#!/usr/bin/env python3
"""Offline counterfactual / execution verification for the `cmrguard` soak candidate.

`X.cm_IsRSafeToOpen` (bots/BotLib/hero_crystal_maiden.lua) withholds Crystal
Maiden's Freezing Field when an enemy hero inside the 1600 scan holds a READY
curated hard CC that he can actually DELIVER right now -- i.e.

    GetUnitToUnitDistance(cm, e) <= (cc:GetCastRange() or 0) + X.nRGuardCloseBuffer

Every input to that predicate except the cast range is in a behav-dump timeline
(positions, per-ability level + cooldown, alive/dead), so the gate can be
replayed frame-by-frame against real games WITHOUT arming it on the farm. That
is what this script does.

Two questions it is built to answer:

  1. PRE-FLIGHT (before the candidate is ever armed): how many real Freezing
     Fields would the gate have withheld, and were those genuinely threat
     frames? The gate's failure mode is FALSE POSITIVES -- that is what GH #34
     was filed for -- so "how many ultimates disappeared" is not the metric;
     "did the vetoing enemy's hard CC actually come out, and did CM die" is.

  2. LOCKOUT LENGTH: how long does the veto hold CONTINUOUSLY? A guard that
     never releases suppresses the ultimate for a whole teamfight, which is
     strictly worse than a badly-timed cast. GH #34 measured a 12s lockout --
     but it measured the RANGE-BLIND version (the boolean J.HasReadyHardCc),
     which the 2026-08-19T11:53Z narrowing replaced. Pass --range-blind to
     reproduce that older reading side by side.

Usage (timelines come from `behav-dump [-interval S] GAME.dem > GAME.json`;
this line used to say `-interval 0.5` unconditionally, but `run_replay.sh` --
the path every ARCHIVED timeline came through -- passes no flag and takes the
dumper's 1.0s default, so a frame count from one recipe is not comparable with
a frame count from the other. See `sample_interval()`; quote EPISODES):

    cmrguard_counterfactual.py TIMELINE.json [TIMELINE.json ...]
    cmrguard_counterfactual.py --range-blind TIMELINE.json ...
    cmrguard_counterfactual.py --buffer 250 TIMELINE.json ...
    cmrguard_counterfactual.py --json TIMELINE.json ...     # machine-readable

Honest boundaries (carry these into any readout):

  * CAST RANGES ARE OUT-OF-FRAME ANCHORS. behav-dump does not carry ability
    cast range (it is KV data, not replay data -- same family as GH #36), so
    CAST_RANGE below is an anchor. Everything else -- positions, HP, levels,
    cooldowns, alive/dead -- is real frame data. The self-radius entries
    (hoof_stomp, berserkers_call, ravage, slithereen_crush) are 0 on purpose:
    the engine reports 0 for no-target abilities and the gate's "holder must be
    on top of her" reading of that is the intended behaviour.

    RE-ANCHORED 2026-08-21 (hero stream, `esaftershock` pre-flight) AGAINST THE
    DATAFEED, which is the shipping KV -- the same source the Lua reads at
    runtime through GetCastRange(). The previous table was hand-anchored to
    Liquipedia and 16 of its 23 entries were wrong, two of them because the
    ability is PER-LEVEL and the table held a scalar. The Lua is unaffected (it
    never sees this table); only the offline reconstructions in this directory
    were. Every entry is now the datafeed's `cast_ranges` LIST, indexed by the
    ability's level on the frame -- use cast_range(name, level), never
    CAST_RANGE[name] directly. The two that moved far enough to change a
    published reading are called out in `ANCHOR_DELTA` below.
  * NO VISION. The engine gate also runs J.IsValid -> CanBeSeen(); the dumper
    does not emit per-hero vis (GH #27), so this reconstruction assumes every
    enemy is visible and therefore OVER-counts vetoes. Treat the veto rate as
    an upper bound.
  * MANA IS NOT CHECKED. IsFullyCastable() also requires the mana; this uses
    level >= 1 and cooldown == 0 only, which again over-counts vetoes.
  * CASTS ARE DETECTED BY COOLDOWN EDGE (0 -> >0), so a cast cannot be
    attributed to a target. "the vetoer's CC fired within 10s" means it was
    used, not that it landed on CM.
  * Entities are keyed by the dumper's `idx`, not by hero name: the dumper can
    emit several entities sharing a class name and tracking by name alone
    poisons trajectories (the shadow_shaman/hp_pct==0 twin in GH #34).
"""

import argparse
import collections
import json
import math
import os
import re
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
JMZ = os.path.join(REPO, "bots", "FunLib", "jmz_func.lua")
HERO_LUA = os.path.join(REPO, "bots", "BotLib", "hero_crystal_maiden.lua")

CM = "npc_dota_hero_crystal_maiden"
R_NAME = "crystal_maiden_freezing_field"
SCAN_RANGE = 1600.0  # J.GetNearbyHeroes(hBot, 1600, ...) in cm_IsRSafeToOpen
CHANNEL = 10.0       # Freezing Field's max channel time; the horizon that matters

# Out-of-frame anchors -- see the module docstring. 0 == no-target/self-radius.
# Values are the datafeed's `cast_ranges` list (one entry = flat across levels).
# Pulled 2026-08-21 from https://www.dota2.com/datafeed/herodata?hero_id=N.
CAST_RANGE = {
    "axe_berserkers_call": [0],
    "bane_fiends_grip": [625],
    "bane_nightmare": [550, 600, 650, 700],
    "centaur_hoof_stomp": [0],
    "chaos_knight_chaos_bolt": [600],
    "crystal_maiden_frostbite": [600],
    "dragon_knight_dragon_tail": [150],
    "earthshaker_fissure": [1600],
    "jakiro_ice_path": [1100],
    "lion_impale": [650],
    "lion_voodoo": [575, 600, 625, 650],
    "ogre_magi_fireblast": [525],
    "primal_beast_pulverize": [200],
    "shadow_demon_disruption": [675],
    "shadow_shaman_shackles": [450],
    "shadow_shaman_voodoo": [550],
    "skeleton_king_hellfire_blast": [525],
    "slardar_slithereen_crush": [0],
    "storm_spirit_electric_vortex": [300],
    "sven_storm_bolt": [600],
    "tidehunter_ravage": [0],
    "vengefulspirit_magic_missile": [650],
    "witch_doctor_paralyzing_cask": [600],
}

# What the re-anchoring moved, for anyone re-reading a published number.
# The two that matter are marked; the rest shift a ring by <= 150u.
ANCHOR_DELTA = {
    # was 900 -- GH #63's headline ("a 900-range projectile inflates cmrguard's
    # ring to 1300u") rests on the OLD value; at the real 600 the ring is 1000u.
    "witch_doctor_paralyzing_cask": (900, 600),
    # was 200 -- more than doubles; shackles is the ability ccburst's own
    # narrowing bisect was filed against.
    "shadow_shaman_shackles": (200, 450),
}


def cast_range(name, level):
    """GetCastRange() for a curated ability at the level it is on this frame.

    Two of the curated abilities are per-level (bane_nightmare, lion_voodoo);
    the rest are flat and the list has one entry. Levels are 1-based; a level
    past the end clamps to the last entry (talent/shard levels are not modelled
    -- neither are Aether Lens and the other cast-range items, so every value
    here is a LOWER bound on the engine's answer)."""
    vals = CAST_RANGE[name]
    if not isinstance(vals, list):
        return vals                       # tolerate a scalar override in tests
    return vals[min(max(int(level), 1), len(vals)) - 1]


def curated_abilities():
    """Extract J.tHardCcAbilities from the Lua source -- never hand-copied, so a
    table edit shows up here as a KeyError instead of silently diverging."""
    src = open(JMZ, encoding="utf-8").read()
    block = src.split("J.tHardCcAbilities = {")[1].split("}")[0]
    return set(re.findall(r"([a-z_]+)\s*=\s*true", block))


def shipped_buffer():
    """Read X.nRGuardCloseBuffer out of the hero file so the default here cannot
    drift away from the value actually being tested."""
    src = open(HERO_LUA, encoding="utf-8").read()
    m = re.search(r"X\.nRGuardCloseBuffer\s*=\s*(\d+)", src)
    return float(m.group(1)) if m else 400.0


def sample_interval(times):
    """Modal spacing of a timeline's snapshot times, in seconds.

    Measured 2026-08-21 (hero stream, `esaftershock` pre-flight) because two
    recipes in this directory disagree and nothing printed which one produced a
    given file: this module's own docstring says `behav-dump -interval 0.5`,
    while `run_replay.sh` -- the path every archived timeline actually came
    through -- passes no flag and takes the dumper's 1.0s default.

    The consequence is that FRAME COUNTS ARE NOT COMPARABLE ACROSS TIMELINES OF
    DIFFERENT INTERVALS, and this stream's headline numbers have been quoted in
    frames.  Re-dumping one 17-game corpus both ways: `cmrself`'s predicate
    reads 31 frames at 1.0s and 61 at 0.5s -- but 13 EPISODES either way, in the
    same 9 games, and its domain is 1 episode either way.  So test_set.md
    section Z.2's rule ("quote the episode number") is not only about
    independence between adjacent samples; it is the only quantity here that
    survives a change of sampling rate.  Every tool that prints a frame count
    should print this alongside it."""
    ts = sorted(set(round(t, 2) for t in times))
    if len(ts) < 3:
        return None
    gaps = collections.Counter(round(b - a, 2) for a, b in zip(ts, ts[1:]))
    return gaps.most_common(1)[0][0]


def group_by_time(snapshots):
    frames = {}
    for s in snapshots:
        frames.setdefault(s["t"], []).append(s)
    return frames


def evaluate(path, curated, buffer_units, range_blind=False):
    """Replay cm_IsRSafeToOpen over one timeline. Returns None if CM is absent."""
    data = json.load(open(path, encoding="utf-8"))
    snaps = data["snapshots"]
    if not any(s["hero"] == CM for s in snaps):
        return None
    cm_team = next(s["team"] for s in snaps if s["hero"] == CM)
    frames = group_by_time(snaps)
    times = sorted(frames)

    veto = {}      # t -> (hero, ability, dist, idx) or None
    hp = {}        # t -> CM hp_pct
    casts = []     # t of each real Freezing Field cast
    prev_cd = None

    for t in times:
        frame = frames[t]
        me = next((s for s in frame if s["hero"] == CM), None)
        if me is None:
            continue
        hp[t] = me["hp_pct"]

        r = next((a for a in (me["abilities"] or []) if a["name"] == R_NAME), None)
        if r is not None:
            if r["level"] >= 1 and prev_cd == 0 and r["cd"] > 0:
                casts.append(t)
            prev_cd = r["cd"]

        if me["hp_pct"] <= 0:
            veto[t] = None
            continue

        closest = None
        for e in frame:
            if e["team"] == cm_team or e["hp_pct"] <= 0:
                continue
            dist = math.hypot(e["x"] - me["x"], e["y"] - me["y"])
            if dist > SCAN_RANGE:
                continue
            for ab in e["abilities"] or []:
                name = ab["name"]
                if name not in curated or ab["level"] < 1 or ab["cd"] != 0:
                    continue
                if name not in CAST_RANGE:
                    raise SystemExit(
                        "no cast-range anchor for curated ability %r -- add it to "
                        "CAST_RANGE (with a datafeed check) before trusting a run" % name)
                if range_blind or dist <= cast_range(name, ab["level"]) + buffer_units:
                    if closest is None or dist < closest[2]:
                        closest = (e["hero"].replace("npc_dota_hero_", ""), name, dist, e["idx"])
        veto[t] = closest

    return {
        "game": os.path.basename(path).replace(".json", ""),
        "runs": continuous_runs(times, veto),
        "casts": [describe_cast(c, times, frames, veto, hp) for c in casts],
    }


def continuous_runs(times, veto):
    """Lengths (seconds) of every maximal stretch of consecutive vetoing frames."""
    runs, start, last = [], None, None
    for t in times:
        if t not in veto:
            continue
        if veto[t] is not None:
            if start is None:
                start = t
            last = t
        elif start is not None:
            runs.append(round(last - start, 1))
            start = None
    if start is not None:
        runs.append(round(last - start, 1))
    return runs


def describe_cast(t, times, frames, veto, hp):
    """What the gate would have done at a real Freezing Field frame, and whether
    the frame deserved it."""
    v = veto.get(t)
    out = {"t": t, "vetoed": v is not None, "hp_at_cast": hp.get(t)}
    if v is None:
        return out
    hero, ability, dist, idx = v
    out.update(vetoed_by="%s/%s" % (hero, ability), distance=round(dist))

    # Did that specific holder actually use that CC inside the channel window?
    fired, prev = None, 0
    for tt in times:
        if tt < t or tt > t + CHANNEL:
            continue
        for e in frames[tt]:
            if e["idx"] != idx:
                continue
            for ab in e["abilities"] or []:
                if ab["name"] == ability:
                    if prev == 0 and ab["cd"] > 0 and fired is None:
                        fired = round(tt - t, 1)
                    prev = ab["cd"]
    out["cc_fired_within_channel"] = fired

    # How long had the veto already been held when the ultimate went off?
    held, tt = 0.0, t
    idx_t = times.index(t) if t in times else None
    if idx_t is not None:
        for back in range(idx_t - 1, -1, -1):
            if veto.get(times[back]) is None:
                break
            held = round(t - times[back], 1)
    out["veto_held_for"] = held
    later = [x for x in times if x >= t + CHANNEL]
    out["hp_after_channel"] = hp.get(later[0]) if later else None
    return out


def percentile(sorted_values, q):
    if not sorted_values:
        return 0.0
    return sorted_values[min(len(sorted_values) - 1, int(len(sorted_values) * q))]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("timelines", nargs="+", help="behav-dump JSON timelines")
    ap.add_argument("--buffer", type=float, default=None,
                    help="override X.nRGuardCloseBuffer (default: read from the hero file)")
    ap.add_argument("--range-blind", action="store_true",
                    help="reproduce the pre-11:53Z boolean-wrapper gate (GH #34's version)")
    ap.add_argument("--json", action="store_true", help="emit raw per-game JSON")
    args = ap.parse_args()

    curated = curated_abilities()
    buf = args.buffer if args.buffer is not None else shipped_buffer()
    results = []
    for path in args.timelines:
        r = evaluate(path, curated, buf, args.range_blind)
        if r is None:
            print("skip (no Crystal Maiden): %s" % path, file=sys.stderr)
            continue
        results.append(r)

    if args.json:
        json.dump(results, sys.stdout, indent=1)
        print()
        return

    label = "RANGE-BLIND (pre-narrowing)" if args.range_blind else "buffer=%g" % buf
    print("cmrguard counterfactual -- %s, %d games\n" % (label, len(results)))
    print("%-26s %6s %6s" % ("game", "casts", "veto"))
    total_casts = vetoed = 0
    runs = []
    for r in results:
        v = sum(1 for c in r["casts"] if c["vetoed"])
        total_casts += len(r["casts"])
        vetoed += v
        runs += r["runs"]
        print("%-26s %6d %6d" % (r["game"], len(r["casts"]), v))

    runs.sort()
    print("\nreal Freezing Fields: %d   would be withheld: %d (%.0f%%, %.2f/game)"
          % (total_casts, vetoed, 100.0 * vetoed / max(total_casts, 1),
             float(vetoed) / max(len(results), 1)))
    print("continuous veto runs: n=%d median=%.1fs p90=%.1fs max=%.1fs "
          ">=%.0fs(channel): %d (%.1f%%)"
          % (len(runs), percentile(runs, 0.5), percentile(runs, 0.9),
             runs[-1] if runs else 0.0, CHANNEL,
             sum(1 for x in runs if x >= CHANNEL),
             100.0 * sum(1 for x in runs if x >= CHANNEL) / max(len(runs), 1)))

    print("\nwithheld frames -- was each a genuine threat frame?")
    for r in results:
        for c in r["casts"]:
            if not c["vetoed"]:
                continue
            fired = c["cc_fired_within_channel"]
            verdict = ("CC came out %.1fs later" % fired) if fired is not None \
                else "CC never came out within %.0fs" % CHANNEL
            print("  %-26s t=%-8.1f %-38s %5du  held %.1fs  hp %.2f -> %s  [%s]"
                  % (r["game"], c["t"], c["vetoed_by"], c["distance"],
                     c["veto_held_for"], c["hp_at_cast"] or 0.0,
                     ("%.2f" % c["hp_after_channel"]) if c["hp_after_channel"] is not None else "?",
                     verdict))


if __name__ == "__main__":
    main()

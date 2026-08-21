#!/usr/bin/env python3
"""Pre-flight corpus check for the `odaoe` soak candidate (dev-only, no AWS spend).

`odaoe` is the ADDITIVE branch added by GH #54 at
hero_obsidian_destroyer.lua:535 (`X.od_GetEclipseAoeLocation`). It sits BELOW
the shipped single-target loop inside `X.ConsiderSanitysEclipse`, so armed it
can only turn a NONE into a cast -- never redirect one. Its domain is therefore
exactly:

    { frames | the gated area predicate is TRUE  AND  the shipped loop is FALSE }

and this script measures that set on real frames, before anyone spends a wave
arming it (test_set.md section V.7 pre-flight; the `axeblink` trap).

Section layout mirrors the other three domain scripts in this directory:

  D  SUPPLY        -- is the carrier even present? games with OD, ult learned,
                      frames alive with the ult castable, real casts.
  A  EXACT DOMAIN  -- frames (and EPISODES) where armed != shipped.
  A' CLAUSE FUNNEL -- a monotone narrowing of D down to A, so the load-bearing
                      clause is named rather than guessed.
  B  OUTCOME SIDE  -- what the shipped code actually did on those frames, plus
                      deaths-with-ult-ready as the cost side.

NUMERIC ANCHORS (pulled live from the Dota datafeed, hero_id=76, 2026-08-21 --
do NOT reuse od_ult_gate.py's defaults, all four of them are wrong; see the
report for that round):

    cast_range          700         (flat; od_ult_gate.py used 600)
    radius              500/525/550 (per ult level; the gate reads it per level)
    base_damage         200/300/400 (per ult level; od_ult_gate.py used 350 flat)
    damage_multiplier   0.4         (flat; od_ult_gate.py used 0.7 and swept
                                     only 0.6/0.7/0.8 -- never reaching 0.4)
    AbilityManaCost     200/300/400 (per level; od_ult_gate.py used 400 flat,
                                     which silently drops every level-1 frame)
    AbilityCooldown     140/130/120

HONEST BOUNDARIES -- every count below is an UPPER bound on the true domain:
  * `J.IsGoingOnSomeone(bot)` wraps the whole Consider function and is a
    script-side mode concept that is not in the .dem (same class as
    `J.IsRetreating`; GH #27 family). Both the gated branch and the shipped
    loop live inside it, so it cannot flip the armed-vs-shipped COMPARISON,
    but it does inflate every absolute count here.
  * No fog: `J.GetNearbyHeroes` returns only VISIBLE enemies and the dumper has
    no per-team vision (GH #27), so enemies that OD could not actually see are
    counted here. Upper bound again.
  * `IsFullyCastable` also fails under silence/break; not tracked. Upper bound.
  * Corpse frames are dropped (`hp <= 0`): the dumper keeps emitting snapshots
    for dead heroes with state frozen at the instant of death, so an unfiltered
    frame counter turns one death into dozens of in-domain frames (GH #78; this
    stream hit the same thing in wk_reincarn_domain.py and axe_blink_domain.py).

    DIRECTOR CORRECTION 2026-08-21T07:0xZ (test_set.md section AA): `hp <= 0`
    IS NOT THE #78 FIX -- IT IS THE PROXY #78 CONDEMNED, IN OTHER UNITS.
    #78 is not about the bulk of the corpse tail (that reads exactly 0); it is
    about the FIRST snapshot at/after the DEATH event, which still carries the
    last LIVE sample.  Swapping `hp_pct > 0` for `hp > 0` changes nothing:
    dumper/main.go:412 computes `HPPct = h.hp / h.maxhp` from the same `h.hp`
    at emission, so for maxhp > 0 the two tests are ALGEBRAICALLY IDENTICAL.
    Every leak `leak_tail.py` measured (235 leaks / 940 death spans, values up
    to hp_pct 0.517) is simultaneously a corpse frame reading `hp > 0` here.
    The real fix is `roam_conversion.is_dead()` (DEATH event -> revival spans),
    which only capmono_refusal.py and lanekill_commit.py currently call.
    CONSEQUENCE FOR THIS SCRIPT'S NUMBERS, both one-sided upward:
      (i)  a dead enemy can still satisfy the load-bearing `>= MIN_TARGETS
           enemies inside CAST_RANGE` clause -- and because the threshold is 2,
           ONE phantom promotes a 1-real-enemy frame into the domain;
      (ii) OD's own leaked frame survives the skip above with ult/mana state
           frozen live, adding spurious `frames_alive` / `ready` frames.
    BOUND, from the measured lag: max lag after DEATH is 0.30s over 940 spans
    (reproduced twice), i.e. STRICTLY LESS THAN ONE 0.5s SAMPLE.  So a phantom
    survives at most one frame and can only CREATE episodes of length exactly
    1; every episode of length >= 2 contains a real in-domain frame.  Report
    the episode-length histogram and the contamination is bounded on sight.
      -- RE-MEASURED HERE on the 19-game 20260819_22xx corpus (425 spans, 208
         leaks): max lag 0.40s, above the recorded 0.30s but still inside one
         0.5s sample, so the "at most one frame" bound HOLDS with less margin
         than the ruling assumed.  Max leaked hp_pct is 1.000 (medusa, lag
         0.10s, span closed normally) -- an independent and stronger death of
         the band-geometry argument section AA.1 retired.  Both facts routed
         to replay-check via GH #82 section 6.

    ANSWERED 2026-08-21T08:xxZ -- both of the director's columns:
      column 1 (episode-length histogram): {1:2, 2:3, 3:2, 4:2, 8:1}, i.e.
        8 of 10 episodes are >= 2 frames = phantom-proof by the bound above.
        The contamination ceiling is the 2 singleton episodes.
      column 2 (rerun on is_dead()): funnel 4092 -> 47 -> 41 -> 40 -> 30
        (was 4096 -> 49 -> 42 -> 41 -> 31).  The proxy cost exactly ONE domain
        frame and ZERO episodes, and that frame is textbook #78: OD's own
        snapshot stamped at his DEATH tick, 20260819_223055 t=650.5, still
        reading hp=29/1512 with the next sample at 0.  So the domain reading
        survives its own audit; `--liveness hp` reproduces the old numbers.
      A separate blindness found while auditing (GH #82): `death_spans()` keyed
        events and snapshots by two different spellings of the same hero, so
        queen_of_pain / vengeful_spirit were NEVER dead (5 games each here).
        Fixed in roam_conversion.canon_hero(); every funnel number above is
        bit-identical before and after that fix -- it did not touch OD's games.
  * Post-game frozen snapshots are cut at the last event (GH #43).
  * Illusions carry the same class name as their owner; the real entity is
    locked as the longest-lived (name, idx) and illusion entities are dropped
    entirely. That matches the gate, whose `J.CanCastOnNonMagicImmune` ends in
    `J.IsSuspiciousIllusion`.
  * Whether `bot:GetNearbyHeroes(r, false, ...)` includes the bot itself is not
    settled from the .dem, and it only affects the SHIPPED loop's ally-parity
    clause, so both conventions are reported. Including self makes shipped fire
    MORE often, i.e. shrinks the measured domain -- that is the conservative
    side for a "should we arm this" question, and it is the one printed as the
    headline.
  * 0.5s sampling: adjacent frames inside one standoff are NOT independent
    observations. Every frame count here is therefore also reported as an
    EPISODE count with the longest run, per the director's ruling in
    test_set.md section Z.2 -- quote the episode number, not the frame number.

LIVENESS (2026-08-21T08:xxZ, this is the director's column 2 of section AA.2):
  every liveness test in this file now goes through `roam_conversion.is_dead()`
  -- DEATH event to respawn -- which is the only audited criterion in this
  directory (section AA.3 rule 1).  `--liveness hp` reproduces the condemned
  `hp > 0` proxy so the two readings can be diffed on the SAME corpus; it
  exists for that audit and for nothing else.  The five call sites it governs
  are OD himself, the load-bearing in-range enemy count, the shipped loop's
  ally ring, the shipped loop's target-adjacent enemy count, and `ready_t`.

Usage:
    od_eclipse_aoe_domain.py tl/*.json [--json out.json] [--episode-gap 1.0]
                                       [--liveness is_dead|hp]
"""
import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from roam_conversion import death_spans, is_dead  # noqa: E402

OD = "npc_dota_hero_obsidian_destroyer"
ULT = "obsidian_destroyer_sanity_eclipse"

# datafeed hero_id=76, pulled 2026-08-21 (see docstring)
CAST_RANGE = 700.0
RADIUS = {1: 500.0, 2: 525.0, 3: 550.0}
BASE_DAMAGE = {1: 200.0, 2: 300.0, 3: 400.0}
MANA_COST = {1: 200.0, 2: 300.0, 3: 400.0}
MULT = 0.4

MAGIC_RESIST = 0.75      # 25% base magic resistance, as GetActualIncomingDamage applies
MIN_TARGETS = 2          # X.nRAoeMinTargets
MIN_DAMAGE_PCT = 0.25    # X.nRAoeMinDamagePct
ALLY_RING = 1200.0       # both ally counts in the shipped loop


def load_frames(tl_path):
    """-> (raw, teams, events, snapshots-by-(hero,idx), snapshots-by-rounded-t).

    The raw dict is returned as well because `roam_conversion.death_spans()`
    needs the UNCUT snapshot list: a death near the end of the game respawns
    (or does not) in the post-game tail this function drops."""
    d = json.load(open(tl_path))
    teams = d["game"]["teams"]
    events = sorted(d["events"], key=lambda e: e["t"])
    t_end = max((e["t"] for e in events), default=float("inf"))
    by_ent = collections.defaultdict(list)
    by_t = collections.defaultdict(list)
    for s in d["snapshots"]:
        if s["t"] > t_end:                       # GH #43 post-game freeze
            continue
        by_ent[(s["hero"], s["idx"])].append(s)
        by_t[round(s["t"], 1)].append(s)
    for k in by_ent:
        by_ent[k].sort(key=lambda s: s["t"])
    return d, teams, events, by_ent, by_t


def real_entities(by_ent):
    """Longest-lived (name, idx) per hero name -- the body, not its illusions."""
    best = {}
    for (name, idx), snaps in by_ent.items():
        if name not in best or len(snaps) > len(by_ent[(name, best[name])]):
            best[name] = idx
    return best


def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def dist_loc(s, loc):
    return math.hypot(s["x"] - loc[0], s["y"] - loc[1])


def worth_hitting(od, e, base):
    """X.od_IsEclipseWorthHitting -- signed mana gap, raw damage vs CURRENT hp.

    Note the gate does NOT apply magic resistance here (it compares the raw
    `nBaseDamage + nManaGap * nMultiplier` against `hEnemy:GetHealth() * 0.25`),
    so neither does this. Reproducing the predicate as written is the point."""
    gap = od["mp"] - e["mp"]
    if gap <= 0:
        return False
    return base + gap * MULT >= e["hp"] * MIN_DAMAGE_PCT


def aoe_covers(od, hittable, radius):
    """X.od_GetEclipseAoeLocation's candidate search -> best coverage count."""
    locs = []
    for i, a in enumerate(hittable):
        locs.append((a["x"], a["y"]))
        for b in hittable[i + 1:]:
            locs.append(((a["x"] + b["x"]) / 2.0, (a["y"] + b["y"]) / 2.0))
    best = 0
    for loc in locs:
        if dist_loc(od, loc) > CAST_RANGE:
            continue
        n = sum(1 for e in hittable if dist_loc(e, loc) <= radius)
        best = max(best, n)
    return best


def episode_runs(times, gap):
    """[t, ...] from ONE game -> [[t, ...], ...], one list per episode.

    Must be called per game.  Pooling timestamps across games and splitting on
    the gap merges two different games' standoffs whenever their clocks land
    within `gap` of each other -- which UNDERCOUNTS episodes, in the direction
    that makes a domain look more concentrated than it is.  (The 2026-08-21
    05:52Z report's "10 episodes" was computed on a pooled list; see the
    corrected reading in that round's follow-up.)"""
    if not times:
        return []
    times = sorted(times)
    runs, cur = [], [times[0]]
    for t in times[1:]:
        if t - cur[-1] <= gap:
            cur.append(t)
        else:
            runs.append(cur)
            cur = [t]
    runs.append(cur)
    return runs


def episodes_of(runs):
    """[[t, ...], ...] -> (n_episodes, longest_run_frames, longest_run_seconds)."""
    if not runs:
        return 0, 0, 0.0
    longest = max(runs, key=len)
    return len(runs), len(longest), round(longest[-1] - longest[0], 1)


def scan_game(tl_path, liveness="is_dead"):
    raw, teams, events, by_ent, by_t = load_frames(tl_path)
    if OD not in teams:
        return None
    my, foe = teams[OD], (3 if teams[OD] == 2 else 2)
    real = real_entities(by_ent)
    od_key = (OD, real[OD])
    real_idx = {(n, i) for n, i in real.items()}

    # --- liveness (test_set.md section AA.2/AA.3) ---------------------------
    # `is_dead()` reads DEATH events, so it also covers the ONE leaked snapshot
    # after each death that still carries live HP -- the frame the `hp > 0`
    # proxy cannot see, and the only frame #78 was ever about.
    spans = death_spans(raw, real)
    if liveness == "is_dead":
        def alive(s):
            return not is_dead(spans, s["hero"], s["t"])
    else:                                   # audit-only: the condemned proxy
        def alive(s):
            return s["hp"] > 0
    # Book-keeping for the audit column: how many frames do the two criteria
    # disagree on, and on whom.  A phantom is a frame the proxy calls alive and
    # is_dead() calls dead; the reverse (a hero inside a death span still
    # reading hp > 0 late) would be a respawn-detection miss, counted apart.
    ghosts = collections.Counter()
    for s_list in by_ent.values():
        for s in s_list:
            if (s["hero"], s["idx"]) not in real_idx:
                continue
            dead_ev = is_dead(spans, s["hero"], s["t"])
            if dead_ev and s["hp"] > 0:
                ghosts["proxy_alive_event_dead"] += 1
            elif not dead_ev and s["hp"] <= 0:
                ghosts["proxy_dead_event_alive"] += 1

    casts = [e["t"] for e in events
             if e["type"] == "ABILITY" and e.get("actor") == OD
             and e.get("inflictor") == ULT]
    # Weak observable proxy for `J.IsGoingOnSomeone(bot)`, which is a
    # script-side mode concept and genuinely absent from the .dem: did OD
    # damage an enemy HERO, or cast anything, within +/-3s of the frame? It is
    # neither necessary nor sufficient for the real predicate -- it is here
    # only to keep the headline count from resting entirely on an unmeasurable
    # clause, and it is reported separately, never folded into the domain.
    acting = sorted(e["t"] for e in events
                    if e.get("actor") == OD
                    and (e["type"] == "ABILITY"
                         or (e["type"] in ("DAMAGE", "CRITICAL_DAMAGE")
                             and e.get("target_hero"))))
    deaths = [e["t"] for e in events
              if e["type"] == "DEATH" and e.get("target") == OD]

    g = {"key": os.path.basename(tl_path).replace(".json", ""),
         "od_team": my, "real_casts": len(casts), "cast_t": [round(c, 1) for c in casts],
         "od_deaths": len(deaths), "max_ult_lvl": 0, "ult_learn_t": None,
         "frames_alive": 0, "ready": 0,
         "f_two_in_range": 0, "f_two_hittable": 0, "f_covered": 0,
         "shipped_self": 0, "shipped_noself": 0,
         "domain_self": [], "domain_noself": [],
         "died_with_ready": 0, "samples": [],
         "liveness": liveness, "ghost_frames": ghosts["proxy_alive_event_dead"],
         "late_respawn_frames": ghosts["proxy_dead_event_alive"],
         "ep_len_hist_self": {}, "ep_len_hist_noself": {}}

    for s in by_ent[od_key]:
        # Call site 1/5: OD himself.  His own leaked frame carries a frozen
        # LIVE ult cooldown and mana, i.e. it can fake a `ready` frame.
        if not alive(s):
            continue
        g["frames_alive"] += 1
        ult = next((a for a in s["abilities"] if a["name"] == ULT), None)
        if not ult or ult["level"] < 1:
            continue
        lvl = min(ult["level"], 3)
        g["max_ult_lvl"] = max(g["max_ult_lvl"], lvl)
        if g["ult_learn_t"] is None:
            g["ult_learn_t"] = round(s["t"], 1)
        if ult["cd"] > 0 or s["mp"] < MANA_COST[lvl]:
            continue
        g["ready"] += 1

        base, radius = BASE_DAMAGE[lvl], RADIUS[lvl]
        frame = by_t.get(round(s["t"], 1), [])
        # Call site 2/5 -- THE LOAD-BEARING CLAUSE (4096 -> 49 on the
        # 2026-08-19 22:xx corpus).  This is the one the director flagged: with
        # MIN_TARGETS == 2 a single phantom promotes a 1-real-enemy frame into
        # the domain, and the contamination is one-sided UPWARD, i.e. towards
        # this script's own conclusion.  Now on `is_dead()` (section AA.2
        # column 2); `--liveness hp` reproduces the old, contaminated reading.
        enemies = [z for z in frame
                   if teams.get(z["hero"]) == foe and alive(z)
                   and (z["hero"], z["idx"]) in real_idx
                   and dist(s, z) <= CAST_RANGE]
        if len(enemies) < MIN_TARGETS:
            continue
        g["f_two_in_range"] += 1

        hittable = [z for z in enemies if worth_hitting(s, z, base)]
        if len(hittable) < MIN_TARGETS:
            continue
        g["f_two_hittable"] += 1

        covered = aoe_covers(s, hittable, radius)
        if covered < MIN_TARGETS:
            continue
        g["f_covered"] += 1

        # --- would the SHIPPED loop already have fired on this frame? ---
        # Call site 3/5: the shipped loop's ally ring.  A phantom ALLY makes
        # shipped fire more often, i.e. it shrinks the domain -- the opposite
        # sign to call site 2, so the two do not cancel, they blur.
        allies = [z for z in frame
                  if teams.get(z["hero"]) == my and alive(z)
                  and (z["hero"], z["idx"]) in real_idx
                  and dist(s, z) <= ALLY_RING]
        n_ally_self = len(allies)                       # includes OD himself
        n_ally_noself = sum(1 for z in allies if z["hero"] != OD)
        shipped = {True: False, False: False}
        for e in enemies:
            est = MAGIC_RESIST * (base + abs(s["mp"] - e["mp"]) * MULT)
            if est < e["hp"]:
                continue
            # Call site 4/5: the victim's own ally count in the shipped loop.
            t_ally = sum(1 for z in frame
                         if teams.get(z["hero"]) == foe and alive(z)
                         and (z["hero"], z["idx"]) in real_idx
                         and dist(e, z) <= ALLY_RING)
            if n_ally_self >= t_ally:
                shipped[True] = True
            if n_ally_noself >= t_ally:
                shipped[False] = True
        g["shipped_self"] += shipped[True]
        g["shipped_noself"] += shipped[False]

        # value of the cast this branch would make: effective (post-resist)
        # damage on every hittable enemy the best circle actually covers.
        # Unlike the gate's own predicate this DOES apply magic resistance --
        # the predicate asks "is it worth counting", this asks "what is bought".
        covered_e = []
        for loc in [(z["x"], z["y"]) for z in hittable] + \
                   [((p["x"] + q["x"]) / 2.0, (p["y"] + q["y"]) / 2.0)
                    for i, p in enumerate(hittable) for q in hittable[i + 1:]]:
            if dist_loc(s, loc) > CAST_RANGE:
                continue
            hit = [z for z in hittable if dist_loc(z, loc) <= radius]
            if len(hit) > len(covered_e):
                covered_e = hit
        dmg = [MAGIC_RESIST * (base + max(0.0, s["mp"] - z["mp"]) * MULT)
               for z in covered_e]
        rec = {"t": round(s["t"], 1), "lvl": lvl, "covered": covered,
               "n_range": len(enemies), "n_hit": len(hittable),
               "od_hp": round(s["hp_pct"], 2), "od_mp": round(s["mp"]),
               "ally": n_ally_self, "shipped": shipped[True],
               "engaged": any(abs(x - s["t"]) <= 3.0 for x in acting),
               "dmg_each": [round(x) for x in dmg], "dmg_total": round(sum(dmg)),
               "hp_frac": [round(x / max(z["hp"], 1), 2)
                           for x, z in zip(dmg, covered_e)],
               "tgts": sorted(z["hero"].replace("npc_dota_hero_", "")
                              for z in hittable)}
        if not shipped[True]:
            g["domain_self"].append(rec)
        if not shipped[False]:
            g["domain_noself"].append(rec)
        g["samples"].append(rec)

    # Call site 5/5: `died_with_ready`, the cost side.
    ready_t = {round(s["t"], 1) for s in by_ent[od_key]
               if alive(s)
               for a in [next((a for a in s["abilities"] if a["name"] == ULT), None)]
               if a and a["level"] >= 1 and a["cd"] == 0
               and s["mp"] >= MANA_COST[min(a["level"], 3)]}
    g["died_with_ready"] = sum(1 for d in deaths
                               if any(abs(d - t) <= 1.0 for t in ready_t))
    return g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="+")
    ap.add_argument("--episode-gap", type=float, default=1.0,
                    help="max seconds between frames of one episode (0.5s sampling)")
    ap.add_argument("--liveness", choices=("is_dead", "hp"), default="is_dead",
                    help="is_dead = DEATH event -> respawn (the only audited "
                         "criterion, test_set.md AA.3); hp = the condemned "
                         "`hp > 0` proxy, kept only to diff the two readings")
    ap.add_argument("--json", dest="json_out")
    a = ap.parse_args()

    games = [g for g in (scan_game(p, a.liveness) for p in a.timelines) if g]
    if not games:
        print("no game in this corpus has Obsidian Destroyer -- nothing to measure")
        return

    tot = collections.Counter()
    for g in games:
        for k in ("frames_alive", "ready", "f_two_in_range", "f_two_hittable",
                  "f_covered", "shipped_self", "shipped_noself", "real_casts",
                  "od_deaths", "died_with_ready"):
            tot[k] += g[k]

    print(f"=== D SUPPLY === ({len(games)} games with OD, of {len(a.timelines)} scanned)")
    print(f"{'game':28s} {'ult@':>7s} {'lvl':>3s} {'alive':>6s} {'ready':>6s} "
          f"{'casts':>5s} {'deaths':>6s} {'d+ready':>7s}")
    for g in games:
        print(f"{g['key'][:28]:28s} {str(g['ult_learn_t']):>7s} {g['max_ult_lvl']:>3d} "
              f"{g['frames_alive']:>6d} {g['ready']:>6d} {g['real_casts']:>5d} "
              f"{g['od_deaths']:>6d} {g['died_with_ready']:>7d}")
    print(f"{'TOTAL':28s} {'':>7s} {'':>3s} {tot['frames_alive']:>6d} "
          f"{tot['ready']:>6d} {tot['real_casts']:>5d} {tot['od_deaths']:>6d} "
          f"{tot['died_with_ready']:>7d}")

    print("\n=== A' CLAUSE FUNNEL === (monotone; every step is an upper bound)")
    steps = [("ult castable (lvl>=1, cd==0, mana>=cost, alive)", tot["ready"]),
             (f">= {MIN_TARGETS} living enemies within {CAST_RANGE:.0f}", tot["f_two_in_range"]),
             (f">= {MIN_TARGETS} of them worth hitting (gap>0, dmg >= {MIN_DAMAGE_PCT:.0%} hp)",
              tot["f_two_hittable"]),
             (f"a candidate circle covers >= {MIN_TARGETS}", tot["f_covered"])]
    prev = None
    for label, n in steps:
        drop = "" if prev is None else f"  (-{prev - n})"
        print(f"  {n:6d}  {label}{drop}")
        prev = n
    print(f"  {tot['f_covered'] - tot['shipped_self']:6d}  "
          f"...and the SHIPPED loop does NOT already fire  "
          f"(-{tot['shipped_self']})   <-- EXACT DOMAIN (ally count incl. self)")
    print(f"  {tot['f_covered'] - tot['shipped_noself']:6d}  "
          f"...same, ally count EXCLUDING self  (-{tot['shipped_noself']})")

    for tag in ("self", "noself"):
        recs = [r for g in games for r in g[f"domain_{tag}"]]
        runs = [run for g in games                       # per game, never pooled
                for run in episode_runs([r["t"] for r in g[f"domain_{tag}"]],
                                        a.episode_gap)]
        n_ep, run_f, run_s = episodes_of(runs)
        per = len(recs) / len(games)
        print(f"\n=== A EXACT DOMAIN (ally-parity {tag}) === "
              f"{len(recs)} frames / {n_ep} EPISODES over {len(games)} games "
              f"({per:.1f} frames/game); longest run {run_f} frames = {run_s}s")
        by_game = collections.Counter(g["key"] for g in games for r in g[f"domain_{tag}"])
        print("  per game:", dict(by_game) or "{}")

        # DIRECTOR'S COLUMN 1 (test_set.md section AA.2): the measured DEATH
        # lag is 0.30s < one 0.5s sample, so a phantom survives at most one
        # frame and can only manufacture an episode of length EXACTLY 1.
        # => #(length-1 episodes) is a hard upper bound on the contamination,
        # and every length->=2 episode contains at least one real in-domain
        # frame no matter which liveness criterion is used.
        hist = collections.Counter(len(r) for r in runs)
        ge2 = sum(n for L, n in hist.items() if L >= 2)
        print("  episode-length histogram (frames -> episodes):",
              {L: hist[L] for L in sorted(hist)} or "{}")
        if n_ep:
            print(f"  episodes of length >= 2 (phantom-proof): {ge2}/{n_ep} "
                  f"= {ge2 / n_ep:.0%}; length-1 episodes bound the "
                  f"contamination at {n_ep - ge2}")
        for g in games:
            g[f"ep_len_hist_{tag}"] = dict(collections.Counter(
                len(r) for r in episode_runs([r["t"] for r in g[f"domain_{tag}"]],
                                             a.episode_gap)))

    print(f"\n=== LIVENESS === criterion: {a.liveness}"
          f"  (is_dead = DEATH event -> respawn; hp = the condemned proxy)")
    gh = sum(g["ghost_frames"] for g in games)
    lr = sum(g["late_respawn_frames"] for g in games)
    print(f"  frames the `hp > 0` proxy calls ALIVE but is_dead() calls dead "
          f"(phantoms): {gh} over {len(games)} games = {gh / len(games):.1f}/game")
    print(f"  frames the proxy calls DEAD but is_dead() calls alive "
          f"(respawn-detection lag): {lr}")

    recs = [r for g in games for r in g["domain_self"]]
    if recs:
        eng = [r for r in recs if r["engaged"]]
        n_ep_e, _, _ = episodes_of([run for g in games for run in episode_runs(
            [r["t"] for r in g["domain_self"] if r["engaged"]], a.episode_gap)])
        print(f"\n  of the in-domain frames, OD was observably ENGAGED "
              f"(damaged a hero or cast something within 3s): {len(eng)}/{len(recs)} "
              f"frames = {n_ep_e} episodes -- a proxy for the unmeasurable "
              f"J.IsGoingOnSomeone, reported separately, NOT subtracted")
        print("\n  in-domain frames (ally-parity incl. self), first 40:")
        for g in games:
            for r in g["domain_self"][:40]:
                print(f"    {g['key'][:26]:26s} t={r['t']:7.1f} lvl={r['lvl']} "
                      f"cover={r['covered']} inRange={r['n_range']} hit={r['n_hit']} "
                      f"od_hp={r['od_hp']:.2f} od_mp={r['od_mp']:4d} ally={r['ally']} "
                      f"dmg={r['dmg_total']:4d}{str(r['hp_frac']):14s} "
                      f"tgts={','.join(t[:8] for t in r['tgts'])}")
        tot_dmg = sorted(r["dmg_total"] for r in recs)
        print(f"\n  effective AoE damage the armed cast would deal, over the "
              f"{len(recs)} in-domain frames: min {tot_dmg[0]} / median "
              f"{tot_dmg[len(tot_dmg) // 2]} / max {tot_dmg[-1]}")

    print("\n=== B OUTCOME SIDE ===")
    print(f"  real Sanity's Eclipse casts in corpus : {tot['real_casts']}")
    print(f"  OD deaths                             : {tot['od_deaths']}")
    print(f"  OD deaths with the ult castable       : {tot['died_with_ready']}")
    print(f"  frames where BOTH would fire (armed == shipped): {tot['shipped_self']}")

    if a.json_out:
        json.dump({"games": games, "totals": dict(tot)}, open(a.json_out, "w"), indent=1)
        print(f"\nwrote {a.json_out}")


if __name__ == "__main__":
    main()

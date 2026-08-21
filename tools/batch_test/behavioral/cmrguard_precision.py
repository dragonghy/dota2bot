#!/usr/bin/env python3
"""Correctness (false-positive) readout for the `cmrguard` soak candidate.

`cmrguard_counterfactual.py` answers "how many Freezing Fields would the gate
withhold, and how long does a veto hold". It cannot answer the question the
director's constraint 3 (test_set.md, §E) actually asks:

    of the frames the gate BLOCKS, in what fraction does a hard CC really land
    on Crystal Maiden inside the 10s channel horizon?

That is a *precision* question, and precision is meaningless without the base
rate: if hard CC lands on CM within 10s at 40% of ALL frames, a veto that fires
at 45% is detecting nothing. So this script scores every frame twice --

  * gate state (VETO / CLEAR), by replaying `X.cm_IsRSafeToOpen` on the frame
    (imported from cmrguard_counterfactual, so there is exactly one copy of the
    predicate and the cast-range anchors);
  * outcome, from MODIFIER_ADD events landing on CM inside [t, t+10]:
    - ANY hard CC (the curated stun/root/hex modifier set below),
    - the VETOING hero's own CC specifically (attribution),
    - death.

and prints P(outcome | VETO) against P(outcome | CLEAR) with the lift. Episodes
(maximal runs of consecutive VETO frames) are scored the same way, one row per
episode, so a single 26s lockout cannot be counted as 52 independent successes.

Why modifiers and not cooldown edges: a cooldown edge says the vetoer USED his
CC somewhere on the map; `modifier_stunned` on CM says it LANDED on her. The
gate's stated purpose is "she isn't covered against being chain-CC'd out of the
channel", so the landing is the event that matters.

Usage:

    cmrguard_precision.py --label armed  TL.json ...   [--label base TL.json ...]
    cmrguard_precision.py --episodes TL.json ...       # per-episode detail
    cmrguard_precision.py --json TL.json ...

Honest boundaries (carry these into any readout):

  * Inherits the cast-range and vision boundaries of cmrguard_counterfactual:
    cast ranges are Liquipedia anchors (not replay data), and vision is
    unobservable (J.IsValid -> CanBeSeen, GH #27). Both make the VETO set an
    OVER-count, so the measured precision is a LOWER bound.
  * MANA IS PARTLY CHECKED, and it matters. J.GetReadyHardCc asks
    IsFullyCastable(), which includes mana; cmrguard_counterfactual ignores it.
    A real frame caught the difference: 041137_20260820_043124 t=449.9, Shadow
    Shaman 595u away with shackles at cd 0 -- but on 35/579 mana, far below any
    curated CC's cost. The reconstruction said VETO, the engine said clear, and
    CM opened her ultimate 0.3s later. That cast is NOT a gate failure; it is
    this script's blind spot. Rather than hand-copy 23 per-ability mana costs
    (a fresh out-of-frame anchor set to keep correct), --mana-floor drops any
    would-be vetoer holding less mana than the CHEAPEST curated hard CC. That
    is a strict UNDER-correction: it removes only holders who provably cannot
    cast anything, never one who merely cannot afford his own spell, so the
    corrected precision remains a lower bound on the engine's.
  * `modifier_stunned` is generic: it is the landing of *a* stun, not
    necessarily the vetoer's. Attribution to the vetoer is only possible for
    the abilities with their own named modifier (shackles, voodoo, crush,
    berserkers_call, astral); for those, MODIFIER_ADD.actor is used. The ANY
    column is therefore the honest headline and the ATTRIB column an under-count.
  * Frames are 0.5s snapshots; a CC landing inside the same half-second as the
    veto is attributed to that frame. Post-game freeze tails are truncated per
    GH #43 (t > max event t is dropped).
  * Dead frames (hp_pct <= 0) are excluded from both arms: a corpse is neither
    vetoed nor stunnable, and including them was what made the first pass of
    GH #34 read 577 phantom opportunities.
"""

import argparse
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cmrguard_counterfactual import (  # noqa: E402
    CM, CHANNEL, SCAN_RANGE, cast_range, curated_abilities, shipped_buffer,
    group_by_time,
)
import math  # noqa: E402

# Modifiers that mean "CM is locked out of her channel". Freezing Field is
# broken by stun/hex/root/taunt/banish -- not by slows, silences or damage.
HARD_CC_MODIFIERS = {
    "modifier_stunned",
    "modifier_bashed",
    "modifier_shadow_shaman_shackles",
    "modifier_shadow_shaman_voodoo",
    "modifier_lion_voodoo",
    "modifier_slithereen_crush",
    "modifier_axe_berserkers_call",
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_bane_fiends_grip",
    "modifier_bane_nightmare",
    "modifier_shadow_demon_disruption",
    "modifier_earthshaker_fissure_stun",
    "modifier_jakiro_ice_path_stun",
    "modifier_primal_beast_pulverize",
    "modifier_storm_spirit_electric_vortex_pull",
}

# Named modifier -> the curated ability that applies it, for attribution.
ABILITY_MODIFIER = {
    "shadow_shaman_shackles": "modifier_shadow_shaman_shackles",
    "shadow_shaman_voodoo": "modifier_shadow_shaman_voodoo",
    "lion_voodoo": "modifier_lion_voodoo",
    "slardar_slithereen_crush": "modifier_slithereen_crush",
    "axe_berserkers_call": "modifier_axe_berserkers_call",
    "bane_fiends_grip": "modifier_bane_fiends_grip",
    "bane_nightmare": "modifier_bane_nightmare",
    "shadow_demon_disruption": "modifier_shadow_demon_disruption",
}

R_CHANNEL_MODIFIER = "modifier_crystal_maiden_freezing_field"

# Cheapest level-1 mana cost across J.tHardCcAbilities (axe_berserkers_call, 80).
# Used only as a floor -- see the --mana-floor note in the module docstring.
CHEAPEST_CURATED_CC_MANA = 80.0


def canon(name):
    return (name or "").replace("npc_dota_hero_", "")


def truncate_tail(data):
    """GH #43: every game ends with a 24-25s frozen post-game snapshot tail that
    no event brackets. Drop frames past the last real event."""
    if not data.get("events"):
        return data
    tmax = max(e["t"] for e in data["events"])
    data["snapshots"] = [s for s in data["snapshots"] if s["t"] <= tmax]
    return data


def score_game(path, curated, buffer_units, mana_floor=False):
    data = truncate_tail(json.load(open(path, encoding="utf-8")))
    snaps = data["snapshots"]
    if not any(s["hero"] == CM for s in snaps):
        return None
    cm_team = next(s["team"] for s in snaps if s["hero"] == CM)
    frames = group_by_time(snaps)
    times = sorted(frames)

    # --- outcome streams -------------------------------------------------
    cc_on_cm = []      # (t, inflictor, actor)
    death_ts = []
    r_casts = []
    for e in data["events"]:
        tgt_is_cm = canon(e.get("target", "")).replace("_", "") == "crystalmaiden"
        if e["type"] == "MODIFIER_ADD" and tgt_is_cm:
            if e["inflictor"] in HARD_CC_MODIFIERS:
                cc_on_cm.append((e["t"], e["inflictor"], canon(e.get("actor", ""))))
            elif e["inflictor"] == R_CHANNEL_MODIFIER:
                r_casts.append(e["t"])
        elif e["type"] == "DEATH" and tgt_is_cm:
            death_ts.append(e["t"])

    # --- gate replay -----------------------------------------------------
    rows = []
    for t in times:
        frame = frames[t]
        me = next((s for s in frame if s["hero"] == CM), None)
        if me is None or me["hp_pct"] <= 0:
            continue
        vetoer = None
        for e in frame:
            if e["team"] == cm_team or e["hp_pct"] <= 0:
                continue
            dist = math.hypot(e["x"] - me["x"], e["y"] - me["y"])
            if dist > SCAN_RANGE:
                continue
            if mana_floor and e["mp"] < CHEAPEST_CURATED_CC_MANA:
                continue
            for ab in e["abilities"] or []:
                name = ab["name"]
                if name not in curated or ab["level"] < 1 or ab["cd"] != 0:
                    continue
                if dist <= cast_range(name, ab["level"]) + buffer_units:
                    if vetoer is None or dist < vetoer[2]:
                        vetoer = (canon(e["hero"]), name, dist)
        hi = t + CHANNEL
        any_cc = [c for c in cc_on_cm if t <= c[0] <= hi]
        attrib = None
        if vetoer is not None:
            want = ABILITY_MODIFIER.get(vetoer[1])
            for c in any_cc:
                if c[2] == vetoer[0] and (want is None or c[1] == want):
                    attrib = round(c[0] - t, 1)
                    break
        rows.append({
            "t": t,
            "veto": vetoer is not None,
            "vetoer": vetoer,
            "hp": me["hp_pct"],
            "cc": round(any_cc[0][0] - t, 1) if any_cc else None,
            "cc_what": any_cc[0][1] if any_cc else None,
            "attrib": attrib,
            "died": any(t <= d <= hi for d in death_ts),
        })
    return {"game": os.path.basename(path).replace(".json", ""),
            "rows": rows, "r_casts": r_casts,
            "duration": max(times) if times else 0}


def episodes(rows):
    """Maximal runs of consecutive VETO frames, scored on the run's FIRST frame
    (that is the frame at which the ultimate would have been withheld)."""
    out, cur = [], None
    for r in rows:
        if r["veto"]:
            if cur is None:
                cur = {"t0": r["t"], "t1": r["t"], "head": r, "n": 1}
            else:
                cur["t1"] = r["t"]
                cur["n"] += 1
                # keep the strongest (closest) vetoer seen in the run
                if r["vetoer"][2] < cur["head"]["vetoer"][2]:
                    cur["head"] = r
        elif cur is not None:
            out.append(cur)
            cur = None
    if cur is not None:
        out.append(cur)
    for e in out:
        e["len"] = round(e["t1"] - e["t0"], 1)
    return out


def rate(n, d):
    return 0.0 if d == 0 else 100.0 * n / d


def report(label, games, show_episodes):
    all_rows = [r for g in games for r in g["rows"]]
    veto = [r for r in all_rows if r["veto"]]
    clear = [r for r in all_rows if not r["veto"]]
    eps = [(g, e) for g in games for e in episodes(g["rows"])]

    print("=" * 78)
    print("%s -- %d games, %d CM-alive frames (%.1f%% vetoed), %d veto episodes"
          % (label, len(games), len(all_rows), rate(len(veto), len(all_rows)), len(eps)))
    print("  real Freezing Fields (modifier_crystal_maiden_freezing_field): %d"
          % sum(len(g["r_casts"]) for g in games))
    print()
    print("  %-34s %8s %8s %8s" % ("outcome within 10s", "VETO", "CLEAR", "lift"))
    for key, name in (("cc", "hard CC lands on CM"), ("died", "CM dies")):
        if key == "cc":
            nv = sum(1 for r in veto if r["cc"] is not None)
            nc = sum(1 for r in clear if r["cc"] is not None)
        else:
            nv = sum(1 for r in veto if r["died"])
            nc = sum(1 for r in clear if r["died"])
        pv, pc = rate(nv, len(veto)), rate(nc, len(clear))
        lift = ("%.2fx" % (pv / pc)) if pc else "--"
        print("  %-34s %7.1f%% %7.1f%% %8s" % (name, pv, pc, lift))
    na = sum(1 for r in veto if r["attrib"] is not None)
    print("  %-34s %7.1f%% %8s %8s"
          % ("...and it is the VETOER's CC", rate(na, len(veto)), "n/a", ""))
    print()
    ep_cc = sum(1 for _, e in eps if e["head"]["cc"] is not None)
    ep_at = sum(1 for _, e in eps if e["head"]["attrib"] is not None)
    ep_dd = sum(1 for _, e in eps if e["head"]["died"])
    print("  per EPISODE (one vote each): CC %d/%d (%.0f%%)  attributed %d/%d (%.0f%%)"
          "  death %d/%d (%.0f%%)"
          % (ep_cc, len(eps), rate(ep_cc, len(eps)), ep_at, len(eps), rate(ep_at, len(eps)),
             ep_dd, len(eps), rate(ep_dd, len(eps))))
    lens = sorted(e["len"] for _, e in eps)
    if lens:
        print("  episode length: median %.1fs  p90 %.1fs  max %.1fs  >=10s: %d"
              % (lens[len(lens) // 2], lens[int(len(lens) * 0.9)], lens[-1],
                 sum(1 for x in lens if x >= CHANNEL)))
    who = Counter("%s/%s" % (e["head"]["vetoer"][0], e["head"]["vetoer"][1]) for _, e in eps)
    print("  top vetoers: " + ", ".join("%s x%d" % (k, v) for k, v in who.most_common(6)))

    if show_episodes:
        print("\n  %-28s %7s %5s %5s %-34s %6s %6s"
              % ("game", "t0", "len", "hp", "vetoer", "cc@", "att@"))
        for g, e in sorted(eps, key=lambda x: -x[1]["len"])[:40]:
            h = e["head"]
            print("  %-28s %7.1f %5.1f %5.2f %-34s %6s %6s"
                  % (g["game"][:28], e["t0"], e["len"], h["hp"],
                     "%s/%s@%du" % (h["vetoer"][0], h["vetoer"][1], round(h["vetoer"][2])),
                     h["cc"] if h["cc"] is not None else "-",
                     h["attrib"] if h["attrib"] is not None else "-"))
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("timelines", nargs="+")
    ap.add_argument("--label", default="corpus")
    ap.add_argument("--split", metavar="SUBSTR",
                    help="split the corpus into two arms by a substring of the filename")
    ap.add_argument("--buffer", type=float, default=None)
    ap.add_argument("--mana-floor", action="store_true",
                    help="drop would-be vetoers below the cheapest curated CC's mana cost")
    ap.add_argument("--episodes", action="store_true", help="print per-episode detail")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    curated = curated_abilities()
    buf = args.buffer if args.buffer is not None else shipped_buffer()
    games = []
    for p in args.timelines:
        g = score_game(p, curated, buf, args.mana_floor)
        if g is None:
            print("skip (no Crystal Maiden): %s" % p, file=sys.stderr)
            continue
        g["path"] = p
        games.append(g)

    if args.json:
        json.dump([{k: v for k, v in g.items() if k != "rows"} for g in games],
                  sys.stdout, indent=1)
        print()
        return

    if args.split:
        a = [g for g in games if args.split in g["path"]]
        b = [g for g in games if args.split not in g["path"]]
        report("%s [%s]" % (args.label, args.split), a, args.episodes)
        report("%s [not %s]" % (args.label, args.split), b, args.episodes)
    else:
        report(args.label, games, args.episodes)


if __name__ == "__main__":
    main()

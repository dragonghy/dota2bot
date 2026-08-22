#!/usr/bin/env python3
"""How much of `hometp_highhp.py`'s "no branch explains it" residual is a
SAMPLING ARTIFACT of reading `X.IsInvFull` one sample too early.

Why this exists (2026-08-22T23:xxZ, replay-check):
  GH #120 excluded the `shop` / "撤退:1" branch (`ability_item_usage_generic.lua:5193`,
  `X.IsInvFull(bot) and X.GetNumStashItem(bot) >= 1 ...`) on the strength of a
  1.0s-interval `pre` frame -- the last snapshot at or before the
  `modifier_teleporting` add.  On its two bearing frames, re-dumped at 0.1s,
  the 9th slot fills on the SAME tick as the cast:

    run_121214/20260822_123136_slot3  lina  t=434.5 bag 8/9 -> t=434.6 claymore
      lands, bag 9/9, `ITEM item_tpscroll` fires at 434.6.
    run_121209/20260822_121409_slot8  crystal_maiden  t=526.1 bag 8/9 ->
      t=526.2 clarity lands, bag 9/9, `ITEM item_tpscroll` fires at 526.2.

  `IsInvFull` is a STEP function that a courier delivery flips inside one think
  tick, and the delivery is exactly what makes the "go complete items" branch
  fire.  #121 registered the 1Hz blind window for `hp_pct` (a drifting scalar);
  this is the same window hitting a BOOLEAN GATE, where the bias is not a few
  percentage points but a flipped label.

What this tool measures (and nothing else):
  For every teleport that LANDS at home, on timelines dumped at a fine
  interval, it evaluates `IsInvFull` twice --
    at_cast : the last frame at or before the cast tick   (the truth)
    at_lag  : the last frame at or before cast - LAG      (what a LAG-interval
              sweep could have read as its `pre` frame, worst case)
  and counts the FLIPS (at_cast full, at_lag not full).  A flip is a row that a
  LAG-interval run of `hometp_highhp.py` can mislabel as "not `shop`".

Honest boundaries:
  * This is an UPPER bound on the artifact, not the artifact: a 1.0s sweep's
    `pre` frame lands anywhere in (cast-1.0, cast], so only the flips whose
    fill happened after that particular sample are actually mislabeled.  The
    lower bound is 0 and the tool prints both ends.
  * `IsInvFull` is only ONE of the `shop` branch's clauses; `GetNumStashItem`,
    `GetStashValue`, gold and the bot's mode are not networked into a replay.
    A flip therefore says "the branch is no longer excluded", never "the branch
    fired".
  * "home" is `landing within HOME_U of the team's own ancient`.  The ancient,
    not a fountain centroid: no fountain entity is dumped.  Base-defence TPs
    are inside this ring by construction (same caveat as #120's `defend`).

Usage:
  hometp_invfull_lag.py <dir-of-*.timeline.json>... [--lag 1.0] [--hp 0.55]
  hometp_invfull_lag.py --selfcheck
"""

import argparse
import json
import math
import os
import sys

HOME_U = 2500.0        # landing ring around own ancient
JUMP_U = 3000.0        # a TP landing displaces at least this much
LAND_MAX_S = 6.0       # channel is 3s; allow slack for the landing sample
FULL = "npc_dota_hero_"


def bare(n):
    return n.replace(FULL, "")


def inv_full(snap):
    """X.IsInvFull: slots 0-8 all occupied.  The dump gives exactly 9 slots."""
    items = snap.get("items") or []
    return len(items) == 9 and all(bool(x) for x in items)


def ancients(tl):
    """Per-team ancient position (they never move; take the first sample)."""
    out = {}
    for b in tl.get("buildings", []):
        if b.get("name") == "ancient" and b.get("team") not in out:
            out[b["team"]] = (b["x"], b["y"])
    return out


def frames_by_hero(tl):
    out = {}
    for s in tl.get("snapshots", []):
        out.setdefault(s["hero"], []).append(s)
    for v in out.values():
        v.sort(key=lambda s: s["t"])
    return out


def at_or_before(frames, t):
    """Last frame with frame.t <= t (None if the hero has no such frame)."""
    lo, hi, best = 0, len(frames) - 1, None
    while lo <= hi:
        mid = (lo + hi) // 2
        if frames[mid]["t"] <= t + 1e-9:
            best = frames[mid]
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def episodes(tl, lag):
    """Every teleport that lands at home, with IsInvFull read twice."""
    anc = ancients(tl)
    byhero = frames_by_hero(tl)
    out = []
    for e in tl.get("events", []):
        if e.get("type") != "MODIFIER_ADD" or e.get("inflictor") != "modifier_teleporting":
            continue
        hero = e.get("target") if e.get("target", "").startswith(FULL) else e.get("actor")
        if not hero or not hero.startswith(FULL):
            continue
        frames = byhero.get(hero)
        if not frames:
            continue
        t_cast = e["t"]
        pre = at_or_before(frames, t_cast)
        old = at_or_before(frames, t_cast - lag)
        if pre is None or old is None:
            continue
        # landing = first frame after the cast that jumped far from the cast spot
        land = None
        for s in frames:
            if s["t"] <= t_cast or s["t"] > t_cast + LAND_MAX_S:
                continue
            if math.hypot(s["x"] - pre["x"], s["y"] - pre["y"]) >= JUMP_U:
                land = s
                break
        if land is None:
            continue                      # channel interrupted, or a short hop
        home = anc.get(pre["team"])
        if home is None:
            continue
        if math.hypot(land["x"] - home[0], land["y"] - home[1]) > HOME_U:
            continue                      # a TP to the map, not a trip home
        out.append({
            "hero": bare(hero),
            "t_cast": round(t_cast, 2),
            "hp": pre.get("hp_pct", 0.0),
            "hp_lag": old.get("hp_pct", 0.0),
            "full_at_cast": inv_full(pre),
            "full_at_lag": inv_full(old),
            "slots_at_cast": sum(1 for x in (pre.get("items") or []) if x),
            "slots_at_lag": sum(1 for x in (old.get("items") or []) if x),
        })
    return out


def selfcheck():
    """Synthetic frames only -- no corpus, no AWS.  Each check is a claim the
    body above makes; a failure means the claim is wrong, not the data."""
    ok = True

    def chk(name, cond):
        nonlocal ok
        print("  %-52s %s" % (name, "PASS" if cond else "FAIL"))
        ok = ok and bool(cond)

    nine = ["a"] * 9
    eight = ["a"] * 8 + [""]
    chk("inv_full: 9 filled slots is full", inv_full({"items": nine}))
    chk("inv_full: 8 filled + 1 empty is not full", not inv_full({"items": eight}))
    chk("inv_full: a 6-slot dump is refused, not guessed",
        not inv_full({"items": ["a"] * 6}))

    def mk(t, x, items, team=2, hero=FULL + "lina"):
        return {"t": t, "hero": hero, "team": team, "x": x, "y": 0.0,
                "hp_pct": 1.0, "items": list(items)}

    # the cast sits at t=10.6 so that `cast - lag` is still inside the timeline
    frames = [mk(9.6 + t / 10.0, 0.0, eight) for t in range(0, 10)]
    frames += [mk(10.6, 0.0, nine)]
    frames += [mk(10.0 + t / 10.0, 9000.0, nine) for t in range(7, 40)]
    tl = {
        "snapshots": frames,
        "buildings": [{"name": "ancient", "team": 2, "x": 9000.0, "y": 0.0}],
        "events": [{"t": 10.6, "type": "MODIFIER_ADD", "actor": FULL + "lina",
                    "target": FULL + "lina", "inflictor": "modifier_teleporting"}],
    }
    eps = episodes(tl, lag=1.0)
    chk("a home landing is found", len(eps) == 1)
    chk("the flip is seen (full at cast, not full a lag earlier)",
        eps and eps[0]["full_at_cast"] and not eps[0]["full_at_lag"])
    chk("at_or_before is <=, never the next frame",
        abs(at_or_before(frames, 10.25)["t"] - 10.2) < 1e-9)
    chk("lag frame is the one a lag-interval sweep would read",
        abs(at_or_before(frames, 10.6 - 0.4)["t"] - 10.2) < 1e-9)

    far = json.loads(json.dumps(tl))
    far["buildings"] = [{"name": "ancient", "team": 2, "x": -9000.0, "y": 0.0}]
    chk("a TP that lands away from home is not counted",
        len(episodes(far, lag=1.0)) == 0)

    short = json.loads(json.dumps(tl))
    short["snapshots"] = [s for s in short["snapshots"] if s["x"] < 1.0]
    chk("an interrupted channel (no landing jump) is not counted",
        len(episodes(short, lag=1.0)) == 0)

    two_team = json.loads(json.dumps(tl))
    two_team["buildings"].append({"name": "ancient", "team": 3, "x": 0.0, "y": 0.0})
    chk("the ring is the OWN team's ancient", len(episodes(two_team, lag=1.0)) == 1)
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--lag", type=float, default=1.0,
                    help="the coarse interval whose blind window is being probed")
    ap.add_argument("--hp", type=float, default=0.55,
                    help="the #120 population: hp at cast at or above this")
    ap.add_argument("--analysis", default=None,
                    help="directory of <game>.analysis.json; games whose "
                         "script_version is not a 'mirror:' stamp are WARM-UPS "
                         "(the armed string never took effect) and are skipped")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args()

    if args.selfcheck:
        print("=== selfcheck ===")
        sys.exit(0 if selfcheck() else 1)
    if not args.dirs:
        ap.error("give at least one directory of *.timeline.json (or --selfcheck)")

    rows, games, warm = [], 0, 0
    for d in args.dirs:
        for fn in sorted(os.listdir(d)):
            if not fn.endswith(".timeline.json"):
                continue
            game = fn[:-len(".timeline.json")]
            if args.analysis:
                aj = os.path.join(args.analysis, game + ".analysis.json")
                if not os.path.exists(aj):
                    warm += 1
                    continue
                with open(aj) as fh:
                    if not str(json.load(fh).get("script_version", "")).startswith("mirror:"):
                        warm += 1
                        continue
            with open(os.path.join(d, fn)) as fh:
                tl = json.load(fh)
            games += 1
            for r in episodes(tl, args.lag):
                r["game"] = fn[:-len(".timeline.json")]
                rows.append(r)

    hi = [r for r in rows if r["hp"] >= args.hp]
    flips = [r for r in hi if r["full_at_cast"] and not r["full_at_lag"]]
    full_cast = [r for r in hi if r["full_at_cast"]]
    full_lag = [r for r in hi if r["full_at_lag"]]

    print("=== home TPs, IsInvFull read at the cast tick vs %.1fs earlier ===" % args.lag)
    print("games %d (warm-ups skipped %d) | home TPs %d | at hp >= %.2f: %d"
          % (games, warm, len(rows), args.hp, len(hi)))
    print("  IsInvFull at the cast tick : %d (%.1f%%)"
          % (len(full_cast), 100.0 * len(full_cast) / max(len(hi), 1)))
    print("  IsInvFull %.1fs earlier     : %d (%.1f%%)"
          % (args.lag, len(full_lag), 100.0 * len(full_lag) / max(len(hi), 1)))
    print("  FLIPS (excluded from `shop` by the stale read): %d (%.1f%% of the population)"
          % (len(flips), 100.0 * len(flips) / max(len(hi), 1)))
    # A flip needs the bag to be ONE item short just before it fills.  At an
    # interval coarser than the fill-to-cast gap this tool's own `at_cast` can
    # be stale too, so it under-counts; the rows that are one short AT the cast
    # frame are the only ones a finer re-dump could still turn into flips.
    short1 = [r for r in hi if not r["full_at_cast"] and r["slots_at_cast"] == 8]
    print("  one item short at the cast frame (re-dump candidates): %d (%.1f%%)"
          % (len(short1), 100.0 * len(short1) / max(len(hi), 1)))
    back = [r for r in hi if r["full_at_lag"] and not r["full_at_cast"]]
    print("  reverse flips (bag emptied inside the window): %d" % len(back))
    print("  -> a %.1fs sweep mislabels between 0 and %d of them; its `pre` frame"
          % (args.lag, len(flips)))
    print("     falls anywhere in (cast-%.1f, cast]." % args.lag)
    for r in sorted(flips, key=lambda r: -r["hp"])[:12]:
        print("    %-28s %-16s t=%7.2f hp=%.3f slots %d->%d"
              % (r["game"], r["hero"], r["t_cast"], r["hp"],
                 r["slots_at_lag"], r["slots_at_cast"]))


if __name__ == "__main__":
    main()

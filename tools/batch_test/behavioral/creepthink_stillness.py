#!/usr/bin/env python3
"""creepthink (GH #326) execution check -- the POST-POKE DRAG, on pull frames.

WHAT THE GATE DOES.  `bots/mode_roam_generic.lua:264-266` early-returns out of
Think() when `J.Utils.IsBotThinkingMeaningfulAction` says the hero is busy.  A
hero that just right-clicked sits in ACTIVITY_ATTACK for a whole attack cycle
(1.4-1.7 s in GH #326's own measurement), so on the shipped tree the creep-pull
branch below is NOT REACHED on those frames and THE DRAG ORDER IS NEVER ISSUED
-- the hero stands still while the wave it just aggroed eats it.  Soak candidate
'creepthink' adds `not (bot.roamCreepPull ~= nil and IsSoakCandidate(...))` to
that condition, exempting creep-pull frames from the throttle.

    unarmed  -> poke, then frozen for the attack cycle (GH #326's
                byte-identical coordinates with right-clicks inside)
    armed    -> poke, then the retreat walk actually happens

SO THE READING IS A CONDITIONAL, NOT A RATE:  P(drag | the hero JUST poked).
An unconditional drag rate cannot see this gate: it mixes in the frames where
nobody attacked, which the throttle never touched in either leg.

DOMAIN.  Not re-derived here.  This tool consumes `creeppull_domain.scan_game`,
which already certifies J.ShouldCreepPullLane's observable conjuncts (t<=360,
hp>=0.5, 1-2 enemies near with none extra in the 1000-1800 ring, enemy lane
creeps within 900, an aggro target within 500 of one of them) and, crucially,
resolves J.GetPosition() from the soak seed's own draft rather than the pick
slot (GH #57).  `J.IsCore` is a REAL conjunct of the gate, so `pos <= 3` is
required here -- a support standing in the same shape is NOT in the domain.

THE ONE THING ADDED: "the hero just poked".  creeppull_domain's `poke` field is
TRUE for a hit anywhere in [t-1.0, t+2.0], which includes hits that have not
happened yet at t -- those frames are not inside an attack animation and the
throttle never ate them.  Here the window is [t-BACK, t], i.e. the hero is
inside the attack cycle at t, which is exactly the set the early-return removes.

STRATA (README iron law 4-(i-a)).  The stamped side IS the armed side, so side
bias rides the same axis as the leg.  Every number is printed for the
`:radiant`-stamped and `:dire`-stamped strata separately; the pooled figure is
the arithmetic mean of the two per-stratum contrasts, never weighted by game or
frame counts (4-(i-d)).  This estimator does NOT cancel side bias, so 4-(i-b)
applies to it: two strata disagreeing in sign is noise, not a finding.

CO-ARMED (charter 4a).  On a W47 leg `pullcad` and `pulldrag` are armed inside
the same branch.  `pullcad` changes the BEAT BETWEEN pokes and `pulldrag` the
retreat point; neither decides whether Think() reaches the branch at all, which
is the only thing 'creepthink' changes.  The conjunction is still registered:
this reading is `creepthink` measured on a leg that also carries those two.

EXIT: 0 ran, 2 could not run.  A census, not a gate.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creeppull_domain import (  # noqa: E402
    DRAG_U, Game, canon, load_sweep, scan_game,
)

BACK = 1.0          # a poke in [t-BACK, t] -- the hero is mid-attack-cycle at t
CORE_MAX_POS = 3    # J.IsCore

# WHY A SECOND, SHORTER WINDOW.  creeppull_domain's `drag` integrates
# displacement over DRAG_S = 3.0 s, which is TWICE the attack cycle this gate
# lives inside (1.4-1.7 s, GH #326).  A hero the throttle silences at t is free
# again well before t+3.0, so its walk lands inside the same window as a hero
# that was never silenced: the 3.0 s read CANNOT separate the two legs even if
# the gate works perfectly.  CYCLE_S is the window the mechanism actually
# occupies.  Both are printed -- the 3.0 s column is kept precisely to show that
# it is the blunter instrument, not to be averaged with the sharp one.
CYCLE_S = 1.5
CYCLE_U = 100.0     # DRAG_U scaled to the shorter window (200u over 3.0s)

# THIRD ESTIMATOR, and the only one that even TRIES to see an ORDER rather than
# a displacement.  Displacement after a poke is confounded: an order issued on
# an EARLIER frame keeps executing while the throttle silences Think, so a
# throttled hero still moves.  A path that turns back on itself cannot come
# from an order that was already running -- it needs a NEW one.  So the
# reversal rate is the sharpest dump-side proxy available for "Think reached
# the branch and issued the drag".
#   ** IT IS STILL NOT A PROOF, and the tool says so in its own output. **
# mode_roam_generic's throttle guards only THIS mode's Think(); retreat/laning
# modes run their own and can turn the hero around on the same frame.  A
# reversal therefore proves "some mode issued an order", never "the creep-pull
# branch did".  Which is why a null here is reported as INDETERMINATE and never
# as SILENT -- see the header of report 20260905T09xxZ.
REV_MOVE_U = 60.0   # each leg of the path must be a real move, not idle jitter


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sweeps", nargs="+")
    ap.add_argument("--frames", action="store_true",
                    help="print every post-poke pull frame (逐帧 before 聚合)")
    ap.add_argument("--back", type=float, default=BACK)
    a = ap.parse_args()

    games = []
    for d in a.sweeps:
        for m in load_sweep(d):
            tl = os.path.join(d, "timelines", m["game"] + ".timeline.json")
            an = os.path.join(d, "analysis", m["game"] + ".analysis.json")
            if not os.path.exists(tl):
                print("[warn] missing timeline %s" % tl, file=sys.stderr)
                continue
            games.append((Game(tl, an, m["side"]), m["game"], m["seed"],
                          m["side"]))
    if not games:
        print("CT_COULD_NOT_RUN: no games", file=sys.stderr)
        return 2

    cand = json.loads(open(os.path.join(
        a.sweeps[0], "games_manifest.jsonl")).readline())["cand"]
    armed_here = "creepthink" in cand.split(",")
    print("corpus: %d games; 'creepthink' in cand string: %s"
          % (len(games), armed_here))
    if not armed_here:
        print("[note] 'creepthink' is NOT armed in this corpus -- the "
              "armed/baseline contrast below is measuring the OTHER ids on the "
              "leg, not this one. Do not read it as a creepthink verdict.")

    strata = {"radiant": defaultdict(lambda: dict(n=0, drag=0, dragsum=0.0,
                                                  cyc=0, cycsum=0.0, cycn=0,
                                                  rev=0, revn=0)),
              "dire": defaultdict(lambda: dict(n=0, drag=0, dragsum=0.0,
                                               cyc=0, cycsum=0.0, cycn=0,
                                               rev=0, revn=0))}
    rows_out = []
    for g, name, seed, side in games:
        for r in scan_game(g, name, seed):
            if not r["clean"] or not r["pos"] or r["pos"] > CORE_MAX_POS:
                continue
            hits = g.dmg.get((r["hero"], r["tgt"]), ())
            if not any(r["t"] - a.back <= et <= r["t"] for et in hits):
                continue
            acc = strata[side][r["leg"]]
            acc["n"] += 1
            acc["dragsum"] += r["drag"]
            if r["drag"] >= DRAG_U:
                acc["drag"] += 1
            # --- the sharp window: displacement inside the attack cycle only.
            # Same projection as creeppull_domain (toward our own fountain), so
            # the two columns differ ONLY in the integration window.
            fr = g.frames[r["hero"]]
            s0, s1 = fr.get(r["t"]), fr.get(r["t"] + CYCLE_S)
            r["cyc"] = None
            if s0 and s1 and s1["hp_pct"] > 0 and g.clean_window(
                    r["hero"], r["t"], r["t"] + CYCLE_S):
                fx, fy = g.fountain[g.teams[r["hero"]]]
                dx, dy = fx - s0["x"], fy - s0["y"]
                n = max((dx * dx + dy * dy) ** 0.5, 1.0)
                r["cyc"] = round(((s1["x"] - s0["x"]) * dx
                                  + (s1["y"] - s0["y"]) * dy) / n)
                acc["cycn"] += 1
                acc["cycsum"] += r["cyc"]
                if r["cyc"] >= CYCLE_U:
                    acc["cyc"] += 1
            # --- reversal: did the path turn back on itself across t?
            s_pre = fr.get(r["t"] - CYCLE_S)
            r["turn"] = None
            if (s_pre and s0 and s1 and s_pre["hp_pct"] > 0 and s1["hp_pct"] > 0
                    and g.clean_window(r["hero"], r["t"] - CYCLE_S,
                                       r["t"] + CYCLE_S)):
                v1 = (s0["x"] - s_pre["x"], s0["y"] - s_pre["y"])
                v2 = (s1["x"] - s0["x"], s1["y"] - s0["y"])
                n1 = (v1[0] ** 2 + v1[1] ** 2) ** 0.5
                n2 = (v2[0] ** 2 + v2[1] ** 2) ** 0.5
                if n1 >= REV_MOVE_U and n2 >= REV_MOVE_U:
                    cos = (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)
                    r["turn"] = cos
                    acc["revn"] += 1
                    if cos < 0.0:          # turned more than 90 degrees
                        acc["rev"] += 1
            r["side"] = side
            rows_out.append(r)

    print("post-poke core pull frames: %d" % len(rows_out))
    if args_frames := a.frames:
        print("\n-- post-poke frames (逐帧, hard rule: read these before the "
              "table below) --")
        for r in sorted(rows_out, key=lambda r: (r["game"], r["t"])):
            print("  %-30s t=%6.1f %-20s pos%s %-8s hp=%.2f tgt=%-18s "
                  "d=%-4d drag=%+5d %s"
                  % (r["game"], r["t"], canon(r["hero"]), r["pos"], r["leg"],
                     r["hp"], canon(r["tgt"]), r["tgt_d"], r["drag"],
                     "DRAG" if r["drag"] >= DRAG_U else "still"))
    del args_frames

    for label, key, kn, thr, win in (
            ("BLUNT  P(drag>=%du over %.1fs | just poked, core, pull domain)"
             % (DRAG_U, 3.0), "drag", "n", DRAG_U, 3.0),
            ("SHARP  P(walk>=%du over %.1fs | just poked, core, pull domain)"
             % (CYCLE_U, CYCLE_S), "cyc", "cycn", CYCLE_U, CYCLE_S),
            ("ORDER-PROXY  P(path reverses >90deg across the poke)",
             "rev", "revn", None, CYCLE_S)):
        print("\n-- %s --" % label)
        if win == 3.0:
            print("   (window is 2x the attack cycle the gate lives in -- kept "
                  "to show it cannot resolve this gate, NOT as a reading)")
        contrasts = []
        for side in ("radiant", "dire"):
            parts, vals = ["  stamp=:%-8s" % side], {}
            for leg in ("armed", "baseline"):
                c = strata[side][leg]
                n = c[kn]
                p = (c[key] / n) if n else None
                vals[leg] = p
                tot = {"drag": "dragsum", "cyc": "cycsum"}.get(key)
                md = (c[tot] / n) if (n and tot) else None
                parts.append("%s: n=%-4d p=%s mean=%s"
                             % (leg, n,
                                ("%.3f" % p) if p is not None else " n/a",
                                ("%+6.0fu" % md) if md is not None
                                else "   n/a"))
            if vals["armed"] is not None and vals["baseline"] is not None:
                d = vals["armed"] - vals["baseline"]
                contrasts.append(d)
                parts.append("delta=%+.3f" % d)
            print("   ".join(parts))
        if len(contrasts) == 2:
            print("  swap-averaged delta = %+.3f  [arithmetic mean of the two "
                  "strata, never count-weighted -- iron law 4-(i-d)]"
                  % (sum(contrasts) / 2))
            if contrasts[0] * contrasts[1] < 0:
                print("  ** THE TWO STRATA DISAGREE IN SIGN. ** This estimator "
                      "does not cancel side bias (no per-seed 50/50 swap "
                      "inside it), so iron law 4-(i-b) applies: NOISE, not a "
                      "conclusion. Registered per 4-(i-a).")
        else:
            print("  swap-average NOT computable -- a stratum is empty; no "
                  "pooled number is printed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""`idle fountain round trip` -- codifies the SHAPE found on W29, 2026-08-30T21:58Z.

WHY THIS TOOL EXISTS
--------------------
The 21:58Z round went looking for `stayfield2`'s domain and found something
else on the way: on 10 W29 games, **127 of 155 walk-home trips departed at
hp > 0.90**, and 96% of those were back beyond 4000u inside 60 seconds.  The
hand reading in that report's §4 was:

    127 trips / 10 games; 122 (96%) back out past 4000u within 60s;
    round trip median 38s / p75 47s / max 72s; 4,638s over 10 games
    = 464 hero-seconds per game.  Mana does not explain it (departure mp
    median 1.00; whole-trip mp gain median +0.00; only 1/127 gained
    >= +0.25).  Items do not explain the bulk either (inventory completely
    unchanged on 51%).  "Pure idle" -- full hp AND full mp AND zero
    inventory change -- was 32%.

That reading was **hand-computed out of another tool's trip dump**, which is
exactly the state GH #243 keeps catching: a number nobody in the tree can
reproduce next week.  The charter's own next-round line called it out --
"把 §4 的形状 codify 成检测器 …… 这比再核一个零域 id 值钱".  This file is that
detector.

WHAT IT IS NOT
--------------
⭐⭐⭐ **THIS IS NOT AN ARMED-ID PROBE, AND IT MUST NEVER BE READ AS ONE.**
Every sibling in this directory (`stayfield_domain.py`, `stayfield2_whynot.py`,
`fieldcreep_domain.py`, ...) exists to buy condition (a) for ONE gate id, and
each of them refuses to run when its id is missing from the wave's arm string.
This one measures **stable-version default behaviour**: the shape appeared on
BOTH legs in BOTH strata on W29, so it is not the product of any armed id and
not a side artefact either.  It therefore:

  * takes no `CAND_ID` and refuses nothing on arm-string grounds;
  * still prints the arm string and still refuses a MIXED-string corpus
    (two engines in one pool have no single right reading);
  * prints all four (stratum x leg) cells for every headline number, because
    a count is an estimator with the physical-side term still in it
    (铁律 4(i-b)) and the only defensible claim from a counting estimator is
    the one that survives in all four cells.

The claim this tool is built to support or refute is therefore NOT
"armed minus baseline is X".  It is: **"this behaviour is present at
comparable rate in all four cells"** -- which is a statement about the shipped
default, and is the one shape a side-uncancelled counter can actually carry.

THE POPULATION, AND THE FIVE TRAPS IT INHERITS
----------------------------------------------
A *round trip* = a continuous WALK from beyond FAR_U into the hero's own
fountain ring, followed by a continuous WALK back out beyond FAR_U within
RETURN_WINDOW_S of arrival.

Both legs use the same continuity discipline as
`stayfield2_margin.homeward_close`, and for the same reasons recorded there --
the scan **terminates, never skips**, at the first of: death, TP channel,
corpse frame, sampling gap, or a step faster than a hero can walk.  Three
earlier versions of that function died by skipping a frame:

  * a RESPAWN scored as "walked home" (the corpse frame was skipped);
  * a TP SCROLL scored as "walked home" (that is `stayfield`'s call site,
    not this behaviour);
  * and on the way back out, a TP OUT would score as "walked back" -- which
    is the opposite of the claim, because a bot that TPs out did not burn
    the walk.  Those rows are counted separately as `tp_out`.

Identity comes from `stayfield_domain.Game`, which locks each hero to its
primary `idx` (GH #176: illusions carry the same name AND the same
`player_id`, differing only in `idx`; 30% of a 60-game sample was polluted).
Liveness comes from real death events plus `hp_pct > 0`, never from
interpolated hp (GH #176 again).

⭐ THE DEPARTURE ANCHOR IS THE TURNAROUND, NOT THE FIRST FAR FRAME.
Copied deliberately from `stayfield2_whynot.walk_home_trips`, including its
constant: anchoring on "first gap-free frame beyond FAR_U" scored a
spiritbreaker who was Nether-Striking INTO a fight as having "decided to go
home" at hp 0.416.  The anchor must be the decision instant.  We walk back
from arrival across the monotone homeward descent (MONO_SLACK_U of pathing
wobble tolerated) and take its start.

THE EXPLANATION LADDER
----------------------
Each round trip gets its FIRST available explanation, in this fixed order --
the same first-failing-clause discipline the siblings use, for the same
reason (a trip that is both hurt and shopping must land in exactly one cell,
or the columns stop summing):

  1. `hurt`      hp at departure <= HP_FULL          -> going home to heal
  2. `mana`      mp at departure <  MP_FULL          -> going home for mana
  3. `shopping`  usable inventory changed over the trip (GH #120's
                 BOT_MODE_ITEM stash-fetch path lands here)
  4. `idle`      none of the above  <- THE FINDING

`idle` is the conservative cell by construction: every ambiguity above it is
resolved AGAINST calling a trip pointless.  `hp_min` over the whole round trip
is reported alongside, because a trip that left at full hp and got chewed on
the way is a different story and the reader must be able to see it.

Usage:
    idletrip_domain.py <sweep_dir> [...] [--interval 1.0]
    idletrip_domain.py <sweep_dir> [...] --frames [--limit N]
    idletrip_domain.py --selfcheck <sweep_dir> [...]
"""
import argparse
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import stayfield_domain as SD                                   # noqa: E402
from stayfield_domain import (                                  # noqa: E402
    Game, SIDE_TEAM, load_sweeps, usable_items, FOUNTAIN_NEAR_U,
)
from stayfield2_margin import FAR_U, WALK_CAP_U                 # noqa: E402
from stayfield2_whynot import MONO_SLACK_U                      # noqa: E402

# --- this tool's own constants -------------------------------------------
# NOT source constants: no gate reads any of these.  They are the operational
# definition of "went home for nothing", chosen to match the 21:58Z hand
# reading so the two can be compared, and exposed as flags so a reader can
# see how sensitive a headline is to them.
RETURN_WINDOW_S = 60.0     # 21:58Z: 96% of the 127 were back out inside this
HP_FULL = 0.90             # 21:58Z: the departure-hp cut that isolated the 127
MP_FULL = 0.90             # 21:58Z: "满蓝" -- mana is not why they went

EXPLANATIONS = ["hurt", "mana", "shopping", "idle"]


def continuity_break(g, hero, prev, cur, tp_open):
    """Why the walking trace ends between `prev` and `cur`, or None.

    ⭐ Callers must TERMINATE on a non-None answer, never `continue` past it.
    Every historical bug in this family came from carrying on with `prev`
    reset, which disarms the displacement guard on the very frame that had
    teleported.
    """
    gap = cur["t"] - prev["t"]
    if gap > g.interval + 1e-6:
        return "gap"
    if cur["hp_pct"] <= 0:
        return "corpse"
    if any(prev["t"] < td <= cur["t"] for td in g.deaths.get(hero, ())):
        return "death"
    if any(prev["t"] < a <= cur["t"] for a in tp_open):
        return "tp"
    if SD.dist(prev["x"], prev["y"], cur["x"], cur["y"]) > WALK_CAP_U * max(gap, 1e-6):
        return "jump"
    return None


def explain(hp0, mp0, inv0, inv_end):
    """First available explanation for the trip.  Order is load-bearing."""
    if hp0 <= HP_FULL:
        return "hurt"
    if mp0 < MP_FULL:
        return "mana"
    if sorted(inv0) != sorted(inv_end):
        return "shopping"
    return "idle"


def round_trips(g, side):
    """Every continuous walk home, with its return leg scored if there is one.

    One row per HOME ARRIVAL.  Rows with `returned=False` are trips the bot did
    not walk back out of within RETURN_WINDOW_S -- they are kept (a bot that
    went home and stayed there is not this shape) but never counted as idle.
    """
    armed_team = SIDE_TEAM[side]
    out = []
    for hero, tr in g.track.items():
        tp_open = [a for (a, _b) in g.tp_spans(hero)]
        i, n = 0, len(tr)
        while i < n:
            s = tr[i]
            d = g.dist_fountain(s)
            if d is None or d <= FAR_U or s["hp_pct"] <= 0:
                i += 1
                continue
            # ---- outbound: walk toward the fountain, terminating on any break
            j, prev, arrived = i + 1, s, None
            while j < n:
                cur = tr[j]
                if continuity_break(g, hero, prev, cur, tp_open):
                    break
                dc = g.dist_fountain(cur)
                if dc is not None and dc <= FOUNTAIN_NEAR_U:
                    arrived = cur
                    break
                prev = cur
                j += 1
            if arrived is None:
                i += 1
                continue
            # ---- anchor correction: back up over the monotone descent -------
            k = j
            while k - 1 >= i:
                dk = g.dist_fountain(tr[k])
                dp = g.dist_fountain(tr[k - 1])
                if dk is None or dp is None or dp < dk - MONO_SLACK_U:
                    break
                k -= 1
            s = tr[k]
            d = g.dist_fountain(s)
            if d is None or d <= FAR_U:
                i = j + 1
                continue
            i_anchor = k
            # ---- return leg: walk back out past FAR_U, same discipline ------
            deadline = arrived["t"] + RETURN_WINDOW_S
            m, prev = j, arrived
            returned, out_break, dwell_end = None, None, arrived["t"]
            while m + 1 < n:
                cur = tr[m + 1]
                if cur["t"] > deadline:
                    out_break = "window"
                    break
                br = continuity_break(g, hero, prev, cur, tp_open)
                if br:
                    out_break = "tp_out" if br == "tp" else br
                    break
                dc = g.dist_fountain(cur)
                if dc is not None and dc <= FOUNTAIN_NEAR_U:
                    dwell_end = cur["t"]
                if dc is not None and dc > FAR_U:
                    returned = cur
                    break
                prev = cur
                m += 1
            end_frame = returned if returned is not None else prev
            hp0 = s["hp_pct"]
            mp0 = s.get("mp_pct")
            inv0 = usable_items(s)
            inv_end = usable_items(end_frame)
            # A timeline without mp is not evidence of full mana.  Scoring a
            # missing field as 1.0 would push those trips INTO `idle`, i.e.
            # toward the finding -- so a missing field disqualifies the row
            # from `idle` instead, and is disclosed in the header.
            mp_known = mp0 is not None
            why = explain(hp0, mp0 if mp_known else 0.0, inv0, inv_end)
            span = [x for x in tr[i_anchor:m + 2] if x["hp_pct"] > 0]
            out.append({
                "hero": hero,
                "t0": s["t"], "t_arrive": arrived["t"],
                "t_return": returned["t"] if returned is not None else None,
                "dwell": dwell_end - arrived["t"],
                "d0": d,
                "hp0": hp0, "mp0": mp0, "mp_known": mp_known,
                "mp_end": end_frame.get("mp_pct"),
                "hp_min": min([x["hp_pct"] for x in span] or [hp0]),
                "inv0": inv0, "inv_end": inv_end,
                "returned": returned is not None,
                "out_break": out_break,
                "why": why,
                "team": s["team"],
                "phys": "radiant" if s["team"] == SIDE_TEAM["radiant"] else "dire",
                "leg": "armed" if s["team"] == armed_team else "baseline",
            })
            i = j + 1
    return out


# --------------------------------------------------------------------------
def cells(rows):
    """The four (stratum x leg) buckets, in a fixed printing order."""
    return [(("ab" if side == "radiant" else "ba") + "/" + leg,
             [r for r in rows if r["_side"] == side and r["leg"] == leg])
            for side in ("radiant", "dire")
            for leg in ("armed", "baseline")]


def _med(vals):
    return statistics.median(vals) if vals else None


def _f(v, fmt="%.1f"):
    return "n/a" if v is None else fmt % v


def report(rows, games):
    ngames = len(games)
    idle = [r for r in rows if r["returned"] and r["why"] == "idle"]
    rt = [r for r in rows if r["returned"]]
    print("== idle fountain round trips (SHIPPED-DEFAULT behaviour probe) ==")
    print("population: continuous WALK home (>%.0fu -> %.0fu ring) + continuous"
          % (FAR_U, FOUNTAIN_NEAR_U))
    print("            WALK back out past %.0fu within %.0fs of arrival."
          % (FAR_U, RETURN_WINDOW_S))
    print("            TP in or out terminates the trace (other call sites).")
    print("cuts: hp>%.2f at departure, mp>=%.2f at departure, inventory"
          % (HP_FULL, MP_FULL))
    print("      unchanged across the trip.  First-explanation ladder: %s"
          % " > ".join(EXPLANATIONS))
    print("games: %d   walks home: %d   round trips: %d   IDLE round trips: %d"
          % (ngames, len(rows), len(rt), len(idle)))
    nomp = sum(1 for r in rows if not r["mp_known"])
    print("timelines without mp_pct: %d rows (disqualified from `idle`, never"
          % nomp)
    print("      scored as full mana -- the conservative direction)")
    print("")

    # ---- 铁律 4(i-a): every cell disclosed, no pooling ---------------------
    print("-- per (stratum x leg).  A COUNT DOES NOT CANCEL THE SIDE TERM:")
    print("   the only claim this table can carry is 'present in all four',")
    print("   never 'armed minus baseline = X'. (铁律 4(i-b))")
    hdr = "%-12s %6s %6s %6s %7s %8s %8s" % (
        "cell", "games", "walks", "rtrip", "IDLE", "idle/gm", "sec/gm")
    print(hdr)
    for name, sub in cells(rows):
        side = "radiant" if name.startswith("ab") else "dire"
        gn = sum(1 for gg in games if gg[4] == side)
        sub_rt = [r for r in sub if r["returned"]]
        sub_id = [r for r in sub_rt if r["why"] == "idle"]
        secs = sum(r["t_return"] - r["t0"] for r in sub_id)
        print("%-12s %6d %6d %6d %7d %8s %8s" % (
            name, gn, len(sub), len(sub_rt), len(sub_id),
            _f(len(sub_id) / gn if gn else None, "%.2f"),
            _f(secs / gn if gn else None, "%.0f")))
    print("")

    # ---- explanation ladder, per cell -------------------------------------
    print("-- first explanation for each ROUND TRIP (columns sum to rtrip) --")
    print("%-12s %8s %8s %10s %8s" % ("cell", "hurt", "mana", "shopping", "IDLE"))
    for name, sub in cells(rows):
        sub_rt = [r for r in sub if r["returned"]]
        row = [sum(1 for r in sub_rt if r["why"] == w) for w in EXPLANATIONS]
        pct = [100.0 * c / max(len(sub_rt), 1) for c in row]
        print("%-12s %8s %8s %10s %8s" % (
            name,
            "%d (%.0f%%)" % (row[0], pct[0]), "%d (%.0f%%)" % (row[1], pct[1]),
            "%d (%.0f%%)" % (row[2], pct[2]), "%d (%.0f%%)" % (row[3], pct[3])))
    print("")

    # ---- 铁律 4(ii): counts get mean + distribution, not a bare median -----
    print("-- IDLE round trip shape (mean + distribution; 铁律 4(ii)) --")
    if idle:
        durs = [r["t_return"] - r["t0"] for r in idle]
        dwells = [r["dwell"] for r in idle]
        print("   duration  mean %.1fs  median %.1fs  p75 %.1fs  max %.1fs"
              % (sum(durs) / len(durs), _med(durs),
                 sorted(durs)[int(0.75 * (len(durs) - 1))], max(durs)))
        print("   dwell     mean %.1fs  median %.1fs  max %.1fs"
              % (sum(dwells) / len(dwells), _med(dwells), max(dwells)))
        print("   hp_min over the round trip: >0.90 on %d/%d (%.0f%%)"
              % (sum(1 for r in idle if r["hp_min"] > HP_FULL), len(idle),
                 100.0 * sum(1 for r in idle if r["hp_min"] > HP_FULL) / len(idle)))
        mg = [r["mp_end"] - r["mp0"] for r in idle
              if r["mp_known"] and r["mp_end"] is not None]
        if mg:
            print("   mp gain across the trip: median %+.2f   >=+0.25 on %d/%d"
                  % (_med(mg), sum(1 for v in mg if v >= 0.25), len(mg)))
        print("   TOTAL idle hero-seconds: %.0f over %d games = %.0f s/game"
              % (sum(durs), ngames, sum(durs) / max(ngames, 1)))
    else:
        print("   none on this corpus")
    print("")

    print("-- walks home that did NOT walk back out (not this shape) --")
    br = {}
    for r in rows:
        if not r["returned"]:
            key = r["out_break"] or "trace_end"
            br[key] = br.get(key, 0) + 1
    print("   " + ("  ".join("%s=%d" % kv for kv in sorted(br.items()))
                   if br else "none"))
    print("")

    # ---- reproduction of the 2026-08-30T21:58Z hand reading ---------------
    # ⭐ This block exists so the detector can DISAGREE with the report that
    # motivated it, out loud.  A tool that only ever confirms the number it
    # was built from is not a check.
    hi = [r for r in rows if r["hp0"] > HP_FULL]
    hi_ret = [r for r in hi if r["returned"]]
    hi_secs = sum(r["t_return"] - r["t0"] for r in hi_ret)
    print("-- 21:58Z hand reading, recomputed on the same corpus --")
    print("   walks home with departure hp>%.2f : %d   (hand: 127)"
          % (HP_FULL, len(hi)))
    print("   ...of those, back out past %.0fu inside %.0fs : %d (%.0f%%)"
          % (FAR_U, RETURN_WINDOW_S, len(hi_ret),
             100.0 * len(hi_ret) / max(len(hi), 1)))
    print("      (hand: 122 = 96%)")
    print("   their hero-seconds: %.0f over %d games = %.0f s/game  (hand: 464)"
          % (hi_secs, ngames, hi_secs / max(ngames, 1)))
    print("   after the explanation ladder peels off `mana` and `shopping`,")
    print("   the defensible subset is IDLE: %.0f s/game."
          % (sum(r["t_return"] - r["t0"] for r in
                 [x for x in rows if x["returned"] and x["why"] == "idle"])
             / max(ngames, 1)))
    # ⭐ The correction is to the ESTIMATOR, not to the problem.  A hero who
    # walks 11,607u home at full hp and then scrolls out did not walk back --
    # but he did walk there.  The OUTBOUND leg is burnt either way, and it is
    # the honest superset cost, so it is printed next to the other two rather
    # than left for a reader to reconstruct.
    outbound = sum(r["t_arrive"] - r["t0"] for r in hi)
    tp_out = sum(1 for r in hi if r["out_break"] == "tp_out")
    print("   OUTBOUND walk only, all hp>%.2f walks home (returned or not):"
          % HP_FULL)
    print("      %.0f s over %d games = %.0f s/game   (%d of them ended in a"
          % (outbound, ngames, outbound / max(ngames, 1), tp_out))
    print("      TP OUT -- walked there, scrolled back)")


def frames(rows, limit):
    print("%-8s %-26s %-18s %7s %7s %5s %5s %6s %6s %-9s"
          % ("run", "game", "hero", "t0", "t_ret", "hp0", "mp0", "hpmin",
             "dwell", "why"))
    sel = [r for r in rows if r["returned"] and r["why"] == "idle"]
    sel.sort(key=lambda r: -(r["t_return"] - r["t0"]))
    for r in sel[:limit]:
        print("%-8s %-26s %-18s %7.1f %7.1f %5.2f %5s %6.2f %6.1f %-9s"
              % (r["_run"][:8], r["_game"], r["hero"], r["t0"], r["t_return"],
                 r["hp0"], _f(r["mp0"], "%.2f"), r["hp_min"], r["dwell"],
                 r["why"]))


# --------------------------------------------------------------------------
def selfcheck(games, interval):
    """Corpus assertions.  Every one of these is a way the tool can go wrong
    while still printing a plausible table."""
    checks = []

    def chk(name, cond, why=""):
        checks.append((name, bool(cond)))
        print("  %-62s %s%s" % (name, "ok" if cond else "FAIL",
                                "  " + why if why else ""))

    rows = []
    for run, game, _c, _s, side, tl in games:
        g = Game(tl, interval)
        for r in round_trips(g, side):
            r["_run"], r["_game"], r["_side"] = run, game, side
            rows.append(r)

    chk("corpus produced walk-home rows", len(rows) > 0, "%d rows" % len(rows))
    chk("every row departs beyond FAR_U",
        all(r["d0"] > FAR_U for r in rows))
    chk("every returned row returns after it arrives",
        all(r["t_return"] > r["t_arrive"] for r in rows if r["returned"]))
    chk("every returned row is inside the return window",
        all(r["t_return"] - r["t_arrive"] <= RETURN_WINDOW_S + 1e-6
            for r in rows if r["returned"]))
    chk("arrival never precedes departure",
        all(r["t_arrive"] > r["t0"] for r in rows))
    chk("explanations partition the round trips",
        sum(1 for r in rows if r["returned"])
        == sum(1 for r in rows if r["returned"] and r["why"] in EXPLANATIONS))
    idle = [r for r in rows if r["returned"] and r["why"] == "idle"]
    chk("no idle row departed hurt", all(r["hp0"] > HP_FULL for r in idle))
    chk("no idle row changed its inventory",
        all(sorted(r["inv0"]) == sorted(r["inv_end"]) for r in idle))
    chk("no idle row has unknown mana", all(r["mp_known"] for r in idle))
    # ⭐ The one that would catch a skipped discontinuity: a round trip cannot
    # be shorter than the time it physically takes to cover 2*(d0-ring) at the
    # walk cap.  A skipped TP or respawn shows up here and nowhere else.
    bad = [r for r in rows if r["returned"]
           and (r["t_return"] - r["t0"]) * WALK_CAP_U
           < 2.0 * (r["d0"] - FOUNTAIN_NEAR_U) - 1.0]
    chk("no round trip covers ground faster than a hero can walk",
        not bad, "%d violations" % len(bad))
    ok = sum(1 for _n, r in checks if r)
    print("selfcheck: %d/%d" % (ok, len(checks)))
    return ok == len(checks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--limit", type=int, default=30)
    a = ap.parse_args()

    games = load_sweeps(a.dirs)
    if a.selfcheck:
        sys.exit(0 if selfcheck(games, a.interval) else 1)

    # ---- MANDATORY disclosure block ---------------------------------------
    # It prints on every run, including the boring one.  A reader who cannot
    # see it must conclude the tool did not check, never that there was
    # nothing to check (铁律 10's SKIP/UNCERTIFIABLE wording, applied to a
    # tool's own preconditions).
    cands = set(r[2] for r in games)
    print("=== arm-string disclosure ===")
    if len(cands) != 1:
        sys.exit("[fatal] mixed cand strings in this corpus (%d distinct) -- "
                 "two engines in one pool have no single right reading:\n  %s"
                 % (len(cands), "\n  ".join(sorted(cands))))
    cand = cands.pop()
    armed_ids = [c.strip() for c in cand.split(",") if c.strip()]
    print("  uniform, %d ids: %s" % (len(armed_ids), cand))
    print("  ** THIS TOOL SCORES NO GATE. **  It measures shipped-default")
    print("  behaviour on BOTH legs.  The arm string is printed so a later")
    print("  reader can tell which engine produced the corpus and refuse to")
    print("  pool two different ones -- NOT because any id here is armed.")
    print("")

    rows = []
    for run, game, _c, _s, side, tl in games:
        g = Game(tl, a.interval)
        for r in round_trips(g, side):
            r["_run"], r["_game"], r["_side"] = run, game, side
            rows.append(r)

    if a.frames:
        frames(rows, a.limit)
    else:
        report(rows, games)


if __name__ == "__main__":
    main()

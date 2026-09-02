#!/usr/bin/env python3
"""Stratified (ab/ba) re-read of a wide sweep's detector table.

WHY THIS FILE EXISTS (replay-check 2026-09-02)
-----------------------------------------------
`sweep_run.sh` writes ONE pooled detector table per run:

    detector          hits   on-cand   on-base
    lowhp_chase        212       104       108

That table is the thing 铁律 4(i) forbids reading on its own.  Every game
in a mirrored wave arms the candidate on ONE physical side, and the stamp
records which:

    mirror:<ids>:s<seed>:radiant   -> the `ab` leg (armed = radiant)
    mirror:<ids>:s<seed>:dire      -> the `ba` leg (armed = dire)

(that mapping is `recover_verdict.py:279-281`, not a convention invented
here).  So a pooled `on-cand vs on-base` column is `arm effect + side
effect`, and Radiant-side bias in this game is worth about +1.5k gold --
big enough to BE the whole reading.  Six rounds of this stream registered
`ab_games`/`ba_games` (COUNTS) and thought they had discharged 4(i-a);
GH #329 is that correction, and rule 4(i-a) now says in so many words:
**读数不是局数**.  This file publishes the READINGS.

The charter has carried "§5 宽扫表按 ab/ba 重打" as an open debt for
three consecutive rounds,每轮顺延, because doing it by hand is tedious --
which is the #263 shape (a read that is not in the tree is a read the next
round redoes, and redoes differently).  Hence a tool.

WHAT IT COMPUTES
----------------
Per detector, per seed, using PER-GAME RATES (never raw counts -- the two
legs have unequal game counts and 4(i-d) forbids pooling weighted by games):

    r_ab = (cand_hits_ab - base_hits_ab) / n_games_ab      # armed = radiant
    r_ba = (cand_hits_ba - base_hits_ba) / n_games_ba      # armed = dire
    arm  = (r_ab + r_ba) / 2      # side-bias ELIMINATED  -> 4(i-c)
    side = (r_ab - r_ba) / 2      # what the swap-average removed

then the ACROSS-SEED number is the arithmetic mean of the per-seed `arm`
values -- per-seed swap-average FIRST, arithmetic mean SECOND, never a
games-weighted pool (4(i-d), pinned in tests/test_verdict_strata.py).

HOW TO READ THE OUTPUT (the part that is a rule, not a preference)
------------------------------------------------------------------
* `r_ab` / `r_ba` are side-bias-UNCORRECTED estimators.  4(i-b): if they
  have opposite signs, that is noise -- register it, do not conclude from
  it.  The tool marks such rows `FLIP`.
* `arm` IS side-bias-eliminated.  4(i-c): a FLIP is NOT a veto on it.
  `FLIP <=> |side| > |arm|` is an identity, not a diagnosis; what governs
  precision is `arm`'s own dispersion across seeds (`seeds_neg`, `sd`).
* Both strata's readings are printed on every row whether or not they
  agree -- that is 4(i-a), and it is unconditional.

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **No number here is an effect size for any single id.**  A wave arms
   the whole declared set at once; `arm` is a WHOLE-BUNDLE reading.
2. **Detector counts are not behaviour.**  A detector firing more on the
   armed side may mean the fix works and the detector is aimed at the
   old shape, or that the fix is harmful.  WORKING/BUGGY/SILENT is a
   frame-level question this tool cannot answer (same limit as
   arm_string_census.py:2).
3. **`unk` (hero not resolvable to a team) is printed, never dropped.**
   Dropping it would silently shrink the denominator.
4. A seed with an empty leg (`NO-PAIR`) contributes NOTHING -- it cannot
   be swap-averaged, and half of a swap-average is a side reading.
5. Rates are per GAME, not per minute; a wave whose two legs have very
   different game lengths violates that implicit normalisation.

EXIT CODES (GH #171 vocabulary: "could not run" is not "passed")
    0  clean    -- a table was produced
    2  refused  -- no usable input (no findings, no manifest, no paired seed)
    3  findings -- produced a table AND at least one structural complaint
                   (a seed with an empty leg, or unresolved-team findings)
"""

import argparse
import collections
import json
import os
import sys

EXIT_CLEAN, EXIT_REFUSED, EXIT_FINDINGS = 0, 2, 3

# recover_verdict.py:279-281 -- the stamp's side IS the leg name.
AB, BA = "radiant", "dire"


def load(dirs):
    """-> (findings, games).  Both are lists of dicts; missing files are
    counted as missing, never as empty."""
    findings, games, missing = [], [], []
    for d in dirs:
        fp = os.path.join(d, "all_findings.jsonl")
        gp = os.path.join(d, "games_manifest.jsonl")
        if not os.path.exists(fp) or not os.path.exists(gp):
            missing.append(d)
            continue
        with open(fp) as fh:
            findings += [json.loads(l) for l in fh if l.strip()]
        with open(gp) as fh:
            games += [json.loads(l) for l in fh if l.strip()]
    return findings, games, missing


def tabulate(findings, games):
    """-> (rows, complaints).  One row per detector."""
    complaints = []

    # games per (seed, leg)
    ngames = collections.Counter((g["seed"], g["side"]) for g in games)
    seeds = sorted({g["seed"] for g in games})
    paired = [s for s in seeds if ngames[(s, AB)] and ngames[(s, BA)]]
    for s in seeds:
        if s not in paired:
            complaints.append(
                "seed %s has an empty leg (ab=%d ba=%d) -- contributes nothing "
                "(LIMIT 4)" % (s, ngames[(s, AB)], ngames[(s, BA)]))

    # hits per (detector, seed, leg, which side of the mirror)
    hits = collections.Counter()
    unk = collections.Counter()
    for f in findings:
        key = (f["detector"], f["seed"], f["side"])
        if f.get("on_candidate_side") is True:
            hits[key + ("cand",)] += 1
        elif f.get("on_candidate_side") is False:
            hits[key + ("base",)] += 1
        else:
            unk[f["detector"]] += 1
    if unk:
        complaints.append(
            "unresolved hero->team on %d finding(s) across %d detector(s): %s "
            "-- printed as `unk`, never dropped (LIMIT 3)"
            % (sum(unk.values()), len(unk),
               ",".join("%s=%d" % kv for kv in sorted(unk.items()))))

    rows = []
    for det in sorted({f["detector"] for f in findings}):
        per_seed = []
        tot_ab = tot_ba = 0
        for s in paired:
            r_ab = (hits[(det, s, AB, "cand")] - hits[(det, s, AB, "base")]) \
                / ngames[(s, AB)]
            r_ba = (hits[(det, s, BA, "cand")] - hits[(det, s, BA, "base")]) \
                / ngames[(s, BA)]
            tot_ab += hits[(det, s, AB, "cand")] + hits[(det, s, AB, "base")]
            tot_ba += hits[(det, s, BA, "cand")] + hits[(det, s, BA, "base")]
            per_seed.append({"seed": s, "r_ab": r_ab, "r_ba": r_ba,
                             "arm": (r_ab + r_ba) / 2.0,
                             "side": (r_ab - r_ba) / 2.0})
        if not per_seed:
            continue
        n = len(per_seed)
        # 4(i-d): per-seed swap-average FIRST, arithmetic mean SECOND.
        arm = sum(p["arm"] for p in per_seed) / n
        side = sum(p["side"] for p in per_seed) / n
        m_ab = sum(p["r_ab"] for p in per_seed) / n
        m_ba = sum(p["r_ba"] for p in per_seed) / n
        var = sum((p["arm"] - arm) ** 2 for p in per_seed) / (n - 1) if n > 1 else 0.0
        rows.append({
            "detector": det,
            "hits_ab": tot_ab, "hits_ba": tot_ba,
            "r_ab": m_ab, "r_ba": m_ba, "arm": arm, "side": side,
            "sd": var ** 0.5,
            "seeds": n,
            # 4(i-b) marker on the UNCORRECTED pair; identically |side|>|arm|.
            "flip": (m_ab > 0 > m_ba) or (m_ab < 0 < m_ba),
            "seeds_neg": sum(1 for p in per_seed if p["arm"] < 0),
            "per_seed": per_seed,
        })
    rows.sort(key=lambda r: -(r["hits_ab"] + r["hits_ba"]))
    return rows, complaints


def render(rows, games, complaints, verbose=False):
    ngames = collections.Counter(g["side"] for g in games)
    out = []
    out.append("SWEEP STRATA  games ab(armed=radiant)=%d  ba(armed=dire)=%d  "
               "seeds paired=%d"
               % (ngames[AB], ngames[BA], rows[0]["seeds"] if rows else 0))
    out.append("")
    out.append("%-22s %6s %6s | %8s %8s | %8s %8s %6s %s"
               % ("detector", "hit_ab", "hit_ba", "r_ab", "r_ba",
                  "arm", "side", "sd", "neg/n"))
    out.append("-" * 96)
    for r in rows:
        out.append("%-22s %6d %6d | %+8.3f %+8.3f | %+8.3f %+8.3f %6.3f %d/%d%s"
                   % (r["detector"], r["hits_ab"], r["hits_ba"],
                      r["r_ab"], r["r_ba"], r["arm"], r["side"], r["sd"],
                      r["seeds_neg"], r["seeds"], "  FLIP" if r["flip"] else ""))
    out.append("")
    out.append("r_ab/r_ba = (armed-side hits - baseline-side hits) per game, "
               "within that leg.")
    out.append("arm = per-seed (r_ab+r_ba)/2 then arithmetic mean across seeds "
               "(4(i-d): never games-weighted).")
    out.append("FLIP marks r_ab and r_ba disagreeing in sign. Those two are "
               "side-bias-UNCORRECTED (4(i-b): noise, do not conclude).")
    out.append("`arm` IS side-bias-eliminated (4(i-c)): a FLIP is not a veto "
               "on it -- FLIP <=> |side|>|arm| is an identity, not a diagnosis.")
    out.append("NO number here is a per-id effect size (LIMIT 1); detector "
               "counts are not behaviour (LIMIT 2).")
    if verbose:
        out.append("")
        for r in rows:
            out.append("%s:" % r["detector"])
            for p in r["per_seed"]:
                out.append("    seed %s  r_ab %+.3f  r_ba %+.3f  arm %+.3f  "
                           "side %+.3f" % (p["seed"], p["r_ab"], p["r_ba"],
                                           p["arm"], p["side"]))
    for c in complaints:
        out.append("FINDING: %s" % c)
    return "\n".join(out)


# ---------------------------------------------------------------- selfcheck
def _mk(det, seed, side, cand, n):
    return [{"detector": det, "seed": seed, "side": side,
             "on_candidate_side": cand, "hero": "h"} for _ in range(n)]


def selfcheck():
    """Mutation stand: each case is built so that a specific WRONG
    implementation gives a different answer than the right one."""
    ok, fail = 0, 0

    def chk(name, got, want, tol=1e-9):
        nonlocal ok, fail
        if abs(got - want) <= tol:
            ok += 1
        else:
            fail += 1
            print("FAIL %s: got %r want %r" % (name, got, want))

    # M1 -- games-weighted pooling (4(i-d)) must NOT reproduce `arm`.
    # ab leg: 10 games, +1 net hit/game.  ba leg: 2 games, -3 net hits/game.
    # correct arm = (1 + (-3))/2 = -1.0 ; games-weighted = (10*1+2*-3)/12 = +0.333
    games = ([{"seed": "1", "side": AB}] * 10) + ([{"seed": "1", "side": BA}] * 2)
    f = _mk("d", "1", AB, True, 10) + _mk("d", "1", BA, False, 6)
    rows, _ = tabulate(f, games)
    chk("M1 arm is swap-average not games-weighted", rows[0]["arm"], -1.0)
    chk("M1 side", rows[0]["side"], 2.0)

    # M2 -- per-seed FIRST, then mean across seeds.  Two seeds with very
    # different game counts: pooling all games first gives a different number.
    # seed A: ab 1 game +4, ba 1 game +4  -> arm +4
    # seed B: ab 9 games 0,  ba 9 games 0 -> arm  0     mean = +2.0
    # (a games-pooling implementation would give +0.4)
    games = [{"seed": "A", "side": AB}, {"seed": "A", "side": BA}]
    games += ([{"seed": "B", "side": AB}] * 9) + ([{"seed": "B", "side": BA}] * 9)
    f = _mk("d", "A", AB, True, 4) + _mk("d", "A", BA, True, 4)
    rows, _ = tabulate(f, games)
    chk("M2 per-seed first then arithmetic mean", rows[0]["arm"], 2.0)

    # M3 -- an unpaired seed must contribute NOTHING (LIMIT 4).  Adding a
    # radiant-only seed with huge hits must not move `arm`.
    games2 = games + ([{"seed": "C", "side": AB}] * 5)
    f2 = f + _mk("d", "C", AB, True, 50)
    rows2, comp = tabulate(f2, games2)
    chk("M3 unpaired seed does not move arm", rows2[0]["arm"], 2.0)
    if any("empty leg" in c for c in comp):
        ok += 1
    else:
        fail += 1
        print("FAIL M3: unpaired seed did not raise a complaint")

    # M4 -- `unk` is complained about, not silently dropped.
    f3 = _mk("d", "A", AB, True, 1) + _mk("d", "A", BA, True, 1)
    f3 += [{"detector": "d", "seed": "A", "side": AB,
            "on_candidate_side": None, "hero": "?"}]
    rows3, comp3 = tabulate(f3, [{"seed": "A", "side": AB},
                                 {"seed": "A", "side": BA}])
    chk("M4 unk not counted as a cand hit", rows3[0]["arm"], 1.0)
    if any("unresolved hero" in c for c in comp3):
        ok += 1
    else:
        fail += 1
        print("FAIL M4: unk finding raised no complaint")

    # M5 -- FLIP is exactly |side| > |arm| (the identity, so a reader can
    # never take the marker for an independent diagnosis).
    games5 = [{"seed": "1", "side": AB}, {"seed": "1", "side": BA}]
    f5 = _mk("d", "1", AB, True, 3) + _mk("d", "1", BA, False, 1)
    rows5, _ = tabulate(f5, games5)
    r = rows5[0]
    if r["flip"] == (abs(r["side"]) > abs(r["arm"])):
        ok += 1
    else:
        fail += 1
        print("FAIL M5: FLIP marker is not |side|>|arm|")

    # M6 -- baseline-side hits must SUBTRACT (a mutant that ignores
    # on_candidate_side would read +1.0 here instead of 0.0).
    f6 = _mk("d", "1", AB, True, 1) + _mk("d", "1", AB, False, 1) \
        + _mk("d", "1", BA, True, 1) + _mk("d", "1", BA, False, 1)
    rows6, _ = tabulate(f6, games5)
    chk("M6 baseline hits subtract", rows6[0]["arm"], 0.0)

    print("SELFCHECK %d PASS / %d FAIL" % (ok, fail))
    return 0 if fail == 0 else 3


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("sweep_dirs", nargs="*",
                    help="sweep_run.sh output dir(s) (each holding "
                         "all_findings.jsonl + games_manifest.jsonl)")
    ap.add_argument("--verbose", action="store_true",
                    help="also print the per-seed rows behind every mean")
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()
    if not a.sweep_dirs:
        print("REFUSED: no sweep dir given (this is not a pass)", file=sys.stderr)
        return EXIT_REFUSED

    findings, games, missing = load(a.sweep_dirs)
    for d in missing:
        print("REFUSED-INPUT: %s has no all_findings.jsonl/games_manifest.jsonl"
              % d, file=sys.stderr)
    if not games:
        print("REFUSED: no games in any manifest -- nothing was tabulated, "
              "and that is not a pass", file=sys.stderr)
        return EXIT_REFUSED

    rows, complaints = tabulate(findings, games)
    if not rows:
        print("REFUSED: no paired seed (every seed has an empty leg); "
              "half a swap-average is a side reading, not an arm reading",
              file=sys.stderr)
        for c in complaints:
            print("FINDING: %s" % c, file=sys.stderr)
        return EXIT_REFUSED

    print(render(rows, games, complaints, a.verbose))
    if missing:
        complaints.append("%d input dir(s) unreadable" % len(missing))
    return EXIT_FINDINGS if complaints else EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())

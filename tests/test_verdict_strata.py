#!/usr/bin/env python3
"""The verdict must publish the two STRATUM READINGS, not just the leg counts.
[GH #329, iron rule 4(i)-a/-c/-d]

WHY THIS EXISTS
    Rule 4(i) says every armed/baseline comparison must give the ab and the ba
    reading.  For six rounds the batch desk satisfied it with `ab_games` /
    `ba_games` -- COUNTS -- because counts were the only stratum fields the
    verdict carried.  The seventh round satisfied it correctly, and had to
    recompute the readings BY HAND off the corpus to do it.

    The omission is not the interesting half; the hand step is.  Legs are
    routinely unbalanced (W27+W28: 275 ab games against 137 ba), and the
    obvious way to pool unbalanced legs by hand is to weight by game count.
    That is wrong in a way nothing catches:

        arm = (ab + ba)/2   side = (ab - ba)/2
        game-weighted pool  = arm + side * (Nab - Nba)/(Nab + Nba)

    On W27+W28 that coefficient is 0.335 and side averages -51.96, so the
    game-weighted answer reads +9.20 where the correct estimator reads +26.60
    -- a -17.40 bias, two thirds of the effect size, in the direction that
    would have sunk the promote case, printed as an ordinary number.  So this
    file pins both halves at once: the readings must be PUBLISHED (nobody needs
    to recompute them), and the estimator that combines them must stay
    UNWEIGHTED (each leg 50% regardless of depth, which is what cancels side).

    Fourth member of the family that fails toward danger, after W14's basename
    collisions, W17-R's "non-empty per_seed != a usable seed", and W19's 41:1
    thin arm.  Each of the first three left reading advice in a charter and
    recurred anyway; this one is a test for that reason.

HOW IT TESTS
    On the REAL script (no reimplementation of the estimator -- a test that
    owns a second copy of the arithmetic passes when both copies are wrong the
    same way), driven on real corpora in temp dirs.

    Case 3 is the load-bearing one: an UNBALANCED corpus whose unweighted and
    game-weighted answers differ, asserted against the unweighted value.  A
    corpus with equal legs cannot fail that assertion no matter what the tool
    does, which is exactly the vacuity the M2 mutation below is aimed at.

    M1 mutation: drop the `_ab`/`_ba` row fields          -> case 1 red.
    M2 mutation: `(ab*len(AB) + ba*len(BA)) / (len(AB)+len(BA))` for row[m]
                 (game-weighted pooling, the hand-math hazard) -> case 3 red.
    M3 mutation: `sign_flip` hardcoded False              -> case 2 red.
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "batch_test", "soak", "recover_verdict.py")
CAND = "stratacand"

failures = []
checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def game(stamp, rad_gpm, dire_gpm):
    return {
        "script_version": stamp, "winner": "radiant",
        "winner_by": "economy_30min_cap", "econ_winner": "radiant",
        "players": ([{"team": "radiant", "gpm": rad_gpm, "xpm": rad_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)] +
                    [{"team": "dire", "gpm": dire_gpm, "xpm": dire_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)]),
    }


def corpus(spec):
    """spec: {seed: (ab_games, ba_games, ab_delta, ba_delta)}.

    ab_delta is the candidate-minus-baseline gpm on the wave where the
    candidate is radiant; ba_delta the one where it is dire.
    """
    d = tempfile.mkdtemp(prefix="verdict_strata_")
    n = 0
    for seed, (nab, nba, dab, dba) in sorted(spec.items()):
        for _ in range(nab):
            g = game("mirror:%s:s%s:radiant" % (CAND, seed), 500 + dab, 500)
            json.dump(g, open(os.path.join(d, "g%04d.analysis.json" % n), "w"))
            n += 1
        for _ in range(nba):
            g = game("mirror:%s:s%s:dire" % (CAND, seed), 500, 500 + dba)
            json.dump(g, open(os.path.join(d, "g%04d.analysis.json" % n), "w"))
            n += 1
    return d


def run(d):
    p = subprocess.run([sys.executable, SCRIPT, d, CAND],
                       capture_output=True, text=True)
    if p.returncode != 0:
        print(p.stdout)
        print(p.stderr)
        raise SystemExit("recover_verdict.py exited %d" % p.returncode)
    return json.loads(p.stdout)


def row_of(v, seed):
    return next((r for r in v.get("per_seed", []) if r["seed"] == seed), None)


# --------------------------------------------------------------------------
# 1. The readings are published per seed, and they are the ones the
#    swap-average actually consumed.
# --------------------------------------------------------------------------
# s001: ab +100, ba -40  -> arm +30, side +70  (side > arm: the strata flip)
# s002: ab  +20, ba +40  -> arm +30, side -10  (no flip)
V1 = run(corpus({"001": (20, 20, 100, -40),
                 "002": (20, 20, 20, 40)}))

check(len(V1.get("per_seed", [])) == 2 and all(r.get("scored") for r in V1["per_seed"]),
      "guard: both seeds parsed and scored (a vacuous pass here would hide everything below)")

r1, r2 = row_of(V1, "001"), row_of(V1, "002")
check(r1 is not None and "gpm_ab" in r1 and "gpm_ba" in r1,
      "per-seed row publishes gpm_ab / gpm_ba (4(i)-a: readings, not counts)")
check(r1 and r1.get("gpm_ab") == 100.0 and r1.get("gpm_ba") == -40.0,
      "s001 strata readings are +100 / -40")
check(r1 and "gpm_ab" in r1 and abs((r1["gpm_ab"] + r1["gpm_ba"]) / 2 - r1["gpm"]) < 0.01,
      "s001: the published readings reproduce the published swap-average")
check(r2 and "gpm_ab" in r2 and abs((r2["gpm_ab"] + r2["gpm_ba"]) / 2 - r2["gpm"]) < 0.01,
      "s002: the published readings reproduce the published swap-average")
check(all(m + "_ab" in r1 for m in ("gpm", "xpm", "deaths", "last_hits")),
      "all four economy metrics carry strata, not just gpm")

# --------------------------------------------------------------------------
# 2. The wave-level block, and sign_flip as a DISCLOSURE of |side| > |arm|.
# --------------------------------------------------------------------------
s = V1.get("strata", {}).get("gpm", {})
check(s.get("ab") == 60.0 and s.get("ba") == 0.0,
      "wave strata means are ab +60 / ba 0 (mean of +100,+20 and of -40,+40)")
check(abs((s.get("ab", 0) + s.get("ba", 0)) / 2 - V1["mean"]["gpm"]) < 0.01,
      "wave strata reproduce the wave mean -- same estimator, shown open")
check(s.get("side") == 30.0, "wave side term is published (+30)")
check(s.get("side_gt_arm") == "1/2",
      "side_gt_arm counts the seeds where the nuisance beats the effect (s001 only)")
check(s.get("sign_flip") is False,
      "strata means ab +60 / ba 0 do not flip -- flag is off")

# A corpus whose STRATA MEANS flip, the shape #329 was opened about.
V2 = run(corpus({"001": (20, 20, -300, 360),
                 "002": (20, 20, -100, 160)}))
s2 = V2.get("strata", {}).get("gpm", {})
check(s2.get("ab") == -200.0 and s2.get("ba") == 260.0 and s2.get("sign_flip") is True,
      "strata means of opposite sign set sign_flip")
check(abs(V2["mean"]["gpm"] - 30.0) < 0.01,
      "and the arm reading is still +30 -- the flip did not disturb the estimate")

# --------------------------------------------------------------------------
# 3. LOAD-BEARING: unbalanced legs must stay UNWEIGHTED.
# --------------------------------------------------------------------------
# One seed, 30 ab games against 10 ba, ab +200 / ba -80.
#   unweighted (correct): (200 + -80)/2                = +60.0
#   game-weighted (hazard): (200*30 + -80*10)/40       = +130.0
# The two answers differ by 70 gpm, so this assertion cannot pass vacuously.
V3 = run(corpus({"777": (30, 10, 200, -80)}))
r3 = row_of(V3, "777")
check(r3 is not None and r3.get("ab_games") == 30 and r3.get("ba_games") == 10,
      "guard: the unbalanced corpus really is 30:10 (else case 3 proves nothing)")
check(r3 and abs(r3["gpm"] - 60.0) < 0.01,
      "unbalanced seed reads +60.0 (unweighted), NOT +130.0 (game-weighted)")
check(abs(V3["mean"]["gpm"] - 60.0) < 0.01,
      "and the wave mean carries the unweighted value through")
check(r3 and r3.get("gpm_ab") == 200.0 and r3.get("gpm_ba") == -80.0,
      "the unbalanced seed still publishes both readings")

print()
print("%d check(s), %d failure(s)" % (checks, len(failures)))
sys.exit(1 if failures else 0)

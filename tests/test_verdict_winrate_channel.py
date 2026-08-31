#!/usr/bin/env python3
"""A winrate of 0.500 must not be able to mean two opposite things silently.

WHY THIS EXISTS  [GH #352]
    The mirrored winrate is `(r_ab + (1 - r_ba)) / 2 == 0.5 + (r_ab - r_ba)/2`
    where r_x is one physical side's win share in wave x.  So the entire arm
    signal is the DIFFERENCE in a side's win share between the two waves, and
    a corpus in which one side sweeps has r_ab == r_ba == 0, which forces
    winrate == 0.500 EXACTLY no matter what the candidate does.

    That is not a hypothetical.  From roughly 08-26 the batch corpus went to a
    dire sweep and stayed there: 08-27 48/48, 08-29 58/59, W29 227/228,
    W30 231/231, W31 221/222.  The tool printed `winrate 0.500` and
    `comps_better winrate 0/4`, six waves running, and both were read as
    measurements.  One of them reached a promote ruling: charter section CO.4
    cited "winrate 0.503" as support for rule 2(b).

    The defect is NOT that the number was wrong -- 0.500 is arithmetically
    correct.  It is that the tool published a FORCED number in the same shape,
    the same field and the same units as a measured one, so no reader could
    tell them apart.  This test pins the quantity that separates them.

HOW IT TESTS
    It drives the REAL script on REAL analysis.json corpora written to a temp
    dir and reads its real stdout/stderr -- no reimplementation is imported
    (GH #67, "three writers, zero readers").  check_parsed() runs before every
    real assertion so a corpus the script silently skipped cannot let an
    assertion pass by never being reached.

    The load-bearing case is case 2 vs case 1: the SAME printed winrate 0.5
    off corpora that mean opposite things.  A test that only checked the swept
    corpus would pass against a tool that hard-coded headroom to 0.
"""
import json, os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "batch_test", "soak", "recover_verdict.py")
CAND = "testcand"

failures = []


def check(cond, msg):
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def game(stamp, winner, winner_by="economy_30min_cap"):
    """One analysis.json in the exact shape analyze_log.py emits.

    All ten players carry identical economy stats, so every economy delta is
    0 and nothing this test asserts can be an artifact of the gpm path.
    """
    return {
        "script_version": stamp,
        "winner": winner,
        "winner_by": winner_by,
        "econ_winner": winner,
        "players": [{"team": t, "gpm": 500, "xpm": 500, "deaths": 5,
                     "last_hits": 100}
                    for t in ("radiant", "dire") for _ in range(5)],
    }


def run(games):
    """Drive the real script; return (parsed stdout, stderr)."""
    d = tempfile.mkdtemp(prefix="verdict_ch_")
    for i, g in enumerate(games):
        with open(os.path.join(d, "g%03d.analysis.json" % i), "w") as f:
            json.dump(g, f)
    # --min-arm-depth 1 is DECLARATIVE: these corpora are 4 hand-built games
    # per leg, below the farm default of 8, and the GH #269 depth gate would
    # correctly refuse to score them.  That gate is tested at its real default
    # in tests/test_verdict_arm_depth.py; it is not what this file is about.
    out = subprocess.run([sys.executable, SCRIPT, d, CAND, "--min-arm-depth", "1"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        print(out.stdout)
        print(out.stderr)
        raise SystemExit("recover_verdict.py exited %d" % out.returncode)
    return json.loads(out.stdout), out.stderr


def check_parsed(v, want_seeds, where):
    """ANTI-EMPTY-MATCH GUARD, run before the real assertions in every case.

    On a stamp typo the script still exits 0 and prints a well-formed verdict
    with per_seed == [], and every "the headroom is right" assertion below
    would then pass by never being reached.
    """
    seeds = [r["seed"] for r in v.get("per_seed", [])]
    check(seeds == want_seeds,
          "[guard] %s: corpus parsed, seeds %s (not an empty/silent parse)"
          % (where, want_seeds))
    check(all(r.get("ab_games", 0) > 0 and r.get("ba_games", 0) > 0
              for r in v["per_seed"]),
          "[guard] %s: both waves are present in every seed" % where)


def waves(seed):
    return ("mirror:%s:s%s:radiant" % (CAND, seed),
            "mirror:%s:s%s:dire" % (CAND, seed))


# --- 1. the swept corpus: winrate 0.500 is FORCED -------------------------
# ab wave (candidate is radiant): dire wins all 4.  ba wave (candidate is
# dire): dire wins all 4.  This is W30's shape in miniature.
RS, DS = waves("001")
v, err = run([game(RS, "dire") for _ in range(4)] +
             [game(DS, "dire") for _ in range(4)])
check_parsed(v, ["001"], "case 1")
row = v["per_seed"][0]
check(row.get("winrate") == 0.5,
      "swept corpus still prints winrate 0.500 -- the reading is not silenced,"
      " got %r" % row.get("winrate"))
check(row.get("winrate_headroom") == 0.0,
      "swept corpus: headroom is 0 -- 0.500 is the only value it could take,"
      " got %r" % row.get("winrate_headroom"))
check(row.get("winrate_side_census") == {"radiant": 0, "dire": 8},
      "per-seed side census counts both waves, got %r"
      % row.get("winrate_side_census"))
check(v.get("winrate_side_census") == {"radiant": 0, "dire": 8},
      "wave-level side census is published, got %r"
      % v.get("winrate_side_census"))
check(v.get("winrate_minority_side_share") == 0.0,
      "minority side share is 0 on a sweep, got %r"
      % v.get("winrate_minority_side_share"))
check(v.get("winrate_channel") == "DEGENERATE",
      "a sweep is called DEGENERATE, got %r" % v.get("winrate_channel"))
check(v["mean"].get("winrate_headroom") == 0.0,
      "the pooled mean carries its own headroom, got %r"
      % v["mean"].get("winrate_headroom"))
check("DEGENERATE" in err and "2(b)" in err,
      "stderr names the channel and the rule it must not be cited for, got %r"
      % err.strip()[:160])

# --- 2. THE LOAD-BEARING CASE: same 0.500, opposite meaning ---------------
# A competitive corpus that also averages to exactly 0.500.  If the tool
# hard-coded headroom to 0, or keyed "degenerate" off the winrate value
# instead of off the corpus, case 1 alone would still pass and this fails.
RS2, DS2 = waves("002")
v2, err2 = run([game(RS2, "radiant"), game(RS2, "radiant"),
                game(RS2, "dire"), game(RS2, "dire"),
                game(DS2, "dire"), game(DS2, "dire"),
                game(DS2, "radiant"), game(DS2, "radiant")])
check_parsed(v2, ["002"], "case 2")
row2 = v2["per_seed"][0]
check(row2.get("winrate") == 0.5,
      "competitive corpus prints the SAME winrate 0.500, got %r"
      % row2.get("winrate"))
check(row2.get("winrate_headroom") == 0.5,
      "competitive corpus: headroom 0.5 -- this 0.500 was free to move, got %r"
      % row2.get("winrate_headroom"))
check(row.get("winrate") == row2.get("winrate")
      and row.get("winrate_headroom") != row2.get("winrate_headroom"),
      "the two corpora are indistinguishable by winrate and separated ONLY "
      "by headroom -- the whole point of the field")
check(v2.get("winrate_minority_side_share") == 0.5,
      "even side split reads share 0.5, got %r"
      % v2.get("winrate_minority_side_share"))
check(v2.get("winrate_channel") == "RECOVERED",
      "a competitive corpus is RECOVERED, got %r" % v2.get("winrate_channel"))
check("DEGENERATE" not in err2,
      "no degenerate warning is emitted on a competitive corpus, got %r"
      % err2.strip()[:160])

# --- 3. the bound is a real bound, and it is tight ------------------------
# One radiant win in 8 (W31 seed 2444's shape).  ab: 1 radiant + 3 dire;
# ba: 4 dire.  winrate = (1/4 + 4/4)/2 = 0.625, headroom = (1/4)/2 = 0.125.
RS3, DS3 = waves("003")
v3, err3 = run([game(RS3, "radiant")] + [game(RS3, "dire") for _ in range(3)] +
               [game(DS3, "dire") for _ in range(4)])
check_parsed(v3, ["003"], "case 3")
row3 = v3["per_seed"][0]
check(row3.get("winrate") == 0.625,
      "one minority win moves the winrate off 0.5, got %r" % row3.get("winrate"))
check(row3.get("winrate_headroom") == 0.125,
      "headroom == min(R,D)/min(leg) / 2 == (1/4)/2, got %r"
      % row3.get("winrate_headroom"))
check(abs(row3["winrate"] - 0.5) <= row3["winrate_headroom"] + 1e-9,
      "the bound holds: |winrate - 0.5| = %r <= headroom %r"
      % (abs(row3["winrate"] - 0.5), row3["winrate_headroom"]))
check(v3.get("winrate_channel") == "DEGENERATE",
      "share 1/8 = 0.125 < 0.20 is still DEGENERATE, got %r"
      % v3.get("winrate_channel"))

# --- 4. the gold-independence bucket is `engine_natural` [GH #108] --------
# The pre-rename name `engine` must NOT be counted as naturally ended: the
# header of wr() says so, and reading it printed 0/222 on a corpus that was
# 222/222 natural -- inverting the one field that says whether the winrate
# carries information the economy metrics do not.
NAT = [game(RS2, "radiant"), game(RS2, "radiant"),
       game(RS2, "dire"), game(RS2, "dire"),
       game(DS2, "dire"), game(DS2, "dire"),
       game(DS2, "radiant"), game(DS2, "radiant")]
v4, _ = run([dict(g, winner_by="engine_natural") for g in NAT])
check_parsed(v4, ["002"], "case 4a")
check(v4.get("winrate_independent_of_gold") == "8/8 games",
      "engine_natural games are counted as gold-independent, got %r"
      % v4.get("winrate_independent_of_gold"))
v5, _ = run([dict(g, winner_by="engine") for g in NAT])
check_parsed(v5, ["002"], "case 4b")
check(v5.get("winrate_independent_of_gold") == "0/8 games",
      "the pre-rename `engine` bucket is NOT counted as natural, got %r"
      % v5.get("winrate_independent_of_gold"))

print()
if failures:
    print("%d FAILURE(S)" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")

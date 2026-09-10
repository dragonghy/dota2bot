#!/usr/bin/env python3
"""A seed that could not vote yes must not sit in the promote bar's denominator.

WHY THIS EXISTS  [GH #696]
    GH #352's own case statement named TWO misread numbers:

        "the tool printed `winrate 0.500` and `comps_better winrate 0/4`, six
         waves running, and BOTH were read as measurements"

    It then fixed the first one.  `winrate_headroom` made a forced 0.500
    legible beside the value it bounds -- and `comps_better.winrate` went on
    counting the seed that produced that 0.500 in its DENOMINATOR.

    The arithmetic is the wr() header's identity, not a new claim.  A seed
    whose corpus swept one physical side has r_ab == r_ba, so its winrate is
    0.500 exactly, so `x > 0.5` is false for it whatever the candidate did.
    Two such seeds in a four-seed wave put a bar of the form "comps_better
    winrate >= 3/4" arithmetically OUT OF RANGE -- and the fraction that
    reports it is shaped exactly like one that means "the arm lost two".

    Live instance, not hypothetical: W62 published `comps_better winrate 2/4`
    off seeds 10601 (headroom 0), 10607 (0.0357), 10803 (headroom 0) and
    10813 (0.4167).  Both "no" votes were identities.  Among the seeds that
    could speak the record was 2/2, and no field in the verdict said so.

HOW IT TESTS
    It drives the REAL script on REAL analysis.json corpora in a temp dir and
    reads its real stdout/stderr -- nothing is reimplemented here (GH #67,
    "three writers, zero readers").  check_parsed() runs before the real
    assertions in every case, so a corpus the script silently skipped cannot
    let an assertion pass by never being reached.

    The load-bearing case is case 1: ONE arm, TWO different fractions.  A test
    that only checked an all-forced wave would pass against a tool that always
    excluded every seed, and case 2 (nothing forced) is what refuses that.
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


def game(stamp, winner):
    """One analysis.json in the shape analyze_log.py emits.

    All ten players carry identical economy stats, so every economy delta is
    0 and nothing asserted below can be an artifact of the gpm path.
    """
    return {
        "script_version": stamp,
        "winner": winner,
        "winner_by": "engine_natural",
        "econ_winner": winner,
        "players": [{"team": t, "gpm": 500, "xpm": 500, "deaths": 5,
                     "last_hits": 100}
                    for t in ("radiant", "dire") for _ in range(5)],
    }


def waves(seed):
    """(ab stamp, ba stamp) -- candidate is radiant in ab, dire in ba."""
    return ("mirror:%s:s%s:radiant" % (CAND, seed),
            "mirror:%s:s%s:dire" % (CAND, seed))


def swept(seed):
    """A seed whose winrate is FORCED to 0.500: one side takes both waves."""
    ab, ba = waves(seed)
    return ([game(ab, "dire") for _ in range(4)]
            + [game(ba, "dire") for _ in range(4)])


def winning(seed):
    """A seed that MEASURES a win: r_ab = 3/4, r_ba = 1/4 -> winrate 0.750.

    headroom = min(1, min(R,D)/min(leg))/2 with R = 3+1, D = 1+3, leg = 4,
    i.e. 0.5 -- strictly positive, so this seed is free to move and its vote
    is a reading.
    """
    ab, ba = waves(seed)
    return ([game(ab, "radiant") for _ in range(3)] + [game(ab, "dire")]
            + [game(ba, "radiant")] + [game(ba, "dire") for _ in range(3)])


def run(games):
    """Drive the real script; return (parsed stdout, stderr)."""
    d = tempfile.mkdtemp(prefix="verdict_comps_")
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
    with per_seed == [], and every assertion below would then pass by never
    being reached.
    """
    seeds = sorted(r["seed"] for r in v.get("per_seed", []))
    check(seeds == want_seeds,
          "[guard] %s: corpus parsed, seeds %s (not an empty/silent parse)"
          % (where, want_seeds))
    check(all("winrate" in r for r in v["per_seed"]),
          "[guard] %s: every seed cleared the depth gate and carries a winrate"
          % where)


def seed_row(v, seed):
    for r in v["per_seed"]:
        if r["seed"] == seed:
            return r
    return {}


# --- 1. THE LOAD-BEARING CASE: one arm, two different fractions -----------
# Seed 001 swept (forced 0.500, votes "no" by identity); seed 002 measured a
# 0.750 win.  Pooled the arm reads 1/2; among seeds that could speak, 1/1.
v, err = run(swept("001") + winning("002"))
check_parsed(v, ["001", "002"], "case 1")

r1, r2 = seed_row(v, "001"), seed_row(v, "002")
check(r1.get("winrate") == 0.5 and r1.get("winrate_headroom") == 0.0,
      "[guard] case 1: seed 001 is the forced shape (0.500, headroom 0), "
      "got %r / %r" % (r1.get("winrate"), r1.get("winrate_headroom")))
check(r2.get("winrate") == 0.75 and r2.get("winrate_headroom") == 0.5,
      "[guard] case 1: seed 002 is the measured shape (0.750, headroom 0.5), "
      "got %r / %r" % (r2.get("winrate"), r2.get("winrate_headroom")))

check(v["comps_better"].get("winrate") == "1/2",
      "the pooled fraction is UNCHANGED -- published beside, never replaced, "
      "got %r" % v["comps_better"].get("winrate"))
check(v["comps_better"].get("winrate_measurable") == "1/1",
      "the measurable fraction drops the seed that could not vote yes, got %r"
      % v["comps_better"].get("winrate_measurable"))
check(v["comps_better"].get("winrate") != v["comps_better"].get("winrate_measurable"),
      "the two fractions DIFFER on this corpus -- the whole point of the "
      "field; a tool that copied one into the other passes every other check")
check(sorted(v.get("winrate_forced_seeds") or []) == ["001"],
      "the forced seed is named, not just counted, got %r"
      % v.get("winrate_forced_seeds"))
check("winrate_undisclosed_headroom_seeds" not in v,
      "no undisclosed bucket when every seed published a headroom, got %r"
      % v.get("winrate_undisclosed_headroom_seeds"))
check("GH #696" in err and "unreachable" in err,
      "stderr names the defect and the word that matters to a promote bar, "
      "got %r" % err.strip()[:200])
check("1/2" in err and "1/1" in err,
      "stderr carries BOTH fractions, so a reader who never opens the JSON "
      "still sees the gap, got %r" % err.strip()[:200])


# --- 2. nothing forced: the tool must NOT excuse a genuine loss -----------
# Three measurable seeds: one winning (003), one LOSING (004), and one that
# reads exactly 0.500 while being free to move (007 -- #352's own load-bearing
# shape).  Seed 007 is what separates "keyed off headroom" from "keyed off the
# winrate value": a tool that excluded every 0.500 would drop it here.
v2, err2 = run(winning("003")
               + [game(waves("004")[0], "dire") for _ in range(3)]
               + [game(waves("004")[0], "radiant")]
               + [game(waves("004")[1], "dire")]
               + [game(waves("004")[1], "radiant") for _ in range(3)]
               + [game(waves("007")[0], "radiant") for _ in range(2)]
               + [game(waves("007")[0], "dire") for _ in range(2)]
               + [game(waves("007")[1], "radiant") for _ in range(2)]
               + [game(waves("007")[1], "dire") for _ in range(2)])
check_parsed(v2, ["003", "004", "007"], "case 2")
check(seed_row(v2, "004").get("winrate") == 0.25,
      "[guard] case 2: seed 004 measured a LOSS (0.250), got %r"
      % seed_row(v2, "004").get("winrate"))
check(seed_row(v2, "007").get("winrate") == 0.5
      and seed_row(v2, "007").get("winrate_headroom") == 0.5,
      "[guard] case 2: seed 007 reads 0.500 with headroom 0.5 -- a 0.500 that "
      "was FREE to move, got %r / %r" % (seed_row(v2, "007").get("winrate"),
                                         seed_row(v2, "007").get("winrate_headroom")))
check(v2.get("winrate_forced_seeds") == [],
      "nothing is forced on a competitive corpus -- in particular the 0.500 "
      "that was free to move is NOT excluded, got %r"
      % v2.get("winrate_forced_seeds"))
check(v2["comps_better"].get("winrate") == "1/3"
      and v2["comps_better"].get("winrate_measurable") == "1/3",
      "with nothing forced the two fractions AGREE -- a real loss stays a "
      "loss, got %r / %r" % (v2["comps_better"].get("winrate"),
                             v2["comps_better"].get("winrate_measurable")))
check("GH #696" not in err2,
      "no unreachability warning when every seed could vote, got %r"
      % err2.strip()[:200])


# --- 3. everything forced: "0/0" is printed, not omitted ------------------
# An absent key reads as "nothing to report", which is the one thing a wave
# with no measurable seed does not mean.  This is W30's shape.
v3, err3 = run(swept("005") + swept("006"))
check_parsed(v3, ["005", "006"], "case 3")
check(v3["comps_better"].get("winrate") == "0/2",
      "[guard] case 3: pooled fraction still reports 0/2, got %r"
      % v3["comps_better"].get("winrate"))
check(v3["comps_better"].get("winrate_measurable") == "0/0",
      "an all-forced wave prints 0/0 rather than omitting the key, got %r"
      % v3["comps_better"].get("winrate_measurable"))
check(sorted(v3.get("winrate_forced_seeds") or []) == ["005", "006"],
      "both forced seeds are named, got %r" % v3.get("winrate_forced_seeds"))
check("0/2" in err3 and "unreachable" in err3,
      "stderr says a bar above 0/2 is unreachable on this corpus, got %r"
      % err3.strip()[:200])


print()
if failures:
    print("FAILED %d check(s)" % len(failures))
    for m in failures:
        print("  - %s" % m)
    raise SystemExit(1)
print("test_verdict_winrate_comps.py: all checks passed")

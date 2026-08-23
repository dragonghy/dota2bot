#!/usr/bin/env python3
"""recover_verdict.py must report the quantity README rule 2(b) actually names.

WHY THIS EXISTS
    Rule 2(b) is "the batch shows no obvious negative effect on WINS/LOSSES".
    For the first fifty director triggers the verdict tool computed only
    gpm/xpm/deaths/last_hits -- four per-player ECONOMY means -- while every
    analysis.json had carried `winner` all along (analyze_log.py:120).  The
    gap was in the tool, not in the corpus, so it was invisible: every wave
    reported four numbers and nobody noticed none of them was the one the
    rule names.  This test pins the fifth number so it cannot quietly leave.

HOW IT TESTS
    It drives the REAL script on a REAL corpus of analysis.json files it
    writes to a temp dir, and reads the script's real stdout.  It does not
    import a helper and unit-test it: recover_verdict.py is a top-level
    script with no main(), and a test that imports a reimplementation is the
    "three writers, zero readers" shape (GH #67).

    Every assertion that could pass vacuously (on an empty parse, a typo'd
    stamp, a corpus the script silently skipped) is preceded by the
    anti-empty-match guard in check_parsed() -- written before the assertions
    it protects, not bolted on after.
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


def game(stamp, winner, winner_by="economy_30min_cap", rad_gpm=500, dire_gpm=500):
    """One analysis.json in the exact shape analyze_log.py emits."""
    return {
        "script_version": stamp,
        "winner": winner,
        "winner_by": winner_by,
        "econ_winner": winner,
        "players": ([{"team": "radiant", "gpm": rad_gpm, "xpm": rad_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)] +
                    [{"team": "dire", "gpm": dire_gpm, "xpm": dire_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)]),
    }


def run(games, allow_crash=False):
    """Drive the real script on a real corpus; return its parsed stdout.

    allow_crash returns (None, stderr) instead of aborting, so a case whose
    whole point is "the script must survive this corpus" reports a named
    failure rather than taking the run down with a traceback.
    """
    d = tempfile.mkdtemp(prefix="verdict_wr_")
    for i, g in enumerate(games):
        with open(os.path.join(d, "g%03d.analysis.json" % i), "w") as f:
            json.dump(g, f)
    out = subprocess.run([sys.executable, SCRIPT, d, CAND],
                         capture_output=True, text=True)
    if out.returncode != 0:
        if allow_crash:
            return None, out.stderr.strip().splitlines()[-1:] or [""]
        print(out.stdout)
        print(out.stderr)
        raise SystemExit("recover_verdict.py exited %d" % out.returncode)
    return (json.loads(out.stdout), "") if allow_crash else json.loads(out.stdout)


def check_parsed(v, want_seeds, where, half_seeds=()):
    """ANTI-EMPTY-MATCH GUARD.  Runs before every real assertion below.

    If the stamps did not match, the script still exits 0 and prints a
    well-formed verdict with per_seed == [] -- and every "is the winrate
    right" assertion would then pass by never being reached.  This proves
    the corpus was actually read first.

    half_seeds names the seeds a case deliberately builds one-sided (case 5),
    so the "both waves present" leg stays a real check everywhere else
    instead of being weakened to fit the one case that violates it.
    """
    seeds = [r["seed"] for r in v.get("per_seed", [])]
    check(seeds == want_seeds,
          "[guard] %s: corpus parsed, seeds %s (not an empty/silent parse)"
          % (where, want_seeds))
    check(all((r.get("ab_games", 0) > 0) == (r.get("ba_games", 0) > 0)
              if r["seed"] not in half_seeds
              else (r.get("ab_games", 0) > 0) != (r.get("ba_games", 0) > 0)
              for r in v["per_seed"]),
          "[guard] %s: wave completeness is as the case built it" % where)


# --- 1. the metric exists at all, and the two waves are averaged -----------
# seed 001 radiant wave: candidate is radiant, wins 3 of 4.
# seed 001 dire wave:    candidate is dire,    wins 1 of 4.
# expected winrate = (0.75 + 0.25) / 2 = 0.5
RS, DS = "mirror:%s:s001:radiant" % CAND, "mirror:%s:s001:dire" % CAND
v = run([game(RS, "radiant"), game(RS, "radiant"), game(RS, "radiant"), game(RS, "dire"),
         game(DS, "dire"), game(DS, "radiant"), game(DS, "radiant"), game(DS, "radiant")])
check_parsed(v, ["001"], "case 1")
check("winrate" in v["mean"], "winrate is reported in mean at all")
check(v["per_seed"][0].get("winrate") == 0.5,
      "two-wave average: (3/4 radiant + 1/4 dire) / 2 == 0.5, got %r"
      % v["per_seed"][0].get("winrate"))
check(v.get("winrate_neutral") == 0.5,
      "neutral point is published as 0.5 (it is a rate, not a delta)")

# The candidate side must actually be read per wave.  If the tool counted
# "radiant won" in both waves it would get (0.75 + 0.75)/2 = 0.75 here.
check(v["mean"]["winrate"] != 0.75,
      "the dire wave is scored from the DIRE side, not radiant")

# --- 2. the four economy metrics are untouched by this change -------------
# All ten players carry identical stats above, so every economy delta is 0.
check([v["mean"].get(m) for m in ("gpm", "xpm", "deaths", "last_hits")] == [0, 0, 0, 0],
      "the four economy metrics still compute (and are 0 on a tied corpus)")
check(v.get("suggested") == "hold_or_reject",
      "suggested still reads gpm only -- adding a metric did not change policy")

# --- 3. unfinished games leave the denominator, and say so ----------------
# seed 002: radiant wave 2 wins + 1 unfinished; dire wave 2 wins + 1 unfinished.
# winrate must be 1.0 (2/2 and 2/2), NOT 2/3 -- and 2 games must be reported
# as unfinished rather than silently counted as losses.
RS2, DS2 = "mirror:%s:s002:radiant" % CAND, "mirror:%s:s002:dire" % CAND
v = run([game(RS2, "radiant"), game(RS2, "radiant"), game(RS2, None),
         game(DS2, "dire"), game(DS2, "dire"), game(DS2, None)])
check_parsed(v, ["002"], "case 3")
check(v["per_seed"][0].get("winrate") == 1.0,
      "winner=None is excluded from the numerator AND denominator, got %r"
      % v["per_seed"][0].get("winrate"))
check(v.get("scored_games") == 4 and v.get("unfinished_games") == 2,
      "the denominator is reported, not assumed: scored=%r unfinished=%r"
      % (v.get("scored_games"), v.get("unfinished_games")))

# --- 4. the independence disclosure (test_set.md AS.1b) -------------------
# Under the 30-min cap `winner` is rewritten to the economic winner, so only
# `engine` games carry information independent of gold.  The tool must print
# that split every time -- a winrate without it reads as a second witness
# when it is a sign-coarsened read of the same gold.
RS3, DS3 = "mirror:%s:s003:radiant" % CAND, "mirror:%s:s003:dire" % CAND
v = run([game(RS3, "radiant", "engine"), game(RS3, "radiant", "economy_30min_cap"),
         game(DS3, "dire", "economy_forcewin_recovery"), game(DS3, "dire", "engine")])
check_parsed(v, ["003"], "case 4")
check(v.get("winner_by") == {"engine": 2, "economy_30min_cap": 1,
                             "economy_forcewin_recovery": 1},
      "winner_by distribution is tallied, got %r" % (v.get("winner_by"),))
check(v.get("winrate_independent_of_gold") == "2/4 games",
      "the independent (engine-decided) fraction is stated outright, got %r"
      % v.get("winrate_independent_of_gold"))

# --- 5. a seed with only one wave scores no winrate ------------------------
# The economy metrics already refuse to score a half seed; the winrate must
# refuse on the same rule, or a one-sided seed would enter the mean at a
# value that never cancelled the side bias.
RS4 = "mirror:%s:s004:radiant" % CAND
v = run([game(RS, "radiant"), game(RS, "dire"), game(DS, "dire"), game(DS, "radiant"),
         game(RS4, "radiant"), game(RS4, "radiant")])
check_parsed(v, ["001", "004"], "case 5", half_seeds=("004",))
half = [r for r in v["per_seed"] if r["seed"] == "004"][0]
check("winrate" not in half,
      "a seed with only one wave gets no winrate (side bias never cancelled)")
check(v["comps_better"]["winrate"].endswith("/1"),
      "the half seed is excluded from comps_better too, got %r"
      % v["comps_better"]["winrate"])

# --- 6. a wave in which NO game finished ----------------------------------
# This is the condition the inner `if ab_n and ba_n` guard actually protects,
# and it is NOT the same as case 5: both waves are present (so the economy
# metrics score normally), but one wave has a zero winrate denominator.
# Without the guard this is a ZeroDivisionError -- the tool would die on a
# corpus the four economy metrics handle fine, i.e. adding the fifth metric
# would have made previously-readable waves unreadable.
RS5, DS5 = "mirror:%s:s005:radiant" % CAND, "mirror:%s:s005:dire" % CAND
v, err = run([game(RS5, "radiant"), game(RS5, "radiant"),
              game(DS5, None), game(DS5, None)], allow_crash=True)
check(v is not None,
      "a wave where no game finished does not crash the tool (%s)" % (err,))
if v is not None:
    check_parsed(v, ["005"], "case 6")
    check("winrate" not in v["per_seed"][0],
          "no winrate is invented for a seed whose dire wave never finished")
    check(v["per_seed"][0].get("unfinished") == 2,
          "the two unfinished games are still counted and reported, got %r"
          % v["per_seed"][0].get("unfinished"))
    check(v["mean"].get("gpm") == 0,
          "the economy metrics still score that seed -- the fifth metric "
          "abstaining must not take the other four down with it")

print()
if failures:
    print("%d FAILURE(S)" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")

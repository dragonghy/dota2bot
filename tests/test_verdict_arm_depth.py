#!/usr/bin/env python3
"""A seed too thin to be measured must not decide the wave's reading. [GH #269]

WHY THIS EXISTS
    The scored gate in both verdict tools was `if AB and BA` -- "both waves
    present" -- and it cannot tell `ba_games=1` from `ba_games=15`.  W19's seed
    928 passed it with ab=41/ba=1, and because a seed reads as (ab + ba) / 2
    with each leg weighted 50% regardless of depth, ONE dire game decided half
    of that seed and moved the wave mean by 76.5 gpm.  Nothing raised a hand:
    `scored_games`, `unfinished`, `per_seed`, `mean` and `suggested` all looked
    normal, and the only field that could show it was `ba_games` itself.

    Third member of the family that fails toward danger (W14 basename
    collisions; W17-R's "non-empty per_seed != a usable seed").  The first two
    left READING advice in the charters, and this recurrence is the proof that
    reading advice is not a gate -- hence a test, at the real default.

HOW IT TESTS
    Behaviorally, on the real scripts.  Case 1 rebuilds W19's actual shape
    (a 41/1 seed beside a 38/15 seed) as real analysis.json files and drives
    the real recover_verdict.py; the LOAD-BEARING assertion is not "it exits 0"
    (the broken version exits 0 too) and not "the thin seed is flagged" (a flag
    nobody subtracts is what #269 is about) but THE MEAN IS THE SOUND SEED'S
    NUMBER, i.e. the thin seed's -180 is actually gone from the arithmetic.

    Case 2 does the same for the copy embedded in validate_onspot.sh, because
    THAT is what the farm runs on the happy path: a gate that lives only in the
    offline tool is a gate every non-reclaimed wave runs without.

    Every case that could pass vacuously is preceded by a guard proving the
    corpus was really parsed.
"""
import json, os, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOAK = os.path.join(ROOT, "tools", "batch_test", "soak")
SCRIPT = os.path.join(SOAK, "recover_verdict.py")
VALIDATE = os.path.join(SOAK, "validate_onspot.sh")
CAND = "testcand"

failures = []


def check(cond, msg):
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def game(stamp, rad_gpm, dire_gpm, winner="radiant"):
    """One analysis.json in the shape analyze_log.py emits.

    winner=None is a game that did not finish (wr() drops it from both halves
    of the winrate fraction).
    """
    return {
        "script_version": stamp, "winner": winner,
        "winner_by": "economy_30min_cap", "econ_winner": winner,
        "players": ([{"team": "radiant", "gpm": rad_gpm, "xpm": rad_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)] +
                    [{"team": "dire", "gpm": dire_gpm, "xpm": dire_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)]),
    }


def corpus(spec):
    """spec: {seed: (ab_games, ba_games, ab_delta, ba_delta, ba_winners)}.

    ab_delta is the radiant-wave candidate-minus-baseline gpm (candidate is
    radiant there), ba_delta the dire-wave one (candidate is dire).
    """
    d = tempfile.mkdtemp(prefix="verdict_depth_")
    n = 0
    for seed, (nab, nba, dab, dba, ba_winners) in sorted(spec.items()):
        for i in range(nab):
            g = game("mirror:%s:s%s:radiant" % (CAND, seed), 500 + dab, 500)
            json.dump(g, open(os.path.join(d, "g%04d.analysis.json" % n), "w"))
            n += 1
        for i in range(nba):
            w = ba_winners[i] if i < len(ba_winners) else "dire"
            g = game("mirror:%s:s%s:dire" % (CAND, seed), 500, 500 + dba, w)
            json.dump(g, open(os.path.join(d, "g%04d.analysis.json" % n), "w"))
            n += 1
    return d


def run(d, *extra):
    p = subprocess.run([sys.executable, SCRIPT, d, CAND] + list(extra),
                       capture_output=True, text=True)
    if p.returncode != 0:
        print(p.stdout)
        print(p.stderr)
        raise SystemExit("recover_verdict.py exited %d" % p.returncode)
    return json.loads(p.stdout), p.stderr


def row_of(v, seed):
    return next((r for r in v.get("per_seed", []) if r["seed"] == seed), None)


# --------------------------------------------------------------------------
# 1. W19's shape, at the real default.  s928 = ab41/ba1, s935 = ab38/ba15.
# --------------------------------------------------------------------------
# s935: ab -40, ba 0   -> -20   (the sound seed)
# s928: ab -40, ba -320 -> -180 (the poison: one dire game carries half of it)
# pooled mean would be -100; the gated mean must be -20.
W19 = corpus({"928": (41, 1, -40, -320, []),
              "935": (38, 15, -40, 0, [])})
v, err = run(W19)

check([r["seed"] for r in v.get("per_seed", [])] == ["928", "935"],
      "[guard] the corpus parsed: both seeds are in per_seed "
      "(not an empty/silent parse that would satisfy everything below)")
check((row_of(v, "928") or {}).get("ab_games") == 41
      and (row_of(v, "928") or {}).get("ba_games") == 1,
      "[guard] the thin seed was built as 41/1, as W19 had it")

check(v["mean"].get("gpm") == -20.0,
      "THE MEAN IS THE SOUND SEED'S NUMBER: -20, not the pooled -100 "
      "(the thin seed's -180 is out of the arithmetic, not merely labelled), "
      "got %r" % v["mean"].get("gpm"))
check(v["comps_better"].get("gpm") == "0/1",
      "the majority denominator counts the SCORED seeds only (0/1, not 0/2), "
      "got %r" % v["comps_better"].get("gpm"))
check("gpm" not in (row_of(v, "928") or {"gpm": 0}),
      "the thin seed carries no metric at all -- same treatment as ba=0, "
      "which is what option (A) of #269 asks for")
check((row_of(v, "935") or {}).get("gpm") == -20.0,
      "the sound seed is still scored (the gate refuses thin arms, it does "
      "not refuse unbalanced-but-deep ones), got %r"
      % (row_of(v, "935") or {}).get("gpm"))

# arm_depth is published on EVERY row: the W19 defect was invisible precisely
# because no field said how thin the seed was.
check((row_of(v, "928") or {}).get("arm_depth") == 1.95,
      "the thin seed is worth 1.95 games per leg and says so, got %r"
      % (row_of(v, "928") or {}).get("arm_depth"))
check((row_of(v, "935") or {}).get("arm_depth") == 21.51,
      "the sound seed is worth 21.51 games per leg and says so, got %r"
      % (row_of(v, "935") or {}).get("arm_depth"))
check((row_of(v, "928") or {}).get("excluded") == "THIN-ARM"
      and (row_of(v, "928") or {}).get("scored") is False,
      "the exclusion is named on the row, not left to be inferred")
check([s["seed"] for s in v.get("thin_arm_seeds", [])] == ["928"],
      "the exclusion is published at the TOP level too -- nobody reads a "
      "per-seed field they have no reason to suspect, got %r"
      % v.get("thin_arm_seeds"))
check(v.get("min_arm_depth") == 8,
      "the threshold in force is printed with the verdict, got %r"
      % v.get("min_arm_depth"))
check("THIN-ARM" in err and "s928" in err and "ba=1" in err,
      "stderr names the excluded seed and its legs, got %r" % err.strip()[-200:])

# --------------------------------------------------------------------------
# 2. The copy the farm actually runs (validate_onspot.sh) has the same gate.
# --------------------------------------------------------------------------
body = open(VALIDATE).read()
per_seed_blk = re.search(
    r'python3 - "\$WORK" "\$CAND" "\$SEED" "\$RS" "\$DS".*?\n(.*?)\nPY\n',
    body, re.S)
check(per_seed_blk is not None,
      "[guard] validate_onspot.sh's per-seed block was found (if this fails, "
      "everything below it tests nothing)")

if per_seed_blk:
    src = per_seed_blk.group(1)

    def onspot_row(nab, nba, dba):
        d = corpus({"777": (nab, nba, -40, dba, [])})
        p = subprocess.run([sys.executable, "-c", src, d, CAND, "777",
                            "mirror:%s:s777:radiant" % CAND,
                            "mirror:%s:s777:dire" % CAND],
                           capture_output=True, text=True)
        check(p.returncode == 0,
              "onspot per-seed block runs on a %d/%d corpus (%s)"
              % (nab, nba, p.stderr.strip()[:160]))
        return json.loads(p.stdout) if p.returncode == 0 else {}

    thin = onspot_row(41, 1, -320)
    check(thin.get("ab_games") == 41 and thin.get("ba_games") == 1,
          "[guard] the onspot block really read the 41/1 corpus, got %r/%r"
          % (thin.get("ab_games"), thin.get("ba_games")))
    check("gpm" not in thin,
          "THE FARM'S OWN COPY drops the thin seed's metrics -- a gate that "
          "lives only in recover_verdict.py is a gate every non-reclaimed "
          "wave runs without, got %r" % thin.get("gpm"))
    check(thin.get("excluded") == "THIN-ARM" and thin.get("arm_depth") == 1.95,
          "the farm's copy names the exclusion and the depth too, got %r/%r"
          % (thin.get("excluded"), thin.get("arm_depth")))

    sound = onspot_row(38, 15, 0)      # same shape as case 1's s935
    check(sound.get("gpm") == -20.0 and sound.get("scored") is True,
          "the farm's copy still scores the sound seed, got %r"
          % sound.get("gpm"))

# The two copies must carry the SAME number.  Extracted from the source of
# each, so drift is caught rather than assumed away.
off = re.search(r"MIN_ARM_DEPTH_DEFAULT\s*=\s*(\d+)", open(SCRIPT).read())
on = re.search(r"MIN_ARM_DEPTH\s*=\s*(\d+)", body)
check(off is not None and on is not None,
      "[guard] both MIN_ARM_DEPTH literals were found in source")
if off and on:
    check(off.group(1) == on.group(1) == "8",
          "offline and online agree on the threshold (%s vs %s)"
          % (off.group(1), on.group(1)))

# --------------------------------------------------------------------------
# 3. The aggregator's majority test counts the same population as its mean.
# --------------------------------------------------------------------------
# It used to divide by len(rows), so a seed excluded from the mean still voted
# against promote -- the same incoherence #269 names, with the sign that
# happened to look safe.  One scored seed (+50 gpm, deaths -1) beside one
# excluded seed must read `promote`, because 1 of 1 scored seed is better.
agg_blk = re.search(r'python3 - "\$CAND" "\$SEEDS" "\$RESULTS" "\$CAND_REF".*?\n(.*?)\nPY\n',
                    body, re.S)
check(agg_blk is not None, "[guard] validate_onspot.sh's aggregator block was found")
if agg_blk:
    rows = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False)
    rows.write(json.dumps({"seed": "1", "ab_games": 38, "ba_games": 15,
                           "arm_depth": 21.51, "scored": True, "gpm": 50.0,
                           "xpm": 5.0, "deaths": -1.0, "last_hits": 1.0}) + "\n")
    rows.write(json.dumps({"seed": "2", "ab_games": 41, "ba_games": 1,
                           "arm_depth": 1.95, "scored": False,
                           "excluded": "THIN-ARM"}) + "\n")
    rows.close()
    p = subprocess.run([sys.executable, "-c", agg_blk.group(1), CAND, "1 2",
                        rows.name, ""], capture_output=True, text=True)
    check(p.returncode == 0,
          "onspot aggregator runs (%s)" % p.stderr.strip()[:160])
    if p.returncode == 0:
        av = json.loads(p.stdout)
        check(len(av.get("per_seed", [])) == 2,
              "[guard] the aggregator read both rows, including the excluded one")
        check(av["comps_better"].get("gpm") == "1/1",
              "the mean's denominator is the scored population, got %r"
              % av["comps_better"].get("gpm"))
        check(av.get("suggested") == "promote",
              "the majority test divides by the SCORED count, matching the "
              "mean above it -- an excluded seed does not get a vote it was "
              "too thin to earn, got %r" % av.get("suggested"))
        check([s["seed"] for s in av.get("thin_arm_seeds", [])] == ["2"],
              "the farm's verdict.json publishes the excluded seeds, got %r"
              % av.get("thin_arm_seeds"))

# --------------------------------------------------------------------------
# 4. A wave of nothing but thin seeds still reports its census.
# --------------------------------------------------------------------------
# The gate must not take the evidence for itself down with it: this is the
# exact shape it exists to expose, so the game counts have to survive.
ALLTHIN = corpus({"801": (30, 1, -40, -320, []), "802": (30, 2, -40, -320, [])})
v2, err2 = run(ALLTHIN)
check([r["seed"] for r in v2.get("per_seed", [])] == ["801", "802"],
      "[guard] the all-thin corpus parsed")
check(v2.get("mean") == {},
      "no mean is invented from thin seeds, got %r" % v2.get("mean"))
check(v2.get("scored_games") == 63,
      "the census survives the gate (30+1+30+2 finished games), got %r"
      % v2.get("scored_games"))
check("WAVE ZEROED BY THE GATE" in err2 and "do NOT lower the gate" in err2,
      "a wave zeroed by the gate says so, and says it is a report about the "
      "wave rather than an argument for a smaller number, got %r"
      % err2.strip()[-200:])
check(v2.get("suggested") == "hold_or_reject",
      "an all-thin wave never suggests promote, got %r" % v2.get("suggested"))

# --------------------------------------------------------------------------
# 5. Lowering the gate is possible, loud, and called a skip.
# --------------------------------------------------------------------------
v3, err3 = run(W19, "--min-arm-depth", "1")
check(v3["mean"].get("gpm") == -100.0,
      "[guard] the override really did score the thin seed (pooled -100), "
      "got %r" % v3["mean"].get("gpm"))
check("SKIP" in err3 and "NOT a pass" in err3,
      "the override announces itself as a SKIP, not a pass -- the same "
      "discipline as --allow-pooled-basenames, got %r" % err3.strip()[-200:])
v4, err4 = run(W19, "--min-arm-depth", "8")
check("SKIP" not in err4,
      "passing the default explicitly is not an override and says nothing")

# --------------------------------------------------------------------------
# 6. The winrate legs are gated on their OWN denominators.
# --------------------------------------------------------------------------
# A seed can be deep enough in games and still have a single FINISHED game on
# one leg -- `if ab_n and ba_n` is the same predicate that could not tell 1
# from 15, in the same function.  The economy metrics must survive it.
WR = corpus({"900": (41, 15, -40, 0, [None] * 14 + ["dire"])})
v5, err5 = run(WR)
r900 = row_of(v5, "900") or {}
check(r900.get("ab_games") == 41 and r900.get("unfinished") == 14,
      "[guard] the seed was built deep in games but thin in finished ones, "
      "got %r games / %r unfinished" % (r900.get("ab_games"), r900.get("unfinished")))
check(r900.get("winrate_arm_depth") == 1.95,
      "the winrate's depth is measured on the FINISHED counts (41 and 1), "
      "not inherited from the economy gate, got %r"
      % r900.get("winrate_arm_depth"))
check("winrate" not in r900 and r900.get("winrate_excluded") == "THIN-ARM",
      "no winrate is computed from a one-game leg, and the abstention is named")
check("winrate" not in v5.get("mean", {}),
      "and no wave winrate is invented from it, got %r" % v5["mean"].get("winrate"))
check(r900.get("gpm") == -20.0,
      "the economy metrics still score that seed -- the fifth metric "
      "abstaining must not take the other four down with it, got %r"
      % r900.get("gpm"))

print()
if failures:
    print("%d FAILURE(S)" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")

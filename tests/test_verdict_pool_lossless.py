#!/usr/bin/env python3
"""recover_verdict.py must not score a pool it cannot show is lossless. [GH #225]

WHY THIS EXISTS
    Every wave since W10 is four runs (4x1, one seed per instance) that have to
    be pooled into one verdict.  Per-game files are named
    `<YYYYmmdd_HHMMSS>_slot<N>.analysis.json` (soak_loop.sh:76) with NO run
    token, and the four instances are launched in the same second with the same
    slot cadence -- so the obvious pooling step, `aws s3 cp` all four runs into
    one directory, makes cross-run basename collisions the norm.  W14 measured
    the damage: 208 files landed as 188, 184 scored games became 170, and the
    effect size moved 3.6 gpm.

    The reason that is worth a test rather than a checklist line is the failure
    DIRECTION: the tool still printed a verdict, still printed `suggested`, and
    `scored_games` shrank to a number no wave has an expected value for.  The
    old `except Exception: pass` around the json load was the same shape.  So
    this file pins two things at once: the lossless layout must WORK (fix A),
    and the lossy one must REFUSE rather than print (fix B).

HOW IT TESTS
    It drives the REAL script (no main(), no importable helper -- importing a
    reimplementation is the "three writers, zero readers" shape, GH #67) on
    real corpora written to temp dirs, and reads real stdout/stderr/exit codes.

    Case 1 is the arithmetic heart: the SAME games, laid out both ways, must
    give the same verdict when pooled per-run -- and the flat layout must not
    silently give a different one.  Both readings are asserted against a
    hand-computable expected value, so a bug that changes both identically
    still fails.
"""
import json, os, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "batch_test", "soak", "recover_verdict.py")
CAND = "poolcand"

failures = []


def check(cond, msg):
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def game(seed, side, rad_gpm, dire_gpm, nonce):
    """One analysis.json in the shape analyze_log.py emits.

    `nonce` only exists to keep two distinct games from being byte-identical,
    which is its own refusal (R1) and would otherwise mask what a case is
    actually testing.
    """
    return {
        "script_version": "mirror:%s:s%s:%s" % (CAND, seed, side),
        "winner": "radiant",
        "winner_by": "engine_natural",
        "econ_winner": "radiant",
        "wall_s": nonce,
        "players": ([{"team": "radiant", "gpm": rad_gpm, "xpm": rad_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)] +
                    [{"team": "dire", "gpm": dire_gpm, "xpm": dire_gpm,
                      "deaths": 5, "last_hits": 100} for _ in range(5)]),
    }


def raw_tag(hh, mm, ss, slot):
    """The exact basename soak_loop.sh writes -- the one with no run token."""
    return "20260826_%02d%02d%02d_slot%d.analysis.json" % (hh, mm, ss, slot)


def write(root, rel, obj):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(obj, f)
    return p


def run(root, *extra):
    # [GH #269] `--min-arm-depth 1` is DECLARATIVE: this corpus is 2-3 games
    # per leg (it is about basename collisions, not about statistical depth),
    # and the real gate would refuse to score it.  The gate is tested at its
    # real default in tests/test_verdict_arm_depth.py.
    out = subprocess.run([sys.executable, SCRIPT, root, CAND,
                          "--min-arm-depth", "1"] + list(extra),
                         capture_output=True, text=True)
    parsed = None
    if out.returncode == 0:
        try:
            parsed = json.loads(out.stdout)
        except Exception:
            parsed = None
    return out.returncode, parsed, out.stderr


# --- the corpus: four runs, one seed each, PARTIALLY colliding basenames ---
# Modelled on the real thing, not on the worst case.  The four instances are
# launched in the same second and their slots keep step, so SOME tags are
# identical across runs (W14: 20 of 208) while the rest drift apart.  Each run
# below contributes two colliding tags per wave and one tag of its own.
#
# The partial overlap is load-bearing for case 2: it is what leaves the
# flattened directory holding more than one seed, which is the evidence the
# refusal keys on.  (LIMIT, stated rather than hidden: a pool in which EVERY
# file collided down to a single run would show one seed and slip past R2 --
# but that pool is also a one-seed reading, which the batch desk already
# refuses to interpret on its own.)
#
# gpm is set so the verdict is hand-computable: per seed the radiant wave
# diffs +40 and the dire wave diffs +40, so every seed scores +40 and any
# subset of seeds still means +40.  That is deliberate -- case 1 must not be
# able to pass on the mean alone, so it checks the seed and file counts too.
RUNS = [("A", "801"), ("B", "802"), ("C", "803"), ("D", "804")]
# Waves are sequential within a run (mirror_ab.sh deploys, drains, redeploys),
# so the radiant and dire tags differ by their clock, exactly as real ones do.
SHARED = [raw_tag(21, 14, 24, 1), raw_tag(21, 14, 24, 2),   # radiant wave
          raw_tag(21, 40, 11, 1), raw_tag(21, 40, 11, 2)]   # dire wave


def corpus():
    """(run, basename, analysis) for all four runs, both waves."""
    out = []
    n = 0
    for ri, (run_name, seed) in enumerate(RUNS):
        for i, tag in enumerate(SHARED):
            n += 1
            side = "radiant" if i < 2 else "dire"
            gpms = (540, 500) if side == "radiant" else (500, 540)
            out.append((run_name, tag, game(seed, side, gpms[0], gpms[1], n)))
        # one tag per wave that this run does not share with any other
        for side, hh, mm in (("radiant", 21, 16), ("dire", 21, 42)):
            n += 1
            gpms = (540, 500) if side == "radiant" else (500, 540)
            out.append((run_name, raw_tag(hh, mm, 30 + ri, 1),
                        game(seed, side, gpms[0], gpms[1], n)))
    return out


TOTAL_FILES = len(RUNS) * (len(SHARED) + 2)          # 24
# what survives `cp` flattening them all into one directory: the 4 shared tags
# (last writer wins) plus each run's 2 private tags
FLAT_SURVIVORS = len(SHARED) + len(RUNS) * 2         # 12

# --- 1. per-run subdirectories: the lossless layout must score -------------
d1 = tempfile.mkdtemp(prefix="verdict_pool_nested_")
for run_name, base, g in corpus():
    write(d1, os.path.join(run_name, base), g)
rc, v, err = run(d1)
check(rc == 0, "per-run subdirectories score cleanly (rc=%d, %s)" % (rc, err[:200]))
if v:
    check(v["input"]["files_seen"] == TOTAL_FILES
          and v["input"]["games_loaded"] == TOTAL_FILES,
          "all %d files across 4 subdirectories are found, got %r"
          % (TOTAL_FILES, v["input"]))
    check(v["input"]["source_dirs"] == 4,
          "the census reports 4 source dirs, got %r" % v["input"].get("source_dirs"))
    check(len(v["per_seed"]) == 4,
          "all four seeds survive pooling, got %d" % len(v["per_seed"]))
    check(v["mean"].get("gpm") == 40.0,
          "the pooled gpm is the hand-computed +40, got %r" % v["mean"].get("gpm"))
    check(v.get("scored_games") == TOTAL_FILES,
          "every game is scored, got %r" % v.get("scored_games"))

# --- 2. THE W14 SHAPE: flattened pool must refuse, not print --------------
# This is the case the issue was opened on.  Note the corpus here is what
# SURVIVES the flattening (12 of 24 files: the four shared tags keep only the
# last run to be copied): the tool can never see the 12 that `cp` destroyed,
# which is precisely why it has to refuse on the LAYOUT instead of on a count.
d2 = tempfile.mkdtemp(prefix="verdict_pool_flat_")
survivors = {}
for run_name, base, g in corpus():
    survivors[base] = g          # last writer wins, exactly like `cp`
for base, g in survivors.items():
    write(d2, base, g)
check(len(survivors) == FLAT_SURVIVORS,
      "the flattening really does destroy files (%d left of %d)"
      % (len(survivors), TOTAL_FILES))
rc, v, err = run(d2)
check(rc == 2, "a flattened multi-run pool is REFUSED (rc=%d, not 0)" % rc)
check(v is None, "the refusal prints no verdict at all")
check("seeds=" in err and "GH #225" in err,
      "the refusal names the offending directory and its seeds, got %r" % err[:300])

# --- 3. the override is a skip, and says so -------------------------------
rc, v, err = run(d2, "--allow-pooled-basenames")
check(rc == 0, "--allow-pooled-basenames lets a known-safe layout through (rc=%d)" % rc)
check("SKIPPED, NOT PASSED" in err,
      "the override announces itself as a skip, not a pass, got %r" % err[:200])
if v:
    check(v["input"]["pooled_basename_dirs_overridden"] == 1,
          "the override is recorded in the machine-readable census, got %r"
          % v["input"].get("pooled_basename_dirs_overridden"))

# --- 4. single-run flat input (the documented usage) still works ----------
# The refusal must key on >1 SEED in a directory, not on flatness: the header's
# own single-run example is flat with raw tag names, and breaking it would be
# trading one silent loss for a loud one.
d4 = tempfile.mkdtemp(prefix="verdict_pool_single_")
for run_name, base, g in corpus():
    if run_name == "A":
        write(d4, base, g)
rc, v, err = run(d4)
check(rc == 0, "one run, flat, raw tag names -- still scores (rc=%d, %s)" % (rc, err[:200]))
if v:
    check(len(v["per_seed"]) == 1 and v["mean"].get("gpm") == 40.0,
          "the single-run reading is unchanged, got %d seed(s) gpm=%r"
          % (len(v["per_seed"]), v["mean"].get("gpm")))

# --- 5. a pool whose basenames the caller already disambiguated ----------
# The batch desk's standing workaround (`<run>__<tag>`).  It is safe, so it
# must not be refused -- otherwise the fix would break the practice it exists
# to make unnecessary.
d5 = tempfile.mkdtemp(prefix="verdict_pool_prefixed_")
for run_name, base, g in corpus():
    write(d5, "%s__%s" % (run_name, base), g)
rc, v, err = run(d5)
check(rc == 0, "a flat pool with run-prefixed basenames is NOT refused (rc=%d)" % rc)
if v:
    check(len(v["per_seed"]) == 4 and v["input"]["files_seen"] == TOTAL_FILES,
          "and it reads all four runs, got %d seed(s) / %r"
          % (len(v["per_seed"]), v["input"].get("files_seen")))

# --- 6. the same game at two paths is a double count, not a windfall -----
d6 = tempfile.mkdtemp(prefix="verdict_pool_dup_")
for run_name, base, g in corpus():
    write(d6, os.path.join(run_name, base), g)
    if run_name == "A":
        write(d6, os.path.join("copy", base), g)   # byte-identical
rc, v, err = run(d6)
check(rc == 2, "identical bytes at two paths is REFUSED (rc=%d)" % rc)
check("more than one path" in err,
      "the duplicate refusal says what it found, got %r" % err[:200])

# --- 7. an unparseable file is a lost game, not a silent skip ------------
# This is the `except Exception: pass` that used to sit around the json load.
d7 = tempfile.mkdtemp(prefix="verdict_pool_bad_")
for run_name, base, g in corpus():
    write(d7, os.path.join(run_name, base), g)
with open(os.path.join(d7, "A", "truncated.analysis.json"), "w") as f:
    f.write('{"script_version": "mirror:')
rc, v, err = run(d7)
check(rc == 2, "a truncated analysis.json is REFUSED (rc=%d)" % rc)
check("did not parse" in err and "truncated.analysis.json" in err,
      "the refusal names the file, got %r" % err[:300])
rc, v, err = run(d7, "--allow-unparseable")
check(rc == 0 and v is not None,
      "--allow-unparseable scores without it (rc=%d)" % rc)
if v:
    check(v["input"]["unparseable"] == 1
          and v["input"]["files_seen"] == TOTAL_FILES + 1,
          "and the dropped file is COUNTED in the census, got %r" % (v["input"],))

# --- 8. R1's two halves are both load-bearing ----------------------------
# Same basename + DIFFERENT bytes is case 1, the whole point of fix (A), and is
# already asserted there.  This pins the other half: identical bytes under
# DIFFERENT basenames is two games that merely scored alike, not a duplicate.
# Without this narrowing R1 refuses any synthetic corpus built from a repeated
# template -- tests/test_verdict_winrate.py is exactly that, and a fix that
# takes an existing test down with it is not a fix.
d8 = tempfile.mkdtemp(prefix="verdict_pool_twin_")
twin = game("801", "radiant", 540, 500, 1)
write(d8, raw_tag(21, 14, 24, 1), twin)
write(d8, raw_tag(21, 14, 25, 2), dict(twin))      # identical bytes, other tag
write(d8, raw_tag(21, 40, 11, 1), game("801", "dire", 500, 540, 2))
rc, v, err = run(d8)
check(rc == 0, "identical bytes under different basenames is NOT a duplicate "
               "(rc=%d, %s)" % (rc, err[:200]))
if v:
    check(v["input"]["games_loaded"] == 3,
          "and all three games are scored, got %r" % v["input"].get("games_loaded"))

print()
if failures:
    print("%d FAILURE(S)" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")

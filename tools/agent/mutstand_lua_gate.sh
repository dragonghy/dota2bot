#!/usr/bin/env bash
# Mutation stand for tools/agent/lua_gate.py (GH #624).  Director 2026-09-10.
# Run by hand when that gate or tests/test_lua_gate.py is edited.
#
# WHY THIS GATE NEEDS A STAND.  Its whole value is that it REFUSES; a build
# that runs, prints a healthy banner and never refuses is indistinguishable
# from a working one on every channel a reader has except the one this stand
# supplies.  That is not hypothetical here -- the sibling python gate's own
# acceptance file records four checks going green against a gate that was
# behaving as specified, and this repo has twice shipped a gate whose "pass"
# was a did-not-run (GH #171 SKIP, GH #205 `Unable to locate package`).
#
# DISCIPLINE (inherited from mutstand_reclaim_materiality.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`, under a trap so an
#     interrupted stand cannot leave the mutant in the tree (GH #418);
#   * bare exit codes -- the test writes a log and `$?` is read with no pipe;
#   * a mutant whose target string is absent ABORTS rather than scoring caught;
#   * __pycache__ purged between mutants;
#   * a behavioural fingerprint decides INERT, and the probes below cover the
#     branches the mutants move -- a fingerprint that never reaches a branch
#     cannot tell a no-op from a change.
#
# Usage: bash tools/agent/mutstand_lua_gate.sh
set -u
cd "$(dirname "$0")/../.."

SRC=tools/agent/lua_gate.py
TEST=tests/test_lua_gate.py
WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_luagate.XXXXXX")
cp "$SRC" "$WORK/orig.py"
sha256sum "$SRC" > "$WORK/sum.txt"

purge_pyc() { find . -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null; }
restore() {
    cp "$WORK/orig.py" "$SRC"
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}
trap restore EXIT

if ! lua5.1 -v >/dev/null 2>&1; then
    echo "UNCERTIFIABLE -- lua5.1 absent; this stand's subject cannot run."
    echo "  Buy it:  apt-get install -y lua5.1   (this line is NOT a pass)"
    exit 2
fi

apply_mutant() {
    MUT="$1" python3 - "$SRC" <<'PY'
import os, sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
mut = os.environ["MUT"]
PAIRS = {
    # M1: membership stops consulting the measured `in_gate` flag and takes
    #     every measured test.  The gate still runs, still reports, still
    #     refuses on a real red -- it is simply no longer the FAST leg it
    #     promises to be, and a 100-minute test in the manifest would now hang
    #     every push in the repo.  Nothing in the banner changes shape.
    "M1": ("(selected if meta.get(\"in_gate\") else skipped).append(rel)",
           "selected.append(rel)"),
    # M2: THE mutant of a gate.  Findings are collected, printed, counted --
    #     and the exit code stays 0, so `.githooks/pre-push` lets the red
    #     through.  Every human-readable channel still says "FAIL".
    "M2": ("    if findings:\n        return EXIT_FINDINGS",
           "    if findings:\n        return EXIT_CLEAN"),
    # M3: a selected test that stops answering is dropped instead of raising.
    #     This is GH #171's SKIP re-opened on a new leg: the promise "this test
    #     ran" silently becomes "this test was mentioned".
    "M3": ("            unrun.append((rel, \"timed out after %.0fs (manifest says %.2fs)\"",
           "            ran += 0 or ((rel, \"timed out after %.0fs (manifest says %.2fs)\""),
    # M4: new, never-measured tests are ignored rather than run.  The gate then
    #     stops gating the day someone adds a file -- and it stops SILENTLY,
    #     because a frozen list reports a perfectly healthy `selected` count.
    "M4": ("    for rel in unmeasured:\n        rc, out, secs, timed_out = run_one(rel, timeout)",
           "    for rel in []:\n        rc, out, secs, timed_out = run_one(rel, timeout)"),
    # M5: the gate runs the test FILE instead of going through the runner.  A
    #     Lua test file ends with `return tests`; loading it asserts nothing and
    #     exits 0.  So this mutant turns every in-scope test into a guaranteed
    #     pass while the banner counts them all as `ran` -- a did-not-run
    #     wearing a pass, the exact family GH #200 legislated against and
    #     `tools/agent/rc.sh` refuses by name.
    "M5": ("            [LUA, \"tests/run_tests.lua\", name],",
           "            [LUA, rel],"),
    # M6: an empty selection reads as clean instead of uncertifiable.  A
    #     manifest that lost its `tests` key (or was pointed at the wrong repo)
    #     then reports a green gate that ran nothing at all.
    "M6": ("    if not selected:\n        print(\"LUA GATE COULD NOT RUN -- the manifest selected 0 tests.\")",
           "    if not selected:\n        return EXIT_CLEAN\n    if False:\n        print(\"LUA GATE COULD NOT RUN -- the manifest selected 0 tests.\")"),
    # M7: scope FAILS OPEN.  An empty path list -- the value the hook produces
    #     whenever `git diff` errors, and the value a caller passing no paths
    #     produces -- now means "skip".  The gate then reports exit 0 with a
    #     tidy SKIPPED BY SCOPE line on precisely the pushes where it could not
    #     tell what was being pushed.  This is the same sentence GH #171,
    #     GH #205 and the CI smoke job each got wrong, in a fourth place.
    "M7": ("    if not paths:\n        return True",
           "    if not paths:\n        return False"),
    # M8: scope demands that EVERY changed path be in scope instead of any.  A
    #     realistic push (one hero file plus a report) then skips the leg, and
    #     the more files a change touches the more certainly it is skipped --
    #     the exact inversion of what the scope is for.
    "M8": ("    return any(p.startswith(IN_SCOPE_PREFIXES) for p in paths if p)",
           "    return all(p.startswith(IN_SCOPE_PREFIXES) for p in paths if p)"),
    # M9: the baseline swallows EVERY red, not the eighteen it was taken from.
    #     The gate keeps running, keeps printing, keeps naming failures -- and
    #     never refuses again.  This is the mutant that turns "you did not add
    #     a red" back into the state GH #624 was opened about, and it moves no
    #     exit code that any run on a green tree would notice.
    "M9": ("    known_red = set(manifest.get(\"known_red\") or ())",
           "    known_red = type(\"E\", (), {\"__contains__\": lambda s, k: True})()"),
    # M10: a manifest with no baseline reads as TOTAL amnesty instead of none.
    #      Same sentence as M7's, one field over: absence of a record treated
    #      as permission rather than as absence.
    "M10": ("    known_red = set(manifest.get(\"known_red\") or ())",
            "    known_red = set(manifest[\"known_red\"]) if manifest.get(\"known_red\")"
            " else type(\"E\", (), {\"__contains__\": lambda s, k: True})()"),
}
old, new = PAIRS[mut]
if old not in src:
    sys.exit("MUTATION TARGET ABSENT for %s -- this stand cannot claim that mutant" % mut)
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

# Behavioural fingerprint.  Each probe is a throwaway repo driven through the
# real gate, and the recorded facts are the exit code plus the sentences the
# refusal is made of -- because half the mutants above move a decision without
# moving a word of the prose, and the other half move prose without moving the
# exit code.
fingerprint() {
    python3 - <<'PY'
import json, os, shutil, subprocess, sys, tempfile

REPO = os.getcwd()
GATE = os.path.join(REPO, "tools", "agent", "lua_gate.py")
RUNNER = os.path.join(REPO, "tests", "run_tests.lua")

PASS = "local t = {}\nt['ok'] = function() end\nreturn t\n"
FAIL = "local t = {}\nt['bad'] = function() error('BOOM') end\nreturn t\n"
HANG = ("local t = {}\nt['hang'] = function() local x = os.time()\n"
        "while os.time() - x < 30 do end end\nreturn t\n")

# (files, manifest tests) -- every branch a mutant above can move.
PROBES = {
    # an out-of-gate red: only M1 (membership) makes this one speak.
    "outofgate": ({"test_slow_one.lua": FAIL, "test_fast_one.lua": PASS},
                  {"tests/test_slow_one.lua": {"seconds": 9.0, "in_gate": False,
                                               "reason": "too_slow"},
                   "tests/test_fast_one.lua": {"seconds": 0.1, "in_gate": True,
                                               "reason": "fast"}}),
    # an in-gate red: M2 and M5 both make this stop refusing, by different routes.
    "red": ({"test_red.lua": FAIL},
            {"tests/test_red.lua": {"seconds": 0.2, "in_gate": True,
                                    "reason": "fast"}}),
    # a selected test that no longer answers: M3's branch.
    "hang": ({"test_hang.lua": HANG},
             {"tests/test_hang.lua": {"seconds": 0.2, "in_gate": True,
                                      "reason": "fast"}}),
    # a brand-new unmeasured red: M4's branch.
    "new": ({"test_known.lua": PASS, "test_new.lua": FAIL},
            {"tests/test_known.lua": {"seconds": 0.1, "in_gate": True,
                                      "reason": "fast"}}),
    # nothing selected at all: M6's branch.
    "empty": ({"test_a.lua": PASS}, {}),
    # a red that IS baselined beside one that is not: M9/M10's branch.  Without
    # this probe both mutants change only which reds are forgiven, the
    # fingerprint never reaches the baseline, and they would score INERT --
    # which reads as "the tests are strong" and is the opposite of true.
    "baselined": ({"test_old.lua": FAIL, "test_new.lua": FAIL},
                  {"tests/test_old.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"},
                   "tests/test_new.lua": {"seconds": 0.2, "in_gate": True, "reason": "fast"}},
                  ["tests/test_old.lua"]),
    # an all-green tree: no mutant here may move this one.
    "green": ({"test_a.lua": PASS, "test_b.lua": PASS},
              {"tests/test_a.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"},
               "tests/test_b.lua": {"seconds": 0.1, "in_gate": True, "reason": "fast"}}),
}

TAGS = ("COULD NOT RUN", "FAIL  ", "UNCERTIFIABLE", "BOOM", "findings",
        "new test(s) not in the manifest", "ran,", "SKIPPED BY SCOPE", "ALREADY RED", "GREEN again", "known-red")

tmp = tempfile.mkdtemp(prefix="mutfp_")
try:
    for name, probe in PROBES.items():
        files, mtests = probe[0], probe[1]
        kred = probe[2] if len(probe) > 2 else None
        root = os.path.join(tmp, name)
        os.makedirs(os.path.join(root, "tests"))
        os.makedirs(os.path.join(root, "tools", "agent"))
        shutil.copy(RUNNER, os.path.join(root, "tests", "run_tests.lua"))
        for fn, body in files.items():
            open(os.path.join(root, "tests", fn), "w").write(body)
        mpath = os.path.join(root, "tools", "agent", "lua_gate_manifest.json")
        man = {"per_test_cap_seconds": 3.0, "budget_seconds": 25.0,
               "hook_timeout_seconds": 3.0, "tests": mtests}
        if kred is not None:
            man["known_red"] = kred
        json.dump(man, open(mpath, "w"))
        env = dict(os.environ)
        env["LUA_GATE_ROOT"] = root
        env["LUA_GATE_MANIFEST"] = mpath
        # The scope arguments are part of the fingerprint, not a separate
        # probe set: M7/M8 move only the --if-touched decision, and a
        # fingerprint that never passes --if-touched would score both INERT
        # and record that as evidence the tests are strong.
        for label, extra in (("", []),
                             ("+none", ["--if-touched", "docs/a.md"]),
                             ("+lua", ["--if-touched", "bots/x.lua"]),
                             ("+empty", ["--if-touched"]),
                             ("+mixed", ["--if-touched", "docs/a.md", "tests/b.lua"])):
            p = subprocess.run([sys.executable, GATE] + extra, cwd=REPO, env=env,
                               capture_output=True, text=True, timeout=180)
            tags = [t for t in TAGS if t in p.stdout]
            # The `N ran, M findings` line is the one a reader scans; keep it whole.
            banner = [ln.strip() for ln in p.stdout.splitlines()
                      if ln.startswith("lua gate: ")]
            print("%s%s=%d:%s:%s" % (name, label, p.returncode, "|".join(tags),
                                     "||".join(banner)))
finally:
    shutil.rmtree(tmp, ignore_errors=True)
PY
}

purge_pyc
fingerprint > "$WORK/fp.base" 2>&1

echo "== mutation stand (GH #624 lua gate): $SRC / $TEST"
worst=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10; do
    purge_pyc
    if ! apply_mutant "$m"; then
        echo "$m  APPLY-FAILED -- stand aborted rather than score a no-op as caught"
        restore; exit 2
    fi
    fingerprint > "$WORK/fp.$m" 2>&1
    if cmp -s "$WORK/fp.base" "$WORK/fp.$m"; then
        echo "$m  INERT -- the source changed and the behaviour did not; this is a"
        echo "       DEFECT IN THE STAND, not a finding about the tests"
        restore; worst=2; continue
    fi
    python3 "$TEST" > "$WORK/$m.log" 2>&1
    rc=$?
    sha=$(sha256sum "$SRC" | cut -c1-12)
    if [ "$rc" -eq 0 ]; then
        echo "$m  SURVIVED (sha=$sha) -- behaviour moved and no test noticed"
        echo "       log: $WORK/$m.log"
        worst=3
    else
        echo "$m  CAUGHT   (sha=$sha, exit $rc)"
    fi
    restore
done

purge_pyc
python3 "$TEST" > "$WORK/baseline.log" 2>&1
brc=$?
if [ "$brc" -ne 0 ]; then
    echo "BASELINE RED after restore (exit $brc) -- the stand's own readings are"
    echo "  not trustworthy until this is explained.  log: $WORK/baseline.log"
    tail -20 "$WORK/baseline.log"
    exit 2
fi
echo "baseline after restore: exit 0 (clean tree, tests green)"
echo "worst=$worst  (0 all caught / 2 stand defect / 3 a mutant survived)"
exit "$worst"

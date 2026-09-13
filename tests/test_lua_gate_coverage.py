#!/usr/bin/env python3
"""Acceptance for tools/agent/lua_gate_coverage.py (GH #806).

WHY THIS EXISTS.  The subject computes a RELATION -- which `tests/test_*.lua`
files no automatic reader runs -- and ratchets it.  A ratchet has exactly one
interesting property (it goes red when the set GROWS) and exactly one way to be
worthless (it never does).  This repo has recorded that failure twice in a
week on other legs: py_gate's `5f` asserted `len(rt) >= 100` while claiming to
assert coverage, and the selfcheck's Lua leg had four cases that "passed"
without the clean run finishing.  So the growth case here is a MUTATION STAND,
not an inspection: the CLI is run against a temp tree, a file is really made
uncovered, and the exit code is read bare.

The load-bearing claims, in the order they can fail:
  1. the two discovery rules AGREE.  The subject re-spells 开工自检's tag rule
     in python; this extracts the shell leg's OWN pipeline out of
     routine_selfcheck.sh, runs it, and asserts set equality.  Drift on either
     side fails HERE rather than silently shrinking the covered set.
  2. `in_gate`, the tag leg, and `known_red` each count as covered -- and a
     file covered by NONE of them is reported.
  3. THE RATCHET BITES: a newly-uncovered file exits 3 and is named.
  4. no baseline => exit 2 with a banner that does not read like a pass
     (rule 10's "SKIP/UNCERTIFIABLE is not a pass").
  5. --update-baseline REFUSES growth (a ratchet you can silence by re-running
     the recorder is not a ratchet), and records a shrink.
  6. it runs NO Lua test.  The whole design rests on being cheap enough that
     nobody skips it; a subject that quietly shells out to lua5.1 would be a
     different tool with a different price.

Run:  python3 tests/test_lua_gate_coverage.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SUBJECT = os.path.join(REPO, "tools", "agent", "lua_gate_coverage.py")
SELFCHECK = os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh")

checks = 0
failures = []


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
    print(("  ok   " if cond else "  FAIL ") + label)


sys.path.insert(0, os.path.join(REPO, "tools", "agent"))
import lua_gate_coverage as subj  # noqa: E402


# --- 1: the two spellings of 开工自检's discovery rule agree -----------------
#
# The shell leg's own `files=$(...)` block is extracted from the script rather
# than retyped: a copy of the rule inside its own test asserts the copy.
src = open(SELFCHECK, encoding="utf-8").read()
m = re.search(r"^\s*files=\$\(\s*\{(.*?)\n\s*\}\s*\|\s*sort -u\s*\)", src, re.S | re.M)
check(m is not None,
      "1a: routine_selfcheck.sh still has the `files=$( { ... } | sort -u )` "
      "discovery block this test extracts (if this fails, the leg was "
      "rewritten and claim 1 is no longer checking anything)")
if m:
    pipeline = "{" + m.group(1) + "\n} | sort -u"
    shell = subprocess.run(["bash", "-c", pipeline], cwd=REPO,
                           capture_output=True, text=True, timeout=120)
    shell_set = {ln.strip() for ln in shell.stdout.splitlines() if ln.strip()}
    py_set = subj.selfcheck_covered(REPO)
    check(len(shell_set) > 0,
          "1b: (control) the extracted shell pipeline discovers >0 files -- an "
          "empty set would make 1c pass vacuously (got %d)" % len(shell_set))
    only_sh = sorted(shell_set - py_set)
    only_py = sorted(py_set - shell_set)
    check(not only_sh and not only_py,
          "1c: the subject's tag rule EQUALS the shell leg's discovery set "
          "(shell-only=%s py-only=%s)" % (only_sh[:5], only_py[:5]))


# --- temp-tree helpers -------------------------------------------------------
def make_tree(files, manifest, baseline=None):
    """files: {name: source}.  Returns a temp root with tests/ + manifest."""
    root = tempfile.mkdtemp(prefix="lgc_")
    os.makedirs(os.path.join(root, "tests"))
    os.makedirs(os.path.join(root, "tools", "agent"))
    for name, body in files.items():
        with open(os.path.join(root, "tests", name), "w", encoding="utf-8") as fh:
            fh.write(body)
    mpath = os.path.join(root, "tools", "agent", "lua_gate_manifest.json")
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh)
    bpath = os.path.join(root, "tools", "agent", "lua_gate_coverage_baseline.json")
    if baseline is not None:
        with open(bpath, "w", encoding="utf-8") as fh:
            json.dump(baseline, fh)
    return root, mpath, bpath


def run_cli(root, mpath, bpath, *args):
    env = dict(os.environ)
    env["LUA_GATE_COVERAGE_ROOT"] = root
    env["LUA_GATE_COVERAGE_MANIFEST"] = mpath
    env["LUA_GATE_COVERAGE_BASELINE"] = bpath
    p = subprocess.run([sys.executable, SUBJECT] + list(args),
                       capture_output=True, text=True, timeout=120, env=env)
    return p.returncode, p.stdout + p.stderr


BASE_FILES = {
    "test_in_gate.lua": "-- plain\n",
    "test_tagged.lua": "-- [detector] watched by the selfcheck leg\n",
    "test_amnestied.lua": "-- plain\n",
    "test_orphan.lua": "-- plain, read by nothing\n",
}
BASE_MANIFEST = {
    "known_red": ["tests/test_amnestied.lua"],
    "tests": {
        "tests/test_in_gate.lua": {"in_gate": True, "seconds": 1.0, "reason": "fast"},
        "tests/test_tagged.lua": {"in_gate": False, "seconds": 6.0,
                                  "reason": "timed_out"},
        "tests/test_amnestied.lua": {"in_gate": False, "seconds": 6.0,
                                     "reason": "timed_out"},
        "tests/test_orphan.lua": {"in_gate": False, "seconds": 6.0,
                                  "reason": "timed_out"},
    },
}

# --- 2: each covering channel counts, and the orphan is reported -------------
root, mpath, bpath = make_tree(BASE_FILES, BASE_MANIFEST)
try:
    st = subj.classify(root, mpath)
    check(st["uncovered"] == ["tests/test_orphan.lua"],
          "2a: exactly the file covered by no channel is uncovered (got %s)"
          % st["uncovered"])
    check(st["gate"] == 1 and st["selfcheck_leg"] == 1 and st["known_red"] == 1,
          "2b: in_gate / tag leg / known_red are each counted as a covering "
          "channel (got gate=%d leg=%d amnesty=%d)"
          % (st["gate"], st["selfcheck_leg"], st["known_red"]))

    # --- 4: no baseline => 2, and the banner is not a pass line --------------
    rc, out = run_cli(root, mpath, bpath)
    check(rc == 2, "4a: no baseline exits 2, not 0 (got %d)" % rc)
    check("UNCERTIFIABLE" in out and "not a pass" in out.lower(),
          "4b: the no-baseline banner says it is NOT a pass (got %r)"
          % out.strip()[-160:])

    rc, out = run_cli(root, mpath, bpath, "--update-baseline")
    check(rc == 0 and os.path.exists(bpath),
          "4c: --update-baseline writes the baseline and exits 0 (got %d)" % rc)
    rc, out = run_cli(root, mpath, bpath)
    check(rc == 0 and "unchanged" in out,
          "4d: (control) an unchanged tree exits 0 -- without this, 3a below "
          "could be red for any reason at all (got %d)" % rc)

    # --- 3: THE MUTATION STAND -- the ratchet must bite ----------------------
    # M1: a tagged file loses its tag.  This is the real-world shape: a test
    # that WAS watched stops being watched, and nothing else about the tree
    # changes.
    tagged = os.path.join(root, "tests", "test_tagged.lua")
    keep = open(tagged, encoding="utf-8").read()
    with open(tagged, "w", encoding="utf-8") as fh:
        fh.write("-- tag removed\n")
    rc, out = run_cli(root, mpath, bpath)
    check(rc == 3,
          "3a [M1 tag removed]: a newly-uncovered file exits 3 (got %d)" % rc)
    check("test_tagged.lua" in out and "NEW UNCOVERED" in out,
          "3b [M1]: the growth line NAMES the file (got %r)" % out.strip()[-200:])

    # --- 5: --update-baseline refuses to record the growth -------------------
    rc, out = run_cli(root, mpath, bpath, "--update-baseline")
    check(rc == 3 and "REFUSED" in out,
          "5a [M1]: --update-baseline REFUSES growth -- otherwise the ratchet "
          "is silenced by re-running the recorder (got %d)" % rc)
    saved = json.load(open(bpath, encoding="utf-8"))
    check("tests/test_tagged.lua" not in saved.get("uncovered", []),
          "5b [M1]: the refused run did not write the grown set to disk")

    with open(tagged, "w", encoding="utf-8") as fh:
        fh.write(keep)
    rc, out = run_cli(root, mpath, bpath)
    check(rc == 0,
          "3c [M1 restored]: restoring the tag returns the leg to 0 -- the "
          "red in 3a was caused by the mutation and nothing else (got %d)" % rc)

    # M2: a brand-new test lands with no manifest row (the stale-manifest
    # channel: 50 real files are in this state on trunk 2026-09-13).
    with open(os.path.join(root, "tests", "test_brand_new.lua"), "w",
              encoding="utf-8") as fh:
        fh.write("-- landed after the last measurement\n")
    rc, out = run_cli(root, mpath, bpath)
    check(rc == 3 and "test_brand_new.lua" in out,
          "3d [M2 unmeasured newcomer]: a test with no manifest row is "
          "uncovered and exits 3 (got %d)" % rc)
    check("no_manifest_row" in out,
          "3e [M2]: the reason distinguishes 'never measured' from 'too slow' "
          "-- they have different fixes (got %r)" % out.strip()[-200:])

    # 5c: a SHRINK is recordable (the set is meant to go down).
    os.remove(os.path.join(root, "tests", "test_brand_new.lua"))
    os.remove(os.path.join(root, "tests", "test_orphan.lua"))
    rc, out = run_cli(root, mpath, bpath, "--update-baseline")
    check(rc == 0 and json.load(open(bpath, encoding="utf-8"))["uncovered"] == [],
          "5c: a shrink IS recordable -- the baseline refuses growth only "
          "(got %d)" % rc)
finally:
    shutil.rmtree(root, ignore_errors=True)

# --- 6: it runs no Lua test --------------------------------------------------
root2, mpath2, bpath2 = make_tree(BASE_FILES, BASE_MANIFEST)
try:
    # A PATH holding a lua5.1 that fails loudly if invoked.  If the subject
    # shells out to it, the tripwire file appears.
    bindir = tempfile.mkdtemp(prefix="lgc_bin_")
    trip = os.path.join(bindir, "TRIPPED")
    shim = os.path.join(bindir, "lua5.1")
    with open(shim, "w", encoding="utf-8") as fh:
        fh.write("#!/bin/sh\ntouch %s\nexit 0\n" % trip)
    os.chmod(shim, 0o755)
    env = dict(os.environ)
    env["PATH"] = bindir + os.pathsep + env.get("PATH", "")
    env["LUA_GATE_COVERAGE_ROOT"] = root2
    env["LUA_GATE_COVERAGE_MANIFEST"] = mpath2
    env["LUA_GATE_COVERAGE_BASELINE"] = bpath2
    t0 = time.time()
    subprocess.run([sys.executable, SUBJECT, "--update-baseline"],
                   capture_output=True, text=True, timeout=120, env=env)
    elapsed = time.time() - t0
    check(not os.path.exists(trip),
          "6a: the subject invoked no lua5.1 -- it is set arithmetic, and the "
          "design rests on it staying cheap")
    check(elapsed < 10.0,
          "6b: a full run costs well under 10s (got %.2fs) -- the number is "
          "recorded because 'cheap' is the reason this can be run every round"
          % elapsed)
    print("  NOTE  subject cost on this container: %.2fs" % elapsed)
finally:
    shutil.rmtree(root2, ignore_errors=True)
    shutil.rmtree(bindir, ignore_errors=True)

print("\n%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)

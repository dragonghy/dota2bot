#!/usr/bin/env python3
"""Acceptance for the fast-Lua-detector leg of tools/agent/routine_selfcheck.sh.

WHY THIS EXISTS.  The wrapper's trunk-health leg ran the python suite only, and
said so on purpose: "NOT the Lua suite: that one needs lua5.1 + minutes, and is
the push gate's job".  On 2026-08-24T22:55Z a fresh corpus-size pin (1d41fb1)
reddened tests/test_corpus_scale.lua's detector and sat red on origin/main for
~5 hours across five stream triggers, every one of which ran this script and
read a CLEAN trunk-health line.  The exemption's premise was wrong in the half
that mattered: the full Lua suite is ~48 minutes, but the TREE-SCANNING subset
-- the only subset anyone else's landing can redden -- is seconds.

The load-bearing claims, in the order they can fail:
  1. the leg EXISTS and its red path raises the script's exit code (a leg that
     prints a finding and exits 0 is the "detector nobody runs" shape again,
     one layer down)
  2. discovery is BY TAG, and covers every tagged file in the live tree.  A
     hardcoded list is the rot this repo has already paid for in
     corpus_scale.lua's seven files -- a detector written tomorrow must be
     picked up without editing the wrapper
  3. discovery matching NOTHING is itself a finding, not a pass (the empty-match
     trap: "on the books, matching nothing")
  4. a missing lua5.1 SKIPs and does NOT claim trunk is red -- an absent
     interpreter is not a failing test
  5. END TO END on a real tree: a reddened detector file makes the real script
     print TRUNK RED and exit 3; a clean tree exits 0 on this leg.  Case 5 is
     the one that would have caught the 08-24 miss.

Run:  python3 tests/test_selfcheck_lua_leg.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SCRIPT = os.path.join(REPO, "tools", "agent", "routine_selfcheck.sh")

failures = []
checks = 0


def check(cond, label):
    global checks
    checks += 1
    if not cond:
        failures.append(label)
        print("  FAIL  %s" % label)


src = open(SCRIPT, encoding="utf-8").read()

# The leg's body: from its own header printf to the end of the file.  Asserting
# against the whole script would let a match in the python leg stand in for the
# Lua one.
at = src.find("trunk health (fast Lua detectors)")
check(at != -1, "1a: the script has a fast-Lua-detector leg at all")
leg = src[at:] if at != -1 else ""

# ---------------------------------------------------------------------------
# 1. the red path raises the exit code
# ---------------------------------------------------------------------------
check("TRUNK RED" in leg, "1b: the red path says TRUNK RED")
# `note` is the wrapper's own exit-code accumulator; without it the leg prints
# a finding and the script still exits 0.
check(leg.count("note 3") >= 2,
      "1c: BOTH the red path and the no-detectors path call `note 3` "
      "(a leg that reports without raising the exit code is not a gate)")

# ---------------------------------------------------------------------------
# 2. discovery is by tag, and covers the live tree
# ---------------------------------------------------------------------------
check("grep -l" in leg and r"\[detector\]" in leg and r"\[ratchet\]" in leg,
      "2a: discovery greps for the [detector]/[ratchet] tags")

# Run the wrapper's OWN discovery block, lifted verbatim out of the script,
# then compare it against an independent scan of the tree.
#
# Lifting it matters, and the first draft got this wrong: it re-typed the
# discovery command here instead.  That made every coverage claim below vacuous
# with respect to the script -- deleting a named file from the wrapper left
# this test green, because this test was reading its own copy.  Two mutations
# (drop test_level_gate_census, drop test_wk_fact_anchor) SURVIVED and are what
# said so.  A test that mirrors the thing it checks is checking the mirror.
_dm = re.search(r"^(\s*files=\$\(.*?\| sort -u \))\s*$", leg, re.S | re.M)
check(_dm is not None, "2a2: the discovery block can be lifted out of the script")
disc = subprocess.run(
    ["bash", "-c", 'cd "$1" || exit 1\n' + (_dm.group(1) if _dm else "files=") +
     '\nprintf "%s\\n" $files', "_", REPO],
    capture_output=True, text=True)
discovered = set(p for p in disc.stdout.split() if p)

tagged = set()
for name in sorted(os.listdir(os.path.join(REPO, "tests"))):
    if not (name.startswith("test_") and name.endswith(".lua")):
        continue
    body = open(os.path.join(REPO, "tests", name), encoding="utf-8", errors="replace").read()
    # The tag as it appears in a test NAME: tests['[detector] ...'] = function()
    if re.search(r"tests\[\s*['\"]\[(detector|ratchet)\]", body):
        tagged.add("tests/" + name)

missing = sorted(tagged - discovered)
check(not missing,
      "2b: every tagged detector is discovered (missed: %s)" % (missing or "none"))
check("tests/test_corpus_scale.lua" in discovered,
      "2c: the detector that caught the 2026-08-24 red is in the set")

# The four reds actually sitting on origin/main on 2026-08-25, per the 00:5xZ
# full-suite run (1796 tests / 4 failures, all trunk-pre-existing).  This is the
# leg's reason for existing stated as a test: it must cover the real cases, not
# a class defined to fit whatever it already covers.
for f, why in (("tests/test_corpus_scale.lua", "the tpgap corpus-size pin"),
               ("tests/test_level_gate_census.lua", "ability_item_usage_generic 5768/5823"),
               ("tests/test_wk_fact_anchor.lua", "hero_lion drift, GH #166")):
    check(f in discovered, "2d: %s is covered (%s)" % (f, why))

# `[census]` names the same kind of claim but must NOT become a discovery tag:
# the tag marks what a test claims, not what it costs, and adding it drags in
# the GH #124 sweep family -- measured, 4.2s -> 7m08s.  Named tree-scanners are
# how the fast census files get in.
check(r"\[census\]" not in leg,
      "2e: [census] is not a discovery tag (it costs 7m08s -- time the set "
      "before adding a tag)")

# ---------------------------------------------------------------------------
# 3. matching nothing is a finding
# ---------------------------------------------------------------------------
check("NO DETECTORS FOUND" in leg,
      "3: zero discovered files is reported, not passed over silently")

# ---------------------------------------------------------------------------
# 4. no lua5.1 => SKIP, not red
# ---------------------------------------------------------------------------
check("command -v lua5.1" in leg, "4a: the leg checks for lua5.1 first")
skip_at = leg.find("SKIP (no lua5.1")
check(skip_at != -1, "4b: a missing interpreter SKIPs")
# The SKIP branch must not be the red branch: `note 3` must not follow it.
check(skip_at == -1 or "note 3" not in leg[skip_at:],
      "4c: SKIP does not raise the exit code -- an absent interpreter is not "
      "a failing test")

# ---------------------------------------------------------------------------
# 5. end to end on a real tree
# ---------------------------------------------------------------------------
# The leg is run on its own, NOT via the whole wrapper.  Invoking
# routine_selfcheck.sh from here would recurse without bound: the wrapper runs
# tests/run_py_tests.sh, which runs this file, which runs the wrapper.  (It
# does -- that is how this comment got written.)  Running the leg's own source
# with the wrapper's exit-code accumulator supplied is the real code either
# way; what is dropped is the git/network legs, which this test is not about.
LEG_END = "printf '\\nselfcheck worst exit:"
_lo = src.find("printf '\\n=== trunk health (fast Lua detectors)")
_hi = src.find(LEG_END)
check(_lo != -1 and _hi > _lo, "5-pre: the leg's source can be isolated")
LEG_SRC = src[_lo:_hi] if (_lo != -1 and _hi > _lo) else ""

if shutil.which("lua5.1") is None:
    print("  SKIP  5: end-to-end needs lua5.1")
elif not LEG_SRC:
    print("  SKIP  5: leg source not isolated")
else:
    # The leg is a 开工 check, so its whole claim is that it is fast.  The
    # budget is an assertion, not a convenience: without it, widening discovery
    # to the `[census]` tag turns this test into a 14-minute hang instead of a
    # failure (it did -- that mutation had to be killed by hand).  A hang reads
    # as "still working"; a red reads as "you broke it".
    BUDGET_S = 120

    def run_leg(tree):
        """Run the real leg source in `tree` -> (text, said_red, rc)."""
        harness = ("set -u\nworst=0\n"
                   "note() { [ \"$1\" -gt \"$worst\" ] && worst=\"$1\"; return 0; }\n"
                   + LEG_SRC + "\nexit \"$worst\"\n")
        try:
            p = subprocess.run(["bash", "-c", harness], cwd=tree,
                               capture_output=True, text=True, timeout=BUDGET_S)
        except subprocess.TimeoutExpired:
            return ("__TIMEOUT__", False, -1)
        out = p.stdout + p.stderr
        return out, ("TRUNK RED" in out), p.returncode

    tmp = tempfile.mkdtemp(prefix="selfcheck_leg_")
    try:
        tree = os.path.join(tmp, "repo")
        # The WHOLE tree minus .git (~29MB).  A partial copy is the wrong
        # fixture and says so loudly: copying only tests/tools/bots made
        # test_itemtrip_supply_gap red on "cannot read docs/BOT_API_REFERENCE.md"
        # -- an invented failure that would have been mistaken for the leg
        # working.  These detectors scan the tree; the tree is what they need.
        shutil.copytree(REPO, tree, symlinks=True,
                        ignore=shutil.ignore_patterns(".git"))

        clean_leg, clean_red, clean_rc = run_leg(tree)
        check(clean_leg != "__TIMEOUT__",
              "5a0: the leg finishes inside %ds -- it is a 开工 check, and a "
              "discovery set that outgrows the budget must fail here rather "
              "than hang" % BUDGET_S)
        check(not clean_red, "5a: a clean tree does not report TRUNK RED")
        check(clean_rc == 0, "5a2: a clean tree exits 0 on this leg (got %d)" % clean_rc)
        check(re.search(r"\d+ detector file\(s\), 0 failures", clean_leg) is not None,
              "5b: a clean tree reports the count it actually ran")
        n_clean = re.search(r"(\d+) detector file\(s\)", clean_leg)
        check(n_clean is not None and int(n_clean.group(1)) > 0,
              "5c: the clean run is not vacuous (ran > 0 files)")

        # Redden one discovered detector the way a landing would: make an
        # assertion in it false.  test_corpus_scale.lua's own detector is the
        # 08-24 case, so reproduce THAT one -- add a live corpus-size pin to a
        # test file and confirm the leg surfaces it.
        victim = os.path.join(tree, "tests", "test_data_consistency.lua")
        body = open(victim, encoding="utf-8").read()
        n_fx = len([f for f in os.listdir(os.path.join(REPO, "tests", "fixtures"))
                    if f.endswith(".lua")])
        body += ("\ntests['injected corpus pin (test fixture, not a real claim)'] = "
                 "function()\n    assert(1 + 1 == 2)\n    local n = %d\n"
                 "    assert(n == %d, 'injected')\nend\n" % (n_fx, n_fx))
        open(victim, "w", encoding="utf-8").write(body)

        red_leg, red_said, red_rc = run_leg(tree)
        check(red_said, "5d: a reddened detector makes the leg print TRUNK RED")
        check("test_corpus_scale" in red_leg,
              "5e: the leg names the failing detector file")
        check(re.search(r"TRUNK RED -- \d+ of \d+ Lua detector file", red_leg) is not None,
              "5f: the red line carries the red/ran counts")
        check(red_rc == 3, "5g: the leg raises the exit code to 3 (got %d)" % red_rc)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

print("\n%d checks, %d failures" % (checks, len(failures)))
for f in failures:
    print("  " + f)
sys.exit(1 if failures else 0)

#!/usr/bin/env python3
"""`tools/agent/promote_atoms.py` must go red for the RIGHT reason.

WHY THIS EXISTS (2026-09-04, director; test_set.md §EI)
    The tool is green on trunk, and a green checker proves nothing about the
    day it is supposed to bite.  Both shapes it watches are, by construction,
    absent from today's tree:

      (A) the `pullcad` trap -- a live gate naming a promoted id;
      (B) a violated co-promote atom -- a subject promoted while a
          prerequisite is still gated (test_set.md §ED.5, `stayfield` /
          `stayfield2` needing `fieldsip`).

    So every case below is driven on a SYNTHETIC tree built in a temp dir,
    where the violating day can actually be constructed.

    THE LOAD-BEARING CASE IS 3, and it is not the violation -- it is the
    DECOY.  On the real tree, all five occurrences that a comment-blind scan
    would call violations are cautionary comments warning about this exact
    trap (three `pullbeat` mentions in mode_roam_generic.lua, two `'X'`
    placeholders in jmz_func.lua).  A checker without comment-stripping is
    RED on trunk from birth, and a check that is red from birth gets turned
    off -- which is precisely how the hand stops being raised.  Case 3 pins
    the decoys as decoys; case 4 pins that stripping did not also blind the
    tool to the live site sitting next to them.

    Case 6 pins the vacuity guard: a registry row naming an id the tree does
    not have must be LOUD.  A typo in `promote_atoms.json` is the one failure
    a constraint registry must never answer with a green tick.

HOW IT TESTS
    On the real script, as a subprocess, on trees it writes itself.  Exit
    codes are read BARE (subprocess returncode), never through a pipe --
    evidence discipline 3, the thing this repo has paid for 35 times.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "agent", "promote_atoms.py")

failures = []
checks = 0
tmpdirs = []


def check(cond, msg):
    global checks
    checks += 1
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def tree(lua_files, atoms):
    """Build a synthetic repo: bots/<name>.lua files + iterations/promote_atoms.json."""
    d = tempfile.mkdtemp(prefix="promote_atoms_")
    tmpdirs.append(d)
    os.makedirs(os.path.join(d, "bots"))
    os.makedirs(os.path.join(d, "iterations"))
    for name, body in lua_files.items():
        with open(os.path.join(d, "bots", name), "w", encoding="utf-8") as fh:
            fh.write(body)
    if atoms is not None:
        with open(os.path.join(d, "iterations", "promote_atoms.json"),
                  "w", encoding="utf-8") as fh:
            json.dump({"atoms": atoms}, fh)
    return d


def run(d):
    p = subprocess.run([sys.executable, SCRIPT, d],
                       capture_output=True, text=True)
    return p.returncode, p.stdout


ATOM = [{"name": "fieldatom", "rule": "no_promote_without",
         "subject": ["stayfield"], "prereq": ["fieldsip"],
         "ref": "test_set.md §ED.5"}]

GATED_BOTH = {"a.lua": (
    "if not J.IsSoakCandidate( 'stayfield' ) then return false end\n"
    "if not J.IsSoakCandidate( 'fieldsip' ) then return true end\n")}

# ---------------------------------------------------------------- case 1
rc, out = run(tree(GATED_BOTH, ATOM))
check(rc == 0, "case 1: both members still gated -> exit 0")
check("stayfield=GATED" in out and "fieldsip=GATED" in out,
      "case 1: and it prints the state it read for each member")

# ---------------------------------------------------------------- case 2
# The violating day: `stayfield` promoted (gate deleted, PROMOTED note left),
# `fieldsip` still gated.  This is the ruling of test_set.md §ED.5 biting.
rc, out = run(tree({"a.lua": (
    "-- [GH #485 20260904] PROMOTED (was soak-candidate 'stayfield')\n"
    "if not J.IsSoakCandidate( 'fieldsip' ) then return true end\n")}, ATOM))
check(rc == 3, "case 2: subject promoted while prereq still gated -> exit 3")
check("ATOM" in out and "'fieldatom' violated" in out and "stayfield" in out,
      "case 2: and it names the atom and the id, not just a count")

# ---------------------------------------------------------------- case 3
# THE DECOY CASE.  Every occurrence is a comment -- exactly trunk's shape.
rc, out = run(tree({"a.lua": (
    "-- [GH #143 20260823] PROMOTED (was soak-candidate 'pullbeat')\n"
    "-- had this read `IsSoakCandidate('pullcad') and IsSoakCandidate('pullbeat')`\n"
    "-- it would be frozen FALSE.  A gate written as IsSoakCandidate('X') and\n"
    "--[[ IsSoakCandidate('pullbeat') in a block comment, too ]]\n"
    "return true\n")}, []))
check(rc == 0, "case 3: promoted id named ONLY in comments -> exit 0 (decoys)")
check("FROZEN    none" in out,
      "case 3: and it says so, rather than staying silent")
check("scanned: 0 distinct live gate id" in out,
      "case 3: guard -- the comment lines really did contribute no live site")

# ---------------------------------------------------------------- case 3b
# A single-line `--[[ ... ]]` proves nothing about block stripping: it starts
# with `--`, so the LINE stripper alone already kills it.  Only a MULTI-LINE
# block separates the two, and it is the shape that fails toward noise -- the
# body lines do not start with `--`, so a line-only stripper reads the gate
# call on line 3 as live.  (Found by the mutation stand: M3, which removes
# block stripping, survived until this case existed.)
rc, out = run(tree({"a.lua": (
    "local x = 1\n"
    "--[[ a multi-line note about the trap\n"
    "if J.IsSoakCandidate( 'pullbeat' ) then return true end\n"
    "]]\n"
    "return false\n")}, []))
check("scanned: 0 distinct live gate id" in out,
      "case 3b: a gate call inside a MULTI-LINE block comment is not a live site")
check(rc == 0, "case 3b: and so the run is clean")

# ---------------------------------------------------------------- case 4
# Stripping must not have blinded it: same file, one LIVE site added.
rc, out = run(tree({"a.lua": (
    "-- [GH #143 20260823] PROMOTED (was soak-candidate 'pullbeat')\n"
    "-- IsSoakCandidate('pullbeat') in a comment right above the live one\n"
    "if J.IsSoakCandidate( 'pullcad' ) and J.IsSoakCandidate( 'pullbeat' ) then\n"
    "  return true\n"
    "end\n")}, []))
check(rc == 3, "case 4: the SAME file plus one live site -> exit 3")
check("FROZEN" in out and "'pullbeat' is promoted" in out,
      "case 4: and it is the frozen-FALSE finding, named")
check("a.lua:3" in out,
      "case 4: pointing at the live line (3), not at the comment above it")

# ---------------------------------------------------------------- case 5
# Direction is one-way: promoting the PREREQ while the subject stays gated is
# explicitly allowed by the ruling, and must stay green.
rc, out = run(tree({"a.lua": (
    "-- [GH #485 20260904] PROMOTED (was soak-candidate 'fieldsip')\n"
    "if not J.IsSoakCandidate( 'stayfield' ) then return false end\n")}, ATOM))
check(rc == 0, "case 5: prereq promoted, subject gated -> exit 0 (one-way)")

# ---------------------------------------------------------------- case 6
# The vacuity guard: a registry row naming an id the tree does not have.
rc, out = run(tree(GATED_BOTH, [{
    "name": "typoatom", "rule": "no_promote_without",
    "subject": ["stayfeild"], "prereq": ["fieldsip"]}]))
check(rc == 3, "case 6: registry names an id absent from the tree -> exit 3")
check("UNKNOWN" in out and "stayfeild" in out,
      "case 6: and it names the id, so the typo is fixable from the line")

# ---------------------------------------------------------------- case 7
# A rule this tool cannot evaluate must not be counted as satisfied.
rc, out = run(tree(GATED_BOTH, [{
    "name": "futureatom", "rule": "some_rule_from_2027",
    "subject": ["stayfield"], "prereq": ["fieldsip"]}]))
check(rc == 3, "case 7: unknown rule kind -> exit 3, not a silent pass")

# ---------------------------------------------------------------- case 8
# Could-not-run is its own answer (repo convention 0/2/3), not a pass.
rc, out = run(tree(GATED_BOTH, None))
check(rc == 2, "case 8: no registry file -> exit 2 (could-not-run, not a pass)")

# ---------------------------------------------------------------- case 9
# The real registry must parse and evaluate on the real tree.  This is the
# row that would otherwise be prose: if iterations/promote_atoms.json rots,
# the constraint stops binding and nothing else notices.
rc, out = run(ROOT)
check(rc in (0, 3), "case 9: the REAL tree + REAL registry evaluates (not exit 2)")
check("field_hold_needs_magnitude" in out,
      "case 9: and the §ED.5 atom is actually in the registry it read")

for d in tmpdirs:
    shutil.rmtree(d, ignore_errors=True)

print()
print("%d check(s), %d failure(s)" % (checks, len(failures)))
sys.exit(1 if failures else 0)

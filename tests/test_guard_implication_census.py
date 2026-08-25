#!/usr/bin/env python3
"""Ratchet + reverse assertions for the cross-statement satisfiability scan.

The scan (`tools/agent/guard_implication_census.py`, strategy `0SAT` next cell)
asks: after an early-return guard establishes `not G`, is a LATER condition in
the same function body still satisfiable?  Its answer today is that the axis is
EMPTY of behaviour defects -- and an empty answer is only worth anything if the
thing that produced it has teeth.  Two layers, and the second is the reason this
file is long.

  LAYER 1 -- the ratchet (section 1).  The nine strategy decision files read
  ZERO.  Whole-repo reads exactly one site, `mode_attack_generic:8`, which is a
  duplicated module guard with NO behaviour consequence (line 3 already returns
  on a superset of the same disjuncts).  It is ALLOWLISTED, not fixed: deleting
  it buys no behaviour and would need its own argument, the same call made on
  the `hero_earth_spirit` / `hero_phoenix` redundancies.  A NEW cross-statement
  dead branch anywhere in `bots/` turns this file red the day it lands, and
  fixing the allowlisted one means deleting its row -- the list can only shrink.

  LAYER 2 -- the reverse assertions (section 2).  The naive version of this
  scan reported FOUR findings, and every one was false, from four separate
  missing pieces of flow.  Each is pinned below as synthetic Lua the scan must
  stay SILENT on.  This matters more than the ratchet: the failure mode of a
  tool that claims arithmetic certainty is not "it misses one", it is "it
  confidently names a live branch dead, someone deletes the branch, and the
  behaviour goes with it".  Simplify any of the four out of the scanner and
  this file names which one.

    (a) NESTING ARITHMETIC.  `for`/`while` open through their own `do`; counting
        both inflates depth forever and a fact leaks across a function boundary
        (first reading: `jmz_func:5773` -> `:5975`, two unrelated functions).
    (b) SIBLING BRANCHES.  A guard inside a `then` arm says nothing in the
        `else` arm (`hero_storm_spirit:326`).
    (c) REBINDING.  A fact dies when its name is reassigned
        (`minion_with_skill:543`, where `FindAoELocation` is called a second
        time in between).
    (d) ARGUMENT IDENTITY, two halves:
        - a fact on `f(b)` dies when `b` is rebound, not only when `f` is
          (`aba_defend:542` and seven siblings);
        - two calls that differ ONLY in a string argument are two different
          predicates (`mode_roam_generic:1434`: `modifier_black_king_bar_immune`
          vs `modifier_lich_chainfrost_slow`).

Run: python3 tests/test_guard_implication_census.py   (or tests/run_py_tests.sh)
"""

import importlib.util
import os
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "guard_implication_census.py")

_spec = importlib.util.spec_from_file_location("guard_implication_census", TOOL)
G = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(G)

FAIL = []


def ok(name, cond, detail=""):
    if cond:
        print("  ok    %s" % name)
    else:
        FAIL.append(name)
        print("  FAIL  %s%s" % (name, ("  -- " + detail) if detail else ""))


def eq(name, got, want):
    ok(name, got == want, "got %r want %r" % (got, want))


def scan_source(lua):
    """Run the scan over a synthetic snippet, return its findings."""
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as fh:
        fh.write(lua)
        path = fh.name
    try:
        return G.scan_file(path, "<synthetic>", {})
    finally:
        os.unlink(path)


def repo_scan(paths):
    findings = []
    stats = {}
    for rel in paths:
        findings.extend(G.scan_file(os.path.join(REPO, rel), rel, stats))
    return findings, stats


# ----------------------------------------------------------------------------
# 1. the ratchet
# ----------------------------------------------------------------------------
print("\n1. ratchet -- what the tree reads today")

nine, nine_stats = repo_scan(G.STRATEGY_FILES)
eq("the nine strategy decision files carry no cross-statement dead branch",
   [(f["file"], f["line"]) for f in nine], [])

# A zero reading is only news if the scan reached anything.  These are floors,
# not exact counts: the files churn, and pinning them exactly would make every
# unrelated edit red for no reason.
ok("the scan actually reached the nine files (guards)",
   nine_stats.get("guard_1line", 0) + nine_stats.get("guard_3line", 0) >= 400,
   "guards %r" % nine_stats)
ok("the scan actually reached the nine files (conditions under a live fact)",
   nine_stats.get("cond_under_fact", 0) >= 300, "stats %r" % nine_stats)
ok("some fact and some later condition actually shared an lvalue",
   nine_stats.get("lvalue_overlap", 0) + nine_stats.get("atom_overlap", 0) > 0,
   "stats %r" % nine_stats)

# Whole-repo allowlist.  ONE row.  Delete the row when the site is fixed.
# `mode_attack_generic:8` repeats a strict subset of the module guard on line 3
# -- zero behaviour, kept because removing it needs its own argument.
ALLOWLIST = {("bots/mode_attack_generic.lua", 8)}

ALL_LUA = []
for root, _dirs, files in os.walk(os.path.join(REPO, "bots")):
    for f in sorted(files):
        if f.endswith(".lua"):
            p = os.path.join(root, f)
            ALL_LUA.append(os.path.relpath(p, REPO))
ALL_LUA.sort()

allf, all_stats = repo_scan(ALL_LUA)

# Every finding rests on knowing which block a line is in, so a file whose
# nesting does not balance is a file whose reading means nothing. All 275 do.
# (Three did not until `--[[ ]]` blocks were carried across lines: the `do` in
# "furnished to do so" in an MIT header was being counted as a block opener.)
# Asserted off the SCAN's own stats, not off a re-derivation here -- a check
# that walks its own path can stay green while the scan's path rots.
eq("every scanned file's block nesting balances",
   all_stats.get("unbalanced", []), [])
sites = {(f["file"], f["line"]) for f in allf}
eq("no cross-statement dead branch outside the allowlist",
   sorted(sites - ALLOWLIST), [])
eq("every allowlisted site still reads dead (delete the row when fixed)",
   sorted(ALLOWLIST - sites), [])

# The allowlisted site's whole claim is that line 3 already covers it.  If the
# module guard on line 3 is ever narrowed, the duplicate stops being dead and
# this reading changes meaning -- so pin what makes it dead, not just that it is.
attack = [f for f in allf if f["file"] == "bots/mode_attack_generic.lua"]
eq("the allowlisted site is dead in EVERY disjunct, not just one",
   sorted({f["kind"] for f in attack}), ["DEAD-BRANCH"])
eq("and it is the module guard on line 3 that kills it",
   sorted({f["guard_line"] for f in attack}), [3])


# ----------------------------------------------------------------------------
# 2. reverse assertions -- the four false positives the naive scan produced
# ----------------------------------------------------------------------------
print("\n2. reverse -- each of these must stay SILENT")

# (a) nesting arithmetic: a `for ... do` must open exactly one block, so the
#     fact dies at the first function's `end` and never reaches the second.
eq("(a) a fact does not leak across a function boundary",
   scan_source(
       "function J.A( bot )\n"
       "\tif bot:GetCurrentMovementSpeed() < 285 then return false end\n"
       "\tfor _, e in pairs( t )\n"
       "\tdo\n"
       "\t\tif e ~= nil then return true end\n"
       "\tend\n"
       "\treturn false\n"
       "end\n"
       "\n"
       "function J.B( bot )\n"
       "\tif bot:GetCurrentMovementSpeed() < 285 then return false end\n"
       "\treturn true\n"
       "end\n"), [])

# ... and the positive control for (a): inside ONE function it must still fire,
# otherwise "silent" above would be silence about nothing.
same_fn = scan_source(
    "function J.A( bot )\n"
    "\tif bot:GetCurrentMovementSpeed() < 285 then return false end\n"
    "\tif bot:GetCurrentMovementSpeed() < 200 then return true end\n"
    "\treturn false\n"
    "end\n")
eq("(a control) within one body the same shape IS reported",
   [(f["line"], f["kind"]) for f in same_fn], [(3, "DEAD-BRANCH")])

# The two kinds are different instructions to whoever reads a finding:
# DEAD-BRANCH means the whole block can never be entered, DEAD-DISJUNCT means
# ONE leg of an `or` can never be the reason it was. Collapsing them would turn
# "delete this leg" into "delete this block" -- the expensive direction.
partial = scan_source(
    "function X.J( bot )\n"
    "\tif DotaTime() < 300 then return false end\n"
    "\tif DotaTime() < 200 or bot:GetLevel() >= 6 then\n"
    "\t\treturn true\n"
    "\tend\n"
    "\treturn false\n"
    "end\n")
eq("a partly-dead `or` is a DEAD-DISJUNCT, not a DEAD-BRANCH",
   [(f["kind"], f["disjunct"]) for f in partial],
   [("DEAD-DISJUNCT", "DotaTime() < 200")])

# (b) sibling branches: the `then` arm's guard says nothing in the `else` arm.
eq("(b) an else-arm is not under the then-arm's guard",
   scan_source(
       "function X.C( bot )\n"
       "\tlocal aoe = bot:FindAoELocation( true, false, p, r, 0, 0 )\n"
       "\tif J.IsInLaningPhase() then\n"
       "\t\tif aoe.count >= 2 then\n"
       "\t\t\treturn 1\n"
       "\t\tend\n"
       "\telse\n"
       "\t\tif aoe.count >= 3 then\n"
       "\t\t\treturn 2\n"
       "\t\tend\n"
       "\tend\n"
       "\treturn 0\n"
       "end\n"), [])

# (c) rebinding: the second `count >= 2` asks about a different object.
eq("(c) a reassignment between guard and test kills the fact",
   scan_source(
       "function X.D( u )\n"
       "\tlocal aoe = u:FindAoELocation( true, true, p, 0, r, 0, 0 )\n"
       "\tif aoe.count >= 2 then\n"
       "\t\treturn 1\n"
       "\tend\n"
       "\taoe = u:FindAoELocation( true, false, p, 0, r, 0, 0 )\n"
       "\tif aoe.count >= 2 then\n"
       "\t\treturn 2\n"
       "\tend\n"
       "\treturn 0\n"
       "end\n"), [])

# (d1) argument identity: `f(b)` depends on `b`, not only on `f`.
eq("(d1) rebinding an ARGUMENT kills a fact pinned on the call",
   scan_source(
       "function X.E( team )\n"
       "\tlocal b = GetTower( team, Tower.Top1 )\n"
       "\tif IsValidBuildingTarget(b) then\n"
       "\t\treturn 1\n"
       "\tend\n"
       "\tb = GetBarracks( team, Barracks.TopMelee )\n"
       "\tif IsValidBuildingTarget(b) then\n"
       "\t\treturn 2\n"
       "\tend\n"
       "\treturn 0\n"
       "end\n"), [])

# (d2) string identity: two modifier names are two predicates.
eq("(d2) two calls differing only in a string argument are not the same lvalue",
   scan_source(
       "function X.F( bot )\n"
       "\tif bot:HasModifier(\"modifier_black_king_bar_immune\") then return false end\n"
       "\tif bot:HasModifier('modifier_lich_chainfrost_slow') then\n"
       "\t\treturn true\n"
       "\tend\n"
       "\treturn false\n"
       "end\n"), [])

# ... and its positive control: the SAME string still collapses to one lvalue.
same_str = scan_source(
    "function X.G( bot )\n"
    "\tif bot:HasModifier('modifier_lich_chainfrost_slow') then return false end\n"
    "\tif bot:HasModifier('modifier_lich_chainfrost_slow') then\n"
    "\t\treturn true\n"
    "\tend\n"
    "\treturn false\n"
    "end\n")
eq("(d2 control) the same string argument IS the same lvalue",
   [f["line"] for f in same_str], [3])

# A guard whose condition is a top-level `and` negates to a DISJUNCTION and must
# establish nothing.  Recorded as a CONTRACT rather than a mutation target: the
# scanner's explicit `and` check turns out to be belt-and-braces, because a
# conjunction does not parse as a comparison or an atom either way.  Deleting
# the check does not turn this red today.  It is asserted so that a future
# parser that DOES accept richer terms cannot quietly start negating an `and`.
eq("an `and` guard establishes no fact (its negation is a disjunction)",
   scan_source(
       "function X.H( bot )\n"
       "\tif DotaTime() < 300 and bot:GetLevel() < 6 then return false end\n"
       "\tif DotaTime() < 200 then\n"
       "\t\treturn true\n"
       "\tend\n"
       "\treturn false\n"
       "end\n"), [])

# A guard whose body is more than a bare `return` does not establish the fact
# either -- control can fall through it.
eq("a guard that does work before returning is not an early-return guard",
   scan_source(
       "function X.I( bot )\n"
       "\tif DotaTime() < 300 then\n"
       "\t\tbot:Action_ClearActions( true )\n"
       "\t\treturn false\n"
       "\tend\n"
       "\tif DotaTime() < 200 then\n"
       "\t\treturn true\n"
       "\tend\n"
       "\treturn false\n"
       "end\n"), [])


# ----------------------------------------------------------------------------
# 3. the arithmetic core, on its own
# ----------------------------------------------------------------------------
print("\n3. interval satisfiability")

eq("< 0.08 and >= 1 is unsatisfiable (the 0SAT finding's shape)",
   G.unsat([("<", 0.08), (">=", 1.0)]), True)
eq("< 0.08 and >= 0.0 is satisfiable", G.unsat([("<", 0.08), (">=", 0.0)]), False)
eq("a half-open point is empty", G.unsat([(">", 5.0), ("<=", 5.0)]), True)
eq("a closed point is not empty", G.unsat([(">=", 5.0), ("<=", 5.0)]), False)
eq("== outside the interval is empty", G.unsat([("==", 9.0), ("<", 5.0)]), True)
eq("== inside the interval is not", G.unsat([("==", 3.0), ("<", 5.0)]), False)
eq("== and ~= on the same value is empty",
   G.unsat([("==", 3.0), ("~=", 3.0)]), True)
eq("5*60 parses as 300", G.as_number("5*60"), 300.0)
eq("a bare identifier is not a number", G.as_number("botHP"), None)
eq("a string token is not a number", G.as_number("_hero_"), None)

print()
if FAIL:
    print("%d FAILED: %s" % (len(FAIL), ", ".join(FAIL)))
    sys.exit(1)
print("guard-implication census: ratchet holds and all four reverse cases stay silent")

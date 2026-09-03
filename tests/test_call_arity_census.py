#!/usr/bin/env python3
"""Ratchet + reverse assertions for the call-arity census.

The class: Lua does not check arity, and `.luacheckrc`'s `only = { "1" }` means
iron rule 6 does not either.  A call that is short an argument passes both, and
the missing parameter arrives as nil.  Usually that is harmless.  Once, at
`aiug:993`, it meant `X.SetUseItem` fell off the end of its own dispatcher and
issued no engine action while the `return` behind it still skipped the whole
item loop -- see tests/test_lf_salve_cast_type.lua for the frames.

Four layers:

  LAYER 0 -- the premise.  `.luacheckrc` still says `only = {"1"}`, so this tool
  is not duplicating a check the gate already runs.  If someone turns the full
  warning set on, this section says so instead of the tool quietly persisting.

  LAYER 1 -- the ratchet.  `bots/` carries exactly these 40 mismatched call
  sites today and every one is judged in the tool's ALLOWLIST with a reason.  A
  new one is red the day it lands; fixing an old one means deleting its row, so
  the list can only shrink.  Keyed by (file, name, kind, passed, declared),
  never by line number -- charter 0LN2: line numbers drift under comment edits.

  LAYER 2 -- the denominators.  A "0 new findings" reading and a scanner that
  reached nothing look identical on paper (charter 0IMPL judgement two), so the
  scale of the scan is asserted alongside the finding count.

  LAYER 3 -- the reverse assertions.  The dangerous direction for THIS tool is a
  false positive: a call that was always correct gets "fixed" and takes
  behaviour with it.  Each synthetic case pins one half of what a mismatch is.

Section 4 pins the one row with teeth (`hero_bristleback:620`, an 8.0 handed to
a helper with a hardcoded 5) so that fixing it or refuting it has to happen
deliberately, and section 5 pins the repaired call site itself.

Run: python3 tests/test_call_arity_census.py   (or tests/run_py_tests.sh)
"""

import importlib.util
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "call_arity_census.py")

_spec = importlib.util.spec_from_file_location("call_arity_census", TOOL)
C = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(C)

FAIL = []


def ok(name, cond, detail=""):
    if cond:
        print("  ok    %s" % name)
    else:
        print("  FAIL  %s%s" % (name, ("\n        " + detail) if detail else ""))
        FAIL.append(name)


# ---------------------------------------------------------------------------
# 0. The premise: iron rule 6's gate cannot see this class.
# ---------------------------------------------------------------------------
print("0. premise")

_rc = open(os.path.join(REPO, ".luacheckrc"), encoding="utf-8").read()
ok("luacheck is still restricted to the 1xx family",
   'only = { "1" }' in _rc or "only = { '1' }" in _rc,
   ".luacheckrc no longer says only={\"1\"}.  If the full warning set is on, "
   "luacheck reports some of this class itself -- re-read this file's premise "
   "before extending the allowlist.")

# ---------------------------------------------------------------------------
# 1 + 2. The ratchet, and the denominators that make its zero meaningful.
# ---------------------------------------------------------------------------
print("\n1. ratchet over bots/")

FINDINGS, STATS = C.census(C.all_lua_files())
GROUPED = C.group(FINDINGS)

ok("the scan reached the tree",
   STATS["files"] >= 250 and STATS["declarations"] >= 1500,
   "scanned %d files against %d declarations -- far below the 275/1672 this "
   "was written on; a collapsed denominator makes every count below "
   "meaningless" % (STATS["files"], STATS["declarations"]))
ok("the scan resolved most of the calls it saw",
   STATS["resolved_calls"] >= 20000
   and STATS["resolved_calls"] <= STATS["dotted_calls"],
   "resolved %d of %d dotted calls (was 25194 of 28364)"
   % (STATS["resolved_calls"], STATS["dotted_calls"]))

# The denominator that did not exist before 2026-09-03, and whose absence is
# the whole reason this file once asserted an empty OVER half over a tree that
# had a member.  Declarations in the 24 transpiled modules are written
# `____exports.Foo`; callers write `Alias.Foo`.  Those never matched, the call
# fell out of an uncounted `continue`, and the printed denominators looked
# healthy the whole time.  Assert the crossing itself, not just the total: a
# resolver that stops crossing the boundary goes red here instead of going
# quiet everywhere.
ok("the scan still crosses module boundaries",
   STATS["alias_resolved"] >= 500 and STATS["exports"] >= 200,
   "resolved %d alias-qualified call(s) against %d export(s) in %d module(s) "
   "-- was 665/256/24.  A collapse here reads as 'no findings' downstream; it "
   "is the blind spot returning, not the tree getting cleaner"
   % (STATS["alias_resolved"], STATS["exports"], STATS["modules"]))
ok("every alias call that reached a declaration was parsed",
   STATS["alias_resolved"] == STATS["alias_calls"],
   "%d alias call(s) resolved to a declaration but only %d parsed"
   % (STATS["alias_calls"], STATS["alias_resolved"]))

# JUDGED means one of two different things, and the tool keeps them apart:
# ALLOWLIST = the call is fine, ROUTED = the call is broken and owned elsewhere.
_judged = dict(C.ALLOWLIST)
_judged.update(C.ROUTED)

_overlap = sorted(set(C.ALLOWLIST) & set(C.ROUTED))
ok("no row is both benign and routed",
   not _overlap,
   "a key appears in ALLOWLIST and ROUTED; those words contradict each "
   "other:\n        " + "\n        ".join(str(k) for k in _overlap))

_new = sorted(k for k in GROUPED if k not in _judged)
ok("no unjudged mismatch",
   not _new,
   "new arity mismatch(es), each needs a verdict in the tool's ALLOWLIST "
   "(benign) or ROUTED (broken, owned elsewhere) before it can ride:\n        "
   + "\n        ".join("%s  %s  %s passed %d declares %d" % k for k in _new))

_gone = sorted(k for k in _judged if k not in GROUPED)
ok("no judged row without a finding",
   not _gone,
   "these rows no longer match anything -- if the call was fixed, DELETE the "
   "row in the same commit (both lists may only shrink):\n        "
   + "\n        ".join("%s  %s  %s passed %d declares %d" % k for k in _gone))

_count_drift = sorted(
    "%s %s %s: %d now, %d judged" % (k[0], k[1], k[2], GROUPED[k],
                                     _judged[k][0])
    for k in GROUPED if k in _judged and GROUPED[k] != _judged[k][0])
ok("no row grew a new instance",
   not _count_drift,
   "a judged row changed count; a NEW call site of an already-judged shape "
   "still needs judging:\n        " + "\n        ".join(_count_drift))

ok("every judged row carries a verdict word",
   all(any(v[1].startswith(w) for w in
           ("DEFAULTED", "UNREAD", "BRANCHED", "VENDORED", "COSMETIC", "TEETH"))
       for v in _judged.values()),
   "a row's reason does not begin with one of the six verdicts the tool "
   "header defines")

# ---------------------------------------------------------------------------
# 3. Reverse assertions: what a mismatch is, and is not.
# ---------------------------------------------------------------------------
print("\n2. reverse assertions (the tool's own selfcheck battery)")
ok("the synthetic battery passes", C.selfcheck() == 0)

# ---------------------------------------------------------------------------
# 4. The one row with teeth, pinned.
# ---------------------------------------------------------------------------
print("\n3. the OVER half, swept (GH #189)")

# The row that had teeth was hero_bristleback:620 -- an 8.0 handed to a helper
# with a hardcoded 5-second window.  It was swept together with the other seven
# OVER sites (hero group, 2026-08-25); every one passed a literal constant, so
# every removal is byte-for-byte the same behaviour.
#
# !! This section used to assert "the OVER half is still empty", and that
# assertion was TRUE OF THE TOOL rather than of the tree.  The sweep cleared
# every OVER the resolver could see, and the resolver could not see across a
# transpiled-module boundary at all; the tree's only remaining OVER member sat
# at exactly such a call site (hero_selection:1040) for the whole time the
# assertion was green.  What is defensible is the narrower claim the sweep
# actually earned -- no OVER member is behaviour-bearing -- so that is what is
# asserted now.  An OVER can never crash, which is what makes COSMETIC an
# honest verdict for the survivor and TEETH the only word that must not appear.
ok("no behaviour-bearing row is being tolerated as benign",
   not [k for k, v in C.ALLOWLIST.items() if v[1].startswith("TEETH")],
   "a TEETH row is in ALLOWLIST: a behaviour-bearing arity mismatch is routed "
   "to its owner (ROUTED, with an issue) and fixed, not judged benign and kept")

ok("every routed row is behaviour-bearing and carries its issue",
   all(v[1].startswith("TEETH") and "GH #" in v[1] for v in C.ROUTED.values()),
   "ROUTED is for real defects handed to an owner; every row must be TEETH "
   "and must name the issue that carries it, or it is untracked:\n        "
   + "\n        ".join("%s  %s  %s" % (k[0], k[1], v[1])
                       for k, v in C.ROUTED.items()
                       if not (v[1].startswith("TEETH") and "GH #" in v[1])))

_over_teeth = [k for k, v in list(C.ALLOWLIST.items()) + list(C.ROUTED.items())
               if k[2] == "OVER" and v[1].startswith("TEETH")]
ok("no OVER row claims teeth",
   not _over_teeth,
   "an OVER row is marked TEETH.  Lua drops the extra argument, so an OVER "
   "cannot change behaviour; if it looks behaviour-bearing, the declaration "
   "grew a parameter and the row needs re-judging, not re-labelling:\n        "
   + "\n        ".join("%s  %s" % (k[0], k[1]) for k in _over_teeth))

# The survivor, pinned by the thing that makes it harmless.  If
# CMLaneAssignment ever declares a second parameter, the dropped flag starts
# being read and COSMETIC stops being true.
_cm = open(os.path.join(REPO, "bots", "FunLib", "captain_mode.lua"),
           encoding="utf-8").read()
ok("CMLaneAssignment still declares exactly one parameter",
   "function ____exports.CMLaneAssignment(roleAssign)" in _cm,
   "CMLaneAssignment's signature changed.  hero_selection:1040 passes it two "
   "arguments; while it declares one, the second is dropped and the row is "
   "COSMETIC -- if it now declares two, `userSwitchedRole` just became live "
   "and the row must be re-judged")

_hs = open(os.path.join(REPO, "bots", "hero_selection.lua"),
           encoding="utf-8").read()
ok("userSwitchedRole still has exactly one reader",
   _hs.count("userSwitchedRole") == 3,
   "the write-only flag grew or lost a mention (expected 3: the `local`, the "
   "one `= true`, and the argument Lua drops).  A new reader means the "
   "feature was implemented and this row should be gone")

_jmz = open(os.path.join(REPO, "bots", "FunLib", "jmz_func.lua"),
            encoding="utf-8").read()
ok("J.GetTotalEstimatedDamageToTarget still hardcodes its window",
   "GetEstimatedDamageToTarget(true, target, 5, DAMAGE_TYPE_ALL)" in _jmz,
   "the shared helper stopped hardcoding 5 seconds.  If it now takes a "
   "duration, the three call sites this sweep shortened are the ones that "
   "wanted one -- re-read hero_bristleback:620's comment before extending it")
ok("J.GetTotalEstimatedDamageToTarget still declares two parameters",
   "function J.GetTotalEstimatedDamageToTarget(nUnits, target)" in _jmz,
   "the helper's signature changed; the swept call sites were shortened "
   "against exactly this declaration")

_bristle = open(os.path.join(REPO, "bots", "BotLib", "hero_bristleback.lua"),
                encoding="utf-8").read()
ok("hero_bristleback's burst check calls the helper with two arguments",
   "J.GetTotalEstimatedDamageToTarget(nEnemyHeroes, bot)" in _bristle
   and "J.GetTotalEstimatedDamageToTarget(nEnemyHeroes, bot, " not in _bristle,
   "the 8.0 is back at hero_bristleback:620.  Lua drops it, so the check "
   "still runs on 5 seconds while reading as 8 -- see GH #189")
ok("the dropped window is recorded where the reader will look",
   "GH #189" in _bristle,
   "the call site lost the comment explaining why it does NOT pass a "
   "duration; without it the next reader re-adds the 8.0")

_mars = open(os.path.join(REPO, "bots", "BotLib", "hero_mars.lua"),
             encoding="utf-8").read()
ok("the sister that DOES take a duration is still there",
   "function X.GetTotalEstimatedDamageToTarget(hUnitList, hTarget, fDuration)"
   in _mars,
   "hero_mars.lua's duration-taking copy is gone.  It is the reason the "
   "three-argument shape reads as correct in this repo, and therefore the "
   "reason the swept sites are worth pinning")

_iglp = ("J.IsGoingOnSomeone", "J.IsInLaningPhase")
_still_over = sorted(
    "%s:%d %s" % (f["file"], f["line"], f["name"])
    for f in FINDINGS if f["kind"] == "OVER" and f["name"] in _iglp)
ok("no caller passes a radius to a helper that has none",
   not _still_over,
   "J.IsGoingOnSomeone reads GetActiveMode() and J.IsInLaningPhase declares "
   "no parameters; an argument handed to either is read by a human and "
   "discarded by Lua:\n        " + "\n        ".join(_still_over))

# ---------------------------------------------------------------------------
# 5. The repaired call site.
# ---------------------------------------------------------------------------
print("\n4. the repair this census was born from")

_aiug = open(os.path.join(REPO, "bots", "ability_item_usage_generic.lua"),
             encoding="utf-8").read()
ok("the lf_salve regen cast passes all three arguments",
   "X.SetUseItem( hRegen, bot, 'unit' )" in _aiug,
   "aiug's lf_salve branch went back to a short X.SetUseItem call; that is a "
   "no-op cast AND a suppressed item loop -- see "
   "tests/test_lf_salve_cast_type.lua")
ok("no X.SetUseItem row is in the allowlist",
   not any(k[1] == "X.SetUseItem" for k in C.ALLOWLIST),
   "X.SetUseItem is back in the allowlist; it must be fixed, not judged")

print()
if FAIL:
    print("FAILED: %d" % len(FAIL))
    sys.exit(1)
print("all checks pass")

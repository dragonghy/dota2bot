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

_new = sorted(k for k in GROUPED if k not in C.ALLOWLIST)
ok("no unjudged mismatch",
   not _new,
   "new arity mismatch(es), each needs a verdict in the tool's ALLOWLIST "
   "before it can ride:\n        "
   + "\n        ".join("%s  %s  %s passed %d declares %d" % k for k in _new))

_gone = sorted(k for k in C.ALLOWLIST if k not in GROUPED)
ok("no allowlist row without a finding",
   not _gone,
   "these allowlist rows no longer match anything -- if the call was fixed, "
   "DELETE the row in the same commit (the list may only shrink):\n        "
   + "\n        ".join("%s  %s  %s passed %d declares %d" % k for k in _gone))

_count_drift = sorted(
    "%s %s %s: %d now, %d allowlisted" % (k[0], k[1], k[2], GROUPED[k],
                                          C.ALLOWLIST[k][0])
    for k in GROUPED if k in C.ALLOWLIST and GROUPED[k] != C.ALLOWLIST[k][0])
ok("no row grew a new instance",
   not _count_drift,
   "an allowlisted row changed count; a NEW call site of an already-judged "
   "shape still needs judging:\n        " + "\n        ".join(_count_drift))

ok("every allowlist row carries a verdict word",
   all(any(v[1].startswith(w) for w in
           ("DEFAULTED", "UNREAD", "BRANCHED", "VENDORED", "COSMETIC", "TEETH"))
       for v in C.ALLOWLIST.values()),
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
print("\n3. the row with teeth")

_teeth = [k for k, v in C.ALLOWLIST.items() if v[1].startswith("TEETH")]
ok("exactly one behaviour-bearing row",
   len(_teeth) == 1,
   "the TEETH set changed (%d rows); if a mismatch was promoted or demoted, "
   "say so in a report" % len(_teeth))

_jmz = open(os.path.join(REPO, "bots", "FunLib", "jmz_func.lua"),
            encoding="utf-8").read()
ok("J.GetTotalEstimatedDamageToTarget still hardcodes its window",
   "GetEstimatedDamageToTarget(true, target, 5, DAMAGE_TYPE_ALL)" in _jmz,
   "the shared helper stopped hardcoding 5 seconds -- if it now takes a "
   "duration, hero_bristleback:620's 8.0 became correct and the TEETH row "
   "must be deleted")

_mars = open(os.path.join(REPO, "bots", "BotLib", "hero_mars.lua"),
             encoding="utf-8").read()
ok("the sister that DOES take a duration is still there",
   "function X.GetTotalEstimatedDamageToTarget(hUnitList, hTarget, fDuration)"
   in _mars,
   "hero_mars.lua's duration-taking copy is gone; it is the reason the "
   "three-argument call reads as correct, and the TEETH row's argument cites it")

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

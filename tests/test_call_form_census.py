#!/usr/bin/env python3
"""Ratchet + reverse assertions for the call-FORM census.

The class: a dotted call whose name resolves to nothing, and a call whose form
(dot vs colon) disagrees with its declaration.  Neither is visible to iron rule
6 -- `.luacheckrc` says `only = {"1"}`, and a field access is not a global
access -- and neither is visible to the arity census either: its first act is
`if name not in decls: continue`, so a name with no declaration at all is
dropped before any comparison happens.

WHY IT IS WORSE HERE THAN IN ORDINARY LUA.  `AGENTS.md`: the engine's error
handler is broken (`error in error handling` masks the Lua text) and `print()`
never reaches the console.  A nil call inside a Think therefore does not
announce itself -- the bot silently loses that Think and the only symptom is a
decision that stops halfway.  It cannot be debugged at runtime, so it has to be
caught at the desk.

Four layers, same shape as tests/test_call_arity_census.py:

  LAYER 0 -- the premise, in two halves.  `.luacheckrc` still restricts
  luacheck to the 1xx family, so this tool is not duplicating the gate; and
  tests/test_no_undefined_jmz_refs.lua (GH #48) -- which DOES test this class
  for `J.<name>` and has run every round since -- still stops at the first dot,
  which is exactly why it walked past mode_farm_generic:710.  If either premise
  changes, this file says so instead of quietly overlapping another check.

  LAYER 1 -- the ratchet.  `bots/` carries exactly these findings today and
  every one is judged in the tool's ALLOWLIST with a reason.  A new one is red
  the day it lands; fixing an old one means deleting its row.  Keyed by
  (file, name, shape), never by line number -- charter 0LN2.

  LAYER 2 -- the denominators.  "0 findings" and "the scanner reached nothing"
  look identical on paper (charter 0IMPL judgement two), so the scale of the
  scan is asserted alongside the counts.

  LAYER 3 -- the reverse assertions.  The dangerous direction for THIS tool is
  a false positive: a call that was always fine gets "repaired" and takes
  behaviour with it.  Most of the synthetic battery therefore pins what is NOT
  a finding.

Section 4 pins the repair this census was born from (hero_queenofpain:503, a
dot where the same file uses a colon 9 times) and the one live NOWHERE row
that is deliberately NOT repaired here because the file belongs to another
group (mode_farm_generic:710, GH #193).

Run: python3 tests/test_call_form_census.py   (or tests/run_py_tests.sh)
"""

import importlib.util
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "call_form_census.py")

_spec = importlib.util.spec_from_file_location("call_form_census", TOOL)
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
# 0. The premise.
# ---------------------------------------------------------------------------
print("0. premise")

_rc = open(os.path.join(REPO, ".luacheckrc"), encoding="utf-8").read()
ok("luacheck is still restricted to the 1xx family",
   'only = { "1" }' in _rc or "only = { '1' }" in _rc,
   ".luacheckrc no longer says only={\"1\"}; re-read this file's premise "
   "before extending the allowlist")

# The SECOND half of the premise, and the more surprising one.  A test for this
# exact class already exists and has run every round since GH #48:
# tests/test_no_undefined_jmz_refs.lua, "every `J.<name>` referenced under
# bots/ must be defined under bots/" -- its header even cites the same masked
# engine error handler.  It walked straight past mode_farm_generic:710 for one
# reason: its patterns capture ONE component after the dot, so
# `J.Site.IsCampDangerous` is read as a reference to `J.Site` (which is defined,
# by `J.Site = require(...)`) and the name `IsCampDangerous` is never asked
# about.  Every J sub-table -- J.Site, J.Skill, J.Item, J.Role, J.Utils,
# J.Chat -- is behind that blind spot.
#
# So this assertion is not decoration: if someone deepens those patterns, this
# tool's NILCALL half starts overlapping a check the Lua suite already runs,
# and whoever does that should be told rather than left to duplicate it.
_jmz_test = open(os.path.join(REPO, "tests", "test_no_undefined_jmz_refs.lua"),
                 encoding="utf-8").read()
_JMZ_REF_LINE = "for name in line:gmatch('J%.([%w_]+)') do"
_jmz_follows_subtables = re.search(r"J%\.[^\n']*%\.", _jmz_test) is not None
ok("the GH #48 scan still stops at the first dot",
   _JMZ_REF_LINE in _jmz_test and not _jmz_follows_subtables,
   "tests/test_no_undefined_jmz_refs.lua changed its patterns.  If it now "
   "follows sub-table paths (J.Site.X), it covers part of this tool's NILCALL "
   "half -- reconcile the two rather than running both blind, and re-read the "
   "premise recorded here.")

# ---------------------------------------------------------------------------
# 1 + 2. The ratchet and its denominators.
# ---------------------------------------------------------------------------
print("\n1. ratchet over bots/")

_files = C.all_lua_files()
FINDINGS, STATS = C.census(_files, _files)
GROUPED = C.group(FINDINGS)

ok("the scan reached the tree",
   STATS["files"] >= 250 and STATS["names"] >= 2000,
   "scanned %d files and collected %d declared names -- far below the "
   "275/2530 this was written on; a collapsed denominator makes every count "
   "below meaningless" % (STATS["files"], STATS["names"]))
ok("both call forms were reached",
   STATS["dotted_calls"] >= 20000 and STATS["colon_calls"] >= 15000,
   "%d dotted and %d colon calls (was 28364 / 20774).  A collapsed colon "
   "count would silently retire the SELFLESS and BOUND halves"
   % (STATS["dotted_calls"], STATS["colon_calls"]))

_new = sorted(k for k in GROUPED if k not in C.ALLOWLIST)
ok("no unjudged call-form finding",
   not _new,
   "each of these needs a verdict in the tool's ALLOWLIST before it can "
   "ride:\n        " + "\n        ".join("%s  %s  %s" % k for k in _new))

_gone = sorted(k for k in C.ALLOWLIST if k not in GROUPED)
ok("no allowlist row without a finding",
   not _gone,
   "these rows no longer match anything -- if the call was repaired, DELETE "
   "the row in the same commit (the list may only shrink):\n        "
   + "\n        ".join("%s  %s  %s" % k for k in _gone))

_drift = sorted("%s %s %s: %d now, %d allowlisted"
                % (k[0], k[1], k[2], GROUPED[k], C.ALLOWLIST[k][0])
                for k in GROUPED
                if k in C.ALLOWLIST and GROUPED[k] != C.ALLOWLIST[k][0])
ok("no row grew a new instance",
   not _drift,
   "a NEW call site of an already-judged shape still needs judging:\n        "
   + "\n        ".join(_drift))

ok("every allowlist row carries a verdict word",
   all(any(v[1].startswith(w) for w in
           ("NOWHERE", "HANDLE", "DEADFILE", "DYNAMIC", "SELFUNREAD",
            "VENDORED"))
       for v in C.ALLOWLIST.values()),
   "a row's reason does not begin with one of the six verdicts the tool "
   "header defines")

# ---------------------------------------------------------------------------
# 3. Reverse assertions.
# ---------------------------------------------------------------------------
print("\n2. reverse assertions (the tool's own selfcheck battery)")
ok("the synthetic battery passes", C.selfcheck() == 0)

# The generous resolver is the reason this tool does not produce false
# positives, and it is also the reason it under-reports.  Pin both halves so
# neither can be quietly changed: `J.Skill.GetTalentList` must resolve (it is
# declared on a different table), and a name that exists nowhere must not.
_names, _colon, _dot = C.collect(_files)
ok("a sub-table path resolves on its last component",
   "GetTalentList" in _names and "GetRoleItemsBuyList" in _names,
   "the declaration collector stopped seeing the transpiled "
   "`____exports.name = function` form; every J.Skill.* / J.Item.* call in "
   "the tree would become a false NILCALL")
ok("the collector sees colon declarations too",
   "IsDebug" in _colon and "Debug" in _colon["IsDebug"],
   "COLON_DECL_RE stopped matching `function Debug:IsDebug()`; the SELFLESS "
   "shape would collapse into NILCALL")
ok("the transpiler's explicit-self declarations are recorded as such",
   any(first == "self" for _, first in _dot.get("GetUUID", ())),
   "`function Request.GetUUID(self, callback)` is no longer read with its "
   "first parameter; ts_libs' correct `Request:GetUUID(cb)` call sites would "
   "become false BOUND findings")

# ---------------------------------------------------------------------------
# 4. The repair, and the one live row deliberately left alone.
# ---------------------------------------------------------------------------
print("\n3. the repair this census was born from (GH #192)")

_qop = open(os.path.join(REPO, "bots", "BotLib", "hero_queenofpain.lua"),
            encoding="utf-8").read()
# Read the CODE, not the prose.  The repair's own comment quotes the defective
# form verbatim, so a raw substring test here would fail on the explanation of
# the thing it is checking -- the same trap GH #162 recorded for
# test_gate_claim_consistency ("ungated" contains "gated").
_qop_code = C.strip_comments(_qop)
ok("queenofpain's Scream-of-Pain castability check uses a colon",
   "abilityE:IsFullyCastable()" in _qop_code
   and "abilityE.IsFullyCastable(" not in _qop_code,
   "the dot is back at hero_queenofpain:503.  A dot reaches an engine method "
   "without its receiver, and the engine masks whatever it raises, so the "
   "conjunct cannot answer the question it asks -- see GH #192")
ok("the reason is recorded where the reader will look",
   "GH #192" in _qop,
   "the call site lost the comment explaining why it is a colon; without it "
   "the next reader cannot tell the repair from a stylistic choice")
ok("the discriminator the repair rests on is still true",
   _qop_code.count("abilityE:") >= 8,
   "the file used the colon form 9 times when the repair was made (measured, "
   "not estimated).  That majority IS the argument that the dot was a typo "
   "rather than a deliberate call form; if it erodes, the argument does too")

print("\n4. the live NOWHERE row, deliberately not repaired here")

_farm = open(os.path.join(REPO, "bots", "mode_farm_generic.lua"),
             encoding="utf-8").read()
_camp_key = ("bots/mode_farm_generic.lua", "J.Site.IsCampDangerous", "NILCALL")
_camp_present = "J.Site.IsCampDangerous(" in _farm
ok("the camp-danger call and its allowlist row agree",
   _camp_present == (_camp_key in C.ALLOWLIST),
   "mode_farm_generic's `J.Site.IsCampDangerous(` call and its ALLOWLIST row "
   "must land or leave together.  If the strategy group repaired it (by "
   "writing the predicate or dropping the conjunct), delete the row in the "
   "same commit; if the row was deleted while the call stands, the ratchet "
   "just stopped watching a live nil call.  See GH #193.")
if _camp_present:
    _site = open(os.path.join(REPO, "bots", "FunLib", "aba_site.lua"),
                 encoding="utf-8").read()
    ok("aba_site still declares no IsCampDangerous",
       "IsCampDangerous" not in _site,
       "aba_site.lua now declares IsCampDangerous -- the call at "
       "mode_farm_generic:710 resolves and its allowlist row must go")
    ok("aba_site is still a plain export table with no metatable",
       "setmetatable" not in _site and "__index" not in _site,
       "aba_site.lua grew a metatable; `J.Site.<missing>` could now resolve "
       "through __index, and the NOWHERE verdict's argument no longer holds")

print()
if FAIL:
    print("FAILED: %d" % len(FAIL))
    sys.exit(1)
print("all checks pass")

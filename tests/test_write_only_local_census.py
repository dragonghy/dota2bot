#!/usr/bin/env python3
"""Ratchet + reverse assertions for the write-only-local census.

The class exists because of one line in this repo's own gate.  `.luacheckrc`
says `only = { "1" }`: only the 1xx global-access warnings are enforced.
luacheck's unused-variable family is 2xx, so a local that is ASSIGNED and NEVER
READ passes `luacheck bots game` silently, in every file, forever -- and iron
rule 6 is exactly that command.  Section 0 asserts that premise rather than
assuming it: the day someone turns 2xx on, this tool is redundant and the test
says so instead of quietly duplicating luacheck.

Three layers:

  LAYER 0 -- the premise (section 0).  `only = {"1"}` still in `.luacheckrc`.

  LAYER 1 -- the ratchet (section 1).  The nine strategy decision files carry
  exactly THIRTEEN single-name write-only locals today, and each is judged in
  the tool's ALLOWLIST with a reason.  A new one goes red the day it lands;
  sweeping an old one means deleting its row, so the list can only shrink.
  Nothing here is "fixed by deleting it" -- see the tool's header, and note
  that three of the thirteen are `require(...)` whose LOAD SIDE EFFECT is
  load-bearing.  "Write-only" does not mean "dead".

  LAYER 2 -- the reverse assertions (section 2).  The scan is sound by
  construction (a name with zero reads in a file cannot be read by any scope in
  that file), which makes it worth almost nothing unless "read" is defined
  correctly.  Each synthetic case below pins one half of that definition.  The
  dangerous direction is a FALSE POSITIVE: someone reads "write-only", deletes
  the line, and takes behaviour with it.

Section 3 pins the one finding that is not cosmetic: `nLongEnemyTowers` in
`mode_retreat_generic`, the dropped rung 1 of the graded tower-fear ladder whose
sibling copy in `mode_farm_generic` still reads it.  It is pinned rather than
restored -- the rung's own domain is empty on the fixture archive (closest
approach in its band is 1310 u against a 1200 u ring), so restoring it buys
zero frames.  If a later round restores or sweeps it, this section is what
comes and asks for the argument.

Run: python3 tests/test_write_only_local_census.py   (or tests/run_py_tests.sh)
"""

import importlib.util
import os
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "write_only_local_census.py")

_spec = importlib.util.spec_from_file_location("write_only_local_census", TOOL)
W = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(W)

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
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as fh:
        fh.write(lua)
        path = fh.name
    try:
        return W.scan_file(path, "<synthetic>", {})
    finally:
        W._STRIP_CACHE.pop(path, None)
        os.unlink(path)


def names(findings):
    return sorted(f["name"] for f in findings)


# ----------------------------------------------------------------------------
# 0. the premise this tool rests on
# ----------------------------------------------------------------------------
print("\n0. premise -- the repo gate cannot see this class")

with open(os.path.join(REPO, ".luacheckrc"), "r", encoding="utf-8") as fh:
    luacheckrc = fh.read()
ok("`.luacheckrc` still enforces only the 1xx family (2xx unused is OFF)",
   'only = { "1" }' in luacheckrc,
   "if this changed, luacheck reports unused locals itself and this tool is "
   "redundant -- retire it rather than run two censuses of the same thing")


# ----------------------------------------------------------------------------
# 1. the ratchet
# ----------------------------------------------------------------------------
print("\n1. ratchet -- what the nine decision files read today")

findings = []
stats = {}
for rel in W.STRATEGY_FILES:
    findings.extend(W.scan_file(os.path.join(REPO, rel), rel, stats))

single = sorted((f["file"], f["name"]) for f in findings if not f["multi"])
eq("every single-name write-only local is judged in the tool's ALLOWLIST",
   [k for k in single if k not in W.ALLOWLIST], [])
eq("every ALLOWLIST row still names a real finding (no stale rows)",
   sorted(k for k in W.ALLOWLIST if k not in single), [])
eq("the count is thirteen", len(single), 13)

# `0IMPL` judgement two: a zero -- or any count -- and a scan that reached
# nothing look identical on paper unless the denominator is printed too.
total_locals = sum(s["locals"] for s in stats.values())
eq("the scan reached all nine files", len(stats), 9)
ok("the scan actually found locals to judge (floor, not an exact count)",
   total_locals >= 1200, "locals %r" % total_locals)

ok("three of the thirteen are require() whose LOAD SIDE EFFECT is the point",
   sum(1 for k in single if W.ALLOWLIST[k] == "require side effect") == 3,
   "write-only is not dead code; do not sweep these")

_stdout = sys.stdout
sys.stdout = open(os.devnull, "w")          # the census listing is not the test
try:
    _exit = W.main([])
finally:
    sys.stdout.close()
    sys.stdout = _stdout
eq("the tool exits clean while every finding is allowlisted", _exit, 0)


# ----------------------------------------------------------------------------
# 2. reverse assertions -- what "read" means
# ----------------------------------------------------------------------------
print("\n2. reverse -- the definition of a read")

eq("[reverse] a local that is read is not reported",
   names(scan_source("local a = 1\nreturn a\n")), [])
eq("a local that is only assigned is reported",
   names(scan_source("local a = 1\na = 2\n")), ["a"])

# `a.x = 1` and `a[i] = 2` READ `a` -- they index it.  Calling those write-only
# is the false positive that deletes a live table.
eq("[reverse] a field store reads the table",
   names(scan_source("local a = {}\na.x = 1\n")), [])
eq("[reverse] an index store reads the table",
   names(scan_source("local a = {}\na[1] = 2\n")), [])
eq("[reverse] a method call reads the receiver",
   names(scan_source("local a = f()\na:Go()\n")), [])

# ...but a FIELD or METHOD of the same name is not this local.
eq("a name that only ever appears as someone else's field is still write-only",
   names(scan_source("local a = 1\nlocal t = {}\nt.a = 2\nreturn t:a()\n")),
   ["a"])

eq("[reverse] `a == 1` is a read", names(scan_source("local a = f()\nif a == 1 then end\n")), [])

# A multi-target assignment is a write to EVERY name on the left.  Without the
# comma alternation in ASSIGN_RE, `zz` below reads as live and the finding
# vanishes -- an under-report, but the one that hides the class this file is
# about.
eq("every name left of a multi-target `=` is a write",
   names(scan_source("local zz = 1\nlocal a = 2\nzz, a = 3, 4\nreturn a\n")), ["zz"])

# `;`-separated statements are split before the assignment test; without the
# split, the second statement's target is never seen as a target.  This shape
# is not hypothetical: these files use trailing `;` throughout.
eq("a `;`-separated assignment still counts as a write",
   names(scan_source("local zz = 1\nlocal a = 2\nf(a); zz = 3\nreturn a\n")), ["zz"])

# [contract], not a mutation target.  ASSIGN_RE's `(?<![=~<>])` lookbehind and
# DECL_RE's `(?!\s+function\b)` are both DEFENSIVE on today's scanner: the
# comparison cases below and the `local function` case pass with either guard
# removed, because a comparison never starts a Lua statement and a function's
# own name is followed by `(` rather than `=`.  They are kept, and labelled,
# because the guards are what let the next person widen `statements()` or
# DECL_RE without silently changing what "write" means.  Pretending they are
# load-bearing would be the same lie as omitting a real case (`0IMPL` iv).
eq("[contract] `a ~= 1` is a read", names(scan_source("local a = f()\nif a ~= 1 then end\n")), [])
eq("[contract] `a <= 1` is a read", names(scan_source("local a = f()\nif a <= 1 then end\n")), [])

# Strings and comments are not code.  Without stripping, a name mentioned in a
# comment reads as live and the finding silently disappears.
eq("a name mentioned only in a comment is still write-only",
   names(scan_source("local zzq = 1\n-- zzq is great\n")), ["zzq"])
eq("a name mentioned only inside a string is still write-only",
   names(scan_source("local zzq = 1\nlocal s = 'zzq'\nreturn s\n")), ["zzq"])

# `local function f` is a different question (it may be exported via a table),
# so it is skipped rather than guessed at.  [contract] -- see the note above.
eq("[contract] `local function` is skipped",
   names(scan_source("local function f()\n\treturn 1\nend\n")), [])

# Multi-name declarations are tagged, not ratcheted: `local a, b = f()` to
# discard the second value is idiomatic.
multi = scan_source("local a, b = f()\nreturn a\n")
eq("a discarded second return is reported", names(multi), ["b"])
eq("...and tagged multi", [f["multi"] for f in multi], [True])

# Sound-by-construction has a price, and it is under-reporting.  State it.
eq("[reverse] a name read in ONE scope is never reported, even if write-only "
   "in another (the safe direction)",
   names(scan_source(
       "local function g()\n\tlocal n = 1\n\treturn n\nend\n"
       "local function h()\n\tlocal n = 2\nend\n")), [])


# ----------------------------------------------------------------------------
# 3. the one finding that is not cosmetic
# ----------------------------------------------------------------------------
print("\n3. the dropped rung")

rung = [f for f in findings
        if f["file"] == "bots/mode_retreat_generic.lua"
        and f["name"] == "nLongEnemyTowers"]
eq("mode_retreat_generic still computes nLongEnemyTowers and never reads it",
   len(rung), 1)
if rung:
    eq("...assigned twice (the plain ring and the mid-lane override)",
       len(rung[0]["assign_lines"]), 2)
    eq("...costing two GetNearbyTowers calls for nothing",
       rung[0]["engine_calls_on_assign"], 2)
    ok("...while the verbatim sibling copy in mode_farm_generic still reads it",
       any(r.startswith("bots/mode_farm_generic.lua:")
           for r in W.other_file_readers(
               "nLongEnemyTowers",
               [(os.path.join(REPO, r), r) for r in W.STRATEGY_FILES
                if r != "bots/mode_retreat_generic.lua"])),
       "this cross-file read is what makes it a dropped RUNG rather than "
       "scratch -- and it is the ONLY one of the thirteen where the sibling "
       "read sits in a copy of the same block")

# The sibling ladder is what the retreat copy lost a rung of.  Pinned by shape,
# not by line number (`0PATH`: line numbers drift, ids and text do not).
with open(os.path.join(REPO, "bots", "mode_farm_generic.lua"), "r",
          encoding="utf-8") as fh:
    farm = fh.read()
ok("the sibling ladder still grades the ring by maturity (widest ring, "
   "youngest band)",
   "nLongEnemyTowers = bot:GetNearbyTowers(1200, true)" in farm
   and "nLongEnemyTowers[1] ~= nil" in farm,
   "if this rung moved or went away, the retreat copy is no longer missing "
   "anything and this whole finding needs re-arguing")


# ----------------------------------------------------------------------------
# 4. why the rung is pinned rather than restored
# ----------------------------------------------------------------------------
print("\n4. the rung's domain")

_dspec = importlib.util.spec_from_file_location(
    "tower_band_domain", os.path.join(REPO, "tools", "agent", "tower_band_domain.py"))
D = importlib.util.module_from_spec(_dspec)
_dspec.loader.exec_module(D)

r = D.band_report(max_level=2, max_time=120.0)

# `0GEO`, reproduced: the map is a measured constant of this engine build, not
# a model.  If either number moves, every distance below is re-derived, not
# re-quoted.
eq("22 towers, identical across every carrier fixture", r["towers"], 22)
eq("...carried by 61 fixtures", r["carrier_fixtures"], 61)

# The separation, and both of the "is this just a thin corpus?" answers.
ok("the archive does contain tower-adjacent frames (so a zero is not sampling)",
   r["all_min"] <= 200, "closest any frame %r" % r["all_min"])
ok("the rung's band is populated (so a zero is not an empty denominator)",
   r["band_frames"] >= 60, "band frames %r" % r["band_frames"])
eq("the band's closest approach to an enemy tower", r["band_min"], 1310)
ok("...which is OUTSIDE the 1200 u ring the dropped rung would use",
   r["band_min"] > 1200, "%r vs 1200" % r["band_min"])
ok("...and far outside the 898 u ring this copy actually has",
   r["band_min"] > 898, "%r vs 898" % r["band_min"])
eq("median approach in the band (a creep-meet point, as the geometry predicts)",
   r["band_median"], 2086)

# The shipped comment quotes these numbers.  Keep the quote and the measurement
# in the same test, or the comment becomes the next false assertion (GH #178 was
# exactly that failure).
with open(os.path.join(REPO, "bots", "mode_retreat_generic.lua"), "r",
          encoding="utf-8") as fh:
    retreat = fh.read()
ok("the shipped comment quotes the measured number, not a remembered one",
   "1310 u" in retreat and "1200 u ring" in retreat,
   "comment and tool must move together")
ok("the shipped comment no longer claims the calibrated clause catches the "
   "released frames (GH #178)",
   "What catches the released frames instead is the CALIBRATED clause"
   not in retreat)

print()
if FAIL:
    print("%d FAILED: %s" % (len(FAIL), ", ".join(FAIL)))
    sys.exit(1)
print("write-only-local census: 13 judged, ratchet holds, reverse cases silent")

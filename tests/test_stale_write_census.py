#!/usr/bin/env python3
"""[ratchet] The (C) shape -- a branch's leftover write fired by a sibling's bare read.

THE CLASS, and why it needed an instrument rather than a second fix.  GH #821
(`tpstale`) found one function-scoped local, `tpLoc`, written by one branch of
`X.ConsiderItemDesire["item_tpscroll"]`, left behind when that branch's own
distance test refused to fire, and then TELEPORTED ON by a different branch
whose fire condition is a bare `if tpLoc ~= nil`.  In that configuration every
conjunct of the writing branch is bypassed -- including the two gated vetoes
`tprecov` / `tpdeep`, which guard the ASSIGNMENT while the firing reads
SOMEBODY ELSE'S assignment.

  The reason it escaped every automatic reader we own: `check_armed_wiring.py`
  calls such a gate WIRED (a call site exists and the predicate can be true),
  the inverse-gate census is satisfied (nothing is frozen false), and the
  gate's own unit tests pass.  The defect lives strictly between the two, which
  is also true of `pullcad` -- but from the other direction: there a gate was
  frozen false, here a live gate's ANSWER is overwritten.

WHAT THIS FILE PINS (charter 0NEXT14, outcome (b)).

  1. The census can see `bots/` at all.  Its first draft could not: a
     line-local depth model double-counted `for ... in pairs(...)` whose `do`
     sits on the next line, drifted +97 over one file, and reported 7 functions
     in 9069 lines -- a clean `live=0` that meant nothing.  So the scanner's
     depth must return to 0 at EOF for every shipped Lua file.

  2. The census goes RED when the shape is present.  Not against a synthetic:
     against the REAL shipped file with the `tpstale` clear deleted, which is
     the pre-GH-#821 text of that branch.  A ratchet that cannot be made to
     fail is not measuring anything (evidence discipline 2).

  3. Trunk carries no REACHABLE member of the class (`live == 0`).

  4. The premise that refutes the two residual textual matches is still true in
     source.  Those two (`前往守塔` / `前往推塔` writing `tpLoc`, read bare by
     `保人`) are excluded because the branches are mode-exclusive: all of
     `nMode`, `J.IsDefending` and `J.IsPushing` resolve to the same per-frame
     `bot:GetActiveMode()`, and `tpLoc` is re-initialised every call.  If a
     later edit makes `保人` mode-agnostic, or gives `nMode` a second source,
     the exclusion silently becomes wrong -- so it is asserted, not assumed.

READING 2026-09-14 (`tools/agent/stale_write_census.py`, whole of `bots/`):
  pre-fix tree (`d96fb899^`)  sites=4 cross=4 live=4  -- ALL FOUR reading the
      one bare test in `回复状态`.  GH #821 named two writers (`前往守塔`,
      `前往推塔`); the census adds `飞鞋带线` (5843) and `线上打钱` (5867).
      One clear on the READ side closes all four.
  trunk                       sites=2 cross=2 live=0

LIMIT, stated because the `live=0` rests on it: the criteria are textual and
NARROWING.  A clear performed by a helper rather than a literal `v = nil`, a
fire behind something other than a bare non-nil test, and a write whose own
branch never tries to fire are all invisible here.  `live=0` therefore means
"no member of THIS shape", not "no stale write in bots/".
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AIUG = os.path.join(REPO, "bots", "ability_item_usage_generic.lua")

sys.path.insert(0, os.path.join(REPO, "tools", "agent"))
import stale_write_census as swc  # noqa: E402
import lua_corpus  # noqa: E402

FAIL = []


def ok(name, cond, detail=""):
    if cond:
        print("  ok    %s" % name)
    else:
        print("  FAIL  %s%s" % (name, ("\n        " + detail) if detail else ""))
        FAIL.append(name)


# In-process, ONE pass over the corpus. Running the census as a subprocess per
# section made this file cost 6.6s and the iron rule 6 python gate refused the
# push for blowing its unmeasured-test slack -- a real cost to everyone, paid
# for re-reading 212k lines three times.


# ---------------------------------------------------------------------------
# 1. The scanner can see the corpus (the +97 drift class).
# ---------------------------------------------------------------------------
print("1. block scanner closes every shipped Lua file")

_BOTS = os.path.join(REPO, "bots")
_sites, _unbalanced = swc.scan_paths([_BOTS])
_counts = swc.summary(_sites)

# Through lua_corpus, not an open-coded walk: tests/test_lua_corpus_stability.py
# ratchets that nobody re-derives the corpus listing, and this line was the one
# copy still doing it (found red on trunk 2026-09-14T22:xxZ, one file, this
# desk's own from the 16:26Z round -- GH #624's shape exactly: the red is found
# by the next desk to start work). The listing is also the more correct operand
# here: it excludes the gitignored gate switch, which is not shipped Lua.
_n_lua = len(lua_corpus.bots_lua_files())
ok("bots/ has Lua to walk", _n_lua > 50, "found %d files" % _n_lua)

ok("every file returns to depth 0", not _unbalanced,
   "unbalanced: %r -- the census cannot see past the drift, and its counts "
   "on these files are meaningless rather than zero" % (_unbalanced[:5],))

with open(AIUG, encoding="utf-8") as fh:
    _aiug_lines = fh.read().split("\n")
_fns = len(swc.parse_functions(_aiug_lines)[0])
ok("the Consider* family is actually parsed", _fns > 100,
   "parsed %d functions in ability_item_usage_generic.lua (%d lines); the "
   "first draft saw 7, which is what a silent `live=0` looks like"
   % (_fns, len(_aiug_lines)))

# ---------------------------------------------------------------------------
# 2. Reverse assertion: delete the tpstale clear, the census must go red.
# ---------------------------------------------------------------------------
print("\n2. reverse assertion on the real file (tpstale clear removed)")

CLEAR = ("\t\tif J.ShouldDropUnownedRecoverTp( bRecoverTpIsOurs )\n"
         "\t\tthen\n"
         "\t\t\ttpLoc = nil\n"
         "\t\tend\n")
_src = open(AIUG, encoding="utf-8").read()
ok("the tpstale clear is present verbatim", _src.count(CLEAR) == 1,
   "found %d copies of the clear block; if it was reformatted, re-anchor this "
   "test -- do NOT drop the reverse assertion" % _src.count(CLEAR))

if _src.count(CLEAR) == 1:
    _mut_sites, _mut_depth = swc.scan_text(AIUG, _src.replace(CLEAR, ""))
    _mut = swc.summary(_mut_sites)
    _live = [s for s in _mut_sites if s["cross"] and not s["disjoint"]]
    ok("the mutated copy still parses", _mut_depth == 0,
       "depth=%+d at EOF" % _mut_depth)
    ok("removing the clear resurrects reachable sites", _mut["live"] >= 1,
       "live=%d with the clear deleted -- the ratchet in section 3 cannot go "
       "red, so its 0 is a vacuum\n%s" % (_mut["live"], swc.render(_mut_sites)))
    _reads = set(s["read"] for s in _live)
    ok("they all fire on ONE bare read", len(_reads) == 1,
       "reads=%r; GH #821's finding is that several writers share one "
       "unguarded reader" % (sorted(_reads),))
    ok("the clear covers more writers than GH #821 named", _mut["live"] >= 4,
       "live=%d; the issue named 2 (前往守塔 / 前往推塔) and the census "
       "measured 4 -- if this drops, re-read the branch list" % _mut["live"])

# ---------------------------------------------------------------------------
# 3. The ratchet.
# ---------------------------------------------------------------------------
print("\n3. trunk carries no reachable member of the class")

ok("live == 0 over all of bots/", _counts["live"] == 0,
   "a branch now fires on a local a sibling branch left behind:\n%s"
   % swc.render(_sites))
ok("the residual matches are still exactly the two known ones",
   _counts["sites"] == 2 and _counts["cross"] == 2,
   "sites=%d cross=%d (expected 2/2). A NEW textual match is not itself a "
   "defect, but it has not been argued yet -- read it and either refute it "
   "here or land a fix.\n%s"
   % (_counts["sites"], _counts["cross"], swc.render(_sites)))

# ---------------------------------------------------------------------------
# 4. The premise the two residual matches are refuted with.
# ---------------------------------------------------------------------------
print("\n4. the mode-exclusivity premise is still true in source")

ok("nMode has exactly one source, and it is GetActiveMode",
   len(re.findall(r"^\s*nMode\s*=\s*bot:GetActiveMode\(\)", _src, re.M)) == 1
   and len(re.findall(r"^\s*nMode\s*=(?!=)", _src, re.M)) == 1,
   "nMode is assigned somewhere other than the single "
   "`nMode = bot:GetActiveMode()`; the two residual sites were excluded on "
   "the premise that write and read branches test ONE per-frame value")

_jmz = open(os.path.join(REPO, "bots", "FunLib", "jmz_func.lua"),
            encoding="utf-8").read()
for _pred in ("J.IsDefending", "J.IsPushing"):
    _body = re.search(r"function %s\( bot \)(.*?)\nend" % re.escape(_pred),
                      _jmz, re.S)
    ok("%s still resolves to GetActiveMode" % _pred,
       _body is not None and "bot:GetActiveMode()" in _body.group(1),
       "%s no longer reads the active mode; the mode-disjoint exclusion of "
       "the 保人 reader loses its argument" % _pred)

ok("tpLoc is still re-initialised per call",
   len(re.findall(r"^\s*local tpLoc = nil\s*$", _src, re.M)) == 1,
   "the per-call reset is what makes mode-exclusivity sufficient; without it "
   "a leak could survive between thinks")

print()
if FAIL:
    print("FAILED: %d" % len(FAIL))
    sys.exit(1)
print("all checks pass")

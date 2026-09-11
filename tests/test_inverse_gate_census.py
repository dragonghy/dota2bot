#!/usr/bin/env python3
"""[ratchet] tools/agent/inverse_gate_census.py -- the two ways it can lie.

The leg answers "can this candidate's domain only be reached THROUGH another
candidate's gate" (director RULING 13, `test_set.md` §GS.2).  It has exactly
two failure directions and they are not symmetric:

  * A MISSED dependency is the defect the leg exists for -- a retired id
    silently zeroing another id's domain while `check_armed_wiring.py` still
    reads WIRED and the next verdict comes back "tested, no effect".
  * A FALSE dependency is worse in a different way: it declares a live lever
    structurally dead, and on trunk the first two cuts of this tool did
    exactly that.  Both false positives are pinned below by name, because
    both were real and both were plausible:
      - a SIBLING `if` read as a dominator (`fieldbuy` reported as needing
        `fieldregen`, which is the sibling purchase block above it -- a lever
        with 785 measured episodes);
      - a NEGATIVE THROTTLE read as a guard (`rotscope` and `pulldrag`
        reported as needing `creepthink`, whose line can only make the
        throttle's `return` LESS likely, i.e. arming it WIDENS what follows).

GROUND TRUTH.  `pulldrag -> pullcamp` was derived BY HAND in RULING 13 before
this tool existed, through `bot.roamCampPull`, and it is the one case where
the answer is known independently of the code being tested.  If the field-
mediated mechanism ever stops finding it, the leg has lost the only thing it
was built to see.

WHAT THIS FILE DOES NOT ASSERT: that the live tree has any particular FROZEN
count.  That number is a property of today's armed string and changes with
every ruling; pinning it here would make an ordinary retire look like a
regression.  What is pinned is that the tool RUNS on the real tree and that
its three states stay distinguishable.

Run: python3 tests/test_inverse_gate_census.py
"""

import importlib.util
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(REPO, "tools", "agent", "inverse_gate_census.py")

spec = importlib.util.spec_from_file_location("igc", TOOL)
igc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(igc)

checks = []


def check(name, ok, detail=""):
    checks.append((name, bool(ok), detail))


# --------------------------------------------------- the decision procedure
#
# These are the two condition shapes the tool has to tell apart, verbatim from
# bots/.  Everything else in the file rests on this pair being decided rather
# than pattern-matched.
GUARD = "not J.IsSoakCandidate( 'fieldbuy' )"
THROTTLE = ("not (bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink')) "
            "and not (bot.roamCreepPull ~= nil and "
            "J.IsSoakCandidate('creepthink')) "
            "and J.Utils.IsBotThinkingMeaningfulAction(bot, C.ThinkLess, 'roam')")
ENTRY = "J.IsModeTurbo() and J.IsSoakCandidate( 'slotpush' )"

check("an early-return guard forces its return when the gate is unarmed",
      igc.forced_outcome(GUARD, "fieldbuy", True) is True)
check("a negative throttle does NOT force its return when the gate is unarmed",
      igc.forced_outcome(THROTTLE, "creepthink", True) is False)
check("the same throttle is not an entry condition either",
      igc.forced_outcome(THROTTLE, "creepthink", False) is False)
check("an entry condition blocks the block when the gate is unarmed",
      igc.forced_outcome(ENTRY, "slotpush", False) is True)
check("a condition naming a different gate is not a dependency",
      igc.forced_outcome(GUARD, "someotherid", True) is False)
# "Cannot answer" must never read as "not a dependency".  Two malformed shapes,
# both rejected by the PARSER: the tokeniser is total, and the `return None` it
# used to carry was unreachable -- a mutation of it survived this whole stand,
# which is how the dead branch was found.
check("an unbalanced condition reads None, never a silent False",
      igc.forced_outcome("not J.IsSoakCandidate( 'x' ) and (", "x", True)
      is None)
check("a condition with a stray close-paren reads None too",
      igc.forced_outcome(") J.IsSoakCandidate( 'x' )", "x", True) is None)
check("too many free atoms reads None, never a silent False",
      igc.forced_outcome(" and ".join(["a%d()" % i for i in range(20)])
                         + " and J.IsSoakCandidate( 'x' )", "x", False) is None)

# --------------------------------------------------- (A1) on a built tree
#
# The decision procedure is checked above; what this checks is that (A1)
# actually CONSULTS it.  On the live tree it cannot be checked: every gate
# that appears in an enclosing condition there happens to dominate, so
# hard-wiring "yes" gives the same answers and the mutation survives.  A
# disjunctive condition is the case that separates them, and the tree does not
# contain one -- so it is built.
LEAF = ["function J.Leaf( bot )",
        "\tif not J.IsSoakCandidate( 'leafid' ) then return false end",
        "\treturn true",
        "end",
        ""]
CALLER_OR = ["function J.CallerOr( bot )",
             "\tif J.IsSoakCandidate( 'orid' ) or bot:IsAlive()",
             "\tthen",
             "\t\treturn J.Leaf( bot )",
             "\tend",
             "end",
             ""]
CALLER_AND = ["function J.CallerAnd( bot )",
              "\tif J.IsSoakCandidate( 'andid' ) and bot:IsAlive()",
              "\tthen",
              "\t\treturn J.Leaf( bot )",
              "\tend",
              "end",
              ""]


def synth_deps(body):
    """(state, deps) for 'leafid' in a tree built from `body`."""
    for cache in (igc._CALLSITE_CACHE, igc._FIELDSRC_CACHE, igc._GATESIN_CACHE,
                  igc._CROSSING_CACHE, igc._ASSIGN_INDEX):
        cache.clear()
    igc._REFERENCE_INDEX = None
    sfiles = {"bots/synth.lua": body}
    sindex = {r: igc.index_functions(l) for r, l in sfiles.items()}
    state, paths, _n = igc.analyse(sfiles, sindex, igc.gate_sites(sfiles),
                                   "leafid")
    return state, {o for p in paths for (o, _w) in p}


# Each caller is put in a tree ALONE, so it is the only path and the verdict
# is about it.  Together they would answer a different question: one clear
# path makes the leaf CLEAR and the other path is then not reported at all.
sstate, sdeps = synth_deps(LEAF + CALLER_OR)
check("(A1) a gate in a DISJUNCTIVE enclosing condition does not block the "
      "path", sstate == "CLEAR" and "orid" not in sdeps,
      "%s %s" % (sstate, sorted(sdeps)))
sstate, sdeps = synth_deps(LEAF + CALLER_AND)
check("(A1) a gate in a CONJUNCTIVE enclosing condition does block it",
      sstate == "DEP" and sdeps == {"andid"}, "%s %s" % (sstate, sorted(sdeps)))
sstate, sdeps = synth_deps(LEAF + CALLER_OR + CALLER_AND)
check("(A1) one unblocked caller is enough to make the leaf CLEAR",
      sstate == "CLEAR", "%s %s" % (sstate, sorted(sdeps)))

for cache in (igc._CALLSITE_CACHE, igc._FIELDSRC_CACHE, igc._GATESIN_CACHE,
              igc._CROSSING_CACHE, igc._ASSIGN_INDEX):
    cache.clear()
igc._REFERENCE_INDEX = None

# --------------------------------------------------------- the real tree
files = igc.load_files()
funcindex = {rel: igc.index_functions(lines) for rel, lines in files.items()}
gates = igc.gate_sites(files)

check("the real tree carries gate sites at all", len(gates) > 50,
      "%d gate id(s)" % len(gates))


def deps_of(gid):
    state, paths, _notes = igc.analyse(files, funcindex, gates, gid)
    return state, {o for p in paths for (o, _w) in p}


# GROUND TRUTH -- derived by hand in RULING 13, before this tool existed.
state, deps = deps_of("pulldrag")
check("pulldrag is not reachable without crossing a gate", state == "DEP",
      state)
check("pulldrag's domain hangs under pullcamp (RULING 13, by hand, via "
      "bot.roamCampPull)", "pullcamp" in deps, sorted(deps))
check("pulldrag is NOT reported under creepthink (negative throttle)",
      "creepthink" not in deps, sorted(deps))
check("pulldrag is NOT reported under pulllane/pullnolane (inner branches of "
      "the producer only narrow which camp comes back)",
      not ({"pulllane", "pullnolane"} & deps), sorted(deps))

state, deps = deps_of("campbind")
check("campbind hangs under pullcamp too (§GS.2)",
      state == "DEP" and "pullcamp" in deps, "%s %s" % (state, sorted(deps)))

# FALSE POSITIVES, both of which the tool actually emitted before it was fixed.
state, deps = deps_of("fieldbuy")
check("fieldbuy is NOT reported under fieldregen (sibling purchase block)",
      "fieldregen" not in deps, sorted(deps))
state, deps = deps_of("rotscope")
check("rotscope is NOT reported under creepthink (negative throttle)",
      "creepthink" not in deps, sorted(deps))

# The nesting the source comments state in prose, read back off the code.
state, deps = deps_of("fieldsip")
check("fieldsip is reachable only through its consumers' gates",
      state == "DEP", state)
check("fieldsip's consumers include fieldbuy and both hold-side wrappers",
      {"fieldbuy", "stayfield", "stayfield2"} <= deps, sorted(deps))

# ------------------------------------------------------------ the wrapper
run = subprocess.run([sys.executable, TOOL], capture_output=True, text=True,
                     cwd=REPO, timeout=300)
check("the leg returns 0 (clean) or 3 (findings), never a crash",
      run.returncode in (0, 3), "rc=%d\n%s" % (run.returncode, run.stderr[-400:]))
check("the banner names all three states so a CLEAR cannot absorb an "
      "UNRESOLVED",
      "FROZEN" in run.stdout and "COUPLED" in run.stdout
      and "UNRESOLVED" in run.stdout, run.stdout[:300])

failed = [c for c in checks if not c[1]]
for name, ok, detail in checks:
    if not ok:
        print("FAIL  %s\n        %s" % (name, detail))
print("%d checks, %d failed" % (len(checks), len(failed)))
sys.exit(1 if failed else 0)

#!/usr/bin/env bash
# Mutation stand for the COMMENT STRIP in tests/test_gate_claim_consistency.lua
# (2026-09-03).  Run by hand when that file, or the comment blocks in
# bots/mode_roam_generic.lua / bots/FunLib/jmz_func.lua that it reads, is edited.
#
# WHAT IS UNDER TEST AND WHY IT NEEDS A STAND.  That file's verdict is
# `not claim.promoted and not wired[claim.id]`.  Until this round the wired set
# was extracted from the RAW file, so an id appearing in `IsSoakCandidate('id')`
# form only INSIDE A COMMENT counted as wired -- the register was built out of
# the text it audits.  Two live carriers, both self-referential: 'pullbeat'
# (PROMOTED 2026-08-23, wired by nothing, quoted in three comment blocks that
# teach the `pullcad` trap) and 'X' (the metavariable in jmz_func.lua's
# statement of that same trap).  A comment reading `-- Gated (turbo +
# 'pullbeat')` therefore passed clean, which is the `nochaselow` failure that
# file was written for, reached by a different door.
#
# The strip is not a `gsub`, and every mutant below is a plausible edit toward
# one:  strings hold the ids (`IsSoakCandidate('pullcad')` IS a string), a `--`
# inside a string is not a comment, `--[[` and `[[` both occur in bots/ (80 and
# 204 times), and blanking must leave the LINE STRUCTURE alone or the SoakStrArms
# body match downstream stops finding its function.  (Byte offsets survive too,
# but see the M5 note below for why that half is not a tested claim.)
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant (0CORP).
#
# ⚠ WHAT THIS STAND DELIBERATELY DOES NOT ATTACK.  No mutant merely WEAKENS the
# tree ratchet's expected set (`'X,pullbeat'` -> anything).  A file cannot catch
# its own assertion being loosened, so "SURVIVED" there would be a statement
# about mutation testing rather than about this file (0EQUIV, and the same
# disposition mutstand_ckpush.sh records for its M9/M10 drafts).  The same fact
# is attacked from the DATA side instead: M6 fabricates the "before" figure,
# M11 adds a third comment-only id, and M12 re-wires 'pullbeat' for real.
#
# ⚠ TWO DRAFTS OF M5 SURVIVED BEFORE THE THIRD CAUGHT, and the reason is reusable:
# THE HEADER CLAIMED MORE THAN ANY READER NEEDS.  Draft 1 made the strip DELETE
# comment bytes rather than blank them, on the strength of "positions are
# preserved".  It survived, and correctly: every extractor here is a
# position-independent `gmatch`, so byte offsets are a property nothing in this
# repo reads.  Draft 2 swallowed a line comment's terminating newline -- also a
# no-op, because the blanking pattern `[^\n]` spares the newline it just took.
# The property with a real reader is the LINE STRUCTURE downstream
# (`SoakStrArms%b()(.-)\nend`), and destroying it takes BOTH edits at once, which
# is what M5 now does.  ⇒ A stand's job includes finding out which half of a
# header's claim is load-bearing; two survivors said "offsets" was the decorative
# half.  The residual gap is named rather than deleted with the drafts: nothing
# here would notice a future strip that shifts offsets while keeping newlines,
# and until something reads an offset, nothing should.
#
# ⚠ AND ONE CONTROL WAS SHARPENED BY A SURVIVOR.  M2 (drop the long-comment branch)
# first survived because the control's `--[==[ ... ]==]` was written on ONE LINE,
# where the line-comment branch blanks it correctly by accident.  bots/ has 80 long
# comments and most of them span lines; the control now does too.  A single-line
# example of a multi-line construct is a control that agrees with the bug.
#
# Usage: bash tools/agent/mutstand_gatecomment.sh
set -u
cd "$(dirname "$0")/../.."

FILES=(
    tests/test_gate_claim_consistency.lua
    bots/mode_roam_generic.lua
)
TESTS=(
    test_gate_claim_consistency
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_gc.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null || { echo "RESTORE FAILED"; exit 2; }
}

trap restore EXIT

run_tests() {
    local rc=0
    for t in "${TESTS[@]}"; do
        lua5.1 tests/run_tests.lua "$t" > "$WORK/run.log" 2>&1
        local one=$?
        if [ "$one" -ne 0 ]; then rc=$one; fi
    done
    return $rc
}

apply_mutant() {
    MUT="$1" python3 - <<'PY'
import os, sys

mut = os.environ["MUT"]
TEST = "tests/test_gate_claim_consistency.lua"
ROAM = "bots/mode_roam_generic.lua"

STRIP_CALL = "local function wired_ids_in(src, into)\n    return wired_ids_in_text(strip_lua_comments(src), into)\nend\n"

MUTANTS = {
    # M1: THE REVERT -- the strip is not applied.  This is the tree exactly as
    #     it stood before 2026-09-03, and it is the mutant the whole file is
    #     for: 'X' and 'pullbeat' come back into the wired set and every
    #     over-claim naming them goes invisible again.
    "M1": [(TEST, STRIP_CALL,
            "local function wired_ids_in(src, into)\n"
            "    return wired_ids_in_text(src, into)\nend\n")],
    # M2: line comments only -- the `--[[ ]]` branch is dropped, so a long
    #     comment blanks its first line and the rest of it is read as code.
    #     bots/ has 80 of these.
    "M2": [(TEST,
            "            local _, le, leq = src:find('^%-%-%[(=*)%[', first)\n",
            "            local _, le, leq = src:find('^ZZNEVERMATCH(=*)%[', first)\n")],
    # M3: long STRINGS are blanked as if they were comments.  Strings are where
    #     the gate ids live; `[[ ... ]]` blocks in bots/ (204 of them) would
    #     stop contributing anything, and the census would go quiet in the one
    #     direction that never reports.
    "M3": [(TEST,
            "            local close = ']' .. beq .. ']'\n"
            "            local j = src:find(close, first + #beq + 2, true)\n"
            "            local stop = j and (j + #close - 1) or n\n"
            "            out[#out + 1] = src:sub(first, stop)\n",
            "            local close = ']' .. beq .. ']'\n"
            "            local j = src:find(close, first + #beq + 2, true)\n"
            "            local stop = j and (j + #close - 1) or n\n"
            "            out[#out + 1] = (src:sub(first, stop):gsub('[^\\n]', ' '))\n")],
    # M4: THE NAIVE GSUB -- the edit anybody would reach for first.  It cannot
    #     tell a `--` inside a string from a comment, and it deletes rather than
    #     blanks, so byte offsets move.
    "M4": [(TEST, STRIP_CALL,
            "local function wired_ids_in(src, into)\n"
            "    return wired_ids_in_text((src:gsub('%-%-[^\\n]*', '')), into)\nend\n")],
    # M5: THE STRIP IS ONE CHARACTER TOO GREEDY -- a line comment takes its own
    #     terminating newline (off-by-one on `stop`) and the blanking no longer
    #     spares newlines.  Two source lines merge, and the wildcard rule
    #     downstream is anchored on `\nend`.
    #     Two edits, because either alone is a NO-OP: `[^\n]` spares the swallowed
    #     newline, and sparing newlines matters only once one has been swallowed.
    #     That pair is why the first draft of this mutant survived (see header).
    "M5": [(TEST,
            "                local j = src:find('\\n', first, true)\n"
            "                stop = j and (j - 1) or n\n",
            "                local j = src:find('\\n', first, true)\n"
            "                stop = j or n\n"),
           (TEST,
            "            out[#out + 1] = (src:sub(first, stop):gsub('[^\\n]', ' '))\n",
            "            out[#out + 1] = (src:sub(first, stop):gsub('.', ' '))\n")],
    # M6: the ratchet's "before" figure is FABRICATED -- both sides of the
    #     comparison read stripped text, so the difference is empty by
    #     construction and the domain price reads zero on any tree.  This is the
    #     data-side attack on the expected set (see the header note).
    "M6": [(TEST,
            "        wired_ids_in_text(src, raw)   -- comments included (before the fix)\n",
            "        wired_ids_in(src, raw)   -- comments included (before the fix)\n")],
    # M7: the strip is applied only to SHORT sources.  Every synthetic control
    #     in the file still passes; every real file in bots/ goes unstripped.
    #     A guard that is true only on test data is how a census stops covering
    #     shipped code without anything turning red.
    "M7": [(TEST, STRIP_CALL,
            "local function wired_ids_in(src, into)\n"
            "    if #src >= 1000 then return wired_ids_in_text(src, into) end\n"
            "    return wired_ids_in_text(strip_lua_comments(src), into)\nend\n")],
    # M8: `claims_in` is fed the STRIPPED source.  The claim census reads
    #     comments on purpose -- stripping them there empties it, and an empty
    #     claim set makes the invariant vacuously true.
    "M8": [(TEST,
            "        for _, c in ipairs(claims_in(src, path)) do",
            "        for _, c in ipairs(claims_in(strip_lua_comments(src), path)) do")],
    # M9: short strings are blanked too.  Every quoted gate id in the tree
    #     disappears; the wired set collapses to whatever the matcher body
    #     contributes.
    "M9": [(TEST,
            "            stop = stop or n\n"
            "            out[#out + 1] = src:sub(first, stop)\n",
            "            stop = stop or n\n"
            "            out[#out + 1] = (src:sub(first, stop):gsub('[^\\n]', ' '))\n")],
    # M10: the long-comment close ignores the `=` level, so `--[==[ ... ]==]`
    #      never terminates and the strip eats the rest of the file from there.
    #      Over-stripping is the silent direction: it can only ever REMOVE ids.
    "M10": [(TEST,
             "                local close = ']' .. leq .. ']'\n",
             "                local close = ']]'\n")],
    # M11: a THIRD comment-only id appears in shipped source -- the MORE
    #      direction of the double-sided ratchet.  Writing one is allowed; the
    #      census not noticing is not.
    "M11": [(ROAM,
             "-- mutually exclusive BY CONSTRUCTION",
             "-- e.g. J.IsSoakCandidate('mutantid')\n\t-- mutually exclusive BY CONSTRUCTION")],
    # M12: 'pullbeat' is WIRED AGAIN for real -- a promoted id back in a live
    #      gate, which is the `pullcad` trap itself.  The FEWER direction, and
    #      the event the ratchet exists to make loud rather than legible only to
    #      someone re-reading three comment blocks.
    "M12": [(ROAM,
             "function GetDesire()",
             "local function MutantGate() return J.IsSoakCandidate('pullbeat') end\n"
             "function GetDesire()")],
    # M13: the memo on census() answers EMPTY from its second call on.  The walk
    #      was memoised this round to pay for the raw side (2.4s -> 1.1s), and a
    #      cache that quietly stops returning the tree is how a measured speedup
    #      becomes a silent census.  The anti-vacuity floors are what stand here.
    "M13": [(TEST,
             "    if cached_census then\n"
             "        return cached_census[1], cached_census[2], cached_census[3]\n"
             "    end\n",
             "    if cached_census then\n"
             "        return {}, {}, {}\n"
             "    end\n")],
}

edits = MUTANTS[mut]
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    if old not in src:
        sys.stderr.write("ABORT: %s target absent in %s\n" % (mut, path))
        sys.exit(3)
for path, old, new in edits:
    src = open(path, encoding="utf-8").read()
    open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

echo "=== baseline (must be GREEN before any mutant is scored) ==="
run_tests
BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- every mutant below would score CAUGHT on this red."
    tail -20 "$WORK/run.log"
    exit 2
fi
echo "baseline GREEN"

CAUGHT=0; SURVIVED=0; ABORTED=0
for m in M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13; do
    restore
    apply_mutant "$m"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ABORT   $m -- target string absent; NOT scored"
        ABORTED=$((ABORTED + 1))
        continue
    fi
    run_tests
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "CAUGHT  $m"
        CAUGHT=$((CAUGHT + 1))
    else
        echo "SURVIVED $m  <-- an assertion is missing"
        SURVIVED=$((SURVIVED + 1))
    fi
done
restore

echo "=== $CAUGHT caught / $SURVIVED survived / $ABORTED aborted (of 13) ==="
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ]

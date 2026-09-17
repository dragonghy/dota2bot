#!/usr/bin/env bash
# Mutation stand for the argmax search/admission ring census (hero group,
# 2026-09-17; queue hero-102 cell (甲), GH #873).
#
# WHAT IT IS DEFENDING.  A source census fails QUIETLY.  Every way this one can
# be wrong produces a table that still prints 20 tidy rows and still exits 0 --
# it just answers a slightly different question than the one on the tin, and
# the number at the bottom is then quoted into an issue, a queue cell and a
# charter with nothing left to contradict it.  So the ratchet has to be shown
# to redden on each way, not asserted to.
#
# ⛔ THE MUTANTS ARE NOT INVENTED.  M1 and M4 are two defects this census
# ACTUALLY HAD while it was being written (a literal ring read as CONSISTENT;
# four same-named `local`s merged into one variable, which reported 13
# co-readers for a list that has none).  M2 is the classifier half of the
# provenance rule those two share.
# M3 is the one simplification that would erase the thesis of GH #873 §一 (the
# PLACE of the reach test is the difference between falling back and vetoing).
# M5/M6 are the two parser slips that would silently lose an admission ring.
# M7/M8 mutate `bots/` itself, to prove the ratchet reads the TREE and not a
# table typed into the test file.
#
# DISCIPLINE (evidence-discipline rules 1-3):
#   * pristine copies live OUTSIDE the temp dir the trap wipes; the trap is
#     armed BEFORE the first mutant; the run ends on a sha256 manifest;
#   * every mutant is `cmp`-checked, so a no-op edit cannot score as a mutant;
#   * exit codes are read BARE -- no pipe between the runner and `$?`.
#
# ⚠️ TWO MEASURED EQUIVALENTS, DECLARED RATHER THAN HIDDEN.  A stand that scores
# an equivalent as SURVIVED reports a coverage hole that does not exist; one
# that scores it as CAUGHT is lying.  Both of these are therefore named here and
# NOT run:
#
#   (a) `J.CombineTwoTable` resolving only its FIRST operand instead of the
#       wider of the two.  The two call sites are hero_jakiro.lua:523 and
#       hero_sven.lua:270, and at BOTH the operands are built on the same ring
#       (`nCastRange + 43`), so max, min and first-operand agree.
#   (b) `base_is_cast_range()` answering by NAME (`"CastRange" in base`) instead
#       of by provenance (an assignment from `GetCastRange()`).  ⭐ This one was
#       RUN FIRST AND SURVIVED, and the survival is the measurement: all 17
#       non-literal bases in the corpus are spelled `nCastRange` AND assigned
#       from `GetCastRange()`, and the three literal-ring rows are rejected one
#       branch earlier (`s_base == LITERAL_BASE`) before provenance is consulted
#       at all.  So the EXTRACTOR half of the provenance rule is defensive code
#       the corpus cannot price today -- ⛔ which is not the same as saying the
#       rule is unpriced: M2 prices the CLASSIFIER half, where the guard is what
#       turns an unproven base into UNCOMPARABLE.
#
# If a third CombineTwoTable site appears with unequal operands, or any hero
# builds a ring on a base named `*CastRange*` that is not assigned from
# `GetCastRange()`, these become real mutants; that is the moment to add them.
#
# Usage: bash tools/agent/mutstand_argmaxring.sh
set -u
cd "$(dirname "$0")/../.."

TOOL=tools/agent/argmax_ring_census.py
PYTEST=tests/test_argmax_ring_census.py
WK=bots/BotLib/hero_skeleton_king.lua
LION=bots/BotLib/hero_lion.lua

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand.XXXXXX")
BAK=$(mktemp -d "${TMPDIR:-/tmp}/mutbak.XXXXXX")     # NOT the dir the trap wipes
cp "$TOOL" "$BAK/tool.orig"
cp "$WK"   "$BAK/wk.orig"
cp "$LION" "$BAK/lion.orig"
sha256sum "$TOOL" "$WK" "$LION" > "$BAK/manifest.sha256"

restore() {
    cp "$BAK/tool.orig" "$TOOL"
    cp "$BAK/wk.orig"   "$WK"
    cp "$BAK/lion.orig" "$LION"
    if ! sha256sum -c --quiet "$BAK/manifest.sha256"; then
        printf 'FATAL: restore did not verify -- the tree may hold a mutant\n' >&2
        exit 9
    fi
}
trap 'restore; rm -rf "$WORK"' EXIT
restore                                   # prove the manifest before mutating

caught=0
survived=0

# run_case <name> <expect RED|GREEN> <target file> <python-mutator on $TARGET>
run_case() {
    local name="$1" expect="$2" target="${3:-}" mut="${4:-}"
    restore
    if [ -n "$mut" ]; then
        python3 - "$target" <<PY
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
$mut
open(p, 'w', encoding='utf-8').write(s)
PY
        local orig
        case "$target" in
            "$TOOL") orig="$BAK/tool.orig" ;;
            "$WK")   orig="$BAK/wk.orig" ;;
            "$LION") orig="$BAK/lion.orig" ;;
        esac
        if cmp -s "$orig" "$target"; then
            printf '%-8s ABORT: byte-identical file -- the anchor is gone, not the mutant\n' "$name"
            survived=$((survived + 1))
            return 1
        fi
    fi
    python3 "$PYTEST" > "$WORK/$name.out" 2>&1
    local rc=$?                            # bare, no pipe
    local verdict=GREEN
    [ "$rc" -ne 0 ] && verdict=RED
    if [ "$verdict" = "$expect" ]; then
        if [ "$name" = CONTROL ]; then
            printf '%-8s %-5s (expected %-5s) control_ok   %s\n' "$name" "$verdict" \
                "$expect" "$(grep -m1 'Ran .* tests' "$WORK/$name.out")"
        else
            caught=$((caught + 1))
            printf '%-8s %-5s (expected %-5s) CAUGHT       %s\n' "$name" "$verdict" \
                "$expect" "$(grep -m1 -E '^(FAIL|ERROR):' "$WORK/$name.out")"
        fi
    else
        [ "$name" = CONTROL ] || survived=$((survived + 1))
        printf '%-8s %-5s (expected %-5s) *** SURVIVED ***\n' "$name" "$verdict" "$expect"
        sed 's/^/           /' "$WORK/$name.out" | tail -20
    fi
}

printf '=== mutation stand: argmax search/admission ring census ===\n'
printf 'work %s   backups %s\n\n' "$WORK" "$BAK"

run_case CONTROL GREEN "" ""

# M1 -- A BARE LITERAL RING READ AS CONSISTENT.  The census's first version did
# exactly this: `_BASE_ONLY` was `^(\w+)$`, which matches `1600`, so a fixed
# 1600u search ring with no reach test scored as "the searched ring is the bare
# base" -- i.e. CORRECT.  Two rows (necrolyte, riki) flipped from
# "source cannot say" to "nothing to see here" on a regex character class.
run_case M1 RED "$TOOL" '
a = "_BASE_ONLY = re.compile(r\x27^([A-Za-z_]\\w*)$\x27)"
assert a in s, "M1 anchor missing"
s = s.replace(a, "_BASE_ONLY = re.compile(r\x27^(\\w+)$\x27)", 1)'

# M2 -- THE PROVENANCE GUARD DELETED FROM THE CLASSIFIER.  `nCastRange` is the
# house convention, not a guarantee; without this branch a ring whose base is
# never assigned from `GetCastRange()` scores CONSISTENT -- the same class of
# error as GH #725 reading 861.99u as "outside 670".
# ⚠️ The SIBLING mutant -- rewriting `base_is_cast_range()` itself to answer by
# NAME instead of by provenance -- is a measured equivalent on today's corpus
# and is deliberately NOT run; see the header note.
run_case M2 RED "$TOOL" '
a = """        if not row.get(\x27base_is_cast_range\x27):"""
assert a in s, "M2 anchor missing"
s = s.replace(a, """        if False:""", 1)'

# M3 -- THE PLACE OF THE REACH TEST ERASED.  This is the thesis of GH #873 §一.
# A test inside the loop filter cannot self-veto (a rejected candidate never
# wins, the argmax falls back); the SAME test on the winner alone kills the
# branch with a legal target standing in range.  A census that reports only
# "are the two rings equal" collapses those two into one row and loses the
# distinction the whole family is about.
run_case M3 RED "$TOOL" '
a = """    if row.get(\x27admission_place\x27) == \x27in-loop\x27:"""
assert a in s, "M3 anchor missing"
s = s.replace(a, """    if False:""", 1)'

# M4 -- SHADOWING IGNORED IN THE FANOUT COLUMN.  Measured, on this census's own
# first output: hero_arc_warden.lua declares `nInRangeEnemy` four separate times
# in one function, and a name-based count reported 13 co-readers for a list that
# has none.  The fanout number is what decides whether a gap is this leg's to
# fix, so a number inflated by homonyms is worse than no number.
run_case M4 RED "$TOOL" '
a = """            if scopes and binding_owner(scopes, i) != def_idx:"""
assert a in s, "M4 anchor missing"
s = s.replace(a, """            if False:""", 1)'

# M5 -- THE POST-LOOP WINNER TEST NEVER SCANNED.  Lion then reads OVER-REACH
# instead of SELF-VETO: same row, opposite failure, and the fix a reader would
# derive from it (tighten the search ring) is the one that makes Lion WORSE.
run_case M5 RED "$TOOL" '
a = """        post = distance_predicates("""
assert a in s, "M5 anchor missing"
s = s.replace(a, """        post = [] or distance_predicates(""", 1).replace(
    """        post = [] or distance_predicates(\x27\\n\x27.join(clean[win_idx:j + 1]), \x27npcMostDangerousEnemy\x27)""",
    """        post = []""", 1)'

# M6 -- THE WINNER CONDITION READ ONE LINE DEEP.  The realistic parser slip:
# Lion writes `if npcMostDangerousEnemy ~= nil` on one line and
# `and J.IsInRange( bot, npcMostDangerousEnemy, nCastRange + 50 )` on the next.
# A scanner that stops at the end of the first line finds no admission ring and
# reports the branch as having no reach test at all.
run_case M6 RED "$TOOL" '
a = """        while j < n and \x27then\x27 not in clean[j]:
            j += 1"""
assert a in s, "M6 anchor missing"
s = s.replace(a, """        pass""", 1)'

# M7 -- `bots/` MUTANT: Wraith King loses the 43.  Proves the focus-five row
# assertions read the TREE and not a table typed into the test file.  (It is
# also the shape of the fix GH #873 §四 considered and priced DO-NOT-ARM, so
# the red here is the ratchet correctly saying "that published table changed".)
run_case M7 RED "$WK" '
a = "J.GetNearbyHeroes(bot, nCastRange + 43, true, BOT_MODE_NONE )"
assert a in s, "M7 anchor missing"
s = s.replace(a, "J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE )", 1)'

# M8 -- `bots/` MUTANT: Lion loses its winner-only reach test.  The row then
# reads OVER-REACH 300u.  Same direction as M5 but applied to the tree instead
# of the parser, so the two together say the SELF-VETO reading needs both the
# source line and the scanner that finds it.
run_case M8 RED "$LION" '
a = """		if npcMostDangerousEnemy ~= nil
			and J.IsInRange( bot, npcMostDangerousEnemy, nCastRange + 50 )
		then"""
assert a in s, "M8 anchor missing"
s = s.replace(a, """		if npcMostDangerousEnemy ~= nil
		then""", 1)'

printf '\n%d CAUGHT / %d SURVIVED\n' "$caught" "$survived"
[ "$survived" -eq 0 ] || exit 3

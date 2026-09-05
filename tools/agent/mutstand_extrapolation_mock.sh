#!/usr/bin/env bash
# Mutation stand for tests/test_fixture_extrapolation_mock.lua (GH #492,
# director 2026-09-05).  Run by hand when that file, or the
# GetExtrapolatedLocation stub in tests/mock/replay_fixture.lua, is edited.
#
# WHAT IS UNDER TEST AND WHY IT NEEDS A STAND.  The repair itself is three
# lines and is not the risky part.  The risky part is the DECLARATION that ships
# with it: the mock cannot extrapolate, because a fixture is one instant and
# carries no velocity, so it answers the current location and models every unit
# as standing still.  That sentence is load-bearing for two published domains
# (test_set.md §EF.1's `fires`, and the 73 in
# tests/test_midsupmirror_checkability.lua), and it is exactly the kind of
# sentence that rots into a comment nobody measures -- which is the failure this
# repo has now recorded from several directions.
#
# So the mutants attack the DECLARATION, not the stub:
#   * can the file tell a standing-still mock from an extrapolating one? (M3)
#   * can it tell a corpus with no motion from a corpus with motion? (M4)
#   * ...without crying wolf at a fixture that merely SAYS the word? (M5, the
#     control, and the reason strip_line_comments exists at all -- every
#     fixture's generated header names the tool's own arguments)
#
# M1 is the revert, and it is the mutant with the widest blast radius: it is the
# tree exactly as it stood before this commit, where the guard raised on 257 of
# 257 in-domain frames and two `pcall` sweeps with two buckets scored those
# raises as measured "no"s.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠ WHAT THIS STAND DELIBERATELY DOES NOT ATTACK.  No mutant merely weakens an
# expected constant inside the test file itself; a file cannot catch its own
# assertion being loosened, so a SURVIVED there would be a statement about
# mutation testing rather than about this file.  The data side is attacked
# instead (M3/M4/M5 all mutate the mock or the corpus, never the expectation).
#
# Usage: bash tools/agent/mutstand_extrapolation_mock.sh
set -u
cd "$(dirname "$0")/../.."

MOCK=tests/mock/replay_fixture.lua
FIXTURE=tests/fixtures/f_071423_luna_chase.lua

FILES=(
    "$MOCK"
    "$FIXTURE"
)
TESTS=(
    test_fixture_extrapolation_mock
)

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_xm.XXXXXX")
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

STUB="            GetExtrapolatedLocation = function(self, _fTimeInFuture)
                return self:GetLocation()
            end,
"

apply_mutant() {
    MUT="$1" MOCK="$MOCK" FIXTURE="$FIXTURE" STUB="$STUB" python3 - <<'PY'
import os, sys

mut  = os.environ["MUT"]
MOCK = os.environ["MOCK"]
FIX  = os.environ["FIXTURE"]
STUB = os.environ["STUB"]

MUTANTS = {
    # M1: THE REVERT.  The stub is removed and the name falls back through
    #     bot_api.lua's `^Get -> 0` catch-all -- the tree exactly as it stood
    #     before this commit.  Every consumer indexes the 0 as a location and
    #     the frame raises again.
    "M1": [(MOCK, STUB, "")],
    # M2: the stub answers a TABLE that is not a location.  `type(e) == 'table'`
    #     alone would pass; the finding is that the value is USABLE as a
    #     location, which is what the shipped consumers index.
    "M2": [(MOCK, "                return self:GetLocation()\n",
                  "                return {}\n")],
    # M3: ⭐ THE LOAD-BEARING ONE.  The mock actually extrapolates -- 500 units
    #     along +x, which is a plausible "let's do this properly" edit.  Nothing
    #     RAISES, the guard still answers, and every count in the published
    #     domains stays readable; only the standing-still DECLARATION becomes
    #     false.  If [consequence] cannot catch this, the declaration is a
    #     comment with a test-shaped costume on.
    "M3": [(MOCK, "                return self:GetLocation()\n",
                  "                local v = self:GetLocation()\n"
                  "                return { x = v.x + 500, y = v.y, z = v.z }\n")],
    # M4: a fixture gains real motion state.  The corpus stops FORCING
    #     standing-still, so the model becomes an undeclared choice -- which is
    #     the precise thing [model] exists to refuse.
    "M4": [(FIX, "  units = {\n",
                 "  units = {\n    { name = 'npc_dota_hero_zzz', vel = 300 },\n")],
    # M5: ⚠ THE CONTROL, AND IT MUST SURVIVE.  The word appears in a COMMENT --
    #     which is where it will actually appear, because make_fixture.py writes
    #     a generated header naming its own arguments.  A scanner reading raw
    #     bytes reports this as motion state and the [model] leg starts crying
    #     wolf on a corpus that is fine.  Expected SURVIVED; a CAUGHT here means
    #     strip_line_comments is not doing its job and the leg is a false alarm
    #     waiting for the next fixture generation.
    "M5": [(FIX, "-- GENERATED by tools/batch_test/replayscope/make_fixture.py",
                 "-- GENERATED by make_fixture.py --velocity = off (facing = n/a)\n"
                 "-- GENERATED by tools/batch_test/replayscope/make_fixture.py")],
}

if mut not in MUTANTS:
    sys.stderr.write("unknown mutant %s\n" % mut)
    sys.exit(2)

for path, old, new in MUTANTS[mut]:
    with open(path) as f:
        src = f.read()
    if old not in src:
        sys.stderr.write("ABORT %s: target absent in %s\n" % (mut, path))
        sys.exit(3)
    with open(path, "w") as f:
        f.write(src.replace(old, new, 1))
PY
}

echo "=== baseline (must be GREEN before any mutant is trusted) ==="
run_tests
BASE=$?
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- nothing below means anything"
    cat "$WORK/run.log"
    exit 2
fi
echo "baseline: GREEN"
echo

# M5 is the control: it is EXPECTED to survive.  Everything else must be caught.
EXPECT_SURVIVE=" M5 "
FAILED=0
for m in M1 M2 M3 M4 M5; do
    restore
    apply_mutant "$m"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "$m: ABORTED (target string absent, exit $rc) -- the stand is stale"
        FAILED=1
        continue
    fi
    run_tests
    rc=$?
    if [ "$rc" -ne 0 ]; then verdict=CAUGHT; else verdict=SURVIVED; fi
    case "$EXPECT_SURVIVE" in
        *" $m "*) want=SURVIVED ;;
        *)        want=CAUGHT ;;
    esac
    if [ "$verdict" = "$want" ]; then
        echo "$m: $verdict (expected)"
    else
        echo "$m: $verdict -- EXPECTED $want"
        FAILED=1
    fi
done

restore
echo
echo "=== restored; re-running baseline ==="
run_tests
rc=$?
if [ "$rc" -ne 0 ]; then
    echo "POST-RESTORE BASELINE RED (exit $rc)"
    cat "$WORK/run.log"
    exit 2
fi
echo "post-restore baseline: GREEN"
# Disarm the trap BEFORE removing its scratch copies, or the EXIT handler runs
# after the directory is gone, `cp` fails, and a stand that scored 5/5 exits 2 --
# a pass wearing a failure's costume, which is the same family of defect as
# reading an exit code through a pipe.  Caught on this stand's first run.
trap - EXIT
rm -rf "$WORK"
if [ "$FAILED" -ne 0 ]; then
    echo "STAND: FAILED"
    exit 1
fi
echo "STAND: OK"

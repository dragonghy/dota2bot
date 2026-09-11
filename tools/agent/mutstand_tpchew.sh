#!/usr/bin/env bash
# Mutation stand for the `tpchew` lever (strategy desk 2026-09-11, GH #739).
# Not part of any suite -- run by hand when J.ShouldStepOutBeforeTpChannel,
# its one call site J.ShouldNotStartInterruptibleTp, the loader's
# GetNearbyNeutralCreeps reader, or tests/test_tpchew_channel_creep.lua is
# edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ ANCHOR HAZARD SPECIFIC TO THIS LEVER. The whole point of clause 1 is that
# it is the SAME call the shipped 'fieldcreep' clause makes, so the literal
# `bot:WasRecentlyDamagedByCreep( 3.0 )` occurs TWICE in $SRC. Its anchor below
# therefore carries the surrounding `if not ... then return false end`, which
# only this site has. A bare anchor would abort as AMBIGUOUS -- the right
# failure, but a stand that aborts scores nothing.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or while quietly meaning something else:
#   * M1/M2 are the two shapes of "the gate stops holding the change back":
#     M1 drops the candidate check, M2 drops turbo-only. Both make a leg fire
#     that must not -- the one thing a gated, turbo-only fix can never do.
#   * M3 is the opposite direction: the gate frozen shut, so the lever is a
#     no-op that still reads as landed. This is the leg that proves the effect
#     assertions are load-bearing rather than decorative.
#   * M4 is the pullcad trap (AGENTS.md): conjoin an already-PROMOTED id and
#     the gate is frozen FALSE forever, because a promoted id is in no armed
#     string. `tpsafe` is a real promoted id AND a real TP-family sibling, so
#     this is the plausible version of the mistake, not a strawman.
#   * ⭐ M5 IS THIS LEVER'S OWN FAILURE MODE, and it is the one the round had
#     to measure its way out of: DELETE CLAUSE 2. The bare "a creep hit me"
#     probe is what 'fieldcreep' ships, so this mutant looks like consistency
#     with a shipped precedent -- and every behavioural assertion on the head
#     frame and on N1 stays green, because a camp frame is a camp frame either
#     way. Only N2 and the corpus census can see it. It is the `lanefix` shape:
#     74 frames instead of 6.
#   * M6 is clause 2 inverted the cheap way: scan a radius so small nothing is
#     ever in it. The guard goes structurally dead while reading as present --
#     the thirteenth-world trap at this site.
#   * M7 moves the 3.0 lookback to 5.0. N1 is the whole reason that constant
#     has a frame: same fixture, other hero, one neutral hit at dt=4.7.
#   * M8 is the FORBIDDEN EDIT SHAPE: turn the append in the wrapper into an
#     insert, so the new leg is asked BEFORE the promoted hero predicate. The
#     answer is unchanged on every frame (both legs return booleans into an
#     `or`), which is exactly why this needs a source-order assertion rather
#     than a behavioural one -- the safety argument for touching a promoted
#     function is that its reads keep their order.
#   * M9 drops the rooted fall-through. A bot that cannot walk out then has its
#     last-resort scroll refused. No fixture can exercise IsRooted (the mock
#     answers every Is* false), so this leg must be caught by the test that
#     declares that vacuity and overrides the spec -- if it survives, that
#     declaration is decoration.
#   * ⭐⭐ M10 and M11 are the FORBIDDEN DIRECTION: leave the lever alone and
#     break the TEST's own measuring instrument. M10 makes the loader's
#     neutral reader accept lane creeps (so clause 2 stops discriminating and
#     the 6/6 split the narrowing argument rests on evaporates); M11 makes it
#     invent a neutral on an unattributed v1 row. Both leave the shipped Lua
#     untouched and both must go red, or the corpus census is measuring the
#     wrong bytes and nobody is told. The `bagtango` round walked into exactly
#     this (its M10) by scoring "red = caught" without reading WHY it was red.

set -u
cd "$(dirname "$0")/../.."

SRC=bots/FunLib/jmz_func.lua
MOCK=tests/mock/replay_fixture.lua
TEST=tests/test_tpchew_channel_creep.lua

FILES=("$SRC" "$MOCK" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_tpchew.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

run_tests() {
    lua5.1 tests/run_tests.lua test_tpchew_channel_creep > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
n = s.count(old)
if n == 0:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
if n != 1:
    sys.stderr.write("ANCHOR AMBIGUOUS (%d hits) in %s: %r\n" % (n, f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "ANCHOR PROBLEM -- stand aborted rather than scoring a no-op"
        exit 2
    fi
}

CAND=$'\tif not J.IsSoakCandidate( \'tpchew\' ) then return false end'
TURBO=$'function J.ShouldStepOutBeforeTpChannel( bot )\n\tif not J.IsModeTurbo() then return false end'
# Carries its own `if not ... then return false end` wrapper: the bare call
# also appears in the shipped 'fieldcreep' clause ~2000 lines below.
DMG=$'\tif not bot:WasRecentlyDamagedByCreep( 3.0 ) then return false end'
NEUT=$'\tlocal tNeutrals = bot:GetNearbyNeutralCreeps( 700 )\n\treturn tNeutrals ~= nil and #tNeutrals > 0'
ROOT=$'\tif bot:IsRooted() then return false end'
APPEND=$'\tif J.CanEnemyInterruptTpChannel( bot ) then return true end\n\treturn J.ShouldStepOutBeforeTpChannel( bot )'
SRCTEST=$'            and src:find(\'^npc_dota_neutral\') and not seen[src]'

PASS=0
FAIL=0

# $1 = label, $2 = "green"|"red" expected AFTER the mutation
expect() {
    label="$1"; want="$2"
    run_tests
    rc=$?
    if [ "$want" = red ]; then
        if [ "$rc" -ne 0 ]; then
            echo "  CAUGHT  $label"; PASS=$((PASS+1))
        else
            echo "  SURVIVED $label  <-- the suite cannot see this mutation"; FAIL=$((FAIL+1))
        fi
    else
        if [ "$rc" -eq 0 ]; then
            echo "  ok      $label"; PASS=$((PASS+1))
        else
            echo "  BROKE   $label  <-- expected green, got red"; FAIL=$((FAIL+1))
            sed -n '1,25p' "$WORK/run.log"
        fi
    fi
    restore
}

echo "=== baseline (unmutated tree must be GREEN) ==="
expect "baseline" green

echo "=== M1  candidate gate dropped (lever fires un-armed) ==="
sub "$SRC" "$CAND" $'\tif false then return false end'
expect "M1 candidate gate dropped" red

echo "=== M2  turbo-only dropped (ships into normal mode) ==="
sub "$SRC" "$TURBO" $'function J.ShouldStepOutBeforeTpChannel( bot )\n\tif false then return false end'
expect "M2 turbo gate dropped" red

echo "=== M3  gate frozen shut (lever is a no-op that reads as landed) ==="
sub "$SRC" "$CAND" $'\tif true then return false end'
expect "M3 gate frozen shut" red

echo "=== M4  pullcad trap: conjoin the PROMOTED sibling 'tpsafe' ==="
sub "$SRC" "$CAND" \
    $'\tif not ( J.IsSoakCandidate( \'tpchew\' ) and J.IsSoakCandidate( \'tpsafe\' ) ) then return false end'
expect "M4 conjoined with promoted 'tpsafe'" red

echo "=== M5  THIS LEVER'S TRAP: clause 2 deleted (the lanefix shape) ==="
sub "$SRC" "$NEUT" $'\treturn true'
expect "M5 neutral clause deleted -- bare creep probe" red

echo "=== M6  clause 2 scanned at a radius nothing can be inside ==="
sub "$SRC" "$NEUT" \
    $'\tlocal tNeutrals = bot:GetNearbyNeutralCreeps( 0 )\n\treturn tNeutrals ~= nil and #tNeutrals > 1000'
expect "M6 neutral scan structurally dead" red

echo "=== M7  lookback widened 3.0 -> 5.0 (N1 is the frame that owns this) ==="
sub "$SRC" "$DMG" $'\tif not bot:WasRecentlyDamagedByCreep( 5.0 ) then return false end'
expect "M7 lookback 3.0 -> 5.0" red

echo "=== M8  the append turned into an insert (promoted read loses its order) ==="
sub "$SRC" "$APPEND" \
    $'\tif J.ShouldStepOutBeforeTpChannel( bot ) then return true end\n\treturn J.CanEnemyInterruptTpChannel( bot )'
expect "M8 append -> insert" red

echo "=== M9  rooted fall-through dropped (scroll refused with no way out) ==="
sub "$SRC" "$ROOT" $'\tif false then return false end'
expect "M9 rooted fall-through dropped" red

echo "=== M10 INSTRUMENT: the loader's neutral reader accepts lane creeps ==="
sub "$MOCK" "$SRCTEST" $'            and src:find(\'^npc_dota\') and not seen[src]'
expect "M10 neutral reader stops discriminating" red

echo "=== M11 INSTRUMENT: the loader invents a neutral on an unattributed row ==="
sub "$MOCK" \
    $'            local src = d.src' \
    $'            local src = d.src or \'npc_dota_neutral_unknown\''
expect "M11 neutral reader invents attribution" red

echo
echo "STAND: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
echo "STAND GREEN"

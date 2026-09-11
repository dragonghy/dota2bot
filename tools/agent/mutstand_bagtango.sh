#!/usr/bin/env bash
# Mutation stand for the `bagtango` lever (strategy desk 2026-09-11T04:xxZ, GH #734).
# Not part of any suite -- run by hand when TrySwapInvItemForFieldRegen in
# bots/mode_team_roam_generic.lua, its one call site, or
# tests/test_bagtango_field_regen_rescuer.lua is edited.
#
# DISCIPLINE (evidence-discipline skill, rules 1-3):
#   * restore is an out-of-tree `cp` verified with `sha256sum -c`, never
#     `git checkout` (which would revert unrelated working-tree edits);
#   * exit codes are read BARE -- no pipe between the test and `$?`;
#   * a mutant whose anchor is absent OR ambiguous ABORTS: a no-op edit scored
#     as "caught" is the stand lying about what was on the bench.
#
# ⚠️ ANCHOR HAZARD SPECIFIC TO THIS FILE, and it is the reason several anchors
# below carry more context than looks necessary: this lever is a deliberate
# near-duplicate of five SHIPPED rescuers in the same file (clarity, flask,
# smoke, moonshard, cheese, refresher_shard). The lines
# `local lessValItem = J.Item.GetMainInvLessValItemSlot(bot)`,
# `if lessValItem ~= -1` and the swap call each occur SIX times in $SRC. Every
# anchor here is therefore either inside this function's unique gate/loop or
# carries a neighbouring unique line. A bare anchor would abort as AMBIGUOUS --
# the right failure, but still a failure, and a stand that aborts scores nothing.
#
# WHAT THIS STAND IS FOR -- the ways this lever could LOOK landed while leaving
# the defect, or while quietly meaning something else:
#   * M1/M2 are the two shapes of "the gate stops holding the change back":
#     M1 drops the candidate check, M2 drops turbo-only. Both make a leg fire
#     that must not -- the one thing a gated, turbo-only fix can never do.
#   * M3 is the opposite direction: the gate is frozen shut, so the lever is a
#     no-op that still reads as landed. This is the leg that proves the effect
#     assertions are load-bearing rather than decorative.
#   * M4 is the pullcad trap (AGENTS.md): conjoin an already-PROMOTED id and the
#     gate is frozen FALSE forever, because a promoted id is in no armed string.
#     `fight` is a real promoted id. Section [isolation] is the only place that
#     can see it, because behaviourally M4 looks exactly like M3.
#   * ⭐ M5 IS THIS LEVER'S OWN FAILURE MODE: point the gate at 'bagsalve' or
#     'staybag'. Those two widen what the tree BELIEVES it carries; this one
#     widens what it can REACH. Sharing an id arms them together, which is the
#     call-spread pullcad that 'staybag's own header documents -- and every
#     behavioural assertion stays green, because the rescuer still does the
#     right thing when it is armed.
#   * M6 breaks the slot test (BACKPACK -> MAIN). This is the thirteenth-world
#     trap at this site: it is how the rescuer goes structurally dead while
#     every count reads a quiet, believable zero.
#   * M7 and M8 are the two ways the rescued SET can drift: M7 adds the bottle
#     (deliberately excluded -- its problem is charge state, not slot), M8 drops
#     faerie fire, which is the ONE member the pinned frame carries for real.
#   * M9 is the swap written backwards (main <-> bag instead of bag <-> main).
#     It still "fires", still logs one action, and moves the consumable the
#     wrong way.
#   * ⭐⭐ M10 is the FORBIDDEN DIRECTION and the one this round actually walked
#     into: leave the lever alone and break the TEST's own measuring instrument.
#     `fn_body` exists because `body_of` runs to the next `function` keyword and
#     swallows this id's 60-line doc comment -- which made the set-difference
#     premise read the FLASK rescuer's body as containing "bagtango" and report
#     "the flask rescuer disappeared". Reverting fn_body to body_of must go red,
#     or the premise is measuring the wrong bytes again and nobody is told.
#   * M11 is the premise eroding the other way: give faerie fire a SHIPPED
#     rescuer. This id is then redundant and the premise must say so out loud
#     rather than quietly continuing to pass.

set -u
cd "$(dirname "$0")/../.."

SRC=bots/mode_team_roam_generic.lua
TEST=tests/test_bagtango_field_regen_rescuer.lua

FILES=("$SRC" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_bagtango.XXXXXX")
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
    lua5.1 tests/run_tests.lua bagtango > "$WORK/run.log" 2>&1
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

CAND=$'\tif not J.IsSoakCandidate(\'bagtango\') then return end'
TURBO=$'\tif not J.IsModeTurbo() then return end'
LOOP=$'\t\tfor _, sName in ipairs({ \'item_tango\', \'item_tango_single\', \'item_faerie_fire\' })'
# Carries the loop's own `break`, which no shipped rescuer has -- the six
# byte-identical swap calls in this file make a bare anchor ambiguous.
SWAP=$'\t\t\t\t\tbot:ActionImmediate_SwapItems(cSlot, lessValItem)\n\t\t\t\t\tbreak'
SLOT=$'\t\t\tand bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_BACKPACK'

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
sub "$SRC" "$CAND" $'\tif false then return end'
expect "M1 candidate gate dropped" red

echo "=== M2  turbo-only dropped (ships into normal mode) ==="
sub "$SRC" "$TURBO" $'\tif false then return end'
expect "M2 turbo gate dropped" red

echo "=== M3  gate frozen shut (lever is a no-op that reads as landed) ==="
sub "$SRC" "$CAND" $'\tif true then return end'
expect "M3 gate frozen shut" red

echo "=== M4  pullcad trap: conjoin a PROMOTED id (frozen FALSE forever) ==="
sub "$SRC" "$CAND" \
    $'\tif not (J.IsSoakCandidate(\'bagtango\') and J.IsSoakCandidate(\'fight\')) then return end'
expect "M4 conjoined with promoted 'fight'" red

echo "=== M5  this lever's own trap: share 'staybag's id (arms as a bundle) ==="
sub "$SRC" "$CAND" $'\tif not J.IsSoakCandidate(\'staybag\') then return end'
expect "M5 gate renamed to 'staybag'" red

echo "=== M6  slot test broken (thirteenth world: rescuer silently dead) ==="
sub "$SRC" "$SLOT" $'\t\t\tand bot:GetItemSlotType(cSlot) == ITEM_SLOT_TYPE_MAIN'
expect "M6 BACKPACK -> MAIN" red

echo "=== M7  rescued set widened to the bottle (deliberately excluded) ==="
sub "$SRC" "$LOOP" \
    $'\t\tfor _, sName in ipairs({ \'item_tango\', \'item_tango_single\', \'item_faerie_fire\', \'item_bottle\' })'
expect "M7 bottle added" red

echo "=== M8  faerie fire dropped (the one the pinned frame really carries) ==="
sub "$SRC" "$LOOP" $'\t\tfor _, sName in ipairs({ \'item_tango\', \'item_tango_single\' })'
expect "M8 faerie fire dropped" red

echo "=== M9  swap written backwards (fires, moves it the wrong way) ==="
sub "$SRC" "$SWAP" $'\t\t\t\t\tbot:ActionImmediate_SwapItems(lessValItem, cSlot)\n\t\t\t\t\tbreak'
expect "M9 swap arguments reversed" red

echo "=== M10 the TEST's own instrument: fn_body reverted to body_of ==="
sub "$TEST" $'        local b = fn_body(roam, \'function \' .. name .. \'()\')' \
            $'        local b = body_of(roam, \'function \' .. name .. \'()\')'
expect "M10 premise measures the wrong bytes" red

echo "=== M11 premise erodes: faerie fire gains a SHIPPED rescuer ==="
sub "$SRC" $'\t\tlocal cSlot = bot:FindItemSlot(\'item_smoke_of_deceit\')' \
           $'\t\tlocal cSlot = bot:FindItemSlot(\'item_faerie_fire\')'
expect "M11 shipped rescuer added for faerie fire" red

echo
echo "STAND: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
echo "STAND GREEN"

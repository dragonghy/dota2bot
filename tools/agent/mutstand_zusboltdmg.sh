#!/usr/bin/env bash
# Mutation stand for the `zusboltdmg` candidate -- X.ConsiderW's ranged-creep
# snipe freed from a structurally-zero damage read (hero, 2026-09-05,
# OWNER_PRIORITIES P4.4).
# Run by hand when X.GetBoltRangedKillDamage, X.ConsiderW or
# tests/test_zuus_bolt_ranged_damage.lua are edited, and before quoting any of
# that file's readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_wkbonefight.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is ABSENT *or* AMBIGUOUS aborts, so a mutant can never
#     score "caught" for having applied to nothing, nor "survived" for having
#     applied to the wrong one of two near-identical sites.  This file has TWO
#     gated helpers reading the same ability (`zusboltcap` and `zusboltdmg`) and
#     their gate lines differ only by the id -- exactly the collision that cost
#     mutstand_axecallbkb.sh a slot;
#   * the baseline is proven GREEN before the first mutant.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# WHAT THIS STAND IS FOR.  Four mutants are directional or instrumental rather
# than cosmetic, and they are the ones worth reading:
#   * M3 is the DEAD-WIRING twin: helper present, id registered, call site
#     present, and the armed answer byte-for-byte the shipped one.  The lever is
#     then inert in every wave and the verdict reads back "tested, no effect"
#     with nothing raising a hand (GH #531's third shape).
#   * M4 is the FORBIDDEN DIRECTION and it is the mutant this lever was written
#     around.  `<` instead of `>` reads like a typo and turns a max into a min:
#     armed then answers BELOW shipped and silently DELETES snipes the shipped
#     bot makes.  No counter reports a cast that did not happen.
#   * M7 is a control on the END-TO-END SWEEP.  Section 4d's "arming changed
#     something" is the whole claim that the lever is live; collapse the health
#     ladder to a health no bolt can kill and that claim must fail.
#   * M8 is a control on the SUPPLY ZERO, which is the most easily faked reading
#     in the file: point section 5's creep probe at a substring every fixture
#     really carries.  If section 5 stays green, the probe was never looking.
#
# Usage: bash tools/agent/mutstand_zusboltdmg.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_zuus.lua
TEST=tests/test_zuus_bolt_ranged_damage.lua

FILES=("$HERO" "$TEST")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zbd.XXXXXX")
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

# The filter is `zuus`, not this one file: two sibling ratchets
# (test_zuus_static_field_second_consumer.lua, test_zuus_bolt_kill_cap.lua) pin
# the same expression and the same call count, and a stand scoped to the new file
# alone would report a collision there as SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua zuus > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort on an absent OR ambiguous anchor.
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
}

GATE_LINE=$'\tif J.IsModeTurbo() and J.IsSoakCandidate( \'zusboltdmg\' )'
ARMED_LINE=$'\t\tif type( nKvDamage ) == \'number\' and nKvDamage > nShipped then return nKvDamage end'
SHIPPED_BIND=$'\tlocal nShipped = hAbility:GetAbilityDamage()'
CALL_SITE=$'\tlocal nDamage = X.GetBoltRangedKillDamage( abilityW ) * ( 1 + bot:GetSpellAmp() )'

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the candidate check is dropped.  The repair becomes the shipped default in
#     every Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M1: the gate stops asking whether the candidate is armed ==="
sub "$HERO" "$GATE_LINE" $'\tif J.IsModeTurbo()'
score "M1" "unarmed answer at shipped="

# ---------------------------------------------------------------------------
# M2: turbo-only is dropped, the candidate check kept.  The narrower half of M1.
echo
echo "=== M2: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" "$GATE_LINE" $'\tif J.IsSoakCandidate( \'zusboltdmg\' )'
score "M2" "non-turbo answer at shipped="

# ---------------------------------------------------------------------------
# M3: THE DEAD-WIRING TWIN.  The armed branch returns the shipped number.
echo
echo "=== M3: the armed branch answers exactly what shipped answers ==="
sub "$HERO" "$ARMED_LINE" $'\t\tif type( nKvDamage ) == \'number\' and nKvDamage > nShipped then return nShipped end'
score "M3" "armed clause admits"

# ---------------------------------------------------------------------------
# M4: THE FORBIDDEN DIRECTION.  One character: `>` becomes `<`, a max becomes a
#     min, and armed can answer BELOW shipped -- deleting a snipe rather than
#     adding one.
echo
echo '=== M4: the comparison flips, so armed can answer BELOW shipped ==='
sub "$HERO" "$ARMED_LINE" $'\t\tif type( nKvDamage ) == \'number\' and nKvDamage < nShipped then return nKvDamage end'
score "M4" "is BELOW the shipped"

# ---------------------------------------------------------------------------
# M5: gate-off stops being the shipped path.  The binding the whole
#     by-construction argument rests on reads the KV instead, so EVERY leg --
#     unarmed, non-turbo, real games -- gets the repaired number.
echo
echo "=== M5: the shipped binding reads the KV, so gate-off is no longer shipped ==="
sub "$HERO" "$SHIPPED_BIND" $'\tlocal nShipped = hAbility:GetSpecialValueInt( \'damage\' )'
score "M5" "must bind the shipped read to nShipped"

# ---------------------------------------------------------------------------
# M6: the call site reverts to the raw read.  The helper, the id, the gate and
#     the registration all survive review; only the wire is gone.
echo
echo '=== M6: X.ConsiderW reads GetAbilityDamage() again and stops calling the helper ==='
sub "$HERO" "$CALL_SITE" $'\tlocal nDamage = abilityW:GetAbilityDamage() * ( 1 + bot:GetSpellAmp() )'
score "M6" "must go through the helper"

# ---------------------------------------------------------------------------
# M7: a control on the END-TO-END SWEEP.  Section 4d's "arming changed
#     something" is the entire claim that this lever is live rather than merely
#     present.  Replace the health ladder with a health no bolt can kill: if 4d
#     stays green it was never measuring a difference.
echo
echo "=== M7: the end-to-end health ladder is moved out of reach (instrument control) ==="
sub "$TEST" "local HEALTH_LADDER  = { 1, 5, 25, 50, 100, 150, 200, 250, 300, 400, 550, 700, 1000, 2000 }" \
            "local HEALTH_LADDER  = { 100000 }"
score "M7" "arming changed nothing on any of"

# ---------------------------------------------------------------------------
# M8: a control on the SUPPLY ZERO.  Section 5's "0 of 10 frames carry creeps"
#     is the kind of reading that is true either because the corpus says so or
#     because the probe is broken.  Point it at a substring every fixture really
#     carries -- if section 5 stays green, `find` was answering nil for
#     everything and the zero measured the instrument.
echo
echo "=== M8: the creep probe is pointed at a substring the corpus DOES carry (instrument control) ==="
sub "$TEST" "u.name:find('_creep', 1, true)" "u.name:find('_hero', 1, true)"
score "M8" "Zeus frames now carry creep units"

# ---------------------------------------------------------------------------
echo
echo "=== $CAUGHT/$TOTAL CAUGHT ==="

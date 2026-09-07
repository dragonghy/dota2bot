#!/usr/bin/env bash
# Mutation stand for tests/test_axe_call_staged_frames.lua -- the two REAL frames
# GH #577 section 5 registered, pinned 2026-09-07 (hero, backlog -112).
#
# WHY A SECOND STAND AND NOT MORE MUTANTS IN mutstand_axecallbkb.sh.  That stand
# proves the GATE is wired: its mutants live in bots/BotLib/hero_axe.lua and are
# scored against a counterfactual world built on the corpus frame.  This one
# proves the FRAMES are load-bearing, and its mutants live somewhere that stand
# cannot reach at all -- the frame files, the shipped override the immunity
# repair agrees with, and the dumper's own snapshot schema.  A mutant in
# main.go is not a mutant in a Lua gate, and neither stand can score the other's.
#
# DISCIPLINE (inherited from tools/agent/mutstand_axecallbkb.sh):
#   * out-of-tree restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * an anchor that is absent OR ambiguous ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#   * F10 adds a FILE rather than editing one, so `restore` deletes it by name --
#     a sha256 check over the tracked files cannot see a stray copy.
#
# ⚠️ DO NOT RUN THIS CONCURRENTLY WITH THE FULL SUITE OR THE SELFCHECK.  A stand
# that rewrites shipped source in place opens a tearing window for any concurrent
# reader (GH #507).
#
# THE THREE MUTANTS WORTH READING:
#   * F3 is the one that decides whether the immunity REPAIR is a repair.  The
#     whole "zero invented state" claim rests on `modifier_black_king_bar_immune`
#     being a name the SHIPPED IsMagicImmune override reads.  Drop it there and
#     the repair becomes an invention -- and the file must say so, not pass.
#   * F4/F5 are the schema leg, which is the only assertion in the new file that
#     outlives both frames: "no frame from this generator can reach branch (ii)"
#     is falsifiable exactly when the dumper grows a target or mode channel.  A
#     stand that could not score these would leave that claim unguarded.
#   * F8 removes the immunity repair from the loader while leaving the channel
#     repair in place.  If the DEFECT case still reads 0 afterwards, the frame is
#     not showing what the file says it shows -- the shipped bot would have
#     declined for some other reason and the immunity term is not the subject.
#
# Usage: bash tools/agent/mutstand_axecall_frames.sh
set -u
cd "$(dirname "$0")/../.."

HERO=bots/BotLib/hero_axe.lua
TEST=tests/test_axe_call_staged_frames.lua
OVERRIDES=bots/FunLib/aba_global_overrides.lua
DUMPER=tools/batch_test/behavioral/dumper/main.go
FRAME_I=tests/frames/f_260831_061811_axe_call_tp_channel.lua
FRAME_II=tests/frames/f_260828_002127_axe_call_bkb_ring.lua

# The path F10 creates.  Named here so `restore` can remove it even if the
# mutant aborts halfway.
STRAY=tests/fixtures/f_260828_002127_axe_call_bkb_ring.lua

FILES=("$HERO" "$TEST" "$OVERRIDES" "$DUMPER" "$FRAME_I" "$FRAME_II")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_acf.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    rm -f "$STRAY"
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

# The filter is `axe`, not this one file: mutants in hero_axe.lua are also seen
# by tests/test_axe_call_immune_veto.lua and tests/test_axe_cull_immune_veto.lua,
# and a stand scoped to the new file alone would report a collision there as
# SURVIVED.
run_tests() {
    lua5.1 tests/run_tests.lua axe > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex).  Abort if the anchor is missing OR ambiguous:
# a mutant that applied to nothing scores "caught" for the wrong reason, and one
# that applied to the WRONG of two identical sites scores "survived" for the
# wrong reason (GH #550).
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
# F1: frame (i) loses the BKB modifier.  The immunity repair in section 3 becomes
#     an invention and the "zero invented state" claim is false.
echo
echo "=== F1: frame (i)'s enemy stops carrying modifier_black_king_bar_immune ==="
sub "$FRAME_I" "{ name = 'modifier_black_king_bar_immune', remaining = 3.4" \
               "{ name = 'modifier_NOT_bkb_immune', remaining = 3.4"
score "F1" "the immunity repair in"

# ---------------------------------------------------------------------------
# F2: frame (i) loses the teleport modifier.  The channel repair becomes an
#     invention -- the weaker of the two repairs, and the one the header insists
#     must be quoted with its own caveat.
echo
echo "=== F2: frame (i)'s enemy stops carrying modifier_teleporting ==="
# Anchored through the PRECEDING modifier: two units on this frame carry
# `modifier_teleporting` (bristleback and crystal_maiden are both teleporting
# out), so the bare name is ambiguous and the stand refuses it -- which is the
# GH #550 guard doing its job, but it scores SURVIVED rather than telling you
# which unit you meant.  This anchor names bristleback's list unambiguously.
sub "$FRAME_I" "stacks = 4 }, { name = 'modifier_teleporting'" \
               "stacks = 4 }, { name = 'modifier_NOT_teleporting'"
score "F2" "the channel repair in"

# ---------------------------------------------------------------------------
# F3: THE REPAIR LOSES ITS CRITERION.  The shipped IsMagicImmune override stops
#     naming the BKB modifier.  The frames are untouched and every behavioural
#     case still passes -- what is gone is the reason the repair is agreement
#     with the shipped reader rather than a convenient stub.
echo
echo "=== F3: the shipped IsMagicImmune override stops naming the BKB modifier ==="
sub "$OVERRIDES" "        or self:HasModifier('modifier_black_king_bar_immune')" \
                 "        or self:HasModifier('modifier_black_king_bar_NOPE')"
score "F3" "stopped naming"

# ---------------------------------------------------------------------------
# F4: THE SCHEMA LEG, target half.  The dumper grows a target channel, so a frame
#     could carry bot:GetTarget() and branch (ii) may become reachable.  The claim
#     "no frame from this generator can reach it" must stop being asserted.
echo
echo "=== F4: the dumper's snapshot struct grows a target channel ==="
sub "$DUMPER" '	NetWorth  int32         `json:"net_worth"`' \
              '	AttackTarget int32      `json:"attack_target"`
	NetWorth  int32         `json:"net_worth"`'
score "F4" "the dumper grew a"

# ---------------------------------------------------------------------------
# F5: THE SCHEMA LEG, mode half.  Same shape, other premise: with an active-mode
#     channel J.IsGoingOnSomeone can be true on a frame.
echo
echo "=== F5: the dumper's snapshot struct grows an active-mode channel ==="
sub "$DUMPER" '	NetWorth  int32         `json:"net_worth"`' \
              '	Mode      int32         `json:"mode"`
	NetWorth  int32         `json:"net_worth"`'
score "F5" "the dumper grew a"

# ---------------------------------------------------------------------------
# F6: THE DEAD-WIRING TWIN, scored on the REAL frame this time.  Branch (i)
#     reverts to the shipped predicate while helper, id and call site all stay
#     intact.  mutstand_axecallbkb.sh scores this against a three-flip
#     counterfactual; here it is scored against a frame whose cooldown, immunity
#     and channel are all the replay's.
echo
echo "=== F6: branch (i) reverts to the shipped predicate (real-frame scoring) ==="
sub "$HERO" "			and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceInterruptOn() ) -- see X.IsCallPierceInterruptOn" \
            "			and not npcEnemy:IsMagicImmune() -- see X.IsCallPierceInterruptOn"
score "F6" "does not fire branch (i) here"

# ---------------------------------------------------------------------------
# F7: CROSSED WIRING.  Branch (i) reads branch (ii)'s helper.  Both ids exist,
#     both helpers exist, check_armed_wiring.py is happy -- and arming
#     `axecallbkb_i` moves nothing while arming `axecallbkb_ii` moves branch (i).
#     Only a case that arms ONE id and reads the decision can see it.
echo
echo "=== F7: branch (i) is wired to branch (ii)'s helper (the split goes cosmetic) ==="
sub "$HERO" "			and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceInterruptOn() ) -- see X.IsCallPierceInterruptOn" \
            "			and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceInitiateOn() ) -- see X.IsCallPierceInterruptOn"
score "F7" "moved branch (i)"

# ---------------------------------------------------------------------------
# F8: THE IMMUNITY REPAIR IS REMOVED FROM THE LOADER, the channel repair kept.
#     If the DEFECT case still reads 0 the frame is not isolating what the file
#     says it isolates -- the shipped bot would be declining for some reason
#     other than the immunity veto.
echo
echo "=== F8: opt.repairImmune becomes a no-op (is the immunity term the subject?) ==="
sub "$TEST" "    if opt.repairImmune then
        rawget(heroes[subject], '__spec').IsMagicImmune = true
    end" \
            "    if opt.repairImmune then
        rawget(heroes[subject], '__spec').IsMagicImmune = false
    end"
score "F8" "the shipped bot casts here after all"

# ---------------------------------------------------------------------------
# F9: A CONTROL ON THE INSTRUMENT, not the subject.  RING stops being 265.  If
#     section 1's "bristleback is the ONLY live enemy inside the ring" were
#     measured with a broken ring, the unambiguity the whole branch-(i) reading
#     rests on would be vacuous rather than true.
echo
echo "=== F9: the ring stops measuring 265u (control on the instrument) ==="
sub "$TEST" "local RING = Q_RADIUS - 50   -- 265, the interrupt branch's GetAroundEnemyHeroList arg" \
            "local RING = 99999           -- 265, the interrupt branch's GetAroundEnemyHeroList arg"
score "F9" "in-ring:"

# ---------------------------------------------------------------------------
# F10: THE STAGING CONTRACT.  A copy of a staged frame appears in
#      tests/fixtures/.  Nothing else changes -- every behavioural case still
#      passes -- but the corpus has silently grown a different-era frame whose
#      admission price this round did not measure (tests/frames/README.md).
echo
echo "=== F10: a staged frame is also admitted to tests/fixtures/ ==="
cp "$FRAME_II" "$STRAY"
score "F10" "has been ADMITTED"

# ---------------------------------------------------------------------------
echo
echo "=== restoring and re-proving the tree is clean ==="
restore
run_tests; FINAL=$?
echo "post-restore EXIT=$FINAL"
echo
echo "MUTANTS $CAUGHT/$TOTAL CAUGHT"
if [ "$FINAL" -ne 0 ]; then
    echo "⚠️ the tree did not come back green -- the count above is not trustworthy"
    exit 2
fi
[ "$CAUGHT" -eq "$TOTAL" ] || exit 3
exit 0

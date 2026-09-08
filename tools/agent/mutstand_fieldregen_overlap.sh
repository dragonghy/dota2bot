#!/usr/bin/env bash
# Mutation stand for tests/test_fieldregen_family_overlap.lua.
#
# The file it defends makes a claim about STRUCTURE -- five claimants on one
# purchase, the earlier one pre-empting the later four -- so every mutant below
# breaks one load-bearing piece of that structure and the stand asserts the test
# goes RED for it. A test that stays green through a mutant is not defending the
# thing its name says it defends.
#
# RESTORE IS FROM A FILE COPY AND IS VERIFIED WITH `git diff`, not with a
# checksum of the stand's own backup: a hash round-trip only proves the backup is
# self-consistent, and it stays green when the backup was taken from an ALREADY
# MUTATED file. `git diff --quiet` compares against the index, so it also catches
# that case, and it can only err in the noisy direction.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

BUY='bots/item_purchase_generic.lua'
BAK="$(mktemp)"
RUNNER="$(mktemp /tmp/frstand_runner.XXXXXX.lua)"

cp "$BUY" "$BAK" || exit 2

# `restore` is defined BEFORE the trap that calls it, and the trap calls it by
# NAME rather than repeating the `cp` inline. Both halves are load-bearing:
# an interrupted run must put the pristine file back, and a trap body that
# open-codes the copy is the shape tests/test_mutstand_restore_trap.py exists to
# refuse (GH #418 -- a last-armed trap that reaches no restore is strictly worse
# than no trap at all, because it can also delete the only pristine copy).
restore() { cp "$BAK" "$BUY"; }

trap 'restore 2>/dev/null; rm -f "$BAK" "$RUNNER"' EXIT

cat > "$RUNNER" <<'LUA'
package.path = 'tests/?.lua;' .. package.path
local ok, t = pcall(dofile, 'tests/test_fieldregen_family_overlap.lua')
if not ok then os.exit(1) end
local bad = 0
for _, fn in pairs(t) do
    local s = pcall(fn)
    if not s then bad = bad + 1 end
end
os.exit(bad == 0 and 0 or 1)
LUA

run_test() { lua5.1 "$RUNNER" >/dev/null 2>&1; echo $?; }

caught=0; survived=0; ctrl_ok=0

# The CONTROL first, and it runs before any mutant so a stand that is simply
# broken cannot print CAUGHT for everything. A pure comment edit must NOT be
# caught -- if it is, the test is reading prose as code and every CAUGHT below
# is worthless.
control() {
    restore
    perl -0pi -e 's/-- \[fieldregen, owner directive 20260723\]/-- [fieldregen, owner directive 20260723] (control edit)/' "$BUY"
    if ! git diff --quiet -- "$BUY"; then
        local rc; rc="$(run_test)"
        if [ "$rc" = "0" ]; then
            echo "CONTROL ok      : a pure comment edit is NOT caught"; ctrl_ok=1
        else
            echo "CONTROL BROKEN  : a comment-only edit turned the test red -- prose is being read as code"
        fi
    else
        echo "CONTROL BROKEN  : the control edit did not land (anchor missing)"
    fi
    restore
}

# $1 = label, $2 = perl program
mutate() {
    local label="$1"; shift
    restore
    perl -0pi -e "$1" "$BUY"
    if git diff --quiet -- "$BUY"; then
        echo "ANCHOR MISS     : $label -- the mutation did not land, so its CAUGHT would be a lie"
        survived=$((survived + 1))
        restore
        return
    fi
    local rc; rc="$(run_test)"
    if [ "$rc" != "0" ]; then
        echo "CAUGHT          : $label"; caught=$((caught + 1))
    else
        echo "SURVIVED        : $label"; survived=$((survived + 1))
    fi
    restore
}

control

# M1 -- the pre-emption DIRECTION. Renaming the family call so the fieldregen
# block no longer precedes a locatable four-arm block breaks the line-order
# claim that makes this pre-emption rather than co-occurrence.
mutate "M1 four-arm call site renamed (line-order claim unanchored)" \
    's/J\.ShouldFieldBuyRegen\(bot\) or J\.ShouldFieldBuyRegenHurt\(bot\)/J.ShouldFieldBuyRegenX(bot) or J.ShouldFieldBuyRegenHurt(bot)/'

# M2 -- the shared guard that CARRIES the pre-emption. Dropped from the FOUR-ARM
# block, so the earlier purchase stops suppressing the later one.
# ⚠ The anchor is `RegenRing(bot) )` and not the stash line itself: that line
# occurs THREE times in this file and perl without /g rewrites the FIRST match,
# which is the fieldregen block -- a mutant that silently cuts a different block
# while still printing CAUGHT (GH #550).
mutate "M2 four-arm block loses its stash guard (mechanism gone)" \
    's/RegenRing\(bot\) \)\n\tand bot:IsAlive\(\)\n\tand bot:FindItemSlot\(\x27item_flask\x27\) < 0\n\tand not IsThereHealingInStash\(bot\)\n/RegenRing(bot) )\n\tand bot:IsAlive()\n\tand bot:FindItemSlot(\x27item_flask\x27) < 0\n/'

# M3 -- the ABSENCE that creates the overlap with `buytower`. Give the
# fieldregen block a tower clause and it stops reaching that arm's frames.
# `and J.GetHP(bot) < 0.45` occurs exactly once in this file (checked).
mutate "M3 fieldregen block gains a tower ring (overlap shrinks silently)" \
    's/\tand J\.GetHP\(bot\) < 0\.45\n/\tand J.GetHP(bot) < 0.45\n\tand #bot:GetNearbyTowers( 1200, true ) == 0\n/'

# M4 -- the ABSENCE that creates the overlap with `buyring`.
mutate "M4 fieldregen block gains a hero ring (overlap shrinks silently)" \
    's/\tand J\.GetHP\(bot\) < 0\.45\n/\tand J.GetHP(bot) < 0.45\n\tand #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) == 0\n/'

# M5 -- the open band. A floor stops fieldregen underrunning the arms' own 0.18
# floor, which is one of the two reasons the bands overlap.
mutate "M5 fieldregen block gains an HP floor (band no longer open below)" \
    's/\tand J\.GetHP\(bot\) < 0\.45\n/\tand J.GetHP(bot) < 0.45\n\tand J.GetHP(bot) > 0.18\n/'

# M6 -- the CEILING constant. Not an absence but a number this file's header
# quotes; a silent move leaves every band statement describing a lever the tree
# no longer has.
mutate "M6 fieldregen ceiling moved 0.45 -> 0.60" \
    's/\tand J\.GetHP\(bot\) < 0\.45\n/\tand J.GetHP(bot) < 0.60\n/'

# M7 -- the item. If the two claimants stop buying the SAME item there is no
# pre-emption left to record. Anchored on the block's tail plus the following
# `-- [fieldbuy` comment, which occurs once (the bare purchase line occurs six
# times).
mutate "M7 fieldregen buys a different item (claimants no longer collide)" \
    's/\tthen\n\t\tbot:ActionImmediate_PurchaseItem\(\x27item_flask\x27\)\n\tend\n\n\t-- \[fieldbuy/\tthen\n\t\tbot:ActionImmediate_PurchaseItem(\x27item_clarity\x27)\n\tend\n\n\t-- [fieldbuy/'

restore
if git diff --quiet -- "$BUY"; then
    echo "RESTORE         : YES -- $BUY is byte-identical to the index"
else
    echo "RESTORE         : NO -- $BUY still differs from the index; FIX THIS"
    exit 2
fi

echo "----"
echo "control_ok=$ctrl_ok caught=$caught survived=$survived"
if [ "$ctrl_ok" != "1" ]; then exit 3; fi
if [ "$survived" != "0" ]; then exit 3; fi
exit 0

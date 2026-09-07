#!/usr/bin/env bash
# Mutation stand for tests/test_grenharass_domain.lua (test_set.md §FS).
#
# WHAT IT IS FOR. X.ConsiderItemDesire['item_blood_grenade']
# (bots/ability_item_usage_generic.lua ~:7209) is SHIPPED and un-gated, and BOTH
# of its branches are KILL-CONFIRMS: loop 1 needs the grenade's own 125 to
# finish the target (275 only inside a 15-DEGREE facing cone), loop 2 needs an
# ally whose own estimated damage already kills. So a 25-gold restocking laning
# consumable -- on the buy list of 51 hero files -- is only ever thrown as an
# execute. Measured: 100 corpus frames carry one in a main slot, 40 see an enemy
# hero inside the 900 cast range, and the shipped kill-confirm fires on ZERO of
# them. 'grenharass' appends a third branch for the trade-winning use:
# `enemyHero:GetHealth() <= totalDmg * 3`. Domain 8 of the 40.
#
# The case has four halves and they forge differently:
#   (a) the BEHAVIOUR: a DRIVEN before/after. The sweep runs the shipped
#       `_G.ItemUsageThink` on each frame twice, un-armed and armed, and reads
#       the recorded engine action -- 0 casts shipped, 8 armed;
#   (b) ⭐ the DIRECTION claim, which here is CONSTRUCTION and not argument. The
#       block is appended after both shipped `return`s, so arming can only turn
#       NONE into a cast and `flip_true_to_false` must be 0. A counter whose
#       content is all zeros cannot tell "the direction holds" from "the tally
#       never ran", so both directions go through ONE tally() called twice with
#       the legs swapped. M6 and M6b attack that construction, and M7 attacks
#       the placement that the zero depends on;
#   (c) ⭐⭐ the TWO INSTRUMENTS ON ONE NUMBER. `domain` comes from walking the
#       conjuncts; `cast_armed` comes from driving the shipped entry point.
#       They agree at 8, and the test asserts the EQUALITY -- so a stand that
#       let one silently answer for the other would let a conjunct walk that
#       has drifted away from the code still read as a measurement. M8 attacks
#       exactly that;
#   (d) ⭐ the SHIPPED-SIDE claim, i.e. what makes this a finding rather than a
#       preference: both shipped branches are kill-confirms and neither fires
#       here. That is parsed off the live file as a COUNT (M9, M10), so
#       deleting one must go red rather than leaving the argument as prose.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- M2 flips the threshold to
#     `>=`, which is the same idea pointed at the enemies the grenade cannot
#     meaningfully dent;
#   * ⭐ THE GATE STOPS BEING THE FIRST CONJUNCT (M3) -- reordered so the turbo
#     read happens before J.IsSoakCandidate. Behaviour is unchanged in every
#     armed configuration and no count moves; the only thing that catches it is
#     the byte-identical-when-unarmed claim, which is the claim the whole
#     gated-fix discipline rests on;
#   * ⭐ THE TURBO CONJUNCT LEAVES (M4) -- this entry has no IsModeTurbo above
#     it, so dropping it ships the lever into non-Turbo games. Invisible to
#     every corpus count (the fixtures are all Turbo);
#   * ⭐ THE SHIPPED SELF-PRESERVATION FLOOR LEAVES (M5) -- `nHealth >
#     nHealthCost * 2` does NOT bind on this corpus (40 of 40 pass it), so
#     deleting it moves no domain number at all. It is caught only by the
#     copied-clause census, which is why that census counts to 3 instead of
#     asking whether the clause is present;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M6, M6b) -- the direction tally stops
#     being called. `flip_true_to_false` then reads exactly as it does when
#     1012 frames were driven and none went the wrong way: the GH #171 shape;
#   * ⭐⭐ THE BLOCK MOVES ABOVE THE SHIPPED LOOPS (M7) -- syntactically fine,
#     and on THIS corpus behaviourally identical (the shipped loops fire on
#     nothing), so no count moves. What it destroys is the direction argument
#     itself: from there, arming CAN preempt a throw the shipped code would
#     have made. The mutant that is invisible to every number and fatal to the
#     claim;
#   * ⭐⭐ THE TWO INSTRUMENTS COLLAPSE (M8) -- the conjunct walk drops the
#     threshold, so `domain` stops being a measurement of the same predicate the
#     driven column runs;
#   * ⭐ THE SHIPPED-SIDE CLAIM IS A COUNT, NOT A FLAG (M9, M10) -- loop 1's
#     kill-confirm and loop 2's ally-damage requirement are deleted one at a
#     time. The 'stayurn' round's M6 survivor is what a presence flag costs;
#   * THE ARMING IS TOO WIDE (M11) -- the stub arms every id, so another lever
#     could move the answer while the flip is still credited here;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M12) -- strip_comments becomes
#     the identity, and this lever's comment quotes both shipped loops, the id
#     name and the threshold verbatim;
#   * ⭐ THE DRIVEN COLUMN GOES BLIND (M13) -- `make_castable` stops supplying
#     the castability flags, so `J.CanCastAbility` short-circuits and the entry
#     is never reached. `cast_armed` then reads 0, which is exactly what a lever
#     that does nothing reads (the sixteenth world assertion, turned into a
#     silent instrument failure);
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If
#     it is caught, something in the suite is satisfied by prose.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex
# (GH #550, GH #555). `perl -0pi -e "s///"` without /g rewrites the FIRST match,
# so an anchor occurring twice cuts a site the label does not name -- and then
# prints CAUGHT, indistinguishable from a mutant that worked. Every anchor below
# declares its expected count and `anchor` proves it on every run.
#
# ⛔ AND THE FOURTH FORM, paid for on mutstand_waitclar.sh: every mutant is a
# SHELL FUNCTION that NAMES ITS TARGET FILE. A bare `perl -0pi -e '...'` passed
# through "$@" reads STDIN, edits nothing, and the stand prints NO-OP for every
# shot.
#
# ⛔ AND THE FIFTH, paid for on the 'corpuspin' round: TWO mutants in ONE run
# only ever prove the FIRST one. If two negative controls are wanted, run them
# separately -- the second is never evaluated once the first has thrown, and the
# whole-run exit code looks identical either way.
#
# NOTE the quoting for multi-line needles: $'\n' (ANSI-C), never $(printf '\n')
# -- command substitution STRIPS trailing newlines, so the latter expands to the
# empty string and the needle silently collapses to one line and counts 0.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_grenharass.sh
#
# ⚠️ DO NOT EDIT THIS FILE WHILE IT IS RUNNING. bash reads a script by BYTE
# OFFSET as it executes; inserting bytes ahead of the current offset misaligns
# every later read and the run is void.
#
# ⚠️ AND DO NOT RUN IT CONCURRENTLY WITH routine_selfcheck.sh. That script's
# trunk-red leg READS the working tree while this one WRITES it, so a mutant in
# flight is reported as a trunk-red detector failure -- indistinguishable from a
# real one, and `git stash` does not help (it stashes the mutant too).
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AIUG=bots/ability_item_usage_generic.lua
SWEEP=tests/_grenharass_sweep.lua
TEST=grenharass

TMP=$(mktemp -d)
nrun=0; ncaught=0; nbad=0
INFLIGHT=""

save() {
    cp "$1" "$TMP/$(basename "$1").orig"
    sha256sum "$1" > "$TMP/$(basename "$1").sha"
    INFLIGHT="$1"
}
restore() {
    cp "$TMP/$(basename "$1").orig" "$1"
    if ! sha256sum -c "$TMP/$(basename "$1").sha" >/dev/null; then
        echo "FATAL: restore of $1 did not verify -- stopping before anything else runs"
        exit 2
    fi
    INFLIGHT=""
}
# GH #418's trap: restore FIRST, delete the copies SECOND. The reverse leaves a
# mutant in the tree and destroys the only original.
on_exit() {
    if [ -n "$INFLIGHT" ]; then
        echo "INTERRUPTED with $INFLIGHT mutated -- restoring before exit"
        restore "$INFLIGHT"
    fi
    rm -rf "$TMP"
}
trap on_exit EXIT

# Rule 3: read the exit code directly, never through a pipe.
run_test() {
    local rc=0
    lua5.1 tests/run_tests.lua "$TEST" > "$TMP/$TEST.log" 2>&1 || rc=$?
    echo "$rc"
}

anchor() {
    local want=$1 file=$2 needle=$3
    local n
    n=$(NEEDLE="$needle" python3 -c 'import os,sys; sys.stdout.write(str(open(sys.argv[1]).read().count(os.environ["NEEDLE"])))' "$file" 2>/dev/null || true)
    [ -z "$n" ] && n=0
    if [ "$n" -ne "$want" ]; then
        printf 'ANCHOR    %-58s occurs %s time(s) in %s, expected %s\n' \
            "$needle" "$n" "$file" "$want"
        nbad=$((nbad + 1))
        return 1
    fi
    return 0
}

# want=caught (a real mutant), want=survive (a control).
mutant() {
    local want=$1 label=$2 target=$3; shift 3
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        nbad=$((nbad + 1))
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$want" = caught ]; then
        if [ "$rc" -ne 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
            echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
            echo "            per its converse, first confirm the edit landed where you meant."
        fi
    else
        if [ "$rc" -eq 0 ]; then
            ncaught=$((ncaught + 1))
            printf 'SURVIVED  %-58s exit=%s  (control, as declared)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** CONTROL WENT RED **\n' "$label" "$rc"
            echo "          ^ a comment edit turned this suite red: something in it"
            echo "            is being satisfied by prose rather than by code."
        fi
    fi
}

# The gate and the whole gated block, exactly as they sit in the file. Read with
# `cat -A` before being written down: this entry is indented with ONE tab at
# statement level and the loop body runs to four -- the sibling stand's first
# version guessed and every anchor answered `occurs 0`.
GATE=$'\tif J.IsSoakCandidate(\'grenharass\')\n\t\tand J.IsModeTurbo()\n\tthen\n'
BLOCK=$'\tif J.IsSoakCandidate(\'grenharass\')\n\t\tand J.IsModeTurbo()\n\tthen\n\t\tfor _, enemyHero in pairs(nEnemyHeroes)\n\t\tdo\n\t\t\tif J.IsValidHero(enemyHero)\n\t\t\tand J.CanCastOnNonMagicImmune(enemyHero)\n\t\t\tand not J.IsSuspiciousIllusion(enemyHero)\n\t\t\tand enemyHero:GetHealth() <= totalDmg * 3\n\t\t\tand nHealth > nHealthCost * 2\n\t\t\tthen\n\t\t\t\tlocal nInRangeEnemy = J.GetEnemiesNearLoc(enemyHero:GetLocation(), nRadius)\n\n\t\t\t\tif nInRangeEnemy ~= nil and #nInRangeEnemy >= 1\n\t\t\t\tthen\n\t\t\t\t\treturn BOT_ACTION_DESIRE_HIGH, J.GetCenterOfUnits(nInRangeEnemy), \'ground\', \'Blood Grenade\'\n\t\t\t\tend\n\n\t\t\t\treturn BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation(), \'ground\', \'Blood Grenade\'\n\t\t\tend\n\t\tend\n\tend\n'
# The first line of the SHIPPED entry's body, used by M7 as the insertion point
# for the moved block.
HEAD=$'\tlocal totalDmg = nImpactDamage + (nDPS * nDuration)\n'

export GATE BLOCK HEAD

m1()  { perl -0pi -e "\$b=\$ENV{BLOCK}; s{\Q\$b\E}{}" "$AIUG"; }
m2()  { perl -0pi -e "s{and enemyHero:GetHealth\\(\\) <= totalDmg \\* 3}{and enemyHero:GetHealth() >= totalDmg * 3}" "$AIUG"; }
m3()  { perl -0pi -e "\$g=\$ENV{GATE}; \$n=\"\\tif J.IsModeTurbo()\\n\\t\\tand J.IsSoakCandidate('grenharass')\\n\\tthen\\n\"; s{\Q\$g\E}{\$n}" "$AIUG"; }
m4()  { perl -0pi -e "\$g=\$ENV{GATE}; \$n=\"\\tif J.IsSoakCandidate('grenharass')\\n\\tthen\\n\"; s{\Q\$g\E}{\$n}" "$AIUG"; }
m5()  { perl -0pi -e "s{\\t\\t\\tand enemyHero:GetHealth\\(\\) <= totalDmg \\* 3\\n\\t\\t\\tand nHealth > nHealthCost \\* 2\\n}{\\t\\t\\tand enemyHero:GetHealth() <= totalDmg * 3\\n}" "$AIUG"; }
m6()  { perl -0pi -e "s{tally\\(armed, shipped, 'flips', 'flip_true_to_false'\\)}{local _ = armed}" "$SWEEP"; }
m6b() { perl -0pi -e "s{tally\\(shipped, armed,\n\\s+'flips_swapped', 'flip_true_to_false_swapped'\\)}{local _ = shipped}" "$SWEEP"; }
# The block moves ABOVE both shipped loops: no corpus number moves (the shipped
# loops fire on nothing here), and the direction argument is gone.
m7()  { perl -0pi -e "\$b=\$ENV{BLOCK}; \$h=\$ENV{HEAD}; s{\Q\$b\E}{}; s{\Q\$h\E}{\$h . \$b}e" "$AIUG"; }
m8()  { perl -0pi -e "s{if e:GetHealth\\(\\) <= nTot \\* 3 then}{if true then}" "$SWEEP"; }
m9()  { perl -0pi -e "s{\\t\\tand canKillTarget\\n}{}" "$AIUG"; }
m10() { perl -0pi -e "s{\\t\\t\\t\\tand J\\.GetTotalEstimatedDamageToTarget\\(nInRangeAlly, enemyHero\\) >= enemyHero:GetHealth\\(\\)\\n}{}" "$AIUG"; }
m11() { perl -0pi -e "s{return armed and sId == 'grenharass'}{return armed}" "$SWEEP"; }
m12() { perl -0pi -e "s{    if s == nil then return nil end\n    return \\(s:gsub.*\n}{    if s == nil then return nil end\n    return s\n}" "$SWEEP"; }
m13() { perl -0pi -e "s{            h.IsTrained = function\\(\\) return true end\n}{}" "$SWEEP"; }
c1()  { perl -0pi -e "s{-- \\[grenharass\\] SOAK CANDIDATE, turbo only, inert until armed\\.}{-- [grenharass] (control edit, no code touched)}" "$AIUG"; }

# --- M1, M2: the lever leaves, or lands inverted -----------------------------
anchor 1 "$AIUG" "$BLOCK"
mutant caught "M1  the gated block is deleted outright"              "$AIUG" m1
anchor 1 "$AIUG" "and enemyHero:GetHealth() <= totalDmg * 3"
mutant caught "M2  the threshold is inverted (only fat targets)"     "$AIUG" m2

# --- M3: the gate stops short-circuiting --------------------------------------
# Behaviourally identical in every armed configuration; what it breaks is the
# claim that un-armed, no engine call below the gate is evaluated.
mutant caught "M3  gate reordered behind the turbo read"             "$AIUG" m3

# --- M4: the turbo conjunct leaves --------------------------------------------
# This entry has no IsModeTurbo above it, so the lever would ship into non-Turbo
# games. Every fixture is Turbo, so no corpus count moves.
mutant caught "M4  the explicit J.IsModeTurbo() conjunct is dropped" "$AIUG" m4

# --- M5: the shipped self-preservation floor leaves ---------------------------
# 40 of 40 corpus frames pass this clause, so deleting it moves NO domain
# number. Only the copied-clause census (which counts to 3) sees it.
anchor 3 "$AIUG" "and nHealth > nHealthCost * 2"
mutant caught "M5  the copied nHealth floor is deleted"              "$AIUG" m5

# --- M6, M6b: a zero that was never measured ----------------------------------
anchor 1 "$SWEEP" "tally(armed, shipped, 'flips', 'flip_true_to_false')"
mutant caught "M6  the direction tally stops being called"           "$SWEEP" m6
mutant caught "M6b the SWAPPED direction tally stops being called"   "$SWEEP" m6b

# --- M7: the block moves above the shipped loops ------------------------------
# ⭐⭐ The mutant that is invisible to every number and fatal to the claim.
mutant caught "M7  the gated block moves above both shipped loops"   "$AIUG" m7

# --- M8: the two instruments collapse -----------------------------------------
anchor 1 "$SWEEP" "if e:GetHealth() <= nTot * 3 then"
mutant caught "M8  the conjunct walk drops the threshold"            "$SWEEP" m8

# --- M9, M10: the shipped-side claim is a count, not a flag -------------------
anchor 1 "$AIUG" $'\t\tand canKillTarget\n'
mutant caught "M9  loop 1's kill-confirm conjunct is deleted"        "$AIUG" m9
anchor 1 "$AIUG" "and J.GetTotalEstimatedDamageToTarget(nInRangeAlly, enemyHero) >= enemyHero:GetHealth()"
mutant caught "M10 loop 2's ally-damage requirement is deleted"      "$AIUG" m10

# --- M11: the arming is too wide ----------------------------------------------
mutant caught "M11 the sweep's gate stub arms every id"              "$SWEEP" m11

# --- M12: the instrument reads prose ------------------------------------------
# This lever's comment quotes both shipped loops, the id name and the threshold
# verbatim, so an identity strip_comments would let the COMMENT satisfy the
# structural assertions.
mutant caught "M12 strip_comments becomes the identity"              "$SWEEP" m12

# --- M13: the driven column goes blind ----------------------------------------
# Without IsTrained, J.CanCastAbility short-circuits and the shipped dispatcher
# never reaches this entry -- `cast_armed` reads 0, exactly like a lever that
# does nothing.
anchor 1 "$SWEEP" "            h.IsTrained = function() return true end"
mutant caught "M13 make_castable stops supplying IsTrained"          "$SWEEP" m13

# --- C1: the control -----------------------------------------------------------
mutant survive "C1  comment-only edit inside the lever"              "$AIUG" c1

echo
printf '%d run / %d as declared / %d NOT as declared\n' "$nrun" "$ncaught" "$nbad"
if [ "$nbad" -eq 0 ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED"
exit 1

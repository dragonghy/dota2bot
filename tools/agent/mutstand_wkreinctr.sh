#!/usr/bin/env bash
# Mutation stand for tests/test_wkreinctr_untrained.lua (test_set.md §FR).
#
# WHAT IT IS FOR. J.IsWkReincarnationArmed (bots/FunLib/jmz_func.lua) is
# SHIPPED, and its one caller -- mode_retreat_generic.lua ~:198, also SHIPPED --
# spends its answer on `return BOT_MODE_DESIRE_NONE`: the WHOLE retreat mode
# goes to zero for a Wraith King in a team fight. The helper decides that on a
# cooldown read and 160 mana, and neither notices that `bot:GetAbilityByName`
# hands back a live handle for an ability with no skill point in it -- a level-0
# ability is not on cooldown, so an unlearned Reincarnation reads ARMED.
# Measured: 24 of the 36 live Wraith King frames answer TRUE and 14 of those 24
# sit on ability level 0. 'wkreinctr' adds `not abilityR:IsTrained()`.
#
# The case has four halves and they forge differently:
#   (a) the BEHAVIOUR: a DRIVEN before/after of the shipped helper on real
#       frames with one soak id toggled;
#   (b) ⭐ the DIRECTION claim. Prepending a veto can only turn TRUE into FALSE,
#       so `flip_false_to_true` must be 0 -- and a counter whose content is all
#       zeros cannot tell "the direction holds" from "the tally never ran".
#       Both directions go through ONE tally() called twice with the legs
#       swapped; M8 and M8b attack that construction rather than the lever;
#   (c) ⭐⭐ the TWO COLUMNS, which is the part a reader is most likely to get
#       wrong. The flip set is 14 at the HELPER and 0 at the CALL SITE, because
#       the call site's own `J.IsInTeamFight(bot, 1200)` is false on all 36 WK
#       frames this corpus holds. A stand that let those two collapse into one
#       number would let "the domain was not reached" be quoted as "tested, no
#       effect" -- the GH #576 mistake, priced in wave money. M9 and M14 attack
#       exactly that separation;
#   (d) ⭐ the "THE TREE ALREADY KNEW" claim, i.e. condition (c) of the owner's
#       validation philosophy: mode_retreat_generic's OWN huskar block pairs
#       GetAbilityByName with IsTrained() eight lines from the call site. That
#       is parsed off the live file as a COUNT (M10, M11), so deleting one must
#       go red rather than leaving the argument as prose.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2);
#   * ⭐ THE GATE STOPS BEING THE FIRST CONJUNCT (M3) -- reordered so
#     `abilityR:IsTrained()` is evaluated before `J.IsSoakCandidate`. Behaviour
#     is unchanged in every armed configuration and no count moves; the only
#     thing that catches it is the byte-identical-when-unarmed claim, which is
#     the claim the whole gated-fix discipline rests on;
#   * ⭐ THE TURBO CONJUNCT LEAVES (M4) -- neither this helper nor its call site
#     asks turbo above it, so dropping it ships the lever into non-Turbo games.
#     Invisible to every corpus count (the fixtures are Turbo);
#   * ⭐ THE VETO MOVES BELOW THE SIBLING (M5) -- syntactically fine and
#     behaviourally identical today, but it destroys the property the census row
#     was pinned on: the early `return false` is what makes the two ids on this
#     helper SEQUENTIAL and independently sufficient rather than conjoined;
#   * THE READ DRIFTS TO THE WRONG QUESTION (M6) -- `GetLevel() >= 0` instead of
#     IsTrained(), i.e. a test that is true for every handle the engine returns.
#     The mutant that looks like the same idea and measures nothing;
#   * ⭐ THE CALL SITE'S OWN GUARD IS DELETED (M7) -- `bot:GetLevel() >= 6` is
#     what cuts 14 to 2, and that arithmetic is the honest bound this lever is
#     sold with;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M8, M8b) -- the direction tally stops
#     being called. `flip_false_to_true` then reads exactly as it does when 1012
#     frames were driven and none went the wrong way: the GH #171 shape;
#   * ⭐⭐ THE TWO COLUMNS COLLAPSE (M9) -- the call-site column stops applying
#     the team-fight guard, so the 0 that must be labelled "domain not reached"
#     silently becomes a different number;
#   * ⭐ CONDITION (c) IS A COUNT, NOT A FLAG (M10, M11) -- the sibling
#     IsTrained() sites in the caller's own file are deleted one at a time. The
#     'stayurn' round's M6 survivor is what a presence flag costs here;
#   * THE ARMING IS TOO WIDE (M12) -- the stub arms every id, so another lever
#     could move the answer while the flip is still credited here;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M13) -- strip_comments becomes
#     the identity, and this lever's comment quotes the call site, both id names
#     and the huskar block verbatim;
#   * ⭐ THE ANTI-VACUUM WALK GOES BLIND (M14) -- the per-frame stop rows stop
#     being emitted, so "the corpus has no untrained ults" becomes
#     indistinguishable from "it has fifteen and something above rejects one";
#   * ⭐ THE PAIR COLUMN GOES BLIND (M15) -- `pair_ne_arm_in_flipset` is the
#     measurement that says a single-arm wave can attribute these flips, and it
#     is a ZERO. Its first version SURVIVED this shot: a bare `if ... then
#     bump() end` asserted == 0 is indistinguishable from one that never ran.
#     Both halves now go through ONE bump and the test asserts the complement;
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If
#     it is caught, something in the suite is satisfied by prose.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex
# (GH #550, GH #555). `perl -0pi -e "s///"` without /g rewrites the FIRST match,
# so an anchor occurring twice cuts a site the label does not name -- and then
# prints CAUGHT, indistinguishable from a mutant that worked. Every anchor below
# declares its expected count and `anchor` proves it on every run.
#
# ⛔ AND THE THIRD FORM: an anchor that is not WORD-anchored. A sibling sweep
# split Lua conditions on `if(.-)then` and read 3 of 6, because `HasModifier`
# CONTAINS the substring "if" (`Mod` + `if` + `ier`). Nothing went red; the
# number was simply wrong.
#
# ⛔ AND THE FOURTH, paid for on mutstand_waitclar.sh: every mutant is a SHELL
# FUNCTION that NAMES ITS TARGET FILE. A bare `perl -0pi -e '...'` passed
# through "$@" reads STDIN, edits nothing, and the stand prints NO-OP for every
# shot.
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
#   bash tools/agent/mutstand_wkreinctr.sh
#
# ⚠️ DO NOT EDIT THIS FILE WHILE IT IS RUNNING. bash reads a script by BYTE
# OFFSET as it executes; inserting bytes ahead of the current offset misaligns
# every later read and the run is void.
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
RET=bots/mode_retreat_generic.lua
SWEEP=tests/_wkreinctr_sweep.lua
TEST=wkreinctr

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

# The gate, exactly as it sits in the file (ONE tab on every line of the
# condition, two on the body). Read with `cat -A` before it was written down:
# the sibling stand's first version guessed four tabs and every anchor answered
# `occurs 0`.
GATE=$'\tif J.IsSoakCandidate( \'wkreinctr\' )\n\tand J.IsModeTurbo()\n\tand not abilityR:IsTrained()\n\tthen\n\t\treturn false\n\tend\n'
# mode_retreat_generic.lua is indented with SPACES, not tabs -- checked with
# `cat -A`, not assumed from the sibling file two directories up.
HUSKAR=$'        if hAbility and hAbility:IsTrained() and hAbility:GetLevel() >= 3 then\n'
LEVELG=$'        and bot:GetLevel() >= 6\n'

m1()  { perl -0pi -e "\$g=\$ENV{GATE}; s{\Q\$g\E}{}" "$JMZ"; }
m2()  { perl -0pi -e "s{and not abilityR:IsTrained\\(\\)}{and abilityR:IsTrained()}" "$JMZ"; }
m3()  { perl -0pi -e "\$g=\$ENV{GATE}; \$n=\"\\tif not abilityR:IsTrained()\\n\\tand J.IsModeTurbo()\\n\\tand J.IsSoakCandidate( 'wkreinctr' )\\n\\tthen\\n\\t\\treturn false\\n\\tend\\n\"; s{\Q\$g\E}{\$n}" "$JMZ"; }
m4()  { perl -0pi -e "s{\\tand J\\.IsModeTurbo\\(\\)\\n\\tand not abilityR:IsTrained\\(\\)}{\\tand not abilityR:IsTrained()}" "$JMZ"; }
# The veto moves BELOW the sibling's mana clause: same answers today, but the
# early `return false` that made the two ids sequential is gone, and with it the
# property the nesting-census row was pinned on.
m5()  { perl -0pi -e "\$g=\$ENV{GATE}; s{\Q\$g\E}{}; s{\\treturn bot:GetMana\\(\\) >= nReq\\n}{\\tif J.IsSoakCandidate( 'wkreinctr' )\\n\\tand J.IsModeTurbo()\\n\\tand not abilityR:IsTrained()\\n\\tthen\\n\\t\\treturn false\\n\\tend\\n\\treturn bot:GetMana() >= nReq\\n}" "$JMZ"; }
# `GetLevel() >= 0` is true for every handle the engine hands back, trained or
# not: the same idea, measuring nothing.
m6()  { perl -0pi -e "s{and not abilityR:IsTrained\\(\\)}{and not (abilityR:GetLevel() >= 0)}" "$JMZ"; }
m7()  { perl -0pi -e "\$l=\$ENV{LEVELG}; s{\Q\$l\E}{}" "$RET"; }
m8()  { perl -0pi -e "s{tally\\(shipped, arm, 'flips', 'flip_false_to_true'\\)}{local _ = shipped}" "$SWEEP"; }
m8b() { perl -0pi -e "s{tally\\(arm, shipped, 'flips_swapped', 'flip_false_to_true_swapped'\\)}{local _ = arm}" "$SWEEP"; }
m9()  { perl -0pi -e "s{local siteShip = bFight and nLv >= 6 and shipped}{local siteShip = nLv >= 6 and shipped}" "$SWEEP"; }
m10() { perl -0pi -e "\$h=\$ENV{HUSKAR}; \$n=\"        if hAbility and hAbility:GetLevel() >= 3 then\\n\"; s{\Q\$h\E}{\$n}" "$RET"; }
m11() { perl -0pi -e "s{\\(hAbility ~= nil and hAbility:IsTrained\\(\\) and hAbility:GetCooldownTimeRemaining\\(\\) <= 3}{(hAbility ~= nil and hAbility:GetCooldownTimeRemaining() <= 3}" "$RET"; }
m12() { perl -0pi -e "s{return armed and sId == 'wkreinctr'}{return armed}" "$SWEEP"; }
m13() { perl -0pi -e "s{    if s == nil then return nil end\n    return \\(s:gsub.*\n}{    if s == nil then return nil end\n    return s\n}" "$SWEEP"; }
m14() { perl -0pi -e "s{out:write\\(string\\.format\\('W %s %d %d %s %\\.1f %\\.0f %s %s %s %s\\\\n',}{local _ = (string.format('W %s %d %d %s %.1f %.0f %s %s %s %s\\\\n',}" "$SWEEP"; }
m15() { perl -0pi -e "s{\\s+bump\\(\\(shipped and not arm\\)\n\\s+and 'pair_ne_arm_in_flipset'\n\\s+or 'pair_ne_arm_out_flipset'\\)}{\n                                local _ = shipped}" "$SWEEP"; }
c1()  { perl -0pi -e "s{-- \\[wkreinctr / owner priority P2 kin, 2026-09-07\\] The clause BELOW this}{-- [wkreinctr] (control edit, no code touched)}" "$JMZ"; }

export GATE HUSKAR LEVELG

# --- M1, M2: the lever leaves, or lands inverted -----------------------------
anchor 1 "$JMZ" "$GATE"
mutant caught "M1  the gate block is deleted outright"               "$JMZ" m1
anchor 1 "$JMZ" "and not abilityR:IsTrained()"
mutant caught "M2  the veto is inverted (fires when TRAINED)"        "$JMZ" m2

# --- M3: the gate stops short-circuiting --------------------------------------
# Behaviourally identical in every armed configuration; what it breaks is the
# claim that un-armed the engine call below the gate is never evaluated.
mutant caught "M3  gate reordered behind the engine call"            "$JMZ" m3

# --- M4: the turbo conjunct leaves --------------------------------------------
# Neither this helper nor its call site asks turbo above it.
mutant caught "M4  the explicit J.IsModeTurbo() conjunct is dropped" "$JMZ" m4

# --- M5: the veto moves below the sibling -------------------------------------
# Same answers today; what it destroys is the early `return false` that makes
# the two ids on this helper sequential and independently sufficient.
mutant caught "M5  veto moved below the wkreincarnmp clause"         "$JMZ" m5

# --- M6: the read drifts to a question with no content ------------------------
mutant caught "M6  IsTrained() becomes GetLevel() >= 0 (vacuous)"    "$JMZ" m6

# --- M7: the call site's own narrowing guard is deleted -----------------------
# `GetLevel() >= 6` is what cuts the 14 helper flips to 2, and that arithmetic
# is the honest bound this lever is sold with.
anchor 1 "$RET" "$LEVELG"
mutant caught "M7  the call site's GetLevel() >= 6 guard is deleted" "$RET" m7

# --- M8, M8b: a zero that was never measured ----------------------------------
anchor 1 "$SWEEP" "tally(shipped, arm, 'flips', 'flip_false_to_true')"
mutant caught "M8  the real direction tally stops being called"      "$SWEEP" m8
anchor 1 "$SWEEP" "tally(arm, shipped, 'flips_swapped', 'flip_false_to_true_swapped')"
mutant caught "M8b the SWAPPED tally stops being called"             "$SWEEP" m8b

# --- M9: the two columns collapse ---------------------------------------------
# The call-site column stops applying the team-fight guard, so the 0 that has to
# be labelled "domain not reached on this corpus" quietly becomes a 2.
anchor 1 "$SWEEP" "local siteShip = bFight and nLv >= 6 and shipped"
mutant caught "M9  the call-site column drops the teamfight guard"   "$SWEEP" m9

# --- M10, M11: condition (c) is a COUNT of live sites -------------------------
# The argument is "this file already guards a GetAbilityByName handle with
# IsTrained(), eight lines from the call site". A presence flag reads the same
# whether that happens once or twice, which is exactly the 'stayurn' M6
# survivor; the test counts, so deleting EITHER site must go red.
anchor 1 "$RET" "$HUSKAR"
mutant caught "M10 the huskar block drops its IsTrained() conjunct"  "$RET" m10
anchor 1 "$RET" "(hAbility ~= nil and hAbility:IsTrained() and hAbility:GetCooldownTimeRemaining() <= 3"
mutant caught "M11 the OTHER IsTrained() site in the caller leaves"  "$RET" m11

# --- M12: the arming is too wide ----------------------------------------------
anchor 1 "$SWEEP" "return armed and sId == 'wkreinctr'"
mutant caught "M12 the sweep arms every id, not just this one"       "$SWEEP" m12

# --- M13: the instrument reads prose ------------------------------------------
# This lever's comment quotes the call site, the huskar block and both id names
# verbatim, so an identity strip_comments would let the COMMENT satisfy the
# structural assertions.
mutant caught "M13 strip_comments becomes the identity"              "$SWEEP" m13

# --- M14: the anti-vacuum walk goes blind -------------------------------------
mutant caught "M14 the per-frame stop rows stop being emitted"       "$SWEEP" m14

# --- M15: the pair column goes blind ------------------------------------------
# ⛔ M15 SURVIVED on its first run and the defect was the ASSERTION, not the
# mutant (evidence-discipline rule 2). The counter was a bare `if shipped and
# not arm then bump(...) end` asserted == 0 downstream -- so deleting the bump
# left a zero that reads exactly like a measured one: the GH #171 shape, landing
# on this lever's own pair column. Both halves now go through ONE bump and the
# test asserts the complement and the sum, so the shot lands.
anchor 1 "$SWEEP" "and 'pair_ne_arm_in_flipset'"
mutant caught "M15 the in-flipset pair counter stops being bumped"   "$SWEEP" m15

# --- C1: the control -----------------------------------------------------------
mutant survive "C1  comment-only edit inside the lever"              "$JMZ" c1

echo
printf '%d run / %d as declared / %d NOT as declared\n' "$nrun" "$ncaught" "$nbad"
if [ "$nbad" -eq 0 ]; then
    echo "STAND GREEN"
    exit 0
fi
echo "STAND RED"
exit 1

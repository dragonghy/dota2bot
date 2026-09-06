#!/usr/bin/env bash
# Mutation stand for tests/test_waitclar_mana_trip.lua (test_set.md §FP).
#
# WHAT IT IS FOR. ConsiderWaitInBaseToHeal (bots/mode_roam_generic.lua) is
# SHIPPED and ungated: it decides whether a bot TPs to its own base. Its
# condition is one `or` with two legs that disagree about supply ten to zero --
# the HP leg (trigger `J.GetHP(bot) < 0.25`) refuses the trip on TEN modifiers
# meaning "already recovering, or must not be moved" (two of them not even
# consumables), the MANA leg (trigger `J.GetMP(bot) < 0.25`) refuses on none. The
# 'waitclar' lever adds exactly one veto to the second leg: a ticking
# 'modifier_clarity_potion'. Domain: 1 frame of 1012, and it is the cleanest
# statement of the defect this corpus has -- a hero at FULL health being sent
# home for mana it is already drinking.
#
# The case has four halves and they forge differently:
#   (a) the BEHAVIOUR: a DRIVEN before/after of the shipped global on real
#       frames with one soak id toggled;
#   (b) ⭐ the DIRECTION claim. Appending a veto can only turn TRUE into FALSE,
#       so `flip_false_to_true` must be 0 -- and a counter whose content is all
#       zeros cannot tell "the direction holds" from "the tally never ran".
#       Both directions go through ONE tally() called twice with the legs
#       swapped; M8 and M8b attack that construction rather than the lever;
#   (c) ⭐ the LEG SPLIT, which is what makes the finding about anything at all:
#       5 of the 6 shipped TRUEs come through the leg this lever edits. M9
#       blinds that column;
#   (d) ⭐ the "THE TREE ALREADY KNEW" claim, i.e. condition (c) of the owner's
#       validation philosophy: three OTHER shipped sites in the item layer
#       refuse to act on a ticking clarity, one of them being the ungated
#       self-drink that gives this lever its CAST PATH -- the thing the refused
#       urn widening lacked. Those are parsed off live files (M10, M11), so
#       deleting one must go red rather than leaving the argument as prose.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2);
#   * ⭐ THE GATE STOPS BEING THE FIRST CONJUNCT (M3) -- reordered so
#     `bot:HasModifier` is evaluated before `J.IsSoakCandidate`. Behaviour is
#     unchanged in every armed configuration and the flip count does not move;
#     the only thing that catches it is the byte-identical-when-unarmed claim,
#     which is the claim the whole gated-fix discipline rests on;
#   * ⭐ THE TURBO CONJUNCT LEAVES (M4) -- nothing above this path asks, so
#     dropping it ships the lever into non-Turbo games. Invisible to every
#     corpus count (the fixtures are Turbo);
#   * THE MODIFIER DRIFTS (M5) -- reads the bottle's modifier instead, which no
#     frame in this leg's domain carries. The mutant that looks like a widening;
#   * ⭐ THE VETO MOVES TO THE OTHER LEG (M6) -- syntactically fine, reachable,
#     and about the wrong quantity: the HP leg is triggered by health and a
#     clarity restores none. This is the mutant that turns the lever into the
#     opinion this round REFUSED, so the suite must reject it;
#   * THE HP LEG'S OWN LIST SHRINKS (M7) -- the ten-modifier asymmetry is the
#     condition-(c) argument; a presence flag would stay green when one of the
#     ten is deleted (the 'stayurn' round's M6 survivor), so it is COUNTED;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M8, M8b) -- the direction tally stops
#     being called. `flip_false_to_true` then reads exactly as it does when 1012
#     frames were driven and none went the wrong way: the GH #171 shape;
#   * ⭐ THE LEG SPLIT GOES BLIND (M9) -- the sweep buckets every shipped TRUE
#     into one leg, so "the leg this lever edits is the leg that fires" becomes
#     unfalsifiable;
#   * ⭐ A CORROBORATING SITE IS DELETED (M10) and THE CAST PATH IS DELETED
#     (M11) -- condition (c) rests on those being LIVE code.
#     ⛔ M11 SURVIVED on its first run and the defect was the ASSERTION, not the
#     mutant (evidence-discipline rule 2, and it is the needle-uniqueness lesson
#     one level up): the test flagged the bare string `J.GetMP( bot ) < 0.4`,
#     which occurs TWICE in that file -- ~1879 in a different block and ~1905 in
#     the clarity self-drink -- so the flag stayed green while the site the
#     argument rests on was destroyed. The test now scopes to the
#     X.ConsiderItemDesire["item_clarity"] block (cut at a LINE-ANCHORED
#     `X.ConsiderItemDesire[`) and pins the multiplicity at 2;
#   * THE ARMING IS TOO WIDE (M12) -- the stub arms every id, so another lever
#     could move the answer while the flip is still credited here;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M13) -- strip_comments becomes
#     the identity, and this lever's comment quotes the modifier name, both leg
#     triggers and the file paths verbatim;
#   * THE ANTI-VACUUM COLUMN GOES BLIND (M14) -- the carrier walk stops emitting
#     rows, so "the corpus has no clarities" becomes indistinguishable from "it
#     has twelve and this function rejects eleven of them earlier";
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If
#     it is caught, something in the suite is satisfied by prose.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex
# (GH #550, GH #555). `perl -0pi -e "s///"` without /g rewrites the FIRST match,
# so an anchor occurring twice cuts a site the label does not name -- and then
# prints CAUGHT, indistinguishable from a mutant that worked. Every anchor below
# declares its expected count and `anchor` proves it on every run.
#
# ⛔ AND THE THIRD FORM OF THE SAME LESSON, found while building this stand: an
# anchor that is not WORD-anchored. The sibling sweep split Lua conditions on
# `if(.-)then` and read 3 of 6, because `HasModifier` CONTAINS the substring
# "if" (`Mod` + `if` + `ier`). Nothing went red; the number was simply wrong.
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
#   bash tools/agent/mutstand_waitclar.sh
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

ROAM=bots/mode_roam_generic.lua
SWEEP=tests/_waitclar_sweep.lua
AIUG=bots/ability_item_usage_generic.lua
TEST=waitclar

TMP=$(mktemp -d)
nrun=0; ncaught=0; nbad=0; nunmeas=0
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

# The gate, exactly as it sits in the file (THREE tabs, then two four-tab
# continuation lines).  Read with cat -A before it was written down: the first
# version of this stand declared four and every anchor answered `occurs 0`.
GATE=$'\t\t\tand not (J.IsSoakCandidate(\'waitclar\')\n\t\t\t\tand J.IsModeTurbo()\n\t\t\t\tand bot:HasModifier(\'modifier_clarity_potion\'))\n'
URNLINE=$'\t\t\tand not bot:HasModifier(\'modifier_item_urn_heal\'))\n'
ORACLE=$'\t\t\tand not bot:HasModifier(\'modifier_oracle_purifying_flames\')\n'

# ⛔ Every mutant is a SHELL FUNCTION that names the target file itself.  A bare
# `perl -0pi -e '...'` passed through "$@" reads STDIN, edits nothing, and the
# stand prints NO-OP for all sixteen -- paid for once on this very file.
# Delimiters are s{}{} because half of these needles contain `/`.

m1()  { perl -0pi -e "\$g=\$ENV{GATE}; s{\Q\$g\E}{}" "$ROAM"; }
m2()  { perl -0pi -e "s{and not \\(J\\.IsSoakCandidate\\('waitclar'\\)}{and (J.IsSoakCandidate('waitclar')}" "$ROAM"; }
m3()  { perl -0pi -e "\$g=\$ENV{GATE}; \$n=\"\\t\\t\\tand not (bot:HasModifier('modifier_clarity_potion')\\n\\t\\t\\t\\tand J.IsModeTurbo()\\n\\t\\t\\t\\tand J.IsSoakCandidate('waitclar'))\\n\"; s{\Q\$g\E}{\$n}" "$ROAM"; }
m4()  { perl -0pi -e "s{\\t\\t\\t\\tand J\\.IsModeTurbo\\(\\)\\n}{}" "$ROAM"; }
m5()  { perl -0pi -e "s{and bot:HasModifier\\('modifier_clarity_potion'\\)\\)}{and bot:HasModifier('modifier_bottle_regeneration'))}" "$ROAM"; }
m6()  { perl -0pi -e "\$g=\$ENV{GATE}; \$u=\$ENV{URNLINE}; \$n=\"\\t\\t\\tand not bot:HasModifier('modifier_item_urn_heal')\\n\\t\\t\\tand not (J.IsSoakCandidate('waitclar')\\n\\t\\t\\t\\tand J.IsModeTurbo()\\n\\t\\t\\t\\tand bot:HasModifier('modifier_clarity_potion')))\\n\"; s{\Q\$g\E}{}; s{\Q\$u\E}{\$n}" "$ROAM"; }
m7()  { perl -0pi -e "\$o=\$ENV{ORACLE}; s{\Q\$o\E}{}" "$ROAM"; }
m8()  { perl -0pi -e "s{tally\\(shipped, arm, 'flips', 'flip_false_to_true'\\)}{local _ = shipped}" "$SWEEP"; }
m8b() { perl -0pi -e "s{tally\\(arm, shipped, 'flips_swapped', 'flip_false_to_true_swapped'\\)}{local _ = arm}" "$SWEEP"; }
m9()  { perl -0pi -e "s{if nHP < HP_TRIG then bump\\('wait_hp_leg'\\)}{if false then bump('wait_hp_leg')}" "$SWEEP"; }
m10() { perl -0pi -e "s{\\t\\t\\tand not bot:HasModifier\\( \"modifier_clarity_potion\" \\)\\n}{}" "$AIUG"; }
m11() { perl -0pi -e "s{\\tif J\\.GetMP\\( bot \\) < 0\\.4}{\\tif J.GetMP( bot ) < 0.0}" "$AIUG"; }
m12() { perl -0pi -e "s{return armed and sId == 'waitclar'}{return armed}" "$SWEEP"; }
m13() { perl -0pi -e "s{if s == nil then return nil end\n    return .*\n}{if s == nil then return nil end\n    return s\n}" "$SWEEP"; }
m14() { perl -0pi -e "s{if bClar then\\n\\s+bump\\('clar_carriers'\\)}{if false then\n                            bump('clar_carriers')}" "$SWEEP"; }
c1()  { perl -0pi -e "s{-- \\[waitclar / owner priority P2, 2026-09-06\\] The leg above this}{-- [waitclar] (control edit, no code touched)}" "$ROAM"; }

export GATE URNLINE ORACLE

# --- M1, M2: the lever leaves, or lands inverted -----------------------------
anchor 1 "$ROAM" "$GATE"
mutant caught "M1  the gate block is deleted outright"               "$ROAM" m1
mutant caught "M2  the veto is inverted (fires when NOT drinking)"   "$ROAM" m2

# --- M3: the gate stops short-circuiting --------------------------------------
# Behaviourally identical in every armed configuration; what it breaks is the
# claim that un-armed the engine call below the gate is never evaluated -- the
# claim the whole gated-fix discipline rests on.
mutant caught "M3  gate reordered behind the engine call"            "$ROAM" m3

# --- M4: the turbo conjunct leaves --------------------------------------------
# Nothing above this path asks, so this ships the lever into every game mode.
# Invisible to every corpus count (the fixtures are all Turbo).
mutant caught "M4  the explicit J.IsModeTurbo() conjunct is dropped" "$ROAM" m4

# --- M5: the modifier drifts ---------------------------------------------------
mutant caught "M5  reads the bottle's modifier, not the clarity"     "$ROAM" m5

# --- M6: the veto moves to the OTHER leg --------------------------------------
# The HP leg is triggered by health and a clarity restores none: this is the
# mutant that turns the lever into the opinion this round priced and REFUSED.
anchor 1 "$ROAM" "$URNLINE"
mutant caught "M6  the veto is moved onto the HP leg (wrong量)"      "$ROAM" m6

# --- M7: the HP leg's ten-modifier list shrinks -------------------------------
# The asymmetry IS the condition-(c) argument, and it is a COUNT: a presence
# flag reads the same whether that list has ten entries or nine.
anchor 1 "$ROAM" "$ORACLE"
mutant caught "M7  one of the HP leg's ten vetoes is deleted"        "$ROAM" m7

# --- M8, M8b: a zero that was never measured ----------------------------------
anchor 1 "$SWEEP" "tally(shipped, arm, 'flips', 'flip_false_to_true')"
mutant caught "M8  the real direction tally stops being called"      "$SWEEP" m8
anchor 1 "$SWEEP" "tally(arm, shipped, 'flips_swapped', 'flip_false_to_true_swapped')"
mutant caught "M8b the SWAPPED tally stops being called"             "$SWEEP" m8b

# --- M9: the leg split goes blind ---------------------------------------------
anchor 1 "$SWEEP" "if nHP < HP_TRIG then bump('wait_hp_leg')"
mutant caught "M9  every shipped TRUE is bucketed into one leg"      "$SWEEP" m9

# --- M10, M11: condition (c) rests on LIVE code -------------------------------
# ⛔ THREE sites match the bare needle and they do NOT share an indent: two are
# the home-TP branches (three tabs) and the third is the self-drink refusal (two
# tabs).  The count that the argument rests on is 3; the mutant must cut exactly
# one, so its needle carries the three-tab indent and is declared as 2.
anchor 3 "$AIUG" 'and not bot:HasModifier( "modifier_clarity_potion" )'
anchor 2 "$AIUG" $'\t\t\tand not bot:HasModifier( "modifier_clarity_potion" )\n'
mutant caught "M10 one item-layer clarity refusal is deleted"        "$AIUG" m10
anchor 1 "$AIUG" $'\tif J.GetMP( bot ) < 0.4'
mutant caught "M11 the ungated self-drink (the CAST PATH) is broken" "$AIUG" m11

# --- M12: the arming is too wide ----------------------------------------------
anchor 1 "$SWEEP" "return armed and sId == 'waitclar'"
mutant caught "M12 the sweep's stub arms every id, not one"          "$SWEEP" m12

# --- M13: the instrument reads prose instead of code --------------------------
# The needle is the two-line body, not the gsub expression: the first version
# escaped `%-%-[^\n]*` into a perl pattern and matched nothing, and the stand
# printed NO-OP -- which is the third bucket doing its job, not a pass.
anchor 1 "$SWEEP" "    if s == nil then return nil end"
mutant caught "M13 strip_comments becomes the identity"              "$SWEEP" m13

# --- M14: the anti-vacuum column goes blind -----------------------------------
anchor 1 "$SWEEP" "                        if bClar then"
mutant caught "M14 the carrier walk stops emitting rows"             "$SWEEP" m14

# --- C1: the control ----------------------------------------------------------
anchor 1 "$ROAM" "-- [waitclar / owner priority P2, 2026-09-06] The leg above this"
mutant survive "C1  comment-only edit inside the lever"              "$ROAM" c1

echo
if [ "$nbad" -eq 0 ]; then
    echo "STAND GREEN -- $nrun mutant(s), all landed as declared ($ncaught as expected, $nunmeas declared-unmeasurable)."
    exit 0
fi
echo "STAND RED -- $nrun mutant(s), $nbad unexpected."
exit 1

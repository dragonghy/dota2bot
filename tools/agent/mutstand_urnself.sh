#!/usr/bin/env bash
# Mutation stand for tests/test_urnself_self_patient.lua (test_set.md §FM).
#
# WHAT IT IS FOR. This round appends the SELF branch that
# X.ConsiderItemDesire["item_urn_of_shadows"] does not have. Its patient loop is
# `bot:GetNearbyHeroes(...)`, which does not return the caller, so the urn -- 400
# health over 8 seconds, self-castable -- is never pressed by the hero holding
# it. The sibling entry in the same table for the same 400 health,
# X.ConsiderItemDesire["item_flask"], has BOTH branches plus three ids of
# arbitration. The lever is one gated block on 'urnself', worth 4 casts on a
# 1012-frame corpus.
#
# The case has three halves and they forge differently:
#   (a) the BEHAVIOUR: an end-to-end DRIVEN before/after -- the shipped
#       `_G.ItemUsageThink` on a real frame, reading the recorded engine action
#       -- with one soak id toggled;
#   (b) ⭐ the TWO-COLUMN construction. This entry's own first line is
#       `hItem:GetCurrentCharges() == 0 -> DESIRE_NONE`, and charges are
#       per-frame runtime state no .dem carries, so through the mock every column
#       is 0. The sweep drives the corpus twice (charges 0 and 1) and the suite
#       asserts BOTH, precisely so the zero cannot be read as "the lever does
#       nothing". Mutants M9-M11 attack that construction rather than the lever;
#   (c) the PROVENANCE claim -- every conjunct is quoted from the ally loop
#       directly above rather than tuned here, so the quotation must be proved
#       live in BOTH directions: the copy drifting (M6) and the original moving
#       (M7) must each go red.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- the block is deleted, or the gate
#     lands negated so shipped and armed swap;
#   * ⭐ THE APPEND BECOMES AN INSERT (M3) -- the self block moves ABOVE the ally
#     branch's return. Every cast count for the self-only domain is unchanged,
#     and what dies is the property the lever's whole safety argument rests on:
#     "it fires only where no ally qualified" is CONTROL FLOW, and above the
#     return it silently becomes an arbitration change that pre-empts allies;
#   * ⭐ THE GATE STOPS BEING FIRST (M4) -- behaviourally identical on both legs,
#     and it destroys the reason "un-armed this is byte-identical" is a fact
#     rather than a sentence. The mutant that most looks like a tidy-up;
#   * TURBO LEAKS (M5) -- the turbo conjunct leaves. Nothing above this entry
#     asks it, so the gate would be live in normal mode;
#   * THE QUOTATION GOES STALE (M6, M7) -- the copied floor drifts, or the ally
#     loop's own floor moves and leaves the copy behind;
#   * THE DANGER CLAUSE LEAVES (M8) -- the empty-enemy-list conjunct goes, so the
#     bot self-heals in a fight;
#   * ⭐ THE TWO-COLUMN CONSTRUCTION COLLAPSES (M9) -- the charge override stops
#     taking, so the c1 column reads the c0 column's zero. The shape this file
#     exists to make unpublishable;
#   * THE TOGGLE STOPS TOGGLING (M10) -- the armed leg is driven disarmed
#     (gain -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction);
#   * THE ARMING IS TOO WIDE (M11) -- the stub arms every id, so a sibling lever
#     could move the answer while the gain is still credited here;
#   * THE TWO ROUTES STOP BEING TWO (M12) -- the mirrored prefix walk stops
#     asking the health floor, so it and the driven column measure different sets;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M13, M13b) -- the direction tally stops
#     being called. `loss` then reads exactly as it does when 81 frames were
#     driven and none went the wrong way: the GH #171 shape. The swapped call is
#     what makes the zero falsifiable, so removing IT must also go red;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M14) -- strip_comments becomes
#     the identity, and this lever's comment quotes the sibling entry, the ids
#     and the constants verbatim;
#   * ⭐ THE BOUNDARY IS MOVED BY A COMMENT (M15) -- the sweep's block slice loses
#     its newline anchor. This is not hypothetical: the first run of this sweep
#     did exactly that, cut the urn entry at this lever's own comment (which
#     names X.ConsiderItemDesire["item_flask"]) and reported the self branch
#     ABSENT from a file containing it -- URN_NIDS 0, SELF_ASSIGNS_BOT 0,
#     SELF_AFTER_ALLY_RETURN 0, three facts reading as if the lever were never
#     written;
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If
#     it is caught, something in the suite is satisfied by prose.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex
# (GH #550, GH #555). `perl -0pi -e "s///"` without /g rewrites the FIRST match,
# so an anchor occurring twice cuts a site the label does not name -- and then
# prints CAUGHT, indistinguishable from a mutant that worked. Two needles here
# are deliberately multi-line for that reason: `hEffectTarget = bot` is a PREFIX
# of the attack branch's `hEffectTarget = botTarget` twelve lines up, and the
# three heal-modifier refusals appear once in the ally loop and once in the self
# block by construction. Every anchor declares its expected count and `anchor`
# proves it on every run.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_urnself.sh
#
# ⚠️ DO NOT EDIT THIS FILE WHILE IT IS RUNNING. bash reads a script by BYTE
# OFFSET as it executes; inserting bytes ahead of the current offset misaligns
# every later read and the run is void (paid for on 2026-09-06, one whole stand
# re-run).
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AIUG=bots/ability_item_usage_generic.lua
SWEEP=tests/_urnself_sweep.lua
TEST=urnself

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

# want=caught (a real mutant), want=survive (a control), want=unmeasurable (a
# real mutant this corpus provably cannot catch, with the reason recorded at the
# call site). UNMEASURABLE is not a pass.
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
    elif [ "$want" = unmeasurable ]; then
        if [ "$rc" -eq 0 ]; then
            nunmeas=$((nunmeas + 1))
            printf 'UNMEASURABLE %-55s exit=%s  (declared; NOT a pass)\n' "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** re-classify as `caught` **\n' "$label" "$rc"
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

# --- M1, M2: the lever leaves, or lands inverted -----------------------------
anchor 1 "$AIUG" "		if J.IsSoakCandidate( 'urnself' )"
m1() { perl -0pi -e "s/\t\tif J\.IsSoakCandidate\( 'urnself' \)/\t\tif not J.IsSoakCandidate( 'urnself' )/" "$AIUG"; }
mutant caught "M1 the gate lands negated (shipped and armed legs swap)" "$AIUG" m1

# The whole block, anchored on its LAST two statements plus the assignment --
# `hEffectTarget = bot` alone is a prefix of `hEffectTarget = botTarget`.
anchor 1 "$AIUG" "			and #hNearbyEnemyHeroList == 0
		then
			hEffectTarget = bot
"
m2() { perl -0pi -e "s/\t\tif J\.IsSoakCandidate\( 'urnself' \)\n(\t\t\tand [^\n]*\n)+\t\tthen\n\t\t\thEffectTarget = bot\n\t\t\tsCastMotive = '治疗:'\.\.J\.Chat\.GetNormName\( hEffectTarget \)\n\t\t\treturn BOT_ACTION_DESIRE_HIGH, hEffectTarget, sCastType, sCastMotive\n\t\tend\n//" "$AIUG"; }
mutant caught "M2 the self branch is deleted outright" "$AIUG" m2

# --- M3: ⭐ the append becomes an insert --------------------------------------
# Moved ABOVE the ally branch's return, the self block pre-empts a qualifying
# ally. On the 4 self-only frames nothing moves -- no ally qualified there -- so
# every cast count this suite reads from the gain set is UNCHANGED. What changes
# is that the lever is now an arbitration decision, the one thing its comment
# says it does not make, and the 2 with-ally frames flip owner.
# ⛔ The ally-return block is BYTE-IDENTICAL for six lines in the salve entry
# 1,400 lines up; only the SEVENTH line differs (`\tend` there, a blank line
# here).  So the needle runs one line past the block.  The first run of this
# stand anchored on a `return ...` line that does not exist as written and the
# anchor check said so.
anchor 1 "$AIUG" "		if( hNeedHealAlly ~= nil )
		then
			hEffectTarget = hNeedHealAlly
			sCastMotive = '治疗:'..J.Chat.GetNormName( hEffectTarget )
			return BOT_ACTION_DESIRE_HIGH, hEffectTarget, sCastType, sCastMotive
		end

"
m3() { perl -0pi -e "s/\t\tif\( hNeedHealAlly ~= nil \)\n\t\tthen\n\t\t\thEffectTarget = hNeedHealAlly\n\t\t\tsCastMotive = '治疗:'\.\.J\.Chat\.GetNormName\( hEffectTarget \)\n\t\t\treturn BOT_ACTION_DESIRE_HIGH, hEffectTarget, sCastType, sCastMotive\n\t\tend\n\n/\n/" "$AIUG"; }
mutant caught "M3 the ally return is removed (append becomes arbitration)" "$AIUG" m3

# --- M4: ⭐ the gate stops being the FIRST conjunct ---------------------------
# Behaviourally identical on BOTH legs, so no cast count moves. What dies is the
# reason "un-armed, shipped behaviour is byte-identical" is a fact: with the
# engine reads first, every frame of every shipped game pays for them.
m4() { perl -0pi -e "s/\t\tif J\.IsSoakCandidate\( 'urnself' \)\n\t\t\tand J\.IsModeTurbo\(\)\n/\t\tif J.IsModeTurbo()\n\t\t\tand J.IsSoakCandidate( 'urnself' )\n/" "$AIUG"; }
mutant caught "M4 the gate is no longer the first conjunct (inertness dies)" "$AIUG" m4

# --- M5: turbo leaks ---------------------------------------------------------
# Unlike J.ShouldStayAndRegen, nothing above this entry asks IsModeTurbo, so
# dropping it makes the gate live in normal mode -- the charter's turbo-only rule.
m5() { perl -0pi -e "s/\t\t\tand J\.IsModeTurbo\(\)\n//" "$AIUG"; }
mutant caught "M5 the turbo conjunct leaves (gate leaks into normal mode)" "$AIUG" m5

# --- M6, M7: the provenance claim, both directions ---------------------------
# The lever's own copy of the missing-health floor drifts. Anchored on the
# assignment that follows it, because the same comparison exists in the ally loop
# spelled with `npcAlly`.
anchor 1 "$AIUG" "			and bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > 450"
m6() { perl -0pi -e "s/\t\t\tand bot:OriginalGetMaxHealth\(\) - bot:OriginalGetHealth\(\) > 450/\t\t\tand bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > 250/" "$AIUG"; }
mutant caught "M6 the lever's floor drifts from the ally loop's 450" "$AIUG" m6

# ...and the OWNING constant moves instead, which leaves this lever untouched and
# still passing its behaviour tests while the finding it is named after ("every
# conjunct is the ally loop's own") is no longer true.
# ⛔ THE GH #550 TRAP, CAUGHT LIVE ON THIS STAND'S FIRST RUN. The single line
# `and npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > 450` occurs
# TWICE in this file -- the salve entry's ally loop has the identical clause --
# so `perl s///` without /g rewrote the SALVE, left the urn's 450 untouched, and
# the mutant printed SURVIVED. The `anchor` line is what said why; without it the
# survival would have been read as a hole in the test. Pinned with the following
# line instead, which carries a trailing space in the urn's copy and none in the
# salve's -- an invisible difference doing load-bearing work, which is exactly
# why the count is asserted rather than eyeballed.
# NOTE the quoting: $'\n' (ANSI-C), never $(printf '\n') -- command
# substitution STRIPS trailing newlines, so the latter expands to the empty
# string and the needle silently collapses to one line and counts 0.
anchor 1 "$AIUG" "				and npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > 450"$'\n'"				and #hNearbyEnemyHeroList == 0 "$'\n'
m7() { perl -0pi -e "s/\t\t\t\tand npcAlly:OriginalGetMaxHealth\(\) - npcAlly:OriginalGetHealth\(\) > 450\n\t\t\t\tand #hNearbyEnemyHeroList == 0 \n/\t\t\t\tand npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > 700\n\t\t\t\tand #hNearbyEnemyHeroList == 0 \n/" "$AIUG"; }
mutant caught "M7 the ALLY loop's own 450 moves (the quotation goes stale)" "$AIUG" m7

# --- M8: the danger clause leaves --------------------------------------------
m8() { perl -0pi -e "s/\t\t\tand #hNearbyEnemyHeroList == 0\n\t\tthen\n\t\t\thEffectTarget = bot/\t\tthen\n\t\t\thEffectTarget = bot/" "$AIUG"; }
mutant caught "M8 the empty-enemy-list clause leaves (self-heals in a fight)" "$AIUG" m8

# --- M9: ⭐ the two-column construction collapses -----------------------------
anchor 1 "$SWEEP" "            h.GetCurrentCharges = function() return nCharges end"
m9() { perl -0pi -e "s/            h\.GetCurrentCharges = function\(\) return nCharges end/            h.GetCurrentCharges = function() return 0 end/" "$SWEEP"; }
mutant caught "M9 the charge override stops taking (c1 reads c0's zero)" "$SWEEP" m9

# --- M10: the toggle stops toggling ------------------------------------------
# gain -> 0, i.e. "tested, no effect": the safe-looking direction.
anchor 1 "$SWEEP" "    J.IsSoakCandidate = function(sId) return armed and sId == 'urnself' end"
m10() { perl -0pi -e "s/    J\.IsSoakCandidate = function\(sId\) return armed and sId == 'urnself' end/    J.IsSoakCandidate = function(sId) return false end/" "$SWEEP"; }
mutant caught "M10 the armed leg is driven disarmed (gain -> 0)" "$SWEEP" m10

# --- M11: the arming is too wide ---------------------------------------------
m11() { perl -0pi -e "s/    J\.IsSoakCandidate = function\(sId\) return armed and sId == 'urnself' end/    J.IsSoakCandidate = function(sId) return armed end/" "$SWEEP"; }
mutant caught "M11 the stub arms EVERY id (gain credited to the wrong lever)" "$SWEEP" m11

# --- M12: the two routes stop being two --------------------------------------
anchor 1 "$SWEEP" "                        local c1 = nMiss > MISSING"
m12() { perl -0pi -e "s/                        local c1 = nMiss > MISSING/                        local c1 = true/" "$SWEEP"; }
mutant caught "M12 the mirrored walk drops the health floor (routes diverge)" "$SWEEP" m12

# --- M13, M13b: ⭐ a zero that was never measured ------------------------------
# `loss` must be 0. Its content is all zeros on this corpus, so deleting the real
# call leaves it reading exactly as a measured 0 -- unless the SWAPPED call is
# what makes it falsifiable. Both removals must go red, and that is the whole
# construction: the branch asserted to be 0 is the branch that must report the
# whole domain when the legs are exchanged.
anchor 1 "$SWEEP" "                        tally(s1, a1, 'loss', 'gain')"
m13() { perl -0pi -e "s/                        tally\(s1, a1, 'loss', 'gain'\)\n//" "$SWEEP"; }
mutant caught "M13 the real direction tally is removed" "$SWEEP" m13

anchor 1 "$SWEEP" "                        tally(a1, s1, 'loss_swapped', 'gain_swapped')"
m13b() { perl -0pi -e "s/                        tally\(a1, s1, 'loss_swapped', 'gain_swapped'\)\n//" "$SWEEP"; }
mutant caught "M13b the SWAPPED tally is removed (the 0 becomes vacuous)" "$SWEEP" m13b

# --- M14: the instrument reads prose instead of code -------------------------
anchor 1 "$SWEEP" "    return (s:gsub('%-%-[^\\n]*', ''))"
m14() { perl -0pi -e "s/    return \(s:gsub\('%-%-\[\^\\\\n\]\*', ''\)\)/    return s/" "$SWEEP"; }
mutant caught "M14 strip_comments becomes the identity (prose satisfies code)" "$SWEEP" m14

# --- M15: ⭐ the boundary is moved by a comment --------------------------------
# Not hypothetical: this is what the first run of this sweep actually did.
anchor 1 "$SWEEP" "    local stop = src:find('\\nX.ConsiderItemDesire[', at + 10, true) or #src"
m15() { perl -0pi -e "s/    local stop = src:find\('\\\\nX\.ConsiderItemDesire\[', at \+ 10, true\) or #src/    local stop = src:find('X.ConsiderItemDesire[', at + 10, true) or #src/" "$SWEEP"; }
mutant caught "M15 the block slice loses its newline anchor (a comment cuts it)" "$SWEEP" m15

# --- C1: the control ---------------------------------------------------------
anchor 1 "$AIUG" "		-- [urnself / owner priority P2, 2026-09-06] The SELF branch this consider"
c1() { perl -0pi -e "s/\t\t-- \[urnself \/ owner priority P2, 2026-09-06\] The SELF branch this consider/\t\t-- [urnself \/ owner priority P2, 2026-09-06] THE SELF BRANCH this consider/" "$AIUG"; }
mutant survive "C1 comment-only edit inside the lever" "$AIUG" c1

printf '\nSTAND: %d mutants run, %d landed as declared, %d unmeasurable, %d unexpected\n' \
    "$nrun" "$ncaught" "$nunmeas" "$nbad"
if [ "$nbad" -eq 0 ] && [ "$nunmeas" -eq 0 ]; then
    echo 'STAND GREEN'
    exit 0
fi
if [ "$nbad" -eq 0 ]; then
    echo 'STAND AMBER -- every mutant landed as declared, but some are UNMEASURABLE'
    exit 0
fi
echo 'STAND RED'
exit 1

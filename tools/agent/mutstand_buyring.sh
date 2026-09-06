#!/usr/bin/env bash
# Mutation stand for tests/test_buyring_purchase_domain.lua (test_set.md §FJ).
#
# WHAT IT IS FOR. This round adds a FOURTH gated arm to a shipped purchase site,
# and the lever is ONE CONSTANT that the same family answers twice. Over the same
# health band [0.18, 0.75], the PROMOTED hold half (J.ShouldStayAndRegen, live in
# every turbo game) calls a bot un-chased at 1200, while the supply half
# (J.IsFieldRegenSituation and all three buy arms) requires 1600 -- a number whose
# own comment says it is "the ring THE GUARDED BRANCH ITSELF MEASURES", i.e. a
# hold-side justification. The buy arms cancel no branch. This lever answers
# exactly the frames in that 1200-1600 gap: 10 frames of a 1012-frame corpus.
#
# The case has three halves and they forge differently:
#   (a) the behaviour: a driven before/after on real frames plus a 1012-frame
#       domain price, both legs from the same shipped call-site predicate QUARTET
#       with one soak id toggled;
#   (b) the DISJOINTNESS claim -- carried by the INVERSION, not by an HP split.
#       `nRing == 0 then return false` against the siblings' `> 0 then return
#       false` is the whole of it: un-invert that one comparison and the four arms
#       start overlapping while every other number still looks plausible;
#   (c) the PROVENANCE claim -- 1200 and 1600 are quoted from two SHIPPED
#       functions, not tuned here, so both quotations must be proven live in both
#       directions. Move the quoted number and the lever is untouched, still
#       gated, still passing its behaviour tests, and the FINDING is about
#       something else.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- the gate lands un-negated, or the
#     wiring is removed from the purchase site so the predicate exists and decides
#     nothing;
#   * ⭐ THE INVERSION GOES (M3, M4) -- the clause this lever IS gets un-inverted
#     or deleted. Both leave a lever that still fires and still buys salves; what
#     they destroy is the property that makes any of its frames attributable;
#   * ⭐ THE PROMOTED RING STOPS BEING A VETO (M5, M6) -- the 1200 clause is
#     defanged, or widened until this lever's own domain is empty. M5 is the one
#     that would ship the behaviour into a chase, which is the frame set the
#     condition-(c) argument explicitly excludes;
#   * THE BAND STOPS BEING THE PROMOTED ONE (M7, M8);
#   * ⭐ THE PREMISE MOVES (M9, M10) -- the shipped functions this lever quotes
#     are edited instead. M10 is the sharpest: lower the SHARED predicate's 1600
#     to 1200 and the gap this lever exists for is gone while it keeps firing;
#   * THE PULLCAD TRAP, BOTH FORMS (M11, M12) -- a second soak id joins the gate's
#     condition; or the un-copied 'fieldcreep' veto is copied in, which reads as
#     tidying and freezes that clause FALSE the day that id is promoted;
#   * ANOTHER LEVER'S INVARIANT (M13) -- the attribution scan is routed through
#     J.HasNearbyHeroDamager, which is strictly tidier code and breaks the
#     one-caller count tests/test_stayattr_global_ult.lua asserts. Recorded as a
#     mutant because "tidier" is exactly how it would arrive;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M14) -- strip_comments leaves
#     the sweep, and this lever's comment names IsSoakCandidate, three sibling
#     ids and every constant while explaining them;
#   * THE TOGGLE STOPS TOGGLING (M15) -- the armed leg is driven disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction);
#   * THE ARMING IS TOO WIDE (M16) -- the stub arms every candidate, so a sibling
#     can move the answer while the flip is still attributed here;
#   * THE TWO ROUTES STOP BEING TWO (M17) -- the independent prefix walk drops the
#     chase clause, so it and the driven count measure different populations;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M18) -- the disjointness probe stops
#     driving. All three overlap columns then read exactly as they do when the
#     probe ran over 1012 frames and found nothing: the GH #171 shape;
#   * THE LEVER IS SIMPLIFIED INTO THE TRAP IT AVOIDS (M19) -- someone folds the
#     copied clauses back into a call to J.IsFieldRegenSituation. Strictly
#     shorter, passes luacheck, and re-imposes the very 1600 this lever exists to
#     narrow: the lever becomes a no-op that still passes its own gate;
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If it
#     is caught, something in the suite is being satisfied by prose.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex.
# GH #550, and this round's own experience of it: the first draft of this lever
# spelled its band as `if nHP < 0.18 then return false end` / `if nHP > 0.75 then
# return false end`, which is BYTE IDENTICAL to the two lines
# mutstand_buytower.sh anchors M5 and M6 on -- so landing it would have broken a
# sibling stand's anchor check for a lever it has nothing to say about. The band
# is a single high-first statement for that reason. The same round also had to
# re-anchor that sibling stand's M2, whose needle ended at the closing paren of a
# THREE-arm OR and therefore matched zero times once a fourth arm joined.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_buyring.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
#
# SLOW ON PURPOSE (~46s per mutant): every mutant re-runs a 109-fixture,
# 1012-frame sweep in which the decision is driven six times per frame. The sweep
# is the thing under test; running it once and reusing the output would test
# nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
PURCHASE=bots/item_purchase_generic.lua
SWEEP=tests/_buyring_sweep.lua
TEST=buyring_purchase

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

# ⛔ THE ANCHOR CHECK, and it runs BEFORE the mutant does. A `perl -0pi -e "s///"`
# without /g rewrites the FIRST match, so an anchor that occurs twice cuts a
# function the label does not name -- and then prints CAUGHT, which is
# indistinguishable from a mutant that worked (GH #550). Every anchor declares how
# many times it may occur, and a mismatch is a STAND failure, not a mutant result.
# The count is a literal substring count over the whole file: `grep -F -c` counts
# matching LINES and treats a multi-line needle as a list of alternatives, which
# is how the first version of this check reported 13133 occurrences of a two-line
# anchor that occurs once.
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
# call site), or want=equivalent (an edit that is provably a NO-OP on any corpus).
# Neither of the last two is a pass.
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
    elif [ "$want" = unmeasurable ] || [ "$want" = equivalent ]; then
        local word=UNMEASURABLE
        [ "$want" = equivalent ] && word=EQUIVALENT
        if [ "$rc" -eq 0 ]; then
            nunmeas=$((nunmeas + 1))
            printf '%-12s %-55s exit=%s  (declared; NOT a pass)\n' "$word" "$label" "$rc"
        else
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** re-classify as `caught` **\n' "$label" "$rc"
            echo "          ^ the suite can now witness this branch; the"
            echo "            $word note at the call site is out of date."
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
anchor 1 "$JMZ" "	if not J.IsSoakCandidate( 'buyring' ) then return false end"
m1() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buyring' \) then return false end/\tif J.IsSoakCandidate( 'buyring' ) then return false end/" "$JMZ"; }
mutant caught "M1 the gate lands negated (shipped and armed legs swap)" "$JMZ" m1

# The predicate survives, fully tested, and decides nothing: the purchase site
# stops consulting it. Every [frame] test drives the SITE, so this is the mutant
# that separates "the helper is right" from "the helper is wired".
anchor 1 "$PURCHASE" "or J.ShouldFieldBuyRegenRing(bot)"
m2() { perl -0pi -e "s/ or J\.ShouldFieldBuyRegenRing\(bot\)//" "$PURCHASE"; }
mutant caught "M2 the fourth OR arm is removed from the purchase site" "$PURCHASE" m2

# --- M3, M4: ⭐ the inversion goes --------------------------------------------
anchor 1 "$JMZ" "	if nRing == 0 then return false end"
m3() { perl -0pi -e "s/\tif nRing == 0 then return false end/\tif nRing > 0 then return false end/" "$JMZ"; }
mutant caught "M3 the 1600 ring is un-inverted (domains overlap)" "$JMZ" m3

# Deleted outright, the tidier-looking version of the same defect: the lever now
# answers over every clean frame its siblings already own.
m4() { perl -0pi -e "s/\tlocal nRing = #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \)\n\tif nRing == 0 then return false end\n\n//" "$JMZ"; }
mutant caught "M4 the inverted ring clause is deleted entirely" "$JMZ" m4

# --- M5, M6: ⭐ the promoted ring stops being a veto ---------------------------
# The clause this lever keeps UNCHANGED, and the one whose removal would ship the
# behaviour into exactly the frames condition (c) excludes: a hero in contact.
anchor 1 "$JMZ" "	if nChasers > 0 then return false end"
m5() { perl -0pi -e "s/\tif nChasers > 0 then return false end/\tif nChasers < 0 then return false end/" "$JMZ"; }
mutant caught "M5 the promoted 1200 ring stops vetoing (fires under a chase)" "$JMZ" m5

# Widened to the inherited number, which makes the two clauses contradict and the
# domain empty -- the "tested, no effect" reading a single-arm wave would report.
anchor 1 "$JMZ" "	local nChasers = #J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE )"
m6() { perl -0pi -e "s/\tlocal nChasers = #J\.GetNearbyHeroes\( bot, 1200, true, BOT_MODE_NONE \)/\tlocal nChasers = #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE )/" "$JMZ"; }
mutant caught "M6 the chase ring is widened to 1600 (the gap closes)" "$JMZ" m6

# --- M7, M8: the band stops being the promoted one ---------------------------
anchor 1 "$JMZ" "	if nHP > 0.75 or nHP < 0.18 then return false end"
m7() { perl -0pi -e "s/\tif nHP > 0\.75 or nHP < 0\.18 then return false end/\tif nHP > 0.75 or nHP < 0.05 then return false end/" "$JMZ"; }
mutant caught "M7 the lever's floor leaves the sibling's 0.18" "$JMZ" m7

m8() { perl -0pi -e "s/\tif nHP > 0\.75 or nHP < 0\.18 then return false end/\tif nHP > 1.0 or nHP < 0.18 then return false end/" "$JMZ"; }
mutant caught "M8 the lever's ceiling leaves the promoted veto's 0.75" "$JMZ" m8

# --- M9, M10: ⭐ the premise moves ---------------------------------------------
# The two rings are QUOTED from shipped functions. Move one of them and the lever
# is untouched, still gated, still passing its behavioural assertions -- and the
# finding it is named for has silently become a different one.
# ⚠️ BOTH ANCHORS BELOW WERE WRONG ON THIS STAND'S FIRST RUN, and the check said
# so before either mutant was believed. The bare ring lines are NOT unique: the
# 1200 one occurs twice in this file (J.ShouldStayAndRegen and J.IsWastefulItemTrip's
# neighbourhood) and the 1600 one FIVE times. `perl -0pi -e "s///"` without /g
# rewrites the FIRST match, so each was cutting one particular function by
# accident of position rather than by declaration -- the GH #550 shape, which
# prints CAUGHT either way. Both are now anchored on a two-line needle that
# occurs exactly once, and the needle names the function by its neighbour.
anchor 1 "$JMZ" "	if #J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE ) > 0 then return false end
	local bHasFlask = J.IsItemAvailable( 'item_flask' ) ~= nil"
m9() { perl -0pi -e "s/\tif #J\.GetNearbyHeroes\( bot, 1200, true, BOT_MODE_NONE \) > 0 then return false end\n\tlocal bHasFlask = J\.IsItemAvailable\( 'item_flask' \) ~= nil/\tif #J.GetNearbyHeroes( bot, 1500, true, BOT_MODE_NONE ) > 0 then return false end\n\tlocal bHasFlask = J.IsItemAvailable( 'item_flask' ) ~= nil/" "$JMZ"; }
mutant caught "M9 the PROMOTED function's own 1200 ring moves to 1500" "$JMZ" m9

# The sharpest of the pair: lower the SHARED predicate's ring to the promoted
# number and the gap this lever exists for is gone, while the lever keeps firing.
anchor 1 "$JMZ" "	-- Nobody in the ring the guarded branch itself measures (1600).
	if #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0 then return false end"
m10() { perl -0pi -e "s/\t-- Nobody in the ring the guarded branch itself measures \(1600\)\.\n\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end/\t-- Nobody in the ring the guarded branch itself measures (1600).\n\tif #J.GetNearbyHeroes( bot, 1200, true, BOT_MODE_NONE ) > 0 then return false end/" "$JMZ"; }
mutant caught "M10 the SHARED predicate's 1600 drops to 1200 (no gap left)" "$JMZ" m10

# --- M11, M12: the pullcad trap, both forms ----------------------------------
m11() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buyring' \) then return false end/\tif not ( J.IsSoakCandidate( 'buyring' ) and J.IsSoakCandidate( 'fieldbuy' ) ) then return false end/" "$JMZ"; }
mutant caught "M11 a second soak id joins the gate's condition" "$JMZ" m11

# Reads as tidying up an inconsistency between the four arms, and freezes the
# copied clause FALSE the day 'fieldcreep' is promoted.
anchor 1 "$JMZ" "	local nTowers = #bot:GetNearbyTowers( 1200, true )"
m12() { perl -0pi -e "s/\tlocal nTowers = #bot:GetNearbyTowers\( 1200, true \)/\tif J.IsSoakCandidate( 'fieldcreep' ) and bot:WasRecentlyDamagedByCreep( 3.0 ) then return false end\n\tlocal nTowers = #bot:GetNearbyTowers( 1200, true )/" "$JMZ"; }
mutant caught "M12 the un-copied 'fieldcreep' veto is copied in" "$JMZ" m12

# --- M13: another lever's invariant ------------------------------------------
# Strictly tidier: the helper exists, is a pure question about the world, and says
# exactly this. It also has a one-caller count asserted in another lever's file,
# so "tidier" here means turning that file red for a change it does not concern.
anchor 1 "$JMZ" "		local hDamagers = J.GetNearbyHeroes( bot, 3000, true, BOT_MODE_NONE )"
m13() { perl -0pi -e "s/\tif bot:WasRecentlyDamagedByAnyHero\( 3\.0 \) then\n\t\tlocal hDamagers = J\.GetNearbyHeroes\( bot, 3000, true, BOT_MODE_NONE \)\n\t\tfor _, hEnemy in pairs\( hDamagers \) do\n\t\t\tif J\.IsValidHero\( hEnemy \)\n\t\t\t\tand bot:WasRecentlyDamagedByHero\( hEnemy, 3\.0 \)\n\t\t\tthen\n\t\t\t\treturn false\n\t\t\tend\n\t\tend\n\tend/\tif J.HasNearbyHeroDamager( bot, 3000, 3.0 ) then return false end/" "$JMZ"; }
mutant caught "M13 the attribution scan is routed through the shared helper" "$JMZ" m13

# --- M14: the instrument reads prose instead of code -------------------------
anchor 1 "$SWEEP" "    return (s:gsub('%-%-[^\\n]*', ''))"
m14() { perl -0pi -e "s/    return \(s:gsub\('%-%-\[\^\\\\n\]\*', ''\)\)/    return s/" "$SWEEP"; }
mutant caught "M14 strip_comments becomes the identity (prose satisfies code)" "$SWEEP" m14

# --- M15, M16: the toggle stops toggling / arms too wide ---------------------
# The armed leg is driven DISARMED: flips -> 0, which reads as "tested, no
# effect" -- the safe-looking direction, and the one a wave would archive.
anchor 1 "$SWEEP" "                    local ok2, arm = pcall(pred)"
m15() { perl -0pi -e "s/                    local ok2, arm = pcall\(pred\)/                    armed = false\n                    local ok2, arm = pcall(pred)/" "$SWEEP"; }
mutant caught "M15 the armed leg is driven disarmed (flips -> 0)" "$SWEEP" m15

# ⚠️ RE-ANCHORED after this stand's second run said so: the bare line occurs TWICE
# in the sweep, and NOT because there are two copies of it -- the second is the
# stub RESTORED inside the disjointness probe at a deeper indent, and a needle
# indented 24 spaces is a SUBSTRING of the same line indented 28. That is a shape
# the "count the anchor" check catches and eyeballing does not: nothing in the file
# looks duplicated. The needle now carries the closing `end` at its own indent.
anchor 1 "$SWEEP" "                        return armed and sId == 'buyring'
                    end"
m16() { perl -0pi -e "s/                        return armed and sId == 'buyring'\n                    end/                        return armed\n                    end/" "$SWEEP"; }
mutant caught "M16 the stub arms every candidate at once" "$SWEEP" m16

# --- M17, M18: the two routes stop being two / a zero nobody measured --------
anchor 1 "$SWEEP" "                        and not bChase and bRingBusy and not bAttr and not bTower"
m17() { perl -0pi -e "s/                        and not bChase and bRingBusy and not bAttr and not bTower/                        and bRingBusy and not bAttr and not bTower/" "$SWEEP"; }
mutant caught "M17 the prefix walk drops the chase clause (routes disagree)" "$SWEEP" m17

anchor 1 "$SWEEP" "                            local okr, ringonly = pcall(J.ShouldFieldBuyRegenRing, bot)"
m18() { perl -0pi -e "s/                            local okr, ringonly = pcall\(J\.ShouldFieldBuyRegenRing, bot\)/                            local okr, ringonly = false, false/" "$SWEEP"; }
mutant caught "M18 the disjointness probe stops driving (an unmeasured zero)" "$SWEEP" m18

# --- M19: the lever is simplified into the trap it avoids --------------------
# Strictly shorter, passes luacheck, and re-imposes the very 1600 this lever
# exists to narrow -- a no-op that still passes its own gate.
m19() { perl -0pi -e "s/\tlocal nChasers = #J\.GetNearbyHeroes\( bot, 1200, true, BOT_MODE_NONE \)\n\tif nChasers > 0 then return false end/\tif not J.IsFieldRegenSituation( bot ) then return false end/" "$JMZ"; }
mutant caught "M19 the lever is folded back into a call to the shared predicate" "$JMZ" m19

# --- C1: the control ---------------------------------------------------------
anchor 1 "$JMZ" "	-- The tower clause, kept in its shipped direction so the ONLY thing this"
c1() { perl -0pi -e "s/\t-- The tower clause, kept in its shipped direction so the ONLY thing this/\t-- CONTROL EDIT: comment text only, no code touched./" "$JMZ"; }
mutant survive "C1 comment-only edit inside the lever" "$JMZ" c1

echo
printf 'STAND: %d mutants run, %d landed as declared, %d unmeasurable/equivalent, %d unexpected\n' \
    "$nrun" "$ncaught" "$nunmeas" "$nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND RED -- see the lines above"
    exit 1
fi
echo "STAND GREEN"
exit 0

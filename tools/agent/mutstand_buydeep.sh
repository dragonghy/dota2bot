#!/usr/bin/env bash
# Mutation stand for tests/test_buydeep_purchase_floor.lua.
#
# WHAT IT IS FOR. This round adds a FIFTH gated arm to a shipped purchase site,
# and the lever is the LAST FREE CLAUSE of one predicate: J.IsFieldRegenSituation's
# 0.18 floor. Three of that predicate's four clauses have already been answered by
# their own standalone arm ('buyband' the ceiling, 'buytower' the tower, 'buyring'
# the ring), each time because the clause carries a rationale written for the HOLD
# side. The floor's own comment says "below the floor the genuine escape retreat
# stands" -- an argument about not cancelling a retreat bid. A purchase cancels no
# bid. This arm answers the 6 corpus frames below that floor.
#
# The case has four halves and they forge differently:
#   (a) the behaviour: a driven before/after on real frames plus a 1021-frame
#       domain price, both legs from the same shipped call-site predicate QUINTET
#       with one soak id toggled;
#   (b) the DISJOINTNESS claim -- carried by the INVERSION, not by a band split.
#       All four siblings require `nHP >= 0.18`; this one requires `< 0.18`.
#       Un-invert that one comparison and the five arms start overlapping while
#       every other number still looks plausible;
#   (c) ⭐ the ABSENT BOTTOM EDGE. The decision-side lever in this same band
#       ('tpdeep') carries a 0.10 bottom because a 115-135 field sip cannot lift a
#       bot back over 0.18. A salve is 400, so the bottom is arithmetically absent
#       here -- and an absence is what a later round harmonises in without
#       noticing. Half this arm's domain (3 of 6) sits below 0.10, so the mutant
#       that adds the sibling's constant is caught twice over: structurally and on
#       a pinned frame;
#   (d) ⭐ the CORRECTION this round is named for. The charter handed this round
#       `stop_source 8` with a warning attached: 8 says "no supply", it does not
#       say "safe". Five of the eight are refused by clauses this arm KEEPS. The
#       sweep's split of the 8 is therefore load-bearing, and M20 is the mutant
#       that quietly turns it back into the wrong 8.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- the gate lands un-negated, or the
#     wiring is removed from the purchase site so the predicate exists and decides
#     nothing;
#   * ⭐ THE INVERSION GOES (M3, M4) -- the clause this lever IS gets un-inverted
#     or deleted. Both leave a lever that still fires and still buys salves; what
#     they destroy is the property that makes any of its frames attributable;
#   * ⭐ THE ABSENT BOTTOM EDGE IS "HARMONISED" IN (M5) -- the sibling's 0.10 is
#     copied over, which reads as making the two deep-band levers consistent and
#     silently discards half the domain;
#   * ⭐ ANCHOR UNIQUENESS IS TIDIED AWAY (M6) -- the inline floor becomes a
#     `local nHP` two-liner, which is byte-identical to the decision-side
#     sibling's band edge and makes mutstand_tpdeep.sh's M5 anchor AMBIGUOUS. The
#     cost lands in ANOTHER lever's stand, which is exactly why this one asserts
#     it (GH #550);
#   * A SECOND CLAUSE IS MOVED (M7, M8, M9) -- the ring is inverted or drifts from
#     its owner, the tower clause goes. Any of the three makes this two levers;
#   * ⭐ THE PREMISE MOVES (M10) -- the SHARED predicate's own floor is lowered
#     instead. The lever is untouched, still gated, still passing its behavioural
#     assertions, and the finding it is named for is gone -- plus three families
#     move on one arm (the 'lanefix' shape);
#   * THE PULLCAD TRAP, BOTH FORMS (M11, M12) -- a second soak id joins the gate's
#     condition; or the un-copied 'fieldcreep' veto is copied in, which reads as
#     tidying and freezes that clause FALSE the day that id is promoted;
#   * ANOTHER LEVER'S INVARIANT (M13) -- the attribution scan is routed through
#     J.HasNearbyHeroDamager, which is strictly tidier code and breaks the
#     one-caller count tests/test_stayattr_global_ult.lua asserts;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M14) -- strip_comments leaves
#     the sweep, and this lever's comment names IsSoakCandidate, four sibling ids
#     and every constant while explaining them;
#   * THE TOGGLE STOPS TOGGLING (M15) -- the armed leg is driven disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction);
#   * THE ARMING IS TOO WIDE (M16) -- the stub arms every candidate, so a sibling
#     can move the answer while the flip is still attributed here;
#   * THE TWO ROUTES STOP BEING TWO (M17) -- the independent prefix walk drops a
#     clause, so it and the driven count measure different populations;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M18) -- the disjointness probe stops
#     driving. All four overlap columns then read exactly as they do when the
#     probe ran over 1021 frames and found nothing: the GH #171 shape;
#   * THE LEVER IS SIMPLIFIED INTO THE TRAP IT AVOIDS (M19) -- someone folds the
#     copied clauses back into a call to J.IsFieldRegenSituation. Strictly
#     shorter, passes luacheck, and re-imposes the very 0.18 floor this lever
#     exists to invert: the lever becomes a no-op that still passes its own gate;
#   * ⭐ THE ROUND'S OWN CORRECTION IS UNDONE (M20) -- the sweep's split of the 8
#     stops asking the ring, so `stop_source_domain` reads 8 and the file reports
#     the number the charter warned about;
#   * ⭐ AN ORDER-FREE COLUMN BECOMES A PREFIX COLUMN (M21) -- `stop_source_attr_any`
#     starts respecting the walk order, so its 3 collapses to the prefix bucket's
#     0 and the file loses the only thing separating "attribution is silent" from
#     "attribution is filed under the ring";
#   * THE CONTROL (C1) -- a comment-only edit inside the lever must SURVIVE. If it
#     is caught, something in the suite is being satisfied by prose.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_buydeep.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
#
# SLOW ON PURPOSE (~40s per mutant): every mutant re-runs a 110-fixture,
# 1021-frame sweep in which the decision is driven seven times per frame. The
# sweep is the thing under test; running it once and reusing the output would test
# nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
PURCHASE=bots/item_purchase_generic.lua
SWEEP=tests/_buydeep_sweep.lua
TEST=buydeep_purchase

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
anchor 1 "$JMZ" "	if not J.IsSoakCandidate( 'buydeep' ) then return false end"
m1() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buydeep' \) then return false end/\tif J.IsSoakCandidate( 'buydeep' ) then return false end/" "$JMZ"; }
mutant caught "M1 the gate lands negated (shipped and armed legs swap)" "$JMZ" m1

# The predicate survives, fully tested, and decides nothing: the purchase site
# stops consulting it. Every [frame] test drives the SITE, so this is the mutant
# that separates "the helper is right" from "the helper is wired".
anchor 1 "$PURCHASE" "
		or J.ShouldFieldBuyRegenDeep(bot) )"
m2() { perl -0pi -e "s/\n\t\tor J\.ShouldFieldBuyRegenDeep\(bot\) \)/ \)/" "$PURCHASE"; }
mutant caught "M2 the fifth OR arm is removed from the purchase site" "$PURCHASE" m2

# --- M3, M4: ⭐ the inversion goes --------------------------------------------
anchor 1 "$JMZ" "	if J.GetHP( bot ) >= 0.18 then return false end"
m3() { perl -0pi -e "s/\tif J\.GetHP\( bot \) >= 0\.18 then return false end/\tif J.GetHP( bot ) < 0.18 then return false end/" "$JMZ"; }
mutant caught "M3 the floor is un-inverted (domains overlap, band empty)" "$JMZ" m3

# Deleted outright, the tidier-looking version of the same defect: the lever now
# answers over every clean frame its four siblings already own.
m4() { perl -0pi -e "s/\tif J\.GetHP\( bot \) >= 0\.18 then return false end\n\n//" "$JMZ"; }
mutant caught "M4 the inverted floor clause is deleted entirely" "$JMZ" m4

# --- M5: ⭐ the absent bottom edge is "harmonised" in --------------------------
# Reads as making the two deep-band levers consistent with each other. It
# discards HALF this arm's domain (3 of 6 frames sit below 0.10), and the reason
# it is wrong is arithmetic the sibling states in its own block: a field sip is
# 115-135 and cannot lift a bot back over 0.18; a salve is 400 and always can.
m5() { perl -0pi -e "s/\tif J\.GetHP\( bot \) >= 0\.18 then return false end/\tif J.GetHP( bot ) >= 0.18 then return false end\n\tif J.GetHP( bot ) < 0.10 then return false end/" "$JMZ"; }
mutant caught "M5 the sibling's 0.10 bottom is copied in (half the domain goes)" "$JMZ" m5

# --- M6: ⭐ anchor uniqueness is tidied away -----------------------------------
# Strictly more conventional: every sibling arm in this family reads its HP into a
# `local nHP` first. Doing it here produces a line BYTE-IDENTICAL to
# J.ShouldDeepSipNotTpRecover's band edge, which tools/agent/mutstand_tpdeep.sh
# anchors its M5 on -- and that stand treats an ambiguous anchor as a STAND
# failure. The cost of this edit is paid in another lever's stand, which is
# precisely why this one has to catch it here.
m6() { perl -0pi -e "s/\tif J\.GetHP\( bot \) >= 0\.18 then return false end/\tlocal nHP = J.GetHP( bot )\n\tif nHP >= 0.18 then return false end/" "$JMZ"; }
mutant caught "M6 the inline floor becomes a local (sibling anchor ambiguous)" "$JMZ" m6

# --- M7, M8, M9: a second clause is moved -------------------------------------
# Each of these makes the change TWO levers, and the disjointness argument names
# only the floor. The needles carry a neighbour line because the bare clauses
# occur six (ring) and several (tower) times in this file.
anchor 1 "$JMZ" "	if #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0 then return false end

	-- Attribution: recent hero damage counts only while its author is still in"
m7() { perl -0pi -e "s/\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end\n\n\t-- Attribution: recent hero damage counts only while its author is still in/\tif #J.GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) == 0 then return false end\n\n\t-- Attribution: recent hero damage counts only while its author is still in/" "$JMZ"; }
mutant caught "M7 the ring clause is inverted too (a second lever)" "$JMZ" m7

m8() { perl -0pi -e "s/\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end\n\n\t-- Attribution: recent hero damage counts only while its author is still in/\tif #J.GetNearbyHeroes( bot, 2500, true, BOT_MODE_NONE ) > 0 then return false end\n\n\t-- Attribution: recent hero damage counts only while its author is still in/" "$JMZ"; }
mutant caught "M8 the copied ring drifts from the body that owns it" "$JMZ" m8

anchor 1 "$JMZ" "	if #bot:GetNearbyTowers( 1200, true ) > 0 then return false end

	-- The same conjunction all four siblings ask"
m9() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n\n\t-- The same conjunction all four siblings ask/\t-- The same conjunction all four siblings ask/" "$JMZ"; }
mutant caught "M9 the inherited tower clause is dropped" "$JMZ" m9

# --- M10: ⭐ the premise moves --------------------------------------------------
# The floor is QUOTED from a shipped function. Lower it THERE and this lever is
# untouched, still gated, still passing its behavioural assertions -- and the
# finding it is named for has silently become a different one. It also moves
# 'stayfield', 'stayfield2' and 'fieldbuy' on one arm: the 'lanefix' shape.
anchor 1 "$JMZ" "	if nHP < 0.18 or nHP > 0.55 then return false end"
m10() { perl -0pi -e "s/\tif nHP < 0\.18 or nHP > 0\.55 then return false end/\tif nHP < 0.10 or nHP > 0.55 then return false end/" "$JMZ"; }
mutant caught "M10 the SHARED predicate's own floor is lowered instead" "$JMZ" m10

# --- M11, M12: the pullcad trap, both forms ----------------------------------
m11() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buydeep' \) then return false end/\tif not ( J.IsSoakCandidate( 'buydeep' ) and J.IsSoakCandidate( 'fieldbuy' ) ) then return false end/" "$JMZ"; }
mutant caught "M11 a second soak id joins the gate's condition" "$JMZ" m11

# Reads as tidying up an inconsistency between the five arms, and freezes the
# copied clause FALSE the day 'fieldcreep' is promoted.
m12() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n\n\t-- The same conjunction all four siblings ask/\tif J.IsSoakCandidate( 'fieldcreep' ) and bot:WasRecentlyDamagedByCreep( 3.0 ) then return false end\n\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n\t-- The same conjunction all four siblings ask/" "$JMZ"; }
mutant caught "M12 the un-copied 'fieldcreep' veto is copied in" "$JMZ" m12

# --- M13: another lever's invariant ------------------------------------------
# Strictly tidier: the helper exists, is a pure question about the world, and says
# exactly this. It also has a one-caller count asserted in another lever's file,
# so "tidier" here means turning that file red for a change it does not concern.
anchor 1 "$JMZ" "		local hDamagers = J.GetNearbyHeroes( bot, 3000, true, BOT_MODE_NONE )
		for _, hEnemy in pairs( hDamagers ) do
			if J.IsValidHero( hEnemy )
				and bot:WasRecentlyDamagedByHero( hEnemy, 3.0 )
			then
				return false
			end
		end
	end

	if #bot:GetNearbyTowers( 1200, true ) > 0 then return false end"
m13() { perl -0pi -e "s/\tif bot:WasRecentlyDamagedByAnyHero\( 3\.0 \) then\n\t\tlocal hDamagers = J\.GetNearbyHeroes\( bot, 3000, true, BOT_MODE_NONE \)\n\t\tfor _, hEnemy in pairs\( hDamagers \) do\n\t\t\tif J\.IsValidHero\( hEnemy \)\n\t\t\t\tand bot:WasRecentlyDamagedByHero\( hEnemy, 3\.0 \)\n\t\t\tthen\n\t\t\t\treturn false\n\t\t\tend\n\t\tend\n\tend\n\n\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end/\tif J.HasNearbyHeroDamager( bot, 3000, 3.0 ) then return false end\n\n\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end/" "$JMZ"; }
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

# ⚠️ The needle carries its closing `end` at its own indent: the bare line occurs
# twice, the second being the stub RESTORED inside the disjointness probe at a
# deeper indent, and a needle indented 24 spaces is a SUBSTRING of the same line
# indented 28 (mutstand_buyring.sh bought that lesson).
anchor 1 "$SWEEP" "                        return armed and sId == 'buydeep'
                    end"
m16() { perl -0pi -e "s/                        return armed and sId == 'buydeep'\n                    end/                        return armed\n                    end/" "$SWEEP"; }
mutant caught "M16 the stub arms every candidate at once" "$SWEEP" m16

# --- M17, M18: the two routes stop being two / a zero nobody measured --------
anchor 1 "$SWEEP" "                    local bClean = not bRingBusy and not bAttr and not bTower"
m17() { perl -0pi -e "s/                    local bClean = not bRingBusy and not bAttr and not bTower/                    local bClean = not bAttr and not bTower/" "$SWEEP"; }
mutant caught "M17 the prefix walk drops the ring clause (routes disagree)" "$SWEEP" m17

anchor 1 "$SWEEP" "                            local okd, deeponly = pcall(J.ShouldFieldBuyRegenDeep, bot)"
m18() { perl -0pi -e "s/                            local okd, deeponly = pcall\(J\.ShouldFieldBuyRegenDeep, bot\)/                            local okd, deeponly = false, false/" "$SWEEP"; }
mutant caught "M18 the disjointness probe stops driving (an unmeasured zero)" "$SWEEP" m18

# --- M19: the lever is simplified into the trap it avoids --------------------
# Strictly shorter, passes luacheck, and re-imposes the very 0.18 floor this lever
# exists to invert -- a no-op that still passes its own gate.
m19() { perl -0pi -e "s/\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end\n\n\t-- Attribution: recent hero damage counts only while its author is still in/\tif not J.IsFieldRegenSituation( bot ) then return false end\n\n\t-- Attribution: recent hero damage counts only while its author is still in/" "$JMZ"; }
mutant caught "M19 the lever is folded back into a call to the shared predicate" "$JMZ" m19

# --- M20, M21: ⭐ the round's own correction is undone -------------------------
# The charter handed this round `stop_source 8` with the warning that 8 says "no
# supply", not "safe". M20 makes the split stop asking the ring, so
# `stop_source_domain` reads 8 -- the number a lever sized on the charter's
# reading would have been sized on.
anchor 1 "$SWEEP" "                            if bRingBusy then sWhy = 'ring'; bump('stop_source_ring')"
m20() { perl -0pi -e "s/                            if bRingBusy then sWhy = 'ring'; bump\('stop_source_ring'\)\n                            elseif/                            if false then sWhy = 'ring'; bump('stop_source_ring')\n                            elseif/" "$SWEEP"; }
mutant caught "M20 the split of the 8 stops asking the ring (domain reads 8)" "$SWEEP" m20

# The order-free column starts respecting the walk order, so its 3 collapses to
# the prefix bucket's 0 -- and the file loses the only thing that separates
# "attribution is silent here" from "attribution is filed under the ring".
anchor 1 "$SWEEP" "                            if bAttr then bump('stop_source_attr_any') end"
m21() { perl -0pi -e "s/                            if bAttr then bump\('stop_source_attr_any'\) end/                            if bAttr and not bRingBusy then bump('stop_source_attr_any') end/" "$SWEEP"; }
mutant caught "M21 the order-free attribution column becomes a prefix column" "$SWEEP" m21

# --- C1: the control ---------------------------------------------------------
anchor 1 "$JMZ" "	-- The three surroundings clauses of J.IsFieldRegenSituation, in its own order"
c1() { perl -0pi -e "s/\t-- The three surroundings clauses of J\.IsFieldRegenSituation, in its own order/\t-- CONTROL EDIT: comment text only, no code touched./" "$JMZ"; }
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

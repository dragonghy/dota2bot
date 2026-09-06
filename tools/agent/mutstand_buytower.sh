#!/usr/bin/env bash
# Mutation stand for tests/test_buytower_purchase_domain.lua (test_set.md §FE).
#
# WHAT IT IS FOR. This round adds a THIRD gated arm to a shipped purchase site,
# and the lever is not a band -- it is one INVERTED clause. J.IsFieldRegenSituation
# refuses whenever an enemy tower is inside 1200, and its own comment gives a
# HOLD-side reason for that: do not cancel the local back-off from a tower. The
# supply side cancels no retreat bid, so on the buy arms the clause vetoes for a
# reason that does not apply, and a hurt, empty-handed bot near a tower is sent
# home instead of buying a salve. This lever answers exactly where that clause is
# the only thing refusing -- 8 frames of a 1012-frame corpus.
#
# The case has three halves and they forge differently:
#   (a) the behaviour: a driven before/after on real frames plus a 1012-frame
#       domain price, both legs from the same shipped call-site predicate TRIO
#       with one soak id toggled;
#   (b) the DISJOINTNESS claim -- and for this lever it is carried by the
#       INVERSION, not by an HP split. `== 0 then return false` against the
#       siblings' `> 0 then return false` is the whole of it: un-invert that one
#       comparison and the three arms start overlapping while every other number
#       still looks plausible;
#   (c) the DUPLICATION claim -- the ring and attribution clauses are copied out
#       of J.IsFieldRegenSituation rather than called, so the copies must be
#       proven not to drift. That rests on parsed constants, both directions.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- the gate lands un-negated (so the
#     arm applies to the SHIPPED path and disappears when armed: a change to
#     shipped behaviour wearing the shape of a gated one), or the wiring is
#     removed from the purchase site so the predicate exists and decides nothing;
#   * ⭐ THE INVERSION GOES (M3, M4) -- the clause this lever IS gets un-inverted
#     or deleted. Both leave a lever that still fires, still passes its gate and
#     still buys salves; what they destroy is the property that makes any of its
#     frames attributable to it;
#   * THE BAND STOPS BEING THE PROMOTED ONE (M5, M6) -- a bound is retuned in the
#     lever, so it is a new constant rather than one owned elsewhere;
#   * ⭐ THE PREMISE MOVES (M7, M8) -- the shipped functions this lever quotes are
#     edited instead. Nothing about the lever changes, its behavioural assertions
#     still pass on some population, and the FINDING is silently about something
#     else. M8 is the sharpest: delete the tower clause from the SHARED predicate
#     and this lever's whole reason for existing is gone while it keeps firing;
#   * THE PULLCAD TRAP, BOTH FORMS (M9, M10) -- a second soak id joins the gate's
#     condition; or the un-copied 'fieldcreep' veto is copied in, which reads as
#     tidying and freezes that clause FALSE the day that id is promoted;
#   * THE DUPLICATION DRIFTS (M11, M12) -- a copied constant moves in the lever
#     only, so it answers about a different situation than the sibling it claims
#     to mirror;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M13) -- strip_comments leaves
#     the sweep, and this lever's comment names IsSoakCandidate, three sibling
#     ids and every constant while explaining them;
#   * THE TOGGLE STOPS TOGGLING (M14, M15) -- the armed leg is driven disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction), or the
#     shipped baseline is driven armed;
#   * THE ARMING IS TOO WIDE (M16) -- the stub arms every candidate, so a sibling
#     can move the answer while the flip is still attributed here. Inherited
#     knowledge: the same mutant SURVIVED the first run of the 'stayattr' stand;
#   * THE TWO ROUTES STOP BEING TWO (M17) -- the independent prefix walk drops a
#     clause, so it and the driven count measure different populations. The
#     cross-check is the only thing making either of them evidence;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M18) -- the disjointness probe stops
#     driving. Both overlap columns then read exactly as they do when the probe
#     ran over 1012 frames and found nothing: the GH #171 shape;
#   * THE LEVER IS SIMPLIFIED INTO THE TRAP IT AVOIDS (M19) -- someone folds the
#     copied clauses back into a call to J.IsFieldRegenSituation. Strictly
#     shorter, passes luacheck, and re-imposes the very veto this lever exists to
#     lift: the lever becomes a no-op that still passes its own gate.
#
# ⛔ ANCHOR UNIQUENESS IS PART OF EACH DECLARATION, not a detail of the regex.
# GH #550 (and this round's own measurement of the sibling stand, where M9 and
# M17 had been cutting J.IsFieldRegenSituation rather than the lever they name
# and printing CAUGHT for it) is why every anchor below was counted in the file
# before it was used. The band line of this lever is deliberately written as two
# statements for the same reason.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_buytower.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, first confirm the edit landed where you meant).
#
# SLOW ON PURPOSE (~30s per mutant): every mutant re-runs a 109-fixture,
# 1012-frame sweep in which the decision is driven five times per frame. The
# sweep is the thing under test; running it once and reusing the output would
# test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
PURCHASE=bots/item_purchase_generic.lua
SWEEP=tests/_buytower_sweep.lua
TEST=buytower_purchase

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
# indistinguishable from a mutant that worked. This is the mechanised form of
# GH #550: every anchor declares how many times it may occur, and a mismatch is
# a stand failure, not a mutant result.
#
# ⚠️ The obvious implementation is WRONG and it failed loudly on its first run,
# which is the only reason this comment exists: `grep -F -c -- "$needle"` counts
# matching LINES and treats a multi-line needle as a LIST of alternative
# patterns, so a needle containing a blank line matched every blank line in the
# file and reported 13133 occurrences of a two-line anchor. A counter that can
# report a five-digit number for a thing that occurs once is not a check. The
# count is therefore done as a literal substring count over the whole file.
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
# call site), or want=equivalent (an edit that is provably a NO-OP on any corpus,
# kept because the proof is worth reading).
#
# The two non-binary classes are different claims and must not be collapsed:
#   UNMEASURABLE says "this corpus cannot witness the difference" -- a fixture
#     could change that tomorrow, and the entry gets re-classified when it does.
#   EQUIVALENT says "there is no difference to witness" -- the mutated program
#     computes the same function, so no corpus, ever, can catch it.
# Neither is a pass.
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
# Un-negated in effect: the arm now applies when the id is NOT armed, so the
# shipped tree changes and the armed leg is the old shipped read. Both legs still
# "work"; they have swapped.
anchor 1 "$JMZ" "	if not J.IsSoakCandidate( 'buytower' ) then return false end"
m1() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buytower' \) then return false end/\tif J.IsSoakCandidate( 'buytower' ) then return false end/" "$JMZ"; }
mutant caught "M1 the gate lands negated (shipped and armed legs swap)" "$JMZ" m1

# The predicate survives, fully tested, and decides nothing: the purchase site
# stops consulting it. Every [frame] test in the file drives the SITE, so this is
# the mutant that separates "the helper is right" from "the helper is wired".
# ⚠️ 2026-09-06: re-anchored the day a FOURTH arm ('buyring') joined the same OR.
# The old anchor ended at ` )` -- the closing paren of a three-arm condition -- so
# the new arm made it occur ZERO times, and only the anchor check said so. The
# needle is now the arm ITSELF, which is what this mutant removes; the replacement
# deletes just that arm and leaves whatever else the OR carries.
anchor 1 "$PURCHASE" "or J.ShouldFieldBuyRegenTower(bot)"
m2() { perl -0pi -e "s/or J\.ShouldFieldBuyRegenTower\(bot\) ?//" "$PURCHASE"; }
mutant caught "M2 the third OR arm is removed from the purchase site" "$PURCHASE" m2

# --- M3, M4: ⭐ the inversion goes --------------------------------------------
# The one comparison the whole disjointness argument rests on. Un-inverted, this
# lever's domain becomes a SUBSET of its siblings' -- both arms answer TRUE on
# the same frames, and no isolation wave can attribute a single one of them.
anchor 1 "$JMZ" "	if #bot:GetNearbyTowers( 1200, true ) == 0 then return false end"
m3() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) == 0 then return false end/\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end/" "$JMZ"; }
mutant caught "M3 the tower clause is un-inverted (domains overlap)" "$JMZ" m3

# Deleted outright, which is the tidier-looking version of the same defect: the
# lever now answers over every clean frame its siblings already own.
m4() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) == 0 then return false end\n\n//" "$JMZ"; }
mutant caught "M4 the tower clause is deleted entirely" "$JMZ" m4

# --- M5, M6: the band stops being the promoted one ---------------------------
# Written as two statements so each bound has a unique anchor (see the header).
anchor 1 "$JMZ" "	if nHP < 0.18 then return false end"
m5() { perl -0pi -e "s/\tif nHP < 0\.18 then return false end/\tif nHP < 0.05 then return false end/" "$JMZ"; }
mutant caught "M5 the lever's floor leaves the sibling's 0.18" "$JMZ" m5

anchor 1 "$JMZ" "	if nHP > 0.75 then return false end"
m6() { perl -0pi -e "s/\tif nHP > 0\.75 then return false end/\tif nHP > 1.0 then return false end/" "$JMZ"; }
mutant caught "M6 the lever's ceiling leaves the promoted veto's 0.75" "$JMZ" m6

# --- M7, M8: ⭐ the premise moves ---------------------------------------------
# The band is quoted from two SHIPPED functions. Move one of them and the lever
# is untouched, still gated, still passing its own behaviour tests -- and the
# band it documents itself as spanning is a different band.
anchor 1 "$JMZ" "	if nHP < 0.18 or nHP > 0.75 then return false end"
m7() { perl -0pi -e "s/\tif nHP < 0\.18 or nHP > 0\.75 then return false end/\tif nHP < 0.18 or nHP > 0.60 then return false end/" "$JMZ"; }
mutant caught "M7 the PROMOTED veto's own 0.75 moves" "$JMZ" m7

# ⭐ The sharpest one in this stand. Delete the tower clause from the SHARED
# predicate and this lever's entire reason for existing is gone -- its siblings
# now cover those frames themselves -- while the lever keeps firing and every
# [frame] assertion about it still passes. Only a source assertion about the
# sibling can see it, which is why SIT_TOWER_PLAIN exists.
anchor 1 "$JMZ" "	if #bot:GetNearbyTowers( 1200, true ) > 0 then return false end

	-- [soak candidate 'fieldcreep'"
m8() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n\n\t-- \[soak candidate 'fieldcreep'/\t-- [soak candidate 'fieldcreep'/" "$JMZ"; }
mutant caught "M8 the tower clause leaves the SHARED predicate" "$JMZ" m8

# --- M9, M10: the pullcad trap, both forms -----------------------------------
m9() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buytower' \) then return false end/\tif not ( J.IsSoakCandidate( 'buytower' ) and J.IsSoakCandidate( 'fieldbuy' ) ) then return false end/" "$JMZ"; }
mutant caught "M9 a second soak id joins the gate condition (pullcad)" "$JMZ" m9

# The tidying that looks like consistency: copy in the sibling's gated creep
# veto. It reads as making the arms agree -- and it freezes that clause FALSE the
# day 'fieldcreep' is promoted, because a promoted id is in no armed string.
# Anchored on this lever's OWN closing comment, which is unique in the file.
anchor 1 "$JMZ" "	-- The same conjunction both siblings ask, asked the same way."
m10() { perl -0pi -e "s/\t-- The same conjunction both siblings ask, asked the same way\./\tif J.IsSoakCandidate( 'fieldcreep' ) and bot:WasRecentlyDamagedByCreep( 3.0 ) then return false end\n\t-- The same conjunction both siblings ask, asked the same way./" "$JMZ"; }
mutant caught "M10 the lever copies in the sibling's gated creep veto" "$JMZ" m10

# --- M11, M12: the duplication drifts ----------------------------------------
# The price of copying clauses instead of calling them. Neither crashes; what
# they change is whether the lever answers about the same situation as the
# sibling whose clauses it claims to mirror. Anchored on THIS lever's own comment
# wording, which was written to be unique for exactly this reason.
anchor 1 "$JMZ" "	-- Danger, attributed: someone hit me recently AND is still near me."
m11() { perl -0pi -e "s/\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end\n\n\t-- Danger, attributed/\tif #J.GetNearbyHeroes( bot, 900, true, BOT_MODE_NONE ) > 0 then return false end\n\n\t-- Danger, attributed/" "$JMZ"; }
mutant caught "M11 the copied ring radius drifts to 900" "$JMZ" m11

m12() { perl -0pi -e "s/\t-- Danger, attributed: someone hit me recently AND is still near me\.\n\tif bot:WasRecentlyDamagedByAnyHero\( 3\.0 \) then/\t-- Danger, attributed: someone hit me recently AND is still near me.\n\tif bot:WasRecentlyDamagedByAnyHero( 9.0 ) then/" "$JMZ"; }
mutant caught "M12 the copied damage lookback drifts to 9.0" "$JMZ" m12

# --- M13: the instrument reads prose instead of code -------------------------
m13() { perl -0pi -e "s/local tow = strip_comments\(block\(src, 'function J\.ShouldFieldBuyRegenTower\( bot \)'\)\)/local tow = block(src, 'function J.ShouldFieldBuyRegenTower( bot )')/" "$SWEEP"; }
mutant caught "M13 the sweep stops stripping comments before parsing" "$SWEEP" m13

# --- M14, M15: the toggle stops toggling -------------------------------------
m14() { perl -0pi -e "s/                    local ok1, shipped = pcall\(pred\)\n                    armed = true\n/                    local ok1, shipped = pcall(pred)\n                    armed = false\n/" "$SWEEP"; }
mutant caught "M14 the armed leg is driven disarmed (flips -> 0)" "$SWEEP" m14

m15() { perl -0pi -e "s/                    local ok1, shipped = pcall\(pred\)\n/                    armed = true\n                    local ok1, shipped = pcall(pred)\n/" "$SWEEP"; }
mutant caught "M15 the shipped baseline is driven armed" "$SWEEP" m15

# --- M16: the arming is too wide ---------------------------------------------
# SURVIVED the first run of the 'stayattr' stand; caught here by `arm_leak`,
# which names the five siblings sharing this path.
m16() { perl -0pi -e "s/                        return armed and sId == 'buytower'\n                    end\n\n                    local nHP/                        return armed\n                    end\n\n                    local nHP/" "$SWEEP"; }
mutant caught "M16 the stub arms every candidate, not just this one" "$SWEEP" m16

# --- M17: the two routes stop being two --------------------------------------
# The independent prefix walk drops the "carries nothing" clause, so it counts a
# larger population than the driven flip set. The cross-check is the only thing
# that makes either number evidence rather than an assertion about itself.
m17() { perl -0pi -e "s/                        and not bRingBusy and not bAttr and bTower\n                        and not bMain\n                    then\n                        bump\('tower_domain'\)/                        and not bRingBusy and not bAttr and bTower\n                    then\n                        bump('tower_domain')/" "$SWEEP"; }
mutant caught "M17 the prefix walk drops the empty-handed clause" "$SWEEP" m17

# --- M18: ⭐ a zero that was never measured ----------------------------------
# Both overlap columns are claims whose entire content is a zero; a probe that
# stops driving prints exactly the same zero as one that drove 1012 frames and
# found nothing. Nothing else in the suite contradicts it -- which is why the
# probe counts its own drives.
m18() { perl -0pi -e "s/                            if okt and okb and okh then bump\('overlap_probe_runs'\) end\n/                            if false then bump('overlap_probe_runs') end\n/" "$SWEEP"; }
mutant caught "M18 the disjointness probe stops driving (a fake zero)" "$SWEEP" m18

# --- M19: the lever is simplified into the trap it avoids --------------------
# The reviewer's tidy-up: replace the copied clauses with the call they were
# copied from. Strictly shorter, passes luacheck -- and it re-imposes the tower
# veto this lever exists to lift, so the lever becomes a no-op that still passes
# its own gate and still reports itself WIRED.
m19() { perl -0pi -e "s/\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end\n\n\t-- Danger, attributed.*?\tif #bot:GetNearbyTowers\( 1200, true \) == 0 then return false end\n/\tif not J.IsFieldRegenSituation( bot ) then return false end\n/s" "$JMZ"; }
mutant caught "M19 the copied clauses are folded back into a call" "$JMZ" m19

# --- M20: the control --------------------------------------------------------
m20() { perl -0pi -e "s/-- \[buytower \/ owner priority P2 supply side, 2026-09-06\] The third arm of the same/-- [buytower \/ owner priority P2 supply side, 2026-09-06] The THIRD arm of the same/" "$JMZ"; }
mutant survive "M20 a comment inside the lever's own block is reworded" "$JMZ" m20

echo "---"
echo "mutants run: $nrun   landed as declared: $ncaught   unmeasurable+equivalent: $nunmeas   NOT as declared: $nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND RED: $nbad mutant(s) did not land as declared."
    exit 1
fi
echo "STAND GREEN"
exit 0

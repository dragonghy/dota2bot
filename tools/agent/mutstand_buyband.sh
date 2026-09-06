#!/usr/bin/env bash
# Mutation stand for tests/test_buyband_hp_band.lua (test_set.md §FD).
#
# WHAT IT IS FOR. This round adds a NEW gated arm to a shipped purchase site: the
# HP band between J.ShouldStayAndRegen's 0.75 (where the PROMOTED veto stops
# holding a hurt bot) and J.IsFieldRegenSituation's 0.55 (where the field
# alternative stops being offered at all). The case for it has three halves and
# they forge differently:
#   (a) the behaviour: a driven before/after on real frames plus a 1012-frame
#       domain price, both legs from the same shipped call-site predicate pair
#       with one soak id toggled;
#   (b) the DESIGN claim -- that the lever is visible to a SINGLE-ARM wave. The
#       obvious edit (pass a gated ceiling from inside J.ShouldFieldBuyRegen)
#       would sit behind that function's own gate, so the new id could only act
#       with 'fieldbuy' also armed: the second form of the 'pullcad' trap
#       (GH #542). That claim rests entirely on `flips_buyband` being nonzero
#       with nothing else armed;
#   (c) the DUPLICATION claim -- three surroundings clauses are copied out of
#       J.IsFieldRegenSituation rather than called, so the two copies must be
#       proven not to drift. That rests on eight parsed constants.
#
# So the forgeable surfaces are the toggle (it stops toggling, or toggles too
# much), the census (a plausible number about the wrong population), the two
# constants the whole finding is a GAP between, and the drift guard itself.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2) -- the gate lands un-negated (so the
#     new arm applies to the SHIPPED path and disappears when armed: a change to
#     shipped behaviour wearing the shape of a gated one), or the wiring is
#     removed from the purchase site so the predicate exists and decides nothing;
#   * THE BAND STOPS BEING THE GAP (M3, M4) -- the floor is deleted, so this
#     lever and 'fieldbuy' overlap and an isolation wave can credit either id
#     with the other's frames; or the ceiling leaves the promoted veto's 0.75 and
#     the lever starts buying salves for healthy bots;
#   * ⭐ THE PREMISE MOVES (M5, M6) -- one of the two constants the finding is a
#     GAP BETWEEN is edited in its own shipped function. This is the mutant class
#     this stand exists for: nothing about the lever changes, every behavioural
#     assertion still passes on some population, and the FINDING is silently
#     about a different gap (or about none);
#   * THE PULLCAD TRAP, BOTH FORMS (M7, M8) -- a second soak id joins the gate's
#     condition; or the un-copied 'fieldcreep' veto is copied in, which reads as
#     tidying and freezes that clause FALSE the day that id is promoted;
#   * THE DUPLICATION DRIFTS (M9, M10) -- a copied constant moves in the lever
#     only. Nothing crashes, no test about THIS lever's behaviour changes on this
#     corpus for the small edits, and the lever is quietly answering about a
#     different situation than the sibling it claims to mirror;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M11) -- strip_comments leaves
#     the sweep, and this lever's ~60-line comment names IsSoakCandidate, three
#     sibling ids and both constants while explaining them;
#   * THE TOGGLE STOPS TOGGLING (M12, M13) -- the armed leg is driven disarmed
#     (flips -> 0, i.e. "tested, no effect", the SAFE-LOOKING direction), or the
#     shipped baseline is driven armed;
#   * THE ARMING IS TOO WIDE (M14) -- the stub arms every candidate, so
#     'fieldbuy' (33 flips on this corpus) can move the answer while 20 flips are
#     still attributed here. Inherited knowledge, not invention: the same mutant
#     SURVIVED the first run of the 'stayattr' stand;
#   * THE TWO ROUTES STOP BEING TWO (M15) -- the independent prefix walk drops a
#     clause, so it and the driven count are measuring different populations. The
#     cross-check is the only thing making either of them evidence;
#   * ⭐ A ZERO THAT WAS NEVER MEASURED (M16) -- the disjointness probe stops
#     driving. `overlap_buy_hurt == 0` then reads exactly as it does when the
#     probe ran over 1012 frames and found nothing: the GH #171 shape. Caught
#     only because the probe now counts its own drives;
#   * THE LEVER IS SIMPLIFIED INTO THE TRAP IT AVOIDS (M17) -- someone folds the
#     three duplicated clauses back into a call to J.IsFieldRegenSituation. It
#     looks strictly tidier, it passes luacheck, and it silently caps the lever's
#     band at 0.55 -- i.e. the lever becomes a no-op that still passes its gate.
#
# ⚠️ DECLARED UNMEASURABLE (M18): the `return false` inside the lever's copied
# attribution loop is removed, so recent hero damage from an enemy still inside
# 3000 no longer vetoes. Of the 20 domain frames exactly 1 carries recent hero
# damage at all and it is UNATTRIBUTED (the frame that motivated 'stayattr'), so
# no frame in this corpus can distinguish the two programs. The drift guard does
# not see it either: the constants are untouched. The day a fixture lands a
# hurt-by-a-nearby-enemy frame inside the band, this re-classifies -- and the
# entry says so rather than being deleted.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_buyband.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, read the diff first: a regex that misses prints NO-OP, a
# regex that hits the wrong place prints SURVIVED while the subject is
# untouched).
#
# SLOW ON PURPOSE (~30s per mutant): every mutant re-runs a 109-fixture,
# 1012-frame sweep in which the decision is driven five times per frame (shipped
# / armed / fieldbuy-only / and the two arms separately for the disjointness
# probe). The sweep is the thing under test; running it once and reusing the
# output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
PURCHASE=bots/item_purchase_generic.lua
SWEEP=tests/_buyband_sweep.lua
TEST=buyband_hp_band

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
m1() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buyband' \) then return false end\n\tif not J\.IsModeTurbo\(\) then return false end/\tif J.IsSoakCandidate( 'buyband' ) then return false end\n\tif not J.IsModeTurbo() then return false end/" "$JMZ"; }
mutant caught "M1 the gate lands negated (shipped and armed legs swap)" "$JMZ" m1

# The predicate survives, fully tested, and decides nothing: the purchase site
# stops consulting it. Every [frame] test in the file drives the SITE, so this is
# the mutant that separates "the helper is right" from "the helper is wired".
#
# ⚠️ RE-ANCHORED 2026-09-06: the 'buytower' round added a THIRD arm to the same
# condition, so the two-arm literal stopped matching and this mutant printed
# NO-OP -- which the stand reports as a failure precisely because a mutant that
# never existed is not a mutant that survived. The replacement now drops THIS
# lever's arm out of the three-arm OR and leaves the other two.
#
# ⚠️ RE-ANCHORED A SECOND TIME, 2026-09-06T17:xxZ, and the second failure is the
# instructive one because it is the SAME failure. The 09-06T04:35Z re-anchor
# rewrote the WHOLE `if (...)` condition -- correct against a three-arm site, and
# NO-OP again the moment the 'buyring' round added a fourth arm. An anchor that
# spells out the syntactic CONTEXT of the thing it edits has to be re-cut every
# time a neighbour lands; the family this site belongs to grows an arm per round,
# so that is a standing tax with a NO-OP as the failure mode.
# ⇒ The anchor is now ARM-LOCAL: it names only the arm this mutant removes, and
# says nothing about how many other arms exist or what order they are in. This is
# the same shape `mutstand_buytower.sh` was moved to by the 'buyring' round
# (95b5d5f8) -- which fixed its own stand's M2 and left this one, so the identical
# defect sat here until it was re-run.
# ⇒ GENERAL RULE, and it is the mutation-stand form of the GH #550 lesson: anchor
# a mutant on the THING IT MUTATES, never on the context that happens to contain
# it. Uniqueness alone is not enough -- a unique anchor made of its neighbours is
# still a hostage to them.
m2() { perl -0pi -e "s/ or J\.ShouldFieldBuyRegenHurt\(bot\)//" "$PURCHASE"; }
mutant caught "M2 the OR arm is removed from the purchase site" "$PURCHASE" m2

# --- M3, M4: the band stops being the gap ------------------------------------
# Delete the floor: the lever now answers over 'fieldbuy''s domain too, so the
# two ids overlap and a single-arm wave can credit either with the other's work.
m3() { perl -0pi -e "s/\tif nHP <= 0\.55 or nHP > 0\.75 or nHP < 0\.18 then return false end/\tif nHP > 0.75 or nHP < 0.18 then return false end/" "$JMZ"; }
mutant caught "M3 the floor is deleted (domains overlap fieldbuy)" "$JMZ" m3

m4() { perl -0pi -e "s/\tif nHP <= 0\.55 or nHP > 0\.75 or nHP < 0\.18 then return false end/\tif nHP <= 0.55 or nHP > 1.0 or nHP < 0.18 then return false end/" "$JMZ"; }
mutant caught "M4 the ceiling leaves the promoted veto's 0.75" "$JMZ" m4

# --- M5, M6: ⭐ the premise moves --------------------------------------------
# The finding is a GAP between two shipped constants. Move either one and the
# lever is unchanged, still gated, still passing its own behaviour tests on some
# population -- and the thing it is documented to fill is a different gap. These
# are only visible because both numbers are parsed out of their own functions and
# compared, rather than written down in the test.
m5() { perl -0pi -e "s/\tif nHP < 0\.18 or nHP > 0\.55 then return false end/\tif nHP < 0.18 or nHP > 0.70 then return false end/" "$JMZ"; }
mutant caught "M5 the sibling's 0.55 moves (the gap shrinks silently)" "$JMZ" m5

m6() { perl -0pi -e "s/\tif nHP < 0\.18 or nHP > 0\.75 then return false end/\tif nHP < 0.18 or nHP > 0.60 then return false end/" "$JMZ"; }
mutant caught "M6 the promoted veto's 0.75 moves (the gap inverts)" "$JMZ" m6

# --- M7, M8: the pullcad trap, both forms ------------------------------------
m7() { perl -0pi -e "s/\tif not J\.IsSoakCandidate\( 'buyband' \) then return false end/\tif not ( J.IsSoakCandidate( 'buyband' ) and J.IsSoakCandidate( 'fieldbuy' ) ) then return false end/" "$JMZ"; }
mutant caught "M7 a second soak id joins the gate condition (pullcad)" "$JMZ" m7

# The tidying that looks like consistency: copy in the sibling's gated creep
# veto. It reads as making the two arms agree -- and it freezes that clause FALSE
# the day 'fieldcreep' is promoted, because a promoted id is in no armed string.
#
# ⚠️ THIS MUTANT SURVIVED ITS FIRST RUN, AND THE REASON IS THE STAND'S OWN
# HEADER WARNING ABOUT ITSELF. Its first anchor was the bare tower line, which
# occurs TWICE in this file -- once in J.IsFieldRegenSituation (line ~5588) and
# once in this lever (~5852) -- and `perl -0pi -e "s///"` without /g rewrites the
# FIRST. So the edit landed in the SIBLING and this lever was never touched: a
# real mutation of a function no assertion in the suite was counting ids on.
# Re-anchored on the comment that follows THIS lever's copy, which is unique.
# ⭐ AND THE SURVIVAL PAID FOR ITSELF TWICE. It bought a genuinely missing
# assertion (`SIT_NIDS == 1`: a SECOND gated clause appearing in the shared
# predicate is the "one arm moves three families" hazard this whole design is
# built to avoid, and nothing was watching for it), and it exposed that M10 --
# same bare anchor -- had been CAUGHT for the WRONG REASON, moving the sibling's
# constant rather than this lever's copy. ⇒ **CAUGHT hides a mis-aimed mutant
# exactly as well as SURVIVED reveals one**: a green stand does not establish
# that any mutant hit its stated subject, only that something turned the suite
# red. Anchor uniqueness is not a detail of the regex, it is part of the claim.
m8() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n\n\t-- The same conjunction/\tif J.IsSoakCandidate( 'fieldcreep' ) and bot:WasRecentlyDamagedByCreep( 3.0 ) then return false end\n\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n\t-- The same conjunction/" "$JMZ"; }
mutant caught "M8 the lever copies in the sibling's gated creep veto" "$JMZ" m8

# The same edit landing in the SIBLING instead -- kept as its own mutant now that
# the two are distinguishable, because it is a different defect with a different
# owner: a second gated clause in the predicate three families share, which is
# the "one arm moves three levers" shape. Caught by `SIT_NIDS`, an assertion that
# did not exist until M8's mis-aimed first run walked into it.
m8b() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n\n\t-- \[soak candidate 'fieldcreep'/\tif J.IsSoakCandidate( 'fieldcreep' ) and bot:WasRecentlyDamagedByCreep( 3.0 ) then return false end\n\tif #bot:GetNearbyTowers( 1200, true ) > 0 then return false end\n\n\t-- [soak candidate 'fieldcreep'/" "$JMZ"; }
mutant caught "M8b a second gated clause joins the SHARED predicate" "$JMZ" m8b

# --- M9, M10: the duplication drifts -----------------------------------------
# The price of copying three clauses instead of calling them. Neither of these
# crashes and neither changes this corpus's flip count by much; what they change
# is whether the lever is answering about the same situation as the sibling whose
# clauses it claims to mirror.
#
# ⚠️ RE-ANCHORED 2026-09-06 (協同組, 'buytower' round), and it is the THIRD
# instance of this stand's own header warning -- this time found by measurement
# rather than by a survival. The old anchor was the bare ring line plus the
# comment `-- Attributed danger` that follows it, and that PAIR occurred THREE
# times in jmz_func.lua before the 'buytower' lever existed: in
# J.IsFieldRegenSituation (~5560), in this lever (~5843) and in
# J.IsWastefulItemTrip (~6088). `perl -0pi -e "s///"` without /g rewrites the
# FIRST, so every run of this mutant since it was written moved the SHARED
# predicate's 1600 -- and the drift guard `HURT_RING == SIT_RING` then went red
# because the SIBLING had moved, printing CAUGHT for a mutation of a function
# this mutant does not name. Re-anchored on the two comment lines that precede
# THIS lever's copy, which are unique in the file.
m9() { perl -0pi -e "s/-- third bullet above\. tests\/_buyband_sweep\.lua parses both copies\.\n\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end/-- third bullet above. tests\/_buyband_sweep.lua parses both copies.\n\tif #J.GetNearbyHeroes( bot, 900, true, BOT_MODE_NONE ) > 0 then return false end/" "$JMZ"; }
mutant caught "M9 the copied ring radius drifts to 900" "$JMZ" m9

# ⚠️ RE-ANCHORED for the same reason as M8, and it is the more instructive half:
# this mutant was CAUGHT on its first run and was still wrong. The bare tower line
# occurs twice, so the edit moved the SIBLING's constant, the drift guard saw
# 300 != 1200 and went red -- the right colour from the wrong function. Nothing in
# a CAUGHT line says which one it hit.
m10() { perl -0pi -e "s/\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n\n\t-- The same conjunction/\tif #bot:GetNearbyTowers( 300, true ) > 0 then return false end\n\n\t-- The same conjunction/" "$JMZ"; }
mutant caught "M10 the LEVER's copied tower radius drifts to 300" "$JMZ" m10

# --- M11: the instrument reads prose instead of code -------------------------
m11() { perl -0pi -e "s/local hurt = strip_comments\(block\(src, 'function J\.ShouldFieldBuyRegenHurt\( bot \)'\)\)/local hurt = block(src, 'function J.ShouldFieldBuyRegenHurt( bot )')/" "$SWEEP"; }
mutant caught "M11 the sweep stops stripping comments before parsing" "$SWEEP" m11

# --- M12, M13: the toggle stops toggling -------------------------------------
m12() { perl -0pi -e "s/                    local ok1, shipped = pcall\(pred\)\n                    armed = true\n/                    local ok1, shipped = pcall(pred)\n                    armed = false\n/" "$SWEEP"; }
mutant caught "M12 the armed leg is driven disarmed (flips -> 0)" "$SWEEP" m12

m13() { perl -0pi -e "s/                    local ok1, shipped = pcall\(pred\)\n/                    armed = true\n                    local ok1, shipped = pcall(pred)\n/" "$SWEEP"; }
mutant caught "M13 the shipped baseline is driven armed" "$SWEEP" m13

# --- M14: the arming is too wide ---------------------------------------------
# SURVIVED the first run of the 'stayattr' stand; caught here by `arm_leak`,
# which names the four siblings sharing this path.
m14() { perl -0pi -e "s/                        return armed and sId == 'buyband'\n                    end\n\n                    local nHP/                        return armed\n                    end\n\n                    local nHP/" "$SWEEP"; }
mutant caught "M14 the stub arms every candidate, not just this one" "$SWEEP" m14

# --- M15: the two routes stop being two --------------------------------------
# The independent prefix walk drops the "carries nothing" clause, so it counts a
# larger population than the driven flip set. The cross-check is the only thing
# that makes either number evidence rather than an assertion about itself.
m15() { perl -0pi -e "s/                        and not bRingBusy and not bAttr and not bTower\n                        and not bMain\n                    then\n                        bump\('hurt_domain'\)/                        and not bRingBusy and not bAttr and not bTower\n                    then\n                        bump('hurt_domain')/" "$SWEEP"; }
mutant caught "M15 the prefix walk drops the empty-handed clause" "$SWEEP" m15

# --- M16: ⭐ a zero that was never measured ----------------------------------
# The mutant this stand's newest counter exists for. `overlap_buy_hurt == 0` is a
# claim whose entire content is a zero; a probe that stops driving prints exactly
# the same zero as one that drove 1012 frames and found nothing. Nothing else in
# the suite contradicts it -- which is why the probe now counts its own drives.
m16() { perl -0pi -e "s/                            if okh and okb then bump\('overlap_probe_runs'\) end\n/                            if false then bump('overlap_probe_runs') end\n/" "$SWEEP"; }
mutant caught "M16 the disjointness probe stops driving (a fake zero)" "$SWEEP" m16

# --- M17: the lever is simplified into the trap it avoids --------------------
# The reviewer's tidy-up: replace three duplicated clauses with the call they
# were copied from. Strictly shorter, passes luacheck, and silently caps this
# lever's band at the sibling's 0.55 -- so the lever becomes a no-op that still
# passes its own gate. This is edit (b)/(c) of the file header arriving by
# accident rather than by decision.
#
# ⚠️ RE-ANCHORED 2026-09-06 for the same reason as M9, and this one was worse:
# the span started at the FIRST ring line in the file, so it ran from
# J.IsFieldRegenSituation's own ring clause to J.IsFieldRegenSituation's own
# tower clause and replaced the middle of the SHARED predicate with a call to
# ITSELF -- infinite recursion, suite red, CAUGHT. The right colour from a
# program that is not the one the label describes. Anchored on the same unique
# comment pair M9 now uses.
m17() { perl -0pi -e "s/-- third bullet above\. tests\/_buyband_sweep\.lua parses both copies\.\n\tif #J\.GetNearbyHeroes\( bot, 1600, true, BOT_MODE_NONE \) > 0 then return false end\n\n\t-- Attributed danger.*?\tif #bot:GetNearbyTowers\( 1200, true \) > 0 then return false end\n/-- third bullet above. tests\/_buyband_sweep.lua parses both copies.\n\tif not J.IsFieldRegenSituation( bot ) then return false end\n/s" "$JMZ"; }
mutant caught "M17 the copied clauses are folded back into a call" "$JMZ" m17

# --- M18: DECLARED UNMEASURABLE ----------------------------------------------
# See the header: of the 20 domain frames exactly 1 carries recent hero damage at
# all, and that damage is UNATTRIBUTED (it is the global-ult shape 'stayattr'
# exists for), so removing the attributed veto changes no frame in this corpus.
# The drift guard cannot see it either -- the constants are untouched.
m18() { perl -0pi -e "s/\t\t\tif J\.IsValidHero\( hEnemy \)\n\t\t\t\tand bot:WasRecentlyDamagedByHero\( hEnemy, 3\.0 \)\n\t\t\tthen\n\t\t\t\treturn false\n\t\t\tend\n\t\tend\n\tend\n\n\tif #bot:GetNearbyTowers/\t\t\tif J.IsValidHero( hEnemy )\n\t\t\t\tand bot:WasRecentlyDamagedByHero( hEnemy, 3.0 )\n\t\t\tthen\n\t\t\t\tbHurtSeen = true\n\t\t\tend\n\t\tend\n\tend\n\n\tif #bot:GetNearbyTowers/" "$JMZ"; }
mutant unmeasurable "M18 the copied attribution veto stops vetoing" "$JMZ" m18

# --- M19: the control --------------------------------------------------------
m19() { perl -0pi -e "s/-- \[buyband \/ owner priority P2 supply side, 2026-09-06\] The band between the two/-- [buyband \/ owner priority P2 supply side, 2026-09-06] The BAND between the two/" "$JMZ"; }
mutant survive "M19 a comment inside the lever's own block is reworded" "$JMZ" m19

echo "---"
echo "mutants run: $nrun   landed as declared: $ncaught   unmeasurable+equivalent: $nunmeas   NOT as declared: $nbad"
if [ "$nbad" -ne 0 ]; then
    echo "STAND RED: $nbad mutant(s) did not land as declared."
    exit 1
fi
echo "STAND GREEN"
exit 0

#!/usr/bin/env bash
# Mutation stand for tests/test_stayattr_global_ult.lua (test_set.md §EP).
#
# WHAT IT IS FOR. This round narrows one clause of a PROMOTED function -- the
# chase read in J.ShouldStayAndRegen, live in every turbo game -- and the case
# for it is a driven before/after on real frames plus a 1012-frame domain price.
# Both legs come from the same shipped function with one soak id toggled, so the
# forgeable surfaces are different from a shadow comparison's: here the danger
# is that the TOGGLE stops toggling (both legs read the same thing and the flip
# count is 0 or 1012 for reasons unrelated to the lever), or that the census
# reports a plausible number about the wrong population.
#
# The shapes under test:
#   * THE LEVER LEAVES OR INVERTS (M1, M2, M3) -- the disjunct is deleted, or
#     the negation is dropped, or the scan is inverted. M2 and M3 are the
#     dangerous ones: both still read like the fix, both compile, and both send
#     the guard's answer the other way. M3 in particular flips the lever from
#     "keep the veto only when someone who hit me is near" to "keep it only when
#     nobody is" -- which is the change a reviewer skims past;
#   * THE PULLCAD TRAP (M4) -- a second soak id appears in the function, making
#     the live condition a conjunction that freezes FALSE the day either id is
#     promoted, while check_armed_wiring.py still calls it WIRED (it checks that
#     a call site exists, not that the predicate can ever be true);
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M5) -- strip_comments leaves
#     the sweep. The shipped clause's own comment names IsSoakCandidate twice
#     while explaining the trap, so STAY_NIDS reads 3 off prose. This is not
#     hypothetical: the identical bug fired for real on the §EN sweep's first
#     run, where a counter that had to read 0 read 1 off the comment saying why
#     it was 0;
#   * THE TOGGLE STOPS TOGGLING (M6, M7) -- the sweep's armed leg is taken
#     disarmed (flips -> 0, and the round reports "no effect", which is the
#     droppick/argfix shape and the SAFE-LOOKING direction), or the disarmed leg
#     is taken armed (the shipped baseline is not the shipped tree);
#   * THE ARMING IS TOO WIDE (M8) -- the sweep arms every candidate instead of
#     just this one. Then any of the other 140 live gates can move the answer
#     and the flip is attributed to this lever anyway;
#   * THE PARTITION STOPS PARTITIONING (M9, M10) -- a defect-shape frame lands
#     in the wrong bucket, or a bucket becomes unreachable. The four buckets are
#     the only thing keeping "the lever is inert on this frame" apart from "the
#     situation does not occur", and the sum assertion is what makes them
#     answerable. ⚠️ M10 is DECLARED UNMEASURABLE on this corpus and says why:
#     see its call site;
#   * A CONSTANT MOVES UNDER THE CENSUS (M11, M12) -- the scan radius or the HP
#     band changes, so every ratcheted count is about a different population
#     than the one reported, while the numbers still look reasonable;
#   * THE HELPER GROWS A SECOND CALLER (M13) -- the one-lever claim dies quietly:
#     the promoted sibling scan starts sharing this code, which is precisely the
#     refactor the source comment says was avoided.
#
# CONTROL (must SURVIVE): M14 rewrites a COMMENT in the shipped clause. Nothing
# in this suite is allowed to be satisfied by prose, so a comment edit must not
# be able to turn it red. A stand where every mutant is caught cannot tell a
# sharp assertion from one that fires on anything.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_stayattr.sh
#
# TWO OF THESE WERE WRITTEN AFTER THE FACT, and both entries earned their keep
# by surviving the first run rather than by being thought of: M8 exposed a real
# assertion gap (nothing could tell a one-id stub from an all-ids one, because
# on this corpus they give the same numbers) and is now caught; M10 exposed a
# vacuous zero and is now declared. A stand whose every mutant was caught on the
# first run has usually not been pointed at anything.
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED, or
# the control was CAUGHT (rule 2: suspect the assertion before the mutation --
# and per its converse, read the diff first: a regex that misses prints NO-OP, a
# regex that hits the wrong place prints SURVIVED while the subject is
# untouched; that converse cost the midsupmirror stand two rounds).
#
# SLOW ON PURPOSE: every mutant re-runs a 109-fixture, 1012-frame sweep in which
# the guard is driven twice per frame. The sweep is the thing under test;
# running it once and reusing the output would test nothing.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

JMZ=bots/FunLib/jmz_func.lua
SWEEP=tests/_stayattr_sweep.lua
TEST=test_stayattr_global_ult

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

# want=caught (a real mutant), want=survive (a control), or want=unmeasurable
# (a real mutant this corpus provably cannot catch, with the reason recorded at
# the call site). An UNMEASURABLE is NOT a pass and NOT a failure: it is the
# stand admitting which of its own claims currently rest on a vacuous branch.
# Declaring it beats deleting the mutant -- a deleted mutant is a gap nobody
# can see, and the day the corpus grows the frame that fills it, the entry says
# what to re-run.
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
            # Good news, and it must not be silent: the corpus grew the frame
            # that makes this branch matter, so the declaration is now stale.
            nbad=$((nbad + 1))
            printf 'CAUGHT    %-58s exit=%s  ** re-classify as `caught` **\n' "$label" "$rc"
            echo "          ^ the corpus can now witness this branch; the"
            echo "            UNMEASURABLE note at the call site is out of date."
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

# --- M1, M2, M3: the lever leaves, or lands inverted -------------------------
m1() { perl -0pi -e "s/\n\t\tand \( not J\.IsSoakCandidate\( 'stayattr' \)\n\t\t\tor J\.HasNearbyHeroDamager\( bot, 3000, 3\.0 \) \)//" "$JMZ"; }
mutant caught "M1 the gated disjunct is deleted (shipped read restored)" "$JMZ" m1

# The reviewable-looking inversion: same call, same place, no `not`. Unarmed the
# guard now never vetoes on hero damage at all -- a change to SHIPPED behaviour
# wearing the shape of a gated one.
m2() { perl -0pi -e "s/and \( not J\.IsSoakCandidate\( 'stayattr' \)/and ( J.IsSoakCandidate( 'stayattr' )/" "$JMZ"; }
mutant caught "M2 the gate lands un-negated (shipped path inverted)" "$JMZ" m2

# The other half of the same trick, and the one a reviewer skims: keep the veto
# only when nobody who hit me is near. Compiles, reads like the fix, is its
# opposite.
m3() { perl -0pi -e "s/\t\t\tor J\.HasNearbyHeroDamager\( bot, 3000, 3\.0 \) \)/\t\t\tor not J.HasNearbyHeroDamager( bot, 3000, 3.0 ) )/" "$JMZ"; }
mutant caught "M3 the attributed scan is negated (lever inverted)" "$JMZ" m3

# --- M4: the pullcad trap ----------------------------------------------------
m4() { perl -0pi -e "s/\t\tand \( not J\.IsSoakCandidate\( 'stayattr' \)/\t\tand ( not J.IsSoakCandidate( 'stayfield' )\n\t\t\tor not J.IsSoakCandidate( 'stayattr' )/" "$JMZ"; }
mutant caught "M4 a second soak id joins the condition (pullcad trap)" "$JMZ" m4

# --- M5: the instrument reads prose instead of code --------------------------
# The shipped clause's comment names IsSoakCandidate while explaining the trap,
# so without stripping, STAY_NIDS counts the warning as the violation. The
# identical bug fired for real on the §EN sweep's first run.
m5() { perl -0pi -e "s/local stay = strip_comments\(block\(src, 'function J\.ShouldStayAndRegen\( bot \)'\)\)/local stay = block(src, 'function J.ShouldStayAndRegen( bot )')/" "$SWEEP"; }
mutant caught "M5 the sweep stops stripping comments before parsing" "$SWEEP" m5

# --- M6, M7: the toggle stops toggling ---------------------------------------
# M6: the armed leg is taken disarmed. flips -> 0 and the round reports "this
# lever does nothing" -- the droppick/argfix shape, in the direction that looks
# like an honest negative result rather than like a broken instrument.
# Anchored on the assignment alone, NOT on the assignment plus the pcall that
# used to follow it: the arm_leak probe landed between them and turned the
# original two-line anchor into a NO-OP -- a mutant that silently stopped
# existing while the stand still printed a line about it. That is the converse
# of rule 2 (a regex that misses prints NO-OP), and it is why NO-OP counts as
# `not as declared` here rather than being waved through.
m6() { perl -0pi -e 's/\n                    armed = true\n/\n                    armed = false\n/' "$SWEEP"; }
mutant caught "M6 the armed leg is measured with the gate still off" "$SWEEP" m6

# M7: the baseline leg is taken armed, so "shipped" is not the shipped tree.
m7() { perl -0pi -e 's/                    local ok1, shipped = pcall\(J\.ShouldStayAndRegen, bot\)/                    armed = true\n                    local ok1, shipped = pcall(J.ShouldStayAndRegen, bot)/' "$SWEEP"; }
mutant caught "M7 the baseline leg is measured with the gate armed" "$SWEEP" m7

# --- M8: the arming is too wide ----------------------------------------------
# 141 live gate ids exist in this tree. Arm them all and any of the other 140
# can move this guard's answer, while the flip is still reported as this one's.
m8() { perl -0pi -e "s/                        return armed and sId == 'stayattr'/                        return armed/" "$SWEEP"; }
mutant caught "M8 the sweep arms every candidate, not just this one" "$SWEEP" m8

# --- M9, M10: the partition stops partitioning -------------------------------
# M9: an out-of-band frame is filed as supply-blocked. Both buckets still exist,
# the sum still holds, and "the supply clause is what stops P2's own frame"
# becomes a claim about a frame that never reached that clause.
m9() { perl -0pi -e "s/                                sBucket = 'unattr_out_of_band'/                                sBucket = 'unattr_blocked_supply'/" "$SWEEP"; }
mutant caught "M9 out-of-band frames are filed as supply-blocked" "$SWEEP" m9

# M10: the ring bucket can never be reached, so the zero that honest bound (1)
# rests on becomes a zero about a branch instead of about the world -- the
# GH #171 shape, where "never measured" and "measured zero" print the same.
# ⚠️ DECLARED UNMEASURABLE, and this is the stand's own most useful line.
# On this corpus all five in-band unattributed frames have an EMPTY 1200 ring,
# so `unattr_blocked_ring` is 0 whether the branch runs or not: killing it
# changes no number any assertion can see. The zero that honest bound (1) rests
# on is therefore VACUOUS -- it says "no measured frame put the untouched ring
# to work", not "the ring covers the case". It survived the stand's first run
# and the honest response was to say so, in the test file and here, rather than
# to invent an assertion that would fire for some other reason.
# What IS now asserted is the branch's REACHABILITY (`unattr_ring_tested`), so
# the bucket can no longer be a zero about a branch instead of about the world
# (the GH #171 shape). When a fixture lands a ring-occupied unattributed frame,
# this mutant becomes catchable and the `unmeasurable` above must become
# `caught` -- the stand prints a re-classification notice on that day.
m10() { perl -0pi -e 's/                                if #J\.GetNearbyHeroes\(bot, G\.STAY_RING, true,\n                                    BOT_MODE_NONE\) > 0 then/                                if false then/' "$SWEEP"; }
mutant unmeasurable "M10 the 1200-ring bucket becomes unreachable" "$SWEEP" m10

# --- M11, M12: a constant moves under the census -----------------------------
# M11: the scan radius widens to the whole map, so every hero-damage frame reads
# as attributed, unattributed -> 0, and the lever is a no-op on a corpus that
# still produces a full, plausible-looking manifest.
m11() { perl -0pi -e 's/or J\.HasNearbyHeroDamager\( bot, 3000, 3\.0 \) \)/or J.HasNearbyHeroDamager( bot, 99999, 3.0 ) )/' "$JMZ"; }
mutant caught "M11 the attributed scan radius widens to the map" "$JMZ" m11

# M12: the HP band moves, so hp_band, the four buckets and both TRUE sets are
# all about a different population -- and every one of them still looks sane.
m12() { perl -0pi -e 's/\tif nHP < 0\.18 or nHP > 0\.75 then return false end/\tif nHP < 0.10 or nHP > 0.90 then return false end/' "$JMZ"; }
mutant caught "M12 the HP band widens under the census" "$JMZ" m12

# --- M13: the helper grows a second caller -----------------------------------
# The source comment argues that the promoted sibling scan was deliberately NOT
# refactored to share this code. Make it share, and the one-lever claim is false
# while every behavioural assertion above still passes -- the lanefix shape.
m13() { perl -0pi -e 's/\t\tlocal hEnemyList = J\.GetNearbyHeroes\( bot, 3000, true, BOT_MODE_NONE \)\n\t\tfor _, hEnemy in pairs\( hEnemyList \) do\n\t\t\tif J\.IsValidHero\( hEnemy \)\n\t\t\t\tand bot:WasRecentlyDamagedByHero\( hEnemy, 3\.0 \)\n\t\t\tthen\n\t\t\t\treturn false\n\t\t\tend\n\t\tend/\t\tif J.HasNearbyHeroDamager( bot, 3000, 3.0 ) then return false end/' "$JMZ"; }
mutant caught "M13 the promoted sibling scan is refactored to share" "$JMZ" m13

# --- M14: the CONTROL, which must survive ------------------------------------
# A comment inside the shipped clause is rewritten, and one of the numbers in it
# is falsified. Nothing here may be satisfied by prose, so this must stay green.
# (The numbers in comments are audited by the citation tooling, not by this
# suite -- that separation is the point.)
m14() { perl -0pi -e 's/\t-- off, and this line still vetoes\. J\.IsFieldRegenSituation -- the gated/\t-- off (it was 66 units), and this line still vetoes. Also the gated/' "$JMZ"; }
mutant survive "M14 CONTROL: a comment in the clause is falsified" "$JMZ" m14

echo
echo "mutants run: $nrun   landed as declared: $ncaught   declared unmeasurable: $nunmeas   not as declared: $nbad"
[ "$nbad" -eq 0 ] || exit 1

#!/usr/bin/env bash
# Mutation stand for tests/test_outchan_domain.py (test_set.md §EO, GH #511).
#
# WHAT IT IS FOR. This round lands NO behaviour change. Its whole product is a
# NEGATIVE verdict -- "GH #511's proposed one-liner is a no-op" -- plus the
# ratchet that keeps that verdict honest when its premises move. A negative
# verdict is the most forgeable thing this stream produces: every leg reports
# 0, and a probe that is simply broken reports 0 too. So the mutants here are
# aimed almost entirely at the INSTRUMENT, and specifically at the ways a
# broken instrument would still print the answer this round wants.
#
# The shapes under test:
#   * THE NO-OP LANDS ANYWAY (M1) -- someone adds `bot:IsChanneling()` to
#     mode_outpost_generic.lua exactly as #511 proposes. That is the outcome
#     this whole file exists to prevent, so the assertion had better fire;
#   * THE PREMISE OF THE VERDICT LEAVES (M2, M3) -- J.CanNotUseAction loses its
#     IsChanneling disjunct, or Think() stops calling it. Either one makes the
#     proposed line a REAL fix, and the §EN ratchet rule is precisely that this
#     must fire by itself: the edit unlocking it would happen in jmz_func.lua,
#     where nothing on this stream's backlog is looking;
#   * THE DEDUCTION LOSES ITS SOLE-SITE PREMISE (M4) -- a second ability_capture
#     cast site appears. "A logged cast proves the predicate was false" holds
#     only while every cast passes that one guard;
#   * THE GUARD SINKS BELOW THE CAST (M5) -- ordering, not presence, is what
#     makes it a guard. A file that still contains both tokens in the wrong
#     order reads clean to a grep and guards nothing;
#   * THE INSTRUMENT READS PROSE INSTEAD OF CODE (M6) -- strip_comments is
#     removed. This file's own docstring quotes `bot:IsChanneling()` several
#     times, so without it the M1 assertion is satisfied by the DOCUMENTATION
#     that explains why the guard is absent. §EN paid a round for this exact
#     bug; M6 is it re-committed one file over;
#   * THE ISSUEFIX LEG STOPS BEING ABLE TO SAY YES (M7, M8) -- the interval test
#     is inverted or emptied. Both keep printing 0/14 while measuring nothing;
#     M8 is the dangerous one, because an empty interval list is what a genuine
#     "no channels in this corpus" would also look like;
#   * THE ORDERING LEG COLLAPSES (M9, M10) -- ties get folded into the claim's
#     side, or the gap sign flips. #511's mechanism needs a cast BEFORE a
#     removal; a stand that cannot distinguish before from after cannot refute
#     it. M9 is the shape this round already made once and corrected: the
#     summary line said "every gap > 0" while the distribution printed four
#     zeros;
#   * THE ANTI-VACUUM CONTROL STOPS CONTROLLING (M11) -- the control is what
#     upgrades leg infile's three zeros from "stuck probe" to "reading". Break
#     it and every zero in section 2 becomes uninterpretable while still
#     printing as a pass;
#   * THE REAL FRAMES ARE REPLACED BY CONVENIENT ONES (M12) -- the fixture's
#     capture events are dropped. The corpus is the subject; a stand that
#     passes on an empty one is testing its own defaults.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_outchan.sh
#
# Exit 0 = every mutant CAUGHT. Exit 1 = a mutant SURVIVED (rule 2: suspect the
# assertion before the mutation -- and per its converse, read the diff first: a
# regex that misses prints NO-OP, a regex that hits the wrong place prints
# SURVIVED while the subject is untouched).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

MODE=bots/mode_outpost_generic.lua
JMZ=bots/FunLib/jmz_func.lua
FARM=bots/mode_farm_generic.lua
TOOL=tools/batch_test/behavioral/outchan_domain.py
TESTF=tests/test_outchan_domain.py
FIX=tests/fixtures/tl_260905_010205_luna_outchan.json

TMP=$(mktemp -d)
nrun=0; ncaught=0
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
    python3 "$TESTF" > "$TMP/out.log" 2>&1 || rc=$?
    # A python traceback is a CAUGHT, but it must not be mistaken for an
    # assertion firing: name it so the reader can tell the two apart.
    if grep -q 'Traceback (most recent call last)' "$TMP/out.log"; then
        echo "${rc}T"
        return
    fi
    echo "$rc"
}

mutant() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" != "0" ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
        echo "          ^ per evidence-discipline rule 2, suspect the ASSERTION first;"
        echo "            per its converse, first confirm the edit landed where you meant."
    fi
}

# Two-file mutant: some hazards only exist as a PAIR of edits (see M6).
mutant2() {
    local label=$1 t1=$2 t2=$3; shift 3
    nrun=$((nrun + 1))
    cp "$t1" "$TMP/m2a.orig"; sha256sum "$t1" > "$TMP/m2a.sha"
    cp "$t2" "$TMP/m2b.orig"; sha256sum "$t2" > "$TMP/m2b.sha"
    INFLIGHT="$t1"
    "$@"
    local rc; rc=$(run_test)
    cp "$TMP/m2a.orig" "$t1"; cp "$TMP/m2b.orig" "$t2"
    if ! sha256sum -c "$TMP/m2a.sha" >/dev/null || ! sha256sum -c "$TMP/m2b.sha" >/dev/null; then
        echo "FATAL: restore of $t1/$t2 did not verify -- stopping"
        exit 2
    fi
    INFLIGHT=""
    if [ "$rc" != "0" ]; then
        ncaught=$((ncaught + 1))
        printf 'CAUGHT    %-58s exit=%s\n' "$label" "$rc"
    else
        printf 'SURVIVED  %-58s exit=%s\n' "$label" "$rc"
    fi
}

# A control, not a mutant: an edit that MUST NOT move the verdict. It counts
# toward the tally only when it behaves -- an assertion that fires on a benign
# comment is a false alarm generator, and this is where that shows up.
mutant_expect_pass() {
    local label=$1 target=$2; shift 2
    nrun=$((nrun + 1))
    save "$target"
    "$@"
    if cmp -s "$target" "$TMP/$(basename "$target").orig"; then
        restore "$target"
        printf 'NO-OP     %-58s (the edit matched nothing)\n' "$label"
        return
    fi
    local rc; rc=$(run_test)
    restore "$target"
    if [ "$rc" = "0" ]; then
        ncaught=$((ncaught + 1))
        printf 'CONTROL   %-58s exit=%s (correctly did not fire)\n' "$label" "$rc"
    else
        printf 'FALSE-RED %-58s exit=%s\n' "$label" "$rc"
        echo "          ^ a benign comment moved the verdict: the assertion is"
        echo "            reading prose. That is the bug M6 is about, not a catch."
    fi
}

echo "=== mutants against the tree (the verdict's premises) ==="

# --- M1: #511's fix lands as written -----------------------------------------
m1() { perl -0pi -e 's/(function Think\(\)\n)/$1\tif bot:IsChanneling\(\) then return end\n/' "$MODE"; }
mutant "M1 #511's redundant guard is added to Think()" "$MODE" m1

# --- M2, M3: the premise that makes it redundant leaves ----------------------
m2() { perl -0pi -e 's/\t\t\tor bot:IsChanneling\(\)\n//' "$JMZ"; }
mutant "M2 J.CanNotUseAction loses its IsChanneling disjunct" "$JMZ" m2

m3() { perl -0pi -e 's/\tif J\.CanNotUseAction\(bot\) then return end\n//' "$MODE"; }
mutant "M3 Think() stops calling J.CanNotUseAction" "$MODE" m3

# --- M4: the sole-cast-site premise ------------------------------------------
m4() { perl -0pi -e "s/^(local J = require)/local _decoy = 'ability_capture'\n\$1/m" "$FARM"; }
mutant "M4 a second ability_capture reference appears" "$FARM" m4

# --- M5: the guard sinks below the cast --------------------------------------
# Both tokens still present, and the file still greps clean; only the ORDER is
# wrong, which is the whole of what makes a guard a guard.
m5() {
    perl -0pi -e 's/\tif J\.CanNotUseAction\(bot\) then return end\n//' "$MODE"
    perl -0pi -e 's/(\t\t\t\tbot:Action_UseAbilityOnEntity\(hAbilityCapture, ClosestOutpost\)\n)/$1\t\t\t\tif J.CanNotUseAction(bot) then return end\n/' "$MODE"
}
mutant "M5 the guard moves below the cast (order, not presence)" "$MODE" m5

echo
echo "=== mutants against the instrument (how a 0 gets forged) ==="

# --- M6: the instrument reads prose ------------------------------------------
# Two files on purpose. Defeating strip_comments alone changes nothing TODAY,
# because no comment in the tree happens to contain the tokens the assertions
# look for -- so a one-file M6 would print SURVIVED and mean nothing. The
# hazard is the PAIR: the natural comment a reviewer would write while closing
# #511 ("no bot:IsChanneling() guard needed here, J.CanNotUseAction has it"),
# plus an instrument that reads prose. Then the guard-absent assertion fires on
# the sentence explaining why the guard is absent. §EN paid a round for exactly
# this, one file over.
#
# The control half is asserted first: with strip_comments intact, that comment
# must NOT move the verdict.
m6ctl() { perl -0pi -e "s{^function Think\(\)}{-- no bot:IsChanneling() guard needed here: J.CanNotUseAction has it\nfunction Think()}m" "$MODE"; }
mutant_expect_pass "M6a the reviewer comment alone (must NOT fire)" "$MODE" m6ctl

m6() {
    perl -0pi -e "s{^function Think\(\)}{-- no bot:IsChanneling() guard needed here: J.CanNotUseAction has it\nfunction Think()}m" "$MODE"
    perl -0pi -e 's/^def strip_comments\(src\):/def strip_comments(src):\n    return src  # MUTANT/m' "$TESTF"
}
mutant2 "M6b that comment plus a prose-reading instrument" "$MODE" "$TESTF" m6

# --- M7, M8: the issuefix leg loses the ability to answer yes -----------------
m7() { perl -0pi -e 's/if any\(lo < c\["t"\] < hi for lo, hi in intervals\):/if not any(lo < c["t"] < hi for lo, hi in intervals):/' "$TOOL"; }
mutant "M7 the live-channel interval test is inverted" "$TOOL" m7

m8() { perl -0pi -e 's/^        intervals = \[\]$/        intervals = []\n        ep_adds = []  # MUTANT/m' "$TOOL"; }
mutant "M8 the interval list is silently emptied (still prints 0/14)" "$TOOL" m8

# --- M9, M10: the ordering leg collapses -------------------------------------
m9() { perl -0pi -e 's/            if gap < 0:/            if gap <= 0:/' "$TOOL"; }
mutant "M9 ties are folded into the claim's side" "$TOOL" m9

m10() { perl -0pi -e 's/            gap = round\(later\[0\]\["t"\] - rem\["t"\], 3\)/            gap = round(rem["t"] - later[0]["t"], 3)/' "$TOOL"; }
mutant "M10 the gap sign is flipped" "$TOOL" m10

# --- M11: the anti-vacuum control stops controlling --------------------------
m11() { perl -0pi -e 's/^            if enemies_in_vision\(frame, me, me\["team"\]\):$/            if False:  # MUTANT/m' "$TOOL"; }
mutant "M11 the anti-vacuum control is wired to zero" "$TOOL" m11

# --- M12: the real frames are replaced by convenient ones --------------------
m12() { python3 - "$FIX" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['events'] = [e for e in d['events']
               if e.get('inflictor') != 'ability_capture']
json.dump(d, open(p, 'w'), indent=1)
PY
}
mutant "M12 the fixture's capture casts are dropped" "$FIX" m12

echo
echo "ran=$nrun caught=$ncaught"
[ "$ncaught" -eq "$nrun" ] || exit 1

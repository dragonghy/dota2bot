#!/usr/bin/env bash
# Mutation stand for tools/batch_test/behavioral/stayattr_domain.py --selfcheck.
#
# WHAT IT IS FOR. That probe is the instrument this desk used to rule on
# `stayattr`'s condition (a) from W48 frames, and a probe that answers
# DOMAIN-NOT-REACHED is exactly the shape that can be wrong without anybody
# noticing: an empty domain looks the same whether the lever really is inert on
# this corpus or whether one clause is silently rejecting every frame. A
# selfcheck that has never been mutated cannot tell those two apart, and this
# round's own history says so twice -- 1c and 9b/11a were WRONG CONTROLS that
# passed review and were caught only by running them.
#
# The forgeries that matter here, each with the mutant that stands for it:
#
#   * A CLAUSE STOPS REJECTING (M1-M5). Widen the hp band, zero the damager
#     radius, drop the 1200 ring, wave through the regen source, or stretch the
#     damage window, and the domain gets BIGGER -- the direction that
#     manufactures a condition-(a) reading out of nothing. This is the one that
#     would have turned "0 armed frames" into a promote.
#   * THE CROSS-STREAM JOIN DEGRADES (M6). `canon` instead of `hkey` drops
#     Vengeful Spirit entirely (GH #303) -- a whole hero, silently, in the
#     direction of a SMALLER domain. That is the reading this round actually
#     published, so the join has to be pinned or the null is unearned.
#   * THE TP DISCRIMINATION COLLAPSES (M7-M8). `tp_home` is the airtight half
#     of the decision readout precisely because it requires a spent scroll AND
#     a jump TOWARD the fountain. Drop either conjunct and a respawn or a
#     retreat past the fountain reads as "went home by TP".
#   * THE STAMP PARSER GETS SLOPPY (M9-M10). Accepting `ab` as a side token, or
#     matching the armed id by substring, both produce a corpus that looks
#     scored and is not. `stayfield` vs `stayfield2` is the live substring pair.
#
# CONTROL (must SURVIVE): M11 rewrites prose inside the module docstring.
# Nothing in this suite may be satisfied by a comment, and a stand where every
# mutant is caught cannot distinguish a sharp assertion from one that fires on
# anything.
#
# Each mutant edits the file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would silently discard the
# uncommitted work that is the whole subject here).
#
#   bash tools/agent/mutstand_stayattr_domain.sh
#
# Exit 0 = every mutant landed as declared. Exit 1 = a real mutant SURVIVED,
# the control was CAUGHT, or an edit matched nothing (NO-OP counts as
# non-compliant, not as a pass: a mutant that never existed still prints a
# line).
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TOOL=tools/batch_test/behavioral/stayattr_domain.py

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

# Evidence-discipline rule 3: read the exit code directly, never through a pipe.
run_selfcheck() {
    local rc=0
    python3 "$TOOL" --selfcheck > "$TMP/self.log" 2>&1 || rc=$?
    echo "$rc"
}

mutant() {
    local want=$1 label=$2; shift 2
    nrun=$((nrun + 1))
    save "$TOOL"
    "$@"
    if cmp -s "$TOOL" "$TMP/$(basename "$TOOL").orig"; then
        restore "$TOOL"
        printf 'NO-OP     %-58s (the edit matched nothing -- the mutant never existed)\n' "$label"
        nbad=$((nbad + 1))
        return
    fi
    local rc; rc=$(run_selfcheck)
    restore "$TOOL"
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
            echo "          ^ a prose edit turned this suite red: something in it"
            echo "            is being satisfied by a comment rather than by code."
        fi
    fi
}

# --- M1..M5: a rejection clause stops rejecting (the domain grows) ------------

m1() { perl -0pi -e 's/^HP_LO, HP_HI = 0\.18, 0\.75/HP_LO, HP_HI = 0.0, 1.0/m' "$TOOL"; }
mutant caught "M1 hp band widened to the whole bar" m1

m2() { perl -0pi -e 's/^DAMAGER_RADIUS = 3000\.0/DAMAGER_RADIUS = 0.0/m' "$TOOL"; }
mutant caught "M2 damager radius zeroed (nobody is ever near)" m2

m3() { perl -0pi -e 's/^            if ring_enemy:$/            if False:/m' "$TOOL"; }
mutant caught "M3 the 1200 ring (:5121) stops vetoing" m3

m4() { perl -0pi -e 's/(\"\"\"The OBSERVABLE half of `bHasFlask` \(jmz_func\.lua:5122-5124\)\.\"\"\"\n)/$1    return True\n/' "$TOOL"; }
mutant caught "M4 regen source waved through (gold clause forged)" m4

m5() { perl -0pi -e 's/^DAMAGE_WINDOW_S = 3\.0/DAMAGE_WINDOW_S = 100.0/m' "$TOOL"; }
mutant caught "M5 damage window stretched 3s -> 100s" m5

# --- M6: the cross-stream join degrades (the domain SHRINKS, silently) --------
# The direction matters: this one makes the null LOOK stronger, so a stand that
# only mutates toward a bigger domain would not cover the reading published.
#
# ⚠️ THE FIRST CUT OF M6 SURVIVED, AND THE MUTANT WAS WRONG, NOT THE ASSERTION.
# It degraded the INDEX side (`hkey` -> `canon` inside `damage_index`, i.e. on
# the EVENT spelling). Measured:
#
#     canon('...vengefulspirit')  == 'vengefulspirit'   <- no underscore to lose
#     hkey ('...vengeful_spirit') == 'vengefulspirit'
#
# so on the event side `canon` and `hkey` are THE SAME FUNCTION for exactly the
# names GH #303 is about -- the collapse only has work to do where the dumper
# INSERTED an underscore, which is the snapshot side. Degrading the index side
# therefore cannot break the join and must not be scored as covering it.
# The defect direction is the QUERY side, which is what M6 now mutates.
# General rule, and it is the same one the 2026-09-05T06:57Z stand paid for:
# a mutant has to model the defect's own direction, or its CAUGHT/SURVIVED says
# nothing about the check it was aimed at.
m6() { perl -0pi -e "s/        hk = entities\.hkey\(h\)/        hk = entities.canon(h)/" "$TOOL"; }
mutant caught "M6 victim join queries with canon, not hkey (GH #303)" m6

# M6b: the attacker half of the same join, mutated independently. The victim
# and the attacker are separate lookups and a stand that only covers one would
# leave the other free to rot.
m6b() { perl -0pi -e "s/entities\.hkey\(e\) in recent_attackers/entities.canon(e) in recent_attackers/" "$TOOL"; }
mutant caught "M6b attacker join queries with canon, not hkey" m6b

# --- M7..M8: the TP discrimination collapses ---------------------------------

m7() { perl -0pi -e 's/    if not consumed:\n        return False\n//' "$TOOL"; }
mutant caught "M7 tp_home drops the spent-scroll conjunct" m7

# M8 is not invented: it is verbatim the first cut of this function, the one a
# real frame (necrolyte's cross-map rotation TP) proved wrong. A mutant that
# reproduces a defect the corpus actually produced is worth more than one that
# reproduces a defect nobody would write.
m8() { perl -0pi -e "s/        if closed > HOME_PROGRESS_U:/        if closed > 0:/" "$TOOL"; }
mutant caught "M8 tp_home direction test weakened to 'any progress'" m8

# M8b: the jump-size conjunct, mutated on its own, so M8 and M8b each answer
# for one clause rather than jointly.
m8b() { perl -0pi -e "s/        if _dist\(a\['x'\], a\['y'\], b\['x'\], b\['y'\]\) <= TP_JUMP_U:/        if False:/" "$TOOL"; }
mutant caught "M8b tp_home stops requiring a jump at all" m8b

# --- M9..M10: the stamp parser gets sloppy -----------------------------------

m9() { perl -0pi -e 's/    if side not in ARMED_TEAM:\n        return \(None, None, None\)\n//' "$TOOL"; }
mutant caught "M9 leg_of accepts any side token (ab/ba included)" m9

m10() { perl -0pi -e "s/    return cand_id in \[x\.strip\(\) for x in body\.split\(','\)\]/    return cand_id in body/" "$TOOL"; }
mutant caught "M10 armed_in_stamp matches the id by substring" m10

# --- M11: the control ---------------------------------------------------------

m11() { perl -0pi -e 's/Read-only, offline; consumes dumper timelines\./Read-only, offline; consumes dumper timelines (prose edit)./' "$TOOL"; }
mutant survived "M11 CONTROL: prose edit inside the module docstring" m11

echo
echo "mutants run: $nrun   landed as declared: $ncaught   non-compliant: $nbad"
if ! sha256sum -c "$TMP/$(basename "$TOOL").sha" >/dev/null 2>&1; then
    echo "FATAL: $TOOL does not match its pre-stand checksum"
    exit 2
fi
echo "restore verified: $TOOL matches its pre-stand sha256"
[ "$nbad" -eq 0 ] || exit 1

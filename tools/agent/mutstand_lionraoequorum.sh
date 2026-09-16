#!/usr/bin/env bash
# Mutation stand for tests/test_lion_ult_aoe_quorum.lua -- the hero desk's
# pricing of the `nMaxAoeCount >= 4` quorum in hero_lion.lua X.ConsiderR, and
# its BUNDLE-ONLY ruling (no id landed on that term this round).
#
# ⚠️ NO GATED ID SHIPS THIS ROUND, so this is not a "does the gate work" stand.
# What it prices is whether the FILE CAN STILL FAIL.  The headline of the round
# is a RATIO between two corpus counts, and a ratio is exactly what a broken
# enumerator hands out for free: an `ls` that yields nothing, a `find` that
# silently becomes the same list as the `ls`, a densest() that counts the pivot
# twice.  Groups:
#   A  the source facts the ruling reads          (M1-M5)
#   B  the corpus facts it reports                (M6-M9)
#   C  THE INSTRUMENT ITSELF                      (M10-M13)
#
# Usage:  bash tools/agent/mutstand_lionraoequorum.sh
# Exit 0 iff every mutant is KILLED.  Reads and restores from a file copy (never
# from git), per .claude/skills/evidence-discipline.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

TEST=tests/test_lion_ult_aoe_quorum.lua
LION=bots/BotLib/hero_lion.lua
KV=tests/mock/special_value_shapes.lua
# ⚠️ M8 mutates the CORPUS (a whole subdirectory), not a source file.  Per the
# mutstand_cmkillscan.sh lesson (2026-09-16): EVERY FILE A MUTANT TOUCHES
# BELONGS IN THE BACKUP LIST, and the list is not "the files the stand is
# about".  A leaked mutation does not merely dirty the tree -- it manufactures
# kills for every mutant that runs after it.  The subdirectory is handled in
# restore()/verify_restore() alongside the three files below.

TMP="$(mktemp -d)"
cp "$TEST" "$TMP/test.bak"
cp "$LION" "$TMP/lion.bak"
cp "$KV"   "$TMP/kv.bak"

PAIRS="$TEST:test.bak $LION:lion.bak $KV:kv.bak"
# Enumerated once, before anything is moved: verify_restore() compares against
# it rather than against a hardcoded name.
NSUBDIRS="$(find tests/fixtures -mindepth 1 -type d | wc -l)"

restore() {
    # M8 moves a whole corpus subdirectory rather than editing a file; it is
    # restored here for the same reason every mutated file is (a leaked mutation
    # manufactures kills for every mutant that runs after it).
    if [ -d "$TMP/subdirs" ]; then
        for d in "$TMP/subdirs"/*/; do
            [ -d "$d" ] || continue
            rm -rf "tests/fixtures/$(basename "$d")"
            mv "$d" tests/fixtures/
        done
    fi
    cp "$TMP/test.bak" "$TEST"
    cp "$TMP/lion.bak" "$LION"
    cp "$TMP/kv.bak"   "$KV"
}

# ⛔ RESTORING IS NOT THE SAME AS HAVING RESTORED.  Checked after every restore
# rather than once at the end, so a leak is caught on the mutant that caused it
# instead of five mutants later (tests/test_mutstand_restore_trap.py).
verify_restore() {
    local bad=0 f b pair
    if [ "$(find tests/fixtures -mindepth 1 -type d | wc -l)" -lt "$NSUBDIRS" ]; then
        echo "  RESTORE LEAK: tests/fixtures lost a corpus subdirectory"
        bad=1
    fi
    for pair in $PAIRS; do
        f="${pair%%:*}"; b="$TMP/${pair##*:}"
        if [ "$(sha256sum < "$f")" != "$(sha256sum < "$b")" ]; then
            echo "  RESTORE LEAK: $f does not match its pristine copy"
            bad=1
        fi
    done
    return $bad
}
trap 'restore; rm -rf "$TMP"' EXIT

KILLED=0
SURVIVED=0
ABORTED=0

run_suite() {
    timeout 300 lua5.1 tests/run_tests.lua "$(basename "$TEST")" >"$TMP/out" 2>&1
    return $?
}

mutant() {
    local label="$1"; shift
    restore
    if ! verify_restore; then
        echo "  ABORT   $label -- the tree was not pristine going in"
        ABORTED=$((ABORTED + 1))
        return
    fi
    if ! eval "$@"; then
        echo "  ABORT   $label -- the mutation did not apply (GH #846: an"
        echo "          unapplied mutant scores for free)"
        ABORTED=$((ABORTED + 1))
        return
    fi
    if run_suite; then
        echo "  SURVIVED $label"
        SURVIVED=$((SURVIVED + 1))
    else
        echo "  killed   $label"
        KILLED=$((KILLED + 1))
    fi
}

sub() {
    local file="$1" from="$2" to="$3"
    # ⚠️ `--` is load-bearing: M11's replacement text starts with `-maxdepth`,
    # and without it grep read that as an option and answered
    # `grep: invalid max count` -- which this stand then reported as ABORT.
    # An ABORT is not a survival, but it is also not a kill, and a stand that
    # aborts for a quoting reason has simply not asked its question.
    grep -qF -- "$from" "$file" || return 1
    python3 - "$file" "$from" "$to" <<'PY' || return 1
import sys
path, frm, to = sys.argv[1], sys.argv[2], sys.argv[3]
body = open(path, encoding='utf-8').read()
if frm not in body:
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(body.replace(frm, to, 1))
PY
    grep -qF -- "$to" "$file" || return 1
}

echo "=== baseline (unmutated) ==="
restore
if ! run_suite; then
    echo "BASELINE IS RED -- nothing below means anything."
    tail -20 "$TMP/out"
    exit 2
fi
echo "  baseline green"

echo
echo "=== group A: the source facts the ruling reads ==="

# M1  the quorum itself moves.  §1 exists so that a silent re-tune of this
#     constant invalidates the pricing instead of inheriting it.
mutant "M1  quorum 4 -> 5 in hero_lion.lua" \
    "sub '$LION' 'nMaxAoeCount >= 4' 'nMaxAoeCount >= 5'"

# M2  the low-HP fallback loses its health term.  Claim (3) is about the two
#     questions SHARING one expression; unconditional, it is a different file.
mutant "M2  fallback loses nHP < 0.46" \
    "sub '$LION' 'nMaxAoeCount >= 3 and nHP < 0.46' 'nMaxAoeCount >= 3'"

# M3  the seed.  densest() counts the pivot itself precisely to match
#     `nMaxAoeCount = 1` plus a strict `>`; move the seed and every §3 number is
#     off by one in a direction nobody would notice.
mutant "M3  nMaxAoeCount seeds at 0" \
    "sub '$LION' 'local nMaxAoeCount = 1' 'local nMaxAoeCount = 0'"

# M4  the counted SET changes, so the ceiling argument (team size 5) no longer
#     follows from what is counted.
mutant "M4  the AoE loop stops counting over J.GetEnemyList" \
    "sub '$LION' 'local hNearbyEnemyList = J.GetEnemyList' 'local hNearbyEnemyList = J.GetAllyList'"

# M5  reason (i) for the branch being dead disappears: the shipped splash key is
#     replaced by the live one, i.e. the branch silently stops being dead and §4
#     is stale without saying so.
mutant "M5  X.GetAbilityRSplashRadius drops the shipped key" \
    "sub '$LION' \"local nShipped = abilityR:GetSpecialValueInt( 'splash_radius_scepter' )\" \"local nShipped = abilityR:GetSpecialValueInt( 'splash_radius' )\""

echo
echo "=== group B: the corpus facts it reports ==="

# M6  the radius the whole pricing is stated against moves in the KV snapshot.
mutant "M6  KV scepter splash radius 325 -> 600" \
    "sub '$KV' \"['special_bonus_scepter'] = '325', ['affected_by_aoe_increase'] = '1'\" \"['special_bonus_scepter'] = '600', ['affected_by_aoe_increase'] = '1'\""

# M7  ⭐ reason (i) for the branch being dead evaporates: the `lionsplash` gate
#     leaves X.GetAbilityRSplashRadius, so the live key would be read by default
#     and the exit stops being dead.  §4 has to notice, because the moment it
#     happens this file's whole routing (to a wave, not to a helper) is wrong.
#     ⚠️ THE FIRST VERSION OF M7 MUTATED THE TEST'S OWN ASSERT into
#     `assert(true or ...)` and SURVIVED -- of course it did: disabling an
#     assertion cannot be detected by the suite that assertion belongs to.  That
#     was a defect in the mutant, not in the file (evidence-discipline rule 2).
mutant "M7  the lionsplash gate leaves X.GetAbilityRSplashRadius" \
    "sub '$LION' \"if J.IsModeTurbo() and J.IsSoakCandidate( 'lionsplash' )\" \"if J.IsModeTurbo() and J.IsSoakCandidate( 'lionsplashx' )\""

# M8  ⭐ the corpus-side twin of M11: the subdirectory frames go away, so the
#     recursive and the flat enumerator return the same list and §3c is §3a
#     wearing a hat.  M11 breaks the instrument, M8 breaks the corpus; only
#     both together show the assert is about the DIFFERENCE and not about
#     either side of it.
#     ⚠️ THE FIRST VERSION OF M8 scattered the single densest cluster and
#     SURVIVED.  That was the mutant being wrong about the file, not the file
#     being weak: §3c pins a RELATION (`n4 * 2 <= n3`) precisely so that corpus
#     churn does not break it, and removing a quorum frame moves that relation
#     in the SAFE direction.  A mutant has to push the reading toward the claim,
#     not away from it.
#     ⚠️ SECOND CORRECTION, same rule: v2 moved only `skillstall/` and survived
#     too, because `tests/fixtures/` holds TWO subdirectories today
#     (`skillstall/` 11 frames, `outchan/` 2) and `find` still outran `ls` on
#     the other one.  The assert is about the DIFFERENCE existing, not about any
#     one subdirectory -- so the mutant has to remove the difference, i.e. all
#     of them.  Enumerated, never hardcoded: a third subdirectory appearing must
#     not silently turn this mutant back into a survivor.
mutant "M8  every subdirectory corpus frame disappears" \
    "mkdir -p '$TMP/subdirs' && n=0 && for d in tests/fixtures/*/; do [ -d \"\$d\" ] || continue; mv \"\$d\" '$TMP/subdirs/' && n=\$((n+1)); done && [ \"\$n\" -gt 0 ]"

# M9  the gap shrinks the other way: make the quorum as common as the floor by
#     declaring them equal.  §3c's relation assert is the whole finding.
mutant "M9  §3c compares the quorum against itself" \
    "sub '$TEST' 'if c >= FALLBACK then n3 = n3 + 1 end' 'if c >= QUORUM then n3 = n3 + 1 end'"

echo
echo "=== group C: the instrument itself ==="

# M10 the flat enumerator yields nothing.  Without the liveness guard, §3a and
#     §3b would both report a maximum of 0 and read as a stronger result.
mutant "M10 corpus_paths_flat() yields nothing" \
    "sub '$TEST' \"local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))\" \"local p = assert(io.popen('ls /nonexistent-corpus-dir 2>/dev/null'))\""

# M11 ⭐ the deep enumerator silently becomes the flat one.  Then §3c is §3a
#     wearing a hat and its numbers are not independent -- the assert that the
#     two lists DIFFER is the only thing standing between those two readings.
mutant "M11 corpus_paths_deep() loses the subdirectories" \
    "sub '$TEST' \"-name 'f_*.lua' 2>/dev/null | sort\" \"-maxdepth 1 -name 'f_*.lua' 2>/dev/null | sort\""

# M12 the ring in §3a swallows the map, so (a) and (b) can no longer disagree
#     and (b)'s job -- showing that (a)'s zero is not the ring's doing -- is
#     done by construction rather than by measurement.
mutant "M12 §3a's ring becomes unbounded" \
    "sub '$TEST' 'local RING        = 1600' 'local RING        = 99999'"

# M13 ⭐ densest() stops counting the pivot, i.e. the instrument disagrees with
#     the seed M3 protects.  Every count in §3 drops by one; the quorum becomes
#     unreachable and the file reports a STRONGER version of its own conclusion.
#     A file that cannot fail in the direction that flatters it is not evidence.
mutant "M13 densest() stops counting the pivot itself" \
    "sub '$TEST' 'if dist(e, o) <= SPLASH then c = c + 1 end' 'if e ~= o and dist(e, o) <= SPLASH then c = c + 1 end'"

restore
verify_restore || { echo; echo "FINAL RESTORE FAILED"; exit 2; }

echo
echo "=== result ==="
echo "  killed   : $KILLED"
echo "  survived : $SURVIVED"
echo "  aborted  : $ABORTED"
[ "$SURVIVED" -eq 0 ] && [ "$ABORTED" -eq 0 ] && { echo "  ALL MUTANTS KILLED"; exit 0; }
exit 1

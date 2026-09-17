#!/usr/bin/env bash
# Mutation stand for tests/test_cm_weakest_sentinel_domain.lua -- the hero desk's
# DO-NOT-ARM verdict on the `10000` in `X.cm_GetWeakestUnit`.
#
# ⚠️ NO GATED ID SHIPS THIS ROUND, so this is not a "does the gate work" stand.
# What it prices is whether the file CAN STILL FAIL.  Its two headline readings
# are both NEGATIVE claims -- "nothing reads the second return value" and
# "nothing in the corpus reaches 10000 hp" -- and a negative claim is the easiest
# thing in this repo to satisfy by accident: a reader that resolves no call
# sites, a scope window that is the whole file, a corpus walk that finds no
# files, a hero filter that matches no rows.  Every one of those would make the
# file green while saying nothing at all.  Groups:
#   A  the SUBJECT: both shipped copies of the picker       (M1-M5)
#   B  THE CONTROL: the sibling picker section 3 rests on   (M6)
#   C  THE INSTRUMENT: site reader, scope window, walk      (M7-M9, M14-M15)
#   D  the PREMISES the verdict rests on                    (M10-M13)
#
# Usage:  bash tools/agent/mutstand_cmweaksent.sh
# Exit 0 iff every mutant is KILLED.  Reads and restores from a file copy (never
# from git), per .claude/skills/evidence-discipline.
#
# ⛔ EVERY FILE A MUTANT TOUCHES IS IN THE BACKUP LIST -- not "the files the
# stand is about" (the mutstand_cmkillscan.sh lesson, 2026-09-16: a leaked
# mutation does not merely dirty the tree, it MANUFACTURES kills for every
# mutant that runs after it).  This stand mutates two hero files, one mode file,
# `.luacheckrc`, one corpus fixture and the test itself; all six are backed up
# and every restore is verified.
#
# ⛔ `.luacheckrc` IS IN THAT LIST AND IT MATTERS MORE THAN THE OTHERS: it is the
# push gate's own configuration (iron rule 6), so a leak here does not redden a
# test, it changes what the gate enforces for whoever pushes next.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 2

TEST=tests/test_cm_weakest_sentinel_domain.lua
CM=bots/BotLib/hero_crystal_maiden.lua
RUB=bots/FunLib/rubick_hero/crystal_maiden.lua
OUT=bots/mode_outpost_generic.lua
RC=.luacheckrc
FIX=tests/frames/f_260910_124853_lion_spike_slardar_1416.lua

TMP="$(mktemp -d)"
cp "$TEST" "$TMP/test.bak"
cp "$CM"   "$TMP/cm.bak"
cp "$RUB"  "$TMP/rub.bak"
cp "$OUT"  "$TMP/out.bak"
cp "$RC"   "$TMP/rc.bak"
cp "$FIX"  "$TMP/fix.bak"

PAIRS="$TEST:test.bak $CM:cm.bak $RUB:rub.bak $OUT:out.bak $RC:rc.bak $FIX:fix.bak"

restore() {
    local pair f b
    for pair in $PAIRS; do
        f="${pair%%:*}"; b="$TMP/${pair##*:}"
        cp "$b" "$f"
    done
}

# ⛔ RESTORING IS NOT THE SAME AS HAVING RESTORED.  Checked after every restore
# rather than once at the end, so a leak is caught on the mutant that caused it
# instead of five mutants later (tests/test_mutstand_restore_trap.py).
verify_restore() {
    local bad=0 f b pair
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
    # `--` is load-bearing: a replacement starting with `-` is otherwise read as
    # an option, and the stand reports ABORT for a quoting reason -- which is not
    # a survival, but is also not a kill (mutstand_lionraoequorum.sh M11).
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
echo "=== group A: the subject -- both shipped copies of the picker ==="

# M1  The constant itself, in the copy the verdict is named after.  If §1
#     survives this, the file is not about a constant, it is about a comment.
mutant "M1  CM picker: seed 10000 -> math.huge (the cap is gone)" \
    "sub '$CM' 'local nWeakestUnitLowestHealth = 10000' 'local nWeakestUnitLowestHealth = math.huge'"

# M2  The SECOND copy.  Reading A is a claim about fourteen sites across TWO
#     files; a file that only ever opens the first one would say half of it.
mutant "M2  rubick copy: seed 10000 -> 9999" \
    "sub '$RUB' 'local nWeakestUnitLowestHealth = 10000' 'local nWeakestUnitLowestHealth = 9999'"

# M3  Strict `<` is what makes the seed a CAP rather than an initial value, and
#     §1 asserts the comparison for exactly that reason.
mutant "M3  CM picker: '<' -> '<=' (changes what reading B is about)" \
    "sub '$CM' 'if unit:GetHealth() < nWeakestUnitLowestHealth' 'if unit:GetHealth() <= nWeakestUnitLowestHealth'"

# M4  ⭐ THE HEADLINE MUTANT.  Give the dead second binding ONE reader, in the
#     same function, and reading A becomes live -- which is precisely the day
#     the DO-NOT-ARM verdict has to be re-decided.  A §2 that survives this is
#     not measuring consumption.
mutant "M4  CM ConsiderQ: add one live read of the dead second binding" \
    "sub '$CM' \
'	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )' \
'	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )
	local nMutantSink = nWeakestEnemyHeroHealth1 + 0'"

# M5  the same attack on the OTHER file, so "fourteen sites" cannot be satisfied
#     by reading one file twice.
mutant "M5  rubick copy: add one live read of the dead second binding" \
    "sub '$RUB' \
'	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )' \
'	local nWeakestEnemyHeroInRange, nWeakestEnemyHeroHealth1 = X.cm_GetWeakestUnit( nEnemysHeroesInRange )
	local nMutantSink = nWeakestEnemyHeroHealth1 + 0'"

echo
echo "=== group B: the control section 3 rests on ==="

# M6  Kill the CONTROL, not the subject: rename the sibling's second binding so
#     its three readers no longer reach it.  §3 exists because "zero reads" is
#     otherwise a fact about the reader; if §3 survives a dead sibling site,
#     that is exactly what it has become.
mutant "M6  CM: make a cm_GetStrongestUnit second binding dead too" \
    "sub '$CM' \
'local nEnemysStrongestCreeps2, nEnemysStrongestCreepsHealth2 = X.cm_GetStrongestUnit( nEnemysCreeps2 )' \
'local nEnemysStrongestCreeps2, nMutantDeadHealth = X.cm_GetStrongestUnit( nEnemysCreeps2 )'"

echo
echo "=== group C: the instrument -- site reader, scope window, corpus walk ==="

# M7  ⭐ THE SCOPE WINDOW, and this file got it wrong on its first draft, which
#     is why it is mutated rather than trusted.  `nWeakestEnemyHeroHealth1` is
#     bound in THREE different functions of the CM file; widen the window to the
#     whole file and each binding counts the other two as readers.  §2 must go
#     red -- a green §2 here would be reporting six reads as zero.
mutant "M7  test: fn_bounds finds no function start (window becomes whole file)" \
    "sub '$TEST' \"if tLines[n]:match('^function%s') then nStart = n break end\" \
\"if tLines[n]:match('^functionZZZ%s') then nStart = n break end\""

# M8  the site pattern.  Point it at a table that does not exist and the reader
#     resolves ZERO sites -- the cheapest way for a negative claim to be green.
#     Both §2 and §3 must fail, because both floors are measured floors.
mutant "M8  test: site pattern looks for Y.<picker> instead of X.<picker>" \
    "sub '$TEST' \"=%s*X%.' .. sPicker\" \"=%s*Y%.' .. sPicker\""

# M9  the corpus walk.  Narrow it to one subtree: the directory floor and the
#     file floor both exist so that a narrowed walk reddens instead of quietly
#     reporting a ceiling over less corpus than exists.
mutant "M9  test: corpus walk narrowed to tests/fixtures only" \
    "sub '$TEST' \"find tests -type f -name 'f_*.lua'\" \"find tests/fixtures -type f -name 'f_*.lua'\""

# M14 the hero filter.  If it matches nothing, §4's ceiling is -1 and 'nothing
#     reaches 10000' is true of a corpus with no heroes in it.
mutant "M14 test: hero-row filter matches no unit name" \
    "sub '$TEST' \"tUnit.name:match('^npc_dota_hero_')\" \"tUnit.name:match('^npc_dota_heroZ_')\""

# M15 ⭐ THE ANTI-VACUITY GUARD ITSELF, mutated from the OUTSIDE rather than by
#     editing its own assertion (mutating an assertion cannot be killed by the
#     suite it belongs to -- mutstand_lionraoequorum.sh M7).  Raise the
#     high-water threshold past anything the corpus holds and the guard must
#     fire, because at that point §4 is measuring nothing again.
mutant "M15 test: the 'corpus reaches high hp' threshold raised past the corpus" \
    "sub '$TEST' 'tUnit.hp >= 4000' 'tUnit.hp >= 40000'"

echo
echo "=== group D: the premises the verdict rests on ==="

# M10 READING B's premise, attacked in the corpus rather than in prose: put one
#     hero above the sentinel and the cap becomes reachable.  This is the mutant
#     that says §4 is a measurement and not a restatement of the header.
mutant "M10 corpus: the ceiling row's max_hp raised above the sentinel" \
    "sub '$FIX' 'max_hp = 4343' 'max_hp = 14343'"

# M11 §5's premise: the reason fourteen dead locals survived every push this
#     repo has ever made.  Turn the 2xx warnings on and §5 must say so, because
#     from that moment the linter enforces §2 and §5 should be deleted.
mutant "M11 .luacheckrc: enforce 2xx (unused) warnings as well" \
    "sub '$RC' 'only = { \"1\" }' 'only = { \"1\", \"2\" }'"

# M12 the HANDOFF pin.  §6's whole point is that the same literal is below its
#     domain one dimension over; fix that seed and the issue is done, which §6
#     must report as a red rather than by continuing to pass.
mutant "M12 outpost: GetClosestOutpost seed 10000 -> math.huge" \
    "sub '$OUT' 'local dist = 10000' 'local dist = math.huge'"

# M13 the OTHER half of the handoff claim: that the compared distance is
#     unbounded.  Break the comparison's shape and §6 must stop asserting it.
mutant "M13 outpost: the loop no longer compares against the seed" \
    "sub '$OUT' 'and GetUnitToUnitDistance(bot, Outposts[i]) < dist' \
'and GetUnitToUnitDistance(bot, Outposts[i]) < 99999'"

# M16 ⭐ THE MASK, which is the half that keeps §6 from being a bug report -- and
#     this desk had the bug report written before it read the consumer.  Loosen
#     the `< 3000` conjunct past the seed and the capped answer stops being
#     behaviourally identical to the far answer, i.e. the cap goes LIVE.  A §6
#     that survives this is pinning only the half that is not the finding.
mutant "M16 outpost: the '< 3000' mask loosened past the seed (cap goes live)" \
    "sub '$OUT' 'if ClosestOutpost ~= nil and ClosestOutpostDist < 3000' \
'if ClosestOutpost ~= nil and ClosestOutpostDist < 30000'"

echo
restore
if ! verify_restore; then
    echo "FINAL RESTORE LEAKED -- the tree is NOT pristine.  Fix before pushing."
    exit 2
fi

TOTAL=$((KILLED + SURVIVED + ABORTED))
echo "=== $KILLED killed / $SURVIVED survived / $ABORTED aborted  (of $TOTAL) ==="
if [ "$SURVIVED" -ne 0 ] || [ "$ABORTED" -ne 0 ]; then
    echo "NOT CLEAN.  A survivor means the file cannot fail for that reason; an"
    echo "abort means the question was never asked.  Neither is a pass."
    exit 3
fi
echo "every mutant killed"

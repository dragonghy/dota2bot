#!/usr/bin/env bash
# Mutation stand for tests/test_replay_260819_zuus_boltdom.lua -- the
# `zusboltdom` candidate (hero, 2026-09-04, GH #477).  Run by hand when that
# file, X.BoltAoEKillTarget or X.ConsiderW2's kill-AoE return is edited, and
# before quoting any of its readings.
#
# DISCIPLINE (inherited from tools/agent/mutstand_zusaether.sh):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose anchor string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR.  This candidate's whole subject is ONE RETURN VALUE
# that is legitimately nil most of the time.  Two failure modes therefore look
# identical from outside: "the helper correctly reported nil" and "the helper is
# dead".  M1 and M5 are that pair, and they exist to prove the file can tell
# them apart.  M2/M3 are the shipped-defaults drift a gate-plumbing test would
# miss, and M4 is the pullcad trap (a gate that names a SIBLING id and freezes
# FALSE the day that sibling is promoted) applied on purpose.
#
# Usage: bash tools/agent/mutstand_zusboltdom.sh
set -u
cd "$(dirname "$0")/../.."

TEST=tests/test_replay_260819_zuus_boltdom.lua
HERO=bots/BotLib/hero_zuus.lua

FILES=("$TEST" "$HERO")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zbd.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
}

trap restore EXIT

run_tests() {
    lua5.1 tests/run_tests.lua test_replay_260819_zuus_boltdom > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex), and abort if the anchor is gone -- a mutant
# that silently applied to nothing scores "caught" for the wrong reason.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
if old not in s:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the helper is dead -- it answers nil on every frame, which is exactly what
#     a CORRECT helper answers on most frames.  This is the mutant that decides
#     whether the file is measuring anything at all.
echo
echo "=== M1: BoltAoEKillTarget always reports nothing (the dead-helper twin) ==="
sub "$HERO" '		and type( nHealthCap ) == '"'"'number'"'"' and nHealthCap <= 0
	then
		return hWeakest
	end' '		and type( nHealthCap ) == '"'"'number'"'"' and nHealthCap <= 0
	then
		return nil
	end'
score "M1" "the degenerate filter means the branch must name what it is aimed at"

# ---------------------------------------------------------------------------
# M2: the candidate check is dropped.  The exemption is now conditional in every
#     shipped Turbo game -- a defaults change wearing a candidate's name.
echo
echo "=== M2: the gate stops asking whether the candidate is armed ==="
sub "$HERO" '	if J.IsModeTurbo() and J.IsSoakCandidate( '"'"'zusboltdom'"'"' )
		and type( nHealthCap ) == '"'"'number'"'"' and nHealthCap <= 0' \
            '	if type( nHealthCap ) == '"'"'number'"'"' and nHealthCap <= 0'
score "M2" "unarmed, the helper reports nothing whatever the cap says"

# ---------------------------------------------------------------------------
# M3: turbo-only is dropped, the candidate check kept.  The narrower half of M2,
#     and the one a gate-plumbing test would miss.
echo
echo "=== M3: the turbo guard is dropped, the candidate check kept ==="
sub "$HERO" 'if J.IsModeTurbo() and J.IsSoakCandidate( '"'"'zusboltdom'"'"' )' \
            'if J.IsSoakCandidate( '"'"'zusboltdom'"'"' )'
score "M3" "the gate is turbo-only"

# ---------------------------------------------------------------------------
# M4: THE pullcad TRAP, applied deliberately.  The value test is replaced by the
#     sibling id it stands for.  Behaviourally identical TODAY -- and frozen
#     FALSE the day `zusboltcap` is promoted, because a promoted id appears in no
#     armed string.  The wiring case is the only thing that can see this, which
#     is why that case exists.
echo
echo "=== M4: the cap's VALUE is replaced by the sibling candidate's NAME ==="
sub "$HERO" 'and type( nHealthCap ) == '"'"'number'"'"' and nHealthCap <= 0' \
            'and not J.IsSoakCandidate( '"'"'zusboltcap'"'"' )'
score "M4" "the helper must not name zusboltcap"

# ---------------------------------------------------------------------------
# M5: the call site stops passing the cap, so the helper sees nil and takes the
#     `type(...) == 'number'` exit.  Same OBSERVABLE as M1 (always nil) reached
#     by a different route -- the site, not the helper.  A file that only drove
#     X.BoltAoEKillTarget directly would be green here.
echo
echo "=== M5: the kill-AoE return stops handing the helper the cap ==="
sub "$HERO" 'X.BoltAoEKillTarget( nDamage, nWeakestEnemyHeroInSkillRange )' \
            'X.BoltAoEKillTarget( nil, nWeakestEnemyHeroInSkillRange )'
score "M5" "the degenerate filter means the branch must name what it is aimed at"

# ---------------------------------------------------------------------------
# M6: the exemption is dropped UNCONDITIONALLY -- the branch always reports its
#     target, so a genuine kill window can be held.  This is the over-correction
#     GH #47 exists to forbid, and the direction that costs Zeus kills.
echo
echo "=== M6: the cap test is dropped -- real kills lose the exemption too ==="
sub "$HERO" 'and type( nHealthCap ) == '"'"'number'"'"' and nHealthCap <= 0' \
            'and true'
score "M6" "a real kill filter keeps GH #47"

# ---------------------------------------------------------------------------
# M7: a control on the INSTRUMENT rather than on the subject.  The file's hero
#     AoE reader is what makes the kill-AoE branch reachable at all; blinded
#     back to the loader's structural {count = 0}, every behavioural case here
#     is exercising a branch that never runs.  If this survives, the readings
#     above are about some other branch.
echo
echo "=== M7: the supplied hero AoE reader is blinded (control on the instrument) ==="
sub "$TEST" '        if bHeroes ~= true then' '        if true then'
#     Note what the blinded run says: with the loader's structural {count = 0}
#     the frame's bid comes from a POKE branch, which reports its target, so
#     `zusult` alone already holds it and NOTHING is cast ("got {}").  That is
#     the second half of the evidence -- the leak this candidate closes is
#     specifically the kill-AoE branch, not the frame.
score "M7" "reproduced on a real frame; got {}"

# ---------------------------------------------------------------------------
# The EXIT trap restores and verifies; do not restore-and-delete here, or the
# trap fires against a work dir that is already gone and reports a false
# "the working tree still holds a mutant".
echo
echo "=== $CAUGHT / $TOTAL mutants caught ==="
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1

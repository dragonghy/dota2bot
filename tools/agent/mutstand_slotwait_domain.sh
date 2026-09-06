#!/usr/bin/env bash
# Mutation stand for tests/test_slotwait_domain_liveness.py
# (replay-check condition-(a) instrument for soak candidate 'slotwait', GH #467).
#
# WHY.  This one is not hypothetical: the liveness file caught its own
# instrument on its FIRST run.  `IMPORTANT_SPELL` was transcribed BY HAND at
# 40 rows off a Lua table that actually has 88 -- the source had been read
# through a window that stopped at 40 lines, and the table LOOKED complete.
# The truncated table still produced a full, plausible corpus reading, and its
# headline ("seed 4950 reads ZERO on dire -- the lever is structurally inert on
# that roster") was an artifact of the missing rows: with the real table that
# seed reads 6,719.  A number that is wrong for a reason nobody can see from
# the number is exactly what a mutation stand is for.
#
# The six shapes under test, each a way this instrument could go back to
# measuring something else while still printing a table:
#   M1  the dire scan set is transposed with radiant -- the side ratio, which
#       is the whole arithmetic claim, silently inverts;
#   M2  radiant's missed slot (pid 4) is handed back to the scanned set -- the
#       radiant column goes to zero and reads as "the defect is dire-only";
#   M3  IMPORTANT_SPELL is truncated again (the actual defect, replayed);
#   M4  the spell leg starts reading the SECOND ImportantSpells entry, i.e. an
#       ultimate the shipped predicate never looks at (LIMIT 6 inverted);
#   M5  the untrained-ability guard is dropped, so level-0 ultimates count;
#   M6  the illusion filter goes back to keying on player_id alone -- the
#       defect that SUPPRESSES divergences, found frame-first on chaos_knight
#       (eleven rows, one pid) in 20260904_190005_slot1 t=739.4.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would discard uncommitted
# work, which is exactly what is under test here).  Note the EXIT trap deletes
# $SAFE, so the restore-and-verify happens INSIDE mutate(), never after the
# cleanup -- the 2026-09-04 mutstand_zusmana.sh failure was a `rm -rf "$SAFE"`
# racing its own trap and reporting a RESTORE FAILURE about a healthy tree.
#
#   bash tools/agent/mutstand_slotwait.sh
#
# Exit 0 = every mutant CAUGHT.  Exit 1 = a mutant SURVIVED (rule 2: suspect
# the assertion before the mutation, and read the printed diff first -- a regex
# that misses prints NO-OP, and one that hits the wrong line prints SURVIVED
# while the instrument is untouched).  No AWS, no network, no corpus needed.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SRC=tools/batch_test/behavioral/slotwait_domain.py
TEST=tests/test_slotwait_domain_liveness.py
SAFE=$(mktemp -d)
cp "$SRC" "$SAFE/orig.py"
sha256sum "$SRC" > "$SAFE/orig.sha"
# Named rather than inlined so the restore has one definition to read and one
# place to change; the trap body used to carry the `cp` itself.
restore() { cp "$SAFE/orig.py" "$SRC"; }
trap 'restore; rm -rf "$SAFE"' EXIT

fail=0
# `-B` and the pycache wipe are NOT hygiene, they are this stand's own bug,
# measured 2026-09-04 on mutstand_campbind_poke.sh: two mutants of identical
# byte size written inside one filesystem mtime second made CPython reuse the
# previous mutant's cached bytecode, and the stand reported CAUGHT with the
# WRONG failure message.  A stand that re-measures the previous mutant fails
# in the green-looking direction.
run_test() {
  rm -rf tools/batch_test/behavioral/__pycache__ tests/__pycache__
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$TEST" > "$SAFE/out.txt" 2>&1
  echo $?
}

baseline=$(run_test)
if [[ "$baseline" != "0" ]]; then
  echo "BASELINE IS RED (exit $baseline) -- fix that before mutating:"
  tail -20 "$SAFE/out.txt"
  exit 1
fi
echo "baseline: test file GREEN (exit 0)"

mutate() {   # $1 = name, $2 = python snippet performing the edit
  local name=$1 edit=$2
  cp "$SAFE/orig.py" "$SRC"
  python3 - "$SRC" <<PY
import sys
p = sys.argv[1]
s = open(p).read()
before = s
$edit
if s == before:
    print('NO-OP')
    sys.exit(9)
open(p, 'w').write(s)
PY
  local landed=$?
  if [[ $landed -eq 9 ]]; then
    echo "  $name  NO-OP  (the edit did not land -- the regex missed; NOT a pass)"
    fail=1
  else
    echo "  --- $name diff ---"
    diff -u "$SAFE/orig.py" "$SRC" | grep -E '^[+-][^+-]' | head -6
    local rc
    rc=$(run_test)
    if [[ "$rc" == "0" ]]; then
      echo "  $name  SURVIVED  (test still green -- the assertion measures nothing)"
      fail=1
    else
      echo "  $name  CAUGHT    (exit $rc)"
      grep -E '^  FAIL' "$SAFE/out.txt" | head -3
    fi
  fi
  cp "$SAFE/orig.py" "$SRC"
  sha256sum -c "$SAFE/orig.sha" > /dev/null || { echo "RESTORE FAILED"; exit 1; }
}

echo
echo "M1: the two sides' scan sets are transposed (the ratio inverts)"
mutate M1 "s = s.replace('''    if team == RADIANT:
        return {0, 1, 2, 3}
    return {9}''', '''    if team == RADIANT:
        return {4}
    return {5, 6, 7, 8}''')"

echo
echo "M2: radiant's one missed slot is handed back to the scanned set"
mutate M2 "s = s.replace('        return {0, 1, 2, 3}', '        return {0, 1, 2, 3, 4}')"

echo
echo "M3: IMPORTANT_SPELL truncated again (the defect this file was born from)"
mutate M3 "
i = s.index('IMPORTANT_SPELL = {')
j = s.index('\n}\n', i)
rows = s[i:j].split('\n')
s = s[:i] + '\n'.join(rows[:41]) + s[j:]"

echo
echo "M4: the spell leg reads the SECOND ImportantSpells entry (LIMIT 6 inverted)"
mutate M4 "s = s.replace('\\\"npc_dota_hero_undying\\\": \\\"undying_tombstone\\\"', '\\\"npc_dota_hero_undying\\\": \\\"undying_flesh_golem\\\"')"

echo
echo "M5: the untrained-ability guard is dropped (level-0 ultimates count)"
mutate M5 "s = s.replace('''        if (ab.get(\\\"level\\\") or 0) < 1:
            return False''', '        pass')"

echo
echo "M6: the illusion filter goes back to keying on player_id alone"
mutate M6 "s = s.replace('''        if s.get(\\\"idx\\\") is not None and s[\\\"idx\\\"] not in real:
            continue''', '        pass')"

echo
sha256sum -c "$SAFE/orig.sha" && echo "restore verified"
if [[ $fail -ne 0 ]]; then
  echo "RESULT: at least one mutant SURVIVED or did not land"
  exit 1
fi
echo "RESULT: all mutants CAUGHT"

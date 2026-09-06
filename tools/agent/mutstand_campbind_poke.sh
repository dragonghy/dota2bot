#!/usr/bin/env bash
# Mutation stand for tests/test_campbind_poke_liveness.py
# (replay-check condition-(a) instrument for soak candidate 'campbind').
#
# WHY.  Every leg of that test file passed on its first run, which is exactly
# when an assertion is most likely to be measuring nothing.  The file exists
# because the instrument it pins was WRONG THREE TIMES on its first corpus and
# each time the output table still looked clean -- so "green" here has to be
# shown to mean "the defect would be caught", not "the driver reached the line".
#
# The four shapes under test, each a way the instrument could quietly go back
# to measuring the wrong thing:
#   M1  the right-click discriminator is dropped -- ability damage (an ignite
#       DoT ticking across BOTH camps) counts as a poke again;
#   M2  the discriminator is inverted -- `physical` becomes "an ability fired",
#       the same defect wearing the opposite sign;
#   M3  camp membership goes back to a per-camp radius test, so two camps
#       1121 u apart share creeps and an untouched neighbour inherits the drag
#       (the defect that SUPPRESSES findings, i.e. the dangerous direction);
#   M4  the reach radius / leash drift off the values transcribed from the Lua
#       (POKE_R 1400, LEASH 1200) -- section 4 is the only thing tying this
#       tool to the call site it claims to measure;
#   M5  clusters_near stops sorting by distance, so index 0 is no longer
#       "nearest" and the whole nearest/non_nearest verdict silently means
#       nothing.
#
# Each mutant edits ONE file in place and restores it from a copy taken OUTSIDE
# the tree, proving the restore with `sha256sum -c` after every mutant
# (evidence-discipline rule 1: `git checkout --` would discard uncommitted work,
# which is exactly what is under test here).
#
#   bash tools/agent/mutstand_campbind_poke.sh
#
# Exit 0 = every mutant CAUGHT.  Exit 1 = a mutant SURVIVED (rule 2: suspect
# the assertion before the mutation -- and first read the printed diff and
# confirm the mutant landed where you think it did; a regex that misses prints
# NO-OP, and a regex that hits the wrong function prints SURVIVED while the
# instrument is untouched).  No AWS, no network.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SRC=tools/batch_test/behavioral/campbind_poke.py
TEST=tests/test_campbind_poke_liveness.py
SAFE=$(mktemp -d)
cp "$SRC" "$SAFE/orig.py"
sha256sum "$SRC" > "$SAFE/orig.sha"
# Named rather than inlined so the restore has one definition to read and one
# place to change; the trap body used to carry the `cp` itself.
restore() { cp "$SAFE/orig.py" "$SRC"; }
trap 'restore; rm -rf "$SAFE"' EXIT

fail=0
# `-B` and the pycache wipe are NOT hygiene, they are the stand's own bug.
# Measured 2026-09-04 on this very file: M4 (POKE_R 1400->2000) and M4b
# (LEASH 1200->2000) produce files of IDENTICAL SIZE, written inside the same
# filesystem mtime second, so CPython's default (mtime, size) staleness check
# reused M4's cached bytecode for M4b's run.  M4b was reported CAUGHT -- with
# M4's failure message ("POKE_R mirrors it" while the diff said LEASH).  A
# stand that re-measures the previous mutant is a stand that measures nothing,
# and it fails GREEN-looking, i.e. in the direction nobody checks.
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
echo "M1: drop the right-click discriminator (ability damage is a poke again)"
mutate M1 "s = s.replace(\"o['physical'] = 'dota_unknown' in o['inflictors']\", \"o['physical'] = True\")"

echo
echo "M2: invert it (physical means 'an ability fired')"
mutate M2 "s = s.replace(\"o['physical'] = 'dota_unknown' in o['inflictors']\", \"o['physical'] = 'dota_unknown' not in o['inflictors']\")"

echo
echo "M3: camp membership back to a per-camp radius test (shared creeps)"
mutate M3 "s = s.replace('''            best, bd = None, CAMP_LINK
            for i, (tx, ty) in enumerate(tracks):
                d = PD.dist(c['x'], c['y'], tx, ty)
                if d < bd:
                    best, bd = i, d
            if best is not None:
                buckets[best].append(c)''', '''            for i, (tx, ty) in enumerate(tracks):
                if PD.dist(c['x'], c['y'], tx, ty) <= CAMP_LINK:
                    buckets[i].append(c)''')"

echo
echo "M4: the reach radius drifts off the Lua's 1400"
mutate M4 "s = s.replace('POKE_R = 1400.0', 'POKE_R = 2000.0')"

echo
echo "M4b: the leash drifts off the Lua's 1200"
mutate M4b "s = s.replace('LEASH = 1200.0', 'LEASH = 2000.0')"

echo
echo "M5: clusters_near stops sorting, so index 0 is not 'nearest'"
mutate M5 "s = s.replace(\"    out.sort(key=lambda d: d['near'])\", \"    out.sort(key=lambda d: -d['near'])\")"

echo
sha256sum -c "$SAFE/orig.sha" && echo "restore verified"
if [[ $fail -eq 0 ]]; then
  echo "ALL MUTANTS CAUGHT"
  exit 0
fi
echo "AT LEAST ONE MUTANT SURVIVED OR NO-OPed"
exit 1

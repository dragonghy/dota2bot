#!/usr/bin/env bash
# Mutation stand for Ruling 5 (wave_fence.py accrual scope), director 2026-09-09.
# Discipline 1: restore from a FILE COPY, not from an inverse edit.
set -u
SRC=tools/batch_test/soak/wave_fence.py
CP=$(mktemp /tmp/wave_fence.orig.XXXXXX.py)
cp "$SRC" "$CP"

# GH #418: the trap goes in BEFORE the first mutant, not after the last one.
# Without it, a stand that dies mid-mutant (Ctrl-C, a killed container, a typo
# in the applier) leaves the tree MUTATED and the next reader has no way to
# know -- the per-mutant `cp` below only covers the paths this script survives.
SUM=$(mktemp /tmp/wave_fence.sum.XXXXXX)
sha256sum "$SRC" > "$SUM"
restore() { cp "$CP" "$SRC"; }
trap restore EXIT

run() {  # run() <label>
  out=$(python3 tests/test_wave_fence.py 2>&1); rc=$?
  echo "$1: rc=$rc  $(echo "$out" | tail -1)"
  echo "$out" | grep -E '^FAIL' | sed 's/^/    /'
}

run "CONTROL (unmutated)"

# M1 -- put the pre-ruling claim back: the zero is account-wide unconditionally.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace('        where = "account-wide" if complete else "in the region(s) above"',
            '        where = "account-wide"')
s=s.replace('        if complete:\n            lines.append(\n                "accrual check    : CERTIFIED (0 accruing instances "',
            '        if True:\n            lines.append(\n                "accrual check    : CERTIFIED (0 accruing instances "')
open(p,"w").write(s)
PY
run "M1 (old account-wide claim restored)"
cp "$CP" "$SRC"

# M2 -- the DescribeRegions fallback calls itself complete.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace('return rows, {"regions": ["(configured default)"], "complete": False,',
            'return rows, {"regions": ["(configured default)"], "complete": True,')
open(p,"w").write(s)
PY
run "M2 (fallback claims completeness)"
cp "$CP" "$SRC"

# M3 -- an unreadable region is swallowed and the scope still reads complete.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace('    scope = {"regions": read, "complete": not failed}',
            '    scope = {"regions": read, "complete": True}')
open(p,"w").write(s)
PY
run "M3 (partial enumeration reads complete)"
cp "$CP" "$SRC"

# M4 -- the per-region loop reverts to a single unscoped call.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace('        args = ["ec2", "describe-instances", "--filters"] + filters\n        if region:\n            args += ["--region", region]',
            '        args = ["ec2", "describe-instances", "--filters"] + filters')
open(p,"w").write(s)
PY
run "M4 (region argument dropped)"
cp "$CP" "$SRC"

# The restore is PROVEN, not asserted: sha256sum against the digest taken
# before the first mutant (the same proof `mutstand_wave_fence.sh` uses).
if sha256sum -c "$SUM" > /dev/null 2>&1; then
  echo "RESTORE: byte-identical ok (sha256sum -c)"
else
  echo "RESTORE: DIFFERS -- STOP, the tree still carries a mutant"; trap - EXIT; rm -f "$SUM"; exit 2
fi
# GH #492 §EL.7: disarm BEFORE removing the copy, so cleanup cannot outrun the trap.
trap - EXIT
rm -f "$CP" "$SUM"

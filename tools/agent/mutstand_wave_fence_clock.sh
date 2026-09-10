#!/usr/bin/env bash
# Mutation stand for Ruling 6 (wave_fence.py wave-accrual clock), director
# 2026-09-10.  Discipline 1: restore from a FILE COPY, not an inverse edit.
#
# What these mutants are: each one is a way of writing the SAME bug back in.
# M1 is the pre-ruling code verbatim (the branch that certified $0 with a wave
# in flight); M2 is the half the desk got wrong by hand (anchoring the window
# to `now` instead of to the budget snapshot); M3 is the tempting "just use the
# 4.3h floor"; M4 prices the waves, which is the free parameter this whole file
# exists to remove; M5 lets the ruling-3 bound swallow a record that is
# genuinely inside the window.
set -u
SRC=tools/batch_test/soak/wave_fence.py
CP=$(mktemp /tmp/wave_fence.clock.orig.XXXXXX.py)
cp "$SRC" "$CP"

# GH #418: the trap goes in BEFORE the first mutant, not after the last one.
SUM=$(mktemp /tmp/wave_fence.clock.sum.XXXXXX)
sha256sum "$SRC" > "$SUM"
restore() { cp "$CP" "$SRC"; }
trap restore EXIT

run() {  # run() <label>
  out=$(python3 tests/test_wave_fence.py 2>&1); rc=$?
  echo "$1: rc=$rc  $(echo "$out" | tail -1)"
  echo "$out" | grep -E '^FAIL' | sed 's/^/    /'
}

run "CONTROL (unmutated)"

# M1 -- the pre-ruling branch: nothing running => certify $0, wave or no wave.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
# Anchored on the comment, NOT on `if wave_rows:` alone: a bare replace(...,1)
# silently moved onto the OTHER wave_rows branch the moment one was added
# above it, and the stand went on reporting CAUGHT off a mutant that was no
# longer the pre-ruling code.  A mutant applier needs an anchor that cannot
# drift.
old = "        if wave_rows:\n            # The half Ruling 4 got wrong"
assert s.count(old) == 1, "M1 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "        if False:\n            # The half Ruling 4 got wrong")
open(p,"w").write(s)
PY
run "M1 (pre-ruling: a self-terminated wave certifies \$0)"
cp "$CP" "$SRC"

# M2 -- anchor the window to `now` instead of the budget snapshot.  This is
# exactly the hand arithmetic the desk ran on 2026-09-10, and it silently drops
# every wave in the gap between the snapshot and this instant.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace("    clock = parse_snapshot_instant(last_updated)",
            "    clock = None")
open(p,"w").write(s)
PY
run "M2 (window anchored to now, not to the snapshot)"
cp "$CP" "$SRC"

# M3 -- use the FLOOR of the documented lag band instead of the ceiling.  A
# wave 5h old is then 'probably billed', which is not the same as billed.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace("ACCRUAL_LAG_MAX_HOURS = 11.3", "ACCRUAL_LAG_MAX_HOURS = 4.3")
open(p,"w").write(s)
PY
run "M3 (lag floor 4.3h instead of ceiling 11.3h)"
cp "$CP" "$SRC"

# M4 -- price the waves here with a constant.  The output then looks MORE
# helpful and carries a free parameter nobody re-derives.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace('                "This tool does not price waves. Pass --pending with the "\n'
            '                "desk\'s own figure (sum of the waves above), or pass "\n'
            '                "--no-accrual-check and quote the SKIPPED line in your report.")',
            '                "Estimated at $1.10 per wave; pass --pending to override, or "\n'
            '                "--no-accrual-check and quote the SKIPPED line in your report.")')
open(p,"w").write(s)
PY
run "M4 (a wave price constant is invented here)"
cp "$CP" "$SRC"

# M5 -- let the ruling-3 bound apply even when the datable sibling is itself
# inside the window, so an undatable recent record is silently dropped.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
s=s.replace("                if bound_above is not None and bound_above < cutoff:",
            "                if bound_above is not None:")
open(p,"w").write(s)
PY
run "M5 (ruling-3 bound swallows an in-window undatable record)"
cp "$CP" "$SRC"

# The restore is PROVEN, not asserted.
if sha256sum -c "$SUM" > /dev/null 2>&1; then
  echo "RESTORE: byte-identical ok (sha256sum -c)"
else
  echo "RESTORE: DIFFERS -- STOP, the tree still carries a mutant"; trap - EXIT; rm -f "$SUM"; exit 2
fi
# GH #492 §EL.7: disarm BEFORE removing the copy.
trap - EXIT
rm -f "$CP" "$SUM"

#!/usr/bin/env bash
# Mutation stand for Ruling 7 (wave_fence.py: the epoch clock, and the degrade
# that now reaches the exit code), director 2026-09-10, GH #692 / #693.
# Discipline 1: restore from a FILE COPY, not an inverse edit.
#
# What these mutants are: each one is a way of writing the SAME bug back in.
# R1 is GH #692 verbatim -- the parser that did not know the shape the CLI
# actually returns, so Ruling 6's "rare" degrade fired on 100% of live runs.
# R2 drops the bool guard (isinstance(True, int) is True), which turns an
# unreadable stamp into a WRONG one dated 1970.  R3 is the pre-Ruling-7 world:
# the degrade prints a caveat and returns 0.  R4 is the subtler half and the
# one that actually spent money -- let --pending buy past the degrade, which
# is precisely what the desk did, in full compliance with the tool's own
# `must cover :` line, on a launch that crossed the fence.  R5 marks the
# operator's asserted clock degraded, turning the escape hatch into the
# permanent launch outage Ruling 5 refused to build.  R6 ignores an
# unparseable --snapshot-instant instead of refusing it.
set -u
SRC=tools/batch_test/soak/wave_fence.py
CP=$(mktemp /tmp/wave_fence.r7.orig.XXXXXX.py)
cp "$SRC" "$CP"

# GH #418: the trap goes in BEFORE the first mutant, not after the last one.
SUM=$(mktemp /tmp/wave_fence.r7.sum.XXXXXX)
sha256sum "$SRC" > "$SUM"
restore() { cp "$CP" "$SRC"; }
trap restore EXIT

run() {  # run() <label>
  out=$(python3 tests/test_wave_fence.py 2>&1); rc=$?
  echo "$1: rc=$rc  $(echo "$out" | tail -1)"
  echo "$out" | grep -E '^FAIL' | sed 's/^/    /'
}

run "CONTROL (unmutated)"

# R1 -- GH #692 verbatim: the float epoch the CLI hands back falls through to
# `return None`, so every live run degrades to `now`.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = ("    if isinstance(text, (int, float)) and not isinstance(text, bool):")
assert s.count(old) == 1, "R1 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "R1 (GH #692: the CLI's float epoch is not recognised)"
cp "$CP" "$SRC"

# R2 -- accept bools as epochs.  isinstance(True, int) is True, so this reads
# a budget snapshot of 1970-01-01 and cuts a window nobody chose.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if isinstance(text, (int, float)) and not isinstance(text, bool):"
assert s.count(old) == 1, "R2 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if isinstance(text, (int, float)):")
open(p,"w").write(s)
PY
run "R2 (bool accepted as an epoch)"
cp "$CP" "$SRC"

# R3 -- the pre-Ruling-7 world: a degraded clock is a wording problem.  After
# GH #683 ss4 the exit code IS the launch authorisation, so this is the whole
# hole, not a cosmetic difference.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '    if waves and waves.get("clock_degraded"):'
assert s.count(old) == 1, "R3 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "R3 (a degraded clock only changes the wording, as before Ruling 7)"
cp "$CP" "$SRC"

# R4 -- THE ONE THAT SPENT MONEY.  Let a supplied --pending buy past the
# degrade.  The desk covered every wave the tool named, in full; the naming
# was short by $3.250 because the clock that did the naming was wrong.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '    if waves and waves.get("clock_degraded"):'
assert s.count(old) == 1, "R4 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '    if (waves and waves.get("clock_degraded")\n'
                   '            and pending_supplied is None):')
open(p,"w").write(s)
PY
run "R4 (--pending buys past a degraded clock)"
cp "$CP" "$SRC"

# R5 -- mark the operator's asserted clock degraded too.  The gate then can
# never open once AWS changes a serialisation: the outage Ruling 5 refused.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = ('            "snapshot instant ASSERTED by the operator '
       '(--snapshot-instant)",\n            False)')
assert s.count(old) == 1, "R5 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, old[:-6] + "True)")
open(p,"w").write(s)
PY
run "R5 (the asserted clock is treated as degraded => permanent outage)"
cp "$CP" "$SRC"

# R6 -- ignore an unparseable --snapshot-instant instead of refusing it.  The
# operator then believes they anchored the window and they did not.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = ("    if (args.snapshot_instant is not None\n"
       "            and parse_snapshot_instant(args.snapshot_instant) is None):")
assert s.count(old) == 1, "R6 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "R6 (an unreadable --snapshot-instant is silently ignored)"
cp "$CP" "$SRC"

# The restore is PROVEN, not asserted.
if sha256sum -c "$SUM" > /dev/null 2>&1; then
  echo "RESTORE: byte-identical ok (sha256sum -c)"
else
  echo "RESTORE: DIFFERS -- STOP, the tree still carries a mutant"; trap - EXIT; rm -f "$SUM"; exit 2
fi
# GH #492 ssEL.7: disarm BEFORE removing the copy.
trap - EXIT
rm -f "$CP" "$SUM"

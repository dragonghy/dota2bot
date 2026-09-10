#!/usr/bin/env bash
# Mutation stand for RULING 10 (wave_fence.py: the director crossing field),
# director 2026-09-10, GH #721.
# Discipline 1: restore from a FILE COPY, not an inverse edit.
#
# What these mutants are: each one is a way of turning the bounded, expiring,
# self-announcing crossing field back into the thing it must never be -- a
# bypass switch.  The four constraints in the RULING 10 block are each probed
# by at least one mutant, plus the two places the ruling must not reach.
#
#   M1  the ceiling stops being capped by the brake        (constraint 1)
#   M2  an over-brake ruling is silently CLAMPED not refused (constraint 1,
#       the subtler half: a wrong ruling then reads as an obeyed one)
#   M3  the expiry stops being checked                     (constraint 2)
#   M4  a ruling with no expiry is accepted                (constraint 2)
#   M5  --crossing-ref stops being mandatory               (constraint 3)
#   M6  the CLEAR line stops saying the ruling is why it passed (constraint 4)
#   M7  the crossing rescues the NO-FENCE case, i.e. it reaches past the
#       owner's approval line                              (deliberate hole)
#   M8  the crossing raises but can never tighten -- max() instead of the
#       ruling's own number.  THIS IS THE LOAD-BEARING ONE: under M8 the flag
#       is exactly a bypass switch, because a ruling could then only ever buy
#       headroom and never cost any.
#   M9  main() validates the ruling but never hands it to the gate (the
#       "reachable but not wired" shape -- every unit check still passes on a
#       function nothing calls)
set -u
SRC=tools/batch_test/soak/wave_fence.py
CP=$(mktemp /tmp/wave_fence.r10.orig.XXXXXX.py)
cp "$SRC" "$CP"

# GH #418: the trap goes in BEFORE the first mutant, not after the last one.
SUM=$(mktemp /tmp/wave_fence.r10.sum.XXXXXX)
sha256sum "$SRC" > "$SUM"
restore() { cp "$CP" "$SRC"; }
trap restore EXIT

run() {  # run() <label>
  out=$(python3 tests/test_wave_fence.py 2>&1); rc=$?
  echo "$1: rc=$rc  $(echo "$out" | tail -1)"
  echo "$out" | grep -E '^FAIL' | sed 's/^/    /'
}

run "CONTROL (unmutated)"

# M1 -- the brake stops capping the ruling.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if ceiling > brake:\n        return None, (\"--director-crossing $%.2f is above the $%.2f brake."
assert s.count(old) == 1, "M1 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:\n        return None, (\"--director-crossing $%.2f is above the $%.2f brake.")
open(p,"w").write(s)
PY
run "M1 (a ruling may name a number above the brake)"
cp "$CP" "$SRC"

# M2 -- the subtler half of the same constraint: clamp instead of refuse.  The
# operator's ruling then silently becomes a different ruling, and the run reads
# as if it had been obeyed.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '''    if ceiling > brake:
        return None, ("--director-crossing $%.2f is above the $%.2f brake. The '''
assert s.count(old) == 1, "M2 anchor is not unique -- refusing to mutate blind"
new = '''    if ceiling > brake:
        ceiling = brake
    if False:
        return None, ("--director-crossing $%.2f is above the $%.2f brake. The '''
s = s.replace(old, new)
open(p,"w").write(s)
PY
run "M2 (an over-brake ruling is silently clamped, not refused)"
cp "$CP" "$SRC"

# M3 -- the expiry is written down but never checked: the ruling becomes
# permanent by simply being copied into the next round's command line.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if moment > when:"
assert s.count(old) == 1, "M3 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "M3 (an expired ruling still authorises the crossing)"
cp "$CP" "$SRC"

# M4 -- a ruling with no expiry at all is accepted.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if not expiry:"
assert s.count(old) == 1, "M4 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "M4 (a crossing with no expiry is accepted)"
cp "$CP" "$SRC"

# M5 -- the ruling stops having to name itself, so nothing in the round's
# report says what authorised the money.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if not ref or not str(ref).strip():"
assert s.count(old) == 1, "M5 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "M5 (--crossing-ref is optional)"
cp "$CP" "$SRC"

# M6 -- the crossing runs but stops announcing itself on the exit-0 path, so a
# ruling-funded wave is indistinguishable in the report from a derived one.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "    if crossing is not None and projected > fence:"
assert s.count(old) == 1, "M6 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "    if False:")
open(p,"w").write(s)
PY
run "M6 (the CLEAR line no longer says the ruling is why it passed)"
cp "$CP" "$SRC"

# M7 -- the deliberate hole is filled in the permissive direction: past every
# ACTUAL alert, i.e. past the owner's approval line, a director ruling starts
# authorising launches.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '''        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- stop and report to the "
                     "owner. Do not pick a higher number.")
        return 3, lines'''
assert s.count(old) == 1, "M7 anchor is not unique -- refusing to mutate blind"
new = '''        lines.append("WAVE_FENCE: THROTTLED (exit 3) -- stop and report to the "
                     "owner. Do not pick a higher number.")
        if crossing is not None:
            return 0, lines
        return 3, lines'''
s = s.replace(old, new)
open(p,"w").write(s)
PY
run "M7 (the ruling rescues the no-fence case, past the owner's line)"
cp "$CP" "$SRC"

# M8 -- LOAD-BEARING.  The ruling can only ever RAISE the ceiling, never lower
# it below the derived fence.  A crossing flag that can only buy headroom and
# never cost any IS a bypass switch; the bound is what makes it a ruling.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = '        operative = min(crossing["ceiling"], brake)'
assert s.count(old) == 1, "M8 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, '        operative = min(max(crossing["ceiling"], fence), brake)')
open(p,"w").write(s)
PY
run "M8 (the ruling can only raise the ceiling, never bound it)"
cp "$CP" "$SRC"

# M9 -- reachable but not wired: main() validates the ruling and then never
# passes it to the gate.  Every pure-function check still passes.
python3 - <<'PY'
p="tools/batch_test/soak/wave_fence.py"; s=open(p).read()
old = "                        crossing=crossing)"
assert s.count(old) == 1, "M9 anchor is not unique -- refusing to mutate blind"
s = s.replace(old, "                        crossing=None)")
open(p,"w").write(s)
PY
run "M9 (main validates the ruling, then drops it)"
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

#!/usr/bin/env bash
# Mutation stand for outlatch_capture.py + tests/test_outlatch_capture_liveness.py.
#
# WHY: a green selfcheck proves the assertions RAN, not that they can FAIL.
# Each mutation below breaks one thing the round's reading depends on; the
# stand is only worth anything if every one of them is CAUGHT.
#
# ⚠️ Two traps this stand is built around, both paid for by this stream:
#   - evidence discipline 3: never read an exit code through a pipe.  Every
#     runner call here redirects to a file and reads $?.
#   - the __pycache__ trap (2026-09-04): two mutants whose files have the same
#     byte size written inside the same mtime second make CPython reuse the
#     first one's cache, so the stand measures the PREVIOUS mutant and the
#     failure looks exactly like a pass.  Hence `-B` plus an explicit purge.
#
# Usage: bash tools/agent/mutstand_outlatch_capture.sh
# Exit: 0 = every mutation caught and the originals restored byte-for-byte.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$REPO/tools/batch_test/behavioral/outlatch_capture.py"
LIVE="$REPO/tests/test_outlatch_capture_liveness.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$TOOL" "$WORK/tool.orig"
cp "$LIVE" "$WORK/live.orig"
( cd "$REPO" && sha256sum "${TOOL#$REPO/}" "${LIVE#$REPO/}" > "$WORK/sums" )

purge_cache() {
	find "$REPO/tools/batch_test/behavioral/__pycache__" -name 'outlatch_capture*' -delete 2>/dev/null
}

run_detectors() {
	# Returns 0 only if BOTH the selfcheck and the liveness pins pass.
	purge_cache
	python3 -B "$TOOL" --selfcheck > "$WORK/self.log" 2>&1
	local a=$?
	purge_cache
	python3 -B "$LIVE" > "$WORK/live.log" 2>&1
	local b=$?
	[ $a -eq 0 ] && [ $b -eq 0 ]
}

restore() { cp "$WORK/tool.orig" "$TOOL"; cp "$WORK/live.orig" "$LIVE"; purge_cache; }

# Upgrade the trap now that `restore` and the backups both exist.  Until this
# line the trap was `rm -rf "$WORK"` alone, which on an interrupt deleted the
# ONLY pristine copies (they live inside $WORK) while leaving the mutant in the
# working tree -- strictly worse than no trap.  Armed here, before the first
# mutate, which is the window GH #418 is about.
trap 'restore; rm -rf "$WORK"' EXIT

CAUGHT=0
SURVIVED=0

mutate() {
	local name="$1"; shift
	restore
	python3 -B - "$TOOL" "$@" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
if old not in src:
    sys.stderr.write("MUTATION ANCHOR MISSING: %r\n" % old)
    sys.exit(9)
open(path, "w").write(src.replace(old, new, 1))
PY
	if [ $? -ne 0 ]; then
		echo "  $name: ANCHOR MISSING -- the stand is measuring nothing, fix it"
		SURVIVED=$((SURVIVED + 1))
		return
	fi
	if run_detectors; then
		echo "  $name: SURVIVED  <-- no assertion covers this"
		SURVIVED=$((SURVIVED + 1))
	else
		echo "  $name: CAUGHT"
		CAUGHT=$((CAUGHT + 1))
	fi
}

echo "=== baseline (unmutated) ==="
restore
if run_detectors; then
	echo "  baseline: PASS"
else
	echo "  baseline: FAIL -- stand aborted, nothing below would mean anything"
	sed -n '1,20p' "$WORK/self.log" "$WORK/live.log"
	restore
	exit 1
fi

echo "=== mutations ==="

# M1 pair channels through one global slot instead of per actor.  This is the
# real defect the per-actor code was written to avoid: it splices two heroes'
# overlapping channels into one and loses the other.
mutate "M1 global channel slot" \
	'        if e.get("type") == "MODIFIER_ADD":
            open_by_actor[actor] = (e["t"], e.get("target"))' \
	'        if e.get("type") == "MODIFIER_ADD":
            open_by_actor["ANY"] = (e["t"], e.get("target"))
            actor = "ANY"'

# M2 count a channel still open at the recording boundary as an aborted
# attempt -- inventing a defect out of where the recording stopped.
mutate "M2 unclosed channel counted as aborted" \
	'    unclosed = len(open_by_actor)' \
	'''    unclosed = len(open_by_actor)
    for _a, (_t0, _op) in open_by_actor.items():
        attempts.append({"actor": _a, "t0": _t0, "t1": _t0, "dur": 0.0,
                         "outpost": _op, "leg": leg_of(_a)})'''

# M3 bake the completion threshold in, so --complete-cs stops meaning anything
# and the band in the report becomes unverifiable.
mutate "M3 completion threshold hardcoded" \
	'        complete = caster_s >= complete_cs' \
	'        complete = caster_s >= DEFAULT_COMPLETE_CS'

# M4 file an unknown hero under 'base'.  Silently moves casts onto the leg
# that did not make them.
mutate "M4 unknown actor defaults to base" \
	'''        if team is None:
            return None''' \
	'''        if team is None:
            return "base"'''

# M5 drop the upper edge of the flip window: any later flip in the game gets
# credited to this attempt, so aborted channels start reading as captures.
mutate "M5 flip window unbounded" \
	'            hit = [f for f in r["flips"] if -0.5 <= f["t"] - grp["t1"] <= window_s]' \
	'            hit = [f for f in r["flips"] if -0.5 <= f["t"] - grp["t1"]]'

# M7 put the frame track back on a raw name filter over `snapshots` -- the
# first cut of this reader, which printed 21 luna rows per second in
# 20260905_010205_slot7 because corpse/duplicate entity streams share the name.
mutate "M7 frame track back to a name filter" \
	'    rows = []
    for s in frames.get(canon(hero), ()):
        if t0 <= s["t"] <= t1:' \
	'    rows = []
    for s in timeline.get("snapshots", ()):
        if s.get("hero") == hero and t0 <= s["t"] <= t1:'

# M6 treat every ownership SAMPLE as a flip.  Turns a stable outpost into 300
# captures -- the false positive the selfcheck's control case exists for.
mutate "M6 every sample is a flip" \
	'            if team != prev:' \
	'            if True:'

# ---------------------------------------------------------------- GH #609
# The group rule.  These four are the ones the 2026-09-07 finding is about:
# the old per-attempt floor read every hitch-hiker on a shared capture as an
# abort (11/113 attempts on W52, 11/11 inside multi-caster groups).

# M8 drop the outpost dimension from the grouping key.  Two heroes finishing
# DIFFERENT outposts on the same frame then become one bar, and a pair of
# aborts is promoted to a capture.
mutate "M8 grouping key loses the outpost" \
	'        key = a["outpost"] or ("?unresolved", a["actor"])' \
	'        key = "ANY"'

# M9 stop integrating the number of open channels and count wall-clock
# coverage instead.  This is the pre-#609 reading wearing the new structure:
# two heroes filling a bar together go back to reading as one hero'"'"'s channel,
# so every multi-caster completion becomes an abort again.
mutate "M9 coverage not weighted by caster count" \
	'                caster_s += n_open * (t - prev_t)' \
	'                caster_s += (t - prev_t)'

# M9b hold each channel open a quarter second past its removal, so a re-issue
# seam stops splitting the bar.  viper'"'"'s four re-issues on South
# (20260907_063637_slot3) then sum to 6.7 caster-seconds across 0.1-0.2 s seams
# and read as a capture the game says never happened -- the outpost stayed
# team 2 on every sample from 1353.5 to 1393.5.
# ⚠️ The first cut of this mutation swapped `not n_open` for `not members` in
# the interval-open branch and SURVIVED.  It survived because it is a no-op --
# those two are equal at every reachable point -- not because an assertion was
# missing.  Recorded here because "mutant survived" is read as "assertion
# missing" by default, and that reading would have sent the next round hunting
# for a hole in the selfcheck that does not exist.
mutate "M9b a re-issue seam no longer splits the coverage" \
	'        marks = sorted([(a["t0"], 1, a) for a in lst] + [(a["t1"], -1, a) for a in lst],' \
	'        marks = sorted([(a["t0"], 1, a) for a in lst] + [(a["t1"] + 0.25, -1, a) for a in lst],'

# M10/M11 move the threshold OUT of the range two corpora leave open, in each
# direction.  ⚠️ Deliberately NOT mutated: a move to 5.9.  W52 puts the
# smallest flipping group at 5.8 and W53 puts the largest NON-flipping group at
# 5.8, so the real value is bracketed into [5.8, 5.9] -- the dump's own
# timestamp resolution -- and each of the two candidates misfiles exactly one
# boundary group.  A stand that claimed to catch that move would be asserting
# the constant against itself.  GH #609's acceptance (3) asked for an
# inside-the-band mutant; that ask was wrong and this is the correction.
mutate "M10 threshold above every flipping cluster seen (6.1)" \
	'DEFAULT_COMPLETE_CS = 5.8' \
	'DEFAULT_COMPLETE_CS = 6.1'
mutate "M11 threshold below the non-flipping cluster (5.2)" \
	'DEFAULT_COMPLETE_CS = 5.8' \
	'DEFAULT_COMPLETE_CS = 5.2'

# M12 pool every attempt whose outpost did not resolve under one shared key.
# Unknown values that compare equal merge two towers into one bar.
mutate "M12 unresolved outposts pooled" \
	'        key = a["outpost"] or ("?unresolved", a["actor"])' \
	'        key = a["outpost"] or "?unresolved"'

# M13 re-test each member against its own duration instead of inheriting the
# group verdict.  The group table then reads correct while the per-leg abort
# counts -- the numbers that actually go into a report -- stay wrong.
mutate "M13 members do not inherit the group verdict" \
	'                    m["complete"] = complete' \
	'                    m["complete"] = m["dur"] >= complete_cs'

# M14 sort closes before opens at an equal timestamp.  A hero who steps onto
# the outpost on the exact frame the bar completes then becomes the sole member
# of a zero-length bar of his own and is filed as an abort -- a defect
# manufactured out of a timestamp collision (20260907_003647_slot4).
mutate "M14 equal-timestamp join falls outside the bar" \
	'                       key=lambda m: (m[0], -m[1]))' \
	'                       key=lambda m: (m[0], m[1]))'

restore
echo "=== restore verification ==="
if ( cd "$REPO" && sha256sum -c "$WORK/sums" ); then
	echo "  restore: OK (byte-for-byte)"
else
	echo "  restore: FAILED -- the working tree is NOT the original, fix by hand"
	exit 1
fi

echo "=== result: $CAUGHT CAUGHT / $SURVIVED SURVIVED ==="
[ "$SURVIVED" -eq 0 ]

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
            open_by_actor[actor] = e["t"]' \
	'        if e.get("type") == "MODIFIER_ADD":
            open_by_actor["ANY"] = e["t"]
            actor = "ANY"'

# M2 count a channel still open at the recording boundary as an aborted
# attempt -- inventing a defect out of where the recording stopped.
mutate "M2 unclosed channel counted as aborted" \
	'    unclosed = len(open_by_actor)' \
	'''    unclosed = len(open_by_actor)
    for _a, _t0 in open_by_actor.items():
        attempts.append({"actor": _a, "t0": _t0, "t1": _t0, "dur": 0.0,
                         "complete": False, "leg": leg_of(_a)})'''

# M3 bake the completion floor in, so --complete-s stops meaning anything and
# the sensitivity band in the report becomes unverifiable.
mutate "M3 completion floor hardcoded" \
	'                "complete": dur >= complete_s, "leg": leg_of(actor),' \
	'                "complete": dur >= DEFAULT_COMPLETE_S, "leg": leg_of(actor),'

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
	'            hit = [f for f in r["flips"] if -0.5 <= f["t"] - a["t1"] <= window_s]' \
	'            hit = [f for f in r["flips"] if -0.5 <= f["t"] - a["t1"]]'

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

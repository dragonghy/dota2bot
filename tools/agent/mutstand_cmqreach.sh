#!/usr/bin/env bash
# Mutation stand for tools/batch_test/behavioral/cmqreach_domain.py --selfcheck.
#
# WHY: GH #626 asked for the TP/channel guard AND, in the same work unit, for a
# mutant that proves the guard is load-bearing -- "至少一枚「去掉通道守卫」的变异体
# 必须 CAUGHT,否则守卫等于没写".  A green selfcheck proves the assertions RAN,
# not that they can FAIL.
#
# Built to the same two traps this stream has already paid for:
#   - evidence discipline 3: never read an exit code through a pipe.  Every
#     runner call redirects to a file and reads $?.
#   - the __pycache__ trap (2026-09-04): two mutants of equal byte size written
#     inside the same mtime second make CPython reuse the first one's cache, so
#     the stand measures the PREVIOUS mutant and the failure looks like a pass.
#     Hence `-B` plus an explicit purge.
#   - ANCHOR MISSING is counted as SURVIVED (mutstand_outlatch_capture.sh's M3
#     lesson, 2026-09-08): a stand whose anchor moved measures nothing, and must
#     say so rather than print a clean number.
#
# Usage: bash tools/agent/mutstand_cmqreach.sh
# Exit: 0 = every mutation caught and the original restored byte-for-byte.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$REPO/tools/batch_test/behavioral/cmqreach_domain.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$TOOL" "$WORK/tool.orig"
( cd "$REPO" && sha256sum "${TOOL#$REPO/}" > "$WORK/sums" )

purge_cache() {
	find "$REPO/tools/batch_test/behavioral/__pycache__" -name 'cmqreach_domain*' -delete 2>/dev/null
}

run_detectors() {
	# Returns 0 only if BOTH the module battery and the python-suite door pass.
	# The suite door is included on purpose: it is the one that stays red when
	# an edit deletes the guard AND the module's own case for it.
	purge_cache
	python3 -B "$TOOL" --selfcheck > "$WORK/self.log" 2>&1
	local a=$?
	purge_cache
	python3 -B "$REPO/tests/test_cmqreach_domain.py" > "$WORK/suite.log" 2>&1
	local b=$?
	[ $a -eq 0 ] && [ $b -eq 0 ]
}

restore() { cp "$WORK/tool.orig" "$TOOL"; purge_cache; }

# Upgrade the trap now that `restore` and the backup both exist.  Until this
# line the trap was `rm -rf "$WORK"` alone, which on an interrupt deleted the
# ONLY pristine copy while leaving the mutant in the working tree (GH #418).
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
	sed -n '1,20p' "$WORK/self.log" "$WORK/suite.log"
	restore
	exit 1
fi

echo "=== mutations ==="

# ------------------------------------------------------------------ GH #626
# The guard itself.  M1 is the mutant the issue's acceptance names: the reader
# as it stood when it scored a teleport `away d=-9779`.

# M1 remove the domain guard: channel frames go back into the gap domain.
mutate "M1 domain guard removed (channel frames back in the domain)" \
	'        if g.in_tp(t):                                   # GH #626: not a decision frame' \
	'        if False:                                        # GH #626: not a decision frame'

# M2 remove the movement-window guard.  The domain can be right while the
# LABEL -- the number cell (2) is read off -- is still manufactured by a
# landing displacement.  These are two separate defects and need two mutants.
mutate "M2 movement window guard removed" \
	'    if g.tp_crosses(row["t"], row["t"] + MOVE_WINDOW_S):
        return None' \
	'    if False:
        return None'

# M3 collapse the window guard onto the point guard.  This is the plausible
# under-fix: it excludes frames INSIDE a channel (already done by M1's guard)
# but not a frame whose 2s lookahead crosses the landing, which is exactly the
# case the deadband then reads as `stand` = "the branch refused an order".
mutate "M3 window guard weakened to a point guard" \
	'    if g.tp_crosses(row["t"], row["t"] + MOVE_WINDOW_S):' \
	'    if g.in_tp(row["t"]):'

# M4 drop the identity filter on the channel: any hero's teleport becomes CM's.
# A support who TPs while CM farms would then empty CM's domain -- the failure
# mode `capmono_refusal.tp_channel_spans` keeps a per-hero slot to avoid.
mutate "M4 channel identity dropped (any hero's TP is CM's)" \
	'            elif (e.get("inflictor") == TP_MODIFIER
                  and canon(e.get("target")) == CM):' \
	'            elif e.get("inflictor") == TP_MODIFIER:'

# M5 half-open the channel interval.  The ADD instant and the REMOVE instant
# are the two frames most likely to be sampled (the engine emits them), and an
# off-by-one at the boundary silently readmits them.
mutate "M5 channel interval half-open at the end" \
	'        return any(t0 <= t <= t1 for (t0, t1) in self.tp_spans)' \
	'        return any(t0 <= t < t1 for (t0, t1) in self.tp_spans)'

# M6 drop a channel still open at the recording cut-off.  A game whose .dem
# ends mid-teleport then keeps its channel frames, and the frames lost are the
# ones nearest the cut -- where a truncated track is least trustworthy.
mutate "M6 unclosed channel dropped instead of spanned" \
	'        if tp_open is not None:                          # open at the cut-off
            self.tp_spans.append((tp_open, tp_open + TP_UNCLOSED_S))' \
	'        if False:
            self.tp_spans.append((tp_open, tp_open + TP_UNCLOSED_S))'

# M7 stop counting the dropped frames.  The correction would then be invisible
# in the report -- a silent narrowing of the domain, which is the one thing an
# instrument change must never be (the `n_casters` discipline, 2026-09-08).
mutate "M7 dropped frames no longer counted" \
	'            if stats is not None:
                stats["tp_frames"] = stats.get("tp_frames", 0) + 1' \
	'            if False:
                stats["tp_frames"] = stats.get("tp_frames", 0) + 1'

# M8 pool the two unscored reasons.  A TP window (an instrument correction) and
# a missing lookahead snapshot (a recording gap) would land in one number, and
# the report could no longer say which one moved.
mutate "M8 unscored reasons pooled onto 'no_snapshot'" \
	'    if g.tp_crosses(row["t"], row["t"] + MOVE_WINDOW_S):
        return "tp"' \
	'    if False:
        return "tp"'

# M9 read the channel from displacement instead of ADD/REMOVE -- the tempting
# substitute, and wrong in BOTH directions: it misses the channel frames (she
# stands still in them) and it would swallow every blink.  Emulated here by
# taking the span from the landing only.
mutate "M9 channel inferred from the landing instead of the ADD" \
	'                    self.tp_spans.append((tp_open, e["t"]))' \
	'                    self.tp_spans.append((e["t"], e["t"]))'

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

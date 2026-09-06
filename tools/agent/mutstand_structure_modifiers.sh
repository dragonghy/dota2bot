#!/usr/bin/env bash
# Mutation stand for the structure-modifier join in make_fixture.py, and for
# the two tests that pin it (tests/test_fixture_structure_modifiers.{py,lua}).
#
# WHY: green tests prove the assertions RAN, not that they can FAIL.  The join
# added for GH #511 (甲) is exactly the kind of change whose failure mode is
# silent -- a capture modifier hung on the WRONG outpost still produces a
# fixture that loads, still answers HasModifier = true, and states the opposite
# of the frame it claims to be.  Every mutation below is a plausible way to
# write it wrong; the stand is worth something only if all of them are CAUGHT.
#
# ⚠️ Two traps this stand is built around, both already paid for by this stream:
#   - evidence discipline 3: never read an exit code through a pipe.  Every
#     runner call here redirects to a file and reads $?.
#   - the __pycache__ trap (2026-09-04): two mutants of equal byte size written
#     inside one mtime second make CPython reuse the first one's cache, so the
#     stand measures the PREVIOUS mutant and a survival looks like a catch.
#     Hence `-B` plus an explicit purge, and the generator is additionally run
#     as a SUBPROCESS by the test, which is the same risk one level down.
#
# Usage: bash tools/agent/mutstand_structure_modifiers.sh
# Exit: 0 = every mutation caught and the originals restored byte-for-byte.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN="$REPO/tools/batch_test/replayscope/make_fixture.py"
PYT="$REPO/tests/test_fixture_structure_modifiers.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$GEN" "$WORK/gen.orig"
cp "$PYT" "$WORK/pyt.orig"
( cd "$REPO" && sha256sum "${GEN#$REPO/}" "${PYT#$REPO/}" > "$WORK/sums" )

purge_cache() {
	find "$REPO/tools/batch_test/replayscope/__pycache__" -name 'make_fixture*' -delete 2>/dev/null
	find "$REPO/tests/__pycache__" -name 'test_fixture_structure_modifiers*' -delete 2>/dev/null
	return 0
}

run_detectors() {
	# Only the generator half runs per mutation: the Lua half reads a
	# CHECKED-IN fixture and so cannot see a generator mutation at all.  It is
	# run once, separately, at the end -- and mutated in its own loop below.
	purge_cache
	( cd "$REPO" && python3 -B "$PYT" > "$WORK/py.log" 2>&1 )
}

restore() { cp "$WORK/gen.orig" "$GEN"; cp "$WORK/pyt.orig" "$PYT"; purge_cache; }

# Upgrade the trap now that `restore` and the backups both exist.  Until this
# line the trap was `rm -rf "$WORK"` alone, which on an interrupt deleted the
# ONLY pristine copies (they live inside $WORK) while leaving the mutant in the
# working tree -- strictly worse than no trap.  Armed here, before the first
# mutate, which is the window GH #418 is about.
trap 'restore; rm -rf "$WORK"' EXIT

CAUGHT=0
SURVIVED=0

mutate() {
	local name="$1"; local target="$2"; shift 2
	restore
	python3 -B - "$target" "$@" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
if old not in src:
    sys.stderr.write("MUTATION ANCHOR MISSING: %r\n" % old)
    sys.exit(9)
if old == new:
    sys.stderr.write("MUTATION IS A NO-OP\n")
    sys.exit(9)
open(path, "w").write(src.replace(old, new, 1))
PY
	if [ $? -ne 0 ]; then
		echo "  $name: ANCHOR MISSING or NO-OP -- the stand measures nothing here"
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
	tail -20 "$WORK/py.log"
	restore
	exit 1
fi

echo "=== mutations: the join ==="

# M1 attach the modifier to EVERY outpost instead of the resolved one.  This is
# the mutation the whole file exists for: it is invisible in a one-outpost
# world and it makes a fixture state that both outposts are being captured.
mutate "M1 attach to every outpost" "$GEN" \
	'            outposts[next(iter(seen))]["modifiers"] = mods' \
	'''            for _o in outposts:
                _o["modifiers"] = mods'''

# M2 resolve to the FARTHEST outpost.  Same shape as an off-by-one in the sort
# key; the fixture still loads and still answers true, on the wrong entity.
mutate "M2 resolve to the farthest outpost" "$GEN" \
	'            d = sorted((math.hypot(s["x"] - o["x"], s["y"] - o["y"]), i)
                       for i, o in enumerate(outposts))' \
	'            d = sorted(((math.hypot(s["x"] - o["x"], s["y"] - o["y"]), i)
                        for i, o in enumerate(outposts)), reverse=True)'

# M3 drop the distance ceiling: an actor anywhere on the map now "resolves"
# the outpost, so the refusal case silently becomes an attachment.
mutate "M3 no distance ceiling" "$GEN" \
	'            if d[0][0] > CAPTURE_JOIN_MAX_U:
                continue' \
	'            if False:
                continue'

# M4 drop the ambiguity test: a near-tie now resolves to whichever sorted first.
mutate "M4 no runner-up margin" "$GEN" \
	'            if len(d) > 1 and d[1][0] < CAPTURE_JOIN_RATIO * max(d[0][0], 1e-9):
                continue' \
	'            if False:
                continue'

# M5 accept a split vote (different ADDs pointing at different outposts) by
# taking the majority instead of refusing.  Turns a contradiction into a guess.
mutate "M5 majority instead of unanimity" "$GEN" \
	'            if seen is None or len(seen) != 1:' \
	'            if seen is None:'

# M6 swallow the refusal: resolve nothing, say nothing.  The fixture then
# silently carries no modifier and reads exactly like a calm frame.
mutate "M6 refusals not written into the fixture" "$GEN" \
	'                mod_unresolved.append((tgt, sorted(seen) if seen else []))' \
	'                pass'

# M7 emit the modifier unconditionally rather than only when live at t: every
# fixture from a game that ever saw a capture would carry one.
mutate "M7 modifier not scoped to the instant" "$GEN" \
	'        for tgt, mods in sorted(mods_at_t.items()):' \
	'''        _all = {}
        for _e in tl.get("events", []):
            if _e.get("type") == "MODIFIER_ADD" and str(_e.get("target", "")).startswith("#DOTA_Outpost"):
                _all.setdefault(_e["target"], [{"name": _e.get("inflictor", ""),
                                                "remaining": 0.0, "elapsed": 0.0,
                                                "stacks": 0}])
        for tgt, mods in sorted(_all.items()):'''

echo "=== mutations: the identity key (the ghost outpost) ==="

# M8 put the team back into the structure key.  This is the defect the round
# found: after a capture the fixture carries two live rows at one coordinate.
mutate "M8 structures keyed on team again" "$GEN" \
	'            latest_b[(b["name"], round(b["x"]), round(b["y"]))] = b' \
	'            latest_b[(b["name"], b["team"], round(b["x"]), round(b["y"]))] = b'

echo "=== demo: what a weakened assertion would hide ==="
# NOT counted in the tally, and deliberately so.  Weakening an ASSERTION can
# never turn a suite red -- a "SURVIVED" line for it would be arithmetic, not a
# finding.  What is worth showing is the pair: weaken 1a to "some outpost
# carries it" and the wrong-outpost join (M1) walks straight through.  That is
# the reason 1a is written as an equality against ONE coordinate.
if [ "$SURVIVED" -eq 0 ] && [ "$CAUGHT" -gt 0 ]; then
	restore
	python3 -B - "$PYT" \
		'   carriers(rows) == [NEAR],' \
		'   len(carriers(rows)) >= 1,' <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
open(path, "w").write(src.replace(old, new, 1))
PY
	python3 -B - "$GEN" \
		'            outposts[next(iter(seen))]["modifiers"] = mods' \
		'            for _o in outposts:
                _o["modifiers"] = mods' <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
open(path, "w").write(src.replace(old, new, 1))
PY
	purge_cache
	if ( cd "$REPO" && python3 -B "$PYT" > "$WORK/py2.log" 2>&1 ); then
		echo "  DEMO (M1+M9 together): SURVIVED as designed -- 1a is the assertion"
		echo "         that catches a wrong-outpost join; weakening it hides M1."
	else
		echo "  DEMO (M1+M9 together): still caught -- another check covers it too"
	fi
fi

echo "=== mutations: the LOADER (tests/mock/replay_fixture.lua) ==="
restore
LOADER="$REPO/tests/mock/replay_fixture.lua"
cp "$LOADER" "$WORK/loader.orig"
( cd "$REPO" && sha256sum "${LOADER#$REPO/}" >> "$WORK/sums" )

lua_run() { ( cd "$REPO" && lua5.1 tests/run_tests.lua test_fixture_structure_modifiers \
	> "$WORK/lua.log" 2>&1 ); }

lua_mutate() {
	local name="$1"; shift
	cp "$WORK/loader.orig" "$LOADER"
	python3 -B - "$LOADER" "$@" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
if old not in src:
    sys.stderr.write("MUTATION ANCHOR MISSING: %r\n" % old)
    sys.exit(9)
if old == new:
    sys.stderr.write("MUTATION IS A NO-OP\n")
    sys.exit(9)
open(path, "w").write(src.replace(old, new, 1))
PY
	if [ $? -ne 0 ]; then
		echo "  $name: ANCHOR MISSING or NO-OP -- measures nothing"
		SURVIVED=$((SURVIVED + 1))
		cp "$WORK/loader.orig" "$LOADER"
		return
	fi
	if lua_run; then
		echo "  $name: SURVIVED  <-- no assertion covers this"
		SURVIVED=$((SURVIVED + 1))
	else
		echo "  $name: CAUGHT"
		CAUGHT=$((CAUGHT + 1))
	fi
	cp "$WORK/loader.orig" "$LOADER"
}

if lua_run; then
	echo "  lua baseline: PASS"

	# L1 the index is built ONCE and shared by every structure -- so the last
	# structure's modifiers answer for all of them. §3 and §7 exist for this.
	lua_mutate "L1 one modifier index shared by all structures" \
		'        local bmods = b.modifiers or {}
        local bmod_by_name = {}' \
		'        local bmods = b.modifiers or {}
        bmod_by_name = bmod_by_name or {}'

	# L2 the wiring is dropped entirely -- the pre-change world, in which every
	# structure answered HasModifier = false.
	lua_mutate "L2 HasModifier wiring removed from structures" \
		'            HasModifier = function(_, sName) return bmod_by_name[sName] ~= nil end,
            NumModifiers = #bmods,' \
		'            NumModifiers = #bmods,'

	# L3 the payload is dropped and only names are kept: remaining reads 0,
	# which is the shape a commitment test would silently mis-read as "the
	# channel is over".
	lua_mutate "L3 remaining duration zeroed" \
		'            GetModifierRemainingDuration = function(_, i)
                return (bmods[i + 1] or {}).remaining or 0
            end,' \
		'            GetModifierRemainingDuration = function(_, i)
                return 0
            end,'
else
	echo "  lua baseline: FAIL -- L1/L2/L3 skipped, and that is NOT a pass"
	SURVIVED=$((SURVIVED + 1))
	tail -20 "$WORK/lua.log"
fi
cp "$WORK/loader.orig" "$LOADER"

restore
echo "=== restore check ==="
( cd "$REPO" && sha256sum -c "$WORK/sums" ) && echo "  originals restored byte-for-byte"

echo "=== result: $CAUGHT caught, $SURVIVED survived ==="
[ "$SURVIVED" -eq 0 ] || exit 1

#!/usr/bin/env bash
# Mutation stand for tools/batch_test/behavioral/outpost_block_probe.py.
#
# WHY: this probe's output is about to change what #511 accepts as a
# completion, so a green selfcheck ("the assertions ran") is not enough --
# every assertion has to be able to FAIL.  Each mutation below breaks exactly
# one thing the 2026-09-08 reading rests on; the stand is worth something only
# if all of them are CAUGHT.
#
# Same two traps as the sibling stands, both paid for by this stream:
#   - evidence discipline 3: never read an exit code through a pipe (every
#     runner call here redirects to a file and reads $?).
#   - the __pycache__ trap (2026-09-04): two mutants of equal byte size written
#     inside one mtime second make CPython reuse the first one's cache, so the
#     stand measures the PREVIOUS mutant and the failure looks like a pass.
#     Hence `-B` plus an explicit purge.
#
# Usage: bash tools/agent/mutstand_outpost_block.sh
# Exit: 0 = every mutation caught and the original restored byte-for-byte.
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOOL="$REPO/tools/batch_test/behavioral/outpost_block_probe.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp "$TOOL" "$WORK/tool.orig"

purge_cache() {
	find "$REPO/tools/batch_test/behavioral/__pycache__" \
		-name 'outpost_block_probe*' -delete 2>/dev/null
}

run_detectors() {
	purge_cache
	python3 -B "$TOOL" --selfcheck > "$WORK/self.log" 2>&1
}

restore() { cp "$WORK/tool.orig" "$TOOL"; purge_cache; }

# Upgrade the trap now that `restore` and the backup both exist: until this
# line an interrupt would delete the only pristine copy (it lives in $WORK)
# and leave the mutant in the working tree (GH #418).
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
	sed -n '1,25p' "$WORK/self.log"
	restore
	exit 1
fi

echo "=== mutations ==="

# M1 count corpse frames as blockers.  This is the association the probe
# exists to test, so a dead enemy lying on the outpost would manufacture it.
mutate "M1 corpse frames count as blockers" \
	'                if s["hp_pct"] <= 0:          # corpse frames are not blockers
                    continue' \
	'                if False:
                    continue'

# M2 drop the team test, so the channelling hero's own allies (and the hero
# itself, at distance 0) become "enemies near the outpost".
mutate "M2 own team counted as enemies" \
	'            if team_by.get(hero) == ct or team_by.get(hero) is None:' \
	'            if team_by.get(hero) is None:'

# M3 measure the enemy distance to the CASTER instead of to the OUTPOST.
# Reads the same on a hero standing on the post and differently everywhere
# else, which is exactly the kind of near-miss a selfcheck must pin.
mutate "M3 distance measured to the caster, not the outpost" \
	'                d = _dist(s["x"], s["y"], post[0], post[1])' \
	'                d = _dist(s["x"], s["y"], cx, cy)'

# M4 widen the sample filter past the channel, so an enemy who arrived after
# the channel ended is counted as having been there during it.
mutate "M4 samples outside the channel counted" \
	'                if not (grp["t0"] <= s["t"] <= grp["t1"]):' \
	'                if not (grp["t0"] - 60.0 <= s["t"] <= grp["t1"] + 60.0):'

# M5 guess the outpost instead of refusing.  A group whose caster is nowhere
# near either post gets filed on the nearer one anyway.
mutate "M5 unresolved position guessed instead of refused" \
	'        if pos_err > pos_max:
            unresolved += 1
            continue' \
	'        if False:
            unresolved += 1
            continue'

# M6 stop joining flips to the group's own outpost, so the OTHER outpost's
# capture is credited to this channel (`verify_floor`'s documented looseness,
# which this probe tightened on purpose).
mutate "M6 flip not joined to this outpost" \
	'                if -0.5 <= f["t"] - grp["t1"] <= window_s and f["pos"] == post]' \
	'                if -0.5 <= f["t"] - grp["t1"] <= window_s]'

# M7 read a MISSING REMOVE value as "did not complete".  This is the
# difference between "the field says no" and "there is no field", and it is
# the one that would quietly turn a join bug into a fleet of fake aborts.
mutate "M7 missing REMOVE value read as not-complete" \
	'            "removed_zero": (None if not [v for v in vals if v is not None]
                             else any(v == 0 for v in vals)),' \
	'            "removed_zero": any(v == 0 for v in vals),'

# M8 join the REMOVE value on the actor alone, so a hero who channelled the
# same outpost twice gets whichever value sorted last -- the neighbouring
# channel's outcome pinned onto this one.
mutate "M8 REMOVE value joined on actor alone" \
	'            out[(e.get("actor"), e["t"])] = e.get("value")
    return out' \
	'            out[(e.get("actor"), e["t"])] = e.get("value")
    _last = {}
    for (_a, _t), _v in out.items():
        _last[_a] = _v
    for (_a, _t) in list(out):
        out[(_a, _t)] = _last[_a]
    return out'

# M9 ownership before the channel read from the WHOLE game instead of from
# samples at or before t0, so a later capture makes the outpost look
# already-owned and a real capture reads as a no-op.
mutate "M9 owner_t0 read from the last sample of the game" \
	'        before = [s for s in samples if s[0] <= grp["t0"]]' \
	'        before = list(samples)'

# M10 drop the illusion-safe entity join and go back to a raw name filter over
# `snapshots` -- the 2026-08-25 defect, which here would put an illusion on
# the outpost and invent the blocker the probe is testing for.
mutate "M10 enemy frames back to a name filter" \
	'    frames, team_by = frames_by_hero(timeline)' \
	'    frames, team_by = {}, {}
    for _s in timeline.get("snapshots", ()):
        _k = canon(_s["hero"])
        frames.setdefault(_k, []).append(_s)
        team_by[_k] = _s["team"]'

echo
echo "MUTSTAND caught=$CAUGHT survived=$SURVIVED"
restore
if ( cd "$REPO" && git diff --quiet -- "${TOOL#$REPO/}" ); then
	echo "restore: clean (working tree matches what the stand started from)"
else
	echo "restore: DIRTY -- the stand did not put the file back, do not trust the run"
	exit 1
fi
[ "$SURVIVED" -eq 0 ] || exit 1
exit 0

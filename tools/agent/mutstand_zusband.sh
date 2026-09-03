#!/usr/bin/env bash
# Mutation stand for section 6 of tests/test_replay_260820_zuus_static_band.lua
# -- the in-band registry that replaced `assert(nBand == 1)` (GH #465, hero
# 2026-09-04).  Run by hand when that section is edited, and before quoting any
# of its numbers in a ruling.
#
# DISCIPLINE (the house rules this stand inherits):
#   * out-of-tree `cp` restore, verified with `sha256sum -c`;
#   * `trap restore EXIT` BEFORE the first mutant is applied (GH #418: an
#     interrupted stand otherwise leaves the MUTANT in the working tree);
#   * bare exit codes -- the runner writes to a file and `$?` is read with NO
#     pipe in between (evidence discipline 3);
#   * a mutant whose target string is absent ABORTS instead of scoring caught;
#   * the baseline is proven GREEN before the first mutant.
#
# WHAT THIS STAND IS FOR.  Section 6's product is a READING ("the band holds
# exactly these pairs, and here is why each one is in it"), and a reading has
# two silent failure modes a behaviour change does not:
#
#   (1) THE WALK GOES BLIND.  No fixture is scanned, or no pair is ever scored
#       in-band, and an empty hit list agrees with any registry that happens to
#       be empty.  This is the shape that let a whole-tree read of 0 pass a
#       `<=` ceiling in silence (hero 2026-09-03, GH #459).  M4, M5.
#   (2) THE ARITHMETIC DRIFTS UNDER A MEMBERSHIP THAT DID NOT CHANGE.  The same
#       pair stays in the band for a different reason.  M3 is the reason this
#       section stopped being a count -- and the claim is MEASURED, not argued:
#       clean HEAD in a `git worktree` (the old `assert(nBand == 1)` shape),
#       M3 applied, `lua5.1 tests/run_tests.lua …` exit 0, 15 tests 0 failures.
#       The count cannot see M3; the registry names it.
#
# M1 and M2 are the two directions the registry exists to name: a pair entering
# the band (the corpus grew -- GH #465's own history, and the thing a bumped
# count would have swallowed) and a pair leaving it (evidence moved).
#
# Usage: bash tools/agent/mutstand_zusband.sh
set -u
cd "$(dirname "$0")/../.."

TEST=tests/test_replay_260820_zuus_static_band.lua
RESIDUE=tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua
SYNTH=tests/fixtures/f_mutstand_zusband_synthetic.lua

FILES=("$TEST" "$RESIDUE")

WORK=$(mktemp -d "${TMPDIR:-/tmp}/mutstand_zb.XXXXXX")
for f in "${FILES[@]}"; do
    cp "$f" "$WORK/$(echo "$f" | tr / _)"
done
sha256sum "${FILES[@]}" > "$WORK/sum.txt"

restore() {
    for f in "${FILES[@]}"; do
        cp "$WORK/$(echo "$f" | tr / _)" "$f"
    done
    rm -f "$SYNTH"
    sha256sum -c "$WORK/sum.txt" > /dev/null \
        || { echo "RESTORE FAILED -- the working tree still holds a mutant"; exit 2; }
    echo "RESTORE verified byte-identical"
}

trap restore EXIT

run_tests() {
    lua5.1 tests/run_tests.lua test_replay_260820_zuus_static_band > "$WORK/run.log" 2>&1
    return $?
}

# Substitute LITERALLY (no regex), and abort if the anchor is gone -- a mutant
# that silently applied to nothing scores "caught" for the wrong reason.
sub() {
    F="$1" OLD="$2" NEW="$3" python3 - <<'PY'
import os, sys
f, old, new = os.environ["F"], os.environ["OLD"], os.environ["NEW"]
s = open(f, encoding="utf-8").read()
if old not in s:
    sys.stderr.write("ANCHOR ABSENT in %s: %r\n" % (f, old[:70]))
    sys.exit(3)
open(f, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# ---------------------------------------------------------------------------
echo "=== baseline ==="
run_tests; BASE=$?
tail -2 "$WORK/run.log"
if [ "$BASE" -ne 0 ]; then
    echo "BASELINE RED (exit $BASE) -- stand aborted, nothing below is meaningful"
    exit 2
fi
echo "baseline EXIT=$BASE (green)"

CAUGHT=0
TOTAL=0

score() {
    local name="$1" want="$2"
    TOTAL=$((TOTAL + 1))
    run_tests; local rc=$?
    if [ "$rc" -eq 0 ]; then
        echo "$name  SURVIVED (exit 0) -- the stand cannot see this"
    elif grep -qF "$want" "$WORK/run.log"; then
        echo "$name  caught (exit $rc), and it says why:"
        grep -m1 -F "$want" "$WORK/run.log" | sed 's/^/        /'
        CAUGHT=$((CAUGHT + 1))
    else
        echo "$name  RED (exit $rc) but with the WRONG MESSAGE -- red for a"
        echo "        reason the reader cannot act on; treat as survived:"
        grep -m1 -i 'fail' "$WORK/run.log" | sed 's/^/        /'
    fi
    restore > /dev/null
}

# ---------------------------------------------------------------------------
# M1: the corpus grows and a NEW pair enters the band -- GH #465's own history.
#     Both enemies below are hand-solved to sit inside the band: at Zeus level 9
#     (KV 3.85%) the 1.00 band is hp in (286.0, 302.2] and the 0.75 band is hp
#     in (212.4, 221.2].  A count-shaped assertion answers "got 2" here; the
#     registry must answer with the pair's NAME.
echo
echo "=== M1: a new in-band pair appears (synthetic fixture) ==="
cat > "$SYNTH" <<'LUA'
-- MUTANT (tools/agent/mutstand_zusband.sh) -- deleted on restore.
return {
  game = 'mutstand', time = 1.0, window = 8.0,
  self = 'npc_dota_hero_zuus',
  units = {
    { name = 'npc_dota_hero_zuus', team = 2, hp = 900, max_hp = 900, level = 9, alive = true,
      abilities = { { name = 'zuus_thundergods_wrath', level = 1, cd = 0 } } },
    { name = 'npc_dota_hero_lich', team = 3, hp = 295, max_hp = 900, level = 9, alive = true,
      abilities = { } },
    { name = 'npc_dota_hero_lina', team = 3, hp = 217, max_hp = 900, level = 9, alive = true,
      abilities = { } },
  },
  observed = { burst = {}, died_after = nil },
}
LUA
score "M1" "a NEW in-band pair appeared"

# ---------------------------------------------------------------------------
# M2: a REGISTERED pair leaves the band, because the evidence moved.  Raising
#     skywrath's HP from 220 to 260 puts it above the shipped kill line
#     ((275 + 260*0.09) * 0.75 = 223.8 < 260), so the 0.75 band empties.
echo
echo "=== M2: a registered pair leaves the band (fixture HP moved) ==="
python3 - <<'PY'
import re, sys
p = "tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua"
s = open(p, encoding="utf-8").read()
m = re.search(r"(npc_dota_hero_skywrath_mage'.*?hp = )220\b", s, re.S)
if not m:
    sys.stderr.write("ANCHOR ABSENT: skywrath hp = 220\n"); sys.exit(3)
open(p, "w", encoding="utf-8").write(s[:m.end(1)] + "260" + s[m.end():])
PY
score "M2" "a REGISTERED in-band pair LEFT the band"

# ---------------------------------------------------------------------------
# M3: THE HEADLINE MUTANT.  Skywrath's HP moves 220 -> 219 -- one point, the
#     size of a re-dumped fixture.  The pair STAYS in the band ((275 +
#     219*0.09) * 0.75 = 220.98 >= 219 > (275 + 219*0.039) * 0.75 = 212.66), so
#     the count is still 1 and `sWhere` still names the same pair: THE OLD
#     SHAPE IS GREEN THROUGH THIS.  Measured, not assumed -- clean HEAD in a
#     `git worktree`, this mutant applied, exit 0 (hero 2026-09-04 report §3).
#
#     ⚠ THE FIRST DRAFT OF THIS MUTANT WAS WRONG AND IS WORTH KEEPING WRITTEN
#     DOWN.  It moved static_field's KV base 3.45 -> 3.40 instead, and the new
#     section duly reported "the arithmetic of a REGISTERED pair moved" -- but
#     so did the OLD file, because section 2 already pins that snapshot
#     (`Static Field is 3.45 +0.05/level`, line 239).  The mutant was caught by
#     a SIBLING, and would have been scored as evidence for a claim it says
#     nothing about.  A fixture's HP is under no such tripwire, which is why
#     the isolating mutant has to live there.
echo
echo "=== M3: registered arithmetic drifts, membership unchanged ==="
python3 - <<'PY'
import re, sys
p = "tests/fixtures/f_260902_154755_cm_wandbleed_residue.lua"
s = open(p, encoding="utf-8").read()
m = re.search(r"(npc_dota_hero_skywrath_mage'.*?hp = )220\b", s, re.S)
if not m:
    sys.stderr.write("ANCHOR ABSENT: skywrath hp = 220\n"); sys.exit(3)
open(p, "w", encoding="utf-8").write(s[:m.end(1)] + "219" + s[m.end():])
PY
score "M3" "the arithmetic of a REGISTERED pair moved"

# ---------------------------------------------------------------------------
# M4: the walk is pointed at a glob that matches nothing.  tHits is empty AND
#     the domain is 0.  Without the supply assertion beside the membership
#     check, an empty registry would agree with this in silence.
echo
echo "=== M4: the corpus walk is blinded (glob matches nothing) ==="
sub "$TEST" \
    "io.popen('ls tests/fixtures/f_*.lua 2>/dev/null')" \
    "io.popen('ls tests/fixtures/f_*.luaX 2>/dev/null')" || exit 3
score "M4" "the domain must be non-trivial"

# ---------------------------------------------------------------------------
# M5: the domain still reads 177 -- every fixture is walked, every pair scored
#     -- but nothing is ever recorded in-band.  This is the half M4's supply
#     assertion CANNOT catch, and it must be the membership check that speaks.
echo
echo "=== M5: scoring blinded while the domain stays intact ==="
sub "$TEST" \
    "if nShip >= u.hp and nArm < u.hp then" \
    "if false and nShip >= u.hp and nArm < u.hp then" || exit 3
score "M5" "a REGISTERED in-band pair LEFT the band"

# ---------------------------------------------------------------------------
echo
echo "MUTANTS $CAUGHT/$TOTAL caught"
[ "$CAUGHT" -eq "$TOTAL" ] || exit 1

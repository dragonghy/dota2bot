#!/usr/bin/env python3
"""A fixture's non-hero damage rows must say WHAT hit the bot, not just what kind.

Plain python, no pytest (matches tests/test_canon_hero_join.py).

Background (director 2026-08-22T23:0xZ, test_set.md SS-AR.2).  `make_fixture.py`
classifies every incoming-damage row into one of the four kinds the engine gives
a reader for -- hero / tower / creep / other.  The collapse of NEUTRALS into
'creep' is CORRECT and must stay: the engine hands the script exactly one reader
for both (`WasRecentlyDamagedByCreep`), so a mock that split them would answer a
question the real bot cannot ask.

What was wrong is that the generator also stored `actor = None` on every
non-hero row.  Kind collapsed AND name dropped means "was it a centaur camp or a
melee creep" was deleted at fixture-write time, unrecoverably, for the whole
corpus.

That turned out to be load-bearing rather than cosmetic.  Ruling on the gated
`fieldcreep` veto (GH #119) came down to which of its five vetoed frames were
camp contact and which were lane creeps -- because in a world where the engine's
predicate ignores neutrals, the veto's surviving domain is exactly the frames
where its own condition-(c) arithmetic says it should NOT fire.  The corpus could
not answer, so the source had to be inferred from per-hit magnitude.  This test
pins the fix that makes the next corpus able to answer directly.

Three properties, and the third is the one that actually bites:

  1. KIND STILL COLLAPSES.  A neutral and a lane creep both land on
     `kind = 'creep'`.  A "fix" that split them would break every
     WasRecentlyDamagedByCreep answer in the mock.

  2. `src` DISTINGUISHES THEM, and only on non-hero rows -- hero rows already
     name their actor, and `tests/test_fixture_recent_damage.lua` pins `actor`
     as hero-only, so `src` must not leak onto them.

  3. THE EMITTER ACTUALLY WRITES IT.  The fixture writer names its keys one at a
     time, so a field added to the collector but not to the writer is dropped in
     silence -- which is the identical shape of the bug being fixed.  This test
     therefore drives the REAL SCRIPT end to end and reads the emitted Lua text,
     rather than importing a function and trusting the file on the other side.
     (`recent_damage` is nested inside `main()` and cannot be imported anyway.)

Usage:  python3 tests/test_fixture_damage_source.py
"""
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "tools", "batch_test", "replayscope", "make_fixture.py")

failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


# ---------------------------------------------------------------------------
# A synthetic timeline carrying one of every kind the classifier distinguishes.
# Synthetic is right here: the property under test is the generator's own
# contract, and a real dump cannot be pinned to contain a centaur AND a lane
# creep AND a tower hitting the same hero inside one lookback.
# ---------------------------------------------------------------------------
NEUTRAL = "npc_dota_neutral_centaur_khan"
LANE = "npc_dota_creep_badguys_melee"
TOWER = "npc_dota_badguys_tower1_mid"
VIPER = "npc_dota_hero_viper"

snapshots = []
for t in (98.0, 99.0, 100.0):
    snapshots.append({"t": t, "hero": "npc_dota_hero_lion", "team": 2, "idx": 1,
                      "x": 100.0, "y": 200.0, "hp": 300, "hp_pct": 0.25,
                      "mp": 100, "max_mp": 500, "player_id": 0})
    snapshots.append({"t": t, "hero": VIPER, "team": 3, "idx": 2,
                      "x": 900.0, "y": 800.0, "hp": 900, "hp_pct": 0.9,
                      "mp": 200, "max_mp": 400, "player_id": 5})

events = [
    {"type": "DAMAGE", "t": 99.0, "target": "npc_dota_hero_lion",
     "actor": NEUTRAL, "value": 37},
    {"type": "DAMAGE", "t": 99.5, "target": "npc_dota_hero_lion",
     "actor": LANE, "value": 13},
    {"type": "DAMAGE", "t": 99.7, "target": "npc_dota_hero_lion",
     "actor": VIPER, "actor_hero": True, "value": 50},
    {"type": "DAMAGE", "t": 99.8, "target": "npc_dota_hero_lion",
     "actor": TOWER, "value": 100},
]

tmp = tempfile.mkdtemp(prefix="fixture_src_")
tl_path = os.path.join(tmp, "timeline.json")
out_path = os.path.join(tmp, "f_synthetic_damage_source.lua")
with open(tl_path, "w") as fh:
    json.dump({"snapshots": snapshots, "events": events}, fh)

proc = subprocess.run(
    [sys.executable, GEN, tl_path, "--t", "100", "--hero", "lion", "-o", out_path],
    capture_output=True, text=True)
check(proc.returncode == 0,
      "make_fixture.py exited %d\nstdout: %s\nstderr: %s"
      % (proc.returncode, proc.stdout[-800:], proc.stderr[-800:]))

emitted = ""
if os.path.exists(out_path):
    with open(out_path) as fh:
        emitted = fh.read()

block = re.search(r"recent_damage = \{(.*?)\},\n", emitted, re.S)
check(block is not None, "the emitted fixture carries no recent_damage block at all")

rows = []
if block:
    for raw in re.finditer(r"\{([^{}]*)\}", block.group(1)):
        row = {}
        for k, v in re.findall(r"(\w+) = ('[^']*'|nil|[\d.]+)", raw.group(1)):
            row[k] = v.strip("'") if v.startswith("'") else (None if v == "nil" else v)
        rows.append(row)

# ---------------------------------------------------------------------------
# ANTI-EMPTY-MATCH GUARD, written before the assertions below and not after.
# This repo has been burned seven times by a scan whose regex quietly matched
# nothing while every assertion under it still printed ok (test_set.md SS-AQ.6).
# Every row this timeline feeds in must come back out, or nothing below means
# anything.
# ---------------------------------------------------------------------------
check(len(rows) == len(events),
      "parsed %d rows from the emitted fixture but fed in %d -- the assertions "
      "below would be vacuous. Emitted block: %r"
      % (len(rows), len(events), block.group(1)[:400] if block else None))

by_value = {r.get("value"): r for r in rows}
for want in ("37", "13", "50", "100"):
    check(want in by_value, "no emitted row with value=%s (rows: %r)" % (want, rows))

if all(v in by_value for v in ("37", "13", "50", "100")):
    neutral_row, lane_row = by_value["37"], by_value["13"]
    hero_row, tower_row = by_value["50"], by_value["100"]

    # 1. The engine-shaped collapse survives.
    check(neutral_row.get("kind") == "creep",
          "a neutral must still classify as kind='creep' -- the engine gives one "
          "reader for both; got %r" % neutral_row.get("kind"))
    check(lane_row.get("kind") == "creep",
          "a lane creep must classify as kind='creep'; got %r" % lane_row.get("kind"))

    # 2. ...and is now recoverable, which is the whole point.
    check(neutral_row.get("src") == NEUTRAL,
          "the neutral row must carry src=%r; got %r" % (NEUTRAL, neutral_row.get("src")))
    check(lane_row.get("src") == LANE,
          "the lane-creep row must carry src=%r; got %r" % (LANE, lane_row.get("src")))
    check(neutral_row.get("src") != lane_row.get("src"),
          "two rows that share kind='creep' must not share src -- distinguishing "
          "them is the only reason this field exists")
    check(tower_row.get("src") == TOWER,
          "the tower row must carry src=%r; got %r" % (TOWER, tower_row.get("src")))

    # 3. Hero rows are untouched: `actor` names them, and
    #    tests/test_fixture_recent_damage.lua pins actor as hero-only.
    check("src" not in hero_row,
          "a hero row must NOT carry src -- actor already names it, and adding a "
          "second name invites the two to drift; got %r" % hero_row.get("src"))
    check(hero_row.get("actor") == VIPER,
          "the hero row must still carry actor=%r; got %r" % (VIPER, hero_row.get("actor")))
    check(neutral_row.get("actor") is None,
          "non-hero rows keep actor=nil; got %r" % neutral_row.get("actor"))

    # 4. Append-only: the four original keys keep their order, so a fixture
    #    diffed against an older one differs only by a suffix on some rows.
    for label, row in (("neutral", neutral_row), ("hero", hero_row)):
        keys = [k for k, _ in re.findall(r"(\w+) = ('[^']*'|nil|[\d.]+)",
                                         re.search(r"\{[^{}]*value = %s[^{}]*\}"
                                                   % row["value"],
                                                   block.group(1)).group(0))]
        check(keys[:4] == ["dt", "kind", "actor", "value"],
              "the %s row's first four keys must stay dt/kind/actor/value in that "
              "order (append-only); got %r" % (label, keys))

if failures:
    print("FAIL tests/test_fixture_damage_source.py")
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)

print("ok tests/test_fixture_damage_source.py -- %d rows: neutral and lane creep "
      "share kind='creep' and are separated by src; hero rows unchanged" % len(rows))

#!/usr/bin/env python3
"""A fixture must carry the creep sample, and carry it honestly.

Plain python, no pytest (matches tests/test_fixture_damage_source.py, whose
end-to-end shape this file copies deliberately -- see property 4).

Background (hero 2026-08-31, GH #354).  `make_fixture.py` wrote heroes and
buildings and dropped `timeline["creeps"]` on the floor.  Every fixture in
tests/fixtures/ therefore described a world with NO CREEPS IN IT, and
tests/mock/replay_fixture.lua answers `FindAoELocation` with the conservative
stand-in `{count = 0, ...}`.  Every shipped creep-AoE decision sits behind a
`.count >= 2..5` read of that result, so those branches were not "unexercised by
the corpus" -- they were unreachable by construction in every fixture ever
generated.  That is why GH #354 section 5's "pin a fixture on the gap frame"
could not be built: the datum the question is about was discarded at
fixture-write time.

Four properties:

  1. THE BLOCK IS EMITTED, with position and team, and nothing else -- the dump
     carries nothing else (dumper/main.go writes {t, team, x, y} per sample: no
     id, no name, no health).  A fixture that grew an `hp` field would be
     inventing one, and tests/test_cm_creep_reach_real_frame.lua section 6 reads
     its absence as the reason the KILL search cannot be priced.

  2. THE NEAREST SAMPLE WINS, not the latest at or before t.  Creeps are sampled
     coarsely (3.0s on the wave farm) and march ~325 u/s, so "the last sample
     before the instant" can be a wave several hundred units back -- the exact
     staleness GH #354 section 3 showed swallowing whole conclusions.

  3. `dt` AND `creep_interval` ARE EMITTED, so a test can say how stale its
     world is instead of assuming it is fresh.  A block without them reads as a
     freshness claim nobody made.

  4. THE EMITTER ACTUALLY WRITES IT.  The fixture writer names its keys one at a
     time, so a field added to the collector but not to the writer is dropped in
     silence.  This test therefore drives the REAL SCRIPT end to end and reads
     the emitted Lua text.

Usage:  python3 tests/test_fixture_creeps.py
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
# A synthetic timeline: creep samples at 97/100/103, the subject at 100.  The
# t=100 sample is both the nearest AND the latest-at-or-before, so it cannot
# distinguish the two rules -- so the SECOND run below asks for t = 101.6, where
# nearest (103) and latest-before (100) disagree.
# ---------------------------------------------------------------------------
LION = "npc_dota_hero_lion"
VIPER = "npc_dota_hero_viper"

snapshots = []
for t in (99.0, 100.0, 101.0, 101.4, 102.0):
    snapshots.append({"t": t, "hero": LION, "team": 2, "idx": 1,
                      "x": 0.0, "y": 0.0, "hp": 300, "hp_pct": 0.25,
                      "mp": 100, "max_mp": 500, "player_id": 0})
    snapshots.append({"t": t, "hero": VIPER, "team": 3, "idx": 2,
                      "x": 900.0, "y": 800.0, "hp": 900, "hp_pct": 0.9,
                      "mp": 200, "max_mp": 400, "player_id": 5})

creeps = []
for t, tag in ((97.0, -1000.0), (100.0, 0.0), (103.0, 1000.0)):
    # Two lane creeps of each team plus one neutral, all offset by `tag` in x so
    # a run can tell WHICH sample it got, and one far creep that the radius
    # filter must drop.
    creeps.append({"t": t, "team": 2, "x": 100.0 + tag, "y": 0.0})
    creeps.append({"t": t, "team": 2, "x": 200.0 + tag, "y": 0.0})
    creeps.append({"t": t, "team": 3, "x": 300.0 + tag, "y": 0.0})
    creeps.append({"t": t, "team": 4, "x": 400.0 + tag, "y": 0.0})
    creeps.append({"t": t, "team": 2, "x": 9000.0, "y": 9000.0})

tmp = tempfile.mkdtemp(prefix="fixture_creeps_")
tl_path = os.path.join(tmp, "timeline.json")
with open(tl_path, "w") as fh:
    json.dump({"snapshots": snapshots, "events": [], "creeps": creeps}, fh)


def generate(t):
    out_path = os.path.join(tmp, "f_synth_%s.lua" % str(t).replace(".", "_"))
    proc = subprocess.run(
        [sys.executable, GEN, tl_path, "--t", str(t), "--hero", "lion",
         "-o", out_path],
        capture_output=True, text=True)
    check(proc.returncode == 0,
          "make_fixture.py --t %s exited %d\nstdout: %s\nstderr: %s"
          % (t, proc.returncode, proc.stdout[-800:], proc.stderr[-800:]))
    if not os.path.exists(out_path):
        return "", []
    with open(out_path) as fh:
        emitted = fh.read()
    block = re.search(r"creeps = \{(.*?)\n  \},", emitted, re.S)
    rows = []
    if block:
        for raw in re.finditer(r"\{([^{}]*)\}", block.group(1)):
            row = {}
            for k, v in re.findall(r"(\w+) = (-?[\d.]+)", raw.group(1)):
                row[k] = float(v)
            rows.append(row)
    return emitted, rows


# --- property 1 + 4: the block exists and carries exactly the dump's fields ---
emitted, rows = generate(100)
# ANTI-EMPTY-MATCH GUARD, written before the assertions and not after: four of
# the five creeps in the t=100 sample are inside the 3000 radius.
check(len(rows) == 4,
      "parsed %d creep rows at t=100, expected the 4 inside the radius -- the "
      "assertions below would be vacuous.  Emitted: %r" % (len(rows), emitted[-900:]))
for r in rows:
    check(sorted(r.keys()) == ["dt", "team", "x", "y"],
          "a creep row carries fields the dump does not have: %r" % (sorted(r.keys()),))
check(sorted(r["team"] for r in rows) == [2.0, 2.0, 3.0, 4.0],
      "both teams and the neutral must survive; the loader/test decides which "
      "are enemies, not the generator: %r" % ([r["team"] for r in rows],))
check(all(r["x"] < 3000 for r in rows),
      "the 9000,9000 creep is outside every shipped search and must be dropped")
check("hp" not in emitted.split("creeps = {")[-1].split("},")[0],
      "a creep row grew a health field -- the dump has none to give")

# --- property 3: dt and creep_interval -------------------------------------
check("creep_interval = 3.0," in emitted,
      "creep_interval is not emitted, so no test can say how stale its world is")
check(all(r.get("dt") == 0.0 for r in rows),
      "at t=100 the sample sits on the instant, so every dt must be 0.0: %r"
      % ([r.get("dt") for r in rows],))

# --- property 2: NEAREST sample, not latest-at-or-before --------------------
# t = 101.6 is 1.6s after the t=100 sample and 1.4s before the t=103 one, so the
# two rules disagree here and only here.  Latest-at-or-before would answer the
# +0 offsets; nearest answers the +1000 ones.
emitted2, rows2 = generate(101.6)
check(len(rows2) == 4, "parsed %d creep rows at t=101.6, expected 4" % len(rows2))
xs = sorted(r["x"] for r in rows2)
check(xs == [1100.0, 1200.0, 1300.0, 1400.0],
      "the NEARER sample (t=103, +1000) must win over the latest-before one "
      "(t=100, +0).  Got: %r" % (xs,))
check(all(r.get("dt") == 1.4 for r in rows2),
      "dt must be the sample's offset from t (103 - 101.6 = +1.4): %r"
      % ([r.get("dt") for r in rows2],))

# --- a dump with no creeps at all keeps the old, creep-free world -----------
tl2 = os.path.join(tmp, "timeline_nocreeps.json")
with open(tl2, "w") as fh:
    json.dump({"snapshots": snapshots, "events": []}, fh)
out3 = os.path.join(tmp, "f_synth_nocreeps.lua")
proc = subprocess.run(
    [sys.executable, GEN, tl2, "--t", "100", "--hero", "lion", "-o", out3],
    capture_output=True, text=True)
check(proc.returncode == 0, "make_fixture.py on a creep-free dump exited %d: %s"
      % (proc.returncode, proc.stderr[-400:]))
if os.path.exists(out3):
    with open(out3) as fh:
        old = fh.read()
    check("creeps = {" not in old and "creep_interval" not in old,
          "a pre-creeps dump must keep its old world byte for byte -- no empty "
          "block, no zero interval")

if failures:
    for f in failures:
        print("FAIL: %s" % f)
    print("%d failure(s)" % len(failures))
    sys.exit(1)
print("ok: fixture creep block (emitted, nearest sample, dt/interval, no health)")

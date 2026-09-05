#!/usr/bin/env python3
"""[replay-check] The generator half of "a structure's modifiers reach a fixture".

Companion to tests/test_fixture_structure_modifiers.lua, which pins the LOADER
half on a checked-in fixture.  This file pins make_fixture.py itself, because
the part that can go quietly wrong is not "does a modifier arrive" but "does it
arrive on the RIGHT outpost, and does the generator REFUSE when it cannot tell".

GH #511 handoff (甲), 2026-09-05.  The handoff read "the dumper's `buildings`
record needs `modifiers`".  It does not: the field is already in the dump, one
table over -- `events` carries MODIFIER_ADD/REMOVE with
target = `#DOTA_OutpostName_North|South` -- and `active_modifiers` already
rebuilt every interval from it.  Only the HERO keys were ever read, so the
structure keys were computed and dropped.  What was actually missing is the
JOIN from a compass-word log name to a coordinate, and the join is the thing
worth testing: nothing in the dump maps them, and the compass word does not
describe the axis the two outposts differ on (both sit at y = -448).  So it is
derived from the game rule -- a capture channel requires the actor to stand on
the outpost -- and every case where that rule cannot decide has to end in a
declared refusal, not a coin flip.  A capture modifier silently hung on the
wrong outpost would make a fixture state the opposite of the frame.

THE POSITIVE CASES ARE REAL FRAMES, not synthetic ones: the two verbatim
dumper slices the strategy group checked in for the same issue
(run spot_20260905_003250_1_..._695907, seed 4763).  The refusal cases are those
same slices with ONE field moved, so a control differs from a positive in
exactly the thing under test.

Run: python3 tests/test_fixture_structure_modifiers.py     (exit 0 clean)
"""

import copy
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
GEN = os.path.join(REPO, "tools", "batch_test", "replayscope", "make_fixture.py")
LUNA_TL = os.path.join(HERE, "fixtures", "tl_260905_010205_luna_outchan.json")
AXE_TL = os.path.join(HERE, "fixtures", "tl_260905_010226_axe_outchan.json")
CAPTURING = "modifier_watch_tower_capturing"
NEAR = (3392, -448)     # the outpost both episodes are captured at
FAR = (-4096, -448)     # the other one, ~7500u away

CHECKS = []


def ck(name, cond, detail=""):
    CHECKS.append((name, bool(cond), detail))


BUILDING_RE = re.compile(
    r"\{ name = '(?P<name>[a-z_]+)', team = (?P<team>\d+), x = (?P<x>-?\d+), "
    r"y = (?P<y>-?\d+), alive = (?P<alive>\w+), hp = (?P<hp>[\d.]+),"
    r"(?P<tail>(?:[^}]|\}(?!\s*,\s*$))*)\},?\s*$", re.M)


def generate(tl_path, t, hero):
    """Run the real generator; return (buildings, refusal_comments, stdout)."""
    out = os.path.join(TMP, "f_%d.lua" % len(os.listdir(TMP)))
    p = subprocess.run([sys.executable, GEN, tl_path, "--t", str(t),
                        "--hero", hero, "-o", out],
                       cwd=REPO, capture_output=True, text=True)
    if p.returncode != 0:
        raise AssertionError("generator failed: %s\n%s" % (p.stdout, p.stderr))
    src = open(out).read()
    block = src.split("buildings = {", 1)
    rows = []
    if len(block) > 1:
        body = block[1].split("\n  },", 1)[0]
        for m in BUILDING_RE.finditer(body):
            mods = re.findall(r"name = '([a-z_]+)', remaining = ([\d.-]+), "
                              r"elapsed = ([\d.-]+), stacks = (\d+)", m.group("tail"))
            rows.append({"name": m.group("name"), "team": int(m.group("team")),
                         "xy": (int(m.group("x")), int(m.group("y"))),
                         "mods": [(a, float(b), float(c), int(d)) for a, b, c, d in mods]})
    refusals = re.findall(r"^  --   (\S+) -- (.+)$", src, re.M)
    return rows, refusals, p.stdout


def carriers(rows, mod=CAPTURING):
    return sorted(r["xy"] for r in rows if any(m[0] == mod for m in r["mods"]))


def tmp_tl(tl):
    path = os.path.join(TMP, "tl_%d.json" % len(os.listdir(TMP)))
    with open(path, "w") as fh:
        json.dump(tl, fh)
    return path


TMP = tempfile.mkdtemp(prefix="structmods_")

# ------------------------------------------------------------------ section 1
# Real frames: the modifier lands, and it lands on ONE outpost -- the one the
# actor is standing on.
rows, refusals, _ = generate(LUNA_TL, 1350.5, "luna")
ck("1a the real luna frame puts the capture modifier on exactly one outpost",
   carriers(rows) == [NEAR],
   "got %r" % (carriers(rows),))
ck("1b two outposts are present, so 1a is a choice and not the only option",
   sorted(r["xy"] for r in rows if r["name"] == "watch_tower") == [FAR, NEAR])
ck("1c remaining/elapsed are the real interval, not a placeholder",
   any(m[0] == CAPTURING and abs(m[1] - 1.3) < 0.05 and abs(m[2] - 0.6) < 0.05
       for r in rows for m in r["mods"]),
   "ADD 1349.9 -> REMOVE 1351.8, read at 1350.5")

# ANTI-VACUUM.  Same game, same outposts, an instant BEFORE the first channel
# opens.  If the emitter were unconditional this is where it would show.
rows_idle, _, _ = generate(LUNA_TL, 1349.5, "luna")
ck("1d an instant before the first ADD carries no capture modifier anywhere",
   carriers(rows_idle) == [] and len(rows_idle) == 2,
   "got %r" % (carriers(rows_idle),))

# A SECOND, INDEPENDENT GAME.  Different hero, different leg, same join.
rows_axe, _, _ = generate(AXE_TL, 1021.4, "axe")
ck("1e the axe episode resolves to the same physical outpost",
   carriers(rows_axe) == [NEAR], "got %r" % (carriers(rows_axe),))

# ------------------------------------------------------------------ section 2
# Refusals.  Each control is the real slice with ONE field changed.
base = json.load(open(LUNA_TL))

# 2a  The actor is nowhere near either outpost at the ADD instant.  The log
# still names an outpost; the rule cannot say which, so nothing is attached.
far_tl = copy.deepcopy(base)
for s in far_tl["snapshots"]:
    if s["hero"] == "npc_dota_hero_luna":
        s["x"], s["y"] = 0.0, 6000.0
rows_far, ref_far, _ = generate(tmp_tl(far_tl), 1350.5, "luna")
ck("2a an actor 6000u from both outposts yields NO attachment",
   carriers(rows_far) == [], "got %r" % (carriers(rows_far),))
ck("2b and the refusal is written into the fixture, not swallowed",
   any(t.startswith("#DOTA_Outpost") for t, _ in ref_far),
   "refusals: %r" % (ref_far,))

# 2c  Ambiguous: the two outposts are moved to sit either side of the actor at
# equal distance, both inside the join radius.  Nearest is well-defined by a
# hair, and that is exactly the case that must NOT be resolved.
amb = copy.deepcopy(base)
anchor = next(s for s in amb["snapshots"]
              if s["hero"] == "npc_dota_hero_luna" and abs(s["t"] - 1349.5) < 0.6)
for b in amb["buildings"]:
    if b["name"] == "watch_tower":
        b["x"] = anchor["x"] + (200 if b["x"] > 0 else -200)
        b["y"] = anchor["y"]
rows_amb, ref_amb, _ = generate(tmp_tl(amb), 1350.5, "luna")
ck("2c two outposts equidistant inside the radius yield NO attachment",
   carriers(rows_amb) == [], "got %r" % (carriers(rows_amb),))

# 2d  ANTI-VACUUM FOR THE CONTROLS: move the outposts the same way but leave
# ONE clearly nearest, and the attachment must come back.  Without this, 2a/2c
# would also pass if the feature were simply broken.
ok = copy.deepcopy(base)
for b in ok["buildings"]:
    if b["name"] == "watch_tower" and b["x"] > 0:
        b["x"], b["y"] = anchor["x"] + 100, anchor["y"]
rows_ok, _, _ = generate(tmp_tl(ok), 1350.5, "luna")
ck("2d the same edit with one outpost clearly nearest DOES attach",
   len(carriers(rows_ok)) == 1, "got %r" % (carriers(rows_ok),))

# The three refusal clauses are separately load-bearing, and a control that
# trips two of them at once cannot tell which one did the work: dropping either
# clause then still refuses, and the mutation stand reports it as covered when
# it is only masked. (Measured: 2a trips the ceiling AND the margin; 2c trips
# the margin AND unanimity. Both showed as SURVIVED for M3/M4/M5 until the
# three controls below existed.) Each of these trips exactly one clause.


def luna_at(tl, fn):
    """Move luna to fn(t) on every snapshot; return the edited timeline."""
    for s in tl["snapshots"]:
        if s["hero"] == "npc_dota_hero_luna":
            s["x"], s["y"] = fn(s["t"])
    return tl


# 2e  CEILING ONLY: 2000u from the nearest outpost -- over the 500u ceiling --
# but the runner-up is 7750u away, so the margin clause is satisfied.
ceil_only = luna_at(copy.deepcopy(base), lambda _t: (3392.0, 1552.0))
rows_ce, _, _ = generate(tmp_tl(ceil_only), 1350.5, "luna")
ck("2e over the distance ceiling with an unambiguous nearest: still refused",
   carriers(rows_ce) == [], "got %r" % (carriers(rows_ce),))

# 2f  MARGIN ONLY: both outposts inside the ceiling (100u and 150u) and every
# vote agrees, so only the runner-up margin can refuse this.
margin_only = luna_at(copy.deepcopy(base), lambda _t: (0.0, 0.0))
for b in margin_only["buildings"]:
    if b["name"] == "watch_tower":
        b["x"], b["y"] = (100.0 if b["x"] > 0 else 150.0), 0.0
rows_mo, _, _ = generate(tmp_tl(margin_only), 1350.5, "luna")
ck("2f a 100u/150u pair (inside the ceiling, under the 2x margin): refused",
   carriers(rows_mo) == [], "got %r" % (carriers(rows_mo),))

# 2g  UNANIMITY ONLY: luna stands ON one outpost for the early channels and ON
# the other for the late ones. Every individual vote clears the ceiling and the
# margin; they simply disagree, which is the only thing left to refuse on.
split = luna_at(copy.deepcopy(base),
                lambda t: (3392.0, -448.0) if t < 1353.0 else (-4096.0, -448.0))
rows_sp, ref_sp, _ = generate(tmp_tl(split), 1356.5, "luna")
ck("2g votes that disagree are refused, not majority-resolved",
   carriers(rows_sp) == [], "got %r" % (carriers(rows_sp),))
# The refusal line records the votes it could not reconcile, so the split is
# readable rather than asserted: a one-element list would mean 2g refused for
# some other reason and proves nothing about unanimity.
ck("2h and the refusal names TWO candidate outposts (anti-vacuum for 2g)",
   any(t.startswith("#DOTA_Outpost") and w.strip().startswith("[")
       and w.count(",") >= 1 for t, w in ref_sp),
   "refusals: %r" % (ref_sp,))

# ------------------------------------------------------------------ section 3
# The ghost outpost.  Structures used to be keyed on (name, TEAM, x, y); an
# outpost changes hands, so a fixture taken after a capture carried two live
# rows at one coordinate.  13 captures happened in the 37-game W47 corpus.
flip = copy.deepcopy(base)
flip["buildings"] = [b for b in flip["buildings"]]
for b in flip["buildings"]:
    if b["name"] == "watch_tower" and b["x"] > 0 and b["t"] >= 1354.0:
        b["team"] = 2                      # captured by the other team
have_flip = any(b["name"] == "watch_tower" and b["x"] > 0 and b["team"] == 2
                for b in flip["buildings"])
ck("3a the flip control really contains a flip (anti-vacuum)", have_flip)
rows_flip, _, _ = generate(tmp_tl(flip), 1360.5, "luna")
at_near = [r for r in rows_flip if r["xy"] == NEAR]
ck("3b after a capture there is exactly ONE row at that coordinate",
   len(at_near) == 1, "got %d rows: %r" % (len(at_near), at_near))
ck("3c and it names the NEW owner, not the old one",
   at_near and at_near[0]["team"] == 2,
   "team=%r" % (at_near[0]["team"] if at_near else None,))
# What the old keying would have produced, computed from the same dump so the
# claim above is a difference and not an assertion about history.
old_keys = set()
for b in flip["buildings"]:
    if b["t"] <= 1360.5:
        old_keys.add((b["name"], b["team"], round(b["x"]), round(b["y"])))
ck("3d the previous keying would have emitted two rows there",
   len([k for k in old_keys if (k[2], k[3]) == NEAR]) == 2,
   "old keys at NEAR: %r" % ([k for k in old_keys if (k[2], k[3]) == NEAR],))

# ------------------------------------------------------------------ section 4
# The claim this whole change rests on: no dumper change was needed.
ck("4a the dump already carries the capture modifier as a combat-log event",
   any(e.get("inflictor") == CAPTURING and str(e.get("target", "")).startswith("#DOTA_Outpost")
       for e in base["events"]))
ck("4b and the buildings record still does NOT carry a modifiers field",
   all("modifiers" not in b for b in base["buildings"]),
   "if this flips, the dumper grew the field and the join here may be "
   "redundant -- check before deleting it")

# ------------------------------------------------------------------ section 5
# Emission shape: a structure the generator attached nothing to must not gain a
# `modifiers` field at all, so every fixture generated before this change keeps
# its world (loader default: no modifier) byte for byte.
out = os.path.join(TMP, "shape.lua")
subprocess.run([sys.executable, GEN, LUNA_TL, "--t", "1350.5", "--hero", "luna",
                "-o", out], cwd=REPO, capture_output=True, text=True, check=True)
src = open(out).read()
bl = src.split("buildings = {", 1)[1].split("\n  },", 1)[0]
ck("5a exactly one structure row carries a modifiers field",
   bl.count("modifiers = {") == 1, "block:\n%s" % bl)
ck("5b and the other row omits the field entirely (not an empty table)",
   "modifiers = { }" not in bl and "modifiers = {}" not in bl)
ck("5c an instant with no capture emits no structure modifiers field at all",
   "modifiers" not in open(
       subprocess.run([sys.executable, GEN, LUNA_TL, "--t", "1349.5", "--hero",
                       "luna", "-o", os.path.join(TMP, "idle.lua")],
                      cwd=REPO, capture_output=True, text=True, check=True)
       and os.path.join(TMP, "idle.lua")).read().split(
           "buildings = {", 1)[1].split("\n  },", 1)[0])

print("\n".join("%-4s %s%s" % ("ok" if p else "FAIL", n,
                               ("  -- " + d) if (d and not p) else "")
                for n, p, d in CHECKS))
bad = [n for n, p, _ in CHECKS if not p]
print("STRUCTMODS %d checks, %d failed" % (len(CHECKS), len(bad)))
sys.exit(1 if bad else 0)

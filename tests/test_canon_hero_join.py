#!/usr/bin/env python3
"""The snapshot/event join key must be underscore-insensitive AND collision-free.

Plain python, no pytest (matches tests/test_hero_position.py).

Background (`[harness]` GH #82).  The dumper derives a snapshot's hero name from
the ENTITY CLASS -- `dumper/main.go:190 snakeFromClass` strips the class prefix,
deletes existing underscores and then inserts one at every camelCase boundary --
while DEATH events carry the COMBAT LOG name.  Wherever the engine's own npc
name concatenates words that the class camelCases, the two spellings disagree
and `death_spans()` produced NO span at all for that hero, i.e. the criterion
the director made the ONLY accepted liveness test reported them alive through
every death (196 corpse frames in the hero group's 19-game corpus).

Two properties are load-bearing and neither is visible in a single detector run:

  1. UNDERSCORE-INSENSITIVE FOR EVERY HERO, not just the two that happened to
     be observed.  `anti_mage` is the third structurally-affected name in this
     repo's roster: the combat log spells it `npc_dota_hero_antimage` while
     `CDOTA_Unit_Hero_AntiMage` derives `npc_dota_hero_anti_mage`.  It did not
     appear in the corpus that motivated the fix, so an alias-table "fix"
     covering exactly queen_of_pain and vengeful_spirit would look complete and
     still be blind to Anti-Mage.  That is why the join must be a RULE.

  2. COLLISION-FREE.  An underscore-insensitive key is only safe while no two
     distinct heroes collapse onto the same token; if two ever did, the fix for
     #82 would silently merge their death spans -- a strictly worse failure
     than the one it repairs.  Checked here against every hero name the bot
     scripts mention, so a future roster addition that breaks it fails HERE
     rather than inside somebody's detector read.

Usage:  python3 tests/test_canon_hero_join.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "batch_test", "behavioral"))
sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))
import roam_conversion as RC  # noqa: E402
from lua_corpus import CorpusVanished, bots_lua_files, read_lua, uncertifiable  # noqa: E402

failures = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        failures.append(msg)
        print("  FAIL %s" % msg)


def roster():
    """Every `npc_dota_hero_*` name the shipped bot scripts mention."""
    names = set()
    pat = re.compile(r"npc_dota_hero_[a-z0-9_]+")
    # GH #243: shared corpus listing (excludes the gitignored gate switch) and
    # a read that reports a mid-scan vanish as did-not-run, not as a shorter
    # roster -- a roster that silently lost a file reads as a real join defect.
    try:
        for path in bots_lua_files(ROOT):
            names.update(pat.findall(read_lua(path, errors="ignore")))
    except CorpusVanished as exc:
        uncertifiable(exc, "tests/test_canon_hero_join.py")
    return sorted(names)


def timeline(snapshot_name, event_name):
    """One hero, one death at t=10, fountain respawn at t=40.

    Snapshots every 0.5s; the corpse sits at hp_pct 0.0 where it died and the
    respawn is the >1500u fountain jump `death_spans()` looks for.
    """
    snaps = []
    t = 0.0
    while t < 60.0:
        if t < 10.0:
            hp, x, y = 1.0, 0.0, 0.0
        elif t < 40.0:
            hp, x, y = 0.0, 0.0, 0.0
        else:
            hp, x, y = 1.0, 6000.0, 6000.0
        snaps.append({"hero": snapshot_name, "idx": 1, "t": round(t, 1),
                      "x": x, "y": y, "hp_pct": hp})
        t += 0.5
    events = [{"type": "DEATH", "t": 10.0, "target": event_name, "target_hero": True}]
    return {"snapshots": snaps, "events": events}, {snapshot_name: 1}


print("canon_hero(): rule, not alias table")
check(RC.canon_hero("npc_dota_hero_queen_of_pain")
      == RC.canon_hero("npc_dota_hero_queenofpain"), "queen_of_pain joins queenofpain")
check(RC.canon_hero("npc_dota_hero_vengeful_spirit")
      == RC.canon_hero("npc_dota_hero_vengefulspirit"),
      "vengeful_spirit joins vengefulspirit")
check(RC.canon_hero("npc_dota_hero_anti_mage")
      == RC.canon_hero("npc_dota_hero_antimage"),
      "anti_mage joins antimage (predicted, absent from the #82 corpus)")
check(RC.canon_hero("npc_dota_hero_not_a_real_hero")
      == RC.canon_hero("npc_dota_hero_notarealhero"),
      "an unlisted name joins too -- an alias table would fail here")
check(RC.canon_hero(None) is None, "None survives (callers pass raw snapshot fields)")

print("canon_hero(): collision-free over the roster")
names = roster()
check(len(names) > 100, "roster scraped from bots/ (%d names)" % len(names))
buckets = {}
for n in names:
    buckets.setdefault(RC.canon_hero(n), []).append(n)
collisions = {k: v for k, v in buckets.items() if len(v) > 1}
check(not collisions, "no two hero names collapse onto one key%s"
      % ("" if not collisions else " -- %r" % collisions))

print("is_dead(): the join actually reaches the spans (end-to-end)")
for snap_name, ev_name, label in [
        ("npc_dota_hero_queen_of_pain", "npc_dota_hero_queenofpain", "queen of pain"),
        ("npc_dota_hero_vengeful_spirit", "npc_dota_hero_vengefulspirit", "vengeful spirit"),
        ("npc_dota_hero_anti_mage", "npc_dota_hero_antimage", "anti-mage"),
]:
    tl, real_idx = timeline(snap_name, ev_name)
    spans = RC.death_spans(tl, real_idx)
    check(bool(spans), "%s: a span exists at all (this is what #82 lost)" % label)
    # Either spelling must answer, because callers hold whichever their own
    # data source gave them: detectors read the SNAPSHOT name, event-driven
    # code reads the EVENT name.
    for held in (snap_name, ev_name):
        check(not RC.is_dead(spans, held, 9.5), "%s: alive before death (%s)" % (label, held))
        check(RC.is_dead(spans, held, 10.0), "%s: dead at the DEATH tick (%s)" % (label, held))
        check(RC.is_dead(spans, held, 25.0), "%s: dead mid-span (%s)" % (label, held))
        check(not RC.is_dead(spans, held, 45.0), "%s: alive after respawn (%s)" % (label, held))

print("is_dead(): an agreeing spelling is unaffected")
tl, real_idx = timeline("npc_dota_hero_witch_doctor", "npc_dota_hero_witch_doctor")
spans = RC.death_spans(tl, real_idx)
check(RC.is_dead(spans, "npc_dota_hero_witch_doctor", 25.0),
      "witch_doctor (both sides agree) still reads dead")

print()
if failures:
    print("FAILED %d" % len(failures))
    for f in failures:
        print("  - %s" % f)
    sys.exit(1)
print("all checks passed")

#!/usr/bin/env python3
"""Pins for `zusult_gate.py` -- the two ways this scanner was NOT measuring
what its output line claimed, both found on the W44 corpus 2026-09-04.

  1. **THE INSTRUMENT DID NOT RUN AT ALL.**  `snapshots[].abilities` is `None`
     on 10271 of 79735 Zeus frames in that corpus (12.9%; 735 of them with
     Zeus ALIVE).  The scanner read it unguarded and raised
     `TypeError: 'NoneType' object is not iterable` on the first such frame,
     so `zusult` -- an id armed in every wave since W14 -- had no condition-(a)
     reading available from any current-dumper corpus.  The fix is NOT a silent
     `or []`: with the list missing, `ready` would evaluate False and the frame
     would be filed as a real negative, and that error flatters the armed leg
     (a violation on such a frame silently leaves the domain).  Missing frames
     are carried as their own state and reported as UNKNOWN.

  2. **AN `ABILITY` EVENT IS NOT A CAST.**  Nimbus (`zuus_cloud`) strikes are
     logged as `inflictor=zuus_lightning_bolt` with Zeus as the actor, and they
     spend no mana and touch no cooldown.  Six of the twelve raw in-domain
     flags on W44 -- 50% -- were those, one of them a "bolt" whose only damaged
     hero stood **8300 units** away, an order of magnitude outside the bolt's
     own cast range.  The discriminator is the ability's own cooldown across
     the instant: `pre_cd > 0` means the spell was ALREADY running and this
     event cannot be a fresh cast of it; `0 -> cd_len` means it is.

Neither of these is a wrong crash, which is why they survived: (1) looked like
a dumper problem and (2) looked like a clean number.

Run: python3 tests/test_zusult_gate_liveness.py
"""
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', 'tools', 'batch_test', 'behavioral'))
import zusult_gate as Z  # noqa: E402

ZEUS = 'npc_dota_hero_zuus'
FOE = 'npc_dota_hero_lion'
BOLT = 'zuus_lightning_bolt'

checks = 0
failures = []


def check(cond, what):
    global checks
    checks += 1
    if not cond:
        failures.append(what)


def abils(rlvl=1, rcd=0, wcd=0):
    return [{'name': 'zuus_arc_lightning', 'level': 1, 'cd': 0, 'cd_len': 1.6},
            {'name': BOLT, 'level': 1, 'cd': wcd, 'cd_len': 6},
            {'name': 'zuus_heavenly_jump', 'level': 0, 'cd': 0, 'cd_len': 0},
            {'name': 'zuus_thundergods_wrath', 'level': rlvl, 'cd': rcd,
             'cd_len': 130}]


def snap(t, hero, team, hp_pct, mp, x=0.0, abilities=None, missing=False):
    s = {'t': t, 'hero': hero, 'idx': 1, 'team': team, 'player_id': 1,
         'x': x, 'y': 0.0, 'hp': int(1000 * hp_pct), 'hp_pct': hp_pct,
         'mp': mp, 'max_mp': 900, 'mp_pct': mp / 900.0, 'level': 10,
         'items': [], 'tp_cd': 0, 'tp_cdlen': 0, 'net_worth': 5000}
    s['abilities'] = None if missing else (abilities or abils())
    return s


def build(cast_t, wcd_pre, wcd_post, foe_hp=1.0, mp=100, zeus_missing_at=(),
          mp_post=None):
    """One 6-second timeline holding exactly one Zeus bolt event."""
    snaps, evs = [], []
    # 1 Hz, straddling the cast the way the dumper's real frames do.
    for t in (cast_t - 1.5, cast_t - 0.5, cast_t + 0.5, cast_t + 1.5):
        pre = t <= cast_t
        snaps.append(snap(t, ZEUS, 2, 1.0,
                          mp if pre else (mp if mp_post is None else mp_post),
                          abilities=abils(wcd=wcd_pre if pre else wcd_post),
                          missing=(t in zeus_missing_at)))
        snaps.append(snap(t, FOE, 3, foe_hp, 500, x=600.0))
    evs.append({'t': cast_t, 'type': 'ABILITY', 'actor': ZEUS,
                'target': 'dota_unknown', 'inflictor': BOLT, 'value': 0,
                'actor_hero': True, 'target_hero': False})
    evs.append({'t': cast_t, 'type': 'DAMAGE', 'actor': ZEUS, 'target': FOE,
                'inflictor': BOLT, 'value': 260, 'actor_hero': True,
                'target_hero': True})
    evs.append({'t': cast_t + 2.0, 'type': 'DAMAGE', 'actor': ZEUS,
                'target': FOE, 'inflictor': 'dota_unknown', 'value': 1,
                'actor_hero': True, 'target_hero': True})
    return {'game': {'teams': {ZEUS: 2, FOE: 3}}, 'snapshots': snaps,
            'events': evs, 'buildings': [], 'creeps': [], 'wards': []}


def run(doc):
    fd, path = tempfile.mkstemp(suffix='.json')
    with os.fdopen(fd, 'w') as fh:
        json.dump(doc, fh)
    try:
        return Z.analyze(path)
    finally:
        os.unlink(path)


# --- 1. the frame that used to raise ---------------------------------------
# Zeus's gate frame carries no ability list.  Before the guard this raised
# TypeError and the whole run produced nothing.
r = run(build(100.0, 0, 6, zeus_missing_at=(99.5,)))
check(len(r['dom']) == 0, '1a: a missing-ability gate frame must not be in-domain')
check(len(r['unknown']) == 1, '1b: it must be reported as UNKNOWN, not as a negative')
check(r['noab_frames'] == 1, '1c: missing frames are counted')

# The same run without the missing list is the positive control: identical
# input except for the one field, and now the cast IS in the domain.  Without
# this half, "0 in-domain" above could not be told from "the scan found nothing".
r = run(build(100.0, 0, 6))
check(len(r['dom']) == 1, '1d: control -- a real in-domain cast is still flagged')
check(len(r['unknown']) == 0, '1e: control -- nothing unknown')

# --- 2. an ABILITY event is not a cast -------------------------------------
# Lightning Bolt already on cooldown 0.9s before the event: Nimbus struck, Zeus
# did not cast.  Mana is flat across the instant, as it was on the real frame
# (20260904_004641_slot4 t=422.3, and 20260904_004903_slot2 t=453.4 where the
# damaged hero was 8300 units away).
r = run(build(100.0, 0.9, 0))
check(len(r['dom']) == 0, '2a: a spell already on cooldown cannot be a fresh cast')
check(len(r['notcast']) == 1, '2b: it is dropped explicitly, not silently')

# Still on cooldown on BOTH sides of the event -- Nimbus striking in the middle
# of the bolt's own cooldown.  This is the case that separates the `pre_cd > 0`
# rule from the two witnesses below it: drop the rule and `post_cd > 0` reads
# this as a fresh cast.  The first version of this file used pre=0.9/post=0
# instead, and that mutation SURVIVED, because the flat mana already answered
# no.  A mutant surviving is a claim about the assertion, not about the guard.
r = run(build(100.0, 3.0, 2.0))
check(len(r['dom']) == 0, '2f: a cooldown running on both sides is not a fresh cast')
check(len(r['notcast']) == 1, '2g: and it is dropped explicitly')

# Cooldown 0 -> 0 with no mana spent: also not a cast.
r = run(build(100.0, 0, 0))
check(len(r['dom']) == 0, '2c: cd 0->0 with flat mana is not a cast')
check(len(r['notcast']) == 1, '2d: and it is dropped explicitly')

# Cooldown 0 -> 0 but mana fell by more than a bolt: the cooldown elapsed
# inside the 1 Hz gap.  This is the fallback witness, and it must still count.
r = run(build(100.0, 0, 0, mp=200, mp_post=60))
check(len(r['dom']) == 1, '2e: a mana drop is accepted when the cooldown elapsed unseen')

# --- 3. the domain predicate itself still bites ----------------------------
# A target below the 0.60 health floor is a kill window: the gate stands aside
# by design, so this is not a violation even though the cast is real.
r = run(build(100.0, 0, 6, foe_hp=0.40))
check(len(r['dom']) == 0, '3a: a target under the health floor is out of domain')

# Ult affordable -> nothing is being denied -> out of domain.
r = run(build(100.0, 0, 6, mp=400))
check(len(r['dom']) == 0, '3b: an affordable ult puts the cast out of domain')

# Ult untrained -> the gate returns false on its own second line.
doc = build(100.0, 0, 6)
for s in doc['snapshots']:
    if s['hero'] == ZEUS:
        for a in s['abilities']:
            if a['name'] == 'zuus_thundergods_wrath':
                a['level'] = 0
r = run(doc)
check(len(r['dom']) == 0, '3c: an untrained ult puts the cast out of domain')

# --- 4. a mana refill inside the sample gap (replay-check W46, 2026-09-04) --
# The gate's first clause reads the mana Zeus holds AT THE DECISION.  The only
# mana this scanner can see is the last snapshot at or before the cast, up to
# 1 s earlier.  An Arcane Boots / wand / mango inside that gap moves clause 7's
# input between the sample and the decision, and the error only ever runs one
# way: it manufactures leaks, it cannot hide one.
#
# Real frame this pins: run …_84e984 game 20260904_124709_slot5, armed leg.
# Snapshot t=394.5 mp=162 (< R cost 225 at R level 1) -> the scanner called the
# t=395.1 bolt in-domain.  `item_arcane_boots` fired at t=394.5 for +175, so the
# bot decided holding ~337 >= 225 and clause 7 correctly returned false.  The
# arithmetic that forces it: a level-4 bolt costs ~131 (measured on clean casts
# in that same game: -131, -128, -127), and the post-cast snapshot reads
# mp=181 -- unreachable from 162 without the refill, which would leave ~31.
doc = build(100.0, 0, 6, mp=100)
doc['events'].append({'t': 99.8, 'type': 'ITEM', 'actor': ZEUS,
                      'target': 'dota_unknown', 'inflictor': 'item_arcane_boots',
                      'value': 0, 'actor_hero': True, 'target_hero': False})
r = run(doc)
check(len(r['dom']) == 0, '4a: a cast whose mana reading is stale is not in-domain')
check(len(r['stale']) == 1, '4b: it is reported as STALE-MANA, not silently dropped')
check(len(r['notcast']) == 0,
      '4c: stale is split off BEFORE not-a-cast -- it never was in the domain')

# Positive control: same timeline, same item, but the use lands BEFORE the
# snapshot the row was read from, so the sampled mana already includes it and
# the reading is sound.  Without this half, 4a could not be told from "any
# ITEM event anywhere disarms the flag".
doc = build(100.0, 0, 6, mp=100)
doc['events'].append({'t': 98.9, 'type': 'ITEM', 'actor': ZEUS,
                      'target': 'dota_unknown', 'inflictor': 'item_arcane_boots',
                      'value': 0, 'actor_hero': True, 'target_hero': False})
r = run(doc)
check(len(r['dom']) == 1, '4d: control -- a refill before the sample leaves the row in-domain')
check(len(r['stale']) == 0, '4e: control -- nothing stale')

# An item that restores no mana must not disarm the flag: the guard is keyed to
# the mechanism (mana income), not to "an item was used".
doc = build(100.0, 0, 6, mp=100)
doc['events'].append({'t': 99.8, 'type': 'ITEM', 'actor': ZEUS,
                      'target': 'dota_unknown', 'inflictor': 'item_blink',
                      'value': 0, 'actor_hero': True, 'target_hero': False})
r = run(doc)
check(len(r['dom']) == 1, '4f: a non-mana item in the gap does not excuse the cast')
check(len(r['stale']) == 0, '4g: and is not reported as stale')

# The refill must be ZEUS's own: an ally drinking a mango in the gap changes
# nothing about the mana Zeus held.
doc = build(100.0, 0, 6, mp=100)
doc['events'].append({'t': 99.8, 'type': 'ITEM', 'actor': FOE,
                      'target': 'dota_unknown', 'inflictor': 'item_enchanted_mango',
                      'value': 0, 'actor_hero': True, 'target_hero': False})
r = run(doc)
check(len(r['dom']) == 1, "4h: another hero's mana item does not excuse the cast")

print(f'zusult_gate liveness: {checks} checks, {len(failures)} failures')
for f in failures:
    print('  FAIL', f)
sys.exit(1 if failures else 0)

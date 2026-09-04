#!/usr/bin/env python3
"""Pins for `rotscope_domain.py` -- the ways this reading can be a plausible
WRONG NUMBER rather than a wrong crash.

Not a re-run of the tool's `--selfcheck` (that pins the interval algebra and
the bucket arithmetic on synthetic frames).  This file pins the four
properties the 2026-09-04 replay-check reading actually leans on, each of
which was found frame by frame on W44's pudge corpus:

  1. **THE LEG IS PUDGE'S TEAM, NOT THE GAME'S ARMED SIDE.**  `sweep_run.sh`
     stamps `side` = which physical team carries the armed candidate string.
     Pudge is drafted onto exactly one of the two teams, so his leg is
     `team == TEAM_OF_SIDE[side]` and NOT `side` itself.  Getting this
     backwards silently swaps every armed and baseline row -- and because the
     table is symmetric in shape, nothing downstream would look wrong.

  2. **"Rot OFF" IS NOT ALWAYS A DECISION** (the tool's LIMIT 6).  A silenced
     Pudge cannot toggle Rot.  On this corpus the disable share of the OFF
     bucket by TIME is ~1%, while the disable share of the solo hero-attack
     EPISODES -- the numerator -- is 50%.  A numerator 50% contaminated under
     a denominator 1% contaminated is exactly the shape that reads as a clean
     rate.  Pinned so the two shares can never be conflated again.

  3. **A DISABLE ON ANOTHER HERO IS NOT PUDGE'S**, and two overlapping
     silences must not close each other's window on the first REMOVE.  The
     real frame is Ancient Seal, which Skywrath also puts on other heroes in
     the same seconds.

  4. **`hp_pct <= 0` IS NOT DEATH** (GH #470).  The dumper's `round3` reads a
     1-HP hero as `0.0`.  If aliveness regressed to `hp_pct > 0`, live frames
     would leave the OFF denominator and the rate would rise for free.

Run: python3 tests/test_rotscope_domain.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', 'tools', 'batch_test', 'behavioral'))
import rotscope_domain as R  # noqa: E402

checks = 0
failures = []


def check(cond, name):
    global checks
    checks += 1
    if not cond:
        failures.append(name)


def snap(t, hp=100, hp_pct=1.0, idx=1, team=2, hero=R.PUDGE, x=0.0, y=0.0):
    return {'t': float(t), 'hero': hero, 'idx': idx, 'team': team, 'x': x,
            'y': y, 'hp': hp, 'hp_pct': hp_pct, 'level': 1}


def mod(t, kind, inflictor, target=R.PUDGE, actor=R.PUDGE):
    return {'t': float(t), 'type': kind, 'actor': actor, 'target': target,
            'inflictor': inflictor, 'value': 1, 'actor_hero': True,
            'target_hero': True}


def atk(t, target='npc_dota_hero_skywrath_mage', target_hero=True):
    return {'t': float(t), 'type': 'DAMAGE', 'actor': R.PUDGE,
            'target': target, 'inflictor': R.AUTO_ATTACK_INFLICTOR,
            'value': 120, 'actor_hero': True, 'target_hero': target_hero}


SNAPS = [snap(t) for t in range(0, 41)]
ROT = [mod(10, 'MODIFIER_ADD', R.ROT_MOD), mod(14, 'MODIFIER_REMOVE', R.ROT_MOD)]

# ---------------------------------------------------------------- pin 1: leg
# Pudge on team 2 (radiant).  The game whose ARMED side is radiant puts him on
# the armed leg; the game whose armed side is dire puts him on the baseline
# leg -- with byte-identical frames.
tl = {'snapshots': SNAPS, 'events': ROT + [atk(11), atk(20)]}
r_arm = R.read_game(tl, 'radiant')
r_base = R.read_game(tl, 'dire')
check(r_arm['leg'] == 'armed' and r_base['leg'] == 'baseline',
      "leg follows Pudge's team against the stamped armed side")
check(r_arm['phys_side'] == 'radiant' and r_base['phys_side'] == 'radiant',
      "the PHYSICAL stratum is Pudge's team and does not move with the leg")
check(R.TEAM_OF_SIDE == {'radiant': 2, 'dire': 3},
      'the side->team map matches sweep_run.sh (radiant 2, dire 3)')
# Pudge on team 3 flips both legs, same stamps.
tl_d = {'snapshots': [snap(t, team=3) for t in range(0, 41)],
        'events': ROT + [atk(11), atk(20)]}
check(R.read_game(tl_d, 'radiant')['leg'] == 'baseline'
      and R.read_game(tl_d, 'dire')['leg'] == 'armed',
      'a dire Pudge inverts the leg under the same two stamps')

# --------------------------------------------------- pin 2: LIMIT 6 contamination
# The real shape: a 6 s Ancient Seal sitting entirely inside a long OFF
# stretch, with the hero attacks concentrated inside the seal.
SEAL = 'modifier_skywrath_mage_ancient_seal'
ev = ROT + [mod(20, 'MODIFIER_ADD', SEAL, actor='npc_dota_hero_skywrath_mage'),
            mod(26, 'MODIFIER_REMOVE', SEAL, actor='npc_dota_hero_skywrath_mage')]
ev += [atk(t) for t in (21, 22, 23, 24, 25)]   # numerator: all inside the seal
row = R.read_game({'snapshots': SNAPS, 'events': ev}, 'radiant')
check(row['off_s'] == 36.0, 'OFF seconds are alive minus Rot-on (40 - 4)')
check(row['off_disabled_s'] == 6.0, 'the seal lands entirely in the OFF bucket')
share_time = row['off_disabled_s'] / row['off_s']
check(share_time < 0.20,
      'by TIME the disable share of the OFF bucket is small (~17% here, ~1% on corpus)')
dis = R.disable_windows(ev, SNAPS)
inside = sum(1 for e in ev
             if e.get('inflictor') == R.AUTO_ATTACK_INFLICTOR
             and R.in_windows(e['t'], dis))
total = sum(1 for e in ev if e.get('inflictor') == R.AUTO_ATTACK_INFLICTOR)
check((inside, total) == (5, 5),
      'by EPISODE the same seal covers the whole numerator -- the two shares '
      'are different quantities and must never be quoted for each other')
check(row['atk_hero_off'] == 5 and row['atk_hero_on'] == 0,
      'those five attacks are counted in the OFF bucket, undeducted')

# ------------------------------------------------- pin 3: whose disable, and overlap
HEX = 'modifier_sheepstick_debuff'
check(R.disable_windows(
    [mod(3, 'MODIFIER_ADD', SEAL, target='npc_dota_hero_lion'),
     mod(9, 'MODIFIER_REMOVE', SEAL, target='npc_dota_hero_lion')], SNAPS) == [],
    "a silence on another hero is not Pudge's")
check(R.disable_windows(
    [mod(3, 'MODIFIER_ADD', SEAL), mod(4, 'MODIFIER_ADD', HEX),
     mod(5, 'MODIFIER_REMOVE', HEX), mod(9, 'MODIFIER_REMOVE', SEAL)],
    SNAPS) == [(3.0, 9.0), (4.0, 5.0)],
    'two overlapping silences keep their own windows')
check(R.disable_windows(
    [mod(3, 'MODIFIER_ADD', 'modifier_item_pipe_aura'),
     mod(9, 'MODIFIER_REMOVE', 'modifier_item_pipe_aura')], SNAPS) == [],
    'a buff aura is not a disable')
check(all(k == k.lower() for k in R.DISABLE_KEYS),
      'the disable keys are matched against a lower-cased modifier name')

# Rot's own modifier lands on VICTIMS too; only Pudge's own opens a window.
check(R.rot_windows(
    [mod(5, 'MODIFIER_ADD', R.ROT_MOD, target='npc_dota_hero_lion'),
     mod(8, 'MODIFIER_REMOVE', R.ROT_MOD, target='npc_dota_hero_lion')],
    SNAPS)[0] == [],
    "the Rot aura on a victim does not mean Pudge toggled Rot")

# -------------------------------------------------------- pin 4: GH #470 liveness
check(R.is_live({'hp': 1, 'hp_pct': 0.0}) is True,
      'a 1-HP hero rounded to hp_pct 0.0 is LIVE (GH #470)')
check(R.is_live({'hp': 0, 'hp_pct': 0.0}) is False, 'a real corpse is dead')
# ... and that liveness is what the OFF denominator is built on: a 1-HP stretch
# must stay in the denominator.
onehp = ([snap(t) for t in range(0, 20)]
         + [snap(t, hp=1, hp_pct=0.0) for t in range(20, 31)]
         + [snap(t) for t in range(31, 41)])
check(R.alive_windows(onehp, 1) == [(0.0, 40.0)],
      'a 1-HP stretch does not split the alive window')
check(R.read_game({'snapshots': onehp, 'events': ROT},
                  'radiant')['off_s'] == 36.0,
      'and it stays in the OFF denominator')

# ------------------------------------------------- an auto-attack is an auto-attack
check(len(R.pudge_autoattacks(
    [{'t': 1.0, 'type': 'DAMAGE', 'actor': R.PUDGE,
      'target': 'npc_dota_hero_lion', 'inflictor': 'pudge_rot', 'value': 5,
      'actor_hero': True, 'target_hero': True}], False)) == 0,
    'Rot aura damage is not a right-click')
check(len(R.pudge_autoattacks([atk(1, 'npc_dota_creep', False)], True)) == 0,
      'the hero-only cut drops creep right-clicks')
check(len(R.pudge_autoattacks([atk(1, 'npc_dota_creep', False)], False)) == 1,
      'and the all cut keeps them')

print('%d checks, %d failures' % (checks, len(failures)))
for f in failures:
    print('  FAIL %s' % f)
sys.exit(1 if failures else 0)

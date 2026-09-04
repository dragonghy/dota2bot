#!/usr/bin/env python3
"""Pins for `campbind_poke.py` -- the three ways it was NOT measuring what its
output line claimed.  All three were found by reading FRAMES, not by reading the
table, and all three were found on the W46 corpus 2026-09-04 (b77771/d7082b).

  1. **A POKE IS A RIGHT CLICK.**  The first cut counted any hero DAMAGE row
     onto an `npc_dota_neutral_*` target.  `20260904_124739_slot1` ogre_magi
     t=271.0-279.5 is then twenty-eight "pokes": one `ogre_magi_ignite` DoT,
     ticking on THREE families across BOTH camps in reach while the hero walks
     between them.  `20260904_124617_slot2` spirit_breaker t=194.5 is another,
     a `spirit_breaker_greater_bash` proc.  The lever under test picks the
     argument of `Action_AttackUnit`; ability damage is not that call, so it is
     not evidence about that call.  Discriminator: inflictor `dota_unknown`.

  2. **TWO CAMPS CAN CLAIM THE SAME CREEPS.**  Camp boxes sit as close as
     1121 u (`20260904_124617_slot2`: (-4193,4792) and (-4845,3880)) while the
     cluster-link radius is 900, so a per-camp `dist <= CAMP_LINK` membership
     test put the same six creeps in both camps and printed both as
     `d_bot=163 n=6`.  Two camps that share their creeps move together, so the
     instant files as `unattributed`: the defect SUPPRESSES findings silently
     rather than fabricating them, which is why the table looked fine.
     Assignment must be EXCLUSIVE -- nearest tracked centroid wins.

  3. **THE WINDOW IS PART OF THE DOMAIN.**  The camp-pull branch cannot run
     after `pullcamp_domain.T_HI`.  Counting every neutral poke charged
     late-game jungling to the gate and produced a 5-vs-2 armed/baseline
     "signal" out of pure background -- visible as such only because shipped
     code CANNOT poke a non-nearest camp, so the baseline column is a
     measurable false-positive rate.  Same shape as the `zusult` lesson
     (量具把「门管不着的施法」记在门头上).

Run: python3 tests/test_campbind_poke_liveness.py
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', 'tools', 'batch_test', 'behavioral'))
import campbind_poke as CB  # noqa: E402

checks = 0
failures = []


def check(cond, what):
    global checks
    checks += 1
    if not cond:
        failures.append(what)
    print('  %-4s %s' % ('ok' if cond else 'FAIL', what))


class FakeGame:
    """Minimal stand-in carrying only what the functions under test read."""

    def __init__(self, creeps_by_t, events=(), teams=None):
        self.neutrals = creeps_by_t
        self.creep_t = sorted(creeps_by_t)
        self.raw_events = list(events)
        self.teams = teams or {}


def neut(x, y):
    return {'t': 0.0, 'team': 4, 'x': x, 'y': y}


# --- 1. a poke is a right click ---------------------------------------
print('=== 1. poke_instants: ability damage is not a poke ===')
HERO = 'npc_dota_hero_ogre_magi'


def dmg(t, target, inflictor):
    return {'t': t, 'type': 'DAMAGE', 'actor': HERO, 'target': target,
            'inflictor': inflictor, 'value': 40,
            'actor_hero': True, 'target_hero': False}


g = FakeGame({}, [dmg(271.0, 'npc_dota_neutral_ghost', 'ogre_magi_ignite'),
                  dmg(271.7, 'npc_dota_neutral_fel_beast', 'ogre_magi_ignite'),
                  dmg(272.5, 'npc_dota_neutral_wildkin', 'ogre_magi_ignite')],
             {HERO: 2})
inst = CB.poke_instants(g, HERO)
check(len(inst) == 1, 'a DoT chain within POKE_GAP is ONE instant, not three'
      ' (got %d)' % len(inst))
check(inst and inst[0]['physical'] is False,
      'an ignite-only instant is NOT physical -- the real frame this pins is '
      '20260904_124739_slot1 t=271.0')

g = FakeGame({}, [dmg(194.5, 'npc_dota_neutral_harpy_scout',
                      'spirit_breaker_greater_bash')], {HERO: 2})
check(CB.poke_instants(g, HERO)[0]['physical'] is False,
      'a greater_bash proc alone is NOT physical (20260904_124617_slot2 t=194.5)')

g = FakeGame({}, [dmg(165.0, 'npc_dota_neutral_harpy_storm', 'dota_unknown')],
             {HERO: 2})
check(CB.poke_instants(g, HERO)[0]['physical'] is True,
      'a right click IS physical (20260904_124610_slot3 lich t=165.0)')

# a real attack that also procs must still read physical
g = FakeGame({}, [dmg(300.0, 'npc_dota_neutral_kobold', 'dota_unknown'),
                  dmg(300.1, 'npc_dota_neutral_kobold',
                      'spirit_breaker_greater_bash')], {HERO: 2})
check(CB.poke_instants(g, HERO)[0]['physical'] is True,
      'attack + proc in one instant still reads physical (no under-claim)')

# lane creeps and hero targets are outside this census entirely
g = FakeGame({}, [dmg(100.0, 'npc_dota_creep_badguys_ranged', 'dota_unknown')],
             {HERO: 2})
check(CB.poke_instants(g, HERO) == [],
      'a lane-creep hit is not a neutral poke (dmg_creep lumps these in)')

# --- 2. camp membership is exclusive ----------------------------------
print('\n=== 2. moved(): two camps 1121 u apart do not share creeps ===')
# The real geometry of 20260904_124617_slot2: centroids 1121 u apart, i.e.
# closer than 2*CAMP_LINK, so a per-camp radius test double-counts.
A = (-4193.0, 4792.0)
B = (-4845.0, 3880.0)
check(CB.PD.dist(*A, *B) < 2 * CB.CAMP_LINK,
      'the pinned camp pair really is closer than 2*CAMP_LINK (%.0f u < %.0f)'
      % (CB.PD.dist(*A, *B), 2 * CB.CAMP_LINK))

camps = [{'cx': A[0], 'cy': A[1], 'n': 3, 'near': 163.0},
         {'cx': B[0], 'cy': B[1], 'n': 1, 'near': 695.0}]
# Camp A is dragged 600 u TOWARD B; camp B never moves.  The direction is the
# whole assertion and it was wrong the first time: dragging A away from B left
# A's creeps 1121+ u from B, outside CAMP_LINK, so the shared-membership
# mutant (mutstand M3) changed nothing and SURVIVED green.  Dragged toward B
# they end 521 u away -- inside the 900 u radius a per-camp test would use --
# so B inherits them and its centroid reads as moved.  A three-to-one creep
# count makes the blended centroid clear the threshold rather than sit on it.
ux, uy = (B[0] - A[0]) / 1121.0, (B[1] - A[1]) / 1121.0
t0 = 100.0


def a_creeps(k):
    ax, ay = A[0] + 100 * k * ux, A[1] + 100 * k * uy
    return [neut(ax, ay), neut(ax + 40, ay), neut(ax, ay + 40)]


frames = {t0: a_creeps(0) + [neut(*B)]}
for k in range(1, 7):
    frames[t0 + k] = a_creeps(k) + [neut(*B)]
g = FakeGame(frames)
d = CB.moved(g, camps, t0)
check(d[0] >= CB.AGGRO_MIN,
      'the dragged camp reads as moved (%.0f u >= %.0f)' % (d[0], CB.AGGRO_MIN))
check(d[1] < CB.AGGRO_MIN,
      'the UNTOUCHED neighbour does not inherit the drag (%.0f u < %.0f) -- '
      'this is the shared-membership defect' % (d[1], CB.AGGRO_MIN))

print('\n=== 3. clusters_near: reach and ordering ===')
creeps = [neut(*A), neut(A[0] + 40, A[1]), neut(*B), neut(B[0] + 40, B[1])]
near = CB.clusters_near(creeps, A[0] + 100, A[1], CB.POKE_R)
check(len(near) == 2, 'both camps are in reach from between them (got %d)'
      % len(near))
check(near[0]['near'] < near[1]['near'],
      'clusters come back sorted by nearest member -- index 0 IS "nearest", '
      'which is what the non_nearest/nearest verdict is read off')
far = CB.clusters_near(creeps, A[0] + 5000, A[1], CB.POKE_R)
check(far == [], 'a camp outside POKE_R is not in reach')

# --- 4. the constants are the Lua's, not this file's -------------------
print('\n=== 4. constants transcribed from the call site ===')
lua = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..',
                        'bots', 'FunLib', 'jmz_func.lua')).read()
check('local PULL_CAMP_NEUTRAL_RANGE = 1200' in lua,
      'jmz_func.lua still declares PULL_CAMP_NEUTRAL_RANGE = 1200')
check(CB.LEASH == 1200.0, 'campbind_poke.LEASH mirrors it')
roam = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..',
                         'bots', 'mode_roam_generic.lua')).read()
check('GetNearbyNeutralCreeps(1400)' in roam,
      'the call site still reads GetNearbyNeutralCreeps(1400)')
check(CB.POKE_R == 1400.0, 'campbind_poke.POKE_R mirrors it')
check('J.GetCampPullPokeTarget(tNeut, bot.roamCampPull)' in roam,
      'the poke still goes through the gated helper (the fix is not reverted)')

print('\n%d checks, %d failed' % (checks, len(failures)))
for f in failures:
    print('  FAIL: %s' % f)
sys.exit(1 if failures else 0)

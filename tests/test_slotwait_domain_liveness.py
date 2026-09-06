#!/usr/bin/env python3
"""Pins for `slotwait_domain.py` -- GH #467's (a)-verification instrument.

Three things this file exists to hold down, all of which would let the domain
count go wrong QUIETLY (the counter still prints a number, and the number still
looks like a reading):

  1. **THE TABLES ARE TRANSCRIPTIONS, NOT OPINIONS.**  `ImportantSpells` and
     `ImportantItems` live in `bots/FunLib/utils.lua`; the shipped predicate
     reads `ImportantSpells[hero][1]` -- the FIRST entry only.  If someone adds
     a hero to the Lua table and not here, the domain silently shrinks; if the
     python side ever starts reading the SECOND entry, the domain silently
     grows.  Both are checked against the Lua source, not against memory.
     (Undying, Spectre and Terrorblade are the three rows with a second entry,
     so they are the ones a "helpful" widening would hit first.)

  2. **ILLUSIONS SHARE THE PLAYER ID.**  Real-frame origin, 2026-09-05, W47
     `20260904_190005_slot1` t=739.4: dire pid 6 (chaos_knight) is ELEVEN
     snapshot rows -- one body plus ten `chaos_knight_phantasm` illusions, all
     with the same hero name and the same `player_id`.  Keyed by player_id
     alone, whichever row sorts last wins; the predicate reads a COOLDOWN, and
     an illusion's ability list is not the hero's, so the answer can flip in
     EITHER direction.  Same family as the entities.py lina case, one level
     down (there the collision was on the name, here it survives player_id
     too).

  3. **THE SIDE ASYMMETRY IS THE WHOLE POINT AND IT IS EASY TO INVERT.**
     Radiant loses ONE scan slot, dire loses FOUR.  A transposed
     `shipped_scanned_pids` still produces a plausible-looking table with the
     ratio upside down -- and W47 seed 4950 shows the reading can legitimately
     be 0 on dire (no ImportantSpells hero on that roster at all), so "dire is
     zero" cannot be used as the smoke test.  The mapping is pinned directly.

Run: python3 tests/test_slotwait_domain_liveness.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools', 'batch_test', 'behavioral'))
import slotwait_domain as SW  # noqa: E402

checks = 0
failures = []


def check(cond, what):
    global checks
    checks += 1
    if not cond:
        failures.append(what)
    print('  %-4s %s' % ('ok' if cond else 'FAIL', what))


def lua(path):
    return open(os.path.join(HERE, '..', path)).read()


UTILS = lua('bots/FunLib/utils.lua')
JMZ = lua('bots/FunLib/jmz_func.lua')
HEROES = lua('bots/ts_libs/dota/heroes.lua')

# --- 1. the lever is still where the reading assumes it is ------------------
# PROMOTED 2026-09-06 (director, stable-v3): the gate is gone and the flag is
# `J.IsModeTurbo()`. Before that date these two checks asserted the gate's
# PRESENCE. The instrument this file pins reads the armed/shipped scan
# difference, which is unchanged by the promote -- what changes is who supplies
# the flag -- so the pin moves with it instead of being deleted.
print('=== 1. the lever under test still exists, now a turbo default ===')
WRAPPER = JMZ.split('function J.ShouldWaitForTeamCooldowns')[1].split('\nend')[0]
check("IsSoakCandidate" not in WRAPPER,
      "the promoted wrapper carries no soak gate at all (a re-grown gate would "
      "be inert in every real game while every armed-wiring check reads clean)")
check(WRAPPER.count('J.IsModeTurbo()') == 1,
      'the turbo flag is read exactly ONCE (one wrapper, two legs -- the two '
      'predicates can never end up in different index domains)')
check('IsSoakCandidate' not in UTILS,
      'utils.lua never RESOLVES a gate itself -- it may not import jmz_func, '
      "so the id reaches it only as the bSlotWait parameter (naming the id in "
      'a doc comment is fine and is not what this pins)')
for fn in ('HasTeamMemberWithCriticalSpellInCooldown',
           'HasTeamMemberWithCriticalItemInCooldown'):
    body = UTILS.split('function ____exports.%s' % fn)[1].split('\nfunction ')[0]
    check('if bSlotWait then' in body and 'nSlot = i' in body,
          '%s still swaps the pid for the loop index when armed' % fn)
    check('teamMember:IsAlive()' in body,
          '%s still guards on the MEMBER it just fetched -- no guard/subject '
          'split, so the shipped TRUE set is a strict subset (this is what '
          'makes the one-direction count legitimate)' % fn)

# --- 2. tables transcribed from the Lua, first entry only ------------------
print('\n=== 2. ImportantSpells / ImportantItems are transcriptions ===')
items = re.search(r'____exports\.ImportantItems = \{([^}]*)\}', UTILS).group(1)
lua_items = tuple(re.findall(r'"item_([a-z_]+)"', items))
check(lua_items == SW.IMPORTANT_ITEMS,
      'ImportantItems matches the Lua exactly (%s)' % (lua_items,))

spells = UTILS.split('____exports.ImportantSpells = {')[1].split('\n}')[0]
rows = re.findall(r'\[HeroName\.(\w+)\] = \{([^}]*)\}', spells)
check(len(rows) == len(SW.IMPORTANT_SPELL),
      'the python table has one row per Lua row (%d)' % len(rows))
enum = dict(re.findall(r'____exports\.HeroName\.(\w+) = "([a-z_]+)"', HEROES))
missing, wrong, tail_leak = [], [], []
for key, body in rows:
    npc = enum.get(key)
    first = re.findall(r'"([a-z_0-9]+)"', body)
    if npc not in SW.IMPORTANT_SPELL:
        missing.append(key)
    elif SW.IMPORTANT_SPELL[npc] != first[0]:
        wrong.append(key)
    for extra in first[1:]:
        if extra in SW.IMPORTANT_SPELL.values():
            tail_leak.append(extra)
check(not missing, 'every Lua hero is transcribed (missing: %s)' % missing)
check(not wrong, 'each row transcribes the FIRST spell (wrong: %s)' % wrong)
check(not tail_leak,
      'no SECOND entry leaked into the table -- the shipped code reads [1] '
      'only, so counting undying_flesh_golem / spectre_haunt / '
      'terrorblade_sunder would measure a predicate the bot does not have '
      '(leaked: %s)' % tail_leak)
check('ImportantSpells[heroName][1]' in UTILS,
      'HasCriticalSpellWithCooldown still reads index [1] -- if this ever '
      'becomes a loop, LIMIT 6 and this pin both have to change')

# --- 3. the slot arithmetic, pinned in both directions ---------------------
print('\n=== 3. the pid->slot shrinkage, both sides ===')
check(SW.shipped_scanned_pids(SW.RADIANT) == {0, 1, 2, 3},
      'radiant shipped scan == pids 0..3 (GetTeamMember(0) is nil, slot 5 is '
      'never asked for)')
check(SW.shipped_scanned_pids(SW.DIRE) == {9},
      'dire shipped scan == pid 9 alone (only nSlot 5 is in 1..5)')
check(len(SW.all_pids(SW.RADIANT) - SW.shipped_scanned_pids(SW.RADIANT)) == 1
      and len(SW.all_pids(SW.DIRE) - SW.shipped_scanned_pids(SW.DIRE)) == 4,
      'the shrinkage is 1 slot on radiant and 4 on dire -- the arithmetic '
      'that predicts the side ratio')

# --- 4. phase gate transcribed from jmz_func -------------------------------
print('\n=== 4. the turbo phase gate is the Lua one ===')
check('DotaTime() > (J.IsModeTurbo() and 5 * 60 or 10 * 60)' in JMZ
      and 'DotaTime() > (J.IsModeTurbo() and 18 * 60 or 30 * 60)' in JMZ,
      'IsMidGame/IsLateGame still switch at turbo 5:00 / 18:00')
check(SW.TURBO_MID_START == 300.0 and SW.TURBO_LATE_START == 1080.0,
      'the python bounds mirror them')
check(not SW.phase_ok(1080.0),
      'both Lua tests are STRICT, so t == 1080.0 exactly is NEITHER mid nor '
      'late -- transcribed, not rounded away')
check('jmz.ShouldWaitForTeamCooldowns(vLocation)' in lua('bots/FunLib/aba_push.lua')
      and 'eAliveCount >= aAliveCount' in lua('bots/FunLib/aba_push.lua'),
      'the consumer still gates on the alive-count conjunct the d3 column '
      'narrows to')

# --- 5. the illusion collision, on the real shape ------------------------
print('\n=== 5. illusions share hero AND player_id ===')


def row(idx, t, pid, hero, cd):
    return {'idx': idx, 't': t, 'player_id': pid, 'team': SW.DIRE, 'hero': hero,
            'hp_pct': 1.0, 'items': [''] * 9,
            'abilities': [{'name': SW.IMPORTANT_SPELL[hero], 'level': 2, 'cd': cd}]}


CK = 'npc_dota_hero_chaos_knight'
LUNA = 'npc_dota_hero_luna'
real_then_illusions = {'snapshots': [
    row(11, -30.0, 6, CK, 55.0), row(11, 400.0, 6, CK, 55.0),
    row(22, 399.0, 6, CK, 0.0), row(22, 400.0, 6, CK, 0.0),
    row(23, 399.0, 6, CK, 0.0), row(23, 400.0, 6, CK, 0.0),
    row(33, -30.0, 9, LUNA, 0.0), row(33, 400.0, 9, LUNA, 0.0),
]}
check(SW.real_body_idx(real_then_illusions) == {11, 33},
      'post-horn streams are dropped even when hero AND player_id match')
g = SW.analyse_game(real_then_illusions, 0.0)
check(g['dire']['naive'] == 1,
      'the divergence survives two illusions whose ultimate reads READY -- '
      'keyed by player_id alone this reads 0 and the id looks SILENT')

# 5b. THE OTHER HALF: the filter must not invent a divergence either.  Same
# shape, but the real body is the one with the ready ultimate.
inverted = {'snapshots': [
    row(11, -30.0, 6, CK, 0.0), row(11, 400.0, 6, CK, 0.0),
    row(22, 399.0, 6, CK, 55.0), row(22, 400.0, 6, CK, 55.0),
    row(33, -30.0, 9, LUNA, 0.0), row(33, 400.0, 9, LUNA, 0.0),
]}
check(SW.analyse_game(inverted, 0.0)['dire']['naive'] == 0,
      'and an illusion carrying a LIVE cooldown does not manufacture one')

# --- 6. the two bounds are bounds -----------------------------------------
print('\n=== 6. strict <= naive, and both move the right way ===')
bkb = row(11, -30.0, 6, CK, 55.0)
scanned_holding = dict(row(33, -30.0, 9, LUNA, 0.0),
                       items=['black_king_bar'] + [''] * 8)
frame = {6: bkb, 9: scanned_holding}
r = SW.scan_team_second(frame, SW.DIRE, 0.0)
check(r['naive'] and not r['strict'],
      'strict drops what naive keeps when a SCANNED member holds a bkb -- the '
      'item leg is unobservable, so this is a bound, not a correction')
hi = SW.scan_team_second({6: bkb, 9: row(33, -30.0, 9, LUNA, 0.0)}, SW.DIRE, 0.0)
lo = SW.scan_team_second({6: bkb, 9: row(33, -30.0, 9, LUNA, 0.0)}, SW.DIRE, 90.0)
check(hi['naive'] and not lo['naive'],
      'raising nDuration can switch a MISSED member off and remove a '
      'divergence')

# 6b. THE OTHER DIRECTION, WHICH IS WHY "UPPER/LOWER BOUND" WOULD BE A LIE.
# Real shape, W47 20260904_184704_slot3 t=573.4 (seed 4763, armed radiant):
# luna is SCANNED (pid 0) with eclipse at cd 36.6, crystal_maiden is the one
# missed radiant slot (pid 4) with freezing_field at cd 66.0.  At bound 0 luna
# answers TRUE and there is NO divergence; at bound 40 luna drops out and the
# divergence APPEARS.  The two runs are two questions, not two bounds on one.
def rrow(idx, pid, hero, cd):
    return {'idx': idx, 't': -30.0, 'player_id': pid, 'team': SW.RADIANT,
            'hero': hero, 'hp_pct': 1.0, 'items': [''] * 9,
            'abilities': [{'name': SW.IMPORTANT_SPELL[hero], 'level': 1,
                           'cd': cd}]}


real = {0: rrow(1, 0, 'npc_dota_hero_luna', 36.6),
        4: rrow(2, 4, 'npc_dota_hero_crystal_maiden', 66.0)}
check(not SW.scan_team_second(real, SW.RADIANT, 0.0)['naive']
      and SW.scan_team_second(real, SW.RADIANT, 40.0)['naive'],
      'and raising it can switch a SCANNED member off and CREATE one -- the '
      'divergence count is NOT monotone in nDuration (luna 36.6 / cm 66.0)')

# --- 7. the IsTrained guard ------------------------------------------------
# ADDED BECAUSE A MUTANT SURVIVED.  `mutstand_slotwait.sh` M5 deletes the
# `level < 1` guard and every check above stayed green: nothing in this file
# was asking about it.  It is not decorative -- W47
# `20260904_183412_slot7` t=243.7 has skeleton_king carrying
# `skeleton_king_reincarnation` at level 0 with a NON-ZERO cd_len, and the
# shipped predicate refuses it through IsValidAbility -> IsTrained().  Without
# the guard every pre-level-6 hero in the table joins the domain.
print('\n=== 7. IsValidAbility is transcribed as level >= 1 ===')
check('not ability:IsTrained()' in UTILS,
      'IsValidAbility still refuses an untrained ability')
check('IsValidAbility(ability) and ability:GetCooldownTimeRemaining()' in UTILS,
      'HasCriticalSpellWithCooldown still runs the cooldown test only AFTER '
      'IsValidAbility')
untrained = {'hero': 'npc_dota_hero_skeleton_king',
             'abilities': [{'name': 'skeleton_king_reincarnation',
                            'level': 0, 'cd': 99.0}]}
check(not SW.spell_on_cd(untrained, 0.0),
      'a level-0 ultimate with a live cooldown is NOT in the domain (the real '
      'shape: W47 20260904_183412_slot7 t=243.7)')
check(SW.spell_on_cd(dict(untrained,
                          abilities=[{'name': 'skeleton_king_reincarnation',
                                      'level': 1, 'cd': 99.0}]), 0.0),
      'and the same row at level 1 IS -- so the guard is the level, not the '
      'hero')

print('\n%d checks, %d failed' % (checks, len(failures)))
for f in failures:
    print('  FAIL: %s' % f)
sys.exit(1 if failures else 0)

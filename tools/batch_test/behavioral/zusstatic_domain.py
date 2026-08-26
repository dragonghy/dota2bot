#!/usr/bin/env python3
"""`zusstatic` condition (a): is the armed leg a NO-OP, or does it change a decision?

WHY THIS TOOL EXISTS (replay-check 2026-08-26, GH #207 / GH #173)
-----------------------------------------------------------------
batch-desk's 09:20Z pre-launch check filed GH #207 calling the `zusstatic` leg
a STRUCTURAL ZERO, quoting `hero_zuus.lua`'s own doc line:

    `zusstatic` armed without `zusbind` armed measures the wrong ability's
    missing key, i.e. 0.

That sentence is about the VALUE the armed branch reads.  It is NOT the same
claim as "the leg changes nothing", and the difference is the whole of
condition (a).  Read the shipped function (`X.GetStaticFieldBonus`):

    if not hAbility:IsTrained() then return 0 end          -- BOTH legs 0
    if turbo and IsSoakCandidate('zusstatic') then
        ... return nPct/100  (a missing key answers 0)      -- ARMED   -> 0
    end
    return 0.09                                            -- BASELINE -> 0.09

So there are three worlds, not two, and they are told apart by ONE engine
fact -- what `sAbilityList[5]` resolves to:

  (W-nil)      handle is nil.  In the W12 tree (14004d85) there is NO nil
               guard, so `nil:IsTrained()` RAISES inside X.SkillsComplement,
               which is where every Zeus cast is dispatched from.  Prediction:
               Zeus casts NOTHING, on BOTH legs, in every game of the wave.
  (W-untrained) handle is a real but untrained ability.  Both legs return 0.
               TRUE structural zero -- GH #207's reading.
  (W-trained)  handle is a real TRAINED ability that has no `damage_health_pct`
               key.  ARMED reads 0, BASELINE reads 0.09.  The leg is LIVE and
               its effect is a strictly one-directional tightening of the two
               consumers, both of which are kill estimates:
                 X.ConsiderW  -- `zuus_lightning_bolt` sniping a ranged creep
                 X.ConsiderR  -- the `lowHPCount` loop that decides the ~130s
                                 global execute
               `+ target:GetHealth()*bonus` is >= 0 always, so ARMED can only
               ever fire LESS than BASELINE.  A one-sided prediction is what
               makes this cheap to test.

This tool reads the three worlds off the corpus instead of arguing about them:

  * W-nil is refuted by ANY Zeus ability cast, and refuted with a margin by a
    cast dispatched from BELOW the raising line (`zuus_cloud`, X.ConsiderD at
    hero_zuus.lua:552, sits after the assignment at :389 in the W12 tree).
  * W-untrained vs W-trained is separated by the leg contrast on the two
    consumers, ab/ba stratified (铁律 4(i)).

WHAT THIS TOOL DOES NOT DO
--------------------------
It does not identify WHICH ability `sAbilityList[5]` is.  The walk's drop rule
(`NOT_LEARNABLE and IsHidden()`) is not in the dump, and the dumper filters
hidden abilities out of the snapshot array altogether, so the offline slot list
is the VISIBLE abilities, not the walk's input.  What the corpus can settle is
whether the handle raises, and whether the leg moves a decision -- which is
exactly what condition (a) asks and what GH #207 needs ruled.

Read-only.  No AWS spend, no bot Lua touched.
"""
import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402

HERO = 'npc_dota_hero_zuus'
ULT = 'zuus_thundergods_wrath'
BOLT = 'zuus_lightning_bolt'
ARC = 'zuus_arc_lightning'
JUMP = 'zuus_heavenly_jump'
CLOUD = 'zuus_cloud'          # scepter; X.ConsiderD, dispatched BELOW the raise
HANDS = 'zuus_lightning_hands'  # shard
STATIC = 'zuus_static_field'  # innate + hidden; never in the dump (measured)

ZEUS_OWN = (ARC, BOLT, JUMP, ULT, CLOUD, HANDS)

# Window for "did this ult convert", queue.json:hero-12's requested reading (2).
ULT_KILL_WINDOW = 3.0
# Window for "did the bolt actually finish the creep it was aimed at".
BOLT_KILL_WINDOW = 1.0

# The two constants the legs disagree about, read off the Lua rather than
# retyped, so the tool goes red if the file drifts.
LUA = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   '..', '..', '..', 'bots', 'BotLib', 'hero_zuus.lua')


def _is_creep(name):
    return bool(name) and name.startswith('npc_dota_creep_')


def _is_ranged_creep(name):
    """X.GetRanged's quarry.  `_flagbearer` and `_melee` are not it."""
    return _is_creep(name) and name.endswith('_ranged')


def shipped_baseline_bonus(path=LUA):
    """The gate-off constant, read out of hero_zuus.lua (not retyped)."""
    with open(path) as fh:
        src = fh.read()
    body = src[src.index('function X.GetStaticFieldBonus'):]
    body = body[:body.index('\nend')]
    m = re.search(r'return\s+(0\.\d+)\s*$', body, re.M)
    if not m:
        raise SystemExit('hero_zuus.lua: no gate-off constant in '
                         'X.GetStaticFieldBonus -- the tool is stale')
    return float(m.group(1))


def armed_reads_key(path=LUA):
    """The KV key the armed branch asks for -- also read, not retyped."""
    with open(path) as fh:
        src = fh.read()
    body = src[src.index('function X.GetStaticFieldBonus'):]
    body = body[:body.index('\nend')]
    m = re.search(r"GetSpecialValueFloat\(\s*'([a-z_]+)'\s*\)", body)
    if not m:
        raise SystemExit('hero_zuus.lua: armed branch no longer reads a KV key')
    return m.group(1)


def scan_game(timeline, side, seed, game):
    """One game -> one record.  `side` is the physical team ARMED in this game."""
    ev = timeline['events']
    frames, teams = entities.frames_by_hero(timeline)
    zf = frames.get(entities.canon(HERO), [])
    if not zf:
        return None

    team = teams[entities.canon(HERO)]  # 2 radiant, 3 dire
    armed_team = {'radiant': 2, 'dire': 3}[side]
    zeus_armed = (team == armed_team)

    casts = [e for e in ev if e.get('type') == 'ABILITY'
             and e.get('actor') == HERO and e.get('inflictor') in ZEUS_OWN]
    by_ability = collections.Counter(e['inflictor'] for e in casts)

    deaths = [e for e in ev if e.get('type') == 'DEATH']
    hero_deaths = [e for e in deaths if e.get('target_hero')]
    enemy_hero_deaths = [e['t'] for e in hero_deaths
                         if e.get('target') != HERO]

    # --- consumer 2: X.ConsiderR, the ~130s global execute -------------------
    ult_t = sorted(e['t'] for e in casts if e['inflictor'] == ULT)
    ult_kills = []
    for t in ult_t:
        ult_kills.append(sum(1 for dt in enemy_hero_deaths
                             if t <= dt <= t + ULT_KILL_WINDOW))

    # --- consumer 1: X.ConsiderW, the ranged-creep snipe ---------------------
    # ⚠️ TOOL TRAP, measured 2026-08-26 on `20260826_031246_slot7` before this
    # channel was published.  An ABILITY event whose `target` is
    # `dota_unknown` (target_hero False) does NOT mean the cast was aimed at a
    # creep -- it means the dumper could not resolve the target handle.  In
    # that game 21 of 28 bolts read `dota_unknown`, and correlating each cast
    # with the bolt DAMAGE events in the next 1.2 s shows all but one landing
    # on an ENEMY HERO.  Reading `not target_hero` as "creep snipe" would have
    # published a leg contrast on an instrument artefact.
    #
    # The branch's real footprint is the DAMAGE stream, where creeps DO carry
    # their names: `npc_dota_creep_*_ranged` is X.GetRanged's quarry.
    bolts = [e for e in casts if e['inflictor'] == BOLT]
    bolt_unresolved = [e for e in bolts if not e.get('target_hero')]
    bolt_dmg = [e for e in ev if e.get('type') == 'DAMAGE'
                and e.get('actor') == HERO and e.get('inflictor') == BOLT]
    bolt_dmg_ranged_creep = [e for e in bolt_dmg
                             if _is_ranged_creep(e.get('target'))]
    bolt_dmg_any_creep = [e for e in bolt_dmg if _is_creep(e.get('target'))]
    # Did the bolt actually finish it?  GH #173's claim is that the shipped
    # 0.09 credits Zeus damage he cannot deal, so the BASELINE leg should show
    # more bolts that hit a ranged creep WITHOUT killing it.
    creep_kills = [(e['t'], e.get('target')) for e in deaths
                   if e.get('actor') == HERO and _is_ranged_creep(e.get('target'))]
    bolt_ranged_converted = sum(
        1 for e in bolt_dmg_ranged_creep
        if any(e['t'] <= kt <= e['t'] + BOLT_KILL_WINDOW and tgt == e.get('target')
               for kt, tgt in creep_kills))

    # --- which of the three worlds ------------------------------------------
    # A cast dispatched from BELOW the raising line refutes W-nil with margin.
    below_raise = by_ability[CLOUD]

    # First appearance of the two grant abilities, for the "when could the
    # handle have become trained" axis.
    def first_seen(name):
        for s in zf:
            for a in (s.get('abilities') or []):
                if a['name'] == name:
                    return s['t']
        return None

    static_ever = any(a['name'] == STATIC
                      for s in zf for a in (s.get('abilities') or []))

    return {
        'game': game, 'seed': seed, 'armed_side': side,
        'zeus_team': 'radiant' if team == 2 else 'dire',
        'zeus_armed': zeus_armed,
        'duration_s': timeline['game'].get('duration_s'),
        'casts_total': len(casts),
        'casts': dict(by_ability),
        'casts_below_raise': below_raise,
        'ult_casts': len(ult_t),
        'ult_t': ult_t,
        'ult_kills_3s': ult_kills,
        'ult_zero_kill': sum(1 for k in ult_kills if k == 0),
        'bolt_casts': len(bolts),
        'bolt_unresolved_target': len(bolt_unresolved),  # instrument, not a decision
        'bolt_dmg_events': len(bolt_dmg),
        'bolt_dmg_ranged_creep': len(bolt_dmg_ranged_creep),
        'bolt_dmg_any_creep': len(bolt_dmg_any_creep),
        'bolt_ranged_converted': bolt_ranged_converted,
        'shard_first_t': first_seen(HANDS),
        'scepter_first_t': first_seen(CLOUD),
        'static_field_in_dump': static_ever,
        'zeus_deaths': sum(1 for e in hero_deaths if e.get('target') == HERO),
    }


def aggregate(records):
    """ab/ba stratified, per 铁律 4(i): never pool the two legs' strata."""
    out = {}
    for stratum in ('radiant', 'dire'):
        rows = [r for r in records if r['armed_side'] == stratum]
        legs = {}
        for armed in (True, False):
            sub = [r for r in rows if r['zeus_armed'] == armed]
            if not sub:
                continue
            n = len(sub)
            legs['armed' if armed else 'baseline'] = {
                'games': n,
                'ult_casts_mean': round(sum(r['ult_casts'] for r in sub) / n, 3),
                'ult_casts_total': sum(r['ult_casts'] for r in sub),
                'bolt_ranged_creep_total': sum(
                    r['bolt_dmg_ranged_creep'] for r in sub),
                'bolt_ranged_converted_total': sum(
                    r['bolt_ranged_converted'] for r in sub),
                'casts_total_mean': round(
                    sum(r['casts_total'] for r in sub) / n, 3),
                'mute_games': sum(1 for r in sub if r['casts_total'] == 0),
                'below_raise_games': sum(1 for r in sub
                                         if r['casts_below_raise'] > 0),
            }
        out[stratum] = legs
    return out


# --------------------------------------------------------------------------
# selfcheck: every predicate must be able to answer NO, and every world the
# tool claims to tell apart must be exercised by a synthetic corpus.
# --------------------------------------------------------------------------
def _snap(t, team=2, abilities=None, idx=1280):
    return {'t': t, 'hero': HERO, 'idx': idx, 'team': team, 'player_id': 1,
            'x': 0.0, 'y': 0.0, 'hp': 100, 'hp_pct': 1.0, 'mp': 100,
            'max_mp': 100, 'mp_pct': 1.0, 'level': 10, 'items': [],
            'abilities': abilities if abilities is not None else [
                {'name': ARC, 'level': 4, 'cd': 0, 'cd_len': 1.3}]}


def _cast(t, ability, target='dota_unknown', target_hero=False):
    return {'t': t, 'type': 'ABILITY', 'actor': HERO, 'target': target,
            'inflictor': ability, 'value': 0, 'actor_hero': True,
            'target_hero': target_hero}


def _dmg(t, ability, target, target_hero, actor=HERO, value=100):
    return {'t': t, 'type': 'DAMAGE', 'actor': actor, 'target': target,
            'inflictor': ability, 'value': value, 'actor_hero': True,
            'target_hero': target_hero}


def _tl(snaps, events, duration=1200):
    return {'game': {'duration_s': duration}, 'snapshots': snaps,
            'events': events, 'buildings': [], 'creeps': [], 'wards': []}


def selfcheck():
    ok, bad = [], []

    def chk(name, cond):
        (ok if cond else bad).append(name)

    base = shipped_baseline_bonus()
    chk('gate-off constant read off the Lua is 0.09', base == 0.09)
    chk('armed branch still asks for damage_health_pct',
        armed_reads_key() == 'damage_health_pct')

    # --- W-nil: a mute Zeus is representable and is NOT silently normalised --
    tl = _tl([_snap(-60), _snap(60), _snap(600)], [])
    r = scan_game(tl, 'radiant', '888', 'g_mute')
    chk('W-nil: mute Zeus reads 0 casts', r['casts_total'] == 0)
    chk('W-nil: mute Zeus reads 0 ults', r['ult_casts'] == 0)
    chk('W-nil: mute Zeus has no below-raise cast',
        r['casts_below_raise'] == 0)

    # --- the below-raise witness must be able to answer YES *and* NO ---------
    tl = _tl([_snap(-60), _snap(600)],
             [_cast(100, ARC), _cast(500, ULT)])
    r = scan_game(tl, 'radiant', '888', 'g_no_cloud')
    chk('below-raise witness answers NO when only ConsiderR/Q fired',
        r['casts_below_raise'] == 0 and r['casts_total'] == 2)
    tl = _tl([_snap(-60), _snap(600)], [_cast(100, ARC), _cast(500, CLOUD)])
    r = scan_game(tl, 'radiant', '888', 'g_cloud')
    chk('below-raise witness answers YES on a zuus_cloud cast',
        r['casts_below_raise'] == 1)

    # --- leg assignment must follow the PHYSICAL team, both ways -------------
    tl = _tl([_snap(-60, team=2), _snap(600, team=2)], [_cast(10, ARC)])
    chk('zeus on radiant + armed radiant  => armed leg',
        scan_game(tl, 'radiant', '888', 'g')['zeus_armed'] is True)
    chk('zeus on radiant + armed dire     => baseline leg',
        scan_game(tl, 'dire', '888', 'g')['zeus_armed'] is False)
    tl = _tl([_snap(-60, team=3), _snap(600, team=3)], [_cast(10, ARC)])
    chk('zeus on dire + armed dire        => armed leg',
        scan_game(tl, 'dire', '888', 'g')['zeus_armed'] is True)
    chk('zeus on dire + armed radiant     => baseline leg',
        scan_game(tl, 'radiant', '888', 'g')['zeus_armed'] is False)

    # --- ult conversion window: both answers reachable ----------------------
    ev = [_cast(100, ULT),
          {'t': 101.0, 'type': 'DEATH', 'target': 'npc_dota_hero_lina',
           'target_hero': True},
          _cast(400, ULT),
          {'t': 500.0, 'type': 'DEATH', 'target': 'npc_dota_hero_lina',
           'target_hero': True}]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk('ult conversion: in-window kill counted', r['ult_kills_3s'][0] == 1)
    chk('ult conversion: out-of-window kill NOT counted',
        r['ult_kills_3s'][1] == 0)
    chk('ult conversion: zero-kill ults counted', r['ult_zero_kill'] == 1)
    ev2 = ev + [{'t': 101.5, 'type': 'DEATH', 'target': HERO,
                 'target_hero': True}]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev2), 'radiant', '888', 'g')
    chk("ult conversion: Zeus's OWN death is not an ult kill",
        r['ult_kills_3s'][0] == 1 and r['zeus_deaths'] == 1)

    # --- the bolt channel: the TRAP this tool was corrected for -------------
    # An unresolved ABILITY target that DAMAGES a hero must never land in the
    # creep-snipe channel.  This is the 2026-08-26 measurement encoded so it
    # cannot come back.
    ev = [_cast(10, BOLT, 'dota_unknown', False),
          _dmg(10.1, BOLT, 'npc_dota_hero_lina', True)]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk('TRAP: an unresolved bolt that damaged a HERO is not a creep snipe',
        r['bolt_unresolved_target'] == 1 and r['bolt_dmg_ranged_creep'] == 0
        and r['bolt_dmg_any_creep'] == 0)
    # ...and the channel must still be able to answer YES, or it is empty by
    # construction rather than by measurement.
    ev = [_cast(10, BOLT, 'dota_unknown', False),
          _dmg(10.1, BOLT, 'npc_dota_creep_badguys_ranged', False)]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk('creep-snipe channel answers YES on a bolt that damaged a ranged creep',
        r['bolt_dmg_ranged_creep'] == 1 and r['bolt_dmg_any_creep'] == 1)
    chk('...and reads it UNCONVERTED when no death follows',
        r['bolt_ranged_converted'] == 0)
    ev.append({'t': 10.4, 'type': 'DEATH', 'actor': HERO,
               'target': 'npc_dota_creep_badguys_ranged', 'target_hero': False})
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk('...and CONVERTED when the creep dies inside the window',
        r['bolt_ranged_converted'] == 1)
    ev[-1]['t'] = 30.0
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk('...and not converted by a death outside the window',
        r['bolt_ranged_converted'] == 0)
    # melee and flagbearer creeps are not X.GetRanged's quarry
    ev = [_cast(10, BOLT, 'dota_unknown', False),
          _dmg(10.1, BOLT, 'npc_dota_creep_badguys_melee', False),
          _dmg(10.2, BOLT, 'npc_dota_creep_goodguys_flagbearer', False)]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk('melee/flagbearer creeps counted as creeps but NOT as ranged',
        r['bolt_dmg_any_creep'] == 2 and r['bolt_dmg_ranged_creep'] == 0)
    # another hero's bolt damage must not be attributed to Zeus
    ev = [_dmg(10.1, BOLT, 'npc_dota_creep_badguys_ranged', False,
               actor='npc_dota_hero_lina')]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk("another unit's bolt damage is not Zeus's creep snipe",
        r['bolt_dmg_ranged_creep'] == 0)

    # --- another hero's cast must not be counted as Zeus's ------------------
    ev = [{'t': 10, 'type': 'ABILITY', 'actor': 'npc_dota_hero_lina',
           'target': 'dota_unknown', 'inflictor': ULT, 'actor_hero': True,
           'target_hero': False}]
    r = scan_game(_tl([_snap(-60), _snap(600)], ev), 'radiant', '888', 'g')
    chk("another hero's ult is not attributed to Zeus", r['ult_casts'] == 0)

    # --- illusion streams must not create a second Zeus ---------------------
    snaps = [_snap(-60), _snap(600),
             _snap(500, idx=2400), _snap(600, idx=2400)]
    r = scan_game(_tl(snaps, [_cast(10, ARC)]), 'radiant', '888', 'g')
    chk('illusion stream dropped (entities.py), team still read',
        r is not None and r['zeus_team'] == 'radiant')

    # --- grant-ability first-seen must answer None as well as a time --------
    snaps = [_snap(-60), _snap(300),
             _snap(600, abilities=[{'name': ARC, 'level': 4, 'cd': 0,
                                    'cd_len': 1.3},
                                   {'name': HANDS, 'level': 1, 'cd': 0,
                                    'cd_len': 0}])]
    r = scan_game(_tl(snaps, [_cast(10, ARC)]), 'radiant', '888', 'g')
    chk('shard first-seen finds the first frame carrying it',
        r['shard_first_t'] == 600)
    chk('scepter first-seen answers None when never granted',
        r['scepter_first_t'] is None)
    chk('static field is absent from the dump (the measured LIMIT)',
        r['static_field_in_dump'] is False)
    snaps[-1]['abilities'].append({'name': STATIC, 'level': 1, 'cd': 0,
                                   'cd_len': 0})
    r = scan_game(_tl(snaps, [_cast(10, ARC)]), 'radiant', '888', 'g')
    chk('...and that probe can answer YES, so it is not structurally empty',
        r['static_field_in_dump'] is True)

    # --- a Zeus-less game must be dropped, not silently zero-filled ---------
    tl = _tl([{'t': 10, 'hero': 'npc_dota_hero_lina', 'idx': 7, 'team': 2,
               'player_id': 2, 'x': 0.0, 'y': 0.0, 'hp': 1, 'hp_pct': 1.0,
               'mp': 1, 'max_mp': 1, 'mp_pct': 1.0, 'level': 1, 'items': [],
               'abilities': []}], [])
    chk('a game without Zeus returns None (not a zero row)',
        scan_game(tl, 'radiant', '888', 'g') is None)

    # --- aggregate must keep the two strata apart ---------------------------
    recs = [
        {'game': 'a', 'seed': '888', 'armed_side': 'radiant',
         'zeus_armed': True, 'ult_casts': 4, 'bolt_dmg_ranged_creep': 10, 'bolt_ranged_converted': 4,
         'casts_total': 100, 'casts_below_raise': 1},
        {'game': 'b', 'seed': '888', 'armed_side': 'dire',
         'zeus_armed': False, 'ult_casts': 8, 'bolt_dmg_ranged_creep': 20, 'bolt_ranged_converted': 6,
         'casts_total': 120, 'casts_below_raise': 1},
    ]
    agg = aggregate(recs)
    chk('aggregate keeps ab and ba in separate strata',
        agg['radiant']['armed']['ult_casts_mean'] == 4.0
        and agg['dire']['baseline']['ult_casts_mean'] == 8.0)
    chk('aggregate does not invent the missing leg of a stratum',
        'baseline' not in agg['radiant'] and 'armed' not in agg['dire'])
    chk('mute-game counter can answer YES',
        aggregate([dict(recs[0], casts_total=0)])['radiant']['armed']
        ['mute_games'] == 1)

    for name in ok:
        print('PASS  ' + name)
    for name in bad:
        print('FAIL  ' + name)
    print('\n%d PASS / %d FAIL' % (len(ok), len(bad)))
    return 0 if not bad else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('timeline', nargs='?')
    ap.add_argument('--side', help='physical team ARMED in this game')
    ap.add_argument('--seed', default='?')
    ap.add_argument('--game', default='?')
    ap.add_argument('--records', help='aggregate a jsonl of scan_game records')
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()

    if args.records:
        recs = [json.loads(l) for l in open(args.records) if l.strip()]
        print(json.dumps(aggregate(recs), indent=1))
        return 0

    if not args.timeline or not args.side:
        ap.error('need <timeline> --side, or --records, or --selfcheck')
    with open(args.timeline) as fh:
        tl = json.load(fh)
    rec = scan_game(tl, args.side, args.seed, args.game)
    print(json.dumps(rec) if rec else json.dumps({'game': args.game,
                                                  'no_zeus': True}))
    return 0


if __name__ == '__main__':
    sys.exit(main())

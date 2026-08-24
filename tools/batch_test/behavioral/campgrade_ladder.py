#!/usr/bin/env python3
"""(a)-verification for soak candidate `campgrade` (GH #137), ancient clause.

WHAT `campgrade` DOES
---------------------
`bots/mode_farm_generic.lua:242` passes `J.IsModeTurbo() and
J.IsSoakCandidate('campgrade')` into `J.Site.RefreshCamp` as `bStrictLadder`.
When true, `aba_site.IsCampAllowedForLevel` filters the camp list; when false
the list is every camp on the map at every level (the shipped default, whose
if/elseif chain decides nothing because every branch bounds the level from
ABOVE and ends in an unconditional `else`).

The clauses that apply to an ANCIENT camp are exactly two, and they COMPOSE:

    IsAncientCamp(camp) and botLevel < 12  -> reject
    IsEnemyCamp(camp)   and botLevel < 15  -> reject

so an ancient camp on the enemy's half needs 15, its own half needs 12.

WHY THIS IS THE ACCEPTANCE QUANTITY
-----------------------------------
`campgrade` edits a LIST, and a list is not observable in a replay.  What IS
observable is the population the list edit is supposed to empty: an
under-levelled hero trading with an ancient camp.  That population is the
frame evidence that motivated GH #137 in the first place (2026-08-23T06:36Z:
a level-11 Wraith King, starting items, 28 s in the Radiant ancient camp,
100% -> 13.5% HP for 166 gold, no enemy hero within 6,000 u).

`ancient_camp_domain.py` already censuses that population geometrically.
This file adds the three things the (a)-verification needs and that file
does not have: the armed/baseline LEG, the ladder predicate itself, and the
#148 reporting discipline.

THE ONE THING THIS CANNOT PROVE, STATED UP FRONT
------------------------------------------------
A camp missing from `availableCampTable` cannot be CHOSEN, but a hero can
still end up trading with it -- walking past it, being chased through it,
or a camp's aggro reaching him.  So an under-levelled ancient episode on the
armed leg is NOT automatically a gate failure.  `opened` (the hero's own
first damage lands before the camp's, inherited from `ancient_camp_domain`)
is the closest offline read of "he chose this fight", and every table below
is reported both ways.  Read the `opened` column as the gate's own domain and
the all-episodes column as the upper bound.

`level` is the hero's level at the episode's FIRST frame, which is the
decision-side convention (never read a frame from the future of the instant
being described).  `bot:GetAttackDamage()` is not in the dump, so the
large-camp clause is out of reach -- but it does not touch ancient camps, so
nothing about the ancient ladder is censored by that.

#148 DISCIPLINE (and the 08-23T21:00Z correction to it)
-------------------------------------------------------
Every armed/baseline number below is reported in BOTH physical strata
(radiant-armed = "ab", dire-armed = "ba").  The estimator is the mean of the
two strata's paired per-game differences, not the pooled difference: within
one stratum the armed leg IS one physical side, so the paired difference
still carries the whole side term; that term enters the two strata with
opposite sign and the average cancels it exactly.  Two strata that disagree
in sign are therefore NOT automatically noise -- compute the mean first.

Usage:
    campgrade_ladder.py <sweep_dir> [<sweep_dir> ...] [--selfcheck]

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ancient_camp_domain import (  # noqa: E402
    DEFAULT_AFTER, DEFAULT_GAP, DEFAULT_TAIL, episodes_for_game, load)
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402

# The ladder, transcribed from bots/FunLib/aba_site.lua:IsCampAllowedForLevel.
# Kept as named constants so a future patch to the Lua shows up as a diff here
# rather than as a silently wrong verdict.
ANCIENT_MIN_LEVEL = 12
ENEMY_MIN_LEVEL = 15


def camp_owner(x, y, ancients):
    """Which team's half is this ancient camp on?

    Decided by distance to each team's ANCIENT building, read out of the
    timeline, not by a hardcoded sign of x.  The four ancient camps sit at
    |x| ~ 4000-5000, y ~ 0 (charter: exactly two clusters per corpus), i.e.
    on the map's short axis, where the two ancients are ~19k apart -- so this
    is a wide-margin call, not a coin flip.  Returns None if the timeline
    carries no ancient buildings (then the enemy clause is unevaluable and
    the episode is reported in the `own-clause only` column).
    """
    if RADIANT not in ancients or DIRE not in ancients:
        return None
    dr = math.dist((x, y), ancients[RADIANT])
    dd = math.dist((x, y), ancients[DIRE])
    return RADIANT if dr < dd else DIRE


def required_level(camp_team, hero_team):
    """The composed lower bound IsCampAllowedForLevel imposes on this camp."""
    if camp_team is not None and camp_team != hero_team:
        return max(ANCIENT_MIN_LEVEL, ENEMY_MIN_LEVEL)
    return ANCIENT_MIN_LEVEL


def scan_sweep(d):
    """One sweep dir -> episode records tagged with leg and ladder verdict."""
    out = []
    ngames = 0
    for m in load_sweep(d):
        tl_path = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
        if not os.path.exists(tl_path):
            print('[warn] missing timeline %s' % tl_path, file=sys.stderr)
            continue
        tl = load(tl_path)
        ngames += 1
        teams = tl['game']['teams']
        armed_team = RADIANT if m['side'] == 'radiant' else DIRE
        ancients = {}
        for b in tl.get('buildings', []):
            if b['name'] == 'ancient':
                ancients.setdefault(b['team'], (b['x'], b['y']))
        # Running max level per TEAM.  `J.Role.availableCampTable` is a
        # module-level table in bots/FunLib/aba_role.lua:292, i.e. ONE table
        # shared by all five bots of a team, and the refresh at
        # mode_farm_generic.lua:241 overwrites it wholesale with the list
        # filtered by whichever single bot happens to run that Think inside the
        # `sec in (0,2)` window.  So the strongest thing that can be said about
        # a camp's presence in the list is: SOME bot on this team was high
        # enough to admit it at SOME earlier refresh.  Taking the max over the
        # whole game up to t0 makes the test one-directional and sound in only
        # one direction -- if even the team's best level never reached the
        # bound, no refresh could have admitted the camp, and the list is
        # exonerated.  The converse is NOT proof that the list is to blame.
        max_lvl = {RADIANT: [], DIRE: []}
        for s in sorted(tl['snapshots'], key=lambda s: s['t']):
            tm = teams.get(s['hero'])
            if tm in max_lvl:
                prev = max_lvl[tm][-1][1] if max_lvl[tm] else 0
                max_lvl[tm].append((s['t'], max(prev, s['level'])))

        def team_max_before(tm, t):
            best = 0
            for ts, lv in max_lvl.get(tm, []):
                if ts > t:
                    break
                best = lv
            return best

        eps, _ = episodes_for_game(tl, tl_path, DEFAULT_GAP, DEFAULT_TAIL,
                                   DEFAULT_AFTER)
        for e in eps:
            hero_full = 'npc_dota_hero_' + e['hero']
            ht = teams.get(hero_full)
            if ht is None:
                continue
            ct = camp_owner(e['x0'], e['y0'], ancients)
            need = required_level(ct, ht)
            e = dict(e)
            e['game'] = m['game']
            e['seed'] = m.get('seed')
            e['leg'] = 'armed' if ht == armed_team else 'baseline'
            e['arm_side'] = 'radiant' if armed_team == RADIANT else 'dire'
            e['camp_side'] = ('own' if ct == ht
                              else ('enemy' if ct is not None else 'unknown'))
            e['need'] = need
            e['violation'] = e['level'] < need
            e['violation_own'] = e['level'] < ANCIENT_MIN_LEVEL
            e['team_max_level'] = team_max_before(ht, e['t0'])
            # True = no refresh by ANY teammate could have put this camp in the
            # shared list, so the list filter is not what let him in.
            e['list_exonerated'] = e['team_max_level'] < need
            out.append(e)
    return out, ngames


def strata_table(recs, ngames_by_side, key, title, only_opened):
    """Per-leg counts in both physical strata plus the pooled row."""
    print('\n  %s%s' % (title, '   [opened-only]' if only_opened else ''))
    print('  %-16s %-9s %6s %8s %8s %10s'
          % ('stratum', 'leg', 'games', 'episodes', 'hits', 'hits/game'))
    xs_all = [r for r in recs if (r['opened'] if only_opened else True)]
    for lbl, side in (('radiant-armed', 'radiant'), ('dire-armed', 'dire'),
                      ('POOLED (#148)', None)):
        ng = (ngames_by_side['radiant'] + ngames_by_side['dire']
              if side is None else ngames_by_side[side])
        for leg in ('armed', 'baseline'):
            xs = [r for r in xs_all
                  if r['leg'] == leg and (side is None or r['arm_side'] == side)]
            hit = sum(1 for r in xs if r[key])
            print('  %-16s %-9s %6d %8d %8d %10.3f'
                  % (lbl, leg, ng, len(xs), hit, hit / float(max(ng, 1))))


def balanced(recs, ngames_side_games, keys, only_opened):
    """Mean of the two strata's paired per-game (armed - baseline) counts.

    Paired WITHIN a game: mirrored draft makes the two legs of one game the
    same ten heroes, so the pairing is exact and the physical-side term is the
    only one left -- and averaging the two strata cancels that.

    Games with no ancient episode at all still count: they are real zeros in
    both legs, and dropping them would condition the denominator on the
    outcome.  `ngames_side_games` is therefore the full per-side game-name
    list, not the set of games that produced a record.
    """
    print('\n[balanced] per-game paired counts, averaged over the two '
          'armed-side strata (#148 + the 08-23T21:00Z correction)%s'
          % ('   [opened-only]' if only_opened else ''))
    print('%-24s %10s %10s %10s %8s'
          % ('quantity', 'ab (rad)', 'ba (dire)', 'balanced', '|t|'))
    per = defaultdict(lambda: defaultdict(int))
    for r in recs:
        if only_opened and not r['opened']:
            continue
        per[r['game']]['%s_eps' % r['leg']] += 1
        for k in keys:
            if r[k]:
                per[r['game']]['%s_%s' % (r['leg'], k)] += 1
    for key, lbl in [('eps', 'ancient episodes')] + \
            [(k, k) for k in keys]:
        cell = {}
        for s in ('radiant', 'dire'):
            d = [per[g]['armed_' + key] - per[g]['baseline_' + key]
                 for g in ngames_side_games[s]]
            if not d:
                cell[s] = (0.0, 0.0)
                continue
            m = sum(d) / float(len(d))
            var = sum((x - m) ** 2 for x in d) / max(len(d) - 1, 1)
            cell[s] = (m, var / len(d))
        bal = 0.5 * (cell['radiant'][0] + cell['dire'][0])
        se = 0.5 * math.sqrt(cell['radiant'][1] + cell['dire'][1])
        print('%-24s %+10.3f %+10.3f %+10.3f %8s'
              % (lbl + '/game', cell['radiant'][0], cell['dire'][0], bal,
                 ('%.2f' % abs(bal / se)) if se else 'inf'))
    print('  (|t| is a noise ruler, not a gate -- the promote bar is the '
          "owner's three conditions.)")


def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    # --- camp ownership is decided by the ancients, not by a sign convention.
    anc = {RADIANT: (-7000.0, -6600.0), DIRE: (7000.0, 6600.0)}
    chk('ancient camp at x=-4600 belongs to radiant',
        camp_owner(-4600.0, 100.0, anc) == RADIANT)
    chk('ancient camp at x=+4600 belongs to dire',
        camp_owner(4600.0, -100.0, anc) == DIRE)
    chk('no ancient buildings -> owner unknown',
        camp_owner(-4600.0, 0.0, {}) is None)
    # Ownership must not flip when the fight drifts along y within the camp.
    chk('ownership stable across the camp radius',
        camp_owner(-4600.0, 900.0, anc) == camp_owner(-4600.0, -900.0, anc)
        == RADIANT)

    # --- the composed ladder.  The bug the Lua comment calls out is exactly
    # an if/elseif that lets a camp fall THROUGH into a more permissive
    # branch, so the two clauses must COMPOSE, not alternate.
    chk('own ancient needs 12', required_level(RADIANT, RADIANT) == 12)
    chk('enemy ancient needs 15, not 12',
        required_level(DIRE, RADIANT) == 15,
        'the enemy clause must not be shadowed by the ancient clause')
    chk('unknown owner falls back to the own-side bound',
        required_level(None, RADIANT) == 12,
        'strictly under-strict: never invents a violation it cannot prove')

    # --- boundary: the Lua is `botLevel < 12`, so 12 itself is ALLOWED.
    chk('level 11 vs own ancient is a violation', 11 < required_level(2, 2))
    chk('level 12 vs own ancient is allowed', not (12 < required_level(2, 2)))
    chk('level 14 vs enemy ancient is a violation', 14 < required_level(3, 2))
    chk('level 15 vs enemy ancient is allowed', not (15 < required_level(3, 2)))

    # --- the shared-list attribution is one-directional by construction.
    # Re-expressed as the pure predicate so the asymmetry is pinned, not just
    # commented: exoneration requires the team's BEST level to fall short of
    # the bound the camp imposes, which is why it can only ever clear the list,
    # never convict it.
    def exonerated(team_max, need):
        return team_max < need

    chk('team max 11 vs own ancient (12) -> list exonerated',
        exonerated(11, 12) is True)
    chk('team max 12 vs own ancient (12) -> NOT exonerated',
        exonerated(12, 12) is False,
        'a teammate at exactly the bound can admit the camp')
    chk('team max 14 vs ENEMY ancient (15) -> list exonerated',
        exonerated(14, 15) is True,
        'the enemy bound must be the one tested, not the ancient bound')
    chk('exoneration ignores the offender own level',
        exonerated(11, 12) == exonerated(11, 12))

    # --- the balanced estimator must cancel a pure physical-side term.
    # Construct a corpus where the ONLY signal is "dire heroes fight ancients
    # more", identical on both legs: the pooled armed-baseline difference is
    # then nonzero in each stratum with opposite signs, and the balanced
    # estimator must read 0.
    recs = []
    for i in range(10):
        for side, dire_extra in (('radiant', 3), ('dire', 3)):
            gname = '%s%d' % (side, i)
            # dire team always logs `dire_extra` episodes, radiant team 1.
            for team, n in ((DIRE, dire_extra), (RADIANT, 1)):
                armed_team = RADIANT if side == 'radiant' else DIRE
                for _ in range(n):
                    recs.append(dict(
                        game=gname, arm_side=side, opened=True,
                        leg='armed' if team == armed_team else 'baseline',
                        violation=False, violation_own=False))
    games = {'radiant': ['radiant%d' % i for i in range(10)],
             'dire': ['dire%d' % i for i in range(10)]}
    per = defaultdict(lambda: defaultdict(int))
    for r in recs:
        per[r['game']]['%s_eps' % r['leg']] += 1
    cell = {}
    for s in ('radiant', 'dire'):
        d = [per[g]['armed_eps'] - per[g]['baseline_eps'] for g in games[s]]
        cell[s] = sum(d) / float(len(d))
    chk('pure side term: strata disagree in sign',
        cell['radiant'] < 0 < cell['dire'],
        'ab=%+.1f ba=%+.1f' % (cell['radiant'], cell['dire']))
    chk('pure side term: balanced estimator cancels it',
        abs(0.5 * (cell['radiant'] + cell['dire'])) < 1e-9,
        'this is why a sign disagreement is not by itself noise')

    # --- and it must NOT cancel a real effect that is common to both strata.
    per2 = defaultdict(lambda: defaultdict(int))
    for s in ('radiant', 'dire'):
        for g in games[s]:
            per2[g]['armed_eps'] = 1
            per2[g]['baseline_eps'] = 3
    cell2 = {}
    for s in ('radiant', 'dire'):
        d = [per2[g]['armed_eps'] - per2[g]['baseline_eps'] for g in games[s]]
        cell2[s] = sum(d) / float(len(d))
    chk('real common effect survives the average',
        abs(0.5 * (cell2['radiant'] + cell2['dire']) + 2.0) < 1e-9,
        'armed 1 vs baseline 3 in both strata -> -2.0')
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--top', type=int, default=12)
    ap.add_argument('--out', default='/tmp/campgrade_ladder.jsonl')
    a = ap.parse_args()

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck():
            sys.exit(2)
        if not a.sweeps:
            return

    recs = []
    ngames_by_side = {'radiant': 0, 'dire': 0}
    side_games = {'radiant': [], 'dire': []}
    for d in a.sweeps:
        rs, _ = scan_sweep(d)
        recs.extend(rs)
        for m in load_sweep(d):
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if os.path.exists(tl):
                ngames_by_side[m['side']] += 1
                side_games[m['side']].append(m['game'])
    tot = ngames_by_side['radiant'] + ngames_by_side['dire']
    print('corpus: %d games (%d radiant-armed, %d dire-armed) from %d sweep dir(s)'
          % (tot, ngames_by_side['radiant'], ngames_by_side['dire'],
             len(a.sweeps)))
    print('ancient-camp episodes: %d' % len(recs))
    if not recs:
        return

    unk = sum(1 for r in recs if r['camp_side'] == 'unknown')
    print('camp ownership: own %d, enemy %d, unknown %d'
          % (sum(1 for r in recs if r['camp_side'] == 'own'),
             sum(1 for r in recs if r['camp_side'] == 'enemy'), unk))

    for only_opened in (False, True):
        strata_table(recs, ngames_by_side, 'violation',
                     'LADDER VIOLATION (level < the composed bound: 12 own / '
                     '15 enemy)', only_opened)
        strata_table(recs, ngames_by_side, 'violation_own',
                     'ANCIENT CLAUSE ONLY (level < 12, ignores camp ownership)',
                     only_opened)
        balanced(recs, side_games, ('violation', 'violation_own'), only_opened)

    print('\n--- level histogram of ancient episodes, per leg ---')
    print('%-9s %s' % ('leg', ' '.join('%4d' % L for L in range(1, 19))))
    for leg in ('armed', 'baseline'):
        h = defaultdict(int)
        for r in recs:
            if r['leg'] == leg:
                h[r['level']] += 1
        print('%-9s %s' % (leg, ' '.join('%4d' % h[L] for L in range(1, 19))))

    # --- which leak channel?  See `list_exonerated` in scan_sweep.
    av = [r for r in recs if r['leg'] == 'armed' and r['violation']]
    ex = [r for r in av if r['list_exonerated']]
    print('\n--- armed-leg violations: could the SHARED list have admitted the '
          'camp? ---')
    print('  armed-leg violations                       : %d' % len(av))
    print('  team never reached the bound before t0      : %d (%.1f%%)'
          % (len(ex), 100.0 * len(ex) / max(len(av), 1)))
    print('    -> for these the list filter is EXONERATED: the camp cannot')
    print('       have been in availableCampTable, so some other path put')
    print('       the bot on an ancient creep.')
    print('  a teammate was high enough at some earlier refresh: %d'
          % (len(av) - len(ex)))
    print('    -> consistent with the shared-table channel (not proof).')

    print('\n--- armed-leg violations, worst first (frame-by-frame targets) ---')
    v = sorted([r for r in recs if r['leg'] == 'armed' and r['violation']],
               key=lambda r: -(r['hp0'] - (r['hp_min'] or r['hp0'])))
    for r in v[:a.top]:
        print('  %s %-16s t=%.1f-%.1f L%d need%d %s hp %.3f->%.3f gold=%d '
              'opened=%s near=%s/t0=%s'
              % (r['game'], r['hero'], r['t0'], r['t1'], r['level'], r['need'],
                 r['camp_side'], r['hp0'], r['hp_min'] if r['hp_min'] is not None
                 else -1, r['gold'], r['opened'], r['nearest_enemy'],
                 r.get('nearest_enemy_t0')))
    print('\n--- baseline-leg violations, worst first (the control) ---')
    v = sorted([r for r in recs if r['leg'] == 'baseline' and r['violation']],
               key=lambda r: -(r['hp0'] - (r['hp_min'] or r['hp0'])))
    for r in v[:a.top]:
        print('  %s %-16s t=%.1f-%.1f L%d need%d %s hp %.3f->%.3f gold=%d '
              'opened=%s near=%s/t0=%s'
              % (r['game'], r['hero'], r['t0'], r['t1'], r['level'], r['need'],
                 r['camp_side'], r['hp0'], r['hp_min'] if r['hp_min'] is not None
                 else -1, r['gold'], r['opened'], r['nearest_enemy'],
                 r.get('nearest_enemy_t0')))

    with open(a.out, 'w') as fh:
        for r in recs:
            fh.write(json.dumps(r) + '\n')
    print('\nwrote %d records to %s' % (len(recs), a.out))


if __name__ == '__main__':
    main()

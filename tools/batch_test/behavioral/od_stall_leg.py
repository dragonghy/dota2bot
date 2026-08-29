#!/usr/bin/env python3
"""OD skill-point stall, crossed with the ARMED/BASELINE leg -- the `hero-22`
pre-gate, and the arithmetic that decides which build row a game actually ran.

WHY THIS FILE EXISTS (hero stream 2026-08-29, GH #309)
------------------------------------------------------
GH #309 (batch desk, W25 harvest) named exactly one thing as the hero stream's
own to run before `hero-22`'s `odbuild` reading may be quoted:

    "`hero-22` 仍须自己先跑 tools/batch_test/behavioral/skill_point_stall.py
      -- OD 若仍在 STALL 表,按上轮裁定标 UNINTERPRETABLE 退回。本台不代跑。"

`skill_point_stall.py` answers "is OD in the STALL table" and stops there.  It
is leg-blind by construction (its own LIMIT 6: the #286 defect is on the
factory path, both legs identical, no arm string is read).  That is the right
scope for THAT module and the wrong scope for this question, because `odbuild`
is precisely a build-row swap: the pre-gate's answer and the id's own condition
(a) are read off the same nine hero-games, and separating them needs the leg.

So this module does two things `skill_point_stall.py` deliberately does not:

  1. joins each game to its wave stamp (`analysis.json:script_version`,
     `mirror:<ids>:s<seed>:<side>`, where <side> is the ARMED side) and to the
     team OD actually played, yielding ARMED / baseline / WARMUP per row;
  2. asks WHICH ROW RAN, by arithmetic rather than by trusting the stamp --
     see ROW ARITHMETIC below.

WHAT WAS MEASURED (W25, tree b51bac77, the 12 dem-backed games)
---------------------------------------------------------------
9 of the 12 games carry an Obsidian Destroyer.  Four of them are STALL rows
(hero level 19-23, SIX skill points, `objurgation` never levelled, the hero
frozen for 78-83% of the game):

    leg              rows   STALL
    ARMED               4       1
    baseline            2       2
    WARMUP(unstamped)   3       1

=> OD IS STILL IN THE STALL TABLE.  Per the registered branch that is
`hero-22` = UNINTERPRETABLE, returned.  That is this module's headline and it
does not depend on any of the arithmetic below.

ROW ARITHMETIC -- WHICH ROW RAN, AND WHY THE STAMP IS NOT THE ANSWER
--------------------------------------------------------------------
Both build tables in bots/BotLib/hero_obsidian_destroyer.lua hold exactly ONE
row, so `J.Skill.GetRandomBuild` is deterministic on both legs -- a within-leg
split is NOT row randomness, and that has to be established before any split is
interpreted at all (it is the first thing an unwary reading gets wrong):

    shipped      {2,1,4,2,2,6,2,1,1,1,6,4,4,4,6}   spends 4 points on [4],
                                                   never names [3]
    odbuild      {2,1,3,2,2,6,2,1,1,1,6,3,3,3,6}   [4] -> [3]

With [3] = objurgation, the third point of the ARMED row is objurgation.  So:

    ANY game that ran the armed row has objurgation rank >= 1 from hero level 3.

That is a one-line falsifier, and one W25 game fails it: `20260829_124418`,
stamped `s1603:radiant` with OD ON RADIANT -- the armed side -- ended with
objurgation at rank 0 and the exact shipped-row signature (arcane_orb 1 /
astral 4 / objurgation 0 / sanity_eclipse 1 = 6 points).  The armed row cannot
produce a rank-0 objurgation at any hero level.  So that game ran the SHIPPED
row while its own stamp says its side was armed.  It is not a deploy-ordering
artifact: the immediately preceding game of the same run, same seed, same side
(`20260829_123208`) reached objurgation rank 4.

This module reports that as ROW_CONTRADICTS_STAMP and counts it separately,
because it is a different kind of fact from a stall: a stall is a defect in the
bot, a row/stamp contradiction is a defect in the READING -- it puts an upper
bound on how much of any armed leg on this wave is actually armed, for every
id, not just `odbuild`.

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **n is nine hero-games.**  The corpus is the 12 dem-backed W25 games (the
   recording slots decided that, not a sample), and 4/2/3 rows across the three
   legs.  NOTHING here is an effect size.  In particular "ARMED 1/4 vs baseline
   2/2" must NOT be read as `odbuild` reducing stalls; iron rule 4(i) wants ab
   and ba layers and this corpus does not have them for OD.  The headline
   (OD is still in the STALL table) needs no comparison and is unaffected.
2. **The stall flag is `skill_point_stall.py`'s cut** (level>=15 and pts<=8),
   imported, not re-implemented, so the two modules cannot drift apart.  That
   cut's justification, and its pts histogram, live in that module.
3. **ROW_CONTRADICTS_STAMP is one-directional.**  objurgation>=1 proves the
   armed row ran; objurgation==0 proves it did not.  A baseline row showing
   objurgation>0 proves neither -- levelling can reach objurgation by paths
   this module does not model, and two W25 WARMUP games do exactly that
   (objurgation 3 and 4 under no stamp at all).  Do NOT read those as "armed".
   Why the shipped row can end anywhere but rank 0 is OPEN and is not answered
   here; see the report and the issue this module was filed with.
4. **The stamp names the armed SIDE, not the armed hero.**  A game is ARMED for
   OD iff OD's team equals that side.  Team ids are the engine's (2 radiant,
   3 dire); mapping them by string comparison against the stamp silently makes
   every row read "baseline", which is how the first pass of this reading came
   out wrong before the arithmetic above caught it.
5. Illusions are dropped upstream by `entities.frames_by_hero` (GH #176).
6. The `abilities` array is not the engine slot array (`skill_point_stall.py`
   LIMIT 2): this module never re-derives a slot from it, only ability RANKS by
   name, which is what the row arithmetic needs.
"""
import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from entities import frames_by_hero  # noqa: E402
from skill_point_stall import census_game, is_stall, LEVEL_MIN, PTS_MAX  # noqa: E402

HERO = 'obsidian_destroyer'
OBJURGATION = 'obsidian_destroyer_objurgation'
# The engine's team ids, not strings -- see LIMIT 4.
TEAM_NAME = {2: 'radiant', 3: 'dire'}


def parse_stamp(script_version):
    """('warmup', None) for an unstamped game, else (seed, armed_side)."""
    sv = script_version or ''
    if not sv.startswith('mirror:'):
        return 'warmup', None
    parts = sv.split(':')
    if len(parts) < 4:
        return 'warmup', None
    return parts[2], parts[3]


def leg_of(od_team, armed_side):
    if armed_side is None:
        return 'WARMUP'
    return 'ARMED' if TEAM_NAME.get(od_team, od_team) == armed_side else 'baseline'


def ability_rank(row_frame, name):
    for a in row_frame or ():
        if a.get('name') == name:
            return a.get('level') or 0
    return 0


def od_row(timeline, game, script_version):
    """One row for the OD in one game, or None if this game has no OD."""
    fr, team = frames_by_hero(timeline)
    if HERO not in fr:
        return None
    stall_rows = {r['hero']: r for r in census_game(timeline, game)}
    r = stall_rows.get(HERO)
    if r is None or r.get('pts') is None:
        return None
    last = None
    for s in reversed(fr[HERO]):
        if s.get('abilities'):
            last = s
            break
    seed, armed_side = parse_stamp(script_version)
    objurg = ability_rank(last.get('abilities') if last else None, OBJURGATION)
    leg = leg_of(team[HERO], armed_side)
    # LIMIT 3: only the rank-0 direction is a proof, and only on an armed leg.
    contradicts = (leg == 'ARMED' and objurg == 0)
    return dict(game=game, seed=seed, armed_side=armed_side,
                od_team=TEAM_NAME.get(team[HERO], team[HERO]), leg=leg,
                level=r['level'], pts=r['pts'], pts_abil=r['pts_abil'],
                pts_talent=r['pts_talent'], objurgation=objurg,
                t_last_gain=r['t_last_gain'], frozen_frac=r['frozen_frac'],
                stall=bool(is_stall(r, LEVEL_MIN, PTS_MAX)),
                row_contradicts_stamp=contradicts)


def summarise(rows):
    out = ['== OD rows (n=%d hero-games) ==' % len(rows), '']
    out.append('%-16s %-7s %-8s %-8s %-9s %4s %4s %5s %6s %s'
               % ('game', 'seed', 'armedsid', 'od_side', 'leg', 'lvl', 'pts',
                  'objrg', 'frozen', 'flag'))
    for r in sorted(rows, key=lambda r: r['game']):
        flags = []
        if r['stall']:
            flags.append('STALL')
        if r['row_contradicts_stamp']:
            flags.append('ROW_CONTRADICTS_STAMP')
        out.append('%-16s %-7s %-8s %-8s %-9s %4s %4s %5s %5.0f%% %s'
                   % (r['game'][:16], r['seed'], r['armed_side'] or '-',
                      r['od_team'], r['leg'], r['level'], r['pts'],
                      r['objurgation'], 100 * r['frozen_frac'],
                      ' '.join(flags) or '-'))

    out.append('')
    out.append('== leg x stall (LIMIT 1: n is tiny, this is NOT an effect size) ==')
    by_leg = collections.Counter(r['leg'] for r in rows)
    st_leg = collections.Counter(r['leg'] for r in rows if r['stall'])
    for leg in ('ARMED', 'baseline', 'WARMUP'):
        if by_leg[leg]:
            out.append('  %-9s rows=%-3d STALL=%d' % (leg, by_leg[leg], st_leg[leg]))
    n_stall = sum(1 for r in rows if r['stall'])
    out.append('')
    out.append('  PRE-GATE (GH #309): OD %s in the STALL table -- %d/%d hero-game(s).'
               % ('IS STILL' if n_stall else 'is NOT', n_stall, len(rows)))
    out.append('  => hero-22 %s' % ('UNINTERPRETABLE, returned' if n_stall
                                    else 'pre-gate PASSES, reading may proceed'))

    bad = [r for r in rows if r['row_contradicts_stamp']]
    out.append('')
    out.append('== ROW_CONTRADICTS_STAMP -- %d row(s) ==' % len(bad))
    if not bad:
        out.append('  none (every ARMED row carries objurgation >= 1)')
    else:
        for r in bad:
            out.append('  %s  seed=%s armed=%s od=%s: objurgation rank 0, but the '
                       'armed row spends its 3rd point there => this game ran the '
                       'SHIPPED row.' % (r['game'][:16], r['seed'],
                                         r['armed_side'], r['od_team']))
    return '\n'.join(out)


# --------------------------------------------------------------------------
# selfcheck: synthetic frames, no S3, no corpus.  Every case pins one claim
# the module's own text makes, so the text cannot quietly stop being true.
# --------------------------------------------------------------------------
def _tl(team, level, ranks, t_end=1500.0):
    """A minimal timeline in the dumper's own shape (a flat `snapshots` list
    keyed by entity `idx`), so the selfcheck exercises the real
    `entities.frames_by_hero` rather than a hand-rolled stand-in."""
    abil = [{'name': n, 'level': lv} for n, lv in ranks.items()]
    zero = [{'name': n, 'level': 0} for n in ranks]
    base = dict(idx=1, hero=HERO, team=team)
    return {'snapshots': [
        dict(base, t=-60.0, level=1, abilities=zero),
        dict(base, t=300.0, level=level, abilities=abil),
        dict(base, t=t_end, level=level, abilities=abil),
    ]}


def selfcheck():
    fails = []

    def chk(name, cond, detail=''):
        if not cond:
            fails.append('%s %s' % (name, detail))
        print('%-4s %s' % ('ok' if cond else 'FAIL', name))

    stalled = {'obsidian_destroyer_arcane_orb': 1,
               'obsidian_destroyer_astral_imprisonment': 4,
               OBJURGATION: 0,
               'obsidian_destroyer_sanity_eclipse': 1}
    healthy = {'obsidian_destroyer_arcane_orb': 4,
               'obsidian_destroyer_astral_imprisonment': 4,
               OBJURGATION: 4,
               'obsidian_destroyer_sanity_eclipse': 3}
    armed_r = 'mirror:odbuild:s1:radiant'

    r = od_row(_tl(2, 23, stalled), 'g', armed_r)
    chk('1 armed leg resolved by TEAM ID, not string (LIMIT 4)', r['leg'] == 'ARMED', r['leg'])
    chk('2 the shipped signature is a STALL', r['stall'] is True)
    chk('3 armed + objurgation 0 => ROW_CONTRADICTS_STAMP', r['row_contradicts_stamp'] is True)

    r = od_row(_tl(3, 23, stalled), 'g', armed_r)
    chk('4 OD on the un-armed side reads baseline', r['leg'] == 'baseline', r['leg'])
    chk('5 a baseline stall is NOT a stamp contradiction (LIMIT 3)',
        r['row_contradicts_stamp'] is False)

    r = od_row(_tl(2, 26, healthy), 'g', armed_r)
    chk('6 armed + objurgation 4 is clean', r['stall'] is False and not r['row_contradicts_stamp'])

    r = od_row(_tl(2, 22, healthy), 'g', 'b51bac77')
    chk('7 unstamped game reads WARMUP, never ARMED', r['leg'] == 'WARMUP', r['leg'])
    chk('8 WARMUP with objurgation>0 is NOT called armed (LIMIT 3)',
        r['row_contradicts_stamp'] is False)

    r = od_row(_tl(2, 12, stalled), 'g', armed_r)
    chk('9 below the level cut it is not a STALL (LIMIT 2: the cut is imported)',
        r['stall'] is False)

    chk('10 no OD in the game => no row', od_row({'snapshots': []}, 'g', armed_r) is None)

    # The falsifier itself: the armed row must still spend a point on
    # objurgation.  If someone edits the row, this module's whole argument is
    # void, so read it off the source rather than trusting this docstring.
    hero_lua = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            '..', '..', '..', 'bots', 'BotLib',
                            'hero_obsidian_destroyer.lua')
    src = open(os.path.abspath(hero_lua)).read()
    chk('11 armed row still names index 3 third (the falsifier)',
        '{2,1,3,2,2,6,2,1,1,1,6,3,3,3,6}' in src,
        'EXPECTED EXPIRY, NOT A REGRESSION: the odbuild row moved; re-derive '
        'ROW_CONTRADICTS_STAMP before quoting this module.')
    chk('12 shipped row still never names index 3',
        '{2,1,4,2,2,6,2,1,1,1,6,4,4,4,6}' in src,
        'EXPECTED EXPIRY, NOT A REGRESSION: the shipped row moved.')

    print('\n%d/%d ok' % (12 - len(fails), 12))
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('timelines', nargs='*', help='timeline JSON files (dumper output)')
    ap.add_argument('--analysis-dir',
                    help='directory of <game>.json analysis files carrying script_version')
    ap.add_argument('--json', help='write the raw rows here')
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()

    rows = []
    for path in args.timelines:
        game = os.path.basename(path).split('.')[0]
        sv = ''
        if args.analysis_dir:
            ap_path = os.path.join(args.analysis_dir, game + '.json')
            if os.path.exists(ap_path):
                with open(ap_path) as fh:
                    sv = json.load(fh).get('script_version', '')
            else:
                print('[warn] no analysis for %s -- it will read WARMUP, which is '
                      'NOT the same as unarmed' % game, file=sys.stderr)
        try:
            with open(path) as fh:
                tl = json.load(fh)
        except (OSError, ValueError) as exc:
            print('[skip] %s: %s' % (path, exc), file=sys.stderr)
            continue
        r = od_row(tl, game, sv)
        if r:
            rows.append(r)

    if not rows:
        print('no OD rows -- pass timelines containing an obsidian_destroyer',
              file=sys.stderr)
        return 2
    if args.json:
        with open(args.json, 'w') as fh:
            json.dump(rows, fh, indent=1)
    print(summarise(rows))
    return 0


if __name__ == '__main__':
    sys.exit(main())

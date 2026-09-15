#!/usr/bin/env python3
"""GH #822 -- repairing LIMIT A by DIVISION, and the three ways that goes wrong.

WHAT CHANGED AND WHY (replay-check 2026-09-15T00:xxZ, handoff item (2))
-----------------------------------------------------------------------
`ability_exhaustion_split.py` excluded every LINKED body from `banked` as
LIMIT A ("inflated visible count, NOT repaired by `free`").  On W40 that was
all 35 nevermore rows -- 12% of the band -- and it left the one question the
exclusion raised unanswerable: is nevermore stalling like the other nine, or
is it only the instrument that is broken there?

The repair is DIVISION, not subtraction.  A linked group rises as ONE ability,
so the points ever put into it equal the COMMON rank:

    spent = sum(visible) - group_sum + group_sum // len(group) - innate
    banked = level - spent - #{tiers reached}

`free` could not do this because it is a CONSTANT read at level 1 (2 ranks for
nevermore) while the inflation GROWS with every further point -- 4 points into
a group of 3 shows 12 visible ranks, of which 8 are inflation, not 2.

Measured on the same 8 W40 games (cut travels with the number, iron rule
4(iii): band 18-22, skipped-alive rows, body = longest-lived idx per name):
PROVEN 229 -> 264, the LIMIT-A bucket 29 -> 0, the `banked == 0` bucket 6 -> 0.
All 35 recovered rows are nevermore, all carry an unbought `nevermore_frenzy`
rank (corpus_max 4), and deflated banked runs 3..6 (3:8 4:15 5:6 6:6).

⭐ THE DIVISION IS ONLY LICENSED BY LOCKSTEP, AND THAT IS THE POINT OF THIS
FILE.  `group_sum // size` is a rank only while every member holds the same
rank on every frame.  Read off W40: 8/8 nevermore bodies, group size 3,
frames-with-unequal-ranks 0 -- so the licence was BOUGHT there, not assumed.
But a corpus that agrees with a rule does not certify the rule (the same trap
that let mutant M2 survive in test_exhaustion_free_correction.py), so the
refusal path is separated here on a synthetic body that breaks lockstep.

⛔ WHAT IS NOT ASSERTED HERE.  The W40 numbers are a MEASUREMENT on a corpus
that lives in S3, not in this tree; this file asserts the ARITHMETIC, the
DIRECTION, and the REFUSAL on synthetic bodies.  Frame evidence (slot1
nevermore idx=1352: group 1->4 in lockstep at t=-59.9/82.1/168.1/270.1, then a
579s spend silence t=750.1 lvl14 -> t=1329.1 lvl23) is in
iterations/reports/replay-check/20260915T0*.md §2.

⚠️ THE `innate` TERM IS UNEXERCISED BY W40.  No nevermore there carries an
innate, so `linked_group()`'s second return value was 0 on all 8 bodies.  It is
asserted below on a synthetic body and must NOT be cited as measured.

[ratchet] [bug]
"""
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
BEHAV = os.path.abspath(os.path.join(HERE, '..', 'tools', 'batch_test', 'behavioral'))
sys.path.insert(0, BEHAV)

import ability_exhaustion_split as AE  # noqa: E402

ok = True


def chk(msg, cond):
    global ok
    ok = ok and bool(cond)
    print('%s %s' % ('PASS' if cond else 'FAIL', msg))


def body(hero, idx, ledger_by_level, top=23, prespend=None):
    """One body; two frames per level so a level can be complete with no movement."""
    out, cur = [], {}
    if prespend is not None:
        out.append(dict(hero=hero, idx=idx, t=-1.0, level=1, hp_pct=0.8,
                        abilities=[dict(name=n, level=v) for n, v in sorted(prespend.items())]))
    for lvl in range(1, top + 1):
        cur = dict(cur, **ledger_by_level.get(lvl, {}))
        for k in range(2):
            out.append(dict(hero=hero, idx=idx, t=float(lvl * 100 + k), level=lvl,
                            hp_pct=0.8,
                            abilities=[dict(name=n, level=v) for n, v in sorted(cur.items())]))
    return out


def write_game(path, *bodies):
    json.dump(dict(snapshots=[s for b in bodies for s in b]), open(path, 'w'))
    return path


# LINKED: three rows rise together on every point into the group, then stall.
# 4 points into the group -> 12 visible ranks, of which 8 are inflation.
#
# ⭐ THIS LEDGER IS THE REAL ONE, TRANSCRIBED.  It mirrors W40 slot1 nevermore
# idx=1352 level for level (group at 1/3/5/7, presence at 2/4/6/8, requiem 9/12,
# frenzy 11/13/14, then the 579s silence, then frenzy 3->4 at level 23).  That
# is deliberate: a body calibrated by eye stalls HARDER than the real one and
# would have asserted `banked_free <= 0` off a shape that does not occur.  On
# this ledger the in-band arithmetic reproduces the replay bit for bit --
# visible 21, spent 13, banked 3 at level 18, banked_free -3 -- so the two
# readings this file separates are the two readings the corpus actually shows.
LINKED = {1: {'beta_r1': 1, 'beta_r2': 1, 'beta_r3': 1}, 2: {'beta_w': 1},
          3: {'beta_r1': 2, 'beta_r2': 2, 'beta_r3': 2}, 4: {'beta_w': 2},
          5: {'beta_r1': 3, 'beta_r2': 3, 'beta_r3': 3}, 6: {'beta_w': 3},
          7: {'beta_r1': 4, 'beta_r2': 4, 'beta_r3': 4}, 8: {'beta_w': 4},
          9: {'beta_e': 1}, 11: {'beta_f': 1}, 12: {'beta_e': 2},
          13: {'beta_f': 2}, 14: {'beta_f': 3},
          # ...the silence: levels 15-22 complete with no movement...
          23: {'beta_f': 4}}          # the hold ENDS here -> beta_f is BASIC
# INNATE: one row stands from the first frame and never moves again.
INNATE = {1: {'alpha_inn': 1, 'alpha_q': 1}, 2: {'alpha_q': 2}, 3: {'alpha_q': 3},
          4: {'alpha_q': 4}, 5: {'alpha_w': 1}}
# NOT LOCKSTEP: the members separate at level 3.  Same level-1 shape, so
# is_linked() still says True -- only the lockstep check can tell them apart.
UNEVEN = {1: {'beta_r1': 1, 'beta_r2': 1, 'beta_r3': 1},
          2: {'beta_r1': 2, 'beta_r2': 2, 'beta_r3': 2},
          3: {'beta_r1': 3, 'beta_r2': 3},
          4: {'beta_r3': 3}}

lk = body('npc_dota_hero_beta', 22, LINKED, top=24, prespend={})
inn = body('npc_dota_hero_alpha', 11, INNATE, prespend={'alpha_inn': 1})
uneven = body('npc_dota_hero_beta', 22, UNEVEN, prespend={})

print('--- linked_group: WHICH rows, and how many ranks the engine gave away')
g, innate = AE.linked_group(lk)
chk('a linked body returns its three member names',
    g == {'beta_r1', 'beta_r2', 'beta_r3'})
chk('...and innate=0 when nothing else stands at level 1 (the W40 shape)',
    innate == 0)
chk('an innate carrier is NOT a group -> (None, 0)', AE.linked_group(inn) == (None, 0))
# ⭐ THIS BODY EXISTS BECAUSE A MUTANT SURVIVED.  Replacing the innate sum with
# a literal 0 left every check green: the W40-shaped bodies all carry innate=0,
# and the only other exercise of the term passed it in BY HAND to
# deflated_spent(), so nothing ever asserted that linked_group() COMPUTES it.
# A corpus where the right answer is 0 cannot tell a correct sum from a zero.
lk_inn = body('npc_dota_hero_delta', 44, {1: {'d_r1': 1, 'd_r2': 1, 'd_inn': 1},
                                          2: {'d_r1': 2, 'd_r2': 2},
                                          3: {'d_r1': 3, 'd_r2': 3}},
              prespend={'d_inn': 1})
chk('⭐ a body carrying BOTH a linked group and an innate reports the group AND '
    'innate=1: the standing row that never moves is the engine\'s gift, and it '
    'is counted by SUMMING the non-group standing ranks, not assumed to be 0',
    AE.linked_group(lk_inn) == ({'d_r1', 'd_r2'}, 1))
chk('a body with no level-1 window -> (None, 0), never a guess',
    AE.linked_group([f for f in lk if f['level'] > 1]) == (None, 0))

print('\n--- ⭐ the refusal: no lockstep, no licence to divide')
chk('is_linked STILL says True on the uneven body -- it only looks at level 1, '
    'so it cannot be the thing that licenses the division',
    AE.is_linked(uneven) is True)
chk('⭐ linked_group REFUSES it -> (None, 0): group_sum/size is not a rank when '
    'the members disagree, so the body stays an excluded LIMIT A row, which is '
    'the CONSERVATIVE outcome (under-report, never over-report)',
    AE.linked_group(uneven) == (None, 0))

print('\n--- deflated_spent: the arithmetic, on the rank that breaks `free`')
chk('group of 3 at rank 4 (+ one 3-rank solo) costs 4+3=7 points, not the 15 '
    'visible ranks and not the 13 that level-1 `free` would leave',
    AE.deflated_spent({'beta_r1': 4, 'beta_r2': 4, 'beta_r3': 4, 'beta_w': 3},
                      {'beta_r1', 'beta_r2', 'beta_r3'}, 0) == 7)
chk('at rank 1 the two corrections AGREE (3 visible, 1 point) -- which is why '
    'the level-1 reading looked sound and why the gap only opens later',
    AE.deflated_spent({'beta_r1': 1, 'beta_r2': 1, 'beta_r3': 1},
                      {'beta_r1', 'beta_r2', 'beta_r3'}, 0) == 1)
chk('⚠️ the innate term subtracts on top of the division (UNEXERCISED by W40)',
    AE.deflated_spent({'beta_r1': 2, 'beta_r2': 2, 'beta_r3': 2, 'b_inn': 1},
                      {'beta_r1', 'beta_r2', 'beta_r3'}, 1) == 2)

print('\n--- ⭐ direction: deflation can ADD a PROVEN row, never retract one')
bad = []
for rank in range(1, 5):
    for size in (2, 3, 4):
        led = {'r%d' % i: rank for i in range(size)}
        free_only = sum(led.values()) - (size - 1)      # level-1 free = size-1
        if AE.deflated_spent(led, set(led), 0) > free_only:
            bad.append((rank, size))
chk('over every rank 1..4 x group size 2..4, deflated spent <= the free-only '
    'spent, so banked only RISES: %s' % ('none higher' if not bad else bad),
    not bad)
chk('...and the gap GROWS with rank, which is LIMIT A verbatim: at rank 4 a '
    'group of 3 is 8 ranks inflated while `free` buys back only 2',
    AE.deflated_spent({'a': 4, 'b': 4, 'c': 4}, {'a', 'b', 'c'}, 0) == 4
    and (12 - 2) - 4 == 6)

print('\n--- end to end: a stalling linked body is PROVEN, and was not before')
with tempfile.TemporaryDirectory() as d:
    g1 = write_game(os.path.join(d, 'g1.timeline.json'), lk)
    rows, _, _, basic, nowindow = AE.scan([g1], 18, 22)
    chk('the group is recorded on every row (so a reader can re-derive the cut)',
        rows and all(r['group'] == ['beta_r1', 'beta_r2', 'beta_r3'] for r in rows))
    chk('the band is the silence: one row per level 18..22 minus the top level',
        sorted(r['level'] for r in rows) == [18, 19, 20, 21, 22])
    chk('⭐ the in-band arithmetic reproduces the replay body bit for bit: '
        'visible 21, spent 13, and banked 3 at level 18',
        all(r['visible'] == 21 and r['spent'] == 13 for r in rows)
        and [r for r in rows if r['level'] == 18][0]['banked'] == 3)
    chk('⭐ under the free-only term no row cleared 0: -3,-2,-2,-1,0 over '
        'levels 18..22, so every one was excluded and nevermore could not be '
        'asked about at all',
        [r['banked_free'] for r in sorted(rows, key=lambda r: r['level'])]
        == [-3, -2, -2, -1, 0])
    chk('⭐⭐ and the level-22 row lands on exactly 0 -- the SILENT MISLABEL: '
        'the free term walks a still-inflated row into a bucket whose label '
        'reads "tiers exactly account".  This is the synthetic twin of the 6 '
        'such rows measured on W40, and the reason a sign test alone is unsafe',
        sum(1 for r in rows if r['banked_free'] == 0) == 1
        and sum(1 for r in rows if r['banked_free'] < 0) == 4)
    chk('⭐ under deflation every row reads banked > 0: a point provably in hand',
        rows and all(r['banked'] > 0 for r in rows))
    chk('...and the rows become PROVEN, because beta_f is bought to rank 4 at '
        'level 23 -- so it is BASIC, and in-band it sits at 3, one rank unbought',
        rows and all(r['banked'] > 0 and r['deficit'] > 0 for r in rows)
        and all(r['gaps'] == {'beta_f': 1} for r in rows))
    chk('the two readings are BOTH carried on the row, so the pre-repair number '
        'stays auditable next to the repaired one (iron rule 4(iii))',
        all('banked_free' in r and 'banked_raw' in r and 'spent' in r for r in rows))
    chk('no level-1 window went unreported', nowindow == [])

    print('\n--- an unlocked-lockstep body keeps the OLD, excluded behaviour')
    g2 = write_game(os.path.join(d, 'g2.timeline.json'), uneven)
    rows2, _, _, _, _ = AE.scan([g2], 18, 22)
    chk('it carries no group, so `free` is what applies and it stays excluded '
        '(banked <= 0) rather than being laundered into PROVEN',
        rows2 and all(r['group'] == [] and r['banked'] == r['banked_free'] for r in rows2))

    print('\n--- an INNATE body is untouched by any of this')
    g3 = write_game(os.path.join(d, 'g3.timeline.json'), inn)
    rows3, _, _, _, _ = AE.scan([g3], 18, 22)
    chk('innate rows still use `visible - free`, bit-identical to before',
        rows3 and all(r['group'] == [] and r['spent'] == r['visible'] - r['free']
                      for r in rows3))

print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
sys.exit(0 if ok else 1)

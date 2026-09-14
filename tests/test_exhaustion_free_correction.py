#!/usr/bin/env python3
"""GH #822 -- the `free` term in `banked`, and the detector it must not disarm.

WHAT CHANGED AND WHY (replay-check 2026-09-14T21:xxZ, handoff item (2))
-----------------------------------------------------------------------
`ability_exhaustion_split.py` computed

    banked = level - sum(visible ability ranks) - #{tiers reached}

and charged the hero for ranks the ENGINE handed out free (innate rows since
7.36; the extra members of a linked group).  The 2026-09-14T18:45Z round bought
that fact off the frames (`free_rank_census.py`) and its handoff asked for the
correction to be fed back.  It now reads

    banked = level - (sum(visible) - free) - #{tiers reached}

with `free` a LOWER bound read at hero level 1, where exactly one point has been
granted.  Direction is the whole argument: free >= 0, so banked only RISES, so
GH #822's `PROVEN 229` was a lower bound before and stays one after.  Measured
on the same 8 W40 games: PROVEN 229 -> 229, INDETERMINATE 18 -> 18, and the
LIMIT-A bucket 35 -> 29.

⭐ THE TRAP THIS FILE EXISTS TO NAIL.  Those 6 rows did not become correct --
they slid from `banked < 0` into `banked == 0`, a bucket whose label reads
"tiers exactly account".  On a LINKED body the inflation grows with every point
into the group (3 points -> 9 visible ranks), so level-1 `free` buys back 2 of
nevermore's ranks and no more; banked <= 0 there still means "inflated".  Left
alone, the correction would have quietly TRADED a loud detector for a silent
mislabel on exactly the bodies it could not repair.  `is_linked()` is the
sign-free replacement, and it recovered all 35 rows on W40 -- bit-identical to
the pre-correction LIMIT-A set, all nevermore, none of them PROVEN.

⛔ WHAT IS NOT ASSERTED HERE.  The W40 numbers above are a MEASUREMENT on a
corpus that lives in S3, not in this tree (the .dem set is 180MB); this file
asserts the ARITHMETIC and the DISCRIMINATOR on synthetic bodies that separate
the rules, per evidence-discipline rule 2.  Frame evidence for both shapes is
in iterations/reports/replay-check/20260914T214xxxZ.md §2.

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
    """One body: level L holds the cumulative ledger `ledger_by_level[L]`.

    Two frames per level so a level can be 'complete with no movement'.

    ⭐ `prespend` prepends ONE level-1 frame holding the ledger as it stood
    BEFORE the first point was spent.  That is the real shape -- W40 slot1 has
    vengeful_spirit at t=-68.9 with revenge alone, then t=-59.9 with
    wave_of_terror added; nevermore at t=-66.9 with an EMPTY ledger, then
    t=-59.9 with all three shadowrazes at 1.  It is also the only thing that
    separates `max` from `min` over the level-1 window, which is why a body
    without it let mutant M2 survive.
    """
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
    snaps = [s for b in bodies for s in b]
    json.dump(dict(snapshots=snaps), open(path, 'w'))
    return path


# --- the two shapes, as bodies -------------------------------------------
# INNATE: 'inn' stands at rank 1 from the first frame and never moves again.
INNATE = {1: {'alpha_inn': 1, 'alpha_q': 1}, 2: {'alpha_q': 2}, 3: {'alpha_q': 3},
          4: {'alpha_q': 4}, 5: {'alpha_w': 1}}          # then stalls: 6..23 nothing
INNATE_SPENDER = dict(INNATE)
INNATE_SPENDER.update({6: {'alpha_w': 2}, 7: {'alpha_w': 3}, 8: {'alpha_w': 4}})
# LINKED: three rows rise together on every point into the group.
LINKED = {1: {'beta_r1': 1, 'beta_r2': 1, 'beta_r3': 1},
          2: {'beta_r1': 2, 'beta_r2': 2, 'beta_r3': 2},
          3: {'beta_r1': 3, 'beta_r2': 3, 'beta_r3': 3},
          4: {'beta_r1': 4, 'beta_r2': 4, 'beta_r3': 4}}  # then stalls

print('--- free_ranks: read at hero level 1, a LOWER bound, never a guess')
inn = body('npc_dota_hero_alpha', 11, INNATE, prespend={'alpha_inn': 1})
chk('an innate carrier reads free=1 (2 visible ranks, 1 point granted)',
    AE.free_ranks(inn) == (1, True))
chk('⭐ it is the MAX over the level-1 window: the pre-spend frame (innate '
    'alone) is in that window too, and reading it instead would zero the '
    'correction on exactly the bodies that need it',
    AE.free_ranks([f for f in inn if f['t'] < 0]) == (0, True)
    and AE.free_ranks(inn)[0] == 1)
chk('a linked group of 3 reads free=2 -- same instrument, no table of innates',
    AE.free_ranks(body('npc_dota_hero_beta', 22, LINKED, prespend={})) == (2, True))
chk('a body with no free rank reads free=0',
    AE.free_ranks(body('npc_dota_hero_gamma', 33, {1: {'g_q': 1}, 2: {'g_q': 2}}))
    == (0, True))
chk('NO level-1 window -> (0, False): 0 is a valid lower bound AND the caller '
    'is told it was missing, so it can register instead of pooling',
    AE.free_ranks([f for f in inn if f['level'] > 1]) == (0, False))

print('\n--- is_linked: the sign-free detector, separated on synthetic bodies')
chk('linked body: two or more level-1 rows move later -> True',
    AE.is_linked(body('npc_dota_hero_beta', 22, LINKED, prespend={})) is True)
chk('innate body: exactly one level-1 row moves later -> False', AE.is_linked(inn) is False)
chk('⭐ the discriminator is the LATER movement, not the level-1 count: an '
    'innate carrier whose bought row is one of TWO standing rows is still '
    'not linked',
    AE.is_linked(body('npc_dota_hero_alpha', 11, INNATE_SPENDER,
                      prespend={'alpha_inn': 1})) is False)
chk('a linked body truncated before the group ever moves again cannot be '
    'called linked -- the tool refuses rather than guessing',
    AE.is_linked([f for f in body('npc_dota_hero_beta', 22, LINKED) if f['level'] <= 1])
    is False)

print('\n--- end to end: the correction raises banked and retracts nothing')
with tempfile.TemporaryDirectory() as d:
    g1 = write_game(os.path.join(d, 'g1.timeline.json'),
                    body('npc_dota_hero_alpha', 11, INNATE, prespend={'alpha_inn': 1}),
                    body('npc_dota_hero_beta', 22, LINKED, prespend={}))
    g2 = write_game(os.path.join(d, 'g2.timeline.json'),
                    body('npc_dota_hero_alpha', 11, INNATE_SPENDER,
                         prespend={'alpha_inn': 1}))
    rows, releases, corpus, basic, nowindow = AE.scan([g1, g2])

    a18 = [r for r in rows if r['hero'] == 'alpha' and r['level'] == 18
           and r['game'] == 'g1'][0]
    chk('alpha@18 visible=6 (inn 1 + q 4 + w 1), free=1, tiers 10/15 reached',
        (a18['visible'], a18['free'], a18['linked']) == (6, 1, False))
    chk('banked_raw = 18 - 6 - 2 = 10 (the pre-GH#822 arithmetic, kept for audit)',
        a18['banked_raw'] == 10)
    chk('banked     = 18 - (6-1) - 2 = 11 -- the innate rank is no longer '
        'charged to the hero', a18['banked'] == 11)
    chk('every row: banked >= banked_raw, so no PROVEN row can be retracted '
        'by the correction', all(r['banked'] >= r['banked_raw'] for r in rows))
    chk('alpha@18 is PROVEN: a point in hand AND alpha_w unbought at corpus-max 4',
        a18['banked'] > 0 and a18['deficit'] == 3 and corpus['alpha_w'] == 4)

    linked_rows = [r for r in rows if r['linked']]
    chk('the linked body contributes rows in the band', len(linked_rows) > 0)
    chk('⛔ every row the OLD sign detector caught is still caught by is_linked '
        '-- this is the W40 property (35 -> 29 by sign, 35 by linkage) held on '
        'synthetic data',
        all(r['linked'] for r in rows if r['banked_raw'] < 0))
    chk('and the linked rows are NOT laundered into PROVEN by the correction',
        not any(r['linked'] and r['banked'] > 0 and r['deficit'] > 0 for r in rows))
    chk('bodies with no level-1 window are reported, not silently pooled',
        nowindow == [])

    print('\n--- the body rule (LIMIT E): longest-lived, never first-appearance')
    illusion = body('npc_dota_hero_alpha', 5, {1: {'alpha_q': 1}}, top=2)
    for f in illusion:            # an illusion: lower idx, frozen ledger, short life
        f['level'] = 12
    real = body('npc_dota_hero_alpha', 11, INNATE, prespend={'alpha_inn': 1})
    g3 = write_game(os.path.join(d, 'g3.timeline.json'), illusion, real)
    chosen, per = AE.bodies(g3)
    chk('the hero body is chosen over an illusion that appears FIRST at a '
        'lower idx (the reading `min(idx)` and `first appearance` both get '
        'wrong once an illusion leads)',
        chosen['npc_dota_hero_alpha'] == 11
        and len(per['npc_dota_hero_alpha']) == len(real))

print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
sys.exit(0 if ok else 1)

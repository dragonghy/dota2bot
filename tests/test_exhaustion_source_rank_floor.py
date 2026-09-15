#!/usr/bin/env python3
"""GH #822 -- the corpus-max blind spot, and why the repair must read SOURCE.

WHAT CHANGED AND WHY (replay-check 2026-09-15T0x:xxZ, handoff item (2))
-----------------------------------------------------------------------
`ability_exhaustion_split.py` classified a skipped-alive row PROVEN only when a
BASIC ability sat below its max, and it estimated max rank by CORPUS-MAX: the
highest rank the name reaches anywhere in the games passed to the run.  That
estimator is blinded by exactly the pathology it exists to detect.  An ability
that no body in the corpus ever trains has corpus-max equal to its STALLED
value, so its gap is 0 by construction and it can never carry a proof.

On W40 that hero is obsidian_destroyer, and the blindness was TOTAL: all 18 of
the tool's INDETERMINATE rows were OD rows, and every OD row was INDETERMINATE
(OD 0 PROVEN / 18 not).  OD's ledger sits at arcane_orb 1, astral 4,
objurgation 0, sanity_eclipse 1 -- corpus-max 1 / 4 / 0 / 1 -- so only astral
counted as BASIC, and astral is the one ability that IS maxed.

The repair reads the bound OFF THE REPO instead of off the batch, and it is
two independent sources agreeing:
  * WHICH abilities are basics -- tests/mock/hero_slots.lua (GENERATED from the
    game's own npc_heroes.txt), slots 0,1,2.
  * HOW MANY ranks a basic has -- the hero's own build row spends 4+4+4+3 over
    four distinct indices, so three of its abilities have >= 4 ranks.  Same
    arithmetic as the OD file's own promote argument, condition (c).

Measured on the same 8 W40 games (cut travels with the number, iron rule
4(iii): band 18-22, skipped-alive rows, body = longest-lived idx per name):
PROVEN 264 -> 282, INDETERMINATE 18 -> 0, and the other nine heroes' per-hero
counts are BYTE-IDENTICAL (35/34/33/32/31/27/27/26/19).  Two names are lifted:
obsidian_destroyer_arcane_orb (corpus-max 1 -> 4) and _objurgation (0 -> 4).

⭐ THE DIRECTION ARGUMENT IS THE WHOLE LICENCE, and it is asserted below rather
than described.  A floor is a LOWER bound on true max rank; the caller takes
max(corpus_max, floor), a max of two lower bounds, hence still a lower bound.
So eff-max only RISES, the BASIC set only GROWS, every gap only WIDENS, and
deficit only increases.  ⇒ the term can ADD PROVEN rows and can NEVER retract
one.  Every number GH #822 published under corpus-max alone survives it.

⛔ WHAT IS NOT ASSERTED HERE.  The W40 numbers are a MEASUREMENT on a corpus
that lives in S3, not in this tree; this file asserts the GUARDS, the
DIRECTION, and the REFUSAL paths on synthetic bodies plus the real shipped
source files.  Frame evidence (slot1 OD idx=1462, t=1428.1, hero level 19,
hp_pct 0.996, ledger arcane_orb 1 / astral 4 / objurgation 0 / sanity 1) is in
iterations/reports/replay-check/20260915T0*.md.

⚠️ THE GUARDS ARE THE POINT.  A floor that fires when it should not would
INVENT a rank and manufacture PROVEN rows -- the one direction the argument
above does not protect.  So each of the three guards gets its own refusal test,
and refusal returns {} (no floor, corpus-max stands alone), never a guess.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), 'tools', 'batch_test', 'behavioral'))
import ability_exhaustion_split as AE  # noqa: E402

ok = True


def chk(name, cond, detail=''):
    global ok
    if not cond:
        ok = False
    print('%s %s%s' % ('PASS' if cond else 'FAIL', name,
                       ('  [%s]' % detail) if detail and not cond else ''))


OD = 'obsidian_destroyer'
OD_BASICS = {'obsidian_destroyer_arcane_orb': 4,
             'obsidian_destroyer_astral_imprisonment': 4,
             'obsidian_destroyer_objurgation': 4}
OD_LEDGER = set(OD_BASICS) | {'obsidian_destroyer_sanity_eclipse'}

print('--- the two SHIPPED sources this reads (not a table typed from memory)')
slots = AE._slot_rows()
chk('tests/mock/hero_slots.lua parses and carries the roster',
    len(slots) > 50, 'got %d heroes' % len(slots))
chk('OD slots 0,1,2 are its three basics, verbatim from npc_heroes.txt',
    [slots[OD].get(i) for i in (0, 1, 2)] == list(
        ['obsidian_destroyer_arcane_orb',
         'obsidian_destroyer_astral_imprisonment',
         'obsidian_destroyer_objurgation']),
    str([slots[OD].get(i) for i in (0, 1, 2)]))
chk('OD slot 3 is the generic_hidden placeholder the shipped row aimed at',
    slots[OD].get(3) == 'generic_hidden', str(slots[OD].get(3)))

rows = AE._build_rows(OD)
chk('OD ships TWO ability build rows (shipped + turbo override)',
    len(rows) == 2, str(rows))
from collections import Counter  # noqa: E402
ms = {tuple(sorted(Counter(r).values(), reverse=True)) for r in rows}
chk('BOTH rows give the same count multiset (4,4,4,3), so the floor does not '
    'depend on which row runs in turbo', ms == {(4, 4, 4, 3)}, str(ms))

print('\n--- the floor itself')
chk('OD gets a floor of 4 on exactly its three slot-0..2 basics',
    AE.rank_floor(OD, OD_LEDGER, slots) == OD_BASICS,
    str(AE.rank_floor(OD, OD_LEDGER, slots)))
chk('the ULTIMATE is deliberately NOT floored (LIMIT F: the proof rests on '
    'basics alone, as it did before)',
    'obsidian_destroyer_sanity_eclipse' not in AE.rank_floor(OD, OD_LEDGER, slots))

print('\n--- guard (1): the slot row must name exactly 3 real basics')
# ⭐ THESE TWO SYNTHETIC HEROES DO NOT TEST GUARD (1) AND ARE KEPT TO SAY SO.
# Neither has a BotLib file, so guard (2) refuses them first: the mutation
# stand killed `if len(basics) != 3:` -> `if False:` NOWHERE, and these were
# the checks that were supposed to catch it.  A refusal reached for the wrong
# reason looks exactly like the right one.
fake = dict(slots)
fake['ghost_hero'] = {0: '', 1: '', 2: '', 3: 'x_ult'}
chk('a hero whose slots 0-2 are empty is refused (⚠️ by guard 2, not guard 1 '
    '-- it has no BotLib row either)',
    AE.rank_floor('ghost_hero', {'x_ult'}, fake) == {})
fake['half_hero'] = {0: 'h_a', 1: 'generic_hidden', 2: 'h_c'}
chk('generic_hidden at slot 1 leaves only 2 real basics (⚠️ same caveat)',
    AE.rank_floor('half_hero', {'h_a', 'h_c'}, fake) == {})

# ⭐ THE REAL GUARD-(1) DISCRIMINATOR, and it is a SHIPPED hero: morphling has
# a BotLib file whose rows DO spend 4+4+4+3, so guards (2) and (3) both pass
# -- but its slot 2 is `generic_hidden`, leaving only two real basics.  Only
# guard (1) can refuse it, so this check is the one that kills the mutant.
MORPH_LOW = [slots['morphling'].get(i, '') for i in (0, 1, 2)]
chk('morphling really is the shipped shape this needs: slots 0-2 carry a '
    'generic_hidden, and its build rows really are (4,4,4,3)',
    MORPH_LOW[2] == 'generic_hidden'
    and {tuple(sorted(Counter(r).values(), reverse=True))
         for r in AE._build_rows('morphling')} == {(4, 4, 4, 3)}, str(MORPH_LOW))
chk('⭐ morphling is REFUSED with only 2 real basics, though guards (2) and '
    '(3) would both pass -- a floor is never handed to a hero whose third '
    'basic the slot row cannot name',
    AE.rank_floor('morphling',
                  {n for n in MORPH_LOW if n} | {'morphling_replicate'},
                  slots) == {},
    str(AE.rank_floor('morphling', {n for n in MORPH_LOW if n}, slots)))

# ⭐ AND THE OTHER HALF OF GUARD (1): the window is slots 0,1,2 -- widening it
# to 0..3 would sweep in a fourth REAL ability on most of the roster.  OD
# cannot show this (its slot 3 is the placeholder, filtered either way), which
# is why the stand saw the widened mutant survive.
ABA = [slots['abaddon'].get(i, '') for i in (0, 1, 2)]
chk('abaddon is the shape OD cannot provide: slots 0-2 are three real basics '
    'AND slot 3 is a real ability too',
    len([n for n in ABA if n and n != 'generic_hidden']) == 3
    and slots['abaddon'].get(3) == 'abaddon_withering_mist', str(ABA))
chk('⭐ abaddon is floored on exactly its THREE slot-0..2 basics -- slot 3 is '
    'outside the window, not merely filtered',
    AE.rank_floor('abaddon', set(ABA) | {'abaddon_withering_mist',
                                         'abaddon_borrowed_time'}, slots)
    == {n: 4 for n in ABA},
    str(AE.rank_floor('abaddon', set(ABA) | {'abaddon_withering_mist'}, slots)))

print('\n--- name canon: the dump name and the slot key disagree for VS')
chk('the corpus calls it `vengeful_spirit` and hero_slots.lua keys it '
    '`vengefulspirit`; the KEY lookup now follows the same canon _build_rows '
    'uses, so the slot row resolves instead of missing',
    AE.rank_floor('vengeful_spirit',
                  {'vengefulspirit_magic_missile',
                   'vengefulspirit_wave_of_terror',
                   'vengefulspirit_command_aura'}, slots)
    == {'vengefulspirit_magic_missile': 4,
        'vengefulspirit_wave_of_terror': 4,
        'vengefulspirit_command_aura': 4},
    str(AE.rank_floor('vengeful_spirit', set(), slots)))
# ⛔ LIMIT G, AND THE CANON FIX DOES **NOT** REMOVE IT.  The underscore split
# runs through the ABILITY NAMES too: the slot map says
# `vengefulspirit_command_aura` while the dumper says
# `vengeful_spirit_command_aura`.  So VS resolves its row and is then refused
# by guard (3), and is STILL unfloorable on a real corpus.  Asserted here so
# nobody reads the line above as "VS is fixed".  It costs no W40 number (VS is
# already 34/34 PROVEN off corpus-max); it would matter on a corpus where a VS
# basic goes untrained.
VS_DUMP = {'vengeful_spirit_magic_missile', 'vengeful_spirit_wave_of_terror',
           'vengeful_spirit_command_aura', 'vengeful_spirit_nether_swap'}
chk('⛔ LIMIT G: on the REAL dump spelling VS is still refused (guard 3) -- '
    'the key canon is fixed, the ability-name canon is NOT',
    AE.rank_floor('vengeful_spirit', VS_DUMP, slots) == {},
    str(AE.rank_floor('vengeful_spirit', VS_DUMP, slots)))

print('\n--- guard (2): every build row must spend 4+4+4+3')
chk('a hero with no BotLib build row at all is REFUSED',
    AE.rank_floor('no_such_hero_at_all', OD_LEDGER, fake) == {})
saved = AE._build_rows
try:
    AE._build_rows = lambda short: [[1, 1, 1, 2, 2, 2, 3, 3, 3, 6, 6, 6]]
    chk('a 3+3+3+3 row (no four-point block) is REFUSED -- the floor of 4 is '
        'not licensed by it', AE.rank_floor(OD, OD_LEDGER, slots) == {})
    AE._build_rows = lambda short: [[2, 1, 3, 2, 2, 6, 2, 1, 1, 1, 6, 3, 3, 3, 6],
                                    [1, 1, 1, 2, 2, 2, 3, 3, 3, 6, 6, 6]]
    chk('ONE conforming row does not rescue a non-conforming sibling: ANY bad '
        'row refuses the whole hero', AE.rank_floor(OD, OD_LEDGER, slots) == {})
finally:
    AE._build_rows = saved
chk('the guard was restored (the stand did not leak into later checks)',
    AE.rank_floor(OD, OD_LEDGER, slots) == OD_BASICS)

print('\n--- guard (3): each basic must appear in THIS body\'s ledger')
chk('a body missing objurgation from its ledger is REFUSED whole, rather than '
    'flooring the two names it does carry',
    AE.rank_floor(OD, OD_LEDGER - {'obsidian_destroyer_objurgation'}, slots) == {})
chk('an EMPTY ledger is REFUSED', AE.rank_floor(OD, set(), slots) == {})

print('\n--- the direction: max of two LOWER bounds is a LOWER bound')
for corpus_max in range(0, 7):
    eff = max(corpus_max, 4)
    if not eff >= corpus_max:
        chk('eff-max >= corpus-max at corpus_max=%d' % corpus_max, False)
chk('eff-max >= corpus-max for every corpus-max 0..6, so the BASIC set only '
    'grows and no gap can shrink',
    all(max(c, 4) >= c for c in range(0, 7)))
chk('an ability ALREADY at or above the floor is left bit-identical '
    '(astral corpus-max 4 -> eff 4), so lifting is confined to blind names',
    max(4, OD_BASICS['obsidian_destroyer_astral_imprisonment']) == 4)
chk('a gap can only WIDEN: for visible rank v, eff-gap >= corpus-gap',
    all(max(0, max(c, 4) - v) >= max(0, c - v)
        for c in range(0, 7) for v in range(0, 7)))

print('\n--- the OD arithmetic this was built to answer, on the pinned ledger')
led = {'obsidian_destroyer_arcane_orb': 1,
       'obsidian_destroyer_astral_imprisonment': 4,
       'obsidian_destroyer_objurgation': 0,
       'obsidian_destroyer_sanity_eclipse': 1}
corpus = {'obsidian_destroyer_arcane_orb': 1,
          'obsidian_destroyer_astral_imprisonment': 4,
          'obsidian_destroyer_objurgation': 0,
          'obsidian_destroyer_sanity_eclipse': 1}
floor = AE.rank_floor(OD, set(led), slots)
eff = {n: max(corpus[n], floor.get(n, 0)) for n in led}
basic = {n for n, v in eff.items() if v >= 4}
old_basic = {n for n, v in corpus.items() if v >= 4}
chk('under corpus-max ONLY astral is BASIC, and astral is the one maxed '
    'ability -> deficit 0 -> INDETERMINATE, which is the bug',
    old_basic == {'obsidian_destroyer_astral_imprisonment'}
    and sum(max(0, corpus[n] - led[n]) for n in old_basic) == 0)
chk('under the floor all three basics count, and the deficit is 3+0+4 = 7',
    basic == set(OD_BASICS)
    and sum(eff[n] - led[n] for n in basic if eff[n] > led[n]) == 7)
chk('7 > 0, so a body with banked > 0 on this ledger is PROVEN, not '
    'INDETERMINATE (the 18 W40 rows carried banked 10..13)',
    sum(eff[n] - led[n] for n in basic if eff[n] > led[n]) > 0)

print('\n--- the claim is robust to NOT knowing which ability is the ultimate')
# min over every choice of "which one of the four rows is the 3-rank ultimate",
# the other three being 4-rank basics.  Even the worst assignment proves a gap,
# so the conclusion does not rest on the slot table being right about WHICH.
worst = min(sum(max(0, 4 - led[n]) for n in led if n != ult) for ult in led)
chk('every assignment of the ultimate leaves a basic gap; the MINIMUM is 6 > 0',
    worst == 6, 'got %d' % worst)

print('\n--- end to end through scan(): the wiring, not just the floor')
# ⭐ THIS SECTION EXISTS BECAUSE rank_floor() BEING RIGHT PROVES NOTHING ABOUT
# THE TOOL.  The floor is consumed as max(corpus_max, floor) inside scan(), and
# a mutant that drops the max() -- or never calls rank_floor() at all -- leaves
# every assertion above green.  So the real OD ledger is replayed through the
# public entry point.
import json          # noqa: E402
import tempfile      # noqa: E402

# The pinned W40 body, transcribed: OD spends 6 points and stops at hero level
# 7 (astral 4 via the double-spend, arcane_orb 1, sanity 1), then stands still
# through the whole band.  objurgation never appears above 0.
OD_BY_LEVEL = {1: {'obsidian_destroyer_arcane_orb': 1,
                   'obsidian_destroyer_objurgation': 0,
                   'obsidian_destroyer_sanity_eclipse': 0,
                   'obsidian_destroyer_astral_imprisonment': 1},
               3: {'obsidian_destroyer_astral_imprisonment': 2},
               5: {'obsidian_destroyer_astral_imprisonment': 3},
               6: {'obsidian_destroyer_sanity_eclipse': 1},
               7: {'obsidian_destroyer_astral_imprisonment': 4}}


def od_body(top=23):
    out, cur = [], {}
    for lvl in range(1, top + 1):
        cur = dict(cur, **OD_BY_LEVEL.get(lvl, {}))
        for k in range(2):
            out.append(dict(hero='npc_dota_hero_obsidian_destroyer', idx=1462,
                            t=float(lvl * 100 + k), level=lvl, hp_pct=0.99,
                            abilities=[dict(name=n, level=v)
                                       for n, v in sorted(cur.items())]))
    return out


with tempfile.TemporaryDirectory() as d:
    p = os.path.join(d, 'od.timeline.json')
    json.dump(dict(snapshots=od_body()), open(p, 'w'))
    rows, _releases, eff, basic, nowindow, lifted = AE.scan([p], 18, 22)
    chk('the band is the stall: one row per level 18..22',
        sorted(r['level'] for r in rows) == [18, 19, 20, 21, 22],
        str(sorted(r['level'] for r in rows)))
    chk('scan() reports WHICH names the floor lifted, so a reader can re-derive '
        'the cut (iron rule 4(iii))',
        set(lifted) == {'obsidian_destroyer_arcane_orb',
                        'obsidian_destroyer_objurgation'}, str(lifted))
    chk('...and reports what each was lifted FROM: arcane_orb 1->4, '
        'objurgation 0->4',
        lifted.get('obsidian_destroyer_arcane_orb') == (1, 4)
        and lifted.get('obsidian_destroyer_objurgation') == (0, 4), str(lifted))
    chk('all three basics are now BASIC; the ultimate is not',
        basic == set(OD_BASICS), str(basic))
    chk('⭐ every row carries a deficit of 7 and banked > 0 -> all five are '
        'PROVEN, where under corpus-max alone all five were INDETERMINATE',
        rows and all(r['deficit'] == 7 and r['banked'] > 0 for r in rows),
        str([(r['level'], r['deficit'], r['banked']) for r in rows]))
    chk('the gap is carried by the two BLIND names, not by the maxed astral',
        rows and all(set(r['gaps']) == {'obsidian_destroyer_arcane_orb',
                                        'obsidian_destroyer_objurgation'}
                     for r in rows), str(rows[0]['gaps']) if rows else '')
    chk('no level-1 window went unreported', nowindow == [])
    chk('eff-max never falls below the corpus reading for a name the floor '
        'does not touch (astral stays 4)',
        eff['obsidian_destroyer_astral_imprisonment'] == 4)

    # ⭐ THE CONTROL. Same stall, same arithmetic, a hero the guards REFUSE:
    # the floor must NOT fire, and the rows must stay INDETERMINATE.  Without
    # this, "the floor fires" and "the floor fires on everything" look alike.
    ghost = [dict(s, hero='npc_dota_hero_not_a_real_hero_xyz') for s in od_body()]
    p2 = os.path.join(d, 'ghost.timeline.json')
    json.dump(dict(snapshots=ghost), open(p2, 'w'))
    rows2, _r2, _e2, basic2, _n2, lifted2 = AE.scan([p2], 18, 22)
    chk('⭐ an unknown hero gets NO floor, so its identical ledger stays '
        'INDETERMINATE (deficit 0) -- the floor is guarded, not global',
        lifted2 == {} and rows2 and all(r['deficit'] == 0 for r in rows2),
        str(lifted2))

    # ⭐ THE FLOOR IS A FLOOR, NOT AN ASSIGNMENT.  The stand showed
    # `eff[n] = max(eff[n], v)` -> `eff[n] = v` SURVIVING everything above,
    # because on W40 no floored name ever has corpus-max above 4, so the two
    # spellings agree on every reachable row.  That makes the max() defensive
    # code -- and defensive code that nothing exercises is how a lower bound
    # quietly becomes an over-write.  This body raises arcane_orb to 5 so the
    # two spellings finally disagree.
    # ⚠️ NOT A W40 SHAPE: no OD in the corpus trains arcane_orb past 1.  It
    # asserts the CONTRACT (never lower a corpus reading), not a measurement.
    hi5 = od_body()
    for s in hi5:
        for a in s['abilities']:
            if a['name'] == 'obsidian_destroyer_arcane_orb' and a['level'] >= 1:
                a['level'] = 5
    p3 = os.path.join(d, 'hi5.timeline.json')
    json.dump(dict(snapshots=hi5), open(p3, 'w'))
    _r3, _rel3, eff3, _b3, _n3, lifted3 = AE.scan([p3], 18, 22)
    chk('⭐ a corpus reading ABOVE the floor is kept (arcane_orb 5, not clamped '
        'down to the floor of 4) -- eff-max is max(), not the floor itself',
        eff3['obsidian_destroyer_arcane_orb'] == 5,
        str(eff3.get('obsidian_destroyer_arcane_orb')))
    chk('...and such a name is not reported as LIFTED, because the floor did '
        'not raise it', 'obsidian_destroyer_arcane_orb' not in lifted3,
        str(lifted3))

print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
sys.exit(0 if ok else 1)

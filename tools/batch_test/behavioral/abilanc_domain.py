#!/usr/bin/env python3
"""(a)-verification for soak candidate `abilanc` (GH #196, director ruling §BL).

WHAT `abilanc` DOES
-------------------
`J.GetMostHpUnit( unitList )` returns the highest-health unit of a sweep.  An
ancient creep is the biggest thing on the field, so "most HP" and "the ancient"
are the same answer whenever an ancient camp is inside the sweep.  Armed (turbo
only), a bot below `J.Site.ANCIENT_MIN_LEVEL` stops seeing ancient creeps as
that answer: the selector either returns the normal creep sharing the sweep, or
nil, and every call site already declines on nil.

The 19 consumers are hero ABILITY branches -- `bot:GetNearbyNeutralCreeps(...)`
handed straight to this selector, the returned handle cast at.  So the shipped
observable is **an ABILITY event whose TARGET is an ancient-camp creep, cast by
a hero below the tier**.  That is what this file counts.

WHY THIS FILE AND NOT `campfarm_target.py` (director §BL.3)
-----------------------------------------------------------
The application transcribed its (a) search domain as "the 10..11 band's `cast
at camp` column", and the director struck that: **the 10..11 band is
`campfarm`'s domain, not this id's.**  `abilanc`'s gate has no lower bound --
`jmz_func.lua:1850` reads `hSelf:GetLevel() < J.Site.ANCIENT_MIN_LEVEL` and
nothing else -- so its domain is `level < 12` ENTIRE, i.e. `under` + `band`.

The ruling called the fix zero-cost because `campfarm_target.py:473` already
loops `('under','band','over')`.  That is true of its EPISODE table and **false
of the `cast AT camp` column**, which loops `('band','over')` (`:505`): half the
mandated domain was not in any output.  Two further reasons this is its own
file rather than a third band in that one:

  1. `campfarm_target`'s `cast_at_camp` is a per-EPISODE flag -- an episode is
     built from hero<->ancient DAMAGE events, and the flag asks whether a cast
     happened inside its window.  `abilanc` edits a TARGETING call, so the
     event itself is the unit of observation; binding it to an episode adds an
     episode-membership filter that the gate knows nothing about.
  2. That file's `under` row is LABELLED `CONTROL -- <10 band (shipped filter
     already refuses; expect no move)`.  For `campfarm` that label is right.
     For `abilanc` it is exactly the reading §BL.3 boundary 1 forbids.  A label
     is an instruction to the reader; two ids cannot share one.

LEVEL AT THE CAST IS A STEP FUNCTION, SO IT IS BRACKETED, NEVER INTERPOLATED
---------------------------------------------------------------------------
`entities.interp` blends two samples.  Blending levels yields 10.4, and the
band test then answers about a level no hero ever had -- the same shape as the
`hp_pct` blend that GH #176 caught passing a corpse through an `hp > 0` filter.
Level only rises, so the honest read is the BRACKET: `lo` = last sample at or
before the cast, `hi` = first sample at or after it.  A cast is placed only
when the bracket does not straddle the tier:

    certain_under : hi <  ANCIENT_MIN_LEVEL     (both ends below)
    certain_over  : lo >= ANCIENT_MIN_LEVEL     (both ends at or above)
    straddle      : reported as its own row, never silently placed

At 1 Hz a straddle is a hero who levelled within a second of the cast.  Placing
those by `lo` would have been the convenient choice and would have inflated the
under-tier count on BOTH legs; the row is printed instead.

ENTITY HYGIENE
--------------
Levels come from `entities.frames_by_hero` (illusions and duplicate streams
dropped, GH #176).  An illusion cannot cast, but it CAN own the by-name frame
list that a naive level lookup would read.

WHAT THIS CANNOT SAY
--------------------
- **A residual armed cast is not automatically a bug.**  The comment block
  above `J.GetMostHpUnit` names what the id deliberately does not cover: 54
  `list[1]` reads, 14 centre-of-mass reads, and `J.GetMostHpUnitAnyTier`'s one
  caller (doom's devour).  Splash is a third: Zeus's static field fires on
  every cast and lands on whatever is nearby.  So residuals are printed
  hero-by-ability, for source-side adjudication -- this file refuses to call
  them bugs on its own.
- **The list is not in the dump.**  A hero standing at an ancient camp with the
  list filtered still shows up standing at an ancient camp.  Only his target
  moved.  WORKING therefore looks like "under-tier casts AT the camp fall while
  the >=12 casts do not", never like "ancient camps stop being fought".
- **Turbo levels fast.**  §BL.3 boundary 3 records the honest prior that the
  `under` (<10) band may simply be empty.  An empty band is a RESULT and is
  reported as one; it is not a reason to have skipped it.
"""
import argparse
import json
import math
import os
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from ancient_camp_domain import is_ancient, is_hero, load  # noqa: E402
from campfarm_target import (  # noqa: E402
    ANCIENT_MIN_LEVEL, R_SWEEP_MAX, SHIPPED_ANCIENT_MIN, WARMUP_GAMES,
    ANC_SUPPORT, NORM_SUPPORT, band_of, camp_samples, cluster, keep_supported)
from creeppull_domain import DIRE, RADIANT, load_sweep  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    '..', '..', '..'))
JMZ = os.path.join(REPO, 'bots', 'FunLib', 'jmz_func.lua')
BOTS = os.path.join(REPO, 'bots')

CAND = 'abilanc'
SELECTOR = 'J.GetMostHpUnit'
ANYTIER = 'J.GetMostHpUnitAnyTier'


# --------------------------------------------------------------------------
# source side -- every structural claim this file makes is read out of the Lua
# --------------------------------------------------------------------------
def _strip_comments(src):
    return '\n'.join(l for l in src.splitlines()
                     if not l.strip().startswith('--'))


def gate_facts(path=JMZ):
    """The five structural facts the reading rests on, read from jmz_func.lua.

    Fails loud rather than defaulting (source_constants contract): if the
    selector stops matching this shape, every consumer raises instead of
    quietly measuring a gate that moved.
    """
    with open(path, 'r', encoding='utf-8') as fh:
        src = _strip_comments(fh.read())
    m = re.search(r'function\s+J\.GetMostHpUnit\s*\(.*?\n(.*?)\nfunction\s',
                  src, re.S)
    if not m:
        raise RuntimeError('%s: no J.GetMostHpUnit body' % path)
    body = m.group(1)
    cands = re.findall(r"J\.IsSoakCandidate\(\s*'([a-z0-9_]+)'\s*\)", body)
    if cands != [CAND]:
        raise RuntimeError('%s: expected exactly one soak id %r, got %r'
                           % (path, CAND, cands))
    if not re.search(r'J\.IsModeTurbo\(\s*\)\s*and\s+J\.IsSoakCandidate',
                     body):
        raise RuntimeError('%s: turbo conjunct is not the first one' % path)
    lvl = re.search(r'GetLevel\(\s*\)\s*(<|<=|>|>=)\s*'
                    r'J\.Site\.ANCIENT_MIN_LEVEL', body)
    if not lvl:
        raise RuntimeError('%s: no GetLevel vs ANCIENT_MIN_LEVEL test' % path)
    # A LOWER bound would make the domain a band; there is none, and that is
    # the whole of §BL.3.  Assert its absence rather than trusting prose.
    lower = re.search(r'GetLevel\(\s*\)\s*(>|>=)\s*\d', body)
    return {
        'op': lvl.group(1),
        'has_lower_bound': bool(lower),
        'min_level': ANCIENT_MIN_LEVEL,
    }


def selector_sites(root=BOTS):
    """Files that feed the GUARDED selector, and the one opt-out, by grep.

    Returned as a set of repo-relative paths so a residual cast can be asked
    the cheap half of "is this hero even on a covered path".  The expensive
    half (which ABILITY inside the file) stays with the human reader -- see the
    module docstring's WHAT THIS CANNOT SAY.
    """
    guarded, optout = set(), set()
    for dirpath, _, names in os.walk(root):
        for n in names:
            if not n.endswith('.lua'):
                continue
            p = os.path.join(dirpath, n)
            with open(p, 'r', encoding='utf-8') as fh:
                src = _strip_comments(fh.read())
            rel = os.path.relpath(p, REPO)
            if re.search(r'J\.GetMostHpUnitAnyTier\s*\(', src):
                optout.add(rel)
            if re.search(r'J\.GetMostHpUnit\s*\(', src):
                guarded.add(rel)
    guarded.discard(os.path.relpath(JMZ, REPO))
    optout.discard(os.path.relpath(JMZ, REPO))
    return guarded, optout


GENERIC = os.path.join(BOTS, 'ability_item_usage_generic.lua')


def generic_sites_are_items(path=GENERIC):
    """Is every selector site in the shared file an ITEM consider?

    This decides how a residual by a hero with NO file of his own is read.
    `ability_item_usage_generic.lua` runs for every hero, so if it held an
    ABILITY consider that used the selector, "his hero file has no site" would
    stop meaning "this cast cannot have come through the selector".  Today its
    one site is `X.ConsiderItemDesire["item_iron_talon"]`, whose casts appear
    in the combat log as ITEM, not ABILITY -- so the inference holds.  Asserted
    rather than assumed, because it is load-bearing and cheap.
    """
    with open(path, 'r', encoding='utf-8') as fh:
        lines = _strip_comments(fh.read()).splitlines()
    owners = []
    cur = None
    for l in lines:
        m = re.match(r'\s*(?:function\s+)?X\.Consider(\w+)', l)
        if m:
            cur = m.group(1)
        elif re.match(r'\s*function\s', l):
            cur = None
        if re.search(r'J\.GetMostHpUnit\s*\(', l):
            owners.append(cur)
    if not owners:
        raise RuntimeError('%s: no selector site -- this check is stale' % path)
    return owners


# --------------------------------------------------------------------------
# corpus side
# --------------------------------------------------------------------------
def level_bracket(frames, t):
    """(lo, hi) hero level around t -- the last sample <= t, the first >= t.

    Never interpolates (see the module docstring).  Either end may be None at
    the edges of the sampled span; a caller must handle that rather than
    clamping, because a clamped read answers with a frame from outside the
    unit's life.
    """
    lo = hi = None
    for s in frames:
        if s['t'] <= t:
            lo = s['level']
        else:
            hi = s['level']
            break
    if hi is None and lo is not None and frames and frames[-1]['t'] <= t:
        hi = None                      # past the last sample: genuinely unknown
    return lo, hi


def place(lo, hi, tier):
    """Which side of the tier a bracketed level is on -- or 'straddle'."""
    if lo is None and hi is None:
        return 'no_frame'
    if hi is not None and hi < tier:
        return 'certain_under'
    if lo is not None and lo >= tier:
        return 'certain_over'
    if lo is None or hi is None:
        return 'no_frame'
    return 'straddle'


def scan(dirs, warmup=WARMUP_GAMES):
    games = []
    for d in dirs:
        run_tag = os.path.basename(d.rstrip('/')).split('_')[-1]
        for m in load_sweep(d):
            p = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            if os.path.exists(p):
                games.append((run_tag, m, p))
            else:
                print('[warn] missing timeline %s' % p, file=sys.stderr)

    # GH #226: `<stamp>_slotN` repeats across the runs of one wave.  Every key
    # in this file is (run, game); the collision count is printed so a reader
    # can see the difference a bare `game` key would have made.
    bare = Counter(m['game'] for _, m, _ in games)
    collisions = sum(c - 1 for c in bare.values() if c > 1)

    anc_pts, norm_pts = [], []
    for _, _, p in games[:warmup]:
        tl = load(p)
        fr, _ = entities.frames_by_hero(tl)
        a, n = camp_samples(tl, fr)
        anc_pts += a
        norm_pts += n
        del tl
    anc_camps, anc_cov = keep_supported(cluster(anc_pts), ANC_SUPPORT)
    norm_camps, norm_cov = keep_supported(cluster(norm_pts), NORM_SUPPORT)

    # The denominator that decides how much a zero is worth.  A leg that never
    # had a SELECTOR-FED hero standing under-tier at an ancient camp cannot be
    # said to have declined anything; a leg that stood there often and still
    # never cast is measuring a rare observable, not a working gate.
    fed_basenames = {os.path.basename(f) for f in selector_sites()[0]}
    fed_exposure = Counter()      # (leg, arm_side) -> those frames, fed heroes only

    casts = []
    ngames = {'radiant': 0, 'dire': 0}
    keys = set()
    exposure = Counter()          # (leg, arm_side, band) -> hero-frames near a camp
    engage = Counter()            # (leg, arm_side) -> hero<->ancient DAMAGE events
    stats = Counter()
    for run_tag, m, p in games:
        tl = load(p)
        teams = tl['game']['teams']
        armed_team = RADIANT if m['side'] == 'radiant' else DIRE
        ngames[m['side']] += 1
        keys.add((run_tag, m['game']))
        clean, _ = entities.frames_by_hero(tl)
        deaths = entities.death_times(tl)

        def leg_of(hero_full):
            tm = teams.get(hero_full)
            if tm not in (RADIANT, DIRE):
                return None
            return 'armed' if tm == armed_team else 'baseline'

        # ---- exposure: alive under-tier hero-frames within a sweep of a camp
        for h, fr in clean.items():
            leg = leg_of('npc_dota_hero_' + h)
            if leg is None:
                continue
            dt = deaths.get(h, [])
            for s in fr:
                if s['level'] >= ANCIENT_MIN_LEVEL:
                    continue
                if not entities.alive_at(fr, dt, s['t']):
                    continue
                if not anc_camps:
                    continue
                if min(math.dist((s['x'], s['y']), (c[0], c[1]))
                       for c in anc_camps) > R_SWEEP_MAX:
                    continue
                exposure[(leg, m['side'], band_of(s['level']))] += 1
                if 'hero_%s.lua' % h in fed_basenames:
                    fed_exposure[(leg, m['side'])] += 1

        # ---- the observable, plus guard (乙)'s denominator
        for e in tl['events']:
            if e['type'] == 'DAMAGE' and is_hero(e['actor']) \
                    and is_ancient(e['target']):
                leg = leg_of(e['actor'])
                if leg:
                    engage[(leg, m['side'])] += 1
                continue
            if e['type'] != 'ABILITY' or not is_hero(e['actor']):
                continue
            if not is_ancient(e['target'] or ''):
                continue
            leg = leg_of(e['actor'])
            if leg is None:
                continue
            h = entities.canon(e['actor'])
            fr = clean.get(h) or []
            lo, hi = level_bracket(fr, e['t'])
            cls = place(lo, hi, ANCIENT_MIN_LEVEL)
            stats[cls] += 1
            casts.append({
                'run': run_tag, 'game': m['game'], 'seed': m.get('seed'),
                't': e['t'], 'hero': h, 'ability': e.get('inflictor'),
                'target': e['target'], 'leg': leg, 'arm_side': m['side'],
                'lvl_lo': lo, 'lvl_hi': hi, 'placed': cls,
                'band': None if lo is None else band_of(lo),
            })
        del tl
    return {'casts': casts, 'ngames': ngames, 'games': len(games),
            'keys': len(keys), 'collisions': collisions,
            'anc_camps': anc_camps, 'anc_cov': anc_cov,
            'norm_camps': norm_camps, 'norm_cov': norm_cov,
            'exposure': exposure, 'fed_exposure': fed_exposure,
            'engage': engage, 'stats': stats}


def layered(casts, ngames, pred):
    """(ab, ba) counts and per-game rates -- iron rule 4(i), never pooled only.

    A layer with ZERO GAMES is flagged, never rendered as a measurement (GH
    #257).  `max(ngames[side], 1)` keeps the division safe but it also makes an
    absent layer arithmetically identical to a measured-and-flat one: both come
    out `0/0.000` with `delta == 0`.  Those are different facts -- one leg was
    watched and did nothing, the other was never watched -- so the difference is
    carried out of here in `absent` (and per-side `row['absent']`) rather than
    left for a reader to notice in the `games` column.
    """
    out = {}
    for side in ('radiant', 'dire'):
        row = {}
        for leg in ('armed', 'baseline'):
            n = sum(1 for c in casts
                    if c['arm_side'] == side and c['leg'] == leg and pred(c))
            row[leg + '_n'] = n
            row[leg] = n / float(max(ngames[side], 1))
        row['delta'] = row['armed'] - row['baseline']
        row['absent'] = ngames[side] == 0
        out[side] = row
    out['absent'] = tuple(s for s in ('radiant', 'dire') if out[s]['absent'])
    out['pooled'] = {
        leg + '_n': sum(1 for c in casts if c['leg'] == leg and pred(c))
        for leg in ('armed', 'baseline')}
    # Iron rule 4(i) rejects a reading whose two layers point in OPPOSITE
    # directions.  A layer that is flat is not a contradiction of the other --
    # folding zero into "disagreement" would throw away every reading with one
    # small layer, which is most of this id's domain.  So the test is strict
    # opposition, and the flat case is reported as what it is.
    a = out['radiant']['delta']
    b = out['dire']['delta']
    out['opposed'] = (a > 0 > b) or (a < 0 < b)
    out['same_sign'] = not out['opposed']
    out['one_layer_flat'] = (a == 0) != (b == 0)
    return out


def show(title, tab, ngames):
    print('\n%s' % title)
    print('  %-9s %7s %9s %9s %9s'
          % ('arm side', 'games', 'armed', 'baseline', 'delta'))
    for side in ('radiant', 'dire'):
        r = tab[side]
        if r['absent']:
            # Not `0/0.000 ... 0.000`.  That row is what an unfought layer
            # looks like, and this layer was never dealt into the wave.
            print('  %-9s %7d %10s %10s %9s'
                  % (side, ngames[side], '-', '-', 'ABSENT'))
            continue
        print('  %-9s %7d %4d/%.3f %4d/%.3f %9.3f'
              % (side, ngames[side], r['armed_n'], r['armed'],
                 r['baseline_n'], r['baseline'], r['delta']))
    p = tab['pooled']
    if tab['absent']:
        note = ('LAYER ABSENT (0 games: %s) -- NOT a flat layer'
                % ','.join(tab['absent']))
    elif tab['opposed']:
        note = 'OPPOSED => NOISE (rule 4i)'
    elif tab['one_layer_flat']:
        note = 'one layer flat (not a contradiction)'
    else:
        note = 'both layers agree'
    print('  %-9s %7s %9d %9d   two-layer: %s'
          % ('pooled', '-', p['armed_n'], p['baseline_n'], note))


def verdict(res):
    """NO-CORPUS / EMPTY-DOMAIN / SINGLE-LAYER / SILENT / REFUSE / WORKING /
    WORKING-WITH-RESIDUAL / BUGGY-SUSPECT.

    Deliberately ordered so that a zero delta reads SILENT and can never be
    swallowed by the two-layer test, and so that an empty domain is its own
    answer rather than being reported as a silence the lever caused.

    The first three exist to keep ABSENCE from being rendered as a measured
    zero (GH #257).  They are ordered outward from the emptiest fact: nothing
    was scanned, then nothing in what was scanned entered the domain, then the
    domain was entered but only one of rule 4(i)'s two layers exists.  Each one
    of them refuses to answer the armed-vs-baseline question rather than
    answering it from a leg that was never dealt.
    """
    casts = [c for c in res['casts'] if c['placed'] == 'certain_under']
    tab = layered(casts, res['ngames'], lambda c: True)
    a = tab['pooled']['armed_n']
    b = tab['pooled']['baseline_n']
    exposed = sum(v for (leg, side, band), v in res['exposure'].items())
    if res['ngames']['radiant'] + res['ngames']['dire'] == 0:
        # EMPTY-DOMAIN below asserts a scan happened and found nothing in the
        # domain.  With no games there was no scan, and saying so is the same
        # distinction this whole block is about.
        return 'NO-CORPUS', ('0 games loaded -- nothing was measured; this is '
                             'NOT an empty domain')
    if exposed == 0:
        return 'EMPTY-DOMAIN', ('no alive under-tier hero-frame came within '
                                '%d u of an ancient camp' % R_SWEEP_MAX)
    if tab['absent']:
        # Ahead of every armed/baseline branch below, INCLUDING the a==b
        # silence: on a one-layer corpus each of those would be a statement
        # about a comparison rule 4(i) says we do not have.
        return 'SINGLE-LAYER', (
            'no games on the %s arm-side, so iron rule 4(i)\'s second layer '
            'does not exist; the one layer present (armed %d, baseline %d) '
            'cannot carry an armed-vs-baseline reading'
            % (' and '.join(tab['absent']), a, b))
    if a == 0 and b == 0:
        return 'SILENT', ('domain is non-empty (%d exposed hero-frames) but '
                          'neither leg ever cast at an ancient under tier'
                          % exposed)
    # ORDER MATTERS, and this is the load-bearing pair.  A pooled delta of zero
    # produced by two OPPOSING layers is not a silence -- it is the cancellation
    # rule 4(i) exists to catch -- so opposition is asked first.  Only when both
    # layers are themselves flat does a zero read as SILENT (the `tbearly`
    # lesson: a genuine Δ=0 must not be laundered into REFUSE either).
    if tab['opposed']:
        return 'REFUSE', ('ab and ba point in opposite directions -- iron rule '
                          '4(i) says that is noise, not a reading')
    if a == b:
        return 'SILENT', 'armed and baseline fired the same number of times'
    if a < b and a == 0:
        return 'WORKING', 'armed leg is empty where baseline is not'
    if a < b:
        return 'WORKING-WITH-RESIDUAL', ('armed %d < baseline %d; the residual '
                                         'needs source-side adjudication' % (a, b))
    return 'BUGGY-SUSPECT', 'armed fired MORE than baseline'


def report(res, top=12):
    g = gate_facts()
    guarded, optout = selector_sites()
    print('=== source facts (read from bots/, not copied)')
    print('  gate            J.IsModeTurbo() and J.IsSoakCandidate(%r)' % CAND)
    print('  level test      GetLevel() %s J.Site.ANCIENT_MIN_LEVEL (= %d)'
          % (g['op'], g['min_level']))
    print('  lower bound     %s   <-- §BL.3: the domain is level < %d ENTIRE'
          % ('PRESENT (!)' if g['has_lower_bound'] else 'none', g['min_level']))
    print('  guarded files   %d   opt-out files %d'
          % (len(guarded), len(optout)))
    print('  bands           under = <%d, band = %d..%d, over = >=%d'
          % (SHIPPED_ANCIENT_MIN, SHIPPED_ANCIENT_MIN, ANCIENT_MIN_LEVEL - 1,
             ANCIENT_MIN_LEVEL))
    print('  DOMAIN for this id = under + band.  `over` is guard (甲) only.')

    print('\n=== corpus')
    print('  games %d  distinct (run,game) keys %d  bare-name collisions %d'
          % (res['games'], res['keys'], res['collisions']))
    print('  (a bare `game` key would have merged %d of them -- GH #226)'
          % res['collisions'])
    print('  ancient clusters %d (%.1f%% of samples)'
          % (len(res['anc_camps']), 100 * res['anc_cov']))
    if len(res['anc_camps']) != 2:
        print('  ** WARNING: a real ancient unit resolves to exactly TWO '
              'clusters; got %d **' % len(res['anc_camps']))

    print('\n=== placement of every ABILITY -> ancient cast (%d total)'
          % len(res['casts']))
    # Pre-seeded and printed in a fixed order: a class with zero members must
    # print `0`, not vanish.  (replay-check 2026-08-26T12:54Z: a bare Counter
    # dropped the zero rung and it read as "not measured".)
    for cls in ('certain_under', 'straddle', 'certain_over', 'no_frame'):
        print('  %-14s %6d' % (cls, res['stats'][cls]))

    print('\n=== exposure -- alive under-tier hero-frames within %d u of a camp'
          % R_SWEEP_MAX)
    print('  %-9s %-9s %10s %10s' % ('leg', 'arm side', 'under', 'band'))
    for leg in ('armed', 'baseline'):
        for side in ('radiant', 'dire'):
            print('  %-9s %-9s %10d %10d'
                  % (leg, side, res['exposure'][(leg, side, 'under')],
                     res['exposure'][(leg, side, 'band')]))

    print('\n=== ... of those, heroes whose file FEEDS the guarded selector')
    print('  %-9s %10s %10s   (a leg with none of these had nothing to decline)'
          % ('leg', 'radiant', 'dire'))
    for leg in ('armed', 'baseline'):
        print('  %-9s %10d %10d'
              % (leg, res['fed_exposure'][(leg, 'radiant')],
                 res['fed_exposure'][(leg, 'dire')]))

    ng = res['ngames']
    under = [c for c in res['casts'] if c['placed'] == 'certain_under']
    show('DOMAIN (§BL.3) -- casts at an ancient by a hero below level %d'
         % ANCIENT_MIN_LEVEL, layered(under, ng, lambda c: True), ng)
    show('  ... split: `under` band (<%d)' % SHIPPED_ANCIENT_MIN,
         layered(under, ng, lambda c: c['band'] == 'under'), ng)
    show('  ... split: `band` (%d..%d)' % (SHIPPED_ANCIENT_MIN,
                                           ANCIENT_MIN_LEVEL - 1),
         layered(under, ng, lambda c: c['band'] == 'band'), ng)
    show('REVERSE GUARD (甲) -- casts at an ancient at level >= %d '
         '(must NOT collapse > 30%%)' % ANCIENT_MIN_LEVEL,
         layered([c for c in res['casts'] if c['placed'] == 'certain_over'],
                 ng, lambda c: True), ng)

    print('\n=== REVERSE GUARD (乙) -- hero->ancient DAMAGE events '
          '(must NOT collapse to 0)')
    print('  %-9s %10s %10s' % ('arm side', 'armed', 'baseline'))
    for side in ('radiant', 'dire'):
        print('  %-9s %10d %10d'
              % (side, res['engage'][('armed', side)],
                 res['engage'][('baseline', side)]))

    print('\n=== residual armed under-tier casts (for source-side adjudication)')
    resid = [c for c in under if c['leg'] == 'armed']
    if not resid:
        print('  none')
    else:
        gen = generic_sites_are_items()
        gen_item_only = all(o == 'ItemDesire' for o in gen)
        by = Counter((c['hero'], c['ability']) for c in resid)
        for (h, ab), n in by.most_common(top):
            covered = any(os.path.basename(f) == 'hero_%s.lua' % h
                          for f in guarded)
            if covered:
                tag = 'REACHABLE via the selector -- adjudicate this one'
            elif gen_item_only:
                tag = ('not reachable: no site in hero_%s.lua, and the shared '
                       'file\'s only site is an ITEM consider' % h)
            else:
                tag = ('UNKNOWN: the shared file now holds a non-item site '
                       '(%s)' % ','.join(sorted(set(map(str, gen)))))
            print('  %-18s %-32s %4d   %s' % (h, ab, n, tag))
        print('  -- frames --')
        for c in sorted(resid, key=lambda c: (c['run'], c['game'], c['t']))[:top]:
            print('  %s/%s t=%.1f %s lvl[%s,%s] %s -> %s'
                  % (c['run'], c['game'], c['t'], c['hero'], c['lvl_lo'],
                     c['lvl_hi'], c['ability'], c['target']))

    v, why = verdict(res)
    print('\n=== VERDICT  %s' % v)
    print('  %s' % why)
    return v


# --------------------------------------------------------------------------
def selfcheck():
    ok = True

    def chk(label, cond):
        nonlocal ok
        print('  %-62s %s' % (label, 'PASS' if cond else 'FAIL'))
        ok = ok and bool(cond)

    print('--- source facts')
    g = gate_facts()
    chk('gate reads a single soak id, and it is %r' % CAND, True)  # gate_facts raises otherwise
    chk('level test is a strict upper bound (<)', g['op'] == '<')
    chk('gate has NO lower bound => domain is under+band (§BL.3)',
        not g['has_lower_bound'])
    chk('tier came from the Lua, not this file', g['min_level'] == ANCIENT_MIN_LEVEL)
    guarded, optout = selector_sites()
    chk('guarded selector has call sites outside jmz_func', len(guarded) >= 10)
    chk('the opt-out has exactly one file', len(optout) == 1)
    chk('the opt-out file is doom bringer',
        len(optout) == 1 and 'doom_bringer' in list(optout)[0])
    gen = generic_sites_are_items()
    chk('the shared file\'s selector sites are ALL item considers '
        '(%s) -- this is what makes "his hero file has no site" mean '
        '"not reachable"' % ','.join(map(str, gen)),
        gen and all(o == 'ItemDesire' for o in gen))

    print('--- anti-selfskip: the source assertions must be able to go RED')
    import tempfile
    def _tmp(src):
        fh = tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False)
        fh.write(src)
        fh.close()
        return fh.name
    bad_two = _tmp("function J.GetMostHpUnit( l )\n"
                   "\tlocal a = J.IsSoakCandidate( 'abilanc' )\n"
                   "\tlocal b = J.IsSoakCandidate( 'campfarm' )\n"
                   "\treturn a and b\n"
                   "end\nfunction J.Next()\nend\n")
    try:
        gate_facts(bad_two)
        chk('two soak ids in the body raises', False)
    except RuntimeError:
        chk('two soak ids in the body raises', True)
    bad_lower = _tmp("function J.GetMostHpUnit( l )\n"
                     "\tlocal x = J.IsModeTurbo() and J.IsSoakCandidate( 'abilanc' )\n"
                     "\tif x then x = h:GetLevel() >= 10 "
                     "and h:GetLevel() < J.Site.ANCIENT_MIN_LEVEL end\n"
                     "\treturn x\n"
                     "end\nfunction J.Next()\nend\n")
    chk('a lower bound added to the gate is DETECTED',
        gate_facts(bad_lower)['has_lower_bound'] is True)
    for p in (bad_two, bad_lower):
        os.unlink(p)

    print('--- level bracketing (never interpolate a step function)')
    fr = [{'t': 0.0, 'level': 9}, {'t': 1.0, 'level': 11},
          {'t': 2.0, 'level': 12}, {'t': 3.0, 'level': 12}]
    chk('bracket at a sample is (that sample, the next)',
        level_bracket(fr, 1.0) == (11, 12))
    chk('bracket between samples straddles',
        level_bracket(fr, 1.5) == (11, 12))
    chk('a straddle over the tier is NOT placed',
        place(*level_bracket(fr, 1.5), tier=12) == 'straddle')
    chk('both ends below the tier => certain_under',
        place(*level_bracket(fr, 0.5), tier=12) == 'certain_under')
    chk('both ends at or above => certain_over',
        place(*level_bracket(fr, 2.5), tier=12) == 'certain_over')
    # Monotonicity makes a past-the-end read sound in ONE direction only: if
    # the last sample is already at or above the tier, no later level can be
    # below it, so `certain_over` is safe.  Below the tier it is not -- he may
    # have levelled in the gap -- and that direction must stay unknown, because
    # it is the direction that would manufacture a violation.
    chk('past the last sample, already over the tier => certain_over',
        place(*level_bracket(fr, 9.9), tier=12) == 'certain_over')
    low = [{'t': 0.0, 'level': 9}, {'t': 1.0, 'level': 11}]
    chk('past the last sample, still UNDER the tier => no_frame (never guessed)',
        place(*level_bracket(low, 9.9), tier=12) == 'no_frame')
    chk('empty frame list is no_frame', place(*level_bracket([], 1.0), tier=12)
        == 'no_frame')
    chk('a level of exactly the tier is OVER, matching `<`',
        place(12, 12, 12) == 'certain_over')
    chk('band_of agrees with the tier read from Lua',
        band_of(ANCIENT_MIN_LEVEL - 1) == 'band'
        and band_of(ANCIENT_MIN_LEVEL) == 'over'
        and band_of(SHIPPED_ANCIENT_MIN - 1) == 'under')

    print('--- two-layer table (iron rule 4(i))')
    ng = {'radiant': 10, 'dire': 10}
    same = [{'arm_side': 'radiant', 'leg': 'baseline'},
            {'arm_side': 'dire', 'leg': 'baseline'}]
    t = layered(same, ng, lambda c: True)
    chk('both layers negative => not opposed', t['opposed'] is False)
    opp = [{'arm_side': 'radiant', 'leg': 'armed'},
           {'arm_side': 'dire', 'leg': 'baseline'}]
    t2 = layered(opp, ng, lambda c: True)
    chk('one layer up, one down => OPPOSED', t2['opposed'] is True)
    chk('pooled counts are printed alongside, not instead',
        t2['pooled']['armed_n'] == 1 and t2['pooled']['baseline_n'] == 1)
    flat = [{'arm_side': 'dire', 'leg': 'baseline'}]
    t3 = layered(flat, ng, lambda c: True)
    chk('a FLAT layer is not an opposition (it would eat most readings)',
        t3['opposed'] is False and t3['one_layer_flat'] is True)

    print('--- an ABSENT layer is not a flat one (GH #257)')
    # W17-R shape: four boxes all radiant, so the `dire` arm-side has zero
    # games.  Arithmetically indistinguishable from the flat case above -- the
    # `dire` delta is 0 in both -- which is exactly why the flag is carried.
    ng_one = {'radiant': 18, 'dire': 0}
    one = [{'arm_side': 'radiant', 'leg': 'baseline'},
           {'arm_side': 'radiant', 'leg': 'baseline'},
           {'arm_side': 'radiant', 'leg': 'armed'}]
    t4 = layered(one, ng_one, lambda c: True)
    chk('a layer with 0 games is flagged ABSENT', t4['absent'] == ('dire',))
    chk('the layer that DOES have games is not flagged',
        t4['radiant']['absent'] is False and t4['dire']['absent'] is True)
    chk('absence is still not an opposition, and `one_layer_flat` alone '
        'cannot tell the two apart',
        t4['opposed'] is False and t4['one_layer_flat'] is True
        and t3['absent'] == ())
    import io as _io
    import contextlib as _ctx
    buf = _io.StringIO()
    with _ctx.redirect_stdout(buf):
        show('t', t4, ng_one)
    rendered = buf.getvalue()
    chk('the note says LAYER ABSENT, never "one layer flat"',
        'LAYER ABSENT (0 games: dire)' in rendered
        and 'one layer flat' not in rendered)
    chk('the absent ROW prints no rate either -- `0/0.000` is what a watched '
        'and silent layer looks like',
        '0/0.000' not in rendered and 'ABSENT' in rendered)

    print('--- verdict, all five worlds, and the ORDER between them')
    base = {'ngames': ng, 'exposure': Counter({('armed', 'radiant', 'band'): 5}),
            'fed_exposure': Counter(), 'engage': Counter()}
    def mk(casts, exposure=None):
        d = dict(base)
        d['casts'] = casts
        if exposure is not None:
            d['exposure'] = exposure
        return d
    def c(side, leg, cls='certain_under'):
        return {'arm_side': side, 'leg': leg, 'placed': cls, 'band': 'band'}
    chk('empty domain is its own answer, not a silence',
        verdict(mk([], Counter()))[0] == 'EMPTY-DOMAIN')
    chk('non-empty domain, nobody fired => SILENT',
        verdict(mk([]))[0] == 'SILENT')
    chk('armed empty, baseline fires in both layers => WORKING',
        verdict(mk([c('radiant', 'baseline'), c('dire', 'baseline')]))[0]
        == 'WORKING')
    chk('armed fewer but non-zero => WORKING-WITH-RESIDUAL',
        verdict(mk([c('radiant', 'baseline'), c('radiant', 'baseline'),
                    c('dire', 'baseline'), c('dire', 'baseline'),
                    c('radiant', 'armed'), c('dire', 'armed')]))[0]
        == 'WORKING-WITH-RESIDUAL')
    chk('armed MORE => BUGGY-SUSPECT',
        verdict(mk([c('radiant', 'armed'), c('dire', 'armed'),
                    c('radiant', 'baseline')]))[0] == 'BUGGY-SUSPECT')
    chk('opposed layers => REFUSE **even though the pooled delta is zero**',
        verdict(mk([c('radiant', 'armed'), c('radiant', 'armed'),
                    c('dire', 'baseline'), c('dire', 'baseline')]))[0]
        == 'REFUSE')
    chk('a genuinely flat pair reads SILENT, not REFUSE (`tbearly` lesson)',
        verdict(mk([c('radiant', 'armed'), c('radiant', 'baseline'),
                    c('dire', 'armed'), c('dire', 'baseline')]))[0]
        == 'SILENT')
    chk('an over-tier cast never enters the domain count',
        verdict(mk([c('radiant', 'armed', 'certain_over'),
                    c('dire', 'armed', 'certain_over')]))[0] == 'SILENT')

    # GH #257.  The reproduction in the issue is this exact shape: 18 radiant
    # games, armed 1 < baseline 2, dire never dealt -- and it printed
    # WORKING-WITH-RESIDUAL, i.e. half of condition (a), off one layer.
    one_layer = dict(base)
    one_layer['ngames'] = ng_one
    one_layer['casts'] = [c('radiant', 'baseline'), c('radiant', 'baseline'),
                          c('radiant', 'armed')]
    chk('armed < baseline on a ONE-LAYER corpus is SINGLE-LAYER, not '
        'WORKING-WITH-RESIDUAL (GH #257)',
        verdict(one_layer)[0] == 'SINGLE-LAYER')
    for label, casts_ in (
            ('armed empty (would have read WORKING)',
             [c('radiant', 'baseline'), c('radiant', 'baseline')]),
            ('armed more (would have read BUGGY-SUSPECT)',
             [c('radiant', 'armed'), c('radiant', 'armed'),
              c('radiant', 'baseline')]),
            ('armed == baseline (would have read SILENT)',
             [c('radiant', 'armed'), c('radiant', 'baseline')])):
        d = dict(one_layer)
        d['casts'] = casts_
        chk('  ... and so is %s' % label, verdict(d)[0] == 'SINGLE-LAYER')
    chk('SINGLE-LAYER does NOT pre-empt EMPTY-DOMAIN -- a one-layer corpus '
        'whose domain never occurred still says so',
        verdict(mk([], Counter()))[0] == 'EMPTY-DOMAIN')
    no_corpus = dict(base)
    no_corpus['ngames'] = {'radiant': 0, 'dire': 0}
    no_corpus['casts'] = []
    chk('zero games is NO-CORPUS, not an empty domain (nothing was scanned)',
        verdict(no_corpus)[0] == 'NO-CORPUS')
    chk('a two-layer corpus is unaffected: WORKING-WITH-RESIDUAL survives',
        verdict(mk([c('radiant', 'baseline'), c('radiant', 'baseline'),
                    c('dire', 'baseline'), c('dire', 'baseline'),
                    c('radiant', 'armed'), c('dire', 'armed')]))[0]
        == 'WORKING-WITH-RESIDUAL')

    print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--source', action='store_true',
                    help='source-side facts only; needs no corpus, costs nothing')
    ap.add_argument('--top', type=int, default=12)
    ap.add_argument('--warmup', type=int, default=WARMUP_GAMES)
    ap.add_argument('--out', default='/tmp/abilanc_domain.jsonl')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if a.source:
        g = gate_facts()
        guarded, optout = selector_sites()
        print(json.dumps({'gate': g,
                          'guarded_files': sorted(guarded),
                          'optout_files': sorted(optout)}, indent=2))
        return 0
    if not a.sweeps:
        ap.error('give at least one sweep dir (or --source / --selfcheck)')
    res = scan(a.sweeps, a.warmup)
    with open(a.out, 'w', encoding='utf-8') as fh:
        for c in res['casts']:
            fh.write(json.dumps(c) + '\n')
    report(res, a.top)
    print('\n(per-cast rows: %s)' % a.out)
    return 0


if __name__ == '__main__':
    sys.exit(main())

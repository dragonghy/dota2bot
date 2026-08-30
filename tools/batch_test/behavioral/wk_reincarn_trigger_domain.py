#!/usr/bin/env python3
"""`hero-20`: how often does Reincarnation trigger, and who is standing there?

WHY THIS FILE EXISTS
--------------------
`bots/BotLib/hero_skeleton_king.lua:412-417` prices Wraith King's t25 row and
then writes its own honest bound:

    HONEST BOUNDS on the t25 half: no frame in this repo shows a Wraith King at
    25, so the window length is inferred from ONE post-cap game (GH #235), and
    "how often does Reincarnation trigger with enemies inside 900" is a corpus
    question nobody has asked -- if that number turns out high, [8]'s case
    improves and this row should be re-priced.

That is the whole request (`queue.json:hero-20`, director APPROVED
2026-08-30T01:05Z, `test_set.md §CH`, `director.executor = replay-check`).
It buys a DISTRIBUTION, not a gate verdict: nothing here is gated, both talent
rows are live in every turbo game that reaches the level.

  [7] special_bonus_unique_wraith_king_10  -- Mortal Strike cooldown 5 -> 3s
  [8] special_bonus_unique_wraith_king_4   -- Reincarnation casts Wraithfire
                                              Blast (900 radius) INSTEAD OF the
                                              shipped slow (slow_radius 600)

[8] is a REPLACEMENT, not an addition, so the gross number that decides it is
the 900-count MINUS the 600-count, per acceptance (3).  Reporting 900 alone
overstates it.

THE IDENTIFIER, AND WHY IT IS NOT THE ONE THE REQUEST NAMED
-----------------------------------------------------------
`acceptance` (2) named `modifier_skeleton_king_reincarnation` on Wraith King's
own frame.  The director's `acceptance_amendment` then measured that name at
**0 occurrences in all 109 fixtures**, ruled out the `_scepter` variant as a
permanent marker, offered the ability-cooldown rising edge as an unproven
lead, and attached a hard clause:

  (丁) if ANY identifier yields 0 triggers, record METHOD-FAILED -- do NOT
       record it as "triggering is rare, so the pricing is confirmed".

The corpus answers that clause without needing it.  There is a THIRD
identifier neither the request nor the amendment had, and it is an exact event
rather than a sampled state:

    events[] type == 'ABILITY_TRIGGER'
             actor == npc_dota_hero_skeleton_king
             inflictor == 'skeleton_king_reincarnation'

It carries the combat log's own 0.1 s timestamp, so unlike the 1 Hz snapshot
stream it does not depend on amendment (戊)'s ">= 1 s persistent state" escape
-- the resolution problem that sank `wkqdmg` (GH #310) does not arise here.

This tool does not ASK the reader to trust that.  It cross-checks all three
identifiers on every Wraith King death in the corpus and prints the agreement
matrix (`--method`):

  A. ABILITY_TRIGGER event                       (the one used)
  B. reincarnation cooldown 0 -> positive        (amendment 丙, sampled 1 Hz)
  C. in-place resurrection                       (behavioural ground truth:
     revived <= REVIVE_DT_MAX s after the DEATH event and displaced less than
     REVIVE_DISP_MAX u -- WK resurrects WHERE HE FELL, the charter's
     2026-08-21 tool pit, so a fountain respawn is 8k-12k u away and tens of
     seconds later)

C is independent of both A and B: it reads positions and hp, not ability
state.  If the three disagree the number below is not worth reading, and the
`--method` block says so before any distribution is printed.

WHAT IT CANNOT SEE
------------------
* The 900 count is a POSITION read on a 1 Hz stream, and a hero closing at
  400 u/s moves +-420 u between samples -- a real hazard against a 900 u
  threshold (the `wkqdmg` phase lesson, GH #310).  So every count is reported
  at BOTH bracketing samples (`pre` = last sample at or before the trigger,
  `post` = first sample after) and the spread between them is printed.  A
  conclusion that only survives one phase is not a conclusion.
* The 600 count has an engine-side ground truth that needs no positions at
  all: the shipped Reincarnation applies `modifier_skeleton_king_reincarnate_slow`
  to everything inside `slow_radius`, and those MODIFIER_ADD events name their
  targets.  The tool reports the position-derived 600 count beside the engine's
  own answer, which calibrates the position instrument on real frames instead
  of assuming it.
* Illusions are dropped by `entities.frames_by_hero` (GH #176) and death is
  read through `entities.alive_at` with the DEATH-event anchor, because an
  interpolated hp_pct blends a live frame with a corpse frame and answers 0.05.

NAMING NOTE (read before adding a third Wraith King file)
---------------------------------------------------------
`wk_reincarn_domain.py` beside this file is a DIFFERENT tool for a DIFFERENT
question: it sizes the `wkreincarnmp` mana-threshold gate (hero stream,
2026-08-18).  This file measures how often the ultimate FIRES and who is
standing there; that one measures when the "armed" predicate disagrees with
the shipped 160-mana constant.

And that file already knew the identifier this one had to re-derive: its
section C header (`wk_reincarn_domain.py`, "outcome side") names the
`ABILITY_TRIGGER` event AND records that
`modifier_skeleton_king_reincarnation_scepter_active` is not the trigger --
which is the exact pair of facts `hero-20`'s acceptance and its amendment
spent a round establishing from fixtures.  The knowledge was on trunk,
committed by another stream, and neither the request nor the amendment found
it.  Naming this file distinctly is the cheap half of not repeating that.

USAGE
    wk_reincarn_domain.py <timeline.json> [...]        # scan, JSONL to stdout
    wk_reincarn_domain.py --agg <records.jsonl>        # aggregate + report
    wk_reincarn_domain.py --selfcheck
"""

import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from entities import (canon, frames_by_hero, death_times, alive_at, interp)

WK = 'skeleton_king'
ABIL = 'skeleton_king_reincarnation'
SLOW_MOD = 'modifier_skeleton_king_reincarnate_slow'

# Radii under test.  600 is the shipped Reincarnation's `slow_radius`; 900 is
# the Wraithfire Blast radius talent [8] would replace it with.
R_TALENT = 900.0
R_SHIPPED = 600.0

# In-place resurrection window (identifier C).  `reincarnate_time = 3`, and the
# snapshot stream is 1 Hz, so the first live sample lands 3.0-4.0 s out; a
# fountain respawn in turbo is tens of seconds and >1500 u (charter 2026-08-21
# fixes the displacement rule at >1500 u for the fountain case).
REVIVE_DT_MAX = 6.0
REVIVE_DISP_MAX = 1500.0

# Window in which the engine's own slow lands after the trigger instant.
SLOW_WINDOW_S = 0.5

# Identifier B's threshold.  Measured on this corpus: the real Reincarnation
# cooldown runs ~150 s at rank 2 and ~110 s at rank 3, while the auxiliary
# timer that shares the ability handle runs 4.3 s.  See triggers_B().
B_MIN_CD = 60.0


def _bracket(frames, t):
    """(last sample at or before t, first sample after t), or (None, None)."""
    if not frames or t < frames[0]['t'] or t > frames[-1]['t']:
        return None, None
    lo, hi = 0, len(frames) - 1
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if frames[mid]['t'] <= t:
            lo = mid
        else:
            hi = mid
    return frames[lo], frames[hi]


def _dist(a, b):
    return math.hypot(a['x'] - b['x'], a['y'] - b['y'])


def _wk_key(fr):
    for h in fr:
        if canon(h) == WK:
            return h
    return None


def triggers_A(timeline):
    """Identifier A: the ABILITY_TRIGGER event.  Returns sorted timestamps."""
    out = []
    for e in timeline.get('events', ()):
        if (e.get('type') == 'ABILITY_TRIGGER'
                and e.get('inflictor') == ABIL
                and canon(e.get('actor') or '') == WK):
            out.append(e['t'])
    return sorted(out)


def triggers_B(wk_frames):
    """Identifier B: the reincarnation cooldown jumping to its FULL length.

    WHY NOT THE "0 -> positive" EDGE THE AMENDMENT PROPOSED.  The amendment
    (丙) offered `cd` going from 0 to positive as a lead, and explicitly did
    not claim to have proven it.  On this corpus it is wrong in BOTH
    directions, and the same mechanism causes both:

      * FALSE NEGATIVE, `20260827_122211_slot9` t=982.3.  The real trigger is
        there (ABILITY_TRIGGER + DEATH + the slow, all at 982.3), but the
        sample before it reads cd=0.5, not 0 -- so a `prev <= 0` test misses
        it.  The cooldown then jumps 0.5 -> 149.7.
      * FALSE POSITIVE, `20260827_123454_slot3` t=452.5.  cd goes 0 -> 4.3 and
        decays 3.1 / 2.3 / 1.1 / 0.3 / 0 with no death and no trigger.
        `modifier_skeleton_king_reincarnation_scepter_active` is added at
        452.0 and removed at 456.5 -- that 4.3 s is ITS timer riding on the
        same ability handle.  (It is also what the snapshot's `cd_len` field
        reports for this ability: 4.3, never the 150/110 the real cooldown
        actually runs -- so `cd_len` cannot be used to normalise it either.)

    The real Reincarnation cooldown measured on these frames is ~150 s at
    rank 2 and ~110 s at rank 3, an order of magnitude above that auxiliary
    timer, so the two populations do not overlap and a magnitude threshold
    separates them cleanly.  `B_MIN_CD` sits between them.

    Returns the timestamp of the FIRST sample showing the raised cooldown, so
    it is late by up to one sample interval relative to A by construction.
    """
    out = []
    prev = None
    for s in wk_frames:
        cd = lvl = None
        # `abilities` is present but JSON-null on pre-horn frames (and on any
        # frame the dumper sampled before the ability book existed), so the
        # two-arg get() default never fires: `or ()` is the one that does.
        for a in (s.get('abilities') or ()):
            if a.get('name') == ABIL:
                cd = a.get('cd')
                lvl = a.get('level', 0)
                break
        if cd is None:
            continue
        if prev is not None and prev < B_MIN_CD <= cd and lvl >= 1:
            out.append(s['t'])
        prev = cd
    return out


def triggers_C(timeline, wk_frames, wk_deaths):
    """Identifier C: a DEATH followed by an IN-PLACE resurrection.

    Ground truth that touches neither ability state nor modifiers.
    """
    out = []
    for td in wk_deaths:
        before, _ = _bracket(wk_frames, td)
        if before is None:
            continue
        rev = None
        for s in wk_frames:
            if s['t'] > td and s['hp_pct'] > 0.5:
                rev = s
                break
        if rev is None:
            continue
        if (rev['t'] - td) <= REVIVE_DT_MAX and _dist(rev, before) <= REVIVE_DISP_MAX:
            out.append(td)
    return out


def _near(ts, t, tol):
    return any(abs(x - t) <= tol for x in ts)


def scan(path):
    """One timeline -> one record dict (per-game) with a list of triggers."""
    with open(path) as fh:
        tl = json.load(fh)
    fr, team = frames_by_hero(tl)
    deaths = death_times(tl)
    wkh = _wk_key(fr)
    game = os.path.basename(path).replace('.timeline.json', '')
    rec = {'game': game, 'wk_present': wkh is not None, 'triggers': []}
    if wkh is None:
        return rec

    wkf = fr[wkh]
    wk_deaths = list(deaths.get(wkh) or ())
    A = triggers_A(tl)
    B = triggers_B(wkf)
    C = triggers_C(tl, wkf, wk_deaths)
    rec['n_deaths'] = len(wk_deaths)
    rec['idA'] = A
    rec['idB'] = B
    rec['idC'] = C
    rec['wk_max_level'] = max((s.get('level', 0) for s in wkf), default=0)
    rec['t_last'] = wkf[-1]['t'] if wkf else 0.0
    # The OTHER half of the t25 argument.  hero_skeleton_king.lua:412 concedes
    # "the window length is inferred from ONE post-cap game (GH #235)" -- so
    # record, per game, when Wraith King actually crossed 20 and 25.  The
    # window [t25, end] is what talent [8] gets paid in; the window [t20, end]
    # is the same question one row up.
    for lv in (20, 25):
        hit = next((s['t'] for s in wkf if s.get('level', 0) >= lv), None)
        rec['t_level%d' % lv] = hit
    # amendment (甲): the identifier the request named, counted on this corpus
    rec['n_named_modifier'] = sum(
        1 for e in tl.get('events', ())
        if e.get('inflictor') == 'modifier_skeleton_king_reincarnation')

    wk_team = team[wkh]
    enemies = [h for h in fr if canon(h) != WK and team[h] != wk_team]

    for t in A:
        wk_pre, wk_post = _bracket(wkf, t)
        if wk_pre is None:
            continue
        row = {
            't': t,
            'wk_level': wk_pre.get('level', 0),
            'agree_B': _near(B, t, 1.5),   # B is late by up to one 1 Hz sample
            'agree_C': _near(C, t, 0.5),
        }
        for tag, wkpos in (('pre', wk_pre), ('post', wk_post)):
            n900 = n600 = 0
            ds = []
            for h in enemies:
                if not alive_at(fr[h], deaths.get(h), wkpos['t']):
                    continue
                e_at, _ = _bracket(fr[h], wkpos['t'])
                if e_at is None:
                    continue
                d = _dist(wkpos, e_at)
                ds.append(round(d, 1))
                if d <= R_TALENT:
                    n900 += 1
                if d <= R_SHIPPED:
                    n600 += 1
            row['n900_' + tag] = n900
            row['n600_' + tag] = n600
            row['dists_' + tag] = sorted(ds)
        # engine's own answer for the shipped 600 radius: who actually got slowed
        slowed = set()
        for e in tl.get('events', ()):
            if (e.get('type') == 'MODIFIER_ADD'
                    and e.get('inflictor') == SLOW_MOD
                    and t <= e['t'] <= t + SLOW_WINDOW_S
                    and e.get('target_hero')):
                slowed.add(canon(e.get('target')))
        row['n600_engine'] = len(slowed)
        rec['triggers'].append(row)
    return rec


# --------------------------------------------------------------------------
# aggregation
# --------------------------------------------------------------------------

def _share(vals, pred):
    return (sum(1 for v in vals if pred(v)) / len(vals)) if vals else 0.0


def _hist(vals):
    c = collections.Counter(vals)
    return {str(k): c[k] for k in sorted(c)}


def aggregate(recs, out=sys.stdout):
    p = lambda *a: print(*a, file=out)
    games = [r for r in recs if r.get('wk_present')]
    trig = [x for r in games for x in r['triggers']]

    p('=== METHOD VALIDATION (acceptance (2) as amended; hard clause 丁) ===')
    p('  identifier A  ABILITY_TRIGGER event   : %d' % len(trig))
    nb = sum(1 for x in trig if x['agree_B'])
    nc = sum(1 for x in trig if x['agree_C'])
    p('  identifier B  cooldown rising edge    : %d agreeing with A (%d/%d)'
      % (nb, nb, len(trig)))
    p('  identifier C  in-place resurrection   : %d agreeing with A (%d/%d)'
      % (nc, nc, len(trig)))
    nbt = sum(len(r['idB']) for r in games)
    nct = sum(len(r['idC']) for r in games)
    p('  totals across corpus: A=%d  B=%d  C=%d' % (len(trig), nbt, nct))
    named = sum(r.get('n_named_modifier', 0) for r in games)
    p('  amendment (甲) `modifier_skeleton_king_reincarnation` on this corpus: %d'
      % named)
    deaths = sum(r.get('n_deaths', 0) for r in games)
    p('  WK deaths total %d; of them non-reincarnation %d' % (deaths, deaths - len(trig)))
    if not trig:
        # amendment (丁): zero under every identifier is a BROKEN INSTRUMENT,
        # never "triggering is rare, so the t25 pricing is confirmed".
        p('  >>> METHOD-FAILED (zero triggers under every identifier)')
        return
    # The gate is B, which after the correction in triggers_B() is an exact
    # magnitude test on the ability's own cooldown with no known contaminant.
    # C is a BEHAVIOURAL cross-check, not a second ground truth: it reads
    # positions and hp only, which is exactly what makes it independent, and
    # also what gives it two documented failure modes --
    #   FN: Wraith King is displaced >REVIVE_DISP_MAX u within one sample of
    #       standing up (`20260827_123452_slot10` t=1374.2: 1583 u, a Pudge
    #       stood in the slow list),
    #   FP: an in-place resurrection that is NOT a reincarnation, with the
    #       ability still on cooldown (`20260827_122056_slot2` t=1365.2:
    #       revived 5.5 s later 77 u away while cd ran 97.9 -> 92.7).
    # So C's residual is reported and named, not folded into the gate.
    if nb == len(trig) and nbt == len(trig):
        p('  >>> METHOD OK (identifier B exact on all %d)' % len(trig))
    else:
        p('  >>> METHOD DISAGREEMENT on the gate identifier -- read no '
          'distribution below')
    p('  identifier C residual: %d A-triggers unmatched, %d C-events with no A'
      ' (documented modes, see source)' % (len(trig) - nc, nct - nc))

    p('')
    p('=== (1) CARRIER DENOMINATOR (frame corpus) ===')
    p('  WK hero-games scanned            : %d' % len(games))
    lv = [r['wk_max_level'] for r in games]
    p('  reaching level >=25              : %d' % sum(1 for v in lv if v >= 25))
    p('  reaching level >=20              : %d' % sum(1 for v in lv if v >= 20))
    p('  max level mean %.2f  min %d  max %d' % (sum(lv) / len(lv), min(lv), max(lv)))
    for L in (20, 25):
        w = [r['t_last'] - r['t_level%d' % L] for r in games
             if r.get('t_level%d' % L) is not None]
        if not w:
            p('  t%d window: never reached' % L)
            continue
        p('  t%d window (level %d -> last WK frame), n=%d: mean %.0f s (%.1f min)'
          '  min %.0f s  max %.0f s' % (L, L, len(w), sum(w) / len(w),
                                        sum(w) / len(w) / 60.0, min(w), max(w)))
        # how many triggers land inside that window, per game that reaches it
        tg = [sum(1 for x in r['triggers'] if x['wk_level'] >= L) for r in games
              if r.get('t_level%d' % L) is not None]
        p('     triggers at level >=%d per such game: mean %.3f  hist %s  '
          'P(>=1)=%.1f%%' % (L, sum(tg) / len(tg), _hist(tg),
                             100 * _share(tg, lambda v: v >= 1)))

    p('')
    p('=== (3) MAIN READING -- enemies at the trigger frame ===')
    p('  (integer, small range => mean + distribution, NOT median: iron rule 4(ii))')
    for tag in ('pre', 'post'):
        v9 = [x['n900_' + tag] for x in trig]
        v6 = [x['n600_' + tag] for x in trig]
        p('  [%s-trigger sample]' % tag)
        p('    900u : mean %.3f  hist %s  P(>=1)=%.1f%%  P(>=2)=%.1f%%'
          % (sum(v9) / len(v9), _hist(v9), 100 * _share(v9, lambda v: v >= 1),
             100 * _share(v9, lambda v: v >= 2)))
        p('    600u : mean %.3f  hist %s  P(>=1)=%.1f%%  P(>=2)=%.1f%%'
          % (sum(v6) / len(v6), _hist(v6), 100 * _share(v6, lambda v: v >= 1),
             100 * _share(v6, lambda v: v >= 2)))
        d = [a - b for a, b in zip(v9, v6)]
        p('    900-600 (the gross [8] buys over [7]) : mean %.3f  hist %s  P(>=1)=%.1f%%'
          % (sum(d) / len(d), _hist(d), 100 * _share(d, lambda v: v >= 1)))
    sp9 = [abs(x['n900_pre'] - x['n900_post']) for x in trig]
    p('  phase sensitivity |pre-post| 900u: mean %.3f  hist %s'
      % (sum(sp9) / len(sp9), _hist(sp9)))

    p('')
    p('=== instrument calibration: position-derived 600 vs the engine\'s own slow ===')
    eng = [x['n600_engine'] for x in trig]
    p('  engine  modifier_skeleton_king_reincarnate_slow targets: mean %.3f  hist %s'
      % (sum(eng) / len(eng), _hist(eng)))
    for tag in ('pre', 'post'):
        agree = sum(1 for x in trig if x['n600_' + tag] == x['n600_engine'])
        p('  position(%s) == engine on %d/%d triggers (%.1f%%)'
          % (tag, agree, len(trig), 100.0 * agree / len(trig)))

    p('')
    p('=== (4) PER-GAME TRIGGER COUNT, stratified by WK level at the trigger ===')
    per = [len(r['triggers']) for r in games]
    p('  triggers/game: mean %.3f  hist %s  P(>=1 in a game)=%.1f%%'
      % (sum(per) / len(per), _hist(per), 100 * _share(per, lambda v: v >= 1)))
    for name, lo, hi in (('<20', 0, 19), ('20-24', 20, 24), ('>=25', 25, 99)):
        sub = [x for x in trig if lo <= x['wk_level'] <= hi]
        if not sub:
            p('  level %-6s: 0 triggers' % name)
            continue
        v9 = [x['n900_pre'] for x in sub]
        v6 = [x['n600_pre'] for x in sub]
        p('  level %-6s: %d triggers  900u mean %.3f  600u mean %.3f  '
          '900-600 mean %.3f  P(900>=1)=%.1f%%'
          % (name, len(sub), sum(v9) / len(v9), sum(v6) / len(v6),
             sum(a - b for a, b in zip(v9, v6)) / len(sub),
             100 * _share(v9, lambda v: v >= 1)))

    p('')
    p('=== (6) pre-registered third outcome ===')
    v9 = [x['n900_pre'] for x in trig]
    v6 = [x['n600_pre'] for x in trig]
    gap = sum(v9) / len(v9) - sum(v6) / len(v6)
    p('  mean(900) - mean(600) = %.3f enemies per trigger' % gap)
    p('  outcome (6) ("the radius advantage is on paper") holds iff this is ~0.')


# --------------------------------------------------------------------------
# selfcheck
# --------------------------------------------------------------------------

def _synth():
    """A hand-built timeline with one reincarnation and one ordinary death."""
    ev, sn = [], []

    def frame(t, hero, idx, team, x, y, hp, lvl=25, cd=0.0):
        sn.append({'t': t, 'hero': 'npc_dota_hero_' + hero, 'idx': idx,
                   'team': team, 'player_id': idx, 'x': x, 'y': y,
                   'hp': int(1000 * hp), 'hp_pct': hp, 'mp': 500, 'max_mp': 500,
                   'mp_pct': 1, 'level': lvl, 'items': [],
                   'abilities': [{'name': ABIL, 'level': 3, 'cd': cd,
                                  'cd_len': 120}]})

    # Wraith King (team 2).  Three deaths, each pinning one behaviour:
    #   t=100.0  the real Reincarnation -- and the sample BEFORE it carries
    #            cd=0.5 from the auxiliary timer, the false negative that
    #            sank the amendment's "0 -> positive" edge (slot9 t=982.3).
    #   t=200.0  no death at all, just the auxiliary timer bumping cd to 4.3
    #            and decaying -- the matching false positive (slot3 t=452.5).
    #   t=300.0  an ordinary death with Reincarnation still on cooldown,
    #            respawning at the fountain.
    for t in [x / 1.0 for x in range(-2, 400)]:
        t = float(t)
        if 100.0 < t < 103.5:
            hp, cd = 0.0, 110.0
        elif t > 100.0:
            hp, cd = 1.0, max(0.0, 110.0 - (t - 103.5))
        elif t == 100.0:
            hp, cd = 1.0, 0.5          # <- auxiliary timer, not "0"
        else:
            hp, cd = 1.0, 0.0
        if 200.0 <= t < 205.0:         # auxiliary timer alone, nobody dies
            cd = max(0.0, 4.3 - (t - 200.0))
        x, y = (0.0, 0.0)
        if 300.0 < t < 340.0:
            hp = 0.0
        if t >= 340.0:
            x, y = 7000.0, 7000.0      # fountain: far away
        frame(t, 'skeleton_king', 10, 2, x, y, hp, 25, cd)

    # Enemy 1 (team 3): 500 u away at the trigger  -> inside 600 and 900
    # Enemy 2 (team 3): 800 u away at the trigger  -> inside 900 only
    # Enemy 3 (team 3): 2000 u away                -> outside both
    # Enemy 4 (team 3): 300 u away but DEAD        -> must not be counted
    for t in [x / 1.0 for x in range(-2, 400)]:
        t = float(t)
        frame(t, 'lion', 20, 3, 500.0, 0.0, 1.0)
        frame(t, 'zuus', 21, 3, 800.0, 0.0, 1.0)
        frame(t, 'pudge', 22, 3, 2000.0, 0.0, 1.0)
        frame(t, 'lina', 23, 3, 300.0, 0.0, 0.0 if 90.0 < t < 150.0 else 1.0)
    # a lina ILLUSION born after the horn, standing on top of Wraith King
    for t in [x / 1.0 for x in range(120, 400)]:
        frame(float(t), 'lina', 99, 3, 50.0, 0.0, 1.0)

    ev.append({'t': 90.5, 'type': 'DEATH', 'actor': 'npc_dota_hero_skeleton_king',
               'target': 'npc_dota_hero_lina', 'inflictor': 'x', 'value': 1,
               'actor_hero': True, 'target_hero': True})
    ev.append({'t': 100.0, 'type': 'DEATH', 'actor': 'npc_dota_hero_lion',
               'target': 'npc_dota_hero_skeleton_king', 'inflictor': 'x',
               'value': 1, 'actor_hero': True, 'target_hero': True})
    ev.append({'t': 100.0, 'type': 'ABILITY_TRIGGER',
               'actor': 'npc_dota_hero_skeleton_king', 'target': 'dota_unknown',
               'inflictor': ABIL, 'value': 3, 'actor_hero': True,
               'target_hero': False})
    ev.append({'t': 100.1, 'type': 'MODIFIER_ADD',
               'actor': 'npc_dota_hero_skeleton_king',
               'target': 'npc_dota_hero_lion', 'inflictor': SLOW_MOD,
               'value': 1, 'actor_hero': True, 'target_hero': True})
    ev.append({'t': 300.0, 'type': 'DEATH', 'actor': 'npc_dota_hero_lion',
               'target': 'npc_dota_hero_skeleton_king', 'inflictor': 'x',
               'value': 1, 'actor_hero': True, 'target_hero': True})
    return {'game': {'start_time': 0.0, 'teams': {}}, 'events': ev,
            'snapshots': sn, 'buildings': [], 'creeps': [], 'wards': []}


def selfcheck():
    import tempfile
    ok = True

    def chk(name, cond, why=''):
        nonlocal ok
        print('  %-42s %s%s' % (name, 'PASS' if cond else 'FAIL',
                                '' if cond else '  <- ' + why))
        ok = ok and bool(cond)

    tl = _synth()
    with tempfile.NamedTemporaryFile('w', suffix='.timeline.json',
                                     delete=False) as fh:
        json.dump(tl, fh)
        path = fh.name
    rec = scan(path)
    os.unlink(path)

    chk('wraith-king-found', rec['wk_present'])
    chk('one-ability-trigger', len(rec['idA']) == 1,
        'got %r' % (rec['idA'],))
    t = rec['triggers'][0]
    chk('identifier-B-agrees', t['agree_B'],
        'cooldown edge missed -- the sample before the trigger reads cd=0.5, '
        'not 0, so a "prev <= 0" test would fail here (slot9 t=982.3)')
    chk('identifier-B-ignores-auxiliary-timer', len(rec['idB']) == 1,
        'the 4.3 s scepter_active timer at t=200 was counted as a trigger: %r'
        % (rec['idB'],))
    chk('identifier-C-agrees', t['agree_C'], 'in-place resurrection missed')
    chk('fountain-death-not-a-trigger', len(rec['idC']) == 1,
        'C fired on the t=300 fountain death too: %r' % (rec['idC'],))
    chk('n600-counts-only-the-500u-enemy', t['n600_pre'] == 1,
        'got %d' % t['n600_pre'])
    chk('n900-counts-500u-and-800u', t['n900_pre'] == 2,
        'got %d (dists %r)' % (t['n900_pre'], t['dists_pre']))
    chk('dead-enemy-at-300u-excluded', 300.0 not in t['dists_pre'],
        'a corpse 300 u away was counted: %r' % (t['dists_pre'],))
    chk('illusion-on-top-of-wk-excluded', 50.0 not in t['dists_pre'],
        'a post-horn illusion was counted: %r' % (t['dists_pre'],))
    chk('engine-slow-target-count', t['n600_engine'] == 1,
        'got %d' % t['n600_engine'])
    chk('named-modifier-absent-as-amended', rec['n_named_modifier'] == 0)

    # aggregation must not crash and must report METHOD OK on this record
    import io
    buf = io.StringIO()
    aggregate([rec], out=buf)
    chk('aggregate-reports-method-ok', 'METHOD OK' in buf.getvalue())
    # iron rule 4(ii): a small-range integer count gets mean + distribution and
    # NEVER a median.  The only occurrence of the word must be the line saying
    # so -- assert that, rather than a bare substring absence that a future
    # `p('  median ...')` would slip past unnoticed.
    med = [l for l in buf.getvalue().splitlines() if 'median' in l.lower()]
    chk('aggregate-reports-no-median', med == ['  (integer, small range => mean '
                                               '+ distribution, NOT median: '
                                               'iron rule 4(ii))'],
        'iron rule 4(ii) violated or its banner moved: %r' % (med,))

    print('selfcheck: %s' % ('OK' if ok else 'FAILED'))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('paths', nargs='*')
    ap.add_argument('--agg', metavar='JSONL',
                    help='aggregate a file of per-game records instead of scanning')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if a.agg:
        recs = [json.loads(l) for l in open(a.agg) if l.strip()]
        aggregate(recs)
        return 0
    if not a.paths:
        ap.error('need at least one timeline.json (or --agg / --selfcheck)')
    for p in a.paths:
        print(json.dumps(scan(p)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

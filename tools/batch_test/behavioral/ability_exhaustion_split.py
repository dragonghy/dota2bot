#!/usr/bin/env python3
"""Split the skipped-alive band: was a point HELD while a legal visible target existed?

Provenance: the 2026-09-14T13:12Z replay-check round measured 588 skipped-alive
levels over 8 W40 games (skipped_alive_levels.py) and found the holds pile into
hero levels 15-22, ~60 of 80 bodies per level.  That round REFUSED to read the
shape as an explanation, because 15+ is simultaneously where a build runs out of
ability ranks and where talent tiers sit, and the talent blind spot (LIMIT 2
there / LIMIT C here) bites hardest exactly in that band.  Its handoff asked for
the discriminator: "abilities exhausted, only talents left" vs "abilities not
maxed and still not spending".  This is that discriminator.

⚠️ TWO ESTIMATORS WERE BUILT AND THE FIRST ONE WAS WRONG.  Read this before
reusing either, because the wrong one is the more obvious one:

  v1 (DISCARDED) asked "does any ability sit below its corpus-max, over band
  15-22".  It answers 431/463 DEFICIT, and that number is close to VACUOUS:
  mid-climb a build is simply unfinished, so almost every level shows a gap.
  Worse, it read obsidian_destroyer as EXHAUST -- the one body with pinned
  ground truth (2026-09-14T13:12Z, idx=1462, 6 spent points with objurgation at
  rank 0 all game).  No OD in any of the 8 games ever trains objurgation past 0
  or arcane_orb/sanity_eclipse past 1, so corpus-max COLLAPSES ONTO THE STALLED
  VALUE.  ⇒ the estimator is blinded by exactly the pathology it must detect,
  and its blindness is worst on the most-stalled hero.  Kept here as a named
  failure, not deleted, because "corpus-max as a stand-in for max rank" is the
  obvious thing for the next round to reinvent.

  v2 (WHAT THIS TOOL COMPUTES) makes both halves sound instead:
    BASIC-DEFICIT -- restrict the gap to abilities whose corpus-max is >= 4.
        An ability reaching rank 4 anywhere is a 4-rank (basic) ability, and
        every basic rank is unlocked by hero level 7 (Dota tier rule).  Inside
        the band that is TIER-SAFE BY CONSTRUCTION: no row can be "waiting for
        a tier".  The band is also narrowed to 18-22, where the ultimate's
        rank 3 (level 18) is unlocked too, so nothing at all is tier-blocked.
    BANKED -- level - visible_spent - EVERY talent tier reached.  Subtracting
        all tiers grants the invisible-talent story its best case; what is left
        over is banked no matter what was spent on unseen rows.  banked > 0 is
        therefore a LOWER BOUND on points in hand, the same arithmetic the
        13:12Z round used to pin OD.
  A row is PROVEN only when banked > 0 AND basic-deficit > 0: a point provably
  in hand AND a fully-unlocked visible rank provably unbought.

CUT (iron rule 4(iii) -- quote it with every number this prints):

  body        = (hero name, FIRST idx that name appears), as skipped_alive_levels.py.
                Keying by name alone pools illusions/clones and biases holds longer.
  ability     = ledger entry whose name does not start with 'special_bonus'.
  corpus-max  = highest level an ability NAME reaches on any body in the games
                passed to THIS run.  A lower bound on true max rank -- see v1.
  BASIC       = ability whose corpus-max >= 4.
  skipped-alive = complete level, no ability-ledger movement, hp_pct > 0 on
                every frame of it.  The body's top level is dropped (the game
                ended inside it).
  banked      = level - sum(visible ability ranks) - #{tiers 10,15,20,25 <= level}.
  release     = the hero level at the first ability spend that ENDS a body's
                longest ability-spend silence.

⛔ LIMIT A -- BANKED IS NOT DEFINED WHEN THE VISIBLE COUNT IS INFLATED.  A
chained ability rises several ranks on one point (nevermore's shadowraze1/2/3;
recorded 2026-09-14T09:49Z as "account 23 = 15 actually spent").  Those bodies
print banked < 0, which is the DETECTOR of the inflation, not a reading: this
tool excludes them rather than repairing them.  Measured on W40: all 35 negative
rows are nevermore.

⛔ LIMIT B -- this counts the HOLD, not a wasted point.  "Held at level 19 and
spent at 23" is a delay, and a delay is what is measured; do not upgrade it into
"N points were thrown away".

⛔ LIMIT C -- the talent blind spot applies to the SPEND side.  A point spent on
a hero-UNIQUE talent row raises nothing the dumper can see (GH #817,
tests/test_talent_uptake_visibility.lua).  BANKED is built to survive this --
it already concedes every tier -- but a per-level "did it spend here" answer is
still blind at 20.  Levels 18,19,21,22 are not talent tiers and are the clean
subset.

⛔ LIMIT D -- whole-roster census on one tree, both teams every game.  No
armed/baseline leg exists, so there is no ab/ba stratification (iron rule
4(i-a)): registered as "no ab/ba reading", not as a balanced one.  Anyone
comparing this against an armed wave must re-stratify from scratch.
"""
import json
import sys
from collections import defaultdict, Counter

FULL = 'npc_dota_hero_'
TALENT = 'special_bonus'
TIERS = (10, 15, 20, 25)


def _abilities(s):
    return {a['name']: a['level']
            for a in (s.get('abilities') or [])
            if not a['name'].startswith(TALENT)}


def bodies(path):
    d = json.load(open(path))
    first = {}
    for s in d['snapshots']:
        first.setdefault(s['hero'], s['idx'])
    per = defaultdict(list)
    for s in d['snapshots']:
        if s['idx'] == first[s['hero']]:
            per[s['hero']].append(s)
    for frames in per.values():
        frames.sort(key=lambda x: x['t'])
    return first, per


def _tiers_reached(lvl):
    return sum(1 for t in TIERS if lvl >= t)


def scan(paths, lo=18, hi=22):
    corpus = defaultdict(int)
    games = []
    for p in paths:
        first, per = bodies(p)
        games.append((p, first, per))
        for frames in per.values():
            for f in frames:
                for n, l in _abilities(f).items():
                    corpus[n] = max(corpus[n], l)
    basic = {n for n, v in corpus.items() if v >= 4}

    rows, releases = [], []
    for p, first, per in games:
        game = p.split('/')[-1].replace('.timeline.json', '')
        for hero, frames in per.items():
            moves, prev = [], None
            for f in frames:
                L = _abilities(f)
                if prev is not None and any(v > prev.get(k, 0) for k, v in L.items()):
                    moves.append((f['t'], f['level']))
                prev = L
            if len(moves) >= 2:
                k = max(range(1, len(moves)), key=lambda i: moves[i][0] - moves[i - 1][0])
                releases.append(dict(game=game, hero=hero.replace(FULL, ''), idx=first[hero],
                                     silence=round(moves[k][0] - moves[k - 1][0], 1),
                                     t0=moves[k - 1][0], lvl0=moves[k - 1][1],
                                     t1=moves[k][0], release=moves[k][1]))
            bylvl = defaultdict(list)
            for f in frames:
                bylvl[f['level']].append(f)
            top = max(bylvl)
            spent_at = {l for _, l in moves}
            for lvl in sorted(bylvl):
                if lvl >= top or not (lo <= lvl <= hi):
                    continue
                g = bylvl[lvl]
                if lvl in spent_at or any(x['hp_pct'] <= 0 for x in g):
                    continue
                led = [x for x in g if x.get('abilities')]
                if not led:
                    continue
                L = _abilities(led[-1])
                gaps = {n: corpus[n] - v for n, v in L.items() if n in basic and corpus[n] > v}
                rows.append(dict(game=game, hero=hero.replace(FULL, ''), idx=first[hero],
                                 level=lvl, t=led[-1]['t'], visible=sum(L.values()),
                                 banked=lvl - sum(L.values()) - _tiers_reached(lvl),
                                 deficit=sum(gaps.values()), gaps=gaps))
    return rows, releases, corpus, basic


def main(paths, lo=18, hi=22):
    rows, releases, corpus, basic = scan(paths, lo, hi)
    proven = [r for r in rows if r['banked'] > 0 and r['deficit'] > 0]
    inflated = [r for r in rows if r['banked'] < 0]

    print('games %d   band %d-%d   BASIC names (corpus-max>=4) %d' % (len(paths), lo, hi, len(basic)))
    print('skipped-alive rows in band            %4d' % len(rows))
    print('  PROVEN held (banked>0 AND basic gap) %4d  <- point in hand AND an unlocked rank unbought'
          % len(proven))
    print('  banked>0 but NO basic gap seen       %4d  <- INDETERMINATE: corpus-max may be blind (v1 note)'
          % sum(1 for r in rows if r['banked'] > 0 and r['deficit'] == 0))
    print('  banked==0 (tiers exactly account)    %4d' % sum(1 for r in rows if r['banked'] == 0))
    print('  banked<0  = INFLATED visible count   %4d  <- LIMIT A, excluded not repaired' % len(inflated))

    ph = defaultdict(lambda: [0, 0])
    for r in rows:
        ph[r['hero']][0 if (r['banked'] > 0 and r['deficit'] > 0) else 1] += 1
    print('\nper hero: PROVEN / not-proven   (⛔ NOT comparable across heroes -- LIMIT C)')
    for h, (a, b) in sorted(ph.items(), key=lambda kv: -kv[1][0]):
        print('  %-24s %3d / %-3d' % (h, a, b))

    print('\nwhich BASIC carries the gap (rows):')
    for n, k in Counter(n for r in proven for n in r['gaps']).most_common(12):
        print('  %-45s %3d   corpus_max=%d' % (n, k, corpus[n]))

    if releases:
        sil = sorted(r['silence'] for r in releases)
        long = [r for r in releases if r['silence'] >= 300]
        print('\nlongest ability-spend silence per body: median %.1f s, max %.1f s; >=300s on %d/%d bodies'
              % (sil[len(sil) // 2], sil[-1], len(long), len(releases)))
        print('release hero level after a >=300s silence:',
              sorted(Counter(r['release'] for r in long).items()))
        print('\ntop silences:')
        for r in sorted(long, key=lambda r: -r['silence'])[:10]:
            print('  %-26s %-20s idx=%-6s %6.1fs  t=%.1f(lvl%d) -> t=%.1f(lvl%d)'
                  % (r['game'], r['hero'], r['idx'], r['silence'], r['t0'], r['lvl0'], r['t1'], r['release']))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    band = [a for a in sys.argv[1:] if a.startswith('--band=')]
    lo, hi = (18, 22)
    if band:
        lo, hi = (int(x) for x in band[0].split('=')[1].split('-'))
    if not args:
        raise SystemExit('usage: ability_exhaustion_split.py <timeline.json> [...] [--band=18-22]')
    main(args, lo, hi)

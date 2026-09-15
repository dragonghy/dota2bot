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

  body        = (hero name, LONGEST-LIVED idx for that name).  ⚠️ CHANGED
                2026-09-14T21:xxZ: it used to be the FIRST idx the name appears
                at.  Keying by name alone pools illusions/clones and biases
                holds longer, but "which idx" is itself a choice and this repo
                held three different answers to it -- see LIMIT E.
  ability     = ledger entry whose name does not start with 'special_bonus'.
  corpus-max  = highest level an ability NAME reaches on any body in the games
                passed to THIS run.  A lower bound on true max rank -- see v1.
  BASIC       = ability whose corpus-max >= 4.
  skipped-alive = complete level, no ability-ledger movement, hp_pct > 0 on
                every frame of it.  The body's top level is dropped (the game
                ended inside it).
  free        = max(sum of visible ranks over the body's HERO-LEVEL-1 frames)-1,
                clamped at >= 0; 0 when the body has no level-1 window.  A LOWER
                bound on the ranks the engine handed this body for free
                (innates, and the first point of a linked group).  Measured, not
                tabled -- free_rank_census.py, GH #822.
  banked      = level - (sum(visible ability ranks) - free)
                      - #{tiers 10,15,20,25 <= level}.
                ⚠️ CHANGED 2026-09-14T21:xxZ: the `- free` term is new.  Before
                it, every innate row was charged to the hero as a spent point.
  release     = the hero level at the first ability spend that ENDS a body's
                longest ability-spend silence.

⭐ WHY THE `- free` TERM IS SOUND, AND WHICH WAY IT CAN ONLY ERR.  free is a
LOWER bound on the free ranks, so (visible - free) is an UPPER bound on the
points actually spent, so banked is a LOWER bound on the points actually in
hand.  ⇒ every PROVEN row stays PROVEN when the instrument improves; the
correction can only ADD rows, never retract one.  That direction is why the
GH #822 headline (`PROVEN 229`) survived being measured with the uncorrected
sum: it was a lower bound then and it is a lower bound now.

⛔ LIMIT A -- BANKED IS NOT DEFINED WHEN THE VISIBLE COUNT IS INFLATED.  A
chained ability rises several ranks on one point (nevermore's shadowraze1/2/3;
recorded 2026-09-14T09:49Z as "account 23 = 15 actually spent").  Those bodies
print banked < 0, which is the DETECTOR of the inflation, not a reading: this
tool excludes them rather than repairing them.  Measured on W40 BEFORE the free
term: all 35 negative rows are nevermore.
⚠️ THE `free` TERM DOES NOT REPAIR LIMIT A, AND EXPECTING IT TO IS THE TRAP.
free is read at hero level 1, where a linked group has been raised ONCE: it
buys back 2 of nevermore's ranks and no more, while the inflation GROWS with
every further point into the group (3 points -> 9 visible ranks -> 6 inflated).
So a linked body stays detectable; it just sits 2 closer to zero.  Read a
surviving banked < 0 as "still inflated", never as "now accounted".

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

⛔ LIMIT E -- "KEY BY idx" IS NECESSARY AND NOT SUFFICIENT; WHICH idx IS A
CHOICE.  This file used to take the FIRST idx a hero name appears at.  That is
one of three answers living in this repo (`min(idx)` -- a named failure in
free_rank_census.py LIMIT 3; "first appearance" -- here; "longest-lived" --
make_fixture.py, the only sound one, because an illusion is short-lived and its
level never moves).  It now uses longest-lived.  ⭐ On the W40 corpus the two
choices select the SAME body for all 80 bodies -- MEASURED in the
2026-09-14T21:xxZ round (report §3), not asserted by the test, which separates
the two RULES on a synthetic illusion instead (the corpus cannot separate them
and so cannot certify the rule).  So this change moved no number here; it is
made because on the next corpus, where an illusion may well appear first, the
old rule would read an illusion's frozen ledger as a hero's.
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
    """(chosen idx per hero name, frames of that body).  LIMIT E: longest-lived."""
    d = json.load(open(path))
    byidx = defaultdict(list)
    for s in d['snapshots']:
        byidx[(s['hero'], s['idx'])].append(s)
    chosen, per = {}, {}
    # sorted(), not a set walk: str hashing is randomized per process, so an
    # unsorted walk makes the per-hero table's TIE ORDER move between runs of
    # the same corpus -- a diff that looks like a finding and is not.
    for hero in sorted({h for (h, _) in byidx}):
        idxs = [i for (h, i) in byidx if h == hero]
        idx = max(idxs, key=lambda i: len(byidx[(hero, i)]))
        chosen[hero] = idx
        per[hero] = sorted(byidx[(hero, idx)], key=lambda x: x['t'])
    return chosen, per


def free_ranks(frames):
    """Free ranks this body carries, LOWER bound, read at hero level 1 (GH #822).

    At hero level 1 the engine has granted exactly one point, so any visible
    rank beyond the first was handed out (innate row, or the extra rows of a
    linked group).  Returns 0 -- never a guess -- when the dump has no level-1
    frame for the body; 0 is still a valid lower bound, so `banked` stays a
    lower bound either way.  The second return value says which it was, so a
    caller can register the missing window instead of silently pooling it.
    """
    lvl1 = [f for f in frames if f.get('level') == 1 and f.get('abilities')]
    if not lvl1:
        return 0, False
    return max(0, max(sum(_abilities(f).values()) for f in lvl1) - 1), True


def is_linked(frames):
    """True when this body's free ranks come from a LINKED group, not an innate.

    ⭐ The discriminator is read off the frames, needs no table of innates, and
    is the reason the `free` term does not quietly disarm LIMIT A.  At hero
    level 1 exactly one point has been spent, so of the rows standing then:
      * an INNATE row never moves again for the rest of the game;
      * a LINKED group moves in lockstep, every member rising on every later
        point into the group.
    So "two or more of the level-1 standing rows move later" is exactly the
    linked case.  Measured on W40: the five innate carriers (VS revenge, WD
    gris_gris, SK innate_vampiric_spirit, BB prickly, SS fowl_play) each move
    ONE row later (the bought one); nevermore moves all three shadowrazes, 1->4
    together.  ⛔ On a linked body the inflation GROWS with every point, so
    banked <= 0 there means "still inflated", never "accounted for".
    """
    lvl1 = [f for f in frames if f.get('level') == 1 and f.get('abilities')]
    if not lvl1:
        return False
    best = max(lvl1, key=lambda f: sum(_abilities(f).values()))
    standing = {k for k, v in _abilities(best).items() if v > 0}
    top = defaultdict(int)
    for f in frames:
        for n, l in _abilities(f).items():
            top[n] = max(top[n], l)
    at_best = _abilities(best)
    return sum(1 for k in standing if top[k] > at_best[k]) >= 2


def linked_group(frames):
    """The LINKED group's member names and its free innate ranks, or (None, 0).

    is_linked() answers "is this body inflated"; this answers "by how much",
    which is what LIMIT A said could not be repaired by `free`.  The repair is
    division, not subtraction: a linked group rises as ONE ability, so the
    points ever put into it equal the COMMON rank, i.e. group_sum // size, at
    every level -- whereas `free` subtracts a constant 2 read at level 1 and so
    falls further behind with every further point (LIMIT A, verbatim).

    ⛔ THE DIVISION IS ONLY LICENSED BY LOCKSTEP, SO LOCKSTEP IS CHECKED, NOT
    ASSUMED.  If any frame ever shows two members of the group at different
    ranks, group_sum/size is not a rank and this returns (None, 0) -- the body
    stays an excluded LIMIT A row, which is the conservative outcome.  Measured
    on W40: 8/8 nevermore bodies, group size 3, frames-with-unequal-ranks 0.

    Second return value is the body's INNATE free ranks: level-1 standing rows
    that are NOT in the group.  At level 1 exactly one point has been spent and
    (given a group) it went into the group, so every other standing rank was
    handed over.  ⚠️ On W40 this is 0 for all 8 linked bodies -- no nevermore
    carries an innate -- so that term is UNEXERCISED BY THIS CORPUS and is
    written for the next one; do not cite it as measured.
    """
    lvl1 = [f for f in frames if f.get('level') == 1 and f.get('abilities')]
    if not lvl1:
        return None, 0
    best = max(lvl1, key=lambda f: sum(_abilities(f).values()))
    at_best = _abilities(best)
    standing = {k for k, v in at_best.items() if v > 0}
    top = defaultdict(int)
    for f in frames:
        for n, l in _abilities(f).items():
            top[n] = max(top[n], l)
    group = {k for k in standing if top[k] > at_best[k]}
    if len(group) < 2:
        return None, 0
    for f in frames:
        L = _abilities(f)
        if L and len({L.get(k, 0) for k in group}) > 1:
            return None, 0          # not lockstep -> no licence to divide
    return group, sum(at_best[k] for k in standing - group)


def deflated_spent(ledger, group, innate):
    """Points this ledger proves were SPENT, with a linked group counted once.

    group_sum is divisible by len(group) because linked_group() verified
    lockstep; // is exact there, and is used rather than / so a future
    non-lockstep caller gets an integer it can be challenged on.
    """
    gsum = sum(v for k, v in ledger.items() if k in group)
    return sum(ledger.values()) - gsum + gsum // len(group) - innate


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

    rows, releases, nowindow = [], [], []
    for p, first, per in games:
        game = p.split('/')[-1].replace('.timeline.json', '')
        for hero, frames in per.items():
            free, had_window = free_ranks(frames)
            linked = is_linked(frames)
            group, innate = linked_group(frames)
            if not had_window:
                nowindow.append((game, hero.replace(FULL, ''), first[hero]))
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
                visible = sum(L.values())
                # On a linked body the group DIVISION replaces the `free`
                # subtraction; applying both would credit the level-1 extra
                # ranks twice.  banked_free is kept alongside so the GH #822
                # reading stays auditable next to the deflated one.
                spent = (deflated_spent(L, group, innate) if group
                         else visible - free)
                rows.append(dict(game=game, hero=hero.replace(FULL, ''), idx=first[hero],
                                 level=lvl, t=led[-1]['t'], visible=visible,
                                 free=free, free_window=had_window, linked=linked,
                                 group=sorted(group) if group else [],
                                 spent=spent,
                                 banked=lvl - spent - _tiers_reached(lvl),
                                 banked_free=lvl - (visible - free) - _tiers_reached(lvl),
                                 banked_raw=lvl - visible - _tiers_reached(lvl),
                                 deficit=sum(gaps.values()), gaps=gaps))
    return rows, releases, corpus, basic, nowindow


def _split(rows, key):
    return (sum(1 for r in rows if r[key] > 0 and r['deficit'] > 0),
            sum(1 for r in rows if r[key] > 0 and r['deficit'] == 0),
            sum(1 for r in rows if r[key] == 0),
            sum(1 for r in rows if r[key] < 0))


def main(paths, lo=18, hi=22):
    rows, releases, corpus, basic, nowindow = scan(paths, lo, hi)
    proven = [r for r in rows if r['banked'] > 0 and r['deficit'] > 0]
    inflated = [r for r in rows if r['banked'] < 0]
    raw = _split(rows, 'banked_raw')

    print('games %d   band %d-%d   BASIC names (corpus-max>=4) %d' % (len(paths), lo, hi, len(basic)))
    print('skipped-alive rows in band            %4d' % len(rows))
    print('  PROVEN held (banked>0 AND basic gap) %4d  <- point in hand AND an unlocked rank unbought'
          % len(proven))
    print('  banked>0 but NO basic gap seen       %4d  <- INDETERMINATE: corpus-max may be blind (v1 note)'
          % sum(1 for r in rows if r['banked'] > 0 and r['deficit'] == 0))
    zero_clean = sum(1 for r in rows if r['banked'] == 0 and not r['linked'])
    zero_linked = sum(1 for r in rows if r['banked'] == 0 and r['linked'])
    print('  banked==0 (tiers exactly account)    %4d  <- of which on a LINKED body: %d (NOT accounted)'
          % (zero_clean + zero_linked, zero_linked))
    print('  banked<0  = INFLATED visible count   %4d  <- LIMIT A, still inflated, NOT repaired by `free`'
          % len(inflated))
    print('  on a LINKED body, any sign           %4d  <- the sign-free detector; see is_linked()'
          % sum(1 for r in rows if r['linked']))

    # The free-rank correction, shown as a delta so the pre-GH#822 reading stays
    # auditable next to the corrected one (iron rule 4(iii): the cut travels).
    carry = [r for r in rows if r['free'] > 0]
    print('\nfree-rank correction (GH #822; `banked` = level - (visible - free) - tiers):')
    print('  rows whose body carries free ranks   %4d / %d' % (len(carry), len(rows)))
    print('  rows with NO level-1 window (free:=0) %4d  <- lower bound preserved, not a guess'
          % sum(1 for r in rows if not r['free_window']))
    print('  UNCORRECTED split for comparison: PROVEN %d / INDETERMINATE %d / zero %d / inflated %d'
          % raw)
    print('  ⭐ direction: free >= 0, so banked only RISES; a PROVEN row can never be retracted.')

    # The linked-group deflation (LIMIT A's repair).  Printed as a DELTA against
    # the free-only reading so both cuts travel together (iron rule 4(iii)).
    lk = [r for r in rows if r['group']]
    if lk:
        fp = sum(1 for r in lk if r['banked_free'] > 0 and r['deficit'] > 0)
        dp = sum(1 for r in lk if r['banked'] > 0 and r['deficit'] > 0)
        print('\nlinked-group deflation (LIMIT A repaired by DIVISION, not subtraction):')
        print('  linked rows                          %4d  group(s)=%s'
              % (len(lk), sorted({tuple(r['group']) for r in lk})[0]))
        print('  under `free` only : PROVEN %3d   banked>0 %3d  ==0 %3d  <0 %3d'
              % (fp, sum(1 for r in lk if r['banked_free'] > 0),
                 sum(1 for r in lk if r['banked_free'] == 0),
                 sum(1 for r in lk if r['banked_free'] < 0)))
        print('  under DEFLATION   : PROVEN %3d   banked>0 %3d  ==0 %3d  <0 %3d'
              % (dp, sum(1 for r in lk if r['banked'] > 0),
                 sum(1 for r in lk if r['banked'] == 0),
                 sum(1 for r in lk if r['banked'] < 0)))
        bk = sorted(r['banked'] for r in lk)
        print('  deflated banked: min %d  median %d  max %d   (⚠️ 4(ii): distribution, %s)'
              % (bk[0], bk[len(bk) // 2], bk[-1],
                 ' '.join('%d:%d' % (v, bk.count(v)) for v in sorted(set(bk)))))
        print('  ⭐ direction: group_sum//size <= group_sum - free for every rank >= 1,')
        print('     so deflation only LOWERS spent, only RAISES banked, and like the free')
        print('     term can add PROVEN rows but never retract one.')
    if nowindow:
        print('  bodies with no level-1 window:')
        for g, h, i in nowindow:
            print('    %-26s %-22s idx=%s' % (g, h, i))

    ph = defaultdict(lambda: [0, 0])
    for r in rows:
        ph[r['hero']][0 if (r['banked'] > 0 and r['deficit'] > 0) else 1] += 1
    print('\nper hero: PROVEN / not-proven   (⛔ NOT comparable across heroes -- LIMIT C)')
    for h, (a, b) in sorted(ph.items(), key=lambda kv: (-kv[1][0], kv[0])):
        print('  %-24s %3d / %-3d' % (h, a, b))

    print('\nwhich BASIC carries the gap (rows):')
    for n, k in sorted(Counter(n for r in proven for n in r['gaps']).items(),
                       key=lambda kv: (-kv[1], kv[0]))[:12]:
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

#!/usr/bin/env python3
"""`pullcad` condition (a): DOES THE ARMED LEG ACTUALLY POKE ON A SLOWER BEAT?

WHAT THE CANDIDATE DOES (and it is ONLY this)
---------------------------------------------
`mode_roam_generic.lua:268-271`, inside the lane creep-pull execution branch
(`bot.roamCreepPull ~= nil`, reachable only because `creeppull` is PROMOTED and
therefore live on BOTH legs of a mirrored game):

    local nBeat = 1.2
    if J.IsSoakCandidate('pullcad') then
        nBeat = 3.0
    end
    if bot.creepPullAttackTime == nil or (now - bot.creepPullAttackTime) > nBeat then
        bot:Action_AttackUnit(pull.enemy, true)          -- the POKE
        bot.creepPullAttackTime = now
    elseif (now - bot.creepPullAttackTime) < 0.5 then
        -- promoted 'pullbeat': issue NO order for one attack wind-up
    else
        bot:Action_MoveToLocation(pull.retreat)          -- the DRAG
    end

The candidate changes ONE number: the minimum spacing between two consecutive
aggro pokes at the same enemy hero, 1.2 s -> 3.0 s.  It does not change whether
the pull happens, who is poked, or where the drag goes.  So (a) is a TIMING
question, and it is answerable off the combat log without any counterfactual:

    on the armed leg, are consecutive pokes at the pull target >= ~3 s apart,
    while the baseline leg's are ~1.2 s apart?

WHY THIS IS BUYABLE AT ALL (contrast with `wkqdmg`, GH #310)
------------------------------------------------------------
The 1 Hz snapshot stream cannot resolve a 1.2 s beat -- but the poke is not read
off snapshots.  DAMAGE events carry their own combat-log timestamps at **0.1 s**
resolution, i.e. 12 ticks inside the shipped beat and 30 inside the armed one.
The instrument is a factor of 12 finer than the quantity, which is exactly the
condition `wkqdmg` failed (there the target's EHP moved a full decision band
inside ONE 1 Hz interval).  This is why `pullcad` is worth a round and that one
was not.

THE MEASURED QUANTITY
---------------------
Within a creep-pull episode (the domain of `creeppull_domain.py`, a deliberate
SUPERSET of the Lua gate), the ordered times at which the puller lands a
RIGHT-CLICK on the aggro target, and the gaps between them.  One armed beat can
land at most one attack: the wind-up hold runs 0.5 s and every frame after it
re-issues Action_MoveToLocation, which cancels an attack that has not started.

    gap < 2.0 s   ==> a second poke arrived inside a 3.0 s beat.
                      STRUCTURALLY IMPOSSIBLE for the armed cadence to author.
    gap ~ 1.2 s   ==> the shipped cadence, as authored.
    gap ~ 3.0 s   ==> the armed cadence, as authored.

`SHORT_MAX` (2.0 s) sits between the two authored beats with >= 0.8 s of margin
on each side -- 8 combat-log ticks -- so no rounding, no sampling phase and no
one-tick jitter can move a gap across it.

WHAT A DIFFERENCE HERE CAN AND CANNOT MEAN
------------------------------------------
Both legs run the same promoted pull, in the same game, on mirrored drafts.  The
domain is a superset of the Lua gate (three source clauses are not observable
offline), so ordinary lane harassment leaks into BOTH legs' windows equally.
That leak can only DILUTE a real difference; it cannot manufacture one.  Hence:

  * a large, same-signed drop in `short_share` on the armed leg in BOTH ab and
    ba strata  ==> the gate is reaching the code and changing the cadence
                   (condition (a) WORKING, at the trigger level);
  * armed `short_share` indistinguishable from baseline  ==> BUGGY or SILENT,
    and the NEGATIVE CONTROL below says which;
  * no episodes / no pokes at all  ==> SILENT, domain-empty.

NEGATIVE CONTROL (in the same run, not a separate argument)
-----------------------------------------------------------
The same hero's right-clicks at the same enemy heroes OUTSIDE any pull episode.
`pullcad` cannot touch those -- it lives inside the `roamCreepPull` branch.  If
the armed/baseline split appears there too, the discriminator is reading some
other armed id (44 others are co-armed) or a side effect, NOT this one, and the
in-domain reading must not be attributed to `pullcad`.  This is the charter's
co-armed attribution discipline (§4a) discharged by construction rather than by
prose: the control shares the wave, the game, the hero and the target, and
differs only by being outside the branch the candidate lives in.

STRATIFICATION (铁律 4(i))
--------------------------
Every reading is printed for the `ab` (radiant armed) and `ba` (dire armed)
strata separately.  Two strata that disagree in SIGN are noise and do not enter
a conclusion.

Usage:
    pullcad_beat.py <sweep_dir> [<sweep_dir> ...] [--wave LABEL] [--selfcheck]
                    [--episodes N]

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creeppull_domain import (  # noqa: E402
    Game, canon, dist, episodes, load_sweep, scan_game)

# A right-click in this dumper's combat log carries no ability/item inflictor;
# the dumper renders that as the literal 'dota_unknown'.  Asserted on real data
# by --selfcheck (a hero's melee last-hits are all of this kind), never assumed.
ATTACK_INFLICTORS = ('dota_unknown', None, '')

SHORT_MAX = 2.0        # a gap below this cannot come from a 3.0 s beat
BEAT_SHIPPED = 1.2
BEAT_ARMED = 3.0
EP_PRE = 1.0           # the poke that OPENS an episode lands just before it
EP_POST = 3.0          # ...and the last drag runs one beat past the last frame
CTRL_PAD = 6.0         # keep the control this far away from any episode
STILL_U = 50.0         # 1 Hz path length below which the hero did not walk


def poke_times(g, hero, tgt, t0, t1):
    """Right-click landings by `hero` on `tgt` inside [t0, t1], 0.1 s log time."""
    out = []
    for e in g.raw_events:
        if e['t'] < t0:
            continue
        if e['t'] > t1:
            break
        if (e['type'] == 'DAMAGE' and e.get('actor_hero') and e.get('target_hero')
                and e.get('inflictor') in ATTACK_INFLICTORS
                and canon(e.get('actor')) == canon(hero)
                and canon(e.get('target')) == canon(tgt)):
            out.append(e['t'])
    return sorted(out)


def gaps_of(ts):
    return [round(b - a, 4) for a, b in zip(ts, ts[1:])]


def bucket(gp):
    if gp < 0.6:
        return '<0.6'
    if gp < SHORT_MAX:
        return '0.6-2.0'
    if gp < 2.6:
        return '2.0-2.6'
    if gp < 3.6:
        return '2.6-3.6'
    return '>=3.6'


class Acc:
    def __init__(self):
        self.eps = 0
        self.pokes = 0
        self.gaps = []
        self.buckets = defaultdict(int)
        self.eps_with_short = 0

    def add_episode(self, ts):
        self.eps += 1
        self.pokes += len(ts)
        gs = gaps_of(ts)
        self.gaps.extend(gs)
        for gp in gs:
            self.buckets[bucket(gp)] += 1
        if any(gp < SHORT_MAX for gp in gs):
            self.eps_with_short += 1

    @property
    def short(self):
        return sum(1 for gp in self.gaps if gp < SHORT_MAX)

    @property
    def short_share(self):
        return (100.0 * self.short / len(self.gaps)) if self.gaps else float('nan')

    @property
    def mean_gap(self):
        return (sum(self.gaps) / len(self.gaps)) if self.gaps else float('nan')


def collect(games, keep_examples=0):
    """Returns (in_domain, control) -- each {(stratum, leg): Acc} -- plus examples."""
    dom = defaultdict(Acc)
    ctl = defaultdict(Acc)
    examples = []
    for g, name, seed, stratum in games:
        rows = scan_game(g, name, seed)
        eps = episodes(rows)
        # episode windows per hero, so the control can avoid them
        windows = defaultdict(list)
        for ep in eps:
            hero = ep[0]['hero']
            windows[hero].append((ep[0]['t'] - EP_PRE, ep[-1]['t'] + EP_POST))
        for ep in eps:
            hero = ep[0]['hero']
            leg = ep[0]['leg']
            t0, t1 = ep[0]['t'] - EP_PRE, ep[-1]['t'] + EP_POST
            # the aggro target(s) the domain identified across this episode
            for tgt in sorted({r['tgt'] for r in ep}):
                ts = poke_times(g, hero, tgt, t0, t1)
                if len(ts) < 2:
                    # a lone poke has no gap; it still counts as an episode-leg
                    # observation so `pokes` and `eps` stay honest
                    dom[(stratum, leg)].add_episode(ts)
                    continue
                dom[(stratum, leg)].add_episode(ts)
                if keep_examples and len(examples) < keep_examples:
                    examples.append(dict(
                        game=name, seed=seed, stratum=stratum, leg=leg,
                        hero=canon(hero), tgt=canon(tgt), pos=ep[0]['pos'],
                        t0=round(t0, 1), t1=round(t1, 1),
                        pokes=ts, gaps=gaps_of(ts),
                        drag=max(r['drag'] for r in ep),
                        pull=any(r['pull'] for r in ep)))
        # --- negative control: same heroes, same enemies, OUTSIDE every episode
        for hero, team in g.teams.items():
            leg = g.leg(hero)
            wins = windows.get(hero, [])
            for tgt, tteam in g.teams.items():
                if tteam == team:
                    continue
                ts = [t for t in poke_times(g, hero, tgt, 0.0, 360.0)
                      if not any(a - CTRL_PAD <= t <= b + CTRL_PAD for a, b in wins)]
                if ts:
                    ctl[(stratum, leg)].add_episode(ts)
    return dom, ctl, examples


def stillness(games):
    """WAS THE PULLER MOVING BETWEEN TWO CONSECUTIVE POKES?

    This is the discriminator that decides whether the poke channel is the
    BRANCH at all, and it is not optional prose -- it is the thing that turns
    "the armed leg carries sub-2 s gaps" from a verdict into a question.

    The branch cannot be silent about movement: between pokes it issues
    Action_MoveToLocation(pull.retreat) on EVERY frame from 0.5 s after the
    poke until nBeat -- 2.5 of every 3.0 s armed, 0.7 of every 1.2 s shipped.
    So a poke pair that brackets a STATIONARY hero was authored by neither
    cadence; it is an ordinary standing lane trade that the (deliberately
    superset) domain let in.  Path length is summed over the 1 Hz frames, so
    it under-reads a walk that leaves and returns inside one second -- which
    makes `still` an UNDER-count of the non-branch population, never an over-
    count.
    """
    out = defaultdict(lambda: [0, 0, 0, 0])   # short, short_still, long, long_still
    per_game = defaultdict(lambda: [0, 0])
    for g, name, seed, stratum in games:
        for ep in episodes(scan_game(g, name, seed)):
            hero, leg = ep[0]['hero'], ep[0]['leg']
            t0, t1 = ep[0]['t'] - EP_PRE, ep[-1]['t'] + EP_POST
            fr = g.frames[hero]
            for tgt in sorted({r['tgt'] for r in ep}):
                ts = poke_times(g, hero, tgt, t0, t1)
                for a, b in zip(ts, ts[1:]):
                    pts = [fr[t] for t in sorted(fr)
                           if a - 0.6 <= t <= b + 0.6 and fr[t]['hp_pct'] > 0]
                    if len(pts) < 2:
                        continue
                    path = sum(dist(p['x'], p['y'], q['x'], q['y'])
                               for p, q in zip(pts, pts[1:]))
                    i = 0 if (b - a) < SHORT_MAX else 2
                    out[(stratum, leg)][i] += 1
                    per_game[(name, leg)][0] += 1
                    if path < STILL_U:
                        out[(stratum, leg)][i + 1] += 1
                        per_game[(name, leg)][1] += 1
    print('\nSTILLNESS -- 1 Hz path length between the two pokes (still < %.0f u)'
          % STILL_U)
    print('%-4s %-9s %9s %15s %9s %15s'
          % ('str', 'leg', 'short<2s', 'of which still', 'long>=2s', 'of which still'))
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            s, ss, l, ls = out[(stratum, leg)]
            print('%-4s %-9s %9d %8d (%4.1f%%) %9d %8d (%4.1f%%)'
                  % (stratum, leg, s, ss, 100.0 * ss / s if s else 0,
                     l, ls, 100.0 * ls / l if l else 0))
    print('\nper game (frame-derived), %d game(s)' % len({k[0] for k in per_game}))
    for k in sorted(per_game):
        n, st = per_game[k]
        print('  %-26s %-9s gaps=%4d still=%4d (%4.1f%%)'
              % (k[0], k[1], n, st, 100.0 * st / n if n else 0))
    return out


def duty(games):
    """THE LEVER'S OWN CLAIMED QUANTITY, measured directly.

    mode_roam_generic.lua:249-251 registers the intended effect as a DUTY
    CYCLE: "the drag owns 2.5s of every 3.0s (83%) against 0.7s of every 1.2s
    (58%)" -- i.e. armed should raise the fountain-ward walk rate of a pull by
    ~43% relative.  `creeppull_domain`'s `drag` field is exactly that rate:
    fountain-ward displacement over the next 3.0 s from a domain frame.  So
    this table is a bound on the lever's observable footprint that needs NO
    channel separation and no counterfactual -- unlike the poke tables above.

    Caveat that must travel with the number (charter §4a): 44 other ids are
    co-armed, so a null here bounds the BUNDLE's footprint on this quantity.
    It bounds `pullcad`'s own only under the assumption that no co-armed id
    cancels it -- state that, do not drop it.
    """
    acc, accP = defaultdict(list), defaultdict(list)
    for g, name, seed, stratum in games:
        for ep in episodes(scan_game(g, name, seed)):
            leg = ep[0]['leg']
            cert = any(r['pull'] for r in ep)
            for r in ep:
                if not r['clean']:
                    continue
                acc[(stratum, leg)].append(r['drag'])
                if cert:
                    accP[(stratum, leg)].append(r['drag'])

    def show(title, a):
        print('\n%s' % title)
        print('%-4s %-9s %8s %8s %8s %8s %8s'
              % ('str', 'leg', 'n', 'mean', 'p50', '>=200u', '>=400u'))
        for stratum in ('ab', 'ba'):
            for leg in ('armed', 'baseline'):
                v = sorted(a[(stratum, leg)])
                if not v:
                    print('%-4s %-9s %8s' % (stratum, leg, '-'))
                    continue
                n = len(v)
                print('%-4s %-9s %8d %8.1f %8.1f %7.1f%% %7.1f%%'
                      % (stratum, leg, n, sum(v) / n, v[n // 2],
                         100.0 * sum(1 for x in v if x >= 200) / n,
                         100.0 * sum(1 for x in v if x >= 400) / n))
    show('DUTY -- fountain-ward displacement over 3.0 s, all clean domain frames',
         acc)
    show('DUTY -- restricted to pull-certified episodes (drag+keep+poke)', accP)
    return acc, accP


def table(title, acc):
    print('\n%s' % title)
    print('%-4s %-9s %7s %7s %7s %9s %9s   %s'
          % ('str', 'leg', 'eps', 'pokes', 'gaps', 'short<2s', 'mean gap', 'buckets'))
    for stratum in ('ab', 'ba'):
        for leg in ('armed', 'baseline'):
            a = acc.get((stratum, leg))
            if a is None:
                print('%-4s %-9s %7s' % (stratum, leg, '-'))
                continue
            bs = ' '.join('%s:%d' % (k, a.buckets[k]) for k in
                          ('<0.6', '0.6-2.0', '2.0-2.6', '2.6-3.6', '>=3.6')
                          if a.buckets[k])
            print('%-4s %-9s %7d %7d %7d %8.1f%% %9.2f   %s'
                  % (stratum, leg, a.eps, a.pokes, len(a.gaps),
                     a.short_share, a.mean_gap, bs))


def selfcheck(games, dom, ctl):
    """Assertions that must hold on REAL data, not on a fixture of my own."""
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    g = games[0][0]
    # 1. 'dota_unknown' really is the right-click channel: every hero in the
    #    corpus authors some, and they land on creeps too (spells that hit
    #    creeps all carry their own inflictor).
    authors, on_creep = set(), 0
    for e in g.raw_events:
        if e['type'] == 'DAMAGE' and e.get('actor_hero') \
                and e.get('inflictor') in ATTACK_INFLICTORS:
            authors.add(canon(e.get('actor')))
            if not e.get('target_hero'):
                on_creep += 1
    chk('attack channel authored by >=8/10 heroes', len(authors) >= 8,
        '%d heroes' % len(authors))
    chk('attack channel also lands on creeps', on_creep > 100, 'n=%d' % on_creep)

    # 2. combat-log time really is 0.1 s, i.e. finer than the beat we resolve.
    ts = sorted({e['t'] for e in g.raw_events})
    fine = sum(1 for a, b in zip(ts, ts[1:]) if 0 < round(b - a, 4) < 0.5)
    chk('log timestamps finer than 0.5 s', fine > 100, 'n=%d' % fine)
    frac = {round(t % 1.0, 4) for t in ts[:4000]}
    chk('log time is not 1 Hz-quantised', len(frac) > 3, '%d distinct fracs'
        % len(frac))

    # 3. SHORT_MAX separates the two authored beats with real margin.
    chk('SHORT_MAX strictly between the two beats',
        BEAT_SHIPPED + 0.5 < SHORT_MAX < BEAT_ARMED - 0.5,
        '%.1f in (%.1f, %.1f)' % (SHORT_MAX, BEAT_SHIPPED, BEAT_ARMED))

    # 4. legs are balanced across the corpus (mirrored device intact).
    legs = defaultdict(int)
    for gg, _, _, _ in games:
        for h in gg.teams:
            legs[gg.leg(h)] += 1
    chk('legs balanced', legs['armed'] == legs['baseline'], dict(legs))

    # 5. both strata present -- 铁律 4(i) cannot be honoured otherwise.
    strata = {s for (s, _) in dom} or {s for (s, _) in ctl}
    chk('both ab and ba strata present', strata >= {'ab', 'ba'}, sorted(strata))

    # 6. the control is not empty (a control that never fires proves nothing).
    ctl_gaps = sum(len(a.gaps) for a in ctl.values())
    chk('negative control non-empty', ctl_gaps > 50, 'gaps=%d' % ctl_gaps)

    # 7. no gap may be negative or zero-length (ordering / dedup sanity).
    bad = [gp for a in list(dom.values()) + list(ctl.values())
           for gp in a.gaps if gp < 0]
    chk('no negative gaps', not bad, '%d bad' % len(bad))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--wave', default='?')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--episodes', type=int, default=0,
                    help='print the first N in-domain episodes frame by frame')
    ap.add_argument('--still', action='store_true',
                    help='did the puller WALK between pokes? (branch or not)')
    ap.add_argument('--duty', action='store_true',
                    help="the lever's own claimed quantity: drag duty cycle")
    a = ap.parse_args()

    games = []
    for d in a.sweeps:
        for m in load_sweep(d):
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                continue
            g = Game(tl, an, m['side'])
            stratum = 'ab' if m['side'] == 'radiant' else 'ba'
            games.append((g, m['game'], m.get('seed'), stratum))
    if not games:
        sys.exit('[fatal] no parsable games in %s' % a.sweeps)

    print('wave=%s  games=%d  (ab=%d, ba=%d)'
          % (a.wave, len(games),
             sum(1 for x in games if x[3] == 'ab'),
             sum(1 for x in games if x[3] == 'ba')))
    dom, ctl, examples = collect(games, keep_examples=a.episodes)

    table('IN DOMAIN -- pokes at the pull target inside creep-pull episodes', dom)
    table('NEGATIVE CONTROL -- same heroes/enemies OUTSIDE every episode', ctl)

    for ex in examples:
        print('\n-- %s s%s [%s/%s] %s -> %s (pos=%s) t=%.1f..%.1f  drag=%s pull=%s'
              % (ex['game'], ex['seed'], ex['stratum'], ex['leg'], ex['hero'],
                 ex['tgt'], ex['pos'], ex['t0'], ex['t1'], ex['drag'], ex['pull']))
        print('   pokes: %s' % ' '.join('%.1f' % t for t in ex['pokes']))
        print('   gaps : %s' % ' '.join('%.1f' % gp for gp in ex['gaps']))

    if a.still:
        stillness(games)
    if a.duty:
        duty(games)

    if a.selfcheck:
        print('\n--- selfcheck (real data) ---')
        if not selfcheck(games, dom, ctl):
            sys.exit(3)
    print('\nOK')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Is the `creeppull` signature SPECIFIC, or does stock laning make it too?

WHY THIS EXISTS.  2026-08-23T09:09Z measured the creep-pull domain over 213
mirrored games and found `core_pull` episodes armed 1,869 : baseline 1,424 =
**1.31x**.  A gate that is OFF on the baseline leg producing 76% of the armed
leg's count means the *metric* is not specific to the behaviour -- the same
reading `pullcamp` earns 10.4x on.  The registered next step was "measure how
many core_pull episodes are accompanied by this hero's own attack on the aggro
target".

That step is a NO-OP and this tool says so up front: `poke` is already a
CONJUNCT of `pull` (`creeppull_domain.py:339`,
`pull = drag >= DRAG_U and keep and poke`), so the answer is 100% by
construction on both legs.  A discriminator cannot be a clause the metric
already requires.  Registered as a trap in the charter.

So this tool tests the two axes that are NOT already inside `pull`, both read
straight off the call site (`mode_roam_generic.lua:185-198`):

  CADENCE   the action alternates `Action_AttackUnit(pull.enemy)` (at most one
            per 1.2 s) with `Action_MoveToLocation(pull.retreat)`, and it
            re-bids every frame the trigger holds.  So an armed pull should be
            a RUN of pull frames, not one.  Stock laning harass-then-reposition
            can manufacture a single frame of "damaged him, then drifted
            homeward 200 u"; sustaining that for 3-4 consecutive samples while
            the enemy wave stays within 900 u is a different claim.
            -> bucket episodes by their pull-frame count, ratio per bucket.

  OUTCOME   the point of the manoeuvre is that the WAVE follows.  Nothing in
            `pull` looks at the creeps' own motion.
            -> displacement of the enemy lane-creep centroid, projected on the
            unit vector toward our fountain, from the episode's first frame to
            its last frame + DRAG_S.

Both are measured per leg on the same games (mirrored draft = free control), so
a ratio well above the 1.31x floor means that slice of the signature really is
armed-specific; a ratio that stays near 1.31x means the extra structure is not
in the data either and `creeppull` (a)-evidence stays UNPROVEN rather than
WORKING.

Positional conventions, identity locking, TP/death exclusion, creep staleness
and the seed-draft position source are all inherited from `creeppull_domain`
(see its DOMAIN block); this file adds no new world reading of its own beyond
the creep centroid.

Usage:
    creeppull_specificity.py <sweep_dir> [<sweep_dir> ...] [--selfcheck]

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from creeppull_domain import (  # noqa: E402
    DRAG_S, R_CREEP, RADIANT, Game, dist, episodes, load_sweep, scan_game)

# The 18:53Z round's registered SPECIFIC acceptance quantity (GH #143 fix 2 /
# GH #149's differential wave).  Every displacement-shaped read-out that round
# produced was carried by a confound -- `follow` by episode DURATION (the wave
# marches ~30 s on its own), `net` by "lost the trade and ran" being the same
# reading as "dragged the wave" -- and every pooled armed/baseline count was
# carried by the PHYSICAL side (#148).  An event count in a fixed window after
# a fixed anchor has neither problem: it does not grow with episode length, and
# it is reported per armed-side stratum below.
#
# 2.5 s is the anchor-to-deadline budget, not a guess about creep aggro decay:
# it is two dumper samples at the 1.0 s default plus slack, so a wave that is
# genuinely chasing has to show up in a sampled combat-log row, while a wave
# that was merely standing next to us when we hit the hero does not get 6 s of
# lane marching to blunder into us.
AGGRO_W = 2.5

# ...and the clause the registered spelling is MISSING.  A window after an
# anchor reads "was the wave hitting us", which is not the same claim as "our
# attack flipped the wave onto us": a bot standing inside the enemy wave while
# it is already chewing on him satisfies the first for free.  Frame evidence
# (2026-08-23T20Z, `20260823_182327_slot6` tidehunter, BASELINE leg): enemy
# lane creeps hit him at 118.1 and 119.5, he right-clicks sven at 128.1/129.5,
# creeps hit him again at 130.2 -- scored "chased" by the registered metric
# while the frames show a 2v1 he is losing (hp 0.879 -> 0.502 under cask +
# storm bolt + maledict), retreating 714 u.  Nothing was pulled.
#
# LOOKBACK_S is the "the wave was NOT already on us" guard.  10 s, not 3:
# 3 s is the aggro-decay timescale, so a 3 s lookback would have called that
# same tidehunter frame a flip (his lookback happens to be clean).  10 s is
# long enough that the pre-existing aggro of a hero standing in the wave is
# visible, and still short enough to sit inside a single lane engagement.
LOOKBACK_S = 10.0

# Creeps that count as "the wave we were dragging" at the end of the episode:
# any enemy lane creep still within this radius of where the wave was when the
# episode opened.  Wide enough that a wave dragged a full DRAG_U-per-sample run
# stays inside it, narrow enough that the NEXT wave (spawned 30 s apart, ~1500 u
# of lane travel between them at creep speed) is not silently swapped in.
WAVE_R = 1500.0

# The combat log's inflictor for a plain right-click. Everything else is an
# ability -- INCLUDING passives that tick without any order from the bot.
AUTOATTACK = 'dota_unknown'


def attack_index(g):
    """(actor, target) -> [t] for RIGHT-CLICKS only.

    `creeppull_domain`'s `poke` accepts ANY hero->hero damage, and this round's
    frame reading shows what that lets in: `20260823_063011_slot1` lina t=47.4
    scores a pull whose only damage on zuus is `lina_slow_burn` ticking from a
    cast seconds earlier, and `20260823_061930_slot12` viper t=100.4 scores one
    off `viper_corrosive_skin` -- a REFLECT passive that fires when viper is
    ATTACKED. A bot walking home with a DOT still running has issued no attack
    order at all, and it is the attack order on the enemy hero that flips the
    creep aggro. So the discriminator the 09:09Z round asked for is not vacuous
    after all -- it just has to be spelled `inflictor == dota_unknown` rather
    than "any damage".
    """
    idx = defaultdict(list)
    c2h = {h.replace('npc_dota_hero_', '').replace('_', '').lower(): h
           for h in g.teams}
    for e in g.raw_events:
        if (e['type'] == 'DAMAGE' and e.get('actor_hero') and e.get('target_hero')
                and e.get('inflictor') == AUTOATTACK):
            a = c2h.get(str(e.get('actor')).replace('npc_dota_hero_', '')
                        .replace('_', '').lower(), e.get('actor'))
            b = c2h.get(str(e.get('target')).replace('npc_dota_hero_', '')
                        .replace('_', '').lower(), e.get('target'))
            idx[(a, b)].append(e['t'])
    return idx


def wave_centroid(g, team, t, x, y, radius):
    """Centroid of enemy lane creeps within `radius` of (x, y) at time t.

    Returns (cx, cy, n) or None when the creep sample is stale (`creeps_at`
    enforces the 1.6 s cap) or nothing is in range.
    """
    cs = g.creeps_at(t)
    if cs is None:
        return None
    ec = [c for c in cs
          if c['team'] != team and dist(x, y, c['x'], c['y']) <= radius]
    if not ec:
        return None
    return (sum(c['x'] for c in ec) / len(ec),
            sum(c['y'] for c in ec) / len(ec), len(ec))


def creep_hits_on(g, hero):
    """Times an enemy LANE creep damaged this hero.

    The only offline read-out of "the wave actually aggroed onto me": lane
    creeps do not attack a hero unless something redirected them. Neutrals are
    excluded by name (`npc_dota_neutral_*`) -- a jungle camp chewing on a hero
    is the ancient-camp shape, not a pull. Charter 2026-08-23: non-hero actors
    ARE present in the combat log, so this is a corpus read, not an inference.
    """
    cache = getattr(g, '_creep_hits_cache', None)
    if cache is None:
        cache = g._creep_hits_cache = {}
    if hero in cache:
        return cache[hero]
    out = []
    want = hero.replace('npc_dota_hero_', '').replace('_', '').lower()
    for e in g.raw_events:
        if (e['type'] == 'DAMAGE' and e.get('target_hero')
                and not e.get('actor_hero')):
            a = str(e.get('actor') or '')
            if 'creep' in a and 'neutral' not in a:
                b = str(e.get('target') or '').replace('npc_dota_hero_', '')
                if b.replace('_', '').lower() == want:
                    out.append(e['t'])
    out.sort()
    cache[hero] = out
    return out


def aggro_flip(hits, rc_first, t_end, w=AGGRO_W, back=LOOKBACK_S):
    """Did our FIRST right-click of the episode flip a wave that was NOT on us?

    True  = clean lookback AND a creep row inside the window (a flip).
    False = a creep row inside the window but the wave was already on us
            (`aggro_within` says "chased", this says "not a flip"), or no
            creep row at all.
    None  = same right-censoring as `aggro_within`.

    The anchor is the FIRST right-click, not the last: the flip is caused by
    the attack that starts the exchange, and anchoring on the last one lets
    every re-attack inside a genuine sustained pull invalidate its own
    lookback.
    """
    if rc_first is None or rc_first + w > t_end:
        return None
    if any(rc_first - back <= t <= rc_first for t in hits):
        return False
    return any(rc_first < t <= rc_first + w for t in hits)


def aggro_within(hits, rc_last, t_end, w=AGGRO_W):
    """Did the wave hit us inside the fixed window after the last right-click?

    None when the window is not fully covered by the replay's combat log
    (`t_end` is the last event, charter #130's frozen tail sits after it).
    The window is OPEN at the anchor: a creep row stamped at exactly the
    right-click instant is aggro this attack cannot have caused yet.
    """
    if rc_last is None or rc_last + w > t_end:
        return None
    return any(rc_last < t <= rc_last + w for t in hits)


def is_rightclick(atk, hero, r):
    """Did this hero right-click the aggro target in `poke`'s own window?"""
    return any(r['t'] - 1.0 <= t <= r['t'] + 2.0
               for t in atk.get((hero, r['tgt']), ()))


def episode_metrics(g, ep, atk):
    """Per-episode cadence + outcome record for one run of domain frames."""
    r0, r1 = ep[0], ep[-1]
    hero = r0['hero']
    team = g.teams.get(hero)
    fx, fy = g.fountain.get(team, (0.0, 0.0))
    t0, t1 = r0['t'], r1['t'] + DRAG_S

    n_pull = sum(1 for r in ep if r['pull'])
    # The longest RUN of consecutive-sample pull frames, which is what the
    # 1.2 s attack / move alternation actually emits; a scattered 1+1 inside one
    # episode is not a sustained drag.  Samples are 1 Hz but the stream is not
    # perfectly regular, so "consecutive" means <= 1.6 s apart (same slack the
    # domain's own staleness cap uses).
    run = best = 0
    prev = None
    for r in ep:
        if r['pull'] and (prev is None or r['t'] - prev <= 1.6):
            run += 1
        elif r['pull']:
            run = 1
        else:
            run = 0
        prev = r['t'] if r['pull'] else None
        best = max(best, run)

    s0 = g.frames[hero].get(r0['t'])
    s1 = g.alive_at(hero, t1)
    clean = g.clean_window(hero, t0, t1)
    dx, dy = fx - s0['x'], fy - s0['y']
    n = max(math.hypot(dx, dy), 1.0)
    ux, uy = dx / n, dy / n

    net = None
    if s1 and clean:
        net = (s1['x'] - s0['x']) * ux + (s1['y'] - s0['y']) * uy

    rcs = [t for t in atk.get((hero, r0['tgt']), ())
           if r0['t'] - 1.0 <= t <= t1]
    n_rc = len(rcs)
    aggro_tail = None
    # aggro25: the specific quantity. None = NOT MEASURABLE, and the two
    # reasons are different: no right-click at all (no anchor), or the 2.5 s
    # window runs past the last combat-log row in the replay. The second is
    # right-censoring, not a zero -- charter #130's frozen tail (~25 s of
    # duplicated frames with ZERO combat rows at the end of every game) would
    # otherwise manufacture "the wave stopped chasing" for free on whichever
    # leg happens to own the late episodes.
    aggro25 = flip = None
    if rcs:
        hits = [t for t in creep_hits_on(g, hero) if rcs[-1] <= t <= t1 + 6.0]
        aggro_tail = round(hits[-1] - rcs[-1], 1) if hits else 0.0
        aggro25 = aggro_within(creep_hits_on(g, hero), rcs[-1], g.t_end)
        flip = aggro_flip(creep_hits_on(g, hero), rcs[0], g.t_end)

    follow = None
    w0 = wave_centroid(g, team, r0['t'], s0['x'], s0['y'], R_CREEP)
    if w0 and clean:
        w1 = wave_centroid(g, team, t1, w0[0], w0[1], WAVE_R)
        if w1:
            follow = (w1[0] - w0[0]) * ux + (w1[1] - w0[1]) * uy

    return dict(game=r0['game'], hero=hero, leg=r0['leg'], pos=r0['pos'],
                t0=r0['t'], t1=r1['t'], frames=len(ep),
                n_poke=sum(1 for r in ep if r['poke']),
                # STRICT = the domain's own subset that actually matches the Lua
                # gate's single-enemy branch (pos<=3, exactly one enemy in the
                # near ring, no recent hero damage). The wide domain admits
                # 2-enemy frames because the melee-vs-2-ranged branch exists,
                # and a ranged core losing a 2v1 trade then walking home looks
                # identical to a pull in the wide reading -- 062503_slot11
                # viper t=129.5 is exactly that (this round's frame evidence).
                n_strict=sum(1 for r in ep if r['strict']),
                n_strict_pull=sum(1 for r in ep if r['strict'] and r['pull']),
                n_atk=sum(1 for r in ep if is_rightclick(atk, hero, r)),
                n_atk_pull=sum(1 for r in ep
                               if r['pull'] and is_rightclick(atk, hero, r)),
                # how many right-clicks on the aggro target the whole episode
                # carries, and how long the wave kept hitting us after the LAST
                # one (creep aggro from an attack expires on its own; the call
                # site's only means of holding it is to re-attack every 1.2 s,
                # which requires walking back into range -- the exact thing the
                # drag is supposed to be doing the opposite of).
                n_rc=n_rc, aggro_tail=aggro_tail, aggro25=aggro25, flip=flip,
                arm_side='radiant' if g.armed_team == RADIANT else 'dire',
                n_pull=n_pull, run=best, clean=clean,
                net=None if net is None else round(net),
                follow=None if follow is None else round(follow),
                core=bool(r0['pos'] and r0['pos'] <= 3))


def med(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    m = len(xs) // 2
    return xs[m] if len(xs) % 2 else (xs[m - 1] + xs[m]) / 2.0


def ratio(a, b):
    return float('inf') if b == 0 and a else (0.0 if not a else a / float(b))


def selfcheck():
    """Synthetic cases for the two things this file adds: the run counter and
    the wave-follow projection.  Everything else is `creeppull_domain`'s."""
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-38s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    def runof(flags, step=1.0):
        ep = [dict(t=i * step, pull=f, poke=f, game='g', hero='h', leg='armed',
                   pos=1) for i, f in enumerate(flags)]
        run = best = 0
        prev = None
        for r in ep:
            if r['pull'] and (prev is None or r['t'] - prev <= 1.6):
                run += 1
            elif r['pull']:
                run = 1
            else:
                run = 0
            prev = r['t'] if r['pull'] else None
            best = max(best, run)
        return best

    chk('run: all-false -> 0', runof([False] * 4) == 0)
    chk('run: single -> 1', runof([False, True, False]) == 1)
    chk('run: 1+1 split -> 1', runof([True, False, True]) == 1,
        'scattered pulls must not read as a sustained drag')
    chk('run: 3 in a row -> 3', runof([False, True, True, True]) == 3)
    chk('run: gap > 1.6 s breaks it', runof([True, True], step=3.0) == 1)

    # wave-follow sign: a wave that moves TOWARD our fountain is positive.
    class FakeG:
        teams = {'h': 2}
        fountain = {2: (-6000.0, -6000.0)}

        def __init__(self, c0, c1):
            self._c = {0.0: c0, 10.0: c1}
            self.creep_t = sorted(self._c)
            self.creeps = {t: [dict(t=t, team=3, x=x, y=y)]
                           for t, (x, y) in self._c.items()}

        def creeps_at(self, t):
            return self.creeps.get(t)

    g = FakeG((0.0, 0.0), (-1000.0, -1000.0))
    w0 = wave_centroid(g, 2, 0.0, 0.0, 0.0, R_CREEP)
    w1 = wave_centroid(g, 2, 10.0, w0[0], w0[1], WAVE_R)
    # this fake fountain sits on the diagonal, so ux == uy exactly and one
    # variable stands for both components below -- true only here.
    ux = -6000.0 / math.hypot(6000.0, 6000.0)
    follow = (w1[0] - w0[0]) * ux + (w1[1] - w0[1]) * ux
    chk('follow: toward our fountain > 0', follow > 1000, 'follow=%d' % follow)
    g2 = FakeG((0.0, 0.0), (1000.0, 1000.0))
    w0 = wave_centroid(g2, 2, 0.0, 0.0, 0.0, R_CREEP)
    w1 = wave_centroid(g2, 2, 10.0, w0[0], w0[1], WAVE_R)
    chk('follow: away -> < 0',
        ((w1[0] - w0[0]) * ux + (w1[1] - w0[1]) * ux) < -1000)
    # aggro25 -- the specific quantity's window semantics.
    chk('aggro25: hit inside window -> True',
        aggro_within([12.0], 10.0, 1000.0) is True)
    chk('aggro25: no hit -> False',
        aggro_within([20.0], 10.0, 1000.0) is False)
    chk('aggro25: hit AT the anchor is not it',
        aggro_within([10.0], 10.0, 1000.0) is False,
        'aggro already present cannot be caused by this right-click')
    chk('aggro25: right edge inclusive',
        aggro_within([12.5], 10.0, 1000.0) is True)
    chk('aggro25: just past the edge -> False',
        aggro_within([12.6], 10.0, 1000.0) is False)
    chk('aggro25: window past last event -> None',
        aggro_within([12.0], 10.0, 12.4) is None,
        'right-censored, must NOT be scored as "wave stopped chasing"')
    chk('aggro25: window exactly covered -> not None',
        aggro_within([], 10.0, 12.5) is False)
    chk('aggro25: no anchor -> None', aggro_within([12.0], None, 1000.0) is None)

    # flip -- the clause the registered spelling is missing.
    chk('flip: clean lookback + hit -> True',
        aggro_flip([12.0], 10.0, 1000.0) is True)
    chk('flip: wave already on us -> False',
        aggro_flip([1.0, 12.0], 10.0, 1000.0) is False,
        'a creep row inside the lookback means nothing was flipped')
    chk('flip: lookback edge is inclusive',
        aggro_flip([0.0, 12.0], 10.0, 1000.0) is False)
    chk('flip: older than the lookback does not count',
        aggro_flip([-0.1, 12.0], 10.0, 1000.0) is True)
    chk('flip: clean lookback, no hit -> False',
        aggro_flip([20.0], 10.0, 1000.0) is False)
    chk('flip: tidehunter case (this round) reads False',
        aggro_flip([118.1, 119.5, 130.2], 128.1, 700.0) is False,
        '20260823_182327_slot6 -- CHASED but not a flip')
    chk('flip: zuus case (this round) reads True',
        aggro_flip([210.4, 210.8, 211.4], 208.5, 750.0) is True,
        '20260823_181204_slot11 -- flip, wave followed 2.0k u')
    chk('flip: censored window -> None',
        aggro_flip([12.0], 10.0, 12.4) is None)

    g3 = FakeG((0.0, 0.0), (9000.0, 9000.0))
    w0 = wave_centroid(g3, 2, 0.0, 0.0, 0.0, R_CREEP)
    chk('follow: next wave not swapped in',
        wave_centroid(g3, 2, 10.0, w0[0], w0[1], WAVE_R) is None,
        'creeps beyond WAVE_R must read None, not a huge follow')
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--top', type=int, default=10)
    ap.add_argument('--out', default='/tmp/creeppull_specificity.jsonl')
    a = ap.parse_args()

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck():
            sys.exit(2)

    games = []
    for d in a.sweeps:
        for m in load_sweep(d):
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            games.append((Game(tl, an, m['side']), m['game'], m['seed']))
    print('corpus: %d games from %d sweep dir(s)' % (len(games), len(a.sweeps)))

    recs = []
    for g, name, seed in games:
        rows = scan_game(g, name, seed)
        atk = attack_index(g)
        for ep in episodes(rows):
            recs.append(episode_metrics(g, ep, atk))

    core = [r for r in recs if r['core']]
    print('\nepisodes: %d total, %d core (pos 1-3)' % (len(recs), len(core)))

    # --- axis 0: the discriminator the 09:09Z round registered, split into the
    # vacuous reading and the one that actually bites.
    withpull = [r for r in core if r['n_pull']]
    print('\n[axis 0a] core_pull episodes with ANY damage on the aggro target: '
          '%d/%d = %.1f%% -- 100%% BY CONSTRUCTION (poke is a conjunct of pull), '
          'so "any damage" is not a discriminator.'
          % (sum(1 for r in withpull if r['n_poke']), len(withpull),
             100.0 * sum(1 for r in withpull if r['n_poke'])
             / max(len(withpull), 1)))
    print('[axis 0b] core_pull episodes with an actual RIGHT-CLICK on the aggro '
          'target (inflictor == %s) -- the attack order that flips creep aggro:'
          % AUTOATTACK)
    print('%-12s %10s %10s %8s' % ('slice', 'armed', 'baseline', 'ratio'))
    for label, sel in (('any pull', lambda r: r['n_pull'] >= 1),
                       ('atk pull', lambda r: r['n_atk_pull'] >= 1),
                       ('strict pull', lambda r: r['n_strict_pull'] >= 1),
                       ('strict+atk', lambda r: r['n_strict_pull'] >= 1
                        and r['n_atk_pull'] >= 1)):
        A = sum(1 for r in core if r['leg'] == 'armed' and sel(r))
        B = sum(1 for r in core if r['leg'] == 'baseline' and sel(r))
        print('%-12s %10d %10d %8s'
              % (label, A, B, ('%.2fx' % ratio(A, B)) if B else '-'))
    for leg in ('armed', 'baseline'):
        p = [r for r in core if r['leg'] == leg and r['n_pull']]
        rc = [r for r in p if r['n_atk_pull']]
        print('  %-8s right-click share of pull episodes: %d/%d = %.1f%%'
              % (leg, len(rc), len(p), 100.0 * len(rc) / max(len(p), 1)))

    # --- axis 1: cadence (longest consecutive run of pull frames)
    print('\n[axis 1] cadence -- core episodes by longest consecutive PULL run')
    print('%-12s %10s %10s %8s' % ('run length', 'armed', 'baseline', 'ratio'))
    buckets = [(1, 1), (2, 2), (3, 3), (4, 10 ** 6)]
    for lo, hi in buckets:
        A = sum(1 for r in core if r['leg'] == 'armed' and lo <= r['run'] <= hi)
        B = sum(1 for r in core if r['leg'] == 'baseline' and lo <= r['run'] <= hi)
        lbl = '>=%d' % lo if hi > 10 else '%d' % lo
        print('%-12s %10d %10d %8s'
              % (lbl, A, B, ('%.2fx' % ratio(A, B)) if B else ('inf' if A else '-')))
    for k in (1, 2, 3):
        A = sum(1 for r in core if r['leg'] == 'armed' and r['run'] >= k)
        B = sum(1 for r in core if r['leg'] == 'baseline' and r['run'] >= k)
        print('  cumulative run >= %d: armed %d, baseline %d, ratio %s'
              % (k, A, B, ('%.2fx' % ratio(A, B)) if B else ('inf' if A else '-')))

    # --- axis 2: outcome (did the wave follow?)
    print('\n[axis 2] outcome -- enemy wave centroid displacement toward our '
          'fountain over the episode (+DRAG_S)')
    print('%-26s %10s %10s' % ('slice', 'armed', 'baseline'))
    for label, sel in (('all core episodes', lambda r: True),
                       ('core, >=1 pull frame', lambda r: r['n_pull'] >= 1),
                       ('core, run >= 2', lambda r: r['run'] >= 2),
                       ('core, >=1 STRICT pull', lambda r: r['n_strict_pull'] >= 1),
                       ('core, >=1 ATK pull', lambda r: r['n_atk_pull'] >= 1)):
        row = []
        for leg in ('armed', 'baseline'):
            xs = [r['follow'] for r in core
                  if r['leg'] == leg and sel(r) and r['follow'] is not None]
            pos = sum(1 for x in xs if x > 0)
            row.append('%s n=%d med=%s +%.0f%%'
                       % ('', len(xs), med(xs),
                          100.0 * pos / max(len(xs), 1)))
        print('%-26s %10s %10s' % (label, row[0], row[1]))

    # --- axis 3: does the aggro get HELD? one right-click buys a couple of
    # seconds of creep chase; the call site's only means of extending it is to
    # re-attack, which means walking back into range.
    print('\n[axis 3] aggro holding, core episodes with >=1 right-click pull')
    print('%-9s %6s %10s %10s %10s %10s'
          % ('leg', 'n', 'med n_rc', 'n_rc==1', 'med tail s', 'tail==0'))
    for leg in ('armed', 'baseline'):
        xs = [r for r in core if r['leg'] == leg and r['n_atk_pull'] >= 1
              and r['n_rc']]
        one = sum(1 for r in xs if r['n_rc'] == 1)
        tails = [r['aggro_tail'] for r in xs if r['aggro_tail'] is not None]
        zero = sum(1 for t in tails if t == 0.0)
        print('%-9s %6d %10s %9.1f%% %10s %9.1f%%'
              % (leg, len(xs), med([r['n_rc'] for r in xs]),
                 100.0 * one / max(len(xs), 1), med(tails),
                 100.0 * zero / max(len(tails), 1)))

    # --- axis 4: THE specific acceptance quantity (see AGGRO_W). Reported the
    # way #148 says every armed/baseline comparison has to be: both physical
    # strata separately (two strata that disagree in SIGN = noise, not effect),
    # plus the supply (episodes per game) that the rate is conditioned on --
    # #86's lesson is that a rate can move purely because the two legs enter
    # the domain at different speeds.
    print('\n[axis 4] SPECIFIC: enemy lane-creep damage row on the bot within '
          '%.1f s AFTER its last right-click on the aggro target' % AGGRO_W)
    strata = [('radiant-armed', 'radiant'), ('dire-armed', 'dire'),
              ('POOLED (#148)', None)]
    for key, title in (('aggro25', 'CHASED  (registered spelling: any creep '
                                   'row in the window)'),
                       ('flip', 'FLIP    (+ the wave was NOT already on us '
                                'in the %.0f s before)' % LOOKBACK_S)):
        print('\n  %s' % title)
        print('  %-16s %-9s %6s %6s %8s %8s %10s'
              % ('stratum', 'leg', 'games', 'n', 'yes', 'rate', 'eps/game'))
        rates = {}
        for lbl, side in strata:
            ng = len([1 for g, _, _ in games
                      if side is None
                      or ('radiant' if g.armed_team == RADIANT else 'dire') == side])
            for leg in ('armed', 'baseline'):
                xs = [r for r in core
                      if r['leg'] == leg and r['n_atk_pull'] >= 1
                      and r[key] is not None
                      and (side is None or r['arm_side'] == side)]
                hit = sum(1 for r in xs if r[key])
                rate = 100.0 * hit / max(len(xs), 1)
                rates[(lbl, leg)] = (len(xs), hit, rate)
                print('  %-16s %-9s %6d %6d %8d %7.1f%% %10.2f'
                      % (lbl, leg, ng, len(xs), hit, rate,
                         len(xs) / float(max(ng, 1))))
        for lbl, _ in strata:
            a_n, _, a_r = rates[(lbl, 'armed')]
            b_n, _, b_r = rates[(lbl, 'baseline')]
            print('    %-16s delta = %+.1f pp (armed n=%d, baseline n=%d)'
                  % (lbl, a_r - b_r, a_n, b_n))
    # --- axis 4b: the side-BALANCED estimator. Within one stratum the paired
    # (armed - baseline) difference still carries the whole physical-side term,
    # because the armed leg IS one physical side there; averaging the two
    # strata's paired differences cancels that term exactly (it enters with
    # opposite sign in ab and ba). This round's corpus is the worked example:
    # per-game domain supply reads +1.40 in dire-armed and -0.17 in
    # radiant-armed -- neither is the effect, their mean is.
    print('\n[axis 4b] per-game counts, paired within game, then averaged over '
          'the two armed-side strata (#148)')
    print('%-14s %10s %10s %10s %8s'
          % ('quantity', 'ab (rad)', 'ba (dire)', 'balanced', '|t|'))
    per = defaultdict(lambda: defaultdict(int))
    gside = {}
    for r in core:
        if r['n_atk_pull'] < 1:
            continue
        per[r['game']][r['leg'] + '_n'] += 1
        gside[r['game']] = r['arm_side']
        for k in ('flip', 'aggro25'):
            if r[k]:
                per[r['game']][r['leg'] + '_' + k] += 1
    for key, lbl in (('n', 'episodes'), ('aggro25', 'chased'), ('flip', 'FLIP')):
        cell = {}
        for s in ('radiant', 'dire'):
            d = [per[g]['armed_' + key] - per[g]['baseline_' + key]
                 for g in per if gside[g] == s]
            m = sum(d) / float(len(d))
            var = sum((x - m) ** 2 for x in d) / max(len(d) - 1, 1)
            cell[s] = (m, var / len(d))
        bal = 0.5 * (cell['radiant'][0] + cell['dire'][0])
        se = 0.5 * math.sqrt(cell['radiant'][1] + cell['dire'][1])
        print('%-14s %+10.3f %+10.3f %+10.3f %8.2f'
              % (lbl + '/game', cell['radiant'][0], cell['dire'][0], bal,
                 abs(bal / se) if se else float('inf')))
    print('  (|t| is a noise ruler, not a gate -- the promote bar is the '
          "owner's three conditions, not a p-value.)")

    cens = [r for r in core if r['n_atk_pull'] >= 1 and r['n_rc']
            and r['aggro25'] is None]
    print('  right-censored by the replay tail (excluded, charter #130): %d'
          % len(cens))
    # How much of "chased" is pre-existing aggro rather than a flip: the size
    # of the false-positive channel, per leg.
    for leg in ('armed', 'baseline'):
        ch = [r for r in core if r['leg'] == leg and r['n_atk_pull'] >= 1
              and r['aggro25']]
        fl = sum(1 for r in ch if r['flip'])
        print('  %-9s of %d CHASED episodes, %d are flips = %.1f%% '
              '(the rest: the wave was already on us)'
              % (leg, len(ch), fl, 100.0 * fl / max(len(ch), 1)))

    print('\n%-26s %10s %10s' % ('hero net drag (u)', 'armed', 'baseline'))
    for label, sel in (('all core episodes', lambda r: True),
                       ('core, run >= 2', lambda r: r['run'] >= 2)):
        row = []
        for leg in ('armed', 'baseline'):
            xs = [r['net'] for r in core
                  if r['leg'] == leg and sel(r) and r['net'] is not None]
            row.append('n=%d med=%s' % (len(xs), med(xs)))
        print('%-26s %10s %10s' % (label, row[0], row[1]))

    top = sorted([r for r in core if r['leg'] == 'armed'],
                 key=lambda r: (r['run'], r['follow'] or -10 ** 6), reverse=True)
    print('\n--- top armed core episodes for frame-by-frame review ---')
    for r in top[:a.top]:
        print('%-24s %-18s pos%s t=%.1f..%.1f frames=%d pull=%d run=%d '
              'net=%s follow=%s'
              % (r['game'], r['hero'].replace('npc_dota_hero_', ''), r['pos'],
                 r['t0'], r['t1'], r['frames'], r['n_pull'], r['run'],
                 r['net'], r['follow']))

    with open(a.out, 'w') as fh:
        for r in recs:
            fh.write(json.dumps(r) + '\n')
    print('\n(%d episode records written to %s)' % (len(recs), a.out))


if __name__ == '__main__':
    main()

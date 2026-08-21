#!/usr/bin/env python3
"""axe_blink_domain.py -- pre-flight sizing for the `axeblink` gate.

`axeblink` (hero stream, 2026-08-19; `J.ShouldHoldAxeBlinkForCall` in
`bots/FunLib/jmz_func.lua:7803`) has exactly ONE consumer: the offensive branch
of `X.ConsiderItemDesire['item_blink']` in
`bots/ability_item_usage_generic.lua:1613-1621`.  There the guard can only
SUPPRESS a blink that the shipped tree would have cast; it never adds one.  So
the armed and shipped trees diverge on a frame only if ALL of these hold at once
(the guard's own conjunction, jmz_func.lua:7803-7821):

    turbo AND soak-candidate armed        (assumed; corpus is Turbo)
    bot is npc_dota_hero_axe
    axe_berserkers_call level >= 1        ("there is a combo to wait for")
    Call NOT castable this instant        (cooldown > 0, or mana < its cost)
    >= 2 currently-visible enemy heroes within Call's radius of the LANDING
    point

...AND the branch itself fires, which additionally requires a valid enemy hero
target between 500 and cast range away, allies-not-outnumbered, and
`J.WeAreStronger`.

Datafeed anchors, hero_id=2, pulled 2026-08-21:

    axe_berserkers_call  radius [315]  (flat across all four levels)
                         mana   [90, 100, 110, 120]
                         cd     [18, 16, 14, 12]

Sections measured off behav-dump timelines:

  D. supply       -- per game, whether Axe ever owns a Blink Dagger and from
                     what time.  Without a dagger the consumer cannot run at
                     all, which is the weak (sampling-shaped) reason a domain
                     can be empty.  Corpus choice matters: use a wave where
                     `axebuyblink` was armed, or this section answers the
                     question by itself and nothing else is learned.
  A. exact domain -- every real `item_blink` cast by Axe, with the guard's
                     predicate evaluated on the pre-jump frame and the LANDING
                     point read straight off the post-jump snapshot -- better
                     than re-deriving it through
                     `J.GetUnitTowardDistanceLocation` + `RandomVector(150)`.
                     The jump is located as the largest consecutive-snapshot
                     displacement inside [t-0.5, t+2.0] around the ITEM event,
                     NOT as "the next snapshot": measured on this corpus the
                     teleport lands one or two 0.5s samples after the event
                     (20260820_043124 t=492.3 lands on the next sample, t=529.6
                     and t=555.2 land on the one after), so taking the first
                     post-event snapshot silently reports a 77-unit walk as the
                     blink and puts the landing point in the wrong place.
                     A cast is in the domain iff the guard would have held it.
                     Each clause is reported separately so the BINDING clause
                     is visible, not just the conjunction's value.
  A'. branch tag  -- each cast is tagged with the GH #71 geometric fingerprint:
                     cos(displacement, unit vector from Axe toward its OWN
                     ancient) and the jump distance.  cos ~ +1 at ~1200 is the
                     retreat branch (`blinkflee`'s domain, not this gate's);
                     cos < 0 toward a nearby enemy is the offensive branch.
                     Only offensive-branch casts are addressable by `axeblink`.
  B. loose ceiling-- an UPPER BOUND reached by dropping the branch's clauses:
                     every frame where Axe holds a dagger that is plausibly off
                     cooldown (no blink cast in the preceding `--blink-cd`
                     seconds) and there is an enemy hero in the
                     (500, cast-range] window, scored with the guard's own
                     predicate against a PROJECTED landing point (toward that
                     enemy, capped at cast range).  Reported as a funnel, and
                     then narrowed once more (B2) by the one branch clause that
                     is faithfully reproducible off the dump --
                     `#nInRangeAlly >= nNearbyEnemyHeroCount`, allies vs enemy
                     heroes within 1200 of the target.  `J.WeAreStronger` is
                     NOT reproducible (it prices items and levels), so B2
                     remains an upper bound too.  If the funnel's floor is ~0
                     the domain is structurally empty rather than undersampled;
                     if it is not, the emptiness of section A is a statement
                     about the branch, not about the guard.
  B3. ally column -- the same `#nInRangeAlly` ring scored on EVERY candidate
                     frame of section B, not only on the predicate-true slice.
                     Added on the director's 2026-08-21T03:00Z ruling
                     (test_set.md Y.1) because B2's "21/21 frames Axe stood
                     alone" cannot distinguish two very different worlds: Axe
                     never groups while holding a dagger with an enemy in range
                     (in which case the >=2-enemy sub-slice inherits a property
                     of the whole ceiling), or Axe groups routinely and the 21
                     just happened to miss it (in which case the domain is live
                     but rare and 0/21 is a coincidence of the sub-slice).
                     Read the direction, not only the number: this is a fact
                     about how Axe currently POSITIONS, so under the corrected
                     desk-check rule it can show the domain RARE, never EMPTY,
                     and it expires the moment a grouping-class id is armed
                     (axeblink revival condition 3).

Known boundaries (every count below is an UPPER bound on the true domain):

  * issue #27 -- behav-dump emits no per-hero vision, so "currently visible"
    is approximated by "alive and present in the snapshot".  This can only
    OVERCOUNT enemies near the landing point, i.e. overstate the domain.
  * issue #78 / #43 -- corpses keep being snapshotted with frozen state, so
    `hp > 0` is required of every counted enemy, and samples past the last real
    event are dropped.
  * blink cooldown is not in the dump (items carry no cooldown field), so
    section B's readiness test is the `--blink-cd` heuristic, again generous.
  * cast range is taken as 1200 (no Aether Lens / no `nCastRange` modifiers in
    Axe's observed item pool); a longer real range would only widen B.
  * 0.5s sampling: the pre-cast frame is up to 0.5s before the decision, so
    cooldowns and mana are read slightly early.  Reported per cast so a human
    can see when it matters.

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.

Usage:
    python3 axe_blink_domain.py tl/*.json [--json out.json]
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

AXE = 'npc_dota_hero_axe'
CALL = 'axe_berserkers_call'
BLINK = 'blink_dagger'

CALL_RADIUS = 315                       # datafeed: flat across all levels
CALL_MANA = {1: 90, 2: 100, 3: 110, 4: 120}
CAST_RANGE = 1200                       # item_blink, no range modifiers
MIN_OFFENSIVE_RANGE = 500               # `not J.IsInRange(bot, botTarget, 500)`
MIN_JUMP = 250                          # below this the ITEM event did not
                                        # resolve into a visible teleport
HEADCOUNT_RADIUS = 1200                 # the branch's own ally/enemy ring

# Ancient locations, for the GH #71 retreat fingerprint.
ANCIENT = {2: (-5528.0, -4874.0), 3: (5528.0, 5000.0)}


def load(path):
    d = json.load(open(path))
    if not d.get('events'):
        return None
    tmax = max(e['t'] for e in d['events'])          # issue #43
    d['snapshots'] = [s for s in d['snapshots'] if s['t'] <= tmax]
    return d


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def call_state(snap):
    """(learned, available_now) for Berserker's Call on this frame."""
    for a in snap['abilities']:
        if a['name'] != CALL:
            continue
        if a['level'] < 1:
            return False, False
        cost = CALL_MANA[min(a['level'], 4)]
        return True, (a['cd'] == 0 and snap['mp'] >= cost)
    return False, False


def enemies_near(frames, team, x, y, radius):
    out = []
    for o in frames:
        if o['team'] == team or o['hp'] <= 0 or o['hero'] == AXE:
            continue
        d = dist(o['x'], o['y'], x, y)
        if d <= radius:
            out.append((round(d), o['hero'][14:], round(o['hp_pct'], 2)))
    return sorted(out)


def analyse(path, blink_cd):
    d = load(path)
    if d is None:
        return None
    axe = sorted([s for s in d['snapshots'] if s['hero'] == AXE], key=lambda s: s['t'])
    if not axe:
        return {'timeline': os.path.basename(path), 'has_axe': False}
    team = axe[0]['team']
    by_t = collections.defaultdict(list)
    for s in d['snapshots']:
        by_t[round(s['t'], 1)].append(s)

    holds = [s for s in axe if any(i == BLINK for i in s['items'])]
    casts = [e for e in d['events']
             if e['type'] == 'ITEM' and e.get('actor') == AXE
             and e.get('inflictor') == 'item_blink']

    res = {
        'timeline': os.path.basename(path),
        'has_axe': True,
        'axe_frames': len(axe),
        # D. supply
        'D_holds_blink': bool(holds),
        'D_first_hold_t': round(holds[0]['t'], 1) if holds else None,
        'D_hold_frames': len(holds),
        # A. exact domain
        'A_casts': [],
        'A_in_domain': 0,
        'A_unresolved_casts': [],
        # B. loose ceiling
        'B_candidate_frames': 0,
        'B_corpse_frames_dropped': 0,
        'B_predicate_true_frames': 0,
        'B_max_enemies_at_projected_landing': 0,
        'B_call_unavailable_frames': 0,
        'B2_not_outnumbered_frames': 0,
        'B2_min_not_outnumbered_frames': 0,
        'B2_allies_hist': {},
        'B2_foes_hist': {},
        'B2_episodes': [],
        # B3. the ally column over the WHOLE ceiling (director ruling
        # 2026-08-21T03:00Z, test_set.md Y.1) -- see the section note above.
        'B3_allies_hist_all': {},
        'B3_allies_hist_unavail': {},
        'B3_axe_ring_hist': {},
        'B3_rows': [],
    }

    ax, ay = ANCIENT[team]
    for ev in casts:
        t = ev['t']
        # The teleport shows up one or two 0.5s samples after the ITEM event,
        # so locate it as the largest consecutive-snapshot step in the window
        # rather than assuming the next sample is the landing.
        win = [s for s in axe if t - 0.5 <= s['t'] <= t + 2.0]
        if len(win) < 2:
            continue
        pre, post, best = None, None, -1.0
        for a, b in zip(win, win[1:]):
            step = dist(a['x'], a['y'], b['x'], b['y'])
            if step > best:
                pre, post, best = a, b, step
        if best < MIN_JUMP:
            res['A_unresolved_casts'].append(round(t, 1))
            continue
        learned, avail = call_state(pre)
        land_frames = by_t[round(post['t'], 1)]
        near = enemies_near(land_frames, team, post['x'], post['y'], CALL_RADIUS)
        # nearest live enemy hero before the jump, for branch attribution
        pre_frames = by_t[round(pre['t'], 1)]
        pre_enemies = sorted(
            [(round(dist(o['x'], o['y'], pre['x'], pre['y'])), o['hero'][14:],
              round(o['hp_pct'], 2))
             for o in pre_frames
             if o['team'] != team and o['hp'] > 0 and o['hero'] != AXE])
        jump = dist(pre['x'], pre['y'], post['x'], post['y'])
        # GH #71 fingerprint: +1 = straight toward our own ancient
        home = dist(pre['x'], pre['y'], ax, ay)
        cos = 0.0
        if jump > 1 and home > 1:
            cos = (((post['x'] - pre['x']) * (ax - pre['x'])
                    + (post['y'] - pre['y']) * (ay - pre['y'])) / (jump * home))
        held = learned and not avail and len(near) >= 2
        if held:
            res['A_in_domain'] += 1
        res['A_casts'].append({
            't': round(t, 1),
            'hp_pct': round(pre['hp_pct'], 2),
            'mp': pre['mp'],
            'jump': round(jump),
            'cos_toward_own_ancient': round(cos, 3),
            'branch_hint': ('retreat' if cos > 0.9 and 1100 <= jump <= 1400
                            else 'offensive' if cos < 0 else 'other'),
            'call_learned': learned,
            'call_available': avail,
            'enemies_at_landing_within_315': near,
            'nearest_enemy_before_jump': pre_enemies[0] if pre_enemies else None,
            'guard_would_hold': held,
        })

    last_cast = -1e9
    cast_ts = sorted(e['t'] for e in casts)
    for s in holds:
        while cast_ts and cast_ts[0] <= s['t']:
            last_cast = cast_ts.pop(0)
        # issue #78, found in THIS tool 2026-08-21T04Z while adding B3: a dead
        # Axe keeps being snapshotted with frozen state, dagger included, so
        # without this line the ceiling counts corpse frames as candidates --
        # and a corpse does not count itself in its own ally ring, which is
        # what produced the `allies == 0` bucket the first B3 run reported.
        # The ITEM-event side (section A) is event-driven and unaffected.
        if s['hp'] <= 0:
            res['B_corpse_frames_dropped'] += 1
            continue
        if s['t'] - last_cast < blink_cd:
            continue
        frames = by_t[round(s['t'], 1)]
        targets = [o for o in frames
                   if o['team'] != team and o['hp'] > 0 and o['hero'] != AXE
                   and MIN_OFFENSIVE_RANGE
                   < dist(o['x'], o['y'], s['x'], s['y']) <= CAST_RANGE]
        if not targets:
            continue
        res['B_candidate_frames'] += 1
        learned, avail = call_state(s)
        if learned and not avail:
            res['B_call_unavailable_frames'] += 1
        # B3: the branch's ally ring, scored on EVERY candidate frame rather
        # than only on the predicate-true ones.  Taken as the MAXIMUM over the
        # valid targets, which is the generous direction: it is the largest
        # ally count any target on this frame could have offered the branch, so
        # a max that is still 1 means Axe was alone no matter which enemy the
        # branch picked.
        allies_max = 0
        for tgt in targets:
            allies_max = max(allies_max, sum(
                1 for o in frames
                if o['team'] == team and o['hp'] > 0
                and dist(o['x'], o['y'], tgt['x'], tgt['y']) <= HEADCOUNT_RADIUS))
        res['B3_allies_hist_all'][allies_max] = (
            res['B3_allies_hist_all'].get(allies_max, 0) + 1)
        if learned and not avail:
            res['B3_allies_hist_unavail'][allies_max] = (
                res['B3_allies_hist_unavail'].get(allies_max, 0) + 1)
        # Target-independent cross-check: company around AXE HIMSELF.  The
        # branch does not read this ring, but it separates "no ally near the
        # target" from "no ally anywhere near Axe" without another corpus pull.
        axe_ring = sum(1 for o in frames
                       if o['team'] == team and o['hp'] > 0
                       and dist(o['x'], o['y'], s['x'], s['y'])
                       <= HEADCOUNT_RADIUS)
        res['B3_axe_ring_hist'][axe_ring] = (
            res['B3_axe_ring_hist'].get(axe_ring, 0) + 1)
        # Per-frame row kept so main() can episode-ify.  0.5s samples inside one
        # standoff are not independent observations: quoting a rate or a
        # binomial bound per FRAME overstates the evidence by whatever the run
        # length happens to be.  The n that belongs in any bound is the episode
        # count (cf. the director's 2026-08-21T03:1xZ addendum: report the
        # band's own n before citing anything computed from it).
        row = {'t': round(s['t'], 1), 'allies': allies_max,
               'unavail': bool(learned and not avail), 'pred': False}
        res['B3_rows'].append(row)
        best, best_ok, best_min = 0, False, False
        best_heads = (0, 0)
        for tgt in targets:
            dd = dist(tgt['x'], tgt['y'], s['x'], s['y'])
            f = min(CAST_RANGE, dd) / dd
            lx = s['x'] + (tgt['x'] - s['x']) * f
            ly = s['y'] + (tgt['y'] - s['y']) * f
            n = len(enemies_near(frames, team, lx, ly, CALL_RADIUS))
            if n < 2:
                continue
            # the branch's own head count, around the TARGET (not the landing)
            allies = sum(1 for o in frames
                         if o['team'] == team and o['hp'] > 0
                         and dist(o['x'], o['y'], tgt['x'], tgt['y'])
                         <= HEADCOUNT_RADIUS)
            foes = sum(1 for o in frames
                       if o['team'] != team and o['hp'] > 0
                       and dist(o['x'], o['y'], tgt['x'], tgt['y'])
                       <= HEADCOUNT_RADIUS)
            # Two readings of `#nInRangeAlly >= nNearbyEnemyHeroCount`.
            # `foes` counts every live enemy in the ring, which OVERCOUNTS
            # relative to the branch (it only counts enemies seen in the last
            # 3.0s) and would understate the domain.  `n` is the floor: the
            # >= 2 enemies the guard itself found within 315 of a landing point
            # that coincides with the target are necessarily in the ring and
            # necessarily visible, so `allies >= n` is the loosest faithful
            # form of the clause and keeps B2_min an upper bound.
            if n > best:
                best, best_ok, best_min = n, allies >= foes, allies >= n
                best_heads = (allies, foes)
        res['B_max_enemies_at_projected_landing'] = max(
            res['B_max_enemies_at_projected_landing'], best)
        if learned and not avail and best >= 2:
            res['B_predicate_true_frames'] += 1
            row['pred'] = True
            # The punchline lives here: how many allies stood with Axe on the
            # frames where the guard's own predicate was true.
            a_, f_ = best_heads
            res['B2_allies_hist'][a_] = res['B2_allies_hist'].get(a_, 0) + 1
            res['B2_foes_hist'][f_] = res['B2_foes_hist'].get(f_, 0) + 1
            if best_min:
                res['B2_min_not_outnumbered_frames'] += 1
            if best_ok:
                res['B2_not_outnumbered_frames'] += 1
                if (res['B2_episodes']
                        and s['t'] - res['B2_episodes'][-1]['t_end'] <= 2.0):
                    res['B2_episodes'][-1]['t_end'] = round(s['t'], 1)
                    res['B2_episodes'][-1]['frames'] += 1
                else:
                    res['B2_episodes'].append({'t_start': round(s['t'], 1),
                                               't_end': round(s['t'], 1),
                                               'frames': 1,
                                               'enemies_at_landing': best})
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('timelines', nargs='+')
    ap.add_argument('--blink-cd', type=float, default=15.0,
                    help='seconds after a blink cast during which the dagger is '
                         'assumed unavailable (dump carries no item cooldowns)')
    ap.add_argument('--json', help='write the full per-game readings here')
    args = ap.parse_args()

    paths = []
    for p in args.timelines:
        paths.extend(sorted(glob.glob(p)) if any(c in p for c in '*?[') else [p])

    rows = [r for r in (analyse(p, args.blink_cd) for p in paths) if r]
    with_axe = [r for r in rows if r['has_axe']]
    with_blink = [r for r in with_axe if r['D_holds_blink']]
    casts = [c for r in with_axe for c in r['A_casts']]

    print('== corpus ==')
    print(f'  timelines            {len(rows)}')
    print(f'  games with Axe       {len(with_axe)}')
    print(f'  games where Axe owns a dagger  {len(with_blink)}  (section D)')
    for r in with_blink:
        print(f'    {r["timeline"]:34s} first hold t={r["D_first_hold_t"]}  '
              f'{r["D_hold_frames"]} frames')

    print('\n== A. exact domain (every real item_blink cast) ==')
    print(f'  casts                {len(casts)}')
    by_branch = collections.Counter(c['branch_hint'] for c in casts)
    print(f'  by branch hint       {dict(by_branch)}')
    print(f'  IN DOMAIN (guard would have held)  '
          f'{sum(1 for c in casts if c["guard_would_hold"])}')
    print('  clause breakdown:')
    print(f'    call learned          {sum(1 for c in casts if c["call_learned"])}'
          f'/{len(casts)}')
    print(f'    call unavailable      '
          f'{sum(1 for c in casts if c["call_learned"] and not c["call_available"])}'
          f'/{len(casts)}')
    print(f'    >=2 enemies at landing '
          f'{sum(1 for c in casts if len(c["enemies_at_landing_within_315"]) >= 2)}'
          f'/{len(casts)}')
    hist = collections.Counter(len(c['enemies_at_landing_within_315']) for c in casts)
    print(f'    enemies-at-landing histogram {dict(sorted(hist.items()))}')
    for r in with_axe:
        for c in r['A_casts']:
            print(f'    {r["timeline"][:19]} t={c["t"]:7.1f} {c["branch_hint"]:9s} '
                  f'jump={c["jump"]:5d} cos={c["cos_toward_own_ancient"]:+.3f} '
                  f'hp={c["hp_pct"]:.2f} call(learned={c["call_learned"]},'
                  f'avail={c["call_available"]}) landing={c["enemies_at_landing_within_315"]} '
                  f'nearest_pre={c["nearest_enemy_before_jump"]} '
                  f'HOLD={c["guard_would_hold"]}')

    print('\n== B. loose ceiling (branch clauses ignored; upper bound) ==')
    cand = sum(r['B_candidate_frames'] for r in with_axe)
    unav = sum(r['B_call_unavailable_frames'] for r in with_axe)
    true_ = sum(r['B_predicate_true_frames'] for r in with_axe)
    mx = max([r['B_max_enemies_at_projected_landing'] for r in with_axe] or [0])
    b2 = sum(r['B2_not_outnumbered_frames'] for r in with_axe)
    eps = [(r['timeline'], e) for r in with_axe for e in r['B2_episodes']]
    print(f'  corpse frames dropped before the ceiling (#78)        '
          f'{sum(r["B_corpse_frames_dropped"] for r in with_axe)}')
    print(f'  frames: dagger held + off cd + enemy in (500,1200]   {cand}')
    print(f'    of those, Call learned but unavailable              {unav}')
    print(f'    of those, ALSO >=2 enemies at projected landing     {true_}')
    print(f'    B2: ALSO allies >= all live enemies within 1200 of target {b2}')
    print(f'    B2_min: ALSO allies >= the guard\'s own enemy count (loosest) '
          f'{sum(r["B2_min_not_outnumbered_frames"] for r in with_axe)}')
    print(f'  max enemies at any projected landing point            {mx}')
    ah, fh = collections.Counter(), collections.Counter()
    for r in with_axe:
        ah.update({int(k): v for k, v in r['B2_allies_hist'].items()})
        fh.update({int(k): v for k, v in r['B2_foes_hist'].items()})
    print(f'  on the {true_} predicate-true frames, heads within 1200 of target:')
    print(f'    allies (Axe included) {dict(sorted(ah.items()))}')
    print(f'    enemy heroes          {dict(sorted(fh.items()))}')

    print('\n== B3. the ally ring over the WHOLE ceiling (not just the '
          'predicate-true slice) ==')
    a_all, a_unav, a_axe = (collections.Counter(), collections.Counter(),
                            collections.Counter())
    for r in with_axe:
        a_all.update({int(k): v for k, v in r['B3_allies_hist_all'].items()})
        a_unav.update({int(k): v for k, v in r['B3_allies_hist_unavail'].items()})
        a_axe.update({int(k): v for k, v in r['B3_axe_ring_hist'].items()})

    def _grouped(counter):
        tot = sum(counter.values())
        n = sum(v for k, v in counter.items() if k >= 2)
        return n, tot, (100.0 * n / tot if tot else 0.0)

    for label, c in (('all candidate frames        ', a_all),
                     ('  of those, Call unavailable', a_unav)):
        n, tot, pct = _grouped(c)
        print(f'  allies within 1200 of the best target, {label} '
              f'{dict(sorted(c.items()))}')
        print(f'    >=2 (i.e. Axe had company): {n}/{tot} = {pct:.1f}%')
    n, tot, pct = _grouped(a_axe)
    print(f'  cross-check, allies within 1200 of AXE      '
          f'{dict(sorted(a_axe.items()))}')
    print(f'    >=2: {n}/{tot} = {pct:.1f}%  '
          f'(ring the branch does NOT read; separates "nobody near the target" '
          f'from "nobody near Axe")')

    print('\n  the same three stages counted in EPISODES, which is the n that '
          'belongs in any bound:')

    def _episodes(pick):
        eps = []
        for r in with_axe:
            for row in r['B3_rows']:
                if not pick(row):
                    continue
                if eps and eps[-1]['g'] == r['timeline'] \
                        and row['t'] - eps[-1]['t_end'] <= 2.0:
                    eps[-1]['t_end'] = row['t']
                    eps[-1]['frames'] += 1
                    eps[-1]['allies_max'] = max(eps[-1]['allies_max'],
                                                row['allies'])
                else:
                    eps.append({'g': r['timeline'], 't_start': row['t'],
                                't_end': row['t'], 'frames': 1,
                                'allies_max': row['allies']})
        return eps

    stages = (('all candidate frames', lambda r: True),
              ('Call unavailable', lambda r: r['unavail']),
              ('predicate-true (the guard\'s own domain)', lambda r: r['pred']))
    for si, (label, pick) in enumerate(stages):
        stage_eps = _episodes(pick)
        comp = sum(1 for e in stage_eps if e['allies_max'] >= 2)
        frames = sum(e['frames'] for e in stage_eps)
        longest = max([e['frames'] for e in stage_eps] or [0])
        print(f'    {label:42s} {frames:4d} frames -> {len(stage_eps):3d} '
              f'episodes, {comp} with company '
              f'({100.0*comp/max(len(stage_eps),1):.1f}%), '
              f'longest run {longest} frames')
        if si == len(stages) - 1:
            for e in stage_eps:
                print(f'      {e["g"][:19]} t={e["t_start"]}-{e["t_end"]} '
                      f'{e["frames"]} frames allies_max={e["allies_max"]}')
    print(f'  B2 episodes ({len(eps)}, {len(eps)/max(len(with_blink),1):.2f}/game '
          f'over the {len(with_blink)} dagger games):')
    for name, e in eps:
        print(f'    {name[:19]} t={e["t_start"]}-{e["t_end"]} '
              f'{e["frames"]} frames, {e["enemies_at_landing"]} enemies at landing')

    if args.json:
        json.dump(rows, open(args.json, 'w'), indent=1)
        print(f'\nwrote {args.json}')
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""`rotscope` (GH #368) condition-(a) domain reader -- READ-ONLY, offline.

WHAT THE GATE ACTUALLY BRANCHES ON
----------------------------------
`bots/mode_roam_generic.lua`, the Pudge block of `ThinkIndividualRoaming`:

    if botName == 'npc_dota_hero_pudge' then
        local rotscope = J.IsModeTurbo() and J.IsSoakCandidate('rotscope')
        local Rot = bot:GetAbilityByName('pudge_rot')
        if Rot:GetToggleState() then
            local botTarget = J.GetProperTarget(bot)          -- SHADOW
            ... move branch ...
            if rotscope and J.IsValid(botTarget) then
                bot:ActionQueue_AttackUnit(botTarget, false)
            end
        end
        if not rotscope then
            bot:ActionQueue_AttackUnit(botTarget, false)      -- FILE-LOCAL
        end
    end

So the two legs differ by exactly one order, and the leading term of the
difference set is a predicate this dump CAN see: **Rot's toggle state**.

  * baseline (shipped): the order is issued on every frame this block runs,
    Rot toggled or not;
  * armed: the order is issued only INSIDE the toggled block.

⇒ every roam frame with **Rot OFF** is in the difference set, and every frame
with Rot ON is a frame where both legs may issue an order.  That is the shape
this file measures: Pudge's own auto-attack activity split by his Rot toggle
state, armed leg vs baseline leg.

WHAT THIS FILE DOES **NOT** CLAIM
---------------------------------
LIMIT 1 -- **The dump carries no bot orders.**  `ActionQueue_AttackUnit` is
    not in the combat log; nothing here observes the order itself.  What is
    observed is the auto-attack damage an order that LANDS produces.  An
    order on a `nil` handle produces nothing observable at all, and §CU.5
    already registered that `J.GetProperTarget` answered `nil` on 993/993
    fixture frames.  ⇒ a null reading here is `DOMAIN-NOT-REACHED`-shaped,
    never "the fix has no effect".

LIMIT 2 -- **Mode is not observable.**  Auto-attacks arrive from every mode
    (laning, fight, push, defend), not just roam.  Those are common to both
    legs and sit in BOTH the ON and the OFF bucket, so they dilute the ratio
    toward 1.0 in both legs.  ⇒ the estimator is a **lower bound on the
    effect**, and only a DIFFERENCE BETWEEN LEGS is readable, never the level.

LIMIT 3 -- **Detector counts do not have side bias removed** (iron rule
    4(i-b)).  Both physical strata are printed; **two strata of opposite sign
    are noise and must not be written into a conclusion**.

LIMIT 4 -- **Rot windows come from `modifier_pudge_rot` on Pudge himself.**
    The aura also applies that modifier to victims; those rows are excluded by
    `target == pudge`.  An unmatched trailing ADD is closed at the last
    snapshot, an unmatched REMOVE is dropped (both counted and printed).

LIMIT 5 -- **`hp_pct <= 0` is not death** (GH #470, replay-check 2026-09-04).
    `round3` rounds a 1-HP hero to `0.0`.  Aliveness here reads
    `hp > 0 or hp_pct > 0`, and Pudge's DEATH/RESPAWN is taken from the
    snapshot stream, never from `hp_pct` alone.

LIMIT 6 -- **"Rot OFF" is not always a DECISION.**  Found frame by frame on
    this corpus, not reasoned: a silenced Pudge cannot toggle Rot at all.
    `20260904_003516_slot8` t=1015.7-1021.7 is Ancient Seal on Pudge; he
    right-clicks Skywrath at 219u for 6.3 s with meat_hook/rot/dismember all
    at `cd=0.0` and mana 1002/1002, and casts hook+heap+dismember at t=1023.5,
    1.8 s after the seal expires.  The baseline twin
    (`20260904_004848_slot6` t=977.8-983.8) is the SAME modifier and the same
    recovery.  ⇒ part of the OFF bucket is a stretch where the gate's ON
    branch is unreachable by construction.  `disable_windows()` measures that
    share; on this corpus it was **50% of the solo OFF episodes** (armed 7/23,
    baseline 12/15), i.e. the two legs' OFF buckets are not the same object.

Usage:
    rotscope_domain.py --sweep <sweep_out_dir> [<sweep_out_dir> ...]
    rotscope_domain.py --selfcheck
    rotscope_domain.py --sweep <dir> --pin <game> --t <sec>
"""
import argparse
import collections
import json
import os
import sys

PUDGE = 'npc_dota_hero_pudge'
ROT_MOD = 'modifier_pudge_rot'
AUTO_ATTACK_INFLICTOR = 'dota_unknown'  # combat-log inflictor for a right-click
TEAM_OF_SIDE = {'radiant': 2, 'dire': 3}


# ---------------------------------------------------------------- primitives

def is_live(snap):
    """LIMIT 5: a 1-HP hero reads `hp_pct == 0` after the dumper's round3."""
    return (snap.get('hp') or 0) > 0 or (snap.get('hp_pct') or 0) > 0


def pudge_entity(snapshots):
    """The real Pudge, not an illusion: the `idx` with the most live frames.

    Illusions share the hero string; they never outlive the original over a
    whole game, so max live-frame count is a safe discriminator here.  Returns
    (idx, team) or (None, None).
    """
    live = collections.Counter()
    team = {}
    for s in snapshots:
        if s.get('hero') != PUDGE:
            continue
        team[s.get('idx')] = s.get('team')
        if is_live(s):
            live[s.get('idx')] += 1
    if not live:
        return None, None
    idx = live.most_common(1)[0][0]
    return idx, team.get(idx)


def rot_windows(events, snapshots):
    """[(t_on, t_off), ...] from Rot's self modifier.  LIMIT 4."""
    marks = []
    for e in events:
        if e.get('inflictor') != ROT_MOD or e.get('target') != PUDGE:
            continue
        if e.get('type') == 'MODIFIER_ADD':
            marks.append((e['t'], 1))
        elif e.get('type') == 'MODIFIER_REMOVE':
            marks.append((e['t'], -1))
    marks.sort(key=lambda m: (m[0], -m[1]))
    t_end = max((s['t'] for s in snapshots), default=0.0)
    wins, open_t, dropped = [], None, 0
    for t, kind in marks:
        if kind == 1:
            if open_t is None:
                open_t = t
        else:
            if open_t is None:
                dropped += 1
            else:
                if t > open_t:
                    wins.append((open_t, t))
                open_t = None
    unmatched_add = 0
    if open_t is not None:
        wins.append((open_t, t_end))
        unmatched_add = 1
    return wins, dropped, unmatched_add


# LIMIT 6.  Substrings of the MODIFIER name, not a whitelist of ability names:
# the combat log carries the modifier, and a new silence source added by a
# patch must not silently fall out of the denominator.  Deliberately WIDE --
# it is used to say how much of the OFF bucket is NOT a decision, and a wide
# read makes that share an UPPER bound, which is the conservative direction
# for "the OFF bucket is contaminated".
DISABLE_KEYS = ('silence', 'seal', 'hex', 'stun', 'bash', 'sheep', 'fear',
                'doom', 'shackle', 'ensnare', 'root')


def disable_windows(events, snapshots, target=PUDGE):
    """[(t0, t1), ...] where a silence/disable modifier sits on Pudge.

    Tracked PER MODIFIER NAME: two different silences overlapping would
    otherwise close each other's window on the first REMOVE.
    """
    marks = collections.defaultdict(list)
    for e in events:
        if e.get('target') != target:
            continue
        mod = (e.get('inflictor') or '').lower()
        if not mod.startswith('modifier_'):
            continue
        if not any(k in mod for k in DISABLE_KEYS):
            continue
        if e.get('type') == 'MODIFIER_ADD':
            marks[mod].append((e['t'], 1))
        elif e.get('type') == 'MODIFIER_REMOVE':
            marks[mod].append((e['t'], -1))
    t_end = max((s['t'] for s in snapshots), default=0.0)
    wins = []
    for mod, ms in marks.items():
        ms.sort(key=lambda m: (m[0], -m[1]))
        open_t = None
        for t, kind in ms:
            if kind == 1:
                if open_t is None:
                    open_t = t
            else:
                if open_t is not None and t > open_t:
                    wins.append((open_t, t))
                open_t = None
        if open_t is not None and t_end > open_t:
            wins.append((open_t, t_end))
    return sorted(wins)


def alive_windows(snapshots, idx):
    """[(t0, t1), ...] where Pudge is live, from consecutive live snapshots."""
    rows = sorted((s for s in snapshots if s.get('hero') == PUDGE and s.get('idx') == idx),
                  key=lambda s: s['t'])
    wins, start, prev = [], None, None
    for s in rows:
        if is_live(s):
            if start is None:
                start = s['t']
            prev = s['t']
        else:
            if start is not None and prev is not None and prev > start:
                wins.append((start, prev))
            start, prev = None, None
    if start is not None and prev is not None and prev > start:
        wins.append((start, prev))
    return wins


def overlap(a, b):
    """Total length of intersection between two interval lists."""
    total = 0.0
    for s0, s1 in a:
        for t0, t1 in b:
            lo, hi = max(s0, t0), min(s1, t1)
            if hi > lo:
                total += hi - lo
    return total


def subtract(a, b):
    """a minus b, as an interval list."""
    out = []
    for s0, s1 in a:
        pieces = [(s0, s1)]
        for t0, t1 in b:
            nxt = []
            for p0, p1 in pieces:
                if t1 <= p0 or t0 >= p1:
                    nxt.append((p0, p1))
                    continue
                if p0 < t0:
                    nxt.append((p0, t0))
                if t1 < p1:
                    nxt.append((t1, p1))
            pieces = nxt
        out.extend(pieces)
    return out


def in_windows(t, wins):
    return any(w0 <= t <= w1 for w0, w1 in wins)


def pudge_autoattacks(events, hero_only):
    out = []
    for e in events:
        if e.get('type') != 'DAMAGE' or e.get('actor') != PUDGE:
            continue
        if e.get('inflictor') != AUTO_ATTACK_INFLICTOR:
            continue
        if hero_only and not e.get('target_hero'):
            continue
        out.append(e)
    return out


# ------------------------------------------------------------------ per game

def read_game(tl, armed_side):
    snaps = tl.get('snapshots') or []
    events = tl.get('events') or []
    idx, team = pudge_entity(snaps)
    if idx is None:
        return None
    rot, dropped_rem, unmatched_add = rot_windows(events, snaps)
    alive = alive_windows(snaps, idx)
    on_wins = [(max(a, r), min(b, s)) for a, b in alive for r, s in rot
               if min(b, s) > max(a, r)]
    off_wins = subtract(alive, rot)
    on_s = sum(b - a for a, b in on_wins)
    off_s = sum(b - a for a, b in off_wins)

    res = {
        'pudge_team': team,
        'armed_side': armed_side,
        'leg': ('armed' if team == TEAM_OF_SIDE.get(armed_side) else 'baseline'),
        'phys_side': ('radiant' if team == 2 else 'dire' if team == 3 else None),
        'rot_windows': len(rot),
        'rot_dropped_remove': dropped_rem,
        'rot_unmatched_add': unmatched_add,
        'on_s': round(on_s, 2),
        'off_s': round(off_s, 2),
    }
    for label, hero_only in (('all', False), ('hero', True)):
        atk = pudge_autoattacks(events, hero_only)
        on = sum(1 for e in atk if in_windows(e['t'], on_wins))
        off = sum(1 for e in atk if in_windows(e['t'], off_wins))
        res['atk_%s_on' % label] = on
        res['atk_%s_off' % label] = off
        res['rate_%s_on' % label] = (on / on_s) if on_s > 0 else None
        res['rate_%s_off' % label] = (off / off_s) if off_s > 0 else None

    # LIMIT 6: how much of the OFF bucket is a stretch where Rot COULD NOT be
    # toggled.  Reported, never subtracted -- subtracting it would be a second
    # unregistered cut on the same corpus.
    dis = disable_windows(events, snaps)
    res['off_disabled_s'] = round(overlap(off_wins, dis), 2)
    res['on_disabled_s'] = round(overlap(on_wins, dis), 2)
    return res


def load_sweeps(dirs):
    games = []
    for d in dirs:
        man = os.path.join(d, 'games_manifest.jsonl')
        if not os.path.exists(man):
            print('[rotscope] no manifest in %s' % d, file=sys.stderr)
            continue
        with open(man) as fh:
            for line in fh:
                m = json.loads(line)
                tlf = os.path.join(d, 'timelines', '%s.timeline.json' % m['game'])
                if not os.path.exists(tlf):
                    continue
                games.append((m, tlf))
    return games


def run(dirs, pin=None, pin_t=None):
    games = load_sweeps(dirs)
    rows = []
    for m, tlf in games:
        with open(tlf) as fh:
            tl = json.load(fh)
        r = read_game(tl, m['side'])
        if r is None:
            continue
        r['game'] = m['game']
        r['seed'] = m['seed']
        rows.append(r)
        if pin and m['game'] == pin:
            pin_report(tl, r, pin_t)
    return rows


def pin_report(tl, row, t):
    print('\n=== PIN %s  t=%s ===' % (row['game'], t))
    snaps = [s for s in tl['snapshots'] if s.get('hero') == PUDGE]
    near = sorted(snaps, key=lambda s: abs(s['t'] - t))[:1]
    for s in near:
        print('  pudge snapshot t=%.2f pos=(%.0f,%.0f) hp=%s hp_pct=%s level=%s'
              % (s['t'], s['x'], s['y'], s['hp'], s['hp_pct'], s['level']))
    ev = [e for e in tl['events'] if abs(e['t'] - t) <= 3.0
          and (e.get('actor') == PUDGE or e.get('target') == PUDGE)]
    for e in ev:
        print('  t=%.2f %s actor=%s target=%s infl=%s val=%s'
              % (e['t'], e['type'], e.get('actor'), e.get('target'),
                 e.get('inflictor'), e.get('value')))


def summarise(rows):
    print('\n## games: %d' % len(rows))
    by = collections.defaultdict(list)
    for r in rows:
        by[(r['leg'], r['phys_side'])].append(r)

    print('\n| leg | phys side | games | rot windows/game | Rot ON s | Rot OFF s | '
          'atk ON | atk OFF | rate ON | rate OFF | OFF/ON |')
    print('|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
    out = {}
    for key in sorted(by, key=lambda k: (k[0], str(k[1]))):
        g = by[key]
        on_s = sum(r['on_s'] for r in g)
        off_s = sum(r['off_s'] for r in g)
        on = sum(r['atk_all_on'] for r in g)
        off = sum(r['atk_all_off'] for r in g)
        r_on = on / on_s if on_s else float('nan')
        r_off = off / off_s if off_s else float('nan')
        ratio = r_off / r_on if r_on else float('nan')
        out[key] = ratio
        print('| %s | %s | %d | %.1f | %.0f | %.0f | %d | %d | %.4f | %.4f | %.3f |'
              % (key[0], key[1], len(g), sum(r['rot_windows'] for r in g) / len(g),
                 on_s, off_s, on, off, r_on, r_off, ratio))

    print('\n### LIMIT 6: share of each bucket under a Pudge disable (Rot un-toggleable)')
    print('| leg | phys side | OFF s | OFF disabled s | share | ON s | ON disabled s |')
    print('|---|---|---:|---:|---:|---:|---:|')
    for key in sorted(by, key=lambda k: (k[0], str(k[1]))):
        g = by[key]
        off_s = sum(r['off_s'] for r in g)
        offd = sum(r['off_disabled_s'] for r in g)
        on_s = sum(r['on_s'] for r in g)
        ond = sum(r['on_disabled_s'] for r in g)
        print('| %s | %s | %.0f | %.0f | %.1f%% | %.0f | %.0f |'
              % (key[0], key[1], off_s, offd, 100.0 * offd / off_s if off_s else 0,
                 on_s, ond))

    print('\n### stratum readings (iron rule 4(i-a): BOTH strata registered)')
    for side in ('radiant', 'dire'):
        a = out.get(('armed', side))
        b = out.get(('baseline', side))
        if a is None or b is None:
            print('- %s: MISSING LEG (armed=%s baseline=%s) -- no reading' % (side, a, b))
            continue
        print('- %s: armed OFF/ON %.3f vs baseline %.3f  =>  delta %+.3f'
              % (side, a, b, a - b))
    return out


# ---------------------------------------------------------------- selfcheck

def _snap(t, hp=100, hp_pct=1.0, idx=1, team=2):
    return {'t': t, 'hero': PUDGE, 'idx': idx, 'team': team, 'x': 0.0, 'y': 0.0,
            'hp': hp, 'hp_pct': hp_pct, 'level': 1}


def _mod(t, kind, target=PUDGE):
    return {'t': t, 'type': kind, 'actor': PUDGE, 'target': target,
            'inflictor': ROT_MOD, 'value': 1, 'actor_hero': True, 'target_hero': True}


def _atk(t, target='npc_dota_hero_lion', target_hero=True):
    return {'t': t, 'type': 'DAMAGE', 'actor': PUDGE, 'target': target,
            'inflictor': AUTO_ATTACK_INFLICTOR, 'value': 50,
            'actor_hero': True, 'target_hero': target_hero}


def selfcheck():
    checks, fails = 0, 0

    def ck(name, got, want):
        nonlocal checks, fails
        checks += 1
        if got != want:
            fails += 1
            print('FAIL %s: got %r want %r' % (name, got, want))

    snaps = [_snap(t) for t in range(0, 21)]

    # 1. clean window pair
    ev = [_mod(5, 'MODIFIER_ADD'), _mod(8, 'MODIFIER_REMOVE'),
          _mod(12, 'MODIFIER_ADD'), _mod(14, 'MODIFIER_REMOVE')]
    w, drop, unm = rot_windows(ev, snaps)
    ck('windows', w, [(5, 8), (12, 14)])
    ck('dropped', drop, 0)
    ck('unmatched', unm, 0)

    # 2. LIMIT 4: the aura's modifier on a VICTIM must not open a window
    ev2 = ev + [_mod(1, 'MODIFIER_ADD', target='npc_dota_hero_lion'),
                _mod(3, 'MODIFIER_REMOVE', target='npc_dota_hero_lion')]
    w2, _, _ = rot_windows(ev2, snaps)
    ck('victim rows excluded', w2, [(5, 8), (12, 14)])

    # 3. unmatched trailing ADD closes at the last snapshot, and is counted
    w3, d3, u3 = rot_windows([_mod(18, 'MODIFIER_ADD')], snaps)
    ck('trailing add window', w3, [(18, 20)])
    ck('trailing add counted', u3, 1)
    # ... and a leading REMOVE is dropped, and is counted
    w4, d4, u4 = rot_windows([_mod(2, 'MODIFIER_REMOVE')], snaps)
    ck('leading remove dropped', w4, [])
    ck('leading remove counted', d4, 1)

    # 4. LIMIT 5: a 1-HP hero reading hp_pct 0.0 is LIVE, not a corpse
    ck('1hp live', is_live({'hp': 1, 'hp_pct': 0.0}), True)
    ck('true corpse', is_live({'hp': 0, 'hp_pct': 0.0}), False)
    ck('hp_pct only', is_live({'hp': 0, 'hp_pct': 0.02}), True)

    # 5. interval algebra
    ck('subtract', subtract([(0, 10)], [(2, 4)]), [(0, 2), (4, 10)])
    ck('subtract whole', subtract([(0, 10)], [(0, 10)]), [])
    ck('overlap', overlap([(0, 10)], [(5, 20)]), 5.0)

    # 6. leg assignment follows Pudge's TEAM, not the game's armed side alone
    tl = {'snapshots': snaps, 'events': ev + [_atk(6), _atk(10), _atk(11)]}
    r = read_game(tl, 'radiant')
    ck('leg armed', r['leg'], 'armed')
    ck('phys side', r['phys_side'], 'radiant')
    r2 = read_game(tl, 'dire')
    ck('leg baseline', r2['leg'], 'baseline')

    # 7. attacks land in the right bucket: t=6 inside (5,8); t=10,11 outside
    ck('atk on', r['atk_all_on'], 1)
    ck('atk off', r['atk_all_off'], 2)
    ck('on seconds', r['on_s'], 5.0)     # (5,8) + (12,14)
    ck('off seconds', r['off_s'], 15.0)  # 20 alive - 5 on

    # 8. hero_only split
    tl2 = {'snapshots': snaps,
           'events': ev + [_atk(6), _atk(6.5, 'npc_dota_creep', False)]}
    r3 = read_game(tl2, 'radiant')
    ck('atk all on', r3['atk_all_on'], 2)
    ck('atk hero on', r3['atk_hero_on'], 1)

    # 9. a non-auto-attack inflictor is NOT an auto-attack
    rot_dmg = {'t': 6, 'type': 'DAMAGE', 'actor': PUDGE,
               'target': 'npc_dota_hero_lion', 'inflictor': 'pudge_rot',
               'value': 5, 'actor_hero': True, 'target_hero': True}
    ck('rot damage excluded', len(pudge_autoattacks([rot_dmg], False)), 0)

    # 10. a DEAD stretch is removed from the OFF denominator
    dead = [_snap(t) for t in range(0, 11)] + \
           [_snap(t, hp=0, hp_pct=0.0) for t in range(11, 16)] + \
           [_snap(t) for t in range(16, 21)]
    aw = alive_windows(dead, 1)
    ck('alive windows split', aw, [(0, 10), (16, 20)])
    tl4 = {'snapshots': dead, 'events': ev}
    r4 = read_game(tl4, 'radiant')
    ck('off excludes death', r4['off_s'], 11.0)  # 14 alive - 3 on(5..8)

    # 11. illusion (a second idx with fewer live frames) does not win
    withillu = snaps + [_snap(t, idx=9) for t in range(0, 5)]
    ck('real pudge idx', pudge_entity(withillu)[0], 1)

    # 12. LIMIT 6: silence windows, and two OVERLAPPING sources must not close
    #     each other's window on the first REMOVE
    def _dis(t, kind, mod):
        return {'t': t, 'type': kind, 'actor': 'npc_dota_hero_skywrath_mage',
                'target': PUDGE, 'inflictor': mod, 'value': 1,
                'actor_hero': True, 'target_hero': True}
    seal = 'modifier_skywrath_mage_ancient_seal'
    hexx = 'modifier_sheepstick_debuff'
    ck('one silence window',
       disable_windows([_dis(3, 'MODIFIER_ADD', seal),
                        _dis(9, 'MODIFIER_REMOVE', seal)], snaps),
       [(3, 9)])
    ck('overlapping silences kept apart',
       disable_windows([_dis(3, 'MODIFIER_ADD', seal),
                        _dis(4, 'MODIFIER_ADD', hexx),
                        _dis(5, 'MODIFIER_REMOVE', hexx),
                        _dis(9, 'MODIFIER_REMOVE', seal)], snaps),
       [(3, 9), (4, 5)])
    # a non-disable modifier is not a disable
    ck('buff is not a disable',
       disable_windows([_dis(3, 'MODIFIER_ADD', 'modifier_item_pipe_aura'),
                        _dis(9, 'MODIFIER_REMOVE', 'modifier_item_pipe_aura')],
                       snaps),
       [])
    # ... and a disable on SOMEONE ELSE is not Pudge's
    other = [dict(_dis(3, 'MODIFIER_ADD', seal), target='npc_dota_hero_lion'),
             dict(_dis(9, 'MODIFIER_REMOVE', seal), target='npc_dota_hero_lion')]
    ck('other hero silence excluded', disable_windows(other, snaps), [])
    # the per-game row reports the contaminated share of each bucket
    tl5 = {'snapshots': snaps,
           'events': ev + [_dis(10, 'MODIFIER_ADD', seal),
                           _dis(13, 'MODIFIER_REMOVE', seal)]}
    r5 = read_game(tl5, 'radiant')
    ck('off disabled seconds', r5['off_disabled_s'], 2.0)   # 10..12 of (8,12)
    ck('on disabled seconds', r5['on_disabled_s'], 1.0)     # 12..13 of (12,14)

    print('SELFCHECK %d checks / %d failures' % (checks, fails))
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sweep', nargs='*', default=[])
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--pin')
    ap.add_argument('--t', type=float)
    ap.add_argument('--json')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.sweep:
        ap.error('--sweep or --selfcheck required')
    rows = run(a.sweep, a.pin, a.t)
    summarise(rows)
    if a.json:
        with open(a.json, 'w') as fh:
            json.dump(rows, fh, indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""axe_jump_pick_audit.py -- audit the ONE heuristic step inside
`axe_blink_domain.py` that the replay-check stream registered as an
unfalsified residual risk (charter 2026-08-21T06:46Z, "next round (4)").

Background.  `axe_blink_domain.py` section A locates the teleport belonging to
an `item_blink` ITEM event as

    win  = snapshots of Axe with  t-0.5 <= s.t <= t+2.0
    pre, post = the adjacent pair in `win` with the LARGEST displacement

and then evaluates the whole `axeblink` predicate at `post` (the landing
point): ">= 2 live enemy heroes within Call's 315 radius of the LANDING".
Everything downstream -- `A_in_domain`, the GH #71 branch fingerprint
(cos toward own ancient), `nearest_enemy_before_jump` -- hangs off that one
argmax.  If some OTHER large displacement lands inside the same 2.5s window,
the argmax picks it and the predicate is evaluated at the wrong place.

Two contaminants are known to produce Axe displacements far larger than a
blink (cast range 1200):

  * a TP scroll landing (`modifier_teleporting` channel ends inside the
    window) -- ~1e4 units, the shape that already fooled `capmono_refusal.py`
    (replay-check 2026-08-21T04:36Z);
  * a death -> fountain respawn inside the window -- also ~1e4.

Both would push `jump` far past 1400, so `branch_hint` degrades to 'other'
(the retreat branch requires 1100 <= jump <= 1400) -- that is the structural
resistance the charter noted.  But `guard_would_hold` has NO such guard: it is
computed at whatever `post` the argmax returned, so a contaminated cast is
silently scored as OUT of the domain (enemies near a fountain: 0).  The bias
is therefore one-directional: contamination can only UNDERCOUNT
`A_in_domain`, never overcount it.  That matters because the standing
`axeblink` disposition is DOMAIN-NOT-REACHED off A = 0/11.

What this script measures, per `item_blink` cast:

  1. every adjacent step in the window, not just the winner, so a human can
     see the margin between the winner and the runner-up;
  2. whether the winning step exceeds `--max-blink` (default 1400) -- i.e. is
     physically impossible for a blink and hence certainly not one;
  3. whether Axe was mid-`modifier_teleporting` or dead anywhere in the
     window (the two known contaminants, detected from events, not guessed
     from geometry);
  4. the game-wide base rate of >`--max-blink` Axe steps, and the closest
     such step to any blink cast -- the margin by which this corpus misses
     the failure, which is what makes the "no contamination here" reading
     falsifiable rather than lucky.

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.

Usage:
    python3 axe_jump_pick_audit.py tl/*.json [--json out.json]
"""
import argparse
import glob
import json
import math
import os
import sys

AXE = 'npc_dota_hero_axe'
BLINK_NAMES = ('blink_dagger', 'item_blink')
WIN_LO, WIN_HI = -0.5, 2.0      # axe_blink_domain.py's window, verbatim
MIN_JUMP = 250                  # axe_blink_domain.py's MIN_JUMP, verbatim


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def axe_blink_casts(events):
    out = []
    for e in events:
        if e.get('type') != 'ITEM' or e.get('actor') != AXE:
            continue
        inf = e.get('inflictor') or ''
        if any(b in inf for b in BLINK_NAMES):
            out.append(e)
    return out


def tp_channel_spans(events):
    """[start, end] of every `modifier_teleporting` Axe carried.

    Same mechanism `capmono_refusal.tp_channel_spans()` uses: exact from
    MODIFIER_ADD/REMOVE, never inferred from displacement.
    """
    spans, open_at = [], None
    for e in events:
        if e.get('target') != AXE or e.get('inflictor') != 'modifier_teleporting':
            continue
        if e.get('type') == 'MODIFIER_ADD' and open_at is None:
            open_at = e['t']
        elif e.get('type') == 'MODIFIER_REMOVE' and open_at is not None:
            spans.append((open_at, e['t']))
            open_at = None
    if open_at is not None:
        spans.append((open_at, 1e9))
    return spans


def death_spans(events):
    """[death, next respawn-ish] windows, from DEATH events only.

    Deliberately NOT hp-based: `hp_pct > 0` is not a liveness predicate
    (GH #78).  A cast window overlapping a death span is flagged for manual
    reconstruction rather than auto-classified, because Axe has no in-place
    revive (unlike Wraith King) but aegis exists.
    """
    return [e['t'] for e in events
            if e.get('type') == 'DEATH' and e.get('target') == AXE]


def audit_game(path, max_blink):
    d = json.load(open(path))
    name = os.path.basename(path).replace('.json', '')
    if AXE not in d.get('game', {}).get('teams', {}):
        return {'game': name, 'axe_present': False}

    axe = sorted([s for s in d['snapshots'] if s['hero'] == AXE],
                 key=lambda s: s['t'])
    ev = d['events']
    casts = axe_blink_casts(ev)
    tps = tp_channel_spans(ev)
    deaths = death_spans(ev)

    # game-wide base rate of impossible-for-a-blink Axe steps
    big_steps = []
    for a, b in zip(axe, axe[1:]):
        st = dist(a['x'], a['y'], b['x'], b['y'])
        if st > max_blink:
            big_steps.append({'t0': round(a['t'], 1), 't1': round(b['t'], 1),
                              'step': round(st)})

    rows = []
    for c in casts:
        t = c['t']
        win = [s for s in axe if t + WIN_LO <= s['t'] <= t + WIN_HI]
        steps = [{'t0': round(a['t'], 1), 't1': round(b['t'], 1),
                  'step': round(dist(a['x'], a['y'], b['x'], b['y']))}
                 for a, b in zip(win, win[1:])]
        ordered = sorted(steps, key=lambda s: -s['step'])
        win_lo, win_hi = t + WIN_LO, t + WIN_HI
        rows.append({
            't': round(t, 1),
            'n_snapshots': len(win),
            'steps': steps,
            'picked': ordered[0] if ordered else None,
            'runner_up': ordered[1] if len(ordered) > 1 else None,
            'picked_resolves': bool(ordered and ordered[0]['step'] >= MIN_JUMP),
            'picked_impossible_for_blink':
                bool(ordered and ordered[0]['step'] > max_blink),
            'n_steps_over_min_jump': sum(1 for s in steps
                                         if s['step'] >= MIN_JUMP),
            'tp_channel_overlap': [[round(a, 1), round(b, 1)] for a, b in tps
                                   if a <= win_hi and b >= win_lo],
            'death_in_window': [round(x, 1) for x in deaths
                                if win_lo <= x <= win_hi],
        })

    # margin: how close does any impossible step come to a cast window?
    margin = None
    for b in big_steps:
        for r in rows:
            gap = max(r['t'] + WIN_LO - b['t1'], b['t0'] - (r['t'] + WIN_HI))
            gap = max(gap, 0.0)
            if margin is None or gap < margin[0]:
                margin = (round(gap, 1), b, r['t'])

    return {
        'game': name,
        'axe_present': True,
        'axe_team': d['game']['teams'][AXE],
        'n_casts': len(casts),
        'casts': rows,
        'n_tp_channels': len(tps),
        'n_deaths': len(deaths),
        'big_steps': big_steps,
        'closest_big_step_to_a_cast_window_s': margin[0] if margin else None,
        'closest_big_step': margin[1] if margin else None,
        'closest_big_step_cast_t': margin[2] if margin else None,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('timelines', nargs='+')
    ap.add_argument('--max-blink', type=float, default=1400.0,
                    help='largest displacement a real blink can produce '
                         '(cast range 1200 + slack); above this the step is '
                         'certainly not a blink')
    ap.add_argument('--json')
    a = ap.parse_args()

    paths = []
    for p in a.timelines:
        paths.extend(sorted(glob.glob(p)) if any(c in p for c in '*?[') else [p])

    out, tot_casts, tot_contam, with_axe = [], 0, 0, 0
    for p in paths:
        r = audit_game(p, a.max_blink)
        out.append(r)
        if not r['axe_present']:
            print(f'{r["game"]}: no Axe')
            continue
        with_axe += 1
        tot_casts += r['n_casts']
        print(f'\n{r["game"]}  axe_team={r["axe_team"]}  casts={r["n_casts"]}  '
              f'tp_channels={r["n_tp_channels"]}  deaths={r["n_deaths"]}  '
              f'game-wide steps>{int(a.max_blink)}: {len(r["big_steps"])}')
        for c in r['casts']:
            bad = (c['picked_impossible_for_blink'] or c['tp_channel_overlap']
                   or c['death_in_window'])
            tot_contam += 1 if bad else 0
            pk = c['picked']
            ru = c['runner_up']
            print(f'  t={c["t"]:7.1f} snaps={c["n_snapshots"]} '
                  f'picked={pk["step"] if pk else None:>6} '
                  f'({pk["t0"] if pk else "-"}->{pk["t1"] if pk else "-"}) '
                  f'runner_up={ru["step"] if ru else "-":>5} '
                  f'steps>=250={c["n_steps_over_min_jump"]} '
                  f'{"** CONTAMINATED" if bad else "clean"}')
            if c['tp_channel_overlap']:
                print(f'      tp_channel_overlap={c["tp_channel_overlap"]}')
            if c['death_in_window']:
                print(f'      death_in_window={c["death_in_window"]}')
        if r['closest_big_step_to_a_cast_window_s'] is not None:
            print(f'  closest impossible step to any cast window: '
                  f'{r["closest_big_step_to_a_cast_window_s"]}s '
                  f'(step {r["closest_big_step"]["step"]} at '
                  f'{r["closest_big_step"]["t0"]}->{r["closest_big_step"]["t1"]}, '
                  f'cast t={r["closest_big_step_cast_t"]})')

    print(f'\n=== {with_axe} games with Axe / {len(paths)} swept; '
          f'{tot_casts} blink casts; {tot_contam} contaminated windows ===')
    if a.json:
        json.dump(out, open(a.json, 'w'), indent=1)


if __name__ == '__main__':
    main()

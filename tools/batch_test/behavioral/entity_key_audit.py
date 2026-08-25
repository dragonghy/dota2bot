#!/usr/bin/env python3
"""How exposed is a detector to GH #176's two contaminants?  MEASURED, per file.

WHY THIS EXISTS (replay-check 2026-08-25T21:xxZ, GH #176 acceptance item 3)
---------------------------------------------------------------------------
GH #176 §3 NAMES roughly fifteen detectors that read `hp_pct` as aliveness and
says, in as many words, "命中不等于读数已经错 -- 逐个判读,别一刀切改".  Two
rounds of this charter have carried "推广 entities.py 到其余检测器" as a
priority and both times it stayed a to-do, because the honest version of that
job is not a sed script: it is a measurement per detector of whether the
contamination can reach the number the detector reports.

This tool measures the two contaminants where a detector actually consumes
them, on real corpus:

  (Q1) KEYING.  How many snapshot streams share a hero NAME, and does the
       reader's rule pick the same entity `entities.frames_by_hero` picks?
       Three rules are compared on the same timeline:
         naive      -- key by name, all streams concatenated (the bug)
         earliest   -- `pullcamp_domain.Game`: lowest first-sample t per name
         pre-horn   -- `entities.frames_by_hero`: drop any stream first sampled
                       after the horn; on a pre-horn tie keep the longer-lived
       A DIVERGENCE between the last two is a real fork in what gets measured;
       agreement is the result that lets a detector be declared out of reach.

  (Q2) CORPSE LEAK.  `entities.alive_at` is the authority (a resurrection is
       two consecutive positive-hp samples, never a time window -- charter
       2026-08-25, measured leak 0.40 s).  A sample with hp_pct > 0 that
       `alive_at` calls dead is a LEAK FRAME: exactly what an exact-frame
       `hp_pct > 0` filter passes through as a live enemy.

  (Q3) DOES IT MOVE THE NUMBER.  For `pullcamp_domain` -- whose `R_SAFE`
       enemy ring is the widest cross-entity read in the pull family, and
       which the P1 `pulldrag` (a) reading of 2026-08-25T19:18Z is built on --
       run `scan_game` twice on the same games, once as shipped and once with
       leak frames removed from `by_t`, and diff the rows.  A counterfactual,
       not an argument.

DIRECTION OF THE ERROR, stated before the numbers.  In `pullcamp_domain` a
leak frame can only ADD an enemy to the `R_SAFE` ring, and an enemy in that
ring VETOES the domain frame (`IsLanePullSafe`).  So the contamination here
SHRINKS the domain -- it can only manufacture SILENT, never WORKING.  Any
frame the counterfactual recovers is a frame the engine's predicate would have
allowed (a dead hero is not a visible enemy hero) and the detector dropped.

WHAT THIS TOOL DOES NOT DO.  It does not edit any detector.  It reports where
the exposure is, so the fix lands where a number actually moves.
"""
import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import entities                                            # noqa: E402
from pullcamp_domain import (Game, load_sweep, derive_camps,  # noqa: E402
                             scan_game)


# ---- Q1: keying -----------------------------------------------------
def streams_by_name(timeline):
    """{canon name: {idx: [snaps sorted by t]}} -- no filtering at all."""
    out = collections.defaultdict(lambda: collections.defaultdict(list))
    for s in timeline['snapshots']:
        out[entities.canon(s['hero'])][s['idx']].append(s)
    for name in out:
        for idx in out[name]:
            out[name][idx].sort(key=lambda s: s['t'])
    return out


def keying_report(timeline):
    """Compare the three keying rules on one timeline.

    `earliest` reproduces `pullcamp_domain.Game`'s rule from the same input
    rather than importing it, because `Game` keys on the RAW hero string while
    everything else here is canonicalised -- and the charter's standing lesson
    is that two estimators written apart drift.  The selfcheck therefore pins
    `earliest` against a real `Game` built from the same synthetic timeline, so
    a drift fails a test instead of quietly changing a column.
    """
    st = streams_by_name(timeline)
    dup_names, post_horn, pre_horn_dup = [], 0, []
    earliest, prehorn = {}, {}
    for name, byidx in st.items():
        if len(byidx) > 1:
            dup_names.append(name)
        pre = [i for i, ss in byidx.items() if ss[0]['t'] <= entities.HORN_T]
        post_horn += len(byidx) - len(pre)
        if len(pre) > 1:
            pre_horn_dup.append(name)
        earliest[name] = min(byidx, key=lambda i: byidx[i][0]['t'])
        if pre:
            prehorn[name] = max(pre, key=lambda i: len(byidx[i]))
    fr, _ = entities.frames_by_hero(timeline)
    # what frames_by_hero actually kept, as an idx, so the two rules compare
    kept = {n: ss[0]['idx'] for n, ss in fr.items() if ss}
    mismatch = sorted(n for n in kept if earliest.get(n) != kept[n])
    dropped = sorted(n for n in earliest if n not in kept)
    return dict(names=len(st), dup_names=sorted(dup_names),
                post_horn_streams=post_horn,
                pre_horn_dup_names=sorted(pre_horn_dup),
                rule_mismatch=mismatch, dropped_by_prehorn=dropped)


# ---- Q2: corpse leak ------------------------------------------------
def leak_times(g, hero):
    """Sampled times where this hero is DEAD but still carries hp_pct > 0.

    `entities.alive_at` is the authority; this function only asks it.  Heroes
    with no DEATH event on record are skipped outright rather than falling back
    to the bracket rule: the bracket rule flags the last live frame before an
    unrecorded death, and counting that as a leak would inflate a census whose
    whole job is to be an upper bound on real contamination.
    """
    deaths = g.deaths.get(hero, [])
    if not deaths:
        return set()
    fr = [g.frames[hero][t] for t in sorted(g.frames[hero])]
    return {s['t'] for s in fr
            if s['hp_pct'] > 0 and not entities.alive_at(fr, deaths, s['t'])}


def strip_leaks(g):
    """Remove every leak sample from `g.by_t` (the cross-entity view).

    Returns the number of samples removed.  `g.frames` is left alone: it is the
    hero's OWN stream, and a detector reading its own actor at a decision
    instant must not have that instant deleted (`entities.py`'s standing note
    about the presser of a fatal TP).
    """
    leaks = {(h, t) for h in g.frames for t in leak_times(g, h)}
    if not leaks:
        return 0
    n = 0
    for t in list(g.by_t):
        keep = [s for s in g.by_t[t] if (s['hero'], s['t']) not in leaks]
        n += len(g.by_t[t]) - len(keep)
        g.by_t[t] = keep
    return n


def clean_timeline(tl):
    """The same timeline as `entities.py` would have a detector see.

    Nothing is monkeypatched: the detector under audit is handed a cleaned
    INPUT and its own code decides again.  That keeps the diff attributable to
    the data rather than to a patched predicate, and it means the audit stays
    correct when the detector changes.
    """
    fr, _ = entities.frames_by_hero(tl)
    keep_idx = {ss[0]['idx'] for ss in fr.values() if ss}
    deaths = entities.death_times(tl)
    drop = set()
    for name, ss in fr.items():
        ds = deaths.get(name, [])
        if not ds:
            continue
        for s in ss:
            if s['hp_pct'] > 0 and not entities.alive_at(ss, ds, s['t']):
                drop.add((s['idx'], s['t']))
    new = [s for s in tl['snapshots']
           if s['idx'] in keep_idx and (s['idx'], s['t']) not in drop]
    out = dict(tl)
    out['snapshots'] = new
    return out, len(tl['snapshots']) - len(new)


# ---- selfcheck ------------------------------------------------------
def _tl(snaps, events=(), teams=None):
    # `Game` truncates snapshots at the LAST EVENT (`t_end`), so a synthetic
    # timeline whose last event is the death under test would silently drop
    # every frame after it -- including the leak frame this file exists to
    # find.  The sentinel keeps the fixture honest; it is inert to every
    # branch `Game` takes (no type it reads, no inflictor).
    return dict(game=dict(teams=teams or {}), snapshots=list(snaps),
                events=list(events) + [dict(type='TICK', t=1e6)],
                creeps=[], buildings=[])


def _snap(hero, idx, t, hp=1.0, x=0.0, y=0.0, team=2, lvl=1):
    return dict(hero=hero, idx=idx, t=t, hp_pct=hp, x=x, y=y, team=team,
                level=lvl, player_id=0)


def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-42s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    import tempfile

    def game_from(snaps, events, teams):
        d = tempfile.mkdtemp()
        p = os.path.join(d, 'g.timeline.json')
        json.dump(_tl(snaps, events, teams), open(p, 'w'))
        return Game(p, None, 'radiant')

    H = 'npc_dota_hero_lina'
    teams = {H: 2}

    # --- leak census: the shape GH #176 §2 and the 0.40 s measurement pin
    snaps = ([_snap(H, 1, t) for t in (-2.0, 0.0, 1.0, 2.0)]
             + [_snap(H, 1, 3.0, hp=0.08)]           # the leak frame
             + [_snap(H, 1, t, hp=0.0) for t in (4.0, 5.0, 6.0)])
    ev = [dict(type='DEATH', t=2.6, target=H, target_hero=True)]
    g = game_from(snaps, ev, teams)
    lk = leak_times(g, H)
    chk('leak-frame-flagged', lk == {3.0}, sorted(lk))
    chk('pre-death-frames-not-flagged', not (lk & {-2.0, 0.0, 1.0, 2.0}))

    # a resurrection is TWO consecutive positive samples -- and it must hold
    # for Wraith King, who comes back IN PLACE (charter 2026-08-21), so this
    # case deliberately keeps x/y frozen across the death.
    snaps2 = (snaps[:5]
              + [_snap(H, 1, 4.0, hp=0.0)]
              + [_snap(H, 1, t, hp=1.0) for t in (5.0, 6.0, 7.0)])
    g2 = game_from(snaps2, ev, teams)
    lk2 = leak_times(g2, H)
    chk('wk-in-place-resurrection-not-a-leak', lk2 == {3.0}, sorted(lk2))
    chk('resurrected-frames-not-flagged', not (lk2 & {5.0, 6.0, 7.0}))

    # no death on record -> no leak claimed (upper-bound discipline)
    g3 = game_from(snaps, [], teams)
    chk('no-death-event-no-leak', leak_times(g3, H) == set())

    # --- by_t stripping: the cross-entity view loses the corpse, the hero's
    # own stream does not (entities.py's presser rule)
    g4 = game_from(snaps, ev, teams)
    before = sum(len(v) for v in g4.by_t.values())
    n = strip_leaks(g4)
    after = sum(len(v) for v in g4.by_t.values())
    chk('by_t-leak-removed', n == 1 and before - after == 1, 'n=%d' % n)
    chk('own-stream-frames-kept', 3.0 in g4.frames[H])
    chk('strip-is-idempotent', strip_leaks(g4) == 0)

    # --- keying: an illusion is a post-horn stream under the same name
    ill = ([_snap(H, 1, t) for t in (-2.0, 0.0, 1.0, 2.0, 3.0)]
           + [_snap(H, 7, t, x=500.0) for t in (2.0, 3.0)])
    rep = keying_report(_tl(ill, teams=teams))
    chk('illusion-counted-as-dup', rep['dup_names'] == ['lina']
        and rep['post_horn_streams'] == 1, rep['post_horn_streams'])
    chk('illusion-not-a-rule-mismatch', rep['rule_mismatch'] == []
        and rep['dropped_by_prehorn'] == [])
    g5 = game_from(ill, [], teams)
    chk('pullcamp-drops-the-illusion-too', g5.copies == 1
        and all(s['idx'] == 1 for v in g5.by_t.values() for s in v),
        'copies=%d' % g5.copies)

    # --- the case where the two rules genuinely fork: TWO pre-horn streams,
    # the earlier one short.  `earliest` keeps the short one, `pre-horn` keeps
    # the long one.  This is the assertion that makes the mismatch column mean
    # something -- without it the column could be structurally empty and the
    # tool would still print zeros.
    fork = ([_snap(H, 4, -3.0), _snap(H, 4, -2.0)]
            + [_snap(H, 9, t) for t in (-1.0, 0.0, 1.0, 2.0, 3.0)])
    rep2 = keying_report(_tl(fork, teams=teams))
    chk('pre-horn-fork-is-reported', rep2['rule_mismatch'] == ['lina']
        and rep2['pre_horn_dup_names'] == ['lina'], rep2['rule_mismatch'])
    g6 = game_from(fork, [], teams)
    kept_idx = {s['idx'] for v in g6.by_t.values() for s in v}
    chk('mismatch-column-tracks-real-Game', kept_idx == {4}, kept_idx)

    # --- clean_timeline: the illusion goes, the hero stays, the corpse's leak
    # frame goes.  Without this the --tpdefend diff could read zero simply
    # because the cleaner never removed anything (the `selfskip-trap` shape:
    # a counterfactual that cannot move is not evidence that nothing moved).
    mixed = (snaps                                   # hero + death + leak
             + [_snap(H, 7, t, x=500.0) for t in (1.0, 2.0, 3.0)])   # illusion
    ctl, nrem = clean_timeline(_tl(mixed, ev, teams))
    kept_idx = {s['idx'] for s in ctl['snapshots']}
    chk('clean-drops-illusion-and-leak', kept_idx == {1} and nrem == 4,
        'removed=%d kept=%s' % (nrem, kept_idx))
    chk('clean-keeps-live-hero-frames',
        sum(1 for s in ctl['snapshots'] if s['hp_pct'] > 0) == 4)

    # --- a hero first sampled AFTER the horn is DROPPED by entities.py.  If a
    # whole game were sampled late, `frames_by_hero` would return nothing --
    # that is a silent-zero risk for every importer, so the audit reports it.
    late = [_snap(H, 1, t) for t in (5.0, 6.0, 7.0)]
    rep3 = keying_report(_tl(late, teams=teams))
    chk('late-sampled-hero-reported-as-dropped',
        rep3['dropped_by_prehorn'] == ['lina'], rep3['dropped_by_prehorn'])

    return ok


# ---- main -----------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--counterfactual', action='store_true',
                    help='re-run pullcamp_domain.scan_game with leaks stripped')
    ap.add_argument('--tpdefend', action='store_true',
                    help='re-run tpdefend_events.events_for_game on a cleaned '
                         'timeline and diff the rows (that detector is '
                         'name-keyed, GH #176 §1, and its domain is the whole '
                         'game -- i.e. squarely inside the illusion era)')
    ap.add_argument('--out', default='/tmp/entity_key_audit.jsonl')
    a = ap.parse_args()

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck():
            sys.exit(2)
        print('selfcheck OK')
        if not a.sweeps:
            return

    games = []
    for d in a.sweeps:
        for m in load_sweep(d):
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            m['_dir'] = d
            games.append((tl, an, m))
    print('corpus: %d games from %d sweep dir(s)' % (len(games), len(a.sweeps)))

    tot = collections.Counter()
    dup_games, mismatch_games, dropped_games = [], [], []
    leak_rows = []
    cf_rows = []
    tpd_rows = []
    camps = None
    if a.counterfactual:
        # camps need a pooled derivation; load a warm subset only (a 100-game
        # corpus of cap=25 timelines does not fit in memory at once -- charter
        # 2026-08-25, exit 137).
        warm = []
        for tl, an, m in games[:10]:
            warm.append((Game(tl, an, m['side']), m['game'], m['seed'], ''))
        camps = derive_camps(warm)
        print('camps derived from a 10-game warm subset: %d' % len(camps))
        del warm

    for tl, an, m in games:
        d = json.load(open(tl))
        rep = keying_report(d)
        tot['games'] += 1
        tot['post_horn_streams'] += rep['post_horn_streams']
        if rep['dup_names']:
            tot['games_with_dup'] += 1
            dup_games.append((m['game'], rep['dup_names']))
        if rep['rule_mismatch']:
            mismatch_games.append((m['game'], rep['rule_mismatch']))
        if rep['dropped_by_prehorn']:
            dropped_games.append((m['game'], rep['dropped_by_prehorn']))
        del d

        g = Game(tl, an, m['side'])
        n_leak = 0
        for h in g.frames:
            lt = leak_times(g, h)
            n_leak += len(lt)
            for t in sorted(lt):
                leak_rows.append(dict(game=m['game'], hero=h, t=t,
                                      hp=g.frames[h][t]['hp_pct'],
                                      leg=g.leg(h)))
        tot['leak_samples'] += n_leak
        tot['deaths'] += sum(len(v) for v in g.deaths.values())

        if a.tpdefend:
            import tpdefend_events as tde
            tl_raw = json.load(open(tl))
            pos = tde.positions_for(m['_dir'], m['game'])
            base = tde.events_for_game(tl_raw, m['game'], pos)
            tl_clean, nrem = clean_timeline(tl_raw)
            fixed = tde.events_for_game(tl_clean, m['game'], pos)
            tot['tpd_removed_samples'] += nrem
            tot['tpd_base_rows'] += len(base)
            tot['tpd_fixed_rows'] += len(fixed)
            bk = {(r['hero'], r['t']): r for r in base}
            fk = {(r['hero'], r['t']): r for r in fixed}
            tot['tpd_only_base'] += len(set(bk) - set(fk))
            tot['tpd_only_fixed'] += len(set(fk) - set(bk))
            for k in set(bk) & set(fk):
                for col in ('answered', 'n_enemy', 'n_ally', 'helper_shaped',
                            'sup_available', 'died_or_no_landing'):
                    if bk[k].get(col) != fk[k].get(col):
                        tot['tpd_flip_' + col] += 1
                        tpd_rows.append(dict(game=m['game'], hero=k[0], t=k[1],
                                             col=col, base=bk[k].get(col),
                                             fixed=fk[k].get(col)))
            for k in sorted(set(bk) ^ set(fk)):
                tpd_rows.append(dict(game=m['game'], hero=k[0], t=k[1],
                                     col='row', base=k in bk, fixed=k in fk))
            del tl_raw, tl_clean

        if a.counterfactual:
            base = scan_game(g, m['game'], m['seed'], camps, sweep=m['game'])
            strip_leaks(g)
            fixed = scan_game(g, m['game'], m['seed'], camps, sweep=m['game'])
            bk = {(r['hero'], r['t']) for r in base}
            fk = {(r['hero'], r['t']) for r in fixed}
            for k in sorted(fk - bk):
                row = next(r for r in fixed if (r['hero'], r['t']) == k)
                cf_rows.append(dict(game=m['game'], hero=k[0], t=k[1],
                                    leg=row['leg'], poke=row['poke'],
                                    drag=row['drag'], at_camp=row['at_camp']))
            tot['cf_base_rows'] += len(base)
            tot['cf_fixed_rows'] += len(fixed)
            tot['cf_recovered'] += len(fk - bk)
            tot['cf_lost'] += len(bk - fk)
        del g

    print('\n=== Q1 keying ===')
    print('games                          : %d' % tot['games'])
    print('games with a duplicate name    : %d (%.1f%%)'
          % (tot['games_with_dup'],
             100.0 * tot['games_with_dup'] / max(tot['games'], 1)))
    print('post-horn (illusion) streams   : %d' % tot['post_horn_streams'])
    print('earliest-vs-prehorn mismatches : %d game(s)' % len(mismatch_games))
    for name, hs in mismatch_games[:10]:
        print('    %-28s %s' % (name, hs))
    print('heroes DROPPED by the pre-horn rule: %d game(s)' % len(dropped_games))
    for name, hs in dropped_games[:10]:
        print('    %-28s %s' % (name, hs))

    print('\n=== Q2 corpse leak ===')
    print('death events                   : %d' % tot['deaths'])
    print('leak samples (dead, hp>0)      : %d  (%.2f per death)'
          % (tot['leak_samples'],
             tot['leak_samples'] / max(tot['deaths'], 1)))

    if a.tpdefend:
        print('\n=== Q3b tpdefend_events counterfactual (name-keyed reader) ===')
        print('samples removed by the cleaner : %d' % tot['tpd_removed_samples'])
        print('rows as shipped / cleaned      : %d / %d'
              % (tot['tpd_base_rows'], tot['tpd_fixed_rows']))
        print('rows only in shipped / cleaned : %d / %d'
              % (tot['tpd_only_base'], tot['tpd_only_fixed']))
        for k in sorted(tot):
            if k.startswith('tpd_flip_'):
                print('column flips %-18s: %d' % (k[len('tpd_flip_'):], tot[k]))
        for r in tpd_rows[:20]:
            print('    %-28s %-16s t=%-8s %-18s %s -> %s'
                  % (r['game'], r['hero'], r['t'], r['col'], r['base'], r['fixed']))

    if a.counterfactual:
        print('\n=== Q3 pullcamp_domain counterfactual ===')
        print('domain rows as shipped         : %d' % tot['cf_base_rows'])
        print('domain rows with leaks stripped: %d' % tot['cf_fixed_rows'])
        print('rows RECOVERED (leak vetoed)   : %d' % tot['cf_recovered'])
        print('rows LOST                      : %d  (must be 0: stripping a '
              'corpse can only remove a veto)' % tot['cf_lost'])
        legs = collections.Counter(r['leg'] for r in cf_rows)
        print('recovered by leg               : %s' % dict(legs))
        for r in cf_rows[:20]:
            print('    %-28s %-16s t=%-7s leg=%-8s poke=%s drag=%s'
                  % (r['game'], r['hero'], r['t'], r['leg'], r['poke'],
                     r['drag']))

    with open(a.out, 'w') as f:
        for r in leak_rows:
            f.write(json.dumps(dict(kind='leak', **r)) + '\n')
        for r in cf_rows:
            f.write(json.dumps(dict(kind='recovered', **r)) + '\n')
        for r in tpd_rows:
            f.write(json.dumps(dict(kind='tpdefend', **r)) + '\n')
    print('\nrows -> %s' % a.out)


if __name__ == '__main__':
    main()

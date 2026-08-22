#!/usr/bin/env python3
"""Trace the `TL.at()` same-name-entity artifact THROUGH `tp_attribution.scan`.

Why this exists
---------------
2026-08-22T04:05Z (replay-check) measured the artifact at the PRIMITIVE level:
`TL.at()` merges every entity that shares a hero name and returns "the last
snapshot with t <= t", so on a corpus with illusions/copies 2.80% of calls
(3,399 / 121,268) return a NON-BODY entity, median position error 3,087 u, and
on the `alive()` gate it turns a living body into a corpse 2,716 times against
19 in the other direction (~143:1, sign FIXED, unlike `#78`'s sampling-grid
leak which is one frame wide and unsigned).

That round stopped at the primitive and said so explicitly ("only measured the
primitive, did not trace which predicate it reaches inside `scan` => does not
claim `#96`'s 4/16 background rate is overturned or biased").  This script is
that missing step, and it matters because `lf_rescue_null_channel.py` -- the
tool carrying `#96`'s registered four-cell table -- calls `TA.scan` directly.

Method
------
Build BOTH worlds from one timeline: the legacy merged-by-name snapshot map and
an idx-locked one (`primary_idx`, EARLIEST-first-appearance, the discriminator
the charter mandates), then run the SAME `scan` twice and diff:

  1. per-CALL-SITE divergence, keyed on the caller's line number in
     `tp_attribution.py`, so "which predicate does it reach" is answered by
     measurement and not by reading the source.  For each site we count calls,
     how many returned a different snapshot, how many of those flipped the
     `alive()` verdict, and in which direction (false-corpse vs false-body).
  2. the downstream verdicts that are actually quoted: pass-A `cast_hits`,
     landing-`attributed(thr)`, and pass-B opportunity episodes -- per game,
     per leg, and pooled into `#96`'s four cells.

A divergence that reaches no verdict is a latent hazard, not an error in the
published numbers; the two are reported separately and never merged.

Usage:
    tp_attribution_idxlock_audit.py --arm-a <sweep_dir> [...] --arm-b <sweep_dir> [...]
    tp_attribution_idxlock_audit.py ... --threshold 1500
    tp_attribution_idxlock_audit.py ... --selfcheck

Guards (all abort BEFORE any number is printed):
  * arm guard -- the cand-id set difference A-B must be exactly {'lf_rescue'}
    and B-A empty, read from each game's own mirror stamp;
  * completeness guard -- a sweep dir without `sweep_summary.md` (the de-facto
    finish sentinel, `[harness] #102`) is refused, and its `games swept:` count
    must equal the manifest line count;
  * `--selfcheck` re-derives the legacy cells and compares them against `#96`'s
    registered readings, exit 2 on drift.

Read-only.  No AWS, no billable resource, no bot Lua touched.
"""
import argparse
import collections
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tp_attribution as TA  # noqa: E402  -- the scanner under audit, shared on purpose

OTHER = {'radiant': 'dire', 'dire': 'radiant'}

# #96's registered legacy readings on this exact corpus (16 vs 16, seeds
# 859-862).  ONLY the attributed cell is a usable anchor, and only at the
# registered threshold (1000 u, `lf_rescue_null_channel.ATTRIB_U`): on a fresh
# re-sweep of the same 8 S3 prefixes the cast cell reads 27, and it reads 27 in
# `lf_rescue_null_channel.py` ITSELF as well -- so the 26 in #96's prose is a
# drift of the report, not of this audit.  Hence the real positive control is
# cross-tool (control 1 below), with the prose number kept only as a soft note.
REGISTERED = {'A_armed_casts': 26, 'A_armed_attrib': 16, 'threshold': 1000}


# --------------------------------------------------------------------------
# identity
# --------------------------------------------------------------------------
# `primary_idx` now lives in tp_attribution itself (landed 2026-08-22 off the
# back of this audit); re-exported here so the older call sites keep working and
# so there is exactly ONE implementation of the identity rule.
primary_idx = TA.primary_idx


# --------------------------------------------------------------------------
# the two-world TL: same object serves both modes, so `scan` is untouched
# --------------------------------------------------------------------------
STATS = collections.defaultdict(lambda: dict(calls=0, differ=0,
                                             alive_flip_to_dead=0,
                                             alive_flip_to_alive=0,
                                             none_flip=0, posdiff=[]))
MODE = 'legacy'          # 'legacy' | 'locked'
AUDIT = False            # when True, every at() consults both worlds


class DualTL(TA.TL):
    """TA.TL plus an idx-locked snapshot map; `at()` answers per MODE."""

    def __init__(self, path):
        # Build the LEGACY (merged-by-name) world through TA itself with the
        # lock off, then the locked world with it on -- so neither map is a
        # second implementation of TA.TL.__init__.
        lock, TA.IDX_LOCK = TA.IDX_LOCK, False
        try:
            # super(), not TA.TL.__init__: `run()` rebinds TA.TL to this class
            # so that scan() builds it, and a name-based call would recurse.
            super(DualTL, self).__init__(path)      # -> self.snaps = merged
        finally:
            TA.IDX_LOCK = lock
        d = json.load(open(path))
        snaps = d['snapshots']
        if snaps and 'idx' not in snaps[0]:
            sys.exit('[fatal] this dumper build has no snapshots[].idx -- the '
                     'audit cannot distinguish body from copy; rebuild the dumper')
        prim = primary_idx(snaps)
        self.snaps_locked = collections.defaultdict(list)
        for s in snaps:
            if prim.get(s['hero']) == s['idx']:
                self.snaps_locked[s['hero']].append(s)
        for h in self.snaps_locked:
            self.snaps_locked[h].sort(key=lambda s: s['t'])
        self.n_copy_entities = len({(s['hero'], s['idx']) for s in snaps}) - len(prim)
        self.n_copy_frames = len(snaps) - sum(len(v) for v in self.snaps_locked.values())

    @staticmethod
    def _pick(arr, t, tol):
        """verbatim TA.TL.at body, parameterised on the snapshot list."""
        if not arr:
            return None
        best = None
        for s in arr:
            if s['t'] <= t + 0.01:
                best = s
            else:
                break
        if best is None or t - best['t'] > tol:
            for s in arr:
                if abs(s['t'] - t) <= tol:
                    return s
            return None
        return best

    def at(self, hero, t, tol=1.2):
        leg = self._pick(self.snaps.get(hero), t, tol)
        if not AUDIT:
            return leg if MODE == 'legacy' else self._pick(self.snaps_locked.get(hero), t, tol)
        loc = self._pick(self.snaps_locked.get(hero), t, tol)
        site = sys._getframe(1).f_lineno
        st = STATS[site]
        st['calls'] += 1
        if leg is not loc:
            if leg is None or loc is None:
                st['differ'] += 1
                st['none_flip'] += 1
            elif leg['t'] != loc['t'] or leg.get('idx') != loc.get('idx'):
                st['differ'] += 1
                st['posdiff'].append(TA.dist(leg['x'], leg['y'], loc['x'], loc['y']))
                al, ao = TA.alive(leg), TA.alive(loc)
                if al != ao:
                    st['alive_flip_to_dead' if ao else 'alive_flip_to_alive'] += 1
        return leg if MODE == 'legacy' else loc


# --------------------------------------------------------------------------
# corpus plumbing (same contracts as lf_rescue_null_channel.py)
# --------------------------------------------------------------------------
def load_manifest(d):
    """rows of a COMPLETE sweep dir; refuses a half-dead one (#102)."""
    sm = os.path.join(d, 'sweep_summary.md')
    if not os.path.exists(sm):
        sys.exit('[fatal] %s has no sweep_summary.md -- that file is written '
                 'last and is the de-facto completion sentinel (#102); a '
                 'half-dead sweep dir is indistinguishable from a good one by '
                 'its manifest alone' % d)
    rows = [json.loads(x) for x in open(os.path.join(d, 'games_manifest.jsonl'))]
    m = re.search(r'games swept:\s*(\d+)', open(sm).read())
    if m and int(m.group(1)) != len(rows):
        sys.exit('[fatal] %s: sweep_summary says %s games, manifest has %d'
                 % (d, m.group(1), len(rows)))
    return rows


def cand_set(rows):
    out = set()
    for r in rows:
        c = r.get('cand') or ''
        out |= {x for x in re.split(r'[,\s]+', c) if x and x != 'mirror'}
    return out


def arm_guard(man, dirs_a, dirs_b):
    a = set().union(*[cand_set(man[d]) for d in dirs_a])
    b = set().union(*[cand_set(man[d]) for d in dirs_b])
    if (a - b) != {'lf_rescue'} or (b - a):
        sys.exit('[fatal] arm guard: A-B=%s B-A=%s, expected {lf_rescue} / set()'
                 % (sorted(a - b), sorted(b - a)))
    print('[guard] arms OK: A-B={lf_rescue}, B-A=none, %d shared ids' % len(a & b),
          file=sys.stderr)


def attributed(hit, thr):
    if 'land_xy' not in hit or 'pred_xy' not in hit:
        return False
    return math.hypot(hit['land_xy'][0] - hit['pred_xy'][0],
                      hit['land_xy'][1] - hit['pred_xy'][1]) <= thr


def key_of(h):
    return (round(h['t'], 1), h['responder'], h['ally'])


# --------------------------------------------------------------------------
def run(dirs_a, dirs_b, thr, audit_sites):
    global MODE, AUDIT
    man = {d: load_manifest(d) for d in dirs_a + dirs_b}
    arm_guard(man, dirs_a, dirs_b)
    TA.TL = DualTL                       # scan() builds the dual object

    recs = []
    copies = dict(entities=0, frames=0, games_with=0, games=0)
    for arm, dirs in (('A', dirs_a), ('B', dirs_b)):
        for d in dirs:
            for g in man[d]:
                tl = os.path.join(d, 'timelines', g['game'] + '.timeline.json')
                aj = os.path.join(d, 'analysis', g['game'] + '.analysis.json')
                if not (os.path.exists(tl) and os.path.exists(aj)):
                    sys.exit('[fatal] missing timeline/analysis for %s' % g['game'])
                probe = DualTL(tl)
                copies['games'] += 1
                copies['entities'] += probe.n_copy_entities
                copies['frames'] += probe.n_copy_frames
                copies['games_with'] += 1 if probe.n_copy_entities else 0
                for leg, side in (('armed', g['side']), ('base', OTHER[g['side']])):
                    AUDIT = audit_sites
                    MODE = 'legacy'
                    h_leg, o_leg = TA.scan(tl, aj, side)
                    AUDIT = False
                    MODE = 'locked'
                    h_loc, o_loc = TA.scan(tl, aj, side)
                    MODE = 'legacy'
                    recs.append(dict(
                        arm=arm, leg=leg, seed=g['seed'], game=g['game'], side=side,
                        run=os.path.basename(d.rstrip('/')),
                        casts_leg=len(h_leg), casts_loc=len(h_loc),
                        att_leg=sum(1 for h in h_leg if attributed(h, thr)),
                        att_loc=sum(1 for h in h_loc if attributed(h, thr)),
                        keys_leg={key_of(h) for h in h_leg},
                        keys_loc={key_of(h) for h in h_loc},
                        opp_leg=len({(o['responder'], o['ally'], int(o['t'] // 10))
                                     for o in o_leg}),
                        opp_loc=len({(o['responder'], o['ally'], int(o['t'] // 10))
                                     for o in o_loc}),
                        copies=probe.n_copy_entities))
                    print('[scan] %s %s seed%s %-5s casts %d->%d att %d->%d opp %d->%d'
                          % (arm, g['game'], g['seed'], leg,
                             recs[-1]['casts_leg'], recs[-1]['casts_loc'],
                             recs[-1]['att_leg'], recs[-1]['att_loc'],
                             recs[-1]['opp_leg'], recs[-1]['opp_loc']), file=sys.stderr)
    return recs, copies


def cells(recs, field):
    c = collections.defaultdict(int)
    for r in recs:
        c[(r['arm'], r['leg'])] += r[field]
    return c


def report(recs, copies, thr, audit_sites):
    print('\n=== 0. corpus ===')
    print('games x legs: %d records (%d games), threshold %d u, tool: '
          'tp_attribution.scan via DualTL' % (len(recs), copies['games'], thr))
    print('same-name copies: %d extra entities over %d/%d games, %d extra frames'
          % (copies['entities'], copies['games_with'], copies['games'], copies['frames']))

    if audit_sites:
        print('\n=== 1. per-call-site divergence inside tp_attribution.py ===')
        print('%-6s %-46s %8s %8s %14s %12s %9s' %
              ('line', 'predicate the returned snapshot feeds', 'calls',
               'differ', 'LEGfalseCORPSE', 'LEGfalseBODY', 'med_pos_u'))
        for site in sorted(STATS):
            st = STATS[site]
            med = (sorted(st['posdiff'])[len(st['posdiff']) // 2]
                   if st['posdiff'] else 0)
            print('%-6d %-46s %8d %8d %14d %12d %9d'
                  % (site, site_label(site)[:46], st['calls'],
                     st['differ'], st['alive_flip_to_dead'],
                     st['alive_flip_to_alive'], med))
        tot_c = sum(s['calls'] for s in STATS.values())
        tot_d = sum(s['differ'] for s in STATS.values())
        print('TOTAL calls=%d differ=%d (%.2f%%) alive-flips: legacy-false-corpse=%d legacy-false-body=%d'
              % (tot_c, tot_d, 100.0 * tot_d / max(1, tot_c),
                 sum(s['alive_flip_to_dead'] for s in STATS.values()),
                 sum(s['alive_flip_to_alive'] for s in STATS.values())))

    print('\n=== 2. downstream verdicts: legacy -> idx-locked ===')
    for field, lab in ((('casts_leg', 'casts_loc'), 'pass-A precondition-true casts'),
                       (('att_leg', 'att_loc'), 'landing-attributed (thr=%d)' % thr),
                       (('opp_leg', 'opp_loc'), 'pass-B opportunity episodes')):
        cl, cc = cells(recs, field[0]), cells(recs, field[1])
        print('\n%s' % lab)
        print('%-12s %10s %10s %8s' % ('cell', 'legacy', 'locked', 'delta'))
        for arm in ('A', 'B'):
            for leg in ('armed', 'base'):
                a, b = cl[(arm, leg)], cc[(arm, leg)]
                print('%-12s %10d %10d %+8d' % ('%s_%s' % (arm, leg), a, b, b - a))
        armed_leg = cl[('A', 'armed')] - cl[('B', 'armed')]
        armed_loc = cc[('A', 'armed')] - cc[('B', 'armed')]
        null_leg = cl[('A', 'base')] - cl[('B', 'base')]
        null_loc = cc[('A', 'base')] - cc[('B', 'base')]
        print('ARMED A-B  %10d %10d %+8d      NULL A-B %d -> %d'
              % (armed_leg, armed_loc, armed_loc - armed_leg, null_leg, null_loc))

    print('\n=== 3. episode-identity churn (are the same casts kept?) ===')
    add = drop = 0
    ex_add, ex_drop = [], []
    for r in recs:
        for k in r['keys_loc'] - r['keys_leg']:
            add += 1
            ex_add.append((r['game'], r['leg'], k))
        for k in r['keys_leg'] - r['keys_loc']:
            drop += 1
            ex_drop.append((r['game'], r['leg'], k))
    print('casts only under the lock: %d ; only under legacy: %d' % (add, drop))
    for lab, ex in (('LOCK-ONLY', ex_add[:6]), ('LEGACY-ONLY', ex_drop[:6])):
        for g, leg, k in ex:
            print('  %-12s %s %-5s t=%.1f %s -> %s' % (lab, g, leg, k[0], k[1], k[2]))

    print('\n=== 4. games where any verdict moved ===')
    moved = [r for r in recs if r['casts_leg'] != r['casts_loc']
             or r['att_leg'] != r['att_loc'] or r['opp_leg'] != r['opp_loc']]
    print('%d / %d (game, leg) records moved' % (len(moved), len(recs)))
    for r in moved:
        print('  %s %s %-5s copies=%d casts %d->%d att %d->%d opp %d->%d'
              % (r['arm'], r['game'], r['leg'], r['copies'],
                 r['casts_leg'], r['casts_loc'], r['att_leg'], r['att_loc'],
                 r['opp_leg'], r['opp_loc']))


_SRC = None


def site_label(line):
    """The actual source line in tp_attribution.py -- never a hard-coded map.

    An earlier draft hard-coded {163: 'passA rs ...'}; landing the idx lock in
    tp_attribution.py shifted every call site by +60 lines and turned the whole
    table into '(unlabelled)'.  Reading the source at report time cannot drift.
    """
    global _SRC
    if _SRC is None:
        _SRC = open(TA.__file__).read().splitlines()
    txt = _SRC[line - 1].strip() if 0 < line <= len(_SRC) else '?'
    for back in range(line - 1, max(0, line - 12), -1):
        d = _SRC[back - 1].strip()
        if d.startswith('def '):
            return '%s | %s' % (d[4:d.index('(')], txt)
    return txt




def selfcheck(recs, thr, dirs_a, dirs_b):
    """Two controls, in order of strength.

    1. CROSS-TOOL (hard, exit 2): this audit's LEGACY mode must reproduce
       `lf_rescue_null_channel.collect` -- the tool that actually carries #96's
       table -- per (game, leg), on casts and on attributed.  That is what
       licenses reading the locked-vs-legacy delta as an effect of the lock and
       of nothing else.  It runs the other tool's own scan, so there is no
       second implementation of anything.
    2. PROSE ANCHOR (soft, printed): #96 registered 26 casts / 16 attributed on
       A_armed.  The attributed cell must reproduce at the registered
       threshold; the cast cell is reported either way, because control 1 pins
       any disagreement on the report rather than on this audit.
    """
    import lf_rescue_null_channel as LF  # noqa: E402 -- the tool under control
    global MODE, AUDIT
    MODE, AUDIT = 'legacy', False
    man = {d: load_manifest(d) for d in dirs_a + dirs_b}
    ref = LF.collect(dirs_a, dirs_b, man)
    mine = {(r['arm'], r['leg'], r['game']): r for r in recs}
    bad = []
    if len(ref) != len(recs):
        bad.append('record counts differ: %d vs %d' % (len(ref), len(recs)))
    for rr in ref:
        k = (rr['arm'], rr['leg'], rr['game'])
        if k not in mine:
            bad.append('missing record %s' % (k,))
            continue
        m = mine[k]
        if rr['casts'] != m['casts_leg']:
            bad.append('%s casts %d vs %d' % (k, rr['casts'], m['casts_leg']))
        ra = sum(1 for h in rr['hits'] if attributed(h, thr))
        if ra != m['att_leg']:
            bad.append('%s attributed %d vs %d' % (k, ra, m['att_leg']))
        if rr['opp_eps'] != m['opp_leg']:
            bad.append('%s opp_eps %d vs %d' % (k, rr['opp_eps'], m['opp_leg']))
    if len({(r['arm'], r['leg'], r['seed']) for r in recs}) != 16:
        bad.append('expected 16 (arm,leg,seed) cells, got %d'
                   % len({(r['arm'], r['leg'], r['seed']) for r in recs}))
    if bad:
        print('[selfcheck] FAIL (control 1, cross-tool): %s'
              % '; '.join(bad[:8]), file=sys.stderr)
        sys.exit(2)
    cl, ca = cells(recs, 'casts_leg'), cells(recs, 'att_leg')
    print('[selfcheck] control 1 OK: legacy mode == lf_rescue_null_channel.collect '
          'on all %d (game, leg) records (casts, attributed, opportunity episodes)'
          % len(recs), file=sys.stderr)
    note = 'reproduces' if ca[('A', 'armed')] == REGISTERED['A_armed_attrib'] else 'DRIFTS from'
    print('[selfcheck] control 2 (prose anchor, thr=%d): A_armed attributed %d %s #96\'s %d; '
          'casts %d vs #96\'s %d%s'
          % (thr, ca[('A', 'armed')], note, REGISTERED['A_armed_attrib'],
             cl[('A', 'armed')], REGISTERED['A_armed_casts'],
             ' -- control 1 pins this on the report, not on the audit'
             if cl[('A', 'armed')] != REGISTERED['A_armed_casts'] else ''),
          file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--arm-a', nargs='+', required=True)
    ap.add_argument('--arm-b', nargs='+', required=True)
    ap.add_argument('--threshold', type=int, default=1000,
                help='landing/prediction tolerance; 1000 is '
                     'lf_rescue_null_channel.ATTRIB_U, the value #96 registered')
    ap.add_argument('--no-site-audit', action='store_true',
                    help='skip the per-call-site instrumentation (faster)')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--json')
    a = ap.parse_args()
    recs, copies = run(a.arm_a, a.arm_b, a.threshold, not a.no_site_audit)
    if a.selfcheck:
        selfcheck(recs, a.threshold, a.arm_a, a.arm_b)
    report(recs, copies, a.threshold, not a.no_site_audit)
    if a.json:
        dump = [{k: (sorted(v) if isinstance(v, set) else v) for k, v in r.items()}
                for r in recs]
        json.dump(dict(records=dump, sites={str(k): {kk: (vv if kk != 'posdiff'
                                                          else len(vv))
                                                     for kk, vv in v.items()}
                                            for k, v in STATS.items()}),
                  open(a.json, 'w'), indent=1)


if __name__ == '__main__':
    main()

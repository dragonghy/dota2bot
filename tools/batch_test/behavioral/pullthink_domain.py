#!/usr/bin/env python3
"""(a)-evidence for the `pullthink` soak candidate: DOES THE DRAG STEP GO OUT?

WHAT THE CANDIDATE DOES  (one id, two inseparable halves)
---------------------------------------------------------
`bots/mode_roam_generic.lua`

  site A (:224)  `if not (bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink'))
                  and J.Utils.IsBotThinkingMeaningfulAction(...) then return end`
                 -- armed, the anim-activity throttle STOPS eating the frames on
                 which the camp-pull cadence would issue its drag order.  The
                 throttle's list opens with ACTIVITY_RUN / ACTIVITY_ATTACK, and a
                 hero mid-attack-animation on the camp it just poked is by
                 construction in ACTIVITY_ATTACK, so the frames the drag needs are
                 exactly the frames the throttle ate.

  site B (:321)  the 0.5 s wind-up hold after the poke -- issue NO order so the
                 attack that was just ordered actually starts.  Structural
                 precondition of site A, not a second lever (shipping A alone is
                 the configuration GH #143 already measured as broken).

So the candidate does not change WHETHER a camp is poked; `pullcamp` decides
that.  It changes whether the hero WALKS between pokes.  That makes the (a)
question a kinematics question, and a direction-free one:

    on a poke frame, does the hero move in the following second?

GH #186's立案读数 is the defect side of exactly that quantity: 31 of 73 armed
poke frames moved < 50 u in the following second (ab 48% / ba 39%, same sign),
with one hero standing on 6 CONSECUTIVE seconds of identical coordinates while
its HP fell 1.00 -> 0.84.

⭐ WHY armed-vs-baseline IS NOT THE CONTRAST HERE  (the thing this tool exists
   to say out loud)
------------------------------------------------------------------------------
`bot.roamCampPull` is non-nil only when `J.ShouldPullNeutralCamp` returned
non-nil, and that opens with

    if not J.IsModeTurbo() then return nil end
    if not J.IsSoakCandidate('pullcamp') then return nil end     (jmz_func.lua:8250)

`pullcamp` is itself still gated.  On the BASELINE leg of a mirrored wave no id
is armed, so `roamCampPull` is nil on every frame, site A's added conjunct is
one nil compare, site B is unreachable, and there is no camp pull to walk away
from.  The baseline leg's few poke frames are stock JUNGLING ON THE WAY HOME --
pullcamp_domain's own header records that finding and keeps it as a negative
result (measured there: baseline poke episodes 4 vs armed 59 on 139 games).

    ==> Reading `pullthink` off the armed/baseline split of ONE wave compares
        camp pulls against incidental jungling.  The two legs do not share a
        domain, so the contrast is not an effect estimate at all.  The control
        with the same domain is the ARMED LEG OF A WAVE WHERE `pullcamp` IS
        ARMED AND `pullthink` IS NOT.

That is a cross-wave control and it is weaker than a mirrored one -- different
tree, different seeds -- so it is reported as such and never as an A/B.  Both
legs of both waves are printed anyway (rule 4(i)), and the baseline columns are
printed precisely so the domain emptiness above is visible as a number rather
than asserted.

WHAT IS MEASURED
----------------
For every POKE frame `pullcamp_domain.scan_game` already finds (its domain, its
clauses, its entity discipline, its TP/death exclusion -- imported, never
re-implemented), the hero's own next two samples are read:

    v1 = |p(s1) - p(t )| / (s1 - t )      u/s over the first sample step
    v2 = |p(s2) - p(s1)| / (s2 - s1)      u/s over the second

`s1`/`s2` are the hero's next actual samples, and each step's own dt is used --
the grid is nominally 1 Hz but a step is never assumed to be 1.0 s.  A frame is
STILL when the step covers < STILL_U (50 u, GH #186's literal) scaled by that
step's dt.  Both steps are kept because the two halves of the id push v1 in
OPPOSITE directions: site B deliberately spends the first 0.5 s standing (the
wind-up hold), while site A is what makes the rest of the step move.  v2 is
past the hold in every sampling that resolves it at all, so v2 is the half of
the reading that carries site A alone.

WHAT THIS TOOL CANNOT SAY  (registered, not guessed)
----------------------------------------------------
* Site B's 0.5 s hold is NOT separately observable at 1 Hz -- a hold shorter
  than one sample step leaves no sample inside itself.  Its intended
  consequence (the poke lands) is already inside pullcamp_domain's `poke`
  predicate, which requires a hero->non-hero DAMAGE event, so a poke frame that
  reached this tool has by construction landed damage.  The tool therefore
  reports site B as UNOBSERVABLE-AT-1HZ and scores site A only.
* `GetAnimActivity()` -- the operand the throttle actually reads -- is in no
  dump.  The throttle is scored by its consequence, never by its input.

Usage:
    pullthink_domain.py --armed <sweep_dir>... --control <sweep_dir>...
    pullthink_domain.py --selfcheck          # synthetic, no corpus needed

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pullcamp_domain as PC                              # noqa: E402

CAND_ID = 'pullthink'
DEP_ID = 'pullcamp'          # jmz_func.lua:8250 -- the domain's own gate

# GH #186's立案 literal: "moving < 50 u in the following second".  Applied as a
# SPEED so an off-nominal sample step cannot silently change the threshold.
STILL_U = 50.0
STILL_V = STILL_U / 1.0      # u/s

# A sample step this long is not one grid step any more; the frames on either
# side of it are not adjacent and the reading is dropped rather than stretched.
STEP_MAX = 2.5


class Source(object):
    """The shipped facts this tool's reading rests on, read off the Lua.

    Every field here is load-bearing for the CONTROL DESIGN, not merely for a
    number: if `pullcamp` stops being gated the baseline leg acquires a domain
    and "the two legs do not share a domain" -- the whole reason this tool
    takes a cross-wave control -- becomes false with nothing raising a hand.
    Ratcheted in tests/test_detector_source_constants.py.
    """

    def __init__(self):
        self.errors = []
        root = os.path.normpath(os.path.join(
            os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'bots'))
        roam = os.path.join(root, 'mode_roam_generic.lua')
        jmz = os.path.join(root, 'FunLib', 'jmz_func.lua')
        for p in (roam, jmz):
            if not os.path.exists(p):
                self.errors.append('missing source file %s' % p)
        roam_src = open(roam).read() if os.path.exists(roam) else ''
        jmz_src = open(jmz).read() if os.path.exists(jmz) else ''

        self.sites = roam_src.count("J.IsSoakCandidate('%s')" % CAND_ID)
        if self.sites != 2:
            self.errors.append(
                'expected exactly 2 `%s` call sites in mode_roam_generic.lua, '
                'found %d -- the id moved; re-read the source before trusting '
                'any reading' % (CAND_ID, self.sites))

        # site A's domain guard, verbatim: without `bot.roamCampPull ~= nil`
        # the throttle skip is unconditional and the id stops being a camp-pull
        # lever at all.
        self.site_a_guard = "bot.roamCampPull ~= nil and J.IsSoakCandidate('%s')" \
            % CAND_ID in roam_src
        if not self.site_a_guard:
            self.errors.append(
                'site A no longer reads `bot.roamCampPull ~= nil and '
                'J.IsSoakCandidate(%r)` -- the domain guard changed' % CAND_ID)

        # the dependency the whole control design rests on
        self.dep_gated = ("J.IsSoakCandidate( '%s' )" % DEP_ID) in jmz_src
        if not self.dep_gated:
            self.errors.append(
                '`%s` is no longer gated in jmz_func.lua -- if it was PROMOTED '
                'the baseline leg HAS a camp-pull domain, and the cross-wave '
                'control this tool takes is no longer needed OR valid; re-read '
                'J.ShouldPullNeutralCamp' % DEP_ID)

        # `pullthink` must NOT be conjoined with `pullcamp` in either gate --
        # the pullcad trap (a promoted id is in no armed string, so such a
        # conjunction freezes FALSE while check_armed_wiring still says WIRED).
        self.no_conjunction = ("J.IsSoakCandidate('%s') and J.IsSoakCandidate('%s')"
                               % (CAND_ID, DEP_ID)) not in roam_src
        if not self.no_conjunction:
            self.errors.append(
                'site gate now conjoins `%s` with `%s` -- promoting `%s` would '
                'freeze it FALSE in every wave (the pullcad trap)'
                % (CAND_ID, DEP_ID, DEP_ID))


def load_source():
    return Source()


def _sites_in_source():
    s = load_source()
    if s.errors:
        raise RuntimeError('; '.join(s.errors))
    return s.sites


def step_reads(g, hero, t):
    """The hero's own next two sample steps after t.

    Returns (v1, dt1, v2, dt2, s1t, s2t) with None where a step is missing,
    unclean (TP channel / death window) or longer than STEP_MAX.
    """
    fr = g.frames.get(hero, {})
    later = sorted(x for x in fr if x > t)
    out = [None, None, None, None, None, None]
    prev_t = t
    for k in (0, 1):
        if k >= len(later):
            break
        st = later[k]
        dt = st - prev_t
        if dt <= 0 or dt > STEP_MAX:
            break
        if not g.clean_window(hero, prev_t, st):
            break
        a, b = fr[prev_t], fr[st]
        if a['hp_pct'] <= 0 or b['hp_pct'] <= 0:
            break
        d = math.hypot(b['x'] - a['x'], b['y'] - a['y'])
        out[k * 2] = d / dt
        out[k * 2 + 1] = dt
        out[4 + k] = st
        prev_t = st
    return tuple(out)


# A whole wave's Game objects do not fit in memory (337 games OOM-killed a 15 GB
# container at exit 137, silently, on the first full-corpus run).  Camps are
# derived from a WARM subset and every other game is loaded, scanned, and
# dropped -- the same discipline pulldrag_walk.py adopted for the same reason.
# The subset is safe because `derive_camps` reads the FIRST neutral spawn, which
# is map geometry: 28 camps came out of 6 games, of 71, and of 162 alike.  It is
# asserted rather than assumed below.
WARM_GAMES = 10


def _manifest(sweep_dirs, label):
    out, cands = [], set()
    for d in sweep_dirs:
        for m in PC.load_sweep(d):
            cands.add(m['cand'])
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            out.append((tl, an, m['side'], m['game'], m['seed'], d))
    if not out:
        sys.exit('[fatal] %s: no games' % label)
    if len(cands) != 1:
        sys.exit('[fatal] %s: mixed cand strings: %s' % (label, sorted(cands)))
    return out, cands.pop()


def collect(sweep_dirs, label):
    """Every poke frame in these sweeps, with its two step speeds attached."""
    man, cand = _manifest(sweep_dirs, label)

    warm = [(PC.Game(tl, an, side), name, seed, d)
            for tl, an, side, name, seed, d in man[:WARM_GAMES]]
    camps = PC.derive_camps(warm)
    if not camps:
        sys.exit('[fatal] %s: no camps derived from the warm subset' % label)

    rows = []
    for i, (tl, an, side, name, seed, d) in enumerate(man):
        g = warm[i][0] if i < len(warm) else PC.Game(tl, an, side)
        for r in PC.scan_game(g, name, seed, camps, sweep=d):
            if not r['poke'] or not r['clean']:
                continue
            v1, dt1, v2, dt2, s1t, s2t = step_reads(g, r['hero'], r['t'])
            r = dict(r)
            r.update(wave=label, v1=v1, dt1=dt1, v2=v2, dt2=dt2,
                     s1t=s1t, s2t=s2t,
                     side='radiant' if g.teams[r['hero']] == PC.RADIANT
                          else 'dire')
            rows.append(r)
        if i >= len(warm):
            del g
    # camp-count stability: re-derive from a DIFFERENT slice and require the
    # same count, so a warm subset that happened to miss a camp cannot silently
    # shrink the domain.
    if len(man) > 2 * WARM_GAMES:
        alt = [(PC.Game(tl, an, side), name, seed, d)
               for tl, an, side, name, seed, d in man[-WARM_GAMES:]]
        n_alt = len(PC.derive_camps(alt))
        if n_alt != len(camps):
            sys.exit('[fatal] %s: camp count is warm-subset dependent '
                     '(%d from the first %d games, %d from the last %d) -- the '
                     'domain would depend on load order'
                     % (label, len(camps), WARM_GAMES, n_alt, WARM_GAMES))
    return rows, cand, len(man), len(camps)


def share(rows, key):
    """(n_still, n_read, share) over the frames where `key` could be read."""
    read = [r for r in rows if r[key] is not None]
    still = [r for r in read if r[key] < STILL_V]
    return len(still), len(read), (len(still) / len(read) if read else None)


def table(rows, title):
    print('\n%s' % title)
    print('  %-9s %-8s %6s | %-18s | %-18s' %
          ('wave', 'leg', 'pokes', 'still v1 (n/N, %)', 'still v2 (n/N, %)'))
    keys = sorted({(r['wave'], r['leg'], r['side']) for r in rows})
    for wave in sorted({k[0] for k in keys}):
        for leg in ('armed', 'baseline'):
            for side in (None, 'radiant', 'dire'):
                sel = [r for r in rows if r['wave'] == wave and r['leg'] == leg
                       and (side is None or r['side'] == side)]
                if not sel:
                    continue
                a1, n1, p1 = share(sel, 'v1')
                a2, n2, p2 = share(sel, 'v2')
                tag = leg if side is None else '  %s' % side
                print('  %-9s %-8s %6d | %4d/%-4d %6s | %4d/%-4d %6s' %
                      (wave if side is None else '', tag, len(sel),
                       a1, n1, '%.1f%%' % (100 * p1) if p1 is not None else 'n/a',
                       a2, n2, '%.1f%%' % (100 * p2) if p2 is not None else 'n/a'))


def selfcheck():
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-52s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    # --- source assertions: the gate this tool scores must still be there
    src = load_source()
    chk('mode_roam_generic.lua carries 2 pullthink sites', src.sites == 2,
        '(%d)' % src.sites)
    chk("site A still guards on `bot.roamCampPull ~= nil`", src.site_a_guard)
    chk("`%s` (the domain's own gate) is still gated" % DEP_ID, src.dep_gated)
    chk('the two ids are NOT conjoined (the pullcad trap)', src.no_conjunction)
    chk('no source-assertion error on trunk', src.errors == [], repr(src.errors))

    # --- kinematics on a synthetic hero
    class FakeG:
        def __init__(self, pts, tp=(), deaths=()):
            self.frames = {'h': {t: dict(x=x, y=y, hp_pct=hp)
                                 for t, x, y, hp in pts}}
            self._tp, self._d = tp, deaths

        def clean_window(self, hero, t0, t1):
            for a, b in self._tp:
                if a <= t1 and b >= t0:
                    return False
            return not any(t0 <= d <= t1 for d in self._d)

    # a hero standing still: both steps still
    g = FakeG([(10.0, 0, 0, 1.0), (11.0, 5, 0, 1.0), (12.0, 9, 0, 1.0)])
    v1, dt1, v2, dt2, _, _ = step_reads(g, 'h', 10.0)
    chk('standing hero reads STILL on both steps',
        v1 < STILL_V and v2 < STILL_V, 'v1=%.1f v2=%.1f' % (v1, v2))

    # the shape the candidate is supposed to produce: held for the first step's
    # first half, then dragging -- v1 straddles, v2 is unambiguously moving
    g = FakeG([(10.0, 0, 0, 1.0), (11.0, 150, 0, 1.0), (12.0, 450, 0, 1.0)])
    v1, dt1, v2, dt2, _, _ = step_reads(g, 'h', 10.0)
    chk('hold-then-drag: v2 moves, and by more than v1',
        v2 >= STILL_V and v2 > v1, 'v1=%.1f v2=%.1f' % (v1, v2))

    # dt is used, never assumed: the SAME displacement over a half step is
    # twice the speed, and must be able to cross the threshold
    g = FakeG([(10.0, 0, 0, 1.0), (10.5, 40, 0, 1.0), (11.5, 40, 0, 1.0)])
    v1, dt1, _, _, _, _ = step_reads(g, 'h', 10.0)
    chk('40 u over a 0.5 s step is NOT still (dt is honoured)',
        v1 >= STILL_V and abs(dt1 - 0.5) < 1e-9, 'v1=%.1f dt1=%.2f' % (v1, dt1))

    # an over-long step is dropped, not stretched
    g = FakeG([(10.0, 0, 0, 1.0), (10.0 + STEP_MAX + 0.5, 0, 0, 1.0)])
    v1, _, _, _, _, _ = step_reads(g, 'h', 10.0)
    chk('step longer than STEP_MAX is dropped, not stretched', v1 is None)

    # a TP channel over the step voids it (the charter's own instrument rule)
    g = FakeG([(10.0, 0, 0, 1.0), (11.0, 900, 0, 1.0)], tp=[(10.2, 13.0)])
    v1, _, _, _, _, _ = step_reads(g, 'h', 10.0)
    chk('TP channel over the step voids the read', v1 is None)

    # a death inside the step voids it
    g = FakeG([(10.0, 0, 0, 1.0), (11.0, 900, 0, 1.0)], deaths=[10.4])
    v1, _, _, _, _, _ = step_reads(g, 'h', 10.0)
    chk('death inside the step voids the read', v1 is None)

    # a corpse sample voids it even without a DEATH event in range
    g = FakeG([(10.0, 0, 0, 1.0), (11.0, 900, 0, 0.0)])
    v1, _, _, _, _, _ = step_reads(g, 'h', 10.0)
    chk('hp_pct == 0 on either end voids the read', v1 is None)

    # ANTI-VACUITY: the threshold must be able to separate at all
    g = FakeG([(10.0, 0, 0, 1.0), (11.0, 49, 0, 1.0), (12.0, 400, 0, 1.0)])
    v1, _, v2, _, _, _ = step_reads(g, 'h', 10.0)
    chk('49 u/s is still and 400 u/s is not (threshold has teeth)',
        v1 < STILL_V <= v2, 'v1=%.1f v2=%.1f' % (v1, v2))

    # share() must not silently count unreadable frames as moving
    rs = [dict(v1=None), dict(v1=10.0), dict(v1=400.0)]
    a, n, p = share(rs, 'v1')
    chk('share() drops unreadable frames from BOTH numerator and denominator',
        (a, n, p) == (1, 2, 0.5), '%s/%s' % (a, n))

    print('--- %s ---' % ('all PASS' if ok else 'FAILURES'))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--armed', nargs='*', default=[],
                    help='sweep dirs of the wave where `pullthink` IS armed')
    ap.add_argument('--control', nargs='*', default=[],
                    help='sweep dirs of a wave where `pullcamp` is armed and '
                         '`pullthink` is NOT')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--out', default='/tmp/pullthink_rows.jsonl')
    ap.add_argument('--top', type=int, default=12)
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(0 if selfcheck() else 2)

    if not a.armed:
        sys.exit('[fatal] --armed is required (or --selfcheck)')

    _sites_in_source()

    rows_a, cand_a, ng_a, nc_a = collect(a.armed, 'W-armed')
    print('armed wave:   %d games, %d camps, %d clean poke frames'
          % (ng_a, nc_a, len(rows_a)))
    ids_a = cand_a.split(',')
    if CAND_ID not in ids_a:
        sys.exit('[fatal] `%s` is NOT in the armed wave\'s cand string' % CAND_ID)
    if DEP_ID not in ids_a:
        sys.exit('[fatal] `%s` (the domain\'s own gate) is NOT armed in the '
                 'armed wave -- `%s` has NO domain there and any reading below '
                 'would be of an empty gate' % (DEP_ID, CAND_ID))

    rows = list(rows_a)
    if a.control:
        rows_c, cand_c, ng_c, nc_c = collect(a.control, 'W-control')
        ids_c = cand_c.split(',')
        print('control wave: %d games, %d camps, %d clean poke frames'
              % (ng_c, nc_c, len(rows_c)))
        if CAND_ID in ids_c:
            sys.exit('[fatal] `%s` IS armed in the control wave -- that is not '
                     'a control' % CAND_ID)
        if DEP_ID not in ids_c:
            sys.exit('[fatal] `%s` is NOT armed in the control wave -- the two '
                     'waves do not share a domain and the comparison is void'
                     % DEP_ID)
        only_a = sorted(set(ids_a) - set(ids_c))
        only_c = sorted(set(ids_c) - set(ids_a))
        print('arm-string delta armed\\control: %s' % (only_a or '(none)'))
        print('arm-string delta control\\armed: %s' % (only_c or '(none)'))
        if only_a != [CAND_ID]:
            print('⚠ the two waves differ by MORE than `%s` (%d extra id(s)) -- '
                  'the cross-wave contrast is confounded by those ids and is '
                  'reported as such, never as an A/B' % (CAND_ID, len(only_a) - 1))
        rows += rows_c

    table(rows, 'still-after-poke, by wave / leg / physical side (rule 4(i))')

    print('\nsite B (the 0.5 s wind-up hold, mode_roam_generic.lua:321): '
          'UNOBSERVABLE-AT-1HZ')
    print('  a hold shorter than one sample step leaves no sample inside '
          'itself; its consequence (the poke lands damage) is already inside '
          'the `poke` predicate, so every frame counted above has landed one.')

    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    print('\nrows -> %s (%d)' % (a.out, len(rows)))

    # the deepest-still episodes, for the frame-by-frame leg
    still = [r for r in rows if r['v1'] is not None and r['v1'] < STILL_V
             and r['v2'] is not None and r['v2'] < STILL_V]
    still.sort(key=lambda r: (r['v1'] + r['v2']))
    print('\ntop %d STILL-on-both-steps poke frames (frame-by-frame candidates):'
          % a.top)
    for r in still[:a.top]:
        print('  %-9s %-8s %-22s %-18s t=%7.1f v1=%5.1f v2=%5.1f camp_d=%4d'
              % (r['wave'], r['leg'], r['game'], PC.canon(r['hero']), r['t'],
                 r['v1'], r['v2'], r['camp_d']))


if __name__ == '__main__':
    main()

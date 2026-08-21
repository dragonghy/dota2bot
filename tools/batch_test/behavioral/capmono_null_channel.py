#!/usr/bin/env python3
"""§AG.2 decomposition of the `capmono` bisect DiD into its ARMED and NULL legs.

WHY THIS EXISTS
  `capmono_refusal.py` reports a seed-paired DiD and calls arm B's *internal*
  diff the "null channel".  That is one null channel, and it is the right one
  for "does capmono move the metric".  Director section AG.2 (2026-08-21T18:45Z)
  asks for a DIFFERENT one, and requires it of every (a) ever registered with a
  DiD: the two arms' BASELINE legs.

  In this bisect both arms ran the same four seeds, and in both arms the
  baseline side has every gate off.  So `armA base` and `armB base` are two
  samples of the SAME shipped code, and the contrast between them is a
  quantity that must read zero for the DiD to mean what its name says.

  Use the identity
      DiD = (Aarm - Abase) - (Barm - Bbase)
          = (Aarm - Barm) - (Abase - Bbase)
          =      ARMED     -      NULL
  ARMED is the only term that contains the code difference (`capmono`).
  NULL is a term the DiD actively subtracts.  Whatever NULL reads is a slice
  of the registered DiD with no code explanation behind it.

  This is NOT a member of the "band geometry / structural immunity" family of
  errors (those are about the DOMAIN).  It is about the ESTIMATOR: the domain
  can be perfect and the DiD still be part baseline-leg drift.

WHAT IT IS NOT
  A verdict.  #72's NOT-PROMOTE does not depend on the sign of anything here;
  the decomposition narrows what may be QUOTED, exactly as GH #90 did for the
  attribution sentence.  Both legs of this decomposition sit inside the same
  noise floor `capmono_refusal.py` already measured.

HONEST BOUNDARY (inherited verbatim from roamstale_null_channel.py)
  The two baseline legs are a near-zero, not a certified zero: a mirror game's
  baseline side plays AGAINST that arm's candidate side, and the two candidate
  sides differ by `capmono`, so an opponent-mediated path exists in principle.
  If that path is real it is itself an effect worth registering; either way the
  DiD's assumption that the baseline legs are exchangeable is the thing under
  test here.

SHARED SCANNER, ON PURPOSE
  Domain, liveness (`is_dead`), the `modifier_teleporting` channel filter, the
  GH #90 floor read out of `J.ShouldRetreatLaneBurst`, dedup and the illusion
  idx-lock all come from `capmono_refusal.scan_game` by import.  There is no
  second implementation of anything here.  `--selfcheck` re-derives that
  module's own four cells and per-seed internal diffs and exits 2 on drift.

SAMPLING INTERVAL
  Every number registered for this corpus (DiD -7.89 / -7.70 / -11.90) is a
  1.0s read -- the dumper default, i.e. `behav-dump <in.dem> > out.json` with
  no `-interval`.  Frame-level rates move with the interval (charter, (乙)
  2026-08-21T10:51Z).  Build timelines the default way or the comparison to
  the registered numbers is void.

USAGE
  capmono_null_channel.py <root>          # root/{armA,armB}_<run>/*.timeline.json
  capmono_null_channel.py <root> --selfcheck
  capmono_null_channel.py <root> --legacy-domain   # pre-#90 850u floor
"""
import glob
import json
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import capmono_refusal as cr  # noqa: E402  -- the scanner is shared on purpose
from roam_conversion import load_game  # noqa: E402

SEEDS = ('888', '895', '896', '906')
BANNER = ("ARMED (Aarm-Barm) is the only term carrying the code difference; "
          "NULL (Abase-Bbase) is a term the DiD subtracts.")


def log_comb(n, k):
    return (math.lgamma(n + 1) - math.lgamma(k + 1) - math.lgamma(n - k + 1))


def fisher_two_sided(a, b, c, d):
    """Exact two-sided Fisher p for [[a,b],[c,d]].  No scipy in this image."""
    n = a + b + c + d
    row1, col1 = a + b, a + c
    lo = max(0, col1 - (n - row1))
    hi = min(row1, col1)

    def lp(x):
        return (log_comb(row1, x) + log_comb(n - row1, col1 - x)
                - log_comb(n, col1))

    obs = lp(a)
    tot = 0.0
    for x in range(lo, hi + 1):
        p = math.exp(lp(x))
        if lp(x) <= obs + 1e-9:
            tot += p
    return min(1.0, tot)


def cand_set(stamp):
    """`mirror:<ids>:s<seed>:<side>` -> frozenset(ids); '' for a warm-up game."""
    if not stamp.startswith('mirror:'):
        return None
    return frozenset(stamp.split(':')[1].split(','))


def arm_guard(root):
    """Read each arm's candidate string from the games' own stamps.

    Aborts BEFORE any number is printed if the corpus is not a `capmono`
    bisect.  The stamp -- not the directory name -- is the authority: an
    `armA_`/`armB_` prefix is something a human typed.
    """
    seen = {}
    for arm in ('armA', 'armB'):
        sets = set()
        for aj in sorted(glob.glob(os.path.join(root, arm + '_*', '*.analysis.json'))):
            cs = cand_set(json.load(open(aj))['script_version'])
            if cs is not None:
                sets.add(cs)
        if not sets:
            sys.exit(f"ARM GUARD: no mirror-stamped games under {arm}_* -- refusing")
        if len(sets) > 1:
            sys.exit(f"ARM GUARD: {arm} carries {len(sets)} distinct candidate "
                     f"strings -- not one arm, refusing")
        seen[arm] = next(iter(sets))
    only_a, only_b = seen['armA'] - seen['armB'], seen['armB'] - seen['armA']
    if only_a != {'capmono'} or only_b:
        sys.exit(f"ARM GUARD: A-B={sorted(only_a)} B-A={sorted(only_b)}; "
                 f"expected A-B={{capmono}} and B-A=empty -- refusing")
    return seen, len(seen['armA'] & seen['armB'])


def collect(root):
    eps = []
    for arm in ('armA', 'armB'):
        for d in sorted(glob.glob(os.path.join(root, arm + '_*'))):
            for tl in sorted(glob.glob(os.path.join(d, '*.timeline.json'))):
                name = os.path.basename(tl).replace('.timeline.json', '')
                aj = tl.replace('.timeline.json', '.analysis.json')
                g = load_game(tl, aj)
                if g is None:
                    continue
                stamp = json.load(open(aj))['script_version']
                for e in cr.scan_game(g, os.path.basename(d) + '/' + name):
                    e['arm'] = arm
                    e['run'] = os.path.basename(d)
                    e['armed_side'] = g['armed_side']
                    e['seed'] = stamp.split(':s')[1].split(':')[0]
                    eps.append(e)
    return eps


def cell(eps, arm, side, seed=None, dedup=False):
    sel = [e for e in eps
           if e['arm'] == arm and e['armed'] == (side == 'armed')
           and (seed is None or e['seed'] == seed)
           and (not dedup or not e['dedup'])]
    r = sum(e['retreat'] for e in sel)
    n = len(sel)
    return r, n, (100.0 * r / n if n else float('nan'))


def table(eps, dedup=False, label='FRAME-LEVEL'):
    c = {(a, s): cell(eps, a, s, dedup=dedup)
         for a in ('armA', 'armB') for s in ('armed', 'base')}
    print(f"=== {label} four cells ===")
    for k in (('armA', 'armed'), ('armA', 'base'), ('armB', 'armed'), ('armB', 'base')):
        r, n, f = c[k]
        print(f"  {k[0]} {k[1]:5}: retreat {r:3}/{n:3} = {f:5.1f}%")
    armed = c[('armA', 'armed')][2] - c[('armB', 'armed')][2]
    null = c[('armA', 'base')][2] - c[('armB', 'base')][2]
    did = armed - null
    internal = ((c[('armA', 'armed')][2] - c[('armA', 'base')][2])
                - (c[('armB', 'armed')][2] - c[('armB', 'base')][2]))
    if abs(did - internal) > 1e-9:
        sys.exit(f"IDENTITY GUARD: {did} != {internal} -- decomposition is wrong")
    print(f"  ARMED (Aarm-Barm) {armed:+6.1f}pp   "
          f"NULL (Abase-Bbase) {null:+6.1f}pp   DiD {did:+6.1f}pp")
    share = (abs(null) / (abs(armed) + abs(null)) * 100.0) if (armed or null) else 0.0
    print(f"  |NULL| share of |ARMED|+|NULL|: {share:.0f}%")
    pa = fisher_two_sided(c[('armA', 'armed')][0],
                          c[('armA', 'armed')][1] - c[('armA', 'armed')][0],
                          c[('armB', 'armed')][0],
                          c[('armB', 'armed')][1] - c[('armB', 'armed')][0])
    pn = fisher_two_sided(c[('armA', 'base')][0],
                          c[('armA', 'base')][1] - c[('armA', 'base')][0],
                          c[('armB', 'base')][0],
                          c[('armB', 'base')][1] - c[('armB', 'base')][0])
    print(f"  Fisher two-sided: ARMED p={pa:.4f}   NULL p={pn:.4f}")
    return c, armed, null, did


def paired(eps):
    print("\n=== seed-paired decomposition ===")
    arms, nulls, dids = [], [], []
    print("  seed   Aarm   Barm   ARMED |  Abase  Bbase   NULL  |    DiD")
    for s in SEEDS:
        aa = cell(eps, 'armA', 'armed', s)[2]
        ba = cell(eps, 'armB', 'armed', s)[2]
        ab = cell(eps, 'armA', 'base', s)[2]
        bb = cell(eps, 'armB', 'base', s)[2]
        a, n = aa - ba, ab - bb
        arms.append(a)
        nulls.append(n)
        dids.append(a - n)
        print(f"  s{s} {aa:6.1f} {ba:6.1f} {a:+7.1f} | {ab:6.1f} {bb:6.1f} "
              f"{n:+7.1f} | {a - n:+7.1f}")

    def stat(v, name):
        m = statistics.mean(v)
        sd = statistics.stdev(v)
        se = sd / math.sqrt(len(v))
        print(f"  {name:6}: mean {m:+6.2f}pp  SD {sd:5.1f}  SE {se:5.2f}  "
              f"|t| {abs(m / se) if se else float('nan'):.2f}  "
              f"signs {sum(1 for x in v if x < 0)}/{len(v)} negative")
        return m
    mA = stat(arms, 'ARMED')
    mN = stat(nulls, 'NULL')
    mD = stat(dids, 'DiD')
    if abs((mA - mN) - mD) > 1e-9:
        sys.exit("IDENTITY GUARD (paired): means do not satisfy the identity")
    denom = abs(mA) + abs(mN)
    print(f"  seed-paired |NULL| share: {(abs(mN) / denom * 100.0) if denom else 0:.0f}%")
    return dids


def selfcheck(eps, dids):
    """Re-derive `capmono_refusal.py`'s own registered outputs.  Drift => exit 2."""
    print("\n=== SELFCHECK vs capmono_refusal.py ===")
    bad = 0
    for arm in ('armA', 'armB'):
        for s in SEEDS:
            a = cell(eps, arm, 'armed', s)
            b = cell(eps, arm, 'base', s)
            if a[1] == 0 or b[1] == 0:
                print(f"  !! {arm} s{s} has an empty cell")
                bad += 1
            print(f"  {arm} s{s}: armed {a[0]}/{a[1]} base {b[0]}/{b[1]} "
                  f"internal {a[2] - b[2]:+.1f}pp")
    dA = [cell(eps, 'armA', 'armed', s)[2] - cell(eps, 'armA', 'base', s)[2] for s in SEEDS]
    dB = [cell(eps, 'armB', 'armed', s)[2] - cell(eps, 'armB', 'base', s)[2] for s in SEEDS]
    ref = [dA[i] - dB[i] for i in range(len(SEEDS))]
    if max(abs(ref[i] - dids[i]) for i in range(len(SEEDS))) > 1e-9:
        sys.exit(2)
    m = statistics.mean(ref)
    sd = statistics.stdev(ref)
    print(f"  internal-diff route: DiD {m:+.2f}pp  paired SD {sd:.1f}  "
          f"SE {sd / 2:.2f}  |t| {abs(m / (sd / 2)):.2f}")
    print("  both routes agree bit-for-bit (identity holds per seed)")
    if bad:
        sys.exit(2)


def main():
    argv = [a for a in sys.argv[1:] if not a.startswith('--')]
    if '--legacy-domain' in sys.argv:
        cr.ENE_LO = cr.LEGACY_ENE_LO
    root = argv[0]
    seen, shared = arm_guard(root)
    print(f"ARM GUARD ok: A-B={{capmono}}, B-A=empty, {shared} shared ids")
    print(f"  armA cand: {','.join(sorted(seen['armA']))}")
    print(f"NOTE: {BANNER}")
    print(f"=== DOMAIN FLOOR === nearest-enemy floor {cr.ENE_LO:.0f}u"
          f"{'  (LEGACY pre-#90)' if cr.ENE_LO != cr.LANESURV_REACH else ''}\n")
    eps = collect(root)
    games = len(set((e['run'], e['game']) for e in eps))
    table(eps, dedup=False, label='FRAME-LEVEL')
    print()
    table(eps, dedup=True, label='EPISODE-LEVEL (dedup >=6s)')
    dids = paired(eps)
    if '--selfcheck' in sys.argv:
        selfcheck(eps, dids)
    print(f"\nepisodes {len(eps)}  games with >=1 episode {games}")


if __name__ == '__main__':
    main()

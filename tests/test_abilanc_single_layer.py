#!/usr/bin/env python3
"""GH #257 -- an ABSENT layer must not be rendered as a measured flat one.

WHY THIS FILE EXISTS ALONGSIDE `abilanc_domain.py --selfcheck`
--------------------------------------------------------------
The module's own selfcheck covers the pieces (`layered`'s flag, `show`'s note,
`verdict`'s new state).  Nothing runs it: `tests/run_py_tests.sh` loops
`tests/test_*.py`, and no test in the tree invokes that selfcheck.  A check
nobody runs is the shape this repo has rejected twice (the dead S3 lifecycle
rule, test_set.md Z.4; the four `tests/*.py` with no runner that motivated
`run_py_tests.sh` itself).  So the load-bearing half is asserted here, where
the harness can see it.

WHAT IT ASSERTS, AND WHY IT DRIVES `report()` RATHER THAN `verdict()`
---------------------------------------------------------------------
The issue is not that a helper returns a wrong value -- it is that **the two
lines a human quotes** (the table's note and the `=== VERDICT` line) said a
one-layer corpus had been measured on both layers.  So the test renders the
real report and reads those two lines back, at the altitude the defect lives.

The corpus half of the acceptance criteria (`--selfcheck` aside, the issue asks
for the W17-R repro command) cannot run in a routine container: the sweep dirs
under `.sweep_out/` are generated on the farm and are not in the tree.  What is
reproduced here is the SHAPE the issue printed -- 18 radiant games, `dire`
never dealt, armed 1 < baseline 2 -- driven through the same `report()`.

THE MUTATION IS THE PRE-FIX PROGRAM
------------------------------------
`layered` is patched so the flag it now computes always comes back empty.  That
is byte-for-byte the behaviour the issue filed: same counts, same corpus, and
the note/verdict pair reverts to `one layer flat` / `WORKING-WITH-RESIDUAL`.
A control with a genuine second layer must keep reading
`WORKING-WITH-RESIDUAL`, or the fix would have bought its honesty by refusing
every reading -- which is the failure mode the `tbearly` lesson names.
"""
import contextlib
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
BEHAV = os.path.join(HERE, '..', 'tools', 'batch_test', 'behavioral')
sys.path.insert(0, os.path.abspath(BEHAV))

try:
    import abilanc_domain as AD
except Exception as exc:                                  # pragma: no cover
    print('UNCERTIFIABLE: cannot import abilanc_domain: %s' % exc)
    sys.exit(2)

from collections import Counter                           # noqa: E402

ok = True


def chk(label, cond, detail=''):
    global ok
    print('  %-70s %s %s' % (label, 'PASS' if cond else 'FAIL', detail))
    ok = ok and bool(cond)


def cast(side, leg, hero='lion', ability='lion_impale'):
    """One under-tier ABILITY->ancient cast, in the shape `scan()` emits."""
    return {'run': 'r1', 'game': 'g1', 'seed': 1, 't': 100.0, 'hero': hero,
            'ability': ability, 'target': 'npc_dota_neutral_black_dragon',
            'leg': leg, 'arm_side': side, 'lvl_lo': 8, 'lvl_hi': 8,
            'placed': 'certain_under', 'band': 'under'}


def res_of(ngames, casts):
    """A `scan()` result with only the fields `report()` reads.

    `anc_camps` is given exactly two clusters because `report()` warns when a
    real ancient does not resolve to two, and that warning is not what is
    under test here.
    """
    return {
        'casts': casts, 'ngames': ngames,
        'games': sum(ngames.values()), 'keys': sum(ngames.values()),
        'collisions': 0,
        'anc_camps': [(1000.0, 1000.0), (-1000.0, -1000.0)], 'anc_cov': 0.9,
        'norm_camps': [], 'norm_cov': 0.0,
        'exposure': Counter({('armed', 'radiant', 'under'): 40,
                             ('baseline', 'radiant', 'under'): 40}),
        'fed_exposure': Counter({('armed', 'radiant'): 20,
                                 ('baseline', 'radiant'): 20}),
        'engage': Counter({('armed', 'radiant'): 30,
                           ('baseline', 'radiant'): 30}),
        'stats': Counter({'certain_under': len(casts)}),
    }


def render(res):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        AD.report(res)
    return buf.getvalue()


def side_rows(out, side):
    """The two-layer-table rows for one arm side, across all four tables.

    Scoped deliberately: `0/0.000` on a WATCHED layer is a legitimate measured
    zero and it really does appear (the `band` split has no casts in it), so a
    whole-report substring test would answer about the wrong rows.

    The `('/' or 'ABSENT')` filter picks the four `show()` tables and leaves out
    the reverse-guard (乙) table, which is keyed by the same side name but is a
    raw event count with no per-game rate.  The count is asserted by the caller
    so a row that rendered as neither cannot slip through as "none to check".
    """
    return [l for l in out.splitlines()
            if l.startswith('  %-9s' % side)
            and ('/' in l or 'ABSENT' in l)]


# The issue's exact numbers: 18 games, all radiant; armed 1, baseline 2.
ONE_LAYER = res_of({'radiant': 18, 'dire': 0},
                   [cast('radiant', 'baseline'), cast('radiant', 'baseline'),
                    cast('radiant', 'armed')])
TWO_LAYER = res_of({'radiant': 9, 'dire': 9},
                   [cast('radiant', 'baseline'), cast('radiant', 'baseline'),
                    cast('dire', 'baseline'), cast('dire', 'baseline'),
                    cast('radiant', 'armed'), cast('dire', 'armed')])

print('--- GH #257: the W17-R shape (18 radiant games, `dire` never dealt)')
out = render(ONE_LAYER)
chk('the VERDICT line reads SINGLE-LAYER', '=== VERDICT  SINGLE-LAYER' in out)
chk('it does NOT read WORKING-WITH-RESIDUAL (the filed defect)',
    'WORKING-WITH-RESIDUAL' not in out)
chk('the DOMAIN table calls the absent layer ABSENT, with its side named',
    'LAYER ABSENT (0 games: dire)' in out)
chk('it does NOT call it flat', 'one layer flat' not in out)
DIRE_ROWS = side_rows(out, 'dire')
chk('all four two-layer tables render the `dire` row (none silently dropped)',
    len(DIRE_ROWS) == 4, str(len(DIRE_ROWS)))
chk('and none of them prints a per-game rate (`0/0.000` is what a WATCHED '
    'layer looks like)',
    DIRE_ROWS and all('/' not in l and 'ABSENT' in l for l in DIRE_ROWS))
chk('the WATCHED layer keeps its rates -- the fix did not blank both rows',
    any('/' in l for l in side_rows(out, 'radiant')))
chk('the why-line says the second layer does not exist, and still shows the '
    'counts that do',
    'second layer' in out and 'armed 1, baseline 2' in out)
chk('the row still prints the games column, so the 0 is visible too',
    'dire' in out and 'ABSENT' in out)

print('--- control: a real second layer still reads WORKING-WITH-RESIDUAL')
two = render(TWO_LAYER)
chk('a two-layer corpus is untouched by the fix',
    '=== VERDICT  WORKING-WITH-RESIDUAL' in two)
chk('and no ABSENT note appears on it', 'LAYER ABSENT' not in two)

print('--- mutation: make the flag always empty (= the pre-fix program)')
_real_layered = AD.layered


def _blind(casts, ngames, pred):
    tab = _real_layered(casts, ngames, pred)
    tab['absent'] = ()
    for side in ('radiant', 'dire'):
        tab[side]['absent'] = False
    return tab


AD.layered = _blind
try:
    mut = render(ONE_LAYER)
finally:
    AD.layered = _real_layered

chk('MUTANT reverts to WORKING-WITH-RESIDUAL -- so the assertions above are '
    'held up by the fix and not by the fixture',
    '=== VERDICT  WORKING-WITH-RESIDUAL' in mut)
chk('MUTANT reverts the note to `one layer flat`', 'one layer flat' in mut)
chk('MUTANT renders the absent layer as a measured zero on every table',
    all('0/0.000' in l for l in side_rows(mut, 'dire'))
    and len(side_rows(mut, 'dire')) == 4 and 'LAYER ABSENT' not in mut)
chk('restoring the real function restores the fixed reading',
    '=== VERDICT  SINGLE-LAYER' in render(ONE_LAYER))

print('--- the ordering the new state sits in')
chk('a one-layer corpus whose domain never occurred is still EMPTY-DOMAIN, '
    'not SINGLE-LAYER',
    AD.verdict(dict(ONE_LAYER, casts=[], exposure=Counter()))[0]
    == 'EMPTY-DOMAIN')
chk('zero games is NO-CORPUS -- EMPTY-DOMAIN would claim a scan that never ran',
    AD.verdict(dict(ONE_LAYER, ngames={'radiant': 0, 'dire': 0},
                    casts=[]))[0] == 'NO-CORPUS')

print('\n%s' % ('ALL PASS' if ok else 'FAILURES ABOVE'))
sys.exit(0 if ok else 1)

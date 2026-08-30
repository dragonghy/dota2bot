#!/usr/bin/env python3
"""Corpus-free battery for `stayfield2_whynot.py`, the `stayfield2` (a)-probe.

WHY THIS FILE EXISTS.  `tests/run_py_tests.sh` loops over `tests/test_*.py`
only, so a probe invoked solely by hand is a probe nothing in the tree runs --
the GH #243 shape.  Its sibling `stayfield_domain.py` left that state on
2026-08-30 (`tests/test_stayfield_domain.py`); this file was still in it, and
the very first W29 reading is what proved that matters.

⭐ WHAT IS ACTUALLY BEING PROTECTED: THE GATED FIFTH CLAUSE, AND THE FACT THAT
ITS LIVENESS IS A PROPERTY OF THE WAVE, NOT OF THIS TOOL.
`J.ShouldRegenNotWalkHome`'s fifth clause only exists when the wave armed
`fieldcreep` (jmz_func.lua:4890).  W25..W28 all armed it; the set retired it on
2026-08-30T10:09Z (test_set.md §CJ), so W29 -- the first 44-id wave -- does
not.  Until this change the tool evaluated that clause unconditionally on the
armed leg, with a header sentence asserting "on this corpus `fieldcreep` IS
ARMED" as a standing fact.

The bias runs TOWARD the candidate, which is why nothing raised a hand: an
extra veto on the armed leg only ever REMOVES armed trips from the
predicate-TRUE pool, and "the id had no reach" is the reading that keeps a
gate alive as untested rather than killing it.  Measured on W29 (10 games,
155 walk-home trips): 2 armed departure frames -- 3fcb3d/20260830_183121_slot1
spiritbreaker t=955.5 and 3fcb3d/20260830_184327_slot1 lion t=1194.4 -- were
charged to a clause the engine never evaluated.

⭐⭐ THE NON-CHANGE ON W29 WAS EMPIRICAL, NOT STRUCTURAL, AND THAT IS THE
WHOLE REASON THIS FILE EXISTS.  Both trips fell through to `no heal in bag`,
so the verdict (armed predicate-TRUE = 0 in both strata) survived.  That is
luck about those two bags, NOT a property of the fix: this clause sits ABOVE
`no heal in bag` in the ladder, so removing it can and eventually will promote
a trip to predicate-TRUE and move a verdict.  The sibling's W28 correction was
provably verdict-preserving (its clause is veto-only-removes on a count that
was already zero); this one is not, and a reader must not carry the sibling's
guarantee across.

⭐⭐⭐ THE INERTNESS PATHS ARE THE LOAD-BEARING ONES, AND THE WRONG DIRECTION
IS JUST AS CLEAN.  The clause must be false on the baseline leg always, and on
every leg of a wave that did not arm it.  Reverse either and the tool starts
removing BASELINE trips instead -- the same bias flipped, with identical
output shape and no error anywhere.

Corpus-half note: the subject's `--selfcheck` needs sweep dirs, which CI does
not have.  This file therefore runs the PURE half only and says so in those
words -- a reader who sees no corpus lines must conclude they were not run,
never that the corpus was clean (铁律 10's SKIP/UNCERTIFIABLE wording).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BEHAV = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral')
TOOL = os.path.join(BEHAV, 'stayfield2_whynot.py')

fails = []


def ok(name, cond, why=''):
    print('%-66s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(TOOL):
    print('could not read %s' % TOOL)
    sys.exit(2)

sys.path.insert(0, BEHAV)
try:
    import stayfield2_whynot as W                              # noqa: E402
    import stayfield_domain as SD                              # noqa: E402
except Exception as exc:                                       # pragma: no cover
    print('could not import stayfield2_whynot: %s' % exc)
    sys.exit(2)

print('corpus checks SKIPPED, not passed '
      '(--selfcheck needs sweep dirs; CI has none)')


class FakeG(object):
    """Minimal Game stand-in: nobody near, nothing hitting, no tower.

    Deliberately the same shape as the subject's own in-selfcheck stand-in --
    a divergent stub here would test a predicate the tool does not run.
    """

    interval = 1.0

    def __init__(self, enemies=False, dmg=False, tower=False):
        self._e, self._d, self._t = enemies, dmg, tower
        self.deaths = {}

    def enemies_within(self, hero, s, radius):
        return [('x', 100.0)] if self._e else []

    def attributed_danger(self, hero, s):
        return self._d

    def enemy_tower_within(self, s, radius):
        return self._t


def frame(hp, items):
    return {'t': 100.0, 'hp_pct': hp, 'x': 0.0, 'y': 0.0, 'team': 2,
            'items': list(items) + [None] * (6 - len(items))}


# A frame that clears clauses 1-4 and carries a heal: predicate TRUE unless the
# gated clause fires.  Every check below moves exactly one thing off this base.
BASE = frame(0.40, ['flask'])

# ---------------------------------------------------------------------------
# the gated clause is inert wherever IsSoakCandidate('fieldcreep') is false
# ---------------------------------------------------------------------------
ok('predicate is TRUE on the base frame when the clause is not evaluated',
   W.first_failing_clause(FakeG(), 'h', BASE, creep_hits=None) is None)
ok('inert for creep_hits=None (wave did not arm it / baseline leg)',
   W.first_failing_clause(FakeG(), 'h', BASE, creep_hits=None)
   != 'fieldcreep (armed leg)')
ok('inert for creep_hits=False (armed leg, no qualifying hit)',
   W.first_failing_clause(FakeG(), 'h', BASE, creep_hits=False)
   != 'fieldcreep (armed leg)')
ok('creep_hits defaults to off when the argument is omitted',
   W.first_failing_clause(FakeG(), 'h', BASE) is None)
ok('the clause DOES fire when it is live and a hit landed',
   W.first_failing_clause(FakeG(), 'h', BASE, creep_hits=True)
   == 'fieldcreep (armed leg)')

# ---------------------------------------------------------------------------
# ladder ORDER.  The clause sits above `no heal in bag` and below the tower --
# which is precisely why removing it can PROMOTE a trip to predicate-TRUE and
# move a verdict.  A reordering here silently changes what a zero means.
# ---------------------------------------------------------------------------
ok('a tower still outranks the gated clause',
   W.first_failing_clause(FakeG(tower=True), 'h', BASE, creep_hits=True)
   == 'enemy tower 1200')
ok('the gated clause outranks `no heal in bag`',
   W.first_failing_clause(FakeG(), 'h', frame(0.40, []), creep_hits=True)
   == 'fieldcreep (armed leg)')
ok('without the clause that same frame falls through to `no heal in bag`',
   W.first_failing_clause(FakeG(), 'h', frame(0.40, []), creep_hits=None)
   == 'no heal in bag')
# ⭐ the verdict-moving case the W29 corpus happened not to contain
ok('removing the clause CAN promote a trip to predicate-TRUE',
   W.first_failing_clause(FakeG(), 'h', BASE, creep_hits=True) is not None
   and W.first_failing_clause(FakeG(), 'h', BASE, creep_hits=None) is None)
ok('hp band still outranks everything (clause 1 first)',
   W.first_failing_clause(FakeG(), 'h', frame(0.90, []), creep_hits=True)
   == 'hp>0.55')
ok('every clause name the ladder can return is declared in CLAUSES',
   all(W.first_failing_clause(g, 'h', f, creep_hits=c) in W.CLAUSES
       or W.first_failing_clause(g, 'h', f, creep_hits=c) is None
       for g in (FakeG(), FakeG(tower=True))
       for f in (BASE, frame(0.90, []), frame(0.10, []), frame(0.40, []))
       for c in (None, False, True)))

# ---------------------------------------------------------------------------
# the id is IMPORTED, never re-spelled.  A local literal drifts from the
# sibling the day one of them is renamed, and both tools keep running.
# ---------------------------------------------------------------------------
ok('FIELDCREEP_ID is the sibling module\'s object, not a copy',
   W.FIELDCREEP_ID is SD.FIELDCREEP_ID, repr(W.FIELDCREEP_ID))
ok('CAND_ID is this tool\'s own id', W.CAND_ID == 'stayfield2')

# ---------------------------------------------------------------------------
# source pins.  The subject cannot be run corpus-free, and the failures these
# guard against -- deleting the disclosure, dropping the arm-string guard,
# hardcoding the damage index again -- all leave a tool that runs fine and
# prints something that reads exactly like a clean report.
# ---------------------------------------------------------------------------
src = open(TOOL).read()

ok('liveness is derived from the wave stamp, not asserted',
   'fc_live = FIELDCREEP_ID in armed_ids' in src)
ok('the damage index is loaded ONLY when the clause is live',
   'inc = FC.load_nonhero_damage(tl)[0] if fc_live else None' in src)
ok('no unconditional load_nonhero_damage survives outside selfcheck',
   src.count('inc, _outg = FC.load_nonhero_damage(tl)') <= 1,
   'selfcheck deliberately keeps one, to exercise the armed path')

for line in ('=== gated 5th clause `%s` (jmz_func.lua:4890) ===',
             "NOT ARMED in this wave's cand string",
             'Nothing removed; nothing to correct.',
             'armed-leg departure frames charged to it',
             'NOT check the clause -- never that the corpus was clean'):
    ok('disclosure line still present: %s' % line[:44], line in src)

ok('the disclosure prints on the NOT-armed path too',
   'if not fc_live:' in src)
ok('arm-string guard refuses a corpus that never armed this id',
   'refusing to' in src and 'CAND_ID not in armed_ids' in src)
ok('mixed cand strings are fatal, not averaged',
   'mixed cand strings in this corpus' in src)
ok('the stale "IS ARMED" standing claim is gone from the header',
   "string) `fieldcreep` IS ARMED" not in src)

print('\n%s' % ('all checks passed' if not fails
                else 'FAILURES:\n  ' + '\n  '.join(fails)))
sys.exit(1 if fails else 0)

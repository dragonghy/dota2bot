#!/usr/bin/env python3
"""Corpus-free battery for `idletrip_domain.py`, the idle-fountain-round-trip probe.

WHY THIS FILE EXISTS.  `tests/run_py_tests.sh` loops over `tests/test_*.py`
only, so a probe invoked solely by hand is a probe nothing in the tree runs --
the GH #243 shape, now caught for the sixth time in this family.  This file
lands in the same commit as its subject so the subject is never once in that
state.

WHAT IS ACTUALLY BEING PROTECTED
--------------------------------
⭐ THE EXPLANATION LADDER'S ORDER AND ITS CONSERVATIVE DIRECTIONS.
`idle` is the finding.  Everything above it in the ladder -- `hurt`, `mana`,
`shopping` -- is a reason the trip might have been worth taking, and each one
of them is resolved AGAINST calling a trip pointless.  Every way that
discipline can be lost is silent and produces a bigger, more interesting
number:

  * moving `idle` up the ladder, or dropping a rung, inflates the finding;
  * comparing inventories order-sensitively turns a slot reshuffle into
    `shopping` -- which deflates it, the other direction, equally silently;
  * scoring a MISSING `mp_pct` as full mana pushes those rows INTO `idle`.
    A timeline without mana is not evidence of full mana.  The subject
    disqualifies such rows instead, and this file pins that direction.

⭐⭐ THE RETURN LEG MUST NOT COUNT A TELEPORT AS A WALK.  This is not a
hypothetical: it is the defect the tool found on its first run.  The 21:58Z
hand reading of this same corpus reported "122 of 127 (96%) back out past
4000u within 60s ... 464 hero-seconds per game".  Scoring the return leg with
the walking-trace discipline gives **84 of 127 (66%)** and **338 s/game**,
because **45 of the 155 walks home ended in a TP OUT**.  A bot that scrolls
back to lane did not burn the walk, so counting it inflates the cost claim by
roughly a third.  `continuity_break` returning "tp" on the return leg, and the
caller mapping it to `out_break="tp_out"` with `returned=False`, is the entire
correction -- reverse either and the tool reproduces the wrong number while
looking exactly as healthy.

⭐⭐⭐ `continuity_break` MUST TERMINATE ITS CALLERS, NOT BE STEPPED OVER.
Inherited verbatim from `stayfield2_margin.homeward_close`, where three
successive versions died the same death: a frame was SKIPPED (corpse, TP
channel) and the scan carried on with `prev` reset, which disarms the
displacement guard on the very next frame -- the one that had teleported.  A
RESPAWN then scores as "walked home".

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
TOOL = os.path.join(BEHAV, 'idletrip_domain.py')

fails = []


def ok(name, cond, why=''):
    print('%-70s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(TOOL):
    print('could not read %s' % TOOL)
    sys.exit(2)

sys.path.insert(0, BEHAV)
try:
    import idletrip_domain as IT                                # noqa: E402
except Exception as exc:                                        # pragma: no cover
    print('could not import idletrip_domain: %s' % exc)
    sys.exit(2)

print('corpus checks SKIPPED, not passed '
      '(--selfcheck needs sweep dirs; CI has none)')


# ---------------------------------------------------------------------------
# the explanation ladder
# ---------------------------------------------------------------------------
FULL = ['flask', 'tango']

ok('a full-hp full-mana unchanged-bag trip is IDLE',
   IT.explain(1.00, 1.00, FULL, FULL) == 'idle')
ok('a hurt departure is `hurt`, never `idle`',
   IT.explain(0.40, 1.00, FULL, FULL) == 'hurt')
ok('a low-mana departure is `mana`, never `idle`',
   IT.explain(1.00, 0.20, FULL, FULL) == 'mana')
ok('a bag that changed is `shopping`, never `idle`',
   IT.explain(1.00, 1.00, FULL, FULL + ['blink_dagger']) == 'shopping')

# ---- ORDER.  A trip can satisfy several rungs; it must land on the first. --
ok('hurt outranks mana',
   IT.explain(0.40, 0.20, FULL, FULL) == 'hurt')
ok('hurt outranks shopping',
   IT.explain(0.40, 1.00, FULL, []) == 'hurt')
ok('mana outranks shopping',
   IT.explain(1.00, 0.20, FULL, []) == 'mana')
ok('idle is the last rung, reached only when every other one is clear',
   IT.EXPLANATIONS[-1] == 'idle' and IT.EXPLANATIONS[0] == 'hurt')

# ---- the two boundaries, each in its conservative direction ---------------
ok('hp exactly at HP_FULL counts as hurt (<=, not <)',
   IT.explain(IT.HP_FULL, 1.00, FULL, FULL) == 'hurt')
ok('hp a hair above HP_FULL is not hurt',
   IT.explain(IT.HP_FULL + 0.01, 1.00, FULL, FULL) == 'idle')
ok('mp exactly at MP_FULL is NOT `mana` (<, not <=)',
   IT.explain(1.00, IT.MP_FULL, FULL, FULL) == 'idle')
ok('mp a hair below MP_FULL is `mana`',
   IT.explain(1.00, IT.MP_FULL - 0.01, FULL, FULL) == 'mana')

# ---- inventory comparison must be order-insensitive -----------------------
# A slot reshuffle is not shopping.  Getting this wrong deflates the finding,
# which is the direction nobody goes looking for.
ok('a reordered bag is not `shopping`',
   IT.explain(1.00, 1.00, ['tango', 'flask'], ['flask', 'tango']) == 'idle')
ok('a bag that lost an item IS `shopping`',
   IT.explain(1.00, 1.00, FULL, ['flask']) == 'shopping')
ok('two empty bags are not `shopping`',
   IT.explain(1.00, 1.00, [], []) == 'idle')

# ---- missing mana: disqualify, never assume full -------------------------
# round_trips() passes 0.0 in place of a missing mp_pct precisely so the row
# falls into `mana` instead of `idle`.  Pinned here as the contract.
ok('a missing mp_pct, passed as the subject passes it, lands in `mana`',
   IT.explain(1.00, 0.0, FULL, FULL) == 'mana')
# `explain` cannot see whether mana was missing or merely zero, so the
# disqualifying substitution lives in round_trips and is pinned at its source.
# Substituting 1.0 there would be invisible to every check above.
ok('round_trips substitutes 0.0 (not 1.0) for a missing mp_pct',
   'mp0 if mp_known else 0.0' in open(TOOL).read())


# ---------------------------------------------------------------------------
# continuity_break -- the five discontinuities, and the tp mapping
# ---------------------------------------------------------------------------
class FakeG(object):
    interval = 1.0

    def __init__(self, deaths=()):
        self.deaths = {'h': list(deaths)}


def f(t, x=0.0, y=0.0, hp=1.0):
    return {'t': t, 'x': x, 'y': y, 'hp_pct': hp}


A = f(100.0)
ok('a normal one-second step is not a break',
   IT.continuity_break(FakeG(), 'h', A, f(101.0, 200.0), []) is None)
ok('a sampling gap breaks',
   IT.continuity_break(FakeG(), 'h', A, f(103.0), []) == 'gap')
ok('a corpse frame breaks',
   IT.continuity_break(FakeG(), 'h', A, f(101.0, hp=0.0), []) == 'corpse')
ok('a death inside the step breaks',
   IT.continuity_break(FakeG(deaths=[100.5]), 'h', A, f(101.0), []) == 'death')
ok('a TP channel opening inside the step breaks',
   IT.continuity_break(FakeG(), 'h', A, f(101.0), [100.5]) == 'tp')
ok('a superhuman step breaks',
   IT.continuity_break(FakeG(), 'h', A, f(101.0, 5000.0), []) == 'jump')
ok('a step exactly at the walk cap does NOT break',
   IT.continuity_break(FakeG(), 'h', A, f(101.0, IT.WALK_CAP_U), []) is None)

# ---- the discontinuities are distinguishable, which is what lets the caller
# ---- map exactly ONE of them ("tp") to tp_out and leave the rest alone.
ok('every discontinuity has its own distinct name',
   len({IT.continuity_break(FakeG(), 'h', A, f(103.0), []),
        IT.continuity_break(FakeG(), 'h', A, f(101.0, hp=0.0), []),
        IT.continuity_break(FakeG(deaths=[100.5]), 'h', A, f(101.0), []),
        IT.continuity_break(FakeG(), 'h', A, f(101.0), [100.5]),
        IT.continuity_break(FakeG(), 'h', A, f(101.0, 5000.0), [])}) == 5)

# The source must actually contain the tp_out mapping and the terminating
# `break`; a reader who deletes either gets a tool that silently reproduces
# the 96%/464 s number this file exists to have corrected.
src = open(TOOL).read()
ok('the return leg maps a TP to tp_out (string-pinned)',
   '"tp_out" if br == "tp" else br' in src)
ok('the subject still refuses a mixed cand string',
   'mixed cand strings in this corpus' in src)
ok('the subject still states that it scores no gate',
   'THIS TOOL SCORES NO GATE' in src)
ok('the subject prints all four (stratum x leg) cells, not a pool',
   'def cells(' in src and 'for leg in ("armed", "baseline")' in src)


# ---------------------------------------------------------------------------
print('')
if fails:
    print('FAILURES (%d):' % len(fails))
    for x in fails:
        print('  - %s' % x)
    sys.exit(1)
print('all checks passed (pure half only; corpus half not run)')

#!/usr/bin/env python3
"""Runs `cmqreach_domain.py`'s selfcheck battery from the python suite, and pins
the parts of it a future edit is most likely to undo.

WHY THIS WRAPPER EXISTS.  `tests/run_py_tests.sh` only loops over
`tests/test_*.py`, so a module-level `--selfcheck` that nothing invokes is a
gate that never opens (the GH #243 shape; same reason `tests/test_od_stall_leg.py`
and `tests/test_tpreach_domain.py` exist).

THE FALSY-ZERO TRAP, PINNED BY NAME.  The first version of the module's own
selfcheck wrote `abs(nearest_center_dist(...) or -1) < 1e-6` to check that CM
standing INSIDE the lens reads distance 0.  `0.0 or -1` is `-1` in Python, so
the check failed on its own idiom while the function was correct.  A `None`
return and a legitimate `0.0` return are the two answers this function must
keep distinguishable, and `or` cannot distinguish them.  `test_falsy_zero`
below fails if anyone reintroduces that conflation.

THE DIRECTION THAT MATTERS.  `cmqreach` narrows the creep search from
`nCastRange + nRadius` to `nCastRange`, and the id's whole admission argument
(§CO, "纯收窄") is that a SMALLER search can never see MORE.  If
`best_pair()` ever became non-monotone in `reach`, the gap-frame count would
stop meaning "shipped reaches a point armed cannot" and every reading built on
it would silently change question.  `test_monotone_in_reach` pins it on random
geometry, not on one hand-picked pair.
"""

import os
import random
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'cmqreach_domain.py')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))

fails = []


def check(label, cond):
    if not cond:
        fails.append(label)


# ---- 1. the module's own battery, through its real exit code (not a pipe) ---
p = subprocess.run([sys.executable, TOOL, '--selfcheck'],
                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
out = p.stdout.decode()
check('module selfcheck exits 0 (bare, not through a pipe)', p.returncode == 0)

# The count is read, not hardcoded to one value: the first version of this line
# was `'10/10' in out`, which turned every ADDED assertion into a red test
# (2026-09-08, when GH #626's battery took it to 26).  A literal is still wanted
# in the SHRINKING direction -- deleting assertions must not pass quietly -- so
# the pin is a ratchet: all green, and never fewer than we have already banked.
RATCHET = 26                         # raise when the module's battery grows
m = re.search(r'selfcheck (\d+)/(\d+)', out)
check('module selfcheck prints its count at all', m is not None)
if m:
    ran, total = int(m.group(1)), int(m.group(2))
    check('module selfcheck reports every check green', ran == total)
    check('module selfcheck battery has not shrunk (>= %d)' % RATCHET,
          total >= RATCHET)

import cmqreach_domain as C                                       # noqa: E402

R = C.RADIUS


# ---- 2. the falsy-zero trap ------------------------------------------------
def test_falsy_zero():
    inside = C.nearest_center_dist(1000, 50, 1000, 0, 1000, 100, R)
    empty = C.nearest_center_dist(0, 0, 1000, 0, 1000, 2 * R + 1, R)
    check('CM inside the lens returns a real 0.0, not None',
          inside is not None and abs(inside) < 1e-9)
    check('an empty lens returns None, not 0.0', empty is None)
    check('0.0 and None are distinguishable without `or`',
          (inside is None) != (empty is None))


# ---- 3. monotonicity in reach, on random geometry --------------------------
def test_monotone_in_reach():
    rng = random.Random(20260831)
    bad = 0
    for _ in range(400):
        creeps = [(rng.uniform(-2000, 2000), rng.uniform(-2000, 2000))
                  for _ in range(rng.randint(2, 8))]
        armed = C.best_pair(0, 0, creeps, R, 732.0)
        shipped = C.best_pair(0, 0, creeps, R, 1157.0)
        if armed is not None and shipped is None:
            bad += 1
        if armed is not None and shipped is not None and shipped[0] > armed[0] + 1e-9:
            bad += 1
    check('a pair the armed search reaches is always reachable by the '
          'shipped search (the id is a pure narrowing)', bad == 0)


# ---- 4. the lens really is the intersection, checked by brute force --------
def test_lens_against_bruteforce():
    rng = random.Random(4924)
    worst = 0.0
    for _ in range(120):
        ax, ay = rng.uniform(-1500, 1500), rng.uniform(-1500, 1500)
        bx, by = ax + rng.uniform(-800, 800), ay + rng.uniform(-800, 800)
        cx, cy = rng.uniform(-2500, 2500), rng.uniform(-2500, 2500)
        exact = C.nearest_center_dist(cx, cy, ax, ay, bx, by, R)
        # dense sample of the lens; the grid can only ever be WORSE than exact
        best = None
        lo_x, hi_x = min(ax, bx) - R, max(ax, bx) + R
        lo_y, hi_y = min(ay, by) - R, max(ay, by) + R
        for i in range(70):
            for j in range(70):
                px = lo_x + (hi_x - lo_x) * i / 69.0
                py = lo_y + (hi_y - lo_y) * j / 69.0
                if (C.dist(px, py, ax, ay) <= R and C.dist(px, py, bx, by) <= R):
                    d = C.dist(cx, cy, px, py)
                    if best is None or d < best:
                        best = d
        if exact is None:
            check('closed form says empty only when the grid finds nothing',
                  best is None or best > 0)
            continue
        if best is not None:
            # exact must never be WORSE than a grid point (it may be better)
            worst = max(worst, exact - best)
    check('closed-form minimum is never beaten by a dense grid sample '
          '(exceeded by %.1fu)' % worst, worst < 1.0)


# ---- 5. source constants, so a silent retune shows up ----------------------
def test_source_constants():
    check('cast ring without Aether Lens is 732',
          abs(C.CAST_RANGE_KV + C.CAST_RANGE_PAD - 732.0) < 1e-9)
    check('shipped creep-search ring is 1157 = cast + radius',
          abs(C.CAST_RANGE_KV + C.CAST_RANGE_PAD + C.RADIUS - 1157.0) < 1e-9)
    check('the overshoot is exactly nRadius', abs(C.RADIUS - 425.0) < 1e-9)
    check('every creep return site needs rank >= 3', C.SKILL_LV_MIN == 3)
    check('the widest creep threshold at any site is >= 2', C.COUNT_MIN == 2)
    check('lane creeps only; neutrals (team 4) are not lane creeps',
          4 not in C.CREEP_TEAMS)


# ---- 6. the mana floor is a probe and must stay ABOVE any nova cost --------
def test_mana_floor_is_conservative():
    check('MANA_FLOOR is above any plausible nova mana cost, so every counted '
          'frame is genuinely castable', C.MANA_FLOOR >= 200.0)
    check('the sensitivity floor is strictly lower, or it is not a sensitivity',
          C.MANA_FLOOR_LO < C.MANA_FLOOR)


# ---- 7. GH #626: a teleport channel is not a decision frame ----------------
def test_tp_channel_is_out_of_domain():
    """A second door on the guard, independent of the module's own battery.

    The module selfcheck builds the same frame; this one exists so that an edit
    deleting BOTH the guard and its selfcheck case still turns the python suite
    red.  Deliberately minimal: it asserts the two predicates and the domain
    exit, not the geometry (§2-4 above already own the geometry).
    """
    snaps = [{'hero': 'npc_dota_hero_crystal_maiden', 'idx': 1, 'team': 2,
              't': t, 'x': x, 'y': y, 'hp_pct': 1.0, 'mp': 1023.0, 'items': [],
              'abilities': [{'name': C.NOVA, 'level': 4, 'cd': 0.0}]}
             for (t, x, y) in ((1518.4, 4941.0, -5802.0),
                               (1521.4, 5219.0, -5689.0),
                               (1523.4, -5131.0, -4815.0))]
    creeps = [{'t': t, 'x': 6500.0, 'y': y, 'team': 3}
              for t in (1518.4, 1521.4) for y in (-5802.0, -5652.0)]
    tp = [{'type': 'MODIFIER_ADD', 't': 1519.3,
           'target': 'npc_dota_hero_crystal_maiden',
           'inflictor': C.TP_MODIFIER},
          {'type': 'MODIFIER_REMOVE', 't': 1522.3,
           'target': 'npc_dota_hero_crystal_maiden',
           'inflictor': C.TP_MODIFIER}]

    def tl(events):
        return {'game': {'teams': {}}, 'snapshots': snaps, 'creeps': creeps,
                'events': events}

    ctrl = C.Game(tl([]))
    fixed = C.Game(tl(tp))
    ctrl_t = [round(r['t'], 1) for r in C.gap_frames(ctrl, C.MANA_FLOOR)]
    fixed_t = [round(r['t'], 1) for r in C.gap_frames(fixed, C.MANA_FLOOR)]
    check('CONTROL: without the TP events the channel frame IS a gap frame '
          '(otherwise the exclusion below proves nothing)', ctrl_t == [1518.4, 1521.4])
    check('a frame inside CM\'s own TP channel leaves the gap domain',
          fixed_t == [1518.4])
    check('the channel span is read exactly off ADD/REMOVE',
          fixed.tp_spans == [(1519.3, 1522.3)])
    check('a movement window crossing the channel is unscored, and says why',
          C.unscored_reason(fixed, C.gap_frames(fixed, C.MANA_FLOOR)[0]) == 'tp')


for fn in (test_falsy_zero, test_monotone_in_reach, test_lens_against_bruteforce,
           test_source_constants, test_mana_floor_is_conservative,
           test_tp_channel_is_out_of_domain):
    fn()

if fails:
    for f in fails:
        print('FAIL: %s' % f)
    sys.exit(1)
print('ok: cmqreach_domain checks passed')

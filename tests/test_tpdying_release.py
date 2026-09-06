#!/usr/bin/env python3
"""Runs `tpdying_release.py`'s selfcheck battery from the python suite, and pins
the three properties a future edit is most likely to undo.

WHY THIS WRAPPER EXISTS.  `tests/run_py_tests.sh` only loops over
`tests/test_*.py`, so a module-level `--selfcheck` that nothing invokes is a
gate that never opens (the GH #243 shape; same reason `tests/test_od_stall_leg.py`,
`tests/test_tpreach_domain.py` and `tests/test_cmqreach_domain.py` exist).

THE REACHABILITY REFUSAL IS THE POINT, AND IT IS PINNED HERE BY NAME.
`tpdying`'s clause sits INSIDE `J.GetTpCommitDefendDesire`, whose second line
is `if not J.IsSoakCandidate( 'tpcommit' ) then return nil end`.  Armed alone
it is byte-for-byte inert, so a wave that armed `tpdying` without `tpcommit`
would produce a perfectly clean-looking ZERO -- the exact shape the 2026-09-06
`suptp` round found (`A or B` co-armed => B never carries weight) read from the
other side.  `--assert-arm` exists to make that unreportable, and
`test_refuses_unreachable_wave` below fails if the refusal is ever softened
into a warning.

THE OFF-BY-ONE THAT DELETES A WHOLE CLASS OF LANDINGS.  The landing sample must
be the first snapshot STRICTLY AFTER the `modifier_teleporting` MODIFIER_REMOVE.
Written `>=`, a sample sitting exactly on the removal instant still shows the
hero at his DEPARTURE point: the trip reads 0, the episode is discarded as an
interruption, and on a ~1 Hz dump that silently deletes every landing whose
tick happens to coincide with the event.  It was the module's own clean-landing
case that caught this, not real corpus -- real corpus would have shown a
slightly smaller n and nothing else.  `test_landing_sample_is_strictly_after`
pins it.

DIRECTION IS THE WHOLE READING.  The candidate can only ever RELEASE a pin
sooner (`return nil`), never raise or create one, so its (a) signature is
one-sided by construction: fewer pinned frames, more drift.  If `pinned` ever
stopped being monotone in the pin radius, or if a walking hero stopped counting
fewer pinned frames than a standing one, every reading built on it would change
question without changing shape.  `test_pin_monotone_in_radius` and
`test_release_shape` pin both on generated geometry rather than one frame.
"""

import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'tpdying_release.py')
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
check('module selfcheck reports every check green', ' 0 FAIL' in out)
check('the battery is not vacuous', 'PASS' in out and '/ 0 FAIL' in out)

import tpdying_release as T                                       # noqa: E402


def _game(post, press_t=10.0, end_t=13.0, hero='npc_dota_hero_lion'):
    """A pre-horn hero at the origin who teleports and then follows `post`."""
    pre = T._mk(hero, [(-60, 0, 0), (-59, 0, 0)])
    walk = T._mk(hero, [(t, 0.0, 0.0) for t in (8, 9, 10, 11, 12, 13)])
    return T._tl(pre + walk + T._mk(hero, post),
                 [T._tp(hero, press_t), T._tp(hero, end_t, 'MODIFIER_REMOVE')])


# ---- 2. the reachability refusal -------------------------------------------
def test_refuses_unreachable_wave():
    without = subprocess.run(
        [sys.executable, TOOL, '--assert-arm', 'tpdying,lf_rescue,midtp'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    check('a wave without `tpcommit` is REFUSED, not reported as a zero',
          without.returncode != 0)
    check('the refusal names the enclosing gate',
          b'tpcommit' in without.stdout)
    check('REQUIRED_PARTNER is still the enclosing gate',
          T.REQUIRED_PARTNER == 'tpcommit')
    both = subprocess.run(
        [sys.executable, TOOL, '--assert-arm', 'tpcommit,tpdying'],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    check('a wave with both armed is not refused for reachability',
          b'byte-for-byte inert' not in both.stdout)


# ---- 3. the strictly-after landing sample ----------------------------------
def test_landing_sample_is_strictly_after():
    # A tick sits EXACTLY on the removal instant, still at the departure point,
    # and the real landing tick follows.  Under `>=` this reads trip 0 and the
    # landing vanishes.
    post = [(13.0, 0.0, 0.0)] + [(t, 6000.0, 0.0) for t in range(14, 30)]
    eps, _ = T.tp_episodes(_game(post), 'g', T.DEFAULT_TRIP_FLOOR_U)
    check('a tick exactly on MODIFIER_REMOVE does not delete the landing',
          len(eps) == 1)
    check('the landing is read from the tick AFTER the removal instant',
          eps and eps[0]['land_t'] == 14.0 and eps[0]['trip'] == 6000)


# ---- 4. pinned frames are monotone in the radius, on random geometry -------
def test_pin_monotone_in_radius():
    rng = random.Random(20260906)
    bad = 0
    for _ in range(300):
        cx, cy = 6000.0, 0.0
        post = [(14.0, cx, cy)]
        for t in range(15, 27):
            post.append((float(t), cx + rng.uniform(-2500, 2500),
                         cy + rng.uniform(-2500, 2500)))
        eps, _ = T.tp_episodes(_game(post), 'g', T.DEFAULT_TRIP_FLOOR_U)
        if not eps:
            continue
        pin = eps[0]['pinned']
        vals = [pin[r] for r in T.PIN_RADII_U]
        if any(b < a for a, b in zip(vals, vals[1:])):
            bad += 1
    check('a wider pin radius never counts FEWER pinned frames', bad == 0)


# ---- 5. the one-sided release shape ----------------------------------------
def test_release_shape():
    stand = [(float(t), 6000.0, 0.0) for t in range(14, 30)]
    leave = [(float(t), 6000.0 + 400.0 * (t - 13), 0.0) for t in range(14, 30)]
    a, _ = T.tp_episodes(_game(stand), 'g', T.DEFAULT_TRIP_FLOOR_U)
    b, _ = T.tp_episodes(_game(leave), 'g', T.DEFAULT_TRIP_FLOOR_U)
    check('a released (walking) lander counts fewer pinned frames at every '
          'radius',
          a and b and all(b[0]['pinned'][r] < a[0]['pinned'][r]
                          for r in T.PIN_RADII_U))
    check('drift moves the opposite way from the pin count, so the two '
          'cannot agree by construction',
          a and b and b[0]['drift'] > a[0]['drift'])


# ---- 6. source constants, so a silent retune shows up ----------------------
def test_source_constants():
    src = open(os.path.join(ROOT, 'bots', 'ability_item_usage_generic.lua'),
               encoding='utf-8', errors='replace').read()
    jmz = open(os.path.join(ROOT, 'bots', 'FunLib', 'jmz_func.lua'),
               encoding='utf-8', errors='replace').read()
    check('the commitment window mirrors the three stamp sites (12.0 s)',
          T.COMMIT_WINDOW_S == 12.0 and 'DotaTime() + 12.0' in src)
    check('the trip floor mirrors nMinTPDistance - 500',
          T.DEFAULT_TRIP_FLOOR_U == 5000.0 and 'nMinTPDistance = 5500' in src)
    check('detector (1) still uses the 10 s window §A\'.3 named',
          T.DEATH_WINDOW_S == 10.0)
    check('tpdying is still gated, and still nested inside tpcommit',
          "J.IsSoakCandidate( 'tpdying' )" in jmz
          and (jmz.index("if not J.IsSoakCandidate( 'tpcommit' ) then return nil end")
               < jmz.index("if J.IsSoakCandidate( 'tpdying' )")))
    check('the default pin radius is one of the reported radii',
          T.DEFAULT_PIN_RADIUS_U in T.PIN_RADII_U)


for fn in (test_refuses_unreachable_wave, test_landing_sample_is_strictly_after,
           test_pin_monotone_in_radius, test_release_shape,
           test_source_constants):
    fn()

if fails:
    for f in fails:
        print('FAIL: %s' % f)
    sys.exit(1)
print('ok: tpdying_release checks passed')

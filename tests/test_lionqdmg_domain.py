#!/usr/bin/env python3
"""Runs `lionqdmg_domain.py`'s selfcheck battery from the python suite, and pins
the parts of it that would fail SILENTLY -- i.e. keep producing a plausible
number after the question changed.

WHY THIS WRAPPER EXISTS.  `tests/run_py_tests.sh` only loops over
`tests/test_*.py`, so a module-level `--selfcheck` that nothing invokes is a
gate that never opens (the GH #243 shape; same reason `tests/test_od_stall_leg.py`,
`tests/test_tpreach_domain.py` and `tests/test_cmqreach_domain.py` exist).

THE DIRECTION THAT MATTERS, AND WHY IT IS THE OPPOSITE OF `wkqdmg`'s.
`wkqdmg` is a `math.min` NARROWING: its armed leg can only withdraw a claimed
kill.  `lionqdmg` is a WIDENING: shipped reads a structural 0, armed reads
105/170/235/300, so the armed leg can only ADD casts.  Everything this tool
counts is therefore a COUNTERFACTUAL on the shipped leg -- "would the kill loop
have fired here" -- and the two readouts that carry the whole conclusion are

    (2) ready       the kill loop is traversed at all
    (3) kill(mr25)  the armed claim reaches a living enemy's health bar

If `mr25` ever stopped being STRICTLY TIGHTER than `raw`, cell (3) would still
print a number and the report built on it would silently change question from
"could it kill" to "could it kill ignoring magic resistance".  `test_mr25_is_
tighter` pins that.  `test_upper_bound_direction` pins the other one: every
unobservable predicate must be assumed in the direction that INFLATES the
domain, because this file's conclusion on W30 is a NEGATIVE one ("the domain is
one episode in ten games") and a negative read off an upper bound is safe while
a positive one is not.

READING DISCIPLINE PINNED TOO.  The stream counts EPISODES, not frames: at a
~1s sample a single two-second chase contributes two frames and one episode,
and quoting the frame count doubles the apparent domain.  `test_episodes`
pins the gap rule, including that unsorted input is sorted first (the corpus
merges four sweep dirs, so timestamps do not arrive ordered).
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'lionqdmg_domain.py')
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
# NOT `'FAIL' not in out`: that idiom passes on an empty battery and on a
# crash before the first line.  Count the greens against the total instead.
n_pass = sum(1 for l in out.splitlines() if l.startswith('PASS'))
check('module selfcheck ran a non-trivial battery', n_pass >= 20)
check('module selfcheck reports every check green',
      ('%d/%d PASS' % (n_pass, n_pass)) in out)
check('module selfcheck disclaims the corpus half rather than implying it',
      'corpus checks SKIPPED, not passed' in out)

import lionqdmg_domain as L                                       # noqa: E402


# ---- 2. source constants, so a silent retune shows up ----------------------
def test_source_constants():
    check('the per-rank KV damage is the 105/170/235/300 row',
          L.Q_DAMAGE == (105.0, 170.0, 235.0, 300.0))
    check('the per-rank KV mana cost is the 90/110/130/150 row',
          L.Q_MANA == (90.0, 110.0, 130.0, 150.0))
    check('Earth Spike cast range is flat 650 at every rank',
          L.CAST_RANGE_KV == 650.0)
    check('hero_lion.lua:568 pads the cast range by 20', L.CAST_RANGE_PAD == 20.0)
    check('the kill loop reads nInBonusEnemyList = nCastRange + 200',
          L.BONUS_PAD == 200.0)
    check('Aether Lens is +250, the same bonus hero_lion.lua:394 applies',
          L.AETHER_BONUS == 250.0)
    check('the catch-all branch this id is NOT covered by needs level >= 15',
          L.FALLBACK_LEVEL == 15)
    check('IsInTeamFight is called with 1200 at this call site',
          L.TEAMFIGHT_R == 1200.0 and L.TEAMFIGHT_ALLIES == 2)
    check('all three acceptance tiers are present, 0% first',
          L.AMP_TIERS == (0.0, 0.15, 0.20))


# ---- 3. mr25 must stay STRICTLY tighter than raw ---------------------------
def test_mr25_is_tighter():
    check('base magic resist multiplier is below 1, or mr25 is not a resist',
          0.0 < L.BASE_MAGIC_RESIST_MULT < 1.0)
    # a target sitting exactly on the raw line must NOT survive into mr25
    row = _frame(enemy_hp=105.0, enemy_x=800.0)
    check('hp exactly at the raw claim counts raw', row['kill_raw_0.0'])
    check('hp exactly at the raw claim does NOT count mr25',
          not row['kill_mr25_0.0'])
    # and mr25 must never fire where raw does not, at any tier
    for hp in (1.0, 50.0, 78.0, 79.0, 105.0, 200.0, 400.0):
        r = _frame(enemy_hp=hp, enemy_x=800.0)
        for amp in L.AMP_TIERS:
            check('mr25 never fires where raw does not (hp=%s amp=%s)' % (hp, amp),
                  (not r['kill_mr25_%s' % amp]) or r['kill_raw_%s' % amp])


# ---- 4. the unobservable predicates must inflate, never deflate ------------
def test_upper_bound_direction():
    # An enemy who is only reachable because we ignore fog still counts: the
    # tool is an upper bound on the engine's domain.  Flipping this would turn
    # the negative conclusion into an unsupported one.
    near = _frame(enemy_hp=50.0, enemy_x=800.0)
    far = _frame(enemy_hp=50.0, enemy_x=10000.0)
    check('an enemy inside the ring counts regardless of vision', near['ready'])
    check('an enemy outside the ring never counts', not far['ready'])
    # the ally count is a NECESSARY-condition exclusion for IsInTeamFight;
    # fewer than 2 nearby allies means the predicate is definitely false.
    check('two nearby allies are seen, so the frame is NOT credited as '
          'definitely-not-a-teamfight',
          _frame(enemy_hp=50.0, enemy_x=800.0, allies=2)['allies_1200'] == 2)


# ---- 5. episodes, not frames ----------------------------------------------
def test_episodes():
    check('adjacent samples are one episode', L.episodes([1.0, 1.5, 2.0]) == 1)
    # the gap is measured from the PREVIOUS sample, not from the run's start --
    # getting that wrong merges long chases into one episode and shrinks the
    # domain readout, which is the flattering direction for a negative verdict.
    check('a gap wider than the rule splits',
          L.episodes([1.0, 1.5, 1.5 + L.EPISODE_GAP_S + 0.1]) == 2)
    check('the gap is measured from the previous sample, not the first',
          L.episodes([1.0, 4.0, 7.0, 10.0]) == 1)
    check('a gap exactly at the rule does NOT split',
          L.episodes([1.0, 1.0 + L.EPISODE_GAP_S]) == 1)
    check('unsorted input is sorted first', L.episodes([20.0, 1.0, 1.5]) == 2)
    check('no frames is no episodes', L.episodes([]) == 0)


# ---- 6. readiness is a conjunction; each clause must be able to say no -----
def test_ready_clauses():
    check('rank 0 (unlearned) is not ready',
          not _frame(enemy_hp=50.0, enemy_x=800.0, q_level=0)['ready'])
    check('a cooling-down Q is not ready',
          not _frame(enemy_hp=50.0, enemy_x=800.0, cd=0.1)['ready'])
    check('mana one point below the rank cost is not ready',
          not _frame(enemy_hp=50.0, enemy_x=800.0, mp=89.0)['ready'])
    check('a dead enemy is not a target',
          not _frame(enemy_hp=50.0, enemy_x=800.0, enemy_alive=False)['ready'])
    check('rank 4 reads the rank-4 mana cost, not the rank-1 one',
          not _frame(enemy_hp=50.0, enemy_x=800.0, q_level=4, mp=149.0)['ready'])


# ---- 7. reach arithmetic ---------------------------------------------------
def test_reach():
    base = L._snap()
    check('no lens, no talent: 650 + 20 + 200', L.reach_of(base) == 870.0)
    check('lens adds 250', L.reach_of(L._snap(items=['aether_lens'])) == 1120.0)
    talent = L._snap(abilities=[{'name': L.CAST_RANGE_TALENT, 'level': 1,
                                 'cd': 0, 'cd_len': 0}])
    check('the +600 talent is read off the frame, not assumed absent '
          '(hero_lion.lua:395 is commented out, so aetherRange does not carry it)',
          L.reach_of(talent) == 1470.0)
    check('an untrained talent row adds nothing',
          L.reach_of(L._snap(abilities=[{'name': L.CAST_RANGE_TALENT, 'level': 0,
                                         'cd': 0, 'cd_len': 0}])) == 870.0)


def _frame(enemy_hp, enemy_x, q_level=1, cd=0.0, mp=500.0, lion_level=6,
           allies=0, enemy_alive=True):
    """One synthetic frame driven through the real `scan_game`."""
    snaps = [L._snap(t=0.0, abilities=L._q(q_level, cd), mp=mp, level=lion_level)]
    snaps.append(L._snap(t=0.0, hero='npc_dota_hero_lina', idx=2, team=3,
                         hp=enemy_hp if enemy_alive else 0.0, x=enemy_x,
                         abilities=[]))
    for i in range(allies):
        snaps.append(L._snap(t=0.0, hero='npc_dota_hero_zuus', idx=10 + i,
                             team=2, x=100.0 * (i + 1), abilities=[]))
    g = L.Game.__new__(L.Game)
    g.teams = {'npc_dota_hero_lion': 2, 'npc_dota_hero_lina': 3,
               'npc_dota_hero_zuus': 2}
    g.has_lion = True
    g.lion_team = 2
    g.primary = {'lion': 1, 'lina': 2, 'zuus': 10}
    g.by_t = {0.0: snaps}
    g.lion = [snaps[0]]
    return L.scan_game(g)[0]


for fn in (test_source_constants, test_mr25_is_tighter, test_upper_bound_direction,
           test_episodes, test_ready_clauses, test_reach):
    fn()

if fails:
    for f in fails:
        print('FAIL: %s' % f)
    sys.exit(1)
print('ok: lionqdmg_domain checks passed  (corpus checks SKIPPED, not passed)')

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


# ---- 8. the outcome column (GH #361) ---------------------------------------
def test_outcome_column():
    HL = 'net_0.0_%s' % L.OUTCOME_HEADLINE_S
    # The defect this column exists for: "26 hp escaped and healed to full" and
    # "1 hp being killed by an ally right now" were the SAME event to cell (3),
    # and on W31 the second kind was 9 of 10.  These two rows must now differ.
    escaped = _frame(enemy_hp=26.0, enemy_x=800.0,
                     enemy_future=[(1.0, 30.0), (2.0, 57.0), (5.0, 190.0)])
    doomed = _frame(enemy_hp=1.0, enemy_x=800.0, enemy_future=[(1.0, 0.0)])
    check('both are still cell (3) frames -- the column subtracts, it does not '
          'redefine the domain',
          escaped['kill_mr25_0.0'] and doomed['kill_mr25_0.0'])
    check('the enemy who escaped and healed is net', escaped[HL])
    check('the enemy who died anyway is NOT net', not doomed[HL])
    check('the headline window is a rung of the printed ladder',
          L.OUTCOME_HEADLINE_S in L.OUTCOME_WINDOWS)
    check('the ladder brackets the 1-5s death delays W31 was hand-read at',
          min(L.OUTCOME_WINDOWS) <= 2.0 and max(L.OUTCOME_WINDOWS) >= 10.0)
    # the window must actually be a window: a death past it is still net there
    late = _frame(enemy_hp=50.0, enemy_x=800.0, enemy_future=[(7.0, 0.0)])
    check('a death at 7s is net inside the 5s window', late[HL])
    check('a death at 7s is not net inside the 10s window',
          not late['net_0.0_10.0'])
    check('the window is not silently unbounded',
          L.OUTCOME_WINDOWS == tuple(sorted(L.OUTCOME_WINDOWS)))
    # net must never exceed cell (3): it is a SUBSET, at every tier and window
    for hp in (1.0, 26.0, 78.0, 79.0, 105.0, 400.0):
        for fut in ([], [(1.0, 0.0)], [(1.0, 300.0)]):
            r = _frame(enemy_hp=hp, enemy_x=800.0, enemy_future=fut)
            for amp in L.AMP_TIERS:
                for w in L.OUTCOME_WINDOWS:
                    check('net is a subset of cell (3) (hp=%s amp=%s w=%s)'
                          % (hp, amp, w),
                          (not r['net_%s_%s' % (amp, w)])
                          or r['kill_mr25_%s' % amp])


def test_outcome_is_an_upper_bound():
    """Both survivorship choices must INFLATE net, never deflate it.

    The stream's standing finding on this id is NEGATIVE, and a negative read
    off an upper bound is safe while a positive one is not.  If either of these
    flipped, `net` would shrink toward zero on its own and the tool would agree
    with the standing verdict for the wrong reason.
    """
    HL = 'net_0.0_%s' % L.OUTCOME_HEADLINE_S
    check('a victim with NO further samples counts as survived',
          _frame(enemy_hp=50.0, enemy_x=800.0)[HL])
    # ANY qualifying victim surviving keeps the frame: with two victims, one
    # doomed and one escaping, the frame is still net.
    snaps = [L._snap(t=0.0, abilities=L._q(1, 0.0), mp=500.0, level=6),
             L._snap(t=0.0, hero='npc_dota_hero_lina', idx=2, team=3,
                     hp=1.0, x=200.0, abilities=[]),
             L._snap(t=0.0, hero='npc_dota_hero_luna', idx=3, team=3,
                     hp=40.0, x=300.0, abilities=[])]
    g = L.Game.__new__(L.Game)
    g.teams = {'npc_dota_hero_lion': 2, 'npc_dota_hero_lina': 3,
               'npc_dota_hero_luna': 3}
    g.has_lion = True
    g.lion_team = 2
    g.primary = {'lion': 1, 'lina': 2, 'luna': 3}
    g.by_t = {0.0: snaps}
    g.lion = [snaps[0]]
    g.by_hero = {'lion': [(0.0, 500.0)],
                 'lina': [(0.0, 1.0), (1.0, 0.0)],
                 'luna': [(0.0, 40.0), (1.0, 200.0)]}
    # the second witness sees the same pair through the combat log: lina's
    # death is logged, luna's is not, so the ANY quantifier must survive in
    # that column too (a per-victim column that lost it would read `netev`
    # off whichever victim happened to be first)
    g.deaths = {'lina': [0.5]}
    g.ev_horizon = max(L.OUTCOME_WINDOWS) + 1.0
    row = L.scan_game(g)[0]
    check('one doomed victim does not cancel a surviving one', row[HL])
    check('...and the same holds in the combat-log column',
          row['netev_0.0_%s' % L.OUTCOME_HEADLINE_S])
    # and hp is read off REAL samples only: a "died" verdict needs a sampled 0,
    # never an interpolated dip (GH #176).
    gg = type('G', (), {})()
    gg.by_hero = {'lina': [(0.0, 50.0), (4.0, 1.0), (12.0, 0.0)]}
    check('a victim still at 1 hp inside the window has not died',
          not L.dies_within(gg, 'lina', 0.0, L.OUTCOME_HEADLINE_S))
    check('a sampled zero past the window is outside it',
          not L.dies_within(gg, 'lina', 0.0, 10.0))
    check('a sampled zero inside a wider window is seen',
          L.dies_within(gg, 'lina', 0.0, 12.0))
    check('samples at or before t0 are never read',
          not L.dies_within(gg, 'lina', 12.0, 5.0))


def test_two_witnesses_are_never_merged():
    """The second column (combat-log DEATH) must stay a SECOND READING.

    The failure this pins is not a crash, it is a merge: someone notices the
    two columns almost always agree and makes one derive from the other (or
    "improves" `net` by consulting events).  After that the report still
    prints two columns, they simply stop being independent, and the corpus
    reading that motivated the second witness -- W31 `ba/baseline`, where the
    combat log had already declared the victim dead 0.1 s BEFORE the frame --
    silently becomes unrepresentable.
    """
    EHL = 'netev_0.0_%s' % L.OUTCOME_HEADLINE_S
    HL = 'net_0.0_%s' % L.OUTCOME_HEADLINE_S
    # same health bar, events swung: only the event column may move
    quiet = _frame(50.0, 800.0, enemy_future=[(1.0, 90.0), (6.0, 600.0)])
    logged = _frame(50.0, 800.0, enemy_future=[(1.0, 90.0), (6.0, 600.0)],
                    deaths={'npc_dota_hero_lina': [2.0]})
    check('the health-bar column ignores the event stream',
          quiet[HL] and logged[HL])
    check('the event column moves when the log does',
          quiet[EHL] and not logged[EHL])
    check('a disagreement is reported as such, not reconciled',
          logged['dis_0.0_%s' % L.OUTCOME_HEADLINE_S])
    # same events, health bar swung: only the hp column may move
    bar_dead = _frame(50.0, 800.0, enemy_future=[(1.0, 0.0)])
    check('the event column ignores the health bar',
          bar_dead[EHL] and not bar_dead[HL])
    # coverage is reported, never folded in
    dark = _frame(50.0, 800.0, ev_horizon=None)
    check('a stopped log is NOT coverage', not dark['evcov_5.0'])
    check('...but the frame is still netev -- coverage is a separate count, '
          'not a filter on the column', dark[EHL])
    # netev, like net, is a subset of cell (3) at every tier and window
    for hp in (1.0, 26.0, 78.0, 79.0, 105.0, 400.0):
        for evs in ({}, {'npc_dota_hero_lina': [2.0]}):
            r = _frame(hp, 800.0, enemy_future=[(1.0, 300.0)], deaths=evs)
            for amp in L.AMP_TIERS:
                for w in L.OUTCOME_WINDOWS:
                    check('netev is a subset of cell (3) (hp=%s amp=%s w=%s)'
                          % (hp, amp, w),
                          r['kill_mr25_%s' % amp]
                          or not r['netev_%s_%s' % (amp, w)])


def test_stale_victims_need_both_halves():
    """The (3c) column must keep BOTH of its conditions.

    It says: the combat log had already reported this "living" victim dead
    when the frame was sampled, AND the next hp sample confirms no respawn
    intervened.  Drop the first half and it degenerates into the ordinary
    outcome column; drop the second and Turbo's fast respawn makes it lie in
    the direction of its own conclusion.  Measured instance:
    `fde133/20260831_065721_slot1` t=217.5, DEATH at t=217.4, snapshot still
    carrying luna at hp 47 -- 1 of 5 cell-(3) frames on that leg.
    """
    SHL = 'stale_0.0_%s' % L.STALE_HEADLINE_S
    both = _frame(50.0, 800.0, enemy_future=[(1.0, 0.0)],
                  deaths={'npc_dota_hero_lina': [-0.1]})
    check('both halves present is stale', both[SHL])
    check('a stale frame is still counted in cell (3) -- this column measures '
          'the contamination, it does not remove it', both['kill_mr25_0.0'])
    check('death AFTER the frame is the ordinary outcome case, not stale',
          not _frame(50.0, 800.0, enemy_future=[(1.0, 0.0)],
                     deaths={'npc_dota_hero_lina': [0.5]})[SHL])
    check('a prior death with the victim ALIVE afterwards is not stale '
          '(Turbo respawn is fast)',
          not _frame(50.0, 800.0, enemy_future=[(1.0, 300.0)],
                     deaths={'npc_dota_hero_lina': [-0.1]})[SHL])
    check('no further samples at all is NOT stale (lower bound)',
          not _frame(50.0, 800.0, deaths={'npc_dota_hero_lina': [-0.1]})[SHL])
    check('the stale window stays near one sampling cell -- a wide one cannot '
          'tell "already dead" from "died and respawned"',
          max(L.STALE_WINDOWS) <= 3.0 and L.STALE_HEADLINE_S in L.STALE_WINDOWS)
    check('stale is a subset of cell (3)',
          all(_frame(400.0, 800.0, enemy_future=[(1.0, 0.0)],
                     deaths={'npc_dota_hero_lina': [-0.1]})
              ['stale_%s_%s' % (amp, sw)] is False
              for amp in L.AMP_TIERS for sw in L.STALE_WINDOWS))


def test_cross_stream_join_is_underscore_insensitive():
    """GH #303 in this file's own shape.

    Both new columns join the SNAPSHOT stream's hero names against the COMBAT
    LOG's, and those two spellings differ for every hero whose npc name
    concatenates two words.  What closes it here is that this file's `canon`
    (imported from `stayfield_domain`) removes underscores -- it is
    `entities.hkey` under another name.  Swapping in a canon that keeps them
    (e.g. `entities.canon`, the obvious "cleanup") would make Vengeful Spirit,
    Queen of Pain and Anti-Mage read as never dying, silently and in the
    direction that inflates both columns.
    """
    for flat, spaced in (('vengefulspirit', 'vengeful_spirit'),
                         ('queenofpain', 'queen_of_pain'),
                         ('antimage', 'anti_mage')):
        check('canon joins %s / %s' % (flat, spaced),
              L.canon('npc_dota_hero_' + flat) == L.canon('npc_dota_hero_' + spaced))
    check('canon still separates two different heroes',
          L.canon('npc_dota_hero_lion') != L.canon('npc_dota_hero_luna'))


def _frame(enemy_hp, enemy_x, q_level=1, cd=0.0, mp=500.0, lion_level=6,
           allies=0, enemy_alive=True, enemy_future=None, deaths=None,
           ev_horizon='cover'):
    """One synthetic frame driven through the real `scan_game`.

    `enemy_future` is the victim's REAL hp samples after the frame; the default
    (none at all) is what the outcome column must read as SURVIVED.

    `deaths` / `ev_horizon` drive the SECOND witness (the combat-log column,
    2026-08-31T21:xxZ) and the stale-victim column, and they are deliberately
    SEPARATE inputs from `enemy_future`: the whole point of the second column
    is that it does not read the health bar, so a builder that derived one from
    the other could not express the disagreements these tests are about.
    `deaths` is keyed by the name AS THE COMBAT LOG SPELLS IT.
    """
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
    g.by_hero = {'lion': [(0.0, 500.0)],
                 'lina': [(0.0, enemy_hp if enemy_alive else 0.0)]
                 + sorted(enemy_future or [])}
    g.deaths = {}
    for nm, ts in sorted((deaths or {}).items()):
        g.deaths.setdefault(L.canon(nm), []).extend(sorted(ts))
    g.ev_horizon = (max(L.OUTCOME_WINDOWS) + 1.0 if ev_horizon == 'cover'
                    else ev_horizon)
    return L.scan_game(g)[0]


for fn in (test_source_constants, test_mr25_is_tighter, test_upper_bound_direction,
           test_episodes, test_ready_clauses, test_reach, test_outcome_column,
           test_outcome_is_an_upper_bound, test_two_witnesses_are_never_merged,
           test_stale_victims_need_both_halves,
           test_cross_stream_join_is_underscore_insensitive):
    fn()

if fails:
    for f in fails:
        print('FAIL: %s' % f)
    sys.exit(1)
print('ok: lionqdmg_domain checks passed  (corpus checks SKIPPED, not passed)')

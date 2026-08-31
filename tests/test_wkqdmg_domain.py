#!/usr/bin/env python3
"""Runs `wkqdmg_domain.py`'s selfcheck battery from the python suite, and pins
the parts of it that would fail SILENTLY -- i.e. keep printing a plausible
number after the question underneath it changed.

WHY THIS WRAPPER EXISTS.  `tests/run_py_tests.sh` only loops over
`tests/test_*.py`, so a module-level `--selfcheck` that nothing invokes is a
gate that never opens (the GH #243 shape; the same reason
`tests/test_lionqdmg_domain.py` exists).  Note the sibling
`tests/test_wk_qdmg_domain.lua` is a different file with a different job: it
tests the Lua gate, this one tests the measuring tool.

WHAT THIS FILE IS REALLY GUARDING: THE OUTCOME COLUMN'S THREE-WAY SPLIT.
`band_pair` says the shipped claim would have promised a kill the armed claim
refuses.  The outcome column says whether that promised kill ARRIVED anyway,
and it splits three ways on purpose:

    died  a REAL sample at hp <= 0 inside the window -- ANY death, whoever
          dealt it, so an UPPER bound on kills the narrowing could cost
    surv  observed alive at the far edge -- a LOWER bound on free withdrawals
    unk   the samples ran out first -- folded into NEITHER

The two-way version of this column (the shape `lionqdmg_domain.py` uses, where
"no further samples" counts as survived) is not wrong there -- that file's
standing finding is negative and inflating its `net` is the safe direction.
Here it would be wrong, because `surv` is the column that would carry a claim
that this narrowing costs nothing.  `test_unk_is_never_folded` pins exactly
that, and it is the single check most likely to be "simplified" away by a
future reader who notices the third column is usually small.
"""

import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TOOL = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral',
                    'wkqdmg_domain.py')
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
# NOT `'FAIL' not in out`: that idiom passes on an empty battery and on a crash
# before the first line.  Count the greens against the total instead.
n_pass = sum(1 for line in out.splitlines() if line.strip().endswith('PASS'))
check('module selfcheck ran a non-trivial battery', n_pass >= 30)
check('module selfcheck reports every check green',
      ('%d PASS / 0 FAIL' % n_pass) in out)

import wkqdmg_domain as W                                         # noqa: E402


# ---- 2. registered choices, so a silent retune shows up ---------------------
def test_registered_constants():
    check('the outcome ladder is the registered 2/5/10 s one',
          W.OUTCOME_WINDOWS == (2.0, 5.0, 10.0))
    check('the headline window is a rung of that ladder',
          W.OUTCOME_HEADLINE_S in W.OUTCOME_WINDOWS)
    check('the ladder is sorted, so the printed table is not silently unbounded',
          W.OUTCOME_WINDOWS == tuple(sorted(W.OUTCOME_WINDOWS)))
    check('there are exactly three outcomes and unk is one of them',
          W.OUTCOMES == ('died', 'surv', 'unk'))
    check('the sample tolerance stays well under the 1 Hz sample interval',
          0.0 < W.SAMPLE_TOL_S < 0.5)
    check('the impact ladder is the 80/100/120/140 row',
          [W.KV_IMPACT[i] for i in (1, 2, 3, 4)] == [80, 100, 120, 140])
    check('the dot dps ladder is the 20/40/60/80 row',
          [W.KV_DOT_DPS[i] for i in (1, 2, 3, 4)] == [20, 40, 60, 80])


# ---- 3. the lever really is a pure narrowing -------------------------------
def test_narrowing_only():
    """If the armed claim could ever EXCEED the shipped one, every word about
    which leg is interpretable would be wrong, and `band` would stop being a
    straddle of two claims."""
    a = W.lua_anchors()
    check('hero lua still parses', a is not None)
    if a is None:
        return
    for lvl in range(1, 31):
        for q in (1, 2, 3, 4):
            shipped, armed = W.claims(q, lvl, a)
            check('armed never exceeds shipped (q%d lvl%d)' % (q, lvl),
                  armed <= shipped)


# ---- 4. the three-way outcome, on the arithmetic ---------------------------
def test_outcome_three_way():
    HL = W.OUTCOME_HEADLINE_S
    check('a sampled zero inside the window is died',
          W.outcome([(101.0, 40.0), (102.0, 0.0), (105.5, 0.0)], 100.0, HL) == 'died')
    check('observed alive at the far edge is surv',
          W.outcome([(101.0, 40.0), (105.2, 40.0)], 100.0, HL) == 'surv')
    check('samples that stop short of the edge are unk',
          W.outcome([(101.0, 40.0), (102.0, 40.0)], 100.0, HL) == 'unk')
    check('no samples at all is unk', W.outcome([], 100.0, HL) == 'unk')
    check('a sample exactly at t0 is not after t0',
          W.outcome([(100.0, 0.0), (105.5, 40.0)], 100.0, HL) == 'surv')
    check('the window never looks backwards',
          W.outcome([(90.0, 0.0), (105.5, 40.0)], 100.0, HL) == 'surv')
    check('a death past the window is not died there',
          W.outcome([(101.0, 40.0), (105.5, 40.0), (107.0, 0.0)],
                    100.0, HL) != 'died')
    check('the same death is died in the 10 s window',
          W.outcome([(101.0, 40.0), (105.5, 40.0), (107.0, 0.0), (111.0, 0.0)],
                    100.0, 10.0) == 'died')
    check('hp above zero is never a death, however low',
          W.outcome([(101.0, 1.0), (105.5, 1.0)], 100.0, HL) == 'surv')
    check('every outcome is one of the three, for any input',
          all(W.outcome(s, 100.0, w) in W.OUTCOMES
              for w in W.OUTCOME_WINDOWS
              for s in ([], [(101.0, 0.0)], [(101.0, 5.0)],
                        [(90.0, 0.0)], [(120.0, 0.0)])))


def test_unk_is_never_folded():
    """`unk` must not collapse into either neighbour.

    Folding it into `surv` would make `surv` -- the column that would carry
    "this narrowing withdraws nothing real" -- an assumption instead of an
    observation.  Folding it into `died` would do the mirror damage.  A corpus
    where recording stops mid-window is the normal case at game end, so this is
    not a hypothetical."""
    short = [(101.0, 40.0), (102.0, 40.0)]
    check('a truncated tail is unk, not surv',
          W.outcome(short, 100.0, 5.0) == 'unk')
    check('a truncated tail is unk, not died',
          W.outcome(short, 100.0, 5.0) != 'died')
    check('the same tail IS surv against a window it does cover',
          W.outcome(short, 100.0, 2.0) == 'surv')


# ---- 5. the wiring: which entity's samples, measured from which t0 ---------
def _cast(after, tgt_idx=None):
    """One rank-1 band_pair cast at t=100 through the REAL scan()."""
    snaps = [
        {"t": 99.5, "hero": W.WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9,
         "level": 5, "abilities": [{"name": W.QNAME, "level": 1}]},
        {"t": 99.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
         "hp": 110, "hp_pct": 0.5, "level": 5},
        {"t": 100.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
         "hp": 108, "hp_pct": 0.5, "level": 5}]
    if tgt_idx is not None:
        snaps[1]["idx"] = snaps[2]["idx"] = tgt_idx
    for row in after:
        s = {"t": row[0], "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": row[1], "hp_pct": 0.1, "level": 5}
        if len(row) > 2:
            s["idx"] = row[2]
        snaps.append(s)
    tl = {"events": [{"t": 100.0, "type": "ABILITY", "inflictor": W.QNAME,
                      "target": "npc_dota_hero_lion", "target_hero": True}],
          "snapshots": snaps}
    rows, _ = W.scan(tl, W.lua_anchors(), 0.25, 6.0)
    return rows[0] if rows else None


def test_outcome_wiring():
    alive = [(t, 60) for t in (101.5, 102.5, 103.5, 104.5, 105.5, 106.5)]
    r = _cast(alive)
    check('the fixture really is the case the column is about',
          r is not None and r['band'] and r['band_pair'])
    check('every window gets a verdict on every row',
          r is not None and all(r['out_%s' % w] in W.OUTCOMES
                                for w in W.OUTCOME_WINDOWS))
    check('a surviving target reads surv end to end',
          r is not None and r['out_5.0'] == 'surv')
    dead = _cast([(101.5, 20), (102.5, 0), (103.5, 0), (104.5, 0), (105.5, 0)])
    check('a dying target reads died end to end',
          dead is not None and dead['out_5.0'] == 'died')
    # The window is (100.05, 105.05] at a 1 Hz clock, so the trajectory opens
    # with the straddling `after` frame (t=100.5, hp 108 -- the one `band_pair`
    # itself is read on) and STOPS before the t=105.5 sample.  Both ends matter:
    # dropping the first would hide the frame the verdict rests on, and keeping
    # the last would print a sample the window does not cover.
    check('the trajectory is real samples, cut at the window it claims',
          dead is not None and dead['traj'] == [108, 20, 0, 0, 0])
    check('the outcome is measured from the CAST, not from the frame read',
          # the frame read is t=99.5; a death at 104.8 is inside 5 s of the
          # cast (100.0) either way, but a death at 105.4 is only inside if
          # t0 is the frame -- it must NOT be
          _cast([(101.5, 40), (105.4, 0), (106.0, 0)])['out_5.0'] != 'died')


def test_identity_lock():
    """LIMIT 9: an illusion's corpse is not the target's."""
    mixed = [(101.5, 60, 7), (102.5, 0, 9), (103.5, 60, 7),
             (104.5, 60, 7), (105.5, 60, 7), (106.5, 60, 7)]
    check('a hp-0 sample under a different idx does not make the target died',
          _cast(mixed, tgt_idx=7)['out_5.0'] == 'surv')
    check('the same corpse DOES count when it is the locked entity',
          _cast([(101.5, 60, 9), (102.5, 0, 9)], tgt_idx=9)['out_5.0'] == 'died')
    check('an idx-less timeline still works (hand-built fixtures)',
          _cast([(101.5, 0)])['out_5.0'] == 'died')


# ---- 6. end to end: the printed table, and its armed-leg disclaimer --------
def test_printed_table():
    """The armed-leg rows must stay printed AND stay marked uninterpretable.

    铁律 4(i-a) says every reading appears in all four cells; the structural
    argument says only the baseline cells can be read.  A future edit that
    drops the marker leaves four cells that invite exactly the difference the
    header forbids, and nothing else in the suite would notice."""
    tmp = tempfile.mkdtemp(prefix='wkqdmg_')
    alive = [(t, 60) for t in (101.5, 102.5, 103.5, 104.5, 105.5, 106.5)]
    names = {'g_armed': (alive, '1'), 'g_base': ([(101.5, 20), (102.5, 0),
                                                  (103.5, 0), (104.5, 0),
                                                  (105.5, 0)], '0')}
    legs = []
    for base, (after, armed) in names.items():
        snaps = [
            {"t": 99.5, "hero": W.WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9,
             "level": 5, "abilities": [{"name": W.QNAME, "level": 1}]},
            {"t": 99.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": 110, "hp_pct": 0.5, "level": 5, "idx": 3},
            {"t": 100.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": 108, "hp_pct": 0.5, "level": 5, "idx": 3}]
        snaps += [{"t": t, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
                   "hp": hp, "hp_pct": 0.1, "level": 5, "idx": 3}
                  for t, hp in after]
        json.dump({"events": [{"t": 100.0, "type": "ABILITY",
                               "inflictor": W.QNAME,
                               "target": "npc_dota_hero_lion",
                               "target_hero": True}],
                   "snapshots": snaps},
                  open(os.path.join(tmp, base + '.json'), 'w'))
        legs.append('%s\t%s\tab' % (base, armed))
    legs_path = os.path.join(tmp, 'legs.tsv')
    open(legs_path, 'w').write('\n'.join(legs) + '\n')
    r = subprocess.run([sys.executable, TOOL,
                        os.path.join(tmp, 'g_armed.json'),
                        os.path.join(tmp, 'g_base.json'),
                        '--legs', legs_path, '--mr', '0.25'],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    text = r.stdout.decode()
    check('the run exits 3 -- an armed-leg HIT is still a finding',
          r.returncode == W.EXIT_FINDINGS)
    check('the outcome table is printed at all', 'died' in text and 'surv' in text)
    check('the armed leg is marked uninterpretable', 'NO (armed leg' in text)
    check('BOTH armed cells carry the marker, once each (铁律 4(i-a): all four '
          'cells are printed even when a stratum is empty)',
          text.count('NO (armed leg') == 2)
    check('no baseline row carries the armed-leg marker',
          all('NO (armed leg' not in ln for ln in text.splitlines()
              if ' baseline ' in ln))
    check('unk is named in the printed legend, not silently dropped',
          'unk' in text)
    body = [ln.split() for ln in text.splitlines()
            if ln.startswith('ab ') or ln.startswith('ab' + ' ' * 4)]
    rows = [c for c in body if len(c) >= 7 and c[2] in ('2.0', '5.0', '10.0')]
    check('all three rungs are printed for both legs of the ab stratum',
          len(rows) == 6)
    armed_rows = [c for c in rows if c[1] == 'armed']
    base_rows = [c for c in rows if c[1] == 'baseline']
    check('the armed leg reads surv at the headline window',
          any(c[2] == '5.0' and c[5] == '1' for c in armed_rows))
    check('the baseline leg reads died at the headline window',
          any(c[2] == '5.0' and c[4] == '1' for c in base_rows))
    check('died + surv + unk never exceeds band_pair',
          all(int(c[4]) + int(c[5]) + int(c[6]) <= int(c[3]) for c in rows))
    # --per-cast prints EVERY cast, so a cast nowhere near the band must not be
    # labelled as one.  Until 2026-08-31 an ehp-931 cast -- five times the
    # shipped claim -- printed "band(before only)".
    r2 = subprocess.run([sys.executable, TOOL,
                         os.path.join(tmp, 'g_armed.json'),
                         '--legs', legs_path, '--mr', '0.25', '--per-cast'],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    check('a band_pair cast is still labelled BAND_PAIR under --per-cast',
          'BAND_PAIR' in r2.stdout.decode())
    far = [{"t": 99.5, "hero": W.WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9,
            "level": 5, "abilities": [{"name": W.QNAME, "level": 1}]}]
    far += [{"t": t, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": 700, "hp_pct": 0.9, "level": 5, "idx": 3}
            for t in (99.5, 100.5, 101.5, 105.5)]
    json.dump({"events": [{"t": 100.0, "type": "ABILITY", "inflictor": W.QNAME,
                           "target": "npc_dota_hero_lion", "target_hero": True}],
               "snapshots": far}, open(os.path.join(tmp, 'g_far.json'), 'w'))
    open(legs_path, 'a').write('g_far\t0\tab\n')
    r3 = subprocess.run([sys.executable, TOOL, os.path.join(tmp, 'g_far.json'),
                         '--legs', legs_path, '--mr', '0.25', '--per-cast'],
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    far_out = r3.stdout.decode()
    check('a cast far outside the band is printed as such',
          'not in band' in far_out)
    check('a cast far outside the band is NOT labelled a band cast',
          'band(before only)' not in far_out and 'BAND_PAIR' not in far_out)


# ---- 7. sweep -> legs: the join that could label half the corpus backwards --
def _sweep_dir(games):
    """A minimal sweep_run.sh output tree.  `games` is a list of
    (name, armed_side, wk_team_or_None)."""
    d = tempfile.mkdtemp(prefix='wkqdmg_sweep_')
    os.mkdir(os.path.join(d, 'timelines'))
    with open(os.path.join(d, 'games_manifest.jsonl'), 'w') as man:
        for name, side, wk_team in games:
            man.write(json.dumps({'game': name, 'cand': 'odbuild,wkqdmg,lionqdmg',
                                  'seed': '1', 'side': side}) + '\n')
            teams = {'npc_dota_hero_lion': 2, 'npc_dota_hero_zuus': 3}
            if wk_team is not None:
                teams[W.WK] = wk_team
            json.dump({'game': {'teams': teams}, 'events': [], 'snapshots': []},
                      open(os.path.join(d, 'timelines',
                                        name + '.timeline.json'), 'w'))
    return d


def test_sweep_leg_join():
    # radiant is team 2, dire is team 3.  The manifest's `side` is the side the
    # CANDIDATE string was armed on; this tool reads Wraith King, so the game is
    # an armed sample only when WK's own team IS that side.  Getting this join
    # backwards is the failure that still prints a full, plausible table.
    d = _sweep_dir([('g1', 'radiant', 2),      # WK radiant, radiant armed
                    ('g2', 'radiant', 3),      # WK dire,    radiant armed
                    ('g3', 'dire', 3),         # WK dire,    dire armed
                    ('g4', 'dire', 2)])        # WK radiant, dire armed
    paths, legs, rows = W.from_sweeps([d])
    check('all four games are kept', len(paths) == 4 and len(legs) == 4)
    check('WK on the armed side is an ARMED sample',
          legs['g1.timeline'] == (True, 'ab') and legs['g3.timeline'] == (True, 'ba'))
    check('WK on the other side is a BASELINE sample',
          legs['g2.timeline'] == (False, 'ab') and legs['g4.timeline'] == (False, 'ba'))
    check('the layer follows the ARMED side, not Wraith King',
          all(r['layer'] == ('ab' if r['side'] == 'radiant' else 'ba') for r in rows))


def test_sweep_refusals():
    """Every one of these must be exit 2 (could not run), never a quiet 0 with
    an empty table -- GH #171's whole vocabulary."""
    none_wk = _sweep_dir([('g1', 'radiant', None)])
    try:
        W.from_sweeps([none_wk])
        check('a corpus with no Wraith King refuses', False)
    except W.SweepRefused:
        check('a corpus with no Wraith King refuses', True)
    # a draft without WK is EXCLUDED from the legs but still audited as a row
    mixed = _sweep_dir([('g1', 'radiant', 2), ('g2', 'radiant', None)])
    paths, legs, rows = W.from_sweeps([mixed])
    check('a WK-less game is excluded from the legs, not counted as a zero',
          len(paths) == 1 and len(legs) == 1 and len(rows) == 2)
    check('the WK-less game is still shown in the audit rows',
          any(r['wk_team'] == '-' for r in rows))
    # a wave that never armed this id has no armed leg to read
    d = _sweep_dir([('g1', 'radiant', 2)])
    man = os.path.join(d, 'games_manifest.jsonl')
    open(man, 'w').write(json.dumps({'game': 'g1', 'cand': 'odbuild,lionqdmg',
                                     'seed': '1', 'side': 'radiant'}) + '\n')
    try:
        W.from_sweeps([d])
        check('a wave without wkqdmg in its arm string refuses', False)
    except W.SweepRefused:
        check('a wave without wkqdmg in its arm string refuses', True)
    # two different arm strings are two different trees
    a = _sweep_dir([('g1', 'radiant', 2)])
    b = _sweep_dir([('g2', 'dire', 3)])
    open(os.path.join(b, 'games_manifest.jsonl'), 'w').write(
        json.dumps({'game': 'g2', 'cand': 'wkqdmg,somethingelse',
                    'seed': '2', 'side': 'dire'}) + '\n')
    try:
        W.from_sweeps([a, b])
        check('mixed arm strings refuse rather than pool', False)
    except W.SweepRefused:
        check('mixed arm strings refuse rather than pool', True)
    # and the refusal really is exit 2 at the process boundary
    r = subprocess.run([sys.executable, TOOL, '--sweep', none_wk],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    check('a refused sweep exits 2, not 0', r.returncode == W.EXIT_REFUSED)
    check('the refusal says REFUSED', 'REFUSED' in r.stdout.decode())


for fn in (test_registered_constants, test_narrowing_only, test_outcome_three_way,
           test_unk_is_never_folded, test_outcome_wiring, test_identity_lock,
           test_printed_table, test_sweep_leg_join, test_sweep_refusals):
    fn()

if fails:
    for f in fails:
        print('FAIL: %s' % f)
    sys.exit(1)
print('ok: wkqdmg_domain checks passed  (corpus checks SKIPPED, not passed)')

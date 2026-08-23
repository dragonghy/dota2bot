#!/usr/bin/env python3
"""`seed_draft.py --assert-carrier` must refuse a wave whose draft cannot carry
the id being armed -- and must refuse LOUDLY when it checked nothing at all.

WHY (director ruling 2026-08-23 16:xxZ, test_set.md AV.3).  Two gates guard a
wave launch and they fail on different axes:

  * `check_armed_wiring.py` -- does the id have a call site ON THE PINNED TREE?
  * this one              -- does the wave's draft ever produce the hero (and
                             the position) that call site needs?

Both absences are byte-level no-ops that report as "no effect", and neither
raises a counter anywhere in the launch path.  This file's subject already cost
one wave: `seed_draft.py`'s own header records 224 mirror games launched for
`axebuyblink` that drafted zero Axe.

The measured case pinned here is `cmboots`, which rewrites
`sRoleItemsBuyList['pos_5']` and nothing else.  On the standing chain seed set
888/895/896/906 Crystal Maiden is drafted in 4 of 4 seeds but at pos 5 in only
3 -- seed 888 puts her at pos 4, where the id is inert.  A presence-only check
would have called that 4/4.  On the proposed axe+lion set 974/986/1024 she is
absent from all three, which is a wave that buys nothing.

The failure directions are not symmetric, same as the wiring gate:
  * TOO TIGHT (a typo'd hero reported ABSENT) cancels a launch for nothing.
    Hence exit 2 + "not in pool", never exit 1.  Cases 6-7.
  * TOO LOOSE (absent carrier certified, or zero seeds treated as a pass)
    spends $1.5 measuring nothing.  Cases 3-5, and mutations M1-M4.
"""
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'tools', 'batch_test', 'soak', 'seed_draft.py')
sys.path.insert(0, os.path.dirname(SCRIPT))
import seed_draft  # noqa: E402

failures = []
checked = []


def check(name, cond, detail=''):
    checked.append(name)
    if cond:
        print('  ok   %s' % name)
    else:
        print('  FAIL %s %s' % (name, detail))
        failures.append(name)


def run(args):
    """Run the real script; return (exit_code, stdout+stderr)."""
    p = subprocess.run([sys.executable, SCRIPT] + args, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def gate(seeds, spec):
    """Call the gate in-process and capture its lines."""
    pool = seed_draft.load_pool()
    terms = seed_draft.parse_carrier_terms(spec, pool)
    buf = io.StringIO()
    code = seed_draft.assert_carrier(seeds, terms, pool, out=buf)
    return code, buf.getvalue()


# --- 1. the port itself still reproduces real rosters -------------------------
# Everything below is derived from `draft()`; if that regressed, every carrier
# verdict here would be confidently wrong.
code, out = run(['--selftest'])
check('selftest still passes', code == 0 and 'PASS' in out, out.strip())

# --- 2-3. the measured cmboots case ------------------------------------------
code, out = gate([888, 895, 896, 906], 'crystal_maiden:5')
check('chain set: gate passes', code == 0, out)
check('chain set: PARTIAL 3 of 4, not 4 of 4',
      'seeds=4 satisfied=3 verdict=PARTIAL' in out, out)
check('chain set: 888 named as the non-carrier',
      re.search(r'CARRIER seed=888 term=crystal_maiden:5 present=yes side=dire pos=4 satisfied=no', out),
      out)
check('chain set: carriers listed by seed number',
      'carriers=895,896,906' in out, out)

# presence-only is a different question and must answer differently
code, out = gate([888, 895, 896, 906], 'crystal_maiden')
check('presence-only term is FULL on the same seeds',
      code == 0 and 'seeds=4 satisfied=4 verdict=FULL' in out, out)

# --- 4. the wave that would have bought nothing -------------------------------
code, out = gate([974, 986, 1024], 'crystal_maiden:5')
check('axe+lion set: gate refuses (exit 1)', code == 1, out)
check('axe+lion set: verdict ABSENT with zero carriers',
      'satisfied=0 verdict=ABSENT carriers=none' in out, out)

# and the set does carry what it was chosen for
code, out = gate([974, 986, 1024], 'axe,lion')
check('axe+lion set: carries axe and lion (FULL, exit 0)',
      code == 0 and out.count('verdict=FULL') == 2, out)

# --- 5. nothing checked is not a pass ----------------------------------------
code, out = gate([], 'axe')
check('no seeds => exit 2, not 0', code == 2, out)
check('no seeds => says so in the line', 'nothing checked' in out, out)

# one term absent poisons the whole gate even when the others are carried
code, out = gate([974, 986, 1024], 'axe,crystal_maiden:5')
check('one ABSENT term fails the gate even beside a FULL one', code == 1, out)

# --- 6-7. loud in the right direction on bad input ----------------------------
code, out = run(['888', '--assert-carrier', 'crystal_maidne'])
check('typo hero => exit 2 (never 1)', code == 2, out)
check('typo hero => names the term', 'not in pool: crystal_maidne' in out, out)

code, out = run(['888', '--assert-carrier', 'crystal_maiden:9'])
check('position out of 1-5 => exit 2', code == 2, out)

code, out = run(['888', '--assert-carrier', ','])
check('empty term list => exit 2', code == 2, out)

# --- 8. the CLI wiring, not just the function ---------------------------------
code, out = run(['888', '895', '896', '906', '--assert-carrier', 'crystal_maiden:5'])
check('CLI: chain set exit 0 with the PARTIAL summary',
      code == 0 and 'verdict=PARTIAL' in out and 'CARRIER_GATE terms=1 seeds=4 exit=0' in out, out)

code, out = run(['974', '986', '1024', '--assert-carrier', 'crystal_maiden:5'])
check('CLI: absent carrier exit 1', code == 1 and 'verdict=ABSENT' in out, out)

# the flag must not disturb the plain expansion path
code, out = run(['888'])
check('plain expansion unchanged by the new flag',
      code == 0 and 'pos4=crystal_maiden' in out and 'CARRIER' not in out, out)

# --- 9. mutations: each one is a way this gate could certify an empty wave -----
MUTATIONS = [
    # (name, pattern, replacement) -- applied to a copy of the script
    ('M1 absent carrier returns 0',
     '            worst = max(worst, 1)', '            worst = max(worst, 0)'),
    ('M2 zero seeds treated as a pass',
     '        return 2\n\n    worst = 0', '        return 0\n\n    worst = 0'),
    ('M3 position half ignored',
     '            ok = pos is None or drafted_pos == pos', '            ok = True'),
    ('M4 unknown hero reported instead of refused',
     '            raise ValueError("not in pool: %s" % hero)', '            continue'),
]

with open(SCRIPT) as f:
    ORIGINAL = f.read()

tmpdir = tempfile.mkdtemp(prefix='seed_draft_mut_')
try:
    shutil.copy(os.path.join(os.path.dirname(SCRIPT), 'hero_pool.txt'), tmpdir)
    mutant = os.path.join(tmpdir, 'seed_draft.py')

    def run_mutant(args):
        p = subprocess.run([sys.executable, mutant] + args, capture_output=True, text=True)
        return p.returncode, p.stdout + p.stderr

    # the assertions each mutation must break, in the same order as MUTATIONS
    def probe(i):
        if i == 0:
            return run_mutant(['974', '986', '1024', '--assert-carrier', 'crystal_maiden:5'])[0] == 1
        if i == 1:
            return run_mutant(['--assert-carrier', 'axe'])[0] == 2
        if i == 2:
            c, o = run_mutant(['888', '895', '896', '906', '--assert-carrier', 'crystal_maiden:5'])
            return c == 0 and 'satisfied=3 verdict=PARTIAL' in o
        # a typo BESIDE a real term: dropping it silently would leave one good
        # term standing and the gate would pass.  Probing with the typo alone
        # cannot see this -- the "no carrier terms given" guard catches the
        # empty list and returns 2 for the wrong reason.
        return run_mutant(['888', '--assert-carrier', 'axe,crystal_maidne'])[0] == 2

    for i, (name, pat, rep) in enumerate(MUTATIONS):
        check('%s: pattern is present to mutate' % name, pat in ORIGINAL,
              'source drifted -- this mutation no longer tests anything')
        with open(mutant, 'w') as f:
            f.write(ORIGINAL.replace(pat, rep, 1))
        check('%s: caught' % name, not probe(i), 'mutant survived')

    # restore and prove the restoration is byte-identical
    with open(mutant, 'w') as f:
        f.write(ORIGINAL)
    check('restored copy is byte-identical', open(mutant).read() == ORIGINAL)
    check('restored copy still passes its probes',
          all(probe(i) for i in range(len(MUTATIONS))))
finally:
    shutil.rmtree(tmpdir, ignore_errors=True)

print('\n%d checks, %d failures' % (len(checked), len(failures)))
sys.exit(1 if failures else 0)

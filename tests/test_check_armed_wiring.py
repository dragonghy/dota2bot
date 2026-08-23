#!/usr/bin/env python3
"""`check_armed_wiring.py` must answer "is this id wired ON THAT TREE" -- and it
must fail in the LOUD direction when it is unsure.

WHY (director ruling 2026-08-23, batch-desk 10:15Z section 7).  The incident
this tool is built from: `campgrade`'s only call site landed in `498bad4`, the
wave pinned `7159ff3`, and arming the id on that tree would have been a
byte-level no-op reported as "no effect".  Nothing in the launch path counts an
absence, so the absence has to be made into an exit code.

Two ways this tool could itself be wrong, and only one of them is survivable:

  * TOO TIGHT -- misses `J.IsSoakCandidate( 'x' )` because of the spaces, and
    reports a wiring collapse that is not happening.  Costs a round.  Case 1.
  * TOO LOOSE -- counts the id where it appears in a COMMENT, and certifies a
    wave that measures nothing.  Ships.  Case 2, and it is the one that made
    this a script instead of a table.

The corpus is a real temporary git repo with two real commits, because the load
bearing part is `git grep <ref>` -- checking the working tree would pass while
the pinned tree was broken, which is the whole bug.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, 'tools', 'batch_test', 'check_armed_wiring.py')

failures = []


def check(name, cond, detail=''):
    if cond:
        print('  ok   %s' % name)
    else:
        print('  FAIL %s %s' % (name, detail))
        failures.append(name)


def git(repo, *args):
    p = subprocess.run(['git', '-c', 'user.email=t@t', '-c', 'user.name=t']
                       + list(args), cwd=repo, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError('git %s failed: %s' % (' '.join(args), p.stderr))
    return p.stdout


def run(repo, ref, cand):
    p = subprocess.run([sys.executable, SCRIPT, '--repo', repo,
                        '--ref', ref, '--cand', cand],
                       capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def write(repo, rel, text):
    path = os.path.join(repo, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as fh:
        fh.write(text)


# The gate helper as this repo actually writes it: spaces inside the parens,
# and -- the trap -- a comment naming the very call it is about to make.
LANEFIX = """
function J.IsLaneFixOn( sub )
\treturn J.IsSoakCandidate( 'lanefix' ) or J.IsSoakCandidate( 'lf_' .. sub )
end
-- Gated turbo + the per-fix id 'lf_ghost' (J.IsSoakCandidate('ghost')); this
-- COMMENT is the trap -- a substring search counts it and certifies a wave
-- that measures nothing.
function J.Rescue( bot )
\tif not J.IsLaneFixOn( 'rescue' ) then return nil end
end
function J.Alpha( bot )
\tif not J.IsSoakCandidate( 'alpha' ) then return false end
end
function J.Beta( bot )
\tif not J.IsSoakCandidate( "beta" ) then return false end
end
"""

tmp = tempfile.mkdtemp(prefix='wiring_')
try:
    git(tmp, 'init', '-q')
    write(tmp, 'bots/FunLib/jmz_func.lua', LANEFIX)
    # A call site OUTSIDE bots//game/ must not count: the game never loads it.
    write(tmp, 'tools/whatever.py', "J.IsSoakCandidate( 'toolonly' )\n")
    git(tmp, 'add', '-A')
    git(tmp, 'commit', '-qm', 'c1')
    C1 = git(tmp, 'rev-parse', 'HEAD').strip()

    # The campgrade shape, exactly: the id's ONLY call site arrives in a later
    # commit, in a different file.
    write(tmp, 'bots/mode_farm_generic.lua',
          "J.Site.RefreshCamp(bot, J.IsModeTurbo() and "
          "J.IsSoakCandidate('campish'))\n")
    git(tmp, 'add', '-A')
    git(tmp, 'commit', '-qm', 'c2')
    C2 = git(tmp, 'rev-parse', 'HEAD').strip()

    print('case 1: the SPACED literal is the one the source actually writes')
    rc, out, err = run(tmp, C1, 'alpha')
    check('J.IsSoakCandidate( \'alpha\' ) reads WIRED (not a tight-regex false alarm)',
          rc == 0 and 'alpha' in out and 'UNWIRED' not in out, '(rc=%d, out=%r)' % (rc, out))
    rc, out, err = run(tmp, C1, 'beta')
    check('double-quoted literal reads WIRED', rc == 0 and 'UNWIRED' not in out,
          '(rc=%d, out=%r)' % (rc, out))

    print('case 2: a COMMENT is not a call site (the direction that ships)')
    rc, out, err = run(tmp, C1, 'ghost')
    check('an id that appears only in a comment -> UNWIRED, exit 1',
          rc == 1 and 'ghost' in out and 'UNWIRED' in out, '(rc=%d, out=%r)' % (rc, out))

    print('case 3: the indirect lanefix form resolves, so 0 needs no allowlist')
    rc, out, err = run(tmp, C1, 'lf_rescue')
    check('lf_rescue -> form=lanefix via J.IsLaneFixOn( \'rescue\' ), exit 0',
          rc == 0 and 'lanefix' in out, '(rc=%d, out=%r)' % (rc, out))
    rc, out, err = run(tmp, C1, 'lf_nosuch')
    check('lf_<sub> with no J.IsLaneFixOn site -> UNWIRED, exit 1',
          rc == 1 and 'UNWIRED' in out, '(rc=%d, out=%r)' % (rc, out))

    print('case 4: kill the dispatcher and every lf_* id dies at once')
    write(tmp, 'bots/FunLib/jmz_func.lua',
          LANEFIX.replace("or J.IsSoakCandidate( 'lf_' .. sub )", ''))
    git(tmp, 'add', '-A')
    git(tmp, 'commit', '-qm', 'c3-no-dispatch')
    C3 = git(tmp, 'rev-parse', 'HEAD').strip()
    rc, out, err = run(tmp, C3, 'lf_rescue')
    check('call site alive but \'lf_\' .. sub gone -> NO-DISPATCH, exit 1',
          rc == 1 and 'NO-DISPATCH' in out, '(rc=%d, out=%r)' % (rc, out))
    rc, out, err = run(tmp, C1, 'lf_rescue')
    check('...and the SAME id on the earlier ref is still wired (ref-scoped)',
          rc == 0, '(rc=%d, out=%r)' % (rc, out))

    print('case 5: THE INCIDENT -- wiring newer than the pinned ref')
    rc, out, err = run(tmp, C1, 'alpha,campish')
    check('campish UNWIRED on the tree that predates its call site, exit 1',
          rc == 1 and 'campish' in out and 'UNWIRED' in out, '(rc=%d, out=%r)' % (rc, out))
    check('the message names the fix (pin a newer tree / drop the id)',
          'pin a newer tree' in out, '(out=%r)' % out[-400:])
    rc, out, err = run(tmp, C2, 'alpha,campish')
    check('same string on the tree that HAS the call site -> exit 0',
          rc == 0 and 'all 2 armed ids wired' in out, '(rc=%d, out=%r)' % (rc, out))

    print('case 6: a call site outside bots//game/ does not count')
    rc, out, err = run(tmp, C2, 'toolonly')
    check('an id wired only under tools/ -> UNWIRED, exit 1',
          rc == 1 and 'UNWIRED' in out, '(rc=%d, out=%r)' % (rc, out))

    print('case 7: an unusable input is never a pass')
    rc, out, err = run(tmp, 'deadbeefdeadbeef', 'alpha')
    check('a ref that does not exist -> exit 2, NOT "0 wired"',
          rc == 2 and 'all 1 armed ids wired' not in out, '(rc=%d, err=%r)' % (rc, err[:200]))
    rc, out, err = run(tmp, C2, '   ')
    check('an empty armed string -> exit 2', rc == 2, '(rc=%d)' % rc)

    print('case 8: a duplicated id is reported (it inflates the count check)')
    rc, out, err = run(tmp, C1, 'alpha,alpha')
    check('duplicate id named in the output', 'DUPLICATED' in out and 'alpha' in out,
          '(out=%r)' % out[:300])
finally:
    shutil.rmtree(tmp, ignore_errors=True)

print('\n%d checks failed' % len(failures))
sys.exit(1 if failures else 0)

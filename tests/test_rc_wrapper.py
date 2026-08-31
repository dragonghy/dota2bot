#!/usr/bin/env python3
"""Pins `tools/agent/rc.sh` -- the mechanical remedy for evidence discipline 3.

WHY THIS FILE EXISTS.  Discipline 3 ("never measure an exit code through a
pipe") recurred five times as prose and a sixth time after the prose became a
loadable skill, which is what pre-registered the ruling that the remedy has to
be MECHANICAL.  `rc.sh` is that remedy, and this file pins the two properties
that do the work.  Neither is visible by reading the script casually, and both
can be destroyed by an edit that looks like a tidy-up:

  1. THE BANNER IS THE LAST LINE.  That is the entire reason the wrapper beats
     the habit instead of merely forbidding it: `rc.sh cmd | tail -5` still
     shows the true code IN THE TEXT, at the exact moment `$?` stops being able
     to.  Move the banner above the tail output -- which reads like better
     layout -- and the wrapper silently stops covering the case it was built
     for.  Pinned by piping it, not by describing it.

  2. `"$@" > "$log" 2>&1` AND `rc=$?` ARE ADJACENT.  Any statement inserted
     between them overwrites `$?` -- the same defect one layer down, inside the
     fix for it.  Pinned structurally on the source, because an inserted
     `printf` would leave every behavioural test green (printf succeeds, so the
     code it reports would be 0 exactly when the command failed... and 0 is the
     answer nobody double-checks).

  3. THE REFUSAL.  Found the same round, in the same family: a `tests/*.lua`
     detector ends `return tests`, so `lua5.1 tests/test_x.lua` loads a module,
     asserts nothing, and exits 0.  A bare exit code cannot save you there --
     the 0 is honest -- so the wrapper refuses the invocation and names the
     runner.  It was caught by a surviving mutant (discipline 2), not by
     reading.

Exit vocabulary matches run_py_tests.sh: 2 = could not read its inputs (did NOT
run), 1 = ran and the answer was wrong, 0 = clean.
"""

import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RC = os.path.join(ROOT, 'tools', 'agent', 'rc.sh')

fails = []


def ok(name, cond, why=''):
    print('%-68s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.exists(RC):
    print('could not read %s' % RC)
    sys.exit(2)

with open(RC, encoding='utf-8') as fh:
    src = fh.read()


def run(args, shell_cmd=None):
    """Run rc.sh bare (discipline 3: no pipe between the command and its code)."""
    if shell_cmd is not None:
        p = subprocess.run(['bash', '-c', shell_cmd], cwd=ROOT,
                           capture_output=True, text=True)
    else:
        p = subprocess.run(['bash', RC] + args, cwd=ROOT,
                           capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def banner_of(out):
    lines = [ln for ln in out.splitlines() if ln.strip()]
    return lines[-1] if lines else ''


# --- 1. exit-code passthrough ---------------------------------------------
# Explicitly asserted as `returncode ==`, which is discipline 3's own
# prescription for a test.
for code in (0, 1, 2, 3, 7):
    rc, out, _ = run(['sh', '-c', 'exit %d' % code])
    ok('exit %d: wrapper exits with the command\'s code' % code, rc == code,
       'got %d' % rc)
    ok('exit %d: banner carries the code' % code,
       'RC_EXIT=%d' % code in banner_of(out), banner_of(out))

# --- 2. the banner is the LAST line, and survives a pipe -------------------
rc, out, _ = run(['sh', '-c', 'echo hello; exit 3'])
ok('banner is the last non-blank line', banner_of(out).startswith('RC_EXIT=3'),
   banner_of(out))

# THE case this file exists for: pipe the wrapper to tail.  `$?` is now tail's
# (0), and the truth has to be in the text or it is gone.
prc, pout, _ = run(None, shell_cmd='bash %s sh -c "echo hi; exit 3" | tail -1'
                   % RC)
ok('piped to `tail -1`: the shell\'s own status is tail\'s, i.e. useless',
   prc == 0, 'got %d -- if this is 3 the test no longer models the defect' % prc)
ok('piped to `tail -1`: the TRUE code survives in the text',
   'RC_EXIT=3' in pout, repr(pout))

prc, pout, _ = run(None, shell_cmd='bash %s sh -c "exit 5" | tail -3' % RC)
ok('piped to `tail -3`: the TRUE code survives in the text',
   'RC_EXIT=5' in pout, repr(pout))

# --- 3. long output: the tail is short, the banner still last, log complete -
rc, out, _ = run(['-n', '5', 'sh', '-c',
                  'i=1; while [ $i -le 500 ]; do echo line$i; i=$((i+1)); done; exit 4'])
ok('long output: exits 4', rc == 4, 'got %d' % rc)
ok('long output: banner still the last line',
   banner_of(out).startswith('RC_EXIT=4'), banner_of(out))
ok('long output: -n 5 kept the shown tail short', out.count('line') <= 12,
   '%d occurrences -- the whole point is context economy' % out.count('line'))
logline = [ln for ln in out.splitlines() if ln.startswith('RC_LOG:')]
ok('long output: RC_LOG names a real file', bool(logline) and
   os.path.exists(logline[0].split()[1]), logline)
if logline and os.path.exists(logline[0].split()[1]):
    with open(logline[0].split()[1], encoding='utf-8') as fh:
        body = fh.read()
    ok('long output: the log keeps ALL 500 lines (the tail is a view, not the data)',
       body.count('\n') == 500, '%d' % body.count('\n'))

# --- 4. the two look-alike codes are NAMED --------------------------------
rc, out, _ = run(['sh', '-c', 'kill -TERM $$'])
ok('SIGTERM: exits 143', rc == 143, 'got %d' % rc)
ok('SIGTERM: output says 143 is DID NOT RUN, not clean',
   '143' in out and 'DID NOT RUN' in out.upper(), out[-300:])

rc, out, _ = run(['python3', '-c',
                  'import argparse,sys\n'
                  'p=argparse.ArgumentParser()\n'
                  'p.add_argument("--cand",required=True)\n'
                  'p.parse_args()'])
ok('argparse missing flag: exits 2', rc == 2, 'got %d' % rc)
ok('argparse missing flag: output says 2 is not a pass',
   'argparse' in out and 'Not a pass' in out, out[-300:])

# --- 5. the refusal (the second trap, same family) ------------------------
with tempfile.TemporaryDirectory() as td:
    mod = os.path.join(td, 'test_fake_detector.lua')
    with open(mod, 'w', encoding='utf-8') as fh:
        fh.write('local tests = {}\n-- a trailing comment\n\nreturn tests\n')
    rc, out, err = run(['lua5.1', mod])
    ok('module .lua: REFUSED with could-not-run 2', rc == 2, 'got %d' % rc)
    ok('module .lua: banner says REFUSED', 'REFUSED' in banner_of(out),
       banner_of(out))
    ok('module .lua: names the runner that actually runs the tests',
       'run_tests.lua' in err, err[-300:])

    # Discipline 2: the refusal must DISCRIMINATE, so build the case it must
    # let through.  A self-running .lua has no trailing `return <name>`.
    script = os.path.join(td, 'selfrunning.lua')
    with open(script, 'w', encoding='utf-8') as fh:
        fh.write('os.exit(6)\n')
    rc, out, _ = run(['lua5.1', script])
    ok('self-running .lua: NOT refused, real code passed through', rc == 6,
       'got %d -- a refusal that fires on everything is not a check' % rc)

ok('run_tests.lua is never refused (it is the runner)',
   run(['lua5.1', 'tests/run_tests.lua', 'test_rc_wrapper_nonexistent.lua'])[0] != 2
   or 'REFUSED' not in run(['lua5.1', 'tests/run_tests.lua',
                            'test_rc_wrapper_nonexistent.lua'])[1])

rc, out, _ = run([])
ok('no command: refused with 2, not silently 0', rc == 2, 'got %d' % rc)

# --- 6. structural: nothing may sit between the command and `rc=$?` -------
lines = [ln.strip() for ln in src.splitlines()]
try:
    i = lines.index('"$@" > "$log" 2>&1')
    adjacent = lines[i + 1] == 'rc=$?'
except ValueError:
    i, adjacent = -1, False
ok('source: `"$@" > "$log" 2>&1` is present', i >= 0,
   'the wrapper no longer runs the command bare')
ok('source: `rc=$?` is the VERY NEXT line (anything between overwrites it)',
   adjacent, 'next line was %r' % (lines[i + 1] if i >= 0 and i + 1 < len(lines)
                                   else None))
ok('source: the command is not piped anywhere',
   '"$@" |' not in src and '"$@" 2>&1 |' not in src)

# The banner printf must be the last printf in the file, ahead of only `exit`.
tail_src = [ln for ln in lines[lines.index('rc=$?'):] if ln.startswith('printf')] \
    if adjacent else []
ok('source: the RC_EXIT banner is the final printf (so `| tail` keeps it)',
   bool(tail_src) and 'RC_EXIT=%d' in tail_src[-1], tail_src[-1] if tail_src else None)

print()
if fails:
    print('%d FAILURE(S):' % len(fails))
    for f in fails:
        print('  - %s' % f)
    sys.exit(1)
print('rc.sh wrapper: all checks ok')

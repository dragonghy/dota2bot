#!/usr/bin/env python3
"""The push gate's leg 2 must not be refusable by a 4-second package.

GH #899 (director ruling 2026-09-18).  `tests/test_rc_wrapper.py` carries two
checks that need a real `lua5.1` to pass through to.  GH #384 correctly stopped
them from reporting the tree as RED when the interpreter is absent, and made
them say the honest word instead: UNCERTIFIABLE, exit 2.

What nobody wrote down is where that 2 goes.  This file is `in_gate: true` in
`tools/agent/py_gate_manifest.json`, so on a container with no lua5.1:

    tests/test_rc_wrapper.py  exit 2
      -> tools/agent/py_gate.py  exit 2   ("N ran, 0 findings, 2 uncertifiable")
      -> .githooks/pre-push      PUSH REFUSED -- "could NOT RUN (gate exit 2)"
      -> the remedy it prints:   RULE6_BYPASS=1 git push ...

That is a fresh Routine container's DEFAULT state until something buys lua5.1,
and the one thing that does buy it -- 开工自检 -- runs `run_py_tests.sh` at
:627 and installs the interpreter at :767, i.e. ~140 lines LATER.  So the
window is real, it is at the start of every round, and the exit it steers the
author to is the bypass (GH #707 / #669: that is how RULE6_BYPASS becomes the
ordinary path).

The fix is the one GH #205 already made mandatory everywhere else: BUY IT.
This file pins both halves of that, because only the pair is the claim:

  (A) lua5.1 absent + a package manager that can supply it
      => the interpreter is bought and the two checks RUN (exit 0).
  (B) lua5.1 absent + a package manager that cannot supply it
      => #384's honesty survives: still UNCERTIFIABLE, still exit 2.

(B) is not decoration.  A "fix" that made the checks green without the binary
would pass (A) and be strictly worse than the bug -- it would be a did-not-run
wearing a pass, the exact family this repo has paid for in GH #171, #198 and
#200.  Evidence discipline 2: the assertion has to discriminate.

The stand is hermetic: a PATH with no lua5.1 on it and a FAKE `apt-get`.  No
network, no dpkg, no mutation of the container, and it says so by marking every
call the fake receives.
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TARGET = os.path.join(ROOT, 'tests', 'test_rc_wrapper.py')

# Everything the target (and rc.sh, and ensure_lua_toolchain.sh) reaches for by
# name.  Anything missing from the container is simply skipped -- the stand then
# fails loudly on its own terms rather than pretending.
NEEDED = [
    'bash', 'sh', 'dash', 'env', 'mktemp', 'grep', 'tail', 'head', 'wc', 'tr',
    'sed', 'cat', 'rm', 'ln', 'ls', 'sleep', 'timeout', 'id', 'kill', 'dirname',
    'basename', 'python3', 'uname', 'cut', 'sort', 'date',
]

fails = []
uncs = []


def ok(name, cond, why=''):
    print('%-68s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


def unc(name, why):
    """The check did not run.  NOT a pass, and NOT a failure of the tree."""
    print('%-68s %s' % (name, 'UNCERTIFIABLE'))
    uncs.append('%s: %s' % (name, why))


def build_stand(td, real_lua, supplies_lua):
    """A bin/ with no lua5.1 on it and a fake apt-get.

    `supplies_lua` decides whether the fake package manager can actually
    produce the interpreter -- that is the only difference between case (A)
    and case (B), which is what makes the pair discriminating.
    """
    binp = os.path.join(td, 'bin')
    os.makedirs(binp)
    for tool in NEEDED:
        src = shutil.which(tool)
        if src and os.path.basename(src) not in ('lua5.1', 'lua'):
            dst = os.path.join(binp, tool)
            if not os.path.exists(dst):
                os.symlink(src, dst)

    marker = os.path.join(td, 'apt-calls.txt')
    body = ['#!/bin/sh', 'printf "%s\\n" "$*" >> ' + marker]
    if supplies_lua:
        # "The package manager made lua5.1 appear."  A symlink to the real
        # interpreter, because the two checks downstream run actual Lua and
        # read actual exit codes -- a stub binary would make them vacuous,
        # which is the failure mode this whole file exists to refuse.
        body += [
            'for a in "$@"; do',
            '  if [ "$a" = "lua5.1" ]; then',
            '    /bin/ln -sf %s %s/lua5.1 2>/dev/null' % (real_lua, binp),
            '    exit 0',
            '  fi',
            'done',
        ]
    else:
        body += ['exit 100']
    body += ['exit 0']

    apt = os.path.join(binp, 'apt-get')
    with open(apt, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(body) + '\n')
    os.chmod(apt, 0o755)
    return binp, marker


def run_target(binp):
    env = {
        'PATH': binp,
        'HOME': os.environ.get('HOME', '/root'),
        'TMPDIR': os.environ.get('TMPDIR', '/tmp'),
        'LANG': 'C',
    }
    p = subprocess.run([sys.executable, TARGET], cwd=ROOT, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       timeout=300)
    return p.returncode, p.stdout.decode('utf-8', 'replace')


real_lua = shutil.which('lua5.1')

if not os.path.isfile(TARGET):
    print('could not read %s' % TARGET)
    sys.exit(2)

# --- 1. structural: the purchase is in the file, ahead of the decision -------
with open(TARGET, encoding='utf-8') as fh:
    src = fh.read()

ok('target calls the shared buyer, not a bare which()',
   'ensure_lua_toolchain.sh' in src,
   'no reference to tools/agent/ensure_lua_toolchain.sh in %s' % TARGET)

i_buy = src.find('ensure_lua_toolchain.sh')
i_has = src.find('HAS_LUA =')
ok('the purchase is defined before HAS_LUA is decided',
   i_buy != -1 and i_has != -1 and i_buy < i_has,
   'buyer at %d, HAS_LUA at %d' % (i_buy, i_has))

ok('the #384 honesty word is still in the file',
   'UNCERTIFIABLE' in src, 'the exit-2 word is gone -- see case (B) below')

# --- 2+3. behavioural: the discriminating pair ------------------------------
if real_lua is None:
    why = ('no lua5.1 on PATH -- the stand needs a real interpreter to hand '
           'the fake package manager; a stub would make both cases vacuous')
    unc('(A) absent + buyable  => bought, checks RUN, exit 0', why)
    unc('(B) absent + unbuyable => still UNCERTIFIABLE, exit 2', why)
else:
    with tempfile.TemporaryDirectory() as td:
        binp, marker = build_stand(td, real_lua, supplies_lua=True)
        rc, out = run_target(binp)
        asked = os.path.isfile(marker) and 'lua5.1' in open(marker).read()
        ok('(A) absent + buyable  => bought, checks RUN, exit 0',
           rc == 0 and 'UNCERTIFIABLE' not in out,
           'exit %d; %s' % (rc, out[-400:]))
        # Without this the case is satisfiable by lua5.1 leaking in from the
        # real PATH -- i.e. by the stand not standing.
        ok('(A) is answered by the purchase, not by a leaked interpreter',
           asked, 'the fake apt-get was never asked for lua5.1')

    with tempfile.TemporaryDirectory() as td:
        binp, marker = build_stand(td, real_lua, supplies_lua=False)
        rc, out = run_target(binp)
        ok('(B) absent + unbuyable => still UNCERTIFIABLE, exit 2',
           rc == 2 and 'UNCERTIFIABLE' in out,
           'exit %d (a green here would be a did-not-run wearing a pass); %s'
           % (rc, out[-400:]))

print()
if fails:
    print('%d FAILURE(S):' % len(fails))
    for f in fails:
        print('  - %s' % f)
    sys.exit(1)
if uncs:
    print('%d check(s) UNCERTIFIABLE -- this is NOT a pass:' % len(uncs))
    for u in uncs:
        print('  - %s' % u)
    sys.exit(2)
print('rc.sh wrapper buys its interpreter: all checks ok')

#!/usr/bin/env python3
"""Pins the `.claude/skills/` registry, and pins the four evidence disciplines.

WHY THIS FILE EXISTS.  A skill is loaded by name and used on demand, so nothing
in the tree fails when one is renamed, de-registered from the `AGENTS.md` table,
or quietly hollowed out -- the same shape as the un-run `tests/*.py` before
GH #243 and the un-registered stable anchors before `stable_anchors.py`:
**a missing registration does not raise its own hand; adding the check is what
makes it raise one.**

Two legs:

1. REGISTRY (all skills).  Every `.claude/skills/<dir>/SKILL.md` must exist,
   carry YAML frontmatter whose `name` equals its directory, carry a
   `description` (that string is the whole trigger surface -- an empty one means
   the skill is on disk and unreachable), and appear as a row in the `AGENTS.md`
   skills table.  Both directions are checked: a table row naming a skill that
   does not exist is just as wrong as a skill missing from the table.

2. THE FOUR DISCIPLINES (`evidence-discipline`).  This one skill is pinned
   harder than the others because its content is the part that decays: each
   discipline was written after >=2 recurrences, and the failure mode is a
   later edit that keeps the heading and drops the **mechanical remedy** --
   which is the only half that does any work.  Prose alone ("be careful with
   exit codes") is what the four rules were written to replace, so each rule is
   pinned to its executable token, not to its title:

     1  restore from a file copy      -> `sha256sum -c`, and `git checkout` named
                                         as the thing NOT to use
     2  surviving mutant              -> the word "synthetic" (the actual move)
     3  exit code without a pipe      -> `returncode ==` in a test, plus the
                                         two look-alike codes 143 and argparse 2
     4  same conclusion != same reason-> the demand to name WHICH route was taken

Exit vocabulary matches `run_py_tests.sh`: 2 = could not read its inputs (did
NOT run), 1 = ran and the answer was wrong, 0 = clean.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SKILLS_DIR = os.path.join(ROOT, '.claude', 'skills')
AGENTS_MD = os.path.join(ROOT, 'AGENTS.md')

fails = []


def ok(name, cond, why=''):
    print('%-64s %s' % (name, 'ok' if cond else 'FAIL'))
    if not cond:
        fails.append('%s%s' % (name, ': ' + why if why else ''))


if not os.path.isdir(SKILLS_DIR):
    print('could not read %s' % SKILLS_DIR)
    sys.exit(2)
if not os.path.exists(AGENTS_MD):
    print('could not read %s' % AGENTS_MD)
    sys.exit(2)

with open(AGENTS_MD, encoding='utf-8') as fh:
    agents = fh.read()

skill_dirs = sorted(d for d in os.listdir(SKILLS_DIR)
                    if os.path.isdir(os.path.join(SKILLS_DIR, d)))
ok('at least the six original skills are present', len(skill_dirs) >= 6,
   'found %d' % len(skill_dirs))

# --- leg 1: registry -------------------------------------------------------
# The table rows look like `| `<name>` | when ... |`.  Only rows whose first
# cell is a bare backticked token count, so prose mentioning a skill inline
# cannot satisfy the registration check (that is the accidental-agreement trap
# from discipline 2 -- every skill name appears in the file's prose somewhere).
table_names = set(re.findall(r'^\|\s*`([a-z0-9-]+)`\s*\|', agents, re.M))

for d in skill_dirs:
    path = os.path.join(SKILLS_DIR, d, 'SKILL.md')
    if not os.path.exists(path):
        ok('%s/SKILL.md exists' % d, False)
        continue
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    m = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    ok('%s: has YAML frontmatter' % d, m is not None)
    if not m:
        continue
    front = m.group(1)
    name = re.search(r'^name:\s*(\S+)\s*$', front, re.M)
    desc = re.search(r'^description:\s*(\S.*)$', front, re.M)
    ok('%s: frontmatter name matches directory' % d,
       name is not None and name.group(1) == d,
       'got %r' % (name.group(1) if name else None))
    ok('%s: frontmatter carries a description' % d,
       desc is not None and len(desc.group(1).strip()) >= 40,
       'a skill with no description is on disk and unreachable')
    ok('%s: registered in the AGENTS.md skills table' % d, d in table_names)

for n in sorted(table_names):
    if os.path.isdir(os.path.join(SKILLS_DIR, n)):
        continue
    # Rows for the subagent profiles in `.claude/agents/` share the table shape;
    # only complain about names that claim to be skills.
    if os.path.exists(os.path.join(ROOT, '.claude', 'agents', n + '.md')):
        continue
    ok('table row `%s` names something that exists' % n, False,
       'no .claude/skills/%s/ and no .claude/agents/%s.md' % (n, n))

# --- leg 2: the four disciplines -------------------------------------------
ED = os.path.join(SKILLS_DIR, 'evidence-discipline', 'SKILL.md')
if not os.path.exists(ED):
    ok('evidence-discipline/SKILL.md exists', False)
else:
    with open(ED, encoding='utf-8') as fh:
        ed = fh.read()

    heads = re.findall(r'^## (\d)\. (.+)$', ed, re.M)
    ok('four numbered disciplines, numbered 1..4',
       [h[0] for h in heads] == ['1', '2', '3', '4'],
       'got %r' % ([h[0] for h in heads],))

    # Each discipline is pinned to the mechanical half, not to its heading.
    # Slice the file per section so a token cannot satisfy the wrong rule.
    bodies = {}
    parts = re.split(r'^## (\d)\. .+$', ed, flags=re.M)
    for i in range(1, len(parts), 2):
        bodies[parts[i]] = parts[i + 1]

    ok('1: names sha256sum -c as the proof of restore',
       'sha256sum -c' in bodies.get('1', ''))
    ok('1: names git checkout as the thing NOT to restore with',
       'git checkout' in bodies.get('1', ''))
    ok('2: prescribes a synthetic case (the actual move)',
       'synthetic' in bodies.get('2', '').lower())
    ok('3: prescribes asserting the code in a test',
       'returncode ==' in bodies.get('3', ''))
    ok('3: keeps both look-alike codes (SIGTERM 143, argparse 2)',
       '143' in bodies.get('3', '') and 'argparse' in bodies.get('3', ''))
    # [director 20260831] The mechanical remedy itself, pinned by name. Rule 3
    # is the one rule whose recurrences continued AFTER the skill landed (the
    # 08-31 round read exit 0 piped and exit 3 bare from one command), and the
    # diagnosis was economic, not educational: the wrong form was the shorter
    # one. So the half that does the work here is the WRAPPER, and an edit that
    # keeps the advice and drops the tool restores the losing trade.
    ok('3: names the wrapper that makes the correct path the short one',
       'tools/agent/rc.sh' in bodies.get('3', ''))
    ok('3: names the runner for Lua tests (a module exits 0 having run nothing)',
       'run_tests.lua' in bodies.get('3', ''))
    ok('4: demands naming which route the ruling took',
       re.search(r'which\s+(route|argument|path)', bodies.get('4', ''),
                 re.I) is not None)

    # The reporting section is what carries the disciplines into the artifact a
    # reader actually sees; without it the skill is advice with no output.
    ok('carries the "where these belong in a report" section',
       'UNCERTIFIABLE' in ed and 'sha256sum -c' in ed.split('## 4.')[-1])

print()
if fails:
    print('%d FAILURE(S):' % len(fails))
    for f in fails:
        print('  - %s' % f)
    sys.exit(1)
print('skill registry + four disciplines: all checks ok (%d skills)'
      % len(skill_dirs))

#!/usr/bin/env python3
"""Promote-time constraints, made mechanical.

WHY THIS EXISTS (2026-09-04T19:xxZ, director; test_set.md §EI)
--------------------------------------------------------------
Two failure shapes, one root: **a constraint that only binds on the day
somebody promotes an id, written in prose that nobody re-reads on that day.**

  (A) THE `pullcad` TRAP (AGENTS.md, "Hard-won learnings").  A gate written
      as `IsSoakCandidate('X') and IsSoakCandidate('Y')` -- the *good* way to
      make a dependency code instead of prose -- is frozen FALSE the day `Y`
      is promoted, because a promoted id is in no armed string.  The lever
      then no-ops in every wave, `check_armed_wiring.py` still calls it
      WIRED (it checks that a call site EXISTS, not that the predicate CAN
      be true), and the verdict reads back "tested, no effect" with nothing
      raising a hand.  AGENTS.md answers this with an instruction to a human:
      "Before promoting anything, grep the id for appearances in OTHER
      gates' conditions."  That instruction has already failed once (caught
      by hand during the `creeppull`/`pullbeat` promote); an instruction is
      not a gate.

  (B) THE CO-PROMOTE ATOM (test_set.md §ED.5, strategy 2026-09-04T10:45Z).
      `stayfield`/`stayfield2` have never been measured without `fieldsip`
      armed beside them from W27 on, so promoting the holding side while
      rejecting the magnitude lever would ship a configuration no wave has
      ever run.  Strategy wrote that constraint down BEFORE the ruling --
      which is the improvement over `pullcad` -- and handed it to the
      director as prose.  Prose does not raise its hand either.  §ED.5 sat
      un-collected across two director rounds (both of which carried it
      forward in a "next trigger" list), which is precisely the evidence
      that the carrier, not the author, was the problem.

WHAT IT REPORTS
---------------
  FROZEN   -- a LIVE gate site names an id that carries a
              `PROMOTED (was soak-candidate '<id>')` note somewhere in the
              tree.  That predicate can never be true again.  (Shape A.)
  ATOM     -- a registered `no_promote_without` row is violated: a subject
              id has been promoted while one of its prerequisites is still
              gated.  (Shape B.)
  UNKNOWN  -- a registry row names an id that is NEITHER gated NOR marked
              promoted anywhere in the tree.  A typo here would make the
              atom silently vacuous, which is the one thing a constraint
              registry must never do quietly, so it is a finding.

EXIT CODES (house convention: 0 clean / 2 could-not-run / 3 findings)

LIMITS (read these before treating a green run as proof)
-------------------------------------------------------
1. **Comments are stripped before the LIVE scan, and that is load-bearing.**
   On the tree this landed against, EVERY occurrence that a naive scan would
   have called a violation was a cautionary comment about this exact trap:
   three `pullbeat` mentions in `mode_roam_generic.lua` and two `'X'`
   placeholders in `jmz_func.lua`, five in total, zero live.  A checker
   without comment-stripping is RED on trunk from birth -- and a check that
   is red from birth gets switched off, which is how the hand stops being
   raised.
2. Comment stripping is lexical (`--[[ ]]` blocks, then `--` to end of
   line).  A `--` inside a Lua string literal would truncate that line.
   The failure direction is toward FEWER live sites, i.e. toward quiet, so
   the number this prints is a **lower bound on live gate sites**.  It is
   not a lower bound on findings: an UNKNOWN row is loud either way.
3. "Promoted" is read from the `PROMOTED (was soak-candidate '<id>')` note,
   the same string `tests/test_gate_claim_consistency.lua` already keys on.
   An id promoted WITHOUT leaving that note is invisible to shape (A) and
   shows up as UNKNOWN in shape (B) -- loud in the registry, silent outside
   it.  That gap is the note's, not this tool's; do not paper over it here.
4. This answers "is a registered constraint violated ON THIS TREE".  It
   cannot know about a constraint nobody registered.  Registering the row
   is the required action; this file only makes the row bite.
"""

import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGISTRY = os.path.join('iterations', 'promote_atoms.json')
SCAN_DIRS = ('bots', 'game')

CALL_RE = re.compile(r"IsSoakCandidate\s*\(\s*['\"]([A-Za-z0-9_]+)['\"]\s*\)")
PROMOTED_RE = re.compile(
    r"PROMOTED\s*\(\s*was\s+soak-candidate\s*['\"]([A-Za-z0-9_]+)['\"]")
BLOCK_COMMENT_RE = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)


def strip_lua_comments(text):
    """Remove Lua comments.  See LIMIT 2 -- lexical, biased toward quiet."""
    text = BLOCK_COMMENT_RE.sub(lambda m: '\n' * m.group(0).count('\n'), text)
    out = []
    for line in text.split('\n'):
        idx = line.find('--')
        out.append(line if idx < 0 else line[:idx])
    return '\n'.join(out)


def lua_files(root):
    for base in SCAN_DIRS:
        d = os.path.join(root, base)
        if not os.path.isdir(d):
            continue
        for dirpath, _dirnames, filenames in os.walk(d):
            for fn in sorted(filenames):
                if fn.endswith('.lua'):
                    yield os.path.join(dirpath, fn)


def scan_tree(root):
    """-> (live_sites: id -> [(relpath, lineno)], promoted: id -> [(relpath, lineno)])"""
    live, promoted = {}, {}
    for path in sorted(lua_files(root)):
        rel = os.path.relpath(path, root)
        with open(path, encoding='utf-8', errors='replace') as fh:
            raw = fh.read()
        # promoted notes live IN comments, so they are read off the raw text
        for m in PROMOTED_RE.finditer(raw):
            lineno = raw.count('\n', 0, m.start()) + 1
            promoted.setdefault(m.group(1), []).append((rel, lineno))
        # Line numbers are counted in the STRIPPED text, which is line-for-line
        # aligned with the raw file (block comments collapse to their own
        # newlines, line comments truncate in place).  Counting a stripped
        # OFFSET against the raw string silently under-reports the line -- it
        # pointed at the cautionary comment above the live site, i.e. at the
        # decoy this tool exists to tell apart.  Caught by case 4.
        stripped = strip_lua_comments(raw)
        for m in CALL_RE.finditer(stripped):
            lineno = stripped.count('\n', 0, m.start()) + 1
            live.setdefault(m.group(1), []).append((rel, lineno))
    return live, promoted


def state_of(cand_id, live, promoted):
    if live.get(cand_id):
        return 'GATED'
    if promoted.get(cand_id):
        return 'PROMOTED'
    return 'UNKNOWN'


def load_registry(root):
    path = os.path.join(root, REGISTRY)
    if not os.path.exists(path):
        return None, 'registry not found: %s' % REGISTRY
    try:
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
    except ValueError as exc:
        return None, 'registry is not valid JSON: %s' % exc
    atoms = data.get('atoms')
    if not isinstance(atoms, list):
        return None, 'registry has no "atoms" list'
    return atoms, None


def check(root):
    """-> (exit_code, lines)"""
    lines = []
    live, promoted = scan_tree(root)
    lines.append('scanned: %d distinct live gate id(s), %d id(s) carrying a '
                 'PROMOTED note' % (len(live), len(promoted)))

    findings = 0

    # ---- shape (A): the pullcad trap -------------------------------------
    frozen = sorted(i for i in promoted if live.get(i))
    if frozen:
        for cand_id in frozen:
            findings += 1
            where = ', '.join('%s:%d' % s for s in live[cand_id][:4])
            lines.append("FROZEN    '%s' is promoted, yet a live gate still "
                         'names it -- that predicate can never be true again '
                         '(%s)' % (cand_id, where))
    else:
        lines.append('FROZEN    none (no live gate names a promoted id)')

    # ---- shape (B): registered co-promote atoms --------------------------
    atoms, err = load_registry(root)
    if atoms is None:
        lines.append('ATOM      COULD NOT RUN -- %s' % err)
        return 2 if not findings else 3, lines

    lines.append('atoms registered: %d' % len(atoms))
    for atom in atoms:
        name = atom.get('name', '<unnamed>')
        rule = atom.get('rule')
        if rule != 'no_promote_without':
            findings += 1
            lines.append("ATOM      '%s' has unknown rule %r -- a row this "
                         'tool cannot evaluate is not a row that binds'
                         % (name, rule))
            continue
        subjects = atom.get('subject') or []
        prereqs = atom.get('prereq') or []
        states = {i: state_of(i, live, promoted) for i in list(subjects) + list(prereqs)}
        unknown = sorted(i for i, s in states.items() if s == 'UNKNOWN')
        for cand_id in unknown:
            findings += 1
            lines.append("UNKNOWN   '%s' (atom '%s') is neither gated nor "
                         'marked promoted anywhere in the tree -- a typo here '
                         'makes the atom vacuous' % (cand_id, name))
        still_gated = [p for p in prereqs if states.get(p) == 'GATED']
        for subj in subjects:
            if states.get(subj) == 'PROMOTED' and still_gated:
                findings += 1
                lines.append("ATOM      '%s' violated: '%s' is promoted while "
                             'prerequisite(s) %s remain gated -- this ships a '
                             'configuration no wave has run (%s)'
                             % (name, subj, ','.join(still_gated),
                                atom.get('ref', 'no ref')))
        if not unknown:
            lines.append("ok        '%s': %s" % (
                name, ' '.join('%s=%s' % (i, states[i])
                               for i in list(subjects) + list(prereqs))))

    if findings:
        lines.append('%d finding(s)' % findings)
        return 3, lines
    lines.append('promote-atom constraints: OK')
    return 0, lines


def main(argv):
    root = argv[1] if len(argv) > 1 else REPO
    if not os.path.isdir(root):
        print('COULD NOT RUN -- no such tree: %s' % root)
        return 2
    code, lines = check(root)
    for line in lines:
        print(line)
    return code


if __name__ == '__main__':
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""Read an identifying threshold OUT OF the shipped Lua instead of copying it.

WHY THIS EXISTS (GH #90, director ruling 2026-08-21T15:0xZ)
  `capmono_refusal.py` claimed, in the sentence that carried its whole
  attribution argument:

      NEAREST ENEMY IN [850,1500] -- the load-bearing clause: >850u guarantees
      `lanesurv`'s burst retreat does not fire on its own

  The radius `J.ShouldRetreatLaneBurst` actually scans is **1100**
  (`jmz_func.lua:4892`); the literal `850` does not occur anywhere in
  `jmz_func.lua`.  53.3% of the registered domain sat inside the very rule the
  domain was built to exclude, so the attribution sentence was false on 423 of
  793 frames -- and nothing in the tree could notice, because the number lived
  only in a Python file that no test compared against the Lua.

  This is the recurrence class, not the incident: a detector's identifying
  clause is an ASSERTION ABOUT SHIPPED CODE, and a hand-copied number is an
  assertion that decays silently the first time someone edits the rule.

THE CONTRACT
  A threshold that means "the shipped rule R reaches this far" must be READ
  FROM R at run time.  Copying it verbatim (what GH #90 recommended) is
  strictly weaker: it is correct on the day it is written and rots on the day
  the constant moves, with no red anywhere.  Deriving it cannot rot -- if the
  call shape moves, every consumer raises.

  Every lookup here is FAIL-LOUD BY CONSTRUCTION: there is no `default=`
  parameter and no silent fallback, and a pattern matching zero OR MORE THAN
  ONE site raises.  A defaulting extractor would reproduce exactly the failure
  mode it exists to kill (a plausible number, no red).  Do not add one.

  Ambiguity is an error on purpose: `J.ShouldInitiateLaneKill` contains two
  `J.GetNearbyHeroes` calls (allies at 1000, enemies at 800).  Selecting "the
  first one" would have quietly returned the ally radius; `where=` forces the
  caller to say which call it means.

SCOPE
  Deliberately a ~100-line regex reader, not a Lua parser.  It handles the one
  shape jmz_func.lua is written in (top-level `function J.Name(` ... next
  top-level `function`).  If a future file breaks that shape, the uniqueness
  checks turn it into a loud failure rather than a wrong number.

USE
    from source_constants import call_arg, literal
    ENE_LO = call_arg('J.ShouldRetreatLaneBurst', 'J.GetNearbyHeroes',
                      index=1, where={2: 'true'})     # -> 1100.0

The registry test `tests/test_detector_source_constants.py` pins every detector
constant that claims to mirror shipped code, and is what converts a one-off
hand check into a tripwire.
"""
import os
import re

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
JMZ = os.path.join(REPO, 'bots', 'FunLib', 'jmz_func.lua')


class SourceConstantError(Exception):
    """A threshold could not be read out of the shipped source, unambiguously.

    Always fatal.  Callers must not catch this to substitute a literal: the
    literal is the bug (GH #90).
    """


def function_body(func, path=None):
    """Source text of a top-level `function <func>(` up to the next top-level one."""
    path = path or JMZ
    with open(path, 'r', encoding='utf-8') as fh:
        src = fh.read()
    starts = [m.start() for m in
              re.finditer(r'^function\s+' + re.escape(func) + r'\s*\(', src, re.M)]
    if len(starts) != 1:
        raise SourceConstantError(
            '%s: expected exactly 1 definition of `function %s(`, found %d'
            % (os.path.basename(path), func, len(starts)))
    nxt = re.compile(r'^function\s', re.M).search(src, starts[0] + 1)
    return src[starts[0]:nxt.start() if nxt else len(src)]


def _strip_comments(body):
    """Drop `--` line comments so a number quoted in prose is never matched.

    Load-bearing: jmz_func.lua explains its own thresholds in comments
    ("skip any target meaningfully past the midline (>800 ...)"), and a reader
    that counted those would report the wrong number of sites and, worse, could
    match a stale number in a comment that no longer matches the code below it.
    """
    return '\n'.join(re.sub(r'--.*$', '', ln) for ln in body.split('\n'))


def _num(tok, what):
    try:
        return float(tok)
    except ValueError:
        raise SourceConstantError('%s: `%s` is not a numeric literal '
                                  '(computed thresholds cannot be read here)'
                                  % (what, tok))


def call_arg(func, callee, index, where=None, path=None):
    """Numeric argument `index` (0-based) of the unique matching `callee(` call.

    `where` selects among several calls to the same callee by pinning other
    arguments to their exact source text, e.g. {2: 'true'} for the
    enemies-not-allies variant of `J.GetNearbyHeroes`.  Matching is on the
    literal token, so a caller cannot accidentally select "whichever one comes
    first".
    """
    body = _strip_comments(function_body(func, path))
    hits = []
    for m in re.finditer(re.escape(callee) + r'\s*\(([^()]*)\)', body):
        args = [a.strip() for a in m.group(1).split(',')]
        if index >= len(args):
            continue
        if where and any(k >= len(args) or args[k] != v for k, v in where.items()):
            continue
        hits.append(args[index])
    what = '%s -> %s(arg %d)' % (func, callee, index)
    if len(hits) != 1:
        raise SourceConstantError(
            '%s: expected exactly 1 matching call site, found %d%s'
            % (what, len(hits), '' if not hits else ' (%s)' % ', '.join(hits)))
    return _num(hits[0], what)


def assignment(name, path=None):
    """Numeric literal of the unique top-level `<name> = <number>` assignment.

    Many gates park their threshold in a file-level constant rather than inline
    (`X.nEDrainDangerRadius = 500` in hero_lion.lua), which `function_body`
    cannot reach because it is not inside any function.  Fail-loud on the same
    terms as the rest of this module: zero or several matches raise, so a
    detector can never silently mirror the wrong site.
    """
    path = path or JMZ
    with open(path, 'r', encoding='utf-8') as fh:
        src = _strip_comments(fh.read())
    hits = re.findall(r'^\s*' + re.escape(name) + r'\s*=\s*([-\d.]+)\s*$',
                      src, re.M)
    what = '%s = <number> in %s' % (name, os.path.basename(path))
    if len(hits) != 1:
        raise SourceConstantError(
            '%s: expected exactly 1 assignment, found %d%s'
            % (what, len(hits), '' if not hits else ' (%s)' % ', '.join(hits)))
    return _num(hits[0], what)


def literal(func, pattern, path=None):
    """The number in group `n` of `pattern`, which must match the body exactly once.

    For thresholds that appear as comparisons rather than call arguments, e.g.
    `GetUnitToUnitDistance( bot, e ) <= 700`.
    """
    body = _strip_comments(function_body(func, path))
    hits = [m.group('n') for m in re.finditer(pattern, body)]
    what = '%s -> /%s/' % (func, pattern)
    if len(hits) != 1:
        raise SourceConstantError(
            '%s: expected exactly 1 match, found %d%s'
            % (what, len(hits), '' if not hits else ' (%s)' % ', '.join(hits)))
    return _num(hits[0], what)


if __name__ == '__main__':
    print('lanesurv reach          =', call_arg('J.ShouldRetreatLaneBurst',
                                                'J.GetNearbyHeroes', 1,
                                                {2: 'true'}))
    print('l1trade enemy ring      =', call_arg('J.ShouldInitiateLaneKill',
                                                'J.GetNearbyHeroes', 1,
                                                {2: 'true'}))
    print('l5combo enemy ring      =', call_arg('J.ShouldSupportComboKill',
                                                'J.GetNearbyHeroes', 1,
                                                {2: 'true'}))
    print('l5combo 2-enemy veto    =', literal('J.ShouldSupportComboKill',
                                               r'GetUnitToUnitDistance\([^()]*\)'
                                               r'\s*<=\s*(?P<n>\d+)'))

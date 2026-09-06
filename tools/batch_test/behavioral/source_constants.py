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
  shape jmz_func.lua is written in (top-level `function J.Name(` ... its own
  matching `end`; block depth is counted per line, so a ONE-LINE `if ... end`
  closes on the line it opened -- GH #547).  If a future file breaks that
  shape, the uniqueness checks and `function_span`'s never-closes error turn
  it into a loud failure rather than a wrong number.

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


# `for`/`while` always reach their block through `do`, so counting `do` alone
# keeps them from being counted twice.  `elseif` is one word, so `\bif\b` does
# not match inside it -- an elseif opens no new block and needs no `end`.
# `repeat ... until` has no `end` and so contributes to neither side.
_OPEN_RE = re.compile(r'\b(?:function|do|if)\b')
_END_RE = re.compile(r'\bend\b')
_STR_RE = re.compile(r"'[^'\n]*'|\"[^\"\n]*\"")


def _block_delta(line):
    """(block openers, `end`s) on one Lua line, ignoring comments and strings.

    Strings and comments are blanked first so an `end` inside either cannot
    close a real block -- `-- ... at the end of the ladder` is a comment, not a
    terminator.
    """
    line = _STR_RE.sub("''", line)
    cut = line.find('--')
    if cut != -1:
        line = line[:cut]
    return len(_OPEN_RE.findall(line)), len(_END_RE.findall(line))


def function_span(src, start, what='function'):
    """Offset one past the `end` that closes the block opened at `start`.

    THE TERMINATOR IS THE FUNCTION'S OWN `end`, NOT THE NEXT DECLARATION
    (GH #547, 2026-09-06).  Until this round the body ran from the header to
    the next `^function`, which is a different thing whenever ANYTHING sits
    between the two -- and something does, often:

      * 35 of 449 top-level functions in `jmz_func.lua`,
      * 10 of 110 in `utils.lua`,
      * 9 of 29 in `ability_item_usage_generic.lua`, one of which
        (`X.WillBreakInvisible`) picked up **2,959 lines** -- the whole
        `X.ConsiderItemDesire` table -- as "its body".

    Nothing was measurably wrong TODAY (the two live call sites that over-read
    took in a `local` table with no numbers in it, and `_strip_comments` was
    already eating the prose), but that is a property of today's Lua, not of
    the reader: this module's whole contract is that a wrong scope must be
    loud, and a body that silently contains someone else's constants is the
    GH #296 failure with the fuse pulled.
    """
    depth, i = 0, start
    for line in src[start:].split('\n'):
        opens, closes = _block_delta(line)
        depth += opens - closes
        i += len(line) + 1
        if depth <= 0:
            return min(i, len(src))
    raise SourceConstantError(
        '%s never closes: no `end` brings it back to depth 0' % what)


def function_body(func, path=None):
    """Source text of a top-level `function <func>(` up to its own bare `end`."""
    path = path or JMZ
    with open(path, 'r', encoding='utf-8') as fh:
        src = fh.read()
    starts = [m.start() for m in
              re.finditer(r'^function\s+' + re.escape(func) + r'\s*\(', src, re.M)]
    if len(starts) != 1:
        raise SourceConstantError(
            '%s: expected exactly 1 definition of `function %s(`, found %d'
            % (os.path.basename(path), func, len(starts)))
    return src[starts[0]:function_span(src, starts[0],
                                       '%s (%s)' % (func, os.path.basename(path)))]


def _strip_comments(body):
    """Drop `--` line comments so a number quoted in prose is never matched.

    Load-bearing: jmz_func.lua explains its own thresholds in comments
    ("skip any target meaningfully past the midline (>800 ...)"), and a reader
    that counted those would report the wrong number of sites and, worse, could
    match a stale number in a comment that no longer matches the code below it.
    """
    return '\n'.join(re.sub(r'--.*$', '', ln) for ln in body.split('\n'))


# [GH #167 follow-on] A gated widening: `<flag> and <armed> or <shipped>`.
#
# This is the ONE non-literal form this module reads, and only when the caller
# says which leg it means.  It exists because a soak candidate that moves a
# threshold turns a literal into an expression, and the module's fail-loud
# default then takes a detector that was correctly mirroring the SHIPPED value
# down with it -- which is what happened the first time (`tpreach` widened
# J.CanEnemyInterruptTpChannel's scan and test_detector_source_constants.py
# went red on a reading that had not actually changed for any corpus in hand).
#
# Refusing outright would push the next author toward deleting the assertion;
# guessing a leg would silently mirror the wrong number on half the waves.
# So: readable, but only with the leg named at the call site.
_GATED_WIDEN = re.compile(r'^(\w+)\s+and\s+([0-9]+(?:\.[0-9]+)?)'
                          r'\s+or\s+([0-9]+(?:\.[0-9]+)?)$')


def _num(tok, what, arm=None):
    try:
        return float(tok)
    except ValueError:
        pass
    m = _GATED_WIDEN.match(tok)
    if m is not None and arm in ('shipped', 'armed'):
        return float(m.group(2) if arm == 'armed' else m.group(3))
    hint = ''
    if m is not None:
        hint = ("; this is a gated widening on `%s` -- pass arm='shipped' or "
                "arm='armed' to say which leg you mean" % m.group(1))
    raise SourceConstantError('%s: `%s` is not a numeric literal '
                              '(computed thresholds cannot be read here)%s'
                              % (what, tok, hint))


def call_arg(func, callee, index, where=None, path=None, arm=None):
    """Numeric argument `index` (0-based) of the unique matching `callee(` call.

    `where` selects among several calls to the same callee by pinning other
    arguments to their exact source text, e.g. {2: 'true'} for the
    enemies-not-allies variant of `J.GetNearbyHeroes`.  Matching is on the
    literal token, so a caller cannot accidentally select "whichever one comes
    first".

    `arm` is for an argument a soak candidate has turned into a gated widening
    (`bWide and 1200 or 700`): 'shipped' reads the ungated leg, 'armed' the
    other.  Omitted -- the default -- such an argument is still refused, so a
    threshold that quietly became computed cannot be read as though it were
    still one number.
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
    return _num(hits[0], what, arm)


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

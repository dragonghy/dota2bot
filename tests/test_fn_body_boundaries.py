#!/usr/bin/env python3
"""Every self-written Lua function-body splitter must stop at its own `end`.

GH #547 (director census, 2026-09-06).  `wkqdmg_domain.py::_fn_body` counted a
line as closing a block only when the line STARTED with `end`, so the one-line
gate

    if not ( J.IsModeTurbo() and J.IsSoakCandidate( 'wkqdmg' ) ) then return n end

scored +1 and never gave it back: `X.wk_GetBlastKillDamage` is 22 lines and was
read as 567, swallowing `X.ConsiderQ` and `X.ConsiderW` whole, so the gate id
read out of "its body" belonged to a different helper.  That one splitter was
fixed the same round.  This file is the CENSUS the issue actually asked for:
every other splitter in the tree, measured on the functions it really slices.

WHY A TEST AND NOT A ONE-OFF CHECK: a mis-scoped body does not raise.  It
returns a plausible string, and the number found inside it is a number from
somewhere else in the file.  The only durable form of "we checked" is a check
that runs again next round.

WHAT IS PINNED (each production splitter x each function it slices in prod):
  1. the slice ends at a bare `end` -- with the comments and blank lines that
     follow it, and the NEXT function's doc comment, outside;
  2. the slice contains exactly one top-level function header (its own);
  3. the slice is block-balanced: openers and `end`s cancel exactly once, at
     the last line.

(3) is deliberately computed here rather than imported, so this file does not
grade a splitter against its own arithmetic.

CENSUS RESULT, for the record (2026-09-06, on the tree at the time):
  * `blinkflee_domain._fn_body` -- shape "first `end` at column 0".  Agrees
    with block counting on 588/588 top-level functions of jmz_func.lua,
    utils.lua and ability_item_usage_generic.lua.  Correct today because every
    body in this repo is indented; pinned here so the day that stops being
    true is a red, not a number.
  * `slotpush_domain._fn_body` -- shape "up to the next top-level declaration".
    Over-reads real code in 32/449 jmz functions and 9/110 utils functions.
    NEITHER of the two it slices in production is one of them (their over-read
    is blank lines left behind by comment stripping), so nothing it reports is
    wrong today.
  * `source_constants.function_body` -- same shape until this round, and it is
    the one everything else is built on (tbearly, tpgap, and the whole
    registry in test_detector_source_constants.py).  Over-read real code in
    35/449 + 10/110 + 9/29 functions; the worst was `X.WillBreakInvisible`,
    which took in the entire 2,959-line `X.ConsiderItemDesire` table.  Fixed
    in the same commit as this file: it now stops at its own `end`.
  * `wkqdmg_domain._fn_body` -- block counting, fixed 2026-09-06 (a2caace8).

Run: python3 tests/test_fn_body_boundaries.py   (or tests/run_py_tests.sh)
Exit 0 clean / 1 a splitter is out of bounds / 2 could not run (GH #243).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral')
sys.path.insert(0, BEHAV)

JMZ = os.path.join(ROOT, 'bots', 'FunLib', 'jmz_func.lua')
UTILS = os.path.join(ROOT, 'bots', 'FunLib', 'utils.lua')
WK = os.path.join(ROOT, 'bots', 'BotLib', 'hero_skeleton_king.lua')

fails = []
checks = 0


def check(what, ok, detail=''):
    global checks
    checks += 1
    if ok:
        print('  ok    %s' % what)
    else:
        print('  FAIL  %s%s' % (what, ('  -- ' + detail) if detail else ''))
        fails.append(what)


def read(path):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return fh.read()
    except OSError as exc:                                   # pragma: no cover
        print('UNCERTIFIABLE -- cannot read %s: %s' % (path, exc))
        sys.exit(2)


# --------------------------------------------------------------------------
# An INDEPENDENT balance reading.  Not imported from any splitter on purpose:
# a test that grades an implementation with the implementation's own helper
# asserts nothing (test_set.md AD.3).
# --------------------------------------------------------------------------
_OPEN = re.compile(r'\b(?:function|do|if)\b')
_END = re.compile(r'\bend\b')
_STR = re.compile(r"'[^'\n]*'|\"[^\"\n]*\"")


def _code(line):
    """One line with strings blanked and any `--` comment cut off."""
    line = _STR.sub("''", line)
    cut = line.find('--')
    return line if cut == -1 else line[:cut]


def balance_closes_once(body):
    """(closes_at_last_line, depth_trace_ok) for a candidate function body.

    Walks the slice counting block openers against `end`s.  A correct body
    reaches depth 0 exactly once, on its final code line.
    """
    depth = 0
    zero_at = None
    lines = body.split('\n')
    for k, raw in enumerate(lines):
        line = _code(raw)
        depth += len(_OPEN.findall(line)) - len(_END.findall(line))
        if depth <= 0 and zero_at is None and line.strip():
            zero_at = k
    if zero_at is None:
        return False, 'never returns to depth 0'
    # Everything after the closing line must be blank or comment: that is the
    # boundary claim.  (A trailing blank line from the slice's own newline is
    # normal; a `local` table or the next function's prose is not.)
    tail = [ln for ln in lines[zero_at + 1:]
            if ln.strip() and not ln.strip().startswith('--')]
    if tail:
        return False, 'code after the closing `end`: %r' % tail[0][:60]
    return True, ''


def depth_of(text):
    """Net block depth of a chunk of Lua (openers minus `end`s)."""
    depth = 0
    for raw in text.split('\n'):
        line = _code(raw)
        depth += len(_OPEN.findall(line)) - len(_END.findall(line))
    return depth


def ends_on_bare_end(body):
    lines = [ln for ln in body.split('\n') if ln.strip()]
    if not lines:
        return False, 'empty slice'
    last = _code(lines[-1]).strip()
    if last != 'end':
        return False, 'last code line is %r, not a bare `end`' % last[:60]
    return True, ''


def one_header(body, name):
    heads = re.findall(r'^function\s+([\w.:]+)', body, re.M)
    if heads == [name]:
        return True, ''
    return False, 'headers inside the slice: %s' % heads[:4]


def pin(label, body, name):
    """The three boundary claims, for one splitter x one production function."""
    if body is None:
        check('%s: splitter returned a slice' % label, False, 'got None')
        return
    for what, (ok, why) in (
            ('ends on a bare `end`', ends_on_bare_end(body)),
            ('holds exactly one function header', one_header(body, name)),
            ('block-balanced, closes once', balance_closes_once(body))):
        check('%s %s' % (label, what), ok, why)


print('=== 1. source_constants.function_body (the shared one) ===')
try:
    import source_constants as SC
except Exception as exc:                                     # pragma: no cover
    print('UNCERTIFIABLE -- cannot import source_constants: %s' % exc)
    sys.exit(2)

# The functions production actually slices through this reader (tbearly,
# tpgap, and the registry test), plus the two that showed the over-read.
for _fn in ('J.IsLateGame',                       # tbearly_domain.py
            'J.ShouldNotTpUnderLethalPressure',   # tpgap_domain.py
            'J.ShouldInitiateLaneKill',           # registry
            'J.ShouldTpSupportTowerFight',        # registry
            'J.IsWastefulItemTrip',               # over-read 16 code lines
            'J.IsCore'):                          # over-read 1 code line
    pin('function_body(%s)' % _fn, SC.function_body(_fn, path=JMZ), _fn)

# The reader must still be LOUD when a body never closes.  A silent
# run-to-end-of-file is the shape this whole file exists to keep out.
try:
    SC.function_span('function J.Broken( bot )\n\tif x then\n', 0, 'J.Broken')
    check('function_span raises on a body that never closes', False,
          'it returned instead')
except SC.SourceConstantError:
    check('function_span raises on a body that never closes', True)

# Section 2's claim ("no code between the `end` and the next declaration" is
# NOT assumed) restated as a live reading: the reader must not depend on it.
_src = read(JMZ)
_st = re.search(r'^function J\.IsWastefulItemTrip\s*\(', _src, re.M).start()
_nxt = re.compile(r'^function\s', re.M).search(_src, _st + 1)
_old = _src[_st:_nxt.start()]
check('the old "next ^function" terminator really did over-read (why this changed)',
      len([ln for ln in _old[len(SC.function_body('J.IsWastefulItemTrip',
                                                  path=JMZ)):].split('\n')
           if ln.strip() and not ln.strip().startswith('--')]) > 0,
      'if this goes false the Lua moved; the fix is still right, drop this row')

print('=== 2. blinkflee_domain._fn_body ===')
try:
    import blinkflee_domain as BF
except Exception as exc:                                     # pragma: no cover
    print('UNCERTIFIABLE -- cannot import blinkflee_domain: %s' % exc)
    sys.exit(2)

_bf_name = 'J.ShouldHoldBlinkFlee'
# Its _fn_body returns the body WITHOUT the header (group 1), so the header
# claim is checked on the header+body span it implies.
_bf_body = BF._fn_body(_src, _bf_name)
check('blinkflee: slice is non-empty', bool(_bf_body and _bf_body.strip()))
check('blinkflee: no other function header inside',
      re.findall(r'^function\s+([\w.:]+)', _bf_body, re.M) == [],
      'headers: %s' % re.findall(r'^function\s+([\w.:]+)', _bf_body, re.M)[:3])
check('blinkflee: stops where block counting stops',
      _src[_src.find(_bf_body) + len(_bf_body):].lstrip('\n').startswith('end'),
      'the text right after the slice is not the closing `end`')
# The row above is NOT sufficient on its own, and the mutation stand is how
# that was found rather than argued: a slice truncated at the FIRST `end`
# anywhere -- one line into the body, at a one-line `if ... end` -- also has
# `end` sitting right after it, and passed.  What separates a body from a
# prefix of one is that a body closes every block it opens, leaving only the
# `function` itself open.
_bf_header = re.search(r'^function\s+' + re.escape(_bf_name) + r'\s*\([^)]*\)',
                       _src, re.M).group(0)
check('blinkflee: the slice closes every block it opens (depth 1 = the function)',
      depth_of(_bf_header + _bf_body) == 1,
      'net depth %d -- the slice is a prefix of the body, not the body'
      % depth_of(_bf_header + _bf_body))

print('=== 3. slotpush_domain._fn_body ===')
try:
    import slotpush_domain as SP
except Exception as exc:                                     # pragma: no cover
    print('UNCERTIFIABLE -- cannot import slotpush_domain: %s' % exc)
    sys.exit(2)

_u = SP._strip_lua_comments(read(UTILS))
_j = SP._strip_lua_comments(read(JMZ))
pin('slotpush(____exports.IsTeamPushingSecondTierOrHighGround)',
    SP._fn_body(_u, r'^function ____exports\.IsTeamPushingSecondTierOrHighGround\s*\('),
    '____exports.IsTeamPushingSecondTierOrHighGround')
pin('slotpush(J.IsTeamPushingHighGround)',
    SP._fn_body(_j, r'^function J\.IsTeamPushingHighGround\s*\('),
    'J.IsTeamPushingHighGround')

print('=== 4. wkqdmg_domain._fn_body (fixed 2026-09-06) ===')
try:
    import wkqdmg_domain as WKD
except Exception as exc:                                     # pragma: no cover
    print('UNCERTIFIABLE -- cannot import wkqdmg_domain: %s' % exc)
    sys.exit(2)

_wk = read(WK)
for _fn in ('wk_GetBlastKillDamage', 'SkillsComplement', 'GetRoshanManaFloor'):
    pin('wkqdmg(X.%s)' % _fn, WKD._fn_body(_wk, _fn), 'X.' + _fn)

# The incident itself, as a row: the gate inside that body names exactly the
# one id.  `wkbonefight` (a DIFFERENT helper's gate, 400+ lines further down)
# reappearing here means the splitter ran on again.
_ids = re.findall(r"IsSoakCandidate\(\s*'([a-z0-9_]+)'\s*\)",
                  WKD._fn_body(_wk, 'wk_GetBlastKillDamage') or '')
check("wkqdmg: the sliced body's gate ids are exactly ['wkqdmg']",
      _ids == ['wkqdmg'], 'read %s' % _ids)

print()
print('%d check(s), %d failed' % (checks, len(fails)))
if fails:
    for f in fails:
        print('  FAILED: %s' % f)
    sys.exit(1)
sys.exit(0)

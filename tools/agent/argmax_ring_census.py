#!/usr/bin/env python3
"""Census: the `most dangerous enemy` argmax -- for every copy in `bots/`, is
the ring it SEARCHES the ring it is willing to ACCEPT?

Why this exists (hero group, 2026-09-17; queue `hero-102` cell (甲), GH #873)
---------------------------------------------------------------------------
GH #873 found the same argmax body, byte for byte, three times inside the five
focus heroes, with three DIFFERENT reach postures and two failures of OPPOSITE
sign:

    Crystal Maiden  search `nCastRange`         no winner test   correct
    Wraith King     search `nCastRange + 43`    no winner test   over-reach 43u
    Lion            search `nCastRange + 300`   winner `+50`     self-veto 250u

"The shape travelled, the term that made the shape safe did not."  The census
#873 asked for is the one question that says how big that is:

    ⭐ the right question for this family is NOT "does this branch test
       distance" -- it is "is the ring it searches the ring it will accept".

⛔ WHY THE OBVIOUS GREP WALKS PAST HALF OF THEM (the立案 sentence of #873).
Both of the known bad postures are invisible to a one-directional search.  A
hunt for "which firing site has NO distance test" finds Wraith King and walks
past Lion -- Lion HAS one, eight lines down.  A hunt for "which site HAS one"
finds Lion and walks past Wraith King.  The failures have opposite sign, so a
single-direction census finds at most half.  This script therefore reports the
PAIR (search ring, admission ring) for every copy and classifies from the pair,
never from the presence or absence of one member.

WHAT THIS SCRIPT MEASURES (one row per copy)
--------------------------------------------
  (1) SEARCH RING.  The list the argmax loop walks, resolved back to its
      `local <list> = J.GetNearbyHeroes(bot, <ring>, ...)` definition inside the
      same function, and the ring expression parsed as `<base> [+ <delta>]`.
  (2) ADMISSION RING.  A distance predicate on the chosen unit, in EITHER of
      the two places one can sit:
        - IN-LOOP, inside the filter (this is the shape that cannot self-veto,
          because a rejected candidate does not win -- the loop falls back);
        - POST-LOOP, on the winner only (this is Lion's shape: the winner is
          re-tested after it has already displaced the runner-up, so a reject
          kills the whole branch instead of falling back).
      The PLACE is part of the reading, not a detail: same predicate, different
      failure mode.
  (3) THE VERDICT for the pair, and the count this census exists to produce:
      how many copies have SEARCH != ADMISSION.
  (4) ⭐ SHARED-LIST FANOUT (the column `-199` added after GH #873).  How many
      OTHER reads of that same list variable there are, and how many of those
      are shipping sites (a `return ... BOT_ACTION_DESIRE` inside the block that
      reads it).  The scan range follows the list's own SCOPE -- the enclosing
      function for a `local`, the whole file for a module-scope upvalue -- so
      the number is the real number of co-owners, not an artifact of where the
      reader happened to look.  The reason this column exists is a measured one:
      a gap found at this leg may not be THIS leg's to fix, because the list it
      reads is built for somebody else and widening or narrowing it moves every
      other consumer too.  Lion's own sibling lever `lionwreach`
      (hero_lion.lua:1008) is exactly that case -- one wide list, two interrupt
      legs -- and it is why the first census walked past this one.
  (5) ATTRIBUTION.  focus-five / other-hero / rubick-copy, printed per row,
      because the queue cell says 归属先查: most copies are in files this group
      does not own.

⚠️ LIMIT A -- THIS IS A SOURCE CENSUS AND SAYS NOTHING ABOUT FREQUENCY.
`-197` already falsified the natural expectation here, on corpus:  "has no
winner test" does NOT imply "has frames to buy".  Measured then: Crystal Maiden
2 of 51 surviving moments clear the teamfight predicate, Wraith King 0 of 36.
A row in this table is a shape, never a domain.  Do not read a count off it and
call it a rate.

⚠️ LIMIT B -- THE RESOLVER REFUSES RATHER THAN GUESSES, AND A REFUSAL IS
COUNTED AS NEITHER.  The list variable is resolved by the nearest preceding
`local <list> =` inside the enclosing function, falling back to a file-level
assignment for a module-scope upvalue (riki's `hEnemyList`); the ring is parsed
only out of the builder shapes the tree actually uses at these sites
(`J.GetNearbyHeroes`, `bot:GetNearby*`, `J.GetEnemyList`, and a
`J.CombineTwoTable` union resolved through BOTH operands).  A ring whose base is
never assigned from `GetCastRange()` -- including a bare literal like `1600` --
is `UNCOMPARABLE`, NOT `CONSISTENT`: source alone cannot say whether a fixed
1600u search ring is inside the cast range.  ⛔ The census never trusts the
house naming convention: `nCastRange` earns its meaning from an assignment, not
from its spelling.  `UNRESOLVED`, `UNCOMPARABLE` and `PAIR-UNCOMPARABLE` rows
are counted in neither the matching nor the mismatching total, and printed.

⚠️ LIMIT C -- `nCastRange` CAN BE REASSIGNED ABOVE THE SITE, AND A ROW WHOSE
BASE WAS REASSIGNED SAYS SO.  Wraith King rewrites `nCastRange` (`+260` against
a long-attack-range enemy) and Crystal Maiden rewrites it (to attack range) on
the lines above their own lists.  Both rewrites happen BEFORE the list is
built, so the `base + delta` reading stays exact for the pair comparison -- the
same `nCastRange` flows into both members.  The column `base_rebound` records
it anyway, because a reader comparing a delta ACROSS heroes must know that the
two bases are not the same number.

⚠️ LIMIT D -- an aether-lens term is NOT modelled.  `tests/test_cast_ring_
mirror_discipline.lua [2]` already caught this group writing `GetCastRange()`
where the shipped branch writes `GetCastRange() + aetherRange`; that ratchet
governs re-implementations of a cast ring.  This census never computes a ring
in units -- it compares two SOURCE EXPRESSIONS for identity -- so the aether
term cancels whenever it appears in both, and a row where it appears in only
one member is reported as a mismatch with both expressions printed verbatim.

Usage:
    python3 tools/agent/argmax_ring_census.py            # table + the number
    python3 tools/agent/argmax_ring_census.py --json
    python3 tools/agent/argmax_ring_census.py --selfcheck   # parser self-tests
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# ⛔ Every corpus read goes through lua_corpus (GH #243 / GH #856): listing
# `bots/**.lua` and `open()`ing the paths later is a race with a MEASURED
# failure rate, because the 16 Lua gate tests create and delete
# `bots/Customize/soak_side.lua` mid-run.  A file that vanishes between the
# listing and the read makes this census DID-NOT-RUN (exit 2), never a
# different count.
from lua_corpus import (  # noqa: E402
    UNCERTIFIABLE_EXIT, CorpusVanished, bots_lua_relpaths, read_lua, uncertifiable)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The needle.  GH #873 anchors the family on this literal seed line; every copy
# in the tree writes it identically (the one Lion site whose SEED is gated still
# writes this line, because `lionwseed` gates the value on the NEXT line).
SEED_RE = re.compile(r'^\s*local npcMostDangerousEnemy = nil\s*$')

WINNER_RE = re.compile(r'npcMostDangerousEnemy\s*~=\s*nil')
FOR_RE = re.compile(r'\bfor\s+[\w,\s]+\s+in\s+pairs\s*\(\s*([\w.]+)\s*\)')
ASSIGN_RE = re.compile(r'^\s*npcMostDangerousEnemy\s*=\s*(\w+)\s*$')
FUNC_RE = re.compile(r'^(local\s+)?function\b')

FOCUS_FILES = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_zuus.lua',
    'bots/BotLib/hero_skeleton_king.lua',
    'bots/BotLib/hero_lion.lua',
    'bots/BotLib/hero_crystal_maiden.lua',
}


def strip_lua(line):
    """Drop a `--` comment tail and blank out string literals.

    Only what the block counter and the predicate scanner need.  Long-bracket
    comments (`--[[ ]]`) are handled by the caller, which tracks them across
    lines; this function is line-local.
    """
    out = []
    i = 0
    n = len(line)
    quote = None
    while i < n:
        c = line[i]
        if quote:
            out.append(' ')
            if c == '\\':
                i += 2
                out.append(' ')
                continue
            if c == quote:
                quote = None
                out[-1] = c
            i += 1
            continue
        if c in ('"', "'"):
            quote = c
            out.append(c)
            i += 1
            continue
        if c == '-' and i + 1 < n and line[i + 1] == '-':
            break
        out.append(c)
        i += 1
    return ''.join(out)


def clean_lines(text):
    """Comment- and string-stripped view of the file, one entry per source line.

    Long-bracket comments are removed across lines.  The result keeps line
    numbering identical to the raw file so every reported line number is the
    number a reader will see in an editor.
    """
    raw = text.split('\n')
    out = []
    in_long = False
    for line in raw:
        if in_long:
            if ']]' in line:
                in_long = False
                out.append(strip_lua(line.split(']]', 1)[1]))
            else:
                out.append('')
            continue
        s = strip_lua(line)
        if '--[[' in line and ']]' not in line.split('--[[', 1)[1]:
            in_long = True
            out.append(strip_lua(line.split('--[[', 1)[0]))
            continue
        out.append(s)
    return raw, out


_OPEN_KW = re.compile(r'\b(then|do|function|repeat)\b')
_CLOSE_KW = re.compile(r'\b(end|until)\b')
_ELSEIF = re.compile(r'\belseif\b')


def block_depths(clean):
    """Per-line (depth_before, depth_after) using Lua's own block keywords.

    `then`/`do`/`function`/`repeat` open, `end`/`until` close; an `elseif ...
    then` carries a `then` that continues a block rather than opening one, so
    its `then` is discounted.  `--selfcheck` asserts the depth returns to 0 at
    end of file for every file this census parses, which is the whole reason
    this hand-rolled counter is allowed to stand in for a Lua parser.
    """
    depths = []
    d = 0
    for s in clean:
        opens = len(_OPEN_KW.findall(s)) - len(_ELSEIF.findall(s))
        closes = len(_CLOSE_KW.findall(s))
        depths.append((d, d + opens - closes))
        d += opens - closes
    return depths, d


def split_args(s):
    """Split a call's argument text on TOP-LEVEL commas."""
    args, depth, cur = [], 0, []
    for c in s:
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        if c == ',' and depth == 0:
            args.append(''.join(cur).strip())
            cur = []
        else:
            cur.append(c)
    args.append(''.join(cur).strip())
    return args


def call_args(text, start):
    """Text between the parens of a call whose `(` is at/after `start`."""
    i = text.find('(', start)
    if i < 0:
        return None
    depth = 0
    for j in range(i, len(text)):
        if text[j] == '(':
            depth += 1
        elif text[j] == ')':
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
    return None


# The list-builder shapes the tree actually uses at these sites.  Anything else
# is UNRESOLVED on purpose (LIMIT B).
#   J.GetNearbyHeroes(bot, R, ...)      ring is arg 2
#   bot:GetNearby*(R, ...)              ring is arg 1
#   J.GetEnemyList(bot, R)              ring is arg 2, and the HELPER CLAMPS IT
#                                       at 1600 (jmz_func.lua:4506) -- a fact
#                                       the caller's own text does not carry.
#   J.CombineTwoTable(A, B)             the union of two lists: resolved by
#                                       resolving BOTH operands, never by
#                                       picking one.
_NEARBY_J = re.compile(r'J\.GetNearbyHeroes\s*\(')
_NEARBY_BOT = re.compile(r'bot:GetNearby(Heroes|Creeps|Towers|LaneCreeps)\s*\(')
_ENEMY_LIST = re.compile(r'J\.GetEnemyList\s*\(')
_COMBINE = re.compile(r'J\.CombineTwoTable\s*\(')
GET_ENEMY_LIST_CLAMP = 1600.0


def ring_of_rhs(rhs):
    """(ring_expr, how) for a list-builder right-hand side, or (None, why)."""
    m = _NEARBY_J.search(rhs)
    if m:
        args = call_args(rhs, m.start())
        if args is None:
            return None, 'unparsable-call'
        parts = split_args(args)
        if len(parts) < 2:
            return None, 'arity'
        return parts[1].strip(), 'J.GetNearbyHeroes'
    m = _ENEMY_LIST.search(rhs)
    if m:
        args = call_args(rhs, m.start())
        if args is None:
            return None, 'unparsable-call'
        parts = split_args(args)
        if len(parts) < 2:
            return None, 'arity'
        return parts[1].strip(), 'J.GetEnemyList (clamped at %g by the helper)' % GET_ENEMY_LIST_CLAMP
    m = _NEARBY_BOT.search(rhs)
    if m:
        args = call_args(rhs, m.start())
        if args is None:
            return None, 'unparsable-call'
        parts = split_args(args)
        if not parts:
            return None, 'arity'
        return parts[0].strip(), 'bot:GetNearby*'
    return None, 'not-a-list-builder'


_BASE_DELTA = re.compile(r'^([A-Za-z_]\w*)\s*\+\s*(\d+(?:\.\d+)?)$')
_BASE_ONLY = re.compile(r'^([A-Za-z_]\w*)$')
_MATH_MIN = re.compile(r'^math\.min\s*\(')
LITERAL_BASE = '<literal>'


def parse_ring(expr):
    """(base, delta, note) -- refuses rather than guesses (LIMIT B)."""
    if expr is None:
        return None, None, 'none'
    e = ' '.join(expr.split())
    if _MATH_MIN.match(e):
        inner = call_args(e, 0)
        if inner is not None:
            parts = split_args(inner)
            if len(parts) == 2:
                b, d, _ = parse_ring(parts[0])
                if b is not None:
                    return b, d, 'clamped by math.min(_, %s)' % parts[1]
        return None, None, 'math.min-unparsed'
    m = _BASE_DELTA.match(e)
    if m:
        return m.group(1), float(m.group(2)), ''
    m = _BASE_ONLY.match(e)
    if m:
        return m.group(1), 0.0, ''
    if re.match(r'^\d+(\.\d+)?$', e):
        return LITERAL_BASE, float(e), ''
    return None, None, 'unmodelled-expression'


# Distance predicates, as the tree writes them.
def distance_predicates(text, unit):
    """Ring expressions of every distance test on `unit` inside `text`."""
    found = []
    u = re.escape(unit)
    for m in re.finditer(r'J\.IsInRange\s*\(', text):
        args = call_args(text, m.start())
        if args is None:
            continue
        parts = split_args(args)
        if len(parts) == 3 and unit in (parts[0], parts[1]) and 'bot' in (parts[0], parts[1]):
            found.append(parts[2].strip())
    for m in re.finditer(
        r'GetUnitToUnitDistance\s*\(([^)]*)\)\s*(<=|<)\s*([^\s)]+(?:\s*\+\s*\d+)?)', text
    ):
        inner = [p.strip() for p in m.group(1).split(',')]
        if unit in inner and 'bot' in inner:
            found.append(m.group(3).strip())
    for m in re.finditer(r'%s:GetLocation\(\)' % u, text):
        pass  # location-only reads are not a distance test; recorded nowhere
    return found


def resolve_list(clean, list_name, for_idx, fn_start, n):
    """(rhs, def_line_idx, scope) for the list the argmax walks.

    Two scopes, and the difference is the whole point of column (4): a
    function-local list is this leg's to widen or narrow, a FILE-LEVEL upvalue
    (riki's `hEnemyList`, declared at module scope and refilled once per frame)
    is shared with every other leg in the file, so the same gap may not be this
    leg's to fix at all.
    """
    if not list_name:
        return None, None, None
    pat = re.compile(r'^\s*(local\s+)?%s\s*=\s*(.+)$' % re.escape(list_name))
    for i in range(for_idx, fn_start - 1, -1):
        m = pat.match(clean[i])
        if m:
            return m.group(2).strip(), i, 'function-local'
    # not in this function: look for the file-level assignment
    for i in range(n):
        m = pat.match(clean[i])
        if m and ring_of_rhs(m.group(2).strip())[0] is not None:
            return m.group(2).strip(), i, 'file-upvalue'
    return None, None, None


def resolve_ring(rhs, clean, def_idx, fn_start, n):
    """(ring_expr, builder, base, delta, note), following a CombineTwoTable."""
    m = _COMBINE.search(rhs)
    if m:
        args = call_args(rhs, m.start())
        parts = split_args(args) if args else []
        if len(parts) == 2:
            legs = []
            for name in parts:
                sub_rhs, sub_idx, _scope = resolve_list(clean, name.strip(), def_idx, fn_start, n)
                if sub_rhs is None:
                    legs = None
                    break
                sub_ring, _how = ring_of_rhs(sub_rhs)
                sub_base, sub_delta, _nt = parse_ring(sub_ring)
                if sub_base is None:
                    legs = None
                    break
                legs.append((name.strip(), sub_ring, sub_base, sub_delta))
            if legs and legs[0][2] == legs[1][2]:
                # same base: the union's outer ring is the wider of the two
                wide = max(legs, key=lambda t: t[3])
                return (wide[1], 'J.CombineTwoTable(%s, %s)' % (parts[0].strip(), parts[1].strip()),
                        wide[2], wide[3],
                        'union of %s=%s and %s=%s; the wider one is the search ring'
                        % (legs[0][0], legs[0][1], legs[1][0], legs[1][1]))
            return None, 'J.CombineTwoTable', None, None, 'union operands did not both resolve to one base'
    ring, how = ring_of_rhs(rhs)
    base, delta, note = parse_ring(ring)
    if base and base != LITERAL_BASE and how.startswith('J.GetEnemyList'):
        note = (note + '; ' if note else '') + 'helper clamps the ring at %g' % GET_ENEMY_LIST_CLAMP
    return ring, how, base, delta, note


def base_is_cast_range(clean, base, fn_start, fn_end, n):
    """Is the ring's base the function's own cast range?

    ⛔ The census never assumes this from the NAME.  `nCastRange` is the house
    convention, not a guarantee, and the verdict CONSISTENT for a bare base is
    only earned if the base really is the castable ring.  Answered by looking
    for an assignment of that identifier from `GetCastRange()` inside the
    function (file scope as a fallback, for the upvalue case).
    """
    if not base or base == LITERAL_BASE:
        return False
    pat = re.compile(r'^\s*(local\s+)?%s\s*=\s*.*GetCastRange\s*\(' % re.escape(base))
    for i in range(fn_start, min(fn_end + 1, n)):
        if pat.match(clean[i]):
            return True
    for i in range(n):
        if pat.match(clean[i]):
            return True
    return False


def binding_scopes(clean, depths, name, lo, hi, n):
    """Every `local <name> =` binding in [lo, hi] as (decl_line, scope_end).

    ⛔ WHY THIS EXISTS, MEASURED ON A ROW OF THIS CENSUS'S OWN FIRST OUTPUT.
    The fanout column's first version counted every textual occurrence of the
    list's name inside the function, and reported `nInRangeEnemy` in
    hero_arc_warden.lua as having 13 co-readers.  Hand-checking the file says
    that name is re-declared as a DIFFERENT `local` four times in the same
    function (lines 294, 306, 395, 532), each with its own ring -- one of them
    is not even built around `bot`.  A name-based count silently merged four
    variables into one and turned "this leg owns its list" into "this leg
    shares its list with twelve others", which is exactly the conclusion the
    column exists to inform.  A read therefore counts only if THIS binding is
    the one in scope at that line.
    """
    decl = re.compile(r'^\s*local\s+%s\s*=' % re.escape(name))
    out = []
    for i in range(lo, min(hi + 1, n)):
        if not decl.match(clean[i]):
            continue
        d = depths[i][0]
        end = hi
        for j in range(i + 1, min(hi + 1, n)):
            if depths[j][1] < d:
                end = j
                break
        out.append((i, end))
    return out


def binding_owner(scopes, line_idx):
    """The innermost binding in scope at line_idx, or None."""
    best = None
    for decl, end in scopes:
        if decl <= line_idx <= end:
            if best is None or decl > best[0]:
                best = (decl, end)
    return best[0] if best else None


def enclosing_function(clean, line_idx):
    for i in range(line_idx, -1, -1):
        if FUNC_RE.match(clean[i]):
            return i
    return 0


def function_end(depths, start_idx, n):
    """Index of the `end` that closes the function starting at start_idx."""
    base = depths[start_idx][0]
    for i in range(start_idx + 1, n):
        if depths[i][1] <= base:
            return i
    return n - 1


def attribution(relpath):
    if '/rubick_hero/' in relpath:
        return 'rubick-copy'
    if relpath in FOCUS_FILES:
        return 'focus-five'
    return 'other-hero'


def innermost_block(depths, line_idx, fn_start, fn_end):
    """(start, end) of the innermost block containing line_idx."""
    d = depths[line_idx][0]
    start = fn_start
    for i in range(line_idx, fn_start - 1, -1):
        if depths[i][1] == d and depths[i][0] == d - 1:
            start = i
            break
    end = fn_end
    for i in range(line_idx, fn_end + 1):
        if depths[i][1] < d:
            end = i
            break
    return start, end


def census(root=ROOT):
    rows = []
    unresolved = []
    for rel in bots_lua_relpaths(root):
        text = read_lua(os.path.join(root, rel))
        if 'local npcMostDangerousEnemy = nil' not in text:
            continue
        raw, clean = clean_lines(text)
        depths, _tail = block_depths(clean)
        n = len(clean)
        for i, line in enumerate(clean):
            if not SEED_RE.match(line):
                continue
            rows.append(read_site(rel, raw, clean, depths, n, i, unresolved))
    rows.sort(key=lambda r: (r['file'], r['line']))
    return rows, unresolved


def read_site(rel, raw, clean, depths, n, seed_idx, unresolved):
    fn_start = enclosing_function(clean, seed_idx)
    fn_end = function_end(depths, fn_start, n)
    row = {
        'file': rel,
        'line': seed_idx + 1,
        'attribution': attribution(rel),
        'function': ' '.join(raw[fn_start].split()),
    }

    # --- the loop and the list it walks -----------------------------------
    for_idx, list_name = None, None
    for i in range(seed_idx, min(seed_idx + 12, n)):
        m = FOR_RE.search(clean[i])
        if m:
            for_idx, list_name = i, m.group(1)
            break
    row['list'] = list_name
    row['for_line'] = for_idx + 1 if for_idx is not None else None
    if for_idx is None:
        row['verdict'] = 'UNRESOLVED'
        row['why'] = 'no argmax loop found within 12 lines of the seed'
        unresolved.append(row)
        return row

    # --- winner test (post-loop) ------------------------------------------
    win_idx = None
    for i in range(for_idx, min(fn_end + 1, n)):
        if WINNER_RE.search(clean[i]):
            win_idx = i
            break
    row['winner_line'] = win_idx + 1 if win_idx is not None else None

    # --- the element variable and where the argmax assigns it -------------
    elem = None
    assign_idx = None
    for i in range(for_idx, win_idx if win_idx is not None else fn_end):
        m = ASSIGN_RE.match(clean[i])
        if m:
            elem, assign_idx = m.group(1), i
            break
    row['elem'] = elem

    # --- resolve the list variable to its definition -----------------------
    rhs, def_idx, scope = resolve_list(clean, list_name, for_idx, fn_start, n)
    row['list_def_line'] = def_idx + 1 if def_idx is not None else None
    row['list_rhs'] = rhs
    row['list_scope'] = scope
    if rhs is None:
        row['verdict'] = 'UNRESOLVED'
        row['why'] = 'list `%s` has no assignment anywhere in the file (parameter or engine-side)' % list_name
        row['search_ring'] = None
        row['admission_ring'] = None
        unresolved.append(row)
        return row

    ring, how, base, delta, note = resolve_ring(rhs, clean, def_idx, fn_start, n)
    row['search_ring'] = ring
    row['search_builder'] = how
    row['search_base'] = base
    row['search_delta'] = delta
    row['search_note'] = note

    # --- admission: in-loop filter, then post-loop winner test -------------
    loop_text = '\n'.join(clean[for_idx:(assign_idx if assign_idx is not None else for_idx)])
    in_loop = distance_predicates(loop_text, elem) if elem else []
    post = []
    if win_idx is not None:
        # the winner `if` condition runs from the `~= nil` line to its `then`
        j = win_idx
        while j < n and 'then' not in clean[j]:
            j += 1
        post = distance_predicates('\n'.join(clean[win_idx:j + 1]), 'npcMostDangerousEnemy')
    row['admission_in_loop'] = in_loop
    row['admission_post_loop'] = post
    if in_loop:
        row['admission_ring'] = in_loop[0]
        row['admission_place'] = 'in-loop'
    elif post:
        row['admission_ring'] = post[0]
        row['admission_place'] = 'post-loop'
    else:
        row['admission_ring'] = None
        row['admission_place'] = 'none'
    a_base, a_delta, a_note = parse_ring(row['admission_ring'])
    row['admission_base'] = a_base
    row['admission_delta'] = a_delta

    # --- was the base reassigned above the list? (LIMIT C) -----------------
    row['base_rebound'] = False
    if base and def_idx is not None:
        pat = re.compile(r'^\s*%s\s*=\s*' % re.escape(base))
        for i in range(fn_start, def_idx):
            if pat.match(clean[i]):
                row['base_rebound'] = True
                break
    row['base_is_cast_range'] = base_is_cast_range(clean, base, fn_start, fn_end, n)

    # --- shared-list fanout (column (4)) -----------------------------------
    # ⭐ The scan RANGE follows the list's own scope.  A function-local list is
    # shared only with the rest of its function; a file-level upvalue (riki's
    # `hEnemyList`, refilled once per frame at module scope) is shared with
    # every leg in the file, and counting it per-function would report 1 where
    # the real number is 9.
    reads, shippers = [], set()
    scan_lo, scan_hi = (0, n - 1) if scope == 'file-upvalue' else (fn_start, fn_end)
    row['fanout_scope'] = 'file' if scope == 'file-upvalue' else 'function'
    shadowed = 0
    if list_name:
        word = re.compile(r'(?<![\w.])%s(?![\w])' % re.escape(list_name))
        scopes = binding_scopes(clean, depths, list_name, scan_lo, scan_hi, n)
        for i in range(scan_lo, min(scan_hi + 1, n)):
            if i in (def_idx, for_idx):
                continue
            if not word.search(clean[i]):
                continue
            if scopes and binding_owner(scopes, i) != def_idx:
                shadowed += 1
                continue
            reads.append(i + 1)
            b_start, b_end = innermost_block(depths, i, scan_lo, scan_hi)
            if any('BOT_ACTION_DESIRE' in clean[k] and 'return' in clean[k]
                   for k in range(i, min(b_end + 1, n))):
                shippers.add((b_start, b_end))
    row['other_reads'] = reads
    # ⭐ The queue's question is "how many OTHER SHIPPING SITES read this list",
    # so the unit is the BLOCK, not the line: eight lines of one `if` whose body
    # ends in a single `return ... DESIRE` are one shipping site, not eight.
    row['other_shipping_sites'] = len(shippers)
    row['shadowed_reads'] = shadowed

    # --- the verdict for the pair ------------------------------------------
    row['verdict'], row['why'] = classify(row)
    if row['verdict'] == 'UNRESOLVED':
        unresolved.append(row)
    return row


def classify(row):
    """The pair's verdict.  Never reads one member alone (the #873 lesson).

    The verdicts are named after the CONSEQUENCE, not after "the rings differ",
    because the rings differing is benign in one of the two places the test can
    sit.  Both readings are reported: `rings_differ` answers the queue's literal
    question, the verdict answers what it costs.
    """
    s_expr, a_expr = row.get('search_ring'), row.get('admission_ring')
    s_base, s_delta = row.get('search_base'), row.get('search_delta')
    a_base, a_delta = row.get('admission_base'), row.get('admission_delta')
    if s_expr is None or s_base is None:
        return 'UNRESOLVED', 'search ring not parsable from `%s`' % (row.get('list_rhs') or '')[:70]
    if a_expr is None:
        # No admission test anywhere: the searched ring IS the accepted ring, so
        # the question becomes whether it is the CASTABLE ring.
        if s_base == LITERAL_BASE:
            return ('UNCOMPARABLE',
                    'no winner test and the searched ring is the bare literal %g -- source cannot '
                    'say whether that is inside the cast range' % s_delta)
        if not row.get('base_is_cast_range'):
            return ('UNCOMPARABLE',
                    'no winner test and the searched ring is `%s`, whose base is never assigned '
                    'from GetCastRange() -- not comparable to a cast ring from source' % s_expr)
        if s_delta == 0:
            return 'CONSISTENT', 'no winner test, and the searched ring is exactly the cast range `%s`' % s_base
        return ('OVER-REACH',
                'no winner test and the searched ring is `%s` => can bid up to %gu outside cast range'
                % (s_expr, s_delta))
    if a_base is None:
        return 'UNRESOLVED', 'admission ring not parsable from `%s`' % a_expr
    if row.get('admission_place') == 'in-loop':
        # A test inside the filter cannot self-veto: a rejected candidate never
        # wins, so the argmax falls back to the next one.  Benign by shape,
        # whatever the two rings are.
        if a_base == s_base and a_delta == s_delta:
            return 'CONSISTENT', 'search and admission are the same ring `%s`' % s_expr
        return ('FILTERED',
                'the reach test sits INSIDE the loop filter (`%s`), so an out-of-reach candidate '
                'never wins and the argmax falls back -- differing rings are benign here' % a_expr)
    if a_base != s_base:
        return ('PAIR-UNCOMPARABLE',
                'winner-only test, and the two rings have different bases (`%s` vs `%s`) -- source '
                'cannot order them' % (s_expr, a_expr))
    if s_delta == a_delta:
        return 'CONSISTENT', 'search and admission are the same ring `%s`' % s_expr
    if s_delta > a_delta:
        gap = s_delta - a_delta
        return ('SELF-VETO',
                'winner-only test %gu tighter than the searched ring => a candidate in the %gu '
                'annulus can WIN and then be rejected, and the branch does NOT fall back'
                % (gap, gap))
    return ('VACUOUS-TEST',
            'winner-only test is %gu WIDER than the searched ring => it can never reject anything'
            % (a_delta - s_delta))


# The verdicts whose two rings differ (the queue's literal question) and, within
# them, the ones that cost something.
DIFFER_VERDICTS = ('OVER-REACH', 'SELF-VETO', 'FILTERED', 'VACUOUS-TEST', 'PAIR-UNCOMPARABLE')
COSTLY_VERDICTS = ('OVER-REACH', 'SELF-VETO', 'VACUOUS-TEST')
UNRESOLVED_VERDICTS = ('UNRESOLVED', 'UNCOMPARABLE', 'PAIR-UNCOMPARABLE')


def fmt_table(rows):
    out = []
    hdr = ('%-44s %-6s %-12s %-22s %-22s %-11s %s'
           % ('file', 'line', 'attribution', 'search ring', 'admission ring', 'place', 'verdict'))
    out.append(hdr)
    out.append('-' * len(hdr))
    for r in rows:
        out.append('%-44s %-6s %-12s %-22s %-22s %-11s %s'
                   % (r['file'].replace('bots/BotLib/', 'BotLib/').replace('bots/FunLib/', 'FunLib/'),
                      r['line'], r['attribution'],
                      (r.get('search_ring') or '?')[:22],
                      (r.get('admission_ring') or '(none)')[:22],
                      r.get('admission_place', '?'),
                      r['verdict']))
    return '\n'.join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args(argv)

    try:
        if args.selfcheck:
            return selfcheck()
        rows, unresolved = census()
    except CorpusVanished as exc:
        # ⛔ 0 clean / 2 did-not-run / 3 findings -- a census that could not read
        # its input has NO answer, and must never print a smaller one.
        uncertifiable(exc, what='the argmax ring census')
        return UNCERTIFIABLE_EXIT
    if args.json:
        print(json.dumps({'rows': rows, 'unresolved': len(unresolved)},
                         ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    print(fmt_table(rows))
    print()
    counts = {}
    for r in rows:
        counts[r['verdict']] = counts.get(r['verdict'], 0) + 1
    differ = sum(counts.get(v, 0) for v in DIFFER_VERDICTS)
    costly = sum(counts.get(v, 0) for v in COSTLY_VERDICTS)
    unres = sum(counts.get(v, 0) for v in UNRESOLVED_VERDICTS)
    print('copies                          : %d' % len(rows))
    for v in sorted(counts):
        print('  %-30s: %d' % (v, counts[v]))
    print()
    print('⭐ THE NUMBER (queue hero-102 (甲)): search ring != admission ring in %d of %d copies'
          % (differ, len(rows)))
    print('   of those, the ones it COSTS something (over-reach / self-veto / vacuous): %d' % costly)
    print('   unresolved or uncomparable from source (counted as neither): %d' % unres)
    print()
    print('per-row detail (why, and the shared-list fanout column):')
    for r in rows:
        print('  %s:%d  [%s]  %s' % (r['file'], r['line'], r['verdict'], r['why']))
        print('      list `%s` def@%s (%s) | other reads in the same %s: %d lines / %d other'
              ' SHIPPING SITES | same name, other binding: %d%s'
              % (r.get('list'), r.get('list_def_line'), r.get('list_scope'),
                 r.get('fanout_scope') or 'function', len(r.get('other_reads') or []),
                 r.get('other_shipping_sites') or 0, r.get('shadowed_reads') or 0,
                 '  [base reassigned above the list]' if r.get('base_rebound') else ''))
    return 0


def selfcheck():
    """Parser self-tests.  Prints ALL PASS / a failure list; exit 0 / 1."""
    fails = []

    # 1. the block counter must close every file this census parses
    for rel in bots_lua_relpaths(ROOT):
        text = read_lua(os.path.join(ROOT, rel))
        if 'local npcMostDangerousEnemy = nil' not in text:
            continue
        _raw, clean = clean_lines(text)
        _depths, tail = block_depths(clean)
        if tail != 0:
            fails.append('block depth does not close on %s (tail=%d)' % (rel, tail))

    # 2. argument splitting is top-level only
    if split_args('bot, math.min(a, b), true') != ['bot', 'math.min(a, b)', 'true']:
        fails.append('split_args does not respect nesting')

    # 3. ring parsing refuses rather than guesses
    if parse_ring('nCastRange + 43')[:2] != ('nCastRange', 43.0):
        fails.append('parse_ring base+delta')
    if parse_ring('nCastRange')[:2] != ('nCastRange', 0.0):
        fails.append('parse_ring bare base')
    if parse_ring('nCastRange * 2')[0] is not None:
        fails.append('parse_ring should refuse an unmodelled expression')
    if parse_ring('math.min(nCastRange + 100, 1600)')[:2] != ('nCastRange', 100.0):
        fails.append('parse_ring math.min')

    # 4. a distance predicate is found in both argument orders and nowhere else
    if distance_predicates('J.IsInRange( bot, e, nCastRange + 50 )', 'e') != ['nCastRange + 50']:
        fails.append('distance_predicates bot-first')
    if distance_predicates('J.IsInRange( e, bot, nCastRange )', 'e') != ['nCastRange']:
        fails.append('distance_predicates unit-first')
    if distance_predicates('J.IsInRange( bot, other, nCastRange )', 'e') != []:
        fails.append('distance_predicates must not match another unit')

    # 5. the classifier reads the PAIR, never one member (the #873 lesson)
    over = classify({'search_ring': 'R + 43', 'search_base': 'R', 'search_delta': 43.0,
                     'base_is_cast_range': True,
                     'admission_ring': None, 'admission_place': 'none'})
    if over[0] != 'OVER-REACH':
        fails.append('classify: no admission + delta must be OVER-REACH')
    veto = classify({'search_ring': 'R + 300', 'search_base': 'R', 'search_delta': 300.0,
                     'admission_ring': 'R + 50', 'admission_base': 'R', 'admission_delta': 50.0,
                     'admission_place': 'post-loop'})
    if veto[0] != 'SELF-VETO':
        fails.append('classify: tighter POST-LOOP test must be SELF-VETO')
    filt = classify({'search_ring': 'R + 300', 'search_base': 'R', 'search_delta': 300.0,
                     'admission_ring': 'R', 'admission_base': 'R', 'admission_delta': 0.0,
                     'admission_place': 'in-loop'})
    if filt[0] != 'FILTERED':
        fails.append('classify: tighter IN-LOOP test must NOT be SELF-VETO')
    ok = classify({'search_ring': 'R', 'search_base': 'R', 'search_delta': 0.0,
                   'base_is_cast_range': True,
                   'admission_ring': None, 'admission_place': 'none'})
    if ok[0] != 'CONSISTENT':
        fails.append('classify: bare base with no test is CONSISTENT')

    # 6. a base that is never assigned from GetCastRange() is NOT comparable --
    #    the census must refuse rather than trust the house naming convention
    unc = classify({'search_ring': 'R', 'search_base': 'R', 'search_delta': 0.0,
                    'base_is_cast_range': False,
                    'admission_ring': None, 'admission_place': 'none'})
    if unc[0] != 'UNCOMPARABLE':
        fails.append('classify: a base with no GetCastRange() provenance must be UNCOMPARABLE')
    lit = classify({'search_ring': '1600', 'search_base': LITERAL_BASE, 'search_delta': 1600.0,
                    'admission_ring': None, 'admission_place': 'none'})
    if lit[0] != 'UNCOMPARABLE':
        fails.append('classify: a bare literal ring must be UNCOMPARABLE, never CONSISTENT')

    if fails:
        for f in fails:
            print('FAIL: %s' % f)
        return 1
    print('ALL PASS (%d checks)' % 14)
    return 0


if __name__ == '__main__':
    sys.exit(main())

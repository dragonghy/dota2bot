#!/usr/bin/env python3
"""Census for the (C) shape found by strategy 0NEXT13 / GH #821 (`tpstale`).

The shape, stated mechanically:

  (a) a function-level `local` is written inside some branch, and control can
      leave that branch WITHOUT the write being consumed (no `return` at the
      write's own statement depth after it, and no clear on the fall-through);
  (b) the same local has other write points in the same function;
  (c) a LATER, sibling branch fires on a BARE read of that local
      (`if v ~= nil` / `if v`), i.e. it never re-derives the conclusion the
      earlier branch reached.

In that configuration every conjunct of the earlier branch -- including any
gated veto guarding its write -- is bypassed on the frames where the earlier
branch wrote but did not fire: the veto guards the ASSIGNMENT, the firing
reads SOMEBODY ELSE'S assignment.

Why an automatic reader is needed at all: `check_armed_wiring.py` still calls
such a gate WIRED (a call site exists and the predicate can be true), the
inverse-gate census is satisfied (nothing is frozen false), and the gate's own
tests pass. The defect lives strictly between the two.

Two further criteria narrow (a)-(c) to the sites that can actually misfire:

  (d) the WRITE's own branch already tries to fire on the local behind EXTRA
      conjuncts -- without this, a plain fallback-selector cascade (one
      destination, several candidate sources, one fire at the bottom) matches
      (a)-(c) and is perfectly correct;
  (e) the two branches are not MODE-DISJOINT -- `nMode == BOT_MODE_X` and the
      mode-valued helpers below all read one per-frame `bot:GetActiveMode()`,
      so two branches demanding different modes cannot both run in the call
      that the local lives for.

Exit: 0 always (this is a reporting census, not a gate). Machine-readable
summary on the last line:
`CENSUS sites=<n> cross=<n> live=<n> files=<n> gated=<n>`, where **live** --
cross-branch and not mode-disjoint -- is the number that means anything.

LIMITS (read before quoting a number from this):
  * The depth model is keyword-based (`if/for/while/do/repeat/function` ...
    `end`/`until`), not a real Lua parser; `elseif` chains are treated as one
    block, and a write inside an `else` leg is attributed to the leg's depth.
    tests/test_stale_write_census.py §1 asserts every shipped file still
    closes to depth 0 -- when it does not, this census's zeros are silence,
    not evidence.
  * "no clear on fall-through" is checked only for a literal `<var> = nil`
    between the write and the read; a clear done by a helper is not seen.
  * The read classification is textual: only `if v` and `if v ~= nil` (plus
    trailing `then`, after multi-line conjunctions are joined) count as BARE.
    A read with extra conjuncts is not counted -- deliberate, and also why
    the site count is a LOWER BOUND, not a population.
  * One site per write: the reachable read wins, else the first disjoint one.
  * (e) only knows the mode vocabulary in MODE_PREDICATES plus literal
    `nMode ==` tests. A branch gated on a mode by some other spelling reads
    as unconstrained, i.e. as REACHABLE -- the safe direction.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import lua_corpus  # noqa: E402  (GH #856 -- see scan_paths)

LOCAL_DECL = re.compile(r'^\s*local\s+([A-Za-z_]\w*)\s*(=|$)')
ASSIGN = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*(.+)$')
FUNC_HEAD = re.compile(r'^\s*(?:local\s+)?function\s+([\w.:\[\]\'"]+)\s*\(')
# `X.ConsiderItemDesire["item_tpscroll"] = function( hItem )` -- the form the
# whole Consider* family uses, and the form the first draft of this census
# could not see (it found 4 sites and missed its own positive control).
# NOTE the `\s` inside the name class: strip_noise blanks string CONTENTS, so
# the head arrives here as `X.ConsiderItemDesire["      "] = function(`. Without
# it this regex missed every table-keyed Consider* in the repo -- which is to
# say, it missed the one function the census exists to find.
FUNC_ASSIGN_HEAD = re.compile(r'^\s*([\w.:\[\]\'"\s]+?)\s*=\s*function\s*\(')
BARE_READ = re.compile(r'^if\s+([A-Za-z_]\w*)\s*(?:~=\s*nil\s*)?(?:then)?$')
GATE_CALL = re.compile(r'J\.IsSoakCandidate\s*\(\s*[\'"]([\w]+)[\'"]')
MODE_EQ = re.compile(r'\bnMode\s*==\s*(BOT_MODE_\w+)')

# Mode-valued predicates, expanded so a branch head that says `J.IsDefending(
# bot )` can be compared against one that says `nMode == BOT_MODE_DEFEND_ALLY`.
# Both read the SAME per-frame value: `nMode = bot:GetActiveMode()` is assigned
# once per think in ability_item_usage_generic.lua:1127 and these helpers call
# `bot:GetActiveMode()` themselves (bots/FunLib/jmz_func.lua:1604 / :1632).
MODE_PREDICATES = {
    'J.IsDefending': {'BOT_MODE_DEFEND_TOWER_TOP', 'BOT_MODE_DEFEND_TOWER_MID',
                      'BOT_MODE_DEFEND_TOWER_BOT'},
    'J.IsPushing': {'BOT_MODE_PUSH_TOWER_TOP', 'BOT_MODE_PUSH_TOWER_MID',
                    'BOT_MODE_PUSH_TOWER_BOT'},
}


_NOISE = re.compile(r'"(?:\\.|[^"\\])*"?|\'(?:\\.|[^\'\\])*\'?|--.*')
_WORDS = re.compile(r'[A-Za-z_]\w*')


def _blank(m):
    """Same-length spaces for a string literal, nothing for a comment."""
    return '' if m.group(0).startswith('--') else ' ' * len(m.group(0))


def strip_noise(line):
    """Drop `--` comments and the contents of string literals.

    Offsets of everything left are preserved (literals become spaces of equal
    width) because Cleaner locates long-bracket openers by slicing the raw
    line and re-stripping the prefix.
    """
    return _NOISE.sub(_blank, line)


class Cleaner(object):
    """Line cleaner that also carries LONG-BRACKET state across lines.

    `strip_noise` alone is line-local, so a `--[[ ... ]]` comment block (or a
    `[[ ... ]]` string) donated its `if`/`end` words to the depth scanner:
    five shipped files -- `hero_skeleton_king.lua` worst at +13 -- never
    returned to depth 0, which means the census saw almost none of their
    functions and reported `live=0` for a reason that had nothing to do with
    the code. Caught by section 1 of tests/test_stale_write_census.py, which
    is why that section exists.
    """

    LONG_OPEN = re.compile(r'(--)?\[(=*)\[')

    def __init__(self):
        self.level = None

    def line(self, raw):
        out, rest = [], raw
        while True:
            if self.level is not None:
                close = ']' + '=' * self.level + ']'
                pos = rest.find(close)
                if pos < 0:
                    return ''.join(out)
                rest = rest[pos + len(close):]
                self.level = None
            m = self.LONG_OPEN.search(rest)
            if m is None:
                out.append(strip_noise(rest))
                return ''.join(out)
            # `--[[` IS the long-comment opener, so it must be taken even
            # though strip_noise would otherwise cut the line at the `--`.
            # (Getting this backwards left `Customize/general.lua` counting
            # the English word "if" in its own manual.) A bare `[[` counts
            # only if it survives comment/string stripping.
            if m.group(1) is None and \
                    not strip_noise(rest[:m.end()]).rstrip().endswith('['):
                out.append(strip_noise(rest))
                return ''.join(out)
            out.append(strip_noise(rest[:m.start()]))
            self.level = len(m.group(2))
            rest = rest[m.end():]


class Scanner(object):
    """Sequential block-depth scanner.

    Stateful ON PURPOSE. The first draft computed each line's delta in
    isolation and therefore double-counted a `for ... in pairs(...)` whose
    `do` sits on the NEXT line (`bots/ability_item_usage_generic.lua:450`):
    +1 for the header, +1 again for the orphan `do`. The drift was +97 over
    that one file, so depth never returned to 0 after line ~450 and the
    census saw 7 functions in a 9069-line file -- including none of the
    `Consider*` family it was written for. A `for` header therefore parks a
    pending `do` that the next `do` token consumes.
    """

    def __init__(self):
        self.pending_do = 0

    def delta(self, code):
        opens = closes = 0
        for w in _WORDS.findall(code):
            if w in ('for', 'while'):
                opens += 1
                self.pending_do += 1
            elif w == 'do':
                if self.pending_do:
                    self.pending_do -= 1   # belongs to a header already counted
                else:
                    opens += 1             # standalone `do ... end`
            elif w in ('if', 'function', 'repeat'):
                # `elseif` lexes as its own word, so it never lands here.
                opens += 1
            elif w in ('end', 'until'):
                closes += 1
        return opens - closes


def parse_functions(lines, clean=None):
    """Return ([(name, start_idx, end_idx)], block depth at EOF).

    The EOF depth comes back with the functions rather than from a second walk:
    a file that does not close to 0 was not really read, and the functions found
    in it are a fragment. Callers must look at both.
    """
    if clean is None:
        c = Cleaner()
        clean = [c.line(l) for l in lines]
    depth = 0
    cur = None
    scanner = Scanner()
    funcs = []
    for idx, code in enumerate(clean):
        # The cheap `in` test first: the head regexes (FUNC_ASSIGN_HEAD in
        # particular) backtrack, and running them on every one of ~212k corpus
        # lines was over a third of the census's runtime.
        if depth == 0 and cur is None and 'function' in code:
            head = FUNC_HEAD.match(code) or FUNC_ASSIGN_HEAD.match(code)
            if head:
                cur = (head.group(1), idx)
        before = depth
        depth += scanner.delta(code)
        if cur is not None and depth == 0 and before > 0:
            funcs.append((cur[0], cur[1], idx))
            cur = None
    return funcs, depth


def census_function(path, name, lines, start, end, clean=None):
    """Return the list of (C)-shape sites inside one function body."""
    if clean is None:
        c = Cleaner()
        clean = [c.line(l) for l in lines]
    # Pass 1: statement depth of every line, relative to the function body.
    depths, depth = [], 0
    scanner = Scanner()
    for idx in range(start, end + 1):
        code = clean[idx]
        opens_first = re.match(r'^\s*(end|else|elseif)\b', code)
        d = depth
        if opens_first:
            d = depth - 1
        depths.append(max(d, 0))
        depth += scanner.delta(code)

    # Which body-level (depth-1) branch does each line belong to? The benign
    # form of this shape -- a cascade of fallback selectors writing ONE
    # destination and one shared `if v ~= nil` fire at the bottom -- keeps
    # write and read inside the SAME branch. The GH #821 form crosses
    # branches: `前往守塔` wrote the local, `回复状态` fired on it. Only the
    # crossing form can bypass a sibling's conjuncts, so it is reported
    # separately rather than mixed into one count.
    branch, cur_branch = [], -1
    bscan = Scanner()
    bdepth = 0
    for idx in range(start, end + 1):
        code = clean[idx]
        d = depths[idx - start]
        delta = bscan.delta(code)
        if d == 1 and delta > 0:
            cur_branch = idx
        branch.append(cur_branch if d > 1 else idx)
        bdepth += delta

    def at(idx):
        return depths[idx - start]

    def br(idx):
        return branch[idx - start]

    def logical_cond(idx):
        """Join a multi-line `if` head into one condition string.

        Load-bearing, and it was the second thing this census got wrong: the
        shipped style puts each conjunct on its own line, so the FIRST line of
        `if tpLoc ~= nil` + `and GetUnitToLocationDistance(...) > ...` reads as
        a BARE non-nil test on its own. Classifying line-by-line made the
        writing branch's own guarded fire look bare, the scan stopped there,
        and the cross-branch read 600 lines below was never reached -- i.e.
        the census reported `same` for the exact site it exists to find.
        """
        parts = []
        for k in range(idx, min(idx + 25, end + 1)):
            c = clean[k].strip()
            parts.append(c)
            if re.search(r'(^|\W)then(\W|$)', c):
                break
        return ' '.join(parts).strip()

    def branch_modes(bidx):
        """The `nMode` values a body-level branch head admits ({} = any)."""
        if bidx < start or bidx > end:
            return set()
        head = logical_cond(bidx)
        modes = set(MODE_EQ.findall(head))
        for pred, group in MODE_PREDICATES.items():
            if pred in head:
                modes |= group
        return modes

    def code(idx):
        return clean[idx].strip()

    # Pass 2: function-level locals (declared at body depth 1).
    locals_ = {}
    for idx in range(start + 1, end):
        if 'local' not in clean[idx]:
            continue
        m = LOCAL_DECL.match(clean[idx])
        if m and at(idx) == 1:
            locals_[m.group(1)] = idx

    # Pass 3: writes.
    writes = {}
    for idx in range(start + 1, end):
        if '=' not in clean[idx]:
            continue
        m = ASSIGN.match(clean[idx])
        if not m:
            continue
        var = m.group(1)
        if var not in locals_ or idx == locals_[var]:
            continue
        writes.setdefault(var, []).append(idx)

    sites = []
    for var, idxs in writes.items():
        if len(idxs) < 2:
            continue                     # criterion (b)
        for widx in idxs:
            wdepth = at(widx)
            if wdepth <= 1:
                continue                 # a body-level write is not a branch
            # Does the write's own block consume it before falling through?
            consumed = False
            j = widx + 1
            while j < end and at(j) >= wdepth:
                if at(j) == wdepth and re.match(r'^return\b', code(j)):
                    consumed = True
                    break
                j += 1
            if consumed:
                continue                 # criterion (a) fails: fire-with-write
            block_end = j
            # Criterion (c): a later BARE read that fires, outside this block.
            # One site per write, and it must be the REACHABLE read when one
            # exists: stopping at the first match would have classified the
            # `前往守塔` write by its nearest reader (`保人`, mode-disjoint) and
            # never looked at `回复状态` 600 lines further down -- i.e. it would
            # have answered "live=0" on the very tree GH #821 was filed against.
            fallback = None
            for ridx in range(block_end, end):
                if not re.match(r'^if\b', code(ridx)):
                    continue
                cond = logical_cond(ridx)
                m = BARE_READ.match(cond)
                if not m or m.group(1) != var:
                    continue
                cleared = any(
                    code(k) == '%s = nil' % var
                    for k in range(block_end, ridx)
                )
                if cleared:
                    continue
                # Criterion (d), the one that separates GH #821 from a plain
                # fallback cascade: the WRITE's own body-level branch already
                # tries to fire on this local behind EXTRA conjuncts. That is
                # what makes the leftover write a decision this branch took and
                # then refused to act on -- and what makes the later bare read
                # a different question answered with somebody else's answer.
                # A selector cascade (jmz_func:4547, the minion target loops)
                # has no such fire inside the writing branch and drops out.
                wb = br(widx)
                own_guarded_fire = False
                for k in range(widx + 1, end):
                    if br(k) != wb:
                        break
                    if not re.match(r'^if\b', code(k)):
                        continue
                    c = logical_cond(k)
                    if var not in c or BARE_READ.match(c):
                        continue
                    kd = at(k)
                    for t in range(k + 1, end):
                        if at(t) <= kd and not re.match(r'^(and|or|then)\b', code(t)):
                            break
                        if re.match(r'^return\b', code(t)):
                            own_guarded_fire = True
                            break
                    if own_guarded_fire:
                        break
                if not own_guarded_fire:
                    continue

                # Criterion (e): can the two branches run in the SAME think?
                # `tpLoc` is re-initialised at every call, so a leak that needs
                # two mode-exclusive branches to both execute needs them in one
                # invocation -- and cannot get it.
                wmodes, rmodes = branch_modes(br(widx)), branch_modes(br(ridx))
                disjoint = bool(wmodes) and bool(rmodes) and not (wmodes & rmodes)

                gates = sorted(set(
                    g for k in range(widx, block_end)
                    for g in GATE_CALL.findall(clean[k])
                ))
                site = {
                    'file': path, 'func': re.sub(r'\s+', '', name), 'var': var,
                    'write': widx + 1, 'read': ridx + 1,
                    'cond': cond, 'gates': gates,
                    'cross': br(widx) != br(ridx),
                    'disjoint': disjoint,
                }
                if disjoint:
                    fallback = fallback or site
                    continue
                fallback = site
                break
            if fallback is not None:
                sites.append(fallback)
    return sites


def scan_text(path, text):
    """Census one file's source. Returns (sites, block depth at EOF).

    The EOF depth is returned, not swallowed: a file that does not close to 0
    was not really read, and every count taken from it is silence rather than
    evidence (tests/test_stale_write_census.py asserts it corpus-wide).
    """
    lines = text.split('\n')
    cleaner = Cleaner()
    clean = [cleaner.line(l) for l in lines]
    funcs, depth = parse_functions(lines, clean)
    sites = []
    for name, start, end in funcs:
        sites.extend(census_function(path, name, lines, start, end, clean))
    return sites, depth


def scan_paths(paths):
    """Census files and directories. Returns (sites, [(path, eof depth)]).

    GH #856 / GH #243 family.  This was the EIGHTH open-coded
    walk-then-bare-`open` of bots/, and it crashed with FileNotFoundError when
    a concurrent Lua gate test deleted `bots/Customize/soak_side.lua` between
    the two moments -- read as `FAIL`, i.e. TRUNK RED, on a tree that was fine.

    Two repairs, both from GH #243's own kit:
      * the declared non-corpus files are excluded from the listing, so the
        window mostly cannot open; and
      * the read goes through `lua_corpus.read_lua`, so when it opens anyway
        the answer is `CorpusVanished` -> exit 2 (did-not-run), never a
        shorter count and never a findings exit.

    The exclusion is applied only to walked directories.  An explicitly named
    file on argv is still read: asking this census about one path by name is
    not the corpus question, and silently returning nothing for it would be
    the "counted fewer" failure wearing the repair's clothes.
    """
    files = []
    for root in paths:
        if os.path.isfile(root):
            files.append(root)
            continue
        for dirpath, _dirnames, names in os.walk(root):
            for n in sorted(names):
                if n.endswith('.lua'):
                    path = os.path.join(dirpath, n)
                    if lua_corpus.is_excluded(path):
                        continue
                    files.append(path)
    files.sort()

    sites, unbalanced = [], []
    for path in files:
        text = lua_corpus.read_lua(path, errors='replace')
        found, depth = scan_text(path, text)
        sites.extend(found)
        if depth != 0:
            unbalanced.append((path, depth))
    return sites, unbalanced


def summary(sites):
    return {
        'sites': len(sites),
        'cross': sum(1 for s in sites if s['cross']),
        'live': sum(1 for s in sites if s['cross'] and not s['disjoint']),
        'files': len(set(s['file'] for s in sites)),
        'gated': sum(1 for s in sites if s['gates']),
    }


def render(sites, unbalanced=()):
    out = []
    for path, depth in unbalanced:
        out.append('UNBALANCED %s depth=%+d -- counts from this file are '
                   'silence, not evidence' % (path, depth))
    for s in sites:
        out.append('SITE %-6s %-13s %s:%d %s var=%s read=%d cond=%r gates=%s' % (
            'CROSS' if s['cross'] else 'same',
            'MODE-DISJOINT' if s['disjoint'] else 'reachable',
            s['file'], s['write'], s['func'], s['var'], s['read'],
            s['cond'], ','.join(s['gates']) or '-'))
    c = summary(sites)
    out.append('CENSUS sites=%(sites)d cross=%(cross)d live=%(live)d '
               'files=%(files)d gated=%(gated)d' % c)
    return '\n'.join(out)


@lua_corpus.guard('stale_write_census')
def main(argv):
    sites, unbalanced = scan_paths(argv[1:] or ['bots'])
    print(render(sites, unbalanced))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

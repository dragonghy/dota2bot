#!/usr/bin/env python3
"""Whose domain can only be reached THROUGH another candidate's gate?

THE DEFECT THIS ANSWERS, and it is the mirror of a trap the tree already
knows about.

`pullcad` taught the house that PROMOTING an id kills every gate that names
it: a gate written `IsSoakCandidate('X') and IsSoakCandidate('Y')` freezes
FALSE the day `Y` is promoted, because a promoted id appears in no armed
string.  Two source comments (`jmz_func.lua` around the lane-pull helpers)
were written to remember exactly that, and both of them steered the author
to a STANDALONE gate, which is the correct remedy for the trap they name.

2026-09-11 (director RULING 13, `test_set.md` §GS.2) measured the other
direction on `pulldrag`, and the STANDALONE gate did not help at all:

    J.GetLanePullDragTarget has exactly ONE call site in bots/
    (mode_roam_generic.lua), and that call site sits inside
    `if bot.roamCampPull ~= nil`.  `roamCampPull` is given a non-nil value
    in exactly one place, from `J.ShouldPullNeutralCamp`, whose first two
    lines are turbo + IsSoakCandidate('pullcamp').

    => retire `pullcamp` and `pulldrag`'s domain is structurally EMPTY,
       while `check_armed_wiring.py` still reads WIRED (a call site exists),
       `verify_coverage.py` still lists it as armed INDETERMINATE, and the
       next wave's verdict still comes back "tested, no effect".

    Nothing raises a hand.  Promote kills the gate that names you; RETIRE
    kills the domain that hangs under you.  The house rule now says to check
    both directions before touching armed state -- and a rule that says
    "check" is a habit, not a gate.  This is the gate.

WHAT IT REPORTS, in three states, and the third one is the point
---------------------------------------------------------------
For every live gate id it resolves the call paths that can reach that gate's
own function and asks whether EVERY one of them passes through some OTHER
id's gate.

  FROZEN    an ARMED id whose domain is conditioned on an id that is NOT
            armed.  Its armed leg is a structural no-op right now: every
            wave that carries it is buying nothing, and every verdict it
            collects is a correct zero about a lever that never ran.
            This is the finding; exit 3.
  COUPLED   an ARMED id conditioned on another ARMED id.  Not a defect --
            but its readings are JOINT, and the day the other id is promoted
            or retired this row becomes FROZEN with nothing else changing.
            Printed for the ruling desk; it does NOT set the exit code,
            because a standing red on a healthy configuration is how a leg
            teaches people to skip it.
  UNRESOLVED the analysis could not answer.  Printed by name and never
            folded into "clear" -- see LIMITS.  A silent CLEAR on an id this
            tool cannot actually trace is the failure mode it exists to stop.

THE TWO MECHANISMS IT TRACES (both witnessed, neither guessed)
--------------------------------------------------------------
  (A) NESTED GATE -- the gated function is only called from inside a body
      that is itself behind another id's gate.
  (B) FIELD-MEDIATED -- the call site is guarded by `bot.<field>`, and every
      assignment that can give `<field>` a non-nil value comes from a
      function carrying another id's gate.  This is the `pulldrag` shape,
      and it is the one a "does a call site exist" check cannot see.

THE SIBLING THAT ALREADY EXISTS, AND WHAT IS ACTUALLY NEW HERE
---------------------------------------------------------------
`tests/test_gated_helper_nesting_census.lua` (strategy 2026-08-29, GH #304)
already pins the SET of gate-inside-gate conjunctions, deliberately
over-inclusive, as a ratchet.  This leg does not replace it and does not
license removing a single one of its rows.  Three things it cannot do, and
all three are why RULING 13 was found by hand:

  1. It is a ratchet on a SET.  Retiring `pullcamp` changes no conjunction
     row, so the ratchet stays green on exactly the event that emptied
     `pulldrag`'s domain.  FROZEN is a question about the ARMED STRING, which
     a fixed-set ratchet structurally cannot ask.
  2. Its "nested" means "the call sits anywhere in the caller's body".  That
     is the safe direction for a ratchet and the wrong one for a verdict --
     `fieldbuy` and `fieldregen` share a body and nothing else.
  3. It does not follow mechanism (B) at all, and `pulldrag`'s row in it is
     a HAND-WRITTEN pin (`dragnolane,pulldrag`) precisely because the field
     hop is invisible to it.

That file also states the objection this one has to answer: a narrower rule
"would decide by indentation what the wave decides by arithmetic".  Correct,
and the answer is that indentation here only recovers WHICH conditions
enclose the call; whether such a condition GATES it is then decided by the
boolean procedure below, not by layout.  Where that procedure cannot answer,
the row reads UNRESOLVED.

A GATE EARLIER IN THE SAME BODY IS NOT A GATE OVER YOU
------------------------------------------------------
The first cut of mechanism (A) counted any gate appearing earlier in the
calling function at an indent no deeper than the call.  Run on trunk it
reported `fieldbuy needs 'fieldregen' <- NOT ARMED`, which is FALSE and
expensively so: `item_purchase_generic.lua:776` is the *fieldregen* purchase
block, a SIBLING `if` that ends before the `fieldbuy` block begins.  Reading
that as a dominator would have declared a lever with 785 measured episodes
structurally dead.

So (A) now accepts exactly two dominating shapes, both checkable:
  * the gate sits in the CONDITION of an if/elseif block that contains the
    call site (recovered from indentation), or
  * the gate sits in an early-return guard -- `if not <gate> ... then return`
    -- at an indent no deeper than the call, earlier in the same body.
Anything else is a sibling and is ignored.

LIMITS -- read these before quoting a CLEAR
-------------------------------------------
  * Syntactic, single-file-set, `bots/` only.  It does not execute Lua and
    it does not do real dataflow.
  * Mechanism (B) follows `bot.<field>` guards only, one hop from the field
    to the function that filled it.  A guard on a plain local, a field on
    something other than `bot`, or a two-hop launder reads UNRESOLVED.
  * A function with no call site at all reads UNRESOLVED (engine entry
    points such as Think/Consider live there, and so does dead code -- this
    tool refuses to tell them apart).  Dispatch-table entries
    (`X.ConsiderItemDesire["item_blink"] = function(...)`) are resolved one
    hop further, to the sites that index the TABLE.
  * Comment detection is positional: a `--` earlier in the line than the
    match means the match is commentary.  A gate spelled inside a Lua string
    would be misread; there are none today.
  * CLEAR means "a path to this gate exists that this tool could follow and
    that crossed no other gate".  It is not a proof that the lever fires.
  * The verdict is over PATHS, not over deps: one call site that crosses
    nothing makes the id CLEAR even when three other call sites are buried
    under unarmed gates.  FROZEN requires EVERY resolved path to be blocked.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(os.path.dirname(__file__) + "/../")))
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BOTS = os.path.join(ROOT, "bots")
TEST_SET = os.path.join(ROOT, "iterations", "streams", "test_set.md")

GATE_RE = re.compile(r"J\.IsSoakCandidate\(\s*['\"]([a-z0-9_]+)['\"]\s*\)")
FUNC_RE = re.compile(r"^(\s*)(?:local\s+)?function\s+([\w.:]+)\s*\(")
ANONFUNC_RE = re.compile(r"^(\s*)(?:local\s+)?([\w.]+(?:\[[^\]]+\])?)\s*=\s*function\s*\(")
IF_RE = re.compile(r"^(\s*)(?:els)?e?if\s+(.*?)\s+then\s*$")
BOTFIELD_RE = re.compile(r"\bbot\.([A-Za-z_]\w*)")
CALL_OF = "%s\\s*\\("


def fail(msg):
    print("INVERSE-GATE CENSUS: UNCERTIFIABLE -- %s" % msg)
    sys.exit(2)


# --- deciding domination, instead of pattern-matching it ---------------------
#
# "The line has `not`, a gate and a `return`" is not the same question as "does
# this gate have to be armed to get past this line", and on trunk the two part
# company on the throttle in `mode_roam_generic.lua`:
#
#     if not (bot.roamCampPull ~= nil and J.IsSoakCandidate('pullthink'))
#     and not (bot.roamCreepPull ~= nil and J.IsSoakCandidate('creepthink'))
#     and J.Utils.IsBotThinkingMeaningfulAction(...) then return end
#
# Arming `creepthink` can only make that return LESS likely -- it WIDENS what
# follows.  The pattern match read it as a guard and reported `rotscope` and
# `pulldrag` as conditioned on `creepthink`, which is backwards.
#
# So the condition is parsed and DECIDED: pin the gate atom to false, leave
# every other atom free, and ask whether the outcome is forced.  Small, total,
# and it answers the question actually being asked.
MAX_FREE_ATOMS = 12
KEYWORD_RE = re.compile(r"(not|and|or)\b")
BREAK_RE = re.compile(r"\s+(and|or)\b")


def tokenize_cond(s):
    """['(' | ')' | 'not' | 'and' | 'or' | ('ATOM', text)].

    An identifier's own call parens belong to the atom; a '(' met where a token
    may start is a grouping paren.

    Total by construction -- every character lands in some token, so malformed
    input produces a malformed TOKEN LIST, not a failure here.  It used to
    carry a `return None` for an empty atom; that branch was unreachable (the
    scanner has already skipped whitespace, so an atom scan always consumes at
    least one character) and a mutation that turned the caller's handling of it
    into a silent False therefore survived the whole stand.  Rejection belongs
    to `parse_cond`, which is where it can actually happen.
    """
    toks, i, n = [], 0, len(s)
    while i < n:
        if s[i].isspace():
            i += 1
            continue
        if s[i] in "()":
            toks.append(s[i])
            i += 1
            continue
        m = KEYWORD_RE.match(s, i)
        if m:
            toks.append(m.group(1))
            i = m.end()
            continue
        start, depth = i, 0
        while i < n:
            c = s[i]
            if c == "(":
                depth += 1
            elif c == ")":
                if depth == 0:
                    break
                depth -= 1
            elif depth == 0 and BREAK_RE.match(s, i):
                break
            i += 1
        toks.append(("ATOM", s[start:i].strip()))
    return toks


def parse_cond(toks):
    """(ast, atoms) or (None, None).  ast: ('atom', i) | ('not', a) | ('and'|'or', a, b)."""
    pos = [0]
    atoms = []

    def peek():
        return toks[pos[0]] if pos[0] < len(toks) else None

    def factor():
        t = peek()
        if t == "not":
            pos[0] += 1
            a = factor()
            return None if a is None else ("not", a)
        if t == "(":
            pos[0] += 1
            a = expr()
            if peek() != ")":
                return None
            pos[0] += 1
            return a
        if isinstance(t, tuple):
            pos[0] += 1
            if t[1] not in atoms:
                atoms.append(t[1])
            return ("atom", atoms.index(t[1]))
        return None

    def term():
        a = factor()
        while a is not None and peek() == "and":
            pos[0] += 1
            b = factor()
            a = None if b is None else ("and", a, b)
        return a

    def expr():
        a = term()
        while a is not None and peek() == "or":
            pos[0] += 1
            b = term()
            a = None if b is None else ("or", a, b)
        return a

    ast = expr()
    if ast is None or pos[0] != len(toks):
        return None, None
    return ast, atoms


def eval_ast(ast, vals):
    k = ast[0]
    if k == "atom":
        return vals[ast[1]]
    if k == "not":
        return not eval_ast(ast[1], vals)
    if k == "and":
        return eval_ast(ast[1], vals) and eval_ast(ast[2], vals)
    return eval_ast(ast[1], vals) or eval_ast(ast[2], vals)


def forced_outcome(cond, gid, want):
    """With the '<gid>' gate atom false, is `cond` always `want`?

    None when the condition could not be parsed or has too many free atoms --
    never a silent False, because a silent False is a silent CLEAR.
    """
    ast, atoms = parse_cond(tokenize_cond(cond))
    if ast is None:
        return None
    gate_ix = [i for i, a in enumerate(atoms)
               if any(m.group(1) == gid for m in GATE_RE.finditer(a))]
    if not gate_ix:
        return False
    free = [i for i in range(len(atoms)) if i not in gate_ix]
    if len(free) > MAX_FREE_ATOMS:
        return None
    for bits in range(1 << len(free)):
        vals = [False] * len(atoms)
        for k, i in enumerate(free):
            vals[i] = bool(bits & (1 << k))
        if eval_ast(ast, vals) is not want:
            return False
    return True


def code_part(line):
    """The part of a Lua line before its first `--`, or None if all comment.

    Positional, and deliberately crude: see LIMITS.  Returns '' for a line
    whose code part is empty so callers can still index it.
    """
    i = line.find("--")
    if i < 0:
        return line
    return line[:i]


def load_files():
    out = {}
    for dirpath, _dirs, names in os.walk(BOTS):
        for n in names:
            if not n.endswith(".lua"):
                continue
            p = os.path.join(dirpath, n)
            rel = os.path.relpath(p, ROOT)
            try:
                out[rel] = open(p, encoding="utf-8", errors="replace").read().split("\n")
            except OSError as exc:
                fail("cannot read %s (%s)" % (rel, exc))
    if not out:
        fail("no .lua files under %s" % BOTS)
    return out


def index_functions(lines):
    """[(start, end, name, indent)] -- 0-based, `end` inclusive.

    A function runs from its `function` header to the first later line that is
    exactly `end` (plus optional trailing comment) at the SAME indent.  The
    codebase is tab-indented and consistent; a header whose `end` is never
    found is dropped rather than guessed at.
    """
    funcs = []
    for i, ln in enumerate(lines):
        m = FUNC_RE.match(ln)
        if m:
            indent, name = m.group(1), m.group(2)
        else:
            m = ANONFUNC_RE.match(ln)
            if not m:
                continue
            indent, name = m.group(1), m.group(2)
        closer = indent + "end"
        for j in range(i + 1, len(lines)):
            c = code_part(lines[j]).rstrip()
            if c == closer:
                funcs.append((i, j, name, indent))
                break
    return funcs


def enclosing(funcs, line):
    """Innermost function containing 0-based `line`, or None."""
    best = None
    for (s, e, name, indent) in funcs:
        if s <= line <= e:
            if best is None or s > best[0]:
                best = (s, e, name, indent)
    return best


def gate_sites(files):
    """id -> [(relpath, 0-based line)] for every non-comment gate call."""
    sites = {}
    for rel, lines in files.items():
        for i, ln in enumerate(lines):
            code = code_part(ln)
            for m in GATE_RE.finditer(code):
                sites.setdefault(m.group(1), []).append((rel, i))
    return sites


def enclosing_conditions(lines, funcbounds, line):
    """Conditions of the `if`/`elseif` blocks that contain 0-based `line`.

    Walks upward keeping only headers strictly less indented than everything
    accepted so far -- the standard way to recover block nesting from
    consistent indentation without parsing Lua.

    MULTI-LINE HEADERS ARE THE COMMON CASE HERE, not an edge case.  A first cut
    matched only `if <cond> then` on one line and was therefore blind to

        if J.IsModeTurbo()
        and J.IsSoakCandidate( 'x' )
        then

    which is how most of `bots/` is written.  It did not show up as a wrong
    answer anywhere -- it showed up as mechanism (A1) quietly never firing.
    A header is recognised by its `then` and read back up to its `if`.
    """
    start = funcbounds[0]
    cur = len(code_part(lines[line])) - len(code_part(lines[line]).lstrip())
    conds = []
    j = line - 1
    while j >= start:
        code = code_part(lines[j]).rstrip()
        if not code.strip() or not re.search(r"\bthen$", code):
            j -= 1
            continue
        h = j
        while (h > start and h > j - 12
               and not re.match(r"^\s*(?:els)?e?if\b", code_part(lines[h]))):
            h -= 1
        m = re.match(r"^(\s*)(?:els)?e?if\b", code_part(lines[h]))
        if m:
            ind = len(m.group(1))
            if ind < cur:
                blob = " ".join(code_part(lines[k]).strip()
                                for k in range(h, j + 1))
                mm = re.match(r"^(?:els)?e?if\s+(.*?)\s*then$", blob)
                if mm:
                    conds.append(mm.group(1))
                    cur = ind
        j = h - 1
    return conds


def split_top(s):
    """Split on commas that are not inside (), {} or []."""
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "({[":
            depth += 1
        elif ch in ")}]":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return [x.strip() for x in out]


_ASSIGN_INDEX = {}


def assign_index(files):
    """field name -> [(relpath, 0-based line, lhs targets, rhs values)].

    Built ONCE over every `bots/` line.  The per-field scan it replaces was
    the whole runtime: ~200 distinct guard fields x ~80k lines did not finish
    inside two minutes, which for a leg that runs at every 开工 is the same as
    not existing.
    """
    if _ASSIGN_INDEX:
        return _ASSIGN_INDEX
    stmt = re.compile(r"^\s*([\w.,\s\[\]']+?)\s*=\s*(.+?)\s*$")
    for rel, lines in files.items():
        for i, ln in enumerate(lines):
            code = code_part(ln)
            if "=" not in code or "." not in code:
                continue
            m = stmt.match(code)
            if not m or re.search(r"[=<>~]=\s*$", m.group(1) + "="):
                continue
            lhs, rhs = split_top(m.group(1)), split_top(m.group(2))
            row = (rel, i, lhs, rhs)
            for target in lhs:
                if "." in target:
                    _ASSIGN_INDEX.setdefault(target.rsplit(".", 1)[1],
                                             []).append(row)
    return _ASSIGN_INDEX


def field_sources(files, funcindex, field):
    """Which gate ids can put a NON-NIL value into `bot.<field>`?

    Returns (gate_ids, unresolved_notes).  Every assignment whose value is a
    literal `nil` is skipped -- a lever cannot be reached by a field being
    cleared.  For the rest the value is traced ONE hop: a direct `J.Foo(...)`
    call, or a local that the same function filled from a `J.Foo(...)` call.
    """
    if field in _FIELDSRC_CACHE:
        return _FIELDSRC_CACHE[field]
    ids, notes = set(), []
    for (rel, i, lhs, rhs) in assign_index(files).get(field, ()):
        lines, funcs = files[rel], funcindex[rel]
        if True:
            for k, target in enumerate(lhs):
                if not target.endswith("." + field):
                    continue
                val = rhs[k] if k < len(rhs) else (rhs[-1] if rhs else "")
                if val.strip() == "nil":
                    continue
                src = trace_value(lines, funcs, i, val.strip())
                if src is None:
                    notes.append("%s:%d assigns bot.%s = %s (value not traced)"
                                 % (rel, i + 1, field, val.strip()[:40]))
                    continue
                gates = gates_in_function(files, funcindex, src)
                if gates is None:
                    notes.append("%s:%d value comes from %s, which this tool "
                                 "cannot locate" % (rel, i + 1, src))
                    continue
                if not gates:
                    notes.append("%s:%d value comes from %s, which carries no "
                                 "gate (so this field is reachable ungated)"
                                 % (rel, i + 1, src))
                    ids.add(None)      # an ungated producer exists
                else:
                    ids |= gates
    _FIELDSRC_CACHE[field] = (ids, notes)
    return ids, notes


def trace_value(lines, funcs, line, val):
    """Resolve `val` at 0-based `line` to a `J.Foo` producer name, or None."""
    m = re.match(r"^(J\.[\w.]+)\s*\(", val)
    if m:
        return m.group(1)
    if not re.match(r"^[A-Za-z_]\w*$", val):
        return None
    fb = enclosing(funcs, line)
    start = fb[0] if fb else 0
    pat = re.compile(r"(?:local\s+)?%s\s*=\s*(J\.[\w.]+)\s*\(" % re.escape(val))
    for j in range(line - 1, start - 1, -1):
        mm = pat.search(code_part(lines[j]))
        if mm:
            return mm.group(1)
    return None


def gates_in_function(files, funcindex, qualname):
    """Gate ids that gate `qualname`'s RETURN VALUE, or None if not defined here.

    Top-level early-return guards only.  Counting every gate anywhere in the
    body over-reports, and the over-report is the dangerous direction: run
    that way, `pulldrag` came back conditioned on `creepthink`, `pulllane` and
    `pullnolane` as well as on `pullcamp`, because those three appear in inner
    branches of `J.ShouldPullNeutralCamp` that only NARROW which camp comes
    back.  Retire any one of them and the caller would have been declared
    FROZEN on a lever that still runs.  Only `pullcamp`, whose guard is the
    function's second line, can make the producer return nil outright.
    """
    if qualname in _GATESIN_CACHE:
        return _GATESIN_CACHE[qualname]
    for rel, lines in files.items():
        for (s, e, name, ind) in funcindex[rel]:
            if name != qualname:
                continue
            out = {g for (g, _ln) in
                   early_return_gates(lines, s, e, len(ind) + 1)}
            _GATESIN_CACHE[qualname] = out
            return out
    _GATESIN_CACHE[qualname] = None
    return None


_CALLSITE_CACHE = {}
_FIELDSRC_CACHE = {}
_GATESIN_CACHE = {}


def call_sites(files, funcindex, fname, defrel, defline):
    """Every line in bots/ that calls `fname`, plus a note when it is opaque.

    A dispatch-table entry (`X.Consider["item_blink"] = function(...)`) has no
    name to call, so the hop is taken to the sites that index the TABLE -- the
    engine reaches the body through there and nowhere else.

    Memoised: the recursive walk revisits the same helper from many gates, and
    an uncached scan of every `bots/` line per hop does not finish.
    """
    ck = (fname, defrel, defline)
    if ck in _CALLSITE_CACHE:
        return _CALLSITE_CACHE[ck]
    call_idx, index_idx = reference_index(files)
    if "[" in fname:
        # Dispatch-table entry: the engine reaches the body by indexing the
        # TABLE, so that is where the call path continues.
        hits = index_idx.get(fname.split("[", 1)[0], ())
    else:
        hits = call_idx.get(fname, ())
    out = [(r, i) for (r, i) in hits if not (r == defrel and i == defline)]
    _CALLSITE_CACHE[ck] = out
    return out


_REFERENCE_INDEX = None
REF_CALL_RE = re.compile(r"([A-Za-z_][\w.:]*)\s*\(")
REF_INDEX_RE = re.compile(r"([A-Za-z_][\w.]*)\s*\[")


def reference_index(files):
    """(name -> call sites, name -> index sites), built in ONE pass.

    The scan this replaces was per-function-name over every `bots/` line, and
    the recursive walk visits thousands of function names: ~80k lines x ~2k
    names is why the first working version of this leg took 13.5 SECONDS on
    its first gate id and never reached its second.  A leg that does not
    return is a leg nobody runs.
    """
    global _REFERENCE_INDEX
    if _REFERENCE_INDEX is not None:
        return _REFERENCE_INDEX
    calls, idxs = {}, {}
    for rel, lines in files.items():
        for i, ln in enumerate(lines):
            code = code_part(ln)
            if "(" not in code and "[" not in code:
                continue
            if FUNC_RE.match(code) or ANONFUNC_RE.match(code):
                continue
            for m in REF_CALL_RE.finditer(code):
                calls.setdefault(m.group(1), []).append((rel, i))
            for m in REF_INDEX_RE.finditer(code):
                idxs.setdefault(m.group(1), []).append((rel, i))
    _REFERENCE_INDEX = (calls, idxs)
    return _REFERENCE_INDEX


def early_return_gates(lines, fstart, cline, cindent):
    """Gate ids in `if not <gate> ... then return` guards dominating `cline`.

    The guard must sit at an indent no deeper than the call (a guard nested
    deeper is inside some branch and returns only on that branch's terms), its
    `return` must be on the guard line or the line after -- the shape every
    gated helper in this tree opens with -- and, the part that is decided
    rather than matched, pinning the gate to FALSE must force the guard's
    condition TRUE, i.e. the unarmed leg really does take that return.
    """
    out = set()
    for j in range(fstart, cline):
        code = code_part(lines[j])
        if not code.strip():
            continue
        ind = len(code) - len(code.lstrip())
        if ind > cindent:
            continue
        ms = list(GATE_RE.finditer(code))
        if not ms:
            continue
        # The condition may be spread over the following lines; take up to
        # three, which covers every multi-line guard in bots/ today.
        blob = code
        k = j
        while "then" not in blob and k + 1 < len(lines) and k - j < 3:
            k += 1
            blob += " " + code_part(lines[k])
        if "then" not in blob:
            continue
        tail = blob
        if "return" not in tail and k + 1 < len(lines):
            tail = blob + " " + code_part(lines[k + 1])
        if "return" not in tail:
            continue
        m_if = re.search(r"\b(?:els)?e?if\s+(.*?)\s+then\b", blob)
        if not m_if:
            continue
        cond = m_if.group(1)
        for m in ms:
            if forced_outcome(cond, m.group(1), True):
                out.add((m.group(1), j + 1))
    return out


MAX_DEPTH = 4


_CROSSING_CACHE = {}


def crossings_at(files, funcindex, gid, crel, cline, notes):
    """Gates that dominate one call site, by all three mechanisms.

    Cached WITHOUT the `!= gid` filter and filtered on the way out: what
    dominates a call site is a property of the site, not of which gate is
    asking, and 195 gate ids each re-deriving it is the difference between
    seconds and not returning.
    """
    ck = (crel, cline)
    if ck in _CROSSING_CACHE:
        raw, cfb, cnotes = _CROSSING_CACHE[ck]
        notes.extend(cnotes)
        if raw is None:
            return None, None
        return {(o, w) for (o, w) in raw if o != gid}, cfb
    notes_before = len(notes)
    raw, cfb = _crossings_uncached(files, funcindex, crel, cline, notes)
    _CROSSING_CACHE[ck] = (raw, cfb, list(notes[notes_before:]))
    if raw is None:
        return None, None
    return {(o, w) for (o, w) in raw if o != gid}, cfb


def _crossings_uncached(files, funcindex, crel, cline, notes):
    clines = files[crel]
    cfb = enclosing(funcindex[crel], cline)
    if cfb is None:
        notes.append("%s:%d call site is outside any delimited function"
                     % (crel, cline + 1))
        return None, None
    code = code_part(clines[cline])
    cindent = len(code) - len(code.lstrip())
    crossed = set()
    conds = enclosing_conditions(clines, cfb, cline)
    # (A1) the gate is IN a condition that contains the call site.
    for cond in conds:
        for m in GATE_RE.finditer(cond):
            # Enter the block only when the condition is true, so the gate
            # dominates iff pinning it false forces the condition false.
            if forced_outcome(cond, m.group(1), False):
                crossed.add((m.group(1),
                             "dominating condition at %s:%d" % (crel, cline + 1)))
    # (A2) an early-return guard at or above the call's indent.
    for (other, gline) in early_return_gates(clines, cfb[0], cline, cindent):
        crossed.add((other, "early-return guard %s:%d" % (crel, gline)))
    # (B) FIELD-MEDIATED: a `bot.<field>` guard over the call.
    for cond in conds:
        for fm in BOTFIELD_RE.finditer(cond):
            field = fm.group(1)
            ids, fnotes = field_sources(files, funcindex, field)
            notes.extend(fnotes)
            if None in ids or not ids:
                continue                  # an ungated producer exists
            for other in ids:
                crossed.add((other, "bot.%s guard at %s:%d, filled only "
                             "behind '%s'" % (field, crel, cline + 1, other)))
    return crossed, cfb


def reach_ungated(ctx, fname, rel, defline):
    """Can `fname` be reached from an entry point crossing no OTHER gate?

    Walks the CALLER direction breadth-first with ONE shared visited set per
    gate id.  "Is there a gate-free path up to an entry point" is a property
    of the node, not of the route taken to it, so re-entering a node can add
    nothing -- which is what makes cycles harmless and the walk linear.

    ⚠️ The first version used a per-PATH stack for cycle detection plus a memo
    that refused to cache anything a cycle had touched.  Both halves were
    right in isolation and together they made every mutually-recursive
    neighbourhood exponential: the leg spent 13.5s on its first gate id and
    never reached its second.  A leg that does not return is a leg nobody
    runs, which is the one failure mode this whole file exists to prevent.

    A function with no call site terminates the walk: in this tree that is an
    engine entry point (`ItemPurchaseThink`, `ItemUsageThink`, the mode
    Think/Desire pairs).  It could also be dead code and this tool does NOT
    tell the two apart -- the terminus is recorded in `notes`.
    """
    files, funcindex, gid = ctx["files"], ctx["funcindex"], ctx["gid"]
    seen = {(fname, rel, defline)}
    queue = [(fname, rel, defline)]
    ok = False
    while queue:
        (nm, nrel, nline) = queue.pop()
        sites = call_sites(files, funcindex, nm, nrel, nline)
        if not sites:
            ctx["notes"].append("%s (%s:%d) has no call site in bots/ -- engine "
                                "entry point or dead; not distinguished here"
                                % (nm, nrel, nline + 1))
            ok = True
            continue
        for (crel, cline) in sites:
            crossed, cfb = crossings_at(files, funcindex, gid, crel, cline,
                                        ctx["notes"])
            if crossed is None:
                continue
            if crossed:
                ctx["blocked"].add(frozenset(crossed))
                continue
            key = (cfb[2], crel, cfb[0])
            if key not in seen:
                seen.add(key)
                queue.append(key)
    return ok


def analyse(files, funcindex, gates, gid):
    """(state, [set of (other_id, why)], [notes]) for one gate id.

    The verdict is over PATHS.  One path that crosses no other gate makes the
    id CLEAR; FROZEN needs every resolved path blocked AND every blocked path
    to carry at least one unarmed id.
    """
    ctx = {"files": files, "funcindex": funcindex, "gid": gid,
           "notes": [], "blocked": set()}
    clear = False
    for (rel, line) in gates[gid]:
        fb = enclosing(funcindex[rel], line)
        if fb is None:
            ctx["notes"].append("%s:%d gate is not inside a function this tool "
                                "could delimit" % (rel, line + 1))
            continue
        clear = reach_ungated(ctx, fb[2], rel, fb[0]) or clear
    if clear:
        return "CLEAR", [], ctx["notes"]
    if ctx["blocked"]:
        return "DEP", sorted(ctx["blocked"], key=lambda s: sorted(s)), ctx["notes"]
    return "UNRESOLVED", [], ctx["notes"]


def main():
    argv = sys.argv[1:]
    show_all = "--all" in argv
    try:
        lines = open(TEST_SET, encoding="utf-8").read().split("\n")
        armed = {x.strip() for x in lines[1].split(",") if x.strip()}
    except (OSError, IndexError) as exc:
        fail("cannot read the armed string from %s (%s)" % (TEST_SET, exc))
    if not armed:
        fail("the armed string parsed to zero ids")

    files = load_files()
    funcindex = {rel: index_functions(lines_) for rel, lines_ in files.items()}
    gates = gate_sites(files)
    if not gates:
        fail("no J.IsSoakCandidate gate site found under bots/")

    frozen, coupled, unresolved, clear = [], [], [], []
    for gid in sorted(gates):
        state, paths, notes = analyse(files, funcindex, gates, gid)
        # One row per (other_id, why), deduped -- the same helper is often
        # called from several sites behind the same gate.
        deps = sorted({d for p in paths for d in p})
        row = (gid, deps, notes)
        if state == "DEP":
            if gid not in armed:
                clear.append(row)          # not armed: nothing is being bought
            elif any(all(o in armed for (o, _w) in p) for p in paths):
                coupled.append(row)
            else:
                frozen.append(row)
        elif state == "UNRESOLVED":
            (unresolved if gid in armed else clear).append(row)
        else:
            clear.append(row)

    print("INVERSE-GATE CENSUS  live gate ids %d  armed %d"
          % (len(gates), len(armed)))
    print("  FROZEN %d   COUPLED %d   UNRESOLVED(armed) %d   other %d"
          % (len(frozen), len(coupled), len(unresolved), len(clear)))

    if frozen:
        print("\nFROZEN -- armed, but the domain hangs under an id that is NOT "
              "armed.\nIts armed leg is a structural no-op; any verdict it "
              "collects is a correct zero\nabout a lever that never ran.")
        for (gid, deps, _n) in frozen:
            for (other, why) in deps:
                mark = "" if other in armed else "   <- NOT ARMED"
                print("  %-14s needs '%s'%s\n      %s" % (gid, other, mark, why))

    if coupled:
        print("\nCOUPLED -- armed, and conditioned on another ARMED id.  Not a "
              "defect today.\nRead before any promote/retire ruling on either "
              "side: promoting the other id kills\nthe gate that names it, "
              "retiring it kills the domain that hangs under it.")
        for (gid, deps, _n) in coupled:
            for (other, why) in deps:
                print("  %-14s under '%s'\n      %s" % (gid, other, why))

    if unresolved:
        print("\nUNRESOLVED (armed) -- this tool could NOT answer.  Not clear; "
              "see LIMITS in the\nheader before quoting any of these as safe.")
        for (gid, _d, notes) in unresolved:
            print("  %s" % gid)
            for n in notes[:3]:
                print("      %s" % n)

    if show_all:
        print("\nCLEAR / not-armed -- %d id(s):" % len(clear))
        for (gid, deps, _n) in clear:
            tag = " (dep: %s)" % ",".join(sorted({d[0] for d in deps})) if deps else ""
            print("  %s%s" % (gid, tag))

    if frozen:
        print("\nFINDING: %d armed id(s) whose domain is structurally empty."
              % len(frozen))
        return 3
    print("\nno armed id hangs under an unarmed gate -- OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

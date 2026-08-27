#!/usr/bin/env python3
"""Cross-statement satisfiability census (strategy `0SAT` next cell).

`0SAT` asked whether the two legs of ONE conjunction can be true together.
This asks the next question over, and it is the first one that needs control
flow rather than a regex sweep:

    an early `return` guard establishes a fact for the rest of the function
    body -- is a LATER condition in that same body still satisfiable under it?

Concretely, inside one function body:

    if <G> then return ... end       -- after this line, `not G` holds
    ...
    if <C> then ... end              -- is <C> satisfiable under `not G`?

If a top-level disjunct of <C> carries a numeric comparison on the same lvalue
that contradicts what `not G` pins down, that disjunct is dead code -- it can
never be taken, on any frame, in any game mode. That is an ARITHMETIC fact,
not a frame phenomenon: no census of "did it fire?" can prove it, because the
line never executed in the first place (the `0SAT`/`0TERN` lesson).

SCOPE: strategy owns nine decision files (charter `0CLK`); this tool defaults
to exactly those. Whole-repo is available with --all but is deliberately not
the default -- see the charter note "要做就先把范围收到本组那九个决策文件里".

LIMITS (read these before believing a reading):
  * Lexical, not a Lua parser. Function bodies are found by keyword nesting
    (`function`/`if`/`for`/`while`/`do` ... `end`), strings and comments are
    stripped first. A file whose nesting does not balance is reported, not
    silently skipped.
  * Only `if <G> then return ... end` guards whose body is JUST a return are
    treated as facts -- and only while control flow stays at the guard's own
    nesting depth (a later line deeper inside some other block is still under
    the fact; a line at a SHALLOWER depth is not, and ends the fact's scope).
  * Facts are kept only from guards whose condition is a comparison or a
    top-level `or` of comparisons: negating those yields a CONJUNCTION of
    facts (sound). A guard with a top-level `and` negates to a disjunction --
    too weak to conclude anything, so it is dropped, not approximated.
  * lvalues are matched by normalized SOURCE TEXT (`DotaTime()` == `DotaTime ()`).
    Two textually identical calls are assumed to answer the same value within
    one evaluation of one function body -- true for the frame-scoped getters
    these files read, and the reason this stays sound in practice.
  * Only numeric-constant right-hand sides are compared (`0.08`, `5*60`,
    `18 * 60`). Anything else on either side makes the comparison opaque and
    it is ignored, never guessed at.
  * `==` / `~=` participate; `nil`/boolean comparisons do not.

Exit code 1 if any DEAD finding is present (so it can serve as a ratchet),
0 otherwise. `--json` prints machine-readable findings.
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lua_corpus import bots_lua_files, read_lua  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The nine files the strategy charter (`0CLK`) calls this group's decision path.
STRATEGY_FILES = [
    "bots/mode_farm_generic.lua",
    "bots/mode_laning_generic.lua",
    "bots/mode_retreat_generic.lua",
    "bots/mode_roam_generic.lua",
    "bots/mode_team_roam_generic.lua",
    "bots/FunLib/jmz_func.lua",
    "bots/FunLib/aba_defend.lua",
    "bots/FunLib/aba_push.lua",
    "bots/FunLib/aba_role.lua",
]

CMP_OPS = ("<=", ">=", "==", "~=", "<", ">")

# Block openers. `for` / `while` are deliberately NOT here: they always open
# through their own `do`, which may sit on a later line -- counting both would
# double-count and inflate depth forever (that inflation is exactly what made
# the first version leak a fact 200 lines across a function boundary).
OPEN_KW = re.compile(r"\b(function|if|do|repeat)\b")
CLOSE_KW = re.compile(r"\b(end|until)\b")
FUNC_RE = re.compile(r"(^\s*(local\s+)?function\b|=\s*function\b)")


# ---------------------------------------------------------------- lexing ----

BLOCK_OPEN_RE = re.compile(r"(--)?\[(=*)\[")


def strip_file(lines):
    """strip_noise over a whole file, carrying `--[[ ]]` block state across lines.

    Line-at-a-time stripping counted the `do` in "furnished to do so" inside
    three MIT license headers as a block opener, and those files then read as
    structurally unbalanced. A long comment is exactly where prose keywords
    live, so this is not a corner case.

    The block opener must be looked for on the RAW line: `--[[` starts with the
    line-comment marker, so a stripped line has already erased it.
    """
    out = []
    level = None            # closing `=` count while inside a block, else None
    for line in lines:
        if level is not None:
            close = line.find("]" + "=" * level + "]")
            if close < 0:
                out.append(" " * len(line))
                continue
            cut = close + level + 2
            out.append(" " * cut + strip_noise(line[cut:]))
            level = None
            continue
        m = BLOCK_OPEN_RE.search(line)
        # Only trust an opener the single-line stripper agrees is live code:
        # `[[` inside a quoted string, or after a plain `--`, is not a block.
        if m and (m.group(1) or strip_noise(line)[m.start():m.end()] == m.group(0)):
            head = strip_noise(line[: m.start()])
            lvl = len(m.group(2))
            close = line.find("]" + "=" * lvl + "]", m.end())
            if close < 0:
                out.append(head + " " * (len(line) - len(head)))
                level = lvl
                continue
            cut = close + lvl + 2
            out.append(head + " " * (cut - len(head)) + strip_noise(line[cut:]))
            continue
        out.append(strip_noise(line))
    return out


def strip_noise(line):
    """Neutralize string literals and comments, keeping column positions.

    Comments become spaces. String literals become an IDENTIFIER-SHAPED token
    of the same length: word characters survive, everything else (the quotes
    included) becomes `_`. That is deliberate and load-bearing in two ways:

      * blanking strings to spaces made `bot:HasModifier('modifier_bkb')` and
        `bot:HasModifier('modifier_lich_slow')` normalize to the SAME lvalue
        text, and the tool then called `mode_roam_generic:1434` dead code.
        Two different modifier names are two different predicates.
      * `_` rather than a symbol keeps a word inside a string (`'x or y'`)
        from ever forming a `\\bor\\b` boundary and being mistaken for a
        top-level disjunction.

    Collision is possible in principle (`'a-b'` and `'a_b'` map alike); no
    identifier this repo passes to a predicate distinguishes itself that way.
    """
    out = []
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if ch == "-" and line.startswith("--", i):
            out.append(" " * (n - i))
            break
        if ch in "\"'":
            quote = ch
            out.append("_")
            i += 1
            while i < n:
                if line[i] == "\\":
                    out.append("__")
                    i += 2
                    continue
                if line[i] == quote:
                    out.append("_")
                    i += 1
                    break
                out.append(line[i] if line[i].isalnum() or line[i] == "_" else "_")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)[:n].ljust(n)


def depth_delta(code):
    """Net nesting change of one already-stripped line.

    `elseif` does not open a block and is not matched: `\\bif\\b` finds no word
    boundary between `else` and `if`.
    """
    opens = len(OPEN_KW.findall(code))
    closes = len(CLOSE_KW.findall(code))
    return opens - closes


# ------------------------------------------------------- expression split ----

def split_top(expr, sep):
    """Split on a top-level `and`/`or`, respecting parentheses."""
    parts = []
    depth = 0
    i = 0
    start = 0
    pat = re.compile(r"\b" + sep + r"\b")
    while i < len(expr):
        c = expr[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0:
            m = pat.match(expr, i)
            if m:
                parts.append(expr[start:i])
                i = m.end()
                start = i
                continue
        i += 1
    parts.append(expr[start:])
    return [p.strip() for p in parts]


def unwrap(expr):
    """Drop one layer of fully-enclosing parentheses."""
    expr = expr.strip()
    while expr.startswith("(") and expr.endswith(")"):
        depth = 0
        for i, c in enumerate(expr):
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0 and i != len(expr) - 1:
                    return expr
        expr = expr[1:-1].strip()
    return expr


NUM_RE = re.compile(r"^[-+]?(\d+\.?\d*|\.\d+)(\s*[*/]\s*[-+]?(\d+\.?\d*|\.\d+))*$")


def as_number(text):
    text = unwrap(text)
    if not NUM_RE.match(text):
        return None
    try:
        return float(eval(text, {"__builtins__": {}}, {}))  # digits and * / only
    except Exception:
        return None


LVALUE_RE = re.compile(r"^[A-Za-z_][\w.:\[\]'\"]*(\(\s*[\w.:,\s'\"\[\]]*\))?$")


def norm_lvalue(text):
    text = unwrap(text)
    compact = re.sub(r"\s+", "", text)
    if not compact or as_number(text) is not None:
        return None
    if not LVALUE_RE.match(compact):
        return None
    return compact


FLIP = {"<": ">", "<=": ">=", ">": "<", ">=": "<=", "==": "==", "~=": "~="}
NEGATE = {"<": ">=", "<=": ">", ">": "<=", ">=": "<", "==": "~=", "~=": "=="}


def parse_cmp(expr):
    """-> (lvalue, op, number) with the lvalue on the left, or None."""
    expr = unwrap(expr)
    depth = 0
    i = 0
    while i < len(expr):
        c = expr[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0:
            for op in CMP_OPS:
                if expr.startswith(op, i):
                    # `<=` must win over `<`; CMP_OPS is ordered for that.
                    lhs, rhs = expr[:i], expr[i + len(op):]
                    lv, num = norm_lvalue(lhs), as_number(rhs)
                    if lv is not None and num is not None:
                        return (lv, op, num)
                    lv, num = norm_lvalue(rhs), as_number(lhs)
                    if lv is not None and num is not None:
                        return (lv, FLIP[op], num)
                    return None
        i += 1
    return None


# ------------------------------------------------------- satisfiability ----

def unsat(constraints):
    """constraints: list of (op, number) on ONE lvalue over the reals."""
    lo, lo_open = float("-inf"), False
    hi, hi_open = float("inf"), False
    eq = None
    neq = set()
    for op, v in constraints:
        if op == "<":
            if v < hi or (v == hi and not hi_open):
                hi, hi_open = v, True
        elif op == "<=":
            if v < hi:
                hi, hi_open = v, False
        elif op == ">":
            if v > lo or (v == lo and not lo_open):
                lo, lo_open = v, True
        elif op == ">=":
            if v > lo:
                lo, lo_open = v, False
        elif op == "==":
            if eq is not None and eq != v:
                return True
            eq = v
        elif op == "~=":
            neq.add(v)
    if eq is not None:
        if eq in neq:
            return True
        return not (lo < eq < hi
                    or (eq == lo and not lo_open)
                    or (eq == hi and not hi_open))
    if lo > hi:
        return True
    if lo == hi and (lo_open or hi_open):
        return True
    if lo == hi and lo in neq:
        return True
    return False


# ---------------------------------------------------------------- scan ----

COND_RE = re.compile(r"^\s*(?:\}\s*)?(elseif|if)\b(.*?)\bthen\b(.*)$")
RETURN_ONLY_RE = re.compile(r"^\s*return\b")
ELSE_RE = re.compile(r"^\s*(else|elseif)\b")
# `x = ...` but never `==`, `<=`, `>=`, `~=`. Captures the base identifier so
# `nLocationAoE = ...` invalidates a fact pinned on `nLocationAoE.count`.
ASSIGN_RE = re.compile(
    r"(?:^|[;,]|\blocal\b)\s*([A-Za-z_]\w*)[\w.:\[\]'\"]*\s*(?<![=<>~!])=(?!=)")


IDENT_RE = re.compile(r"[A-Za-z_]\w*")


def assigned_names(line):
    """Every name that could be rebound by an assignment on this line.

    Deliberately over-inclusive: on a hit, EVERY identifier left of the `=`
    is invalidated (so `local a, b = f()` kills both, not just `b`). Killing a
    fact too eagerly costs a missed finding; keeping a stale one costs a wrong
    one, and this tool's whole claim is arithmetic certainty.
    """
    m = ASSIGN_RE.search(line)
    if not m:
        return set()
    return set(IDENT_RE.findall(line[: m.end() - 1]))


def depends_on(lvalue):
    """Every name a pinned lvalue's value depends on -- receiver AND arguments.

    `IsValidBuildingTarget(b)` depends on `b`, so `b = GetBarracks(...)` must
    kill the fact. Keying invalidation on the leading identifier alone made
    the tool call four consecutive `if IsValidBuildingTarget(b)` blocks in
    `aba_defend` dead, missing the `b = ...` rebind before each one.
    """
    return set(IDENT_RE.findall(lvalue))


def scan_file(path, rel, stats=None):
    raw = read_lua(path, errors="replace").splitlines()   # GH #243: vanish -> exit 2
    code = strip_file([l.rstrip("\n") for l in raw])
    if stats is None:
        stats = {}

    findings = []
    depth = 0
    # facts[] entries: {'depth', 'line', 'guard',
    #                   'by_lvalue': {lv: [(op, num)]},   -- numeric intervals
    #                   'by_atom':   {lv: 'truthy'|'falsy'|'isnil'|'notnil'}}
    facts = []

    for idx, line in enumerate(code):
        lineno = idx + 1
        # A fact stops applying the moment control flow leaves the block that
        # established it -- including the function `end`, which drops depth
        # below every fact the body put on the stack.
        facts = [f for f in facts if f["depth"] <= depth]
        if FUNC_RE.search(line):
            facts = []

        # An `else` / `elseif` closes the sibling branch: anything the guards
        # inside it established does NOT hold here. Without this the tool
        # reports `hero_storm_spirit:326` (`count >= 3` in the else-arm of an
        # `if IsInLaningPhase()` whose then-arm early-returns on `count >= 2`)
        # as dead code. It is not: the two arms never both run.
        if ELSE_RE.match(line):
            facts = [f for f in facts if f["depth"] < depth]

        # A reassignment kills every fact pinned on that name. Without this the
        # tool reports `minion_with_skill:543` as dead, missing the line in
        # between that calls FindAoELocation a second time and rebinds
        # `nLocationAoE` -- the second `count >= 2` asks about a NEW object.
        assigned = assigned_names(line)
        if assigned:
            kept = []
            for f in facts:
                f = dict(f)
                f["by_lvalue"] = {k: v for k, v in f["by_lvalue"].items()
                                  if not (depends_on(k) & assigned)}
                f["by_atom"] = {k: v for k, v in f["by_atom"].items()
                                if not (depends_on(k) & assigned)}
                if f["by_lvalue"] or f["by_atom"]:
                    kept.append(f)
            facts = kept

        m = COND_RE.match(line)
        if m and facts:
            cond = m.group(2).strip()
            tail = m.group(3).strip()
            body_is_return = bool(RETURN_ONLY_RE.match(tail))
            # collect facts in scope
            pinned = {}
            pinned_atom = {}
            origin = {}
            for f in facts:
                for lv, cons in f["by_lvalue"].items():
                    pinned.setdefault(lv, []).extend(cons)
                    origin.setdefault(lv, []).append(f)
                for atom, kind in f["by_atom"].items():
                    pinned_atom.setdefault(atom, kind)
                    origin.setdefault(atom, []).append(f)
            stats["cond_under_fact"] = stats.get("cond_under_fact", 0) + 1
            disjuncts = split_top(cond, "or")
            dead = []
            for d in disjuncts:
                conj = split_top(d, "and")
                by_lv = {}
                atoms = []
                for c in conj:
                    p = parse_cmp(c)
                    if p:
                        by_lv.setdefault(p[0], []).append((p[1], p[2]))
                        continue
                    a = parse_atom(c)
                    if a:
                        atoms.append(a)
                hit = None
                for lv, cons in by_lv.items():
                    if lv not in pinned:
                        continue
                    stats["lvalue_overlap"] = stats.get("lvalue_overlap", 0) + 1
                    if unsat(cons + pinned[lv]):
                        hit = (lv, cons, pinned[lv], origin[lv][0])
                        break
                if hit is None:
                    for atom, kind in atoms:
                        if atom not in pinned_atom:
                            continue
                        stats["atom_overlap"] = stats.get("atom_overlap", 0) + 1
                        if pinned_atom[atom] in ATOM_CONTRADICTS[kind]:
                            hit = (atom, [("is", kind)],
                                   [("is", pinned_atom[atom])], origin[atom][0])
                            break
                dead.append(hit)
            if any(dead):
                all_dead = all(dead)
                for h, d in zip(dead, disjuncts):
                    if not h:
                        continue
                    lv, cons, pin, src = h
                    findings.append({
                        "file": rel,
                        "line": lineno,
                        "kind": "DEAD-BRANCH" if all_dead else "DEAD-DISJUNCT",
                        "lvalue": lv,
                        "cond": cond,
                        "disjunct": d.strip(),
                        "here": [[o, n] for o, n in cons],
                        "guard_line": src["line"],
                        "guard": src["guard"],
                        "implies": [[o, n] for o, n in pin],
                        "body_is_return": body_is_return,
                    })

        # does THIS line establish a new fact?
        if m:
            cond = m.group(2).strip()
            tail = m.group(3).strip()
            if m.group(1) == "if" and RETURN_ONLY_RE.match(tail) and "end" in tail:
                stats["guard_1line"] = stats.get("guard_1line", 0) + 1
                by_lv, by_atom = negated_facts(cond)
                if by_lv or by_atom:
                    stats["fact"] = stats.get("fact", 0) + 1
                    facts.append({"depth": depth, "line": lineno, "guard": cond,
                                  "by_lvalue": by_lv, "by_atom": by_atom})
            elif m.group(1) == "if" and not tail:
                # multi-line guard: body must be a single `return`, then `end`
                nxt = code[idx + 1].strip() if idx + 1 < len(code) else ""
                nxt2 = code[idx + 2].strip() if idx + 2 < len(code) else ""
                if RETURN_ONLY_RE.match(nxt) and nxt2 == "end":
                    stats["guard_3line"] = stats.get("guard_3line", 0) + 1
                    by_lv, by_atom = negated_facts(cond)
                    if by_lv or by_atom:
                        stats["fact"] = stats.get("fact", 0) + 1
                        facts.append({"depth": depth, "line": lineno,
                                      "guard": cond, "by_lvalue": by_lv,
                                      "by_atom": by_atom})

        depth += depth_delta(line)
    if depth != 0:
        # Recorded, not just printed: every finding rests on knowing which
        # block a line sits in, so an unbalanced file's reading means nothing
        # and a caller must be able to assert on it.
        stats.setdefault("unbalanced", []).append((rel, depth))
        print("UNBALANCED %s  net nesting %+d (findings from it are suspect)"
              % (rel, depth), file=sys.stderr)
    return findings


NOT_RE = re.compile(r"^not\b(.*)$")


def parse_atom(expr):
    """-> (atom, kind) for the truthiness/nil shapes, else None.

    kinds: 'truthy' | 'falsy' | 'isnil' | 'notnil' -- what the EXPRESSION
    asserts about `atom` when the expression itself is true.
    """
    expr = unwrap(expr)
    m = NOT_RE.match(expr)
    if m:
        inner = norm_lvalue(m.group(1))
        return (inner, "falsy") if inner else None
    # `X == nil` / `X ~= nil`
    for op, kind in (("==", "isnil"), ("~=", "notnil")):
        parts = expr.split(op)
        if len(parts) == 2:
            lv, rhs = norm_lvalue(parts[0]), unwrap(parts[1])
            if lv and rhs == "nil":
                return (lv, kind)
            lv, lhs = norm_lvalue(parts[1]), unwrap(parts[0])
            if lv and lhs == "nil":
                return (lv, kind)
    lv = norm_lvalue(expr)
    return (lv, "truthy") if lv else None


# What holds about `atom` once an expression asserting `kind` is known FALSE.
ATOM_NEGATE = {"truthy": "falsy", "falsy": "truthy",
               "isnil": "notnil", "notnil": "isnil"}

# A later conjunct asserting `kind` is impossible when the established fact is
# one of these. `isnil` implies `falsy`; `truthy` implies `notnil`.
ATOM_CONTRADICTS = {
    "truthy": {"falsy", "isnil"},
    "falsy": {"truthy"},
    "isnil": {"notnil", "truthy"},
    "notnil": {"isnil"},
}


def negated_facts(guard_cond):
    """Facts that hold AFTER an early-return guard on `guard_cond`.

    Sound only when negation yields a conjunction: a bare term, or a top-level
    `or` of terms. A top-level `and` negates to a disjunction -- too weak to
    conclude anything, so it is dropped rather than approximated.

    Returns (numeric_by_lvalue, atom_by_lvalue).
    """
    if len(split_top(guard_cond, "and")) > 1:
        return {}, {}
    by_lv = {}
    by_atom = {}
    for part in split_top(guard_cond, "or"):
        p = parse_cmp(part)
        if p:
            lv, op, num = p
            by_lv.setdefault(lv, []).append((NEGATE[op], num))
            continue
        a = parse_atom(part)
        if a:
            atom, kind = a
            by_atom[atom] = ATOM_NEGATE[kind]
    return by_lv, by_atom


def fmt_c(c):
    op, val = c
    return "%s %s" % (op, val if isinstance(val, str) else ("%g" % val))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true",
                    help="scan every .lua under bots/ instead of the nine")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.all:
        targets = [(p, os.path.relpath(p, REPO)) for p in bots_lua_files(REPO)]
    else:
        targets = [(os.path.join(REPO, r), r) for r in STRATEGY_FILES]

    findings = []
    stats = {}
    for path, rel in targets:
        if not os.path.exists(path):
            print("MISSING   %s" % rel)
            continue
        findings.extend(scan_file(path, rel, stats))

    if args.json:
        print(json.dumps({"findings": findings, "stats": stats},
                         indent=2, sort_keys=True))
    else:
        # The reach counters are the point of a zero reading: "0 findings" is
        # only news if the tool actually looked at something.
        print("GUARD-IMPLICATION  files %d  findings %d  "
              "guards(1line/3line) %d/%d  facts %d  conds-under-fact %d  "
              "overlaps num/atom %d/%d"
              % (len(targets), len(findings),
                 stats.get("guard_1line", 0), stats.get("guard_3line", 0),
                 stats.get("fact", 0), stats.get("cond_under_fact", 0),
                 stats.get("lvalue_overlap", 0), stats.get("atom_overlap", 0)))
        for f in findings:
            print()
            print("%-14s %s:%d" % (f["kind"], f["file"], f["line"]))
            print("   guard   :%d  if %s then return" % (f["guard_line"], f["guard"]))
            print("   implies    %s %s" % (f["lvalue"],
                                           " and ".join(fmt_c(c) for c in f["implies"])))
            print("   here       %s %s" % (f["lvalue"],
                                           " and ".join(fmt_c(c) for c in f["here"])))
            print("   disjunct   %s" % f["disjunct"])
    return 1 if any(f["kind"] == "DEAD-BRANCH" for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Which `if/elseif` ladders test ONE expression against a threshold family in
an order that makes a later rung unreachable?  (dev-only, read-only, zero AWS;
reads bots/**.lua only.)

WHY THIS EXISTS
---------------
A graded rule is normally written as a ladder: the same measured quantity
compared against several thresholds, one rung per tier.  For a `>=` ladder the
rungs must be tested in DESCENDING order, because `X >= 750` is a strict subset
of `X >= 450` -- put the small threshold first and the big rung is dead code
that no input can ever reach.  For a `<=` ladder the same argument runs the
other way (ASCENDING).

That defect is invisible to every gate this repo runs.  It is valid Lua, so
`tests/test_smoke_load.lua` loads it; it accesses no undefined global, so
`luacheck bots game` (iron rule 6's static half, `only = {"1"}`) is silent; and
the dead rung's ONLY symptom in a game is a number that stays one tier too low
-- there is no crash, no log line, and `print()` never reaches the server
console anyway (AGENTS.md, "no bot-side debugging").  So it survives
indefinitely, and the reader who greps the file sees both tiers written down
and believes both are live.

WHAT IT ANSWERS, AND WHAT IT DOES NOT
-------------------------------------
It answers exactly one question, syntactically: **within one if/elseif chain,
does a later rung compare the SAME left-hand expression against a numeric
threshold that its own earlier rung already subsumes?**  When it says yes, the
rung is unreachable -- that half is sound, and it is the half worth having.

It does NOT answer whether the ladder's DOMAIN is reachable at all.  A dead
rung inside a branch that no game ever enters is dead twice over, and only
`corpus_hero_census.py` and a look at the fixture archive can say which.  Keep
those two readings apart: this tool finds the defect, the domain price decides
whether a fix can ever buy condition (a).  That order is the standing lesson
from GH #400 / #422 / #426 -- run the cheap falsifier BEFORE choosing a lever,
not after landing one.

TURBO/NORMAL PAIRS ARE RESOLVED, NOT SKIPPED
--------------------------------------------
This codebase writes most time thresholds as `(J.IsModeTurbo() and A or B)`.
A ladder can therefore be dead in Turbo and live in normal play, or the other
way round, and a scanner that only understood bare literals would miss the
whole family -- the single finding this tool has today is written exactly that
way.  Both legs are evaluated and reported separately, and Turbo is the leg
that matters here (AGENTS.md: Turbo is the optimization target).

KNOWN LIMITS (do not launder these away)
----------------------------------------
* Left-hand sides are matched as NORMALIZED TEXT, not semantically.  Two spellings
  of the same quantity (`DotaTime()` vs a local holding it) are two different
  ladders to this tool, so the scan under-reports.  A reported finding is still
  a finding -- textual identity of the LHS is sufficient for the subsumption
  argument, never necessary.
* Only chains whose rung conditions are a bare `LHS <op> <numeric literal>` are
  compared.  A rung carrying an extra conjunct is skipped, because the conjunct
  may be exactly what makes it reachable.  Under-reports; never over-reports.
* A rung that is unreachable is not automatically a BUG.  It can be a
  deliberately parked tier.  The tool reports; the reader judges.
* Comment stripping is textual (`--` outside a balanced quote count), the same
  approximation every other census here uses.
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lua_corpus  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Every finding carries a judgement, so a NEW one is visibly new.  Keyed by
# (relpath, first_rung_line, dead_rung_line).
JUDGED = {
    ("bots/ability_item_usage_generic.lua", 1541, 1543):
        "GH #431: the blink cast-range ladder for item_enhancement_keen_eyed. "
        "Written ascending, so the 12.5-turbo-minute +135 rung is unreachable "
        "in BOTH modes and the bonus stays +125 forever.  REGISTERED, NOT "
        "REPAIRED: no fixture inventory in the archive holds any enhancement "
        "(0 of 107), so condition (a) cannot be bought on this corpus -- the "
        "numbers, including the two that the first draft of that reading got "
        "wrong, are pinned in tests/test_threshold_chain_census.py section 3.",
}


def strip_comments(text):
    out = []
    for line in text.split("\n"):
        i = line.find("--")
        if i >= 0 and (line[:i].count('"') + line[:i].count("'")) % 2 == 0:
            line = line[:i]
        out.append(line)
    return out


COND = re.compile(r"^\s*(else)?if\s+(.+?)\s+then\s*$")
CLOSE = re.compile(r"^\s*(end|else)\s*$")
CMP = re.compile(r"^(.*?)\s*(>=|<=|>|<)\s*(.*)$")
TURBO_TERNARY = re.compile(
    r"^\(?\s*(?:J\.)?IsModeTurbo\(\)\s+and\s+(.+?)\s+or\s+(.+?)\s*\)?$")
ARITH_ONLY = re.compile(r"^[-\d.\s*+/()]+$")


def literal(expr):
    """Value of a pure-arithmetic literal expression, else None."""
    e = expr.strip()
    if not e or not ARITH_ONLY.match(e):
        return None
    try:
        return float(eval(e, {"__builtins__": {}}, {}))  # arithmetic only
    except Exception:
        return None


def threshold(expr):
    """(turbo_value, normal_value) for a threshold expression, else None."""
    e = expr.strip()
    m = TURBO_TERNARY.match(e)
    if m:
        a, b = literal(m.group(1)), literal(m.group(2))
        return None if a is None or b is None else (a, b)
    v = literal(e)
    return None if v is None else (v, v)


def parse_rung(cond):
    """(lhs, op, (turbo, normal)) for `LHS <op> <literal>`, else None."""
    m = CMP.match(cond)
    if not m:
        return None
    lhs, op, rhs = m.group(1).strip(), m.group(2), m.group(3).strip()
    if not lhs or literal(lhs) is not None:
        return None
    # A rung carrying an extra conjunct is not a bare comparison -- skip it,
    # because that conjunct may be exactly what makes the rung reachable.  The
    # test is on the LEFT side only: the right side is allowed to contain
    # `and`/`or`, since the repo writes nearly every time threshold as the
    # ternary `(J.IsModeTurbo() and A or B)`, and `threshold()` is what decides
    # whether the right side is wholly a threshold or has a conjunct glued on.
    if re.search(r"(?<![\w.])(and|or|not)(?![\w.])", lhs):
        return None
    t = threshold(rhs)
    return None if t is None else (re.sub(r"\s+", " ", lhs), op, t)


def subsumes(first_op, first_val, later_op, later_val):
    """Does the FIRST rung already cover everything the LATER rung matches?"""
    if first_op in (">=", ">") and later_op in (">=", ">"):
        return later_val >= first_val
    if first_op in ("<=", "<") and later_op in ("<=", "<"):
        return later_val <= first_val
    return False


def scan(root=None):
    findings, chains = [], 0
    for path in lua_corpus.bots_lua_files(root):
        rel = os.path.relpath(path, root or REPO)
        lines = strip_comments(lua_corpus.read_lua(path))
        chain = []
        for n, raw in enumerate(lines, 1):
            if CLOSE.match(raw):
                chain = []
                continue
            m = COND.match(raw)
            if not m:
                continue
            rung = parse_rung(m.group(2).strip())
            if not m.group(1):                      # a fresh `if` starts a chain
                chains += 1
                chain = [(n, rung)] if rung else []
                continue
            if rung and chain:                      # `elseif` continues it
                for pn, prev in chain:
                    if not prev or prev[0] != rung[0]:
                        continue
                    dead = []
                    for leg, label in ((0, "turbo"), (1, "normal")):
                        if subsumes(prev[1], prev[2][leg], rung[1], rung[2][leg]):
                            dead.append(label)
                    if dead:
                        findings.append({
                            "file": rel, "first_line": pn, "dead_line": n,
                            "lhs": rung[0], "first": (prev[1], prev[2]),
                            "dead": (rung[1], rung[2]), "dead_in": dead,
                        })
            if rung:
                chain.append((n, rung))
    return findings, chains


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=None, help="corpus root (default: repo)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    try:
        findings, chains = scan(args.root)
    except lua_corpus.CorpusVanished as exc:
        # exit 2 -- "did not run" is not "clean" and not "found nothing"
        lua_corpus.uncertifiable(exc, "threshold_chain_census")
        return 2

    # A zero reading and a scanner that reached nothing look identical on paper
    # unless the denominator is printed too.
    print("SCANNED   if-chains %d" % chains)
    novel = 0
    for f in findings:
        key = (f["file"], f["first_line"], f["dead_line"])
        known = key in JUDGED
        if not known:
            novel += 1
        print("DEAD-RUNG %s:%d -> :%d   dead in %s%s" % (
            f["file"], f["first_line"], f["dead_line"],
            "+".join(f["dead_in"]), "" if known else "   *NEW*"))
        if not args.quiet:
            print("          lhs    %s" % f["lhs"])
            print("          first  %s %s  (turbo %g / normal %g)" % (
                f["first"][0], f["first"][1], f["first"][1][0], f["first"][1][1]))
            print("          dead   %s %s  (turbo %g / normal %g)" % (
                f["dead"][0], f["dead"][1], f["dead"][1][0], f["dead"][1][1]))
            if known:
                print("          judged: %s" % JUDGED[key])
    print("FINDINGS  %d  (judged %d, new %d)" % (
        len(findings), len(findings) - novel, novel))
    if not findings:
        return 0
    return 3 if novel else 0


if __name__ == "__main__":
    sys.exit(main())

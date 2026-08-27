#!/usr/bin/env python3
"""Write-only local census -- the class this repo's own gate cannot see.

`.luacheckrc` sets `only = { "1" }`: ONLY the 1xx (global access) warnings are
enforced.  luacheck's unused-variable family is 2xx, so it is switched off
repo-wide, deliberately and for a good reason (the inherited OHA tree is full
of harmless unused parameters and the 1xx line is the one that catches typos).
The side effect is that a local which is ASSIGNED and NEVER READ passes the
gate silently, forever, in every file.

That class is worth a census because its members are not all the same thing:

  (i)  a scratch value nobody got round to deleting -- dead code, zero
       behavior, not worth touching on its own (`0IMPL`'s allowlist call);
  (ii) a DROPPED CONSUMER -- the value is computed because a sibling copy of
       the same block reads it, and this copy lost the line that did.  That
       one is not cosmetic: it says a graded ladder has silently collapsed to
       one rung, and the reader of the block cannot tell, because the
       computation is right there looking load-bearing.

Only (ii) is a lever, and the census CANNOT tell (i) from (ii).  The obvious
separator -- "is this same name read in some other file?" -- is printed, but
it is a HINT, not evidence, and measured on this tree it is wrong 17 times out
of 18: `Customize`, `Localization`, `attackRange`, `botHealthRegen`, `_` and
friends are read all over the tree as entirely unrelated locals.  A NAME IS
NOT AN IDENTITY.  What promotes a hit to (ii) is narrower and has to be read
by a human: the other file's read sits inside a VERBATIM COPY of the same
block.  The column is labelled `same-name-elsewhere` for that reason, and
anyone quoting it as "dropped consumer" is quoting the wrong column.

A third thing the class contains, and the reason "write-only" never implies
"safe to delete": `local Customize = require(...)`.  The value is unused; the
`require` is a load side effect.  Three of the thirteen findings on this tree
are exactly that.

SCOPE: defaults to the nine files the strategy charter (`0CLK`) calls this
group's decision path, matching `guard_implication_census.py`.  `--all` walks
every `.lua` under `bots/`.

SOUNDNESS -- why this needs no scope analysis:
    a name that has ZERO read occurrences anywhere in the file cannot be read
    by any scope in that file.
So the tool never resolves shadowing, never builds a symbol table, and cannot
report a live local as dead by getting a scope wrong.  The price is that it
under-reports: a name read in one function and write-only in another is not
reported.  That is the safe direction, and it is stated rather than hidden.

LIMITS (read before believing a reading):
  * Lexical.  Strings and comments are neutralized first (shared with
    `guard_implication_census.py`, which is where the `--[[ ]]` and
    string-identity lessons already live).
  * A READ is any `\\bNAME\\b` occurrence that is not the declaration, not a
    bare assignment target (`NAME =` / `a, NAME = ...`), and not a field or
    method name (`t.NAME`, `t:NAME()`).  `NAME.x = 1` and `NAME[i] = 2` READ
    NAME and are counted as reads -- they are.
  * `local function NAME` is skipped: a locally-declared function that is
    never called in its own file is a different question (it may be exported
    through a table), and answering it would need the export map.
  * Multi-name declarations (`local a, b = f()`) are scanned per name but
    tagged `multi`: discarding the second return value is idiomatic, so those
    are reported separately and are not ratchet material.
  * Engine-call counting is textual: any `Get*(` on the assigning lines,
    method (`bot:GetNearbyTowers(`) or bare global (`GetUnitToLocationDistance(`).
    Both forms occur in these findings.  It is a cost hint, not a profile.

Exit 1 if any non-`multi` finding is outside the allowlist below, 0 otherwise,
so this can serve as a ratchet.  `--json` prints machine-readable findings.
"""

import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard_implication_census import STRATEGY_FILES, strip_file  # noqa: E402
from lua_corpus import bots_lua_files, read_lua  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Known, judged, deliberately-not-swept single-name write-only locals, keyed
# (file, name).  A new entry needs a sentence saying WHICH of (i)/(ii)/require
# it is and why it stays.  Sweeping any of them means DELETING its line here --
# the list can only shrink, and a newly written one goes red the day it lands.
#
# Nothing here is "fixed by removing it": `0IMPL` and `0SAT` both ruled that
# harmless dead code is not worth a behavior-carrying edit, and the three
# `require` entries below are not dead at all.
ALLOWLIST = {
    # require(): value unused, LOAD SIDE EFFECT load-bearing.  Do not delete.
    ("bots/mode_retreat_generic.lua", "Customize"): "require side effect",
    ("bots/mode_team_roam_generic.lua", "Localization"): "require side effect",
    ("bots/mode_team_roam_generic.lua", "Roles"): "require side effect",
    # (i) scratch, zero engine calls.
    ("bots/mode_retreat_generic.lua", "fRetreatFromTormentorTime"): "scratch; sibling fRetreatFromRoshanTime is read",
    ("bots/mode_team_roam_generic.lua", "nTpSolt"): "scratch constant 15, never consulted",
    ("bots/mode_team_roam_generic.lua", "nTowerDamage"): "scratch; the loop below uses X.GetLastHitHealth instead",
    ("bots/FunLib/jmz_func.lua", "nearByHeroCacheDuration"): "scratch; cache TTL comment only",
    ("bots/FunLib/jmz_func.lua", "printN"): "debug counter left from a print() era (no bot-side printing exists)",
    # (i) scratch, but each burns an engine call every time its line runs.
    ("bots/mode_farm_generic.lua", "farmDistance"): "GetUnitToLocationDistance, unread",
    ("bots/FunLib/jmz_func.lua", "attackRange"): "bot:GetAttackRange(), unread (and mock-blind per GH #145)",
    ("bots/FunLib/jmz_func.lua", "botHealthRegen"): "bot:GetHealthRegen()*2, unread; shadows a real upvalue of the same name in mode_retreat_generic",
    ("bots/mode_roam_generic.lua", "vBeamEndLoc"): "phoenix sun-ray beam endpoint; the block targets by RADIUS instead -- geometry computed, never consulted",
    # (ii) DROPPED RUNG -- the only one on this tree; charter 0DEAD, GH #182.
    # Kept, not restored: the rung's own domain is empty (closest approach in
    # its band is 1310 u against a 1200 u ring).  Deleting it would erase the
    # evidence that the ladder lost a rung; restoring it buys zero frames.
    ("bots/mode_retreat_generic.lua", "nLongEnemyTowers"): "dropped rung 1 of the graded tower ladder; sibling mode_farm_generic:1203 reads it",
}

DECL_RE = re.compile(r"\blocal\b(?!\s+function\b)\s+([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)")
ASSIGN_RE = re.compile(r"^\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*(?<![=~<>])=(?!=)")
ENGINE_CALL_RE = re.compile(r"(?<![\w.])(?:[A-Za-z_]\w*\s*[:.]\s*)?Get[A-Za-z_]\w*\s*\(")
# Load-time path helper, not a per-frame query: counting it made every
# `local X = require(GetScriptDirectory()..'/...')` line read as costing an
# engine call, which is the opposite of this column's point.
ENGINE_CALL_FREE = ("GetScriptDirectory",)


def statements(code):
    """Split one stripped line into `;`-separated statements, keeping offsets."""
    out = []
    start = 0
    for i, ch in enumerate(code):
        if ch == ";":
            out.append(code[start:i])
            start = i + 1
    out.append(code[start:])
    return out


def names_in(namelist):
    return [n.strip() for n in namelist.split(",") if n.strip()]


_STRIP_CACHE = {}


def stripped(path):
    """Stripped source, memoized -- `--all` cross-references O(files x findings)."""
    if path not in _STRIP_CACHE:
        # GH #243: keepends=True is `readlines()` exactly; vanish -> exit 2.
        _STRIP_CACHE[path] = strip_file(
            read_lua(path, errors="replace").splitlines(True))
    return _STRIP_CACHE[path]


def scan_file(path, rel, stats):
    code = stripped(path)

    decls = {}          # name -> {"lines": [...], "multi": bool}
    writes = {}         # name -> set of line numbers that are bare assignments
    for ln, line in enumerate(code, 1):
        for stmt in statements(line):
            for m in DECL_RE.finditer(stmt):
                nl = names_in(m.group(1))
                for name in nl:
                    d = decls.setdefault(name, {"lines": [], "multi": False})
                    d["lines"].append(ln)
                    if len(nl) > 1:
                        d["multi"] = True
                    writes.setdefault(name, set()).add(ln)
            m = ASSIGN_RE.match(stmt)
            if m:
                for name in names_in(m.group(1)):
                    writes.setdefault(name, set()).add(ln)

    stats[rel] = {"locals": len(decls)}

    findings = []
    for name, d in sorted(decls.items()):
        pat = re.compile(r"(?<![\w.:])" + re.escape(name) + r"\b")
        reads = 0
        for ln, line in enumerate(code, 1):
            for m in pat.finditer(line):
                # An occurrence on a line that only writes this name is a write.
                if ln in writes[name] and _is_write_occurrence(line, m.start(), name):
                    continue
                reads += 1
        if reads:
            continue
        assign_lines = sorted(writes[name])
        calls = sum(1 for ln in assign_lines
                    for m in ENGINE_CALL_RE.finditer(code[ln - 1])
                    if not any(free in m.group(0) for free in ENGINE_CALL_FREE))
        findings.append({
            "file": rel,
            "name": name,
            "decl_lines": d["lines"],
            "assign_lines": assign_lines,
            "engine_calls_on_assign": calls,
            "multi": d["multi"],
        })
    return findings


def _is_write_occurrence(line, col, name):
    """True if the occurrence at `col` is the target of a declaration/assignment.

    Both forms put the name to the LEFT of the statement's `=`, so the test is
    positional and needs no re-parse: find the statement this column sits in,
    then ask whether a top-level `=` follows the name within it.
    """
    start = line.rfind(";", 0, col) + 1
    end = line.find(";", col)
    stmt = line[start:] if end < 0 else line[start:end]
    rest = stmt[col - start + len(name):]
    return bool(re.match(r"\s*(,\s*[A-Za-z_]\w*\s*)*(?<![=~<>])=(?!=)", rest))


def other_file_readers(name, targets):
    """Files (other than the finding's own) that read a local of THIS NAME.

    Deliberately not called "dropped consumer": on this tree the column is
    wrong 17 times in 18.  `attackRange` is read in six files and none of them
    is the same computation.  What it is good for is narrowing where to LOOK;
    the promotion to (ii) is a human reading two blocks side by side.
    """
    hits = []
    pat = re.compile(r"(?<![\w.:])" + re.escape(name) + r"\b")
    for path, rel in targets:
        if not os.path.exists(path):
            continue
        code = stripped(path)
        if not any(pat.search(line) for line in code):
            continue
        for ln, line in enumerate(code, 1):
            for m in pat.finditer(line):
                if _is_write_occurrence(line, m.start(), name):
                    continue
                if re.search(r"\blocal\b\s*$", line[: m.start()]):
                    continue
                hits.append("%s:%d" % (rel, ln))
    return hits


def all_bot_files():
    # GH #243: one listing, one exclusion list, shared with every other census.
    out = [(p, os.path.relpath(p, REPO)) for p in bots_lua_files(REPO)]
    return sorted(out, key=lambda t: t[1])


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true",
                    help="scan every .lua under bots/ (default: the nine decision files)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if args.all:
        targets = all_bot_files()
    else:
        targets = [(os.path.join(REPO, r), r) for r in STRATEGY_FILES]

    universe = all_bot_files()

    findings = []
    stats = {}
    for path, rel in targets:
        if not os.path.exists(path):
            print("MISSING   %s" % rel)
            continue
        findings.extend(scan_file(path, rel, stats))

    for f in findings:
        f["read_elsewhere"] = other_file_readers(
            f["name"], [t for t in universe if t[1] != f["file"]])

    if args.json:
        print(json.dumps({"findings": findings, "stats": stats},
                         indent=2, sort_keys=True))
    else:
        total_locals = sum(s["locals"] for s in stats.values())
        # A zero reading and a scanner that reached nothing look identical on
        # paper unless the denominator is printed too (`0IMPL` judgement two).
        print("SCANNED   files %d  locals %d" % (len(stats), total_locals))
        for f in findings:
            tag = "multi" if f["multi"] else "single"
            known = (f["file"], f["name"]) in ALLOWLIST
            print("WRITE-ONLY %-28s %s:%s  [%s] engine-calls=%d%s" % (
                f["name"], f["file"], ",".join(str(x) for x in f["assign_lines"]),
                tag, f["engine_calls_on_assign"], "" if known else "  *NEW*"))
            if known:
                print("           judged: %s" % ALLOWLIST[(f["file"], f["name"])])
            if f["read_elsewhere"]:
                print("           same-name-elsewhere (HINT ONLY, not identity): %s%s" % (
                    ", ".join(f["read_elsewhere"][:4]),
                    " ..." if len(f["read_elsewhere"]) > 4 else ""))
        print("FINDINGS  %d (single %d, multi %d)" % (
            len(findings),
            sum(1 for f in findings if not f["multi"]),
            sum(1 for f in findings if f["multi"])))

    offending = [f for f in findings
                 if not f["multi"] and (f["file"], f["name"]) not in ALLOWLIST]
    return 1 if offending else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Census of calls whose FORM disagrees with the declaration -- or that have no
declaration anywhere in the tree.

WHY THIS IS A SEPARATE AXIS FROM call_arity_census.py.  That tool compares the
argument COUNT of a dotted call against its declaration, and its very first act
is

    if name not in decls: continue           # call_arity_census.py, census()

so a name that resolves to NOTHING is not a finding there -- it is invisible,
and it is not even in the stats line.  That is the hole this tool fills.  The
two are complementary and deliberately not merged: arity asks "is this call
handed the right number of things", form asks "is there anything at the other
end of this call at all, and is it being called the way it was declared".

WHY IT MATTERS MORE HERE THAN IN ORDINARY LUA.  `AGENTS.md`: `print()` never
reaches the server console and the engine's error handler is broken -- an error
inside a Think surfaces as `error in error handling` with the Lua text masked.
So a nil call does not announce itself as a crash.  It silently costs that bot
that Think, and the only evidence is behaviour that stops mid-decision.  A
class that cannot be debugged at runtime has to be caught at the desk.

THE THREE SHAPES:

  NILCALL   `A.b(...)` where `b` is declared nowhere under any declaration form
            and `A` is not an engine or stdlib table.  At runtime this is
            `attempt to call a nil value` -- unless `A` is a local holding an
            engine handle, in which case it is an engine method being invoked
            with a dot, so it runs without its `self`.  The tool cannot tell
            those apart (it does no type inference); the ALLOWLIST verdict
            records which one a human read it to be.

  SELFLESS  declared `function T:m(...)`, called `T.m(...)`.  `self` is nil in
            the body.  Harmless exactly when the body never reads `self` --
            which is a fact about the body, so it belongs in a verdict, not in
            the scanner.

  BOUND     declared `function T.m(a, ...)`, called `T:m(...)`.  The receiver
            is passed as `a` and every real argument shifts one place right.
            This is the silent one; note the arity census cannot see it at all
            (its header: colon calls are out of scope, implicit self).

            A declaration whose FIRST PARAMETER IS LITERALLY NAMED `self` is
            NOT a finding: that is the transpiled-TypeScript idiom in
            `ts_libs/` (`function Request.GetUUID(self, callback)` called as
            `Request:GetUUID(cb)`), and it is correct.

LIMITS -- read these before quoting a count:

  * Dotted and colon calls only.  A bare `foo(` local call needs scope
    resolution and is out of scope, same as in the arity census.
  * Resolution is by the LAST component of the name, across the whole tree --
    `J.Skill.GetTalentList` resolves because SOMETHING somewhere declares
    `GetTalentList`.  This is deliberately loose in the SAFE direction: the
    tool's dangerous direction is a false positive (someone "repairs" a call
    that was always fine), so resolution is generous and a finding means the
    name is nowhere in `bots/` at all.  It follows that a name that resolves
    proves nothing -- a real cross-table typo that happens to collide with
    another table's method is invisible here.  ONE-DIRECTIONAL, like the key
    census in GH #162.  Measured example of exactly that miss, so nobody has
    to take it on faith: `bot.GetUnitName(` in advanced_item_strategy.lua is
    the same defect as the `enemy.IsHero(` two lines above it, and only the
    second is a finding -- because aba_global_overrides.lua happens to declare
    `function CDOTA_Bot_Script:GetUnitName()`, and the resolver asks only
    whether the NAME exists somewhere.
  * Roots that `.luacheckrc` already lists as engine globals are skipped: if
    iron rule 6's gate calls the table legitimate, its fields are not this
    tool's business.
  * Comment stripping is inherited from call_arity_census.strip_comments, and
    with it that helper's naive handling of `--` inside an odd-quoted line.
    The self-check asserts the scan's scale, so a stripper regression shows up
    as a collapsed denominator rather than as a quiet zero.

Usage:
    python3 tools/agent/call_form_census.py              # every .lua under bots/
    python3 tools/agent/call_form_census.py --selfcheck
"""

import argparse
import importlib.util
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

_ARITY = os.path.join(REPO, "tools", "agent", "call_arity_census.py")
_spec = importlib.util.spec_from_file_location("call_arity_census", _ARITY)
_A = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_A)

strip_comments = _A.strip_comments
all_lua_files = _A.all_lua_files
CALL_RE = _A.CALL_RE

# `function A.b.c(params)` -- the dotted declaration the arity census reads.
DOT_DECL_RE = re.compile(
    r"^[ \t]*function\s+((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"
    r"\s*\(([^)]*)\)", re.M)
# `function A:b(params)` -- the method declaration.
COLON_DECL_RE = re.compile(
    r"^[ \t]*function\s+((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"
    r":([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
# `A.b = function(`, `local f = function(`, and the transpiled `____exports.x =`
ASSIGN_DECL_RE = re.compile(
    r"^[ \t]*(?:local\s+)?((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"
    r"\s*=\s*function\s*\(", re.M)
# `x = function(` inside a table constructor, and `['x'] = function(`
TABLE_KEY_RE = re.compile(
    r"^[ \t]*\[?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?\]?\s*=\s*function\s*\(", re.M)
# `T['name'] = ...` -- a field assigned something that may be a function
BRACKET_ASSIGN_RE = re.compile(
    r"^[ \t]*((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"
    r"\[['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]\]\s*=", re.M)
# `local function name(` -- not callable through a dot, but the name exists
LOCAL_DECL_RE = re.compile(
    r"^[ \t]*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
COLON_CALL_RE = re.compile(
    r"(?<![\w.:])((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"
    r":([A-Za-z_][A-Za-z0-9_]*)\s*\(")

LUA_STDLIB = {"math", "string", "table", "os", "io", "coroutine", "debug",
              "package", "utf8", "bit", "bit32", "json", "JSON"}

# (file, dotted-or-colon name, shape) -> (count, verdict)
#
# VERDICTS:
#   NOWHERE     the name is declared nowhere; this call raises at runtime and
#               the engine masks the text.  Behaviour-bearing by construction.
#   HANDLE      a dot call on a local holding an engine handle -- the method is
#               reached without its receiver.  Also behaviour-bearing, but the
#               exact engine behaviour is not readable at the desk.
#   DEADFILE    as above, in a file nothing in the tree requires.
#   DYNAMIC     the field is assigned at runtime, so no declaration can exist.
#   SELFUNREAD  colon-declared, dot-called, and the body never reads `self`.
#   VENDORED    third-party code off every decision path.
ALLOWLIST = {
    # ---- NILCALL ----------------------------------------------------------
    # hero_queenofpain:503 and mode_farm_generic:710 are NOT here.  They are
    # the two findings this census was written for; see GH #192 and the
    # repaired call site pinned in tests/test_call_form_census.py section 4.
    ("bots/mode_farm_generic.lua", "J.Site.IsCampDangerous", "NILCALL"):
        (1, "NOWHERE (strategy group, GH #193): `IsCampDangerous` is declared "
            "in no file under bots/ under any declaration form, and J.Site is "
            "`require(FunLib/aba_site)`, a transpiled module of plain "
            "`____exports.name = function` assignments with no metatable -- so "
            "the field is nil and the call raises inside mode_farm_generic's "
            "Think().  Ungated, reached whenever a farming bot's nearest "
            "available camp is >200 units closer than its current pick.  Left "
            "in place deliberately: the repair is a farm-policy decision (write "
            "the predicate, or drop the conjunct and always switch), and this "
            "file belongs to the strategy group."),
    ("bots/FunLib/advanced_item_strategy.lua", "enemy.IsHero", "NILCALL"):
        (1, "DEADFILE: `enemy` is an engine handle and IsHero is an engine "
            "method, so the dot reaches it without its receiver.  Nothing in "
            "bots/ requires advanced_item_strategy.lua (established in GH "
            "#156), so the cost is zero today and the repair belongs to "
            "whoever wakes the file.  Its three `bot.GetUnitName(` and one "
            "`enemy.GetUnitName(` siblings are the SAME defect and are NOT "
            "findings here -- see the resolution limit in the header: "
            "aba_global_overrides.lua declares `function "
            "CDOTA_Bot_Script:GetUnitName()`, so the name resolves and the "
            "generous-by-design resolver lets them through."),
    ("bots/Buff/Timers.lua", "v.callback", "NILCALL"):
        (2, "DYNAMIC: `callback` is a field of a timer table built at "
            "registration time; no static declaration can exist"),
    ("bots/FretBots/Timers.lua", "v.callback", "NILCALL"):
        (2, "DYNAMIC: same timer library, vendored copy"),

    # ---- SELFLESS ---------------------------------------------------------
    # Debug:IsDebug() returns an upvalue and never touches self, so the twelve
    # dot calls behave identically to colon calls.  Read the body before
    # moving any of these: the verdict is about the body, not the call.
    ("bots/FretBots/AwardBonus.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/BonusTimers.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/DataTables.lua", "Debug.IsDebug", "SELFLESS"):
        (3, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/DynamicDifficulty.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/GameState.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/HeroLoneDruid.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/NeutralItems.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/OnEntityHurt.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/OnEntityKilled.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/RoleDetermination.lua", "Debug.IsDebug", "SELFLESS"):
        (1, "SELFUNREAD: body is `return isDebug` (an upvalue)"),
    ("bots/FretBots/Utilities.lua", "Utilities.CanPlaySound", "SELFLESS"):
        (1, "SELFUNREAD: body reads the global Settings table only"),
}


def engine_globals():
    """Roots `.luacheckrc` already blesses.  If iron rule 6's gate calls the
    table legitimate, this tool does not second-guess its fields."""
    path = os.path.join(REPO, ".luacheckrc")
    try:
        src = open(path, encoding="utf-8").read()
    except OSError:
        return set()
    return set(re.findall(r"['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]", src))


def collect(files):
    """Return (names, colon_methods, dot_methods).

    names           every identifier declared anywhere, by last component.
    colon_methods   name -> set of tables declaring it with `function T:name`.
    dot_methods     name -> set of (table, first_param) for `function T.name`.
    """
    names, colon_methods, dot_methods = set(), {}, {}
    for path in files:
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        for m in DOT_DECL_RE.finditer(src):
            parts = m.group(1).split(".")
            names.add(parts[-1])
            if len(parts) >= 2:
                raw = m.group(2).strip()
                first = raw.split(",")[0].strip() if raw else ""
                dot_methods.setdefault(parts[-1], set()).add(
                    (".".join(parts[:-1]), first))
        for m in COLON_DECL_RE.finditer(src):
            names.add(m.group(2))
            colon_methods.setdefault(m.group(2), set()).add(m.group(1))
        for m in ASSIGN_DECL_RE.finditer(src):
            names.add(m.group(1).split(".")[-1])
        for m in TABLE_KEY_RE.finditer(src):
            names.add(m.group(1))
        for m in BRACKET_ASSIGN_RE.finditer(src):
            names.add(m.group(2))
        for m in LOCAL_DECL_RE.finditer(src):
            names.add(m.group(1))
    return names, colon_methods, dot_methods


def census(scan_files, decl_files=None, skip_roots=None):
    decl_files = decl_files or scan_files
    names, colon_methods, dot_methods = collect(decl_files)
    skip = LUA_STDLIB | (engine_globals() if skip_roots is None else skip_roots)
    findings = []
    stats = {"files": 0, "names": len(names), "dotted_calls": 0,
             "colon_calls": 0, "root_skipped": 0}
    for path in scan_files:
        stats["files"] += 1
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        rel = os.path.relpath(path, REPO)
        for m in CALL_RE.finditer(src):
            stats["dotted_calls"] += 1
            parts = m.group(1).split(".")
            table, name = ".".join(parts[:-1]), parts[-1]
            line = src[:m.start()].count("\n") + 1
            if name not in names:
                # The root skip applies HERE ONLY.  A missing declaration under
                # an engine-provided root means the engine declares it, which
                # is not a finding.  It says nothing about the two shapes
                # below, where a declaration WAS found in the tree -- there the
                # root's blessing is irrelevant and skipping on it would hide
                # every FretBots module (`Debug`, `Utilities`) by accident.
                if parts[0] in skip:
                    stats["root_skipped"] += 1
                    continue
                findings.append({"file": rel, "line": line,
                                 "name": m.group(1), "shape": "NILCALL"})
            elif (name in colon_methods and table in colon_methods[name]
                  and not any(t == table for t, _ in dot_methods.get(name, ()))):
                findings.append({"file": rel, "line": line,
                                 "name": m.group(1), "shape": "SELFLESS"})
        for m in COLON_CALL_RE.finditer(src):
            stats["colon_calls"] += 1
            table, name = m.group(1), m.group(2)
            # A dot declaration whose first parameter is literally `self` is a
            # method declaration in disguise (the ts_libs transpiler idiom).
            hits = [(t, first) for t, first in dot_methods.get(name, ())
                    if t == table]
            if not hits or name in colon_methods:
                continue
            if all(first == "self" for _, first in hits):
                continue
            findings.append({"file": rel,
                             "line": src[:m.start()].count("\n") + 1,
                             "name": "%s:%s" % (table, name),
                             "shape": "BOUND"})
    return findings, stats


def group(findings):
    out = {}
    for f in findings:
        key = (f["file"], f["name"], f["shape"])
        out[key] = out.get(key, 0) + 1
    return out


def selfcheck():
    """Synthetic cases.  The dangerous direction for this tool is a FALSE
    POSITIVE -- a call that was always correct gets "repaired" and takes
    behaviour with it -- so most of these pin what is NOT a finding."""
    import tempfile
    cases = [
        ("function A.f() end\nA.f()\n", []),
        ("A.g()\n", [("A.g", "NILCALL")]),
        # any declaration form anywhere makes the name resolve
        ("A.b = function() end\nQ.b()\n", []),
        ("local t = {\n  b = function() end,\n}\nQ.b()\n", []),
        ("T['b'] = 1\nQ.b()\n", []),
        ("local function b() end\nQ.b()\n", []),
        # a sub-table path resolves on its last component
        ("function S.Deep() end\nJ.Site.Deep()\n", []),
        # colon-declared, dot-called
        ("function T:m() end\nT.m()\n", [("T.m", "SELFLESS")]),
        ("function T:m() end\nT:m()\n", []),
        # a name declared BOTH ways on the same table is not a form finding
        ("function T:m() end\nfunction T.m() end\nT.m()\n", []),
        # dot-declared, colon-called: the argument shift
        ("function T.m(a, b) end\nT:m(1)\n", [("T:m", "BOUND")]),
        # ...unless the first parameter is literally `self` (ts_libs idiom)
        ("function T.m(self, b) end\nT:m(1)\n", []),
        # a colon call on a table that declares the name with a colon is right
        ("function T:m(a) end\nT:m(1)\n", []),
        # a commented-out call is not a call
        ("-- A.g()\n", []),
        # a nil call inside a comment block is not a call
        ("--[[\nA.g()\n]]\n", []),
    ]
    failures = 0
    for i, (src, want) in enumerate(cases, 1):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "case.lua")
            open(p, "w").write(src)
            found, _ = census([p], [p], skip_roots=set())
            got = sorted((f["name"], f["shape"]) for f in found)
            if got != sorted(want):
                failures += 1
                print("  FAIL case %d: want %r got %r" % (i, sorted(want), got))
            else:
                print("  ok   case %d" % i)
    print("%d/%d selfcheck cases pass" % (len(cases) - failures, len(cases)))
    return 0 if failures == 0 else 1


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args(argv)
    if args.selfcheck:
        return selfcheck()

    files = all_lua_files()
    findings, stats = census(files, files)
    print("scanned %d file(s); %d declared name(s); %d dotted call(s) "
          "(%d skipped by root), %d colon call(s)"
          % (stats["files"], stats["names"], stats["dotted_calls"],
             stats["root_skipped"], stats["colon_calls"]))
    for shape in ("NILCALL", "SELFLESS", "BOUND"):
        rows = [f for f in findings if f["shape"] == shape]
        print("\n== %s (%d)" % (shape, len(rows)))
        for f in sorted(rows, key=lambda r: (r["file"], r["line"])):
            key = (f["file"], f["name"], f["shape"])
            verdict = ALLOWLIST.get(key, (0, "*** NOT IN ALLOWLIST ***"))[1]
            print("  %s:%d  %s\n      %s" % (f["file"], f["line"], f["name"],
                                             verdict))
    return 0


if __name__ == "__main__":
    sys.exit(main())

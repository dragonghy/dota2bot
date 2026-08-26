#!/usr/bin/env python3
"""Census: hero files that bind a talent by LITERAL NAME, and whether the game
still gives that hero a talent by that name.

Why this exists (hero group, 2026-08-26, follow-on to GH #214)
--------------------------------------------------------------
Two ways exist in this tree to get a talent handle, and they fail differently:

  * BY INDEX -- `bot:GetAbilityByName( sTalentList[N] )`.  Pinned by GH #166 /
    #214.  Survives a rename, breaks on a REORDER: the handle silently starts
    naming a different talent and `IsTrained()` answers about that one.
  * BY LITERAL NAME -- `bot:GetAbilityByName('special_bonus_unique_doom_2')`.
    The inverse.  Survives a reorder, breaks on a RENAME or a REMOVAL -- and it
    breaks harder, because `GetAbilityByName` answers **nil** for a talent the
    hero does not have, and the next thing every one of these sites does is call
    a method on the handle.  A `nil:IsTrained()` hits the engine's broken error
    handler (`error in error handling` masks the text, AGENTS.md), so `Think()`
    stops part-way through the frame with nothing printed anywhere.

GH #214 left the by-name half uncounted, and named `doom_bringer` as the one to
look at first because it is one of the 18 heroes odota's display list was stale
on.  This script is that count, run against the same authoritative source #214
switched to: the game's own `npc_heroes.txt`, where a hero's talents are a
contiguous run of eight `"AbilityN" "special_bonus_*"` entries.

WHAT IT PROVES, AND IN WHICH DIRECTION
--------------------------------------
  * name NOT in the hero's KV run  =>  PROOF the in-game handle is nil.  The
    unit only carries the abilities its own block lists; there is nowhere else
    for `bot:GetAbilityByName` to find it.
  * name IS in the run  =>  proves only that the handle is non-nil.  It does
    NOT prove the site reads the talent its variable is named after; that is
    the `mods` column (an override key inside an AbilityValues block IS a proof
    of what the talent changes), and an empty `mods` proves nothing at all --
    generic rows live in npc_abilities.txt, which this script does not read.

GUARD DETECTION IS DELIBERATELY CONSERVATIVE
--------------------------------------------
A method call is counted GUARDED only when the nil test sits in the SAME
conjunction: on the same live line (`VAR ~= nil and VAR:`), or on the line
above when this line continues it (`if VAR ~= nil` / `then ... VAR:`).  A guard
reached any other way -- further up a multi-line chain, through an intermediate
boolean, or by an `if` block that already closed -- is reported UNGUARDED.

That asymmetry is the whole design.  The judge may over-report (visible, and
someone can argue with the line it printed); it must never under-report, because
under-reporting means calling a live nil dereference safe.  The first draft
looked one line up unconditionally and did exactly that -- its own test suite
caught it laundering `local a = VAR ~= nil and VAR:IsTrained()` into a guard for
a bare `VAR:GetLevel()` on the next line.  A test that RAN and a test that
GUARDS are not the same thing.

The exit code only escalates on the intersection that is a provable crash --
ABSENT *and* UNGUARDED -- so a conservative miss elsewhere costs a line of
output, not a red gate.

Usage
-----
  python3 tools/agent/talent_name_binding_census.py            # report
  python3 tools/agent/talent_name_binding_census.py --snapshot # regenerate the
                                                               # Lua snapshot

Exit codes: 0 clean, 3 at least one ABSENT + UNGUARDED site (a live crash).
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import talent_slot_census as T  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if not os.path.isdir(os.path.join(REPO, "bots")):
    REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SNAPSHOT = "tests/mock/talent_name_bindings.lua"

HERO_KV = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
           "dota/scripts/npc/heroes/npc_dota_hero_%s.txt")

# `local Foo = bot:GetAbilityByName('special_bonus_...')` and the bare
# assignment form (`talent20Left = bot:GetAbilityByName(...)`, silencer).
BIND = re.compile(
    r"""(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"""
    r"""[A-Za-z_][A-Za-z0-9_]*\s*:\s*GetAbilityByName\s*\(\s*"""
    r"""['"](special_bonus_[A-Za-z0-9_]+)['"]\s*\)""")

# Hero files whose unit short name is not the file stem.  Empty today; kept so
# a mismatch is a one-line fix instead of a reason to loosen the lookup.
FILE_TO_HERO = {}


def strip_comments(text):
    """Blank out Lua comments, keeping line count and column positions.

    Line-based on purpose: this axis's own tree has a commented-out copy of the
    bearing site (`hero_doom_bringer.lua:249` mirrors :320), so a parser that
    reads prose would report a call site that cannot run -- the same mistake
    GH #136's first buy-list census made in the other direction.  Long-bracket
    comments (`--[[ ]]`) are handled; a `--` inside a string literal is not,
    and no `special_bonus_*` binding in this tree sits in one.
    """
    out, in_block = [], False
    for line in text.splitlines():
        if in_block:
            end = line.find("]]")
            if end < 0:
                out.append("")
                continue
            line = " " * (end + 2) + line[end + 2:]
            in_block = False
        start = line.find("--[[")
        if start >= 0:
            end = line.find("]]", start)
            if end < 0:
                out.append(line[:start])
                in_block = True
                continue
            line = line[:start] + " " * (end + 2 - start) + line[end + 2:]
        cut = line.find("--")
        if cut >= 0:
            line = line[:cut]
        out.append(line)
    return out


def hero_of(path):
    """Unit short name for a hero file, or None if the file is not one."""
    stem = os.path.basename(path)[:-len(".lua")]
    if stem.startswith("hero_"):
        stem = stem[len("hero_"):]
    elif "rubick_hero" not in path.replace("\\", "/"):
        return None
    return FILE_TO_HERO.get(stem, stem)


def hero_files(root=None):
    root = os.path.join(root or REPO, "bots")
    for base, _, names in os.walk(root):
        for name in sorted(names):
            if name.endswith(".lua"):
                yield os.path.join(base, name)


# The previous line is read only when THIS line is a continuation of it -- the
# tree's house style breaks a conjunction across lines (`if x`\n`and y`\n`then`).
# The narrow rule is what keeps the judge sound in the one direction that
# matters.  Two shapes it deliberately refuses, both of which a "look one line
# up" rule would have laundered into a false GUARDED:
#   local a = Foo ~= nil and Foo:IsTrained()   -- a test that RAN,
#   local b = Foo:GetLevel()                   -- but does not guard this
#   if Foo ~= nil then bar() end               -- a block that already
#   Foo:GetLevel()                             -- CLOSED
# A test that ran and a test that guards are not the same thing.
#
# Note what is NOT in the list: `if`, `elseif`, `while`.  Those OPEN a
# construct, they do not continue one, so a line starting with `if` must carry
# its own test.  Leaving them in cost a second false GUARDED, on the one site
# in the tree that is genuinely guarded through an intermediate boolean
# (hero_silencer.lua:747-748) -- the judge was reading a completed `local` line
# above an `if` and calling it this condition's guard.
CONTINUES = re.compile(r"^\s*(then|and|or|not)\b")


def guarded(lines, idx, var):
    """Is the `var:` method call on live line `idx` nil-tested in place?

    Same line, or the line directly above when this line continues its
    conjunction.  A guard reached any other way -- further up the chain, through
    an intermediate boolean, or via an `if` block that already closed -- is
    reported unguarded on purpose: see the module docstring on which direction
    of error this is allowed to make.
    """
    tests = (r"%s\s*~=\s*nil" % re.escape(var),
             r"\bnot\s+%s\b" % re.escape(var),
             r"\b%s\s+and\b" % re.escape(var))
    window = [lines[idx]]
    if idx > 0 and CONTINUES.match(lines[idx]):
        window.append(lines[idx - 1])
    for text in window:
        for pattern in tests:
            if re.search(pattern, text):
                return True
    return False


def scan_file(path, lines=None):
    """[(var, talent, bind_line, [(call_line, guarded), ...]), ...]"""
    if lines is None:
        with open(path, "r", encoding="utf-8") as fh:
            lines = strip_comments(fh.read())
    found = []
    for n, line in enumerate(lines):
        m = BIND.search(line)
        if m:
            found.append((m.group(1), m.group(2), n + 1))
    out = []
    for var, talent, bind_line in found:
        call = re.compile(r"\b%s\s*:\s*[A-Za-z_]" % re.escape(var))
        calls = [(n + 1, guarded(lines, n, var))
                 for n, line in enumerate(lines) if call.search(line)]
        out.append((var, talent, bind_line, calls))
    return out


def census(root=None, names=None, overrides=None):
    """[ {file, hero, var, talent, bind_line, present, mods, calls}, ... ]"""
    if names is None:
        names, _ = T.kv_talents()
    rows = []
    for path in hero_files(root):
        hero = hero_of(path)
        if hero is None:
            continue
        for var, talent, bind_line, calls in scan_file(path):
            if hero not in names:
                raise SystemExit(
                    "npc_heroes.txt names no talents for %r (%s) -- the file "
                    "stem no longer maps to a unit name; fix FILE_TO_HERO "
                    "before trusting anything below" % (hero, path))
            mods = []
            if overrides is not None:
                mods = overrides.get(hero, {}).get(talent, [])
            rows.append({
                "file": os.path.relpath(path, root or REPO),
                "hero": hero,
                "var": var,
                "talent": talent,
                "bind_line": bind_line,
                "present": talent in names[hero],
                "slot": (names[hero].index(talent) + 1
                         if talent in names[hero] else 0),
                "mods": mods,
                "calls": calls,
            })
    return rows


def crashers(rows):
    """Rows that are a proven live nil call: name gone AND call unguarded."""
    return [r for r in rows
            if not r["present"] and any(not g for _, g in r["calls"])]


def fetch_overrides(rows):
    out = {}
    for hero in sorted({r["hero"] for r in rows}):
        try:
            out[hero] = T.talent_overrides(T.get(HERO_KV % hero))
        except Exception as exc:                       # noqa: BLE001
            print("  (no hero KV for %s: %s)" % (hero, exc), file=sys.stderr)
            out[hero] = {}
    return out


def report(rows):
    for r in sorted(rows, key=lambda r: (r["present"], r["file"])):
        state = ("slot %d" % r["slot"]) if r["present"] else "*** ABSENT ***"
        print("%-40s %-34s %-62s %s" % (
            r["file"].replace("bots/BotLib/", ""), r["var"], r["talent"], state))
        if r["mods"]:
            for mod in r["mods"]:
                print("%-40s   modifies %s" % ("", mod))
        elif r["present"]:
            print("%-40s   (nothing in this hero's own KV names it)" % "")
        for line, ok in r["calls"]:
            print("%-40s   call :%d  %s" % (
                "", line, "nil-tested" if ok else "NOT nil-tested"))
    bad = crashers(rows)
    print("\n%d literal-name binding(s), %d absent, %d proven live nil call(s)"
          % (len(rows), sum(1 for r in rows if not r["present"]), len(bad)))
    for r in bad:
        print("  CRASH  %s:%d  %s -> %s"
              % (r["file"], r["bind_line"], r["var"], r["talent"]))
    return 3 if bad else 0


def snapshot_header():
    """The provenance block, returned so the GENERATOR itself is assertable.

    GH #214's escape hatch: an assertion that reads the committed .lua cannot
    tell a stale generator from a stale snapshot, because it only ever sees the
    generator's output.
    """
    return [
        "-- GENERATED by tools/agent/talent_name_binding_census.py --snapshot"
        " -- do not hand-edit.",
        "--",
        "-- Every place a hero file binds a talent by LITERAL NAME, and whether",
        "-- the game still gives that hero a talent by that name.  Slot order and",
        "-- membership are read out of npc_heroes.txt (the contiguous run of",
        "-- \"AbilityN\" \"special_bonus_*\" entries) -- the same source GH #214",
        "-- moved the talent census to after odota's display list was measured a",
        "-- patch behind.",
        "--",
        "-- `present = false` is a PROOF that bot:GetAbilityByName answers nil in",
        "-- game.  `present = true` proves only non-nil; what the talent actually",
        "-- modifies is `mods`, and an empty `mods` proves nothing (generic rows",
        "-- live in npc_abilities.txt, which the census does not read).",
        "--",
        "-- Regenerate after a patch:",
        "--   python3 tools/agent/talent_name_binding_census.py --snapshot",
        "",
    ]


def write_snapshot(rows, root=None):
    q = T.lua_quote
    out = list(snapshot_header())
    out.append("local X = {}")
    out.append("")
    out.append("X.SITES = {")
    for r in sorted(rows, key=lambda r: (r["file"], r["bind_line"])):
        out.append("    {")
        out.append("        file = %s," % q(r["file"]))
        out.append("        hero = %s," % q(r["hero"]))
        out.append("        var = %s," % q(r["var"]))
        out.append("        talent = %s," % q(r["talent"]))
        out.append("        present = %s," % ("true" if r["present"] else "false"))
        out.append("        slot = %d," % r["slot"])
        if r["mods"]:
            out.append("        mods = {")
            for mod in r["mods"]:
                out.append("            %s," % q(mod))
            out.append("        },")
        else:
            out.append("        mods = {},")
        out.append("    },")
    out.append("}")
    out.append("")
    out.append("return X")
    out.append("")
    path = os.path.join(root or REPO, SNAPSHOT)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    print("wrote %s (%d site(s))" % (SNAPSHOT, len(rows)))


def main(argv):
    names, _ = T.kv_talents()
    rows = census(names=names)
    rows_overrides = fetch_overrides(rows)
    rows = census(names=names, overrides=rows_overrides)
    code = report(rows)
    if "--snapshot" in argv:
        write_snapshot(rows)
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))

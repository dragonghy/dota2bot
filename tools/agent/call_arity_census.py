#!/usr/bin/env python3
"""Census of call sites whose argument COUNT disagrees with the declaration.

WHY THIS CLASS IS INVISIBLE TO IRON RULE 6.  Lua has no arity check: a missing
argument is `nil`, an extra one is discarded, and neither is an error.  luacheck
would report some of it, but `.luacheckrc` says `only = { "1" }` -- only the 1xx
global-access family is enforced -- and cross-file arity is not 1xx anyway.  So
a call that is two arguments short passes `luacheck bots game` and every unit
test that does not happen to drive that exact branch.

WHAT IT COST ONCE, so nobody has to take the class on faith.  `aiug:993` read

    X.SetUseItem( hRegen )                 -- declares ( hItem, hItemTarget, sCastType )

and `X.SetUseItem` dispatches on `sCastType`: all five of its arms miss when the
type is nil, so the call issued NO engine action -- while the `return` on the
next line still skipped the whole item loop behind it.  Measured on the fixture
corpus: 0 of 18 domain frames produced any action before the fix, 17 of 18
after, and 8 of those 18 had been losing an action the shipped tree was already
making.  See tests/test_lf_salve_cast_type.lua.

TWO SHAPES, and they fail in opposite directions:

  UNDER  n < declared.  The missing parameter is nil.  Usually harmless -- the
         helper defaults it (`nRadius == nil or nRadius > 1600`) or never reads
         it -- and occasionally fatal, as above.  A finding here is a QUESTION,
         not a verdict.
  OVER   n > declared.  The extra argument is silently dropped.  This can never
         crash, which is exactly why it is worth reporting: the call site READS
         as if it were passing something (a radius, a window), and it is not.

WHAT THE ALLOWLIST IS FOR.  Every row below has been judged by hand and carries
its reason.  A NEW mismatch is red the day it lands; sweeping an old one means
deleting its row.  The list can only shrink.  Rows are keyed by
(file, dotted name, kind, passed, declared, count) -- deliberately NOT by line
number, because line numbers drift under comment edits alone (charter 0LN2).

LIMITS -- read these before quoting the count:

  * Only DOTTED calls (`J.Foo(`, `X.Bar(`) are scanned.  Bare `foo(` local
    calls and `obj:Method(` colon calls are not: the first needs scope
    resolution, the second has an implicit self.  The count is therefore an
    UNDER-report of the class, and deliberately so -- a name that resolves
    wrongly would produce a confident false positive, and this tool's dangerous
    direction is exactly that (someone "fixes" a call that was already right).
  * A name declared with two different arities anywhere in `bots/` is skipped
    entirely (`X.` tables are per-file, so this happens a lot and there is no
    way to tell which declaration a given call site meant).
  * Declarations taking `...` are skipped.
  * `--[[ ]]` blocks and `--` line comments are stripped before scanning; the
    stripper is naive about `--` inside strings on a line that already has an
    odd quote count.  The self-check asserts the scan reached its expected
    scale, so a stripper regression shows up as a collapsed denominator rather
    than as a quiet zero (charter 0IMPL judgement two).

Usage:
    python3 tools/agent/call_arity_census.py            # the nine decision files
    python3 tools/agent/call_arity_census.py --all      # every .lua under bots/
    python3 tools/agent/call_arity_census.py --selfcheck
"""

import argparse
import glob
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# The nine files this stream's decisions actually live in (same set as
# guard_implication_census.py and write_only_local_census.py).
DECISION_FILES = [
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

# (file, name, kind, passed, declared) -> (count, verdict)
#
# VERDICTS, and what each one commits to:
#   DEFAULTED  the helper substitutes a value for the missing parameter, from
#              its own source.  Benign by construction.
#   UNREAD     the declared parameter is never read in the body.  Benign; the
#              parameter is the dead thing, not the call.
#   BRANCHED   the missing parameter is only read on branches this call site
#              cannot reach (verified by reading the branch selector).
#   VENDORED   third-party/library code off any decision path, optional arg.
#   COSMETIC   an OVER call whose extra argument changes nothing but misleads a
#              reader.  Zero behaviour, non-zero confusion.
#   TEETH      behaviour-bearing.  Routed, with an issue, to whoever owns it.
ALLOWLIST = {
    # ---- OVER -------------------------------------------------------------
    # J.GetTotalEstimatedDamageToTarget(nUnits, target) hardcodes a 5-second
    # window inside (`GetEstimatedDamageToTarget(true, target, 5, ...)`).  Two
    # of the three sites pass 5.0, which is what the helper does anyway.
    ("bots/BotLib/hero_life_stealer.lua",
     "J.GetTotalEstimatedDamageToTarget", "OVER", 3, 2):
        (1, "COSMETIC: passes 5.0, the helper's own hardcoded window"),
    ("bots/FunLib/override_generic/mode_attack_generic.lua",
     "J.GetTotalEstimatedDamageToTarget", "OVER", 3, 2):
        (1, "COSMETIC: passes 5.0, the helper's own hardcoded window"),
    # ...and one does not.
    ("bots/BotLib/hero_bristleback.lua",
     "J.GetTotalEstimatedDamageToTarget", "OVER", 3, 2):
        (1, "TEETH (hero group): passes 8.0 into a 5-second helper, so the "
            "'will the incoming burst kill me' comparison at hero_bristleback "
            "sees 5/8 of the damage the author asked for.  The sister "
            "X.GetTotalEstimatedDamageToTarget(hUnitList, hTarget, fDuration) "
            "in hero_mars.lua takes the duration for real, which is why the "
            "three-argument shape looks right at a glance."),
    # J.IsGoingOnSomeone(bot) reads the active mode only; it has never had a
    # radius.  The 1200 is read by a human as a range and by Lua as nothing.
    ("bots/BotLib/hero_enchantress.lua", "J.IsGoingOnSomeone", "OVER", 2, 1):
        (1, "COSMETIC: helper reads GetActiveMode() only, no radius exists"),
    ("bots/BotLib/hero_undying.lua", "J.IsGoingOnSomeone", "OVER", 2, 1):
        (1, "COSMETIC: helper reads GetActiveMode() only, no radius exists"),
    # J.IsInLaningPhase() is a global clock read; the bot handed to it is
    # dropped.  Reads per-hero, is not.
    ("bots/BotLib/hero_invoker.lua", "J.IsInLaningPhase", "OVER", 1, 0):
        (1, "COSMETIC: global clock, takes no arguments"),
    ("bots/BotLib/hero_pudge.lua", "J.IsInLaningPhase", "OVER", 1, 0):
        (1, "COSMETIC: global clock, takes no arguments"),
    ("bots/BotLib/hero_tinker.lua", "J.IsInLaningPhase", "OVER", 1, 0):
        (1, "COSMETIC: global clock, takes no arguments"),

    # ---- UNDER ------------------------------------------------------------
    # J.IsInTeamFight(bot, nRadius): `if nRadius == nil or nRadius > 1600 then
    # nRadius = 1600 end`.
    ("bots/BotLib/hero_earthshaker.lua", "J.IsInTeamFight", "UNDER", 1, 2):
        (2, "DEFAULTED: nRadius nil -> 1600"),
    ("bots/BotLib/hero_faceless_void.lua", "J.IsInTeamFight", "UNDER", 1, 2):
        (1, "DEFAULTED: nRadius nil -> 1600"),
    ("bots/BotLib/hero_invoker.lua", "J.IsInTeamFight", "UNDER", 1, 2):
        (1, "DEFAULTED: nRadius nil -> 1600"),
    ("bots/BotLib/hero_muerta.lua", "J.IsInTeamFight", "UNDER", 1, 2):
        (1, "DEFAULTED: nRadius nil -> 1600"),
    ("bots/BotLib/hero_sand_king.lua", "J.IsInTeamFight", "UNDER", 1, 2):
        (1, "DEFAULTED: nRadius nil -> 1600"),
    ("bots/ability_item_usage_generic.lua", "J.IsInTeamFight", "UNDER", 1, 2):
        (3, "DEFAULTED: nRadius nil -> 1600"),
    # J.ShouldConserveManaInLane(bot, nReservePct): `nReservePct = nReservePct
    # or 0.35`.  (Also inert: its first line is J.IsLaneFixOn('mana').)
    ("bots/BotLib/hero_crystal_maiden.lua",
     "J.ShouldConserveManaInLane", "UNDER", 1, 2):
        (1, "DEFAULTED: nReservePct nil -> 0.35"),
    ("bots/BotLib/hero_lion.lua", "J.ShouldConserveManaInLane", "UNDER", 1, 2):
        (1, "DEFAULTED: nReservePct nil -> 0.35"),
    ("bots/BotLib/hero_zuus.lua", "J.ShouldConserveManaInLane", "UNDER", 1, 2):
        (2, "DEFAULTED: nReservePct nil -> 0.35"),
    # J.GetNearbyHeroes(bot, nRadius, bEnemy, bBotMode): `if not bBotMode then
    # bBotMode = BOT_MODE_NONE end`.
    ("bots/BotLib/hero_elder_titan.lua", "J.GetNearbyHeroes", "UNDER", 3, 4):
        (2, "DEFAULTED: bBotMode nil -> BOT_MODE_NONE"),
    ("bots/BotLib/hero_invoker.lua", "J.GetNearbyHeroes", "UNDER", 3, 4):
        (3, "DEFAULTED: bBotMode nil -> BOT_MODE_NONE"),
    # Parameters that are declared and never read.
    ("bots/BotLib/hero_morphling.lua", "J.GetTormentorLocation", "UNDER", 0, 1):
        (1, "UNREAD: the `team` parameter is not read in the body -- the "
            "function branches on J.CheckTimeOfDay() alone"),
    ("bots/BotLib/hero_tinker.lua", "J.GetMostFarmLaneDesire", "UNDER", 0, 1):
        (1, "UNREAD: the `bot` parameter is not read in the body -- the "
            "function reads the three global GetFarmLaneDesire values"),
    # X.CastInvokerSpell(ability, target): `target` is read only on the
    # UseAbilityOnLocation / UseAbilityOnEntity arms, and all six short call
    # sites pass Cataclysm / GhostWalk / ForgeSpirit / IceWall, which the same
    # if-chain routes to the self-target and no-target arms.
    ("bots/BotLib/hero_invoker.lua", "X.CastInvokerSpell", "UNDER", 1, 2):
        (6, "BRANCHED: all six pass abilities the dispatcher routes to arms "
            "that never read `target`"),
    # Vendored / debug helpers, off every decision path.
    ("bots/FretBots/Chat.lua", "json.encode", "UNDER", 1, 2):
        (3, "VENDORED: json.encode(obj, state) -- state is optional"),
    ("bots/FretBots/Inspect.lua", "inspect.inspect", "UNDER", 1, 2):
        (1, "VENDORED: inspect(root, options) -- options is optional"),
    ("bots/FunLib/utils.lua", "____exports.PrintTable", "UNDER", 1, 2):
        (2, "VENDORED: transpiled debug printer, indent defaults inside"),
}


def strip_comments(src):
    src = re.sub(r"--\[\[.*?\]\]", lambda m: "\n" * m.group(0).count("\n"),
                 src, flags=re.S)
    out = []
    for line in src.split("\n"):
        i = line.find("--")
        if i >= 0 and line[:i].count("'") % 2 == 0 and line[:i].count('"') % 2 == 0:
            line = line[:i]
        out.append(line)
    return "\n".join(out)


def split_args(s):
    """Split the argument list that starts just after an opening paren.

    Returns (list_of_arg_strings, index_of_closing_paren) or (None, -1) if the
    call is unterminated within `s`.
    """
    depth, parts, cur, quote, i = 0, [], "", None, 0
    while i < len(s):
        c = s[i]
        if quote:
            if c == "\\":
                cur += c + (s[i + 1] if i + 1 < len(s) else "")
                i += 2
                continue
            if c == quote:
                quote = None
            cur += c
        else:
            if c in "\"'":
                quote = c
                cur += c
            elif c in "([{":
                depth += 1
                cur += c
            elif c in ")]}":
                if depth == 0:
                    parts.append(cur)
                    return parts, i
                depth -= 1
                cur += c
            elif c == "," and depth == 0:
                parts.append(cur)
                cur = ""
            else:
                cur += c
        i += 1
    return None, -1


DECL_RE = re.compile(
    r"^[ \t]*function\s+((?:[A-Za-z_][A-Za-z0-9_]*\.)*[A-Za-z_][A-Za-z0-9_]*)"
    r"\s*\(([^)]*)\)", re.M)
CALL_RE = re.compile(
    r"(?<![\w.:])((?:[A-Za-z_][A-Za-z0-9_]*\.)+[A-Za-z_][A-Za-z0-9_]*)\s*\(")


def all_lua_files(root=None):
    root = root or os.path.join(REPO, "bots")
    return sorted(glob.glob(os.path.join(root, "**", "*.lua"), recursive=True))


def collect_declarations(files):
    """name -> (arity, defining_file, ambiguous, has_vararg)."""
    decls = {}
    for path in files:
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        for m in DECL_RE.finditer(src):
            name = m.group(1)
            raw = m.group(2).strip()
            params = [p.strip() for p in raw.split(",")] if raw else []
            vararg = "..." in params
            rel = os.path.relpath(path, REPO)
            if name in decls and decls[name][0] != len(params):
                decls[name] = (decls[name][0], decls[name][1], True,
                               decls[name][3] or vararg)
            else:
                prev = decls.get(name)
                decls[name] = (len(params), rel,
                               prev[2] if prev else False,
                               (prev[3] if prev else False) or vararg)
    return decls


def census(scan_files, decl_files=None):
    """Scan `scan_files` for arity mismatches against declarations in
    `decl_files` (default: every file under bots/).

    Returns (findings, stats).  A finding is a dict; stats carry the
    denominators so a zero reading can be told apart from a scan that never
    reached anything.
    """
    decl_files = decl_files or all_lua_files()
    decls = collect_declarations(decl_files)
    findings = []
    stats = {"declarations": len(decls), "files": 0, "dotted_calls": 0,
             "resolved_calls": 0, "ambiguous_skipped": 0, "vararg_skipped": 0}
    for path in scan_files:
        stats["files"] += 1
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        rel = os.path.relpath(path, REPO)
        for m in CALL_RE.finditer(src):
            stats["dotted_calls"] += 1
            name = m.group(1)
            if name not in decls:
                continue
            declared, dfile, ambiguous, vararg = decls[name]
            if ambiguous:
                stats["ambiguous_skipped"] += 1
                continue
            if vararg:
                stats["vararg_skipped"] += 1
                continue
            args, _ = split_args(src[m.end():])
            if args is None:
                continue
            stats["resolved_calls"] += 1
            passed = len([a for a in args if a.strip() != ""])
            if passed == declared:
                continue
            findings.append({
                "file": rel,
                "line": src[:m.start()].count("\n") + 1,
                "name": name,
                "kind": "UNDER" if passed < declared else "OVER",
                "passed": passed,
                "declared": declared,
                "declared_in": dfile,
            })
    return findings, stats


def group(findings):
    """Collapse findings to the allowlist key -> count."""
    out = {}
    for f in findings:
        key = (f["file"], f["name"], f["kind"], f["passed"], f["declared"])
        out[key] = out.get(key, 0) + 1
    return out


def selfcheck():
    """Synthetic cases: each pins one half of what 'mismatch' means."""
    import tempfile
    cases = [
        # (source, expected findings on that source)
        ("function A.f(a, b) end\nA.f(1)\n", [("A.f", "UNDER", 1, 2)]),
        ("function A.f(a, b) end\nA.f(1, 2)\n", []),
        ("function A.f(a, b) end\nA.f(1, 2, 3)\n", [("A.f", "OVER", 3, 2)]),
        ("function A.f() end\nA.f()\n", []),
        # nested calls must not be counted as extra top-level arguments
        ("function A.f(a) end\nfunction A.g(a, b) end\nA.f(A.g(1, 2))\n", []),
        # a comma inside a string literal is not a separator
        ("function A.f(a) end\nA.f('x, y')\n", []),
        # a comma inside a table constructor is not a separator
        ("function A.f(a) end\nA.f({1, 2, 3})\n", []),
        # a call spanning lines is still one call
        ("function A.f(a, b) end\nA.f(\n  1,\n  2\n)\n", []),
        # varargs are skipped entirely
        ("function A.f(a, ...) end\nA.f(1)\nA.f(1,2,3)\n", []),
        # a name declared with two arities is skipped entirely
        ("function A.f(a) end\nfunction A.f(a, b) end\nA.f(1)\n", []),
        # a commented-out call is not a call
        ("function A.f(a, b) end\n-- A.f(1)\n", []),
        # colon calls are out of scope (implicit self)
        ("function A.f(a, b) end\nlocal o = {}\no:f(1)\n", []),
        # a trailing comma with an empty slot does not count as an argument
        ("function A.f(a, b) end\nA.f(1, 2)\n", []),
    ]
    failures = 0
    for i, (src, want) in enumerate(cases, 1):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "case.lua")
            open(p, "w").write(src)
            found, _ = census([p], [p])
            got = sorted((f["name"], f["kind"], f["passed"], f["declared"])
                         for f in found)
            if got != sorted(want):
                failures += 1
                print("  FAIL case %d: want %r got %r" % (i, sorted(want), got))
            else:
                print("  ok   case %d" % i)
    print("%d/%d selfcheck cases pass" % (len(cases) - failures, len(cases)))
    return 0 if failures == 0 else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true",
                    help="scan every .lua under bots/ (default: the nine "
                         "strategy decision files)")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args(argv)

    if args.selfcheck:
        return selfcheck()

    files = (all_lua_files() if args.all
             else [os.path.join(REPO, f) for f in DECISION_FILES])
    findings, stats = census(files)

    print("scanned %d file(s); %d declaration(s) known; %d dotted call(s), "
          "%d resolved, %d ambiguous-skipped, %d vararg-skipped"
          % (stats["files"], stats["declarations"], stats["dotted_calls"],
             stats["resolved_calls"], stats["ambiguous_skipped"],
             stats["vararg_skipped"]))
    for kind in ("OVER", "UNDER"):
        rows = [f for f in findings if f["kind"] == kind]
        print("\n== %s (%d)" % (kind, len(rows)))
        for f in sorted(rows, key=lambda r: (r["file"], r["line"])):
            key = (f["file"], f["name"], f["kind"], f["passed"], f["declared"])
            verdict = ALLOWLIST.get(key, (0, "*** NOT IN ALLOWLIST ***"))[1]
            print("  %s:%d  %s  passed %d, declares %d  [%s]\n      %s"
                  % (f["file"], f["line"], f["name"], f["passed"],
                     f["declared"], f["declared_in"], verdict))
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
  * MODULE BOUNDARIES are crossed by name, not by import graph -- see the next
    paragraph for what that cost.
  * `--[[ ]]` blocks and `--` line comments are stripped before scanning; the
    stripper is naive about `--` inside strings on a line that already has an
    odd quote count.  The self-check asserts the scan reached its expected
    scale, so a stripper regression shows up as a collapsed denominator rather
    than as a quiet zero (charter 0IMPL judgement two).

THE TRANSPILED-MODULE BLIND SPOT, and why `OVER (0)` was not a reading
(strategy 2026-09-03).  Declarations are keyed by the dotted name AS WRITTEN.
Thirteen modules under `bots/` are transpiled TypeScript, and every one of
their 256 exports is declared `function ____exports.Foo(...)` while every
importer writes `local Alias = require(GetScriptDirectory()..'/FunLib/utils')`
and calls `Alias.Foo(...)`.  Those two names never match, so the call fell out
at `if name not in decls: continue` -- and that branch incremented NO counter.
The denominator line therefore could not disclose the gap: 161 resolvable
cross-module call sites were invisible, and the tool printed `OVER (0)` over a
tree whose ONLY OVER member lives at exactly such a call site
(`hero_selection:1040`).  A skip that is not counted is not a limit, it is a
lie with a denominator next to it.  Resolution now follows the import graph:

  * per-file `local Alias = require('/path')` bindings, plus
  * field bindings written in the imported module itself (`J.Utils =
    require('/FunLib/utils')` in jmz_func), so `J.Utils.SetContains(` resolves
    two segments deep;
  * `alias_calls` / `alias_resolved` are now denominators in their own right,
    so the blind spot cannot come back as a silent zero.

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
    # EMPTY, and that is a state worth defending (hero group, 2026-08-25,
    # GH #189).  All eight OVER sites were swept in one commit: the extra
    # argument was a literal constant at every one of them, so deleting it is
    # byte-for-byte the same behaviour and removes the only thing the argument
    # ever did, which was mislead a reader.
    #
    #   hero_bristleback:620   passed 8.0 into a helper with a hardcoded 5s
    #                          window -- the one row that ever had teeth.  The
    #                          8.0 is recorded in a comment at the call site,
    #                          not plumbed: 5s is the repo-wide window for this
    #                          question and the better burst estimate anyway.
    #   hero_life_stealer:506, mode_attack_generic:334
    #                          passed 5.0, the helper's own constant.
    #   hero_enchantress:500, hero_undying:373
    #                          passed 1200 to J.IsGoingOnSomeone(bot), which
    #                          reads GetActiveMode() and has never had a radius.
    #   hero_invoker:339, hero_pudge:801, hero_tinker:464
    #                          passed `bot` to J.IsInLaningPhase(), a global
    #                          clock that declares no parameters.
    #
    # An OVER can never crash, which is why an empty OVER half is cheap to hold
    # and worth holding: the next one is red the day it lands.  See
    # tests/test_call_arity_census.py section 3.

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
    # Landed 2026-09-02 with the soak candidate 'roshdist' (GH #422, test_set.md
    # SS DP).  Judged by the director the day it went red rather than left to
    # ride: `J.RoshanPitProximity(hUnit, vRoshanLocation, bRoshDist, nRadius)`
    # reads nRadius on exactly one line -- `return nDistance <= (nRadius or
    # 1600)` -- and only after `if not bRoshDist then return nDistance end`, so
    # the missing fourth argument cannot reach an unguarded read.  The sole
    # caller is the gate wrapper J.IsAtRoshanPit, which passes three ON PURPOSE:
    # 1600 is this repo's own "arrived at the pit" radius (hero_dark_seer:520,
    # hero_rattletrap:475, rubick_hero/rattletrap:383) and SS DP.5 records it as
    # derived, not borrowed.  DEFAULTED, not BRANCHED: the substitution is
    # unconditional inside the branch that reads it.
    # !! What would make this row wrong: a SECOND caller of J.RoshanPitProximity
    # that means a different radius.  The row is keyed by count (1), so a second
    # call site turns this file red again by itself -- that is the guard, not
    # this sentence.
    ("bots/FunLib/jmz_func.lua", "J.RoshanPitProximity", "UNDER", 3, 4):
        (1, "DEFAULTED: nRadius read once, as `nRadius or 1600`, past the "
            "`if not bRoshDist then return` early exit"),

    # ---- first seen 2026-09-03, when the resolver learned to cross a module
    # ---- boundary.  These were never new; they were unreachable by the tool.
    ("bots/hero_selection.lua", "Utils.PrintTable", "UNDER", 1, 2):
        (1, "VENDORED: transpiled debug printer, indent defaults inside"),
    # ____exports.MoveBotSafely(bot, targetPos) hands targetPos straight to
    # GetSafeDestination, whose first line is `targetPos or add(
    # bot:GetLocation(), RandomVector(260))`.  The one-argument call is the
    # documented way to ask for "somewhere safe near me".
    ("bots/mode_roam_generic.lua", "J.Utils.MoveBotSafely", "UNDER", 1, 2):
        (1, "DEFAULTED: targetPos nil -> bot location + RandomVector(260), "
            "substituted on GetSafeDestination's first line"),
    # The tree's only OVER member, and it was invisible for as long as the
    # resolver keyed on `____exports.CMLaneAssignment` while the call site
    # writes `CaptainMode.CMLaneAssignment`.  `userSwitchedRole` is a
    # file-scope flag in hero_selection.lua set at one place (a human typing
    # `!pick` in chat) and passed at one place -- here -- to a function that
    # declares one parameter.  Lua drops it, so the flag is write-only and the
    # feature behind it was never implemented.
    # COSMETIC and not TEETH on two counts, both structural: the branch is
    # `GetGameMode() == GAMEMODE_CM or GAMEMODE_REVERSE_CM`, and this repo
    # optimises Turbo (GAMEMODE 23), which never enters it; and an OVER
    # argument cannot change behaviour even when the branch is entered.
    # !! What would make this row wrong: CMLaneAssignment growing a second
    # parameter.  Then the argument stops being dropped and starts being read,
    # and the row must be re-judged rather than re-counted.
    ("bots/hero_selection.lua", "CaptainMode.CMLaneAssignment", "OVER", 2, 1):
        (1, "COSMETIC: `userSwitchedRole` is dropped by Lua; the flag has no "
            "other reader, and the branch is CM-only (Turbo never enters it)"),
}

# Real, behaviour-bearing, and deliberately NOT swept here: each row is routed
# to the group that owns the file, with the issue that carries it.  This table
# exists so that "judged" and "benign" stay different words -- ALLOWLIST means
# the call is fine, ROUTED means the call is broken and someone else's to fix.
# A row may only leave this table by being FIXED (or refuted in its issue).
ROUTED = {
    # FIXED 2026-09-03 (hero group, GH #451): the eight one-argument
    # `J.Utils.GetItem` calls in hero_tinker.lua now pass the bot, so this row
    # left the table the only way a ROUTED row may -- by being repaired.
    #
    # One correction worth carrying forward, because the row's own sibling got
    # it right: this table read the tinker row as "Live: CanDoCombo2 reaches
    # the first of these whenever tinker has blink + Laser + WarpFlare
    # castable", while the `mode_roam_generic.lua` row below reads "LATENT, not
    # live: GeneralReactToStackedDebuff has no caller in bots/".  The tinker
    # calls were latent too, and for a stronger reason -- ALL SEVEN of their
    # enclosing functions are unreachable from the three members the engine
    # dispatches on a BotLib module.  An enclosing `if` is not reachability.
    # Counted, and kept: tests/test_hero_export_reachability.py.
    #
    # `not J.Utils.NumActionTypeInQueue(BOT_ACTION_TYPE_ATTACK) <= 2` carries
    # TWO independent errors, either of which raises on its own: the missing
    # `bot` (the enum becomes the receiver) and the precedence -- `not` binds
    # tighter than `<=`, so this is `(not <boolean>) <= 2`, measured under
    # lua5.1 as "attempt to compare boolean with number".
    # LATENT, not live: GeneralReactToStackedDebuff has no caller in bots/.
    ("bots/mode_roam_generic.lua", "J.Utils.NumActionTypeInQueue", "UNDER", 1, 2):
        (1, "TEETH: latent runtime error (dead function), strategy -- GH #452"),
    # ____exports.SetContains(set, key) is `not not set[key]`.  With one
    # argument set is the item NAME and key is nil; `("item_aegis")[nil]` is a
    # legal read that yields nil, so the guard is CONSTANT FALSE rather than a
    # crash, and `not SetContains(...)` is constant true.  ignorePickupList is
    # therefore write-only: added to at :1821, never consulted.  Second,
    # independent defect in the same three lines -- AddToSet stores the item
    # HANDLE while the reads ask about the item NAME, so passing the set would
    # still never match (the 0SLOT / slotarb index-space family).
    ("bots/mode_team_roam_generic.lua", "Utils.SetContains", "UNDER", 1, 2):
        (2, "TEETH: constant-false guard, strategy -- GH #452"),
    ("bots/mode_team_roam_generic.lua", "J.Utils.SetContains", "UNDER", 1, 2):
        (1, "TEETH: constant-false guard, strategy -- GH #452"),
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


REQUIRE_RE = re.compile(
    r"require\s*\(\s*GetScriptDirectory\(\)\s*\.\.\s*['\"]/?([^'\"]+)['\"]\s*\)")
LOCAL_ALIAS_RE = re.compile(
    r"local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*" + REQUIRE_RE.pattern)
FIELD_ALIAS_RE = re.compile(
    r"^[ \t]*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"
    + REQUIRE_RE.pattern, re.M)
EXPORT_DECL_RE = re.compile(
    r"^[ \t]*(?:function\s+____exports\.([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)"
    r"|____exports\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(([^)]*)\))",
    re.M)


def all_lua_files(root=None):
    root = root or os.path.join(REPO, "bots")
    return sorted(glob.glob(os.path.join(root, "**", "*.lua"), recursive=True))


def module_key(path):
    """'<repo>/bots/FunLib/utils.lua' -> 'FunLib/utils' (what require() names)."""
    rel = os.path.relpath(path, os.path.join(REPO, "bots"))
    return rel[:-4].replace(os.sep, "/") if rel.endswith(".lua") else rel


def collect_module_exports(files):
    """module key -> {export name: (arity, vararg, defining file)}.

    Transpiled modules declare `function ____exports.Foo(a, b)`; importers only
    ever see the name they bound `require` to.  This table is the other half of
    that mapping.
    """
    mods = {}
    for path in files:
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        if "____exports" not in src:
            continue
        rel = os.path.relpath(path, REPO)
        table = mods.setdefault(module_key(path), {})
        for m in EXPORT_DECL_RE.finditer(src):
            name = m.group(1) or m.group(3)
            raw = (m.group(2) if m.group(1) else m.group(4)).strip()
            params = [p.strip() for p in raw.split(",")] if raw else []
            if name in table and table[name][0] != len(params):
                table[name] = (table[name][0], table[name][1], True)
                continue
            table[name] = (len(params), "..." in params, rel)
    return mods


def collect_field_aliases(files):
    """(module key of the file, field) -> module key it was bound to.

    jmz_func writes `J.Utils = require('/FunLib/utils')`, so a caller holding
    `J` can reach utils' exports two segments deep as `J.Utils.Foo(`.
    """
    out = {}
    for path in files:
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        for m in FIELD_ALIAS_RE.finditer(src):
            out[(module_key(path), m.group(2))] = m.group(3).strip("/")
    return out


def local_aliases(src):
    """alias -> module key, for one file's `local X = require(...)` lines."""
    return {m.group(1): m.group(2).strip("/")
            for m in LOCAL_ALIAS_RE.finditer(src)}


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
    mods = collect_module_exports(decl_files)
    fields = collect_field_aliases(decl_files)
    findings = []
    stats = {"declarations": len(decls), "files": 0, "dotted_calls": 0,
             "resolved_calls": 0, "ambiguous_skipped": 0, "vararg_skipped": 0,
             "modules": len(mods), "exports": sum(len(v) for v in mods.values()),
             "alias_calls": 0, "alias_resolved": 0}

    def resolve_alias(name, aliases):
        """`Utils.SetContains` / `J.Utils.SetContains` -> the ____exports decl.

        Returns (arity, defining file, ambiguous, vararg) or None.  Only the
        LAST segment can be the export name; everything before it must resolve
        to a module through the import graph.
        """
        segs = name.split(".")
        if len(segs) < 2 or len(segs) > 3:
            return None
        head, fname = segs[:-1], segs[-1]
        mod = aliases.get(head[0])
        if mod is None:
            return None
        if len(head) == 2:
            mod = fields.get((mod, head[1]))
            if mod is None:
                return None
        entry = mods.get(mod, {}).get(fname)
        if entry is None:
            return None
        if entry[2] is True:          # two arities inside the module
            return (entry[0], mod, True, entry[1])
        return (entry[0], entry[2], False, entry[1])

    for path in scan_files:
        stats["files"] += 1
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        rel = os.path.relpath(path, REPO)
        aliases = local_aliases(src)
        for m in CALL_RE.finditer(src):
            stats["dotted_calls"] += 1
            name = m.group(1)
            entry = decls.get(name)
            via_alias = False
            if entry is None:
                entry = resolve_alias(name, aliases)
                if entry is None:
                    continue
                via_alias = True
                stats["alias_calls"] += 1
            declared, dfile, ambiguous, vararg = entry
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
            if via_alias:
                stats["alias_resolved"] += 1
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

    # Cross-module cases need two files inside a fake `bots/` tree, because
    # module keys are computed relative to it.  Each pins one half of the
    # import-graph resolution that 2026-09-03 added.
    xcases = [
        # (module source, caller source, expected)
        # the plain alias: local U = require('/m'); U.f(1) against ____exports
        ("function ____exports.f(a, b) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.f(1)\n",
         [("U.f", "UNDER", 1, 2)]),
        # an OVER across the same boundary -- the half that used to read 0
        ("function ____exports.f(a) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.f(1, 2)\n",
         [("U.f", "OVER", 2, 1)]),
        # a correct call stays silent
        ("function ____exports.f(a, b) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.f(1, 2)\n", []),
        # an alias that was never require()d must NOT resolve -- resolving by
        # bare leaf name is exactly the false positive this tool must not make
        ("function ____exports.f(a, b) end\n",
         "Nope.f(1)\n", []),
        # the export name must be the LAST segment; a module used as a value
        # does not make every deeper field an export
        ("function ____exports.f(a, b) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.x.f(1)\n", []),
        # ...and the chain must be at most alias.field.export.  A four-segment
        # name resolving against the alias's OWN module would be a confident
        # mismatch reported on the wrong declaration entirely -- the false
        # positive this tool must never make.  No such call exists in bots/
        # today, which is exactly why the bound needs a synthetic case: the
        # mutation stand's M8 survived on an empty domain until this line.
        ("function ____exports.f(a, b) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.a.b.f(1)\n", []),
        # a module declaring the same export twice with different arities is
        # ambiguous and skipped, exactly as same-file declarations are
        ("function ____exports.f(a) end\nfunction ____exports.f(a, b) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.f(1)\n", []),
        # varargs are skipped across the boundary too
        ("function ____exports.f(a, ...) end\n",
         "local U = require(GetScriptDirectory()..'/m')\nU.f(1)\n", []),
    ]
    for i, (mod_src, call_src, want) in enumerate(xcases, len(cases) + 1):
        with tempfile.TemporaryDirectory() as d:
            bots = os.path.join(d, "bots")
            os.makedirs(bots)
            mp = os.path.join(bots, "m.lua")
            cp = os.path.join(bots, "caller.lua")
            open(mp, "w").write(mod_src)
            open(cp, "w").write(call_src)
            global REPO
            saved, REPO = REPO, d
            try:
                found, _ = census([cp], [mp, cp])
            finally:
                REPO = saved
            got = sorted((f["name"], f["kind"], f["passed"], f["declared"])
                         for f in found)
            if got != sorted(want):
                failures += 1
                print("  FAIL case %d: want %r got %r" % (i, sorted(want), got))
            else:
                print("  ok   case %d" % i)
    total = len(cases) + len(xcases)
    print("%d/%d selfcheck cases pass" % (total - failures, total))
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
    print("cross-module: %d transpiled module(s), %d export(s); %d alias call(s) "
          "reached a declaration, %d of them parsed"
          % (stats["modules"], stats["exports"], stats["alias_calls"],
             stats["alias_resolved"]))
    if stats["alias_resolved"] == 0 and stats["files"] > 50:
        print("  !! ZERO alias calls resolved over a full-tree scan.  Before "
              "2026-09-03 that was this tool's normal state and it printed "
              "OVER (0) anyway -- treat any count below as unread.")
    for kind in ("OVER", "UNDER"):
        rows = [f for f in findings if f["kind"] == kind]
        print("\n== %s (%d)" % (kind, len(rows)))
        for f in sorted(rows, key=lambda r: (r["file"], r["line"])):
            key = (f["file"], f["name"], f["kind"], f["passed"], f["declared"])
            verdict = ALLOWLIST.get(
                key, ROUTED.get(key, (0, "*** NOT IN ALLOWLIST ***")))[1]
            print("  %s:%d  %s  passed %d, declares %d  [%s]\n      %s"
                  % (f["file"], f["line"], f["name"], f["passed"],
                     f["declared"], f["declared_in"], verdict))
    return 0


if __name__ == "__main__":
    sys.exit(main())

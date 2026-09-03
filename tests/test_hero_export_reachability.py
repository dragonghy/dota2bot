#!/usr/bin/env python3
"""[ratchet] Functions in a BotLib hero file that the engine can never reach.

WHY THIS EXISTS.  GH #451 reported eight `J.Utils.GetItem('item_x')` calls in
`bots/BotLib/hero_tinker.lua` -- one argument where the wrapper wants
`(bot, itemName)` -- and called them live, on the strength of reading their
enclosing `if`.  Each of those calls RAISES on every execution (the wrapper's
first statement is `bot:GetItemInSlot(i)` and `bot` is a string; see
`tests/test_utils_getitem_arity.lua` for the interpreter reading).  A statement
that raises every time it runs, in a hero that has shipped for months, is the
loudest possible hint that it does not run -- and it does not: nothing calls its
enclosing function.

That inverts the fix.  Under the repo rule a behaviour change ships gated, and
GH #451's second acceptance line asks for a soak candidate + a real-frame
fixture on the grounds that the repaired call makes downstream branches
"reachable for the first time".  They are not reachable after the repair either,
because the FUNCTION is not.  An unreachable statement has no behaviour to hold
dark, so the arity repair landed ungated -- and this file is the reading that
claim rests on, kept, so it is checked rather than remembered.

WHAT THE ENGINE ACTUALLY CALLS.  A BotLib module is loaded by
`bots/bot_generic.lua`, `bots/ability_item_usage_generic.lua` and
`bots/item_purchase_generic.lua`, and between them they touch exactly three
FUNCTION members plus five data fields.  The root set is DERIVED from those
files here, not typed in, and then compared against the registered set: a fourth
dispatch entry appearing upstream widens reachability for all 128 hero files at
once, and that must arrive as a red naming the new entry rather than as a
silently larger `seen` set.

HOW REACHABILITY IS COMPUTED.  Per file: comment-stripped source, `function
X.Name(` / `function Name(` declarations, then a transitive closure over
`name(`-shaped call sites in each body.  Each hero file is `dofile`d into its
own bot's Lua state, so a name defined in another hero file is not a caller --
`CanDoCombo1` exists in both `hero_tinker.lua` and `hero_techies.lua` and they
never see each other.

LIMITS, stated rather than discovered later:
  * Indirect dispatch would defeat the closure.  It does not occur: `X['...']`
    appears 899 times and every one is a DATA field (`sBuyList`, `sSkillList`,
    `bDeafaultAbility`, ...); the 15 `local v = X.Foo(...)` lines are calls, not
    function-value aliases, and the closure sees them.  If either becomes false
    this census reads high and the fix is here, not in the ceiling.
  * The failure direction is therefore "reports an orphan that is reached by a
    route this scan cannot see" -- loud, not silent.  It never reports a reached
    function as unreachable-and-fine.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERO_DIR = os.path.join(REPO, "bots", "BotLib")

# The generic scripts that load a BotLib module and call into it.
DISPATCHERS = (
    "bots/bot_generic.lua",
    "bots/ability_item_usage_generic.lua",
    "bots/item_purchase_generic.lua",
)

# Function members the dispatchers call on a loaded module.  Derived below and
# compared against this; see the docstring for why it is not simply derived.
DISPATCHED_FUNCTIONS = {"MinionThink", "CanUseRefresherShard", "SkillsComplement"}

# Ratchet.  Monotone DOWN: wiring an orphan up, or deleting it, lowers this.
# Measured 2026-09-03 on 04cb6c0 over 128 files / 1061 functions.
ORPHAN_CEILING = 34

# GH #451's eight call sites live in these functions of hero_tinker.lua.  This
# is a REGISTERED READING, not a wish.
#
# ==> IF THIS GOES RED, READ THE DIRECTION BEFORE TOUCHING IT. <==
# Red because these names became REACHABLE means somebody wired tinker's combo
# and item layer into `SkillsComplement`.  That is the real fix and it is
# welcome -- but it is a behaviour change: it needs a turbo-only soak candidate
# and a real-frame fixture, and the ungated arity repair (GH #451) stops being
# justified by unreachability.  Move this reading to a dated archive line and
# say so in the report.  Do NOT delete the check to get green.
# Red because a name is GONE means the layer was deleted instead; drop the
# vanished name here in the same change.
GH451_UNREACHABLE = {
    "hero_tinker.lua": [
        "CanDoCombo2", "CanDoCombo3", "CanDoCombo4", "CanDoCombo5",
        "CanClearCreeps2", "X.ConsiderSoulRing", "X.ConsiderShivasGuard",
    ],
}

checks = 0
failures = []


def check(ok, msg):
    global checks
    checks += 1
    if not ok:
        failures.append(msg)


def strip_comment(line):
    """Cut at the first `--` that is not inside a quoted string."""
    out, i, quote = [], 0, None
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                out.append(c)
                i += 1
                if i < len(line):
                    out.append(line[i])
                i += 1
                continue
            if c == quote:
                quote = None
            out.append(c)
            i += 1
            continue
        if c in "\"'":
            quote = c
            out.append(c)
            i += 1
            continue
        if c == "-" and line[i + 1:i + 2] == "-":
            break
        out.append(c)
        i += 1
    return "".join(out)


def analyse(path):
    """-> (defs {name: (start, end)}, reachable set)."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        code = [strip_comment(l) for l in fh.read().split("\n")]

    starts = []
    for i, line in enumerate(code):
        m = re.match(r"\s*function\s+((?:X\.)?[A-Za-z_][A-Za-z0-9_]*)\s*\(", line)
        if m:
            starts.append((i, m.group(1)))
    defs = {}
    for k, (i, name) in enumerate(starts):
        defs[name] = (i, starts[k + 1][0] - 1 if k + 1 < len(starts) else len(code) - 1)

    short = {n.split(".")[-1]: n for n in defs}

    def calls_in(name):
        s, e = defs[name]
        found = set()
        for m in re.finditer(r"\b((?:X\.)?[A-Za-z_][A-Za-z0-9_]*)\s*\(",
                             "\n".join(code[s + 1:e + 1])):
            c = m.group(1)
            if c in defs:
                found.add(c)
            elif c in short:
                found.add(short[c])
        return found

    seen, stack = set(), [n for n in defs if n.split(".")[-1] in DISPATCHED_FUNCTIONS]
    while stack:
        n = stack.pop()
        if n in seen or n not in defs:
            continue
        seen.add(n)
        stack.extend(calls_in(n))
    return defs, seen


# ---- the root set is derived, then held to the register -------------------
derived = set()
for rel in DISPATCHERS:
    with open(os.path.join(REPO, rel), encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = strip_comment(raw)
            for m in re.finditer(r"\b(?:BotBuild|newBuild)\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", line):
                derived.add(m.group(1))

check(derived == DISPATCHED_FUNCTIONS,
      "the generic dispatchers call a different set of hero-module functions "
      "than this file registers: derived %s vs registered %s. A NEW entry "
      "widens reachability for every hero file at once -- update "
      "DISPATCHED_FUNCTIONS and re-read ORPHAN_CEILING in the same change."
      % (sorted(derived), sorted(DISPATCHED_FUNCTIONS)))

check(derived,
      "no BotBuild.<name>( dispatch was found in any of %s -- the dispatchers "
      "moved or were renamed, and this census is now vacuous rather than clean"
      % (DISPATCHERS,))

# ---- the census -----------------------------------------------------------
orphans_by_file, n_defs = {}, 0
for name in sorted(os.listdir(HERO_DIR)):
    if not (name.startswith("hero_") and name.endswith(".lua")):
        continue
    defs, seen = analyse(os.path.join(HERO_DIR, name))
    n_defs += len(defs)
    orph = sorted((n for n in defs if n not in seen), key=lambda n: defs[n][0])
    if orph:
        orphans_by_file[name] = orph

n_files = len([n for n in os.listdir(HERO_DIR)
               if n.startswith("hero_") and n.endswith(".lua")])
total = sum(len(v) for v in orphans_by_file.values())

check(total <= ORPHAN_CEILING,
      "unreachable hero-file functions rose to %d, above the %d ceiling. A new "
      "orphan is dead logic that reads as live: %s"
      % (total, ORPHAN_CEILING,
         {f: v for f, v in sorted(orphans_by_file.items()) if v}))

# ---- the GH #451 reading --------------------------------------------------
for fname, names in sorted(GH451_UNREACHABLE.items()):
    have = orphans_by_file.get(fname, [])
    for n in names:
        check(n in have,
              "%s:%s is no longer an unreachable orphan. Read the direction in "
              "GH451_UNREACHABLE above before editing this list: if the layer "
              "got wired up, that wiring needs a soak candidate + fixture and "
              "the ungated GH #451 arity repair loses its justification."
              % (fname, n))

print("%d checks, %d failed  [%d files, %d functions, %d orphans, ceiling %d]"
      % (checks, len(failures), n_files, n_defs, total, ORPHAN_CEILING))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)

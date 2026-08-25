#!/usr/bin/env python3
"""Census `ITEMID`: `item_*` string literals the current patch has no item for.

Why this exists (hero group, 2026-08-25)
----------------------------------------
Every axis this group has run so far asked its question about an ABILITY -- what
a constant is worth (`zusstatic`), which KV key a reader names (#162), what
SHAPE the value behind that key has (#179), which cast order the behavior bits
accept (#177), which power-treads state a helper switches to (#183).  This one
asks the same family of question one layer over, about ITEMS::

    the file wrote down an item name.  Does the game ship an item by that name?

An item name in this tree reaches the engine through exactly two doors and both
of them answer a wrong name with silence:

  * `bot:FindItemSlot(name)` / `Item.HasItem(bot, name)` answer **-1 / false**
    for a name no item has -- indistinguishable from "the hero does not own it".
    So `not HasItem(bot, 'item_typo')` is a permanently TRUE conjunct and
    `HasItem(bot, 'item_typo')` a permanently false one.
  * a buy list entry that is neither a real item nor an `aba_item.lua` macro is
    forwarded verbatim by `Item.GetBasicItems` (its `Item[v] == nil` branch) and
    handed to the purchase layer as if it were a basic item.

Neither raises.  `print()` never reaches the server console and the engine error
handler is broken (AGENTS.md), so a renamed item is exactly as loud as a correct
one -- which is not at all.  Items get renamed for real: Gleipnir's internal name
is `item_gungir`, and this tree asks for `item_gleipnir`.

WHAT IT PROVES AND WHAT IT DOES NOT
-----------------------------------
Strong, and one-directional in the SAME sense as #162's key census:

  * a literal that is in no `items.txt` block and in no `aba_item.lua` macro is
    a PROOF that no item answers to it -- the name is written down in full, so
    there is no handle-resolution step left to doubt.
  * silence is NOT a clean bill of health.  A name assembled at runtime
    (`'item_' .. sTail`, `string.find(name, 'item_flask')`, the `item_recipe_`
    prefix built in ability_item_usage_generic.lua) is invisible to this script
    by construction, and it does not read the neutral-item tiers' own tables.

And a limit on the SITE, not the name: a proven-dead name in a file nothing
`require`s costs nothing today.  The census reports the file so the reader can
check that themselves; it does not build a call graph.

THE GROUND TRUTH IS THE THING TO DOUBT FIRST (#179's lesson, paid again here)
----------------------------------------------------------------------------
The first version of this script read `item_gleipnir` as MISSING and that was
RIGHT -- but for a reason worth writing down, because the identical output would
have been produced by a broken parser.  `items.txt` really does contain a block
commented `// Gleipnir`; the block's key is `item_gungir`.  A census whose
ground truth is parsed cannot tell "the patch renamed it" from "my parser lost
it", so `--self-test` feeds the block parser a synthetic KV with the shapes that
break naive readers (a nested `"item_x"` value inside a requirements block, a
name that appears only in a comment) and asserts what it finds.

Usage::

    python3 tools/agent/item_name_census.py            # census
    python3 tools/agent/item_name_census.py --snapshot # tests/mock/item_names.lua
    python3 tools/agent/item_name_census.py --self-test

Network: one HTTPS GET of the same public d2vpkr mirror `gen_ability_meta.py`,
`cast_shape_census.py` and the two special-value censuses already use.  No AWS,
no cost, and the test never goes to the network -- it reads the frozen snapshot.
"""

import glob
import os
import re
import sys
import urllib.request

ITEMS_URL = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
             "dota/scripts/npc/items.txt")
OUT = "tests/mock/item_names.lua"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# A quoted item name anywhere in a line, after line comments are stripped.
LITERAL_RE = re.compile(r"""['"](item_[a-z0-9_]+)['"]""")

# `string.find(x, 'item_recipe_')` and friends do not LOOK UP a name, they probe
# for a substring of one -- `item_recipe_` matches every recipe there is.  Those
# literals are deliberately not whole item names and reporting them as missing
# items is a category error, so they are classified apart rather than dropped
# (dropping them would also hide a probe for a prefix no item carries any more).
PROBE_RE = re.compile(r"""(?:string\.(?:find|match|gmatch|gsub)|[:.](?:find|match|gmatch|gsub))\s*\(""")

# `Item['name'] = ...` -- aba_item.lua's macro/alias registry.  A buy list entry
# that matches one of these never reaches the engine under that name.
MACRO_RE = re.compile(r"""Item\[\s*['"]([A-Za-z0-9_]+)['"]\s*\]\s*=""")


def strip_line_comments(text):
    """Lua `--` to end of line.  Deliberately crude and deliberately applied:
    aba_item.lua carries whole item names inside rationale comments (the
    `-- 'item_shadow_amulet',` line at :98 is a commented-OUT list entry), and a
    census that counted those would report names nothing reads."""
    return "\n".join(re.sub(r"--.*$", "", ln) for ln in text.split("\n"))


def kv_item_names(text):
    """Top-level item block keys in an items.txt.

    Depth matters: `"item_maelstrom"` also appears as a VALUE inside recipe
    requirement blocks and as an `ItemResult`, and a depth-blind reader would
    accept those as declarations -- which is the failure mode that makes a
    renamed item invisible (a name can be referenced by a recipe it no longer
    ships under).  Only a bare `"item_x"` line at depth 1 declares an item.
    """
    names = set()
    depth = 0
    for line in text.split("\n"):
        stripped = line.strip()
        # A KV comment cannot contain a brace that counts, but it CAN contain a
        # name; drop it before both tests.
        if stripped.startswith("//"):
            continue
        m = re.match(r'^"(item_[a-z0-9_]+)"\s*$', stripped)
        if m and depth == 1:
            names.add(m.group(1))
        depth += line.count("{") - line.count("}")
    return names


def macros_of(aba_item_src):
    return set(MACRO_RE.findall(strip_line_comments(aba_item_src)))


def is_known(name, kv_names, macros):
    """The predicate, extracted so the self-test can drive it directly (§24 of
    the hero charter: a scan whose offender set is empty on the real tree cannot
    exercise its own predicate)."""
    if name in kv_names or name in macros:
        return True
    # `item_recipe_x` is a real KV block for every composite x, but some patches
    # ship the recipe under the result's name only; accept it when the result
    # exists.
    if name.startswith("item_recipe_"):
        return "item_" + name[len("item_recipe_"):] in kv_names
    return False


def offences_in(path, text, kv_names, macros):
    """Report half, also extracted for the self-test.

    Yields `(kind, name, site)` with kind in {'LOOKUP', 'PROBE'}."""
    out = []
    for i, line in enumerate(text.split("\n"), 1):
        code = re.sub(r"--.*$", "", line)
        kind = "PROBE" if PROBE_RE.search(code) else "LOOKUP"
        for name in LITERAL_RE.findall(code):
            if not is_known(name, kv_names, macros):
                out.append((kind, name, "%s:%d" % (path, i)))
    return out


def fetch_items():
    with urllib.request.urlopen(ITEMS_URL, timeout=120) as fh:
        return fh.read().decode("utf-8", "replace")


def scan(kv_names, macros):
    hits = {}
    for path in sorted(glob.glob(os.path.join(REPO, "bots", "**", "*.lua"),
                                 recursive=True)):
        rel = os.path.relpath(path, REPO)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        for kind, name, site in offences_in(rel, text, kv_names, macros):
            hits.setdefault((kind, name), []).append(site)
    return hits


SELF_TEST_KV = '''"DOTAAbilities"
{
\t// Recipe: Renamed Thing
\t"item_recipe_gungir"
\t{
\t\t"ItemResult"\t"item_gungir"
\t\t"ItemRequirements"
\t\t{
\t\t\t"01"\t"item_rod_of_atos*;item_point_booster"
\t\t}
\t}
\t// Gleipnir
\t"item_gungir"
\t{
\t\t"AbilityCooldown"\t"18"
\t}
\t"item_rod_of_atos"
\t{
\t\t"ItemCost"\t"3050"
\t}
}
'''


def self_test():
    fails = []

    def check(cond, msg):
        if not cond:
            fails.append(msg)

    names = kv_item_names(SELF_TEST_KV)
    # The three real declarations, and NOT the two names that occur only as a
    # requirement value / an ItemResult / a comment.
    check(names == {"item_recipe_gungir", "item_gungir", "item_rod_of_atos"},
          "block parser read %s" % sorted(names))
    check("item_point_booster" not in names,
          "a requirement VALUE was read as a declaration -- the depth test is dead")
    check("item_gleipnir" not in names,
          "a name that appears only in a comment was read as a declaration")

    macros = macros_of("Item['item_mage_outfit'] = { 'item_tranquil_boots' }\n"
                       "-- Item['item_ghost_outfit'] = { 'x' }\n")
    check(macros == {"item_mage_outfit"},
          "macro reader read %s (a commented-out registration is not one)" % sorted(macros))

    # Predicate, both directions, on a synthetic offender and its near misses.
    check(not is_known("item_gleipnir", names, macros), "renamed item read as known")
    check(is_known("item_gungir", names, macros), "shipped item read as unknown")
    check(is_known("item_mage_outfit", names, macros), "macro read as unknown")
    check(is_known("item_recipe_gungir", names, macros), "recipe read as unknown")
    check(not is_known("item_recipe_gleipnir", names, macros),
          "a recipe for an item that does not exist read as known")

    # Report, on a synthetic file: the offender is found, the commented-out
    # sibling one line above it is not.  Without this pair the report branch is
    # unreachable on a clean tree and a mutation that stops reporting escapes.
    src = ("local a = HasItem(bot, 'item_gungir')\n"
           "-- local b = HasItem(bot, 'item_gleipnir')\n"
           "local c = HasItem(bot, 'item_gleipnir')\n"
           "if string.find(n, 'item_gleipnir') then end\n")
    got = offences_in("synthetic.lua", src, names, macros)
    check(got == [("LOOKUP", "item_gleipnir", "synthetic.lua:3"),
                  ("PROBE", "item_gleipnir", "synthetic.lua:4")],
          "report read %s -- expected the line-3 lookup and the line-4 probe" % got)

    for msg in fails:
        print("SELF-TEST FAIL: " + msg)
    print("self-test: %d check(s) failed" % len(fails))
    return 1 if fails else 0


def write_snapshot(kv_names):
    path = os.path.join(REPO, OUT)
    lines = [
        "-- GENERATED by tools/agent/item_name_census.py -- do not hand-edit.",
        "--",
        "-- Every item name the current patch declares as a top-level block in",
        "-- scripts/npc/items.txt.  Frozen so tests/test_item_name_census.lua can",
        "-- ask \"does the game ship an item by this name\" without going to the",
        "-- network.  Regenerate after a patch:",
        "--",
        "--     python3 tools/agent/item_name_census.py --snapshot",
        "",
        "local X = {}",
        "",
        "X.NAMES = {",
    ]
    for name in sorted(kv_names):
        lines.append("    ['%s'] = true," % name)
    lines += ["}", "", "return X", ""]
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print("wrote %s (%d names)" % (OUT, len(kv_names)))


def main():
    if "--self-test" in sys.argv:
        return self_test()

    kv_names = kv_item_names(fetch_items())
    if len(kv_names) < 400:
        print("REFUSING: items.txt parsed to only %d names -- the mirror or the "
              "parser changed, and a short ground truth turns every correct name "
              "into a false MISSING." % len(kv_names))
        return 2

    if "--snapshot" in sys.argv:
        write_snapshot(kv_names)
        return 0

    with open(os.path.join(REPO, "bots/FunLib/aba_item.lua"),
              encoding="utf-8", errors="replace") as fh:
        macros = macros_of(fh.read())

    hits = scan(kv_names, macros)
    for key in sorted(hits, key=lambda k: (k[0], -len(hits[k]), k[1])):
        kind, name = key
        print("%-7s %-28s %2d  %s" % (kind, name, len(hits[key]), ", ".join(hits[key])))
    nlookup = sum(len(v) for k, v in hits.items() if k[0] == "LOOKUP")
    print("\n%d unknown name(s) at %d site(s), of which %d are LOOKUP sites; "
          "ground truth %d items, %d macros"
          % (len(hits), sum(len(v) for v in hits.values()), nlookup,
             len(kv_names), len(macros)))
    print("LIMIT: names assembled at runtime are invisible here; a dead name in a "
          "file nothing require()s costs nothing.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

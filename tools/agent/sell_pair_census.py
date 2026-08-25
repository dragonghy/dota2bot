#!/usr/bin/env python3
"""Census `0SELL`: sell rules whose two items can never be held at once.

Why this exists (hero group, 2026-08-25)
----------------------------------------
`bots/item_purchase_generic.lua:SetPairedItems` is a PAIR list, not a list of
things to sell::

    function SetPairedItems(itemList)
        for i = 2 , #itemList, 2 do
            local nNewSlot = bot:FindItemSlot( itemList[i - 1] )   -- the NEW item
            local nOldSlot = bot:FindItemSlot( itemList[i] )       -- sell THIS one
            if nNewSlot >= 0 and nOldSlot >= 0 then
                bot:ActionImmediate_SellItem( bot:GetItemInSlot( nOldSlot ) )
            end
        end
    end

Both slots must be `>= 0` at the same instant, so a pair whose two items can
never sit in one inventory together is dead code -- silently, because
`FindItemSlot` on a name the hero never owns answers -1 and nothing anywhere
says so (`print()` never reaches the server console, AGENTS.md).

This is the sell-layer sibling of the axes the group has already run:
`0CLK` asks what a constant is worth, `0TERN` (GH #157/#165) asks how an
expression parses, `0SAT` (GH #168) asks whether two legs of one conjunction
can both be true.  `0SELL` asks whether two ITEMS can both be in the bag.

WHAT IT PROVES AND WHAT IT DOES NOT
-----------------------------------
The reachability walk (question Q5) is an UPPER BOUND on what a hero holds: it
executes the DECLARED buy list literally, in order, and auto-combines whatever
the recipes allow.  The real purchase layer buys strictly less than that -- see
GH #136 / GH #139, where WK's declared list contains a magic wand's parts and
40/40 games ended without the wand.  Therefore:

  * a pair unreachable in the upper bound is a PROOF that the rule is dead;
  * a pair reachable in the upper bound proves NOTHING about a real game.

Same one-directional shape as the boots-supply census (hero charter,
2026-08-24) and the KV key census (GH #162): findings are real, silence is not
a clean bill of health.

Questions asked (all five reported, including the empty ones, so nobody has to
re-scan for them):

  Q1  a sell-list entry that is not a real item and not one of the repo's own
      pseudo-item macros -- `FindItemSlot` on it is -1 forever;
  Q2  an odd-length sell list -- the loop starts at 2 and steps by 2, so the
      trailing entry is never read at all;
  Q3  a self-pair (`X` sells `X`);
  Q4  a pair whose OLD item is a transitive component of its NEW item -- the
      recipe consumed the old one, so the two cannot coexist;
  Q5  a pair neither of whose items the declaring hero's own build can reach
      (focus five only -- the buy lists of the other 121 heroes are not this
      group's property).

Usage::

    python3 tools/agent/sell_pair_census.py             # census
    python3 tools/agent/sell_pair_census.py --pairs axe # one hero's pairs

Network: two HTTPS GETs (odota `items.json` for recipes, the d2vpkr mirror's
`items.txt` for the real-name set) -- the same public mirrors
`gen_ability_meta.py` and `special_value_key_census.py` already use.  No AWS,
no cost.
"""

import glob
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

ODOTA_ITEMS = ("https://raw.githubusercontent.com/odota/dotaconstants/master/"
               "build/items.json")
VPKR_ITEMS = ("https://raw.githubusercontent.com/dotabuff/d2vpkr/master/"
              "dota/scripts/npc/items.txt")

FOCUS = ["axe", "zuus", "skeleton_king", "lion", "crystal_maiden"]

# The one registered exception to Q2.  Recorded rather than fixed: hero_meepo is
# not this group's hero and the repair is a widening (it makes a sell fire that
# never has), which needs its own evidence -- see GH #168 on widening levers.
KNOWN_ODD = {"hero_meepo.lua"}


# --------------------------------------------------------------------------
# source parsing
# --------------------------------------------------------------------------

def strip_comments(src):
    """Drop Lua comments.

    Must run BEFORE any item-name scan: rationale blocks in this repo quote
    item names in prose, and counting those as purchases is a mistake the group
    has actually made (`tests/test_wk_magic_wand_branches.lua`).
    """
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    return re.sub(r"--(?!\[\[).*", "", src)


def table_items(src, key_pattern):
    """Every `item_*` literal inside the first `<key_pattern> = { ... }` table."""
    m = re.search(key_pattern + r"\s*=\s*\{(.*?)\n\}", src, re.S)
    if m is None:
        return None
    return re.findall(r"['\"](item_[a-z0-9_]+)['\"]", m.group(1))


def pairs_of(flat):
    """The pairs `SetPairedItems` actually reads: (new, old), i = 2, #l, 2.

    The trailing entry of an odd-length list is dropped here exactly as the Lua
    loop drops it -- that omission IS the Q2 finding, so it must not be papered
    over by pairing it with nothing.
    """
    return [(flat[i - 1], flat[i]) for i in range(1, len(flat), 2)]


def load_lua_item_tables():
    """`aba_item.lua`'s two pseudo-item tables.

    `tDefineItemRealName` maps a pseudo name to ONE real item;
    `Item['<name>'] = { ... }` expands a pseudo name into a LIST of them.
    """
    src = strip_comments(open(os.path.join(ROOT, "bots/FunLib/aba_item.lua"),
                              encoding="utf-8", errors="replace").read())
    alias = dict(re.findall(
        r"\['(item_[a-z0-9_]+)'\]\s*=\s*\"(item_[a-z0-9_]+)\"", src))
    bundle = {}
    for m in re.finditer(r"Item\[['\"](item_[a-z0-9_]+)['\"]\]\s*=\s*\{([^}]*)\}", src):
        bundle[m.group(1)] = re.findall(r"['\"](item_[a-z0-9_]+)['\"]", m.group(2))
    return alias, bundle


def expand(name, alias, bundle, depth=0):
    """Pseudo name -> the real items it stands for (bundles nest one level)."""
    if depth < 4 and name in bundle:
        out = []
        for part in bundle[name]:
            out.extend(expand(part, alias, bundle, depth + 1))
        return out
    return [alias.get(name, name)]


# --------------------------------------------------------------------------
# game data
# --------------------------------------------------------------------------

def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as fh:
        return fh.read().decode("utf-8", errors="replace")


def snapshot_items():
    """The frozen copy of `game_items()` -- offline, for tests.

    Regenerate with `--snapshot` after a patch.  Reading the snapshot instead of
    the network is what keeps `tests/test_sell_pair_census.py` from going red
    when a mirror is down; the price is that the snapshot can go stale, which is
    why the census tool itself always uses the live source.
    """
    with open(os.path.join(ROOT, "tests/mock/item_recipes.json"),
              encoding="utf-8") as fh:
        snap = json.load(fh)
    return set(snap["names"]), snap["recipes"]


def game_items():
    """(real item names, recipe map) for the patch on the public mirrors."""
    od = json.loads(fetch(ODOTA_ITEMS))
    kv = fetch(VPKR_ITEMS)
    names = set(re.findall(r'"(item_[A-Za-z0-9_]+)"\s*\r?\n?\s*\{', kv))
    names |= {"item_" + k for k in od}
    recipes = {}
    for k, v in od.items():
        comp = [c for c in (v.get("components") or []) if c]
        if comp:
            recipes["item_" + k] = ["item_" + c for c in comp]
    return names, recipes


# --------------------------------------------------------------------------
# criteria -- kept as free functions so the tests can feed them synthetic
# input.  A census that only ever runs on a clean tree never exercises its own
# positive path (hero charter §24), and these four are exactly that shape.
# --------------------------------------------------------------------------

def q1_unknown(flat, known):
    """Entries that name nothing -- neither a real item nor a repo macro."""
    return sorted({n for n in flat if n not in known})


def q2_odd(flat):
    """True when the last entry is structurally unreadable by the pair loop."""
    return len(flat) % 2 == 1


def q3_self(prs):
    return [p for p in prs if p[0] == p[1]]


def transitive_components(name, recipes, seen=None):
    seen = set() if seen is None else seen
    for c in recipes.get(name, []):
        if c not in seen:
            seen.add(c)
            transitive_components(c, recipes, seen)
    return seen


def q4_component_dead(prs, recipes):
    """Pairs where building NEW consumed OLD, so they cannot coexist."""
    return [p for p in prs if p[1] in transitive_components(p[0], recipes)]


def reachable_items(buy_list, alias, bundle, recipes):
    """Upper bound on the items this build ever holds.

    Walks the declared list in order and auto-combines after every purchase,
    which is what the engine does when a bot completes a recipe.  Returns the
    union of every inventory state along the way -- an item counts as reachable
    if it is held at ANY point, including one later consumed by an upgrade.
    """
    inv = {}
    held = set()

    def add(name):
        inv[name] = inv.get(name, 0) + 1
        held.add(name)

    def combine():
        changed = True
        while changed:
            changed = False
            for out, comp in recipes.items():
                need = {}
                for c in comp:
                    need[c] = need.get(c, 0) + 1
                if all(inv.get(c, 0) >= n for c, n in need.items()):
                    for c, n in need.items():
                        inv[c] -= n
                        if inv[c] == 0:
                            del inv[c]
                    add(out)
                    changed = True

    for entry in buy_list:
        for real in expand(entry, alias, bundle):
            add(real)
        combine()
    return held


def q5_unreachable(prs, held):
    """Pairs with at least one item this build can never hold."""
    return [(p, p[0] in held, p[1] in held) for p in prs
            if p[0] not in held or p[1] not in held]


# --------------------------------------------------------------------------
# collection + report
# --------------------------------------------------------------------------

def sell_lists():
    """Every sell list in `bots/`: the global one plus each hero's own."""
    out = []
    g = os.path.join(ROOT, "bots/FunLib/aba_item.lua")
    src = strip_comments(open(g, encoding="utf-8", errors="replace").read())
    flat = table_items(src, r"Item\['sSellList'\]")
    if flat:
        out.append(("GLOBAL aba_item.lua", g, flat))
    for path in sorted(glob.glob(os.path.join(ROOT, "bots/BotLib/hero_*.lua"))):
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        flat = table_items(src, r"X\['sSellList'\]")
        if flat:
            out.append((os.path.basename(path), path, flat))
    return out


def role_buy_lists(path):
    src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
    roles = {}
    for m in re.finditer(r"sRoleItemsBuyList\['(pos_\d)'\]\s*=\s*\{(.*?)\n\}", src, re.S):
        roles[m.group(1)] = re.findall(r"['\"](item_[a-z0-9_]+)['\"]", m.group(2))
    # `sRoleItemsBuyList['pos_2'] = sRoleItemsBuyList['pos_1']` style aliases.
    for m in re.finditer(
            r"sRoleItemsBuyList\['(pos_\d)'\]\s*=\s*sRoleItemsBuyList\['(pos_\d)'\]", src):
        if m.group(2) in roles:
            roles[m.group(1)] = roles[m.group(2)]
    return roles


def report(findings):
    """Render the census.  Separate from the criteria so a test can drive it."""
    lines = []
    for tag, label, detail in findings:
        lines.append("%-18s %-28s %s" % (tag, label, detail))
    return lines


def main(argv):
    alias, bundle = load_lua_item_tables()
    names, recipes = game_items()
    known = names | set(alias) | set(bundle)

    lists = sell_lists()
    findings = []

    for label, path, flat in lists:
        for n in q1_unknown(flat, known):
            findings.append(("Q1-NOT-AN-ITEM", label, n))
        if q2_odd(flat):
            tag = "Q2-ODD-KNOWN" if label in KNOWN_ODD else "Q2-ODD"
            findings.append((tag, label,
                             "len=%d, entry %r never read" % (len(flat), flat[-1])))
        prs = pairs_of(flat)
        for p in q3_self(prs):
            findings.append(("Q3-SELF-PAIR", label, "%s sells itself" % p[0]))
        for p in q4_component_dead(prs, recipes):
            findings.append(("Q4-COMPONENT-DEAD", label,
                             "%s consumed %s at build time" % (p[0], p[1])))

    if "--snapshot" in argv:
        # The offline half of this census lives in tests/, and a test that
        # reaches the network is a test that goes red when GitHub hiccups.  So
        # the patch's recipe graph is frozen here, the same way GH #166 froze
        # the talent slot order into tests/mock/talent_slots.lua.
        out = os.path.join(ROOT, "tests/mock/item_recipes.json")
        with open(out, "w", encoding="utf-8") as fh:
            json.dump({"_source": ODOTA_ITEMS,
                       "_note": "regenerate: python3 tools/agent/"
                                "sell_pair_census.py --snapshot",
                       "names": sorted(names),
                       "recipes": {k: recipes[k] for k in sorted(recipes)}},
                      fh, indent=0, sort_keys=True)
        print("wrote %s (%d items, %d recipes)" % (out, len(names), len(recipes)))
        return 0

    if "--pairs" in argv:
        who = argv[argv.index("--pairs") + 1]
        path = os.path.join(ROOT, "bots/BotLib/hero_%s.lua" % who)
        for role, buy in sorted(role_buy_lists(path).items()):
            held = reachable_items(buy, alias, bundle, recipes)
            print("== %s %s: %d reachable items" % (who, role, len(held)))
            for it in sorted(held):
                print("   ", it)
        return 0

    # Q5 -- focus five, against THEIR OWN sell list only.
    #
    # Deliberately NOT run against `Item['sSellList']`: that list is shared by
    # all 127 heroes, so "Crystal Maiden never reaches an Assault Cuirass" is
    # the design, not a defect (445 such lines when the filter is left off).  A
    # dead pair in a hero's OWN list is different -- one author wrote both the
    # buy list and the sell list, and they disagree.
    for hero in FOCUS:
        path = os.path.join(ROOT, "bots/BotLib/hero_%s.lua" % hero)
        src = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        own = table_items(src, r"X\['sSellList'\]") or []
        for role, buy in sorted(role_buy_lists(path).items()):
            held = reachable_items(buy, alias, bundle, recipes)
            for p, hn, ho in q5_unreachable(pairs_of(own), held):
                findings.append((
                    "Q5-UNREACHABLE",
                    "%s %s" % (hero, role),
                    "sell %s when %s (hasNew=%s hasOld=%s)"
                    % (p[1], p[0], hn, ho)))

    for line in report(findings):
        print(line)
    counts = {}
    for tag, _l, _d in findings:
        counts[tag] = counts.get(tag, 0) + 1
    print("\n%d finding(s): %s" % (len(findings), counts or "{}"))
    print("LIMIT: Q5 walks the DECLARED buy list, an upper bound on a real "
          "inventory (GH #136/#139). Unreachable = proof; reachable = nothing.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

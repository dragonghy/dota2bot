#!/usr/bin/env python3
"""`0SELL`: a hero's own sell rule must name items that hero can actually hold.

Plain python, no pytest (matches tests/test_canon_hero_join.py).

WHAT THIS PINS
--------------
1. THE SHAPE `SetPairedItems` READS.  The whole census rests on one Lua loop
   header in `bots/item_purchase_generic.lua` -- `for i = 2 , #itemList, 2` with
   `itemList[i - 1]` as the NEW item and `itemList[i]` as the one sold.  If a
   future edit turns that table into a flat "sell these" list, every finding
   below silently changes meaning, so the header is an assertion.

2. THE CRITERIA, ON SYNTHETIC INPUT.  A census over a repaired tree never
   exercises its own positive path: the criterion branch and the report branch
   both stop being reachable, and a mutation that loosens either escapes green
   (hero charter §24, learned the hard way on
   `tests/test_dup_component_buylist_census.lua`).  So `q1..q5` and
   `reachable_items` are each fed a hand-built offender AND a near-miss.

   Per §24's correction, ask first whether the tree carries a legal-but-adjacent
   shape that a loosened criterion would swallow.  Here it does: the global
   `Item['sSellList']` is full of pairs that are unreachable for any one hero
   BY DESIGN (445 of them for the focus five alone), which is exactly why Q5 is
   scoped to each hero's own list.  So the loosening direction has a live
   counterexample and only the SILENT direction needs synthetic feeding -- both
   are fed anyway, because the counterexample is one filter away from being
   edited out.

3. A RATCHET ON THE FOCUS FIVE.  The registered findings are frozen.  A buy-list
   edit that orphans a sell rule (or a sell rule added for an item the build
   never reaches) turns this red instead of adding one more silent no-op.
   Repairs are welcome -- they just have to edit the baseline DOWN.

WHAT IS NOT CLAIMED
-------------------
Reachability walks the DECLARED buy list, so it is an UPPER BOUND on a real
inventory (GH #136/#139: WK's declared list contains a magic wand's parts and
40/40 games ended without the wand).  Unreachable is a proof that the rule is
dead; reachable proves nothing about a real game.

And a dead sell rule is a NO-OP, not damage.  Nothing here is an argument for
"repairing" one: making a sell fire that never has is a WIDENING, and GH #168
settled that a widening cannot be validated by an "armed looks like baseline"
read.  The value is the drift signal -- each dead rule is a fossil of a build
its own file no longer buys.

Usage:  python3 tests/test_sell_pair_census.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "agent"))
import sell_pair_census as C  # noqa: E402

FAILURES = []


def check(cond, msg):
    if cond:
        print("  ok   %s" % msg)
    else:
        print("  FAIL %s" % msg)
        FAILURES.append(msg)


# --------------------------------------------------------------------------
# 1. the Lua shape everything else depends on
# --------------------------------------------------------------------------

def test_pair_loop_shape():
    print("[shape] SetPairedItems still reads (new, old) pairs")
    src = open(os.path.join(ROOT, "bots/item_purchase_generic.lua"),
               encoding="utf-8", errors="replace").read()
    body = re.search(r"function SetPairedItems\(itemList\)(.*?)\nend", src, re.S)
    check(body is not None, "SetPairedItems is still there")
    if body is None:
        return
    body = body.group(1)
    check(re.search(r"for\s+i\s*=\s*2\s*,\s*#itemList\s*,\s*2", body) is not None,
          "loop is `for i = 2 , #itemList, 2` (pairs, trailing odd entry unread)")
    check("itemList[i - 1]" in body and "itemList[i]" in body,
          "reads both halves of the pair")
    # The sold slot is the SECOND of the pair.  If this ever flips, every
    # finding in the census reverses, so it is pinned by position and not by
    # trusting the variable names.
    new_at = body.index("itemList[i - 1]")
    old_at = body.index("itemList[i]", new_at)
    sell_at = body.index("ActionImmediate_SellItem")
    nOld_name = re.search(r"local\s+(\w+)\s*=\s*bot:FindItemSlot\(\s*itemList\[i\]\s*\)",
                          body)
    check(nOld_name is not None and sell_at > old_at > new_at,
          "the SECOND item of the pair is the one sold")
    if nOld_name:
        check(re.search(r"ActionImmediate_SellItem\(\s*bot:GetItemInSlot\(\s*%s\s*\)"
                        % nOld_name.group(1), body) is not None,
              "SellItem is handed the slot found for itemList[i]")


# --------------------------------------------------------------------------
# 2. criteria on synthetic input -- offenders and near misses
# --------------------------------------------------------------------------

SYN_KNOWN = {"item_a", "item_b", "item_c", "item_recipe_c", "item_pseudo"}
SYN_RECIPES = {
    "item_c": ["item_a", "item_b", "item_recipe_c"],
    "item_d": ["item_c", "item_c"],
}


def test_criteria_synthetic():
    print("[synthetic] each criterion sees an offender and a near miss")

    # Q1 -- unknown name.
    check(C.q1_unknown(["item_a", "item_nope"], SYN_KNOWN) == ["item_nope"],
          "Q1 reports the name that is in no table")
    check(C.q1_unknown(["item_a", "item_pseudo"], SYN_KNOWN) == [],
          "Q1 near miss: a pseudo-item macro is NOT an unknown name")

    # Q2 -- odd length.  The near miss is the even list one entry longer.
    check(C.q2_odd(["item_a", "item_b", "item_c"]) is True,
          "Q2 reports the 3-entry list")
    check(C.q2_odd(["item_a", "item_b"]) is False,
          "Q2 near miss: a 2-entry list is fine")
    check(C.pairs_of(["item_a", "item_b", "item_c"]) == [("item_a", "item_b")],
          "Q2's premise: the trailing entry really is never paired")

    # Q3 -- self pair.  Near miss: the same name in two DIFFERENT pairs.
    check(C.q3_self([("item_a", "item_a")]) == [("item_a", "item_a")],
          "Q3 reports X selling X")
    check(C.q3_self([("item_a", "item_b"), ("item_c", "item_a")]) == [],
          "Q3 near miss: one name on both sides of two different pairs is fine")

    # Q4 -- old is consumed building new.  Near miss: the reverse direction.
    check(C.transitive_components("item_d", SYN_RECIPES)
          == {"item_c", "item_a", "item_b", "item_recipe_c"},
          "Q4's component closure is transitive")
    check(C.q4_component_dead([("item_c", "item_a")], SYN_RECIPES)
          == [("item_c", "item_a")],
          "Q4 reports selling a component of the thing you just built")
    check(C.q4_component_dead([("item_a", "item_c")], SYN_RECIPES) == [],
          "Q4 near miss: the reverse direction is a live rule")

    # Q5 -- reachability, including the auto-combine the engine performs.
    alias = {"item_pseudo": "item_a"}
    bundle = {"item_kit": ["item_a", "item_b", "item_recipe_c"]}
    held = C.reachable_items(["item_kit"], alias, bundle, SYN_RECIPES)
    check("item_c" in held,
          "reachability auto-combines a completed recipe (kit -> item_c)")
    check("item_a" in held,
          "an item later consumed by an upgrade still counts as once held")
    check("item_d" not in held,
          "reachability near miss: one item_c is not two, so item_d is not held")
    check(C.reachable_items(["item_pseudo"], alias, bundle, SYN_RECIPES)
          == {"item_a"}, "alias names resolve to the real item")
    check([p for p, _n, _o in C.q5_unreachable([("item_c", "item_d")], held)]
          == [("item_c", "item_d")],
          "Q5 reports the pair whose OLD item is unreachable")
    check(C.q5_unreachable([("item_c", "item_a")], held) == [],
          "Q5 near miss: both reachable -> not reported")

    # The report half.  A criterion that finds things and a reporter that stays
    # quiet is the escape §24 is about, so the renderer gets its own input.
    lines = C.report([("Q5-UNREACHABLE", "axe pos_3", "sell item_x when item_y")])
    check(len(lines) == 1 and "Q5-UNREACHABLE" in lines[0]
          and "axe pos_3" in lines[0] and "item_x" in lines[0],
          "report renders tag, label and detail")
    check(C.report([]) == [], "report of nothing is nothing")


# --------------------------------------------------------------------------
# 3. the ratchet
# --------------------------------------------------------------------------

# Registered 2026-08-25.  Each entry is (hero, role, new_item, old_item) for a
# pair in that hero's OWN sell list that the role's declared build cannot make
# both halves of.  Shrinking this set is a repair; growing it is drift.
#
#   axe   pos_3/4/5  -- pos_3 never buys an Abyssal Blade (pos_4 and pos_5 are
#                       assigned `= sRoleItemsBuyList['pos_3']`, so they inherit
#                       it).  pos_1 does, and is correctly absent here.
#   zuus  all five   -- Zeus owns no quelling blade in any build.  He is a
#                       ranged intelligence hero; the blade's creep damage bonus
#                       is the melee one, so not buying it is right and the SELL
#                       rule is the half that is out of date.
#   lion  all five   -- same quelling blade rule, same reason; plus a
#                       "sell Hand of Midas for Octarine" rule for a midas no
#                       Lion build buys.
#   crystal_maiden pos_4 -- her Eul's rule, in the one role whose list has no
#                       Eul's (pos_3 and pos_5 do, and are absent here).
REGISTERED_UNREACHABLE = {
    ("axe", "pos_3", "item_abyssal_blade", "item_magic_wand"),
    ("axe", "pos_4", "item_abyssal_blade", "item_magic_wand"),
    ("axe", "pos_5", "item_abyssal_blade", "item_magic_wand"),
    ("zuus", "pos_1", "item_black_king_bar", "item_quelling_blade"),
    ("zuus", "pos_2", "item_black_king_bar", "item_quelling_blade"),
    ("zuus", "pos_3", "item_black_king_bar", "item_quelling_blade"),
    ("zuus", "pos_4", "item_black_king_bar", "item_quelling_blade"),
    ("zuus", "pos_5", "item_black_king_bar", "item_quelling_blade"),
    ("lion", "pos_1", "item_black_king_bar", "item_quelling_blade"),
    ("lion", "pos_2", "item_black_king_bar", "item_quelling_blade"),
    ("lion", "pos_3", "item_black_king_bar", "item_quelling_blade"),
    ("lion", "pos_4", "item_black_king_bar", "item_quelling_blade"),
    ("lion", "pos_5", "item_black_king_bar", "item_quelling_blade"),
    ("lion", "pos_4", "item_octarine_core", "item_hand_of_midas"),
    ("lion", "pos_5", "item_octarine_core", "item_hand_of_midas"),
    ("crystal_maiden", "pos_4", "item_cyclone", "item_magic_wand"),
}


def focus_unreachable():
    alias, bundle = C.load_lua_item_tables()
    _names, recipes = C.snapshot_items()
    found = set()
    for hero in C.FOCUS:
        path = os.path.join(ROOT, "bots/BotLib/hero_%s.lua" % hero)
        src = C.strip_comments(open(path, encoding="utf-8",
                                    errors="replace").read())
        own = C.table_items(src, r"X\['sSellList'\]") or []
        for role, buy in C.role_buy_lists(path).items():
            held = C.reachable_items(buy, alias, bundle, recipes)
            for p, _hn, _ho in C.q5_unreachable(C.pairs_of(own), held):
                found.add((hero, role, p[0], p[1]))
    return found


def test_focus_ratchet():
    print("[ratchet] focus-five dead sell rules match the register")
    found = focus_unreachable()
    new = found - REGISTERED_UNREACHABLE
    gone = REGISTERED_UNREACHABLE - found
    check(not new, "no NEW dead sell rule: %s" % sorted(new))
    check(not gone,
          "register has no stale entry (repair one -> delete its line): %s"
          % sorted(gone))
    # Every focus hero declares a sell list at all; if one loses it the ratchet
    # above would go quiet for the right-looking reason.
    for hero in C.FOCUS:
        src = C.strip_comments(open(
            os.path.join(ROOT, "bots/BotLib/hero_%s.lua" % hero),
            encoding="utf-8", errors="replace").read())
        own = C.table_items(src, r"X\['sSellList'\]")
        check(own is not None and len(own) >= 2,
              "%s still declares a sell list (len=%s)"
              % (hero, None if own is None else len(own)))
        check(own is not None and not C.q2_odd(own),
              "%s's sell list has an even length" % hero)


# --------------------------------------------------------------------------
# 4. the two global-list facts worth not re-deriving
# --------------------------------------------------------------------------

def test_global_list_facts():
    print("[global] the shared sell list's own dead entries")
    src = C.strip_comments(open(os.path.join(ROOT, "bots/FunLib/aba_item.lua"),
                                encoding="utf-8", errors="replace").read())
    flat = C.table_items(src, r"Item\['sSellList'\]")
    check(flat is not None and not C.q2_odd(flat),
          "the shared list has an even length")
    names, recipes = C.snapshot_items()
    alias, bundle = C.load_lua_item_tables()
    known = names | set(alias) | set(bundle)

    # `item_drum_of_endurance` is not an item name -- the drum is
    # `item_ancient_janggo`, which THIS SAME TABLE spells correctly eight lines
    # earlier ("item_assault", "item_ancient_janggo").  That is the discriminant
    # for oversight-vs-convention the group keeps reaching for: another place in
    # the same file writes it right.
    check(C.q1_unknown(flat, known) == ["item_drum_of_endurance"],
          "exactly one non-item name in the shared list")
    check("item_ancient_janggo" in flat,
          "and the correct spelling is in the same table")

    # But repairing the typo buys NOTHING, and this is the arithmetic why:
    # Boots of Bearing consumes the drum at build time, so the pair is dead a
    # second time over.  Pinned so nobody "fixes" the name expecting behavior.
    check("item_ancient_janggo" in C.transitive_components(
        "item_boots_of_bearing", recipes),
        "renaming the drum would still leave the pair component-dead")

    dead = C.q4_component_dead(C.pairs_of(flat), recipes)
    check(sorted(dead) == [("item_solar_crest", "item_pavise"),
                           ("item_spirit_vessel", "item_urn_of_shadows")],
          "the two component-dead pairs are the registered ones: %s" % sorted(dead))
    check(C.q3_self(C.pairs_of(flat)) == [], "no self-pair in the shared list")


def main():
    test_pair_loop_shape()
    test_criteria_synthetic()
    test_focus_ratchet()
    test_global_list_facts()
    print()
    if FAILURES:
        print("%d failure(s)" % len(FAILURES))
        return 1
    print("all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

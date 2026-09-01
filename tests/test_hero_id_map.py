#!/usr/bin/env python3
"""hero_id_map.py must resolve ids by joining name tables, and must fail loud
rather than resolve one confidently and wrongly.

WHY THIS EXISTS
    The tool's job is to replace an eyeball reading of numeric ids with a
    join.  Every way it can be wrong is quiet:

      * an id looked up in the WRONG table comes back with a real name that
        belongs to something else -- confident, plausible, wrong;
      * a non-hero unit (Lone Druid's Spirit Bear rides in the `heroes` array
        under id 1961) silently counted as an unresolved hero, or worse,
        guessed at;
      * a neutral-item SECTION HEADER carries `ability_id: -1`, and lumping
        those in with genuine misses buries a real one in expected noise;
      * a section dropped upstream shrinks the denominator without failing
        anything.

    None of those crash.  So each is pinned here by number, and the exit code
    is asserted BARE every time (evidence discipline 3: a pipe would return
    tail's status and read a 2 or 3 back as a pass).

HOW IT TESTS
    It drives the REAL script as a subprocess against synthetic name tables it
    writes to a temp dir.  It does not import the resolver and unit-test it in
    isolation -- this repo has a named failure class for tools validated only
    through a reimplementation nobody ships (GH #67).  Synthetic tables (not
    the live feed) are what let the disjointness and header cases exist at
    all: today's real feed has zero id collisions, so a corpus-only test could
    never discriminate the guard from its absence (evidence discipline 2).
"""
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "tools", "patch", "hero_id_map.py")

failures = []
checks = []


def check(cond, msg):
    checks.append(msg)
    if cond:
        print("ok   %s" % msg)
    else:
        print("FAIL %s" % msg)
        failures.append(msg)


def write_sources(d, heroes=None, abilities=None, items=None):
    """Write the three name tables.  Defaults are a minimal but realistic set."""
    heroes = heroes if heroes is not None else [
        {"id": 2, "name": "npc_dota_hero_axe"},
        {"id": 22, "name": "npc_dota_hero_zuus"},
    ]
    abilities = abilities if abilities is not None else [
        {"id": 5008, "name": "axe_battle_hunger"},
        {"id": 1110, "name": "zuus_lightning_hands"},
        {"id": 1348, "name": "lone_druid_spirit_bear_demolish"},
        {"id": 1349, "name": "lone_druid_spirit_bear_entangle"},
    ]
    items = items if items is not None else [
        {"id": 208, "name": "item_abyssal_blade"},
        {"id": 1854, "name": "item_consecrated_wraps"},
    ]
    with open(os.path.join(d, "herolist.json"), "w") as fh:
        json.dump({"result": {"data": {"heroes": heroes}}}, fh)
    with open(os.path.join(d, "abilitylist.json"), "w") as fh:
        json.dump({"result": {"data": {"itemabilities": abilities}}}, fh)
    with open(os.path.join(d, "itemlist.json"), "w") as fh:
        json.dump({"result": {"data": {"itemabilities": items}}}, fh)


def write_notes(d, version, payload):
    payload.setdefault("patch_number", version)
    with open(os.path.join(d, "pn_%s.json" % version), "w") as fh:
        json.dump(payload, fh)


def run(cache_dir, *args):
    """Run the real script BARE and return (exit code, stdout+stderr)."""
    proc = subprocess.Popen(
        [sys.executable, SCRIPT, "--cache-dir", cache_dir] + list(args),
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    out, _ = proc.communicate()
    return proc.returncode, out.decode("utf-8", "replace")


# --------------------------------------------------------------------------
# 1. the happy path: every id joins, exit 0
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99a", {
        "heroes": [{"hero_id": 22, "abilities": [{"ability_id": 1110}]}],
        "items": [{"ability_id": 208}],
        "neutral_items": [],
    })
    rc, out = run(d, "--version", "7.99a")
    check(rc == 0, "all-resolved patch exits 0 (got %d)" % rc)
    check("npc_dota_hero_zuus" in out, "hero 22 resolves to npc_dota_hero_zuus")
    check("zuus_lightning_hands" in out,
          "ability 1110 resolves to zuus_lightning_hands (NOT read off the note text)")
    check("item_abyssal_blade" in out, "item 208 resolves from the ITEM table")
    check("UNKNOWN_TOTAL 0" in out, "unknown total is 0 on the happy path")

# --------------------------------------------------------------------------
# 2. a non-hero unit in the `heroes` array: named UNKNOWN, hinted, never counted
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99b", {
        "heroes": [{"hero_id": 1961,
                    "abilities": [{"ability_id": 1348}, {"ability_id": 1349}]}],
    })
    rc, out = run(d, "--version", "7.99b", "--json")
    check(rc == 3, "an unresolved id makes the run a FINDING, exit 3 (got %d)" % rc)
    res = json.loads(out)
    check(res["counts"]["heroes_resolved"] == 0,
          "an inferred owner does NOT count as resolved")
    check(res["counts"]["heroes_unknown"] == 1, "the non-hero id is counted unknown")
    check(res["heroes"][0]["inferred_owner"] == "lone_druid_spirit_bear",
          "owner prefix inferred from its abilities (got %r)"
          % res["heroes"][0]["inferred_owner"])
    check(res["counts"]["abilities_resolved"] == 2,
          "a non-hero's abilities still resolve normally")

    rc2, out2 = run(d, "--version", "7.99b")
    check(rc2 == 3 and "UNKNOWN_HERO" in out2 and "INFERRED" in out2,
          "text mode labels it UNKNOWN_HERO with the hint marked INFERRED")

# --------------------------------------------------------------------------
# 3. section headers: the FLAG decides, not the -1
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99c", {
        "neutral_items": [
            {"ability_id": -1, "title": "Artifacts", "is_general_note": True},
            {"ability_id": 1854},
        ],
    })
    rc, out = run(d, "--version", "7.99c", "--json")
    res = json.loads(out)
    check(rc == 0, "a flagged header is not a finding: exit 0 (got %d)" % rc)
    check(res["counts"]["items_general"] == 1, "header lands in its own bucket")
    check(res["counts"]["items_unknown"] == 0, "header is NOT counted as unknown")
    check(res["counts"]["items_resolved"] == 1, "the real neutral item still resolves")

with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99d", {"neutral_items": [{"ability_id": -1}]})
    rc, out = run(d, "--version", "7.99d", "--json")
    check(rc == 3, "-1 WITHOUT the flag stays a finding, exit 3 (got %d)" % rc)
    check(json.loads(out)["counts"]["items_unknown"] == 1,
          "-1 without the flag is counted unknown, not waved through")

# The two candidate rules -- "the flag decides" and "the -1 decides" -- agree on
# every entry above, because the unflagged -1 above carries no title and so
# lands in the unknown bucket either way.  They separate only on an entry that
# has one property without the other, and the direction that matters is the one
# where a genuinely unresolvable id gets WAVED THROUGH as a header.  Both are
# synthetic on purpose: the live feed has never filed either shape, so a
# corpus-only test could not tell the two rules apart (evidence discipline 2).
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99d2", {
        # -1 WITH a title but WITHOUT the flag: an id we cannot resolve.
        "neutral_items": [{"ability_id": -1, "title": "Artifacts"}],
    })
    rc, out = run(d, "--version", "7.99d2", "--json")
    c = json.loads(out)["counts"]
    check(rc == 3, "-1 + title but no flag is still a finding, exit 3 (got %d)" % rc)
    check(c["items_unknown"] == 1 and c["items_general"] == 0,
          "a title alone does not make an entry a header (unknown=%d general=%d)"
          % (c["items_unknown"], c["items_general"]))

with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99d3", {
        # flagged header carrying a positive id: still a header, by the flag.
        "neutral_items": [{"ability_id": 7777, "title": "Enchantments",
                           "is_general_note": True}],
    })
    rc, out = run(d, "--version", "7.99d3", "--json")
    c = json.loads(out)["counts"]
    check(rc == 0, "a flagged header with a positive id is not a finding (got %d)" % rc)
    check(c["items_general"] == 1 and c["items_unknown"] == 0,
          "the FLAG classifies it, not the sign of the id (general=%d unknown=%d)"
          % (c["items_general"], c["items_unknown"]))

# --------------------------------------------------------------------------
# 4. the disjointness guard -- the whole reason a cross-table hit stays impossible
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(
        d,
        abilities=[{"id": 208, "name": "some_hero_some_ability"}],
        items=[{"id": 208, "name": "item_abyssal_blade"}],
    )
    write_notes(d, "7.99e", {"items": [{"ability_id": 208}]})
    rc, out = run(d, "--version", "7.99e")
    check(rc == 2, "colliding id spaces are COULD-NOT-RUN, exit 2 (got %d)" % rc)
    check("overlap" in out, "the collision is named, not silently tolerated")
    check("COULD-NOT-RUN" in out and "not a pass" in out,
          "exit 2 says out loud that it is not a pass")

# --------------------------------------------------------------------------
# 5. could-not-run beats both a pass and a finding
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    rc, out = run(d, "--version", "7.99z")
    check(rc == 2, "a missing patch note is exit 2, not 0 and not 3 (got %d)" % rc)

with tempfile.TemporaryDirectory() as d:
    write_sources(d, abilities=[])
    write_notes(d, "7.99f", {"heroes": []})
    rc, out = run(d, "--version", "7.99f")
    check(rc == 2, "an EMPTY id table refuses to certify, exit 2 (got %d)" % rc)
    check("empty" in out, "the empty table is named")

with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    with open(os.path.join(d, "herolist.json"), "w") as fh:
        fh.write("{not json")
    write_notes(d, "7.99g", {"heroes": []})
    rc, out = run(d, "--version", "7.99g")
    check(rc == 2, "unparseable source is exit 2 (got %d)" % rc)

# --------------------------------------------------------------------------
# 6. the balance invariant: every raw entry lands in exactly one bucket
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99h", {
        "heroes": [
            {"hero_id": 2, "abilities": [{"ability_id": 5008}, {"ability_id": 999999}]},
            {"hero_id": 1961, "abilities": []},
        ],
        "items": [{"ability_id": 208}, {"ability_id": 999999}],
        "neutral_items": [{"ability_id": -1, "title": "X", "is_general_note": True}],
    })
    rc, out = run(d, "--version", "7.99h", "--json")
    c = json.loads(out)["counts"]
    check(rc == 3, "mixed run is a finding, exit 3 (got %d)" % rc)
    check(c["heroes_total"] == c["heroes_resolved"] + c["heroes_unknown"],
          "heroes bucket balances (%d vs %d+%d)"
          % (c["heroes_total"], c["heroes_resolved"], c["heroes_unknown"]))
    check(c["abilities_total"] == c["abilities_resolved"] + c["abilities_unknown"],
          "abilities bucket balances")
    check(c["items_total"] == c["items_resolved"] + c["items_unknown"] + c["items_general"],
          "items bucket balances including headers")
    check(c["abilities_unknown"] == 1, "the bogus ability id is counted unknown")
    check(c["items_unknown"] == 1, "the bogus item id is counted unknown")
    check(c["items_total"] == 3, "the header still counts toward the denominator")

# --------------------------------------------------------------------------
# 7. an unresolved ability must never borrow a name from the ITEM table
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    write_notes(d, "7.99i", {
        "heroes": [{"hero_id": 2, "abilities": [{"ability_id": 1854}]}],
    })
    rc, out = run(d, "--version", "7.99i", "--json")
    res = json.loads(out)
    check(rc == 3, "an ability id that only exists as an ITEM is a finding (got %d)" % rc)
    check("item_consecrated_wraps" not in out,
          "the item name is NOT borrowed for an ability slot")
    check(res["counts"]["abilities_unknown"] == 1, "it is reported unknown instead")

# --------------------------------------------------------------------------
# 8. maps mode alone certifies the three tables loaded and are disjoint
# --------------------------------------------------------------------------
with tempfile.TemporaryDirectory() as d:
    write_sources(d)
    rc, out = run(d)
    check(rc == 0, "maps mode with no --version exits 0 (got %d)" % rc)
    check("heroes=2" in out and "abilities=4" in out and "items=2" in out,
          "maps mode prints each table's size")

print("")
print("%d checks, %d failed" % (len(checks), len(failures)))
for msg in failures:
    print("  FAILED: %s" % msg)
sys.exit(1 if failures else 0)

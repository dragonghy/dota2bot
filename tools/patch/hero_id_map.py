#!/usr/bin/env python3
"""hero_id_map.py -- resolve every numeric id in a datafeed patch note to an
internal name, and say out loud when it cannot.

WHY THIS EXISTS
    `iterations/streams/patch_gap_7.41b-e.md` §2 blocks shards P1-P3 on a
    prerequisite: "datafeed 的 hero id 与经典 hero_id 不一定是同一套编号",
    evidenced by entries that looked self-contradictory when read by eye
    (a 7.41e note filed under hero 22 whose mechanic "did not look like Zeus",
    a 7.41c note read as "Treant (19)" / "Bristle (155)").

    The failure mode that warning was guarding against is real and it is
    SILENT: a patch-note summary read against a guessed id mapping edits the
    wrong hero's Lua, and nothing in the pipeline raises a hand.  What the
    warning could NOT do is settle the question -- reading ids by eye is the
    same instrument that produced the doubt.  This script is the other
    instrument: it joins the ids against Valve's own name tables.

    So the deliverable here is not "the mapping is fine".  It is that
    every id in a patch note now comes back either RESOLVED to an internal
    name, or named as UNKNOWN with its own line.  A guess never silently
    passes as a reading.

THE THREE ID SPACES (each needs its own endpoint -- this is the trap)
    heroes          datafeed/herolist        `id` -> npc_dota_hero_*
    hero abilities  datafeed/abilitylist     `id` -> <hero>_<ability>
    items           datafeed/itemlist        `id` -> item_*

    Both ability endpoints return their payload under the key
    `itemabilities`, which is why abilitylist looks like it should contain
    items.  It does not: item ids 208/139 are absent from abilitylist and
    present in itemlist.  Resolving an item id against the ability table
    therefore yields MISSING, not a wrong name -- today.  That safety is a
    measured property of the current feed (0 ids overlap between the two
    tables), not a guarantee, so check_disjoint() asserts it and aborts if it
    ever stops holding.  A collision would resolve an item id to an ability
    name: wrong, confident, and quiet.

NOT ALL hero_id VALUES ARE HEROES
    The `heroes` array of a patch note also carries non-hero units.  7.41e
    files a note under hero_id 1961, which is in no herolist; its ability
    1348 is `lone_druid_spirit_bear_demolish`, i.e. the Spirit Bear.  The
    script reports such an id as UNKNOWN_HERO and, when its abilities agree
    on a prefix, prints that prefix as INFERRED -- labelled, never merged
    into the resolved count.

EXIT CODES (repo convention: 0 clean / 2 could-not-run / 3 findings)
    0  every id in the requested patch note resolved
    2  a source file or patch note was missing/unreadable, or an invariant
       (balance, disjointness) failed -- nothing was certified
    3  the patch note parsed, and at least one id did not resolve
"""
import argparse
import json
import os
import subprocess
import sys

FEED = "https://www.dota2.com/datafeed"
SOURCES = {
    "herolist": "herolist?language=english",
    "abilitylist": "abilitylist?language=english",
    "itemlist": "itemlist?language=english",
}


class CouldNotRun(Exception):
    """Raised for every condition that must exit 2 rather than certify."""


def fetch(url, dest):
    """Download via curl: the container's proxy CA is already wired for it."""
    rc = subprocess.call(
        ["curl", "-sS", "--fail", "--max-time", "60", url, "-o", dest]
    )
    if rc != 0 or not os.path.getsize(dest):
        raise CouldNotRun("fetch failed (curl rc=%d): %s" % (rc, url))


def load_json(path):
    if not os.path.exists(path):
        raise CouldNotRun("missing source file: %s" % path)
    try:
        with open(path) as fh:
            return json.load(fh)
    except ValueError as exc:
        raise CouldNotRun("unparseable JSON in %s: %s" % (path, exc))


def _rows(doc, path_desc):
    """Both ability endpoints nest their rows under result.data.itemabilities."""
    try:
        return doc["result"]["data"]["itemabilities"]
    except (KeyError, TypeError):
        raise CouldNotRun("unexpected shape for %s" % path_desc)


def build_maps(cache_dir):
    heroes_doc = load_json(os.path.join(cache_dir, "herolist.json"))
    try:
        hero_rows = heroes_doc["result"]["data"]["heroes"]
    except (KeyError, TypeError):
        raise CouldNotRun("unexpected shape for herolist")
    heroes = {h["id"]: h["name"] for h in hero_rows}

    abilities = {
        a["id"]: a["name"]
        for a in _rows(load_json(os.path.join(cache_dir, "abilitylist.json")), "abilitylist")
    }
    items = {
        a["id"]: a["name"]
        for a in _rows(load_json(os.path.join(cache_dir, "itemlist.json")), "itemlist")
    }
    if not heroes or not abilities or not items:
        raise CouldNotRun("an id table came back empty; refusing to certify")
    check_disjoint(abilities, items)
    return {"heroes": heroes, "abilities": abilities, "items": items}


def check_disjoint(abilities, items):
    """The ability and item id spaces must not collide -- see module docstring."""
    clash = sorted(set(abilities) & set(items))
    if clash:
        raise CouldNotRun(
            "ability/item id spaces overlap on %d id(s), e.g. %s -- a lookup "
            "could resolve an item to an ability name; refusing to certify"
            % (len(clash), clash[:5])
        )


def resolve_patch(notes, maps):
    """Annotate every id in one patch note.  Every entry lands in exactly one
    bucket, and the caller balances the buckets against the raw counts."""
    out = {
        "patch": notes.get("patch_number"),
        "heroes": [],
        "items": [],
        "neutral_items": [],
        "counts": {},
    }

    for h in notes.get("heroes", []) or []:
        hid = h.get("hero_id")
        ability_names, unknown_abilities = [], []
        for ab in h.get("abilities", []) or []:
            aid = ab.get("ability_id")
            name = maps["abilities"].get(aid)
            if name is None:
                unknown_abilities.append(aid)
            else:
                ability_names.append((aid, name))
        entry = {
            "hero_id": hid,
            "name": maps["heroes"].get(hid),
            "abilities": ability_names,
            "unknown_abilities": unknown_abilities,
            "inferred_owner": None,
        }
        if entry["name"] is None:
            entry["inferred_owner"] = infer_owner(ability_names)
        out["heroes"].append(entry)

    for key, table in (("items", "items"), ("neutral_items", "items")):
        for it in notes.get(key, []) or []:
            iid = it.get("ability_id")
            # A neutral-item section header ("Artifacts", "Enchantments") rides
            # in the same array carrying ability_id -1.  That is not an id we
            # failed to resolve, and lumping it in with real misses would bury
            # a genuine one in expected noise.  The flag decides, not the -1:
            # an id of -1 WITHOUT the flag stays a finding.
            if it.get("is_general_note"):
                out[key].append({"ability_id": iid, "name": None,
                                 "general_note": it.get("title")})
                continue
            out[key].append({"ability_id": iid, "name": maps[table].get(iid),
                             "general_note": None})

    out["counts"] = {
        "heroes_total": len(out["heroes"]),
        "heroes_resolved": sum(1 for e in out["heroes"] if e["name"]),
        "heroes_unknown": sum(1 for e in out["heroes"] if not e["name"]),
        "abilities_total": sum(
            len(e["abilities"]) + len(e["unknown_abilities"]) for e in out["heroes"]
        ),
        "abilities_resolved": sum(len(e["abilities"]) for e in out["heroes"]),
        "abilities_unknown": sum(len(e["unknown_abilities"]) for e in out["heroes"]),
        "items_total": len(out["items"]) + len(out["neutral_items"]),
        "items_resolved": sum(
            1 for e in out["items"] + out["neutral_items"] if e["name"]
        ),
        "items_unknown": sum(
            1 for e in out["items"] + out["neutral_items"]
            if not e["name"] and not e.get("general_note")
        ),
        "items_general": sum(
            1 for e in out["items"] + out["neutral_items"] if e.get("general_note")
        ),
    }
    check_balance(out["counts"])
    return out


def infer_owner(ability_names):
    """A non-hero unit's abilities usually share their owner's prefix.  This is
    a HINT printed as INFERRED; it never counts as resolved."""
    prefixes = set()
    for _, name in ability_names:
        parts = name.split("_")
        for cut in range(len(parts) - 1, 0, -1):
            prefixes.add("_".join(parts[:cut]))
            break
    if len(prefixes) == 1:
        return prefixes.pop()
    if prefixes:
        common = os.path.commonprefix(sorted(prefixes)).rstrip("_")
        return common or None
    return None


def check_balance(counts):
    """Every bucket must account for every raw entry.  A section quietly
    dropped upstream shrinks the denominator without failing anything."""
    for kind in ("heroes", "abilities", "items"):
        total = counts["%s_total" % kind]
        parts = (counts["%s_resolved" % kind] + counts["%s_unknown" % kind]
                 + counts.get("%s_general" % kind, 0))
        if total != parts:
            raise CouldNotRun(
                "%s bucket does not balance: total=%d resolved+unknown=%d"
                % (kind, total, parts)
            )


def render(res, focus=None):
    lines = ["PATCH %s" % res["patch"]]
    c = res["counts"]
    lines.append(
        "COUNTS heroes %d/%d resolved  abilities %d/%d  items %d/%d "
        "(+%d section header(s), not ids)"
        % (
            c["heroes_resolved"], c["heroes_total"],
            c["abilities_resolved"], c["abilities_total"],
            c["items_resolved"], c["items_total"], c["items_general"],
        )
    )
    for e in res["heroes"]:
        if e["name"]:
            if focus and e["name"] not in focus:
                continue
            lines.append("RESOLVED  hero %-5s %s" % (e["hero_id"], e["name"]))
        else:
            hint = e["inferred_owner"]
            lines.append(
                "UNKNOWN_HERO  hero %-5s not in herolist%s"
                % (e["hero_id"], ("  INFERRED owner prefix=%s" % hint) if hint else "")
            )
        for aid, name in e["abilities"]:
            if e["name"] or not focus:
                lines.append("    ability %-6s %s" % (aid, name))
        for aid in e["unknown_abilities"]:
            lines.append("    UNKNOWN_ABILITY %s" % aid)
    if not focus:
        for e in res["items"] + res["neutral_items"]:
            if e["name"]:
                lines.append("RESOLVED  item %-6s %s" % (e["ability_id"], e["name"]))
            elif e.get("general_note"):
                lines.append("SECTION_HEADER  %s (not an id)" % e["general_note"])
            else:
                lines.append("UNKNOWN_ITEM  item %s not in itemlist" % e["ability_id"])
    unknown = c["heroes_unknown"] + c["abilities_unknown"] + c["items_unknown"]
    lines.append("UNKNOWN_TOTAL %d" % unknown)
    return "\n".join(lines), unknown


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--cache-dir", required=True,
                    help="directory holding herolist.json / abilitylist.json / "
                         "itemlist.json / pn_<version>.json")
    ap.add_argument("--version", help="patch version to resolve, e.g. 7.41e")
    ap.add_argument("--fetch", action="store_true",
                    help="download the sources (and the patch note) into --cache-dir first")
    ap.add_argument("--focus", action="store_true",
                    help="print only the five focus heroes' entries")
    ap.add_argument("--json", action="store_true", help="emit the raw resolution as JSON")
    args = ap.parse_args(argv)

    FOCUS = {
        "npc_dota_hero_axe", "npc_dota_hero_zuus", "npc_dota_hero_skeleton_king",
        "npc_dota_hero_lion", "npc_dota_hero_crystal_maiden",
    }

    try:
        if args.fetch:
            if not os.path.isdir(args.cache_dir):
                os.makedirs(args.cache_dir)
            for name, path in SOURCES.items():
                fetch("%s/%s" % (FEED, path),
                      os.path.join(args.cache_dir, "%s.json" % name))
            if args.version:
                fetch(
                    "%s/patchnotes?version=%s&language=english" % (FEED, args.version),
                    os.path.join(args.cache_dir, "pn_%s.json" % args.version),
                )

        maps = build_maps(args.cache_dir)
        if not args.version:
            print("MAPS heroes=%d abilities=%d items=%d  (id spaces disjoint)"
                  % (len(maps["heroes"]), len(maps["abilities"]), len(maps["items"])))
            return 0

        notes = load_json(os.path.join(args.cache_dir, "pn_%s.json" % args.version))
        if not notes.get("patch_number"):
            raise CouldNotRun("pn_%s.json carries no patch_number" % args.version)
        res = resolve_patch(notes, maps)
    except CouldNotRun as exc:
        print("COULD-NOT-RUN: %s" % exc, file=sys.stderr)
        print("COULD-NOT-RUN -- this is not a pass and not a finding.")
        return 2

    if args.json:
        print(json.dumps(res, indent=1, sort_keys=True))
        return 3 if (res["counts"]["heroes_unknown"] + res["counts"]["abilities_unknown"]
                     + res["counts"]["items_unknown"]) else 0

    text, unknown = render(res, FOCUS if args.focus else None)
    print(text)
    return 3 if unknown else 0


if __name__ == "__main__":
    sys.exit(main())

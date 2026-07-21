#!/usr/bin/env python3
"""ReplayScope builder — turn ONE dumped replay timeline into a standalone web page.

Pipeline:
    dumper (behav-dump)  replay.dem  ->  timeline.json          (parse, Go/manta)
    build.py             timeline.json ->  page.html            (this script)

This is the reusable half: a single HTML template (template.html) plus this
transform. It is NOT hand-authored per replay — point it at any timeline.json a
dump produced and it emits a self-contained page (data + hero icons inlined, no
network needed to view). Same template, different game in, different page out.

Usage:
    python3 build.py <timeline.json> [-o out.html] [--tick 1.0]

Input schema (behav-dump output):
    { "game": { "teams": {"npc_dota_hero_<name>": <team 2|3>, ...} },
      "snapshots": [ {"t":float,"hero":"npc_dota_hero_<name>","team":int,
                      "x":float,"y":float,"hp":int,"hp_pct":float,"mp_pct":float,
                      "level":int,
                      # optional (extended dump):
                      "items":[...], "abilities":[...], "vis":[teams]}, ... ],
      # optional (extended dump):
      "buildings": [ {"t":float,"name":str,"team":int,"x":float,"y":float,"alive":bool}, ...],
      "creeps":    [ {"t":float,"team":int,"x":float,"y":float}, ... ],
      "events":    [ ... ] }

Output: compact per-tick schema the renderer consumes (see template.html header).
Position-only dumps (v1) render fully; items/creeps/fog light up automatically
when an extended dump provides them.
"""
import argparse, base64, bisect, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ICON_DIR = os.path.join(HERE, "icons")
ICON_URL = ("https://cdn.cloudflare.steamstatic.com/apps/dota2/images/"
            "dota_react/heroes/icons/{}.png")
# Dota map is a square; fixed bounds keep the canvas undistorted.
BOUNDS = {"min": -8300, "max": 8300}
ANCIENTS = {"radiant": [-7205, -6610], "dire": [7137, 6474]}
DEAD_GAP = 5.0   # seconds without a snapshot => treat hero as dead (forward-fill pos)


def bare(name):
    return name.replace("npc_dota_hero_", "")


def load_icon(hero):
    """Return a data: URI for a hero minimap icon. Uses the committed cache first,
    fetches + caches on a miss (some heroes drop the underscores in the icon file)."""
    path = os.path.join(ICON_DIR, hero + ".png")
    if not os.path.exists(path):
        os.makedirs(ICON_DIR, exist_ok=True)
        for fn in (hero, hero.replace("_", "")):
            try:
                req = urllib.request.Request(ICON_URL.format(fn),
                                             headers={"User-Agent": "replayscope"})
                data = urllib.request.urlopen(req, timeout=15).read()
                if data[:8] == b"\x89PNG\r\n\x1a\n":
                    open(path, "wb").write(data)
                    break
            except Exception:
                continue
    if not os.path.exists(path):
        sys.stderr.write("  (no icon for %s — falls back to initials)\n" % hero)
        return None
    return "data:image/png;base64," + base64.b64encode(open(path, "rb").read()).decode()


ITEM_URL = ("https://cdn.cloudflare.steamstatic.com/apps/dota2/images/"
            "dota_react/items/{}.png")
# dumper item names are class-derived; a few differ from the react icon filename.
ITEM_ALIAS = {"teleport_scroll": "tpscroll", "tpscroll": "tpscroll",
              "empty_bottle": "bottle", "boots_of_speed": "boots"}
ITEM_DIR = os.path.join(HERE, "item_icons")


def load_item_icon(item):
    """data: URI for an item icon (cached in item_icons/, fetched on miss)."""
    path = os.path.join(ITEM_DIR, item + ".png")
    if not os.path.exists(path):
        os.makedirs(ITEM_DIR, exist_ok=True)
        cands = [ITEM_ALIAS.get(item, item), item, item.replace("recipe_", "")]
        for fn in dict.fromkeys(cands):
            try:
                req = urllib.request.Request(ITEM_URL.format(fn),
                                             headers={"User-Agent": "replayscope"})
                data = urllib.request.urlopen(req, timeout=15).read()
                if data[:8] == b"\x89PNG\r\n\x1a\n":
                    open(path, "wb").write(data)
                    break
            except Exception:
                continue
    if not os.path.exists(path):
        return None
    return "data:image/png;base64," + base64.b64encode(open(path, "rb").read()).decode()


# Status modifiers worth surfacing (crowd control + a few notable states), keyed
# by substring -> display label. Auras/buffs/DoTs are intentionally excluded.
CC_KINDS = [("stunned", "Stun"), ("stun", "Stun"), ("bash", "Stun"),
            ("hex", "Hex"), ("root", "Root"), ("ensnare", "Root"),
            ("silence", "Silence"), ("leash", "Root"), ("cyclone", "Cyclone"),
            ("knockback", "Knock"), ("teleporting", "TP"),
            ("slow", "Slow"), ("gale", "Slow"), ("ignite", "Slow")]


def cc_label(modifier):
    m = modifier.lower()
    for key, lab in CC_KINDS:
        if key in m:
            return lab
    return None


def attach_cc(ticks, tl, tick_s):
    """Reconstruct active crowd-control per hero per tick from MODIFIER_ADD/REMOVE
    events. Because the whole replay is parsed, each ADD is matched to its REMOVE,
    so a real countdown ('Stun 1.2s') can be shown at any scrubbed instant."""
    open_iv = {}          # (hero, modifier) -> add_t
    intervals = {}        # hero -> [(start, end, label)]
    for e in tl.get("events", []):
        if not e.get("target_hero"):
            continue
        typ, mod = e.get("type"), e.get("inflictor", "")
        lab = cc_label(mod)
        if lab is None:
            continue
        h = bare(e["target"])
        key = (h, mod)
        if typ == "MODIFIER_ADD":
            open_iv[key] = e["t"]
        elif typ == "MODIFIER_REMOVE" and key in open_iv:
            intervals.setdefault(h, []).append((open_iv.pop(key), e["t"], lab))
    for h, ivs in intervals.items():
        ivs.sort()
    for row in ticks:
        t = row["t"]
        for hero in row["heroes"]:
            ivs = intervals.get(hero["name"])
            if not ivs:
                continue
            active = [(lab, round(end - t, 1)) for (s, end, lab) in ivs if s <= t < end]
            if active:
                # strongest CC first (Stun > others), then most time remaining
                order = {"Stun": 0, "Hex": 1, "Cyclone": 1, "Root": 2, "Silence": 3}
                active.sort(key=lambda a: (order.get(a[0], 9), -a[1]))
                hero["cc"] = [{"k": lab, "r": r} for lab, r in active[:3]]
    return ticks


VISION_R = 1600  # approx sight range used to decide if a TP cast was witnessed


def attach_tp(ticks):
    """Perspective-aware TP-scroll knowledge. hero['tpcd'] is the TRUE remaining
    cooldown; hero['tpk'] lists the teams that actually KNOW it. Own team always
    knows; an enemy team knows only if it witnessed the most recent cast (the
    caster was within sight of one of its live heroes when tpcd jumped to full).
    This mirrors the bot's real information: you only know an enemy TP'd if you
    saw it. Vision is approximate (no fog data), matching the map's radiant/dire
    toggle."""
    names = {h["name"] for tk in ticks for h in tk["heroes"]}
    # per-hero (t, tpcd) series and a quick tick lookup
    casts = {n: [] for n in names}  # name -> [(cast_t, duration, {witness teams})]
    prev = {}
    for tk in ticks:
        t = tk["t"]
        by_team_alive = {2: [], 3: []}
        for h in tk["heroes"]:
            if h["alive"]:
                by_team_alive.setdefault(h["team"], []).append(h)
        for h in tk["heroes"]:
            n, cd = h["name"], h.get("tpcd", 0)
            p = prev.get(n, 0)
            if cd >= 20 and p <= 5:  # tpcd jumped to ~full -> a fresh cast
                witnessed = set()
                for v in (2, 3):
                    if v == h["team"]:
                        continue
                    if any(abs(e["x"] - h["x"]) < VISION_R and abs(e["y"] - h["y"]) < VISION_R
                           and (e["x"] - h["x"]) ** 2 + (e["y"] - h["y"]) ** 2 < VISION_R ** 2
                           for e in by_team_alive.get(v, [])):
                        witnessed.add(v)
                casts[n].append([t, cd, witnessed])
            prev[n] = cd
    # second pass: who knows the cd at each tick
    for tk in ticks:
        t = tk["t"]
        for h in tk["heroes"]:
            cl = casts[h["name"]]
            last = None
            for c in cl:
                if c[0] <= t:
                    last = c
                else:
                    break
            know = {h["team"]}  # own team always knows
            if last is None:
                know |= {2, 3}   # no cast seen yet -> ready is common knowledge
            else:
                know |= last[2]  # teams that witnessed the last cast
            h["tpk"] = sorted(know)
    return ticks


def build_ticks(tl, tick_s):
    teams = {bare(k): v for k, v in tl["game"]["teams"].items()}
    heroes = sorted(teams)
    dur = int(round(max((s["t"] for s in tl["snapshots"]), default=0)))

    # A hero and its illusions share a class name (e.g. Chaos Knight's Phantasm),
    # so multiple entities can report as the same hero at one tick. The real hero
    # is the entity index that persists across the whole game; illusions are
    # short-lived. Keep only the longest-lived index per hero, when idx is present.
    from collections import Counter
    idx_life = {}
    for s in tl["snapshots"]:
        if "idx" in s:
            idx_life.setdefault(bare(s["hero"]), Counter())[s["idx"]] += 1
    canon_idx = {h: c.most_common(1)[0][0] for h, c in idx_life.items()}

    # per-hero sorted (t, record)
    per = {h: [] for h in heroes}
    for s in tl["snapshots"]:
        h = bare(s["hero"])
        if h not in per:
            continue
        if h in canon_idx and "idx" in s and s["idx"] != canon_idx[h]:
            continue  # drop illusion entity
        per[h].append(s)
    for h in per:
        per[h].sort(key=lambda s: s["t"])
    times = {h: [s["t"] for s in per[h]] for h in heroes}

    # Creeps are dumped on a coarser interval than hero snapshots. Group them by
    # their sample tick, then forward-fill so EVERY hero tick shows creeps (else
    # only every Nth frame has them). Team 4 = neutral (rendered a distinct color).
    creeps_by_tick = {}
    for c in tl.get("creeps", []):
        tk = round(c["t"] / tick_s) * tick_s
        creeps_by_tick.setdefault(tk, []).append([round(c["x"]), round(c["y"]), c["team"]])
    creep_keys = sorted(creeps_by_tick)

    # Start at the earliest snapshot (negative during the pre-game prep phase),
    # floored to a tick boundary, so the pre-horn setup is scrubbable.
    start = min((s["t"] for s in tl["snapshots"]), default=0.0)
    start = (int(start // tick_s)) * tick_s

    last_mhp, last_mmp = {}, {}
    ticks = []
    t = start
    while t <= dur + 0.5:
        row = {"t": round(t, 1), "heroes": []}
        for h in heroes:
            arr, ts = per[h], times[h]
            if not arr:
                continue
            j = bisect.bisect_right(ts, t) - 1
            if j < 0:
                j = 0
            s = arr[j]
            hp_pct = s.get("hp_pct") or 0
            # A dead hero keeps emitting snapshots (entity persists) but reports
            # hp_pct==0 until respawn; a long snapshot gap also means dead.
            alive = hp_pct > 0 and (t - s["t"]) <= DEAD_GAP
            if hp_pct > 0 and s.get("hp"):
                last_mhp[h] = int(round(s["hp"] / hp_pct))
            if s.get("max_mp"):
                last_mmp[h] = s["max_mp"]
            mhp = last_mhp.get(h, s.get("hp", 0))
            mmp = last_mmp.get(h, s.get("max_mp", 0))
            hero = {"name": h, "team": teams[h],
                    "x": round(s["x"]), "y": round(s["y"]),
                    "hp": (s.get("hp", 0) if alive else 0), "mhp": mhp,
                    "mp": (s.get("mp", 0) if alive else 0), "mmp": mmp,
                    "lvl": s.get("level", 1), "alive": alive,
                    "tpcd": round(s.get("tp_cd", 0) or 0)}
            if s.get("items"):
                hero["items"] = [bare(x) for x in s["items"]]
            if s.get("vis"):
                hero["vis"] = s["vis"]
            row["heroes"].append(hero)
        # Attach creeps only on their (coarser) sample ticks; the renderer
        # forward-fills to intermediate frames so every tick shows creeps without
        # duplicating the (large) creep arrays into the file.
        ck = round(t / tick_s) * tick_s
        if ck in creeps_by_tick:
            row["creeps"] = creeps_by_tick[ck]
        ticks.append(row)
        t += tick_s
    return heroes, ticks, dur


def build_towers(tl):
    """Collapse the buildings stream into {name,team,x,y,die_t}. Keyed by
    (name, position) because every tower shares the generic name "tower" — keying
    by name alone would merge all 22 into one. die_t = first tick a structure
    reports dead (None if it survives). Ancients are drawn separately (as stars)."""
    seen = {}
    for b in tl.get("buildings", []):
        if b["name"] == "ancient":
            continue
        key = (b["name"], round(b["x"]), round(b["y"]))
        rec = seen.setdefault(key, {"name": b["name"], "team": b["team"],
                                    "x": round(b["x"]), "y": round(b["y"]), "die_t": None})
        if not b.get("alive", True) and rec["die_t"] is None:
            rec["die_t"] = round(b["t"], 1)
    return list(seen.values())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline", help="timeline.json from behav-dump")
    ap.add_argument("-o", "--out", help="output html (default: <timeline>.html)")
    ap.add_argument("--tick", type=float, default=1.0, help="tick seconds (default 1.0)")
    ap.add_argument("--game-id", help="override the game label shown in the header")
    args = ap.parse_args()

    tl = json.load(open(args.timeline))
    heroes, ticks, dur = build_ticks(tl, args.tick)
    attach_cc(ticks, tl, args.tick)
    attach_tp(ticks)
    towers = build_towers(tl)
    has_fog = any(h.get("vis") for tk in ticks for h in tk["heroes"])

    gid = args.game_id or os.path.basename(args.timeline).replace(".timeline.json", "").replace(".json", "")
    tag = "real · v%s" % ("2 vision+items" if (has_fog or towers) else "1 positions")
    data = {
        "meta": {"game_id": "%s (%s)" % (gid, tag), "duration_s": dur,
                 "tick_s": args.tick, "vision": "fog" if has_fog else "approx"},
        "bounds": BOUNDS, "ancients": ANCIENTS, "towers": towers, "ticks": ticks,
    }

    icons = {}
    for h in heroes:
        uri = load_icon(h)
        if uri:
            icons[h] = uri

    # Item icons for every item that appears in the game (readable loadout in the
    # state table). Cached in item_icons/; a miss just omits that icon.
    item_names = set()
    for tk in ticks:
        for h in tk["heroes"]:
            item_names.update(x for x in h.get("items", []) if x)
    item_icons = {}
    for it in sorted(item_names):
        uri = load_item_icon(it)
        if uri:
            item_icons[it] = uri

    tpl = open(os.path.join(HERE, "template.html")).read()
    inject = ("window.__ICONS__=%s;\nwindow.__ITEMS__=%s;\nwindow.__REPLAY__=%s;"
              % (json.dumps(icons), json.dumps(item_icons),
                 json.dumps(data, separators=(",", ":"))))
    if "/*__REPLAYSCOPE_INJECT__*/" not in tpl:
        sys.exit("template.html is missing the /*__REPLAYSCOPE_INJECT__*/ marker")
    html = tpl.replace("/*__REPLAYSCOPE_INJECT__*/", inject)

    out = args.out or (os.path.splitext(args.timeline)[0] + ".html")
    open(out, "w").write(html)
    ccn = sum(1 for tk in ticks for h in tk["heroes"] if h.get("cc"))
    print("heroes: %d  ticks: %d  duration: %ds  towers: %d  fog: %s  icons: %d  item-icons: %d  cc-frames: %d"
          % (len(heroes), len(ticks), dur, len(towers), has_fog, len(icons), len(item_icons), ccn))
    print("wrote %s (%d KB)" % (out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    main()

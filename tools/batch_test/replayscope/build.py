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

    # optional creeps grouped to nearest tick
    creeps_by_tick = {}
    for c in tl.get("creeps", []):
        tk = int(round(c["t"] / tick_s)) * tick_s
        creeps_by_tick.setdefault(tk, []).append([round(c["x"]), round(c["y"]), c["team"]])

    # Start at the earliest snapshot (negative during the pre-game prep phase),
    # floored to a tick boundary, so the pre-horn setup is scrubbable.
    start = min((s["t"] for s in tl["snapshots"]), default=0.0)
    start = (int(start // tick_s)) * tick_s

    last_mhp = {}
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
            mhp = last_mhp.get(h, s.get("hp", 0))
            hero = {"name": h, "team": teams[h],
                    "x": round(s["x"]), "y": round(s["y"]),
                    "hp": (s.get("hp", 0) if alive else 0), "mhp": mhp,
                    "mp": round(s.get("mp_pct", 0), 2), "lvl": s.get("level", 1),
                    "alive": alive}
            if s.get("items"):
                hero["items"] = [bare(x) for x in s["items"]]
            if s.get("vis"):
                hero["vis"] = s["vis"]
            row["heroes"].append(hero)
        ck = int(round(t / tick_s)) * tick_s
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

    tpl = open(os.path.join(HERE, "template.html")).read()
    inject = ("window.__ICONS__=%s;\nwindow.__REPLAY__=%s;"
              % (json.dumps(icons), json.dumps(data, separators=(",", ":"))))
    if "/*__REPLAYSCOPE_INJECT__*/" not in tpl:
        sys.exit("template.html is missing the /*__REPLAYSCOPE_INJECT__*/ marker")
    html = tpl.replace("/*__REPLAYSCOPE_INJECT__*/", inject)

    out = args.out or (os.path.splitext(args.timeline)[0] + ".html")
    open(out, "w").write(html)
    print("heroes: %d  ticks: %d  duration: %ds  towers: %d  fog: %s  icons: %d"
          % (len(heroes), len(ticks), dur, len(towers), has_fog, len(icons)))
    print("wrote %s (%d KB)" % (out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    main()

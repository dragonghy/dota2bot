#!/usr/bin/env python3
"""Frame-by-frame printer for a `stayfield` decision instant.

Charter hard rule: 先逐帧后聚合.  stayfield_domain.py picks WHICH instants are
worth looking at; this prints the instant itself, one snapshot per line, with
every clause of J.IsFieldRegenSituation / J.HasFieldRegenSource / the tpscroll
'撤退:3' branch evaluated on that frame -- so a verdict can name the frame and
say what the bot could actually see.

Usage:
    stayfield_frames.py <timeline.json> --hero lina --t 439.4 [--span 12]
"""
import argparse
import sys

sys.path.insert(0, __import__("os").path.dirname(__file__))
from stayfield_domain import (Game, canon, dist, situation, strict_branch,   # noqa: E402
                              usable_items, has_field_regen_source,
                              HP_LO, HP_HI, RING_U, TOWER_U, DMG_WINDOW_S,
                              DMG_ATTRIB_U)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline")
    ap.add_argument("--hero", required=True)
    ap.add_argument("--t", type=float, required=True)
    ap.add_argument("--span", type=float, default=12.0)
    ap.add_argument("--interval", type=float, default=1.0)
    a = ap.parse_args()

    g = Game(a.timeline, a.interval)
    hero = canon(a.hero)
    if hero not in g.track:
        sys.exit("no such hero in this timeline: %s (have %s)"
                 % (hero, sorted(g.track)))

    print("hero=%s team=%s  window=[%.1f, %.1f]  interval=%.2fs  "
          "copies dropped by idx lock=%d"
          % (hero, g.hero_team[hero], a.t - a.span, a.t + a.span, a.interval,
             g.copies))
    fx = g.fountain[g.hero_team[hero]]
    print("own fountain centroid = (%.0f, %.0f)" % fx)
    print()
    print("%-8s %6s %6s %5s %-16s %8s %8s %-6s %-6s %-6s %s" %
          ("t", "hp", "mp", "lvl", "pos", "d(fnt)", "enemy", "ring", "dmg",
           "tower", "usable items"))
    for s in g.track[hero]:
        if not (a.t - a.span <= s["t"] <= a.t + a.span):
            continue
        near = g.enemies_within(hero, s, 1e9)
        emin = min([d for _, d in near]) if near else None
        ring = "CLEAR" if not g.enemies_within(hero, s, RING_U) else "BLOCK"
        dmgv = "VETO" if g.attributed_danger(hero, s) else "ok"
        tw = "VETO" if g.enemy_tower_within(s, TOWER_U) else "ok"
        mark = ""
        if s["hp_pct"] > 0 and usable_items(s):
            if situation(g, hero, s) and has_field_regen_source(s):
                mark = "  <== SITUATION"
                if strict_branch(g, hero, s):
                    mark = "  <== STRICT (gate should veto the home-TP here)"
        print("%-8.1f %6.3f %6.3f %5d (%6.0f,%6.0f) %8.0f %8s %-6s %-6s %-6s %s%s" %
              (s["t"], s["hp_pct"], s.get("mp_pct", -1), s.get("level", -1),
               s["x"], s["y"], dist(s["x"], s["y"], fx[0], fx[1]),
               ("%.0f" % emin) if emin else "-", ring, dmgv, tw,
               ",".join(usable_items(s)), mark))

    print("\n-- events in window --")
    for e in g_events(a.timeline):
        if not (a.t - a.span <= e["t"] <= a.t + a.span):
            continue
        act, tgt = canon(e.get("actor")), canon(e.get("target"))
        if hero not in (act, tgt):
            continue
        print("  %-8.1f %-16s %-22s actor=%-16s target=%-16s v=%s"
              % (e["t"], e["type"], e.get("inflictor"), act, tgt, e.get("value")))

    print("\n-- clause reference (source constants) --")
    print("  HP band [%.2f, %.2f] | empty ring %.0fu | attributed dmg %.1fs/%.0fu"
          " | enemy tower %.0fu" % (HP_LO, HP_HI, RING_U, DMG_WINDOW_S,
                                    DMG_ATTRIB_U, TOWER_U))


def g_events(path):
    import json
    return json.load(open(path))["events"]


if __name__ == "__main__":
    main()

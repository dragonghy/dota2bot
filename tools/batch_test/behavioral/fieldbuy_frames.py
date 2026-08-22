#!/usr/bin/env python3
"""Frame-by-frame print around one hero/time in one swept game.

Deliberately dumb: it prints what the dump says on every sampled frame in the
window -- hp, the nine item slots, distance to the hero's own fountain, the
nearest enemy hero, the fieldbuy clause values, and every event that lands in
the window.  No verdicts.  The aggregate tools pick the moments; this is what
"逐帧" means for them (charter hard rule: frame by frame FIRST, aggregate second).

Usage:
    fieldbuy_frames.py <sweep_dir> <game> <hero> <t_from> <t_to>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from stayfield_domain import Game, canon, dist, situation, has_field_regen_source
from fieldbuy_domain import domain_frame, is_laning, all_items, exclusive, airtight


def _slots(s):
    """slots 0-5 (drinkable) then | then 6-8 (backpack: a salve here is dead)."""
    it = all_items(s)
    main6 = ",".join(i for i in it[:6] if i) or "-"
    back = ",".join(i for i in it[6:9] if i)
    return main6 + (" | " + back if back else "")


def main():
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    sweep, game, hero, t0, t1 = sys.argv[1], sys.argv[2], canon(sys.argv[3]), \
        float(sys.argv[4]), float(sys.argv[5])
    path = os.path.join(sweep, "timelines", "%s.timeline.json" % game)
    g = Game(path, 1.0)
    tr = g.track.get(hero)
    if not tr:
        sys.exit("no such hero in %s: %s (have %s)"
                 % (game, hero, sorted(g.track)))

    print("game %s   hero %s   team %d   window %.1f..%.1f"
          % (game, hero, g.hero_team[hero], t0, t1))
    print("%-7s %6s %5s %6s %8s %-22s %-52s %s"
          % ("t", "hp", "lvl", "nw", "d(fnt)", "nearest enemy",
             "items 0-5 | backpack", "flags"))
    for s in tr:
        if not (t0 <= s["t"] <= t1):
            continue
        near = g.enemies_within(hero, s, 6000.0)
        near.sort(key=lambda p: p[1])
        ne = "%s %.0f" % (near[0][0][:14], near[0][1]) if near else "none<6000"
        flags = []
        if s["hp_pct"] <= 0 or not any(all_items(s)):
            flags.append("DEAD/EMPTY")
        else:
            if situation(g, hero, s):
                flags.append("SITUATION")
            if has_field_regen_source(s):
                flags.append("hasheal")
            if domain_frame(g, hero, s):
                flags.append("FIELDBUY-DOMAIN")
                if exclusive(s):
                    flags.append("excl")
                if airtight(s):
                    flags.append("AIRTIGHT")
            if is_laning(s):
                flags.append("laning")
        d = g.dist_fountain(s)
        print("%-7.1f %6.3f %5d %6d %8.0f %-22s %-52s %s"
              % (s["t"], s["hp_pct"], s.get("level", 0), s.get("net_worth", 0),
                 d if d is not None else -1, ne,
                 _slots(s),
                 " ".join(flags)))

    print("")
    print("-- events touching %s in the window --" % hero)
    for (h, item), ts in sorted(g.item_use.items()):
        if h != hero:
            continue
        for t in ts:
            if t0 <= t <= t1:
                print("  %-7.1f ITEM     %s" % (t, item))
    for (h, mod), ts in sorted(g.mod_add.items()):
        if h != hero:
            continue
        for t in ts:
            if t0 <= t <= t1:
                print("  %-7.1f MOD_ADD  %s" % (t, mod))
    for (vic, atk), ts in sorted(g.dmg_by.items()):
        if vic != hero:
            continue
        for t in ts:
            if t0 <= t <= t1:
                print("  %-7.1f DAMAGED  by %s" % (t, atk))
    for t in g.deaths.get(hero, ()):
        if t0 <= t <= t1:
            print("  %-7.1f DEATH" % t)


if __name__ == "__main__":
    main()

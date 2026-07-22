#!/usr/bin/env python3
# Find MISSED LANE KILL WINDOWS in dumped timelines: during laning (<= 600s),
# an enemy hero is LOW (<= 40%) with TWO of our heroes close by (core+support
# pattern), and it does NOT die within the next 10s -> a kill window we let go.
# Prints candidate decision instants for make_fixture.py.
import json, math, sys, os

def dist(a,b): return math.hypot(a["x"]-b["x"], a["y"]-b["y"])

for path in sys.argv[1:]:
    d = json.load(open(path))
    teams = d["game"]["teams"]
    snaps = {}
    for s in d["snapshots"]:
        snaps.setdefault(s["hero"], []).append(s)
    deaths = [(e["t"], e["target"]) for e in d["events"]
              if e["type"]=="DEATH" and e.get("target","").startswith("npc_dota_hero_")]
    def died_within(h, t, w):
        return any(dt >= t and dt <= t+w and dh == h for dt, dh in deaths)
    found = []
    seen_until = {}
    for hero, ss in snaps.items():
        ht = teams.get(hero, 0)
        if not ht: continue
        for s in ss:
            t = s["t"]
            if t < 90 or t > 600: continue
            if s["hp"] <= 0 or s["hp_pct"] > 0.40: continue
            if t < seen_until.get(hero, 0): continue
            # two opposing heroes near this low hero
            near = []
            for other, ot in teams.items():
                if ot == ht or ot == 0: continue
                best = None
                for os_ in snaps.get(other, []):
                    if abs(os_["t"]-t) <= 1.0 and os_["hp"] > 0:
                        best = os_; break
                if best and dist(s, best) <= 1200:
                    near.append((other.replace("npc_dota_hero_",""), int(dist(s,best)),
                                 int(best["hp_pct"]*100)))
            if len(near) >= 2 and not died_within(hero, t, 10):
                seen_until[hero] = t + 20  # dedup window
                found.append((t, hero.replace("npc_dota_hero_",""),
                              int(s["hp_pct"]*100), near))
    if found:
        print("### %s" % os.path.basename(path))
        for t, h, hp, near in found[:6]:
            print("  t=%.0f (%d:%02d)  %s at %d%%  attackers-nearby: %s  -> SURVIVED"
                  % (t, int(t)//60, int(t)%60, h, hp, near))

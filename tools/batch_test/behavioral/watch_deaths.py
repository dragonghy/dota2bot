#!/usr/bin/env python3
# "Watch" a dumped replay frame-by-frame around focus-hero deaths and annotate the
# STORY (not a count): where the hero was, who was with it, who killed it, and how
# the fight developed second by second. This is the human-reviewer step.
import json, math, sys, glob, os

FOCUS = {"skeleton_king","zuus","lion","crystal_maiden","axe"}

def load(tl):
    d = json.load(open(tl))
    teams = d["game"]["teams"]
    snaps = {}
    for s in d["snapshots"]:
        snaps.setdefault(s["hero"], []).append(s)
    for h in snaps: snaps[h].sort(key=lambda s: s["t"])
    return d, teams, snaps

def at(snaps, h, t, tol=1.0):
    best = None
    for s in snaps.get(h, []):
        if abs(s["t"]-t) <= tol and (best is None or abs(s["t"]-t) < abs(best["t"]-t)):
            best = s
    return best

def dist(a, b): return math.hypot(a["x"]-b["x"], a["y"]-b["y"])

ANC = {2: (-7205, -6610), 3: (7137, 6474)}  # radiant, dire ancient coords
def depth_enemy_half(team, x, y):
    # Unambiguous: (dist to OWN ancient) - (dist to ENEMY ancient).
    # >0 => closer to the enemy base than our own => overextended into enemy half.
    own = ANC[team]; enemy = ANC[2 if team == 3 else 3]
    d_own = math.hypot(x-own[0], y-own[1])
    d_en  = math.hypot(x-enemy[0], y-enemy[1])
    return d_own - d_en

def watch_death(d, teams, snaps, victim, t_death, killer):
    vt = teams.get(victim, 0)
    rows = []
    ally_hist = {}   # ally -> list of (t, dist) to see who left
    for tt in range(int(t_death)-11, int(t_death)+2):
        w = at(snaps, victim, tt)
        if not w: continue
        dep = depth_enemy_half(vt, w["x"], w["y"])
        allies, enemies = [], []
        for h, tm in teams.items():
            if h == victim: continue
            s = at(snaps, h, tt)
            if not s or s["hp"] <= 0: continue
            dd = dist(w, s)
            if dd <= 1700:
                nm = h.replace("npc_dota_hero_","")[:8]
                (allies if tm == vt else enemies).append((nm, int(dd)))
        rows.append((tt, int(w["hp_pct"]*100), int(dep), allies, enemies))
    return rows

def classify(rows, t_death):
    if not rows: return "no-data"
    tags = []
    depths = [r[2] for r in rows]
    max_depth = max(depths)
    # overextend: deep in enemy half at any point in the run-up
    if max_depth > 2500: tags.append("DEEP-in-enemy-half(+%d)" % max_depth)
    elif max_depth > 0: tags.append("slightly-past-mid(+%d)" % max_depth)
    else: tags.append("own-half")
    # burst: hp dropped >40% in <=3s
    for i in range(len(rows)-1):
        for j in range(i+1, min(i+4, len(rows))):
            if rows[i][1] - rows[j][1] >= 45:
                tags.append("BURST(%d%%->%d%% in %ds)" % (rows[i][1], rows[j][1], rows[j][0]-rows[i][0]))
                break
        else: continue
        break
    # support-bail: an ally present early (first third) but gone in last 2 rows
    early_allies = set(n for r in rows[:len(rows)//2] for (n,_) in r[3])
    late_allies = set(n for r in rows[-2:] for (n,_) in r[3])
    bailed = early_allies - late_allies
    if bailed and early_allies: tags.append("ALLY-LEFT(%s)" % ",".join(sorted(bailed)))
    # numbers at the moment hp first crossed 60%
    for r in rows:
        if r[1] <= 60:
            tags.append("%dv%d-when-committed" % (len(r[3])+1, len(r[4])))
            break
    return " | ".join(tags)

def main():
    tls = sys.argv[1:]
    for tl in tls:
        d, teams, snaps = load(tl)
        deaths = [(e["t"], e["target"], e.get("actor","?"))
                  for e in d["events"]
                  if e["type"]=="DEATH" and e.get("target","").startswith("npc_dota_hero_")
                  and e["target"].replace("npc_dota_hero_","") in FOCUS]
        if not deaths: continue
        print("\n############ %s ############" % os.path.basename(tl))
        for t, v, k in sorted(deaths):
            vn = v.replace("npc_dota_hero_","")
            kn = k.replace("npc_dota_hero_","")
            rows = watch_death(d, teams, snaps, v, t, k)
            print("\n=== %s died %d:%02d to %s === %s" %
                  (vn, int(t)//60, int(t)%60, kn, classify(rows, t)))
            for (tt, hp, dep, al, en) in rows:
                als = ",".join("%s:%d"%(n,dd) for n,dd in al) or "NONE"
                ens = ",".join("%s:%d"%(n,dd) for n,dd in en) or "none"
                print("  %d:%02d %3d%% d%+5d | %-26s | %s" % (tt//60, tt%60, hp, dep, als, ens))

if __name__ == "__main__":
    main()

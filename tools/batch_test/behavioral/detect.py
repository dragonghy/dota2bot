#!/usr/bin/env python3
"""Behavioral bug detectors over a replay timeline (dumper/main.go output).

Each detector is a pure function over the {snapshots, events} timeline and emits
concrete, timestamped findings matching a bug class from
iterations/0009-laning-bugs/bug_queue.md. This is our automated substitute for
the owner watching .dem replays by hand.

Usage:
    detect.py timeline.json [--json findings.json]

Detectors implemented (bug_queue letter in brackets):
  D1 tp_under_threat     [A] TP channel started with an enemy hero on your face
  D2 tp_home_wasteful    [A] low-HP TP with no enemy near (should regen in lane)
  D3 skywrath_solo_silence [G] Ancient Seal cast with no follow-up burst
  D4 idle_while_ally_dies  [F] stood within range of a dying ally, did nothing
  D5 sandwiched_walk       [F] walked between 2+ enemies and got beaten
  D6 overextend_alone      [6] solo-walked deep into enemy territory, no ally
                               near, enemies present (the aegis/lead feed loop)
  D7 unpunished_tower_dive [P] enemy dove our tower with the numbers on us, no kill
"""
import argparse
import bisect
import json
import math
import sys
from collections import defaultdict

# --- tunables (Dota world units; ranges are generous to stay high-precision) ---
THREAT_RADIUS = 700.0      # "enemy on your face"
TP_CHANNEL_SEC = 3.0       # TP scroll channel time; <2.9s observed => interrupted
WASTE_HP_PCT = 0.55        # "low HP" threshold for wasteful-TP
SAFE_RADIUS = 1400.0       # no enemy within this => not in danger
FOLLOWUP_SEC = 4.0         # window for a silence follow-up
PARTICIPATE_RADIUS = 1500.0
SANDWICH_RADIUS = 750.0
SANDWICH_WINDOW = 4.0
TOWER_DIVE_RADIUS = 1400.0   # defenders "nearby" enough to collapse on a diver
PUNISH_WINDOW = 6.0          # window after the dive to look for the kill
TOWER_DIVE_DEDUP = 8.0       # one finding per diver per this many seconds


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


class Timeline:
    def __init__(self, d):
        self.teams = d["game"]["teams"]
        self.events = sorted(d["events"], key=lambda e: e["t"])
        # per-hero sorted snapshots for nearest-time lookup
        self.snaps = defaultdict(list)
        for s in d["snapshots"]:
            self.snaps[s["hero"]].append(s)
        for h in self.snaps:
            self.snaps[h].sort(key=lambda s: s["t"])
            self._t_index = None
        self._times = {h: [s["t"] for s in v] for h, v in self.snaps.items()}
        self.heroes = list(self.teams.keys())

    def team(self, hero):
        return self.teams.get(hero, 0)

    def enemies_of(self, hero):
        t = self.team(hero)
        return [h for h in self.heroes if self.team(h) != t and t]

    def state_at(self, hero, t, tol=2.0):
        """Nearest snapshot for hero within tol seconds, else None."""
        times = self._times.get(hero)
        if not times:
            return None
        i = bisect.bisect_left(times, t)
        best = None
        for j in (i - 1, i, i + 1):
            if 0 <= j < len(times):
                dt = abs(times[j] - t)
                if dt <= tol and (best is None or dt < best[0]):
                    best = (dt, self.snaps[hero][j])
        return best[1] if best else None

    def pos(self, hero, t, tol=2.0):
        s = self.state_at(hero, t, tol)
        return (s["x"], s["y"]) if s else None

    def alive_at(self, hero, t, tol=2.0):
        s = self.state_at(hero, t, tol)
        return bool(s and s["hp"] > 0)

    def nearest_enemy(self, hero, t):
        p = self.pos(hero, t)
        if not p:
            return None
        best = None
        for e in self.enemies_of(hero):
            if not self.alive_at(e, t):
                continue
            ep = self.pos(e, t)
            if not ep:
                continue
            dd = dist(p, ep)
            if best is None or dd < best[1]:
                best = (e, dd, ep)
        return best


def _tp_channels(tl):
    """Match each teleporting ADD with the next REMOVE for the same hero."""
    adds = defaultdict(list)
    outs = []
    for e in tl.events:
        if e["inflictor"] != "modifier_teleporting":
            continue
        if e["type"] == "MODIFIER_ADD":
            adds[e["target"]].append(e["t"])
        elif e["type"] == "MODIFIER_REMOVE":
            hero = e["target"]
            if adds[hero]:
                start = adds[hero].pop(0)
                outs.append((hero, start, e["t"] - start))
    for hero, starts in adds.items():
        for s in starts:
            outs.append((hero, s, None))  # never resolved (game ended mid-channel)
    return sorted(outs, key=lambda x: x[1])


def d1_tp_under_threat(tl):
    out = []
    for hero, t, dur in _tp_channels(tl):
        s0 = tl.state_at(hero, t)
        if not s0 or s0["hp"] <= 0:
            continue  # dead hero (respawn/fountain TP artifact), not a laning bug
        ne = tl.nearest_enemy(hero, t)
        if not ne or ne[1] > THREAT_RADIUS:
            continue
        enemy, dd, _ = ne
        s = tl.state_at(hero, t)
        hp = s["hp_pct"] if s else None
        interrupted = dur is not None and dur < TP_CHANNEL_SEC - 0.1
        out.append({
            "detector": "tp_under_threat", "bug": "A", "hero": hero, "t": round(t, 1),
            "enemy": enemy, "enemy_dist": round(dd), "hp_pct": hp,
            "channel_dur": None if dur is None else round(dur, 1),
            "interrupted": interrupted,
            "desc": f"{hero} channeled TP at t={t:.0f}s ({fmt(t)}) with {enemy} "
                    f"within {dd:.0f}u, hp={pct(hp)}"
                    + (f" -> channel INTERRUPTED after {dur:.1f}s (wasted TP)" if interrupted
                       else " -> TP-under-threat"),
        })
    return out


def d2_tp_home_wasteful(tl):
    out = []
    for hero, t, dur in _tp_channels(tl):
        s = tl.state_at(hero, t)
        if not s or s["hp"] <= 0 or not (0 < s["hp_pct"] < WASTE_HP_PCT):
            continue  # must be alive and genuinely low (dead => respawn artifact)
        ne = tl.nearest_enemy(hero, t)
        if ne and ne[1] < SAFE_RADIUS:
            continue  # actually in danger -> that's D1, not wasteful
        near = f"{ne[0]} {ne[1]:.0f}u away" if ne else "no enemy tracked"
        out.append({
            "detector": "tp_home_wasteful", "bug": "A", "hero": hero, "t": round(t, 1),
            "hp_pct": s["hp_pct"], "nearest_enemy": near,
            "desc": f"{hero} TP'd at t={t:.0f}s ({fmt(t)}) at low hp={pct(s['hp_pct'])} "
                    f"while NOT in danger ({near}) -> should regen in lane, not TP home",
        })
    return out


def d3_skywrath_solo_silence(tl):
    out = []
    SIL = "skywrath_mage_ancient_seal"
    BURST = {"skywrath_mage_arcane_bolt", "skywrath_mage_concussive_shot",
             "skywrath_mage_mystic_flare"}
    casts = [e for e in tl.events if e["type"] == "ABILITY" and e["inflictor"] == SIL]
    for c in casts:
        t, tgt = c["t"], c["target"]
        followup = False
        for e in tl.events:
            if e["t"] < t or e["t"] > t + FOLLOWUP_SEC:
                continue
            if e["actor"] != "npc_dota_hero_skywrath_mage":
                continue
            if e["type"] == "ABILITY" and e["inflictor"] in BURST:
                followup = True
                break
            if e["type"] == "DAMAGE" and e.get("target_hero") and \
                    (tgt in ("dota_unknown", "", e["target"])):
                followup = True
                break
        if not followup:
            out.append({
                "detector": "skywrath_solo_silence", "bug": "G",
                "hero": "npc_dota_hero_skywrath_mage", "t": round(t, 1),
                "target": tgt,
                "desc": f"Skywrath cast Ancient Seal (silence) at t={t:.0f}s ({fmt(t)}) "
                        f"on {tgt} with NO follow-up burst within {FOLLOWUP_SEC:.0f}s "
                        f"-> solo silence is wasted",
            })
    return out


def d4_idle_while_ally_dies(tl):
    out = []
    deaths = [e for e in tl.events if e["type"] == "DEATH" and e.get("target_hero")
              and e["target"].startswith("npc_dota_hero_")]
    for dth in deaths:
        victim, t = dth["target"], dth["t"]
        vteam = tl.team(victim)
        vp = tl.pos(victim, t)
        if not vp:
            continue
        for ally in tl.heroes:
            if ally == victim or tl.team(ally) != vteam:
                continue
            if not tl.alive_at(ally, t):
                continue
            ap = tl.pos(ally, t)
            if not ap or dist(vp, ap) > PARTICIPATE_RADIUS:
                continue
            # did the ally act in [t-5, t+2]? (dealt hero damage or cast an ability)
            acted = False
            for e in tl.events:
                if e["t"] < t - 5 or e["t"] > t + 2:
                    continue
                if e["actor"] != ally:
                    continue
                if e["type"] == "ABILITY":
                    acted = True
                    break
                if e["type"] == "DAMAGE" and e.get("target_hero"):
                    acted = True
                    break
            if not acted:
                out.append({
                    "detector": "idle_while_ally_dies", "bug": "F",
                    "hero": ally, "t": round(t, 1), "dying_ally": victim,
                    "dist": round(dist(vp, ap)),
                    "desc": f"{ally} stood {dist(vp, ap):.0f}u from {victim} as it died "
                            f"at t={t:.0f}s ({fmt(t)}) but cast/attacked nothing in the "
                            f"fight window -> no teamfight participation",
                })
    return out


def d5_sandwiched_walk(tl):
    out = []
    # group hero-on-hero damage taken per victim into 4s windows
    dmg = [e for e in tl.events if e["type"] == "DAMAGE" and e.get("actor_hero")
           and e.get("target_hero") and e["actor"].startswith("npc_dota_hero_")
           and e["target"].startswith("npc_dota_hero_")]
    by_victim = defaultdict(list)
    for e in dmg:
        by_victim[e["target"]].append(e)
    seen = []
    for victim, evs in by_victim.items():
        evs.sort(key=lambda e: e["t"])
        i = 0
        for i, e in enumerate(evs):
            t = e["t"]
            window = [x for x in evs if t <= x["t"] <= t + SANDWICH_WINDOW]
            vteam = tl.team(victim)
            # only genuine enemies (exclude self-damage / reflect / same team)
            attackers = set(x["actor"] for x in window
                            if x["actor"] != victim and tl.team(x["actor"]) != vteam)
            if len(attackers) < 2:
                continue
            vp = tl.pos(victim, t)
            if not vp:
                continue
            # attackers physically flanking: >=2 within SANDWICH_RADIUS and on
            # opposite sides (vectors from victim have negative dot product)
            close = []
            for a in attackers:
                ap = tl.pos(a, t)
                if ap and dist(vp, ap) <= SANDWICH_RADIUS:
                    close.append((a, ap))
            if len(close) < 2:
                continue
            flanked = False
            for x in range(len(close)):
                for y in range(x + 1, len(close)):
                    v1 = (close[x][1][0] - vp[0], close[x][1][1] - vp[1])
                    v2 = (close[y][1][0] - vp[0], close[y][1][1] - vp[1])
                    if v1[0] * v2[0] + v1[1] * v2[1] < 0:
                        flanked = True
            if not flanked:
                continue
            # de-dup: one finding per victim per ~8s
            if any(v == victim and abs(tt - t) < 8 for v, tt in seen):
                continue
            seen.append((victim, t))
            s = tl.state_at(victim, t)
            out.append({
                "detector": "sandwiched_walk", "bug": "F", "hero": victim,
                "t": round(t, 1), "attackers": sorted(close_names(close)),
                "hp_pct": s["hp_pct"] if s else None,
                "desc": f"{victim} caught between {len(close)} enemies "
                        f"({', '.join(sorted(close_names(close)))}) at t={t:.0f}s "
                        f"({fmt(t)}), hp={pct(s['hp_pct'] if s else None)} "
                        f"-> walked into a flank",
            })
    return out


# --- overextend_alone tunables (Dota world units) ---
# The diagonal river/midline is x+y == 0: Radiant (team 2) base sits at very
# negative x+y (~-13700 at fountain), Dire (team 3) at very positive x+y, so a
# hero is in ENEMY territory when x+y is pushed toward the enemy base. Require a
# margin past the midline so we only flag heroes genuinely deep in, not those
# skirmishing at the river.
OVEREXTEND_MIDLINE_MARGIN = 3000.0   # x+y units past the midline into enemy half
OVEREXTEND_ALONE_RADIUS = 1500.0     # no allied hero within this => "solo"
OVEREXTEND_ENEMY_RADIUS = 1600.0     # an enemy hero within this => genuinely contested
OVEREXTEND_DEDUP_SEC = 8.0           # one finding per hero per continuous stretch


def _enemy_half_depth(team, x, y):
    """How far (in x+y space) the point is INTO enemy territory; <=0 = own half.
    Radiant (2) enemy territory is positive x+y; Dire (3) is mirrored."""
    s = x + y
    if team == 2:
        return s
    if team == 3:
        return -s
    return 0.0


def d6_overextend_alone(tl):
    """Flag a hero deep in enemy territory, alone, with enemies near — the
    'solo-walk into their jungle/triangle' pattern that feeds a lead/aegis.

    LIMITATION: aegis/rune state is NOT present in the replay dump
    (dumper/main.go emits only position/hp/mp/level per hero + combat-log
    events), so the aegis-specific 'solo_dive_with_aegis' variant cannot be
    computed here — this implements the general overextension pattern only (an
    aegis carrier that solo-walks in is still caught by it). If aegis modifier
    state is later added to the dump, add a 'solo_dive_with_aegis' detector that
    filters these findings down to aegis carriers."""
    out = []
    last_flag = {}
    for hero, snaps in tl.snaps.items():
        team = tl.team(hero)
        if not team:
            continue
        for s in snaps:
            if s["hp"] <= 0:
                continue
            t = s["t"]
            depth = _enemy_half_depth(team, s["x"], s["y"])
            if depth < OVEREXTEND_MIDLINE_MARGIN:
                continue  # not deep in enemy territory
            hp = (s["x"], s["y"])
            # solo: no living allied hero within the leash radius
            ally_near = False
            for ally in tl.heroes:
                if ally == hero or tl.team(ally) != team:
                    continue
                if not tl.alive_at(ally, t):
                    continue
                ap = tl.pos(ally, t)
                if ap and dist(hp, ap) <= OVEREXTEND_ALONE_RADIUS:
                    ally_near = True
                    break
            if ally_near:
                continue  # grouped -> fine
            # contested: at least one living enemy hero near-ish
            enemies_near = []
            for e in tl.enemies_of(hero):
                if not tl.alive_at(e, t):
                    continue
                ep = tl.pos(e, t)
                if ep and dist(hp, ep) <= OVEREXTEND_ENEMY_RADIUS:
                    enemies_near.append(e)
            if not enemies_near:
                continue
            # de-dup: one finding per hero per continuous overextension window
            if hero in last_flag and t - last_flag[hero] < OVEREXTEND_DEDUP_SEC:
                last_flag[hero] = t
                continue
            last_flag[hero] = t
            out.append({
                "detector": "overextend_alone", "bug": "6", "hero": hero,
                "t": round(t, 1), "depth": round(depth),
                "enemies_near": sorted(enemies_near),
                "hp_pct": s["hp_pct"],
                "desc": f"{hero} was deep in enemy territory (x+y past midline by "
                        f"{depth:.0f}) ALONE (no ally within "
                        f"{OVEREXTEND_ALONE_RADIUS:.0f}u) with {len(enemies_near)} "
                        f"enemy hero(es) near ({', '.join(sorted(enemies_near))}) "
                        f"at t={t:.0f}s ({fmt(t)}), hp={pct(s['hp_pct'])} "
                        f"-> solo-walked into their jungle/triangle, risks feeding "
                        f"the lead/aegis",
            })
    return out


def _tower_team(actor):
    """Side of a tower from its combat-log unit name: goodguys=Radiant(2),
    badguys=Dire(3). Returns 0 if the actor is not a recognizable tower."""
    if "_tower" not in actor:
        return 0
    if "goodguys" in actor:
        return 2
    if "badguys" in actor:
        return 3
    return 0


def d6_unpunished_tower_dive(tl):
    """[P / issue #7] An enemy hero dives under a team's tower (takes tower
    aggro) while that team has >=2 defenders nearby AND the numbers to kill, yet
    no kill/commit follows -- the over-extension goes unpunished.

    APPROXIMATION (important): the timeline dump carries NO tower entities,
    positions, or aggro table (see dumper/main.go -- only hero snapshots +
    hero-touching combat-log events are recorded). So we approximate "deep under
    our tower" with a tower-damage combat-log event: when a tower shoots an enemy
    hero, that hero is by definition physically inside tower range = diving. The
    tower's side comes from its unit name (goodguys=Radiant/2, badguys=Dire/3);
    the diver is the opposing-team hero it hit. "Had the numbers to kill" =
    >=2 defenders (tower's team) within TOWER_DIVE_RADIUS of the diver AND that
    defender count strictly exceeds the diver's own side present (diver + its
    allies). "Unpunished" = the diver does not die within PUNISH_WINDOW seconds.
    """
    out = []
    hits = []
    for e in tl.events:
        if e["type"] != "DAMAGE" or not e.get("target_hero"):
            continue
        if e.get("actor_hero"):
            continue  # hero damage, not a tower
        tteam = _tower_team(e["actor"])
        if tteam == 0:
            continue
        diver = e["target"]
        if not diver.startswith("npc_dota_hero_"):
            continue
        if tl.team(diver) == tteam or tl.team(diver) == 0:
            continue  # tower hitting its own side (or unknown team) -> ignore
        hits.append((e["t"], diver, tteam))
    hits.sort()

    seen = []
    for t, diver, tteam in hits:
        if any(d == diver and abs(tt - t) < TOWER_DIVE_DEDUP for d, tt in seen):
            continue
        dp = tl.pos(diver, t)
        if not dp:
            continue
        # defenders (tower's team) and the diver's own side, both near the diver
        defenders = []
        diver_side = 0
        for h in tl.heroes:
            if h == diver or not tl.alive_at(h, t):
                continue
            hp = tl.pos(h, t)
            if not hp or dist(dp, hp) > TOWER_DIVE_RADIUS:
                continue
            th = tl.team(h)
            if th == tteam:
                defenders.append(h)
            elif th != 0:
                diver_side += 1  # another enemy hero backing the dive
        # "had the numbers": >=2 defenders AND they outnumber the whole diving
        # group (the diver plus its nearby allies == diver_side + 1).
        if len(defenders) < 2 or len(defenders) < diver_side + 1:
            continue
        # did the diver die within the punish window? that IS a punish -> skip.
        killed = False
        for e in tl.events:
            if e["t"] < t or e["t"] > t + PUNISH_WINDOW:
                continue
            if e["type"] == "DEATH" and e["target"] == diver:
                killed = True
                break
        if killed:
            continue
        seen.append((diver, t))
        s = tl.state_at(diver, t)
        out.append({
            "detector": "unpunished_tower_dive", "bug": "P", "hero": diver,
            "t": round(t, 1), "defender_team": tteam,
            "defenders": sorted(defenders),
            "hp_pct": s["hp_pct"] if s else None,
            "desc": f"{diver} dove team {tteam}'s tower at t={t:.0f}s ({fmt(t)}), "
                    f"hp={pct(s['hp_pct'] if s else None)}, taking tower aggro with "
                    f"{len(defenders)} defenders ({', '.join(sorted(defenders))}) in "
                    f"range vs {diver_side} of its own side -> defenders had the "
                    f"numbers but landed no kill within {PUNISH_WINDOW:.0f}s "
                    f"(unpunished tower dive)",
        })
    return out


def close_names(close):
    return [c[0] for c in close]


def fmt(t):
    return f"{int(t)//60}:{int(t)%60:02d}"


def pct(v):
    return "?" if v is None else f"{v*100:.0f}%"


DETECTORS = [d1_tp_under_threat, d2_tp_home_wasteful, d3_skywrath_solo_silence,
             d4_idle_while_ally_dies, d5_sandwiched_walk,
             d6_overextend_alone, d6_unpunished_tower_dive]


def run(path):
    tl = Timeline(json.load(open(path)))
    findings = []
    for fn in DETECTORS:
        findings.extend(fn(tl))
    findings.sort(key=lambda f: f["t"])
    return findings


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline")
    ap.add_argument("--json", help="write findings JSON here")
    args = ap.parse_args()
    findings = run(args.timeline)

    from collections import Counter
    counts = Counter(f["detector"] for f in findings)
    print(f"=== {len(findings)} behavioral findings in {args.timeline} ===\n")
    for f in findings:
        print(f"[{f['bug']}] {f['desc']}")
    print("\n=== summary by detector ===")
    for k, v in sorted(counts.items()):
        print(f"  {v:3d}  {k}")

    if args.json:
        json.dump(findings, open(args.json, "w"), indent=2)
        print(f"\nwrote {args.json}")


if __name__ == "__main__":
    main()

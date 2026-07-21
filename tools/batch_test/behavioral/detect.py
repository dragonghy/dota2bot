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
  D8 return_to_death_spot  [17] died in the enemy half, respawned, walked
                                straight back to the death spot alone
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

        # Combat-log events name some heroes differently from game.teams /
        # snapshots (e.g. teams 'npc_dota_hero_queen_of_pain' vs event
        # 'npc_dota_hero_queenofpain'; likewise vengeful_spirit/vengefulspirit).
        # Left unfixed this mis-attributes ALL hero-vs-hero damage/deaths for
        # those heroes to nobody (report_card showed QoP 0.00 dmg/min while it
        # dealt 207 hero-damage events). Canonicalize by stripping the prefix +
        # underscores and remap each event's hero actor/target back to the
        # teams-form name so every downstream detector/metric matches.
        def _canon(n):
            return n.replace("npc_dota_hero_", "").replace("_", "").lower() if n else n
        canon2hero = {_canon(h): h for h in self.heroes}
        for e in self.events:
            if e.get("actor_hero"):
                c = canon2hero.get(_canon(e.get("actor")))
                if c:
                    e["actor"] = c
            if e.get("target_hero"):
                c = canon2hero.get(_canon(e.get("target")))
                if c:
                    e["target"] = c

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


# --- return_to_death_spot tunables (Dota world units / seconds) ---
RETURN_WINDOW = 90.0       # seconds after respawn the death spot stays "hot"
RETURN_RADIUS = 1500.0     # back within this of the death spot => "returned"
RETURN_ALLY_RADIUS = 1500.0  # <2 allies within this of the hero => solo return


def d8_return_to_death_spot(tl):
    """[17 / issue #17] The 'respawn -> walk straight back to the death spot ->
    die again' loop (iterations/0011: WK died deep at 6:59, walked back to the
    same corner, died again 7:27). Flag: a hero dies at spot P in the ENEMY
    half (positive _enemy_half_depth); within RETURN_WINDOW seconds after its
    respawn its position comes within RETURN_RADIUS of P while fewer than 2
    living allies are within RETURN_ALLY_RADIUS of it -- a solo return into
    the zone that just killed it. One finding per death (dedup per death)."""
    out = []
    deaths = [e for e in tl.events if e["type"] == "DEATH" and e.get("target_hero")
              and e["target"].startswith("npc_dota_hero_")]
    for dth in deaths:
        hero, t = dth["target"], dth["t"]
        team = tl.team(hero)
        if not team:
            continue
        p = tl.pos(hero, t)
        if not p:
            continue
        depth = _enemy_half_depth(team, p[0], p[1])
        if depth <= 0:
            continue  # died on own half -> going back there is normal play
        snaps = tl.snaps.get(hero, [])
        # respawn = first alive snapshot after the death
        respawn_t = None
        for s in snaps:
            if s["t"] > t and s["hp"] > 0:
                respawn_t = s["t"]
                break
        if respawn_t is None:
            continue  # never respawned (game ended)
        for s in snaps:
            if s["t"] < respawn_t or s["t"] > respawn_t + RETURN_WINDOW:
                continue
            if s["hp"] <= 0:
                break  # died again before returning -> that death gets its own pass
            hp = (s["x"], s["y"])
            dd = dist(hp, p)
            if dd > RETURN_RADIUS:
                continue
            allies_near = []
            for ally in tl.heroes:
                if ally == hero or tl.team(ally) != team:
                    continue
                if not tl.alive_at(ally, s["t"]):
                    continue
                ap = tl.pos(ally, s["t"])
                if ap and dist(hp, ap) <= RETURN_ALLY_RADIUS:
                    allies_near.append(ally)
            if len(allies_near) >= 2:
                continue  # returning with numbers is a regroup, not a repeat feed
            out.append({
                "detector": "return_to_death_spot", "bug": "17", "hero": hero,
                "t": round(s["t"], 1), "death_t": round(t, 1),
                "respawn_t": round(respawn_t, 1), "return_dist": round(dd),
                "depth": round(depth), "allies_near": sorted(allies_near),
                "hp_pct": s["hp_pct"],
                "desc": f"{hero} died at t={t:.0f}s ({fmt(t)}) in the enemy half "
                        f"(depth {depth:.0f}) and walked back to within {dd:.0f}u "
                        f"of the death spot at t={s['t']:.0f}s ({fmt(s['t'])}), "
                        f"{s['t']-respawn_t:.0f}s after respawn, with only "
                        f"{len(allies_near)} ally(ies) near -> respawn-return "
                        f"feed loop",
            })
            break  # one finding per death
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


# --- enemy_overchase_unpunished tunables (Dota world units / seconds) ---
OVERCHASE_DEPTH_MARGIN = 2000.0   # chaser this far into OUR half (x+y) => "deep"
OVERCHASE_VICTIM_HP = 0.45        # the chased ally must be at/under this hp fraction
OVERCHASE_CHASE_RADIUS = 900.0    # chaser within this of the fleeing low ally
OVERCHASE_SOLO_RADIUS = 1400.0    # no living chaser-side ally within this => solo dive
OVERCHASE_COLLAPSE_RADIUS = 1400.0  # our heroes within this could collapse on the chaser
OVERCHASE_DEDUP = 8.0             # one finding per chaser per this many seconds


def d20_enemy_overchase_unpunished(tl):
    """[issue #20] An ENEMY hero over-chases one of our low-HP heroes deep into
    OUR half, separated from its own team, while we have the numbers to turn and
    kill it -- yet it survives (we never collapse). This is the missed
    counter-punish the 'overchase' fix (J.ShouldPunishOverchase) is meant to
    convert into a kill; a candidate side with the fix armed should produce FEWER
    of these findings.

    Sister of d6_unpunished_tower_dive: same 'enemy over-extends, we have the
    numbers, no kill follows' shape, but the trigger is 'chasing our low ally into
    our territory' instead of 'took tower aggro'. Uses only hero snapshots +
    DEATH events (no tower/aggro data needed).

    A finding requires ALL of:
      - chaser is deep in our half (_enemy_half_depth from its own frame >
        OVERCHASE_DEPTH_MARGIN -- i.e. it walked into our territory),
      - a living hero of OURS at/under OVERCHASE_VICTIM_HP within
        OVERCHASE_CHASE_RADIUS of the chaser (the ally being chased),
      - the chaser is SOLO (no living chaser-side ally within OVERCHASE_SOLO_RADIUS
        -- it dove without backup),
      - we have the numbers: >=2 living defenders (our side, incl. the victim)
        within OVERCHASE_COLLAPSE_RADIUS of the chaser,
      - UNPUNISHED: the chaser does not die within PUNISH_WINDOW seconds.
    Dedup per chaser per OVERCHASE_DEDUP seconds.
    """
    out = []
    deaths = [(e["t"], e["target"]) for e in tl.events
              if e["type"] == "DEATH" and e["target"].startswith("npc_dota_hero_")]
    seen = []
    for chaser, snaps in tl.snaps.items():
        ct = tl.team(chaser)
        if not ct:
            continue
        for s in snaps:
            if s["hp"] <= 0:
                continue
            t = s["t"]
            cp = (s["x"], s["y"])
            # deep in our (the chaser's enemy's) half
            if _enemy_half_depth(ct, s["x"], s["y"]) < OVERCHASE_DEPTH_MARGIN:
                continue
            # a low-HP ally of OURS being chased (an enemy hero of the chaser)
            victim, victim_hp = None, None
            for v in tl.heroes:
                if tl.team(v) == ct or tl.team(v) == 0:
                    continue
                if not tl.alive_at(v, t):
                    continue
                vs = tl.state_at(v, t)
                if not vs or vs["hp_pct"] is None or vs["hp_pct"] > OVERCHASE_VICTIM_HP:
                    continue
                vp = (vs["x"], vs["y"])
                if dist(cp, vp) <= OVERCHASE_CHASE_RADIUS:
                    if victim is None or vs["hp_pct"] < victim_hp:
                        victim, victim_hp = v, vs["hp_pct"]
            if victim is None:
                continue
            # chaser must be solo (no living chaser-side ally backing the dive)
            backed = False
            for a in tl.heroes:
                if a == chaser or tl.team(a) != ct or not tl.alive_at(a, t):
                    continue
                ap = tl.pos(a, t)
                if ap and dist(cp, ap) <= OVERCHASE_SOLO_RADIUS:
                    backed = True
                    break
            if backed:
                continue
            # we have the numbers: >=2 of our living heroes OTHER THAN the fleeing
            # victim near the chaser -- real collapse power, not the dying ally
            # itself. The victim being chased cannot be counted on to turn and win.
            defenders = []
            for d in tl.heroes:
                if d == victim or tl.team(d) == ct or tl.team(d) == 0 \
                        or not tl.alive_at(d, t):
                    continue
                dp = tl.pos(d, t)
                if dp and dist(cp, dp) <= OVERCHASE_COLLAPSE_RADIUS:
                    defenders.append(d)
            if len(defenders) < 2:
                continue
            # dedup per chaser
            if any(c == chaser and abs(tt - t) < OVERCHASE_DEDUP for c, tt in seen):
                continue
            # unpunished? chaser must survive the punish window
            if any(dt >= t and dt <= t + PUNISH_WINDOW and dh == chaser
                   for dt, dh in deaths):
                continue
            seen.append((chaser, t))
            out.append({
                "detector": "enemy_overchase_unpunished", "bug": "20",
                "hero": chaser, "t": round(t, 1), "victim": victim,
                "defenders": sorted(defenders), "hp_pct": s["hp_pct"],
                "desc": f"{chaser} over-chased our {victim} "
                        f"(hp={pct(victim_hp)}) into our half at t={t:.0f}s "
                        f"({fmt(t)}), SOLO, with {len(defenders)} of our heroes "
                        f"({', '.join(sorted(defenders))}) in collapse range -> we "
                        f"had the numbers but landed no kill within "
                        f"{PUNISH_WINDOW:.0f}s (unpunished over-chase)",
            })
    return out


def close_names(close):
    return [c[0] for c in close]


def fmt(t):
    return f"{int(t)//60}:{int(t)%60:02d}"


def pct(v):
    return "?" if v is None else f"{v*100:.0f}%"



def d9_missed_cs_at_tower(tl):
    """[replay-review missed-CS / owner's 漏刀 example] Lane creeps dying to a
    TOWER while a core of the tower's team stands nearby and is not last-hitting.
    That is farm burning in front of an idle core -- the sharpest measurable
    slice of "wave crashed, nobody collected".

    Needs the extended dump (lane-creep deaths are kept even for non-hero
    killers); on older dumps this detector finds nothing and stays silent.
    Approximation: no creep positions at death, so "nearby" means the core has
    dealt/received ANY combat-log event within 30s (it is active in a lane, not
    jungling) and killed no creep in the +/-8s around the tower kill. Reported
    aggregated per hero per laning phase, not per creep.
    """
    LANING_END = 10 * 60
    tower_kills = []
    for e in tl.events:
        if e["type"] != "DEATH" or e.get("target_hero"):
            continue
        tgt = e.get("target", "")
        if "creep" not in tgt or "neutral" in tgt:
            continue
        side = _tower_team(e.get("actor", ""))
        if side == 0 or e["t"] > LANING_END:
            continue
        tower_kills.append((e["t"], side))
    if not tower_kills:
        return []
    # per-hero last-hit times (any creep)
    lh = {}
    for e in tl.events:
        if e["type"] == "DEATH" and e.get("actor_hero") and not e.get("target_hero") \
                and "creep" in e.get("target", ""):
            lh.setdefault(e["actor"], []).append(e["t"])
    counts = {}
    for t, side in tower_kills:
        for hero, team in tl.teams.items():
            if team != side or not _is_core(tl, hero):
                continue
            hero_lh = lh.get(hero, [])
            if any(abs(x - t) <= 8 for x in hero_lh):
                continue  # it was busy last-hitting; the tower just won one
            counts[hero] = counts.get(hero, 0) + 1
    out = []
    for hero, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        if n < 8:
            continue  # a few tower kills are normal; flag systematic waste
        out.append({
            "detector": "missed_cs_at_tower", "bug": "misscs", "hero": hero,
            "t": 0, "count": n,
            "desc": "%s: %d lane creeps died to its own team's towers during "
                    "the laning phase while it was not last-hitting (farm "
                    "burning in front of an idle core)" % (hero, n),
        })
    return out


def _is_core(tl, hero):
    """Best-effort core check without role data: the 5 highest last-hit heroes
    per game are treated as cores. Cheap and good enough for aggregation."""
    if not hasattr(tl, "_core_cache"):
        lh = {}
        for e in tl.events:
            if e["type"] == "DEATH" and e.get("actor_hero") \
                    and not e.get("target_hero") and "creep" in e.get("target", ""):
                lh[e["actor"]] = lh.get(e["actor"], 0) + 1
        ranked = sorted(tl.teams, key=lambda h: -lh.get(h, 0))
        tl._core_cache = set(ranked[:6])
    return hero in tl._core_cache

DETECTORS = [d1_tp_under_threat, d2_tp_home_wasteful, d3_skywrath_solo_silence,
             d4_idle_while_ally_dies, d5_sandwiched_walk,
             d6_overextend_alone, d6_unpunished_tower_dive,
             d8_return_to_death_spot, d9_missed_cs_at_tower,
             d20_enemy_overchase_unpunished]


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

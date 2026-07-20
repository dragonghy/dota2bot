#!/usr/bin/env python3
"""Fight storyboards from a replay timeline (dumper/main.go output).

Gives a non-video-capable analysis agent "eyes" on a replay: auto-detects
team-fight windows from the combat log, then renders each fight as a short
sequence of top-down map frames (PNG) showing hero positions, HP, movement
trails, and deaths — the visual context a human gets by scrubbing the .dem.

Fight detection: hero-vs-hero DAMAGE events (plus hero DEATHs) are clustered
greedily in time+space — an event joins an open cluster if it happens within
FIGHT_GAP_SEC of the cluster's last event and within FIGHT_RADIUS of the
cluster's running centroid. Clusters with >= FIGHT_MIN_EVENTS hero-damage
events are fights.

Usage:
    storyboard.py timeline.json --out-dir OUT [--max-fights N]

Outputs:
    OUT/fight_<N>_frame_<K>.png   4-8 frames per fight
    OUT/fights.json               index: id, t range, participants, deaths,
                                  damage per side, frame file list

Dependency-light: stdlib + matplotlib (imported lazily so fight detection can
be reused without it, e.g. by report_card.py).

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from detect import Timeline, dist, fmt  # noqa: E402  (sibling module, no side effects)

# --- fight detection tunables (Dota world units / seconds) ---
FIGHT_MIN_EVENTS = 3     # >= this many hero-vs-hero DAMAGE events => a fight
FIGHT_GAP_SEC = 15.0     # max quiet time inside one fight
FIGHT_RADIUS = 2500.0    # max distance from the fight's running centroid

# --- rendering tunables ---
MIN_FRAMES = 4
MAX_FRAMES = 8
TRAIL_SEC = 3.0          # movement trail length per hero
MAP_MIN, MAP_MAX = -8000.0, 8000.0  # approximate playable coordinate range
ANCIENTS = {2: (-7200.0, -6600.0), 3: (7000.0, 6400.0)}

RADIANT, DIRE = 2, 3
TEAM_NAME = {RADIANT: "radiant", DIRE: "dire"}

# Distinct shades within one color family per team (assigned per hero).
RADIANT_COLORS = ["#1b7a1b", "#2eaf5b", "#0d5c2e", "#55c47a", "#3d8f3d"]
DIRE_COLORS = ["#c62828", "#e2574c", "#8e1b1b", "#f08080", "#a83232"]

SHORT_NAMES = {
    "skeleton_king": "WK", "crystal_maiden": "CM", "wraith_king": "WK",
    "zuus": "Zeus", "witch_doctor": "WD", "death_prophet": "DP",
    "dragon_knight": "DK", "skywrath_mage": "Sky", "centaur": "Cent",
    "necrolyte": "Necro", "windrunner": "WR", "shadow_shaman": "Shaman",
    "queenofpain": "QoP", "antimage": "AM", "phantom_assassin": "PA",
    "templar_assassin": "TA", "faceless_void": "Void", "spirit_breaker": "SB",
    "vengefulspirit": "Venge", "obsidian_destroyer": "OD",
    "keeper_of_the_light": "KotL", "tidehunter": "Tide", "furion": "NP",
    "doom_bringer": "Doom", "nevermore": "SF", "rattletrap": "Clock",
}


def short_name(hero):
    """npc_dota_hero_crystal_maiden -> 'CM'; unknown heroes get a title-cased
    compact name ('Lina', 'Warlock', 'Bounty Hunter' -> 'BountyHunter')."""
    base = hero.replace("npc_dota_hero_", "")
    if base in SHORT_NAMES:
        return SHORT_NAMES[base]
    parts = base.split("_")
    if len(parts) == 1:
        return parts[0].capitalize()
    return "".join(p[:1].upper() + p[1:] for p in parts)


def _event_pos(tl, e):
    """Best-known world position for a combat-log event (victim's, else actor's)."""
    if e.get("target_hero") and e["target"].startswith("npc_dota_hero_"):
        p = tl.pos(e["target"], e["t"])
        if p:
            return p
    if e.get("actor_hero") and e["actor"].startswith("npc_dota_hero_"):
        return tl.pos(e["actor"], e["t"])
    return None


def detect_fights(tl):
    """Cluster hero-vs-hero DAMAGE / hero DEATH events into fight windows.

    Returns a list of fight dicts:
      {id, t_start, t_end, x, y (centroid), participants[], teams{hero:team},
       deaths[{t, hero, killer}], damage{"radiant": n, "dire": n},
       n_damage_events}
    """
    # collect positioned fight-relevant events
    evs = []
    for e in tl.events:
        if e["type"] == "DAMAGE":
            if not (e.get("actor_hero") and e.get("target_hero")
                    and e["actor"].startswith("npc_dota_hero_")
                    and e["target"].startswith("npc_dota_hero_")
                    and e["actor"] != e["target"]
                    and tl.team(e["actor"]) != tl.team(e["target"])):
                continue
        elif e["type"] == "DEATH":
            if not (e.get("target_hero")
                    and e["target"].startswith("npc_dota_hero_")):
                continue
        else:
            continue
        p = _event_pos(tl, e)
        if p:
            evs.append((e["t"], p, e))
    evs.sort(key=lambda x: x[0])

    # greedy time+space clustering
    clusters = []  # each: {"events": [(t,p,e)...], "sx","sy","n"}
    for t, p, e in evs:
        placed = None
        for c in clusters:
            if t - c["events"][-1][0] > FIGHT_GAP_SEC:
                continue
            cx, cy = c["sx"] / c["n"], c["sy"] / c["n"]
            if dist(p, (cx, cy)) <= FIGHT_RADIUS:
                placed = c
                break
        if placed is None:
            placed = {"events": [], "sx": 0.0, "sy": 0.0, "n": 0}
            clusters.append(placed)
        placed["events"].append((t, p, e))
        placed["sx"] += p[0]
        placed["sy"] += p[1]
        placed["n"] += 1

    fights = []
    for c in clusters:
        dmg_evs = [x for x in c["events"] if x[2]["type"] == "DAMAGE"]
        if len(dmg_evs) < FIGHT_MIN_EVENTS:
            continue
        participants = set()
        deaths = []
        damage = {"radiant": 0, "dire": 0}
        for t, _p, e in c["events"]:
            if e["type"] == "DAMAGE":
                participants.add(e["actor"])
                participants.add(e["target"])
                side = TEAM_NAME.get(tl.team(e["actor"]))
                if side:
                    damage[side] += int(e.get("value", 0))
            else:  # DEATH
                participants.add(e["target"])
                deaths.append({"t": round(t, 1), "hero": e["target"],
                               "killer": e["actor"]})
        fights.append({
            "id": len(fights) + 1,
            "t_start": round(c["events"][0][0], 1),
            "t_end": round(c["events"][-1][0], 1),
            "x": round(c["sx"] / c["n"], 1),
            "y": round(c["sy"] / c["n"], 1),
            "participants": sorted(participants),
            "teams": {h: tl.team(h) for h in sorted(participants)},
            "deaths": deaths,
            "damage": damage,
            "n_damage_events": len(dmg_evs),
        })
    return fights


def frame_times(fight):
    """Pick MIN_FRAMES..MAX_FRAMES key ticks: start, every death, end, and
    midpoints of the largest remaining gaps."""
    t0, t1 = fight["t_start"], fight["t_end"]
    times = sorted(set([t0, t1] + [d["t"] for d in fight["deaths"]]))
    while len(times) < MIN_FRAMES:
        gaps = [(times[i + 1] - times[i], i) for i in range(len(times) - 1)]
        g, i = max(gaps)
        if g < 1.0:
            break
        times.insert(i + 1, round((times[i] + times[i + 1]) / 2, 1))
    protected = set([t0, t1] + [d["t"] for d in fight["deaths"]])
    while len(times) > MAX_FRAMES:
        droppable = [t for t in times[1:-1] if t not in protected]
        if not droppable:
            droppable = times[1:-1]  # too many deaths: sacrifice mid ones
        # drop the droppable time with the smallest surrounding gap
        best = min(droppable,
                   key=lambda t: times[times.index(t) + 1] - times[times.index(t) - 1])
        times.remove(best)
    return times


def _death_before(fight, hero, t):
    """Latest death of hero in this fight at or before t (+small epsilon)."""
    best = None
    for d in fight["deaths"]:
        if d["hero"] == hero and d["t"] <= t + 0.25:
            if best is None or d["t"] > best["t"]:
                best = d
    return best


def caption(tl, fight, t):
    """One-line auto-caption for the frame at time t."""
    # a death at (or just before) this frame headlines it
    for d in fight["deaths"]:
        if abs(d["t"] - t) <= 0.6:
            k = d["killer"]
            who = short_name(k) if k.startswith("npc_dota_hero_") else k
            return "%s dies (killed by %s)" % (short_name(d["hero"]), who)
    # otherwise describe the shape of the fight: who is near the fight centroid
    center = (fight["x"], fight["y"])
    near = {RADIANT: [], DIRE: []}
    for h in fight["participants"]:
        if not tl.alive_at(h, t):
            continue
        p = tl.pos(h, t)
        if p and dist(p, center) <= FIGHT_RADIUS:
            near[tl.team(h)].append(h)
    nr, nd = len(near[RADIANT]), len(near[DIRE])
    if nr == 0 and nd == 0:
        return "fight winding down"
    if nr == 0 or nd == 0:
        side = "radiant" if nr else "dire"
        return "%d %s posturing, no contact" % (max(nr, nd), side)
    if nr >= nd + 2 or nd >= nr + 2:
        big_side = RADIANT if nr > nd else DIRE
        small = near[DIRE if big_side == RADIANT else RADIANT]
        # focus target: lowest-HP hero on the outnumbered side
        def hp_of(h):
            s = tl.state_at(h, t)
            return s["hp_pct"] if s else 1.0
        tgt = min(small, key=hp_of)
        return "%d %s collapse on %s" % (max(nr, nd), TEAM_NAME[big_side],
                                         short_name(tgt))
    if nr == nd:
        return "even %dv%d" % (nr, nd)
    return "%dv%d skirmish" % (nr, nd)


def _hero_colors(tl):
    """Deterministic per-hero color, one family per team."""
    colors = {}
    for team, fam in ((RADIANT, RADIANT_COLORS), (DIRE, DIRE_COLORS)):
        members = sorted(h for h in tl.heroes if tl.team(h) == team)
        for i, h in enumerate(members):
            colors[h] = fam[i % len(fam)]
    return colors


def render_frame(tl, fight, t, path, colors, plt):
    fig, ax = plt.subplots(figsize=(7.2, 7.2))
    pad = 500
    ax.set_xlim(MAP_MIN - pad, MAP_MAX + pad)
    ax.set_ylim(MAP_MIN - pad, MAP_MAX + pad)
    ax.set_aspect("equal")

    # faint map frame: playable square, diagonal river x+y=0, ancients
    ax.add_patch(plt.Rectangle((MAP_MIN, MAP_MIN), MAP_MAX - MAP_MIN,
                               MAP_MAX - MAP_MIN, fill=False,
                               edgecolor="#999999", linewidth=0.8, alpha=0.5))
    ax.plot([MAP_MIN, MAP_MAX], [MAP_MAX, MAP_MIN], color="#4a90d9",
            linewidth=1.0, alpha=0.35, linestyle="--")  # river
    for team, (ax_, ay_) in ANCIENTS.items():
        ax.scatter([ax_], [ay_], marker="*", s=220,
                   color="#2eaf5b" if team == RADIANT else "#e2574c",
                   alpha=0.5, zorder=2)
        ax.annotate("%s ancient" % TEAM_NAME[team], (ax_, ay_),
                    textcoords="offset points", xytext=(0, -14),
                    ha="center", fontsize=7, color="#777777", alpha=0.8)

    # stagger label offsets so heroes standing on top of each other stay readable
    label_offsets = [(9, 8), (9, -16), (-64, 8), (-64, -16), (9, 22)]
    participants = set(fight["participants"])
    for hi, hero in enumerate(sorted(tl.heroes)):
        loff = label_offsets[hi % len(label_offsets)]
        color = colors.get(hero, "#555555")
        in_fight = hero in participants
        alpha = 1.0 if in_fight else 0.25
        d = _death_before(fight, hero, t)
        s = tl.state_at(hero, t)
        dead = d is not None or (s is not None and s["hp"] <= 0)
        if dead:
            # X at the death spot
            dpos = None
            if d is not None:
                dpos = tl.pos(hero, d["t"])
            if dpos is None and s is not None:
                dpos = (s["x"], s["y"])
            if dpos is None:
                continue
            ax.scatter([dpos[0]], [dpos[1]], marker="x", s=140, color=color,
                       alpha=alpha, linewidths=2.5, zorder=4)
            ax.annotate("%s (dead)" % short_name(hero), dpos,
                        textcoords="offset points", xytext=loff,
                        fontsize=8, color=color, alpha=alpha)
            continue
        if s is None:
            continue
        pos = (s["x"], s["y"])
        # fading trail over the last TRAIL_SEC seconds + direction arrow
        trail = [ss for ss in tl.snaps.get(hero, [])
                 if t - TRAIL_SEC <= ss["t"] <= t]
        for i in range(1, len(trail)):
            a = 0.15 + 0.55 * (i / max(1, len(trail) - 1))
            ax.plot([trail[i - 1]["x"], trail[i]["x"]],
                    [trail[i - 1]["y"], trail[i]["y"]],
                    color=color, alpha=a * alpha, linewidth=1.6, zorder=3)
        if len(trail) >= 2:
            prev = trail[-2]
            if dist((prev["x"], prev["y"]), pos) > 20:
                ax.annotate("", xy=pos, xytext=(prev["x"], prev["y"]),
                            arrowprops=dict(arrowstyle="->", color=color,
                                            alpha=alpha, lw=1.6), zorder=3)
        hp = s["hp_pct"]
        size = 50 + 170 * max(0.0, min(1.0, hp))  # marker size encodes HP%
        ax.scatter([pos[0]], [pos[1]], s=size, color=color, alpha=alpha,
                   edgecolors="black", linewidths=0.6, zorder=5)
        ax.annotate("%s %d%%" % (short_name(hero), round(hp * 100)), pos,
                    textcoords="offset points", xytext=loff, fontsize=8,
                    color=color, alpha=min(1.0, alpha + 0.15), zorder=6)

    ax.set_title("%s — %s" % (fmt(t), caption(tl, fight, t)), fontsize=11)
    ax.set_xticks([])
    ax.set_yticks([])
    fig.tight_layout()
    fig.savefig(path, dpi=110)
    plt.close(fig)


def render_fight(tl, fight, out_dir, colors, plt):
    files = []
    for k, t in enumerate(frame_times(fight), 1):
        fn = "fight_%d_frame_%d.png" % (fight["id"], k)
        render_frame(tl, fight, t, os.path.join(out_dir, fn), colors, plt)
        files.append(fn)
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("timeline", help="timeline JSON from dumper/main.go")
    ap.add_argument("--out-dir", default="storyboard_out",
                    help="directory for PNG frames + fights.json")
    ap.add_argument("--max-fights", type=int, default=0,
                    help="render at most N fights (0 = all)")
    args = ap.parse_args()

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    with open(args.timeline) as f:
        tl = Timeline(json.load(f))
    fights = detect_fights(tl)
    if args.max_fights > 0:
        fights = fights[:args.max_fights]

    os.makedirs(args.out_dir, exist_ok=True)
    colors = _hero_colors(tl)
    for fight in fights:
        fight["frames"] = render_fight(tl, fight, args.out_dir, colors, plt)
        print("fight %d  %s-%s  %d dmg events, %d death(s): %s" % (
            fight["id"], fmt(fight["t_start"]), fmt(fight["t_end"]),
            fight["n_damage_events"], len(fight["deaths"]),
            ", ".join(short_name(h) for h in fight["participants"])))

    idx_path = os.path.join(args.out_dir, "fights.json")
    with open(idx_path, "w") as f:
        json.dump(fights, f, indent=2)
    print("%d fight(s); wrote %s" % (len(fights), idx_path))


if __name__ == "__main__":
    main()

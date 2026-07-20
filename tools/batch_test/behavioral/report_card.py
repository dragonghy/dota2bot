#!/usr/bin/env python3
"""Per-hero per-game report card from a replay timeline (dumper/main.go output).

Quantitative proxies for a human's replay judgment ("did this hero play well"):

- fight participation: % of team fights (windows from storyboard.detect_fights)
  the hero was within PRESENT_RADIUS of during the window; counts fights where
  the hero was present but had ZERO damage events ("spectator").
- death contexts: each death classified solo_overextend / outnumbered_fight /
  even_fight / unknown from ally proximity, local numbers, map half, and
  nearby enemy-tower damage.
- positioning: mean distance to the (rest-of-)team centroid; % of alive time
  spent in the enemy half of the map (x+y sign vs team).
- activity: hero-vs-hero damage events dealt/received per minute; longest gap
  inside a fight the hero attended without a single damage event of its own
  ("idle-near-fight").

Usage:
    report_card.py timeline.json --out-dir OUT

Outputs:
    OUT/report_<hero>.md      one markdown card per hero
    OUT/report_all.json       every metric, machine-readable
    OUT/SUMMARY.md            heroes ranked by concern score
                              (spectator fights + solo-overextend deaths)

Stdlib only (imports fight detection from storyboard.py; no matplotlib needed).

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from detect import Timeline, dist, fmt, _enemy_half_depth, _tower_team  # noqa: E402
from storyboard import detect_fights, short_name, TEAM_NAME  # noqa: E402

# --- tunables (Dota world units / seconds) ---
PRESENT_RADIUS = 1500.0   # within this of the fight centroid => participated
ALLY_RADIUS = 1500.0      # "alone" = no living ally within this at death
WINDOW_PAD = 2.0          # fight windows padded by this on each side
TOWER_WINDOW = 5.0        # enemy tower damage within this before death => dove
EVEN_MARGIN = 1           # |enemies - (allies+self)| <= this => even fight


def _bare(hero):
    return hero.replace("npc_dota_hero_", "")


def _hero_dmg_events(tl, hero, t0=None, t1=None):
    """Hero-vs-hero DAMAGE events where hero is actor or target, optionally
    restricted to [t0, t1]."""
    out = []
    for e in tl.events:
        if e["type"] != "DAMAGE":
            continue
        if not (e.get("actor_hero") and e.get("target_hero")):
            continue
        if hero not in (e["actor"], e["target"]):
            continue
        if t0 is not None and not (t0 <= e["t"] <= t1):
            continue
        out.append(e)
    return out


def _present_in_fight(tl, hero, fight):
    """True if the hero came within PRESENT_RADIUS of the fight centroid at any
    snapshot inside the (padded) fight window while alive."""
    c = (fight["x"], fight["y"])
    t0 = fight["t_start"] - WINDOW_PAD
    t1 = fight["t_end"] + WINDOW_PAD
    for s in tl.snaps.get(hero, []):
        if t0 <= s["t"] <= t1 and s["hp"] > 0:
            if dist((s["x"], s["y"]), c) <= PRESENT_RADIUS:
                return True
    return False


def _classify_death(tl, hero, t):
    """Classify one death and return (context dict)."""
    team = tl.team(hero)
    p = tl.pos(hero, t)
    allies_near = 0
    enemies_near = 0
    if p:
        for h in tl.heroes:
            if h == hero or not tl.alive_at(h, t):
                continue
            hp = tl.pos(h, t)
            if not hp or dist(p, hp) > ALLY_RADIUS:
                continue
            if tl.team(h) == team:
                allies_near += 1
            else:
                enemies_near += 1
    depth = _enemy_half_depth(team, p[0], p[1]) if p else 0.0
    in_enemy_half = depth > 0

    under_tower = False
    for e in tl.events:
        if e["type"] != "DAMAGE" or e["target"] != hero:
            continue
        if not (t - TOWER_WINDOW <= e["t"] <= t):
            continue
        tt = _tower_team(e["actor"])
        if tt and tt != team:
            under_tower = True
            break

    own_side = allies_near + 1
    if allies_near == 0 and in_enemy_half:
        cls = "solo_overextend"
    elif enemies_near > own_side + (EVEN_MARGIN - 1):
        cls = "outnumbered_fight"
    elif enemies_near > 0 and abs(enemies_near - own_side) <= EVEN_MARGIN:
        cls = "even_fight"
    else:
        cls = "unknown"
    return {
        "t": round(t, 1), "clock": fmt(t), "class": cls,
        "alone": allies_near == 0, "allies_near": allies_near,
        "enemies_near": enemies_near, "in_enemy_half": in_enemy_half,
        "enemy_half_depth": round(depth), "under_enemy_tower": under_tower,
    }


def _positioning(tl, hero):
    """Mean distance to the rest-of-team centroid + %% time in enemy half."""
    team = tl.team(hero)
    dists = []
    in_enemy = 0
    alive_ticks = 0
    for s in tl.snaps.get(hero, []):
        if s["hp"] <= 0:
            continue
        alive_ticks += 1
        if _enemy_half_depth(team, s["x"], s["y"]) > 0:
            in_enemy += 1
        pts = []
        for h in tl.heroes:
            if h == hero or tl.team(h) != team:
                continue
            hs = tl.state_at(h, s["t"])
            if hs and hs["hp"] > 0:
                pts.append((hs["x"], hs["y"]))
        if pts:
            cx = sum(p[0] for p in pts) / len(pts)
            cy = sum(p[1] for p in pts) / len(pts)
            dists.append(dist((s["x"], s["y"]), (cx, cy)))
    return {
        "mean_dist_to_team_centroid": round(sum(dists) / len(dists)) if dists else None,
        "pct_time_enemy_half": round(in_enemy / alive_ticks, 3) if alive_ticks else 0.0,
    }


def _longest_idle_gap(tl, hero, attended):
    """Longest stretch inside an attended fight window with no damage event of
    the hero's own (dealt or received)."""
    worst = 0.0
    where = None
    for fight in attended:
        t0 = fight["t_start"] - WINDOW_PAD
        t1 = fight["t_end"] + WINDOW_PAD
        marks = sorted([t0] + [e["t"] for e in _hero_dmg_events(tl, hero, t0, t1)] + [t1])
        for i in range(len(marks) - 1):
            gap = marks[i + 1] - marks[i]
            if gap > worst:
                worst = gap
                where = fight["id"]
    return round(worst, 1), where


def analyze(tl, fights):
    """Compute the full per-hero report; returns {hero: metrics}."""
    end_t = max((s["t"] for v in tl.snaps.values() for s in v), default=0.0)
    minutes = max(end_t / 60.0, 1e-6)
    out = {}
    for hero in sorted(tl.heroes):
        attended = [f for f in fights if _present_in_fight(tl, hero, f)]
        spectator = []
        for f in attended:
            n = len(_hero_dmg_events(tl, hero, f["t_start"] - WINDOW_PAD,
                                     f["t_end"] + WINDOW_PAD))
            if n == 0:
                spectator.append(f["id"])
        deaths = [_classify_death(tl, hero, e["t"]) for e in tl.events
                  if e["type"] == "DEATH" and e["target"] == hero
                  and e.get("target_hero")]
        dealt = sum(1 for e in _hero_dmg_events(tl, hero) if e["actor"] == hero)
        received = sum(1 for e in _hero_dmg_events(tl, hero) if e["target"] == hero)
        idle_gap, idle_fight = _longest_idle_gap(tl, hero, attended)
        solo_deaths = sum(1 for d in deaths if d["class"] == "solo_overextend")
        m = {
            "hero": hero,
            "team": TEAM_NAME.get(tl.team(hero), "?"),
            "fights_total": len(fights),
            "fights_present": len(attended),
            "fight_participation_pct":
                round(len(attended) / len(fights), 3) if fights else None,
            "spectator_fights": spectator,
            "deaths": deaths,
            "death_classes": {
                c: sum(1 for d in deaths if d["class"] == c)
                for c in ("solo_overextend", "outnumbered_fight",
                          "even_fight", "unknown")},
            "positioning": _positioning(tl, hero),
            "dmg_events_dealt_per_min": round(dealt / minutes, 2),
            "dmg_events_received_per_min": round(received / minutes, 2),
            "longest_idle_near_fight_sec": idle_gap,
            "longest_idle_fight_id": idle_fight,
            # concern = spectator fights + solo-overextend deaths (the two
            # strongest "played badly" proxies)
            "concern_score": len(spectator) + solo_deaths,
        }
        out[hero] = m
    return out


def write_hero_md(m, path):
    h = m["hero"]
    lines = ["# Report card: %s (%s, %s)" % (short_name(h), _bare(h), m["team"]), ""]
    pp = m["fight_participation_pct"]
    lines.append("## Fight participation")
    lines.append("- present in %d/%d team fights (%s)" % (
        m["fights_present"], m["fights_total"],
        "n/a" if pp is None else "%d%%" % round(pp * 100)))
    lines.append("- spectator fights (present, zero damage events): %d%s" % (
        len(m["spectator_fights"]),
        " (fight ids: %s)" % ", ".join(map(str, m["spectator_fights"]))
        if m["spectator_fights"] else ""))
    lines.append("")
    lines.append("## Deaths (%d)" % len(m["deaths"]))
    if not m["deaths"]:
        lines.append("- none")
    for d in m["deaths"]:
        flags = []
        if d["alone"]:
            flags.append("ALONE")
        if d["in_enemy_half"]:
            flags.append("enemy half (depth %d)" % d["enemy_half_depth"])
        if d["under_enemy_tower"]:
            flags.append("under enemy tower")
        lines.append("- t=%s  **%s**  (%d allies / %d enemies within %du%s)" % (
            d["clock"], d["class"], d["allies_near"], d["enemies_near"],
            int(ALLY_RADIUS), ("; " + ", ".join(flags)) if flags else ""))
    lines.append("")
    pos = m["positioning"]
    lines.append("## Positioning")
    lines.append("- mean distance to team centroid: %s" % (
        "n/a" if pos["mean_dist_to_team_centroid"] is None
        else "%du" % pos["mean_dist_to_team_centroid"]))
    lines.append("- time in enemy half: %d%%" % round(pos["pct_time_enemy_half"] * 100))
    lines.append("")
    lines.append("## Activity")
    lines.append("- damage events dealt/min: %.2f, received/min: %.2f" % (
        m["dmg_events_dealt_per_min"], m["dmg_events_received_per_min"]))
    lines.append("- longest idle gap inside an attended fight: %.1fs%s" % (
        m["longest_idle_near_fight_sec"],
        " (fight %d)" % m["longest_idle_fight_id"]
        if m["longest_idle_fight_id"] else ""))
    lines.append("")
    lines.append("**Concern score: %d** (spectator fights + solo-overextend deaths)"
                 % m["concern_score"])
    lines.append("")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def write_summary_md(report, fights, path):
    ranked = sorted(report.values(),
                    key=lambda m: (-m["concern_score"],
                                   m["fight_participation_pct"] or 0.0))
    lines = ["# Behavioral report summary", "",
             "%d team fight(s) detected." % len(fights), "",
             "Heroes ranked most-concerning first "
             "(concern = spectator fights + solo-overextend deaths; "
             "ties broken by lower fight participation).", "",
             "| # | hero | team | concern | fights | spectator | deaths "
             "(solo/outnum/even/unk) | dealt/min |",
             "|---|------|------|---------|--------|-----------|------------------------|-----------|"]
    for i, m in enumerate(ranked, 1):
        dc = m["death_classes"]
        pp = m["fight_participation_pct"]
        lines.append("| %d | %s | %s | %d | %d/%d (%s) | %d | %d/%d/%d/%d | %.2f |" % (
            i, short_name(m["hero"]), m["team"], m["concern_score"],
            m["fights_present"], m["fights_total"],
            "n/a" if pp is None else "%d%%" % round(pp * 100),
            len(m["spectator_fights"]),
            dc["solo_overextend"], dc["outnumbered_fight"],
            dc["even_fight"], dc["unknown"],
            m["dmg_events_dealt_per_min"]))
    lines.append("")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("timeline", help="timeline JSON from dumper/main.go")
    ap.add_argument("--out-dir", default="report_out",
                    help="directory for report_<hero>.md, report_all.json, SUMMARY.md")
    args = ap.parse_args()

    with open(args.timeline) as f:
        tl = Timeline(json.load(f))
    fights = detect_fights(tl)
    report = analyze(tl, fights)

    os.makedirs(args.out_dir, exist_ok=True)
    for hero, m in report.items():
        write_hero_md(m, os.path.join(args.out_dir, "report_%s.md" % _bare(hero)))
    with open(os.path.join(args.out_dir, "report_all.json"), "w") as f:
        json.dump({"fights": fights, "heroes": report}, f, indent=2)
    write_summary_md(report, fights, os.path.join(args.out_dir, "SUMMARY.md"))

    for m in sorted(report.values(), key=lambda m: -m["concern_score"]):
        print("%-28s concern=%d  fights %d/%d  spectator=%d  deaths=%d" % (
            _bare(m["hero"]), m["concern_score"], m["fights_present"],
            m["fights_total"], len(m["spectator_fights"]), len(m["deaths"])))
    print("wrote reports for %d heroes to %s" % (len(report), args.out_dir))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Parse one Dota 2 dedicated-server console log into per-game JSON metrics.

Usage: parse_log.py game_1.log > game_1.json

Calibrated against a real completed headless game (2026-07-19). The engine's
"Match signout" block provides winner, duration, and a full per-player
scoreboard; hero identities come from the PR:SetSelectedHero picks.
"""
import json
import re
import sys

# 07/19 04:22:27 [Server] PR:SetSelectedHero 0:[I:0:0] npc_dota_hero_obsidian_destroyer(76)
RE_PICK = re.compile(r"PR:SetSelectedHero (\d+):\S+ (npc_dota_hero_\w+)\(\d+\)")
# Match signout:  duration = 3381 (3381.966797) Winning team = 1
RE_SIGNOUT = re.compile(r"Match signout:\s+duration = (\d+).*Winning team = (\d+)")
# Building: npc_dota_goodguys_fort destroyed at 3381.933594.  (fallback winner)
RE_FORT = re.compile(r"Building: npc_dota_(goodguys|badguys)_fort destroyed at (\d+(?:\.\d+)?)")
# Team 0 Player 0 m_unAccountID = 0  Items: ...
RE_PLAYER = re.compile(r"Team (\d) Player (\d) m_unAccountID")
RE_KDA = re.compile(r"KDA: (\d+) / (\d+) / (\d+)")
RE_LEVEL = re.compile(r"Level: (\d+) Gold: (\d+)")
RE_LASTHIT = re.compile(r"LastHit = (\d+)\s+Deny = (\d+)")
RE_PERMIN = re.compile(r"XP per min: (\d+)\s+Gold per min: (\d+)")
RE_DAMAGE = re.compile(r"Actual Player Damage: (\d+) Actual Building Damage: (\d+) Actual Healing: (\d+)")
# console timestamps for wall-clock (effective timescale): 07/19 04:22:47
RE_TS = re.compile(r"^(\d\d)/(\d\d) (\d\d):(\d\d):(\d\d) ")
RE_STATE = re.compile(r"entering state 'DOTA_GAMERULES_STATE_(\w+)'")
# Building destruction timeline: "Building: npc_dota_badguys_tower1_top destroyed at 850.36"
RE_BUILDING = re.compile(r"Building: (npc_dota_\w+) destroyed at (\d+(?:\.\d+)?)")
# Lua errors / script perf warnings worth surfacing
RE_SCRIPT_ERR = re.compile(r"(lua|script)[^\n]*error|attempt to (index|call|compare)", re.I)


def wall_seconds(line):
    m = RE_TS.match(line)
    if not m:
        return None
    _mo, _d, h, mi, s = m.groups()
    return int(h) * 3600 + int(mi) * 60 + int(s)


def parse(path):
    result = {
        "log": path,
        "winner": None,           # "radiant" | "dire"
        "winning_team_raw": None, # engine's team index (0=Radiant/good, 1=Dire/bad)
        "duration_s": None,       # game-clock seconds
        "wall_in_progress_s": None,
        "effective_timescale": None,
        "picks": {},              # playerid -> hero
        "players": [],            # per-player scoreboard
        "towers": [],             # [{building, t}] destruction timeline (game seconds)
        "script_errors": [],
        "notes": [],
    }

    in_progress_wall = None
    signout_wall = None
    current_player = None

    with open(path, errors="replace") as f:
        for line in f:
            m = RE_PICK.search(line)
            if m and m.group(2) != "npc_dota_hero_target_dummy":
                pid = int(m.group(1))
                # picks repeat at disconnect with (null); keep first real pick
                result["picks"].setdefault(pid, m.group(2))
                continue

            m = RE_STATE.search(line)
            if m:
                if m.group(1) == "GAME_IN_PROGRESS" and in_progress_wall is None:
                    in_progress_wall = wall_seconds(line)
                continue

            m = RE_SIGNOUT.search(line)
            if m:
                result["duration_s"] = int(m.group(1))
                result["winning_team_raw"] = int(m.group(2))
                result["winner"] = "radiant" if int(m.group(2)) == 0 else "dire"
                signout_wall = wall_seconds(line)
                continue

            m = RE_BUILDING.search(line)
            if m:
                result["towers"].append({"building": m.group(1),
                                         "t": int(float(m.group(2)))})
                # fort destruction also decides the winner if no signout line
                fm = RE_FORT.search(line)
                if fm and result["winner"] is None:
                    result["winner"] = "dire" if fm.group(1) == "goodguys" else "radiant"
                    result["duration_s"] = int(float(fm.group(2)))
                continue

            m = RE_PLAYER.search(line)
            if m:
                current_player = {
                    "team": "radiant" if int(m.group(1)) == 0 else "dire",
                    "team_slot": int(m.group(2)),
                }
                result["players"].append(current_player)
                continue

            if current_player is not None:
                # "Level: 22 Gold: 537  KDA: 5 / 9 / 0" — same line, check both
                m = RE_LEVEL.search(line)
                if m:
                    current_player["level"] = int(m.group(1))
                    current_player["end_gold"] = int(m.group(2))
                m = RE_KDA.search(line)
                if m:
                    current_player["kills"], current_player["deaths"], current_player["assists"] = (
                        int(m.group(1)), int(m.group(2)), int(m.group(3)))
                    continue
                m = RE_LASTHIT.search(line)
                if m:
                    current_player["last_hits"] = int(m.group(1))
                    current_player["denies"] = int(m.group(2))
                    continue
                m = RE_PERMIN.search(line)
                if m:
                    current_player["xpm"] = int(m.group(1))
                    current_player["gpm"] = int(m.group(2))
                    continue
                m = RE_DAMAGE.search(line)
                if m:
                    current_player["hero_damage"] = int(m.group(1))
                    current_player["building_damage"] = int(m.group(2))
                    current_player["healing"] = int(m.group(3))
                    continue

            if (RE_SCRIPT_ERR.search(line) and "[ResourceSystem]" not in line
                    and len(result["script_errors"]) < 50):
                result["script_errors"].append(line.strip()[:300])

    # attach heroes to scoreboard rows: picks use global playerid 0-4 (radiant)
    # and 5-9 (dire); scoreboard uses per-team slots 0-4 in the same order.
    for p in result["players"]:
        gid = p["team_slot"] + (0 if p["team"] == "radiant" else 5)
        p["hero"] = result["picks"].get(gid)

    if in_progress_wall is not None and signout_wall is not None and result["duration_s"]:
        wall = signout_wall - in_progress_wall
        if wall < 0:  # crossed midnight
            wall += 24 * 3600
        result["wall_in_progress_s"] = wall
        if wall > 0:
            result["effective_timescale"] = round(result["duration_s"] / wall, 2)

    if result["winner"] is None:
        result["notes"].append("no winner found — game likely did not finish")
    if not result["players"]:
        result["notes"].append("no Match signout scoreboard — incomplete game or format change")

    # crude mode heuristic until telemetry lands: turbo doubles passive gold
    gpms = [p.get("gpm", 0) for p in result["players"]]
    if gpms and result["duration_s"]:
        avg = sum(gpms) / len(gpms)
        result["avg_gpm"] = round(avg)
        result["mode_guess"] = "turbo" if avg > 800 else "normal"

    return result


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(json.dumps(parse(sys.argv[1]), indent=2))

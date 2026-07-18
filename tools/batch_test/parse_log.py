#!/usr/bin/env python3
"""Parse one Dota 2 dedicated-server console log into per-game JSON metrics.

Usage: parse_log.py game_1.log > game_1.json

The PATTERNS below are best-effort guesses at Source 2 console output and
MUST be calibrated against a real first-run log (see README.md). Every
pattern that never matches is reported in the "unmatched_patterns" field so
calibration gaps are visible instead of silent.
"""
import json
import re
import sys

# Calibrate these against a real console log on first run.
PATTERNS = {
    # winner detection: ancient (fort) destruction or explicit game-over line
    "radiant_win": [
        re.compile(r"npc_dota_badguys_fort.*(destroyed|killed)", re.I),
        re.compile(r"game.?over.*radiant", re.I),
        re.compile(r"winner.*radiant|radiant.*victory", re.I),
    ],
    "dire_win": [
        re.compile(r"npc_dota_goodguys_fort.*(destroyed|killed)", re.I),
        re.compile(r"game.?over.*dire", re.I),
        re.compile(r"winner.*dire|dire.*victory", re.I),
    ],
    # FretBots / OHA stat lines (hero, kills, deaths, assists, gpm, xpm ...)
    "hero_stats": [
        re.compile(
            r"(npc_dota_hero_\w+).*?(\d+)/(\d+)/(\d+).*?gpm[:\s]+(\d+).*?xpm[:\s]+(\d+)",
            re.I,
        ),
    ],
    "game_time": [
        re.compile(r"game.?time[:\s]+(\d+):(\d+)", re.I),
    ],
}


def parse(path):
    result = {
        "log": path,
        "winner": None,
        "duration_s": None,
        "heroes": [],
        "unmatched_patterns": [],
    }
    with open(path, errors="replace") as f:
        for line in f:
            if result["winner"] is None:
                if any(p.search(line) for p in PATTERNS["radiant_win"]):
                    result["winner"] = "radiant"
                elif any(p.search(line) for p in PATTERNS["dire_win"]):
                    result["winner"] = "dire"
            for p in PATTERNS["hero_stats"]:
                m = p.search(line)
                if m:
                    result["heroes"].append(
                        {
                            "hero": m.group(1),
                            "kills": int(m.group(2)),
                            "deaths": int(m.group(3)),
                            "assists": int(m.group(4)),
                            "gpm": int(m.group(5)),
                            "xpm": int(m.group(6)),
                        }
                    )
            for p in PATTERNS["game_time"]:
                m = p.search(line)
                if m:
                    result["duration_s"] = int(m.group(1)) * 60 + int(m.group(2))

    for key, pats in PATTERNS.items():
        # report which detector groups never fired, for calibration
        fired = (
            (key == "radiant_win" and result["winner"] == "radiant")
            or (key == "dire_win" and result["winner"] == "dire")
            or (key == "hero_stats" and result["heroes"])
            or (key == "game_time" and result["duration_s"] is not None)
        )
        if not fired:
            result["unmatched_patterns"].append(key)
    return result


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(json.dumps(parse(sys.argv[1]), indent=2))

#!/usr/bin/env python3
"""Per-game anomaly extraction for the soak farm.

Wraps parse_log.py's scoreboard parse and adds behavior/health signals:
  - VScript runtime errors (with surrounding context lines)
  - script-perf warnings ("Script function ... took N ms"), aggregated
  - duration outliers (turbo game dragging past 40 game-minutes = bots
    failing to close; or ending before 10 = a stomp/insta-end bug)
  - feeding pattern: deaths >= 8 with kills <= 2
  - farming cores: core-tagged hero below 300 GPM (turbo!) is broken

Usage: analyze_log.py game.log > game.analysis.json
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from parse_log import parse  # noqa: E402

RE_VSCRIPT_ERR = re.compile(r"\[VScript\].*(Runtime Error|Syntax Error|error)", re.I)
RE_PERF = re.compile(r"Script function '(\w+)' on bot (npc_dota_hero_\w+) took ([0-9.]+)ms")


def analyze(path):
    base = parse(path)
    anomalies = []

    vscript_errors = []
    perf = {}
    lines = open(path, errors="replace").read().splitlines()
    for i, line in enumerate(lines):
        if RE_VSCRIPT_ERR.search(line):
            ctx = lines[max(0, i - 2): i + 3]
            vscript_errors.append([c.strip()[:220] for c in ctx])
        m = RE_PERF.search(line)
        if m:
            key = f"{m.group(2)}:{m.group(1)}"
            rec = perf.setdefault(key, {"count": 0, "max_ms": 0.0})
            rec["count"] += 1
            rec["max_ms"] = max(rec["max_ms"], float(m.group(3)))

    if vscript_errors:
        anomalies.append({
            "type": "vscript_errors",
            "count": len(vscript_errors),
            "samples": vscript_errors[:5],
        })
    slow = {k: v for k, v in perf.items() if v["count"] >= 10 or v["max_ms"] >= 8}
    if slow:
        anomalies.append({"type": "script_perf", "hotspots": slow})

    # achieved timescale: stdout has no per-line clock, so the loop passes
    # measured wall seconds via SOAK_WALL_S.
    wall_s = os.environ.get("SOAK_WALL_S")
    if wall_s and base.get("duration_s"):
        try:
            w = int(wall_s)
            if w > 0:
                base["effective_timescale"] = round(base["duration_s"] / w, 2)
                base["wall_s"] = w
        except ValueError:
            pass

    dur_min = (base.get("duration_s") or 0) / 60

    # Economic winner (owner rule): games are locked to ~30 game-minutes by
    # the rcon referee; for those, the winner is the team that EARNED more
    # gold (sum of GPM x duration), not whoever the engine credited for the
    # forcewin. Natural sub-cap endings keep the engine winner.
    team_gold = {"radiant": 0, "dire": 0}
    for p in base.get("players", []):
        team = p.get("team")
        if team in team_gold and p.get("gpm"):
            team_gold[team] += p["gpm"] * dur_min
    team_gold = {k: int(v) for k, v in team_gold.items()}
    econ_winner = None
    if team_gold["radiant"] or team_gold["dire"]:
        econ_winner = "radiant" if team_gold["radiant"] >= team_gold["dire"] else "dire"
    winner_by = "engine"
    if base.get("winner") is not None and econ_winner and dur_min >= 29.5:
        base["winner"] = econ_winner
        winner_by = "economy_30min_cap"

    if base.get("winner") is None:
        anomalies.append({"type": "no_winner", "note": "game did not finish"})
    elif dur_min > 40:
        anomalies.append({"type": "slow_close",
                          "duration_min": round(dur_min, 1),
                          "note": "turbo game dragged past 40 min — closing problem"})
    elif dur_min < 10:
        anomalies.append({"type": "insta_end", "duration_min": round(dur_min, 1)})

    for p in base.get("players", []):
        k, d = p.get("kills", 0), p.get("deaths", 0)
        if d >= 8 and k <= 2:
            anomalies.append({"type": "feeder", "hero": p.get("hero"),
                              "kda": f"{k}/{d}/{p.get('assists', 0)}"})
        if p.get("gpm", 999) < 300:
            anomalies.append({"type": "low_gpm", "hero": p.get("hero"),
                              "gpm": p.get("gpm")})

    return {
        "log": path,
        # script_version: git describe of the code this game RAN, stamped at
        # launch by soak_loop.sh (SOAK_SCRIPT_VERSION). The single most important
        # field for later analysis — ties every game to an exact code version.
        "script_version": os.environ.get("SOAK_SCRIPT_VERSION", "unknown"),
        "winner": base.get("winner"),
        "winner_by": winner_by,
        "team_gold": team_gold,
        "econ_winner": econ_winner,
        "duration_s": base.get("duration_s"),
        "duration_min": round(dur_min, 1),
        "wall_s": base.get("wall_s"),
        "effective_timescale": base.get("effective_timescale"),
        "mode": base.get("mode_guess"),
        "avg_gpm": base.get("avg_gpm"),
        "players": base.get("players"),
        "towers": base.get("towers"),
        "anomaly_count": len(anomalies),
        "anomalies": anomalies,
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(json.dumps(analyze(sys.argv[1]), indent=2))

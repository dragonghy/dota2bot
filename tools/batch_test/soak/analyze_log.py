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

    dur_min = (base.get("duration_s") or 0) / 60
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
        "winner": base.get("winner"),
        "duration_min": round(dur_min, 1),
        "effective_timescale": base.get("effective_timescale"),
        "players": base.get("players"),
        "anomaly_count": len(anomalies),
        "anomalies": anomalies,
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    print(json.dumps(analyze(sys.argv[1]), indent=2))

#!/usr/bin/env python3
"""Per-game anomaly extraction for the soak farm.

Wraps parse_log.py's scoreboard parse and adds behavior/health signals:
  - VScript runtime errors (with surrounding context lines)
  - script-perf warnings ("Script function ... took N ms"), aggregated
  - duration outliers, both tied to SOAK_CAP_MIN rather than pinned ([GH #108]):
    past cap+15 game-minutes the referee that force-wins at the cap is dead;
    below 10 with no ancient down is the premature-forcewin artifact
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
    cap_min = float(os.environ.get("SOAK_CAP_MIN", "30"))

    # [GH #108 checklist 1] Did the game end because somebody took the ancient?
    # At SOAK_CAP_MIN=10 this was nearly a constant false (no turbo game loses
    # its fort in 10 minutes), so "sub-cap ending" and "referee artifact" were
    # the same set and the recovery heuristic below could not be wrong. At 25
    # they come apart: most games are expected to end naturally, and a REAL win
    # by the economic loser (a comeback, a throw) is exactly a sub-cap engine
    # ending whose winner disagrees with the gold -- i.e. it looks bit for bit
    # like the artifact the heuristic exists to repair. So the fort is asked
    # first: a destroyed ancient is a scoreboard, and no economic reasoning is
    # allowed to overwrite one.
    fort = next((t for t in base.get("towers", [])
                 if str(t.get("building", "")).endswith("_fort")), None)
    natural_end = fort is not None

    winner_by = "engine"
    if natural_end:
        # parse_log already derives the winner from the fort when the signout
        # block is missing; when both exist the signout is the same fact.
        winner_by = "engine_natural"
    elif base.get("winner") is not None and econ_winner and dur_min >= cap_min - 0.5:
        base["winner"] = econ_winner
        winner_by = f"economy_{int(cap_min)}min_cap"
    elif base.get("winner") is not None and econ_winner and dur_min < cap_min - 0.5:
        # [freehunt2 finding 1] A sub-cap "engine" ending with NO fort down is
        # the referee's premature forcewin signature (ancient 4500->0 between
        # samples with every tower/rax alive; engine winner dire 50/50 times):
        # the engine attribution is an artifact of the surrender mechanism, not
        # a real win. Trust the economy instead so ~10% of verdicts stop
        # flipping.
        if base["winner"] != econ_winner:
            base["winner"] = econ_winner
            winner_by = "economy_forcewin_recovery"

    if base.get("winner") is None:
        anomalies.append({"type": "no_winner", "note": "game did not finish"})
    elif dur_min > cap_min + 15:
        # The referee force-wins at the cap, so this band is unreachable while
        # the referee works -- which is the whole point: it detects a DEAD
        # REFEREE, not slow bots. Tied to the cap so it keeps meaning that
        # after #108 (at cap=25 it is the same literal 40 it always was).
        anomalies.append({"type": "slow_close",
                          "duration_min": round(dur_min, 1),
                          "note": f"game ran past cap {cap_min:g}+15 min — referee likely dead"})
    elif not natural_end and dur_min < min(10.0, cap_min):
        # An ending far below the cap with nobody's ancient down. This is the
        # artifact above, not a stomp; a genuine 9-minute stomp has a fort.
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
        # [GH #108 acceptance 1] The natural-end RATE is the number the owner's
        # cap decision is judged by, and it has to be a field: deriving it from
        # winner_by at report time is how a definition drifts between two desks.
        "natural_end": natural_end,
        "cap_min": cap_min,
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

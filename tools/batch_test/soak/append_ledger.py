#!/usr/bin/env python3
"""Append per-game metadata rows to the queryable games ledger.

The ledger (iterations/games_ledger.jsonl) is the committed, no-need-to-reparse
record of every soak game: one JSON object per line. Query it with jq or
pandas (pd.read_json(path, lines=True)) instead of re-parsing gzipped console
logs.

Input: one or more per-game analysis JSON files (as produced on the farm by
analyze_log.py and stored in S3). Output: normalized ledger rows appended to
the ledger file, de-duplicated by game_id.

Each row carries the fields the owner asked to keep queryable:
  - script_version  (git describe of the code the game RAN — the key field)
  - game-level: game_id, run_prefix, mode, duration_s/min, wall_s,
    effective_timescale, winner
  - per hero: name, team, gpm, xpm, kills/deaths/assists, level, last_hits
  - tower destruction timeline (building -> game-second)
  - anomaly tags

Usage:
  append_ledger.py --ledger iterations/games_ledger.jsonl \
                   --run-prefix soak/run_20260719_0455 analysis1.json [analysis2.json ...]
"""
import argparse
import json
import os
import sys


def game_id_from_path(path):
    # <TS>_slot<N>.analysis.json  ->  <TS>_slot<N>
    base = os.path.basename(path)
    return base.replace(".analysis.json", "").replace(".json", "")


def row_from_analysis(path, run_prefix):
    with open(path) as f:
        a = json.load(f)
    heroes = []
    for p in a.get("players") or []:
        heroes.append({
            "hero": p.get("hero"),
            "team": p.get("team"),
            "gpm": p.get("gpm"),
            "xpm": p.get("xpm"),
            "kills": p.get("kills"),
            "deaths": p.get("deaths"),
            "assists": p.get("assists"),
            "level": p.get("level"),
            "last_hits": p.get("last_hits"),
        })
    return {
        "game_id": game_id_from_path(path),
        "script_version": a.get("script_version", "unknown"),
        "run_prefix": run_prefix,
        "mode": a.get("mode"),
        "winner": a.get("winner"),
        "duration_s": a.get("duration_s"),
        "duration_min": a.get("duration_min"),
        "wall_s": a.get("wall_s"),
        "effective_timescale": a.get("effective_timescale"),
        "heroes": heroes,
        "towers": a.get("towers"),
        "anomalies": [x.get("type") if isinstance(x, dict) else x
                      for x in (a.get("anomalies") or [])],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", required=True)
    ap.add_argument("--run-prefix", required=True)
    ap.add_argument("analyses", nargs="+")
    args = ap.parse_args()

    seen = set()
    if os.path.exists(args.ledger):
        with open(args.ledger) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    seen.add(json.loads(line)["game_id"])
                except Exception:
                    pass

    added = 0
    os.makedirs(os.path.dirname(args.ledger) or ".", exist_ok=True)
    with open(args.ledger, "a") as out:
        for path in args.analyses:
            try:
                row = row_from_analysis(path, args.run_prefix)
            except Exception as e:
                print(f"skip {path}: {e}", file=sys.stderr)
                continue
            if row["game_id"] in seen:
                continue
            out.write(json.dumps(row, separators=(",", ":")) + "\n")
            seen.add(row["game_id"])
            added += 1
    print(f"appended {added} rows to {args.ledger} (total unique {len(seen)})")


if __name__ == "__main__":
    main()

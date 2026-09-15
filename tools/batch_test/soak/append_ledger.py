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
    return row_from_analysis_obj(a, game_id_from_path(path), run_prefix)


def row_from_analysis_obj(a, game_id, run_prefix):
    """Normalize one ALREADY-PARSED analysis object into a ledger row.

    Split out of row_from_analysis so the harvest chain can write the ledger
    from the games it has already loaded (recover_verdict.py --ledger) without
    a second copy of this schema.  Two copies of a row schema drift, and a
    ledger whose rows changed shape halfway is exactly the un-comparable
    accounting GH #.../W37 opened this obligation about.
    """
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
        "game_id": game_id,
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


def ledger_key(row):
    """The identity a ledger row is de-duplicated on: (run_prefix, game_id).

    NOT game_id alone.  Per-game files are named `<YYYYmmdd_HHMMSS>_slot<N>`
    with no run token, the 4x1 waves launch their instances in the same second,
    and their slot cadence matches -- so the SAME basename naming two DIFFERENT
    games across two runs is the norm, not an accident (GH #225 measured it at
    the filesystem layer: 208 files became 188).  De-duplicating on the tag
    alone would reinstate that loss inside the ledger, and silently: the second
    game would simply never be written, and the ledger carries no expected
    count to miss it against.  Keying on the pair keeps `game_id` itself
    unchanged (historical rows and any grep over them still read the raw tag).
    """
    return (row.get("run_prefix"), row.get("game_id"))


def existing_keys(ledger_path):
    """Keys already in the ledger. Unreadable lines are skipped, not guessed."""
    seen = set()
    if os.path.exists(ledger_path):
        with open(ledger_path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    seen.add(ledger_key(json.loads(line)))
                except Exception:
                    pass
    return seen


def append_rows(ledger_path, rows):
    """Append rows not already present. Returns (added, total_unique)."""
    seen = existing_keys(ledger_path)
    added = 0
    os.makedirs(os.path.dirname(ledger_path) or ".", exist_ok=True)
    with open(ledger_path, "a") as out:
        for row in rows:
            k = ledger_key(row)
            if k in seen:
                continue
            out.write(json.dumps(row, separators=(",", ":")) + "\n")
            seen.add(k)
            added += 1
    return added, len(seen)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", required=True)
    ap.add_argument("--run-prefix", required=True)
    ap.add_argument("analyses", nargs="+")
    args = ap.parse_args()

    rows = []
    for path in args.analyses:
        try:
            rows.append(row_from_analysis(path, args.run_prefix))
        except Exception as e:
            print(f"skip {path}: {e}", file=sys.stderr)

    added, total = append_rows(args.ledger, rows)
    print(f"appended {added} rows to {args.ledger} (total unique {total})")


if __name__ == "__main__":
    main()

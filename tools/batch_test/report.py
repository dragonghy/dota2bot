#!/usr/bin/env python3
"""Aggregate batch-run results; compare two runs (A/B) when given two dirs.

Usage:
    report.py results/run1                 # summarize one run
    report.py results/baseline results/candidate   # A/B comparison
"""
import glob
import json
import math
import os
import sys


def load_run(dirpath):
    games = []
    for path in sorted(glob.glob(os.path.join(dirpath, "game_*.json"))):
        with open(path) as f:
            games.append(json.load(f))
    return games


def summarize(dirpath, games):
    n = len(games)
    decided = [g for g in games if g.get("winner")]
    radiant = sum(1 for g in decided if g["winner"] == "radiant")
    durations = [g["duration_s"] for g in games if g.get("duration_s")]
    gpms = [h["gpm"] for g in games for h in g.get("heroes", [])]
    uncal = sum(1 for g in games if g.get("unmatched_patterns"))

    print(f"== {dirpath} ==")
    print(f"  games parsed:        {n}")
    print(f"  decided (winner):    {len(decided)}")
    if decided:
        print(f"  radiant win rate:    {radiant / len(decided):.1%} ({radiant}/{len(decided)})")
    if durations:
        print(f"  avg duration:        {sum(durations) / len(durations) / 60:.1f} min")
    if gpms:
        print(f"  avg hero GPM:        {sum(gpms) / len(gpms):.0f}")
    if uncal:
        print(f"  WARNING: {uncal} game(s) had unmatched parser patterns — "
              f"calibrate parse_log.py (see README)")
    print()
    return {
        "n": len(decided),
        "radiant_wins": radiant,
        "gpms": gpms,
    }


def two_proportion_z(w1, n1, w2, n2):
    """z-test for difference of win proportions; returns (diff, z)."""
    if n1 == 0 or n2 == 0:
        return 0.0, 0.0
    p1, p2 = w1 / n1, w2 / n2
    p = (w1 + w2) / (n1 + n2)
    se = math.sqrt(p * (1 - p) * (1 / n1 + 1 / n2))
    z = (p1 - p2) / se if se > 0 else 0.0
    return p1 - p2, z


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)

    runs = []
    for d in sys.argv[1:]:
        games = load_run(d)
        if not games:
            sys.exit(f"no game_*.json files in {d} — run parse_log.py first")
        runs.append((d, summarize(d, games)))

    if len(runs) == 2:
        (da, a), (db, b) = runs
        diff, z = two_proportion_z(a["radiant_wins"], a["n"], b["radiant_wins"], b["n"])
        print("== A/B comparison (radiant win rate) ==")
        print(f"  {da}: {a['radiant_wins']}/{a['n']}")
        print(f"  {db}: {b['radiant_wins']}/{b['n']}")
        print(f"  diff: {diff:+.1%}, z = {z:.2f} "
              f"({'significant at p<0.05' if abs(z) > 1.96 else 'NOT significant'})")
        if a["gpms"] and b["gpms"]:
            ga = sum(a["gpms"]) / len(a["gpms"])
            gb = sum(b["gpms"]) / len(b["gpms"])
            print(f"  avg GPM: {ga:.0f} vs {gb:.0f} ({gb - ga:+.0f})")


if __name__ == "__main__":
    main()

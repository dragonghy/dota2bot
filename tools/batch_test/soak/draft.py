#!/usr/bin/env python3
"""Soak-farm drafter: pick 10 heroes from the pool and write them into
bots/Customize/general.lua (Radiant_Heros / Dire_Heros).

Selection heuristic:
  - always include >=1 focus hero per side (they're the protagonists)
  - otherwise weight picks toward least-played heroes (coverage-driven,
    tracked in soak_state.json next to this script)
  - soft role balance: aim for >=2 support-ish heroes per side; a failed
    constraint is accepted (mismatched comps still produce useful logs)

Usage: draft.py --customize /path/to/bots/Customize/general.lua [--seed N]
"""
import argparse
import json
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(HERE, "soak_state.json")


def load_pool():
    pool = []
    with open(os.path.join(HERE, "hero_pool.txt")) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            name, role, tier = line.split(",")
            pool.append({"name": name, "role": role, "tier": tier})
    return pool


def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except Exception:
        return {"plays": {}}


def pick_team(pool, state, taken):
    """Pick 5 heroes for one team."""
    plays = state["plays"]
    avail = [h for h in pool if h["name"] not in taken]

    def weight(h):
        w = 1.0 / (1 + plays.get(h["name"], 0))   # least-played favored
        if h["tier"] == "focus":
            w *= 2.0
        return w

    team = []
    # 1 guaranteed focus hero
    focus = [h for h in avail if h["tier"] == "focus"]
    if focus:
        c = random.choices(focus, weights=[weight(h) for h in focus])[0]
        team.append(c)
        avail.remove(c)
    # fill remaining 4, nudging toward >=2 supports
    while len(team) < 5 and avail:
        n_sup = sum(1 for h in team if h["role"] == "support")
        cands = avail
        if n_sup < 2 and len(team) >= 3:
            sups = [h for h in avail if h["role"] in ("support", "either")]
            if sups:
                cands = sups
        c = random.choices(cands, weights=[weight(h) for h in cands])[0]
        team.append(c)
        avail.remove(c)
    return team


def write_customize(path, radiant, dire):
    with open(path) as f:
        src = f.read()

    def block(names):
        inner = "\n".join(f"    'npc_dota_hero_{n}'," for n in names)
        return "{\n" + inner + "\n}"

    src = re.sub(r"Customize\.Radiant_Heros\s*=\s*\{.*?\}",
                 "Customize.Radiant_Heros = " + block(radiant),
                 src, count=1, flags=re.S)
    src = re.sub(r"Customize\.Dire_Heros\s*=\s*\{.*?\}",
                 "Customize.Dire_Heros = " + block(dire),
                 src, count=1, flags=re.S)
    with open(path, "w") as f:
        f.write(src)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--customize", required=True)
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()
    if args.seed is not None:
        random.seed(args.seed)

    pool = load_pool()
    state = load_state()

    taken = set()
    radiant = pick_team(pool, state, taken)
    taken.update(h["name"] for h in radiant)
    dire = pick_team(pool, state, taken)

    for h in radiant + dire:
        state["plays"][h["name"]] = state["plays"].get(h["name"], 0) + 1
    with open(STATE, "w") as f:
        json.dump(state, f)

    write_customize(args.customize,
                    [h["name"] for h in radiant], [h["name"] for h in dire])
    print(json.dumps({
        "radiant": [h["name"] for h in radiant],
        "dire": [h["name"] for h in dire],
    }))


if __name__ == "__main__":
    main()

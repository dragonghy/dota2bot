#!/usr/bin/env python3
"""Offline replay of Outworld/Obsidian Destroyer's Sanity's Eclipse gate.

Answers, for one soak wave's timelines, three separate questions that the raw
`died_with_ult_ready` detector conflates:

  1. OPPORTUNITY  -- how often was the ult actually available with an enemy in
     range (level>0, cd==0, mana >= cost, living enemy hero within cast range)?
  2. GATE STATE   -- of those frames, how many passed each offline-computable
     clause of `X.ConsiderSanitysEclipse` (hero_obsidian_destroyer.lua:442)?
       * ally parity   `#alliesWithin1200(bot) >= #alliesWithin1200(target)`
       * lethality     `J.CanKillTarget(target, base + |dMana|*mult, MAGICAL)`
  3. FIRING       -- given both gates open, did the cast actually happen?

Why the split matters: on the 22:11Z (a)-evidence wave the candidate side cast
the ult 1x vs the baseline side's 7x, which reads like an armed-id suppressing
the ultimate. Decomposed, the ally-parity clause is identical on both sides
(p=1.0) and the whole difference sits in the lethality clause (p=0.006) --
which tracks the ENEMY team's HP pool, i.e. the known economy deficit, not a
decision defect. See iterations/reports/replay-check/20260820T024500Z.md.

Honest boundaries, do not overstate results from this script:
  * `J.IsGoingOnSomeone(bot)` wraps the whole Consider function and is a
    script-side mode concept that is NOT in the .dem (same class as
    `J.IsRetreating`; see the 22:36Z report). Every count here is therefore a
    SUPERSET of the frames where the gate could really have opened.
  * `J.CanKillTarget` calls the engine's `GetActualIncomingDamage`. We
    approximate it as `0.75 * (base + |dMana| * mult)` (25% base magic
    resistance). The special values are not in the .dem, but they ARE in the
    datafeed and have been pulled -- see the constants block below. --base and
    --mult remain as overrides and --sweep as a sensitivity check; the
    defaults are now the measured values, not guesses.
  * Snapshots are 1 Hz: a cast within 4s of an opportunity frame counts as
    "fired for that opportunity", and corpse frames (hp_pct==0) are dropped.
  * Illusions share the hero class name; entities are locked by (name, idx).

Usage:
    od_ult_gate.py <manifest.json> [--base N] [--mult 0.4] [--range 700]
                   [--dedup 6] [--sweep] [--episodes]

The manifest is a JSON list of {"key","seed","armed_side","tl"} records, where
`tl` is a behav-dump timeline path -- exactly what sweep_run.sh's
games_manifest.jsonl carries, one object per mirrored (non-warmup) game.
"""
import argparse
import collections
import json
import math

OD = "npc_dota_hero_obsidian_destroyer"
ULT = "obsidian_destroyer_sanity_eclipse"

# CORRECTED 2026-08-21 (hero stream) from the live datafeed, hero_id=76. The
# four constants this file shipped with were all guesses and all wrong:
#     base_damage        350 flat   ->  200/300/400 per ult level
#     damage_multiplier  0.7        ->  0.4  (--sweep only spanned 0.6-0.8,
#                                            so no run ever reached the truth)
#     cast_range         600        ->  700
#     ULT_MANA           400 flat   ->  200/300/400 per ult level
# Net effect on every reading published before that date: the `lethal` clause
# used ~0.75*(350 + d*0.7) where the truth at ult level 1 is 0.75*(200 + d*0.4)
# -- inflated by roughly 75% at a typical mana gap -- while the opportunity
# count was deflated from both sides (cast range too short, mana bar too high).
# In this project's turbo corpus Sanity's Eclipse is level 1 in 9 games out of
# 9, so the level-1 column is the one that matters. Between-side comparisons
# (armed vs baseline) applied the same wrong constants to both arms and are
# less affected than the absolute counts, but any absolute "N opportunity
# frames" figure quoted from this script before 2026-08-21 should be re-run.
# See tools/batch_test/behavioral/od_eclipse_aoe_domain.py for the full pull.
ULT_MANA_BY_LEVEL = {1: 200, 2: 300, 3: 400}
ULT_BASE_BY_LEVEL = {1: 200.0, 2: 300.0, 3: 400.0}
ULT_MANA = ULT_MANA_BY_LEVEL[1]     # kept for callers that want a scalar floor
MAGIC_RESIST = 0.75     # 25% base magic resistance, as GetActualIncomingDamage applies
SIDE = {"radiant": 2, "dire": 3}


def load_frames(tl_path):
    """-> (teams, events, snapshots-by-(hero,idx), snapshots-by-rounded-t).

    Post-game frozen snapshots are cut at the last event ([harness] GH #43)."""
    d = json.load(open(tl_path))
    teams = d["game"]["teams"]
    events = sorted(d["events"], key=lambda e: e["t"])
    t_end = max((e["t"] for e in events), default=float("inf"))
    by_ent = collections.defaultdict(list)
    by_t = collections.defaultdict(list)
    for s in d["snapshots"]:
        if s["t"] > t_end:
            continue
        by_ent[(s["hero"], s["idx"])].append(s)
        by_t[round(s["t"], 1)].append((s["hero"], s["idx"], s))
    for k in by_ent:
        by_ent[k].sort(key=lambda s: s["t"])
    return teams, events, by_ent, by_t


def scan_game(tl_path, armed_side, base_override, mult, cast_range, dedup):
    teams, events, by_ent, by_t = load_frames(tl_path)
    if OD not in teams:
        return None
    my, foe = teams[OD], (3 if teams[OD] == 2 else 2)
    role = "ARMED" if my == SIDE[armed_side] else "BASE"
    # lock the real hero entity: illusions carry the same class name
    od_key = max((k for k in by_ent if k[0] == OD), key=lambda k: len(by_ent[k]))
    casts = [e["t"] for e in events
             if e["type"] == "ABILITY" and e.get("actor") == OD
             and e.get("inflictor") == ULT]

    episodes, last = [], -1e9
    for s in by_ent[od_key]:
        if s["hp_pct"] <= 0:                      # corpse frame
            continue
        ult = next((a for a in s["abilities"] if a["name"] == ULT), None)
        if not ult or ult["level"] < 1 or ult["cd"] > 0:
            continue
        lvl = min(ult["level"], 3)
        if s["mp"] < ULT_MANA_BY_LEVEL[lvl]:
            continue
        # --base is an override; left at its default the per-level truth wins
        base = ULT_BASE_BY_LEVEL[lvl] if base_override is None else base_override
        frame = by_t.get(round(s["t"], 1), [])
        near = sorted((math.hypot(z["x"] - s["x"], z["y"] - s["y"]), h, z)
                      for h, i, z in frame
                      if teams.get(h) == foe and z["hp_pct"] > 0)
        near = [n for n in near if n[0] <= cast_range]
        if not near or s["t"] - last < dedup:
            continue
        last = s["t"]
        allies = [z for h, i, z in frame
                  if teams.get(h) == my and h != OD and z["hp_pct"] > 0
                  and math.hypot(z["x"] - s["x"], z["y"] - s["y"]) <= 1200]
        best = None
        for dist, h, z in near:
            t_allies = [z2 for h2, i2, z2 in frame
                        if teams.get(h2) == foe and h2 != h and z2["hp_pct"] > 0
                        and math.hypot(z2["x"] - z["x"], z2["y"] - z["y"]) <= 1200]
            est = MAGIC_RESIST * (base + abs(s["mp"] - z["mp"]) * mult)
            rec = {"t": round(s["t"], 1), "tgt": h.replace("npc_dota_hero_", ""),
                   "dist": round(dist), "od_hp": round(s["hp_pct"], 2),
                   "od_mp": round(s["mp"]), "tgt_mp": round(z["mp"]),
                   "tgt_hp": round(z["hp"]), "est": round(est),
                   "parity": len(allies) >= len(t_allies), "lethal": est >= z["hp"],
                   "ally": len(allies), "tally": len(t_allies),
                   "n_in_range": len(near), "od_nw": s["net_worth"]}
            if best is None or (rec["parity"], rec["lethal"]) > (best["parity"], best["lethal"]):
                best = rec
            if rec["parity"] and rec["lethal"]:
                break
        best["fired"] = any(s["t"] <= c <= s["t"] + 4.0 for c in casts)
        episodes.append(best)
    return {"role": role, "episodes": episodes, "real_casts": len(casts),
            "deaths": sum(1 for e in events
                          if e["type"] == "DEATH" and e.get("target") == OD)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--base", type=float, default=None,
                    help="override base_damage; default = per-ult-level 200/300/400")
    ap.add_argument("--mult", type=float, default=0.4)
    ap.add_argument("--range", dest="cast_range", type=float, default=700.0)
    ap.add_argument("--dedup", type=float, default=6.0)
    ap.add_argument("--sweep", action="store_true",
                    help="report the gate over a range of (base, mult) guesses")
    ap.add_argument("--episodes", action="store_true",
                    help="print every episode where both offline gates pass")
    a = ap.parse_args()

    games = json.load(open(a.manifest))
    # the sweep brackets the datafeed truth (per-level base, mult 0.4) rather
    # than the old 0.6-0.8 band, which never contained it
    params = [(200.0, 0.3), (a.base, a.mult), (400.0, 0.5)] if a.sweep \
        else [(a.base, a.mult)]

    for base, mult in params:
        agg = collections.defaultdict(collections.Counter)
        shown = []
        for g in games:
            r = scan_game(g["tl"], g["armed_side"], base, mult, a.cast_range, a.dedup)
            if r is None:
                continue
            c = agg[r["role"]]
            c["games"] += 1
            c["real_casts"] += r["real_casts"]
            c["deaths"] += r["deaths"]
            for ep in r["episodes"]:
                c["opp"] += 1
                c["parity_ok"] += ep["parity"]
                c["lethal_ok"] += ep["lethal"]
                if ep["parity"] and ep["lethal"]:
                    c["both"] += 1
                    c["fired"] += ep["fired"]
                    shown.append((r["role"], g["key"], ep))
        shown_base = "per-level" if base is None else f"{base:.0f}"
        print(f"=== base={shown_base} mult={mult} range={a.cast_range:.0f} "
              f"dedup={a.dedup:.0f}s (est *= {MAGIC_RESIST} magic resist) ===")
        for role in ("ARMED", "BASE"):
            c = agg[role]
            n = max(c["opp"], 1)
            print(f"  {role:5s} games={c['games']} OD_deaths={c['deaths']} "
                  f"real_SE_casts={c['real_casts']} | opportunities={c['opp']} "
                  f"parity_ok={c['parity_ok']} ({c['parity_ok']/n*100:.0f}%) "
                  f"lethal_ok={c['lethal_ok']} ({c['lethal_ok']/n*100:.0f}%) "
                  f"BOTH={c['both']} -> fired={c['fired']}")
        if a.episodes:
            for role, key, ep in shown:
                print(f"  {role:5s} {key[:30]:30s} t={ep['t']:7.1f} "
                      f"tgt={ep['tgt']:16s} d={ep['dist']:4d} od_hp={ep['od_hp']:.2f} "
                      f"od_mp={ep['od_mp']:4d} tgt_hp={ep['tgt_hp']:4d} est={ep['est']:4d} "
                      f"ally={ep['ally']}v{ep['tally']} fired={ep['fired']}")
        print()


if __name__ == "__main__":
    main()

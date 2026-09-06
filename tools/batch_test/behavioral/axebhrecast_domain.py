#!/usr/bin/env python3
"""axebhrecast_domain.py -- size the domain of the `axebhrecast` soak candidate
from ALREADY-LANDED dumper timelines.  Zero EC2, read-only.

Executes queue.json `hero-35` (GH #554), ruled APPROVED-SCAN by the director
2026-09-06T07:xxZ (test_set.md section FG.2).  Product path is fixed by that
ruling: iterations/reports/replay-check/domain_scan_hero_2_30_31.md

THE LEVER (bots/BotLib/hero_axe.lua X.axe_IsBattleHungerFresh).  Eight sites in
X.ConsiderW carry `not <target>:HasModifier('modifier_axe_battle_hunger_self')`,
a name a target can never carry: it is the CASTER-side family, and in this patch
that family is spelled `..._self_movespeed`.  So the veto is structurally
always-true and Axe has never declined a Battle Hunger for "already hungered".
The gated fix wires a real check at three of the eight sites.

WHAT THIS TOOL COUNTS, and the four columns hero-35 asked for:
  (1) every `axe_battle_hunger` cast, and the subset whose target ALREADY
      carried `modifier_axe_battle_hunger` -- the direct count of the defect,
      no inference needed.
  (2) THE VALUE COLUMN: at each such re-cast, how many OTHER enemy heroes were
      inside Battle Hunger's rank-dependent cast range (600/700/800/900) and
      were NOT themselves hungered.  This is what decides whether the lever
      SPREADS (a gain) or merely DECLINES (a pure cost).
  (3) the remaining debuff time at the re-cast instant; a re-cast is worth only
      `12 - remaining` seconds, so this is the pricing denominator.
  (4) which of the eight branches issued the cast -- NOT COMPUTED, and it
      cannot be: the dump carries no bot-side mode or branch identity.  Reported
      as INSTRUMENT-BLIND rather than guessed.  See section CJ.

EXTRA TERM THE REQUEST DID NOT ASK FOR BUT THE GATE CARRIES, AND THE FIRST WAY
OF READING IT WAS WRONG.  The armed leg stands down under
`J.HasAghanimsShard( bot )`, because the shard turns `should_stack` on and a
re-cast becomes a genuine second stack.  A re-cast made while Axe holds the
shard is OUTSIDE the lever's domain entirely, so this term decides how much
domain there is at all.

The obvious reading -- look for the item in `snapshots[].items` -- returns ZERO
across 72 games, and that zero is manufactured, not observed: Aghanim's Shard is
CONSUMED on use.  It grants its bonus permanently and leaves the inventory, so
an inventory scan can only ever catch the seconds between purchase and use, and
the combat log carries no `modifier_item_aghanims_shard` on Axe either.  Reading
that zero as "the shard is never held" would have put the entire 577-episode
domain inside a gate that in fact stands down for much of it.

THE OBSERVABLE THAT DOES WORK IS BEHAVIOURAL.  `axe_berserkers_call` gains
`applies_battle_hunger` from exactly one source in the ability KV --
`special_bonus_shard`.  So a Berserker's Call whose own instant also carries
`modifier_axe_battle_hunger` MODIFIER_ADDs is a shard sighting, and the first
such Call dates the acquisition.  Caught frame-by-frame at
26717d__20260902_033228_slot1 t=1475.6, where a Call and a Battle Hunger ADD
share a tick while the inventory shows six items and no shard; in that game the
signature starts at t=1011.2 and every Call before it is clean.

⚠️ THE DETECTOR IS LATE BY CONSTRUCTION and the report must say so: it cannot
fire until Axe next lands a Call on somebody, so the onset it returns is an
UPPER BOUND on the true acquisition time, and the in-domain episode count it
yields is therefore an OVER-estimate.  That is the conservative direction for a
request whose pre-registered failure mode is "the domain is smaller than it
looks", so it is reported as a bound and never as the count.

THE KILL-CONFIRM COLUMN, and why column (2) alone over-counts the benefit.
Found by frame-by-frame review of this scan's own top exemplar
(b30fe4__20260904_184634_slot6 t=1393.9, four unhungered enemies inside 900u --
the single best "spread" frame in 577 episodes).  Two seconds later Axe
Culling-Bladed that same target dead, and the one after him.  The re-cast was a
kill-confirm, and X.ConsiderW's KILL LOOP is one of the five sites the lever
deliberately leaves UNWIRED, precisely because its damage claim is priced on a
full 12s duration that only a refresh restores.  A "spread candidate existed"
count that ignores this reads a deliberate no-op site as forgone benefit.  So
every episode also carries whether the target died within 5s and to what.  This
does not identify the branch -- that stays INSTRUMENT-BLIND -- but it bounds how
much of column (2) can possibly be the wired sites' business.

TWO CONTAMINATION GUARDS ARE MANDATORY HERE (charter section, GH #176):
  * ILLUSIONS share their hero's name AND player_id and differ only in `idx`.
    The discriminator is BIRTH TIME (the real hero is sampled before the horn,
    t < 0), not hp and not displacement.  Counting an illusion as an enemy
    inflates column (2) -- the exact column this request turns on.
  * ALIVENESS is decided on BRACKETING samples, never on an interpolated hp:
    a dead hero interpolates to hp>0 and to a position it never stood on.

Usage:
    axebhrecast_domain.py TIMELINE.json [TIMELINE.json ...] [--json OUT]
    axebhrecast_domain.py --selfcheck
"""

import argparse
import glob
import json
import math
import os
import sys
from collections import Counter, defaultdict

CAST_ABILITY = "axe_battle_hunger"
CALL_ABILITY = "axe_berserkers_call"
DEBUFF = "modifier_axe_battle_hunger"
CASTER_SELF_REAL = "modifier_axe_battle_hunger_self_movespeed"
CASTER_SELF_TESTED = "modifier_axe_battle_hunger_self"  # the dead string in bots/
AXE = "npc_dota_hero_axe"
SHARD_ITEM = "aghanims_shard"  # snapshots strip the `item_` prefix

DURATION = 12.0                       # ability KV `duration`, no level ladder
KILL_WINDOW = 5.0                     # "did the re-cast target die shortly after"
CAST_RANGE = [600.0, 700.0, 800.0, 900.0]   # AbilityCastRange by rank
SAMPLE_TOL = 0.75                     # snapshots are 1.0s apart


def _dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def real_hero_streams(snapshots):
    """(hero, idx) streams that belong to the REAL hero, not an illusion.

    Discriminator is birth time: the engine samples the real hero before the
    horn (t < 0).  Where no stream of a name qualifies (a hero that somehow was
    never sampled pre-horn), fall back to the longest stream and flag it, so
    the caller can see the fallback rather than silently trusting it.
    """
    by_name = defaultdict(list)
    for s in snapshots:
        by_name[s["hero"]].append(s)
    streams = {}
    fallbacks = []
    for name, rows in by_name.items():
        by_idx = defaultdict(list)
        for r in rows:
            by_idx[r["idx"]].append(r)
        pre = [i for i, v in by_idx.items() if min(x["t"] for x in v) < 0]
        if len(pre) == 1:
            keep = pre[0]
        elif len(pre) > 1:
            keep = min(pre, key=lambda i: min(x["t"] for x in by_idx[i]))
            fallbacks.append((name, "multiple pre-horn streams"))
        else:
            keep = max(by_idx, key=lambda i: len(by_idx[i]))
            fallbacks.append((name, "no pre-horn stream"))
        streams[name] = sorted(by_idx[keep], key=lambda x: x["t"])
    return streams, fallbacks


def bracket(rows, t):
    """(before, after) samples straddling t, or (None, None) if t is outside."""
    lo, hi = 0, len(rows) - 1
    if not rows or t < rows[0]["t"] - SAMPLE_TOL or t > rows[-1]["t"] + SAMPLE_TOL:
        return None, None
    while lo < hi:
        mid = (lo + hi) // 2
        if rows[mid]["t"] < t:
            lo = mid + 1
        else:
            hi = mid
    after = rows[lo]
    before = rows[lo - 1] if lo > 0 else rows[lo]
    return before, after


def alive_at(rows, t):
    """Alive iff BOTH bracketing samples are alive and both are near t.

    Never interpolates hp.  A dead hero whose bracket spans its death is
    reported not-alive, which is the conservative direction for column (2).
    """
    b, a = bracket(rows, t)
    if b is None or a is None:
        return False, None
    if abs(b["t"] - t) > SAMPLE_TOL + 1.0 or abs(a["t"] - t) > SAMPLE_TOL + 1.0:
        return False, None
    if b["hp"] <= 0 or a["hp"] <= 0:
        return False, None
    near = b if abs(b["t"] - t) <= abs(a["t"] - t) else a
    return True, near


def nearest(rows, t, tol=SAMPLE_TOL):
    b, a = bracket(rows, t)
    cands = [r for r in (b, a) if r is not None and abs(r["t"] - t) <= tol]
    if not cands:
        return None
    return min(cands, key=lambda r: abs(r["t"] - t))


def shard_onset(events, tol=0.15):
    """Game time of the first Berserker's Call that also applied Battle Hunger.

    `applies_battle_hunger` reaches axe_berserkers_call from `special_bonus_shard`
    and from nowhere else, so this coincidence IS the shard.  Returns None when
    no Call in the replay carries the signature (no shard, or never landed one).
    LATE BY CONSTRUCTION -- see the module docstring; treat as an upper bound.
    """
    calls = sorted(e["t"] for e in events
                   if e["type"] == "ABILITY" and e.get("inflictor") == CALL_ABILITY)
    adds = sorted(e["t"] for e in events
                  if e["type"] == "MODIFIER_ADD" and e.get("inflictor") == DEBUFF)
    if not calls or not adds:
        return None
    ai = 0
    for c in calls:
        while ai < len(adds) and adds[ai] < c - tol:
            ai += 1
        if ai < len(adds) and abs(adds[ai] - c) <= tol:
            return c
    return None


def debuff_intervals(events):
    """target -> sorted list of (t_add, t_remove) for modifier_axe_battle_hunger.

    An ADD with no matching REMOVE runs to +inf (the replay ended holding it).
    """
    opens = defaultdict(list)
    out = defaultdict(list)
    for e in events:
        if e.get("inflictor") != DEBUFF:
            continue
        tgt = e.get("target") or ""
        if e["type"] == "MODIFIER_ADD":
            opens[tgt].append(e["t"])
        elif e["type"] == "MODIFIER_REMOVE":
            if opens[tgt]:
                out[tgt].append((opens[tgt].pop(0), e["t"]))
            else:
                out[tgt].append((e["t"], e["t"]))
    for tgt, rest in opens.items():
        for t0 in rest:
            out[tgt].append((t0, float("inf")))
    for tgt in out:
        out[tgt].sort()
    return out


def open_interval_at(intervals, t, strict_before=True):
    """The interval covering t whose ADD is strictly before t (or None).

    `strict_before` is what separates a RE-cast from the cast's own ADD: the
    engine logs both at the same 0.1s tick, so an interval that starts AT t is
    this cast's own debuff, not a pre-existing one.
    """
    for t0, t1 in intervals:
        if (t0 < t if strict_before else t0 <= t) and t < t1:
            return (t0, t1)
    return None


def scan_timeline(path):
    with open(path) as fh:
        tl = json.load(fh)
    tag = os.path.basename(path).replace(".json", "")
    events = tl.get("events", [])
    snaps = tl.get("snapshots", [])
    teams = (tl.get("game") or {}).get("teams") or {}

    if AXE not in teams:
        return {"tag": tag, "skipped": "no axe in this game"}
    axe_team = teams[AXE]

    streams, fallbacks = real_hero_streams(snaps)
    axe_rows = streams.get(AXE, [])
    enemies = {n: r for n, r in streams.items()
               if teams.get(n) is not None and teams.get(n) != axe_team}

    intervals = debuff_intervals(events)
    onset = shard_onset(events)

    casts = [e for e in events
             if e["type"] == "ABILITY" and e.get("inflictor") == CAST_ABILITY
             and e.get("actor") == AXE]

    deaths = defaultdict(list)
    for e in events:
        if e["type"] == "DEATH":
            deaths[e.get("target") or ""].append((e["t"], e.get("actor") or "",
                                                  e.get("inflictor") or ""))
    for k in deaths:
        deaths[k].sort()

    self_real = sum(1 for e in events if e.get("inflictor") == CASTER_SELF_REAL)
    self_tested = sum(1 for e in events if e.get("inflictor") == CASTER_SELF_TESTED)

    rec = {
        "tag": tag,
        "axe_team": axe_team,
        "n_casts": len(casts),
        "n_casts_target_hero": 0,
        "n_casts_target_nonhero": 0,
        "n_recasts": 0,
        "n_recast_no_rank": 0,
        "self_modifier_real_sightings": self_real,
        "self_modifier_tested_string_sightings": self_tested,
        "illusion_fallbacks": fallbacks,
        "shard_onset_t": onset,
        "episodes": [],
    }

    for e in casts:
        t = e["t"]
        tgt = e.get("target") or ""
        if e.get("target_hero"):
            rec["n_casts_target_hero"] += 1
        else:
            rec["n_casts_target_nonhero"] += 1
        iv = open_interval_at(intervals.get(tgt, []), t)
        if iv is None:
            continue
        rec["n_recasts"] += 1

        axe_snap = nearest(axe_rows, t, tol=1.5)
        rank = 0
        shard_item = None
        if axe_snap is not None:
            for ab in axe_snap.get("abilities", []):
                if ab["name"] == CAST_ABILITY:
                    rank = int(ab["level"])
            shard_item = SHARD_ITEM in (axe_snap.get("items") or [])
        if rank < 1 or rank > 4 or axe_snap is None:
            rec["n_recast_no_rank"] += 1
            continue
        rng = CAST_RANGE[rank - 1]

        others_total = 0
        others_fresh = 0
        fresh_names = []
        for name, rows in enemies.items():
            if name == tgt:
                continue
            ok, near = alive_at(rows, t)
            if not ok or near is None:
                continue
            if _dist(axe_snap["x"], axe_snap["y"], near["x"], near["y"]) > rng:
                continue
            others_total += 1
            if open_interval_at(intervals.get(name, []), t, strict_before=False) is None:
                others_fresh += 1
                fresh_names.append(name)

        remaining = max(0.0, min(DURATION, DURATION - (t - iv[0])))
        died_in = None
        died_to = None
        for dt, dactor, dinfl in deaths.get(tgt, []):
            if t <= dt <= t + KILL_WINDOW:
                died_in = round(dt - t, 1)
                died_to = f"{dactor}/{dinfl}"
                break
        rec["episodes"].append({
            "t": round(t, 1),
            "target": tgt,
            "target_hero": bool(e.get("target_hero")),
            "rank": rank,
            "range": rng,
            "remaining": round(remaining, 2),
            "refresh_worth": round(DURATION - remaining, 2),
            "others_in_range": others_total,
            "others_in_range_unhungered": others_fresh,
            "unhungered_names": fresh_names,
            "axe_has_shard": (onset is not None and t >= onset),
            "shard_item_in_inventory": shard_item,
            "axe_level": axe_snap.get("level"),
            "target_died_in": died_in,
            "target_died_to": died_to,
        })
    return rec


def aggregate(recs):
    live = [r for r in recs if "skipped" not in r]
    agg = {
        "games_scanned": len(recs),
        "games_with_axe": len(live),
        "n_casts": sum(r["n_casts"] for r in live),
        "n_casts_target_hero": sum(r["n_casts_target_hero"] for r in live),
        "n_casts_target_nonhero": sum(r["n_casts_target_nonhero"] for r in live),
        "n_recasts": sum(r["n_recasts"] for r in live),
        "n_recast_no_rank": sum(r["n_recast_no_rank"] for r in live),
        "self_modifier_real_sightings": sum(r["self_modifier_real_sightings"] for r in live),
        "self_modifier_tested_string_sightings":
            sum(r["self_modifier_tested_string_sightings"] for r in live),
    }
    eps = [e for r in live for e in r["episodes"]]
    agg["n_episodes"] = len(eps)
    in_domain = [e for e in eps if not e["axe_has_shard"]]
    agg["n_episodes_shard_held"] = len(eps) - len(in_domain)
    agg["n_episodes_in_gate_domain"] = len(in_domain)

    # Column (2): integer-valued, small support -> distribution + threshold
    # shares, never a median (iron rule 4(ii)).
    dist = Counter(e["others_in_range_unhungered"] for e in in_domain)
    agg["unhungered_in_range_dist"] = dict(sorted(dist.items()))
    n = len(in_domain) or 1
    agg["share_zero_candidates"] = round(dist.get(0, 0) / n, 4)
    agg["share_ge1_candidates"] = round(sum(v for k, v in dist.items() if k >= 1) / n, 4)
    agg["share_ge2_candidates"] = round(sum(v for k, v in dist.items() if k >= 2) / n, 4)
    agg["mean_unhungered"] = round(sum(e["others_in_range_unhungered"] for e in in_domain) / n, 3)

    tot = Counter(e["others_in_range"] for e in in_domain)
    agg["others_in_range_dist"] = dict(sorted(tot.items()))

    # Column (3): remaining time, bucketed.
    buckets = Counter()
    for e in in_domain:
        buckets[min(11, int(e["remaining"]))] += 1
    agg["remaining_sec_bucket_dist"] = dict(sorted(buckets.items()))
    if in_domain:
        agg["mean_remaining"] = round(sum(e["remaining"] for e in in_domain) / n, 3)
        agg["mean_refresh_worth"] = round(sum(e["refresh_worth"] for e in in_domain) / n, 3)

    # The kill-confirm split.  A re-cast whose target dies within KILL_WINDOW is
    # plausibly the KILL LOOP's, and that site is deliberately unwired -- so it
    # can be neither forgone benefit nor lever cost.  Reported separately, never
    # pooled into column (2), and NOT claimed as branch identification.
    killed = [e for e in in_domain if e["target_died_in"] is not None]
    by_axe = [e for e in killed if e["target_died_to"] and e["target_died_to"].startswith(AXE)]
    agg["n_target_died_within_5s"] = len(killed)
    agg["n_target_died_to_axe_within_5s"] = len(by_axe)
    agg["share_kill_confirm"] = round(len(killed) / n, 4)
    agg["killer_inflictor_top"] = dict(
        Counter(e["target_died_to"] for e in killed).most_common(6))
    survivors = [e for e in in_domain if e["target_died_in"] is None]
    agg["n_episodes_target_survived"] = len(survivors)
    if survivors:
        sd = Counter(e["others_in_range_unhungered"] for e in survivors)
        agg["survivor_unhungered_dist"] = dict(sorted(sd.items()))
        agg["survivor_share_ge1"] = round(
            sum(v for k, v in sd.items() if k >= 1) / len(survivors), 4)

    agg["rank_dist"] = dict(sorted(Counter(e["rank"] for e in in_domain).items()))
    agg["by_rank_share_ge1"] = {}
    for rk in sorted(set(e["rank"] for e in in_domain)):
        sub = [e for e in in_domain if e["rank"] == rk]
        agg["by_rank_share_ge1"][rk] = [
            len(sub), round(sum(1 for e in sub if e["others_in_range_unhungered"] >= 1) / len(sub), 4)]

    per_game = {}
    for r in live:
        dom = [e for e in r["episodes"] if not e["axe_has_shard"]]
        per_game[r["tag"]] = {
            "casts": r["n_casts"], "recasts": r["n_recasts"],
            "episodes_in_domain": len(dom),
            "ge1": sum(1 for e in dom if e["others_in_range_unhungered"] >= 1),
        }
    agg["per_game"] = per_game

    # The benefit-side exemplars the request asked for, best first.
    best = sorted((e for r in live for e in r["episodes"]
                   if not e["axe_has_shard"] and e["others_in_range_unhungered"] >= 1),
                  key=lambda e: (-e["others_in_range_unhungered"], -e["remaining"]))
    agg["exemplars"] = []
    for r in live:
        for e in r["episodes"]:
            if e in best[:12]:
                agg["exemplars"].append(dict(e, game=r["tag"]))
    agg["column4_branch_stratification"] = (
        "INSTRUMENT-BLIND: the dump carries no bot-side mode or branch identity, "
        "so which of the eight X.ConsiderW sites issued a cast is not recoverable. "
        "Not guessed. Section CJ INSTRUMENT-BLIND return, not a DOMAIN-NOT-REACHED.")
    return agg


# ---------------------------------------------------------------- selfcheck

def _mk(t, hero, idx, team, x, y, hp=100, lvl=6, bh=1, items=None):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "player_id": 0,
            "x": x, "y": y, "hp": hp, "hp_pct": hp / 100.0, "mp": 100,
            "max_mp": 100, "mp_pct": 1.0, "level": lvl,
            "items": items if items is not None else [],
            "abilities": [{"name": CAST_ABILITY, "level": bh, "cd": 0, "cd_len": 20}]}


def selfcheck():
    checks = []

    def ck(name, got, want):
        ok = got == want
        checks.append((name, ok, got, want))

    # --- open_interval_at: the cast's own ADD must not count as a re-cast.
    ck("own add is not a recast", open_interval_at([(30.1, 42.1)], 30.1), None)
    ck("earlier add is a recast", open_interval_at([(25.0, 37.0)], 30.1), (25.0, 37.0))
    ck("expired add is not", open_interval_at([(10.0, 22.0)], 30.1), None)
    ck("non-strict sees own add",
       open_interval_at([(30.1, 42.1)], 30.1, strict_before=False), (30.1, 42.1))

    # --- illusions: same name+player_id, later birth.
    snaps = ([_mk(-5 + i, "npc_dota_hero_luna", 1, 3, 0, 0) for i in range(20)] +
             [_mk(5 + i, "npc_dota_hero_luna", 2, 3, 500, 0) for i in range(10)])
    streams, fb = real_hero_streams(snaps)
    ck("illusion excluded by birth", streams["npc_dota_hero_luna"][0]["idx"], 1)
    ck("no fallback flagged", fb, [])
    snaps2 = [_mk(5 + i, "npc_dota_hero_luna", 2, 3, 500, 0) for i in range(10)]
    _, fb2 = real_hero_streams(snaps2)
    ck("no-pre-horn stream is flagged", len(fb2), 1)

    # --- aliveness on bracketing samples, never interpolated.
    rows = [_mk(float(i), "e", 1, 3, 0, 0, hp=(100 if i < 10 else 0)) for i in range(20)]
    ck("alive before death", alive_at(rows, 5.0)[0], True)
    ck("dead after death", alive_at(rows, 15.0)[0], False)
    ck("bracket spanning death is not alive", alive_at(rows, 9.5)[0], False)
    ck("outside sampled span is not alive", alive_at(rows, 99.0)[0], False)

    # --- debuff_intervals pairing
    ev = [{"t": 1.0, "type": "MODIFIER_ADD", "target": "a", "inflictor": DEBUFF},
          {"t": 13.0, "type": "MODIFIER_REMOVE", "target": "a", "inflictor": DEBUFF},
          {"t": 20.0, "type": "MODIFIER_ADD", "target": "a", "inflictor": DEBUFF}]
    iv = debuff_intervals(ev)
    ck("two intervals, last open", iv["a"], [(1.0, 13.0), (20.0, float("inf"))])
    ck("other modifiers ignored",
       debuff_intervals([{"t": 1.0, "type": "MODIFIER_ADD", "target": "a",
                          "inflictor": CASTER_SELF_REAL}]), {})

    # --- end to end: one re-cast, one unhungered candidate in range, one out.
    tl = {"game": {"teams": {AXE: 2, "e1": 3, "e2": 3, "e3": 3}}, "snapshots": [], "events": []}
    for i in range(-5, 60):
        tl["snapshots"].append(_mk(float(i), AXE, 10, 2, 0, 0, bh=1))
        tl["snapshots"].append(_mk(float(i), "e1", 11, 3, 100, 0))     # in 600 range
        tl["snapshots"].append(_mk(float(i), "e2", 12, 3, 300, 0))     # in range
        tl["snapshots"].append(_mk(float(i), "e3", 13, 3, 5000, 0))    # far out
    tl["events"] = [
        {"t": 10.0, "type": "ABILITY", "actor": AXE, "target": "e1",
         "inflictor": CAST_ABILITY, "target_hero": True},
        {"t": 10.0, "type": "MODIFIER_ADD", "target": "e1", "inflictor": DEBUFF},
        {"t": 14.0, "type": "ABILITY", "actor": AXE, "target": "e1",
         "inflictor": CAST_ABILITY, "target_hero": True},
    ]
    p = "/tmp/_axebh_selfcheck.json"
    with open(p, "w") as fh:
        json.dump(tl, fh)
    r = scan_timeline(p)
    os.unlink(p)
    ck("2 casts seen", r["n_casts"], 2)
    ck("exactly 1 recast", r["n_recasts"], 1)
    ck("1 episode", len(r["episodes"]), 1)
    e = r["episodes"][0]
    ck("rank 1 range 600", e["range"], 600.0)
    ck("remaining 8s of 12", e["remaining"], 8.0)
    ck("refresh worth 4s", e["refresh_worth"], 4.0)
    ck("e2 in range, e3 not", e["others_in_range"], 1)
    ck("e2 counted unhungered", e["others_in_range_unhungered"], 1)
    ck("no shard", e["axe_has_shard"], False)
    ck("no death, no kill-confirm", e["target_died_in"], None)

    # kill-confirm column: a death inside the window is attributed, one outside
    # is not.
    tl_k = json.loads(json.dumps(tl))
    tl_k["events"] = tl["events"] + [
        {"t": 16.0, "type": "DEATH", "actor": AXE, "target": "e1",
         "inflictor": "axe_culling_blade"}]
    with open(p, "w") as fh:
        json.dump(tl_k, fh)
    rk = scan_timeline(p)
    os.unlink(p)
    ck("death inside window attributed", rk["episodes"][0]["target_died_in"], 2.0)
    ck("killer recorded", rk["episodes"][0]["target_died_to"],
       f"{AXE}/axe_culling_blade")
    ak = aggregate([rk])
    ck("kill-confirm counted", ak["n_target_died_within_5s"], 1)
    ck("survivors excluded", ak["n_episodes_target_survived"], 0)
    tl_k["events"][-1]["t"] = 30.0
    with open(p, "w") as fh:
        json.dump(tl_k, fh)
    rk2 = scan_timeline(p)
    os.unlink(p)
    ck("death outside window not attributed", rk2["episodes"][0]["target_died_in"], None)

    # --- shard: the BEHAVIOURAL detector, not the inventory.
    #     Carrying the item in `items` must NOT by itself put an episode out of
    #     domain -- that reading is what produced a manufactured zero.
    tl_inv = json.loads(json.dumps(tl))
    tl_inv["snapshots"] = [dict(s, items=[SHARD_ITEM]) if s["hero"] == AXE else s
                           for s in tl_inv["snapshots"]]
    with open(p, "w") as fh:
        json.dump(tl_inv, fh)
    r_inv = scan_timeline(p)
    os.unlink(p)
    ck("inventory item alone is not the gate term", r_inv["episodes"][0]["axe_has_shard"], False)
    ck("inventory sighting still registered",
       r_inv["episodes"][0]["shard_item_in_inventory"], True)

    ck("no call, no onset", shard_onset(tl["events"]), None)
    clean_call = tl["events"] + [
        {"t": 40.0, "type": "ABILITY", "actor": AXE, "target": "",
         "inflictor": CALL_ABILITY}]
    ck("a call that applies nothing is not a shard", shard_onset(clean_call), None)
    shard_call = clean_call + [
        {"t": 40.0, "type": "MODIFIER_ADD", "target": "e2", "inflictor": DEBUFF}]
    ck("call + coincident BH add dates the shard", shard_onset(shard_call), 40.0)
    ck("an add far from the call does not count",
       shard_onset(clean_call + [{"t": 55.0, "type": "MODIFIER_ADD", "target": "e2",
                                  "inflictor": DEBUFF}]), None)

    # onset AFTER the episode leaves it in domain; onset BEFORE takes it out.
    tl_s = json.loads(json.dumps(tl))
    tl_s["events"] = shard_call
    with open(p, "w") as fh:
        json.dump(tl_s, fh)
    r_late = scan_timeline(p)
    os.unlink(p)
    ck("onset after the episode keeps it in domain",
       r_late["episodes"][0]["axe_has_shard"], False)
    ck("onset recorded", r_late["shard_onset_t"], 40.0)

    tl_s["events"] = tl["events"] + [
        {"t": 8.0, "type": "ABILITY", "actor": AXE, "target": "", "inflictor": CALL_ABILITY},
        {"t": 8.0, "type": "MODIFIER_ADD", "target": "e2", "inflictor": DEBUFF}]
    with open(p, "w") as fh:
        json.dump(tl_s, fh)
    r_early = scan_timeline(p)
    os.unlink(p)
    ck("onset before the episode takes it out",
       r_early["episodes"][0]["axe_has_shard"], True)
    a2 = aggregate([r_early])
    ck("shard episode is out of domain", a2["n_episodes_in_gate_domain"], 0)
    ck("shard episode still registered", a2["n_episodes_shard_held"], 1)

    # a hungered neighbour is not a spread candidate
    tl["snapshots"] = [dict(s, items=[]) if s["hero"] == AXE else s for s in tl["snapshots"]]
    tl["events"] = tl["events"] + [
        {"t": 9.0, "type": "MODIFIER_ADD", "target": "e2", "inflictor": DEBUFF}]
    with open(p, "w") as fh:
        json.dump(tl, fh)
    r3 = scan_timeline(p)
    os.unlink(p)
    ck("hungered neighbour excluded", r3["episodes"][0]["others_in_range_unhungered"], 0)
    ck("but still counted in range", r3["episodes"][0]["others_in_range"], 1)

    # a dead neighbour is not a spread candidate
    tl["events"] = tl["events"][:3]
    tl["snapshots"] = [dict(s, hp=0, hp_pct=0.0) if s["hero"] == "e2" and s["t"] >= 5 else s
                       for s in tl["snapshots"]]
    with open(p, "w") as fh:
        json.dump(tl, fh)
    r4 = scan_timeline(p)
    os.unlink(p)
    ck("dead neighbour excluded", r4["episodes"][0]["others_in_range"], 0)

    # aggregate never reports a median for the count column
    ck("no median key in aggregate",
       any("median" in k or "med_" in k for k in aggregate([r]).keys()), False)

    fails = [c for c in checks if not c[1]]
    for name, ok, got, want in checks:
        if not ok:
            print(f"FAIL {name}: got {got!r} want {want!r}")
    print(f"{len(checks) - len(fails)} PASS / {len(fails)} FAIL")
    return 0 if not fails else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*")
    ap.add_argument("--json", dest="out")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()

    paths = []
    for t in args.timelines:
        paths.extend(sorted(glob.glob(t)) if any(c in t for c in "*?[") else [t])
    if not paths:
        print("no timelines given", file=sys.stderr)
        return 2

    recs = [scan_timeline(p) for p in paths]
    agg = aggregate(recs)
    if args.out:
        with open(args.out, "w") as fh:
            json.dump({"aggregate": agg, "per_timeline": recs}, fh, indent=1)
    print(json.dumps(agg, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())

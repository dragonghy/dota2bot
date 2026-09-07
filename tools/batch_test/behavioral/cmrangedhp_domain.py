#!/usr/bin/env python3
"""`cmrangedhp` condition-(a) domain census over an archived Crystal Maiden corpus.

WHAT THIS ANSWERS (queue row hero-36; GH #560; director ruling APPROVED-SCAN
2026-09-06, test_set.md §FI.2 -- a zero-EC2 read-only archive traversal)
-----------------------------------------------------------------------------
`cmrangedhp` (hero_crystal_maiden.lua `X.cm_GetRangedCreepReportedHealth`,
gated, never armed) makes the ranged-creep early exit of `X.cm_GetStrongestUnit`
report the creep's OWN health instead of the literal `500`.  The consumer is a
single block of `X.ConsiderW` ("无英雄目标时冰冻小兵打钱"), which reads that
second return value as a health five times.

THE QUEUE ROW ASKED FOR FOUR COLUMNS.  This tool reports what the archive can
actually answer and refuses to manufacture the rest:

  (1) frostbite casts whose TARGET IS A CREEP, split by target unit name
      (melee / ranged / siege / neutral / upgraded / mega / summon)   -> READ
  (2) the real health of that ranged creep at the cast instant        -> BLIND
      `creeps[]` in the dump carries exactly {t, team, x, y} -- no health, no
      name, no entity index -- so the frozen creep cannot even be IDENTIFIED in
      the position stream, let alone read.  `key_shapes` below is the measured
      census of that, per game, so the claim is a reading and not an assertion.
      ⭐ What IS sound is a ONE-SIDED bound, and it is reported as one:
      Frostbite's own damage ticks against the frozen creep are combat-log
      DAMAGE rows with `inflictor = crystal_maiden_frostbite` and a hero actor,
      so they survive the dumper's noise filter.  A creep that is still alive
      after k ticks had MORE health at the cast than the first k ticks dealt:
          hp_at_cast  >  sum(ticks) - last_tick          [hp_lb]
      That is a LOWER bound and only a lower bound.  It can PROVE a cast was
      not in the wasted window `(2*ad, 460]`; it can never prove one was.
      ⭐ And a CONDITIONAL upper bound, reported under its own key so it can
      never be quoted as the health: when the combat log's own DEATH row names
      `crystal_maiden_frostbite` as the killing inflictor AND no other
      hero-sourced damage row touched that target in the episode, the health
      at the cast was at most the frostbite total.  THE ASSUMPTION IS NAMED,
      NOT HIDDEN: the dumper keeps a damage row only when a hero is on one end
      of it, so allied-creep and tower damage is invisible and could have
      contributed.  `other_hero_dmg_in_window == 0` therefore means "no HERO
      also hit it", never "nothing else hit it".
  (3) Frostbite rank at the cast (-> nCreepCap)                       -> READ
      CM's attack damage (the `2*ad` admission gate)                  -> BLIND
      `snapshots[]` carries no attack damage and no attack speed.  The queue
      row hoped the .dem would supply what the fixture corpus could not; it
      does not.  Reported as INSTRUMENT-BLIND, never as 0 (a 0 would make the
      admission test degenerate to `GetHealth() > 0` and read as "widest
      possible window" -- that is the instrument, not the game).
  (4) branch attribution -- only the money block is wired             -> PARTIAL
      Its own preconditions are `#nEnemysHeroesInView == 0` (1600u, VISIBLE),
      `#nAllies < 3` (1200u), `nLV >= 5`, and a mode that is not
      LANING/RETREAT/ATTACK.  Geometry is in the dump; VISION and MODE are not.
      Both directions are registered and never swapped:
        * geometric-zero enemies within 1600 IMPLIES engine-side zero visible
          (you cannot see a hero that is not there) -> a SUFFICIENT condition,
          so that subset is a LOWER bound on the block's own domain;
        * a geometric hero inside 1600 need not have been visible -> the
          complement is an UPPER bound, not a refutation.
      `GetActiveMode()` is bot-internal and absent from any replay, so every
      count here is an UPPER bound on the block's true reach.

THE 10-MINUTE GATE, AND THE ONE NAME THAT WALKS THROUGH IT
-----------------------------------------------------------
Both halves of the money block are guarded by

    DotaTime() > 10*60  or  <target name is none of the four lane names>

and `npc_dota_creep_{badguys,goodguys}_{melee,ranged}` are exactly those four.
So a BASE ranged lane creep -- the archetype the lever's exit is written for --
can only be frozen by this block after 10:00.  But the exit itself matches on
`string.find(name, 'ranged')`, which ALSO matches
`npc_dota_creep_*_ranged_upgraded` and `..._upgraded_mega`, and those are NOT
equal to any of the four literals, so for them the disjunct is true and the
block is open from the first second.  The census therefore splits every ranged
cast into `gated_name` (one of the four) and `ungated_name` (upgraded/mega) and
crosses that with the 600s line, instead of assuming the domain sits after 10:00.

⚠️ THE CAP TERM IS DEAD ON THE SHIPPED TREE, AND THAT RESIZES THE DEFECT
-------------------------------------------------------------------------
`X.cm_GetFrostbiteCreepCap` returns a flat 1200 unless `cmcreepcap` (hero-33,
GH #541) is armed -- and it is not armed anywhere in this corpus.  The picker
itself admits only `unit:GetHealth() <= 1100`.  So on the shipped tree
`health <= nCreepCap` is 1100 <= 1200: VACUOUSLY TRUE on every exit, including
this one.  The "IT LIES LOW" half of the defect (window `(nCreepCap, 1100]`,
non-empty at ranks 1-3) is therefore NOT reachable by arming `cmrangedhp`
alone; it needs `cmcreepcap` armed at the same time.  The two gates are
separable as code -- the new test file asserts that -- but the second of the
two cost directions is not separable in EFFECT.  Arming `cmrangedhp` by itself
can only bite through the four FLOORS (460/410/390/360), i.e. only the
`(2*ad, 460]` "lies high" window.  That is a source-level fact, checkable in
one grep, and it is pinned in selfcheck rather than left in prose.

USAGE
-----
    cmrangedhp_domain.py --selfcheck
    cmrangedhp_domain.py --game TIMELINE.json --out REC.json
    cmrangedhp_domain.py --aggregate REC_DIR
"""

import argparse
import json
import os
import sys
import glob
import collections

CM = "npc_dota_hero_crystal_maiden"
FROSTBITE = "crystal_maiden_frostbite"
FROSTBITE_MOD = "modifier_crystal_maiden_frostbite"

# KV snapshot, tests/mock/special_value_shapes.lua: duration 1.5/2/2.5/3,
# damage_per_second 100, creep_multiplier 4  ->  creep damage 600/800/1000/1200.
FROSTBITE_DURATION = [1.5, 2.0, 2.5, 3.0]
FROSTBITE_MANA = [125, 135, 145, 155]

# The four literal names the money block's 10-minute disjunct spells out.
GATED_LANE_NAMES = {
    "npc_dota_creep_badguys_melee",
    "npc_dota_creep_badguys_ranged",
    "npc_dota_creep_goodguys_melee",
    "npc_dota_creep_goodguys_ranged",
}

# The four floors the reported health is compared against, read off the source
# rather than retyped -- consumer_floors() below re-reads them and selfcheck
# fails if the file moves.  This mirrors the GH #560 lesson: the load-bearing
# assertion has to be one that CAN fail.
EXPECTED_FLOORS = [460, 410, 390, 360]

# How far BEFORE the ABILITY row the decision instant can sit.  The picker read
# `GetHealth()` inside ConsiderW; the combat-log ABILITY row fires only after
# Frostbite's cast point (0.35s) plus the think-to-order latency.  Any damage in
# that interval landed AFTER the health was read and BEFORE the log row, so it
# invalidates a bound computed from the ticks.
#
# ⚠️ THIS CONSTANT IS A CORRECTION, AND THE ROUND THAT MADE IT SHOULD SAY SO.
# The first version used 0.2s and was caught by frame-checking its own shortlist
# (2026-09-07, game 20260831_005511_slot1, t=705.5): an ALLIED Storm Spirit hit
# the same creep for 221 at t=705.1 -- 0.4s before the cast, i.e. OUTSIDE a 0.2s
# pre-roll -- and Frostbite's single 22-damage tick then killed it.  The bound
# survived and read "this creep had 22 health", when what the picker saw was
# ~243.  Same family as GH #176 and the WK respawn window: THE INSTRUMENT
# MANUFACTURED THE READING IT THEN REPORTED, and only a frame-by-frame look at
# its own output found it.
DECISION_PRE_ROLL = 1.0

MONEY_BLOCK_MIN_LEVEL = 5
ENEMY_VIEW_RADIUS = 1600.0
ALLY_RADIUS = 1200.0
ALLY_MAX = 3
PICKER_HEALTH_CEILING = 1100
SHIPPED_CREEP_CAP = 1200  # cm_GetFrostbiteCreepCap with cmcreepcap un-armed

HERO_SRC = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "..", "bots", "BotLib", "hero_crystal_maiden.lua")


def consumer_floors(path=None):
    """Read the four floors out of hero_crystal_maiden.lua's money block.

    Written as a READ, not a constant, for the reason GH #560 states about its
    own direction argument: an assertion that cannot fail is not evidence.  If
    someone raises `> 460` to `> 560`, `500` stops clearing every floor, the
    'arming can only narrow' sentence stops being true, and this returns a
    different list so selfcheck goes red.
    """
    path = path or HERO_SRC
    try:
        src = open(path, encoding="utf-8").read()
    except OSError:
        return None
    # The money block is the only place these five terms appear as code.
    body = src.split("--无英雄目标时冰冻小兵打钱", 1)
    if len(body) < 2:
        return None
    body = body[1].split("--进攻", 1)[0]
    floors = []
    for line in body.splitlines():
        if "nEnemysStrongestCreepsHealth" not in line or ">" not in line:
            continue
        for tok in line.replace("(", " ").replace(")", " ").split():
            if tok.isdigit():
                floors.append(int(tok))
    return floors


def classify_target(name):
    """Bucket a frostbite target name.  Buckets are disjoint and exhaustive."""
    if not name:
        return "unknown"
    if name.startswith("npc_dota_hero_"):
        return "hero"
    if name.startswith("npc_dota_neutral"):
        return "neutral"
    lane = name.startswith("npc_dota_creep_badguys_") or \
        name.startswith("npc_dota_creep_goodguys_")
    if lane:
        if "siege" in name:
            return "lane_siege"
        if "ranged" in name:
            if "mega" in name:
                return "lane_ranged_mega"
            if "upgraded" in name:
                return "lane_ranged_upgraded"
            return "lane_ranged"
        if "melee" in name:
            if "mega" in name:
                return "lane_melee_mega"
            if "upgraded" in name:
                return "lane_melee_upgraded"
            return "lane_melee"
        return "lane_other"
    return "other"


def hits_ranged_exit(name):
    """Does `string.find(name, 'ranged') ~= nil` hold?  That is the exit's own
    test -- NOT the bucket, and not equality with the four literals."""
    return bool(name) and "ranged" in name


def creep_team_from_name(name):
    """2 = Radiant (goodguys), 3 = Dire (badguys), None for neutrals/unknown."""
    if not name:
        return None
    if "goodguys" in name:
        return 2
    if "badguys" in name:
        return 3
    return None


def real_hero_streams(snaps):
    """Group snapshots into entity streams keyed by (hero, idx).

    Illusions share the hero NAME and the player_id and differ only in `idx`
    (charter 2026-08-25 / GH #176).  The discriminator is the SPAWN INSTANT --
    a real hero is sampled before the horn (t < 0) -- not health and not
    movement.  Streams that never appear before t=0 are dropped as suspicious.
    """
    by_key = collections.defaultdict(list)
    for s in snaps:
        by_key[(s.get("hero"), s.get("idx"))].append(s)
    out = {}
    for key, rows in by_key.items():
        rows.sort(key=lambda r: r["t"])
        if rows[0]["t"] < 0:
            out[key] = rows
    return out


def bracket(rows, t):
    """Return (prev, next) samples bracketing t.  Either may be None."""
    prev = nxt = None
    lo, hi = 0, len(rows) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if rows[mid]["t"] <= t:
            prev = rows[mid]
            lo = mid + 1
        else:
            nxt = rows[mid]
            hi = mid - 1
    return prev, nxt


def near_count(streams, t, cx, cy, radius, team, want_enemy, exclude_key):
    """Count hero entities of the wanted side within `radius` of (cx, cy) at t.

    CONSERVATIVE BY CONSTRUCTION, in the direction the charter demands: a hero
    counts if EITHER bracketing sample is inside the ring and that sample shows
    it alive.  Never interpolates hp (GH #176 (2): an alive sample and a dead
    sample interpolate to a live-looking 0.05 and place the hero where it never
    stood).  Over-counting makes `== 0` HARDER to reach, so the zero-set this
    produces is a subset of the true zero-set.
    """
    n = 0
    for key, rows in streams.items():
        if key == exclude_key:
            continue
        p, q = bracket(rows, t)
        side = None
        for s in (p, q):
            if s is not None:
                side = s.get("team")
                break
        if side is None:
            continue
        is_enemy = (side != team)
        if is_enemy != want_enemy:
            continue
        for s in (p, q):
            if s is None:
                continue
            if abs(s["t"] - t) > 2.0:
                continue
            if (s.get("hp_pct") or 0) <= 0:
                continue
            dx = s["x"] - cx
            dy = s["y"] - cy
            if dx * dx + dy * dy <= radius * radius:
                n += 1
                break
    return n


def frostbite_rank(rows, t):
    """Frostbite level from the last snapshot at or before t (0 if unknown)."""
    p, _ = bracket(rows, t)
    if p is None:
        return 0
    for a in p.get("abilities") or []:
        if a.get("name") == FROSTBITE:
            return int(a.get("level") or 0)
    return 0


def hp_lower_bound(ticks):
    """Sound lower bound on the target's health at the cast instant.

    `ticks` are the frostbite DAMAGE values against this target in the episode,
    in time order.  The unit survived every tick but (possibly) the last, so
    its health exceeded the sum of all but the last.  Returns None when there
    is nothing to bound with.

    This is a LOWER bound and is never to be read as the health: the dumper's
    noise filter drops creep-on-creep and tower damage, so the true health can
    be far above it.  It can prove `hp > 460`; it can never prove `hp <= 460`.
    """
    if not ticks:
        return None
    return sum(ticks[:-1])


def scan_game(tl, game_id):
    snaps = tl.get("snapshots") or []
    events = tl.get("events") or []
    creeps = tl.get("creeps") or []

    # --- the named question: what does creeps[] actually carry? -------------
    key_shapes = collections.Counter()
    for c in creeps:
        key_shapes["|".join(sorted(c.keys()))] += 1

    streams = real_hero_streams(snaps)
    cms = {k: v for k, v in streams.items() if k[0] == CM}
    cm_teams = {}
    for k, rows in cms.items():
        for r in rows:
            if r.get("team"):
                cm_teams[k] = r["team"]
                break

    rec = {
        "game": game_id,
        "creep_rows": len(creeps),
        "creep_key_shapes": dict(key_shapes),
        "n_cm_streams": len(cms),
        "cm_teams": sorted(set(cm_teams.values())),
        "casts": [],
        "snapshot_has_attack_damage": any(
            "attack_damage" in s or "ad" in s for s in snaps[:50]),
    }
    if not cms:
        return rec

    # Frostbite DAMAGE rows, bucketed by target name in time order.
    dmg_by_target = collections.defaultdict(list)
    for e in events:
        if e.get("type") == "DAMAGE" and e.get("inflictor") == FROSTBITE:
            dmg_by_target[e.get("target")].append((e["t"], e.get("value") or 0))
    for v in dmg_by_target.values():
        v.sort()

    deaths_by_target = collections.defaultdict(list)
    for e in events:
        if e.get("type") == "DEATH":
            deaths_by_target[e.get("target")].append(
                (e["t"], e.get("actor"), e.get("inflictor")))
    for v in deaths_by_target.values():
        v.sort()

    # Every OTHER hero-sourced damage row against the same target name.  The
    # dumper's noise filter drops creep-on-creep and tower damage, so an empty
    # list does NOT mean nothing else hit the creep -- it means nothing a HERO
    # did hit it.  That distinction is the whole caveat on the conditional
    # upper bound below and it is kept in the data, not only in prose.
    other_dmg_by_target = collections.defaultdict(list)
    for e in events:
        if e.get("type") in ("DAMAGE", "CRITICAL_DAMAGE") \
                and e.get("inflictor") != FROSTBITE:
            other_dmg_by_target[e.get("target")].append(
                (e["t"], e.get("value") or 0))
    for v in other_dmg_by_target.values():
        v.sort()

    creeps_by_t = collections.defaultdict(list)
    for c in creeps:
        creeps_by_t[round(c["t"], 1)].append(c)

    casts = [e for e in events
             if e.get("type") == "ABILITY" and e.get("inflictor") == FROSTBITE
             and e.get("actor") == CM]
    casts.sort(key=lambda e: e["t"])

    for i, e in enumerate(casts):
        t0 = e["t"]
        tgt = e.get("target")
        bucket = classify_target(tgt)

        # --- which CM cast it? --------------------------------------------
        # A creep target's own name carries its team, so the caster is the
        # other side.  With one CM in the game the answer is direct.  With two
        # CMs and a neutral target it is genuinely unknown -> `ambiguous`,
        # never silently booked to one of them (charter's zusult lesson: a
        # guess written as a fact launders "don't know" into "not guilty").
        caster_key = None
        if len(cms) == 1:
            caster_key = next(iter(cms))
        else:
            tteam = creep_team_from_name(tgt)
            if tgt and tgt.startswith("npc_dota_hero_"):
                for k, rows in streams.items():
                    if k[0] == tgt:
                        p, q = bracket(rows, t0)
                        s = p or q
                        if s:
                            tteam = s.get("team")
                        break
            if tteam is not None:
                cand = [k for k, tm in cm_teams.items() if tm != tteam]
                if len(cand) == 1:
                    caster_key = cand[0]

        c = {
            "t": t0,
            "target": tgt,
            "bucket": bucket,
            "ranged_exit_name": hits_ranged_exit(tgt),
            "gated_name": tgt in GATED_LANE_NAMES,
            "after_600": t0 > 600.0,
            "caster": "ambiguous" if caster_key is None else str(caster_key),
        }

        if caster_key is not None:
            rows = cms[caster_key]
            p, _ = bracket(rows, t0)
            rank = frostbite_rank(rows, t0)
            c["rank"] = rank
            c["creep_cap_shipped"] = SHIPPED_CREEP_CAP
            c["side"] = cm_teams.get(caster_key)
            if p is not None and abs(p["t"] - t0) <= 2.0:
                c["cm_level"] = p.get("level")
                c["cm_mp_pct"] = p.get("mp_pct")
                c["n_enemy_1600"] = near_count(
                    streams, t0, p["x"], p["y"], ENEMY_VIEW_RADIUS,
                    cm_teams[caster_key], True, caster_key)
                c["n_ally_1200"] = near_count(
                    streams, t0, p["x"], p["y"], ALLY_RADIUS,
                    cm_teams[caster_key], False, caster_key)

            # --- episode window and the one-sided health bound -------------
            dur = FROSTBITE_DURATION[rank - 1] if 1 <= rank <= 4 else 3.0
            t_end = t0 + dur + 0.6
            if i + 1 < len(casts):
                t_end = min(t_end, casts[i + 1]["t"] - 0.01)
            ticks = [v for (tt, v) in dmg_by_target.get(tgt, [])
                     if t0 - 0.2 <= tt <= t_end]
            c["n_ticks"] = len(ticks)
            c["tick_sum"] = sum(ticks)
            lb = hp_lower_bound(ticks)
            if lb is not None:
                c["hp_lb"] = lb

            # ⚠️ A CREEP'S NAME IS NOT AN ENTITY KEY, and unlike heroes the
            # combat log gives creeps no idx at all (GH #176's lesson, one rung
            # worse).  Several `npc_dota_creep_goodguys_ranged` are alive at
            # once, so:
            #   * `died_in_window` is NAME-attributed -> an UPPER bound;
            #   * `killed_by_frostbite` is EXACT, because only one Frostbite is
            #     ever active per caster, so a row whose inflictor is Frostbite
            #     can only be THIS creep.  The conditional bound below is gated
            #     on the exact predicate, never on the name-attributed one.
            death = None
            for (td, actor, infl) in deaths_by_target.get(tgt, []):
                if t0 <= td <= t_end:
                    death = (td, actor, infl)
                    break
            c["died_in_window"] = death is not None
            if death is not None:
                c["death_actor"] = death[1]
                c["death_inflictor"] = death[2]
                # The killing blow was Frostbite itself, by the combat log's
                # own attribution -- not by our arithmetic.
                c["killed_by_frostbite"] = (death[2] == FROSTBITE)
            c["other_hero_dmg_in_window"] = sum(
                v for (tt, v) in other_dmg_by_target.get(tgt, [])
                if t0 - DECISION_PRE_ROLL <= tt <= t_end)
            c["pre_cast_hero_dmg"] = sum(
                v for (tt, v) in other_dmg_by_target.get(tgt, [])
                if t0 - DECISION_PRE_ROLL <= tt < t0)

            # CONDITIONAL upper bound.  Sound ONLY under the named assumption
            # that no unobservable source (allied creeps, towers) contributed:
            # the dumper keeps a damage row only when a hero is on one end.
            # Reported under its own key so nobody can quote it as the health.
            if death is not None and c.get("killed_by_frostbite") \
                    and c["other_hero_dmg_in_window"] == 0 and ticks:
                c["hp_ub_if_frostbite_alone"] = sum(ticks)

            # Context only: enemy lane creeps near CM, from the position-only
            # creep stream.  These rows carry no name and no health, so this
            # can never become a health reading -- it is a "was she at a wave"
            # column and nothing more.
            if p is not None and abs(p["t"] - t0) <= 2.0:
                tk = round(round(t0 / 3.0) * 3.0, 1)
                near = 0
                for cc in creeps_by_t.get(tk, []):
                    if cc.get("team") == cm_teams[caster_key]:
                        continue
                    dx = cc["x"] - p["x"]
                    dy = cc["y"] - p["y"]
                    if dx * dx + dy * dy <= 800.0 * 800.0:
                        near += 1
                c["n_nonally_creeprows_800"] = near

        rec["casts"].append(c)
    return rec


def aggregate(recs):
    agg = {
        "games": len(recs),
        "creep_key_shapes": collections.Counter(),
        "games_with_cm": 0,
        "casts_total": 0,
        "buckets": collections.Counter(),
        "ranged_exit_casts": 0,
        "ranged_by_time": collections.Counter(),
        "ranged_gatedname_by_time": collections.Counter(),
        "money_block_geom": collections.Counter(),
        "rank_hist": collections.Counter(),
        "hp_lb_hist": collections.Counter(),
        "hp_lb_over_460": 0,
        "hp_lb_known": 0,
        "died_in_window": 0,
        "killed_by_frostbite": 0,
        "clean_episodes": 0,          # frostbite killed it AND no other hero dmg
        "hp_ub_hist": collections.Counter(),
        "hp_ub_at_or_below_460": 0,
        "hp_ub_over_460": 0,
        "ub_withdrawn_pre_cast_dmg": 0,
        "side_hist": collections.Counter(),
        "ambiguous_caster": 0,
        "snapshot_has_attack_damage": 0,
    }
    for r in recs:
        for k, v in (r.get("creep_key_shapes") or {}).items():
            agg["creep_key_shapes"][k] += v
        if r.get("n_cm_streams"):
            agg["games_with_cm"] += 1
        if r.get("snapshot_has_attack_damage"):
            agg["snapshot_has_attack_damage"] += 1
        for c in r.get("casts") or []:
            agg["casts_total"] += 1
            agg["buckets"][c["bucket"]] += 1
            if c["caster"] == "ambiguous":
                agg["ambiguous_caster"] += 1
                continue
            if c.get("side"):
                agg["side_hist"][c["side"]] += 1
            if not c["ranged_exit_name"]:
                continue
            agg["ranged_exit_casts"] += 1
            slot = "after_600" if c["after_600"] else "before_600"
            agg["ranged_by_time"][slot] += 1
            if c["gated_name"]:
                agg["ranged_gatedname_by_time"][slot] += 1
            agg["rank_hist"][c.get("rank", 0)] += 1
            if c.get("died_in_window"):
                agg["died_in_window"] += 1
            if c.get("killed_by_frostbite"):
                agg["killed_by_frostbite"] += 1
            if c.get("pre_cast_hero_dmg") and \
                    "hp_ub_if_frostbite_alone" not in c:
                agg["ub_withdrawn_pre_cast_dmg"] += 1
            if "hp_ub_if_frostbite_alone" in c:
                agg["clean_episodes"] += 1
                ub = c["hp_ub_if_frostbite_alone"]
                if ub <= 460:
                    agg["hp_ub_at_or_below_460"] += 1
                else:
                    agg["hp_ub_over_460"] += 1
                agg["hp_ub_hist"][min(int(ub // 100) * 100, 1200)] += 1
            if "n_enemy_1600" in c:
                cond = (c["n_enemy_1600"] == 0
                        and c.get("n_ally_1200", 99) < ALLY_MAX
                        and (c.get("cm_level") or 0) >= MONEY_BLOCK_MIN_LEVEL)
                agg["money_block_geom"]["pass" if cond else "fail"] += 1
                if c["n_enemy_1600"] == 0:
                    agg["money_block_geom"]["enemy1600_zero"] += 1
                if c.get("n_ally_1200", 99) < ALLY_MAX:
                    agg["money_block_geom"]["allies_lt3"] += 1
                if (c.get("cm_level") or 0) >= MONEY_BLOCK_MIN_LEVEL:
                    agg["money_block_geom"]["level_ge5"] += 1
            else:
                agg["money_block_geom"]["no_snapshot"] += 1
            if "hp_lb" in c:
                agg["hp_lb_known"] += 1
                lb = c["hp_lb"]
                if lb > 460:
                    agg["hp_lb_over_460"] += 1
                b = min(int(lb // 200) * 200, 1200)
                agg["hp_lb_hist"][b] += 1
    for k in ("creep_key_shapes", "buckets", "ranged_by_time",
              "ranged_gatedname_by_time", "money_block_geom", "rank_hist",
              "hp_lb_hist", "side_hist", "hp_ub_hist"):
        agg[k] = dict(agg[k])
    return agg


def selfcheck():
    ok = fail = 0

    def check(name, cond):
        nonlocal ok, fail
        if cond:
            ok += 1
            print("PASS %s" % name)
        else:
            fail += 1
            print("FAIL %s" % name)

    # --- the floors are READ from the source, and the read must be able to
    #     fail (GH #560's own lesson about by-construction arguments) --------
    floors = consumer_floors()
    check("floors_readable_from_source", floors is not None)
    check("floors_match_expected", sorted(floors or [], reverse=True) ==
          EXPECTED_FLOORS)
    check("shipped_500_clears_every_floor",
          floors is not None and all(500 > f for f in floors))
    # The one that resizes the defect: with cmcreepcap un-armed the cap is a
    # flat 1200 and the picker's own ceiling is 1100, so the cap term cannot
    # bite on ANY exit.
    check("cap_term_vacuous_on_shipped_tree",
          PICKER_HEALTH_CEILING <= SHIPPED_CREEP_CAP)
    check("shipped_500_under_shipped_cap", 500 <= SHIPPED_CREEP_CAP)

    # --- target classification --------------------------------------------
    check("bucket_base_ranged",
          classify_target("npc_dota_creep_badguys_ranged") == "lane_ranged")
    check("bucket_upgraded_ranged_is_not_base",
          classify_target("npc_dota_creep_badguys_ranged_upgraded")
          == "lane_ranged_upgraded")
    check("bucket_mega_ranged_is_not_upgraded",
          classify_target("npc_dota_creep_goodguys_ranged_upgraded_mega")
          == "lane_ranged_mega")
    check("bucket_siege_separate",
          classify_target("npc_dota_creep_badguys_siege") == "lane_siege")
    check("bucket_hero", classify_target("npc_dota_hero_lion") == "hero")
    check("bucket_neutral",
          classify_target("npc_dota_neutral_kobold_taskmaster") == "neutral")

    # --- the exit's own test is a substring match, NOT the bucket ----------
    check("exit_matches_upgraded_ranged",
          hits_ranged_exit("npc_dota_creep_badguys_ranged_upgraded"))
    check("exit_matches_mega_ranged",
          hits_ranged_exit("npc_dota_creep_goodguys_ranged_upgraded_mega"))
    check("exit_rejects_melee",
          not hits_ranged_exit("npc_dota_creep_badguys_melee"))

    # --- the 10-minute disjunct: only the four literals are gated ----------
    check("base_ranged_is_a_gated_name",
          "npc_dota_creep_badguys_ranged" in GATED_LANE_NAMES)
    check("upgraded_ranged_is_NOT_a_gated_name",
          "npc_dota_creep_badguys_ranged_upgraded" not in GATED_LANE_NAMES)
    check("mega_ranged_is_NOT_a_gated_name",
          "npc_dota_creep_goodguys_ranged_upgraded_mega" not in
          GATED_LANE_NAMES)
    check("gated_names_are_exactly_four", len(GATED_LANE_NAMES) == 4)

    # --- creep team from name ---------------------------------------------
    check("badguys_is_dire", creep_team_from_name(
        "npc_dota_creep_badguys_ranged") == 3)
    check("goodguys_is_radiant", creep_team_from_name(
        "npc_dota_creep_goodguys_ranged") == 2)
    check("neutral_has_no_team",
          creep_team_from_name("npc_dota_neutral_harpy_scout") is None)

    # --- the health bound is one-sided, and stays one-sided ----------------
    check("hp_lb_drops_the_killing_tick", hp_lower_bound([200, 200, 200]) == 400)
    check("hp_lb_single_tick_is_zero", hp_lower_bound([200]) == 0)
    check("hp_lb_none_without_ticks", hp_lower_bound([]) is None)
    check("hp_lb_never_exceeds_total",
          hp_lower_bound([200, 200, 150]) < 550)
    # A creep that survived the whole root: the bound is the sum of all but the
    # last tick, which is still a LOWER bound -- it must not be read as "the
    # health was this".
    check("hp_lb_is_below_a_survivors_true_health",
          hp_lower_bound([200, 200, 200, 200]) == 600)

    # --- illusion / death discipline (GH #176) -----------------------------
    snaps = [
        {"hero": CM, "idx": 1, "team": 2, "t": -60.0, "x": 0, "y": 0,
         "hp_pct": 1.0, "level": 1, "abilities": []},
        {"hero": CM, "idx": 1, "team": 2, "t": 100.0, "x": 0, "y": 0,
         "hp_pct": 1.0, "level": 9, "abilities": [
             {"name": FROSTBITE, "level": 3, "cd": 0.0}]},
        # an illusion: same name, different idx, never seen before the horn
        {"hero": CM, "idx": 7, "team": 2, "t": 90.0, "x": 0, "y": 0,
         "hp_pct": 1.0, "level": 9, "abilities": []},
    ]
    st = real_hero_streams(snaps)
    check("illusion_stream_dropped", len(st) == 1 and (CM, 1) in st)
    check("rank_read_from_last_sample_at_or_before",
          frostbite_rank(st[(CM, 1)], 100.0) == 3)
    check("rank_zero_before_training",
          frostbite_rank(st[(CM, 1)], -10.0) == 0)

    dead = [
        {"hero": "npc_dota_hero_lion", "idx": 2, "team": 3, "t": 99.0,
         "x": 100, "y": 0, "hp_pct": 0.0},
        {"hero": "npc_dota_hero_lion", "idx": 2, "team": 3, "t": 101.0,
         "x": 100, "y": 0, "hp_pct": 0.0},
    ]
    st2 = real_hero_streams(snaps + dead)
    check("dead_enemy_not_counted",
          near_count(st2, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)) == 0)
    alive = [
        {"hero": "npc_dota_hero_lion", "idx": 3, "team": 3, "t": -60.0,
         "x": 100, "y": 0, "hp_pct": 1.0},
        {"hero": "npc_dota_hero_lion", "idx": 3, "team": 3, "t": 99.0,
         "x": 100, "y": 0, "hp_pct": 1.0},
        {"hero": "npc_dota_hero_lion", "idx": 3, "team": 3, "t": 101.0,
         "x": 100, "y": 0, "hp_pct": 1.0},
    ]
    st3 = real_hero_streams(snaps + alive)
    check("live_enemy_inside_ring_counted",
          near_count(st3, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)) == 1)
    far = [dict(r, x=9000) for r in alive]
    st4 = real_hero_streams(snaps + far)
    check("live_enemy_outside_ring_not_counted",
          near_count(st4, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)) == 0)
    # Over-counting direction: a hero inside the ring on EITHER bracket counts,
    # so the zero-set this produces is a subset of the true zero-set.
    half = [
        {"hero": "npc_dota_hero_lion", "idx": 4, "team": 3, "t": -60.0,
         "x": 9000, "y": 0, "hp_pct": 1.0},
        {"hero": "npc_dota_hero_lion", "idx": 4, "team": 3, "t": 99.0,
         "x": 9000, "y": 0, "hp_pct": 1.0},
        {"hero": "npc_dota_hero_lion", "idx": 4, "team": 3, "t": 101.0,
         "x": 100, "y": 0, "hp_pct": 1.0},
    ]
    st5 = real_hero_streams(snaps + half)
    check("either_bracket_inside_counts_conservatively",
          near_count(st5, 100.0, 0, 0, 1600.0, 2, True, (CM, 1)) == 1)
    check("ally_side_is_not_enemy_side",
          near_count(st3, 100.0, 0, 0, 1200.0, 2, False, (CM, 1)) == 0)

    # --- a whole tiny game, end to end ------------------------------------
    tl = {
        "snapshots": snaps + alive,
        "creeps": [{"t": 1.0, "team": 2, "x": 1, "y": 2}],
        "events": [
            {"t": 100.0, "type": "ABILITY", "actor": CM,
             "target": "npc_dota_creep_badguys_ranged",
             "inflictor": FROSTBITE, "value": 0},
            {"t": 100.5, "type": "DAMAGE", "actor": CM,
             "target": "npc_dota_creep_badguys_ranged",
             "inflictor": FROSTBITE, "value": 200},
            {"t": 101.0, "type": "DAMAGE", "actor": CM,
             "target": "npc_dota_creep_badguys_ranged",
             "inflictor": FROSTBITE, "value": 200},
            {"t": 101.2, "type": "DEATH", "actor": CM,
             "target": "npc_dota_creep_badguys_ranged",
             "inflictor": FROSTBITE},
        ],
    }
    rec = scan_game(tl, "unit")
    check("game_reports_creep_key_shape",
          rec["creep_key_shapes"] == {"t|team|x|y": 1})
    check("game_finds_one_cast", len(rec["casts"]) == 1)
    c0 = rec["casts"][0]
    check("cast_bucketed_lane_ranged", c0["bucket"] == "lane_ranged")
    check("cast_is_gated_name", c0["gated_name"] is True)
    check("cast_before_600_flagged", c0["after_600"] is False)
    check("cast_hp_lb_is_first_tick_only", c0.get("hp_lb") == 200)
    check("cast_death_in_window", c0.get("died_in_window") is True)
    check("cast_killed_by_frostbite", c0.get("killed_by_frostbite") is True)
    check("cast_conditional_ub_is_the_tick_total",
          c0.get("hp_ub_if_frostbite_alone") == 400)
    check("cast_ub_strictly_above_lb",
          c0["hp_ub_if_frostbite_alone"] > c0["hp_lb"])
    check("cast_no_other_hero_damage", c0.get("other_hero_dmg_in_window") == 0)
    check("pre_roll_is_one_second", DECISION_PRE_ROLL == 1.0)
    # The 2026-09-07 self-catch, pinned: an ALLY's damage 0.4s before the cast
    # row lands between the health read and the log row, and must withdraw the
    # bound.  A 0.2s pre-roll let this through and published "22 health".
    tl_ally = dict(tl)
    tl_ally["events"] = [
        {"t": 99.6, "type": "DAMAGE", "actor": "npc_dota_hero_storm_spirit",
         "target": "npc_dota_creep_badguys_ranged", "inflictor": "dota_unknown",
         "value": 221}] + tl["events"]
    c_ally = scan_game(tl_ally, "unit_ally")["casts"][0]
    check("ally_damage_0p4s_before_the_cast_withdraws_the_ub",
          "hp_ub_if_frostbite_alone" not in c_ally)
    check("pre_cast_damage_is_registered_not_only_used",
          c_ally.get("pre_cast_hero_dmg") == 221)
    # ...and damage further back than the pre-roll does NOT withdraw it: the
    # picker read the health after that, so the ticks still bracket it.
    tl_old = dict(tl)
    tl_old["events"] = [
        {"t": 97.0, "type": "DAMAGE", "actor": "npc_dota_hero_storm_spirit",
         "target": "npc_dota_creep_badguys_ranged", "inflictor": "dota_unknown",
         "value": 221}] + tl["events"]
    c_old = scan_game(tl_old, "unit_old")["casts"][0]
    check("damage_before_the_pre_roll_keeps_the_ub",
          c_old.get("hp_ub_if_frostbite_alone") == 400
          and c_old.get("pre_cast_hero_dmg") == 0)
    # A hero auto-attack in the window withdraws the conditional bound: the
    # health is then above the frostbite total by an unknown amount.
    tl_dirty = dict(tl)
    tl_dirty["events"] = tl["events"] + [
        {"t": 100.7, "type": "DAMAGE", "actor": CM,
         "target": "npc_dota_creep_badguys_ranged",
         "inflictor": "", "value": 55}]
    c_dirty = scan_game(tl_dirty, "unit_dirty")["casts"][0]
    check("other_hero_damage_withdraws_the_ub",
          "hp_ub_if_frostbite_alone" not in c_dirty
          and c_dirty["other_hero_dmg_in_window"] == 55)
    # A death whose inflictor is NOT frostbite also withdraws it.
    tl_other = dict(tl)
    tl_other["events"] = tl["events"][:-1] + [
        {"t": 101.2, "type": "DEATH", "actor": "npc_dota_hero_lion",
         "target": "npc_dota_creep_badguys_ranged",
         "inflictor": "lion_impale"}]
    c_other = scan_game(tl_other, "unit_other")["casts"][0]
    check("foreign_killing_blow_withdraws_the_ub",
          "hp_ub_if_frostbite_alone" not in c_other
          and c_other["killed_by_frostbite"] is False
          and c_other["died_in_window"] is True)
    check("cast_sees_one_enemy_in_1600", c0.get("n_enemy_1600") == 1)
    check("cast_rank_read", c0.get("rank") == 3)
    check("attack_damage_absent_from_snapshots",
          rec["snapshot_has_attack_damage"] is False)

    agg = aggregate([rec])
    check("agg_counts_the_cast", agg["casts_total"] == 1)
    check("agg_ranged_exit_counted", agg["ranged_exit_casts"] == 1)
    check("agg_money_block_fails_on_visible_enemy",
          agg["money_block_geom"].get("fail") == 1)
    check("agg_hp_lb_not_over_460", agg["hp_lb_over_460"] == 0)
    check("agg_counts_the_clean_episode", agg["clean_episodes"] == 1)
    check("agg_ub_bucketed_at_or_below_460",
          agg["hp_ub_at_or_below_460"] == 1 and agg["hp_ub_over_460"] == 0)
    check("agg_key_shape_pooled", agg["creep_key_shapes"] == {"t|team|x|y": 1})

    # A second game where the caster is genuinely ambiguous must not be
    # silently booked to one CM.
    tl2 = dict(tl)
    tl2["snapshots"] = snaps + alive + [
        {"hero": CM, "idx": 5, "team": 3, "t": -60.0, "x": 0, "y": 0,
         "hp_pct": 1.0, "level": 9, "abilities": []},
        {"hero": CM, "idx": 5, "team": 3, "t": 100.0, "x": 0, "y": 0,
         "hp_pct": 1.0, "level": 9, "abilities": []},
    ]
    tl2["events"] = [dict(tl["events"][0],
                          target="npc_dota_neutral_harpy_scout")]
    rec2 = scan_game(tl2, "unit2")
    check("two_cms_neutral_target_is_ambiguous",
          rec2["casts"][0]["caster"] == "ambiguous")
    check("ambiguous_cast_carries_no_rank",
          "rank" not in rec2["casts"][0])
    agg2 = aggregate([rec2])
    check("agg_registers_ambiguous", agg2["ambiguous_caster"] == 1)
    # And with two CMs but a team-bearing creep target it IS resolvable.
    tl3 = dict(tl2)
    tl3["events"] = [dict(tl["events"][0])]
    rec3 = scan_game(tl3, "unit3")
    check("two_cms_creep_target_resolves_by_creep_team",
          rec3["casts"][0]["caster"] != "ambiguous"
          and rec3["casts"][0].get("side") == 2)

    print("SELFCHECK %d PASS / %d FAIL" % (ok, fail))
    return 0 if fail == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--game")
    ap.add_argument("--out")
    ap.add_argument("--aggregate")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()

    if a.game:
        with open(a.game) as f:
            tl = json.load(f)
        rec = scan_game(tl, os.path.basename(a.game)[:-5])
        txt = json.dumps(rec)
        if a.out:
            with open(a.out, "w") as f:
                f.write(txt)
        else:
            print(txt)
        return 0

    if a.aggregate:
        recs = []
        for p in sorted(glob.glob(os.path.join(a.aggregate, "*.json"))):
            try:
                recs.append(json.load(open(p)))
            except Exception:
                pass
        print(json.dumps(aggregate(recs), indent=2, sort_keys=True))
        return 0

    ap.error("one of --selfcheck / --game / --aggregate required")


if __name__ == "__main__":
    sys.exit(main())

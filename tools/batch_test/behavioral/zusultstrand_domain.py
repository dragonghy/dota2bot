#!/usr/bin/env python3
"""`zusultstrand` condition-(a) domain census over an archived Zeus corpus.

WHAT THIS ANSWERS (queue row hero-37; GH #564; director ruling APPROVED-SCAN
2026-09-06, test_set.md §FK.7 -- a zero-EC2 read-only archive traversal)
-----------------------------------------------------------------------------
`bots/BotLib/hero_zuus.lua` `X.ConsiderR` carries a RETREAT branch:

    if J.IsRetreating( bot ) and bot:WasRecentlyDamagedByAnyHero( 2.0 ) then
        if X.zuus_ShouldCashUltBeforeDeath( bot )      -- was: GetRespawnTime() > GetCooldown()
            and nHealthPercentage <= 0.28 then
            return BOT_ACTION_DESIRE_HIGH

The shipped conjunct is structurally false (right side is the constant 130, left
side is at most 75 in turbo), so this branch has never fired.  The landed gated
fix (`zusultstrand`, turbo-only, NOT armed) replaces it with "an enemy hero is
inside X.nUltCashChaseRadius = 1600".

⚠️  DIRECTION, pre-registered by the request and repeated here so no reader has
to go find it: this is a **WIDENING**.  Arming can only ADD ult casts on this
branch; it can never remove one.  A negative reading may only ever be read as
"the extra casts were bad", never as "the lever cost N casts".

THE FOUR COLUMNS, AND WHAT THE ARCHIVE CAN ACTUALLY ANSWER
-----------------------------------------------------------------------------
  (1) domain size: retreating + HP<=28% + hero-damaged within 2s + ult
      castable                                                     -> UPPER BOUND
      Three of the four conjuncts are frame data and are read exactly:
        * `nHealthPercentage <= 0.28`      -> `hp_pct` in snapshots[]
        * `WasRecentlyDamagedByAnyHero(2)` -> combat-log DAMAGE rows with
          `actor_hero == true` and `target == zeus` in (t-2, t]
        * `abilityR:IsFullyCastable()`     -> the ult's own entry in
          snapshots[].abilities[]: `level >= 1` and `cd <= 0`, plus
          `mp >= AbilityManaCost[rank]`, and the cost ladder is READ FROM the
          repo's KV snapshot (tests/mock/special_value_shapes.lua), never
          retyped here -- GH #560's "an assertion that cannot fail is not
          evidence" applies to the constants too.
      The fourth, `J.IsRetreating( bot )`, is a BOT-INTERNAL MODE.  No replay
      carries it (`GetActiveMode()` is absent from every dump; the same wall
      §CJ has hit on every mode-guarded lever).  So every count under (1) is an
      UPPER BOUND on the branch's true domain and is reported as one.  A
      geometric proxy is computed and reported UNDER ITS OWN KEY
      (`retreat_proxy_*`) so it can never be quoted as the mode.
  (2) ⭐ the value column: did Zeus then DIE, and was the ult still un-cast and
      READY at that death                                                -> READ
      This is the one the request marked METHOD-FAILED-if-unreadable, and it is
      readable: DEATH rows name the target, ABILITY rows name
      `zuus_thundergods_wrath` as the inflictor, and the pre-death snapshot
      carries the ult's own `level`/`cd` and Zeus's `mp`.  "Died holding a
      castable ult" is therefore a direct reading, not an inference.
      ⚠️  It is reported at TWO scopes that must not be merged:
        * per-episode: a domain episode followed by a death within
          `DEATH_WINDOW` seconds -- the payoff this lever is actually pricing;
        * per-game: EVERY Zeus death holding a castable ult, whatever branch
          would have covered it -- the strictly larger population, quoted only
          as context.
  (3) nearest enemy hero distance at the domain instants                 -> READ
      (geometry), with the vision caveat registered in BOTH directions and
      never swapped:
        * a hero inside 1600 need not have been VISIBLE -> the "inside" count
          is an UPPER bound on what `J.GetNearbyHeroes(..., true, ...)` returns;
        * zero heroes inside 1600 geometrically IMPLIES zero visible -> the
          "outside" count is a SOUND refutation for those frames.
  (4) the `ultcash` overlap layer                                     -> PARTIAL
      `J.IsDyingUnderAttack` = HP<=45% + hero-damaged within 2s + >=1 enemy
      within 1200 + sum of `GetEstimatedDamageToTarget(3s)` >= current HP.
      The first two are implied by (1)'s own conjuncts (0.28 <= 0.45, same
      damage predicate), and the 1200 ring is geometry -> READ.  The estimator
      is a live bot-API prediction and exists in no replay -> BLIND.  A
      RETROSPECTIVE proxy (hero damage actually taken in the next 3s >= HP at
      the instant) is reported under `ultcash_retro_*`.  It is NOT the
      predicate: the estimator fires on damage that was predicted and then did
      not land, and stays silent on damage that landed unpredictably.  So
      `ultcash_ring_only` (the geometry-only layer) is an UPPER bound on the
      overlap and `ultcash_retro_and_ring` is neither a bound nor an estimate
      of it -- it is a differently-defined quantity, printed so the reader can
      see how far apart they are.

THE LOADER QUESTION THE ROW ASKED "IN PASSING"
-----------------------------------------------------------------------------
"Is there any column in the dump that gives a LIVING hero's GetRespawnTime?"
`snapshot_key_shapes` is the measured answer: the key census over every
snapshot row in the corpus.  If no respawn-ish key appears there, the one-way
trip-wire in tests/test_zuus_ult_strand.lua §6 stays as it is.
"""

import argparse
import collections
import json
import math
import os
import re
import sys

ULT = "zuus_thundergods_wrath"
ZEUS = "npc_dota_hero_zuus"

# The two windows this tool owns.  Named, not inlined, because both are
# judgement calls the reader is entitled to move.
DAMAGE_LOOKBACK = 2.0   # WasRecentlyDamagedByAnyHero( 2.0 ) -- from the source
DEATH_WINDOW = 6.0      # "and then he actually died" -- this tool's choice
EPISODE_GAP = 1.0       # frames this far apart or closer are one episode
CHASE_RADIUS = 1600.0   # X.nUltCashChaseRadius -- the armed narrowing term
ULTCASH_RADIUS = 1200.0 # J.IsDyingUnderAttack's ring
HP_GATE = 0.28          # nHealthPercentage <= 0.28
ULTCASH_HP_GATE = 0.45  # J.IsDyingUnderAttack's HP gate


# --------------------------------------------------------------------------
# Constants are READ from the repo, never retyped.  A hardcoded 250/375/500
# here would make every "the ult was affordable" reading an assertion about
# this file instead of about the game.
# --------------------------------------------------------------------------
def _repo_root():
    # this file lives at <repo>/tools/batch_test/behavioral/ -- four levels up.
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(os.path.dirname(here)))


def read_ult_kv(path=None):
    """Return (mana_cost_ladder, cooldown) for zuus_thundergods_wrath from the KV snapshot."""
    if path is None:
        path = os.path.join(_repo_root(), "tests", "mock", "special_value_shapes.lua")
    src = open(path, encoding="utf-8").read()
    i = src.find("['%s']" % ULT)
    if i < 0:
        raise RuntimeError("KV snapshot has no %s block: %s" % (ULT, path))
    block = src[i:i + 2000]
    def field(name):
        m = re.search(r"\['%s'\]\s*=\s*\{\s*base\s*=\s*'([^']*)'" % name, block)
        if not m:
            raise RuntimeError("KV block for %s has no %s" % (ULT, name))
        return m.group(1)
    mana = [float(x) for x in field("AbilityManaCost").split()]
    cd = [float(x) for x in field("AbilityCooldown").split()]
    return mana, cd


def mana_cost_for_rank(ladder, rank):
    """Ladder values are per-rank; a shorter ladder means the last value repeats."""
    if rank <= 0:
        return None
    return ladder[min(rank, len(ladder)) - 1]


# --------------------------------------------------------------------------
def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def ult_entry(snap):
    # `abilities` is present in every row's KEY SHAPE but is sometimes JSON
    # null (10 of the 152 sampled games carry such rows).  A null ability list
    # is an UNREADABLE frame, not an "ult not learned" frame, so it is counted
    # under its own key and never silently folded into the negatives.
    for a in (snap.get("abilities") or []):
        if a.get("name") == ULT:
            return a
    return None


def scan_game(tl, game_id, mana_ladder, cd_ladder):
    """Scan one dumped timeline. Returns a per-game result dict."""
    snaps = tl.get("snapshots", [])
    events = tl.get("events", [])

    # ⭐ TWO instrument facts, both measured on 2026-09-07 and both able to move
    # a reading on their own:
    #  (a) the dumper emits the rows of one tick in NONDETERMINISTIC ORDER (the
    #      row SET is identical across runs of the same .dem, the SEQUENCE is
    #      not -- Go map iteration).  So nothing here may depend on "the first"
    #      or "the next" row at a given t.
    #  (b) `hero` + `player_id` do NOT identify one unit: ILLUSIONS carry the
    #      same hero name and the same player_id and differ only in `idx`
    #      (measured: one game had 6,514 rows on idx 1534 and 326 each on idx
    #      1622 / 2084, at DIFFERENT positions and identical hp/mp).
    # Together these two made `deaths_holding_castable_ult` and the retreat
    # proxy irreproducible across sweeps (190 vs 193, 685 vs 707) before the
    # entity keying below; every count in this file is now order-independent.
    key_shapes = collections.Counter()
    by_t = collections.defaultdict(list)
    idx_rows = collections.defaultdict(list)          # (hero, idx) -> rows
    for s in snaps:
        key_shapes["|".join(sorted(s.keys()))] += 1
        by_t[round(float(s["t"]), 3)].append(s)
        if s.get("hero"):
            idx_rows[(s["hero"], s.get("idx"))].append(s)

    # the REAL entity of a hero is the idx that appears in the most frames; an
    # illusion exists for a fraction of the game by construction.  Ties (which
    # would make this arbitrary) are counted and reported, not silently broken.
    real_idx = {}
    tie_names = []
    per_hero = collections.defaultdict(list)
    for (hero, idx), rows in idx_rows.items():
        per_hero[hero].append((len(rows), idx))
    for hero, cand in per_hero.items():
        cand.sort(reverse=True)
        if len(cand) > 1 and cand[0][0] == cand[1][0]:
            tie_names.append(hero)
        real_idx[hero] = cand[0][1]

    zeus_rows = collections.defaultdict(list)   # player_id -> rows (REAL Zeus only)
    zeus_illusion_rows = 0
    for s in snaps:
        if s.get("hero") != ZEUS:
            continue
        if s.get("idx") != real_idx.get(ZEUS):
            zeus_illusion_rows += 1
            continue
        zeus_rows[s.get("player_id")].append(s)

    # combat-log slices, per Zeus instance
    hero_dmg = collections.defaultdict(list)     # zeus hero name key -> [(t, value, actor)]
    deaths = []
    ult_casts = []
    for e in events:
        et = e.get("type")
        if et == "DAMAGE" and e.get("target") == ZEUS and e.get("actor_hero"):
            hero_dmg[ZEUS].append((float(e["t"]), float(e.get("value") or 0), e.get("actor")))
        elif et == "DEATH" and e.get("target") == ZEUS:
            deaths.append(float(e["t"]))
        elif et == "ABILITY" and e.get("actor") == ZEUS and e.get("inflictor") == ULT:
            ult_casts.append(float(e["t"]))
    dmg_rows = sorted(hero_dmg[ZEUS])
    deaths.sort()
    ult_casts.sort()

    out = {
        "game": game_id,
        "key_shapes": dict(key_shapes),
        "zeus_players": sorted(k for k in zeus_rows.keys() if k is not None),
        # iron rule 4(i-a): every reading is registered in BOTH strata.  For a
        # single-arm domain census the stratum is the physical SIDE (team 2 =
        # radiant, 3 = dire), which is the layer the +1.5k radiant gold bias
        # and the detector-side-bias finding (GH #148/#329) both live on.
        "by_side": {},
        "n_zeus_snapshots": sum(len(v) for v in zeus_rows.values()),
        "n_death_rows": len(deaths),
        "zeus_illusion_rows": zeus_illusion_rows,
        "real_idx_ties": sorted(tie_names),
        "n_deaths": 0,
        "zeus_snapshots_null_abilities": 0,
        "n_ult_casts": len(ult_casts),
        "frames": 0,
        "episodes": [],
        "rank_hist": collections.Counter(),
        "nearest_enemy": [],
        "in_chase_radius": 0,
        "in_chase_radius_real_only": 0,
        "out_chase_radius": 0,
        "ultcash_ring_only": 0,
        "ultcash_retro_and_ring": 0,
        "retreat_proxy_frames": 0,
        "deaths_holding_castable_ult": 0,
        "deaths_with_pre_snapshot": 0,
        "ult_ready_uncast_at_death_ts": [],
    }

    def dmg_in(lo, hi):
        return sum(v for (t, v, _a) in dmg_rows if lo < t <= hi)

    def side_bucket(team):
        name = {2: "radiant", 3: "dire"}.get(int(team) if team is not None else -1, "unknown")
        return out["by_side"].setdefault(name, {
            "frames": 0, "episodes": 0, "in_chase_radius": 0,
            "out_chase_radius": 0, "ultcash_ring_only": 0,
            "ultcash_retro_and_ring": 0, "n_deaths": 0,
            "deaths_with_pre_snapshot": 0, "deaths_holding_castable_ult": 0,
            "ep_died": 0, "ep_died_ult_uncast": 0, "n_ult_casts": 0, "games": 0,
            "retreat_proxy_frames": 0,
        })

    for pid, rows in zeus_rows.items():
        rows.sort(key=lambda r: float(r["t"]))
        sb = side_bucket(rows[0].get("team") if rows else None)
        sb["games"] += 1
        sb["n_ult_casts"] += len(ult_casts)
        # ⭐ DEATHS ARE READ FROM THE REAL ENTITY'S OWN HP SERIES, not from the
        # combat log.  A DEATH row names its target by HERO NAME, so an
        # illusion's death is indistinguishable from the hero's in the log --
        # `n_death_rows` is therefore an UPPER bound and is kept only as a
        # cross-check.  An hp>0 -> hp<=0 transition on the one entity index
        # that is the hero cannot be an illusion's.
        hp_deaths = []
        prev_alive = None
        for r in rows:
            alive = float(r.get("hp") or 0) > 0
            if prev_alive and not alive:
                hp_deaths.append(float(r["t"]))
            prev_alive = alive
        out["n_deaths"] += len(hp_deaths)
        sb["n_deaths"] += len(hp_deaths)

        hits = []
        for i, s in enumerate(rows):
            t = float(s["t"])
            if float(s.get("hp") or 0) <= 0:
                continue
            if float(s.get("hp_pct", 1.0)) > HP_GATE:
                continue
            if s.get("abilities") is None:
                out["zeus_snapshots_null_abilities"] += 1
                continue
            ab = ult_entry(s)
            if ab is None:
                continue
            rank = int(ab.get("level") or 0)
            if rank < 1:
                continue
            if float(ab.get("cd") or 0) > 0:
                continue
            cost = mana_cost_for_rank(mana_ladder, rank)
            if cost is None or float(s.get("mp") or 0) < cost:
                continue
            if dmg_in(t - DAMAGE_LOOKBACK, t) <= 0:
                continue

            # --- frame is in the (upper-bound) domain -------------------
            out["frames"] += 1
            sb["frames"] += 1
            out["rank_hist"][rank] += 1

            # (3) geometry at this instant
            peers = by_t.get(round(t, 3), [])
            me = (float(s["x"]), float(s["y"]))
            enemies = [
                (dist(me, (float(p["x"]), float(p["y"]))), p.get("hero"))
                for p in peers
                if p.get("team") != s.get("team") and float(p.get("hp") or 0) > 0
            ]
            enemies.sort()
            enemies_real = [
                (dist(me, (float(p["x"]), float(p["y"]))), p.get("hero"))
                for p in peers
                if p.get("team") != s.get("team") and float(p.get("hp") or 0) > 0
                and p.get("idx") == real_idx.get(p.get("hero"))
            ]
            nearest = enemies[0][0] if enemies else None
            out["nearest_enemy"].append(nearest)
            n1600 = sum(1 for d, _ in enemies if d <= CHASE_RADIUS)
            n1200 = sum(1 for d, _ in enemies if d <= ULTCASH_RADIUS)
            # SECOND reading with illusions dropped, under its own key.  The
            # lever's own call -- J.GetNearbyHeroes(bot, 1600, true, MODE_NONE)
            # -- carries NO illusion filter, so `n1600` (illusions included) is
            # the lever-faithful one and this is the conservative companion.
            n1600_real = sum(1 for d, h in enemies_real if d <= CHASE_RADIUS)
            if n1600_real > 0:
                out["in_chase_radius_real_only"] += 1
            if n1600 > 0:
                out["in_chase_radius"] += 1
                sb["in_chase_radius"] += 1
            else:
                out["out_chase_radius"] += 1
                sb["out_chase_radius"] += 1

            # (4) ultcash overlap layers
            if n1200 > 0:
                out["ultcash_ring_only"] += 1
                sb["ultcash_ring_only"] += 1
                if dmg_in(t, t + 3.0) >= float(s.get("hp") or 0):
                    out["ultcash_retro_and_ring"] += 1
                    sb["ultcash_retro_and_ring"] += 1

            # retreat PROXY, under its own key: moving away from the nearest
            # enemy over the next second.  NOT the mode; a bot can retreat
            # while cornered and can walk away without being in retreat mode.
            nxt_t = next((float(r["t"]) for r in rows if float(r["t"]) > t), None)
            if nearest is not None and nxt_t is not None and nxt_t - t <= 1.0:
                nxt = [r for r in rows if float(r["t"]) == nxt_t][0]
                peers2 = by_t.get(round(nxt_t, 3), [])
                me2 = (float(nxt["x"]), float(nxt["y"]))
                e2 = [
                    dist(me2, (float(p["x"]), float(p["y"])))
                    for p in peers2
                    if p.get("team") != s.get("team") and float(p.get("hp") or 0) > 0
                ]
                if e2 and min(e2) > nearest:
                    out["retreat_proxy_frames"] += 1
                    sb["retreat_proxy_frames"] += 1

            hits.append((t, s, nearest, n1600, n1200, rank))

        # --- episodes -------------------------------------------------
        cur = []
        eps = []
        for h in hits:
            if cur and h[0] - cur[-1][0] > EPISODE_GAP:
                eps.append(_close_episode(cur, hp_deaths, ult_casts, game_id, pid))
                cur = []
            cur.append(h)
        if cur:
            eps.append(_close_episode(cur, hp_deaths, ult_casts, game_id, pid))
        for e in eps:
            e["side"] = {2: "radiant", 3: "dire"}.get(
                int(rows[0].get("team")) if rows and rows[0].get("team") is not None else -1,
                "unknown")
            sb["episodes"] += 1
            if e["died_within_window"]:
                sb["ep_died"] += 1
                if not e["ult_cast_before_death"]:
                    sb["ep_died_ult_uncast"] += 1
        out["episodes"] += eps

        # --- (2) at per-game scope: every death, ult in hand? ----------
        for dt in hp_deaths:
            # the last snapshot in the 3s before the death row.  3s is the
            # widest gap that still describes the SAME fight instant at the
            # dumper's coarsest useful sampling; a death with no snapshot in
            # that window is counted as unreadable, not as "not holding".
            pre = [r for r in rows
                   if dt - 3.0 <= float(r["t"]) < dt and r.get("abilities") is not None]
            if not pre:
                continue
            out["deaths_with_pre_snapshot"] += 1
            sb["deaths_with_pre_snapshot"] += 1
            tmax = max(float(r["t"]) for r in pre)
            s = sorted((r for r in pre if float(r["t"]) == tmax),
                       key=lambda r: (r.get("idx") or 0))[0]
            ab = ult_entry(s)
            if ab is None:
                continue
            rank = int(ab.get("level") or 0)
            if rank < 1 or float(ab.get("cd") or 0) > 0:
                continue
            cost = mana_cost_for_rank(mana_ladder, rank)
            if cost is None or float(s.get("mp") or 0) < cost:
                continue
            out["deaths_holding_castable_ult"] += 1
            sb["deaths_holding_castable_ult"] += 1
            out["ult_ready_uncast_at_death_ts"].append(round(dt, 1))

    out["rank_hist"] = dict(out["rank_hist"])
    return out


def _close_episode(cur, deaths, ult_casts, game_id, pid):
    t0, t1 = cur[0][0], cur[-1][0]
    died = [d for d in deaths if t1 <= d <= t1 + DEATH_WINDOW]
    cast = [c for c in ult_casts if t0 <= c <= (died[0] if died else t1 + DEATH_WINDOW)]
    nearest = [h[2] for h in cur if h[2] is not None]
    return {
        "game": game_id,
        "player_id": pid,
        "t0": round(t0, 1),
        "t1": round(t1, 1),
        "frames": len(cur),
        "rank": cur[0][5],
        "min_nearest_enemy": round(min(nearest), 1) if nearest else None,
        "any_in_1600": any(h[3] > 0 for h in cur),
        "any_in_1200": any(h[4] > 0 for h in cur),
        "died_within_window": bool(died),
        "death_t": round(died[0], 1) if died else None,
        "ult_cast_before_death": bool(cast),
    }


# --------------------------------------------------------------------------
def aggregate(paths):
    agg = {
        "games": 0,
        "games_with_zeus": 0,
        "frames": 0,
        "episodes": 0,
        "games_with_domain": 0,
        "rank_hist": collections.Counter(),
        "key_shapes": collections.Counter(),
        "in_chase_radius": 0,
        "in_chase_radius_real_only": 0,
        "out_chase_radius": 0,
        "ultcash_ring_only": 0,
        "ultcash_retro_and_ring": 0,
        "retreat_proxy_frames": 0,
        "n_deaths": 0,
        "n_death_rows": 0,
        "zeus_illusion_rows": 0,
        "deaths_with_pre_snapshot": 0,
        "deaths_holding_castable_ult": 0,
        "n_ult_casts": 0,
        "zeus_snapshots_null_abilities": 0,
        "ep_died": 0,
        "ep_died_ult_uncast": 0,
        "ep_in_1600": 0,
        "nearest_enemy": [],
        "top_episodes": [],
        "per_game_frames": {},
        "by_side": {},
    }
    for p in paths:
        r = json.load(open(p))
        agg["games"] += 1
        if r["n_zeus_snapshots"]:
            agg["games_with_zeus"] += 1
        agg["frames"] += r["frames"]
        agg["episodes"] += len(r["episodes"])
        if r["frames"]:
            agg["games_with_domain"] += 1
        agg["per_game_frames"][r["game"]] = r["frames"]
        for k in ("in_chase_radius", "in_chase_radius_real_only",
                  "out_chase_radius", "ultcash_ring_only",
                  "ultcash_retro_and_ring", "retreat_proxy_frames", "n_deaths",
                  "n_death_rows", "zeus_illusion_rows",
                  "deaths_with_pre_snapshot", "deaths_holding_castable_ult",
                  "n_ult_casts", "zeus_snapshots_null_abilities"):
            agg[k] += r[k]
        for k, v in r["rank_hist"].items():
            agg["rank_hist"][int(k)] += v
        for k, v in r["key_shapes"].items():
            agg["key_shapes"][k] += v
        for side, b in r.get("by_side", {}).items():
            tgt = agg["by_side"].setdefault(side, {})
            for k, v in b.items():
                tgt[k] = tgt.get(k, 0) + v
        agg["nearest_enemy"] += [d for d in r["nearest_enemy"] if d is not None]
        for e in r["episodes"]:
            if e["died_within_window"]:
                agg["ep_died"] += 1
                if not e["ult_cast_before_death"]:
                    agg["ep_died_ult_uncast"] += 1
            if e["any_in_1600"]:
                agg["ep_in_1600"] += 1
            agg["top_episodes"].append(e)
    agg["rank_hist"] = dict(agg["rank_hist"])
    agg["key_shapes"] = dict(agg["key_shapes"])
    # the pin-worthy frames first: died, ult still uncast, enemy inside 1600
    agg["top_episodes"].sort(
        key=lambda e: (e["died_within_window"] and not e["ult_cast_before_death"],
                       e["any_in_1600"], e["frames"]),
        reverse=True)
    agg["top_episodes"] = agg["top_episodes"][:40]
    ne = sorted(agg["nearest_enemy"])
    agg["nearest_enemy_summary"] = {
        "n": len(ne),
        "min": round(ne[0], 1) if ne else None,
        "max": round(ne[-1], 1) if ne else None,
        "mean": round(sum(ne) / len(ne), 1) if ne else None,
        "le_1200": sum(1 for d in ne if d <= ULTCASH_RADIUS),
        "le_1600": sum(1 for d in ne if d <= CHASE_RADIUS),
    }
    del agg["nearest_enemy"]
    return agg


# --------------------------------------------------------------------------
# --selfcheck: synthetic timelines whose answers are known by construction.
# Every assertion here has to be able to FAIL -- the checks that only restate
# the input are the ones GH #560 called out, so each case below moves ONE
# conjunct and demands the count move with it.
# --------------------------------------------------------------------------
def _snap(t, hero, team, x, y, hp, hp_pct, mp, rank, cd, pid=1, idx=1):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "player_id": pid,
            "x": x, "y": y, "hp": hp, "hp_pct": hp_pct, "mp": mp, "max_mp": 1000,
            "mp_pct": mp / 1000.0, "level": 15, "items": [], "tp_cd": 0,
            "tp_cdlen": 0, "net_worth": 1,
            "abilities": [{"name": ULT, "level": rank, "cd": cd, "cd_len": 130}]}


def _dmg(t, value=50, actor="npc_dota_hero_lina", target=ZEUS, actor_hero=True):
    return {"t": t, "type": "DAMAGE", "actor": actor, "target": target,
            "inflictor": "x", "value": value, "actor_hero": actor_hero,
            "target_hero": True}


def _death_at(tl, t, log_row=True):
    """Append the hp>0 -> hp<=0 transition that IS a death to this tool, plus
    (optionally) the combat-log row that is only the cross-check."""
    tl["snapshots"].append(_snap(t, ZEUS, 2, 0, 0, 0, 0.0, 400, 2, 0))
    tl["snapshots"].append(_snap(t, "npc_dota_hero_lina", 3, 800, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=2))
    if log_row:
        tl["events"].append({"t": t, "type": "DEATH", "actor": "npc_dota_hero_lina",
                             "target": ZEUS, "inflictor": "x", "value": 0,
                             "actor_hero": True, "target_hero": True})
    return tl


def _base_tl(**kw):
    """One Zeus frame that IS in the domain, plus an enemy at 800u."""
    hp_pct = kw.get("hp_pct", 0.20)
    rank = kw.get("rank", 2)
    cd = kw.get("cd", 0)
    mp = kw.get("mp", 400)
    ex = kw.get("enemy_x", 800)
    dmg_t = kw.get("dmg_t", 99.0)
    dmg_actor_hero = kw.get("dmg_actor_hero", True)
    snaps = []
    for t in (100.0,):
        snaps.append(_snap(t, ZEUS, 2, 0, 0, 300, hp_pct, mp, rank, cd))
        snaps.append(_snap(t, "npc_dota_hero_lina", 3, ex, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=2))
    return {"game": {}, "snapshots": snaps, "events": [_dmg(dmg_t, actor_hero=dmg_actor_hero)],
            "creeps": [], "buildings": [], "wards": []}


def selfcheck():
    mana, cd_lad = read_ult_kv()
    passed, failed = [], []

    def check(name, got, want):
        if got == want:
            passed.append(name)
        else:
            failed.append("%s: got %r want %r" % (name, got, want))

    # --- the KV read itself (M: retype 250/375/500 and this is the only leg
    #     that can see it moving) ---------------------------------------
    check("kv_mana_ladder", mana, [250.0, 375.0, 500.0])
    check("kv_cooldown_flat", cd_lad, [130.0])
    check("kv_cd_has_no_rank_ladder", len(cd_lad), 1)
    check("cost_rank1", mana_cost_for_rank(mana, 1), 250.0)
    check("cost_rank3", mana_cost_for_rank(mana, 3), 500.0)
    check("cost_rank0_is_none", mana_cost_for_rank(mana, 0), None)
    # a rank above the ladder repeats the last value rather than crashing
    check("cost_rank4_clamps", mana_cost_for_rank(mana, 4), 500.0)

    # --- the arithmetic the whole issue rests on ----------------------
    check("shipped_conjunct_false_at_every_rank",
          all(75.0 > c for c in cd_lad), False)

    # --- one conjunct at a time; each must be able to zero the count ---
    base = scan_game(_base_tl(), "g", mana, cd_lad)
    check("base_frame_in_domain", base["frames"], 1)
    check("base_rank_hist", base["rank_hist"], {2: 1})
    check("base_in_chase_radius", base["in_chase_radius"], 1)
    check("base_out_chase_radius", base["out_chase_radius"], 0)
    check("base_ultcash_ring", base["ultcash_ring_only"], 1)
    check("base_episodes", len(base["episodes"]), 1)

    check("hp_above_gate_excluded",
          scan_game(_base_tl(hp_pct=0.29), "g", mana, cd_lad)["frames"], 0)
    check("hp_at_gate_included",
          scan_game(_base_tl(hp_pct=0.28), "g", mana, cd_lad)["frames"], 1)
    check("ult_unlearned_excluded",
          scan_game(_base_tl(rank=0), "g", mana, cd_lad)["frames"], 0)
    check("ult_on_cooldown_excluded",
          scan_game(_base_tl(cd=2.2), "g", mana, cd_lad)["frames"], 0)
    check("mana_below_rank_cost_excluded",
          scan_game(_base_tl(rank=2, mp=374), "g", mana, cd_lad)["frames"], 0)
    check("mana_at_rank_cost_included",
          scan_game(_base_tl(rank=2, mp=375), "g", mana, cd_lad)["frames"], 1)
    # the SAME mana passes at rank 1 and fails at rank 2 -- the ladder is read,
    # not a single number
    check("rank1_cheaper_than_rank2",
          scan_game(_base_tl(rank=1, mp=300), "g", mana, cd_lad)["frames"], 1)
    check("rank2_same_mana_excluded",
          scan_game(_base_tl(rank=2, mp=300), "g", mana, cd_lad)["frames"], 0)
    check("no_recent_hero_damage_excluded",
          scan_game(_base_tl(dmg_t=97.0), "g", mana, cd_lad)["frames"], 0)
    check("damage_exactly_at_lookback_edge_excluded",
          scan_game(_base_tl(dmg_t=98.0), "g", mana, cd_lad)["frames"], 0)
    check("damage_just_inside_lookback_included",
          scan_game(_base_tl(dmg_t=98.01), "g", mana, cd_lad)["frames"], 1)
    check("non_hero_damage_excluded",
          scan_game(_base_tl(dmg_actor_hero=False), "g", mana, cd_lad)["frames"], 0)

    # --- (3) the radius term, both sides of the boundary --------------
    far = scan_game(_base_tl(enemy_x=1601), "g", mana, cd_lad)
    check("enemy_outside_1600_still_in_domain", far["frames"], 1)
    check("enemy_outside_1600_not_in_chase", far["in_chase_radius"], 0)
    check("enemy_outside_1600_counted_out", far["out_chase_radius"], 1)
    check("enemy_outside_1600_no_ultcash_ring", far["ultcash_ring_only"], 0)
    edge = scan_game(_base_tl(enemy_x=1600), "g", mana, cd_lad)
    check("enemy_at_1600_is_inside", edge["in_chase_radius"], 1)
    mid = scan_game(_base_tl(enemy_x=1400), "g", mana, cd_lad)
    check("enemy_at_1400_in_1600_not_1200", (mid["in_chase_radius"], mid["ultcash_ring_only"]), (1, 0))

    # --- (2) the value column ----------------------------------------
    r = scan_game(_death_at(_base_tl(), 103.0), "g", mana, cd_lad)
    check("death_in_window_marked", r["episodes"][0]["died_within_window"], True)
    check("death_ult_uncast", r["episodes"][0]["ult_cast_before_death"], False)
    check("death_holding_castable_ult", r["deaths_holding_castable_ult"], 1)
    check("death_t_recorded", r["episodes"][0]["death_t"], 103.0)

    r2 = scan_game(_death_at(_base_tl(), 120.0), "g", mana, cd_lad)
    check("death_outside_window_not_marked", r2["episodes"][0]["died_within_window"], False)
    check("late_death_no_pre_snapshot", r2["deaths_holding_castable_ult"], 0)
    check("late_death_counted_as_unreadable_not_as_not_holding",
          r2["deaths_with_pre_snapshot"], 0)
    # the 3s pre-death window has an edge, and it is tested on both sides
    for gap, want in ((2.99, 1), (3.01, 0)):
        check("pre_death_window_gap_%s" % gap,
              scan_game(_death_at(_base_tl(), 100.0 + gap), "g", mana,
                        cd_lad)["deaths_with_pre_snapshot"], want)
    # a death while the ult is on cooldown is a death, but not one "holding" it
    rc = scan_game(_death_at(_base_tl(cd=40.0), 102.0), "g", mana, cd_lad)
    check("death_on_cooldown_seen_but_not_holding",
          (rc["deaths_with_pre_snapshot"], rc["deaths_holding_castable_ult"]), (1, 0))

    tl3 = _death_at(_base_tl(), 103.0)
    tl3["events"].append({"t": 101.0, "type": "ABILITY", "actor": ZEUS,
                          "target": "npc_dota_hero_lina", "inflictor": ULT,
                          "value": 0, "actor_hero": True, "target_hero": True})
    r3 = scan_game(tl3, "g", mana, cd_lad)
    check("ult_cast_before_death_seen", r3["episodes"][0]["ult_cast_before_death"], True)
    check("ult_cast_counted", r3["n_ult_casts"], 1)
    # an ult cast by SOMEONE ELSE is not Zeus's
    tl3b = _base_tl()
    tl3b["events"].append({"t": 101.0, "type": "ABILITY", "actor": "npc_dota_hero_lina",
                           "target": ZEUS, "inflictor": ULT, "value": 0,
                           "actor_hero": True, "target_hero": True})
    check("other_actor_ult_not_counted", scan_game(tl3b, "g", mana, cd_lad)["n_ult_casts"], 0)
    # a death of someone ELSE is not Zeus's
    tl3c = _base_tl()
    tl3c["events"].append({"t": 103.0, "type": "DEATH", "actor": "npc_dota_hero_lina",
                           "target": "npc_dota_hero_sven", "inflictor": "x", "value": 0,
                           "actor_hero": True, "target_hero": True})
    check("other_target_death_not_counted", scan_game(tl3c, "g", mana, cd_lad)["n_death_rows"], 0)
    check("other_target_death_no_hp_death", scan_game(tl3c, "g", mana, cd_lad)["n_deaths"], 0)

    # ⭐ the two death counters are DIFFERENT quantities and must be able to
    # disagree: a combat-log row with no hp transition is not a death here...
    tl3d = _base_tl()
    tl3d["events"].append({"t": 103.0, "type": "DEATH", "actor": "npc_dota_hero_lina",
                           "target": ZEUS, "inflictor": "x", "value": 0,
                           "actor_hero": True, "target_hero": True})
    r3d = scan_game(tl3d, "g", mana, cd_lad)
    check("log_row_without_hp_transition_is_not_a_death",
          (r3d["n_death_rows"], r3d["n_deaths"]), (1, 0))
    # ... and an hp transition with no log row IS one.
    r3e = scan_game(_death_at(_base_tl(), 103.0, log_row=False), "g", mana, cd_lad)
    check("hp_transition_without_log_row_is_a_death",
          (r3e["n_death_rows"], r3e["n_deaths"]), (0, 1))

    # ⭐ ILLUSIONS: same hero name, same player_id, a different idx and a
    # different position.  The real entity is the one with the most rows.
    tli = _base_tl()
    tli["snapshots"].append(_snap(100.0, ZEUS, 2, 5000, 0, 300, 0.20, 400, 2, 0, idx=77))
    tli["snapshots"].append(_snap(100.5, ZEUS, 2, 0, 0, 300, 0.20, 400, 2, 0))
    tli["snapshots"].append(_snap(100.5, "npc_dota_hero_lina", 3, 800, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=2))
    tli["events"].append(_dmg(100.2))
    ri = scan_game(tli, "g", mana, cd_lad)
    check("illusion_rows_excluded_from_domain", ri["frames"], 2)
    check("illusion_rows_counted_separately", ri["zeus_illusion_rows"], 1)
    check("no_real_idx_tie", ri["real_idx_ties"], [])
    # an enemy illusion DOES count for the lever (J.GetNearbyHeroes has no
    # illusion filter) and is excluded only in the companion column
    tlj = _base_tl(enemy_x=5000)
    tlj["snapshots"].append(_snap(100.0, "npc_dota_hero_lina", 3, 900, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=99))
    tlj["snapshots"].append(_snap(101.0, "npc_dota_hero_lina", 3, 5000, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=2))
    rj = scan_game(tlj, "g", mana, cd_lad)
    check("enemy_illusion_counts_for_the_lever", rj["in_chase_radius"], 1)
    check("enemy_illusion_excluded_from_companion", rj["in_chase_radius_real_only"], 0)

    # --- (4) the retrospective ultcash proxy --------------------------
    tl4 = _base_tl()
    tl4["events"].append(_dmg(101.5, value=400))
    r4 = scan_game(tl4, "g", mana, cd_lad)
    check("retro_proxy_fires_when_next3s_damage_exceeds_hp",
          r4["ultcash_retro_and_ring"], 1)
    tl5 = _base_tl()
    tl5["events"].append(_dmg(101.5, value=10))
    check("retro_proxy_silent_on_small_damage",
          scan_game(tl5, "g", mana, cd_lad)["ultcash_retro_and_ring"], 0)
    tl6 = _base_tl(enemy_x=1601)
    tl6["events"].append(_dmg(101.5, value=400))
    check("retro_proxy_needs_the_ring_too",
          scan_game(tl6, "g", mana, cd_lad)["ultcash_retro_and_ring"], 0)

    # --- episodes group by gap, not by count --------------------------
    tl7 = _base_tl()
    for t in (100.5, 101.0, 104.0):
        tl7["snapshots"].append(_snap(t, ZEUS, 2, 0, 0, 300, 0.20, 400, 2, 0))
        tl7["snapshots"].append(_snap(t, "npc_dota_hero_lina", 3, 800, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=2))
    tl7["events"] += [_dmg(99.6), _dmg(100.2), _dmg(103.5)]
    r7 = scan_game(tl7, "g", mana, cd_lad)
    check("gapped_frames_split_into_two_episodes", len(r7["episodes"]), 2)
    check("gapped_frames_total", r7["frames"], 4)
    check("first_episode_span", (r7["episodes"][0]["t0"], r7["episodes"][0]["t1"]), (100.0, 101.0))

    # --- the retreat proxy is reported, and is NOT the mode -----------
    tl8 = {"game": {}, "snapshots": [], "events": [_dmg(99.0), _dmg(100.2)],
           "creeps": [], "buildings": [], "wards": []}
    for t, zx, ex in ((100.0, 0, 800), (100.5, -200, 800)):
        tl8["snapshots"].append(_snap(t, ZEUS, 2, zx, 0, 300, 0.20, 400, 2, 0))
        tl8["snapshots"].append(_snap(t, "npc_dota_hero_lina", 3, ex, 0, 1000, 1.0, 500, 1, 0, pid=6, idx=2))
    r8 = scan_game(tl8, "g", mana, cd_lad)
    check("retreat_proxy_counts_moving_away", r8["retreat_proxy_frames"], 1)
    check("retreat_proxy_is_a_subset_of_frames", r8["retreat_proxy_frames"] <= r8["frames"], True)

    # --- dead Zeus rows never enter the domain ------------------------
    tl9 = _base_tl()
    tl9["snapshots"][0]["hp"] = 0
    check("dead_frame_excluded", scan_game(tl9, "g", mana, cd_lad)["frames"], 0)

    # --- a null `abilities` list is UNREADABLE, not "ult not learned" -
    tl10 = _base_tl()
    tl10["snapshots"][0]["abilities"] = None
    r10 = scan_game(tl10, "g", mana, cd_lad)
    check("null_abilities_not_in_domain", r10["frames"], 0)
    check("null_abilities_counted_separately", r10["zeus_snapshots_null_abilities"], 1)
    # ... and an EMPTY list is a different thing again: readable, no ult row
    tl11 = _base_tl()
    tl11["snapshots"][0]["abilities"] = []
    r11 = scan_game(tl11, "g", mana, cd_lad)
    check("empty_abilities_not_in_domain", r11["frames"], 0)
    check("empty_abilities_not_counted_as_null", r11["zeus_snapshots_null_abilities"], 0)

    # --- 4(i-a): the side stratum is a reading, not a label -----------
    check("side_bucket_radiant", base["by_side"]["radiant"]["frames"], 1)
    check("side_bucket_only_one_side_present", sorted(base["by_side"].keys()), ["radiant"])
    tld = _base_tl()
    for r_ in tld["snapshots"]:
        r_["team"] = 3 if r_["hero"] == ZEUS else 2
    rd = scan_game(tld, "g", mana, cd_lad)
    check("side_bucket_dire", rd["by_side"]["dire"]["frames"], 1)
    check("side_bucket_dire_no_radiant_row", "radiant" in rd["by_side"], False)
    check("side_episode_tagged", rd["episodes"][0]["side"], "dire")
    check("side_frames_sum_to_total",
          sum(b["frames"] for b in rd["by_side"].values()), rd["frames"])

    # --- the key census is a reading, so it must actually count -------
    check("key_shapes_single_shape", len(base["key_shapes"]), 1)
    check("key_shapes_total", sum(base["key_shapes"].values()), 2)

    for p in passed:
        print("PASS %s" % p)
    for f in failed:
        print("FAIL %s" % f)
    print("SELFCHECK %d PASS / %d FAIL" % (len(passed), len(failed)))
    return 0 if not failed else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--game", help="a dumped timeline .json")
    ap.add_argument("--game-id", default=None)
    ap.add_argument("--out")
    ap.add_argument("--aggregate", nargs="*")
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()

    mana, cd_lad = read_ult_kv()

    if args.aggregate is not None:
        paths = args.aggregate
        if len(paths) == 1 and os.path.isdir(paths[0]):
            paths = [os.path.join(paths[0], f) for f in sorted(os.listdir(paths[0]))
                     if f.endswith(".json")]
        agg = aggregate(paths)
        txt = json.dumps(agg, indent=1, sort_keys=True)
        if args.out:
            open(args.out, "w").write(txt)
        else:
            print(txt)
        return 0

    if not args.game:
        ap.error("need --game or --aggregate or --selfcheck")
    tl = json.load(open(args.game))
    gid = args.game_id or os.path.basename(args.game).replace(".json", "")
    r = scan_game(tl, gid, mana, cd_lad)
    txt = json.dumps(r, indent=1, sort_keys=True)
    if args.out:
        open(args.out, "w").write(txt)
    else:
        print(txt)
    return 0


if __name__ == "__main__":
    sys.exit(main())

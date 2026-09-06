#!/usr/bin/env python3
"""`cullthresh` condition-(a) domain census over an archived Axe corpus.

WHAT THIS ANSWERS (queue row hero-2 / GH #115 section 5 / GH #146)
------------------------------------------------------------------
`cullthresh` (hero_axe.lua:1147 `X.CullKillThreshold`, gated, never armed)
replaces Axe's hardcoded execute estimate `150 + 100*lv` = 250/350/450 with
`abilityR:GetSpecialValueInt('damage')` = 275/375/475, and only when the live
read is STRICTLY GREATER.  So the lever changes exactly one thing: the
threshold the `X.ConsiderR` execute loop compares against.

THE BAND, WRITTEN FROM THE CODE AND NOT FROM THE REQUEST
--------------------------------------------------------
The queue row and the helper header both write the domain as the half-open
interval `(150 + 100*lv, damage[lv]]`.  The comparison in the loop is

    npcEnemy:GetHealth() + npcEnemy:GetHealthRegen() * 0.8 < nKillDamage

-- STRICTLY LESS THAN.  A target is therefore declined by the shipped tree and
accepted by the armed tree iff

    150 + 100*lv  <=  hp_eff  <  damage[lv]

i.e. the CLOSED-OPEN band [250,275) / [350,375) / [450,475).  Both endpoints
move by one side relative to the prose: hp_eff == 250 is IN the domain (shipped
declines it) and hp_eff == 275 is OUT (armed declines it too).  The band is 25
points wide either way, so no published magnitude changes -- but a frame is
pinned or not pinned by the endpoint, so the code's version is used here.

THE CALIBER IS CROSSINGS, NOT BAND-OCCUPIED FRAMES
---------------------------------------------------
Pre-registered in queue.json:hero-2 `acceptance_amendment_hero_20260830`.  A
25-point band on a ~1000 health pool is hit by a uniformly drawn frame with
probability ~0.022 (one hit per ~45 in-ring frames), which is why the fixture
library's zero is underpowered rather than empty.  An enemy does not sit in the
band, it FALLS THROUGH it, so the observable is the CROSSING: two adjacent 1 Hz
samples of the same enemy entity whose health segment [hp_next, hp_prev]
intersects the band while the branch's other conditions hold.  Crossings are
counted here as the domain proper; band-occupied frames are reported beside
them as the (much smaller) set of instants a fixture can actually be cut from.

Capture rate, from the same pre-registration: p = min(1, band/(v*dt)), an UPPER
bound (it assumes a monotone constant-velocity descent and independent sampling
phase; a heal, or one hit that clears the whole band, only lowers it).

PREDICATE FIDELITY (all-stream rule U.1.1 -- thresholds verbatim from source)
-----------------------------------------------------------------------------
  X.ConsiderR (hero_axe.lua:1170-1220), in source order:
    * `abilityR:IsFullyCastable()` -- trained, off cooldown, mana affordable.
      AbilityManaCost 100/125/150, AbilityCooldown 80/75/70
      (tests/mock/special_value_shapes.lua, from npc_dota_hero_axe.txt).
    * `nCastRange = abilityR:GetCastRange()` = AbilityCastRange 175.
    * the loop iterates `J.GetAroundEnemyHeroList( nCastRange + 200 )` = 375u.
      The bare 175u list is computed into `nInRangeEnemyList` and NEVER READ --
      the correction the queue row already carries.  Both rings are reported.
    * `J.IsValidHero` + `npcEnemy:CanBeSeen()`      -- see LIMITS 2
    * `hp + hp_regen*0.8 < nKillDamage`             -- see LIMITS 1
    * `not J.IsHaveAegis( npcEnemy )`
    * `not npcEnemy:IsInvulnerable()`
    * `not npcEnemy:IsMagicImmune()`  (the `X.IsCullPierceOn()` escape is the
      SEPARATE unarmed candidate `axecall`/`axecull`, off here)
    * `not X.HasSpecialModifier( npcEnemy )`        -- the seven names below
    * `not X.IsKillBotAntiMage( npcEnemy )`

LIMITS (read these before quoting any number)
---------------------------------------------
 1. HEALTH REGEN IS NOT IN THE DUMP.  The branch tests `hp + hp_regen*0.8`;
    snapshots carry `hp` only.  At a typical hero regen of 2-10 HP/s the term
    is 1.6-8 points against a 25-point band, so it is NOT negligible: it
    shifts every classification UP by that much.  Reading hp alone therefore
    reports a band that is offset, not one that is wrong-sized, and a frame
    pinned here must be re-checked against the real handle by the fixture
    (make_fixture.py carries the true regen).  Reported as `hp_only`.
 2. FOG IS NOT IN THE DUMP.  `CanBeSeen()` cannot be evaluated offline (the
    replay is omniscient; see the dumper's own `vision_note`).  Every count
    here is therefore an UPPER bound on the branch's reach.  A 375u ring is
    small enough that a hero inside it is usually visible, but "usually" is
    not a predicate -- so any frame proposed for a fixture is printed with
    its distance so the reviewer can judge.
 3. 1 Hz UNDERSAMPLES THE BAND.  That is the whole reason for the crossing
    caliber; see above.  Do not read the band-occupied frame count as the
    domain -- it is the fixture-pinnable subset of it.
 4. ILLUSIONS SHARE THE HERO NAME (GH #176).  Guarded by birth time: the real
    hero is the entity present at that hero name's OWN earliest sample.
    Discarded sample count is reported.
 5. MODIFIER STATE is reconstructed from ADD/REMOVE intervals, which are not
    sampled, so immunity/aegis windows shorter than 1s are still seen.  A
    modifier the dumper does not emit would make the domain too large.

USAGE
    cullthresh_domain.py --selfcheck
    cullthresh_domain.py TL_DIR [--json out.json]
    cullthresh_domain.py TL_DIR --frames [--top N]
    cullthresh_domain.py TL_DIR --list-modifiers
"""

import argparse
import bisect
import collections
import glob
import json
import math
import os
import sys

AXE = "npc_dota_hero_axe"
CULL = "axe_culling_blade"

# --- verbatim from tests/mock/special_value_shapes.lua (KV snapshot) --------
CULL_MANA = [100, 125, 150]          # AbilityManaCost, by rank-1 index
CULL_LIVE_DAMAGE = [275, 375, 475]   # AbilityValues/damage -- the ARMED read
CULL_CAST_RANGE = 175.0              # AbilityCastRange
RING_BONUS = 200.0                   # nCastRange + 200, the list actually read
SNAP_DT = 1.0                        # dumper -interval default

# X.HasSpecialModifier( npcEnemy ) -- hero_axe.lua, verbatim, all seven
SPECIAL_MODIFIERS = {
    "modifier_winter_wyvern_winters_curse",
    "modifier_winter_wyvern_winters_curse_aura",
    "modifier_antimage_spell_shield",
    "modifier_item_lotus_orb_active",
    "modifier_item_aeon_disk_buff",
    "modifier_item_sphere_target",
    "modifier_illusion",
}

# npcEnemy:IsMagicImmune().  SPELL immunity only -- the 2026-09-06 lesson from
# liondrainbkb's first pass is that a physical-immunity or damage-amp modifier
# in this list manufactures domain out of nothing.  Every name here blocks a
# targeted enemy spell.
IMMUNITY_MODIFIERS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
    "modifier_omniknight_repel",
    "modifier_item_ultimate_scepter_consumed_bonus_spell_immunity",
    "modifier_pudge_meat_shield",
}

# J.IsHaveAegis / IsInvulnerable, as far as a replay can answer them.
AEGIS_MODIFIERS = {"modifier_item_aegis"}
INVULNERABLE_MODIFIERS = {
    "modifier_eul_cyclone",
    "modifier_invoker_tornado",
    "modifier_brewmaster_storm_cyclone",
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_outworld_destroyer_astral_imprisonment_prison",
    "modifier_shadow_demon_disruption",
    "modifier_dark_willow_shadow_realm",
    "modifier_puck_phase_shift",
    "modifier_item_shadow_amulet_fade",
}

ANTIMAGE = "npc_dota_hero_antimage"


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def shipped_threshold(rank):
    """hero_axe.lua X.CullKillThreshold with the gate OFF.

    The `talent8` term is a hero-UNIQUE talent handle that owns no KV block and
    answers 0 (GH #228), so gate-off is exactly 150 + 100*lv.
    """
    return 150 + 100 * rank


def armed_threshold(rank):
    """Gate ON: the live KV read, taken only when STRICTLY greater."""
    live = CULL_LIVE_DAMAGE[rank - 1]
    base = shipped_threshold(rank)
    return live if live > base else base


def band(rank):
    """[lo, hi) -- declined by shipped, accepted by armed.  See module header."""
    return shipped_threshold(rank), armed_threshold(rank)


def build_modifier_intervals(events, names):
    """{(target, modifier): [(t_add, t_remove), ...]} for the given names."""
    open_at = {}
    out = collections.defaultdict(list)
    for e in events:
        if e["type"] not in ("MODIFIER_ADD", "MODIFIER_REMOVE"):
            continue
        name = e.get("inflictor")
        if name not in names:
            continue
        key = (e.get("target"), name)
        if e["type"] == "MODIFIER_ADD":
            open_at.setdefault(key, e["t"])
        else:
            start = open_at.pop(key, None)
            if start is not None:
                out[key].append((start, e["t"]))
    for key, start in open_at.items():
        out[key].append((start, float("inf")))
    for key in out:
        out[key].sort()
    return dict(out)


def active_modifiers(intervals, target, t):
    hits = set()
    for (tgt, name), spans in intervals.items():
        if tgt != target:
            continue
        for a, b in spans:
            if a <= t <= b:
                hits.add(name)
                break
    return hits


def real_entity_index(snapshots):
    """GH #176 illusion guard: the real hero is the entity at its own earliest
    sample.  Returns ({hero: idx}, discarded_sample_count)."""
    first_t, first_idx = {}, {}
    for s in snapshots:
        h = s["hero"]
        if h not in first_t or s["t"] < first_t[h]:
            first_t[h], first_idx[h] = s["t"], s.get("idx")
    return first_idx, first_t


# --------------------------------------------------------------------------
# per-game scan
# --------------------------------------------------------------------------
def scan_game(tl, key):
    game = tl.get("game", {})
    teams = game.get("teams", {})
    if AXE not in teams:
        return None
    axe_team = teams[AXE]

    events = tl.get("events") or []
    watched = (SPECIAL_MODIFIERS | IMMUNITY_MODIFIERS
               | AEGIS_MODIFIERS | INVULNERABLE_MODIFIERS)
    intervals = build_modifier_intervals(events, watched)

    deaths = collections.defaultdict(list)
    for e in events:
        if e["type"] == "DEATH" and e.get("target_hero"):
            deaths[e.get("target")].append(e["t"])
    for k in deaths:
        deaths[k].sort()

    def died_within(hero, t, window):
        ts = deaths.get(hero) or []
        i = bisect.bisect_left(ts, t)
        return i < len(ts) and ts[i] <= t + window

    casts = [e for e in events
             if e["type"] == "ABILITY" and e.get("actor") == AXE
             and e.get("inflictor") == CULL]
    cast_ts = sorted(e["t"] for e in casts)

    def cast_within(t, window):
        i = bisect.bisect_left(cast_ts, t)
        return i < len(cast_ts) and cast_ts[i] <= t + window

    snaps = tl.get("snapshots") or []
    first_idx, _ = real_entity_index(snaps)
    discarded = 0
    by_t = collections.defaultdict(dict)
    for s in snaps:
        h = s["hero"]
        if s.get("idx") != first_idx.get(h):
            discarded += 1
            continue
        by_t[s["t"]][h] = s

    times = sorted(by_t)
    prev_frame = None

    band_rows = []       # sampled instants with a target inside the band
    shipped_rows = []    # sampled instants ALREADY under the shipped threshold
    crossings = []       # adjacent-pair health segments intersecting the band
    ready_frames = 0     # Axe alive + Culling fully castable
    ring_frames = 0      # ... and at least one eligible enemy inside 375u
    ring175_frames = 0
    eligible_rows = 0    # eligible enemy-frames (the in-ring denominator)
    hp_pool = []         # eligible enemy max-health, for the pool model
    rank_hist = collections.Counter()

    for t in times:
        frame = by_t[t]
        axe = frame.get(AXE)
        if axe is None or axe.get("hp", 0) <= 0:
            prev_frame = frame
            continue
        abils = {a["name"]: a for a in (axe.get("abilities") or [])}
        r = abils.get(CULL)
        if r is None or r["level"] < 1 or r["cd"] > 0:
            prev_frame = frame
            continue
        rank = min(int(r["level"]), 3)
        if axe.get("mp", 0) < CULL_MANA[rank - 1]:
            prev_frame = frame
            continue
        ready_frames += 1
        rank_hist[rank] += 1
        lo, hi = band(rank)

        any_ring, any_ring175 = False, False
        for h, s in frame.items():
            if teams.get(h) == axe_team or s.get("hp", 0) <= 0:
                continue
            d = dist(s, axe)
            if d > CULL_CAST_RANGE + RING_BONUS:
                continue
            act = active_modifiers(intervals, h, t)
            if act & IMMUNITY_MODIFIERS or act & SPECIAL_MODIFIERS \
               or act & AEGIS_MODIFIERS or act & INVULNERABLE_MODIFIERS:
                continue
            if h == ANTIMAGE:
                continue
            any_ring = True
            eligible_rows += 1
            pct = s.get("hp_pct") or 0
            max_hp = int(round(s["hp"] / pct)) if pct > 0 else None
            if max_hp:
                hp_pool.append(max_hp)
            if d <= CULL_CAST_RANGE:
                any_ring175 = True
            hp = s["hp"]

            if hp < lo:
                # ALREADY accepted by the SHIPPED threshold.  This is not the
                # lever's domain -- it is the control that says whether the
                # branch the lever widens fires at all.  A lever that widens a
                # branch nothing reaches buys nothing, so this column is
                # measured beside the band and never pooled with it.
                shipped_rows.append({
                    "game": key, "t": t, "target": h, "rank": rank,
                    "hp": hp, "dist": round(d, 1),
                    "inside_175": d <= CULL_CAST_RANGE,
                    "shipped_threshold": lo,
                    "died_5s": died_within(h, t, 5.0),
                    "cull_cast_2s": cast_within(t, 2.0),
                })

            if lo <= hp < hi:
                band_rows.append({
                    "game": key, "t": t, "target": h, "rank": rank,
                    "hp": hp, "max_hp": max_hp, "dist": round(d, 1),
                    "inside_175": d <= CULL_CAST_RANGE,
                    "band": [lo, hi],
                    "axe_mp": axe.get("mp"), "axe_level": axe.get("level"),
                    "died_5s": died_within(h, t, 5.0),
                    "cull_cast_2s": cast_within(t, 2.0),
                })

            # crossing: same entity, previous sample, health falling through
            if prev_frame is not None:
                ps = prev_frame.get(h)
                if ps is not None and ps.get("hp", 0) > 0:
                    hp_prev, hp_next = ps["hp"], hp
                    if hp_next < hp_prev and hp_prev > lo and hp_next < hi:
                        v = (hp_prev - hp_next) / SNAP_DT
                        crossings.append({
                            "game": key, "t": t, "target": h, "rank": rank,
                            "hp_prev": hp_prev, "hp_next": hp_next,
                            "v": v, "dist": round(d, 1),
                            "inside_175": d <= CULL_CAST_RANGE,
                            "sampled_in_band": lo <= hp_next < hi
                                               or lo <= hp_prev < hi,
                            "p_capture": min(1.0, (hi - lo) / (v * SNAP_DT))
                                         if v > 0 else 1.0,
                            "died_5s": died_within(h, t, 5.0),
                        })
        if any_ring:
            ring_frames += 1
        if any_ring175:
            ring175_frames += 1
        prev_frame = frame

    # episodes: band rows on the same target separated by > 3s are distinct
    episodes = 0
    last = {}
    for row in sorted(band_rows, key=lambda r: (r["target"], r["t"])):
        k = row["target"]
        if k not in last or row["t"] - last[k] > 3.0:
            episodes += 1
        last[k] = row["t"]

    return {
        "game": key,
        "duration": max(times) if times else 0,
        "frames": len(times),
        "discarded_illusion_samples": discarded,
        "ready_frames": ready_frames,
        "ring_frames": ring_frames,
        "ring175_frames": ring175_frames,
        "eligible_enemy_rows": eligible_rows,
        "rank_hist": dict(rank_hist),
        "band_rows": band_rows,
        "shipped_rows": shipped_rows,
        "band_episodes": episodes,
        "crossings": crossings,
        "casts": len(casts),
        "median_max_hp": (sorted(hp_pool)[len(hp_pool) // 2]
                          if hp_pool else None),
    }


# --------------------------------------------------------------------------
# aggregation / reporting
# --------------------------------------------------------------------------
def aggregate(results):
    tot = collections.Counter()
    band_rows, crossings, shipped_rows = [], [], []
    games_with_band, games_with_crossing = set(), set()
    pool = []
    for r in results:
        for k in ("frames", "ready_frames", "ring_frames", "ring175_frames",
                  "eligible_enemy_rows", "casts", "band_episodes",
                  "discarded_illusion_samples"):
            tot[k] += r[k]
        band_rows.extend(r["band_rows"])
        shipped_rows.extend(r["shipped_rows"])
        crossings.extend(r["crossings"])
        if r["band_rows"]:
            games_with_band.add(r["game"])
        if r["crossings"]:
            games_with_crossing.add(r["game"])
        if r["median_max_hp"]:
            pool.append(r["median_max_hp"])
    return {
        "games": len(results),
        "totals": dict(tot),
        "band_rows": band_rows,
        "shipped_rows": shipped_rows,
        "crossings": crossings,
        "games_with_band": sorted(games_with_band),
        "games_with_crossing": sorted(games_with_crossing),
        "median_max_hp_of_game_medians": (sorted(pool)[len(pool) // 2]
                                          if pool else None),
    }


def print_report(agg):
    t = agg["totals"]
    print("=" * 74)
    print("cullthresh (queue hero-2) -- condition (a) domain census")
    print("=" * 74)
    print(f"games scanned                      : {agg['games']}")
    print(f"1 Hz frames                        : {t['frames']}")
    print(f"Axe alive + Culling fully castable : {t['ready_frames']}")
    print(f"  ... eligible enemy inside 375u   : {t['ring_frames']}")
    print(f"  ... eligible enemy inside 175u   : {t['ring175_frames']}")
    print(f"eligible in-ring enemy-frames      : {t['eligible_enemy_rows']}")
    print(f"Culling Blade casts (event side)   : {t['casts']}")
    print(f"illusion samples discarded (#176)  : "
          f"{t['discarded_illusion_samples']}")
    print()
    print("--- the caliber: CROSSINGS (queue acceptance amendment 2026-08-30)")
    cr = agg["crossings"]
    cr175 = [c for c in cr if c["inside_175"]]
    print(f"crossings, 375u ring               : {len(cr)}"
          f"   in {len(agg['games_with_crossing'])} game(s)")
    print(f"crossings, 175u ring               : {len(cr175)}")
    if cr:
        exp = sum(c["p_capture"] for c in cr)
        vs = sorted(c["v"] for c in cr)
        print(f"expected captures  sum p           : {exp:.2f}"
              f"   (UPPER bound, see LIMITS 3)")
        print(f"health velocity  mean / max (HP/s) : "
              f"{sum(vs)/len(vs):.1f} / {vs[-1]:.1f}")
        below = sum(1 for v in vs if v <= 25.0)
        print(f"crossings slow enough to be caught : {below}"
              f"  ({100.0*below/len(vs):.1f}%  v <= band width)")
    print()
    print("--- band-occupied SAMPLED frames (the fixture-pinnable subset)")
    br = agg["band_rows"]
    print(f"band-occupied enemy-frames         : {len(br)}"
          f"   in {len(agg['games_with_band'])} game(s)")
    print(f"band episodes                      : {t['band_episodes']}")
    print(f"  ... inside 175u                  : "
          f"{sum(1 for b in br if b['inside_175'])}")
    print(f"  ... target died within 5s        : "
          f"{sum(1 for b in br if b['died_5s'])}")
    print(f"  ... a Culling cast followed <=2s : "
          f"{sum(1 for b in br if b['cull_cast_2s'])}")
    print()
    sr = agg["shipped_rows"]
    sr175 = [r for r in sr if r["inside_175"]]
    print("--- CONTROL: does the branch the lever widens fire at all?")
    print(f"instants already under the SHIPPED line : {len(sr)}"
          f"  ({len(sr175)} inside 175u)")
    if sr175:
        fired = sum(1 for r in sr175 if r["cull_cast_2s"])
        print(f"  ... a Culling cast followed <=2s      : {fired}"
              f"  ({100.0*fired/len(sr175):.1f}%)")
        print(f"  ... target died within 5s anyway      : "
              f"{sum(1 for r in sr175 if r['died_5s'])}")
    print()
    print("--- the pool model this replaces (why the frame caliber fails)")
    m = agg["median_max_hp_of_game_medians"]
    if m:
        print(f"median in-ring enemy max health    : {m}")
        print(f"pool-model p(frame in band)        : {25.0/m:.4f}"
              f"   => 1 hit per {m/25.0:.1f} in-ring frames")
        print(f"pool-model expected band frames    : "
              f"{t['eligible_enemy_rows'] * 25.0 / m:.2f}")
    print("=" * 74)


def print_frames(agg, top):
    br = sorted(agg["band_rows"], key=lambda r: (not r["inside_175"],
                                                 r["dist"]))
    print(f"--- band-occupied frames ({len(br)} total), nearest first")
    for r in br[:top]:
        print(f"  {r['game']}  t={r['t']}  {r['target']}  rank={r['rank']} "
              f"band=[{r['band'][0]},{r['band'][1]})  hp={r['hp']}"
              f"/{r['max_hp']}  d={r['dist']}"
              f"{'  <=175u' if r['inside_175'] else ''}"
              f"  died5s={r['died_5s']}  cast2s={r['cull_cast_2s']}")
    print()
    cr = sorted(agg["crossings"], key=lambda r: r["v"])
    print(f"--- crossings ({len(cr)} total), slowest (most catchable) first")
    for r in cr[:top]:
        print(f"  {r['game']}  t={r['t']}  {r['target']}  rank={r['rank']} "
              f"hp {r['hp_prev']} -> {r['hp_next']}  v={r['v']:.0f}HP/s "
              f"d={r['dist']}{'  <=175u' if r['inside_175'] else ''} "
              f"p={r['p_capture']:.2f}  died5s={r['died_5s']}")


# --------------------------------------------------------------------------
# selfcheck
# --------------------------------------------------------------------------
def _snap(t, hero, idx, team, x, y, hp, hp_pct=1.0, mp=1000, level=10,
          abilities=None):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "x": x, "y": y,
            "hp": hp, "hp_pct": hp_pct, "mp": mp, "level": level,
            "items": [], "abilities": abilities if abilities is not None else
            [{"name": CULL, "level": 1, "cd": 0, "cd_len": 80}]}


def _tl(snapshots, events=None, teams=None):
    return {"game": {"teams": teams or {AXE: 2, "npc_dota_hero_lina": 3}},
            "snapshots": snapshots, "events": events or []}


def selfcheck():
    checks = []

    def ck(name, cond):
        checks.append((name, bool(cond)))

    # --- band arithmetic reads off the code, not the prose ------------------
    ck("band_rank1_is_250_275", band(1) == (250, 275))
    ck("band_rank2_is_350_375", band(2) == (350, 375))
    ck("band_rank3_is_450_475", band(3) == (450, 475))
    ck("band_width_is_25_every_rank",
       all(band(r)[1] - band(r)[0] == 25 for r in (1, 2, 3)))
    ck("lower_endpoint_is_INSIDE_the_band", band(1)[0] == 250)
    ck("upper_endpoint_is_OUTSIDE_the_band", band(1)[1] == 275)
    ck("armed_never_below_shipped",
       all(armed_threshold(r) >= shipped_threshold(r) for r in (1, 2, 3)))

    L = "npc_dota_hero_lina"

    # --- a target parked in the band is counted ----------------------------
    snaps = []
    for i, t in enumerate([100.0, 101.0]):
        snaps.append(_snap(t, AXE, 1, 2, 0, 0, 2000))
        snaps.append(_snap(t, L, 2, 3, 100, 0, 260))
    r = scan_game(_tl(snaps), "g")
    ck("band_frame_detected", len(r["band_rows"]) == 2)
    ck("band_frame_inside_175", all(b["inside_175"] for b in r["band_rows"]))
    ck("no_crossing_when_health_flat", len(r["crossings"]) == 0)

    # --- 249 and 275 are OUT (endpoint discipline) -------------------------
    for hp, want in ((249, 0), (250, 1), (274, 1), (275, 0), (276, 0)):
        snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
                 _snap(100.0, L, 2, 3, 100, 0, hp)]
        r = scan_game(_tl(snaps), "g")
        ck(f"endpoint_hp_{hp}_gives_{want}", len(r["band_rows"]) == want)

    # --- a crossing THROUGH the band, never sampled inside it ---------------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 400),
             _snap(101.0, AXE, 1, 2, 0, 0, 2000),
             _snap(101.0, L, 2, 3, 100, 0, 200)]
    r = scan_game(_tl(snaps), "g")
    ck("crossing_detected_without_band_frame",
       len(r["crossings"]) == 1 and len(r["band_rows"]) == 0)
    ck("crossing_velocity_is_per_second", r["crossings"][0]["v"] == 200.0)
    ck("crossing_p_capture_is_band_over_v",
       abs(r["crossings"][0]["p_capture"] - 25.0 / 200.0) < 1e-9)
    ck("crossing_not_marked_sampled_in_band",
       r["crossings"][0]["sampled_in_band"] is False)

    # --- health RISING through the band is not a crossing -------------------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 200),
             _snap(101.0, AXE, 1, 2, 0, 0, 2000),
             _snap(101.0, L, 2, 3, 100, 0, 400)]
    r = scan_game(_tl(snaps), "g")
    ck("rising_health_is_not_a_crossing", len(r["crossings"]) == 0)

    # --- a segment entirely above or below the band is not a crossing -------
    for a, b, want in ((900, 500, 0), (200, 100, 0), (300, 260, 1),
                       (260, 100, 1), (276, 275, 0)):
        snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
                 _snap(100.0, L, 2, 3, 100, 0, a),
                 _snap(101.0, AXE, 1, 2, 0, 0, 2000),
                 _snap(101.0, L, 2, 3, 100, 0, b)]
        r = scan_game(_tl(snaps), "g")
        ck(f"segment_{a}_to_{b}_gives_{want}", len(r["crossings"]) == want)

    # --- ring discipline: 375 counted, 376 not; 175 flagged separately ------
    for d, in_ring, in175 in ((174.0, 1, True), (175.0, 1, True),
                              (176.0, 1, False), (375.0, 1, False),
                              (376.0, 0, False)):
        snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
                 _snap(100.0, L, 2, 3, d, 0, 260)]
        r = scan_game(_tl(snaps), "g")
        ck(f"ring_d{d}_counted_{in_ring}", len(r["band_rows"]) == in_ring)
        if in_ring:
            ck(f"ring_d{d}_inside175_{in175}",
               r["band_rows"][0]["inside_175"] is in175)

    # --- readiness: untrained / on cooldown / mana-short all excluded -------
    for abil, mp, want, tag in (
            ([{"name": CULL, "level": 0, "cd": 0, "cd_len": 80}], 1000, 0, "untrained"),
            ([{"name": CULL, "level": 1, "cd": 12.0, "cd_len": 80}], 1000, 0, "cooldown"),
            ([{"name": CULL, "level": 1, "cd": 0, "cd_len": 80}], 99, 0, "mana_short"),
            ([{"name": CULL, "level": 1, "cd": 0, "cd_len": 80}], 100, 1, "mana_exact"),
            ([], 1000, 0, "no_ability_row")):
        snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000, mp=mp, abilities=abil),
                 _snap(100.0, L, 2, 3, 100, 0, 260)]
        r = scan_game(_tl(snaps), "g")
        ck(f"ready_{tag}_gives_{want}", len(r["band_rows"]) == want)

    # --- rank drives the band, and rank 2 mana is 125 -----------------------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000, mp=130,
                   abilities=[{"name": CULL, "level": 2, "cd": 0, "cd_len": 75}]),
             _snap(100.0, L, 2, 3, 100, 0, 360)]
    r = scan_game(_tl(snaps), "g")
    ck("rank2_band_is_350_375", len(r["band_rows"]) == 1
       and r["band_rows"][0]["band"] == [350, 375])
    snaps[0]["mp"] = 124
    r = scan_game(_tl(snaps), "g")
    ck("rank2_mana_floor_is_125", len(r["band_rows"]) == 0)

    # --- exclusions: immunity, special modifier, aegis, anti-mage ----------
    for mod, tag in ((("modifier_black_king_bar_immune"), "magic_immune"),
                     (("modifier_item_aegis"), "aegis"),
                     (("modifier_item_lotus_orb_active"), "lotus"),
                     (("modifier_illusion"), "illusion_modifier"),
                     (("modifier_eul_cyclone"), "invulnerable")):
        snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
                 _snap(100.0, L, 2, 3, 100, 0, 260)]
        ev = [{"t": 50.0, "type": "MODIFIER_ADD", "target": L,
               "inflictor": mod}]
        r = scan_game(_tl(snaps, ev), "g")
        ck(f"excluded_{tag}", len(r["band_rows"]) == 0)

    # a REMOVED modifier stops excluding
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 260)]
    ev = [{"t": 50.0, "type": "MODIFIER_ADD", "target": L,
           "inflictor": "modifier_black_king_bar_immune"},
          {"t": 60.0, "type": "MODIFIER_REMOVE", "target": L,
           "inflictor": "modifier_black_king_bar_immune"}]
    r = scan_game(_tl(snaps, ev), "g")
    ck("expired_immunity_stops_excluding", len(r["band_rows"]) == 1)

    # anti-mage is excluded by name (X.IsKillBotAntiMage, bots only -- kept
    # unconditional here, which makes the domain SMALLER, never larger)
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, ANTIMAGE, 2, 3, 100, 0, 260)]
    r = scan_game(_tl(snaps, teams={AXE: 2, ANTIMAGE: 3}), "g")
    ck("excluded_antimage", len(r["band_rows"]) == 0)

    # --- allies are never targets ------------------------------------------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 2, 100, 0, 260)]
    r = scan_game(_tl(snaps, teams={AXE: 2, L: 2}), "g")
    ck("ally_in_band_not_counted", len(r["band_rows"]) == 0)

    # --- dead units are never targets, and a dead Axe is never ready -------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 0)]
    r = scan_game(_tl(snaps), "g")
    ck("dead_target_not_counted", len(r["band_rows"]) == 0)
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 0),
             _snap(100.0, L, 2, 3, 100, 0, 260)]
    r = scan_game(_tl(snaps), "g")
    ck("dead_axe_not_ready", r["ready_frames"] == 0)

    # --- illusion guard: a later-born entity on the same name is dropped ----
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 900),
             _snap(101.0, AXE, 1, 2, 0, 0, 2000),
             _snap(101.0, L, 2, 3, 100, 0, 900),
             _snap(101.0, L, 77, 3, 100, 0, 260)]
    r = scan_game(_tl(snaps), "g")
    ck("illusion_sample_discarded", r["discarded_illusion_samples"] == 1)
    ck("illusion_does_not_make_domain", len(r["band_rows"]) == 0)

    # --- episodes: 3 consecutive band frames on one target = 1 episode ------
    snaps = []
    for t in (100.0, 101.0, 102.0):
        snaps.append(_snap(t, AXE, 1, 2, 0, 0, 2000))
        snaps.append(_snap(t, L, 2, 3, 100, 0, 260))
    r = scan_game(_tl(snaps), "g")
    ck("consecutive_band_frames_are_one_episode", r["band_episodes"] == 1)
    snaps = []
    for t in (100.0, 101.0, 200.0):
        snaps.append(_snap(t, AXE, 1, 2, 0, 0, 2000))
        snaps.append(_snap(t, L, 2, 3, 100, 0, 260))
    r = scan_game(_tl(snaps), "g")
    ck("gap_splits_episodes", r["band_episodes"] == 2)

    # --- death / cast annotation -------------------------------------------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 260)]
    ev = [{"t": 103.0, "type": "DEATH", "target": L, "actor": AXE,
           "target_hero": True},
          {"t": 101.0, "type": "ABILITY", "actor": AXE, "target": L,
           "inflictor": CULL}]
    r = scan_game(_tl(snaps, ev), "g")
    ck("died_5s_flagged", r["band_rows"][0]["died_5s"] is True)
    ck("cast_2s_flagged", r["band_rows"][0]["cull_cast_2s"] is True)
    ck("cast_counted", r["casts"] == 1)
    ev = [{"t": 110.0, "type": "DEATH", "target": L, "actor": AXE,
           "target_hero": True}]
    r = scan_game(_tl(snaps, ev), "g")
    ck("death_outside_5s_not_flagged", r["band_rows"][0]["died_5s"] is False)

    # --- the shipped-line control column ------------------------------------
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 200)]
    r = scan_game(_tl(snaps), "g")
    ck("under_shipped_line_is_control_not_band",
       len(r["shipped_rows"]) == 1 and len(r["band_rows"]) == 0)
    snaps = [_snap(100.0, AXE, 1, 2, 0, 0, 2000),
             _snap(100.0, L, 2, 3, 100, 0, 260)]
    r = scan_game(_tl(snaps), "g")
    ck("band_row_is_not_also_a_control_row",
       len(r["shipped_rows"]) == 0 and len(r["band_rows"]) == 1)

    # --- a game without Axe returns nothing --------------------------------
    snaps = [_snap(100.0, L, 2, 3, 100, 0, 260)]
    ck("game_without_axe_is_skipped",
       scan_game(_tl(snaps, teams={L: 3}), "g") is None)

    n_pass = sum(1 for _, ok in checks if ok)
    for name, ok in checks:
        if not ok:
            print(f"FAIL {name}")
    print(f"selfcheck: {n_pass} PASS / {len(checks) - n_pass} FAIL")
    return 0 if n_pass == len(checks) else 1


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tl_dir", nargs="?")
    ap.add_argument("--json")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--list-modifiers", action="store_true")
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()
    if not a.tl_dir:
        ap.error("TL_DIR required unless --selfcheck")

    files = sorted(glob.glob(os.path.join(a.tl_dir, "*.json")))
    results, unreadable = [], []
    seen_mods = collections.Counter()
    for f in files:
        key = os.path.basename(f)[:-5]
        try:
            with open(f) as fh:
                tl = json.load(fh)
        except Exception:
            unreadable.append(key)
            continue
        if a.list_modifiers:
            for e in tl.get("events") or []:
                if e["type"] == "MODIFIER_ADD":
                    seen_mods[e.get("inflictor")] += 1
            continue
        r = scan_game(tl, key)
        if r:
            results.append(r)

    if a.list_modifiers:
        watched = (SPECIAL_MODIFIERS | IMMUNITY_MODIFIERS
                   | AEGIS_MODIFIERS | INVULNERABLE_MODIFIERS)
        print("watched modifiers present in this corpus:")
        for m in sorted(watched):
            print(f"  {seen_mods.get(m, 0):7d}  {m}")
        return 0

    if unreadable:
        print(f"unreadable timelines: {len(unreadable)}", file=sys.stderr)
        for u in unreadable:
            print(f"  {u}", file=sys.stderr)

    agg = aggregate(results)
    print_report(agg)
    if a.frames:
        print()
        print_frames(agg, a.top)
    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"per_game": results, "aggregate": {
                k: v for k, v in agg.items()
                if k not in ("band_rows", "crossings", "shipped_rows")},
                "band_rows": agg["band_rows"],
                "shipped_rows": agg["shipped_rows"],
                "crossings": agg["crossings"],
                "unreadable": unreadable}, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

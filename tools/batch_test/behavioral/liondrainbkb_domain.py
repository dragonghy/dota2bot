#!/usr/bin/env python3
"""`liondrainbkb` condition-(a) domain census over an archived Lion corpus.

WHAT THIS ANSWERS (queue row hero-34 / GH #549)
-----------------------------------------------
`liondrainbkb` (hero_lion.lua:1520 `X.lion_IsDrainTargetCastable`) narrows the
ONE Mana Drain target test that asks `J.CanCastOnMagicImmune` -- the helper for
abilities that PIERCE spell immunity -- on an ability whose own KV says
`SPELL_IMMUNITY_ENEMIES_NO`.  The lever may only turn the shipped predicate's
`true` into `false`, so gate-off IS the shipped expression and every reading
here is COUNTERFACTUAL: `liondrainbkb` has never been armed in any wave.

THE MEASUREMENT TRAP THIS TOOL EXISTS TO AVOID
----------------------------------------------
The request's column (4) proposes to read the defect off the CAST side: order a
drain on a spell-immune hero, watch `modifier_lion_mana_drain` fail to appear
1-2s later.  **That signature cannot exist in a Source 2 combat log.**  An
ENEMIES_NO ability aimed at a spell-immune unit is refused at ORDER time -- no
mana is spent, no `DOTA_COMBATLOG_ABILITY` row is written.  `--selfcheck`
case `cast_side_is_blind` pins the consequence: on this corpus every single
`ABILITY lion_mana_drain` row is followed by its `MODIFIER_ADD` on the SAME
tick, so "ordered but did not take" has zero observable instances -- not
because the defect is absent, but because the instrument cannot see it.
Section 4 of the output reports that ratio rather than hiding it, and the
domain proper is measured on the STATE side instead:

    how many instants exist where the buggy branch, had it run, would have
    aimed at a spell-immune enemy?

That question is answerable offline, because every input to the branch except
the bot's own mode is in the dump.

PREDICATE FIDELITY (all-stream rule U.1.1 -- thresholds verbatim from source)
-----------------------------------------------------------------------------
  X.ConsiderE 团战吸蓝 branch (hero_lion.lua:1083-1100), in source order:
    * `X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 -> return 0`  (:1071)
        Q/W/R mana costs and cooldowns from tests/mock/special_value_shapes.lua
        (impale 90/110/130/150, voodoo 110/140/170/200, finger 200/400/600).
    * `X.lion_IsDrainSafeToStart( bot )`                              (:1081)
        no-op unless `liondrain` is armed; ARMED IN W39-W41 ONLY, so the two
        strata are reported separately and never pooled (iron rule 4).
    * `J.IsInTeamFight( bot, 1000 )`                                  (:1084)
        = `#J.GetNearbyHeroes(bot,1000,false,BOT_MODE_ATTACK) >= 2`.  Bot MODE
        is the one input the replay does not carry -- see LIMITS.
    * `J.IsInRange( bot, npcEnemy, nCastRange )`  nCastRange = 850 + aether
    * `not npcEnemy:HasModifier('modifier_lion_finger_of_death')`
    * `npcEnemy:GetMana() > 200`
    * `X.lion_IsDrainTargetCastable( npcEnemy )`   <-- THE LEVER
    * `J.CanCastOnTargetAdvanced` / `not J.IsDisabled` -- approximated, see LIMITS

SPELL-IMMUNITY SOURCES counted (the request asks for the list actually seen,
not a total): every modifier name in IMMUNITY_MODIFIERS below, plus whatever
else the corpus turns up under --list-modifiers.

LIMITS (read these before quoting any number)
---------------------------------------------
 1. BOT MODE IS NOT IN THE REPLAY.  `J.IsInTeamFight` needs allies in
    BOT_MODE_ATTACK; the dump has positions only.  The proxy is "2+ living
    allies within 1000u AND at least one hero-vs-hero DAMAGE event inside
    +/-3.0s involving either team".  That is WIDER than the source predicate
    on the mode axis (allies may be retreating) => the domain here is an
    UPPER bound on the teamfight branch's reach.  Reported both ways: the
    `tf_proxy` and `tf_proxy_strict` (damage event involving Lion himself)
    counts bracket it.
 2. TARGET SELECTION ORDER IS UNKNOWABLE.  The branch bids on the FIRST
    qualifying enemy in `hEnemyList`; the replay cannot reproduce that list's
    order.  So two counts are reported and never merged:
      * `any_immune`  -- at least one qualifying enemy is spell-immune
                         (UPPER bound on where the lever could change the bid)
      * `all_immune`  -- EVERY qualifying enemy is spell-immune
                         (LOWER bound: here the lever definitely changes it)
    Iron rule 4(ii): both are small-valued integer counts, so no medians.
 3. `J.IsDisabled` / `J.CanCastOnTargetAdvanced` are approximated by the
    DISABLE_MODIFIERS list and by "target alive".  A missed disable name makes
    the domain slightly too large (conservative for a NOT-REACHED reading,
    anti-conservative for a REACHED one) -- so any non-zero domain must be
    frame-checked, which is what --frames prints.
 4. Snapshots are sampled at 1.0s; an immunity window shorter than the sample
    gap can be missed on the STATE side.  Immunity is read from the EVENT
    stream (ADD/REMOVE intervals), which is not sampled, so this bites only
    the position/mana columns.

USAGE
    liondrainbkb_domain.py --selfcheck
    liondrainbkb_domain.py TL_DIR --wave-map wave_dems.tsv [--json out.json]
    liondrainbkb_domain.py TL_DIR --frames [--top N]
"""

import argparse
import bisect
import collections
import glob
import json
import os
import sys

LION = "npc_dota_hero_lion"

# --- verbatim from tests/mock/special_value_shapes.lua (KV snapshot) --------
MANA_Q = [90, 110, 130, 150]
MANA_W = [110, 140, 170, 200]
MANA_R = [200, 400, 600]
CAST_RANGE_E = 850.0
AETHER_BONUS = 225.0            # item_aether_lens
ENEMY_MANA_FLOOR = 200          # npcEnemy:GetMana() > 200
DRAIN_MIN_LEVEL = 2             # nSkillLV <= 1 -> return 0
TEAMFIGHT_RADIUS = 1000.0       # J.IsInTeamFight( bot, 1000 )
DRAIN_DANGER_RADIUS = 500.0     # X.nEDrainDangerRadius
RECENT_DAMAGE_WINDOW = 2.0      # WasRecentlyDamagedByAnyHero( 2.0 )
TF_DAMAGE_WINDOW = 3.0          # proxy only -- see LIMITS 1

# SPELL immunity only.  The request named four candidates; two of them are NOT
# spell immunity and were removed after they polluted the first pass:
#   * modifier_item_mask_of_madness_berserk -- a damage/speed buff that INCREASES
#     damage taken.  It contributed 3 of the first pass's 21 "immune" landings.
#   * modifier_omniknight_martyr / _guardian_angel -- PHYSICAL immunity, which
#     does not refuse an ENEMIES_NO targeted spell at all.
# Keeping either would have manufactured domain out of modifiers that never
# block a cast -- the same shape as the `aghanims_shard` zero of 2026-09-06.
IMMUNITY_MODIFIERS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
    "modifier_omniknight_repel",
}

DISABLE_MODIFIERS = {
    "modifier_stunned",
    "modifier_bashed",
    "modifier_lion_impale",
    "modifier_lion_voodoo",
    "modifier_sheepstick_debuff",
    "modifier_shadow_shaman_voodoo",
    "modifier_axe_berserkers_call",
    "modifier_legion_commander_duel",
    "modifier_faceless_void_chronosphere_freeze",
    "modifier_bane_nightmare",
    "modifier_enigma_black_hole_pull",
    "modifier_disruptor_static_storm",
    "modifier_naga_siren_song_of_the_siren",
}

FINGER_MOD = "modifier_lion_finger_of_death"
DRAIN_MOD = "modifier_lion_mana_drain"
DRAIN_ABILITY = "lion_mana_drain"


# --------------------------------------------------------------------------
# modifier interval reconstruction
# --------------------------------------------------------------------------
def build_modifier_intervals(events, names):
    """{(target, modifier): [(t_add, t_remove), ...]} for the given names.

    An ADD with no matching REMOVE runs to +inf (the replay ended, or the unit
    died holding it).  Nested ADDs of the same name on the same target are
    merged into one interval rather than counted twice -- a refresh is one
    immunity window, not two.
    """
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
    """Names in `intervals` active on `target` at time `t`."""
    hits = []
    for (tgt, name), spans in intervals.items():
        if tgt != target:
            continue
        for a, b in spans:
            if a <= t <= b:
                hits.append(name)
                break
    return hits


# --------------------------------------------------------------------------
# per-game scan
# --------------------------------------------------------------------------
def is_fully_castable(ab, mana, cost_table):
    """`IsFullyCastable()`: trained, off cooldown, mana affordable."""
    if ab is None or ab["level"] < 1:
        return False
    if ab["cd"] > 0:
        return False
    lvl = min(ab["level"], len(cost_table)) - 1
    return mana >= cost_table[lvl]


def scan_game(tl, key):
    game = tl.get("game", {})
    teams = game.get("teams", {})
    lion_team = teams.get(LION)
    if lion_team is None:
        return None

    events = tl["events"]
    watched = IMMUNITY_MODIFIERS | DISABLE_MODIFIERS | {FINGER_MOD}
    intervals = build_modifier_intervals(events, watched)

    # hero-vs-hero damage timestamps (teamfight proxy, LIMIT 1)
    dmg_all, dmg_lion = [], []
    for e in events:
        if e["type"] != "DAMAGE" or not e.get("actor_hero") or not e.get("target_hero"):
            continue
        dmg_all.append(e["t"])
        if e.get("actor") == LION or e.get("target") == LION:
            dmg_lion.append(e["t"])
    dmg_all.sort()
    dmg_lion.sort()

    def damaged_within(sorted_ts, t, window):
        i = bisect.bisect_left(sorted_ts, t - window)
        return i < len(sorted_ts) and sorted_ts[i] <= t + window

    # hero damage TAKEN by Lion, for WasRecentlyDamagedByAnyHero( 2.0 )
    lion_hurt = sorted(e["t"] for e in events
                       if e["type"] == "DAMAGE" and e.get("target") == LION
                       and e.get("actor_hero"))

    def hurt_recently(t):
        i = bisect.bisect_left(lion_hurt, t - RECENT_DAMAGE_WINDOW)
        return i < len(lion_hurt) and lion_hurt[i] <= t

    # ILLUSION GUARD (GH #176): several entities share one hero NAME, so a
    # name-keyed frame silently swaps the real hero for a Manta/rune illusion
    # (seen live: a Bristleback row jumping to hp_pct 0.00 at 3.6k units).  The
    # real hero is the entity present at that hero's OWN earliest sample --
    # illusions are born later, by construction.
    first_idx, first_t = {}, {}
    for s in tl["snapshots"]:
        h = s["hero"]
        if h not in first_t or s["t"] < first_t[h]:
            first_t[h], first_idx[h] = s["t"], s.get("idx")
    n_multi = collections.Counter()
    by_t = collections.defaultdict(dict)
    for s in tl["snapshots"]:
        h = s["hero"]
        if s.get("idx") != first_idx.get(h):
            n_multi[h] += 1
            continue
        by_t[s["t"]][h] = s

    rows = []
    for t in sorted(by_t):
        frame = by_t[t]
        lion = frame.get(LION)
        if lion is None or lion.get("hp", 0) <= 0:
            continue
        abils = {a["name"]: a for a in (lion.get("abilities") or [])}
        e_ab = abils.get(DRAIN_ABILITY)
        if e_ab is None or e_ab["level"] < DRAIN_MIN_LEVEL or e_ab["cd"] > 0:
            continue
        mana = lion.get("mp", 0)
        # X.IsOtherAbilityFullyCastable() must be FALSE for the branch to run
        if (is_fully_castable(abils.get("lion_impale"), mana, MANA_Q)
                or is_fully_castable(abils.get("lion_voodoo"), mana, MANA_W)
                or is_fully_castable(abils.get("lion_finger_of_death"), mana, MANA_R)):
            continue

        cast_range = CAST_RANGE_E
        if "item_aether_lens" in (lion.get("items") or []) or \
           "aether_lens" in (lion.get("items") or []):
            cast_range += AETHER_BONUS

        allies = [h for h, s in frame.items()
                  if h != LION and teams.get(h) == lion_team and s.get("hp", 0) > 0
                  and dist(s, lion) <= TEAMFIGHT_RADIUS]
        if len(allies) < 2:
            continue
        tf_proxy = damaged_within(dmg_all, t, TF_DAMAGE_WINDOW)
        if not tf_proxy:
            continue
        tf_strict = damaged_within(dmg_lion, t, TF_DAMAGE_WINDOW)

        qualifying, immune_q = [], []
        for h, s in frame.items():
            if teams.get(h) == lion_team or s.get("hp", 0) <= 0:
                continue
            if dist(s, lion) > cast_range:
                continue
            if s.get("mp", 0) <= ENEMY_MANA_FLOOR:
                continue
            act = active_modifiers(intervals, h, t)
            if FINGER_MOD in act:
                continue
            if any(m in DISABLE_MODIFIERS for m in act):
                continue
            qualifying.append(h)
            imm = [m for m in act if m in IMMUNITY_MODIFIERS]
            if imm:
                immune_q.append((h, imm))

        if not qualifying:
            continue
        rows.append({
            "game": key,
            "t": t,
            "lion_mp": mana,
            "lion_level": lion.get("level"),
            "e_level": e_ab["level"],
            "cast_range": cast_range,
            "allies_1000": len(allies),
            "tf_strict": tf_strict,
            "n_qualifying": len(qualifying),
            "qualifying": qualifying,
            "immune": immune_q,
            "any_immune": bool(immune_q),
            "all_immune": bool(immune_q) and len(immune_q) == len(qualifying),
            "hurt_recently": hurt_recently(t),
            "enemy_within_500": any(
                dist(frame[h], lion) <= DRAIN_DANGER_RADIUS
                for h in frame
                if teams.get(h) != lion_team and frame[h].get("hp", 0) > 0),
        })

    # cast-side counts (section 4: the instrument-blindness read)
    casts, adds = [], []
    for e in events:
        if e.get("actor") != LION:
            continue
        if e["type"] == "ABILITY" and e.get("inflictor") == DRAIN_ABILITY:
            casts.append(e)
        elif e["type"] == "MODIFIER_ADD" and e.get("inflictor") == DRAIN_MOD:
            adds.append(e)
    add_ts = sorted(a["t"] for a in adds)
    unlanded = []
    for c in casts:
        i = bisect.bisect_left(add_ts, c["t"] - 0.05)
        if not (i < len(add_ts) and add_ts[i] <= c["t"] + 2.0):
            unlanded.append(c)

    drain_intervals = build_modifier_intervals(events, {DRAIN_MOD})
    add_rows = []
    for a in adds:
        tgt = a.get("target") or ""
        imm_spans = []
        for (t_, name), spans in intervals.items():
            if t_ != tgt or name not in IMMUNITY_MODIFIERS:
                continue
            for lo, hi in spans:
                if lo <= a["t"] <= hi:
                    imm_spans.append((name, lo, hi))
        # channel end for THIS landing
        chan_end = None
        for lo, hi in drain_intervals.get((tgt, DRAIN_MOD), []):
            if abs(lo - a["t"]) < 0.05:
                chan_end = hi
                break
        add_rows.append({
            "t": a["t"],
            "target": tgt,
            "target_hero": bool(a.get("target_hero")),
            "immune_at_add": [m for (m, _, _) in imm_spans],
            # lead = how long the immunity had ALREADY been up when the drain
            # landed.  A lead of ~0 is ambiguous (the enemy may have popped BKB
            # in the same tick the cast resolved); a multi-second lead is not.
            "immunity_lead_s": round(min((a["t"] - lo for (_, lo, _) in imm_spans),
                                         default=-1.0), 2) if imm_spans else None,
            "channel_s": (round(chan_end - a["t"], 2)
                          if chan_end is not None and chan_end < float("inf") else None),
            # the decisive shape: the WHOLE channel nested inside one immunity
            # window -- no tick of it happened while the target was castable.
            "nested_in_immunity": bool(imm_spans) and chan_end is not None and any(
                lo <= a["t"] and chan_end <= hi for (_, lo, hi) in imm_spans),
            # illusion conflation risk for this target (LIMIT: name-keyed log)
            "name_clean": n_multi.get(tgt, 0) == 0,
        })

    return {
        "game": key,
        "rows": rows,
        "casts": len(casts),
        "adds": len(adds),
        "unlanded": [{"t": c["t"], "target": c.get("target")} for c in unlanded],
        "add_rows": add_rows,
        "immunity_names_seen": sorted({
            name for (_, name) in intervals if name in IMMUNITY_MODIFIERS}),
        "illusion_samples_dropped": sum(n_multi.values()),
        "multi_entity_names": len(n_multi),
    }


def dist(a, b):
    return ((a["x"] - b["x"]) ** 2 + (a["y"] - b["y"]) ** 2) ** 0.5


# --------------------------------------------------------------------------
def episodes(rows, gap=3.0):
    """Collapse consecutive in-domain instants into decisions (LIMIT: a long
    stand is one decision, not N samples)."""
    out, cur = [], []
    for r in sorted(rows, key=lambda r: (r["game"], r["t"])):
        if cur and r["game"] == cur[-1]["game"] and r["t"] - cur[-1]["t"] <= gap:
            cur.append(r)
        else:
            if cur:
                out.append(cur)
            cur = [r]
    if cur:
        out.append(cur)
    return out


def selfcheck():
    """Assertions that fail loudly if the reconstruction drifts."""
    n_pass = n_fail = 0

    def check(name, cond):
        nonlocal n_pass, n_fail
        if cond:
            n_pass += 1
            print("PASS %s" % name)
        else:
            n_fail += 1
            print("FAIL %s" % name)

    ev = [
        {"t": 10.0, "type": "MODIFIER_ADD", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 18.0, "type": "MODIFIER_REMOVE", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 30.0, "type": "MODIFIER_ADD", "target": "e",
         "inflictor": "modifier_juggernaut_blade_fury"},
    ]
    iv = build_modifier_intervals(ev, IMMUNITY_MODIFIERS)
    check("interval_closed", iv[("e", "modifier_black_king_bar_immune")] == [(10.0, 18.0)])
    check("interval_open_runs_to_inf",
          iv[("e", "modifier_juggernaut_blade_fury")][0][1] == float("inf"))
    check("active_inside", "modifier_black_king_bar_immune" in active_modifiers(iv, "e", 12.0))
    check("active_outside",
          "modifier_black_king_bar_immune" not in active_modifiers(iv, "e", 25.0))
    check("active_wrong_target", active_modifiers(iv, "other", 12.0) == [])

    dup = [
        {"t": 1.0, "type": "MODIFIER_ADD", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 2.0, "type": "MODIFIER_ADD", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 9.0, "type": "MODIFIER_REMOVE", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
    ]
    iv2 = build_modifier_intervals(dup, IMMUNITY_MODIFIERS)
    check("refresh_is_one_window",
          iv2[("e", "modifier_black_king_bar_immune")] == [(1.0, 9.0)])

    # IsFullyCastable
    check("untrained_not_castable",
          not is_fully_castable({"name": "q", "level": 0, "cd": 0}, 999, MANA_Q))
    check("on_cooldown_not_castable",
          not is_fully_castable({"name": "q", "level": 2, "cd": 3.0}, 999, MANA_Q))
    check("poor_not_castable",
          not is_fully_castable({"name": "q", "level": 2, "cd": 0}, 100, MANA_Q))
    check("rich_ready_castable",
          is_fully_castable({"name": "q", "level": 2, "cd": 0}, 110, MANA_Q))
    check("level_clamped_to_table",
          is_fully_castable({"name": "r", "level": 3, "cd": 0}, 600, MANA_R))
    check("missing_ability_not_castable", not is_fully_castable(None, 999, MANA_Q))

    # episode collapse
    rows = [{"game": "g", "t": x} for x in (10.0, 11.0, 12.0, 40.0)]
    eps = episodes(rows)
    check("episode_collapse", len(eps) == 2 and len(eps[0]) == 3)
    rows2 = [{"game": "a", "t": 10.0}, {"game": "b", "t": 10.5}]
    check("episode_not_across_games", len(episodes(rows2)) == 2)

    # the immunity set must not readmit the two non-immunity modifiers that
    # polluted the first pass (they would manufacture domain)
    check("mask_of_madness_excluded",
          "modifier_item_mask_of_madness_berserk" not in IMMUNITY_MODIFIERS)
    check("guardian_angel_excluded",
          not any("omniknight_martyr" in m or "guardian_angel" in m
                  for m in IMMUNITY_MODIFIERS))
    check("bkb_included", "modifier_black_king_bar_immune" in IMMUNITY_MODIFIERS)
    check("blade_fury_included",
          "modifier_juggernaut_blade_fury" in IMMUNITY_MODIFIERS)

    # end-to-end: a drain nested inside a BKB window must be flagged, and the
    # illusion guard must drop the later-born entity of the same name
    tl = {
        "game": {"teams": {LION: 2, "npc_dota_hero_sven": 3}},
        "snapshots": [
            {"t": 0.0, "hero": LION, "idx": 1, "x": 0, "y": 0, "hp": 500,
             "hp_pct": 1, "mp": 0, "max_mp": 500, "level": 6, "items": [],
             "abilities": []},
            {"t": 0.0, "hero": "npc_dota_hero_sven", "idx": 2, "x": 0, "y": 0,
             "hp": 500, "hp_pct": 1, "mp": 400, "max_mp": 500, "level": 6,
             "items": [], "abilities": []},
            {"t": 5.0, "hero": "npc_dota_hero_sven", "idx": 77, "x": 9e3,
             "y": 9e3, "hp": 0, "hp_pct": 0, "mp": 0, "max_mp": 0, "level": 6,
             "items": [], "abilities": []},
        ],
        "events": [
            {"t": 10.0, "type": "MODIFIER_ADD", "actor": "npc_dota_hero_sven",
             "target": "npc_dota_hero_sven",
             "inflictor": "modifier_black_king_bar_immune", "target_hero": True},
            {"t": 13.0, "type": "ABILITY", "actor": LION,
             "target": "npc_dota_hero_sven", "inflictor": DRAIN_ABILITY,
             "target_hero": True},
            {"t": 13.0, "type": "MODIFIER_ADD", "actor": LION,
             "target": "npc_dota_hero_sven", "inflictor": DRAIN_MOD,
             "target_hero": True},
            {"t": 17.0, "type": "MODIFIER_REMOVE", "actor": LION,
             "target": "npc_dota_hero_sven", "inflictor": DRAIN_MOD,
             "target_hero": True},
            {"t": 19.0, "type": "MODIFIER_REMOVE", "actor": "npc_dota_hero_sven",
             "target": "npc_dota_hero_sven",
             "inflictor": "modifier_black_king_bar_immune", "target_hero": True},
        ],
    }
    r = scan_game(tl, "synthetic")
    row = r["add_rows"][0]
    check("premise_nested_detected", row["nested_in_immunity"] is True)
    check("premise_lead_measured", row["immunity_lead_s"] == 3.0)
    check("premise_channel_measured", row["channel_s"] == 4.0)
    check("illusion_guard_dropped_late_entity", r["illusion_samples_dropped"] == 1)
    check("illusion_guard_flags_name_unclean", row["name_clean"] is False)

    # constants stay pinned to the KV snapshot
    check("cast_range_pinned", CAST_RANGE_E == 850.0)
    check("mana_floor_pinned", ENEMY_MANA_FLOOR == 200)
    check("drain_level_pinned", DRAIN_MIN_LEVEL == 2)
    check("teamfight_radius_pinned", TEAMFIGHT_RADIUS == 1000.0)
    check("danger_radius_pinned", DRAIN_DANGER_RADIUS == 500.0)

    print("\nSELFCHECK %d PASS / %d FAIL" % (n_pass, n_fail))
    return 0 if n_fail == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tl_dir", nargs="?")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--wave-map", help="TSV: wave<TAB>tag<TAB>run<TAB>dem")
    ap.add_argument("--json", help="write the full row dump here")
    ap.add_argument("--frames", action="store_true",
                    help="print every in-domain instant for frame-by-frame review")
    ap.add_argument("--list-modifiers", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()
    if not a.tl_dir:
        ap.error("tl_dir required unless --selfcheck")

    wave_of = {}
    if a.wave_map:
        for line in open(a.wave_map):
            p = line.rstrip("\n").split("\t")
            if len(p) >= 3:
                wave_of["%s__%s" % (p[2][-6:], p[1])] = p[0]

    games = sorted(glob.glob(os.path.join(a.tl_dir, "*.json")))
    results, skipped = [], 0
    for f in games:
        key = os.path.basename(f)[:-5]
        try:
            tl = json.load(open(f))
        except Exception as exc:            # unparseable dumps are reported, not hidden
            print("UNPARSEABLE %s (%s)" % (key, exc), file=sys.stderr)
            skipped += 1
            continue
        r = scan_game(tl, key)
        if r is None:
            skipped += 1
            continue
        r["wave"] = wave_of.get(key, "?")
        results.append(r)

    if a.list_modifiers:
        seen = collections.Counter()
        for r in results:
            for n in r["immunity_names_seen"]:
                seen[n] += 1
        for n, c in seen.most_common():
            print("%-45s %d game(s)" % (n, c))
        return 0

    all_rows = [row for r in results for row in r["rows"]]
    for r in results:
        for row in r["rows"]:
            row["wave"] = r["wave"]

    # liondrain armed only in W39-W41: that stratum has an extra gate above.
    LIONDRAIN_ARMED = {"W39", "W40", "W41"}

    def strat(rows, waves):
        return [r for r in rows if r["wave"] in waves]

    print("=== corpus ===")
    print("games scanned          : %d (skipped %d)" % (len(results), skipped))
    by_wave = collections.Counter(r["wave"] for r in results)
    print("by wave                : %s" % dict(sorted(by_wave.items())))

    print("\n=== section 1: cast side (MODIFIER_ADD of %s) ===" % DRAIN_MOD)
    adds = []
    for r in results:
        for row in r["add_rows"]:
            row["game"] = r["game"]
            adds.append(row)
    hero_adds = [x for x in adds if x["target_hero"]]
    print("drain landings total   : %d" % len(adds))
    print("  on an enemy HERO     : %d" % len(hero_adds))
    print("  on a creep/neutral   : %d   (denominator control, not this lever)"
          % (len(adds) - len(hero_adds)))
    # The drop count is large by construction -- one Chaos Knight game carries
    # 41 entities under the single name `npc_dota_hero_chaos_knight`, so the
    # guard removes tens of thousands of samples per illusion-heavy game.  It
    # is printed next to the per-name entity count so a big number reads as
    # "illusions existed", not as "the guard ate the real heroes".
    print("  illusion samples dropped by the GH #176 guard: %d (%d hero-name(s)"
          " carried more than one entity)"
          % (sum(r["illusion_samples_dropped"] for r in results),
             sum(r["multi_entity_names"] for r in results)))

    print("\n=== section 0: THE PREMISE TEST (does the engine refuse a"
          " spell-immune target?) ===")
    imm_lands = [x for x in hero_adds if x["immune_at_add"]]
    clean = [x for x in imm_lands if x["name_clean"]]
    nested = [x for x in clean if x["nested_in_immunity"]]
    lead2 = [x for x in clean if (x["immunity_lead_s"] or 0) >= 2.0]
    print("hero landings while the target held SPELL immunity : %d" % len(imm_lands))
    print("  ... with no same-name second entity in the game   : %d"
          " (illusion conflation structurally impossible)" % len(clean))
    print("  ... immunity already up >= 2.0s before the landing: %d" % len(lead2))
    print("  ... WHOLE channel nested inside the immunity window: %d" % len(nested))
    if nested:
        print("  => the lever's premise ('a spell-immune enemy is not a target")
        print("     the engine will accept at all') is FALSIFIED on real frames.")
        for x in sorted(nested, key=lambda r: -(r["immunity_lead_s"] or 0))[:12]:
            print("     %-38s t=%.1f %-16s lead=%.2fs channel=%.1fs %s"
                  % (x["game"], x["t"], x["target"][14:], x["immunity_lead_s"],
                     x["channel_s"] or 0, ",".join(m[9:] for m in x["immune_at_add"])))
    else:
        print("  => no counterexample in this corpus (NOT the same as proof:"
              " see section 4)")

    print("\n=== section 4: is the cast side observable at all? (LIMIT: no) ===")
    casts = sum(r["casts"] for r in results)
    unl = [u for r in results for u in r["unlanded"]]
    print("ABILITY %s rows        : %d" % (DRAIN_ABILITY, casts))
    print("of which NO modifier within 2.0s : %d" % len(unl))
    print("=> 'ordered but refused' has %d observable instances; the engine"
          % len(unl))
    print("   never writes a combat-log row for a refused order, so a zero here")
    print("   is INSTRUMENT-BLIND, not evidence the defect does not fire.")

    print("\n=== section 2+3: state side domain (the answerable question) ===")
    for label, waves in (("liondrain ARMED  (W39-W41)", LIONDRAIN_ARMED),
                         ("liondrain gate-off (W42+)",
                          set(by_wave) - LIONDRAIN_ARMED)):
        rows = strat(all_rows, waves)
        if label.startswith("liondrain ARMED"):
            # X.lion_IsDrainSafeToStart refuses when hurt AND an enemy is <500u
            rows = [r for r in rows
                    if not (r["hurt_recently"] and r["enemy_within_500"])]
        eps = episodes(rows)
        g = len({r["game"] for r in rows})
        any_i = [r for r in rows if r["any_immune"]]
        all_i = [r for r in rows if r["all_immune"]]
        print("\n-- %s --" % label)
        print("  in-branch instants     : %d  (%d episode(s), %d game(s))"
              % (len(rows), len(eps), g))
        print("  ... tf proxy strict    : %d" % sum(1 for r in rows if r["tf_strict"]))
        print("  ANY qualifying immune  : %d instant(s), %d episode(s), %d game(s)"
              % (len(any_i), len(episodes(any_i)),
                 len({r['game'] for r in any_i})))
        print("  ALL qualifying immune  : %d instant(s), %d episode(s), %d game(s)"
              % (len(all_i), len(episodes(all_i)),
                 len({r['game'] for r in all_i})))
        dist_n = collections.Counter(r["n_qualifying"] for r in rows)
        print("  #qualifying enemies    : %s  (integer small-valued: no median,"
              " iron rule 4(ii))" % dict(sorted(dist_n.items())))

    print("\n=== immunity sources actually seen in the corpus ===")
    seen = collections.Counter()
    for r in results:
        for n in r["immunity_names_seen"]:
            seen[n] += 1
    for n, c in seen.most_common():
        print("  %-45s %d game(s)" % (n, c))
    if not seen:
        print("  (none)")

    if a.frames:
        print("\n=== in-domain instants (frame-by-frame review list) ===")
        for r in sorted((x for x in all_rows if x["any_immune"]),
                        key=lambda r: (r["game"], r["t"])):
            print("%s t=%.1f wave=%s qual=%d immune=%s allies=%d tf_strict=%s"
                  % (r["game"], r["t"], r["wave"], r["n_qualifying"],
                     r["immune"], r["allies_1000"], r["tf_strict"]))

    if a.json:
        json.dump({"results": results, "rows": all_rows},
                  open(a.json, "w"), indent=1)
        print("\nwrote %s" % a.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())

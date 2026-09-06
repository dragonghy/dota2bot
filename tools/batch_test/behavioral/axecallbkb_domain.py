#!/usr/bin/env python3
"""`axecallbkb` condition-(a) domain census over an archived Axe corpus.

WHAT THIS ANSWERS (queue row hero-30; director ruling FROZEN-HOLD 2026-09-05,
which explicitly keeps BUYING the evidence: "冻结冻的是入集,不是取证")
--------------------------------------------------------------------------
⚠️ NAMES, 2026-09-06 (GH #577): this census READ the tree while both branches
still shared one id and one helper `X.IsCallPierceOn`.  Its own readings are
what made the hero stream SPLIT them the same day -- branch (i) is now gated by
`axecallbkb_i` (`X.IsCallPierceInterruptOn`) and branch (ii) by `axecallbkb_ii`
(`X.IsCallPierceInitiateOn`), and the retired `axecallbkb` names no gate in
`bots/` any more.  Nothing measured below changes: the census keys off the two
BRANCHES (which are untouched, predicate for predicate), never off the id, and
it always reported them separately.  Re-running it is still valid; quoting it
under the old single id is not.

`axecallbkb` (hero_axe.lua `X.IsCallPierceOn`, gated, never armed) removed
TWO spell-immunity vetoes from `X.ConsiderQ`, because axe_berserkers_call is
`bkbpierce: "Yes"` -- it is not stopped by spell immunity in the game:

  (i) INTERRUPT branch (hero_axe.lua:583-590)
        for npcEnemy in J.GetAroundEnemyHeroList( nRadius - 50 ):
            if npcEnemy:IsChanneling()
               and ( not npcEnemy:IsMagicImmune() or X.IsCallPierceOn() )
      -> shipped declines to break a channel it can in fact break.

 (ii) INITIATION branch (hero_axe.lua:595-606)
        if J.IsGoingOnSomeone( bot )
           and J.IsValidHero( botTarget )
           and J.IsInRange( botTarget, bot, nRadius - 90 )
           and ( J.CanCastOnNonMagicImmune( botTarget ) or ( pierce and
                 J.CanCastOnMagicImmune( botTarget ) ) )
           and not J.IsDisabled( botTarget )
      -> shipped declines the Call when its CURRENT target is spell-immune,
         and because the Call is a NO-TARGET AoE taunt centred on Axe, that
         single enemy's property also throws away every OTHER enemy standing
         in the same `nRadius` ring.  That ring count is the (ii)-only value
         column the queue row refuses to let us drop.

THE TWO BRANCHES ARE REPORTED SEPARATELY AND NEVER POOLED.  That is the queue
row's own pre-registration ("两个分支分开报,不许并池") and also the charter's
attribution rule 4a: one aggregate difference may not be booked to two ids --
here, to two branches sharing one id.  The same pre-registration says a
negative read may not be attributed to either branch; the next rung is to
SPLIT the id.

RADII, WRITTEN FROM THE CODE AND FROM THE REPO'S KV SNAPSHOT
-------------------------------------------------------------
`nRadius = abilityQ:GetSpecialValueInt('radius')` = 315, and the engine folds
`special_bonus_unique_axe_2` (+85) into that same read for a caster who
trained it (hero_axe.lua:566-578, GH #228).  So nRadius is 315 or 400, and
TALENT TRAINING IS NOT IN THE DUMP (snapshots carry the four real abilities
only -- no `special_bonus_*` rows).  Every count is therefore reported at
BOTH radii and never averaged:

    branch (i)  ring = nRadius - 50  ->  265 (untrained) / 350 (trained)
    branch (ii) ring = nRadius - 90  ->  225 (untrained) / 310 (trained)
    (ii) value column ring = nRadius ->  315 (untrained) / 400 (trained)

Mana 90/100/110/120 and cooldown 18/16/14/12 are verbatim from
tests/mock/special_value_shapes.lua (which is the game KV snapshot); the
cooldown is not needed as a model because snapshots carry the live `cd`.

CHANNELING IS RECONSTRUCTED, AND THE LIST IS THE ONE ACTUALLY SEEN
-------------------------------------------------------------------
`IsChanneling()` is not a dumped field.  It is rebuilt from modifier
intervals, keyed by the CHANNELLING entity, which is not always the modifier's
target: MODIFIER_ADD/REMOVE carry `actor` (the caster) as well as `target`, so
a channel whose marker lands on the victim (Dismember, Shackles, Mana Drain)
is attributed to `actor`, and a channel whose marker sits on the caster
(teleport, Freezing Field) to itself.  The set below is the set that actually
occurs in this corpus (censused, not assumed) -- see CHANNEL_SELF /
CHANNEL_BY_ACTOR.  A channelled ability absent from the corpus is absent from
the list; adding an unseen name could only inflate the domain.

LIMITS (read these before quoting any number)
---------------------------------------------
 1. `J.IsGoingOnSomeone( bot )` IS A BOT MODE (jmz_func.lua:1540:
    ROAM/TEAM_ROAM/GANK/ATTACK/DEFEND_ALLY) and `botTarget` is
    J.GetProperTarget.  NEITHER IS OBSERVABLE OFFLINE.  Branch (ii) is
    therefore reported as an UPPER BOUND with those two terms dropped, plus a
    narrower "commitment proxy" stratum (Axe and that enemy exchanged hero
    damage within 2.0s).  The strict predicate is INSTRUMENT-BLIND; the
    immune FRACTION is still readable, because the dropped terms do not
    depend on the target's immunity.
 2. FOG IS NOT IN THE DUMP.  `J.GetAroundEnemyHeroList` is GetNearbyHeroes,
    which the engine filters by visibility, and `CanBeSeen()` appears again
    inside J.CanCastOnNonMagicImmune.  The replay is omniscient, so every
    count here is an upper bound on the branch's reach.
 3. MODIFIER STATE is reconstructed from ADD/REMOVE intervals, which are not
    sampled, so windows shorter than the 1 Hz snapshot period are still seen.
    A modifier the dumper does not emit would make the domain too small on
    the immunity side and too large on the disable side.
 4. ILLUSIONS SHARE THE HERO NAME (GH #176).  Guarded by birth time: the real
    hero is the entity present at that hero name's OWN earliest sample.  The
    discarded sample count is reported.  Event-side rows cannot be split by
    entity at all, so channel/immunity intervals are hero-name-keyed.
 5. SPELL IMMUNITY means `IsMagicImmune()`.  Ghost Shroud
    (`modifier_necrolyte_ghost_shroud_active`) and ethereal
    (`modifier_ghost_state`) are NOT spell immunity and are deliberately
    excluded -- the 2026-09-06 `liondrainbkb` pass manufactured 3 of its
    first 21 "immune" landings out of exactly this kind of name.

USAGE
    axecallbkb_domain.py --selfcheck
    axecallbkb_domain.py TL_DIR [--json out.json]
    axecallbkb_domain.py TL_DIR --frames [--top N]
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
CALL = "axe_berserkers_call"

# --- verbatim from tests/mock/special_value_shapes.lua (KV snapshot) --------
CALL_MANA = [90, 100, 110, 120]        # AbilityManaCost, by rank-1 index
CALL_RADIUS_BASE = 315.0               # radius / value
CALL_RADIUS_TALENT = 400.0             # +85 from special_bonus_unique_axe_2
INTERRUPT_MARGIN = 50.0                # nRadius - 50
INITIATE_MARGIN = 90.0                 # nRadius - 90
COMMIT_WINDOW = 2.0                    # commitment proxy, LIMIT 1
EPISODE_GAP = 3.0                      # consecutive-instant grouping

# --- spell immunity: IsMagicImmune() only (LIMIT 5) -------------------------
IMMUNITY_MODIFIERS = {
    "modifier_black_king_bar_immune",
    "modifier_juggernaut_blade_fury",
    "modifier_life_stealer_rage",
    "modifier_omniknight_repel",
}

# --- J.IsDisabled( enemy ) = IsRooted/IsStunned/IsHexed/IsNightmared/IsTaunted
DISABLE_MODIFIERS = {
    # stun
    "modifier_stunned",
    "modifier_bashed",
    "modifier_lion_impale",
    "modifier_jakiro_ice_path_stun",
    "modifier_earthshaker_fissure_stun",
    "modifier_frogmen_arm_of_the_deep_stun",
    # hex
    "modifier_lion_voodoo",
    "modifier_shadow_shaman_voodoo",
    "modifier_sheepstick_debuff",
    # root
    "modifier_medusa_gorgon_grasp_root",
    "modifier_spawnlord_master_freeze_root",
    "modifier_dark_troll_warlord_ensnare",
    # taunt (J.IsTaunted, jmz_func.lua:1417)
    "modifier_axe_berserkers_call",
    "modifier_legion_commander_duel",
    "modifier_winter_wyvern_winters_curse",
    "modifier_winter_wyvern_winters_curse_aura",
    # nightmare
    "modifier_bane_nightmare",
}

# --- IsInvulnerable() ------------------------------------------------------
INVULNERABLE_MODIFIERS = {
    "modifier_invulnerable",
    "modifier_fountain_invulnerability",
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_eul_cyclone",
    "modifier_puck_phase_shift",
    "modifier_shadow_demon_disruption",
}

# --- J.HasForbiddenModifier -> J.Buff['enemy_is_immune'] (aba_buff.lua:4) ---
FORBIDDEN_MODIFIERS = {
    "modifier_necrolyte_reapers_scythe",
    "modifier_winter_wyvern_winters_curse",
    "modifier_winter_wyvern_winters_curse_aura",
    "modifier_troll_warlord_battle_trance",
}

# --- AXE HIMSELF MUST BE ABLE TO ACT --------------------------------------
# Caught 2026-09-06 by frame-verifying this tool's OWN candidate list: the
# Spirit Breaker instant (20260905_004904_slot1 t=1442.5) had Axe with Call off
# cooldown next to a spell-immune enemy -- and Axe was being DISMEMBERED, i.e.
# stunned and unable to cast anything.  Counting such a frame books "the veto
# cost us a cast" against a frame where no cast was possible for another
# reason entirely.  Same shape as the WK revive-window over-count of
# 2026-09-06T19:13Z, and it was found the same way (逐帧核验自己递上来的清单).
# ROOTS ARE DELIBERATELY NOT HERE: a rooted hero can still cast.
AXE_CANNOT_CAST = {
    # stun / channelled stun
    "modifier_stunned",
    "modifier_bashed",
    "modifier_spiritbreaker_greater_bash_knockback",
    "modifier_jakiro_ice_path_stun",
    "modifier_earthshaker_fissure_stun",
    "modifier_frogmen_arm_of_the_deep_stun",
    "modifier_lion_impale",
    "modifier_pudge_dismember",
    "modifier_storm_spirit_electric_vortex_pull",
    # hex
    "modifier_shadow_shaman_voodoo",
    "modifier_lion_voodoo",
    "modifier_sheepstick_debuff",
    # silence
    "modifier_silence",
    "modifier_death_prophet_silence",
    "modifier_skywrath_mage_ancient_seal",
    "modifier_silencer_global_silence",
    "modifier_silencer_curse_of_the_silent",
    "modifier_disruptor_static_storm",
    # banished / cycloned -- no orders accepted
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_eul_cyclone",
    # feared
    "modifier_nevermore_requiem_fear",
    "modifier_death_prophet_spirit_siphon_fear",
    # Axe is himself channelling a teleport
    "modifier_teleporting",
}

# --- channelling, censused over this corpus (see module docstring) ---------
# marker sits on the CHANNELLER itself
CHANNEL_SELF = {
    "modifier_teleporting",
    "modifier_crystal_maiden_freezing_field",
}
# marker sits on the VICTIM; the channeller is the event's `actor`
CHANNEL_BY_ACTOR = {
    "modifier_pudge_dismember",
    "modifier_shadow_shaman_shackles",
    "modifier_lion_mana_drain",
}
CHANNEL_MARKERS = CHANNEL_SELF | CHANNEL_BY_ACTOR

WATCHED = (IMMUNITY_MODIFIERS | DISABLE_MODIFIERS | INVULNERABLE_MODIFIERS
           | FORBIDDEN_MODIFIERS | CHANNEL_MARKERS | AXE_CANNOT_CAST)


# --------------------------------------------------------------------------
# name canon-isation (charter tool-trap: events drop the inner underscore)
# --------------------------------------------------------------------------
def canon(name):
    """`npc_dota_hero_vengeful_spirit` and `..._vengefulspirit` -> one key."""
    return (name or "").replace("_", "").lower()


def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


# --------------------------------------------------------------------------
# modifier / channel interval reconstruction
# --------------------------------------------------------------------------
def build_intervals(events, names, key_field="target"):
    """{(canon(key), modifier): [(t_add, t_remove), ...]} for `names`.

    An ADD with no REMOVE runs to +inf.  Nested ADDs of the same name on the
    same key merge into ONE interval -- a refresh is one window, not two.
    """
    open_at, out = {}, collections.defaultdict(list)
    for e in events:
        if e["type"] not in ("MODIFIER_ADD", "MODIFIER_REMOVE"):
            continue
        name = e.get("inflictor")
        if name not in names:
            continue
        key = (canon(e.get(key_field)), name)
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


def active(intervals, key, t):
    """Modifier names active on canon key `key` at time `t`."""
    hits = []
    for (k, name), spans in intervals.items():
        if k != key:
            continue
        for a, b in spans:
            if a <= t <= b:
                hits.append(name)
                break
    return hits


def build_channel_intervals(events):
    """Channel windows keyed by the CHANNELLING hero (canon)."""
    self_iv = build_intervals(events, CHANNEL_SELF, key_field="target")
    actor_iv = build_intervals(events, CHANNEL_BY_ACTOR, key_field="actor")
    merged = collections.defaultdict(list)
    for src in (self_iv, actor_iv):
        for key, spans in src.items():
            merged[key].extend(spans)
    return dict(merged)


# --------------------------------------------------------------------------
# per-game scan
# --------------------------------------------------------------------------
def is_call_castable(ab, mana):
    """`abilityQ:IsFullyCastable()` -- trained, off cooldown, mana affordable."""
    if ab is None or ab["level"] < 1:
        return False
    if ab["cd"] > 0:
        return False
    return mana >= CALL_MANA[min(ab["level"], len(CALL_MANA)) - 1]


def scan_game(tl, key):
    game = tl.get("game", {})
    teams = game.get("teams", {})
    if AXE not in teams:
        return None
    axe_team = teams[AXE]
    team_of = {canon(h): t for h, t in teams.items()}

    events = tl["events"]
    mods = build_intervals(events, WATCHED, key_field="target")
    channels = build_channel_intervals(events)

    # Axe <-> enemy-hero damage timestamps, per enemy (commitment proxies).
    # `commit`  -- either direction (they are fighting each other)
    # `dealt`   -- Axe HIT that enemy: the tightest observable stand-in for
    #             `botTarget == that enemy`, since J.GetProperTarget is
    #             bot:GetTarget() / bot:GetAttackTarget() (jmz_func.lua:335)
    #             and carries NO immunity filter of its own.
    commit = collections.defaultdict(list)
    dealt = collections.defaultdict(list)
    for e in events:
        if e["type"] != "DAMAGE":
            continue
        if not (e.get("actor_hero") and e.get("target_hero")):
            continue
        a, t_ = canon(e.get("actor")), canon(e.get("target"))
        if a == canon(AXE) and team_of.get(t_) not in (None, axe_team):
            commit[t_].append(e["t"])
            dealt[t_].append(e["t"])
        elif t_ == canon(AXE) and team_of.get(a) not in (None, axe_team):
            commit[a].append(e["t"])
    for k in commit:
        commit[k].sort()
    for k in dealt:
        dealt[k].sort()

    def _within(table, enemy_canon, t):
        ts = table.get(enemy_canon)
        if not ts:
            return False
        i = bisect.bisect_left(ts, t - COMMIT_WINDOW)
        return i < len(ts) and ts[i] <= t + COMMIT_WINDOW

    def committed(enemy_canon, t):
        return _within(commit, enemy_canon, t)

    def axe_dealt(enemy_canon, t):
        return _within(dealt, enemy_canon, t)

    # ILLUSION GUARD (GH #176): the real hero is the entity present at that
    # hero name's OWN earliest sample; illusions are born later.
    first_idx, first_t = {}, {}
    for s in tl["snapshots"]:
        h = s["hero"]
        if h not in first_t or s["t"] < first_t[h]:
            first_t[h], first_idx[h] = s["t"], s.get("idx")
    n_discarded = 0
    by_t = collections.defaultdict(dict)
    for s in tl["snapshots"]:
        if s.get("idx") != first_idx.get(s["hero"]):
            n_discarded += 1
            continue
        by_t[s["t"]][s["hero"]] = s

    # actual Call casts (control column: is the branch firing at all?)
    casts = [e for e in events
             if e["type"] == "ABILITY" and e.get("inflictor") == CALL
             and canon(e.get("actor")) == canon(AXE)]
    cast_ts = sorted(c["t"] for c in casts)

    def cast_near(t, window=COMMIT_WINDOW):
        """Did SOME other branch cast the Call anyway around this instant?

        A vetoed instant that is followed by a Call regardless is NOT a lost
        cast -- the shipped tree reached the same action by another road.
        """
        i = bisect.bisect_left(cast_ts, t - window)
        return i < len(cast_ts) and cast_ts[i] <= t + window

    rows_i, rows_ii = [], []
    n_frames = n_axe_ready = n_axe_blocked = 0
    for t in sorted(by_t):
        frame = by_t[t]
        axe = frame.get(AXE)
        n_frames += 1
        if axe is None or axe.get("hp", 0) <= 0 or not axe.get("abilities"):
            continue
        abils = {a["name"]: a for a in axe["abilities"]}
        q = abils.get(CALL)
        if not is_call_castable(q, axe.get("mp", 0)):
            continue
        # Axe must be able to act at all (see AXE_CANNOT_CAST)
        axe_blocked = [m for m in active(mods, canon(AXE), t)
                       if m in AXE_CANNOT_CAST]
        if axe_blocked:
            n_axe_blocked += 1
            continue
        n_axe_ready += 1

        enemies = []
        for h, s in frame.items():
            if teams.get(h) == axe_team or s.get("hp", 0) <= 0:
                continue
            ck = canon(h)
            act = active(mods, ck, t)
            enemies.append({
                "hero": h,
                "canon": ck,
                "d": dist(s, axe),
                "immune": [m for m in act if m in IMMUNITY_MODIFIERS],
                "disabled": [m for m in act if m in DISABLE_MODIFIERS],
                "invuln": [m for m in act if m in INVULNERABLE_MODIFIERS],
                "forbidden": [m for m in act if m in FORBIDDEN_MODIFIERS],
                "channeling": [n for n in active(channels, ck, t)],
            })

        for radius, tag in ((CALL_RADIUS_BASE, "r315"), (CALL_RADIUS_TALENT, "r400")):
            # ---- branch (i): interrupt -----------------------------------
            ring_i = radius - INTERRUPT_MARGIN
            chan = [e for e in enemies if e["d"] <= ring_i and e["channeling"]]
            if chan:
                imm = [e for e in chan if e["immune"]]
                rows_i.append({
                    "game": key, "t": t, "radius": tag,
                    "ring": ring_i,
                    "q_level": q["level"], "axe_mp": axe.get("mp"),
                    "n_channeling": len(chan),
                    "n_immune": len(imm),
                    "all_immune": len(imm) == len(chan),
                    "any_immune": bool(imm),
                    "cast_near": cast_near(t),
                    "enemies": [(e["hero"], round(e["d"], 1), e["channeling"],
                                 e["immune"]) for e in chan],
                })

            # ---- branch (ii): initiation (UPPER BOUND, LIMIT 1) ----------
            ring_ii = radius - INITIATE_MARGIN
            cands = [e for e in enemies
                     if e["d"] <= ring_ii
                     and not e["disabled"]        # not J.IsDisabled
                     and not e["invuln"]          # not IsInvulnerable
                     and not e["forbidden"]]      # not HasForbiddenModifier
            for e in cands:
                others = [o for o in enemies
                          if o["canon"] != e["canon"] and o["d"] <= radius]
                rows_ii.append({
                    "game": key, "t": t, "radius": tag,
                    "ring": ring_ii, "aoe_ring": radius,
                    "target": e["hero"], "d": round(e["d"], 1),
                    "immune": bool(e["immune"]),
                    "immune_src": e["immune"],
                    "others_in_ring": len(others),
                    "committed": committed(e["canon"], t),
                    "axe_dealt": axe_dealt(e["canon"], t),
                    "cast_near": cast_near(t),
                    "q_level": q["level"], "axe_mp": axe.get("mp"),
                })

    return {
        "game": key,
        "axe_team": axe_team,
        "n_frames": n_frames,
        "n_axe_ready": n_axe_ready,
        "n_axe_blocked": n_axe_blocked,
        "n_discarded_illusion_samples": n_discarded,
        "casts": [{"t": c["t"], "target": c.get("target")} for c in casts],
        "rows_i": rows_i,
        "rows_ii": rows_ii,
    }


# --------------------------------------------------------------------------
# episodes / aggregation
# --------------------------------------------------------------------------
def episodes(rows):
    """Group instants of the same game into episodes (gap > EPISODE_GAP)."""
    by_game = collections.defaultdict(list)
    for r in rows:
        by_game[r["game"]].append(r["t"])
    n = 0
    for g, ts in by_game.items():
        ts.sort()
        last = None
        for t in ts:
            if last is None or t - last > EPISODE_GAP:
                n += 1
            last = t
    return n


def summarise(per_game):
    out = {}
    for tag in ("r315", "r400"):
        i_rows = [r for g in per_game for r in g["rows_i"] if r["radius"] == tag]
        ii_rows = [r for g in per_game for r in g["rows_ii"] if r["radius"] == tag]
        # branch (i) is per-INSTANT (the loop returns on the first channeller)
        i_imm = [r for r in i_rows if r["any_immune"]]
        i_all = [r for r in i_rows if r["all_immune"]]
        # branch (ii) is per (instant, candidate target)
        ii_imm = [r for r in ii_rows if r["immune"]]
        ii_com = [r for r in ii_rows if r["committed"]]
        ii_com_imm = [r for r in ii_com if r["immune"]]
        ii_hit = [r for r in ii_rows if r["axe_dealt"]]
        ii_hit_imm = [r for r in ii_hit if r["immune"]]
        ii_ship = [r for r in ii_rows if not r["immune"]]
        out[tag] = {
            "branch_i": {
                "instants": len(i_rows),
                "episodes": episodes(i_rows),
                "games": len({r["game"] for r in i_rows}),
                "instants_any_immune": len(i_imm),
                "instants_all_immune": len(i_all),
                "instants_immune_without_a_cast_anyway": len(
                    [r for r in i_imm if not r["cast_near"]]),
                "immune_fraction": (len(i_imm) / len(i_rows)) if i_rows else None,
            },
            "branch_ii": {
                "target_instants": len(ii_rows),
                "episodes": episodes(ii_rows),
                "games": len({r["game"] for r in ii_rows}),
                "immune_instants": len(ii_imm),
                "immune_fraction": (len(ii_imm) / len(ii_rows)) if ii_rows else None,
                "committed_instants": len(ii_com),
                "committed_immune": len(ii_com_imm),
                "committed_immune_fraction": (
                    len(ii_com_imm) / len(ii_com)) if ii_com else None,
                "axe_dealt_instants": len(ii_hit),
                "axe_dealt_immune": len(ii_hit_imm),
                "axe_dealt_immune_fraction": (
                    len(ii_hit_imm) / len(ii_hit)) if ii_hit else None,
                "axe_dealt_immune_episodes": episodes(ii_hit_imm),
                "axe_dealt_immune_games": len({r["game"] for r in ii_hit_imm}),
                "axe_dealt_immune_no_cast_anyway": len(
                    [r for r in ii_hit_imm if not r["cast_near"]]),
                "axe_dealt_immune_no_cast_episodes": episodes(
                    [r for r in ii_hit_imm if not r["cast_near"]]),
                "axe_dealt_immune_no_cast_games": len(
                    {r["game"] for r in ii_hit_imm if not r["cast_near"]}),
                "others_in_ring_hist_shipped": dict(collections.Counter(
                    r["others_in_ring"] for r in ii_ship)),
                "others_in_ring_hist": dict(collections.Counter(
                    r["others_in_ring"] for r in ii_rows)),
                "others_in_ring_hist_immune": dict(collections.Counter(
                    r["others_in_ring"] for r in ii_imm)),
                "others_mean": (sum(r["others_in_ring"] for r in ii_rows)
                                / len(ii_rows)) if ii_rows else None,
                "others_mean_immune": (sum(r["others_in_ring"] for r in ii_imm)
                                       / len(ii_imm)) if ii_imm else None,
            },
        }
    return out


def side_split(per_game, tag):
    """Iron rule 4(i-a): both strata's READINGS are registered, not game counts."""
    out = {}
    for side, team in (("radiant", 2), ("dire", 3)):
        gs = [g for g in per_game if g["axe_team"] == team]
        i_rows = [r for g in gs for r in g["rows_i"] if r["radius"] == tag]
        ii_rows = [r for g in gs for r in g["rows_ii"] if r["radius"] == tag]
        out[side] = {
            "games": len(gs),
            "branch_i_instants": len(i_rows),
            "branch_i_immune": len([r for r in i_rows if r["any_immune"]]),
            "branch_ii_instants": len(ii_rows),
            "branch_ii_immune": len([r for r in ii_rows if r["immune"]]),
        }
    return out


# --------------------------------------------------------------------------
# selfcheck
# --------------------------------------------------------------------------
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

    # -- canon-isation (the charter's own 2026-08-21 trap) ------------------
    check("canon_matches_event_and_snapshot_spelling",
          canon("npc_dota_hero_vengeful_spirit") == canon("npc_dota_hero_vengefulspirit"))
    check("canon_keeps_distinct_heroes_distinct",
          canon("npc_dota_hero_axe") != canon("npc_dota_hero_lion"))

    # -- KV constants -------------------------------------------------------
    check("mana_table_from_kv", CALL_MANA == [90, 100, 110, 120])
    check("radius_pair_from_kv",
          CALL_RADIUS_BASE == 315.0 and CALL_RADIUS_TALENT == 400.0)
    check("interrupt_ring_is_radius_minus_50",
          CALL_RADIUS_BASE - INTERRUPT_MARGIN == 265.0
          and CALL_RADIUS_TALENT - INTERRUPT_MARGIN == 350.0)
    check("initiate_ring_is_radius_minus_90",
          CALL_RADIUS_BASE - INITIATE_MARGIN == 225.0
          and CALL_RADIUS_TALENT - INITIATE_MARGIN == 310.0)

    # -- IsFullyCastable ----------------------------------------------------
    check("castable_needs_training",
          not is_call_castable({"name": CALL, "level": 0, "cd": 0}, 999))
    check("castable_needs_cooldown_zero",
          not is_call_castable({"name": CALL, "level": 2, "cd": 3.2}, 999))
    check("castable_needs_mana_rank2",
          not is_call_castable({"name": CALL, "level": 2, "cd": 0}, 99)
          and is_call_castable({"name": CALL, "level": 2, "cd": 0}, 100))
    check("castable_rank4_costs_120",
          not is_call_castable({"name": CALL, "level": 4, "cd": 0}, 119)
          and is_call_castable({"name": CALL, "level": 4, "cd": 0}, 120))

    # -- modifier intervals -------------------------------------------------
    ev = [
        {"t": 10.0, "type": "MODIFIER_ADD", "actor": "e", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 18.0, "type": "MODIFIER_REMOVE", "actor": "e", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
    ]
    iv = build_intervals(ev, IMMUNITY_MODIFIERS)
    check("interval_closed", iv[("e", "modifier_black_king_bar_immune")] == [(10.0, 18.0)])
    check("active_inside", "modifier_black_king_bar_immune" in active(iv, "e", 12.0))
    check("inactive_after",
          "modifier_black_king_bar_immune" not in active(iv, "e", 25.0))
    dangling = build_intervals(
        [{"t": 4.0, "type": "MODIFIER_ADD", "actor": "e", "target": "e",
          "inflictor": "modifier_juggernaut_blade_fury"}], IMMUNITY_MODIFIERS)
    check("dangling_add_runs_to_inf",
          dangling[("e", "modifier_juggernaut_blade_fury")][0][1] == float("inf"))
    nested = build_intervals([
        {"t": 1.0, "type": "MODIFIER_ADD", "actor": "e", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 3.0, "type": "MODIFIER_ADD", "actor": "e", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
        {"t": 9.0, "type": "MODIFIER_REMOVE", "actor": "e", "target": "e",
         "inflictor": "modifier_black_king_bar_immune"},
    ], IMMUNITY_MODIFIERS)
    check("refresh_is_one_window",
          nested[("e", "modifier_black_king_bar_immune")] == [(1.0, 9.0)])

    # -- channel attribution: the victim is NOT the channeller --------------
    chev = [
        {"t": 5.0, "type": "MODIFIER_ADD", "actor": "npc_dota_hero_pudge",
         "target": "npc_dota_hero_axe", "inflictor": "modifier_pudge_dismember"},
        {"t": 8.0, "type": "MODIFIER_REMOVE", "actor": "npc_dota_hero_pudge",
         "target": "npc_dota_hero_axe", "inflictor": "modifier_pudge_dismember"},
        {"t": 20.0, "type": "MODIFIER_ADD", "actor": "npc_dota_hero_lina",
         "target": "npc_dota_hero_lina", "inflictor": "modifier_teleporting"},
        {"t": 23.0, "type": "MODIFIER_REMOVE", "actor": "npc_dota_hero_lina",
         "target": "npc_dota_hero_lina", "inflictor": "modifier_teleporting"},
    ]
    ch = build_channel_intervals(chev)
    check("channel_credited_to_caster_not_victim",
          "modifier_pudge_dismember" in active(ch, canon("npc_dota_hero_pudge"), 6.0)
          and "modifier_pudge_dismember" not in active(ch, canon("npc_dota_hero_axe"), 6.0))
    check("self_channel_credited_to_self",
          "modifier_teleporting" in active(ch, canon("npc_dota_hero_lina"), 21.0))

    # -- the names that must NOT be counted as spell immunity (LIMIT 5) -----
    check("ghost_shroud_is_not_spell_immunity",
          "modifier_necrolyte_ghost_shroud_active" not in IMMUNITY_MODIFIERS)
    check("ethereal_is_not_spell_immunity",
          "modifier_ghost_state" not in IMMUNITY_MODIFIERS)
    check("mask_of_madness_is_not_spell_immunity",
          "modifier_item_mask_of_madness_berserk" not in IMMUNITY_MODIFIERS)
    check("omniknight_martyr_is_not_spell_immunity",
          not any("martyr" in m or "guardian_angel" in m for m in IMMUNITY_MODIFIERS))

    # -- end-to-end on a synthetic game ------------------------------------
    def snap(t, hero, idx, team, x, y, hp=1000, mp=500, abils=None, level=10):
        return {"t": t, "hero": hero, "idx": idx, "team": team, "x": x, "y": y,
                "hp": hp, "hp_pct": 1.0, "mp": mp, "max_mp": 800, "level": level,
                "items": [], "abilities": abils if abils is not None else []}

    call_ready = [{"name": CALL, "level": 2, "cd": 0, "cd_len": 16}]
    tl = {
        "game": {"start_time": 0.0,
                 "teams": {AXE: 2, "npc_dota_hero_lina": 3,
                           "npc_dota_hero_pudge": 3}},
        "events": [
            # Lina TPs (channelling) inside the ring while BKB'd
            {"t": 100.0, "type": "MODIFIER_ADD", "actor": "npc_dota_hero_lina",
             "target": "npc_dota_hero_lina", "inflictor": "modifier_teleporting"},
            {"t": 103.0, "type": "MODIFIER_REMOVE", "actor": "npc_dota_hero_lina",
             "target": "npc_dota_hero_lina", "inflictor": "modifier_teleporting"},
            {"t": 99.0, "type": "MODIFIER_ADD", "actor": "npc_dota_hero_lina",
             "target": "npc_dota_hero_lina",
             "inflictor": "modifier_black_king_bar_immune"},
            {"t": 105.0, "type": "MODIFIER_REMOVE", "actor": "npc_dota_hero_lina",
             "target": "npc_dota_hero_lina",
             "inflictor": "modifier_black_king_bar_immune"},
            {"t": 101.0, "type": "DAMAGE", "actor": "npc_dota_hero_axe",
             "target": "npc_dota_hero_lina", "actor_hero": True,
             "target_hero": True},
        ],
        "snapshots": [
            snap(101.0, AXE, 1, 2, 0, 0, abils=call_ready),
            snap(101.0, "npc_dota_hero_lina", 2, 3, 200, 0),
            snap(101.0, "npc_dota_hero_pudge", 3, 3, 300, 0),
            # an illusion of Lina, born later, standing on top of Axe
            snap(101.0, "npc_dota_hero_lina", 77, 3, 5, 0),
        ],
    }
    g = scan_game(tl, "synthetic")
    check("synthetic_axe_ready_frame_counted", g["n_axe_ready"] == 1)
    check("illusion_sample_discarded", g["n_discarded_illusion_samples"] == 1)
    i315 = [r for r in g["rows_i"] if r["radius"] == "r315"]
    check("branch_i_sees_the_immune_channeller",
          len(i315) == 1 and i315[0]["n_channeling"] == 1
          and i315[0]["all_immune"])
    ii315 = [r for r in g["rows_ii"] if r["radius"] == "r315"]
    check("branch_ii_ring_is_225_not_315",
          [r["target"] for r in ii315] == ["npc_dota_hero_lina"])
    check("branch_ii_counts_the_other_enemy_in_the_aoe_ring",
          ii315[0]["others_in_ring"] == 1)
    check("branch_ii_marks_the_immune_target", ii315[0]["immune"] is True)
    check("branch_ii_commitment_proxy_fires", ii315[0]["committed"] is True)
    check("branch_ii_axe_dealt_proxy_fires", ii315[0]["axe_dealt"] is True)
    check("no_call_cast_in_the_synthetic_game", ii315[0]["cast_near"] is False)
    ii400 = [r for r in g["rows_ii"] if r["radius"] == "r400"]
    check("talent_radius_admits_pudge_too",
          sorted(r["target"] for r in ii400)
          == ["npc_dota_hero_lina", "npc_dota_hero_pudge"])

    # the two proxies are NOT the same column: an enemy who only hits AXE is
    # "committed" but was never Axe's own attack target.
    tl_rev = json.loads(json.dumps(tl))
    tl_rev["events"] = [e for e in tl_rev["events"] if e["type"] != "DAMAGE"]
    tl_rev["events"].append({"t": 101.0, "type": "DAMAGE",
                             "actor": "npc_dota_hero_lina",
                             "target": "npc_dota_hero_axe",
                             "actor_hero": True, "target_hero": True})
    g_rev = scan_game(tl_rev, "synthetic_reverse")
    rev = [r for r in g_rev["rows_ii"] if r["radius"] == "r315"][0]
    check("axe_dealt_is_directional",
          rev["committed"] is True and rev["axe_dealt"] is False)

    # a stunned AXE buys nothing, however good the target looks
    tl_stun = json.loads(json.dumps(tl))
    tl_stun["events"].append({"t": 100.0, "type": "MODIFIER_ADD",
                              "actor": "npc_dota_hero_pudge",
                              "target": AXE,
                              "inflictor": "modifier_pudge_dismember"})
    tl_stun["events"].append({"t": 104.0, "type": "MODIFIER_REMOVE",
                              "actor": "npc_dota_hero_pudge",
                              "target": AXE,
                              "inflictor": "modifier_pudge_dismember"})
    g_stun = scan_game(tl_stun, "synthetic_axe_dismembered")
    check("dismembered_axe_is_not_domain",
          not g_stun["rows_i"] and not g_stun["rows_ii"]
          and g_stun["n_axe_blocked"] == 1 and g_stun["n_axe_ready"] == 0)
    tl_root = json.loads(json.dumps(tl))
    tl_root["events"].append({"t": 100.0, "type": "MODIFIER_ADD",
                              "actor": "npc_dota_hero_lina", "target": AXE,
                              "inflictor": "modifier_medusa_gorgon_grasp_root"})
    g_root = scan_game(tl_root, "synthetic_axe_rooted")
    check("rooted_axe_can_still_cast", g_root["n_axe_ready"] == 1)

    # a disabled target is refused by J.IsDisabled
    tl2 = json.loads(json.dumps(tl))
    tl2["events"].append({"t": 100.5, "type": "MODIFIER_ADD",
                          "actor": "npc_dota_hero_axe",
                          "target": "npc_dota_hero_lina",
                          "inflictor": "modifier_stunned"})
    tl2["events"].append({"t": 102.5, "type": "MODIFIER_REMOVE",
                          "actor": "npc_dota_hero_axe",
                          "target": "npc_dota_hero_lina",
                          "inflictor": "modifier_stunned"})
    g2 = scan_game(tl2, "synthetic_stunned")
    check("branch_ii_refuses_a_stunned_target",
          not [r for r in g2["rows_ii"]
               if r["radius"] == "r315" and r["target"] == "npc_dota_hero_lina"])
    check("branch_i_does_not_care_about_stun",
          len([r for r in g2["rows_i"] if r["radius"] == "r315"]) == 1)

    # a dead Axe frame buys nothing
    tl3 = json.loads(json.dumps(tl))
    tl3["snapshots"][0]["hp"] = 0
    g3 = scan_game(tl3, "synthetic_dead")
    check("dead_axe_frame_is_not_domain",
          not g3["rows_i"] and not g3["rows_ii"])

    # a game without Axe is skipped outright
    tl4 = json.loads(json.dumps(tl))
    tl4["game"]["teams"].pop(AXE)
    check("game_without_axe_returns_none", scan_game(tl4, "no_axe") is None)

    # episodes: two instants 1s apart are one episode, 10s apart are two
    check("episode_grouping",
          episodes([{"game": "g", "t": 1.0}, {"game": "g", "t": 2.0}]) == 1
          and episodes([{"game": "g", "t": 1.0}, {"game": "g", "t": 11.0}]) == 2)

    print("\n%d PASS / %d FAIL" % (ok, fail))
    return 0 if fail == 0 else 1


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tl_dir", nargs="?")
    ap.add_argument("--json")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()
    if not a.tl_dir:
        ap.error("TL_DIR required unless --selfcheck")

    files = sorted(glob.glob(os.path.join(a.tl_dir, "*.timeline.json")))
    per_game, unparseable = [], 0
    for f in files:
        try:
            tl = json.load(open(f))
        except Exception:
            unparseable += 1
            continue
        g = scan_game(tl, os.path.basename(f)[: -len(".timeline.json")])
        if g is not None:
            per_game.append(g)

    summ = summarise(per_game)
    total_casts = sum(len(g["casts"]) for g in per_game)
    report = {
        "games_scanned": len(files),
        "games_with_axe": len(per_game),
        "unparseable": unparseable,
        "frames": sum(g["n_frames"] for g in per_game),
        "axe_call_ready_frames": sum(g["n_axe_ready"] for g in per_game),
        "axe_ready_but_cannot_act_frames": sum(
            g["n_axe_blocked"] for g in per_game),
        "illusion_samples_discarded": sum(
            g["n_discarded_illusion_samples"] for g in per_game),
        "berserkers_call_casts": total_casts,
        "summary": summ,
        "side_split_r315": side_split(per_game, "r315"),
        "side_split_r400": side_split(per_game, "r400"),
    }

    if a.frames:
        rows = [r for g in per_game for r in g["rows_i"] if r["radius"] == "r315"]
        print("=== branch (i) pinnable instants (r315, ring 265) ===")
        for r in rows[: a.top]:
            print("%-95s t=%8.1f  %s" % (r["game"][:95], r["t"], r["enemies"]))
        imm = [r for g in per_game for r in g["rows_ii"]
               if r["radius"] == "r315" and r["immune"]]
        print("\n=== branch (ii) IMMUNE-target instants (r315, ring 225) ===")
        for r in imm[: a.top]:
            print("%-95s t=%8.1f  %-28s d=%5.1f others=%d committed=%s %s"
                  % (r["game"][:95], r["t"], r["target"], r["d"],
                     r["others_in_ring"], r["committed"], r["immune_src"]))
        return 0

    print(json.dumps(report, indent=2))
    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"report": report, "per_game": per_game}, fh)
    return 0


if __name__ == "__main__":
    sys.exit(main())

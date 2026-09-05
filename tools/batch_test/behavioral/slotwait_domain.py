#!/usr/bin/env python3
"""(a)-verification for soak candidate `slotwait` (GH #467, admitted W47).

WHAT `slotwait` DOES
--------------------
`bots/FunLib/utils.lua:2141` / `:2168` -- the last two LIVE members of the
eight-strong pid-for-slot cluster (`slotarb` GH #406, `slotdust` GH #411,
`slotpush` GH #415 fixed three of the others; GH #467 censused the remaining
five as having no caller in `bots/` at all):

    for i, playerId in ipairs(GetTeamPlayers(GetTeam())) do
        local nSlot = playerId
        if bSlotWait then nSlot = i end          -- <- THE GATE
        local teamMember = GetTeamMember(nSlot)
        if teamMember ~= nil and teamMember:IsAlive() then
            local nDuration = GetUnitToLocationDistance(teamMember, targetLoc)
                              / teamMember:GetCurrentMovementSpeed()
            ... HasCriticalSpellWithCooldown(teamMember, nDuration)      -- spell leg
            ... GetItem(teamMember, itemName):GetCooldownTimeRemaining() > nDuration  -- item leg
        end
    end
    return false

`GetTeamPlayers` hands back PLAYER IDS (0..4 radiant / 5..9 dire);
`GetTeamMember` takes a TEAM SLOT (1..5) and answers nil out of range.

  * radiant: nSlot 0..4.  `GetTeamMember(0)` is nil, slots 1..4 answer ->
    FOUR of five members are scanned; the hero in team slot 5 is never asked.
  * dire: nSlot 5..9.  Only 5 is in range -> exactly ONE of five is scanned.

Armed, `nSlot = i`, so all five slots are scanned.

WHY THIS PAIR IS THE EASY ONE (and it changes what has to be measured)
---------------------------------------------------------------------
The guard is `teamMember:IsAlive()`, asked about the member the accessor just
handed back -- there is NO guard/subject split, unlike `slotpush`, whose
misaligned `IsHeroAlive(playerdId)` guard creates an `over` direction too.
Here the loop is monotone in the scan set: a member can only turn the answer
into TRUE, never into FALSE.  The shipped TRUE set is therefore a STRICT
SUBSET of the armed one, and the ONLY divergence direction that exists is
`armed TRUE / shipped FALSE`.  This script counts that one direction, and
counting it needs no armed-vs-baseline comparison at all -- it is a property
of the arithmetic, evaluable on either leg's frames (iron rule 4(i-b) keeps a
side-biased estimator out of a cross-leg read; nothing here is cross-leg).

CONSUMER AND SIGN
-----------------
Sole consumer: `aba_push.ShouldWaitForImportantItemsSpells(vEnemyLaneFront)`
(`bots/FunLib/aba_push.lua:284`), whose TRUE caps the push desire:

    if waitForSpells and eAliveCount >= aAliveCount
                     and eAliveCoreCount >= aAliveCoreCount then
        nMaxDesire = math.min(nMaxDesire, 0.5)

TRUE means "hold the push, a teammate's key spell/item is not back yet".
Under-scanning can only make TRUE harder to reach => the shipped tree opens a
mid/late-game push while the teammates it never looked at are not ready.
Systematically pushing EARLY, and only early.

WHAT THIS READING CAN AND CANNOT SAY
------------------------------------
LIMIT 1 -- `GetTeamMember(slot)` mapping.  Team slot s is taken to be pid s-1
(radiant) / s+4 (dire), i.e. the roster in player-id order.  Not observable in
a `.dem`; every count inherits it.  Same hypothesis as `slotpush_domain.py`.

LIMIT 2 -- THE ITEM LEG IS NOT OBSERVABLE.  `items` in the dump is a list of
NAMES; item cooldowns are not dumped at all.  `ImportantItems` is exactly
{black_king_bar, refresher}.  So a frame can be shipped-TRUE through an item
this script cannot see, which would make a divergence a false positive.
Two columns are therefore reported and NEITHER is "the" answer:
  * `naive`  -- spell leg only.  UPPER bound on the divergence set.
  * `strict` -- additionally requires that no scanned-and-alive member even
    HOLDS a BKB/refresher (holding is observable, its cooldown is not).
    LOWER bound.
The truth is between them.  Reporting only `naive` would be reporting the
item leg's blindness as the gate's effect.

LIMIT 3 -- `nDuration` IS NOT OBSERVABLE, AND NEITHER BOUND DOMINATES.  It is
`dist(member, enemyLaneFront) / member movespeed`; neither the lane front
(`GetLaneFrontLocation`, engine-side and per-lane) nor movespeed is dumped, so
the script sweeps the plausible range: `--duration 0` and `--duration 40`
(~12000 u at 300 ms).

The PER-MEMBER predicate `cd > nDuration` is monotone decreasing in nDuration.
The DIVERGENCE IS NOT, and reading the two runs as "upper and lower bound on
one number" is wrong.  Divergence is `missed_true and not scanned_true`:
raising the bound can switch a MISSED member off (removing a divergence) or a
SCANNED member off (CREATING one).  Caught frame-first, not by reasoning:
W47 `20260904_184704_slot3` t=573.4 (seed 4763, armed radiant) has luna
(pid 0, SCANNED) on `luna_eclipse` cd 36.6 and crystal_maiden (pid 4, the one
missed slot) on `crystal_maiden_freezing_field` cd 66.0 -- a divergence at
bound 40 and NOT one at bound 0.  So the two runs are two different questions,
both reported, neither subtracted from the other.

LIMIT 4 -- `cd` freshness.  The dump's `cd` is the last networked cooldown
remaining, "+-1 snapshot" per the dumper README.  A cooldown that ticks to 0
inside the sampling gap reads as still-on-cooldown.  That inflates BOTH the
scanned and the missed side, so it does not have a single direction here --
unlike GH #491, where the selection condition and the contamination source
were the same condition.  Registered, not corrected.

LIMIT 5 -- ONLY THE GATE INPUT IS MEASURED, NOT THE PUSH.  Reaching the cap
also needs the bot to be evaluating push desire on that lane at that second,
with a desire that would otherwise exceed 0.5.  Neither is in the dump.  The
alive-count conjunct IS observable and is reported as its own narrowing
(`d3`), but `d3` is still an upper bound on frames where behaviour changed.

LIMIT 6 -- `HasCriticalSpellWithCooldown` reads `ImportantSpells[hero][1]`
only -- the FIRST entry.  NINE rows have a tail the shipped code never reads,
and for several of them the unread entry is the ULTIMATE while the read one is
not: necrolyte (ghost_shroud read, reapers_scythe not), warlock (fatal_bonds
read, golem not), witch_doctor (voodoo_switcheroo read, death_ward not),
winter_wyvern, shadow_demon, grimstroke, undying, spectre, terrorblade.  This
script mirrors that exactly -- measuring the ultimate instead would measure a
predicate the bot does not have.  A hero absent from the table (40 of them) has
no spell leg at all.

The table is 88 rows and is TRANSCRIBED, not curated: it was first written out
by hand at 40 rows, and `tests/test_slotwait_domain_liveness.py` refused that
by diffing against the Lua.  Regenerate it from `utils.lua`, never edit by
hand.

LIMIT 7 -- `IsValidAbility` requires `IsTrained()`; level >= 1 is the
observable half.  `IsHidden`/`IsActivated` are not dumped, so an ability
hidden behind a shapeshift would be counted here and refused in the engine.

Usage:
    slotwait_domain.py <timeline.json> [more...] [--duration 0] [--json out]
    slotwait_domain.py --selfcheck
"""
import argparse
import json
import os
import sys

# bots/ts_libs/dota/heroes.lua HeroName -> bots/FunLib/utils.lua ImportantSpells.
# ONLY the first entry of each list is ever read (LIMIT 6); the tail is kept in
# a comment so a future reader can see what the shipped code ignores.
IMPORTANT_SPELL = {
    "npc_dota_hero_alchemist": "alchemist_chemical_rage",
    "npc_dota_hero_axe": "axe_culling_blade",
    "npc_dota_hero_bristleback": "bristleback_bristleback",
    "npc_dota_hero_centaur": "centaur_stampede",
    "npc_dota_hero_chaos_knight": "chaos_knight_phantasm",
    "npc_dota_hero_dawnbreaker": "dawnbreaker_solar_guardian",
    "npc_dota_hero_doom_bringer": "doom_bringer_doom",
    "npc_dota_hero_dragon_knight": "dragon_knight_elder_dragon_form",
    "npc_dota_hero_earth_spirit": "earth_spirit_magnetize",
    "npc_dota_hero_earthshaker": "earthshaker_echo_slam",
    "npc_dota_hero_elder_titan": "elder_titan_earth_splitter",
    "npc_dota_hero_kunkka": "kunkka_ghostship",
    "npc_dota_hero_legion_commander": "legion_commander_duel",
    "npc_dota_hero_life_stealer": "life_stealer_rage",
    "npc_dota_hero_mars": "mars_arena_of_blood",
    "npc_dota_hero_night_stalker": "night_stalker_darkness",
    "npc_dota_hero_omniknight": "omniknight_guardian_angel",
    "npc_dota_hero_primal_beast": "primal_beast_pulverize",
    "npc_dota_hero_sven": "sven_gods_strength",
    "npc_dota_hero_tidehunter": "tidehunter_ravage",
    "npc_dota_hero_treant": "treant_overgrowth",
    "npc_dota_hero_undying": "undying_tombstone",  # [2+] undying_flesh_golem NEVER read
    "npc_dota_hero_skeleton_king": "skeleton_king_reincarnation",
    "npc_dota_hero_antimage": "antimage_mana_void",
    "npc_dota_hero_bloodseeker": "bloodseeker_rupture",
    "npc_dota_hero_clinkz": "clinkz_burning_barrage",
    "npc_dota_hero_faceless_void": "faceless_void_chronosphere",
    "npc_dota_hero_gyrocopter": "gyrocopter_flak_cannon",
    "npc_dota_hero_hoodwink": "hoodwink_sharpshooter",
    "npc_dota_hero_juggernaut": "juggernaut_omni_slash",
    "npc_dota_hero_luna": "luna_eclipse",
    "npc_dota_hero_medusa": "medusa_stone_gaze",
    "npc_dota_hero_monkey_king": "monkey_king_wukongs_command",
    "npc_dota_hero_naga_siren": "naga_siren_song_of_the_siren",
    "npc_dota_hero_razor": "razor_static_link",
    "npc_dota_hero_nevermore": "nevermore_requiem",
    "npc_dota_hero_slark": "slark_shadow_dance",
    "npc_dota_hero_spectre": "spectre_shadow_step",  # [2+] spectre_haunt NEVER read
    "npc_dota_hero_terrorblade": "terrorblade_metamorphosis",  # [2+] terrorblade_sunder NEVER read
    "npc_dota_hero_troll_warlord": "troll_warlord_battle_trance",
    "npc_dota_hero_ursa": "ursa_enrage",
    "npc_dota_hero_viper": "viper_viper_strike",
    "npc_dota_hero_weaver": "weaver_time_lapse",
    "npc_dota_hero_ancient_apparition": "ancient_apparition_ice_blast",
    "npc_dota_hero_crystal_maiden": "crystal_maiden_freezing_field",
    "npc_dota_hero_death_prophet": "death_prophet_exorcism",
    "npc_dota_hero_disruptor": "disruptor_static_storm",
    "npc_dota_hero_grimstroke": "grimstroke_dark_portrait",  # [2+] grimstroke_soul_chain NEVER read
    "npc_dota_hero_jakiro": "jakiro_macropyre",
    "npc_dota_hero_lich": "lich_chain_frost",
    "npc_dota_hero_lina": "lina_laguna_blade",
    "npc_dota_hero_lion": "lion_finger_of_death",
    "npc_dota_hero_muerta": "muerta_pierce_the_veil",
    "npc_dota_hero_necrolyte": "necrolyte_ghost_shroud",  # [2+] necrolyte_reapers_scythe NEVER read
    "npc_dota_hero_oracle": "oracle_false_promise",
    "npc_dota_hero_obsidian_destroyer": "obsidian_destroyer_sanity_eclipse",
    "npc_dota_hero_puck": "puck_dream_coil",
    "npc_dota_hero_pugna": "pugna_life_drain",
    "npc_dota_hero_queenofpain": "queenofpain_sonic_wave",
    "npc_dota_hero_ringmaster": "ringmaster_wheel",
    "npc_dota_hero_shadow_demon": "shadow_demon_disruption",  # [2+] shadow_demon_demonic_cleanse,shadow_demon_demonic_purge NEVER read
    "npc_dota_hero_shadow_shaman": "shadow_shaman_mass_serpent_ward",
    "npc_dota_hero_silencer": "silencer_global_silence",
    "npc_dota_hero_skywrath_mage": "skywrath_mage_mystic_flare",
    "npc_dota_hero_warlock": "warlock_fatal_bonds",  # [2+] warlock_golem NEVER read
    "npc_dota_hero_witch_doctor": "witch_doctor_voodoo_switcheroo",  # [2+] witch_doctor_death_ward NEVER read
    "npc_dota_hero_zuus": "zuus_thundergods_wrath",
    "npc_dota_hero_abaddon": "abaddon_borrowed_time",
    "npc_dota_hero_bane": "bane_fiends_grip",
    "npc_dota_hero_batrider": "batrider_flaming_lasso",
    "npc_dota_hero_beastmaster": "beastmaster_primal_roar",
    "npc_dota_hero_brewmaster": "brewmaster_primal_split",
    "npc_dota_hero_broodmother": "broodmother_insatiable_hunger",
    "npc_dota_hero_chen": "chen_hand_of_god",
    "npc_dota_hero_dark_seer": "dark_seer_wall_of_replica",
    "npc_dota_hero_dark_willow": "dark_willow_terrorize",
    "npc_dota_hero_enigma": "enigma_black_hole",
    "npc_dota_hero_lycan": "lycan_shapeshift",
    "npc_dota_hero_magnataur": "magnataur_reverse_polarity",
    "npc_dota_hero_marci": "marci_unleash",
    "npc_dota_hero_pangolier": "pangolier_gyroshell",
    "npc_dota_hero_phoenix": "phoenix_supernova",
    "npc_dota_hero_sand_king": "sandking_epicenter",
    "npc_dota_hero_snapfire": "snapfire_mortimer_kisses",
    "npc_dota_hero_vengefulspirit": "vengefulspirit_nether_swap",
    "npc_dota_hero_venomancer": "venomancer_noxious_plague",
    "npc_dota_hero_windrunner": "windrunner_focusfire",
    "npc_dota_hero_winter_wyvern": "winter_wyvern_cold_embrace",  # [2+] winter_wyvern_winters_curse NEVER read
}

# bots/FunLib/utils.lua:869 -- ImportantItems, verbatim, minus the "item_" prefix
# the dumper strips.  GetItem() looks at the first SIX slots only (active
# inventory), utils.lua:2097 GetItemFromCountedInventory(bot, name, 6).
IMPORTANT_ITEMS = ("black_king_bar", "refresher")
ACTIVE_INVENTORY_SLOTS = 6

TURBO_MID_START = 5 * 60.0     # jmz_func.lua:4687 IsMidGame, turbo branch
TURBO_LATE_START = 18 * 60.0   # jmz_func.lua:4694 IsLateGame, turbo branch

RADIANT, DIRE = 2, 3


def shipped_scanned_pids(team):
    """Player ids the SHIPPED scan actually reaches, per LIMIT 1.

    radiant: nSlot = pid in 0..4; GetTeamMember(0) is nil, slots 1..4 are team
    slots 1..4 == pids 0..3.  dire: nSlot = pid in 5..9; only 5 is in range and
    team slot 5 == pid 9.
    """
    if team == RADIANT:
        return {0, 1, 2, 3}
    return {9}


def all_pids(team):
    return set(range(0, 5)) if team == RADIANT else set(range(5, 10))


def is_core(pid):
    """Position 1/2/3.  aba_role.lua RoleAssignment is the fixed [1..5] cycle,
    so position = pid % 5 + 1 (registered in the 2026-08-19T08:49Z report)."""
    return (pid % 5 + 1) in (1, 2, 3)


def phase_ok(t):
    """IsMidGame() or IsLateGame() in turbo.  Note both are STRICT
    inequalities in jmz_func.lua, so t == 1080.0 exactly is NEITHER."""
    return (TURBO_MID_START < t < TURBO_LATE_START) or (t > TURBO_LATE_START)


def spell_on_cd(snap, duration):
    """HasCriticalSpellWithCooldown(member, nDuration), observable half.

    IsValidAbility needs IsTrained() -> level >= 1 (LIMIT 7)."""
    name = IMPORTANT_SPELL.get(snap.get("hero"))
    if name is None:
        return False
    for ab in snap.get("abilities") or ():
        if ab.get("name") != name:
            continue
        if (ab.get("level") or 0) < 1:
            return False
        cd = ab.get("cd")
        if cd is None:          # charter warning: `cd` can be absent/None
            return False
        return cd > duration
    return False


def holds_important_item(snap):
    """Observable half of the item leg: does the member HOLD a BKB/refresher in
    the six active-inventory slots.  Its cooldown is NOT observable (LIMIT 2)."""
    items = (snap.get("items") or [])[:ACTIVE_INVENTORY_SLOTS]
    return any(i in IMPORTANT_ITEMS for i in items)


def alive(snap):
    return (snap.get("hp_pct") or 0.0) > 0.0


def real_body_idx(timeline):
    """The `idx` streams that are REAL HEROES, by entities.frames_by_hero's rule.

    CAUGHT FRAME-FIRST, THIS ROUND, ON A REAL FRAME: dire pid 6
    (chaos_knight) in `20260904_190005_slot1` has ELEVEN snapshot rows at
    t=739.4 -- one real body plus ten `chaos_knight_phantasm` illusions, all
    carrying the SAME hero name AND the same `player_id`.  Keying the second
    index by player_id alone lets whichever row sorts last win, and an
    illusion's ability list is not the hero's: this predicate reads a
    cooldown, so an illusion row can flip the answer in either direction.

    The rule that survives (`entities.py:163`, and this stream's own
    2026-09-04T21:56Z note that `idx` alone is NOT a stable entity key
    because the engine recycles indices): keep only streams whose FIRST
    sample is at or before the horn.  Illusions are all born after it.  When
    two pre-horn streams claim one player id, keep the longer-lived one
    rather than letting sort order decide.
    """
    by_idx = {}
    for s in timeline.get("snapshots") or ():
        idx = s.get("idx")
        if idx is None:
            continue
        e = by_idx.setdefault(idx, {"t0": float(s["t"]), "n": 0, "pid": s.get("player_id")})
        e["t0"] = min(e["t0"], float(s["t"]))
        e["n"] += 1
    keep = {}
    for idx, e in sorted(by_idx.items()):
        if e["t0"] > 0.0 or e["pid"] is None:      # HORN_T == 0.0
            continue
        prev = keep.get(e["pid"])
        if prev is None or e["n"] > by_idx[prev]["n"]:
            keep[e["pid"]] = idx
    return set(keep.values())


def frames_by_second(timeline):
    """{t: {pid: snapshot}} keeping only live REAL bodies with a player_id."""
    real = real_body_idx(timeline)
    out = {}
    for s in timeline.get("snapshots") or ():
        pid = s.get("player_id")
        if pid is None or not alive(s):
            continue
        if s.get("idx") is not None and s["idx"] not in real:
            continue
        out.setdefault(round(float(s["t"]), 1), {})[pid] = s
    return out


def scan_team_second(bodies, team, duration):
    """One team, one second.  Returns a dict of the two bounds plus context.

    bodies: {pid: snapshot} of LIVE members (dead ones are simply absent, which
    is exactly what the IsAlive() guard does to them)."""
    scanned = shipped_scanned_pids(team)
    mine = {p: s for p, s in bodies.items() if p in all_pids(team)}

    scanned_true = any(spell_on_cd(s, duration) for p, s in mine.items() if p in scanned)
    missed_true = any(spell_on_cd(s, duration) for p, s in mine.items() if p not in scanned)
    scanned_holds = any(holds_important_item(s) for p, s in mine.items() if p in scanned)

    naive = missed_true and not scanned_true
    strict = naive and not scanned_holds
    return {
        "naive": naive,
        "strict": strict,
        "scanned_true": scanned_true,
        "missed_true": missed_true,
        "scanned_holds": scanned_holds,
        "n_alive": len(mine),
        "n_alive_core": sum(1 for p in mine if is_core(p)),
    }


def analyse_game(timeline, duration):
    """Per-team counts for one game."""
    per_second = frames_by_second(timeline)
    res = {}
    for team in (RADIANT, DIRE):
        enemy = DIRE if team == RADIANT else RADIANT
        c = {"seconds": 0, "phase_seconds": 0, "naive": 0, "strict": 0,
             "d3_naive": 0, "d3_strict": 0, "scanned_true": 0, "missed_true": 0,
             "frames": []}
        for t in sorted(per_second):
            bodies = per_second[t]
            r = scan_team_second(bodies, team, duration)
            e = scan_team_second(bodies, enemy, duration)
            c["seconds"] += 1
            if r["scanned_true"]:
                c["scanned_true"] += 1
            if r["missed_true"]:
                c["missed_true"] += 1
            if not phase_ok(t):
                continue
            c["phase_seconds"] += 1
            if not r["naive"]:
                continue
            c["naive"] += 1
            if r["strict"]:
                c["strict"] += 1
            # the conjunct the cap needs: eAliveCount >= aAliveCount and
            # eAliveCoreCount >= aAliveCoreCount (aba_push.lua:285)
            if e["n_alive"] >= r["n_alive"] and e["n_alive_core"] >= r["n_alive_core"]:
                c["d3_naive"] += 1
                if r["strict"]:
                    c["d3_strict"] += 1
                    c["frames"].append({
                        "t": t,
                        "missed": sorted(p for p in bodies
                                         if p in all_pids(team)
                                         and p not in shipped_scanned_pids(team)
                                         and spell_on_cd(bodies[p], duration)),
                        "n_alive": r["n_alive"], "e_alive": e["n_alive"],
                    })
        res["radiant" if team == RADIANT else "dire"] = c
    return res


def selfcheck():
    checks = []

    def ck(msg, ok):
        checks.append((msg, bool(ok)))

    ck("radiant shipped scan reaches pids 0..3 and misses 4",
       shipped_scanned_pids(RADIANT) == {0, 1, 2, 3}
       and all_pids(RADIANT) - shipped_scanned_pids(RADIANT) == {4})
    ck("dire shipped scan reaches pid 9 only and misses 5..8",
       shipped_scanned_pids(DIRE) == {9}
       and all_pids(DIRE) - shipped_scanned_pids(DIRE) == {5, 6, 7, 8})
    ck("cores are positions 1/2/3 == pids 0,1,2 and 5,6,7",
       [p for p in range(10) if is_core(p)] == [0, 1, 2, 5, 6, 7])
    ck("turbo phase: 300 is out, 301 in, 1080 exactly out, 1081 in",
       not phase_ok(300.0) and phase_ok(301.0)
       and not phase_ok(1080.0) and phase_ok(1081.0))

    sven_cd = {"hero": "npc_dota_hero_sven", "hp_pct": 1.0, "items": [""] * 9,
               "abilities": [{"name": "sven_gods_strength", "level": 2, "cd": 55.0}]}
    ck("spell leg true when cd exceeds nDuration", spell_on_cd(sven_cd, 40.0))
    ck("spell leg false when nDuration exceeds cd", not spell_on_cd(sven_cd, 60.0))
    ck("spell leg false on an untrained ability (IsValidAbility/IsTrained)",
       not spell_on_cd({"hero": "npc_dota_hero_sven",
                        "abilities": [{"name": "sven_gods_strength", "level": 0,
                                       "cd": 99.0}]}, 0.0))
    ck("spell leg false when cd is None (the charter's warning)",
       not spell_on_cd({"hero": "npc_dota_hero_sven",
                        "abilities": [{"name": "sven_gods_strength", "level": 3,
                                       "cd": None}]}, 0.0))
    # 88 of the ~128 heroes ARE in the table; drow_ranger is one of the 40
    # that are not, and a hero absent from it has no spell leg at all.
    ck("a hero absent from ImportantSpells has no spell leg",
       "npc_dota_hero_drow_ranger" not in IMPORTANT_SPELL
       and not spell_on_cd({"hero": "npc_dota_hero_drow_ranger",
                            "abilities": [{"name": "drow_ranger_marksmanship",
                                           "level": 3, "cd": 99.0}]}, 0.0))
    ck("only the FIRST ImportantSpells entry is read (LIMIT 6: undying golem)",
       not spell_on_cd({"hero": "npc_dota_hero_undying",
                        "abilities": [{"name": "undying_flesh_golem", "level": 3,
                                       "cd": 99.0}]}, 0.0))
    ck("item leg observes holding only, in the first six slots",
       holds_important_item({"items": ["", "black_king_bar", "", "", "", "", ""]})
       and not holds_important_item(
           {"items": ["", "", "", "", "", "", "black_king_bar", "", ""]}))

    # A dire frame where ONLY a missed member (pid 6) is on cooldown.
    def body(pid, hero, cd=None, level=2, items=None):
        s = {"hero": hero, "player_id": pid, "hp_pct": 1.0,
             "items": items or [""] * 9, "abilities": []}
        if cd is not None:
            s["abilities"] = [{"name": IMPORTANT_SPELL[hero], "level": level, "cd": cd}]
        return s

    dire_leak = {6: body(6, "npc_dota_hero_sven", cd=55.0),
                 9: body(9, "npc_dota_hero_luna")}
    r = scan_team_second(dire_leak, DIRE, 0.0)
    ck("dire divergence: a missed member on cooldown, the scanned one not",
       r["naive"] and r["strict"] and r["missed_true"] and not r["scanned_true"])

    r = scan_team_second({9: body(9, "npc_dota_hero_sven", cd=55.0),
                          6: body(6, "npc_dota_hero_luna")}, DIRE, 0.0)
    ck("no divergence when the SCANNED member is the one on cooldown",
       not r["naive"] and r["scanned_true"])

    r = scan_team_second({6: body(6, "npc_dota_hero_sven", cd=55.0),
                          9: body(9, "npc_dota_hero_luna",
                                  items=["black_king_bar"] + [""] * 8)}, DIRE, 0.0)
    ck("strict refuses what naive keeps when a scanned member HOLDS a bkb",
       r["naive"] and not r["strict"] and r["scanned_holds"])

    # radiant mirror: only pid 4 is ever missed
    r = scan_team_second({4: body(4, "npc_dota_hero_sven", cd=55.0),
                          0: body(0, "npc_dota_hero_luna")}, RADIANT, 0.0)
    ck("radiant divergence rides on pid 4 alone", r["naive"] and r["strict"])
    r = scan_team_second({3: body(3, "npc_dota_hero_sven", cd=55.0)}, RADIANT, 0.0)
    ck("pid 3 is scanned by the shipped code, so it is not a divergence",
       not r["naive"] and r["scanned_true"])

    # a dead missed member cannot leak: the IsAlive() guard drops it on BOTH legs
    ck("a dead member is absent from the frame index and cannot leak",
       not scan_team_second({9: body(9, "npc_dota_hero_luna")}, DIRE, 0.0)["naive"])

    # ILLUSION CONTROL (the real-frame defect this round caught frame-first):
    # one real pre-horn stream for pid 6 whose ultimate IS on cooldown, plus an
    # illusion stream born after the horn carrying the SAME pid, the SAME hero
    # and a READY ultimate.  Keying by pid alone lets the illusion win and the
    # divergence disappears; the pre-horn rule must keep the real body.
    def row(idx, t, pid, hero, cd, t0=False):
        s = body(pid, hero, cd=cd)
        return dict(s, idx=idx, t=t, team=DIRE if pid >= 5 else RADIANT)

    illu = {"snapshots": [
        row(11, -30.0, 6, "npc_dota_hero_chaos_knight", 55.0),
        row(11, 400.0, 6, "npc_dota_hero_chaos_knight", 55.0),
        row(22, 399.0, 6, "npc_dota_hero_chaos_knight", 0.0),
        row(22, 400.0, 6, "npc_dota_hero_chaos_knight", 0.0),
        row(33, -30.0, 9, "npc_dota_hero_luna", 0.0),
        row(33, 400.0, 9, "npc_dota_hero_luna", 0.0),
    ]}
    ck("the post-horn illusion stream is dropped, the pre-horn body kept",
       real_body_idx(illu) == {11, 33})
    ck("illusion control: the divergence survives an illusion with a ready ult",
       analyse_game(illu, 0.0)["dire"]["naive"] == 1)

    # FALSE-POSITIVE CONTROL: a whole game with nobody ever on cooldown must
    # read zero, or the counter is measuring its own scaffolding.
    quiet = {"snapshots": []}
    for t in (100.0, 400.0, 1200.0):
        for pid, hero in ((0, "npc_dota_hero_luna"), (4, "npc_dota_hero_sven"),
                          (5, "npc_dota_hero_axe"), (9, "npc_dota_hero_lich")):
            s = body(pid, hero) if hero in IMPORTANT_SPELL else body(pid, "npc_dota_hero_luna")
            s = dict(s, t=t, hero=hero, team=RADIANT if pid < 5 else DIRE,
                     abilities=[])
            quiet["snapshots"].append(s)
    g = analyse_game(quiet, 0.0)
    ck("false-positive control: a game with no cooldowns reads 0 divergence",
       g["radiant"]["naive"] == 0 and g["dire"]["naive"] == 0
       and g["radiant"]["phase_seconds"] == 2)

    bad = [m for m, ok in checks if not ok]
    for m, ok in checks:
        print(("  ok   " if ok else "  FAIL ") + m)
    print("selfcheck: %d checks, %d failed" % (len(checks), len(bad)))
    return 0 if not bad else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*")
    ap.add_argument("--duration", type=float, default=0.0,
                    help="nDuration bound in seconds (LIMIT 3): 0 = upper "
                         "bound on the divergence set, 40 = lower bound")
    ap.add_argument("--json", default=None)
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.timelines:
        ap.error("give at least one timeline.json (or --selfcheck)")

    totals = {"radiant": {}, "dire": {}}
    per_game = []
    for path in a.timelines:
        with open(path) as fh:
            tl = json.load(fh)
        g = analyse_game(tl, a.duration)
        per_game.append({"game": os.path.basename(path), "teams": g})
        for side in ("radiant", "dire"):
            for k, v in g[side].items():
                if k == "frames":
                    continue
                totals[side][k] = totals[side].get(k, 0) + v

    print("slotwait domain -- nDuration bound = %.1fs, %d game(s)"
          % (a.duration, len(a.timelines)))
    print("%-8s %9s %9s %8s %8s %8s %8s" %
          ("side", "seconds", "phase_s", "naive", "strict", "d3_naive", "d3_strict"))
    for side in ("radiant", "dire"):
        t = totals[side]
        print("%-8s %9d %9d %8d %8d %8d %8d" %
              (side, t.get("seconds", 0), t.get("phase_seconds", 0),
               t.get("naive", 0), t.get("strict", 0),
               t.get("d3_naive", 0), t.get("d3_strict", 0)))
    print("\nthe two columns are BOUNDS, not two estimates (LIMIT 2): the item "
          "leg's\ncooldown is not in the dump, so the truth is between strict "
          "and naive.")

    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"duration": a.duration, "totals": totals,
                       "games": per_game}, fh, indent=1)
        print("wrote %s" % a.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())

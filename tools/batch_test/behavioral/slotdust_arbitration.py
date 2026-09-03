#!/usr/bin/env python3
"""[slotdust] TRIGGER-level reader over dumper timelines.

Second member of the family `wandbleed_trigger.py` opened: it does not measure a
*domain* (an upper bound on frames where a gate could have fired), it measures
the FIRINGS THEMSELVES, because the action this gate produces is one item
activation and that is directly in the combat log:

    events[] type == "ITEM"  actor == <hero>  inflictor == "item_dust"

WHY THIS ID GETS A STRUCTURAL ZERO ON THE BASELINE LEG (the `fieldsip`
template, and the reason this is the cheapest un-recorded id to buy).

Source of truth: `J.IsClosestToDustLocation` (bots/FunLib/jmz_func.lua:11591),
resolved in exactly one place, the `ClosestDustCarrier` wrapper in
bots/ability_item_usage_generic.lua:59.

    for i, id in pairs(AllyPIDs) do            -- AllyPIDs = GetTeamPlayers(...)
        local nSlot = id                       -- a PLAYER ID (0-4 / 5-9)
        if bSlotDust then nSlot = i end        -- the gate: a team SLOT (1..5)
        local member = GetTeamMember(nSlot)
        ...
    if closest ~= nil then return closest == bot end

`GetTeamMember` takes a team SLOT 1..5 (docs/BOT_API_REFERENCE.md:223) and
answers nil out of range, so UNARMED the scanned roster is decided by the
numeric VALUES of the player ids, and it is side-dependent:

    radiant  ids 0..4 -> GetTeamMember(0) is nil, 1..4 are slots 1..4
             => team slot 5 is NEVER scanned
    dire     ids 5..9 -> only GetTeamMember(5) exists
             => team slots 1..4 are NEVER scanned

`closest == bot` can therefore only be TRUE for a hero the scan reaches.  So
UNARMED, a dust cast that went through either gated branch is IMPOSSIBLE for:

    * every dire hero except the one in team slot 5, and
    * the radiant hero in team slot 5.

Call those the UNREACHABLE slots.  A gated cast from an unreachable slot is a
cast no shipped configuration can produce -- a hard structural zero on the
baseline leg, not a small number.  That, and not a rate difference, is what
this script counts.

WHICH BRANCHES ARE GATED, AND HOW THE UNGATED ONES ARE EXCLUDED.
`X.ConsiderItemDesire['item_dust']` (ability_item_usage_generic.lua:7279) is the
ONLY dust-cast site in bots/ (censused; the other `item_dust` hits are purchase
lists, `modifier_item_dustofappearance` reads, and the helper itself).  It has
five return paths, evaluated in order:

  B1  trees<5 ; an enemy last seen 0.2-0.5 s ago ; its last-seen loc within
      600 u ; ClosestDustCarrier                                    [GATED]
  B2  the caster has modifier_sandking_sand_storm_slow{,_aura_thinker} [ungated]
  B3  no enemy within 1050 ; caster has modifier_item_radiance_debuff [ungated]
  B4  no enemy within 1050 ; WasRecentlyDamagedByPlayer(id, 0.5) ; that
      enemy's last-seen loc within 1050                             [ungated]
  B5  an enemy within 1050 ; it is going invisible ; ClosestDustCarrier ;
      no invis counter ; not an illusion ; no enemy tower within 700 [GATED]

B1 and B5 are the gate.  The three ungated paths are excluded by OBSERVABLE
clauses only, each in the conservative direction (they throw real firings away,
they cannot invent one):

  B2 -> the game carries no Sand King on either side (draft census).  The
        modifier can only come from an enemy Sand King; excluding on EITHER
        side is slack on purpose.
  B3 -> no hero on the caster's ENEMY side ever holds a radiance in this game
        (snapshot `items[]`).  "Ever", not "by now": slack again.
  B4 -> no DAMAGE event of any kind lands on the caster in [t-0.8, t).  The
        engine clause is 0.5 s; 0.8 s is a 60% margin over the 0.1 s event grid.

*** BOTH OF THOSE EXCLUSIONS WERE WRONG IN THIS SCRIPT'S FIRST RUN, and its own
falsification column (LIMIT 6) is what said so: baseline 10 in a column whose
baseline is structurally zero.  The two defects are LIMIT 9 and LIMIT 10 below,
and both failed in the PERMISSIVE direction -- they promoted casts INTO the
exclusive column on the leg that cannot produce them.  Neither is visible in a
count that is merely plausible, which is why the zero-baseline control is the
load-bearing part of this design and not a decoration.

Note what B4's exclusion costs and why it is still the primary channel: it
throws away every dust cast thrown while the caster is being hit, which is a
large share of them.  The alternative -- excluding B3/B4 by showing an enemy
INSIDE the 1050 ring -- needs the engine's VISION, because `J.GetEnemiesNearLoc`
is vision-limited and a replay dump is not.  A body inside the ring that the
bot could not see leaves B3/B4 reachable, so that route is NOT airtight and is
reported as a separate, secondary column (`ring_nonempty`), never as the
verdict.

LIMITS -- read before quoting a number.

 1. TEAM SLOT IS DERIVED, NOT DUMPED.  `GetTeamMember(k)` is the k-th member of
    your team; the dump carries `player_id`.  This script maps radiant slot =
    pid+1 and dire slot = pid-4, and REFUSES any game whose two pre-horn rosters
    are not exactly {0..4} and {5..9} (five distinct bodies each).  The mapping
    is checked against the corpus rather than assumed: on the BASELINE leg the
    gated-shaped casts must land on reachable slots, and any that do not are
    reported as an INSTRUMENT FAILURE (LIMIT 6), not as a firing.
 2. EVENTS CARRY NO idx.  `events[].actor` is a name, so a cast is attributed to
    the one pre-horn body of that name.  An illusion cannot activate an item, so
    this is safe for the CAST.
 3. ENTITY KEYS (GH #176): bodies are keyed (hero, idx) and frames with
    hp_pct <= 0 are dropped, because an illusion's stream keeps being emitted
    with frozen coordinates long after it dies.
 4. THE RING COLUMN COUNTS REAL BODIES ONLY, and that is the safe direction for
    the use it is put to here.  `J.GetEnemiesNearLoc` does not filter illusions
    (GH #436), so the engine's ring is a SUPERSET of the one measured here: when
    this script says the ring is non-empty, the engine's is too.  The converse
    does not hold, which is the other half of why `ring_nonempty` is secondary.
 5. BOTH LEGS LIVE IN THE SAME GAME and are not independent samples.  Per
    铁律 4(i-a) every reading is registered split by ab / ba.  This estimator
    does NOT cancel side bias, so 4(i-b) applies: a count that flips sign
    between the layers is noise and does not enter a conclusion.
 6. A NON-ZERO BASELINE IN THE EXCLUSIVE COLUMN FALSIFIES THIS SCRIPT, not the
    fix.  The baseline leg runs the same five-branch function with the gate
    closed, so an unreachable-slot cast surviving all three ungated exclusions
    cannot happen there.  Baseline > 0 means the branch partition or the slot
    mapping (LIMIT 1) is wrong -- report it as an instrument bug.
 7. `item_gungir` also calls ClosestDustCarrier (line 6684) but falls through to
    `item_rod_of_atos`'s desire when the gated branch is false, so a gungir cast
    has an UNGATED explanation that no observable clause removes.  Gungir casts
    are counted for context and are NEVER part of the exclusive column.
 9. *** THE COMBAT LOG AND SNAPSHOT `items[]` USE DISJOINT ITEM VOCABULARIES.
    Over this corpus (64 games) the combat log carries 87 distinct `item_*`
    inflictor names and snapshot `items[]` carries 164 distinct names, and the
    two sets share NOTHING.  `items[]` is de-prefixed (`item_radiance` ->
    `radiance`), and for several items it is not even a prefix strip:
        item_dust          -> dustof_appearance
        item_ward_observer -> observer_ward
        item_bottle        -> empty_bottle   (the only bottle spelling present)
    So an `item_`-prefixed literal tested against `items[]` is not a rare miss,
    it is ALWAYS false, and it fails SILENTLY in the permissive direction for
    any "the enemy does not carry X" exclusion.  That is exactly how this
    script's B3 clause read "no radiance in this game" for 64 straight games
    while the combat log carried 20,167 `item_radiance` damage events.
10. `WasRecentlyDamagedByPlayer(id, 0.5)` IS PER-PLAYER, NOT PER-HERO-BODY: a
    player's summons and illusions carry their damage too, and those actors are
    not heroes in the combat log.  The B4 exclusion therefore takes ANY damage
    on the caster, not only `actor_hero` damage.
11. THE GATE CUTS BOTH WAYS.  Armed is NOT a subset of shipped here (the search
    seeds with `nil`, so the caller wins only by being found): a hero inside the
    shipped scan can LOSE to a nearer ally the armed scan reaches.  This script
    can only see the direction that produces a cast; the suppression direction
    is invisible to it and is not claimed either way.
"""
import argparse
import collections
import json
import math
import os
import re
import sys

DUST = "item_dust"
GUNGIR = "item_gungir"
B4_DAMAGE_WINDOW = 0.8   # engine clause is 0.5 s; margin over the 0.1 s grid
ENEMY_RING = 1050.0      # nRadius in ConsiderItemDesire['item_dust']
VMAX = 700.0             # u/s closing-speed bound, above the 550 u/s move cap
SANDKING = "npc_dota_hero_sand_king"
# *** THE TWO ITEM VOCABULARIES ARE DISJOINT (LIMIT 9).  The combat log says
# `item_radiance`; snapshot `items[]` says `radiance`.  Over this corpus the two
# name sets intersect in NOTHING (87 combat-log `item_*` names, 164 snapshot
# names, zero shared), so an `item_`-prefixed literal tested against `items[]`
# is not a rare miss -- it is ALWAYS false.  This constant is the snapshot
# spelling on purpose.
RADIANCE = "radiance"
RADIANT, DIRE = 2, 3

STAMP = re.compile(r"^mirror:(?P<cand>.*):s(?P<seed>\d+):(?P<side>radiant|dire)$")


def real_bodies(snaps):
    """(hero, idx) keys of entities first sampled before the horn (LIMIT 3)."""
    born = {}
    for s in snaps:
        k = (s["hero"], s["idx"])
        if k not in born or s["t"] < born[k]:
            born[k] = s["t"]
    return {k for k, t0 in born.items() if t0 < 0.0}


def index(snaps, bodies):
    by_ent = collections.defaultdict(list)
    by_t = collections.defaultdict(list)
    for s in snaps:
        if (s.get("hp_pct") or 0) <= 0:
            continue
        by_t[round(s["t"], 3)].append(s)
        k = (s["hero"], s["idx"])
        if k in bodies:
            by_ent[k].append(s)
    for v in by_ent.values():
        v.sort(key=lambda s: s["t"])
    return by_ent, by_t


def roster(by_ent):
    """{team: {pid: (hero, idx)}} over pre-horn bodies, or None if malformed."""
    out = {RADIANT: {}, DIRE: {}}
    for k, frames in by_ent.items():
        s = frames[0]
        team, pid = s.get("team"), s.get("player_id")
        if team not in out or pid is None or pid < 0:
            continue
        if pid in out[team] and out[team][pid] != k:
            return None                       # two bodies claim one player slot
        out[team][pid] = k
    if sorted(out[RADIANT]) != [0, 1, 2, 3, 4]:
        return None
    if sorted(out[DIRE]) != [5, 6, 7, 8, 9]:
        return None
    return out


def team_slot(team, pid):
    """GetTeamMember's 1..5 argument for this player id (LIMIT 1)."""
    return pid + 1 if team == RADIANT else pid - 4


def reachable_unarmed(team, slot):
    """Slots the SHIPPED scan can return, from the numeric player-id values."""
    if team == RADIANT:
        return slot in (1, 2, 3, 4)   # id 0 is out of range, id 5 never asked
    return slot == 5                  # ids 6..9 are out of range


def last_frame_before(frames, t):
    best = None
    for s in frames:
        if s["t"] < t:
            best = s
        else:
            break
    return best


def first_frame_after(frames, t):
    for s in frames:
        if s["t"] > t:
            return s
    return None


def nearest_enemy(by_t, s, team):
    best = math.inf
    for o in by_t.get(round(s["t"], 3), ()):
        if o["team"] == team:
            continue
        d = math.hypot(o["x"] - s["x"], o["y"] - s["y"])
        if d < best:
            best = d
    return best


def ring_nonempty(frames, by_t, s_pre, t_cast, team):
    """True only if an enemy MUST have been inside ENEMY_RING at t_cast.

    Bounded by VMAX on both sides and REFUSED when there is no sample after the
    cast, so the margin is spent making the answer conservative (LIMIT 4).
    """
    d_pre = nearest_enemy(by_t, s_pre, team)
    s_post = first_frame_after(frames, t_cast)
    if s_post is None:
        return False, d_pre, None
    d_post = nearest_enemy(by_t, s_post, team)
    ok = (d_pre < ENEMY_RING - VMAX * (t_cast - s_pre["t"])
          and d_post < ENEMY_RING - VMAX * (s_post["t"] - t_cast))
    return ok, d_pre, d_post


def scan_game(tl, armed_side):
    snaps = tl.get("snapshots") or []
    events = tl.get("events") or []
    if not snaps:
        return None
    bodies = real_bodies(snaps)
    by_ent, by_t = index(snaps, bodies)
    team_roster = roster(by_ent)
    if team_roster is None:
        return None                        # LIMIT 1: refuse, do not guess
    key_of = {}
    for team, pids in team_roster.items():
        for pid, k in pids.items():
            key_of.setdefault(k[0], (k, team, pid))
    armed_team = RADIANT if armed_side == "radiant" else DIRE

    # B2 census: a Sand King anywhere in the draft disarms the exclusive column.
    sandking = any(k[0] == SANDKING for k in by_ent)
    # B3 census: which side ever holds a radiance.
    radiance_teams = set()
    for k, frames in by_ent.items():
        for s in frames:
            if RADIANCE in (s.get("items") or ()):
                radiance_teams.add(s["team"])
                break

    # LIMIT 10: `WasRecentlyDamagedByPlayer` counts a PLAYER's damage, which
    # includes that player's summons and illusions -- entities whose combat-log
    # actor is not a hero at all.  Filtering on `actor_hero` would leave B4
    # reachable on exactly those frames, so ANY damage landing on the caster
    # disarms the exclusive column.  Slack in the safe direction: this also
    # throws away casts whose only recent damage came from a creep, Roshan or a
    # tower, which no player id can claim.
    dmg_by_target = collections.defaultdict(list)
    for e in events:
        if e.get("type") == "DAMAGE" and e.get("target_hero"):
            dmg_by_target[e["target"]].append(e["t"])
    for v in dmg_by_target.values():
        v.sort()

    out = {leg: collections.Counter() for leg in ("armed", "baseline")}
    rows, bugs = [], []
    for e in events:
        inf = e.get("inflictor")
        if e.get("type") != "ITEM" or inf not in (DUST, GUNGIR):
            continue
        got = key_of.get(e.get("actor"))
        if got is None:
            continue
        k, team, pid = got
        leg = "armed" if team == armed_team else "baseline"
        if inf == GUNGIR:
            out[leg]["gungir_casts"] += 1        # LIMIT 7: context only
            continue
        out[leg]["dust_casts"] += 1

        frames = by_ent[k]
        s = last_frame_before(frames, e["t"])
        if s is None:
            continue
        slot = team_slot(team, pid)
        enemy_team = DIRE if team == RADIANT else RADIANT
        near, d_pre, d_post = ring_nonempty(frames, by_t, s, e["t"], team)
        if near:
            out[leg]["ring_nonempty"] += 1       # secondary column, LIMIT 4
        dmg = [t for t in dmg_by_target.get(k[0], ())
               if e["t"] - B4_DAMAGE_WINDOW <= t < e["t"]]

        if reachable_unarmed(team, slot):
            out[leg]["reachable_slot"] += 1
            continue
        out[leg]["unreachable_slot"] += 1
        if sandking:
            out[leg]["blocked_b2_sandking"] += 1
            continue
        if enemy_team in radiance_teams:
            out[leg]["blocked_b3_radiance"] += 1
            continue
        if dmg:
            out[leg]["blocked_b4_recent_damage"] += 1
            continue

        out[leg]["exclusive"] += 1
        row = {
            "leg": leg, "hero": k[0], "idx": k[1], "team": team, "pid": pid,
            "slot": slot, "t_cast": round(e["t"], 2), "t_frame": round(s["t"], 2),
            "hp_pct": round(s.get("hp_pct") or 0, 3), "hp": s.get("hp"),
            "x": round(s.get("x") or 0, 1), "y": round(s.get("y") or 0, 1),
            "d_enemy_pre": None if d_pre == math.inf else round(d_pre, 1),
            "d_enemy_post": (None if d_post in (None, math.inf)
                             else round(d_post, 1)),
            "ring_nonempty": near,
        }
        rows.append(row)
        if leg == "baseline":
            bugs.append(row)                     # LIMIT 6
    return out, rows, bugs


def selfcheck():
    ok = [0, 0]

    def check(name, cond):
        ok[0 if cond else 1] += 1
        print("  %-64s %s" % (name, "PASS" if cond else "FAIL"))

    def snap(hero, idx, team, pid, t, x=0.0, y=0.0, hp_pct=0.5, items=None):
        return {"t": t, "hero": hero, "idx": idx, "team": team,
                "player_id": pid, "x": x, "y": y, "hp": 500, "hp_pct": hp_pct,
                "items": items if items is not None else ["", "", "", "", "", "",
                                                          "", "", ""]}

    def build(caster_team, caster_pid, **kw):
        """Ten pre-horn bodies plus one enemy placed at `enemy_d` from caster."""
        enemy_d = kw.get("enemy_d", 5000.0)
        items = kw.get("enemy_items")
        heroes = kw.get("heroes")
        snaps = []
        for pid in range(10):
            team = RADIANT if pid < 5 else DIRE
            name = (heroes or {}).get(pid, "npc_dota_hero_h%d" % pid)
            is_caster = (team == caster_team and pid == caster_pid)
            for t in (-30.0, 9.0, 11.0):
                x = 0.0 if is_caster else 9000.0
                it = None
                if team != caster_team and items:
                    it = items
                if team != caster_team and pid == (9 if caster_team == RADIANT else 4):
                    x = enemy_d
                snaps.append(snap(name, 100 + pid, team, pid, t, x=x, items=it))
        ev = kw.get("events") or []
        return {"snapshots": snaps, "events": ev}

    cast = [{"t": 10.0, "type": "ITEM", "actor": "npc_dota_hero_h5",
             "target": "npc_dota_hero_h5", "inflictor": DUST, "value": 0,
             "actor_hero": True, "target_hero": True}]

    # dire pid 5 == team slot 1: unreachable unarmed.
    g = build(DIRE, 5, events=cast)
    res, rows, bugs = scan_game(g, "dire")          # dire carries the armed leg
    check("a dire slot-1 dust cast is EXCLUSIVE on the armed leg",
          res["armed"]["exclusive"] == 1 and rows and rows[0]["slot"] == 1)

    res_b, _, bugs_b = scan_game(g, "radiant")      # same cast, baseline leg
    check("the same cast on the baseline leg is reported as an instrument bug",
          res_b["baseline"]["exclusive"] == 1 and len(bugs_b) == 1)

    # dire pid 9 == team slot 5: the ONE slot the shipped scan reaches.
    cast9 = [dict(cast[0], actor="npc_dota_hero_h9", target="npc_dota_hero_h9")]
    res, rows, _ = scan_game(build(DIRE, 9, events=cast9), "dire")
    check("a dire slot-5 dust cast is REACHABLE unarmed, never exclusive",
          res["armed"]["reachable_slot"] == 1 and res["armed"]["exclusive"] == 0)

    # radiant pid 4 == team slot 5: the radiant hole.
    cast4 = [dict(cast[0], actor="npc_dota_hero_h4", target="npc_dota_hero_h4")]
    res, rows, _ = scan_game(build(RADIANT, 4, events=cast4), "radiant")
    check("a radiant slot-5 dust cast is EXCLUSIVE",
          res["armed"]["exclusive"] == 1 and rows[0]["slot"] == 5)

    # radiant pid 0 == team slot 1: reachable (GetTeamMember(1) exists).
    cast0 = [dict(cast[0], actor="npc_dota_hero_h0", target="npc_dota_hero_h0")]
    res, _, _ = scan_game(build(RADIANT, 0, events=cast0), "radiant")
    check("a radiant slot-1 dust cast is REACHABLE unarmed",
          res["armed"]["reachable_slot"] == 1 and res["armed"]["exclusive"] == 0)

    # B4: hero damage inside the 0.8 s window disarms the exclusive column.
    dmg = [{"t": 9.6, "type": "DAMAGE", "actor": "npc_dota_hero_h0",
            "target": "npc_dota_hero_h5", "inflictor": "", "value": 100,
            "actor_hero": True, "target_hero": True}]
    res, _, _ = scan_game(build(DIRE, 5, events=dmg + cast), "dire")
    check("recent hero damage blocks the cast (B4 is reachable there)",
          res["armed"]["blocked_b4_recent_damage"] == 1
          and res["armed"]["exclusive"] == 0)
    old = [{"t": 8.9, "type": "DAMAGE", "actor": "npc_dota_hero_h0",
            "target": "npc_dota_hero_h5", "inflictor": "", "value": 100,
            "actor_hero": True, "target_hero": True}]
    res, _, _ = scan_game(build(DIRE, 5, events=old + cast), "dire")
    check("damage older than the 0.8 s window does not block",
          res["armed"]["exclusive"] == 1)

    # B2: a Sand King anywhere in the draft disarms it.
    res, _, _ = scan_game(build(DIRE, 5, events=cast,
                                heroes={0: SANDKING}), "dire")
    check("a Sand King in the draft blocks the cast (B2 is reachable)",
          res["armed"]["blocked_b2_sandking"] == 1)

    # B3: an enemy radiance disarms it.  Spelled the SNAPSHOT way (LIMIT 9).
    res, _, _ = scan_game(build(DIRE, 5, events=cast,
                                enemy_items=["radiance"] + [""] * 8), "dire")
    check("an enemy radiance blocks the cast (B3 is reachable)",
          res["armed"]["blocked_b3_radiance"] == 1)
    # LIMIT 9 pinned: the combat-log spelling must NOT be what items[] is read
    # for.  This is the real defect that put 10 casts on the baseline leg.
    res, _, _ = scan_game(build(DIRE, 5, events=cast,
                                enemy_items=["item_radiance"] + [""] * 8), "dire")
    check("the combat-log spelling is not the items[] spelling (LIMIT 9)",
          res["armed"]["blocked_b3_radiance"] == 0
          and res["armed"]["exclusive"] == 1)
    # LIMIT 10 pinned: damage from a NON-hero actor still disarms B4, because
    # WasRecentlyDamagedByPlayer counts a player's summons and illusions.
    summon = [{"t": 9.6, "type": "DAMAGE", "actor": "npc_dota_lycan_wolf1",
               "target": "npc_dota_hero_h5", "inflictor": "", "value": 40,
               "actor_hero": False, "target_hero": True}]
    res, _, _ = scan_game(build(DIRE, 5, events=summon + cast), "dire")
    check("non-hero damage on the caster still blocks (LIMIT 10)",
          res["armed"]["blocked_b4_recent_damage"] == 1
          and res["armed"]["exclusive"] == 0)

    # LIMIT 1: a malformed roster is refused, never guessed at.
    bad = build(DIRE, 5, events=cast)
    bad["snapshots"] = [s for s in bad["snapshots"] if s["player_id"] != 7]
    check("a game whose roster is not {0..4}/{5..9} is REFUSED",
          scan_game(bad, "dire") is None)

    # LIMIT 7: gungir is context, never exclusive.
    gun = [dict(cast[0], inflictor=GUNGIR)]
    res, _, _ = scan_game(build(DIRE, 5, events=gun), "dire")
    check("a gungir cast is counted as context, never as exclusive",
          res["armed"]["gungir_casts"] == 1 and res["armed"]["exclusive"] == 0)

    # LIMIT 3: an illusion born after the horn is not a caster.
    illu = build(DIRE, 5, events=cast)
    illu["snapshots"].append(snap("npc_dota_hero_h5", 999, DIRE, 5, 5.0))
    res, rows, _ = scan_game(illu, "dire")
    check("a post-horn body of the same name does not become the caster",
          res["armed"]["exclusive"] == 1 and rows[0]["idx"] == 105)

    # the ring column: an enemy far away is not read as inside 1050.
    res, rows, _ = scan_game(build(DIRE, 5, events=cast, enemy_d=9000.0), "dire")
    check("a distant enemy leaves ring_nonempty false",
          res["armed"]["ring_nonempty"] == 0 and rows[0]["ring_nonempty"] is False)

    print("selfcheck: %d pass, %d fail" % tuple(ok))
    return 0 if ok[1] == 0 else 1


KEYS = ("dust_casts", "gungir_casts", "reachable_slot", "unreachable_slot",
        "blocked_b2_sandking", "blocked_b3_radiance", "blocked_b4_recent_damage",
        "ring_nonempty", "exclusive")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*")
    ap.add_argument("--stamps", help="JSON {timeline basename: 'mirror:...:sN:side'}")
    ap.add_argument("--manifest", action="append", default=[],
                    help="a sweep_run.sh games_manifest.jsonl (repeatable)")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--rows", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(selfcheck())
    if not a.timelines or not (a.stamps or a.manifest):
        ap.error("timelines and --stamps/--manifest are required unless --selfcheck")

    stamps = {}
    if a.stamps:
        with open(a.stamps) as fh:
            stamps.update(json.load(fh))
    for mp in a.manifest:
        with open(mp) as fh:
            for line in fh:
                if not line.strip():
                    continue
                g = json.loads(line)
                stamps[g["game"]] = "mirror:%s:s%s:%s" % (g["cand"], g["seed"], g["side"])

    layers = {"ab": collections.Counter(), "ba": collections.Counter()}
    all_rows, all_bugs, seen, skipped, refused = [], [], 0, 0, 0
    for path in sorted(a.timelines):
        base = os.path.basename(path)
        for suf in (".timeline.json", ".json"):
            if base.endswith(suf):
                base = base[: -len(suf)]
                break
        st = stamps.get(base)
        m = STAMP.match(st) if st else None
        if not m:
            skipped += 1
            print("skip (no/unparseable stamp): %s" % base, file=sys.stderr)
            continue
        with open(path) as fh:
            tl = json.load(fh)
        got = scan_game(tl, m.group("side"))
        if got is None:
            refused += 1
            print("refused (roster not {0..4}/{5..9}): %s" % base, file=sys.stderr)
            continue
        res, rows, bugs = got
        seen += 1
        layer = "ab" if m.group("side") == "radiant" else "ba"
        layers[layer]["games"] += 1
        for leg in ("armed", "baseline"):
            for k in KEYS:
                layers[layer]["%s_%s" % (leg, k)] += res[leg][k]
        for r in rows + bugs:
            r["game"] = base
            r["layer"] = layer
        all_rows.extend(rows)
        all_bugs.extend(bugs)

    print("games read: %d  (skipped %d, refused %d)" % (seen, skipped, refused))
    print()
    hdr = "%6s %6s %9s" % ("layer", "games", "leg") + "".join(
        "%*s" % (max(len(k) + 2, 9), k) for k in KEYS)
    print(hdr)
    print("-" * len(hdr))
    for layer in ("ab", "ba"):
        c = layers[layer]
        for leg in ("armed", "baseline"):
            print("%6s %6d %9s" % (layer, c["games"], leg) + "".join(
                "%*d" % (max(len(k) + 2, 9), c["%s_%s" % (leg, k)]) for k in KEYS))
    print()
    tot = {leg: sum(layers[l]["%s_exclusive" % leg] for l in ("ab", "ba"))
           for leg in ("armed", "baseline")}
    print("EXCLUSIVE-DOMAIN DUST CASTS  armed %d  baseline %d"
          % (tot["armed"], tot["baseline"]))
    print("baseline > 0 falsifies the branch partition or the slot mapping,")
    print("NOT the fix (LIMIT 6) -- %d such row(s) below." % len(all_bugs))
    print("Both layers are printed because this estimator does NOT cancel side")
    print("bias (铁律 4(i-b)): a count that flips sign between them is noise.")
    if a.rows:
        for tag, rs in (("EXCLUSIVE", all_rows), ("INSTRUMENT-FAILURE", all_bugs)):
            if not rs:
                continue
            print()
            print("%s rows:" % tag)
            for r in sorted(rs, key=lambda r: (r["game"], r["t_cast"])):
                print("  %s %-3s %-8s %-22s idx=%-5s pid=%d slot=%d t=%8.2f "
                      "frame=%8.2f hp=%.3f pos=(%.0f,%.0f) d_pre=%s d_post=%s"
                      % (r["game"], r["layer"], r["leg"],
                         r["hero"].replace("npc_dota_hero_", ""), r["idx"],
                         r["pid"], r["slot"], r["t_cast"], r["t_frame"],
                         r["hp_pct"], r["x"], r["y"],
                         r["d_enemy_pre"], r["d_enemy_post"]))


if __name__ == "__main__":
    main()

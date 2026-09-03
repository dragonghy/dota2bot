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
  B3 -> no `item_radiance` DAMAGE tick lands on THE CASTER in [t-1.5, t+1.5].
        The shipped clause is `bot:HasModifier('modifier_item_radiance_debuff')`
        -- a per-frame test on the caster's own body -- so the carrier is the
        burn tick, not the draft (LIMIT 13; this used to be a whole-game team
        census and that census whitewashed one whole side, GH #445).
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
    while the combat log carried 20,167 `item_radiance` damage events.  The
    B3 exclusion no longer reads `items[]` at all (LIMIT 13), but the census it
    used to read is still computed, as the `b3_census_only` contrast column, so
    the two spellings stay pinned from both sides in the selfcheck.
10. `WasRecentlyDamagedByPlayer(id, 0.5)` IS PER-PLAYER, NOT PER-HERO-BODY: a
    player's summons and illusions carry their damage too, and those actors are
    not heroes in the combat log.  The B4 exclusion therefore takes ANY damage
    on the caster, not only `actor_hero` damage.
11. THE GATE CUTS BOTH WAYS.  Armed is NOT a subset of shipped here (the search
    seeds with `nil`, so the caller wins only by being found): a hero inside the
    shipped scan can LOSE to a nearer ally the armed scan reaches.  This script
    can only see the direction that produces a cast; the suppression direction
    is invisible to it and is not claimed either way.
12. *** THE EXCLUSIVE COLUMN CANNOT CORRECT THE MODEL IT IS DEFINED BY (GH
    #441).  `reachable_unarmed` is a hypothesis, and a cast from a slot it calls
    reachable `continue`s out BEFORE B2/B3/B4 are consulted -- so the one number
    that would discriminate the hypotheses, "how many casts from a REACHABLE
    slot survive all three exclusions", was never computed by any run.  The
    REACHABILITY FIT table (added 2026-09-03) computes the cascade for every
    slot and prints survivors/casts, which makes the model refutable: on the
    BASELINE leg, {slots with survivors} must be a subset of the hypothesis.
    It REFUTES ONLY.  A hypothesis calling every slot reachable is unrefutable
    here, an unrefuted hypothesis is not confirmed, and a slot with no survivors
    may simply be a slot nobody cast dust from -- read fit_casts beside it.  If
    every baseline slot carries survivors the reading is about B2/B3/B4, not
    about reachability.
13. *** B3 IS A PER-FRAME TEST ON THE CASTER, AND MODELLING IT AS A DRAFT
    CENSUS DELETED ONE WHOLE SIDE OF THE TABLE (GH #445).  The shipped clause
    is `bot:HasModifier('modifier_item_radiance_debuff')`
    (ability_item_usage_generic.lua:7326).  The first version asked instead
    whether the caster's ENEMY side EVER held a radiance -- a necessary
    condition, so the direction was safe, but on a MIRRORED-DRAFT corpus the
    radiance carrier is pinned to one physical team by construction (W40: all
    20,167 burn events from dire's own skeleton_king, radiant 0), which made
    the clause TRUE for every radiant caster in 46/64 games and FALSE for every
    dire one.  Result: `ba/baseline/radiant` read 0/11 and was quoted as
    "radiant is unreachable" when it was an erased row.  A census whose truth
    value is decided by the draft rather than by the frame is not a
    conservative version of a per-frame predicate -- it is a per-SIDE filter
    wearing one.
    The carrier now is the burn tick itself (`item_radiance` DAMAGE on the
    caster), which is the only radiance evidence this corpus is KNOWN to carry.
    Two consequences to read before quoting the new number:
      (a) THE WINDOW IS THE SLACK.  Radiance burns on a 1.0 s tick; B3_BURN_
          WINDOW is 1.5 s each way, a 50% margin, so a debuff applied just
          before the cast (first tick still pending) or lingering just after it
          is still caught.  Wider = more blocking = fewer survivors, which is
          the safe direction for LIMIT 6.  A debuff carried with NO tick inside
          3 s would invent a survivor; nothing in this corpus is known to
          produce one, and that is a stated assumption, not a measurement.
      (b) THE BETTER CARRIER IS NOT ASSUMED TO EXIST.  If the combat log emits
          MODIFIER_ADD/MODIFIER_REMOVE for `modifier_item_radiance_debuff`, the
          interval is exact and the window becomes unnecessary.  Whether it does
          is a corpus fact nobody here has bought, so this script COUNTS those
          events (`radiance_debuff_add` / `_remove`) and blocks on neither.
          The next run reads the count and decides; it does not guess.
      (c) `radiance_burn_ticks` IS THE DOMAIN PRICE OF THIS WHOLE CLAUSE.  If it
          is 0 over a corpus, B3 blocked nothing there and the table cannot tell
          "B3 never fired" from "the carrier is missing" -- the report says so
          in one loud line rather than printing a clean-looking zero.
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
# B3's carrier (LIMIT 13).  These two ARE combat-log spellings on purpose: the
# burn tick is a DAMAGE event's inflictor and the debuff is a MODIFIER_ADD's,
# neither is ever compared against snapshot `items[]`.
RADIANCE_BURN = "item_radiance"
RADIANCE_DEBUFF = "modifier_item_radiance_debuff"
B3_BURN_WINDOW = 1.5     # burn ticks at 1.0 s; 50% margin on each side
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


# --- REACHABILITY FIT (GH #441) ---------------------------------------------
# `reachable_unarmed` is a HYPOTHESIS about what the unarmed scan reaches, and
# the exclusive column is DEFINED by it, so no reading the script produced could
# ever correct it: a cast from a slot the hypothesis calls reachable `continue`s
# out before the three ungated exclusions are consulted.  The fit table asks the
# same corpus the reachability-agnostic question -- for EVERY slot, how many
# casts survive B2/B3/B4 -- which turns the model into something the data can
# refute.  The rule is one line: on the BASELINE leg, a slot with a surviving
# cast MUST be reachable, because the surviving cast has no ungated explanation
# left.  So {slots with baseline survivors} must be a SUBSET of the hypothesis.
#
# The three hypotheses on the table.  `AllyPIDs` (jmz_func.lua:11541) is a
# MODULE-LEVEL local filled on the first call with `GetTeamPlayers(GetTeam())`.
# If a Lua VM is per-team, the shipped model holds; if one VM serves both teams,
# whichever team calls first freezes the list for BOTH, and the unarmed scan of
# the other team walks the wrong numeric values.  Note that the ARMED leg is
# immune either way -- it reads the loop INDEX `i` (1..5 on an array table), not
# the values -- so this defect can only break the control, never the fix.
HYPOTHESES = {
    # own pids: radiant 0..4 -> slots 1..4 ; dire 5..9 -> slot 5 only
    "H0-shipped":             {RADIANT: (1, 2, 3, 4), DIRE: (5,)},
    # a radiant bot called first: both teams walk 0..4
    "H1-leak-radiant-cached": {RADIANT: (1, 2, 3, 4), DIRE: (1, 2, 3, 4)},
    # a dire bot called first: both teams walk 5..9
    "H2-leak-dire-cached":    {RADIANT: (5,), DIRE: (5,)},
}


def team_of(layer, leg):
    """Which team a (layer, leg) pair is.  ab == radiant armed, by definition."""
    if layer == "ab":
        return RADIANT if leg == "armed" else DIRE
    return DIRE if leg == "armed" else RADIANT


def refutations(baseline_survivors, hypothesis):
    """(team, slot, n) triples a hypothesis cannot explain.  Empty == survives.

    LIMIT 12: this test can only REFUTE.  A hypothesis that calls every slot
    reachable is unrefutable by it, and a hypothesis surviving here is not
    thereby confirmed -- absence of a surviving cast in a slot is also what a
    slot nobody cast dust from looks like (read the fit_casts row next to it).
    """
    out = []
    for team, per_slot in sorted(baseline_survivors.items()):
        for slot, n in sorted(per_slot.items()):
            if n > 0 and slot not in hypothesis[team]:
                out.append((team, slot, n))
    return out


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
    out = {leg: collections.Counter() for leg in ("armed", "baseline")}

    # B2 census: a Sand King anywhere in the draft disarms the exclusive column.
    sandking = any(k[0] == SANDKING for k in by_ent)
    # B3 census: which side ever holds a radiance.  NO LONGER AN EXCLUSION
    # (LIMIT 13) -- kept as the `b3_census_only` contrast column, which is what
    # measures how much of the table the old draft-wide rule was erasing.
    radiance_teams = set()
    for k, frames in by_ent.items():
        for s in frames:
            if RADIANCE in (s.get("items") or ()):
                radiance_teams.add(s["team"])
                break

    # B3 carrier: `item_radiance` burn ticks landing on each body, plus the
    # MODIFIER_ADD/REMOVE counts that would be the exact carrier if this corpus
    # turns out to emit them (LIMIT 13(b) -- counted, never blocked on).
    burn = collections.defaultdict(list)
    mod_events = collections.Counter()
    for e in events:
        et, inf = e.get("type"), e.get("inflictor")
        if et == "DAMAGE" and inf == RADIANCE_BURN:
            burn[e.get("target")].append(e["t"])
        elif inf == RADIANCE_DEBUFF and et in ("MODIFIER_ADD", "MODIFIER_REMOVE"):
            mod_events[(e.get("target"), et)] += 1
    for v in burn.values():
        v.sort()
    for (name, et), n in mod_events.items():
        got = key_of.get(name)
        if got is None:
            continue
        leg = "armed" if got[1] == armed_team else "baseline"
        out_key = ("radiance_debuff_add" if et == "MODIFIER_ADD"
                   else "radiance_debuff_remove")
        out[leg][out_key] += n
    for name, ticks in burn.items():
        got = key_of.get(name)
        if got is None:
            continue
        leg = "armed" if got[1] == armed_team else "baseline"
        out[leg]["radiance_burn_ticks"] += len(ticks)

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

        # REACHABILITY FIT (GH #441).  The three ungated exclusions are decided
        # here, for EVERY cast, BEFORE the reachability model gets a vote.  The
        # cascade below is left byte-for-byte as it was and simply reads this
        # answer, so every pre-existing column keeps its exact value
        # ([column-parity] in tests/test_slotdust_reachability_fit.py).
        # LIMIT 13: the CASTER's own burn decides B3, not the draft.  The old
        # draft census is still evaluated, but only as the contrast column that
        # says how many casts it was erasing.
        burning = any(abs(bt - e["t"]) <= B3_BURN_WINDOW
                      for bt in burn.get(e.get("actor"), ()))
        census = enemy_team in radiance_teams
        if census and not burning:
            out[leg]["b3_census_only"] += 1
        if burning and not census:
            out[leg]["b3_tick_no_census"] += 1
        blocked = ("b2" if sandking else
                   "b3" if burning else
                   "b4" if dmg else None)
        out[leg]["fit_casts_s%d" % slot] += 1
        if blocked is None:
            out[leg]["fit_survive_s%d" % slot] += 1

        if reachable_unarmed(team, slot):
            out[leg]["reachable_slot"] += 1
            continue
        out[leg]["unreachable_slot"] += 1
        if blocked == "b2":
            out[leg]["blocked_b2_sandking"] += 1
            continue
        if blocked == "b3":
            out[leg]["blocked_b3_radiance"] += 1
            continue
        if blocked == "b4":
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

    # --- B3, TIGHTENED TO THE CASTER'S OWN BURN (GH #445, LIMIT 13) ---------
    burn_tick = [{"t": 9.8, "type": "DAMAGE", "actor": "npc_dota_hero_h0",
                  "target": "npc_dota_hero_h5", "inflictor": RADIANCE_BURN,
                  "value": 60, "actor_hero": True, "target_hero": True}]
    res, _, _ = scan_game(build(DIRE, 5, events=burn_tick + cast), "dire")
    check("a burn tick ON THE CASTER blocks the cast (B3 is reachable)",
          res["armed"]["blocked_b3_radiance"] == 1
          and res["armed"]["exclusive"] == 0)
    # *** THE WHITEWASH (GH #445).  An enemy radiance in the DRAFT, with no burn
    # landing on this caster, used to block every cast that side threw for the
    # rest of the game -- which is how `ba/baseline/radiant` read 0/11 and got
    # quoted as "radiant is unreachable".
    res, _, _ = scan_game(build(DIRE, 5, events=cast,
                                enemy_items=["radiance"] + [""] * 8), "dire")
    check("an enemy radiance the caster is NOT burning from no longer blocks",
          res["armed"]["blocked_b3_radiance"] == 0
          and res["armed"]["exclusive"] == 1
          and res["armed"]["b3_census_only"] == 1)
    # The retired census is still computed, so LIMIT 9 stays pinned from both
    # sides: the snapshot spelling must reach the contrast column and the
    # combat-log spelling must NOT.
    res, _, _ = scan_game(build(DIRE, 5, events=cast,
                                enemy_items=["item_radiance"] + [""] * 8), "dire")
    check("the combat-log spelling is not the items[] spelling (LIMIT 9)",
          res["armed"]["b3_census_only"] == 0
          and res["armed"]["exclusive"] == 1)
    # The window is the slack (LIMIT 13(a)): a tick 1.5 s out still blocks, one
    # further out does not, and a tick AFTER the cast counts too (the debuff was
    # already on when the cast went out).
    late = [dict(burn_tick[0], t=11.5)]
    res, _, _ = scan_game(build(DIRE, 5, events=late + cast), "dire")
    check("a burn tick %.1f s AFTER the cast still blocks" % B3_BURN_WINDOW,
          res["armed"]["blocked_b3_radiance"] == 1)
    far = [dict(burn_tick[0], t=11.6)]
    res, _, _ = scan_game(build(DIRE, 5, events=far + cast), "dire")
    check("a tick outside the window does not block",
          res["armed"]["blocked_b3_radiance"] == 0
          and res["armed"]["exclusive"] == 1)
    # A burn on SOMEONE ELSE is not this caster's debuff.
    other = [dict(burn_tick[0], target="npc_dota_hero_h6")]
    res, _, _ = scan_game(build(DIRE, 5, events=other + cast), "dire")
    check("a burn tick on another hero does not block this caster",
          res["armed"]["blocked_b3_radiance"] == 0
          and res["armed"]["exclusive"] == 1)
    # LIMIT 13(c): the carrier's own domain price is counted, per leg.
    res, _, _ = scan_game(build(DIRE, 5, events=burn_tick + cast), "dire")
    check("the burn ticks are counted as the carrier's domain price",
          res["armed"]["radiance_burn_ticks"] == 1)
    # LIMIT 13(b): the exact carrier is COUNTED and never blocked on, so a
    # corpus that emits it says so instead of silently changing the answer.
    mod = [{"t": 9.0, "type": "MODIFIER_ADD", "actor": "npc_dota_hero_h0",
            "target": "npc_dota_hero_h5", "inflictor": RADIANCE_DEBUFF,
            "value": 0, "actor_hero": True, "target_hero": True}]
    res, _, _ = scan_game(build(DIRE, 5, events=mod + cast), "dire")
    check("a MODIFIER_ADD is counted but does NOT block (LIMIT 13(b))",
          res["armed"]["radiance_debuff_add"] == 1
          and res["armed"]["blocked_b3_radiance"] == 0
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

    # --- REACHABILITY FIT (GH #441, LIMIT 12) -------------------------------
    # The number the exclusive column structurally cannot produce: a cast from a
    # slot the hypothesis calls REACHABLE, carried through the same three
    # exclusions.  dire pid 9 == slot 5 is that slot on the dire leg.
    res, _, _ = scan_game(build(DIRE, 9, events=cast9), "dire")
    check("a REACHABLE-slot cast is put through B2/B3/B4 all the same",
          res["armed"]["fit_casts_s5"] == 1
          and res["armed"]["fit_survive_s5"] == 1
          and res["armed"]["exclusive"] == 0)
    dmg9 = [dict(dmg[0], target="npc_dota_hero_h9")]
    res, _, _ = scan_game(build(DIRE, 9, events=dmg9 + cast9), "dire")
    check("...and a blocked one is a cast but not a survivor",
          res["armed"]["fit_casts_s5"] == 1
          and res["armed"]["fit_survive_s5"] == 0)
    res, _, _ = scan_game(build(DIRE, 5, events=cast), "dire")
    check("the fit counts the UNREACHABLE slot too (same cast, both columns)",
          res["armed"]["fit_survive_s1"] == 1 and res["armed"]["exclusive"] == 1)

    check("team_of: ab is radiant-armed, so ab/baseline is dire",
          team_of("ab", "armed") == RADIANT and team_of("ab", "baseline") == DIRE
          and team_of("ba", "armed") == DIRE
          and team_of("ba", "baseline") == RADIANT)
    # The observed shape of GH #441: dire baseline survivors on slots 2/3/4.
    obs = {DIRE: {1: 0, 2: 5, 3: 2, 4: 9, 5: 0}, RADIANT: {s: 0 for s in SLOTS}}
    check("that shape REFUTES the shipped model",
          len(refutations(obs, HYPOTHESES["H0-shipped"])) == 3)
    check("...and H2 (dire-cached) with it",
          len(refutations(obs, HYPOTHESES["H2-leak-dire-cached"])) == 3)
    check("...while H1 (radiant-cached) survives it",
          refutations(obs, HYPOTHESES["H1-leak-radiant-cached"]) == [])
    # H1's own falsifier is the number no run has ever printed: dire slot 5.
    obs5 = {DIRE: dict(obs[DIRE]), RADIANT: obs[RADIANT]}
    obs5[DIRE][5] = 1
    check("a single dire slot-5 survivor would refute H1 as well",
          len(refutations(obs5, HYPOTHESES["H1-leak-radiant-cached"])) == 1)
    check("zero survivors everywhere refutes nothing (LIMIT 12: only refutes)",
          all(refutations({t: {s: 0 for s in SLOTS} for t in (RADIANT, DIRE)}, h)
              == [] for h in HYPOTHESES.values()))

    print("selfcheck: %d pass, %d fail" % tuple(ok))
    return 0 if ok[1] == 0 else 1


KEYS = ("dust_casts", "gungir_casts", "reachable_slot", "unreachable_slot",
        "blocked_b2_sandking", "blocked_b3_radiance", "blocked_b4_recent_damage",
        "ring_nonempty", "exclusive")

SLOTS = (1, 2, 3, 4, 5)
FIT_KEYS = tuple("fit_%s_s%d" % (w, s) for w in ("casts", "survive")
                 for s in SLOTS)

# LIMIT 13.  Deliberately NOT part of KEYS: those nine columns are the cascade,
# and `tests/test_slotdust_reachability_fit.py` compares every one of them
# against an independently transcribed oracle.  These five are diagnostics ABOUT
# the B3 clause -- what its carrier looks like in this corpus, and what the
# retired draft census would have blocked -- so they are reported separately.
B3_KEYS = ("radiance_burn_ticks", "radiance_debuff_add",
           "radiance_debuff_remove", "b3_census_only", "b3_tick_no_census")


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
            for k in KEYS + FIT_KEYS + B3_KEYS:
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

    # --- B3 CARRIER (GH #445, LIMIT 13) --------------------------------------
    # Printed BEFORE the fit table, because a zero here disqualifies every B3
    # reading below it and a reader who meets that fact afterwards has already
    # quoted the wrong number.
    print()
    print("B3 CARRIER -- the tightened clause reads the CASTER's own burn tick,")
    print("not a draft census.  `b3_census_only` is what the retired census was")
    print("blocking and this one is not (LIMIT 13).")
    hdr3 = "%6s %9s" % ("layer", "leg") + "".join(
        "%*s" % (max(len(k) + 2, 12), k) for k in B3_KEYS)
    print(hdr3)
    print("-" * len(hdr3))
    for layer in ("ab", "ba"):
        for leg in ("armed", "baseline"):
            print("%6s %9s" % (layer, leg) + "".join(
                "%*d" % (max(len(k) + 2, 12),
                         layers[layer]["%s_%s" % (leg, k)]) for k in B3_KEYS))
    ticks = sum(layers[l]["%s_radiance_burn_ticks" % leg]
                for l in ("ab", "ba") for leg in ("armed", "baseline"))
    adds = sum(layers[l]["%s_radiance_debuff_add" % leg]
               for l in ("ab", "ba") for leg in ("armed", "baseline"))
    if ticks == 0:
        print("*** CARRIER ABSENT: zero `item_radiance` DAMAGE ticks in this")
        print("*** corpus, so B3 blocked NOTHING here and this table cannot")
        print("*** tell that apart from a game with no radiance in it.  Do not")
        print("*** read the fit rows below as a B3 result (LIMIT 13(c)).")
    if adds:
        print("MODIFIER_ADD for %s is present (%d): the exact interval carrier"
              % (RADIANCE_DEBUFF, adds))
        print("exists in this corpus and the +/-%.1fs window can be retired."
              % B3_BURN_WINDOW)

    # --- REACHABILITY FIT (GH #441) -----------------------------------------
    # Both layers are registered per 铁律 4(i-a).  4(i-b) does NOT apply: the
    # reading here is a SUPPORT SET, not a magnitude -- one surviving cast
    # refutes and a thousand refute no harder -- and each team's baseline leg
    # lives in exactly one layer (dire baseline only in ab, radiant only in ba),
    # so there is no pooling step in which a side term could hide.
    print()
    print("REACHABILITY FIT -- casts / survivors of B2+B3+B4, by team slot")
    hdr2 = "%6s %9s %8s" % ("layer", "leg", "team") + "".join(
        "%10s" % ("slot%d" % s) for s in SLOTS)
    print(hdr2)
    print("-" * len(hdr2))
    baseline_survivors = {}
    for layer in ("ab", "ba"):
        c = layers[layer]
        for leg in ("armed", "baseline"):
            team = team_of(layer, leg)
            cells = []
            for s in SLOTS:
                cells.append("%10s" % ("%d/%d" % (
                    c["%s_fit_survive_s%d" % (leg, s)],
                    c["%s_fit_casts_s%d" % (leg, s)])))
            print("%6s %9s %8s" % (layer, leg,
                                   "radiant" if team == RADIANT else "dire")
                  + "".join(cells))
            if leg == "baseline":
                baseline_survivors.setdefault(team, {}).update(
                    {s: c["%s_fit_survive_s%d" % (leg, s)] for s in SLOTS})
    print()
    print("The ARMED leg reads the loop INDEX, so every slot is reachable there")
    print("under all three hypotheses; only the BASELINE rows discriminate.")
    for name in sorted(HYPOTHESES):
        bad = refutations(baseline_survivors, HYPOTHESES[name])
        if bad:
            print("  %-24s REFUTED by %s" % (name, ", ".join(
                "%s slot%d (%d survivor%s)"
                % ("radiant" if t == RADIANT else "dire", s, n,
                   "" if n == 1 else "s") for t, s, n in bad)))
        else:
            print("  %-24s not refuted by this corpus (LIMIT 12: not confirmed)"
                  % name)
    print("If EVERY baseline slot carries survivors, the reading is about the")
    print("three exclusions, not about reachability -- suspect B2/B3/B4 first.")

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

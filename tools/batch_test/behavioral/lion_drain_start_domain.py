#!/usr/bin/env python3
"""`liondrain` pre-flight corpus census: how often would the START guard fire?

WHAT THIS ANSWERS
-----------------
`liondrain` (hero_lion.lua:1084 `X.lion_IsDrainSafeToStart`) is the START-side
lever of the Lion Mana Drain pair; `liondrainstop` (measured by the sibling
tool `lion_drain_census.py`) is the RELEASE side.  Neither has ever been armed,
so every reading here is COUNTERFACTUAL -- the corpus is the gate-OFF base
rate, and the question is the one the stream now asks before every admission:

    on real frames, how many decisions would arming this id actually change?

The five preceding pre-flights (`wkreincarnmp`, `axeblink`, `cmrself`,
`esaftershock`, `zusultx`) each died a different death, and the charter now
lists five disposal classes.  This tool is written so that each of them is a
column rather than an afterthought:

  * EMPTY / structurally-vetoed-elsewhere (`wkreincarnmp`): does a WEAKER
    condition on the same branch already refuse every frame the gate wants to
    refuse?  Here the branch preconditions are printed per start (section
    "precondition" below) instead of argued.
  * DOMAIN-NOT-REACHED (`axeblink`): counted directly -- `in_domain` is
    evaluated on the frames where the action really happened.
  * CARRIER-UNAVAILABLE (`#88`): `games_with_lion` vs `games` is the first
    line of the summary.
  * DOMAIN-REACHED-BUT-VANISHING (`cmrself`, `esaftershock`): episodes and
    games are reported next to raw frame counts, because a single long
    episode is one decision, not N.
  * CONSUMER-SIDE-UNREACHABLE (`zusultx`): the universe below is restricted to
    starts that can only have come from the two branches the gate actually
    sits above -- see UNIVERSE.

UNIVERSE (the zusultx question: does the action pass through this gate?)
-----------------------------------------------------------------------
`X.ConsiderE` has four ways to return a Mana Drain, in source order:

    1. mana refill off an ENEMY CREEP            (`bot:GetNearbyCreeps`)  -- above the gate
    2. burst a suspicious ILLUSION                                        -- above the gate
       ... `if X.IsOtherAbilityFullyCastable() or nSkillLV <= 1 then return 0`
       ... `if not X.lion_IsDrainSafeToStart( bot ) then return 0`        <-- THE GATE
    3. teamfight drain    (`J.IsInTeamFight( bot, 1000 )`)                -- below the gate
    4. fight drain        (`J.IsGoingOnSomeone( bot )`)                   -- below the gate

Offline a cast is visible as a `MODIFIER_ADD` of `modifier_lion_mana_drain`
with `actor == lion`, and -- unlike the snapshot stream, which holds heroes
only -- the MODIFIER event stream carries creep and neutral targets too.  So
branch 1 is separable by the target's own name and is EXCLUDED (counted, not
dropped silently).  Branch 2 targets an enemy hero and is NOT separable by
target class, so it is bounded instead: `J.IsSuspiciousIllusion` can only ever
answer true for an enemy who HAS illusions, so a roster with no illusion-making
hero makes branch 2 structurally unreachable, and the roster is printed.  Both
surviving branches also require `npcEnemy:GetMana() > 200`, which IS in the
snapshot stream, so every start reports the target's mana as a cross-check on
the attribution rather than as an assumption.

PREDICATE FIDELITY (all-stream rule U.1.1 -- every threshold verbatim from the
gate source, and mirrored by tests/test_detector_source_constants.py):
  * `X.nEDrainDangerRadius = 500`                    (hero_lion.lua:1082)
  * `hBot:WasRecentlyDamagedByAnyHero( 2.0 )`        (hero_lion.lua:1096)
  * `J.GetNearbyHeroes( hBot, 500, true, ... )`      (hero_lion.lua:1101)
`WasRecentlyDamagedByAnyHero` is not captured by the dumper (charter "工具坑"),
same proxy as the sibling tool: a DAMAGE event with `target == lion` and
`actor_hero == true` inside `(t-2.0, t]`.  The proxy leans SUPERSET in exactly
one direction (it cannot see damage the engine attributes to a non-hero source
that the engine still credits to a hero), so an empty domain measured through
it is stronger than a full one.

SAMPLING DISCIPLINE (charter 2026-08-21T10:51Z, and the interval trap of
`esaftershock` §甲):
  * start times come from the EVENT stream (0.1s), NOT the snapshot grid, so
    they do not move with `-interval`.
  * the PREDICATE is evaluated on SNAPSHOTS and therefore IS grid limited.
    Every enemy read is "the last snapshot <= t" and is dropped when that
    snapshot is older than one measured interval (never a fixed offset, never
    a +/-tolerance window).  The measured interval is printed with every run,
    because frame counts are not comparable across intervals -- EPISODE counts
    are, which is why the headline is stated in episodes.

TWO KNOWN CORPUS TRAPS, both handled and both counted:
  * `#69` same-name multiple entities: the main entity is the one with the
    EARLIEST first snapshot (never `hp_max`, never frame count).  Illusions of
    an enemy hero therefore cannot masquerade as that enemy standing next to
    Lion.
  * `#78` corpse leak: `hp > 0` can read a hero alive for up to ~0.4s after its
    DEATH, which here would manufacture an enemy inside the 500u ring, i.e. a
    FALSE in-domain positive.  Instrumented AFTER full qualification (the
    instrumentation point decides the number's meaning) and printed.

WHAT THIS IS NOT: an execution check.  No wave has armed `liondrain`, so a
non-empty domain here licenses buying condition (a), nothing more.

Usage:
    lion_drain_start_domain.py tl/*.json [--json out.json] [--episode-gap 8.0]
    lion_drain_start_domain.py --verify        # offline self-test, no corpus
"""
from __future__ import annotations

import argparse
import bisect
import glob
import json
import math
import os
import sys

DANGER_RADIUS = 500.0        # hero_lion.lua:1082  X.nEDrainDangerRadius
DAMAGE_WINDOW = 2.0          # hero_lion.lua:1096  WasRecentlyDamagedByAnyHero(2.0)
BRANCH_MANA_FLOOR = 200.0    # hero_lion.lua:823/840  npcEnemy:GetMana() > 200
EPISODE_GAP = 8.0            # two starts closer than this are one decision
LEAK_S = 0.5                 # #78: corpse frames observed up to ~0.4s after DEATH
DEATH_WINDOW = 12.0          # "did the channel get him killed" read-out window
LION = "npc_dota_hero_lion"
DRAIN_MOD = "modifier_lion_mana_drain"
DRAIN_ABILITY = "lion_mana_drain"
OTHER_ABILITIES = ("lion_impale", "lion_voodoo", "lion_finger_of_death")

# Heroes whose kit can put an ILLUSION of themselves on the map, i.e. the only
# enemies for whom branch 2 (`J.IsSuspiciousIllusion`) can ever answer true.
# Frame-external anchor: kit lists, not the replay.  Used only to BOUND branch
# 2's reachability, never to attribute a start to it.
ILLUSION_HEROES = {
    "npc_dota_hero_naga_siren", "npc_dota_hero_phantom_lancer",
    "npc_dota_hero_terrorblade", "npc_dota_hero_chaos_knight",
    "npc_dota_hero_arc_warden", "npc_dota_hero_vengefulspirit",
    "npc_dota_hero_spectre", "npc_dota_hero_shadow_demon",
    "npc_dota_hero_dark_seer", "npc_dota_hero_grimstroke",
    "npc_dota_hero_monkey_king", "npc_dota_hero_wraith_king",
    "npc_dota_hero_juggernaut",
}


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


class Corpus:
    """One game's timeline, reduced to what this census needs.

    Deliberately the same reduction as `lion_drain_census.py`: the two tools
    measure the two ends of the same channel and must not disagree about which
    entity is Lion or when he was hit.
    """

    def __init__(self, d):
        self.events = sorted(d["events"], key=lambda e: e["t"])
        self.t_end = max((e["t"] for e in self.events), default=float("inf"))
        first_seen, by_key = {}, {}
        for s in d["snapshots"]:
            if s["t"] > self.t_end:
                continue          # dumper keeps emitting frozen post-game rows
            key = (s["hero"], s.get("idx"))
            by_key.setdefault(key, []).append(s)
            if key not in first_seen or s["t"] < first_seen[key]:
                first_seen[key] = s["t"]
        main_idx = {}
        for (hero, idx), t0 in first_seen.items():          # #69
            cur = main_idx.get(hero)
            if cur is None or t0 < cur[1]:
                main_idx[hero] = (idx, t0)
        self.entity_count = {}
        for hero, idx in [k for k in by_key]:
            self.entity_count[hero] = self.entity_count.get(hero, 0) + 1
        self.snaps = {}
        for (hero, idx), rows in by_key.items():
            if main_idx.get(hero, (None, None))[0] != idx:
                continue
            rows.sort(key=lambda s: s["t"])
            self.snaps[hero] = rows
        self.times = {h: [s["t"] for s in rows] for h, rows in self.snaps.items()}
        self.team = {h: rows[0]["team"] for h, rows in self.snaps.items() if rows}
        self.interval = self._interval()
        self.deaths = {}
        for e in self.events:
            if e["type"] == "DEATH" and e.get("target_hero") \
                    and str(e.get("target", "")).startswith("npc_dota_hero_"):
                self.deaths.setdefault(e["target"], []).append(e["t"])
        self.lion_hits = sorted(e["t"] for e in self.events
                                if e["type"] == "DAMAGE" and e.get("target") == LION
                                and e.get("actor_hero"))

    def _interval(self):
        rows = self.snaps.get(LION) or next(iter(self.snaps.values()), [])
        ts = [s["t"] for s in rows]
        gaps = sorted(round(b - a, 3) for a, b in zip(ts, ts[1:]))
        return gaps[len(gaps) // 2] if gaps else None

    def last_snap_le(self, hero, t):
        ts = self.times.get(hero)
        if not ts:
            return None
        i = bisect.bisect_right(ts, t + 1e-9) - 1
        return self.snaps[hero][i] if i >= 0 else None

    def damaged_recently(self, t):
        i = bisect.bisect_right(self.lion_hits, t + 1e-9)
        j = bisect.bisect_left(self.lion_hits, t - DAMAGE_WINDOW)
        return i > j

    def just_died(self, hero, t):
        return any(td <= t < td + LEAK_S for td in self.deaths.get(hero, ()))

    def died_within(self, hero, t, window):
        return any(t <= td <= t + window for td in self.deaths.get(hero, ()))


def ability(snap, name):
    for a in snap.get("abilities", ()):
        if a.get("name") == name:
            return a
    return None


def starts(c):
    """Every Mana Drain start, classified by target class.

    Branch 1 (creep mana refill) is separable here and only here: the MODIFIER
    event stream carries non-hero targets, the snapshot stream does not.

    Each start is paired with its `MODIFIER_REMOVE` so the channel it opened is
    available: the START guard's counterfactual is bounded by the channel it
    prevents, and a channel that was already over cannot have been worth
    preventing.
    """
    lion_team = c.team.get(LION)
    out, open_at = [], {}
    for e in c.events:
        if e.get("inflictor") != DRAIN_MOD or e.get("actor") != LION:
            continue
        tgt = e.get("target")
        if e["type"] == "MODIFIER_ADD":
            row = {
                "t": e["t"], "target": tgt,
                "target_hero": bool(e.get("target_hero")),
                "t_end": None, "span": None,
                # an enemy HERO target is the only class the gated branches make
                "gated_branch": bool(e.get("target_hero")
                                     and c.team.get(tgt) is not None
                                     and c.team.get(tgt) != lion_team),
            }
            out.append(row)
            open_at.setdefault(tgt, []).append(row)
        elif e["type"] == "MODIFIER_REMOVE" and open_at.get(tgt):
            row = open_at[tgt].pop(0)
            row["t_end"] = e["t"]
            row["span"] = round(e["t"] - row["t"], 2)
    return out


def predicate(c, t):
    """(true?, qualifying enemies, leak_only) -- the gate's two halves at time t.

    Shared by BOTH levers on purpose: `X.lion_ShouldStopDrain` is
    `X.lion_IsDrainSafeToStart` with the polarity flipped and nothing else
    changed (hero_lion.lua:1112 vs :1084), so the sibling-coverage column below
    is not an approximation of the release lever -- it IS the release lever's
    predicate, evaluated one snapshot later.
    """
    s = c.last_snap_le(LION, t)
    if s is None or (c.interval and t - s["t"] > c.interval + 1e-6):
        return None, [], False
    if s["hp"] <= 0 or not c.damaged_recently(t):
        return False, [], False
    lion_team = c.team.get(LION)
    near, leak_only = [], True
    for hero in c.snaps:
        if hero == LION or c.team.get(hero) == lion_team:
            continue
        es = c.last_snap_le(hero, t)
        if not es or es["hp"] <= 0:
            continue
        if c.interval and t - es["t"] > c.interval + 1e-6:
            continue                                  # stale read for this enemy
        if dist((s["x"], s["y"]), (es["x"], es["y"])) > DANGER_RADIUS:
            continue
        near.append(hero)
        if not c.just_died(hero, es["t"]):             # #78, instrumented AFTER
            leak_only = False
    return bool(near), near, (bool(near) and leak_only)


def sibling_cut(c, st):
    """When would `liondrainstop` have cut this channel?

    The release lever runs on the FIRST line of `X.SkillsComplement`
    (hero_lion.lua:199), i.e. ABOVE the `J.CanNotUseAbility` early return, so it
    is evaluated on every think tick while the channel runs -- a channel whose
    predicate is already true at the start is cut on the next tick.  Offline the
    resolution is the sampling interval, which OVERSTATES the surviving channel:
    the in-game bound is one think tick.
    """
    if st["t_end"] is None:
        return None
    for s in c.snaps.get(LION, ()):
        if s["t"] < st["t"] or s["t"] > st["t_end"]:
            continue
        hit, _, _ = predicate(c, s["t"])
        if hit:
            return round(s["t"], 2)
    return None


def classify(c, st):
    """Evaluate the gate predicate on the frame the cast really happened."""
    st["in_domain"] = False
    st["stale"] = False
    st["leak_only"] = False
    st["near"] = []
    st["target_mp"] = None
    st["others_castable_cd0"] = None
    st["drain_level"] = None
    st["lion_hp_pct"] = None
    st["sibling_first_cut"] = None
    st["surviving_channel"] = None
    st["stop_only"] = False
    st["lion_died_after"] = c.died_within(LION, st["t"], DEATH_WINDOW)

    s = c.last_snap_le(LION, st["t"])
    if s is None or (c.interval and st["t"] - s["t"] > c.interval + 1e-6):
        st["stale"] = True
        return st
    st["lion_hp_pct"] = round(s.get("hp_pct", 0.0), 3)

    # --- branch preconditions, read not assumed (the wkreincarnmp question) ---
    a = ability(s, DRAIN_ABILITY)
    st["drain_level"] = a.get("level") if a else None
    # `X.IsOtherAbilityFullyCastable()` is `IsFullyCastable` on Q/W/R, which is
    # cooldown AND mana.  Mana costs are a frame-external anchor and the stream
    # has been burned by bad anchors (esaftershock §乙), so only the ANCHOR-FREE
    # half is reported: how many of Q/W/R are learned and off cooldown.  Zero
    # means the branch is reachable without needing any anchor at all.
    st["others_castable_cd0"] = sum(
        1 for n in OTHER_ABILITIES
        for ab in [ability(s, n)]
        if ab and ab.get("level", 0) > 0 and (ab.get("cd") or 0) <= 0)

    ts = c.last_snap_le(st["target"], st["t"]) if st["target_hero"] else None
    if ts is not None:
        st["target_mp"] = ts.get("mp")

    hit, near, leak_only = predicate(c, st["t"])
    st["in_domain"] = bool(hit)
    st["near"] = near
    st["leak_only"] = leak_only

    # --- the sibling question (new with this pre-flight) -------------------
    # `liondrainstop` is ALREADY in the eligible set, and it runs the identical
    # predicate on every think tick of the channel.  So a start the START guard
    # refuses is a decision the RELEASE guard also takes, one tick later -- the
    # start lever's EXCLUSIVE value is only what happens inside that tick.  The
    # column below separates the two: `sibling_first_cut` is when the release
    # lever would have fired, and `stop_only` marks channels that start clean
    # and turn unsafe, which is the class ONLY the release lever can reach.
    st["sibling_first_cut"] = sibling_cut(c, st)
    st["surviving_channel"] = (round(st["t_end"] - st["sibling_first_cut"], 2)
                               if st["t_end"] is not None
                               and st["sibling_first_cut"] is not None else None)
    st["stop_only"] = bool(st["sibling_first_cut"] is not None and not st["in_domain"])
    return st


def episodes(rows, gap=EPISODE_GAP):
    """Consecutive in-domain starts closer than `gap` are ONE decision.

    cmrself/esaftershock both had their headline halved by this: a frame count
    over-states a domain whenever one situation produces several casts.
    """
    out, cur = [], []
    for r in sorted(rows, key=lambda r: r["t"]):
        if cur and r["t"] - cur[-1]["t"] > gap:
            out.append(cur)
            cur = []
        cur.append(r)
    if cur:
        out.append(cur)
    return out


def census(tl, tag):
    c = Corpus(tl)
    if LION not in c.snaps:
        return {"tag": tag, "has_lion": False}
    lion_team = c.team[LION]
    enemies = sorted(h for h, t in c.team.items() if t != lion_team)
    rows = [classify(c, st) for st in starts(c)]
    # Cross-check on the universe itself: the dumper also emits an ABILITY event
    # at the cast instant.  If a cast could fail to place the modifier (blocked,
    # target dies in the cast point) the modifier stream would UNDER-count the
    # decisions the gate gets asked about.  Measured, not assumed -- on the
    # 2026-08-20 corpus the two streams agree exactly (73 and 73 casts, 27 and
    # 27 on enemy heroes), so the modifier stream is used and this stays a
    # tripwire.
    ab = [e for e in c.events
          if e["type"] == "ABILITY" and e.get("actor") == LION
          and e.get("inflictor") == DRAIN_ABILITY]
    ab_enemy_hero = [e for e in ab if e.get("target_hero")
                     and c.team.get(e.get("target")) not in (None, lion_team)]
    gated = [r for r in rows if r["gated_branch"]]
    dom = [r for r in gated if r["in_domain"]]
    return {
        "tag": tag, "has_lion": True, "interval": c.interval, "t_end": c.t_end,
        "enemies": enemies,
        "illusion_capable_enemies": sorted(set(enemies) & ILLUSION_HEROES),
        "multi_entity_enemies": sorted(h for h in enemies
                                       if c.entity_count.get(h, 1) > 1),
        "starts_all": len(rows),
        "starts_ability_events": len(ab),
        "starts_ability_enemy_hero": len(ab_enemy_hero),
        "starts_creep_or_neutral": sum(1 for r in rows if not r["target_hero"]),
        "starts_gated_branch": len(gated),
        "in_domain": len(dom),
        "in_domain_leak_only": sum(1 for r in dom if r["leak_only"]),
        "episodes": len(episodes(dom)),
        "stale": sum(1 for r in gated if r["stale"]),
        "rows": gated,
    }


def summarise(games):
    lion = [g for g in games if g["has_lion"]]
    dom_rows = [r for g in lion for r in g["rows"] if r["in_domain"]]
    gated_rows = [r for g in lion for r in g["rows"]]
    return {
        "games": len(games),
        "games_with_lion": len(lion),
        "games_with_domain": sum(1 for g in lion if g["in_domain"]),
        "intervals": sorted(set(g["interval"] for g in lion)),
        "starts_all": sum(g["starts_all"] for g in lion),
        "starts_ability_events": sum(g["starts_ability_events"] for g in lion),
        "starts_ability_enemy_hero": sum(g["starts_ability_enemy_hero"] for g in lion),
        "starts_creep_or_neutral": sum(g["starts_creep_or_neutral"] for g in lion),
        "starts_gated_branch": len(gated_rows),
        "in_domain": len(dom_rows),
        "in_domain_leak_only": sum(1 for r in dom_rows if r["leak_only"]),
        "episodes": sum(g["episodes"] for g in lion),
        "stale": sum(g["stale"] for g in lion),
        "illusion_capable_enemies": sorted(set(
            h for g in lion for h in g["illusion_capable_enemies"])),
        "multi_entity_enemies": sorted(set(
            h for g in lion for h in g["multi_entity_enemies"])),
        "target_mp_le_floor": sum(1 for r in gated_rows
                                  if r["target_mp"] is not None
                                  and r["target_mp"] <= BRANCH_MANA_FLOOR),
        "others_cd0_nonzero": sum(1 for r in gated_rows
                                  if r["others_castable_cd0"]),
        "death_after_in_domain": sum(1 for r in dom_rows if r["lion_died_after"]),
        "death_after_out_domain": sum(1 for r in gated_rows
                                      if not r["in_domain"] and r["lion_died_after"]),
        # --- sibling coverage: what the START lever adds over `liondrainstop`
        "sibling_covers": sum(1 for r in dom_rows
                              if r["sibling_first_cut"] is not None),
        "sibling_surviving_channel": [r["surviving_channel"] for r in dom_rows
                                      if r["surviving_channel"] is not None],
        "stop_only": sum(1 for r in gated_rows if r["stop_only"]),
        # --- the counterfactual is bounded by the channel that gets prevented
        "spans_in_domain": [r["span"] for r in dom_rows if r["span"] is not None],
        "in_domain_span_lt_interval": sum(
            1 for g in games if g.get("has_lion")
            for r in g["rows"] if r["in_domain"] and r["span"] is not None
            and g["interval"] and r["span"] < g["interval"]),
    }


def report(games, out=sys.stdout):
    s = summarise(games)
    p = lambda *a: print(*a, file=out)
    p("=== liondrain START-guard domain (COUNTERFACTUAL: id never armed) ===")
    p("corpus: %d games, %d with Lion, sampling interval(s) %s"
      % (s["games"], s["games_with_lion"], s["intervals"]))
    p("")
    p("%-28s %-9s %-7s %-7s %-6s %-5s" %
      ("game", "starts", "creep", "gated", "domain", "ep"))
    for g in games:
        if not g["has_lion"]:
            continue
        p("%-28s %-9d %-7d %-7d %-6d %-5d"
          % (g["tag"], g["starts_all"], g["starts_creep_or_neutral"],
             g["starts_gated_branch"], g["in_domain"], g["episodes"]))
    p("")
    p("UNIVERSE  %d starts total; %d on creeps/neutrals (branch 1, ABOVE the gate,"
      % (s["starts_all"], s["starts_creep_or_neutral"]))
    p("          excluded); %d on enemy heroes = the gated branches."
      % s["starts_gated_branch"])
    p("          branch-2 (illusion) reachability: illusion-capable enemies %s;"
      % (s["illusion_capable_enemies"] or "NONE in any roster"))
    p("          enemies with >1 entity in the snapshot stream: %s"
      % (s["multi_entity_enemies"] or "none"))
    p("          attribution cross-check -- starts whose target held <= %d mana"
      % BRANCH_MANA_FLOOR)
    p("          (both gated branches require > %d): %d"
      % (BRANCH_MANA_FLOOR, s["target_mp_le_floor"]))
    p("          cross-check on the universe -- ABILITY events for %s: %d total,"
      % (DRAIN_ABILITY, s["starts_ability_events"]))
    p("          %d on enemy heroes (must equal %d / %d above)"
      % (s["starts_ability_enemy_hero"], s["starts_all"], s["starts_gated_branch"]))
    p("          starts with a learned, off-cooldown Q/W/R (the branch above the"
      " gate should")
    p("          have returned 0 first, mana permitting): %d" % s["others_cd0_nonzero"])
    p("")
    p("DOMAIN    %d starts / %d EPISODE / %d of %d Lion games  =  %.2f ep per Lion game"
      % (s["in_domain"], s["episodes"], s["games_with_domain"], s["games_with_lion"],
         (s["episodes"] / s["games_with_lion"]) if s["games_with_lion"] else 0.0))
    p("          of which resting only on a #78 corpse frame: %d"
      % s["in_domain_leak_only"])
    p("          stale (no fresh Lion snapshot at the cast): %d" % s["stale"])
    p("")
    p("OUTCOME   Lion dead within %.0fs of the start:  in-domain %d/%d, "
      "out-of-domain %d/%d"
      % (DEATH_WINDOW, s["death_after_in_domain"], s["in_domain"],
         s["death_after_out_domain"], s["starts_gated_branch"] - s["in_domain"]))
    p("          channel spans actually prevented (s): %s"
      % (s["spans_in_domain"] or "-"))
    p("          of them shorter than one sampling interval: %d"
      % s["in_domain_span_lt_interval"])
    p("")
    p("SIBLING   `liondrainstop` (ALREADY eligible, identical predicate, runs on")
    p("          SkillsComplement's first line) also cuts %d of the %d in-domain"
      % (s["sibling_covers"], s["in_domain"]))
    p("          channels; channel left running after ITS cut (s): %s"
      % (s["sibling_surviving_channel"] or "-"))
    p("          -- offline resolution is the sampling interval; in game the")
    p("          bound is one think tick, so these are UPPER bounds.")
    p("          starts the release lever reaches and the start lever cannot")
    p("          (clean start, turns unsafe mid-channel): %d" % s["stop_only"])
    return s


def _verify():
    """Offline self-test on hand-built timelines; no corpus, no S3."""
    n = [0]

    def ok(cond, what):
        n[0] += 1
        if not cond:
            print("FAIL: %s" % what)
            sys.exit(1)

    def snap(hero, t, x, y, hp=500, team=2, idx=1, mp=400, abil=None):
        return {"hero": hero, "t": t, "x": x, "y": y, "hp": hp,
                "hp_pct": hp / 500.0, "mp": mp, "team": team, "idx": idx,
                "abilities": abil if abil is not None else [
                    {"name": DRAIN_ABILITY, "level": 2, "cd": 0},
                    {"name": "lion_impale", "level": 2, "cd": 5.0},
                    {"name": "lion_voodoo", "level": 1, "cd": 5.0},
                    {"name": "lion_finger_of_death", "level": 0, "cd": 0}]}

    LUNA = "npc_dota_hero_luna"
    grid = [round(0.5 * i, 1) for i in range(0, 60)]

    def build(lion_xy, luna_xy, hits, add_t, target=LUNA, target_hero=True,
              deaths=(), luna_hp=500, end_t="auto"):
        snaps = []
        for t in grid:
            snaps.append(snap(LION, t, *lion_xy, team=3))
            snaps.append(snap(LUNA, t, *luna_xy, team=2, hp=luna_hp))
        ev = [{"t": t, "type": "DAMAGE", "actor": LUNA, "target": LION,
               "inflictor": "attack", "value": 50, "actor_hero": True,
               "target_hero": True} for t in hits]
        ev.append({"t": add_t, "type": "MODIFIER_ADD", "actor": LION,
                   "target": target, "inflictor": DRAIN_MOD, "value": 1,
                   "actor_hero": True, "target_hero": target_hero})
        if end_t == "auto":
            end_t = add_t + 3.0
        if end_t is not None:
            ev.append({"t": end_t, "type": "MODIFIER_REMOVE", "actor": LION,
                       "target": target, "inflictor": DRAIN_MOD, "value": 1,
                       "actor_hero": True, "target_hero": target_hero})
        for h, t in deaths:
            ev.append({"t": t, "type": "DEATH", "actor": LUNA, "target": h,
                       "inflictor": "attack", "value": 1, "actor_hero": True,
                       "target_hero": True})
        ev.append({"t": 29.5, "type": "PLAYERSTATS", "actor": LION,
                   "target": LION, "value": 0})
        return {"snapshots": snaps, "events": ev}

    # 1. both predicate halves true, enemy at 300u -> in domain
    g = census(build((0, 0), (300, 0), [9.0], 10.0), "t1")
    ok(g["starts_gated_branch"] == 1, "t1 universe")
    ok(g["in_domain"] == 1 and g["episodes"] == 1, "t1 in domain")

    # 2. same geometry, no recent hero damage -> out of domain
    g = census(build((0, 0), (300, 0), [1.0], 10.0), "t2")
    ok(g["in_domain"] == 0, "t2 damage half must bind")

    # 3. damaged, but the enemy sits outside the 500u ring -> out of domain
    g = census(build((0, 0), (700, 0), [9.0], 10.0), "t3")
    ok(g["in_domain"] == 0, "t3 radius half must bind")

    # 4. boundary: exactly 500u is NOT outside (`> DANGER_RADIUS` refuses)
    g = census(build((0, 0), (500, 0), [9.0], 10.0), "t4")
    ok(g["in_domain"] == 1, "t4 500u is inside the ring")

    # 5. the damage window is half-open on the old side: a hit 2.0s before the
    #    cast still counts, one 2.6s before does not
    ok(census(build((0, 0), (300, 0), [8.0], 10.0), "t5a")["in_domain"] == 1,
       "t5 hit at exactly -2.0s counts")
    ok(census(build((0, 0), (300, 0), [7.4], 10.0), "t5b")["in_domain"] == 0,
       "t5 hit at -2.6s does not")

    # 6. a CREEP target is branch 1, above the gate -- excluded from the universe
    g = census(build((0, 0), (300, 0), [9.0], 10.0,
                     target="npc_dota_creep_goodguys_ranged", target_hero=False),
               "t6")
    ok(g["starts_all"] == 1 and g["starts_gated_branch"] == 0, "t6 creep excluded")
    ok(g["starts_creep_or_neutral"] == 1, "t6 creep counted")
    ok(g["in_domain"] == 0, "t6 creep start cannot be in domain")

    # 7. #78: an enemy whose only qualifying frame is a corpse frame is still
    #    counted in domain but flagged leak_only, never silently dropped
    g = census(build((0, 0), (300, 0), [9.0], 10.0,
                     deaths=((LUNA, 9.8),)), "t7")
    ok(g["in_domain"] == 1 and g["in_domain_leak_only"] == 1, "t7 leak flagged")

    # 8. episode collapsing: three casts inside one situation are ONE decision
    tl = build((0, 0), (300, 0), [9.0, 11.0, 13.0], 10.0)
    for t in (12.0, 14.0):
        tl["events"].append({"t": t, "type": "MODIFIER_ADD", "actor": LION,
                             "target": LUNA, "inflictor": DRAIN_MOD, "value": 1,
                             "actor_hero": True, "target_hero": True})
    g = census(tl, "t8")
    ok(g["in_domain"] == 3 and g["episodes"] == 1, "t8 three casts, one episode")

    # 9. ... and two casts a long way apart are two decisions
    tl = build((0, 0), (300, 0), [9.0, 24.0], 10.0)
    tl["events"].append({"t": 25.0, "type": "MODIFIER_ADD", "actor": LION,
                         "target": LUNA, "inflictor": DRAIN_MOD, "value": 1,
                         "actor_hero": True, "target_hero": True})
    g = census(tl, "t9")
    ok(g["in_domain"] == 2 and g["episodes"] == 2, "t9 two episodes")

    # 10. #69: an illusion sharing the enemy's name must not be read as the
    #     enemy standing next to Lion.  The illusion is the LATER first
    #     snapshot, so the far-away main entity wins and the domain stays empty.
    tl = build((0, 0), (900, 0), [9.0], 10.0)
    for t in grid[10:]:
        tl["snapshots"].append(snap(LUNA, t, 100, 0, team=2, idx=77))
    g = census(tl, "t10")
    ok(g["in_domain"] == 0, "t10 illusion must not qualify the ring")
    ok(g["multi_entity_enemies"] == [LUNA], "t10 multi-entity reported")

    # 11. attribution cross-checks are read, not assumed
    tl = build((0, 0), (300, 0), [9.0], 10.0, luna_hp=500)
    for s in tl["snapshots"]:
        if s["hero"] == LUNA:
            s["mp"] = 100
    g = census(tl, "t11")
    ok(g["rows"][0]["target_mp"] == 100, "t11 target mana reported")
    ok(summarise([g])["target_mp_le_floor"] == 1, "t11 below-floor counted")

    # 12. an off-cooldown Impale is reported (the branch above the gate should
    #     have taken the frame first), but never silently drops the row
    tl = build((0, 0), (300, 0), [9.0], 10.0)
    for s in tl["snapshots"]:
        if s["hero"] == LION:
            s["abilities"] = [{"name": DRAIN_ABILITY, "level": 2, "cd": 0},
                              {"name": "lion_impale", "level": 2, "cd": 0},
                              {"name": "lion_voodoo", "level": 1, "cd": 5.0},
                              {"name": "lion_finger_of_death", "level": 0, "cd": 0}]
    g = census(tl, "t12")
    ok(g["rows"][0]["others_castable_cd0"] == 1, "t12 off-cd sibling reported")
    ok(g["in_domain"] == 1, "t12 row kept")

    # 13. a game without Lion is carrier-unavailable, not domain-empty
    tl = build((0, 0), (300, 0), [9.0], 10.0)
    tl["snapshots"] = [s for s in tl["snapshots"] if s["hero"] != LION]
    ok(census(tl, "t13")["has_lion"] is False, "t13 no Lion")

    # 14. outcome column: a death inside the window is attributed, one outside
    #     the window is not
    ok(census(build((0, 0), (300, 0), [9.0], 10.0,
                    deaths=((LION, 15.0),)), "t14a")["rows"][0]["lion_died_after"],
       "t14 death at +5s counted")
    ok(not census(build((0, 0), (300, 0), [9.0], 10.0,
                        deaths=((LION, 25.0),)), "t14b")["rows"][0]["lion_died_after"],
       "t14 death at +15s not counted")

    # 15. a dead enemy (hp<=0, outside the leak shadow) never qualifies the ring
    tl = build((0, 0), (300, 0), [9.0], 10.0)
    for s in tl["snapshots"]:
        if s["hero"] == LUNA and s["t"] >= 5.0:
            s["hp"] = 0
            s["hp_pct"] = 0.0
    g = census(tl, "t15")
    ok(g["in_domain"] == 0, "t15 corpse hp<=0 must not qualify")

    # 16. an ALLY hero target is not a gated-branch start either
    tl = build((0, 0), (300, 0), [9.0], 10.0)
    for s in tl["snapshots"]:
        if s["hero"] == LUNA:
            s["team"] = 3
    g = census(tl, "t16")
    ok(g["starts_gated_branch"] == 0, "t16 ally target excluded")

    # 17. summarise/report run end to end on a mixed corpus
    games = [census(build((0, 0), (300, 0), [9.0], 10.0), "a"),
             census(build((0, 0), (900, 0), [9.0], 10.0), "b")]
    s = summarise(games)
    ok(s["games_with_lion"] == 2 and s["in_domain"] == 1
       and s["games_with_domain"] == 1, "t17 summary")
    import io
    buf = io.StringIO()
    report(games, out=buf)
    ok("DOMAIN" in buf.getvalue(), "t17 report renders")

    # 18. the constants are the shipped ones (mirrored again in
    #     tests/test_detector_source_constants.py against the Lua itself)
    ok(DANGER_RADIUS == 500.0 and DAMAGE_WINDOW == 2.0, "t18 constants")

    # 19. SIBLING COVERAGE -- the column this pre-flight turns on.  A start
    #     whose predicate is already true is a channel `liondrainstop` cuts on
    #     its first tick, so the start lever's exclusive value is one tick.
    g = census(build((0, 0), (300, 0), [9.0], 10.0, end_t=15.0), "t19")
    r = g["rows"][0]
    ok(r["in_domain"] and r["span"] == 5.0, "t19 in domain, 5s channel")
    ok(r["sibling_first_cut"] == 10.0, "t19 release lever cuts at the first tick")
    ok(r["surviving_channel"] == 5.0, "t19 surviving channel measured")
    ok(not r["stop_only"], "t19 not release-only")
    ok(summarise([g])["sibling_covers"] == 1, "t19 counted as covered")

    # 20. ... and the complementary class: a channel that STARTS clean and
    #     turns unsafe is out of the start lever's domain and reachable only by
    #     the release lever.  Damage lands at 12.0, after the 10.0 start.
    g = census(build((0, 0), (300, 0), [12.0], 10.0, end_t=15.0), "t20")
    r = g["rows"][0]
    ok(not r["in_domain"], "t20 start is clean")
    ok(r["stop_only"] and r["sibling_first_cut"] == 12.0, "t20 release-only class")
    ok(summarise([g])["stop_only"] == 1, "t20 counted")

    # 21. an unterminated channel (no MODIFIER_REMOVE, e.g. the game ends)
    #     must not fabricate a cut or crash
    g = census(build((0, 0), (300, 0), [9.0], 10.0, end_t=None), "t21")
    r = g["rows"][0]
    ok(r["span"] is None and r["sibling_first_cut"] is None, "t21 open channel")
    ok(r["in_domain"], "t21 still classified")

    # 22. a channel shorter than the sampling interval is counted separately:
    #     preventing it cannot have changed anything observable
    g = census(build((0, 0), (300, 0), [9.0], 10.0, end_t=10.2), "t22")
    ok(g["rows"][0]["span"] == 0.2, "t22 sub-interval span")
    ok(summarise([g])["in_domain_span_lt_interval"] == 1, "t22 counted")

    print("lion_drain_start_domain --verify: %d asserts OK" % n[0])


def main():
    global EPISODE_GAP
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*", help="<tag>.json timelines")
    ap.add_argument("--json", help="write the full per-start rows here")
    ap.add_argument("--episode-gap", type=float, default=EPISODE_GAP)
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    if a.verify:
        _verify()
        return
    EPISODE_GAP = a.episode_gap
    paths = []
    for t in a.timelines:
        paths.extend(sorted(glob.glob(t)) or [t])
    if not paths:
        ap.error("no timelines given")
    games = []
    for p in paths:
        with open(p) as fh:
            games.append(census(json.load(fh), os.path.basename(p)[:-5]))
    s = report(games)
    if a.json:
        with open(a.json, "w") as fh:
            json.dump({"summary": s, "games": games}, fh, indent=1)


if __name__ == "__main__":
    main()

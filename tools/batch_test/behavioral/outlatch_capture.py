#!/usr/bin/env python3
"""outlatch / outpost-capture channel reader.

WHAT IT MEASURES
  Two different things that live in the same file
  (`bots/mode_outpost_generic.lua`) and must not be mixed up:

  (1) `outlatch` (mode_outpost_generic.lua:79) -- the soak candidate.  Shipped,
      `DidWeGetOutpost = true` runs unconditionally after the first
      `GetUnitList` sweep, so ONE empty sweep kills the whole mode for that bot
      for the rest of the game.  Armed, the latch records the postcondition
      (`#Outposts > 0`) and the sweep retries once per game second.
      OBSERVABLE CONSEQUENCE, and the only one this reader can buy: a bot that
      never got a non-empty sweep can never reach `Think()`'s
      `Action_UseAbilityOnEntity(hAbilityCapture, ...)`, so it can never emit an
      `ability_capture` cast.  A cast therefore PROVES that bot's `Outposts`
      table was non-empty; on the shipped leg it proves the FIRST sweep
      succeeded.  ⚠️ The converse is NOT observable: "no cast" is consistent
      with an empty sweep AND with every other reason the mode never bid
      (enemy tier-2 still up, `IsSuitableToCaptureOutpost` false, another mode
      out-bidding it).  The domain of `outlatch` -- "the first sweep came back
      empty" -- is NOT in the dump, so a cast census is an UPPER bound on
      liveness and says nothing about the gate's own effect size.

  (2) The capture channel itself -- shipped default behaviour, NOT gated by
      anything.  `Think()` re-issues the capture order on every think tick that
      gets past `J.Utils.IsBotThinkingMeaningfulAction`, with no
      `bot:IsChanneling()` guard (`mode_farm_generic.lua:1260` has one; this
      file does not).  A re-issue restarts the 6 s channel, so the attempt is
      aborted and the hero stands on the outpost for nothing.

WHAT IT READS
  Per game, from the dumper timeline:
    events  ABILITY / inflictor `ability_capture`            -> a cast
    events  MODIFIER_ADD/REMOVE `modifier_watch_tower_capturing`
                                                             -> a channel attempt
    buildings name `watch_tower`, field `team`               -> ownership flips
    snapshots                                                -> the frame track
  COMPLETION IS A GROUP PROPERTY, NOT AN ATTEMPT PROPERTY (GH #609)
  ⚠️ This changed 2026-09-07.  Until then an attempt was COMPLETE when its own
  channel lasted >= --complete-s (default 5.0), and that is WRONG in a way that
  is invisible in the aggregate: capture progress on one outpost is ADDITIVE
  across simultaneous casters.  Two heroes channelling together fill the bar in
  roughly half the time, and finishing it removes the modifier from BOTH on the
  same frame -- so a per-hero length test records every hitch-hiker as an
  abort.  On the W52 corpus (85 games, 4 seeds) that was 11/113 attempts
  (~10%), and 11/11 of them sat inside multi-caster groups.

  So: a group is one CONTIGUOUS COVERAGE INTERVAL on one outpost -- a maximal
  stretch during which at least one channel is open -- and the quantity
  compared with the threshold is CASTER-SECONDS, the integral of the number of
  open channels over that stretch.  Every member of a group shares the group's
  verdict, because the bar they filled is one bar.  The flag is `--complete-cs`
  (default 5.8); `--complete-s` is REFUSED rather than reinterpreted, because a
  saved command line meaning "5.0 seconds of one hero" must not silently start
  meaning "5.0 caster-seconds of a group".

  The threshold is NOT asserted and it is NOT the game's channel time copied
  into a constant.  It is CHECKED against ground truth on every run: a capture
  that actually finished flips the outpost's `team` field, so `verify_floor()`
  pairs each GROUP with the ownership flips that follow it and prints the two
  clusters it separates.  On W52 the separation is clean and wide: every
  flipping group is >= 5.8 caster-seconds (5.8, 5.9, 6.0), and the largest
  non-flipping group is 5.3 -- a wider empty band than the 4.4/5.2 one the old
  per-attempt floor sat in.  ⚠️ Two exceptions are pre-registered UNDECIDABLE
  and do NOT define the band's endpoints: a chaos_knight who re-issued the
  order 12 times (`20260907_003641_slot2`) flipped its outpost off groups of
  2.8 and 3.1 caster-seconds, and this dump cannot say whether the last 3.1 s
  channel bought it or whether progress simply never cleared across the 0.1 s
  seam between two re-issues.  ⚠️ An empty band is an empty band, not a
  measurement of the endpoint: any threshold inside 5.3-5.8 reproduces this
  corpus exactly, so 5.8 is "the low edge of the flipping cluster", never "the
  value the corpus picked out".  `--dump-groups` prints every group's
  caster-seconds with its flip status so a new corpus can re-verify the band
  before the number is reused; `--dump-durations` still prints raw per-attempt
  lengths.

WHAT IT WILL NOT DO
  It will not attribute a cast-count difference to `outlatch`.  Cast counts are
  a side-biased estimator (iron rule 4(i-b)): in the corpus this was written
  for, the ab and ba strata REVERSE (armed 22 vs base 1 on the radiant-armed
  leg; armed 2 vs base 27 on the dire-armed leg) and the common factor is the
  SIDE, not the arm.  Both strata are always printed, unpooled, for exactly
  that reason.  The abort rate, by contrast, is a within-leg ratio and it comes
  out the same on both legs -- which is the evidence that the channel defect is
  a shipped default, not an armed-id artefact.

USAGE
  outlatch_capture.py <sweep_out_dir> [<sweep_out_dir> ...]
  outlatch_capture.py --selfcheck
Exit: 0 ok / 1 a selfcheck case failed / 2 could not run (bad input).
"""
# Mutation stand: tools/agent/mutstand_outlatch_capture.sh (M8/M9/M10 cover the
# grouping key, the caster-second integral, and the threshold band).

import argparse
import collections
import glob
import json
import os
import sys

CAPTURE_ABILITY = "ability_capture"
CAPTURE_MODIFIER = "modifier_watch_tower_capturing"
WATCH_TOWER = "watch_tower"
# Caster-seconds, not seconds.  See the group-property note in the docstring.
DEFAULT_COMPLETE_CS = 5.8
# Two attempts by the same hero separated by less than this are one visit to
# the outpost.  Episode grouping only shapes the narrative rows; the strata
# table below is computed from raw attempts and does not depend on it.
EPISODE_GAP_S = 5.0

RADIANT, DIRE = 2, 3
# 'unk' carries attempts whose actor game.teams could not resolve.  It is a
# bucket, not a leg, and it is never added to either of the other two.
LEGS = ("armed", "base", "unk")


def _armed_team(side):
    if side == "radiant":
        return RADIANT
    if side == "dire":
        return DIRE
    raise ValueError("unknown side %r" % (side,))


def read_game(timeline, armed_team, complete_cs=DEFAULT_COMPLETE_CS):
    """One game -> {casts, attempts, groups, episodes, flips}.

    `timeline` is a parsed dumper timeline dict.  Every attempt is tagged with
    the leg ('armed'/'base') of the hero that cast it, resolved through
    game.teams -- never through slot order, which is not a leg.
    """
    teams = timeline.get("game", {}).get("teams", {})
    events = timeline.get("events", [])

    def leg_of(actor):
        team = teams.get(actor)
        if team is None:
            return None
        return "armed" if team == armed_team else "base"

    casts = []
    for e in events:
        if e.get("type") == "ABILITY" and e.get("inflictor") == CAPTURE_ABILITY:
            casts.append({"t": e["t"], "actor": e["actor"], "leg": leg_of(e["actor"])})

    # Channel attempts.  ADD/REMOVE are per-actor: a global open-slot would
    # splice two heroes' channels into one bogus attempt whenever they overlap.
    open_by_actor = {}
    attempts = []
    for e in events:
        if e.get("inflictor") != CAPTURE_MODIFIER:
            continue
        actor = e.get("actor")
        if e.get("type") == "MODIFIER_ADD":
            open_by_actor[actor] = (e["t"], e.get("target"))
        elif e.get("type") == "MODIFIER_REMOVE" and actor in open_by_actor:
            t0, outpost = open_by_actor.pop(actor)
            attempts.append({
                "actor": actor, "t0": t0, "t1": e["t"], "dur": e["t"] - t0,
                "outpost": outpost or e.get("target"), "leg": leg_of(actor),
            })
    # A channel still open at the last event (game ended mid-channel) is NOT
    # counted either way: calling it aborted would invent a defect out of the
    # recording boundary.
    unclosed = len(open_by_actor)

    # Completion, per the group note in the module docstring: one bar, one
    # verdict.  A group is one CONTIGUOUS COVERAGE INTERVAL on one outpost --
    # a maximal stretch during which at least one channel is open -- and the
    # compared quantity is the integral of the number of open channels over it.
    #
    # ⚠️ Not "the attempts that end on the same frame", which was this fix's
    # first cut and is too narrow: co-casters need not stop together.  In
    # `20260907_063731_slot4` zuus channelled South 1544.3-1549.2 while
    # skeleton_king rode along 1547.0-1548.0 and left early; the outpost
    # flipped (team 2 -> 3 at the 1554.4 sample) off 5.9 caster-seconds that a
    # removal-frame key splits into a 4.9 "abort" and a 1.0 "abort".
    grouped = collections.OrderedDict()
    for a in attempts:
        # An attempt whose outpost did not resolve is kept on its OWN key.
        # Falling back to a shared sentinel would let two towers' channels
        # overlap into one bar and read as a completion neither earned.
        key = a["outpost"] or ("?unresolved", a["actor"])
        grouped.setdefault(key, []).append(a)
    groups = []
    for key, lst in grouped.items():
        # Opens sort BEFORE closes at an equal timestamp, so a hero who joins
        # on the exact frame another finishes is inside that bar, not the sole
        # member of a zero-length one of his own (the 20260907_003647_slot4
        # queenofpain shape).  A real gap, even 0.1 s, still splits.
        marks = sorted([(a["t0"], 1, a) for a in lst] + [(a["t1"], -1, a) for a in lst],
                       key=lambda m: (m[0], -m[1]))
        n_open, prev_t, caster_s, members, t0 = 0, None, 0.0, [], None
        for t, delta, a in marks:
            if n_open:
                caster_s += n_open * (t - prev_t)
            if delta > 0:
                if not n_open:
                    t0, caster_s, members = t, 0.0, []
                members.append(a)
            n_open += delta
            prev_t = t
            if not n_open and members:
                complete = caster_s >= complete_cs
                for m in members:
                    m["complete"] = complete
                    m["group_caster_s"] = caster_s
                    m["group_n"] = len(members)
                groups.append({
                    "outpost": key if isinstance(key, str) else "?unresolved",
                    "t0": t0, "t1": t, "caster_s": caster_s, "n": len(members),
                    "complete": complete, "actors": [m["actor"] for m in members],
                })
                members = []
    groups.sort(key=lambda g: g["t1"])
    unresolved_outpost = sum(1 for a in attempts if not a["outpost"])

    # Outpost ownership.  Keyed by rounded position: entity indices are not
    # stable keys (this stream's 2026-09-04 finding), positions are, because
    # outposts are map-static.
    series = collections.defaultdict(list)
    for b in timeline.get("buildings", []):
        if b.get("name") == WATCH_TOWER:
            series[(round(b["x"]), round(b["y"]))].append((b["t"], b["team"]))
    flips = []
    for pos, samples in series.items():
        samples.sort()
        if not samples:
            continue
        prev = samples[0][1]
        for t, team in samples[1:]:
            if team != prev:
                flips.append({"pos": pos, "t": t, "from": prev, "to": team})
                prev = team

    # Episodes: per hero, attempts closer than EPISODE_GAP_S are one visit.
    per_hero = collections.defaultdict(list)
    for a in attempts:
        per_hero[a["actor"]].append(a)
    episodes = []
    for actor, lst in per_hero.items():
        lst.sort(key=lambda a: a["t0"])
        cur = [lst[0]]
        for a in lst[1:]:
            if a["t0"] - cur[-1]["t1"] < EPISODE_GAP_S:
                cur.append(a)
            else:
                episodes.append(_episode(actor, cur))
                cur = [a]
        episodes.append(_episode(actor, cur))

    return {"casts": casts, "attempts": attempts, "groups": groups,
            "episodes": episodes, "flips": flips, "unclosed": unclosed,
            "unresolved_outpost": unresolved_outpost}


def _episode(actor, attempts):
    return {
        "actor": actor,
        "leg": attempts[0]["leg"],
        "t0": attempts[0]["t0"],
        "t1": attempts[-1]["t1"],
        "span": attempts[-1]["t1"] - attempts[0]["t0"],
        "n": len(attempts),
        "completed": sum(1 for a in attempts if a["complete"]),
        "longest": max(a["dur"] for a in attempts),
        "wasted_s": sum(a["dur"] for a in attempts if not a["complete"]),
    }


def verify_floor(games, complete_cs=DEFAULT_COMPLETE_CS, window_s=6.0):
    """Cross-check --complete-cs against ground truth (outpost ownership flips).

    A capture that finished flips the outpost's `team`; buildings are sampled
    every 5 s, so the flip is observed up to one sample AFTER the channel ends
    -- hence `window_s`.  Pairs GROUPS, not attempts: the flip is one event and
    the bar is one bar, so pairing per attempt double-counts a multi-caster
    capture and then calls each member a separate disagreement.  Returns the
    two clusters the threshold is separating plus the disagreements, and never
    decides anything on its own: a caller that wants a verdict reads
    `misfiled` / `orphan_flips`.

    ⚠️ Flips are keyed by POSITION and groups by the outpost NAME the combat
    log carries, and this function does not join the two -- a flip anywhere on
    the map inside the window counts.  On this corpus the two outposts are
    never captured within 6 s of each other, so the join would change nothing;
    on a corpus where they are, this check gets looser, never stricter.
    """
    produced, no_flip, orphan_flips = [], [], []
    for g in games:
        r = g["result"]
        for grp in r["groups"]:
            hit = [f for f in r["flips"] if -0.5 <= f["t"] - grp["t1"] <= window_s]
            (produced if hit else no_flip).append(grp)
        for f in r["flips"]:
            if not any(-0.5 <= f["t"] - grp["t1"] <= window_s for grp in r["groups"]):
                orphan_flips.append((g["game"], f))
    # A group the threshold calls complete but that produced no flip, or one it
    # calls aborted that did -- either is the threshold disagreeing with the
    # game.  Both halves are kept as GROUPS too, so a caller can ask the
    # question GH #609 turned on: are any of the survivors multi-caster?
    mis_hi = [grp for grp in no_flip if grp["caster_s"] >= complete_cs]
    mis_lo = [grp for grp in produced if grp["caster_s"] < complete_cs]
    return {"produced": sorted(g["caster_s"] for g in produced),
            "no_flip": sorted(g["caster_s"] for g in no_flip),
            "produced_groups": produced, "no_flip_groups": no_flip,
            "orphan_flips": orphan_flips,
            "misfiled": ([g["caster_s"] for g in mis_hi],
                         [g["caster_s"] for g in mis_lo]),
            "misfiled_groups": (mis_hi, mis_lo)}


def hero_track(timeline, hero, t0, t1):
    """Frame rows for one real hero over [t0,t1] -- the frame-by-frame half.

    ⚠️ Goes through `entities.frames_by_hero`, NOT through a name filter on
    `snapshots`.  A name filter is wrong and it is wrong QUIETLY: in
    `20260905_010205_slot7` the name `npc_dota_hero_luna` carries 21 snapshot
    rows at t=1348.5 -- one live hero at hp_pct 1.00 and twenty corpse/duplicate
    entity streams at 0.00 -- so a name-keyed track prints twenty phantom rows
    per second and the reader picks whichever one sorted first.  That helper
    already exists for exactly this (its docstring pins the lina case); this
    reader must not grow a second, worse copy of it.
    """
    from entities import canon, frames_by_hero
    frames, _teams = frames_by_hero(timeline)
    # frames_by_hero keys by canon name ('luna'), not by the engine name.
    # Looking it up with 'npc_dota_hero_luna' returns nothing and an empty
    # track reads exactly like "the hero was not there".
    rows = []
    for s in frames.get(canon(hero), ()):
        if t0 <= s["t"] <= t1:
            rows.append({"t": s["t"], "x": s["x"], "y": s["y"],
                         "hp_pct": s["hp_pct"], "level": s.get("level")})
    rows.sort(key=lambda r: r["t"])
    return rows


def scan_dirs(dirs, complete_cs=DEFAULT_COMPLETE_CS):
    per_key = collections.defaultdict(collections.Counter)
    games = []
    for d in dirs:
        manifest = os.path.join(d, "games_manifest.jsonl")
        if not os.path.exists(manifest):
            raise SystemExit("no games_manifest.jsonl under %s" % d)
        for line in open(manifest):
            row = json.loads(line)
            tl_path = os.path.join(d, "timelines", row["game"] + ".timeline.json")
            if not os.path.exists(tl_path):
                continue
            timeline = json.load(open(tl_path))
            armed = _armed_team(row["side"])
            r = read_game(timeline, armed, complete_cs)
            stratum = "ab" if row["side"] == "radiant" else "ba"
            games.append({"run": os.path.basename(d.rstrip("/")), "game": row["game"],
                          "seed": row["seed"], "stratum": stratum, "result": r,
                          "path": tl_path})
            # 'unk' is a THIRD bucket, never folded into either leg: an actor
            # game.teams cannot resolve made those casts on some team, and
            # quietly filing it under 'base' is how a leg reads 70 attempts
            # where the corpus has 67 (this stream, 2026-09-07).  Carrying it
            # openly is what lets the three buckets be reconciled against a
            # total computed some other way.
            for leg in LEGS:
                key = (row["seed"], stratum, leg)
                want = None if leg == "unk" else leg
                per_key[key]["games"] += 0
                per_key[key]["attempts"] += sum(1 for a in r["attempts"] if a["leg"] == want)
                per_key[key]["completed"] += sum(1 for a in r["attempts"]
                                                 if a["leg"] == want and a["complete"])
                per_key[key]["casts"] += sum(1 for c in r["casts"] if c["leg"] == want)
                per_key[key]["wasted_s"] += sum(a["dur"] for a in r["attempts"]
                                                if a["leg"] == want and not a["complete"])
            per_key[(row["seed"], stratum, "armed")]["games"] += 1
    return games, per_key


def selfcheck():
    """Synthetic frames only -- no corpus, no S3, no AWS."""
    checks, failures = 0, []

    def ck(name, cond):
        nonlocal checks
        checks += 1
        if not cond:
            failures.append(name)

    def tl(events, buildings=None, teams=None):
        return {"game": {"teams": teams or {"h_a": RADIANT, "h_b": DIRE}},
                "events": events, "buildings": buildings or [], "snapshots": []}

    def ev(t, typ, infl, actor, target=None):
        return {"t": t, "type": typ, "inflictor": infl, "actor": actor,
                "target": target}

    # 1. one clean completed channel
    r = read_game(tl([ev(10.0, "ABILITY", CAPTURE_ABILITY, "h_a"),
                      ev(10.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a"),
                      ev(16.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_a")]), RADIANT)
    ck("1a one attempt", len(r["attempts"]) == 1)
    ck("1b complete", r["attempts"][0]["complete"] is True)
    ck("1c leg armed", r["attempts"][0]["leg"] == "armed")
    ck("1d one cast", len(r["casts"]) == 1)
    ck("1e episode not wasteful", r["episodes"][0]["wasted_s"] == 0)

    # 2. FALSE-POSITIVE CONTROL: a completed channel must never be read as an
    #    abort, and a game with no capture activity at all must read zero.
    r = read_game(tl([]), RADIANT)
    ck("2a empty game: no attempts", r["attempts"] == [])
    ck("2b empty game: no casts", r["casts"] == [])
    ck("2c empty game: no episodes", r["episodes"] == [])
    ck("2d empty game: no flips", r["flips"] == [])

    # 3. the defect shape: three aborted attempts, one episode, zero completed
    evs = []
    for t in (100.0, 103.0, 106.0):
        evs += [ev(t, "ABILITY", CAPTURE_ABILITY, "h_b"),
                ev(t, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_b"),
                ev(t + 2.5, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_b")]
    r = read_game(tl(evs), RADIANT)
    ck("3a three attempts", len(r["attempts"]) == 3)
    ck("3b none complete", sum(1 for a in r["attempts"] if a["complete"]) == 0)
    ck("3c one episode", len(r["episodes"]) == 1)
    ck("3d episode n=3", r["episodes"][0]["n"] == 3)
    ck("3e leg base (h_b is dire, armed=radiant)", r["episodes"][0]["leg"] == "base")
    ck("3f wasted 7.5s", abs(r["episodes"][0]["wasted_s"] - 7.5) < 1e-9)

    # 4. two heroes channelling at the same time must not be spliced together.
    #    Interleaved ADD(a) ADD(b) REMOVE(a) REMOVE(b): a global open-slot would
    #    read one 3s attempt; per-actor reads 4s and 4s.
    r = read_game(tl([ev(0.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a"),
                      ev(1.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_b"),
                      ev(4.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_a"),
                      ev(5.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_b")]), RADIANT)
    ck("4a two attempts", len(r["attempts"]) == 2)
    ck("4b durations 4 and 4", sorted(round(a["dur"], 3) for a in r["attempts"]) == [4.0, 4.0])
    ck("4c legs differ", set(a["leg"] for a in r["attempts"]) == {"armed", "base"})

    # 5. a channel left open at the recording boundary is counted as neither
    r = read_game(tl([ev(0.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a")]), RADIANT)
    ck("5a no attempt from an unclosed channel", r["attempts"] == [])
    ck("5b unclosed reported", r["unclosed"] == 1)

    # 6. ownership flips, with a control that a stable outpost reads zero
    b = [{"t": t, "name": WATCH_TOWER, "x": 3392, "y": -448, "team": 3,
          "hp": 450, "hp_pct": 1, "alive": True} for t in (0.0, 5.0, 10.0)]
    b += [{"t": 15.0, "name": WATCH_TOWER, "x": 3392, "y": -448, "team": 2,
           "hp": 450, "hp_pct": 1, "alive": True}]
    b += [{"t": t, "name": WATCH_TOWER, "x": -4096, "y": -448, "team": 2,
           "hp": 450, "hp_pct": 1, "alive": True} for t in (0.0, 5.0, 10.0, 15.0)]
    r = read_game(tl([], buildings=b), RADIANT)
    ck("6a exactly one flip", len(r["flips"]) == 1)
    ck("6b flip 3->2 at t=15", r["flips"][0]["t"] == 15.0 and r["flips"][0]["to"] == 2)
    ck("6c stable outpost contributes nothing", all(f["pos"] == (3392, -448) for f in r["flips"]))

    # 7. the completion floor is a parameter, not a baked constant
    evs = [ev(0.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a"),
           ev(3.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_a")]
    ck("7a 3s aborted at floor 5.0",
       read_game(tl(evs), RADIANT, 5.0)["attempts"][0]["complete"] is False)
    ck("7b 3s complete at floor 2.0",
       read_game(tl(evs), RADIANT, 2.0)["attempts"][0]["complete"] is True)

    # 8. leg resolution goes through game.teams, and an unknown hero is not
    #    silently filed under 'base'
    r = read_game(tl([ev(0.0, "ABILITY", CAPTURE_ABILITY, "h_ghost")]), RADIANT)
    ck("8a unknown actor -> leg None", r["casts"][0]["leg"] is None)

    # 9. verify_floor: a 6s channel followed by a flip is 'produced'; a 6s
    #    channel with no flip is a MISFILE the floor must surface, not swallow.
    def game_of(events, buildings):
        return {"game": "g", "path": None,
                "result": read_game(tl(events, buildings=buildings), RADIANT)}

    good = game_of([ev(10.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a"),
                    ev(16.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_a")],
                   [{"t": 15.0, "name": WATCH_TOWER, "x": 1, "y": 1, "team": 3,
                     "hp": 1, "hp_pct": 1, "alive": True},
                    {"t": 20.0, "name": WATCH_TOWER, "x": 1, "y": 1, "team": 2,
                     "hp": 1, "hp_pct": 1, "alive": True}])
    v = verify_floor([good])
    ck("9a flip-producing attempt in 'produced'", v["produced"] == [6.0])
    ck("9b no orphan flip", v["orphan_flips"] == [])
    ck("9c nothing misfiled", v["misfiled"] == ([], []))

    lonely = game_of([ev(10.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a"),
                      ev(16.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_a")], [])
    v = verify_floor([lonely])
    ck("9d long channel with no flip is not 'produced'", v["produced"] == [])
    ck("9e and it is reported as misfiled", v["misfiled"][0] == [6.0])

    # 9f FALSE-POSITIVE CONTROL for the window: a flip 30s after the channel is
    #    a different capture and must NOT be credited to this attempt.
    late = game_of([ev(10.0, "MODIFIER_ADD", CAPTURE_MODIFIER, "h_a"),
                    ev(16.0, "MODIFIER_REMOVE", CAPTURE_MODIFIER, "h_a")],
                   [{"t": 20.0, "name": WATCH_TOWER, "x": 1, "y": 1, "team": 3,
                     "hp": 1, "hp_pct": 1, "alive": True},
                    {"t": 50.0, "name": WATCH_TOWER, "x": 1, "y": 1, "team": 2,
                     "hp": 1, "hp_pct": 1, "alive": True}])
    v = verify_floor([late])
    ck("9f flip outside the window not credited", v["produced"] == [])
    ck("9g and that flip is reported as an orphan", len(v["orphan_flips"]) == 1)

    # ---------------------------------------------------------------- GH #609
    # 10. THE GROUP RULE.  Capture progress is additive across simultaneous
    #     casters, so completion belongs to the bar, not to one hero's channel.
    NORTH, SOUTH = "#DOTA_OutpostName_North", "#DOTA_OutpostName_South"

    def chan(t0, t1, actor, outpost):
        return [ev(t0, "MODIFIER_ADD", CAPTURE_MODIFIER, actor, outpost),
                ev(t1, "MODIFIER_REMOVE", CAPTURE_MODIFIER, actor, outpost)]

    # 10a THE CASE THE OLD FLOOR GOT WRONG: two 3.0 s channels on one outpost,
    #     ending on the same frame.  Each member alone is below ANY single-hero
    #     floor the tool has ever shipped (5.0), and the group finished the bar.
    r = read_game(tl(chan(100.0, 103.0, "h_a", NORTH)
                     + chan(100.0, 103.0, "h_b", NORTH)), RADIANT)
    ck("10a two overlapping 3.0s channels are ONE group", len(r["groups"]) == 1)
    ck("10b the group is complete", r["groups"][0]["complete"] is True)
    ck("10c caster-seconds is the INTEGRAL (3+3=6), not the max (3)",
       abs(r["groups"][0]["caster_s"] - 6.0) < 1e-9)
    ck("10d every member inherits the group verdict",
       all(a["complete"] is True for a in r["attempts"]))
    ck("10e and every member alone is below the old 5.0 single-hero floor",
       all(a["dur"] < 5.0 for a in r["attempts"]))

    # 10f/10g THE GROUPING KEY NEEDS BOTH DIMENSIONS.  Same frame at DIFFERENT
    #     outposts is two bars; same outpost at DIFFERENT frames is two bars.
    r = read_game(tl(chan(100.0, 103.0, "h_a", NORTH)
                     + chan(100.0, 103.0, "h_b", SOUTH)), RADIANT)
    ck("10f same frame, different outposts -> two groups", len(r["groups"]) == 2)
    ck("10g neither is complete", all(not g["complete"] for g in r["groups"]))
    r = read_game(tl(chan(100.0, 103.0, "h_a", NORTH)
                     + chan(200.0, 203.0, "h_b", NORTH)), RADIANT)
    ck("10h same outpost, different frames -> two groups", len(r["groups"]) == 2)

    # 10i AN ATTEMPT WITH NO OUTPOST IS NEVER POOLED.  A shared sentinel key
    #     would merge two towers' channels and manufacture a completion.
    r = read_game(tl(chan(100.0, 103.0, "h_a", None)
                     + chan(100.0, 103.0, "h_b", None)), RADIANT)
    ck("10j unresolved outposts stay in singleton groups", len(r["groups"]) == 2)
    ck("10k and they are counted, not swallowed", r["unresolved_outpost"] == 2)

    # 10l THE ZERO-LENGTH ATTEMPT (20260907_003647_slot4 queenofpain): she was
    #     added and removed on the frame lich's 5.9 s channel completed.
    #     Calling that an abort invents a defect out of a timestamp collision.
    r = read_game(tl(chan(919.7, 925.6, "h_a", NORTH)
                     + chan(925.6, 925.6, "h_b", NORTH)), RADIANT)
    ck("10m the 0.0s attempt joins the completing group", len(r["groups"]) == 1)
    ck("10n and is not recorded as an abort",
       all(a["complete"] is True for a in r["attempts"]))

    # 10o verify_floor pairs GROUPS with flips, not attempts: a two-caster
    #     capture is ONE success, and per-attempt pairing would report the same
    #     flip twice and then call each member a separate disagreement.
    b = [{"t": 105.0, "name": WATCH_TOWER, "x": 1, "y": 1, "team": 3,
          "hp": 1, "hp_pct": 1, "alive": True},
         {"t": 106.0, "name": WATCH_TOWER, "x": 1, "y": 1, "team": 2,
          "hp": 1, "hp_pct": 1, "alive": True}]
    v = verify_floor([{"game": "g", "result": read_game(
        tl(chan(100.0, 103.0, "h_a", NORTH) + chan(100.0, 103.0, "h_b", NORTH),
           buildings=b), RADIANT)}])
    ck("10p one flip-producing group, not two attempts", v["produced"] == [6.0])
    ck("10q nothing misfiled", v["misfiled"] == ([], []))
    ck("10r and the multi-caster group is not in the aborted half",
       v["misfiled_groups"][1] == [])

    # 10s CO-CASTERS NEED NOT STOP TOGETHER (20260907_063731_slot4): zuus held
    #     South 1544.3-1549.2 while skeleton_king rode along 1547.0-1548.0 and
    #     left early.  The outpost flipped off those 5.9 caster-seconds, and a
    #     removal-frame key reads them as a 4.9 abort plus a 1.0 abort.
    r = read_game(tl(chan(1544.3, 1549.2, "h_a", SOUTH)
                     + chan(1547.0, 1548.0, "h_b", SOUTH)), RADIANT)
    ck("10s staggered co-casters are ONE group", len(r["groups"]) == 1)
    ck("10t caster-seconds 4.9 + 1.0 = 5.9", abs(r["groups"][0]["caster_s"] - 5.9) < 1e-6)
    ck("10u the group completes", r["groups"][0]["complete"] is True)

    # 10v A REAL GAP STILL SPLITS (20260907_063637_slot3): viper re-issued the
    #     order four times on South across 0.1-0.2 s seams for 6.7 raw
    #     caster-seconds and the outpost never changed hands.  Summing across a
    #     seam would call that a capture the game says did not happen.
    r = read_game(tl(chan(1363.2, 1366.1, "h_a", SOUTH)
                     + chan(1366.2, 1369.1, "h_a", SOUTH)), RADIANT)
    ck("10w a 0.1s seam splits the coverage", len(r["groups"]) == 2)
    ck("10x and neither half completes", all(not g["complete"] for g in r["groups"]))

    # 11. WHERE THE THRESHOLD MAY SIT -- two corpora, and they do not agree to
    #     better than the dump's own 0.1 s timestamp resolution.
    #       W52 (85 games, 4 seeds): every flipping group >= 5.8 caster-seconds
    #         (the 5.8 is silencer 3.7 + slardar 2.1, 20260907_004906_slot8);
    #         every non-flipping group <= 5.3.
    #       W53 (65 games, 4 seeds): every flipping group >= 5.9 apart from one
    #         re-issue episode; the largest NON-flipping group is 5.8
    #         (obsidian_destroyer alone, 20260907_064926_slot6, 1282.1-1287.9,
    #         South stayed team 2 on every sample 1274.4-1309.4).
    #     So 5.8 flipped on one corpus and did not on the other.  The two
    #     bracket the real value into [5.8, 5.9] and no threshold satisfies
    #     both: 5.8 misfiles the W53 obsidian_destroyer group, 5.9 misfiles the
    #     W52 silencer+slardar group.  Exactly one boundary group either way.
    #     ⚠️ WHAT THESE PINS DELIBERATELY DO NOT SAY: which of 5.8 / 5.9 is
    #     right.  Nothing here catches a move between them, because nothing in
    #     the data distinguishes them; an assertion that "caught" it would be
    #     the constant checking itself.  5.8 is kept because it was chosen
    #     first, not because W53 confirmed it.
    ck("11a threshold is above the largest non-flipping group on W52 (5.3)",
       DEFAULT_COMPLETE_CS > 5.3)
    ck("11b threshold is at or below the smallest flipping group on W53 (5.9)",
       DEFAULT_COMPLETE_CS <= 5.9)

    print("SELFCHECK %d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  FAIL", f)
    return 0 if not failures else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--complete-cs", type=float, default=DEFAULT_COMPLETE_CS,
                    help="completion threshold in CASTER-SECONDS per group "
                         "(default %.1f)" % DEFAULT_COMPLETE_CS)
    # Refused, not silently reinterpreted: the old flag meant "seconds of one
    # hero's channel" and the new quantity is a group integral (GH #609).
    ap.add_argument("--complete-s", type=float, default=None,
                    help=argparse.SUPPRESS)
    ap.add_argument("--dump-durations", action="store_true",
                    help="print every attempt duration (raw per-hero lengths)")
    ap.add_argument("--dump-groups", action="store_true",
                    help="print every group's caster-seconds with its flip "
                         "status, so the band behind --complete-cs can be "
                         "re-verified on a new corpus")
    ap.add_argument("--track", metavar="GAME:HERO:T0:T1",
                    help="print the per-second frame track for one hero")
    args = ap.parse_args()

    if args.complete_s is not None:
        sys.stderr.write(
            "--complete-s was removed (GH #609): completion is now a GROUP\n"
            "property measured in caster-seconds, not one hero's channel\n"
            "length.  Re-run with --complete-cs (default %.1f) once you have\n"
            "decided what the new quantity's threshold should be.\n"
            % DEFAULT_COMPLETE_CS)
        return 2
    if args.selfcheck:
        return selfcheck()
    if not args.dirs:
        sys.stderr.write("usage: outlatch_capture.py <sweep_out_dir> ... | --selfcheck\n")
        return 2

    dirs = []
    for d in args.dirs:
        dirs.extend(sorted(glob.glob(d)) if any(c in d for c in "*?[") else [d])
    games, per_key = scan_dirs(dirs, args.complete_cs)
    if not games:
        sys.stderr.write("no games found\n")
        return 2

    print("games scanned: %d" % len(games))
    print()
    print("PER-SEED x STRATUM x LEG (never pooled across strata -- rule 4(i-a))")
    print("%-6s %-4s %-6s %7s %9s %10s %10s" %
          ("seed", "str", "leg", "casts", "attempts", "completed", "wasted_s"))
    for key in sorted(per_key):
        v = per_key[key]
        print("%-6s %-4s %-6s %7d %9d %10d %10.1f" %
              (key[0], key[1], key[2], v["casts"], v["attempts"],
               v["completed"], v["wasted_s"]))

    tot = collections.Counter()
    for key, v in per_key.items():
        for f in ("casts", "attempts", "completed", "wasted_s"):
            tot[(key[2], f)] += v[f]
    print()
    print("BY LEG (abort rate is a within-leg ratio, so it is the one number "
          "here that side bias does not carry; 'unk' is its own bucket)")
    for leg in LEGS:
        att, comp = tot[(leg, "attempts")], tot[(leg, "completed")]
        rate = (att - comp) / att * 100 if att else float("nan")
        print("  %-5s attempts %3d  completed %3d  aborted %3d (%.0f%%)  wasted %.1fs"
              % (leg, att, comp, att - comp, rate, tot[(leg, "wasted_s")]))
    # Reconciliation against a total computed a different way.  The three
    # buckets must account for every attempt; a mismatch means an attempt fell
    # out of the leg split, which is the shape that hid last round's bug.
    raw = sum(len(g["result"]["attempts"]) for g in games)
    split = sum(tot[(leg, "attempts")] for leg in LEGS)
    print("  reconcile: %d attempts in the corpus, %d in the three buckets%s"
          % (raw, split, "" if raw == split else "   <-- MISMATCH"))

    flips = [(g["game"], f) for g in games for f in g["result"]["flips"]]
    print()
    print("outpost ownership flips: %d in %d games" % (len(flips), len(games)))

    groups = [grp for g in games for grp in g["result"]["groups"]]
    multi = [grp for grp in groups if grp["n"] > 1]
    unres = sum(g["result"]["unresolved_outpost"] for g in games)
    print("capture groups: %d (%d multi-caster); attempts with no outpost "
          "resolved: %d" % (len(groups), len(multi), unres))

    vf = verify_floor(games, args.complete_cs)
    print()
    print("THRESHOLD CHECK against ground truth (an ownership flip is a "
          "finished capture); the unit is CASTER-SECONDS per group")
    print("  groups followed by a flip   : %s" % (
        " ".join("%.1f" % d for d in vf["produced"]) or "(none)"))
    print("  largest group with NO flip  : %s" % (
        "%.1f" % max(vf["no_flip"]) if vf["no_flip"] else "(none)"))
    print("  flips with no preceding group: %d" % len(vf["orphan_flips"]))
    mis_hi, mis_lo = vf["misfiled_groups"]
    print("  misfiled by threshold %.1f: %d called complete without a flip, "
          "%d called aborted that flipped"
          % (args.complete_cs, len(mis_hi), len(mis_lo)))
    # GH #609's acceptance (2): after the group rule, no MULTI-CASTER group may
    # sit in the aborted-but-flipped half.  Printed unconditionally, including
    # the zero, so the reading is a measurement and not an absence of output.
    mis_lo_multi = [grp for grp in mis_lo if grp["n"] > 1]
    print("  of those, multi-caster groups: %d  (GH #609 acceptance (2): must "
          "be 0)" % len(mis_lo_multi))
    for grp in mis_lo_multi:
        print("    MULTI-CASTER MISFILE %s t=%.1f cs=%.1f n=%d %s"
              % (grp["outpost"], grp["t1"], grp["caster_s"], grp["n"],
                 ",".join(a.replace("npc_dota_hero_", "") for a in grp["actors"])))

    print()
    print("ZERO-YIELD EPISODES (>=2 attempts, 0 completed) -- the frames to watch")
    rows = [(g["game"], e) for g in games for e in g["result"]["episodes"]
            if e["n"] >= 2 and e["completed"] == 0]
    rows.sort(key=lambda r: -r[1]["n"])
    for game, e in rows:
        print("  %-24s %-22s leg=%-5s n=%-2d t=%.1f-%.1f (%.1fs) longest=%.1fs"
              % (game, e["actor"].replace("npc_dota_hero_", ""), e["leg"], e["n"],
                 e["t0"], e["t1"], e["span"], e["longest"]))

    if args.dump_durations:
        durs = sorted(a["dur"] for g in games for a in g["result"]["attempts"])
        print()
        print("attempt durations (s), sorted:")
        print("  " + " ".join("%.1f" % d for d in durs))

    if args.dump_groups:
        flipped = {id(grp) for grp in vf["produced_groups"]}
        print()
        print("GROUP BAND (n_casters, flipped, caster-seconds) -- re-verify the "
              "empty band on every new corpus before reusing the threshold")
        rows = collections.defaultdict(list)
        for grp in groups:
            rows[(grp["n"], id(grp) in flipped)].append(grp["caster_s"])
        for key in sorted(rows):
            vals = sorted(rows[key])
            print("  n=%d flipped=%-5s groups=%-4d %s"
                  % (key[0], key[1], len(vals),
                     " ".join("%.1f" % v for v in vals)))

    if args.track:
        game, hero, t0, t1 = args.track.split(":")
        hit = [g for g in games if g["game"] == game]
        if not hit:
            sys.stderr.write("game %s not in the scanned dirs\n" % game)
            return 2
        timeline = json.load(open(hit[0]["path"]))
        name = hero if hero.startswith("npc_") else "npc_dota_hero_" + hero
        print()
        print("FRAME TRACK %s %s [%s,%s]" % (game, name, t0, t1))
        for r in hero_track(timeline, name, float(t0), float(t1)):
            print("  t=%7.1f x=%6d y=%6d hp_pct=%.2f level=%s"
                  % (r["t"], r["x"], r["y"], r["hp_pct"], r["level"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

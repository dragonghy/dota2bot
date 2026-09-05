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
  An attempt is COMPLETE when its channel lasted >= --complete-s (default 5.0).
  That floor is NOT asserted and it is NOT the game's channel time copied into
  a constant.  It is CHECKED against ground truth on every run: a capture that
  actually finished flips the outpost's `team` field, so `verify_floor()` pairs
  each attempt with the ownership flips that follow it and prints the two
  clusters it separates.  On the corpus this was written for the check comes
  back clean -- every flip has a preceding attempt, flip-producing attempts run
  5.2-6.0 s, and the longest attempt that produced NO flip is 4.4 s -- so 5.0
  sits in a real gap.  ⚠️ The gap is a gap, not an emptiness: three attempts
  land at 4.2 / 4.4 / 5.2, so a floor moved into that band re-labels individual
  attempts.  It does not move the reading (armed 68-76% / base 75-79% aborted
  across floors 4.0-5.5, same four zero-yield episodes at every floor), but the
  claim to make is "robust over that band", never "the distribution is empty
  there".  `--dump-durations` prints every duration so a new corpus can be
  re-checked before the number is reused.

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

import argparse
import collections
import glob
import json
import os
import sys

CAPTURE_ABILITY = "ability_capture"
CAPTURE_MODIFIER = "modifier_watch_tower_capturing"
WATCH_TOWER = "watch_tower"
DEFAULT_COMPLETE_S = 5.0
# Two attempts by the same hero separated by less than this are one visit to
# the outpost.  Episode grouping only shapes the narrative rows; the strata
# table below is computed from raw attempts and does not depend on it.
EPISODE_GAP_S = 5.0

RADIANT, DIRE = 2, 3


def _armed_team(side):
    if side == "radiant":
        return RADIANT
    if side == "dire":
        return DIRE
    raise ValueError("unknown side %r" % (side,))


def read_game(timeline, armed_team, complete_s=DEFAULT_COMPLETE_S):
    """One game -> {casts, attempts, episodes, flips}.

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
            open_by_actor[actor] = e["t"]
        elif e.get("type") == "MODIFIER_REMOVE" and actor in open_by_actor:
            t0 = open_by_actor.pop(actor)
            dur = e["t"] - t0
            attempts.append({
                "actor": actor, "t0": t0, "t1": e["t"], "dur": dur,
                "complete": dur >= complete_s, "leg": leg_of(actor),
            })
    # A channel still open at the last event (game ended mid-channel) is NOT
    # counted either way: calling it aborted would invent a defect out of the
    # recording boundary.
    unclosed = len(open_by_actor)

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

    return {"casts": casts, "attempts": attempts, "episodes": episodes,
            "flips": flips, "unclosed": unclosed}


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


def verify_floor(games, complete_s=DEFAULT_COMPLETE_S, window_s=6.0):
    """Cross-check --complete-s against ground truth (outpost ownership flips).

    A capture that finished flips the outpost's `team`; buildings are sampled
    every 5 s, so the flip is observed up to one sample AFTER the channel ends
    -- hence `window_s`.  Returns the two clusters the floor is separating plus
    the disagreements, and never decides anything on its own: a caller that
    wants a verdict reads `misfiled` / `orphan_flips`.
    """
    produced, no_flip, orphan_flips = [], [], []
    for g in games:
        r = g["result"]
        for a in r["attempts"]:
            hit = [f for f in r["flips"] if -0.5 <= f["t"] - a["t1"] <= window_s]
            (produced if hit else no_flip).append(a["dur"])
        for f in r["flips"]:
            if not any(-0.5 <= f["t"] - a["t1"] <= window_s for a in r["attempts"]):
                orphan_flips.append((g["game"], f))
    # An attempt the floor calls complete but that produced no flip, or one it
    # calls aborted that did -- either is the floor disagreeing with the game.
    misfiled = ([d for d in no_flip if d >= complete_s],
                [d for d in produced if d < complete_s])
    return {"produced": sorted(produced), "no_flip": sorted(no_flip),
            "orphan_flips": orphan_flips, "misfiled": misfiled}


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


def scan_dirs(dirs, complete_s=DEFAULT_COMPLETE_S):
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
            r = read_game(timeline, armed, complete_s)
            stratum = "ab" if row["side"] == "radiant" else "ba"
            games.append({"run": os.path.basename(d.rstrip("/")), "game": row["game"],
                          "seed": row["seed"], "stratum": stratum, "result": r,
                          "path": tl_path})
            for leg in ("armed", "base"):
                key = (row["seed"], stratum, leg)
                per_key[key]["games"] += 0
                per_key[key]["attempts"] += sum(1 for a in r["attempts"] if a["leg"] == leg)
                per_key[key]["completed"] += sum(1 for a in r["attempts"]
                                                 if a["leg"] == leg and a["complete"])
                per_key[key]["casts"] += sum(1 for c in r["casts"] if c["leg"] == leg)
                per_key[key]["wasted_s"] += sum(a["dur"] for a in r["attempts"]
                                                if a["leg"] == leg and not a["complete"])
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

    def ev(t, typ, infl, actor):
        return {"t": t, "type": typ, "inflictor": infl, "actor": actor}

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

    print("SELFCHECK %d checks, %d failed" % (checks, len(failures)))
    for f in failures:
        print("  FAIL", f)
    return 0 if not failures else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--complete-s", type=float, default=DEFAULT_COMPLETE_S)
    ap.add_argument("--dump-durations", action="store_true",
                    help="print every attempt duration, so the bimodal gap "
                         "behind --complete-s can be re-checked on a new corpus")
    ap.add_argument("--track", metavar="GAME:HERO:T0:T1",
                    help="print the per-second frame track for one hero")
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()
    if not args.dirs:
        sys.stderr.write("usage: outlatch_capture.py <sweep_out_dir> ... | --selfcheck\n")
        return 2

    dirs = []
    for d in args.dirs:
        dirs.extend(sorted(glob.glob(d)) if any(c in d for c in "*?[") else [d])
    games, per_key = scan_dirs(dirs, args.complete_s)
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
          "here that side bias does not carry)")
    for leg in ("armed", "base"):
        att, comp = tot[(leg, "attempts")], tot[(leg, "completed")]
        rate = (att - comp) / att * 100 if att else float("nan")
        print("  %-5s attempts %3d  completed %3d  aborted %3d (%.0f%%)  wasted %.1fs"
              % (leg, att, comp, att - comp, rate, tot[(leg, "wasted_s")]))

    flips = [(g["game"], f) for g in games for f in g["result"]["flips"]]
    print()
    print("outpost ownership flips: %d in %d games" % (len(flips), len(games)))

    vf = verify_floor(games, args.complete_s)
    print()
    print("FLOOR CHECK against ground truth (an ownership flip is a finished capture)")
    print("  attempts followed by a flip : %s" % (
        " ".join("%.1f" % d for d in vf["produced"]) or "(none)"))
    print("  longest attempt with NO flip: %s" % (
        "%.1f" % max(vf["no_flip"]) if vf["no_flip"] else "(none)"))
    print("  flips with no preceding attempt: %d" % len(vf["orphan_flips"]))
    print("  misfiled by floor %.1f: %d called complete without a flip, "
          "%d called aborted that flipped"
          % (args.complete_s, len(vf["misfiled"][0]), len(vf["misfiled"][1])))

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

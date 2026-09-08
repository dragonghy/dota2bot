#!/usr/bin/env python3
"""outpost_block_probe -- does an ENEMY HERO NEARBY explain a channel that
captured nothing?

WHY THIS EXISTS
  replay-check 2026-09-07T21:56Z (charter "当前状态", W53 addendum) closed a
  four-round hunt for a caster-seconds threshold that separates "the outpost
  flipped" from "it did not", and closed it NEGATIVE:

    `122407_slot7` (run 93cef1) venomancer channelled North for a full
    5.9 caster-seconds and the (3392,-448) samples read team 3 the whole way;
    `130206_slot8` (run 93cef1) viper channelled South 5.9 caster-seconds and
    (-4096,-448) read team 2 through six consecutive samples.

  5.9 also appears on the flipping side in the same corpus, so caster-seconds
  is NECESSARY BUT NOT SUFFICIENT: no threshold can separate the two clusters,
  and that round refused to name a mechanism ("本轮不认领这个机制").  The
  named suspect was an enemy hero present at the outpost blocking the capture.

  This probe buys that suspect, or refuses it, off the SAME dump -- because
  hero positions ARE in the dump, so "the hidden variable is not observable"
  was never established, only "it is not in the channel record".

WHAT IT MEASURES
  For every contiguous coverage group `outlatch_capture.read_game` finds:
    - `caster_s`  the group's caster-seconds (that module's quantity, reused
                  verbatim -- this probe does not re-derive it)
    - `flip`      ground truth: an ownership flip within `--window-s` of the
                  group's end (same pairing as `verify_floor`)
    - `min_enemy` the smallest distance from the OUTPOST to any live enemy
                  hero of the channelling team, over the snapshots inside the
                  channel
  and prints the 2x2 of `flip` against `min_enemy <= R` for several R.

HOW THE OUTPOST POSITION IS RESOLVED, AND WHY NOT BY NAME
  A group is keyed by the outpost NAME the combat log carries
  (`#DOTA_OutpostName_North` / `_South`); ownership lives at a POSITION.  This
  probe does NOT hardcode a name->position table: it takes the caster's own
  median position during the channel and picks the nearer of the game's
  watch_tower positions.  The caster is standing on the outpost -- that is what
  channelling it means -- so this is frame evidence, and `pos_err` (how far the
  caster was from the position it picked) is printed so a bad resolution is
  visible instead of silent.  Groups whose `pos_err` exceeds `--pos-max`
  (default 400 u) are reported as `unresolved` and counted OUT of the table
  rather than being filed on a guess.

WHAT IT WILL NOT DO
  It will not call a co-located enemy the CAUSE.  An enemy hero standing on a
  contested outpost is also what a fight there looks like, and a fight
  interrupts a channel through damage, which this dump does not link to the
  channel either.  The output is an association table plus the frames behind
  it; the mechanism claim belongs to whoever reads the frames.

  It also does not use illusion-blind name filtering: enemy frames come from
  `entities.frames_by_hero`, which drops illusions and duplicate entity
  streams (replay-check 2026-08-25).  An illusion counted as a blocker would
  manufacture exactly the association this probe is testing for.
"""
import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from entities import canon, frames_by_hero  # noqa: E402
import outlatch_capture as olc  # noqa: E402

DEFAULT_RADII = (600.0, 900.0, 1200.0, 1500.0)
DEFAULT_POS_MAX = 400.0
DEFAULT_WINDOW_S = 6.0


def _dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def remove_values(timeline):
    """(actor, t) -> `value` on the capture modifier's MODIFIER_REMOVE.

    THE FIELD THE THRESHOLD HUNT NEVER READ.  `outlatch_capture` consumes the
    ADD/REMOVE pair for its timestamps and drops every other key, so four
    rounds of this stream compared channel LENGTHS while the combat log was
    carrying the outcome itself one field over.  On the two games that killed
    the caster-seconds threshold the split is exact: the aborted 5.9 s
    channels (`122407_slot7` venomancer, `130206_slot8` viper) remove with
    `value=1`; the 5.9 s channel that flipped South (`122407_slot7`
    skeleton_king) removes with `value=0`.

    This helper only REPORTS the field.  Whether it means "completed" is a
    corpus question, answered against ownership flips by `table()`, and it is
    exactly the question a threshold cannot answer.
    """
    out = {}
    for e in timeline.get("events", ()):
        if (e.get("inflictor") == olc.CAPTURE_MODIFIER
                and e.get("type") == "MODIFIER_REMOVE"):
            out[(e.get("actor"), e["t"])] = e.get("value")
    return out


def outpost_positions(timeline):
    """The distinct watch_tower positions this game sampled."""
    seen = set()
    for b in timeline.get("buildings", ()):
        if b.get("name") == olc.WATCH_TOWER:
            seen.add((round(b["x"]), round(b["y"])))
    return sorted(seen)


def probe_game(timeline, armed_team, complete_cs=olc.DEFAULT_COMPLETE_CS,
               window_s=DEFAULT_WINDOW_S, pos_max=DEFAULT_POS_MAX):
    """-> {'groups': [...], 'unresolved': n, 'no_samples': n}"""
    res = olc.read_game(timeline, armed_team, complete_cs=complete_cs)
    rem_val = remove_values(timeline)
    frames, team_by = frames_by_hero(timeline)
    posts = outpost_positions(timeline)
    teams = timeline.get("game", {}).get("teams", {})

    rows, unresolved, no_samples = [], 0, 0
    for grp in res["groups"]:
        # --- caster track over the channel (frame evidence, not a name table)
        tracks = {}
        for actor in grp["actors"]:
            tracks[actor] = [s for s in frames.get(canon(actor), ())
                             if grp["t0"] - 0.5 <= s["t"] <= grp["t1"] + 0.5]
        pts = [(s["x"], s["y"]) for tr in tracks.values() for s in tr]
        if not pts or not posts:
            unresolved += 1
            continue
        cx = sorted(p[0] for p in pts)[len(pts) // 2]
        cy = sorted(p[1] for p in pts)[len(pts) // 2]
        post = min(posts, key=lambda p: _dist(cx, cy, p[0], p[1]))
        pos_err = _dist(cx, cy, post[0], post[1])
        if pos_err > pos_max:
            unresolved += 1
            continue

        # --- caster team, through game.teams (never slot order)
        ct = None
        for actor in grp["actors"]:
            ct = teams.get(actor)
            if ct is not None:
                break
        if ct is None:
            unresolved += 1
            continue

        # --- nearest live enemy hero to the OUTPOST during the channel
        min_enemy, min_at, min_who = None, None, None
        n_samples = 0
        for hero, tr in frames.items():
            if team_by.get(hero) == ct or team_by.get(hero) is None:
                continue
            for s in tr:
                if not (grp["t0"] <= s["t"] <= grp["t1"]):
                    continue
                n_samples += 1
                if s["hp_pct"] <= 0:          # corpse frames are not blockers
                    continue
                d = _dist(s["x"], s["y"], post[0], post[1])
                if min_enemy is None or d < min_enemy:
                    min_enemy, min_at, min_who = d, s["t"], hero
        if n_samples == 0:
            no_samples += 1

        flip = [f for f in res["flips"]
                if -0.5 <= f["t"] - grp["t1"] <= window_s and f["pos"] == post]

        # Ownership around the channel.  `owner_t0` answers the cheapest
        # alternative reading of a no-flip channel -- the team already owned
        # the outpost, so there was nothing to flip -- without which "it
        # captured nothing" and "there was nothing to capture" are one row.
        samples = sorted((b["t"], b["team"]) for b in timeline.get("buildings", ())
                         if b.get("name") == olc.WATCH_TOWER
                         and (round(b["x"]), round(b["y"])) == post)
        before = [s for s in samples if s[0] <= grp["t0"]]
        after = [s for s in samples if grp["t1"] <= s[0] <= grp["t1"] + 30.0]
        owner_t0 = before[-1][1] if before else None
        owner_after = after[-1][1] if after else None

        # Per-member REMOVE values, joined on (actor, t1) -- the same key the
        # attempt was built from, so a mismatch is a missing event, never a
        # neighbouring channel's value.
        vals = []
        for a in res["attempts"]:
            if (a["outpost"] == grp["outpost"] and a["actor"] in grp["actors"]
                    and grp["t0"] - 1e-6 <= a["t0"] and a["t1"] <= grp["t1"] + 1e-6):
                vals.append(rem_val.get((a["actor"], a["t1"])))
        rows.append({
            "outpost": grp["outpost"], "pos": list(post), "pos_err": round(pos_err, 1),
            "t0": grp["t0"], "t1": grp["t1"], "caster_s": round(grp["caster_s"], 2),
            "n": grp["n"], "actors": grp["actors"], "caster_team": ct,
            "flip": bool(flip),
            "flip_t": flip[0]["t"] if flip else None,
            "owner_t0": owner_t0, "owner_after30": owner_after,
            "already_owned": (owner_t0 == ct) if owner_t0 is not None else None,
            "remove_values": vals,
            # A group is one bar: if ANY member's channel removed with 0, the
            # bar finished on that member's frame.  `None` means the join found
            # no REMOVE for a member, and is kept distinct from 'no zero' --
            # collapsing them would read a missing field as a failed capture.
            "removed_zero": (None if not [v for v in vals if v is not None]
                             else any(v == 0 for v in vals)),
            "min_enemy": None if min_enemy is None else round(min_enemy, 1),
            "min_enemy_t": min_at, "min_enemy_hero": min_who,
            "enemy_samples": n_samples,
        })
    # ONE FLIP BELONGS TO ONE GROUP (2026-09-08).  Same rule, same reason, as
    # `outlatch_capture.verify_floor`: the flip that ends a re-issue burst sits
    # inside the window of the ABORTED group before it too, and crediting both
    # prints `flip=True` on a group that captured nothing -- in
    # 20260907_003641_slot2 that put chaos_knight's 3.0 cs `rmv=1,1` group in
    # the flip column beside the 3.1 cs `rmv=0` group that actually bought it,
    # and the 2x2 below then reported a criterion disagreement that is not one.
    # The credit goes to the group that ended NEAREST BEFORE the flip on that
    # outpost; the rest keep every other column and lose only the flip.
    by_flip = collections.defaultdict(list)
    for row in rows:
        if row["flip"]:
            by_flip[(tuple(row["pos"]), row["flip_t"])].append(row)
    for _key, sharers in by_flip.items():
        if len(sharers) < 2:
            continue
        keep = max(sharers, key=lambda r: r["t1"])
        for row in sharers:
            if row is not keep:
                row["flip"], row["flip_t"] = False, None
    return {"groups": rows, "unresolved": unresolved, "no_samples": no_samples}


def scan_dirs(dirs, complete_cs=olc.DEFAULT_COMPLETE_CS,
              window_s=DEFAULT_WINDOW_S, pos_max=DEFAULT_POS_MAX):
    out, games = [], 0
    unresolved = no_samples = 0
    for d in dirs:
        manifest = os.path.join(d, "games_manifest.jsonl")
        if not os.path.exists(manifest):
            print("no games_manifest.jsonl under %s" % d, file=sys.stderr)
            continue
        for line in open(manifest):
            row = json.loads(line)
            tl_path = os.path.join(d, "timelines", "%s.timeline.json" % row["game"])
            if not os.path.exists(tl_path):
                continue
            with open(tl_path) as fh:
                timeline = json.load(fh)
            armed = olc._armed_team(row["side"])
            r = probe_game(timeline, armed, complete_cs, window_s, pos_max)
            games += 1
            unresolved += r["unresolved"]
            no_samples += r["no_samples"]
            for g in r["groups"]:
                # (sweep_dir, game) is the key -- a bare game name collides
                # across runs (replay-check 2026-09-07, twice).
                g["game"] = row["game"]
                g["run"] = os.path.basename(d.rstrip("/"))
                g["seed"] = row.get("seed")
                g["side"] = row.get("side")
                out.append(g)
    return {"groups": out, "games": games,
            "unresolved": unresolved, "no_samples": no_samples}


def table(groups, radii=DEFAULT_RADII):
    lines = []
    have = [g for g in groups if g["min_enemy"] is not None]
    lines.append("groups=%d  with_enemy_sample=%d  flips=%d"
                 % (len(groups), len(have), sum(1 for g in groups if g["flip"])))
    lines.append("")
    lines.append("R(u)  | flip&near  flip&far | noflip&near  noflip&far")
    for R in radii:
        fn = sum(1 for g in have if g["flip"] and g["min_enemy"] <= R)
        ff = sum(1 for g in have if g["flip"] and g["min_enemy"] > R)
        nn = sum(1 for g in have if not g["flip"] and g["min_enemy"] <= R)
        nf = sum(1 for g in have if not g["flip"] and g["min_enemy"] > R)
        lines.append("%5.0f | %9d %9d | %11d %10d" % (R, fn, ff, nn, nf))

    # The threshold-free reading: MODIFIER_REMOVE `value` against ground truth.
    rz = [g for g in groups if g["removed_zero"] is not None]
    a = sum(1 for g in rz if g["removed_zero"] and g["flip"])
    b = sum(1 for g in rz if g["removed_zero"] and not g["flip"])
    c = sum(1 for g in rz if not g["removed_zero"] and g["flip"])
    d = sum(1 for g in rz if not g["removed_zero"] and not g["flip"])
    lines.append("")
    lines.append("REMOVE value vs ownership flip (groups with a value: %d)" % len(rz))
    lines.append("             | flip   no-flip")
    lines.append("  value==0   | %4d   %5d" % (a, b))
    lines.append("  value!=0   | %4d   %5d" % (c, d))
    lines.append("  agreement  : %d/%d%s"
                 % (a + d, len(rz),
                    ("  DISAGREEMENTS: %d" % (b + c)) if (b + c) else "  (exact)"))

    # And the same 2x2 for the caster-seconds threshold, so the two readings
    # are compared on one corpus instead of across reports.
    cs = olc.DEFAULT_COMPLETE_CS
    ta = sum(1 for g in groups if g["caster_s"] >= cs and g["flip"])
    tb = sum(1 for g in groups if g["caster_s"] >= cs and not g["flip"])
    tc = sum(1 for g in groups if g["caster_s"] < cs and g["flip"])
    td = sum(1 for g in groups if g["caster_s"] < cs and not g["flip"])
    lines.append("")
    lines.append("caster_s >= %.1f vs flip (same corpus, for comparison)" % cs)
    lines.append("             | flip   no-flip")
    lines.append("  >= thresh  | %4d   %5d" % (ta, tb))
    lines.append("  <  thresh  | %4d   %5d" % (tc, td))
    lines.append("  agreement  : %d/%d  DISAGREEMENTS: %d"
                 % (ta + td, len(groups), tb + tc))
    return "\n".join(lines)


def selfcheck():
    """Synthetic timelines with a known answer.  Prints PASS/FAIL per check."""
    fails, ran = [], []

    def ck(name, cond):
        print("%-58s %s" % (name, "PASS" if cond else "FAIL"))
        ran.append(name)
        if not cond:
            fails.append(name)

    RAD, DIRE = 2, 3
    NORTH, SOUTH = (3392, -448), (-4096, -448)

    def ev(t, typ, infl, actor, target=None, value=1):
        return {"t": t, "type": typ, "inflictor": infl, "actor": actor,
                "target": target, "value": value}

    def chan(t0, t1, actor, outpost, rmv=1):
        return [ev(t0, "MODIFIER_ADD", olc.CAPTURE_MODIFIER, actor, outpost),
                ev(t1, "MODIFIER_REMOVE", olc.CAPTURE_MODIFIER, actor, outpost,
                   value=rmv)]

    def snaps(hero, idx, team, xy, ts, hp=1.0):
        return [{"t": t, "hero": hero, "idx": idx, "team": team,
                 "x": xy[0], "y": xy[1], "hp_pct": hp} for t in ts]

    def build(pos, ts, team):
        return [{"t": t, "name": olc.WATCH_TOWER, "x": pos[0], "y": pos[1],
                 "team": team} for t in ts]

    caster, foe = "npc_dota_hero_zuus", "npc_dota_hero_lina"
    base_ts = [-5.0] + [float(t) for t in range(0, 30)]

    def tl(events, buildings, snapshots, teams):
        return {"game": {"teams": teams}, "events": events,
                "buildings": buildings, "snapshots": snapshots}

    teams = {caster: RAD, foe: DIRE}

    # 1. no enemy anywhere near -> min_enemy is large, flip observed
    t1 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0], DIRE) + build(NORTH, [20.0], RAD),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, (0, 0), base_ts),
            teams)
    r = probe_game(t1, RAD)
    ck("1a one group resolved", len(r["groups"]) == 1 and r["unresolved"] == 0)
    g = r["groups"][0]
    ck("1b outpost resolved off the caster track", g["pos"] == list(NORTH))
    ck("1c pos_err ~0", g["pos_err"] < 1.0)
    ck("1d flip seen inside the window", g["flip"] is True)
    ck("1e distant enemy measured, not dropped",
       g["min_enemy"] is not None and g["min_enemy"] > 3000)

    # 2. enemy standing ON the outpost, no flip
    t2 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0, 20.0], DIRE),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, (NORTH[0] + 100, NORTH[1]), base_ts),
            teams)
    g2 = probe_game(t2, RAD)["groups"][0]
    ck("2a no flip", g2["flip"] is False)
    ck("2b enemy at 100 u", abs(g2["min_enemy"] - 100.0) < 1.0)

    # 3. a CORPSE at the outpost is not a blocker
    t3 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0, 20.0], DIRE),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, (NORTH[0] + 100, NORTH[1]), base_ts, hp=0.0),
            teams)
    g3 = probe_game(t3, RAD)["groups"][0]
    ck("3 corpse frames are not blockers", g3["min_enemy"] is None)

    # 4. a TEAMMATE at the outpost is not a blocker
    ally = "npc_dota_hero_lion"
    t4 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0, 20.0], DIRE),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(ally, 3, RAD, (NORTH[0] + 50, NORTH[1]), base_ts)
            + snaps(foe, 2, DIRE, (0, 0), base_ts),
            {caster: RAD, ally: RAD, foe: DIRE})
    g4 = probe_game(t4, RAD)["groups"][0]
    ck("4 own-team hero is not an enemy", g4["min_enemy"] > 3000)

    # 5. an ILLUSION at the outpost is not a blocker (post-horn entity)
    t5 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0, 20.0], DIRE),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, (0, 0), base_ts)
            + snaps(foe, 9, DIRE, (NORTH[0] + 10, NORTH[1]),
                    [float(t) for t in range(5, 25)]),
            teams)
    g5 = probe_game(t5, RAD)["groups"][0]
    ck("5 illusion stream dropped, not counted as a blocker",
       g5["min_enemy"] > 3000)

    # 6. the SOUTH outpost's flip does not pair with a NORTH group
    t6 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0, 20.0], DIRE)
            + build(SOUTH, [0.0, 10.0], DIRE) + build(SOUTH, [20.0], RAD),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, (0, 0), base_ts),
            teams)
    g6 = probe_game(t6, RAD)["groups"][0]
    ck("6a group filed at NORTH", g6["pos"] == list(NORTH))
    ck("6b a SOUTH flip is not this group's flip", g6["flip"] is False)

    # 7. a caster nowhere near either outpost is UNRESOLVED, not guessed
    t7 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 20.0], DIRE) + build(SOUTH, [0.0, 20.0], DIRE),
            snaps(caster, 1, RAD, (0, 0), base_ts)
            + snaps(foe, 2, DIRE, (0, 0), base_ts),
            teams)
    r7 = probe_game(t7, RAD)
    ck("7 far-from-any-outpost group is unresolved",
       r7["groups"] == [] and r7["unresolved"] == 1)

    # 8. enemy sampled only OUTSIDE the channel does not count
    t8 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 10.0, 20.0], DIRE),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, NORTH, [-5.0, 0.0, 1.0, 2.0])
            + snaps(foe, 2, DIRE, (9000, 9000),
                    [float(t) for t in range(3, 30)]),
            teams)
    g8 = probe_game(t8, RAD)["groups"][0]
    ck("8 only in-channel samples are read", g8["min_enemy"] > 3000)

    # The count is the checks that RAN, never a literal kept in step by hand:
    # a hand-kept total is exactly the number that stops matching the day a
    # check is added, and it drifts silently downward (this file shipped its
    # first minute reading "13" for 14 checks).
    # 9. ownership around the channel, and the "nothing to capture" reading
    t9 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
            build(NORTH, [0.0, 5.0, 10.0, 20.0, 25.0], RAD),
            snaps(caster, 1, RAD, NORTH, base_ts)
            + snaps(foe, 2, DIRE, (0, 0), base_ts),
            teams)
    g9 = probe_game(t9, RAD)["groups"][0]
    ck("9a owner before the channel is read", g9["owner_t0"] == RAD)
    ck("9b channelling an outpost you already own is flagged",
       g9["already_owned"] is True)
    ck("9c no flip on an already-owned outpost", g9["flip"] is False)
    ck("9d a real capture is not flagged already_owned",
       probe_game(t1, RAD)["groups"][0]["already_owned"] is False)

    # 10. the REMOVE `value` join, including the two ways it can be wrong:
    #     picking up a neighbouring channel's value, and reading a missing
    #     event as "did not complete".
    t10 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North", rmv=0)
             + chan(30.0, 33.0, caster, "#DOTA_OutpostName_North", rmv=1),
             build(NORTH, [0.0, 10.0], DIRE) + build(NORTH, [20.0, 35.0], RAD),
             snaps(caster, 1, RAD, NORTH, base_ts + [30.0, 31.0, 32.0, 33.0, 35.0])
             + snaps(foe, 2, DIRE, (0, 0), base_ts + [30.0, 31.0, 32.0, 33.0, 35.0]),
             teams)
    r10 = probe_game(t10, RAD)["groups"]
    ck("10a two groups", len(r10) == 2)
    ck("10b first group carries its own value 0",
       r10[0]["remove_values"] == [0] and r10[0]["removed_zero"] is True)
    ck("10c second group carries its own value 1",
       r10[1]["remove_values"] == [1] and r10[1]["removed_zero"] is False)

    t11 = tl([ev(10.0, "MODIFIER_ADD", olc.CAPTURE_MODIFIER, caster,
                 "#DOTA_OutpostName_North"),
              ev(16.0, "MODIFIER_REMOVE", olc.CAPTURE_MODIFIER, caster,
                 "#DOTA_OutpostName_North", value=None)],
             build(NORTH, [0.0, 10.0, 20.0], DIRE),
             snaps(caster, 1, RAD, NORTH, base_ts)
             + snaps(foe, 2, DIRE, (0, 0), base_ts),
             teams)
    ck("11 a missing value is None, not 'did not complete'",
       probe_game(t11, RAD)["groups"][0]["removed_zero"] is None)

    # 12. the distance is to the OUTPOST, not to the caster.  Every case above
    #     stands the caster exactly on the post, where the two readings are the
    #     same number -- and the real corpus never does: a channelling hero
    #     sits ~140 u off centre in every W53/W54 group measured.  Without this
    #     case the caster-relative reading survives untouched.
    off = (NORTH[0] - 140, NORTH[1])          # caster 140 u west of the post
    foe_at = (NORTH[0] - 140 + 1000, NORTH[1])  # 1000 u from caster, 860 from post
    t12 = tl(chan(10.0, 16.0, caster, "#DOTA_OutpostName_North"),
             build(NORTH, [0.0, 10.0, 20.0], DIRE),
             snaps(caster, 1, RAD, off, base_ts)
             + snaps(foe, 2, DIRE, foe_at, base_ts),
             teams)
    # 13. ONE FLIP BELONGS TO ONE GROUP (20260907_003641_slot2).  Two groups
    #     end 3.2 s apart and one flip follows both inside the window; the
    #     credit belongs to the later one, which is the one that removed with
    #     value 0.  Crediting both prints `flip=True` on a group that captured
    #     nothing and turns one capture into a criterion disagreement.
    t13 = tl(chan(1239.9, 1242.9, caster, "#DOTA_OutpostName_North", rmv=1)
             + chan(1243.0, 1246.1, caster, "#DOTA_OutpostName_North", rmv=0),
             build(NORTH, [1235.0, 1240.0], DIRE) + build(NORTH, [1248.5], RAD),
             # base_ts is kept in front: `frames_by_hero` identifies the real
             # hero by a pre-horn sample, so a track that starts at t=1239 is
             # dropped as a duplicate entity stream and the group reads
             # "unresolved" (this case failed exactly that way when written).
             snaps(caster, 1, RAD, NORTH,
                   base_ts + [1239.0, 1240.0, 1243.0, 1245.0, 1246.0])
             + snaps(foe, 2, DIRE, (0, 0),
                     base_ts + [1239.0, 1240.0, 1243.0, 1245.0, 1246.0]),
             teams)
    r13 = sorted(probe_game(t13, RAD)["groups"], key=lambda g: g["t1"])
    ck("13a two groups, one flip", len(r13) == 2)
    ck("13b the flip is credited to the later group only",
       r13[1]["flip"] is True and r13[0]["flip"] is False)
    ck("13c and the credited group is the one that removed with 0",
       r13[1]["removed_zero"] is True and r13[0]["removed_zero"] is False)

    g12 = probe_game(t12, RAD)["groups"][0]
    ck("12a caster offset still resolves the post", g12["pos"] == list(NORTH))
    ck("12b distance is measured to the outpost (860), not the caster (1000)",
       abs(g12["min_enemy"] - 860.0) < 1.0)

    print("\nSELFCHECK %d checks / %d failed" % (len(ran), len(fails)))
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dirs", nargs="*", help="sweep_run.sh output dirs")
    ap.add_argument("--complete-cs", type=float, default=olc.DEFAULT_COMPLETE_CS)
    ap.add_argument("--window-s", type=float, default=DEFAULT_WINDOW_S)
    ap.add_argument("--pos-max", type=float, default=DEFAULT_POS_MAX)
    ap.add_argument("--min-caster-s", type=float, default=None,
                    help="only print rows at or above this caster-seconds")
    ap.add_argument("--dump-groups", action="store_true")
    ap.add_argument("--json-out")
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()
    if not a.dirs:
        ap.error("give at least one sweep dir, or --selfcheck")

    r = scan_dirs(a.dirs, a.complete_cs, a.window_s, a.pos_max)
    rows = r["groups"]
    print("games=%d  groups=%d  unresolved_groups=%d  groups_without_enemy_samples=%d"
          % (r["games"], len(rows), r["unresolved"], r["no_samples"]))
    print()
    print(table(rows))
    if a.dump_groups:
        print()
        sel = rows if a.min_caster_s is None else [
            g for g in rows if g["caster_s"] >= a.min_caster_s]
        for g in sorted(sel, key=lambda g: (-g["caster_s"], g["game"])):
            print("%5.1f cs n=%d %-6s flip=%-5s rmv=%-11s own=%s->%s mine=%-5s "
                  "min_enemy=%-8s @t=%-8s %-14s %s/%s t=%.1f-%.1f "
                  "actors=%s pos_err=%.0f"
                  % (g["caster_s"], g["n"], g["outpost"].split("_")[-1],
                     g["flip"],
                     ",".join("-" if v is None else str(v) for v in g["remove_values"]),
                     g["owner_t0"], g["owner_after30"],
                     g["already_owned"], g["min_enemy"], g["min_enemy_t"],
                     (g["min_enemy_hero"] or "-"), g["run"][-6:], g["game"],
                     g["t0"], g["t1"],
                     ",".join(a.replace("npc_dota_hero_", "") for a in g["actors"]),
                     g["pos_err"]))
    if a.json_out:
        with open(a.json_out, "w") as fh:
            json.dump(r, fh, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

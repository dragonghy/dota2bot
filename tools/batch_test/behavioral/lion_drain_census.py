#!/usr/bin/env python3
"""`liondrainstop` condition-(a) census over an arbitrary Lion corpus.

WHAT THIS ANSWERS (replay-check 2026-08-20T20:49Z §2.3, corrected 口径):
`liondrainstop` (hero_lion.lua:1112 `X.lion_ShouldStopDrain`) releases a
Mana Drain channel that has already started when the SAME pressure test that
refuses to start one is met.  Offline we cannot see `Action_ClearActions`, only
"the channel ended".  So a channel is evidence for (a) only if a release would
have produced an OBSERVABLY different channel end -- which needs the channel to
be long enough to cut.  The 20:49Z pre-flight found 5 of 6 in-domain channels
spanned <=1.1s on an 8-game corpus and registered a filter: **span >= 2.0s
first, then compare arms**.

THAT FILTER IS SUPERSEDED (director ruling 2026-08-21T15:0xZ on GH #86;
`state.json:liondrainstop_detector_20260821`).  On a 24x larger corpus the
replay stream measured the filter variable to be COMMON-CAUSED with the
outcome variable: in-domain channels under 2.0s end with Lion dead within 12s
in 12/24 cases, the ones the filter keeps in 6/40 (Fisher two-sided p=0.0040).
The mechanism is mechanical -- Lion dies, `modifier_lion_mana_drain` is
removed, so the channel is short BECAUSE he died -- which makes "long enough
to cut" a proxy for "that one went fine", and filtering on it throws away
exactly the class the gate exists for.

**PRIMARY criterion now: `post-domain residual` = channel end - first
in-domain timestamp**, over EVERY in-domain channel (no span filter, hence no
coupling), reported as mean/median/sd/n and compared per seed.  A working gate
collapses the armed side's residual to at most one sampling interval.
Judgement constraint (GH #86 section 5): require effect >= 2.0s, or a per-seed
paired read with >= 12 two-arm seeds; a ~1s shortening does NOT establish (a).
The span>=2.0s and `resolvable` columns are still computed and printed, but
only so archived readings stay reproducible -- they no longer gate anything.

The two frames that ruling pins are in `tests/fixtures/` (see
`tests/test_replay_260820_lion_drain_stop_pair.lua`): `20260820_162821_slot1`
t=307.4 (1.0s channel, Lion dead 1.5s later -- the class the filter discarded)
and `20260820_182906_slot1` t=606.5 (5.0s channel, Lion survives and the enemy
inside the radius dies) -- and the predicate answers HIGH on BOTH of them.

WHAT IT IS NOT: an execution check.  No wave has ever armed `liondrainstop`
(nor `liondrain`), so every reading here is COUNTERFACTUAL -- the corpus is the
gate-OFF base rate.  The `side` column says which side of the mirror was the
candidate side for OTHER ids; for this id both sides are gate-OFF, which is
exactly why the armed:base split is a NULL CHANNEL and is printed as such.

PREDICATE FIDELITY (all-stream rule U.1.1: every threshold verbatim from the
gate source):
  * `X.nEDrainDangerRadius = 500`                    (hero_lion.lua:1082)
  * `hBot:WasRecentlyDamagedByAnyHero( 2.0 )`        (hero_lion.lua:1125)
  * `J.GetNearbyHeroes( hBot, 500, true, ... )`      (hero_lion.lua:1127)
`WasRecentlyDamagedByAnyHero` is NOT captured by the dumper (a known capture
gap, charter "工具坑").  Proxy: a DAMAGE event with `target == Lion` and
`actor_hero == true` in `(t-2.0, t]`.  This is a superset-leaning proxy in one
direction only (it cannot see damage the engine attributes differently), and
the direction is registered in the output.

SAMPLING DISCIPLINE (charter 2026-08-21T10:51Z):
  * channel spans come from the EVENT stream (`MODIFIER_ADD` / `MODIFIER_REMOVE`
    of `modifier_lion_mana_drain`), 0.1s precision -- they are NOT grid
    quantised and do not move with `-interval`.
  * the DOMAIN test is evaluated on SNAPSHOTS and therefore IS grid limited.
    A channel shorter than the sampling interval can contain zero snapshots and
    is then structurally unclassifiable, so `zero_snap` channels are counted and
    printed separately instead of being silently folded into "not in domain".
  * every run prints the interval it read, and enemy state uses "the last
    snapshot <= t" (never a fixed offset, never `state_at`'s +/-2s tolerance).

TWO KNOWN CORPUS TRAPS, both handled and both counted:
  * `#69` same-name multiple entities: the main entity is the one with the
    EARLIEST first snapshot (never `hp_max`, never frame count).
  * `#78` corpse leak: `hp > 0` can still read a hero alive for <=~0.4s after
    its DEATH.  Here that would manufacture an enemy inside the 500u ring, i.e.
    a FALSE in-domain positive.  The count of qualifications that rest ONLY on
    such a frame is instrumented AFTER full domain qualification (charter: the
    instrumentation point decides the number's meaning) and printed.

Usage:
    lion_drain_census.py --timelines DIR [--json out.json]
    lion_drain_census.py --verify          # offline self-test, no corpus needed

`DIR` holds `<tag>.json` timelines plus a `stamps.json` mapping
`tag -> {seed, side, cand, run}` (written by the caller that downloaded them).
"""
from __future__ import annotations

import argparse
import bisect
import json
import math
import os
import sys

DANGER_RADIUS = 500.0          # hero_lion.lua:1082  X.nEDrainDangerRadius
DAMAGE_WINDOW = 2.0            # hero_lion.lua:1125  WasRecentlyDamagedByAnyHero(2.0)
RESOLVABLE_SPAN = 2.0          # SUPERSEDED filter -- kept as a reported column only
MIN_CUT = 0.5                  # a release must remove at least this much channel
LEAK_S = 0.5                   # #78: corpse frames observed up to ~0.4s after DEATH
LION = "npc_dota_hero_lion"
DRAIN_MOD = "modifier_lion_mana_drain"


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


class Corpus:
    """One game's timeline, reduced to what this census needs."""

    def __init__(self, d):
        self.events = sorted(d["events"], key=lambda e: e["t"])
        self.t_end = max((e["t"] for e in self.events), default=float("inf"))
        # ---- main-entity resolution (#69): earliest first snapshot wins.
        first_seen, by_key = {}, {}
        for s in d["snapshots"]:
            if s["t"] > self.t_end:
                continue          # dumper keeps emitting frozen post-game rows
            key = (s["hero"], s.get("idx"))
            by_key.setdefault(key, []).append(s)
            t = s["t"]
            if key not in first_seen or t < first_seen[key]:
                first_seen[key] = t
        self.main_idx = {}
        for (hero, idx), t0 in first_seen.items():
            cur = self.main_idx.get(hero)
            if cur is None or t0 < cur[1]:
                self.main_idx[hero] = (idx, t0)
        self.snaps = {}
        for (hero, idx), rows in by_key.items():
            if self.main_idx.get(hero, (None, None))[0] != idx:
                continue          # non-main entity: illusion or low-hp shell
            rows.sort(key=lambda s: s["t"])
            self.snaps[hero] = rows
        self.times = {h: [s["t"] for s in rows] for h, rows in self.snaps.items()}
        self.team = {h: rows[0]["team"] for h, rows in self.snaps.items() if rows}
        # sampling interval, measured not assumed
        self.interval = self._interval()
        # deaths per hero, for the #78 instrumentation
        self.deaths = {}
        for e in self.events:
            if e["type"] == "DEATH" and e.get("target_hero") and e["target"].startswith("npc_dota_hero_"):
                self.deaths.setdefault(e["target"], []).append(e["t"])
        # hero damage taken by Lion
        self.lion_hits = sorted(e["t"] for e in self.events
                                if e["type"] == "DAMAGE" and e.get("target") == LION
                                and e.get("actor_hero"))

    def _interval(self):
        rows = self.snaps.get(LION) or next(iter(self.snaps.values()), [])
        gaps = sorted(round(b - a, 3) for a, b in zip([s["t"] for s in rows],
                                                     [s["t"] for s in rows][1:]))
        return gaps[len(gaps) // 2] if gaps else None

    def last_snap_le(self, hero, t):
        """The last snapshot at or before t -- never a fixed offset (charter
        2026-08-21T09Z trap (4)), never a +/- tolerance window."""
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
        """True if t sits in the #78 corpse-leak shadow of a DEATH."""
        for td in self.deaths.get(hero, ()):
            if td <= t < td + LEAK_S:
                return True
        return False


def channels(c):
    """MODIFIER_ADD -> MODIFIER_REMOVE pairs of the drain modifier, per target.
    Spans come from events (0.1s), not from the snapshot grid."""
    open_at, out = {}, []
    for e in c.events:
        if e.get("inflictor") != DRAIN_MOD or e.get("actor") != LION:
            continue
        tgt = e.get("target")
        if e["type"] == "MODIFIER_ADD":
            open_at.setdefault(tgt, []).append(e["t"])
        elif e["type"] == "MODIFIER_REMOVE" and open_at.get(tgt):
            t0 = open_at[tgt].pop(0)
            out.append({"t0": t0, "t1": e["t"], "target": tgt,
                        "target_hero": tgt.startswith("npc_dota_hero_")})
    return sorted(out, key=lambda ch: ch["t0"])


def classify(c, ch):
    """Evaluate the gate predicate on every snapshot inside the channel."""
    lion_rows = c.snaps.get(LION, [])
    inside = [s for s in lion_rows if ch["t0"] <= s["t"] <= ch["t1"]]
    ch["span"] = round(ch["t1"] - ch["t0"], 2)
    ch["n_snaps"] = len(inside)
    ch["zero_snap"] = not inside
    ch["in_domain"] = False
    ch["t_domain"] = None
    ch["leak_only"] = False
    lion_team = c.team.get(LION)
    for s in inside:
        if s["hp"] <= 0:
            continue                      # Lion's own corpse frame
        if not c.damaged_recently(s["t"]):
            continue
        near, near_leak_only = [], True
        for hero, rows in c.snaps.items():
            if hero == LION or c.team.get(hero) == lion_team:
                continue
            es = c.last_snap_le(hero, s["t"])
            if not es or es["hp"] <= 0:
                continue
            if c.interval and s["t"] - es["t"] > c.interval + 1e-6:
                continue                  # stale read: no fresh sample for this enemy
            if dist((s["x"], s["y"]), (es["x"], es["y"])) > DANGER_RADIUS:
                continue
            near.append(hero)
            if not c.just_died(hero, es["t"]):
                near_leak_only = False
        if not near:
            continue
        # full domain qualification reached -- instrument HERE, not earlier
        ch["in_domain"] = True
        ch["t_domain"] = round(s["t"], 2)
        ch["near"] = near
        ch["leak_only"] = near_leak_only
        break
    ch["resolvable"] = bool(ch["in_domain"] and ch["span"] >= RESOLVABLE_SPAN
                            and (ch["t1"] - ch["t_domain"]) >= MIN_CUT)
    # PRIMARY criterion (director ruling 2026-08-21T15:0xZ, GH #86): how much
    # channel is still running at the moment the gate would have cut it. Defined
    # on EVERY in-domain channel -- no span filter, hence no coupling with the
    # outcome -- and continuous, so a per-seed paired mean has power the
    # release COUNT never had. Gate working => this collapses to <= one
    # sampling interval on the armed side.
    ch["residual"] = (round(ch["t1"] - ch["t_domain"], 2)
                      if ch["in_domain"] else None)
    return ch


def residual_stats(chs):
    """mean / median / sd / n of post-domain residual over in-domain channels."""
    xs = sorted(ch["residual"] for ch in chs if ch["residual"] is not None)
    n = len(xs)
    if n == 0:
        return {"n": 0, "mean": None, "median": None, "sd": None}
    mean = sum(xs) / n
    median = xs[n // 2] if n % 2 else (xs[n // 2 - 1] + xs[n // 2]) / 2.0
    sd = (sum((x - mean) ** 2 for x in xs) / (n - 1)) ** 0.5 if n > 1 else 0.0
    return {"n": n, "mean": round(mean, 3), "median": round(median, 3),
            "sd": round(sd, 3)}


def census(tl, meta):
    c = Corpus(tl)
    if LION not in c.snaps:
        return None
    lion_team = c.team[LION]
    # side stamp: `mirror:<cand>:s<seed>:<side>` names the CANDIDATE side.
    cand_team = 2 if meta.get("side") == "radiant" else 3
    rows = [classify(c, ch) for ch in channels(c)]
    return {
        "tag": meta.get("tag"), "run": meta.get("run"), "seed": meta.get("seed"),
        "side": meta.get("side"), "cand": meta.get("cand"),
        "interval": c.interval, "t_end": c.t_end,
        "lion_on_cand_side": lion_team == cand_team,
        "channels": rows,
    }


def summarise(games):
    def agg(sel):
        chs = [ch for g in games if sel(g) for ch in g["channels"]]
        dom = [ch for ch in chs if ch["in_domain"]]
        return {
            "games": sum(1 for g in games if sel(g)),
            "channels": len(chs),
            "hero_target": sum(1 for ch in chs if ch["target_hero"]),
            "zero_snap": sum(1 for ch in chs if ch["zero_snap"]),
            "in_domain": len(dom),
            "in_domain_leak_only": sum(1 for ch in dom if ch["leak_only"]),
            "span_ge_2": sum(1 for ch in chs if ch["span"] >= RESOLVABLE_SPAN),
            "resolvable": sum(1 for ch in chs if ch["resolvable"]),
            "residual": residual_stats(chs),
        }
    return {
        "all": agg(lambda g: True),
        "lion_cand_side": agg(lambda g: g["lion_on_cand_side"]),
        "lion_base_side": agg(lambda g: not g["lion_on_cand_side"]),
    }


def _verify():
    """Self-test on a hand-built timeline; no corpus, no S3."""
    def snap(hero, t, x, y, hp=500, team=2, idx=1):
        return {"hero": hero, "t": t, "x": x, "y": y, "hp": hp, "hp_pct": hp / 500.0,
                "team": team, "idx": idx}
    ev = [
        {"t": 10.0, "type": "MODIFIER_ADD", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 15.0, "type": "MODIFIER_REMOVE", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 11.5, "type": "DAMAGE", "actor": "npc_dota_hero_luna", "target": LION,
         "inflictor": "x", "actor_hero": True, "target_hero": True},
        # a short channel: starts and ends inside one sampling interval
        {"t": 30.0, "type": "MODIFIER_ADD", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 30.4, "type": "MODIFIER_REMOVE", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 60.0, "type": "DEATH", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": "x", "actor_hero": True, "target_hero": True},
    ]
    sn = []
    for t in [x / 2.0 for x in range(0, 140)]:
        sn.append(snap(LION, t, 0, 0, team=2))
        sn.append(snap("npc_dota_hero_luna", t, 300, 0, team=3))
    tl = {"events": ev, "snapshots": sn, "game": {"teams": {}}}
    g = census(tl, {"tag": "t", "side": "radiant", "seed": "1"})
    chs = g["channels"]
    assert len(chs) == 2, chs
    a, b = chs
    assert a["span"] == 5.0 and b["span"] == 0.4, (a["span"], b["span"])
    # channel A: damaged at 11.5, luna 300u away -> in domain from 11.5 on
    assert a["in_domain"] and a["t_domain"] == 11.5, a
    assert a["resolvable"], a          # 5.0s span, 3.5s left to cut
    # channel B: no hero damage in (28.4, 30.4] -> not in domain
    assert not b["in_domain"] and not b["resolvable"], b
    # span filter is independent of the domain test
    s = summarise([g])
    assert s["all"]["channels"] == 2 and s["all"]["span_ge_2"] == 1, s
    assert s["all"]["in_domain"] == 1 and s["all"]["resolvable"] == 1, s
    assert s["all"]["hero_target"] == 2, s
    assert g["interval"] == 0.5, g["interval"]
    # zero-snapshot channels are counted, never folded into "not in domain"
    tl2 = {"events": ev, "snapshots": [s2 for s2 in sn if not (30.0 <= s2["t"] <= 30.4)],
           "game": {"teams": {}}}
    g2 = census(tl2, {"tag": "t", "side": "radiant", "seed": "1"})
    assert g2["channels"][1]["zero_snap"], g2["channels"][1]
    assert summarise([g2])["all"]["zero_snap"] == 1
    # #78 instrumentation: an enemy frame inside the corpse-leak shadow
    ev2 = list(ev) + [
        {"t": 100.0, "type": "MODIFIER_ADD", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 104.0, "type": "MODIFIER_REMOVE", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 100.5, "type": "DAMAGE", "actor": "npc_dota_hero_luna", "target": LION,
         "inflictor": "x", "actor_hero": True, "target_hero": True},
        {"t": 100.4, "type": "DEATH", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": "x", "actor_hero": True, "target_hero": True},
    ]
    sn2 = list(sn)
    for t in [100.0, 100.5, 101.0, 101.5, 102.0, 102.5, 103.0, 103.5, 104.0]:
        sn2.append(snap(LION, t, 0, 0, team=2))
        # luna is dead from 100.4, but her 100.5 frame still reads hp > 0 (#78);
        # every later frame is a proper corpse.
        sn2.append(snap("npc_dota_hero_luna", t, 300, 0,
                        hp=500 if t <= 100.5 else 0, team=3))
    tl3 = {"events": ev2, "snapshots": sn2, "game": {"teams": {}}}
    g3 = census(tl3, {"tag": "t", "side": "radiant", "seed": "1"})
    ch = [c2 for c2 in g3["channels"] if c2["t0"] == 100.0][0]
    assert ch["in_domain"] and ch["leak_only"], ch
    assert summarise([g3])["all"]["in_domain_leak_only"] == 1
    # main-entity resolution (#69): a later-appearing shell must not be read
    sn3 = list(sn) + [snap("npc_dota_hero_luna", 40.0, 0, 0, hp=8, team=3, idx=999)]
    g4 = census({"events": ev, "snapshots": sn3, "game": {"teams": {}}},
                {"tag": "t", "side": "radiant", "seed": "1"})
    assert g4["channels"][0]["in_domain"], "main entity lost to the shell"

    # ---- PRIMARY criterion: post-domain residual (GH #86 / ruling 15:0xZ) ----
    # channel A ends at 15.0 and enters the domain at 11.5 -> 3.5s still running
    assert a["residual"] == 3.5, a
    # a channel outside the domain has no residual at all (never 0.0, which
    # would silently read as "the gate had nothing left to cut")
    assert b["residual"] is None, b
    st = summarise([g])["all"]["residual"]
    assert st["n"] == 1 and st["mean"] == 3.5 and st["median"] == 3.5, st
    assert st["sd"] == 0.0, st
    # THE POINT of the change: the residual is defined on in-domain channels
    # the superseded span filter would have thrown away. Build one: a 1.2s
    # channel that enters the domain immediately -- span < 2.0 (filtered out)
    # but 1.2s of channel left to cut (real evidence).
    ev3 = [
        {"t": 200.0, "type": "MODIFIER_ADD", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 201.2, "type": "MODIFIER_REMOVE", "actor": LION, "target": "npc_dota_hero_luna",
         "inflictor": DRAIN_MOD, "actor_hero": True, "target_hero": True},
        {"t": 199.8, "type": "DAMAGE", "actor": "npc_dota_hero_luna", "target": LION,
         "inflictor": "x", "actor_hero": True, "target_hero": True},
    ]
    sn4 = []
    for t in [199.5 + x / 2.0 for x in range(0, 8)]:
        sn4.append(snap(LION, t, 0, 0, team=2))
        sn4.append(snap("npc_dota_hero_luna", t, 300, 0, team=3))
    g5 = census({"events": ev3, "snapshots": sn4, "game": {"teams": {}}},
                {"tag": "t", "side": "radiant", "seed": "1"})
    c5 = g5["channels"][0]
    assert c5["in_domain"] and c5["span"] < RESOLVABLE_SPAN, c5
    assert not c5["resolvable"], "the superseded filter would have dropped it"
    assert c5["residual"] == 1.2, c5      # the new criterion keeps it
    print("lion_drain_census --verify: 25 asserts OK")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--timelines")
    ap.add_argument("--json")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    if a.verify:
        _verify()
        return
    if not a.timelines:
        ap.error("--timelines DIR required")
    stamps = json.load(open(os.path.join(a.timelines, "stamps.json")))
    games = []
    for tag, meta in sorted(stamps.items()):
        p = os.path.join(a.timelines, tag + ".json")
        if not os.path.exists(p):
            continue
        meta = dict(meta, tag=tag)
        g = census(json.load(open(p)), meta)
        if g:
            games.append(g)
    s = summarise(games)
    ivals = sorted({g["interval"] for g in games})
    print("games with Lion: %d   sampling interval(s) read: %s" % (len(games), ivals))
    print("PRIMARY criterion: post-domain residual (director ruling "
          "2026-08-21T15:0xZ / GH #86). The span>=2.0s columns below are the "
          "SUPERSEDED filter, printed for continuity with archived readings "
          "ONLY -- it is common-caused with the outcome (in-domain channels "
          "under 2.0s end with Lion dead within 12s 12/24 vs 6/40; Fisher "
          "p=0.0040), so it must never gate an arms comparison again.")
    for k in ("all", "lion_cand_side", "lion_base_side"):
        v = s[k]
        r = v["residual"]
        print("%-15s games %3d  channels %4d (hero-target %3d, zero-snap %3d)  "
              "in-domain %3d (leak-only %d)  RESIDUAL n=%d mean=%s median=%s sd=%s"
              "   [superseded: span>=2.0s %3d  resolvable %3d]"
              % (k, v["games"], v["channels"], v["hero_target"], v["zero_snap"],
                 v["in_domain"], v["in_domain_leak_only"],
                 r["n"], r["mean"], r["median"], r["sd"],
                 v["span_ge_2"], v["resolvable"]))
    print("judgement constraint (GH #86 §5): a residual shortening of ~1s does "
          "NOT establish (a); require effect >= 2.0s, or a per-seed paired read "
          "with >= 12 two-arm seeds. Gate-OFF baseline measured by the replay "
          "stream over 196 archive games: mean 1.91 / median 1.6 / sd 1.66, n=64.")
    if a.json:
        json.dump({"summary": s, "games": games}, open(a.json, "w"), indent=1)
        print("wrote", a.json)


if __name__ == "__main__":
    main()

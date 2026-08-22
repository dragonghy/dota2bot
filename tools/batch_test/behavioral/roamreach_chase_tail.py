#!/usr/bin/env python3
"""Out-of-reach hero-pursuit ("chase tail") scanner for the `roamreach` arm.

WHAT `roamreach` DOES (bots/mode_team_roam_generic.lua:542-578, GH #45).  When
team_roam's Think() has a HERO target further away than the bot's own threat
reach (attack range, or the cast range of a levelled+castable ability), the
shipped code issues `Action_AttackUnit(target, false)` -- a CONTINUOUS order
that outlives the one-frame desire that justified it, because the only leash
this mode owns lives in a Think() the engine stops calling once another mode
wins the auction.  Armed, that same frame gets
`Action_MoveToLocation(target:GetLocation())` -- a FINITE order.  While the
mode keeps winning, the approach is re-issued every frame and is unchanged;
the difference is what happens AFTER the mode loses the auction: the shipped
order keeps dragging the bot after a moving target, the armed one expires
roughly one target-distance later.

SO THE OBSERVABLE IS THE TAIL, NOT THE APPROACH.  This scanner measures
zero-damage pursuits of an enemy hero on 1Hz snapshots and reports, per side:
how many there are (supply), how long they last, how far the bot walked
inside them, and -- the discriminating column -- what the bot does in the
seconds right after the pursuit band is left.

DOMAIN (deliberately empirical, not a reconstructed predicate).  Snapshots
carry ability level and cooldown but NOT cast range, so `_roamreach_
ThreatReach` cannot be rebuilt offline without a per-ability range table.
Instead of guessing it, an episode requires that the bot dealt NO damage to
that enemy for its whole span: "could do nothing to it" is measured, not
inferred.  The band [D_LO, D_HI] is the #45 ring widened to the leash.

HONEST BOUNDARIES (do not let a reader take more than this measures):
  * The mode that owns a frame is NOT visible in a replay dump.  Episodes
    therefore pool team_roam pursuits with every other reason a bot walks at
    an enemy hero without damaging it.  Armed can only touch the team_roam
    subset, so any effect here is DILUTED, and a null is not proof of SILENT.
  * This is a within-game candidate-vs-baseline leg on a mirrored wave whose
    two sides play each other (director ruling, test_set.md AG / GH #94).  It
    is one leg, not an isolated estimator; per-side absolute counts and the
    supply ratio are printed with every rate for that reason.
  * `hp > 0` as an alive test leaks about one frame after a death (#78), and
    Wraith King reincarnates in place.  Both are noted where they can bite.

Identity: snapshots are locked to each hero's PRIMARY entity (the idx that
appears earliest -- illusions/copies enter later), per the replay-check
charter's 2026-08-22 rule.  Without the lock a copy's coordinates silently
enter the geometry (measured elsewhere at 2.80% of position lookups, median
error 3,087u).

Usage:
    roamreach_chase_tail.py <sweep_out_dir> [<sweep_out_dir> ...]
    roamreach_chase_tail.py --episodes <sweep_out_dir> ...   # dump episodes
    roamreach_chase_tail.py --selfcheck <sweep_out_dir> ...  # invariants

Read-only; no AWS, no billable resource.
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detect  # noqa: E402  -- pause spans + event canonicalisation, shared on purpose

D_LO = 700.0        # inside this almost anything can act; below the #45 ring's floor
D_HI = 1600.0       # team_roam's own leash is 1800; stay inside it
MIN_FRAMES = 4      # >= 4 samples in band (>= ~4s at the 1.0s default interval)
APPROACH_COS = 0.5  # frame counts as "walking at him"
MOVE_MIN = 100.0    # ... and actually moving (ties/holds excluded explicitly)
TAIL_S = 4.0        # window after the episode for the tail measurements
DMG_PAD = 1.0       # snapshots lag the event stream (#41/LAG_S convention)


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


IDX_LOCK = True     # --legacy-merge-by-name turns this off, for delta measurement


class Frames:
    """idx-locked per-hero snapshot track."""

    def __init__(self, d):
        self.teams = d["game"]["teams"]
        first_seen = collections.defaultdict(dict)   # hero -> idx -> earliest t
        for s in d["snapshots"]:
            fs = first_seen[s["hero"]]
            i = s.get("idx")
            if i is None:
                raise SystemExit("snapshot without idx: dumper too old for this tool")
            if i not in fs or s["t"] < fs[i]:
                fs[i] = s["t"]
        self.primary = {h: min(v.items(), key=lambda kv: (kv[1], kv[0]))[0]
                        for h, v in first_seen.items()}
        self.dropped = 0
        self.track = collections.defaultdict(list)
        t_end = max((e["t"] for e in d["events"]), default=float("inf"))
        for s in d["snapshots"]:
            if s["t"] > t_end:          # post-game frozen tail (#43)
                continue
            if IDX_LOCK and s.get("idx") != self.primary.get(s["hero"]):
                self.dropped += 1
                continue
            self.track[s["hero"]].append(s)
        for h in self.track:
            self.track[h].sort(key=lambda s: s["t"])
        self.times = {h: [s["t"] for s in v] for h, v in self.track.items()}
        self.heroes = [h for h in self.teams if h in self.track]

    def interval(self):
        gaps = []
        for h, ts in self.times.items():
            gaps += [round(b - a, 3) for a, b in zip(ts, ts[1:])]
        return collections.Counter(gaps).most_common(1)[0][0] if gaps else None

    def at(self, hero, t, tol):
        """Last frame at or before t, but only if it is within one sample."""
        ts = self.times.get(hero)
        if not ts:
            return None
        import bisect
        i = bisect.bisect_right(ts, t) - 1
        if i < 0:
            return None
        s = self.track[hero][i]
        return s if (t - s["t"]) <= tol else None


def hero_damage_spans(d):
    """(actor, target) -> sorted list of damage-event times, canonical names."""
    tl_events = detect.Timeline(d).events   # reuse the canonicaliser (#82)
    out = collections.defaultdict(list)
    for e in tl_events:
        if e["type"] == "DAMAGE" and e.get("actor_hero") and e.get("target_hero"):
            out[(e["actor"], e["target"])].append(e["t"])
    for k in out:
        out[k].sort()
    return out


def any_dmg(dmg, actor, target, t0, t1):
    import bisect
    ts = dmg.get((actor, target))
    if not ts:
        return False
    i = bisect.bisect_left(ts, t0)
    return i < len(ts) and ts[i] <= t1


def scan_game(path, pause_spans=None):
    d = json.load(open(path))
    fr = Frames(d)
    dmg = hero_damage_spans(d)
    tol = (fr.interval() or 1.0) * 1.5
    tl = detect.Timeline(d)
    pauses = detect._paused_spans(tl)

    def paused(t0, t1):
        return any(not (t1 < a or t0 > b) for a, b in pauses)

    eps = []
    for bot in fr.heroes:
        tb = fr.teams.get(bot)
        for foe in fr.heroes:
            if fr.teams.get(foe) == tb or not tb:
                continue
            ts = fr.times[bot]
            run = []
            for i, t in enumerate(ts):
                s = fr.track[bot][i]
                nxt = fr.track[bot][i + 1] if i + 1 < len(ts) else None
                e = fr.at(foe, t, tol)
                ok = False
                if e is not None and nxt is not None and s["hp"] > 0 and e["hp"] > 0:
                    dd = dist((s["x"], s["y"]), (e["x"], e["y"]))
                    if D_LO <= dd <= D_HI:
                        mv = (nxt["x"] - s["x"], nxt["y"] - s["y"])
                        mvlen = math.hypot(*mv)
                        to = (e["x"] - s["x"], e["y"] - s["y"])
                        tolen = math.hypot(*to) or 1.0
                        if mvlen >= MOVE_MIN:
                            cos = (mv[0] * to[0] + mv[1] * to[1]) / (mvlen * tolen)
                            ok = cos >= APPROACH_COS
                if ok:
                    run.append(i)
                else:
                    if len(run) >= MIN_FRAMES:
                        eps.append((bot, foe, run))
                    run = []
            if len(run) >= MIN_FRAMES:
                eps.append((bot, foe, run))

    out = []
    for bot, foe, run in eps:
        i0, i1 = run[0], run[-1]
        t0, t1 = fr.times[bot][i0], fr.times[bot][i1]
        if paused(t0, t1 + TAIL_S):
            continue
        if any_dmg(dmg, bot, foe, t0 - DMG_PAD, t1 + DMG_PAD):
            continue                      # he could act on it -> not out of reach
        pts = [(fr.track[bot][i]["x"], fr.track[bot][i]["y"]) for i in run]
        path_len = sum(dist(a, b) for a, b in zip(pts, pts[1:]))
        dmin = min(dist((fr.track[bot][i]["x"], fr.track[bot][i]["y"]),
                        ((lambda e: (e["x"], e["y"]))(fr.at(foe, fr.times[bot][i], tol))))
                   for i in run if fr.at(foe, fr.times[bot][i], tol))
        # tail: what the bot does in TAIL_S after the last in-band frame
        s_end = fr.track[bot][i1]
        s_tail = fr.at(bot, t1 + TAIL_S, tol)
        tail_move = (dist((s_end["x"], s_end["y"]), (s_tail["x"], s_tail["y"]))
                     if s_tail else None)
        e_end = fr.at(foe, t1, tol)
        e_tail = fr.at(foe, t1 + TAIL_S, tol)
        # did the pursuit convert (any damage on that foe in the tail window)?
        converted = any_dmg(dmg, bot, foe, t1, t1 + TAIL_S + DMG_PAD)
        # is the bot still following him (distance kept in band / shrinking)?
        still_chasing = None
        if s_tail and e_tail:
            d_end = dist((s_end["x"], s_end["y"]), (e_end["x"], e_end["y"])) if e_end else None
            d_tail = dist((s_tail["x"], s_tail["y"]), (e_tail["x"], e_tail["y"]))
            if d_end is not None:
                still_chasing = d_tail <= d_end + 150.0
        # --- the fingerprint of a FINITE order -------------------------------
        # Armed, the last order this mode issued was MoveToLocation(foe's
        # position at that frame).  When the mode stops winning, the bot walks
        # out that leftover order and stops ON THAT OLD POINT while the foe
        # keeps going.  The shipped continuous attack order instead keeps
        # closing on the foe's LIVE position.  So: at t1+TAIL_S, is the bot
        # parked on the stale point with the foe long gone?
        stale_lock = None
        if s_tail and e_end:
            d_stale = dist((s_tail["x"], s_tail["y"]), (e_end["x"], e_end["y"]))
            d_live = (dist((s_tail["x"], s_tail["y"]), (e_tail["x"], e_tail["y"]))
                      if e_tail else None)
            if d_live is not None:
                stale_lock = (d_stale <= 400.0 and d_live >= 1200.0)
        out.append(dict(
            stale_lock=stale_lock,
            game=os.path.basename(path).split(".")[0], bot=bot, foe=foe,
            t0=t0, t1=t1, dur=t1 - t0, frames=len(run), path=path_len,
            dmin=dmin, tail_move=tail_move, converted=converted,
            still_chasing=still_chasing,
            bot_team=fr.teams[bot],
        ))
    return out, fr, tol


def frame_view(path, bot, foe, t0, t1, pad=6.0):
    """Frame-by-frame reconstruction of one pursuit, with vision context.

    Prints, for every sample in [t0-pad, t1+pad]: both positions, the distance,
    both HP fractions, the bot's step vector, and how many living allies /
    enemies of the bot are within 1200u -- i.e. what the bot could actually see
    when it kept walking.  The STALE column is the key one for `roamreach`: the
    distance from the bot's CURRENT position to where the foe stood at the
    moment the pursuit's last in-band frame was taken.  A bounded move
    (Action_MoveToLocation) converges on that old point and stops; a continuous
    attack order keeps closing on the foe's LIVE position instead.
    """
    d = json.load(open(path))
    fr = Frames(d)
    tol = (fr.interval() or 1.0) * 1.5
    dmg = hero_damage_spans(d)
    tl = detect.Timeline(d)
    e_end = fr.at(foe, t1, tol)
    stale_pt = (e_end["x"], e_end["y"]) if e_end else None
    print("== %s  %s -> %s  [%.1f, %.1f] (stale point = foe at t=%.1f: %s)"
          % (os.path.basename(path).split(".")[0], bot, foe, t0, t1, t1, stale_pt))
    print("   t     bot(x,y)         foe(x,y)        dist  botHP foeHP  step  "
          "stale  allies<1200 enemies<1200")
    for s in fr.track[bot]:
        t = s["t"]
        if not (t0 - pad <= t <= t1 + pad):
            continue
        e = fr.at(foe, t, tol)
        if not e:
            continue
        i = fr.times[bot].index(t)
        nxt = fr.track[bot][i + 1] if i + 1 < len(fr.times[bot]) else None
        step = dist((s["x"], s["y"]), (nxt["x"], nxt["y"])) if nxt else float("nan")
        allies = sum(1 for h in fr.heroes
                     if h != bot and fr.teams[h] == fr.teams[bot]
                     and (fr.at(h, t, tol) or {}).get("hp", 0) > 0
                     and dist((s["x"], s["y"]),
                              ((fr.at(h, t, tol) or {}).get("x", 1e9),
                               (fr.at(h, t, tol) or {}).get("y", 1e9))) <= 1200)
        foes = sum(1 for h in fr.heroes
                   if fr.teams[h] != fr.teams[bot]
                   and (fr.at(h, t, tol) or {}).get("hp", 0) > 0
                   and dist((s["x"], s["y"]),
                            ((fr.at(h, t, tol) or {}).get("x", 1e9),
                             (fr.at(h, t, tol) or {}).get("y", 1e9))) <= 1200)
        mark = "*" if t0 <= t <= t1 else " "
        print("%s%6.1f (%6d,%6d) (%6d,%6d) %6.0f  %.2f  %.2f %5.0f %6.0f      %d          %d"
              % (mark, t, s["x"], s["y"], e["x"], e["y"],
                 dist((s["x"], s["y"]), (e["x"], e["y"])),
                 s["hp_pct"], e["hp_pct"], step,
                 dist((s["x"], s["y"]), stale_pt) if stale_pt else float("nan"),
                 allies, foes))
    ev = [e for e in tl.events
          if t0 - pad <= e["t"] <= t1 + pad
          and (e.get("actor") in (bot, foe) or e.get("target") in (bot, foe))
          and e["type"] in ("DAMAGE", "ABILITY", "DEATH", "ITEM")]
    print("   events:")
    for e in ev:
        print("   %6.1f %-8s %-30s -> %-30s %s %s"
              % (e["t"], e["type"], str(e.get("actor"))[14:], str(e.get("target"))[14:],
                 e.get("inflictor", ""), e.get("value", "")))


def load_manifest(d):
    out = {}
    p = os.path.join(d, "games_manifest.jsonl")
    if not os.path.exists(p):
        raise SystemExit("no games_manifest.jsonl in %s" % d)
    for line in open(p):
        r = json.loads(line)
        out[r["game"]] = r
    return out


def completeness_guard(d):
    """#102: a half-dead sweep dir looks exactly like a finished one."""
    summary = os.path.join(d, "sweep_summary.md")
    if not os.path.exists(summary):
        raise SystemExit("%s: no sweep_summary.md (sweep did not finish)" % d)
    man = load_manifest(d)
    txt = open(summary).read()
    for line in txt.splitlines():
        if line.strip().startswith("games swept"):
            # "games swept: 3 (skipped 1 warmup/unstamped)" -- the FIRST integer
            # after the colon is the count; concatenating every digit on the
            # line reads "31" and turns the guard into a false alarm.
            n = int(line.split(":", 1)[1].split()[0])
            if n != len(man):
                raise SystemExit("%s: summary says %d games, manifest has %d"
                                 % (d, n, len(man)))
    return man


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--episodes", action="store_true")
    ap.add_argument("--frame-view", metavar="GAME:BOT:FOE:T0:T1",
                    help="frame-by-frame reconstruction of one pursuit "
                         "(hero names without the npc_dota_hero_ prefix)")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--legacy-merge-by-name", action="store_true",
                    help="merge every same-named entity (pre-idx-lock behaviour); "
                         "for measuring what the lock changes, never for reporting")
    a = ap.parse_args()
    if a.legacy_merge_by_name:
        globals()["IDX_LOCK"] = False
        print("!! LEGACY merge-by-name: illusions/copies are IN the geometry")

    if a.frame_view:
        game, bot, foe, t0, t1 = a.frame_view.split(":")
        for d in a.dirs:
            p = os.path.join(d, "timelines", game + ".timeline.json")
            if os.path.exists(p):
                frame_view(p, "npc_dota_hero_" + bot, "npc_dota_hero_" + foe,
                           float(t0), float(t1))
                return
        raise SystemExit("game %s not found under the given dirs" % game)

    rows, cands, intervals = [], set(), set()
    games = 0
    for d in a.dirs:
        man = completeness_guard(d)
        for tlf in sorted(glob.glob(os.path.join(d, "timelines", "*.timeline.json"))):
            name = os.path.basename(tlf).split(".")[0]
            if name not in man:
                continue
            m = man[name]
            cands.add(m["cand"])
            eps, fr, tol = scan_game(tlf)
            intervals.add(fr.interval())
            side_team = {"radiant": 2, "dire": 3}[m["side"]]
            for e in eps:
                e["seed"] = m["seed"]
                e["armed"] = (e["bot_team"] == side_team)
                e["run"] = os.path.basename(d.rstrip("/"))[5:20]
                rows.append(e)
            games += 1
    if len(cands) != 1:
        raise SystemExit("directories disagree on the armed id: %s" % sorted(cands))
    print("# roamreach chase-tail scan")
    print("cand=%s  games=%d  sample interval(s)=%s  band=[%g,%g] min_frames=%d"
          % (sorted(cands)[0], games, sorted(intervals), D_LO, D_HI, MIN_FRAMES))

    if a.episodes:
        for e in sorted(rows, key=lambda r: -r["dur"]):
            print("%-22s %-28s -> %-28s %6.1f-%6.1f dur=%4.1f path=%6.0f dmin=%5.0f "
                  "tail=%s conv=%s follow=%s %s"
                  % (e["game"], e["bot"][14:], e["foe"][14:], e["t0"], e["t1"], e["dur"],
                     e["path"], e["dmin"],
                     ("%5.0f" % e["tail_move"]) if e["tail_move"] is not None else "  n/a",
                     int(e["converted"]),
                     e["still_chasing"], "ARMED" if e["armed"] else "base"))
        print()

    def block(sel, label):
        eps = [r for r in rows if sel(r)]
        n = len(eps)
        if not n:
            print("%-10s n=0" % label)
            return
        longs = [r for r in eps if r["dur"] >= 6.0]
        vlongs = [r for r in eps if r["dur"] >= 9.0]
        tails = [r["tail_move"] for r in eps if r["tail_move"] is not None]
        follow = [r for r in eps if r["still_chasing"] is True]
        conv = [r for r in eps if r["converted"]]
        lock = [r for r in eps if r["stale_lock"] is True]
        print("%-10s n=%-4d /game %5.2f | dur mean %4.2f max %4.1f | >=6s %3d (%4.1f%%) "
              "| >=9s %2d | path mean %5.0f | tail move mean %5.0f | still-chasing %4.1f%% "
              "| converted %4.1f%% | stale-lock %2d (%4.1f%%)"
              % (label, n, n / games, sum(r["dur"] for r in eps) / n,
                 max(r["dur"] for r in eps), len(longs), 100.0 * len(longs) / n,
                 len(vlongs), sum(r["path"] for r in eps) / n,
                 (sum(tails) / len(tails)) if tails else float("nan"),
                 100.0 * len(follow) / n, 100.0 * len(conv) / n,
                 len(lock), 100.0 * len(lock) / n))

    print()
    block(lambda r: r["armed"], "ARMED")
    block(lambda r: not r["armed"], "baseline")
    na = len([r for r in rows if r["armed"]])
    nb = len(rows) - na
    print("\nsupply ratio armed/baseline = %.2f  (%d vs %d episodes over %d games)"
          % ((na / nb) if nb else float("nan"), na, nb, games))
    print("per-game absolute: armed %.2f, baseline %.2f episodes/game"
          % (na / games, nb / games))

    by_seed = collections.defaultdict(lambda: [0, 0])
    for r in rows:
        by_seed[r["seed"]][0 if r["armed"] else 1] += 1
    print("\nby seed (armed, baseline): " +
          "  ".join("s%s %d/%d" % (s, v[0], v[1]) for s, v in sorted(by_seed.items())))

    if a.selfcheck:
        bad = [r for r in rows if r["dur"] < (MIN_FRAMES - 1) * 0.5]
        assert not bad, "episode shorter than MIN_FRAMES allows: %s" % bad[:1]
        assert all(D_LO - 1 <= r["dmin"] <= D_HI + 1 for r in rows), "dmin outside band"
        print("\nselfcheck OK: %d episodes, all within band and length invariants" % len(rows))


if __name__ == "__main__":
    main()

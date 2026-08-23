#!/usr/bin/env python3
"""Who owns the home-TPs made at HIGH health?  (replay-check 18:36Z)

Background.  17:09Z measured `stayfield`'s domain and found the single largest
disqualifying clause was *health*: **22.4% of every home-TP in the corpus is
made above 55% HP** (armed 318 / baseline 325).  `stayfield` cannot touch that
population by construction -- its helper's own band is [0.18, 0.55]
(`jmz_func.lua:4762`) -- so the question this tool answers is not "does the gate
work" but **"is that 22.4% a defect population at all, and if so whose?"**

Method: attribution by NECESSARY CONDITION, not by guessing.  Every branch in
`X.ConsiderItemDesire["item_tpscroll"]` that can send a bot to its own fountain
was read out of the source, and for each one the sub-clauses that are *visible
in a replay dump* are evaluated on the **last frame before the TP channel
opens** (charter #66 sec.0 -- a cast frame is not the frame after the cast).
A branch whose necessary condition is false on that frame **cannot** have
produced the TP.  Labels are therefore multi-label and conservative:

  shop      `X.IsInvFull` + no enemy in 1600  -- the "Go complete items" branch
            (`ability_item_usage_generic.lua:5194-5201`, motive 撤退:1).  Full
            9 slots is checkable offline; the stash is NOT networked to the
            replay, so this label is NECESSARY-ONLY, never sufficient.
  escape2   撤退:2 (`:5140-5147` band `hp < 0.15 + 0.24*nEnemyCount`, damaged by
            a hero within 6s, <=3 enemies).  The only retreat branch whose HP
            band reaches above 0.55 at all -- and only with >=2 enemies on it.
  rupture   躲血魔大 (`:5873`): carries `modifier_bloodseeker_rupture`.
  defend    a home-side building of OWN team within DEFEND_U of the landing
            spot loses HP in [t_land-15, t_land+20], or an enemy hero comes
            within DEFEND_U of the landing spot inside 20s.  This is the
            observable shadow of 前往守塔 / 守护遗迹 / 保护遗迹, whose landing
            points (T3/T4/ancient) sit inside the fountain ring this tool uses
            to define "home".
  (none)    no branch condition holds -> UNEXPLAINED.  These are the rows worth
            frame-checking by hand; the tool prints them, it does not judge them.

Honest boundaries, stated up front:
  * "home" is `landing within FOUNTAIN_NEAR_U of the team's own fountain
    centroid" (the 17:09Z / #111 definition), so a defensive TP to the base
    towers or the ancient IS inside it.  That is why `defend` exists as a label
    instead of being silently counted as waste.
  * the stash, the bot's mode, and `sCastMotive` are invisible in a replay.
    Nothing here reads a motive string; every label is a source clause
    re-evaluated on real frames.
  * a courier can deliver an item at any moment, so `items_gain` across a home
    trip is EVIDENCE OF, not PROOF OF, a shopping trip.
  * `IsInvFull` is a STEP GATE, and its step source (a courier delivery) is the
    very thing that makes the `shop` branch fire, so the "last frame before the
    channel" and the cast tick land on OPPOSITE SIDES of the step more often
    than a drifting scalar like `hp_pct` would (#121 measured the blind window
    for hp; `hometp_invfull_lag.py` measured it for this clause).  A row whose
    bag is ONE SLOT SHORT on the pre frame therefore cannot be excluded from
    `shop` at this sampling interval -- the summary prints that band as
    UNRESOLVED instead of silently counting it as unexplained.  Measured on the
    12:12Z wave (283 mirror games, 4 runs, `--interval 0.2`): the band is
    15.1% of the hp>=0.55 population and the realised flip rate inside it is
    ~1.8% at 0.2s / ~2-6% at 0.1s.  The band is an UPPER bound, the flip count
    a LOWER one; the truth is between them and only a finer re-dump moves it.

Usage:
  hometp_highhp.py <sweep_dir>... [--interval 1.0] [--cases N] [--selfcheck]
"""

import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), "soak"))

from seed_draft import positions_for_game    # noqa: E402
from stayfield_domain import (            # noqa: E402
    Game, load_sweeps, dist, usable_items, canon,
    HP_HI, TP_TAIL_S, FOUNTAIN_NEAR_U, DEATH_BLANK_S, SIDE_TEAM,
)

RING_U = 1600.0            # X.GetNumHeroWithinRange(1600) at :5151
ESC_DMG_S = 6.0            # WasRecentlyDamagedByAnyHero(6.0) at :5143
ESC_BASE, ESC_SLOPE = 0.15, 0.24     # :5140
ESC_MAX_ENEMIES = 3        # :5146 (nEnemyCount <= 3 when hp >= 0.4)
LASTSEEN_S = 2.0           # GetHeroLastSeenInfo time_since_seen < 2.0 (:5001)
DEFEND_U = 2500.0          # NOT a source constant: observable-shadow radius
DEFEND_BACK_S = 15.0
DEFEND_FWD_S = 20.0
RETURN_FRAC = 0.8          # "back out" = 80% of the pre-cast fountain distance
TRIP_MAX_S = 120.0         # horizon for dwell / return measurement
DEATH_ATTR_S = 5.0         # a death this soon after the channel closes is the
                           # channel's; anything later is not attributed here
RUPTURE = "modifier_bloodseeker_rupture"

# --- mode_roam_generic.lua:1288-1325, ConsiderWaitInBaseToHeal -------------
# The eighth fountain-TP call site, and the only one OUTSIDE
# X.ConsiderItemDesire["item_tpscroll"].  Its second disjunct is MANA-driven
# and, for a non-core, carries NO HP CLAUSE AT ALL -- a support at full health
# with <25% mana is sent home.  That is the branch this label tests for.
LANE_FLOOR_S = 8 * 60      # J.IsInLaningPhase turbo floor (jmz_func.lua:9324)
LANE_SOFT_S = 10 * 60      # soft extension while net worth < LANE_SOFT_NW
LANE_SOFT_NW = 8000
HEAL_MP = 0.25             # J.GetMP(bot) < 0.25 (:1315-1316)
HEAL_CORE_HP = 0.75        # cores additionally need HP < 0.75 (:1315)
ANCIENT_U = 2400.0         # > 2400 from the ENEMY ancient (:1296)


def nonempty(items):
    return [i for i in (items or ()) if i]


def inv_full(s):
    """X.IsInvFull: slots 0-8 all occupied.  The dump gives exactly 9 slots."""
    it = s.get("items") or []
    return len(it) >= 9 and all(bool(x) for x in it[:9])


def n_slots(s):
    """How many of the 9 positional slots are occupied on this frame.

    Only used to size the blind-window band around `inv_full`: 8 means one
    courier delivery away from full, i.e. `shop` is UNRESOLVED at this
    sampling interval rather than excluded.  Dead frames dump an empty
    `items` vector (charter tool-pit), which reads as 0 and is correctly
    outside the band.
    """
    it = s.get("items") or []
    return sum(1 for x in it[:9] if x)


def positions_for_sweep(row):
    """{canon hero: position} from the seed draft (GH #57: never team_slot)."""
    _run, game, _c, _seed, _side, tl = row
    aj = os.path.join(os.path.dirname(os.path.dirname(tl)), "analysis",
                      "%s.analysis.json" % game)
    if not os.path.exists(aj):
        return None
    try:
        pm = positions_for_game(json.load(open(aj)))
    except Exception:
        return None
    if pm is None:
        return None
    return {canon(k): v for k, v in pm.items()}


def building_rows(tl_path):
    """Raw building snapshots -- Game keeps only towers, we need HP over time."""
    d = json.load(open(tl_path))
    return d.get("buildings", ())


def trip(g, hero, t_cast, tp_end, pre):
    """Landing / dwell / what the trip bought.  All from real frames."""
    tr = g.track[hero]
    land = None
    for s in tr:
        if s["t"] >= tp_end + TP_TAIL_S:
            land = s
            break
    if land is None:
        return None
    res = {"t_land": land["t"], "hp_land": land["hp_pct"], "mp_land": land["mp_pct"],
           "t_leave": None, "dwell": None, "hp_leave": None, "mp_leave": None,
           "t_back": None, "trip_s": None, "items_gain": [], "died": False}
    # A death is attributed to the trip only if it lands in the channel or
    # right after touchdown -- TRIP_MAX_S is a measurement horizon, not a
    # causal window, and a death 90s later at the far end of the map is not
    # this TP's.  (The fountain makes a post-landing death nearly impossible,
    # so a hit here means the bot died mid-channel.)
    died = [td for td in g.deaths.get(hero, ())
            if t_cast <= td <= max(tp_end, t_cast) + DEATH_ATTR_S]
    res["died"] = bool(died)
    res["t_death"] = died[0] if died else None
    leave = None
    for s in tr:
        if s["t"] <= land["t"] or s["t"] > land["t"] + TRIP_MAX_S:
            continue
        d = g.dist_fountain(s)
        if d is not None and d > FOUNTAIN_NEAR_U:
            leave = s
            break
    if leave is not None:
        res["t_leave"] = leave["t"]
        res["dwell"] = leave["t"] - land["t"]
        res["hp_leave"] = leave["hp_pct"]
        res["mp_leave"] = leave["mp_pct"]
        # item delta across the trip -- both endpoints must have a real bag
        # (a corpse frame reports every slot empty; charter tool-pit #3)
        if nonempty(pre["items"]) and nonempty(leave["items"]) and not res["died"]:
            gained = [x for x in nonempty(leave["items"])
                      if x not in nonempty(pre["items"])]
            res["items_gain"] = gained
        target = (g.dist_fountain(pre) or 0.0) * RETURN_FRAC
        for s in tr:
            if s["t"] <= leave["t"] or s["t"] > t_cast + TRIP_MAX_S:
                continue
            d = g.dist_fountain(s)
            if d is not None and d >= target:
                res["t_back"] = s["t"]
                res["trip_s"] = s["t"] - t_cast
                break
    return res


def defend_shadow(g, buildings, hero, land, side_hint=None):
    """Own building near the landing loses HP, or an enemy arrives there."""
    if land is None:
        return False, None
    team = g.hero_team.get(hero)
    t0, t1 = land["t"] - DEFEND_BACK_S, land["t"] + DEFEND_FWD_S
    per = collections.defaultdict(list)
    for b in buildings:
        if b.get("team") != team:
            continue
        if dist(b["x"], b["y"], land["x"], land["y"]) > DEFEND_U:
            continue
        if not (t0 <= b["t"] <= t1):
            continue
        per[(round(b["x"]), round(b["y"]))].append(b)
    for key, rows in per.items():
        rows.sort(key=lambda r: r["t"])
        hps = [r.get("hp_pct", r.get("hp", 0)) for r in rows]
        if hps and max(hps) - min(hps) > 0.01:
            return True, "building -%.0f%% @%s" % (100 * (max(hps) - min(hps)), key)
    for other in g.track:
        if g.hero_team.get(other) == team:
            continue
        for s in g.track[other]:
            if not (land["t"] <= s["t"] <= t1):
                continue
            if s["hp_pct"] <= 0:
                continue
            if dist(s["x"], s["y"], land["x"], land["y"]) <= DEFEND_U:
                return True, "enemy %s @%.0fs" % (other, s["t"] - land["t"])
    return False, None


def in_laning_phase(t, net_worth):
    """J.IsInLaningPhase, turbo, with no c2/c4 candidate in the armed string."""
    if t < LANE_FLOOR_S:
        return True
    if t < LANE_SOFT_S and (net_worth or 0) < LANE_SOFT_NW:
        return True
    return False


def high_hp_home_tps(g, buildings, side, pos=None):
    """Every home-TP whose PRE-CAST frame is above HP_HI, with attribution."""
    armed_team = SIDE_TEAM[side]
    out = []
    for hero, tr in g.track.items():
        for (a, b) in g.tp_spans(hero):
            if a < 0:
                continue
            land = None
            for s in tr:
                if s["t"] >= b + TP_TAIL_S:
                    land = s
                    break
            if land is None:
                continue
            d_land = g.dist_fountain(land)
            if d_land is None or d_land > FOUNTAIN_NEAR_U:
                continue
            pre = g.frame_at(hero, a - 1e-6)
            if pre is None or pre["hp_pct"] <= 0:
                continue
            if any(0.0 <= pre["t"] - td < DEATH_BLANK_S
                   for td in g.deaths.get(hero, ())):
                continue
            if not usable_items(pre):
                continue
            if pre["hp_pct"] <= HP_HI:
                continue

            # 1 Hz blind window: `pre` can sit up to one sampling interval
            # before the cast, and HP is FALLING on exactly the rows that
            # matter (54 of 67 unexplained rows were damaged within 6s), so a
            # single pre-frame reading systematically OVER-states the health
            # the branch actually saw.  Bound it with the first frame at or
            # after the channel opens and score every HP clause on the LOWER
            # of the two -- the branch bands are then evaluated on the most
            # favourable health the bot could have had.
            post = None
            for s2 in tr:
                if s2["t"] >= a:
                    post = s2
                    break
            hp_lo = pre["hp_pct"]
            if post is not None and post["hp_pct"] > 0:
                hp_lo = min(hp_lo, post["hp_pct"])

            near = g.enemies_within(hero, pre, RING_U)
            n_enm = len(near)
            # The engine's nEnemyCount is NOT a subset of this ring: it counts
            # every enemy SEEN in the last 2.0s at its LAST-SEEN location
            # (X.GetNumHeroWithinRange, :4998-5005), so an enemy that has since
            # run out of the ring still counts, while one that was never seen
            # does not.  Vision only shrinks the count; staleness only grows it.
            # `n_stale` grants the bot perfect vision AND the stale position --
            # the largest count the engine could possibly have had -- so a row
            # that is still unattributed under it is unattributed under every
            # vision assumption.
            n_stale = 0
            for other in g.track:
                if other == hero or g.hero_team.get(other) == pre["team"]:
                    continue
                seen = False
                for s2 in g.track[other]:
                    if not (a - LASTSEEN_S <= s2["t"] <= a):
                        continue
                    if s2["hp_pct"] <= 0:
                        continue
                    if dist(pre["x"], pre["y"], s2["x"], s2["y"]) <= RING_U:
                        seen = True
                        break
                if seen:
                    n_stale += 1
            hit6 = any(any(a - ESC_DMG_S <= x <= a for x in ts)
                       for (vic, _atk), ts in g.dmg_by.items() if vic == hero)
            lab = []
            # `shop`: the Go-complete-items branch (:5194).  Its danger clause
            # is `nEnemyCount == 0`, which is VISION-LIMITED (last seen < 2.0s),
            # so requiring my god's-eye ring to be empty would under-label it --
            # exactly what happened on _122632_slot15 CM t=382.3, where all 9
            # slots were full, an Arcane Boots was assembled on landing, and the
            # only thing that failed was my ring.  The label is therefore
            # IsInvFull alone (necessary, checkable, exact), and the god's-eye
            # ring is reported separately as "shopped with an enemy closing".
            if inv_full(pre):
                lab.append("shop")
            if (n_stale >= 1 and hit6 and n_stale <= ESC_MAX_ENEMIES
                    and hp_lo < ESC_BASE + ESC_SLOPE * n_stale):
                lab.append("escape2")      # scored on the GENEROUS count
            if g.has_modifier_at(hero, RUPTURE, a):
                lab.append("rupture")
            # heal-in-base (mode_roam).  Only the mana disjunct can reach this
            # population -- the HP disjunct needs HP < 0.25.  Position comes
            # from the seed draft, never from team_slot (GH #57 / #116).
            p = (pos or {}).get(hero)
            is_core = (p is not None and p <= 3)          # J.IsCore: pos <= 3
            if (not in_laning_phase(a, pre.get("net_worth"))
                    and pre["mp_pct"] < HEAL_MP
                    and (not is_core or hp_lo < HEAL_CORE_HP)):
                lab.append("healmana" if p is not None else "healmana?")
            dfd, dwhy = defend_shadow(g, buildings, hero, land)
            if dfd:
                lab.append("defend")
            t = trip(g, hero, a, b, pre)
            # what the channel itself cost: HP at the pre-cast frame minus HP
            # on landing (a TP channel is 3s of standing still).
            # NOT pre_hp - hp_on_landing: the landing frame is already inside
            # the fountain aura, so that reads as a HEAL and hides the cost.
            # Take the minimum over the frames the bot spends standing still in
            # the channel, which is where the damage actually lands.
            # window runs to the LANDING frame, not to the modifier's removal:
            # on _122632_slot15 (CM t=382.3) the whole 19pp was taken between
            # the last channel frame (384.4, hp 1.000) and touchdown (385.4,
            # hp 0.806), so a [cast, remove] window reads that trip as free.
            # The landing frame sits in the fountain aura and therefore only
            # ever biases this DOWNWARD (regen), never up.
            t_land_w = (t["t_land"] if t else b)
            chan_hp = [s2["hp_pct"] for s2 in tr
                       if a <= s2["t"] <= t_land_w and s2["hp_pct"] > 0]
            chan_loss = (pre["hp_pct"] - min(chan_hp)) if chan_hp else None
            out.append({
                "hero": hero, "t_cast": a, "t_pre": pre["t"], "hp": pre["hp_pct"],
                "pos": p,
                "hp_lo": hp_lo, "hp_post": post["hp_pct"] if post else None,
                "mp": pre["mp_pct"], "level": pre.get("level"),
                "leg": "armed" if pre["team"] == armed_team else "baseline",
                "fdist": g.dist_fountain(pre), "land_fdist": d_land,
                "n_enemy_1600": n_enm, "n_enemy_stale": n_stale,
                "enemy_min": (min([x[1] for x in g.enemies_within(hero, pre, 1e9)])
                              if g.enemies_within(hero, pre, 1e9) else None),
                "hit6": hit6, "inv_full": inv_full(pre),
                "slots": n_slots(pre),
                "labels": lab or ["unexplained"], "defend_why": dwhy,
                "chan_loss": chan_loss,
                "trip": t,
            })
    return out


# --------------------------------------------------------------------------
def selfcheck(games, interval):
    """Field-by-field guards.  Each one has cost me a report before."""
    ok = True

    def chk(name, cond, detail=""):
        nonlocal ok
        print("  %-38s %s %s" % (name, "PASS" if cond else "FAIL", detail))
        ok = ok and cond

    run, game, _c, seed, side, tl = games[0]
    g = Game(tl, interval)
    bl = building_rows(tl)

    gaps = []
    for tr in g.track.values():
        if len(tr) > 20:
            gaps = [round(tr[i + 1]["t"] - tr[i]["t"], 2) for i in range(10)]
            break
    med = sorted(gaps)[len(gaps) // 2] if gaps else -1
    chk("sampling interval matches --interval", abs(med - interval) < 0.25,
        "median gap %.2fs" % med)

    rows = high_hp_home_tps(g, bl, side, positions_for_sweep(games[0]))
    chk("every row is above HP_HI", all(r["hp"] > HP_HI for r in rows),
        "n=%d" % len(rows))
    chk("pre-frame strictly precedes the channel",
        all(r["t_pre"] < r["t_cast"] for r in rows))
    chk("landing inside the fountain ring",
        all(r["land_fdist"] <= FOUNTAIN_NEAR_U for r in rows))
    chk("labels never empty", all(r["labels"] for r in rows))
    chk("hp_lo never exceeds the pre-frame hp",
        all(r["hp_lo"] <= r["hp"] + 1e-9 for r in rows))
    chk("generous count dominates the plain ring",
        all(r["n_enemy_stale"] >= r["n_enemy_1600"] for r in rows),
        "stale >= instantaneous on every row")

    # `slots` must agree with `inv_full` in both directions, or the UNRESOLVED
    # band is measuring something other than "one courier delivery short".
    chk("slots == 9 exactly when inv_full",
        all((r["slots"] == 9) == r["inv_full"] for r in rows),
        "n=%d" % len(rows))
    chk("slots in 0..9", all(0 <= r["slots"] <= 9 for r in rows))
    chk("the one-short band excludes full bags",
        not any(r["slots"] == 8 and r["inv_full"] for r in rows))

    # items are exactly 9 positional slots (the IsInvFull premise)
    lens = set()
    for tr in g.track.values():
        for s in tr[:200]:
            lens.add(len(s.get("items") or []))
    chk("items vector is 9 positional slots", lens == {9} or lens <= {0, 9},
        "lens=%s" % sorted(lens))

    # inv_full must be rarer than "has 6 usable items"
    nfull = nusable = 0
    for tr in g.track.values():
        for s in tr:
            if s["hp_pct"] <= 0:
                continue
            if inv_full(s):
                nfull += 1
            if len(usable_items(s)) >= 6:
                nusable += 1
    chk("inv_full subset of 6-usable", nfull <= nusable,
        "%d full <= %d six-usable" % (nfull, nusable))

    # buildings carry hp over time (the defend probe's premise)
    hp_keys = set()
    for b in bl[:500]:
        hp_keys |= set(k for k in ("hp", "hp_pct") if k in b)
    chk("building rows carry hp", bool(hp_keys), "keys=%s" % sorted(hp_keys))

    # a defend hit must name its reason
    chk("defend label always has a reason",
        all(("defend" not in r["labels"]) or r["defend_why"] for r in rows))

    # trip: dwell non-negative, return after leave
    tr_ok = True
    for r in rows:
        t = r["trip"]
        if not t:
            continue
        if t["dwell"] is not None and t["dwell"] < 0:
            tr_ok = False
        if t["t_back"] is not None and t["t_leave"] is not None \
                and t["t_back"] < t["t_leave"]:
            tr_ok = False
    chk("trip timings monotone", tr_ok)

    # dead heroes never contribute an item gain
    chk("no item gain across a death",
        all(not (r["trip"] and r["trip"]["died"] and r["trip"]["items_gain"])
            for r in rows))

    print("  [selfcheck corpus] %s / %s (side=%s, seed=%s)" % (run, game, side, seed))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--cases", type=int, default=12,
                    help="print this many UNEXPLAINED rows for frame-checking")
    ap.add_argument("--jsonl", default=None)
    a = ap.parse_args()

    games = load_sweeps(a.dirs)
    cands = set(r[2] for r in games)
    if len(cands) != 1:
        sys.exit("[fatal] mixed cand strings in this corpus: %s" % sorted(cands))
    cand = cands.pop()
    print("cand string (uniform, %d ids): %s" % (len(cand.split(",")), cand))
    print("games: %d   runs: %s   interval: %.2fs"
          % (len(games), sorted(set(r[0] for r in games)), a.interval))

    if a.selfcheck:
        sys.exit(0 if selfcheck(games, a.interval) else 1)

    rows = []
    n_nopos = 0
    for row in games:
        run, game, _c, seed, side, tl = row
        g = Game(tl, a.interval)
        bl = building_rows(tl)
        pos = positions_for_sweep(row)
        if pos is None:
            n_nopos += 1
        for r in high_hp_home_tps(g, bl, side, pos):
            r.update({"run": run, "game": game, "seed": seed, "side": side})
            rows.append(r)

    ng = len(games)
    print("\n=== population: home-TP with pre-cast HP > %.2f ===" % HP_HI)
    for leg in ("armed", "baseline"):
        sel = [r for r in rows if r["leg"] == leg]
        print("%-9s %4d events  (%.2f/game)" % (leg, len(sel), len(sel) / float(ng)))

    if n_nopos:
        print("\n[warn] %d/%d games had no resolvable seed draft -> their rows "
              "carry `healmana?` instead of `healmana`" % (n_nopos, ng))
    # Direct correction of the 17:09Z headline: that number put a home-TP in
    # the "hp > 0.55" bucket on the strength of ONE pre-cast frame.  Rows whose
    # channel-open frame is already inside the band were never above it at the
    # decision instant -- they belong to `stayfield`'s own domain, not to this
    # population.
    slipped = [r for r in rows if r["hp_lo"] <= HP_HI]
    print("\n=== 1 Hz blind window, measured on this population ===")
    print("  %d/%d rows (%.1f%%) read above %.2f on the pre-cast frame but are "
          "already at or below it one frame later, at channel open"
          % (len(slipped), len(rows), 100.0 * len(slipped) / max(len(rows), 1),
             HP_HI))
    drops = sorted(100 * (r["hp"] - r["hp_lo"]) for r in rows)
    print("  HP fall across that single blind frame: med %.0fpp  p90 %.0fpp  "
          "max %.0fpp" % (drops[len(drops) // 2], drops[int(0.9 * (len(drops) - 1))],
                          drops[-1]))

    print("\n=== attribution (multi-label; a row can carry several) ===")
    print("%-12s %8s %8s" % ("label", "armed", "baseline"))
    labs = collections.Counter()
    for r in rows:
        for l in r["labels"]:
            labs[l] += 1
    for l in sorted(labs, key=lambda x: -labs[x]):
        print("%-12s %8d %8d"
              % (l, sum(1 for r in rows if l in r["labels"] and r["leg"] == "armed"),
                 sum(1 for r in rows if l in r["labels"] and r["leg"] == "baseline")))

    unex = [r for r in rows if r["labels"] == ["unexplained"]]
    print("\n=== unexplained rows: %d (%.1f%% of the population, %.2f/game) ==="
          % (len(unex), 100.0 * len(unex) / max(len(rows), 1), len(unex) / float(ng)))

    def stat(sel, key, f=lambda t: t):
        vals = sorted(f(r) for r in sel if f(r) is not None)
        if not vals:
            return "n/a"
        return "med %.1f  p90 %.1f  n=%d" % (
            vals[len(vals) // 2], vals[int(0.9 * (len(vals) - 1))], len(vals))

    for name, sel in (("ALL", rows), ("unexplained", unex)):
        print("\n-- %s --" % name)
        print("  hp at cast     %s" % stat(sel, None, lambda r: 100 * r["hp"]))
        print("  mp at cast     %s" % stat(sel, None, lambda r: 100 * r["mp"]))
        print("  dist fountain  %s" % stat(sel, None, lambda r: r["fdist"]))
        print("  nearest enemy  %s" % stat(sel, None, lambda r: r["enemy_min"]))
        print("  dwell at home  %s" % stat(sel, None,
                                           lambda r: r["trip"] and r["trip"]["dwell"]))
        print("  round trip s   %s" % stat(sel, None,
                                           lambda r: r["trip"] and r["trip"]["trip_s"]))
        got = [r for r in sel if r["trip"] and r["trip"]["items_gain"]]
        print("  trips that gained an item: %d/%d (%.0f%%)"
              % (len(got), len(sel), 100.0 * len(got) / max(len(sel), 1)))
        hpgain = [100 * (r["trip"]["hp_leave"] - r["hp"]) for r in sel
                  if r["trip"] and r["trip"]["hp_leave"] is not None]
        if hpgain:
            hpgain.sort()
            print("  hp change over the trip: med %+.0fpp" % hpgain[len(hpgain) // 2])

    # Vision asymmetry, stated per label rather than buried: the engine's
    # nEnemyCount only counts enemies SEEN in the last 2.0s
    # (X.GetNumHeroWithinRange, :4998-5005), while this tool's ring is
    # god's-eye.  So `escape2` is over-labelled (superset ring => shrinks
    # "unexplained", conservative against claiming a defect) and `shop` is
    # under-labelled (my ring must be empty, the engine's only has to be
    # unseen => inflates "unexplained").  The rows below quantify the second
    # one instead of leaving it as a caveat.
    ux_full = [r for r in unex if r["inv_full"]]
    ux_seen = [r for r in unex if r["n_enemy_stale"] >= 1]
    print("\n  of the unexplained: %d carry a FULL 9-slot bag (would be `shop` "
          "if the engine could not see the enemy my ring found)" % len(ux_full))
    print("  of the unexplained: %d had an enemy inside 1600 on my god's-eye ring "
          "(%d of those were also damaged within 6s)"
          % (len(ux_seen), sum(1 for r in ux_seen if r["hit6"])))

    # The step-gate blind window (see the docstring).  `shop` is excluded on a
    # boolean whose step source is the branch's own trigger, so the rows that
    # sit one delivery short on the pre frame are UNRESOLVED, not explained.
    ux_one_short = [r for r in unex if not r["inv_full"] and r.get("slots") == 8]
    all_one_short = [r for r in rows if not r["inv_full"] and r.get("slots") == 8]
    print("  of the unexplained: %d are ONE SLOT SHORT on the pre frame -> "
          "`shop` is UNRESOLVED for them at --interval %.2f, not excluded "
          "(%d of all %d rows are in this band; re-dump these games finer to "
          "settle them -- hometp_invfull_lag.py)"
          % (len(ux_one_short), a.interval, len(all_one_short), len(rows)))

    tight = [r for r in unex if r["hp_lo"] > HP_HI]
    print("  of the unexplained: %d still read above %.2f HP on the LOWER of the "
          "pre-cast and channel-open frames (the 1 Hz blind window closed)"
          % (len(tight), HP_HI))

    shop = [r for r in rows if "shop" in r["labels"]]
    shop_hot = [r for r in shop if r["n_enemy_stale"] >= 1]
    losses = sorted(100 * r["chan_loss"] for r in shop
                    if r["chan_loss"] is not None)
    hot_losses = sorted(100 * r["chan_loss"] for r in shop_hot
                        if r["chan_loss"] is not None)
    print("\n=== the stash-pickup trips (`shop`, IsInvFull) ===")
    print("  %d trips; %d (%.0f%%) began with an enemy inside 1600 that the "
          "branch's own `nEnemyCount == 0` clause could only have missed "
          "through vision" % (len(shop), len(shop_hot),
                              100.0 * len(shop_hot) / max(len(shop), 1)))
    if losses:
        print("  HP paid during the channel (all): med %+.0fpp  worst %+.0fpp  (n=%d)"
              % (-losses[len(losses) // 2], -losses[-1], len(losses)))
    if hot_losses:
        print("  HP paid during the channel (enemy inside 1600): med %+.0fpp  "
              "worst %+.0fpp  (n=%d)"
              % (-hot_losses[len(hot_losses) // 2], -hot_losses[-1],
                 len(hot_losses)))
    dead = [r for r in shop if r["trip"] and r["trip"]["died"]]
    print("  died in the channel (or <%.0fs after touchdown): %d"
          % (DEATH_ATTR_S, len(dead)))
    for r in dead:
        print("    %s %s t=%.1f hp=%.2f nearest enemy %.0fu"
              % (r["game"], r["hero"], r["t_cast"], r["hp"],
                 r["enemy_min"] or -1))

    esc = [r for r in rows if "escape2" in r["labels"]]
    close = [r for r in esc if (r["enemy_min"] or 9e9) <= 400.0]
    el = sorted(100 * r["chan_loss"] for r in esc if r["chan_loss"] is not None)
    cl = sorted(100 * r["chan_loss"] for r in close if r["chan_loss"] is not None)
    print("\n=== the escape TPs (`escape2`) and what the channel costs ===")
    print("  %d trips; %d began with an enemy inside 400u -- the case "
          "J.ShouldWalkNotTp (PROMOTED `tpsafe`, live in turbo) exists to refuse"
          % (len(esc), len(close)))
    if el:
        print("  HP paid during the channel (all escapes): med %+.0fpp  "
              "worst %+.0fpp  (n=%d)"
              % (-el[len(el) // 2], -el[-1], len(el)))
    if cl:
        print("  HP paid during the channel (enemy <=400u): med %+.0fpp  "
              "worst %+.0fpp  (n=%d)"
              % (-cl[len(cl) // 2], -cl[-1], len(cl)))
    print("  died in the channel: %d of %d"
          % (sum(1 for r in esc if r["trip"] and r["trip"]["died"]), len(esc)))

    print("\n=== unexplained cases for frame-checking (first %d) ===" % a.cases)
    for r in sorted(unex, key=lambda r: -(r["trip"]["trip_s"] or 0
                                          if r["trip"] and r["trip"]["trip_s"] else 0)
                    )[:a.cases]:
        t = r["trip"] or {}
        print("%s %-16s t=%.1f hp=%.2f mp=%.2f lvl=%s fd=%.0f enm_min=%s "
              "dwell=%s trip=%s gained=%s"
              % (r["game"], r["hero"], r["t_cast"], r["hp"], r["mp"], r["level"],
                 r["fdist"] or -1,
                 ("%.0f" % r["enemy_min"]) if r["enemy_min"] else "none",
                 ("%.0f" % t["dwell"]) if t.get("dwell") is not None else "-",
                 ("%.0f" % t["trip_s"]) if t.get("trip_s") is not None else "-",
                 ",".join(t.get("items_gain") or []) or "-"))

    if a.jsonl:
        with open(a.jsonl, "w") as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")
        print("\nwrote %s" % a.jsonl)


if __name__ == "__main__":
    main()

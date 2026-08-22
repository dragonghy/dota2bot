#!/usr/bin/env python3
"""Execution-verification probe for `fieldbuy` -- the SUPPLY half of owner
priority P2's "野区续航" family (jmz_func.lua:4866 J.ShouldFieldBuyRegen, wired
into item_purchase_generic.lua:800).  Read-only, offline; consumes sweep_run.sh
output dirs.

WHY THIS IS THE ONE ID IN THE FAMILY THAT CAN ACTUALLY BUY (a).
`stayfield` / `stayfield2` are VETOES: when they work, nothing happens, so the
only offline evidence they can ever produce is an asymmetry in a rare negative
(replay-check 2026-08-22T17:09Z ruled `stayfield` (a) INDETERMINATE for exactly
this reason).  `fieldbuy` is the opposite shape -- it ends in
`ActionImmediate_PurchaseItem('item_flask')`, an ACTION whose consequence is
visible in the snapshot stream (a `flask` string appears in the hero's item
slots).  So (a) here is a positive measurement, not an absence.

DOMAIN, transcribed from the source (item_purchase_generic.lua:800-812 plus
J.ShouldFieldBuyRegen -> J.IsFieldRegenSituation):

    J.IsSoakCandidate('fieldbuy')                <- leg split, not a frame test
    J.IsFieldRegenSituation(bot)                 <- reused from stayfield_domain
    not J.HasFieldRegenSource(bot)               <- slots 0..5 only (jmz:4701)
    bot:IsAlive()
    bot:FindItemSlot('item_flask') < 0           <- ALL NINE slots (backpack too)
    not IsThereHealingInStash(bot)               <- NOT observable (dilutes)
    Item.GetEmptyInventoryAmount(bot) >= 1       <- empty among the nine
    botDistanceFromFountain > 2500
    botGold >= GetItemCost('item_flask')         <- NOT observable (dilutes)
    GetItemStockCount('item_flask') > 1          <- NOT observable (dilutes)
    not HasModifier('modifier_flask_healing')
    not HasModifier('modifier_fountain_aura_buff')  <- fountain-distance proxy

Three clauses are unobservable offline and all three can only SUPPRESS a real
purchase, so the scored domain is a SUPERSET of the engine's -- an armed-leg
domain frame with no purchase after it is therefore NOT by itself a bug.

⭐ THE ATTRIBUTION PROBLEM THIS TOOL EXISTS TO SOLVE.
`fieldregen` (item_purchase_generic.lua:776) is armed in the SAME wave and buys
the SAME item.  Its domain and `fieldbuy`'s are NOT disjoint: both fire on a
hurt, flask-less hero at hp<0.45 outside the laning phase.  A bare armed-vs-
baseline flask asymmetry therefore cannot tell the two apart.  The exclusive
band is derived from the two blocks' own clauses:

  * `fieldregen` carries `not J.IsInLaningPhase()` and `J.GetHP(bot) < 0.45`;
  * the shipped "Init Healing Items in Lane" block carries
    `J.IsInLaningPhase()` and `botLevel < 6`.

  ==> EXCL := domain AND ( (laning AND level >= 6) OR (not laning AND hp >= 0.45) )
      is reachable by `fieldbuy` and by neither of the other two.

Both readings are reported.  Only the EXCL one is attributable to `fieldbuy`.

J.IsInLaningPhase() reconstructed exactly for turbo with neither 'c2' nor 'c4'
armed (asserted against the wave's cand string):
    laning  <=>  t < 480  or  (t < 600 and net_worth < 8000)

Registered traps this tool obeys (all inherited with the Game class):
  * idx lock by EARLIEST APPEARANCE -- illusions copy hp/items field-for-field.
  * corpse frames carry an EMPTY items list, so a naive "no flask anywhere"
    test is trivially true on every corpse and a naive set-difference records a
    full re-buy on every respawn (charter 工具坑).  Acquisitions are read only
    between two consecutive frames that are BOTH alive and BOTH non-empty.
  * the 1.0s post-DEATH blanking window (#78 leak band <= 0.30s, 3x margin).
  * "<= t 的最后一帧" with a max gap of one sampling interval for every
    cross-unit lookup.
  * fountain centroid per team, with a positive control in --selfcheck.
  * #102 sweep-completeness sentinel via load_sweeps().
  * timelines indexed by (run, game), never game alone.
  * hero POSITION is never used (GH #57/#116): no clause mentions it.

Usage:
    fieldbuy_domain.py <sweep_dir> [<sweep_dir> ...] [--interval 1.0]
    fieldbuy_domain.py <sweep_dir> ... --frames [--limit N]
    fieldbuy_domain.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from stayfield_domain import (          # noqa: E402  (path juggling first)
    Game, SIDE_TEAM, canon, dist, load_sweeps, situation,
    has_field_regen_source, usable_items,
    HP_LO, HP_HI, DEATH_BLANK_S,
)

CAND_ID = "fieldbuy"
SIBLING_ID = "fieldregen"          # same item, overlapping domain, same wave

FOUNTAIN_MIN_U = 2500.0            # item_purchase_generic.lua:806
LANING_FLOOR_S = 480.0             # jmz_func.lua:9350 (turbo, no c2/c4)
LANING_SOFT_S = 600.0              # jmz_func.lua:9351
LANING_NW = 8000                   # jmz_func.lua:9367
INIT_LANE_LEVEL = 6                # item_purchase_generic.lua "Init Healing" block
FIELDREGEN_HP = 0.45               # item_purchase_generic.lua:781
EPISODE_GAP_S = 5.0
BUY_HORIZON_S = 60.0               # purchase -> stash -> courier -> hand
FLASK = "flask"


def is_laning(s):
    """J.IsInLaningPhase() for turbo with neither c2 nor c4 armed."""
    t = s["t"]
    if t < LANING_FLOOR_S:
        return True
    return t < LANING_SOFT_S and s.get("net_worth", 0) < LANING_NW


def all_items(s):
    """All nine slots: FindItemSlot and GetEmptyInventoryAmount both read 0..8."""
    return (s.get("items") or [])[:9]


def has_items_row(s):
    """A corpse frame's items list is empty -- never mistake it for 'no flask'."""
    return any(all_items(s))


def domain_frame(g, hero, s):
    """The observable subset of the fieldbuy purchase block, on one frame."""
    if not has_items_row(s):                       # corpse / no inventory row
        return False
    if not situation(g, hero, s):
        return False
    if has_field_regen_source(s):                  # slots 0..5 (jmz:4701)
        return False
    items9 = all_items(s)
    if FLASK in items9:                            # FindItemSlot('item_flask')>=0
        return False
    if len([i for i in items9 if i]) >= 9:         # GetEmptyInventoryAmount >= 1
        return False
    d = g.dist_fountain(s)
    if d is None or d <= FOUNTAIN_MIN_U:
        return False
    if g.has_modifier_at(hero, "modifier_flask_healing", s["t"]):
        return False
    return True


def exclusive(s):
    """Reachable by fieldbuy and by NEITHER fieldregen NOR the shipped lane block.

    Classified on the episode's FIRST frame.  Honest bound: `hp >= 0.45` can
    decay below 0.45 inside the 60s outcome window and hand the credit back to
    `fieldregen`, so this band is attributable but not airtight -- see below.
    """
    if is_laning(s):
        return s.get("level", 0) >= INIT_LANE_LEVEL
    return s["hp_pct"] >= FIELDREGEN_HP


def airtight(s):
    """The band where NO other purchase path can fire for the WHOLE window.

    `t0 + 60 < 480` puts the entire outcome window inside turbo's hard laning
    floor, so `fieldregen`'s `not J.IsInLaningPhase()` is false for every frame
    of it -- not merely at t0.  `level >= 6` kills the shipped in-lane block for
    the whole window too, because level is monotone.  A flask that reaches an
    airtight-band hero's hand inside the window can therefore have come from
    exactly one place in the tree: this id.
    """
    return (is_laning(s) and s.get("level", 0) >= INIT_LANE_LEVEL
            and s["t"] + BUY_HORIZON_S < LANING_FLOOR_S)


FOUNTAIN_PICKUP_U = 2000.0        # inside this ring the stash empties into the
                                  # bag by itself -- the salve did NOT have to
                                  # be flown out to the bot


def flask_gains(g, hero):
    """(t, d_fountain) each time a `flask` appears where the previous ALIVE frame
    had none.

    Both frames must carry a non-empty items row, so respawn (empty -> full)
    can never be scored as an acquisition.

    ⭐ THE DISTANCE IS NOT DECORATION.  Frame-scan of
    `181122/20260822_183048_slot8` lina t=244.4 (20.8% HP, 9,794u from her own
    fountain, squarely in the AIRTIGHT band) shows the flask appearing at
    t=245.4 -- with the bot 111u from the fountain.  She went home; the stash
    handed her the salve on arrival.  A salve reaching the hand is therefore NOT
    evidence that the bot healed in the field, which is the entire content of
    owner priority P2.  Gains are split on where the bot was standing.
    """
    out, prev = [], None
    for s in g.track.get(hero, ()):
        if s["hp_pct"] <= 0 or not has_items_row(s):
            prev = None                     # corpse breaks the chain, not scores it
            continue
        if any(0.0 <= s["t"] - td < DEATH_BLANK_S for td in g.deaths.get(hero, ())):
            prev = None
            continue
        cur = FLASK in all_items(s)
        if prev is not None and cur and not prev[0]:
            usable = FLASK in usable_items(s)     # slots 0..5 -- drinkable
            out.append((s["t"], g.dist_fountain(s), usable,
                        _stuck_in_backpack(g, hero, s["t"]) if not usable else False))
        prev = (cur, s["t"])
    return out


BACKPACK_SETTLE_S = 5.0           # how long a slot has to hold to be believed
BACKPACK_WATCH_S = 30.0


def _stuck_in_backpack(g, hero, t_gain):
    """Did the salve REALLY sit in the backpack, or was slot 6-8 a transient?

    ⭐ Registered the hard way.  `181122/20260822_181946_slot6` viper t=354.5:
    the flask is first seen in the backpack -- and is USED at 354.6, healing
    0.476 -> 0.847 in the field.  What actually happened on that frame is a
    courier drop plus a `perseverance` combine that freed a main slot inside one
    sampling interval, so the backpack was a one-frame way-station.  Scoring the
    FIRST frame a flask is visible would have published "26.5% of these salves
    cannot be drunk", which that frame falsifies.

    A landing counts as stuck only if, for the whole watch window, the flask is
    never seen in slots 0..5 and is never used -- and it is still in the pack
    at least BACKPACK_SETTLE_S later.
    """
    saw_late = False
    for s in g.track.get(hero, ()):
        if s["t"] <= t_gain or s["t"] > t_gain + BACKPACK_WATCH_S:
            continue
        if s["hp_pct"] <= 0 or not has_items_row(s):
            continue
        if FLASK in usable_items(s):
            return False                       # moved into a drinkable slot
        if FLASK not in all_items(s):
            return False                       # gone: used, or handed over
        if s["t"] >= t_gain + BACKPACK_SETTLE_S:
            saw_late = True
    return saw_late


def drink_times(g, hero):
    """modifier_flask_healing goes on -- the salve actually being consumed."""
    return sorted(g.mod_add.get((hero, "modifier_flask_healing"), ()))


def scan_game(g, side):
    """Episodes of the fieldbuy domain, per leg, with their outcome."""
    armed_team = SIDE_TEAM[side]
    out = []
    for hero, tr in g.track.items():
        gains = flask_gains(g, hero)
        drinks = drink_times(g, hero)
        mine, cur = [], None
        for s in tr:
            if domain_frame(g, hero, s):
                if cur is not None and s["t"] - cur["t_end"] <= EPISODE_GAP_S:
                    cur["t_end"] = s["t"]
                    cur["frames"] += 1
                    cur["hp_min"] = min(cur["hp_min"], s["hp_pct"])
                    cur["excl"] = cur["excl"] or exclusive(s)
                else:
                    if cur is not None:
                        mine.append(cur)
                    cur = {
                        "hero": hero,
                        "leg": "armed" if s["team"] == armed_team else "base",
                        "t0": s["t"], "t_end": s["t"], "frames": 1,
                        "hp0": s["hp_pct"], "hp_min": s["hp_pct"],
                        "level": s.get("level", 0),
                        "laning": is_laning(s),
                        "excl": exclusive(s),
                        "tight": airtight(s),
                        "dist_f": g.dist_fountain(s),
                        "x": s["x"], "y": s["y"],
                    }
        if cur is not None:
            mine.append(cur)
        for n, e in enumerate(mine):
            hit = next((x for x in gains
                         if e["t0"] <= x[0] <= e["t0"] + BUY_HORIZON_S), None)
            e["gain_dt"] = (hit[0] - e["t0"]) if hit else None
            e["gain_fdist"] = hit[1] if hit else None
            e["gain_usable"] = bool(hit and hit[2])
            e["gain_stuck"] = bool(hit and hit[3])
            e["gain_field"] = bool(hit and (hit[1] or 0.0) > FOUNTAIN_PICKUP_U)
            e["gain_field_usable"] = e["gain_field"] and e["gain_usable"]
            e["drink_dt"] = next((t - e["t0"] for t in drinks
                                  if e["t0"] <= t <= e["t0"] + BUY_HORIZON_S), None)
            e["first"] = (n == 0)     # untouched by any earlier purchase this game
        out.extend(mine)
    return out


# --------------------------------------------------------------------------
def summarise(rows, interval):
    per_leg = collections.defaultdict(lambda: collections.Counter())
    games = collections.defaultdict(set)
    all_eps = []
    for (run, game, cand, seed, side, path) in rows:
        assert CAND_ID in cand.split(","), "armed-string guard: %s not in %s" % (CAND_ID, game)
        g = Game(path, interval)
        eps = scan_game(g, side)
        for e in eps:
            e["run"], e["game"], e["seed"] = run, game, seed
        all_eps.extend(eps)
        for leg in ("armed", "base"):
            games[leg].add((run, game))
        for e in eps:
            c = per_leg[e["leg"]]
            c["eps"] += 1
            c["frames"] += e["frames"]
            if e["gain_dt"] is not None:
                c["gain"] += 1
            if e["gain_field"]:
                c["field"] += 1
            if e["gain_field_usable"]:
                c["fieldok"] += 1
            if e["drink_dt"] is not None:
                c["drink"] += 1
            for tag, flag in (("excl", e["excl"]), ("tight", e["tight"]),
                              ("first", e["first"])):
                if not flag:
                    continue
                c[tag + "_eps"] += 1
                if e["gain_dt"] is not None:
                    c[tag + "_gain"] += 1
                if e["gain_field"]:
                    c[tag + "_field"] += 1
                if e["gain_field_usable"]:
                    c[tag + "_fieldok"] += 1
                if e["drink_dt"] is not None:
                    c[tag + "_drink"] += 1
    return per_leg, games, all_eps


def _band(per_leg, n_games, tag, title, note):
    print("-- %s --" % title)
    print("   %s" % note)
    print("%-6s %6s %9s %11s %7s %9s %13s %7s %11s"
          % ("leg", "eps", "eps/game", "flask<=60s", "rate", "IN FIELD",
             "field+USABLE", "rate", "drink<=60s"))
    for leg in ("armed", "base"):
        c = per_leg[leg]
        n = c[tag + "_eps"]
        rate = (100.0 * c[tag + "_gain"] / n) if n else 0.0
        frate = (100.0 * c[tag + "_fieldok"] / n) if n else 0.0
        print("%-6s %6d %9.2f %11d %6.1f%% %9d %13d %6.1f%% %11d"
              % (leg, n, n / float(n_games or 1), c[tag + "_gain"], rate,
                 c[tag + "_field"], c[tag + "_fieldok"], frate,
                 c[tag + "_drink"]))
    print("")


def report(rows, interval):
    per_leg, games, all_eps = summarise(rows, interval)
    n_games = len(games["armed"])
    print("== fieldbuy (a) execution probe ==")
    print("games: %d   sampling interval: %.1fs   buy horizon: %.0fs"
          % (n_games, interval, BUY_HORIZON_S))
    print("sibling armed in the same wave: %s (same item, overlapping domain)"
          % SIBLING_ID)
    print("")
    hdr = ("leg", "eps", "eps/game", "frames", "flask<=60s", "IN FIELD",
           "field+USABLE", "rate", "drink<=60s")
    print("%-6s %6s %9s %7s %11s %9s %13s %7s %11s" % hdr)
    for leg in ("armed", "base"):
        c = per_leg[leg]
        frate = (100.0 * c["fieldok"] / c["eps"]) if c["eps"] else 0.0
        print("%-6s %6d %9.2f %7d %11d %9d %13d %6.1f%% %11d"
              % (leg, c["eps"], c["eps"] / float(n_games or 1), c["frames"],
                 c["gain"], c["field"], c["fieldok"], frate, c["drink"]))
    print("")
    print("NOTE the domain is SELF-CONSUMING: a delivered salve removes the very")
    print("clause (no regen source) that puts the bot in the domain, so a smaller")
    print("armed-leg episode count is an EFFECT, not a broken control.")
    print("")
    _band(per_leg, n_games, "excl",
          "EXCLUSIVE band (fieldregen + shipped lane block unreachable at t0)",
          "attributable, not airtight: hp>=0.45 can decay inside the window")
    _band(per_leg, n_games, "tight",
          "AIRTIGHT band (laning, level>=6, whole 60s window under the 480s floor)",
          "no other purchase path in the tree can fire anywhere in the window")
    _band(per_leg, n_games, "first",
          "FIRST episode per hero-game (pre-intervention control)",
          "nothing this id did earlier in the game can have shaped this episode")
    per_hero = collections.defaultdict(lambda: collections.Counter())
    for e in all_eps:
        per_hero[e["hero"]][e["leg"]] += 1
        if e["gain_dt"] is not None:
            per_hero[e["hero"]][e["leg"] + "_gain"] += 1
    print("-- per hero (episodes; gain = flask in hand within 60s) --")
    for h, c in sorted(per_hero.items(), key=lambda kv: -(kv[1]["armed"] + kv[1]["base"]))[:14]:
        print("  %-18s armed %3d (gain %3d)   base %3d (gain %3d)"
              % (h, c["armed"], c["armed_gain"], c["base"], c["base_gain"]))
    print("")
    gd = sorted((e["gain_fdist"] or 0.0) for e in all_eps if e["gain_dt"] is not None)
    if gd:
        inside = sum(1 for d in gd if d <= FOUNTAIN_PICKUP_U)
        print("-- WHERE the salve reached the hand (n=%d gains, both legs) --" % len(gd))
        print("   inside the %.0fu fountain ring: %d (%.1f%%)  <- STASH PICKUP,"
              % (FOUNTAIN_PICKUP_U, inside, 100.0 * inside / len(gd)))
        print("      the bot went home anyway; P2 asks for the opposite")
        print("   out in the field:              %d (%.1f%%)  <- courier delivery"
              % (len(gd) - inside, 100.0 * (len(gd) - inside) / len(gd)))
        print("   d(fountain) at the gain frame: med %.0fu  p90 %.0fu" %
              (gd[len(gd) // 2], gd[int(0.9 * len(gd))]))
        ng = [e for e in all_eps if e["gain_dt"] is not None]
        bp = sum(1 for e in ng if not e["gain_usable"])
        stuck = sum(1 for e in ng if e["gain_stuck"])
        fstuck = sum(1 for e in ng if e["gain_field"] and e["gain_stuck"])
        print("")
        print("-- ⭐ WHICH SLOT it landed in (slots 6-8 = backpack = not drinkable) --")
        print("   the purchase block gates on Item.GetEmptyInventoryAmount(bot) >= 1,")
        print("   which counts ALL NINE slots, while J.HasFieldRegenSource -- the")
        print("   clause the whole family is built on -- reads only slots 0..5.")
        print("   first seen in the backpack: %d of %d gains (%.1f%%)"
              % (bp, len(ng), 100.0 * bp / len(ng)))
        print("   ... of which STUCK (never reaches slots 0-5 nor gets used")
        print("       within %.0fs, still in the pack %.0fs on): %d (%.1f%% of all"
              % (BACKPACK_WATCH_S, BACKPACK_SETTLE_S, stuck,
                 100.0 * stuck / len(ng)))
        print("       gains) -- the rest were a one-frame way-station, NOT a defect")
        print("   STUCK among IN-FIELD gains: %d (%.1f%% of %d)"
              % (fstuck, 100.0 * fstuck / max(len(gd) - inside, 1), len(gd) - inside))
    lags = sorted(e["gain_dt"] for e in all_eps if e["gain_dt"] is not None)
    if lags:
        print("")
        print("-- domain-frame -> flask-in-hand lag (n=%d): min %.1f med %.1f max %.1f"
              % (len(lags), lags[0], lags[len(lags) // 2], lags[-1]))
        print("   NOT a purchase latency: the purchase can have happened on an")
        print("   earlier frame of an earlier episode; this is only the lag from")
        print("   the domain frame this tool happened to score.")
    return all_eps


def frames_dump(rows, interval, limit):
    """Frame-by-frame print of armed-leg episodes that DID get a flask."""
    _, _, all_eps = summarise(rows, interval)
    hits = [e for e in all_eps if e["leg"] == "armed" and e["gain_dt"] is not None]
    hits.sort(key=lambda e: (not e["excl"], e["gain_dt"]))
    for e in hits[:limit]:
        print("%s/%s  %s  t0=%.1f..%.1f  hp %.3f->%.3f  lvl %d  laning=%s  "
              "excl=%s  d(fnt)=%.0f  flask +%.1fs @%.0fu  drink %s"
              % (e["run"], e["game"], e["hero"], e["t0"], e["t_end"],
                 e["hp0"], e["hp_min"], e["level"], e["laning"], e["excl"],
                 e["dist_f"], e["gain_dt"], e["gain_fdist"] or -1,
                 ("+%.1fs" % e["drink_dt"]) if e["drink_dt"] is not None else "-"))


# --------------------------------------------------------------------------
def selfcheck(rows, interval):
    """Assertions that would have caught the registered traps."""
    checks = []
    g0 = Game(rows[0][5], interval)
    side0 = rows[0][4]
    eps = scan_game(g0, side0)

    checks.append(("armed string contains fieldbuy in every game",
                   all(CAND_ID in r[2].split(",") for r in rows)))
    checks.append(("c2/c4 absent (laning reconstruction valid)",
                   all("c2" not in r[2].split(",") and "c4" not in r[2].split(",")
                       for r in rows)))
    checks.append(("sibling fieldregen IS armed (attribution band required)",
                   all(SIBLING_ID in r[2].split(",") for r in rows)))
    checks.append(("idx lock dropped at least one copy somewhere",
                   any(Game(r[5], interval).copies > 0 for r in rows[:6])))
    checks.append(("every episode inside the source hp band",
                   all(HP_LO - 1e-9 <= e["hp_min"] and e["hp0"] <= HP_HI + 1e-9
                       for e in eps)))
    dom_frames = [(h, s) for h, tr in g0.track.items() for s in tr
                  if domain_frame(g0, h, s)]
    checks.append(("no domain frame carries a usable heal (the whole point)",
                   all(not has_field_regen_source(s) for _, s in dom_frames)))
    checks.append(("no domain frame has a flask in ANY of the nine slots",
                   all(FLASK not in all_items(s) for _, s in dom_frames)))
    checks.append(("domain is a strict subset of IsFieldRegenSituation frames",
                   len(dom_frames) <= sum(1 for h, tr in g0.track.items() for s in tr
                                          if has_items_row(s) and situation(g0, h, s))))
    checks.append(("every episode > 2500 from its own fountain",
                   all(e["dist_f"] > FOUNTAIN_MIN_U for e in eps)))
    # corpse trap: an empty items row must never be a domain frame nor a gain
    corpse_frames = sum(1 for tr in g0.track.values() for s in tr
                        if not has_items_row(s))
    checks.append(("corpse frames exist in this game (trap is live)", corpse_frames > 0))
    checks.append(("no corpse frame entered the domain",
                   all(has_items_row(s)
                       for h, tr in g0.track.items() for s in tr
                       if domain_frame(g0, h, s))))
    # respawn must not be scored as an acquisition: a hero who dies with a
    # flask and respawns with it still has exactly the gains it really made
    gains_total = sum(len(flask_gains(g0, h)) for h in g0.track)
    deaths_total = sum(len(v) for v in g0.deaths.values())
    checks.append(("gains not inflated by respawns (gains %d <= deaths %d + 12)"
                   % (gains_total, deaths_total), gains_total <= deaths_total + 12))
    # fountain centroid positive control: the two teams' centroids are far apart
    fx = list(g0.fountain.values())
    checks.append(("two fountain centroids >= 12000 apart",
                   len(fx) == 2 and dist(fx[0][0], fx[0][1], fx[1][0], fx[1][1]) >= 12000))
    # exclusive band is a strict subset
    checks.append(("EXCL episodes are a subset of domain episodes",
                   sum(1 for e in eps if e["excl"]) <= len(eps)))
    checks.append(("AIRTIGHT is a strict subset of EXCL",
                   all(e["excl"] for e in eps if e["tight"])))
    checks.append(("every AIRTIGHT window ends before the 480s laning floor",
                   all(e["t0"] + BUY_HORIZON_S < LANING_FLOOR_S
                       for e in eps if e["tight"])))
    checks.append(("gain_field implies the gain frame is outside the ring",
                   all((e["gain_fdist"] or 0.0) > FOUNTAIN_PICKUP_U
                       for e in eps if e["gain_field"])))
    checks.append(("stuck implies not usable at the gain frame",
                   all(not e["gain_usable"] for e in eps if e["gain_stuck"])))
    checks.append(("field+usable implies field",
                   all(e["gain_field"] for e in eps if e["gain_field_usable"])))
    checks.append(("gain_usable implies the flask is in slots 0..5 somewhere",
                   all(e["gain_dt"] is not None for e in eps if e["gain_usable"])))
    checks.append(("gain_field implies a gain happened at all",
                   all(e["gain_dt"] is not None for e in eps if e["gain_field"])))
    checks.append(("exactly one FIRST episode per hero that has any",
                   sum(1 for e in eps if e["first"])
                   == len(set(e["hero"] for e in eps))))
    # laning reconstruction: monotone in t at fixed net worth
    checks.append(("laning is false after 600s",
                   not is_laning({"t": 601.0, "net_worth": 0})))
    checks.append(("laning is true before 480s regardless of net worth",
                   is_laning({"t": 479.9, "net_worth": 99999})))

    ok = True
    for name, res in checks:
        print("  [%s] %s" % ("PASS" if res else "FAIL", name))
        ok = ok and res
    print("selfcheck: %d/%d" % (sum(1 for _, r in checks if r), len(checks)))
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--limit", type=int, default=30)
    a = ap.parse_args()
    rows = load_sweeps(a.dirs)
    if not rows:
        sys.exit("no games")
    if a.selfcheck:
        sys.exit(selfcheck(rows, a.interval))
    if a.frames:
        frames_dump(rows, a.interval, a.limit)
        return
    report(rows, a.interval)


if __name__ == "__main__":
    main()

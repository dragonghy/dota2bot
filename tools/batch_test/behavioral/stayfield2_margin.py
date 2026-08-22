#!/usr/bin/env python3
"""(a)-verification probe for `stayfield2` -- the WALK half of owner priority
P2 (jmz_func.lua:4842 J.ShouldRegenNotWalkHome, wired into
mode_retreat_generic.lua:236).  Read-only, offline; consumes sweep_run.sh dirs.

⭐ WHY A SEPARATE TOOL AND NOT `stayfield_domain.py`'s SITUATION TABLE.
`stayfield_domain.py` scores `stayfield2` against J.ShouldRegenNotGoHome -- the
whole situation domain.  That denominator is WRONG for this id, and wrong in the
direction that flatters it, because `stayfield2` is the SECOND veto on its leg:

    mode_retreat_generic.lua:222   if J.ShouldStayAndRegen(bot) then NONE end
    mode_retreat_generic.lua:236   if J.ShouldRegenNotWalkHome(bot) then NONE end

`J.ShouldStayAndRegen` (jmz_func.lua:4669) is PROMOTED -- ungated, LIVE on BOTH
legs -- and it returns first.  So `stayfield2` only ever CHANGES a frame where
the shipped veto is FALSE and its own predicate is TRUE.  Comparing the two
clause by clause, on three of the four axes `stayfield2` is strictly stricter
and therefore can never be the one that fires:

    axis            ShouldStayAndRegen (shipped)   ShouldRegenNotWalkHome
    hp band         [0.18, 0.75]                   [0.18, 0.55]   <- subset
    hero ring       none within 1200               none within 1600 <- subset
    enemy tower     (no clause)                    none within 1200 <- extra veto

Only two axes can hand `stayfield2` a frame the shipped veto refused, and they
are exactly the two the source comment claims:

  (A) DANGER READ.  The shipped veto dies on bare
      bot:WasRecentlyDamagedByAnyHero(3.0) -- no attribution, no distance.
      `stayfield2` requires the damager to still be inside 3000.  A global ult
      (or a poke from someone who has since left/died) opens this gap.
      FULLY OBSERVABLE: DAMAGE events carry actor_hero, and the attacker's
      position is in the snapshot stream.

  (B) REGEN READ.  The shipped veto asks for a FLASK specifically
      (J.IsItemAvailable('item_flask'), i.e. slots 0..5) or a heal modifier
      already ticking, or 90 gold.  `stayfield2` accepts tango / tango_single /
      faerie_fire / charged bottle.  A bot carrying a faerie_fire and under 90
      gold is `stayfield2`-only.  PARTLY OBSERVABLE: gold is not in the dump.

So this tool reports two bands, and the difference between them is exactly the
unobservable gold clause:

    CERTAIN  = domain AND (A)            -- shipped veto is FALSE whatever the
                                            gold is; every frame here is
                                            genuinely stayfield2's to change.
    WIDE     = domain AND ((A) OR (B))   -- adds the frames that are
                                            stayfield2's ONLY IF gold < 90.

CERTAIN is a lower bound on the id's reach, WIDE an upper bound.  Report both;
never quote one alone.

OUTCOME.  `home_walk` (reused verbatim from stayfield_domain.outcome): within
30s of the episode start the hero reaches its own fountain's 2000u ring with no
TP channel, and the displacement getting there is physically walkable.  An
armed-leg home_walk inside CERTAIN is a LEAK CANDIDATE -- but NOT yet a leak:
mode_retreat_generic is not the only thing that can walk a bot home.  GH #120
established that BOT_MODE_ITEM falls through to Valve's default (which fetches
from the stash) because `bots/--mode_item_generic.lua` cannot be loaded, and
that path does not pass either veto.  So every armed-leg CERTAIN home_walk is
additionally classified by whether the hero GAINED AN ITEM at the fountain:

    stash_pickup  -- a new non-consumable appeared within 8s of arrival
                     => GH #120's path, not a stayfield2 leak
    leak_cand     -- arrived and gained nothing => mode_retreat_generic is the
                     best remaining explanation; read the frames before judging.

Traps obeyed (inherited with the Game class from stayfield_domain):
  idx lock by earliest appearance; corpse frames excluded (empty items row);
  1.0s post-DEATH blanking; "<= t 的最后一帧" with a one-interval gap cap;
  per-team fountain centroid with a positive control; #102 sweep sentinel;
  timelines keyed by (run, game); hero POSITION never used (GH #57/#116).

Usage:
    stayfield2_margin.py <sweep_dir> [...] [--interval 1.0]
    stayfield2_margin.py <sweep_dir> [...] --frames [--limit N]
    stayfield2_margin.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import stayfield_domain as SD           # noqa: E402
from stayfield_domain import (          # noqa: E402
    Game, SIDE_TEAM, dist, load_sweeps, situation, outcome,
    has_field_regen_source, usable_items,
    HP_LO, HP_HI, DMG_WINDOW_S, DEATH_BLANK_S, EPISODE_GAP_S,
    FOUNTAIN_NEAR_U, HORIZON_S,
)

CAND_ID = "stayfield2"
SHIPPED_HP_HI = 0.75              # jmz_func.lua:4674
SHIPPED_RING_U = 1200.0           # jmz_func.lua:4676
PICKUP_WINDOW_S = 8.0             # arrival -> stash item in hand
FAR_U = 4000.0                    # "a real trip home", NOT a source constant:
                                  # home_walk only means something for a bot
                                  # that was not already loitering near base
CONSUMABLES = {"flask", "tango", "tango_single", "faerie_fire", "clarity",
               "enchanted_mango", "bottle", "empty_bottle", "ward_observer",
               "ward_sentry", "ward_dispenser", "smoke_of_deceit", "dust",
               "tpscroll", "blood_grenade", "tome_of_knowledge"}


def damaged_by_any_hero(g, hero, t):
    """bot:WasRecentlyDamagedByAnyHero(3.0) -- no attribution, no distance."""
    for (vic, _atk), ts in g.dmg_by.items():
        if vic != hero:
            continue
        if any(t - DMG_WINDOW_S <= x <= t for x in ts):
            return True
    return False


def shipped_regen_read(g, hero, s):
    """The shipped veto's heal test, minus the unobservable `gold >= 90`."""
    if "flask" in usable_items(s):            # J.IsItemAvailable('item_flask')
        return True
    if g.has_modifier_at(hero, "modifier_flask_healing", s["t"]):
        return True
    if g.has_modifier_at(hero, "modifier_tango_heal", s["t"]):
        return True
    return False


def gap_reason(g, hero, s):
    """Why the SHIPPED veto is false on a frame where stayfield2 is true.

    Returns 'danger' (certain), 'regen' (certain only if gold < 90), or None
    (the shipped veto already covers this frame -- stayfield2 changes nothing).
    """
    # hp and ring can never open a gap: stayfield2's bands are subsets.
    if s["hp_pct"] > SHIPPED_HP_HI:
        return None                                   # unreachable, asserted
    if g.enemies_within(hero, s, SHIPPED_RING_U):
        return None                                   # unreachable, asserted
    if damaged_by_any_hero(g, hero, s["t"]):
        return "danger"
    if not shipped_regen_read(g, hero, s):
        return "regen"
    return None


def domain_frame(g, hero, s):
    """J.ShouldRegenNotWalkHome, offline (gate itself is the leg split)."""
    if s["t"] < 0 or s["hp_pct"] <= 0:
        return False
    if any(0.0 <= s["t"] - td < DEATH_BLANK_S for td in g.deaths.get(hero, ())):
        return False
    if not usable_items(s):                      # corpse / empty bag
        return False
    if not situation(g, hero, s):
        return False
    if not has_field_regen_source(s):
        return False
    return True


def gained_item_near(g, hero, t_arrive):
    """A NON-consumable appearing within PICKUP_WINDOW_S -- GH #120's signature."""
    tr = g.track.get(hero, ())
    prev = None
    for s in tr:
        if s["t"] < t_arrive - 1.0 or s["t"] > t_arrive + PICKUP_WINDOW_S:
            continue
        cur = set(i for i in (s.get("items") or [])[:9] if i)
        if not cur:
            prev = None                          # corpse breaks the chain
            continue
        if prev is not None:
            new = cur - prev
            for i in new:
                if i not in CONSUMABLES:
                    return i
        prev = cur
    return None


HOMEWARD_WINDOW_S = 60.0          # a walk from the far lane is ~35-40s at 300u/s
HOMEWARD_CLOSE_U = 3000.0         # "committed to the trip", not a wobble
WALK_CAP_U = 550.0 * 1.6          # fastest a hero can plausibly cover ground


def homeward_close(g, hero, t0, t_ref):
    """Max ground CLOSED toward the hero's own fountain by CONTINUOUS WALKING.

    The reason this exists: `home_walk` requires ARRIVAL inside the 2000u ring,
    so a trip that is interrupted, or simply longer than the horizon, reads as
    "did not go home".  This estimator asks the weaker and more honest
    question -- did the bot spend the window moving toward its own base at all?

    ⭐ IT TERMINATES ON THE FIRST DISCONTINUITY, IT DOES NOT SKIP PAST ONE.
    Three separate frame scans killed three earlier versions of this function,
    and all three died the same way: a frame was SKIPPED (corpse, TP channel)
    and the scan carried on with `prev` reset, which silently disarmed the
    displacement guard on the very next frame -- the one that had teleported.

      * `181122/20260822_183031_slot6` jakiro t0=238.4, 12,894u out: killed at
        263.4, RESPAWNS AT HIS FOUNTAIN at 283.4 -> scored 12,636u "closed".
      * `181122/20260822_183700_slot1` drowranger t0=62.4, 13,460u out: uses
        item_tpscroll at 111.7, modifier_fountain_aura_buff at 114.7, 13,555u
        -> 167u -> scored 13,350u "closed".  A TP home is the OTHER call site
        (`stayfield`, on tpscroll); counting it here attributes another id's
        behaviour to this one.

    So the window ends -- not pauses -- at the first death, the first TP
    channel, the first corpse frame, the first sampling gap, and any step
    faster than a hero can physically walk.  What survives is a continuous
    walking trace, which is the only thing `stayfield2` could have vetoed.

    Returns (closed_units, aborted).
    """
    horizon = t0 + HOMEWARD_WINDOW_S
    cuts = [td for td in g.deaths.get(hero, ()) if td > t0]          # death
    cuts += [a for (a, _b) in g.tp_spans(hero) if a > t0]            # TP channel
    t_stop = min([horizon] + cuts)
    cut_early = t_stop < horizon
    best, prev = 0.0, None
    for s in g.track.get(hero, ()):
        if s["t"] <= t0:
            continue
        if s["t"] > t_stop:
            break
        if s["hp_pct"] <= 0:
            return (best, True)                      # corpse: story over
        if prev is not None:
            gap = s["t"] - prev["t"]
            if gap > g.interval + 1e-6:
                return (best, True)                  # unsampled stretch
            if dist(s["x"], s["y"], prev["x"], prev["y"]) / max(gap, 1e-6) > WALK_CAP_U:
                return (best, True)                  # blink / unlogged TP
        prev = s
        d = g.dist_fountain(s)
        if d is not None:
            best = max(best, t_ref - d)
    return (best, cut_early)


def arrival_time(g, hero, t0):
    """First frame inside the fountain ring in the outcome window."""
    for s in g.track.get(hero, ()):
        if s["t"] <= t0 or s["t"] > t0 + SD.HORIZON_S:
            continue
        d = g.dist_fountain(s)
        if d is not None and d <= FOUNTAIN_NEAR_U:
            return s["t"]
    return None


def scan_game(g, side):
    armed_team = SIDE_TEAM[side]
    eps = []
    for hero, tr in g.track.items():
        cur = None
        for s in tr:
            if not domain_frame(g, hero, s):
                continue
            reason = gap_reason(g, hero, s)
            if cur is not None and s["t"] - cur["t_end"] <= EPISODE_GAP_S:
                cur["t_end"] = s["t"]
                cur["frames"] += 1
                cur["hp_min"] = min(cur["hp_min"], s["hp_pct"])
                if reason == "danger":
                    cur["certain"] = True
                if reason is not None:
                    cur["wide"] = True
            else:
                if cur is not None:
                    eps.append(cur)
                cur = {"hero": hero, "t_start": s["t"], "t_end": s["t"],
                       "frames": 1, "hp0": s["hp_pct"], "hp_min": s["hp_pct"],
                       "leg": "armed" if s["team"] == armed_team else "base",
                       "certain": reason == "danger",
                       "wide": reason is not None,
                       "reason0": reason,
                       "fdist": g.dist_fountain(s),
                       "far": (g.dist_fountain(s) or 0.0) > FAR_U,
                       "items": usable_items(s),
                       "x": s["x"], "y": s["y"]}
        if cur is not None:
            eps.append(cur)
    for e in eps:
        e.update(outcome(g, e))
        e["closed"], e["closed_abort"] = homeward_close(
            g, e["hero"], e["t_start"], e["fdist"] or 0.0)
        e["homeward"] = (not e["closed_abort"]) and e["closed"] >= HOMEWARD_CLOSE_U
        e["arrive"] = None
        e["pickup"] = None
        if e["home_walk"]:
            e["arrive"] = arrival_time(g, e["hero"], e["t_start"])
            if e["arrive"] is not None:
                e["pickup"] = gained_item_near(g, e["hero"], e["arrive"])
    return eps


# --------------------------------------------------------------------------
def collect(rows, interval):
    all_eps = []
    for (run, game, cand, seed, side, path) in rows:
        assert CAND_ID in cand.split(","), "armed-string guard: %s missing in %s" % (CAND_ID, game)
        g = Game(path, interval)
        for e in scan_game(g, side):
            e["run"], e["game"], e["seed"] = run, game, seed
            all_eps.append(e)
    return all_eps


def band_table(eps, n_games, key, title, note):
    print("-- %s --" % title)
    print("   %s" % note)
    print("%-6s %8s %9s %10s %6s %10s %8s"
          % ("leg", "eps", "eps/game", "home_walk", "rate", "home_tp", "drank"))
    for leg in ("armed", "base"):
        sel = [e for e in eps if e["leg"] == leg and (key is None or e[key])]
        n = len(sel)
        w = sum(1 for e in sel if e["home_walk"])
        tp = sum(1 for e in sel if e["home_tp"])
        dr = sum(1 for e in sel if e["drank"])
        print("%-6s %8d %9.2f %10d %5.1f%% %10d %8d"
              % (leg, n, n / float(n_games or 1), w,
                 (100.0 * w / n) if n else 0.0, tp, dr))
    print("")


def report(rows, interval):
    eps = collect(rows, interval)
    n_games = len(set((e["run"], e["game"]) for e in eps))
    print("== stayfield2 (a) marginal-reach probe ==")
    print("games with at least one domain episode: %d   interval %.1fs   horizon %.0fs"
          % (n_games, interval, SD.HORIZON_S))
    print("(a hero walks ~300 u/s; a %0.0fs horizon can only reach ~%.0fu, so read"
          % (SD.HORIZON_S, 300.0 * SD.HORIZON_S))
    print(" the distance table below BEFORE reading any home_walk rate)")
    print("")
    band_table(eps, n_games, None, "FULL domain (J.ShouldRegenNotWalkHome)",
               "WRONG denominator for this id -- shown only to connect with "
               "stayfield_domain.py")
    band_table(eps, n_games, "certain",
               "CERTAIN band (shipped veto FALSE whatever the gold is)",
               "the shipped veto died on bare WasRecentlyDamagedByAnyHero(3.0); "
               "stayfield2's attributed read let the frame through")
    band_table([e for e in eps if e["far"]], n_games, "certain",
               "CERTAIN band, FAR only (episode starts > %.0fu from own fountain)" % FAR_U,
               "the artifact this filter removes: an episode that STARTS inside "
               "the ring scores home_walk for standing still")
    band_table(eps, n_games, "wide",
               "WIDE band (CERTAIN + 'only a non-flask heal', gold unobservable)",
               "upper bound: these are stayfield2's only if the bot also had "
               "under 90 gold")
    covered = [e for e in eps if not e["wide"]]
    print("-- SHIPPED-COVERED remainder: %d episodes (%.1f%% of the full domain) --"
          % (len(covered), 100.0 * len(covered) / max(len(eps), 1)))
    print("   J.ShouldStayAndRegen already vetoes these; arming stayfield2")
    print("   cannot change them, so they must not be counted as its reach.")
    print("")
    r0 = collections.Counter(e["reason0"] for e in eps)
    print("-- first-frame gap reason over the full domain --")
    for k, v in r0.most_common():
        print("   %-10s %6d  %5.1f%%" % (str(k), v, 100.0 * v / max(len(eps), 1)))
    print("")
    edges = [(0, 2000), (2000, 4000), (4000, 7000), (7000, 11000), (11000, 1e9)]
    for band_key, band_name in ((None, "FULL domain"), ("certain", "CERTAIN band")):
        print("-- home_walk rate by starting distance from own fountain (%s) --"
              % band_name)
        print("   the 0-2000 row is bots ALREADY INSIDE the ring the estimator")
        print("   tests for: for them home_walk is true by standing still.")
        print("%-14s %13s %13s" % ("d(fountain)", "armed", "base"))
        for lo, hi in edges:
            cells = []
            for leg in ("armed", "base"):
                sel = [e for e in eps if e["leg"] == leg
                       and (band_key is None or e[band_key])
                       and lo <= (e["fdist"] or 0.0) < hi]
                w = sum(1 for e in sel if e["home_walk"])
                cells.append("%4d/%-4d %5.0f%%" % (w, len(sel),
                                                   100.0 * w / len(sel) if sel else 0))
            print("%-14s %13s %13s" % ("%d-%d" % (lo, min(hi, 99999)),
                                       cells[0], cells[1]))
        print("")
    print("-- HOMEWARD estimator: ground closed toward own fountain within %.0fs --"
          % HOMEWARD_WINDOW_S)
    print("   weaker and more honest than home_walk: it does NOT require arrival,")
    print("   so an interrupted or simply longer trip still counts.  FAR episodes")
    print("   only (a bot already near base has no ground to close).")
    print("%-28s %14s %14s" % ("population (FAR)", "armed", "base"))
    for key, name in ((None, "full domain"), ("certain", "CERTAIN band"),
                      ("wide", "WIDE band")):
        cells = []
        for leg in ("armed", "base"):
            sel = [e for e in eps if e["leg"] == leg and e["far"]
                   and not e["closed_abort"] and (key is None or e[key])]
            h = sum(1 for e in sel if e["homeward"])
            cells.append("%4d/%-5d %5.1f%%" % (h, len(sel),
                                               100.0 * h / len(sel) if sel else 0))
        print("%-28s %14s %14s" % (name, cells[0], cells[1]))
    ab = sum(1 for e in eps if e["far"] and e["closed_abort"])
    print("   (aborted by the displacement guard: %d FAR episodes)" % ab)
    closed_all = sorted(e["closed"] for e in eps
                        if e["far"] and not e["closed_abort"])
    if closed_all:
        print("   ground closed, all FAR episodes: med %.0fu  p90 %.0fu  max %.0fu"
              % (closed_all[len(closed_all) // 2],
                 closed_all[int(0.9 * len(closed_all))], closed_all[-1]))
    print("")
    lc = [e for e in eps if e["leg"] == "armed" and e["certain"] and e["home_walk"]
          and e["far"]]
    pick = sum(1 for e in lc if e["pickup"])
    print("-- armed-leg CERTAIN+FAR home_walks: %d, of which %d end in a STASH PICKUP"
          % (len(lc), pick))
    print("   (a non-consumable in hand within %.0fs of arrival = GH #120's"
          % PICKUP_WINDOW_S)
    print("   BOT_MODE_ITEM path, which passes neither veto and is NOT a leak)")
    print("   remaining leak candidates: %d" % (len(lc) - pick))
    return eps


def frames_dump(rows, interval, limit):
    eps = collect(rows, interval)
    lc = [e for e in eps if e["leg"] == "armed" and e["certain"] and e["home_walk"]
          and e["far"]]
    lc.sort(key=lambda e: (e["pickup"] is not None, -e["frames"]))
    print("armed-leg CERTAIN+FAR home_walks (leak candidates first), n=%d" % len(lc))
    for e in lc[:limit]:
        print("%s/%s  %-16s t=%.1f..%.1f  hp %.3f->%.3f  d(fountain) %.0f  "
              "items=%s  arrive=%s  pickup=%s  drank=%s"
              % (e["run"], e["game"], e["hero"], e["t_start"], e["t_end"],
                 e["hp0"], e["hp_min"], e["fdist"], ",".join(e["items"]),
                 ("%.1f" % e["arrive"]) if e["arrive"] else "-",
                 e["pickup"] or "-", e["drank"] or "-"))


# --------------------------------------------------------------------------
def selfcheck(rows, interval):
    checks = []
    checks.append(("armed string contains stayfield2 in every game",
                   all(CAND_ID in r[2].split(",") for r in rows)))
    checks.append(("shipped sibling J.ShouldStayAndRegen is UNGATED "
                   "(no id for it in the string)",
                   all("tphome" not in r[2].split(",") for r in rows)))
    g0 = Game(rows[0][5], interval)
    eps = scan_game(g0, rows[0][4])
    dom = [(h, s) for h, tr in g0.track.items() for s in tr
           if domain_frame(g0, h, s)]
    checks.append(("domain non-empty in the first game", len(dom) > 0))
    checks.append(("every domain frame inside the source hp band",
                   all(HP_LO - 1e-9 <= s["hp_pct"] <= HP_HI + 1e-9 for _, s in dom)))
    checks.append(("every domain frame carries a usable heal",
                   all(has_field_regen_source(s) for _, s in dom)))
    # the two axes that CANNOT open a gap -- assert, do not assume
    checks.append(("no domain frame exceeds the shipped hp ceiling 0.75",
                   all(s["hp_pct"] <= SHIPPED_HP_HI for _, s in dom)))
    checks.append(("no domain frame has an enemy inside the shipped ring 1200",
                   all(not g0.enemies_within(h, s, SHIPPED_RING_U) for h, s in dom)))
    checks.append(("gap_reason never returns 'hp' or 'ring' (they are subsets)",
                   all(gap_reason(g0, h, s) in (None, "danger", "regen")
                       for h, s in dom)))
    checks.append(("CERTAIN is a subset of WIDE",
                   all(e["wide"] for e in eps if e["certain"])))
    checks.append(("no corpse frame in the domain (items row non-empty)",
                   all(usable_items(s) for _, s in dom)))
    checks.append(("home_walk implies no TP channel in the window",
                   all(not e["tp_any"] for e in eps if e["home_walk"])))
    checks.append(("home_walk implies an arrival time was found",
                   all(e["arrive"] is not None for e in eps if e["home_walk"])))
    checks.append(("pickup is never a consumable",
                   all(e["pickup"] not in CONSUMABLES for e in eps if e["pickup"])))
    fx = list(g0.fountain.values())
    checks.append(("two fountain centroids >= 12000 apart",
                   len(fx) == 2 and dist(fx[0][0], fx[0][1],
                                         fx[1][0], fx[1][1]) >= 12000))
    checks.append(("a death inside the window always aborts the homeward scan",
                   all(e["closed_abort"] for e in eps
                       if [td for td in g0.deaths.get(e["hero"], ())
                           if e["t_start"] < td < e["t_start"] + HOMEWARD_WINDOW_S])))
    checks.append(("a TP channel inside the window always aborts it",
                   all(e["closed_abort"] for e in eps
                       if [a for (a, b) in g0.tp_spans(e["hero"])
                           if e["t_start"] < a < e["t_start"] + HOMEWARD_WINDOW_S])))
    checks.append(("no surviving homeward trace exceeds walking speed",
                   all(e["closed"] <= WALK_CAP_U * HOMEWARD_WINDOW_S
                       for e in eps if not e["closed_abort"])))
    checks.append(("homeward implies at least HOMEWARD_CLOSE_U closed",
                   all(e["closed"] >= HOMEWARD_CLOSE_U
                       for e in eps if e["homeward"])))
    checks.append(("home_walk (FAR) implies homeward",
                   all(e["homeward"] or e["closed_abort"]
                       for e in eps if e["home_walk"] and e["far"])))
    checks.append(("FAR episodes really do start beyond %.0fu" % FAR_U,
                   all(e["fdist"] > FAR_U for e in eps if e["far"])))
    checks.append(("both legs present",
                   len(set(e["leg"] for e in eps)) == 2 if eps else False))
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
    ap.add_argument("--horizon", type=float, default=None,
                    help="outcome window in seconds (default: stayfield_domain's 30)")
    a = ap.parse_args()
    if a.horizon:
        SD.HORIZON_S = a.horizon
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

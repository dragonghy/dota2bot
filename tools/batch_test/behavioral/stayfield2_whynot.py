#!/usr/bin/env python3
"""§AO.4② first-failing-clause decomposition for `stayfield2`.

WHY THIS TOOL EXISTS (the director's words, test_set.md §AO.4②):

    「`stayfield2` 读零**不再自动记「本语料无表面」**,必须给出**逐条子句的
      第一失败点分解**……「无表面」这条免责只对**已证明域小**的 id 成立,
      而 `stayfield2` 恰恰是这一族里域**最大**的那个。」

`stayfield2_margin.py` answers "how many frames could this id reach".  It
cannot answer "and if that number is small, WHICH CLAUSE made it small",
because it scores the DOMAIN and a frame that fails clause 1 and a frame that
fails clause 5 both simply leave the domain.  This tool inverts the population:
it starts from **the behaviour the id exists to veto** -- a hurt bot WALKING
HOME across the map -- and asks, on the departure frame, which clause of
`J.ShouldRegenNotWalkHome` was the FIRST to say no.

    jmz_func.lua:4842  J.ShouldRegenNotWalkHome
      wired at mode_retreat_generic.lua:236 (the WALK leg; :222 is the shipped
      promoted veto J.ShouldStayAndRegen, which returns FIRST -- see
      stayfield2_margin.py's header for the axis-by-axis subset proof)

    clause order, transcribed from the source, NOT invented:
      1. hp in [0.18, 0.55]              (jmz_func.lua:4826)
      2. no enemy HERO within 1600       (jmz_func.lua:4829)
      3. no attributed damage in 3.0s    (WasRecentlyDamagedByHero + 3000 ring)
      4. no enemy TOWER within 1200      (jmz_func.lua:4857)
      5. a heal in the six usable slots  (HEALS / bottle)

A trip whose departure frame fails NONE of the five is a frame the id SHOULD
have vetoed and the bot walked home anyway.  That is not automatically a leak
(GH #120: BOT_MODE_ITEM falls through to Valve's default stash-fetch, which
passes neither veto), so those rows are printed for frame-by-frame reading
rather than counted as a verdict.

--------------------------------------------------------------------------
WHAT COUNTS AS A WALK HOME (and the four traps this inherits)
--------------------------------------------------------------------------
An arrival inside the hero's own fountain 2000u ring, reached from beyond
4000u, by a CONTINUOUS WALKING TRACE.  The trace terminates -- never skips --
at the first death, TP channel, corpse frame, sampling gap, or step faster
than 550*1.6 u/s.  This is `stayfield2_margin.homeward_close`'s discipline,
and it is load-bearing for exactly the reason recorded there: three earlier
versions of that scan counted a RESPAWN and a TP SCROLL as "walked home".
A TP home is the OTHER call site (`stayfield`); counting it here would
attribute another id's behaviour to this one.

--------------------------------------------------------------------------
STRATIFICATION (GH #148 + the 21:00Z amendment)
--------------------------------------------------------------------------
Every table is reported per (physical side x leg): ab = radiant-armed games,
ba = dire-armed games.  Pooled armed-vs-baseline is NOT printed, because on
this corpus the physical-side term does not cancel in a pool.  The estimator
quoted for a difference is the **mean of the two layers' paired differences**
(21:00Z: two layers disagreeing in sign is evidence the side term is alive,
not evidence of noise -- the average kills the side term exactly).

Usage:
    stayfield2_whynot.py <sweep_dir> [...] [--interval 1.0]
    stayfield2_whynot.py <sweep_dir> [...] --frames [--limit N]
    stayfield2_whynot.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import stayfield_domain as SD            # noqa: E402
from stayfield_domain import (           # noqa: E402
    Game, SIDE_TEAM, load_sweeps, usable_items, has_field_regen_source,
    HP_LO, HP_HI, RING_U, TOWER_U, DEATH_BLANK_S, FOUNTAIN_NEAR_U,
)
from stayfield2_margin import (          # noqa: E402
    FAR_U, WALK_CAP_U, gap_reason, gained_item_near, PICKUP_WINDOW_S,
)
import fieldcreep_domain as FC           # noqa: E402

CAND_ID = "stayfield2"
MONO_SLACK_U = 150.0   # pathing wobble tolerated on the homeward descent;
                       # a bigger backslide is a real turnaround, not jitter

# Ordered exactly as the source evaluates.  Each trip is attributed to its
# FIRST failing clause; that is what turns "the reach is small" into "the reach
# is small BECAUSE ...".
#
# ⚠ Clause 5 is `fieldcreep` (jmz_func.lua:4890), which sits INSIDE
# J.IsFieldRegenSituation and is itself gated.  On this corpus (§AR.0's 24-id
# string) `fieldcreep` IS ARMED, so the armed leg's predicate is strictly
# stricter than the baseline leg's -- a difference that has nothing to do with
# `stayfield2` and would be silently charged to it by a naive leg comparison.
# It is therefore scored explicitly, in BOTH of §AR.1's worlds:
#     甲  WasRecentlyDamagedByCreep counts NEUTRALS  -> lane or neutral hits
#     乙  it does not                                -> lane hits only
# and never merged into one number.
CLAUSES = ["hp<0.18", "hp>0.55", "enemy hero 1600", "attributed damage",
           "enemy tower 1200", "fieldcreep (armed leg)", "no heal in bag",
           "(none -- predicate TRUE)"]


def first_failing_clause(g, hero, s, creep_hits=None):
    """Which clause of J.ShouldRegenNotWalkHome kills this frame, or None.

    `creep_hits` is the §AR.1 world flag: None = do not evaluate the gated
    fieldcreep clause (baseline leg, or the 乙-world reading with no lane hit).
    """
    if s["hp_pct"] < HP_LO:
        return "hp<0.18"
    if s["hp_pct"] > HP_HI:
        return "hp>0.55"
    if g.enemies_within(hero, s, RING_U):
        return "enemy hero 1600"
    if g.attributed_danger(hero, s):
        return "attributed damage"
    if g.enemy_tower_within(s, TOWER_U):
        return "enemy tower 1200"
    if creep_hits:
        return "fieldcreep (armed leg)"
    if not has_field_regen_source(s):
        return "no heal in bag"
    return None


def scorable(g, hero, s):
    """A frame the predicate could have been evaluated on at all."""
    if s is None or s["t"] < 0 or s["hp_pct"] <= 0:
        return False
    if any(0.0 <= s["t"] - td < DEATH_BLANK_S for td in g.deaths.get(hero, ())):
        return False
    return bool(usable_items(s))          # corpse / empty bag


def walk_home_trips(g, side, inc=None):
    """Every continuous walk from beyond FAR_U into the own-fountain ring.

    Returns one row per trip, scored on the last frame at/beyond FAR_U (the
    departure frame -- the instant mode_retreat_generic would have had to say
    NONE for the trip never to start).
    """
    armed_team = SIDE_TEAM[side]
    out = []
    for hero, tr in g.track.items():
        tp_open = [a for (a, _b) in g.tp_spans(hero)]
        i, n = 0, len(tr)
        while i < n:
            s = tr[i]
            d = g.dist_fountain(s)
            if d is None or d <= FAR_U or s["hp_pct"] <= 0:
                i += 1
                continue
            # candidate departure: walk forward while the trace stays continuous
            j = i + 1
            prev = s
            arrived = None
            while j < n:
                cur = tr[j]
                gap = cur["t"] - prev["t"]
                if gap > g.interval + 1e-6:            # sampling gap: story over
                    break
                if cur["hp_pct"] <= 0:                 # corpse: story over
                    break
                if any(prev["t"] < td <= cur["t"] for td in g.deaths.get(hero, ())):
                    break
                if any(prev["t"] < a <= cur["t"] for a in tp_open):
                    break                              # TP channel: other id
                step = SD.dist(prev["x"], prev["y"], cur["x"], cur["y"])
                if step > WALK_CAP_U * max(gap, 1e-6):
                    break                              # superhuman: not a walk
                dc = g.dist_fountain(cur)
                if dc is not None and dc <= FOUNTAIN_NEAR_U:
                    arrived = cur
                    break
                prev = cur
                j += 1
            if arrived is None:
                i += 1
                continue
            # ⭐ ANCHOR CORRECTION (frame-checked 2026-08-23T23:xxZ, run _9b1fe4
            # game 20260823_121142_slot9 spiritbreaker).  "First frame beyond
            # FAR_U whose forward trace happens to be gap-free" is NOT the
            # instant the bot decided to go home.  On that frame the bot was
            # charging IN: d(fountain) 8198 -> 10686 over t=368..372 (a 1333u
            # single-frame jump = Nether Strike), he fought from 0.434 down to
            # 0.059, and only THEN walked back.  Anchoring at t=369.1 scored
            # him hp 0.416 = inside the band = "predicate TRUE", i.e. it
            # credited `stayfield2` with a frame in which the bot was
            # attacking.  This is the 2026-08-20 cooldown-edge mistake in a new
            # costume: the anchor must be the decision instant, not a frame
            # that merely precedes the outcome.
            # So: walk BACK from arrival across the monotone homeward descent
            # and take its start.  MONO_SLACK_U tolerates pathing wobble
            # without swallowing a real reversal.
            k = j
            while k - 1 >= i:
                dk = g.dist_fountain(tr[k])
                dp = g.dist_fountain(tr[k - 1])
                if dk is None or dp is None or dp < dk - MONO_SLACK_U:
                    break                       # going back in time it DROPS:
                k -= 1                          # that is the turnaround point
            s = tr[k]
            d = g.dist_fountain(s)
            if d is None or d <= FAR_U:
                i = j + 1
                continue
            i_anchor = k
            if not scorable(g, hero, s):
                i = j + 1
                continue
            leg = "armed" if s["team"] == armed_team else "baseline"
            # §AR.1's two worlds, evaluated only where the gate is live.
            kind = "none"
            if inc is not None and leg == "armed":
                hits = FC.hits_in_window(inc.get(hero, ()), s["t"])
                kind, _tot = FC.classify(hits)
            jia = kind in ("lane", "neutral", "mixed")     # counts neutrals
            yi = kind in ("lane", "mixed")                 # lane creeps only
            why = first_failing_clause(g, hero, s, creep_hits=jia)
            why_yi = first_failing_clause(g, hero, s, creep_hits=yi)
            # ⭐ The departure frame alone UNDER-counts the reach: the retreat
            # mode re-evaluates every tick, so a bot that leaves at 70% and is
            # whittled to 40% halfway home enters the band mid-trip and the id
            # would veto the REST of the walk.  `held_any` is the honest upper
            # bound -- did the full predicate hold on ANY frame of the trip.
            held_any, held_t = False, None
            for k in range(i_anchor, j + 1):
                sk = tr[k]
                if sk["t"] > arrived["t"]:
                    break
                if not scorable(g, hero, sk):
                    continue
                kh = "none"
                if inc is not None and leg == "armed":
                    kh, _tt = FC.classify(FC.hits_in_window(inc.get(hero, ()),
                                                            sk["t"]))
                if first_failing_clause(
                        g, hero, sk,
                        creep_hits=kh in ("lane", "neutral", "mixed")) is None:
                    held_any, held_t = True, sk["t"]
                    break
            # ⭐ WHEN does the hp band open, relative to the trip?  Frame-read
            # 2026-08-23T23:xxZ on _9b1fe4/20260823_122400_slot2 crystalmaiden:
            # she turns for home at hp 0.856 with an enemy 616u away, is beaten
            # down to 0.036, salves at t=485 and walks 11,307u -> 1,771u; her hp
            # only re-enters [0.18, 0.55] at t=514.4, by which point she is
            # 2,532u from her own fountain -- 29 of the trip's 34 seconds gone.
            # If the band opens only after the walk is nearly over, vetoing the
            # walk there buys nothing.  This column measures that directly.
            band_t, band_d, band_frac = None, None, None
            for k in range(i_anchor, j + 1):
                sk = tr[k]
                if sk["hp_pct"] <= 0 or not (HP_LO <= sk["hp_pct"] <= HP_HI):
                    continue
                band_t = sk["t"]
                band_d = g.dist_fountain(sk)
                span = arrived["t"] - s["t"]
                band_frac = (band_t - s["t"]) / span if span > 0 else None
                break
            pick = gained_item_near(g, hero, arrived["t"])
            out.append({
                "hero": hero,
                "t0": s["t"], "t_arrive": arrived["t"],
                "hp0": s["hp_pct"], "hp_arrive": arrived["hp_pct"],
                "d0": d,
                "team": s["team"],
                "phys": "radiant" if s["team"] == SIDE_TEAM["radiant"] else "dire",
                "leg": leg,
                "creep_class": kind,
                "why_not": why,
                "why_not_yi": why_yi,
                "held_any": held_any,
                "held_t": held_t,
                "band_t": band_t, "band_d": band_d, "band_frac": band_frac,
                "hp_min": min([x["hp_pct"] for x in tr[i_anchor:j + 1]
                               if x["hp_pct"] > 0] or [s["hp_pct"]]),
                "shipped_gap": gap_reason(g, hero, s) if why is None else None,
                "items": usable_items(s),
                "stash_pickup": pick,
            })
            i = j + 1
    return out


# --------------------------------------------------------------------------


def _layers(rows):
    """(ab, ba) row buckets.  ab = radiant-armed games, ba = dire-armed."""
    ab = [r for r in rows if r["_side"] == "radiant"]
    ba = [r for r in rows if r["_side"] == "dire"]
    return ab, ba


def _rate(rows, pred):
    n = len(rows)
    if n == 0:
        return None, 0
    return 100.0 * sum(1 for r in rows if pred(r)) / n, n


def _fmt_rate(val, n):
    return "n/a" if val is None else "%5.1f%% (n=%d)" % (val, n)


def report(rows, ngames):
    print("== stayfield2 -- §AO.4② first-failing-clause decomposition ==")
    print("population: continuous WALKS HOME (>%.0fu -> inside %.0fu ring),"
          % (FAR_U, FOUNTAIN_NEAR_U))
    print("            scored on the departure frame.  TP trips excluded by")
    print("            construction (they belong to `stayfield`, not this id).")
    print("games: %d   trips: %d" % (ngames, len(rows)))
    print("")

    for layer_name, layer in (("ab (radiant-armed)", "radiant"),
                              ("ba (dire-armed)", "dire")):
        sub = [r for r in rows if r["_side"] == layer]
        print("-- layer %s : %d trips --" % (layer_name, len(sub)))
        print("%-26s %14s %14s" % ("first failing clause", "armed leg", "baseline leg"))
        for c in CLAUSES:
            key = None if c.startswith("(none") else c
            cells = []
            for leg in ("armed", "baseline"):
                pop = [r for r in sub if r["leg"] == leg]
                k = sum(1 for r in pop if r["why_not"] == key)
                cells.append("%5d %5.1f%%" % (k, 100.0 * k / max(len(pop), 1)))
            print("%-26s %14s %14s" % (c, cells[0], cells[1]))
        print("")

    # ---- the balanced estimator on the one row that matters ----------------
    print("-- PREDICATE-TRUE trips (the id's actual reach on this behaviour) --")
    print("   balanced estimator = mean of the two layers' armed-baseline")
    print("   differences (21:00Z amendment to GH #148: the physical-side term")
    print("   flips sign between layers, so the mean cancels it exactly).")
    diffs = []
    for layer in ("radiant", "dire"):
        sub = [r for r in rows if r["_side"] == layer]
        a, na = _rate([r for r in sub if r["leg"] == "armed"],
                      lambda r: r["why_not"] is None)
        b, nb = _rate([r for r in sub if r["leg"] == "baseline"],
                      lambda r: r["why_not"] is None)
        print("   %-8s armed %s   baseline %s"
              % (layer, _fmt_rate(a, na), _fmt_rate(b, nb)))
        if a is not None and b is not None:
            diffs.append(a - b)
    if len(diffs) == 2:
        print("   balanced delta: %+.2f pp   (layers %+.2f / %+.2f)"
              % (sum(diffs) / 2.0, diffs[0], diffs[1]))
    else:
        print("   balanced delta: n/a (a layer is empty)")
    print("")

    print("-- ANY-FRAME reach (upper bound): the predicate held on at least one")
    print("   frame between departure and arrival, not just at departure.")
    print("   A trip counted here is one the id would have vetoed for the REST")
    print("   of the walk.  Read this BEFORE concluding anything from the")
    print("   departure-frame table: that table is a LOWER bound.")
    d2 = []
    for layer in ("radiant", "dire"):
        sub = [r for r in rows if r["_side"] == layer]
        a, na = _rate([r for r in sub if r["leg"] == "armed"],
                      lambda r: r["held_any"])
        b, nb = _rate([r for r in sub if r["leg"] == "baseline"],
                      lambda r: r["held_any"])
        print("   %-8s armed %s   baseline %s"
              % (layer, _fmt_rate(a, na), _fmt_rate(b, nb)))
        if a is not None and b is not None:
            d2.append(a - b)
    if len(d2) == 2:
        print("   balanced delta: %+.2f pp   (layers %+.2f / %+.2f)"
              % (sum(d2) / 2.0, d2[0], d2[1]))
    band = [r for r in rows if r["band_frac"] is not None]
    print("")
    print("-- WHEN the hp band [%.2f, %.2f] opens, relative to the trip --"
          % (HP_LO, HP_HI))
    print("   trips that enter the band at all: %d of %d (%.1f%%)"
          % (len(band), len(rows), 100.0 * len(band) / max(len(rows), 1)))
    if band:
        fr = sorted(r["band_frac"] for r in band)
        dd = sorted(r["band_d"] for r in band if r["band_d"] is not None)
        late = sum(1 for r in band if r["band_frac"] >= 0.5)
        print("   fraction of the trip already walked when it opens:")
        print("     med %.2f   p25 %.2f   p75 %.2f   >= half-way: %d (%.1f%%)"
              % (fr[len(fr) // 2], fr[len(fr) // 4], fr[3 * len(fr) // 4],
                 late, 100.0 * late / len(band)))
        if dd:
            print("   d(own fountain) when it opens: med %.0fu  p25 %.0fu  p75 %.0fu"
                  % (dd[len(dd) // 2], dd[len(dd) // 4], dd[3 * len(dd) // 4]))
        print("   (a veto that only becomes available after the walk is mostly")
        print("    done cannot prevent the walk -- it can only stop the tail)")
    print("")
    print("   trips whose MIN hp on the trip entered the band but which the")
    print("   predicate still never held on: %d"
          % sum(1 for r in rows
                if HP_LO <= r["hp_min"] <= HP_HI and not r["held_any"]))
    print("")

    n_jia = sum(1 for r in rows if r["why_not"] is None)
    n_yi = sum(1 for r in rows if r["why_not_yi"] is None)
    print("-- §AR.1 world sensitivity (armed leg only; baseline is unaffected)")
    print("   predicate-TRUE trips read in world 甲 (creep clause counts")
    print("   neutrals): %d   in world 乙 (lane creeps only): %d" % (n_jia, n_yi))
    print("   the gap is the trips `fieldcreep` takes away from `stayfield2`")
    print("   ONLY IF the engine's WasRecentlyDamagedByCreep sees neutrals.")
    print("")

    tru = [r for r in rows if r["why_not"] is None]
    print("-- of the %d predicate-TRUE trips (world 甲 reading) --" % len(tru))
    cov = collections.Counter(str(r["shipped_gap"]) for r in tru)
    print("   shipped-veto coverage (gap_reason on the same frame):")
    for k, v in cov.most_common():
        label = {"None": "shipped veto ALREADY covers it (stayfield2 changes nothing)",
                 "danger": "gap: DANGER read (certain -- stayfield2's to change)",
                 "regen": "gap: REGEN read (only if gold < 90)"}.get(k, k)
        print("     %-8s %4d   %s" % (k, v, label))
    pick = sum(1 for r in tru if r["leg"] == "armed" and r["stash_pickup"])
    armed_tru = [r for r in tru if r["leg"] == "armed"]
    print("   armed-leg predicate-TRUE trips: %d, of which %d end in a STASH"
          % (len(armed_tru), pick))
    print("   PICKUP within %.0fs (GH #120's BOT_MODE_ITEM path -- passes"
          % PICKUP_WINDOW_S)
    print("   neither veto, so NOT attributable to this id)")
    print("   remaining leak candidates: %d" % (len(armed_tru) - pick))
    print("")


def frames(rows, limit):
    lc = [r for r in rows if r["leg"] == "armed" and r["why_not"] is None]
    lc.sort(key=lambda r: (r["stash_pickup"] is not None, -r["d0"]))
    print("armed-leg predicate-TRUE walks home (leak candidates first), n=%d"
          % len(lc))
    for r in lc[:limit]:
        print("%s/%s  %-16s t=%.1f..%.1f  hp %.3f->%.3f  d0=%.0f  gap=%s  "
              "items=%s  pickup=%s"
              % (r["_run"][-6:], r["_game"], r["hero"], r["t0"], r["t_arrive"],
                 r["hp0"], r["hp_arrive"], r["d0"], r["shipped_gap"],
                 ",".join(r["items"]), r["stash_pickup"]))


# --------------------------------------------------------------------------


def selfcheck(games, interval):
    checks = []

    def chk(name, ok, detail=""):
        checks.append((name, bool(ok)))
        print("  [%s] %s%s" % ("PASS" if ok else "FAIL", name,
                               ("  " + str(detail)) if detail else ""))

    chk("corpus has both physical sides",
        len(set(row[4] for row in games)) == 2,
        collections.Counter(row[4] for row in games))

    rows = []
    for run, game, _c, _s, side, tl in games[:8]:
        g = Game(tl, interval)
        inc, _outg = FC.load_nonhero_damage(tl)
        for r in walk_home_trips(g, side, inc):
            r["_run"], r["_game"], r["_side"] = run, game, side
            rows.append(r)
    chk("probe found walk-home trips at all", len(rows) > 0, len(rows))

    chk("every trip starts beyond FAR_U",
        all(r["d0"] > FAR_U for r in rows))
    chk("every trip ends at/after it starts",
        all(r["t_arrive"] > r["t0"] for r in rows))
    chk("no corpse departure frames",
        all(r["hp0"] > 0 for r in rows))
    chk("every why_not is a declared clause or None",
        all(r["why_not"] is None or r["why_not"] in CLAUSES for r in rows))
    chk("predicate-TRUE trips are inside the HP band",
        all(HP_LO <= r["hp0"] <= HP_HI
            for r in rows if r["why_not"] is None))
    chk("clause order is exclusive: an hp-failing trip is never blamed elsewhere",
        all((r["hp0"] < HP_LO or r["hp0"] > HP_HI)
            == (r["why_not"] in ("hp<0.18", "hp>0.55"))
            for r in rows))
    chk("shipped_gap only set on predicate-TRUE trips",
        all(r["shipped_gap"] is None for r in rows if r["why_not"] is not None))
    chk("legs are labelled from the manifest side, both appear",
        len(set(r["leg"] for r in rows)) == 2 if rows else False,
        collections.Counter(r["leg"] for r in rows))

    # --- synthetic drivers: the clause chain must be order-sensitive ---------
    class FakeG(object):
        interval = 1.0

        def __init__(self, enemies=False, dmg=False, tower=False):
            self._e, self._d, self._t = enemies, dmg, tower
            self.deaths = {}

        def enemies_within(self, hero, s, radius):
            return [("x", 100.0)] if self._e else []

        def attributed_danger(self, hero, s):
            return self._d

        def enemy_tower_within(self, s, radius):
            return self._t

    def frame(hp, items=("flask",)):
        return {"t": 100.0, "hp_pct": hp, "items": list(items) + [None] * 5,
                "x": 0.0, "y": 0.0, "team": 2}

    chk("synthetic: hp low wins over an enemy in the ring",
        first_failing_clause(FakeG(enemies=True), "h", frame(0.10)) == "hp<0.18")
    chk("synthetic: hp high wins over damage",
        first_failing_clause(FakeG(dmg=True), "h", frame(0.90)) == "hp>0.55")
    chk("synthetic: ring wins over damage",
        first_failing_clause(FakeG(enemies=True, dmg=True), "h", frame(0.40))
        == "enemy hero 1600")
    chk("synthetic: damage wins over tower",
        first_failing_clause(FakeG(dmg=True, tower=True), "h", frame(0.40))
        == "attributed damage")
    chk("synthetic: tower wins over an empty bag",
        first_failing_clause(FakeG(tower=True), "h", frame(0.40, items=()))
        == "enemy tower 1200")
    chk("synthetic: empty bag is the last clause",
        first_failing_clause(FakeG(), "h", frame(0.40, items=()))
        == "no heal in bag")
    chk("synthetic: clean frame returns None",
        first_failing_clause(FakeG(), "h", frame(0.40)) is None)
    chk("synthetic: fieldcreep clause wins over an empty bag",
        first_failing_clause(FakeG(), "h", frame(0.40, items=()),
                             creep_hits=True) == "fieldcreep (armed leg)")
    chk("synthetic: a tower still outranks the fieldcreep clause",
        first_failing_clause(FakeG(tower=True), "h", frame(0.40),
                             creep_hits=True) == "enemy tower 1200")
    chk("baseline-leg trips never blame the gated fieldcreep clause",
        all(r["why_not"] != "fieldcreep (armed leg)"
            for r in rows if r["leg"] == "baseline"))
    chk("baseline-leg trips read identically in both §AR.1 worlds",
        all(r["why_not"] == r["why_not_yi"]
            for r in rows if r["leg"] == "baseline"))
    chk("world 乙 is a superset of world 甲 (a strictly weaker veto)",
        sum(1 for r in rows if r["why_not_yi"] is None)
        >= sum(1 for r in rows if r["why_not"] is None))
    chk("held_any is implied by a predicate-TRUE departure frame",
        all(r["held_any"] for r in rows if r["why_not"] is None))
    chk("held_t, when set, lies inside the trip",
        all(r["t0"] <= r["held_t"] <= r["t_arrive"]
            for r in rows if r["held_t"] is not None))
    chk("held_any implies the trip's min hp reached the band",
        all(r["hp_min"] <= HP_HI for r in rows if r["held_any"]))
    chk("src_class buckets a lane creep and a neutral apart",
        FC.src_class("npc_dota_creep_badguys_melee") == "lane"
        and FC.src_class("npc_dota_neutral_centaur_khan") == "neutral")
    chk("synthetic: a backpack-only salve does not count (slots 0..5)",
        first_failing_clause(
            FakeG(), "h",
            {"t": 1.0, "hp_pct": 0.4, "x": 0.0, "y": 0.0, "team": 2,
             "items": [None] * 6 + ["flask"]}) == "no heal in bag")

    ok = sum(1 for _, r in checks if r)
    print("selfcheck: %d/%d" % (ok, len(checks)))
    return ok == len(checks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--limit", type=int, default=30)
    a = ap.parse_args()

    games = load_sweeps(a.dirs)
    if a.selfcheck:
        sys.exit(0 if selfcheck(games, a.interval) else 1)

    rows = []
    for run, game, _c, _s, side, tl in games:
        g = Game(tl, a.interval)
        inc, _outg = FC.load_nonhero_damage(tl)
        for r in walk_home_trips(g, side, inc):
            r["_run"], r["_game"], r["_side"] = run, game, side
            rows.append(r)
    if a.frames:
        frames(rows, a.limit)
    else:
        report(rows, len(games))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Execution-verification probe for `fieldsip` -- the MAGNITUDE narrowing of the
"野区续航" family (jmz_func.lua J.IsFieldSipEnough / J.FieldRegenSipValue).
Read-only, offline; consumes sweep_run.sh output dirs.

WHY THIS TOOL EXISTS AT ALL, AND WHY IT IS NOT stayfield_domain.py.
`fieldsip` has two consumers that read the SAME conjunction with OPPOSITE
polarity on the same frame (jmz_func.lua:5343 and :5409):

    J.ShouldRegenNotGoHome  = situation AND source AND     IsFieldSipEnough
    J.ShouldFieldBuyRegen   = situation AND not (source AND IsFieldSipEnough)

Unarmed, `J.IsFieldSipEnough` is the literal `true` on its first line, so the
pair reduces to `A` / `not A` byte-for-byte.  Armed, it is a pure narrowing of
`A`: the hold can only go TRUE->FALSE and the buy only FALSE->TRUE.

⭐ THE CHARTER FORBIDS THE OBVIOUS READING (test_set.md §CG.4, charter 4a):
`fieldsip`'s condition (a) may NOT be bought from the `stayfield`/`stayfield2`
retention-rate differential.  Four ids (`stayfield`, `stayfield2`, `fieldbuy`,
`fieldsip`) act on the SAME frames in the same wave, so that differential is a
four-way resultant, not this id's reading -- the `campexit` lesson (§BW.3)
applied before the fact.  The hold side is also a VETO: when it works nothing
happens, which is why replay-check already ruled `stayfield` (a) INDETERMINATE.

So this tool buys (a) on the BUY side, and it does so at TRIGGER level:

    FIELDSIP DOMAIN := IsFieldRegenSituation
                   AND HasFieldRegenSource        <- note: TRUE, the opposite of
                                                     fieldbuy_domain's clause
                   AND FieldRegenSipValue < 0.25 * GetMaxHealth()

⭐⭐ WHY A PURCHASE ON A DOMAIN FRAME IS UNIQUELY THIS ID'S.
On a domain frame the bot IS carrying an accepted source, so on the BASELINE
leg `J.ShouldFieldBuyRegen` is `not (TRUE and TRUE)` = FALSE **structurally** --
not rarely, not usually: it cannot fire there at all.  The baseline of this
estimator is therefore a hard zero by construction rather than a small number,
and any armed-leg purchase reaching such a frame required `fieldsip` to flip it.

`fieldbuy` is co-armed in the same string and is the EXECUTION VEHICLE for that
purchase, not a rival explanation: without `fieldsip` it is false on every one
of these frames, and without `fieldbuy` there is no purchase call at all.  The
honest statement of the reading is therefore "`fieldsip` AND `fieldbuy`
jointly, with `fieldsip`'s marginal contribution being the whole of it".  That
is a conjunction, not a confound -- and it is registered here rather than left
as prose because §BW.3 is exactly the rule that a co-armed aggregate must not
be silently booked to one id.

`fieldregen` (item_purchase_generic.lua:776) IS a rival -- same item, armed in
the same wave, and it does not ask about a regen source.  It is excluded the
same way fieldbuy_domain excludes it, by that tool's own EXCL/AIRTIGHT bands,
which are imported rather than restated.

⭐⭐⭐ THE ONE CLAUSE THAT IS NOT OBSERVABLE, AND HOW IT IS HANDLED.
`GetMaxHealth()` is NOT in the dump -- snapshots carry `hp_pct` only, never an
absolute bar (verified: stayfield_domain.Game reads no max-health field).  The
threshold clause `sip < 0.25 * maxHP` therefore cannot be evaluated directly.

It is not estimated, and no max-health table is invented.  Frames are instead
partitioned by WHICH item is the best accepted sip, because the sip value is a
five-valued function of that item (jmz_func.lua:5132 J.FIELD_SIP_HEAL):

  * faerie_fire  85 -> below threshold unless maxHP <  340
  * tango       115 -> below threshold unless maxHP <  460
  * bottle      135 -> below threshold unless maxHP <  540
  * flask       400 -> below threshold unless maxHP < 1600   <- REALLY ambiguous

Only the first two are scored.  CERTAIN := the best accepted sip is a faerie
fire or a tango; that needs a 340/460 bar to be wrong, and the source's own
fixture census (jmz_func.lua:5109-5114) measured this class at 0.062..0.156 of
the bar over 21 rows -- i.e. the smallest bar it ever saw was ~737 for a tango.
`bottle` is excluded for a second, independent reason as well: its charges are
unobservable, so stayfield_domain.has_field_regen_source already counts every
bottle as a source (a superset), and 135 sits closest to the 540 line.
`flask` is excluded outright -- a 1600 bar is ordinary mid-game.

Consequence: the scored domain is a strict SUBSET of the engine's.  A missing
armed-leg purchase is still not by itself a bug (the three unobservable
purchase clauses inherited from fieldbuy_domain -- stash, gold, stock -- can
only suppress), but a PRESENT one is real.  This tool can under-count the
domain and can never over-count it.  That asymmetry is the point: (a) is a
positive claim, and a subset is enough to buy a positive claim.

Registered traps: all of them are inherited with Game / flask_gains /
domain-frame plumbing from stayfield_domain and fieldbuy_domain (idx lock by
earliest appearance, corpse frames carrying an empty items row, the post-death
blanking window, per-team fountain centroid, sweep-completeness sentinel,
timelines indexed by (run, game), hero position never used).  Two are re-pinned
here because this tool's clause set differs: the domain frame must carry a
source (the inverted clause), and `bagsalve` must not be armed (armed, it would
widen J.FieldRegenSipValue into the backpack and only ever admit item_flask).

铁律 4(i-a): both physical-side strata are printed unconditionally, as readings
and not as game counts.  This estimator does NOT cancel side bias (it is a
count, not a per-seed swap-average), so 4(i-b) governs it: opposite signs
across the two strata are noise and must not be written into a conclusion.

Usage:
    fieldsip_domain.py <sweep_dir> [<sweep_dir> ...] [--interval 1.0]
    fieldsip_domain.py <sweep_dir> ... --frames [--limit N]
    fieldsip_domain.py <sweep_dir> ... --census      # sip-class breakdown
    fieldsip_domain.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from stayfield_domain import (          # noqa: E402  (path juggling first)
    Game, SIDE_TEAM, dist, load_sweeps, situation,
    has_field_regen_source, usable_items,
    HP_LO, HP_HI,
)
from fieldbuy_domain import (           # noqa: E402
    all_items, has_items_row, is_laning, exclusive, airtight,
    flask_gains, drink_times,
    FLASK, FOUNTAIN_MIN_U, FOUNTAIN_PICKUP_U, BUY_HORIZON_S,
    EPISODE_GAP_S, LANING_FLOOR_S,
)

# ⭐ THE PRE-REGISTERED READ POINT IS 10 SECONDS, NOT 60.
# test_set.md CG.4 item 1 fixes this id's (a) read point in advance: "armed leg,
# a bot in the situation carrying ONLY tango / faerie_fire, does an
# `item_flask` PURCHASE appear within 10 seconds (and not a trip home)".
# The 60s window is `fieldbuy_domain`'s, inherited with its plumbing, and it is
# a different question -- it tolerates a courier flight across the map.  Both
# are reported, but the 10s column is the one the charter pre-registered, so it
# is the one a verdict may lean on; the 60s column is context.
# Nothing here is tuned to a reading: both numbers were fixed before this tool
# was pointed at the corpus (one by CG.4, one by the sibling tool).
HORIZON_S = BUY_HORIZON_S          # overridden by --horizon
PREREG_HORIZON_S = 10.0            # test_set.md CG.4.1

CAND_ID = "fieldsip"
VEHICLE_ID = "fieldbuy"            # the call site the purchase actually goes through
RIVAL_ID = "fieldregen"            # same item, overlapping domain, same wave
FORBIDDEN_ID = "bagsalve"          # would widen FieldRegenSipValue into the backpack

# Mirrors J.FIELD_SIP_HEAL (jmz_func.lua:5132), with the dump's `item_` prefix
# stripped.  selfcheck re-parses the Lua table and asserts equality, so a future
# edit on one side cannot drift silently past this tool.
FIELD_SIP_HEAL = {
    "flask": 400,
    "tango": 115,
    "tango_single": 115,
    "faerie_fire": 85,
    "bottle": 135,
}
MIN_FRACTION = 0.25                # J.FIELD_SIP_MIN_FRACTION

# THE ONE ASSUMPTION THIS TOOL MAKES, stated as a number so it can be argued
# with.  `J.IsFieldSipEnough` is `sip >= 0.25*maxHP`, so the id flips a frame
# iff `maxHP > 4*sip`.  An item is CERTAIN exactly when `4*sip <= this floor`,
# i.e. when no bar at or above the floor could make it "enough".
#
# 460 is not tuned: it is `4 * 115`, the tango row, and the tango is the largest
# table entry that stays under any plausible hero bar.  The source's own fixture
# census (jmz_func.lua:5109-5114) measured this class at 0.062..0.156 of the
# bar over 21 rows -- the smallest bar it ever saw for a tango was ~737, and for
# a faerie fire ~545.  Note the comparison is STRICT (`maxHP > 460`): a hero
# with a bar of exactly 460 carrying a tango would read "enough", which is why
# the boundary is asserted rather than assumed in selfcheck.
CERTAIN_MAXHP_FLOOR = 460
CERTAIN_ITEMS = ("faerie_fire", "tango", "tango_single")
# Excluded: `bottle` (135; charges unobservable, closest to the line) and
# `flask` (400; a 1600 bar is ordinary mid-game).
AMBIGUOUS_ITEMS = ("bottle", "flask")

LUA_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "..", "bots", "FunLib", "jmz_func.lua")


def sip_best(s):
    """J.FieldRegenSipValue over the six usable slots -> (value, item name).

    Slots 0..5 only: the `bagsalve` widening into 6..8 is a separate gate and
    selfcheck asserts it is not armed in this corpus.  Bottle charges are
    unobservable, so a bottle counts here exactly as has_field_regen_source
    already counts it -- as present.  That is a superset in the same direction
    on both sides of the comparison, and bottle frames are AMBIGUOUS anyway.
    """
    best, name = 0, None
    for i in usable_items(s):
        v = FIELD_SIP_HEAL.get(i)
        if v is not None and v > best:
            best, name = v, i
    return best, name


def sip_class(s):
    """CERTAIN / AMBIGUOUS / NONE for one frame, without ever guessing maxHP."""
    _, name = sip_best(s)
    if name is None:
        return "NONE"
    return "CERTAIN" if name in CERTAIN_ITEMS else "AMBIGUOUS"


def domain_frame(g, hero, s):
    """The observable subset of the frames `fieldsip` flips.

    Identical to fieldbuy_domain.domain_frame except for the two clauses that
    are this id's whole content: the source clause is INVERTED (a source must be
    present, which is what makes the baseline leg a structural zero) and the
    magnitude clause is added in its CERTAIN form.
    """
    if not has_items_row(s):                       # corpse / no inventory row
        return False
    if not situation(g, hero, s):
        return False
    if not has_field_regen_source(s):              # <- INVERTED vs fieldbuy
        return False
    if sip_class(s) != "CERTAIN":                  # <- the magnitude clause
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


def scan_game(g, side):
    """Episodes of the fieldsip domain, per leg, with their outcome.

    Episode grouping, the 60s outcome window and the gain classification are
    fieldbuy_domain's, unchanged -- only `domain_frame` differs, which is the
    point.
    """
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
                    val, item = sip_best(s)
                    cur = {
                        "hero": hero,
                        "leg": "armed" if s["team"] == armed_team else "base",
                        "phys": "radiant" if s["team"] == SIDE_TEAM["radiant"] else "dire",
                        "t0": s["t"], "t_end": s["t"], "frames": 1,
                        "hp0": s["hp_pct"], "hp_min": s["hp_pct"],
                        "level": s.get("level", 0),
                        "laning": is_laning(s),
                        "excl": exclusive(s),
                        "tight": airtight(s),
                        "dist_f": g.dist_fountain(s),
                        "sip": val, "sip_item": item,
                        "x": s["x"], "y": s["y"],
                    }
        if cur is not None:
            mine.append(cur)
        for n, e in enumerate(mine):
            hit = next((x for x in gains
                        if e["t0"] <= x[0] <= e["t0"] + HORIZON_S), None)
            e["gain_dt"] = (hit[0] - e["t0"]) if hit else None
            e["gain_fdist"] = hit[1] if hit else None
            e["gain_usable"] = bool(hit and hit[2])
            e["gain_field"] = bool(hit and (hit[1] or 0.0) > FOUNTAIN_PICKUP_U)
            e["gain_field_usable"] = e["gain_field"] and e["gain_usable"]
            e["drink_dt"] = next((t - e["t0"] for t in drinks
                                  if e["t0"] <= t <= e["t0"] + HORIZON_S), None)
            e["first"] = (n == 0)
        out.extend(mine)
    return out


def census_game(g, side):
    """Every situation frame, bucketed by sip class -- the domain's own shape.

    This is the offline analogue of the fixture-corpus census quoted in
    jmz_func.lua:5109, and it is what says whether the CERTAIN subset is most of
    the domain or a sliver of it.  A conclusion that leans on the subset has to
    show this table next to it.
    """
    armed_team = SIDE_TEAM[side]
    c = collections.Counter()
    for hero, tr in g.track.items():
        for s in tr:
            if not has_items_row(s) or not situation(g, hero, s):
                continue
            leg = "armed" if s["team"] == armed_team else "base"
            c[(leg, "situation")] += 1
            if not has_field_regen_source(s):
                c[(leg, "NO_SOURCE")] += 1        # fieldbuy's half, not ours
                continue
            c[(leg, sip_class(s))] += 1
            _, item = sip_best(s)
            c[(leg, "item:" + str(item))] += 1
    return c


# --------------------------------------------------------------------------
def summarise(rows, interval):
    per_leg = collections.defaultdict(collections.Counter)
    per_stratum = collections.defaultdict(collections.Counter)
    census = collections.Counter()
    games = collections.Counter()
    all_eps = []
    for (run, game, cand, seed, side, path) in rows:
        ids = cand.split(",")
        assert CAND_ID in ids, "armed-string guard: %s not in %s" % (CAND_ID, game)
        assert VEHICLE_ID in ids, "vehicle guard: %s not in %s" % (VEHICLE_ID, game)
        g = Game(path, interval)
        eps = scan_game(g, side)
        for e in eps:
            e["run"], e["game"], e["seed"], e["side"] = run, game, seed, side
        all_eps.extend(eps)
        census.update(census_game(g, side))
        games[side] += 1
        games["all"] += 1
        for e in eps:
            for c in (per_leg[e["leg"]], per_stratum[(side, e["leg"])]):
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
                for tag, flag in (("excl", e["excl"]), ("tight", e["tight"])):
                    if not flag:
                        continue
                    c[tag + "_eps"] += 1
                    if e["gain_dt"] is not None:
                        c[tag + "_gain"] += 1
                    if e["gain_field_usable"]:
                        c[tag + "_fieldok"] += 1
                    if e["drink_dt"] is not None:
                        c[tag + "_drink"] += 1
    return per_leg, per_stratum, census, games, all_eps


def hdr():
    """Header carries the ACTUAL window, so a 10s table can never be read as a
    60s one (the two answer different questions -- see HORIZON_S above)."""
    return ("%-6s %6s %9s %11s %8s %13s %11s"
            % ("leg", "eps", "eps/game", "flask<=%.0fs" % HORIZON_S, "rate",
               "field+USABLE", "DRANK<=%.0fs" % HORIZON_S))


def _row(leg, c, n_games, tag=""):
    n = c[tag + "eps"] if tag else c["eps"]
    gain = c[tag + "gain"] if tag else c["gain"]
    fok = c[tag + "fieldok"] if tag else c["fieldok"]
    drink = c[tag + "drink"] if tag else c["drink"]
    rate = (100.0 * gain / n) if n else 0.0
    print("%-6s %6d %9.2f %11d %7.1f%% %13d %11d"
          % (leg, n, n / float(n_games or 1), gain, rate, fok, drink))


def report(rows, interval):
    per_leg, per_stratum, census, games, all_eps = summarise(rows, interval)
    n = games["all"]
    print("== fieldsip (a) execution probe ==")
    print("games: %d   sampling interval: %.1fs   buy horizon: %.0fs%s"
          % (n, interval, HORIZON_S,
             "  <- PRE-REGISTERED (test_set.md CG.4.1)"
             if HORIZON_S == PREREG_HORIZON_S else
             "  <- inherited from fieldbuy_domain; CG.4.1 pre-registered %.0fs"
             % PREREG_HORIZON_S))
    print("vehicle co-armed: %s   rival co-armed: %s" % (VEHICLE_ID, RIVAL_ID))
    print("")
    print("BASELINE IS A STRUCTURAL ZERO: on a domain frame the bot carries an")
    print("accepted source, so unarmed J.ShouldFieldBuyRegen = not(TRUE and TRUE)")
    print("= FALSE.  A non-zero `base` gain row below is therefore NOT this id's")
    print("control -- it is `%s` reaching the same hero, and the EXCL/AIRTIGHT" % RIVAL_ID)
    print("bands are what remove it.")
    print("")
    print(hdr())
    for leg in ("armed", "base"):
        _row(leg, per_leg[leg], n)
    print("")
    print("-- EXCLUSIVE band (%s + shipped lane block unreachable at t0) --" % RIVAL_ID)
    print(hdr())
    for leg in ("armed", "base"):
        _row(leg, per_leg[leg], n, "excl_")
    print("")
    print("-- AIRTIGHT band (laning, level>=6, whole 60s window under %.0fs) --"
          % LANING_FLOOR_S)
    print("   NB the band itself is always sized on the sibling's 60s window,")
    print("   not on --horizon: at a shorter horizon that is STRICTER than")
    print("   needed, which is the safe direction for an attribution band.")
    print(hdr())
    for leg in ("armed", "base"):
        _row(leg, per_leg[leg], n, "tight_")
    print("")

    # -- 铁律 4(i-a): both strata, as READINGS, printed unconditionally -------
    print("-- ⭐ 铁律 4(i-a) BOTH PHYSICAL-SIDE STRATA (readings, not game counts) --")
    print("   This estimator is a COUNT and does NOT cancel side bias, so 4(i-b)")
    print("   governs it: opposite signs across the two strata = noise, and must")
    print("   not be written into a conclusion.")
    for side in ("radiant", "dire"):
        ng = games[side]
        a, b = per_stratum[(side, "armed")], per_stratum[(side, "base")]
        print("   armed-leg=%-8s games=%-3d  armed eps=%-4d gain=%-3d  "
              "base eps=%-4d gain=%-3d  armed-base eps/game=%+.3f"
              % (side, ng, a["eps"], a["gain"], b["eps"], b["gain"],
                 (a["eps"] - b["eps"]) / float(ng or 1)))
        print("     AIRTIGHT band: armed eps=%-3d gain=%-3d   base eps=%-3d gain=%-3d"
              % (a["tight_eps"], a["tight_gain"], b["tight_eps"], b["tight_gain"]))
    print("   ⚠️ The EPISODE COUNT differential above is NOT an effect estimate:")
    print("   the domain is SELF-CONSUMING (a delivered salve removes the very")
    print("   frame that scored it), so the armed leg is expected to hold fewer")
    print("   episodes.  The reading that matters is the AIRTIGHT GAIN, whose")
    print("   baseline is structurally zero rather than merely small.")
    print("")

    # -- the census that says whether CERTAIN is most of the domain -----------
    print("-- SIP-CLASS CENSUS over IsFieldRegenSituation frames --")
    print("   (CERTAIN is the only class this tool scores; see module docstring")
    print("    for why bottle/flask cannot be classified without GetMaxHealth)")
    print("%-6s %10s %10s %9s %10s" % ("leg", "situation", "NO_SOURCE",
                                       "CERTAIN", "AMBIGUOUS"))
    for leg in ("armed", "base"):
        print("%-6s %10d %10d %9d %10d"
              % (leg, census[(leg, "situation")], census[(leg, "NO_SOURCE")],
                 census[(leg, "CERTAIN")], census[(leg, "AMBIGUOUS")]))
    items = sorted({k[1][5:] for k in census if k[1].startswith("item:")})
    print("   best accepted sip, by item (armed / base):")
    for it in items:
        print("     %-14s %5d / %5d"
              % (it, census[("armed", "item:" + it)], census[("base", "item:" + it)]))
    print("")

    per_hero = collections.defaultdict(collections.Counter)
    for e in all_eps:
        per_hero[e["hero"]][e["leg"]] += 1
        if e["gain_dt"] is not None:
            per_hero[e["hero"]][e["leg"] + "_gain"] += 1
    if per_hero:
        print("-- per hero (episodes; gain = flask in hand within %.0fs) --"
              % HORIZON_S)
        for h, c in sorted(per_hero.items(),
                           key=lambda kv: -(kv[1]["armed"] + kv[1]["base"]))[:14]:
            print("  %-18s armed %3d (gain %3d)   base %3d (gain %3d)"
                  % (h, c["armed"], c["armed_gain"], c["base"], c["base_gain"]))
    return all_eps


def frames_dump(rows, interval, limit):
    """Frame evidence: armed-leg domain episodes, gains first, EXCL first."""
    _, _, _, _, all_eps = summarise(rows, interval)
    hits = [e for e in all_eps if e["leg"] == "armed"]
    hits.sort(key=lambda e: (e["gain_dt"] is None, not e["excl"], e["t0"]))
    for e in hits[:limit]:
        print("%s/%s  %s  t0=%.1f..%.1f  hp %.3f->%.3f  lvl %d  sip=%s(%d)  "
              "laning=%s excl=%s tight=%s  d(fnt)=%.0f  flask %s  drink %s"
              % (e["run"], e["game"], e["hero"], e["t0"], e["t_end"],
                 e["hp0"], e["hp_min"], e["level"], e["sip_item"], e["sip"],
                 e["laning"], e["excl"], e["tight"], e["dist_f"],
                 ("+%.1fs @%.0fu" % (e["gain_dt"], e["gain_fdist"] or -1))
                 if e["gain_dt"] is not None else "-",
                 ("+%.1fs" % e["drink_dt"]) if e["drink_dt"] is not None else "-"))
    if not hits:
        print("(no armed-leg domain episode in this corpus)")


def census_dump(rows, interval):
    _, _, census, games, _ = summarise(rows, interval)
    for leg in ("armed", "base"):
        for k in ("situation", "NO_SOURCE", "CERTAIN", "AMBIGUOUS"):
            print("%-6s %-12s %d" % (leg, k, census[(leg, k)]))
    print("games %d" % games["all"])


# --------------------------------------------------------------------------
def _lua_heal_table():
    """Re-parse J.FIELD_SIP_HEAL out of the Lua so the mirror cannot drift."""
    src = open(LUA_SRC, encoding="utf-8").read()
    m = re.search(r"J\.FIELD_SIP_HEAL\s*=\s*\{(.*?)\}", src, re.S)
    if not m:
        return None, None
    out = {}
    for name, val in re.findall(r"(item_\w+)\s*=\s*(\d+)", m.group(1)):
        out[name[len("item_"):]] = int(val)
    f = re.search(r"J\.FIELD_SIP_MIN_FRACTION\s*=\s*([0-9.]+)", src)
    return out, (float(f.group(1)) if f else None)


def pure_checks():
    """The checks that need no corpus: the source mirror, the floor arithmetic
    and the classifier.  Split out so tests/test_fieldsip_domain.py can run the
    battery in CI, where no sweep dir exists (the GH #243 shape).
    """
    checks = []
    lua_tbl, lua_frac = _lua_heal_table()
    checks.append(("FIELD_SIP_HEAL mirrors the Lua table exactly",
                   lua_tbl == FIELD_SIP_HEAL))
    checks.append(("MIN_FRACTION mirrors J.FIELD_SIP_MIN_FRACTION",
                   lua_frac == MIN_FRACTION))
    # The floor is the whole assumption; pin it from both sides so neither a
    # new table entry nor a moved floor can slide a class across it silently.
    checks.append(("every CERTAIN item needs a bar <= %d to ever be 'enough'"
                   % CERTAIN_MAXHP_FLOOR,
                   all(FIELD_SIP_HEAL[i] / MIN_FRACTION <= CERTAIN_MAXHP_FLOOR
                       for i in CERTAIN_ITEMS)))
    checks.append(("every AMBIGUOUS item needs a bar > %d (so it is NOT certain)"
                   % CERTAIN_MAXHP_FLOOR,
                   all(FIELD_SIP_HEAL[i] / MIN_FRACTION > CERTAIN_MAXHP_FLOOR
                       for i in AMBIGUOUS_ITEMS)))
    checks.append(("the tango sits exactly ON the floor (boundary is strict)",
                   FIELD_SIP_HEAL["tango"] / MIN_FRACTION == CERTAIN_MAXHP_FLOOR))
    checks.append(("CERTAIN and AMBIGUOUS partition the heal table",
                   sorted(CERTAIN_ITEMS + AMBIGUOUS_ITEMS) == sorted(FIELD_SIP_HEAL)))

    # -- positive controls on the classifier itself, no corpus needed ---------
    checks.append(("sip_class(faerie_fire only) == CERTAIN",
                   sip_class({"items": ["faerie_fire"]}) == "CERTAIN"))
    checks.append(("sip_class(tango + faerie_fire) == CERTAIN (max is 115)",
                   sip_class({"items": ["tango", "faerie_fire"]}) == "CERTAIN"))
    checks.append(("sip_class(flask + tango) == AMBIGUOUS (max wins, not first)",
                   sip_class({"items": ["tango", "flask"]}) == "AMBIGUOUS"))
    checks.append(("sip_class(bottle) == AMBIGUOUS",
                   sip_class({"items": ["bottle"]}) == "AMBIGUOUS"))
    checks.append(("sip_class(no heal) == NONE",
                   sip_class({"items": ["tpscroll", "branches"]}) == "NONE"))
    checks.append(("a backpack flask does NOT raise the sip (bagsalve unarmed)",
                   sip_class({"items": ["tango", "", "", "", "", "", "flask"]})
                   == "CERTAIN"))
    checks.append(("sip_best reads slots 0..5 only",
                   sip_best({"items": ["", "", "", "", "", "", "flask"]}) == (0, None)))
    checks.append(("the pre-registered read point is CG.4.1's 10s",
                   PREREG_HORIZON_S == 10.0))
    checks.append(("the inherited 60s window is NOT the pre-registered one",
                   BUY_HORIZON_S != PREREG_HORIZON_S))
    checks.append(("laning is false after 600s",
                   not is_laning({"t": 601.0, "net_worth": 0})))
    checks.append(("laning is true before 480s regardless of net worth",
                   is_laning({"t": 479.9, "net_worth": 99999})))
    return checks


def corpus_checks(rows, interval):
    """The checks that need real frames."""
    checks = []
    g0 = Game(rows[0][5], interval)
    side0 = rows[0][4]
    eps = scan_game(g0, side0)
    dom = [(h, s) for h, tr in g0.track.items() for s in tr
           if domain_frame(g0, h, s)]
    ids0 = rows[0][2].split(",")
    checks.append(("armed string contains fieldsip in every game",
                   all(CAND_ID in r[2].split(",") for r in rows)))
    checks.append(("vehicle fieldbuy IS armed (else no purchase call exists)",
                   all(VEHICLE_ID in r[2].split(",") for r in rows)))
    checks.append(("rival fieldregen IS armed (attribution band required)",
                   all(RIVAL_ID in r[2].split(",") for r in rows)))
    checks.append(("bagsalve NOT armed (else sip reads the backpack too)",
                   all(FORBIDDEN_ID not in r[2].split(",") for r in rows)))
    checks.append(("c2/c4 absent (laning reconstruction valid)",
                   "c2" not in ids0 and "c4" not in ids0))

    # -- the inverted clause, which is what separates this tool from fieldbuy --
    checks.append(("EVERY domain frame carries a regen source (inverted clause)",
                   all(has_field_regen_source(s) for _, s in dom)))
    checks.append(("EVERY domain frame is CERTAIN class",
                   all(sip_class(s) == "CERTAIN" for _, s in dom)))
    checks.append(("no domain frame's best sip is a flask or bottle",
                   all(sip_best(s)[1] not in AMBIGUOUS_ITEMS for _, s in dom)))
    checks.append(("domain and fieldbuy's domain are DISJOINT by construction",
                   all(has_field_regen_source(s) for _, s in dom)))
    checks.append(("domain is a strict subset of IsFieldRegenSituation frames",
                   len(dom) <= sum(1 for h, tr in g0.track.items() for s in tr
                                   if has_items_row(s) and situation(g0, h, s))))
    checks.append(("no domain frame has a flask in ANY of the nine slots",
                   all(FLASK not in all_items(s) for _, s in dom)))
    checks.append(("no corpse frame entered the domain",
                   all(has_items_row(s) for _, s in dom)))
    checks.append(("corpse frames exist in this game (trap is live)",
                   any(not has_items_row(s) for tr in g0.track.values() for s in tr)))
    checks.append(("every episode inside the source hp band",
                   all(HP_LO - 1e-9 <= e["hp_min"] and e["hp0"] <= HP_HI + 1e-9
                       for e in eps)))
    checks.append(("every episode > %.0f from its own fountain" % FOUNTAIN_MIN_U,
                   all(e["dist_f"] > FOUNTAIN_MIN_U for e in eps)))
    checks.append(("idx lock dropped at least one copy somewhere",
                   any(Game(r[5], interval).copies > 0 for r in rows[:6])))
    fx = list(g0.fountain.values())
    checks.append(("two fountain centroids >= 12000 apart",
                   len(fx) == 2 and dist(fx[0][0], fx[0][1], fx[1][0], fx[1][1]) >= 12000))
    checks.append(("AIRTIGHT is a subset of EXCL",
                   all(e["excl"] for e in eps if e["tight"])))
    checks.append(("every AIRTIGHT window ends before the laning floor",
                   all(e["t0"] + BUY_HORIZON_S < LANING_FLOOR_S
                       for e in eps if e["tight"])))
    checks.append(("gain_field implies a gain happened at all",
                   all(e["gain_dt"] is not None for e in eps if e["gain_field"])))
    checks.append(("field+usable implies field",
                   all(e["gain_field"] for e in eps if e["gain_field_usable"])))
    checks.append(("every episode carries a physical side",
                   all(e["phys"] in ("radiant", "dire") for e in eps)))

    return checks


def _run(checks):
    ok = True
    for name, res in checks:
        print("  [%s] %s" % ("PASS" if res else "FAIL", name))
        ok = ok and res
    print("selfcheck: %d/%d" % (sum(1 for _, r in checks if r), len(checks)))
    return 0 if ok else 1


def selfcheck(rows, interval):
    checks = pure_checks()
    if rows:
        checks += corpus_checks(rows, interval)
    else:
        print("  (no sweep dir given -- corpus checks SKIPPED, not passed)")
    return _run(checks)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--census", action="store_true")
    ap.add_argument("--limit", type=int, default=30)
    ap.add_argument("--horizon", type=float, default=BUY_HORIZON_S,
                    help="outcome window in seconds; test_set.md CG.4.1 "
                         "pre-registered %.0f for this id" % PREREG_HORIZON_S)
    a = ap.parse_args()
    global HORIZON_S
    HORIZON_S = a.horizon
    rows = load_sweeps(a.dirs) if a.dirs else []
    if a.selfcheck:
        sys.exit(selfcheck(rows, a.interval))
    if not rows:
        sys.exit("no games")
    if a.census:
        census_dump(rows, a.interval)
        return
    if a.frames:
        frames_dump(rows, a.interval, a.limit)
        return
    report(rows, a.interval)


if __name__ == "__main__":
    main()

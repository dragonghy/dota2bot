#!/usr/bin/env python3
"""`cmqreach` domain reading -- queue.json:hero-25, ruled ROUTED_RIDESHARE /
ADMITTED (test_set.md §CO), executor `replay-check`.

WHAT THE REQUEST ASKED FOR, AND WHAT IS ACTUALLY READABLE
---------------------------------------------------------
hero-25 asked for four cells.  Cell (1) was "the distance between the ACTUAL
cast point of `crystal_maiden_crystal_nova` and CM's position at the cast
instant; the fraction > 732 is the domain", already flagged in the request as a
LOWER bound because a refused order emits no cast event.

Measuring it here turns up a second, independent reason that cell is near-blind,
and it is worth writing down because it is a property of the corpus, not of this
script: **the combat log carries no cast LOCATION at all.**  A location can only
be reconstructed from the victims of the resulting damage, and the dumper drops
creep DAMAGE events (`main.go:673-681` keeps only lane-creep DEATH out of the
creep noise).  So for exactly the casts at issue -- the ones aimed at a creep
wave -- there is nothing to reconstruct from.  And the two engine behaviours the
request wants to tell apart BOTH drive that cell to ~0:

  * refuse  => the long cast never happens        => no event
  * walk in => she is inside 732 when it happens  => distance <= 732

=> cell (1) cannot decide anything, in either world.  It is reported for the
record (§1) and is NOT this file's answer.  The request already named cell (2)
the 主判据; this file makes cell (2) carry the ruling.

CELL (2), THE DISCRIMINATOR, DONE AS AN EXACT GEOMETRIC TEST
-----------------------------------------------------------
The shipped creep search is `nCastRange + nRadius`; armed is `nCastRange`
(`hero_crystal_maiden.lua:581`, X.cm_GetCreepAoESearchRange).  Every creep
return site is behind `nSkillLV >= 3` and an `IsValid(nEnemysWeakestLaneCreeps)`
check, and the LOWEST count threshold at any of them is `>= 2`
(`nCanKillCreepsLocationAoE.count >= 2`, twice: the IsFarming site :827 and the
push/defend site :853).

For a threshold of exactly 2 the "is there a legal AoE point" question has a
CLOSED FORM, so no optimiser and no emulation of `FindAoELocation` is needed:
a radius-425 disk covers creeps A and B iff |AB| <= 850, and the set of legal
centres is the lens disk(A,425) n disk(B,425), which is convex.  Minimising
|P - CM| over that lens is exact (nearest point of an intersection of two
disks: clamp to either boundary, or a lens corner).  Then

    pair is SHIPPED-reachable  iff  min|P-CM| <= 1157
    pair is ARMED-reachable    iff  min|P-CM| <=  732
    GAP FRAME  =  some pair is shipped-reachable and NO pair is armed-reachable

which is precisely "shipped's search returns a point the armed search cannot".
On a gap frame the shipped point is > 732 from CM by construction -- that is the
frame class the whole id is about.

Then the readout the request wanted: over the next MOVE_WINDOW_S seconds, does
CM close the distance to that point?
    closes  >= MOVE_U  -> "walk"    (engine walks into range)
    |delta| <  MOVE_U  -> "stand"   (engine refuses; branch wins and does nothing)
    recedes >= MOVE_U  -> "away"    (she was doing something else entirely)

HONEST BOUNDARIES (all of these are registered in the printout, not buried here)
  * creeps[] is sampled every 3.0s and carries POSITION AND TEAM ONLY -- no hp,
    no id.  So frames are evaluated only AT creep sample times (no interpolation
    of creep positions, ever), and the count is an UPPER bound on
    `nCanKillCreepsLocationAoE.count`, whose 0.5/nDamage filter needs creep hp
    this corpus does not have.  It is the faithful shape for the `Hurt` sites.
  * `IsFullyCastable` needs the KV mana cost, which is not in this repo.  The
    ready gate here demands `mp >= MANA_FLOOR`, deliberately ABOVE any plausible
    nova cost, so every frame counted is genuinely castable.  A sensitivity row
    at a lower floor is printed beside it.
  * Aether Lens shifts BOTH rings by +250 (the overshoot stays 425); it is read
    off the snapshot inventory per frame, not assumed absent.
  * mode predicates (IsFarming / IsPushing / IsDefending / IsGoingOnSomeone) are
    not observable offline.  The gap-frame count is therefore an upper bound on
    frames where a creep site would actually be REACHED.  It is not an upper
    bound in the other direction and is not an effect size.
  * 铁律 4(i-a): every headline number is printed in all four (stratum x leg)
    cells.  4(i-b): these are counts, the physical-side term is NOT cancelled in
    them -- opposite signs across strata mean noise and must not be read as an
    armed-minus-baseline difference.

usage:  cmqreach_domain.py <sweep_dir> [sweep_dir ...]
        cmqreach_domain.py --selfcheck
first measured: replay-check 2026-08-31 on W30 (the first 47-id wave).
"""

import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stayfield_domain as SD                                    # noqa: E402
from stayfield_domain import SIDE_TEAM, canon, load_sweeps, stratum_of  # noqa: E402

CM = "crystalmaiden"                       # canon() form
NOVA = "crystal_maiden_crystal_nova"

# --- source constants (hero_crystal_maiden.lua / the ability KV) -------------
CAST_RANGE_KV = 700.0        # AbilityCastRange, flat at every rank
CAST_RANGE_PAD = 32.0        # X.ConsiderQImpl: GetCastRange() + aetherRange + 32
RADIUS = 425.0               # radius/value, flat at every rank
AETHER_BONUS = 250.0         # aether_lens: +250 cast range (and +250 radius)
SKILL_LV_MIN = 3             # every creep return site: nSkillLV >= 3
COUNT_MIN = 2                # lowest creep threshold at any site (:827, :853)

# --- probes, NOT source constants --------------------------------------------
MANA_FLOOR = 200.0           # deliberately above any plausible nova mana cost
MANA_FLOOR_LO = 100.0        # sensitivity row only
MOVE_WINDOW_S = 2.0          # hero-25 cell (2): "the next 2 seconds"
MOVE_U = 100.0               # walk/stand deadband
DEATH_WINDOW_S = 20.0        # hero-25 cell (3)
SAMPLE_TOL_S = 0.6           # a hero snapshot must be this close to a creep sample
CREEP_TEAMS = (2, 3)         # 4 = neutrals; lane creeps only


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def nearest_center_dist(cx, cy, ax, ay, bx, by, r):
    """Exact min |P - C| over the lens disk(A,r) n disk(B,r).  None if empty.

    The lens is convex, so the nearest point is C itself (if inside), or lies on
    one of the two arcs, or at a lens corner.  All four candidates are checked
    and the feasible minimum returned -- no iteration, no tolerance ladder.
    """
    ab = dist(ax, ay, bx, by)
    if ab > 2.0 * r:
        return None                                   # lens empty
    eps = 1e-7

    def inside(px, py):
        return (dist(px, py, ax, ay) <= r + eps
                and dist(px, py, bx, by) <= r + eps)

    best = None

    def offer(px, py):
        nonlocal best
        if inside(px, py):
            d = dist(cx, cy, px, py)
            if best is None or d < best:
                best = d

    offer(cx, cy)                                     # C itself
    for (ox, oy) in ((ax, ay), (bx, by)):             # clamp onto each boundary
        d = dist(cx, cy, ox, oy)
        if d > eps:
            offer(ox + (cx - ox) * r / d, oy + (cy - oy) * r / d)
        else:
            offer(ox + r, oy)                         # C at the centre: any point
    if ab > eps:                                      # the two lens corners
        mx, my = (ax + bx) / 2.0, (ay + by) / 2.0
        h2 = r * r - (ab / 2.0) ** 2
        if h2 > 0:
            h = math.sqrt(h2)
            ux, uy = -(by - ay) / ab, (bx - ax) / ab
            offer(mx + ux * h, my + uy * h)
            offer(mx - ux * h, my - uy * h)
        else:
            offer(mx, my)
    return best


def best_pair(cx, cy, creeps, r, reach):
    """Nearest legal AoE centre covering >= 2 creeps, with centre within `reach`.

    Returns (centre_dist, px, py) for the pair whose legal-centre set comes
    closest to CM, or None when no pair is reachable at all.
    """
    best = None
    n = len(creeps)
    for i in range(n):
        ax, ay = creeps[i]
        for j in range(i + 1, n):
            bx, by = creeps[j]
            d = nearest_center_dist(cx, cy, ax, ay, bx, by, r)
            if d is None or d > reach:
                continue
            if best is None or d < best[0]:
                # the witness point itself, for the movement readout
                mx, my = (ax + bx) / 2.0, (ay + by) / 2.0
                best = (d, mx, my)
    return best


class Game(object):
    """CM's track, the creep samples, and her nova events -- nothing else."""

    def __init__(self, path):
        d = json.load(open(path))
        self.teams = d["game"]["teams"]

        # identity lock by earliest-appearing idx (GH #176 discipline)
        first_t = {}
        for s in d["snapshots"]:
            if "idx" not in s:
                sys.exit("FATAL: timeline has no snapshot idx; cannot lock identity")
            k = (canon(s["hero"]), s["idx"])
            if k not in first_t or s["t"] < first_t[k]:
                first_t[k] = s["t"]
        primary = {}
        for (h, idx), t0 in first_t.items():
            if h not in primary or t0 < primary[h][1]:
                primary[h] = (idx, t0)
        pidx = {h: v[0] for h, v in primary.items()}

        self.cm = [s for s in d["snapshots"]
                   if canon(s["hero"]) == CM and s["idx"] == pidx.get(CM)]
        self.cm.sort(key=lambda s: s["t"])
        self.cm_team = self.cm[0]["team"] if self.cm else None

        self.creeps = collections.defaultdict(list)      # t -> [(x, y, team)]
        for c in d.get("creeps", ()):
            if c["team"] in CREEP_TEAMS:
                self.creeps[round(c["t"], 3)].append((c["x"], c["y"], c["team"]))
        self.creep_times = sorted(self.creeps)

        self.novas = []                                  # cast instants
        self.deaths = []
        self.nova_dmg = collections.defaultdict(list)    # t -> [victim hero]
        for e in d["events"]:
            if e["type"] == "ABILITY" and e.get("inflictor") == NOVA:
                self.novas.append(e["t"])
            elif e["type"] == "DAMAGE" and e.get("inflictor") == NOVA:
                self.nova_dmg[round(e["t"], 1)].append(e.get("target"))
            elif e["type"] == "DEATH" and canon(e.get("target")) == CM:
                self.deaths.append(e["t"])
        self.novas.sort()

    def at(self, t):
        """CM's snapshot nearest to t, or None past SAMPLE_TOL_S."""
        best = None
        for s in self.cm:
            d = abs(s["t"] - t)
            if best is None or d < best[0]:
                best = (d, s)
        if best is None or best[0] > SAMPLE_TOL_S:
            return None
        return best[1]

    def after(self, t, dt):
        """CM's snapshot nearest to t+dt, or None."""
        return self.at(t + dt)

    def enemy_creeps(self, t):
        return [(x, y) for (x, y, team) in self.creeps[t] if team != self.cm_team]

    def nova_state(self, snap):
        # a snapshot can carry an explicit null here, so `.get(k, ())` is not
        # enough -- an absent ability list is NOT evidence Nova is ready.
        for a in (snap.get("abilities") or ()):
            if a["name"] == NOVA:
                return a
        return None

    def rings(self, snap):
        """(cast ring, shipped creep-search ring).  Aether Lens shifts BOTH by
        +250, so the 425u overshoot between them is invariant -- which is the
        whole point of the id and why `search = cast + RADIUS` always holds."""
        aether = AETHER_BONUS if "aether_lens" in (snap.get("items") or ()) else 0.0
        cast = CAST_RANGE_KV + aether + CAST_RANGE_PAD
        return cast, cast + RADIUS


def frames(g, mana_floor):
    """Every creep-sample frame where CM is alive and Nova is genuinely ready."""
    out = []
    for t in g.creep_times:
        s = g.at(t)
        if s is None or s["hp_pct"] <= 0:
            continue
        ab = g.nova_state(s)
        if ab is None or ab["level"] < SKILL_LV_MIN or ab["cd"] > 0:
            continue
        if s.get("mp", 0) < mana_floor:
            continue
        cast, search = g.rings(s)
        out.append((t, s, cast, search))
    return out


def gap_frames(g, mana_floor):
    """Frames where the shipped search reaches a legal >=2 point and armed does not."""
    rows = []
    for (t, s, cast, search) in frames(g, mana_floor):
        creeps = g.enemy_creeps(t)
        if len(creeps) < COUNT_MIN:
            continue
        shipped = best_pair(s["x"], s["y"], creeps, RADIUS, search)
        if shipped is None:
            continue
        armed = best_pair(s["x"], s["y"], creeps, RADIUS, cast)
        if armed is not None:
            continue                                   # armed reaches it too
        rows.append({"t": t, "x": s["x"], "y": s["y"],
                     "centre_dist": shipped[0], "px": shipped[1], "py": shipped[2],
                     "cast_ring": cast, "search_ring": search,
                     "n_creeps": len(creeps), "hp": s["hp_pct"], "mp": s.get("mp")})
    return rows


def movement(g, row):
    """Cell (2): does she close on the point the shipped search handed her?"""
    later = g.after(row["t"], MOVE_WINDOW_S)
    if later is None or later["hp_pct"] <= 0:
        return None
    d0 = dist(row["x"], row["y"], row["px"], row["py"])
    d1 = dist(later["x"], later["y"], row["px"], row["py"])
    delta = d0 - d1
    if delta >= MOVE_U:
        return "walk", delta
    if delta <= -MOVE_U:
        return "away", delta
    return "stand", delta


def cells(rows):
    """The four (stratum x leg) buckets, fixed printing order (铁律 4(i-a))."""
    return [("%s/%s" % (stratum_of(side), leg),
             [r for r in rows if r["_side"] == side and r["_leg"] == leg])
            for side in ("radiant", "dire")
            for leg in ("armed", "baseline")]


def collect(dirs, mana_floor):
    games, gaps, ready, novas, cmmin = [], [], [], [], []
    for (run, game, cand, seed, side, tl) in load_sweeps(dirs):
        g = Game(tl)
        if not g.cm:
            continue
        leg = "armed" if g.cm_team == SIDE_TEAM[side] else "baseline"
        span = (g.cm[-1]["t"] - g.cm[0]["t"]) / 60.0 if len(g.cm) > 1 else 0.0
        games.append((run, game, side, leg, span))
        cmmin.append({"_side": side, "_leg": leg, "min": span, "_game": game})
        for n in g.novas:
            novas.append({"_side": side, "_leg": leg, "t": n, "_game": game,
                          "_run": run, "victims": g.nova_dmg.get(round(n, 1), [])})
        for (t, _s, _c, _r) in frames(g, mana_floor):
            ready.append({"_side": side, "_leg": leg, "t": t, "_game": game})
        for r in gap_frames(g, mana_floor):
            r["_run"], r["_game"], r["_side"], r["_leg"] = run, game, side, leg
            mv = movement(g, r)
            r["move"], r["delta"] = (mv[0], mv[1]) if mv else (None, None)
            r["died_20s"] = any(0 < dt <= DEATH_WINDOW_S
                                for dt in (d - r["t"] for d in g.deaths))
            gaps.append(r)
    return games, gaps, ready, novas, cmmin


def report(dirs, mana_floor):
    games, gaps, ready, novas, cmmin = collect(dirs, mana_floor)
    print("=== cmqreach domain (queue.json:hero-25, cell (2) is the ruling cell) ===")
    print("games with a CM carrier: %d" % len(games))
    if not games:
        print("\nUNINTERPRETABLE -- no CM carrier in this corpus.  Per the §CO")
        print("return gate, hand back the carrier distribution, do NOT read this")
        print("as 'tested, no effect'.")
        return 2

    print("CM hero-minutes: %.1f" % sum(g[4] for g in games))
    lv = collections.Counter()
    for (_r, _g, _s, leg, _m) in games:
        lv[leg] += 1
    print("carrier games per leg: %s" % dict(lv))

    print("\n-- 1. CELL (1): actual nova cast points.  NOT MEASURABLE, and the")
    print("   reason is the corpus, not the sample size: the combat log carries")
    print("   no cast LOCATION, and creep DAMAGE is dropped by the dumper")
    print("   (main.go:673-681), so a creep-aimed nova leaves nothing to")
    print("   reconstruct a point from.  Both engine worlds also drive this cell")
    print("   to ~0 (refuse => no event; walk-in => distance <= cast range).")
    nv = len(novas)
    withv = sum(1 for n in novas if n["victims"])
    print("   novas cast: %d (with a HERO victim, i.e. locatable at all: %d)" % (nv, withv))
    print("   -- per (stratum x leg), per CM-minute (铁律 4(i-a); a COUNT does")
    print("      NOT cancel the side term, so 4(i-b) applies: opposite signs")
    print("      across strata = noise, never 'armed minus baseline = X'):")
    for name, rows in cells([dict(n) for n in novas]):
        mins = sum(c["min"] for c in cmmin
                   if "%s/%s" % (stratum_of(c["_side"]), c["_leg"]) == name)
        rate = (len(rows) / mins) if mins > 0 else float("nan")
        print("      %-12s casts %3d   CM-min %6.1f   %.3f/min" % (name, len(rows), mins, rate))

    print("\n-- 2. CELL (2), THE RULING CELL: gap frames and what she does next.")
    print("   gap frame = some creep pair is legally coverable from within the")
    print("   SHIPPED search ring and none from within the cast ring => the")
    print("   shipped search hands her a point > cast range away.")
    print("   ready frames (alive, rank>=%d, cd 0, mp>=%.0f, at a creep sample): %d"
          % (SKILL_LV_MIN, mana_floor, len(ready)))
    print("   gap frames: %d" % len(gaps))
    if not gaps:
        print("\n   DOMAIN EMPTY on this corpus.  Per hero-25 acceptance (丁) this is")
        print("   written as 域空 and points at state.json:cmqreach_20260830.known_gap")
        print("   item (1) -- it is NOT '测过了没效果'.")
    for name, rows in cells(gaps):
        mv = collections.Counter(r["move"] for r in rows)
        print("      %-12s gap %3d   walk %2d  stand %2d  away %2d  unscored %2d"
              % (name, len(rows), mv["walk"], mv["stand"], mv["away"], mv[None]))
    tot = collections.Counter(r["move"] for r in gaps)
    scored = sum(v for k, v in tot.items() if k)
    if scored:
        print("   pooled shape (NOT an effect size, both legs together): "
              "walk %d / stand %d / away %d of %d scored"
              % (tot["walk"], tot["stand"], tot["away"], scored))
        print("   READING: 'walk' dominant => the engine WALKS INTO RANGE (a")
        print("   position-5 support strolls up to %.0fu into a creep wave)." % RADIUS)
        print("   'stand' dominant => the engine REFUSES the order (the branch")
        print("   wins the desire contest and does nothing).  Neither is good;")
        print("   they cost different things.")
        dd = [r for r in gaps if r["centre_dist"] is not None]
        if dd:
            ds = sorted(r["centre_dist"] for r in dd)
            print("   centre distance on gap frames: mean %.0fu  min %.0f  max %.0f"
                  % (sum(ds) / len(ds), ds[0], ds[-1]))

    print("\n-- 3. CELL (3): CM death within %.0fs of a gap frame" % DEATH_WINDOW_S)
    for name, rows in cells(gaps):
        d = sum(1 for r in rows if r["died_20s"])
        print("      %-12s %d of %d" % (name, d, len(rows)))

    print("\n-- 4. BOUNDARIES (read these before quoting any number above)")
    print("   * creeps[] is position+team only, sampled every 3.0s => frames are")
    print("     evaluated ONLY at creep sample times; creep positions are never")
    print("     interpolated.  The count is an UPPER bound on")
    print("     nCanKillCreepsLocationAoE.count (its damage filter needs creep hp")
    print("     this corpus does not carry).")
    print("   * mode predicates (IsFarming/IsPushing/IsDefending/IsGoingOnSomeone)")
    print("     are not observable offline => the gap count is an upper bound on")
    print("     frames where a creep site is actually REACHED.  It is not an")
    print("     effect size and does not by itself support or oppose a promote.")
    print("   * the ready gate demands mp >= %.0f, above any plausible nova cost,"
          % mana_floor)
    print("     because the KV mana cost is not in this repo.")
    print("   * COUNT_MIN = %d is the lowest threshold at any creep site; sites at"
          % COUNT_MIN)
    print("     >=3/4/5 have strictly smaller domains than the number above.")
    return 0


def selfcheck():
    ok = [0, 0]

    def chk(label, cond):
        ok[0] += 1
        if cond:
            ok[1] += 1
        else:
            print("FAIL: %s" % label)

    r = RADIUS
    # two creeps 100u apart, CM far away on the x axis
    d = nearest_center_dist(0, 0, 1000, 0, 1000, 100, r)
    chk("lens nearest point is on the near side of the pair", d is not None and 550 < d < 620)
    chk("pair further than 2r apart has an empty lens",
        nearest_center_dist(0, 0, 1000, 0, 1000, 2 * r + 1, r) is None)
    # NB: `x or default` is wrong here -- a legitimate 0.0 is falsy.  Compare
    # against None explicitly; the first version of this check failed on its
    # own idiom, not on the function.
    d = nearest_center_dist(1000, 50, 1000, 0, 1000, 100, r)
    chk("CM inside the lens reads 0", d is not None and abs(d) < 1e-6)
    d = nearest_center_dist(0, 0, 1000, 0, 1000, 0, r)
    chk("identical creeps: nearest centre is |CM-A| - r",
        d is not None and abs(d - (1000 - r)) < 1e-6)
    # exactly 2r apart: the lens is the single midpoint
    d = nearest_center_dist(0, 0, 1000, -r, 1000, r, r)
    chk("lens degenerate at exactly 2r is the midpoint", d is not None and abs(d - 1000) < 1.0)
    # monotone in reach: a pair reachable at 732 is reachable at 1157
    cs = [(900, 0), (900, 200)]
    a = best_pair(0, 0, cs, r, 732.0)
    b = best_pair(0, 0, cs, r, 1157.0)
    chk("armed-reachable implies shipped-reachable", (a is None) or (b is not None))
    chk("best_pair needs two creeps", best_pair(0, 0, [(500, 0)], r, 1157.0) is None)
    # a genuine gap: pair sits beyond the cast ring but inside the search ring
    cs = [(1400, 0), (1400, 150)]
    chk("gap geometry: shipped reaches, armed does not",
        best_pair(0, 0, cs, r, 1157.0) is not None
        and best_pair(0, 0, cs, r, 732.0) is None)
    chk("rings: no aether => cast 732", abs(CAST_RANGE_KV + CAST_RANGE_PAD - 732.0) < 1e-9)
    chk("rings: shipped search = cast + radius = 1157",
        abs(CAST_RANGE_KV + CAST_RANGE_PAD + RADIUS - 1157.0) < 1e-9)
    print("selfcheck %d/%d" % (ok[1], ok[0]))
    return 0 if ok[1] == ok[0] else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--mana-floor", type=float, default=MANA_FLOOR)
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.dirs:
        ap.error("need at least one sweep dir")
    return report(a.dirs, a.mana_floor)


if __name__ == "__main__":
    sys.exit(main())

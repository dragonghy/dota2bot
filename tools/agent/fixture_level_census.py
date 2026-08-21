#!/usr/bin/env python3
"""Census the hero-level / ability-level / talent state carried by the fixture
archive (dev-only, zero cost -- reads tests/fixtures/ only).

WHY THIS EXISTS
---------------
Three independent investigations (hero 2026-08-21T10:05Z on CM's Freezing
Field, `lion_finger_domain.py`'s docstring on Finger, `od_ult_gate.py`'s
docstring on Sanity's Eclipse) each reported, from three different corpora,
that the ultimate they were studying sits at level 1 for virtually the whole
game.  Each treated it as a local fact about its own hero.  If it is instead a
property of the turbo LEVEL CURVE, then it constrains every hero file at once
-- ability constants, and above all `tTalentTreeList`, whose tiers are gated on
hero level 10/15/20/25.

The fixture archive is the cheapest corpus we own: 90+ real frames from real
turbo games, each one recording the level of ALL TEN heroes plus their ability
levels.  The frames were selected for a subject's behaviour, so `t` is biased;
but at a given frame the nine NON-subject heroes' levels are not selected for,
which is what makes this readable at all.

DENOMINATOR DISCIPLINE (director rule, test_set.md Z.2)
------------------------------------------------------
Fixtures cluster: several frames often come from one game.  Every headline
number here is therefore reported over DISTINCT GAMES, with the frame count
shown only as context.  Per-game aggregates take the LATEST frame of that game
(levels are monotone in time, so the latest frame is that game's high-water
mark within the archive).

SAMPLING INTERVAL (declared, per the rule added 2026-08-21T11:0xZ)
------------------------------------------------------------------
The fixture archive was generated from timelines dumped at MIXED intervals
(the dumper's default is 1.0s; at least one group has dumped at 0.5s).  This
census is nonetheless GRID-INVARIANT, and the reason has to be stated rather
than assumed: it reports a hero's LEVEL AT A CHOSEN INSTANT, not a
residency-weighted rate.  Level is a step function of time, so making the grid
denser adds samples without changing what any of them says.  The frames here
were also selected by a human for a subject's behaviour, not drawn off a grid
at all.  Contrast the frame-level rates in `capmono_refusal.py`, which moved
-7.70 -> -12.69pp on the same 40 games purely by halving the interval.

KNOWN LIMITS (do not launder these away)
----------------------------------------
* Selection bias in `t`: the archive is not a uniform sample of game time.  The
  level-vs-time table exists so a reader can see the observed `t` range instead
  of taking a single mean.
* The archive is a floor, not the end of the game: the last frame we happen to
  hold for a game is not that game's final state.  Every "max level reached"
  number here is a LOWER BOUND on the true end-of-game level.
* Talent detection reads `special_bonus_*` entries out of each unit's ability
  list.  Absence is only evidence if the dump emits them when present -- see
  the SANITY section of the output, which reports how many units carry one at
  all.  If that count is zero the talent read is vacuous and is reported as
  UNREADABLE rather than as "no talents taken".
"""

import os
import re
import sys
from collections import defaultdict

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FIXDIR = os.path.join(REPO, "tests", "fixtures")

# Talent tiers in Dota 2: a point becomes available at each of these hero levels.
TALENT_TIERS = (10, 15, 20, 25)
# Ultimate points become available at these hero levels.
ULT_TIERS = (6, 12, 18)
# "Late game" for a turbo match.  Anchor: the turbo games in this project's own
# batch corpus average ~670s (director charter, 2026-08-19T13:04Z addendum), so
# t >= 540s is the last ~20% of a typical game.
LATE_T = 540

UNIT_RE = re.compile(r"\{\s*name\s*=\s*'(npc_dota_hero_[a-z_]+)'\s*,(.*?)\n", re.S)
LEVEL_RE = re.compile(r"\blevel\s*=\s*(\d+)")
ALIVE_RE = re.compile(r"\balive\s*=\s*(true|false)")
GAME_RE = re.compile(r"game\s*=\s*'([^']+)'")
TIME_RE = re.compile(r"\btime\s*=\s*([0-9.]+)")


def parse_fixture(path):
    """Return (game, time, [unit dicts]) or None if the file is not a frame."""
    src = open(path, encoding="utf-8").read()
    g = GAME_RE.search(src)
    t = TIME_RE.search(src)
    if not g or not t:
        return None
    units = []
    # Units are one-per-line blocks; the abilities line follows on the next line.
    lines = src.split("\n")
    for i, line in enumerate(lines):
        m = re.search(r"\{\s*name\s*=\s*'(npc_dota_hero_[a-z_]+)'\s*,", line)
        if not m:
            continue
        name = m.group(1)
        lvl = LEVEL_RE.search(line)
        if not lvl:
            continue
        alive = ALIVE_RE.search(line)
        # The abilities table lives on one of the following lines of this block,
        # before the next unit starts.
        ab_src = ""
        for j in range(i + 1, min(i + 6, len(lines))):
            if re.search(r"\{\s*name\s*=\s*'npc_dota_hero_", lines[j]):
                break
            if "abilities = {" in lines[j]:
                ab_src = lines[j]
                break
        abilities = []
        for am in re.finditer(r"\{\s*name\s*=\s*'([a-z_0-9]+)'\s*,\s*level\s*=\s*(\d+)", ab_src):
            abilities.append((am.group(1), int(am.group(2))))
        units.append(dict(name=name, level=int(lvl.group(1)),
                          alive=(alive.group(1) == "true") if alive else True,
                          abilities=abilities))
    return g.group(1), float(t.group(1)), units


def main():
    frames = []
    for fn in sorted(os.listdir(FIXDIR)):
        if not fn.endswith(".lua"):
            continue
        parsed = parse_fixture(os.path.join(FIXDIR, fn))
        if parsed and parsed[2]:
            frames.append((fn,) + parsed)

    if not frames:
        print("no parseable fixture frames found", file=sys.stderr)
        return 1

    games = defaultdict(list)
    for fn, game, t, units in frames:
        games[game].append((t, fn, units))
    for g in games:
        games[g].sort()

    print("=" * 74)
    print("FIXTURE LEVEL CENSUS  (dev-only, zero cost)")
    print("=" * 74)
    print("frames parsed : %d" % len(frames))
    print("DISTINCT GAMES: %d   <- every headline below is over this denominator"
          % len(games))
    print("hero-slots read: %d" % sum(len(u) for _, _, _, u in frames))

    # ---- SANITY: is the talent read even possible? ----------------------
    units_with_talent = 0
    total_units = 0
    talent_names = defaultdict(int)
    for _, _, _, units in frames:
        for u in units:
            total_units += 1
            tal = [a for a, _ in u["abilities"] if a.startswith("special_bonus")]
            if tal:
                units_with_talent += 1
                for a in tal:
                    talent_names[a] += 1
    print()
    print("-- SANITY: can we see talents at all? --")
    print("hero-slots carrying a special_bonus_* entry: %d / %d (%.1f%%)"
          % (units_with_talent, total_units, 100.0 * units_with_talent / total_units))
    if units_with_talent == 0:
        print("  => UNREADABLE: the dump never emits talents; every talent number")
        print("     below is vacuous and must not be read as 'no talents taken'.")
    else:
        top = sorted(talent_names.items(), key=lambda kv: -kv[1])[:6]
        print("  distinct talent ids seen: %d; most common: %s"
              % (len(talent_names), ", ".join("%s x%d" % kv for kv in top)))

    # ---- Level reached, per game (lower bound) --------------------------
    print()
    print("-- HERO LEVEL REACHED, per game (LOWER BOUND: latest frame we hold) --")
    print("%-16s %7s %7s %7s %7s" % ("game", "last_t", "max_lvl", "med_lvl", "min_lvl"))
    per_game_max = []
    per_game_med = []
    for g in sorted(games):
        t, fn, units = games[g][-1]
        lv = sorted(u["level"] for u in units)
        med = lv[len(lv) // 2]
        per_game_max.append(max(lv))
        per_game_med.append(med)
        print("%-16s %7.1f %7d %7d %7d" % (g[:16], t, max(lv), med, min(lv)))

    print()
    print("across %d games -- max-level: min %d / median %d / max %d"
          % (len(games), min(per_game_max), sorted(per_game_max)[len(per_game_max) // 2],
             max(per_game_max)))
    print("across %d games -- MEDIAN hero level: min %d / median %d / max %d"
          % (len(games), min(per_game_med), sorted(per_game_med)[len(per_game_med) // 2],
             max(per_game_med)))

    # ---- Talent-tier reachability --------------------------------------
    print()
    print("-- TALENT TIER REACHABILITY (hero-slots at the latest frame per game) --")
    print("a tier is 'reached' by a hero-slot whose level >= the tier level")
    slots = []
    for g in sorted(games):
        _, _, units = games[g][-1]
        slots.extend(units)
    for tier in TALENT_TIERS:
        n = sum(1 for u in slots if u["level"] >= tier)
        gcount = sum(1 for g in games if any(u["level"] >= tier for u in games[g][-1][2]))
        print("  level >= %-2d : %4d / %d hero-slots (%5.1f%%)   in %d / %d games"
              % (tier, n, len(slots), 100.0 * n / len(slots), gcount, len(games)))

    print()
    print("-- ULTIMATE POINT TIERS (same slots) --")
    for tier in ULT_TIERS:
        n = sum(1 for u in slots if u["level"] >= tier)
        gcount = sum(1 for g in games if any(u["level"] >= tier for u in games[g][-1][2]))
        print("  level >= %-2d : %4d / %d hero-slots (%5.1f%%)   in %d / %d games"
              % (tier, n, len(slots), 100.0 * n / len(slots), gcount, len(games)))

    # ---- LATE-GAME WINDOW: the bias-controlled read ---------------------
    # The section above is confounded: many games' latest archived frame is
    # mid-game (some as early as t=37s), so a tier can read 0% simply because
    # we never watched long enough.  Conditioning on t removes exactly that
    # confound -- among frames late in a turbo game, what level are heroes?
    print()
    print("-- LATE-GAME WINDOW (t >= %ds): the bias-controlled read --" % LATE_T)
    late = [(g, t, u) for _, g, t, u in frames if t >= LATE_T]
    late_games = {}
    for g, t, u in late:
        if g not in late_games or t > late_games[g][0]:
            late_games[g] = (t, u)
    if not late_games:
        print("  no frames in the window -- nothing readable")
    else:
        lslots = [u for _, (_, units) in late_games.items() for u in units]
        print("  %d games, %d hero-slots, t range %.0f..%.0fs"
              % (len(late_games), len(lslots),
                 min(t for t, _ in late_games.values()),
                 max(t for t, _ in late_games.values())))
        for tier in (6, 10, 12, 15, 18, 20, 25):
            n = sum(1 for u in lslots if u["level"] >= tier)
            gc = sum(1 for _, (_, units) in late_games.items()
                     if any(u["level"] >= tier for u in units))
            tag = ""
            if tier in TALENT_TIERS:
                tag = "  <- talent tier"
            elif tier in ULT_TIERS:
                tag = "  <- ult point"
            print("    level >= %-2d : %3d / %d slots (%5.1f%%)  in %d / %d games%s"
                  % (tier, n, len(lslots), 100.0 * n / len(lslots),
                     gc, len(late_games), tag))
        lv = sorted(u["level"] for u in lslots)
        print("    level distribution: min %d / p25 %d / median %d / p75 %d / max %d"
              % (lv[0], lv[len(lv) // 4], lv[len(lv) // 2],
                 lv[3 * len(lv) // 4], lv[-1]))

    # ---- Talent uptake, with its own falsification test -----------------
    # A hero at level >= 10 who carries no special_bonus_* entry either did not
    # spend the point, or the dump does not emit talents.  Those two are
    # separated by the sub-10 slots: if the dump were emitting spuriously, we
    # would see talents on heroes too low to have one.
    print()
    print("-- TALENT UPTAKE (all games, latest frame each) --")
    below = [u for u in slots if u["level"] < 10]
    above = [u for u in slots if u["level"] >= 10]
    bad = sum(1 for u in below
              if any(a.startswith("special_bonus") for a, _ in u["abilities"]))
    print("  FALSIFICATION: slots at level < 10 carrying a talent: %d / %d"
          % (bad, len(below)))
    if bad:
        print("    => the talent read is NOT trustworthy (talents on heroes too")
        print("       low to own one); treat every number below as UNREADABLE.")
    else:
        print("    => 0, as required: the read does not fire spuriously.")
    if above:
        got = sum(1 for u in above
                  if any(a.startswith("special_bonus") for a, _ in u["abilities"]))
        print("  slots at level >= 10 carrying >= 1 talent: %d / %d (%.1f%%)"
              % (got, len(above), 100.0 * got / len(above)))
        print("  (the complement is either an unspent point or a dump gap --")
        print("   this census cannot separate those two; it only sizes them.)")

    # ---- Ability-level context -----------------------------------------
    # The fixture does not flag which ability is the ultimate, so we report a
    # distribution rather than claiming an ult level.
    print()
    print("-- ABILITY-LEVEL CONTEXT (non-talent abilities, latest frame each) --")
    hist = defaultdict(int)
    for u in slots:
        non_talent = [lv for a, lv in u["abilities"] if not a.startswith("special_bonus")]
        if not non_talent:
            continue
        if u["level"] >= 12:
            hist["hero >= 12 : abilities still at lvl 1"] += sum(1 for lv in non_talent if lv == 1)
            hist["hero >= 12 : hero-slots"] += 1
        hist["all       : abilities at lvl 0 (unlearned)"] += sum(1 for lv in non_talent if lv == 0)
    for k in sorted(hist):
        print("  %-44s %d" % (k, hist[k]))

    # ---- Level vs time --------------------------------------------------
    print()
    print("-- LEVEL vs GAME TIME (all frames, median hero level in the frame) --")
    buckets = defaultdict(list)
    for _, game, t, units in frames:
        b = int(t // 120) * 120
        lv = sorted(u["level"] for u in units)
        buckets[b].append(lv[len(lv) // 2])
    print("%-14s %7s %9s %9s" % ("t window", "frames", "med_lvl", "range"))
    for b in sorted(buckets):
        v = sorted(buckets[b])
        print("%-14s %7d %9d %9s"
              % ("%d-%ds" % (b, b + 120), len(v), v[len(v) // 2],
                 "%d..%d" % (v[0], v[-1])))
    return 0


if __name__ == "__main__":
    sys.exit(main())

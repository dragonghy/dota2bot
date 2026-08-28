#!/usr/bin/env python3
"""How close does a hero in a given level/clock band ever get to an enemy tower?

Written for one question and kept because the question recurs: the graded
tower-fear ladder in `mode_farm_generic` gives its YOUNGEST band the WIDEST
ring (1200 u), and the sibling copy in `mode_retreat_generic` dropped that rung
(see `write_only_local_census.py`).  Before arguing about restoring it, ask
whether its band ever stands inside the ring at all.

It does not, and not by a hair: over the fixture archive the closest a hero in
the rung's own band (level <= 2 or t < 2:00) ever comes to an enemy tower is
1310 u -- 110 u OUTSIDE the 1200 u ring the rung would use, and 412 u outside
the 898 u ring the retreat copy actually has.  Median 2086 u.  The zero is not
"the archive has no young frames" (72 frames at level <= 2, 70 at t < 2:00) and
not "the archive has no tower-adjacent frames" (minimum over all frames: 173 u).
It is the band and the ring failing to overlap, which is the `0GEO` judgement
again: a typical value is only typical if its distribution overlaps the target.

WHY THE MAP IS USABLE AT ALL (`0GEO`, reproduced here as an assertion):
`GetLocationAlongLane` is a mock constant in fixtures, but TOWERS ARE OBJECTS
THE CORPUS CARRIES.  Every fixture with a `buildings` table lists the same 22
towers at the same coordinates, so tower geometry is a MEASURED constant of
this engine build, not a model.  The tool asserts the 22 and refuses to report
if the count moves.

LIMITS:
  * `bot:GetNearbyTowers(r, true)` returns only LIVE enemy towers.  This walks
    the static 22, so late-game readings over-count (a dead tower still counts).
    That is harmless for the bands this answers about -- nothing is down at
    level <= 2 -- and it is why the tool prints the band's own frame count.
  * The archive is INCIDENT-selected fixtures, not a uniform sample of frames,
    and it GROWS -- so no count of it is quoted here on purpose (`0QUOTE`: a
    frozen corpus size in prose rots silently, because nothing asserts prose;
    the live number is `carrier_fixtures` in the report below).  Treat a count
    as a lower bound.  The separation above does not
    rest on the sample: a hero at level <= 2 is at their own lane's creep-meet
    point, roughly midway between the two tier-1s, and the measured median
    (2086 u) is what that geometry predicts.
  * Distance is straight-line, which is what `GetNearbyTowers` uses too.
"""

import argparse
import glob
import json
import math
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIXTURES = os.path.join(REPO, "tests", "fixtures")

BUILDING_RE = re.compile(
    r"name = '(\w+)', team = (\d+), x = (-?[\d.]+), y = (-?[\d.]+), alive = (\w+)")
HERO_RE = re.compile(
    r"\{ name = '(npc_dota_hero_\w+)', team = (\d+), x = (-?[\d.]+), y = (-?[\d.]+)"
    r".*?level = (\d+), alive = (\w+)")
TIME_RE = re.compile(r"time = ([\d.]+)")

EXPECTED_TOWERS = 22        # 11 per side: 3 lanes x 3 tiers + 2 ancient guards


def towers():
    """The 22 tower positions, asserted identical across every carrier fixture."""
    seen = {}
    for path in sorted(glob.glob(os.path.join(FIXTURES, "*.lua"))):
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        m = re.search(r"buildings = \{(.*?)\n  \}", src, re.S)
        if not m:
            continue
        here = set()
        for line in m.group(1).splitlines():
            mm = BUILDING_RE.search(line)
            if mm and mm.group(1) == "tower":
                here.add((int(mm.group(2)), float(mm.group(3)), float(mm.group(4))))
        seen[os.path.basename(path)] = here
    if not seen:
        raise SystemExit("no fixture carries a buildings table")
    union = set().union(*seen.values())
    return sorted(union), seen


def frames():
    """(team, x, y, level, time) for every ALIVE hero in every fixture."""
    out = []
    for path in sorted(glob.glob(os.path.join(FIXTURES, "*.lua"))):
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            src = fh.read()
        tm = TIME_RE.search(src)
        t = float(tm.group(1)) if tm else None
        for line in src.splitlines():
            mm = HERO_RE.search(line)
            if not mm or mm.group(6) != "true":
                continue
            out.append((int(mm.group(2)), float(mm.group(3)), float(mm.group(4)),
                        int(mm.group(5)), t))
    return out


def band_report(max_level=2, max_time=120.0):
    tow, carriers = towers()
    if len(tow) != EXPECTED_TOWERS:
        raise SystemExit("tower count moved: %d (expected %d) -- the map is no "
                         "longer a measured constant, re-derive before quoting"
                         % (len(tow), EXPECTED_TOWERS))
    rows = frames()
    band, alld = [], []
    for team, x, y, lvl, t in rows:
        d = min(math.hypot(x - tx, y - ty) for (tt, tx, ty) in tow if tt != team)
        alld.append(d)
        if lvl <= max_level or (t is not None and t < max_time):
            band.append(d)
    band.sort()
    return {
        "towers": len(tow),
        "carrier_fixtures": sum(1 for v in carriers.values() if v),
        "hero_frames": len(rows),
        "band_frames": len(band),
        "band_min": round(band[0]) if band else None,
        "band_median": round(band[len(band) // 2]) if band else None,
        "all_min": round(min(alld)) if alld else None,
        "max_level": max_level,
        "max_time": max_time,
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--level", type=int, default=2)
    ap.add_argument("--time", type=float, default=120.0)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    r = band_report(args.level, args.time)
    if args.json:
        print(json.dumps(r, indent=2, sort_keys=True))
    else:
        print("MAP       towers %d over %d carrier fixtures (measured constant)"
              % (r["towers"], r["carrier_fixtures"]))
        print("CORPUS    alive hero frames %d; closest ANY frame to an enemy "
              "tower %d u" % (r["hero_frames"], r["all_min"]))
        print("BAND      level <= %d or t < %.0f: %d frames; closest %d u, "
              "median %d u" % (r["max_level"], r["max_time"], r["band_frames"],
                               r["band_min"], r["band_median"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

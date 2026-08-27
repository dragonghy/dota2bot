#!/usr/bin/env python3
"""How often is a hero within N units of an enemy hero, across tests/fixtures/?

WHY THIS EXISTS.  A talent whose payout needs an enemy inside some radius can be
priced by asking how much of the game that is true for -- the "payoff
reachability" ruler the focus hero files use.  This answers it off the fixture
corpus, which costs nothing and is the only frame data this repo holds locally.

WHAT IT CANNOT DO, and the reason the hero files quote its output with a bound
attached: the fixtures were each frozen for some OTHER hero's decision, so a
subject hero's frames are an incidental sample, not a sample of his fights.  And
the corpus is early-game -- print the level range with `--verbose` and check it
against the tier you are pricing before quoting anything.  A reading nine levels
below the tier is corroboration at best.

    python3 tools/agent/fixture_proximity_census.py axe 275 315 400
    python3 tools/agent/fixture_proximity_census.py axe 275 --verbose

Exit 0 always: this is a measuring tool, not a gate.
"""
import argparse
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FIXTURES = os.path.join(ROOT, 'tests', 'fixtures')

# The generated fixtures put one unit per line, name first.  Reading them with a
# regex rather than a Lua interpreter keeps this runnable in a container that has
# python but no lua5.1 -- the same reason the other censuses here do it.
UNIT = re.compile(
    r"\{ name = '([^']+)', team = (\d+), x = (-?[\d.]+), y = (-?[\d.]+),"
    r".*?level = (\d+), alive = (true|false)"
)


def units_of(path):
    with open(path) as fh:
        text = fh.read()
    out = []
    for m in UNIT.finditer(text):
        out.append({
            'name': m.group(1),
            'team': int(m.group(2)),
            'x': float(m.group(3)),
            'y': float(m.group(4)),
            'level': int(m.group(5)),
            'alive': m.group(6) == 'true',
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('hero', help="unit short name, e.g. axe (npc_dota_hero_ is added)")
    ap.add_argument('radii', nargs='*', type=float, default=[],
                    help='one or more radii in Dota units')
    ap.add_argument('--verbose', action='store_true',
                    help='print every frame that has an enemy inside the widest radius')
    args = ap.parse_args()

    radii = sorted(args.radii) or [275.0]
    subject = 'npc_dota_hero_' + args.hero
    files = sorted(f for f in os.listdir(FIXTURES) if f.endswith('.lua'))

    frames = 0
    levels = []
    hits = {r: 0 for r in radii}       # frames with >= 1 enemy inside r
    inside = {r: 0 for r in radii}     # enemy-instances inside r, summed over frames
    widened = 0                        # frames the widest radius reaches an enemy the narrowest does not

    for name in files:
        units = units_of(os.path.join(FIXTURES, name))
        for me in [u for u in units if u['name'] == subject and u['alive']]:
            frames += 1
            levels.append(me['level'])
            per = {r: 0 for r in radii}
            for other in units:
                if other['team'] == me['team'] or not other['alive']:
                    continue
                d = math.hypot(other['x'] - me['x'], other['y'] - me['y'])
                for r in radii:
                    if d <= r:
                        per[r] += 1
            for r in radii:
                if per[r]:
                    hits[r] += 1
                inside[r] += per[r]
            if per[radii[-1]] > per[radii[0]]:
                widened += 1
            if args.verbose and per[radii[-1]]:
                counts = '  '.join('r%g=%d' % (r, per[r]) for r in radii)
                print('  %-46s lv%-3d %s' % (name, me['level'], counts))

    if not frames:
        print('%s appears in no fixture frame.' % subject)
        return 0

    print('\n%s: %d fixture frames, levels %d..%d, over %d fixtures'
          % (args.hero, frames, min(levels), max(levels), len(files)))
    for r in radii:
        print('  within %-5g : %2d/%d frames have >= 1 enemy hero (%d enemy-instances)'
              % (r, hits[r], frames, inside[r]))
    if len(radii) > 1:
        print('  frames where %g reaches an enemy %g does not: %d'
              % (radii[-1], radii[0], widened))
    print('  BOUND: fixture frames are frozen for other heroes\' decisions and this '
          'corpus is early-game.\n         Check the level range above against the '
          'tier being priced before quoting this.')
    return 0


if __name__ == '__main__':
    sys.exit(main())

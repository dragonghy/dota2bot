#!/usr/bin/env python3
"""Skill-point stall census -- WHO STOPPED LEVELLING ABILITIES, AND WHEN.

WHY THIS FILE EXISTS (GH #286, replay-check 2026-08-28 -> 2026-08-29)
---------------------------------------------------------------------
On 2026-08-28 Obsidian Destroyer was found, frame by frame, to reach level
21-25 having spent **six** skill points, with the last point spent at
t=228..308 in a ~1550 s game, while the other nine heroes in the same game
sat at 14-20 points.  The source derivation (GH #286) is:

  * `FunLib/aba_skill.lua:102-110` writes the ultimate into the FIXED index
    `sAbilityList[6]` only when its engine slot is `>= 4`.  An ultimate in a
    lower slot is `table.insert`-ed instead, so `sAbilityList[6]` stays nil
    while the generic build table `{2,1,4,2,2,6,...}` still names `6`.
  * `ability_item_usage_generic.lua:198-202` HAS a nil handler, but it is
    inside the `:192` guard `if #sAbilityLevelUpList >= 1`.  Lua 5.1: once
    `table.remove(t,1)` has walked the hole to the head of the list, `t[1]`
    is nil AND `#t == 0` -- the guard is false, and the nil handler is
    unreachable at the one moment it exists for.  Levelling stops for the
    rest of the game.
  * The only escape is `:331` (`botLevel > 25`), which is why 26-level OD
    recovered 16 points and the five games that ended at 21-25 did not.

That is a FACTORY default: no gate, no candidate id, identical on both legs
of every A/B.  It changes the ability levels of every affected hero in every
game.  This module exists so the question "WHICH heroes are affected" stops
being answered by an inline read that dies with the session (the #263
lesson: a read that is not in the tree is a read the next round redoes).

WHAT IT MEASURES
----------------
Per (game, hero) it reconstructs the skill-point history from the snapshot
stream and reports:

    level        hero level at the last frame that carries abilities
    pts_abil     sum of ability levels (entries NOT named special_bonus_*)
    pts_talent   sum of talent levels (special_bonus_* entries)
    pts          pts_abil + pts_talent
    t_last_gain  last time the point total went UP
    t_end        last sampled t for that entity
    frozen_frac  (t_end - t_last_gain) / (t_end - t_horn): how much of the
                 game the hero spent not spending a point

`STALL` is flagged on `level >= LEVEL_MIN and pts <= PTS_MAX` (15 / 8 by
default, both overridable).  Those two numbers are a CUT, not a law -- so
the report always prints the full `pts` histogram next to the flag, per iron
rule 4(ii): a count over a small integer range is reported as a
distribution, never as a bare median, so the knife edge is visible.  If the
histogram turns out to be dense at 9-13 the cut is doing work it cannot
justify and the flag should be re-derived, not re-tuned.

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **This is the SYMPTOM, not the mechanism.**  A hero can be listed here
   for reasons unrelated to GH #286 (died at level 15 in a 12-minute game
   and simply had few levels; a hero-specific build that genuinely buys few
   ability levels).  Confirming #286 for a listed hero means going back to
   the source: does its build table name an index that is nil in
   `sAbilityList`?  This module cannot see `GetAbilityInSlot`.
2. **The dumper's `abilities` array is not the engine slot array.**  Hidden
   / not-learnable slots that `aba_skill.lua` still walks do not appear
   here, and talents appear only once they have been learned.  So the
   position of the ultimate in this array is NOT the `slot >= 4` test.  Do
   not re-derive the root cause from `abil_names`; use it only to say which
   ability sat at 0.
3. **The last frame is not the final state** (replay-check charter, tool
   pit, 2026-08-28).  A game's last snapshot frequently carries
   `abilities: null` or a single-element remnant; reading it as the end
   state produced "jakiro: level 21, 1 point" and "vengeful: level 9, 1
   point", both false.  This module takes the last frame whose `abilities`
   is non-empty, and reports `t_end` from the entity's own last sample so
   the gap is visible.
4. **Illusions are dropped** via `entities.frames_by_hero` (GH #176): an
   illusion carries the same hero name and player_id and would otherwise
   contribute a second, lower, point total under the same name.
5. Counts here are per (game, hero) OBSERVATIONS, not per hero.  A hero
   seen in six games contributes six rows; the summary reports both.
6. Nothing here is an armed-vs-baseline differential.  The defect is on the
   factory path, both legs are identical, and no arm string is read.
"""
import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from entities import frames_by_hero, canon  # noqa: E402

TALENT_PREFIX = 'special_bonus_'

# The cut. Deliberately far from the observed peer band (14-20 points at
# levels 20+) so the flag is not sitting on the edge of the distribution --
# and the histogram is printed regardless so that claim stays checkable.
LEVEL_MIN = 15
PTS_MAX = 8

HORN_T = 0.0


def _points(abilities):
    """(ability points, talent points) at one frame."""
    pa = pt = 0
    for a in abilities or ():
        lv = a.get('level') or 0
        if (a.get('name') or '').startswith(TALENT_PREFIX):
            pt += lv
        else:
            pa += lv
    return pa, pt


def census_game(timeline, game_name):
    """One row per real hero in one game.  See LIMITS 3 and 4."""
    fr, team = frames_by_hero(timeline)
    rows = []
    for hero, frames in sorted(fr.items()):
        t_end = frames[-1]['t']
        last = None
        for s in reversed(frames):
            if s.get('abilities'):
                last = s
                break
        if last is None:
            rows.append(dict(game=game_name, hero=hero, team=team[hero],
                             level=None, pts=None, note='no abilities frame'))
            continue

        # Walk forward for the last INCREASE in the total, skipping empty
        # frames rather than letting them read as a drop to zero.
        t_last_gain, prev = None, None
        for s in frames:
            if not s.get('abilities'):
                continue
            tot = sum(_points(s['abilities']))
            if prev is None or tot > prev:
                t_last_gain = s['t']
                prev = tot
        pa, pt = _points(last['abilities'])
        span = max(t_end - HORN_T, 1e-6)
        rows.append(dict(
            game=game_name,
            hero=hero,
            team=team[hero],
            level=last['level'],
            pts_abil=pa,
            pts_talent=pt,
            pts=pa + pt,
            t_last_gain=round(t_last_gain, 1) if t_last_gain is not None else None,
            t_abil_frame=round(last['t'], 1),
            t_end=round(t_end, 1),
            frozen_frac=round((t_end - (t_last_gain if t_last_gain is not None else HORN_T)) / span, 3),
            n_abil_entries=len([a for a in last['abilities']
                                if not (a.get('name') or '').startswith(TALENT_PREFIX)]),
            zero_level_abils=[a['name'] for a in last['abilities']
                              if not (a.get('name') or '').startswith(TALENT_PREFIX)
                              and not (a.get('level') or 0)],
            abil_names=[a['name'] for a in last['abilities']],
        ))
    return rows


def is_stall(row, level_min, pts_max):
    return (row.get('level') is not None and row.get('pts') is not None
            and row['level'] >= level_min and row['pts'] <= pts_max)


def summarise(rows, level_min, pts_max):
    out = []
    graded = [r for r in rows if r.get('pts') is not None]
    out.append('== corpus ==')
    out.append('games: %d   (game, hero) rows: %d   ungraded (no abilities frame): %d'
               % (len({r['game'] for r in rows}), len(rows), len(rows) - len(graded)))

    # Iron rule 4(ii): small-integer count -> distribution + threshold share,
    # never a bare median.
    hist = collections.Counter(r['pts'] for r in graded)
    out.append('')
    out.append('== pts histogram (all rows) ==')
    for k in sorted(hist):
        out.append('  pts=%-3d %s (%d)' % (k, '#' * min(hist[k], 60), hist[k]))
    if graded:
        mean = sum(r['pts'] for r in graded) / len(graded)
        share = sum(1 for r in graded if r['pts'] <= pts_max) / len(graded)
        out.append('  mean=%.2f   share(pts<=%d)=%.1f%%   n=%d'
                   % (mean, pts_max, 100 * share, len(graded)))

    stalls = [r for r in graded if is_stall(r, level_min, pts_max)]
    out.append('')
    out.append('== STALL (level>=%d and pts<=%d) -- %d row(s) ==' % (level_min, pts_max, len(stalls)))
    if not stalls:
        out.append('  none')
    else:
        per_hero = collections.Counter(r['hero'] for r in stalls)
        seen = collections.Counter(r['hero'] for r in graded)
        for hero, n in per_hero.most_common():
            out.append('  %-24s %d/%d game(s)' % (hero, n, seen[hero]))
        out.append('')
        for r in sorted(stalls, key=lambda r: (r['hero'], r['game'])):
            out.append('  %s  %-22s lvl=%-3s pts=%-3s (abil=%s tal=%s) '
                       'last_gain=%.1fs t_end=%.1fs frozen=%.0f%%'
                       % (r['game'], r['hero'], r['level'], r['pts'], r['pts_abil'],
                          r['pts_talent'], r['t_last_gain'] or -1, r['t_end'],
                          100 * r['frozen_frac']))
            if r['zero_level_abils']:
                out.append('        never levelled: %s' % ', '.join(r['zero_level_abils']))

    # A hero can be stalled in one game and fine in another (the botLevel>25
    # escape at :331).  Show the per-hero spread so that split is legible.
    out.append('')
    out.append('== per-hero pts spread (heroes with >=2 rows) ==')
    byh = collections.defaultdict(list)
    for r in graded:
        byh[r['hero']].append(r['pts'])
    for hero in sorted(byh):
        v = byh[hero]
        if len(v) < 2:
            continue
        out.append('  %-24s n=%-3d min=%-3d max=%-3d mean=%.1f  %s'
                   % (hero, len(v), min(v), max(v), sum(v) / len(v), sorted(v)))
    return '\n'.join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('timelines', nargs='*', help='timeline JSON files from behav-dump')
    ap.add_argument('--merge', nargs='*', default=[],
                    help='previously written --json census files to fold in')
    ap.add_argument('--json', help='write the raw rows here')
    ap.add_argument('--level-min', type=int, default=LEVEL_MIN)
    ap.add_argument('--pts-max', type=int, default=PTS_MAX)
    args = ap.parse_args()

    rows = []
    for path in args.merge:
        with open(path) as fh:
            rows.extend(json.load(fh))
    for path in args.timelines:
        name = os.path.basename(path).split('.')[0]
        try:
            with open(path) as fh:
                tl = json.load(fh)
        except (OSError, ValueError) as exc:
            print('[skip] %s: %s' % (path, exc), file=sys.stderr)
            continue
        rows.extend(census_game(tl, name))

    if not rows:
        print('no rows -- pass at least one timeline or --merge file', file=sys.stderr)
        return 2

    if args.json:
        with open(args.json, 'w') as fh:
            json.dump(rows, fh, indent=1)
    print(summarise(rows, args.level_min, args.pts_max))
    return 0


if __name__ == '__main__':
    sys.exit(main())

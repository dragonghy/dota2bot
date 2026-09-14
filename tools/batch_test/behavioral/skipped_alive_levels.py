#!/usr/bin/env python3
"""skipped-alive levels: hero levels crossed with ZERO ability-ledger movement
while the body was alive on EVERY frame of that level.

Provenance: GH #817 measured "34/80 bodies spent nothing at hero level 10" and
the 2026-09-14T09:49Z replay-check report measured a per-body `span` of idle
seconds.  Neither separates "held a point" from "was dead" from "the level was
simply the last one".  This ruler does, and it reports per LEVEL rather than per
body, which is what made the shape visible: the holds are not spread evenly, they
pile up in a band.

CUT (iron rule 4(iii) -- quote it with every number this prints):

  body            = (hero name, FIRST idx that name appears in the timeline).
                    One name can own several bodies (illusions, clones); keying
                    by name pools them and biases every hold LONGER, since an
                    illusion never spends.
  ledger movement = a frame where any ability's level exceeds its value on the
                    body's previous frame.  Pre-horn frames (t < 0) are INCLUDED
                    -- the level-1 point is spent at about t=-60, and trimming
                    them turns all 80 bodies into false "skipped level 1"
                    readings (measured: 77 of 80, an artifact, not a finding).
  complete level  = a hero level the body left, i.e. level < the body's maximum.
                    The last level is dropped: the game ended inside it, so
                    "nothing was spent" says nothing.
  skipped-alive   = a complete level with no ledger movement and hp_pct > 0 on
                    100% of its frames.
  terminal        = a skipped-alive level ABOVE the body's last ledger movement
                    (it never spent again).  Non-terminal means a spend did come
                    later.

⛔ LIMIT 1 -- THE BIG ONE.  skipped-alive counts the HOLD, not its LEGALITY.
It does NOT establish that a legal spend target existed at that level: rank and
talent tiers are Dota rules, and this tool reads none of them.  "Non-terminal"
is weaker than it looks -- a body that skips level 12 and spends at 15 may have
been waiting for a tier.  Do not upgrade this count into "N points were wasted".

⛔ LIMIT 2 -- THE TALENT BLIND SPOT, and it is not uniform across heroes.  The
dumper's isRealAbility() drops Special_Bonus_Base entities, which is the class
hero-UNIQUE talent rows share (GH #817's hero-desk comment;
tests/test_talent_uptake_visibility.lua).  For a hero whose build selects a
unique row at a tier, a point spent there raises nothing and this tool reads the
level as skipped whether or not it was.  Generic rows (special_bonus_mp_200 and
friends) have their own class and ARE seen.  ⇒ per-hero counts are not
comparable to each other, and the only clean subjects are those whose selected
rows at the tiers in question are generic.  obsidian_destroyer's t10 is the
worked example (tests/test_skillstall_banked_point_frames.lua pins it).

⛔ LIMIT 4 -- HERO LEVEL 1 IS CONTAMINATED; drop that row before quoting.  A
spend is a RISE over the previous frame, so a body whose first sampled frame
already shows a trained ability has its level-1 spend outside the window and
reads as skipped.  Measured on the 8-game W40 slice: 50 of 80 bodies are already
trained on their first frame, and level 1 prints 27 skipped-alive.  Including
pre-horn frames (see the cut) cuts the artifact from 77 down to those 27; it does
not remove it.  Every other level is clean, because the body is sampled across
the whole of it.

⛔ LIMIT 3 -- this is a whole-roster census on one tree, both teams every game.
There is no armed/baseline leg, so no ab/ba stratification exists for it
(iron rule 4(i-a)): registered as "no ab/ba reading", not as a balanced one.
Anyone comparing it against an armed wave must re-stratify from scratch.
"""
import json
import sys
from collections import defaultdict

FULL = 'npc_dota_hero_'


def _ledger(s):
    return {a['name']: a['level'] for a in (s.get('abilities') or [])}


def levels(path):
    """One row per (body, complete hero level)."""
    d = json.load(open(path))
    first = {}
    for s in d['snapshots']:
        first.setdefault(s['hero'], s['idx'])
    per = defaultdict(list)
    for s in d['snapshots']:
        if s['idx'] == first[s['hero']]:
            per[s['hero']].append(s)

    rows = []
    for hero, frames in per.items():
        frames.sort(key=lambda x: x['t'])
        moved, last_spend, prev = set(), None, None
        for f in frames:
            L = _ledger(f)
            if prev is not None and any(v > prev.get(k, 0) for k, v in L.items()):
                moved.add(f['level'])
                last_spend = f['level']
            prev = L
        bylvl = defaultdict(list)
        for f in frames:
            bylvl[f['level']].append(f)
        top = max(bylvl)
        for lvl in sorted(bylvl):
            if lvl >= top:
                continue
            fr = bylvl[lvl]
            rows.append(dict(
                game=path, hero=hero.replace(FULL, ''), idx=first[hero], level=lvl,
                frames=len(fr), alive=sum(1 for f in fr if f['hp_pct'] > 0),
                spent=lvl in moved, secs=round(fr[-1]['t'] - fr[0]['t'], 1),
                terminal=(last_spend is not None and lvl > last_spend)))
    return rows


def main(paths):
    rows, bodies = [], set()
    for p in paths:
        for r in levels(p):
            rows.append(r)
            bodies.add((r['game'], r['hero']))

    sa = [r for r in rows if not r['spent'] and r['alive'] == r['frames']]
    sd = [r for r in rows if not r['spent'] and r['alive'] < r['frames']]
    term = [r for r in sa if r['terminal']]

    print('games %d  bodies %d  complete levels %d' % (len(paths), len(bodies), len(rows)))
    print('  spent                 %4d' % sum(1 for r in rows if r['spent']))
    print('  SKIPPED-ALIVE         %4d   (no ledger movement, alive on 100%% of frames)' % len(sa))
    print('  skipped, had a corpse %4d' % len(sd))
    if not sa:
        return
    print('  of the skipped-alive: %d terminal / %d non-terminal (a spend came later)'
          % (len(term), len(sa) - len(term)))

    lv = defaultdict(lambda: [0, 0])
    for r in sa:
        lv[r['level']][0 if r['terminal'] else 1] += 1
    print('\nhero level : terminal / non-terminal')
    for l in sorted(lv):
        print('  %-3d  %4d / %d' % (l, lv[l][0], lv[l][1]))

    per = defaultdict(int)
    for r in sa:
        per[r['hero']] += 1
    print('\nskipped-alive levels per hero (⛔ NOT comparable across heroes -- LIMIT 2):')
    for h, n in sorted(per.items(), key=lambda kv: -kv[1]):
        print('  %-24s %3d' % (h, n))

    secs = sorted(r['secs'] for r in sa)
    print('\nskipped-alive seconds: total %.0f, median per level %.1f, max %.1f'
          % (sum(secs), secs[len(secs) // 2], secs[-1]))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('usage: skipped_alive_levels.py <timeline.json> [...]')
    main(sys.argv[1:])

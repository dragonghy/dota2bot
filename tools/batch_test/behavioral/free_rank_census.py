#!/usr/bin/env python3
"""Count the ability ranks a body NEVER BOUGHT, per hero, from level-1 frames.

WHY THIS EXISTS (GH #822, replay-check 2026-09-14T18:xxZ).

`ability_exhaustion_split.py:160` computes

    banked = level - sum(visible ability ranks) - #{tiers 10,15,20,25 reached}

and that sum counts every rank the dumper can see -- INCLUDING ranks the engine
handed out for free.  Two different mechanisms put free ranks on a ledger:

  * an INNATE row (7.36+): stands at rank >= 1 from the body's first frame and
    never moves again (vengeful_spirit_revenge, witch_doctor_gris_gris,
    skeleton_king_innate_vampiric_spirit, bristleback_prickly,
    shadow_shaman_fowl_play);
  * a LINKED group: one point raises several rows at once, so the ledger reads
    3 where 1 point was spent (nevermore's three shadowrazes).  That is LIMIT A
    of the wave meter, which EXCLUDES those bodies rather than repairing them.

⭐ THE POINT OF MEASURING IT AT HERO LEVEL 1.  At level 1 the engine has granted
EXACTLY ONE point.  So

    free_lower_bound = max(sum of visible ranks over the body's level-1 frames) - 1

is a SOUND lower bound on the free ranks that body carries, and it needs no
table of innates, no patch notes, and no Liquipedia round-trip -- it is read off
the frames.  ⛔ It is a LOWER bound, not the count: a rank handed out at a later
level (there are none known, but the instrument does not know that) is invisible
to it.

⭐ WHICH row is free is settled separately and only when the body's level-1
window contains the spend: the row that MOVES inside the window is the bought
one; a row already >= 1 before any movement is free.  When no movement is
captured the tool prints the candidate set and refuses to name one.

⛔ DIRECTION, WHICH MATTERS MORE THAN THE DIGIT.  Over-counting spent makes
`banked` SMALLER.  So every PROVEN row in GH #822 is a LOWER bound and its
conclusion survives; what does NOT survive is reading any individual banked
figure as exact, and `banked < 0` (LIMIT A) now has two causes, not one.

LIMITS
  1. Needs the body's level-1 frames.  A dump that starts after the hero dinged
     2 yields nothing for that body, and the tool says so instead of guessing.
  2. `sum of visible ranks` is the dumper's ledger: a hero-unique talent row is
     dropped before the level>0 branch (GH #817), so a point spent there is
     invisible here too.  At hero level 1 no talent tier is reachable, so this
     cannot inflate the level-1 sum -- which is a second reason the reading is
     taken at level 1 and nowhere else.
  3. ⛔⛔ BODIES ARE THE LONGEST-LIVED idx, AND `min(idx)` IS A NAMED FAILURE OF
     THIS FILE.  The first version keyed on `min(idx)` -- the obvious reading of
     the W71 pit, and wrong.  It produced "no level-1 window" for 5 of 80 bodies,
     which looked like thin dump coverage and was not: in
     20260902_214630_slot2, nevermore's idx set is [870, 1389, 2480] and the
     LOWEST, 870, is an ILLUSION frozen at level 12 from t=373 to the end, while
     the hero is 1389 (t=-64.9, level 1 -> 28).  ⭐ So the W71 pit has a second
     half nobody had written down: keying by idx is necessary and not
     sufficient -- WHICH idx is a real choice, and this repo holds three
     different answers to it (`min` here, "first appearance" in
     ability_exhaustion_split.py, "longest-lived" in make_fixture.py).  Only the
     last is sound, and it is what this file now uses.  ⭐ The DISCRIMINATOR is
     cheap: an illusion's level never moves.  The idx set and the chosen idx are
     printed for every name so the choice stays auditable.
  4. No ab/ba split: this is a whole-roster census over a tree with no armed
     leg, and every game contains both teams (iron rule 4(i-a) -- registered,
     not silently omitted).

Usage:
    python3 free_rank_census.py <timeline.json> [<timeline.json> ...]
"""
import json
import sys
from collections import defaultdict


def ranks(row):
    return {a["name"]: a["level"] for a in (row.get("abilities") or [])}


def main(paths):
    per_hero = defaultdict(list)     # hero -> [free_lower_bound, ...]
    named = defaultdict(set)         # hero -> {row identified as free}
    no_window = []
    for path in paths:
        tl = json.load(open(path))
        bodies = defaultdict(list)
        for s in tl["snapshots"]:
            if s["hero"].startswith("npc_dota_hero_"):
                bodies[(s["hero"], s["idx"])].append(s)
        names = {h for (h, _) in bodies}
        for h in sorted(names):
            idxs = sorted(i for (hh, i) in bodies if hh == h)
            # LONGEST-LIVED, never `min` -- see LIMIT 3.
            idx = max(idxs, key=lambda i: len(bodies[(h, i)]))
            rows = sorted(bodies[(h, idx)], key=lambda r: r["t"])
            lvl1 = [r for r in rows if r["level"] == 1]
            if not lvl1:
                no_window.append((path, h, idx, idxs))
                continue
            sums = [(sum(ranks(r).values()), r) for r in lvl1]
            best = max(sums, key=lambda p: p[0])[0]
            free = best - 1
            per_hero[h].append(free)
            # Identify the free row when the window captured the spend.
            first = ranks(lvl1[0])
            last = ranks(max(sums, key=lambda p: p[0])[1])
            moved = {k for k in last if last[k] > first.get(k, 0)}
            standing = {k for k, v in first.items() if v > 0}
            if free > 0 and moved and standing - moved:
                for k in sorted(standing - moved):
                    named[h].add(k)
    print("games: %d" % len(paths))
    print("%-22s %6s %6s  %s" % ("hero", "bodies", "free>=", "row identified as free"))
    tot_bodies = tot_free = 0
    for h in sorted(per_hero):
        v = per_hero[h]
        tot_bodies += len(v)
        tot_free += sum(v)
        print("%-22s %6d %6s  %s"
              % (h.replace("npc_dota_hero_", ""), len(v),
                 "/".join(str(x) for x in sorted(set(v))),
                 ", ".join(sorted(named[h])) or "-- (no level-1 spend captured)"))
    print("\nbodies measured: %d   free ranks (lower bound, summed): %d"
          % (tot_bodies, tot_free))
    print("bodies with NO level-1 window: %d" % len(no_window))
    for path, h, idx, idxs in no_window:
        print("  %s  %s idx=%d (idx set %s)" % (path, h, idx, idxs))
    print("\n⛔ direction: every free rank here makes ability_exhaustion_split.py's "
          "`banked` read ONE LOWER than truth for that body.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    main(sys.argv[1:])

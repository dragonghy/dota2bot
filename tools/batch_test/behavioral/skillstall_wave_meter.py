#!/usr/bin/env python3
"""Wave-wide meter for GH #799 condition (c): "a bot holds skill points while
it is alive and able to spend them".

Provenance: the 2026-09-14T03:52Z replay-check report section 4 measured ten
heroes in ONE game and found every one of them had a minutes-long stretch of
"alive and spending nothing" (median 615 s).  One game is not a wave reading.
This file is that ruler, re-derived and pinned, so the number can be taken
across a whole wave and pooled.

CALIBRATION (2026-09-14T09:xxZ, ab6c0d/20260902_220100_slot6 -- the very game
section 4 read): `span` below reproduces 9 of that table's 10 rows BIT-EXACT
(vengeful 665.0, nevermore 613.0, death_prophet 302.0, crystal_maiden 742.0,
witch_doctor 801.0, skeleton_king 460.0, skywrath 619.0, bristleback 433.0,
shadow_shaman 615.0).  The 10th (obsidian_destroyer) reads 1163.0 here vs
1139.0 there, a 24 s / 2.1% residual that is NOT explained; it does not move
OD's rank (longest either way).  The section-4 POINTS column is a different
story -- see LIMIT 2.

CUT (quote it with every number this prints -- iron rule 4(iii)):

  body    = (hero name, FIRST idx seen for that name).  One name can own
            several bodies in a timeline (illusions, clones); keying by name
            pools them and biases every stall LONGER, since an illusion never
            spends.
  spend   = a frame where the body's ability ledger rises.  Baselines follow
            levelup_build_meter.py: pre-horn level for abilities (innates are
            already level 1 and are NOT a point), 0 for talents (a talent is
            absent until taken, so its arrival IS the point), level-at-arrival
            for genuinely late grants (scepter/shard).
  span    = the section-4 cut, and the one to quote against that table: from
            the FIRST ALIVE frame after a spend to the LAST ALIVE frame before
            the next spend.  hp_pct > 0 trims the ENDS of the window only --
            an interior death does NOT break it and its seconds ARE counted.
            (That is what the 03:52Z numbers actually are; that report's prose
            said "alive frames only", which reads as if corpse time were
            excluded.  It is not.  See LIMIT 1.)
  strict  = the conservative twin: a death BREAKS the window, so a stall is a
            single uninterrupted alive stretch.  Always <= span.  Report both;
            the gap between them is corpse time, which is idleness the bot is
            not responsible for.
  points  = sum over abilities of (final level - baseline) -- the LEDGER, not
            a count of spend frames.  The 2026-09-14T00:51Z round measured
            that two unrelated abilities can rise inside one 1 Hz sample
            (astral_imprisonment + sanity_eclipse; 1 of 31 same-frame pairs in
            8 games), so counting frames undercounts.  The ledger cannot.
  talents = talents at level >= 1 in the ledger.

LIMIT 1: `span` is a floor on idleness, not a claim about intent.  A hero with
zero unspent points cannot spend and still shows a long span.  Read it next to
`points` and `max_level`: it bites when the level rose across the window (the
points existed and were held).
LIMIT 2: `points` is a LEDGER OF LEVELS, not a count of skill points spent.
A linked ability inflates it: nevermore's shadowraze1/2/3 all rise on one
point, so nevermore reads `points=23` in every game of W40 while it actually
spent 15 points.  For heroes with no linked ability (obsidian_destroyer's
5-6) the two coincide.  Use `spend frames` if you need points spent; use this
column only for "did the ledger move".
LIMIT 3: the section-4 POINTS column is NOT reproduced here -- 5 of 10 rows
differ (vengeful 15 vs 16, witch_doctor 14 vs 15, skeleton_king 15 vs 16,
bristleback 15 vs 17, shadow_shaman 15 vs 17) and no tested rule recovers it
(neither +talents, nor +late grants, nor levelup_build_meter's merged
`n_abil_pts`, which reads bristleback 15 / nevermore 15 / OD 5).  So: do not
pool this file's `points` with that table's.  Quote one or the other.

  skillstall_wave_meter.py <timeline.json> [more...] [--csv]
"""
import json
import os
import sys


def is_talent(name):
    return name.startswith("special_bonus")


def measure(tl):
    """-> list of row dicts, one per body (pre-horn idx only)."""
    first = {}
    for s in tl["snapshots"]:
        first.setdefault(s["hero"], s["idx"])

    base, cur = {}, {}
    span_best, strict_best = {}, {}
    span_open, span_last = {}, {}     # span window: alive-trimmed ends
    strict_open, strict_last = {}, {}  # strict window: death breaks
    max_lvl, n_alive, n_frames = {}, {}, {}

    def close(store_best, store_open, store_last, h):
        if store_open.get(h) is not None and store_last.get(h) is not None:
            v = round(store_last[h] - store_open[h], 1)
            if v > store_best.get(h, -1.0):
                store_best[h] = v
        store_open[h] = None
        store_last[h] = None

    for s in tl["snapshots"]:
        h = s["hero"]
        if s["idx"] != first[h]:
            continue
        n_frames[h] = n_frames.get(h, 0) + 1
        max_lvl[h] = max(max_lvl.get(h, 0), s.get("level") or 0)
        abils = s.get("abilities") or []
        if h not in base:
            base[h] = {a["name"]: a["level"] for a in abils}
            cur[h] = dict(base[h])
            span_best[h] = strict_best[h] = -1.0
            span_open[h] = span_last[h] = None
            strict_open[h] = strict_last[h] = None
            continue
        spent = False
        for a in abils:
            name, lv = a["name"], a["level"]
            if name not in cur[h]:
                b = 0 if is_talent(name) else lv
                base[h][name] = b
                cur[h][name] = b
            if lv > cur[h][name]:
                spent = True
                cur[h][name] = lv
        alive = (s.get("hp_pct") or 0) > 0
        if spent:
            close(span_best, span_open, span_last, h)
            close(strict_best, strict_open, strict_last, h)
            continue
        if not alive:
            close(strict_best, strict_open, strict_last, h)
            continue          # span keeps its window open across the corpse
        n_alive[h] = n_alive.get(h, 0) + 1
        for op, la in ((span_open, span_last), (strict_open, strict_last)):
            if op[h] is None:
                op[h] = s["t"]
            la[h] = s["t"]

    rows = []
    for h in first:
        close(span_best, span_open, span_last, h)
        close(strict_best, strict_open, strict_last, h)
        pts = sum(cur[h][n] - base[h][n] for n in cur[h] if not is_talent(n))
        tal = sum(1 for n in cur[h] if is_talent(n) and cur[h][n] > 0)
        rows.append({
            "hero": h.replace("npc_dota_hero_", ""),
            "idx": first[h],
            "max_level": max_lvl[h],
            "points": pts,
            "talents": tal,
            "span_s": span_best[h] if span_best[h] >= 0 else None,
            "strict_s": strict_best[h] if strict_best[h] >= 0 else None,
            "alive_frames": n_alive.get(h, 0),
        })
    rows.sort(key=lambda r: -(r["span_s"] or -1))
    return rows


def _median(v):
    n = len(v)
    if not n:
        return None
    v = sorted(v)
    return v[n // 2] if n % 2 else round((v[n // 2 - 1] + v[n // 2]) / 2.0, 1)


def main(argv):
    as_csv = "--csv" in argv
    paths = [a for a in argv if not a.startswith("--")]
    allrows = []
    if as_csv:
        print("game,hero,idx,max_level,points,talents,span_s,strict_s,alive_frames")
    for p in paths:
        game = os.path.basename(p).replace(".timeline.json", "")
        rows = measure(json.load(open(p)))
        allrows.extend(rows)
        if as_csv:
            for r in rows:
                print("%s,%s,%d,%d,%d,%d,%s,%s,%d" % (
                    game, r["hero"], r["idx"], r["max_level"], r["points"],
                    r["talents"], r["span_s"], r["strict_s"], r["alive_frames"]))
            continue
        print("== %s  (%d bodies)" % (game, len(rows)))
        print("%-22s %6s %5s %7s %8s %9s %9s" %
              ("hero", "idx", "lvl", "points", "talents", "span_s", "strict_s"))
        for r in rows:
            print("%-22s %6d %5d %7d %8d %9s %9s" %
                  (r["hero"], r["idx"], r["max_level"], r["points"],
                   r["talents"], r["span_s"], r["strict_s"]))

    if as_csv or len(paths) < 2:
        return 0
    sp = [r["span_s"] for r in allrows if r["span_s"] is not None]
    st = [r["strict_s"] for r in allrows if r["strict_s"] is not None]
    print("\n== wave: %d games, %d bodies" % (len(paths), len(sp)))
    print("span_s    min %.1f  median %.1f  max %.1f" % (min(sp), _median(sp), max(sp)))
    print("strict_s  min %.1f  median %.1f  max %.1f" % (min(st), _median(st), max(st)))
    for thr in (300, 600, 900):
        k = sum(1 for v in sp if v >= thr)
        j = sum(1 for v in st if v >= thr)
        print("  span >= %4d s : %3d/%3d (%.1f%%)   strict >= %4d s : %3d/%3d (%.1f%%)" % (
            thr, k, len(sp), 100.0 * k / len(sp),
            thr, j, len(st), 100.0 * j / len(st)))
    zt = sum(1 for r in allrows if r["talents"] == 0)
    print("  0 talents at end : %d/%d (%.1f%%)" % (
        zt, len(allrows), 100.0 * zt / len(allrows)))
    # per-game floor: does EVERY body in a game stall, or only some?
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

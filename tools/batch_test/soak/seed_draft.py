#!/usr/bin/env python3
"""Offline replica of the in-game soak drafter -- answer "which heroes does seed N draft?"
BEFORE spending a wave on a hero-specific soak candidate.

Why this exists (replay-check, 2026-08-19T22:36Z): the 22:11Z wave was launched to
collect condition-(a) evidence for `axebuyblink`, and drafted **zero Axe games** in
224 mirror games -- because one seed produces exactly ONE roster (that is by design:
`custom_loader.ApplySoakDraft` derives the draft deterministically from the seed so
both team VMs agree and the mirrored A/B cancels the draft), so a 4-seed wave samples
only 4 drafts = 40 hero slots out of a 42-hero pool. Axe (pos-3-only) lands in 15.8%
of seeds => a 4-seed wave misses it entirely 50.4% of the time.

This is a line-by-line port of `bots/FunLib/custom_loader.lua:ApplySoakDraft`
(Lehmer LCG s = s*16807 % 2147483647, pick = cand[s % #cand + 1], scarcest position
first, radiant then dire per position). The position order is the tie-broken result of
the Lua `table.sort` in that function; it is pinned here as POS_ORDER and VERIFIED
against real waves -- `--selftest` reproduces the four rosters of seeds 867-870
(wave `spot_20260819_2211xx_1_829202ac`) hero-for-hero, 40/40.

Usage:
  seed_draft.py 867 868 869 870        # what do these seeds draft?
  seed_draft.py --find axe --count 4   # give me 4 seeds that contain Axe
  seed_draft.py --find axe,lion --from 900 --count 4
  seed_draft.py --rates --scan 2000    # per-hero appearance rate over N seeds
  seed_draft.py --selftest             # re-verify the port against known rosters
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POOL_TXT = os.path.join(HERE, "hero_pool.txt")

# Tie-broken output of `table.sort(tPosOrder, fewest-eligible-first)` in
# ApplySoakDraft for the current pool sizes {1:13, 2:12, 3:12, 4:15, 5:14}.
# Validated by --selftest; re-run it after editing hero_pool.txt.
POS_ORDER = (3, 2, 1, 5, 4)

# Real rosters read off `*.analysis.json` of wave spot_20260819_2211xx_1_829202ac.
KNOWN = {
    867: "crystal_maiden dragon_knight juggernaut lich lina medusa obsidian_destroyer queenofpain viper witch_doctor",
    868: "crystal_maiden drow_ranger jakiro lich necrolyte nevermore obsidian_destroyer ogre_magi sniper viper",
    869: "centaur chaos_knight dragon_knight shadow_shaman skeleton_king skywrath_mage slardar vengefulspirit viper zuus",
    870: "dragon_knight ember_spirit jakiro lina ogre_magi skeleton_king slardar sniper sven venomancer",
}


def load_pool(path=POOL_TXT):
    pool = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split(",")]
            name = parts[0]
            pos_field = parts[1] if len(parts) > 1 else ""
            pos = [int(p) for p in pos_field.split("/") if p.isdigit() and 1 <= int(p) <= 5]
            pool.append((name, pos or [1, 2, 3, 4, 5]))
    return pool


def draft(seed, pool, pos_order=POS_ORDER):
    """Return (radiant, dire) as {position: hero} for the given soak seed."""
    by_pos = {p: [n for n, ps in pool if p in ps] for p in range(1, 6)}
    s = (seed % 2147483646) + 1          # matches the Lua normalisation
    state = {"s": s}

    def next_rand(n):
        state["s"] = (state["s"] * 16807) % 2147483647
        return (state["s"] % n) + 1

    used = set()
    rad, dire = {}, {}

    def pick(p):
        cand = [n for n in by_pos[p] if n not in used]
        if not cand:                      # dead-end fallback: any unused hero
            cand = [n for n, _ in pool if n not in used]
        if not cand:
            return None
        c = cand[next_rand(len(cand)) - 1]
        used.add(c)
        return c

    for p in pos_order:
        rad[p] = pick(p)
        dire[p] = pick(p)
    return rad, dire


def heroes_of(seed, pool):
    r, d = draft(seed, pool)
    return set(list(r.values()) + list(d.values()))


def selftest(pool):
    ok = True
    for seed, roster in KNOWN.items():
        got = sorted(heroes_of(seed, pool))
        want = sorted(roster.split())
        if got != want:
            ok = False
            print(f"FAIL seed {seed}\n  got  {got}\n  want {want}")
    print("selftest: PASS (%d seeds, %d hero slots)" % (len(KNOWN), 10 * len(KNOWN)) if ok else "selftest: FAIL")
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("seeds", nargs="*", type=int, help="seeds to expand")
    ap.add_argument("--find", help="comma-separated heroes that must ALL appear")
    ap.add_argument("--from", dest="start", type=int, default=871, help="first seed to search")
    ap.add_argument("--count", type=int, default=4, help="how many matching seeds to return")
    ap.add_argument("--rates", action="store_true", help="print per-hero appearance rate")
    ap.add_argument("--scan", type=int, default=2000, help="seeds to scan for --rates/--find")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--pool", default=POOL_TXT)
    args = ap.parse_args()
    pool = load_pool(args.pool)

    if args.selftest:
        return selftest(pool)

    if args.find:
        want = {h.strip() for h in args.find.split(",") if h.strip()}
        unknown = want - {n for n, _ in pool}
        if unknown:
            print("not in pool: %s" % ", ".join(sorted(unknown)), file=sys.stderr)
            return 2
        hits = []
        seed = args.start
        limit = args.start + args.scan
        while seed < limit and len(hits) < args.count:
            if want <= heroes_of(seed, pool):
                hits.append(seed)
            seed += 1
        print("seeds containing %s: %s" % (",".join(sorted(want)),
                                           " ".join(str(s) for s in hits) or "(none in range)"))
        for s in hits:
            r, d = draft(s, pool)
            print("  %d radiant %s | dire %s" % (s, [r[p] for p in range(1, 6)], [d[p] for p in range(1, 6)]))
        return 0

    if args.rates:
        cnt = {}
        for seed in range(1, args.scan + 1):
            for h in heroes_of(seed, pool):
                cnt[h] = cnt.get(h, 0) + 1
        for h, c in sorted(cnt.items(), key=lambda x: x[1]):
            p = c / args.scan
            print("%6.1f%%  %-22s  P(absent from a 4-seed wave)=%.3f" % (100 * p, h, (1 - p) ** 4))
        return 0

    for seed in args.seeds or [867]:
        r, d = draft(seed, pool)
        print("seed %d" % seed)
        print("  radiant  " + ", ".join("pos%d=%s" % (p, r[p]) for p in range(1, 6)))
        print("  dire     " + ", ".join("pos%d=%s" % (p, d[p]) for p in range(1, 6)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

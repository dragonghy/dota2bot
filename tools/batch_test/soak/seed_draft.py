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

What a seed does and does NOT pin (GH #57, corrected 2026-08-20):
  * PINNED: which 10 heroes play, which team each is on, and **which position each
    plays** -- `ApplySoakDraft` drafts per position, and the (hero, role, lane)
    triple stays glued together downstream.  `--find` therefore guarantees the
    hero appears AND that it appears in the position printed below.
  * NOT PINNED: the hero's pick slot.  `X.ShufflePickOrder` permutes slots with
    the engine's unseeded RandomInt every game, so `analysis.json:team_slot`
    varies game to game for the same (seed, hero).  Deriving a position from it
    (`team_slot % 5 + 1`) is 47.3% accurate -- use `positions_for_game()` instead.

Usage:
  seed_draft.py 867 868 869 870        # what do these seeds draft?
  seed_draft.py --find axe --count 4   # give me 4 seeds that contain Axe
  seed_draft.py --find axe,lion --from 900 --count 4
  seed_draft.py --rates --scan 2000    # per-hero appearance rate over N seeds
  seed_draft.py --selftest             # re-verify the port against known rosters
  seed_draft.py 888 895 896 906 --assert-carrier crystal_maiden:5   # PRE-LAUNCH GATE

`--assert-carrier` is the launch gate, not a report (director ruling 2026-08-23
16:xxZ, test_set.md AV.3).  `check_armed_wiring.py` proves the id's call site
exists ON THE PINNED TREE; nothing proved the HERO exists in the wave's draft,
and a hero-specific id armed over a draft that never carries it is a byte-level
no-op that reads as "no effect" -- the same silent-failure shape, one axis over.
The incident in this file's own header (224 mirror games, zero Axe) is that
failure already paid for once.  So: exit 1 when a term is carried by NO seed,
exit 2 when nothing was checked (an unchecked gate is not a passed gate), and
print the satisfied/total fraction even when it passes, because PARTIAL coverage
is the number the pre-registered domain has to be written against.

A term is `hero` (drafted at all) or `hero:pos` (drafted INTO that position).
The position half is load-bearing for build-list ids: `cmboots` rewrites
`sRoleItemsBuyList['pos_5']` only, so a Crystal Maiden drafted pos 4 -- seed 888
does exactly that -- carries the hero and not the id.
"""
import argparse
import os
import re
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


# --- position attribution -----------------------------------------------------
# THE ROLE A HERO PLAYS IS A PROPERTY OF THE SEED; ITS PICK SLOT IS NOT.
# `ApplySoakDraft` drafts per position (tRad[p]/tDire[p]) and `hero_selection.lua`
# seeds slot i with the position-i hero -- but `X.ShufflePickOrder`
# (hero_selection.lua:312, fired once per all-bot team from AllPickHeros) then
# permutes the slots using the ENGINE's unseeded RandomInt, swapping
# sSelectList[i] together with Role.RoleAssignment[team][i] and tLaneAssignList[i].
# The (hero, role, lane) triple travels as a unit, so the hero keeps the role it
# was drafted for while its slot moves. `team_slot` therefore carries per-game
# engine entropy, not the role.
#
# Measured on wave spot_20260820_0411xx (291 mirror games, 2910 player rows):
# labelling by the drafted position explains eta^2 = 0.482 of last-hit variance,
# labelling by `team_slot % 5 + 1` only 0.174 (shuffled control 0.000); the two
# labels agree on just 47.3% of rows.  See GH #57 and the director report
# iterations/reports/director/20260820T050000Z.md.
def position_map(seed, pool):
    """{(team, hero): position} for one soak seed. team is 'radiant'/'dire'."""
    rad, dire = draft(seed, pool)
    out = {}
    for p, h in rad.items():
        out[("radiant", h)] = p
    for p, h in dire.items():
        out[("dire", h)] = p
    return out


def seed_from_stamp(script_version):
    """Soak seed out of an analysis.json `script_version` stamp, else None.

    Stamp shape: `mirror:<cand>:s<seed>:<side>`. Warm-up games carry a bare tree
    SHA and have no seed -- those return None, and callers must treat that as
    "position unknown" rather than falling back to a slot-derived guess.
    """
    if not isinstance(script_version, str):
        return None
    m = re.search(r":s(\d+):", script_version)
    return int(m.group(1)) if m else None


def positions_for_game(aj, pool=None):
    """{hero: position} for one parsed analysis.json, or None if unattributable.

    Keys come back exactly as analysis.json spells them (`npc_dota_hero_axe`), and
    every one of the 10 rows must resolve against the seed's draft -- a partial
    match means the game did not run this seed's roster and is not attributable.

    Returning None (not a guess) is deliberate: the slot-derived fallback this
    replaces was 47.3% accurate and silently mislabelled every consumer.
    """
    seed = seed_from_stamp((aj or {}).get("script_version"))
    if seed is None:
        return None
    pmap = position_map(seed, pool if pool is not None else load_pool())
    out = {}
    for p in aj.get("players") or []:
        short = p.get("hero", "").replace("npc_dota_hero_", "")
        pos = pmap.get((p.get("team"), short))
        if pos is None:
            return None
        out[p["hero"]] = pos
    return out if len(out) == 10 else None


def parse_carrier_terms(spec, pool):
    """`"crystal_maiden:5,axe"` -> [(hero, pos_or_None)], or raise ValueError.

    Refusing an unknown hero (rather than reporting it absent) is the whole
    point: a typo'd term would otherwise come back ABSENT and read as a real
    carrier collapse -- loud in the wrong direction, and the launch would be
    cancelled for nothing.
    """
    names = {n for n, _ in pool}
    terms = []
    for raw in (spec or "").split(","):
        raw = raw.strip()
        if not raw:
            continue
        hero, _, pos_s = raw.partition(":")
        hero = hero.strip()
        if hero not in names:
            raise ValueError("not in pool: %s" % hero)
        pos = None
        if pos_s.strip():
            if not pos_s.strip().isdigit() or not 1 <= int(pos_s) <= 5:
                raise ValueError("bad position in term %r (want 1-5)" % raw)
            pos = int(pos_s)
        terms.append((hero, pos))
    if not terms:
        raise ValueError("no carrier terms given")
    return terms


def assert_carrier(seeds, terms, pool, out=sys.stdout):
    """Pre-launch carrier gate.  Returns 0 (ok) / 1 (a term is carried by no
    seed) / 2 (nothing was checked).  Prints one CARRIER line per seed+term, a
    per-term summary, and one CARRIER_GATE line."""
    if not seeds:
        print("CARRIER_GATE terms=%d seeds=0 exit=2 (nothing checked)" % len(terms), file=out)
        return 2

    worst = 0
    for hero, pos in terms:
        label = hero if pos is None else "%s:%d" % (hero, pos)
        satisfied = []
        for seed in seeds:
            pmap = position_map(seed, pool)
            where = [(team, p) for (team, h), p in pmap.items() if h == hero]
            if not where:
                print("CARRIER seed=%d term=%s present=no satisfied=no" % (seed, label), file=out)
                continue
            team, drafted_pos = where[0]
            ok = pos is None or drafted_pos == pos
            if ok:
                satisfied.append(seed)
            print("CARRIER seed=%d term=%s present=yes side=%s pos=%d satisfied=%s"
                  % (seed, label, team, drafted_pos, "yes" if ok else "no"), file=out)
        if not satisfied:
            verdict = "ABSENT"
            worst = max(worst, 1)
        elif len(satisfied) == len(seeds):
            verdict = "FULL"
        else:
            verdict = "PARTIAL"
        print("CARRIER term=%s seeds=%d satisfied=%d verdict=%s carriers=%s"
              % (label, len(seeds), len(satisfied), verdict,
                 ",".join(str(s) for s in satisfied) or "none"), file=out)

    print("CARRIER_GATE terms=%d seeds=%d exit=%d" % (len(terms), len(seeds), worst), file=out)
    return worst


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
    ap.add_argument("--assert-carrier", dest="assert_carrier",
                    help="pre-launch gate: comma-separated `hero` / `hero:pos` terms that the "
                         "given seeds must carry (exit 1 = a term has no carrier, 2 = nothing checked)")
    ap.add_argument("--assert-carrier-from-arm", dest="arm",
                    help="pre-launch gate with the terms DERIVED from this wave's arm string "
                         "(comma-separated candidate ids) instead of hand-typed: see "
                         "carrier_terms.py and GH #276")
    ap.add_argument("--pool", default=POOL_TXT)
    args = ap.parse_args()
    pool = load_pool(args.pool)

    if args.selftest:
        return selftest(pool)

    if args.arm:
        # Hand-typed terms answered the wrong question twice in a row (W20/W21:
        # `aimguard` armed over 360 games with zero spirit_breaker, gate exit 0).
        sys.path.insert(0, HERE)
        import carrier_terms
        ids = carrier_terms.parse_arm(args.arm)
        if not ids:
            print("CARRIER_GATE exit=2 (empty arm string)", file=sys.stderr)
            return 2
        _terms, rows, summary = carrier_terms.derive_terms(ids)
        carrier_terms.print_derivation(rows, summary)
        if summary["unresolved"]:
            print("CARRIER_GATE exit=2 (%d unresolved id(s); an unchecked gate is not "
                  "a passed gate)" % summary["unresolved"], file=sys.stderr)
            return 2
        return carrier_terms.assert_carrier_ids(args.seeds, rows, pool)

    if args.assert_carrier:
        try:
            terms = parse_carrier_terms(args.assert_carrier, pool)
        except ValueError as exc:
            print("CARRIER_GATE exit=2 (%s)" % exc, file=sys.stderr)
            return 2
        return assert_carrier(args.seeds, terms, pool)

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

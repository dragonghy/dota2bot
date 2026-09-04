#!/usr/bin/env python3
"""Condition-(a) liveness reader for the `odaoe` soak candidate (read-only, no AWS spend).

`od_eclipse_aoe_domain.py` (2026-08-21) is a PRE-FLIGHT tool: it answers "is the
domain reachable" on a corpus where the id was NOT armed.  It has no notion of a
leg, so on an armed wave it pools the armed and the baseline Obsidian Destroyer
into one number and the answer it gives is not condition (a).

This script splits the same domain computation by LEG and adds the one
observable that turns a domain into an execution verdict:

    was an in-domain frame FOLLOWED by a real Sanity's Eclipse cast?

`odaoe` is purely ADDITIVE (hero_obsidian_destroyer.lua:657, the gated
`X.od_GetEclipseAoeLocation` sits BELOW the shipped single-target loop inside
`X.ConsiderSanitysEclipse`), so on an armed leg an in-domain frame is a frame on
which the bot SHOULD cast and the shipped code would not have.  That gives a
two-sided reading that neither leg alone can give:

    armed leg     in-domain frame -> cast within `--cast-window` s  => WORKING
    armed leg     in-domain frame -> no cast, ever                  => SILENT
    baseline leg  in-domain frame -> no cast                        => expected
                                                                       (this is
                                                                       what the
                                                                       gate is
                                                                       supposed
                                                                       to change)

LEG ASSIGNMENT.  The mirrored-draft harness stamps each game with the side that
carries the candidate arm string (`games_manifest.jsonl` field `side`).  W45's
lineups put OD on exactly ONE team per game (verified: one OD entity per game
after illusion filtering), so

    leg = armed   iff  OD's team == the armed side
    leg = baseline otherwise

and because a seed's lineup is fixed, OD's team is constant within a seed while
`side` alternates across the run -- i.e. both legs are bought from the SAME OD
in the SAME lineup, which is the paired reading iron rule 4(i) asks for.
Both strata (ab / ba) are printed separately and never pooled by game count.

HONEST BOUNDARIES (inherited from od_eclipse_aoe_domain.py, unchanged):
  * every domain count is an UPPER bound: `J.IsGoingOnSomeone` and fog are not
    in the .dem, and `IsFullyCastable` does not see silence/break;
  * the domain predicate is recomputed from that module, not reimplemented, so
    the two scripts cannot drift;
  * a cast is confirmed by the ABILITY event whose inflictor is the ult -- and,
    separately, by how many distinct enemy heroes took damage from that
    inflictor within `--hit-window` s of it, which is what says the cast was an
    AREA cast rather than the shipped single-target one.

`--selfcheck` runs the built-in cases and exits 0/1; it touches no corpus.
"""
import argparse
import collections
import json
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import od_eclipse_aoe_domain as M  # noqa: E402  (path shim must come first)

ULT = M.ULT
OD = M.OD
TEAM_OF_SIDE = {"radiant": 2, "dire": 3}

# How far a victim may have moved between the sampled frame and the cast.
# Kept deliberately small: it is additive slack on the radius, so a large value
# would quietly convert every "not hero-centred" cast into a hero-centred one.
MOVE_TOL = 60.0


def leg_of(od_team, side):
    """'armed' | 'baseline' | None -- None when the side stamp is unusable.

    Never guesses: an unknown stamp yields None and the caller drops the game
    rather than defaulting it into a leg (defaulting would land every unstamped
    game on one leg, and that bias has a sign)."""
    want = TEAM_OF_SIDE.get(str(side).strip().lower())
    if want is None or od_team not in (2, 3):
        return None
    return "armed" if od_team == want else "baseline"


def ult_casts(events):
    """[(t, n_hero_victims_placeholder)] -- ABILITY events for the ult only.

    An ABILITY event is the engine's own cast record; unlike the `zusult` family
    (GH #477) Sanity's Eclipse has no passive/aura source that forges one, but
    the caller still confirms area-ness from the damage side."""
    return sorted(e["t"] for e in events
                  if e.get("type") == "ABILITY"
                  and e.get("actor") == OD
                  and e.get("inflictor") == ULT)


def cast_victims(events, t_cast, window):
    """Distinct enemy HERO names damaged by the ult within `window` s of a cast."""
    out = set()
    for e in events:
        if e.get("inflictor") != ULT:
            continue
        if e.get("type") not in ("DAMAGE", "CRITICAL_DAMAGE"):
            continue
        if abs(e["t"] - t_cast) > window:
            continue
        if not e.get("target_hero"):
            continue
        out.add(e.get("target"))
    return out


def followed_by_cast(t_frame, casts, window):
    """The first ult cast in [t_frame, t_frame + window], or None."""
    for c in casts:
        if t_frame <= c <= t_frame + window:
            return c
    return None


def missing_ability_frames(path):
    """(n_missing, n_missing_alive) for the REAL OD entity in one timeline.

    `snapshots[].abilities` is `null` (not `[]`) on some frames -- GH #478.
    `od_eclipse_aoe_domain.py:321` and `:419` iterate it unprotected, so ONE
    such frame on a live OD raises TypeError and zeroes the whole corpus run.
    That file is not on #478's table (its census grepped the single-quoted
    direct-iteration shapes and this one is a double-quoted `next(<genexp>)`),
    so this function both measures the damage and is the reason the counts
    below can be reported at all.

    Frames are counted, never defaulted: a missing ability list is NOT read as
    "ult not ready". Defaulting it that way makes the frame a true negative,
    and that direction flatters the armed leg -- the exact error #478's fix
    note calls out."""
    with open(path) as fh:
        d = json.load(fh)
    if OD not in d["game"]["teams"]:
        return 0, 0
    raw, teams, events, by_ent, by_t = M.load_frames(path)
    real = M.real_entities(by_ent)
    if OD not in real:
        return 0, 0
    spans = M.death_spans(raw, real)
    frames = by_ent[(OD, real[OD])]
    miss = [s for s in frames if s.get("abilities") is None]
    alive = [s for s in miss if not M.is_dead(spans, s["hero"], s["t"])]
    return len(miss), len(alive)


def sanitized_copy(path, tmpdir):
    """Rewrite `path` with every `abilities: null` snapshot REMOVED, or None.

    Returns None when nothing had to be dropped, so an untouched game is read
    straight off the original file and the two paths cannot diverge."""
    with open(path) as fh:
        d = json.load(fh)
    keep = [s for s in d["snapshots"] if s.get("abilities") is not None]
    if len(keep) == len(d["snapshots"]):
        return None
    d["snapshots"] = keep
    out = os.path.join(tmpdir, os.path.basename(path))
    with open(out, "w") as fh:
        json.dump(d, fh)
    return out


def scan(paths, manifest, cast_window, hit_window, liveness, tmpdir=None):
    rows = []
    for p in paths:
        key = os.path.basename(p).replace(".timeline.json", "")
        n_miss, n_miss_alive = missing_ability_frames(p)
        src = p
        if n_miss and tmpdir:
            src = sanitized_copy(p, tmpdir) or p
        g = M.scan_game(src, liveness)
        if g is None:
            continue
        side = manifest.get(key, {}).get("side")
        seed = manifest.get(key, {}).get("seed")
        leg = leg_of(g["od_team"], side)
        raw, teams, events, by_ent, by_t = M.load_frames(p)
        casts = ult_casts(events)
        dom = g["domain_self"]
        runs = M.episode_runs([r["t"] for r in dom], 1.0)
        hits = []
        for c in casts:
            v = cast_victims(events, c, hit_window)
            hits.append({"t": round(c, 1), "victims": sorted(v), "n": len(v)})
        cast_class = classify_casts(src, liveness, hit_window)
        # An episode is CONSUMED when any of its frames is followed by a cast.
        consumed, orphan = [], []
        for run in runs:
            c = next((followed_by_cast(t, casts, cast_window) for t in run
                      if followed_by_cast(t, casts, cast_window)), None)
            (consumed if c is not None else orphan).append(
                {"t0": round(run[0], 1), "t1": round(run[-1], 1),
                 "frames": len(run), "cast_t": round(c, 1) if c else None})
        rows.append({"key": key, "seed": seed, "side": side, "leg": leg,
                     "od_team": g["od_team"], "ready": g["ready"],
                     "f_covered": g["f_covered"], "dom_frames": len(dom),
                     "episodes": len(runs), "consumed": consumed,
                     "orphan": orphan, "casts": hits,
                     "n_casts": len(casts),
                     "missing_ability_frames": n_miss,
                     "missing_ability_frames_alive": n_miss_alive,
                     "cast_class": cast_class,
                     "multi_hero_casts": sum(1 for h in hits if h["n"] >= 2)})
    return rows


def classify_casts(path, liveness, hit_window):
    """Per REAL ult cast: was the SHIPPED single-target loop true at that frame?

    This is the discriminator the episode table cannot give.  `odaoe` is
    additive, so a cast produced by the gated branch must satisfy, AT THE CAST
    FRAME itself:

        shipped single-target predicate FALSE  AND  the AoE predicate TRUE

    Any cast where the shipped predicate is TRUE is claimed by the shipped
    loop and proves nothing about the gate -- on either leg.  Reading the
    predicate at the frame that PRECEDES the in-domain window (which the
    episode table does) is not enough: the shipped loop can turn true inside
    the two seconds, and the baseline leg's own "consumed" episodes are the
    measured proof that it does.

    Returns one record per cast; `verdict` is one of
      gate_only   -- shipped FALSE, AoE TRUE          (armed leg: the gate fired)
      shipped     -- shipped TRUE                     (claimed by shipped code)
      neither     -- both FALSE (out of both domains; sampling lag, fog, or a
                     cast the replay cannot attribute)
    The snapshot nearest at-or-before the cast is used; the dumper samples at
    1.0s, so `dt` is reported and a record with a large `dt` is not evidence."""
    raw, teams, events, by_ent, by_t = M.load_frames(path)
    if OD not in teams:
        return []
    my, foe = teams[OD], (3 if teams[OD] == 2 else 2)
    real = M.real_entities(by_ent)
    real_idx = {(n, i) for n, i in real.items()}
    spans = M.death_spans(raw, real)

    def alive(s):
        if liveness == "hp":
            return s["hp"] > 0
        return not M.is_dead(spans, s["hero"], s["t"])

    out = []
    for t_cast in ult_casts(events):
        snaps = [s for s in by_ent[(OD, real[OD])]
                 if s["t"] <= t_cast and s.get("abilities") is not None]
        if not snaps:
            out.append({"t": round(t_cast, 1), "verdict": "no_snapshot"})
            continue
        s = snaps[-1]
        ult = next((a for a in s["abilities"] if a["name"] == ULT), None)
        lvl = min(ult["level"], 3) if ult and ult["level"] >= 1 else 1
        base, radius = M.BASE_DAMAGE[lvl], M.RADIUS[lvl]
        frame = by_t.get(round(s["t"], 1), [])
        enemies = [z for z in frame
                   if teams.get(z["hero"]) == foe and alive(z)
                   and (z["hero"], z["idx"]) in real_idx
                   and M.dist(s, z) <= M.CAST_RANGE]
        hittable = [z for z in enemies if M.worth_hitting(s, z, base)]
        aoe = (len(hittable) >= M.MIN_TARGETS
               and M.aoe_covers(s, hittable, radius) >= M.MIN_TARGETS)
        allies = [z for z in frame
                  if teams.get(z["hero"]) == my and alive(z)
                  and (z["hero"], z["idx"]) in real_idx
                  and M.dist(s, z) <= M.ALLY_RING]
        shipped = False
        for e in enemies:
            est = M.MAGIC_RESIST * (base + abs(s["mp"] - e["mp"]) * M.MULT)
            if est < e["hp"]:
                continue
            t_ally = sum(1 for z in frame
                         if teams.get(z["hero"]) == foe and alive(z)
                         and (z["hero"], z["idx"]) in real_idx
                         and M.dist(e, z) <= M.ALLY_RING)
            if len(allies) >= t_ally:
                shipped = True
        victims = sorted(cast_victims(events, t_cast, hit_window))
        # The model-free line. Only victims whose position this frame carries
        # can be judged; a victim we cannot place is reported, never assumed.
        epos = {z["hero"]: z for z in frame
                if teams.get(z["hero"]) == foe and (z["hero"], z["idx"]) in real_idx}
        placed = [epos[v] for v in victims if v in epos]
        if len(victims) >= 2 and len(placed) == len(victims):
            hero_centred = hero_centred_cover(placed, list(epos.values()),
                                              radius, MOVE_TOL)
        else:
            hero_centred = None
        verdict = "shipped" if shipped else ("gate_only" if aoe else "neither")
        out.append({"t": round(t_cast, 1), "dt": round(t_cast - s["t"], 1),
                    "hero_centred": hero_centred,
                    "victims_placed": len(placed),
                    "verdict": verdict, "lvl": lvl, "n_range": len(enemies),
                    "n_hit": len(hittable), "od_mp": round(s["mp"]),
                    "od_hp": round(s["hp_pct"], 2),
                    "victims": [v.replace("npc_dota_hero_", "") for v in victims],
                    "n_victims": len(victims)})
    return out


def hero_centred_cover(victim_pos, enemy_pos, radius, tol):
    """Could ONE circle centred on an enemy HERO cover every victim?

    The MODEL-FREE discriminator, and the only one here that survives every
    unknown the .dem carries (magic resistance, `GetSpecialValue*` returning
    something other than the datafeed, fog, illusions, mana sampled up to a
    second stale).  It rests on a pure fact of the source:

        the shipped branch returns `enemyHero:GetLocation()`
                                       (hero_obsidian_destroyer.lua:561)
        the gated branch may return a MIDPOINT of two enemies
                                       (`X.od_GetEclipseAoeLocation`, :687)

    so a cast whose victims no hero-centred circle can hold did not come from
    the shipped branch.  `tol` absorbs the sub-second the victims kept moving
    between the snapshot and the cast.

    RESULT ON W45 (2026-09-04): armed 5 casts, baseline 5 casts -- EQUAL.  On
    the baseline leg the gate is provably inert (single-arm `J.IsSoakCandidate`
    is side-gated, jmz_func.lua:5022-5025), so this is a falsification, not a
    reading: whatever produces those casts is not in the reconstruction, and
    until it is named no armed-leg cast can be booked to `odaoe`."""
    for c in enemy_pos:
        if all(M.dist(c, v) <= radius + tol for v in victim_pos):
            return True
    return False


def selfcheck():
    checks, fails = 0, 0

    def eq(got, want, label):
        nonlocal checks, fails
        checks += 1
        if got != want:
            fails += 1
            print(f"  FAIL {label}: got {got!r} want {want!r}")

    eq(leg_of(2, "radiant"), "armed", "od radiant + armed radiant")
    eq(leg_of(3, "radiant"), "baseline", "od dire + armed radiant")
    eq(leg_of(3, "dire"), "armed", "od dire + armed dire")
    eq(leg_of(2, "dire"), "baseline", "od radiant + armed dire")
    eq(leg_of(2, "DIRE"), "baseline", "side stamp is case-insensitive")
    eq(leg_of(2, None), None, "missing side stamp is not a leg")
    eq(leg_of(2, "left"), None, "unknown side stamp is not a leg")
    eq(leg_of(0, "radiant"), None, "unknown team is not a leg")

    ev = [{"type": "ABILITY", "actor": OD, "inflictor": ULT, "t": 10.0},
          {"type": "ABILITY", "actor": OD, "inflictor": "obsidian_destroyer_arcane_orb", "t": 11.0},
          {"type": "ABILITY", "actor": "npc_dota_hero_lion", "inflictor": ULT, "t": 12.0},
          {"type": "DAMAGE", "actor": OD, "inflictor": ULT, "t": 10.1,
           "target": "npc_dota_hero_pudge", "target_hero": True},
          {"type": "DAMAGE", "actor": OD, "inflictor": ULT, "t": 10.1,
           "target": "npc_dota_hero_zuus", "target_hero": True},
          {"type": "DAMAGE", "actor": OD, "inflictor": ULT, "t": 10.2,
           "target": "npc_dota_creep", "target_hero": False},
          {"type": "DAMAGE", "actor": OD, "inflictor": ULT, "t": 40.0,
           "target": "npc_dota_hero_lina", "target_hero": True}]
    eq(ult_casts(ev), [10.0], "only OD's own ult ABILITY events count")
    eq(sorted(cast_victims(ev, 10.0, 1.0)),
       ["npc_dota_hero_pudge", "npc_dota_hero_zuus"], "two hero victims in window")
    eq(cast_victims(ev, 10.0, 1.0) & {"npc_dota_creep"}, set(),
       "creep damage is not a hero victim")
    eq(len(cast_victims(ev, 10.0, 60.0)), 3, "a wide window pulls in a later cast's victim")

    eq(followed_by_cast(9.0, [10.0], 2.0), 10.0, "cast inside the window")
    eq(followed_by_cast(9.0, [10.0], 0.5), None, "cast outside the window")
    eq(followed_by_cast(11.0, [10.0], 2.0), None, "a cast BEFORE the frame does not count")
    eq(followed_by_cast(10.0, [10.0], 2.0), 10.0, "a cast on the frame counts")

    def pt(x, y):
        return {"x": float(x), "y": float(y)}

    a_, b_ = pt(0, 0), pt(400, 0)
    eq(hero_centred_cover([a_, b_], [a_, b_], 500.0, 0.0), True,
       "two enemies 400 apart fit in a 500 circle centred on either")
    eq(hero_centred_cover([a_, pt(600, 0)], [a_, pt(600, 0)], 500.0, 0.0), False,
       "600 apart does NOT fit a hero-centred 500 circle (the midpoint would)")
    eq(hero_centred_cover([a_, pt(600, 0)], [a_, pt(600, 0)], 500.0, 100.0), True,
       "tolerance can rescue a marginal spread -- so tol must stay small")
    eq(hero_centred_cover([a_, pt(600, 0)], [pt(300, 0)], 500.0, 0.0), True,
       "a third enemy standing at the midpoint makes it hero-centred after all")
    eq(hero_centred_cover([a_], [], 500.0, 0.0), False,
       "no enemy position means no hero-centred circle can be claimed")

    print(f"selfcheck: {checks} checks / {fails} failures")
    return 1 if fails else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*")
    ap.add_argument("--manifest", action="append", default=[],
                    help="games_manifest.jsonl (repeatable)")
    ap.add_argument("--cast-window", type=float, default=2.0,
                    help="seconds after an in-domain frame in which a cast counts as consuming it")
    ap.add_argument("--hit-window", type=float, default=1.0,
                    help="seconds around a cast in which ult damage counts as that cast's")
    ap.add_argument("--liveness", choices=("is_dead", "hp"), default="is_dead")
    ap.add_argument("--json", dest="json_out")
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(selfcheck())
    if not a.timelines:
        ap.error("no timelines given (and --selfcheck not requested)")

    manifest = {}
    for mp in a.manifest:
        with open(mp) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                d = json.loads(line)
                manifest[d["game"]] = d

    with tempfile.TemporaryDirectory() as tmpdir:
        rows = scan(a.timelines, manifest, a.cast_window, a.hit_window,
                    a.liveness, tmpdir)
    if not rows:
        print("no game in this corpus has Obsidian Destroyer -- nothing to measure")
        return

    unassigned = [r for r in rows if r["leg"] is None]
    print(f"=== CORPUS === {len(rows)} games with OD of {len(a.timelines)} scanned; "
          f"{len(unassigned)} without a usable side stamp (dropped from the leg tables)")

    hurt = [r for r in rows if r["missing_ability_frames_alive"]]
    print(f"=== GH #478 ACCOUNTING === games with `abilities: null` on the real "
          f"OD entity: {sum(1 for r in rows if r['missing_ability_frames'])}/{len(rows)}; "
          f"games where at least one such frame is on a LIVE OD (this is what "
          f"raises TypeError in od_eclipse_aoe_domain.py:321): {len(hurt)}")
    for r in hurt:
        print(f"    {r['key']:26s} leg={r['leg']} missing={r['missing_ability_frames']} "
              f"of which alive={r['missing_ability_frames_alive']}")
    print("  those frames are DROPPED from both numerator and denominator, "
          "never read as 'ult not ready'")

    for leg in ("armed", "baseline"):
        sub = [r for r in rows if r["leg"] == leg]
        if not sub:
            print(f"\n=== {leg.upper()} LEG === (no games)")
            continue
        dom = sum(r["dom_frames"] for r in sub)
        eps = sum(r["episodes"] for r in sub)
        cons = sum(len(r["consumed"]) for r in sub)
        orph = sum(len(r["orphan"]) for r in sub)
        casts = sum(r["n_casts"] for r in sub)
        multi = sum(r["multi_hero_casts"] for r in sub)
        rdy = sum(r["ready"] for r in sub)
        print(f"\n=== {leg.upper()} LEG === {len(sub)} games")
        print(f"  castable frames                 : {rdy}")
        print(f"  in-domain frames / episodes     : {dom} / {eps}")
        print(f"  episodes CONSUMED by a real cast: {cons}")
        print(f"  episodes with NO cast (orphan)  : {orph}")
        print(f"  real Sanity's Eclipse casts     : {casts} "
              f"(of which hit >= 2 enemy heroes: {multi})")
        by_seed = collections.Counter(r["seed"] for r in sub)
        print(f"  per seed: {dict(by_seed)}")
        for r in sub:
            if r["consumed"] or r["orphan"]:
                print(f"    {r['key']:26s} seed={r['seed']} side={r['side']} "
                      f"consumed={[c['t0'] for c in r['consumed']]} "
                      f"orphan={[o['t0'] for o in r['orphan']]}")

    print("\n=== CAST CLASSIFICATION (the discriminator; per REAL cast) ===")
    print("  gate_only = shipped single-target predicate FALSE at the cast "
          "frame AND the AoE predicate TRUE -- on the armed leg only the gated "
          "branch can produce this")
    for leg in ("armed", "baseline"):
        sub = [r for r in rows if r["leg"] == leg]
        cc = [c for r in sub for c in r["cast_class"]]
        cnt = collections.Counter(c["verdict"] for c in cc)
        print(f"  {leg:8s}: casts {len(cc):3d}  "
              f"gate_only {cnt['gate_only']:3d}  shipped {cnt['shipped']:3d}  "
              f"neither {cnt['neither']:3d}  no_snapshot {cnt['no_snapshot']:3d}")
        for r in sub:
            for c in r["cast_class"]:
                if c["verdict"] == "gate_only":
                    print(f"      {r['key']:26s} seed={r['seed']} t={c['t']:7.1f} "
                          f"dt={c['dt']:.1f} lvl={c['lvl']} inRange={c['n_range']} "
                          f"hit={c['n_hit']} mp={c['od_mp']:4d} hp={c['od_hp']:.2f} "
                          f"victims={c['n_victims']}:{','.join(v[:8] for v in c['victims'])}")

    print("\n=== MODEL-FREE GEOMETRY (the falsification) ===")
    print("  a cast whose >=2 hero victims NO enemy-hero-centred circle can hold "
          f"(tol {MOVE_TOL:.0f}u) cannot come from the shipped branch, which "
          "returns enemyHero:GetLocation()")
    for leg in ("armed", "baseline"):
        sub = [r for r in rows if r["leg"] == leg]
        cc = [c for r in sub for c in r["cast_class"]]
        judged = [c for c in cc if c.get("hero_centred") is not None]
        off = [c for c in judged if c["hero_centred"] is False]
        print(f"  {leg:8s}: multi-hero casts judged {len(judged):3d}  "
              f"NOT hero-centred {len(off):3d}  "
              f"(unplaceable victims: {sum(1 for c in cc if c.get('hero_centred') is None and c['n_victims'] >= 2)})")
        for r in sub:
            for c in r["cast_class"]:
                if c.get("hero_centred") is False:
                    print(f"      {r['key']:26s} seed={r['seed']} t={c['t']:7.1f} "
                          f"victims={c['n_victims']}:{','.join(v[:8] for v in c['victims'])}")

    print("\n=== STRATA (iron rule 4(i-a): both readings registered) ===")
    for seed in sorted({r["seed"] for r in rows if r["seed"]}):
        for leg in ("armed", "baseline"):
            sub = [r for r in rows if r["seed"] == seed and r["leg"] == leg]
            if not sub:
                continue
            print(f"  seed {seed} {leg:8s}: games {len(sub):2d}  "
                  f"episodes {sum(r['episodes'] for r in sub):3d}  "
                  f"consumed {sum(len(r['consumed']) for r in sub):3d}  "
                  f"casts {sum(r['n_casts'] for r in sub):3d}  "
                  f"multi-hero casts {sum(r['multi_hero_casts'] for r in sub):3d}")

    if a.json_out:
        with open(a.json_out, "w") as fh:
            json.dump(rows, fh, indent=1)
        print(f"\nwrote {a.json_out}")


if __name__ == "__main__":
    main()

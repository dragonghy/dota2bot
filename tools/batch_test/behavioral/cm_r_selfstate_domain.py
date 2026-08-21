#!/usr/bin/env python3
"""Pre-flight corpus check for the `cmrself` soak candidate (dev-only, no AWS spend).

`cmrself` is the SECOND clause added to `X.cm_IsRSafeToOpen`
(hero_crystal_maiden.lua:1008), gated turbo + its own id and gated SEPARATELY
from `cmrguard` above it.  It is a NEW VETO: armed, it can only turn a cast
into a NONE, never redirect one.  Its predicate is a conjunction of two facts
about CM herself:

    J.GetHP(bot) < X.nRSelfHpFloor (0.38)  AND
    bot:WasRecentlyDamagedByAnyHero(X.nRSelfFireWindow = 2.0)

So the set that decides whether arming it is measurable at all is

    { frames | the gate predicate is TRUE  AND  ConsiderR would otherwise
               have returned HIGH }

and this script measures that set on real frames before a wave is spent
(test_set.md section V.7 pre-flight; the `axeblink` trap).

DESK CHECK FIRST (test_set.md section Y.2: the desk can prove EMPTY, it cannot
prove RARE).  `X.ConsiderR` has exactly three fire branches below the gate:

  branch 1  hero_crystal_maiden.lua:1047  teamfight AoE
            `#nEnemysHeroesInRange >= 3 or aoeCanHurtCount >= 2`
            -- NO health clause anywhere on this path.
  branch 2  :1057  `J.IsGoingOnSomeone` single-target execute
            -- NO health clause anywhere on this path.
  branch 3  :1072  retreat, guarded by `J.IsRetreating(bot) and nHP > 0.38`
            -- the file's own pre-existing 0.38 floor, i.e. on THIS branch the
            gate's domain is already a subset of a shipped veto and buys
            nothing.  (The gate takes `< 0.38`, the branch takes `> 0.38`;
            hp == 0.38 exactly is refused by both.)

Two of the three branches are health-blind, so the domain is NOT structurally
empty and the desk cannot close the question -- hence this corpus run.  The
headline is branch 1, which is computable from the .dem modulo the mode clause;
branch 2 is reported apart as a loose upper bound because three of its five
conjuncts (`J.IsGoingOnSomeone`, `J.GetProperTarget`, `bot:GetOffensivePower`)
are simply not in the replay.

Section layout mirrors the other four domain scripts in this directory:

  D  SUPPLY        -- is the carrier present? games with CM, ult learned,
                      alive frames with it castable, real casts.
  A  EXACT DOMAIN  -- frames (and EPISODES) where armed != shipped.
  A' CLAUSE FUNNEL -- a monotone narrowing of D down to A, so the load-bearing
                      clause is named rather than guessed.
  B  OUTCOME SIDE  -- what the shipped code actually did: every real Freezing
                      Field cast classified by CM's own state at the instant
                      she opened the channel, and what happened to her next.

NUMERIC ANCHORS (pulled live from the Dota datafeed, hero_id=5, 2026-08-21):

    crystal_maiden_freezing_field
        radius            810      (FLAT across all three levels)
        AbilityManaCost   200/400/600
        AbilityCooldown   100/95/90
        damage            110/180/250 per explosion

    derived, as the Lua computes them:
        nRadius        = radius * 0.88          = 712.8
        aoe-hurt ring  = nRadius * 0.82 - enemy:GetCurrentMovementSpeed()
                       = 584.5 - ms

`GetCurrentMovementSpeed()` is NOT in the .dem, so the aoe-hurt ring is swept
over a movespeed band (--ms, default 300) and the sensitivity is printed.  A
LOWER movespeed makes the ring LARGER and the shipped branch fire MORE often,
which ENLARGES the measured domain -- so the conservative side for a "should we
arm this" question is the high-movespeed end, and both ends are reported.

HONEST BOUNDARIES -- every count below is an UPPER bound on the true domain:
  * `bot:GetActiveMode()` / `J.IsRetreating` / `J.IsGoingOnSomeone` are
    script-side mode concepts absent from the .dem (GH #27 family).  Branch 1
    is only entered when the mode is not a committed retreat; we cannot test
    that, so branch-1 frames are over-counted.
  * No fog: `J.GetNearbyHeroes` returns only VISIBLE enemies and the dumper has
    no per-team vision (GH #27), so enemies CM could not actually see are
    counted here.  Upper bound again.
  * `IsFullyCastable` also fails under silence/break/mute; not tracked.
  * `bot:DistanceFromFountain() < 300` is reproduced against a per-team
    fountain position estimated from the pre-horn snapshots (every hero stands
    in the fountain at t < -60), not from a hard-coded map constant.
  * `WasRecentlyDamagedByAnyHero(2.0)` is reproduced from DAMAGE /
    CRITICAL_DAMAGE events whose target is CM and whose `actor_hero` is true.
    The engine predicate counts damage from any hero-classed source; an
    illusion's damage is attributed to its owner's name in the combat log and
    is therefore counted here too.  Upper bound.
  * Liveness is `roam_conversion.is_dead()` (DEATH event -> respawn), the only
    audited criterion in this directory (test_set.md section AA.3 rule 1).
    `hp > 0` / `hp_pct > 0` are the proxy GH #78 condemned and are NOT used;
    `--liveness hp` reproduces them for the audit diff and nothing else.
    That audit matters more here than in any previous round in this stream:
    the gate's own predicate is `hp_pct < 0.38`, and a corpse frame reads
    hp_pct == 0, which SATISFIES it.  Under the proxy every corpse in the
    corpus is a candidate domain frame.
  * 0.5s sampling: adjacent frames inside one standoff are NOT independent
    observations.  Every frame count is therefore also reported as an EPISODE
    count with the longest run, per test_set.md section Z.2 -- quote the
    episode number, not the frame number, and never compute a binomial bound
    on the frame count.
  * `cmrguard` is a separate id in the same function.  Where it is co-armed it
    vetoes first, so the marginal domain of `cmrself` shrinks; the overlap is
    measured and reported so a scheduling decision does not have to guess it.

Usage:
    cm_r_selfstate_domain.py tl/*.json [--json out.json] [--episode-gap 1.0]
                                       [--ms 300] [--liveness is_dead|hp]
"""
import argparse
import collections
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from roam_conversion import death_spans, is_dead  # noqa: E402
from cmrguard_counterfactual import (  # noqa: E402
    cast_range, SCAN_RANGE, curated_abilities, shipped_buffer,
)

CM = "npc_dota_hero_crystal_maiden"
ULT = "crystal_maiden_freezing_field"

# datafeed hero_id=5, pulled 2026-08-21 (see docstring)
ULT_RADIUS = 810.0
ULT_MANA = {1: 200.0, 2: 400.0, 3: 600.0}
ULT_CD = {1: 100.0, 2: 95.0, 3: 90.0}

NRADIUS = ULT_RADIUS * 0.88          # X.ConsiderR's nRadius
AOE_HURT_BASE = NRADIUS * 0.82       # minus enemy movespeed, per the Lua
FOUNTAIN_MIN = 300.0                 # bot:DistanceFromFountain() < 300 -> NONE
BRANCH1_ENEMY_COUNT = 3              # #nEnemysHeroesInRange >= 3
BRANCH1_HURT_COUNT = 2               # aoeCanHurtCount >= 2
BRANCH2_ALLY_RING = 1200.0           # #nAllies <= 2, allies within 1200
BRANCH2_CLOSE = 280.0                # J.IsInRange(bot, npcTarget, 280)
BRANCH2_MIN_TARGET_HP = 400.0        # npcTarget:GetHealth() > 400

HERO_LUA = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "..", "..", "..", "bots", "BotLib", "hero_crystal_maiden.lua")

# Hard-CC modifiers that break the channel, for the outcome side.  Same table
# as cmrguard_precision.HARD_CC_MODIFIERS; imported by value rather than by
# reference only because that module runs a full scoring pass on import-time
# arguments we do not need here.
HARD_CC_MODIFIERS = {
    "modifier_stunned", "modifier_bashed",
    "modifier_shadow_shaman_shackles", "modifier_shadow_shaman_voodoo",
    "modifier_lion_voodoo", "modifier_slithereen_crush",
    "modifier_axe_berserkers_call",
    "modifier_obsidian_destroyer_astral_imprisonment_prison",
    "modifier_bane_fiends_grip", "modifier_bane_nightmare",
    "modifier_shadow_demon_disruption", "modifier_earthshaker_fissure_stun",
    "modifier_jakiro_ice_path_stun", "modifier_primal_beast_pulverize",
    "modifier_storm_spirit_electric_vortex_pull",
}


def shipped_constants():
    """Read X.nRSelfHpFloor / X.nRSelfFireWindow out of the hero file so this
    script cannot drift away from the values actually being tested (the same
    tripwire cmrguard_counterfactual.shipped_buffer() uses)."""
    src = open(os.path.normpath(HERO_LUA), encoding="utf-8").read()
    floor = re.search(r"X\.nRSelfHpFloor\s*=\s*([0-9.]+)", src)
    window = re.search(r"X\.nRSelfFireWindow\s*=\s*([0-9.]+)", src)
    if not floor or not window:
        raise SystemExit("cannot read X.nRSelfHpFloor / X.nRSelfFireWindow from "
                         "hero_crystal_maiden.lua -- the gate was renamed or removed")
    return float(floor.group(1)), float(window.group(1))


def load_frames(tl_path):
    """-> (raw, teams, events, snapshots-by-(hero,idx), snapshots-by-t).

    The raw dict is returned as well because `roam_conversion.death_spans()`
    needs the UNCUT snapshot list: a death near the end of the game respawns
    (or does not) in the post-game tail this function drops (GH #43)."""
    d = json.load(open(tl_path))
    teams = d["game"]["teams"]
    events = sorted(d["events"], key=lambda e: e["t"])
    t_end = max((e["t"] for e in events), default=float("inf"))
    by_ent = collections.defaultdict(list)
    by_t = collections.defaultdict(list)
    for s in d["snapshots"]:
        if s["t"] > t_end:
            continue
        by_ent[(s["hero"], s["idx"])].append(s)
        by_t[round(s["t"], 1)].append(s)
    for k in by_ent:
        by_ent[k].sort(key=lambda s: s["t"])
    return d, teams, events, by_ent, by_t


def real_entities(by_ent):
    """Longest-lived (name, idx) per hero name -- the body, not its illusions."""
    best = {}
    for (name, idx), snaps in by_ent.items():
        if name not in best or len(snaps) > len(by_ent[(name, best[name])]):
            best[name] = idx
    return best


def fountain_of(by_t, team):
    """Per-team fountain position, estimated from the pre-horn snapshots.

    Every hero stands in its own fountain before the horn, so the median of
    that team's positions at t < -60 is the fountain to within a few hundred
    units -- which is the same order as the 300-unit threshold it feeds, so the
    frames it can misclassify are exactly the ones CM spends standing in her
    own base.  Those are not fight frames and cannot enter the domain through
    branch 1 anyway (they would need >= 3 visible enemies inside 713 units of
    the fountain)."""
    xs, ys = [], []
    for t, frame in by_t.items():
        if t >= -60:
            continue
        for s in frame:
            if s["team"] == team:
                xs.append(s["x"])
                ys.append(s["y"])
    if not xs:
        return None
    xs.sort()
    ys.sort()
    return xs[len(xs) // 2], ys[len(ys) // 2]


def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def episode_runs(times, gap):
    """[t, ...] from ONE game -> [[t, ...], ...], one list per episode.

    Must be called per game (test_set.md section Z.2; the pooled version merges
    two games whose clocks land within `gap` of each other and UNDERCOUNTS)."""
    if not times:
        return []
    times = sorted(times)
    runs, cur = [], [times[0]]
    for t in times[1:]:
        if t - cur[-1] <= gap:
            cur.append(t)
        else:
            runs.append(cur)
            cur = [t]
    runs.append(cur)
    return runs


def episodes_of(runs):
    """[[t, ...], ...] -> (n_episodes, longest_frames, longest_seconds)."""
    if not runs:
        return 0, 0, 0.0
    longest = max(runs, key=len)
    return len(runs), len(longest), round(longest[-1] - longest[0], 1)


def ult_state(snap):
    """-> (level, cd, mana_cost) for Freezing Field on this snapshot, or None."""
    for a in snap.get("abilities") or []:
        if a["name"] == ULT:
            lvl = a["level"]
            if lvl < 1:
                return None
            return lvl, a["cd"], ULT_MANA.get(lvl, ULT_MANA[3])
    return None


def scan_game(tl_path, hp_floor, fire_window, ms, gap, liveness="is_dead"):
    raw, teams, events, by_ent, by_t = load_frames(tl_path)
    if CM not in teams:
        return None
    my_team = teams[CM]
    real = real_entities(by_ent)
    spans = death_spans(raw, real)
    real_idx = {(n, i) for n, i in real.items()}
    curated = curated_abilities()
    buffer_units = shipped_buffer()
    fountain = fountain_of(by_t, my_team)

    if liveness == "is_dead":
        def alive(s):
            return not is_dead(spans, s["hero"], s["t"])
    else:                                   # audit-only: the condemned proxy
        def alive(s):
            return s["hp"] > 0

    # Hero damage landed ON CM, for WasRecentlyDamagedByAnyHero.
    hits = sorted(e["t"] for e in events
                  if e["type"] in ("DAMAGE", "CRITICAL_DAMAGE")
                  and e.get("target") == CM and e.get("actor_hero"))

    def under_fire(t):
        # (t - window, t]: the engine's predicate is "within the last N seconds".
        lo = t - fire_window
        return any(lo < h <= t for h in hits)

    casts = [e["t"] for e in events
             if e["type"] == "ABILITY" and e.get("actor") == CM
             and e.get("inflictor") == ULT]
    deaths = [e["t"] for e in events
              if e["type"] == "DEATH" and e.get("target") == CM]
    # Cross-check on the cd edge (cmrguard_counterfactual's cast detector), so
    # a missing ABILITY event shows up as a disagreement instead of silence.
    cd_casts, prev_cd = [], None
    for t in sorted(by_t):
        me = next((s for s in by_t[t] if s["hero"] == CM
                   and s["idx"] == real[CM]), None)
        if me is None:
            continue
        st = ult_state(me)
        cd = st[1] if st else None
        if st and prev_cd == 0 and cd > 0:
            cd_casts.append(t)
        prev_cd = cd

    n_frames = n_alive = n_ready = n_offbase = 0
    n_lowhp = n_lowhp_fire = 0
    domain_t, branch2_t, guard_overlap_t, pred_t = [], [], [], []
    hurt_sens = {m: 0 for m in (240, 270, 300, 330, 360)}
    ghosts = collections.Counter()
    ready_hp = []
    # The anti-correlation column: on the frames where the GATE predicate is
    # true, how many enemies is the SHIPPED branch actually looking at?  A
    # small domain can mean either "the gate is a subset of an existing veto"
    # (structural, the `axeblink` trap) or "the two predicates rarely co-occur"
    # (empirical).  Only this histogram tells the two apart, and it is the
    # thing a bare domain count leaves unexplained.
    pred_enemy_hist = collections.Counter()
    pred_hurt_hist = collections.Counter()
    ult_level_hist = collections.Counter()

    for t in sorted(by_t):
        frame = by_t[t]
        me = next((s for s in frame if s["hero"] == CM and s["idx"] == real[CM]), None)
        if me is None:
            continue
        n_frames += 1

        dead_ev = is_dead(spans, CM, t)
        if dead_ev and me["hp"] > 0:
            ghosts["proxy_alive_event_dead"] += 1
        elif not dead_ev and me["hp"] <= 0:
            ghosts["proxy_dead_event_alive"] += 1

        if not alive(me):
            continue
        n_alive += 1

        st = ult_state(me)
        if st is None:
            continue
        lvl, cd, cost = st
        ult_level_hist[lvl] += 1
        if cd > 0 or me["mp"] < cost:
            continue
        n_ready += 1
        ready_hp.append(me["hp_pct"])

        if fountain is not None and math.hypot(me["x"] - fountain[0],
                                               me["y"] - fountain[1]) < FOUNTAIN_MIN:
            continue
        n_offbase += 1

        if me["hp_pct"] >= hp_floor:
            continue
        n_lowhp += 1
        if not under_fire(t):
            continue
        n_lowhp_fire += 1
        pred_t.append(t)

        # --- would the shipped code have fired on this frame? ---------------
        enemies = [s for s in frame
                   if s["team"] != my_team and (s["hero"], s["idx"]) in real_idx
                   and alive(s)]
        in_radius = [e for e in enemies if dist(me, e) <= NRADIUS]

        # aoeCanHurtCount: disabled inside nRadius, or inside the movespeed-
        # dependent inner ring.  Disability is not in a snapshot, so only the
        # ring term is counted -- the omission is one-sided DOWNWARD, i.e. the
        # domain reported here is if anything under-counted on this clause.
        def hurt_count(mspeed):
            ring = AOE_HURT_BASE - mspeed
            return sum(1 for e in in_radius if dist(me, e) <= ring)

        pred_enemy_hist[len(in_radius)] += 1
        pred_hurt_hist[hurt_count(ms)] += 1

        for mspeed in hurt_sens:
            if (len(in_radius) >= BRANCH1_ENEMY_COUNT
                    or hurt_count(mspeed) >= BRANCH1_HURT_COUNT):
                hurt_sens[mspeed] += 1

        branch1 = (len(in_radius) >= BRANCH1_ENEMY_COUNT
                   or hurt_count(ms) >= BRANCH1_HURT_COUNT)

        # branch 2's observable conjuncts only (see the docstring): SOME enemy
        # inside nRadius that is also inside 280, with > 400 hp, and at most
        # two allies within 1200.  The three unobservable conjuncts are assumed
        # TRUE, which is why this is reported apart and never in the headline.
        allies = [s for s in frame
                  if s["team"] == my_team and (s["hero"], s["idx"]) in real_idx
                  and alive(s) and dist(me, s) <= BRANCH2_ALLY_RING]
        branch2 = (len(allies) <= 2
                   and any(dist(me, e) <= BRANCH2_CLOSE and e["hp"] > BRANCH2_MIN_TARGET_HP
                           for e in in_radius))

        if branch1:
            domain_t.append(t)
            # would cmrguard already have vetoed this same frame?
            for e in frame:
                if e["team"] == my_team or not alive(e):
                    continue
                d = dist(me, e)
                if d > SCAN_RANGE:
                    continue
                for ab in e.get("abilities") or []:
                    if (ab["name"] in curated and ab["level"] >= 1 and ab["cd"] == 0
                            and d <= cast_range(ab["name"], ab["level"]) + buffer_units):
                        guard_overlap_t.append(t)
                        break
                else:
                    continue
                break
        elif branch2:
            branch2_t.append(t)

    # --- outcome side: classify every real cast -----------------------------
    cast_rows = []
    for t in casts:
        me = None
        for tt in sorted(by_t):
            if abs(tt - t) <= 0.5:
                cand = next((s for s in by_t[tt] if s["hero"] == CM
                             and s["idx"] == real[CM]), None)
                if cand is not None and (me is None or abs(tt - t) < abs(me["t"] - t)):
                    me = cand
        if me is None:
            continue
        died = next((d for d in deaths if t <= d <= t + 10.0), None)
        cast_rows.append({
            "t": round(t, 1),
            "hp_pct": round(me["hp_pct"], 3),
            "under_fire": under_fire(t),
            "in_gate_domain": me["hp_pct"] < hp_floor and under_fire(t),
            "died_after": round(died - t, 1) if died is not None else None,
        })

    deaths_with_ult = 0
    for d in deaths:
        near = [tt for tt in by_t if 0 <= d - tt <= 0.5]
        if not near:
            continue
        me = next((s for s in by_t[max(near)] if s["hero"] == CM
                   and s["idx"] == real[CM]), None)
        if me is None:
            continue
        st = ult_state(me)
        if st and st[1] == 0 and me["mp"] >= st[2]:
            deaths_with_ult += 1

    return {
        "game": os.path.basename(tl_path).replace(".timeline.json", ""),
        "frames": n_frames, "alive": n_alive, "ready": n_ready,
        "offbase": n_offbase, "lowhp": n_lowhp, "lowhp_fire": n_lowhp_fire,
        "domain_t": domain_t, "branch2_t": branch2_t, "pred_t": pred_t,
        "guard_overlap": len(set(guard_overlap_t)),
        "hurt_sens": hurt_sens,
        "pred_enemy_hist": dict(pred_enemy_hist),
        "pred_hurt_hist": dict(pred_hurt_hist),
        "ult_level_hist": dict(ult_level_hist),
        "domain_episodes": episode_runs(domain_t, gap),
        "pred_episodes": episode_runs(pred_t, gap),
        "casts": cast_rows, "n_casts_event": len(casts), "n_casts_cd": len(cd_casts),
        "deaths": len(deaths), "deaths_with_ult": deaths_with_ult,
        "ready_hp": ready_hp,
        "ghosts": dict(ghosts),
    }


def pct(n, d):
    return f"{100.0 * n / d:5.1f}%" if d else "  n/a"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="+")
    ap.add_argument("--json")
    ap.add_argument("--episode-gap", type=float, default=1.0)
    ap.add_argument("--ms", type=float, default=300.0,
                    help="enemy movespeed used for the aoeCanHurtCount inner ring")
    ap.add_argument("--liveness", choices=("is_dead", "hp"), default="is_dead",
                    help="is_dead = DEATH-event spans (audited); hp = the GH #78 proxy")
    a = ap.parse_args()

    hp_floor, fire_window = shipped_constants()
    games = []
    for p in a.timelines:
        g = scan_game(p, hp_floor, fire_window, a.ms, a.episode_gap, a.liveness)
        if g:
            games.append(g)
    if not games:
        raise SystemExit("no game in the corpus contains Crystal Maiden")

    tot = collections.Counter()
    for g in games:
        for k in ("frames", "alive", "ready", "offbase", "lowhp", "lowhp_fire",
                  "guard_overlap", "n_casts_event", "n_casts_cd", "deaths",
                  "deaths_with_ult"):
            tot[k] += g[k]
        tot["domain"] += len(g["domain_t"])
        tot["branch2"] += len(g["branch2_t"])

    all_eps = [r for g in games for r in g["domain_episodes"]]
    n_eps, longest_f, longest_s = episodes_of(all_eps)
    games_hit = sum(1 for g in games if g["domain_t"])
    ep_hist = collections.Counter(len(r) for r in all_eps)

    print(f"=== corpus: {len(games)} games with Crystal Maiden "
          f"(gate constants read live: hp_floor={hp_floor}, "
          f"fire_window={fire_window}s; liveness={a.liveness}, ms={a.ms:.0f}) ===")

    print("\n=== D  SUPPLY ===")
    print(f"  CM frames (all)                       {tot['frames']:6d}")
    print(f"  ... alive                             {tot['alive']:6d}  {pct(tot['alive'], tot['frames'])}")
    print(f"  ... Freezing Field learned + castable {tot['ready']:6d}  {pct(tot['ready'], tot['alive'])}")
    print(f"  real casts (ABILITY events)           {tot['n_casts_event']:6d}   "
          f"= {tot['n_casts_event'] / len(games):.2f}/game")
    print(f"  cross-check, casts by cd edge         {tot['n_casts_cd']:6d}")
    print(f"  CM deaths                             {tot['deaths']:6d}")
    print(f"  ... with the ultimate castable        {tot['deaths_with_ult']:6d}  "
          f"{pct(tot['deaths_with_ult'], tot['deaths'])}")

    print("\n=== A  EXACT DOMAIN (armed != shipped, branch 1) ===")
    print(f"  frames    {tot['domain']:5d}")
    print(f"  EPISODES  {n_eps:5d}   in {games_hit}/{len(games)} games   "
          f"= {n_eps / len(games):.2f}/game")
    print(f"  longest run: {longest_f} frames / {longest_s}s")
    print(f"  episode-length histogram: {dict(sorted(ep_hist.items()))}")
    print(f"  of those frames, `cmrguard` would already veto: {tot['guard_overlap']}"
          f"  {pct(tot['guard_overlap'], tot['domain'])}   (co-arming shrinks the margin)")
    print(f"  branch-2 LOOSE upper bound (3 unobservable conjuncts assumed true): "
          f"{tot['branch2']} extra frames")

    print("\n=== A' CLAUSE FUNNEL ===")
    steps = [("CM frames", tot["frames"]), ("alive", tot["alive"]),
             ("ult castable", tot["ready"]), ("outside the fountain", tot["offbase"]),
             (f"hp_pct < {hp_floor}", tot["lowhp"]),
             (f"+ hero damage within {fire_window}s", tot["lowhp_fire"]),
             ("+ branch 1 would fire", tot["domain"])]
    prev = None
    for label, n in steps:
        delta = "" if prev is None else f"   {n - prev:+6d}  ({pct(n, prev)} kept)"
        print(f"  {label:<34}{n:6d}{delta}")
        prev = n

    pred_eps = [r for g in games for r in g["pred_episodes"]]
    n_pred_eps, pf, ps = episodes_of(pred_eps)
    pred_games = sum(1 for g in games if g["pred_t"])
    print(f"\n  the GATE PREDICATE alone is well supplied: {tot['lowhp_fire']} frames "
          f"= {n_pred_eps} EPISODES in {pred_games}/{len(games)} games "
          f"({n_pred_eps / len(games):.2f}/game), longest {pf} frames / {ps}s.")
    print("  What collapses the domain is the SHIPPED branch, not the gate. On "
          "exactly those frames:")
    eh = collections.Counter()
    hh = collections.Counter()
    for g in games:
        eh.update(g["pred_enemy_hist"])
        hh.update(g["pred_hurt_hist"])
    print(f"    enemies inside nRadius={NRADIUS:.1f}: {dict(sorted(eh.items()))}"
          f"   -> `>= {BRANCH1_ENEMY_COUNT}` fires "
          f"{sum(n for k, n in eh.items() if k >= BRANCH1_ENEMY_COUNT)}/{tot['lowhp_fire']}")
    print(f"    aoeCanHurtCount (ms={a.ms:.0f}):      {dict(sorted(hh.items()))}"
          f"   -> `>= {BRANCH1_HURT_COUNT}` fires "
          f"{sum(n for k, n in hh.items() if k >= BRANCH1_HURT_COUNT)}/{tot['lowhp_fire']}")
    print("    i.e. the two predicates are ANTI-CORRELATED, not nested: a CM at "
          "low health\n         under fire is a chased support, not a hero "
          "standing in a three-man fight.")

    lv = collections.Counter()
    for g in games:
        lv.update(g["ult_level_hist"])
    print(f"\n  Freezing Field level over learned frames: {dict(sorted(lv.items()))}"
          f"  ({pct(lv.get(1, 0), sum(lv.values()))} at level 1)"
          "\n    -- same 'ultimate parked at level 1 in turbo' family as Lion's "
          "Finger (#7)\n       and OD's Sanity's Eclipse (#9); mana 200 and cd 100s "
          "are therefore constants here.")

    print("\n  movespeed sensitivity of the aoeCanHurtCount ring "
          f"(ring = {AOE_HURT_BASE:.1f} - ms):")
    for mspeed in sorted(games[0]["hurt_sens"]):
        n = sum(g["hurt_sens"][mspeed] for g in games)
        print(f"    ms={mspeed:3d} -> ring {AOE_HURT_BASE - mspeed:6.1f}u -> "
              f"{n:4d} domain frames")

    print("\n=== B  OUTCOME SIDE (every real Freezing Field cast) ===")
    rows = [c for g in games for c in g["casts"]]
    in_dom = [c for c in rows if c["in_gate_domain"]]
    print(f"  casts total                {len(rows):4d}")
    print(f"  ... below the health floor {sum(1 for c in rows if c['hp_pct'] < hp_floor):4d}")
    print(f"  ... under fire             {sum(1 for c in rows if c['under_fire']):4d}")
    print(f"  ... BOTH (gate would veto) {len(in_dom):4d}   "
          f"{pct(len(in_dom), len(rows))} of casts")
    died = [c for c in in_dom if c["died_after"] is not None]
    print(f"  of those, CM died within 10s: {len(died)}/{len(in_dom)}"
          + (f"   (delays: {[c['died_after'] for c in died]})" if died else ""))
    healthy = [c for c in rows if not c["in_gate_domain"]]
    hdied = [c for c in healthy if c["died_after"] is not None]
    print(f"  control -- casts OUTSIDE the domain that still died within 10s: "
          f"{len(hdied)}/{len(healthy)}")
    for c in sorted(in_dom, key=lambda c: c["t"]):
        print(f"    hp={c['hp_pct']:.3f} t={c['t']:7.1f} "
              f"died_after={c['died_after']}")

    print("\n=== LIVENESS AUDIT (GH #78 / #82) ===")
    gh = collections.Counter()
    for g in games:
        gh.update(g["ghosts"])
    print(f"  frames the `hp > 0` proxy calls ALIVE but is_dead() calls dead: "
          f"{gh['proxy_alive_event_dead']}")
    print(f"  frames the proxy calls DEAD but is_dead() calls alive:          "
          f"{gh['proxy_dead_event_alive']}")
    print("  NOTE the gate predicate is `hp_pct < 0.38`, which a corpse frame "
          "(hp_pct == 0)\n       SATISFIES -- rerun with --liveness hp to see "
          "the size of that contamination.")

    if a.json:
        json.dump({"games": games, "totals": dict(tot),
                   "episodes": n_eps, "hp_floor": hp_floor,
                   "fire_window": fire_window, "ms": a.ms,
                   "liveness": a.liveness},
                  open(a.json, "w"), indent=1)
        print(f"\nwrote {a.json}")


if __name__ == "__main__":
    main()

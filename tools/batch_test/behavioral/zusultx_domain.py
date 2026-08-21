#!/usr/bin/env python3
"""Pre-flight corpus check for the `zusultx` soak candidate (dev-only, no AWS spend).

`zusultx` (GH #59) is a ONE-SUBTRACTION WIDENING of an already-gated rule.
`X.zuus_ShouldSaveManaForUlt` (bots/BotLib/hero_zuus.lua) refuses a Q/W bid at a
healthy hero while Thundergod's Wrath is trained, off cooldown and unaffordable.
Its shipped clause reads the mana Zeus holds BEFORE the spend:

    if hBot:GetMana() - nSpend >= nCost then return false end   -- nSpend = 0 shipped

so with only `zusult` armed the gate's whole domain is "the reserve is ALREADY
gone".  With `zusultx` armed the bid's own handle rides along and nSpend becomes
that ability's mana cost, so the gate also covers the one frame that can still
change the outcome: mana sits at or above the ult's cost and this spend is about
to carry it below.

    increment domain = { frames | mana >= nCost  AND  mana - spend < nCost }
                     = { frames | mana in [nCost, nCost + spend) }

Everything else in the gate is byte-identical between the two ids, so this band
IS the difference.  Nothing here is "does the gate work" -- that is `zusult`'s
question and GH #59 section 0 already answered it on execution frames.  The
question here is the one the last four pre-flights were built to ask before an
id costs a wave: **is the band ever occupied, and by what**.

DESK CHECK FIRST (test_set.md section Y.2: the desk can prove EMPTY, it cannot
prove RARE).  Four desk facts, all read out of the source before this ran:

  1. NOT NESTED IN AN EXISTING VETO -- the `axeblink` trap does not apply.  The
     widened clause is strictly weaker than the shipped one (post-spend
     affordability implies pre-spend affordability, never the reverse), so armed
     != shipped is a fresh veto and not a subset of one the branch already
     performs.  Whether the band is occupied is exactly what the desk cannot say.
  2. THE BAND IS NARROW AND ITS WIDTH IS THE SPEND.  Arc Lightning 85..100,
     Lightning Bolt 120..135 (datafeed, below), against an ult cost of 250/375/500.
     So the band is ~1/3 of a Bolt-width of the ult's cost -- small, but it is
     the ONLY place the two ids can disagree, which makes it measurable exactly.
  3. THE CARRIER IS NOT THE PROBLEM HERE.  Zeus is in the focus five and, unlike
     Earthshaker (`esaftershock`, 5/17 games) or Tiny (`CARRIER-UNAVAILABLE`),
     he is in 17/17 games of this corpus and in 30+ banked seeds
     (`seed_roster_index.py --find zuus`).  GH #59's "Zeus only exists in seed
     872" was true of that one 4-seed wave, not of the archive.
  4. THE FIRE CLAUSES DOWNSTREAM ARE PARTLY MEASURABLE AND PARTLY NOT.  Of the
     branches that hand the gate a HERO target: ConsiderW2's two poke branches
     carry `nManaPercentage > 0.65 or GetMana() > nKeepMana*2 (=800)`, and
     `hp < 0.45 / < 0.40 or #nAllies >= 3`.  The health sub-clauses are ALREADY
     exempt inside the gate (it stands aside under 0.60), so on the W2 path the
     only live fire clause is `#nAllies >= 3` -- the same clause backlog #4
     measured -- plus the mana-fraction one.  Both are measurable here.
     ConsiderQ's and ConsiderW's hero branches ride `J.IsGoingOnSomeone` /
     `J.IsRetreating` / `bot:GetActiveMode()`, none of which exist in a .dem, so
     the state scan is an UPPER BOUND and the cast side is the honest number.

Sections mirror the other domain scripts in this directory:

  D  SUPPLY        -- Zeus alive, ult trained, off cooldown, and where his mana
                      sits relative to the ult's cost.
  A  EXACT DOMAIN  -- state-scan frames (and EPISODES) where armed != shipped
                      COULD differ: in-band, with a healthy living enemy hero
                      inside the spending ability's cast range.
  A' CLAUSE FUNNEL -- monotone narrowing of D to A plus the histogram of the
                      load-bearing clause, so "small" gets a named mechanism.
  B  CAST SIDE     -- THE NUMBER TO QUOTE.  Every real Arc Lightning / Lightning
                      Bolt cast that the gate's own arithmetic puts in the band,
                      classified into: refused by `zusultx` (healthy hero),
                      exempt by design (kill window), gate inert (no hero
                      target).  Episodes and games, per test_set.md section Z.2.
  C  COST SIDE     -- what refusing would have cost: in-band casts that KILLED
                      their healthy target (the gate reads hp_pct, not lethality,
                      so a lethal Bolt into a 65%-HP squishy is a false positive
                      by construction), and what Zeus did with the reserve
                      afterwards.

HONEST BOUNDARIES -- carry these into any readout:
  * NO VISION and NO MODE.  `J.IsGoingOnSomeone`, `J.IsRetreating`,
    `bot:GetActiveMode()`, `bot:FindAoELocation` and `J.GetProperTarget` are
    script-side and absent from the .dem.  Section A is therefore one-sided
    UPWARD: every branch is assumed reachable.  Section B does not need them --
    a cast that happened proves its own branch fired.
  * ILLUSIONS.  `J.GetNearbyHeroes` counts illusions as allies (GH #47), the
    dumper's longest-lived (name, idx) is the body.  The `#nAllies >= 3` column
    is therefore one-sided DOWNWARD against the script.
  * MANA ANCHOR.  `abilityR:GetManaCost()` is the live in-game number; this
    script uses the datafeed table and reports the whole readout under the
    legacy in-repo table too (`--rcost legacy`), because the two disagree --
    see NUMERIC ANCHORS.  Both are printed; neither is hidden.
  * 1 Hz SAMPLING.  Mana at the cast instant is not sampled; the frame at or
    before the cast is used and the gate's arithmetic is applied to THAT number
    rather than to the observed post-cast mana, so an arcane-boots refill or a
    second spend inside the same second cannot manufacture a crossing.  The
    observed-crossing count (GH #59's definition) is printed beside it.
  * Liveness is `roam_conversion.is_dead()` (DEATH event -> respawn), the only
    audited criterion in this directory (test_set.md section AA.3 rule 1).
    `--liveness hp` reproduces the GH #78 proxy for the audit diff and nothing
    else.
  * SAMPLING INTERVAL is a dumper FLAG (1.0s in `run_replay.sh`, the path every
    archived timeline came through).  Frame counts are not comparable across
    intervals; EPISODE counts are.  The header prints the detected interval.

NUMERIC ANCHORS (pulled live from the Dota datafeed, hero_id=22, 2026-08-21):

    zuus_arc_lightning        cast_ranges [800]              mana 85/90/95/100
    zuus_lightning_bolt       cast_ranges [700,750,800,850]  mana 120/125/130/135
    zuus_thundergods_wrath    cast_ranges [0] (global)       mana 250/375/500

  The in-repo `zusult_reserve_cross.py` carries RCOST = {1:225, 2:375, 3:525},
  measured off a 1 Hz cast pair in GH #59.  It disagrees with the datafeed at
  levels 1 and 3.  This corpus cannot settle it either -- an isolated ult cast's
  observed mana drop is `cost - 1s of regen`, and Zeus's regen here runs a
  median 5-9/s, which lands the estimate near 230 for a level-1 ult and between
  both anchors.  Hence `--rcost {datafeed,legacy}` and a printed sensitivity
  line rather than a chosen winner.

Usage:
    zusultx_domain.py tl/*.json [--json out.json] [--episode-gap 1.0]
                                [--rcost datafeed|legacy] [--liveness is_dead|hp]
    zusultx_domain.py --verify          # offline self-test, no corpus, no AWS

Dev-only tooling for tools/batch_test/; never shipped to the Workshop.
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
from cmrguard_counterfactual import sample_interval  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
HERO_LUA = os.path.join(REPO, "bots", "BotLib", "hero_zuus.lua")

Z = "npc_dota_hero_zuus"
ULT = "zuus_thundergods_wrath"
Q = "zuus_arc_lightning"
W = "zuus_lightning_bolt"

# datafeed hero_id=22, pulled 2026-08-21 (see docstring)
RCOST_DATAFEED = {1: 250.0, 2: 375.0, 3: 500.0}
RCOST_LEGACY = {1: 225.0, 2: 375.0, 3: 525.0}          # zusult_reserve_cross.py
SPELL_MANA = {
    Q: {1: 85.0, 2: 90.0, 3: 95.0, 4: 100.0},
    W: {1: 120.0, 2: 125.0, 3: 130.0, 4: 135.0},
}
SPELL_RANGE = {
    Q: {1: 800.0, 2: 800.0, 3: 800.0, 4: 800.0},
    W: {1: 700.0, 2: 750.0, 3: 800.0, 4: 850.0},
}
W2_SPLASH = 325.0          # X.ConsiderW2's nRadius -- the W2 path reaches further
ALLY_RING = 800.0          # J.GetNearbyHeroes(bot, 800, false, ...) in ConsiderW2
ALLY_FIRE = 3             # `#nAllies >= 3`
P1_MANA_FRACTION = 0.65   # `nManaPercentage > 0.65` in ConsiderW2's first poke branch
NKEEPMANA_X2 = 800.0      # `bot:GetMana() > nKeepMana * 2`
NKEEPMANA_X23 = 920.0     # `bot:GetMana() > nKeepMana * 2.3`

HEALTHY_DEFAULT = 0.6     # X.nUltSaveHealthFloor, re-read from source below


# --------------------------------------------------------------------------- #
# source anchors (tripwires: a retune of the Lua must not silently rot this)
# --------------------------------------------------------------------------- #
def lua_health_floor():
    """X.nUltSaveHealthFloor, read from hero_zuus.lua rather than duplicated."""
    try:
        src = open(HERO_LUA).read()
    except OSError:
        return HEALTHY_DEFAULT
    m = re.search(r"X\.nUltSaveHealthFloor\s*=\s*([0-9.]+)", src)
    return float(m.group(1)) if m else HEALTHY_DEFAULT


def lua_has_postspend_clause():
    """True while the widening is still a subtraction guarded by `zusultx`."""
    try:
        src = open(HERO_LUA).read()
    except OSError:
        return None
    return ("bPostSpend = J.IsSoakCandidate( 'zusultx' )" in src
            and "hBot:GetMana() - nSpend >= nCost" in src)


# --------------------------------------------------------------------------- #
# frame plumbing (same shape as es_aftershock_domain.py / cm_r_selfstate_domain.py)
# --------------------------------------------------------------------------- #
def load_frames(tl_path):
    """-> (raw, teams, events, by-(hero,idx), by-t).  Raw is returned because
    death_spans() needs the UNCUT snapshot list (GH #43 post-game tail)."""
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


def ability(snap, name):
    for a in snap.get("abilities") or []:
        if a["name"] == name:
            return a
    return None


def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def episode_runs(times, gap):
    """[t, ...] from ONE game -> one list per episode.  Must be called per game
    (test_set.md section Z.2: the pooled version merges two games whose clocks
    land within `gap` of each other and UNDERCOUNTS)."""
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
    if not runs:
        return 0, 0, 0.0
    longest = max(runs, key=len)
    return len(runs), len(longest), round(longest[-1] - longest[0], 1)


# --------------------------------------------------------------------------- #
# the gate, transcribed
# --------------------------------------------------------------------------- #
def band(mana, rcost, spend):
    """The one clause that separates `zusultx` from `zusult`.

    shipped: mana >= rcost            -> stand aside
    widened: mana - spend >= rcost    -> stand aside
    So they differ exactly on mana in [rcost, rcost + spend)."""
    return mana >= rcost and (mana - spend) < rcost


def w2_poke_branches(mana, max_mana, allies, weakest):
    """The three ConsiderW2 branches that REPORT a hero target, transcribed.

    Returns (p1, p2, p3) -- whether each COULD have fired on this frame.  Only
    the clauses a .dem can see are evaluated; each branch additionally needs its
    target inside `nRadius + nCastRange`, which the caller has already imposed
    by building `weakest` from the heroes in that reach.

    The health halves of P2/P3 (`hp < 0.45` / `hp < 0.40`) are below the gate's
    own kill-window floor, so a frame that reaches the gate through them is one
    the gate stands aside on anyway -- they are reported, not counted as reach.

    Note the two absolute-mana bypasses are STRUCTURALLY unreachable inside the
    band: the band's highest possible upper edge is the level-3 ult cost plus a
    level-4 Bolt = 500 + 135 = 635, below `nKeepMana * 2` = 800 and further below
    `nKeepMana * 2.3` = 920.  So inside the band P1 can only fire through the
    mana FRACTION, which needs max mana under (cost + spend) / 0.65."""
    frac = mana / max_mana if max_mana else 0.0
    p1 = frac > P1_MANA_FRACTION or mana > NKEEPMANA_X2
    p2 = allies >= ALLY_FIRE                 # its health half is gate-exempt
    p3 = ((weakest is not None and weakest < 0.40) or mana > NKEEPMANA_X23
          or allies >= ALLY_FIRE)
    return p1, p2, p3


def scan_game(tl_path, rcost_table, gap, hp_floor, liveness="is_dead"):
    raw, teams, events, by_ent, by_t = load_frames(tl_path)
    if Z not in teams:
        return None
    my_team = teams[Z]
    real = real_entities(by_ent)
    spans = death_spans(raw, real)

    if liveness == "is_dead":
        def alive(name, t):
            return not is_dead(spans, name, t)
    else:                                   # audit-only: the condemned proxy
        def alive(name, t):
            return True                     # replaced per-frame below

    zsnaps = by_ent.get((Z, real.get(Z)), [])
    times = sorted({round(s["t"], 1) for s in raw["snapshots"]})

    # per-time index of every real hero's snapshot
    frame_of = collections.defaultdict(dict)
    for name, idx in real.items():
        for s in by_ent[(name, idx)]:
            frame_of[round(s["t"], 1)][name] = s

    g = dict(
        game=os.path.basename(tl_path),
        interval=sample_interval(times),
        zeus_alive=0, r_trained=0, r_ready=0,
        r_ready_afford=0, r_ready_below=0,
        band_frames=[], band_detail=collections.Counter(),
        domain_times=[], domain_rows=[],
        allies_hist=collections.Counter(),
        manafrac_hist=collections.Counter(),
        casts=[], r_casts=[], max_level=0,
    )
    for s in raw["snapshots"]:
        if s["level"] > g["max_level"]:
            g["max_level"] = s["level"]

    for s in zsnaps:
        t = round(s["t"], 1)
        if liveness == "is_dead":
            if is_dead(spans, Z, t):
                continue
        elif s["hp"] <= 0:
            continue
        g["zeus_alive"] += 1
        r = ability(s, ULT)
        if r is None or r["level"] < 1:
            continue
        g["r_trained"] += 1
        if r["cd"] > 0:
            continue
        g["r_ready"] += 1
        rcost = rcost_table.get(r["level"], rcost_table[max(rcost_table)])
        if s["mp"] < rcost:
            g["r_ready_below"] += 1          # the SHIPPED domain (`zusult`)
            continue
        g["r_ready_afford"] += 1             # shipped stands aside here

        # --- the band: which spend, if any, would carry him under the cost ---
        in_band = []
        for spell in (Q, W):
            a = ability(s, spell)
            if a is None or a["level"] < 1:
                continue
            spend = SPELL_MANA[spell][min(a["level"], 4)]
            if band(s["mp"], rcost, spend):
                in_band.append((spell, spend, SPELL_RANGE[spell][min(a["level"], 4)],
                                a["cd"]))
        if not in_band:
            continue
        g["band_frames"].append(t)
        g["band_detail"][",".join(sorted(x[0] for x in in_band))] += 1

        # --- a target the gate could actually be asked about ---
        others = frame_of.get(t, {})
        allies = 0
        for name, o in others.items():
            if name == Z or teams.get(name) != my_team:
                continue
            if liveness == "is_dead" and is_dead(spans, name, t):
                continue
            if liveness == "hp" and o["hp"] <= 0:
                continue
            if dist(s, o) <= ALLY_RING:
                allies += 1
        g["allies_hist"][allies] += 1
        frac = s["mp"] / s["max_mp"] if s["max_mp"] else 0.0
        g["manafrac_hist"][round(frac, 1)] += 1

        hits = []
        for spell, spend, rng, cd in in_band:
            if cd > 0:
                continue                     # IsFullyCastable would have bailed
            reach = rng + (W2_SPLASH if spell == W else 0.0)
            for name, o in others.items():
                if teams.get(name) == my_team:
                    continue
                if liveness == "is_dead" and is_dead(spans, name, t):
                    continue
                if o["hp"] <= 0 or o["hp_pct"] < hp_floor:
                    continue                 # kill window: gate exempts it
                if dist(s, o) <= reach:
                    hits.append((spell, name, round(dist(s, o))))
        if not hits:
            continue
        g["domain_times"].append(t)
        g["domain_rows"].append(dict(t=t, mp=s["mp"], rcost=rcost, allies=allies,
                                     manafrac=round(frac, 3), hits=hits))

    # ------------------------------------------------------------------ #
    # B: the cast side.  A cast proves its own branch fired.
    # ------------------------------------------------------------------ #
    def snap_at(t):
        prev = [s for s in zsnaps if s["t"] <= t]
        return prev[-1] if prev else None

    for e in events:
        if e["type"] != "ABILITY" or e.get("actor") != Z:
            continue
        inf = e.get("inflictor")
        if inf == ULT:
            g["r_casts"].append(e["t"])
        if inf not in (Q, W):
            continue
        pre = snap_at(e["t"])
        if pre is None:
            continue
        r = ability(pre, ULT)
        if r is None or r["level"] < 1 or r["cd"] > 0:
            continue
        rcost = rcost_table.get(r["level"], rcost_table[max(rcost_table)])
        a = ability(pre, inf)
        lvl = min(a["level"], 4) if a else 1
        spend = SPELL_MANA[inf][max(lvl, 1)]
        crossed_gate = band(pre["mp"], rcost, spend)
        post = next((s for s in zsnaps if s["t"] > e["t"]), None)
        crossed_obs = bool(post and pre["mp"] >= rcost and post["mp"] < rcost)

        # target: a hero name on the event, else the hero this spell damaged.
        #
        # The distinction is load-bearing and not cosmetic (this is the same
        # shape as GH #47's W2 leak, seen from the gate's side).  The gate is
        # only ever asked about the target its Consider function REPORTS:
        #   * a unit-targeted event carries a hero handle, so ConsiderQ /
        #     ConsiderW handed the gate a hero and the gate was consulted;
        #   * a ground event is either ConsiderW2 (which reports a hero ONLY
        #     from its two poke branches -- kill-AoE, channel-interrupt and
        #     retreat deliberately report nil, leaving the gate INERT) or
        #     ConsiderW under talent7.  Which one cannot be read off a .dem.
        # So `unit_target` casts are the gate-consulted domain and ground casts
        # are an upper bound on top of it.
        raw_t = str(e.get("target", ""))
        unit_target = raw_t.startswith("npc_dota_hero_")
        tgt = raw_t if unit_target else None
        if tgt is None:
            hit = [x for x in events
                   if abs(x["t"] - e["t"]) <= 0.35 and x["type"] == "DAMAGE"
                   and x.get("inflictor") == inf and x.get("target_hero")]
            tgt = hit[0]["target"] if hit else None
        hp = None
        killed = False
        if tgt:
            near = [s for s in by_ent.get((tgt, real.get(tgt)), [])
                    if abs(s["t"] - e["t"]) <= 1.5 and s["hp"] > 0]
            if near:
                hp = min(s["hp_pct"] for s in near)
            killed = any(x["type"] == "DEATH" and x.get("target") == tgt
                         and 0 <= x["t"] - e["t"] <= 1.5
                         and x.get("inflictor") == inf for x in events)
        # --- B': what ConsiderW2's poke branches could have done on this frame ---
        # (only these three report a hero target; the other three report nil and
        # leave the gate inert.  Transcribed from hero_zuus.lua X.ConsiderW2.)
        others = frame_of.get(round(pre["t"], 1), {})
        allies = sum(1 for name, o in others.items()
                     if name != Z and teams.get(name) == my_team
                     and not is_dead(spans, name, round(pre["t"], 1))
                     and dist(pre, o) <= ALLY_RING)
        wa = ability(pre, W)
        wl = min(wa["level"], 4) if wa and wa["level"] >= 1 else 1
        reach = SPELL_RANGE[W][max(wl, 1)] + W2_SPLASH
        in_reach = [(name, o["hp_pct"]) for name, o in others.items()
                    if teams.get(name) != my_team
                    and not is_dead(spans, name, round(pre["t"], 1))
                    and o["hp"] > 0 and dist(pre, o) <= reach]
        weakest = min((h for _, h in in_reach), default=None)
        frac = pre["mp"] / pre["max_mp"] if pre["max_mp"] else 0.0
        p1, p2, p3 = w2_poke_branches(pre["mp"], pre["max_mp"], allies, weakest)

        g["casts"].append(dict(t=e["t"], spell=inf, mp_pre=pre["mp"], rcost=rcost,
                               spend=spend, gate_band=crossed_gate,
                               obs_cross=crossed_obs, tgt=tgt, hp=hp,
                               killed=killed, unit_target=unit_target,
                               game=os.path.basename(tl_path),
                               manafrac=round(frac, 3), allies=allies,
                               weakest=weakest, w2_p1=p1, w2_p2=p2, w2_p3=p3))
    return g


# --------------------------------------------------------------------------- #
# report
# --------------------------------------------------------------------------- #
def report(games, gap, hp_floor, rcost_name, out_json=None):
    n = len(games)
    zeus_games = [g for g in games if g]
    intervals = collections.Counter(g["interval"] for g in zeus_games)
    tot = lambda k: sum(g[k] for g in zeus_games)  # noqa: E731

    print("=" * 78)
    print("zusultx pre-flight -- corpus domain census")
    print("=" * 78)
    print("  games                     %5d   (with Zeus: %d)" % (n, len(zeus_games)))
    print("  snapshot interval         %s" % dict(intervals))
    print("  ult mana anchor           %s  (%s)" % (
        rcost_name, RCOST_DATAFEED if rcost_name == "datafeed" else RCOST_LEGACY))
    print("  health floor (from Lua)   %.2f" % hp_floor)
    print("  post-spend clause present %s" % lua_has_postspend_clause())
    print()

    print("D SUPPLY (Zeus's own state -- nothing about targets yet)")
    print("  Zeus alive frames                      %6d" % tot("zeus_alive"))
    print("  ... ult trained                        %6d  %5.1f%%"
          % (tot("r_trained"), 100.0 * tot("r_trained") / max(1, tot("zeus_alive"))))
    print("  ... and off cooldown                   %6d  %5.1f%%"
          % (tot("r_ready"), 100.0 * tot("r_ready") / max(1, tot("r_trained"))))
    print("      of those, mana < cost  (`zusult`'s own shipped domain)  %6d"
          % tot("r_ready_below"))
    print("      of those, mana >= cost (shipped stands aside)           %6d"
          % tot("r_ready_afford"))
    band_frames = sum(len(g["band_frames"]) for g in zeus_games)
    print("  ... and IN BAND [cost, cost+spend)     %6d  %5.1f%% of afford"
          % (band_frames, 100.0 * band_frames / max(1, tot("r_ready_afford"))))
    detail = collections.Counter()
    for g in zeus_games:
        detail.update(g["band_detail"])
    print("      which spend puts him in band:      %s" % dict(detail))
    band_eps = [episode_runs(g["band_frames"], gap) for g in zeus_games]
    print("      = %d EPISODES in %d games"
          % (sum(len(r) for r in band_eps),
             sum(1 for r in band_eps if r)))
    print()

    print("A EXACT DOMAIN (in band AND a healthy living enemy hero in reach)")
    dom_frames = sum(len(g["domain_times"]) for g in zeus_games)
    dom_eps = [episode_runs(g["domain_times"], gap) for g in zeus_games]
    n_eps = sum(len(r) for r in dom_eps)
    n_games = sum(1 for r in dom_eps if r)
    longest = max((len(x) for r in dom_eps for x in r), default=0)
    print("  frames        %5d" % dom_frames)
    print("  EPISODES      %5d   in %d/%d games = %.2f episodes/game"
          % (n_eps, n_games, n, n_eps / max(1, n)))
    print("  longest run   %5d frames" % longest)
    print("  NOTE: upward bound -- IsGoingOnSomeone / IsRetreating / GetActiveMode")
    print("        are absent from a .dem, so every branch is assumed reachable.")
    print()

    print("A' CLAUSE FUNNEL (what the downstream fire clauses do to that bound)")
    allies = collections.Counter()
    mfrac = collections.Counter()
    for g in zeus_games:
        allies.update(g["allies_hist"])
        mfrac.update(g["manafrac_hist"])
    tot_band = sum(allies.values())
    fire_ally = sum(v for k, v in allies.items() if k >= ALLY_FIRE)
    print("  allies within %d of Zeus on in-band frames: %s"
          % (int(ALLY_RING), dict(sorted(allies.items()))))
    print("  ... >= %d (the only live W2 poke fire clause): %d / %d = %.1f%%"
          % (ALLY_FIRE, fire_ally, tot_band, 100.0 * fire_ally / max(1, tot_band)))
    hi = sum(v for k, v in mfrac.items() if k > P1_MANA_FRACTION)
    print("  mana fraction on in-band frames: %s" % dict(sorted(mfrac.items())))
    print("  ... > %.2f (ConsiderW2 poke branch 1): %d / %d = %.1f%%"
          % (P1_MANA_FRACTION, hi, tot_band, 100.0 * hi / max(1, tot_band)))
    print()

    print("B CAST SIDE -- THE NUMBER TO QUOTE (a cast proves its own branch fired)")
    rows = [c for g in zeus_games for c in g["casts"]]
    inband = [c for c in rows if c["gate_band"]]
    healthy = [c for c in inband if c["tgt"] and c["hp"] is not None and c["hp"] >= hp_floor]
    killwin = [c for c in inband if c["tgt"] and c["hp"] is not None and c["hp"] < hp_floor]
    inert = [c for c in inband if not c["tgt"] or c["hp"] is None]
    obs = [c for c in rows if c["obs_cross"]]
    print("  Q/W casts with the ult trained and ready          %5d" % len(rows))
    print("  ... in band by the gate's own arithmetic          %5d" % len(inband))
    print("      -> REFUSED by `zusultx` (healthy hero target) %5d   <-- the domain"
          % len(healthy))
    print("      -> exempt by design (kill window, hp < %.2f)  %5d" % (hp_floor, len(killwin)))
    print("      -> gate inert (no hero target resolved)       %5d" % len(inert))
    print("  ... observed crossing (GH #59's 1 Hz definition)  %5d" % len(obs))
    per_game = collections.Counter()
    for g in zeus_games:
        k = g["game"]
        per_game[k] = sum(1 for c in g["casts"] if c["gate_band"] and c["tgt"]
                          and c["hp"] is not None and c["hp"] >= hp_floor)
    hit_games = sum(1 for v in per_game.values() if v)
    print("  domain casts land in %d/%d games = %.2f casts/game"
          % (hit_games, n, len(healthy) / max(1, n)))
    consulted = [c for c in healthy if c["unit_target"]]
    print("  ... of which UNIT-TARGETED (the gate provably held a hero handle)"
          " %5d" % len(consulted))
    print("  ... of which GROUND (ConsiderW2 or talent7 ConsiderW -- the gate is")
    print("      INERT on W2's kill-AoE / interrupt / retreat branches, so these")
    print("      are an upper bound on top of the line above)          %5d"
          % (len(healthy) - len(consulted)))
    cg = len({c["game"] for c in consulted})
    print("  gate-consulted domain: %d cast(s) in %d/%d games = %.2f/game"
          % (len(consulted), cg, n, len(consulted) / max(1, n)))
    for c in sorted(healthy, key=lambda c: -(c["hp"] or 0))[:12]:
        print("      t=%7.1f %-22s mp %4.0f (cost %3.0f + spend %3.0f) -> %-24s hp %.2f  %s%s"
              % (c["t"], c["spell"], c["mp_pre"], c["rcost"], c["spend"],
                 (c["tgt"] or "")[14:], c["hp"],
                 "unit" if c["unit_target"] else "ground",
                 "  KILLED IT" if c["killed"] else ""))
    print()

    print("B' BRANCH ATTRIBUTION of those domain casts (which Consider could have run)")
    maxlvl = max((g["max_level"] for g in zeus_games), default=0)
    print("  highest hero level anywhere in corpus: %d" % maxlvl)
    print("  => talent7 is the LAST talent pair (aba_skill.GetTalentList walks ability")
    print("     slots in order, so index 7/8 = the level-25 tier).  It is therefore")
    print("     NEVER trained here, ConsiderW always uses UseAbilityOnEntity, and every")
    print("     GROUND Lightning Bolt in this corpus came from ConsiderW2.  %s"
          % ("HOLDS" if maxlvl < 25 else "DOES NOT HOLD -- re-derive"))
    print("  per cast, could any of ConsiderW2's three target-REPORTING poke branches")
    print("  have fired?  (the other three report nil and leave the gate inert)")
    consulted_rows = []
    for c in sorted(healthy, key=lambda c: c["t"]):
        print("      t=%7.1f %-20s %-6s mana %.2f of max, allies<=%d: %d, weakest %s"
              % (c["t"], c["spell"][5:], "unit" if c["unit_target"] else "ground",
                 c["manafrac"], int(ALLY_RING), c["allies"],
                 "%.2f" % c["weakest"] if c["weakest"] is not None else "none"))
        if c["spell"] == Q or c["unit_target"]:
            # ConsiderQ (always unit-targeted) and ConsiderW's entity path both
            # hand the gate the hero they picked, so the gate IS consulted --
            # unless the branch that picked it was the retreat one, which the
            # gate exempts on its own.  A .dem cannot separate those two.
            verdict = ("gate CONSULTED (%s hands over its hero) -- unless the "
                       "branch was the retreat one, which the gate exempts"
                       % ("ConsiderQ" if c["spell"] == Q else "ConsiderW"))
            consulted_rows.append(c)
        else:
            reasons = []
            if c["w2_p1"]:
                reasons.append("P1(mana)")
            if c["w2_p2"]:
                reasons.append("P2(allies>=3)")
            if c["w2_p3"]:
                reasons.append("P3(weakest<0.40 or allies>=3)")
            if not reasons:
                verdict = ("NO ConsiderW2 poke branch can fire -> the cast came "
                           "from a nil-target branch -> gate INERT")
            elif reasons == ["P3(weakest<0.40 or allies>=3)"] and \
                    c["weakest"] is not None and c["weakest"] < hp_floor:
                verdict = ("only %s, and it reports that weakest hero (%.2f HP) "
                           "-> the gate's own kill-window exemption stands aside"
                           % (reasons[0], c["weakest"]))
            else:
                verdict = "could fire: " + " + ".join(reasons)
                consulted_rows.append(c)
        print("                    -> %s" % verdict)
    print("  ==> casts where the gate is provably NOT inert and NOT self-exempt: %d"
          % len(consulted_rows))
    print("  NOTE: a firing P3 reports the WEAKEST enemy, so when P3 is the only")
    print("        candidate the gate is handed that hero -- and under the health")
    print("        floor the gate's own kill-window exemption stands it aside.")
    print()

    print("C COST SIDE (what a refusal would have cost on those same casts)")
    lethal = [c for c in healthy if c["killed"]]
    print("  domain casts that KILLED their healthy target      %5d" % len(lethal))
    print("      (the gate reads hp_pct, not lethality: a lethal Bolt into a")
    print("       %.0f%%-HP squishy is a false positive by construction)" % (hp_floor * 100))
    r_casts = sum(len(g["r_casts"]) for g in zeus_games)
    print("  real Thundergod's Wrath casts in corpus           %5d  (%.1f/game)"
          % (r_casts, r_casts / max(1, n)))
    print()

    verdict = len(healthy)
    print("=" * 78)
    print("HEADLINE: cast-side domain = %d cast(s) / %d game(s) of %d"
          % (verdict, hit_games, n))
    print("          of which NOT provably inert / self-exempt = %d cast(s) in %d game(s)"
          % (len(consulted_rows), len({c["game"] for c in consulted_rows})))
    print("          state-scan upper bound = %d frames / %d EPISODES / %d games"
          % (dom_frames, n_eps, n_games))
    print("=" * 78)

    if out_json:
        json.dump(dict(games=n, zeus_games=len(zeus_games), rcost=rcost_name,
                       hp_floor=hp_floor, band_frames=band_frames,
                       domain_frames=dom_frames, domain_episodes=n_eps,
                       domain_games=n_games, casts=len(rows),
                       casts_in_band=len(inband), casts_domain=len(healthy),
                       casts_killwindow=len(killwin), casts_inert=len(inert),
                       casts_observed_cross=len(obs), domain_cast_games=hit_games,
                       casts_domain_unit_targeted=len(consulted),
                       casts_domain_gate_reachable=len(consulted_rows),
                       max_level=max((g["max_level"] for g in zeus_games), default=0),
                       domain_casts_lethal=len(lethal), r_casts=r_casts,
                       allies_hist=dict(allies), manafrac_hist=dict(mfrac),
                       rows=[c for c in healthy]),
                  open(out_json, "w"), indent=1)
        print("wrote %s" % out_json)
    return verdict


# --------------------------------------------------------------------------- #
# offline self-test
# --------------------------------------------------------------------------- #
def verify():
    ok = fail = 0

    def check(name, got, want):
        nonlocal ok, fail
        if got == want:
            ok += 1
        else:
            fail += 1
            print("  FAIL %s: got %r want %r" % (name, got, want))

    # the band is exactly where the two ids disagree
    check("shipped stands aside above cost", band(300, 250, 120), True)
    check("both stand aside well above cost", band(500, 250, 120), False)
    check("both hold below cost", band(200, 250, 120), False)
    check("lower edge is inclusive", band(250, 250, 120), True)
    check("upper edge is exclusive", band(370, 250, 120), False)
    check("width is the spend", band(369.9, 250, 120), True)
    # widening is monotone in the spend: a bigger spend can only widen
    check("bolt band contains arc band",
          all((not band(m, 250, 85)) or band(m, 250, 120) for m in range(240, 400)),
          True)
    # episodes
    check("episode split at the gap",
          [len(r) for r in episode_runs([1.0, 2.0, 3.0, 9.0], 1.0)], [3, 1])
    check("one sample is one episode", len(episode_runs([4.4], 1.0)), 1)
    check("empty is no episode", episode_runs([], 1.0), [])
    # source tripwires
    check("health floor read from Lua", lua_health_floor(), 0.6)
    check("post-spend clause still gated on zusultx", lua_has_postspend_clause(), True)
    # anchors disagree -- the sensitivity knob must not be silently equal
    check("anchors differ at ult level 1", RCOST_DATAFEED[1] == RCOST_LEGACY[1], False)
    check("anchors agree at ult level 2", RCOST_DATAFEED[2] == RCOST_LEGACY[2], True)
    # the W2 poke branches, on the shape GH #59's own frame has
    check("GH #59's frame reaches no poke branch",
          w2_poke_branches(256, 856, 1, 1.00), (False, False, False))
    check("a grouped frame reaches P2 and P3",
          w2_poke_branches(256, 856, 3, 1.00), (False, True, True))
    check("a small mana pool lets the band reach P1",
          w2_poke_branches(300, 400, 0, 1.00), (True, False, False))
    check("the absolute-mana bypasses cannot be reached inside the band",
          any(w2_poke_branches(m, 10 ** 9, 0, 1.00)[0]
              for m in range(0, int(max(RCOST_DATAFEED.values())) + 136)),
          False)
    check("a dying weakest enemy reaches P3 (and the gate then exempts it)",
          w2_poke_branches(256, 856, 0, 0.30), (False, False, True))
    print("verify: %d ok, %d failed" % (ok, fail))
    return 0 if fail == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*")
    ap.add_argument("--json")
    ap.add_argument("--episode-gap", type=float, default=1.0)
    ap.add_argument("--rcost", choices=("datafeed", "legacy"), default="datafeed")
    ap.add_argument("--liveness", choices=("is_dead", "hp"), default="is_dead",
                    help="is_dead = DEATH-event spans (audited); hp = the GH #78 proxy")
    ap.add_argument("--verify", action="store_true")
    a = ap.parse_args()
    if a.verify:
        return verify()
    if not a.timelines:
        ap.error("give timeline json paths, or --verify")
    table = RCOST_DATAFEED if a.rcost == "datafeed" else RCOST_LEGACY
    floor = lua_health_floor()
    games = [scan_game(p, table, a.episode_gap, floor, a.liveness) for p in a.timelines]
    games = [g for g in games if g]
    report(games, a.episode_gap, floor, a.rcost, a.json)
    return 0


if __name__ == "__main__":
    sys.exit(main())

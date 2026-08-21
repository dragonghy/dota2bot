#!/usr/bin/env python3
"""Pre-flight corpus check for the `esaftershock` soak candidate (dev-only, no AWS spend).

`esaftershock` (GH #66) is a CANDIDATE-ONLY SECOND PASS inside `J.GetReadyHardCc`
(bots/FunLib/jmz_func.lua): armed, the helper runs the shipped curated scan
first and, only if that found nothing, looks for a spell whose stun comes from a
required PASSIVE --

    J.tHardCcAbilitiesCandidate = { earthshaker_enchant_totem = 'earthshaker_aftershock' }

Earthshaker with Aftershock leveled stuns everything in a self-radius EVERY time
he casts ANY spell, so the cheapest spell he owns is a hard CC even while Fissure
is on cooldown.  The shipped table carries `earthshaker_fissure` and nothing
else, so an ES holding only Enchant Totem reads as harmless.

SCHEDULING FACT THIS SCRIPT EXISTS TO PRICE.  `esaftershock` is INERT on its own:
it only widens what `J.GetReadyHardCc` returns, and the two consumers of that
helper are themselves gated (`cmrguard` in hero_crystal_maiden.lua, `ccburst` in
jmz_func.lua).  So it must share an arm with a consumer, and the headline domain
below is measured against `cmrguard` -- the consumer already in the test set:

    domain = { frames | CM would open Freezing Field, `cmrguard` armed alone
                        RELEASES, and `cmrguard` + `esaftershock` WITHHOLDS }

`ccburst`'s own marginal domain is reported apart in section C (it is a different
id, a different consumer and a different ring: 250 rather than 400) so a
scheduling decision does not have to guess it.  One lever at a time -- section C
is information, not a request.

DESK CHECK FIRST (test_set.md section Y.2: the desk can prove EMPTY, it cannot
prove RARE).  Three desk facts, all verified by grep before this script was run:

  1. NOT NESTED IN AN EXISTING VETO.  The candidate pass runs only after the
     shipped scan returned nil, so armed != shipped requires Fissure to be
     unavailable (on cooldown or unleveled) on the very ES whose Enchant Totem
     is ready -- a DIFFERENT question from the one the shipped scan asks, not a
     sub-case of it.  So the domain is not structurally empty.
  2. THE RING IS THE TIGHT CLAUSE, AND IT IS TINY.  Enchant Totem is no-target,
     so GetCastRange() == 0 and `cmrguard`'s delivery test collapses to
     `dist(CM, ES) <= X.nRGuardCloseBuffer` = 400 units.  Fissure's own anchor
     (1600) plus the same buffer covers the WHOLE 1600 scan, so on any frame
     where ES holds a ready Fissure the shipped scan already vetoes at any
     distance.  The domain therefore lives entirely inside Fissure's cooldown
     window (18/17/16/15s) with ES standing on top of CM.  Whether that is a
     rare co-occurrence or a never is exactly what the desk cannot answer.
  3. THE CARRIER IS RARE BEFORE THE GATE IS.  Earthshaker is not one of the
     focus five and appears in 5 of the 17 games of this corpus, so section D
     reports supply per GAME as well as per frame.

Sections mirror the other five domain scripts in this directory:

  D  SUPPLY        -- carrier present? ES on the enemy team, Aftershock leveled,
                      Enchant Totem learned/affordable, ES inside the ring.
  A  EXACT DOMAIN  -- frames (and EPISODES) where armed != shipped.
  A' CLAUSE FUNNEL -- monotone narrowing of D down to A, plus (the `cmrself`
                      lesson) the histogram of the clause that turns out to be
                      load-bearing, so "small" becomes a named mechanism.
  B  OUTCOME SIDE  -- every real Freezing Field cast, and the GH #66 recall
                      metric measured directly off the channel modifier.
  C  ccburst       -- the other consumer's marginal domain, for information.

NUMERIC ANCHORS (pulled live from the Dota datafeed, hero_id=7, 2026-08-21):

    earthshaker_enchant_totem   AbilityCastRange 0     <- the 400u ring
                                AbilityManaCost  45/55/65/75
                                AbilityCooldown  5 (flat)
    earthshaker_aftershock      aftershock_range 350   (passive, no cast)
    earthshaker_fissure         AbilityCastRange 1600  <- was anchored 1200
                                AbilityManaCost  115/120/125/130
                                AbilityCooldown  18/17/16/15

    crystal_maiden_freezing_field  radius 810 (flat), mana 200/400/600,
                                   cooldown 100/95/90

HONEST BOUNDARIES -- carry these into any readout:
  * NO VISION.  `J.GetNearbyHeroes` returns only VISIBLE enemies and the dumper
    emits no per-team vis (GH #27), so an ES the bots could not see is counted.
    One-sided UPWARD on the domain.
  * `bot:GetActiveMode()` / `J.IsRetreating` / `J.IsGoingOnSomeone` are
    script-side concepts absent from the .dem, so branch 1 is over-counted and
    branch 2 is reported apart as a loose bound only.  Upward again.
  * `IsFullyCastable()` also fails under silence/break/mute; not tracked.
    Upward.
  * MANA IS CHECKED ON THE CANDIDATE SIDE (Enchant Totem's cost is anchored
    above) but NOT on the shipped side -- there is no per-ability mana anchor
    for the whole curated table.  That makes shipped vetoes over-counted, which
    is one-sided DOWNWARD on the domain.  `--shipped-mana` is therefore not
    offered as a knob; the asymmetry is stated instead of hidden.
  * Liveness is `roam_conversion.is_dead()` (DEATH event -> respawn), the only
    audited criterion in this directory (test_set.md section AA.3 rule 1).
    `--liveness hp` reproduces the GH #78 proxy for the audit diff and nothing
    else.  Unlike `cmrself` this gate's predicate says nothing about HP, so a
    corpse frame cannot satisfy it directly -- but a corpse ES can still be
    counted as a live vetoer, which is why the audit column is still printed.
  * SAMPLING: adjacent frames inside one standoff are NOT independent, so every
    count is also reported as an EPISODE count (test_set.md section Z.2).  A
    second reason to quote episodes was measured on this very corpus: the
    dumper's interval is a FLAG, `run_replay.sh` takes the 1.0s default and this
    directory's docstrings used to say 0.5s, and re-dumping the same 17 games
    both ways moves every frame count by ~2x while leaving the episode counts
    and the cast-side counts alone.  The header prints the detected interval.

Usage:
    es_aftershock_domain.py tl/*.json [--json out.json] [--episode-gap 1.0]
                                      [--ms 300] [--liveness is_dead|hp]
                                      [--analysis-dir DIR]
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
    ANCHOR_DELTA, CAST_RANGE, SCAN_RANGE, cast_range, curated_abilities,
    sample_interval, shipped_buffer,
)

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
JMZ = os.path.join(REPO, "bots", "FunLib", "jmz_func.lua")
HERO_LUA = os.path.join(REPO, "bots", "BotLib", "hero_crystal_maiden.lua")

CM = "npc_dota_hero_crystal_maiden"
ES = "npc_dota_hero_earthshaker"
ULT = "crystal_maiden_freezing_field"
CHANNEL_MOD = "modifier_crystal_maiden_freezing_field"

# datafeed hero_id=5 / hero_id=7, pulled 2026-08-21 (see docstring)
ULT_RADIUS = 810.0
ULT_MANA = {1: 200.0, 2: 400.0, 3: 600.0}
TOTEM_MANA = {1: 45.0, 2: 55.0, 3: 65.0, 4: 75.0}

NRADIUS = ULT_RADIUS * 0.88          # X.ConsiderR's nRadius
AOE_HURT_BASE = NRADIUS * 0.82       # minus enemy movespeed, per the Lua
FOUNTAIN_MIN = 300.0
BRANCH1_ENEMY_COUNT = 3
BRANCH1_HURT_COUNT = 2
BRANCH2_ALLY_RING = 1200.0
BRANCH2_CLOSE = 280.0
BRANCH2_MIN_TARGET_HP = 400.0
CCBURST_BUFFER = 250.0               # jmz_func.lua's own closing buffer
GH66_CUT_SHORT = 3.0                 # "channel broken inside 3s", GH #66's metric

# This run re-anchored the whole shared CAST_RANGE table against the datafeed
# (16 of 23 entries were wrong).  What actually moved is recorded once, in
# cmrguard_counterfactual.ANCHOR_DELTA, and echoed by `anchor_audit()` so every
# run of this script reprints it rather than leaving it in a report nobody
# reads.  earthshaker_fissure itself moved 1200 -> 1600 and is INERT on both
# consumers: 1200 + 400 already equals cmrguard's whole 1600 scan and 1200 + 250
# already exceeds ccburst's 1100 scan, so a ready Fissure vetoed at every
# distance under either anchor.  That is measured, not argued -- see the report.


def candidate_map():
    """Extract J.tHardCcAbilitiesCandidate from the Lua so a table edit shows up
    here as a changed reading instead of silent divergence (the tripwire form
    cmrguard_counterfactual.curated_abilities() uses)."""
    src = open(JMZ, encoding="utf-8").read()
    if "J.tHardCcAbilitiesCandidate = {" not in src:
        raise SystemExit("J.tHardCcAbilitiesCandidate is gone from jmz_func.lua "
                         "-- the `esaftershock` gate was renamed or removed; "
                         "this script's readings are void")
    block = src.split("J.tHardCcAbilitiesCandidate = {")[1].split("}")[0]
    pairs = dict(re.findall(r"([a-z_]+)\s*=\s*'([a-z_]+)'", block))
    if pairs != {"earthshaker_enchant_totem": "earthshaker_aftershock"}:
        raise SystemExit("the candidate table is no longer the single "
                         "enchant_totem -> aftershock pair this script models: "
                         "%r" % pairs)
    return pairs


def gate_is_second_pass():
    """Tripwire: the candidate scan must still run AFTER the shipped scan (that
    is what makes it purely ADDITIVE), and behind exactly one id."""
    src = open(JMZ, encoding="utf-8").read()
    fn = src.split("function J.GetReadyHardCc(")[1].split("\nend")[0]
    shipped_at = fn.find("J.tHardCcAbilities[")
    gate_at = fn.find("J.IsSoakCandidate( 'esaftershock' )")
    cand_at = fn.find("J.tHardCcAbilitiesCandidate[")
    if not (0 <= shipped_at < gate_at < cand_at):
        raise SystemExit("J.GetReadyHardCc no longer runs the shipped scan, then "
                         "the gate, then the candidate scan -- the additive-only "
                         "property this script assumes is void")
    if fn.count("J.IsSoakCandidate(") != 1:
        raise SystemExit("more than one soak id inside J.GetReadyHardCc")
    return True


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


def fountain_of(by_t, team):
    """Per-team fountain, estimated from pre-horn snapshots (every hero stands in
    its own fountain at t < -60)."""
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


def ability(snap, name):
    for a in snap.get("abilities") or []:
        if a["name"] == name:
            return a
    return None


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


def ult_state(snap):
    a = ability(snap, ULT)
    if a is None or a["level"] < 1:
        return None
    return a["level"], a["cd"], ULT_MANA.get(a["level"], ULT_MANA[3])


def scan_game(tl_path, buffer_units, curated, ms, gap, liveness="is_dead"):
    raw, teams, events, by_ent, by_t = load_frames(tl_path)
    if CM not in teams:
        return None
    my_team = teams[CM]
    has_es = ES in teams and teams[ES] != my_team
    real = real_entities(by_ent)
    spans = death_spans(raw, real)
    real_idx = {(n, i) for n, i in real.items()}
    fountain = fountain_of(by_t, my_team)

    if liveness == "is_dead":
        def alive(s):
            return not is_dead(spans, s["hero"], s["t"])
    else:                                   # audit-only: the condemned proxy
        def alive(s):
            return s["hp"] > 0

    def shipped_handle(e):
        """The shipped curated scan, in slot order, with the delivery test left
        to the caller.  Returns (name, level) or None -- the level matters
        because two curated abilities are per-level (see `cast_range`)."""
        for ab in e.get("abilities") or []:
            n = ab["name"]
            if n not in curated or ab["level"] < 1 or ab["cd"] != 0:
                continue
            if n not in CAST_RANGE:
                raise SystemExit(
                    "no cast-range anchor for curated ability %r -- add it to "
                    "cmrguard_counterfactual.CAST_RANGE (with a datafeed check) "
                    "before trusting a run" % n)
            return n, ab["level"]
        return None

    def candidate_handle(e):
        """The `esaftershock` second pass: Enchant Totem ready AND affordable,
        with Aftershock leveled.  Cast range is 0, so the caller's ring is the
        bare buffer."""
        totem = ability(e, "earthshaker_enchant_totem")
        after = ability(e, "earthshaker_aftershock")
        if totem is None or after is None:
            return None
        if totem["level"] < 1 or totem["cd"] != 0 or after["level"] < 1:
            return None
        if e["mp"] < TOTEM_MANA.get(totem["level"], TOTEM_MANA[4]):
            return None
        return "earthshaker_enchant_totem"

    def scan(me, frame, ring_buffer):
        """-> (shipped_veto, candidate_veto).  Mirrors the consumer loop: any
        enemy inside the 1600 scan whose handle is deliverable."""
        shipped = cand = False
        for e in frame:
            if e["team"] == my_team or (e["hero"], e["idx"]) not in real_idx:
                continue
            if not alive(e):
                continue
            d = dist(me, e)
            if d > SCAN_RANGE:
                continue
            hit = shipped_handle(e)
            if hit is not None and d <= cast_range(*hit) + ring_buffer:
                shipped = True
            if (candidate_handle(e) is not None
                    and d <= 0.0 + ring_buffer):      # GetCastRange() == 0
                cand = True
        return shipped, cand

    casts = [e["t"] for e in events
             if e["type"] == "ABILITY" and e.get("actor") == CM
             and e.get("inflictor") == ULT]
    deaths = [e["t"] for e in events
              if e["type"] == "DEATH" and e.get("target") == CM]
    # Channel length straight off the modifier the ultimate applies to CM: the
    # GH #66 recall metric ("broken inside 3s") without having to infer it.
    chan_add = sorted(e["t"] for e in events if e["type"] == "MODIFIER_ADD"
                      and e.get("target") == CM and e.get("inflictor") == CHANNEL_MOD)
    chan_rem = sorted(e["t"] for e in events if e["type"] == "MODIFIER_REMOVE"
                      and e.get("target") == CM and e.get("inflictor") == CHANNEL_MOD)

    n_frames = n_alive = n_ready = n_offbase = 0
    n_es_seen = n_es_armed = n_es_ring = n_pred = 0
    domain_t, branch2_t, pred_t = [], [], []
    ccburst_t = []
    ghosts = collections.Counter()
    # The `cmrself` lesson: when the domain comes back small, report the
    # load-bearing clause's OWN distribution, so "small" becomes a mechanism.
    pred_enemy_hist = collections.Counter()
    pred_hurt_hist = collections.Counter()
    es_dist_hist = collections.Counter()      # ES distance bucket when armed
    fissure_state = collections.Counter()     # why the shipped scan was silent
    ult_level_hist = collections.Counter()
    # Where the in-ring frames GO.  The funnel above narrows on CM's ult state
    # BEFORE it asks about ES, so the two views cross; without this column the
    # 65 -> 15 step reads as one drop when it is really four different reasons,
    # only one of which is about the gate.
    ring_fate = collections.Counter()
    ring_ep_t = []

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

        # --- carrier supply, counted independently of CM's ult state --------
        es_snap = next((s for s in frame if s["hero"] == ES
                        and (s["hero"], s["idx"]) in real_idx and alive(s)
                        and s["team"] != my_team), None)
        if es_snap is not None:
            d_es = dist(me, es_snap)
            if d_es <= SCAN_RANGE:
                n_es_seen += 1
                if candidate_handle(es_snap) is not None:
                    n_es_armed += 1
                    es_dist_hist[int(d_es // 200) * 200] += 1
                    if d_es <= buffer_units:
                        n_es_ring += 1
                        ring_ep_t.append(t)
                        fis = ability(es_snap, "earthshaker_fissure")
                        if fis is None or fis["level"] < 1:
                            fissure_state["unleveled"] += 1
                        elif fis["cd"] > 0:
                            fissure_state["on cooldown"] += 1
                        else:
                            fissure_state["READY (shipped already vetoes)"] += 1
                        # ... and where does this frame end up?  Evaluated in
                        # the same order the Lua does.
                        st_r = ult_state(me)
                        in_base = (fountain is not None
                                   and math.hypot(me["x"] - fountain[0],
                                                  me["y"] - fountain[1]) < FOUNTAIN_MIN)
                        sv, cv = scan(me, frame, buffer_units)
                        if st_r is None:
                            ring_fate["ult not learned"] += 1
                        elif st_r[1] > 0 or me["mp"] < st_r[2]:
                            ring_fate["ult on cd / unaffordable"] += 1
                        elif in_base:
                            ring_fate["CM in the fountain"] += 1
                        elif sv:
                            ring_fate["shipped scan ALREADY vetoes"] += 1
                        elif not cv:
                            ring_fate["candidate handle not deliverable"] += 1
                        else:
                            ring_fate["-> gate predicate TRUE"] += 1

        st = ult_state(me)
        if st is None:
            continue
        lvl, cd, cost = st
        ult_level_hist[lvl] += 1
        if cd > 0 or me["mp"] < cost:
            continue
        n_ready += 1

        if fountain is not None and math.hypot(me["x"] - fountain[0],
                                               me["y"] - fountain[1]) < FOUNTAIN_MIN:
            continue
        n_offbase += 1

        # --- the gate predicate: armed flips cm_IsRSafeToOpen to false ------
        shipped_veto, cand_veto = scan(me, frame, buffer_units)
        cc_shipped, cc_cand = scan(me, frame, CCBURST_BUFFER)
        if cc_cand and not cc_shipped:
            ccburst_t.append(t)
        if shipped_veto or not cand_veto:
            continue
        n_pred += 1
        pred_t.append(t)

        # --- would ConsiderR have fired on this frame? ----------------------
        enemies = [s for s in frame
                   if s["team"] != my_team and (s["hero"], s["idx"]) in real_idx
                   and alive(s)]
        in_radius = [e for e in enemies if dist(me, e) <= NRADIUS]

        def hurt_count(mspeed):
            # aoeCanHurtCount: disabled inside nRadius, OR inside the movespeed-
            # dependent inner ring.  Disability is not in a snapshot, so only
            # the ring term is counted -- one-sided DOWNWARD.
            ring = AOE_HURT_BASE - mspeed
            return sum(1 for e in in_radius if dist(me, e) <= ring)

        pred_enemy_hist[len(in_radius)] += 1
        pred_hurt_hist[hurt_count(ms)] += 1

        branch1 = (len(in_radius) >= BRANCH1_ENEMY_COUNT
                   or hurt_count(ms) >= BRANCH1_HURT_COUNT)
        allies = [s for s in frame
                  if s["team"] == my_team and (s["hero"], s["idx"]) in real_idx
                  and alive(s) and dist(me, s) <= BRANCH2_ALLY_RING]
        branch2 = (len(allies) <= 2
                   and any(dist(me, e) <= BRANCH2_CLOSE and e["hp"] > BRANCH2_MIN_TARGET_HP
                           for e in in_radius))

        if branch1:
            domain_t.append(t)
        elif branch2:
            branch2_t.append(t)

    # --- outcome side: classify every real cast -----------------------------
    def snap_at(t):
        near = [tt for tt in by_t if abs(tt - t) <= 0.5]
        if not near:
            return None
        tt = min(near, key=lambda x: abs(x - t))
        return next((s for s in by_t[tt] if s["hero"] == CM and s["idx"] == real[CM]), None)

    cast_rows = []
    for t in casts:
        me = snap_at(t)
        if me is None:
            continue
        frame = by_t[round(me["t"], 1)]
        shipped_veto, cand_veto = scan(me, frame, buffer_units)
        died = next((d for d in deaths if t <= d <= t + 10.0), None)
        # channel length: the ADD nearest the cast, to its next REMOVE
        add = next((a for a in chan_add if -0.5 <= a - t <= 2.0), None)
        rem = next((r for r in chan_rem if add is not None and r >= add), None)
        chan = round(rem - add, 2) if (add is not None and rem is not None) else None
        cast_rows.append({
            "t": round(t, 1),
            "hp_pct": round(me["hp_pct"], 3),
            "shipped_veto": shipped_veto,
            "would_withhold": cand_veto and not shipped_veto,
            "channel_s": chan,
            "cut_short": (chan is not None and chan < GH66_CUT_SHORT),
            "died_after": round(died - t, 1) if died is not None else None,
        })

    return {
        "game": os.path.basename(tl_path).replace(".timeline.json", "").replace(".json", ""),
        "has_es": has_es, "cm_team": my_team,
        "interval": sample_interval(by_t.keys()),
        "frames": n_frames, "alive": n_alive, "ready": n_ready, "offbase": n_offbase,
        "es_seen": n_es_seen, "es_armed": n_es_armed, "es_ring": n_es_ring,
        "pred": n_pred,
        "domain_t": domain_t, "branch2_t": branch2_t, "pred_t": pred_t,
        "ccburst_t": ccburst_t,
        "domain_episodes": episode_runs(domain_t, gap),
        "pred_episodes": episode_runs(pred_t, gap),
        "ccburst_episodes": episode_runs(ccburst_t, gap),
        "pred_enemy_hist": dict(pred_enemy_hist),
        "pred_hurt_hist": dict(pred_hurt_hist),
        "es_dist_hist": dict(es_dist_hist),
        "fissure_state": dict(fissure_state),
        "ring_fate": dict(ring_fate),
        "ring_episodes": episode_runs(ring_ep_t, gap),
        "ult_level_hist": dict(ult_level_hist),
        "casts": cast_rows,
        "deaths": len(deaths),
        "ghosts": dict(ghosts),
    }


def armed_side(analysis_dir, game):
    """-> (seed, armed_team, armed_ids) from the wave's own `*.analysis.json`,
    or None.  `script_version` is `mirror:<id,...>:<seed>:<radiant|dire>` on a
    mirrored wave and a bare tree hash on an unmirrored one.

    This is what turns the no-vision boundary from a disclaimer into a
    MEASUREMENT.  `cmrguard` was armed on one side of every mirrored game in
    this corpus, so on those games a real Freezing Field cast is proof the
    live gate RELEASED that frame -- and any frame where this offline
    reconstruction claims a shipped veto at that instant is a demonstrated
    FALSE POSITIVE of the reconstruction, not of the gate."""
    if not analysis_dir:
        return None
    p = os.path.join(analysis_dir, game + ".analysis.json")
    if not os.path.exists(p):
        return None
    sv = json.load(open(p)).get("script_version", "")
    if not sv.startswith("mirror:"):
        return (sv, None, ())
    parts = sv.split(":")
    return (parts[-2], 2 if parts[-1] == "radiant" else 3, tuple(parts[1].split(",")))


def anchor_audit():
    """The cast-range anchors that MOVED when this shared table was re-anchored
    to the datafeed, reprinted on every run: other detectors' published numbers
    were computed under the old values."""
    return [(name, old, new) for name, (old, new) in sorted(ANCHOR_DELTA.items())]


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
    ap.add_argument("--analysis-dir",
                    help="directory of the wave's <game>.analysis.json files; "
                         "enables the armed-side false-positive audit")
    a = ap.parse_args()

    candidate_map()
    gate_is_second_pass()
    curated = curated_abilities()
    buffer_units = shipped_buffer()

    games = []
    for p in a.timelines:
        g = scan_game(p, buffer_units, curated, a.ms, a.episode_gap, a.liveness)
        if g:
            games.append(g)
    if not games:
        raise SystemExit("no game in the corpus contains Crystal Maiden")
    es_games = [g for g in games if g["has_es"]]

    tot = collections.Counter()
    for g in games:
        for k in ("frames", "alive", "ready", "offbase", "es_seen", "es_armed",
                  "es_ring", "pred", "deaths"):
            tot[k] += g[k]
        tot["domain"] += len(g["domain_t"])
        tot["branch2"] += len(g["branch2_t"])
        tot["ccburst"] += len(g["ccburst_t"])

    all_eps = [r for g in games for r in g["domain_episodes"]]
    n_eps, longest_f, longest_s = episodes_of(all_eps)
    games_hit = sum(1 for g in games if g["domain_t"])
    ep_hist = collections.Counter(len(r) for r in all_eps)

    print(f"=== corpus: {len(games)} games with Crystal Maiden, "
          f"{len(es_games)} of them with an ENEMY Earthshaker "
          f"(ring read live: X.nRGuardCloseBuffer={buffer_units:.0f}; "
          f"liveness={a.liveness}, ms={a.ms:.0f}) ===")
    ivs = sorted({g["interval"] for g in games if g["interval"]})
    print(f"  SAMPLING INTERVAL {ivs}s -- every FRAME count below scales with "
          f"this; the\n  EPISODE counts and the cast-side counts do not. Quote "
          f"those (test_set.md Z.2).")
    if len(ivs) > 1:
        print("  WARNING: mixed intervals in one corpus -- frame totals are "
              "meaningless here.")
    for name, old, new in anchor_audit():
        print(f"  RE-ANCHORED  {name}: was {old}, datafeed says {new} "
              f"-- readings published under the old value must be re-read")

    print("\n=== D  SUPPLY (the carrier, before CM's own state) ===")
    print(f"  games with CM                              {len(games):6d}")
    print(f"  games with an ENEMY Earthshaker            {len(es_games):6d}   "
          f"{pct(len(es_games), len(games))}")
    print(f"  CM frames (all)                            {tot['frames']:6d}")
    print(f"  ... alive                                  {tot['alive']:6d}  "
          f"{pct(tot['alive'], tot['frames'])}")
    print(f"  ... ES alive inside the 1600 scan          {tot['es_seen']:6d}  "
          f"{pct(tot['es_seen'], tot['alive'])}")
    print(f"  ... ES ALSO totem-ready + aftershock       {tot['es_armed']:6d}  "
          f"{pct(tot['es_armed'], tot['es_seen'])}")
    print(f"  ... ES ALSO inside the {buffer_units:.0f}u delivery ring   "
          f"{tot['es_ring']:6d}  {pct(tot['es_ring'], tot['es_armed'])}")
    dh = collections.Counter()
    fs = collections.Counter()
    for g in games:
        dh.update(g["es_dist_hist"])
        fs.update(g["fissure_state"])
    print(f"  ES distance when totem-armed (200u buckets): "
          f"{dict(sorted(dh.items()))}")
    print(f"  on the in-ring frames, Fissure was: {dict(fs)}")
    print("    -- 'READY' means the SHIPPED scan already vetoes there, so those "
          "frames\n       can never be in the domain no matter what CM is doing.")
    ring_eps = [r for g in games for r in g["ring_episodes"]]
    n_ring_eps, rf, rs = episodes_of(ring_eps)
    ring_games = sum(1 for g in games if g["ring_episodes"])
    print(f"  those in-ring frames are {n_ring_eps} EPISODES in "
          f"{ring_games}/{len(games)} games, longest {rf} frames / {rs}s")
    rfate = collections.Counter()
    for g in games:
        rfate.update(g["ring_fate"])
    print("  and where each in-ring frame ENDS UP (evaluated in the Lua's own "
          "order):")
    for k, n in rfate.most_common():
        print(f"    {k:<38}{n:5d}  {pct(n, sum(rfate.values()))}")

    print("\n=== A  EXACT DOMAIN (armed != shipped AND branch 1 would fire) ===")
    print(f"  frames    {tot['domain']:5d}")
    print(f"  EPISODES  {n_eps:5d}   in {games_hit}/{len(games)} games "
          f"({games_hit}/{len(es_games)} of the ES games)   "
          f"= {n_eps / len(games):.2f}/game over the corpus, "
          f"{(n_eps / len(es_games) if es_games else 0):.2f}/game over ES games")
    print(f"  longest run: {longest_f} frames / {longest_s}s")
    print(f"  episode-length histogram: {dict(sorted(ep_hist.items()))}")
    print(f"  branch-2 LOOSE upper bound (3 unobservable conjuncts assumed true): "
          f"{tot['branch2']} extra frames")

    print("\n=== A' CLAUSE FUNNEL ===")
    steps = [("CM frames", tot["frames"]), ("alive", tot["alive"]),
             ("ult learned + castable", tot["ready"]),
             ("outside the fountain", tot["offbase"]),
             ("+ armed vetoes where shipped did not", tot["pred"]),
             ("+ branch 1 would fire", tot["domain"])]
    prev = None
    for label, n in steps:
        delta = "" if prev is None else f"   {n - prev:+6d}  ({pct(n, prev)} kept)"
        print(f"  {label:<38}{n:6d}{delta}")
        prev = n

    print("  NB the -5727 step is NOT one clause: the funnel narrows on CM's own "
          "state first,\n     so it also absorbs every frame with no Earthshaker "
          "in the game at all. The\n     honest decomposition is the in-ring "
          "fate table in section D above.")

    pred_eps = [r for g in games for r in g["pred_episodes"]]
    n_pred_eps, pf, ps = episodes_of(pred_eps)
    pred_games = sum(1 for g in games if g["pred_t"])
    print(f"\n  the GATE PREDICATE alone (armed vetoes, shipped does not): "
          f"{tot['pred']} frames = {n_pred_eps} EPISODES in "
          f"{pred_games}/{len(games)} games, longest {pf} frames / {ps}s.")
    eh = collections.Counter()
    hh = collections.Counter()
    for g in games:
        eh.update(g["pred_enemy_hist"])
        hh.update(g["pred_hurt_hist"])
    print("  On exactly those frames, what the FIRE clause sees "
          "(test_set.md section AC.2 -- report the load-bearing clause's own "
          "distribution, not just the domain size):")
    print(f"    enemies inside nRadius={NRADIUS:.1f}: {dict(sorted(eh.items()))}"
          f"   -> `>= {BRANCH1_ENEMY_COUNT}` fires "
          f"{sum(n for k, n in eh.items() if k >= BRANCH1_ENEMY_COUNT)}/{tot['pred']}")
    print(f"    aoeCanHurtCount (ms={a.ms:.0f}):      {dict(sorted(hh.items()))}"
          f"   -> `>= {BRANCH1_HURT_COUNT}` fires "
          f"{sum(n for k, n in hh.items() if k >= BRANCH1_HURT_COUNT)}/{tot['pred']}")

    lv = collections.Counter()
    for g in games:
        lv.update(g["ult_level_hist"])
    print(f"\n  Freezing Field level over learned frames: {dict(sorted(lv.items()))}"
          f"  ({pct(lv.get(1, 0), sum(lv.values()))} at level 1)")

    print("\n=== B  OUTCOME SIDE (every real Freezing Field cast) ===")
    rows = [c for g in games for c in g["casts"]]
    es_rows = [c for g in es_games for c in g["casts"]]
    withheld = [c for c in rows if c["would_withhold"]]
    chan = [c for c in rows if c["channel_s"] is not None]
    cut = [c for c in chan if c["cut_short"]]
    print(f"  casts total                     {len(rows):4d}   "
          f"= {len(rows) / len(games):.2f}/game   "
          f"({len(es_rows)} of them in the {len(es_games)} ES games)")
    print(f"  channel length measured          {len(chan):4d}   "
          f"(median {sorted(c['channel_s'] for c in chan)[len(chan) // 2]:.2f}s)"
          if chan else "  channel length measured             0")
    print(f"  ... broken inside {GH66_CUT_SHORT:.0f}s (GH #66)     {len(cut):4d}   "
          f"{pct(len(cut), len(chan))} of measured channels")
    print(f"  casts `cmrguard`+`esaftershock` would WITHHOLD and "
          f"`cmrguard` alone would not: {len(withheld)}")
    for c in sorted(withheld, key=lambda c: c["t"]):
        print(f"    t={c['t']:7.1f}  hp={c['hp_pct']:.3f}  channel={c['channel_s']}s"
              f"  died_after={c['died_after']}")
    print("  cut-short channels, with what the gate would have said:")
    for c in sorted(cut, key=lambda c: c["t"]):
        print(f"    t={c['t']:7.1f}  channel={c['channel_s']:.2f}s  "
              f"shipped_veto={c['shipped_veto']}  "
              f"esaftershock_would_add={c['would_withhold']}  "
              f"died_after={c['died_after']}")

    print("\n=== C  the OTHER consumer (`ccburst`, information only) ===")
    cc_eps = [r for g in games for r in g["ccburst_episodes"]]
    n_cc, cf, cs = episodes_of(cc_eps)
    cc_games = sum(1 for g in games if g["ccburst_t"])
    print(f"  frames where the candidate adds a handle inside ccburst's "
          f"{CCBURST_BUFFER:.0f}u ring: {tot['ccburst']}")
    print(f"  EPISODES {n_cc} in {cc_games}/{len(games)} games, "
          f"longest {cf} frames / {cs}s")
    print("  NOTE this is a DIFFERENT id with a different consumer "
          "(J.ShouldFleeLaneTrade).\n       Reported so a scheduling decision "
          "need not guess it; not a request.")

    if a.analysis_dir:
        print("\n=== AUDIT  armed side vs this reconstruction ===")
        seeds = collections.Counter()
        es_seeds = collections.Counter()
        armed_casts = fp = unarmed_casts = 0
        cmrguard_in_string = None
        for g in games:
            info = armed_side(a.analysis_dir, g["game"])
            if info is None:
                continue
            seed, armed_team, ids = info
            seeds[seed] += 1
            if g["has_es"]:
                es_seeds[seed] += 1
            if armed_team is None:
                cm_armed = False
            else:
                cm_armed = (armed_team == g["cm_team"])
                if cmrguard_in_string is None:
                    cmrguard_in_string = "cmrguard" in ids
            for c in g["casts"]:
                if cm_armed:
                    armed_casts += 1
                    if c["shipped_veto"]:
                        fp += 1
                else:
                    unarmed_casts += 1
        print(f"  seeds in the corpus: {dict(sorted(seeds.items()))}")
        print(f"  seeds that DRAFT Earthshaker: {dict(sorted(es_seeds.items()))}"
              "   <- a wave without one of these buys nothing (GH #46)")
        print(f"  `cmrguard` present in the wave's armed string: {cmrguard_in_string}")
        print(f"  real casts on the side where `cmrguard` was LIVE: {armed_casts}")
        print(f"  ... of which this reconstruction claims a shipped veto "
              f"(FALSE POSITIVES): {fp}")
        print(f"  real casts on the baseline side:                  {unarmed_casts}")
        print("  A live gate cannot have released a frame it vetoes, so every "
              "one of those\n       false positives is over-counting by this "
              "script (no vision, no mana check).")

    print("\n=== LIVENESS AUDIT (GH #78 / #82) ===")
    gh = collections.Counter()
    for g in games:
        gh.update(g["ghosts"])
    print(f"  CM frames the `hp > 0` proxy calls ALIVE but is_dead() calls dead: "
          f"{gh['proxy_alive_event_dead']}")
    print(f"  CM frames the proxy calls DEAD but is_dead() calls alive:          "
          f"{gh['proxy_dead_event_alive']}")
    print("  This gate's predicate says nothing about HP, so a corpse CM cannot "
          "satisfy it\n       directly -- but a corpse ES could still be counted "
          "as a live vetoer; rerun\n       with --liveness hp for that "
          "contamination's size.")

    if a.json:
        json.dump({"games": games, "totals": dict(tot), "episodes": n_eps,
                   "buffer": buffer_units, "ms": a.ms, "liveness": a.liveness},
                  open(a.json, "w"), indent=1)
        print(f"\nwrote {a.json}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Extract a decision-instant Lua fixture from a behav-dump timeline.

This is the LOCAL-VALIDATION half of the iteration loop (CLAUDE.md "Agent
iteration loop"): a bad decision is spotted at time T in a replay; this tool
freezes that instant — every hero's real position/HP/mana/level/team — plus the
GROUND TRUTH of what followed (per-enemy damage actually dealt to the subject
over the next window, and whether/when the subject died). The Lua fixture feeds
tests/mock/replay_fixture.lua, which rebuilds the world under the mock Bot API
so the REAL decision helpers (jmz_func) run on the REAL game state, and a unit
test asserts the fixed decision. No simulator involved.

Usage:
  python3 make_fixture.py <timeline.json> --t 309.5 --hero luna \
      -o tests/fixtures/f_071423_luna_chase.lua [--window 5]
"""
import argparse
import bisect
import json
import math
import os
from collections import Counter, defaultdict

FULL = "npc_dota_hero_"


def bare(n):
    return n.replace(FULL, "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timeline")
    ap.add_argument("--t", type=float, required=True, help="decision instant (game-clock s)")
    ap.add_argument("--hero", required=True, help="subject hero, bare name (e.g. luna)")
    ap.add_argument("--window", type=float, default=5.0, help="ground-truth window after t")
    ap.add_argument("--damage-horizon", type=float, default=30.0,
                    help="how far past t to record the per-event damage timeline")
    ap.add_argument("--recent-window", type=float, default=6.0,
                    help="how far BEFORE t to record incoming damage, so the "
                         "WasRecentlyDamagedBy* readers can be answered")
    ap.add_argument("--roles", help="path to the game's analysis.json; the drafted "
                    "position of each hero is derived from its soak seed and written "
                    "into the fixture. Without it the fixture carries no roles and the "
                    "loader falls back to draft-slot order, which GH #57 measured at "
                    "47.3% accurate -- so any test that reads jmz.GetPosition needs this.")
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()

    roles = None
    if args.roles:
        import sys as _sys
        _here = os.path.dirname(os.path.abspath(__file__))
        _sys.path.insert(0, os.path.join(_here, "..", "soak"))
        import seed_draft
        with open(args.roles) as fh:
            roles = seed_draft.positions_for_game(json.load(fh))
        if roles is None:
            raise SystemExit("--roles: that analysis.json is not attributable to a soak "
                             "seed (warm-up game, or the roster does not match the "
                             "seed's draft). Refusing to guess -- see GH #57.")

    def active_modifiers(tl, t):
        """Per-hero modifiers ACTIVE at t, rebuilt from the combat log.

        The whole replay is parsed, so every MODIFIER_ADD can be matched to its
        MODIFIER_REMOVE and a real remaining duration is known at any instant --
        the same reconstruction replayscope/build.py uses to draw its CC
        countdowns, here kept for EVERY modifier instead of the CC shortlist.

        Why a decision fixture needs this: without it every fixture world has
        `HasModifier == false` for everything (the mock's Is/Has/Can default),
        which silently states a world assumption nobody declared -- nobody is
        rooted, stunned, silenced, hexed, channelling a TP, or holding any buff.
        Whole shipped branches are then structurally unreachable in EVERY
        fixture (mode_roam_generic's continuous-attack branches are all
        modifier-authorized; the tpscroll consider function opens with a
        ten-modifier veto list), and worse, a test can assert "it should have
        walked away here" on a frame where the hero was in fact rooted.

        `stacks` is emitted ONLY when the log shows evidence of stacking
        (concurrent instances of the same name, or MODIFIER_STACK_EVENT rows
        since this instance began). The combat log's stack VALUE semantics are
        not settled, so this counts EVENTS, not the engine's own counter --
        absent the field the loader answers 0, which is engine-truthful for a
        non-stacking modifier. Do not anchor a `J.GetModifierCount(...) >= N`
        threshold on it until the dumper carries the entity's real stack count.
        """
        open_iv, closed = {}, defaultdict(list)   # (target, mod) -> [(s, e)]
        stack_ev = defaultdict(list)              # (target, mod) -> [t, ...]
        last_t = 0.0
        for e in tl.get("events", []):
            last_t = max(last_t, e.get("t", 0))
            typ, mod, tgt = e.get("type"), e.get("inflictor", ""), e.get("target")
            if not tgt or not mod:
                continue
            key = (tgt, mod)
            if typ == "MODIFIER_ADD":
                open_iv.setdefault(key, []).append(e["t"])
            elif typ == "MODIFIER_REMOVE" and open_iv.get(key):
                closed[key].append((open_iv[key].pop(0), e["t"]))
            elif typ == "MODIFIER_STACK_EVENT":
                stack_ev[key].append(e["t"])
        # An ADD with no REMOVE lasted to the end of what we parsed.
        for key, starts in open_iv.items():
            for s in starts:
                closed[key].append((s, last_t))

        out = defaultdict(list)
        for (tgt, mod), ivs in closed.items():
            live = [(s, e) for (s, e) in ivs if s <= t < e]
            if not live:
                continue
            s0, e0 = min(live)
            n = len(live) + sum(1 for st in stack_ev.get((tgt, mod), []) if s0 <= st <= t)
            out[tgt].append({
                "name": mod,
                "remaining": round(e0 - t, 2),
                "elapsed": round(t - s0, 2),
                # >1 only when the log actually showed stacking (see docstring).
                "stacks": n if n > 1 else 0,
            })
        for tgt in out:
            out[tgt].sort(key=lambda m: m["name"])
        return out

    def recent_damage(tl, t, heroes_by_canon):
        """Per-hero damage RECEIVED in (t - recent_window, t].

        Why a decision fixture needs it: `WasRecentlyDamagedByAnyHero` and its
        three siblings are read at 670 sites under `bots/`, and the mock's
        Is/Has/Can/Was default answers `false` for all of them. So every fixture
        world silently asserted "nobody here has been hit by anything recently"
        -- the same undeclared world assumption as the pre-2026-08-19 blanket
        `HasModifier == false`, and the GetTower / GetIncomingTrackingProjectiles
        gaps before it. Whole shipped branches are unreachable underneath it
        (J.ShouldAbandonTpChannel's third line, the retreat/defend "am I under
        fire" guards, ...), and a test can assert a calm-frame decision on a
        frame where the hero was being focused.

        The fixture's `observed.damage` block cannot answer this: it looks
        FORWARD from t (ground truth about what followed), while these readers
        look BACKWARD (what the bot already knows at t).

        Conventions, deliberate and asserted by tests/test_fixture_recent_damage:
          * `dt` is seconds BEFORE t (positive), so the reader is `dt <= interval`;
          * `kind` is 'hero' / 'tower' / 'creep' / 'other' -- one per engine
            reader, classified from the actor entity name;
          * SELF damage is dropped: these readers exist to answer "is someone
            hitting me", and armlet/blade-mail style self-ticks would make every
            such guard true for the wrong reason;
          * hero actors are stored under their SNAPSHOT name, because the event
            stream spells some heroes without underscores (`queenofpain` vs
            `queen_of_pain`) and WasRecentlyDamagedByHero compares handles;
          * `src` carries the RAW actor entity name on non-hero rows (and is
            absent on hero rows, where `actor` already names it).

        Why `src` exists (director 2026-08-22T23:0xZ, test_set.md SS-AR.2):
        `kind` MUST fold neutrals into 'creep', because the engine hands the
        script exactly one reader for both (`WasRecentlyDamagedByCreep`) and the
        mock has to answer the same question the engine answers. But collapsing
        `kind` while also dropping `actor` deleted "was it a centaur or a melee
        creep" at fixture-write time, unrecoverably. That question turned out to
        be load-bearing: ruling on the gated 'fieldcreep' veto needed to know
        which of its five vetoed frames were camp contact, and the corpus could
        not say -- the source had to be INFERRED from per-hit magnitude. `src` is
        an extra field, not a reclassification, so every existing reader (and
        `WasRecentlyDamagedByCreep` itself) is untouched; it only makes newly
        dumped fixtures able to answer what the old ones cannot.
        """
        lo = t - args.recent_window
        out = defaultdict(list)
        for e in tl.get("events", []):
            if e.get("type") != "DAMAGE" or not (lo < e.get("t", -1e9) <= t):
                continue
            tgt = heroes_by_canon.get(bare(e.get("target") or "").replace("_", "").lower())
            if tgt is None:
                continue
            actor_raw = e.get("actor") or ""
            src = None
            if e.get("actor_hero"):
                kind = "hero"
                actor = heroes_by_canon.get(bare(actor_raw).replace("_", "").lower())
                if actor is None or actor == tgt:
                    continue        # unmapped illusion/clone, or self damage
            else:
                actor = None
                src = actor_raw or None
                low = actor_raw.lower()
                if "tower" in low:
                    kind = "tower"
                elif "creep" in low or "neutral" in low:
                    kind = "creep"
                else:
                    kind = "other"
            row = {"dt": round(t - e["t"], 2), "kind": kind,
                   "actor": actor, "value": e.get("value", 0)}
            if src is not None:
                row["src"] = src
            out[tgt].append(row)
        for tgt in out:
            out[tgt].sort(key=lambda d: (d["dt"], d["kind"]))
        return out

    tl = json.load(open(args.timeline))
    subj = FULL + args.hero
    mods_at_t = active_modifiers(tl, args.t)

    # Keep only each hero's longest-lived entity idx (drops illusions — same
    # canonicalization as replayscope/build.py).
    life = defaultdict(Counter)
    for s in tl["snapshots"]:
        if "idx" in s:
            life[s["hero"]][s["idx"]] += 1
    canon = {h: c.most_common(1)[0][0] for h, c in life.items()}

    per = defaultdict(list)
    for s in tl["snapshots"]:
        if s["hero"] in canon and s.get("idx") != canon[s["hero"]]:
            continue
        per[s["hero"]].append(s)
    for h in per:
        per[h].sort(key=lambda s: s["t"])

    # ---- illusion contamination of the ground truth -------------------------
    #
    # The snapshot stream identifies units by ENTITY INDEX, so the block above
    # can drop a hero's illusions cleanly. The COMBAT LOG cannot: every DAMAGE
    # row carries `actor`/`target` as a bare hero NAME, and an illusion is
    # logged under the name of the hero it copies. So while an illusion of hero
    # H is on the field, every damage row naming H is ambiguous between the
    # hero and its copy -- and this generator writes those rows out as
    # `observed.burst` ("damage each enemy hero ACTUALLY dealt to the subject"),
    # which tests/mock/replay_fixture.lua installs as the subject's
    # GetEstimatedDamageToTarget. That is the input of J.WillAllySurviveTpWindow
    # (shipped), J.IsIncomingBurstLethal ('tpdying') and J.ShouldRetreatLaneBurst.
    #
    # Measured, not hypothesised: 20260820_102030_slot1 @ t=639.5, subject
    # tidehunter -- the name-keyed sum says 849 damage from four enemy heroes in
    # the next 3s, while the hero's own entity went 1419 -> 1452 -> 1435 -> 1423
    # (it REGENERATED). All 849 landed on illusion entity 2537.
    #
    # There is nothing to reconstruct here -- the log simply does not say which
    # copy was hit -- so the block is WITHHELD and the reason stated, the same
    # rule the loader already applies to `sSubject` overrides ("rather than a
    # number that would silently mean damage dealt to someone else").
    shadow_alive = defaultdict(list)     # hero -> sample times a copy was alive
    for s in tl["snapshots"]:
        h = s["hero"]
        if h not in canon or s.get("idx") == canon[h]:
            continue
        if (s.get("hp_pct") or 0) > 0:
            shadow_alive[h].append(s["t"])
    # The dump samples on a fixed interval, so a copy can be born and die
    # between two samples; pad each side by one interval and over-report rather
    # than let an unsampled copy through.
    all_ts = sorted(set(s["t"] for s in tl["snapshots"]))
    pad = min((b - a for a, b in zip(all_ts, all_ts[1:])), default=1.0)

    def shadowed(hero, lo, hi):
        """Did a non-canonical entity of `hero` exist anywhere in (lo, hi]?"""
        return any(lo - pad < ts <= hi + pad for ts in shadow_alive.get(hero, ()))

    recent_at_t = recent_damage(
        tl, args.t, {bare(h).replace("_", "").lower(): h for h in per})

    def at(h, t):
        arr = per[h]
        ts = [x["t"] for x in arr]
        j = bisect.bisect_right(ts, t) - 1
        return arr[max(j, 0)] if arr else None

    units = []
    for h in sorted(per):
        s = at(h, args.t)
        if s is None:
            continue
        # Same name-vs-entity ambiguity as `observed.burst`, looking backwards:
        # a row is only usable if neither the hero that was hit nor the hero
        # credited with hitting it had a copy on the field in the lookback.
        rows = recent_at_t.get(h, [])
        rd_ambiguous = bool(rows) and (
            shadowed(h, args.t - args.recent_window, args.t)
            or any(d["actor"] is not None
                   and shadowed(d["actor"], args.t - args.recent_window, args.t)
                   for d in rows))
        if rd_ambiguous:
            rows = []
        hp_pct = s.get("hp_pct") or 0
        max_hp = int(round(s["hp"] / hp_pct)) if hp_pct > 0 and s.get("hp") else s.get("hp", 0)
        units.append({
            "name": h, "team": s["team"],
            # the engine player slot (Radiant 0-4, Dire 5-9). aba_role's whole
            # role chain hangs off it, so without it the fixture world answers
            # "everyone is pos 1 / everyone is a core" -- a definite WRONG
            # answer rather than a refusal (issue #53). -1 (or absent, on dumps
            # older than this field) means the fixture must not claim to know.
            "player_id": s.get("player_id", -1),
            "x": round(s["x"], 1), "y": round(s["y"], 1),
            "hp": s.get("hp", 0), "max_hp": max_hp,
            "mp": s.get("mp", 0), "max_mp": s.get("max_mp", 0),
            "level": s.get("level", 1), "alive": hp_pct > 0,
            # which teams could SEE this hero at that instant (v2 "vision+items"
            # dumps only; absent on v1 position-only dumps). The bot's info model
            # is vision-limited -- J.CanCastOnNonMagicImmune/J.IsValid both gate
            # on CanBeSeen() -- so a fixture that pretends everyone is visible
            # cannot reproduce any fog-dependent decision.
            "seen_by": sorted(s.get("vis") or []),
            # real net worth, when the dump carries it -- lets fixtures exercise
            # relative-economy scoring decisions (e.g. "who's snowballing").
            "net_worth": s.get("net_worth", 0),
            # real inventory (slot-ordered, '' = empty) and TP cooldown, when the
            # dump carries them — lets fixtures exercise item decisions too.
            "items": [x for x in (s.get("items") or [])],
            "tp_cd": s.get("tp_cd", 0),
            # real ability state (name/level/cd remaining) — lets fixtures feed
            # FULL hero scripts (SkillsComplement), not just decision helpers.
            "abilities": [
                {"name": a.get("name", ""), "level": a.get("level", 0),
                 "cd": a.get("cd", 0)}
                for a in (s.get("abilities") or [])
            ],
            # real buffs/debuffs active at the instant (see active_modifiers)
            "modifiers": mods_at_t.get(h, []),
            # what hit this hero just BEFORE the instant (see recent_damage)
            "recent_damage": rows,
            "recent_damage_ambiguous": rd_ambiguous,
        })
    assert any(u["name"] == subj for u in units), "subject %s not in timeline" % subj

    # Ground truth: per-enemy-hero damage actually dealt to the subject in
    # (t, t+window], and the subject's death time after t (if it died).
    burst = Counter()
    died_after = None
    # ...plus the raw per-event damage timeline out to a longer horizon. `burst`
    # answers exactly one window (the shipped J.WillAllySurviveTpWindow budget);
    # a test that asks what a DIFFERENT arrival window would have seen -- the
    # whole question GH #37 candidate 2 turns on -- needs the events themselves.
    # Hero damage only, same filter as `burst`, because the gate this feeds sums
    # over enemy HEROES near the ally and structurally cannot see anything else.
    damage = []
    for e in tl.get("events", []):
        if e.get("type") == "DAMAGE" and e.get("target") == subj \
                and e.get("actor_hero") and args.t < e["t"] <= args.t + args.window:
            burst[e["actor"]] += e["value"]
        if e.get("type") == "DAMAGE" and e.get("target") == subj \
                and e.get("actor_hero") \
                and args.t < e["t"] <= args.t + args.damage_horizon:
            damage.append((round(e["t"] - args.t, 2), e["actor"], e["value"]))
        if e.get("type") == "DEATH" and e.get("target") == subj and e["t"] >= args.t \
                and died_after is None:
            died_after = round(e["t"] - args.t, 1)

    # Withhold the forward ground truth when a copy of the subject, or of any
    # hero credited with hitting it, was on the field (see `shadowed` above).
    # `died_after` goes with them: it is only meaningful as "the subject died
    # from what `burst`/`damage` describe", and the DEATH rows are name-keyed
    # too. LIMITATION, asserted rather than assumed: no DEATH row for an
    # illusion was observed in this corpus, so the death time is probably safe;
    # this refuses anyway rather than ship a half-checked block.
    gt_actors = set(a for _, a, _ in damage) | set(burst)
    gt_ambiguous = shadowed(subj, args.t, args.t + args.damage_horizon) or any(
        shadowed(a, args.t, args.t + args.damage_horizon) for a in gt_actors)
    gt_shadowed = sorted(h for h in ({subj} | gt_actors)
                         if shadowed(h, args.t, args.t + args.damage_horizon))
    if gt_ambiguous:
        burst, damage, died_after = Counter(), [], None
    damage.sort()

    # Buildings (towers/rax/ancient/watch-tower) at the instant. The dumper
    # samples these on their own (coarser) interval and carries no entity idx,
    # so identity is (name, team, x, y) -- structures never move -- and the
    # latest sample at or before t wins, which is what makes `alive` truthful.
    #
    # Why a decision fixture needs them: the shipped TP landing point is
    # J.GetNearbyLocationToTp = 575 units in front of the nearest ALIVE friendly
    # tower (fountain when none is left). Without towers in the slice that
    # helper degenerates to the fountain fallback for EVERY fixture, so no test
    # can assert where a rescue/defend TP actually puts the responder -- the
    # exact question GH #37 turns on. Same for J.GetRescueTpTarget's
    # "ally is standing under its own tower" veto, which scans
    # UNIT_LIST_ALLIED_BUILDINGS and is silently always-false without them.
    #
    # IDENTITY IS POSITION, NOT POSITION+TEAM (fixed 2026-09-05, GH #511 (甲)).
    # The first cut keyed on (name, TEAM, x, y). Structures never move and
    # towers/rax/ancient never change hands, so for them the two keys agree --
    # but a WATCH TOWER (outpost) is captured, and captures are the whole point
    # of that entity: 13 of them in the 37-game W47 corpus. After a flip the
    # team-keyed dict holds TWO live rows at the same coordinates, the current
    # owner AND a frozen row still claiming the previous owner, and both are
    # emitted. The stale one is not inert -- it enters UNIT_LIST_*_BUILDINGS
    # (the loader files every fixture building into the team list it names), so
    # a fixture taken after any capture states a world in which BOTH teams own
    # the same outpost. Keyed on position, the latest sample simply carries the
    # current team, which is the engine's own semantics.
    latest_b = {}
    for b in tl.get("buildings", []):
        if b["t"] <= args.t:
            latest_b[(b["name"], round(b["x"]), round(b["y"]))] = b
    # `hp` is the health FRACTION at t. Without it every structure in every
    # fixture stood at full health, and aba_defend reads that number twice:
    # the lane urgency multiplier is a remap of it, and "this tier-1/2 is
    # already lost" is a threshold on it.
    buildings = [
        {"name": k[0], "team": b["team"], "x": k[1], "y": k[2],
         "alive": bool(b.get("alive")),
         "hp": round(float(b.get("hp_pct", 1.0)), 3), "modifiers": []}
        for k, b in sorted(latest_b.items())
    ]

    # ---- modifiers on STRUCTURES (GH #511 handoff (甲)) --------------------
    # `active_modifiers` already rebuilds every combat-log modifier interval,
    # keyed by the log's TARGET string -- heroes and structures alike. Only the
    # hero keys were ever read (`mods_at_t.get(h, [])`), so a structure's
    # modifiers were computed and then dropped on the floor. The one this was
    # opened for is `modifier_watch_tower_capturing`, which the log puts on the
    # OUTPOST (actor = the capturing hero, target = `#DOTA_OutpostName_*`), so
    # `ClosestOutpost:HasModifier(...)` -- the predicate any commit-style fix
    # to the outpost mode has to be tested against -- was unanswerable from a
    # fixture. NOTE this needed no dumper change: the field was already in the
    # dump, in `events`, one table over.
    #
    # The join is the part that has to be earned. The log names an outpost
    # `#DOTA_OutpostName_North|South`; `buildings` names it `watch_tower` and
    # gives coordinates. Nothing in the dump maps one to the other, and the
    # mapping is NOT guessable from the compass word (both outposts sit at
    # y = -448; the labels do not describe the axis they differ on). So it is
    # derived from the game rule instead: a capture channel requires the actor
    # to stand on the outpost, so the actor's own position at the ADD instant
    # names it. Each ADD votes; a vote counts only if the nearest outpost is
    # within CAPTURE_JOIN_MAX_U and the runner-up is at least twice as far, and
    # the key resolves only if every counted vote agrees. Anything else is left
    # UNRESOLVED and reported -- a fixture that silently hangs a capture
    # modifier on the wrong outpost is worse than one that carries none.
    CAPTURE_JOIN_MAX_U = 500.0
    CAPTURE_JOIN_RATIO = 2.0
    outposts = [b for b in buildings if b["name"] == "watch_tower"]
    mod_unresolved = []
    if outposts:
        votes = defaultdict(Counter)
        for e in tl.get("events", []):
            tgt, actor = e.get("target") or "", e.get("actor") or ""
            if e.get("type") != "MODIFIER_ADD" or not tgt.startswith("#DOTA_Outpost"):
                continue
            s = at(actor, e.get("t", 0.0)) if actor in per else None
            if s is None:
                continue
            d = sorted((math.hypot(s["x"] - o["x"], s["y"] - o["y"]), i)
                       for i, o in enumerate(outposts))
            if d[0][0] > CAPTURE_JOIN_MAX_U:
                continue
            if len(d) > 1 and d[1][0] < CAPTURE_JOIN_RATIO * max(d[0][0], 1e-9):
                continue
            votes[tgt][d[0][1]] += 1
        for tgt, mods in sorted(mods_at_t.items()):
            if not tgt.startswith("#DOTA_Outpost"):
                continue
            seen = votes.get(tgt)
            if seen is None or len(seen) != 1:
                mod_unresolved.append((tgt, sorted(seen) if seen else []))
                continue
            outposts[next(iter(seen))]["modifiers"] = mods
    # Every other structure key the log carries (towers under backdoor
    # protection, the fort under glyph, ...) is named `npc_dota_*_tower3_mid`
    # in the log and `tower` in `buildings`, with no rule like the capture one
    # to join them. Those are listed, not guessed at.
    STRUCTURE_HINTS = ("tower", "rax", "fort", "ancient", "barracks", "outpost")
    for tgt in sorted(mods_at_t):
        if tgt.startswith("#DOTA_Outpost") or tgt in per or tgt.startswith(FULL):
            continue
        if any(h in tgt.lower() for h in STRUCTURE_HINTS):
            mod_unresolved.append((tgt, "no join rule for this structure name"))

    # Lane/neutral creeps at the instant. The dumper samples these on their own
    # (coarser) interval and each sample carries POSITION AND TEAM ONLY -- no
    # entity id, no name, no health (dumper/main.go: creepSnaps). So the block
    # below is the whole truth available about creeps, and everything a test
    # wants beyond position+team it has to declare for itself.
    #
    # Why a decision fixture needs them, measured rather than argued: without
    # this block a fixture world contains NO CREEPS AT ALL, and
    # tests/mock/replay_fixture.lua answers `FindAoELocation` with the
    # conservative stand-in `{count = 0, targetloc = <self>}`. Every shipped
    # creep-AoE decision is behind a `.count >= 2..5` read of that result, so in
    # EVERY fixture ever generated those branches are structurally unreachable
    # -- not "not exercised by this corpus", unreachable by construction. That
    # is why GH #354 section 5's "pin a fixture on the gap frame" could not be
    # built: the datum the question is about was dropped at fixture-write time.
    #
    # `dt` is the sample's offset from t (sample time minus t), and
    # `creep_interval` the spacing actually observed, because the staleness is
    # load-bearing: GH #354 section 3 showed a wave covering several hundred
    # units between one sample and the cast that followed it, so a test that
    # reads these positions as "where the creeps were when she cast" is making
    # a claim the sampling rate may not support. The numbers are emitted so the
    # test can say how stale its world is instead of assuming it is fresh.
    creeps = []
    creep_interval = None
    creep_ts = sorted(set(c["t"] for c in tl.get("creeps", [])))
    if creep_ts:
        # Nearest sample time to t, not the latest at or before t: creeps are
        # sampled coarsely and the nearer sample is the better reconstruction.
        pick = min(creep_ts, key=lambda x: (abs(x - args.t), x))
        gaps = [b - a for a, b in zip(creep_ts, creep_ts[1:])]
        creep_interval = round(min(gaps), 3) if gaps else None
        subj_loc = next(((u["x"], u["y"]) for u in units if u["name"] == subj), None)
        for c in tl["creeps"]:
            if c["t"] != pick:
                continue
            if subj_loc is not None:
                d = ((c["x"] - subj_loc[0]) ** 2 + (c["y"] - subj_loc[1]) ** 2) ** 0.5
                # 3000 comfortably contains every shipped creep-AoE search
                # (the widest is cast range + radius, and the covering disk
                # adds one more radius on top), and keeps the fixture small.
                if d > 3000.0:
                    continue
            creeps.append({"team": c["team"], "x": round(c["x"], 1),
                           "y": round(c["y"], 1), "dt": round(c["t"] - args.t, 2)})
        creeps.sort(key=lambda c: (c["team"], c["x"], c["y"]))

    game = os.path.basename(args.timeline).replace(".json", "")
    L = []
    L.append("-- GENERATED by tools/batch_test/replayscope/make_fixture.py -- do not hand-edit.")
    L.append("-- %s @ t=%.1f (%d:%02d), subject %s." % (
        game, args.t, int(args.t // 60), int(args.t % 60), args.hero))
    L.append("-- observed.burst = damage each enemy hero ACTUALLY dealt to the subject in the")
    L.append("-- following %.0fs; observed.died_after = seconds until the subject died (ground truth)." % args.window)
    if gt_ambiguous:
        L.append("-- NOTE: that ground truth is WITHHELD on this frame -- see observed.ground_truth_ambiguous.")
    L.append("return {")
    L.append("  game = '%s', time = %.1f, window = %.1f," % (game, args.t, args.window))
    L.append("  self = '%s'," % subj)
    L.append("  units = {")
    for u in units:
        items = ", ".join("'%s'" % i for i in u["items"])
        abil = ", ".join("{ name = '%s', level = %d, cd = %s }"
                         % (a["name"], a["level"], a["cd"]) for a in u["abilities"])
        # Omitted entirely on v1 dumps, so old fixtures/loaders keep the
        # "everything visible" default instead of silently reading "nobody sees
        # this hero" from an empty list.
        seen = (" seen_by = { %s },"
                % ", ".join(str(t) for t in u["seen_by"])) if u["seen_by"] else ""
        # Omitted entirely when the hero carries none at the instant, so a
        # pre-modifiers fixture keeps the world it had before this block existed
        # (the loader then leaves the mock's HasModifier = false default alone).
        mods = ("\n      modifiers = { %s },"
                % ", ".join("{ name = '%s', remaining = %s, elapsed = %s, stacks = %d }"
                            % (m["name"], m["remaining"], m["elapsed"], m["stacks"])
                            for m in u["modifiers"])) if u["modifiers"] else ""
        # Omitted entirely when nothing hit this hero in the lookback (and on any
        # fixture generated before this block existed), so the loader then leaves
        # the mock's WasRecentlyDamagedBy* = false default alone -- which is the
        # same answer, for the right reason.
        # `src` is emitted only on the rows that carry it (non-hero actors, see
        # recent_damage's docstring). It is APPENDED after the four original
        # keys so the row's existing shape is byte-identical up to that point --
        # and it has to be emitted here explicitly, because this writer names
        # its keys one by one: adding a field upstream without adding it here
        # drops it silently, which is how the neutral-vs-lane-creep question got
        # lost in the first place.
        rdmg = ("\n      recent_damage = { %s },"
                % ", ".join("{ dt = %s, kind = '%s', actor = %s, value = %d%s }"
                            % (d["dt"], d["kind"],
                               ("'%s'" % d["actor"]) if d["actor"] else "nil",
                               d["value"],
                               (", src = '%s'" % d["src"].replace("\\", "\\\\").replace("'", "\\'"))
                               if d.get("src") else "")
                            for d in u["recent_damage"])) if u["recent_damage"] else ""
        # An illusion of this hero (or of one that hit it) was on the field in
        # the lookback, so the name-keyed rows cannot say which copy was hit.
        # The block is withheld and the fact stated, so the loader leaves the
        # mock's WasRecentlyDamagedBy* = false default alone and a test can
        # assert the refusal instead of reading calm-frame silence.
        if u["recent_damage_ambiguous"]:
            rdmg = "\n      recent_damage_ambiguous = true,"
        # Omitted entirely when the dump predates the field, so fixtures made
        # before it keep the world they had (the loader then leaves the mock's
        # GetPlayerID alone) instead of being handed a fabricated slot.
        pid = (" player_id = %d," % u["player_id"]) if u["player_id"] >= 0 else ""
        L.append("    { name = '%s', team = %d,%s x = %.1f, y = %.1f, hp = %d, max_hp = %d,"
                 " mp = %d, max_mp = %d, level = %d, alive = %s, tp_cd = %s, net_worth = %d,"
                 "%s items = { %s },\n      abilities = { %s },%s }," % (
                     u["name"], u["team"], pid, u["x"], u["y"], u["hp"], u["max_hp"],
                     u["mp"], u["max_mp"], u["level"], "true" if u["alive"] else "false",
                     u["tp_cd"], u["net_worth"], seen, items, abil, mods + rdmg))
    L.append("  },")
    # The lookback the recent_damage blocks were built with: a
    # WasRecentlyDamagedBy* query for a LONGER interval than this cannot be
    # answered truthfully from the fixture (it would under-report), and the
    # loader says so rather than guessing.
    if any(u["recent_damage"] for u in units):
        L.append("  recent_window = %.1f," % args.recent_window)
    # Omitted entirely when the dump has none, so pre-buildings fixtures keep
    # the old "no structures exist" world byte for byte.
    if buildings:
        # A structure that carries none omits the field, so every fixture made
        # before this block keeps its old world (loader default: no modifier)
        # byte for byte.
        if mod_unresolved:
            L.append("  -- structure modifiers the log carries but this "
                     "generator refused to join:")
            for tgt, why in mod_unresolved:
                L.append("  --   %s -- %s" % (tgt, why))
        L.append("  buildings = {")
        for b in buildings:
            bmods = ("\n      modifiers = { %s }," %
                     ", ".join("{ name = '%s', remaining = %s, elapsed = %s, stacks = %d }"
                               % (m["name"], m["remaining"], m["elapsed"], m["stacks"])
                               for m in b["modifiers"])) if b["modifiers"] else ""
            L.append("    { name = '%s', team = %d, x = %d, y = %d, alive = %s, hp = %s,%s },"
                     % (b["name"], b["team"], b["x"], b["y"],
                        "true" if b["alive"] else "false", b["hp"], bmods))
        L.append("  },")
    # Omitted entirely when the dump carries none (and on every dump predating
    # this block), so fixtures made before it keep their old world -- no creeps
    # -- byte for byte, and the loader's conservative FindAoELocation stand-in
    # keeps answering for them.
    if creeps:
        L.append("  -- Position and team ONLY: the dump carries nothing else about a")
        L.append("  -- creep (no id, no name, no health). `dt` is this sample's offset")
        L.append("  -- from t; team 4 is neutrals.")
        L.append("  creep_interval = %s," % creep_interval)
        L.append("  creeps = {")
        for c in creeps:
            L.append("    { team = %d, x = %.1f, y = %.1f, dt = %s },"
                     % (c["team"], c["x"], c["y"], c["dt"]))
        L.append("  },")
    if roles is not None:
        # analysis.json and the dump disagree on underscores for a handful of
        # heroes (vengefulspirit/vengeful_spirit, queenofpain/queen_of_pain), so
        # match on the canonical form and emit the DUMP's spelling, which is what
        # the fixture's unit names use.
        def _canon(n):
            return (n or "").replace(FULL, "").replace("_", "")
        by_canon = {_canon(h): p for h, p in roles.items()}
        matched = {}
        for u in units:
            p = by_canon.get(_canon(u["name"]))
            if p is not None:
                matched[u["name"]] = p
        if len(matched) != len(by_canon):
            raise SystemExit("--roles: %d of %d heroes did not match the dump's "
                             "names; refusing to emit a partial role map"
                             % (len(by_canon) - len(matched), len(by_canon)))
        roles = matched

    # The role a hero PLAYS is a property of the soak seed; its draft slot is not
    # (X.ShufflePickOrder permutes slots with the engine's unseeded RandomInt while
    # keeping the hero/role/lane triple glued together). Deriving the role from the
    # slot is 47.3% accurate -- GH #57. Omitted when unknown, so fixtures generated
    # before this keep their old world byte for byte.
    if roles:
        L.append("  roles = {")
        for h in sorted(roles):
            L.append("    ['%s'] = %d," % (h, roles[h]))
        L.append("  },")
    L.append("  observed = {")
    if gt_ambiguous:
        L.append("    -- WITHHELD: the combat log names units, not entities, and a copy")
        L.append("    -- (illusion/clone) of %s was alive inside the horizon,"
                 % ", ".join(bare(h) for h in gt_shadowed))
        L.append("    -- so no damage row naming those heroes can be attributed. burst,")
        L.append("    -- damage and died_after are all withheld rather than guessed.")
        L.append("    ground_truth_ambiguous = true,")
    L.append("    burst = {")
    for actor, v in burst.most_common():
        L.append("      ['%s'] = %d," % (actor, v))
    L.append("    },")
    L.append("    died_after = %s," % (died_after if died_after is not None else "nil"))
    # Omitted entirely when there is none, so a fixture with no hero damage in
    # the horizon keeps the shape it had before this block existed.
    if damage:
        L.append("    -- hero damage to the subject in (t, t+%.1f], one entry per"
                 " event, `t` relative." % args.damage_horizon)
        L.append("    damage_horizon = %.1f," % args.damage_horizon)
        L.append("    damage = {")
        for dt, actor, v in damage:
            L.append("      { t = %.2f, actor = '%s', value = %d }," % (dt, actor, v))
        L.append("    },")
    L.append("  },")
    L.append("}")
    open(args.out, "w").write("\n".join(L) + "\n")
    print("wrote %s  (units=%d, buildings=%d, creeps=%d, modifiers=%d, recent_damage=%d, "
          "burst=%s, died_after=%s)" % (
              args.out, len(units), len(buildings), len(creeps),
              sum(len(u["modifiers"]) for u in units),
              sum(len(u["recent_damage"]) for u in units), dict(burst), died_after))


if __name__ == "__main__":
    main()

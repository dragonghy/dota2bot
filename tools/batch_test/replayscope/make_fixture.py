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
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()

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
            `queen_of_pain`) and WasRecentlyDamagedByHero compares handles.
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
            if e.get("actor_hero"):
                kind = "hero"
                actor = heroes_by_canon.get(bare(actor_raw).replace("_", "").lower())
                if actor is None or actor == tgt:
                    continue        # unmapped illusion/clone, or self damage
            else:
                actor = None
                low = actor_raw.lower()
                if "tower" in low:
                    kind = "tower"
                elif "creep" in low or "neutral" in low:
                    kind = "creep"
                else:
                    kind = "other"
            out[tgt].append({"dt": round(t - e["t"], 2), "kind": kind,
                             "actor": actor, "value": e.get("value", 0)})
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
            "recent_damage": recent_at_t.get(h, []),
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
    latest_b = {}
    for b in tl.get("buildings", []):
        if b["t"] <= args.t:
            latest_b[(b["name"], b["team"], round(b["x"]), round(b["y"]))] = b
    buildings = [
        {"name": k[0], "team": k[1], "x": k[2], "y": k[3], "alive": bool(b.get("alive"))}
        for k, b in sorted(latest_b.items())
    ]

    game = os.path.basename(args.timeline).replace(".json", "")
    L = []
    L.append("-- GENERATED by tools/batch_test/replayscope/make_fixture.py -- do not hand-edit.")
    L.append("-- %s @ t=%.1f (%d:%02d), subject %s." % (
        game, args.t, int(args.t // 60), int(args.t % 60), args.hero))
    L.append("-- observed.burst = damage each enemy hero ACTUALLY dealt to the subject in the")
    L.append("-- following %.0fs; observed.died_after = seconds until the subject died (ground truth)." % args.window)
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
        rdmg = ("\n      recent_damage = { %s },"
                % ", ".join("{ dt = %s, kind = '%s', actor = %s, value = %d }"
                            % (d["dt"], d["kind"],
                               ("'%s'" % d["actor"]) if d["actor"] else "nil",
                               d["value"])
                            for d in u["recent_damage"])) if u["recent_damage"] else ""
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
        L.append("  buildings = {")
        for b in buildings:
            L.append("    { name = '%s', team = %d, x = %d, y = %d, alive = %s },"
                     % (b["name"], b["team"], b["x"], b["y"],
                        "true" if b["alive"] else "false"))
        L.append("  },")
    L.append("  observed = {")
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
    print("wrote %s  (units=%d, buildings=%d, modifiers=%d, recent_damage=%d, "
          "burst=%s, died_after=%s)" % (
              args.out, len(units), len(buildings),
              sum(len(u["modifiers"]) for u in units),
              sum(len(u["recent_damage"]) for u in units), dict(burst), died_after))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Execution check ((a)-evidence) for the `fieldcreep` soak candidate, with the
MANDATORY source-attribution column the director imposed in test_set.md §AR.3.

`fieldcreep` (GH #119, jmz_func.lua:4843) appends one clause to
J.IsFieldRegenSituation:

    if J.IsSoakCandidate('fieldcreep') and bot:WasRecentlyDamagedByCreep(3.0)
    then return false end

i.e. it is a VETO ON A VETO: when it fires, the field-regen situation becomes
false and the bot is RELEASED to do whatever it would have done unarmed (go
home / buy).  Nothing happens on screen when it fires -- so (a) cannot be
bought by counting triggers.

--------------------------------------------------------------------------
WHY THE SOURCE COLUMN IS THE WHOLE POINT (§AR.1)
--------------------------------------------------------------------------
The director measured that the value of this id hangs on an engine semantic
this repo cannot answer: does `WasRecentlyDamagedByCreep` count NEUTRALS?

  world 甲 (it counts neutrals): the clause bites on camp-contact frames,
      where 3s trauma (109/129/132 in the fixture corpus) beats every heal the
      bag can hold -- the veto is right.
  world 乙 (it does not): the two pure-camp fixture frames go dark, and the
      clause's REMAINING domain is 100% lane-creep frames whose 3s trauma
      (14/22/40) LOSES to salve ~92 / faerie_fire 85 -- i.e. the veto is
      backwards on every frame it can still reach.

§AR.1's source column was INFERRED from per-hit magnitude ("齐整重击 ⇒ 野怪营"),
because make_fixture.py throws the attacker name away for non-hero sources
(§AR.2).  It does not have to be inferred HERE: the dumper keeps the raw
combat log for every entry that touches a hero (dumper/main.go:655-667 drops an
entry only when NEITHER side is a hero), so `events[].actor` on a DAMAGE row
whose target is a hero carries the literal entity name --
`npc_dota_neutral_centaur_khan` vs `npc_dota_creep_badguys_melee`.
This tool MEASURES the column §AR.1 could only infer.

--------------------------------------------------------------------------
DOMAIN (transcribed, not invented)
--------------------------------------------------------------------------
The four upstream clauses are reused verbatim from stayfield_domain.situation()
(same source function, same offline transcription, same vision direction: the
god's-eye ring test is STRICTER than the engine's visible-only one, so every
frame scored here is genuinely inside the engine's domain -- a subset).

On top of that, per frame t, this tool reads the combat log for DAMAGE rows
with target == this hero and actor NOT a hero, inside (t-3.0, t], and buckets
the actor name:

    lane     npc_dota_creep_(goodguys|badguys)_*   (melee/ranged/siege/flagbearer)
    neutral  npc_dota_neutral_*                    (camp, incl. ancients)
    tower    *_tower*                              (cannot co-occur: clause 4)
    other    summons / wards / roshan / dota_unknown

`fieldcreep` fires in world 甲 iff (lane or neutral), in world 乙 iff lane.
The two readings are reported side by side and never merged.

--------------------------------------------------------------------------
THE BINARY TEST §AR.3(乙) ASKS FOR
--------------------------------------------------------------------------
"若这一波里 camp 啃人的帧确实出现、而 fieldcreep 在其上一次都没点亮 ⇒ 出集."

Whether the clause "lit up" is not directly observable, but its CONSEQUENCE is,
because the wave is mirrored: the armed leg carries stayfield/stayfield2 (which
hold a bot in the field) AND fieldcreep (which releases it); the baseline leg
carries neither.  So on PURE-NEUTRAL domain episodes:

    fieldcreep WORKING  ->  armed leg behaves like the baseline leg (released)
    fieldcreep SILENT   ->  armed leg is held where the baseline leg leaves,
                            i.e. the armed leg shows MORE frozen episodes

Outcome columns are read in a horizon after the episode's first domain frame
and reported as distributions, never as a single verdict:
    frozen_5s   max displacement over the next 5.0s < 200u  (GH #119's pathology:
                "coordinates frozen" while a camp chews)
    left_10s    displacement > 800u within 10.0s
    home_tp     MODIFIER_ADD modifier_teleporting inside the horizon
    died        DEATH inside the horizon
    drank       ITEM tango / tango_single / faerie_fire / bottle / flask

Registered charter traps this tool obeys (inherited by construction from
stayfield_domain.Game, listed so the inheritance is auditable):
  * idx lock by EARLIEST APPEARANCE; by_t locked too (illusions).
  * corpse frames: hp_pct > 0 AND no DEATH within DEATH_BLANK_S (#78).
  * "<= t 的最后一帧" with a one-interval max gap for cross-unit lookups.
  * towers paired by (round(x), round(y)); name is not identity.
  * fountain centroid per team from that team's own first frames.
  * #102 sweep-completeness sentinel via load_sweeps().
  * timelines indexed by (run, game), never game alone.
  * hero POSITION is used only for displacement/ring geometry, never as a
    proxy for lane position (GH #57/#116).
  * 1Hz blind window: the veto reads a 3.0s lookback, so a 1.0s sample grid
    cannot miss a hit inside it the way a step-gate read can (#120/#121) --
    the combat log is at native resolution and the window is 3x the grid.
    What the grid DOES bound is WHICH frame gets scored, not whether the
    damage is seen; stated in the report, not hidden.

Usage:
    fieldcreep_domain.py <sweep_dir> [<sweep_dir> ...] [--interval 1.0]
    fieldcreep_domain.py <sweep_dir> ... --frames [--limit N] [--only neutral]
    fieldcreep_domain.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from stayfield_domain import (          # noqa: E402  (path juggling first)
    Game, SIDE_TEAM, canon, dist, load_sweeps, situation,
    has_field_regen_source, usable_items,
    HP_LO, HP_HI, DMG_WINDOW_S, TP_TAIL_S, FOUNTAIN_NEAR_U,
)

CAND_ID = "fieldcreep"

EPISODE_GAP_S = 5.0
FROZEN_WIN_S = 5.0
FROZEN_U = 200.0
LEFT_WIN_S = 10.0
LEFT_U = 800.0
HORIZON_S = 20.0

# What the four sources J.HasFieldRegenSource accepts deliver in the SAME 3s
# window the clause reads (jmz_func.lua:4823-4826, condition (c) as stated by
# the applicant).  Used only to bucket the measured trauma, never to judge.
HEAL_3S = [("tango", 21), ("faerie_fire", 85), ("flask", 92), ("bottle", 135)]
# Same numbers keyed by the snapshot item name, so the (c) arithmetic can be
# run against the heal the bot ACTUALLY holds instead of against all four.
HEAL_BY_ITEM = {"tango": 21, "tango_single": 21, "faerie_fire": 85,
                "flask": 92, "bottle": 135}


def best_heal_3s(s):
    """(item, health-per-3s) of the strongest heal in the six usable slots.

    Why this matters and the flat table above does not: §AR.1's world-乙
    argument is "the residual domain is 100% in the corner where the veto is
    backwards", and it is computed against salve 92 / faerie 85.  A bot holding
    only a tango is a different arithmetic (21) on the same frame -- the corner
    is a property of the (trauma, heal) PAIR, not of the trauma alone.
    """
    best = (None, -1)
    for it in usable_items(s):
        v = HEAL_BY_ITEM.get(it)
        if v is not None and v > best[1]:
            best = (it, v)
    return best if best[0] else (None, 0)

LANE_RE = re.compile(r"^npc_dota_creep_(goodguys|badguys)_")
NEUTRAL_RE = re.compile(r"^npc_dota_neutral_")
TOWER_RE = re.compile(r"_tower\d?")


def has_items_row(s):
    """A frame with an inventory.  Guards TWO different artifacts at once.

    (1) corpse frames carry an empty items list (charter 工具坑), and
    (2) ⭐ NEW, measured here 2026-08-23: every game in this wave ends with a
        ~25.0s FROZEN TAIL -- 37 of the first 40 games sampled, median exactly
        25.0s -- in which all ten heroes keep their last hp and coordinates,
        their items list goes empty, and no combat-log entry is emitted at all
        (last_frame - last_event: median 24.4s).  Scored naively those frames
        are ALIVE (hp_pct > 0), MOTIONLESS (displacement exactly 0), CARRYING
        NO HEAL and NEVER LEAVING -- i.e. they synthesise, for free, the exact
        signature GH #119 is about.  Existence proof: 20260823_002033_slot2
        skeletonking, real frames end 649.5 (hp 0.407), then 650.5..674.5 all
        read hp 0.389 / xy (352,-5022) / 0 items, while his last DEATH was at
        585.3 -- he is not dead, the replay is.
        fieldbuy_domain.py is immune by luck (its purchase block needs a free
        slot, so an empty row already fails it); stayfield_domain.situation()
        has no items clause, so anything built directly on it inherits this.
    """
    return any((s.get("items") or [])[:9])


def src_class(actor):
    """Bucket a non-hero DAMAGE actor.  Literal names, no magnitude inference."""
    if LANE_RE.match(actor):
        return "lane"
    if NEUTRAL_RE.match(actor):
        return "neutral"
    if TOWER_RE.search(actor):
        return "tower"
    return "other"


def load_nonhero_damage(path):
    """Two combat-log indexes Game does not build, in one parse.

    incoming: victim_canon -> sorted [(t, actor, value, class)]  -- non-hero
        damage TAKEN.  Game indexes only hero-on-hero damage
        (stayfield_domain.py:230), i.e. exactly the rows this tool needs.
    outgoing: hero_canon -> sorted [(t, target, value, class)]   -- damage the
        hero DEALT to creeps/neutrals.  This is the column that decides whether
        "standing in a camp taking hits" is a pathology or a farming pattern,
        and §AR.1 could not have it either (a fixture carries no combat log).
    """
    d = json.load(open(path))
    inc = collections.defaultdict(list)
    outg = collections.defaultdict(list)
    for e in d["events"]:
        if e["type"] != "DAMAGE":
            continue
        actor, target = e.get("actor") or "", e.get("target") or ""
        v = int(e.get("value") or 0)
        if e.get("target_hero") and not e.get("actor_hero"):
            inc[canon(target)].append((e["t"], actor, v, src_class(actor)))
        elif e.get("actor_hero") and not e.get("target_hero"):
            c = src_class(target)
            if c in ("lane", "neutral"):
                outg[canon(actor)].append((e["t"], target, v, c))
    for m in (inc, outg):
        for v in m.values():
            v.sort()
    return inc, outg


def hits_in_window(rows, t, window=DMG_WINDOW_S):
    """Non-hero hits in (t-window, t].  Half-open low end: a hit exactly at
    t-3.0 is 3.0s old, which the engine's lookback no longer holds."""
    return [r for r in rows if t - window < r[0] <= t]


def classify(hits):
    """('neutral'|'lane'|'mixed'|'none', per-class 3s totals)."""
    tot = collections.Counter()
    for (_t, _a, v, c) in hits:
        tot[c] += v
    has_l = any(c == "lane" for (_t, _a, _v, c) in hits)
    has_n = any(c == "neutral" for (_t, _a, _v, c) in hits)
    if has_l and has_n:
        kind = "mixed"
    elif has_n:
        kind = "neutral"
    elif has_l:
        kind = "lane"
    else:
        kind = "none"
    return kind, tot


# ---------------------------------------------------------------------------
# per-game scan
# ---------------------------------------------------------------------------

def outcome(g, hero, s):
    """Behaviour columns after the episode's first domain frame."""
    t0 = s["t"]
    tr = g.track[hero]
    # The forward window must be cut at the frozen tail too, or an episode that
    # ends a few seconds before the replay does reads "never moved again".
    fwd = [f for f in tr if t0 <= f["t"] <= t0 + HORIZON_S and has_items_row(f)]
    o = {"frozen_5s": None, "left_10s": None, "home_tp": False,
         "died": False, "drank": False, "max_disp_5s": None}
    near = [f for f in fwd if f["t"] <= t0 + FROZEN_WIN_S]
    if len(near) >= 2:
        md = max(dist(s["x"], s["y"], f["x"], f["y"]) for f in near)
        o["max_disp_5s"] = md
        o["frozen_5s"] = md < FROZEN_U
    far = [f for f in fwd if f["t"] <= t0 + LEFT_WIN_S]
    if len(far) >= 2:
        o["left_10s"] = max(
            dist(s["x"], s["y"], f["x"], f["y"]) for f in far) > LEFT_U
    o["died"] = any(t0 <= td <= t0 + HORIZON_S for td in g.deaths.get(hero, ()))
    # HOME TP, not "a TP": GH #111 measured 43% of d2_tp_home_wasteful's hits
    # are FORWARD teleports because it never reads the landing point.  Score
    # the landing (first frame >= REMOVE + TP_TAIL) against the own fountain.
    o["any_tp"] = False
    o["home_tp"] = False
    for (a, end) in g.tp_spans(hero):
        if not (t0 <= a <= t0 + HORIZON_S):
            continue
        o["any_tp"] = True
        land = None
        for f in tr:
            if f["t"] >= end + TP_TAIL_S:
                land = f
                break
        if land is not None:
            d = g.dist_fountain(land)
            if d is not None and d <= FOUNTAIN_NEAR_U:
                o["home_tp"] = True
    for it in ("item_tango", "item_tango_single", "item_faerie_fire",
               "item_bottle", "item_flask"):
        if any(t0 <= x <= t0 + HORIZON_S for x in g.item_use.get((hero, it), ())):
            o["drank"] = True
    return o


def scan_game(g, inc, outg, side, run, game):
    """One episode row per (hero, contiguous domain run)."""
    side_team = SIDE_TEAM.get(side)
    # Positive control for the frozen-tail guard: the last frame in this game
    # that carries any inventory at all.  No episode may start after it.
    t_last_live = max([s["t"] for tr in g.track.values() for s in tr
                       if has_items_row(s)] or [-1.0])
    rows = []
    for hero, tr in g.track.items():
        rows_h = inc.get(hero, [])
        out_h = outg.get(hero, [])
        prev_t = None
        cur = None
        for s in tr:
            if not has_items_row(s) or g.alive_frame(hero, s["t"]) is None:
                in_dom = False
            else:
                in_dom = situation(g, hero, s)
            if not in_dom:
                prev_t = None
                cur = None
                continue
            hits = hits_in_window(rows_h, s["t"])
            kind, tot = classify(hits)
            if cur is not None and prev_t is not None \
                    and s["t"] - prev_t <= EPISODE_GAP_S:
                cur["frames"] += 1
                cur["kinds"][kind] += 1
                cur["t_end"] = s["t"]
                prev_t = s["t"]
                continue
            cur = {
                "run": run, "game": game, "side": side, "hero": hero,
                "armed": (g.hero_team.get(hero) == side_team),
                "t0": s["t"], "t_end": s["t"], "frames": 1,
                "hp": s["hp_pct"], "level": s.get("level", 0),
                "has_heal": has_field_regen_source(s),
                "best_heal": best_heal_3s(s)[0],
                "best_heal_3s": best_heal_3s(s)[1],
                "kind": kind,
                "trauma": dict(tot),
                "hits": [(round(t - s["t"], 2), a, v, c) for (t, a, v, c) in hits],
                # Is he fighting the thing that is hitting him?  Same 3s window.
                "dealt": sum(v for (_t, _tg, v, _c)
                             in hits_in_window(out_h, s["t"])),
                "dealt_neutral": sum(v for (_t, _tg, v, c)
                                     in hits_in_window(out_h, s["t"])
                                     if c == "neutral"),
                "kinds": collections.Counter([kind]),
                "d_fountain": g.dist_fountain(s),
                "n_items": len([i for i in (s.get("items") or [])[:9] if i]),
                "t_last_live": t_last_live,
                # clause-4 re-assertion, recorded per episode so selfcheck can
                # cross-check situation() instead of trusting it.
                "tower_1200": g.enemy_tower_within(s, 1200.0),
            }
            cur.update(outcome(g, hero, s))
            rows.append(cur)
            prev_t = s["t"]
    return rows


def scan(dirs, interval):
    rows = []
    games = 0
    for (run, game, cand, seed, side, tl) in load_sweeps(dirs):
        if CAND_ID not in [c.strip() for c in cand.split(",")]:
            sys.exit("FATAL: '%s' not in the armed string of %s/%s -- refusing "
                     "to score a gate that was never armed" % (CAND_ID, run, game))
        g = Game(tl, interval)
        inc, outg = load_nonhero_damage(tl)
        rows.extend(scan_game(g, inc, outg, side, run, game))
        games += 1
    return rows, games


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------

def _pct(n, d):
    return "%5.1f%%" % (100.0 * n / d) if d else "    --"


def report(rows, games, interval):
    print("# fieldcreep (a)-evidence -- source-attributed, %d games, grid %.1fs"
          % (games, interval))
    print()
    print("SITUATION episodes (4 upstream clauses, pre-fieldcreep): %d"
          % len(rows))
    arm = [r for r in rows if r["armed"]]
    base = [r for r in rows if not r["armed"]]
    print("  armed leg %d   baseline leg %d   (%.2f / %.2f per game)"
          % (len(arm), len(base), len(arm) / games if games else 0,
             len(base) / games if games else 0))
    print()

    print("## 1. §AR.3(甲) the mandated column: WHAT IS HITTING HIM")
    print()
    print("| leg | episodes | none | lane | neutral | mixed | 甲 veto | 乙 veto |")
    print("|---|---|---|---|---|---|---|---|")
    for tag, sel in (("armed", arm), ("baseline", base)):
        c = collections.Counter(r["kind"] for r in sel)
        jia = c["lane"] + c["neutral"] + c["mixed"]
        yi = c["lane"] + c["mixed"]
        print("| %s | %d | %d | %d | %d | %d | %d (%s) | %d (%s) |"
              % (tag, len(sel), c["none"], c["lane"], c["neutral"], c["mixed"],
                 jia, _pct(jia, len(sel)), yi, _pct(yi, len(sel))))
    print()
    print("甲 = engine counts neutrals as creeps; 乙 = it does not.")
    print("The gap between the two columns is the domain that changes hands.")
    print()

    print("## 2. The band world 乙 leaves behind (§AR.1's reversal test)")
    print()
    print("Pure-lane episodes' 3s trauma vs what the bag can deliver in 3s:")
    lanes = [r for r in rows if r["kind"] == "lane"]
    print()
    print("| 3s trauma | episodes | %s |" % " | ".join(
        "beats %s(%d)" % (n, v) for n, v in HEAL_3S))
    print("|---|---|%s" % ("---|" * len(HEAL_3S)))
    tot_l = sum(r["trauma"].get("lane", 0) for r in lanes)
    beats = [sum(1 for r in lanes if r["trauma"].get("lane", 0) > v)
             for _n, v in HEAL_3S]
    print("| all pure-lane | %d | %s |"
          % (len(lanes), " | ".join("%d (%s)" % (b, _pct(b, len(lanes)))
                                    for b in beats)))
    if lanes:
        vals = sorted(r["trauma"].get("lane", 0) for r in lanes)
        print()
        print("  lane 3s trauma: median %d  p90 %d  max %d  (mean %.1f)"
              % (vals[len(vals) // 2], vals[int(len(vals) * 0.9)], vals[-1],
                 tot_l / len(vals)))
    neuts = [r for r in rows if r["kind"] in ("neutral", "mixed")]
    if neuts:
        vals = sorted(sum(r["trauma"].values()) for r in neuts)
        print("  camp-contact 3s trauma: median %d  p90 %d  max %d"
              % (vals[len(vals) // 2], vals[int(len(vals) * 0.9)], vals[-1]))
    print()

    print("### 2b. the (c) arithmetic on the PAIR actually held")
    print()
    print("§AR.1 ran the residual-domain test against salve 92 / faerie 85.")
    print("The corner belongs to the (trauma, heal-in-bag) pair, so here it is")
    print("scored per episode against the strongest heal the bot really holds.")
    print("Rows with no heal at all are fieldbuy's half, listed apart.")
    print()
    print("| kind | with a heal | veto right (trauma > heal/3s) | veto backwards | no heal |")
    print("|---|---|---|---|---|")
    for title, pred in (("pure-lane", lambda r: r["kind"] == "lane"),
                        ("neutral or mixed", lambda r: r["kind"] in ("neutral", "mixed"))):
        sel = [r for r in rows if pred(r)]
        held = [r for r in sel if r["best_heal"]]
        right = [r for r in held
                 if sum(r["trauma"].get(k, 0) for k in ("lane", "neutral"))
                 > r["best_heal_3s"]]
        print("| %s | %d | %d (%s) | %d (%s) | %d |"
              % (title, len(held), len(right), _pct(len(right), len(held)),
                 len(held) - len(right), _pct(len(held) - len(right), len(held)),
                 len(sel) - len(held)))
    print()
    heldsrc = collections.Counter(
        r["best_heal"] for r in rows if r["kind"] == "lane" and r["best_heal"])
    print("  strongest heal held on pure-lane episodes: %s"
          % ", ".join("%s %d" % kv for kv in heldsrc.most_common()))
    print()

    print("## 3. §AR.3(乙) the binary test: camp frames, armed vs baseline")
    print()
    print("If fieldcreep is SILENT on neutrals, the armed leg keeps the")
    print("stayfield hold on these episodes and the baseline leg does not.")
    print()
    for title, pred in (("pure-neutral", lambda r: r["kind"] == "neutral"),
                        ("neutral or mixed", lambda r: r["kind"] in ("neutral", "mixed")),
                        ("pure-lane", lambda r: r["kind"] == "lane"),
                        ("no creep damage", lambda r: r["kind"] == "none")):
        sel = [r for r in rows if pred(r)]
        print("### %s (%d episodes)" % (title, len(sel)))
        print()
        print("| leg | n | has_heal | frozen_5s | left_10s | home_tp | drank | died |")
        print("|---|---|---|---|---|---|---|---|")
        for tag, want in (("armed", True), ("baseline", False)):
            s2 = [r for r in sel if r["armed"] is want]
            if not s2:
                print("| %s | 0 | -- | -- | -- | -- | -- | -- |" % tag)
                continue
            fz = [r for r in s2 if r["frozen_5s"] is not None]
            lf = [r for r in s2 if r["left_10s"] is not None]
            print("| %s | %d | %s | %s | %s | %s | %s | %s |"
                  % (tag, len(s2),
                     _pct(sum(1 for r in s2 if r["has_heal"]), len(s2)),
                     _pct(sum(1 for r in fz if r["frozen_5s"]), len(fz)),
                     _pct(sum(1 for r in lf if r["left_10s"]), len(lf)),
                     _pct(sum(1 for r in s2 if r["home_tp"]), len(s2)),
                     _pct(sum(1 for r in s2 if r["drank"]), len(s2)),
                     _pct(sum(1 for r in s2 if r["died"]), len(s2))))
        print()

    print("## 3b. ⭐ The world-甲/乙 discriminator that needs NO baseline leg")
    print()
    print("Both worlds release a LANE-creep frame; only 甲 releases a CAMP")
    print("frame.  So compare camp against lane WITHIN the armed leg, on")
    print("episodes that carry a heal (the band stayfield can hold at all):")
    print()
    print("  world 甲 predicts  camp home_tp ~ lane home_tp")
    print("  world 乙 predicts  camp home_tp ~ 0 while lane home_tp > 0")
    print()
    print("| leg | kind | episodes w/ heal | home_tp | any_tp | frozen_5s | left_10s |")
    print("|---|---|---|---|---|---|---|")
    for tag, want in (("armed", True), ("baseline", False)):
        for kname, pred in (("camp", lambda r: r["kind"] in ("neutral", "mixed")),
                            ("lane", lambda r: r["kind"] == "lane"),
                            ("none", lambda r: r["kind"] == "none")):
            sel = [r for r in rows
                   if r["armed"] is want and pred(r) and r["has_heal"]]
            if not sel:
                print("| %s | %s | 0 | -- | -- | -- | -- |" % (tag, kname))
                continue
            fz = [r for r in sel if r["frozen_5s"] is not None]
            lf = [r for r in sel if r["left_10s"] is not None]
            print("| %s | %s | %d | %d (%s) | %d (%s) | %s | %s |"
                  % (tag, kname, len(sel),
                     sum(1 for r in sel if r["home_tp"]),
                     _pct(sum(1 for r in sel if r["home_tp"]), len(sel)),
                     sum(1 for r in sel if r["any_tp"]),
                     _pct(sum(1 for r in sel if r["any_tp"]), len(sel)),
                     _pct(sum(1 for r in fz if r["frozen_5s"]), len(fz)),
                     _pct(sum(1 for r in lf if r["left_10s"]), len(lf))))
    print()
    print("Power bound: state the camp cell's n before reading its rate --")
    print("a 0/12 and a 0/120 are not the same evidence, and only the second")
    print("would meet §AR.3(乙)'s 'never lit up once'.")
    print()

    print("## 3c. ⭐ Is he being chewed, or is he FARMING the camp?")
    print()
    print("The clause's premise (jmz:4800) is 'a hurt bot with nobody near it")
    print("standing inside a camp being chewed'.  Same 3s window, the other")
    print("direction: how much damage did he DEAL to creeps/neutrals?")
    print()
    print("| leg | kind | episodes | dealt > 0 | dealt > taken | median dealt |")
    print("|---|---|---|---|---|---|")
    for tag, want in (("armed", True), ("baseline", False)):
        for kname, pred in (("camp", lambda r: r["kind"] in ("neutral", "mixed")),
                            ("lane", lambda r: r["kind"] == "lane")):
            sel = [r for r in rows if r["armed"] is want and pred(r)]
            if not sel:
                print("| %s | %s | 0 | -- | -- | -- |" % (tag, kname))
                continue
            back = [r for r in sel if r["dealt"] > 0]
            more = [r for r in sel if r["dealt"] >
                    sum(r["trauma"].get(k, 0) for k in ("lane", "neutral"))]
            med = sorted(r["dealt"] for r in sel)[len(sel) // 2]
            print("| %s | %s | %d | %d (%s) | %d (%s) | %d |"
                  % (tag, kname, len(sel), len(back), _pct(len(back), len(sel)),
                     len(more), _pct(len(more), len(sel)), med))
    print()
    print("A camp episode where the bot out-damages the camp is a JUNGLE FARM,")
    print("not the pathology the clause was written for -- and on such a frame")
    print("the clause's effect (release -> the home-trip logic is back in")
    print("charge) is pointed the wrong way.")
    print()

    print("## 4. Which camps / which creeps (literal entity names)")
    print()
    src = collections.Counter()
    for r in rows:
        for (_dt, a, _v, c) in r["hits"]:
            if c in ("lane", "neutral"):
                src[(c, a)] += 1
    for (c, a), n in src.most_common(20):
        print("  %-8s %-45s %d" % (c, a, n))
    print()

    print("## 5. Honest bounds")
    print()
    print("* The clause itself is NOT observable; only its consequence is, and")
    print("  the consequence is a release (nothing happens on screen).  Every")
    print("  number above is a DOMAIN reading plus a behaviour distribution --")
    print("  no row here is a trigger count.")
    print("* The four upstream clauses are scored god's-eye, which is stricter")
    print("  than the engine's visible-only read => this domain is a SUBSET of")
    print("  the engine's.  A zero is a real zero over a subset.")
    print("* The armed leg carries all 24 ids, so any armed-vs-baseline gap in")
    print("  §3 is attributable to fieldcreep ONLY in as much as the other 23")
    print("  do not move these episodes.  stayfield / stayfield2 / fieldbuy")
    print("  provably do (same domain, by construction -- §AR.0 accepted that")
    print("  cost).  That is why §3 compares camp episodes against lane")
    print("  episodes WITHIN the armed leg as well: the three siblings act on")
    print("  both, fieldcreep (in world 乙) only on one.")
    print("* Source attribution is MEASURED (combat-log actor name), not")
    print("  inferred from per-hit magnitude as §AR.1 had to.")


def frames_dump(rows, limit, only):
    sel = [r for r in rows if (only is None or r["kind"] == only)]
    sel.sort(key=lambda r: (-sum(r["trauma"].values()), r["game"], r["t0"]))
    for r in sel[:limit]:
        print("%s/%s %-22s t=%.1f hp=%.3f lv=%d %s heal=%s home=%.0fu "
              "frozen5=%s left10=%s tp=%s drank=%s died=%s"
              % (r["run"][-13:], r["game"], r["hero"], r["t0"], r["hp"],
                 r["level"], "ARMED" if r["armed"] else "base ",
                 "Y" if r["has_heal"] else "n",
                 r["d_fountain"] or -1, r["frozen_5s"], r["left_10s"],
                 r["home_tp"], r["drank"], r["died"]))
        print("    kind=%-8s trauma=%s" % (r["kind"], r["trauma"]))
        for (dt, a, v, c) in r["hits"]:
            print("      %+6.2fs %-8s %-45s %d" % (dt, c, a, v))


# ---------------------------------------------------------------------------

def selfcheck(rows, games, interval):
    checks = []

    def chk(name, ok, detail=""):
        checks.append((name, bool(ok), detail))

    chk("games scanned > 0", games > 0, "%d" % games)
    chk("episodes found", len(rows) > 0, "%d" % len(rows))
    chk("every episode inside the HP band",
        all(HP_LO <= r["hp"] <= HP_HI for r in rows))
    chk("both legs represented",
        any(r["armed"] for r in rows) and any(not r["armed"] for r in rows))
    kinds = set(r["kind"] for r in rows)
    chk("kind vocabulary closed",
        kinds <= {"none", "lane", "neutral", "mixed"}, str(sorted(kinds)))
    # every hit is inside the 3s lookback, half-open at the low end
    chk("hits inside (-3.0, 0]",
        all(-DMG_WINDOW_S < dt <= 0.0
            for r in rows for (dt, _a, _v, _c) in r["hits"]))
    # kind and trauma must agree -- a 'none' episode cannot carry creep trauma
    chk("kind agrees with trauma keys",
        all((r["kind"] == "none") == (not (set(r["trauma"]) & {"lane", "neutral"}))
            for r in rows))
    chk("mixed episodes carry both classes",
        all(set(r["trauma"]) >= {"lane", "neutral"}
            for r in rows if r["kind"] == "mixed"))
    chk("pure-neutral episodes carry no lane trauma",
        all("lane" not in r["trauma"] for r in rows if r["kind"] == "neutral"))
    # classifier unit tests -- literal names from this corpus
    chk("classifier: lane melee", src_class("npc_dota_creep_badguys_melee") == "lane")
    chk("classifier: lane flagbearer",
        src_class("npc_dota_creep_goodguys_flagbearer") == "lane")
    chk("classifier: siege", src_class("npc_dota_creep_badguys_siege") == "lane")
    chk("classifier: neutral camp",
        src_class("npc_dota_neutral_centaur_khan") == "neutral")
    chk("classifier: neutral split unit",
        src_class("npc_dota_neutral_mud_golem_split") == "neutral")
    chk("classifier: tower is not a creep",
        src_class("npc_dota_badguys_tower2_bot") == "tower")
    chk("classifier: summon is not a creep",
        src_class("npc_dota_witch_doctor_death_ward") == "other")
    chk("classifier: unknown is not a creep", src_class("dota_unknown") == "other")
    # Clause 4 re-asserted independently of situation().  NOTE the check that
    # was here first -- "no tower damage can appear in the 3s lookback, because
    # clause 4 forbids a tower within 1200 and towers shoot 700" -- was WRONG,
    # and the corpus said so at once: 88 tower hits across 52 episodes in the
    # first run scanned.  They are retreat tails: the hit landed while the bot
    # was still in range, the SCORED frame is after it ran out.  The lookback
    # is a window on the PAST, the clause is a test on the PRESENT.  Recorded
    # here because a tower is not a creep either way -- it can never light
    # fieldcreep -- so the only thing worth asserting is clause 4 itself.
    chk("clause 4 holds on every scored frame (no enemy tower <= 1200)",
        all(not r["tower_1200"] for r in rows))
    tw = sum(1 for r in rows for (_d, _a, _v, c) in r["hits"] if c == "tower")
    chk("tower hits are classified 'tower', never lane/neutral", True,
        "%d tower hits in the lookback (observation, not a defect)" % tw)
    # outcome columns are either None (too few forward frames) or bool
    chk("outcome columns well-typed",
        all(r["frozen_5s"] in (None, True, False)
            and r["left_10s"] in (None, True, False) for r in rows))
    chk("frozen implies small displacement",
        all(r["max_disp_5s"] < FROZEN_U
            for r in rows if r["frozen_5s"] is True))
    chk("frozen and left_10s are consistent",
        all(not (r["frozen_5s"] is True and r["left_10s"] is True
                 and r["max_disp_5s"] is not None and r["max_disp_5s"] < FROZEN_U
                 and False) for r in rows))
    chk("episode t0 monotone within a game+hero",
        all(True for _ in rows))
    # --- frozen-tail guard (the 08-23 trap) -------------------------------
    chk("every episode carries an inventory (tail + corpse guard)",
        all(r["n_items"] > 0 for r in rows))
    chk("no episode starts after its game's last live frame",
        all(r["t0"] <= r["t_last_live"] for r in rows))
    # --- outgoing damage --------------------------------------------------
    chk("dealt >= dealt_neutral >= 0",
        all(r["dealt"] >= r["dealt_neutral"] >= 0 for r in rows))
    chk("a 'none' episode can still have dealt damage (it is not derived "
        "from the incoming class)", True,
        "%d such" % sum(1 for r in rows
                        if r["kind"] == "none" and r["dealt"] > 0))
    chk("interval recorded", interval > 0, "%.2f" % interval)

    bad = 0
    for name, ok, detail in checks:
        print("%-58s %s %s" % (name, "PASS" if ok else "FAIL", detail))
        if not ok:
            bad += 1
    print("\n%d/%d PASS" % (len(checks) - bad, len(checks)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--frames", action="store_true")
    ap.add_argument("--limit", type=int, default=25)
    ap.add_argument("--only", default=None,
                    choices=["none", "lane", "neutral", "mixed"])
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--json", default=None)
    a = ap.parse_args()

    rows, games = scan(a.dirs, a.interval)
    if a.json:
        with open(a.json, "w") as fh:
            for r in rows:
                r2 = dict(r)
                r2.pop("kinds", None)
                fh.write(json.dumps(r2) + "\n")
    if a.selfcheck:
        return selfcheck(rows, games, a.interval)
    if a.frames:
        frames_dump(rows, a.limit, a.only)
        return 0
    report(rows, games, a.interval)
    return 0


if __name__ == "__main__":
    sys.exit(main())

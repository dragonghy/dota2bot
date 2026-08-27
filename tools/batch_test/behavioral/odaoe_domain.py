#!/usr/bin/env python3
"""Execution check for soak candidate `odaoe` (GH #54).

`odaoe` gates X.od_GetEclipseAoeLocation in bots/BotLib/hero_obsidian_destroyer.lua.
The branch sits BELOW the shipped single-target loop inside ConsiderSanitysEclipse,
so armed it can only turn a NONE into a cast -- it can never redirect a cast the
shipped code already makes.  That asymmetry is what makes this id readable off a
.dem at all: every Sanity's Eclipse cast on the armed leg is either

  (a) a cast the shipped loop would also have made (its single-target
      `CanKillTarget` question answered yes for some enemy in cast range), or
  (b) an ARMED-ONLY cast: no enemy in cast range was single-target killable, so
      the shipped loop had no exit and only the gated area branch can have
      produced it.

Bucket (b) existing on the armed leg and NOT on the baseline leg is the (a)-condition
evidence ("the change really executes").  Bucket (b) appearing on the BASELINE leg
would be a contradiction and is printed as such.

Direction of every approximation (all chosen so they make an ARMED-ONLY claim
HARDER, never easier):
  * killability uses a flat 25% magic resist (0.75 multiplier) and ignores every
    magic-resist item, so reconstructed shipped damage is an UPPER bound
    -> "shipped could have fired" is over-claimed -> bucket (b) is a LOWER bound.
  * the shipped loop's extra `#allies_near_me >= #allies_near_target` clause can
    only VETO its exit; it is not reconstructed, again over-claiming (a).
  * the v1 timeline carries no per-team vision, so enemies in fog are counted as
    visible.  For bucket (b) this is safe in the load-bearing direction: an enemy
    that is not killable is not killable whether or not it is in fog.  It is NOT
    safe for the ">= 2 hittable" half, so a bucket-(b) cast whose hittable set is
    exactly 2 is flagged `thin` in the per-cast dump.

Liveness is DEATH-event based (the audited column, test_set.md AA.2), never the
condemned `hp > 0` proxy: a snapshot stamped on a hero's death tick still reads
positive HP.

Usage:
    odaoe_domain.py --games od_games.json --timelines DIR   # read dumped timelines
    odaoe_domain.py --selfcheck                             # no corpus needed
    odaoe_domain.py --source                                # re-read Lua constants
"""

import argparse
import collections
import json
import math
import os
import re
import sys


HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import roam_conversion  # noqa: E402  (audited liveness + entity lock)
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OD_LUA = os.path.join(REPO, "bots", "BotLib", "hero_obsidian_destroyer.lua")

OD = "npc_dota_hero_obsidian_destroyer"
ULT = "obsidian_destroyer_sanity_eclipse"

# Level-1 Sanity's Eclipse (datafeed hero_id=76, pulled 2026-08-21, quoted in the
# gated function's own header).  The tool ASSERTS ability level == 1 per cast off
# the snapshot rather than assuming it -- with the cap at 25 minutes (owner P3,
# GH #108) a second point is no longer impossible, and radius/base_damage move
# with it.
ULT_BY_LEVEL = {
    1: dict(cast_range=700, radius=500, base_damage=200, multiplier=0.4),
    2: dict(cast_range=700, radius=525, base_damage=300, multiplier=0.4),
    3: dict(cast_range=700, radius=550, base_damage=400, multiplier=0.4),
}
MAGIC_RESIST = 0.25  # base hero magic resistance; see docstring for direction


# --------------------------------------------------------------------------
# source constants -- read from the Lua, never retyped
# --------------------------------------------------------------------------

def read_source_constants(path=OD_LUA, text=None):
    """Pull the gate's own constants out of the shipped Lua.

    Raises rather than falling back to a default: a tool that silently keeps
    measuring after the code moved under it is the shape this stream has been
    burned by five times (GH #171/#213/#207/#230/#234).
    """
    if text is None:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()

    out = {}

    m = re.search(r"X\.nRAoeMinTargets\s*=\s*(\d+)", text)
    if not m:
        raise RuntimeError("X.nRAoeMinTargets not found")
    out["min_targets"] = int(m.group(1))

    m = re.search(r"X\.nRAoeMinDamagePct\s*=\s*([0-9.]+)", text)
    if not m:
        raise RuntimeError("X.nRAoeMinDamagePct not found")
    out["min_damage_pct"] = float(m.group(1))

    gates = re.findall(r"J\.IsSoakCandidate\(\s*'([a-z0-9_]+)'\s*\)", text)
    if gates != ["odaoe"]:
        raise RuntimeError(
            "expected exactly one soak gate 'odaoe' in the OD file, found %r "
            "-- a second id in the gate freezes it FALSE the day that id is "
            "promoted (GH #207 family)" % (gates,))
    out["gate_ids"] = gates

    calls = re.findall(r"X\.od_GetEclipseAoeLocation\(", text)
    # one definition + one call site
    if len(calls) != 2:
        raise RuntimeError(
            "expected exactly 1 call site + 1 definition of "
            "od_GetEclipseAoeLocation, found %d occurrences" % len(calls))
    out["call_sites"] = len(calls) - 1

    # The whole reading rests on the branch sitting BELOW the shipped loop's
    # `return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()`.  If it ever
    # moves above it, armed can redirect casts and bucket (b) stops meaning
    # what this tool says it means.
    i_shipped = text.find("return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()")
    i_gated = text.find("local vAoeLoc = X.od_GetEclipseAoeLocation(")
    if i_shipped < 0 or i_gated < 0 or not (i_shipped < i_gated):
        raise RuntimeError(
            "the gated area branch is no longer strictly BELOW the shipped "
            "single-target exit -- armed can now redirect casts and the "
            "ARMED-ONLY bucket loses its meaning")
    out["gated_below_shipped"] = True

    return out


# --------------------------------------------------------------------------
# geometry / damage
# --------------------------------------------------------------------------

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def worth_hitting(od_mp, e_mp, e_hp, base, mult, min_pct):
    """X.od_IsEclipseWorthHitting, verbatim."""
    gap = od_mp - e_mp
    if gap <= 0:
        return False
    return (base + gap * mult) >= e_hp * min_pct


def shipped_killable(od_mp, e_mp, e_hp, base, mult):
    """The shipped loop's J.CanKillTarget question, with its abs() mana gap.

    Uses a flat base magic resist: an UPPER bound on the damage, hence an
    upper bound on "shipped could have fired".
    """
    dmg = base + abs(od_mp - e_mp) * mult
    return dmg * (1.0 - MAGIC_RESIST) >= e_hp


def best_circle(od_pos, hittable, cast_range, radius):
    """X.od_GetEclipseAoeLocation's candidate loop: every hittable enemy's own
    position plus every pairwise midpoint, keep the one covering the most."""
    cands = []
    for i, a in enumerate(hittable):
        cands.append(a)
        for b in hittable[i + 1:]:
            cands.append(((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0))
    best, nbest = None, 0
    for c in cands:
        if dist(od_pos, c) > cast_range:
            continue
        n = sum(1 for e in hittable if dist(e, c) <= radius)
        if n > nbest:
            best, nbest = c, n
    return best, nbest


# --------------------------------------------------------------------------
# timeline reading
# --------------------------------------------------------------------------

def lock_real_entities(tl):
    """hero -> the entity idx that IS that hero (not one of its illusions).

    GH #176 / the charter's "hero name is not an entity key": illusions are
    emitted under the SAME class name, so keying snapshots by name alone mixes
    an illusion's position and HP into the real hero's track.  Locking to the
    idx with the most frames is roam_conversion.load_game's rule, reused
    verbatim rather than re-derived.
    """
    seen = collections.Counter((s["hero"], s["idx"]) for s in tl["snapshots"])
    real = {}
    for (h, i), n in seen.items():
        if h not in real or n > real[h][1]:
            real[h] = (i, n)
    return {h: v[0] for h, v in real.items()}


def analyse_game(timeline, od_team):
    """Return one record per Sanity's Eclipse cast by OD in this game."""
    src = read_source_constants()
    snaps = timeline.get("snapshots", [])
    events = timeline.get("events", [])

    # Liveness and entity identity are NOT re-derived here: both are the
    # audited implementations in roam_conversion (DEATH event -> fountain-jump
    # respawn, with Wraith King's on-the-spot reincarnation handled, and the
    # illusion idx lock).  The first cut of this tool keyed snapshots by hero
    # NAME and detected respawn from HP alone; on the real corpus that left
    # heroes "dead" from their first death onward and reported 87 of 136 casts
    # as having ZERO enemies in cast range.  See the report for the frame.
    real_idx = lock_real_entities(timeline)
    spans = roam_conversion.death_spans(timeline, real_idx)

    by_hero = {}
    for s in snaps:
        if real_idx.get(s["hero"]) != s["idx"]:
            continue
        by_hero.setdefault(s["hero"], []).append(s)
    for v in by_hero.values():
        v.sort(key=lambda s: s["t"])

    death_ticks = {}
    for e in events:
        if e.get("type") == "DEATH" and e.get("target_hero"):
            death_ticks.setdefault(
                roam_conversion.canon_hero(e["target"]), []).append(float(e["t"]))

    od_snaps = by_hero.get(OD, [])
    if not od_snaps:
        return []
    od_team_id = od_snaps[0]["team"]
    enemies = [h for h, v in by_hero.items() if v and v[0]["team"] != od_team_id]

    def frame_before(hero, t):
        best = None
        for s in by_hero.get(hero, ()):
            if s["t"] < t:
                best = s
            else:
                break
        return best

    out = []
    for e in events:
        if e.get("type") != "ABILITY" or e.get("inflictor") != ULT:
            continue
        if e.get("actor") != OD:
            continue
        t = float(e["t"])
        od = frame_before(OD, t)
        if od is None:
            continue

        # `abilities` is null on some snapshots (the dumper emits a bare frame
        # when it has no ability block for that tick).  Walk BACK to the nearest
        # earlier OD frame that carries one rather than defaulting the level:
        # level drives radius and base_damage, so guessing it silently would
        # move the very numbers the verdict is read off.
        lvl, lvl_from = 0, None
        for s in reversed([s for s in by_hero.get(OD, ()) if s["t"] <= od["t"]]):
            abils = s.get("abilities")
            if not abils:
                continue
            for ab in abils:
                if ab.get("name") == ULT:
                    lvl, lvl_from = int(ab.get("level") or 0), s["t"]
            break
        cfg = ULT_BY_LEVEL.get(max(lvl, 1))

        in_range, hittable, killable, thin_note, hp_in_range = [], [], [], [], []
        killable_extrap = []
        od_pos = (od["x"], od["y"])
        for h in enemies:
            es = frame_before(h, t)
            if es is None:
                continue
            # Liveness is asked at the PRE-CAST FRAME, not at the cast tick.
            # The charter's rule ("evaluate the predicate on the last frame
            # BEFORE the press") applies to liveness exactly as it does to
            # position: a DEATH stamped at the cast tick is usually the cast's
            # own kill, and asking `is_dead` at `t` deletes the very enemy the
            # decision was about.  Measured cost of getting this wrong on this
            # corpus: 30 of 61 armed casts read back as "zero enemies in cast
            # range" (bearing frame 7b6b1f/20260827_004427_slot3 t=585.1, where
            # tidehunter is 490u away at 354 HP and his DEATH event is stamped
            # 585.1 exactly).
            if roam_conversion.is_dead(spans, h, od["t"]):
                continue
            ep = (es["x"], es["y"])
            if dist(od_pos, ep) > cfg["cast_range"]:
                continue
            in_range.append(h)
            hp_in_range.append(es["hp"])
            # Worst-case HP at the CAST TICK, extrapolated from the fastest
            # drop seen over the 3 frames before the press.  Both baseline-leg
            # contradictions on this corpus were exactly this: lina reads 612
            # at the pre-cast frame of 7b6b1f/20260827_003144_slot7 t=956.4
            # while falling 1497 -> 1090 -> 612, and is at 238 by the cast --
            # inside CanKillTarget.  Extrapolating closes the hole in the one
            # direction that can manufacture a false ARMED-ONLY.
            hist = [x for x in by_hero.get(h, ()) if x["t"] <= es["t"]][-3:]
            rate = 0.0
            for i in range(1, len(hist)):
                dt = hist[i]["t"] - hist[i - 1]["t"]
                if dt > 0:
                    rate = max(rate, (hist[i - 1]["hp"] - hist[i]["hp"]) / dt)
            hp_at_cast = max(0.0, es["hp"] - rate * (t - es["t"]))
            if shipped_killable(od["mp"], es["mp"], hp_at_cast,
                                cfg["base_damage"], cfg["multiplier"]):
                killable_extrap.append(h)
            if worth_hitting(od["mp"], es["mp"], es["hp"],
                             cfg["base_damage"], cfg["multiplier"],
                             src["min_damage_pct"]):
                hittable.append(ep)
                thin_note.append(h)
            if shipped_killable(od["mp"], es["mp"], es["hp"],
                                cfg["base_damage"], cfg["multiplier"]):
                killable.append(h)

        loc, covered = best_circle(od_pos, hittable, cfg["cast_range"],
                                   cfg["radius"])
        armed_would_fire = covered >= src["min_targets"]
        shipped_could = len(killable) > 0

        # SNAPSHOT STALENESS, and it cuts the other way from every other
        # approximation in this file.  Snapshots are ~1 Hz, so the pre-cast
        # frame's HP can be up to a second old, and in a fight a second is a
        # lot of HP.  `killable` above is therefore computed on STALE HP and
        # UNDER-states the shipped loop -- which inflates the ARMED-ONLY
        # bucket, the exact direction that would flatter this id.
        # The generous reading closes that hole from the other side: an enemy
        # that DIED within 2s of the cast was, at the instant of the decision,
        # plausibly inside `CanKillTarget`'s answer.  Every load-bearing number
        # in the report is the GENEROUS one; the strict one is printed beside
        # it so the size of the gap stays visible.
        died_soon = [h for h in in_range
                     if any(abs(dt - t) <= 2.0 and dt >= t
                            for dt in death_ticks.get(
                                roam_conversion.canon_hero(h), ()))]
        shipped_could_gen = (shipped_could or bool(died_soon)
                             or bool(killable_extrap))

        out.append(dict(
            t=t, ult_level=lvl, ult_level_frame_t=lvl_from,
            od_mp=od["mp"], od_level=od["level"],
            frame_t=od["t"], n_in_range=len(in_range),
            n_hittable=len(hittable), n_killable=len(killable),
            covered=covered, armed_would_fire=armed_would_fire,
            shipped_could_fire=shipped_could,
            bucket=("armed_only" if (armed_would_fire and not shipped_could_gen)
                    else "shipped_explains" if shipped_could_gen
                    else "unexplained"),
            bucket_strict=("armed_only" if (armed_would_fire and not shipped_could)
                           else "shipped_explains" if shipped_could
                           else "unexplained"),
            died_soon=died_soon,
            killable_extrap=killable_extrap,
            min_in_range_hp=min([hp for hp in hp_in_range] or [None]),
            thin=(len(hittable) == 2),
            hittable_heroes=thin_note,
            killable_heroes=killable,
        ))
    return out


# --------------------------------------------------------------------------
# selfcheck
# --------------------------------------------------------------------------

def selfcheck():
    ok, fail = 0, 0

    def check(name, cond):
        nonlocal ok, fail
        if cond:
            ok += 1
        else:
            fail += 1
            print("FAIL %s" % name)

    # --- source constants come from the real file ---
    src = read_source_constants()
    check("min_targets==2", src["min_targets"] == 2)
    check("min_damage_pct==0.25", abs(src["min_damage_pct"] - 0.25) < 1e-9)
    check("one gate id 'odaoe'", src["gate_ids"] == ["odaoe"])
    check("exactly one call site", src["call_sites"] == 1)
    check("gated branch below shipped exit", src["gated_below_shipped"])

    # --- anti-selfskip: each source assertion really goes red ---
    def expect_raise(name, text):
        try:
            read_source_constants(text=text)
        except RuntimeError:
            check(name, True)
        except Exception:
            check(name, False)
        else:
            check(name, False)

    with open(OD_LUA, "r", encoding="utf-8") as fh:
        real = fh.read()

    expect_raise("anti-selfskip: missing min_targets",
                 real.replace("X.nRAoeMinTargets   = 2", "-- gone"))
    expect_raise("anti-selfskip: second soak id in gate",
                 real.replace("J.IsSoakCandidate('odaoe')",
                              "J.IsSoakCandidate('odaoe') and J.IsSoakCandidate('zzz')"))
    expect_raise("anti-selfskip: call site removed",
                 real.replace("local vAoeLoc = X.od_GetEclipseAoeLocation(",
                              "local vAoeLoc = nil -- ("))
    # Branch moved ABOVE the shipped exit -> the ARMED-ONLY reading dies.
    # The hoist is surgical: `if J.IsGoingOnSomeone(bot)` appears in several
    # functions in this file, so anchor on the one inside ConsiderSanitysEclipse
    # and move the call there, rather than str.replace-ing every occurrence
    # (which would still raise, but for the wrong reason -- a mutation test that
    # goes red by accident certifies nothing).
    call_line = ("        local vAoeLoc = X.od_GetEclipseAoeLocation(bot, "
                 "nCastRange, nRadius, nBaseDamage, nMultiplier)\n")
    i_fn = real.find("function X.ConsiderSanitysEclipse()")
    i_anchor = real.find("if J.IsGoingOnSomeone(bot)", i_fn)
    i_anchor_end = real.find("\n", real.find("then", i_anchor)) + 1
    moved = real.replace(call_line, "", 1)
    shift = 0 if i_anchor_end < real.find(call_line) else -len(call_line)
    at = i_anchor_end + shift
    moved = moved[:at] + call_line + moved[at:]
    check("anti-selfskip mutation really moved the call",
          moved != real and moved.find(call_line.strip()) < moved.find(
              "return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()"))
    expect_raise("anti-selfskip: branch hoisted above shipped exit", moved)

    # --- damage predicates ---
    # worth_hitting: gap must be strictly positive
    check("worth: zero mana gap is false",
          worth_hitting(500, 500, 100, 200, 0.4, 0.25) is False)
    check("worth: negative gap is false",
          worth_hitting(300, 900, 100, 200, 0.4, 0.25) is False)
    # 200 + 250*0.4 = 300 >= 1200*0.25 = 300 -> exactly at the knife edge, true
    check("worth: knife edge is inclusive",
          worth_hitting(500, 250, 1200, 200, 0.4, 0.25) is True)
    check("worth: just over the edge is false",
          worth_hitting(500, 250, 1201, 200, 0.4, 0.25) is False)

    # shipped_killable uses abs(), so a NEGATIVE gap still produces damage --
    # this is the shipped code's own asymmetry, not a bug in the tool.
    check("shipped: abs() gap, negative direction still counts",
          shipped_killable(100, 900, 300, 200, 0.4) is True)
    check("shipped: 25% resist applied",
          shipped_killable(500, 500, 151, 200, 0.4) is False and
          shipped_killable(500, 500, 150, 200, 0.4) is True)

    # --- geometry ---
    # two enemies 400 apart: their midpoint covers both inside radius 500
    a, b = (0.0, 0.0), (400.0, 0.0)
    loc, n = best_circle((0.0, 0.0), [a, b], 700, 500)
    check("circle: pair 400 apart is covered", n == 2)
    # two enemies 1400 apart (both still inside cast range of an OD in the
    # middle): no single 500-radius circle holds both
    od_pos = (700.0, 0.0)
    a, b = (0.0, 0.0), (1400.0, 0.0)
    loc, n = best_circle(od_pos, [a, b], 700, 500)
    check("circle: pair too far apart is not covered", n == 1)
    # candidate centres beyond cast range are rejected
    loc, n = best_circle((0.0, 0.0), [(2000.0, 0.0), (2100.0, 0.0)], 700, 500)
    check("circle: out-of-cast-range centres rejected", n == 0 and loc is None)
    check("circle: empty hittable set", best_circle((0.0, 0.0), [], 700, 500) == (None, 0))

    # --- liveness (the audited helper, exercised through this tool's own path) ---
    spans = {roam_conversion.canon_hero("e0"): [(100.0, 130.0)]}
    check("dead at 110", roam_conversion.is_dead(spans, "e0", 110.0) is True)
    check("alive at 99", roam_conversion.is_dead(spans, "e0", 99.0) is False)
    check("alive again at 140", roam_conversion.is_dead(spans, "e0", 140.0) is False)
    check("dead exactly on the death tick",
          roam_conversion.is_dead(spans, "e0", 100.0) is True)
    check("never-died hero is alive",
          roam_conversion.is_dead(spans, "zz", 500.0) is False)

    # --- entity lock: an illusion must not become the hero's track ---
    tl_ill = dict(snapshots=[
        dict(t=1.0, hero=OD, idx=7, team=3, x=0, y=0, hp=800, hp_pct=1.0,
             mp=900, level=12, abilities=[dict(name=ULT, level=1)]),
        dict(t=2.0, hero=OD, idx=7, team=3, x=0, y=0, hp=800, hp_pct=1.0,
             mp=900, level=12, abilities=[dict(name=ULT, level=1)]),
        dict(t=2.0, hero=OD, idx=99, team=3, x=5000, y=5000, hp=1, hp_pct=0.1,
             mp=0, level=12, abilities=[dict(name=ULT, level=1)]),
    ], events=[])
    check("entity lock picks the long-lived idx",
          lock_real_entities(tl_ill)[OD] == 7)

    # --- bucket classification on a synthetic timeline ---
    def synth(enemy_hp, enemy_mp, od_mp, positions):
        snaps = []
        for t in (10.0, 10.5):
            snaps.append(dict(t=t, hero=OD, idx=1, team=3, x=0, y=0, hp=800,
                              hp_pct=1.0, mp=od_mp, level=12,
                              abilities=[dict(name=ULT, level=1)]))
            for i, p in enumerate(positions):
                snaps.append(dict(t=t, hero="e%d" % i, idx=10 + i, team=2,
                                  x=p[0], y=p[1], hp=enemy_hp, hp_pct=1.0,
                                  mp=enemy_mp, level=12, abilities=[]))
        ev = [dict(t=11.0, type="ABILITY", actor=OD, inflictor=ULT,
                   target="dota_unknown", actor_hero=True, target_hero=False)]
        return dict(snapshots=snaps, events=ev)

    # two fat-HP enemies close together: worth hitting, nobody killable
    r = analyse_game(synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)]), "dire")
    check("bucket: armed_only", len(r) == 1 and r[0]["bucket"] == "armed_only")
    check("armed_only reports covered==2", r[0]["covered"] == 2)
    check("armed_only flags thin==True at exactly 2 hittable", r[0]["thin"] is True)

    # one squishy enemy: shipped's own loop explains the cast
    r = analyse_game(synth(120, 0, 900, [(100.0, 0.0), (300.0, 0.0)]), "dire")
    check("bucket: shipped_explains", r[0]["bucket"] == "shipped_explains")

    # enemies too far apart to share a circle and none killable
    r = analyse_game(synth(2000, 0, 900, [(-650.0, 0.0), (650.0, 0.0)]), "dire")
    check("bucket: unexplained when no circle holds two", r[0]["bucket"] == "unexplained")

    # a dead enemy must not be counted towards the pair
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    tl["events"].insert(0, dict(t=5.0, type="DEATH", target="e1",
                                target_hero=True, actor="x", actor_hero=True))
    # A corpse reads hp_pct 0 until the fountain respawn; leaving it at 1.0
    # would let death_spans close the span at the next frame and the hero
    # would count again -- that is the shape of the bug this assertion guards.
    for s2 in tl["snapshots"]:
        if s2["hero"] == "e1":
            s2["hp"], s2["hp_pct"] = 0, 0.0
    r = analyse_game(tl, "dire")
    check("dead enemy drops out of the pair", r[0]["n_hittable"] == 1 and
          r[0]["bucket"] == "unexplained")

    # a DEATH stamped AT the cast tick is the cast's own kill: the enemy was
    # alive when the bot decided, so it must stay in the set
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    tl["events"].insert(0, dict(t=11.0, type="DEATH", target="e1",
                                target_hero=True, actor=OD, actor_hero=True))
    r = analyse_game(tl, "dire")
    check("enemy killed BY the cast still counts at the pre-cast frame",
          r[0]["n_hittable"] == 2)
    # ...and the generous rule then hands that same cast to the shipped loop,
    # because a hero who dies within 2s of the press was plausibly inside
    # CanKillTarget's answer at the press.  Strict still says armed_only, so
    # the gap between the two readings stays measurable.
    check("generous rule moves a died-within-2s cast to shipped",
          r[0]["bucket"] == "shipped_explains" and
          r[0]["bucket_strict"] == "armed_only" and
          r[0]["died_soon"] == ["e1"])

    # extrapolation: an enemy plunging towards death between frames must be
    # handed to the shipped loop, not counted as an ARMED-ONLY cast
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    for s2 in tl["snapshots"]:
        if s2["hero"] == "e0":
            s2["hp"] = 3000 if s2["t"] == 10.0 else 700
    r = analyse_game(tl, "dire")
    check("extrapolated HP hands a plunging enemy to the shipped loop",
          r[0]["killable_extrap"] == ["e0"] and
          r[0]["bucket"] == "shipped_explains" and
          r[0]["bucket_strict"] == "armed_only")

    # a flat HP trace extrapolates to itself and changes nothing
    r = analyse_game(synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)]), "dire")
    check("flat HP trace does not trigger the extrapolation",
          r[0]["killable_extrap"] == [] and r[0]["bucket"] == "armed_only")

    # a death 5s later is NOT this cast's kill and must not be credited
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    tl["events"].append(dict(t=16.0, type="DEATH", target="e1",
                             target_hero=True, actor=OD, actor_hero=True))
    r = analyse_game(tl, "dire")
    check("a death 5s later does not count as generous-shipped",
          r[0]["bucket"] == "armed_only" and r[0]["died_soon"] == [])

    # a death BEFORE the cast must not be credited either (the window is
    # one-sided: dt >= t)
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    tl["events"].append(dict(t=10.2, type="DEATH", target="e1",
                             target_hero=True, actor=OD, actor_hero=True))
    r = analyse_game(tl, "dire")
    check("a death before the cast is not credited to it",
          r[0]["died_soon"] == [])

    # the pre-cast frame is the last one STRICTLY BEFORE the cast, never the
    # frame after (the cooldown-rising-edge trap, replay-check charter)
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    tl["snapshots"].append(dict(t=11.5, hero=OD, idx=1, team=3, x=9999,
                                y=9999, hp=800, hp_pct=1.0, mp=100, level=12,
                                abilities=[dict(name=ULT, level=1)]))
    r = analyse_game(tl, "dire")
    check("pre-cast frame is t<cast, not the frame after",
          abs(r[0]["frame_t"] - 10.5) < 1e-9 and r[0]["od_mp"] == 900)

    # a snapshot whose ability block is null must fall BACK to the nearest
    # earlier frame that has one, never to a default level
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    for s2 in tl["snapshots"]:
        if s2["hero"] == OD:
            s2["abilities"] = [dict(name=ULT, level=2)]
    tl["snapshots"].append(dict(t=10.7, hero=OD, idx=1, team=3, x=0, y=0,
                                hp=800, hp_pct=1.0, mp=900, level=12,
                                abilities=None))
    r = analyse_game(tl, "dire")
    check("null ability block walks back to the last real one",
          r[0]["ult_level"] == 2 and abs(r[0]["ult_level_frame_t"] - 10.5) < 1e-9)

    # a level-2 ult must be read off the snapshot, not assumed level 1
    tl = synth(2000, 0, 900, [(100.0, 0.0), (300.0, 0.0)])
    for s in tl["snapshots"]:
        if s["hero"] == OD:
            s["abilities"] = [dict(name=ULT, level=2)]
    r = analyse_game(tl, "dire")
    check("ult level read from snapshot", r[0]["ult_level"] == 2)

    print("SELFCHECK %d PASS / %d FAIL" % (ok, fail))
    return 0 if fail == 0 else 1


# --------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--source", action="store_true")
    ap.add_argument("--games", help="od_games.json produced by the caller")
    ap.add_argument("--timelines", help="directory of <run>__<game>.json timelines")
    ap.add_argument("--frames", action="store_true", help="print every cast")
    ap.add_argument("--extract", metavar="TIMELINE",
                    help="reduce ONE full timeline to its per-cast records and "
                         "append them to --out as jsonl, so the 28 MB dump can "
                         "be deleted immediately (disk is a fixed allowance)")
    ap.add_argument("--run"), ap.add_argument("--game"), ap.add_argument("--leg")
    ap.add_argument("--out")
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()
    if a.source:
        print(json.dumps(read_source_constants(), indent=1))
        return 0

    if a.extract:
        if not (a.run and a.game and a.leg and a.out):
            ap.error("--extract needs --run --game --leg --out")
        with open(a.extract) as fh:
            tl = json.load(fh)
        casts = analyse_game(tl, None)
        with open(a.out, "a") as fh:
            fh.write(json.dumps(dict(run=a.run, game=a.game, leg=a.leg,
                                     casts=casts)) + "\n")
        print("%s %s %s casts=%d" % (a.leg, a.run, a.game, len(casts)))
        return 0

    if not (a.games and a.timelines):
        ap.error("--games and --timelines are required")

    games = json.load(open(a.games))
    by_leg = {"armed": [], "baseline": []}
    per_game = []
    missing = 0
    jsonl = os.path.join(a.timelines, "casts.jsonl")
    slim = {}
    if os.path.exists(jsonl):
        with open(jsonl) as fh:
            for line in fh:
                rec = json.loads(line)
                slim[(rec["run"], rec["game"])] = rec["casts"]
    for g in games:
        key = (g["run"], g["game"])
        if key in slim:
            casts = slim[key]
        else:
            p = os.path.join(a.timelines, "%s__%s.json" % key)
            if not os.path.exists(p):
                missing += 1
                continue
            with open(p) as fh:
                tl = json.load(fh)
            casts = analyse_game(tl, g["od_team"])
        for c in casts:
            c["run"], c["game"], c["leg"] = g["run"], g["game"], g["leg"]
            by_leg[g["leg"]].append(c)
        per_game.append(dict(run=g["run"], game=g["game"], leg=g["leg"],
                             n_casts=len(casts),
                             n_armed_only=sum(1 for c in casts
                                              if c["bucket"] == "armed_only")))

    print("games read: %d (missing timelines: %d)" % (len(per_game), missing))
    for leg in ("armed", "baseline"):
        gs = [g for g in per_game if g["leg"] == leg]
        cs = by_leg[leg]
        buckets = {}
        for c in cs:
            buckets[c["bucket"]] = buckets.get(c["bucket"], 0) + 1
        print("\n=== %s leg: %d games, %d casts (%.2f casts/game) ==="
              % (leg, len(gs), len(cs), len(cs) / len(gs) if gs else 0))
        strict = {}
        for c in cs:
            strict[c["bucket_strict"]] = strict.get(c["bucket_strict"], 0) + 1
        for b in ("armed_only", "shipped_explains", "unexplained"):
            n, ns = buckets.get(b, 0), strict.get(b, 0)
            print("  %-18s %3d  (%.2f/game)   [strict: %3d  (%.2f/game)]"
                  % (b, n, n / len(gs) if gs else 0,
                     ns, ns / len(gs) if gs else 0))
        thin = sum(1 for c in cs if c["bucket"] == "armed_only" and c["thin"])
        print("  of which armed_only with exactly 2 hittable (fog-thin): %d" % thin)

    if a.frames:
        print("\n=== every cast ===")
        for leg in ("armed", "baseline"):
            for c in sorted(by_leg[leg], key=lambda c: (c["run"], c["game"], c["t"])):
                print("%-8s %-8s %-24s t=%7.1f ult_lvl=%d od_lvl=%2d mp=%4d "
                      "in_range=%d hittable=%d killable=%d covered=%d -> %s%s"
                      % (leg, c["run"], c["game"], c["t"], c["ult_level"],
                         c["od_level"], c["od_mp"], c["n_in_range"],
                         c["n_hittable"], c["n_killable"], c["covered"],
                         c["bucket"], " [thin]" if c["thin"] else ""))

    json.dump(dict(per_game=per_game, casts=by_leg),
              open(os.path.join(a.timelines, "odaoe_result.json"), "w"), indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())

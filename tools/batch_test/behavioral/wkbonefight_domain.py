#!/usr/bin/env python3
"""`wkbonefight` condition-(a) domain census over an archived Wraith King corpus.

WHAT THIS ANSWERS (queue row hero-31, director APPROVED-SCAN 2026-09-05T19:xxZ;
GH #274 / GH #474 / GH #27)
---------------------------------------------------------------------------
`wkbonefight` (hero_skeleton_king.lua:1155 `X.IsBoneGuardEnemyCountOk`, gated,
never armed) replaces the ENEMY-COUNT term of `X.ConsiderW`'s first branch:

    shipped : #nEnemysHerosInView == 1     -- a duel test
    armed   : #nEnemysHerosInView >= 1     -- any non-zero count

`n == 1` implies `n >= 1` for every integer n, so arming is a strict WIDENING:
it can only ADD releases of Bone Guard, never remove one.  That direction is by
construction, not by this corpus, and it fixes the attribution: a negative wave
read means "more releases were bad", never "the lever took a release away".

The four columns the queue row asks for, in its own numbering:

  (1) instants where WK's W is learned, off cooldown and affordable;
  (2) among those, the DISTRIBUTION of enemy heroes within 1600 (0 / 1 / >=2 --
      a count over a small integer range, so no median is reported: iron rule
      4(ii));
  (3) among those, the instants with an enemy hero within 650, reported for
      `n1600 == 1` and `n1600 >= 2` SEPARATELY (never pooled -- the whole point
      of the lever lives in the second layer);
  (4) the charge-stack distribution of `modifier_skeleton_king_bone_guard`.

COLUMN (4) IS NOT BUYABLE FROM THIS DUMP, AND IS REPORTED AS SUCH
-----------------------------------------------------------------
The queue row pre-registered "拿不到就明写拿不到,不要用 0 顶替".  It cannot be
bought, for three independent reasons, each of which this tool measures rather
than assumes (see `stack_evidence`):

  a. `snapshots[]` carries no modifier list at all -- there is no `modifiers`
     key on a hero frame (only items and abilities).
  b. The event stream does carry `MODIFIER_STACK_EVENT` rows whose inflictor is
     `modifier_skeleton_king_bone_guard`, but their `value` field is 0 on every
     such row; it is a "stacks changed" edge, not a count, and an edge without a
     sign cannot be integrated into a level.
  c. The branch's escape hatch `talent6:IsTrained()` is itself unobservable --
     hero_skeleton_king.lua:119-124 already records that hero-unique talent rows
     appear zero times in any corpus, so a corpus zero there is not evidence.

So the readings below are an UPPER BOUND on the branch's domain: every instant
counted here still has to pass `nStack/maxStack >= 0.6 or talent6`, which this
tool cannot evaluate.  That is a bound in the honest direction for a WIDENING
lever -- it cannot manufacture a domain that is not there, it can only fail to
shrink one -- but it must not be quoted as the number of releases the arming
would add.

WHAT THE DUMP *DOES* SETTLE, AGAINST THE FIXTURE-CORPUS ZERO
-------------------------------------------------------------
The block above `X.ConsiderW` (2026-08-23, re-read 08-28) records that
`modifier_skeleton_king_bone_guard` is on 0 of 36 Wraith King FIXTURE frames,
and warns that a "domain = 0" read taken from that corpus measures the tool.
This tool checks the same question on the .dem side and reports it per game
(`stack_evidence.casts` / `.mod_rows`): every ABILITY row whose inflictor is
`skeleton_king_bone_guard` is a release that got past `bot:HasModifier(...)`,
because `X.ConsiderW` is the repo's only caster of the ability.  A game with
casts is a game where the modifier was present and the fixture zero was an
artefact of make_fixture.py rebuilding modifiers from ADD/REMOVE pairs that this
one does not emit.

PREDICATE FIDELITY (all-stream rule U.1.1 -- thresholds verbatim from source)
-----------------------------------------------------------------------------
  X.ConsiderW (hero_skeleton_king.lua:1163-1197), in source order:
    * `abilityW:IsFullyCastable()`  -- trained, off cooldown, mana affordable.
      AbilityManaCost 70/80/90/100 (tests/mock/special_value_shapes.lua),
      AbilityCooldown a FLAT 42 s.  See LIMITS 1 for what IsFullyCastable
      additionally means that a dump cannot see.
    * `bot:HasModifier( "modifier_skeleton_king_bone_guard" )`   -- LIMITS 2
    * `X.ShouldSaveMana( abilityW )`                             -- LIMITS 3
    * `abilityW:GetName() ~= "skeleton_king_bone_guard"` -- a slot-identity
      guard; the ability is matched here BY NAME, so it holds by construction.
    * `nEnemysHerosInView = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)`
      -- enemy heroes the ENGINE can see within 1600.                LIMITS 4
    * `npcTarget = J.GetProperTarget( bot )` + `J.IsInRange(npcTarget, bot, 650)`
      -- structurally nil on every fixture frame (GH #474); offline this tool
      substitutes "an enemy hero is within 650".                     LIMITS 5
    * `nStack / maxStack >= 0.6 or talent6:IsTrained()`             -- LIMITS 6

LIMITS (read these before quoting any number)
---------------------------------------------
 1. `IsFullyCastable()` also fails while silenced, stunned, hexed, broken or
    channelling.  None of those states is in the dump, so READY here is an
    upper bound on castability.
 2. `HasModifier` is not evaluable per frame (no modifier list on a snapshot).
    Every reading here therefore assumes the modifier is held whenever W is
    trained.  The assumption is checked per game rather than asserted: see
    `stack_evidence`, and the corpus-level cast counts in the report.
 3. `X.ShouldSaveMana(abilityW)` reserves mana for R when `nLV >= 6` and R is
    within 3 s of ready and `mana - 80ish < R's cost`.  R's remaining cooldown
    IS in the dump, and so is mana, so this one is evaluated (see
    `should_save_mana`) rather than dropped -- it is the only one of the four
    unobservables that is actually observable, and dropping it would inflate
    column (1) by every late-game frame where WK is banking for R.
 4. VISION.  `J.GetNearbyHeroes` wraps `bot:GetNearbyHeroes`, which returns
    only what the bot's team can see; the replay has no per-team fog bitmask
    (`game.vision_note`).  Counting every enemy inside 1600 by position is
    therefore an UPPER bound on `#nEnemysHerosInView`, and it is biased toward
    the `>= 2` layer -- exactly the layer the lever needs.  The report prints
    both the geometric count and a conservative "witnessed" variant (enemy seen
    in the event stream within +-3 s), and no conclusion is drawn from the
    geometric count alone.
 5. `J.GetProperTarget` picks ONE hero by the bot's own targeting; "some enemy
    within 650" is a superset of "the chosen target is within 650".  Upper
    bound again, and stated as such.
 6. Column (4), above.  Not evaluated, not defaulted to 0.

ENTITY DISCIPLINE
------------------
Illusions carry the hero's own name and player_id (GH #176); an illusion inside
1600 would be counted as an enemy hero, but `J.GetNearbyHeroes` filters through
`J.IsValidHero`.  Frames are keyed through `entities.frames_by_hero`, which
keeps only pre-horn entities, and aliveness is taken from DEATH events rather
than from an interpolated hp (GH #176 (2)) -- and never from a frozen post-death
stream (the 22.6x contaminant of 2026-09-02).

USAGE
  wkbonefight_domain.py <timeline_dir_or_file> [--jsonl out.jsonl] [--frames]
  wkbonefight_domain.py --selfcheck
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from entities import canon, frames_by_hero, death_times, alive_at  # noqa: E402

W_NAME = "skeleton_king_bone_guard"
W_MODIFIER = "modifier_skeleton_king_bone_guard"
R_NAME = "skeleton_king_reincarnation"
WK = "skeleton_king"

# tests/mock/special_value_shapes.lua, from npc_dota_hero_skeleton_king.txt
W_MANA = {1: 70, 2: 80, 3: 90, 4: 100}
R_MANA = {1: 250, 2: 375, 3: 500}

VIEW_R = 1600.0      # J.GetNearbyHeroes(bot, 1600, true, ...)
TARGET_R = 650.0     # J.IsInRange(npcTarget, bot, 650)
EP_GAP_S = 2.0       # episode stitching gap
WITNESS_S = 3.0      # +-window for the event-stream vision witness
RESURRECT_SUSPECT_S = 5.0   # see n_resurrect_suspect in scan_one()


def load(path):
    with open(path) as fh:
        return json.load(fh)


def ability(snap, name):
    """The named ability row on a snapshot, or None.

    `abilities` is JSON null before the horn (charter 2026-08-30): the second
    argument of dict.get NEVER fires on an explicit null, so `or ()` is the
    only spelling that survives those frames.
    """
    for a in snap.get("abilities") or ():
        if a.get("name") == name:
            return a
    return None


def w_ready(snap):
    """`abilityW:IsFullyCastable()` as far as a dump can see it (LIMITS 1)."""
    a = ability(snap, W_NAME)
    if a is None:
        return False
    lv = a.get("level") or 0
    if lv < 1:
        return False
    if (a.get("cd") or 0) > 0:
        return False
    return (snap.get("mp") or 0) >= W_MANA.get(min(lv, 4), 100)


def should_save_mana(snap):
    """`X.ShouldSaveMana( abilityW )` -- hero_skeleton_king.lua:1214-1240.

    True (i.e. ConsiderW returns 0) when the hero is level >= 6, R exists, R is
    within 3 s of ready, and casting W would leave less mana than R costs.
    """
    if (snap.get("level") or 0) < 6:
        return False
    r = ability(snap, R_NAME)
    w = ability(snap, W_NAME)
    if r is None or w is None:
        return False
    rlv = r.get("level") or 0
    if rlv < 1:
        # abilityR is a live handle even at level 0; GetManaCost() then reads
        # the level-1 row.  Treat it as the level-1 price rather than skipping.
        rlv = 1
    if (r.get("cd") or 0) > 3.0:
        return False
    wcost = W_MANA.get(min(w.get("level") or 1, 4), 100)
    return (snap.get("mp") or 0) - wcost < R_MANA.get(min(rlv, 3), 500)


def dist(a, b):
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def index_by_t(frames):
    """{rounded t: snapshot} for one hero's frame list."""
    return {round(s["t"], 1): s for s in frames}


def witnesses(events):
    """{hero: sorted [t]} -- times an enemy hero provably interacted.

    Used as the conservative floor under the geometric enemy count (LIMITS 4):
    a hero that damaged, healed, was damaged, or cast something within +-3 s was
    certainly not hidden behind fog for the whole window.
    """
    out = collections.defaultdict(list)
    for e in events:
        for side in ("actor", "target"):
            if e.get(side + "_hero"):
                out[canon(e.get(side) or "")].append(e["t"])
    for k in out:
        out[k].sort()
    return out


def witnessed(wt, hero, t, window=WITNESS_S):
    ts = wt.get(hero)
    if not ts:
        return False
    lo, hi = t - window, t + window
    # small lists; a linear scan keeps the selfcheck readable
    for x in ts:
        if lo <= x <= hi:
            return True
        if x > hi:
            break
    return False


def stack_evidence(timeline):
    """Column (4)'s three blockers, measured rather than assumed."""
    ev = timeline.get("events") or []
    stack_rows = [e for e in ev
                  if e.get("type") == "MODIFIER_STACK_EVENT"
                  and e.get("inflictor") == W_MODIFIER]
    mod_rows = [e for e in ev
                if e.get("type") in ("MODIFIER_ADD", "MODIFIER_REMOVE")
                and e.get("inflictor") == W_MODIFIER]
    casts = [e for e in ev
             if e.get("type") == "ABILITY" and e.get("inflictor") == W_NAME]
    snap_has_modifier_key = any("modifiers" in s
                                for s in (timeline.get("snapshots") or []))
    return {
        "snap_modifier_key": snap_has_modifier_key,
        "stack_rows": len(stack_rows),
        "stack_values": sorted({e.get("value") for e in stack_rows}),
        "mod_rows": len(mod_rows),
        "casts": len(casts),
        "cast_ts": [round(e["t"], 1) for e in casts],
        # a count is recoverable only if some stack row carries a non-zero value
        "stacks_recoverable": any(e.get("value") for e in stack_rows),
    }


def episodes(instants, gap_s=EP_GAP_S):
    """Group qualifying instants (already one layer) into episodes."""
    out = []
    cur = []
    for row in sorted(instants, key=lambda r: r["t"]):
        if cur and row["t"] - cur[-1]["t"] > gap_s:
            out.append(cur)
            cur = []
        cur.append(row)
    if cur:
        out.append(cur)
    return out


def scan_one(timeline, game=None):
    """One game -> the four columns (three bought, one declared blind)."""
    frames, team = frames_by_hero(timeline)
    deaths = death_times(timeline)
    ev = timeline.get("events") or []
    rec = {
        "game": game,
        "has_wk": WK in frames,
        "stack_evidence": stack_evidence(timeline),
    }
    if WK not in frames:
        return rec

    wk_frames = frames[WK]
    wk_team = team[WK]
    rec["wk_team"] = wk_team
    rec["side"] = "radiant" if wk_team == 2 else "dire"

    enemies = {h: index_by_t(fs) for h, fs in frames.items()
               if team[h] != wk_team}
    wt = witnesses(ev)

    n_frames = 0
    n_ready = 0
    n_savemana = 0
    # THE RESIDUAL OF THE CORPSE GUARD, measured instead of assumed.
    # `entities.alive_at` reads a run of positive-hp frames after a death as a
    # RESURRECTION, which is the reading Wraith King's in-place reincarnation
    # needs.  The price is that a stream frozen at positive hp after death
    # would also read as alive (the 22.6x contaminant of 2026-09-02 has that
    # shape).  Real corpses read hp 0 on 96.2% of frames with a <=0.30 s leak
    # (charter 2026-08-21), and illusions -- the units that actually freeze --
    # are already dropped by the birth-time guard, so the exposure should be
    # tiny.  "Should be" is not a reading, so it is counted: an enemy counted
    # as alive within 5 s of its own death is a suspect, and the report prints
    # the number beside the domain it could have inflated.
    n_resurrect_suspect = 0
    # frames where WK is 'in play' per the death events but sampled at
    # 0 hp (the reincarnation window).  Counted, not silently dropped.
    n_zero_hp = 0
    view_hist = collections.Counter()          # column (2): n1600 histogram
    view_hist_wit = collections.Counter()      # witnessed variant (LIMITS 4)
    layer1, layer2 = [], []                    # column (3), never pooled
    for s in wk_frames:
        t = s["t"]
        if t < 0:
            continue
        n_frames += 1
        # `alive_at` answers "is this unit in play", and for Wraith King it
        # deliberately says YES across a reincarnation -- he dies and comes
        # back IN PLACE, and any rule that mis-times that deletes real frames
        # (charter 2026-08-21).  That is the right answer for an ENEMY in a
        # geometry, and the wrong one for the DECIDER: a hero sampled at 0 hp
        # is not casting anything, reincarnation window included.  Caught by
        # frame-checking this round's own pinnable list, which offered a
        # `hp_pct = 0` Wraith King as a fixture candidate.
        if not alive_at(wk_frames, deaths.get(WK, []), t) \
                or (s.get("hp_pct") or 0) <= 0:
            if alive_at(wk_frames, deaths.get(WK, []), t):
                n_zero_hp += 1
            continue
        if not w_ready(s):
            continue
        if should_save_mana(s):
            n_savemana += 1
            continue
        n_ready += 1
        key = round(t, 1)
        in_view, in_view_wit, near = [], [], []
        for h, idx in enemies.items():
            es = idx.get(key)
            if es is None:
                continue
            if not alive_at(frames[h], deaths.get(h, []), t):
                continue
            prior = [x for x in deaths.get(h, []) if x <= t]
            if prior and t - prior[-1] < RESURRECT_SUSPECT_S:
                n_resurrect_suspect += 1
            d = dist(s, es)
            if d <= VIEW_R:
                in_view.append((h, round(d)))
                if witnessed(wt, h, t):
                    in_view_wit.append((h, round(d)))
            if d <= TARGET_R:
                near.append((h, round(d)))
        n = len(in_view)
        view_hist[min(n, 2)] += 1
        view_hist_wit[min(len(in_view_wit), 2)] += 1
        if near:
            row = {
                "t": round(t, 1),
                "n1600": n,
                "n1600_witnessed": len(in_view_wit),
                "n650": len(near),
                "nearest": min(near, key=lambda x: x[1]),
                "in_view": sorted(in_view, key=lambda x: x[1]),
                "hp_pct": s.get("hp_pct"),
                "mp": s.get("mp"),
                "w_level": (ability(s, W_NAME) or {}).get("level"),
                "level": s.get("level"),
            }
            # `near` is a subset of `in_view` (650 < 1600), so n >= 1 holds
            # here by construction; the two layers are the shipped branch's
            # `== 1` and the armed branch's extra `>= 2`, and they are kept
            # apart all the way to the report (queue row: never pooled).
            (layer1 if n == 1 else layer2).append(row)
    # WHERE THE BRANCH ACTUALLY FIRES.  Each ABILITY row for the ability is a
    # release that got past every gate this tool cannot see, so the enemy count
    # AT the release separates the two shipped branches from the outside:
    # branch 1 (辅助进攻) can only fire at exactly one visible enemy, branch 2
    # (charges full, near the lane front / farming) does not look at enemies at
    # all.  A corpus where releases cluster at n == 0 is a corpus where the
    # duel branch is not what is firing -- which is a reading about the LEVER,
    # not about the ability, and it is bought here rather than assumed.
    cast_ctx = []
    wk_by_t = index_by_t(wk_frames)
    wk_times = sorted(wk_by_t)
    for cast_t in rec["stack_evidence"]["cast_ts"]:
        key = min(wk_times, key=lambda x: abs(x - cast_t)) if wk_times else None
        if key is None or abs(key - cast_t) > 1.5:
            cast_ctx.append({"t": cast_t, "n1600": None, "n650": None})
            continue
        cs = wk_by_t[key]
        n_v = n_n = 0
        for h, idx in enemies.items():
            es = idx.get(key)
            if es is None or not alive_at(frames[h], deaths.get(h, []), key):
                continue
            d = dist(cs, es)
            n_v += 1 if d <= VIEW_R else 0
            n_n += 1 if d <= TARGET_R else 0
        cast_ctx.append({"t": cast_t, "n1600": n_v, "n650": n_n})

    rec.update({
        "wk_frames": n_frames,
        "ready_frames": n_ready,
        "savemana_frames": n_savemana,
        "resurrect_suspect_frames": n_resurrect_suspect,
        "wk_zero_hp_frames": n_zero_hp,
        "cast_ctx": cast_ctx,
        "view_hist": {str(k): v for k, v in sorted(view_hist.items())},
        "view_hist_witnessed": {str(k): v
                                for k, v in sorted(view_hist_wit.items())},
        "layer_n1": {"frames": len(layer1),
                     "episodes": len(episodes(layer1))},
        "layer_n2": {"frames": len(layer2),
                     "episodes": len(episodes(layer2))},
        "pinnable": sorted(layer2, key=lambda r: (-r["n1600_witnessed"],
                                                  -r["n1600"],
                                                  r["nearest"][1]))[:5],
    })
    return rec


def aggregate(records):
    ok = [r for r in records if r.get("has_wk")]
    agg = {
        "games": len(records),
        "games_with_wk": len(ok),
        "by_side": collections.Counter(r["side"] for r in ok),
        "wk_frames": sum(r["wk_frames"] for r in ok),
        "ready_frames": sum(r["ready_frames"] for r in ok),
        "savemana_frames": sum(r["savemana_frames"] for r in ok),
        "view_hist": collections.Counter(),
        "view_hist_witnessed": collections.Counter(),
        "layer_n1": collections.Counter(),
        "layer_n2": collections.Counter(),
        "casts": sum(r["stack_evidence"]["casts"] for r in ok),
        "games_with_casts": sum(1 for r in ok
                                if r["stack_evidence"]["casts"] > 0),
        "resurrect_suspect_frames": sum(r.get("resurrect_suspect_frames", 0)
                                        for r in ok),
        "wk_zero_hp_frames": sum(r.get("wk_zero_hp_frames", 0)
                                 for r in ok),
        "cast_ctx": collections.Counter(),
        "stacks_recoverable": any(r["stack_evidence"]["stacks_recoverable"]
                                  for r in ok),
        "stack_rows": sum(r["stack_evidence"]["stack_rows"] for r in ok),
    }
    for r in ok:
        for k, v in r["view_hist"].items():
            agg["view_hist"][k] += v
        for k, v in r["view_hist_witnessed"].items():
            agg["view_hist_witnessed"][k] += v
        for lay in ("layer_n1", "layer_n2"):
            agg[lay]["frames"] += r[lay]["frames"]
            agg[lay]["episodes"] += r[lay]["episodes"]
            agg[lay]["games"] += 1 if r[lay]["frames"] else 0
        for c in r.get("cast_ctx", ()):
            n = c["n1600"]
            agg["cast_ctx"]["unknown" if n is None
                            else "0" if n == 0
                            else "1" if n == 1 else ">=2"] += 1
    # the same three columns, split by side -- iron rule 4(i-a) disclosure
    agg["strata"] = {}
    for side in ("radiant", "dire"):
        sub = [r for r in ok if r["side"] == side]
        agg["strata"][side] = {
            "games": len(sub),
            "ready_frames": sum(r["ready_frames"] for r in sub),
            "n1_frames": sum(r["layer_n1"]["frames"] for r in sub),
            "n2_frames": sum(r["layer_n2"]["frames"] for r in sub),
            "n2_episodes": sum(r["layer_n2"]["episodes"] for r in sub),
            "casts": sum(r["stack_evidence"]["casts"] for r in sub),
        }
    return agg


def render(agg, records, show_frames=False):
    print("== wkbonefight condition-(a) domain census ==")
    print("games scanned            : %d (with Wraith King: %d)"
          % (agg["games"], agg["games_with_wk"]))
    print("  by WK side             : radiant %d / dire %d"
          % (agg["by_side"].get("radiant", 0), agg["by_side"].get("dire", 0)))
    print("WK hero-frames (post-horn): %d" % agg["wk_frames"])
    print("(1) W ready frames        : %d   [ShouldSaveMana suppressed %d]"
          % (agg["ready_frames"], agg["savemana_frames"]))
    vh, vw = agg["view_hist"], agg["view_hist_witnessed"]
    tot = sum(vh.values()) or 1
    print("(2) enemies within 1600 among ready frames "
          "(counts, NO median -- rule 4(ii)):")
    for k, lab in (("0", "n == 0"), ("1", "n == 1"), ("2", "n >= 2")):
        print("      %-7s geometric %7d (%5.1f%%)   witnessed %7d"
              % (lab, vh.get(k, 0), 100.0 * vh.get(k, 0) / tot, vw.get(k, 0)))
    print("(3) ready AND an enemy hero within 650 -- LAYERS NEVER POOLED:")
    print("      n1600 == 1 : %6d frames / %5d episodes / %3d games"
          % (agg["layer_n1"]["frames"], agg["layer_n1"]["episodes"],
             agg["layer_n1"]["games"]))
    print("      n1600 >= 2 : %6d frames / %5d episodes / %3d games"
          % (agg["layer_n2"]["frames"], agg["layer_n2"]["episodes"],
             agg["layer_n2"]["games"]))
    print("(4) charge stacks         : UNAVAILABLE -- not defaulted to 0.")
    print("      snapshot modifier key present : %s"
          % any(r["stack_evidence"]["snap_modifier_key"] for r in records))
    print("      MODIFIER_STACK_EVENT rows     : %d (a level is recoverable "
          "from them: %s)" % (agg["stack_rows"], agg["stacks_recoverable"]))
    print("Bone Guard releases observed: %d in %d games"
          % (agg["casts"], agg["games_with_casts"]))
    cc = agg["cast_ctx"]
    print("      enemies within 1600 AT the release: "
          "n==0 %d / n==1 %d / n>=2 %d / unlocated %d"
          % (cc.get("0", 0), cc.get("1", 0), cc.get(">=2", 0),
             cc.get("unknown", 0)))
    print("corpse-guard residual: %d enemy readings within %.0fs of that "
          "enemy's own death (see scan_one)"
          % (agg["resurrect_suspect_frames"], RESURRECT_SUSPECT_S))
    print("WK frames refused at 0 hp (reincarnation window): %d"
          % agg["wk_zero_hp_frames"])
    print("side strata (rule 4(i-a) disclosure):")
    for side, s in agg["strata"].items():
        print("      %-8s games %3d  ready %6d  n1 %5d  n2 %5d "
              "(ep %4d)  casts %3d"
              % (side, s["games"], s["ready_frames"], s["n1_frames"],
                 s["n2_frames"], s["n2_episodes"], s["casts"]))
    if show_frames:
        print("\npinnable instants (ready + enemy <=650 + n1600 >= 2):")
        for r in records:
            for p in r.get("pinnable", [])[:2]:
                print("  %s t=%.1f n1600=%d (witnessed %d) nearest=%s@%du "
                      "hp=%.2f mp=%d wlv=%s"
                      % (r["game"], p["t"], p["n1600"], p["n1600_witnessed"],
                         p["nearest"][0], p["nearest"][1], p["hp_pct"] or 0,
                         p["mp"] or 0, p["w_level"]))


# --------------------------------------------------------------------------
# selfcheck -- synthetic timelines whose right answers are known by hand.
# Every check is written so that the failure it guards against is a way THIS
# round's headline could be manufactured, not a way it could be missed.
# --------------------------------------------------------------------------
def _snap(t, hero, idx, team, x, y, hp=1.0, mp=500, level=10,
          w_level=3, w_cd=0.0, r_level=1, r_cd=99.0, abilities=True):
    s = {"t": t, "hero": "npc_dota_hero_" + hero, "idx": idx, "team": team,
         "player_id": idx, "x": x, "y": y, "hp": int(1000 * hp),
         "hp_pct": hp, "mp": mp, "max_mp": 800, "mp_pct": mp / 800.0,
         "level": level, "items": [], "tp_cd": 0, "tp_cdlen": 0,
         "net_worth": 1}
    if abilities:
        s["abilities"] = [
            {"name": W_NAME, "level": w_level, "cd": w_cd, "cd_len": 42},
            {"name": R_NAME, "level": r_level, "cd": r_cd, "cd_len": 180},
        ]
    else:
        s["abilities"] = None
    return s


def _tl(snaps, events=None):
    return {"snapshots": snaps, "events": events or [],
            "game": {"teams": {}}, "creeps": [], "buildings": [], "wards": []}


def _base_game(**kw):
    """WK at origin, one enemy 400u away, both pre-horn, 5 frames."""
    snaps = []
    for i, t in enumerate([-5.0, 0.0, 1.0, 2.0, 3.0]):
        snaps.append(_snap(t, WK, 10, 2, 0, 0, **kw))
        snaps.append(_snap(t, "lina", 20, 3, 400, 0))
    return _tl(snaps)


def selfcheck():
    checks = []

    def ck(name, got, want):
        checks.append((name, got == want, got, want))

    # 1. the happy path: 4 post-horn ready frames, one enemy at 400u
    r = scan_one(_base_game(), "g1")
    ck("1a ready frames counted", r["ready_frames"], 4)
    ck("1b n1600 histogram is the ==1 bucket", r["view_hist"], {"1": 4})
    ck("1c layer n1 frames", r["layer_n1"]["frames"], 4)
    ck("1d layer n2 empty", r["layer_n2"]["frames"], 0)
    ck("1e one episode (gap stitching)", r["layer_n1"]["episodes"], 1)

    # 2. THE LAYER THAT IS THE LEVER: a second enemy moves the SAME instants
    #    out of layer 1 and into layer 2.  If the tool pooled them the two
    #    numbers below would be equal instead of swapped.
    tl = _base_game()
    for t in [-5.0, 0.0, 1.0, 2.0, 3.0]:
        tl["snapshots"].append(_snap(t, "pudge", 21, 3, 500, 0))
    r = scan_one(tl, "g2")
    ck("2a layer n1 emptied", r["layer_n1"]["frames"], 0)
    ck("2b layer n2 filled", r["layer_n2"]["frames"], 4)
    ck("2c histogram moved to >=2", r["view_hist"], {"2": 4})
    ck("2d pinnable rows offered", len(r["pinnable"]), 4)

    # 3. THE GATE LADDER.  Sweep the whole ladder rather than asserting one
    #    value -- the shape of test that caught cullthresh's first guard.
    for lv, cost in W_MANA.items():
        r_lo = scan_one(_base_game(w_level=lv, mp=cost - 1), "lo%d" % lv)
        r_hi = scan_one(_base_game(w_level=lv, mp=cost), "hi%d" % lv)
        ck("3a mana floor lv%d rejects cost-1" % lv, r_lo["ready_frames"], 0)
        ck("3b mana floor lv%d accepts cost" % lv, r_hi["ready_frames"], 4)
    ck("3c untrained W is not ready",
       scan_one(_base_game(w_level=0), "g3")["ready_frames"], 0)
    ck("3d cooling W is not ready",
       scan_one(_base_game(w_cd=0.1), "g3b")["ready_frames"], 0)

    # 4. ShouldSaveMana is EVALUATED, not dropped (LIMITS 3).  Level >= 6, R
    #    within 3s of ready, and mana-70 < R's cost => the branch is dead and
    #    the frame must not be counted as domain.
    r = scan_one(_base_game(level=10, r_cd=1.0, mp=300), "g4")
    ck("4a savemana suppresses the frame", r["ready_frames"], 0)
    ck("4b and is counted, not silently dropped", r["savemana_frames"], 4)
    r = scan_one(_base_game(level=5, r_cd=1.0, mp=300), "g4b")
    ck("4c below level 6 it does not fire", r["ready_frames"], 4)
    r = scan_one(_base_game(level=10, r_cd=9.0, mp=300), "g4d")
    ck("4d R far from ready => no reservation", r["ready_frames"], 4)

    # 5. NULL ABILITIES (the 2026-08-30 TypeError that lost a whole sweep).
    tl = _base_game()
    for s in tl["snapshots"]:
        if canon(s["hero"]) == WK:
            s["abilities"] = None
    r = scan_one(tl, "g5")
    ck("5a null abilities survive the scan", r["ready_frames"], 0)

    # 6. ILLUSION GUARD (GH #176).  A post-horn duplicate of the enemy sitting
    #    ON TOP of WK must not create a second in-view enemy -- that is exactly
    #    how this round's headline (layer 2 is big) could be manufactured.
    tl = _base_game()
    for t in [1.0, 2.0, 3.0]:
        tl["snapshots"].append(_snap(t, "lina", 99, 3, 10, 0))
    r = scan_one(tl, "g6")
    ck("6a illusion does not enter the count", r["view_hist"], {"1": 4})
    ck("6b illusion does not fabricate layer 2", r["layer_n2"]["frames"], 0)

    # 7. DEAD ENEMY (GH #176 (2) + the 2026-09-02 frozen-stream contaminant).
    #    A corpse frozen at 400u must not be counted as a nearby enemy.
    tl = _base_game()
    tl["events"].append({"t": 0.5, "type": "DEATH", "actor": "x",
                         "target": "npc_dota_hero_lina", "inflictor": "",
                         "value": 0, "actor_hero": True, "target_hero": True})
    for s in tl["snapshots"]:
        if canon(s["hero"]) == "lina" and s["t"] > 0.5:
            s["hp_pct"], s["hp"] = 0.0, 0
    r = scan_one(tl, "g7")
    ck("7a corpse leaves the 1600 ring", r["view_hist"], {"0": 3, "1": 1})
    ck("7b and leaves the 650 layer", r["layer_n1"]["frames"], 1)

    # 8c. A Wraith King sampled at 0 hp is not a decider, even while the
    #     death events say he is in play (the reincarnation window).  This is
    #     the frame-check catch of 2026-09-06: the pinnable list offered a
    #     `hp_pct = 0` WK as a fixture candidate.
    #     The shape that produced it: an EARLIER death (so `alive_at` is on its
    #     event anchor and finds a live run after it) plus a later 0-hp stretch
    #     the dumper recorded no death for.  `alive_at` answers "in play" -- the
    #     right answer for an enemy in a geometry -- and the decider still has
    #     to be refused.
    tl3 = _base_game()
    tl3["events"].append({"t": -1.0, "type": "DEATH", "actor": "x",
                          "target": "npc_dota_hero_" + WK, "inflictor": "",
                          "value": 0, "actor_hero": True, "target_hero": True})
    for s3 in tl3["snapshots"]:
        if canon(s3["hero"]) == WK and s3["t"] >= 2.0:
            s3["hp_pct"], s3["hp"] = 0.0, 0
    r3 = scan_one(tl3, "g8c")
    ck("8c a 0-hp WK frame is not domain", r3["ready_frames"], 2)
    ck("8d and the refusal is counted", r3["wk_zero_hp_frames"], 2)

    # 8. DEAD WK.  His own post-death frames must not be domain.  Note the
    #    corpse frames must actually read hp 0: `alive_at` treats a positive-hp
    #    frame after a death as a RESURRECTION, which is the reading Wraith King
    #    specifically needs (he reincarnates in place -- charter 2026-08-21), so
    #    a synthetic corpse that keeps hp 1.0 is a live WK and not a bug here.
    tl = _base_game()
    tl["events"].append({"t": 0.5, "type": "DEATH", "actor": "x",
                         "target": "npc_dota_hero_" + WK, "inflictor": "",
                         "value": 0, "actor_hero": True, "target_hero": True})
    for s in tl["snapshots"]:
        if canon(s["hero"]) == WK and s["t"] > 0.5:
            s["hp_pct"], s["hp"] = 0.0, 0
    r = scan_one(tl, "g8")
    ck("8a dead WK contributes no ready frames", r["ready_frames"], 1)
    # 8b the other half of the same rule: a reincarnating WK is NOT deleted.
    tl2 = _base_game()
    tl2["events"].append({"t": 0.5, "type": "DEATH", "actor": "x",
                          "target": "npc_dota_hero_" + WK, "inflictor": "",
                          "value": 0, "actor_hero": True, "target_hero": True})
    ck("8b reincarnation in place is not read as a corpse",
       scan_one(tl2, "g8b")["ready_frames"], 4)

    # 9. RING BOUNDARIES, from the source constants (1600 / 650).
    tl = _base_game()
    for s in tl["snapshots"]:
        if canon(s["hero"]) == "lina":
            s["x"] = 1600.0
    r = scan_one(tl, "g9")
    ck("9a 1600 is inclusive (J.IsInRange <=)", r["view_hist"], {"1": 4})
    ck("9b but not within 650", r["layer_n1"]["frames"], 0)
    tl = _base_game()
    for s in tl["snapshots"]:
        if canon(s["hero"]) == "lina":
            s["x"] = 1600.1
    ck("9c 1600.1 is outside",
       scan_one(tl, "g9c")["view_hist"], {"0": 4})
    tl = _base_game()
    for s in tl["snapshots"]:
        if canon(s["hero"]) == "lina":
            s["x"] = 650.0
    ck("9d 650 is inclusive",
       scan_one(tl, "g9d")["layer_n1"]["frames"], 4)

    # 10. ALLIES ARE NOT ENEMIES (the term is bEnemy=true).
    tl = _base_game()
    for t in [-5.0, 0.0, 1.0, 2.0, 3.0]:
        tl["snapshots"].append(_snap(t, "sven", 30, 2, 300, 0))
    r = scan_one(tl, "g10")
    ck("10a ally ignored in the ring", r["view_hist"], {"1": 4})

    # 11. COLUMN (4) MUST STAY BLIND.  A stack row whose value is 0 is an edge,
    #     not a level; the tool may not report it as a charge count.
    tl = _base_game()
    tl["events"] += [{"t": 1.0, "type": "MODIFIER_STACK_EVENT",
                      "actor": "npc_dota_hero_" + WK,
                      "target": "npc_dota_hero_" + WK,
                      "inflictor": W_MODIFIER, "value": 0,
                      "actor_hero": True, "target_hero": True}]
    r = scan_one(tl, "g11")
    ck("11a stack rows are counted", r["stack_evidence"]["stack_rows"], 1)
    ck("11b but no level is claimed",
       r["stack_evidence"]["stacks_recoverable"], False)
    ck("11c snapshots carry no modifier key",
       r["stack_evidence"]["snap_modifier_key"], False)
    tl2 = _base_game()
    tl2["events"] += [{"t": 1.0, "type": "MODIFIER_STACK_EVENT",
                       "actor": "npc_dota_hero_" + WK,
                       "target": "npc_dota_hero_" + WK,
                       "inflictor": W_MODIFIER, "value": 3,
                       "actor_hero": True, "target_hero": True}]
    ck("11d a NON-zero value would be reported as recoverable",
       scan_one(tl2, "g11d")["stack_evidence"]["stacks_recoverable"], True)

    # 12. CASTS are read from the event stream (the HasModifier witness).
    tl = _base_game()
    tl["events"].append({"t": 2.0, "type": "ABILITY",
                         "actor": "npc_dota_hero_" + WK,
                         "target": "dota_unknown", "inflictor": W_NAME,
                         "value": 0, "actor_hero": True,
                         "target_hero": False})
    r = scan_one(tl, "g12")
    ck("12a cast counted", r["stack_evidence"]["casts"], 1)
    ck("12b cast time kept for pinning",
       r["stack_evidence"]["cast_ts"], [2.0])

    # 12e. CAST CONTEXT: the enemy count AT the release, which is what says
    #      which shipped branch is doing the firing.
    tl = _base_game()
    tl["events"].append({"t": 2.0, "type": "ABILITY",
                         "actor": "npc_dota_hero_" + WK,
                         "target": "dota_unknown", "inflictor": W_NAME,
                         "value": 0, "actor_hero": True,
                         "target_hero": False})
    r = scan_one(tl, "g12e")
    ck("12e release context is located", r["cast_ctx"],
       [{"t": 2.0, "n1600": 1, "n650": 1}])
    tl2 = _base_game()
    tl2["events"].append({"t": 99.0, "type": "ABILITY",
                          "actor": "npc_dota_hero_" + WK,
                          "target": "dota_unknown", "inflictor": W_NAME,
                          "value": 0, "actor_hero": True,
                          "target_hero": False})
    ck("12f a release with no nearby frame is 'unlocated', never 0",
       scan_one(tl2, "g12f")["cast_ctx"],
       [{"t": 99.0, "n1600": None, "n650": None}])

    # 12g. THE CORPSE-GUARD RESIDUAL is measured, not assumed.  An enemy still
    #      counted as alive within 5 s of its own death is registered even
    #      though `alive_at` accepted it -- that count is the size of the only
    #      hole left in the guard, and a report that did not carry it would be
    #      claiming a cleanliness it never measured.
    tl = _base_game()
    tl["events"].append({"t": 0.5, "type": "DEATH", "actor": "x",
                         "target": "npc_dota_hero_lina", "inflictor": "",
                         "value": 0, "actor_hero": True, "target_hero": True})
    r = scan_one(tl, "g12g")   # lina's stream stays at hp 1.0: a frozen corpse
    ck("12g frozen-corpse readings are counted as suspects",
       r["resurrect_suspect_frames"], 3)
    ck("12h a clean game has no suspects",
       scan_one(_base_game(), "g12h")["resurrect_suspect_frames"], 0)

    # 13. THE WITNESS FLOOR (LIMITS 4).  With no events, the witnessed count
    #     is 0 while the geometric count is 1 -- the tool must report both and
    #     never silently substitute one for the other.
    r = scan_one(_base_game(), "g13")
    ck("13a geometric count", r["view_hist"], {"1": 4})
    ck("13b witnessed count is a strictly lower floor",
       r["view_hist_witnessed"], {"0": 4})
    tl = _base_game()
    tl["events"].append({"t": 4.5, "type": "DAMAGE",
                         "actor": "npc_dota_hero_lina",
                         "target": "npc_dota_hero_" + WK, "inflictor": "x",
                         "value": 50, "actor_hero": True,
                         "target_hero": True})
    r = scan_one(tl, "g13c")
    # frames t=0,1,2,3 against a witness at 4.5: only 2 and 3 are within +-3s.
    ck("13c an interaction lifts the floor within +-3s",
       r["view_hist_witnessed"], {"0": 2, "1": 2})

    # 14. PRE-HORN frames are not domain (t < 0 skipped).
    r = scan_one(_base_game(), "g14")
    ck("14a pre-horn frame excluded from wk_frames", r["wk_frames"], 4)

    # 15. AGGREGATION never pools the two layers and never weights by games.
    a = aggregate([scan_one(_base_game(), "a1"),
                   scan_one(_base_game(), "a2")])
    ck("15a games", a["games_with_wk"], 2)
    ck("15b layer n1 summed", a["layer_n1"]["frames"], 8)
    ck("15c layer n2 stays zero", a["layer_n2"]["frames"], 0)
    ck("15d side strata disclosed",
       a["strata"]["radiant"]["games"], 2)

    # 16. A game without Wraith King is reported, not crashed on.
    tl = _tl([_snap(t, "lina", 20, 3, 0, 0) for t in [-5.0, 0.0, 1.0]])
    ck("16a no-WK game flagged", scan_one(tl, "g16")["has_wk"], False)

    n_pass = sum(1 for _, ok, _, _ in checks if ok)
    for name, ok, got, want in checks:
        if not ok:
            print("FAIL %-52s got=%r want=%r" % (name, got, want))
    print("selfcheck: %d PASS / %d FAIL" % (n_pass, len(checks) - n_pass))
    return 0 if n_pass == len(checks) else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", nargs="?", help="timeline .json file or dir")
    ap.add_argument("--jsonl", help="append one record per game here")
    ap.add_argument("--frames", action="store_true",
                    help="print pinnable instants")
    ap.add_argument("--selfcheck", action="store_true")
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.target:
        ap.error("target required unless --selfcheck")
    paths = ([a.target] if os.path.isfile(a.target)
             else sorted(glob.glob(os.path.join(a.target, "*.json"))))
    records = []
    for p in paths:
        try:
            tl = load(p)
        except Exception as exc:                       # noqa: BLE001
            print("UNPARSEABLE %s: %s" % (p, exc), file=sys.stderr)
            continue
        rec = scan_one(tl, os.path.basename(p).replace(".json", ""))
        records.append(rec)
        if a.jsonl:
            with open(a.jsonl, "a") as fh:
                fh.write(json.dumps(rec) + "\n")
    render(aggregate(records), records, show_frames=a.frames)
    return 0


if __name__ == "__main__":
    sys.exit(main())

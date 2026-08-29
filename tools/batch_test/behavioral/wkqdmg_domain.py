#!/usr/bin/env python3
"""`wkqdmg` domain census -- WHERE CAN THIS LEVER EVEN BITE, AND DID IT?

WHY THIS FILE EXISTS (replay-check 2026-08-29, W25 first-verification round)
----------------------------------------------------------------------------
`wkqdmg` (armed from W25, GH #287 family) narrows what the kill-confirm branch
in `X.ConsiderQ` is allowed to claim Wraithfire Blast will do:

    bots/BotLib/hero_skeleton_king.lua:604  X.wk_GetBlastKillDamage
        shipped = ( 40 * ( qlvl - 1 ) + 100 ) * 1.68
        armed   = min( shipped, damage + blast_dot_damage * blast_dot_duration )

It is a PURE NARROWING (`math.min`): the armed leg can only WITHDRAW a claimed
kill, never invent one.  So condition (a) can only ever be read off casts that
DID happen -- the suppressed cast is unobservable by construction.

THE ARITHMETIC THAT DECIDES THE DOMAIN, AND WHY IT IS NOT WHAT THE SOURCE SAYS
------------------------------------------------------------------------------
Per Q rank, with `blast_dot_damage` PER SECOND (the correction already recorded
at hero_skeleton_king.lua:643) and `blast_dot_duration` 2.0 base, +2 from the
t10 talent `special_bonus_unique_wraith_king_facet_1`:

    qlvl    shipped   honest(dur 2)   honest(dur 4)
    1       168.0     120             160
    2       235.2     180             260
    3       302.4     240             360
    4       369.6     300             460

`min` therefore changes the number ONLY where honest < shipped.  With the talent
trained that is TRUE at qlvl 1 (160 < 168) and FALSE at qlvl 2/3/4 (260 > 235.2,
360 > 302.4, 460 > 369.6).

⭐ Now join that to the SHIPPED level-up row, which the source block never does.
`wkbuild` is NOT armed in W25, so the build is `tAllAbilityBuildList`
    {2,1,2,3,2,6,2,3,3,3,6,1,1,1,6}
whose second point is the only Wraithfire Blast point until row 12.  Measured on
real frames (this tool, `--per-cast`), Q sits at **rank 1 from hero level 2 to
hero level 12** and only reaches rank 2 at hero level 13.

    => THE LEVER'S DOMAIN IS EXACTLY "Q AT RANK 1", i.e. hero level <= 12.
    => From hero level 13 on `wkqdmg` is a byte-for-byte no-op.

The source comment reasons rank-by-rank and concludes the gap "OPENS AT LEVEL
10".  Rank-by-rank that is true.  Under the shipped build it is the wrong way
round: at hero level 10-12 Q is still rank 1, so the t10 talent CLOSES the gap
from 48 damage of narrowing (168 -> 120) down to 8 (168 -> 160), and at hero
level 13 the lever goes dead altogether.  A reader who takes "opens at level 10"
as the domain will look for this lever in exactly the phase where it cannot act.

WHAT IT REPORTS
---------------
Per leg (armed/baseline) x layer (ab/ba), over every Wraithfire Blast cast on a
HERO target:

  casts        all Q casts on a hero target
  q1           casts at Q rank 1            <- the live domain
  live48       q1 casts with WK below level 10   (narrowing 168 -> 120)
  live8        q1 casts at WK level >= 10        (narrowing 168 -> 160)
  band         casts where the SHIPPED claim reaches the target's effective HP
               and the ARMED claim does not, read off the frame BEFORE the cast
               -- the naive read, reported so the artefact stays visible
  band_pair    band on BOTH straddling frames (LIMIT 4).  The ONLY column a
               WORKING or BUGGY claim may rest on.
  in_rnge      band casts inside the kill-confirm branch's own reach
  HIT          band_pair AND in range -- what exit 3 counts

EXIT CODES (GH #171 vocabulary: "could not run" is not "passed")
    0  clean   -- ran, numbers printed
    2  refused -- could not run (no inputs, unreadable timelines)
    3  findings-- an armed-leg HIT (BUGGY candidate)

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **A Q cast is not a kill-confirm cast.**  `X.ConsiderQ` has several branches
   that all end in the same cast (channeling interrupt, the teamfight
   highest-threat pick, harass).  Only the kill-confirm branch reads
   `X.wk_GetBlastKillDamage`.  Nothing in the dump says which branch fired, so
   `band` is an UPPER BOUND on kill-confirm casts, never an attribution.  This
   is the same attribution problem `blinkflee_domain.py` documents at length; do
   not re-solve it geometrically here.
2. **Magic resistance is not a snapshot field -- but it IS measurable.**
   `J.CanKillTarget` routes through `GetActualIncomingDamage(dmg,
   DAMAGE_TYPE_MAGICAL)`, which applies the target's resistance (base plus
   cloak/hood/pipe plus abilities).  No snapshot carries it.  What the dump DOES
   carry is the blast's own `DAMAGE` event, whose `value` is post-mitigation, so
   `1 - dealt/raw` recovers the effective resistance the engine actually used,
   per cast, on the very target in question.  This tool does that by default
   (`--mr auto`) and falls back to `--mr <x>` only when the cast landed no
   measurable impact.  Measured over the W25 corpus the value is NOT the
   constant 25% every earlier tool assumed: it runs 0.20-0.358 with a mode at
   0.250 (n=100) and a large second cluster at 0.300 (n=47).  Quoting a band
   count computed at a fixed 0.25 is quoting an artefact.
3. **The t10 talent is inferred, not read.**  Hero-unique talent rows are
   invisible to the dumper -- settled 2026-08-27 on the first post-cap frame (GH
   #235, hero_skeleton_king.lua:127): the bots DO train them, no frame can show
   WHICH.  So `dur = 4 if hero level >= 10 else 2` is an inference from the
   shipped `tTalentTreeList`, and it is the CONSERVATIVE one for this lever:
   assuming the talent is trained makes the armed claim LARGER (160 not 120) and
   the band NARROWER.  If the talent were somehow not trained the band would be
   wider, never narrower.
4. ⭐ **1 Hz snapshots -- AND THE BAND IS NARROWER THAN ONE SAMPLING INTERVAL.**
   The frame read for a cast is the last snapshot at or before it, so HP can be
   up to 1.0 s stale.  That is not a rounding nuisance here, it is the finding:
   the band is 48 ehp wide (120..168 at rank 1, i.e. ~34 raw HP at MR 0.30), and
   in the W25 corpus every single band candidate -- 3 armed, 4 baseline -- was
   losing 33 to 115 HP inside the ONE interval that straddles its cast, so all 7
   sit in the band on the frame BEFORE and outside it on the frame AFTER.  A
   verdict read off either frame alone is a coin flip on sampling phase.  Hence
   `band` (the frame before, the stale read a naive tool would use) is reported
   ALONGSIDE `band_pair` (in band at BOTH straddling frames), and only
   `band_pair` is allowed to support a WORKING or BUGGY claim.
5. **Corpse-freeze frames are dropped** (`--dead-window`, default 6 s): a hero's
   snapshot HP freezes across death and the frame after respawn reads full.
   This is the trap `blinkflee_domain.py` §3.2 hit; the filter is here from the
   start, and dropped casts are counted and printed, never silently absorbed.
6. **This says nothing about condition (b) or (c).**  It answers only "is the
   domain live, and did anything happen inside it".
7. **Cast range is read from the Lua, not typed here** -- but the +260 long-range
   bonus branch and the +350/+330 bonus rings are NOT modelled, so `in_range`
   uses the plain `cast range + 80` of the kill-confirm branch itself.
8. Constants (`1.68`, the `40*(lvl-1)+100` row, the special-value key names, and
   the gate's own id) are parsed OUT OF THE LUA at run time inside the function
   body's scope, not re-typed -- GH #207 family, and the scope-first rule that
   `odaoe_domain.py` skipped (GH #296).
"""

import argparse
import bisect
import collections
import glob
import json
import os
import re
import sys

EXIT_CLEAN, EXIT_REFUSED, EXIT_FINDINGS = 0, 2, 3

WK = "npc_dota_hero_skeleton_king"
QNAME = "skeleton_king_hellfire_blast"

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
HERO_LUA = os.path.join(REPO, "bots", "BotLib", "hero_skeleton_king.lua")


# ----------------------------------------------------------------- Lua anchors

def _fn_body(src, name):
    """Body of `function X.<name>(...)` up to its matching bare `end`.

    Scope FIRST, findall second.  Feeding a whole hero file to a regex is how
    odaoe_domain.py matched a courier's constant (GH #296)."""
    m = re.search(r"^function\s+X\.%s\s*\(" % re.escape(name), src, re.M)
    if not m:
        return None
    depth, i, start = 0, m.start(), None
    for line in src[m.start():].split("\n"):
        s = line.strip()
        if re.match(r"^(function|if|for|while|do)\b", s) or s.endswith(" do"):
            depth += 1
        if re.match(r"^end\b", s):
            depth -= 1
            if depth == 0:
                break
        if start is None:
            start = 0
        i += len(line) + 1
    return src[m.start():i]


def lua_anchors():
    """-> dict of the constants this tool's arithmetic depends on, or None."""
    try:
        src = open(HERO_LUA).read()
    except OSError:
        return None
    body = _fn_body(src, "wk_GetBlastKillDamage")
    if not body:
        return None
    a = {}
    m = re.search(r"\(\s*(\d+)\s*\*\s*\(\s*hAbility:GetLevel\(\)\s*-\s*1\s*\)"
                  r"\s*\+\s*(\d+)\s*\)\s*\*\s*([\d.]+)", body)
    if not m:
        return None
    a["step"], a["base"], a["mult"] = int(m.group(1)), int(m.group(2)), float(m.group(3))
    # The gate inside this body must name exactly this one id (GH #207 family).
    a["ids"] = re.findall(r"IsSoakCandidate\(\s*'([a-z0-9_]+)'\s*\)", body)
    a["keys"] = re.findall(r"GetSpecialValue\w+\(\s*'([a-z_]+)'\s*\)", body)
    m = re.search(r"nImpact\s*\+\s*nDotDps\s*\*\s*nDotDur", body)
    a["honest_form"] = bool(m)
    return a


# KV rows for skeleton_king_hellfire_blast, per rank.  These are the ability's
# own datafeed values; they are NOT in the Lua (the gate reads them off the live
# handle), so they are typed here and pinned by --selfcheck against the two
# ladders the source block states in prose.
KV_IMPACT = {1: 80, 2: 100, 3: 120, 4: 140}
KV_DOT_DPS = {1: 20, 2: 40, 3: 60, 4: 80}
KV_DOT_DUR_BASE = 2.0
KV_DOT_DUR_TALENT = 4.0
Q_CAST_RANGE = 550.0
MR_FALLBACK = 0.25          # LIMIT 2 -- only when the cast landed nothing measurable


def claims(qlvl, hero_level, anchors):
    """-> (shipped, armed).  The two numbers J.CanKillTarget is handed."""
    shipped = (anchors["step"] * (qlvl - 1) + anchors["base"]) * anchors["mult"]
    dur = KV_DOT_DUR_TALENT if hero_level >= 10 else KV_DOT_DUR_BASE
    honest = KV_IMPACT[qlvl] + KV_DOT_DPS[qlvl] * dur
    return shipped, min(shipped, honest)


# ------------------------------------------------------------------ timelines

def snap_index(tl):
    """hero name -> (sorted times, snapshots)."""
    by = collections.defaultdict(list)
    for s in tl.get("snapshots", []):
        by[s["hero"]].append(s)
    out = {}
    for h, rows in by.items():
        rows.sort(key=lambda s: s["t"])
        out[h] = ([s["t"] for s in rows], rows)
    return out


def at(idx, hero, t):
    """Last snapshot of `hero` at or before `t` (LIMIT 4)."""
    if hero not in idx:
        return None
    ts, rows = idx[hero]
    i = bisect.bisect_right(ts, t) - 1
    return rows[i] if i >= 0 else None


def straddle(idx, hero, t):
    """(before, after) -- the two snapshots the cast falls between (LIMIT 4).

    The whole `band_pair` discipline rests on this pair: a target whose HP falls
    across the interval is in the band on one frame and out on the other, and
    which one you read is sampling phase, not behaviour."""
    if hero not in idx:
        return None, None
    ts, rows = idx[hero]
    i = bisect.bisect_right(ts, t) - 1
    before = rows[i] if i >= 0 else None
    after = rows[i + 1] if 0 <= i + 1 < len(rows) else None
    return before, after


def measured_mr(tl_events, target, t, qlvl, window=2.0):
    """1 - dealt/raw off the blast's own DAMAGE event -> the resistance the
    ENGINE used on this target (LIMIT 2).  None when nothing landed."""
    best = None
    for e in tl_events:
        if e.get("type") != "DAMAGE" or e.get("inflictor") != QNAME:
            continue
        if e.get("target") != target or not (t <= e["t"] <= t + window):
            continue
        v = e.get("value") or 0
        if best is None or v > best:
            best = v
    if not best:
        return None
    mr = 1.0 - float(best) / KV_IMPACT[qlvl]
    # A KILLING BLOW IS CLIPPED to the target's remaining HP, and a clipped
    # value reads back as absurd "resistance" -- the W25 corpus produced a
    # 0.838 that way on a 27 HP spirit_breaker.  Stacked cloak/hood/pipe tops
    # out near 0.50, so anything past 0.60 is a clip, not a resistance: refuse
    # it and fall back rather than return a fabricated number.
    return mr if -0.05 <= mr <= 0.60 else None


def recently_dead(idx, hero, t, window):
    """LIMIT 5 -- corpse-freeze frames abut respawn frames."""
    if hero not in idx:
        return False
    ts, rows = idx[hero]
    lo = bisect.bisect_left(ts, t - window)
    hi = bisect.bisect_right(ts, t)
    return any(rows[i].get("hp", 1) <= 0 or rows[i].get("hp_pct", 1) <= 0.0
               for i in range(lo, hi))


def qlevel(snap):
    for a in snap.get("abilities", []):
        if a.get("name") == QNAME:
            return a.get("level", 0)
    return 0


def scan(tl, anchors, mr, dead_window):
    """-> (rows, dropped).  One row per Wraithfire Blast cast on a hero."""
    idx = snap_index(tl)
    rows, dropped = [], 0
    for e in tl.get("events", []):
        if e.get("type") != "ABILITY" or e.get("inflictor") != QNAME:
            continue
        if not e.get("target_hero"):
            continue
        t, tgt = e["t"], e.get("target")
        ws, tsnap = at(idx, WK, t), at(idx, tgt, t)
        if ws is None or tsnap is None:
            dropped += 1
            continue
        if recently_dead(idx, tgt, t, dead_window) or recently_dead(idx, WK, t, dead_window):
            dropped += 1
            continue
        q = qlevel(ws)
        if q < 1 or q > 4:
            dropped += 1
            continue
        shipped, armed = claims(q, ws["level"], anchors)
        mr_used, mr_src = mr, "assumed"
        if mr is None:                                  # --mr auto
            m = measured_mr(tl.get("events", []), tgt, t, q)
            mr_used, mr_src = (m, "measured") if m is not None else (MR_FALLBACK, "fallback")
        ehp = tsnap["hp"] / (1.0 - mr_used)
        _, after = straddle(idx, tgt, t)
        ehp_after = after["hp"] / (1.0 - mr_used) if after is not None else None
        dist = ((ws["x"] - tsnap["x"]) ** 2 + (ws["y"] - tsnap["y"]) ** 2) ** 0.5
        in_band = armed < ehp <= shipped
        in_band_after = (ehp_after is not None and armed < ehp_after <= shipped)
        rows.append({
            "t": t, "target": tgt, "hero_level": ws["level"], "qlvl": q,
            "shipped": shipped, "armed": armed, "hp": tsnap["hp"], "ehp": ehp,
            "hp_after": after["hp"] if after is not None else None,
            "ehp_after": ehp_after, "mr": mr_used, "mr_src": mr_src,
            "dist": dist,
            # the only casts the lever is about: shipped reaches, armed does not
            "band": in_band,
            # LIMIT 4 -- the only form allowed to support a verdict
            "band_pair": in_band and in_band_after,
            "in_range": dist <= Q_CAST_RANGE + 80,
        })
    return rows, dropped


# ------------------------------------------------------------------- selfcheck

def selfcheck(anchors):
    fails, ran = [], []

    def ck(name, cond):
        ran.append(name)
        print("  %-58s %s" % (name, "PASS" if cond else "FAIL"))
        if not cond:
            fails.append(name)

    print("wkqdmg_domain --selfcheck")
    ck("hero lua parsed", anchors is not None)
    if anchors is None:
        return 1
    ck("gate names exactly ['wkqdmg']", anchors["ids"] == ["wkqdmg"])
    ck("shipped row is 40*(lvl-1)+100 times 1.68",
       (anchors["step"], anchors["base"], anchors["mult"]) == (40, 100, 1.68))
    ck("honest form is impact + dps*dur", anchors["honest_form"])
    ck("gate reads exactly the three KV keys",
       sorted(anchors["keys"]) == ["blast_dot_damage", "blast_dot_duration", "damage"])
    # the two ladders the source block states in prose
    ck("impact ladder 80/100/120/140",
       [KV_IMPACT[i] for i in (1, 2, 3, 4)] == [80, 100, 120, 140])
    ck("impact+whole-dot (dur 2) is 120/180/240/300",
       [KV_IMPACT[i] + KV_DOT_DPS[i] * 2 for i in (1, 2, 3, 4)] == [120, 180, 240, 300])
    ck("impact+whole-dot (dur 4) is 160/260/360/460",
       [KV_IMPACT[i] + KV_DOT_DPS[i] * 4 for i in (1, 2, 3, 4)] == [160, 260, 360, 460])
    ck("shipped ladder 168/235.2/302.4/369.6",
       [round(claims(i, 1, anchors)[0], 1) for i in (1, 2, 3, 4)] == [168.0, 235.2, 302.4, 369.6])
    # THE DOMAIN CLAIM -- the thing this whole file exists to state
    ck("below level 10 the lever narrows at rank 1 (168 -> 120)",
       claims(1, 9, anchors)[1] == 120)
    ck("at level >= 10 the lever still narrows at rank 1 (168 -> 160)",
       claims(1, 12, anchors)[1] == 160)
    ck("at level >= 10 rank 2 is a NO-OP",
       claims(2, 13, anchors)[1] == claims(2, 13, anchors)[0])
    ck("at level >= 10 rank 3 is a NO-OP",
       claims(3, 14, anchors)[1] == claims(3, 14, anchors)[0])
    ck("at level >= 10 rank 4 is a NO-OP",
       claims(4, 16, anchors)[1] == claims(4, 16, anchors)[0])
    # the trap the last round paid for
    tl = {"events": [{"t": 100.0, "type": "ABILITY", "inflictor": QNAME,
                      "target": "npc_dota_hero_lion", "target_hero": True}],
          "snapshots": [
              {"t": 99.0, "hero": WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9, "level": 5,
               "abilities": [{"name": QNAME, "level": 1}]},
              {"t": 96.0, "hero": "npc_dota_hero_lion", "x": 100, "y": 0, "hp": 0, "hp_pct": 0.0, "level": 5},
              {"t": 99.0, "hero": "npc_dota_hero_lion", "x": 100, "y": 0, "hp": 700, "hp_pct": 1.0, "level": 5}]}
    rows, dropped = scan(tl, anchors, 0.25, 6.0)
    ck("a cast whose target was dead within 6 s is dropped", rows == [] and dropped == 1)
    tl["snapshots"][1]["hp"] = 400
    tl["snapshots"][1]["hp_pct"] = 0.4
    tl["snapshots"][2]["hp"] = 100          # ehp 133.3 -> between 120 and 168
    rows, dropped = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-1 cast at ehp 133 is in the band", len(rows) == 1 and rows[0]["band"])
    tl["snapshots"][2]["hp"] = 200          # ehp 266.7 -> above the shipped claim
    rows, _ = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-1 cast the shipped claim cannot reach is NOT in the band",
       len(rows) == 1 and not rows[0]["band"])
    tl["snapshots"][2]["hp"] = 80           # ehp 106.7 -> both claims reach
    rows, _ = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-1 cast BOTH claims reach is NOT in the band",
       len(rows) == 1 and not rows[0]["band"])
    tl["snapshots"][0]["abilities"][0]["level"] = 3
    tl["snapshots"][0]["level"] = 14
    tl["snapshots"][2]["hp"] = 200
    rows, _ = scan(tl, anchors, 0.25, 6.0)
    ck("a rank-3 cast can never be in the band (lever is a no-op there)",
       len(rows) == 1 and not rows[0]["band"])
    # --- LIMIT 4: the frame-pair discipline, and LIMIT 2: measured resistance
    def one(hp_before, hp_after, dealt=None, mr=0.25, qlvl=1, wklvl=5):
        ev = [{"t": 100.0, "type": "ABILITY", "inflictor": QNAME,
               "target": "npc_dota_hero_lion", "target_hero": True}]
        if dealt is not None:
            ev.append({"t": 100.3, "type": "DAMAGE", "inflictor": QNAME,
                       "target": "npc_dota_hero_lion", "target_hero": True, "value": dealt})
        tl = {"events": ev, "snapshots": [
            {"t": 99.5, "hero": WK, "x": 0, "y": 0, "hp": 900, "hp_pct": 0.9, "level": wklvl,
             "abilities": [{"name": QNAME, "level": qlvl}]},
            {"t": 99.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": hp_before, "hp_pct": 0.5, "level": 5},
            {"t": 100.5, "hero": "npc_dota_hero_lion", "x": 100, "y": 0,
             "hp": hp_after, "hp_pct": 0.3, "level": 5}]}
        r, _ = scan(tl, anchors, mr, 6.0)
        return r[0] if r else None

    r = one(110, 108)                       # ehp 146.7 -> in band on both frames
    ck("a steady target in the band counts as band_pair", r and r["band"] and r["band_pair"])
    r = one(110, 40)                        # collapsing target -- the W25 shape
    ck("a target collapsing across the interval is band but NOT band_pair",
       r and r["band"] and not r["band_pair"])
    r = one(110, 108, dealt=56, mr=None)    # 1 - 56/80 = 0.30
    ck("--mr auto measures 0.300 off a 56-damage impact at rank 1",
       r and r["mr_src"] == "measured" and abs(r["mr"] - 0.30) < 1e-9)
    r = one(27, 0, dealt=13, mr=None)       # the clipped killing blow
    ck("a killing-blow clip is REFUSED, not read as 0.84 resistance",
       r and r["mr_src"] == "fallback" and abs(r["mr"] - MR_FALLBACK) < 1e-9)
    r = one(160, 158, qlvl=2, wklvl=13, mr=0.25)
    ck("no rank-2 cast can be band_pair either", r and not r["band_pair"])

    # the four ConsiderQ branches must still be in the tree, or this argument
    # silently expires (blinkflee_domain.py's lesson)
    src = open(HERO_LUA).read()
    ck("kill-confirm branch still reads wk_GetBlastKillDamage",
       "J.CanKillTarget( npcEnemy, X.wk_GetBlastKillDamage( abilityQ ), nDamageType )" in src)
    ck("ConsiderQ still has a channeling-interrupt branch above it",
       "npcEnemy:IsChanneling()" in src)
    ck("ConsiderQ still has a teamfight branch below it",
       "J.IsInTeamFight( bot, 1200 )" in src)
    ck("wkbuild is still a SEPARATE gate from wkqdmg",
       "J.IsSoakCandidate( 'wkbuild' )" in src)
    print("%d PASS / %d FAIL" % (len(ran) - len(fails), len(fails)))
    return 1 if fails else 0


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*", help="timeline .json files (dumper output)")
    ap.add_argument("--legs", help="tsv: <basename>\\t<armed 0|1>\\t<layer ab|ba>")
    ap.add_argument("--mr", default="auto",
                    help="magic resistance: 'auto' measures it off the blast's own "
                         "DAMAGE event per cast (default), or a fixed float (LIMIT 2)")
    ap.add_argument("--dead-window", type=float, default=6.0)
    ap.add_argument("--per-cast", action="store_true")
    ap.add_argument("--selfcheck", action="store_true")
    args = ap.parse_args()

    anchors = lua_anchors()
    if args.selfcheck:
        return EXIT_CLEAN if selfcheck(anchors) == 0 else EXIT_FINDINGS
    if anchors is None:
        print("REFUSED: could not parse X.wk_GetBlastKillDamage out of %s" % HERO_LUA)
        return EXIT_REFUSED
    if not args.timelines:
        print("REFUSED: no timelines")
        return EXIT_REFUSED

    mr_arg = None if str(args.mr).lower() == "auto" else float(args.mr)

    legs = {}
    if args.legs:
        for line in open(args.legs):
            p = line.split()
            if len(p) >= 3:
                legs[p[0]] = (p[1] == "1", p[2])

    agg = collections.defaultdict(lambda: collections.Counter())
    dropped_total, games, per_cast = 0, 0, []
    for path in args.timelines:
        base = os.path.basename(path).replace(".json", "")
        leg = legs.get(base)
        if leg is None:
            continue
        armed, layer = leg
        key = (layer, "armed" if armed else "baseline")
        try:
            tl = json.load(open(path))
        except Exception:
            dropped_total += 1
            continue
        rows, dropped = scan(tl, anchors, mr_arg, args.dead_window)
        dropped_total += dropped
        games += 1
        agg[key]["games"] += 1
        for r in rows:
            agg[key]["casts"] += 1
            if r["qlvl"] == 1:
                agg[key]["q1"] += 1
                agg[key]["live48" if r["hero_level"] < 10 else "live8"] += 1
            if r["band"]:
                agg[key]["band"] += 1
                if r["band_pair"]:
                    agg[key]["band_pair"] += 1
                if r["in_range"]:
                    agg[key]["in_range"] += 1
                if r["band_pair"] and r["in_range"]:
                    agg[key]["hit"] += 1
                r["game"] = base
                per_cast.append((key, r))
            elif args.per_cast:
                r["game"] = base
                per_cast.append((key, r))

    print("wkqdmg domain census -- %d game(s), mr=%s, dead-window %.1fs, %d cast(s) dropped"
          % (games, args.mr, args.dead_window, dropped_total))
    print("shipped/armed claim ladder (hero lvl >=10): " +
          "  ".join("q%d %.1f/%.0f" % (q, claims(q, 12, anchors)[0], claims(q, 12, anchors)[1])
                    for q in (1, 2, 3, 4)))
    print()
    print("%-6s %-9s %6s %6s %5s %7s %6s %5s %9s %8s %4s" %
          ("layer", "leg", "games", "casts", "q1", "live48", "live8", "band",
           "band_pair", "in_rnge", "HIT"))
    for layer in ("ab", "ba"):
        for leg in ("armed", "baseline"):
            c = agg[(layer, leg)]
            print("%-6s %-9s %6d %6d %5d %7d %6d %5d %9d %8d %4d" %
                  (layer, leg, c["games"], c["casts"], c["q1"],
                   c["live48"], c["live8"], c["band"], c["band_pair"],
                   c["in_range"], c["hit"]))

    if per_cast:
        print("\nper-cast:")
        for key, r in sorted(per_cast, key=lambda kr: (kr[0], kr[1]["t"])):
            print("  %-4s %-8s %-30s t=%7.1f wk=%2d q%d %-16s hp %4d->%-4s "
                  "ehp %6.1f->%-6s mr=%.3f(%s) claims %.1f/%.0f d=%5.0f %s"
                  % (key[0], key[1], r["game"], r["t"], r["hero_level"], r["qlvl"],
                     r["target"].replace("npc_dota_hero_", ""), r["hp"],
                     r["hp_after"] if r["hp_after"] is not None else "-",
                     r["ehp"],
                     ("%.1f" % r["ehp_after"]) if r["ehp_after"] is not None else "-",
                     r["mr"], r["mr_src"][0], r["shipped"], r["armed"], r["dist"],
                     "BAND_PAIR" if r["band_pair"] else "band(before only)"))

    armed_hits = agg[("ab", "armed")]["hit"] + agg[("ba", "armed")]["hit"]
    if armed_hits:
        print("\nFINDINGS: %d armed-leg cast(s) in the band on BOTH straddling frames "
              "and inside branch reach (BUGGY CANDIDATE -- LIMIT 1 before calling it that)"
              % armed_hits)
        return EXIT_FINDINGS
    return EXIT_CLEAN


if __name__ == "__main__":
    sys.exit(main())

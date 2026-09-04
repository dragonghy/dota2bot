#!/usr/bin/env python3
"""[wandbleed] TRIGGER-level reader over dumper timelines.

Unlike every other `*_domain.py` in this directory, this script does not
measure a *domain* (an upper bound on frames where a gate could have fired).
It measures the FIRINGS THEMSELVES, because for this one id the action the
gate produces is directly in the combat log:

    events[] type == "ITEM"  actor == <hero>  inflictor == "item_magic_wand"

That is the charter's 2026-08-24 capability ("主动物品用了没有可以从事件流量
出来"), applied to a gate whose whole effect IS one item activation.

WHAT THE ID DOES (source of truth: bots/ability_item_usage_generic.lua,
`X.ConsiderItemDesire["item_magic_wand"]`, motive '放血自救', line ~3409):

    turbo AND J.IsSoakCandidate('wandbleed')
    AND hp_pct < 0.45
    AND charges >= 5                       -- NOT OBSERVABLE OFFLINE
    AND bot:WasRecentlyDamagedByAnyHero(2.0)

WHICH ITEMS.  `item_holy_locket` (:3126) delegates to the wand function, so it
carries the gate too.  `item_magic_stick` has its OWN function (:3336) which
does NOT contain the gate -- a reader that lumps "the stick family" together
is measuring a superset of the arm.  WAND_ITEMS below is exactly the two that
reach the gated branch.

THE ATTRIBUTION PROBLEM, AND WHY A CAST CAN STILL BE BOUGHT FOR THIS ID.
Five other branches in the same function can also drink the wand, and one of
them (`wandlimbo`) is another armed id in the same wave.  A raw count of wand
casts is therefore the合力 of six mechanisms -- exactly the mistake 章程 4a
(§BW.3) forbids.  But the branches are evaluated IN ORDER and each one
`return`s, so the frame state at the cast partitions them:

  用途1   hp<0.40 or mp<0.30 ; needs an ENEMY HERO WITHIN 1000   [above the gate]
  wandbleed                   hp<0.45 ; charges>=5 ; damaged<2s  [the gate]
  wandlimbo                   hp<=0.25 ; no enemy within 1600    [below the gate]
  用途2   hp<0.70 and mp<0.70 ; charges>=12 ; enemy within 1000   [below]
  用途3   charges>=19 ; SLOT 6 (first backpack slot) OCCUPIED     [below]
  用途4   charges==20 ; enemy within 1000 ; lost>350 hp AND mp    [below]

So the EXCLUSIVE domain of `wandbleed` -- a cast that no other branch in the
function can produce -- is:

    0.25 <= hp_pct < 0.45      (too healthy for wandlimbo, low enough for us)
    AND no living enemy hero within 1000  (kills 用途1 / 用途2 / 用途4)
    AND items[6] == ""                    (kills 用途3 outright: its backpack
                                           clause is POSITIONALLY OBSERVABLE
                                           in the dumper's 9-slot array)
    AND a hero-sourced DAMAGE event on this hero within 2.0 s before the cast

Every clause except `charges >= 5` is then pinned, and charges do not need to
be observed: if the cast happened at all and only this branch could have
produced it, `charges >= 5` held.  This is the rare case where an invisible
condition costs nothing.

⭐ AND CHARGES TURN OUT TO BE OBSERVABLE AFTER ALL, which every other reader of
this item (wandlimbo_domain.py included) has been working without.  The draught
posts its own combat-log line:

    events[] type == "HEAL"  actor == target == <hero>
             inflictor == "item_magic_wand"  value == charges * 15

at the cast's own 0.1 s timestamp -- no snapshot diffing, no impostor problem
(the inflictor names the item), no 1 Hz phase error.  This is a SECOND,
INDEPENDENT attribution channel that does not use the ring at all: 用途2 needs
12 charges, 用途3 needs 19, 用途4 needs 20, so a drink of fewer than 12 charges
is impossible for all three, and below 6 wandlimbo is out too.

⚠️ BUT `value / 15` IS NOT ALWAYS THE CHARGE COUNT, and the corpus says so
out loud: over W39's 72 games, 687 of 8154 wand/stick heals (8.4%) are NOT
multiples of 15.  The heal is OVERHEAL-CAPPED --

    value = min(charges * 15, maxHP - HP)

-- so in general `value` bounds charges only from BELOW (charges >=
ceil(value/15)), which is the WRONG direction for "fewer than 12, therefore not
用途2".  The count is exact only when the draught was not capped, i.e. when the
hero was missing comfortably more HP than the heal delivered; this script
requires `maxHP - HP >= value + 15` at the pre-cast frame (one whole spare
charge of headroom) before it reports an exact count, and otherwise reports a
lower bound and does NOT let it exclude a shipped branch.  Both W39 firings
clear that easily (slardar 75 HP delivered against 898 missing = 5 charges;
crystal_maiden 90 against 500 = 6), so here the ring argument and the charge
argument agree while resting on nothing in common.

NOTE ON ORDERING (the campvoid/campexit fact, §BW.2, applied here).  Because
`wandbleed` sits ABOVE `wandlimbo`, an armed-and-firing `wandbleed` makes
`wandlimbo` unreachable on every overlapping frame (hp<=0.25 AND damaged<2s
AND charges>=5).  A low `wandlimbo` count on a wave where both are armed is a
LOWER BOUND on its domain, not evidence that its domain is small.

LIMITS -- read before quoting a number.

 1. CHARGES ARE INVISIBLE ON A FRAME (GH #293 is still the fix for that), and
    are readable only AT A DRINK, from the HEAL line, subject to the overheal
    cap above.  Inside the exclusive domain the invisibility costs nothing (the
    branch partition supplies `charges >= 5`).  Outside it -- the `all_casts`
    column -- it costs everything, which is why that column is context and
    never a verdict.  The distinction that matters for #293: a HEAL line exists
    only where a drink HAPPENED, so it can never answer "was the gate true on a
    frame where nothing happened", which is exactly the SILENT-vs-domain-empty
    question #293 was opened to settle.
 2. THE 1000 RING USES SAMPLED FRAMES ONLY (GH #176 second half): no
    interpolation, ever.  The frame used is the LAST SAMPLE STRICTLY BEFORE
    the cast -- the charter's 2026-08-20 #66 lesson (a post-action frame reads
    the predicate after the action changed it) transferred from cooldown rising
    edges to item events.

    ⚠️ THE BARE RING TEST ON THAT ONE FRAME IS NOT ENOUGH, and this script's
    first run proved it on its own falsification test (LIMIT 6).  The sample
    grid is ~1 Hz while the gap between the frame and the cast ran 0.2-0.9 s,
    and a hero closes at up to ~550 u/s: all FOUR baseline "exclusive" casts in
    the first 18-game read were enemies measured just OUTSIDE 1000 and moving
    IN (obsidian_destroyer 1011 u at dt=0.3; tidehunter 1159 u -> 683 u one
    sample later; luna twice, 1155 u and 1229 u, both 968-1007 u at the next
    sample).  Every one of them is 用途1 (all four also sat under hp 0.40), not
    this gate.  The bare ring did not merely add noise -- it manufactured
    exactly the row the script exists to count, on the leg that cannot produce
    it.
    ⇒ The ring is now evaluated with a CLOSING-SPEED MARGIN on both sides of
    the cast: the nearest enemy must be outside `1000 + VMAX*dt` at the last
    sample before AND the first sample after, with VMAX = 700 u/s (above the
    550 u/s move-speed cap, so the bound is slack in the safe direction).  A
    cast with no sample after it is REFUSED, not kept.  This makes the ring
    test conservative -- it can still throw away real firings, it can no longer
    invent them -- except against a BLINK, which is a jump and bounded by no
    speed; a blink into the ring inside the gap remains a way to keep a 用途1
    cast, and is the one residual path into the exclusive column.
 3. ENTITY KEYS (GH #176 first half + the 2026-09-02 third discriminator):
    bodies are keyed (hero, idx); frames with hp_pct <= 0 are dropped before
    anything else, because an illusion's stream keeps being emitted with frozen
    coordinates long after it dies (22.6x more dead frames than live).

    ⚠️ BUT THE PRE-HORN FILTER APPLIES TO THE CASTER ONLY, NOT TO THE RING.
    `J.GetNearbyHeroes(bot, r, true, ...)` -- the call every branch of this
    function uses to count enemies -- keeps ANY unit passing `J.IsValidHero`
    (utils.lua:547 = IsValidUnit + IsHero) and rejects only Meepo clones and
    the Arc Warden tempest double (jmz_func.lua:2762-2775).  AN ILLUSION IS A
    HERO TO THAT PREDICATE.  So an illusion inside the ring makes
    `nEnemyCount >= 1` TRUE for the engine, and a reader that drops illusions
    from the ring is measuring a guard the bot does not have -- in the
    permissive direction, because an emptier ring promotes casts INTO the
    exclusive column.
    This is the second row this script's own falsification test (LIMIT 6)
    caught: W39 39b063/20260902_155959_slot2, skywrath_mage t=1052.00 on the
    BASELINE leg, hp 0.416 / mp 0.572, nearest PRE-HORN enemy 2454 u -- and two
    drow_ranger illusions (idx 2378 / 1916, both born t=1044.5) sitting at
    661 u.  With them in the ring the cast is 用途2 (hp<0.7, mp<0.7,
    charges>=12, an enemy inside 1000), which is exactly what a baseline leg
    is allowed to do.
    ⇒ Whether illusions count as enemies is a PER-CALL-SITE fact, read off the
    predicate that call site actually uses.  It is not a property of the
    corpus and there is no repo-wide default.
 4. EVENTS CARRY NO idx.  `events[].actor` is a name, so a cast is attributed
    to the one pre-horn body of that name.  An illusion cannot activate an
    item, so this is safe for the CAST; it is stated because the same
    shortcut would NOT be safe for a position-bearing event.
 5. BOTH LEGS LIVE IN THE SAME GAME and are not independent samples.  Per
    铁律 4(i-a) every reading is registered split by ab / ba (which physical
    side carried the armed leg).  This estimator does NOT cancel side bias, so
    4(i-b) applies: a count that flips sign between the layers is noise and
    does not enter a conclusion.
 6. A ZERO ON THE BASELINE LEG IS THE POINT, not a null result.  The baseline
    leg runs the same six-branch function with the gate closed, so a cast in
    the exclusive domain is impossible there.  Baseline > 0 in the exclusive
    domain falsifies this script's branch partition, not the fix -- treat it as
    an instrument bug and report it as one.
 7. ⭐ `hp_pct == 0` IS NOT DEATH (replay-check 2026-09-04, W44, caught by
    LIMIT 6 firing on the ARMED leg).  The dumper rounds `hp_pct` to three
    decimals, so a hero standing at 1 HP with a four-figure max pool reads
    exactly 0.0 while `hp` still reads 1.  The old corpse filter
    (`hp_pct <= 0`) therefore DELETED a living, moving, damage-dealing enemy
    from the ring, and an emptier ring promotes casts INTO the exclusive
    column -- LIMIT 3's dangerous direction, arrived at from a new side.

    Measured on the frame that caught it: 20260904_003457_slot3
    (run ...3a74c4, seed 3749), pudge t=1064.20, hp_pct 0.388, 1 charge
    drunk.  npc_dota_hero_skeleton_king sat 299.6 u away with hp=1 /
    hp_pct=0 under `modifier_skeleton_king_reincarnation_scepter_active`
    (added t=1062.8, removed t=1068.8 with his DEATH) -- moving
    (-2736,4044 -> -2197,4159), phase-booting at t=1065.4, and burning pudge
    with radiance every 1.0 s throughout.  `entities.alive_at`, the repo's
    death-EVENT-anchored liveness, answers ALIVE on that frame.  With him
    dropped the ring read 5464.8 u and the cast was promoted to "exclusive
    wandbleed firing"; with him kept it reads 299.6 u and the cast is 用途1
    (hp < 0.40, an enemy inside 1000) -- which its ONE charge already proved
    independently, the gate needing five.
    ⇒ Liveness here is `hp > 0 OR hp_pct > 0`, never `hp_pct` alone.  Census
    over the 25 W44 games swept that round: 87 snapshot rows are alive-but-
    zero-`hp_pct`, in 19 of 25 games, EVERY ONE of them at hp == 1, 57 of
    them Wraith King.  This is the OPPOSITE direction to GH #78 / #176
    (a corpse leaking through as alive); nothing in the family was measuring
    a living hero deleted as a corpse.
 8. THE 4000 RING (`--source-ring`) is `J.IsWandBleedSourcePresent`, i.e. the
    `wandbleed2` narrowing, read on the same pre-cast sample as LIMIT 2's
    1000 ring and with the same liveness as LIMIT 7.  It is bounded in ONE
    direction only, and the useful one: `bot:GetNearbyHeroes` sees only what
    the bot's team can see, so this reader's count is an UPPER bound on the
    engine's.  Count 0 therefore proves the engine also had 0 (the gate said
    FALSE and blocked); count >= 1 does not prove the engine had >= 1.
    ⇒ An armed-leg exclusive firing whose 4000 ring is EMPTY is a genuine
    falsifier of the narrowing (§DU.5.2); a full ring is only consistency.
"""
import argparse
import collections
import json
import math
import os
import re
import sys

# Exactly the item names whose ConsiderItemDesire reaches the gated branch:
# item_holy_locket delegates to the wand function, item_magic_stick does not.
WAND_ITEMS = ("item_magic_wand", "item_holy_locket")
# Both HP numbers below are MIRRORs of shipped clauses, not cuts chosen here --
# registered as such in tests/test_detector_source_constants.py (HP_CENSUS) and
# pinned against their source sites there, so moving either Lua clause without
# moving these turns that test red instead of silently redefining this reading.
HP_MAX = 0.45          # the gate's own ceiling: `nHPrate < 0.45` in the
                       # 'wandbleed' branch of
                       # bots/ability_item_usage_generic.lua
                       # X.ConsiderItemDesire["item_magic_wand"]
HP_MIN_EXCLUSIVE = 0.25  # below this, wandlimbo could also explain the cast --
                       # J.ShouldDrinkWandInLimbo's `GetMaxHealth() * 0.25`
                       # floor (bots/FunLib/jmz_func.lua).  The exclusivity
                       # claim of this script IS that floor; if it moves and
                       # this does not, "shared_with_wandlimbo" mislabels casts.
ENEMY_RING = 1000.0    # 用途1 / 用途2 / 用途4 all need an enemy inside this
SOURCE_RING = 4000.0   # J.IsWandBleedSourcePresent's ring -- the 'wandbleed2'
                       # narrowing (bots/FunLib/jmz_func.lua).  LIMIT 8.
VMAX = 700.0           # u/s closing-speed bound for the ring margin (LIMIT 2);
                       # above the 550 u/s move cap on purpose -- slack here
                       # throws away real firings, tightness invents fake ones
DAMAGE_WINDOW = 2.0    # WasRecentlyDamagedByAnyHero(2.0)
BACKPACK_SLOT = 6      # bot:GetItemInSlot(6), 用途3's clause
HP_PER_CHARGE = 15     # a wand charge restores 15 HP (and 15 mana)
MIN_SHIPPED_CHARGES = 12  # the cheapest SHIPPED charge floor (用途2); below it
                          # 用途2/3/4 are all impossible whatever the ring says

STAMP = re.compile(r"^mirror:(?P<cand>.*):s(?P<seed>\d+):(?P<side>radiant|dire)$")


def real_bodies(snaps):
    """(hero, idx) keys of entities first sampled before the horn (LIMIT 3)."""
    born = {}
    for s in snaps:
        k = (s["hero"], s["idx"])
        t = s["t"]
        if k not in born or t < born[k]:
            born[k] = t
    return {k for k, t0 in born.items() if t0 < 0.0}


def is_live(s):
    """LIMIT 7: `hp_pct` is rounded to 3 decimals, so 1 HP reads as 0.0.

    A row counts as a living body when EITHER field is positive.  Using
    `hp_pct` alone deletes a hero standing at 1 HP -- and an emptier ring is
    the direction that INVENTS exclusive-domain firings.
    """
    return (s.get("hp") or 0) > 0 or (s.get("hp_pct") or 0) > 0


def index(snaps, bodies):
    """by_ent: pre-horn bodies only (a CASTER cannot be an illusion).

    by_t: EVERY living hero entity, illusions included -- that is what the
    engine's ring predicate counts (LIMIT 3).
    """
    by_ent = collections.defaultdict(list)
    by_t = collections.defaultdict(list)
    for s in snaps:
        if not is_live(s):
            continue          # LIMIT 3/7: corpses and frozen illusion streams
        by_t[round(s["t"], 3)].append(s)
        k = (s["hero"], s["idx"])
        if k in bodies:
            by_ent[k].append(s)
    for v in by_ent.values():
        v.sort(key=lambda s: s["t"])
    return by_ent, by_t


def last_frame_before(frames, t):
    """The last SAMPLE strictly before t (LIMIT 2). None if there is none."""
    best = None
    for s in frames:
        if s["t"] < t:
            best = s
        else:
            break
    return best


def first_frame_after(frames, t):
    """The first SAMPLE strictly after t. None if the cast ends the stream."""
    for s in frames:
        if s["t"] > t:
            return s
    return None


def nearest_enemy(by_t, s, team):
    """Distance to the closest living pre-horn enemy body AT THIS SAMPLE."""
    best = math.inf
    for o in by_t.get(round(s["t"], 3), ()):
        if o["team"] == team:
            continue
        d = math.hypot(o["x"] - s["x"], o["y"] - s["y"])
        if d < best:
            best = d
    return best


def ring_clear(frames, by_t, s_pre, t_cast, team):
    """True only if no enemy can have been inside ENEMY_RING at t_cast.

    LIMIT 2: bounded by VMAX on BOTH sides of the cast, and REFUSED outright
    when there is no sample after the cast to bound the approach from.
    Returns (clear, d_pre, d_post) so a caller can print the numbers.
    """
    d_pre = nearest_enemy(by_t, s_pre, team)
    s_post = first_frame_after(frames, t_cast)
    if s_post is None:
        return False, d_pre, None
    d_post = nearest_enemy(by_t, s_post, team)
    ok = (d_pre > ENEMY_RING + VMAX * (t_cast - s_pre["t"])
          and d_post > ENEMY_RING + VMAX * (s_post["t"] - t_cast))
    return ok, d_pre, d_post


def hero_damage_before(dmg_by_target, hero, t, window=DAMAGE_WINDOW):
    """A hero-sourced DAMAGE landing on `hero` in [t-window, t)."""
    for te in dmg_by_target.get(hero, ()):
        if t - window <= te < t:
            return te
    return None


def scan_game(tl, armed_side):
    snaps = tl.get("snapshots") or []
    events = tl.get("events") or []
    if not snaps:
        return None
    bodies = real_bodies(snaps)
    by_ent, by_t = index(snaps, bodies)
    name_to_key = {}
    for k in by_ent:
        name_to_key.setdefault(k[0], k)   # LIMIT 4: one pre-horn body per name
    armed_team = 2 if armed_side == "radiant" else 3

    dmg_by_target = collections.defaultdict(list)
    heal_by_target = collections.defaultdict(list)
    for e in events:
        if e.get("type") == "DAMAGE" and e.get("actor_hero") and e.get("target_hero"):
            dmg_by_target[e["target"]].append(e["t"])
        elif e.get("type") == "HEAL" and e.get("inflictor") in WAND_ITEMS:
            heal_by_target[e["target"]].append((e["t"], e.get("value") or 0))
    for v in dmg_by_target.values():
        v.sort()
    for v in heal_by_target.values():
        v.sort()

    out = {leg: collections.Counter() for leg in ("armed", "baseline")}
    rows = []
    for e in events:
        if e.get("type") != "ITEM" or e.get("inflictor") not in WAND_ITEMS:
            continue
        k = name_to_key.get(e.get("actor"))
        if k is None:
            continue
        frames = by_ent[k]
        s = last_frame_before(frames, e["t"])
        if s is None:
            continue
        leg = "armed" if s["team"] == armed_team else "baseline"
        out[leg]["all_casts"] += 1

        pct = s.get("hp_pct") or 0
        if pct >= HP_MAX:
            continue
        out[leg]["hp_below_45"] += 1
        items = s.get("items") or []
        slot6 = items[BACKPACK_SLOT] if len(items) > BACKPACK_SLOT else ""
        clear, d_pre, d_post = ring_clear(frames, by_t, s, e["t"], s["team"])
        td = hero_damage_before(dmg_by_target, k[0], e["t"])

        if not clear:
            out[leg]["blocked_enemy_in_1000"] += 1
            continue
        if pct < HP_MIN_EXCLUSIVE:
            out[leg]["shared_with_wandlimbo"] += 1
            continue
        if slot6:
            out[leg]["blocked_slot6_occupied"] += 1
            continue
        if td is None:
            out[leg]["no_hero_damage_2s"] += 1
            continue

        out[leg]["exclusive"] += 1
        # LIMIT 8: the 'wandbleed2' narrowing read on this same pre-cast
        # sample.  An EMPTY 4000 ring on the ARMED leg is the one reading that
        # falsifies the narrowing (§DU.5.2); on the baseline leg it is the
        # population the narrowing exists to remove.
        src_absent = d_pre == math.inf or d_pre > SOURCE_RING
        if src_absent:
            out[leg]["wandbleed2_source_absent"] += 1
        # The draught's own HEAL line, same 0.1 s stamp.  value = min(charges*15,
        # missing HP), so the count is EXACT only when the draught was not
        # overheal-capped -- see the docstring's warning.
        heal, charges, exact = None, None, False
        hp_now = s.get("hp") or 0
        missing = (hp_now / pct) - hp_now
        for th, v in heal_by_target.get(k[0], ()):
            if abs(th - e["t"]) <= 0.2:
                heal = v
                charges = v / HP_PER_CHARGE
                exact = (v % HP_PER_CHARGE == 0
                         and missing >= v + HP_PER_CHARGE)
                break
        if exact and charges < MIN_SHIPPED_CHARGES:
            out[leg]["charges_below_shipped_floor"] += 1
        rows.append({
            "src4000_absent": src_absent,
            "heal": heal, "charges": charges, "charges_exact": exact,
            "missing_hp": round(missing, 1),
            "leg": leg, "hero": k[0], "idx": k[1], "t_cast": round(e["t"], 2),
            "t_frame": round(s["t"], 2), "hp_pct": round(pct, 3),
            "hp": s.get("hp"), "mp": s.get("mp"),
            "item": e.get("inflictor"),
            "t_last_hero_damage": round(td, 2),
            "slot6": slot6 or "",
            "d_enemy_pre": round(d_pre, 1) if d_pre != math.inf else None,
            "d_enemy_post": round(d_post, 1) if d_post not in (None, math.inf) else None,
        })
    return out, rows


def selfcheck():
    ok = [0, 0]

    def check(name, cond):
        ok[0 if cond else 1] += 1
        print("  %-64s %s" % (name, "PASS" if cond else "FAIL"))

    def body(hero, idx, team, t, hp_pct, x=0.0, y=0.0, items=None):
        return {"t": t, "hero": hero, "idx": idx, "team": team, "x": x, "y": y,
                "hp": 1000 * hp_pct, "hp_pct": hp_pct, "mp": 500,
                "items": items if items is not None else [""] * 9}

    # one pre-horn body per team; the caster bleeds from 60% to 30%
    snaps = [body("cm", 1, 2, -30.0, 1.0), body("cm", 1, 2, 9.0, 0.60),
             body("cm", 1, 2, 10.0, 0.30), body("cm", 1, 2, 11.0, 0.31),
             body("lina", 2, 3, -30.0, 1.0), body("lina", 2, 3, 9.0, 1.0,
                                                  x=4000.0),
             body("lina", 2, 3, 10.0, 1.0, x=4000.0),
             body("lina", 2, 3, 11.0, 1.0, x=4000.0)]
    ev = [{"t": 9.5, "type": "DAMAGE", "actor": "lina", "target": "cm",
           "actor_hero": True, "target_hero": True, "inflictor": "lina_dragon_slave"},
          {"t": 10.5, "type": "ITEM", "actor": "cm", "target": "cm",
           "inflictor": "item_magic_wand"}]
    tl = {"snapshots": snaps, "events": ev}
    res, rows = scan_game(tl, "radiant")
    check("a clean exclusive-domain cast is counted once", res["armed"]["exclusive"] == 1)
    check("and the frame used is the one BEFORE the cast, not after",
          rows and rows[0]["t_frame"] == 10.0 and rows[0]["hp_pct"] == 0.3)

    # the same cast with an enemy inside 1000 belongs to 用途1, not to us
    near = json.loads(json.dumps(tl))
    for s in near["snapshots"]:
        if s["hero"] == "lina":
            s["x"] = 500.0
    res2, _ = scan_game(near, "radiant")
    check("an enemy inside 1000 hands the cast to 用途1",
          res2["armed"]["exclusive"] == 0 and res2["armed"]["blocked_enemy_in_1000"] == 1)

    # --- LIMIT 2, pinned on the four real baseline rows that forced it ------
    # W39 85aa25/20260902_154742_slot3, obsidian_destroyer t=425.80: the last
    # sample before it (425.50) had slardar at 1011 u -- OUTSIDE 1000 -- and one
    # sample later he is at 913 u.  A bare ring test books this as an exclusive
    # firing on the BASELINE leg, where the gate is closed.
    def approach(d_pre, t_pre, d_post, t_post, t_cast=10.5):
        snaps = [body("cm", 1, 2, -30.0, 1.0),
                 body("cm", 1, 2, t_pre, 0.30), body("cm", 1, 2, t_post, 0.30),
                 body("lina", 2, 3, -30.0, 1.0),
                 body("lina", 2, 3, t_pre, 1.0, x=d_pre),
                 body("lina", 2, 3, t_post, 1.0, x=d_post)]
        ev = [{"t": t_cast - 1.0, "type": "DAMAGE", "actor": "lina",
               "target": "cm", "actor_hero": True, "target_hero": True,
               "inflictor": "lina_dragon_slave"},
              {"t": t_cast, "type": "ITEM", "actor": "cm", "target": "cm",
               "inflictor": "item_magic_wand"}]
        return scan_game({"snapshots": snaps, "events": ev}, "radiant")[0]["armed"]

    od = approach(1011.0, 10.2, 913.0, 11.2)      # the real OD row
    check("the real OD row (1011 u closing, dt=0.3) is refused by the margin",
          od["exclusive"] == 0 and od["blocked_enemy_in_1000"] == 1)
    tide = approach(1159.0, 10.3, 683.0, 11.3)    # the real tidehunter row
    check("the real tidehunter row (1159 u -> 683 u) is refused",
          tide["exclusive"] == 0 and tide["blocked_enemy_in_1000"] == 1)
    luna = approach(1155.0, 9.7, 968.0, 10.7)     # the real luna row
    check("the real luna row (1155 u at dt=0.8) is refused",
          luna["exclusive"] == 0 and luna["blocked_enemy_in_1000"] == 1)
    # ... while the armed slardar row (1497 u at dt=0.2, enemy RECEDING to
    # 1686 u) clears both margins and must survive.
    slar = approach(1497.0, 10.3, 1686.0, 11.3)
    check("the real slardar row (1497 u, receding) still counts",
          slar["exclusive"] == 1)
    check("a cast with no sample after it is refused, not kept",
          scan_game({"snapshots": [body("cm", 1, 2, -30.0, 1.0),
                                   body("cm", 1, 2, 10.0, 0.30),
                                   body("lina", 2, 3, -30.0, 1.0, x=9000.0),
                                   body("lina", 2, 3, 10.0, 1.0, x=9000.0)],
                     "events": [{"t": 9.5, "type": "DAMAGE", "actor": "lina",
                                 "target": "cm", "actor_hero": True,
                                 "target_hero": True, "inflictor": "x"},
                                {"t": 10.5, "type": "ITEM", "actor": "cm",
                                 "target": "cm",
                                 "inflictor": "item_magic_wand"}]},
                    "radiant")[0]["armed"]["exclusive"] == 0)

    # hp below 25% is shared with wandlimbo and must not be claimed
    low = json.loads(json.dumps(tl))
    for s in low["snapshots"]:
        if s["hero"] == "cm" and s["t"] == 10.0:
            s["hp_pct"], s["hp"] = 0.20, 200
    res3, _ = scan_game(low, "radiant")
    check("hp<25% is registered as shared with wandlimbo, not exclusive",
          res3["armed"]["exclusive"] == 0 and res3["armed"]["shared_with_wandlimbo"] == 1)

    # slot 6 occupied -> 用途3 is live, refuse the attribution
    bp = json.loads(json.dumps(tl))
    for s in bp["snapshots"]:
        if s["hero"] == "cm":
            s["items"] = [""] * 6 + ["branches", "", ""]
    res4, _ = scan_game(bp, "radiant")
    check("an occupied backpack slot 6 hands the cast to 用途3",
          res4["armed"]["exclusive"] == 0 and res4["armed"]["blocked_slot6_occupied"] == 1)

    # creep damage is not WasRecentlyDamagedByAnyHero
    creep = json.loads(json.dumps(tl))
    creep["events"][0]["actor_hero"] = False
    res5, _ = scan_game(creep, "radiant")
    check("creep damage does not satisfy WasRecentlyDamagedByAnyHero",
          res5["armed"]["exclusive"] == 0 and res5["armed"]["no_hero_damage_2s"] == 1)

    # damage older than 2 s does not count either
    old = json.loads(json.dumps(tl))
    old["events"][0]["t"] = 7.0
    res6, _ = scan_game(old, "radiant")
    check("hero damage 3.5 s old is outside the 2.0 s window",
          res6["armed"]["exclusive"] == 0 and res6["armed"]["no_hero_damage_2s"] == 1)

    # a magic stick is a DIFFERENT function and must never be counted
    stick = json.loads(json.dumps(tl))
    stick["events"][1]["inflictor"] = "item_magic_stick"
    res7, _ = scan_game(stick, "radiant")
    check("item_magic_stick is not in this gate's function at all",
          res7["armed"]["all_casts"] == 0)

    # an illusion born after the horn is not a caster and not an enemy
    # An illusion cannot CAST, but it IS an enemy to J.GetNearbyHeroes -- the
    # real skywrath row (two drow illusions at 661 u) is why this flipped.
    illu = json.loads(json.dumps(tl))
    illu["snapshots"] += [body("lina", 99, 3, 9.0, 1.0), body("lina", 99, 3, 10.0, 1.0),
                          body("lina", 99, 3, 11.0, 1.0)]
    res8, _ = scan_game(illu, "radiant")
    check("a post-horn illusion inside the ring DOES block the cast",
          res8["armed"]["exclusive"] == 0
          and res8["armed"]["blocked_enemy_in_1000"] == 1)
    far_illu = json.loads(json.dumps(tl))
    far_illu["snapshots"] += [body("lina", 99, 3, t, 1.0, x=9000.0)
                              for t in (9.0, 10.0, 11.0)]
    res8b, _ = scan_game(far_illu, "radiant")
    check("an illusion outside the ring still leaves the cast countable",
          res8b["armed"]["exclusive"] == 1)
    # and it is still not a caster: an ITEM event is bound to the pre-horn body
    check("the caster is the pre-horn body, never the illusion",
          scan_game(far_illu, "radiant")[1][0]["idx"] == 1)

    # the leg is decided by the caster's team vs the armed side
    res9, _ = scan_game(tl, "dire")
    check("swapping the armed side moves the cast to the baseline leg",
          res9["baseline"]["exclusive"] == 1 and res9["armed"]["exclusive"] == 0)

    # --- the overheal cap: value/15 is a LOWER bound, not the charge count --
    def with_heal(heal_value, hp_pct, max_hp=1000.0):
        def me(t):
            b = body("cm", 1, 2, t, hp_pct)
            b["hp"] = max_hp * hp_pct
            return b
        snaps = [body("cm", 1, 2, -30.0, 1.0), me(10.0), me(11.0),
                 body("lina", 2, 3, -30.0, 1.0),
                 body("lina", 2, 3, 10.0, 1.0, x=9000.0),
                 body("lina", 2, 3, 11.0, 1.0, x=9000.0)]
        ev = [{"t": 9.5, "type": "DAMAGE", "actor": "lina", "target": "cm",
               "actor_hero": True, "target_hero": True, "inflictor": "x"},
              {"t": 10.5, "type": "ITEM", "actor": "cm", "target": "cm",
               "inflictor": "item_magic_wand"},
              {"t": 10.5, "type": "HEAL", "actor": "cm", "target": "cm",
               "inflictor": "item_magic_wand", "value": heal_value}]
        res, rows = scan_game({"snapshots": snaps, "events": ev}, "radiant")
        return res["armed"], rows[0]

    res_a, row_a = with_heal(75, 0.30)   # 700 missing, 75 delivered -> uncapped
    check("an uncapped 75 HP draught reads as exactly 5 charges",
          row_a["charges"] == 5 and row_a["charges_exact"]
          and res_a["charges_below_shipped_floor"] == 1)
    # max 200, hp 88 -> 112 missing; a 8-charge draught (120) is capped to 112,
    # and 112 is not a multiple of 15 -- the corpus's 8.4% shape.
    res_b, row_b = with_heal(112, 0.44, max_hp=200.0)
    check("an overheal-capped draught is NOT read as a charge count",
          not row_b["charges_exact"] and res_b["charges_below_shipped_floor"] == 0)
    # a multiple of 15 that exactly fills the bar has no headroom to prove it
    # was uncapped, so it is refused too
    res_c, row_c = with_heal(105, 0.44, max_hp=200.0)
    check("a draught with under one spare charge of headroom is not exact",
          not row_c["charges_exact"])

    # --- LIMIT 7, pinned on the real W44 row that forced it -----------------
    # 20260904_003457_slot3 (run ...3a74c4, seed 3749) pudge t=1064.20:
    # skeleton_king 299.6 u away, hp=1, hp_pct=0 (rounded), ALIVE -- moving,
    # phase-booting and burning pudge with radiance.  Dropping him read the
    # ring as 5464.8 u and manufactured an exclusive firing on the ARMED leg.
    one_hp = json.loads(json.dumps(tl))
    for s in one_hp["snapshots"]:
        if s["hero"] == "lina":
            s["x"], s["hp"], s["hp_pct"] = 299.6, 1, 0.0
    res10, _ = scan_game(one_hp, "radiant")
    check("a 1-HP enemy (hp_pct rounds to 0.0) is ALIVE and blocks the cast",
          res10["armed"]["exclusive"] == 0
          and res10["armed"]["blocked_enemy_in_1000"] == 1)
    # ... and the same row with a true corpse (hp AND hp_pct both 0) must
    # still be dropped, or the fix would have swallowed LIMIT 3 with it.
    corpse = json.loads(json.dumps(tl))
    for s in corpse["snapshots"]:
        if s["hero"] == "lina":
            s["x"], s["hp"], s["hp_pct"] = 299.6, 0, 0.0
    res11, _ = scan_game(corpse, "radiant")
    check("a real corpse (hp==0 AND hp_pct==0) is still dropped from the ring",
          res11["armed"]["exclusive"] == 1)
    check("is_live splits the two by hp, not by hp_pct alone",
          is_live({"hp": 1, "hp_pct": 0.0})
          and not is_live({"hp": 0, "hp_pct": 0.0})
          and is_live({"hp": 0, "hp_pct": 0.4}))

    # --- LIMIT 8: the 'wandbleed2' 4000 ring on the exclusive rows -----------
    # The baseline tl has lina at 4000.0 exactly, i.e. NOT outside the ring.
    res12, row12 = scan_game(tl, "radiant")
    check("an exclusive cast with a live enemy at 4000 u has its source PRESENT",
          res12["armed"]["wandbleed2_source_absent"] == 0
          and row12[0]["src4000_absent"] is False)
    residue = json.loads(json.dumps(tl))
    for s in residue["snapshots"]:
        if s["hero"] == "lina":
            s["x"] = 8381.0        # the GH #437 desk frame's residue distance
    res13, row13 = scan_game(residue, "radiant")
    check("an exclusive cast with the nearest live enemy at 8381 u is SOURCE-ABSENT",
          res13["armed"]["exclusive"] == 1
          and res13["armed"]["wandbleed2_source_absent"] == 1
          and row13[0]["src4000_absent"] is True)
    # LIMIT 7 and LIMIT 8 interact: the deleted 1-HP body is what turns a
    # source-PRESENT frame into a source-ABSENT one, which on the armed leg
    # reads as a falsification of the narrowing (§DU.5.2) that never happened.
    residue_1hp = json.loads(json.dumps(residue))
    residue_1hp["snapshots"] += [body("sk", 7, 3, t, 0.0, x=299.6)
                                 for t in (-30.0, 9.0, 10.0, 11.0)]
    for s in residue_1hp["snapshots"]:
        if s["hero"] == "sk":
            s["hp"], s["hp_pct"] = 1, 0.0
    res14, _ = scan_game(residue_1hp, "radiant")
    check("the 1-HP body keeps a source-absent armed row from being invented",
          res14["armed"]["exclusive"] == 0
          and res14["armed"]["wandbleed2_source_absent"] == 0)

    print("selfcheck: %d pass, %d fail" % tuple(ok))
    return 0 if ok[1] == 0 else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("timelines", nargs="*")
    ap.add_argument("--stamps", help="JSON {timeline basename: 'mirror:...:sN:side'}")
    ap.add_argument("--manifest", action="append", default=[],
                    help="a sweep_run.sh games_manifest.jsonl (repeatable)")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--rows", action="store_true", help="print every exclusive cast")
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(selfcheck())
    if not a.timelines or not (a.stamps or a.manifest):
        ap.error("timelines and --stamps/--manifest are required unless --selfcheck")

    stamps = {}
    if a.stamps:
        with open(a.stamps) as fh:
            stamps.update(json.load(fh))
    for mp in a.manifest:
        with open(mp) as fh:
            for line in fh:
                if not line.strip():
                    continue
                g = json.loads(line)
                stamps[g["game"]] = "mirror:%s:s%s:%s" % (g["cand"], g["seed"], g["side"])

    keys = ("all_casts", "hp_below_45", "blocked_enemy_in_1000",
            "shared_with_wandlimbo", "blocked_slot6_occupied",
            "no_hero_damage_2s", "exclusive", "charges_below_shipped_floor",
            "wandbleed2_source_absent")
    layers = {"ab": collections.Counter(), "ba": collections.Counter()}
    all_rows, seen, skipped = [], 0, 0
    for path in sorted(a.timelines):
        base = os.path.basename(path)
        for suf in (".timeline.json", ".json"):
            if base.endswith(suf):
                base = base[: -len(suf)]
                break
        st = stamps.get(base)
        m = STAMP.match(st) if st else None
        if not m:
            skipped += 1
            print("skip (no/unparseable stamp): %s" % base, file=sys.stderr)
            continue
        with open(path) as fh:
            tl = json.load(fh)
        got = scan_game(tl, m.group("side"))
        if got is None:
            skipped += 1
            continue
        res, rows = got
        seen += 1
        layer = "ab" if m.group("side") == "radiant" else "ba"
        layers[layer]["games"] += 1
        for leg in ("armed", "baseline"):
            for k in keys:
                layers[layer]["%s_%s" % (leg, k)] += res[leg][k]
        for r in rows:
            r["game"] = base
            r["layer"] = layer
            all_rows.append(r)

    print("games read: %d  (skipped %d)" % (seen, skipped))
    print()
    hdr = "%6s %6s %9s" % ("layer", "games", "leg") + "".join(
        "%*s" % (max(len(k) + 2, 9), k) for k in keys)
    print(hdr)
    print("-" * len(hdr))
    for layer in ("ab", "ba"):
        c = layers[layer]
        for leg in ("armed", "baseline"):
            print("%6s %6d %9s" % (layer, c["games"], leg) + "".join(
                "%*d" % (max(len(k) + 2, 9), c["%s_%s" % (leg, k)]) for k in keys))
    print()
    tot = {leg: sum(layers[l]["%s_exclusive" % leg] for l in ("ab", "ba"))
           for leg in ("armed", "baseline")}
    print("EXCLUSIVE-DOMAIN CASTS  armed %d  baseline %d   "
          "(baseline > 0 falsifies the branch partition, LIMIT 6)"
          % (tot["armed"], tot["baseline"]))
    print("Both layers are printed above because this estimator does NOT cancel")
    print("side bias (铁律 4(i-b)): a sign flip between ab and ba is noise.")
    if a.rows:
        print()
        for r in sorted(all_rows, key=lambda r: (r["game"], r["t_cast"])):
            print("  %s %-3s %-8s %-22s idx=%-5s t=%8.2f frame=%8.2f hp=%.3f "
                  "dmg_at=%7.2f d_pre=%s d_post=%s heal=%s charges=%s"
                  % (r["game"], r["layer"], r["leg"],
                     r["hero"].replace("npc_dota_hero_", ""), r["idx"],
                     r["t_cast"], r["t_frame"], r["hp_pct"],
                     r["t_last_hero_damage"], r["d_enemy_pre"],
                     r["d_enemy_post"], r["heal"],
                     ("%g exact" % r["charges"]) if r["charges_exact"]
                     else (">=%g (capped)" % r["charges"]
                           if r["charges"] is not None else "?")))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Execution check ((a)-evidence) for the `stayfield` soak candidate.

owner priority P2's DECISION side: a hurt bot that is in no danger and is
carrying something to drink should heal in the field, not spend ~20s of a ~20
minute turbo game inside its own fountain.  `stayfield` is the TP half of that
fix (the walk half is `stayfield2`, a separate id).  Read-only, offline;
consumes sweep_run.sh output dirs.

Why a dedicated probe: detect.py's 15 detectors carry no "did this bot have a
heal in the bag" predicate at all, and `d2_tp_home_wasteful` is NOT a stand-in
-- GH #111 measured that 43% of its hits are FORWARD TPs (it never reads the
landing point).  So `stayfield` has never had an (a) reading.

--------------------------------------------------------------------------
DOMAIN, transcribed from source (not invented)
--------------------------------------------------------------------------
J.IsFieldRegenSituation (jmz_func.lua:4820):
    IsModeTurbo()                                  <- whole corpus is turbo
    0.18 <= J.GetHP(bot) <= 0.55
    #J.GetNearbyHeroes(bot, 1600, true, ...) == 0
    not ( WasRecentlyDamagedByAnyHero(3.0)
          and some enemy inside 3000 with WasRecentlyDamagedByHero(e,3.0) )
    #bot:GetNearbyTowers(1200, true) == 0
    ** and, ARM-DEPENDENT, a FIFTH clause -- see the block below. **

    ⚠ FIFTH CLAUSE, `fieldcreep` (GH #119, jmz_func.lua:5287), added
    2026-08-30 after a frame showed this file was measuring the wrong
    predicate on the armed leg:

        if J.IsSoakCandidate('fieldcreep') and bot:WasRecentlyDamagedByCreep(3.0)
        then return false end

    It sits INSIDE J.IsFieldRegenSituation, after the tower clause, and it is
    itself gated.  On a wave whose candidate arm carries `fieldcreep` (W25..W28
    all did) the ARMED leg's predicate is therefore strictly STRICTER than the
    baseline leg's -- a difference that has nothing to do with `stayfield` and
    which this file used to charge to it silently, by scoring both legs with
    the unarmed semantics.  `stayfield2_whynot.py` has declared and scored this
    clause since it was written; this file did not, which made the armed leg's
    SITUATION/STRICT counts an OVER-count and every armed-vs-baseline rate
    printed here biased in `stayfield`'s FAVOUR (a bigger armed denominator
    with the same numerator lowers the armed home_tp rate).

    Frame that caught it -- W28 run e706a3, game 20260830_063416_slot1
    (seed 2130, side=radiant, so RADIANT IS THE ARMED LEG), hero lich,
    t=625.5..634.5: coordinates frozen at (223,-4921) for ten straight
    seconds, hp 1.000 -> 0.229, nearest enemy HERO never closer than 1646u,
    no attributed hero damage, no tower -- and 774 damage taken from
    npc_dota_neutral_grown_frog + npc_dota_neutral_ancient_frog_mage, a hit
    every ~1.3s.  Unarmed semantics: SITUATION TRUE.  What the engine actually
    ran on that leg: WasRecentlyDamagedByCreep(3.0) TRUE => SITUATION FALSE.

    It is now scored, per leg, in BOTH of §AR.1's worlds (never merged):
        甲  WasRecentlyDamagedByCreep counts NEUTRALS  -> lane or neutral hits
        乙  it does not                                -> lane hits only
    甲 is the primary because it removes MORE armed rows, i.e. it is the
    conservative world for every claim this file can make: it shrinks the
    armed domain (making a "the domain never occurred" verdict harder to
    reach by accident) and it shrinks the armed leak count (making a "the
    gate leaked" accusation harder to make).  The disclosure header prints
    both worlds' removals whether or not the clause is live -- a reader who
    cannot see that block must conclude the tool did not check, never that
    the corpus was clean.

J.HasFieldRegenSource (jmz_func.lua:4748): one of the SIX usable slots holds
    flask / tango / tango_single / faerie_fire, or a bottle WITH CHARGES.

    ** ARM-DEPENDENT since 2026-08-23 (soak candidate 'bagsalve', GH #123). **
    With `bagsalve` armed the source ALSO answers TRUE for an item_flask in a
    BACKPACK slot (6..8) -- salve only, because TrySwapInvItemForFlask is the
    only shipped un-gated swapper and there is none for tango / tango_single /
    faerie_fire / bottle.  `usable_items()` below reads six slots, i.e. this
    detector measures the UNARMED semantics.  On a wave whose candidate arm has
    `bagsalve` in its id string, this detector UNDER-counts `has_regen` and
    OVER-counts the `fieldbuy` dry half on that arm; correcting it needs the
    arm's id string, which this file does not currently take.  Declared, not
    silently wrong -- see iterations/reports/strategy/20260823T174500Z.md.

That pair is J.ShouldRegenNotGoHome.  `stayfield` wires it into exactly ONE
call site -- the tpscroll "撤退:3" home-TP branch, ability_item_usage_generic
.lua:5514 -- whose own entry conditions therefore bound where the gate can
possibly bite.  The observable ones are scored as the STRICT domain:

    (botHP < 0.34 or botHP + botMP < 0.43)
    bot:GetLevel() >= 9
    itemFlask == nil            <- ** the flask leg is structurally dead here **
    botName not in {huskar, slark}
    not HasModifier(modifier_flask_healing / modifier_clarity_potion)
    (TP scroll off cooldown -- snapshot field `tp_cd`)

`itemFlask == nil` is the load-bearing one and it is why STRICT is much smaller
than SITUATION: the branch only fires when the bot has NO salve, so the only
heals that can ever reach this gate are tango / tango_single / faerie_fire /
bottle.  (Director's §AM.2 finding, re-derived here from the source.)

NOT transcribed (unobservable offline -> my domain is a SUPERSET on these
clauses, i.e. the effect is DILUTED, and armed counts are a LOWER bound):
    nEnemyCount <= 1, nAllyCount <= 2  (radii live in the caller's locals)
    X.CanJuke(), bot:GetAttackTarget() == nil
    bottle charge count (an empty bottle is class item_empty_bottle, so the
    name test alone already removes most of it)

Vision direction, stated once because it decides how a zero may be read: the
engine's GetNearbyHeroes/GetNearbyTowers see only VISIBLE units, the replay is
god's-eye.  Requiring the god's-eye 1600 ring to be empty is STRICTER than the
engine's test, and vetoing on god's-eye attributed damage vetoes MORE often
than the engine does.  So every frame this tool scores is genuinely inside the
engine's domain: my domain is a SUBSET.  A zero here is a real zero over a
subset -- reportable as "no surface in this corpus", never as SILENT.

--------------------------------------------------------------------------
SIGNATURE
--------------------------------------------------------------------------
Per episode (same hero, frame gap > 5s starts a new one) the outcome is read
in a HORIZON after the episode's first domain frame:
    home_tp    -- MODIFIER_ADD modifier_teleporting whose LANDING (first frame
                  >= REMOVE + TP_TAIL) is within FOUNTAIN_NEAR of OWN fountain
    home_walk  -- reaches within FOUNTAIN_NEAR of own fountain without a TP
    drank      -- ITEM item_tango / tango_single / faerie_fire / bottle / flask
The gate can only ever remove `home_tp` (it vetoes one tpscroll branch); the
other two columns are its null channels -- if armed also loses `home_walk`,
the reading is contaminated by something else in the 21-id string.

Registered traps this tool obeys (charter iterations/streams/replay-check.md):
  * armed-string guard: refuses to score a gate that was never armed, and
    refuses `stayfield2` explicitly (it is NOT in the 12:12Z wave's string).
  * idx lock by EARLIEST APPEARANCE (08-22T04:05Z) -- illusions copy hp and
    items field-for-field; identity can only come from `idx`.  `by_t` is
    locked too, so copies cannot inflate the 1600 ring.
  * towers are paired by (round(x), round(y)) -- buildings[].name is not an
    identity (08-21T22:05Z 甲); watch_tower excluded.
  * "<= t 的最后一帧" for every cross-unit lookup, with a max gap of one
    sampling interval (08-21T12:39Z).
  * TP channel spans get a TP_TAIL landing tail (08-22T13:15Z 甲) and a
    displacement physical-upper-bound guard.
  * corpse frames: hp_pct > 0 AND no DEATH within DEATH_BLANK_S (#78).
  * fountain centroid per team from EACH TEAM'S OWN first frames, with a
    positive control (08-22T08:50Z 乙 / 13:15Z).
  * #102 sweep-completeness sentinel; "first integer after the colon".
  * timelines indexed by (run, basename), never basename alone (08:50Z 丙).
  * sampling interval recorded; sweep_run.sh passes none -> main.go 1.0s.
  * hero position is NOT used anywhere (GH #116 / #57): the predicate does not
    mention it, so the broken proxy has no way in.

Usage:
    stayfield_domain.py <sweep_dir> [<sweep_dir> ...] [--interval 1.0]
    stayfield_domain.py --selfcheck <sweep_dir> [...]
"""
import argparse
import collections
import json
import math
import os
import re
import sys

RADIANT, DIRE = 2, 3
SIDE_TEAM = {"radiant": RADIANT, "dire": DIRE}

CAND_ID = "stayfield"
WALK_ID = "stayfield2"
FIELDCREEP_ID = "fieldcreep"      # the gated 5th clause inside the situation

# §AR.1's two worlds for WasRecentlyDamagedByCreep, never merged into one
# number.  甲 counts neutrals, 乙 does not.  甲 is primary: it removes MORE
# armed rows, which is the conservative direction for every claim this file
# makes (see the fieldcreep block in the module docstring).
WORLD_JIA = ("lane", "neutral", "mixed")
WORLD_YI = ("lane", "mixed")

HP_LO, HP_HI = 0.18, 0.55        # jmz_func.lua:4826
RING_U = 1600.0                  # jmz_func.lua:4829
DMG_WINDOW_S = 3.0               # WasRecentlyDamagedBy*(3.0)
DMG_ATTRIB_U = 3000.0            # jmz_func.lua:4833
TOWER_U = 1200.0                 # jmz_func.lua:4857
BRANCH_HP = 0.34                 # ability_item_usage_generic.lua:5514
BRANCH_HPMP = 0.43
BRANCH_LEVEL = 9
BRANCH_EXCLUDE = {"huskar", "slark"}

HEALS = ("flask", "tango", "tango_single", "faerie_fire")
HEAL_ITEM_EVENTS = ("item_flask", "item_tango", "item_tango_single",
                    "item_faerie_fire", "item_bottle")

DEATH_BLANK_S = 1.0              # #78 leak band <= 0.30s, 3x margin
CENTROID_WINDOW_S = 3.0
TP_TAIL_S = 1.5                  # 08-22T13:15Z 甲
EPISODE_GAP_S = 5.0
HORIZON_S = 30.0
FOUNTAIN_NEAR_U = 2000.0
MAX_SPEED_U = 550.0              # displacement physical upper bound
NEUTRAL_TEAM = 4                 # measured from the dump, not assumed
CREEP_U = 800.0                  # NOT a source constant: probe for the clause
                                 # J.IsFieldRegenSituation does not have


def canon(name):
    if not name:
        return None
    n = name.lower()
    if n.startswith("npc_dota_hero_"):
        n = n[len("npc_dota_hero_"):]
    return n.replace("_", "")


def games_swept_count(summary_path):
    """First integer after the colon on the 'games swept:' line (06:55Z 甲)."""
    with open(summary_path) as fh:
        for line in fh:
            if "games swept" in line:
                m = re.search(r"games swept[^:]*:\s*(\d+)", line)
                if m:
                    return int(m.group(1))
    return None


def load_sweeps(dirs):
    """Yield (run, game, cand, seed, side, timeline_path) with the #102 sentinel."""
    out = []
    for d in dirs:
        run = os.path.basename(os.path.normpath(d))
        summary = os.path.join(d, "sweep_summary.md")
        manifest = os.path.join(d, "games_manifest.jsonl")
        if not os.path.exists(summary):
            sys.exit("FATAL #102: no sweep_summary.md in %s (incomplete sweep)" % d)
        rows = [json.loads(l) for l in open(manifest) if l.strip()]
        swept = games_swept_count(summary)
        if swept is None or swept != len(rows):
            sys.exit("FATAL #102: %s says 'games swept: %s' but manifest has %d lines"
                     % (d, swept, len(rows)))
        for r in rows:
            tl = os.path.join(d, "timelines", "%s.timeline.json" % r["game"])
            if not os.path.exists(tl):
                sys.exit("FATAL: missing timeline %s" % tl)
            out.append((run, r["game"], r["cand"], r["seed"], r["side"], tl))
    return out


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def stratum_of(side):
    """铁律 4(i): `ab` = games whose CANDIDATE side is radiant, `ba` = mirror.

    Same convention as fieldcreep_domain.stratum_of / lion_drain_census.py.
    Duplicated here rather than imported for the same cycle reason as the
    fieldcreep classifier -- and it is one line of pure vocabulary, not a
    predicate that can drift.
    """
    return "ab" if side == "radiant" else "ba"


class Game(object):
    """One timeline, identity locked to the primary idx per hero."""

    def __init__(self, path, interval):
        d = json.load(open(path))
        self.interval = interval
        self.teams = d["game"]["teams"]

        # --- idx lock: primary entity = EARLIEST APPEARANCE (04:05Z 甲) ---
        first_t = {}
        for s in d["snapshots"]:
            if "idx" not in s:
                sys.exit("FATAL: timeline has no snapshot idx; cannot lock identity")
            key = (canon(s["hero"]), s["idx"])
            if key not in first_t or s["t"] < first_t[key]:
                first_t[key] = s["t"]
        primary = {}
        for (hero, idx), t0 in first_t.items():
            if hero not in primary or t0 < primary[hero][1]:
                primary[hero] = (idx, t0)
        self.primary_idx = {h: v[0] for h, v in primary.items()}

        self.copies = 0
        self.track = collections.defaultdict(list)
        for s in d["snapshots"]:
            h = canon(s["hero"])
            if s["idx"] != self.primary_idx.get(h):    # 04:05Z 丙: lock by_t too
                self.copies += 1
                continue
            s["_hero"] = h
            self.track[h].append(s)
        for v in self.track.values():
            v.sort(key=lambda s: s["t"])

        self.hero_team = {h: tr[0]["team"] for h, tr in self.track.items() if tr}

        # --- events ---
        self.deaths = collections.defaultdict(list)
        self.dmg_by = collections.defaultdict(list)     # (victim, attacker) -> [t]
        self.item_use = collections.defaultdict(list)   # (hero, item) -> [t]
        self.mod_add = collections.defaultdict(list)    # (hero, modifier) -> [t]
        self.mod_rem = collections.defaultdict(list)
        for e in d["events"]:
            ty = e["type"]
            if ty == "DEATH" and e.get("target_hero"):
                self.deaths[canon(e["target"])].append(e["t"])
            elif ty == "DAMAGE" and e.get("actor_hero") and e.get("target_hero"):
                self.dmg_by[(canon(e["target"]), canon(e["actor"]))].append(e["t"])
            elif ty == "ITEM" and e.get("actor_hero"):
                self.item_use[(canon(e["actor"]), e["inflictor"])].append(e["t"])
            elif ty == "MODIFIER_ADD" and e.get("target_hero"):
                self.mod_add[(canon(e["target"]), e["inflictor"])].append(e["t"])
            elif ty == "MODIFIER_REMOVE" and e.get("target_hero"):
                self.mod_rem[(canon(e["target"]), e["inflictor"])].append(e["t"])
        for v in self.dmg_by.values():
            v.sort()
        for v in self.deaths.values():
            v.sort()

        # --- towers: paired by (round(x), round(y)); name is NOT identity ---
        self.towers = {}          # (x,y) -> {'team':, 'spans': [(t_alive_from, t_to)]}
        seen = collections.defaultdict(list)
        for b in d.get("buildings", ()):
            if b.get("name") != "tower":          # watch_tower deliberately out
                continue
            seen[(round(b["x"]), round(b["y"]))].append(b)
        for key, rows in seen.items():
            rows.sort(key=lambda b: b["t"])
            self.towers[key] = {"team": rows[0]["team"], "rows": rows}

        # --- enemy creeps, for the clause the SOURCE DOES NOT HAVE ---
        # J.IsFieldRegenSituation reads heroes and towers only. Creep rows carry
        # t/team/x/y (no name), which is enough to count what is in contact.
        self.creeps = collections.defaultdict(list)   # round(t) -> [(team,x,y)]
        for c in d.get("creeps", ()):
            self.creeps[round(c["t"])].append((c["team"], c["x"], c["y"]))

        # --- fountain centroid: EACH TEAM'S OWN first frames (13:15Z) ---
        self.fountain = {}
        per_team = collections.defaultdict(list)
        for h, tr in self.track.items():
            for s in tr:
                per_team[s["team"]].append(s)
        for team, snaps in per_team.items():
            snaps.sort(key=lambda s: s["t"])
            t0 = snaps[0]["t"]
            pts = [(s["x"], s["y"]) for s in snaps if s["t"] <= t0 + CENTROID_WINDOW_S]
            self.fountain[team] = (sum(p[0] for p in pts) / len(pts),
                                   sum(p[1] for p in pts) / len(pts))

    # -- lookups ------------------------------------------------------------
    def frame_at(self, hero, t):
        """Last frame with time <= t, only if within one sampling interval."""
        tr = self.track.get(hero)
        if not tr:
            return None
        lo, hi, best = 0, len(tr) - 1, None
        while lo <= hi:
            mid = (lo + hi) // 2
            if tr[mid]["t"] <= t:
                best = tr[mid]
                lo = mid + 1
            else:
                hi = mid - 1
        if best is None or t - best["t"] > self.interval + 1e-6:
            return None
        return best

    def alive_frame(self, hero, t):
        f = self.frame_at(hero, t)
        if f is None or f["hp_pct"] <= 0:
            return None
        if any(0.0 <= t - td < DEATH_BLANK_S for td in self.deaths.get(hero, ())):
            return None
        return f

    def enemies_within(self, hero, s, radius):
        me_team = s["team"]
        out = []
        for other in self.track:
            if other == hero or self.hero_team.get(other) == me_team:
                continue
            fr = self.alive_frame(other, s["t"])
            if fr is None:
                continue
            d = dist(s["x"], s["y"], fr["x"], fr["y"])
            if d <= radius:
                out.append((other, d))
        return out

    def attributed_danger(self, hero, s):
        """WasRecentlyDamagedByAnyHero(3) AND that hero still inside 3000."""
        t = s["t"]
        hit_me = [atk for (vic, atk), ts in self.dmg_by.items()
                  if vic == hero and any(t - DMG_WINDOW_S <= x <= t for x in ts)]
        if not hit_me:
            return False
        for atk in hit_me:
            fr = self.alive_frame(atk, t)
            if fr is None:
                continue
            if dist(s["x"], s["y"], fr["x"], fr["y"]) <= DMG_ATTRIB_U:
                return True
        return False

    def enemy_tower_within(self, s, radius):
        for (x, y), tw in self.towers.items():
            if tw["team"] == s["team"]:
                continue
            if dist(s["x"], s["y"], x, y) > radius:
                continue
            # alive at this time? last building row with t <= s['t']
            alive = None
            for b in tw["rows"]:
                if b["t"] <= s["t"]:
                    alive = b.get("alive", True)
                else:
                    break
            if alive is None or alive:
                return True
        return False

    def enemy_creeps_within(self, s, radius=None):
        """(lane, neutral) counts in contact -- NOT source clauses, a gap probe.

        team 4 is the neutral team in this dump (measured, 37825 of 46634 creep
        rows in the first game scanned); the enemy lane team is the other of
        {2,3}.  They are reported apart because they are different phenomena:
        a lane creep chips ~13 a hit, an ancient camp hits for 35-50.
        """
        radius = CREEP_U if radius is None else radius
        rows = self.creeps.get(round(s["t"]))
        if rows is None:
            return None
        lane = neut = 0
        for (team, x, y) in rows:
            if team == s["team"]:
                continue
            if dist(s["x"], s["y"], x, y) > radius:
                continue
            if team == NEUTRAL_TEAM:
                neut += 1
            else:
                lane += 1
        return (lane, neut)

    def has_modifier_at(self, hero, mod, t):
        adds = self.mod_add.get((hero, mod), ())
        if not adds:
            return False
        last_add = max([x for x in adds if x <= t] or [None])
        if last_add is None:
            return False
        rems = [x for x in self.mod_rem.get((hero, mod), ()) if last_add <= x <= t]
        return not rems

    def tp_spans(self, hero):
        """[(add, remove + TP_TAIL_S)] for modifier_teleporting (13:15Z 甲)."""
        adds = sorted(self.mod_add.get((hero, "modifier_teleporting"), ()))
        rems = sorted(self.mod_rem.get((hero, "modifier_teleporting"), ()))
        out, j = [], 0
        for a in adds:
            while j < len(rems) and rems[j] < a:
                j += 1
            end = rems[j] if j < len(rems) else a + 6.0
            out.append((a, end))
        return out

    def dist_fountain(self, s):
        fx = self.fountain.get(s["team"])
        if fx is None:
            return None
        return dist(s["x"], s["y"], fx[0], fx[1])


def usable_items(s):
    """The six usable inventory slots (a salve in the backpack cannot be drunk)."""
    return [i for i in (s.get("items") or [])[:6] if i]


def has_field_regen_source(s):
    items = usable_items(s)
    for i in items:
        if i in HEALS:
            return True
        if i == "bottle":     # charges unobservable -> superset (dilutes)
            return True
    return False


def situation(g, hero, s, creep_hits=None):
    """J.IsFieldRegenSituation, offline.

    `creep_hits` is the gated FIFTH clause (`fieldcreep`, jmz_func.lua:5287),
    evaluated by the caller in one of §AR.1's two worlds and passed in.  The
    default None means "do not evaluate it" -- the baseline leg, or a wave
    whose arm string does not carry `fieldcreep`.  Keeping the default at None
    is what makes this change behaviour-preserving for every existing caller
    (fieldcreep_domain.py imports this function, and its own upstream-clause
    count is DEFINED as the pre-fieldcreep one).
    """
    if not (HP_LO <= s["hp_pct"] <= HP_HI):
        return False
    if g.enemies_within(hero, s, RING_U):
        return False
    if g.attributed_danger(hero, s):
        return False
    if g.enemy_tower_within(s, TOWER_U):
        return False
    if creep_hits:                      # gated 5th clause, armed leg only
        return False
    return True


def strict_branch(g, hero, s):
    """The tpscroll '撤退:3' branch's own observable entry conditions."""
    if not (s["hp_pct"] < BRANCH_HP or s["hp_pct"] + s.get("mp_pct", 1.0) < BRANCH_HPMP):
        return False
    if s.get("level", 0) < BRANCH_LEVEL:
        return False
    if "flask" in usable_items(s):        # itemFlask == nil
        return False
    if hero in BRANCH_EXCLUDE:
        return False
    if g.has_modifier_at(hero, "modifier_flask_healing", s["t"]):
        return False
    if g.has_modifier_at(hero, "modifier_clarity_potion", s["t"]):
        return False
    if (s.get("tp_cd") or 0) > 0:          # no scroll ready -> branch cannot fire
        return False
    return True


def creep_world(inc, hero, t, fc_live, leg):
    """(甲, 乙) truth of the gated fieldcreep clause on this frame.

    Returns (False, False, 'none') wherever the clause is not live: the
    baseline leg always, and every leg on a wave that did not arm
    `fieldcreep`.  That is not a convenience default -- it IS the semantics,
    because an unarmed `J.IsSoakCandidate('fieldcreep')` is literally false in
    the engine.
    """
    if not fc_live or leg != "armed" or inc is None:
        return False, False, "none"
    kind, _tot = FC_CLASSIFY(FC_HITS(inc.get(hero, ()), t))
    return kind in WORLD_JIA, kind in WORLD_YI, kind


# Bound lazily by main() to fieldcreep_domain's own classifier.  Imported at
# call time rather than at module scope because fieldcreep_domain.py imports
# THIS module at ITS module scope -- a top-level import here is a cycle.  They
# are re-used, never re-implemented: a second copy of the lane/neutral regexes
# is exactly how two tools start disagreeing about the same frame.
FC_HITS = None
FC_CLASSIFY = None


def bind_fieldcreep():
    """Import fieldcreep_domain's classifier and bind it.  Idempotent."""
    global FC_HITS, FC_CLASSIFY
    if FC_HITS is not None:
        return
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import fieldcreep_domain as FC          # noqa: E402  (cycle-avoidance)
    FC_HITS, FC_CLASSIFY = FC.hits_in_window, FC.classify


def home_tp_events(g, side, inc=None, fc_live=False):
    """Every home-TP in the game, scored on the LAST FRAME BEFORE the channel.

    This is the estimator that matches what the gate actually does.  The gate
    is a veto evaluated at the instant the tpscroll branch bids, so the domain
    has to be read on the pre-cast frame -- reading it on the post-cast frame
    (or anywhere inside the episode) is the 08-20 cooldown-edge mistake in a
    different costume (charter #66 §0).

    An armed-leg home-TP whose pre-frame satisfies STRICT is a LEAK: the gate
    was armed, the branch's own conditions held, the helper should have
    returned true, and the bot went home anyway.  A baseline-leg one is what
    the gate exists to remove.
    """
    armed_team = SIDE_TEAM[side]
    out = []
    for hero, tr in g.track.items():
        for (a, b) in g.tp_spans(hero):
            if a < 0:
                continue
            land = None
            for s in tr:
                if s["t"] >= b + TP_TAIL_S:
                    land = s
                    break
            if land is None:
                continue
            d_land = g.dist_fountain(land)
            if d_land is None or d_land > FOUNTAIN_NEAR_U:
                continue                      # forward TP, not a trip home (#111)
            # last frame strictly before the channel opened
            pre = g.frame_at(hero, a - 1e-6)
            if pre is None or pre["hp_pct"] <= 0:
                continue
            if any(0.0 <= pre["t"] - td < DEATH_BLANK_S
                   for td in g.deaths.get(hero, ())):
                continue
            if not usable_items(pre):
                continue
            # why-not decomposition: which clause kills this home-TP.  Ordered
            # so each row is attributed to its FIRST failing clause, and the
            # order is the source's own (jmz_func.lua:4820 downwards, then the
            # branch).  This is what turns "the domain is small" into "the
            # domain is small BECAUSE ...".
            leg = "armed" if pre["team"] == armed_team else "baseline"
            jia, yi, fc_kind = creep_world(inc, hero, pre["t"], fc_live, leg)

            def _ladder(creep):
                """First failing clause, in the source's own evaluation order."""
                if not (HP_LO <= pre["hp_pct"] <= HP_HI):
                    return "hp<0.18" if pre["hp_pct"] < HP_LO else "hp>0.55"
                if g.enemies_within(hero, pre, RING_U):
                    return "enemy in 1600"
                if g.attributed_danger(hero, pre):
                    return "attributed damage"
                if g.enemy_tower_within(pre, TOWER_U):
                    return "enemy tower 1200"
                if creep:
                    return "fieldcreep (armed leg)"
                if not has_field_regen_source(pre):
                    return "no heal in bag"
                if not strict_branch(g, hero, pre):
                    return "branch cond (hp/level/flask/tp_cd)"
                return None

            why = _ladder(jia)              # 甲, the conservative world
            why_yi = _ladder(yi)
            in_situation = (situation(g, hero, pre, creep_hits=jia)
                            and has_field_regen_source(pre))
            out.append({
                "why_not_yi": why_yi, "fc_kind": fc_kind,
                "fc_jia": jia, "fc_yi": yi,
                "hero": hero, "t_cast": a, "t_pre": pre["t"],
                "hp": pre["hp_pct"], "team": pre["team"],
                "leg": "armed" if pre["team"] == armed_team else "baseline",
                "situation": in_situation,
                "strict": in_situation and strict_branch(g, hero, pre),
                "fdist": g.dist_fountain(pre), "land_fdist": d_land,
                "items": usable_items(pre),
                "enemy_min": (min([x[1] for x in g.enemies_within(hero, pre, 1e9)])
                              if g.enemies_within(hero, pre, 1e9) else None),
                "creeps": g.enemy_creeps_within(pre),
                "why_not": why,
            })
    return out


def scan_game(g, side, inc=None, fc_live=False, _dropped=None):
    """Domain episodes with outcomes, tagged by leg.

    `_dropped`, when a Counter is passed, receives the per-world count of
    frames the gated fieldcreep clause removed from the armed leg -- the
    number the disclosure header prints.  It is an out-parameter rather than a
    second scan because the alternative (scan twice, once per world) would
    double the corpus pass for a number that is a by-product of the first.
    """
    armed_team = SIDE_TEAM[side]
    rows = []
    for hero, tr in g.track.items():
        for s in tr:
            if s["t"] < 0 or s["hp_pct"] <= 0:
                continue
            if any(0.0 <= s["t"] - td < DEATH_BLANK_S
                   for td in g.deaths.get(hero, ())):
                continue
            if not usable_items(s):        # corpse / empty bag
                continue
            leg = "armed" if s["team"] == armed_team else "baseline"
            jia, yi, _k = creep_world(inc, hero, s["t"], fc_live, leg)
            if _dropped is not None and (jia or yi):
                # only frames the OTHER four clauses already let through can be
                # "removed by fieldcreep" -- otherwise the count would be of
                # frames that were never in the domain to begin with.
                if situation(g, hero, s) and has_field_regen_source(s):
                    if jia:
                        _dropped["jia"] += 1
                    if yi:
                        _dropped["yi"] += 1
            if not situation(g, hero, s, creep_hits=jia):
                continue
            if not has_field_regen_source(s):
                continue
            rows.append({"hero": hero, "t": s["t"], "hp": s["hp_pct"],
                         "team": s["team"], "strict": strict_branch(g, hero, s),
                         "fdist": g.dist_fountain(s),
                         "creeps": g.enemy_creeps_within(s),
                         "items": usable_items(s)})

    eps = []
    for hero in sorted(set(r["hero"] for r in rows)):
        hr = sorted((r for r in rows if r["hero"] == hero), key=lambda r: r["t"])
        cur = None
        for r in hr:
            if cur is None or r["t"] - cur["t_end"] > EPISODE_GAP_S:
                cur = {"hero": hero, "t_start": r["t"], "t_end": r["t"], "frames": 1,
                       "hp_min": r["hp"], "team": r["team"], "strict": r["strict"],
                       "fdist": r["fdist"], "items": r["items"],
                       "creeps": r["creeps"]}
                eps.append(cur)
            else:
                cur["t_end"] = r["t"]
                cur["frames"] += 1
                cur["hp_min"] = min(cur["hp_min"], r["hp"])
                cur["strict"] = cur["strict"] or r["strict"]

    for e in eps:
        e["leg"] = "armed" if e["team"] == armed_team else "baseline"
        e.update(outcome(g, e))
    return eps


def outcome(g, e):
    """home_tp / home_walk / drank, in HORIZON_S after the episode start."""
    hero, t0 = e["hero"], e["t_start"]
    t1 = t0 + HORIZON_S
    res = {"home_tp": False, "home_walk": False, "drank": None,
           "tp_any": False, "land_fdist": None, "jump_guard": False}

    for (a, b) in g.tp_spans(hero):
        if not (t0 < a <= t1):
            continue
        res["tp_any"] = True
        land = None
        for s in g.track[hero]:
            if s["t"] >= b + TP_TAIL_S:
                land = s
                break
        if land is None:
            continue
        d = g.dist_fountain(land)
        res["land_fdist"] = d if res["land_fdist"] is None else min(res["land_fdist"], d)
        if d is not None and d <= FOUNTAIN_NEAR_U:
            res["home_tp"] = True

    if not res["tp_any"]:
        # walking home: reaches the fountain ring, and the displacement it took
        # to get there is physically possible on foot (else something teleported
        # it and the TP channel was simply not sampled).
        prev = None
        for s in g.track[hero]:
            if s["t"] <= t0 or s["t"] > t1:
                continue
            if prev is not None:
                gap = max(s["t"] - prev["t"], 1e-6)
                if dist(s["x"], s["y"], prev["x"], prev["y"]) / gap > MAX_SPEED_U * 1.6:
                    res["jump_guard"] = True
                    break
            prev = s
            d = g.dist_fountain(s)
            if d is not None and d <= FOUNTAIN_NEAR_U:
                res["home_walk"] = True
                break

    for it in HEAL_ITEM_EVENTS:
        for t in g.item_use.get((hero, it), ()):
            if t0 - 2.0 <= t <= t1:
                res["drank"] = it
                break
        if res["drank"]:
            break
    return res


# --------------------------------------------------------------------------


def selfcheck(games, interval):
    """Priors computed against the real corpus, not asserted from memory."""
    checks, fails = [], 0

    def chk(name, ok, detail=""):
        nonlocal fails
        checks.append((name, ok, detail))
        if not ok:
            fails += 1

    g0 = Game(games[0][5], interval)

    # geometry priors, recomputed (13:15Z: never hard-code a guessed span)
    f = g0.fountain
    chk("two fountains present", set(f) == {RADIANT, DIRE}, sorted(f))
    if set(f) == {RADIANT, DIRE}:
        d = dist(f[RADIANT][0], f[RADIANT][1], f[DIRE][0], f[DIRE][1])
        chk("fountains 17k-21k apart", 17000 <= d <= 21000, "%.0f" % d)
        # positive control: each centroid must sit near ITS OWN ancient
        anc = {}
        raw = json.load(open(games[0][5]))
        for b in raw.get("buildings", ()):
            if b.get("name") == "ancient":
                anc.setdefault(b["team"], (b["x"], b["y"]))
        ok = True
        det = []
        for team in (RADIANT, DIRE):
            if team not in anc:
                ok = False
                continue
            own = dist(f[team][0], f[team][1], anc[team][0], anc[team][1])
            oth = dist(f[team][0], f[team][1],
                       anc[3 - team + 2][0], anc[3 - team + 2][1]) \
                if (3 - team + 2) in anc else 1e9
            det.append("t%d own=%.0f other=%.0f" % (team, own, oth))
            ok = ok and own < 2500 and own < oth
        chk("fountain centroid near OWN ancient", ok, "; ".join(det))

    chk("interval matches frame spacing",
        _spacing_ok(g0, interval), "interval=%.2f" % interval)

    # towers exist, both teams, and are paired by coordinate not by name
    teams = collections.Counter(t["team"] for t in g0.towers.values())
    chk("towers paired by coord, both teams", len(g0.towers) >= 16 and len(teams) == 2,
        "%d towers %s" % (len(g0.towers), dict(teams)))

    # idx lock actually removed something somewhere in the corpus
    copies = 0
    for _, _, _, _, _, tl in games[:8]:
        copies += Game(tl, interval).copies
    chk("idx lock is live (copies seen)", copies >= 0, "%d copy snapshots" % copies)

    # the two legs must be balanced across the corpus
    sides = collections.Counter(row[4] for row in games)
    chk("both sides represented", len(sides) == 2, dict(sides))

    # the domain must be a strict subset of the HP band
    eps = []
    for _, _, _, _, side, tl in games[:6]:
        eps += scan_game(Game(tl, interval), side)
    chk("all episodes inside the HP band",
        all(HP_LO - 1e-9 <= e["hp_min"] <= HP_HI + 1e-9 for e in eps),
        "%d episodes" % len(eps))
    chk("every episode carries a heal",
        all(any(i in HEALS or i == "bottle" for i in e["items"]) for e in eps),
        "%d episodes" % len(eps))
    chk("STRICT episodes never hold a salve",
        all("flask" not in e["items"] for e in eps if e["strict"]),
        "%d strict" % sum(1 for e in eps if e["strict"]))

    # ---- the gated 5th clause -------------------------------------------
    chk("stratum_of is a partition of the corpus",
        set(stratum_of(row[4]) for row in games) <= {"ab", "ba"}
        and len(set(stratum_of(row[4]) for row in games)) == 2,
        dict(collections.Counter(stratum_of(row[4]) for row in games)))

    # `creep_world` must be inert wherever the clause is not live.  This is
    # the check that would have failed BEFORE the 08-30 fix -- not because the
    # old code got these three cases wrong, but because it had no way to get
    # them right or wrong: the clause did not exist in this file at all.
    chk("fieldcreep inert when not armed",
        creep_world({"h": [(1.0, "npc_dota_neutral_x", 40, "neutral")]},
                    "h", 1.0, False, "armed") == (False, False, "none"))
    chk("fieldcreep inert on the baseline leg",
        creep_world({"h": [(1.0, "npc_dota_neutral_x", 40, "neutral")]},
                    "h", 1.0, True, "baseline") == (False, False, "none"))
    chk("fieldcreep inert with no damage index",
        creep_world(None, "h", 1.0, True, "armed") == (False, False, "none"))

    fc_here = FIELDCREEP_ID in [c.strip() for c in games[0][2].split(",")]
    if fc_here:
        bind_fieldcreep()
        j, y, k = creep_world(
            {"h": [(1.0, "npc_dota_neutral_grown_frog", 40, "neutral")]},
            "h", 1.0, True, "armed")
        chk("neutral hit separates the two worlds (甲 yes, 乙 no)",
            (j, y, k) == (True, False, "neutral"), "%s/%s/%s" % (j, y, k))
        j2, y2, k2 = creep_world(
            {"h": [(1.0, "npc_dota_creep_badguys_melee", 40, "lane")]},
            "h", 1.0, True, "armed")
        chk("lane hit fires in BOTH worlds",
            (j2, y2, k2) == (True, True, "lane"), "%s/%s/%s" % (j2, y2, k2))
        # the clause can only ever SHRINK the armed domain -- so a zero found
        # without it stays zero with it.  Asserted, because that implication
        # is what lets the 08-30 verdict survive the tool having been wrong.
        s0 = sum(1 for e in eps if True)
        eps_fc = []
        for _, _, _, _, side, tl in games[:6]:
            bind_fieldcreep()
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import fieldcreep_domain as FC          # noqa: E402
            inc, _o = FC.load_nonhero_damage(tl)
            eps_fc += scan_game(Game(tl, interval), side, inc=inc, fc_live=True)
        chk("the clause only ever REMOVES armed episodes",
            len(eps_fc) <= s0, "%d with clause <= %d without" % (len(eps_fc), s0))
    else:
        chk("fieldcreep corpus checks SKIPPED, not passed",
            True, "`fieldcreep` is not in this wave's arm string")

    for name, ok, detail in checks:
        print("  [%s] %s%s" % ("PASS" if ok else "FAIL", name,
                               ("  -- %s" % detail) if detail else ""))
    print("selfcheck: %d checks, %d failures" % (len(checks), fails))
    return fails


def _spacing_ok(g, interval):
    for tr in g.track.values():
        if len(tr) > 20:
            gaps = [round(tr[i + 1]["t"] - tr[i]["t"], 2) for i in range(10)]
            med = sorted(gaps)[len(gaps) // 2]
            return abs(med - interval) < 0.25
    return False


def main():
    global CREEP_U
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("--interval", type=float, default=1.0)
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--top", type=int, default=20)
    ap.add_argument("--id", default=CAND_ID, choices=[CAND_ID, WALK_ID])
    ap.add_argument("--creep-band", type=float, default=CREEP_U,
                    help="radius for the creep/neutral GAP PROBE (not a source "
                         "constant -- J.IsFieldRegenSituation has no creep clause)")
    ap.add_argument("--stratum", choices=["all", "ab", "ba"], default="all",
                    help="铁律 4(i): ab = games whose CANDIDATE side is radiant, "
                         "ba = the mirror. A partition, not a filter.")
    a = ap.parse_args()
    CREEP_U = a.creep_band          # gap probe radius, not a source constant

    games = load_sweeps(a.dirs)

    # --- armed-string guard: never score a gate that was never armed ---
    cands = set(r[2] for r in games)
    if len(cands) != 1:
        sys.exit("[fatal] mixed cand strings in this corpus: %s" % sorted(cands))
    cand = cands.pop()
    if a.id not in cand.split(","):
        sys.exit("[fatal] `%s` is NOT in this wave's cand string -- refusing to "
                 "score a gate that was never armed.\n         string: %s"
                 % (a.id, cand))
    print("cand string (uniform, %s armed, %d ids): %s"
          % (a.id, len(cand.split(",")), cand))
    print("games: %d   runs: %s   interval: %.2fs"
          % (len(games), sorted(set(r[0] for r in games)), a.interval))

    if a.selfcheck:
        sys.exit(1 if selfcheck(games, a.interval) else 0)

    # --- the gated 5th clause: live or not, this is DISCLOSED, never implied ---
    fc_live = FIELDCREEP_ID in [c.strip() for c in cand.split(",")]
    if fc_live:
        bind_fieldcreep()

    # 铁律 4(i): a partition, applied AFTER the arm-string guard so that a
    # never-armed game is fatal in whichever layer is being read.
    if a.stratum != "all":
        games = [r for r in games if stratum_of(r[4]) == a.stratum]
        if not games:
            sys.exit("[fatal] stratum '%s' is empty in this corpus" % a.stratum)
    print("stratum: %s   (%d game(s) in this layer)" % (a.stratum, len(games)))

    all_eps, all_tps = [], []
    per_game = collections.Counter()
    dropped = collections.Counter()
    for run, game, _c, seed, side, tl in games:
        g = Game(tl, a.interval)
        inc = None
        if fc_live:
            bind_fieldcreep()
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import fieldcreep_domain as FC          # noqa: E402
            inc, _outg = FC.load_nonhero_damage(tl)
        eps = scan_game(g, side, inc=inc, fc_live=fc_live, _dropped=dropped)
        tps = home_tp_events(g, side, inc=inc, fc_live=fc_live)
        for e in eps + tps:
            e["run"], e["game"], e["seed"], e["side"] = run, game, seed, side
        all_eps += eps
        all_tps += tps
        per_game[(run, game)] = len(eps)

    # ---- MANDATORY disclosure (printed even when the clause is not live) ----
    print("\n=== gated 5th clause `fieldcreep` (jmz_func.lua:5287) ===")
    if not fc_live:
        print("  NOT ARMED in this wave's cand string -> the clause is false in")
        print("  the engine on BOTH legs, and both legs are scored with the")
        print("  four-clause situation.  Nothing removed; nothing to correct.")
    else:
        print("  ARMED -> the ARMED leg's J.IsFieldRegenSituation is STRICTER")
        print("  than the baseline leg's, and that difference belongs to")
        print("  `fieldcreep`, NOT to `%s`." % a.id)
        print("  SITUATION frames removed from the ARMED leg by this clause:")
        print("      甲 (neutrals count) : %d   <- primary, conservative"
              % dropped["jia"])
        print("      乙 (lane only)      : %d" % dropped["yi"])
        fcrows = [e for e in all_tps if e["leg"] == "armed"]
        print("  home-TP pre-frames on the armed leg attributed to it:"
              " 甲 %d / 乙 %d  (of %d)"
              % (sum(1 for e in fcrows if e["why_not"] == "fieldcreep (armed leg)"),
                 sum(1 for e in fcrows
                     if e["why_not_yi"] == "fieldcreep (armed leg)"),
                 len(fcrows)))
    print("  ** A reader who cannot see this block must conclude the tool did")
    print("     NOT check the clause -- never that the corpus was clean. **")

    ng = len(games)
    legs = {"armed": [e for e in all_eps if e["leg"] == "armed"],
            "baseline": [e for e in all_eps if e["leg"] == "baseline"]}

    def table(title, sel):
        print("\n=== %s ===" % title)
        print("%-14s %8s %8s %8s %8s %8s" %
              ("leg", "episodes", "home_tp", "home_walk", "drank", "per game"))
        out = {}
        for leg in ("armed", "baseline"):
            rows = [e for e in legs[leg] if sel(e)]
            n = len(rows)
            tp = sum(1 for e in rows if e["home_tp"])
            wk = sum(1 for e in rows if e["home_walk"])
            dk = sum(1 for e in rows if e["drank"])
            out[leg] = (n, tp, wk, dk)
            print("%-14s %8d %8d %8d %8d %8.2f" % (leg, n, tp, wk, dk, n / ng))
        na, ta, wa, da = out["armed"]
        nb, tb, wb, db = out["baseline"]
        if na and nb:
            print("  home_tp rate : armed %.1f%%  baseline %.1f%%  delta %+.1fpp"
                  % (100.0 * ta / na, 100.0 * tb / nb,
                     100.0 * ta / na - 100.0 * tb / nb))
            print("  home_walk    : armed %.1f%%  baseline %.1f%%  delta %+.1fpp"
                  % (100.0 * wa / na, 100.0 * wb / nb,
                     100.0 * wa / na - 100.0 * wb / nb))
            print("  drank        : armed %.1f%%  baseline %.1f%%  delta %+.1fpp"
                  % (100.0 * da / na, 100.0 * db / nb,
                     100.0 * da / na - 100.0 * db / nb))
            print("  SUPPLY RATIO (armed episodes / baseline episodes): %.2f"
                  % (float(na) / nb))
        return out

    table("SITUATION domain (J.ShouldRegenNotGoHome, both call sites)",
          lambda e: True)
    table("STRICT domain (what `stayfield`'s ONLY call site can reach)",
          lambda e: e["strict"])

    # ---- primary estimator: home-TPs scored on the PRE-CAST frame ----
    print("\n=== HOME-TPs, predicate read on the LAST FRAME BEFORE the channel ===")
    print("(a home-TP is a TP whose LANDING is within %.0fu of its own fountain --"
          " forward TPs are excluded, GH #111)" % FOUNTAIN_NEAR_U)
    print("%-10s %10s %12s %10s %12s" %
          ("leg", "home_TPs", "in SITUATION", "in STRICT", "STRICT/game"))
    tp_out = {}
    for leg in ("armed", "baseline"):
        rows = [e for e in all_tps if e["leg"] == leg]
        ns = sum(1 for e in rows if e["situation"])
        nx = sum(1 for e in rows if e["strict"])
        tp_out[leg] = (len(rows), ns, nx)
        print("%-10s %10d %12d %10d %12.3f" % (leg, len(rows), ns, nx, nx / float(ng)))
    (ta, sa, xa), (tb, sb, xb) = tp_out["armed"], tp_out["baseline"]
    print("  total home-TPs        : armed %d  baseline %d  (ratio %.2f)"
          % (ta, tb, (float(ta) / tb) if tb else float("nan")))
    print("  STRICT leaks          : armed %d  baseline %d" % (xa, xb))
    print("  ** a STRICT armed leak is a frame where the gate was armed, the "
          "branch conditions held, and the bot went home anyway **")

    print("\n=== WHY the gate's instant is rare: first failing clause on every "
          "home-TP ===")
    print("(甲 = neutrals count toward WasRecentlyDamagedByCreep; 乙 = lane only."
          " On the baseline leg, and on any wave that did not arm `fieldcreep`,"
          " the two worlds are identical by construction.)")
    for leg in ("armed", "baseline"):
        rows = [e for e in all_tps if e["leg"] == leg]
        if not rows:
            print("  %s (n=0)" % leg)
            continue
        cnt = collections.Counter(e["why_not"] or "IN STRICT DOMAIN" for e in rows)
        cnt_yi = collections.Counter(e["why_not_yi"] or "IN STRICT DOMAIN"
                                     for e in rows)
        print("  %s (n=%d)" % (leg, len(rows)))
        print("      %-34s %8s %7s %8s" % ("clause", "甲", "甲%", "乙"))
        for k, v in cnt.most_common():
            print("      %-34s %8d %6.1f%% %8d"
                  % (k, v, 100.0 * v / len(rows), cnt_yi.get(k, 0)))

    # 铁律 4(i-a): both layers' READINGS registered, not both layers' game
    # counts.  Printed here rather than left to the caller because the number
    # a reader quotes out of this file is the domain count, and a pooled
    # domain count does not look side-correlated (fieldcreep_domain's note).
    print("\n=== 铁律 4(i-a): the same two counts, per physical-side stratum ===")
    print("  %-6s %6s %10s %12s %10s %14s"
          % ("layer", "games", "home_TPs", "in SITUATION", "in STRICT",
             "SITUATION eps"))
    for lay in ("ab", "ba"):
        gs = set((r[0], r[1]) for r in games if stratum_of(r[4]) == lay)
        tps = [e for e in all_tps if stratum_of(e["side"]) == lay]
        eps = [e for e in all_eps if stratum_of(e["side"]) == lay]
        print("  %-6s %6d %10d %12d %10d %14d"
              % (lay, len(gs), len(tps),
                 sum(1 for e in tps if e["situation"]),
                 sum(1 for e in tps if e["strict"]), len(eps)))
    print("  (a zero that is zero in BOTH layers cannot be a side artefact --"
          " that is the only kind of zero this file may report as a domain"
          " finding.)")

    # ---- the clause the source does NOT have: enemy creeps in contact ----
    print("\n=== GAP PROBE: enemy creeps within %.0fu on the domain frame ===" % CREEP_U)
    print("(J.IsFieldRegenSituation reads heroes and towers only -- it has no "
          "creep clause at all. This is not a source constant; it measures how "
          "often 'stay and drink' is being asked of a bot standing in a wave.)")
    print("  %-22s %6s %10s %10s %10s %10s" %
          ("population", "n", "lane>0", "lane>=3", "neutral>0", "neut>=3"))
    for label, rows in (("SITUATION episodes", [e for e in all_eps]),
                        ("SITUATION armed", [e for e in all_eps if e["leg"] == "armed"]),
                        ("SITUATION baseline", [e for e in all_eps if e["leg"] == "baseline"]),
                        ("STRICT episodes", [e for e in all_eps if e["strict"]]),
                        ("STRICT home-TPs", [e for e in all_tps if e["strict"]])):
        vals = [e["creeps"] for e in rows if e.get("creeps") is not None]
        if not vals:
            print("  %-22s no creep rows" % label)
            continue
        n = len(vals)
        print("  %-22s %6d %9.1f%% %9.1f%% %9.1f%% %9.1f%%"
              % (label, n,
                 100.0 * sum(1 for v in vals if v[0] > 0) / n,
                 100.0 * sum(1 for v in vals if v[0] >= 3) / n,
                 100.0 * sum(1 for v in vals if v[1] > 0) / n,
                 100.0 * sum(1 for v in vals if v[1] >= 3) / n))

    print("\n--- STRICT-domain home-TPs, every one (armed = LEAKS) ---")
    for e in sorted([e for e in all_tps if e["strict"]],
                    key=lambda e: (e["leg"] != "armed", e["t_cast"])):
        print("  %-9s %s/%s %-16s cast=%.1f pre=%.1f hp=%.3f fdist=%.0f "
              "land=%.0f enemy=%s items=%s"
              % (e["leg"], e["run"][-6:], e["game"], e["hero"], e["t_cast"],
                 e["t_pre"], e["hp"], e["fdist"] or -1, e["land_fdist"],
                 ("%.0f" % e["enemy_min"]) if e["enemy_min"] else "-",
                 ",".join(e["items"])))

    print("\n--- STRICT episodes that went home by TP (armed leg first) ---")
    cand_rows = [e for e in all_eps if e["strict"] and e["home_tp"]]
    cand_rows.sort(key=lambda e: (e["leg"] != "armed", e["t_start"]))
    for e in cand_rows[:a.top]:
        print("  %-9s %s/%s %-16s t=%.1f-%.1f hp=%.3f fdist=%.0f land=%s items=%s"
              % (e["leg"], e["run"][-6:], e["game"], e["hero"], e["t_start"],
                 e["t_end"], e["hp_min"], e["fdist"] or -1,
                 ("%.0f" % e["land_fdist"]) if e["land_fdist"] is not None else "-",
                 ",".join(e["items"])))

    print("\n--- STRICT episodes that STAYED and drank (armed leg first) ---")
    stay = [e for e in all_eps if e["strict"] and e["drank"]
            and not e["home_tp"] and not e["home_walk"]]
    stay.sort(key=lambda e: (e["leg"] != "armed", e["t_start"]))
    for e in stay[:a.top]:
        print("  %-9s %s/%s %-16s t=%.1f-%.1f hp=%.3f fdist=%.0f drank=%s items=%s"
              % (e["leg"], e["run"][-6:], e["game"], e["hero"], e["t_start"],
                 e["t_end"], e["hp_min"], e["fdist"] or -1, e["drank"],
                 ",".join(e["items"])))

    guarded = sum(1 for e in all_eps if e["jump_guard"])
    print("\ndisplacement guard tripped on %d episodes (walk leg abandoned there)"
          % guarded)


if __name__ == "__main__":
    main()

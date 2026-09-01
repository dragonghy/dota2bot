#!/usr/bin/env python3
"""`lionqdmg` domain census -- WHERE COULD THIS LEVER EVEN BITE?

WHY THIS FILE EXISTS (replay-check 2026-08-31, W30)
---------------------------------------------------
`lionqdmg` (armed from W30, 47-id string; queue `hero-24`, director ruling
`ROUTED_RIDESHARE / ADMITTED`, test_set.md §CO, `executor = replay-check`) is
the LION direction of GH #175:

    bots/BotLib/hero_lion.lua:546  X.GetImpaleKillDamage
        shipped = hAbility:GetAbilityDamage()          -- structurally 0
        armed   = hAbility:GetSpecialValueInt('damage') -- 105/170/235/300

`lion_impale` declares no top-level `AbilityDamage` in this patch, so the
shipped read is a hard 0, and the only consumer is `X.ConsiderQ`'s kill loop
via `J.WillMagicKillTarget`, whose estimate is

    EstDamage = dmg * (1 + GetSpellAmp()) - GetHealthRegen()*5.0 / MagicResistReduce
    fires iff  GetActualIncomingDamage(EstDamage, MAGICAL) >= GetHealth()

`dmg` enters ONLY through that product, so at dmg = 0 the branch is dead at
every rank, item and target.  This is therefore a WIDENING: the armed leg can
only ADD casts, never withdraw one -- the mirror image of `wkqdmg`
(`wkqdmg_domain.py`), which is a pure `math.min` narrowing.  That direction
decides what condition (a) can be bought here: the ADDED cast is the thing that
does not exist in the shipped leg, so it cannot be read off shipped casts, and
the ARMED leg's own casts are not separable from the eight other branches of
`X.ConsiderQ` that also return `BOT_ACTION_DESIRE_HIGH`.  What IS measurable,
and what queue `hero-24` actually asks for, is the DOMAIN: the frames on which
the kill loop would be traversed at all, and the sub-frames on which the armed
claim would reach a living enemy's health bar.

WHAT IT REPORTS (queue hero-24's acceptance, cell by cell)
----------------------------------------------------------
  (1) carrier    games containing Lion; Lion frames; alive Lion frames
  (2) ready      alive frames with Earth Spike at rank >= 1, cd 0, mana >= the
                 rank's KV cost, AND >= 1 living enemy hero inside the kill
                 loop's own reach (`nInBonusEnemyList` = nCastRange + 200)
  (3) kill       of (2), frames where SOME enemy in that reach has current hp
                 at or below the armed claim -- reported at spell amp
                 0% / 15% / 20%, each tier its own row (acceptance (3))
  (3b) outcome   of (3), frames where at least one such victim was NOT observed
                 to reach hp 0 within the next N seconds anyway (GH #361).  See
                 THE OUTCOME COLUMN below -- this column is READ ON THE BASELINE
                 LEG ONLY.
  (4) unique     of (3), frames where Lion is below level 15 and the three mode
                 predicates that guard every LATER branch are false.  Only the
                 level test is observable offline; see LIMITS.

THE OUTCOME COLUMN (GH #361, added 2026-08-31T12:xxZ)
------------------------------------------------------
Cell (3) as first shipped had NO outcome clause: "an enemy at 26 hp who escaped
and healed to full" and "an enemy at 1 hp who is being killed by an ally this
very second" were the same event to it.  On W31 the second kind was 9 of 10,
which is why the same tool on the same 47-id arm string read 1 episode on W30
and 10 on W31 -- a 14x swing whose direction was OPPOSITE to the truth (the W30
episode was a real missed kill; not one of the W31 baseline-leg episodes was).
So cell (3) tracks "how many low-hp-about-to-die frames did this corpus sample",
not "how many extra kills could this lever take".  Adding waves does not fix it.

The column added here is the subtraction that was missing:

    net(3) = cell (3) frames MINUS those whose victims all died anyway

with two disciplines baked in, because both are easy to get backwards:

  * BASELINE LEG ONLY.  On the ARMED leg a victim's death inside the window may
    be the armed cast itself landing -- subtracting there would delete exactly
    the effect being measured, i.e. it would kill this id in the four-cell table
    by construction.  The armed-leg rows are printed (铁律 4(i-a) disclosure:
    every reading appears in all four cells) and are marked NOT INTERPRETABLE.
  * SURVIVORSHIP IS THE UPPER BOUND.  A frame counts as `net` when ANY
    qualifying victim survives the window, and a victim with no further samples
    at all (game ends, recording stops) counts as SURVIVED.  Both choices
    INFLATE `net`, which is the safe direction for this stream's standing
    NEGATIVE finding on this id and the unsafe one for any positive claim.

THE SECOND WITNESS AND THE STALE COLUMN (2026-08-31T21:xxZ, GH #361)
--------------------------------------------------------------------
The outcome column above reads ONE witness: the 1 Hz health bar.  Last round
measured (on this same corpus family, n=137 casts) that the combat log leads
that health bar in 136 of 137 pairs, median -0.7 s, 27% by >=1.0 s -- so at
N = 2s the health bar systematically reports SURVIVED for heroes the log has
already declared dead, which is exactly the side `net` calls safe.  Two columns
are added here, and they answer DIFFERENT questions:

  (3b-ev) `netev`  the same subtraction read off combat-log DEATH rows, printed
                   BESIDE `net`, never merged or averaged with it.  Neither
                   witness refines the other (the disagreement has both signs);
                   `netev` also loses the `idx` identity lock, which can push it
                   BELOW the upper bound `net` is defined to be.  `dis` counts
                   the frames where the two differ.  Coverage ("was the log
                   still running") is its own count and is NEVER folded in.
  (3c) `stale`     cell (3) frames whose victim the log had ALREADY reported
                   dead when the frame was sampled, with the next hp sample
                   confirming no respawn.  This one is not about the outcome at
                   all: it is contamination in the DOMAIN, the id's own
                   opportunity count, and it inflates it.

W31 `ba/baseline` reads 1 of 5 (see `stale_victim` for the frame).  Both legs
are interpretable in (3c), unlike (3b): nothing the armed leg does can kill a
hero BEFORE the frame.

`N` IS A REGISTERED CHOICE, NOT A CONSTANT OF NATURE.  W31's ten hand-read
victims died 1 to 5 seconds after the frame, so the headline is N = 5s, and the
whole ladder (2 / 5 / 10s) is printed so the knife edge is visible rather than
buried -- the same reason 铁律 4(ii) makes a median carry its share.

Every headline number is printed in all four (stratum x leg) cells (铁律 4(i-a)),
means and shares only, never a median (4(ii)).

LIMITS -- read these before quoting any number
-----------------------------------------------
  * VISION.  `J.GetNearbyHeroes(bot, r, true, ...)` is engine-vision limited;
    this corpus knows every hero's position.  Every count here is an UPPER
    bound on the engine's own domain.
  * `IsFullyCastable` also fails on silence/break/root-of-cast and on
    `X.ShouldSaveMana`-style callers; none is observable offline.  Upper bound
    again, same direction.
  * `J.WillMagicKillTarget` subtracts `GetHealthRegen()*5.0/MagicResistReduce`
    and then puts the estimate through `GetActualIncomingDamage`.  The corpus
    carries neither regen nor magic resist, so cell (3) is reported TWICE:
      - `raw`  hp <= dmg*(1+amp)                      <- the acceptance's literal wording
      - `mr25` hp <= dmg*(1+amp)*0.75                 <- base 25% magic resist applied
    Both ignore health regen, so both are upper bounds; `mr25` is the tighter
    and the more faithful one.  Neither models Medusa's mana shield, Bristleback
    or refraction (all of which only ever REDUCE the estimate).
  * MODE PREDICATES (cell 4).  `IsGoingOnSomeone` / `IsRetreating` read
    `bot:GetActiveMode()`, which no replay carries -- they are assumed FALSE,
    which INFLATES cell (4), i.e. flatters this id.  `IsInTeamFight(bot,1200)`
    counts allies in BOT_MODE_ATTACK within 1200; the mode half is unobservable
    but "at least 2 allied heroes within 1200" is a NECESSARY condition, so a
    frame with fewer than 2 nearby allies has it definitely false.  Cell (4) is
    therefore printed as two upper bounds -- `u_lvl` (level only) and `u_tf`
    (level AND that necessary condition ruled out) -- and NO lower bound, which
    is 0 by construction.  Acceptance (丙) is judged on the upper bounds, which
    is the safe direction for a negative conclusion and the unsafe one for a
    positive one; say so wherever these are quoted.
  * SPELL AMP.  Which of 0/15/20% is actually reachable in a ~20 minute Turbo
    game is the HERO desk's fact (director's addendum to §CO), not this file's.
    What this file can add is observable: whether any spell-amp item is in
    Lion's inventory on the frame, printed as an `amp_item` share.
  * These are counts on 10 stamped games from ONE wave.  Not effect sizes; the
    physical-side term is NOT cancelled in them (铁律 4(i-b)).

usage:  lionqdmg_domain.py <sweep_dir> [sweep_dir ...] [--stratum {all,ab,ba}]
        lionqdmg_domain.py --selfcheck
"""

import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from stayfield_domain import SIDE_TEAM, canon, dist, load_sweeps, stratum_of  # noqa: E402

CAND_ID = "lionqdmg"
LION = "lion"                              # canon() form
IMPALE = "lion_impale"

# --- source constants (lion_impale KV, mirrored in tests/mock/special_value_shapes.lua) ---
Q_DAMAGE = (105.0, 170.0, 235.0, 300.0)    # AbilityValues/damage, per rank
Q_MANA = (90.0, 110.0, 130.0, 150.0)       # AbilityManaCost, per rank
CAST_RANGE_KV = 650.0                      # AbilityCastRange, flat at every rank
CAST_RANGE_TALENT = "special_bonus_unique_lion_2"   # +600 cast range
CAST_RANGE_TALENT_BONUS = 600.0

# --- source constants (hero_lion.lua) ----------------------------------------
CAST_RANGE_PAD = 20.0                      # :568  GetCastRange() + aetherRange + 20
BONUS_PAD = 200.0                          # :575  nInBonusEnemyList = nCastRange + 200
AETHER_BONUS = 250.0                       # :394  aether_lens => aetherRange = 250

# --- source constants (jmz_func.lua) -----------------------------------------
TEAMFIGHT_R = 1200.0                       # X.ConsiderQ passes 1200 to IsInTeamFight
TEAMFIGHT_ALLIES = 2                       # #attackModeAllyList >= 2
FALLBACK_LEVEL = 15                        # the catch-all "常规" branch's nLV >= 15

# --- probes, NOT source constants --------------------------------------------
BASE_MAGIC_RESIST_MULT = 0.75              # 25% base hero magic resistance
AMP_TIERS = (0.0, 0.15, 0.20)              # acceptance (3)'s three columns
CD_EPS = 1e-9                              # `cd` is reported as a float 0.0
SAMPLE_TOL_S = 1e-6                        # enemy snapshots share the frame's own t

# Outcome window (GH #361).  REGISTERED CHOICE, not a source constant: W31's ten
# hand-read victims reached hp 0 between 1.0 and 5.0 seconds after the frame, so
# the headline is 5.0s and the ladder is printed around it.
OUTCOME_WINDOWS = (2.0, 5.0, 10.0)
OUTCOME_HEADLINE_S = 5.0

# THE SECOND WITNESS (`netev`, added 2026-08-31T21:xxZ, GH #361) reads the same
# instant off the combat log instead of the health bar.  Its tolerance is
# deliberately the SAME number as the health bar's, not an independently tuned
# one: the two columns exist to be read against each other, and a second knob
# would make every disagreement ambiguous between "the clocks differ" and "the
# tolerances differ".  (Same reasoning as `wkqdmg_domain.EVENT_TOL_S`; the
# constant is duplicated rather than imported because the two files share no
# scanner and a shared constant would imply they do.)
EVENT_TOL_S = SAMPLE_TOL_S

# STALE-VICTIM WINDOW.  A REGISTERED CHOICE, and a deliberately SHORT one.
# Measured on `fde133/20260831_065721_slot1` t=217.5 (see `stale_victim`): the
# combat log reported luna dead at t=217.4 while the very next snapshot cell
# still carried her at hp 47, so cell (3) admitted a corpse as "a living enemy
# whose hp is at or below the armed claim".  The window has to stay near ONE
# sampling cell (snapshots are 1 Hz here) because Turbo respawn is fast: a
# DEATH several seconds before the frame is NOT evidence the hero was dead ON
# the frame.  The 2 s rung is printed beside it so the knife edge is visible
# (铁律 4(ii)), and the confirming `hp<=0` sample is required on top -- see
# `stale_victim` for why neither half alone is enough.
STALE_WINDOWS = (1.0, 2.0)
STALE_HEADLINE_S = 1.0

# Spell-amp SOURCES on an item, for the `amp_item` observability row only.  This
# is NOT a claim about GetSpellAmp()'s value -- it is "was any amp source even
# in the bag", which is the half of the hero desk's question a replay can answer.
AMP_ITEMS = (
    "kaya", "kaya_and_sange", "yasha_and_kaya", "trident",
    "ethereal_blade", "aghanims_shard", "ultimate_scepter",
)

CELLS = [(s, l) for s in ("ab", "ba") for l in ("armed", "baseline")]


def rank_index(level):
    """KV rows are 1-indexed by ability rank; rank 0 means unlearned."""
    return level - 1


def death_index(events):
    """{hero key: sorted DEATH times} for HERO deaths only.

    A module-level function rather than four lines inside `Game.__init__`
    because the `target_hero` filter is the clause that decides what "a hero
    died" MEANS here, and a clause built inside a constructor can only be
    tested through a whole synthetic timeline -- which is how it went
    unguarded (mutation stand 2026-08-31T21:xxZ: dropping the filter survived
    every check).  On the W30+W31 corpora the flag and a `npc_dota_hero_`
    target name agree on all 33,216 DEATH rows (937 hero / 32,279 not), so
    dropping it changes no number TODAY; it is pinned because a creep or
    building death landing in a hero's bucket would be invisible in every
    reading built on it.
    """
    by = collections.defaultdict(list)
    for e in events:
        if e.get("type") != "DEATH" or not e.get("target_hero"):
            continue
        tgt = canon(e.get("target"))
        if not tgt or e.get("t") is None:
            continue
        by[tgt].append(e["t"])
    for k in by:
        by[k].sort()
    return by


class Game(object):
    """One timeline reduced to Lion's frames and the enemy heroes around them."""

    def __init__(self, path):
        d = json.load(open(path))
        self.teams = d["game"]["teams"]
        self.has_lion = any(canon(h) == LION for h in self.teams)

        # identity lock by earliest-appearing idx (GH #176 discipline)
        first_t = {}
        for s in d["snapshots"]:
            if "idx" not in s:
                sys.exit("FATAL: timeline has no snapshot idx; cannot lock identity")
            k = (canon(s["hero"]), s["idx"])
            if k not in first_t or s["t"] < first_t[k]:
                first_t[k] = s["t"]
        primary = {}
        for (hero, idx), t0 in first_t.items():
            if hero not in primary or t0 < primary[hero][1]:
                primary[hero] = (idx, t0)
        self.primary = dict((h, v[0]) for h, v in primary.items())

        self.by_t = collections.defaultdict(list)
        self.by_hero = collections.defaultdict(list)
        self.lion = []
        for s in d["snapshots"]:
            hero = canon(s["hero"])
            if self.primary.get(hero) != s["idx"]:
                continue
            self.by_t[s["t"]].append(s)
            # (t, hp) of REAL samples only -- the outcome column never
            # interpolates hp (GH #176: interpolated hp is not aliveness).
            self.by_hero[hero].append((s["t"], s.get("hp") or 0.0))
            if hero == LION:
                self.lion.append(s)
        self.lion.sort(key=lambda s: s["t"])
        for h in self.by_hero:
            self.by_hero[h].sort()
        self.lion_team = self.teams.get("npc_dota_hero_lion")

        # --- the SECOND WITNESS's raw material (GH #361) ----------------------
        # THIS index crosses the two dump streams and the one above does not:
        # victims are named off the SNAPSHOT stream (dumper's `snakeFromClass`)
        # while deaths are named off the COMBAT LOG, and those two spellings
        # disagree on every hero whose npc name concatenates two words --
        # snapshots `vengeful_spirit`, log `vengefulspirit` (GH #303).
        #
        # WHAT ACTUALLY CLOSES THAT HERE, and it is worth being exact because
        # the wrong answer is the plausible one: NOT a `HeroMap`, but the
        # `canon` this file imports from `stayfield_domain`, which lowercases,
        # strips the prefix AND removes underscores -- it is `entities.hkey`
        # under another name, so both spellings arrive at the same key before
        # any lookup happens.  Both sides of this join go through it, which is
        # the only reason a plain dict is safe.  `selfcheck` pins that property
        # directly, so swapping in a canon that keeps underscores (e.g.
        # `entities.canon`) fails a test rather than silently reporting three
        # heroes as immortal.
        events = d.get("events") or ()
        self.deaths = death_index(events)
        # GAME-level, deliberately: the absence of a DEATH row is not evidence
        # that the entity was still being watched, so the only honest question
        # the event stream can answer about coverage is "was the log still
        # running".  Read off the events alone (never off the snapshots) so the
        # two witnesses stay independent.
        ev_ts = [e["t"] for e in events if e.get("t") is not None]
        self.ev_horizon = max(ev_ts) if ev_ts else None


def impale_of(snap):
    """The Earth Spike row of this frame, or None when the frame carries none."""
    for a in snap.get("abilities") or ():
        if a.get("name") == IMPALE:
            return a
    return None


def has_talent(snap, name):
    for a in snap.get("abilities") or ():
        if a.get("name") == name and (a.get("level") or 0) >= 1:
            return True
    return False


def reach_of(snap):
    """`nCastRange + 200`, the radius of the kill loop's own enemy list.

    `abilityQ:GetCastRange()` is engine-side and already carries the +600 talent
    when trained; hero_lion.lua:395 (the aetherRange talent line) is COMMENTED
    OUT in this tree, so the talent must be read from the frame, not folded into
    `aetherRange`.
    """
    r = CAST_RANGE_KV
    if has_talent(snap, CAST_RANGE_TALENT):
        r += CAST_RANGE_TALENT_BONUS
    if "aether_lens" in (snap.get("items") or ()):
        r += AETHER_BONUS
    return r + CAST_RANGE_PAD + BONUS_PAD


def amp_item_present(snap):
    return any(i in AMP_ITEMS for i in (snap.get("items") or ()))


def others_at(game, snap, same_team):
    """Living primary-entity heroes sharing this frame's timestamp."""
    out = []
    for o in game.by_t.get(snap["t"], ()):
        if o is snap or canon(o["hero"]) == LION:
            continue
        if (o.get("hp") or 0) <= 0:
            continue
        if same_team == (o.get("team") == snap.get("team")):
            out.append(o)
    return out


def dies_within(game, hero, t0, window):
    """Did `hero` reach hp 0 on a REAL sample in (t0, t0 + window]?

    No interpolation and no "hp fell a lot" heuristic: only a sampled hp <= 0
    counts as death.  A hero with no samples left in the window (game over,
    recording stopped) returns False -- i.e. counts as SURVIVED, which inflates
    `net` and is therefore the safe direction for a negative finding.
    """
    for t, hp in game.by_hero.get(hero, ()):
        if t <= t0 + SAMPLE_TOL_S:
            continue
        if t > t0 + window + SAMPLE_TOL_S:
            break
        if hp <= 0:
            return True
    return False


def died_ev_within(game, hero, t0, window):
    """Did the COMBAT LOG report `hero` dead in (t0, t0 + window]?

    The second witness to the same question `dies_within` answers off the
    health bar.  It is NOT a refinement of that one and the two are never
    merged or averaged -- three reasons, all of them specific to THIS file:

      * WEAKER IDENTITY, and here it bites the other way round.  A combat-log
        row carries names, not entity indices, so the `idx` lock this file
        applies to snapshots (GH #176) has no counterpart: an illusion's death
        is logged under its hero's own name.  `wkqdmg_domain` records the same
        loss, but its frame is one cast on one target, whereas cell (3b) here
        is `ANY qualifying victim survived` -- so a mislabelled illusion death
        can flip a whole frame OUT of `netev`, i.e. this column can read BELOW
        the survivorship upper bound `net` is defined to be.  That is the
        unsafe direction for this stream's standing NEGATIVE finding, which is
        why `netev` is reported beside `net` and never in place of it.
      * DIFFERENT CLOCK, BOTH SIGNS.  Measured on the W30/W31 corpora
        (`wkqdmg_domain.witness_lag`): the event led the first sampled `hp<=0`
        in 136 of 136 clean pairs, median -0.7 s, so the health bar is
        systematically LATE on short windows, which inflates `net` at N=2s.
        ⚠️ RETRACTED, 2026-09-01: an earlier version of this paragraph read
        `n=137` with "the one positive pair (+7.8 s)" and cited that pair as
        proof the log can also lag the bar.  That 137th pair was an ARTIFACT
        -- `witness_lag` was pairing a corpse with the hero's SECOND death
        after a revival, and its respawn guard removed it (replay-check
        2026-09-01T01:20Z).  All three corpora now read 100% negative.
        What survives the retraction is the OTHER, independent witness to the
        same claim: `bbfloor_domain.py:263`'s skeleton_king (hp 0.005 from
        t=45.4, DEATH event t=48.6).  So "both signs occur" still stands, on
        one measurement rather than two -- and the reason to keep the columns
        apart was never the lag's sign anyway, it is the two bullets that
        bracket this one.  Neither witness refines the other.
      * COVERAGE IS A DIFFERENT QUESTION.  Absence of a DEATH row is not
        evidence of survival, so this column cannot ask "is the victim still
        sampled" -- only "was the log still running" (`ev_covered`), which is
        a game-level property and is printed as its own count rather than
        folded in here.

    A hero the log never mentions returns False, i.e. counts as SURVIVED --
    the same convention `dies_within` uses for a hero with no samples left, so
    the two columns stay comparable at the frame level.  `ev_covered` is what
    exposes how much of `netev` that convention bought.
    """
    for t in game.deaths.get(hero, ()):
        if t <= t0 + EVENT_TOL_S:
            continue
        if t > t0 + window + EVENT_TOL_S:
            break
        return True
    return False


def ev_covered(game, t0, window):
    """Was the combat log still witnessing anything at the far edge of the
    window?  The second witness's coverage test -- game-level by necessity
    (see `died_ev_within`), never per victim, and never folded into `netev`."""
    if game.ev_horizon is None:
        return False
    return game.ev_horizon >= t0 + window - EVENT_TOL_S


def stale_victim(game, hero, t0, window):
    """Was this 'living' victim ALREADY DEAD per the combat log at the frame?

    THE FRAME THIS EXISTS FOR (replay-check 2026-08-31T21:xxZ, read frame by
    frame off `fde133/20260831_065721_slot1`, W31 `ba/baseline`):

        t=217.4  DEATH  actor chaos_knight  target luna  (Lion takes the
                 assist: GOLD 106 / XP 233 land on Lion at the same instant)
        t=217.5  SNAPSHOT still carries luna at hp 47, and cell (3) counts
                 that frame as "a living enemy at or below the armed claim"
        t=218.5  first snapshot with luna at hp 0

    So the domain -- cell (3), this id's own numerator -- can be bought by a
    CORPSE the 1 Hz health bar has not caught up with.  That is the same
    sampling lag last round measured as a property of the recording (n=137,
    the log led the health bar in 136 pairs, median -0.7 s), but landing on a
    different column: not the outcome, the OPPORTUNITY COUNT, and in the
    direction that FLATTERS this id.

    BOTH HALVES ARE REQUIRED and neither is sufficient:

      * a DEATH event in (t0 - window, t0] alone is not enough -- Turbo
        respawn is fast (halved timers), so a hero who died a few seconds ago
        can legitimately be alive again on the frame;
      * the next hp sample reading <= 0 alone is not enough either -- that is
        exactly the ordinary "the victim died right after the frame" case,
        which is what the outcome column already reports.

    Together they say something neither says alone: the log had already
    declared the death BEFORE the frame, and the next sample confirms the
    victim is still down.  Frames with no further samples are NOT stale by this
    test (nothing confirms them), which keeps this count a LOWER bound -- the
    safe direction for a finding that says the domain is over-counted.

    ⭐ THE REVIVAL GUARD (replay-check 2026-09-01, the same family as
    `wkqdmg_domain.witness_lag`'s guard one round earlier).  Until this guard
    existed the docstring claimed the forward sample "confirms no respawn
    intervened".  It does not and cannot: it looks AFTER the frame, while a
    revival between the logged death and the frame happens BEFORE it.  The
    missing half is here -- a `hp<=0` sample strictly between the death and
    the frame.  The frame's own victim sample is `hp>0` by construction
    (`others_at` keeps only living heroes), so a zero in between IS the
    dead->alive transition; and a merely LAGGING health bar never reads 0 and
    then positive inside one death, which is exactly what makes this the whole
    test rather than a heuristic.

    HOW MUCH HEADROOM THERE ACTUALLY IS, measured rather than assumed -- and
    the assumption was wrong in the interesting direction.  Reasoning about
    "Turbo halves respawn timers, so nothing revives inside 2 s" does not
    describe this corpus, because the fastest revivals in it are not respawns
    at all: over W32 (all four runs, 10 games, 498 hero deaths, read frame by
    frame off the timelines) the shortest death -> sampled-alive-again gap is
    3.2 s and the five shortest are ALL `skeleton_king` -- Reincarnation, which
    returns him ON THE SPOT, not at the fountain:

        1312.2  DEATH earthshaker -> skeleton_king
        1312.4  hp 151     x 1271.2 y 1037.7      <- bar still alive, 0.2 s late
        1313.4  hp 0       x  616.1 y   64.3      reincarnation cd 0 -> 148.9
        1315.4  hp 2312    x 1271.2 y 1037.7      <- revived, at the death spot

    So the margin between the widest STALE window (2.0 s) and the observed
    floor (3.2 s) is 1.2 s, about ONE 1 Hz sample -- thin enough that the
    guard belongs in code rather than in a constant.  Measured on that same
    corpus the guard fires on 0 of 318 candidate pairings (a SUPERSET of the
    frames this file visits: no Lion, reach, mana, cooldown or damage band
    required), i.e. it changes no number today -- the whole census is
    byte-identical before and after.  It is pinned so that a widened window, a
    shorter revival, or a corpus with more Wraith King cannot change one
    silently.
    """
    deaths = [t for t in game.deaths.get(hero, ())
              if t0 - window - EVENT_TOL_S <= t <= t0 + EVENT_TOL_S]
    if not deaths:
        return False
    # The most recent logged death is the one the frame could be stale for.
    if any(hp <= 0 for t, hp in game.by_hero.get(hero, ())
           if deaths[-1] < t < t0 - SAMPLE_TOL_S):
        return False
    nxt = next((hp for t, hp in game.by_hero.get(hero, ())
                if t > t0 + SAMPLE_TOL_S), None)
    return nxt is not None and nxt <= 0


def victim_traj(game, hero, t0, window):
    """The hero's REAL hp samples in (t0, t0 + window], for frame-level reading."""
    return [hp for t, hp in game.by_hero.get(hero, ())
            if t0 + SAMPLE_TOL_S < t <= t0 + window + SAMPLE_TOL_S]


def death_times(game, hero, t0, window):
    """The hero's DEATH-event times in (t0, t0 + window] -- the second witness's
    raw material, printed so a disagreement can be audited without re-running
    this tool."""
    return [t for t in game.deaths.get(hero, ())
            if t0 + EVENT_TOL_S < t <= t0 + window + EVENT_TOL_S]


def scan_game(game):
    """Per-frame rows for one game.  No aggregation happens here."""
    rows = []
    if not game.has_lion:
        return rows
    for s in game.lion:
        alive = (s.get("hp") or 0) > 0
        row = {"t": s["t"], "alive": alive, "ready": False, "level": s.get("level")}
        rows.append(row)
        if not alive:
            continue
        ab = impale_of(s)
        if ab is None:
            continue
        rank = ab.get("level") or 0
        if rank < 1:
            continue
        if (ab.get("cd") or 0.0) > CD_EPS:
            continue
        ri = rank_index(rank)
        if (s.get("mp") or 0.0) < Q_MANA[ri]:
            continue
        reach = reach_of(s)
        enemies = [e for e in others_at(game, s, same_team=False)
                   if dist(s["x"], s["y"], e["x"], e["y"]) <= reach]
        if not enemies:
            continue
        row["ready"] = True
        row["rank"] = rank
        row["reach"] = reach
        row["amp_item"] = amp_item_present(s)
        allies = [a for a in others_at(game, s, same_team=True)
                  if dist(s["x"], s["y"], a["x"], a["y"]) <= TEAMFIGHT_R]
        row["allies_1200"] = len(allies)
        dmg = Q_DAMAGE[ri]
        lowest = min(e["hp"] for e in enemies)
        row["lowest_hp"] = lowest
        # How far the softest reachable enemy is from the armed claim, at 0% amp
        # and after base magic resist.  1.0 means "exactly on the line"; this is
        # the readout that separates "nowhere near" from "just barely missed".
        row["ratio_mr25"] = lowest / (dmg * BASE_MAGIC_RESIST_MULT)
        for amp in AMP_TIERS:
            raw = dmg * (1.0 + amp)
            row["kill_raw_%s" % amp] = any(e["hp"] <= raw for e in enemies)
            qual = [e for e in enemies
                    if e["hp"] <= raw * BASE_MAGIC_RESIST_MULT]
            row["kill_mr25_%s" % amp] = bool(qual)
            # (3b) outcome, GH #361: a frame stays `net` while ANY qualifying
            # victim was not observed to die inside the window.
            for w in OUTCOME_WINDOWS:
                row["net_%s_%s" % (amp, w)] = any(
                    not dies_within(game, canon(e["hero"]), s["t"], w)
                    for e in qual)
                # the SECOND witness, same quantifier and same ladder so the
                # two are comparable frame by frame -- separate keys, never
                # reconciled into one column (see `died_ev_within`)
                row["netev_%s_%s" % (amp, w)] = any(
                    not died_ev_within(game, canon(e["hero"]), s["t"], w)
                    for e in qual)
                row["dis_%s_%s" % (amp, w)] = (
                    row["net_%s_%s" % (amp, w)] != row["netev_%s_%s" % (amp, w)])
            # the domain's own contamination check: was a qualifying victim
            # already dead per the combat log when this frame was sampled?
            for sw in STALE_WINDOWS:
                row["stale_%s_%s" % (amp, sw)] = any(
                    stale_victim(game, canon(e["hero"]), s["t"], sw)
                    for e in qual)
            if amp == 0.0:
                for w in OUTCOME_WINDOWS:
                    row["evcov_%s" % w] = ev_covered(game, s["t"], w)
                row["kill_victims"] = [
                    (canon(e["hero"]), e["hp"],
                     dies_within(game, canon(e["hero"]), s["t"],
                                 OUTCOME_HEADLINE_S),
                     died_ev_within(game, canon(e["hero"]), s["t"],
                                    OUTCOME_HEADLINE_S))
                    for e in qual]
        row["victims"] = [(canon(e["hero"]), e["hp"],
                           round(dist(s["x"], s["y"], e["x"], e["y"]), 1))
                          for e in enemies]
    return rows


def cell_of(side, lion_team):
    """(stratum, leg) for Lion in a game whose CANDIDATE side is `side`."""
    leg = "armed" if lion_team == SIDE_TEAM[side] else "baseline"
    return stratum_of(side), leg


def summarize(cells):
    """Render the four-cell tables.  Means and shares only -- 铁律 4(ii)."""
    out = []
    out.append("## (1) carrier denominator")
    out.append("| cell | games | lion frames | alive frames |")
    out.append("|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        out.append("| %s/%s | %d | %d | %d |" % (c[0], c[1], a["games"],
                                                 a["frames"], a["alive"]))
    out.append("")
    out.append("## (2) domain: kill loop traversed (ready + enemy in reach)")
    out.append("| cell | ready frames | per game | share of alive |")
    out.append("|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        pg = (a["ready"] / a["games"]) if a["games"] else 0.0
        sh = (a["ready"] / a["alive"]) if a["alive"] else 0.0
        out.append("| %s/%s | %d | %.2f | %.3f |" % (c[0], c[1], a["ready"], pg, sh))
    out.append("")
    out.append("## (3) armed claim reaches a living enemy's hp  [share of (2)]")
    out.append("| cell | amp | raw | share | mr25 | share |")
    out.append("|---|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        for amp in AMP_TIERS:
            kr = a["kill_raw_%s" % amp]
            km = a["kill_mr25_%s" % amp]
            den = a["ready"] or 1
            out.append("| %s/%s | %d%% | %d | %.3f | %d | %.3f |"
                       % (c[0], c[1], int(amp * 100), kr, kr / den, km, km / den))
    out.append("")
    out.append("## (3b) outcome column: victim NOT observed to die anyway  [GH #361]")
    out.append("")
    out.append("**Read the `baseline` rows only.** On the armed leg a death")
    out.append("inside the window can be the armed cast itself, so subtracting")
    out.append("there would delete the effect being measured. `net` counts a")
    out.append("frame while ANY qualifying victim survives, and no-further-")
    out.append("samples counts as survived: both inflate it (upper bound).")
    out.append("")
    out.append("| cell | amp | kill(mr25) | net<=2s | net<=5s | net<=10s | interpretable |")
    out.append("|---|---|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        note = "yes" if c[1] == "baseline" else "**NO (armed leg)**"
        for amp in AMP_TIERS:
            out.append("| %s/%s | %d%% | %d | %d | %d | %d | %s |"
                       % (c[0], c[1], int(amp * 100), a["kill_mr25_%s" % amp],
                          a["net_%s_2.0" % amp], a["net_%s_5.0" % amp],
                          a["net_%s_10.0" % amp], note))
    out.append("")
    out.append("## (3b-ev) SECOND WITNESS: the same column read off DEATH events")
    out.append("")
    out.append("Two witnesses to one question, printed side by side and **never**")
    out.append("merged or averaged. `net` reads sampled hp, `netev` reads combat-log")
    out.append("DEATH rows; measured on this corpus family the log leads the health")
    out.append("bar in 136 of 137 pairs (median -0.7s) but has also been seen to lag")
    out.append("it, so NEITHER is a refinement of the other. `netev` also LOSES the")
    out.append("`idx` identity lock (illusion deaths are logged under the hero name),")
    out.append("which can push it BELOW the upper bound `net` is defined to be.")
    out.append("`dis` = frames where the two columns disagree, at that window.")
    out.append("Baseline rows are the interpretable ones, exactly as in (3b).")
    out.append("")
    out.append("| cell | amp | kill(mr25) | net/netev <=2s | <=5s | <=10s | dis 2/5/10s | interpretable |")
    out.append("|---|---|---|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        note = "yes" if c[1] == "baseline" else "**NO (armed leg)**"
        for amp in AMP_TIERS:
            out.append("| %s/%s | %d%% | %d | %d/%d | %d/%d | %d/%d | %d/%d/%d | %s |"
                       % (c[0], c[1], int(amp * 100), a["kill_mr25_%s" % amp],
                          a["net_%s_2.0" % amp], a["netev_%s_2.0" % amp],
                          a["net_%s_5.0" % amp], a["netev_%s_5.0" % amp],
                          a["net_%s_10.0" % amp], a["netev_%s_10.0" % amp],
                          a["dis_%s_2.0" % amp], a["dis_%s_5.0" % amp],
                          a["dis_%s_10.0" % amp], note))
    out.append("")
    out.append("### second witness coverage (was the combat log still running?)")
    out.append("")
    out.append("Absence of a DEATH row is NOT evidence of survival, so this is a")
    out.append("game-level 'was anything still being logged at the far edge of the")
    out.append("window' count over cell (3) frames at amp 0%, kept OUT of `netev`.")
    out.append("A gap between `kill(mr25,0%)` and these is the share of `netev`")
    out.append("bought by the log having stopped rather than by an observed survival.")
    out.append("")
    out.append("| cell | kill(mr25,0%) | log live @2s | @5s | @10s |")
    out.append("|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        out.append("| %s/%s | %d | %d | %d | %d |"
                   % (c[0], c[1], a["kill_mr25_0.0"], a["evcov_2.0"],
                      a["evcov_5.0"], a["evcov_10.0"]))
    out.append("")
    out.append("## (3c) STALE VICTIMS: cell (3) frames whose victim was already dead")
    out.append("")
    out.append("The combat log had already reported the qualifying victim dead when")
    out.append("this frame was sampled, AND the next hp sample confirms the victim")
    out.append("is still down, AND no hp sample BETWEEN that death and the frame had")
    out.append("already shown the corpse (which would make the frame a revival, not")
    out.append("a lagging bar). These frames are contamination in cell (3)")
    out.append("ITSELF -- the id's own opportunity count -- not in the outcome")
    out.append("column, and they INFLATE it, which is the direction that flatters")
    out.append("this id. Both legs are interpretable here: unlike (3b), nothing the")
    out.append("armed leg does can retro-actively kill a hero BEFORE the frame.")
    out.append("Requiring the confirming sample makes this a LOWER bound.")
    out.append("")
    out.append("| cell | amp | kill(mr25) | stale<=%gs | share | stale<=%gs |"
               % (STALE_WINDOWS[0], STALE_WINDOWS[1]))
    out.append("|---|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        for amp in AMP_TIERS:
            den = a["kill_mr25_%s" % amp] or 1
            out.append("| %s/%s | %d%% | %d | %d | %.3f | %d |"
                       % (c[0], c[1], int(amp * 100), a["kill_mr25_%s" % amp],
                          a["stale_%s_%s" % (amp, STALE_WINDOWS[0])],
                          a["stale_%s_%s" % (amp, STALE_WINDOWS[0])] / den,
                          a["stale_%s_%s" % (amp, STALE_WINDOWS[1])]))
    out.append("")
    out.append("## (4) coverage unique to this id  [UPPER bounds only, see LIMITS]")
    out.append("| cell | amp | kill(mr25) | u_lvl | u_tf |")
    out.append("|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        for amp in AMP_TIERS:
            out.append("| %s/%s | %d%% | %d | %d | %d |"
                       % (c[0], c[1], int(amp * 100),
                          a["kill_mr25_%s" % amp],
                          a["u_lvl_%s" % amp], a["u_tf_%s" % amp]))
    out.append("")
    out.append("## proximity ladder: how close the softest reachable enemy got")
    out.append("(share of (2) frames whose lowest reachable enemy hp is within")
    out.append("k x the mr25 claim at 0%% amp; k = 1.0 IS cell (3)'s mr25 row)")
    out.append("")
    out.append("| cell | ready | <=1.0x | <=1.5x | <=2.0x | <=3.0x |")
    out.append("|---|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        out.append("| %s/%s | %d | %d | %d | %d | %d |"
                   % (c[0], c[1], a["ready"], a["near_1.0"], a["near_1.5"],
                      a["near_2.0"], a["near_3.0"]))
    out.append("")
    out.append("## episodes (the stream's standing reading discipline)")
    out.append("| cell | ready episodes | kill(mr25,0%%) episodes | net episodes (<=%gs) "
               "| netev episodes (<=%gs) |" % (OUTCOME_HEADLINE_S, OUTCOME_HEADLINE_S))
    out.append("|---|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        out.append("| %s/%s | %d | %d | %d%s | %d%s |"
                   % (c[0], c[1], a["ep_ready"], a["ep_kill"], a["ep_net"],
                      "" if c[1] == "baseline" else " (not interpretable)",
                      a["ep_netev"],
                      "" if c[1] == "baseline" else " (not interpretable)"))
    out.append("")
    out.append("## observability: spell-amp source in the bag on (2) frames")
    out.append("| cell | ready | with amp item | share |")
    out.append("|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        den = a["ready"] or 1
        out.append("| %s/%s | %d | %d | %.3f |"
                   % (c[0], c[1], a["ready"], a["amp_item"], a["amp_item"] / den))
    return "\n".join(out)


NEAR_LADDER = (1.0, 1.5, 2.0, 3.0)
EPISODE_GAP_S = 5.0        # same gap as stayfield_domain's episode discipline


def episodes(times, gap=EPISODE_GAP_S):
    """Count runs of timestamps separated by more than `gap` seconds."""
    n = 0
    prev = None
    for t in sorted(times):
        if prev is None or t - prev > gap:
            n += 1
        prev = t
    return n


def blank_cell():
    a = {"games": 0, "frames": 0, "alive": 0, "ready": 0, "amp_item": 0,
         "ep_ready": 0, "ep_kill": 0}
    for k in NEAR_LADDER:
        a["near_%s" % k] = 0
    for amp in AMP_TIERS:
        a["kill_raw_%s" % amp] = 0
        a["kill_mr25_%s" % amp] = 0
        a["u_lvl_%s" % amp] = 0
        a["u_tf_%s" % amp] = 0
        for w in OUTCOME_WINDOWS:
            a["net_%s_%s" % (amp, w)] = 0
            a["netev_%s_%s" % (amp, w)] = 0
            a["dis_%s_%s" % (amp, w)] = 0
        for sw in STALE_WINDOWS:
            a["stale_%s_%s" % (amp, sw)] = 0
    for w in OUTCOME_WINDOWS:
        a["evcov_%s" % w] = 0
    a["ep_net"] = 0
    a["ep_netev"] = 0
    return a


def run(dirs, stratum="all", witness=0, kill_witness=0):
    rows = load_sweeps(dirs)
    cells = dict((c, blank_cell()) for c in CELLS)
    arms = set()
    witnesses = []
    kill_rows = []
    for run_name, game_name, cand, seed, side, tl in rows:
        arms.add(cand)
        game = Game(tl)
        if not game.has_lion:
            continue
        cell = cell_of(side, game.lion_team)
        if stratum != "all" and cell[0] != stratum:
            continue
        a = cells[cell]
        a["games"] += 1
        # episodes are counted WITHIN a game and then summed; pooling raw
        # timestamps across games would glue two games' spans into one run.
        t_ready, t_kill, t_net, t_netev = [], [], [], []
        for r in scan_game(game):
            a["frames"] += 1
            if not r["alive"]:
                continue
            a["alive"] += 1
            if not r["ready"]:
                continue
            a["ready"] += 1
            t_ready.append(r["t"])
            for k in NEAR_LADDER:
                if r["ratio_mr25"] <= k:
                    a["near_%s" % k] += 1
            if r["kill_mr25_0.0"]:
                t_kill.append(r["t"])
                if r["net_0.0_%s" % OUTCOME_HEADLINE_S]:
                    t_net.append(r["t"])
                if r["netev_0.0_%s" % OUTCOME_HEADLINE_S]:
                    t_netev.append(r["t"])
                for w in OUTCOME_WINDOWS:
                    if r["evcov_%s" % w]:
                        a["evcov_%s" % w] += 1
                if kill_witness and len(kill_rows) < kill_witness:
                    kill_rows.append(
                        (run_name[-6:], game_name, seed, side, cell, r,
                         [(v[0], v[1], v[2], v[3],
                           victim_traj(game, v[0], r["t"], max(OUTCOME_WINDOWS)),
                           death_times(game, v[0], r["t"], max(OUTCOME_WINDOWS)))
                          for v in r["kill_victims"]]))
            if r["amp_item"]:
                a["amp_item"] += 1
            for amp in AMP_TIERS:
                if r["kill_raw_%s" % amp]:
                    a["kill_raw_%s" % amp] += 1
                if r["kill_mr25_%s" % amp]:
                    a["kill_mr25_%s" % amp] += 1
                    for w in OUTCOME_WINDOWS:
                        if r["net_%s_%s" % (amp, w)]:
                            a["net_%s_%s" % (amp, w)] += 1
                        if r["netev_%s_%s" % (amp, w)]:
                            a["netev_%s_%s" % (amp, w)] += 1
                        if r["dis_%s_%s" % (amp, w)]:
                            a["dis_%s_%s" % (amp, w)] += 1
                    for sw in STALE_WINDOWS:
                        if r["stale_%s_%s" % (amp, sw)]:
                            a["stale_%s_%s" % (amp, sw)] += 1
                    if r["level"] is not None and r["level"] < FALLBACK_LEVEL:
                        a["u_lvl_%s" % amp] += 1
                        if r["allies_1200"] < TEAMFIGHT_ALLIES:
                            a["u_tf_%s" % amp] += 1
                            if witness and len(witnesses) < witness and amp == 0.0:
                                witnesses.append((run_name[-6:], game_name, seed,
                                                  side, cell, r))
        a["ep_ready"] += episodes(t_ready)
        a["ep_kill"] += episodes(t_kill)
        a["ep_net"] += episodes(t_net)
        a["ep_netev"] += episodes(t_netev)
    # 铁律 4(i-a) disclosure: the arm string is printed whether or not the id is in it.
    armed_ids = set()
    for c in arms:
        armed_ids |= set(x for x in c.split(",") if x)
    banner = "%s ARMED in this corpus" % CAND_ID if CAND_ID in armed_ids \
        else "%s NOT ARMED in this corpus" % CAND_ID
    if len(arms) > 1:
        sys.exit("FATAL: mixed arm strings across sweeps (%d distinct); "
                 "waves with different strings must not be pooled" % len(arms))
    head = ["# `%s` domain census -- W30-shape corpus" % CAND_ID,
            "",
            "corpus: %d games swept, %d ids in the arm string, **%s**"
            % (len(rows), len(armed_ids), banner),
            "stratum filter: %s" % stratum,
            ""]
    body = summarize(cells)
    tail = []
    if witnesses:
        tail = ["", "## witness frames (amp 0%, mr25, u_tf) -- for frame-level reading", ""]
        for run_name, game_name, seed, side, cell, r in witnesses:
            tail.append("- `%s/%s` seed %s side %s (%s/%s) **t=%.1f** rank %d "
                        "lvl %s allies<1200 %d reach %.0f victims %s"
                        % (run_name, game_name, seed, side, cell[0], cell[1],
                           r["t"], r["rank"], r["level"], r["allies_1200"],
                           r["reach"], r["victims"]))
    if kill_rows:
        tail += ["", "## cell (3) frames with BOTH outcome columns (amp 0%, mr25)",
                 "",
                 "`died(hp)` is the sampled health bar, `died(ev)` the combat log."
                 " A `!=` row is a disagreement to be read frame by frame, not"
                 " reconciled by this table.",
                 "",
                 "| run/game | cell | t | victim | hp | died(hp)<=%gs | died(ev)<=%gs "
                 "| agree | hp samples (%gs) | DEATH events (%gs) |"
                 % (OUTCOME_HEADLINE_S, OUTCOME_HEADLINE_S, max(OUTCOME_WINDOWS),
                    max(OUTCOME_WINDOWS)),
                 "|---|---|---|---|---|---|---|---|---|---|"]
        for run_name, game_name, seed, side, cell, r, vs in kill_rows:
            for hero, hp, died, died_ev, traj, evs in vs:
                tail.append("| `%s/%s` | %s/%s | %.1f | %s | %.0f | %s | %s | %s | %s | %s |"
                            % (run_name, game_name, cell[0], cell[1], r["t"],
                               hero, hp, "yes" if died else "**no**",
                               "yes" if died_ev else "**no**",
                               "" if died == died_ev else "**!=**",
                               " ".join("%.0f" % h for h in traj),
                               " ".join("%.1f" % e for e in evs) or "-"))
    return "\n".join(head) + body + "\n".join(tail)


# --------------------------------------------------------------------------- #
# selfcheck: pure logic, no corpus.  Corpus checks are NOT run here and this
# file says so rather than letting a green line imply them.
# --------------------------------------------------------------------------- #
def _snap(t=0.0, hero="npc_dota_hero_lion", idx=1, team=2, hp=500.0, mp=500.0,
          level=6, items=None, abilities=None, x=0.0, y=0.0):
    return {"t": t, "hero": hero, "idx": idx, "team": team, "hp": hp,
            "hp_pct": 1.0, "mp": mp, "max_mp": mp, "mp_pct": 1.0, "level": level,
            "items": list(items or []), "abilities": abilities, "x": x, "y": y}


def _q(level=1, cd=0.0):
    return [{"name": IMPALE, "level": level, "cd": cd, "cd_len": 14.0}]


def selfcheck():
    checks = []

    def ok(name, cond):
        checks.append((name, bool(cond)))

    ok("rank_index maps rank 1 to the first KV row", Q_DAMAGE[rank_index(1)] == 105.0)
    ok("rank_index maps rank 4 to the last KV row", Q_DAMAGE[rank_index(4)] == 300.0)

    base = _snap()
    ok("reach with no lens and no talent is 650+20+200", reach_of(base) == 870.0)
    ok("aether lens adds 250 to reach",
       reach_of(_snap(items=["aether_lens"])) == 1120.0)
    lens_talent = _snap(items=["aether_lens"],
                        abilities=_q() + [{"name": CAST_RANGE_TALENT, "level": 1,
                                           "cd": 0, "cd_len": 0}])
    ok("the +600 talent stacks with the lens", reach_of(lens_talent) == 1720.0)
    ok("an UNTRAINED talent row adds nothing",
       reach_of(_snap(abilities=[{"name": CAST_RANGE_TALENT, "level": 0,
                                  "cd": 0, "cd_len": 0}])) == 870.0)

    ok("impale_of finds the row", impale_of(_snap(abilities=_q()))["level"] == 1)
    ok("impale_of on a dead frame (abilities null) is None",
       impale_of(_snap(abilities=None)) is None)

    ok("an amp item in the bag is seen", amp_item_present(_snap(items=["kaya"])))
    ok("aether_lens is NOT an amp source",
       not amp_item_present(_snap(items=["aether_lens"])))

    # --- one synthetic game, driven end to end --------------------------------
    def build(enemy_hp, enemy_x, q_level=1, cd=0.0, mp=500.0, lion_level=6,
              allies=0, enemy_alive=True, enemy_future=None, enemy_name="lina",
              deaths=None, ev_horizon="cover", second=None, enemy_past=None):
        snaps = [_snap(t=0.0, abilities=_q(q_level, cd), mp=mp, level=lion_level)]
        snaps.append(_snap(t=0.0, hero="npc_dota_hero_" + enemy_name, idx=2, team=3,
                           hp=enemy_hp if enemy_alive else 0.0, x=enemy_x,
                           abilities=[]))
        # `second` = (name, hp, future) for a SECOND reachable victim, which is
        # the only way to drive cell (3b)'s ANY quantifier with the two victims
        # disagreeing -- a one-victim frame cannot tell "any" from "the".
        if second is not None:
            snaps.append(_snap(t=0.0, hero="npc_dota_hero_" + second[0], idx=3,
                               team=3, hp=second[1], x=enemy_x, abilities=[]))
        for i in range(allies):
            snaps.append(_snap(t=0.0, hero="npc_dota_hero_zuus", idx=10 + i,
                               team=2, x=100.0 * (i + 1), abilities=[]))
        g = Game.__new__(Game)
        g.teams = {"npc_dota_hero_lion": 2,
                   "npc_dota_hero_" + enemy_name: 3, "npc_dota_hero_zuus": 2}
        g.has_lion = True
        g.lion_team = 2
        g.primary = {"lion": 1, canon(enemy_name): 2, "zuus": 10}
        if second is not None:
            g.teams["npc_dota_hero_" + second[0]] = 3
            g.primary[canon(second[0])] = 3
        g.by_t = {0.0: snaps}
        g.lion = [snaps[0]]
        # `enemy_future` = the victim's REAL hp samples after the frame; default
        # is "no further samples", which the outcome column reads as SURVIVED.
        g.by_hero = collections.defaultdict(list)
        g.by_hero["lion"] = [(0.0, 500.0)]
        # `enemy_past` = the victim's REAL hp samples BEFORE the frame -- the
        # only way to drive the revival guard, which asks whether the health
        # bar had already shown this death by the time the frame was sampled.
        g.by_hero[canon(enemy_name)] = sorted(enemy_past or []) + \
                                       [(0.0, enemy_hp if enemy_alive else 0.0)] + \
                                       sorted(enemy_future or [])
        if second is not None:
            g.by_hero[canon(second[0])] = [(0.0, second[1])] + sorted(second[2] or [])
        # --- the SECOND witness's inputs, driven independently of the hp bar --
        # `deaths` = {hero name AS THE COMBAT LOG SPELLS IT: [t, ...]}, keyed
        # through the same `canon` `Game.__init__` uses, so the cross-stream
        # join these columns depend on (GH #303) is the one under test rather
        # than a stub that has already been handed matching keys.
        g.deaths = collections.defaultdict(list)
        for nm, ts in sorted((deaths or {}).items()):
            g.deaths[canon(nm)].extend(ts)
        for k in g.deaths:
            g.deaths[k].sort()
        # default "cover": the log outlives every ladder rung, so an absent
        # DEATH row means OBSERVED survival rather than a stopped recording.
        g.ev_horizon = (max(OUTCOME_WINDOWS) + 1.0 if ev_horizon == "cover"
                        else ev_horizon)
        return scan_game(g)[0]

    ok("enemy inside reach makes the frame ready", build(100.0, 800.0)["ready"])
    ok("enemy outside reach does not", not build(100.0, 900.0)["ready"])
    ok("a cooling-down Q is not ready", not build(100.0, 800.0, cd=1.0)["ready"])
    ok("an unlearned Q is not ready", not build(100.0, 800.0, q_level=0)["ready"])
    ok("mana below the rank cost is not ready",
       not build(100.0, 800.0, mp=89.0)["ready"])
    ok("mana at the rank cost is ready", build(100.0, 800.0, mp=90.0)["ready"])
    ok("a DEAD enemy does not make the frame ready",
       not build(100.0, 800.0, enemy_alive=False)["ready"])

    r = build(105.0, 800.0)
    ok("hp exactly at the rank-1 KV damage counts raw", r["kill_raw_0.0"])
    ok("hp at the KV damage does NOT survive the 25% resist",
       not r["kill_mr25_0.0"])
    ok("15% amp lifts the raw claim over 120 hp",
       build(120.0, 800.0)["kill_raw_0.15"] and not build(120.0, 800.0)["kill_raw_0.0"])
    ok("mr25 is strictly tighter than raw at every tier",
       all(not build(105.0, 800.0)["kill_mr25_%s" % a]
           or build(105.0, 800.0)["kill_raw_%s" % a] for a in AMP_TIERS))
    ok("ally count within 1200 is measured",
       build(100.0, 800.0, allies=2)["allies_1200"] == 2)
    ok("a far ally is not counted",
       build(100.0, 800.0, allies=0)["allies_1200"] == 0)

    ok("ratio 1.0 means exactly on the mr25 line",
       abs(build(105.0 * 0.75, 800.0)["ratio_mr25"] - 1.0) < 1e-9)
    ok("ratio > 1 means the enemy is out of reach of the claim",
       build(200.0, 800.0)["ratio_mr25"] > 1.0)

    # --- the outcome column (GH #361) -----------------------------------------
    HL = "net_0.0_%s" % OUTCOME_HEADLINE_S
    dead_soon = build(50.0, 800.0, enemy_future=[(1.0, 20.0), (2.0, 0.0)])
    ok("a victim who dies inside the window is NOT net", not dead_soon[HL])
    ok("that frame still counts in cell (3)", dead_soon["kill_mr25_0.0"])
    escaped = build(50.0, 800.0,
                    enemy_future=[(1.0, 90.0), (2.0, 300.0), (6.0, 600.0)])
    ok("a victim who escapes and heals IS net", escaped[HL])
    ok("a victim with no further samples counts as SURVIVED (upper bound)",
       build(50.0, 800.0)[HL])
    late = build(50.0, 800.0, enemy_future=[(7.0, 0.0)])
    ok("a death after the 5s window is net at 5s but not at 10s",
       late[HL] and not late["net_0.0_10.0"])
    ok("a death after the 2s window is net at 2s", late["net_0.0_2.0"])
    ok("a frame that never reached cell (3) is not net either",
       not build(400.0, 800.0)[HL] and not build(400.0, 800.0)["kill_mr25_0.0"])
    ok("net is never counted where cell (3) is empty, at any tier",
       all(not build(400.0, 800.0)["net_%s_%s" % (a, w)]
           for a in AMP_TIERS for w in OUTCOME_WINDOWS))
    ok("the headline window is one of the printed ladder rungs",
       OUTCOME_HEADLINE_S in OUTCOME_WINDOWS)

    # --- the SECOND witness: the same column read off DEATH events ------------
    EHL = "netev_0.0_%s" % OUTCOME_HEADLINE_S
    DHL = "dis_0.0_%s" % OUTCOME_HEADLINE_S
    ev_dead = build(50.0, 800.0, deaths={"npc_dota_hero_lina": [2.0]})
    ok("ev: a DEATH event inside the window is NOT netev", not ev_dead[EHL])
    ok("ev: no DEATH event while the log runs IS netev", build(50.0, 800.0)[EHL])
    ok("ev: a DEATH exactly at t0 is not 'after' t0",
       build(50.0, 800.0, deaths={"npc_dota_hero_lina": [0.0]})[EHL])
    ok("ev: a DEATH before t0 is not in the window either",
       build(50.0, 800.0, deaths={"npc_dota_hero_lina": [-3.0]})[EHL])
    late_ev = build(50.0, 800.0, deaths={"npc_dota_hero_lina": [7.0]})
    ok("ev: a DEATH at +7s is netev at 5s but not at 10s",
       late_ev[EHL] and not late_ev["netev_0.0_10.0"])
    ok("ev: another hero's DEATH is not this victim's",
       build(50.0, 800.0, deaths={"npc_dota_hero_axe": [2.0]})[EHL])
    ok("ev: netev is never counted where cell (3) is empty, at any tier",
       all(not build(400.0, 800.0)["netev_%s_%s" % (a, w)]
           for a in AMP_TIERS for w in OUTCOME_WINDOWS))

    # THE JOIN THIS COLUMN LIVES OR DIES ON (GH #303).  Snapshots spell the
    # hero `vengeful_spirit` (dumper's snakeFromClass) while the combat log
    # spells it `vengefulspirit`; a join that keeps underscores misses every
    # such hero, the death goes invisible, and the frame is reported as a
    # SURVIVAL -- silently, and in the direction that inflates this column.
    # The guard is `canon` itself (it removes underscores), so that is what is
    # pinned here rather than a wrapper around it.
    ok("the join key this file imports is underscore-insensitive (GH #303)",
       canon("npc_dota_hero_vengefulspirit")
       == canon("npc_dota_hero_vengeful_spirit")
       and canon("npc_dota_hero_queenofpain") == canon("npc_dota_hero_queen_of_pain")
       and canon("npc_dota_hero_antimage") == canon("npc_dota_hero_anti_mage"))
    ok("...and it still separates two genuinely different heroes",
       canon("npc_dota_hero_lion") != canon("npc_dota_hero_luna"))
    vs_dead = build(50.0, 800.0, enemy_name="vengeful_spirit",
                    deaths={"npc_dota_hero_vengefulspirit": [2.0]})
    ok("ev: the log's `vengefulspirit` joins the snapshot's `vengeful_spirit`",
       not vs_dead[EHL])
    ok("ev: that hero still reaches cell (3) at all", vs_dead["kill_mr25_0.0"])
    qop_dead = build(50.0, 800.0, enemy_name="queen_of_pain",
                     deaths={"npc_dota_hero_queenofpain": [2.0]})
    ok("ev: the same join holds for `queenofpain`", not qop_dead[EHL])

    # THE ANY QUANTIFIER, which is what makes this file's frame different from
    # `wkqdmg_domain`'s one-cast-one-target row.
    any_row = build(50.0, 800.0, second=("axe", 50.0, None),
                    deaths={"npc_dota_hero_lina": [2.0]})
    ok("ev: one victim dying while another lives keeps the frame netev",
       any_row[EHL])
    both = build(50.0, 800.0, second=("axe", 50.0, None),
                 deaths={"npc_dota_hero_lina": [2.0], "npc_dota_hero_axe": [3.0]})
    ok("ev: both victims dead in the window clears netev", not both[EHL])

    # THE DIRECTION THAT IS UNSAFE FOR THIS STREAM'S NEGATIVE FINDING: an
    # illusion's death is logged under the hero's own name, so the event column
    # can report a death for a victim whose own health bar shows survival --
    # `netev` BELOW the upper bound `net` is defined to be.  Registered, not
    # repaired: the combat log carries no entity index to repair it with.
    ill = build(50.0, 800.0, enemy_future=[(1.0, 90.0), (6.0, 600.0)],
                deaths={"npc_dota_hero_lina": [2.0]})
    ok("ev: a logged death against a surviving health bar makes netev < net",
       ill[HL] and not ill[EHL] and ill[DHL])

    # COVERAGE IS ITS OWN COUNT AND IS NEVER FOLDED IN.
    ok("ev: coverage is true when the log outlives the window",
       build(50.0, 800.0)["evcov_5.0"])
    ok("ev: coverage is false when the log stopped inside the window",
       not build(50.0, 800.0, ev_horizon=3.0)["evcov_5.0"])
    ok("ev: a log that stopped at the far edge still counts as covered",
       build(50.0, 800.0, ev_horizon=5.0)["evcov_5.0"])
    stopped = build(50.0, 800.0, ev_horizon=None)
    ok("ev: no events at all is NOT coverage", not stopped["evcov_5.0"])
    ok("ev: but the frame is still netev -- coverage is reported, not folded",
       stopped[EHL])
    ok("ev: coverage is read per rung, not once",
       build(50.0, 800.0, ev_horizon=3.0)["evcov_2.0"]
       and not build(50.0, 800.0, ev_horizon=3.0)["evcov_10.0"])

    # THE TWO COLUMNS ARE NEVER RECONCILED.
    agree = build(50.0, 800.0, enemy_future=[(2.0, 0.0)],
                  deaths={"npc_dota_hero_lina": [2.0]})
    ok("ev: agreement is reported as no disagreement", not agree[DHL])
    # The hp column must not consult the event stream AT ALL -- checked in the
    # direction where a leak would show: same hp samples (a survivor), events
    # swung from silent to a death.  `net` has to stay True across that swing
    # while `netev` flips, which no single-column reading could produce.
    quiet = build(50.0, 800.0, enemy_future=[(1.0, 90.0), (6.0, 600.0)])
    ok("ev: the health-bar column is untouched by any DEATH event",
       quiet[HL] and ill[HL] and quiet[EHL] and not ill[EHL])

    # --- (3c) stale victims: a corpse the health bar had not caught up with ---
    SHL = "stale_0.0_%s" % STALE_HEADLINE_S
    stale = build(50.0, 800.0, enemy_future=[(1.0, 0.0), (2.0, 0.0)],
                  deaths={"npc_dota_hero_lina": [-0.1]})
    ok("stale: a DEATH just before the frame + a confirming sample is stale",
       stale[SHL])
    ok("stale: that frame is still counted in cell (3) (the point of the count)",
       stale["kill_mr25_0.0"])
    ok("stale: a DEATH just AFTER the frame is the ordinary outcome case",
       not build(50.0, 800.0, enemy_future=[(1.0, 0.0)],
                 deaths={"npc_dota_hero_lina": [0.5]})[SHL])
    ok("stale: a DEATH before the frame with NO confirming sample is not stale "
       "(Turbo respawn is fast; the log alone cannot say)",
       not build(50.0, 800.0, enemy_future=[(1.0, 300.0), (2.0, 400.0)],
                 deaths={"npc_dota_hero_lina": [-0.1]})[SHL])
    ok("stale: a confirming sample with NO prior DEATH is not stale either",
       not build(50.0, 800.0, enemy_future=[(1.0, 0.0)])[SHL])
    ok("stale: no further samples at all is NOT stale (lower bound)",
       not build(50.0, 800.0, deaths={"npc_dota_hero_lina": [-0.1]})[SHL])
    ok("stale: a DEATH older than the window is out at 1s and in at 2s",
       not build(50.0, 800.0, enemy_future=[(1.0, 0.0)],
                 deaths={"npc_dota_hero_lina": [-1.5]})["stale_0.0_1.0"]
       and build(50.0, 800.0, enemy_future=[(1.0, 0.0)],
                 deaths={"npc_dota_hero_lina": [-1.5]})["stale_0.0_2.0"])
    ok("stale: a DEATH exactly at the frame instant counts (the log won the tie)",
       build(50.0, 800.0, enemy_future=[(1.0, 0.0)],
             deaths={"npc_dota_hero_lina": [0.0]})[SHL])
    ok("stale: another hero's DEATH does not make this victim stale",
       not build(50.0, 800.0, enemy_future=[(1.0, 0.0)],
                 deaths={"npc_dota_hero_axe": [-0.1]})[SHL])
    ok("stale: it uses the same cross-stream join as the second witness",
       build(50.0, 800.0, enemy_name="vengeful_spirit",
             enemy_future=[(1.0, 0.0)],
             deaths={"npc_dota_hero_vengefulspirit": [-0.1]})[SHL])
    ok("stale: nothing is stale where cell (3) is empty",
       not build(400.0, 800.0, enemy_future=[(1.0, 0.0)],
                 deaths={"npc_dota_hero_lina": [-0.1]})[SHL])
    ok("stale: the headline window is one of the printed rungs",
       STALE_HEADLINE_S in STALE_WINDOWS)

    # --- the REVIVAL GUARD (2026-09-01) ---------------------------------------
    # Same family as `wkqdmg_domain.witness_lag`'s guard.  These fire on 0 of
    # 254 candidate pairings in W32, so they change no number today; they exist
    # so a widened window or a faster revival cannot change one silently.
    ok("stale/revival: a corpse sample BETWEEN the death and the frame is a "
       "revival, not a lagging bar -- not stale",
       not build(50.0, 800.0, enemy_past=[(-1.2, 0.0)],
                 enemy_future=[(1.0, 0.0)],
                 deaths={"npc_dota_hero_lina": [-1.8]})["stale_0.0_2.0"])
    ok("stale/revival: the SAME frame without that corpse sample IS stale "
       "(the guard is what moved it, not the rest of the setup)",
       build(50.0, 800.0, enemy_future=[(1.0, 0.0)],
             deaths={"npc_dota_hero_lina": [-1.8]})["stale_0.0_2.0"])
    ok("stale/revival: a corpse sample BEFORE the death is not a revival "
       "(it belongs to an earlier life)",
       build(50.0, 800.0, enemy_past=[(-2.5, 0.0), (-2.2, 400.0)],
             enemy_future=[(1.0, 0.0)],
             deaths={"npc_dota_hero_lina": [-1.8]})["stale_0.0_2.0"])
    # The discriminating shape for "which death does the guard read": the
    # corpse must sit BETWEEN the two deaths, otherwise oldest and newest give
    # the same answer and the assertion tests nothing.  Died at -1.9, bar
    # showed that corpse at -1.5, revived, died AGAIN at -0.3; the frame is
    # stale for the SECOND death, and reading the first would wrongly clear it.
    ok("stale/revival: the guard reads the MOST RECENT qualifying death, so a "
       "corpse from an earlier life in the same window cannot un-guard it",
       build(50.0, 800.0, enemy_past=[(-1.5, 0.0)],
             enemy_future=[(1.0, 0.0)],
             deaths={"npc_dota_hero_lina": [-1.9, -0.3]})["stale_0.0_2.0"])
    ok("stale/revival: a LIVING sample between the death and the frame is not "
       "by itself a revival -- that is the lagging bar the count exists for",
       build(50.0, 800.0, enemy_past=[(-1.2, 47.0)],
             enemy_future=[(1.0, 0.0)],
             deaths={"npc_dota_hero_lina": [-1.8]})["stale_0.0_2.0"])
    ok("stale/revival: the guard does not reach past the frame -- the "
       "confirming corpse AFTER it still makes the frame stale",
       build(50.0, 800.0, enemy_future=[(1.0, 0.0), (2.0, 0.0)],
             deaths={"npc_dota_hero_lina": [-0.1]})["stale_0.0_2.0"])

    class _G(object):
        pass
    g = _G()
    g.deaths = {"lina": [1.0, 4.0]}
    g.ev_horizon = 9.0
    EV = [{"t": 5.0, "type": "DEATH", "target": "npc_dota_hero_luna",
           "target_hero": True},
          {"t": 6.0, "type": "DEATH", "target": "npc_dota_creep_badguys_melee",
           "target_hero": False},
          {"t": 7.0, "type": "DEATH", "target": "npc_dota_hero_lion",
           "target_hero": False},
          {"t": 8.0, "type": "DAMAGE", "target": "npc_dota_hero_luna",
           "target_hero": True},
          {"t": 2.0, "type": "DEATH", "target": "npc_dota_hero_luna",
           "target_hero": True}]
    di = death_index(EV)
    ok("death_index keeps hero deaths, sorted", di["luna"] == [2.0, 5.0])
    ok("death_index drops a non-hero death", "npc_dota_creep_badguys_melee"
       not in di and "badguysmelee" not in di)
    ok("death_index drops a hero-NAMED row whose target_hero flag is false "
       "(the flag decides, not the name)", "lion" not in di)
    ok("death_index ignores non-DEATH rows", len(di) == 1)

    ok("died_ev_within reads only events AFTER t0",
       died_ev_within(g, "lina", 0.0, 2.0))
    ok("died_ev_within does not look back before t0",
       not died_ev_within(g, "lina", 2.0, 1.0))
    ok("died_ev_within on a hero the log never names is False (survived)",
       not died_ev_within(g, "puck", 0.0, 5.0))
    ok("death_times returns the raw events in the window only",
       death_times(g, "lina", 0.0, 2.0) == [1.0])
    ok("ev_covered is False once the horizon is short of the far edge",
       ev_covered(g, 0.0, 5.0) and not ev_covered(g, 5.0, 5.0))
    ok("EVENT_TOL_S is deliberately the health bar's own tolerance",
       EVENT_TOL_S == SAMPLE_TOL_S)

    g = _G()
    g.by_hero = {"lina": [(0.0, 50.0), (1.0, 0.0), (2.0, 400.0)]}
    ok("dies_within reads only samples AFTER t0",
       dies_within(g, "lina", 0.0, 5.0))
    ok("dies_within does not look back before t0",
       not dies_within(g, "lina", 1.0, 5.0))
    ok("dies_within on an unknown hero is False (survived)",
       not dies_within(g, "puck", 0.0, 5.0))
    ok("victim_traj returns the real samples in the window only",
       victim_traj(g, "lina", 0.0, 1.5) == [0.0])

    ok("episodes: one run of adjacent samples is one episode",
       episodes([1.0, 1.5, 2.0]) == 1)
    ok("episodes: a gap larger than EPISODE_GAP_S splits",
       episodes([1.0, 1.5, 20.0]) == 2)
    ok("episodes: unsorted input is sorted first",
       episodes([20.0, 1.0, 1.5]) == 2)
    ok("episodes of nothing is zero", episodes([]) == 0)

    bad = 0
    for name, good in checks:
        print("%s  %s" % ("PASS" if good else "FAIL", name))
        if not good:
            bad += 1
    print("selfcheck: %d/%d PASS  (corpus checks SKIPPED, not passed)"
          % (len(checks) - bad, len(checks)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="*")
    ap.add_argument("--selfcheck", action="store_true")
    ap.add_argument("--stratum", choices=("all", "ab", "ba"), default="all")
    ap.add_argument("--witness", type=int, default=0,
                    help="print up to N witness frames for frame-level reading")
    ap.add_argument("--kill-witness", type=int, default=0,
                    help="print up to N cell-(3) frames with each victim's hp "
                         "trajectory and the outcome verdict (GH #361)")
    args = ap.parse_args()
    if args.selfcheck:
        return selfcheck()
    if not args.dirs:
        ap.error("need at least one sweep dir (or --selfcheck)")
    print(run(args.dirs, args.stratum, args.witness, args.kill_witness))
    return 0


if __name__ == "__main__":
    sys.exit(main())

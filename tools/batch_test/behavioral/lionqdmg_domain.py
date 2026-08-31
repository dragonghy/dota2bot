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


def victim_traj(game, hero, t0, window):
    """The hero's REAL hp samples in (t0, t0 + window], for frame-level reading."""
    return [hp for t, hp in game.by_hero.get(hero, ())
            if t0 + SAMPLE_TOL_S < t <= t0 + window + SAMPLE_TOL_S]


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
            if amp == 0.0:
                row["kill_victims"] = [
                    (canon(e["hero"]), e["hp"],
                     dies_within(game, canon(e["hero"]), s["t"],
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
    out.append("| cell | ready episodes | kill(mr25,0%%) episodes | net episodes (<=%gs) |"
               % OUTCOME_HEADLINE_S)
    out.append("|---|---|---|---|")
    for c in CELLS:
        a = cells[c]
        out.append("| %s/%s | %d | %d | %d%s |"
                   % (c[0], c[1], a["ep_ready"], a["ep_kill"], a["ep_net"],
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
    a["ep_net"] = 0
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
        t_ready, t_kill, t_net = [], [], []
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
                if kill_witness and len(kill_rows) < kill_witness:
                    kill_rows.append(
                        (run_name[-6:], game_name, seed, side, cell, r,
                         [(v[0], v[1], v[2],
                           victim_traj(game, v[0], r["t"], max(OUTCOME_WINDOWS)))
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
        tail += ["", "## cell (3) frames with the outcome column (amp 0%, mr25)",
                 "", "| run/game | cell | t | victim | hp | died<=%gs | hp samples (%gs) |"
                 % (OUTCOME_HEADLINE_S, max(OUTCOME_WINDOWS)),
                 "|---|---|---|---|---|---|---|"]
        for run_name, game_name, seed, side, cell, r, vs in kill_rows:
            for hero, hp, died, traj in vs:
                tail.append("| `%s/%s` | %s/%s | %.1f | %s | %.0f | %s | %s |"
                            % (run_name, game_name, cell[0], cell[1], r["t"],
                               hero, hp, "yes" if died else "**no**",
                               " ".join("%.0f" % h for h in traj)))
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
              allies=0, enemy_alive=True, enemy_future=None):
        snaps = [_snap(t=0.0, abilities=_q(q_level, cd), mp=mp, level=lion_level)]
        snaps.append(_snap(t=0.0, hero="npc_dota_hero_lina", idx=2, team=3,
                           hp=enemy_hp if enemy_alive else 0.0, x=enemy_x,
                           abilities=[]))
        for i in range(allies):
            snaps.append(_snap(t=0.0, hero="npc_dota_hero_zuus", idx=10 + i,
                               team=2, x=100.0 * (i + 1), abilities=[]))
        g = Game.__new__(Game)
        g.teams = {"npc_dota_hero_lion": 2, "npc_dota_hero_lina": 3,
                   "npc_dota_hero_zuus": 2}
        g.has_lion = True
        g.lion_team = 2
        g.primary = {"lion": 1, "lina": 2, "zuus": 10}
        g.by_t = {0.0: snaps}
        g.lion = [snaps[0]]
        # `enemy_future` = the victim's REAL hp samples after the frame; default
        # is "no further samples", which the outcome column reads as SURVIVED.
        g.by_hero = collections.defaultdict(list)
        g.by_hero["lion"] = [(0.0, 500.0)]
        g.by_hero["lina"] = [(0.0, enemy_hp if enemy_alive else 0.0)] + \
                            sorted(enemy_future or [])
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

    class _G(object):
        pass
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

#!/usr/bin/env python3
"""Condition-(a) instrument for the `overchase` soak candidate (replay-check).

WHAT `overchase` IS
-------------------
`J.ShouldPunishOverchase` (`bots/FunLib/jmz_func.lua`) is gated turbo-only on
the unpromoted `overchase` id, so it returns nil in every shipped game.  Armed,
it hands `mode_team_roam_generic.lua:315` a target and bids a defensive
collapse -- "an enemy over-chased a low-HP ally of mine deep into our half,
out-running its own support; turn and counter-kill instead of fleeing".

Its admission conjunction, as the source reads it, is four clauses:

    RING      the chaser is within the collapse ring of THIS bot
    ISOLATED  at most `<=1` enemy hero within the isolation ring of the chaser
              (the list includes the chaser itself)
    DEEP      a live building of ours within the building ring of the chaser,
              OR the chaser is past the midline into our half by the margin
              (depth = dist(chaser, THEIR ancient) - dist(chaser, OUR ancient))
    LOWALLY   an ally that is not this bot, within the ally ring of the chaser,
              under the HP fraction, that the chaser is ON (attack target, or
              `J.IsChasingTarget`, or damaged by that chaser in the last 2.0s)

and then one commit test, `J.SafeToCommitFight(bot, enemy)`.

WHY THIS FILE EXISTS
--------------------
`overchase` has been armed for weeks with no `VERIFY` line at all.  The
2026-09-11 director ruling (RULING 13 §GS.5, owed row
`a_evidence_overchase_instrument`, GH #540) priced why: of the five UNOWED ids
it was the only `MENTION` -- no detector anywhere in the repo names it in a
topic sentence; its only appearances are inside `capmono_gradient.py` /
`capmono_refusal.py`, which name it as a CONFOUNDER of capmono ("`ownhalf` /
`overchase` / `l1trade` / `l5combo` push the other way").  That is the opposite
of an instrument.  So the purchase for this id was "build the instrument", a
strictly larger purchase than "run the existing one" -- and this file is it.

The shape is deliberately the one `ownhalf_domain.py` proved two days earlier
(`MENTION` -> `DELIVER` -> `VERIFY ... WORKING` inside 48h), because the two
levers are siblings: both admit a target into the SAME collapse pathway in
`mode_team_roam_generic`, both are geometry-plus-commit-test, and both have a
commit test the dump cannot evaluate.

⚠️ CORPUS CAVEAT THAT MUST TRAVEL WITH EVERY READING (`state.json`:
`overchase_KEPT_20260908`, `test_set.md` §FY): the BODY of
`J.ShouldPunishOverchase` was swapped on 2026-09-07T23:xxZ (the midline margin
was narrowed, and the narrowing INHERITED the host's id rather than taking a
new one).  W64 is the first wave reading on the new body.  Do not pool waves
harvested before that instant with waves after it -- `--min-harvest` exists to
make that refusal mechanical rather than remembered.

WHAT THIS MEASURES, AND WHAT IT CANNOT
--------------------------------------
It evaluates RING / ISOLATED / DEEP exactly -- all three are pure geometry and
the dump carries every input.  It evaluates LOWALLY on its THIRD limb only
(`WasRecentlyDamagedByHero`), because the other two limbs read order state the
replay never networked.

So the two error directions are NOT symmetric, and both are named on every
printed table:

  * `SafeToCommitFight` is unobservable  => an admitted episode is an UPPER
    BOUND on firing (the gate may have refused it downstream).
  * two of three chase limbs are unobservable => the damage-witnessed band is
    a LOWER BOUND on LOWALLY (a chaser walking a low ally down without having
    landed a hit in the last 2s is real and is not counted).

`--loose` prints the proximity-only chase band alongside, so the reader can see
the size of that second gap instead of inferring it.

THE DISCRIMINATOR (2026-09-13, replay-check)
--------------------------------------------
The 2026-09-12 reading came back INDETERMINATE, and the thing that decided it
was not the sign-flipped aggregate but two BASELINE-leg frames: on the leg
where this gate is shut entirely, `closed` still read 35-46%, and a 1%-HP
phantom_assassin being run down by a skywrath was scored as a textbook
collapse.  `closed` = d0 - dmin is the SUM of two bodies' motion, so it counts
"the bot turned and punished" and "the bot was caught" as the same event --
which is precisely the distinction the gate exists to make.

`punish` and `rundown` split that sum, and each needs BOTH halves:

    punish   the BOT's own displacement toward the chaser, projected on the
             line that joined them at admission, is >= CLOSE_DELTA and is the
             larger of the two advances, AND the bot landed hero damage on the
             chaser inside the same consequence window.
    rundown  the mirror: the CHASER supplied the advance, it landed damage on
             the bot, and the bot landed none.

An episode can be neither (nobody committed); they are never both.  Motion
comes from the snapshot stream and damage from the DAMAGE event stream, so
neither half is inferred from the other.

THE CONTROLS (the answer to an unobservable commit test is not a better
estimate of it -- it is a control that shares the blindness)
----------------------------------------------------------------------------
  * THE BASELINE LEG.  `overchase` is unpromoted, so in a mirrored game the
    other side's gate is CLOSED ENTIRELY -- not narrowed, closed.  Every
    admitted episode still exists there as geometry; whatever closing behaviour
    appears on it is what the rest of the tree does anyway.  armed minus
    baseline on the admitted band is the lever's behavioural signature.
  * THE NEAR-MISS BAND (the discontinuity control).  Pairs that satisfy RING,
    ISOLATED and LOWALLY, have no building door, and whose depth lands just
    SHORT of the margin are geometrically almost the same frames -- same map
    region, same kind of chase -- and the gate admits NEITHER LEG on them.  The
    armed-vs-baseline difference measured there is this instrument's own noise
    floor, from the same corpus with the same statistic.
  * THE NO-ALLY BAND (the null channel).  Pairs that satisfy RING, ISOLATED and
    DEEP but have no low-HP ally at all: the gate is STRUCTURALLY SILENT on
    both legs.  This is the `tpcommit` / `blinkflee` null-channel buy -- a
    second floor, built from a different clause than the near-miss floor.

A signature that does not clear BOTH floors is not a reading.
⚠️ And a signature that does clear them proves the gate MOVED something, not
which DIRECTION it moved it -- that is the boundary `blinkflee` hit on
2026-09-11 (GH #757): a gate that withholds a bid can hand control flow to a
downstream branch, and the same aggregate then has two readings.  Here the
downstream branch is named and observable (`J.ShouldInitiateLaneKill` at
`mode_team_roam_generic.lua:334`, and the `l1trade` id that gates it), so
`--opponents` prints whether it was armed in the same wave.

STRATA (iron rule 4(i-a)/(i-b))
-------------------------------
Every rate is printed for the `ab` stratum (armed side = radiant) and the `ba`
stratum (armed side = dire) separately, never only pooled.  Episode counts are
NOT side-de-biased, so a two-stratum sign flip is noise (4(i-b)) and must not
enter a conclusion -- it is still registered (4(i-a)).

USAGE
    overchase_domain.py --sweep <sweep_out_dir> [--sweep <dir> ...] [--loose]
    overchase_domain.py <timeline.json> --side radiant|dire
    overchase_domain.py <timeline.json> --side radiant --trace <bot> <enemy> <t>
    overchase_domain.py --selfcheck

Read-only; no AWS writes, no network.
"""
from __future__ import annotations

import argparse
import collections
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from entities import canon, frames_by_hero  # noqa: E402
from source_constants import call_arg, literal  # noqa: E402

RADIANT, DIRE = 2, 3
GATE = 'J.ShouldPunishOverchase'

# --- thresholds READ OUT OF the shipped Lua (GH #90 contract) ---------------
# Never copied.  `overchase`'s margin is the one that moved (§FY, 2026-09-07):
# a hand-copied 800 here would be a file that is correct about a lever that no
# longer exists, with nothing red anywhere.
COLLAPSE_RING = call_arg(GATE, 'J.GetNearbyHeroes', index=1, where={2: 'true'})
ISOLATE_RING = call_arg(GATE, 'J.GetEnemiesNearLoc', index=1)
ISOLATE_MAX = literal(GATE, r'J\.GetEnemiesNearLoc\([^()]*\)\s*<=\s*(?P<n>\d+)')
BUILDING_RING = literal(GATE, r'GetUnitToUnitDistance\(\s*enemy,\s*building\s*\)'
                              r'\s*<=\s*(?P<n>\d+)')
DEPTH_MARGIN = literal(GATE, r'hEnemyAncient:GetLocation\(\)\s*\)\s*-\s*(?P<n>\d+)')
ALLY_RING = call_arg(GATE, 'J.GetAlliesNearLoc', index=1)
ALLY_HP = literal(GATE, r'J\.GetHP\(\s*ally\s*\)\s*<\s*(?P<n>[0-9.]+)')
RECENT_DMG = literal(GATE, r'WasRecentlyDamagedByHero\(\s*enemy,\s*(?P<n>[0-9.]+)\s*\)')

# --- episode + consequence shape (same constants as ownhalf_domain.py, so the
#     two siblings' readings are on one scale) ------------------------------
EPISODE_GAP = 2.5        # snapshots are 1s apart; a wider gap is a new decision
CONSEQUENCE_WIN = 4.0    # the collapse is a move order, not an instant
CLOSE_DELTA = 250.0      # "closed on it": cut this much off the start distance
ENGAGE_RANGE = 600.0     # "engaged it": actually arrived in fighting range
# One screen of DEPTH short of the margin.  A depth is a DIFFERENCE of ancient
# distances and so runs at twice the real midline offset (GH #687): 800 of
# depth is ~400u of ground.
NEARMISS_WIDTH = 800.0


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


class Game(object):
    """One mirrored game: geometry, legs, and the gate's admission clauses."""

    def __init__(self, tl_path, armed_side, name=None):
        with open(tl_path) as fh:
            d = json.load(fh)
        self.name = name or os.path.basename(tl_path)
        self.armed_team = RADIANT if armed_side == 'radiant' else DIRE
        self.side = armed_side
        frames, teams = frames_by_hero(d)
        self.teams = {h: teams[h] for h in frames}
        self.by_t = collections.defaultdict(dict)
        for h in frames:
            for s in frames[h]:
                self.by_t[s['t']][h] = s
        self.times = sorted(self.by_t)

        # buildings: last sample at or before a hero frame, alive only
        self.btimes, self.blds, self.ancients = [], {}, {}
        by_t = collections.defaultdict(lambda: {RADIANT: [], DIRE: []})
        anc_by_t = collections.defaultdict(dict)
        for b in d.get('buildings', ()):
            if not b.get('alive'):
                continue
            by_t[b['t']][b['team']].append((b['x'], b['y']))
            if b.get('name') == 'ancient':
                anc_by_t[b['t']][b['team']] = (b['x'], b['y'])
        for t in sorted(by_t):
            self.btimes.append(t)
            self.blds[t] = by_t[t]
            self.ancients[t] = anc_by_t.get(t, {})

        # hero-on-hero damage times, canon-keyed on BOTH ends.
        # ⚠️ W66's lesson (charter tool-pit #1): the snapshot stream and the
        # event stream spell heroes differently, and a raw-name lookup here
        # returns empty for every pair while raising nothing.
        self.dmg = collections.defaultdict(list)
        for e in d.get('events', ()):
            if e.get('type') != 'DAMAGE':
                continue
            if not (e.get('actor_hero') and e.get('target_hero')):
                continue
            self.dmg[(canon(e['actor']), canon(e['target']))].append(e['t'])
        for k in self.dmg:
            self.dmg[k].sort()

    # -- legs -------------------------------------------------------------
    def leg(self, hero):
        return 'armed' if self.teams.get(hero) == self.armed_team else 'baseline'

    def _bucket(self, t):
        lo, hi = 0, len(self.btimes) - 1
        if hi < 0 or t < self.btimes[0]:
            return None
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if self.btimes[mid] <= t:
                lo = mid
            else:
                hi = mid - 1
        return self.btimes[lo]

    # -- the gate's clauses ------------------------------------------------
    def deep(self, t, my_team, ex, ey):
        """(building_door, depth) for a chaser at (ex, ey); None = undecidable."""
        bt = self._bucket(t)
        if bt is None:
            return None
        for bx, by in self.blds[bt][my_team]:
            if dist(ex, ey, bx, by) <= BUILDING_RING:
                return (True, None)
        anc = self.ancients[bt]
        foe = DIRE if my_team == RADIANT else RADIANT
        if my_team not in anc or foe not in anc:
            return None                      # refuse to answer, never guess
        ox, oy = anc[my_team]
        fx, fy = anc[foe]
        return (False, dist(ex, ey, fx, fy) - dist(ex, ey, ox, oy))

    def isolated(self, live, eteam, ex, ey):
        n = 0
        for h, s in live:
            if self.teams[h] != eteam:
                continue
            if dist(s['x'], s['y'], ex, ey) <= ISOLATE_RING:
                n += 1
        return n <= ISOLATE_MAX

    def hit_recently(self, chaser, ally, t):
        """The one observable limb of the chase test."""
        for td in self.dmg.get((chaser, ally), ()):
            if t - RECENT_DMG <= td <= t:
                return True
        return False

    def dealt(self, actor, target, t0, t1):
        """Did `actor` land a hero-damage event on `target` inside [t0, t1]?"""
        for td in self.dmg.get((actor, target), ()):
            if t0 <= td <= t1:
                return True
        return False

    def low_ally(self, live, bot, bteam, chaser, ex, ey, t):
        """(strict, loose, witness): strict = damage-witnessed chase.

        `loose` is proximity + HP only; `strict` additionally requires the one
        chase limb the replay carries (`WasRecentlyDamagedByHero`).  Returning
        both, from one walk, is what keeps the two bounds from drifting apart.
        """
        loose, witness = False, None
        for h, s in live:
            if h == bot or self.teams[h] != bteam:
                continue
            if s.get('hp_pct', 1.0) >= ALLY_HP:
                continue
            if dist(s['x'], s['y'], ex, ey) > ALLY_RING:
                continue
            loose = True
            if witness is None:
                witness = h
            if self.hit_recently(chaser, h, t):
                return (True, True, h)
        return (False, loose, witness)

    def admitted_frames(self):
        """Yield (t, bot, chaser, band, d_pair) rows.

        Bands are disjoint by construction, and each one names WHICH clause of
        the conjunction it falls short on, so no frame is ever counted twice
        and no band silently borrows another's population:

          admit    -- every observable clause true, chase damage-witnessed
          loose    -- as `admit` but the chase limb is proximity-only
          nearmiss -- ISOLATED + LOWALLY(loose) true, no building door, depth in
                      [margin - NEARMISS_WIDTH, margin)   <- gate shut both legs
          noally   -- ISOLATED + DEEP true, no low-HP ally at all <- null channel
        """
        for t in self.times:
            here = self.by_t[t]
            live = [(h, s) for h, s in here.items() if s.get('hp', 0) > 0]
            for bh, bs in live:
                bteam = self.teams[bh]
                eteam = DIRE if bteam == RADIANT else RADIANT
                for eh, es in live:
                    if self.teams[eh] != eteam:
                        continue
                    dd = dist(bs['x'], bs['y'], es['x'], es['y'])
                    if dd > COLLAPSE_RING:
                        continue
                    if not self.isolated(live, eteam, es['x'], es['y']):
                        continue
                    dp = self.deep(t, bteam, es['x'], es['y'])
                    if dp is None:
                        continue
                    bldg, depth = dp
                    strict, loose, _w = self.low_ally(live, bh, bteam, eh,
                                                      es['x'], es['y'], t)
                    is_deep = bldg or (depth is not None and depth > DEPTH_MARGIN)
                    if is_deep and loose:
                        yield (t, bh, eh, 'admit' if strict else 'loose', dd)
                    elif is_deep and not loose:
                        yield (t, bh, eh, 'noally', dd)
                    elif (not bldg and loose and depth is not None
                          and DEPTH_MARGIN - NEARMISS_WIDTH <= depth <= DEPTH_MARGIN):
                        yield (t, bh, eh, 'nearmiss', dd)

    # -- consequence -------------------------------------------------------
    def pair_dist(self, t0, bh, eh):
        best = None
        for t in self.times:
            if t < t0:
                continue
            if t > t0 + CONSEQUENCE_WIN:
                break
            here = self.by_t[t]
            if bh not in here or eh not in here:
                continue
            b, e = here[bh], here[eh]
            if b.get('hp', 0) <= 0:
                continue
            dd = dist(b['x'], b['y'], e['x'], e['y'])
            if best is None or dd < best:
                best = dd
        return best

    def attribute(self, t0, bh, eh):
        """Who supplied the closing?  (bot_adv, chaser_adv, t_star) or None.

        `closed` (d0 - dmin) is the SUM of two bodies' motion and therefore
        cannot tell "the bot turned and punished" from "the bot was run down"
        -- 2026-09-12 read 35-46% `closed` on the BASELINE leg, where this gate
        is structurally shut, with a 1%-HP PA counted as a textbook collapse
        while she was the one dying.  This decomposes it: project each body's
        own displacement (t0 -> the frame of closest approach) onto the line
        that joined them at admission.  Positive = that body moved in.
        """
        here = self.by_t.get(t0) or {}
        if bh not in here or eh not in here:
            return None
        b0, e0 = here[bh], here[eh]
        ux, uy = e0['x'] - b0['x'], e0['y'] - b0['y']
        d0 = math.hypot(ux, uy)
        if d0 <= 1e-6:
            return None                      # no line to project onto
        ux, uy = ux / d0, uy / d0
        best, tstar = None, None
        for t in self.times:
            if t < t0:
                continue
            if t > t0 + CONSEQUENCE_WIN:
                break
            hh = self.by_t[t]
            if bh not in hh or eh not in hh:
                continue
            if hh[bh].get('hp', 0) <= 0:
                continue
            dd = dist(hh[bh]['x'], hh[bh]['y'], hh[eh]['x'], hh[eh]['y'])
            if best is None or dd < best:
                best, tstar = dd, t
        if tstar is None:
            return None
        b1, e1 = self.by_t[tstar][bh], self.by_t[tstar][eh]
        bot_adv = (b1['x'] - b0['x']) * ux + (b1['y'] - b0['y']) * uy
        chaser_adv = -((e1['x'] - e0['x']) * ux + (e1['y'] - e0['y']) * uy)
        return (bot_adv, chaser_adv, tstar)

    def died_in(self, hero, t0, t1):
        for t in self.times:
            if t < t0:
                continue
            if t > t1:
                break
            s = self.by_t[t].get(hero)
            if s is not None and s.get('hp', 0) <= 0:
                return True
        return False

    def episodes(self):
        runs, out = {}, []
        for t, bh, eh, band, dd in self.admitted_frames():
            k = (bh, eh, band)
            r = runs.get(k)
            if r is not None and t - r['t_last'] <= EPISODE_GAP:
                r['t_last'] = t
                r['frames'] += 1
                continue
            if r is not None:
                out.append(r)
            runs[k] = {'bot': bh, 'enemy': eh, 'band': band, 't0': t,
                       't_last': t, 'frames': 1, 'd0': dd}
        out.extend(runs.values())
        for ep in out:
            dmin = self.pair_dist(ep['t0'], ep['bot'], ep['enemy'])
            ep['dmin'] = dmin
            ep['closed'] = dmin is not None and ep['d0'] - dmin >= CLOSE_DELTA
            ep['engaged'] = dmin is not None and dmin <= ENGAGE_RANGE
            t1 = ep['t0'] + CONSEQUENCE_WIN
            att = self.attribute(ep['t0'], ep['bot'], ep['enemy'])
            ep['bot_adv'] = None if att is None else round(att[0], 1)
            ep['chaser_adv'] = None if att is None else round(att[1], 1)
            ep['bot_driven'] = bool(att is not None and att[0] >= CLOSE_DELTA
                                    and att[0] >= att[1])
            ep['chaser_driven'] = bool(att is not None and att[1] >= CLOSE_DELTA
                                       and att[1] > att[0])
            ep['hit_chaser'] = self.dealt(ep['bot'], ep['enemy'], ep['t0'], t1)
            ep['hit_by_chaser'] = self.dealt(ep['enemy'], ep['bot'], ep['t0'], t1)
            ep['bot_died'] = self.died_in(ep['bot'], ep['t0'], t1)
            ep['chaser_died'] = self.died_in(ep['enemy'], ep['t0'], t1)
            # The two readings `closed` conflates, each requiring BOTH halves:
            # the body that moved AND a landed hit.  Neither is inferred from
            # the other, and an episode can be neither (nobody committed).
            ep['punish'] = bool(ep['bot_driven'] and ep['hit_chaser'])
            ep['rundown'] = bool(ep['chaser_driven'] and ep['hit_by_chaser']
                                 and not ep['hit_chaser'])
            ep['leg'] = self.leg(ep['bot'])
            ep['game'] = self.name
            ep['side'] = self.side
        out.sort(key=lambda e: e['t0'])
        return out

    # -- frame-first (charter hard rule) -----------------------------------
    def trace(self, bot, enemy, t0, span=10.0, pre=4.0):
        """Per-frame rows around one admission instant, every clause shown.

        The charter's hard rule is frame-first-then-aggregate, and a frame
        claim has to be re-runnable by the next reader -- so the trace lives in
        the instrument, not in a scratchpad probe that dies with the container.
        """
        print('# trace %s  bot=%s  chaser=%s  t0=%.1f' % (self.name, bot,
                                                          enemy, t0))
        # `hp_e` and `hit` are here because of what their ABSENCE cost on
        # 2026-09-12: this same trace, read without the chaser's HP and without
        # the damage exchange, was reported as "the bot is the one being run
        # down" on a frame where the bot killed the chaser 3s later (the
        # phantom_assassin/skywrath_mage episode below).  A column that is not
        # printed is a column the reader infers.
        print('#%7s %8s %8s %8s %5s %5s %5s %4s %7s %8s' %
              ('t', 'd_pair', 'depth', 'd_bldg', 'iso', 'hp_b', 'hp_e', 'hit',
               'ally', 'band'))
        for t in self.times:
            if t < t0 - pre or t > t0 + span:
                continue
            here = self.by_t[t]
            if bot not in here or enemy not in here:
                continue
            b, e = here[bot], here[enemy]
            live = [(h, s) for h, s in here.items() if s.get('hp', 0) > 0]
            bteam = self.teams[bot]
            eteam = self.teams[enemy]
            dp = self.deep(t, bteam, e['x'], e['y'])
            bt = self._bucket(t)
            db = -1
            if bt is not None:
                for bx, by in self.blds[bt][bteam]:
                    dd = dist(e['x'], e['y'], bx, by)
                    if db < 0 or dd < db:
                        db = dd
            iso = self.isolated(live, eteam, e['x'], e['y'])
            strict, loose, witness = self.low_ally(live, bot, bteam, enemy,
                                                   e['x'], e['y'], t)
            ally = '-'
            if witness is not None:
                ally = '%s%s' % (witness[:6], '*' if strict else '')
            bldg, depth = (dp if dp is not None else (False, None))
            is_deep = bldg or (depth is not None and depth > DEPTH_MARGIN)
            dpair = dist(b['x'], b['y'], e['x'], e['y'])
            if dpair > COLLAPSE_RING or not iso:
                band = '-'
            elif is_deep and loose:
                band = 'admit' if strict else 'loose'
            elif is_deep:
                band = 'noally'
            elif (not bldg and loose and depth is not None
                  and DEPTH_MARGIN - NEARMISS_WIDTH <= depth <= DEPTH_MARGIN):
                band = 'nearmiss'
            else:
                band = '-'
            fwd = self.dealt(bot, enemy, t - 1.0, t)
            back = self.dealt(enemy, bot, t - 1.0, t)
            hit = ('%s%s' % ('>' if fwd else '', '<' if back else '')) or '-'
            print(' %7.1f %8.0f %8.0f %8.0f %5s %5.2f %5.2f %4s %7s %8s' %
                  (t, dpair, depth if depth is not None else float('nan'), db,
                   'Y' if iso else 'n', b.get('hp_pct', -1),
                   e.get('hp_pct', -1), hit, ally, band))


def tally(eps):
    """{(stratum, leg, band): counters} -- never pooled without the strata."""
    c = collections.defaultdict(collections.Counter)
    for e in eps:
        stratum = 'ab' if e['side'] == 'radiant' else 'ba'
        k = (stratum, e['leg'], e['band'])
        c[k]['episodes'] += 1
        c[k]['frames'] += e['frames']
        c[k]['closed'] += 1 if e['closed'] else 0
        c[k]['engaged'] += 1 if e['engaged'] else 0
        c[k]['punish'] += 1 if e.get('punish') else 0
        c[k]['rundown'] += 1 if e.get('rundown') else 0
    return c


def pct(n, d):
    return '%5.1f%%' % (100.0 * n / d) if d else '    --'


def report(c, games, loose=False):
    bands = ['admit', 'nearmiss', 'noally'] + (['loose'] if loose else [])
    print('games: %d' % games)
    print('thresholds read from %s: ring=%g isolate=%g/<=%d building=%g '
          'depth_margin=%g ally_ring=%g ally_hp=%g recent_dmg=%g'
          % (GATE, COLLAPSE_RING, ISOLATE_RING, int(ISOLATE_MAX), BUILDING_RING,
             DEPTH_MARGIN, ALLY_RING, ALLY_HP, RECENT_DMG))
    print('')
    print('%-9s %-9s %-9s %7s %7s %8s %8s %8s %8s' %
          ('stratum', 'band', 'leg', 'eps', 'frames', 'closed', 'engaged',
           'punish', 'rundown'))
    for stratum in ('ab', 'ba'):
        for band in bands:
            for leg in ('armed', 'baseline'):
                k = (stratum, leg, band)
                r = c.get(k)
                if not r:
                    print('%-9s %-9s %-9s %7d %7d %8s %8s %8s %8s' %
                          (stratum, band, leg, 0, 0, '--', '--', '--', '--'))
                    continue
                print('%-9s %-9s %-9s %7d %7d %8s %8s %8s %8s' %
                      (stratum, band, leg, r['episodes'], r['frames'],
                       pct(r['closed'], r['episodes']),
                       pct(r['engaged'], r['episodes']),
                       pct(r['punish'], r['episodes']),
                       pct(r['rundown'], r['episodes'])))
        print('')
    print('DELTA (armed - baseline), percentage points, per stratum:')
    for stratum in ('ab', 'ba'):
        for band in bands:
            a = c.get((stratum, 'armed', band), collections.Counter())
            b = c.get((stratum, 'baseline', band), collections.Counter())
            if not a.get('episodes') or not b.get('episodes'):
                print('  %-3s %-9s  (a leg is empty: n_armed=%d n_base=%d)'
                      % (stratum, band, a.get('episodes', 0), b.get('episodes', 0)))
                continue
            da = 100.0 * a['closed'] / a['episodes'] - 100.0 * b['closed'] / b['episodes']
            de = 100.0 * a['engaged'] / a['episodes'] - 100.0 * b['engaged'] / b['episodes']
            dp = 100.0 * a['punish'] / a['episodes'] - 100.0 * b['punish'] / b['episodes']
            dr = 100.0 * a['rundown'] / a['episodes'] - 100.0 * b['rundown'] / b['episodes']
            print('  %-3s %-9s  closed %+6.2fpp   engaged %+6.2fpp   '
                  'punish %+6.2fpp   rundown %+6.2fpp   (n %d vs %d)'
                  % (stratum, band, da, de, dp, dr,
                     a['episodes'], b['episodes']))
    print('')
    print('LIMITS (print these with any quotation of the numbers above):')
    print('  * an `admit` episode is an UPPER BOUND on firing: the dump cannot')
    print('    evaluate J.SafeToCommitFight, the gate\'s last clause.')
    print('  * `admit` is a LOWER BOUND on the chase clause: only the')
    print('    WasRecentlyDamagedByHero limb is observable (2 of 3 limbs are')
    print('    order state the replay never networked).  --loose prices that gap.')
    print('  * episode counts are NOT side-de-biased => a two-stratum sign flip')
    print('    is noise (iron rule 4(i-b)); it is registered, not interpreted.')
    print('  * the body of %s was swapped 2026-09-07T23:xxZ (§FY);' % GATE)
    print('    readings from before that instant are a different lever.')
    print('  * `punish` / `rundown` are the 2026-09-13 discriminator: `closed`')
    print('    is the SUM of two bodies\' motion and reads 35-46%% on the leg')
    print('    where the gate is SHUT, so it cannot separate "turned and')
    print('    punished" from "was run down".  Each of the two requires BOTH a')
    print('    named body\'s own advance (>= %g along the admission line) AND a'
          % CLOSE_DELTA)
    print('    landed hero-damage event in the same window.')
    print('  * they are still not the gate\'s output: a bot can advance and hit')
    print('    a chaser for reasons this gate had no part in (that is what the')
    print('    baseline leg and the two floors are for).  `punish` says the')
    print('    episode WAS a counter-punish, not that THIS gate caused it.')
    print('  * damage is the hero-on-hero DAMAGE event stream: a kill landed by')
    print('    an illusion, a summon or a tower is not attributed to the bot,')
    print('    so `punish` is a LOWER bound on committing.')


def floor_overlap(eps, window=5.0):
    """How independent are the two floors from the band they are a floor FOR?

    A floor is only a noise floor if it is not made of the SAME physical
    events.  It is not, by construction, disjoint in TIME: the bands are
    disjoint per FRAME, so one chase can be `noally` at t and `admit` at t+1
    (the pinned 2026-09-12 PA/skywrath episode is exactly that -- `noally` at
    1578.5, `admit` at 1579.5).  This prints the share of each floor's episodes
    that share a (game, bot, chaser) with an `admit` episode inside `window`,
    so the reader sees the contamination instead of assuming it away.
    """
    admit = collections.defaultdict(list)
    for e in eps:
        if e['band'] == 'admit':
            admit[(e['game'], e['bot'], e['enemy'])].append(e['t0'])
    print('FLOOR INDEPENDENCE (share of each floor sharing a pair with an '
          '`admit` episode within %.0fs):' % window)
    for band in ('nearmiss', 'noally'):
        pop = [e for e in eps if e['band'] == band]
        if not pop:
            print('  %-9s (empty)' % band)
            continue
        n = 0
        for e in pop:
            for t in admit.get((e['game'], e['bot'], e['enemy']), ()):
                if abs(t - e['t0']) <= window:
                    n += 1
                    break
        print('  %-9s n=%-6d overlap %s' % (band, len(pop), pct(n, len(pop))))
    print('')


def load_sweep(sweep_dirs, max_games=None):
    """Games from one or more sweep_run.sh output dirs, with their armed side."""
    out = []
    for sweep_dir in sweep_dirs:
        man = os.path.join(sweep_dir, 'games_manifest.jsonl')
        tldir = os.path.join(sweep_dir, 'timelines')
        if not os.path.exists(man):
            sys.stderr.write('no games_manifest.jsonl under %s\n' % sweep_dir)
            continue
        with open(man) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                g = json.loads(line)
                if 'overchase' not in (g.get('cand') or ''):
                    continue                 # not an overchase-armed game
                tl = os.path.join(tldir, '%s.timeline.json' % g['game'])
                if not os.path.exists(tl):
                    continue
                # ⚠️ QUALIFY THE GAME KEY BY ITS RUN (replay-check 2026-09-12).
                # `<YYYYMMDD_HHMMSS>_slot<N>` is NOT unique across the machines
                # of one wave: W67's four machines launched 7s apart and
                # produced TWO colliding basenames
                # (20260911_214155_slot8, 20260911_214214_slot4).  This tool's
                # own aggregates were never wrong (each Game reads its own
                # path), but an episode row carrying the bare key invites the
                # next reader to re-join it against a glob over all runs -- and
                # that join lands on the WRONG GAME while raising nothing,
                # because both sides are real games with real heroes.  It
                # raised here only because a hero happened to be absent from
                # the other draft; that is luck, not a check.
                out.append((tl, g['side'],
                            '%s/%s' % (os.path.basename(sweep_dir.rstrip('/'))[-6:],
                                       g['game'])))
                if max_games and len(out) >= max_games:
                    return out
    return out


def selfcheck():
    """Assert the instrument still describes the gate it claims to describe.

    ⚠️ SCOPE, stated because GH #757 is exactly the failure of not stating it:
    this checks that the CLAUSES THIS FILE READS are still in the source at the
    shape it reads them.  It does NOT and cannot certify that the opponent list
    below is complete -- a branch nobody has noticed is invisible to a check
    written by the same person who missed it.
    """
    ok = True
    vals = [('collapse ring', COLLAPSE_RING), ('isolate ring', ISOLATE_RING),
            ('isolate max', ISOLATE_MAX), ('building ring', BUILDING_RING),
            ('depth margin', DEPTH_MARGIN), ('ally ring', ALLY_RING),
            ('ally hp', ALLY_HP), ('recent dmg', RECENT_DMG)]
    for nm, v in vals:
        print('  %-14s = %g' % (nm, v))
    repo = os.path.abspath(os.path.join(os.path.dirname(__file__),
                                        '..', '..', '..'))
    roam = os.path.join(repo, 'bots', 'mode_team_roam_generic.lua')
    with open(roam) as fh:
        body = fh.read()
    # The consumer, and the OTHER bidders on the same collapse pathway whose
    # behaviour this instrument cannot separate from the gate's.
    for needle in ('J.ShouldPunishOverchase(bot)', 'J.ShouldPunishDive(bot)',
                   'J.ShouldInitiateLaneKill(bot)'):
        if needle not in body:
            print('  MISSING in mode_team_roam_generic.lua: %s' % needle)
            ok = False
        else:
            print('  present: %s' % needle)
    print('selfcheck: %s' % ('OK' if ok else 'FAILED'))
    return 0 if ok else 3


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('timeline', nargs='?')
    ap.add_argument('--side', choices=('radiant', 'dire'))
    ap.add_argument('--sweep', action='append', default=[])
    ap.add_argument('--max-games', type=int)
    ap.add_argument('--loose', action='store_true',
                    help='also print the proximity-only chase band')
    ap.add_argument('--episodes', action='store_true',
                    help='dump every admitted episode as JSONL')
    ap.add_argument('--trace', nargs=3, metavar=('BOT', 'CHASER', 'T'))
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()

    if a.sweep:
        games = load_sweep(a.sweep, a.max_games)
        eps = []
        for tl, side, name in games:
            try:
                eps.extend(Game(tl, side, name).episodes())
            except Exception as exc:                    # noqa: BLE001
                sys.stderr.write('skip %s: %s\n' % (name, exc))
        if a.episodes:
            for e in eps:
                print(json.dumps(e))
            return 0
        report(tally(eps), len(games), a.loose)
        floor_overlap(eps)
        return 0

    if not a.timeline or not a.side:
        ap.error('give a timeline plus --side, or --sweep <dir>')
    g = Game(a.timeline, a.side)
    if a.trace:
        g.trace(a.trace[0], a.trace[1], float(a.trace[2]))
        return 0
    eps = g.episodes()
    if a.episodes:
        for e in eps:
            print(json.dumps(e))
        return 0
    report(tally(eps), 1, a.loose)
    return 0


if __name__ == '__main__':
    sys.exit(main())

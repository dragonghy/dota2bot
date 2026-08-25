#!/usr/bin/env python3
"""(a)-evidence for the `pulldrag` soak candidate: WHICH WAY does the puller
walk between pokes?

WHAT THE CANDIDATE DOES
-----------------------
`mode_roam_generic.lua:280-295` runs the aggro-then-drag cadence of the camp
pull: poke the camp once every 3 s, and in between take a 500 u step toward a
destination.  Shipped, that destination is `J.GetTeamFountain()`.  Armed,
`J.GetLanePullDragTarget` (jmz_func.lua:8286) replaces it with the closest
point on the bot's ASSIGNED LANE to the camp -- home was standing in for the
lane, and on the four camps the engine actually pulls from that proxy spends
81-87% of every step parallel to the lane it is trying to reach.

So the candidate does not change WHETHER the drag happens; it changes its
DIRECTION, and nothing else.  That makes the (a) question a geometry question:

    on the armed leg, is the between-poke walk aimed at the lane point,
    while the baseline leg's walk is aimed at the fountain?

WHY THIS IS NOT `pullcamp_domain.py --drag`
-------------------------------------------
It cannot be.  That tool's DRAG signature (pullcamp_domain.py:409-431) requires

    (displacement over [t+3, t+12]) . unit(fountain - bot) >= DRAG_U (300 u)

i.e. it certifies a drag by ITS FOUNTAIN-WARD COMPONENT -- the exact quantity
`pulldrag` is designed to stop producing.  The predicate was written when the
fountain-ward walk was the only walk there was, and it is correct for the
baseline leg forever.  On the armed leg it is an instrument that encodes the
null hypothesis: measured below, a perfectly executed lane-ward drag projects
only cos(theta) of itself onto the fountain axis, and on all four pull camps
that cosine is at most 0.048 -- the two rays are within 3 deg of perpendicular.
Nine seconds of lane-ward walking at a support's top speed projects 174 u onto
the fountain axis, against a 300 u threshold.  A tool asking "did it walk
home?" of a change whose whole content is "stop walking home" answers no by
construction.

    ==> The armed/baseline DRAG columns of pullcamp_domain (and every CONNECT
        number pullcamp_quality derives from them) are NOT comparable across
        the legs on a wave where `pulldrag` is armed.  That is a statement
        about the instrument, and it is asserted below rather than argued:
        `--selfcheck` fails if the shipped predicate can certify a synthetic
        walk aimed exactly at the lane target.

WHAT IS MEASURED HERE
---------------------
For every POKE frame pullcamp_domain already finds (its domain, its clauses,
its entity discipline -- imported, not re-implemented), the walk over the same
[t+3, t+12] lookahead is projected onto BOTH rays:

    proj_f = m . unit(fountain     - bot(t))     the shipped destination
    proj_l = m . unit(laneTarget(c) - bot(t))    the armed destination

and each frame is labelled by which ray wins.  Both legs are read in both
physical layers (GH #148 (i)); counts and shares are reported, never a median
of a small-valued integer alone (GH #148 (ii)).

THE LANE, AND ITS ERROR BAR
---------------------------
`GetLocationAlongLane` is an engine call and is a mock constant in fixtures, so
the lane polyline is reconstructed from the 22 tower coordinates every fixture
carries (tools/agent/pullcamp_lane_geometry.py -- imported, and its loader
asserts the towers are identical in all 61 building-carrying fixtures).

A reconstruction good enough for a DISTANCE can be unusable for a DIRECTION
(tools/agent/lane_drag_direction.py paid for that lesson: a chord across a
right-angle bend points ~45 deg away from both stretches it replaces).  This
corpus contains the worst case of exactly that: on the radiant hot camp the two
models' GAPS differ by 1 u (1,220 chord vs 1,221 corner-restored) while their
drag TARGETS sit 1,444 u apart, because the two minima are a unit apart and the
argmin flips between the corner chord and the ordinary tier2->tier1 stretch.
So every camp is resolved under BOTH models and a frame counts as lane-ward
only if it is lane-ward under BOTH; frames the models disagree about are
reported in their own column rather than assigned.  `--selfcheck` asserts that
at least one pull camp really is corner-sensitive, so that qualifier can never
go quietly vacuous.

Usage:
    pulldrag_walk.py <sweep_dir> [<sweep_dir> ...] [--selfcheck] [--top N]
    pulldrag_walk.py --selfcheck            # geometry-only, no corpus needed

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))

import pullcamp_lane_geometry as geo          # noqa: E402
from pullcamp_domain import (Game, canon, dist, load_sweep, derive_camps,  # noqa: E402
                             scan_game, RADIANT, DIRE,
                             DRAG_LO, DRAG_HI, DRAG_U, DRAG_OFF, R_FOLLOW)

CAND_ID = 'pulldrag'

# How far a camp's drag target may move between the two corner models before
# this tool refuses to score it.  A drag step is 500 u; 150 u is under a third
# of one step and well under the 700 u DRAG_OFF ring.
CORNER_TOL = 150.0

# The gate `pulldrag` rides through: the camp must be within this of the
# assigned lane (PULL_CAMP_LANE_GAP in jmz_func.lua).  Used here only to decide
# whether a camp's lane assignment is UNIQUE -- the bot's own
# GetAssignedLane() is not in the dump.
LANE_GAP = 1200.0

# The source's own arithmetic table (jmz_func.lua:8250-8256), used as the
# positive control for the reconstruction: camp -> gap to lane, in the same
# tower-polyline units the strategy desk published.
SOURCE_TABLE = [
    ((3994, -5137), 1220),
    ((-4007, 4947), 1084),
    ((200, -5200), 1069),
    ((-800, 5000), 1019),
]

STEP = 500.0        # the drag step in mode_roam_generic.lua:294

# The drag cadence: mode_roam_generic.lua:276 re-pokes every 3.0 s, so the walk
# between two pokes is what the 500 u step actually produces.  4 s is one
# cadence plus one 1 Hz sample of slack.
CADENCE_HI = 4.0

# Creep witness (selfcheck 6): how close a lane creep must pass to a candidate
# drag target to count as "the lane runs here", and how many games to pool.
CREEP_R = 600.0
CREEP_GAMES = 8
STILL_U = 50           # a first-second displacement under this is no motion
WARM_GAMES = 10        # games held resident to derive camps + run the witness
CELL = 300             # creep-occupancy grid, in units
CELL_MIN = 50          # a cell this busy over CREEP_GAMES games is "the lane"
CREEP_RATIO = 2.0      # the loser must be this many times farther than winner


def unit(dx, dy):
    n = math.hypot(dx, dy)
    return (0.0, 0.0) if n < 1e-9 else (dx / n, dy / n)


def closest_point_on_segment(v, a, b):
    """Mirror of ClosestPointOnSegment in jmz_func.lua:8235."""
    abx, aby = b[0] - a[0], b[1] - a[1]
    l2 = abx * abx + aby * aby
    if l2 <= 0:
        return a
    t = ((v[0] - a[0]) * abx + (v[1] - a[1]) * aby) / l2
    t = max(0.0, min(1.0, t))
    return (a[0] + abx * t, a[1] + aby * t)


def closest_point_on_path(v, path):
    best, bd = None, None
    for i in range(len(path) - 1):
        p = closest_point_on_segment(v, path[i], path[i + 1])
        d = math.hypot(v[0] - p[0], v[1] - p[1])
        if bd is None or d < bd:
            best, bd = p, d
    return best, bd


class Lanes:
    """The three lane polylines under both corner models."""

    def __init__(self):
        self.files, towers, self.ancients = geo.load_map()
        self.paths = {
            False: geo.lane_paths(towers, self.ancients, corners=False),
            True: geo.lane_paths(towers, self.ancients, corners=True),
        }

    def target(self, camp, corners=False):
        """(drag target, gap, lane, unique?) for a camp.

        The lane is the bot's GetAssignedLane(), which the dump does not carry.
        It is recoverable anyway WHEN ONLY ONE LANE is within LANE_GAP of the
        camp, because `pulllane` (armed on this wave) is exactly the clause
        that refuses any other camp.  When two lanes qualify the camp is
        reported ambiguous and scored under neither.
        """
        gaps = {ln: closest_point_on_path(camp, p)
                for ln, p in self.paths[corners].items()}
        order = sorted(gaps, key=lambda ln: gaps[ln][1])
        best = order[0]
        unique = gaps[order[1]][1] > LANE_GAP
        return gaps[best][0], gaps[best][1], best, unique

    def both_targets(self, camp):
        """(chord-model row, corner-model row, how far the target moved).

        DELIBERATELY NOT a single "best" target.  On the radiant hot camp the
        two models disagree by 1,444 u while their GAPS differ by 1 u: the
        chord across the map corner reads 1,220 and the real tier2->tier1
        stretch reads 1,221, so the argmin flips from one to the other and the
        drag ray swings ~60 deg.  The sister file's "the corner moves this camp
        by 1 u" is a statement about the DISTANCE and it is true; the
        DESTINATION is not reconstructible to the same tolerance, and a tool
        that picked one model would be reporting its own choice.

        Every reading below is therefore taken under BOTH models, and a frame
        only counts as lane-ward if it is lane-ward under both.
        """
        a = self.target(camp, corners=False)
        b = self.target(camp, corners=True)
        moved = dist(a[0][0], a[0][1], b[0][0], b[0][1])
        return a, b, moved


def creep_witness(lanes, games, camps):
    """Which corner model does the CORPUS put the lane at?  {camp: [n_chord, n_corner]}

    Only corner-sensitive camps are returned; for every other camp the two
    models name the same point and there is nothing to arbitrate.

    The witness is lane creeps, which walk the engine's own lane every wave and
    are in the dump.  The reading is a DISTANCE to the nearest busy cell of the
    creep-occupancy grid, not a count inside a disc: a count answers "do creeps
    ever pass near this point", which both models pass, while the distance
    answers "is this point ON the highway", which is the question.  This is what turns the corner question from "two
    reconstructions, pick one" into a reading -- and it does NOT ratify the
    prettier model: on the radiant hot camp the creeps sit around the chord's
    point, not the corner-restored one, because the real lane cuts that corner
    smoothly (the wave clashes at ~(5400,-5700), which is 200-400 u off the
    chord target and ~1.3 k off the corner-restored one).  The tower polyline's
    right-angle bend is a bound on the lane, not the lane.
    """
    live = [(c, lanes.both_targets(c)) for c in camps]
    live = [(c, t) for c, t in live if t[2] > CORNER_TOL]
    if not live:
        return {}
    # the creep highway, as occupancy of a CELL-sized grid over the whole map
    grid = defaultdict(int)
    for g0, _n, _s, _d, _side in games[:CREEP_GAMES]:
        for t, cs in g0.lane_creeps.items():
            if not (60.0 <= t <= 300.0):
                continue
            for c in cs:
                grid[(int(round(c['x'] / CELL)), int(round(c['y'] / CELL)))] += 1
    busy = [(k[0] * CELL, k[1] * CELL) for k, n in grid.items() if n >= CELL_MIN]
    out = {}
    for camp, (a2, b2, _m) in live:
        row = []
        for tgt in (a2[0], b2[0]):
            row.append(min((dist(tgt[0], tgt[1], bx, by) for bx, by in busy),
                           default=float('inf')))
        out[camp] = row
    return out


def creep_choice(lanes, games, camps):
    """{camp: 0|1} -- the model index the creeps chose, decisive cases only."""
    pick = {}
    for camp, (d_chord, d_corner) in creep_witness(lanes, games, camps).items():
        lo, hi = min(d_chord, d_corner), max(d_chord, d_corner)
        if lo <= CREEP_R and hi >= CREEP_RATIO * max(lo, 1.0):
            pick[camp] = 0 if d_chord < d_corner else 1
    return pick


# ---- selfcheck ------------------------------------------------------
def selfcheck(lanes, games=None):
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-46s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    chk('map loaded from fixtures', lanes.files >= 20,
        '%d building-carrying fixtures agree' % lanes.files)

    # 1. positive control: reproduce the source comment's own gap table.
    worst = 0.0
    for camp, want in SOURCE_TABLE:
        _, gap, lane, uniq = lanes.target(camp)
        worst = max(worst, abs(gap - want))
    chk('reproduces the source gap table (<= 30 u)', worst <= 30.0,
        'worst |delta| = %.0f u' % worst)

    # 2. every pull camp resolves to ONE lane (so GetAssignedLane(), which the
    #    dump does not carry, is recoverable through the armed `pulllane`
    #    clause), and the corner shift of its DESTINATION is on the record.
    shifts = []
    for camp, _ in SOURCE_TABLE:
        a, b, moved = lanes.both_targets(camp)
        shifts.append(moved)
        chk('camp %-14s one lane within %d u' % (str(camp), LANE_GAP),
            a[3] and b[3] and a[2] == b[2],
            'lane=%s gap=%.0f corner_shift=%.0f u' % (a[2], a[1], moved))
    # The dual-model path must actually be exercised: if a future geometry
    # change made every camp corner-insensitive, the "both models agree"
    # qualifier below would silently become vacuous.
    chk('dual-model path exercised (a camp IS corner-sensitive)',
        max(shifts) > CORNER_TOL, 'max shift = %.0f u' % max(shifts))

    # 3. THE INSTRUMENT CLAIM.  A walk aimed exactly at the lane target must
    #    fail the shipped DRAG predicate: its fountain-ward projection over a
    #    full 12 s of walking stays under DRAG_U.  This is the assertion that
    #    makes "pullcamp_domain's DRAG column is not comparable across the
    #    legs" a measurement rather than a story.
    fountain = {RADIANT: lanes.ancients[RADIANT], DIRE: lanes.ancients[DIRE]}
    worst_proj, worst_cos = -1e9, -1e9
    for camp, _ in SOURCE_TABLE:
        team = RADIANT if dist(camp[0], camp[1], *lanes.ancients[RADIANT]) < \
            dist(camp[0], camp[1], *lanes.ancients[DIRE]) else DIRE
        uf = unit(fountain[team][0] - camp[0], fountain[team][1] - camp[1])
        for row in lanes.both_targets(camp)[:2]:
            tgt = row[0]
            ul = unit(tgt[0] - camp[0], tgt[1] - camp[1])
            cos = ul[0] * uf[0] + ul[1] * uf[1]
            # the whole lookahead spent walking lane-ward at the ceiling speed
            # the corpus supports for a support hero
            span = min(DRAG_HI - DRAG_LO, 12.0) * 400.0
            worst_proj = max(worst_proj, cos * span)
            worst_cos = max(worst_cos, cos)
    chk('lane-ward walk cannot pass the shipped DRAG', worst_proj < DRAG_U,
        'max fountain-ward projection %.0f u < DRAG_U %.0f' % (worst_proj, DRAG_U))
    chk('cos(lane, fountain) small on every pull camp', worst_cos < 0.35,
        'max cos = %.3f' % worst_cos)

    # 4. mirror control: the SHIPPED step really is the lossy one.  A 500 u
    #    step toward home must close far less of the camp->lane gap than a
    #    500 u step toward the lane target.
    worst_home, least_lane = 1e9, 1e9
    for camp, _ in SOURCE_TABLE:
        team = RADIANT if dist(camp[0], camp[1], *lanes.ancients[RADIANT]) < \
            dist(camp[0], camp[1], *lanes.ancients[DIRE]) else DIRE
        uf = unit(fountain[team][0] - camp[0], fountain[team][1] - camp[1])
        for corners, row in zip((False, True), lanes.both_targets(camp)[:2]):
            tgt, gap, lane = row[0], row[1], row[2]
            ul = unit(tgt[0] - camp[0], tgt[1] - camp[1])
            home_pt = (camp[0] + uf[0] * STEP, camp[1] + uf[1] * STEP)
            lane_pt = (camp[0] + ul[0] * STEP, camp[1] + ul[1] * STEP)
            _, gh = closest_point_on_path(home_pt, lanes.paths[corners][lane])
            _, gl = closest_point_on_path(lane_pt, lanes.paths[corners][lane])
            worst_home = min(worst_home, gap - gh)
            least_lane = min(least_lane, gap - gl)
    chk('500 u home-ward closes <= 100 u of the gap', worst_home <= 100.0,
        'max closed = %.0f u' % worst_home)
    chk('500 u lane-ward closes >= 480 u of the gap', least_lane >= 480.0,
        'min closed = %.0f u' % least_lane)

    # 5. the ray labels are not degenerate: a walk aimed at the fountain must
    #    win the fountain ray, and a walk aimed at the lane must win the lane
    #    ray.  A trap this file could otherwise fall into is scoring both rays
    #    off the same vector and calling a tautology a result.
    camp = SOURCE_TABLE[0][0]
    tgt = lanes.both_targets(camp)[1][0]        # corner-restored model
    uf = unit(lanes.ancients[RADIANT][0] - camp[0],
              lanes.ancients[RADIANT][1] - camp[1])
    ul = unit(tgt[0] - camp[0], tgt[1] - camp[1])
    m_home = (uf[0] * 900, uf[1] * 900)
    m_lane = (ul[0] * 900, ul[1] * 900)
    chk('home-ward walk wins the home ray',
        m_home[0] * uf[0] + m_home[1] * uf[1] >
        m_home[0] * ul[0] + m_home[1] * ul[1])
    chk('lane-ward walk wins the lane ray',
        m_lane[0] * ul[0] + m_lane[1] * ul[1] >
        m_lane[0] * uf[0] + m_lane[1] * uf[1])

    if games:
        # 6. WHICH MODEL IS THE LANE -- decided by the corpus, not by taste.
        #    Lane creeps walk down the real lane every wave, and the dump
        #    carries them.  For each pull camp, count the lane-creep samples
        #    within CREEP_R of each model's drag target: the real lane point
        #    sits in a creep highway, the wrong one sits in empty jungle.
        #    This is the check that turns the corner question from "two
        #    models, pick one" into a measurement -- without it the radiant
        #    hot camp (1,444 u apart) would stay unassignable.
        near = creep_witness(lanes, games, [c for c, _ in SOURCE_TABLE])
        for camp, (d_chord, d_corner) in sorted(near.items()):
            lo, hi = min(d_chord, d_corner), max(d_chord, d_corner)
            chk('creep witness DECIDES at %s' % str(camp),
                lo <= CREEP_R and hi >= CREEP_RATIO * max(lo, 1.0),
                'chord %.0f u vs corner %.0f u from the nearest busy lane cell'
                ' -> %s' % (d_chord, d_corner,
                            'chord' if d_chord < d_corner else 'corner'))
        chk('creep witness had a camp to arbitrate', bool(near),
            '%d corner-sensitive pull camp(s)' % len(near))

        g = games[0][0]
        # the corpus fountain centroid and the ancient must agree on WHICH WAY
        # home is -- this tool reads the ancient in the geometry-only path and
        # the corpus centroid on real frames.
        worst_cos2 = 1.0
        for tm in (RADIANT, DIRE):
            if tm not in g.fountain or tm not in lanes.ancients:
                continue
            for camp, _ in SOURCE_TABLE:
                u1 = unit(g.fountain[tm][0] - camp[0], g.fountain[tm][1] - camp[1])
                u2 = unit(lanes.ancients[tm][0] - camp[0],
                          lanes.ancients[tm][1] - camp[1])
                worst_cos2 = min(worst_cos2, u1[0] * u2[0] + u1[1] * u2[1])
        # The geometry-only path reads "home" off the ANCIENT; every reading on
        # real frames reads it off the corpus fountain centroid, which is what
        # J.GetTeamFountain() returns.  They are ~1.5k apart and a camp is ~8k
        # away, so they may differ by a few degrees -- but not more, or the
        # geometry-only assertions above would be about a different ray than
        # the measurement.  0.98 = 11.5 deg; measured worst is 9.3 deg.
        chk('corpus fountain agrees with ancient on "home"', worst_cos2 > 0.98,
            'min cos = %.4f (%.1f deg)'
            % (worst_cos2, math.degrees(math.acos(min(1.0, worst_cos2)))))
    return ok


# ---- measurement ----------------------------------------------------
def walk_rows(g, rows, lanes, pick=None):
    """One row per POKE frame: the walk, projected on both destinations.

    `pick` maps a corner-sensitive camp to the model index the CREEP WITNESS
    chose (creep_choice).  Where it has a verdict, that model is the PRIMARY
    reading; where it does not, the primary falls back to the conservative
    min-of-both, which can only understate a lane-ward walk.
    """
    pick = pick or {}
    out = []
    for r in rows:
        if not r['poke'] or not r['clean']:
            continue
        hero = r['hero']
        team = g.teams.get(hero)
        if team not in g.fountain:
            continue
        camp = (r['camp_x'], r['camp_y'])
        a, b, moved_tgt = lanes.both_targets(camp)
        if not (a[3] and b[3] and a[2] == b[2]):
            out.append(dict(r, skipped='ambiguous_lane'))
            continue
        fr = g.frames[hero]
        t = r['t']
        s = fr.get(t)
        if s is None:
            continue
        fx, fy = g.fountain[team]
        uf = unit(fx - s['x'], fy - s['y'])
        ul = unit(a[0][0] - s['x'], a[0][1] - s['y'])       # chord model
        ul2 = unit(b[0][0] - s['x'], b[0][1] - s['y'])      # corner model
        # TWO windows, and they answer two different questions.
        #
        #  * the CADENCE window [t+1, t+CADENCE_HI] is the drag itself: the
        #    call site pokes once every 3.0 s and issues the 500 u step on the
        #    frames in between, so the step's direction is legible only while
        #    that cadence is still running.  Reading direction off the widest
        #    displacement in a 9 s window instead measures whatever the hero
        #    did LAST -- including abandoning the camp: the widest walks in the
        #    first run of this corpus are 2,000-3,000 u ending 2.0-3.3 k off
        #    the camp with ZERO neutrals still following, which is a hero
        #    leaving, not a drag.
        #  * the SHIPPED window [t+DRAG_LO, t+DRAG_HI] is pullcamp_domain's,
        #    reproduced verbatim so the "the shipped predicate cannot see this"
        #    column is that predicate and not a paraphrase of it.
        # STEP1: how far the hero moves in the FIRST second after the poke.
        # The drag step is issued on the frames between two pokes, so a poke
        # frame followed by no motion at all is a drag that produced nothing --
        # and that is invisible in any direction statistic, because a zero
        # vector has no direction.  Frame evidence that this is real and not a
        # dump artifact: in `152604_slot7` zuus t=279.5-284.5 the position is
        # byte-identical for six seconds while hp falls 1.00 -> 0.84 and the
        # neutral sample keeps changing, i.e. the stream is live and the hero
        # is standing in the camp taking hits.
        step1 = None
        best, ship = None, False
        for t2 in sorted(fr):
            if not (t + 1.0 <= t2 <= t + DRAG_HI):
                continue
            if not g.clean_window(hero, t, t2):
                continue
            s3 = fr[t2]
            if s3['hp_pct'] <= 0:
                continue
            mx, my = s3['x'] - s['x'], s3['y'] - s['y']
            pf = mx * uf[0] + my * uf[1]
            pl = mx * ul[0] + my * ul[1]
            pl2 = mx * ul2[0] + my * ul2[1]
            off = dist(s3['x'], s3['y'], camp[0], camp[1])
            nb = g.neutrals_at(t2) or []
            following = sum(1 for c in nb
                            if dist(s3['x'], s3['y'], c['x'], c['y']) <= R_FOLLOW)
            if (t + DRAG_LO <= t2 <= t + DRAG_HI and off >= DRAG_OFF
                    and pf >= DRAG_U and following > 0):
                ship = True
            if t2 <= t + 1.5 and (step1 is None or t2 < step1[0]):
                step1 = (t2, math.hypot(mx, my))
            if t2 > t + CADENCE_HI:
                continue
            sel = pick.get((round(camp[0]), round(camp[1])))
            pri = pl if sel == 0 else pl2 if sel == 1 else min(pl, pl2)
            cand = dict(t2=round(t2, 1), pf=round(pf), pl=round(pl),
                        pl2=round(pl2), pl_min=round(min(pl, pl2)),
                        pl_pri=round(pri), model=('chord' if sel == 0 else
                                                  'corner' if sel == 1 else
                                                  'both'),
                        moved=round(math.hypot(mx, my)), off=round(off),
                        following=following, tgt_shift=round(moved_tgt))
            if best is None or cand['moved'] > best['moved']:
                best = cand
        if best is None:
            out.append(dict(r, skipped='no_clean_lookahead'))
            continue
        best['shipped_drag'] = ship
        best['step1'] = round(step1[1]) if step1 else -1
        out.append(dict(r, lane=a[2], gap=round(a[1]),
                        tgt_x=round(a[0][0]), tgt_y=round(a[0][1]),
                        tgt2_x=round(b[0][0]), tgt2_y=round(b[0][1]),
                        **best))
    return out


def layer_of(side):
    return 'ab(cand=radiant)' if side == 'radiant' else 'ba(cand=dire)'


def summarise(rows, title):
    print('\n=== %s ===' % title)
    print('%-10s %7s %7s %9s %9s %9s %9s %8s %8s %8s'
          % ('leg', 'pokes', 'still', 'lane_pri', 'lane_win', 'home_win',
             'model_dep', 'mean_pl', 'mean_pf', 'shipped'))
    for leg in ('armed', 'baseline'):
        rs = [r for r in rows if r['leg'] == leg and 'pf' in r]
        if not rs:
            print('%-10s %7d' % (leg, 0))
            continue
        moved = [r for r in rs if 0 <= r.get('step1', -1) < STILL_U]
        # lane_win / home_win are decided under BOTH corner models; a frame the
        # models disagree about is counted in neither, and printed.
        lane_win = sum(1 for r in rs if min(r['pl'], r['pl2']) > r['pf'])
        home_win = sum(1 for r in rs if r['pf'] > max(r['pl'], r['pl2']))
        dep = len(rs) - lane_win - home_win
        pri = sum(1 for r in rs if r['pl_pri'] > r['pf'])
        ship = sum(1 for r in rs if r['shipped_drag'])
        print('%-10s %7d %7s %9s %9s %9s %9s %8.0f %8.0f %8s'
              % (leg, len(rs),
                 '%d (%.0f%%)' % (len(moved), 100.0 * len(moved) / len(rs)),
                 '%d (%.0f%%)' % (pri, 100.0 * pri / len(rs)),
                 '%d (%.0f%%)' % (lane_win, 100.0 * lane_win / len(rs)),
                 '%d (%.0f%%)' % (home_win, 100.0 * home_win / len(rs)),
                 '%d (%.0f%%)' % (dep, 100.0 * dep / len(rs)),
                 sum(r['pl_min'] for r in rs) / len(rs),
                 sum(r['pf'] for r in rs) / len(rs),
                 '%d (%.0f%%)' % (ship, 100.0 * ship / len(rs))))
    skipped = defaultdict(int)
    for r in rows:
        if 'skipped' in r:
            skipped[r['skipped']] += 1
    if skipped:
        print('skipped: %s' % dict(skipped))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='*')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--top', type=int, default=20)
    ap.add_argument('--out', default='/tmp/pulldrag_rows.jsonl')
    a = ap.parse_args()

    lanes = Lanes()
    if not a.sweeps:
        if not a.selfcheck:
            sys.exit('usage: pulldrag_walk.py <sweep_dir> ... | --selfcheck')
        print('--- selfcheck (geometry only) ---')
        sys.exit(0 if selfcheck(lanes) else 2)

    # Games are loaded ONE AT A TIME and dropped.  A 25-minute cap=25 timeline
    # is several times the size of the cap=10 ones every earlier tool in this
    # directory was written against, and holding 130 of them at once is an
    # OOM kill (measured: exit 137 on this container at 130 games).  Only the
    # small warm-up subset needed to derive the camps and run the creep
    # witness is ever resident together.
    entries, cands = [], set()
    for d in a.sweeps:
        for m in load_sweep(d):
            cands.add(m['cand'])
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            entries.append((tl, an, m['game'], m['seed'], d, m['side']))
    if len(cands) != 1:
        sys.exit('[fatal] mixed cand strings in this corpus: %s' % sorted(cands))
    cand = cands.pop()
    if CAND_ID not in cand.split(','):
        sys.exit('[fatal] `%s` is NOT in this wave\'s cand string' % CAND_ID)
    print('corpus: %d games from %d sweep dir(s); `%s` armed'
          % (len(entries), len(a.sweeps), CAND_ID))

    warm = [(Game(tl, an, side), name, seed, d, side)
            for tl, an, name, seed, d, side in entries[:WARM_GAMES]]

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck(lanes, warm):
            sys.exit(2)

    camps = derive_camps([(g, n, s2, d) for g, n, s2, d, _ in warm])
    print('camps derived from the first neutral spawn of %d games: %d'
          % (len(warm), len(camps)))
    ckeys = [(round(c[0]), round(c[1])) for c in camps]
    pick = creep_choice(lanes, warm, ckeys)
    wit = creep_witness(lanes, warm, ckeys)
    if wit:
        print('\ncreep witness (the lane, as the corpus walks it):')
        for camp, (dc, dk) in sorted(wit.items()):
            print('  camp %-16s chord %5.0f u   corner %5.0f u   -> %s'
                  % (str(camp), dc, dk,
                     ('chord' if pick[camp] == 0 else 'corner')
                     if camp in pick else 'UNDECIDED (conservative min used)'))
    print('\ncamp -> drag target:')
    for cx, cy, n in sorted(camps, key=lambda c: -c[2]):
        aa, bb, moved = lanes.both_targets((round(cx), round(cy)))
        print('  (%6d,%6d) seen=%-5d lane=%-4s gap=%6.0f unique=%-5s '
              'corner_shift=%5.0f %s'
              % (cx, cy, n, aa[2], aa[1], aa[3], moved,
                 'scored' if (aa[3] and bb[3] and aa[2] == bb[2])
                 else 'AMBIGUOUS LANE'))
    del warm

    allrows = []
    for tl, an, name, seed, d, side in entries:
        g = Game(tl, an, side)
        rs = scan_game(g, name, seed, camps, sweep=d)
        for r in walk_rows(g, rs, lanes, pick):
            r['side'] = side
            r['layer'] = layer_of(side)
            allrows.append(r)
        del g

    with open(a.out, 'w') as fh:
        for r in allrows:
            fh.write(json.dumps(r) + '\n')

    summarise(allrows, 'POOLED (both layers -- for scale only, GH #148 (i))')
    for lay in sorted({r['layer'] for r in allrows}):
        summarise([r for r in allrows if r['layer'] == lay], lay)

    print('\n--- armed-leg poke frames, biggest walks first ---')
    cand_rows = [r for r in allrows if r['leg'] == 'armed' and 'pf' in r]
    cand_rows.sort(key=lambda r: -r['moved'])
    for r in cand_rows[:a.top]:
        print('%-26s %-16s t=%-6.1f camp=(%6d,%6d) lane=%-4s moved=%-5d '
              'pl=%-6d pf=%-6d foll=%-2d off=%-5d shipped=%s'
              % (os.path.basename(r['sweep']) + '/' + r['game'],
                 canon(r['hero']), r['t'], r['camp_x'], r['camp_y'], r['lane'],
                 r['moved'], r['pl'], r['pf'], r['following'], r['off'],
                 r['shipped_drag']))
    print('\nrows written to %s' % a.out)


if __name__ == '__main__':
    main()

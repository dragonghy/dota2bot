#!/usr/bin/env python3
"""Execution check ((a)-evidence) for the `pullcamp` soak candidate.

`J.ShouldPullNeutralCamp` (jmz_func.lua:7459) + `J.IsLanePullSafe`
(jmz_func.lua:6219) + the roam call site (mode_roam_generic.lua:99, action at
:199) implement the turbo 拉野: during the laning window a SUPPORT whose lane
equilibrium is bad walks to a friendly neutral camp at the :05-:20 / :35-:50
travel-lead marks, pokes the camp once every 3 s and walks fountain-ward in
between, dragging the neutrals into the lane path so they eat our own wave.

This answers WORKING / BUGGY / SILENT from the 1 Hz replay timelines of a
mirrored-draft wave: the armed leg is the manifest's `side`, the baseline leg
is the other team of the SAME game running stock code -- the free control.

DOMAIN -- every clause is transcribed literally from the Lua, with the
observability of each one stated, because the two directions do NOT cancel:
  observable   pos in {4,5}                    not J.IsCore(bot) -- from
                                               seed_draft.positions_for_game,
                                               NEVER team_slot%5+1 (GH #57/#116:
                                               that proxy is 47.3% accurate)
               60 <= t <= 360                  DotaTime() window
               t%60 in [5,20] or [35,50]       the pull-window marks
               hp_pct >= 0.50                  IsLanePullSafe
               no enemy hero damaged me <=2 s  IsLanePullSafe (combat log)
               no enemy hero within 1800       IsLanePullSafe (see BIAS below)
               friendly camp within 1500       GetNeutralSpawners() (see CAMPS)
  NOT observable, so LEFT OUT -- the domain is a SUPERSET on these:
               lane front past midpoint + 400  GetLaneFrontLocation not dumped
               bot:GetAssignedLane() ~= nil
  BIAS THE OTHER WAY (honest, and it does not cancel the superset above):
               the engine's GetNearbyHeroes(1800, true) returns only VISIBLE
               enemies; the replay carries ground truth, so an unseen enemy
               inside 1800 closes my domain on a frame the engine would have
               let through. On this clause the domain is a SUBSET.  Net: the
               frame counts are neither a clean upper nor a clean lower bound,
               and a zero here is therefore reported as "no surface", never as
               a certified SILENT.  Both legs pay the same bias.

CAMPS: `GetNeutralSpawners()` is not in the dump, so camp locations are derived
from the corpus itself -- team-4 (neutral) creep positions in t in [60, 66],
i.e. the first spawn, before any pull can have moved them -- pooled over every
game and clustered.  Camp team is assigned by which ancient is closer (a proxy
for the engine's camp.team); `--any-camp` reports the assignment-free column so
no reading is hostage to it.  The selfcheck requires the camp set to reproduce
across games, which is the positive control this geometry needs.

SIGNATURE (the action, as it looks at 1 Hz):
  APPROACH  -- displacement over [t, t+3] projected on the unit vector toward
               the nearest friendly camp >= 200 u AND the camp gets closer.
  AT_CAMP   -- within 400 u of a friendly camp centroid.
  APPROACHED-- within the preceding 12 s the hero's distance to THAT camp fell
               by >= 600 u: the walk-in leg.  MEASURED AND KEPT, BUT IT DOES
               NOT SEPARATE stock jungling-on-the-way-home, which was the
               reason it was added -- see the frame note in the code.  Reported
               so the next reader does not re-invent it.
  POKE      -- this hero deals damage to a NON-hero unit while AT_CAMP.
  DRAG      -- after a poke, the hero is >= 700 u off the camp, moving
               fountain-ward, with >= 1 neutral creep still within 700 u:
               the neutrals actually followed.  This is the whole point of a
               pull and the only signature that distinguishes it from a
               support idly hitting a camp.

Traps honoured here (iterations/streams/replay-check.md):
  * entity identity from `idx`, main entity = EARLIEST appearing idx;
  * `by_t` idx-locked too, so an illusion cannot inflate the 1800 ring;
  * combat-log names canonicalised before comparison;
  * "<= t 的最后一帧" with an explicit staleness cap for the 3 s creep stream;
  * TP channels (+1.5 s landing tail) and death windows excluded from every
    displacement, and a physical displacement cap guards what survives;
  * #102 completeness sentinel on every sweep dir;
  * armed-string guard: refuses to score a gate that was never armed.

Usage:
    pullcamp_domain.py <sweep_dir> [<sweep_dir> ...] [--selfcheck] [--top N]

Read-only; touches no billable AWS resource.
"""
import argparse
import json
import math
import os
import sys
from collections import defaultdict

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))), 'soak'))
import seed_draft  # noqa: E402  -- canonical hero->position (GH #57)

CAND_ID = 'pullcamp'

T_LO, T_HI = 60.0, 360.0     # DotaTime() < 60 or > 6*60 -> nil
HP_MIN = 0.50                # J.GetHP(bot) < 0.5 -> false (IsLanePullSafe)
R_SAFE = 1800.0              # IsLanePullSafe visible-enemy ring
DMG_BACK = 2.0               # WasRecentlyDamagedByAnyHero(2.0)
R_CAMP_REACH = 1500.0        # nBestDist starts at 1500
R_AT_CAMP = 400.0            # "standing at the camp"
R_FOLLOW = 700.0             # a neutral still on our heels
DRAG_OFF = 700.0             # this far off the camp box == we left with them
APPROACH_S = 3.0
APPROACH_U = 200.0
APPROACHED_BACK = 12.0       # how far back to look for the walk-in leg
APPROACHED_U = 600.0         # distance to the poked camp must fall by this much
DRAG_LO, DRAG_HI = 3.0, 12.0  # poke -> drag lookahead
DRAG_U = 300.0
CONNECT_S = 20.0             # how long a dragged camp gets to reach a wave
R_CONNECT = 600.0            # neutral <-> lane creep contact distance
CREEP_STALE = 1.6            # neutrals are dumped every 3.0 s
TP_TAIL = 1.5                # the landing lands one sample after the channel
EPISODE_GAP = 4.0
CAMP_CLUSTER = 900.0         # camp boxes are ~1200 u apart at the closest
CAMP_T_LO, CAMP_T_HI = 60.0, 66.0   # first neutral spawn, pre-pull
WALK_CAP = 550.0             # u/s, every haste in the game

RADIANT, DIRE = 2, 3


def canon(n):
    return n.replace('npc_dota_hero_', '').replace('_', '').lower() if n else n


def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


class Game:
    def __init__(self, tl_path, analysis_path, armed_side):
        d = json.load(open(tl_path))
        self.teams = d['game']['teams']
        self.armed_team = RADIANT if armed_side == 'radiant' else DIRE

        events = sorted(d['events'], key=lambda e: e['t'])
        self.raw_events = events
        self.t_end = max((e['t'] for e in events), default=float('inf'))

        # --- identity: main entity = earliest-appearing idx per hero name
        first_t = {}
        for s in d['snapshots']:
            k = (s['hero'], s['idx'])
            if k not in first_t or s['t'] < first_t[k]:
                first_t[k] = s['t']
        self.main_idx = {}
        for (hero, idx), t0 in first_t.items():
            cur = self.main_idx.get(hero)
            if cur is None or t0 < first_t[(hero, cur)]:
                self.main_idx[hero] = idx
        self.copies = sum(1 for (h, i) in first_t if self.main_idx[h] != i)

        self.frames = defaultdict(dict)      # hero -> {t: snap}
        self.by_t = defaultdict(list)        # t -> [snap], main entities only
        for s in d['snapshots']:
            if s['t'] > self.t_end or s['idx'] != self.main_idx.get(s['hero']):
                continue
            self.frames[s['hero']][s['t']] = s
            self.by_t[s['t']].append(s)

        # --- creeps bucketed by sample time; neutrals kept apart
        self.creep_t = sorted({c['t'] for c in d.get('creeps', [])})
        self.neutrals = defaultdict(list)
        self.lane_creeps = defaultdict(list)
        for c in d.get('creeps', []):
            if c['team'] == 4:
                self.neutrals[c['t']].append(c)
            elif c['team'] in (RADIANT, DIRE):
                self.lane_creeps[c['t']].append(c)

        # --- combat log: hero->hero damage, hero->non-hero damage, deaths, TP
        c2h = {canon(h): h for h in self.teams}
        self.dmg_in = defaultdict(list)      # victim -> [(t, attacker)]
        self.dmg_creep = defaultdict(list)   # attacker -> [t] (non-hero target)
        self.deaths = defaultdict(list)
        open_tp, self.tp_spans = {}, defaultdict(list)
        for e in events:
            if e['type'] == 'DAMAGE' and e.get('actor_hero'):
                a = c2h.get(canon(e.get('actor')), e.get('actor'))
                if e.get('target_hero'):
                    b = c2h.get(canon(e.get('target')), e.get('target'))
                    self.dmg_in[b].append((e['t'], a))
                else:
                    self.dmg_creep[a].append(e['t'])
            elif e['type'] == 'DEATH' and e.get('target_hero'):
                self.deaths[c2h.get(canon(e.get('target')),
                                    e.get('target'))].append(e['t'])
            if e.get('inflictor') == 'modifier_teleporting':
                h = c2h.get(canon(e.get('target')), e.get('target'))
                if e['type'] == 'MODIFIER_ADD':
                    open_tp[h] = e['t']
                elif e['type'] == 'MODIFIER_REMOVE' and h in open_tp:
                    self.tp_spans[h].append((open_tp.pop(h), e['t']))
        for h, t in open_tp.items():
            self.tp_spans[h].append((t, t + 4.0))

        # --- fountains: per-team centroid of that team's earliest 3 s
        acc = defaultdict(lambda: [0.0, 0.0, 0])
        team_t0 = {}
        for t in sorted(self.by_t):
            for s in self.by_t[t]:
                team_t0.setdefault(s['team'], t)
        for t in sorted(self.by_t):
            for s in self.by_t[t]:
                if t > team_t0[s['team']] + 3:
                    continue
                a = acc[s['team']]
                a[0] += s['x']; a[1] += s['y']; a[2] += 1
        self.fountain = {tm: (a[0] / a[2], a[1] / a[2])
                         for tm, a in acc.items() if a[2]}
        self.ancient = {}
        for b in d.get('buildings', []):
            if b['name'] == 'ancient':
                self.ancient.setdefault(b['team'], (b['x'], b['y']))

        # --- positions from the SOAK SEED's draft, never from the pick slot.
        # GH #57 / GH #116: `X.ShufflePickOrder` permutes the slots after the
        # draft, so `team_slot % 5 + 1` agreed with the drafted position on
        # only 47.3% of rows across 291 real mirror games.  It is forbidden
        # under tools/ and `tests/test_hero_position.py` check [6] fails the
        # build on it.  This matters more here than almost anywhere else: the
        # whole domain is gated on `pos in {4,5}` (`not J.IsCore(bot)`), so a
        # wrong label does not blur the reading, it selects the wrong heroes.
        # `positions_for_game` returns None (not a guess) for a game with no
        # seed stamp (warm-ups), which propagates to `pos = None`; the scan
        # reads `not pos or pos < 4` and DROPS such a hero rather than
        # mislabelling it in -- the under-claim-never-over-claim direction this
        # tool's DOMAIN section commits to.
        self.pos = {}
        if analysis_path and os.path.exists(analysis_path):
            self.pos = seed_draft.positions_for_game(
                json.load(open(analysis_path))) or {}

    # ---- predicates -------------------------------------------------
    def recent_hero_dmg(self, hero, t, back):
        """bot:WasRecentlyDamagedByAnyHero(back), rebuilt from the combat log.

        Understated, never overstated: a hero-owned summon also sets the engine
        flag and is not counted here, so this clause can only ADMIT frames the
        engine would have vetoed.
        """
        return any(t - back <= et <= t for et, _ in self.dmg_in.get(hero, ()))

    def clean_window(self, hero, t0, t1):
        """No TP channel (+ landing tail) and no death overlapping [t0, t1]."""
        for a, b in self.tp_spans.get(hero, ()):
            if a <= t1 and b + TP_TAIL >= t0:
                return False
        return not any(t0 - 1.0 <= dt <= t1 for dt in self.deaths.get(hero, ()))

    def creep_sample(self, t):
        """<= t 的最后一帧, with an explicit staleness cap (never a fixed offset)."""
        best = None
        for ct in self.creep_t:
            if ct <= t:
                best = ct
            else:
                break
        if best is None or t - best > CREEP_STALE:
            return None
        return best

    def neutrals_at(self, t):
        ct = self.creep_sample(t)
        return None if ct is None else self.neutrals.get(ct, [])

    def lane_creeps_at(self, t):
        ct = self.creep_sample(t)
        return None if ct is None else self.lane_creeps.get(ct, [])

    def leg(self, hero):
        return 'armed' if self.teams.get(hero) == self.armed_team else 'baseline'


# ---- camps ----------------------------------------------------------
def derive_camps(games):
    """Camp centroids from the FIRST neutral spawn, pooled over the corpus.

    t in [60, 66] is after the 1:00 spawn and before any pull could have walked
    a camp anywhere, so these are spawner locations, not pulled positions.
    """
    pts = []
    for entry in games:
        g = entry[0]
        for t in g.creep_t:
            if CAMP_T_LO <= t <= CAMP_T_HI:
                pts.extend((c['x'], c['y']) for c in g.neutrals.get(t, []))
    clusters = []
    for x, y in pts:
        for cl in clusters:
            if dist(x, y, cl[0], cl[1]) < CAMP_CLUSTER:
                n = cl[2]
                cl[0] = (cl[0] * n + x) / (n + 1)
                cl[1] = (cl[1] * n + y) / (n + 1)
                cl[2] = n + 1
                break
        else:
            clusters.append([x, y, 1])
    # a real camp is seen by many games; a stray pulled/roaming neutral is not
    keep = [c for c in clusters if c[2] >= max(4, len(games))]
    return [(c[0], c[1], c[2]) for c in keep]


def camp_team(cx, cy, anc):
    """Proxy for the engine's camp.team: whose ancient is closer."""
    if RADIANT not in anc or DIRE not in anc:
        return None
    return RADIANT if dist(cx, cy, *anc[RADIANT]) < dist(cx, cy, *anc[DIRE]) else DIRE


# ---- scan -----------------------------------------------------------
def scan_game(g, name, seed, camps, sweep=''):
    out = []
    ct = {}
    for cx, cy, _ in camps:
        ct[(cx, cy)] = camp_team(cx, cy, g.ancient)

    for hero, fr in g.frames.items():
        team = g.teams.get(hero)
        pos = g.pos.get(hero)
        if not team or not pos or pos < 4:
            continue                      # not J.IsCore(bot) -> support only
        fx, fy = g.fountain.get(team, (0.0, 0.0))
        mine = [(cx, cy) for (cx, cy) in ct if ct[(cx, cy)] == team]
        for t in sorted(fr):
            if not (T_LO <= t <= T_HI):
                continue
            sec = t % 60.0
            if not ((5 <= sec <= 20) or (35 <= sec <= 50)):
                continue
            s = fr[t]
            if s['hp_pct'] < HP_MIN:
                continue
            if g.recent_hero_dmg(hero, t, DMG_BACK):
                continue
            enemies = [o for o in g.by_t.get(t, [])
                       if o['team'] != team and o['hp_pct'] > 0]
            if any(dist(s['x'], s['y'], o['x'], o['y']) <= R_SAFE for o in enemies):
                continue
            # nearest camp, mine and any
            def nearest(cs):
                best, bd = None, 1e18
                for cx, cy in cs:
                    dd = dist(s['x'], s['y'], cx, cy)
                    if dd < bd:
                        best, bd = (cx, cy), dd
                return best, bd
            cmine, dmine = nearest(mine)
            cany, dany = nearest(list(ct))
            if dmine > R_CAMP_REACH and dany > R_CAMP_REACH:
                continue

            camp = cmine if dmine <= R_CAMP_REACH else cany
            cd = dmine if dmine <= R_CAMP_REACH else dany
            strict = dmine <= R_CAMP_REACH          # friendly camp, as in Lua

            # --- signature
            clean = g.clean_window(hero, t, t + APPROACH_S)
            s2 = fr.get(t + APPROACH_S)
            appr = 0.0
            if s2 and s2['hp_pct'] > 0 and clean:
                mx, my = s2['x'] - s['x'], s2['y'] - s['y']
                dx, dy = camp[0] - s['x'], camp[1] - s['y']
                n = max(math.hypot(dx, dy), 1.0)
                appr = (mx * dx + my * dy) / n
            at_camp = cd <= R_AT_CAMP
            poke = at_camp and any(t <= et <= t + APPROACH_S
                                   for et in g.dmg_creep.get(hero, ()))
            # APPROACHED -- the walk-in leg.  ADDED as a hypothesis and KEPT
            # AS A NEGATIVE RESULT: it was meant to separate a pull from stock
            # JUNGLING ON THE WAY HOME, which is what the baseline leg's few
            # hits actually are -- frame evidence `20260822_122653_slot8`
            # venomancer t=276.4-295.4 walks fountain-ward the WHOLE time
            # (d(fountain) 8323 -> 6244 monotone), poison-stinging three camps
            # as it passes.  It DOES NOT separate them: that hero also closes
            # on the wolf camp (d(camp) 932 -> 53 over t=276.4-281.4), so it
            # passes this test too.  Measured on 139 games: baseline poke
            # episodes 4 -> 4, baseline drag episodes 1 -> 1; armed 59 -> 57
            # and 39 -> 38.  The baseline background is REAL, not an artifact
            # this clause can remove.  Left in so the next reader does not
            # re-derive the same failed idea.
            approached = False
            for tb in sorted(fr):
                if not (t - APPROACHED_BACK <= tb < t):
                    continue
                sb = fr[tb]
                if sb['hp_pct'] <= 0 or not g.clean_window(hero, tb, t):
                    continue
                if dist(sb['x'], sb['y'], camp[0], camp[1]) - cd >= APPROACHED_U:
                    approached = True
                    break
            drag = connect_own = connect_enemy = False
            if poke:
                for t2 in sorted(fr):
                    if not (t + DRAG_LO <= t2 <= t + DRAG_HI):
                        continue
                    if not g.clean_window(hero, t, t2):
                        continue
                    s3 = fr[t2]
                    if s3['hp_pct'] <= 0:
                        continue
                    if dist(s3['x'], s3['y'], camp[0], camp[1]) < DRAG_OFF:
                        continue
                    mx, my = s3['x'] - s['x'], s3['y'] - s['y']
                    dx, dy = fx - s['x'], fy - s['y']
                    n = max(math.hypot(dx, dy), 1.0)
                    if (mx * dx + my * dy) / n < DRAG_U:
                        continue
                    nb = g.neutrals_at(t2)
                    following = [c for c in (nb or [])
                                 if dist(s3['x'], s3['y'], c['x'], c['y']) <= R_FOLLOW]
                    if following:
                        drag = True
                        # Did the pull CONNECT? A pull only resets the lane if
                        # the dragged neutrals reach a wave. Reported per side:
                        # own-wave contact is the textbook safelane reset (our
                        # creeps stop to fight neutrals); enemy-wave contact is
                        # the other thing that can happen once they are in the
                        # lane path. Neutral creeps carry no idx in the dump, so
                        # this is a proximity reading of the CAMP's neutrals,
                        # not a tracked identity -- stated, not hidden.
                        for t3 in [x for x in g.creep_t if t2 <= x <= t2 + CONNECT_S]:
                            nb3 = g.neutrals.get(t3, [])
                            near = [c for c in nb3
                                    if any(dist(c['x'], c['y'], f['x'], f['y'])
                                           <= R_FOLLOW for f in following)]
                            lc = g.lane_creeps.get(t3, [])
                            for c in near:
                                for w in lc:
                                    if dist(c['x'], c['y'], w['x'], w['y']) <= R_CONNECT:
                                        if w['team'] == team:
                                            connect_own = True
                                        else:
                                            connect_enemy = True
                        break
            out.append(dict(sweep=sweep, game=name, seed=seed, hero=hero, pos=pos,
                            leg=g.leg(hero), t=round(t, 1),
                            hp=round(s['hp_pct'], 3), x=s['x'], y=s['y'],
                            camp_d=round(cd), strict=strict, clean=clean,
                            approach=round(appr), at_camp=at_camp,
                            approached=approached, poke=poke, drag=drag,
                            connect_own=connect_own, connect_enemy=connect_enemy))
    return out


def episodes(rows):
    by = defaultdict(list)
    for r in rows:
        # (sweep, game) -- NOT game alone.  `.dem` basenames collide across
        # runs of the same wave (measured on this corpus: 283 manifest lines,
        # 282 unique names -- `20260822_122615_slot1` is both run_121209/s888
        # and run_121214/s895).  Keying on the basename merges two different
        # games' frames for the same hero into one episode chain.
        by[(r.get('sweep', ''), r['game'], r['hero'])].append(r)
    eps = []
    for rs in by.values():
        rs.sort(key=lambda r: r['t'])
        cur = [rs[0]]
        for r in rs[1:]:
            if r['t'] - cur[-1]['t'] <= EPISODE_GAP:
                cur.append(r)
            else:
                eps.append(cur); cur = [r]
        eps.append(cur)
    return eps


def load_sweep(d):
    """Charter #102 completeness sentinel: summary exists AND counts match."""
    mpath = os.path.join(d, 'games_manifest.jsonl')
    if not os.path.exists(mpath):
        sys.exit('[fatal] %s: no games_manifest.jsonl' % d)
    rows = [json.loads(l) for l in open(mpath) if l.strip()]
    spath = os.path.join(d, 'sweep_summary.md')
    if not os.path.exists(spath):
        sys.exit('[fatal] %s: no sweep_summary.md -- PARTIAL sweep (%d games)'
                 % (d, len(rows)))
    claimed = None
    for line in open(spath):
        if line.startswith('games swept:'):
            claimed = int(line.split(':', 1)[1].split('(')[0].strip())
            break
    if claimed is None or claimed != len(rows):
        sys.exit('[fatal] %s: summary says %s, manifest holds %d -- re-sweep'
                 % (d, claimed, len(rows)))
    return rows


def selfcheck(games, camps):
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-36s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    g = games[0][0]
    fs, anc = g.fountain, g.ancient
    d = dist(*fs[RADIANT], *fs[DIRE]) if len(fs) == 2 else -1
    chk('fountains ~19k apart', 17000 < d < 21000, 'd=%d' % d)
    side_ok = all(dist(*fs[tm], *anc[tm]) < 2500 and dist(*fs[tm], *anc[tm]) <
                  dist(*fs[tm], *anc[RADIANT if tm == DIRE else DIRE])
                  for tm in (RADIANT, DIRE) if tm in fs and tm in anc)
    chk('centroid behind own ancient', side_ok,
        'r=%d d=%d' % (dist(*fs[RADIANT], *anc[RADIANT]),
                       dist(*fs[DIRE], *anc[DIRE])))
    n_r = sum(1 for h, t in g.teams.items() if t == RADIANT)
    chk('roster 5v5', n_r == 5 and len(g.teams) == 10, '%d radiant' % n_r)
    legs = defaultdict(int)
    for entry in games:
        gg = entry[0]
        for h in gg.teams:
            legs[gg.leg(h)] += 1
    chk('legs balanced', legs['armed'] == legs['baseline'], dict(legs))
    chk('idx lock ran', True,
        'non-main entities across corpus: %d' % sum(x[0].copies for x in games))
    chk('neutral sample step 3 s',
        len(g.creep_t) > 1 and abs((g.creep_t[1] - g.creep_t[0]) - 3.0) < 1e-6,
        'step=%s' % (g.creep_t[1] - g.creep_t[0] if len(g.creep_t) > 1 else '?'))
    # camps: the count prior is MEASURED, not guessed (charter 2026-08-22T13:15Z
    # -- a made-up geometric prior fails healthy data and reads as a data bug).
    # This corpus yields 28 camps, 14 a side, minimum separation 1303 u.  The
    # rotational-symmetry check a 16k map used to allow is NOT usable: the
    # current map's mirror mismatch measures up to 987 u.  The load-bearing
    # positive controls are instead (i) separation > the cluster radius, which
    # proves no camp was split in two, and (ii) reproduction in another game.
    tm = [camp_team(cx, cy, anc) for cx, cy, _ in camps]
    chk('camps derived 24..32', 24 <= len(camps) <= 32, 'n=%d' % len(camps))
    if len(camps) > 1:
        pts = [(c[0], c[1]) for c in camps]
        mind = min(dist(*a, *b) for i, a in enumerate(pts) for b in pts[i + 1:])
        chk('camps separated > cluster radius', mind > CAMP_CLUSTER,
            'min=%d u (radius %d)' % (mind, CAMP_CLUSTER))
    chk('both halves populated',
        tm.count(RADIANT) >= 5 and tm.count(DIRE) >= 5,
        'radiant=%d dire=%d' % (tm.count(RADIANT), tm.count(DIRE)))
    # per-game reproduction: every camp must be matched within 300 u by the
    # first spawn of a DIFFERENT game
    if len(games) > 1:
        other = []
        for t in games[-1][0].creep_t:
            if CAMP_T_LO <= t <= CAMP_T_HI:
                other.extend((c['x'], c['y'])
                             for c in games[-1][0].neutrals.get(t, []))
        worst = max((min((dist(cx, cy, ox, oy) for ox, oy in other),
                         default=1e9) for cx, cy, _ in camps), default=1e9)
        chk('camps reproduce in another game', worst < 300, 'worst=%d u' % worst)
    # pull windows cover 32 of every 60 s -- a cheap check that `t` is DotaTime
    tot = sum(1 for t in g.frames[list(g.frames)[0]] if T_LO <= t <= T_HI)
    inw = sum(1 for t in g.frames[list(g.frames)[0]]
              if T_LO <= t <= T_HI and ((5 <= t % 60 <= 20) or (35 <= t % 60 <= 50)))
    frac = inw / tot if tot else 0
    chk('pull-window duty ~53%', 0.45 < frac < 0.62, '%.3f' % frac)
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--top', type=int, default=15)
    ap.add_argument('--any-camp', action='store_true',
                    help='report the camp-team-assignment-free column too')
    ap.add_argument('--out', default='/tmp/pullcamp_rows.jsonl')
    a = ap.parse_args()

    games, cands = [], set()
    for d in a.sweeps:
        for m in load_sweep(d):
            cands.add(m['cand'])
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            games.append((Game(tl, an, m['side']), m['game'], m['seed'], d))
    dupes = len(games) - len({(x[1]) for x in games})
    if dupes:
        print('note: %d basename collision(s) across runs -- every row and '
              'episode is keyed on (sweep, game), never the basename alone'
              % dupes)
    print('corpus: %d games from %d sweep dir(s)' % (len(games), len(a.sweeps)))

    # armed-string guard: never score a gate that was never armed
    if len(cands) != 1:
        sys.exit('[fatal] mixed cand strings in this corpus: %s' % sorted(cands))
    cand = cands.pop()
    if CAND_ID not in cand.split(','):
        sys.exit('[fatal] `%s` is NOT in this wave\'s cand string: %s'
                 % (CAND_ID, cand))
    print('cand string (uniform, %s armed): %s' % (CAND_ID, cand))

    camps = derive_camps(games)
    print('camps derived from the first neutral spawn (t in [%g,%g]): %d'
          % (CAMP_T_LO, CAMP_T_HI, len(camps)))

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck(games, camps):
            sys.exit(2)

    rows = []
    for g, name, seed, d in games:
        rows.extend(scan_game(g, name, seed, camps, sweep=d))

    # physical displacement guard: nothing that survived the TP/death exclusion
    # may exceed what a hero can walk in APPROACH_S seconds.
    worst = max((r for r in rows if r['clean']),
                key=lambda r: abs(r['approach']), default=None)
    n_dirty = sum(1 for r in rows if not r['clean'])
    print('approach guard: max |clean approach| = %s u (cap %d); %d/%d domain '
          'frames excluded as TP-channel/death windows'
          % (abs(worst['approach']) if worst else 'n/a',
             int(WALK_CAP * APPROACH_S), n_dirty, len(rows)))
    if worst and abs(worst['approach']) > WALK_CAP * APPROACH_S:
        print('[fatal] approach guard tripped: %s' % worst)
        sys.exit(2)

    legs = defaultdict(lambda: defaultdict(int))
    for r in rows:
        for key, on in (('frames', True), ('at_camp', r['at_camp']),
                        ('approach', r['approach'] >= APPROACH_U),
                        ('poke', r['poke']), ('drag', r['drag']),
                        ('pull_full', r['approached'] and r['drag']),
                        ('connect_own', r['connect_own']),
                        ('connect_enemy', r['connect_enemy'])):
            if on:
                legs[r['leg']][key] += 1
        if r['strict']:
            L = legs[r['leg']]
            L['strict_frames'] += 1
            L['strict_at_camp'] += 1 if r['at_camp'] else 0
            L['strict_approach'] += 1 if r['approach'] >= APPROACH_U else 0
            L['strict_poke'] += 1 if r['poke'] else 0
            L['strict_drag'] += 1 if r['drag'] else 0
    eps = episodes(rows)
    for e in eps:
        L = legs[e[0]['leg']]
        L['episodes'] += 1
        if any(r['strict'] for r in e):
            L['strict_episodes'] += 1
        if any(r['poke'] for r in e):
            L['poke_episodes'] += 1
        if any(r['drag'] for r in e):
            L['drag_episodes'] += 1
        if any(r['approached'] and r['poke'] for r in e):
            L['approached_poke_episodes'] += 1
        if any(r['approached'] and r['drag'] for r in e):
            L['pull_full_episodes'] += 1
        if any(r['connect_own'] for r in e):
            L['connect_own_episodes'] += 1
        if any(r['connect_enemy'] for r in e):
            L['connect_enemy_episodes'] += 1

    cols = ['frames', 'episodes', 'at_camp', 'approach', 'poke', 'drag',
            'pull_full', 'connect_own', 'connect_enemy',
            'poke_episodes', 'drag_episodes',
            'approached_poke_episodes', 'pull_full_episodes',
            'connect_own_episodes', 'connect_enemy_episodes',
            'strict_frames', 'strict_episodes', 'strict_at_camp',
            'strict_approach', 'strict_poke', 'strict_drag']
    print('\n%-20s %10s %10s' % ('metric', 'armed', 'baseline'))
    for c in cols:
        print('%-20s %10d %10d' % (c, legs['armed'][c], legs['baseline'][c]))
    ng = max(len(games), 1)
    print('\ngames: %d   strict domain episodes per game: armed %.2f  base %.2f'
          % (len(games), legs['armed']['strict_episodes'] / ng,
             legs['baseline']['strict_episodes'] / ng))
    if a.any_camp:
        na = sum(1 for r in rows if not r['strict'] and r['leg'] == 'armed')
        nb = sum(1 for r in rows if not r['strict'] and r['leg'] == 'baseline')
        print('any-camp-only frames (camp-team assignment excluded them): '
              'armed %d  baseline %d' % (na, nb))

    print('\n--- top POKE/DRAG frames (armed leg first) for frame-by-frame review ---')
    cand_rows = [r for r in rows if r['poke'] or r['drag']]
    cand_rows.sort(key=lambda r: (r['leg'] != 'armed', not r['drag'], r['camp_d']))
    for r in cand_rows[:a.top]:
        print('%-8s %-24s t=%-6.1f %-18s pos%s hp=%.2f camp_d=%-5d '
              'appr=%-5d poke=%-5s drag=%s'
              % (r['leg'], r['game'], r['t'], canon(r['hero']), r['pos'],
                 r['hp'], r['camp_d'], r['approach'], r['poke'], r['drag']))

    with open(a.out, 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    print('\n(%d domain frames written to %s)' % (len(rows), a.out))


if __name__ == '__main__':
    main()

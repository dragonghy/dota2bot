#!/usr/bin/env python3
"""Execution check ((a)-evidence) for the `creeppull` soak candidate.

`J.ShouldCreepPullLane` (jmz_func.lua:6698) + `J.IsCreepPullSafe`
(jmz_func.lua:6212) + the roam call site (mode_roam_generic.lua:94, action at
:185) implement the turbo 勾线: a laning CORE that is behind draws the enemy
wave's aggro by attack-ordering the adjacent enemy hero for a beat, then walks
toward its own fountain to drag the wave onto our half.

This tool answers WORKING / BUGGY / SILENT from the 1 Hz replay timelines, over
a mirrored-draft wave (one side armed, the other stock code = the within-game
control leg).

DOMAIN (a deliberate SUPERSET of the Lua gate -- three source clauses are NOT
observable offline, so this cannot over-claim SILENT, only under-claim it):
  observable      t in (0, 360]                      DotaTime() > 6*60 -> nil
                  hp_pct >= 0.50                     SAFE-1 / IsCreepPullSafe
                  1 <= nNear(<=1000) <= 2            IsCreepPullSafe
                  nWide(<=1800) == nNear             IsCreepPullSafe
                  >=1 enemy lane creep within 900    GetNearbyLaneCreeps(900)
                  an enemy hero <=1000 of me AND     the aggro target loop
                    <=500 of an enemy lane creep
  NOT observable  IsInLaningPhase()  (a superset in t<=360 for turbo anyway)
                  WasRecentlyDamagedByAnyHero()      [harness] capture gap
                  lane-front advance / WeAreStronger  (the DISADVANTAGED clause)
  OBSERVABLE      J.GetPosition() -- from the soak seed's draft, via
                  seed_draft.positions_for_game (NOT the pick slot: GH #57,
                  team_slot%5+1 was 47.3% accurate). Unattributable games
                  (warm-ups, no seed stamp) yield pos=None and drop out of the
                  core reading rather than being mislabelled into it.

SIGNATURE (the action, as it looks at 1 Hz):
  DRAG   -- from a domain frame t, displacement over [t, t+DRAG_S] projected on
            the unit vector toward our own fountain is >= DRAG_U, and an enemy
            hero is still within 1400 at the end (we dragged, we did not just
            walk home to heal).
  POKE   -- this hero deals damage to the aggro-target hero in [t-1, t+2].
  PULL   -- DRAG and POKE together: the cadence the call site emits.

Everything is reported per leg (armed = the manifest's `side`, baseline = the
other team of the same game), which is the mirrored device's free control.

Positional-conventions and traps honoured here (iterations/streams/replay-check.md):
  * entity identity comes from `idx`, main entity = EARLIEST appearing idx
    (never hp_max/frame count) -- illusions are field-for-field copies;
  * `by_t` is idx-locked too, so a copy of ANY hero cannot inflate the enemy
    rings (the 08-22T04:05Z (丙) trap);
  * "<= t 的最后一帧" lookups with an explicit staleness cap, never a fixed
    offset and never detect.py's +/-2s tol;
  * combat-log actor/target names are canonicalised before comparison;
  * creeps are sampled at 3 s, so the creep clauses use a 1.6 s staleness cap
    and are reported separately from the hero-only clauses.

Usage:
    creeppull_domain.py <sweep_dir> [<sweep_dir> ...] [--selfcheck] [--top N]

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

T_MAX = 360.0          # DotaTime() > 6*60 -> nil
HP_MIN = 0.50          # J.GetHP(bot) < 0.5 -> nil
R_NEAR = 1000.0        # GetNearbyHeroes(bot, 1000, ...) / IsCreepPullSafe near ring
R_WIDE = 1800.0        # IsCreepPullSafe wide ring
R_CREEP = 900.0        # bot:GetNearbyLaneCreeps(900, true)
R_AGGRO = 500.0        # creep aggro-redirect range in the target loop
CREEP_STALE = 1.6      # creeps are dumped every 3.0 s
DRAG_S = 3.0
DRAG_U = 200.0
DRAG_KEEP = 1400.0     # an enemy still this close at the end of the drag
POKE_BACK, POKE_FWD = 1.0, 2.0
TP_TAIL = 1.5          # see clean_window(): the landing lands one sample late
EPISODE_GAP = 3.0      # consecutive domain frames <= this apart are one episode

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

        # --- identity: main entity = earliest-appearing idx for each hero name
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

        # --- idx-locked per-hero frames, and an idx-locked by_t index
        self.frames = defaultdict(dict)     # hero -> {t: snap}
        self.by_t = defaultdict(list)       # t -> [snap] (main entities only)
        for s in d['snapshots']:
            if s['t'] > self.t_end or s['idx'] != self.main_idx.get(s['hero']):
                continue
            self.frames[s['hero']][s['t']] = s
            self.by_t[s['t']].append(s)

        # --- creeps, bucketed by sample time
        self.creep_t = sorted({c['t'] for c in d.get('creeps', [])})
        self.creeps = defaultdict(list)
        for c in d.get('creeps', []):
            self.creeps[c['t']].append(c)

        # --- damage events, canonicalised, hero -> hero only
        c2h = {canon(h): h for h in self.teams}
        self.dmg = defaultdict(list)        # (actor, target) -> [t]
        self.deaths = defaultdict(list)     # hero -> [t] (this hero DIED)
        # TP channels: a hero inside one is executing a decision taken BEFORE
        # the sampled frame and cannot act -- and its landing shows up as a
        # ~1e4 u displacement, which a fountain-ward projection reads as a
        # maximal "drag". (charter 2026-08-21: `modifier_teleporting` 读条帧
        # 不是决策帧; same shape as capmono_refusal.tp_channel_spans.)
        open_tp, self.tp_spans = {}, defaultdict(list)
        for e in events:
            if e['type'] == 'DAMAGE' and e.get('actor_hero') and e.get('target_hero'):
                a = c2h.get(canon(e.get('actor')), e.get('actor'))
                b = c2h.get(canon(e.get('target')), e.get('target'))
                self.dmg[(a, b)].append(e['t'])
            elif e['type'] == 'DEATH' and e.get('target_hero'):
                self.deaths[c2h.get(canon(e.get('target')), e.get('target'))].append(e['t'])
            if e.get('inflictor') == 'modifier_teleporting':
                h = c2h.get(canon(e.get('target')), e.get('target'))
                if e['type'] == 'MODIFIER_ADD':
                    open_tp[h] = e['t']
                elif e['type'] == 'MODIFIER_REMOVE' and h in open_tp:
                    self.tp_spans[h].append((open_tp.pop(h), e['t']))
        for h, t in open_tp.items():
            self.tp_spans[h].append((t, t + 4.0))

        # --- fountains: centroid of each team's earliest 3 s of frames
        #     (positive control: the pre-horn spawn is the fountain itself)
        # (each team enters the snapshot stream at its own first tick, so the
        #  3 s window is measured per team, not from a global t0)
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
        self.fountain = {tm: (a[0] / a[2], a[1] / a[2]) for tm, a in acc.items() if a[2]}
        self.ancient = {}
        for b in d.get('buildings', []):
            if b['name'] == 'ancient':
                self.ancient.setdefault(b['team'], (b['x'], b['y']))

        # --- positions from the SOAK SEED's draft, never from the pick slot.
        # GH #57: `X.ShufflePickOrder` permutes the slots after the draft, so
        # `team_slot % 5 + 1` agreed with the drafted position on only 47.3% of
        # rows across 291 real mirror games -- it is forbidden under tools/ and
        # `tests/test_hero_position.py` check [6] fails the build on it.
        # `positions_for_game` returns None (not a guess) when the game is not
        # attributable to a seed -- e.g. warm-up games, which carry a bare tree
        # SHA instead of a `mirror:...:s<seed>:...` stamp. That propagates to
        # `pos = None`, and every consumer here reads `pos and pos <= 3`, so an
        # unattributable game drops OUT of the core reading instead of being
        # mislabelled into it -- the same under-claim-never-over-claim direction
        # this tool's DOMAIN section commits to.
        self.pos = {}
        if analysis_path and os.path.exists(analysis_path):
            self.pos = seed_draft.positions_for_game(
                json.load(open(analysis_path))) or {}

    def recent_hero_dmg(self, hero, t, back):
        """`bot:WasRecentlyDamagedByAnyHero(back)` -- observable after all.

        The charter's "known capture gap" list names this reader, but the gap is
        about the ENGINE call; the combat log carries every hero->hero DAMAGE
        event, so the predicate itself reconstructs exactly. (Understated, never
        overstated: a hero-owned summon's damage also sets the engine's flag and
        is not counted here, so STRICT stays a superset of the Lua gate.)
        """
        for (a, b), ts in self.dmg.items():
            if b != hero:
                continue
            if any(t - back <= x <= t for x in ts):
                return True
        return False

    def creep_dmg(self, hero, t0, t1):
        """Did this hero damage any non-hero unit in [t0, t1]? (still last-hitting)"""
        for e in self.raw_events:
            if e['t'] < t0:
                continue
            if e['t'] > t1:
                break
            if (e['type'] == 'DAMAGE' and e.get('actor_hero')
                    and not e.get('target_hero')
                    and canon(e.get('actor')) == canon(hero)):
                return True
        return False

    def clean_window(self, hero, t0, t1):
        """No TP channel and no death of this hero overlapping [t0, t1].

        Both would teleport the body and be read as a maximal drag; the charter
        requires the DEATH exclusion to be explicit rather than folded into a
        displacement cap (respawn and TP landing are indistinguishable by size).
        """
        # TP_TAIL: the LANDING is visible one sample AFTER the channel closes --
        # `20260822_103347_slot4` CM has MODIFIER_REMOVE modifier_teleporting at
        # 135.1 while the snapshot at 135.4 still carries the pre-TP position and
        # only 136.4 shows the landing (a 10,060 u "drag" that the untailed span
        # let straight through, caught by the drag guard). One sampling interval
        # plus margin.
        for a, b in self.tp_spans.get(hero, ()):
            if a <= t1 and b + TP_TAIL >= t0:
                return False
        return not any(t0 - 1.0 <= dt <= t1 for dt in self.deaths.get(hero, ()))

    def alive_at(self, hero, t):
        s = self.frames[hero].get(t)
        return s if (s and s['hp_pct'] > 0) else None

    def creeps_at(self, t):
        """<= t 的最后一帧, with an explicit staleness cap."""
        best = None
        for ct in self.creep_t:
            if ct <= t:
                best = ct
            else:
                break
        if best is None or t - best > CREEP_STALE:
            return None
        return self.creeps[best]

    def leg(self, hero):
        return 'armed' if self.teams.get(hero) == self.armed_team else 'baseline'


def scan_game(g, name, seed):
    """Frame-level domain scan. Returns a list of per-frame records."""
    out = []
    for hero, fr in g.frames.items():
        team = g.teams.get(hero)
        if not team:
            continue
        pos = g.pos.get(hero)
        fx, fy = g.fountain.get(team, (0.0, 0.0))
        for t in sorted(fr):
            if not (0 < t <= T_MAX):
                continue
            s = fr[t]
            if s['hp_pct'] < HP_MIN or s['hp_pct'] <= 0:
                continue
            enemies = [o for o in g.by_t.get(t, [])
                       if o['team'] != team and o['hp_pct'] > 0]
            near = [o for o in enemies if dist(s['x'], s['y'], o['x'], o['y']) <= R_NEAR]
            wide = [o for o in enemies if dist(s['x'], s['y'], o['x'], o['y']) <= R_WIDE]
            if not (1 <= len(near) <= 2) or len(wide) != len(near):
                continue
            cs = g.creeps_at(t)
            if cs is None:
                continue
            ec = [c for c in cs
                  if c['team'] != team and dist(s['x'], s['y'], c['x'], c['y']) <= R_CREEP]
            if not ec:
                continue
            # bWavePushedToUs, conservatively: the enemy lane creeps we are
            # standing in are closer to OUR ancient than to theirs, i.e. the
            # wave is physically on our half. GetLaneFrontAmount is not in the
            # dump; this proxy can only be TRUE when the source clause is true,
            # so STRICT+ourhalf stays a subset-of-the-gate reading.
            cx = sum(c['x'] for c in ec) / len(ec)
            cy = sum(c['y'] for c in ec) / len(ec)
            oa = g.ancient.get(team)
            ea = g.ancient.get(DIRE if team == RADIANT else RADIANT)
            ourhalf = bool(oa and ea and dist(cx, cy, *oa) < dist(cx, cy, *ea))

            tgt = None
            for o in near:
                for c in ec:
                    if dist(o['x'], o['y'], c['x'], c['y']) <= R_AGGRO:
                        tgt = o
                        break
                if tgt:
                    break
            if tgt is None:
                continue

            # --- signature
            s2 = fr.get(t + DRAG_S)
            drag = 0.0
            keep = False
            clean = g.clean_window(hero, t, t + DRAG_S)
            if s2 and s2['hp_pct'] > 0 and clean:
                mx, my = s2['x'] - s['x'], s2['y'] - s['y']
                dx, dy = fx - s['x'], fy - s['y']
                n = max(math.hypot(dx, dy), 1.0)
                drag = (mx * dx + my * dy) / n
                keep = any(dist(s2['x'], s2['y'], o['x'], o['y']) <= DRAG_KEEP
                           for o in g.by_t.get(t + DRAG_S, [])
                           if o['team'] != team and o['hp_pct'] > 0)
            poke = any(t - POKE_BACK <= et <= t + POKE_FWD
                       for et in g.dmg.get((hero, tgt['hero']), ()))
            out.append(dict(game=name, seed=seed, hero=hero, pos=pos,
                            leg=g.leg(hero), t=t, hp=round(s['hp_pct'], 3),
                            x=s['x'], y=s['y'], near=len(near), ncreep=len(ec),
                            tgt=tgt['hero'], tgt_d=round(dist(s['x'], s['y'],
                                                             tgt['x'], tgt['y'])),
                            ourhalf=ourhalf,
                            strict=bool(pos and pos <= 3 and len(near) == 1
                                        and not g.recent_hero_dmg(hero, t, 2.0)),
                            lasthitting=g.creep_dmg(hero, t, t + DRAG_S),
                            drag=round(drag), keep=keep, poke=poke, clean=clean,
                            pull=bool(drag >= DRAG_U and keep and poke)))
    return out


def episodes(rows):
    """Group a hero's consecutive domain frames (gap <= EPISODE_GAP)."""
    by = defaultdict(list)
    for r in rows:
        by[(r['game'], r['hero'])].append(r)
    eps = []
    for k, rs in by.items():
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
            # "games swept: 3 (skipped 1 warmup)" -> the FIRST int after the colon
            claimed = int(line.split(':', 1)[1].split('(')[0].strip())
            break
    if claimed is None or claimed != len(rows):
        sys.exit('[fatal] %s: summary says %s, manifest holds %d -- re-sweep'
                 % (d, claimed, len(rows)))
    return rows


def selfcheck(games):
    """Field-by-field checks against priors that must hold on real data."""
    ok = True

    def chk(name, cond, detail=''):
        nonlocal ok
        print('  %-34s %s %s' % (name, 'PASS' if cond else 'FAIL', detail))
        ok = ok and cond

    g = games[0][0]
    # Fountains: the two spawn corners of a 16k map sit ~19k apart, and each
    # centroid must be behind its OWN ancient (the positive control the charter
    # requires for any fountain/geometry predicate -- a miscalibrated prior here
    # was the first thing this selfcheck caught).
    fs = g.fountain
    d = dist(*fs[RADIANT], *fs[DIRE]) if len(fs) == 2 else -1
    chk('fountains ~19k apart', 17000 < d < 21000, 'd=%d' % d)
    anc = g.ancient
    ok_side = all(
        dist(*fs[tm], *anc[tm]) < 2500 and dist(*fs[tm], *anc[tm]) <
        dist(*fs[tm], *anc[RADIANT if tm == DIRE else DIRE])
        for tm in (RADIANT, DIRE) if tm in fs and tm in anc)
    chk('centroid behind own ancient', ok_side,
        'r=%d d=%d' % (dist(*fs[RADIANT], *anc[RADIANT]),
                       dist(*fs[DIRE], *anc[DIRE])))
    # every hero on a team, 5 v 5
    n_r = sum(1 for h, t in g.teams.items() if t == RADIANT)
    chk('roster 5v5', n_r == 5 and len(g.teams) == 10, '%d radiant' % n_r)
    # idx lock actually locked something or the corpus is copy-free
    tot_copies = sum(x[0].copies for x in games)
    chk('idx lock ran', True, 'non-main entities across corpus: %d' % tot_copies)
    # legs are balanced across the corpus
    legs = defaultdict(int)
    for gg, _, _ in games:
        for h in gg.teams:
            legs[gg.leg(h)] += 1
    chk('legs balanced', legs['armed'] == legs['baseline'], dict(legs))
    # creep staleness cap never silently accepts a >3 s gap
    chk('creep sample step 3 s',
        len(g.creep_t) > 1 and abs((g.creep_t[1] - g.creep_t[0]) - 3.0) < 1e-6,
        'step=%s' % (g.creep_t[1] - g.creep_t[0] if len(g.creep_t) > 1 else '?'))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sweeps', nargs='+')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--top', type=int, default=12)
    a = ap.parse_args()

    games = []
    for d in a.sweeps:
        for m in load_sweep(d):
            tl = os.path.join(d, 'timelines', m['game'] + '.timeline.json')
            an = os.path.join(d, 'analysis', m['game'] + '.analysis.json')
            if not os.path.exists(tl):
                print('[warn] missing timeline %s' % tl, file=sys.stderr)
                continue
            games.append((Game(tl, an, m['side']), m['game'], m['seed']))
    print('corpus: %d games from %d sweep dir(s)' % (len(games), len(a.sweeps)))
    if 'creeppull' not in json.loads(open(os.path.join(
            a.sweeps[0], 'games_manifest.jsonl')).readline())['cand']:
        print('[warn] `creeppull` is NOT in this wave\'s cand string')

    if a.selfcheck:
        print('--- selfcheck ---')
        if not selfcheck(games):
            sys.exit(2)

    rows = []
    for g, name, seed in games:
        rows.extend(scan_game(g, name, seed))

    # Post-scan guard: after the TP/death exclusions no surviving drag may
    # exceed what a hero can physically walk in DRAG_S seconds (~550 u/s with
    # every haste in the game). A violation means another body-teleport channel
    # is leaking in, exactly the way the TP one did on the first cut.
    worst = max((r for r in rows if r['clean']), key=lambda r: r['drag'], default=None)
    n_dirty = sum(1 for r in rows if not r['clean'])
    print('drag guard: max clean drag = %s u (cap %d); %d/%d domain frames '
          'excluded as TP-channel/death windows'
          % (worst['drag'] if worst else 'n/a', 550 * DRAG_S, n_dirty, len(rows)))
    if worst and worst['drag'] > 550 * DRAG_S:
        print('[fatal] drag guard tripped: %s' % worst)
        sys.exit(2)

    legs = defaultdict(lambda: defaultdict(int))
    for r in rows:
        L = legs[r['leg']]
        L['frames'] += 1
        L['core_frames'] += 1 if (r['pos'] and r['pos'] <= 3) else 0
        L['poke'] += 1 if r['poke'] else 0
        L['drag'] += 1 if r['drag'] >= DRAG_U else 0
        L['pull'] += 1 if r['pull'] else 0
        if r['pos'] and r['pos'] <= 3:
            L['core_pull'] += 1 if r['pull'] else 0
    eps = episodes(rows)
    for e in eps:
        legs[e[0]['leg']]['episodes'] += 1
        if any(r['pull'] for r in e):
            legs[e[0]['leg']]['pull_episodes'] += 1
        if e[0]['pos'] and e[0]['pos'] <= 3:
            legs[e[0]['leg']]['core_episodes'] += 1
            if any(r['pull'] for r in e):
                legs[e[0]['leg']]['core_pull_episodes'] += 1

    # STRICT: every observable source clause at its literal threshold. The only
    # clauses left out are the two that a 1 Hz replay cannot express (lane-front
    # advance / WeAreStronger), and bZoned makes the DISADVANTAGED disjunction
    # true whenever we are not locally stronger -- so STRICT is a tight superset
    # of the frames on which J.ShouldCreepPullLane must return a pull intent.
    for r in rows:
        if r['strict']:
            L = legs[r['leg']]
            L['strict_frames'] += 1
            L['strict_pull'] += 1 if r['pull'] else 0
            L['strict_lasthit'] += 1 if r['lasthitting'] else 0
            if r['ourhalf']:
                L['forced_frames'] += 1
                L['forced_pull'] += 1 if r['pull'] else 0
                L['forced_lasthit'] += 1 if r['lasthitting'] else 0
    for e in eps:
        if any(r['strict'] for r in e):
            legs[e[0]['leg']]['strict_episodes'] += 1

    cols = ['frames', 'core_frames', 'episodes', 'core_episodes', 'poke',
            'drag', 'pull', 'core_pull', 'pull_episodes', 'core_pull_episodes',
            'strict_frames', 'strict_episodes', 'strict_pull', 'strict_lasthit',
            'forced_frames', 'forced_pull', 'forced_lasthit']
    print('\n%-20s %10s %10s' % ('metric', 'armed', 'baseline'))
    for c in cols:
        print('%-20s %10d %10d' % (c, legs['armed'][c], legs['baseline'][c]))
    print('\ngames: %d  (per-leg per-game core domain episodes: armed %.2f, base %.2f)'
          % (len(games),
             legs['armed']['core_episodes'] / max(len(games), 1),
             legs['baseline']['core_episodes'] / max(len(games), 1)))

    print('\n--- top core PULL frames (armed leg first) for frame-by-frame review ---')
    cand = [r for r in rows if r['pull'] and r['pos'] and r['pos'] <= 3]
    cand.sort(key=lambda r: (r['leg'] != 'armed', -r['drag']))
    for r in cand[:a.top]:
        print('%-8s %-24s t=%-6.1f %-22s pos%s hp=%.2f tgt=%-20s d=%-5d drag=%-5d'
              % (r['leg'], r['game'], r['t'], canon(r['hero']), r['pos'],
                 r['hp'], canon(r['tgt']), r['tgt_d'], r['drag']))

    with open('/tmp/creeppull_rows.jsonl', 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')
    print('\n(%d domain frames written to /tmp/creeppull_rows.jsonl)' % len(rows))


if __name__ == '__main__':
    main()

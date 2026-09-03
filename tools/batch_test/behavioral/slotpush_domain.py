#!/usr/bin/env python3
"""(a)-verification for soak candidate `slotpush` (GH #415, admitted W39).

WHAT `slotpush` DOES
--------------------
`bots/FunLib/utils.lua:1708` -- `IsTeamPushingSecondTierOrHighGround(bot, bSlotPush)`:

    for i, playerdId in ipairs(GetTeamPlayers(bot:GetTeam())) do
        if IsHeroAlive(playerdId) then
            local nSlot = playerdId
            if bSlotPush then nSlot = i end          -- <- THE GATE
            local teamMember = GetTeamMember(nSlot)
            if teamMember ~= nil
               and #teamMember:GetNearbyHeroes(2000, false, BotMode.None) >= 2
               and (IsNearEnemySecondTierTower(teamMember, 2000)
                    or IsNearEnemyHighGroundTower(teamMember, 3000)
                    or GetUnitToUnitDistance(teamMember, enemyAncient) < 3000)
            then return true end
        end
    end
    return false

`GetTeamPlayers` hands back PLAYER IDS (0..4 radiant / 5..9 dire);
`GetTeamMember` takes a TEAM SLOT (1..5).  Feeding one to the other is the
third instance of the same defect this stream has measured (`slotarb` GH #406,
`slotdust` GH #411).  The shrinkage is SIDE-DEPENDENT:

  * radiant, ids 0..4 -> nSlot 0..4.  `GetTeamMember(0)` is nil, so i=1 is
    skipped entirely and i=2..5 read slots 1..4 -- FOUR of five members are
    scanned, the hero in team slot 5 (pid 4) is never looked at, and from i=2
    on the guard `IsHeroAlive(playerdId)` is asked about pid i-1 while the
    member fetched is pid i-2.  GUARD AND SUBJECT ARE DIFFERENT HEROES.
  * dire, ids 5..9 -> nSlot 5..9.  Only nSlot=5 is in range, at i=1, so
    exactly ONE of five members is ever scanned (team slot 5 == pid 9), and
    its guard is asked about pid 5.

Armed, `nSlot = i`, so player id list[i] and team slot i are the same hero:
all five are scanned and every guard is about its own subject.

SIGN OF THE LEVER, AND WHY THE ARITHMETIC PREDICTS A SIDE RATIO
---------------------------------------------------------------
The seven call sites (`J.IsTeamPushingHighGround`, resolved in exactly one
place -- `jmz_func.lua:12409`) all use TRUE to SUPPRESS a distraction
(BOT_MODE_DESIRE_NONE for ward / rune / outpost / side shop / secret shop /
roshan / return-to-lane).  Under-scanning can only make TRUE HARDER to reach,
so the shipped tree peels bots off a high-ground siege to go shopping.  Dire
loses four of five scan slots, radiant one of five => the UNDER direction
(armed TRUE, shipped FALSE) is predicted to be structurally larger on dire.
That prediction is a property of the ARITHMETIC, not of either leg, so it is
testable WITHOUT any armed-vs-baseline comparison -- which matters here,
because iron rule 4(i-b) forbids reading a side-biased estimator across legs.

It is NOT a strict subset in the other direction: the misaligned guard lets
the shipped scan answer TRUE off a member whose own liveness was never
checked, which armed refuses.  Both directions are counted below.

WHAT THIS READING CAN AND CANNOT SAY
------------------------------------
LIMIT 1 -- `GetTeamMember(slot)` mapping.  Slot s is taken to be pid s-1
(radiant) / s+4 (dire), i.e. the roster in player-id order.  This is the same
hypothesis `slotdust_arbitration.team_slot` encodes and it is not observable
in a `.dem`; every count below inherits it.

LIMIT 2 -- ALLY COUNT EXCLUDES ILLUSIONS.  `real_bodies` keeps only entities
first sampled before the horn, so an illusion never enters the >= 2 ally
test.  The engine counts illusions as heroes (GH #176 is exactly this trap on
Chaos Knight).  Our ally count is therefore a LOWER bound and the >= 2 test a
conservative one: frames we call FALSE could be TRUE in the engine.

LIMIT 3 -- RADIUS CAP.  docs/BOT_API_REFERENCE.md:1319 documents
`GetNearbyHeroes(nRadius, ...)` as "max 1600" while the shipped call passes
2000.  If the engine clamps, the real ally radius is 1600.  Both radii are
computed and reported; no conclusion here rests on the difference.

LIMIT 4 -- DEAD MEMBERS ARE UNOBSERVABLE.  A hero with hp_pct <= 0 is dropped
from the frame index, so when the shipped scan's misaligned guard sends it to
a DEAD member we cannot evaluate that member's position.  Those frames are
reported in their own column (`ind`) and excluded from the strict divergence
counts rather than guessed at.

LIMIT 5 -- the 1 s `GetCachedVars` memo (utils.lua:1713) means the predicate
is evaluated at most once per second per team per cache key.  Snapshots are
sampled at 1.0 s, so the grid matches, but which of the two is the leading
edge is not observable.  Divergence is counted per snapshot second.

LIMIT 6 -- `slotpush` sits UNDER `outlatch` in a same-arm conjunction (GH
#424, test_set.md SS-DN.6).  Nothing below reads a leg difference, so that
conjunction cannot contaminate these numbers; it would contaminate any future
promote-facing econ read.

USAGE
    slotpush_domain.py --run <timelines_dir>:<manifest.jsonl> [--run ...]
    slotpush_domain.py --selfcheck
"""
import argparse
import collections
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from slotdust_arbitration import (  # noqa: E402
    DIRE, RADIANT, real_bodies, roster, team_slot)

REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
UTILS = os.path.join(REPO, 'bots', 'FunLib', 'utils.lua')
JMZ = os.path.join(REPO, 'bots', 'FunLib', 'jmz_func.lua')

CAND = 'slotpush'

ALIVE_DT = 1.5          # a body counts as present within this of the frame
BUILD_DT = 6.0          # buildings sample at 5.0 s; last sample at or before t

N_HIGH_GROUND = 5       # Top3/Mid3/Bot3/Base1/Base2  (utils.lua:734)
N_SECOND_TIER = 3       # Top2/Mid2/Bot2              (utils.lua:742)

# The tier partition is by RANK of distance from a team's own ancient, so the
# only thing that can make it wrong is a boundary that does not actually
# separate.  A bare `d[i] < d[i+1]` catches only exact ties and would let a
# ranked-noise map through -- found by a mutation that removed the guard and
# was NOT caught, because the test's "does not separate" map was collapsing on
# the tower COUNT instead.  Measured on this corpus, the tightest real boundary
# is radiant T2-bot 5633 vs T1-mid 5891: 258 u, 4.6%.  Both floors below sit
# ~2.5x under that.
MIN_TIER_GAP = 100.0
MIN_TIER_GAP_FRAC = 0.015


# ---------------------------------------------------------------------------
# source facts -- READ OFF THE TREE at run time, never transcribed
# ---------------------------------------------------------------------------
def _read(path):
    with open(path, 'r', encoding='utf-8') as fh:
        return fh.read()


def _strip_lua_comments(src):
    return re.sub(r'^\s*--.*$', '', src, flags=re.M)


def _fn_body(src, header_re):
    """Text from a function header to the next top-level declaration."""
    m = re.search(header_re, src, re.M)
    if not m:
        return ''
    nxt = re.compile(r'^(?:function\b|local\s+function\b|____exports\.\w+\s*=)',
                     re.M).search(src, m.end())
    return src[m.start():nxt.start() if nxt else len(src)]


def _brace_list(src, name):
    """The `{...}` a top-level ____exports.<name> assignment holds."""
    m = re.search(r'^____exports\.%s\s*=\s*\{' % re.escape(name), src, re.M)
    if not m:
        return None
    depth, i = 0, m.end() - 1
    for j in range(i, len(src)):
        if src[j] == '{':
            depth += 1
        elif src[j] == '}':
            depth -= 1
            if depth == 0:
                return src[i + 1:j]
    return None


def gate_facts(utils_src=None, jmz_src=None):
    """Every constant and shape the attribution rests on, read at run time.

    FAIL-LOUD BY CONSTRUCTION (the source_constants.py contract): a pattern
    that matches zero times yields None/0 and the caller's assertions raise.
    There is no default= anywhere here on purpose.
    """
    utils = _strip_lua_comments(utils_src if utils_src is not None
                                else _read(UTILS))
    jmz = _strip_lua_comments(jmz_src if jmz_src is not None
                              else _read(JMZ))

    body = _fn_body(
        utils,
        r'^function ____exports\.IsTeamPushingSecondTierOrHighGround\s*\(')

    ally = re.search(r'GetNearbyHeroes\(\s*(\d+)\s*,\s*false\s*,', body)
    ge = re.search(r'GetNearbyHeroes\([^)]*\)\s*>=\s*(\d+)', body)
    t2 = re.search(r'IsNearEnemySecondTierTower\(\s*teamMember\s*,\s*(\d+)\s*\)',
                   body)
    hg = re.search(r'IsNearEnemyHighGroundTower\(\s*teamMember\s*,\s*(\d+)\s*\)',
                   body)
    anc = re.search(r'GetUnitToUnitDistance\(\s*teamMember\s*,\s*enemyAncient'
                    r'\s*\)\s*<\s*(\d+)', body)

    hg_list = _brace_list(utils, 'HighGroundTowers') or ''
    t2_list = _brace_list(utils, 'SecondTierTowers') or ''

    # the ONE gate-resolution site, one level up (utils may not read the gate)
    wrap = _fn_body(jmz, r'^function J\.IsTeamPushingHighGround\s*\(')

    return {
        'ally_radius': int(ally.group(1)) if ally else None,
        'ally_min': int(ge.group(1)) if ge else None,
        't2_radius': int(t2.group(1)) if t2 else None,
        'hg_radius': int(hg.group(1)) if hg else None,
        'ancient_radius': int(anc.group(1)) if anc else None,
        'iter_players': bool(re.search(
            r'ipairs\(GetTeamPlayers\(bot:GetTeam\(\)\)\)', body)),
        'shipped_slot_is_id': bool(re.search(
            r'local\s+nSlot\s*=\s*playerdId', body)),
        'armed_slot_is_index': bool(re.search(
            r'if\s+bSlotPush\s+then\s*\n\s*nSlot\s*=\s*i\b', body)),
        'guard_is_pid': bool(re.search(r'if\s+IsHeroAlive\(playerdId\)', body)),
        'member_is_slot': bool(re.search(
            r'local\s+teamMember\s*=\s*GetTeamMember\(\s*nSlot\s*\)', body)),
        'cached_seconds': int(m.group(1)) if (
            m := re.search(r'GetCachedVars\(cacheKey,\s*(\d+)\)', body)) else None,
        'separate_cache_key': bool(re.search(r'cacheKey\s*\.\.\s*"byslot"', body)),
        'n_high_ground': len(re.findall(r'Tower\.\w+', hg_list)),
        'n_second_tier': len(re.findall(r'Tower\.\w+', t2_list)),
        'gate_conjuncts': sorted(re.findall(
            r"IsSoakCandidate\(\s*'([^']+)'\s*\)", wrap)),
        'gate_is_turbo_only': bool(re.search(r'J\.IsModeTurbo\(\)', wrap)),
        'wrapper_call_sites': len(re.findall(
            r'J\.Utils\.IsTeamPushingSecondTierOrHighGround\s*\(', jmz)),
    }


# ---------------------------------------------------------------------------
# corpus
# ---------------------------------------------------------------------------
def dist(ax, ay, bx, by):
    return math.dist((ax, ay), (bx, by))


def index_bodies(snaps):
    """{(hero, idx): [frames sorted by t]} over pre-horn bodies, alive only."""
    bodies = real_bodies(snaps)
    by_ent = collections.defaultdict(list)
    for s in snaps:
        if (s.get('hp_pct') or 0) <= 0:
            continue
        k = (s['hero'], s['idx'])
        if k in bodies:
            by_ent[k].append(s)
    for v in by_ent.values():
        v.sort(key=lambda s: s['t'])
    return by_ent


def live_pos(frames, t, dt=ALIVE_DT):
    """(x, y) of this body at t, or None if it has no live sample nearby."""
    best, bd = None, dt
    for s in frames:
        d = abs(s['t'] - t)
        if d <= bd:
            best, bd = s, d
        elif s['t'] > t + dt:
            break
    return None if best is None else (best['x'], best['y'])


class Map:
    """Tower tiers DERIVED from the dump, never transcribed coordinates.

    Each team owns exactly 11 towers.  Ranked by distance from that team's OWN
    ancient the partition is 2 base + 3 tier-3 (== the five HighGroundTowers)
    then 3 tier-2 then 3 tier-1, and the three groups are separated by strict
    gaps on the real map.  Both the counts and the separation are asserted, so
    a map change or a dump change raises here instead of quietly reclassifying
    a tower.
    """

    def __init__(self, buildings, n_hg=N_HIGH_GROUND, n_t2=N_SECOND_TIER):
        self.ancient = {}
        samples = collections.defaultdict(dict)   # team -> {(x,y): [(t,alive)]}
        for b in buildings:
            team = b.get('team')
            if team not in (RADIANT, DIRE):
                continue
            if b.get('name') == 'ancient':
                self.ancient[team] = (b['x'], b['y'])
            elif b.get('name') == 'tower':
                key = (round(b['x'], 1), round(b['y'], 1))
                samples[team].setdefault(key, []).append(
                    (b['t'], bool(b.get('alive', True))))
        if sorted(self.ancient) != [RADIANT, DIRE]:
            raise ValueError('ancient positions missing from dump')

        self.hg, self.t2, self.life = {}, {}, {}
        for team in (RADIANT, DIRE):
            towers = samples.get(team, {})
            if len(towers) != n_hg + n_t2 + 3:
                raise ValueError('team %d has %d towers, expected %d'
                                 % (team, len(towers), n_hg + n_t2 + 3))
            own = self.ancient[team]
            order = sorted(towers, key=lambda p: dist(p[0], p[1], own[0], own[1]))
            d = [dist(p[0], p[1], own[0], own[1]) for p in order]
            for i in (n_hg, n_hg + n_t2):
                gap = d[i] - d[i - 1]
                if gap < MIN_TIER_GAP or gap < MIN_TIER_GAP_FRAC * d[i - 1]:
                    raise ValueError(
                        'tower tiers do not separate for team %d at rank %d '
                        '(%.0f -> %.0f)' % (team, i, d[i - 1], d[i]))
            self.hg[team] = order[:n_hg]
            self.t2[team] = order[n_hg:n_hg + n_t2]
            for p in order:
                self.life[(team, p)] = sorted(towers[p])

    def alive(self, team, p, t, dt=BUILD_DT):
        """Last building sample at or before t (LIMIT: 5 s sampling)."""
        rows = self.life[(team, p)]
        state = rows[0][1]
        for bt, al in rows:
            if bt > t + 1e-9:
                break
            state = al
        if rows[0][0] > t + dt:
            return True                        # before first sample: standing
        return state


def enemy(team):
    return DIRE if team == RADIANT else RADIANT


def member_condition(pos_by_pid, team, pid, t, mapinfo, facts, radius):
    """The inner `and` chain of the shipped loop, for one member.

    Returns True/False, or None when the member has no live sample (LIMIT 4).
    """
    me = pos_by_pid.get(pid)
    if me is None:
        return None
    allies = 0
    for other, p in pos_by_pid.items():
        if other == pid:
            continue                            # GetNearbyHeroes excludes self
        if dist(me[0], me[1], p[0], p[1]) <= radius:
            allies += 1
    if allies < facts['ally_min']:
        return False
    foe = enemy(team)
    for p in mapinfo.t2[foe]:
        if mapinfo.alive(foe, p, t) and \
                dist(me[0], me[1], p[0], p[1]) < facts['t2_radius']:
            return True
    for p in mapinfo.hg[foe]:
        if mapinfo.alive(foe, p, t) and \
                dist(me[0], me[1], p[0], p[1]) < facts['hg_radius']:
            return True
    ax, ay = mapinfo.ancient[foe]
    return dist(me[0], me[1], ax, ay) < facts['ancient_radius']


def shipped_scan(team):
    """[(guard_pid, member_pid)] the SHIPPED loop actually evaluates.

    Derived from the numbers, not tabulated: nSlot = playerdId, and only
    1 <= nSlot <= 5 resolves to a member (slot s == pid s-1 radiant / s+4 dire).
    """
    out = []
    pids = range(0, 5) if team == RADIANT else range(5, 10)
    for pid in pids:
        nslot = pid
        if not 1 <= nslot <= 5:
            continue
        out.append((pid, nslot - 1 if team == RADIANT else nslot + 4))
    return out


def armed_scan(team):
    """[(guard_pid, member_pid)] the ARMED loop evaluates: i is the slot."""
    pids = list(range(0, 5) if team == RADIANT else range(5, 10))
    return [(pid, pid) for pid in pids]         # slot i <-> list[i], same hero


def evaluate(pos_by_pid, team, t, mapinfo, facts, radius):
    """(armed, shipped, indeterminate) for one team at one frame."""
    cache = {}

    def cond(pid):
        if pid not in cache:
            cache[pid] = member_condition(pos_by_pid, team, pid, t,
                                          mapinfo, facts, radius)
        return cache[pid]

    armed = False
    for guard, member in armed_scan(team):
        if guard not in pos_by_pid:             # IsHeroAlive(playerdId)
            continue
        if cond(member):
            armed = True
            break
    shipped, ind = False, False
    for guard, member in shipped_scan(team):
        if guard not in pos_by_pid:
            continue
        c = cond(member)
        if c is None:
            ind = True                          # LIMIT 4: dead member
            continue
        if c:
            shipped = True
            break
    return armed, shipped, ind


def scan_game(tl, mapinfo, facts, radius):
    """Per-team per-frame divergence rows for one game."""
    snaps = tl['snapshots']
    by_ent = index_bodies(snaps)
    ros = roster(by_ent)
    if ros is None:
        return None
    frames = {}
    for team, pids in ros.items():
        for pid, key in pids.items():
            for s in by_ent[key]:
                frames.setdefault(round(s['t'], 3), {})[pid] = (s['x'], s['y'])
    rows = []
    for t in sorted(frames):
        if t < 0:
            continue                            # pre-horn
        for team in (RADIANT, DIRE):
            pos = {pid: xy for pid, xy in frames[t].items()
                   if (pid < 5) == (team == RADIANT)}
            if not pos:
                continue
            armed, shipped, ind = evaluate(pos, team, t, mapinfo, facts, radius)
            rows.append({'t': t, 'team': team, 'armed': armed,
                         'shipped': shipped, 'ind': ind, 'n_alive': len(pos)})
    return rows


# ---------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------
def episodes(rows, team, gap=3.0):
    """Contiguous runs of UNDER frames for one team (frames are 1 s apart)."""
    out, cur = [], None
    for r in rows:
        if r['team'] != team:
            continue
        under = r['armed'] and not r['shipped'] and not r['ind']
        if under:
            if cur is None or r['t'] - cur[-1] > gap:
                if cur:
                    out.append(cur)
                cur = [r['t']]
            else:
                cur.append(r['t'])
    if cur:
        out.append(cur)
    return [(e[0], e[-1], len(e)) for e in out]


def consequence(tl, rows, team, pad=0.0):
    """The one consumer of this predicate a .dem can actually see.

    Six of the seven call sites suppress a MODE (ward / rune / outpost / side
    shop / secret shop / roshan / back-to-lane) and a mode is not in the dump
    (LIMIT 7).  Ward PLACEMENT is the exception: `wards[]` is event-shaped and
    carries the placing team and the placement time, so "did this team drop a
    ward during a window where the two scans disagree" is directly countable.

    Returns (wards_in_under_windows, wards_total, under_seconds).
    """
    wins = episodes(rows, team)
    span = sum(b - a + 1.0 for a, b, _ in wins)
    total = hit = 0
    for w in tl.get('wards', ()):
        if w.get('team') != team:
            continue
        total += 1
        t0 = w.get('t_start')
        if t0 is None:
            continue
        for a, b, _ in wins:
            if a - pad <= t0 <= b + pad:
                hit += 1
                break
    return hit, total, span


def load_run(tl_dir, manifest_path):
    """A manifest is bound to its own timeline dir -- GH #444, never pooled."""
    stamps = {}
    with open(manifest_path, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            g = json.loads(line)
            stamps[g['game']] = (g.get('cand'), g.get('seed'), g.get('side'))
    files = []
    for fn in sorted(os.listdir(tl_dir)):
        if fn.endswith('.timeline.json'):
            files.append((fn[:-len('.timeline.json')],
                          os.path.join(tl_dir, fn)))
    return files, stamps


def side_team(side):
    return RADIANT if side == 'radiant' else DIRE


def aggregate(runs, radius, facts, verbose_top=0):
    tally = collections.defaultdict(lambda: collections.Counter())
    per_game = []
    games = errors = 0
    for tl_dir, manifest in runs:
        files, stamps = load_run(tl_dir, manifest)
        for base, path in files:
            if base not in stamps:
                continue
            cand, seed, side = stamps[base]
            if not cand or CAND not in cand.split(','):
                continue
            with open(path, encoding='utf-8') as fh:
                tl = json.load(fh)
            try:
                mapinfo = Map(tl.get('buildings', ()))
            except ValueError as exc:
                errors += 1
                sys.stderr.write('[skip] %s: %s\n' % (base, exc))
                continue
            rows = scan_game(tl, mapinfo, facts, radius)
            if rows is None:
                errors += 1
                sys.stderr.write('[skip] %s: malformed roster\n' % base)
                continue
            games += 1
            g = collections.Counter()
            for team in (RADIANT, DIRE):
                leg = 'armed' if team == side_team(side) else 'baseline'
                sd = 'radiant' if team == RADIANT else 'dire'
                hit, tot, span = consequence(tl, rows, team)
                tally[(sd, leg)]['ward_in_under'] += hit
                tally[(sd, leg)]['ward_total'] += tot
                tally[(sd, leg)]['under_span'] += span
                eps = episodes(rows, team)
                tally[(sd, leg)]['episodes'] += len(eps)
                if eps:
                    longest = max(eps, key=lambda e: e[2])
                    g[(sd, leg, 'longest')] = longest[2]
                    g[(sd, leg, 'longest_t0')] = longest[0]
            for r in rows:
                leg = 'armed' if r['team'] == side_team(side) else 'baseline'
                sd = 'radiant' if r['team'] == RADIANT else 'dire'
                k = (sd, leg)
                tally[k]['frames'] += 1
                g[(sd, leg, 'frames')] += 1
                if r['ind']:
                    tally[k]['ind'] += 1
                if r['armed']:
                    tally[k]['armed_true'] += 1
                if r['shipped']:
                    tally[k]['shipped_true'] += 1
                if r['armed'] and not r['shipped'] and not r['ind']:
                    tally[k]['under'] += 1
                    g[(sd, leg, 'under')] += 1
                if r['shipped'] and not r['armed']:
                    tally[k]['over'] += 1
            per_game.append((base, seed, side, g))
    return tally, per_game, games, errors


def report(tally, games, radius, facts, errors):
    print('== slotpush domain, ally radius %d ==' % radius)
    print('games %d   skipped %d' % (games, errors))
    hdr = ('%-8s %-9s %9s %9s %9s %9s %9s %8s'
           % ('side', 'leg', 'frames', 'armedT', 'shipT', 'UNDER', 'over', 'ind'))
    print(hdr)
    print('-' * len(hdr))
    for sd in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            c = tally[(sd, leg)]
            n = c['frames'] or 1
            print('%-8s %-9s %9d %9d %9d %9d %9d %8d'
                  % (sd, leg, c['frames'], c['armed_true'], c['shipped_true'],
                     c['under'], c['over'], c['ind']))
            print('%-8s %-9s %9s %8.2f%% %8.2f%% %8.3f%% %8.3f%% %7.3f%%'
                  % ('', '(pct)', '', 100.0 * c['armed_true'] / n,
                     100.0 * c['shipped_true'] / n, 100.0 * c['under'] / n,
                     100.0 * c['over'] / n, 100.0 * c['ind'] / n))
    ru = sum(tally[('radiant', l)]['under'] for l in ('armed', 'baseline'))
    rf = sum(tally[('radiant', l)]['frames'] for l in ('armed', 'baseline')) or 1
    du = sum(tally[('dire', l)]['under'] for l in ('armed', 'baseline'))
    df = sum(tally[('dire', l)]['frames'] for l in ('armed', 'baseline')) or 1
    rr, dr = 100.0 * ru / rf, 100.0 * du / df
    print('\nUNDER rate, both legs pooled WITHIN a side (no leg comparison):')
    print('  radiant %.3f%%   dire %.3f%%   ratio %s'
          % (rr, dr, ('%.2fx' % (dr / rr)) if rr else 'n/a'))
    print('  source arithmetic predicts dire >> radiant '
          '(dire scans 1 of 5 slots, radiant 4 of 5); the predicate is an OR '
          'over members, so 4-of-5 loses far less than 1-of-5 and the ratio is '
          'NOT the 4:1 of a nearest-member selection')
    print('\nBLIND FRACTION -- of the frames where the team IS in pushing '
          'geometry, how many the shipped scan cannot see:')
    for sd in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            c = tally[(sd, leg)]
            n = c['armed_true'] or 1
            print('  %-8s %-9s %6d / %6d = %6.2f%%'
                  % (sd, leg, c['under'], c['armed_true'],
                     100.0 * c['under'] / n))
    print('\nObservable consumer (LIMIT 7 -- ward placement is the only one a '
          '.dem carries):')
    for sd in ('radiant', 'dire'):
        for leg in ('armed', 'baseline'):
            c = tally[(sd, leg)]
            span, out = c['under_span'], c['frames'] - c['under_span']
            r_in = c['ward_in_under'] / span if span else float('nan')
            r_out = (c['ward_total'] - c['ward_in_under']) / out if out else \
                float('nan')
            print('  %-8s %-9s wards in UNDER windows %4d / %4d total; '
                  'episodes %5d spanning %8.0f s of %7d'
                  % (sd, leg, c['ward_in_under'], c['ward_total'],
                     c['episodes'], span, c['frames']))
            print('  %-8s %-9s rate in-window %7.3f /100s   out-window %7.3f '
                  '/100s   IN/OUT %s'
                  % ('', '', 100 * r_in, 100 * r_out,
                     ('%.2f' % (r_in / r_out)) if r_out else 'n/a'))
    print('  IN/OUT self-normalises for how ward-happy a team is; the gate '
          'predicts IN/OUT < 1 on the armed leg (ward mode suppressed inside '
          'exactly the windows the shipped scan cannot see) and >= 1 on the '
          'baseline leg.')


# ---------------------------------------------------------------------------
# selfcheck
# ---------------------------------------------------------------------------
def _b(t, name, team, x, y, alive=True):
    return {'t': t, 'name': name, 'team': team, 'x': x, 'y': y,
            'hp_pct': 1.0 if alive else 0.0, 'alive': alive}


def _fake_buildings(times=(0.0, 5.0, 10.0), kill=None):
    """A map whose tiers separate exactly like the real one."""
    out = []
    anc = {RADIANT: (-5920.0, -5352.0), DIRE: (5528.0, 5000.0)}
    # (dx, dy) offsets from own ancient, by rank: 2 base, 3 t3, 3 t2, 3 t1
    # Wider than the real map on purpose: the assertions below need room to
    # place a hero inside ONE ring and its allies outside every ring, which a
    # scale-accurate toy map does not have.
    rings = [(800, 0), (0, 800),
             (2400, 2400), (3600, 600), (600, 3600),
             (6400, 2000), (2000, 6400), (5200, 5200),
             (12000, 2000), (2000, 12000), (9200, 9200)]
    for team in (RADIANT, DIRE):
        sgn = 1 if team == DIRE else -1
        for i, (dx, dy) in enumerate(rings):
            x = anc[team][0] + sgn * dx
            y = anc[team][1] + sgn * dy
            for t in times:
                dead = kill is not None and (team, i) == kill[0] and t >= kill[1]
                out.append(_b(t, 'tower', team, x, y, alive=not dead))
    for team in (RADIANT, DIRE):
        for t in times:
            out.append(_b(t, 'ancient', team, anc[team][0], anc[team][1]))
    return out, anc, rings


def _snap(pid, t, x, y):
    team = RADIANT if pid < 5 else DIRE
    return {'hero': 'npc_dota_hero_h%d' % pid, 'idx': 100 + pid, 'team': team,
            'player_id': pid, 't': t, 'x': float(x), 'y': float(y),
            'hp': 100.0, 'hp_pct': 1.0, 'mp_pct': 1.0, 'level': 1,
            'items': [], 'abilities': []}


def selfcheck():
    ok = fail = 0

    def chk(name, cond):
        nonlocal ok, fail
        if cond:
            ok += 1
            print('  PASS %s' % name)
        else:
            fail += 1
            print('  FAIL %s' % name)

    f = gate_facts()
    print('source facts:', json.dumps(f, sort_keys=True))
    chk('ally radius read from tree (2000)', f['ally_radius'] == 2000)
    chk('ally minimum read from tree (2)', f['ally_min'] == 2)
    chk('t2 radius read from tree (2000)', f['t2_radius'] == 2000)
    chk('hg radius read from tree (3000)', f['hg_radius'] == 3000)
    chk('ancient radius read from tree (3000)', f['ancient_radius'] == 3000)
    chk('loop iterates GetTeamPlayers', f['iter_players'])
    chk('shipped nSlot is the player id', f['shipped_slot_is_id'])
    chk('armed nSlot is the loop index', f['armed_slot_is_index'])
    chk('guard reads the player id', f['guard_is_pid'])
    chk('member is fetched by slot', f['member_is_slot'])
    chk('HighGroundTowers has 5 entries',
        f['n_high_ground'] == N_HIGH_GROUND)
    chk('SecondTierTowers has 3 entries',
        f['n_second_tier'] == N_SECOND_TIER)
    chk('gate is this candidate alone', f['gate_conjuncts'] == [CAND])
    chk('gate is turbo-only', f['gate_is_turbo_only'])
    chk('one wrapper call site in jmz_func', f['wrapper_call_sites'] == 1)
    chk('armed keeps a separate 1 s cache key',
        f['separate_cache_key'] and f['cached_seconds'] == 1)

    # --- the scan tables, derived ------------------------------------------
    chk('radiant shipped scan is 4 pairs, guard != member from i=2',
        shipped_scan(RADIANT) == [(1, 0), (2, 1), (3, 2), (4, 3)])
    chk('dire shipped scan is exactly one pair, guard 5 member 9',
        shipped_scan(DIRE) == [(5, 9)])
    chk('armed scan is all five, guard == member (radiant)',
        armed_scan(RADIANT) == [(p, p) for p in range(5)])
    chk('armed scan is all five, guard == member (dire)',
        armed_scan(DIRE) == [(p, p) for p in range(5, 10)])
    chk('radiant never scans pid 4',
        4 not in {m for _, m in shipped_scan(RADIANT)})
    chk('dire scans only pid 9',
        {m for _, m in shipped_scan(DIRE)} == {9})
    chk('team_slot agrees with the derived mapping',
        all(team_slot(RADIANT, p) == p + 1 for p in range(5))
        and all(team_slot(DIRE, p) == p - 4 for p in range(5, 10)))

    # --- map derivation -----------------------------------------------------
    builds, anc, rings = _fake_buildings()
    m = Map(builds)
    chk('ancients recovered', m.ancient[RADIANT] == anc[RADIANT])
    chk('five high-ground towers per team',
        len(m.hg[RADIANT]) == 5 and len(m.hg[DIRE]) == 5)
    chk('three second-tier towers per team',
        len(m.t2[RADIANT]) == 3 and len(m.t2[DIRE]) == 3)
    chk('tier sets are disjoint',
        not (set(m.hg[RADIANT]) & set(m.t2[RADIANT])))
    try:
        Map([b for b in builds if not (b['name'] == 'tower'
                                       and b['team'] == DIRE
                                       and b['x'] > 11000)][:-1])
        bad = False
    except ValueError:
        bad = True
    chk('a malformed tower census raises instead of guessing', bad)
    kb, _, _ = _fake_buildings(kill=((DIRE, 5), 5.0))
    mk = Map(kb)
    t2_dead = mk.t2[DIRE][0]
    chk('tower death is read from the building samples',
        mk.alive(DIRE, t2_dead, 0.0) and not mk.alive(DIRE, t2_dead, 9.0))

    # --- behaviour on synthetic frames -------------------------------------
    # Put the DIRE team's pid-5 hero (team slot 1 -- unreachable by the shipped
    # scan) on top of a radiant tier-2 tower with two allies beside him.  Armed
    # must answer TRUE, shipped must answer FALSE: that is the UNDER cell.
    t2r = m.t2[RADIANT][0]
    pos = {5: t2r, 6: (t2r[0] + 100, t2r[1]), 7: (t2r[0] - 100, t2r[1]),
           8: (0.0, 0.0), 9: (0.0, 0.0)}
    a, s, ind = evaluate(pos, DIRE, 0.0, m, f, f['ally_radius'])
    chk('dire UNDER: armed TRUE, shipped FALSE', a and not s and not ind)

    # Same geometry hung on pid 9 (the ONE slot the shipped dire scan reads):
    pos9 = {9: t2r, 8: (t2r[0] + 100, t2r[1]), 7: (t2r[0] - 100, t2r[1]),
            6: (0.0, 0.0), 5: (0.0, 0.0)}
    a9, s9, _ = evaluate(pos9, DIRE, 0.0, m, f, f['ally_radius'])
    chk('dire agreement when the pusher is pid 9', a9 and s9)

    # pid 5 dead => the shipped dire loop is guarded out entirely, and armed
    # loses the guard on pid 5 only.
    pos_nog = dict(pos9)
    del pos_nog[5]
    a5, s5, _ = evaluate(pos_nog, DIRE, 0.0, m, f, f['ally_radius'])
    chk('dire shipped guard is pid 5 even though the member is pid 9',
        a5 and not s5)

    # radiant: pid 4 (team slot 5) is the one the shipped scan never reads.
    # The two allies that satisfy pid 4's >= 2 test must themselves sit OUTSIDE
    # every enemy ring, or the shipped scan reaches the same TRUE through one
    # of them -- and the first draft of this assertion did exactly that.
    t2d = m.t2[DIRE][0]
    p4 = (t2d[0] + 1500.0, t2d[1])
    posr = {4: p4, 3: (p4[0] + 1900.0, p4[1]), 2: (p4[0] + 1900.0, p4[1] + 100),
            1: (0.0, 0.0), 0: (0.0, 0.0)}
    ar, sr, _ = evaluate(posr, RADIANT, 0.0, m, f, f['ally_radius'])
    chk('radiant UNDER on pid 4 only', ar and not sr)
    chk('the two allies are themselves outside every enemy ring',
        member_condition(posr, RADIANT, 3, 0.0, m, f, f['ally_radius']) is False
        and member_condition(posr, RADIANT, 2, 0.0, m, f,
                             f['ally_radius']) is False)

    # lone hero at the same tower: the >= 2 ally test refuses both legs.
    lone = {5: t2r, 6: (9000.0, 9000.0), 7: (9100.0, 9000.0),
            8: (9200.0, 9000.0), 9: (9300.0, 9000.0)}
    al, sl, _ = evaluate(lone, DIRE, 0.0, m, f, f['ally_radius'])
    chk('ally minimum refuses a lone pusher', not al and not sl)

    # OVER direction: the misaligned guard. pid 8 is dead (no sample) but the
    # shipped dire scan asks about pid 5 and reads member pid 9 -- so a dead
    # MEMBER can only be reached on radiant, where guard i-1 != member i-2.
    posd = {0: t2d, 1: (t2d[0] + 100, t2d[1]), 2: (t2d[0] - 100, t2d[1]),
            3: (0.0, 0.0)}                       # pid 4 absent == dead
    ad, sd, indd = evaluate(posd, RADIANT, 0.0, m, f, f['ally_radius'])
    chk('radiant shipped reads member pid 0 under guard pid 1', ad and sd)

    posdead = {1: (0.0, 0.0), 2: (0.0, 0.0), 3: (0.0, 0.0), 4: (0.0, 0.0)}
    _, _, ind0 = evaluate(posdead, RADIANT, 0.0, m, f, f['ally_radius'])
    chk('a dead member marks the frame indeterminate, never guessed', ind0)

    # end-to-end on a synthetic game
    snaps = []
    for t in (-30.0, 0.0, 1.0, 2.0):
        for pid, (x, y) in pos.items():
            snaps.append(_snap(pid, t, x, y))
        for pid in range(5):
            snaps.append(_snap(pid, t, -8000.0 + pid, -8000.0))
    rows = scan_game({'snapshots': snaps, 'buildings': builds}, m, f,
                     f['ally_radius'])
    und = [r for r in rows if r['armed'] and not r['shipped']
           and r['team'] == DIRE]
    chk('end-to-end scan finds the planted dire UNDER frames', len(und) == 3)
    chk('pre-horn frames are excluded', all(r['t'] >= 0 for r in rows))

    print('\n%d PASS / %d FAIL' % (ok, fail))
    return 0 if fail == 0 else 1


def pin(tl_dir, manifest, game, t, radius=None):
    """Everything the predicate reads, at one instant, for the frame walk."""
    facts = gate_facts()
    radius = radius or facts['ally_radius']
    _, stamps = load_run(tl_dir, manifest)
    with open(os.path.join(tl_dir, game + '.timeline.json'),
              encoding='utf-8') as fh:
        tl = json.load(fh)
    cand, seed, side = stamps[game]
    mapinfo = Map(tl['buildings'])
    by_ent = index_bodies(tl['snapshots'])
    ros = roster(by_ent)
    print('game %s  seed %s  armed side %s  t=%.1f  ally radius %d'
          % (game, seed, side, t, radius))
    for team in (RADIANT, DIRE):
        pos = {}
        for pid, key in sorted(ros[team].items()):
            p = live_pos(by_ent[key], t)
            if p is not None:
                pos[pid] = p
        leg = 'armed' if team == side_team(side) else 'baseline'
        armed, shipped, ind = evaluate(pos, team, t, mapinfo, facts, radius)
        print('\n  team %d (%s, %s leg): armed=%s shipped=%s ind=%s'
              % (team, 'radiant' if team == RADIANT else 'dire', leg,
                 armed, shipped, ind))
        foe = enemy(team)
        for pid, key in sorted(ros[team].items()):
            p = pos.get(pid)
            if p is None:
                print('    pid %d slot %d %-28s DEAD (no live sample)'
                      % (pid, team_slot(team, pid), key[0]))
                continue
            allies = sum(1 for o, q in pos.items()
                         if o != pid and dist(p[0], p[1], q[0], q[1]) <= radius)
            dt2 = min((dist(p[0], p[1], b[0], b[1])
                       for b in mapinfo.t2[foe] if mapinfo.alive(foe, b, t)),
                      default=float('inf'))
            dhg = min((dist(p[0], p[1], b[0], b[1])
                       for b in mapinfo.hg[foe] if mapinfo.alive(foe, b, t)),
                      default=float('inf'))
            ax, ay = mapinfo.ancient[foe]
            danc = dist(p[0], p[1], ax, ay)
            c = member_condition(pos, team, pid, t, mapinfo, facts, radius)
            print('    pid %d slot %d %-28s allies=%d  d(T2)=%7.0f '
                  ' d(HG)=%7.0f  d(anc)=%7.0f  -> %s'
                  % (pid, team_slot(team, pid), key[0], allies, dt2, dhg,
                     danc, c))
        print('    shipped scan reads (guard,member): %s'
              % shipped_scan(team))
        print('    armed   scan reads (guard,member): %s' % armed_scan(team))
    return 0


def top_episodes(runs, radius, facts, n=10):
    found = []
    for tl_dir, manifest in runs:
        files, stamps = load_run(tl_dir, manifest)
        for base, path in files:
            if base not in stamps:
                continue
            cand, seed, side = stamps[base]
            if not cand or CAND not in cand.split(','):
                continue
            with open(path, encoding='utf-8') as fh:
                tl = json.load(fh)
            rows = scan_game(tl, Map(tl['buildings']), facts, radius)
            if rows is None:
                continue
            for team in (RADIANT, DIRE):
                leg = 'armed' if team == side_team(side) else 'baseline'
                for a, b, k in episodes(rows, team):
                    found.append((k, a, b, base, seed, side, team, leg, tl_dir,
                                  manifest))
    found.sort(reverse=True)
    for row in found[:n]:
        k, a, b, base, seed, side, team, leg, d, _ = row
        print('%4d s  t=%8.1f..%8.1f  %s  seed %s  team %d %s leg'
              % (k, a, b, base, seed, team, leg))
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--run', action='append', default=[],
                    help='<timelines_dir>:<manifest.jsonl>, bound per run')
    ap.add_argument('--radius', type=int, default=None,
                    help='ally radius override (LIMIT 3); default = the tree')
    ap.add_argument('--json', help='write the per-side table here')
    ap.add_argument('--episodes', type=int, default=0,
                    help='print the N longest UNDER episodes and stop')
    ap.add_argument('--pin', help='<game>@<t>: dump every input the predicate '
                                  'reads at that instant, and stop')
    ap.add_argument('--selfcheck', action='store_true')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if not a.run:
        ap.error('--run is required')
    if a.pin:
        game, _, ts = a.pin.partition('@')
        for spec in a.run:
            tl_dir, _, manifest = spec.partition(':')
            if os.path.exists(os.path.join(tl_dir, game + '.timeline.json')):
                return pin(tl_dir, manifest, game, float(ts), a.radius)
        sys.stderr.write('game %s not found under any --run\n' % game)
        return 2
    facts = gate_facts()
    for k in ('ally_radius', 'ally_min', 't2_radius', 'hg_radius',
              'ancient_radius'):
        if facts[k] is None:
            sys.stderr.write('source fact %s could not be read -- refusing\n' % k)
            return 2
    runs = []
    for spec in a.run:
        tl_dir, _, manifest = spec.partition(':')
        if not manifest:
            ap.error('--run needs <timelines_dir>:<manifest.jsonl>')
        runs.append((tl_dir, manifest))
    radius = a.radius or facts['ally_radius']
    if a.episodes:
        top_episodes(runs, radius, facts, a.episodes)
        return 0
    tally, per_game, games, errors = aggregate(runs, radius, facts)
    report(tally, games, radius, facts, errors)
    if a.json:
        with open(a.json, 'w', encoding='utf-8') as fh:
            json.dump({'radius': radius, 'games': games, 'facts': facts,
                       'tally': {'%s/%s' % k: dict(v) for k, v in tally.items()},
                       'per_game': [(b, s, sd, {'/'.join(map(str, k)): v
                                                for k, v in g.items()})
                                    for b, s, sd, g in per_game]},
                      fh, indent=1, sort_keys=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())

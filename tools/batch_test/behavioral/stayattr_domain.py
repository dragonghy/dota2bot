#!/usr/bin/env python3
"""Execution-verification probe for `stayattr` -- the ATTRIBUTION narrowing of
the turbo "don't walk home, heal here" veto (jmz_func.lua J.ShouldStayAndRegen).
Read-only, offline; consumes dumper timelines.  Touches no AWS billable thing.

WHAT THE LEVER ACTUALLY DOES (jmz_func.lua:5115-5120, read off the source)
--------------------------------------------------------------------------
    if bot:WasRecentlyDamagedByAnyHero( 3.0 )
        and ( not J.IsSoakCandidate( 'stayattr' )
            or J.HasNearbyHeroDamager( bot, 3000, 3.0 ) )
    then
        return false
    end

Unarmed, the second conjunct is the literal `true`, so the clause reduces to
"recently damaged by a hero => never stay".  Armed, the veto additionally
requires that the damager still be NEARBY (an enemy inside 3000 that the bot
can see and that damaged it in the last 3 s).  `stayattr` can therefore only
REMOVE vetoes: the armed TRUE set is a strict superset of the shipped one, and
the direction is fixed by construction rather than by comment.

THE ARMED-ONLY DOMAIN, which is what this tool counts
-----------------------------------------------------
The two reads differ on exactly the frames where the first conjunct holds and
the second does not, and where nothing FURTHER down the function vetoes anyway
(a frame the 1200 ring kills is not a frame `stayattr` can move):

    DOMAIN := alive
          AND hp_pct in [0.18, 0.75]              <- the band above line 5083
          AND recently damaged by a hero (3.0 s)  <- first conjunct TRUE
          AND no enemy hero damager inside 3000   <- second conjunct FALSE
          AND no enemy hero inside 1200           <- the ring at line 5121
          AND an observable regen source          <- see CERTAIN/AMBIGUOUS

On a DOMAIN frame the shipped read returns false and the armed read returns
true.  Every other frame in the game is one where the two reads AGREE, and a
behavioural difference seen there is somebody else's lever.

⭐ WHY THIS ID IS BUYABLE FROM THE DUMP AND `creepthink` WAS NOT.
The 2026-09-05T09:38Z round ruled `creepthink` INDETERMINATE structurally: that
gate decides whether `Think()` reaches a line that issues a command, and the
COMMAND STREAM IS NOT IN THE DUMP.  `stayattr` is the opposite shape.  Every
clause it reads is a dumped quantity -- `hp_pct` from snapshots, hero-attributed
damage from `DAMAGE` events carrying `actor_hero`, both distances from the
snapshot positions -- and so is the decision it changes, because "stay here" and
"walk home" are different POSITIONS ten seconds later.  The distinction is not
"detector vs economy" and not "positional vs not": it is whether the quantity
the gate moves ever reaches a dumped field.

⛔ THE OUTCOME SUBSTITUTION THIS TOOL REFUSES (batch-desk's honesty boundary 4,
registered in W48_wave.json against this very cell).  The claim condition (a)
buys is that the DECISION at instant t differs, NOT that the bot which stayed
lived through the next ten seconds.  So this tool scores displacement and the
regen action, and it does not compute -- and must never be backed by -- survival
rate, win rate, or deaths.  A cell backed by an outcome is void.

WHERE THIS TOOL UNDER-COUNTS, ALWAYS IN THE SAME DIRECTION
-----------------------------------------------------------
Three clauses are read on GROUND TRUTH where the engine reads them on VISION,
and one is not observable at all.  Every one of the four errs the same way:

  1. `J.GetNearbyHeroes( bot, r, true, ... )` returns only enemies the bot can
     SEE.  The dump has true world positions.  A damager standing at 2000 u
     inside fog is invisible to the engine (=> armed falls through, domain
     frame) and visible to this tool (=> scored as "veto applies", frame
     dropped).  MISSES domain frames; cannot invent them.
  2. Same for the 1200 ring: an unseen enemy inside 1200 drops a frame here
     that the engine would have admitted.  Misses only.
  3. `bot:GetGold()` is NOT in the dump (snapshots carry `net_worth`, never
     liquid gold).  The final clause is `bHasFlask OR gold >= 90`, so a frame
     whose regen source is unobservable may still be admitted by the engine.
     Those frames are counted as AMBIGUOUS and are NOT scored.  Misses only.
  4. The `IsItemAvailable` half of `bHasFlask` reaches the courier and the
     stash; the snapshot `items` row is the six usable slots plus backpack.
     Misses only.

Consequence, and it is the same asymmetry `fieldsip_domain` runs on: the scored
domain is a strict SUBSET of the engine's.  An EMPTY scored domain is therefore
DOMAIN-NOT-REACHED and never "tested, no effect"; a PRESENT domain frame is
real.  Condition (a) is a positive claim, and a subset suffices for one.

Batch-desk priced the offline domain before the wave (109 fixtures / 1012 live
hero frames: 95 frames trip the veto, 88 of them with the damager inside 3000)
=> the lever is inert on ~93% of the frames that reach the veto BY
CONSTRUCTION.  A small on-wave domain is the expected shape, not a defect.

REGISTERED TRAPS (all inherited, none re-derived)
-------------------------------------------------
  * Illusions and duplicate entity streams: `entities.frames_by_hero`, not a
    name filter.  A name filter returned 21 rows for one hero at one instant
    on 2026-09-05 (`010205_slot7` luna t=1348.5).
  * The `vengefulspirit` / `vengeful_spirit` join (GH #303): the snapshot and
    event streams DISAGREE on the spelling, so every cross-stream lookup goes
    through `HeroMap` / `hkey`, never through `canon(ev['target']) == hero`.
    This tool joins DAMAGE actors and targets to snapshot rows on every frame,
    so it would have been a full-hero silent zero.
  * Corpses: `alive_interp` with the death-EVENT anchor, never `hp > 0` on an
    interpolated blend (the blend is what manufactures the positive hp).
  * Warm-up games: a game whose `.analysis.json` `script_version` does not
    start with `mirror:` carries NO leg and is refused for any armed/baseline
    reading.  It may still be priced for domain reach, which this tool reports
    in a SEPARATE column that never pools with the scored one.
  * Iron rule 4(i-a)/(i-b): this is a COUNT-type quantity whose side bias is
    NOT eliminated (no per-seed 50/50 swap inside the estimator), so the ab and
    ba stratum READINGS are printed separately and opposite signs across the
    two strata read as NOISE and do not enter a conclusion.  Rule 4(ii): no
    medians on it -- the mean plus the distribution, or a share above a stated
    threshold.
  * Iron rule 4(i-d): pooling across seeds is the arithmetic mean of per-seed
    swap-averages, NEVER a game-count weighting.

Exit codes: 0 ran clean, 2 could not run (NOT a pass), 3 nothing to report on.
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402

# --- the source's own constants, transcribed with their line numbers ---------
HP_LO, HP_HI = 0.18, 0.75          # jmz_func.lua:5083
DAMAGE_WINDOW_S = 3.0              # jmz_func.lua:5115 / :5117
DAMAGER_RADIUS = 3000.0            # jmz_func.lua:5117
RING_RADIUS = 1200.0               # jmz_func.lua:5121
# jmz_func.lua:5122-5124 -- the observable half of `bHasFlask`.
REGEN_ITEMS = ('item_flask', 'item_tango', 'item_tango_single')
REGEN_MODIFIERS = ('modifier_flask_healing', 'modifier_tango_heal')

# Decision-readout window.  Ten seconds is the batch-desk cell's own phrasing
# ("it stays put ... where the baseline goes home"); it is a DECISION readout
# and deliberately short of any outcome horizon.
READOUT_S = 10.0
# Displacement toward the bot's own fountain that counts as "went home".  A
# turbo hero walks ~300 u/s, so 600 u is ~2 s of committed walking -- well
# above sampling jitter and well below a full trip.
HOME_PROGRESS_U = 600.0
# A position step larger than this between two ~1 s samples is not walking.
# Turbo movement speeds top out near 550 u/s even buffed, so 3000 u leaves a
# wide margin over the fastest legitimate walk and still catches a TP, whose
# jump is map-scale (the W48 crystal_maiden case moved ~10,200 u in one step).
TP_JUMP_U = 3000.0
# Consecutive domain frames closer than this belong to one decision episode.
EPISODE_GAP_S = 2.0


def _dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def fountains(timeline):
    """{team: (x, y)} from the EARLIEST snapshot tick, per team.

    Derived, never hardcoded: the heroes stand on their own fountain before the
    horn, so the per-team centroid of the first sampled tick IS the fountain.
    A hardcoded (-7200,-6600) would also be a silent lie on any future map
    change, and the centroid costs one pass.
    """
    first = {}
    for s in timeline.get('snapshots', ()):
        tm = s.get('team')
        if tm is None:
            continue
        t0 = first.setdefault(tm, [s['t'], []])
        if s['t'] < t0[0]:
            first[tm] = [s['t'], [s]]
        elif s['t'] == t0[0]:
            t0[1].append(s)
    out = {}
    for tm, (_t, ss) in first.items():
        if ss:
            out[tm] = (sum(s['x'] for s in ss) / len(ss),
                       sum(s['y'] for s in ss) / len(ss))
    return out


def damage_index(timeline):
    """{victim hkey: [(t, attacker hkey)]} for HERO-attributed damage only.

    Keyed with `hkey` on BOTH sides: the event stream spells Vengeful Spirit
    without the underscore that the snapshot stream inserts (GH #303), and this
    index is joined against snapshot rows on every frame.
    """
    out = collections.defaultdict(list)
    for e in timeline.get('events', ()):
        if e.get('type') != 'DAMAGE' or not e.get('actor_hero'):
            continue
        if not e.get('target_hero'):
            continue
        a = entities.hkey(e.get('actor'))
        v = entities.hkey(e.get('target'))
        if not a or not v or a == v:      # self-damage is not "by a hero"
            continue
        out[v].append((e['t'], a))
    for v in out:
        out[v].sort()
    return out


def regen_modifier_spans(timeline):
    """{hero hkey: [(t_add, t_remove)]} for the two heal modifiers.

    An ADD with no matching REMOVE is left open to the end of the game rather
    than dropped: an unterminated heal is still a heal that was running.
    """
    open_at = collections.defaultdict(dict)
    spans = collections.defaultdict(list)
    tmax = 0.0
    for e in timeline.get('events', ()):
        tmax = max(tmax, e.get('t', 0.0))
        typ = e.get('type')
        if typ not in ('MODIFIER_ADD', 'MODIFIER_REMOVE'):
            continue
        name = (e.get('inflictor') or e.get('value_name') or '')
        if name not in REGEN_MODIFIERS:
            continue
        h = entities.hkey(e.get('target'))
        if not h:
            continue
        if typ == 'MODIFIER_ADD':
            open_at[h].setdefault(name, e['t'])
        else:
            t0 = open_at[h].pop(name, None)
            if t0 is not None:
                spans[h].append((t0, e['t']))
    for h, pend in open_at.items():
        for _n, t0 in pend.items():
            spans[h].append((t0, tmax))
    for h in spans:
        spans[h].sort()
    return spans


def _has_regen_source(snap, spans, t):
    """The OBSERVABLE half of `bHasFlask` (jmz_func.lua:5122-5124)."""
    for it in (snap.get('items') or ()):
        if it in REGEN_ITEMS:
            return True
    for (a, b) in spans:
        if a <= t <= b:
            return True
    return False


def scan_game(timeline):
    """Domain frames + their decision readout for one game.

    Returns (rows, stats).  A row is one DOMAIN FRAME; `episodes` in stats
    collapses consecutive frames into decisions.
    """
    frames, team = entities.frames_by_hero(timeline)
    deaths = entities.death_times(timeline)
    dmg = damage_index(timeline)
    spans = regen_modifier_spans(timeline)
    fount = fountains(timeline)

    heroes = list(frames.keys())
    rows = []
    stats = collections.Counter()

    for h in heroes:
        hk = entities.hkey(h)
        my_team = team.get(h)
        enemies = [e for e in heroes if team.get(e) not in (None, my_team)]
        hits = dmg.get(hk, [])
        if not hits:
            continue
        my_spans = spans.get(hk, [])
        home = fount.get(my_team)

        for snap in frames[h]:
            t = snap['t']
            if t < entities.HORN_T:
                continue
            hp = snap.get('hp_pct')
            if hp is None or not (HP_LO <= hp <= HP_HI):
                continue
            if not entities.alive_at(frames[h], deaths.get(h), t):
                continue

            # clause 1: WasRecentlyDamagedByAnyHero(3.0)
            recent = [(ht, ha) for (ht, ha) in hits
                      if t - DAMAGE_WINDOW_S < ht <= t]
            if not recent:
                continue
            stats['veto_reached'] += 1
            recent_attackers = {ha for (_ht, ha) in recent}

            # clause 2: HasNearbyHeroDamager(bot, 3000, 3.0) -- must be FALSE
            damager_near = False
            ring_enemy = False
            for e in enemies:
                es = entities.alive_interp(frames[e], t, deaths.get(e))
                if es is None:
                    continue
                d = _dist(snap['x'], snap['y'], es['x'], es['y'])
                if d <= RING_RADIUS:
                    ring_enemy = True
                if d <= DAMAGER_RADIUS and entities.hkey(e) in recent_attackers:
                    damager_near = True
            if damager_near:
                stats['veto_stands_damager_near'] += 1
                continue
            # clause 3: the 1200 ring at :5121 vetoes independently
            if ring_enemy:
                stats['dropped_ring_enemy'] += 1
                continue
            # clause 4: the observable half of bHasFlask
            if not _has_regen_source(snap, my_spans, t):
                stats['ambiguous_no_observable_regen'] += 1
                continue

            stats['domain_frames'] += 1
            row = _readout(snap, frames[h], deaths.get(h), my_spans,
                           home, h, t, sorted(recent_attackers))
            row['team'] = my_team
            rows.append(row)
    stats['episodes'] = _count_episodes(rows)
    return rows, stats


def _tp_home(hero_frames, home, t):
    """Did this hero TP out during [t, t+READOUT_S]?  Two signals, both required.

    ⭐ WHY THIS FIELD EXISTS, and it was NOT in the first cut: reading the
    decision as "distance to my own fountain fell by more than 600 u" makes a
    TELEPORT and a CROSS-MAP WALK the same observation, and they are not the
    same decision.  Found frame by frame on W48 (2026-09-05), three domain
    frames read side by side:

      * `123858_slot1__4bf01d` crystal_maiden t=269.5 -- stands still at
        (6578,-3804) through 272.5 while `tp_cd` steps 0.0 -> 39.3, then the
        very next sample is (6911,6332).  That is a TP, and it is the shipped
        "recently damaged => go home" branch caught in the act.
      * `122448_slot1__4bf01d` slardar t=226.9 -- a steady ~270 u/s walk with
        `tp_cd` flat at 0.0 the whole way.  Also going home, but by walking.
      * `122457_slot1__272131` axe t=383.9 -- a steady walk that closes 2066 u
        on the fountain while crossing the map diagonally.  Whether that is a
        retreat or a rotation is NOT settled by the displacement alone.

    So `went_home` (displacement) stays, and `tp_home` is the airtight subset.
    A reading that needs to be airtight cites `tp_home`; one that cites
    `went_home` inherits the axe case's ambiguity and must say so.

    Signal 1: `tp_cd` steps UP from ~0 (a TP was consumed -- an unused scroll
    reads 0.0 forever, as slardar's row shows).  Signal 2: a position
    discontinuity larger than any hero can walk in one sample, which CLOSES
    more than HOME_PROGRESS_U on the fountain.  Requiring both is what keeps a
    respawn (which also jumps to the fountain, but consumes no TP) out of this
    field -- and the death anchor in `alive_interp` is the other half of that
    guard.

    ⚠️ THE SECOND SIGNAL WAS TOO WEAK IN THE FIRST CUT, and a real frame caught
    it: `122457_slot1__272131` necrolyte t=264.9 TPs from (-4854,5095) to
    (4890,-6006) -- corner to opposite corner, a ROTATION, not a trip home --
    and the first cut scored it `tp_home` because the test was merely "ends
    nearer the fountain than it starts", which that jump satisfies by 329 u out
    of ~11,900 purely because both corners are about equally far from the
    Radiant fountain.  Requiring the jump to CLOSE a real distance (the same
    600 u the walking readout uses) rejects it and keeps the crystal_maiden
    case, whose jump closes ~10,050 u.  The false positive landed on a WARM-UP
    frame and so never entered a scored reading -- but it would have, on the
    next wave, silently and in the direction that inflates the baseline leg.
    """
    if home is None:
        return False
    win = [s for s in hero_frames if t <= s['t'] <= t + READOUT_S]
    if len(win) < 2:
        return False
    consumed = any(win[i]['tp_cd'] <= 0.5 < win[i + 1]['tp_cd']
                   for i in range(len(win) - 1)
                   if win[i].get('tp_cd') is not None
                   and win[i + 1].get('tp_cd') is not None)
    if not consumed:
        return False
    for i in range(len(win) - 1):
        a, b = win[i], win[i + 1]
        if _dist(a['x'], a['y'], b['x'], b['y']) <= TP_JUMP_U:
            continue
        closed = (_dist(a['x'], a['y'], home[0], home[1])
                  - _dist(b['x'], b['y'], home[0], home[1]))
        if closed > HOME_PROGRESS_U:
            return True
    return False


def _readout(snap, hero_frames, hero_deaths, my_spans, home, hero, t, attackers):
    """The DECISION readout at a domain frame.  No outcome quantity here."""
    later = entities.alive_interp(hero_frames, t + READOUT_S, hero_deaths)
    d0 = d1 = None
    if home is not None:
        d0 = _dist(snap['x'], snap['y'], home[0], home[1])
        if later is not None:
            d1 = _dist(later['x'], later['y'], home[0], home[1])
    progress = None if (d0 is None or d1 is None) else (d0 - d1)
    drank = any(t <= a <= t + READOUT_S for (a, _b) in my_spans)
    return {
        'hero': hero, 't': round(t, 1), 'hp_pct': snap.get('hp_pct'),
        'attackers': attackers,
        'dist_home_t': None if d0 is None else round(d0, 1),
        'dist_home_t_plus': None if d1 is None else round(d1, 1),
        'home_progress': None if progress is None else round(progress, 1),
        'went_home': None if progress is None else bool(progress > HOME_PROGRESS_U),
        'tp_home': _tp_home(hero_frames, home, t),
        'started_regen': drank,
        'readout_truncated': later is None,
    }


def _count_episodes(rows):
    per = collections.defaultdict(list)
    for r in rows:
        per[r['hero']].append(r['t'])
    n = 0
    for _h, ts in per.items():
        ts.sort()
        prev = None
        for t in ts:
            if prev is None or (t - prev) > EPISODE_GAP_S:
                n += 1
            prev = t
    return n


RADIANT, DIRE = 2, 3
ARMED_TEAM = {'radiant': RADIANT, 'dire': DIRE}


def leg_of(analysis_path):
    """(side, cand, seed) from a game's `.analysis.json` stamp.

    ⭐ `side` IS NOT `ab`/`ba` AND IS NOT A LEG.  The stamp's last token is
    `radiant` or `dire`, and it names WHICH PHYSICAL TEAM CARRIES THE ARMED
    CANDIDATE IN THIS ONE GAME.  Both legs live inside a single mirrored game:
    the named team runs the armed read, the other team runs the shipped one,
    off the same draft.  Reading `radiant` as "the ab leg" would silently
    halve the corpus and compare a game against a different game.  This is the
    same convention `sweep_run.sh:133-142` uses to tag `on_candidate_side`, and
    it is imported from there rather than re-derived.

    The physical side is still the STRATUM for iron rule 4(i-a): a `radiant`
    game and a `dire` game are the two strata whose readings must be reported
    separately, because this estimator does not cancel side bias internally.

    A `script_version` that does not start with `mirror:` is a WARM-UP: no
    team is armed, so no armed/baseline reading exists.  Returning None is
    what keeps an unstamped game out of every such reading.
    """
    try:
        with open(analysis_path) as f:
            sv = json.load(f).get('script_version', '')
    except Exception:
        return (None, None, None)
    if not sv.startswith('mirror:'):
        return (None, None, None)
    parts = sv.split(':')
    side = parts[-1]
    if side not in ARMED_TEAM:
        return (None, None, None)
    seed = parts[-2].lstrip('s') if len(parts) >= 3 else None
    cand = ':'.join(parts[1:-2]) if len(parts) >= 4 else None
    return (side, cand, seed)


def armed_in_stamp(analysis_path, cand_id='stayattr'):
    """Is `cand_id` actually in this game's armed string?

    Cheap, and it is the difference between "the lever was off" and "the lever
    did nothing".  A wave whose string does not carry the id cannot buy its
    condition (a) at all, and that must not read as a silent zero.
    """
    try:
        with open(analysis_path) as f:
            sv = json.load(f).get('script_version', '')
    except Exception:
        return None
    if not sv.startswith('mirror:'):
        return None
    body = ':'.join(sv.split(':')[1:-2])
    return cand_id in [x.strip() for x in body.split(',')]


# --------------------------------------------------------------------------
# selfcheck: synthetic timelines, each isolating ONE clause.
#
# The rule the 2026-09-05T06:57Z round paid for: a control for a rejection
# clause must leave every OTHER rejection clause UNSATISFIED, or the stand
# reports CAUGHT for the wrong reason (it was covered twice, not covered once).
# --------------------------------------------------------------------------
def _mk(snaps, events):
    return {'snapshots': snaps, 'events': events, 'buildings': [], 'creeps': [],
            'wards': [], 'game': {}}


def _hero(idx, name, teamn, ts, x, y, hp, items=(), tp=0):
    return [{'t': t, 'hero': name, 'idx': idx, 'team': teamn, 'player_id': idx,
             'x': (x(t) if callable(x) else x), 'y': y, 'hp': int(600 * hp),
             'hp_pct': hp, 'mp': 100, 'max_mp': 100, 'mp_pct': 1.0, 'level': 6,
             'items': list(items) + [''] * (9 - len(items)), 'abilities': [],
             'tp_cd': (tp(t) if callable(tp) else tp), 'tp_cdlen': 60,
             'net_worth': 1000} for t in ts]


def _dmg(t, actor, target):
    return {'t': t, 'type': 'DAMAGE', 'actor': actor, 'target': target,
            'inflictor': 'dota_unknown', 'value': 50,
            'actor_hero': True, 'target_hero': True}


def selfcheck():
    ok = fail = 0

    def check(label, cond):
        nonlocal ok, fail
        if cond:
            ok += 1
        else:
            fail += 1
            print('  FAIL %s' % label)

    ts = [-60.0] + [float(i) for i in range(0, 40)]
    VICTIM, ENEMY = 'npc_dota_hero_lion', 'npc_dota_hero_axe'

    def world(enemy_x, victim_hp=0.5, items=('item_flask',), dmg_t=19.0,
              victim_name=VICTIM, dmg_target=None):
        snaps = (_hero(1, victim_name, 2, ts, -3000, -3000, victim_hp, items)
                 + _hero(2, ENEMY, 3, ts, enemy_x, -3000, 1.0))
        return _mk(snaps, [_dmg(dmg_t, ENEMY, dmg_target or victim_name)])

    # 1. POSITIVE: damager withdrew past 3000 -> armed-only domain frame.
    rows, st = scan_game(world(enemy_x=6000))
    check('1a positive domain non-empty', st['domain_frames'] > 0)
    check('1b positive names the attacker',
          rows and rows[0]['attackers'] == ['axe'])
    # The window is HALF-OPEN on the left and CLOSED on the right, exactly as
    # `t - 3.0 < ht <= t` is written: a hit at 19.0 admits t=19,20,21 and NOT
    # t=22.  Writing this bound as `19.0 < t` (the first cut here) is off by
    # the whole frame the damage lands on.
    check('1c positive is inside the damage window',
          rows and sorted({r['t'] for r in rows}) == [19.0, 20.0, 21.0])

    # 2. Damager INSIDE 3000 -> the veto stands; armed == shipped; no domain.
    #    Every other rejection clause is left unsatisfied here: hp is in band,
    #    a flask is in the slot, and 2500 u is outside the 1200 ring.
    _r, st = scan_game(world(enemy_x=-500 + 0))       # 2500 u away, ring clear
    check('2 damager inside 3000 -> no domain', st['domain_frames'] == 0)
    check('2 counted as veto-stands', st['veto_stands_damager_near'] > 0)

    # 3. Enemy inside the 1200 ring, and NOT the damager (a different hero did
    #    the damage from off-map) -> dropped by :5121 alone.
    snaps = (_hero(1, VICTIM, 2, ts, -3000, -3000, 0.5, ('item_flask',))
             + _hero(2, ENEMY, 3, ts, -2500, -3000, 1.0)
             + _hero(3, 'npc_dota_hero_zuus', 3, ts, 9000, 9000, 1.0))
    _r, st = scan_game(_mk(snaps, [_dmg(19.0, 'npc_dota_hero_zuus', VICTIM)]))
    check('3 ring enemy alone drops the frame', st['domain_frames'] == 0)
    check('3 counted as ring drop', st['dropped_ring_enemy'] > 0)

    # 4. HP out of band, everything else admissible.
    for hp, label in ((0.10, 'below floor'), (0.90, 'above ceiling')):
        _r, st = scan_game(world(enemy_x=6000, victim_hp=hp))
        check('4 hp %s -> no domain' % label, st['domain_frames'] == 0)
        check('4 hp %s -> veto never reached' % label, st['veto_reached'] == 0)

    # 5. No observable regen source -> AMBIGUOUS, not scored (gold unobservable).
    _r, st = scan_game(world(enemy_x=6000, items=()))
    check('5 no regen source -> not scored', st['domain_frames'] == 0)
    check('5 no regen source -> ambiguous',
          st['ambiguous_no_observable_regen'] > 0)

    # 6. ANTI-VACUUM: no hero damage at all -> the veto is never reached, so
    #    `stayattr` cannot move this frame even though it looks admissible.
    snaps = _hero(1, VICTIM, 2, ts, -3000, -3000, 0.5, ('item_flask',)) \
        + _hero(2, ENEMY, 3, ts, 6000, -3000, 1.0)
    _r, st = scan_game(_mk(snaps, []))
    check('6 no hero damage -> no domain', st['domain_frames'] == 0)
    check('6 no hero damage -> veto never reached', st['veto_reached'] == 0)

    # 7. ANTI-VACUUM: an empty timeline reads 0 and does not throw.
    rows, st = scan_game(_mk([], []))
    check('7 empty timeline -> 0 domain', st['domain_frames'] == 0 and not rows)

    # 8. THE GH #303 JOIN.  Snapshots spell it `vengeful_spirit`; the DAMAGE
    #    event spells it `vengefulspirit`.  Under a canon() join this hero is a
    #    silent zero -- the whole hero, not a rounding error.
    w = world(enemy_x=6000, victim_name='npc_dota_hero_vengeful_spirit',
              dmg_target='npc_dota_hero_vengefulspirit')
    _r, st = scan_game(w)
    check('8 cross-spelling victim still joins', st['domain_frames'] > 0)
    w = _mk(_hero(1, VICTIM, 2, ts, -3000, -3000, 0.5, ('item_flask',))
            + _hero(2, 'npc_dota_hero_vengeful_spirit', 3, ts, -500, -3000, 1.0),
            [_dmg(19.0, 'npc_dota_hero_vengefulspirit', VICTIM)])
    _r, st = scan_game(w)
    check('8 cross-spelling ATTACKER still vetoes',
          st['domain_frames'] == 0 and st['veto_stands_damager_near'] > 0)

    # 9. Decision readout: walking home vs standing still, same domain frame.
    #
    # ⚠️ The fountain is DERIVED (the team's pre-horn centroid), so a fixture
    # that means "walks home" has to put the hero somewhere else at t<0 and
    # then move him back toward that point.  The first cut of this control
    # walked the hero from -3000 to -6000 while the derived fountain sat at
    # -3000, i.e. it walked AWAY and asserted `went_home` -- the control was
    # wrong, not the tool.  Fountain here: (-7000, -3000).
    ts9 = [-60.0] + [float(i) / 2 for i in range(0, 80)]

    def lane(t):
        return -7000.0 if t < 0 else -3000.0

    def homeward(t):
        return lane(t) if t < 19 else max(-7000.0, -3000.0 - 300.0 * (t - 19))

    still = _mk(_hero(1, VICTIM, 2, ts9, lane, -3000, 0.5, ('item_flask',))
                + _hero(2, ENEMY, 3, ts9, 6000, -3000, 1.0),
                [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(still)
    check('9a standing still is not went_home',
          rows and rows[0]['went_home'] is False)
    check('9a standing still has ~zero progress',
          rows and abs(rows[0]['home_progress']) < 1.0)
    walk = _mk(_hero(1, VICTIM, 2, ts9, homeward, -3000, 0.5, ('item_flask',))
               + _hero(2, ENEMY, 3, ts9, 6000, -3000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(walk)
    check('9b walking at the fountain is went_home',
          rows and rows[0]['went_home'] is True)
    check('9c readout carries the signed progress',
          rows and rows[0]['home_progress'] > HOME_PROGRESS_U)
    # 9d ANTI-VACUUM for the readout: the SAME geometry walked the other way
    # must read went_home FALSE, or `went_home` is just "the hero moved".
    away = _mk(_hero(1, VICTIM, 2, ts9,
                     lambda t: lane(t) if t < 19 else -3000.0 + 300.0 * (t - 19),
                     -3000, 0.5, ('item_flask',))
               + _hero(2, ENEMY, 3, ts9, 9000, -3000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(away)
    check('9d walking AWAY is not went_home',
          rows and rows[0]['went_home'] is False
          and rows[0]['home_progress'] < 0)

    # 11. TP vs walk vs respawn-lookalike -- the discrimination W48's frames
    #     forced.  All three share the SAME domain frame and the SAME endpoint;
    #     only the mechanism differs, so each control isolates one signal.
    # The fountain is the pre-horn centroid, so t<0 has to sit ON it (-7000)
    # for "-7000 is home" to be true.  The first cut of this control put t<0 at
    # -3000, which made the derived fountain -3000 and turned the TP into a
    # trip AWAY -- the same mistake 9b paid for, made a second time.
    def jump(t):                       # sits in lane, is at the fountain from 22
        return -7000.0 if t < 0 else (-3000.0 if t < 22 else -7000.0)

    def spent(t):                      # a TP consumed at t=20
        return 0.0 if t < 20 else 40.0

    w11 = _mk(_hero(1, VICTIM, 2, ts9, jump, -3000, 0.5, ('item_flask',), spent)
              + _hero(2, ENEMY, 3, ts9, 9000, -3000, 1.0),
              [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(w11)
    check('11a TP: jump + consumed scroll -> tp_home',
          rows and rows[0]['tp_home'] is True and rows[0]['went_home'] is True)
    # 11b RESPAWN LOOKALIKE: identical jump to the fountain, NO scroll spent.
    #     This is the control that keeps a death out of `tp_home`; without the
    #     tp_cd conjunct it would read exactly like 11a.
    w11b = _mk(_hero(1, VICTIM, 2, ts9, jump, -3000, 0.5, ('item_flask',), 0)
               + _hero(2, ENEMY, 3, ts9, 9000, -3000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(w11b)
    check('11b jump with no scroll spent is NOT tp_home',
          rows and rows[0]['tp_home'] is False)
    # 11c WALK: a scroll IS spent (a bought TP sitting on cooldown for any
    #     reason) but the hero only walks.  Isolates the jump conjunct.
    w11c = _mk(_hero(1, VICTIM, 2, ts9, homeward, -3000, 0.5, ('item_flask',), spent)
               + _hero(2, ENEMY, 3, ts9, 9000, -3000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(w11c)
    check('11c walking home is went_home but NOT tp_home',
          rows and rows[0]['went_home'] is True
          and rows[0]['tp_home'] is False)
    # 11d ANTI-VACUUM: a jump AWAY from the fountain with a scroll spent is not
    #     a trip home, so the direction conjunct has to be doing work.
    def outjump(t):
        return -7000.0 if t < 0 else (-3000.0 if t < 22 else 3000.0)
    w11d = _mk(_hero(1, VICTIM, 2, ts9, outjump, -3000, 0.5, ('item_flask',), spent)
               + _hero(2, ENEMY, 3, ts9, 9000, -3000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(w11d)
    check('11d jump AWAY is not tp_home', rows and rows[0]['tp_home'] is False)
    # 11e THE NECROLYTE CONTROL, transcribed from the real frame that broke the
    #     first cut: a cross-map ROTATION TP whose endpoints are near-equidistant
    #     from the hero's own fountain, so it closes a trivial distance.  Under
    #     "ends nearer than it starts" this reads tp_home; under "closes more
    #     than HOME_PROGRESS_U" it does not.  Every other clause is left
    #     satisfied, so this control can only be answered by the distance rule.
    #     Fountain here is (-6700,-6700), matching the source frame.
    ts11 = [-60.0] + [float(i) / 2 for i in range(0, 80)]

    def rot_x(t):
        return -6700.0 if t < 0 else (-4854.0 if t < 22 else 4890.0)

    def rot_y(t):
        return -6700.0 if t < 0 else (5095.0 if t < 22 else -6006.0)

    snaps11 = _hero(1, VICTIM, 2, ts11, rot_x, 0, 0.5, ('item_flask',), spent)
    for s in snaps11:                     # _hero takes a scalar y; set it here
        s['y'] = rot_y(s['t'])
    w11e = _mk(snaps11 + _hero(2, ENEMY, 3, ts11, 30000, 30000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(w11e)
    check('11e cross-map ROTATION TP is not tp_home',
          rows and rows[0]['tp_home'] is False)
    check('11e ... and the control really is a >3000u jump on a domain frame',
          rows and abs(_dist(-4854.0, 5095.0, 4890.0, -6006.0)) > TP_JUMP_U)
    # 11f ISOLATES THE JUMP CONJUNCT, and it exists because the mutation stand
    #     said so: with only 11a-11e, deleting the jump test entirely SURVIVED,
    #     because no control walked fast enough to close HOME_PROGRESS_U inside
    #     ONE sample.  Here the samples are 2 s apart and the hero walks 350 u/s
    #     => 700 u per step, over the 600 u progress bar and far under the
    #     3000 u jump bar.  A scroll IS spent, so signal 1 is satisfied and only
    #     the jump conjunct can reject this.
    ts11f = [-60.0] + [float(2 * i) for i in range(0, 20)]

    def slow_home(t):
        return -7000.0 if t < 0 else (-3000.0 if t < 20
                                      else max(-7000.0, -3000.0 - 350.0 * (t - 20)))

    # ⚠️ The scroll must be spent INSIDE the readout window, not before it.
    #     At this 2 s sampling the only domain frame is t=20, so a spend at
    #     t=20 is already on cooldown at the window's first sample and
    #     `consumed` short-circuits to False -- which made the control pass for
    #     the wrong reason and let M8b survive a second time.  Spend at 22.
    def spent_late(t):
        return 0.0 if t < 22 else 40.0

    w11f = _mk(_hero(1, VICTIM, 2, ts11f, slow_home, -3000, 0.5,
                     ('item_flask',), spent_late)
               + _hero(2, ENEMY, 3, ts11f, 30000, -3000, 1.0),
               [_dmg(19.0, ENEMY, VICTIM)])
    rows, _st = scan_game(w11f)
    check('11f a fast WALK closing >600u per sample is not tp_home',
          rows and rows[0]['tp_home'] is False and rows[0]['went_home'] is True)

    # 10. Warm-up refusal: an unstamped game yields no leg.
    import tempfile
    with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
        json.dump({'script_version': '54b839d1'}, f)
        p = f.name
    check('10a bare-sha stamp -> no side', leg_of(p) == (None, None, None))
    check('10a bare-sha stamp -> id unknowable', armed_in_stamp(p) is None)
    with open(p, 'w') as f:
        json.dump({'script_version': 'mirror:pullcad,stayattr:s5025:radiant'}, f)
    check('10b mirror stamp -> side radiant + seed',
          leg_of(p) == ('radiant', 'pullcad,stayattr', '5025'))
    check('10b stamp carries the id', armed_in_stamp(p) is True)
    # 10c ANTI-VACUUM for the id check: a SUBSTRING of another id must not
    # count as this id being armed.  `stayattr` is a substring of nothing in
    # the live string today, but `stayfield` vs `stayfield2` is exactly the
    # shape that makes a naive `in sv` read true forever.
    with open(p, 'w') as f:
        json.dump({'script_version': 'mirror:stayfield,stayfield2:s5025:dire'}, f)
    check('10c absent id reads False, not True', armed_in_stamp(p) is False)
    check('10c substring id is not a hit',
          armed_in_stamp(p, 'stayfield') is True
          and armed_in_stamp(p, 'stayfiel') is False)
    check('10c side dire parses', leg_of(p)[0] == 'dire')
    # 10d an unknown side token is refused rather than silently kept.
    with open(p, 'w') as f:
        json.dump({'script_version': 'mirror:stayattr:s5025:ab'}, f)
    check('10d ab/ba is NOT a side token here', leg_of(p) == (None, None, None))
    os.unlink(p)

    print('selfcheck: %d passed, %d failed' % (ok, fail))
    return 0 if fail == 0 else 3


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('timelines', nargs='*',
                    help='*.timeline.json (or a dir containing them)')
    ap.add_argument('--analysis-dir',
                    help='dir of <game>.analysis.json for the leg stamp')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--json', help='write per-frame rows here')
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()

    paths = []
    for p in a.timelines:
        paths.extend(sorted(glob.glob(os.path.join(p, '*.timeline.json')))
                     if os.path.isdir(p) else [p])
    if not paths:
        print('could not run: no timelines given', file=sys.stderr)
        return 2

    all_rows, scored, warmup, unarmed = [], 0, 0, 0
    total = collections.Counter()
    by_stratum = collections.defaultdict(lambda: collections.defaultdict(list))
    for p in paths:
        name = os.path.basename(p).replace('.timeline.json', '')
        try:
            with open(p) as f:
                tl = json.load(f)
        except Exception as exc:
            print('could not run: %s: %s' % (name, exc), file=sys.stderr)
            return 2
        rows, st = scan_game(tl)
        side, _cand, seed = (None, None, None)
        has_id = None
        if a.analysis_dir:
            ap = os.path.join(a.analysis_dir, name + '.analysis.json')
            side, _cand, seed = leg_of(ap)
            has_id = armed_in_stamp(ap)
        armed_team = ARMED_TEAM.get(side)
        for r in rows:
            r['game'], r['side'], r['seed'] = name, side, seed
            # THE LEG, and it is per-HERO inside one game, not per-game.
            r['leg'] = (None if armed_team is None
                        else ('armed' if r['team'] == armed_team else 'baseline'))
        all_rows.extend(rows)
        total.update(st)
        if side and has_id:
            scored += 1
            for r in rows:
                by_stratum[side][r['leg']].append(r)
        elif side and has_id is False:
            unarmed += 1
        else:
            warmup += 1
        na = sum(1 for r in rows if r['leg'] == 'armed')
        nb = sum(1 for r in rows if r['leg'] == 'baseline')
        print('%-34s side=%-8s DOMAIN=%-3d (armed %d / baseline %d)  '
              'veto_reached=%-4d damager_near=%-4d ring=%-4d ambig=%d'
              % (name, side or 'WARMUP', st['domain_frames'], na, nb,
                 st['veto_reached'], st['veto_stands_damager_near'],
                 st['dropped_ring_enemy'], st['ambiguous_no_observable_regen']))

    print('\n--- corpus ---')
    print('games: %d scored (mirror-stamped AND carrying `stayattr`)' % scored)
    print('       %d mirror-stamped WITHOUT `stayattr` in the string (refused)'
          % unarmed)
    print('       %d WARM-UP / unstamped (no armed team; never pooled)' % warmup)
    print('veto reached (hp band + hero damage): %d frame(s)' % total['veto_reached'])
    print('  veto stands, damager inside 3000  : %d  <- armed == shipped here'
          % total['veto_stands_damager_near'])
    print('  dropped by the 1200 ring (:5121)  : %d' % total['dropped_ring_enemy'])
    print('  AMBIGUOUS, regen source unobserved: %d  <- gold not in the dump'
          % total['ambiguous_no_observable_regen'])
    print('ARMED-ONLY DOMAIN                   : %d frame(s), %d episode(s)'
          % (total['domain_frames'], total['episodes']))

    if not scored:
        print('\nNO SCORED GAME CARRYING `stayattr` IN THIS CORPUS => no '
              'armed/baseline\nreading is possible. The counts above are a '
              'REACH price on unscored frames\nand are NOT condition (a).')
    else:
        print('\n--- per stratum (iron rule 4(i-a): READINGS, not game counts) ---')
        seen = []
        for side in ('radiant', 'dire'):
            legs = by_stratum.get(side)
            if not legs:
                print('  %-7s: NO GAME IN THIS STRATUM' % side)
                continue
            seen.append(side)
            for leg in ('armed', 'baseline'):
                rs = legs.get(leg, [])
                if not rs:
                    print('  %-7s %-8s: 0 domain frame(s)' % (side, leg))
                    continue
                usable = [r for r in rs if r['went_home'] is not None]
                home = sum(1 for r in usable if r['went_home'])
                drank = sum(1 for r in rs if r['started_regen'])
                prog = [r['home_progress'] for r in usable]
                print('  %-7s %-8s: %d domain frame(s), %d episode(s); '
                      'went_home %d/%d (%s); started_regen %d/%d; '
                      'mean home_progress %s u'
                      % (side, leg, len(rs), _count_episodes(rs), home,
                         len(usable),
                         ('%.3f' % (home / len(usable))) if usable else 'n/a',
                         drank, len(rs),
                         ('%.1f' % (sum(prog) / len(prog))) if prog else 'n/a'))
        print('  4(ii): count-type quantity -- means and shares above a stated'
              '\n         threshold are given above; NO medians.')
        if len(seen) < 2:
            print('  ⛔ 4(i-a) NOT SATISFIED: only the %s stratum is present. '
                  'A one-stratum\n     reading is not a condition-(a) reading; '
                  'it is half of one.' % (seen[0] if seen else 'no'))
        else:
            print('  4(i-b): side bias is NOT eliminated in this estimator; '
                  'opposite signs\n          across the two strata read as '
                  'noise and do not enter a conclusion.')

    if total['domain_frames'] == 0:
        print('\nDOMAIN-NOT-REACHED. This is NOT "tested, no effect": every '
              'unobservable\nclause in this tool can only SUPPRESS a domain '
              'frame (see the module docstring).')

    if a.json:
        with open(a.json, 'w') as f:
            for r in all_rows:
                f.write(json.dumps(r) + '\n')
        print('\nwrote %d row(s) to %s' % (len(all_rows), a.json))
    return 0


if __name__ == '__main__':
    sys.exit(main())

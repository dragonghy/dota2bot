#!/usr/bin/env python3
"""`tpgap` condition (a): does the gap-band retreat guard actually refuse?

THE LEVER
---------
`J.ShouldNotTpUnderLethalPressure` (`bots/FunLib/jmz_func.lua`), called from
the RETREAT branch of `ability_item_usage_generic.lua` immediately after the
promoted `tpsafe` (`J.ShouldWalkNotTp`):

    if not J.IsModeTurbo() then return false end
    if not J.IsSoakCandidate( 'tpgap' ) then return false end
    ...
    if #J.GetNearbyHeroes( bot, 350, true, ... ) > 0 then return false end   -- tpsafe's turf
    if rooted/stunned/hexed/nightmared then return false end
    if bot:GetCurrentMovementSpeed() < 285 then return false end
    hGap = J.GetNearbyHeroes( bot, 700, true, ... )
    if #hGap == 0 then return false end
    return sum( e:GetEstimatedDamageToTarget( true, bot, 3.0, ALL ) ) >= bot:GetHealth()

Direction is NARROWING: the armed predicate refuses a strict subset of the
presses the shipped tree makes.  So the pre-registered reading (director,
`queue.json:strategy-14`) is "presses in the SUB-DOMAIN go down, and the
reverse sentinel -- retreat-TP SUCCESS rate -- does not collapse", never
"press count must not fall".

WHY THE ATTRIBUTION IS CLEAN DESPITE A 37-id BUNDLE WAVE
--------------------------------------------------------
W14 arms 37 ids at once, so any pooled leg difference is a bundle-composite
reading (the `zusstatic` lesson, GH #207).  Two structural facts narrow it:

  1. **Every retreat TP in the tree lands at the own fountain.**  All three
     retreat cases in `ability_item_usage_generic.lua` (`撤退:1/2/3`) assign
     `tpLoc = J.GetTeamFountain()` and nothing else does.  So `dest in
     {home, died}` is a NECESSARY condition for a retreat press, and
     `dest == 'field'` presses are travel TPs which this guard cannot see.
  2. **The other armed TP levers do not run on the retreat branch.**
     `tpreach` widens `J.CanEnemyInterruptTpChannel`, whose three call sites
     are `ShouldNotStartInterruptibleTp` (scoped `nMode ~= BOT_MODE_RETREAT`),
     the rescue TP (`jmz_func:6599`) and the defend/response TP
     (`jmz_func:8009`) -- all travel TPs.  `tpcommit`/`tpdying`/`tpdead` sit
     inside the response-TP landing logic, also travel.  `tpdeathbuy` buys a
     scroll, it does not press one.

`assert_retreat_dest_is_fountain()` and `assert_retreat_only_guard()` below
turn both of those into source assertions, so this argument cannot expire
silently when someone edits the Lua.

WHAT IS OBSERVABLE, AND WHAT IS NOT
-----------------------------------
Observable at the press instant: position of every hero (=> the band), the
presser's `hp` (ABSOLUTE, not just the fraction), level, the destination, and
whether the presser died inside the channel.

NOT observable, hard boundary:

  * `GetEstimatedDamageToTarget( true, bot, 3.0, ALL )`.  There is no engine
    damage estimate in the dump.  This tool uses TWO stand-ins and reports
    both, because neither alone is the predicate:
      - REALIZED (`lethal_obs`): the band enemies did in fact take the
        presser's whole health inside the 3 s channel.  Result-side, but it
        is the set the guard exists to empty, and it is computed identically
        on both legs.
      - DECISION-SIDE (`hp_band`): the presser's absolute health at the
        press, which the predicate is monotone-decreasing in.  Low health is
        where the predicate can be true; high health is where it cannot, and
        the high-health stratum is therefore a built-in negative control.
  * `bot:GetCurrentMovementSpeed()` and rooted/stunned/hexed -- no such field.
    All three are fall-throughs (they let the TP through), so every count
    here is an UPPER BOUND on the true domain.
  * `J.GetNearbyHeroes(..., true, ...)` returns only VISIBLE enemies, and the
    dump is a god's-eye view.  `saw_nearest` (the auto-attack vision witness
    in `tp_channel_death`) is one-directional: True proves vision, False
    proves nothing.

So `verdict()` never answers on the pooled count alone.  It requires the
deficit to be CONCENTRATED in the sub-domain and ABSENT in the two bands the
guard structurally cannot touch (`walk_guard` = tpsafe's turf, which the
guard's second line returns false on; `far`/`no_enemy` = no band enemy at
all).  A uniform deficit across all bands is some other id in the bundle, and
is reported as such rather than as `tpgap`.
"""
import argparse
import collections
import glob
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import source_constants as SC  # noqa: E402
from entities import canon, frames_by_hero, interp, alive_interp, death_times  # noqa: E402
from tp_channel_death import (  # noqa: E402
    band_of, fountains, tp_destination, scan_sweep,
    SCAN_RADIUS_U, WALK_GUARD_RADIUS_U, CHANNEL_WINDOW_S, ATTACK_INFLICTOR,
    VISION_LOOKBACK_S)

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
JMZ = os.path.join(REPO, 'bots', 'FunLib', 'jmz_func.lua')
AIU = os.path.join(REPO, 'bots', 'ability_item_usage_generic.lua')

GUARD = 'J.ShouldNotTpUnderLethalPressure'
# The retreat press destinations this guard can possibly have ruled on.  A
# press that started inside the own fountain (`from_home`) has a meaningless
# destination and is excluded everywhere below.
RETREAT_DESTS = ('home', 'died')


# --------------------------------------------------------------------------
# source side -- constants are READ, never retyped
# --------------------------------------------------------------------------
def _nearby_radii(stripped):
    """The two `J.GetNearbyHeroes` radii of the guard, IN SOURCE ORDER.

    `source_constants.call_arg` cannot pick between them: the two calls differ
    only in the argument being read, so its `where` pin has nothing to pin on.
    Reading them positionally is therefore explicit here rather than smuggled
    in as "whichever one comes first" -- and the order itself is asserted
    (inner < outer), so a swap in the Lua is a loud failure instead of a
    silently inverted domain.
    """
    import re
    radii = [float(m.group(1)) for m in re.finditer(
        r'J\.GetNearbyHeroes\s*\(\s*bot\s*,\s*([0-9.]+)\s*,', stripped)]
    if len(radii) != 2:
        raise SC.SourceConstantError(
            '%s: expected exactly 2 J.GetNearbyHeroes calls, found %d (%s)'
            % (GUARD, len(radii), radii))
    if not radii[0] < radii[1]:
        raise SC.SourceConstantError(
            '%s: the on-face scan (%s) is no longer inside the band scan (%s)'
            % (GUARD, radii[0], radii[1]))
    return radii


def _gate_id(stripped):
    """The soak-candidate id the guard gates on -- exactly one, or a failure.

    `source_constants.literal` coerces its match to a number, so a STRING
    constant cannot go through it.  Read here instead of retyped, for the same
    reason every other constant is: the day this guard is promoted the id
    disappears from the source and this tool must say so rather than keep
    printing `tpgap` from a hardcoded string.
    """
    import re
    ids = re.findall(r"IsSoakCandidate\(\s*'(\w+)'\s*\)", stripped)
    if len(ids) != 1:
        raise SC.SourceConstantError(
            '%s: expected exactly 1 IsSoakCandidate gate, found %d (%s) -- a '
            'conjunction of two ids freezes FALSE the day either is promoted'
            % (GUARD, len(ids), ids))
    return ids[0]


def read_source():
    """The guard's own numbers, off the Lua."""
    body = SC.function_body(GUARD, path=JMZ)
    stripped = SC._strip_comments(body)
    inner, outer = _nearby_radii(stripped)
    out = {
        'onface_radius': inner,
        'band_radius': outer,
        'channel_seconds': float(SC.literal(
            GUARD, r'nChannelSeconds\s*=\s*(?P<n>[0-9.]+)', path=JMZ)),
        'min_speed': float(SC.literal(
            GUARD, r'GetCurrentMovementSpeed\(\)\s*<\s*(?P<n>[0-9.]+)',
            path=JMZ)),
        'gate_id': _gate_id(stripped),
    }
    # The comparison is `>= bot:GetHealth()`, i.e. ABSOLUTE health, not
    # J.GetHP's 0..1 fraction.  If someone swaps it for the fraction every
    # reading below changes meaning, so pin it.
    if 'bot:GetHealth()' not in stripped:
        raise SC.SourceConstantError(
            '%s no longer compares against bot:GetHealth() -- the absolute-hp '
            'reading in this tool is no longer the predicate' % GUARD)
    if 'GetEstimatedDamageToTarget' not in stripped:
        raise SC.SourceConstantError(
            '%s no longer sums GetEstimatedDamageToTarget' % GUARD)
    return out


def _retreat_block(src):
    """The retreat branch of the TP-cast function, ANCHORED ON THE GUARD ITSELF.

    `nMode == BOT_MODE_RETREAT` appears eight times in this file and
    `BOT_MODE_LANING` four; picking the first of each reads a different
    function entirely and then reports "assigns no tpLoc", which looks like a
    finding about the retreat branch and is a finding about the search.  So the
    block is bounded from the guard's own call site outward: back to the
    nearest enclosing retreat test, forward to the next mode test of any kind.
    """
    g = src.find(GUARD)
    if g < 0:
        raise SC.SourceConstantError('%s has no call site in %s'
                                     % (GUARD, AIU))
    i = src.rfind('nMode == BOT_MODE_RETREAT', 0, g)
    if i < 0:
        raise SC.SourceConstantError(
            '%s is no longer inside a BOT_MODE_RETREAT branch' % GUARD)
    import re
    m = re.search(r'nMode\s*[=~]=\s*BOT_MODE_\w+', src[g:])
    if not m:
        raise SC.SourceConstantError('cannot bound the retreat branch')
    return src[i:g + m.start()]


def assert_retreat_dest_is_fountain():
    """Every retreat-branch TP goes to the own fountain -- so `dest` separates
    retreat presses from travel presses.  Returns the count of assignments."""
    with open(AIU, 'r', encoding='utf-8') as fh:
        src = SC._strip_comments(fh.read())
    block = _retreat_block(src)
    assigns = [ln.strip() for ln in block.splitlines()
               if 'tpLoc' in ln and '=' in ln and 'tpLoc ==' not in ln]
    if not assigns:
        raise SC.SourceConstantError('retreat branch assigns no tpLoc')
    bad = [a for a in assigns if 'J.GetTeamFountain()' not in a]
    if bad:
        raise SC.SourceConstantError(
            'retreat branch now teleports somewhere other than the own '
            'fountain (%s) -- `dest` no longer separates retreat from travel'
            % bad)
    return len(assigns)


def assert_retreat_only_guard():
    """`tpgap` is the only armed lever that can refuse a RETREAT press.

    Checks the two structural facts the attribution rests on:
      * `J.ShouldNotStartInterruptibleTp` (which `tpreach` widens) is called
        under `nMode ~= BOT_MODE_RETREAT`;
      * the guard's own call site is inside the `nMode == BOT_MODE_RETREAT`
        branch and after `J.ShouldWalkNotTp`.
    """
    with open(AIU, 'r', encoding='utf-8') as fh:
        src = SC._strip_comments(fh.read())
    k = src.find('J.ShouldNotStartInterruptibleTp')
    if k < 0:
        raise SC.SourceConstantError('tpsafe2 call site vanished')
    if 'nMode ~= BOT_MODE_RETREAT' not in src[max(0, k - 400):k]:
        raise SC.SourceConstantError(
            'tpsafe2 is no longer scoped out of retreat mode -- tpreach now '
            'confounds the retreat band and this tool cannot attribute')
    r = src.find('nMode == BOT_MODE_RETREAT')
    g = src.find(GUARD)
    w = src.find('J.ShouldWalkNotTp( bot )')
    if not (0 < r < w < g):
        raise SC.SourceConstantError(
            'guard call site is no longer inside the retreat branch after '
            'tpsafe (retreat=%d walk=%d guard=%d)' % (r, w, g))
    return True


# --------------------------------------------------------------------------
# corpus side
# --------------------------------------------------------------------------
def band_enemies(fr, team, h, t, dead, radius=SCAN_RADIUS_U,
                 inner=WALK_GUARD_RADIUS_U):
    """Living enemy heroes in (inner, radius] of `h` at `t`.

    `inner` is EXCLUSIVE-BELOW on purpose: the guard's second line returns
    false outright when anything is within 350, so a press with an on-face
    enemy is not in this domain at all.  Returns (list_of_names, nearest) or
    (None, nearest) when the on-face line would have fired.
    """
    s0 = interp(fr[h], t)
    if s0 is None:
        return None, None
    inband, nearest = [], None
    for h2 in fr:
        if h2 == h or team.get(h2) == team.get(h):
            continue
        s2 = alive_interp(fr[h2], t, dead.get(h2))
        if s2 is None:
            continue
        d = math.dist((s0['x'], s0['y']), (s2['x'], s2['y']))
        if nearest is None or d < nearest:
            nearest = d
        if inner < d <= radius:
            inband.append(h2)
    if nearest is not None and nearest <= inner:
        return None, nearest       # tpsafe's turf -- guard returns false
    return inband, nearest


def interp_hp(frames, t):
    """ABSOLUTE health at `t`, plus the sampling gap it was read across.

    `entities.interp` carries `hp_pct` and not `hp`, and the guard compares
    against `bot:GetHealth()` -- an absolute number -- so the fraction is not
    the predicate's quantity.  Read here rather than by widening the shared
    helper, because several detectors build frame dicts in their selfchecks
    that carry no `hp` key at all and would start raising instead of reading.

    Returns (hp, gap) where `gap` is the width of the bracketing interval, so
    a reading taken across a 1 s sample gap can be told apart from one taken
    on a sample.  Health is not actually linear between samples; the gap is
    printed rather than hidden for exactly that reason.
    """
    if not frames or t < frames[0]['t'] or t > frames[-1]['t']:
        return None, None
    lo, hi = 0, len(frames) - 1
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if frames[mid]['t'] <= t:
            lo = mid
        else:
            hi = mid
    a, b = frames[lo], frames[hi]
    span = b['t'] - a['t']
    if span <= 0:
        return float(a['hp']), 0.0
    w = (t - a['t']) / span
    return float(a['hp']) + (float(b['hp']) - float(a['hp'])) * w, span


def realized_burst(events, h, band, t, window):
    """Damage the BAND enemies actually dealt to `h` in [t, t+window].

    Result-side by construction and labelled so.  Restricted to the enemies
    that were in the band AT THE PRESS -- damage from someone who walked in
    afterwards is not something the predicate could have priced.
    """
    tot = 0.0
    band = set(band)
    for e in events:
        if (e['type'] == 'DAMAGE' and canon(e.get('target')) == h
                and canon(e.get('actor')) in band
                and t <= e['t'] <= t + window):
            tot += float(e.get('value') or 0)
    return tot


def enrich(rows, sweep_dir):
    """Add the tpgap-specific columns to `tp_channel_death` rows, in place.

    Adds: `hp_abs` (absolute health at the press -- what the predicate
    compares against), `n_band` (living enemies in the gap band),
    `obs_burst` (realized band damage over the channel), `lethal_obs`
    (obs_burst >= hp_abs), `retreat` (dest in RETREAT_DESTS).
    """
    by_game = collections.defaultdict(list)
    for r in rows:
        by_game[r['game']].append(r)
    src = read_source()
    win = src['channel_seconds']
    for p in sorted(glob.glob(os.path.join(sweep_dir, 'timelines',
                                           '*.timeline.json'))):
        game = os.path.basename(p).replace('.timeline.json', '')
        if game not in by_game:
            continue
        tl = json.load(open(p))
        fr, team = frames_by_hero(tl)
        dead = death_times(tl)
        for r in by_game[game]:
            h, t = r['hero'], r['t']
            if h not in fr:
                continue
            r['hp_abs'], r['hp_gap'] = interp_hp(fr[h], t)
            inband, _ = band_enemies(fr, team, h, t, dead,
                                     radius=src['band_radius'],
                                     inner=src['onface_radius'])
            r['n_band'] = None if inband is None else len(inband)
            r['obs_burst'] = (None if not inband
                              else realized_burst(tl['events'], h, inband, t,
                                                  win))
            r['lethal_obs'] = bool(
                r['obs_burst'] is not None and r['hp_abs']
                and r['obs_burst'] >= r['hp_abs'])
            r['retreat'] = r['dest'] in RETREAT_DESTS
    return rows


# --------------------------------------------------------------------------
# frame audit -- the two fall-throughs the aggregate cannot see
# --------------------------------------------------------------------------
# The engine predicates the guard falls through on are IsRooted / IsStunned /
# IsHexed / IsNightmared.  There is no state field for any of them, but
# MODIFIER_ADD / MODIFIER_REMOVE carry real modifier names, so an ACTIVE
# modifier at the press instant is readable.  The mapping below is deliberately
# BROAD -- it is used to EXCUSE an armed press, so over-matching costs a
# missed finding while under-matching manufactures one, and only the second
# error is the kind this group must not make.
DISABLE_MARKERS = (
    'stunned', 'stun', 'root', 'hex', 'nightmare', 'sleep', 'fear',
    'taunt', 'bash', 'frostbite', 'ensnare', 'entangle', 'shackle',
    'cyclone', 'eul', 'hurricane', 'chronosphere', 'black_hole',
)
# `GetCurrentMovementSpeed() < 285` is the other fall-through, and also has no
# field.  Displacement between snapshots LOWER-bounds the speed: a hero who
# covered 300 u in the second before the press was moving at >= 300 u/s, so
# the fall-through was false.  The converse says nothing -- a hero standing
# still by choice reads 0 -- which is why this is only ever used to REFUTE the
# excuse, never to grant it.
SPEED_LOOKBACK_S = 3.0


def active_modifiers(events, hero, t):
    """Modifiers added to `hero` at or before `t` and not yet removed.

    Pairing is per (target, inflictor) and FIFO: a modifier re-applied before
    its first copy expires would otherwise have its removal counted against
    the wrong copy and read as gone while it is still on.
    """
    live = collections.Counter()
    for e in sorted(events, key=lambda e: e['t']):
        if e['t'] > t:
            break
        if canon(e.get('target')) != hero:
            continue
        if e['type'] == 'MODIFIER_ADD':
            live[e.get('inflictor')] += 1
        elif e['type'] == 'MODIFIER_REMOVE' and live[e.get('inflictor')] > 0:
            live[e.get('inflictor')] -= 1
    return sorted(k for k, v in live.items() if v > 0 and k)


def disabled_at(events, hero, t):
    """The disabling modifiers active at `t`, or [] -- see DISABLE_MARKERS."""
    return [m for m in active_modifiers(events, hero, t)
            if any(k in m for k in DISABLE_MARKERS)]


def observed_speed(frames, t, lookback=SPEED_LOOKBACK_S):
    """Fastest sampled ground speed in the `lookback` seconds before `t`.

    A LOWER bound on `GetCurrentMovementSpeed()` over that window, and only
    that: the reading is displacement over a ~1 s sampling interval, so a hero
    who stopped, turned, or was briefly held reads slower than he could move.
    """
    # BOTH ENDPOINTS must be inside the window.  Letting a step start before
    # `t - lookback` would credit the window with movement that happened
    # outside it -- and since this number is used to REFUTE the speed excuse,
    # borrowing speed from outside the window is the direction that
    # manufactures a finding.
    win = [f for f in frames if t - lookback <= f['t'] <= t]
    best = None
    for a, b in zip(win, win[1:]):
        if b['t'] <= a['t']:
            continue
        v = math.dist((b['x'], b['y']), (a['x'], a['y'])) / (b['t'] - a['t'])
        best = v if best is None or v > best else best
    return best


# Creep entity names carry their side; team vision is SHARED in Dota 2, so an
# allied creep that attacked the enemy is as good a witness for the bot's own
# `GetNearbyHeroes(..., true, ...)` as the bot attacking him itself.
CREEP_SIDE = {2: 'goodguys', 3: 'badguys'}
RAD, DIRE = 2, 3


def vision_witness(events, enemy, bot_team, ally_heroes, t,
                   lookback=VISION_LOOKBACK_S):
    """Did the bot's TEAM demonstrably have vision of `enemy` just before `t`?

    `tp_channel_death.saw_enemy` asks only whether the BOT itself
    auto-attacked, which almost never happens on a retreat -- the hero is
    running away.  But vision in Dota 2 is shared team-wide, and
    `J.GetNearbyHeroes( bot, 700, true, ... )` returns whatever the TEAM can
    see.  So the witness set is widened to any allied unit, creeps included:

      * an ally (hero or creep) auto-attacked `enemy`, or
      * an ally hero targeted an ability at `enemy`.

    Both require a targetable unit, so both prove team vision.  Still strictly
    one-directional: True proves vision, False proves nothing at all -- there
    is no fog field in the dump and this must never be read as "was in fog".
    """
    creep = CREEP_SIDE.get(bot_team)
    for e in events:
        if not (t - lookback <= e['t'] <= t):
            continue
        if canon(e.get('target')) != enemy:
            continue
        actor = e.get('actor') or ''
        ally = (canon(actor) in ally_heroes
                or (creep is not None and creep in actor))
        if not ally:
            continue
        if e['type'] == 'DAMAGE' and e.get('inflictor') == ATTACK_INFLICTOR:
            return 'ally-attack:%s' % canon(actor)
        if e['type'] == 'ABILITY' and e.get('target_hero'):
            return 'ally-cast:%s/%s' % (canon(actor), e.get('inflictor'))
    return None


def frame_audit(rows, sweep_dirs):
    """Per-frame audit of the ARMED rows the guard should have refused.

    An armed press that was realized-lethal is a press the guard did not make.
    Whether that is a FINDING depends on the two fall-throughs the aggregate
    cannot see, so each row is settled individually rather than counted:

      * a disabling modifier active at the press => the guard returns false by
        its own source, the press is CORRECT, and the row is EXCUSED;
      * a demonstrated ground speed >= the source's `min_speed` in the seconds
        before the press REFUTES the speed excuse for that row;
      * nothing else is claimed.  A row with neither witness is UNSETTLED, not
        a bug -- the dump cannot see a slow that left the hero moving.
    """
    src = read_source()
    # KEYED BY (run, game), not by game.  W14 stamps a replay
    # `<UTC>_slot<N>`, and four instances launched within 8 s of each other
    # produced 10 name collisions across runs out of 132 games (7.6%) -- so a
    # bare-name match here would audit a frame against another seed's replay
    # and the mismatch would look like a clean row.
    want = {(r.get('run'), r['game'], r['hero'], r['t']): r for r in rows}
    out = []
    for d in sweep_dirs:
        run = os.path.basename(d.rstrip(os.sep))
        for p in sorted(glob.glob(os.path.join(d, 'timelines',
                                               '*.timeline.json'))):
            game = os.path.basename(p).replace('.timeline.json', '')
            if not any(k[0] == run and k[1] == game for k in want):
                continue
            tl = json.load(open(p))
            fr, team = frames_by_hero(tl)
            for (rn, g, h, t), r in want.items():
                if rn != run or g != game or h not in fr:
                    continue
                dis = disabled_at(tl['events'], h, t)
                spd = observed_speed(fr[h], t)
                bot_team = team.get(h)
                allies = {x for x in fr if team.get(x) == bot_team and x != h}
                saw = vision_witness(tl['events'], r['nearest_hero'],
                                     bot_team, allies, t)
                fast = spd is not None and spd >= src['min_speed']
                if dis:
                    settled = 'EXCUSED (disabled)'
                elif not fast:
                    settled = 'UNSETTLED (speed unwitnessed)'
                elif not saw:
                    settled = 'UNSETTLED (vision unwitnessed)'
                else:
                    settled = 'SHOULD-HAVE-REFUSED'
                out.append(dict(
                    r, disabled=dis, speed=spd, fast=fast, saw_team=saw,
                    settled=settled,
                    modifiers=active_modifiers(tl['events'], h, t)))
    return out


# --------------------------------------------------------------------------
# readings
# --------------------------------------------------------------------------
def cell(rows, pred, base=None):
    """Counts for one stratum, per leg, with TWO denominators.

    Counting quantity with a small integer range => mean + share, never a
    median (铁律 4 (ii), GH #148).  Hence `per_game` (the mean) and `share`
    (the proportion) side by side.

    WHY THE SECOND DENOMINATOR IS NOT OPTIONAL HERE.  W14's armed leg presses
    RETREAT ~1.7 fewer times per game than its baseline leg, in both ab and
    ba -- a 37-id bundle effect that has nothing to do with this guard.  That
    deficit lands on every band at once, so a per-game reading of any single
    band inherits it and a band could read "down" purely from having fewer
    presses to be counted in.  `share` divides by the exposure (`base`,
    normally the leg's retreat presses), which cancels it.
    """
    out = {}
    for leg in ('armed', 'baseline'):
        g = [r for r in rows if r['leg'] == leg]
        games = len({(r.get('run'), r['game']) for r in g})
        hit = [r for r in g if pred(r)]
        exp = [r for r in g if base(r)] if base else g
        out[leg] = dict(n=len(hit), games=games, exposure=len(exp),
                        per_game=(len(hit) / games) if games else 0.0,
                        share=(len(hit) / len(exp)) if exp else 0.0)
    return out


def layered(rows, pred, base=None):
    """The same cell in the ab and the ba stratum (铁律 4 (i)).

    A leg difference that reverses sign between the two arm sides is noise and
    must not be written into a conclusion.
    """
    out = {}
    for side in ('radiant', 'dire'):
        out[side] = cell([r for r in rows if r['arm_side'] == side], pred,
                         base)
    out['POOLED'] = cell(rows, pred, base)
    return out


def _delta(c, key='share'):
    """armed - baseline on the EXPOSURE-CORRECTED quantity by default.

    `per_game` is still printed beside it, but the verdict runs on `share`:
    see cell() for why a per-game band reading in a 37-id bundle wave inherits
    a deficit it did not earn.
    """
    return c['armed'][key] - c['baseline'][key]


def same_sign(lay):
    """Do the ab and ba layers agree on the sign of the armed-baseline gap?"""
    da, db = _delta(lay['radiant']), _delta(lay['dire'])
    if da == 0.0 or db == 0.0:
        return False
    return (da > 0) == (db > 0)


def verdict(strata):
    """WORKING / BUGGY / SILENT -- or a refusal.

    `strata` maps a stratum name to its `layered()` result.  The decision is
    deliberately NOT the pooled sub-domain count:

      * the deficit must be present in `domain` (band + retreat + lethal) and
        agree in sign across ab/ba;
      * it must be ABSENT in `control_onface` (tpsafe's turf -- the guard's
        second line returns false there) and `control_noband` (no band enemy
        -- the guard's fifth line returns false).  A deficit in those is some
        other id in the bundle, not this one.

    Returns (verdict, reason).
    """
    dom = strata['domain']
    if dom['POOLED']['baseline']['n'] == 0:
        return 'REFUSE', ('the baseline leg has no presses in the sub-domain '
                          'at all -- with nothing to refuse, an armed zero '
                          'cannot distinguish WORKING from SILENT')
    # ORDER MATTERS.  "no deficit" is answered BEFORE the ab/ba agreement
    # test, because a pooled delta of exactly 0 is a real reading (armed
    # presses just as often = SILENT) while `same_sign` reads a zero layer as
    # disagreement.  Asking agreement first turns the cleanest SILENT world
    # there is into a REFUSE.
    if _delta(dom['POOLED']) >= 0:
        return 'SILENT', ('armed presses in the sub-domain are not fewer than '
                          'baseline (%.3f vs %.3f per game)'
                          % (dom['POOLED']['armed']['per_game'],
                             dom['POOLED']['baseline']['per_game']))
    if not same_sign(dom):
        return 'REFUSE', ('ab and ba disagree on the sign of the sub-domain '
                          'gap -- noise by 铁律 4 (i), not a reading')
    leaks = [k for k in ('control_onface', 'control_noband')
             if _delta(strata[k]['POOLED']) < 0 and same_sign(strata[k])]
    if leaks:
        return 'BUGGY', ('the sub-domain deficit is not specific: the same '
                         'deficit appears in %s, where this guard returns '
                         'false by its own source' % ', '.join(leaks))
    return 'WORKING', ('sub-domain presses down %.3f/game with ab and ba '
                       'agreeing, and no deficit in either structural control'
                       % -_delta(dom['POOLED']))


# --------------------------------------------------------------------------
def print_layered(name, lay, note=''):
    print('\n  %s%s' % (name, ('  -- ' + note) if note else ''))
    print('  %-10s %7s %7s %8s %8s %9s %9s %9s'
          % ('stratum', 'armed', 'base', 'armed/g', 'base/g',
             'armed%', 'base%', 'd(share)'))
    for k in ('radiant', 'dire', 'POOLED'):
        c = lay[k]
        print('  %-10s %7d %7d %8.4f %8.4f %8.2f%% %8.2f%% %+9.4f'
              % (k, c['armed']['n'], c['baseline']['n'],
                 c['armed']['per_game'], c['baseline']['per_game'],
                 100.0 * c['armed']['share'], 100.0 * c['baseline']['share'],
                 _delta(c)))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('sweep_dirs', nargs='*',
                    help='.sweep_out/<run> directories')
    ap.add_argument('--source', action='store_true',
                    help='source-only read; needs no corpus and costs nothing')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--json', help='write the enriched rows here')
    a = ap.parse_args()

    if a.selfcheck:
        sys.exit(0 if selfcheck() else 1)

    src = read_source()
    n_assign = assert_retreat_dest_is_fountain()
    assert_retreat_only_guard()
    print('SOURCE (read from bots/, not retyped)')
    for k, v in sorted(src.items()):
        print('  %-18s %s' % (k, v))
    print('  %-18s %d tpLoc assignments in the retreat branch, all '
          'J.GetTeamFountain()' % ('retreat_dest', n_assign))
    print('  %-18s tpsafe2 scoped out of retreat => tpreach cannot confound'
          % 'attribution')
    if a.source or not a.sweep_dirs:
        return

    rows = []
    for d in a.sweep_dirs:
        run = os.path.basename(d.rstrip(os.sep))
        rs = scan_sweep(d, reach=SCAN_RADIUS_U)
        enrich(rs, d)
        for r in rs:
            r['run'] = run
        rows.extend(rs)
    rows = [r for r in rows if r.get('dest') != 'from_home']

    games = len({(r['run'], r['game']) for r in rows})
    names = len({r['game'] for r in rows})
    print('\nCORPUS  %d presses over %d games (from_home excluded)'
          % (len(rows), games))
    if names != games:
        print('  NAME COLLISIONS: %d distinct games share only %d distinct '
              '`<UTC>_slot<N>` names across runs.\n'
              '  Every read below is keyed (run, game); a bare-name key would '
              'silently merge %d of them.' % (games, names, games - names))
    print('  UPPER BOUND: movement speed and rooted/stunned/hexed are not in '
          'the dump; all three are fall-throughs, so every count below is an\n'
          '  upper bound on the true domain and a lower bound on nothing.')

    # EXPOSURE = the leg's own retreat presses.  Every band stratum below is a
    # subset of it, so `share` answers "of the retreat presses this leg made,
    # what fraction landed in this band" -- which is the question the guard
    # changes, and the one the bundle's overall retreat deficit does not.
    ret = lambda r: r['retreat']                                  # noqa: E731
    strata = {
        'domain': layered(rows, lambda r: (r['band'] == 'mid_gap'
                                           and r['retreat']
                                           and r['lethal_obs']), ret),
        'band_retreat_all': layered(rows, lambda r: (r['band'] == 'mid_gap'
                                                     and r['retreat']), ret),
        'band_retreat_survived': layered(
            rows, lambda r: (r['band'] == 'mid_gap' and r['retreat']
                             and not r['lethal_obs']), ret),
        'control_onface': layered(rows, lambda r: (r['band'] == 'walk_guard'
                                                   and r['retreat']), ret),
        'control_noband': layered(rows, lambda r: (r['band'] in ('far',
                                                                 'no_enemy')
                                                   and r['retreat']), ret),
        'control_travel': layered(rows, lambda r: (r['band'] == 'mid_gap'
                                                   and not r['retreat']),
                                  lambda r: not r['retreat']),
        # The unambiguous version of the harm: no healing confound, no
        # estimator at all -- the hero pressed in the band and did not come
        # out of the channel alive.
        'harm_strict': layered(rows, lambda r: (r['band'] == 'mid_gap'
                                                and r['retreat']
                                                and r['died_in_channel']),
                               ret),
        'sentinel_all_presses': layered(rows, lambda r: True),
        'sentinel_retreat': layered(rows, lambda r: r['retreat']),
    }
    print_layered('DOMAIN  mid_gap & retreat & realized-lethal',
                  strata['domain'], 'the set the guard exists to empty')
    print_layered('mid_gap & retreat (all)', strata['band_retreat_all'])
    print_layered('mid_gap & retreat & survived',
                  strata['band_retreat_survived'],
                  'false-positive refusals live here')
    print_layered('CONTROL walk_guard & retreat', strata['control_onface'],
                  "tpsafe's turf: guard returns false, legs must match")
    print_layered('CONTROL far/no_enemy & retreat', strata['control_noband'],
                  'no band enemy: guard returns false, legs must match')
    print_layered('CONTROL mid_gap & travel', strata['control_travel'],
                  'tpsafe2/tpreach turf, not this guard')
    print_layered('HARM  mid_gap & retreat & died in channel',
                  strata['harm_strict'],
                  'no estimator, no healing confound: the harm itself')
    print_layered('SENTINEL all presses', strata['sentinel_all_presses'])
    print_layered('SENTINEL retreat presses', strata['sentinel_retreat'],
                  'must not collapse: a wrong refusal costs a life')

    # Reverse sentinel proper: SUCCESS rate, not press count (the director's
    # pre-registered reading -- press count falling is what this id buys).
    print('\n  REVERSE SENTINEL  retreat-TP survival rate '
          '(channel completed, %d s window)' % CHANNEL_WINDOW_S)
    print('  %-10s %10s %10s %10s' % ('leg', 'retreat', 'survived', 'rate'))
    for side in ('radiant', 'dire', 'POOLED'):
        for leg in ('armed', 'baseline'):
            g = [r for r in rows
                 if r['leg'] == leg and r['retreat']
                 and (side == 'POOLED' or r['arm_side'] == side)]
            if not g:
                continue
            ok = [r for r in g if not r['died_in_channel']]
            print('  %-10s %10d %10d %9.1f%%'
                  % ('%s/%s' % (side, leg), len(g), len(ok),
                     100.0 * len(ok) / len(g)))

    # ---- deep frame layer: settle the armed rows one at a time -----------
    armed_dom = [r for r in rows if r['band'] == 'mid_gap' and r['retreat']
                 and r['lethal_obs'] and r['leg'] == 'armed']
    audit = frame_audit(armed_dom, a.sweep_dirs)
    print('\n  FRAME AUDIT  every ARMED press in the sub-domain, settled '
          'individually (%d rows)' % len(audit))
    print('  %-24s %-15s %7s %5s %5s %6s %-22s %s'
          % ('game', 'hero', 't', 'hp', 'near', 'speed', 'team-vision witness',
             'settled'))
    for r in sorted(audit, key=lambda r: r['near']):
        print('  %-24s %-15s %7.1f %5.0f %5d %6s %-22s %s'
              % (r['game'], r['hero'], r['t'], r['hp_abs'] or -1, r['near'],
                 ('%.0f' % r['speed']) if r['speed'] is not None else 'n/a',
                 (r['saw_team'] or '-')[:22], r['settled']))
        if r['disabled']:
            print('  %-24s   -> %s' % ('', ', '.join(r['disabled'])))
    n_should = sum(1 for r in audit if r['settled'] == 'SHOULD-HAVE-REFUSED')
    print('  => %d EXCUSED / %d SHOULD-HAVE-REFUSED / %d UNSETTLED'
          % (sum(1 for r in audit if r['disabled']), n_should,
             sum(1 for r in audit if r['settled'].startswith('UNSETTLED'))))

    # ---- the ceiling: how much of the harm can this predicate even price? --
    print('\n  CEILING  of the fatal gap-band retreat presses, how many could '
          'the guard\'s OWN arithmetic reach?')
    print('  The predicate sums only BAND enemies over 3 s.  A press killed '
          'by a tower, a creep, an enemy\n  outside 700 u, a DoT already '
          'ticking, or an enemy who arrived after the press is harm this\n'
          '  lever cannot price no matter how accurate the engine estimate '
          'is.')
    print('  %-10s %8s %10s %8s' % ('leg', 'fatal', 'priceable', 'share'))
    for leg in ('armed', 'baseline', 'BOTH'):
        g = [r for r in rows if r['band'] == 'mid_gap' and r['retreat']
             and r['died_in_channel']
             and (leg == 'BOTH' or r['leg'] == leg)]
        pr = [r for r in g if r['lethal_obs']]
        print('  %-10s %8d %10d %7.1f%%'
              % (leg, len(g), len(pr),
                 100.0 * len(pr) / len(g) if g else 0.0))

    v, why = verdict(strata)
    print('\nVERDICT  tpgap condition (a): %s' % v)
    print('  %s' % why)

    if a.json:
        with open(a.json, 'w') as fh:
            for r in rows:
                fh.write(json.dumps(r) + '\n')
        print('\n  rows -> %s' % a.json)


# --------------------------------------------------------------------------
def selfcheck():
    ok = fail = 0

    def chk(what, cond, detail=''):
        nonlocal ok, fail
        if cond:
            ok += 1
            print('  PASS  %s' % what)
        else:
            fail += 1
            print('  FAIL  %s %s' % (what, detail))

    # ---- source side ------------------------------------------------------
    src = read_source()
    chk('on-face radius read from Lua is tpsafe\'s 350',
        src['onface_radius'] == WALK_GUARD_RADIUS_U, src['onface_radius'])
    chk('band radius read from Lua is tpsafe2\'s 700',
        src['band_radius'] == SCAN_RADIUS_U, src['band_radius'])
    chk('channel window is 3 s, NOT the shared helper\'s 5 s',
        src['channel_seconds'] == 3.0 and src['channel_seconds'] != CHANNEL_WINDOW_S,
        src['channel_seconds'])
    chk('min movement speed read from Lua', src['min_speed'] == 285.0,
        src['min_speed'])
    chk('gate id is tpgap', src['gate_id'] == 'tpgap', src['gate_id'])
    chk('every retreat tpLoc is the own fountain (dest separates retreat '
        'from travel)', assert_retreat_dest_is_fountain() >= 3)
    chk('tpsafe2 is still scoped out of retreat (tpreach cannot confound)',
        assert_retreat_only_guard() is True)

    # anti-selfskip: the source assertions must be able to FAIL, not just pass
    import re as _re
    with open(JMZ, 'r', encoding='utf-8') as fh:
        jmz = fh.read()
    mutated = jmz.replace('nChannelSeconds = 3.0', 'nChannelSeconds = 5.0')
    chk('mutating the channel window in a copy is visible to the reader',
        mutated != jmz and _re.search(r'nChannelSeconds\s*=\s*5\.0', mutated))
    chk('read_source rejects a body that stopped comparing absolute health',
        _rejects(lambda: _read_source_from(
            jmz.replace('>= bot:GetHealth()', '>= J.GetHP( bot )'))))
    chk('read_source rejects a body that stopped estimating damage',
        _rejects(lambda: _read_source_from(
            jmz.replace('GetEstimatedDamageToTarget', 'GetHealth'))))

    # ---- band geometry ----------------------------------------------------
    fr = {
        'lion': [{'t': t, 'x': 0.0, 'y': 0.0, 'hp': 354, 'hp_pct': 0.43,
                  'level': 6, 'items': []} for t in (99.0, 100.0, 101.0)],
        'lich': [{'t': t, 'x': 676.0, 'y': 0.0, 'hp': 800, 'hp_pct': 1.0,
                  'level': 6, 'items': []} for t in (99.0, 100.0, 101.0)],
        'axe': [{'t': t, 'x': 5000.0, 'y': 0.0, 'hp': 900, 'hp_pct': 1.0,
                 'level': 6, 'items': []} for t in (99.0, 100.0, 101.0)],
    }
    team = {'lion': 2, 'lich': 3, 'axe': 3}
    band, near = band_enemies(fr, team, 'lion', 100.0, {})
    chk('the pinned frame (Lich 676u) is in the gap band',
        band == ['lich'] and round(near) == 676, (band, near))
    chk('band_of agrees it is mid_gap', band_of(676.0) == 'mid_gap')
    band2, _near2 = band_enemies(fr, team, 'lion', 100.0, {})
    fr['axe'][1]['x'] = 200.0
    band3, near3 = band_enemies(fr, team, 'lion', 100.0, {})
    chk('an on-face enemy makes the domain EMPTY, not "band minus him" '
        '(the guard returns false outright)',
        band3 is None and round(near3) == 200, (band3, near3))
    chk('band read is deterministic', band2 == band)
    fr['lich'][1]['x'] = 350.0
    b4, n4 = band_enemies(fr, team, 'lion', 100.0, {})
    chk('350 exactly is tpsafe\'s turf, not the band (inner is exclusive)',
        b4 is None, (b4, n4))
    fr['lich'][1]['x'] = 700.0
    fr['axe'][1]['x'] = 5000.0
    b5, _ = band_enemies(fr, team, 'lion', 100.0, {})
    chk('700 exactly IS in the band (outer is inclusive)', b5 == ['lich'], b5)
    fr['lich'][1]['x'] = 700.1
    b6, _ = band_enemies(fr, team, 'lion', 100.0, {})
    chk('700.1 is outside the band', b6 == [], b6)

    # a corpse must not be a band enemy
    fr['lich'] = [{'t': 99.0, 'x': 500.0, 'y': 0.0, 'hp': 40, 'hp_pct': 0.05,
                   'level': 6, 'items': []},
                  {'t': 101.0, 'x': 500.0, 'y': 0.0, 'hp': 0, 'hp_pct': 0.0,
                   'level': 6, 'items': []}]
    fr['axe'][1]['x'] = 5000.0
    b7, _ = band_enemies(fr, team, 'lion', 100.0, {'lich': [99.5]})
    chk('a hero dead at t is not a band enemy (no interpolated corpse)',
        b7 == [], b7)

    # ---- absolute health --------------------------------------------------
    hpf = [{'t': 100.0, 'x': 0.0, 'y': 0.0, 'hp': 400, 'hp_pct': 0.5,
            'level': 6, 'items': []},
           {'t': 101.0, 'x': 0.0, 'y': 0.0, 'hp': 200, 'hp_pct': 0.25,
            'level': 6, 'items': []}]
    hp, gap = interp_hp(hpf, 100.5)
    chk('absolute hp is interpolated, not the 0..1 fraction the guard does '
        'NOT compare against', hp == 300.0 and gap == 1.0, (hp, gap))
    chk('interp_hp refuses outside the sampled span rather than clamping',
        interp_hp(hpf, 102.0) == (None, None))
    chk('the sampling gap is reported beside the reading',
        interp_hp(hpf, 100.0)[1] == 1.0)

    # ---- realized burst ---------------------------------------------------
    ev = [
        {'t': 100.5, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_lich',
         'target': 'npc_dota_hero_lion', 'inflictor': 'x', 'value': 200},
        {'t': 102.5, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_lich',
         'target': 'npc_dota_hero_lion', 'inflictor': 'x', 'value': 200},
        {'t': 104.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_lich',
         'target': 'npc_dota_hero_lion', 'inflictor': 'x', 'value': 900},
        {'t': 100.5, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_pudge',
         'target': 'npc_dota_hero_lion', 'inflictor': 'x', 'value': 900},
        {'t': 100.5, 'type': 'HEAL', 'actor': 'npc_dota_hero_lich',
         'target': 'npc_dota_hero_lion', 'inflictor': 'x', 'value': 900},
    ]
    b = realized_burst(ev, 'lion', ['lich'], 100.0, 3.0)
    chk('realized burst sums only band enemies inside the channel window',
        b == 400.0, b)
    chk('a damage event at the window edge is included',
        realized_burst(ev, 'lion', ['lich'], 100.0, 4.0) == 1300.0)
    chk('damage from a NON-band enemy is excluded (attribution)',
        realized_burst(ev, 'lion', ['pudge'], 100.0, 3.0) == 900.0
        and 'pudge' not in ['lich'])
    chk('a HEAL is not burst', realized_burst(
        [ev[4]], 'lion', ['lich'], 100.0, 3.0) == 0.0)

    # ---- frame audit ------------------------------------------------------
    mev = [
        {'t': 90.0, 'type': 'MODIFIER_ADD', 'target': 'npc_dota_hero_lion',
         'actor': 'npc_dota_hero_lich', 'inflictor': 'modifier_stunned'},
        {'t': 92.0, 'type': 'MODIFIER_REMOVE', 'target': 'npc_dota_hero_lion',
         'actor': 'npc_dota_hero_lich', 'inflictor': 'modifier_stunned'},
        {'t': 99.0, 'type': 'MODIFIER_ADD', 'target': 'npc_dota_hero_lion',
         'actor': 'npc_dota_hero_lich', 'inflictor': 'modifier_stunned'},
        {'t': 95.0, 'type': 'MODIFIER_ADD', 'target': 'npc_dota_hero_lion',
         'actor': 'npc_dota_hero_lion', 'inflictor': 'modifier_item_pipe_aura'},
        {'t': 95.0, 'type': 'MODIFIER_ADD', 'target': 'npc_dota_hero_axe',
         'actor': 'npc_dota_hero_lich', 'inflictor': 'modifier_stunned'},
    ]
    chk('a stun that was already removed is not active',
        disabled_at(mev[:2], 'lion', 100.0) == [])
    chk('a stun added and not removed IS active',
        disabled_at(mev, 'lion', 100.0) == ['modifier_stunned'])
    chk('a modifier on ANOTHER hero is not on this one',
        disabled_at(mev, 'lion', 94.0) == [])
    chk('a non-disabling aura is not a disable',
        'modifier_item_pipe_aura' in active_modifiers(mev, 'lion', 100.0)
        and 'modifier_item_pipe_aura' not in disabled_at(mev, 'lion', 100.0))
    chk('a modifier added AFTER the instant is not active at it',
        disabled_at(mev, 'lion', 98.0) == [])
    # FIFO pairing: re-applied before the first copy expired
    rea = [dict(mev[0]), dict(mev[0], t=90.5), dict(mev[1], t=91.0)]
    chk('a re-applied stun survives the first REMOVE (FIFO pairing)',
        disabled_at(rea, 'lion', 92.0) == ['modifier_stunned'])

    walk = [{'t': 97.0, 'x': 0.0, 'y': 0.0, 'hp': 400, 'hp_pct': 0.5,
             'level': 6, 'items': []},
            {'t': 98.0, 'x': 100.0, 'y': 0.0, 'hp': 400, 'hp_pct': 0.5,
             'level': 6, 'items': []},
            {'t': 99.0, 'x': 500.0, 'y': 0.0, 'hp': 400, 'hp_pct': 0.5,
             'level': 6, 'items': []},
            {'t': 100.0, 'x': 500.0, 'y': 0.0, 'hp': 400, 'hp_pct': 0.5,
             'level': 6, 'items': []}]
    chk('observed speed is the FASTEST sampled step, not the average '
        '(a lower bound on what the hero could do)',
        observed_speed(walk, 100.0) == 400.0, observed_speed(walk, 100.0))
    chk('a hero who never moved reads 0 and cannot refute the speed excuse',
        observed_speed([dict(f, x=0.0) for f in walk], 100.0) == 0.0)
    chk('samples outside the lookback do not count',
        observed_speed(walk, 100.0, lookback=1.0) == 0.0)

    vev = [
        {'t': 99.0, 'type': 'DAMAGE', 'actor': 'npc_dota_creep_goodguys_melee',
         'target': 'npc_dota_hero_lich', 'inflictor': 'dota_unknown',
         'value': 20, 'target_hero': True},
        {'t': 99.5, 'type': 'ABILITY', 'actor': 'npc_dota_hero_zuus',
         'target': 'npc_dota_hero_lich', 'inflictor': 'zuus_arc_lightning',
         'value': 0, 'target_hero': True},
        {'t': 99.0, 'type': 'DAMAGE', 'actor': 'npc_dota_creep_badguys_melee',
         'target': 'npc_dota_hero_lich', 'inflictor': 'dota_unknown',
         'value': 20, 'target_hero': True},
        {'t': 90.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_zuus',
         'target': 'npc_dota_hero_lich', 'inflictor': 'dota_unknown',
         'value': 20, 'target_hero': True},
    ]
    chk('an ALLIED CREEP attacking the enemy is a team-vision witness '
        '(vision is shared)',
        vision_witness([vev[0]], 'lich', 2, set(), 100.0) is not None)
    chk('an ENEMY creep attacking him is not',
        vision_witness([vev[2]], 'lich', 2, set(), 100.0) is None)
    chk('an ally hero targeting an ability at him is a witness',
        vision_witness([vev[1]], 'lich', 2, {'zuus'}, 100.0) is not None)
    chk('a hero who is not on our team is not an ally witness',
        vision_witness([vev[1]], 'lich', 2, set(), 100.0) is None)
    chk('a witness outside the lookback does not count',
        vision_witness([vev[3]], 'lich', 2, {'zuus'}, 100.0) is None)
    chk('no witness returns None, which the audit must read as UNSETTLED '
        'and never as "was in fog"',
        vision_witness([], 'lich', 2, {'zuus'}, 100.0) is None)

    # ---- strata / verdict -------------------------------------------------
    def mk(game, leg, side, band_, retreat, lethal, died=False):
        return dict(game=game, leg=leg, arm_side=side, band=band_,
                    retreat=retreat, lethal_obs=lethal, died_in_channel=died,
                    dest='died' if died else ('home' if retreat else 'field'))

    # a clean WORKING world: deficit only in the domain, both layers
    world = []
    for side in ('radiant', 'dire'):
        for i in range(10):
            world.append(mk('g%s%d' % (side, i), 'baseline', side, 'mid_gap',
                            True, True, died=True))
            world.append(mk('g%s%d' % (side, i), 'armed', side, 'walk_guard',
                            True, False))
            world.append(mk('g%s%d' % (side, i), 'baseline', side,
                            'walk_guard', True, False))
    ret = lambda r: r['retreat']                                  # noqa: E731
    st = {'domain': layered(world, lambda r: (r['band'] == 'mid_gap'
                                              and r['retreat']
                                              and r['lethal_obs']), ret),
          'control_onface': layered(world, lambda r: (r['band'] == 'walk_guard'
                                                      and r['retreat']), ret),
          'control_noband': layered(world, lambda r: (r['band'] == 'far'
                                                      and r['retreat']), ret)}
    v, _why = verdict(st)
    chk('a world where only the domain empties reads WORKING', v == 'WORKING',
        v)

    # SILENT: armed presses the domain just as often
    world2 = list(world) + [mk('g%s%d' % (s, i), 'armed', s, 'mid_gap', True,
                               True, died=True)
                            for s in ('radiant', 'dire') for i in range(10)]
    st2 = dict(st)
    st2['domain'] = layered(world2, lambda r: (r['band'] == 'mid_gap'
                                               and r['retreat']
                                               and r['lethal_obs']), ret)
    v2, _ = verdict(st2)
    chk('a world where armed presses just as often reads SILENT',
        v2 == 'SILENT', v2)

    # BUGGY: the deficit is everywhere, so it is not this guard
    world3 = [r for r in world if not (r['leg'] == 'armed'
                                       and r['band'] == 'walk_guard')]
    st3 = {'domain': st['domain'],
           'control_onface': layered(world3,
                                     lambda r: (r['band'] == 'walk_guard'
                                                and r['retreat']), ret),
           'control_noband': st['control_noband']}
    v3, _ = verdict(st3)
    chk('a deficit that also empties tpsafe\'s turf reads BUGGY (some other '
        'id in the bundle)', v3 == 'BUGGY', v3)

    # REFUSE: nothing to refuse
    st4 = {'domain': layered([r for r in world if not r['lethal_obs']],
                             lambda r: (r['band'] == 'mid_gap'
                                        and r['retreat'] and r['lethal_obs']),
                             ret),
           'control_onface': st['control_onface'],
           'control_noband': st['control_noband']}
    v4, _ = verdict(st4)
    chk('an empty baseline sub-domain REFUSES rather than reading WORKING',
        v4 == 'REFUSE', v4)

    # REFUSE: ab and ba disagree
    # radiant presses the domain MORE when armed, dire not at all: the layers
    # point opposite ways while the pooled delta is still negative.  The extra
    # rows go on games that already exist, so the denominator does not move
    # and the disagreement is the only thing being tested.
    world5 = list(world)
    world5 += [mk('gradiant%d' % (i % 10), 'armed', 'radiant', 'mid_gap',
                  True, True, died=True) for i in range(15)]
    st5 = dict(st)
    st5['domain'] = layered(world5, lambda r: (r['band'] == 'mid_gap'
                                               and r['retreat']
                                               and r['lethal_obs']), ret)
    v5, _ = verdict(st5)
    chk('ab and ba disagreeing on the sign REFUSES (铁律 4 (i))',
        v5 == 'REFUSE', v5)

    # layered() must actually split, not pool
    lay = layered(world, lambda r: (r['band'] == 'mid_gap' and r['retreat']
                                    and r['lethal_obs']), ret)
    chk('layered() reports radiant and dire separately, not pooled twice',
        lay['radiant']['baseline']['n'] == 10
        and lay['POOLED']['baseline']['n'] == 20)
    chk('same_sign is False when a layer is flat (no free sign from zero)',
        same_sign({'radiant': {'armed': {'share': 1.0},
                               'baseline': {'share': 1.0}},
                   'dire': {'armed': {'share': 0.0},
                            'baseline': {'share': 1.0}}}) is False)

    # (run, game) keying -- the W14 name-collision hazard
    coll = [mk('same_name', 'baseline', 'radiant', 'mid_gap', True, True),
            mk('same_name', 'baseline', 'radiant', 'mid_gap', True, True)]
    coll[0]['run'], coll[1]['run'] = 'runA', 'runB'
    c = cell(coll, lambda r: True)
    chk('two runs that stamped the same game name count as TWO games, not one'
        ' (W14 collided on 10 of 132)', c['baseline']['games'] == 2,
        c['baseline']['games'])
    nokey = [dict(r) for r in coll]
    for r in nokey:
        r.pop('run')
    chk('a row with no run tag still counts (the key falls back to None, it '
        'does not raise)', cell(nokey, lambda r: True)['baseline']['games'] == 1)

    # RETREAT_DESTS must exclude from_home, or a hero standing in his own
    # fountain reads as a retreat press
    chk('from_home is not a retreat destination',
        'from_home' not in RETREAT_DESTS and 'field' not in RETREAT_DESTS)

    print('\n  %d PASS / %d FAIL' % (ok, fail))
    return fail == 0


def _read_source_from(text):
    """read_source() against an in-memory Lua body (selfcheck only)."""
    import tempfile
    global JMZ
    keep = JMZ
    fd, p = tempfile.mkstemp(suffix='.lua')
    try:
        with os.fdopen(fd, 'w') as fh:
            fh.write(text)
        JMZ = p
        return read_source()
    finally:
        JMZ = keep
        os.unlink(p)


def _rejects(fn):
    try:
        fn()
    except SC.SourceConstantError:
        return True
    except Exception:
        return False
    return False


if __name__ == '__main__':
    main()

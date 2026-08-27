#!/usr/bin/env python3
"""Domain + execution reading for the two turbo-scaled buyback floors:
`bbshort` (GH #222) and `bbfight` (GH #215).

WHY THIS TOOL EXISTS
--------------------
Both ids move a NORMAL-mode respawn duration inside a mode that scaled every
respawn by 0.75.  Their shared header in `bots/FunLib/jmz_func.lua` rests the
whole argument on two engine facts and says of them, verbatim:

    "Two documented engine facts, neither of them observable from a dump and
     both named here so a ratchet can pin them:
       * the hero respawn table runs from 12s at level 1 up to 100s at level 25
         ...
       * turbo makes respawn 25% faster.
     The turbo CEILING is therefore 100 * 0.75 = 75 seconds"

The 75-second ceiling is what makes `bbfight`'s unarmed rung (`remaining > 80`)
a *structural* zero rather than a rare one, and it is what bounds `bbshort`'s
domain.  **The clause "neither of them observable from a dump" is false.**  A
death span -- DEATH event to the respawn frame -- is exactly a realised respawn
duration, and this directory has carried an audited span builder since GH #78
(`roam_conversion.death_spans`).  So the ceiling can be MEASURED, and the two
ids' domains can be measured with it, instead of being asserted.

That distinction is not cosmetic.  If the real ceiling is at or under 75 the
header's zero holds and `bbfight` is a lever whose unarmed side cannot fire; if
it is above 80 the unarmed rung is reachable and `bbfight` stops being an
"open a structural zero" fix and becomes a "change an existing decision" fix --
a different id class with a different read.  Nothing in the tree distinguished
those two worlds before this tool.

WHAT IS AND IS NOT OBSERVABLE HERE
----------------------------------
Observable (result side): death spans, hero level at death, whether a span is
far shorter than its level's realised respawn (the buyback signature).
NOT observable: `bot:GetRespawnTime()`'s return value at any given frame, and
therefore which of the two readings of it (GH #208: FULL vs REMAINING) the
engine implements.  Both readings are carried through as two columns rather
than picked -- the header says the finding does not depend on the choice, and
this tool is not the place that settles it.

CONFOUNDS EXCLUDED (each one cost a real round elsewhere in this directory)
--------------------------------------------------------------------------
* **Illusions** (GH #176): frames are keyed by ENTITY, via `entities`, not by
  hero name.  An illusion shares the name and the player_id.
* **Wraith King reincarnates in place** (charter tool-trap, 2026-08-21): his
  ult produces a ~3s "span" that is not a respawn at all.  Any span shorter
  than `REINCARNATION_MAX_S` is reported separately and never enters the
  respawn table.  `skeleton_king` is additionally flagged per span.
* **Aegis** does the same thing for whoever carries it.
* **Truncation**: a hero dead when the dump ends has an unresolved span
  (`tr == inf`).  Those are counted and dropped, never clamped to the end.
* **1 Hz sampling**: the respawn frame is the FIRST sample at or after the real
  respawn, so every measured span is an OVER-estimate by up to one sample
  interval.  That is the safe direction for a CEILING claim (it can only make
  the measured ceiling too high, i.e. it cannot manufacture a false "the
  ceiling holds") and the wrong direction for a FLOOR claim, so floors are
  never claimed from it.
"""
import argparse
import collections
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402

LUA_JMZ = 'bots/FunLib/jmz_func.lua'
LUA_AIU = 'bots/ability_item_usage_generic.lua'

# A span this short is a revive-in-place (WK reincarnation ~3s, aegis ~5s), not
# a respawn.  The shortest turbo respawn possible is 12 * 0.75 = 9s at level 1,
# and the ladder itself is shut below level 16, so this threshold cannot eat a
# real respawn in the domain we read.
REINCARNATION_MAX_S = 8.0

# A frame belongs to the CORPSE RUN if health is at the floor and the unit has
# not moved from where it fell.  `hp_pct` is not exactly 0 on every corpse frame
# -- GH #78 measured a one-sample leak carrying the last live value -- so the
# health side is a band, not an equality, and the position side is what makes
# the pair decisive.
CORPSE_HP_MAX = 0.05
CORPSE_MOVE_MAX = 25.0

# KNOWN LIMIT OF THE CORPSE-RUN BOUND, frame-verified rather than assumed.
# A hero who is ALIVE, stationary and under CORPSE_HP_MAX looks exactly like a
# corpse to the pair above, so the walk-back runs past the real death and the
# bound inflates.  Measured on the one W16 span where it mattered --
# `5e1086/20260827_064305_slot4` drow_ranger L27, corpse-run bound 83.0s:
# the hero is frozen at (-3021.5, 2317.9) from t<=1415.5 while Roshan grinds
# her from hp_pct 0.107 down, crossing 0.05 at t=1419.5 and reaching 0.000 at
# t=1427.5.  The DEATH event (t=1426.4) is right and the bound is 6.9s early.
# The DAMAGE stream settles it independently and exactly: Roshan lands 66 at
# t=1425.4 and a fatal 33 at t=1426.4, so the hero was alive at 1425.4 and the
# real span is 76.1s, not 83.0s.  The damage witness is deliberately NOT folded
# into the bound: DAMAGE events carry a hero NAME, and an illusion's damage
# would move the bound the ANTI-conservative way (GH #176).  Report the outlier
# and resolve it by hand instead of contaminating every row to fix one.
CORPSE_RUN_LIMIT = 'alive + stationary + <=5% HP is indistinguishable from a corpse'

# `BuybackUsageComplement` returns immediately at or below this level, so the
# whole ladder -- both ids -- is unreachable under it.  Read from source.
LADDER_MIN_LEVEL_FALLBACK = 15


def repo_root(start=None):
    d = start or os.path.dirname(os.path.abspath(__file__))
    while d != '/':
        if os.path.isdir(os.path.join(d, 'bots', 'FunLib')):
            return d
        d = os.path.dirname(d)
    raise RuntimeError('repo root not found')


# ---------------------------------------------------------------- source read

class SourceFacts(object):
    """Every constant this tool reasons with, read from the Lua rather than
    retyped here.  A retyped constant is a constant that drifts silently: this
    directory has already lost a round to one (GH #230), so each field below
    RAISES if its line is gone rather than falling back to a literal."""

    def __init__(self, jmz, aiu):
        self.table_max = self._num(jmz, r'J\.RESPAWN_TABLE_MAX\s*=\s*([0-9.]+)',
                                   'J.RESPAWN_TABLE_MAX')
        self.turbo_factor = self._num(
            jmz, r'J\.TURBO_RESPAWN_FACTOR\s*=\s*([0-9.]+)',
            'J.TURBO_RESPAWN_FACTOR')
        self.fight_floor = self._num(jmz, r'J\.BUYBACK_FIGHT_FLOOR\s*=\s*([0-9.]+)',
                                     'J.BUYBACK_FIGHT_FLOOR')
        self.short_floor = self._num(jmz, r'J\.BUYBACK_SHORT_FLOOR\s*=\s*([0-9.]+)',
                                     'J.BUYBACK_SHORT_FLOOR')

        # Each gate must be a SINGLE soak id conjoined with the mode predicate.
        # Two ids in one gate is the GH #207 freeze shape: promoting either one
        # pins the gate false forever, and `check_armed_wiring.py` still calls
        # it WIRED because a call site exists.
        self.fight_ids = self._gate_ids(jmz, 'J.BuybackFightRespawnFloor')
        self.short_ids = self._gate_ids(jmz, 'J.BuybackShortRespawnFloor')

        # The level clause of the fight rung, and the ladder's entry guard.
        self.fight_min_level = self._num(
            aiu, r'if\s+bot:GetLevel\(\)\s*>\s*([0-9]+)\s*\n\s*and\s+'
                 r'nRemainingRespawnTime\s*>\s*J\.BuybackFightRespawnFloor',
            'fight rung level clause')
        self.ladder_min_level = self._num(
            aiu, r'if\s+bot:GetLevel\(\)\s*<=\s*([0-9]+)', 'ladder entry guard')

        # Call sites: exactly one each, and the short floor's `return` must
        # still sit ABOVE the fight rung.  If that order ever flips, `bbshort`
        # stops gating `bbfight`'s reachability and every co-armed reading
        # taken with this tool silently changes meaning.
        self.fight_sites = len(re.findall(r'J\.BuybackFightRespawnFloor\(\)', aiu))
        self.short_sites = len(re.findall(r'J\.BuybackShortRespawnFloor\(\)', aiu))
        i_short = aiu.find('nFullRespawnTime < J.BuybackShortRespawnFloor()')
        i_fight = aiu.find('nRemainingRespawnTime > J.BuybackFightRespawnFloor()')
        self.short_above_fight = -1 < i_short < i_fight

        errs = []
        if self.fight_ids != ['bbfight']:
            errs.append('fight gate ids != [bbfight]: %r' % (self.fight_ids,))
        if self.short_ids != ['bbshort']:
            errs.append('short gate ids != [bbshort]: %r' % (self.short_ids,))
        if self.fight_sites != 1:
            errs.append('fight floor call sites = %d, expected 1' % self.fight_sites)
        if self.short_sites != 1:
            errs.append('short floor call sites = %d, expected 1' % self.short_sites)
        if not self.short_above_fight:
            errs.append('short-floor return no longer sits above the fight rung')
        self.errors = errs

    @staticmethod
    def _num(text, pattern, what):
        m = re.search(pattern, text)
        if not m:
            raise RuntimeError('could not read %s from source' % what)
        return float(m.group(1))

    @staticmethod
    def _gate_ids(text, fname):
        m = re.search(r'function\s+' + re.escape(fname) + r'\(\)(.*?)\nend', text,
                      re.S)
        if not m:
            raise RuntimeError('function %s not found' % fname)
        return re.findall(r"IsSoakCandidate\(\s*'([^']+)'\s*\)", m.group(1))

    # Derived, in the header's own arithmetic -- so that a changed constant
    # moves the prediction instead of silently invalidating a comment.
    @property
    def turbo_ceiling(self):
        return self.table_max * self.turbo_factor

    @property
    def armed_fight_floor(self):
        return self.fight_floor * self.turbo_factor

    @property
    def armed_short_floor(self):
        return self.short_floor * self.turbo_factor


def load_source(root=None, jmz_text=None, aiu_text=None):
    if jmz_text is None or aiu_text is None:
        root = root or repo_root()
        jmz_text = open(os.path.join(root, LUA_JMZ)).read()
        aiu_text = open(os.path.join(root, LUA_AIU)).read()
    return SourceFacts(jmz_text, aiu_text)


# ---------------------------------------------------------------- span build

def level_at(frames, t):
    """Hero level on the last sample at or BEFORE t -- bracketed, never
    interpolated.  Level is a step function; interpolating one produces values
    like 10.4 that no frame ever held (the `abilanc` lesson, 2026-08-26)."""
    lo = None
    for s in frames:
        if s['t'] <= t:
            lo = s
        else:
            break
    return None if lo is None else int(lo['level'])


def death_spans(tl):
    """[(hero, team, t_death, t_respawn_or_inf, level_at_death)] from DEATH
    events, entity-keyed.  Respawn = first frame with hp back above 0.5 that
    either jumped >1500u (fountain) or is >=1.5s after the death (revive in
    place -- Wraith King, aegis).  Same rule as
    `roam_conversion.death_spans`, kept in step deliberately."""
    frames, team = entities.frames_by_hero(tl)
    t_end = max((e['t'] for e in tl['events']), default=0.0)
    out, open_until = [], collections.defaultdict(lambda: -1e18)
    for e in sorted(tl['events'], key=lambda e: e['t']):
        if e['type'] != 'DEATH' or not e.get('target_hero'):
            continue
        h = entities.canon(e['target'])
        td = e['t']
        if td < open_until[h]:
            continue                       # already inside a known death span
        ff = frames.get(h) or []
        # ANCHOR THE FOUNTAIN-JUMP TEST ON THE CORPSE, NOT ON THE LAST LIVE
        # SAMPLE.  `roam_conversion.death_spans` measures the jump from the last
        # frame at or before the DEATH event -- but that frame can be up to a
        # full sample BEFORE the hero fell, and a hero running at 300+ u/s
        # covers 300u in one sample against a 1500u threshold.
        # Frame-verified on `c1d1cf/20260827_063128_slot8` skeleton_king L19,
        # DEATH t=1081.3: the last live sample is t=1080.5 at (-5397.2, 765.3)
        # while the body lies at t=1081.5 (-5074.9, 796.3).  He REINCARNATES in
        # place at t=1085.5 at (-3744.0, 1184.0) -- 1386u from the corpse, but
        # 1705u from the running frame.  The old anchor calls that a fountain
        # teleport, so a 4.2s Reincarnation enters the clean population as a
        # level-19 respawn, and it was this tool's ONLY buyback candidate on the
        # whole W16 corpus.  The corpse anchor removes it and the count is zero.
        corpse = next(((s['x'], s['y']) for s in ff
                       if s['t'] >= td and s['hp_pct'] <= 0.5), None)
        loc = corpse or next(((s['x'], s['y']) for s in reversed(ff)
                              if s['t'] <= td), None)
        # The DEATH EVENT can lag the hero's actual death (measured on
        # 654032/20260827_061825_slot9 skeleton_king: hp is 0.005 and the
        # position frozen from t=45.4, the DEATH event lands at t=48.6).  A late
        # event makes `span` an UNDER-estimate, which is the unsafe direction for
        # a CEILING claim.  So carry a second, strictly conservative measure
        # alongside it: from the last frame the hero was unambiguously ALIVE.
        # `span_ub >= true respawn duration` always, so a ceiling that holds on
        # span_ub holds outright.
        # The bound must be TIGHT as well as conservative: "last frame above
        # half health" is conservative and useless (a hero can fight at 4% HP
        # for half a minute, and that read gave a 184s "upper bound" on a 76s
        # quantity).  Use the CORPSE RUN instead -- a dead unit's position is
        # frozen and its hp is at the floor -- and walk back from the death
        # event through every frame that is still part of it.  The first frame
        # of that run is the earliest instant the hero can have died, so
        # `tr - t_alive` over-states the true respawn and cannot under-state it.
        t_alive = td
        prev = [s for s in ff if s['t'] <= td]
        if prev:
            dloc = (prev[-1]['x'], prev[-1]['y'])
            for s in reversed(prev):
                if s['hp_pct'] > CORPSE_HP_MAX:
                    break
                if math.hypot(s['x'] - dloc[0], s['y'] - dloc[1]) > CORPSE_MOVE_MAX:
                    break
                t_alive = s['t']
        tr, jumped_at = float('inf'), None
        for s in ff:
            if s['t'] <= td or s['hp_pct'] <= 0.5:
                continue
            jumped = loc is None or math.hypot(
                s['x'] - loc[0], s['y'] - loc[1]) > 1500.0
            if jumped or s['t'] - td >= 1.5:
                tr, jumped_at = s['t'], jumped
                break
        open_until[h] = tr
        resolved = tr != float('inf')
        out.append(dict(hero=h, team=team.get(h), t_death=td, t_respawn=tr,
                        span=(tr - td) if resolved else None,
                        span_ub=((tr - t_alive) if resolved else None),
                        event_lag=(td - t_alive),
                        level=level_at(ff, td), jumped=jumped_at,
                        truncated=(not resolved),
                        t_end=t_end))
    return out


def load_game(tl_path, aj_path):
    tl = json.load(open(tl_path))
    aj = json.load(open(aj_path))
    sv = aj.get('script_version', '')
    if not sv.startswith('mirror:'):
        return None                                    # warmup / unstamped
    armed_side = sv.rsplit(':', 1)[-1]
    m = re.search(r':s([0-9]+):', sv)
    return dict(timeline=tl, armed_team=(2 if armed_side == 'radiant' else 3),
                seed=(m.group(1) if m else '?'), side=armed_side)


# ---------------------------------------------------------------- reductions

def reduce_game(tl, armed_team, seed, side, game, run, facts):
    rows = []
    for sp in death_spans(tl):
        if sp['level'] is None:
            continue
        rows.append(dict(
            run=run, game=game, seed=seed, side=side,
            hero=sp['hero'], team=sp['team'],
            leg=('armed' if sp['team'] == armed_team else 'baseline'),
            t_death=round(sp['t_death'], 1),
            span=(round(sp['span'], 2) if sp['span'] is not None else None),
            span_ub=(round(sp['span_ub'], 2) if sp['span_ub'] is not None else None),
            event_lag=(round(sp['event_lag'], 2)
                       if sp['event_lag'] is not None else None),
            level=sp['level'], truncated=sp['truncated'],
            jumped=sp['jumped'],
            # A revive IN PLACE is short AND does not teleport.  The second
            # half matters: a BUYBACK is also short but returns the hero to the
            # fountain, so folding every short span into this bucket would hide
            # the one outcome this tool exists to look for.  Measured on W16, it
            # also un-mixes 14 level-1 Wraith King FOUNTAIN respawns that a
            # duration-only rule called reincarnations.
            in_place=(sp['span'] is not None
                      and sp['span'] < REINCARNATION_MAX_S
                      and sp['jumped'] is False),
            wk=(sp['hero'] == 'skeleton_king'),
            ladder=(sp['level'] > facts.ladder_min_level),
            fightlevel=(sp['level'] > facts.fight_min_level),
        ))
    return rows


def summarise(rows, facts, out=sys.stdout):
    w = out.write
    total = len(rows)
    trunc = [r for r in rows if r['truncated']]
    inplace = [r for r in rows if r['in_place']]
    clean = [r for r in rows if not r['truncated'] and not r['in_place']]

    w('== corpus ==\n')
    w('death spans           %d\n' % total)
    w('  truncated (dropped) %d\n' % len(trunc))
    w('  revive-in-place     %d   (span < %.1fs; WK/aegis, NOT a respawn)\n'
      % (len(inplace), REINCARNATION_MAX_S))
    w('  clean respawns      %d\n' % len(clean))
    if inplace:
        by = collections.Counter(r['hero'] for r in inplace)
        w('  in-place by hero    %s\n' % dict(by.most_common(6)))
    w('  games / runs        %d / %d\n'
      % (len({(r['run'], r['game']) for r in rows}), len({r['run'] for r in rows})))
    w('\n')

    w('== realised turbo respawn duration by level (the "unobservable" table) ==\n')
    w('%-6s %6s %8s %8s %8s %8s\n' % ('level', 'n', 'min', 'median', 'p95', 'max'))
    per = collections.defaultdict(list)
    for r in clean:
        per[r['level']].append(r['span'])
    for lv in sorted(per):
        v = sorted(per[lv])
        w('%-6d %6d %8.1f %8.1f %8.1f %8.1f\n'
          % (lv, len(v), v[0], v[len(v) // 2], v[min(len(v) - 1, int(.95 * len(v)))],
             v[-1]))
    ceiling = max((r['span'] for r in clean), default=None)
    ub = [r['span_ub'] for r in clean if r['span_ub'] is not None]
    lags = sorted(r['event_lag'] for r in clean if r['event_lag'] is not None)
    w('\npredicted turbo ceiling  = %.1f * %.2f = %.1fs   (header arithmetic)\n'
      % (facts.table_max, facts.turbo_factor, facts.turbo_ceiling))
    w('OBSERVED max clean span  = %s\n'
      % ('%.2fs' % ceiling if ceiling is not None else 'n/a'))
    w('OBSERVED max UPPER-BOUND span = %s   <- from the start of the corpse run,\n'
      % ('%.2fs' % max(ub) if ub else 'n/a'))
    w('   so it over-states the true respawn.  A hero who STANDS STILL at <=5%% HP\n'
      '   inflates it (see CORPSE_RUN_LIMIT); resolve any outlier with the DAMAGE\n'
      '   stream, which witnesses aliveness directly.\n')
    if lags:
        w('DEATH-event lag behind the last live frame: median %.1fs  p95 %.1fs  max %.1fs\n'
          % (lags[len(lags) // 2], lags[min(len(lags) - 1, int(.95 * len(lags)))],
             lags[-1]))
    w('   (1 Hz sampling makes every span an OVER-estimate by <=1 sample; a LATE\n'
      '    DEATH event pushes the other way, which is why span_ub is carried.)\n\n')

    w('== bbfight domain: the level clause ==\n')
    lad = [r for r in clean if r['ladder']]
    fl = [r for r in clean if r['fightlevel']]
    w('deaths above ladder entry (level > %d)  %d\n'
      % (int(facts.ladder_min_level), len(lad)))
    w('deaths at fight-rung level (level > %d) %d\n'
      % (int(facts.fight_min_level), len(fl)))
    if fl:
        sp = sorted(r['span'] for r in fl)
        w('  their spans: min %.1f  median %.1f  max %.1f\n'
          % (sp[0], sp[len(sp) // 2], sp[-1]))
        spu = sorted(r['span_ub'] for r in fl if r['span_ub'] is not None)
        w('  UPPER-BOUND spans: min %.1f  median %.1f  max %.1f\n'
          % (spu[0], spu[len(spu) // 2], spu[-1]) if spu else '')
        w('  spans over the UNARMED floor %.0fs: %d   (upper-bound spans over it: %d)\n'
          % (facts.fight_floor, sum(1 for s in sp if s > facts.fight_floor),
             sum(1 for s in spu if s > facts.fight_floor)))
        w('  spans over the ARMED floor   %.0fs: %d\n'
          % (facts.armed_fight_floor,
             sum(1 for s in sp if s > facts.armed_fight_floor)))
        w('  by leg: armed %d / baseline %d\n'
          % (sum(1 for r in fl if r['leg'] == 'armed'),
             sum(1 for r in fl if r['leg'] == 'baseline')))
    w('\n')

    w('== bbshort domain: spans the armed floor opens ==\n')
    band = [r for r in lad
            if facts.armed_short_floor <= r['span'] < facts.short_floor]
    over = [r for r in lad if r['span'] >= facts.short_floor]
    w('ladder-level deaths with span in [%.0f, %.0f)  %d  <- opened ONLY when armed\n'
      % (facts.armed_short_floor, facts.short_floor, len(band)))
    w('ladder-level deaths with span >= %.0f          %d  <- open either way\n'
      % (facts.short_floor, len(over)))
    w('ladder-level deaths with span <  %.0f          %d  <- shut either way\n'
      % (facts.armed_short_floor,
         sum(1 for r in lad if r['span'] < facts.armed_short_floor)))
    if band:
        w('  band by leg: armed %d / baseline %d\n'
          % (sum(1 for r in band if r['leg'] == 'armed'),
             sum(1 for r in band if r['leg'] == 'baseline')))
        w('  band by physical side: radiant %d / dire %d\n'
          % (sum(1 for r in band if r['team'] == 2),
             sum(1 for r in band if r['team'] == 3)))
    w('\n')

    w('== buyback signature (result side) ==\n')
    # A buyback returns the hero to the fountain long before the table would.
    # Signature: a jump-respawn whose span is far under the level's own
    # realised minimum.  Reported as a per-level shortfall so the reader sees
    # the evidence, not a bare count.
    hits = []
    for r in clean:
        peers = per.get(r['level']) or []
        if len(peers) < 5:
            continue
        floor_lv = sorted(peers)[max(0, int(0.10 * len(peers)))]
        if r['span'] < floor_lv - 10.0:
            hits.append((r, floor_lv))
    w('spans >10s under their own level p10  %d\n' % len(hits))
    for r, f in sorted(hits, key=lambda x: x[0]['span'])[:12]:
        w('  %s/%s %s L%d span %.1f (level p10 %.1f) leg=%s\n'
          % (r['run'][-6:], r['game'], r['hero'], r['level'], r['span'], f,
             r['leg']))
    w('\n')

    w('== iron rule 4(i): ab/ba strata ==\n')
    for label, sel in (('bbfight level domain', lambda r: r['fightlevel']),
                       ('bbshort armed-only band',
                        lambda r: r['ladder'] and
                        facts.armed_short_floor <= r['span'] < facts.short_floor)):
        w('%s\n' % label)
        for st in ('radiant', 'dire'):
            s = [r for r in clean if sel(r) and r['side'] == st]
            a = sum(1 for r in s if r['leg'] == 'armed')
            b = sum(1 for r in s if r['leg'] == 'baseline')
            w('  side=%-8s armed %4d  baseline %4d  delta %+d\n'
              % (st, a, b, a - b))
    return dict(clean=len(clean), ceiling=ceiling,
                fight_level_deaths=len([r for r in clean if r['fightlevel']]),
                short_band=len(band))


# ---------------------------------------------------------------- selfcheck

def _snap(t, hero, idx, team, x=0.0, y=0.0, hp_pct=1.0, level=1):
    return dict(t=t, hero='npc_dota_hero_' + hero, idx=idx, team=team, x=x, y=y,
                hp=100, hp_pct=hp_pct, mp=100, max_mp=100, mp_pct=1.0,
                level=level, player_id=idx % 10, net_worth=1000,
                tp_cd=0, tp_cdlen=60, abilities=[], items=[])


def _death(t, hero):
    return dict(t=t, type='DEATH', actor='npc_dota_hero_other',
                target='npc_dota_hero_' + hero, inflictor='x', value=1,
                actor_hero=True, target_hero=True)


def _tl(snaps, evs):
    return dict(snapshots=snaps, events=evs, game=dict(teams={}), buildings=[],
                creeps=[], wards=[])


SRC_OK_JMZ = """
J.RESPAWN_TABLE_MAX    = 100
J.TURBO_RESPAWN_FACTOR = 0.75
J.BUYBACK_FIGHT_FLOOR  = 80
function J.BuybackFightRespawnFloor()
\tif J.IsModeTurbo() and J.IsSoakCandidate( 'bbfight' ) then
\t\treturn J.BUYBACK_FIGHT_FLOOR * J.TURBO_RESPAWN_FACTOR
\tend
\treturn J.BUYBACK_FIGHT_FLOOR
end
J.BUYBACK_SHORT_FLOOR  = 60
function J.BuybackShortRespawnFloor()
\tif J.IsModeTurbo() and J.IsSoakCandidate( 'bbshort' ) then
\t\treturn J.BUYBACK_SHORT_FLOOR * J.TURBO_RESPAWN_FACTOR
\tend
\treturn J.BUYBACK_SHORT_FLOOR
end
"""

SRC_OK_AIU = """
\tif bot:GetLevel() <= 15
\t\tor bot:HasModifier( 'x' )
\tthen
\t\treturn
\tend
\tif nFullRespawnTime < J.BuybackShortRespawnFloor() then
\t\treturn
\tend
\tif bot:GetLevel() > 24
\t\tand nRemainingRespawnTime > J.BuybackFightRespawnFloor()
\tthen
\t\tbot:ActionImmediate_Buyback()
\tend
"""


def selfcheck():
    ok = [0, 0]

    def check(name, cond):
        ok[0 if cond else 1] += 1
        print('  %-58s %s' % (name, 'PASS' if cond else 'FAIL'))

    def expect_raise(name, fn):
        try:
            fn()
        except Exception:
            check(name, True)
            return
        check(name, False)

    print('-- source facts')
    f = load_source(jmz_text=SRC_OK_JMZ, aiu_text=SRC_OK_AIU)
    check('table max read', f.table_max == 100)
    check('turbo factor read', f.turbo_factor == 0.75)
    check('fight floor read', f.fight_floor == 80)
    check('short floor read', f.short_floor == 60)
    check('turbo ceiling derived, not typed', f.turbo_ceiling == 75.0)
    check('armed fight floor derived', f.armed_fight_floor == 60.0)
    check('armed short floor derived', f.armed_short_floor == 45.0)
    check('fight gate ids', f.fight_ids == ['bbfight'])
    check('short gate ids', f.short_ids == ['bbshort'])
    check('fight level clause read', f.fight_min_level == 24)
    check('ladder entry guard read', f.ladder_min_level == 15)
    check('one call site each', f.fight_sites == 1 and f.short_sites == 1)
    check('short floor sits above fight rung', f.short_above_fight)
    check('clean source yields no errors', f.errors == [])

    print('-- anti-selfskip: each source assertion really goes red')
    # A ratchet that cannot be made to fail is not a ratchet.  Each mutation
    # below is surgical: it changes exactly the line the assertion names.
    two_ids = SRC_OK_JMZ.replace(
        "J.IsSoakCandidate( 'bbfight' )",
        "J.IsSoakCandidate( 'bbfight' ) and J.IsSoakCandidate( 'bbrespawn' )")
    check('two ids in the fight gate is caught (GH #207 freeze shape)',
          load_source(jmz_text=two_ids, aiu_text=SRC_OK_AIU).errors != [])
    swapped = SRC_OK_AIU.replace(
        '\tif nFullRespawnTime < J.BuybackShortRespawnFloor() then\n\t\treturn\n\tend\n', '')
    swapped += '\n\tif nFullRespawnTime < J.BuybackShortRespawnFloor() then\n\t\treturn\n\tend\n'
    check('short-floor return moved BELOW the fight rung is caught',
          load_source(jmz_text=SRC_OK_JMZ, aiu_text=swapped).errors != [])
    check('an extra fight call site is caught',
          load_source(jmz_text=SRC_OK_JMZ,
                      aiu_text=SRC_OK_AIU + '\nJ.BuybackFightRespawnFloor()\n'
                      ).errors != [])
    expect_raise('a deleted constant RAISES, never falls back to a literal',
                 lambda: load_source(
                     jmz_text=SRC_OK_JMZ.replace('J.TURBO_RESPAWN_FACTOR = 0.75',
                                                 ''),
                     aiu_text=SRC_OK_AIU))
    expect_raise('a deleted level clause RAISES',
                 lambda: load_source(jmz_text=SRC_OK_JMZ,
                                     aiu_text=SRC_OK_AIU.replace(
                                         'bot:GetLevel() > 24', 'bot:GetLevel() > X')))

    print('-- span builder')
    # plain fountain respawn: death at 100, corpse, respawn 160 with a big jump
    snaps = ([_snap(-10.0, 'lina', 11, 2, x=0, y=0, level=1)]
             + [_snap(t, 'lina', 11, 2, x=0, y=0, level=20) for t in range(90, 100)]
             + [_snap(t, 'lina', 11, 2, x=0, y=0, hp_pct=0.0, level=20)
                for t in range(101, 160)]
             + [_snap(t, 'lina', 11, 2, x=6000, y=6000, level=20)
                for t in range(160, 200)])
    sp = death_spans(_tl(snaps, [_death(100, 'lina')]))
    check('one span found', len(sp) == 1)
    check('span duration is death->respawn', sp and abs(sp[0]['span'] - 60) < 1e-6)
    check('level bracketed at death', sp and sp[0]['level'] == 20)
    check('fountain jump recorded', sp and sp[0]['jumped'] is True)

    # level is a STEP function: a level-up mid-corpse must not interpolate
    snaps2 = [dict(s) for s in snaps]
    for s in snaps2:
        if s['t'] >= 160:
            s['level'] = 21
    sp2 = death_spans(_tl(snaps2, [_death(100, 'lina')]))
    check('level at death unaffected by a post-respawn level-up',
          sp2 and sp2[0]['level'] == 20)

    # WK reincarnation: revive in place, 3.5s, no jump
    wk = ([_snap(-10.0, 'skeleton_king', 21, 2, level=1)]
          + [_snap(t, 'skeleton_king', 21, 2, level=20) for t in range(90, 100)]
          + [_snap(t, 'skeleton_king', 21, 2, hp_pct=0.0, level=20)
             for t in (101, 102, 103)]
          + [_snap(t, 'skeleton_king', 21, 2, x=48, y=0, level=20)
             for t in range(104, 140)])
    spw = death_spans(_tl(wk, [_death(100.0, 'skeleton_king')]))
    check('WK in-place revive is found as a span at all (not 28s of false death)',
          spw and spw[0]['span'] is not None and spw[0]['span'] < 8)
    check('WK revive is NOT a fountain jump', spw and spw[0]['jumped'] is False)
    rows = reduce_game(_tl(wk, [_death(100.0, 'skeleton_king')]), 2, '1', 'radiant',
                       'g', 'r', f)
    check('WK in-place revive is flagged in_place and kept OUT of the table',
          rows and rows[0]['in_place'] is True)
    # A short span that DID teleport is a buyback shape, not a reincarnation:
    # it must stay in the clean population so the buyback signature can see it.
    bb = ([_snap(-10.0, 'sven', 51, 2, level=1)]
          + [_snap(t, 'sven', 51, 2, level=25) for t in range(90, 100)]
          + [_snap(t, 'sven', 51, 2, hp_pct=0.0, level=25) for t in (101, 102)]
          + [_snap(t, 'sven', 51, 2, x=9000.0, y=9000.0, level=25)
             for t in range(103, 160)])
    rb = reduce_game(_tl(bb, [_death(100, 'sven')]), 2, '1', 'radiant', 'g', 'r', f)
    check('a SHORT span that teleported is NOT called a revive-in-place',
          rb and rb[0]['in_place'] is False and rb[0]['jumped'] is True)
    # The anchor bug, reproduced synthetically at the measured geometry: a hero
    # sprinting when he dies, reviving IN PLACE 1386u from where the body fell
    # but 1705u from the last live sample.
    run = ([_snap(-10.0, 'skeleton_king', 61, 3, level=1)]
           + [_snap(t, 'skeleton_king', 61, 3, x=-5397.2 + (t - 99) * 322.3,
                    y=765.3 + (t - 99) * 31.0, level=19) for t in (98, 99)]
           + [_snap(t, 'skeleton_king', 61, 3, x=-5074.9, y=796.3, hp_pct=0.0,
                    level=19) for t in (101, 102, 103)]
           + [_snap(t, 'skeleton_king', 61, 3, x=-3744.0, y=1184.0, level=19)
              for t in range(104, 160)])
    rr = death_spans(_tl(run, [_death(100.0, 'skeleton_king')]))
    check('jump is measured from the CORPSE, so a sprinting death does not fake one',
          rr and rr[0]['jumped'] is False)
    rrows = reduce_game(_tl(run, [_death(100.0, 'skeleton_king')]), 3, '1', 'dire',
                        'g', 'r', f)
    check('...and the Reincarnation therefore stays OUT of the respawn table',
          rrows and rrows[0]['in_place'] is True)

    # truncation: hero still dead when the dump ends
    tr = ([_snap(-10.0, 'lina', 11, 2, level=1)]
          + [_snap(t, 'lina', 11, 2, level=20) for t in range(90, 100)]
          + [_snap(t, 'lina', 11, 2, hp_pct=0.0, level=20) for t in range(101, 120)])
    spt = death_spans(_tl(tr, [_death(100, 'lina')]))
    check('unresolved span is truncated, never clamped to the end',
          spt and spt[0]['truncated'] is True and spt[0]['span'] is None)

    # GH #176: an illusion must not be able to supply the respawn frame
    ill = ([_snap(-10.0, 'lina', 11, 2, level=1)]
           + [_snap(t, 'lina', 11, 2, level=20) for t in range(90, 100)]
           + [_snap(t, 'lina', 11, 2, hp_pct=0.0, level=20) for t in range(101, 160)]
           + [_snap(t, 'lina', 99, 2, x=6000, y=6000, level=20)   # illusion, born t=105
              for t in range(105, 160)]
           + [_snap(t, 'lina', 11, 2, x=6000, y=6000, level=20) for t in range(160, 200)])
    spi = death_spans(_tl(ill, [_death(100, 'lina')]))
    check('post-horn illusion entity dropped; span still 60s, not 5s',
          spi and abs(spi[0]['span'] - 60) < 1e-6)

    # two deaths, second inside the first span, must not double-count
    dd = death_spans(_tl(snaps, [_death(100, 'lina'), _death(130, 'lina')]))
    check('a DEATH inside an open span does not open a second span', len(dd) == 1)

    # A LATE death event must not shorten the conservative bound.  Same corpse
    # frames, event stamped 4s after the hero was last alive.
    late = death_spans(_tl(snaps, [_death(103.5, 'lina')]))
    check('a late DEATH event does shorten the raw span',
          late and abs(late[0]['span'] - 56.5) < 1e-6)
    check('span_ub is measured from the corpse run, so it does NOT shorten',
          late and abs(late[0]['span_ub'] - 59.0) < 1e-6)
    check('span_ub >= span always (it is an upper bound)',
          late and late[0]['span_ub'] >= late[0]['span'])
    check('event lag is reported, not silently absorbed',
          late and abs(late[0]['event_lag'] - 2.5) < 1e-6)
    # ...but a hero who lingers at 4% HP WITHOUT MOVING does inflate it, and
    # that limit is asserted here rather than left for a reader to discover.
    still = ([_snap(-10.0, 'drow_ranger', 41, 2, level=1)]
             + [_snap(t, 'drow_ranger', 41, 2, x=500.0, hp_pct=0.04, level=27)
                for t in range(80, 100)]
             + [_snap(t, 'drow_ranger', 41, 2, x=500.0, hp_pct=0.0, level=27)
                for t in range(101, 160)]
             + [_snap(t, 'drow_ranger', 41, 2, x=9000.0, y=9000.0, level=27)
                for t in range(160, 200)])
    sps = death_spans(_tl(still, [_death(100, 'drow_ranger')]))
    check('CORPSE_RUN_LIMIT is real: a still, alive, <=5%% HP hero inflates the bound',
          sps and sps[0]['span_ub'] > sps[0]['span'] + 15)
    check('...and the raw DEATH-event span is unaffected by it',
          sps and abs(sps[0]['span'] - 60) < 1e-6)
    check('a hero who lingered at 4% HP does not inflate the bound',
          abs(death_spans(_tl(
              [_snap(-10.0, 'sven', 31, 2, level=1)]
              + [_snap(t, 'sven', 31, 2, x=t * 30.0, hp_pct=0.04, level=20)
                 for t in range(60, 100)]
              + [_snap(t, 'sven', 31, 2, x=2970.0, hp_pct=0.0, level=20)
                 for t in range(101, 160)]
              + [_snap(t, 'sven', 31, 2, x=9000.0, y=9000.0, level=20)
                 for t in range(160, 200)],
              [_death(100, 'sven')]))[0]['span_ub'] - 61.0) < 1e-6)
    check('a truncated span has no upper bound either (never clamped)',
          spt and spt[0]['span_ub'] is None)

    print('-- classification')
    r = reduce_game(_tl(snaps, [_death(100, 'lina')]), 2, '1', 'radiant', 'g', 'r', f)
    check('team 2 with armed_team 2 is the armed leg', r[0]['leg'] == 'armed')
    r2 = reduce_game(_tl(snaps, [_death(100, 'lina')]), 3, '1', 'dire', 'g', 'r', f)
    check('team 2 with armed_team 3 is the baseline leg', r2[0]['leg'] == 'baseline')
    check('level 20 is above the ladder entry but below the fight rung',
          r[0]['ladder'] is True and r[0]['fightlevel'] is False)
    hi = [dict(s, level=25) for s in snaps]
    r3 = reduce_game(_tl(hi, [_death(100, 'lina')]), 2, '1', 'radiant', 'g', 'r', f)
    check('level 25 clears the fight rung level clause (> 24)',
          r3[0]['fightlevel'] is True)
    lo = [dict(s, level=15) for s in snaps]
    r4 = reduce_game(_tl(lo, [_death(100, 'lina')]), 2, '1', 'radiant', 'g', 'r', f)
    check('level 15 is shut out of the ladder entirely (<= 15)',
          r4[0]['ladder'] is False)

    print('\n%d PASS / %d FAIL' % (ok[0], ok[1]))
    return 0 if ok[1] == 0 else 1


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('sweep_dirs', nargs='*',
                    help='.sweep_out/<run> directories (timelines/ + analysis/)')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--source', action='store_true',
                    help='print the source-read constants and exit (zero corpus)')
    ap.add_argument('--dump-rows', metavar='PATH',
                    help='write every span as jsonl for frame-level follow-up')
    a = ap.parse_args()

    if a.selfcheck:
        return selfcheck()

    facts = load_source()
    if a.source:
        print('RESPAWN_TABLE_MAX      %.0f' % facts.table_max)
        print('TURBO_RESPAWN_FACTOR   %.2f' % facts.turbo_factor)
        print('turbo ceiling (derived)%7.1f' % facts.turbo_ceiling)
        print('BUYBACK_FIGHT_FLOOR    %.0f  -> armed %.0f  (bbfight)'
              % (facts.fight_floor, facts.armed_fight_floor))
        print('BUYBACK_SHORT_FLOOR    %.0f  -> armed %.0f  (bbshort)'
              % (facts.short_floor, facts.armed_short_floor))
        print('fight rung level       > %.0f' % facts.fight_min_level)
        print('ladder entry           > %.0f' % facts.ladder_min_level)
        print('gate ids               fight=%r short=%r'
              % (facts.fight_ids, facts.short_ids))
        print('source errors          %r' % (facts.errors,))
        return 1 if facts.errors else 0
    if facts.errors:
        sys.stderr.write('SOURCE ASSERTION FAILED:\n  %s\n'
                         % '\n  '.join(facts.errors))
        return 2

    rows, skipped = [], 0
    for d in a.sweep_dirs:
        run = os.path.basename(d.rstrip('/'))
        tld = os.path.join(d, 'timelines')
        if not os.path.isdir(tld):
            continue
        for fn in sorted(os.listdir(tld)):
            if not fn.endswith('.timeline.json'):
                continue
            game = fn[:-len('.timeline.json')]
            aj = os.path.join(d, 'analysis', game + '.analysis.json')
            if not os.path.exists(aj):
                skipped += 1
                continue
            g = load_game(os.path.join(tld, fn), aj)
            if g is None:
                skipped += 1
                continue
            rows.extend(reduce_game(g['timeline'], g['armed_team'], g['seed'],
                                    g['side'], game, run, facts))
    sys.stderr.write('[bbfloor] %d spans from %d games (%d skipped)\n'
                     % (len(rows), len({(r['run'], r['game']) for r in rows}),
                        skipped))
    if a.dump_rows:
        with open(a.dump_rows, 'w') as fh:
            for r in rows:
                fh.write(json.dumps(r) + '\n')
    summarise(rows, facts)
    return 0


if __name__ == '__main__':
    sys.exit(main())

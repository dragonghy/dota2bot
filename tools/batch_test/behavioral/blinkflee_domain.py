#!/usr/bin/env python3
"""`blinkflee` condition (a): does the armed leg actually WITHHOLD the retreat blink?

WHY THIS FILE EXISTS (replay-check 2026-08-29)
----------------------------------------------
`blinkflee` has been armed since W-era 2026-08-20 and, at the time this file
was written, had **zero** verification records in the stream charter -- one of
only six armed ids in the W24 set (42 ids) in that state.  Every other tool in
this directory that touches a blink is about `axeblink` (the OFFENSIVE branch);
`axe_blink_domain.py:56` says so in as many words ("the retreat branch
(`blinkflee`'s domain, not this gate's)").  Nothing measured the retreat branch.

THE LEVER
---------
`bots/FunLib/jmz_func.lua`:

    function J.ShouldHoldBlinkFlee( bot )
        if not J.IsModeTurbo() then return false end
        if not J.IsSoakCandidate( 'blinkflee' ) then return false end
        ...
        if bot:GetHealth() / nMax < 0.70 then return false end
        if bot:WasRecentlyDamagedByAnyHero( 2.0 ) then return false end
        return true
    end

consumed at exactly ONE site, `bots/ability_item_usage_generic.lua:1575`, as
the last conjunct of the RETREAT branch of `X.ConsiderItemDesire['item_blink']`:

    if J.IsRetreating(bot) and not J.IsRealInvisible(bot)
       and bot:GetActiveModeDesire() > BOT_MODE_DESIRE_MODERATE then
        local vLocation = J.GetLocationTowardDistanceLocation(
                              bot, GetAncient(GetTeam()):GetLocation(), nCastRange)
        local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)
        if bot:DistanceFromFountain() > 900
           and IsLocationPassable(vLocation)
           and (#nInRangeAlly <= 1 or ...)
           and nInRangeEnemy ~= nil and #nInRangeEnemy >= 1
           and not J.ShouldHoldBlinkFlee(bot)
        then return BOT_ACTION_DESIRE_HIGH, vLocation, 'ground', nil end
    end

So this is a **SUPPRESSION**: armed can only ever cast a strict SUBSET of what
baseline casts, and the withheld cast is invisible by construction.  The only
readable shape of condition (a) is therefore a leg CONTRAST on the sub-slice
the gate owns, with the branch's own geometry used to seal attribution.

THE ATTRIBUTION PROBLEM -- AND WHY THE OBVIOUS SEAL DOES NOT HOLD
------------------------------------------------------------------
The first version of this file claimed a seal: the retreat branch is the only
blink that aims at `GetAncient(GetTeam())`, so `cos(displacement, own-ancient
direction) > 0.9` at ~cast range with an enemy inside 1200 identifies it.  Run
on 79 W24 games that seal reported 11 armed-leg casts inside the gate's own
slice and the pre-registered reading printed **BUGGY in both layers**.

Frame-by-frame reconstruction of all 11 killed it.  THREE other blink sites in
the SAME function land homeward, none of them gated by `blinkflee`:

  1. `:1557`  `if J.IsStuck(bot)` -> blink toward the own ancient at nCastRange.
     EXCLUDABLE, arithmetically: `J.IsStuck` needs `TAd > 2200` (distance to the
     bot's OWN ancient) plus <25 u of drift for 5 s.  A cast with
     `d_own_ancient <= 2200` at the pre-cast frame cannot be this branch, and
     the drift is readable off the frames.
  2. `:1614`  `if J.IsProjectileIncoming(bot, 1200)` -> blink toward the own
     ancient at a hardcoded 1199, with NO hp clause, NO damage clause, NO
     fountain-distance clause and NO enemy-count clause.  It sits BELOW the
     retreat branch, so it is reached precisely when the retreat branch did not
     return -- which is what an armed `blinkflee` does.  NOT EXCLUDABLE: the
     dump carries no projectile stream.  The nearest proxy is "an enemy hero
     cast a spell in the last 3 s", printed per cast, and it is a proxy, not a
     test (`p.is_attack` projectiles do not arm it, and a slow projectile can
     outlive the window).
  3. `:1647`  the `J.IsGoingOnSomeone` branch -> blink ONTO `botTarget` at
     `min(nCastRange, dist) + RandomVector(150)`.  This is the one that ends
     the seal: **when the enemy stands between the bot and its own ancient the
     two landings are the same landing.**  Measured, not argued -- on
     `de59cd/20260829_064305_slot9` t=1140.5 (radiant Earthshaker, 100% HP, no
     damage of any kind for 10 s, 1038 u from its own ancient so branch 1 is
     out, no enemy spell cast for 3.5 s so branch 2 is out) the three visible
     enemies sit at cos +0.999 / +1.000 / +0.991 along the own-ancient
     direction, zuus at 1079 u on 17% HP, and Earthshaker had cast Fissure 0.9 s
     earlier.  A kill blink onto that zuus is geometrically identical to a
     retreat blink.  Base defence makes "toward my ancient" and "toward them"
     the same ray, and base defence is where retreat blinks live.

So the geometry identifies a HOMEWARD cast, never a retreat-branch cast.  This
tool therefore reports the funnel and REFUSES to convert it into a verdict; the
`enemy_along_home` and `enemy_cast_3s` columns are printed on every candidate so
the refusal is visible per cast instead of being a sentence in a report.

PRE-REGISTERED READING (written down before looking, GH #168 discipline)
--------------------------------------------------------------------------
The reading below is what this tool would need in order to say anything, and
on the corpus it was written for NONE of it is reachable -- kept verbatim so
the next round can see what was promised and what was delivered:

    armed GATED == 0 and baseline GATED > 0 in BOTH layers -> WORKING
    armed GATED  > 0                                        -> BUGGY
    both legs GATED == 0                                    -> SILENT/empty
    the two layers disagree in sign                         -> noise (铁律 4(i))

Two things override it, both measured on W24:
  * a cast with `enemy_along_home` or `enemy_cast_3s` set is NOT attributable,
    so it can never be the BUGGY witness -- `verdict()` counts those separately
    and calls the result INDETERMINATE rather than BUGGY;
  * the layers DID disagree in sign (ab armed 2 / baseline 15; ba armed 9 /
    baseline 6), so the aggregate contrast is noise by 铁律 4(i) and no effect
    size may be registered from it.

EXIT CODES (GH #171 vocabulary: "could not run" is not "passed")
    0  clean   -- ran, and the armed leg is empty on the gated slice
    2  refused -- could not run (no timelines, source constants unreadable)
    3  findings-- armed leg cast inside the gated slice (BUGGY), or a source
                  constant drifted away from what this file argues about

LIMITS -- READ BEFORE QUOTING A NUMBER
--------------------------------------
1. **The withheld cast is not observable.**  Nothing here counts "times the
   gate fired".  It counts casts that DID happen and asks whether any of them
   sits inside the gate's slice.  `armed == 0` is consistent with the gate
   working AND with the branch never being reached; the retreat-cast counts
   (printed beside it) are what separate those two, and they are a
   DIRECTIONAL argument, not a proof.
2. **1 Hz sampling.**  `-interval` defaults to 1.0 s, so the pre-cast frame is
   up to 1.0 s before the decision.  HP read there is the HP up to a second
   early; in a fight that is a real error bar, and it is why the HP margin is
   printed per cast instead of only the boolean.
3. **`WasRecentlyDamagedByAnyHero` is approximated by the DAMAGE stream** with
   `actor_hero == True`.  Illusion damage: the engine counts it, and the dump
   labels an illusion's damage with the hero name, so this matches -- but it
   also cannot tell an illusion from the body, so a hero-damage read is an
   OVER-count.  Over-counting damage SHRINKS the gated slice on both legs, so
   it can only make this test more conservative, never more permissive.
4. **`IsRetreating` / `GetActiveModeDesire` / `IsRealInvisible` /
   `IsLocationPassable` / `#nInRangeAlly` are not in the dump.**  The four
   geometric conjuncts above are the seal; these five are unread.  Every count
   is therefore an UPPER bound on the true branch domain.
5. **Cast range is read as a band, not a number.**  A cast whose jump falls
   outside [1100, 1700] is counted as unresolved rather than forced into a
   branch; the jump histogram is printed so a drifted band is visible.
6. **Fountain position is estimated** (`wandlimbo_domain.fountain_of`, the
   team's own first 10 sampled seconds -- NOT `t < -60`, which fails one-sided
   for dire; GH #292).  `None` means the filter is skipped for that team and
   the cast is counted, which again only widens the domain.
7. **Illusions share the hero name.**  Entities are idx-locked to the earliest
   first appearance (GH #69/#176) before any position is measured; a cast
   event carries no idx, so it is attributed to the locked body.
8. **This says nothing about whether withholding the blink is GOOD.**  That is
   condition (b)/(c) and belongs to the batch desk and the director.

Read-only.  No AWS spend, no bot Lua touched.  Dev-only tooling.

Usage:
    python3 blinkflee_domain.py TL_DIR            # names carry __<side>.json
    python3 blinkflee_domain.py --selfcheck
"""
import argparse
import collections
import glob
import json
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
from wandlimbo_domain import fountain_of  # noqa: E402  (#263: do not re-copy)

BLINK_ITEM = 'item_blink'
BLINK_SLOT = 'blink_dagger'          # snapshots drop the `item_` prefix
ANCIENT = {2: (-5528.0, -4874.0), 3: (5528.0, 5000.0)}
JUMP_LO, JUMP_HI = 1100.0, 1700.0    # LIMIT 5
COS_HOME = 0.9
ENEMY_RING = 1200.0                  # branch's own `GetEnemiesNearLoc(...,1200)`
FOUNTAIN_MIN = 900.0                 # branch's own `DistanceFromFountain() > 900`
STUCK_ANCIENT_MIN = 2200.0           # J.IsStuck needs BOTH ancients > 2200
HOME_CONE_COS = 0.7                  # an enemy this well aligned with the home
                                     # ray makes a kill blink look like a flee
ENEMY_CAST_WINDOW = 3.0              # proxy for a projectile still in flight
DEAD_WINDOW = 6.0                    # a cast this soon after an hp<=0 frame is
                                     # not read (corpse-freeze, GH #78/#43)
WIN_BACK, WIN_FWD = 1.5, 2.5         # jump-location window around the ITEM event

EXIT_CLEAN, EXIT_REFUSED, EXIT_FINDINGS = 0, 2, 3

LUA_JMZ = 'bots/FunLib/jmz_func.lua'
LUA_AIU = 'bots/ability_item_usage_generic.lua'


def repo_root():
    return os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        '..', '..', '..'))


def hkey(name):
    """Join key for hero names across the event stream and the snapshot stream.

    `entities.canon()` only strips the `npc_dota_hero_` prefix, and the two
    streams DO NOT agree on the rest of the string: measured on W24
    (2026-08-29), events spell Vengeful Spirit `npc_dota_hero_vengefulspirit`
    while snapshots spell it `npc_dota_hero_vengeful_spirit` -- 8,033 actor
    rows and 7,545 target rows in five games with no snapshot counterpart.
    The charter's 2026-08-21 note ("events now carry the full underscored
    name") is therefore true of most heroes and false of at least this one,
    and a `canon()` join drops every Vengeful Spirit row silently.  Filed as a
    [bug] for the shared helper; this tool does not wait for it.
    """
    return entities.canon(name).replace('_', '')


def _fn_body(text, fname):
    """The body of `function <fname>(...)` up to its matching top-level `end`.

    Extracting the BODY before any `findall` is the point: `odaoe_domain.py`
    fed a whole FILE to a two-id search and then reported the GH #207 freeze
    on two ids that live in different functions and never meet (GH #296).
    """
    m = re.search(r'function\s+' + re.escape(fname) + r'\s*\([^)]*\)(.*?)\nend',
                  text, re.S)
    if not m:
        raise RuntimeError('function %s not found' % fname)
    return m.group(1)


class SourceFacts(object):
    """Every constant this file argues about, read off the Lua, never retyped."""

    def __init__(self, jmz_text, aiu_text):
        body = _fn_body(jmz_text, 'J.ShouldHoldBlinkFlee')
        self.gate_ids = re.findall(r"IsSoakCandidate\(\s*'([^']+)'\s*\)", body)
        self.hp_floor = self._num(body, r'GetMaxHealth\(\)\s*\n?.*?<\s*([0-9.]+)',
                                  'hp floor', flags=re.S)
        self.dmg_window = self._num(body, r'WasRecentlyDamagedByAnyHero\(\s*([0-9.]+)',
                                    'damage window')
        self.turbo_gated = 'IsModeTurbo' in body
        self.call_sites = len(re.findall(r'J\.ShouldHoldBlinkFlee\s*\(', aiu_text))
        self.negated_call = bool(re.search(r'not\s+J\.ShouldHoldBlinkFlee\s*\(', aiu_text))
        # BOTH of these must be read out of the RETREAT BRANCH, not out of the
        # file: `DistanceFromFountain() > N` appears 10 times in this file with
        # N in {600, 800, 900} and the first hit is a COURIER's 800.  Same
        # discipline as _fn_body above -- scope first, then match (GH #296).
        branch = self._retreat_branch(aiu_text)
        self.enemy_ring = self._num(branch,
                                    r'GetEnemiesNearLoc\(bot:GetLocation\(\),\s*(\d+)',
                                    'enemy ring')
        self.fountain_min = self._num(branch,
                                      r'bot:DistanceFromFountain\(\)\s*>\s*(\d+)',
                                      'fountain floor')
        self.errors = self._check()

    @staticmethod
    def _retreat_branch(aiu_text):
        """The `if J.IsRetreating(bot)` block that ends at the gate call."""
        m = re.search(r'if\s+J\.IsRetreating\(bot\)(.*?)J\.ShouldHoldBlinkFlee',
                      aiu_text, re.S)
        if not m:
            raise RuntimeError('retreat branch around the gate call not found')
        return m.group(1)

    @staticmethod
    def _num(text, pattern, what, flags=0):
        m = re.search(pattern, text, flags)
        if not m:
            raise RuntimeError('could not read %s from source' % what)
        return float(m.group(1))

    def _check(self):
        errs = []
        # GH #207 family, written the way #296 shows it must be: a SECOND id in
        # THIS function's body would freeze the gate FALSE the day the other id
        # is promoted.  Checked on the body, never on the file.
        if self.gate_ids != ['blinkflee']:
            errs.append('gate ids in J.ShouldHoldBlinkFlee = %r, expected exactly '
                        "['blinkflee'] (a second id freezes it FALSE once the "
                        'other id is promoted -- AGENTS.md pullcad trap)'
                        % (self.gate_ids,))
        if not self.turbo_gated:
            errs.append('J.ShouldHoldBlinkFlee no longer checks IsModeTurbo')
        if abs(self.hp_floor - 0.70) > 1e-9:
            errs.append('hp floor drifted to %s (header argues 0.70)' % self.hp_floor)
        if abs(self.dmg_window - 2.0) > 1e-9:
            errs.append('damage window drifted to %s (header argues 2.0)'
                        % self.dmg_window)
        if self.call_sites != 1:
            errs.append('call sites = %d, expected exactly 1 (the attribution '
                        'seal assumes the retreat branch is the only consumer)'
                        % self.call_sites)
        if not self.negated_call:
            errs.append('the call site is no longer `not J.ShouldHoldBlinkFlee(...)`'
                        ' -- the suppression direction this file assumes is gone')
        if abs(self.enemy_ring - ENEMY_RING) > 1e-9:
            errs.append('branch enemy ring drifted to %s (tool uses %s)'
                        % (self.enemy_ring, ENEMY_RING))
        if abs(self.fountain_min - FOUNTAIN_MIN) > 1e-9:
            errs.append('branch fountain floor drifted to %s (tool uses %s)'
                        % (self.fountain_min, FOUNTAIN_MIN))
        return errs


def load_source(root=None, jmz_text=None, aiu_text=None):
    if jmz_text is None or aiu_text is None:
        root = root or repo_root()
        jmz_text = open(os.path.join(root, LUA_JMZ)).read()
        aiu_text = open(os.path.join(root, LUA_AIU)).read()
    return SourceFacts(jmz_text, aiu_text)


# ------------------------------------------------------------------ frame work

def dist(ax, ay, bx, by):
    return math.hypot(ax - bx, ay - by)


def primary_idx(snapshots):
    """{hero: idx of the REAL body}, keyed on earliest first appearance (GH #69).

    Same rule as axe_blink_domain.primary_idx; kept here because that module's
    copy is bound to `AXE` in its own filters, not because the rule differs.
    """
    first = {}
    for s in snapshots:
        key = (s['hero'], s['idx'])
        if key not in first or s['t'] < first[key]:
            first[key] = s['t']
    out = {}
    for (hero, idx), t0 in first.items():
        if hero not in out or t0 < out[hero][1]:
            out[hero] = (idx, t0)
    return {h: v[0] for h, v in out.items()}


def scan_game(d, armed_team, game='?'):
    """-> list of cast records for one timeline."""
    if not d.get('events'):
        return []
    tmax = max(e['t'] for e in d['events'])           # issue #43: drop the tail
    snaps = [s for s in d['snapshots'] if s['t'] <= tmax]
    prim = primary_idx(snaps)
    snaps = [s for s in snaps if prim.get(s['hero']) == s['idx']]

    by_hero = collections.defaultdict(list)
    for s in snaps:
        by_hero[hkey(s['hero'])].append(s)
    for v in by_hero.values():
        v.sort(key=lambda s: s['t'])
    by_t = collections.defaultdict(list)
    for s in snaps:
        by_t[round(s['t'], 1)].append(s)

    founts = {2: fountain_of(snaps, 2), 3: fountain_of(snaps, 3)}

    # hero damage, canon-keyed on the TARGET (charter: canon both sides or read
    # "32 games zero kills")
    dmg = collections.defaultdict(list)
    for e in d['events']:
        if e['type'] == 'DAMAGE' and e.get('actor_hero') and e.get('target_hero'):
            dmg[hkey(e.get('target', ''))].append(e['t'])
    for v in dmg.values():
        v.sort()

    team_of = {}
    for s2 in snaps:
        team_of.setdefault(hkey(s2['hero']), s2['team'])

    out = []
    for ev in d['events']:
        if ev['type'] != 'ITEM' or ev.get('inflictor') != BLINK_ITEM:
            continue
        hero = hkey(ev.get('actor', ''))
        frames = by_hero.get(hero)
        if not frames:
            continue
        t = ev['t']
        win = [s for s in frames if t - WIN_BACK <= s['t'] <= t + WIN_FWD]
        if len(win) < 2:
            continue
        pre = post = None
        best = -1.0
        for a, b in zip(win, win[1:]):
            step = dist(a['x'], a['y'], b['x'], b['y'])
            if step > best:
                pre, post, best = a, b, step
        team = pre['team']
        ax, ay = ANCIENT[team]
        home = dist(pre['x'], pre['y'], ax, ay)
        cos = 0.0
        if best > 1 and home > 1:
            cos = (((post['x'] - pre['x']) * (ax - pre['x'])
                    + (post['y'] - pre['y']) * (ay - pre['y'])) / (best * home))

        foes = [(round(dist(o['x'], o['y'], pre['x'], pre['y'])),
                 entities.canon(o['hero']))
                for o in by_t[round(pre['t'], 1)]
                if o['team'] != team and o['hp'] > 0]
        foes.sort()
        n_near = len([f for f in foes if f[0] <= ENEMY_RING])

        f = founts.get(team)
        # LIMIT 6: an unestimable fountain widens the domain, never narrows it
        d_fount = dist(pre['x'], pre['y'], f[0], f[1]) if f else None

        # -- the three columns that decide whether this cast is attributable --
        d_anc = dist(pre['x'], pre['y'], ax, ay)
        # J.IsStuck also needs <25 u of drift for 5 s; both are reported so the
        # arithmetic exclusion and the observed one are visible separately.
        pre5 = [s2 for s2 in frames if pre['t'] - 5.0 <= s2['t'] <= pre['t']]
        # An under-sampled window has no drift reading at all.  Recording that
        # as 0.0 would read "stood perfectly still" -- the same shape as the
        # `[:60]` slice that printed as data (charter 2026-08-29T09:48Z), so it
        # is None, and None can only ever LEAVE IsStuck live.
        drift = (max(dist(pre5[0]['x'], pre5[0]['y'], s2['x'], s2['y'])
                     for s2 in pre5)
                 if len(pre5) >= 2 and pre5[-1]['t'] - pre5[0]['t'] >= 4.0
                 else None)
        stuck_possible = (d_anc > STUCK_ANCIENT_MIN
                          and (drift is None or drift < 25.0))
        # branch 3: an enemy sitting ON the home ray makes a kill blink and a
        # flee blink the same displacement (see the header's worked frame)
        hx, hy = (ax - pre['x']), (ay - pre['y'])
        hn = math.hypot(hx, hy) or 1.0
        enemy_along_home = None
        for dd, nm in foes:
            o = [q for q in by_t[round(pre['t'], 1)]
                 if entities.canon(q['hero']) == nm and q['team'] != team]
            if not o or dd < 1:
                continue
            c = (((o[0]['x'] - pre['x']) * hx + (o[0]['y'] - pre['y']) * hy)
                 / (dd * hn))
            if c > HOME_CONE_COS and dd <= JUMP_HI:
                enemy_along_home = (dd, nm, round(c, 3))
                break
        # branch 2 proxy: any enemy hero spell cast in the last ENEMY_CAST_WINDOW
        casts_by_enemy = sorted(
            [(round(e2['t'], 1), hkey(e2.get('actor', '')), e2.get('inflictor'))
             for e2 in d['events']
             if e2['type'] == 'ABILITY' and e2.get('actor_hero')
             and team_of.get(hkey(e2.get('actor', '')), team) != team
             and t - ENEMY_CAST_WINDOW <= e2['t'] <= t], reverse=True)
        recent_cast = casts_by_enemy[0] if casts_by_enemy else None
        # a cast within DEAD_WINDOW of an hp<=0 frame is not read at all
        recently_dead = any(s2['hp'] <= 0 for s2 in frames
                            if t - DEAD_WINDOW <= s2['t'] <= t)

        last_dmg = None
        for td in dmg.get(hero, ()):
            if td <= t:
                last_dmg = td
            else:
                break
        since_dmg = (t - last_dmg) if last_dmg is not None else None

        homeward = (cos > COS_HOME and JUMP_LO <= best <= JUMP_HI
                    and n_near >= 1
                    and (d_fount is None or d_fount > FOUNTAIN_MIN)
                    and not recently_dead)
        hp = pre['hp_pct']
        gated = bool(homeward and hp >= 0.70
                     and (since_dmg is None or since_dmg > 2.0))
        # ATTRIBUTABLE means: of the four homeward blink sites, three are
        # excluded on this frame's own evidence and only the retreat branch is
        # left.  Anything else is INDETERMINATE -- never a BUGGY witness.
        attributable = bool(gated and not stuck_possible
                            and enemy_along_home is None and recent_cast is None)
        out.append({
            'game': game, 'hero': hero, 't': round(t, 1),
            'leg': 'armed' if team == armed_team else 'baseline',
            'team': team,
            'jump': round(best), 'cos': round(cos, 3),
            'hp_pct': round(hp, 3), 'mp': pre['mp'],
            'pre_t': round(pre['t'], 1), 'post_t': round(post['t'], 1),
            'foes_within_1200': n_near,
            'nearest_foe': foes[0] if foes else None,
            'dist_fountain': None if d_fount is None else round(d_fount),
            'dist_own_ancient': round(d_anc),
            'drift_5s': None if drift is None else round(drift),
            'stuck_possible': stuck_possible,
            'enemy_along_home': enemy_along_home,
            'enemy_cast_3s': recent_cast,
            'recently_dead': recently_dead,
            'since_hero_dmg': None if since_dmg is None else round(since_dmg, 2),
            'retreat_branch': bool(homeward),
            'gated_slice': gated,
            'attributable': attributable,
        })
    return out


def side_of(path):
    """`<run>__<game>__<side>.json` -- the stamp side is the ARMED physical team."""
    base = os.path.basename(path)
    m = re.match(r'(.+?)__(.+?)__(radiant|dire)\.json$', base)
    if not m:
        return None, None, None
    return m.group(1), m.group(2), m.group(3)


# ---------------------------------------------------------------------- report

def report(rows, layers, src):
    print('source: gate ids=%r hp_floor=%.2f dmg_window=%.1f call_sites=%d '
          'enemy_ring=%d fountain_min=%d'
          % (src.gate_ids, src.hp_floor, src.dmg_window, src.call_sites,
             int(src.enemy_ring), int(src.fountain_min)))
    print()
    print('== corpus ==')
    for layer, n in sorted(layers.items()):
        print('  %-16s %3d games' % (layer, n))
    print()
    print('== casts by layer x leg (LIMIT 1: GATED counts casts that HAPPENED) ==')
    print('%-6s %-9s %6s %8s %6s %6s %6s %6s %6s'
          % ('layer', 'leg', 'casts', 'homeward', 'GATED', '-stuck', '-along',
             '-cast3s', 'ATTRIB'))
    findings = 0
    for layer in sorted(layers):
        for leg in ('armed', 'baseline'):
            sub = [r for r in rows if r['layer'] == layer and r['leg'] == leg]
            hw = [r for r in sub if r['retreat_branch']]
            gat = [r for r in sub if r['gated_slice']]
            n_st = len([r for r in gat if r['stuck_possible']])
            n_al = len([r for r in gat if r['enemy_along_home']])
            n_ca = len([r for r in gat if r['enemy_cast_3s']])
            att = [r for r in sub if r['attributable']]
            print('%-6s %-9s %6d %8d %6d %6d %6d %6d %6d'
                  % (layer, leg, len(sub), len(hw), len(gat), n_st, n_al,
                     n_ca, len(att)))
            if leg == 'armed' and att:
                findings += len(att)
    print()
    print('== jump histogram (LIMIT 5: the band is [%d,%d]) ==' % (JUMP_LO, JUMP_HI))
    h = collections.Counter(int(r['jump'] // 200) * 200 for r in rows)
    for k in sorted(h):
        print('  %5d-%-5d %5d' % (k, k + 199, h[k]))
    print()
    print('== gated-slice casts, every one, with WHY each is or is not '
          'attributable ==')
    gat = [r for r in rows if r['gated_slice']]
    if not gat:
        print('  (none on either leg)')
    for r in sorted(gat, key=lambda r: (r['layer'], r['leg'], r['game'], r['t'])):
        why = []
        if r['stuck_possible']:
            why.append('IsStuck possible (dA=%d drift=%s)'
                       % (r['dist_own_ancient'], r['drift_5s']))
        if r['enemy_along_home']:
            why.append('enemy ON the home ray %s' % (r['enemy_along_home'],))
        if r['enemy_cast_3s']:
            why.append('enemy spell %s' % (r['enemy_cast_3s'],))
        print('  %-4s %-9s %s %-20s t=%7.1f hp=%.2f jump=%4d cos=%+.3f '
              'dA=%5d dF=%s since_dmg=%s'
              % (r['layer'], r['leg'], r['game'], r['hero'], r['t'],
                 r['hp_pct'], r['jump'], r['cos'], r['dist_own_ancient'],
                 r['dist_fountain'], r['since_hero_dmg']))
        print('        %s' % ('ATTRIBUTABLE to the retreat branch alone'
                              if r['attributable']
                              else 'INDETERMINATE: ' + '; '.join(why)))
    return findings


def verdict(rows, layers):
    """Pre-registered reading from the header -- printed, never inferred later."""
    def n(layer, leg, key):
        return len([r for r in rows if r['layer'] == layer and r['leg'] == leg
                    and r[key]])
    print()
    print('== reading ==')
    signs, bad = [], []
    for layer in sorted(layers):
        a_g, b_g = n(layer, 'armed', 'gated_slice'), n(layer, 'baseline', 'gated_slice')
        a_a = n(layer, 'armed', 'attributable')
        print('  %-4s armed gated=%d (attributable %d) | baseline gated=%d'
              % (layer, a_g, b_g, a_a) if False else
              '  %-4s armed gated=%d attributable=%d | baseline gated=%d'
              % (layer, a_g, a_a, b_g))
        signs.append(0 if a_g == b_g else (1 if a_g < b_g else -1))
        if a_a > 0:
            bad.append(layer)
    if len(set(signs)) > 1:
        print('  !! the layers DISAGREE in sign -> the aggregate contrast is '
              'noise by 铁律 4(i).  No effect size may be registered from it.')
    if bad:
        print('  -> BUGGY in %s: an armed cast inside the gate slice with all '
              'three rival branches excluded on its own frame.' % ','.join(bad))
    elif any(n(l, 'armed', 'gated_slice') for l in layers):
        print('  -> INDETERMINATE, (a) NOT BOUGHT.  Armed casts DO land in the '
              'gate slice, but every one of them has a rival homeward branch '
              'live on its own frame (IsStuck / IsProjectileIncoming / a kill '
              'blink onto an enemy standing on the home ray).  This is a '
              'MISSING DISCRIMINATOR, not a missing sample: more games cannot '
              'fix it, only a projectile stream in the dump plus a way to read '
              'botTarget could.')
    else:
        print('  -> NOT BOUGHT: the gated slice is empty on BOTH legs.')


# ------------------------------------------------------------------- selfcheck

def selfcheck():
    ok = [0, 0]

    def check(what, cond):
        ok[0 if cond else 1] += 1
        print('%-4s %s' % ('PASS' if cond else 'FAIL', what))

    src = load_source()
    check('source constants read and consistent (%s)' % (src.errors or 'clean',),
          not src.errors)
    check("gate body carries exactly ['blinkflee']", src.gate_ids == ['blinkflee'])
    check('exactly one call site, negated', src.call_sites == 1 and src.negated_call)

    # #296's own defect, asserted: a whole-file search finds other ids, the
    # body search must not.
    jmz = open(os.path.join(repo_root(), LUA_JMZ)).read()
    whole = re.findall(r"IsSoakCandidate\(\s*'([^']+)'\s*\)", jmz)
    check('file-wide id search would see many ids (so body extraction matters)',
          len(set(whole)) > 3)

    def snap(t, hero, idx, team, x, y, hp=1000, hp_pct=1.0):
        return {'t': t, 'hero': hero, 'idx': idx, 'team': team, 'x': x, 'y': y,
                'hp': hp, 'hp_pct': hp_pct, 'mp': 300, 'items': [], 'abilities': []}

    H = 'npc_dota_hero_earthshaker'
    E = 'npc_dota_hero_lion'
    # radiant (team 2) hero at origin retreating home: ancient is at -5528,-4874
    base = []
    for t in (-80.0, -75.0):
        base.append(snap(t, H, 11, 2, -6900, -6600))
        base.append(snap(t, E, 22, 3, 6900, 6600))
    for t in (94.0, 95.0, 96.0, 97.0, 98.0, 99.0, 100.0, 101.0):
        base.append(snap(t, E, 22, 3, 200, 200))
    tl = {
        'snapshots': base + [
            # walking in for the 5 s before the cast, so IsStuck (<25 u of
            # drift for 5 s) is excluded by observation as well as by dA
            snap(94.0, H, 11, 2, 1200, 1100),
            snap(95.0, H, 11, 2, 960, 880),
            snap(96.0, H, 11, 2, 720, 660),
            snap(97.0, H, 11, 2, 480, 440),
            snap(98.0, H, 11, 2, 240, 220),
            snap(99.0, H, 11, 2, 0, 0),
            snap(100.0, H, 11, 2, -894, -799),     # ~1200 toward own ancient
            snap(101.0, H, 11, 2, -894, -799),
        ],
        'events': [
            {'t': 99.4, 'type': 'ITEM', 'actor': H, 'target': 'dota_unknown',
             'inflictor': 'item_blink', 'value': 0, 'actor_hero': True,
             'target_hero': False},
            {'t': 200.0, 'type': 'DAMAGE', 'actor': E, 'target': H,
             'inflictor': 'x', 'value': 1, 'actor_hero': True, 'target_hero': True},
        ],
    }
    rows = scan_game(tl, armed_team=2, game='sc')
    check('the synthetic retreat blink resolves to one cast', len(rows) == 1)
    r = rows[0]
    check('tagged retreat branch (cos %.2f jump %d foes %d)'
          % (r['cos'], r['jump'], r['foes_within_1200']), r['retreat_branch'])
    check('full HP + no recent hero damage => inside the gated slice',
          r['gated_slice'] is True)
    check('leg follows armed_team, not physical side', r['leg'] == 'armed')

    # hero damage 1.0 s before the cast must remove it from the slice
    tl2 = json.loads(json.dumps(tl))
    tl2['events'].append({'t': 98.6, 'type': 'DAMAGE', 'actor': E, 'target': H,
                          'inflictor': 'x', 'value': 40, 'actor_hero': True,
                          'target_hero': True})
    r2 = scan_game(tl2, armed_team=2, game='sc')[0]
    check('hero damage 0.8 s before the cast drops it from the slice',
          r2['retreat_branch'] and not r2['gated_slice'])

    # creep damage must NOT count (the branch's own t=555.2 counter-example)
    tl3 = json.loads(json.dumps(tl))
    tl3['events'].append({'t': 98.6, 'type': 'DAMAGE',
                          'actor': 'npc_dota_creep_badguys_melee', 'target': H,
                          'inflictor': 'x', 'value': 4, 'actor_hero': False,
                          'target_hero': True})
    r3 = scan_game(tl3, armed_team=2, game='sc')[0]
    check('creep chip 0.8 s before the cast does NOT drop it (GH #71 t=555.2)',
          r3['gated_slice'])

    # 69% HP leaves the slice
    tl4 = json.loads(json.dumps(tl))
    for s in tl4['snapshots']:
        if s['hero'] == H and s['t'] == 99.0:
            s['hp_pct'] = 0.69
    r4 = scan_game(tl4, armed_team=2, game='sc')[0]
    check('69% HP is outside the slice, 70% is inside',
          r4['retreat_branch'] and not r4['gated_slice'])

    # an OFFENSIVE blink (away from own ancient) must not be tagged retreat
    tl5 = json.loads(json.dumps(tl))
    for s in tl5['snapshots']:
        if s['hero'] == H and s['t'] in (100.0, 101.0):
            s['x'], s['y'] = 894, 799
    r5 = scan_game(tl5, armed_team=2, game='sc')[0]
    check('a blink AWAY from the own ancient is not the retreat branch (cos %+.2f)'
          % r5['cos'], not r5['retreat_branch'] and not r5['gated_slice'])

    # no enemy within 1200 -> the branch's own conjunct fails
    tl6 = json.loads(json.dumps(tl))
    for s in tl6['snapshots']:
        if s['hero'] == E and s['t'] > 0:
            s['x'], s['y'] = 6000, 6000
    r6 = scan_game(tl6, armed_team=2, game='sc')[0]
    check('no enemy inside 1200 => not attributable to the retreat branch',
          not r6['retreat_branch'])

    # a dead enemy must not satisfy the ring (issue #78/#43 corpse frames)
    tl7 = json.loads(json.dumps(tl))
    for s in tl7['snapshots']:
        if s['hero'] == E and s['t'] > 0:
            s['hp'] = 0
    r7 = scan_game(tl7, armed_team=2, game='sc')[0]
    check('a corpse inside 1200 does not satisfy the enemy ring',
          not r7['retreat_branch'])

    # illusion (same name, later idx) must not become the body
    tl8 = json.loads(json.dumps(tl))
    tl8['snapshots'].append(snap(99.0, H, 77, 2, 4000, 4000))
    tl8['snapshots'].append(snap(100.0, H, 77, 2, 4000, 4000))
    r8 = scan_game(tl8, armed_team=2, game='sc')
    check('an illusion born later never displaces the idx-locked body',
          len(r8) == 1 and r8[0]['gated_slice'])

    # the canon trap: events spell some heroes without the underscore
    check('entities.canon() alone does NOT join the two spellings of VS '
          '(the defect this tool routes around)',
          entities.canon('npc_dota_hero_vengefulspirit')
          != entities.canon('npc_dota_hero_vengeful_spirit'))
    check('hkey() joins the event spelling to the snapshot spelling',
          hkey('npc_dota_hero_vengefulspirit')
          == hkey('npc_dota_hero_vengeful_spirit'))
    check('hkey() keeps distinct heroes distinct',
          len({hkey('npc_dota_hero_' + h) for h in
               ('skeleton_king', 'crystal_maiden', 'obsidian_destroyer',
                'earthshaker', 'vengeful_spirit', 'spirit_breaker')}) == 6)

    # the three attribution columns, each asserted on a purpose-built frame
    check('a clean synthetic frame IS attributable', rows[0]['attributable'])

    tlA = json.loads(json.dumps(tl))          # enemy sitting ON the home ray
    for s2 in tlA['snapshots']:
        if s2['hero'] == E and s2['t'] > 0:
            s2['x'], s2['y'] = -600, -540
    rA = scan_game(tlA, armed_team=2, game='sc')[0]
    check('an enemy on the home ray makes the cast INDETERMINATE (kill blink '
          'and flee blink are the same displacement)',
          rA['gated_slice'] and not rA['attributable']
          and rA['enemy_along_home'] is not None)

    tlB = json.loads(json.dumps(tl))          # enemy spell 1 s before the cast
    tlB['events'].append({'t': 98.5, 'type': 'ABILITY', 'actor': E,
                          'target': 'dota_unknown', 'inflictor': 'lion_impale',
                          'value': 0, 'actor_hero': True, 'target_hero': False})
    rB = scan_game(tlB, armed_team=2, game='sc')[0]
    check('an enemy spell cast inside 3 s makes it INDETERMINATE '
          '(IsProjectileIncoming cannot be excluded)',
          rB['gated_slice'] and not rB['attributable']
          and rB['enemy_cast_3s'] is not None)

    tlC = json.loads(json.dumps(tl))          # standing still, far from ancient
    for s2 in tlC['snapshots']:
        if s2['hero'] == H and s2['t'] in (-80.0, -75.0):
            pass
    tlC['snapshots'] = [s2 for s2 in tlC['snapshots']
                        if not (s2['hero'] == H and 94.0 <= s2['t'] <= 99.0)]
    for tt in (94.0, 95.0, 96.0, 97.0, 98.0, 99.0):
        tlC['snapshots'].append(snap(tt, H, 11, 2, 0, 0))
        tlC['snapshots'].append(snap(tt, E, 22, 3, 200, 200))
    rC = scan_game(tlC, armed_team=2, game='sc')[0]
    check('5 s of <25 u drift at >2200 from the own ancient leaves IsStuck '
          'live -> INDETERMINATE (dA=%d drift=%d)'
          % (rC['dist_own_ancient'], rC['drift_5s'] or -1),
          rC['gated_slice'] and rC['stuck_possible'] and not rC['attributable'])

    tlD = json.loads(json.dumps(tl))          # a corpse-adjacent cast
    for s2 in tlD['snapshots']:
        if s2['hero'] == H and s2['t'] == 99.0:
            pass
    tlD['snapshots'].append(snap(96.0, H, 11, 2, 0, 0, hp=0, hp_pct=0.0))
    rD = scan_game(tlD, armed_team=2, game='sc')[0]
    check('a cast within 6 s of an hp<=0 frame is not read at all',
          rD['recently_dead'] and not rD['gated_slice'])

    check('the three rival branches this file names are all still in the tree',
          all(k in open(os.path.join(repo_root(), LUA_AIU)).read()
              for k in ('J.IsStuck(bot)', 'J.IsProjectileIncoming(bot, 1200)',
                        'J.IsGoingOnSomeone(bot)')))

    print('\n%d PASS / %d FAIL' % (ok[0], ok[1]))
    return EXIT_CLEAN if not ok[1] else EXIT_FINDINGS


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='*', help='timeline json files or a directory')
    ap.add_argument('--json', help='write the per-cast records here')
    ap.add_argument('--selfcheck', action='store_true')
    args = ap.parse_args()

    if args.selfcheck:
        return selfcheck()

    paths = []
    for p in args.paths:
        paths.extend(sorted(glob.glob(os.path.join(p, '*.json')))
                     if os.path.isdir(p) else [p])
    if not paths:
        print('REFUSED: no timelines given', file=sys.stderr)
        return EXIT_REFUSED

    try:
        src = load_source()
    except Exception as exc:
        print('REFUSED: source constants unreadable (%s)' % exc, file=sys.stderr)
        return EXIT_REFUSED

    rows, layers = [], collections.Counter()
    for p in paths:
        run, game, side = side_of(p)
        if side is None:
            print('REFUSED: %s does not carry __<side>.json' % p, file=sys.stderr)
            return EXIT_REFUSED
        layer = 'ab' if side == 'radiant' else 'ba'
        layers[layer] += 1
        armed_team = 2 if side == 'radiant' else 3
        try:
            d = json.load(open(p))
        except Exception as exc:
            print('skip %s (%s)' % (p, exc), file=sys.stderr)
            continue
        for r in scan_game(d, armed_team, game='%s/%s' % (run, game)):
            r['layer'] = layer
            rows.append(r)

    findings = report(rows, layers, src)
    verdict(rows, layers)
    if args.json:
        json.dump(rows, open(args.json, 'w'), indent=1)
    if src.errors:
        print('\nSOURCE DRIFT:')
        for e in src.errors:
            print('  ' + e)
        return EXIT_FINDINGS
    return EXIT_FINDINGS if findings else EXIT_CLEAN


if __name__ == '__main__':
    sys.exit(main())

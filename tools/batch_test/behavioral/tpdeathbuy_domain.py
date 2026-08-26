#!/usr/bin/env python3
"""`tpdeathbuy` condition (a): does the revived block actually buy a TP?

THE LEVER
---------
`bots/item_purchase_generic.lua`, the "死前如果会损失金钱则购买额外TP" block:

    local bDyingWithDoomedGold = botHP < 0.08 and botHP >= 1
    if J.IsModeTurbo() and J.IsSoakCandidate('tpdeathbuy') then
        bDyingWithDoomedGold = botHP < 0.08
    end
    if botGold >= tpCost and bot:IsAlive()
        and botGold < ( tpCost + botWorth / 40 )
        and bDyingWithDoomedGold
        and bot:WasRecentlyDamagedByAnyHero( 3.1 )
        and not HasSufficientTp()
        and Item.GetItemCharges( bot, 'item_tpscroll' ) <= 2
    then
        bot:ActionImmediate_PurchaseItem( "item_tpscroll" )
    end

`botHP` is `J.GetHP`'s 0..1 fraction, so the shipped conjunction
`< 0.08 and >= 1` is unsatisfiable and the block is dead code exactly as
shipped.  Armed (turbo + `tpdeathbuy`) the stray lower bound is dropped and
the block becomes reachable.  This is the test set's only WIDENING: the armed
predicate is a strict SUPERSET of the shipped one (which is the empty set),
so -- per the director's pre-registered reading (GH #168) -- *a reading of
"armed and baseline are indistinguishable" does not validate this id*; it
says only that it was not armed or that the domain is empty.

WHAT THIS TOOL MEASURES, AND WHAT IT CANNOT
-------------------------------------------
Observable in the dump:

  * every TP purchase, by hero and instant -- but only since this round's
    dumper patch (see PURCHASE NAME INDEX below);
  * `hp_pct` at that instant (the armed clause);
  * "damaged by an enemy hero within 3.1 s" (the `WasRecentlyDamagedByAnyHero`
    conjunct), read off the DAMAGE event stream;
  * `net_worth`, `level`, position, and distance to the own fountain.

NOT observable, and this is a hard boundary rather than an omission:

  * `bot:GetGold()`.  The dump carries `net_worth`, not gold, so the band
    `tpCost <= gold < tpCost + netWorth/40` cannot be evaluated offline.
  * TP CHARGES.  `resolveItems` returns slots 0-8 (inventory + backpack); the
    TP slot is 9+ and is excluded, and `resolveTP` returns (0,0) both for "no
    TP at all" and for "TP off cooldown".  So `not HasSufficientTp()` and
    `charges <= 2` cannot be evaluated either.

Every count this tool prints is therefore an UPPER BOUND on the true domain
(the observable conjuncts only) and a LOWER BOUND on nothing.  It is labelled
that way in the output, and `verdict()` refuses to answer LIVE on the
observable conjuncts alone.

THE ONE PLACE THE ATTRIBUTION IS CLEAN
--------------------------------------
Two other sites in `bots/` buy a TP and could otherwise be mistaken for this
one:

  1. `item_purchase_generic.lua` ~line 1031, the ordinary spare-TP buy.  It is
     gated on `currentTime > 4 * 60` (`currentTime = DotaTime()`), so **a TP
     purchase at DotaTime <= 240 cannot come from it.**
  2. `mode_roam_generic.lua` ~line 426, which buys inside `ShouldWaitInBaseToHeal`
     on the branch where the bot is already within 150 u of its own fountain.
     A distance-from-own-fountain filter removes it.

So `t <= 240` AND `hp_pct < 0.08` AND recently-damaged AND far from the own
fountain is a window in which a TP purchase is attributable to THIS block and
to no other -- on the armed leg.  On the baseline leg the same window must be
empty by arithmetic, which is what makes it a control rather than a guess.

PURCHASE NAME INDEX (the instrument fault this round found first)
-----------------------------------------------------------------
`events[].value` on a PURCHASE is an index into the replay's *own*
`CombatLogNames` string table, NOT a stable item id.  Measured on two W13
games from the same run and the same tree: of the 21 indices present in both,
exactly ONE meant the same item (index 10 = `magic_wand` in one game and
`ancient_janggo` in the other; index 94 = `item_tpscroll` in the first game
and something else in the second).  A cross-game read keyed on the integer
aggregates cleanly, plots cleanly, and is noise.

`dumper/main.go` now resolves it through the same table into `value_name`,
for PURCHASE only -- for DAMAGE/HEAL/GOLD the value is a magnitude and the
same lookup would manufacture item names out of amounts.  This tool REFUSES
to run on a timeline whose PURCHASE events lack `value_name` rather than
falling back to the integer, because the fallback is exactly the silent-garbage
path.
"""
import argparse
import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import entities  # noqa: E402
import source_constants as SC  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
BUY = os.path.join(REPO, 'bots', 'item_purchase_generic.lua')
ROAM = os.path.join(REPO, 'bots', 'mode_roam_generic.lua')

RAD, DIRE = 2, 3
FOUNTAIN = {RAD: (-7200.0, -6666.0), DIRE: (7000.0, 6500.0)}

TP_ITEM = 'item_tpscroll'


# --------------------------------------------------------------------------
# source side -- every constant below is READ, never retyped, so the argument
# in this file cannot silently expire when someone edits the Lua.
# --------------------------------------------------------------------------
def read_source():
    with open(BUY, 'r', encoding='utf-8') as fh:
        buy = SC._strip_comments(fh.read())
    with open(ROAM, 'r', encoding='utf-8') as fh:
        roam = SC._strip_comments(fh.read())

    m = re.search(r'local\s+bDyingWithDoomedGold\s*=\s*botHP\s*<\s*([\d.]+)'
                  r'\s*and\s*botHP\s*>=\s*([\d.]+)', buy)
    if not m:
        raise SC.SourceConstantError(
            'item_purchase_generic: the shipped `botHP < X and botHP >= Y` '
            'clause is gone -- this whole file argues about that clause')
    shipped_hi, shipped_lo = float(m.group(1)), float(m.group(2))

    m = re.search(r"if\s+(J\.IsModeTurbo\(\)[^\n]*IsSoakCandidate\('tpdeathbuy'\)"
                  r"[^\n]*)then\s*\n\s*bDyingWithDoomedGold\s*=\s*botHP\s*<\s*([\d.]+)",
                  buy)
    if not m:
        raise SC.SourceConstantError(
            'item_purchase_generic: the tpdeathbuy arm is no longer '
            '`gate then bDyingWithDoomedGold = botHP < X`')
    gate, armed_hi = m.group(1).strip(), float(m.group(2))

    # The pullcad lesson (charter): a gate written as a conjunction of TWO
    # soak ids freezes FALSE the day either one is promoted, and every wiring
    # check still calls it WIRED.  Refuse to certify such a gate here.
    n_ids = len(re.findall(r"IsSoakCandidate\(\s*'([a-z0-9_]+)'\s*\)", gate))
    if n_ids != 1:
        raise SC.SourceConstantError(
            'tpdeathbuy gate names %d soak ids, expected exactly 1: %s'
            % (n_ids, gate))

    m = re.search(r'WasRecentlyDamagedByAnyHero\(\s*([\d.]+)\s*\)', buy)
    if not m:
        raise SC.SourceConstantError(
            'item_purchase_generic: WasRecentlyDamagedByAnyHero window gone')
    dmg_window = float(m.group(1))

    m = re.search(r'currentTime\s*>\s*(\d+)\s*\*\s*(\d+)', buy)
    if not m:
        raise SC.SourceConstantError(
            'item_purchase_generic: the ordinary spare-TP clock '
            '`currentTime > 4 * 60` is gone -- the t<=240 attribution window '
            'in this file depends on it')
    normal_clock = int(m.group(1)) * int(m.group(2))

    if not re.search(r'currentTime\s*=\s*DotaTime\(\)', buy):
        raise SC.SourceConstantError(
            'item_purchase_generic: currentTime is no longer DotaTime()')

    m = re.search(r'GetUnitToLocationDistance\(bot,\s*J\.GetTeamFountain\(\)\)'
                  r'\s*>\s*(\d+)', roam)
    if not m:
        raise SC.SourceConstantError(
            'mode_roam_generic: the fountain-radius branch that contains the '
            'rival TP purchase is gone')
    roam_radius = float(m.group(1))

    if not re.search(r"J\.Item\.GetItemCharges\(bot,\s*'item_tpscroll'\)\s*<=\s*1"
                     r"[\s\S]{0,200}?ActionImmediate_PurchaseItem\('item_tpscroll'\)",
                     roam):
        raise SC.SourceConstantError(
            'mode_roam_generic: the rival TP purchase site moved -- the '
            'fountain exclusion in this file was aimed at it')

    n_sites = len(re.findall(r'ActionImmediate_PurchaseItem\(\s*["\']item_tpscroll["\']\s*\)',
                             buy + roam))
    return {
        'shipped_hi': shipped_hi,
        'shipped_lo': shipped_lo,
        'armed_hi': armed_hi,
        'gate': gate,
        'dmg_window': dmg_window,
        'normal_clock': normal_clock,
        'roam_radius': roam_radius,
        'tp_buy_sites': n_sites,
    }


def verdict(sc):
    """Can the two legs disagree at all, on the source alone?"""
    if sc['shipped_lo'] > sc['shipped_hi']:
        shipped = 'EMPTY (botHP < %g and botHP >= %g is unsatisfiable on a 0..1 fraction)' % (
            sc['shipped_hi'], sc['shipped_lo'])
        if sc['armed_hi'] > 0:
            return ('WIDENING', 'shipped set is %s; armed set is botHP < %g '
                                '=> every armed firing is a strict addition'
                    % (shipped, sc['armed_hi']))
        return ('STRUCTURAL-ZERO', 'armed set is empty too (botHP < %g)'
                % sc['armed_hi'])
    # The shipped clause became satisfiable: the whole argument in this file
    # (baseline leg is a control that must be empty) no longer holds.  Refuse
    # rather than quietly change what the numbers mean.
    return ('REFUSE', 'shipped clause botHP < %g and botHP >= %g is now '
                      'SATISFIABLE -- the baseline leg is no longer an empty '
                      'control and this tool must not be read as though it were'
            % (sc['shipped_hi'], sc['shipped_lo']))


# --------------------------------------------------------------------------
# corpus side
# --------------------------------------------------------------------------
def _dist(p, q):
    return ((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2) ** 0.5


def hero_damage_index(timeline):
    """{victim: [(t, attacker)]} for DAMAGE dealt BY an enemy hero.

    `WasRecentlyDamagedByAnyHero` counts damage from a hero, so illusions and
    creeps must not be in here.  `actor_hero` is the dumper's own flag for
    "the attacker was a hero"; an illusion is not flagged as a hero by the
    combat log, which is the behaviour we want and the reason this does not
    go through entities.frames_by_hero.
    """
    out = collections.defaultdict(list)
    for e in timeline.get('events', ()):
        if e.get('type') != 'DAMAGE':
            continue
        if not e.get('actor_hero') or not e.get('target_hero'):
            continue
        out[entities.canon(e.get('target'))].append((e['t'], entities.canon(e.get('actor'))))
    for h in out:
        out[h].sort()
    return out


def recently_damaged(dmg, hero, t, window, teams):
    """(bool, attacker) -- damaged by an ENEMY hero within `window` before t."""
    own = teams.get(hero)
    best = None
    for ts, attacker in dmg.get(hero, ()):
        if ts > t:
            break
        if ts < t - window:
            continue
        if own is not None and teams.get(attacker) == own:
            continue  # self / ally damage is not "by an enemy hero"
        best = (ts, attacker)
    return (best is not None), best


def tp_purchases(timeline):
    """Every TP purchase, refusing the unresolved-index fallback."""
    pur = [e for e in timeline.get('events', ()) if e.get('type') == 'PURCHASE']
    if pur and not any(e.get('value_name') for e in pur):
        raise RuntimeError(
            'timeline has %d PURCHASE events and no value_name: this dump '
            'predates the dumper patch.  Refusing to key on events[].value, '
            'which is a PER-REPLAY name-table index (see module docstring).'
            % len(pur))
    return [e for e in pur if e.get('value_name') == TP_ITEM]


def scan_game(timeline, sc):
    """Rows for every TP purchase + the domain census, for one game."""
    frames, teams = entities.frames_by_hero(timeline)
    deaths = entities.death_times(timeline)
    dmg = hero_damage_index(timeline)

    rows = []
    for e in tp_purchases(timeline):
        hero = entities.canon(e.get('target'))
        t = e['t']
        fr = frames.get(hero)
        if fr is None:
            continue
        st = entities.interp(fr, t)
        if st is None:
            continue
        team = teams.get(hero)
        fx = FOUNTAIN.get(team)
        d_f = _dist((st['x'], st['y']), fx) if fx else None
        hit, who = recently_damaged(dmg, hero, t, sc['dmg_window'], teams)
        rows.append({
            't': round(t, 1), 'hero': hero, 'team': team,
            'hp_pct': round(st['hp_pct'], 3), 'level': st.get('level'),
            'dist_fountain': None if d_f is None else round(d_f),
            'lowhp': st['hp_pct'] < sc['armed_hi'],
            'dmg': hit, 'attacker': None if not who else who[1],
            'dmg_dt': None if not who else round(t - who[0], 2),
            'pre_clock': t <= sc['normal_clock'],
            'off_fountain': (d_f is not None and d_f > sc['roam_radius']),
        })

    # Domain census: hero-frames satisfying the OBSERVABLE conjuncts.  Upper
    # bound -- gold and TP charges are not in the dump.  Kept PER TEAM so the
    # caller can split it into the two legs (GH #148 measurement rule (i):
    # any armed/baseline comparison must be given in both ab and ba layers).
    census = collections.defaultdict(collections.Counter)
    for hero, fr in frames.items():
        team = teams.get(hero)
        c = census[team]
        for s in fr:
            if s['t'] < 0:
                continue
            c['frames'] += 1
            if s['hp_pct'] <= 0:
                continue
            if not entities.alive_at(fr, deaths.get(hero, []), s['t']):
                continue
            c['alive'] += 1
            if s['hp_pct'] >= sc['armed_hi']:
                continue
            c['lowhp'] += 1
            hit, _ = recently_damaged(dmg, hero, s['t'], sc['dmg_window'], teams)
            if hit:
                c['lowhp_dmg'] += 1
                if s['t'] <= sc['normal_clock']:
                    c['lowhp_dmg_preclock'] += 1
    maxt = max((s['t'] for fr in frames.values() for s in fr), default=0.0)
    return rows, census, maxt


def iter_games(dirs):
    for d in dirs:
        tdir = os.path.join(d, 'timelines')
        if not os.path.isdir(tdir):
            tdir = d
        man = {}
        mpath = os.path.join(d, 'games_manifest.jsonl')
        if os.path.exists(mpath):
            with open(mpath) as fh:
                for line in fh:
                    try:
                        r = json.loads(line)
                    except ValueError:
                        continue
                    man[r.get('game')] = r
        for name in sorted(os.listdir(tdir)):
            if not name.endswith('.timeline.json'):
                continue
            game = name[:-len('.timeline.json')]
            try:
                with open(os.path.join(tdir, name)) as fh:
                    tl = json.load(fh)
            except (ValueError, OSError) as exc:
                sys.stderr.write('[skip] %s: %s\n' % (game, exc))
                continue
            yield os.path.basename(d.rstrip('/')), game, tl, man.get(game, {})


def leg_of(row, side):
    """'armed' | 'baseline' for the hero this row belongs to.

    `side` is the physical team the candidate arm is on in THIS game
    ('radiant'/'dire'), taken from the mirror stamp.
    """
    if side not in ('radiant', 'dire'):
        return None
    armed_team = RAD if side == 'radiant' else DIRE
    if row['team'] is None:
        return None
    return 'armed' if row['team'] == armed_team else 'baseline'


def run(dirs, dump_rows=False):
    sc = read_source()
    label, why = verdict(sc)

    per = collections.defaultdict(collections.Counter)   # (leg, side) -> counters
    census = collections.defaultdict(collections.Counter)
    unique = []
    n_games = 0
    maxt_all = 0.0
    for run_id, game, tl, meta in iter_games(dirs):
        side = meta.get('side')
        try:
            rows, cen, maxt = scan_game(tl, sc)
        except RuntimeError as exc:
            sys.stderr.write('[refuse] %s: %s\n' % (game, exc))
            continue
        n_games += 1
        maxt_all = max(maxt_all, maxt)
        armed_team = RAD if side == 'radiant' else (DIRE if side == 'dire' else None)
        for team, c in cen.items():
            if armed_team is None or team is None:
                census[('unstamped', side or '?')].update(c)
                continue
            leg = 'armed' if team == armed_team else 'baseline'
            census[(leg, side)].update(c)
            census[(leg, 'BOTH')].update(c)
        for r in rows:
            leg = leg_of(r, side)
            key = (leg or 'unstamped', side or '?')
            per[key]['tp_buys'] += 1
            if r['lowhp']:
                per[key]['lowhp'] += 1
                if r['dmg']:
                    per[key]['lowhp_dmg'] += 1
                    if r['pre_clock'] and r['off_fountain']:
                        per[key]['UNIQUE'] += 1
                        r = dict(r, game=game, run=run_id, leg=leg)
                        unique.append(r)
            if dump_rows and r['lowhp']:
                print('ROW %s %s %s' % (game, leg, json.dumps(r)))

    print('== tpdeathbuy: source ==')
    for k in ('shipped_hi', 'shipped_lo', 'armed_hi', 'dmg_window',
              'normal_clock', 'roam_radius', 'tp_buy_sites'):
        print('   %-14s %s' % (k, sc[k]))
    print('   gate           %s' % sc['gate'])
    print('   VERDICT(source-only) %s -- %s' % (label, why))
    print()
    print('== corpus ==   games=%d  max game-clock=%.1fs' % (n_games, maxt_all))
    print('   NOTE: every count below is an UPPER BOUND on the true domain.')
    print('   Gold and TP charges are NOT in the dump (see module docstring),')
    print('   so `gold` band, `not HasSufficientTp()` and `charges <= 2` are')
    print('   UNEVALUATED conjuncts, all of which can only remove firings.')
    print()
    hdr = ('leg', 'side', 'tp_buys', 'lowhp', 'lowhp+dmg', 'UNIQUE(t<=%d,off-fountain)'
           % sc['normal_clock'])
    print('   %-9s %-8s %8s %7s %10s %s' % hdr)
    for key in sorted(per):
        c = per[key]
        print('   %-9s %-8s %8d %7d %10d %s'
              % (key[0], key[1], c['tp_buys'], c['lowhp'], c['lowhp_dmg'],
                 c['UNIQUE']))
    tot = collections.Counter()
    for key, c in per.items():
        if key[0] in ('armed', 'baseline'):
            tot[key[0] + '_' + 'tp_buys'] += c['tp_buys']
            tot[key[0] + '_lowhp'] += c['lowhp']
            tot[key[0] + '_lowhp_dmg'] += c['lowhp_dmg']
            tot[key[0] + '_UNIQUE'] += c['UNIQUE']
    print()
    print('   pooled  armed  tp_buys=%d lowhp=%d lowhp+dmg=%d UNIQUE=%d'
          % (tot['armed_tp_buys'], tot['armed_lowhp'], tot['armed_lowhp_dmg'],
             tot['armed_UNIQUE']))
    print('   pooled  base   tp_buys=%d lowhp=%d lowhp+dmg=%d UNIQUE=%d'
          % (tot['baseline_tp_buys'], tot['baseline_lowhp'],
             tot['baseline_lowhp_dmg'], tot['baseline_UNIQUE']))
    print()
    print('== observable-conjunct domain census (hero-frames) ==')
    print('   ab/ba layers given separately (GH #148 rule (i)); the armed leg')
    print('   is the physical side named by each game\'s own mirror stamp.')
    keys = ('frames', 'alive', 'lowhp', 'lowhp_dmg', 'lowhp_dmg_preclock')
    for key in sorted(census):
        c = census[key]
        print('   %-9s side=%-8s ' % key + '  '.join(
            '%s=%d' % (k, c[k]) for k in keys))
    agg = collections.Counter()
    for k, c in census.items():
        if k[1] == 'BOTH':
            agg.update(c)
    print('   POOLED              ' + '  '.join('%s=%d' % (k, agg[k]) for k in keys))
    if agg['alive']:
        print('   lowhp/alive = %.4f%%   lowhp+dmg/alive = %.4f%%'
              % (100.0 * agg['lowhp'] / agg['alive'],
                 100.0 * agg['lowhp_dmg'] / agg['alive']))
    if n_games:
        print('   per game: lowhp+dmg = %.1f hero-frames (both legs together)'
              % (agg['lowhp_dmg'] / n_games))
    print()
    if unique:
        print('== uniquely-attributable firings (deep-check these frames) ==')
        for r in sorted(unique, key=lambda r: (r['leg'] or '', r['t'])):
            print('   %s %s %-8s %-22s t=%-7.1f hp=%.3f L%-2s dF=%-6s dmg<-%s (%.2fs)'
                  % (r['run'][-6:], r['game'], r['leg'], r['hero'], r['t'],
                     r['hp_pct'], r['level'], r['dist_fountain'],
                     r['attacker'], r['dmg_dt']))
    else:
        print('== uniquely-attributable firings: NONE ==')
        print('   ZERO IS A READING, NOT A MISSING OUTPUT.  On the BASELINE leg')
        print('   zero is REQUIRED (the block is unsatisfiable there); on the')
        print('   ARMED leg zero means one of: not armed, or the unevaluated')
        print('   gold/charges conjuncts empty the window, or the window is')
        print('   genuinely never reached.  It does NOT mean "tested, neutral".')
    return 0


# --------------------------------------------------------------------------
# selfcheck
# --------------------------------------------------------------------------
def _tl(snaps, events, teams):
    return {'game': {'teams': teams}, 'snapshots': snaps, 'events': events}


def _snap(t, hero, team, hp, idx=1, x=0.0, y=0.0, level=5):
    return {'t': t, 'hero': hero, 'idx': idx, 'team': team, 'x': x, 'y': y,
            'hp': int(1000 * hp), 'hp_pct': hp, 'level': level, 'items': [],
            'net_worth': 3000}


def selfcheck():
    ok = fail = 0

    def chk(name, cond, extra=''):
        nonlocal ok, fail
        if cond:
            ok += 1
            print('PASS %s' % name)
        else:
            fail += 1
            print('FAIL %s %s' % (name, extra))

    sc = read_source()
    chk('shipped clause read', sc['shipped_hi'] == 0.08 and sc['shipped_lo'] == 1,
        str(sc))
    chk('armed clause read', sc['armed_hi'] == 0.08, str(sc))
    chk('damage window read', sc['dmg_window'] == 3.1, str(sc))
    chk('normal spare-TP clock read', sc['normal_clock'] == 240, str(sc))
    chk('roam fountain radius read', sc['roam_radius'] == 150, str(sc))
    chk('gate names exactly one soak id',
        sc['gate'].count('IsSoakCandidate') == 1, sc['gate'])
    chk('gate is turbo-only', 'IsModeTurbo' in sc['gate'], sc['gate'])

    # No retyped thresholds: every number the argument leans on must have come
    # out of the Lua.  Checked on the AST (not on the text), so quoting the Lua
    # in a docstring is fine and a literal in executable code is not.
    import ast
    tree = ast.parse(open(__file__).read())
    # The fixtures in selfcheck/_snap are ALLOWED to name the numbers -- that
    # is what a fixture is.  Everything else must have read them.
    exempt = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name in ('selfcheck', '_snap'):
            for sub in ast.walk(node):
                exempt.add(id(sub))
    # `shipped_lo` is 1, which is every loop increment and every index in the
    # file: banning it would flag arithmetic, not a retyped threshold.  Values
    # <= 2 are therefore out of scope for this check, and that exclusion is
    # stated rather than silent.
    banned = {v for v in (sc['shipped_hi'], sc['shipped_lo'], sc['armed_hi'],
                          sc['dmg_window'], sc['roam_radius'],
                          float(sc['normal_clock'])) if v > 2}
    leaked = [n.value for n in ast.walk(tree)
              if isinstance(n, ast.Constant) and id(n) not in exempt
              and isinstance(n.value, (int, float))
              and not isinstance(n.value, bool)
              and float(n.value) in banned]
    chk('no source threshold retyped as a literal in executable code',
        not leaked, 'leaked %s' % sorted(set(leaked)))
    # ...and the exemption must not be a blanket one: prove the check can FAIL.
    probe = ast.parse('x = %r\n' % sc['dmg_window'])
    probe_leak = [n.value for n in ast.walk(probe)
                  if isinstance(n, ast.Constant) and float(n.value) in banned]
    chk('the literal check can actually fail (anti-selfskip)', probe_leak == [sc['dmg_window']],
        str(probe_leak))

    label, why = verdict(sc)
    chk('verdict is WIDENING', label == 'WIDENING', label + ' ' + why)
    # counterfactuals: verdict must CHANGE, and must refuse rather than guess
    chk('counterfactual: satisfiable shipped clause => REFUSE',
        verdict(dict(sc, shipped_lo=0.05))[0] == 'REFUSE')
    chk('counterfactual: armed clause emptied => STRUCTURAL-ZERO',
        verdict(dict(sc, armed_hi=0.0))[0] == 'STRUCTURAL-ZERO')

    # --- anti-selfskip: every predicate must be able to answer YES *and* NO ---
    teams = {'npc_dota_hero_axe': RAD, 'npc_dota_hero_lion': DIRE}
    snaps = ([_snap(t, 'npc_dota_hero_axe', RAD, 0.05, x=-2000, y=-2000)
              for t in (0.0, 100.0, 200.0, 300.0)] +
             [_snap(t, 'npc_dota_hero_lion', DIRE, 1.0, idx=2, x=2000, y=2000)
              for t in (0.0, 100.0, 200.0, 300.0)])
    dmg_ev = [{'t': 199.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_lion',
               'target': 'npc_dota_hero_axe', 'actor_hero': True,
               'target_hero': True, 'value': 50}]
    buy = [{'t': 200.0, 'type': 'PURCHASE', 'target': 'npc_dota_hero_axe',
            'actor': 'dota_unknown', 'inflictor': 'dota_unknown',
            'value': 94, 'value_name': TP_ITEM,
            'actor_hero': False, 'target_hero': False}]
    rows, cen, _ = scan_game(_tl(snaps, dmg_ev + buy, teams), sc)
    chk('YES: a qualifying purchase is found', len(rows) == 1 and rows[0]['lowhp']
        and rows[0]['dmg'] and rows[0]['pre_clock'] and rows[0]['off_fountain'],
        json.dumps(rows))

    # NO on each conjunct, one at a time
    hi = [_snap(t, 'npc_dota_hero_axe', RAD, 0.5, x=-2000, y=-2000)
          for t in (0.0, 100.0, 200.0, 300.0)] + snaps[4:]
    r2, _, _ = scan_game(_tl(hi, dmg_ev + buy, teams), sc)
    chk('NO: hp above the armed threshold is not lowhp', not r2[0]['lowhp'])

    r3, _, _ = scan_game(_tl(snaps, buy, teams), sc)
    chk('NO: no recent damage => dmg False', not r3[0]['dmg'])

    old = [dict(e, t=190.0) for e in dmg_ev]
    r4, _, _ = scan_game(_tl(snaps, old + buy, teams), sc)
    chk('NO: damage older than the window does not count', not r4[0]['dmg'])

    ally = [{'t': 199.0, 'type': 'DAMAGE', 'actor': 'npc_dota_hero_axe',
             'target': 'npc_dota_hero_axe', 'actor_hero': True,
             'target_hero': True, 'value': 50}]
    r5, _, _ = scan_game(_tl(snaps, ally + buy, teams), sc)
    chk('NO: self/ally damage is not "by an enemy hero"', not r5[0]['dmg'])

    late = [dict(e, t=300.0) for e in buy]
    late_dmg = [dict(e, t=299.0) for e in dmg_ev]
    r6, _, _ = scan_game(_tl(snaps, late_dmg + late, teams), sc)
    chk('NO: a purchase after the 4:00 clock is not uniquely attributable',
        not r6[0]['pre_clock'])

    at_fountain = [_snap(t, 'npc_dota_hero_axe', RAD, 0.05, x=-7200, y=-6666)
                   for t in (0.0, 100.0, 200.0, 300.0)] + snaps[4:]
    r7, _, _ = scan_game(_tl(at_fountain, dmg_ev + buy, teams), sc)
    chk('NO: a purchase at the own fountain is the roam site, excluded',
        not r7[0]['off_fountain'])

    # the census must be able to be non-zero AND zero, and must be PER TEAM
    # (a pooled census cannot be split into the ab/ba layers GH #148 requires)
    _, cen_y, _ = scan_game(_tl(snaps, dmg_ev + buy, teams), sc)
    chk('census YES: lowhp+dmg is non-empty when it should be',
        cen_y[RAD]['lowhp_dmg'] > 0, str(dict(cen_y)))
    chk('census is keyed by team, and the untouched team stays empty',
        cen_y[DIRE]['lowhp'] == 0 and cen_y[DIRE]['alive'] > 0, str(dict(cen_y)))
    _, cen_n, _ = scan_game(_tl(hi, buy, teams), sc)
    chk('census NO: lowhp is empty when nobody is low',
        cen_n[RAD]['lowhp'] == 0, str(dict(cen_n)))

    # the instrument fault this tool exists to refuse
    noname = [{k: v for k, v in b.items() if k != 'value_name'} for b in buy]
    try:
        scan_game(_tl(snaps, dmg_ev + noname, teams), sc)
        chk('REFUSE: a pre-patch timeline is rejected, not silently keyed on '
            'events[].value', False, 'no refusal raised')
    except RuntimeError as exc:
        chk('REFUSE: a pre-patch timeline is rejected, not silently keyed on '
            'events[].value', 'value_name' in str(exc))

    other = [dict(b, value_name='item_flask') for b in buy]
    r8, _, _ = scan_game(_tl(snaps, dmg_ev + other, teams), sc)
    chk('NO: a non-TP purchase is not counted', r8 == [], json.dumps(r8))

    # leg mapping must be able to answer both ways, and refuse an unstamped game
    row_r = {'team': RAD}
    chk('leg: radiant-armed maps radiant hero to armed',
        leg_of(row_r, 'radiant') == 'armed')
    chk('leg: dire-armed maps radiant hero to baseline',
        leg_of(row_r, 'dire') == 'baseline')
    chk('leg: an unstamped game maps to None (never to a leg)',
        leg_of(row_r, '') is None)

    print('\n%d PASS / %d FAIL' % (ok, fail))
    return 1 if fail else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('dirs', nargs='*', help='sweep output dirs (or dirs of *.timeline.json)')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--source', action='store_true',
                    help='structural read only -- needs no corpus, costs nothing')
    ap.add_argument('--rows', action='store_true', help='dump every low-HP TP purchase')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if a.source or not a.dirs:
        sc = read_source()
        label, why = verdict(sc)
        for k in sorted(sc):
            print('%-14s %s' % (k, sc[k]))
        print('VERDICT %s -- %s' % (label, why))
        return 0
    return run(a.dirs, dump_rows=a.rows)


if __name__ == '__main__':
    sys.exit(main())

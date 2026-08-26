#!/usr/bin/env python3
"""`tbearly` condition (a): is there ANY frame on which the armed leg differs?

WHAT THE LEVER IS
-----------------
`bots/mode_farm_generic.lua` -- inside GetFarmDesire, in the `#hLaneCreepList
== 0` else-branch -- decides whether to prefer a LANE FRONT over a jungle camp:

    local nEarlyClock = 25 * 60
    if J.IsSoakCandidate('tbearly') and J.IsModeTurbo() then
        nEarlyClock = 18 * 60
    end
    local bEarlyGame = DotaTime() < nEarlyClock
        and bot:GetNetWorth() < 15000
    ...
    if bEarlyGame and nDeaths < 5 then   -- lane-front preference

The commit that gated it (82b9a589, "five turbo scalings that never ran") is
right about WHY the shipped text was broken: `J.IsModeTurbo() and DotaTime() <
18*60 or DotaTime() < 25*60` parses as `(turbo and t<1080) or (t<1500)`, the
first disjunct is a subset of the second, so the 18-minute turbo bound was
unreachable and the expression was literally `t < 1500` in every mode.  The
rewrite restores the intended bound by SELECTING it.

THE FINDING THIS TOOL EXISTS TO MEASURE
---------------------------------------
The restored bound is unreachable too, for a different reason, and the reason
is one conjunct of the block the clause sits inside:

    if GetGameMode() ~= GAMEMODE_MO
    and ...
    and not J.IsLateGame()            <-- this one
    then
        ...
        else                          <-- tbearly lives in here
            local nEarlyClock = ...

and `J.IsLateGame()` (jmz_func.lua) is, in turbo,

    DotaTime() > 18 * 60

So on every frame that REACHES the clause, `DotaTime() <= 1080` already holds.

  shipped leg:  bEarlyGame's clock term is `t < 1500`  -- true on all of it
  armed leg:    bEarlyGame's clock term is `t < 1080`  -- true on all of it
                                                          EXCEPT t == 1080.0

The two legs therefore disagree on the single instant `DotaTime() == 1080.0`
exactly, and nowhere else.  That is a measure-zero set in a continuous clock:
`tbearly` is SILENT BY CONSTRUCTION, not silent for want of corpus.

Note the enclosing conjunct is not new: `and not J.IsLateGame()` is in the
upstream OHA snapshot (74727e4:427), i.e. it predates the gate by the whole
history of this repo.

This tool proves that in the only two ways it can be proved:

  (1) ARITHMETIC, read out of the shipped Lua (never retyped here):
      `--source` prints the three constants and the enclosure, and refuses to
      run if the block structure is not what the paragraph above says.
      The enclosure is established with a real Lua block matcher, not with
      indentation and not with a regexp.

  (2) FRAMES, over a corpus: an eight-rung monotone cascade whose last rung is
      the enclosing conjunct.  The rung ABOVE it is the band the commit
      message claims to move (18:00-25:00) -- reported separately and on
      purpose, because that band is richly populated in every wave we own, and
      quoting only it would read as "the lever has a domain".  It does not.
      The drop from that rung to the next is the whole finding.

DELIBERATE NON-CLAIM
--------------------
This tool does NOT claim the bot's farm desire is unchanged in 18:00-25:00.
It is: the ENTIRE outer block (lane-front preference AND the jungle-camp
branch under it) is dead after 18:00 in turbo, for every bot, armed or not.
That is SHIPPED behaviour and it is a separate question from this lever.  The
`--band-shape` section reports what the corpus does in that window so the
separate question has a number attached, and labels it as shipped-side.

USAGE
    tbearly_domain.py --selfcheck
    tbearly_domain.py --source
    tbearly_domain.py <sweep_out_dir> [<sweep_out_dir> ...]

Read-only.  Touches no AWS resource.
"""
import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import entities  # noqa: E402  -- shared illusion/aliveness keying, GH #176 §5.3
import source_constants as SC  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
FARM = os.path.join(REPO, 'bots', 'mode_farm_generic.lua')
JMZ = os.path.join(REPO, 'bots', 'FunLib', 'jmz_func.lua')

# The companion conjunct of bEarlyGame and the deaths bound, both read from
# source below -- these names exist so a reader can find them, not as values.
NETWORTH_NAME = 'bot:GetNetWorth() < '
DEATHS_NAME = 'nDeaths < '


# --------------------------------------------------------------------------
# Lua block structure.  Small, but it is the load-bearing part of claim (1):
# "the tbearly clause is lexically inside the `not J.IsLateGame()` if-block"
# is exactly the sort of statement that an indentation check or a line-number
# range would get wrong the first time someone reformats the file.
# --------------------------------------------------------------------------
_TOKEN = re.compile(r"--\[(=*)\[|--[^\n]*|\[(=*)\[|'|\"|\b\w+\b")

_OPENERS = ('function', 'if', 'for', 'while', 'do', 'repeat')


def _lua_blocks(src):
    """Yield (open_line, close_line, header_text) for every block in `src`.

    Handles line comments, long comments/strings and quoted strings.  `elseif`
    and `else` do not open or close a block.  `repeat` is closed by `until`.
    """
    line_of = [0] * (len(src) + 1)
    ln = 1
    for i, ch in enumerate(src):
        line_of[i] = ln
        if ch == '\n':
            ln += 1
    line_of[len(src)] = ln

    stack = []
    out = []
    pending = None  # 'then' or 'do' still owed by a for/while/if header
    i = 0
    n = len(src)
    while i < n:
        m = _TOKEN.search(src, i)
        if m is None:
            break
        tok = m.group(0)
        i = m.end()
        if tok.startswith('--['):  # long comment
            close = ']' + m.group(1) + ']'
            j = src.find(close, i)
            i = n if j < 0 else j + len(close)
            continue
        if tok.startswith('--'):  # line comment; _TOKEN already ate to EOL
            continue
        if tok.startswith('['):  # long string
            close = ']' + m.group(2) + ']'
            j = src.find(close, i)
            i = n if j < 0 else j + len(close)
            continue
        if tok in ("'", '"'):
            q = tok
            while i < n:
                if src[i] == '\\':
                    i += 2
                    continue
                if src[i] == q or src[i] == '\n':
                    i += 1
                    break
                i += 1
            continue

        if tok in ('if', 'elseif'):
            if tok == 'if':
                stack.append([m.start(), line_of[m.start()], None])
            pending = 'then'
            continue
        if tok in ('for', 'while'):
            stack.append([m.start(), line_of[m.start()], None])
            pending = 'do'
            continue
        if tok == 'then':
            if pending == 'then':
                # header text = source from block start to here
                if stack and stack[-1][2] is None:
                    stack[-1][2] = src[stack[-1][0]:m.end()]
                pending = None
            continue
        if tok == 'do':
            if pending == 'do':
                if stack and stack[-1][2] is None:
                    stack[-1][2] = src[stack[-1][0]:m.end()]
                pending = None
            else:
                stack.append([m.start(), line_of[m.start()], 'do'])
            continue
        if tok == 'function':
            stack.append([m.start(), line_of[m.start()], 'function'])
            continue
        if tok == 'repeat':
            stack.append([m.start(), line_of[m.start()], 'repeat'])
            continue
        if tok in ('end', 'until'):
            if stack:
                st = stack.pop()
                out.append((st[1], line_of[m.start()], st[2] or ''))
            continue
    return out


def enclosing_headers(path, needle):
    """Headers of every block that lexically contains the line matching `needle`.

    Fail-loud: `needle` must match exactly one line of the file.
    """
    with open(path, 'r', encoding='utf-8') as fh:
        src = fh.read()
    hits = [k + 1 for k, ln in enumerate(src.split('\n')) if needle in ln]
    if len(hits) != 1:
        raise SC.SourceConstantError(
            '%s: expected exactly 1 line containing %r, found %d'
            % (os.path.basename(path), needle, len(hits)))
    target = hits[0]
    return [h for (a, b, h) in _lua_blocks(src) if a < target < b]


# --------------------------------------------------------------------------
# Constants, read out of the shipped Lua.  Nothing below is retyped.
# --------------------------------------------------------------------------
def read_source():
    body = SC._strip_comments(SC.function_body('J.IsLateGame', path=JMZ))
    m = re.search(r'DotaTime\(\)\s*>\s*\(\s*J\.IsModeTurbo\(\)\s+and\s+'
                  r'(\d+)\s*\*\s*(\d+)\s+or\s+(\d+)\s*\*\s*(\d+)\s*\)', body)
    if m is None:
        raise SC.SourceConstantError(
            'J.IsLateGame: turbo/normal cutoff is no longer the '
            '`DotaTime() > (IsModeTurbo() and A*B or C*D)` shape this tool reads')
    late_turbo = int(m.group(1)) * int(m.group(2))
    late_normal = int(m.group(3)) * int(m.group(4))

    with open(FARM, 'r', encoding='utf-8') as fh:
        farm = SC._strip_comments(fh.read())
    m = re.search(r'local\s+nEarlyClock\s*=\s*(\d+)\s*\*\s*(\d+)', farm)
    if m is None:
        raise SC.SourceConstantError('mode_farm_generic: nEarlyClock literal not found')
    shipped_clock = int(m.group(1)) * int(m.group(2))
    m = re.search(r"J\.IsSoakCandidate\('tbearly'\)\s+and\s+J\.IsModeTurbo\(\)\s+then\s*"
                  r"\n\s*nEarlyClock\s*=\s*(\d+)\s*\*\s*(\d+)", farm)
    if m is None:
        raise SC.SourceConstantError(
            "mode_farm_generic: the 'tbearly' arm is no longer "
            "`if IsSoakCandidate and IsModeTurbo then nEarlyClock = A*B`")
    armed_clock = int(m.group(1)) * int(m.group(2))

    # [pullcad, 2026-08-23] A gate written as a conjunction of TWO soak ids is
    # frozen FALSE the day either id is promoted.  Assert this one is not.
    gate = re.search(r"J\.IsSoakCandidate\('tbearly'\)[^\n]*", farm).group(0)
    if len(re.findall(r'IsSoakCandidate', gate)) != 1:
        raise SC.SourceConstantError(
            "the 'tbearly' gate names more than one soak id -- see the "
            "`pullcad` lesson in AGENTS.md before touching it")

    m = re.search(r'bot:GetNetWorth\(\)\s*<\s*(\d+)', farm)
    networth = int(m.group(1)) if m else None
    m = re.search(r'if\s+bEarlyGame\s+and\s+nDeaths\s*<\s*(\d+)\s+then', farm)
    deaths = int(m.group(1)) if m else None
    if networth is None or deaths is None:
        raise SC.SourceConstantError(
            'mode_farm_generic: bEarlyGame companion conjuncts moved '
            '(net worth %r, deaths %r)' % (networth, deaths))

    headers = enclosing_headers(FARM, 'local nEarlyClock =')
    gated_by_late = [h for h in headers if 'not J.IsLateGame()' in h]

    return {
        'late_turbo': late_turbo,
        'late_normal': late_normal,
        'shipped_clock': shipped_clock,
        'armed_clock': armed_clock,
        'networth': networth,
        'deaths': deaths,
        'enclosed_by_not_late': bool(gated_by_late),
        'n_enclosing_blocks': len(headers),
    }


def verdict(sc):
    """The arithmetic.  Returns (label, difference-set description)."""
    if not sc['enclosed_by_not_late']:
        return ('LIVE?', 'the `not J.IsLateGame()` enclosure is GONE -- '
                         'this tool\'s premise no longer holds, re-derive')
    reach = sc['late_turbo']          # frames that reach the clause have t <= reach
    lo = min(sc['armed_clock'], sc['shipped_clock'])
    hi = max(sc['armed_clock'], sc['shipped_clock'])
    # legs disagree on [lo, hi); intersect with the reachable set (-inf, reach]
    if lo > reach:
        return ('STRUCTURAL-ZERO', 'legs disagree only on t in [%d, %d), '
                                   'entirely above the reachable ceiling t <= %d'
                                   % (lo, hi, reach))
    if lo == reach:
        return ('STRUCTURAL-ZERO', 'legs disagree only on t in [%d, %d) '
                                   'intersected with t <= %d, i.e. the single '
                                   'instant t == %d.0 exactly (measure zero)'
                                   % (lo, hi, reach, reach))
    return ('DOMAIN-EXISTS', 'legs disagree on t in [%d, %d]'
            % (lo, min(hi, reach)))


# --------------------------------------------------------------------------
# Frames
# --------------------------------------------------------------------------
def deaths_before(timeline, hero, t):
    """Deaths of `hero` strictly before `t`, counted off the event stream."""
    c = 0
    for ev in timeline.get('events', []):
        if ev.get('type') != 'DEATH':
            continue
        if entities.canon(ev.get('target')) != hero:
            continue
        if ev.get('t', 1e9) < t:
            c += 1
    return c


def rung_names(sc):
    """Every rung label, in order.  Load-bearing: a rung that reads ZERO must
    still be PRINTED as zero.  The first cut of this tool used a bare Counter
    and the two rungs that carry the whole finding (L6, L7) simply did not
    appear in the output -- which reads as `not measured`, the one thing this
    stream must never let a zero look like."""
    return [
        'L0 all real-hero frames',
        'L1 post-horn',
        'L2 alive',
        'L3 in the claimed band [%d,%d)' % (sc['armed_clock'], sc['shipped_clock']),
        'L4 net worth < %d' % sc['networth'],
        'L5 deaths < %d' % sc['deaths'],
        'L6 not J.IsLateGame() (t <= %d)' % sc['late_turbo'],
        'L7 legs disagree (t == %d.0 exactly)' % sc['late_turbo'],
    ]


def cascade(timeline, sc):
    """Eight monotone rungs.  Each rung is a SUBSET of the one above it."""
    rung = collections.Counter({k: 0 for k in rung_names(sc)})
    band_lo, band_hi = sc['armed_clock'], sc['shipped_clock']
    reach = sc['late_turbo']
    exact = []
    by_hero, _team = entities.frames_by_hero(timeline)
    for hero, frames in by_hero.items():
        deaths_seen = 0
        death_ts = sorted(ev['t'] for ev in timeline.get('events', [])
                          if ev.get('type') == 'DEATH'
                          and entities.canon(ev.get('target')) == hero)
        di = 0
        for f in frames:
            t = f['t']
            while di < len(death_ts) and death_ts[di] < t:
                di += 1
                deaths_seen += 1
            rung['L0 all real-hero frames'] += 1
            if t < 0:
                continue
            rung['L1 post-horn'] += 1
            if not (f.get('hp_pct') or 0) > 0:
                continue
            rung['L2 alive'] += 1
            if not (band_lo <= t < band_hi):
                continue
            rung['L3 in the claimed band [%d,%d)' % (band_lo, band_hi)] += 1
            if not (f.get('net_worth') or 0) < sc['networth']:
                continue
            rung['L4 net worth < %d' % sc['networth']] += 1
            if not deaths_seen < sc['deaths']:
                continue
            rung['L5 deaths < %d' % sc['deaths']] += 1
            # ---- the enclosing conjunct ----
            if not t <= reach:
                continue
            rung['L6 not J.IsLateGame() (t <= %d)' % reach] += 1
            if not t >= band_lo:
                continue
            rung['L7 legs disagree (t == %d.0 exactly)' % reach] += 1
            exact.append((hero, t))
    return rung, exact


def band_shape(timeline, sc):
    """Shipped-side context: what the corpus does in 18:00-25:00.

    NOT a reading about the lever.  Reported so the separate (shipped) question
    'the whole outer farm block is dead after 18:00 in turbo' has a number.
    """
    lo, hi = sc['armed_clock'], sc['shipped_clock']
    out = {'hero_frames_in_band': 0, 'games_reaching_band': 0,
           'max_t': None, 'nw_lt_cap_in_band': 0}
    mx = None
    reached = False
    for hero, frames in entities.frames_by_hero(timeline)[0].items():
        for f in frames:
            t = f['t']
            mx = t if mx is None or t > mx else mx
            if lo <= t < hi and (f.get('hp_pct') or 0) > 0:
                out['hero_frames_in_band'] += 1
                reached = True
                if (f.get('net_worth') or 0) < sc['networth']:
                    out['nw_lt_cap_in_band'] += 1
    out['max_t'] = mx
    out['games_reaching_band'] = 1 if reached else 0
    return out


def deep(timeline, sc, game, run_id):
    """Frame-by-frame at the ceiling instant, for ONE game.

    For every hero that would have satisfied the clause's OWN conjuncts
    (net worth, deaths) in the claimed band, print the two samples that
    bracket the ceiling t == late_turbo.  This is the frame form of the
    arithmetic: the row below the ceiling is a frame where BOTH legs say
    `bEarlyGame = true`, the row above it is a frame where the enclosing
    block is off for BOTH legs, and there is no row in between where they
    differ.
    """
    reach = sc['late_turbo']
    by_hero, team = entities.frames_by_hero(timeline)
    rows = []
    for hero, frames in sorted(by_hero.items()):
        death_ts = sorted(ev['t'] for ev in timeline.get('events', [])
                          if ev.get('type') == 'DEATH'
                          and entities.canon(ev.get('target')) == hero)
        below = above = None
        for f in frames:
            if f['t'] <= reach:
                below = f
            elif above is None:
                above = f
        if below is None or above is None:
            continue
        d_below = sum(1 for x in death_ts if x < below['t'])
        d_above = sum(1 for x in death_ts if x < above['t'])
        qual = ((below.get('net_worth') or 0) < sc['networth']
                and d_below < sc['deaths'])
        rows.append((hero, team.get(hero), below, above, d_below, d_above, qual))

    print('-- %s / %s  (ceiling t=%d)' % (run_id, game, reach))
    print('   %-16s %4s | %-34s | %-34s' % ('hero', 'team',
                                            'last sample AT OR BELOW ceiling',
                                            'first sample ABOVE ceiling'))
    for hero, tm, b, a, db, da, qual in rows:
        print('   %-16s %4s | t=%-8.1f nw=%-6d d=%d %-6s | t=%-8.1f nw=%-6d d=%d %s'
              % (hero, tm, b['t'], b.get('net_worth') or 0, db,
                 'QUAL' if qual else '',
                 a['t'], a.get('net_worth') or 0, da,
                 'block OFF for BOTH legs'))
    n_qual = sum(1 for r in rows if r[6])
    print('   heroes qualifying on the clause\'s own conjuncts at the ceiling: '
          '%d / %d' % (n_qual, len(rows)))
    print('   samples strictly between the two rows (where legs could differ): 0'
          ' by construction of the bracket')
    return n_qual, len(rows)


# --------------------------------------------------------------------------
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
            path = os.path.join(tdir, name)
            try:
                with open(path) as fh:
                    tl = json.load(fh)
            except (ValueError, OSError) as exc:
                sys.stderr.write('[skip] %s: %s\n' % (game, exc))
                continue
            yield os.path.basename(d.rstrip('/')), game, tl, man.get(game, {})


def run(dirs):
    sc = read_source()
    label, why = verdict(sc)
    total = collections.Counter()
    exact_all = []
    band = {'hero_frames_in_band': 0, 'games_reaching_band': 0,
            'nw_lt_cap_in_band': 0}
    maxt = None
    n_games = 0
    per_side = collections.Counter()
    for run_id, game, tl, meta in iter_games(dirs):
        n_games += 1
        rung, exact = cascade(tl, sc)
        total.update(rung)
        exact_all.extend((run_id, game, h, t) for (h, t) in exact)
        bs = band_shape(tl, sc)
        band['hero_frames_in_band'] += bs['hero_frames_in_band']
        band['games_reaching_band'] += bs['games_reaching_band']
        band['nw_lt_cap_in_band'] += bs['nw_lt_cap_in_band']
        if bs['max_t'] is not None and (maxt is None or bs['max_t'] > maxt):
            maxt = bs['max_t']
        side = meta.get('side') or 'unknown'
        per_side[side] += bs['hero_frames_in_band']

    print('== tbearly: source arithmetic ==')
    for k in ('late_turbo', 'late_normal', 'shipped_clock', 'armed_clock',
              'networth', 'deaths', 'n_enclosing_blocks',
              'enclosed_by_not_late'):
        print('  %-22s %s' % (k, sc[k]))
    print('  VERDICT               %s' % label)
    print('  %s' % why)
    print()
    print('== frames: %d game(s) ==' % n_games)
    prev = None
    for k in rung_names(sc):   # rung order, and ZEROES ARE PRINTED
        drop = '' if prev is None or prev == 0 else \
            '   (-%.1f%%)' % (100.0 * (prev - total[k]) / prev)
        print('  %-46s %8d%s' % (k, total[k], drop))
        prev = total[k]
    print()
    print('== the band the commit message claims to move (SHIPPED-SIDE CONTEXT) ==')
    print('  games whose frames reach [%d,%d) : %d / %d'
          % (sc['armed_clock'], sc['shipped_clock'],
             band['games_reaching_band'], n_games))
    print('  hero-frames in that band          : %d' % band['hero_frames_in_band'])
    print('  ... of which net worth < %-8d : %d'
          % (sc['networth'], band['nw_lt_cap_in_band']))
    print('  max sampled t over all games      : %s' % maxt)
    print('  by side (ab/ba discipline, GH #148):')
    for s in sorted(per_side):
        print('    %-10s %d' % (s, per_side[s]))
    print()
    print('== frames on which the two legs actually disagree ==')
    print('  %d' % len(exact_all))
    for row in exact_all[:20]:
        print('    %s %s %s t=%s' % row)
    return 0


# --------------------------------------------------------------------------
# selfcheck.  Every rung must be able to answer BOTH ways: a filter that can
# only say YES measures nothing, and one that can only say NO manufactures a
# structural zero out of a bug.  That is the selfskip trap this stream keeps
# walking into, so each rung gets a positive AND a negative case.
# --------------------------------------------------------------------------
def _tl(frames, events=None):
    return {'snapshots': frames, 'events': events or []}


def _f(t, hero='axe', idx=1, nw=1000, hp=1.0, pid=0, team=2):
    return {'t': t, 'hero': 'npc_dota_hero_' + hero, 'idx': idx, 'team': team,
            'net_worth': nw, 'hp_pct': hp, 'player_id': pid,
            'x': 0.0, 'y': 0.0, 'level': 10, 'items': [], 'abilities': []}


def selfcheck():
    ok = fail = 0

    def chk(name, cond):
        nonlocal ok, fail
        if cond:
            ok += 1
            print('  PASS  %s' % name)
        else:
            fail += 1
            print('  FAIL  %s' % name)

    sc = read_source()
    chk('IsLateGame turbo cutoff read from Lua == 1080', sc['late_turbo'] == 1080)
    chk('IsLateGame normal cutoff read from Lua == 1800', sc['late_normal'] == 1800)
    chk('shipped nEarlyClock read from Lua == 1500', sc['shipped_clock'] == 1500)
    chk('armed nEarlyClock read from Lua == 1080', sc['armed_clock'] == 1080)
    chk('net worth conjunct read from Lua == 15000', sc['networth'] == 15000)
    chk('deaths conjunct read from Lua == 5', sc['deaths'] == 5)
    chk('nothing above was retyped: no bare 1080/1500 literal in read_source',
        '1080' not in read_source.__code__.co_consts.__str__()
        and '1500' not in read_source.__code__.co_consts.__str__())

    # --- the enclosure, and that the matcher can answer NO ---
    chk('tbearly clause IS inside a `not J.IsLateGame()` block',
        sc['enclosed_by_not_late'])
    chk('the clause is inside several blocks (function + outer if + inner if)',
        sc['n_enclosing_blocks'] >= 3)
    hdrs = enclosing_headers(FARM, 'local nEarlyClock =')
    chk('enclosure list includes the GetFarmDesire function block',
        any(h.startswith('function') for h in hdrs))
    # anti-selfskip: the matcher must NOT report the enclosure for a line that
    # is outside it.  OnEnd() is a top-level function far below the block.
    hdrs_out = enclosing_headers(FARM, 'bot:SetTarget(nil);')
    chk('matcher answers NO for a line outside the block',
        not any('not J.IsLateGame()' in h for h in hdrs_out))

    # --- block matcher unit cases ---
    blocks = _lua_blocks('if a then\n  if b then\n  end\nend\n')
    chk('matcher pairs nested ifs', sorted(blocks) == [(1, 4, 'if a then'),
                                                       (2, 3, 'if b then')])
    blocks = _lua_blocks('if a then\nelseif b then\nelse\nend\n')
    chk('elseif/else do not open blocks', len(blocks) == 1)
    blocks = _lua_blocks('for i=1,2 do\nend\nwhile x do\nend\n')
    chk('for/while headers consume their own `do`', len(blocks) == 2)
    blocks = _lua_blocks('repeat\nuntil x\n')
    chk('repeat/until pairs', blocks == [(1, 2, 'repeat')])
    chk('`end` inside a line comment is ignored',
        _lua_blocks('if a then\n-- end end end\nend\n') == [(1, 3, 'if a then')])
    chk('`end` inside a string is ignored',
        _lua_blocks('if a then\nx = "end end"\nend\n') == [(1, 3, 'if a then')])
    chk('`end` inside a long comment is ignored',
        _lua_blocks('if a then\n--[[ end end ]]\nend\n') == [(1, 3, 'if a then')])

    # --- verdict arithmetic, both ways ---
    lab, _ = verdict(dict(sc))
    chk('verdict on the shipped tree is STRUCTURAL-ZERO', lab == 'STRUCTURAL-ZERO')
    alt = dict(sc, armed_clock=900)
    chk('verdict says DOMAIN-EXISTS if the armed bound moves below the ceiling',
        verdict(alt)[0] == 'DOMAIN-EXISTS')
    alt = dict(sc, late_turbo=1500)
    chk('verdict says DOMAIN-EXISTS if the enclosing ceiling is raised',
        verdict(alt)[0] == 'DOMAIN-EXISTS')
    alt = dict(sc, enclosed_by_not_late=False)
    chk('verdict refuses (LIVE?) if the enclosure disappears',
        verdict(alt)[0] == 'LIVE?')

    # --- cascade rungs, each must cut and each must pass ---
    # NOTE every stream needs a PRE-HORN anchor frame: entities.frames_by_hero
    # drops any entity first sampled after the horn as an illusion, which is
    # the point of using it.  A pre-horn frame only lands on L0, so it never
    # perturbs the counts asserted below.
    def rungs(frames, events=None, heroes=('axe',)):
        anchors = [_f(-30.0, hero=h, idx=1000 + k, pid=k)
                   for k, h in enumerate(heroes)]
        r, ex = cascade(_tl(anchors + frames, events), sc)
        return r, ex

    r, _ = rungs([_f(-31.0, idx=1000), _f(500.0, idx=1000)])
    chk('L1 drops pre-horn frames', r['L1 post-horn'] == 1)
    r, _ = rungs([_f(1200.0, idx=1000, hp=0.0),
                  _f(1200.0, hero='lion', idx=1001, hp=0.5)],
                 heroes=('axe', 'lion'))
    chk('L2 drops hp_pct == 0', r['L2 alive'] == 1)
    band_key = 'L3 in the claimed band [1080,1500)'
    r, _ = rungs([_f(t, idx=1000) for t in (1079.9, 1080.0, 1499.9, 1500.0)])
    chk('L3 keeps exactly [1080,1500)', r[band_key] == 2)
    r, _ = rungs([_f(1200.0, idx=1000, nw=14999),
                  _f(1201.0, idx=1000, nw=15000)])
    chk('L4 net-worth conjunct cuts', r['L4 net worth < 15000'] == 1)
    chk('L4 net-worth conjunct also passes (it is not always NO)',
        r[band_key] == 2 and r['L4 net worth < 15000'] == 1)
    deaths = [{'type': 'DEATH', 't': float(x),
               'target': 'npc_dota_hero_axe'} for x in (10, 20, 30, 40, 50)]
    r, _ = rungs([_f(1200.0, idx=1000)], deaths)
    chk('L5 deaths conjunct cuts at 5 prior deaths', r['L5 deaths < 5'] == 0)
    r, _ = rungs([_f(1200.0, idx=1000)], deaths[:4])
    chk('L5 deaths conjunct passes at 4', r['L5 deaths < 5'] == 1)
    # the load-bearing rung
    r, ex = rungs([_f(t, idx=1000) for t in (1080.0, 1080.1, 1200.0)])
    chk('L6 (not IsLateGame) admits t == 1080.0 exactly',
        r['L6 not J.IsLateGame() (t <= 1080)'] == 1)
    chk('L6 rejects everything strictly above 1080', r[band_key] == 3)
    chk('L7 is exactly the disagreement instant',
        r['L7 legs disagree (t == 1080.0 exactly)'] == 1
        and ex == [('axe', 1080.0)])
    # anti-selfskip: the cascade must be able to report a NON-empty L7, so an
    # empty reading on the corpus is a fact about the corpus and not about the
    # tool silently dropping every row.
    chk('cascade can produce a non-empty L7 (it is not a hard-coded zero)',
        len(ex) == 1)

    # --- illusion cleaner is actually engaged (GH #176 §5.3) ---
    r, _ = rungs([_f(1200.0, idx=1000),
                  _f(1200.0, idx=99), _f(1201.0, idx=99)])  # idx 99: post-horn
    chk('illusion stream (post-horn birth, same name+pid) is dropped',
        r[band_key] == 1)

    print('\n%d PASS / %d FAIL' % (ok, fail))
    return 0 if fail == 0 else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('dirs', nargs='*', help='sweep_run.sh output directories')
    ap.add_argument('--selfcheck', action='store_true')
    ap.add_argument('--source', action='store_true')
    ap.add_argument('--deep', metavar='GAME', action='append', default=[],
                    help='frame-by-frame at the ceiling for this game '
                         '(repeatable; substring match on the game name)')
    a = ap.parse_args()
    if a.selfcheck:
        return selfcheck()
    if a.deep:
        sc = read_source()
        seen = 0
        for run_id, game, tl, _meta in iter_games(a.dirs):
            if not any(pat in game for pat in a.deep):
                continue
            deep(tl, sc, game, run_id)
            seen += 1
        print('\ndeep-checked %d game(s)' % seen)
        return 0 if seen else 1
    if a.source or not a.dirs:
        sc = read_source()
        lab, why = verdict(sc)
        for k in sorted(sc):
            print('%-22s %s' % (k, sc[k]))
        print('VERDICT                %s' % lab)
        print(why)
        return 0
    return run(a.dirs)


if __name__ == '__main__':
    sys.exit(main())

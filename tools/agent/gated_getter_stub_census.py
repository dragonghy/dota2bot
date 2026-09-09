#!/usr/bin/env python3
"""Which armed gates lean on a getter the fixture loader answers with a SILENT 0?

WHY THIS EXISTS.  Four consecutive director rounds each burned a whole round
rediscovering the SAME mechanism, one getter at a time, always by hand:

    §GD (2026-09-08)  cmrguard   -> GetCastRange   read 0 from the catch-all,
                                    so the veto ring collapsed to +400 and the
                                    armed gate PASSED on its own filing frame.
    §GE (2026-09-09)  roamidle   -> GetCurrentActionType read 0, so every
                                    `0 == <sentinel >= 1001>` was false and
                                    `bRelocated` was constructively unreachable.
    §GE                campsel   -> the pivot was not in the instrument at all.
    §GF (2026-09-09)  pullthink  -> GetAnimActivity read 0 on 1100/1100 frames.
    §GF                pulllane  -> GetLaneFrontLocation, which is the ONE name
                                    the loader REFUSES, and that refusal is the
                                    only reason those 9 frames could be told
                                    apart from a reading.

The §GF prescription is one sentence: **a getter with a gate pressing on it
should REFUSE, not answer 0** -- because a refusal is a reading you can take
and a 0 is a reading you cannot tell from an answer.  The prescription has been
on the "next trigger" list four times and has never landed, for the reason such
things never land: the FIRST step is a survey nobody wants to do by hand across
215 gate sites.  This is that survey.

⛔ WHAT THIS IS NOT.  It is NOT a verdict on any id, and a row here is NOT a
reason to return an id from the test set.  Three of the four instances above
were real; a fourth candidate could easily be a getter whose 0 is the RIGHT
answer (`axe_berserkers_call` genuinely has cast range 0 -- §GD.3's whole point
is that the value and the source are different questions, and only the source
is knowable from here).  The census reports **where the question can be asked**,
i.e. where a reading taken through the loader cannot distinguish "the frame says
0" from "nobody asked the frame".  Judging is still the director's.

⛔ AND IT IS NOT A COMPLETENESS CLAIM.  This is a TEXT scan with a declared
reach, and the reach is the honest part of the output:

  * It starts at `J.IsSoakCandidate('<id>')` sites, walks out to the enclosing
    top-level function, and (at --depth 2, the default) also reads the bodies of
    `J.*` / `X.*` helpers NAMED IN THAT BODY.  A pivot three helpers deep is
    invisible to it, and the printed `depth` / `fns` counters say how far it got.
  * A getter reached only through a table of function values, a computed name,
    or a shipped call site OUTSIDE the gated function is not seen.
  * It cannot see whether the frame data exists -- only what the loader answers.
    `campsel`'s wall (the pivot absent from the dumper entirely) is a DIFFERENT
    shape and this tool would not have found it.
  * ⚠️⚠️ **AND IT WOULD NOT HAVE FOUND §GD EITHER, WHICH IS THE INSTANCE THAT
    STARTED THIS.**  `sp.GetCastRange = function(self) ... end` is installed by
    the loader, so this census reads it SERVED -- and it IS served, for the 137
    handles whose KV roster carries a range.  The other 350 fall THROUGH that
    installed function to the same catch-all 0, and `CR_ZERO 350` matched
    `CATCHALL 350` to the digit.  A text scan sees the installation, never the
    fall-through, so **SERVED here means "a name the loader knows", not "an
    answer from the frame"**.  The two shapes this census DOES find are §GE's
    and §GF's: a name the loader does not know at all (STUB0), and a global it
    never installs (NILGLOB).  Pricing the conditional-fall-through shape needs
    a RUN, not a grep -- it is the census's own next purchase.

So `0 findings` from this tool means "no *statically reachable* stubbed getter
under an armed gate", never "the instruments are fine".

CLASSES (the whole vocabulary; the ladder is `default_for` in
`tests/mock/bot_api.lua`, read top-down, and a per-unit `__spec` field beats all
of it):

    SERVED    the loader fills this from the dump (a `__spec` field in
              tests/mock/replay_fixture.lua) -- a reading.
    REFUSED   the loader raises and names itself (GH #61's GetLaneFrontLocation)
              -- also a reading, and the shape §GF prescribes.
    DEFAULT   bot_api.lua answers it with a DECLARED default that is not the
              catch-all (GetLocation -> Vector(0,0,0), GetNearby* -> {},
              NumModifiers -> 0, ...).  Declared is not the same as true, but
              somebody wrote the world assumption down.
    STUB0     ⚠️ the finding.  Nothing matches, so `key:find('^Get')` answers
              **0**, silently, on every frame, and every comparison behind it is
              constant.
    ---       not a getter shape this ladder governs (Is*/Has*/Can*/Was* answer
              false, which is a different, also-silent failure -- printed only
              with --all so the STUB0 column stays readable).

SOURCES.  Arm string: `iterations/streams/test_set.md` line 2 (the same line
`verify_coverage.py` and the batch desk's arm-string census read, so the three
cannot drift apart silently).  Corpus: `lua_corpus.bots_lua_files()`.  Loader:
`tests/mock/replay_fixture.lua` + `tests/mock/bot_api.lua`.

EXIT: 0 ran (a census never fails on its findings), 2 could-not-run -- missing
arm string, missing mock, or a corpus file that vanished mid-scan.  2 is this
repo's did-not-run code (rule 10, run_py_tests.sh, the push gate); it is not a
pass.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'batch_test', 'behavioral'))

from lua_corpus import (CorpusVanished, bots_lua_files,  # noqa: E402
                        read_lua, uncertifiable)
from source_constants import function_span  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEST_SET = os.path.join(ROOT, 'iterations', 'streams', 'test_set.md')
FIXTURE_MOCK = os.path.join(ROOT, 'tests', 'mock', 'replay_fixture.lua')
API_MOCK = os.path.join(ROOT, 'tests', 'mock', 'bot_api.lua')

# `IsSoakCandidate( 'pulllane' )` -- WITH the spaces -- is a real call site in
# this tree, and a grep without `\s*` read it as "no call site at all" during the
# §GF round.  That misreading is one character wide and its failure direction is
# "this id is not wired", so the spaces are load-bearing here.
GATE_RE = r"IsSoakCandidate\s*\(\s*['\"]%s['\"]\s*\)"
# A getter as it is CALLED.  THE CHARACTER IN FRONT OF THE NAME IS THE WHOLE
# CLASSIFICATION, so it is captured, not skipped:
#   `hCc:GetCastRange(`   METHOD -- a unit handle, governed by `default_for`
#   `J.GetManaCost(`      REPO   -- a jmz_func helper that merely starts with Get
#   `GetLaneFrontLocation(`  BARE -- an engine GLOBAL, unless the corpus defines it
# The first cut of this file had no such distinction and reported `J.GetManaCost`,
# `J.GetLanePartner` and `X.GetOne` as stubbed engine getters -- 30+ rows of
# confident nonsense, because every one of them is repo Lua the mock never sees.
# The prefix is read by walking BACK over spaces from the match, not by a
# lookbehind, so `hCc :GetCastRange()` and `hCc:GetCastRange()` read alike.
GETTER_CALL_RE = re.compile(r"\b(Get[A-Za-z0-9_]+)\s*\(")


def call_form(body, at, repo_names):
    """METHOD | REPO | GLOBAL for the getter matched at offset `at`."""
    j = at - 1
    while j >= 0 and body[j] in ' \t':
        j -= 1
    prev = body[j] if j >= 0 else ''
    if prev == ':':
        return 'METHOD'
    if prev == '.':
        # `_G.GetLaneFrontLocation(` is the engine global spelled long-hand;
        # every other dotted receiver is a repo table (J, X, aba_*, ...).
        k = j - 1
        while k >= 0 and body[k] in ' \t':
            k -= 1
        end = k + 1
        while k >= 0 and (body[k].isalnum() or body[k] == '_'):
            k -= 1
        return 'GLOBAL' if body[k + 1:end] == '_G' else 'REPO'
    return 'REPO' if body[at:].split('(')[0].strip() in repo_names else 'GLOBAL'
# A J.*/X.* helper named anywhere in a body -- the depth-2 frontier.
HELPER_RE = re.compile(r"\b([JX])\.([A-Za-z][A-Za-z0-9_]*)\s*\(")
FN_HEADER_RE = re.compile(r"^(?:local\s+)?function\s+", re.M)
STR_RE = re.compile(r"(['\"])(?:\\.|(?!\1).)*\1")


def strip_comments(body):
    """Blank `--` line comments, KEEPING string literals.

    Comments matter because this file's own findings are quoted inside comments
    all over `bots/` ("-- GetCastRange reads 0 here"), and a census that counts
    its own prose reports a getter that no frame ever calls.

    ⚠️ STRINGS ARE KEPT HERE ON PURPOSE, and that is not a detail: the gate id
    IS a string literal (`IsSoakCandidate('pulllane')`).  The first cut of this
    file blanked strings here too, and it printed
    `gate-sites 0 ... ids-with-STUB0 0` for all 37 armed ids -- a clean,
    confident, entirely empty answer.  The only reason it did not become a
    reading is that the reach counters are printed on the same line as the
    finding count, which is the whole argument for printing them.

    ⚠️ AND IT IS LENGTH-PRESERVING, which is not cosmetic.  Gate sites are
    located in the STRIPPED text and then matched against function spans
    computed on the RAW text, so a strip that shortens a line shifts every
    offset after it.  The truncating version of this function put 18 of 36 gate
    sites outside every function span -- including `J.ShouldRegenNotWalkHome`,
    whose `function` header is three lines above its gate -- and the census
    reported that as `18 outside any top-level fn`, i.e. as a property of the
    corpus rather than of itself.
    """
    out = []
    for line in body.split('\n'):
        cut = STR_RE.sub(lambda m: ' ' * len(m.group(0)), line).find('--')
        out.append(line if cut == -1 else line[:cut] + ' ' * (len(line) - cut))
    return '\n'.join(out)


def strip_code_noise(body):
    """`strip_comments`, then blank string literals as well.

    For getter EXTRACTION only, where a name inside a string ("GetFoo(...)" in
    an error message) is prose, not a call.  Never for gate detection.
    Length-preserving for the same reason as above.
    """
    return STR_RE.sub(lambda m: "'" + ' ' * (len(m.group(0)) - 2) + "'",
                      strip_comments(body))


def armed_ids(path=TEST_SET):
    with open(path, 'r', encoding='utf-8') as fh:
        fh.readline()                      # line 1 is the heading
        line = fh.readline().strip()
    ids = [s.strip() for s in line.split(',') if s.strip()]
    if not ids or not all(re.match(r'^[a-z0-9_]+$', i) for i in ids):
        raise ValueError('test_set.md line 2 is not an arm string: %r' % line[:80])
    return ids


def loader_map():
    """(served, refused, default, mock_globals) -- everything else is STUB0.

    Order matters and mirrors the runtime: a `__spec` field is consulted before
    `default_for` ever runs, so SERVED wins; a `_G.X = function() error('LOADER
    REFUSES` overwrites the global outright, so REFUSED wins over both.

    `mock_globals` is a SEPARATE ladder, because engine globals never reach
    `default_for` at all: `api.install` writes the ones it knows onto `_G`, and
    the `_G` metatable auto-resolves ONLY `^[A-Z][A-Z0-9_]*$` names.  So an
    undefined global getter is `nil` and calling it RAISES -- loud, not silent,
    and therefore a different finding (see NILGLOB below).
    """
    served, refused, default, mock_globals = set(), set(), set(), set()

    fx = read_lua(FIXTURE_MOCK)
    # Refusals first: the marker is the loader naming itself in its own error.
    for m in re.finditer(r"_G\.(\w+)\s*=\s*function", fx):
        tail = fx[m.end():m.end() + 400]
        if 'LOADER REFUSES' in tail:
            refused.add(m.group(1))
    body = strip_comments(fx)
    # `__spec` fields are written as `GetFoo = <value>` inside the per-unit spec
    # tables, and as `rawget(u,'__spec').GetFoo = ...` in a few late patches.
    # Three shapes the loader writes an answer in, and all three are needed: a
    # bare key in a spec table (`GetTeam = u.team`), a dotted assignment onto a
    # spec it is building (`sp.GetCastRange = function(self)`, and the late
    # `rawget(u,'__spec').GetFoo = ...`).  Missing the dotted shape is not a
    # small error -- it is what made the first run of this census report
    # GetCastRange and GetSpecialValueInt as stubbed.
    for m in re.finditer(r"^\s*(Get[A-Za-z0-9_]+)\s*=", body, re.M):
        served.add(m.group(1))
    for m in re.finditer(r"\b\w+(?:\[[^\]]*\])?\s*\.\s*(Get[A-Za-z0-9_]+)\s*=", body):
        served.add(m.group(1))
    for m in re.finditer(r"_G\.(Get[A-Za-z0-9_]+)\s*=", body):
        if m.group(1) not in refused:
            mock_globals.add(m.group(1))

    api = strip_comments(read_lua(API_MOCK))
    for m in re.finditer(r"\b(?:_G|G)\.(Get[A-Za-z0-9_]+)\s*=", api):
        mock_globals.add(m.group(1))
    # Two shapes of DECLARED default: a named branch inside `default_for`
    # (`if key == 'GetFoo'`, `key:find('^GetNearby')`) and a real definition
    # (`M.GetFoo = function`, `_G.GetFoo = function`, `GetFoo = function`).
    for m in re.finditer(r"key\s*==\s*'(Get[A-Za-z0-9_]+)'", api):
        default.add(m.group(1))
    for m in re.finditer(r"key:find\('\^(Get[A-Za-z0-9_]+)'\)", api):
        if m.group(1) != 'Get':            # the catch-all itself is not a default
            default.add('^' + m.group(1))
    for m in re.finditer(r"^\s*(?:_G\.|M\.)?(Get[A-Za-z0-9_]+)\s*=\s*function", api, re.M):
        default.add(m.group(1))
    # `spec.GetAttackRange = spec.GetAttackRange or 150` -- MakeUnit/MakeAbility
    # seed a per-unit default, so the name never reaches the `^Get` catch-all.
    for m in re.finditer(r"\bspec\s*\.\s*(Get[A-Za-z0-9_]+)\s*=", api):
        default.add(m.group(1))
    # `handle_getters` answers nil, not 0 -- also silent, also fail-closed, but
    # a DIFFERENT value, and a control test that asserted `== 0` on one of these
    # would go red for the wrong reason.  Declared, so: DEFAULT.
    hg = re.search(r"local\s+handle_getters\s*=\s*\{(.*?)\}", api, re.S)
    if hg:
        for m in re.finditer(r"(Get[A-Za-z0-9_]+)\s*=", hg.group(1)):
            default.add(m.group(1))
    return served, refused, default, mock_globals


def classify(name, form, maps):
    served, refused, default, mock_globals = maps
    if name in refused:
        return 'REFUSED'
    if form == 'GLOBAL':
        # An engine global is either installed by the mock or it is nil, and a
        # nil call RAISES.  A raise is not a reading either (§GD: two sweeps
        # scored 257/257 and 75/1012 raised frames as "measured, answered no"
        # through a two-bucket pcall), but it fails LOUD, so it is its own row.
        return 'SERVED' if name in mock_globals else 'NILGLOB'
    if name in served:
        return 'SERVED'
    if name in default:
        return 'DEFAULT'
    for pref in (p for p in default if p.startswith('^')):
        if name.startswith(pref[1:]):
            return 'DEFAULT'
    return 'STUB0'


def top_level_functions(text):
    """[(name, start, end)] for every `function <name>(` at column 0.

    Uses `function_span` (GH #547): the body ends at the function's OWN `end`,
    not at the next declaration.  35 of 449 top-level functions in
    `jmz_func.lua` have something between the two.
    """
    out = []
    # TWO declaration shapes, and the second is not optional: `X.Foo = function(`
    # is how `ability_item_usage_generic.lua` and the mode files write most of
    # their think functions.  With only the `^function` shape, 36 gate sites
    # resolved into 18 enclosing bodies -- half the sites read as "not inside
    # any function" and contributed nothing, silently.
    pat = (r"^(?:local\s+)?function\s+([\w.:]+)\s*\("
           r"|^[ \t]*([\w][\w.:]*)\s*=\s*function\s*\(")
    for m in re.finditer(pat, text, re.M):
        name = m.group(1) or m.group(2)
        try:
            end = function_span(text, m.start(), name)
        except Exception:
            continue                       # never let one unclosed body kill a census
        out.append((name, m.start(), end))
    return out


def scan(ids, depth, root=None):
    maps = loader_map()
    files = bots_lua_files(root)
    # One pass over the corpus: text, its top-level functions, an index of
    # helper name -> body (so depth 2 costs no extra I/O), and the set of names
    # the repo DEFINES ITSELF -- which is how a bare `GetFoo(` is told apart
    # from an engine global.
    docs, helper_body, repo_names = {}, {}, set()
    for path in files:
        text = read_lua(path)
        fns = top_level_functions(text)
        docs[path] = (text, fns)
        for name, s, e in fns:
            short = name.split('.')[-1].split(':')[-1]
            repo_names.add(short)
            helper_body.setdefault(short, []).append(strip_code_noise(text[s:e]))
        for m in re.finditer(r"local\s+(\w+)\s*=\s*function", text):
            repo_names.add(m.group(1))

    findings = {}
    stats = {'gate_sites': 0, 'gate_sites_outside_fn': 0, 'fns': 0,
             'getters': 0, 'repo_calls': 0}
    for gid in ids:
        gate_re = re.compile(GATE_RE % re.escape(gid))
        hits, bodies = 0, []
        for path, (text, fns) in docs.items():
            for m in gate_re.finditer(strip_comments(text)):
                hits += 1
                # The INNERMOST enclosing top-level body, in case two overlap.
                cands = [f for f in fns if f[1] <= m.start() < f[2]]
                span = max(cands, key=lambda f: f[1]) if cands else None
                if span is None:
                    # Counted, not swallowed: a gate site with no enclosing
                    # top-level function contributes zero getters, and a census
                    # that does not say so is under-reaching in silence.
                    stats['gate_sites_outside_fn'] += 1
                    continue
                bodies.append((os.path.relpath(path, ROOT), span[0],
                               strip_code_noise(text[span[1]:span[2]])))
        stats['gate_sites'] += hits
        seen_fn, rows = set(), {}
        # (file, fn, body, level) -- level 1 is the function holding the gate.
        queue = [(f, n, b, 1) for f, n, b in bodies]
        while queue:
            fpath, fname, body, level = queue.pop(0)
            key = (fpath, fname, level)
            if key in seen_fn:
                continue
            seen_fn.add(key)
            stats['fns'] += 1
            for gm in GETTER_CALL_RE.finditer(body):
                nm = gm.group(1)
                form = call_form(body, gm.start(), repo_names)
                if form == 'REPO':
                    stats['repo_calls'] += 1
                    continue
                stats['getters'] += 1
                cls = classify(nm, form, maps)
                prev = rows.get(nm)
                if prev is None or level < prev['level']:
                    rows[nm] = {'class': cls, 'form': form, 'level': level,
                                'via': '%s (%s)' % (fname, fpath)}
            if level < depth:
                for hm in HELPER_RE.finditer(body):
                    for hb in helper_body.get(hm.group(2), []):
                        queue.append((fpath, '%s.%s' % (hm.group(1), hm.group(2)),
                                      hb, level + 1))
        findings[gid] = {'gate_sites': hits, 'getters': rows}
    return findings, stats


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--depth', type=int, default=2,
                    help='1 = the function holding the gate only; '
                         '2 (default) = plus the J.*/X.* helpers it names')
    ap.add_argument('--id', action='append',
                    help='only these ids (default: every armed id)')
    ap.add_argument('--all', action='store_true',
                    help='print SERVED/REFUSED/DEFAULT rows too, not only STUB0')
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args(argv)

    try:
        ids = args.id or armed_ids()
        findings, stats = scan(ids, max(1, args.depth))
    except (OSError, ValueError) as exc:
        print('GATED-GETTER-STUB: could not run: %s' % exc, file=sys.stderr)
        return 2
    except CorpusVanished as exc:
        uncertifiable(exc, 'the gated-getter stub census')
        return 2

    if args.json:
        print(json.dumps({'findings': findings, 'stats': stats},
                         indent=2, sort_keys=True))
        return 0

    flagged = {i: d for i, d in findings.items()
               if any(r['class'] == 'STUB0' for r in d['getters'].values())}
    nilglob = {i: d for i, d in findings.items()
               if any(r['class'] == 'NILGLOB' for r in d['getters'].values())}
    nogate = [i for i, d in findings.items() if d['gate_sites'] == 0]

    # The reach counters come FIRST, because a zero findings line is only news
    # if the tool looked at something -- and `--id` on an unwired id is the way
    # this census would most plausibly print an empty, confident nothing.
    print('GATED-GETTER-STUB  ids %d  gate-sites %d (%d outside any top-level '
          'fn, unread)  fns-read %d  engine-getter-calls %d  '
          'repo-Get-calls-skipped %d  depth %d  ids-with-STUB0 %d  '
          'ids-with-NILGLOB %d'
          % (len(findings), stats['gate_sites'], stats['gate_sites_outside_fn'],
             stats['fns'], stats['getters'], stats['repo_calls'],
             max(1, args.depth), len(flagged), len(nilglob)))
    if nogate:
        print('  ⚠️  no gate site found for: %s  (a wrapper-only id, or a '
              'renamed gate -- not a finding either way)' % ', '.join(sorted(nogate)))

    tally = {}
    loud = set()
    for gid in sorted(findings):
        rows = findings[gid]['getters']
        show = {n: r for n, r in rows.items()
                if args.all or r['class'] in ('STUB0', 'NILGLOB')}
        if not show:
            continue
        print()
        print('%-16s gate-sites %d' % (gid, findings[gid]['gate_sites']))
        for nm in sorted(show, key=lambda n: (show[n]['class'] != 'STUB0', n)):
            r = show[nm]
            print('   %-7s L%d  %-34s via %s' % (r['class'], r['level'], nm, r['via']))
            if r['class'] == 'STUB0':
                tally.setdefault(nm, []).append(gid)
            elif r['class'] == 'NILGLOB':
                loud.add(nm)

    if tally:
        print()
        print('STUB0 getters by how many armed ids reach them '
              '(the §GF.3 purchase list -- cheapest first is the shortest list):')
        for nm in sorted(tally, key=lambda n: (-len(tally[n]), n)):
            print('   %-34s %d  %s' % (nm, len(tally[nm]), ', '.join(sorted(tally[nm]))))
    if loud:
        print()
        print('NILGLOB (engine globals the mock never installs -- these RAISE, '
              'which is loud, so they are a DIFFERENT purchase from the list '
              'above): %s' % ', '.join(sorted(loud)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

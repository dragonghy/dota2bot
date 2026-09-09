#!/usr/bin/env python3
"""Reach ratchet + classifier assertions for the gated-getter stub census.

The census (`tools/agent/gated_getter_stub_census.py`) exists because §GD..§GF
each spent a whole director round hand-pricing one instrument gap.  Its output
is a purchase list, and a purchase list is only worth reading if the thing that
produced it can be wrong out loud.  Two layers here, and the FIRST one is the
one that has already caught something:

  LAYER 1 -- THE REACH RATCHET (section 1).  Both defects this file was written
  after made the census print a SMALLER, CLEANER answer, never an error:

    * `strip_comments` blanked string literals as well, so
      `IsSoakCandidate('pulllane')` no longer contained its own id.  Output:
      `gate-sites 0 ... ids-with-STUB0 0` across all 37 armed ids -- a
      confident, complete-looking nothing.
    * `strip_comments` TRUNCATED comments instead of blanking them, which
      shifted every byte offset after the first comment on a line.  Gate sites
      were then matched against function spans computed on unshifted text, and
      18 of 36 landed outside every span.  The census reported that as
      `18 outside any top-level fn` -- i.e. as a fact about `bots/`, when it was
      a fact about the reader.

  Both are the shape this repo keeps paying for: the measuring device
  manufacturing the conclusion it reports.  So the reach counters are asserted,
  not just printed.

  LAYER 2 -- THE CLASSIFIER (sections 2-4).  Every class in the vocabulary is
  pinned against the REAL mocks, including the two that are deliberately NOT
  findings (DEFAULT, SERVED) and the one that documents the census's own blind
  spot (GetCastRange reads SERVED although §GD proved 350 of 487 handles fall
  through it to the catch-all).  Loosen any of the loader-map patterns and this
  file names which one.

The empirical half lives in `tests/test_gated_getter_stub_control.lua`: this
file asserts what the census SAYS, that one asserts what the loader DOES.
Neither substitutes for the other -- the whole defect class is the gap between
the two.

EXIT: 0 pass, 1 an assertion failed, 2 could not run.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'agent'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'batch_test', 'behavioral'))

try:
    import gated_getter_stub_census as C
except Exception as exc:                                   # pragma: no cover
    print('COULD NOT RUN: %s' % exc)
    sys.exit(2)

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


# --- 1. reach ratchet, on the real tree ------------------------------------
try:
    ids = C.armed_ids()
    findings, stats = C.scan(ids, 1)
except Exception as exc:                                   # pragma: no cover
    print('COULD NOT RUN: scan failed: %s' % exc)
    sys.exit(2)

check(len(ids) >= 20, 'arm string read as only %d ids' % len(ids))
# 36 sites today for 37 armed ids.  The floor is deliberately well under that:
# the arm string SHRINKS by design (owner P4.2 targets <= 20), so a ratchet
# pinned near today's number would go red for the team doing the right thing --
# the exact wrong shape `test_coarmed_attribution_register`'s `n >= 40` had.
check(stats['gate_sites'] >= 15,
      'only %d gate sites found -- the string-blanking defect makes this 0'
      % stats['gate_sites'])
check(stats['fns'] >= 15,
      'only %d enclosing functions read from %d gate sites'
      % (stats['fns'], stats['gate_sites']))
# The offset-shift defect put HALF the sites here.  One (wandbleed, a gate
# inside a nested closure in ability_item_usage_generic.lua) is genuinely
# outside every top-level body and is the honest residue.
check(stats['gate_sites_outside_fn'] <= 3,
      '%d of %d gate sites resolved to no function -- offsets are shifting'
      % (stats['gate_sites_outside_fn'], stats['gate_sites']))
check(stats['repo_calls'] > 0,
      'zero repo Get* calls skipped -- the call-form split is gone, and every '
      'J.GetFoo/X.GetFoo helper is being priced as an engine getter')
check(stats['getters'] > stats['repo_calls'] * 0.2,
      'engine getter calls (%d) implausibly low against repo ones (%d)'
      % (stats['getters'], stats['repo_calls']))

# --- 2. call form is read from the character in front of the name ----------
BODY = ("local a = J.GetManaCost(h)\n"
        "local b = hCc:GetCastRange()\n"
        "local c = GetLaneFrontLocation(2, 1)\n"
        "local d = X.GetOne(t)\n"
        "local e = _G.GetTeamPlayers()\n"
        "local f = ClosestCamp(bot)\n")
repo_names = {'GetManaCost', 'GetOne', 'ClosestCamp'}
forms = {}
for m in C.GETTER_CALL_RE.finditer(BODY):
    forms[m.group(1)] = C.call_form(BODY, m.start(), repo_names)
check(forms.get('GetManaCost') == 'REPO', 'J.GetManaCost must be REPO')
check(forms.get('GetOne') == 'REPO', 'X.GetOne must be REPO')
check(forms.get('GetCastRange') == 'METHOD', 'hCc:GetCastRange must be METHOD')
check(forms.get('GetLaneFrontLocation') == 'GLOBAL',
      'a bare call the repo does not define must be GLOBAL')
check(forms.get('GetTeamPlayers') == 'GLOBAL', '_G.GetX must be GLOBAL')

# A bare name the repo DOES define is repo Lua, not an engine global.
check(C.call_form('GetManaCost(h)', 0, repo_names) == 'REPO',
      'a bare call to a repo-defined function must be REPO')

# --- 3. the strippers ------------------------------------------------------
src = "-- J.IsSoakCandidate('ghost') and bot:GetGhostly()\nif J.IsSoakCandidate('real') then x = bot:GetGold() end\n"
stripped = C.strip_comments(src)
check(len(stripped) == len(src),
      'strip_comments must be length-preserving (offsets are used against raw '
      'text); got %d vs %d' % (len(stripped), len(src)))
check("'ghost'" not in stripped, 'a gate id inside a comment must not survive')
check("'real'" in stripped,
      'a gate id in CODE must survive -- blanking strings here is the defect '
      'that printed gate-sites 0')
noise = C.strip_code_noise(src)
check(len(noise) == len(src), 'strip_code_noise must be length-preserving')
check('GetGold' in noise and 'GetGhostly' not in noise,
      'strip_code_noise must keep code getters and drop commented ones')

# --- 4. classifier anchors, against the REAL mocks -------------------------
try:
    maps = C.loader_map()
except Exception as exc:                                   # pragma: no cover
    print('COULD NOT RUN: loader_map failed: %s' % exc)
    sys.exit(2)


def cls(name, form='METHOD'):
    return C.classify(name, form, maps)


check(cls('GetLaneFrontLocation', 'GLOBAL') == 'REFUSED',
      'GH #61 refusal must classify as REFUSED')
check(cls('GetTeam') == 'SERVED', 'GetTeam is filled from the frame')
check(cls('GetLevel') == 'SERVED', 'GetLevel is filled from the frame')
# ⚠️ THE DECLARED BLIND SPOT, ASSERTED SO IT CANNOT QUIETLY BECOME A CLAIM.
# §GD measured 350 of 487 hard-CC handles falling THROUGH this installed getter
# to the catch-all 0.  The census still says SERVED, because SERVED means "a
# name the loader knows", not "an answer from the frame".  If someone ever
# teaches the census to model conditional fall-through, this line is where the
# story changes and it should change deliberately.
check(cls('GetCastRange') == 'SERVED',
      'GetCastRange is INSTALLED (§GD limit) -- if this now reads STUB0 the '
      'census docstring is out of date')
check(cls('GetAttackTarget') == 'DEFAULT',
      'handle getters answer nil by declared default, not the catch-all')
check(cls('GetAttackRange') == 'DEFAULT',
      'MakeUnit seeds GetAttackRange, so it is a declared default')
check(cls('GetAnimActivity') == 'STUB0',
      '§GF priced GetAnimActivity as the catch-all 0 by hand; the census must '
      'reach the same answer from source')
check(cls('GetGold') == 'STUB0', 'no fixture carries gold; GetGold is STUB0')
check(cls('GetNearbyHeroes') == 'DEFAULT',
      'the ^GetNearby prefix default must be honoured')
check(cls('GetRoshanDesire', 'GLOBAL') == 'NILGLOB',
      'an engine global the mock never installs is nil, i.e. a raise')

# --- 5. an unwired id answers "no gate site", not an empty finding ---------
f2, s2 = C.scan(['no_such_candidate_id'], 1)
check(s2['gate_sites'] == 0 and f2['no_such_candidate_id']['getters'] == {},
      'an id with no gate site must read as zero sites, not as zero findings')

if fails:
    print('FAIL gated-getter stub census (%d):' % len(fails))
    for f in fails:
        print('  * %s' % f)
    sys.exit(1)
print('OK gated-getter stub census: %d ids, %d gate sites, %d fns, '
      '%d engine getters, %d repo calls skipped'
      % (len(ids), stats['gate_sites'], stats['fns'], stats['getters'],
         stats['repo_calls']))

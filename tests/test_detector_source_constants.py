#!/usr/bin/env python3
"""Every detector threshold that claims to mirror shipped Lua must still mirror it.

GH #90 (director ruling 2026-08-21T15:0xZ).  `capmono_refusal.py` carried its
whole attribution argument on the sentence ">850u guarantees `lanesurv`'s burst
retreat does not fire on its own".  The rule scans 1100u.  The literal 850 does
not occur anywhere in jmz_func.lua.  Half the registered domain (423/793 frames)
sat inside the rule it promised to exclude, and nothing in the tree could notice:
the number lived only in a Python file that no test ever compared to the Lua.

The incident is cheap to fix; the CLASS is what this file closes.  Two layers:

  LAYER 1 -- the extractor is fail-loud (section 3).  A defaulting lookup would
  reproduce the exact failure mode (a plausible number, no red), so "raises when
  it cannot find the site" and "raises when the site is ambiguous" are asserted
  behaviours, not implementation details.

  LAYER 2 -- the REGISTRY below (section 2).  Every detector constant whose
  meaning is "the shipped rule reaches this far" is listed with the source site
  it mirrors.  The replay group verified lanekill_commit.py's four literals by
  hand on 2026-08-21; hand checks do not survive the next edit, so they are
  recorded here instead.  Adding a detector with such a constant means adding a
  row -- and if the Lua moves, this file goes red naming the site.

WHY NOT JUST GREP THE DOCSTRINGS: a docstring claim is prose ("beyond this the
rule cannot fire"), and the number in it may legitimately differ from any single
literal in the rule.  A registry states which call site is meant, which is the
part a reader cannot reconstruct and the part that rots.

Run: python3 tests/test_detector_source_constants.py   (or tests/run_py_tests.sh)
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral')
sys.path.insert(0, BEHAV)

from source_constants import (call_arg, literal, function_body,  # noqa: E402
                              assignment, SourceConstantError)

LION_LUA = os.path.join(ROOT, 'bots', 'BotLib', 'hero_lion.lua')

FAIL = []


def check(name, cond, detail=''):
    if cond:
        print('  ok   %s' % name)
    else:
        FAIL.append(name)
        print('  FAIL %s %s' % (name, detail))


def eq(name, got, want):
    check(name, got == want, '(got %r, want %r)' % (got, want))


# ---------------------------------------------------------------- section 1
# The extractor reads the values the replay group read by hand.
print('=== 1. shipped constants, read out of jmz_func.lua ===')

LANESURV_REACH = call_arg('J.ShouldRetreatLaneBurst', 'J.GetNearbyHeroes',
                          index=1, where={2: 'true'})
L1_ENEMY = call_arg('J.ShouldInitiateLaneKill', 'J.GetNearbyHeroes',
                    index=1, where={2: 'true'})
L5_ENEMY = call_arg('J.ShouldSupportComboKill', 'J.GetNearbyHeroes',
                    index=1, where={2: 'true'})
L5_VETO = literal('J.ShouldSupportComboKill',
                  r'GetUnitToUnitDistance\([^()]*\)\s*<=\s*(?P<n>\d+)')
DEPTH_RE = (r'GetLocationToLocationDistance\(\s*hTarget:GetLocation\(\), '
            r'hEnemyAncient:GetLocation\(\) \)\s*<=\s*(?P<n>\d+)')
L1_DEPTH = literal('J.ShouldInitiateLaneKill', DEPTH_RE)
L5_DEPTH = literal('J.ShouldSupportComboKill', DEPTH_RE)

eq('lanesurv enemy scan radius', LANESURV_REACH, 1100.0)
eq('l1trade enemy ring', L1_ENEMY, 800.0)
eq('l5combo enemy ring', L5_ENEMY, 900.0)
eq('l5combo 2-enemy veto ring', L5_VETO, 700.0)
eq('l1trade target depth leash', L1_DEPTH, 800.0)
eq('l5combo target depth leash', L5_DEPTH, 400.0)

# The ally scan in ShouldInitiateLaneKill is a DIFFERENT call to the same
# callee.  If `where=` were ever dropped, the enemy ring above would silently
# become 1000 -- pin the ally radius so the two can never be confused.
eq('l1trade ally scan radius (the decoy)',
   call_arg('J.ShouldInitiateLaneKill', 'J.GetNearbyHeroes',
            index=1, where={2: 'false'}), 1000.0)

# ---------------------------------------------------------------- section 2
# THE REGISTRY: detector constant -> the shipped value it must equal.
print('=== 2. registry: detector constants still mirror their source site ===')

import capmono_refusal as capmono          # noqa: E402
import lanekill_commit as lanekill         # noqa: E402
import filter_outcome_coupling as foc      # noqa: E402
import lion_drain_census as drain          # noqa: E402
import lion_drain_start_domain as drstart  # noqa: E402

# The Lion Mana Drain pair, both levers.  `X.nEDrainDangerRadius` is a
# file-level constant rather than an inline literal, which is why the extractor
# grew `assignment()`; the 2.0s damage window IS an inline call argument and is
# read from each gate separately, because "both levers use the same predicate"
# is a claim the pre-flight of 2026-08-21T22Z leans its whole conclusion on.
LION_DRAIN_RADIUS = assignment('X.nEDrainDangerRadius', LION_LUA)
LION_DRAIN_WINDOW_START = call_arg('X.lion_IsDrainSafeToStart',
                                   'WasRecentlyDamagedByAnyHero', 0, path=LION_LUA)
LION_DRAIN_WINDOW_STOP = call_arg('X.lion_ShouldStopDrain',
                                  'WasRecentlyDamagedByAnyHero', 0, path=LION_LUA)

REGISTRY = [
    # (label, detector value, shipped value)
    ('capmono_refusal.ENE_LO ~ lanesurv scan', capmono.ENE_LO, LANESURV_REACH),
    ('capmono_refusal.LANESURV_REACH', capmono.LANESURV_REACH, LANESURV_REACH),
    ('lanekill_commit.ENEMY_RANGE_CORE', lanekill.ENEMY_RANGE_CORE, L1_ENEMY),
    ('lanekill_commit.ENEMY_RANGE_SUP', lanekill.ENEMY_RANGE_SUP, L5_ENEMY),
    ('lanekill_commit.SUP_CLOSE_RANGE', lanekill.SUP_CLOSE_RANGE, L5_VETO),
    ('lanekill_commit.DEPTH_CORE', lanekill.DEPTH_CORE, L1_DEPTH),
    ('lanekill_commit.DEPTH_SUP', lanekill.DEPTH_SUP, L5_DEPTH),
    ('filter_outcome_coupling.LANESURV_R', foc.LANESURV_R, LANESURV_REACH),
    ('lion_drain_census.DANGER_RADIUS', drain.DANGER_RADIUS, LION_DRAIN_RADIUS),
    ('lion_drain_census.DAMAGE_WINDOW', drain.DAMAGE_WINDOW,
     LION_DRAIN_WINDOW_STOP),
    ('lion_drain_start_domain.DANGER_RADIUS', drstart.DANGER_RADIUS,
     LION_DRAIN_RADIUS),
    ('lion_drain_start_domain.DAMAGE_WINDOW', drstart.DAMAGE_WINDOW,
     LION_DRAIN_WINDOW_START),
]
for label, got, want in REGISTRY:
    eq(label, float(got), float(want))

# The GH #90 incident itself, stated as an assertion: the live domain floor is
# no longer the invented literal.  `LEGACY_ENE_LO` may keep it (archived
# readings must stay reproducible) but the domain the tool scans may not.
check('capmono live floor is not the invented 850',
      capmono.ENE_LO != 850.0, '(ENE_LO=%r)' % capmono.ENE_LO)
eq('capmono legacy floor preserved for reproducibility',
   capmono.LEGACY_ENE_LO, 850.0)
check('filter_outcome_coupling still audits the 850 domain on purpose',
      foc.ENE_LO == 850.0, '(ENE_LO=%r)' % foc.ENE_LO)

# The 2026-08-21T22Z pre-flight concluded that `liondrain` has no domain of its
# own because `liondrainstop` runs THE SAME predicate one think tick later.
# That conclusion is only as good as the sameness, so pin it: same window, and
# both gates handing the same NAMED constant to the same scan.  (`call_arg`
# cannot read the radius here -- it is a name, not a literal -- which is the
# point: an inlined number in either gate makes these two checks go red.)
eq('both drain levers share the 2s damage window',
   LION_DRAIN_WINDOW_START, LION_DRAIN_WINDOW_STOP)
for _gate in ('X.lion_IsDrainSafeToStart', 'X.lion_ShouldStopDrain'):
    check('%s scans J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius, true )' % _gate,
          'J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius, true'
          in function_body(_gate, LION_LUA))

# ---------------------------------------------------------------- section 3
# The extractor must FAIL LOUDLY.  This is the layer that makes the registry
# trustworthy: a lookup that silently returned a default would let every row
# above pass while measuring nothing.
print('=== 3. fail-loud contract ===')


def raises(name, fn):
    try:
        got = fn()
    except SourceConstantError:
        print('  ok   %s' % name)
        return
    except Exception as exc:                       # noqa: BLE001
        FAIL.append(name)
        print('  FAIL %s (raised %s, want SourceConstantError)'
              % (name, type(exc).__name__))
        return
    FAIL.append(name)
    print('  FAIL %s (returned %r instead of raising)' % (name, got))


raises('missing function raises',
       lambda: call_arg('J.NoSuchFunctionAnywhere', 'J.GetNearbyHeroes', 1))
raises('missing call site raises',
       lambda: call_arg('J.ShouldRetreatLaneBurst', 'J.NoSuchCallee', 1))
raises('AMBIGUOUS call site raises (two GetNearbyHeroes, no where=)',
       lambda: call_arg('J.ShouldInitiateLaneKill', 'J.GetNearbyHeroes', 1))
raises('argument index past the end raises',
       lambda: call_arg('J.ShouldRetreatLaneBurst', 'J.GetNearbyHeroes', 9,
                        {2: 'true'}))
raises('non-numeric argument raises rather than coercing',
       lambda: call_arg('J.ShouldRetreatLaneBurst', 'J.GetNearbyHeroes', 0,
                        {2: 'true'}))
raises('pattern matching nothing raises',
       lambda: literal('J.ShouldRetreatLaneBurst', r'zzz(?P<n>\d+)'))
raises('missing module-level assignment raises',
       lambda: assignment('X.nNoSuchConstant', LION_LUA))
raises('assignment to a non-number raises rather than coercing',
       lambda: assignment('local sAbilityList', LION_LUA))

# Comments are stripped before matching: jmz_func.lua explains its own
# thresholds in prose ("skip any target meaningfully past the midline
# (>800 ...)"), and a reader that counted those would both miscount sites and
# risk matching a number a code edit left stale in the prose above it.
#
# ON A SYNTHETIC FILE, ON PURPOSE.  The first version of this section asserted
# comment stripping against jmz_func.lua and it was VACUOUS: deleting
# `_strip_comments` entirely left every number in this test unchanged, because
# today's real comments happen not to match today's regexes.  A test whose
# mutation does not land is not a passing test, it is an unmeasured claim
# (test_set.md AD.3).  A synthetic body makes the decoy REACHABLE, so removing
# comment stripping now goes red here.
body = function_body('J.ShouldInitiateLaneKill')
check('real prose decoy still present (why the stripping exists at all)',
      '(>800 ancient-distance depth)' in body)
eq('depth read is the code value, not the prose one', L1_DEPTH, 800.0)

import tempfile                                    # noqa: E402

with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False) as fh:
    fh.write(
        'function J.Decoy( bot )\n'
        '\t-- old shape, kept for history: J.GetNearbyHeroes( bot, 9999, true, X )\n'
        '\tlocal t = J.GetNearbyHeroes( bot, 500, true, BOT_MODE_NONE )\n'
        '\tif GetUnitToUnitDistance( bot, e ) <= 250 then return nil end -- was <= 999\n'
        'end\n')
    SYNTH = fh.name

eq('a commented-out call site is not a call site',
   call_arg('J.Decoy', 'J.GetNearbyHeroes', 1, {2: 'true'}, path=SYNTH), 500.0)
eq('a number quoted in a trailing comment is not the threshold',
   literal('J.Decoy', r'GetUnitToUnitDistance\([^()]*\)\s*<=\s*(?P<n>\d+)',
           path=SYNTH), 250.0)
os.unlink(SYNTH)

print()
if FAIL:
    print('%d FAILED: %s' % (len(FAIL), ', '.join(FAIL)))
    sys.exit(1)
print('all detector source constants match their shipped sites')

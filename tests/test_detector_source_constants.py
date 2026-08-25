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
import itemtrip_contract as itemtrip       # noqa: E402
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

# `itemtrip`'s four visible clauses (J.IsWastefulItemTrip, jmz_func.lua).  The
# two ring reads are the SAME callee with the same argument shape -- only the
# radius differs -- so `where=` cannot separate them and each is pinned by the
# expression it feeds instead: the 1600 one is tested inline (`#... > 0`), the
# 3000 one is assigned to `hEnemyList`.  Getting these two backwards would swap
# "nobody near" for "nobody who hit me near", which is exactly the confusion
# the registry exists to make loud.
ITEMTRIP_HP = literal('J.IsWastefulItemTrip',
                      r'J\.GetHP\(\s*bot\s*\)\s*<\s*(?P<n>[\d.]+)')
ITEMTRIP_RING = literal('J.IsWastefulItemTrip',
                        r'#J\.GetNearbyHeroes\(\s*bot,\s*(?P<n>[\d.]+),\s*true')
ITEMTRIP_ATTR = literal(
    'J.IsWastefulItemTrip',
    r'hEnemyList\s*=\s*J\.GetNearbyHeroes\(\s*bot,\s*(?P<n>[\d.]+),\s*true')
ITEMTRIP_FDIST = literal(
    'J.IsWastefulItemTrip',
    r'GetDistanceFromAllyFountain\(\s*bot\s*\)\s*<\s*(?P<n>[\d.]+)')

REGISTRY = [
    # (label, detector value, shipped value)
    ('itemtrip_contract.HP_FLOOR', itemtrip.HP_FLOOR, ITEMTRIP_HP),
    ('itemtrip_contract.RING_U', itemtrip.RING_U, ITEMTRIP_RING),
    ('itemtrip_contract.ATTR_U', itemtrip.ATTR_U, ITEMTRIP_ATTR),
    ('itemtrip_contract.FDIST_MIN', itemtrip.FDIST_MIN, ITEMTRIP_FDIST),
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

# The ally-health floor is the ONE member of the 0.40 family that is a real
# mirror: `J.GetHP( hAlly ) >= 0.4` is shipped, in BOTH lane-kill helpers.  It
# was never registered, which is the dangerous half of test_set.md AJ.5: a
# reader scanning behavioral/ sees four identical 0.40s and the tidy-looking
# move is to fuse them.  Fusing this one with the proxy would make a Lua edit
# to the ally floor silently drag the lethality proxy -- and with it the frame
# selection in find_kill_windows.py -- which is GH #90 with extra steps.
ALLY_HP_RE = r'J\.GetHP\(\s*\w+\s*\)\s*>=\s*(?P<n>[\d.]+)'
L1_ALLY_HP = literal('J.ShouldInitiateLaneKill', ALLY_HP_RE)
L5_ALLY_HP = literal('J.ShouldSupportComboKill', ALLY_HP_RE)
eq('lanekill_commit.ALLY_HP_MIN mirrors ShouldInitiateLaneKill',
   float(lanekill.ALLY_HP_MIN), L1_ALLY_HP)
eq('lanekill_commit.ALLY_HP_MIN mirrors ShouldSupportComboKill',
   float(lanekill.ALLY_HP_MIN), L5_ALLY_HP)
eq('both lane-kill helpers use the SAME ally floor (the scanner assumes one)',
   L1_ALLY_HP, L5_ALLY_HP)

# The field-regen family, pinned on the census's first real contact with
# incoming code: `fieldbuy_domain` and `stayfield2_margin` both landed on main
# today carrying a new module-level HP constant, and section 2b went red on
# both.  Both cite a Lua site in a COMMENT and both citations are substantively
# right -- and both line numbers are already off (781 vs the real 779, 4762 vs
# the real 4767), the same drift that made test_set.md AJ.5's `jmz_func.lua:6932`
# point into an unrelated helper.  Pinning them here is the fix: the extractor
# finds the clause by shape, so the line number never has to be right again.
GENERIC_LUA = os.path.join(ROOT, 'bots', 'item_purchase_generic.lua')
NHP_LO_RE = r'nHP < (?P<n>[\d.]+)'
NHP_HI_RE = r'nHP > (?P<n>[\d.]+)'

# TWO DIFFERENT HELPERS WITH DIFFERENT UPPER BOUNDS -- checked, not assumed.
# `stayfield2`'s whole point is a wider band than the shipped situation test, so
# 0.55 and 0.75 disagreeing is the DESIGN, not staleness.  Pin both so that if
# either moves, the one that moved is named.
SITUATION_HP_LO = literal('J.IsFieldRegenSituation', NHP_LO_RE)
SITUATION_HP_HI = literal('J.IsFieldRegenSituation', NHP_HI_RE)
STAYREGEN_HP_HI = literal('J.ShouldStayAndRegen', NHP_HI_RE)
# Disambiguated by the soak-candidate name, not by position: there are two
# `J.GetHP(bot) <` comparisons in ItemPurchaseThink and picking "the first"
# is the mistake `where=` exists to prevent.
FIELDREGEN_BUY_HP = literal(
    'ItemPurchaseThink',
    r"IsSoakCandidate\('fieldregen'\)[\s\S]*?J\.GetHP\(bot\) < (?P<n>[\d.]+)",
    path=GENERIC_LUA)

import fieldbuy_domain as fbd                      # noqa: E402
import stayfield2_margin as s2m                    # noqa: E402
import stayfield_domain as sfd                     # noqa: E402

eq('stayfield_domain.HP_LO mirrors J.IsFieldRegenSituation',
   float(sfd.HP_LO), SITUATION_HP_LO)
eq('stayfield_domain.HP_HI mirrors J.IsFieldRegenSituation',
   float(sfd.HP_HI), SITUATION_HP_HI)
eq('stayfield2_margin.SHIPPED_HP_HI mirrors J.ShouldStayAndRegen',
   float(s2m.SHIPPED_HP_HI), STAYREGEN_HP_HI)
eq('fieldbuy_domain.FIELDREGEN_HP mirrors the fieldregen purchase branch',
   float(fbd.FIELDREGEN_HP), FIELDREGEN_BUY_HP)
check('the two regen helpers really do carry different ceilings '
      '(stayfield2 widens the band on purpose)',
      SITUATION_HP_HI != STAYREGEN_HP_HI,
      '(situation=%r stayregen=%r -- if these ever converge, one of the two '
      'detectors is measuring the other helper)'
      % (SITUATION_HP_HI, STAYREGEN_HP_HI))

# ---------------------------------------------------------------- section 2b
# THE HP-CONSTANT CENSUS (test_set.md AJ.5, director ruling 2026-08-22T21:0xZ).
#
# Section 2 answers "does this constant still equal its source".  It cannot ask
# the question AJ.5 actually raised, which is one level up: HOW MANY COPIES OF
# THIS NUMBER ARE THERE, and does each one know what it is?  `#92` did a
# sensitivity analysis on `lanekill_commit.VICTIM_HP` and flipped a reading's
# sign; for three days nobody asked who else wrote the same number down.  The
# answer was four sites, one of which (`find_kill_windows.py`) does not produce
# a reading at all -- it selects which frames become fixtures.
#
# So this section censuses every MODULE-LEVEL NAMED HP FRACTION in behavioral/
# and requires each to be classified.  Three classes, and the classification is
# the deliverable -- "converge the duplicates" would have been WRONG here:
#
#   MIRROR       equals a literal in shipped Lua; section 2 pins it to the site.
#   PROXY        stands in for a predicate the dumper cannot observe.  Defined
#                once, in roam_conversion, and IMPORTED -- never re-typed.
#   INDEPENDENT  the detector's own tunable.  May share a number with another
#                row by coincidence; converging it would be a defect.
#
# BOUNDARY, stated rather than implied: this censuses module-level ASSIGNMENTS.
# Inline HP literals inside function bodies (tp_attribution's 0.35, capmono's
# 0.55, ...) are a larger population and are NOT covered -- an unregistered
# inline literal still passes here.  Backlog item, not a claim.
print('=== 2b. HP-constant census: every copy classified, no unregistered copy ===')

import re                                          # noqa: E402
import detect as det                               # noqa: E402
import roam_conversion as rc                       # noqa: E402

HP_CENSUS = {
    # 'module:NAME': (class, note)
    'roam_conversion:VICTIM_HP_PROXY':   ('PROXY', 'the definition site'),
    'roam_conversion:VICTIM_HP':         ('PROXY', 'legacy alias of the above'),
    'lanekill_commit:VICTIM_HP':         ('PROXY', 'imported'),
    'find_kill_windows:VICTIM_HP':       ('PROXY', 'imported; selects fixture frames'),
    'lanekill_commit:ALLY_HP_MIN':       ('MIRROR', 'jmz_func.lua:7389 / :7354'),
    'capmono_refusal:HP_LO':             ('MIRROR', 'registered via section 2 domain'),
    'capmono_refusal:HP_HI':             ('MIRROR', 'registered via section 2 domain'),
    'creeppull_domain:HP_MIN':           ('MIRROR', 'J.IsCreepPullSafe >= 0.5'),
    'pullcamp_domain:HP_MIN':            ('MIRROR', 'J.IsLanePullSafe >= 0.5'),
    'stayfield_domain:HP_LO':            ('MIRROR', 'jmz_func.lua:4826'),
    'stayfield_domain:HP_HI':            ('MIRROR', 'jmz_func.lua:4826'),
    'stayfield_domain:BRANCH_HP':        ('MIRROR', 'ability_item_usage_generic.lua:5514'),
    'stayfield_domain:BRANCH_HPMP':      ('MIRROR', 'ability_item_usage_generic.lua:5514'),
    'fieldregen_supply:LOW_HP':          ('MIRROR', 'both ids share this literal'),
    'fieldbuy_domain:FIELDREGEN_HP':     ('MIRROR', 'item_purchase_generic.lua fieldregen branch; pinned above'),
    'stayfield2_margin:SHIPPED_HP_HI':   ('MIRROR', 'J.ShouldStayAndRegen; wider than the situation test BY DESIGN'),
    'hometp_highhp:HEAL_CORE_HP':        ('MIRROR', 'cores need HP < 0.75 (:1315)'),
    'itemtrip_contract:HP_FLOOR':        ('MIRROR', 'J.IsWastefulItemTrip; pinned above'),
    'detect:WASTE_HP_PCT':               ('INDEPENDENT', 'detector "low HP" for wasteful TP'),
    'detect:OVERCHASE_VICTIM_HP':        ('INDEPENDENT', 'enemy-side victim pick; 0.45 on purpose'),
    'detect:LIMBO_HP':                   ('INDEPENDENT', 'shares 0.40 with the proxy by coincidence'),
}

# A module-level assignment of an HP-looking name to a fraction in [0, 1].
CENSUS_RE = re.compile(
    r'^(?P<names>(?:HP_|LOW_HP|LIMBO_HP)\w*|\w*_HP(?:_\w+)?|\w*HP_PCT'
    r'|VICTIM_HP\w*|BRANCH_HP\w*)'
    # The trailing `(?:#.*)?` is not decoration.  Without it the `$` anchor
    # refused every line that carried an explanatory comment -- which is most
    # of the interesting ones -- and the census swept 7 sites instead of 17
    # while every classification assertion below still printed ok.  The
    # anti-vacuity guard is what turned that red; it was added before the first
    # run, not after this was found.
    r'(?P<more>(?:\s*,\s*\w+)*)\s*=\s*(?P<rhs>[^=#\n]+?)\s*(?:#.*)?$')

found = {}
for fn in sorted(os.listdir(BEHAV)):
    if not fn.endswith('.py'):
        continue
    mod = fn[:-3]
    with open(os.path.join(BEHAV, fn)) as fh:
        for line in fh:
            m = CENSUS_RE.match(line.rstrip('\n'))
            if not m:
                continue
            names = [m.group('names')] + [x.strip() for x in
                                          m.group('more').split(',') if x.strip()]
            rhs = [v.strip() for v in m.group('rhs').split(',')]
            if len(rhs) != len(names):
                rhs = [m.group('rhs').strip()] * len(names)
            for nm, val in zip(names, rhs):
                # keep fractions and imported aliases; drop unrelated numbers
                try:
                    if not (0.0 < float(val) < 1.0):
                        continue
                except ValueError:
                    if not re.match(r'^[A-Z][A-Z0-9_]*$', val):
                        continue
                found['%s:%s' % (mod, nm)] = val

# THE ANTI-VACUITY GUARD.  A census that silently matches nothing would pass
# every assertion below while measuring nothing -- the failure this repo has
# now hit six times.  The four sites AJ.5 named must all be in the sweep.
for must in ('roam_conversion:VICTIM_HP_PROXY', 'lanekill_commit:VICTIM_HP',
             'find_kill_windows:VICTIM_HP', 'detect:LIMBO_HP',
             'lanekill_commit:ALLY_HP_MIN'):
    check('census reaches %s' % must, must in found,
          '(swept %d sites: %s)' % (len(found), sorted(found)))

for key in sorted(found):
    check('%s is classified (%s)' % (key, HP_CENSUS.get(key, ('UNREGISTERED',))[0]),
          key in HP_CENSUS,
          '-- a new module-level HP constant appeared and no one said what it '
          'is.  Add a row to HP_CENSUS: MIRROR (and pin it in section 2), '
          'PROXY (import it, do not retype it), or INDEPENDENT (say why it may '
          'share a number).')

# PROXY means IMPORTED, and `is` proves it: an equal-valued retyped literal
# would be a different object and go red here, which is exactly the state
# AJ.5 found the tree in.
import find_kill_windows as fkw                    # noqa: E402
check('lanekill_commit.VICTIM_HP IS the proxy object (imported, not retyped)',
      lanekill.VICTIM_HP is rc.VICTIM_HP_PROXY)
check('find_kill_windows.VICTIM_HP IS the proxy object (imported, not retyped)',
      fkw.VICTIM_HP is rc.VICTIM_HP_PROXY)
check('roam_conversion.VICTIM_HP is the alias, not a second literal',
      rc.VICTIM_HP is rc.VICTIM_HP_PROXY)

# ANTI-FUSION.  The proxy and the ally mirror share a number and nothing else.
# If someone "converges the duplicates", the mirror stops tracking the Lua --
# so assert they are independently reachable, not that they are equal.
check('the ally MIRROR is not the same object as the PROXY',
      lanekill.ALLY_HP_MIN is not rc.VICTIM_HP_PROXY,
      '-- fusing these makes a Lua edit to the ally floor move the frame '
      'selection in find_kill_windows.py')
check('detect.LIMBO_HP is not the same object as the PROXY',
      det.LIMBO_HP is not rc.VICTIM_HP_PROXY)

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

# The two promoted TP guards (GH #159).  `tp_channel_death.py` mirrors BOTH
# radii, and the whole finding of 2026-08-24T21:48Z is that they DISAGREE:
# `tpsafe2` scans 700 u but never runs in BOT_MODE_RETREAT, while `tpsafe` --
# the guard that does run there -- only looks 350 u, so the band between them
# is refused by neither.  Pinning both makes that asymmetry machine-checked
# instead of prose: if either Lua radius moves, the band moves with it and the
# `band_of()` split silently starts measuring a gap that no longer exists.
import tp_channel_death as tpcd                    # noqa: E402

WALK_GUARD_R = call_arg('J.ShouldWalkNotTp', 'J.GetNearbyHeroes',
                        index=1, where={2: 'true'})
# [tpreach, GH #159] That scan is now a gated widening, `bWide and 1200 or 700`.
# The detector mirrors the SHIPPED leg on purpose: `tpreach` is a soak candidate
# that entered the test set at 2026-08-24T22:xxZ, AFTER W8 launched, so every
# corpus in hand -- and every one in flight -- was produced with it unarmed.
# The armed leg is pinned too, so that the day a wave arms `tpreach`, the
# reading the detector owes that corpus is already written down here rather
# than inferred from the Lua by whoever is reading the verdict.
TP_SCAN_R = call_arg('J.CanEnemyInterruptTpChannel', 'J.GetNearbyHeroes',
                     index=1, where={2: 'true'}, arm='shipped')
TP_SCAN_R_ARMED = call_arg('J.CanEnemyInterruptTpChannel', 'J.GetNearbyHeroes',
                           index=1, where={2: 'true'}, arm='armed')
eq('tp_channel_death.WALK_GUARD_RADIUS_U mirrors J.ShouldWalkNotTp',
   float(tpcd.WALK_GUARD_RADIUS_U), WALK_GUARD_R)
eq('tp_channel_death.SCAN_RADIUS_U mirrors the SHIPPED leg of J.CanEnemyInterruptTpChannel',
   float(tpcd.SCAN_RADIUS_U), TP_SCAN_R)
check('arming tpreach can only WIDEN that scan, never narrow it',
      TP_SCAN_R_ARMED > TP_SCAN_R,
      '(shipped=%r armed=%r)' % (TP_SCAN_R, TP_SCAN_R_ARMED))
# Omitting `arm=` must still refuse: a threshold that quietly became computed
# is exactly what this module exists to fail loudly on, and the tpreach reading
# above must not have relaxed that for everyone else.
try:
    call_arg('J.CanEnemyInterruptTpChannel', 'J.GetNearbyHeroes',
             index=1, where={2: 'true'})
    check('a gated widening is still refused without arm=', False)
except SourceConstantError as exc:
    check('a gated widening is still refused without arm=, and names the fix',
          "arm='shipped'" in str(exc), str(exc))
# The ally-refuge scan in ShouldWalkNotTp is the decoy: same callee, same
# argument slot, `false` instead of `true`.  Without `where=` the walk guard's
# on-face radius would silently read 600 and the gap would vanish on paper.
eq('the ally-refuge scan is a different call (the decoy)',
   call_arg('J.ShouldWalkNotTp', 'J.GetNearbyHeroes',
            index=1, where={2: 'false'}), 600.0)
check('the two TP guards really do disagree (the #159 gap exists in source)',
      WALK_GUARD_R < TP_SCAN_R,
      '(walk=%r scan=%r)' % (WALK_GUARD_R, TP_SCAN_R))

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

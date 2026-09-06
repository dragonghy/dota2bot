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

# ---- `pulldrag`, the drag DESTINATION (replay-check 2026-08-25) -------------
# Three numbers this candidate's (a)-reading rests on, and the failure each
# pin prevents:
#   LANE_GAP  the camp-beside-lane gate `pulldrag` rides through.  The reader
#             uses it to decide whether a camp's ASSIGNED LANE is recoverable
#             (GetAssignedLane() is not in the dump); read it too wide and the
#             lane becomes ambiguous, too narrow and camps vanish from the
#             domain.
#   STEP      the 500 u drag step.  The whole "81-87% of the step is wasted"
#             arithmetic is per-step, so a changed step silently rescales it.
#   CADENCE   the 3.0 s poke period.  The direction window is one cadence plus
#             one 1 Hz sample; if the period grew, that window would start
#             measuring the NEXT poke's approach instead of this drag.
ROAM_LUA = os.path.join(ROOT, 'bots', 'mode_roam_generic.lua')
import pulldrag_walk as pdw                # noqa: E402

PULLDRAG_GAP = assignment('local PULL_CAMP_LANE_GAP')
PULLDRAG_STEP = literal('Think', r'dx / n \* (?P<n>\d+)', path=ROAM_LUA)
PULLDRAG_CADENCE = literal('Think', r'campPullAttackTime > (?P<n>[\d.]+)',
                           path=ROAM_LUA)
eq('pulldrag_walk.LANE_GAP', float(pdw.LANE_GAP), float(PULLDRAG_GAP))
eq('pulldrag_walk.STEP', float(pdw.STEP), float(PULLDRAG_STEP))
check('pulldrag_walk.CADENCE_HI covers one poke period',
      PULLDRAG_CADENCE < pdw.CADENCE_HI <= PULLDRAG_CADENCE + 1.5,
      '(cadence=%s, window=%s)' % (PULLDRAG_CADENCE, pdw.CADENCE_HI))
# The decoy: `pulldrag` is gated STANDALONE on purpose (a conjoined gate would
# freeze FALSE the day `pullcamp` is promoted -- the `pullcad` lesson).  If
# someone conjoins it, the reader above would be scoring a dead lever.
check('pulldrag gate is not conjoined with another candidate id',
      "IsSoakCandidate( 'pulldrag' ) and J.IsSoakCandidate"
      not in open(os.path.join(ROOT, 'bots', 'FunLib', 'jmz_func.lua')).read())


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
STAYREGEN_HP_LO = literal('J.ShouldStayAndRegen', NHP_LO_RE)
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
import stayattr_domain as sad                      # noqa: E402

eq('stayfield_domain.HP_LO mirrors J.IsFieldRegenSituation',
   float(sfd.HP_LO), SITUATION_HP_LO)
eq('stayfield_domain.HP_HI mirrors J.IsFieldRegenSituation',
   float(sfd.HP_HI), SITUATION_HP_HI)
eq('stayfield2_margin.SHIPPED_HP_HI mirrors J.ShouldStayAndRegen',
   float(s2m.SHIPPED_HP_HI), STAYREGEN_HP_HI)
# [director 2026-09-06] `stayattr_domain` measures the P2 chase read INSIDE
# J.ShouldStayAndRegen, so its band is that function's band -- both ends, not
# just the ceiling `stayfield2_margin` already pins.  Registered as MIRROR with
# the pin rather than the census row alone: the row says what the number is
# supposed to be, only the pin notices when the source moves.
eq('stayattr_domain.HP_LO mirrors J.ShouldStayAndRegen',
   float(sad.HP_LO), STAYREGEN_HP_LO)
eq('stayattr_domain.HP_HI mirrors J.ShouldStayAndRegen',
   float(sad.HP_HI), STAYREGEN_HP_HI)
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
    'stayattr_domain:HP_LO':             ('MIRROR', 'J.ShouldStayAndRegen jmz_func.lua:5083 -- the band the P2 chase read sits inside; pinned above'),
    'stayattr_domain:HP_HI':             ('MIRROR', 'J.ShouldStayAndRegen jmz_func.lua:5083 -- same band, ceiling shared with stayfield2_margin.SHIPPED_HP_HI; pinned above'),
    'hometp_highhp:HEAL_CORE_HP':        ('MIRROR', 'cores need HP < 0.75 (:1315)'),
    'itemtrip_contract:HP_FLOOR':        ('MIRROR', 'J.IsWastefulItemTrip; pinned above'),
    # [director 2026-08-29] Landed unregistered with the module (bb00ea75,
    # replay-check 05:30Z) and stayed invisible for the rest of the day: this
    # file died at IMPORT further down (the odaoe reader, ~500 lines below), so
    # every reader of the red saw one traceback and none saw this row's name.
    # Two findings, one banner -- record it, because "the suite is already red"
    # is how the second one gets a free pass.
    'wandlimbo_domain:HP_FRAC':          ('MIRROR', 'J.ShouldDrinkWandInLimbo jmz_func.lua:9348 -- `GetHealth() > GetMaxHealth() * 0.25` is the shipped test this reproduces'),
    'tpdefend_events:HEAT_HP':           ('MIRROR', 'J.ShouldTpSupportTowerFight heat gate; pinned above'),
    # [replay-check 2026-08-31] `idletrip_domain` scores no gate -- it measures
    # shipped-default behaviour -- so this cut MUST NOT be read as mirroring
    # any source predicate.  0.90 is the departure-hp cut the 2026-08-30T21:58Z
    # reading used to isolate the 127 walk-home trips, kept identical so the
    # detector's number and that report's number are comparable.  It is
    # deliberately far from every shipped regen threshold in this table
    # (0.55 / 0.75 / 0.34): a trip is only called pointless when the hero was
    # nowhere near needing to go home.
    'idletrip_domain:HP_FULL':           ('INDEPENDENT', 'departure-hp cut for "did not need to go home"; mirrors no source predicate, chosen to match the 2026-08-30T21:58Z hand reading'),
    # [director 2026-09-03] Three rows that landed unregistered with their
    # modules and turned trunk red on a clean tree.  Same shape as the
    # 2026-08-29 note above, so the fix is the same: classify, and PIN --
    # each of the three named a source clause in its own comment, which is a
    # mirror claim, and a mirror claim that is only prose is a comment.
    'illumove_pairs:HP_CUT':             ('MIRROR', 'illusions.lua X.ConfuseEnemyWithIllusions `J.GetHP(bot) < 0.4` -- the branch `illureal` opens; pinned below'),
    'wandbleed_trigger:HP_MAX':          ('MIRROR', "the 'wandbleed' branch ceiling `nHPrate < 0.45` in ability_item_usage_generic.lua item_magic_wand; pinned below"),
    'wandbleed_trigger:HP_MIN_EXCLUSIVE': ('MIRROR', "J.ShouldDrinkWandInLimbo's 25% floor -- the SAME shipped literal wandlimbo_domain:HP_FRAC mirrors; pinned below"),
    'detect:WASTE_HP_PCT':               ('INDEPENDENT', 'detector "low HP" for wasteful TP'),
    'detect:OVERCHASE_VICTIM_HP':        ('INDEPENDENT', 'enemy-side victim pick; 0.45 on purpose'),
    'detect:LIMBO_HP':                   ('INDEPENDENT', 'shares 0.40 with the proxy by coincidence'),
    'bbfloor_domain:CORPSE_HP_MAX':      ('INDEPENDENT', 'corpse-run band, paired with a position test; NOT a liveness proxy -- a live, still hero under it is a KNOWN false positive, asserted in that module\'s selfcheck'),
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

# `towerfear` (GH #171, replay-check 2026-08-25).  This reader is unusual in
# that its whole design -- four rectangles in (game-time, hero-level) -- IS the
# shipped clause's own algebra, so six separate literals have to keep mirroring
# `X.ShouldRun` or the "released rectangle" stops being the released rectangle
# and the three controls stop being controls.  The mid-lane override is the
# decoy here: `nEnemyTowers` is assigned TWICE in the same function, 898 and
# then 980 for LANE_MID, and the two assignments differ only by the word
# `local`.  Reading the wrong one moves the ring by 82 u on every frame.
RETREAT_LUA = os.path.join(ROOT, 'bots', 'mode_retreat_generic.lua')

import towerfear_domain as tf                      # noqa: E402

TF_RING = literal('X.ShouldRun',
                  r'local nEnemyTowers\s*=\s*bot:GetNearbyTowers\(\s*(?P<n>[\d.]+)',
                  path=RETREAT_LUA)
TF_RING_MID = literal('X.ShouldRun',
                      r'\n\s+nEnemyTowers\s+=\s*bot:GetNearbyTowers\(\s*(?P<n>[\d.]+)',
                      path=RETREAT_LUA)
TF_CTX_U = call_arg('X.ShouldRun', 'J.GetEnemyList', 1, path=RETREAT_LUA)
TF_CTX_HP = literal('X.ShouldRun', r'bot:GetHealth\(\) < (?P<n>[\d.]+)',
                    path=RETREAT_LUA)
TF_LEVEL_CAP = literal('X.ShouldRun',
                       r'botLevel <= (?P<n>\d+) and DotaTime\(\) > 0',
                       path=RETREAT_LUA)
TF_LEVEL_LEG = literal('X.ShouldRun',
                       r'botLevel <= (?P<n>\d+) or DotaTime\(\) < nFearClock',
                       path=RETREAT_LUA)
TF_CLOCK_MIN = literal('X.ShouldRun',
                       r'local nFearClock\s*=\s*(?P<n>[\d.]+)\s*\*\s*60',
                       path=RETREAT_LUA)
TF_HALVING = literal('X.ShouldRun',
                     r'nFearClock\s*=\s*nFearClock\s*/\s*(?P<n>[\d.]+)',
                     path=RETREAT_LUA)

eq('towerfear_domain.RING_U mirrors the default tower ring',
   float(tf.RING_U), TF_RING)
eq('towerfear_domain.RING_MID_U mirrors the LANE_MID override (the decoy)',
   float(tf.RING_MID_U), TF_RING_MID)
eq('towerfear_domain.CTX_U mirrors J.GetEnemyList', float(tf.CTX_U), TF_CTX_U)
eq('towerfear_domain.CTX_HP mirrors the hp leg of the gate context',
   float(tf.CTX_HP), TF_CTX_HP)
eq('towerfear_domain.LEVEL_CAP mirrors the level<=10 cap',
   float(tf.LEVEL_CAP), TF_LEVEL_CAP)
eq('towerfear_domain.LEVEL_LEG mirrors the level<=5 leg',
   float(tf.LEVEL_LEG), TF_LEVEL_LEG)
eq('towerfear_domain.SHIPPED_CLOCK mirrors nFearClock',
   float(tf.SHIPPED_CLOCK), TF_CLOCK_MIN * 60.0)
# The armed clock is not a literal anywhere -- it is the shipped one DIVIDED.
# Deriving it here means a change to either half goes red, which is the point:
# the rectangle boundary at 150 s is the armed value, not a chosen number.
eq('towerfear_domain.ARMED_CLOCK is the shipped clock over the shipped divisor',
   float(tf.ARMED_CLOCK), (TF_CLOCK_MIN * 60.0) / TF_HALVING)
check('the two rings really do differ (mid-lane override exists)',
      TF_RING < TF_RING_MID, '(default=%r mid=%r)' % (TF_RING, TF_RING_MID))
check('the armed predicate is a strict subset of the shipped one',
      tf.ARMED_CLOCK < tf.SHIPPED_CLOCK,
      '(armed=%r shipped=%r)' % (tf.ARMED_CLOCK, tf.SHIPPED_CLOCK))

# `towerfear`'s CALIBRATED clause (`mode_retreat_generic.lua:915-922`), the
# thing the source comment claims catches the frames the lever releases --
# read by `towerfear_catch.py` (replay-check 2026-08-25, queue.json:strategy-12
# acceptance item 4).  Two decoys sit inside a dozen lines of each other:
#
#   (1) THE LEVEL TRIPLET.  `botLevel <=` appears THREE times in one block --
#       10 (the block cap), 5 (the crude clause's level leg), 9 (the
#       calibrated clause).  Grab the wrong one and the catchable share moves
#       by every level-10 frame in the corpus, in the direction that flatters
#       the comment.
#   (2) THE 1600 PAIR.  `J.GetEnemyList(bot,1600)` and `J.GetAllyList(bot,1600)`
#       are adjacent lines with the SAME radius, so a reader that grabbed the
#       enemy one would be right by accident today and silently wrong the day
#       either moves.  They are pinned separately and then asserted distinct
#       calls, so the coincidence cannot hide a mix-up.
import towerfear_catch as tfc                      # noqa: E402

TF_CALIB_LEVEL = literal(
    'X.ShouldRun',
    r'botLevel <= (?P<n>\d+)\s*\n\s*and nEnemyTowers\[1\] ~= nil'
    r'\s*\n\s*and nEnemyTowers\[1\]:CanBeSeen',
    path=RETREAT_LUA)
TF_ALLY_CAP = literal(
    'X.ShouldRun',
    r'nEnemyTowers\[1\]:GetAttackTarget\(\) == bot'
    r'\s*\n\s*and #hAllyHeroList <= (?P<n>\d+)',
    path=RETREAT_LUA)
TF_ALLY_R = call_arg('X.ShouldRun', 'J.GetAllyList', 1, path=RETREAT_LUA)

eq('towerfear_catch.CALIB_LEVEL mirrors the calibrated clause level leg',
   float(tfc.CALIB_LEVEL), TF_CALIB_LEVEL)
eq('towerfear_catch.ALLY_CAP mirrors #hAllyHeroList <= N',
   float(tfc.ALLY_CAP), TF_ALLY_CAP)
eq('towerfear_catch.ALLY_R_U mirrors J.GetAllyList (not the enemy list)',
   float(tfc.ALLY_R_U), TF_ALLY_R)
check('the level triplet is really three different numbers (decoy 1)',
      TF_LEVEL_LEG < TF_CALIB_LEVEL < TF_LEVEL_CAP,
      '(leg=%r calib=%r cap=%r)' % (TF_LEVEL_LEG, TF_CALIB_LEVEL,
                                    TF_LEVEL_CAP))
check('ally list and enemy list are separate calls that happen to agree '
      '(decoy 2)',
      TF_ALLY_R == TF_CTX_U,
      '(ally=%r enemy=%r -- if these ever differ, re-read which one the '
      'calibrated clause counts)' % (TF_ALLY_R, TF_CTX_U))
# The tower attack range is NOT a repo literal -- it is the engine's, and it is
# what makes `GetAttackTarget() == bot` arithmetically impossible out at the
# ring edge.  Pinning the RELATION is what matters: the day someone widens the
# ring or narrows it past 700, the "hard-zero band" in the reading changes.
check('the calibrated clause has a hard-zero band inside the ring',
      tfc.TOWER_ATTACK_RANGE_U < TF_RING,
      '(range=%r ring=%r)' % (tfc.TOWER_ATTACK_RANGE_U, TF_RING))

# `midsupyield` event-axis reader (replay-check 2026-08-25, the AX.5 unlock
# bar).  Every one of these six numbers decides whether a TP press counts as a
# tower-defense ANSWER, i.e. whether the event population the director asked to
# be sized exists at all.  The decoy in this function is the RADIUS PAIR: 1200
# appears twice (enemies near the tower, allies near the tower) and 1600 twice
# more (the repeat-front memory, and `J.IsInTeamFight(hAlly, 1600)` in the
# sibling helper) -- reading either 1600 as the front radius would inflate the
# front area by 78% and silently widen every count in the census.
import tpdefend_events as tde                      # noqa: E402

# The responder floor was an inline `> 3500` when this mirror was written; it
# is now the file-level constant `J.TP_RESPONSE_FAR_FLOOR`, shared with
# `J.HasAvailableSupportResponder` so the pairing cannot drift apart.  Reading
# the assignment is the same claim about the same number -- but on its own it
# would be a WEAKER one, because a mirror that reads only the definition stays
# green if the function stops using it.  So the binding is pinned too.
TDE_FAR_NAME = 'J.TP_RESPONSE_FAR_FLOOR'
TDE_FAR = assignment(TDE_FAR_NAME)
TDE_FAR_BOUND = re.search(
    r'GetUnitToUnitDistance\(\s*bot,\s*building\s*\)\s*>\s*'
    + re.escape(TDE_FAR_NAME),
    function_body('J.ShouldTpSupportTowerFight')) is not None
TDE_FRONT_E = call_arg('J.ShouldTpSupportTowerFight', 'J.GetEnemiesNearLoc', 1)
TDE_FRONT_A = call_arg('J.ShouldTpSupportTowerFight', 'J.GetAlliesNearLoc', 1)
TDE_HEAT_HP = literal('J.ShouldTpSupportTowerFight',
                      r'J\.GetHP\(\s*ally\s*\)\s*<\s*(?P<n>[\d.]+)')
TDE_HEAT_S = call_arg('J.ShouldTpSupportTowerFight',
                      'ally:WasRecentlyDamagedByAnyHero', 0)
TDE_REPEAT_S = literal('J.ShouldTpSupportTowerFight',
                       r'DotaTime\(\) - bot\.lastFrontAnswerT < (?P<n>[\d.]+)')
TDE_REPEAT_U = literal('J.ShouldTpSupportTowerFight',
                       r'bot\.lastFrontAnswerY or 0[^<]*<\s*(?P<n>[\d.]+)')
TDE_LEVEL = literal('J.ShouldTpSupportTowerFight',
                    r'bot:GetLevel\(\) < (?P<n>\d+)')
TDE_RESPAWN = literal('J.ShouldTpSupportTowerFight',
                      r'bot\.lastRespawnTime or -999 \)\s*<\s*(?P<n>[\d.]+)')
TDE_CORE = literal('J.IsCore', r'J\.GetPosition\(bot\) <= (?P<n>\d+)')
TDE_SUP = literal('J.HasAvailableSupportResponder',
                  r'J\.GetPosition\(\s*hAlly\s*\)\s*>=\s*(?P<n>\d+)')

eq('tpdefend_events.FAR_U mirrors the responder far floor',
   float(tde.FAR_U), TDE_FAR)
check('the far floor constant is the one the responder clause actually reads',
      TDE_FAR_BOUND,
      '(%s not found in the GetUnitToUnitDistance(bot, building) clause)'
      % TDE_FAR_NAME)
eq('tpdefend_events.FRONT_R_U mirrors GetEnemiesNearLoc(vTower, .)',
   float(tde.FRONT_R_U), TDE_FRONT_E)
check('the two front radii really are the same number in the rule',
      TDE_FRONT_E == TDE_FRONT_A,
      '(enemies=%r allies=%r)' % (TDE_FRONT_E, TDE_FRONT_A))
eq('tpdefend_events.HEAT_HP mirrors the heat gate hp leg',
   float(tde.HEAT_HP), TDE_HEAT_HP)
eq('tpdefend_events.HEAT_S mirrors WasRecentlyDamagedByAnyHero',
   float(tde.HEAT_S), TDE_HEAT_S)
eq('tpdefend_events.REPEAT_S mirrors the repeat-front window',
   float(tde.REPEAT_S), TDE_REPEAT_S)
eq('tpdefend_events.REPEAT_U mirrors the repeat-front radius',
   float(tde.REPEAT_U), TDE_REPEAT_U)
eq('tpdefend_events.MIN_LEVEL mirrors the level-6 floor',
   float(tde.MIN_LEVEL), TDE_LEVEL)
eq('tpdefend_events.RESPAWN_S mirrors the fresh-respawn cooldown',
   float(tde.RESPAWN_S), TDE_RESPAWN)
# The core band is not a literal in this reader either -- it is J.IsCore's
# boundary, and `midsupyield` yields FROM that band TO the support band.  The
# two must tile the 1..5 axis with no gap and no overlap, or "core share" and
# "support share" stop summing to the population.
eq('tpdefend_events.CORE_MAX_POS is J.IsCore\'s boundary',
   float(tde.CORE_MAX_POS), TDE_CORE)
check('core and support bands tile positions 1-5 exactly',
      TDE_SUP == TDE_CORE + 1, '(core<=%r sup>=%r)' % (TDE_CORE, TDE_SUP))
check('the front radius is NOT the repeat-front radius (the 1200/1600 decoy)',
      TDE_FRONT_E != TDE_REPEAT_U,
      '(front=%r repeat=%r)' % (TDE_FRONT_E, TDE_REPEAT_U))

# ---- `campfarm`, the 10..11 BAND (replay-check 2026-08-26) ------------------
# campfarm_target.py's whole domain argument is "three shipped sites bound this
# decision and two of them say 10, the ladder says 12, so the band is 10..11".
# Each of those three numbers is a separate site that can move on its own, and
# if any of them does, the band is the wrong band and the (a)-verdict is read
# on the wrong population.  campgrade_ladder.py keeps a TRANSCRIPTION of the
# ladder constant; campfarm_target.py DERIVES it -- so the pair also pins the
# transcription, which is the copy that rots.
import campfarm_target as cft                      # noqa: E402
import campgrade_ladder as cgl                     # noqa: E402

ABA_SITE_PATH = os.path.join(ROOT, 'bots', 'FunLib', 'aba_site.lua')
FARM_MODE_PATH = os.path.join(ROOT, 'bots', 'mode_farm_generic.lua')
UTILS_PATH = os.path.join(ROOT, 'bots', 'FunLib', 'utils.lua')

eq('campfarm_target.ANCIENT_MIN_LEVEL ~ aba_site export',
   cft.ANCIENT_MIN_LEVEL,
   assignment('____exports.ANCIENT_MIN_LEVEL', ABA_SITE_PATH))
eq('campgrade_ladder transcription has not drifted from the export',
   cgl.ANCIENT_MIN_LEVEL, cft.ANCIENT_MIN_LEVEL)

FARM_SRC = open(FARM_MODE_PATH, encoding='utf-8').read()
UTILS_SRC = open(UTILS_PATH, encoding='utf-8').read()
check('mode_farm ancient clause still spells the lower edge >= 10',
      'bot:GetLevel() >= 10' in FARM_SRC)
check('utils.IsValidCreep still spells the same edge > 9',
      'GetLevel() > 9' in UTILS_SRC)
eq('campfarm_target reads that edge as 10', cft.SHIPPED_ANCIENT_MIN, 10)
check('the band is exactly the two levels between the two edges',
      [lv for lv in range(1, 26) if cft.band_of(lv) == 'band'] == [10, 11],
      str([lv for lv in range(1, 26) if cft.band_of(lv) == 'band']))

RADII, WRAPPED = cft.sweep_sites(FARM_MODE_PATH)
check('the farm mode still sweeps neutrals at 900 and 1000',
      RADII == [900.0, 1000.0], str(RADII))
check('all three sweeps still go through the ONE gated wrapper',
      WRAPPED == 3, '%d NeutralFarmList(bot, ...) sites' % WRAPPED)

# The `pullcad` lesson (charter 2026-08-23): a gate written as a conjunction of
# two candidate ids freezes FALSE the day either is promoted, and nothing goes
# red.  `campfarm`'s gate must stay a single candidate conjoined with turbo.
CF_GATE = [l for l in FARM_SRC.splitlines() if "IsSoakCandidate('campfarm')" in l]
check('campfarm has exactly one gate site', len(CF_GATE) == 1, str(CF_GATE))
check('campfarm\'s gate names no other candidate id',
      CF_GATE and CF_GATE[0].count('IsSoakCandidate') == 1
      and 'IsModeTurbo' in CF_GATE[0], CF_GATE[0] if CF_GATE else '')

# --- campswitch_domain (GH #201): the camp-switch conjunct ------------------
# The detector reasons about ONE line of mode_farm_generic.  Three ways that
# line can move out from under it, each with its own assertion: the margin, the
# 1 Hz throttle the whole "no aliasing cost" argument rests on, and the guard
# the 48ff29fe repair put where the nil call used to be.  A transcription is
# never allowed to stand in for any of them.
import campswitch_domain as csd                    # noqa: E402

MARGIN, THROTTLE = csd.switch_constants(FARM_MODE_PATH)
check('camp-switch margin still reads 200 u out of the farm mode',
      MARGIN == 200.0, str(MARGIN))
check('the repick throttle is still 1.0 s (== the corpus sample rate, which '
      'is why the offline count does not alias)', THROTTLE == 1.0,
      str(THROTTLE))
CS_GATE = [l for l in FARM_SRC.splitlines()
           if 'J.IsCampSwitchSafe(' in l and not l.strip().startswith('--')]
check('the switch is guarded by IsCampSwitchSafe at exactly one site',
      len(CS_GATE) == 1, str(CS_GATE))
check('the nil field the repair removed has not come back',
      'J.Site.IsCampDangerous' not in FARM_SRC)
# The `pullcad` lesson again: campdanger's own gate must not name a second id.
CD_GATE = [l for l in open(os.path.join(ROOT, "bots", "FunLib", "jmz_func.lua"),
                           encoding='utf-8').read().splitlines()
           if "IsSoakCandidate('campdanger')" in l
           and not l.strip().startswith('--')]
check('campdanger has exactly one gate site naming exactly one candidate',
      len(CD_GATE) == 1 and CD_GATE[0].count('IsSoakCandidate') == 1,
      str(CD_GATE))

import zusstatic_domain as zsd                     # noqa: E402

# replay-check 2026-08-26, GH #207.  The whole reading turns on the two legs
# disagreeing by 0.09 - 0, so the tool reads BOTH ends out of the Lua rather
# than retyping either.  If the gate-off constant or the KV key ever moves,
# the three-world argument in the tool's docstring is stale and must go red.
check('zusstatic gate-off constant is still the hardcoded 0.09',
      zsd.shipped_baseline_bonus() == 0.09, str(zsd.shipped_baseline_bonus()))
check('the armed branch still reads damage_health_pct off its parameter',
      zsd.armed_reads_key() == 'damage_health_pct', zsd.armed_reads_key())
ZUUS_SRC = open(os.path.join(ROOT, 'bots', 'BotLib', 'hero_zuus.lua'),
                encoding='utf-8').read()
# The `pullcad` lesson: zusstatic's gate must not name a second id.  The
# dependency on `zusbind` is registered in state.json and GH #207 for the
# director's ARMING decision -- coding it as a conjunction would freeze the
# gate FALSE the day zusbind is promoted.
ZS_GATE = [l for l in ZUUS_SRC.splitlines()
           if "IsSoakCandidate( 'zusstatic' )" in l
           and not l.strip().startswith('--')]
check('zusstatic has exactly one gate site naming exactly one candidate',
      len(ZS_GATE) == 1 and ZS_GATE[0].count('IsSoakCandidate') == 1,
      str(ZS_GATE))
# The witness the corpus reading leans on: X.ConsiderR must still be
# dispatched BELOW the assignment that can raise, or "Zeus ulted" stops being
# proof that the handle resolved.
check('the ConsiderR dispatch still sits below the GetStaticFieldBonus call',
      ZUUS_SRC.index('castRDesire = X.ConsiderR()')
      > ZUUS_SRC.index('abilityASBonus = X.GetStaticFieldBonus('))

import tbearly_domain as tbd                       # noqa: E402

# replay-check 2026-08-26.  `tbearly`'s reading is an ARITHMETIC one: the
# armed bound (18*60) equals the turbo cutoff of J.IsLateGame(), which is a
# conjunct of the block the clause sits inside, so the two legs can differ on
# nothing but the single instant t == 1080.0.  Every number in that sentence
# lives in a different file from the tool, so all four are ratcheted here: if
# ANY of them moves, the STRUCTURAL-ZERO verdict is stale and must go red
# rather than quietly keep being quoted out of an old report.
TB = tbd.read_source()
check('J.IsLateGame turbo cutoff is still 18*60', TB['late_turbo'] == 1080,
      str(TB['late_turbo']))
check('J.IsLateGame normal cutoff is still 30*60', TB['late_normal'] == 1800,
      str(TB['late_normal']))
check('tbearly shipped nEarlyClock is still 25*60', TB['shipped_clock'] == 1500,
      str(TB['shipped_clock']))
check('tbearly armed nEarlyClock is still 18*60', TB['armed_clock'] == 1080,
      str(TB['armed_clock']))
# The load-bearing structural fact, asserted with the block matcher rather
# than with a line range: reformatting mode_farm_generic.lua must not be able
# to silently invalidate it, and neither must MOVING the clause out.
check('the tbearly clause is still lexically inside the '
      '`not J.IsLateGame()` block', TB['enclosed_by_not_late'])
check('tbearly verdict computed from the shipped tree is STRUCTURAL-ZERO',
      tbd.verdict(TB)[0] == 'STRUCTURAL-ZERO', tbd.verdict(TB)[1])
# The `pullcad` lesson again: a gate written as a conjunction of two soak ids
# freezes FALSE the day either is promoted.  read_source() raises on that, so
# reaching this line at all is the assertion; keep it explicit anyway.
TB_GATE = [l for l in open(os.path.join(ROOT, 'bots', 'mode_farm_generic.lua'),
                           encoding='utf-8').read().splitlines()
           if "IsSoakCandidate('tbearly')" in l and not l.strip().startswith('--')]
check('tbearly has exactly one gate site naming exactly one candidate',
      len(TB_GATE) == 1 and TB_GATE[0].count('IsSoakCandidate') == 1,
      str(TB_GATE))

# --------------------------------------------------------------------------
# tpdeathbuy (replay-check 2026-08-26).  The whole reading of this id rests on
# an ARITHMETIC fact about the shipped clause and on two rival TP-purchase
# sites staying where they are.  Ratchet all three, so the conclusion cannot
# expire unnoticed the way a number quoted in an old report can.
# --------------------------------------------------------------------------
import tpdeathbuy_domain as tdb                     # noqa: E402

TD = tdb.read_source()
check('tpdeathbuy shipped clause is still `botHP < 0.08 and botHP >= 1`',
      TD['shipped_hi'] == 0.08 and TD['shipped_lo'] == 1.0, str(TD))
check('tpdeathbuy armed clause is still `botHP < 0.08`', TD['armed_hi'] == 0.08,
      str(TD))
check('tpdeathbuy verdict on the shipped tree is WIDENING',
      tdb.verdict(TD)[0] == 'WIDENING', tdb.verdict(TD)[1])
# The attribution window in the report is `DotaTime <= 240`, and it is only a
# window because the ORDINARY spare-TP buy is gated on `currentTime > 4*60`.
# If that clock moves, every "uniquely attributable" row stops being unique.
check('the ordinary spare-TP buy is still gated on 4*60', TD['normal_clock'] == 240,
      str(TD['normal_clock']))
check('WasRecentlyDamagedByAnyHero window is still 3.1', TD['dmg_window'] == 3.1,
      str(TD['dmg_window']))
# The other rival site: mode_roam_generic buys a TP inside the fountain radius.
check('the roam TP-buy fountain radius is still 150', TD['roam_radius'] == 150.0,
      str(TD['roam_radius']))
check('bots/ still has exactly 4 item_tpscroll purchase sites (a new one '
      'would break the attribution window)', TD['tp_buy_sites'] == 4,
      str(TD['tp_buy_sites']))
# The pullcad lesson, third time: a gate written as a conjunction of two soak
# ids freezes FALSE the day either is promoted.  read_source() raises on that;
# assert it explicitly too.
TD_GATE = [l for l in open(os.path.join(ROOT, 'bots', 'item_purchase_generic.lua'),
                           encoding='utf-8').read().splitlines()
           if "IsSoakCandidate('tpdeathbuy')" in l and not l.strip().startswith('--')]
check('tpdeathbuy has exactly one gate site naming exactly one candidate',
      len(TD_GATE) == 1 and TD_GATE[0].count('IsSoakCandidate') == 1,
      str(TD_GATE))
# The instrument fault the same round found: PURCHASE `value` is a PER-REPLAY
# name-table index.  The dumper now resolves it; assert the resolution is
# still there and still scoped to PURCHASE, because a revert would send every
# cross-game purchase read back to aggregating noise -- silently.
DUMPER = open(os.path.join(BEHAV, 'dumper', 'main.go'), encoding='utf-8').read()
check('dumper still resolves the PURCHASE name index into value_name',
      'ValueName' in DUMPER and 'DOTA_COMBATLOG_PURCHASE' in DUMPER)
check('dumper resolves it for PURCHASE ONLY (a magnitude must never be run '
      'through the name table)',
      DUMPER.count('valueName = name(') == 1 and
      'if m.GetType() == dota.DOTA_COMBATLOG_TYPES_DOTA_COMBATLOG_PURCHASE {' in DUMPER)

# --------------------------------------------------------------------------
# tpgap (GH #159) -- replay-check 2026-08-26T19:xxZ.  The whole attribution of
# `tpgap_domain.py` rests on three source facts.  If any of them changes and
# nobody notices, that round's reading silently becomes a reading about
# something else.
# --------------------------------------------------------------------------
sys.path.insert(0, BEHAV)
import tpgap_domain as TG                              # noqa: E402

TG_SRC = TG.read_source()
check('tpgap still scans tpsafe\'s 350 inside tpsafe2\'s 700',
      (TG_SRC['onface_radius'], TG_SRC['band_radius']) == (350.0, 700.0),
      str(TG_SRC))
check('tpgap prices the CHANNEL (3 s), not the shared helper\'s 5 s -- the '
      'juggernaut counter-example frame is the reason',
      TG_SRC['channel_seconds'] == 3.0, str(TG_SRC['channel_seconds']))
check('tpgap gates on exactly one candidate id (a conjunction would freeze '
      'FALSE the day the other id is promoted)',
      TG_SRC['gate_id'] == 'tpgap')
# `dest in {home, died}` is how the corpus tells a RETREAT press from a travel
# press.  It is only valid while every retreat-branch TP goes to the fountain.
check('every retreat-branch TP still teleports to the own fountain, so `dest` '
      'still separates retreat presses from travel presses',
      TG.assert_retreat_dest_is_fountain() >= 3)
# And `tpreach` must stay out of the retreat branch, or the leg difference in
# the gap band stops being attributable to tpgap at all.
check('tpsafe2 (which tpreach widens) is still scoped out of retreat mode',
      TG.assert_retreat_only_guard() is True)

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

# --------------------------------------------------------------------------
# abilanc (GH #196, director ruling §BL) -- replay-check 2026-08-26T21:xxZ.
# The (a) reading is an EXISTENCE argument on a domain the ruling had to
# correct once already ("level < 12 entire, not the 10..11 band").  Each fact
# below is a premise of that argument; if one moves silently, the reading
# stops being about `abilanc`.
# --------------------------------------------------------------------------
import abilanc_domain as AD                            # noqa: E402

AD_GATE = AD.gate_facts()
check('abilanc still gates on exactly one soak id, turbo-first',
      AD_GATE['min_level'] == 12)
check('abilanc\'s level test is still a strict upper bound',
      AD_GATE['op'] == '<', str(AD_GATE['op']))
check('abilanc still has NO lower level bound -- this IS director ruling '
      '§BL.3: the domain is `under` + `band`, never the 10..11 band alone',
      AD_GATE['has_lower_bound'] is False)

AD_GUARDED, AD_OPTOUT = AD.selector_sites()
check('the tier-blind selector still has exactly ONE caller outside '
      'jmz_func (doom\'s devour) -- a second one would be an unaccounted '
      'uncovered path in every residual adjudication',
      len(AD_OPTOUT) == 1 and 'doom_bringer' in list(AD_OPTOUT)[0],
      str(sorted(AD_OPTOUT)))
check('the guarded selector still feeds a double-digit set of hero files',
      len(AD_GUARDED) >= 10, str(len(AD_GUARDED)))
# Load-bearing for every residual verdict: a hero with no site in his own file
# is read as "this cast cannot have come through the selector".  That holds
# only while the shared, runs-for-everyone file's sites are ITEM considers,
# whose casts appear in the combat log as ITEM rather than ABILITY.
AD_GEN = AD.generic_sites_are_items()
check('the shared ability file\'s selector sites are still ALL item considers '
      '-- an ABILITY consider there would break "no site in his file means '
      'not reachable" for every residual',
      bool(AD_GEN) and all(o == 'ItemDesire' for o in AD_GEN),
      str(AD_GEN))

# The rendering ratchet.  `campfarm_target.py`'s `cast AT camp` table looped
# ('band','over') while the ruling that made `under` a domain called the read
# zero-cost "because the file already loops three bands" -- true of a
# different table in the same file.  A band that is never printed reads
# exactly like a band that is empty.
CFT = open(os.path.join(BEHAV, 'campfarm_target.py'), encoding='utf-8').read()
check('campfarm_target still prints ALL THREE bands in the `cast AT camp` '
      'table (a dropped band is indistinguishable from an empty one)',
      CFT.count("for band in ('under', 'band', 'over'):") == 2,
      str(CFT.count("for band in ('under', 'band', 'over'):")))

# --------------------------------------------------------------------------
# campsel (GH #137) -- replay-check 2026-08-27T0x:xxZ.
# The whole (a) argument is "restoring two OPERANDS changes two predicates",
# so every premise below is load-bearing: the multiplier that makes the
# argmin move, the cut-off it scales, the level the ancient clause names, and
# above all the fact that the predicates are called on `rec` and not on the
# wrapper again -- the last one would turn the armed leg back into the
# shipped leg with nothing red anywhere.
# --------------------------------------------------------------------------
import campsel_domain as CS                            # noqa: E402

CS_GATE = CS.gate_facts()
eq('campsel is gated by exactly one soak id', CS_GATE['cands'], ['campsel'])
# The #207 hazard is `A and B` inside ONE argument: promote B and the whole
# gate freezes FALSE while `check_armed_wiring.py` still calls it WIRED.  A
# second argument is a second gate, not a conjunction -- so the check is aimed
# per argument, and the siblings are ratcheted by name instead.  `slotarb`
# (GH #406, 2026-09-01) is the first of those and turned this file red for a
# tree where nothing was conjoined with anything.
eq('no gate argument of ClosestCamp conjoins two candidate ids',
   CS_GATE['conjoined'], [])
eq('the wrapper\'s independent siblings are exactly the acknowledged ones',
   CS_GATE['sibling_cands'], ['slotarb'])
# ...and the split must still be able to SEE a conjunction, which the live tree
# no longer contains.  Three synthetic wrappers, run every time: without them
# `conjoined == []` is satisfied by a scan that cannot produce a non-empty
# answer, and an aimed check and a disabled one read identically.
_SYNTH = ('local function ClosestCamp(hBot, tCamps)\n'
          '\treturn J.Site.GetClosestNeutralSpwan(hBot, tCamps,\n\t\t%s)\n'
          'end\n')
_conj = CS.gate_facts(farm_src=_SYNTH % (
    "J.IsModeTurbo() and J.IsSoakCandidate('campsel') "
    "and J.IsSoakCandidate('other')"))
eq('a conjoined gate (the #207 shape) is still detected',
   _conj['conjoined'], [('campsel', 'other')])
_two = CS.gate_facts(farm_src=_SYNTH % (
    "J.IsModeTurbo() and J.IsSoakCandidate('campsel'),\n"
    "\t\tJ.IsModeTurbo() and J.IsSoakCandidate('other')"))
eq('two arguments are two gates, not a conjunction', _two['conjoined'], [])
eq('...and the second one is reported as a sibling, by name',
   _two['sibling_cands'], ['other'])
_nested = CS.gate_facts(farm_src=_SYNTH % (
    "J.Between(a, b) and J.IsSoakCandidate('campsel')"))
eq('a comma nested inside an argument does not split it',
   _nested['cands'], ['campsel'])
check('campsel is still resolved at exactly ONE call site -- a second one '
      'would be a path this detector has never looked at',
      CS_GATE['call_sites'] == 1, str(CS_GATE['call_sites']))
eq('the enemy-camp penalty is still 1.5', CS_GATE['penalty'], 1.5)
eq('the selector cut-off is still 15000', CS_GATE['cutoff'], 15000.0)
eq('the selector\'s ancient clause still names level 10',
   CS_GATE['ancient_level'], 10)
check('the operand swap (`rec = camp.cattr` under the gate) is still there',
      CS_GATE['selection'] is True)
check('BOTH predicates are still called on `rec` -- putting either back on '
      'the wrapper silently restores the shipped behaviour on the ARMED leg',
      CS_GATE['preds_on_rec'] == 2 and CS_GATE['preds_on_camp'] == 0,
      'rec=%d camp=%d' % (CS_GATE['preds_on_rec'], CS_GATE['preds_on_camp']))

# The premise ratchet.  `campsel` (and `pullcamp`, and templar assassin's ult)
# all assume the ENGINE hands back `.team` as a team id and `.type` as the
# STRING "ancient".  Nothing in the tree verifies that -- the fix's own
# fixtures supply a camp table the fixer wrote.
#
# GH #241 filed this as a two-sided contradiction: those shipped sites against
# docs/BOT_API_REFERENCE.md, which typed both fields `int`.  2026-08-27
# (strategy) retired the second side.  That row never observed this API --
# Valve publishes no field list for GetNeutralSpawners and the engine dump
# gives `variant`; the same six rows appear verbatim in an unrelated
# third-party repo under the same filename; and the row contradicted itself,
# every numeric annotation in it sitting next to a string-valued description.
#
# So the ratchet moved rather than relaxed.  The shipped-site counts are
# unchanged; what used to pin "the doc still disagrees" now pins the three
# facts that retired it, so the refuter cannot come back unannounced.
CS_PRE = CS.premise_sites()
check('>= 3 shipped sites still compare camp.team to GetTeam()',
      len(CS_PRE['team_readers']) >= 3, str(CS_PRE['team_readers']))
check('>= 1 shipped site still compares camp.type to the STRING "ancient"',
      any(lit == 'ancient' for _f, _l, lit in CS_PRE['type_readers']),
      str(CS_PRE['type_readers']))
check('the API reference still names GetNeutralSpawners().team/.type -- if '
      'this section stops parsing, the audit above is reading nothing',
      set(CS_PRE['doc_fields']) >= {'team', 'type'},
      str(CS_PRE['doc_fields']))
check('the API reference no longer types .team/.type as int -- putting the '
      'int back re-arms a refuter that was never a source (GH #241)',
      CS_PRE['doc_fields'].get('team') != 'int'
      and CS_PRE['doc_fields'].get('type') != 'int',
      str(CS_PRE['doc_fields']))
# Both #241 pointers are pinned by an EXACTLY-ONCE substring, not by `'#241'
# in section`: the token occurs twice, so a membership test survives deleting
# either one of them (measured -- that mutant SURVIVED the first batch).  Same
# shape as the 0SALT uniqueness lesson, read from the other end: a needle that
# is not unique is not a pin.
for _needle in ('See GH #241.',                  # the pointer on the entry
                'settled types (GH #241)'):      # the blockquote's own claim
    check('the API reference still carries %r exactly once -- retiring the '
          'refuter did NOT settle the question' % _needle,
          CS_PRE['doc_section'].count(_needle) == 1,
          str(CS_PRE['doc_section'].count(_needle)))
check('the API reference says out loud that these rows are UNVERIFIED',
      CS_PRE['doc_section'].count('UNVERIFIED') == 1,
      str(CS_PRE['doc_section'].count('UNVERIFIED')))
check('shipped code compares camp.speed to the STRINGS "fast"/"slow" -- the '
      'retired row typed it `float`, which is what made it self-refuting',
      sorted(CS_PRE['speed_readers']) == ['fast', 'slow'],
      str(CS_PRE['speed_readers']))
check('shipped code reads a camp.idx the retired row never listed at all -- '
      'the row was incomplete as well as mistyped',
      CS_PRE['idx_readers'] >= 4, str(CS_PRE['idx_readers']))

# --------------------------------------------------------------------------
# odaoe (GH #54) -- the ARMED-ONLY reading in odaoe_domain.py is only valid
# while the gated area branch sits strictly BELOW the shipped single-target
# exit.  Hoist it and armed starts REDIRECTING casts instead of only adding
# them, at which point every "armed_only" count in the 2026-08-27 report means
# something else.  That is a source fact, so it gets a source ratchet.
import odaoe_domain as OA                              # noqa: E402

# --------------------------------------------------------------------------
# wandlimbo (registered in HP_CENSUS above as MIRROR) -- and a MIRROR that is
# only a prose note is a comment, not a mirror.  Pin the number against the
# shipped test it reproduces so a change to either side turns this red.
import wandlimbo_domain as WL                           # noqa: E402

WL_SHIPPED_HP = literal(
    'J.ShouldDrinkWandInLimbo',
    r'GetHealth\(\)\s*>\s*bot:GetMaxHealth\(\)\s*\*\s*(?P<n>[0-9.]+)')
eq('wandlimbo HP_FRAC mirrors the shipped 25% floor', WL.HP_FRAC, WL_SHIPPED_HP)
eq('wandlimbo MIN_DRAUGHT mirrors charges * 15', WL.MIN_DRAUGHT, 90)

# --------------------------------------------------------------------------
# [director 2026-09-03] The three constants registered MIRROR above.  Same
# reason as the wandlimbo block: the row is the claim, this is the check.
import illumove_pairs as IMP                            # noqa: E402
import wandbleed_trigger as WBT                         # noqa: E402

ILLUSIONS_LUA = os.path.join(ROOT, 'bots', 'FunLib', 'minion_lib',
                             'illusions.lua')
ILLU_CONFUSE_HP = literal(
    'X.ConfuseEnemyWithIllusions',
    r'J\.GetHP\(\s*bot\s*\)\s*<\s*(?P<n>[\d.]+)',
    path=ILLUSIONS_LUA)
eq('illumove_pairs.HP_CUT mirrors the confuse-branch owner-hp clause',
   float(IMP.HP_CUT), ILLU_CONFUSE_HP)

# `X.ConsiderItemDesire["item_magic_wand"] = function( hItem )` is an
# ASSIGNMENT, not a `^function`, so function_body() cannot reach it -- anchor
# on the gate id over the comment-stripped file (the TD_GATE idiom above).
# Anchoring on the ID rather than on position is the point: `nHPrate <`
# appears in several branches of this one function and "the first match" is
# exactly the reading `where=` exists to prevent.
AIUG_SRC = '\n'.join(
    l for l in open(os.path.join(ROOT, 'bots',
                                 'ability_item_usage_generic.lua'),
                    encoding='utf-8').read().splitlines()
    if not l.strip().startswith('--'))
check("'wandbleed' has exactly one gate site in ability_item_usage_generic.lua",
      AIUG_SRC.count("IsSoakCandidate('wandbleed')") == 1,
      str(AIUG_SRC.count("IsSoakCandidate('wandbleed')")))
WB_CEILING = re.search(
    r"IsSoakCandidate\('wandbleed'\)[\s\S]{0,400}?nHPrate\s*<\s*([\d.]+)",
    AIUG_SRC)
check("the 'wandbleed' branch still carries an nHPrate ceiling",
      WB_CEILING is not None,
      '-- the gate moved or the clause left the branch, so '
      'wandbleed_trigger.HP_MAX now bounds a domain that does not exist')
if WB_CEILING:
    eq('wandbleed_trigger.HP_MAX mirrors that ceiling',
       float(WBT.HP_MAX), float(WB_CEILING.group(1)))

# NOT equality by coincidence, unlike detect.LIMBO_HP two rows down in the
# census: this script's `shared_with_wandlimbo` bucket IS the wandlimbo
# domain, so the two numbers are the same one by construction.  If the shipped
# floor moves and this does not, casts get filed under the wrong explanation
# and the "exclusive" count stops being exclusive.
eq('wandbleed_trigger.HP_MIN_EXCLUSIVE mirrors the wandlimbo 25% floor',
   float(WBT.HP_MIN_EXCLUSIVE), WL_SHIPPED_HP)
check('the exclusive band is non-empty (min < max)',
      WBT.HP_MIN_EXCLUSIVE < WBT.HP_MAX,
      '(min=%r max=%r -- an inverted band files every cast as shared)'
      % (WBT.HP_MIN_EXCLUSIVE, WBT.HP_MAX))

OA_SRC = OA.read_source_constants()
eq('odaoe is gated by exactly one soak id', OA_SRC['gate_ids'], ['odaoe'])

# [director 2026-08-29] Both directions of that read, because the check used to
# have the wrong domain and nothing said so.  It scanned the WHOLE OD file for
# a second `IsSoakCandidate`, so the day the hero stream landed 'odbuild' (GH
# #287 §2) -- an independent gate ~560 lines away, sharing no expression with
# odaoe -- this module raised at import and trunk read RED ON MAIN for hours
# over a correct change.  The hazard (GH #207) is a second id CONJOINED INTO
# THE SAME PREDICATE; a hero file carrying two independent candidates is normal
# and must stay green.  Pin the distinction so the domain cannot widen back.
_OD_TEXT = open(os.path.join(ROOT, 'bots', 'BotLib',
                             'hero_obsidian_destroyer.lua'),
                encoding='utf-8').read()
check('an INDEPENDENT second candidate elsewhere in the OD file is not the '
      "#207 shape -- 'odbuild' ships beside 'odaoe' today and must read green",
      "IsSoakCandidate( 'odbuild' )" in _OD_TEXT
      and OA.read_source_constants(text=_OD_TEXT)['gate_ids'] == ['odaoe'])


def _odaoe_conjoined_raises():
    poisoned = _OD_TEXT.replace(
        "J.IsSoakCandidate('odaoe')",
        "J.IsSoakCandidate('odaoe') and J.IsSoakCandidate('odbuild')", 1)
    if poisoned == _OD_TEXT:
        return 'the odaoe guard text moved -- this case poisoned nothing'
    try:
        OA.read_source_constants(text=poisoned)
    except RuntimeError:
        return None
    return 'a second id conjoined into the odaoe guard did NOT raise'


_odaoe_conj = _odaoe_conjoined_raises()
check('a second id CONJOINED into the odaoe guard still raises (GH #207) -- '
      'narrowing the domain must not blind the check it was written for',
      _odaoe_conj is None, _odaoe_conj or '')
check('od_GetEclipseAoeLocation still has exactly ONE call site',
      OA_SRC['call_sites'] == 1, str(OA_SRC['call_sites']))
eq('the area branch still needs 2 targets', OA_SRC['min_targets'], 2)
eq('the worth-hitting threshold is still 25% of current HP',
   OA_SRC['min_damage_pct'], 0.25)
check('the gated area branch is STILL below the shipped single-target exit -- '
      'if it moves above, armed can redirect casts and the ARMED-ONLY bucket '
      'in iterations/reports/replay-check/20260827T0730Z.md stops meaning '
      '"the shipped loop had no exit here"',
      OA_SRC['gated_below_shipped'] is True)

# ---------------------------------------------------------------- bbshort / bbfight
# The two turbo-scaled buyback floors (GH #222 / #215).  Three source facts
# carry the whole 2026-08-27 reading, and each fails a DIFFERENT way:
#
#  * one soak id per gate -- two ids in one gate is the #207 freeze shape, and
#    `check_armed_wiring.py` would still call it WIRED;
#  * one call site each -- a second site means the floor is being asked
#    somewhere this tool never looked;
#  * the short floor's `return` must stay ABOVE the fight rung.  This is the
#    load-bearing one.  W16 armed BOTH ids on the same leg, so `bbfight`'s
#    reachability was measured under an armed `bbshort`.  That co-arming is
#    harmless ONLY because every one of the 434 fight-rung deaths measured
#    R >= 70.9s, clearing either floor -- an argument that assumes the two gates
#    are still in this order.  Flip them and the co-armed reading changes
#    meaning with nothing raising a hand.
import bbfloor_domain as BB                             # noqa: E402

BB_SRC = BB.load_source()
eq('bbfight is gated by exactly one soak id', BB_SRC.fight_ids, ['bbfight'])
eq('bbshort is gated by exactly one soak id', BB_SRC.short_ids, ['bbshort'])
eq('the turbo respawn factor is still 0.75', BB_SRC.turbo_factor, 0.75)
eq('the respawn table maximum is still 100', BB_SRC.table_max, 100.0)
eq('the unarmed fight floor is still 80', BB_SRC.fight_floor, 80.0)
eq('the unarmed short floor is still 60', BB_SRC.short_floor, 60.0)
eq('the fight rung still asks for level > 24', BB_SRC.fight_min_level, 24.0)
eq('the ladder is still shut at or below level 15', BB_SRC.ladder_min_level, 15.0)
check('each floor still has exactly ONE call site',
      BB_SRC.fight_sites == 1 and BB_SRC.short_sites == 1,
      '(fight=%d short=%d)' % (BB_SRC.fight_sites, BB_SRC.short_sites))
check("the short floor's return still sits ABOVE the fight rung -- flip it and "
      "the co-armed W16 reading in iterations/reports/replay-check/ silently "
      "changes meaning",
      BB_SRC.short_above_fight is True)
check('bbfloor_domain reports no source-assertion error on trunk',
      BB_SRC.errors == [], repr(BB_SRC.errors))

# ---------------------------------------------------------------------------
print()
print('=== 8. `pullthink`: the facts its CONTROL DESIGN rests on ===')
# `pullthink` has no usable armed/baseline contrast, because its domain
# (`bot.roamCampPull ~= nil`) exists only when `pullcamp` is armed and
# `pullcamp` is armed on one leg only.  The replay desk therefore reads it
# against the ARMED LEG OF A WAVE WHERE `pullcamp` IS ARMED AND `pullthink` IS
# NOT (W16 vs W15).  Four shipped facts make that design valid rather than
# merely convenient, and each of them can be deleted by an ordinary edit:
#
#  * two call sites -- one id, two inseparable halves;
#  * site A's `bot.roamCampPull ~= nil` guard -- delete it and the id stops
#    being a camp-pull lever, so the domain the reading is taken over is no
#    longer the domain the id acts on;
#  * `pullcamp` still GATED -- promote it and the baseline leg acquires a
#    camp-pull domain.  The cross-wave control then measures the wrong thing
#    while every number it prints still parses;
#  * the two ids NOT conjoined -- the pullcad trap, which this repo has already
#    paid for once.
import pullthink_domain as PT                           # noqa: E402

PT_SRC = PT.load_source()
eq('pullthink still has exactly 2 call sites', PT_SRC.sites, 2)
check("site A still guards on `bot.roamCampPull ~= nil`", PT_SRC.site_a_guard)
check("`pullcamp` is still GATED -- promoting it gives the baseline leg a "
      "camp-pull domain and voids the cross-wave control in "
      "iterations/reports/replay-check/", PT_SRC.dep_gated)
check('pullthink is NOT conjoined with pullcamp (the pullcad trap)',
      PT_SRC.no_conjunction)
check('pullthink_domain reports no source-assertion error on trunk',
      PT_SRC.errors == [], repr(PT_SRC.errors))

# The acceptance criterion in GH #186 is stated on ONE number -- "位移 < 50 u"
# -- and TWO tools now compute it (pulldrag_walk's `still` column and
# pullthink_domain's `still v1`).  Let them drift and the issue's bar is
# silently two different bars.
import pulldrag_walk as PW                              # noqa: E402

eq("GH #186's 50 u threshold is the same number in both tools that read it",
   float(PW.STILL_U), float(PT.STILL_U))

print()
if FAIL:
    print('%d FAILED: %s' % (len(FAIL), ', '.join(FAIL)))
    sys.exit(1)
print('all detector source constants match their shipped sites')

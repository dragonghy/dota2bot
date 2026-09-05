#!/usr/bin/env python3
"""GH #511's proposed fix is a no-op, and this file is the assertion that says so.

WHAT #511 REPORTED, AND WHAT IT CONCLUDED
  The report is right about the facts: outpost capture channels abort at ~75%
  (53 attempts, 13 completions, 66.6 s of hero time), on BOTH legs, so it is a
  shipped defect owned by no armed id.  It then attached a root cause --

      "`mode_outpost_generic.lua` has no `bot:IsChanneling()` guard anywhere in
       the file, so `Think()` re-issues the capture order every tick and each
       re-issue restarts the channel.  Fix: `if bot:IsChanneling() then return
       end` at the top of `Think()`."

  -- and both halves of that are false.

  (1) THE GUARD IS ALREADY IN FORCE.  `Think()`'s FIRST statement is
      `if J.CanNotUseAction(bot) then return end`, and `J.CanNotUseAction`
      lists `or bot:IsChanneling()` among its disjuncts.  "The file does not
      contain the token" is true and load-bearing on nothing: the predicate is
      evaluated one call deep, earlier on the same frame.  Landing the proposed
      line adds a disjunct that already ran.

  (2) THE ORDERING IS BACKWARDS.  `mode_outpost_generic.lua` holds the repo's
      ONLY `ability_capture` cast site, and it sits BELOW that guard.  So every
      cast in the corpus is, by construction, a frame on which
      `bot:IsChanneling()` was ALREADY false -- the channel was gone before the
      order went out.  The re-issue is downstream of the interruption, not its
      cause.

  Measured on 4 W47 games (8 episodes, 36 casts, 36 channel add/remove pairs)
  with `tools/batch_test/behavioral/outchan_domain.py`:

      casts inside the caster's own live channel   0 / 36
      cast strictly BEFORE the removal (the claim) 0 / 28
      tie at 0.1 s dump resolution (UNDECIDABLE)   4 / 28
      removal strictly first                      24 / 28
      in-file abandon clause (a) enemy in vision   2 / 36
      in-file abandon clause (b) recent damage     0 / 36
      in-file abandon clause (c) outnumbered       0 / 36
      anti-vacuum control (same (a) estimator,
        every sampled frame)                  19127 / 58978  -- LIVE

  34 of 36 interruptions therefore have NO reason inside this file: the mode
  never stopped wanting the outpost.  Something outside it took the tick, its
  order killed the channel, and the outpost mode re-won ~0.1 s later and
  re-cast.  That makes the lever COMMITMENT in `GetDesire()`, not a guard in
  `Think()` -- the opposite end of the file from where #511 pointed.

WHY THIS IS A TEST AND NOT A PARAGRAPH IN A REPORT
  The §EN ratchet rule: a conclusion whose premise lives in someone else's edit
  must be written as an assertion that fires by itself, because on the day the
  premise moves, nobody's backlog is looking at it.  Two premises here are
  exactly that shape:
    * `J.CanNotUseAction` keeping its `bot:IsChanneling()` disjunct -- it is
      what makes the proposed line redundant.  If a future edit drops it, the
      no-op verdict silently becomes wrong.
    * `mode_outpost_generic.lua` staying the sole `ability_capture` cast site --
      it is what makes "a logged cast proves the predicate was false" a
      deduction rather than a guess.
  Section 1 pins both.  Section 2 pins the reading on real frames.

  Section 1 also fires the day someone lands #511's line as written: a literal
  `bot:IsChanneling()` inside `mode_outpost_generic.lua` is asserted ABSENT,
  with the message saying it is redundant rather than wrong.  That is the
  no-op landing THIS file exists to stop -- the `droppick`/§EK shape, where the
  diff edits source, passes review, and is bit-identical to the unfixed tree.

Run: python3 tests/test_outchan_domain.py   (or tests/run_py_tests.sh)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BEHAV = os.path.join(ROOT, 'tools', 'batch_test', 'behavioral')
sys.path.insert(0, BEHAV)

import outchan_domain  # noqa: E402

MODE_LUA = os.path.join(ROOT, 'bots', 'mode_outpost_generic.lua')
JMZ_LUA = os.path.join(ROOT, 'bots', 'FunLib', 'jmz_func.lua')
FIXTURE = os.path.join(ROOT, 'tests', 'fixtures',
                       'tl_260905_010205_luna_outchan.json')
# Second slice, kept for what the first one CANNOT exercise: it carries two
# 0.1s-resolution ties (so the tie bookkeeping is under test rather than
# vacuously satisfied) and two interruptions where in-file clause (a) is
# genuinely TRUE (so "no in-file reason" is a reading taken at interruption
# instants, not an estimator that never fires there).
FIXTURE2 = os.path.join(ROOT, 'tests', 'fixtures',
                        'tl_260905_010226_axe_outchan.json')

FAIL = []


def check(ok, label, detail=''):
    print('%-6s %s%s' % ('ok' if ok else 'FAIL', label,
                         '' if ok else '  -- ' + detail))
    if not ok:
        FAIL.append(label)


def strip_comments(src):
    """Lua comments out.  #EN burned a round on this exact hazard: the first
    run of a "does this predicate carry a gate id" assertion read 1 with no id
    in the tree, because it had matched the COMMENT explaining why there was
    none.  Any claim about what the code DOES must read code, never prose.
    """
    src = re.sub(r'--\[\[.*?\]\]', '', src, flags=re.S)
    return re.sub(r'--[^\n]*', '', src)


def body_of(src, name):
    m = re.search(r'\nfunction\s+%s\s*\(' % re.escape(name), src)
    if not m:
        return None
    tail = src[m.end():]
    end = re.search(r'\nend\b', tail)
    return tail[:end.start()] if end else tail


# ---------------------------------------------------------------------------
# 1.  SOURCE ANCHORS -- the ratchet.  These run with no corpus at all.
# ---------------------------------------------------------------------------
print('=== 1. source anchors (why the proposed line is a no-op) ===')

mode_src = strip_comments(open(MODE_LUA).read())
jmz_src = strip_comments(open(JMZ_LUA).read())

can_not = body_of(jmz_src, 'J.CanNotUseAction')
check(can_not is not None, 'J.CanNotUseAction is findable in jmz_func.lua',
      'the anchor moved; the no-op verdict below is unverified')
check(bool(can_not) and 'bot:IsChanneling()' in can_not,
      "J.CanNotUseAction still ORs in bot:IsChanneling()",
      'the disjunct is GONE -- #511\'s line is no longer redundant and this '
      'whole file\'s verdict must be re-derived')

think = body_of(mode_src, 'Think')
check(think is not None, 'mode_outpost_generic.Think is findable')
check(bool(think) and 'J.CanNotUseAction(bot)' in think,
      'Think() still calls J.CanNotUseAction(bot)',
      'the guard call is gone; the channel predicate no longer runs at all')

# The guard must come BEFORE the cast, or it guards nothing.
if think:
    guard_at = think.find('J.CanNotUseAction(bot)')
    cast_at = think.find('Action_UseAbilityOnEntity')
    check(guard_at >= 0 and cast_at >= 0 and guard_at < cast_at,
          'the guard precedes the ability_capture cast inside Think()',
          'guard_at=%d cast_at=%d' % (guard_at, cast_at))

# Sole cast site -- what upgrades "a cast happened" into "the predicate was
# false on that frame".
bots_dir = os.path.join(ROOT, 'bots')
sites = []
for dirpath, _dirs, files in os.walk(bots_dir):
    for fn in files:
        if not fn.endswith('.lua'):
            continue
        path = os.path.join(dirpath, fn)
        if 'ability_capture' in strip_comments(open(path).read()):
            sites.append(os.path.relpath(path, ROOT))
check(sites == ['bots/mode_outpost_generic.lua'],
      "ability_capture is referenced in exactly one shipped file",
      'found %s -- a second cast site would break the deduction that every '
      'logged cast passed the guard' % sites)

# The no-op itself: if this token appears in Think(), someone landed #511 as
# written.
#
# ⚠️ NARROWED 2026-09-05 (協同組, the round that landed 'outcommit'). This check
# used to read `'bot:IsChanneling()' not in mode_src` -- the WHOLE FILE -- and
# it went red on a change it was never about. The predicate is redundant in
# exactly one place, Think(), and for exactly one reason: J.CanNotUseAction is
# Think()'s first statement and evaluates it there. Nothing makes it redundant
# in GetDesireHelper, which J.CanNotUseAction never runs through -- and reading
# it there is precisely the commitment fix this file's own §7 handoff asked for
# ("go fix the commitment in GetDesire"). A file-wide token ban therefore
# forbade the remedy it prescribed. Same shape as the 1b correction in
# tests/test_outlatch_capture_liveness.py: an assertion that keeps passing while
# its stated reason drifts off the thing it is pinned to.
think_body = body_of(mode_src, 'Think') or ''
check('bot:IsChanneling()' not in think_body,
      'Think() carries no redundant bot:IsChanneling() guard',
      'a bot:IsChanneling() guard was added to Think(). It is REDUNDANT, not '
      'wrong: J.CanNotUseAction already evaluates that predicate earlier on the '
      'same frame (see GH #511 and the docstring above). Landing it changes no '
      'behaviour -- remove it and fix the commitment side in GetDesire instead.')

# The three in-file abandon clauses the pricing leg `infile` mirrors.  If one
# is edited away, the "34/36 interruptions had no in-file reason" reading is
# measuring a different set of clauses than the ones it names.
desire = body_of(mode_src, 'GetDesireHelper') or ''
suitable = body_of(mode_src, 'IsSuitableToCaptureOutpost') or ''
check('GetCurrentVisionRange()' in desire and 'GetEnemiesNearLoc' in desire,
      'infile clause (a) still lives in GetDesireHelper',
      'the enemy-in-vision abandon clause moved')
check('WasRecentlyDamagedByAnyHero(5)' in suitable,
      'infile clause (b) still lives in IsSuitableToCaptureOutpost')
check('GetNumOfAliveHeroes' in suitable,
      'infile clause (c) still lives in IsSuitableToCaptureOutpost')

# ---------------------------------------------------------------------------
# 2.  THE READING, on real frames carried in-repo.
# ---------------------------------------------------------------------------
print()
print('=== 2. the reading on real frames (tl_260905_010205_luna_outchan) ===')
print('    real dumper output sliced verbatim from 20260905_010205_slot7,')
print('    seed 4763, t=1344..1374; no field is synthesized.')

check(os.path.exists(FIXTURE), 'the real-frame timeline slice is present',
      'missing %s -- section 2 cannot run, and a section that did not run is '
      'NOT a section that passed' % FIXTURE)

if os.path.exists(FIXTURE):
    doc = json.load(open(FIXTURE))
    check(doc['game']['source'] == '20260905_010205_slot7',
          'the slice still names the game it was cut from')

    r = outchan_domain.price_one(FIXTURE, gap_s=5.0)

    check(r['casts'] == 14, 'the episode still carries its 14 casts',
          'got %d' % r['casts'])
    check(r['adds'] == 14 and r['removes'] == 14,
          'and its 14 channel add/remove pairs',
          'add=%d rem=%d' % (r['adds'], r['removes']))

    # THE finding: #511's line would have suppressed nothing.
    check(r['issuefix_suppressed'] == 0,
          "leg issuefix: 0 casts land inside the caster's own live channel",
          'got %d/%d -- if this is non-zero, #511 is RIGHT and the verdict in '
          'this file is wrong' % (r['issuefix_suppressed'], r['issuefix_checked']))
    check(r['issuefix_checked'] == 14,
          'and all 14 casts were actually examined',
          'checked=%d -- a 0 over an empty examination is not a reading'
          % r['issuefix_checked'])
    # The leg's own anti-vacuum: an emptied interval list reports the same
    # 0-suppressed as a real reading. Assert the intervals were rebuilt.
    check(r['issuefix_intervals'] == 14,
          'and all 14 live-channel intervals were reconstructed',
          'intervals=%d -- with no intervals the leg suppresses nothing no '
          'matter what the frames say, and reports it as a pass'
          % r['issuefix_intervals'])

    # The ordering: removal first, every time, no ties in this slice.
    check(r['selfresend_before'] == 0,
          'leg selfresend: 0 casts strictly precede the removal they would explain')
    check(r['selfresend_after'] == 13,
          'and 13 removals strictly precede the following cast',
          'got %d' % r['selfresend_after'])
    check(r['selfresend_tie'] == 0,
          'with no 0.1s-resolution ties in this slice to argue over',
          'got %d' % r['selfresend_tie'])
    check(min(r['resend_gaps']) > 0,
          'no signed gap is negative (min=%.1f)' % min(r['resend_gaps']))

    # No in-file reason to abandon, on any of the 14 interruptions.
    check((r['infile_a'], r['infile_b'], r['infile_c']) == (0, 0, 0),
          'leg infile: none of the three in-file abandon clauses was true',
          'a/b/c = %d/%d/%d' % (r['infile_a'], r['infile_b'], r['infile_c']))
    check(r['interrupts'] == 14,
          'across all 14 interruption instants',
          'checked %d' % r['interrupts'])

    # ANTI-VACUUM: the (a) estimator must be shown live on this same slice,
    # or its three zeros above are a stuck probe rather than a reading.
    check(r['control_vision_frames'] > 0,
          'anti-vacuum: the clause-(a) estimator fires elsewhere in the slice '
          '(%d/%d frames)' % (r['control_vision_frames'],
                              r['control_total_frames']),
          'the control is DEAD: every zero in leg infile is uninterpretable')

# ---------------------------------------------------------------------------
# 3.  THE SECOND SLICE -- the two things slice 1 cannot exercise.
# ---------------------------------------------------------------------------
print()
print('=== 3. second real-frame slice (tl_260905_010226_axe_outchan) ===')
print('    kept for its ties and its LIVE clause-(a) firings, both absent')
print('    from slice 1 -- see the FIXTURE2 note.')

check(os.path.exists(FIXTURE2), 'the second real-frame slice is present',
      'missing %s -- the tie and clause-(a) bookkeeping would then be '
      'asserted only where it cannot fire' % FIXTURE2)

if os.path.exists(FIXTURE2):
    r2 = outchan_domain.price_one(FIXTURE2, gap_s=5.0)

    check(r2['casts'] == 4 and r2['issuefix_intervals'] == 4,
          'the axe episode still carries its 4 casts and 4 channel intervals',
          'casts=%d intervals=%d' % (r2['casts'], r2['issuefix_intervals']))
    check(r2['issuefix_suppressed'] == 0,
          "leg issuefix: still 0 casts inside the caster's own live channel",
          'got %d' % r2['issuefix_suppressed'])

    # THE tie leg. Slice 1 has no ties, so without this the difference between
    # `gap < 0` and `gap <= 0` is invisible to the whole suite.
    check(r2['selfresend_tie'] == 2,
          'leg selfresend: the 2 resolution ties are counted AS ties',
          'tie=%d before=%d after=%d -- if the ties have been folded into '
          '`before`, the refutation of #511\'s mechanism is being credited '
          'with evidence that orders nothing'
          % (r2['selfresend_tie'], r2['selfresend_before'],
             r2['selfresend_after']))
    check(r2['selfresend_before'] == 0,
          'and still 0 casts strictly precede a removal',
          'got %d' % r2['selfresend_before'])
    check(r2['selfresend_after'] == 1,
          'and 1 removal strictly precedes the following cast',
          'got %d' % r2['selfresend_after'])

    # THE clause-(a) leg fires here. This is what makes slice 1's 0/14 a
    # reading taken at interruption instants rather than an estimator that
    # cannot fire there at all.
    check(r2['infile_a'] == 2,
          'leg infile: clause (a) is TRUE on 2 of this episode\'s 4 '
          'interruptions',
          'got %d -- the in-file estimator does not fire at interruption '
          'instants anywhere in the corpus, so slice 1\'s 0/14 is a stuck '
          'probe' % r2['infile_a'])
    check((r2['infile_b'], r2['infile_c']) == (0, 0),
          'while clauses (b) and (c) stay false here too',
          'b/c = %d/%d' % (r2['infile_b'], r2['infile_c']))

print()
if FAIL:
    print('FAILED (%d): %s' % (len(FAIL), ', '.join(FAIL)))
    sys.exit(1)
print('all outchan domain checks passed')

#!/usr/bin/env python3
"""[ratchet] A test that walks `bots/` must not walk over the farm-only switches.

`bots/Customize/` holds two gitignored, farm-only, TRANSIENT files --
`soak_side.lua` (the gate switch) and `soak_pool.lua`.  Every gate test in this
suite creates and deletes the first one.  A scanner that LISTS it and then
OPENS it has a window between the two, and the caller's `assert(io.open(path))`
turns that window into a red whose text names a file the caller has no business
reading.  GH #365 §2 published exactly that red on three files, attributed it to
GH #229 (contention BETWEEN GATE TESTS) and routed the fix there -- where it is
still blocked.  It never needed to wait: those files are not gate tests, they
never write the switch, they only walk over it, and the walk is theirs.

WHY THIS FILE EXISTS RATHER THAN A THIRD ROUND OF FIXES.  The class has now
been counted three times and each count was different -- "18 call sites" (a
`grep "io.popen('find "`, too narrow), then "at least 17 of 23", then the real
answer.  A defect class whose SIZE nobody can state is a class that comes back;
this file is the instrument, kept, so the next arrival is a red rather than a
rediscovery.

HOW IT MEASURES (and the one place it does not).  Every `io.popen(...)`
argument in `tests/*.lua` is extracted with a paren/quote-balanced scan over
comment-stripped source, its file-local string constants are resolved, and each
fully-resolved command is then EXECUTED.  A command REACHES the switch
directory iff its real output contains `bots/Customize/general.lua` -- a
committed file that is always present, sitting in the same directory with the
same extension, so it stands in for the switches without this test having to
CREATE one.  Creating a real `soak_*` file to probe with would be the very
contention the rule exists to remove (and would break every walk that has not
been fixed yet, which is the wrong way round).

  LIMIT, stated because it is load-bearing: this measures the ENUMERATION, not
  the read.  `tests/test_ancient_hp_unit.lua` cannot use `find`'s `! -path`
  (it enumerates with an `ls` glob), so it closes the window on the READ side
  with `lua_source_scan.is_farm_only`; its command still reaches, legitimately,
  and it is named in READ_SIDE_FILTERED below.  A second entry there must be
  argued, not appended.

  LIMIT 2: a command built from a function PARAMETER (`'find ' .. dir ..`)
  cannot be resolved statically -- its value is whatever its callers pass.
  Those are not skipped: they are listed in UNRESOLVED_HAND_READ with the
  argument each caller actually passes, and an unresolved command that is NOT
  on that list is a FINDING.  A new walk therefore costs a hand read, which is
  the whole point; it cannot join the population in silence.

Run: python3 tests/test_bots_walk_farm_only.py
"""

import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TESTS = os.path.join(REPO, "tests")

# The literal is defined once, in tests/lua_source_scan.lua, and read from
# there -- a second copy of it is the defect this file's own subject warns
# about (four files that merely named the path in a COMMENT were swept into the
# switch-writer census as RAW on 2026-09-02).
SCANNER = os.path.join(TESTS, "lua_source_scan.lua")

# A file that is always present in the switches' own directory, used as their
# proxy so this test never has to create one.  See HOW IT MEASURES above.
PROXY = "bots/Customize/general.lua"

# `find`-shaped walks that legitimately reach and filter on the READ side.
READ_SIDE_FILTERED = {
    "tests/test_ancient_hp_unit.lua": "enumerates with an `ls` glob, which has "
    "no `! -path`; filters with lua_source_scan.is_farm_only before reading",
}

# Commands built from a parameter or a non-constant, hand-read on 2026-09-03.
# The value is what the call sites actually pass.
UNRESOLVED_HAND_READ = {
    # -- built from a function parameter: the value is whatever callers pass --
    """tests/test_botsinit_env_namespace.lua  ::  'find ' .. dir .. " -name '*.lua' -type f " .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' 2>/dev/null'""":
        "listLua('bots') x2 and listLua('tests/fixtures'); carries the clause",
    """tests/test_ckpush_minute_unit.lua  ::  'find ' .. dir .. ' -name "*.lua" ' .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' 2>/dev/null'""":
        "lua_files_under('bots'); carries the clause",
    """tests/test_tormself_identity_domain.lua  ::  "find " .. dir .. " -name '*.lua' " .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' | sort'""":
        "luaFiles('bots') x2 and luaFiles('tests/fixtures'); carries the clause",
    """tests/test_tpclaim_stamp_on_commit.lua  ::  'find ' .. dir .. ' -name "*.lua" ' .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. ' | sort'""":
        "lua_files_under('bots'); carries the clause",
    """tests/test_glyph_veto_subject.lua  ::  "find " .. root .. " -name '*.lua' -type f " .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. " 2>/dev/null\"""":
        "lua_files('bots') (:115 via scan) and lua_files(dir) over the corpus "
        "dirs (:193, :305); carries the clause. Hand-read 2026-09-11 (hero desk "
        "-- this walk is this desk's own, from the glyphany round, and it was "
        "walking bots/ WITHOUT the clause until now: registering it was not "
        "enough, the clause had to be added first",
    """tests/test_local_assign_discipline.lua  ::  "find " .. root .. " -name '*.lua' -type f " .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. " 2>/dev/null\"""":
        "lua_files() loops root over ROOTS == {'bots', 'game'} (:52); carries "
        "the clause. Hand-read 2026-09-11 (hero desk -- this desk's own walk, "
        "from the awraxfield/GH #714 round; same missing-clause fix as the line "
        "above. A gitignored farm-only file is not shipped source, so a "
        "dropped-`=` census must not count its declarations)",
    """tests/test_wk_reserve_rank_blind.lua  ::  'ls ' .. dir""":
        "frame_files() loops dir over DIRS == {'tests/fixtures', 'tests/frames'} "
        "(:78, :127-:141); the table is a file-scope local built from two "
        "literals and nothing writes to it. A plain `ls` is NOT recursive, so it "
        "cannot reach bots/Customize/. Hand-read 2026-09-15 (hero desk -- this "
        "desk's own walk, from the wkrank0 round, registered in the SAME work "
        "unit that landed it, per GH #803)",
    """tests/test_lion_hex_panic_level.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the literal table {FIXTURE_DIR, "
        "STAGED_DIR} == {'tests/fixtures', 'tests/frames'} (:89-:90, :122); "
        "both are file-scope locals assigned once from string literals and "
        "nothing writes to either. A plain `ls` is NOT recursive, so it cannot "
        "reach bots/Customize/ -- identical in shape to the "
        "test_wk_reserve_rank_blind.lua entry above. ⚠️ Registered 2026-09-16 "
        "by the STRATEGY desk, not by the author: the file carries its own "
        "comment at :119-:120 saying it 'belongs on the hand-read list of "
        "tests/test_bots_walk_farm_only.py (GH #774)' and landed anyway, so "
        "this census was RED on trunk across at least three desks' 开工自检 "
        "(replay-check 20260916T124500Z §self-check named it; py_gate.py does "
        "NOT cover this file, so no push hook ever refused it). GH #803's rule "
        "-- register in the SAME work unit that lands the walk -- is exactly "
        "what was skipped, and a comment naming an obligation is not the "
        "obligation being met",
    """tests/test_cm_lane_fallback_wallet.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the literal table {FIXTURE_DIR, "
        "STAGED_DIR} == {'tests/fixtures', 'tests/frames'} (:97-:98, :129); "
        "both are file-scope locals assigned once from string literals and "
        "nothing writes to either. A plain `ls` is NOT recursive, so it cannot "
        "reach bots/Customize/ -- the entry above, and the "
        "test_wk_reserve_rank_blind.lua one above that, are the same shape. "
        "⚠️ Registered 2026-09-16 by the DIRECTOR, not by the author (hero "
        "desk, be8a9185 at 14:09:23Z). THIS IS THE SECOND FILE IN TWO DAYS "
        "THAT CARRIES ITS OWN OBLIGATION COMMENT (:125-:126, verbatim 'this "
        "file belongs on the hand-read list of "
        "tests/test_bots_walk_farm_only.py (GH #774)') AND LANDED WITHOUT "
        "MEETING IT -- so the defect is not that authors do not know. It is "
        "that this census is `in_gate: false` in tools/agent/py_gate_manifest.json, "
        "so no push hook can refuse the landing, and the red is found hours "
        "later by whichever desk opens next (here: batch-desk 开工自检 at "
        "15:11Z, red window [14:09Z, 15:5xZ]). That is the subject of owed row "
        "walk_farm_census_admitted_to_push_gate_or_priced / GH #843, and this "
        "entry is its eighth receipt, not its fix",
    # -- Registered 2026-09-15 by the DIRECTOR, not by either author.  Both
    # -- walks below landed between the 18:06Z and 21:08Z self-checks and left
    # -- this census RED on trunk for ~3.5h (batch-desk 20260915T210852Z.md
    # -- §十), which is GH #624 / #774 verbatim.  ⛔ The wardcomma file ALSO
    # -- held a real finding on the REACHING side, which is a different defect
    # -- and got a different fix: its `[source]` case walked
    # -- `find bots -name '*.lua' -print` with no clause at all, and that case
    # -- asserts "exactly one" missing-comma literal exists in bots/ -- so on
    # -- the farm, where bots/Customize/soak_side.lua exists, it was counting a
    # -- different population than in CI.  Registration would have been the
    # -- WRONG fix there; the clause was added to the walk instead.
    # -- 📌 One commit pair, two halves of this census, two unlike defects.
    """tests/test_axe_call_ring_anchor.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:57-:58, :86-:88) -- two file-scope "
        "literals, no parameter reaches the loop -- and keeps only names ending "
        ".lua; plain `ls` is NOT recursive, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-15 by the DIRECTOR although the walk is the hero "
        "desk's (axecallring, fc0201cd, 20:00Z)",
    # -- Registered 2026-09-16 by the DIRECTOR, again not by the author.  This
    # -- is the THIRD consecutive night this census went red on trunk for a
    # -- newly-landed walk and the director registered it: 09-15 twice
    # -- (wardcomma, axecallring), 09-16 once (axebhcamp, a3d8b7b, hero desk,
    # -- 22:00Z).  GH #803 says the landing work unit registers its own walk;
    # -- that is prose, and prose is what this repo keeps paying for.
    # -- ⭐ The MECHANISM is measured, not guessed: this census costs 4.065s
    # -- against a 3.0s per-test cap, so it is `over_per_test_cap` and has
    # -- NEVER been in the push gate -- the author's own hook cannot tell them.
    # -- See RULING 61 (tools/agent/py_gate_measure.py docstring) and the owed
    # -- row `walk_farm_census_admitted_to_push_gate_or_priced` (GH #843).
    """tests/test_axe_hunger_camp_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:199-:200, :242-:246) -- two "
        "file-scope literals, no parameter reaches the loop -- and keeps only "
        "names matching ^f_.*%.lua$; plain `ls` is NOT recursive, so it never "
        "reaches bots/Customize/. Hand-read 2026-09-16 by the DIRECTOR although "
        "the walk is the hero desk's (axebhcamp, a3d8b7b, 22:00Z)",
    # -- Registered 2026-09-16 by the DIRECTOR, again not by the author, and
    # -- this is the FOURTH such registration in two days: 09-15 twice
    # -- (wardcomma, axecallring), 09-16 twice (axebhcamp, and this one --
    # -- lionwpanic, 5cc18d6d, hero desk, 11:30Z).
    # -- ⭐⭐ THE ONE NEW FACT, and it is the sharpest evidence GH #843 has:
    # -- THE AUTHOR WROTE THIS OBLIGATION DOWN AND STILL COULD NOT MEET IT.
    # -- tests/test_lion_hex_panic_level.lua:119-120 says, verbatim:
    # --   "⚠️ io.popen directory walk: this file belongs on the hand-read list
    # --    of tests/test_bots_walk_farm_only.py (GH #774)."
    # -- So this is NOT inattention, and no amount of further prose fixes it:
    # -- the author knew the rule, cited the issue by number, and shipped red
    # -- anyway -- because this census costs 4.065s against a 3.0s per-test cap,
    # -- is therefore `over_per_test_cap`, and has NEVER been in the push gate.
    # -- Their hook had nothing to tell them with. The red was found ~1h later
    # -- by the replay-check desk (20260916T124530Z.md §10.6), author long gone.
    # -- ⇒ GH #803's "the landing work unit registers its own walk" is prose,
    # -- and this line is the fourth receipt for what prose costs. The fix is
    # -- the owed row `walk_farm_census_admitted_to_push_gate_or_priced`
    # -- (GH #843), not a fifth reminder. See RULING 61 / RULING 65.
    """tests/test_lion_hex_panic_level.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:89-:90, :120-:125) -- two "
        "file-scope literals, no parameter reaches the loop -- and keeps only "
        "names matching ^f_.*%.lua$; plain `ls` is NOT recursive, so it never "
        "reaches bots/Customize/. Hand-read 2026-09-16 by the DIRECTOR although "
        "the walk is the hero desk's (lionwpanic, 5cc18d6d, 11:30Z)",
    """tests/test_wardcomma_mid3_spot.lua  ::  sFind""":
        "a bare parameter, so nothing about it resolves here: scan(sFind) is a "
        "closure local to one case (:374-:385) with exactly TWO call sites, "
        "both file-literal, both rooted at tests/fixtures -- "
        "\"find tests/fixtures -maxdepth 1 -name 'f_*.lua' -print\" (:387) and "
        "\"find tests/fixtures -name 'f_*.lua' -print\" (:388). The case's whole "
        "point is the flat/recursive DIFFERENCE between those two, so neither "
        "can be folded into the other. Neither is rooted at bots/, so neither "
        "reaches bots/Customize/. Hand-read 2026-09-15 by the DIRECTOR although "
        "the walk is the strategy desk's (wardcomma, ff0121ea, 19:29Z)",
    """tests/test_lion_ult_aoe_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:127-:131); plain `ls` is NOT "
        "recursive, so it never reaches bots/Customize/. Hand-read 2026-09-11 "
        "(hero desk -- this desk's own walk, from the lionraoe round)",
    """tests/test_zuus_jump_escape_any.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:124-:128); same non-recursive `ls` "
        "as the line above, same reason. Hand-read 2026-09-11 (hero desk -- this "
        "desk's own walk, from the zusjumpany round)",
    """tests/test_cutoff_retreat_ancient_race_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the two literals {'tests/fixtures', "
        "'tests/frames'} (:110) and keeps only names ending .lua; plain `ls` is "
        "NOT recursive, so it never reaches bots/Customize/. Hand-read "
        "2026-09-12 (strategy desk -- this walk is the cutoff round's own)",
    """tests/test_lion_drain_creep_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:73-:74, :102) and keeps only "
        "names matching ^f_.*%.lua$; plain `ls` is NOT recursive, so it never "
        "reaches bots/Customize/. Hand-read 2026-09-13T22:xxZ by the DIRECTOR "
        "although the walk is the hero desk's (liondrainreach, 20:02Z) -- "
        "THIRD instance on this census, second one in a single day, and the "
        "first two are the two entries directly below. The repeat is not "
        "carelessness: `tests/test_bots_walk_farm_only.py` measures 3.64s "
        "against the python gate's 3.0s per-test cap, so it is `in_gate: "
        "False` and the desk that reddens it is told `py gate: 84 ran, 0 "
        "findings` and pushed. Registered under GH #806, which is the same "
        "defect on the Lua leg",
    """tests/test_axe_cull_blade_mail.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:79-:80, :102) and keeps only "
        "names ending .lua; plain `ls` is NOT recursive, so it never reaches "
        "bots/Customize/. Hand-read AND REGISTERED IN THE SAME WORK UNIT "
        "2026-09-15 (hero desk, axecullbm round) -- which is what GH #803 asked "
        "this desk for after the liondrainreach and cmcreepclock entries above "
        "were both read by somebody else. The registration cost is one entry; "
        "the alternative, twice measured, is a trunk red found by the next desk "
        "to start work",
    """tests/test_cm_lane_fallback_wallet.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:97-:98, :129) and keeps only "
        "names matching ^f_.*%.lua$; plain `ls` is NOT recursive, so it never "
        "reaches bots/Customize/. Hand-read 2026-09-16 by the STRATEGY desk "
        "although the walk is the hero desk's -- the SEVENTH instance of GH "
        "#774, and the file's own line 125 already says in so many words that "
        "it 'belongs on the hand-read list of tests/test_bots_walk_farm_only.py "
        "(GH #774)'. That comment is what makes this entry worth a sentence: a "
        "comment naming an obligation is not that obligation being met, and "
        "nothing in the three push legs can tell the difference, because this "
        "file measures over the python gate's 3.0s per-test cap and is "
        "`in_gate: False` (GH #806 is the same defect on the Lua leg)",
    """tests/test_cm_w_creep_clock.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:72-:73, :120) and keeps only "
        "names matching ^f_.*%.lua$; plain `ls` is NOT recursive, so it never "
        "reaches bots/Customize/. Hand-read 2026-09-13 by the DIRECTOR although "
        "the walk is the hero desk's (cmcreepclock, 13:56Z) -- it landed "
        "unregistered and left this census RED on trunk for ~2h, which is the "
        "GH #624 shape TWICE ON THE SAME CENSUS BY THE SAME DESK: the entry "
        "directly below is its 09-12 twin, registered by the strategy desk for "
        "the identical reason. Two instances of one shape on one census is no "
        "longer a lapse, it is the habit being cheaper to skip than to keep; "
        "raised with the hero desk rather than only re-registered. "
        "APPENDED 2026-09-13T16:1xZ (strategy desk, chasering round -- this "
        "desk hit the same red independently and wrote a SECOND entry for "
        "this key, which a dict silently keeps only the last of; the "
        "duplicate is deleted and its one distinct fact folded in here "
        "instead, GH #777's shape in a new file): the walk carries the "
        "in-file comment `-- UNRESOLVED_HAND_READ: io.popen, registered per "
        "GH #596's habit` -- the COMMENT was written and the registration "
        "never happened, so the file reads as registered to anyone who "
        "opens it, its author included. That is a new way to LOOK "
        "registered without being registered, and it is worth naming "
        "separately from forgetting outright",
    """tests/test_cm_w_teamfight_clock.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:87-:88, :136) and the walk is the "
        "same non-recursive `ls` as the lines above, same reason. Hand-read "
        "2026-09-12 by the STRATEGY desk although the walk is the hero desk's: "
        "it landed unregistered and left this census RED on trunk, which is the "
        "GH #624 shape -- the red is found by whoever starts work next, not by "
        "its author. Reading it costs seconds; leaving it costs a round",
    """tests/test_axe_q_lane_push_clock.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:82-:83, :138) -- two literals, no "
        "parameter reaches the loop -- and the walk is the same non-recursive "
        "`ls` as the lines above, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-12 (hero desk -- this desk's own walk, from the "
        "axecallclock round, registered in the SAME work unit that landed it "
        "rather than left for whoever starts next: GH #624 / #774)",
    """tests/test_axe_q_lane_push_crowd.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:96-:97, :152) -- two literals, no "
        "parameter reaches the loop -- and the walk is the same non-recursive "
        "`ls` as the lines above, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-16 (hero desk -- this desk's own walk, from the "
        "axecallcrowd round, registered in the SAME work unit that landed it: "
        "GH #624 / #774)",
    """tests/test_axe_q_lane_push_nocap.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:89-:90, :145) -- two literals, no "
        "parameter reaches the loop -- and the walk is the same non-recursive "
        "`ls` as the lines above, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-16 (hero desk -- this desk's own walk, from the "
        "axecallnocap round, registered in the SAME work unit that landed it; "
        "the axecallcrowd round one above is the precedent this copies: "
        "GH #624 / #774)",
    # -- ⚠️ `test_axe_hunger_camp_reach.lua` WAS registered here in the same
    # -- pass as the crowd walk above, by the hero desk, before the rebase
    # -- showed the DIRECTOR had already registered it upstream (:134).  The
    # -- duplicate was dropped rather than kept: a dict literal with the same
    # -- key twice keeps the LAST value silently, so two hand reads of the same
    # -- walk do not disagree loudly -- one of them just disappears.  ⇒ The
    # -- hero desk's own note on that debt lives in its round report
    # -- (iterations/reports/hero/20260916T021022Z.md §6), not here.
    """tests/test_lion_q_lane_push_clock.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:92-:93, :144) -- two literals, no "
        "parameter reaches the loop -- and the walk is the same non-recursive "
        "`ls` as the lines above, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-12 (hero desk -- this desk's own walk, from the "
        "lionpushclock round, registered in the SAME work unit that landed it: "
        "GH #624 / #774)",
    # -- GH #774, the five that stood unregistered on trunk.  Hand-read
    # -- 2026-09-12 by the HERO desk in one pass: two of them are this desk's
    # -- own (wk_q_commit_ration, zuus_arc_retreat_immunity, both landed
    # -- earlier the same day) and the bolt one is this round's; the two tpdef
    # -- walks are the strategy desk's.  Registering only this desk's three
    # -- would have left the census RED for whoever starts next, which is the
    # -- GH #624 shape this list exists to avoid -- so all five go in.
    """tests/test_tpdefall_tower_commit_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "the loop at :140 iterates the two LITERALS {'tests/fixtures', "
        "'tests/frames'} -- no parameter reaches it -- and :143 runs a plain "
        "`ls`, which is NOT recursive, so it never reaches bots/Customize/",
    """tests/test_tpdefnan_tower_tp_landing.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "same shape at :106-:107: two literals, non-recursive `ls`, never "
        "reaches bots/Customize/",
    """tests/test_tpdeftower_anchor_pricing.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "same shape again: corpus_paths() loops dir over the two LITERALS "
        "{'tests/fixtures', 'tests/frames'} with no parameter reaching it, and "
        "runs a plain non-recursive `ls`, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-12 (strategy desk) -- registered in the SAME work "
        "unit that added the walk, which is the half GH #774 says keeps going "
        "missing",
    # -- ⚠️ BOTH DESKS FIXED THIS RED IN THE SAME HOUR (2026-09-13), and the
    # -- rebase collided here.  The hero desk's entry for the tpdeftower walk is
    # -- kept verbatim below because it landed first and its attribution is the
    # -- accurate one: the walk landed in 87ef8628 (strategy, GH #782) and left
    # -- this check RED on trunk, and the desk that opened the gate next
    # -- registered it.  The strategy desk's own round (divepost) registers its
    # -- new walk in the SAME work unit that wrote it, which is the half GH #774
    # -- says keeps going missing.
    """tests/test_tpdeftower_outpost_narrow.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() at :126 loops dir over the two LITERALS "
        "{'tests/fixtures', 'tests/frames'} with no parameter reaching it, and "
        "runs a plain non-recursive `ls`, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-13 (hero desk): the call site's own comment already "
        "claimed it was registered here and it was not -- the walk landed in "
        "87ef8628 (strategy, GH #782) and left this check RED on trunk, which "
        "is GH #774 / #624 verbatim. Registered by the next desk to open the "
        "gate, not by the author",
    """tests/test_rescpost_outpost_narrow.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the same two LITERALS "
        "{'tests/fixtures', 'tests/frames'} with no parameter reaching it, and "
        "runs a plain non-recursive `ls`, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-13 (strategy desk, GH #782 family third landing) "
        "BEFORE the push this time: the two siblings above each landed RED on "
        "trunk and were registered by whichever desk opened the gate next "
        "(GH #774 / #624). Author and registrant are the same seat here",
    """tests/test_divepost_outpost_narrow.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the same two literals and runs the same "
        "non-recursive `ls`; it is a copy of the walk on the line above. "
        "Hand-read 2026-09-13 (strategy desk, divepost round -- registered in "
        "the same work unit that wrote it)",
    """tests/test_roshpost_outpost_narrow.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the same two literals "
        "{'tests/fixtures', 'tests/frames'} with no parameter reaching it, and "
        "runs the same plain non-recursive `ls`; it is a copy of the walk two "
        "lines above and never reaches bots/Customize/. Hand-read 2026-09-13 "
        "(strategy desk, GH #782 family FOURTH and final name-test landing -- "
        "roshpost). ⭐ Registered because THIS CHECK CAUGHT IT before the push: "
        "the finding named the file and the exact unresolved command, which is "
        "the GH #774 loop closing in the authoring work unit instead of on the "
        "next desk to open a gate",
    """tests/test_divepocket_target_in_pocket.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the same two literals "
        "{'tests/fixtures', 'tests/frames'} with no parameter reaching it, and "
        "runs the same plain non-recursive `ls`; it is a copy of the walk above "
        "and never reaches bots/Customize/. Hand-read 2026-09-13 (strategy desk, "
        "divepocket round). ⭐ Registered in the authoring work unit because THIS "
        "CHECK CAUGHT IT before the push -- second consecutive round the GH #774 "
        "loop closed with the author, not with the next desk to open a gate",
    """tests/test_chasering_target_in_ring.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over the same two literals "
        "{'tests/fixtures', 'tests/frames'} with no parameter reaching it, and "
        "runs the same plain non-recursive `ls`; it is a copy of the walk above "
        "and never reaches bots/Customize/. Hand-read 2026-09-13 (strategy desk, "
        "chasering round). ⭐ Third consecutive round this check caught the new "
        "file in the AUTHORING work unit rather than leaving the red on trunk "
        "for the next desk to open a gate (the GH #774 loop)",
    """tests/test_wk_q_commit_ration.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() at :110 loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:79-:80); non-recursive `ls`, "
        "same reason as every line above (hero desk, wkqcommit round)",
    """tests/test_zuus_arc_retreat_immunity.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'}; non-recursive `ls` (hero desk, "
        "zusarcimm round)",
    """tests/test_zuus_bolt_retreat_immunity.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'}; non-recursive `ls` (hero desk, "
        "zusboltimm round -- registered in the SAME work unit that wrote the "
        "walk, which is the habit the four lines above failed to keep)",
    """tests/test_blind_a_roamidle_campsel.lua  ::  'grep -l ' .. key .. ' tests/fixtures/*.lua 2>/dev/null | wc -l'""":
        "[1d] loops key over {'GetCurrentActionType', 'GetActiveMode'}; the "
        "path is the fixed glob tests/fixtures/*.lua, not a walk of bots/, so "
        "it cannot reach bots/Customize/ regardless of the parameter's value",
    """tests/test_wk_q_catchall_odds.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'}; plain "
        "`ls` is NOT recursive, so it never reaches bots/Customize/ at all",
    """tests/test_lvlany_first_member_level_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'} and "
        "keeps only names ending .lua; same non-recursive `ls` as the two lines "
        "above, same reason (hand-read 2026-09-10, strategy desk -- this walk is "
        "that round's own)",
    """tests/test_lvlcarry_carry_deny_level_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'} and "
        "keeps only names ending .lua; identical walk to the lvlany line above "
        "and safe for the same reason -- plain `ls` is NOT recursive, so it "
        "never reaches bots/Customize/. Hand-read 2026-09-11 (strategy desk -- "
        "this walk is that round's own, which is exactly why it costs a read)",
    """tests/test_lvlgroup_group_push_level_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'} (:126) "
        "and keeps only names ending .lua; third copy of the lvlany walk, safe "
        "for the same reason -- plain `ls` is NOT recursive, so it never reaches "
        "bots/Customize/. ⛔ Hand-read 2026-09-11 by the lvltogether round, one "
        "round LATE: the lvlgroup round landed the walk without registering it, "
        "so this check was RED on trunk until now (the GH #624 shape -- a census "
        "outside the pusher's own gate, found by the next desk to run it)",
    """tests/test_lvltogether_can_attack_together_level_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'} (:128) "
        "and keeps only names ending .lua; fourth and last copy of the lvlany "
        "walk (the baton's four levers each carry one), safe for the same reason "
        "-- plain `ls` is NOT recursive, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-11 (strategy desk -- this walk is that round's own)",
    """tests/test_lvlhitcreep_suit_to_hit_creep_level_quantifier.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'} (:103) "
        "and keeps only names ending .lua; same walk as the four lvlany-family "
        "lines above, safe for the same reason -- plain `ls` is NOT recursive, so "
        "it never reaches bots/Customize/. Hand-read 2026-09-11 (strategy desk -- "
        "this walk is that round's own, registered in the SAME commit that lands "
        "it: the lvlgroup round's one-round-late registration two entries up is "
        "the GH #624 shape this is avoiding)",
    """tests/test_zuus_arc_execute_kill.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {'tests/fixtures', 'tests/frames'}; same "
        "non-recursive `ls` as the line above, same reason",
    """tests/test_anyhero_first_member_quantifier.lua  ::  'ls ' .. glob .. ' 2>/dev/null'""":
        "corpus_paths() loops glob over the two LITERAL globs "
        "{'tests/fixtures/*.lua', 'tests/frames/*.lua'} -- the parameter is a "
        "whole glob rather than a directory, but it is still non-recursive and "
        "still rooted at the corpus, so it never reaches bots/Customize/. "
        "Hand-read 2026-09-10 (director, GH #729 round) at :103-:107",
    """tests/test_lion_q_field_engagement.lua  ::  'ls ' .. dir .. '/*.lua 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'} (:62-:63); the '/*.lua' is appended "
        "by the caller, and plain `ls` is NOT recursive, so it never reaches "
        "bots/Customize/. Hand-read 2026-09-10 (director, GH #729 round) at :80-:88",
    """tests/test_cast_ring_mirror_discipline.lua  ::  'ls ' .. glob .. ' 2>/dev/null'""":
        "ls(glob) has three callers, all passing a LITERAL glob: "
        "frame_paths() loops over {'tests/fixtures/*.lua', 'tests/frames/*.lua'} "
        "(:109) and the suite census passes 'tests/test_*.lua' (:295). Same "
        "whole-glob-instead-of-directory shape as the anyhero line above, same "
        "reason it is safe: still non-recursive, still rooted in tests/, so it "
        "never reaches bots/Customize/. Hand-read 2026-09-11 (strategy desk) at "
        ":97-:110 and :295 -- not this desk's walk, cleared because it was the "
        "one finding standing between trunk and green on this leg",
    """tests/test_itemtrip_supply_gap.lua  ::  'ls "' .. dir .. '"'""":
        "ls('bots', ...) x2 and ls('tests/fixtures', ...); `ls \"bots\"` is NOT "
        "recursive, so it never reaches bots/Customize/ at all",
    """tests/run_tests.lua  ::  'ls "' .. root .. '"'""":
        "root == 'tests' (arg[0]'s directory)",
    """tests/test_wk_roshan_lategame_reconciliation.lua  ::  sCmd""":
        "glob_files(GLOB), GLOB == 'ls tests/fixtures/f_*.lua'",

    # -- corpus walks that never enter bots/ at all --------------------------
    """tests/test_cm_w_selfdefense_damager.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() loops dir over {FIXTURE_DIR, STAGED_DIR} == "
        "{'tests/fixtures', 'tests/frames'}; plain `ls` is NOT recursive, so it "
        "never reaches bots/Customize/. Hand-read 2026-09-11 (hero desk -- this "
        "walk is that round's own, which is exactly why it costs a read). The "
        "same file's only other popen was REMOVED rather than registered: a "
        "`grep -r ... bots/` would have reached Customize legitimately, so §5 "
        "reads the five focus hero files by literal path instead",
    """tests/test_cm_ult_reach_meter_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    """tests/test_lion_ult_reserve_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    """tests/test_lion_hex_reserve_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}; same shape as the ult sister above",
    """tests/test_wk_q_castrange_meter_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    # Hand-read 2026-09-07 (director), at :193-197: `corpus_paths()` loops
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })`, and those two are
    # literals at :176-177 ('tests/fixtures' / 'tests/frames').  Byte-identical
    # in shape to the hex/ult sisters above; bots/ is not in the enumeration.
    """tests/test_lion_considere_earlyreturn_domain.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-08 (director), at :156-158: `corpus_paths()` loops
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })`, and those two are
    # literals at :136-137 ('tests/fixtures' / 'tests/frames'); its one caller
    # (:249) passes no argument.  Same shape as the hex/ult sisters above;
    # bots/ is not in the enumeration.  The file's other popen (:473) is
    # `grep -rl "lionultcash" bots` -- CAND is a literal at :130, so it
    # resolves statically and is measured by execution, not by this list.
    """tests/test_lion_ult_cash_weakest.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-10 (strategy), at :99-109: `corpus_paths()` takes no
    # parameter and loops `for _, glob in ipairs({ 'tests/fixtures/*.lua',
    # 'tests/frames/*.lua' })` -- both literals in the loop header itself, so the
    # only values `glob` can take are those two.  Same corpus-walk shape as the
    # lion sisters above, differing only in that the literal carries the `*.lua`
    # suffix rather than being a bare directory; bots/ is not in the enumeration
    # at all, and plain `ls` is not recursive either way.  It is the file's only
    # io.popen.
    """tests/test_tombhp_list_to_unit_ruler.lua  ::  'ls ' .. glob .. ' 2>/dev/null'""":
        "corpus_paths() over {'tests/fixtures/*.lua', 'tests/frames/*.lua'}",
    # Hand-read 2026-09-08 (director), at :154-170: `corpus_paths()` takes no
    # parameter, its single caller (:232) passes none, and the loop is
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })` over the literals at
    # :129-130 ('tests/fixtures' / 'tests/frames').  It is the file's only
    # io.popen.  Same shape as the lion sisters above; bots/ is not in the
    # enumeration.
    """tests/test_lion_ult_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-12 (hero), at the file's `corpus_paths()`: no parameter,
    # one caller (§1) passing none, loop is `for _, dir in ipairs({ FIXTURE_DIR,
    # STAGED_DIR })` over the literals ('tests/fixtures' / 'tests/frames').  It
    # is the file's only io.popen.  Same shape as the lion/wk sisters above;
    # bots/ is not in the enumeration.  ⭐ REGISTERED IN THE SAME WORK UNIT THAT
    # CREATED THE FILE -- GH #774's whole case is that an unregistered new walk
    # turns this census red for the NEXT group, hours after its author left.
    """tests/test_lion_hex_interrupt_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-08 (hero), at :140-144: identical shape to the entry
    # above -- `corpus_paths()` over {FIXTURE_DIR, STAGED_DIR}, literals at
    # :116-117, one caller (:224) passing no argument.  Registered in the SAME
    # work unit that created the file, which is the half GH #596 says was
    # missed the previous round (the director's entry above is that round's
    # debt, paid on main first; this conflict is the two payments meeting).
    """tests/test_wk_q_lane_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-08 (hero), at :111-121: `corpus_paths()` takes no
    # parameter, its three callers (:292, :424, :447) pass none, and the loop is
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })` over the literals at
    # :86-87 ('tests/fixtures' / 'tests/frames').  It is the file's only
    # io.popen.  Same shape as the lion/wk sisters above; bots/ is not in the
    # enumeration.  Registered in the SAME work unit that created the file
    # (GH #596's habit, and the second round to keep it).
    """tests/test_axe_cull_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-08 (hero), at :160-175: `corpus_paths()` takes no
    # parameter, its one caller (:253) passes none, and the loop is
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })` over the literals at
    # :137-138 ('tests/fixtures' / 'tests/frames').  It is the file's only
    # io.popen.  Same shape as the lion/wk/axe sisters above; bots/ is not in
    # the enumeration.  Registered in the SAME work unit that created the file
    # (GH #596's habit, and the third round to keep it).
    # Hand-read 2026-09-08 (hero), at :182-193: `corpus_paths()` takes no
    # parameter, its one caller (:277) passes none, and the loop is
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })` over the literals at
    # :161-162 ('tests/fixtures' / 'tests/frames').  Same shape as the
    # lion/wk/axe/cm sisters above; bots/ is not in the enumeration.  The
    # file's other popen (:623) is `grep -rl "'zusjumpland'" bots` -- CAND is a
    # literal at :155, so it resolves statically and is measured by execution,
    # not by this list.  Registered in the SAME work unit that created the file
    # (GH #596's habit, and the fourth round to keep it).
    """tests/test_zuus_jump_landing_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    """tests/test_cm_w_lane_band.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-08 (hero), at :137-152: `corpus_paths()` takes no
    # parameter, its four callers (:246, :377, :435, :500) pass none, and the
    # loop is `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })` over the
    # literals at :113-114 ('tests/fixtures' / 'tests/frames').  Same shape as
    # the lion/wk/axe/cm/zuus sisters above; bots/ is not in the enumeration.
    # The file's other popen (:425) is `grep -rl "'lionqkill'" bots` -- CAND is
    # a literal at :105, so it resolves statically and is measured by execution,
    # not by this list.  Registered in the SAME work unit that created the file
    # (GH #596's habit, and the fifth round to keep it).
    """tests/test_lion_q_kill_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    # Hand-read 2026-09-08 (hero), at :150-165: `corpus_paths()` takes no
    # parameter, its three callers (:248, :424, :462) pass none, and the loop is
    # `for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR })` over the literals at
    # :128-129 ('tests/fixtures' / 'tests/frames').  It is the file's only
    # io.popen.  Same shape as the lion/wk/axe/cm/zuus sisters above; bots/ is
    # not in the enumeration.  Registered in the SAME work unit that created the
    # file (GH #596's habit, and the sixth round to keep it).
    """tests/test_axe_battle_hunger_fight_reach.lua  ::  'ls ' .. dir .. ' 2>/dev/null'""":
        "corpus_paths() over {FIXTURE_DIR, STAGED_DIR} == {tests/fixtures, "
        "tests/frames}",
    """tests/test_fixture_mana_price.lua  ::  'ls ' .. d .. ' 2>/dev/null'""":
        "d in {tests/fixtures, tests/frames}",
    # Hand-read 2026-09-06 (director), at :399-400: the loop is written
    # `for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' })`, so both
    # values are literals in the file itself.  Narrower than its sisters above
    # -- the glob is `<dir>/*.lua`, not the bare directory -- so it reaches
    # strictly less, and bots/ is not in the enumeration either way.
    """tests/test_lion_drain_immune_target.lua  ::  'ls ' .. dir .. '/*.lua 2>/dev/null'""":
        "dir in {tests/fixtures, tests/frames}",
    """tests/test_fixture_kv_getters.lua  ::  'ls ' .. d .. ' 2>/dev/null'""":
        "d in {tests/fixtures, tests/frames} -- corpus_files(), the ipairs list "
        "on :121 feeding the popen on :122; the file's other popen (:393) is the "
        "constant `ls tests/fixtures`, resolved statically and out of scope here",
    """tests/test_level_premise_registry.lua  ::  'ls ' .. pattern .. ' 2>/dev/null'""":
        "ls('tests/*.lua')",

    # -- grep -r over bots/: a DIFFERENT failure mode, registered on purpose --
    # grep opens each file itself, so there is no list-then-open window and no
    # TOCTOU red.  What a switch could do here is MATCH and perturb a count --
    # content-dependent, not structural.  Neither pattern is a shape a
    # `return { side=..., cand=..., seed=... }` table can satisfy, so both are
    # clean today; the entry exists so the next reader does not have to
    # re-derive that this class is different rather than missed.
    'tests/test_abil1st_first_unit_reader.lua  ::  "grep -rn \'" .. pattern .. "\' bots/"':
        "count(pattern) over bots/, content-dependent, see the note above",
    'tests/test_abilanc_ancient_selector.lua  ::  "grep -rn \'" .. pattern .. "\' bots/"':
        "count(pattern) over bots/, content-dependent, see the note above",
}

checks = 0
failures = []


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        failures.append(msg)


def key_of(rel, expr):
    """Identity of a call site: file + the expression, whitespace-collapsed.

    THE LINE NUMBER IS NOT IN IT.  A key carrying a line number turns every
    unrelated edit above a site into a red -- GH #442 is that exact defect,
    filed the day before this file was written, and this file's first draft
    reproduced it within the hour.
    """
    return "%s  ::  %s" % (rel, " ".join(expr.split()))


def strip_comments(src):
    """Blank out `--` line comments, honouring quoted strings, keeping lines."""
    out, quote, i, n = [], None, 0, len(src)
    while i < n:
        c = src[i]
        if quote:
            out.append(c)
            if c == "\\" and i + 1 < n:
                i += 1
                out.append(src[i])
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            out.append(c)
        elif c == "-" and src[i + 1 : i + 2] == "-":
            while i < n and src[i] != "\n":
                i += 1
            out.append("\n")
            i += 1
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def popen_calls(src):
    """(lineno, argument expression) for every io.popen( ... ) in `src`."""
    out, key = [], "io.popen"
    at = src.find(key)
    while at != -1:
        j = at + len(key)
        while j < len(src) and src[j] in " \t":
            j += 1
        if src[j : j + 1] == "(":
            i, depth, quote, start = j + 1, 1, None, j + 1
            while i < len(src) and depth:
                c = src[i]
                if quote:
                    if c == "\\":
                        i += 1
                    elif c == quote:
                        quote = None
                elif c in "\"'":
                    quote = c
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                    if not depth:
                        break
                i += 1
            out.append((src.count("\n", 0, at) + 1, src[start:i]))
        at = src.find(key, at + len(key))
    return out


def split_concat(expr):
    """Top-level `..` operands of a Lua expression."""
    parts, buf, quote, i = [], "", None, 0
    while i < len(expr):
        c = expr[i]
        if quote:
            buf += c
            if c == "\\" and i + 1 < len(expr):
                i += 1
                buf += expr[i]
            elif c == quote:
                quote = None
        elif c in "\"'":
            quote = c
            buf += c
        elif c == "." and expr[i + 1 : i + 2] == ".":
            parts.append(buf)
            buf = ""
            i += 1
        else:
            buf += c
        i += 1
    parts.append(buf)
    return parts


def resolve(expr, consts, clause, depth=0):
    if depth > 6:
        return None
    text = ""
    for part in split_concat(expr):
        p = part.strip()
        if not p:
            continue
        if len(p) > 1 and p[0] == p[-1] and p[0] in "\"'":
            body = p[1:-1]
            for a, b in (('\\"', '"'), ("\\'", "'"), ("\\\\", "\\")):
                body = body.replace(a, b)
            text += body
        elif p.endswith("FARM_ONLY_FIND_CLAUSE"):
            text += clause
        elif p in consts:
            sub = resolve(consts[p], consts, clause, depth + 1)
            if sub is None:
                return None
            text += sub
        else:
            return None
    return text


# --- the clause, read from its single definition ------------------------------
try:
    scanner_src = open(SCANNER, encoding="utf-8").read()
except OSError as exc:
    print("UNCERTIFIABLE -- cannot read %s: %s" % (SCANNER, exc))
    sys.exit(2)

clause = None
for line in scanner_src.splitlines():
    if line.startswith("M.FARM_ONLY_FIND_CLAUSE"):
        # Strip the OUTER quote only.  `.strip("'\"")` eats the clause's own
        # closing `"` as well, and the damage is silent: the ratchet still
        # works, but the repair instruction it prints is a shell fragment that
        # does not parse.
        clause = line.split("=", 1)[1].strip()
        if len(clause) > 1 and clause[0] == clause[-1] and clause[0] in "'\"":
            clause = clause[1:-1]
        break
if not clause:
    print("UNCERTIFIABLE -- lua_source_scan.lua no longer defines "
          "M.FARM_ONLY_FIND_CLAUSE; this test's premise is gone")
    sys.exit(2)
check("soak_" in clause, "the clause read back does not mention the switches: %r" % clause)

# --- premise: the proxy is where this test believes it is ---------------------
check(os.path.exists(os.path.join(REPO, PROXY)),
      "%s is gone -- the proxy for the switches no longer exists, so 'reaches' "
      "would answer no for every command and this ratchet would pass vacuously"
      % PROXY)

# --- scan ---------------------------------------------------------------------
# [director 2026-09-15, GH #624 family] THE SUBPROCESS IS MEMOISED, THE CALL
# SITE IS NOT.  Every command here is a read-only walk (`find` / `ls`), so its
# stdout is a pure function of the command string -- running `ls tests/fixtures`
# a second time cannot answer differently.  It was being run 107 times.  279
# executions collapse to 82 distinct commands, and THAT is what buys this census
# a seat in the push gate: measured 3.723s against a 3.0s per-test cap, it was
# `in_gate: false`, so it could not refuse a push, and its reds were found hours
# later by the next desk to open a gate.  The cache is not a tidy-up; it is the
# difference between this file guarding trunk and merely describing it.
#
# ⛔ `executed` still counts CALL SITES, not subprocesses.  The `>= 100` guard
# below asks "did the extractor still match things", which is a question about
# call sites; counting distinct commands (82) would trip it and turn a speed-up
# into a false finding.  Two different questions, two different counters.
_CMD_CACHE = {}
_FAILED = object()


def run_walk(cmd):
    """stdout of one read-only walk, memoised on the command string."""
    hit = _CMD_CACHE.get(cmd)
    if hit is not None:
        return hit
    try:
        proc = subprocess.run(["bash", "-c", cmd], cwd=REPO, timeout=60,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        out = proc.stdout
    except (OSError, subprocess.TimeoutExpired):
        out = _FAILED
    _CMD_CACHE[cmd] = out
    return out


reaching, unresolved, executed = [], [], 0
for name in sorted(os.listdir(TESTS)):
    if not name.endswith(".lua"):
        continue
    rel = "tests/" + name
    src = open(os.path.join(TESTS, name), encoding="utf-8").read()
    consts = {}
    for raw in strip_comments(src).splitlines():
        stripped = raw.strip()
        if stripped.startswith("local ") and "=" in stripped:
            head, _, val = stripped.partition("=")
            var = head[len("local "):].strip()
            if var.isidentifier():
                consts.setdefault(var, val.strip().rstrip(","))
    for lineno, expr in popen_calls(strip_comments(src)):
        cmd = resolve(expr, consts, clause)
        if cmd is None:  # try dropping a trailing top-level `, <message>`
            depth, quote, cut, i = 0, None, None, 0
            while i < len(expr):
                c = expr[i]
                if quote:
                    if c == "\\":
                        i += 1
                    elif c == quote:
                        quote = None
                elif c in "\"'":
                    quote = c
                elif c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
                elif c == "," and depth == 0:
                    cut = i
                    break
                i += 1
            if cut is not None:
                cmd = resolve(expr[:cut], consts, clause)
        if cmd is None:
            unresolved.append(key_of(rel, expr))
            continue
        if cmd.startswith("lua5.1 "):
            continue  # a sub-sweep: its own popens are separate rows
        out = run_walk(cmd)
        if out is _FAILED:
            unresolved.append(key_of(rel, expr))
            continue
        executed += 1
        if PROXY.encode() in out and "soak_" not in cmd:
            reaching.append((rel, lineno, cmd))

# The scanner must have looked at something.  A census pointed at nothing
# reports zero findings and exits clean (GH #345), which here would read as
# "the class is gone" one edit after the extractor stopped matching.
check(executed >= 100,
      "only %d io.popen commands executed -- the extractor stopped matching, so "
      "'no findings' would mean 'nothing scanned'" % executed)

offenders = [r for r in reaching if r[0] not in READ_SIDE_FILTERED]
check(not offenders,
      "a tests/ walk reaches bots/Customize/ without excluding the farm-only "
      "switches -- add %s to the find, or filter with lua_source_scan."
      "is_farm_only, or route the walk through lua_source_scan.bots_files(): %s"
      % (clause, ["%s:%d" % (f, n) for f, n, _ in offenders]))

# The named read-side exception must still actually reach; if it stops
# reaching, the entry is stale and should be deleted rather than kept as a
# standing excuse.
still_reaching = {r[0] for r in reaching}
for path in READ_SIDE_FILTERED:
    check(path in still_reaching,
          "%s no longer reaches bots/Customize/ -- delete its READ_SIDE_FILTERED "
          "entry rather than leaving a standing exemption" % path)
    check("is_farm_only" in open(os.path.join(REPO, path), encoding="utf-8").read(),
          "%s is exempted on the grounds that it filters on the read side, and it "
          "no longer calls is_farm_only" % path)

new_unresolved = [u for u in unresolved if u not in UNRESOLVED_HAND_READ]
check(not new_unresolved,
      "a tests/ io.popen command cannot be resolved statically and is not on the "
      "hand-read list -- read it, then add it to UNRESOLVED_HAND_READ with the "
      "value its callers pass (do not delete this check): %s" % new_unresolved)

stale = [u for u in UNRESOLVED_HAND_READ if u not in unresolved]
check(not stale,
      "UNRESOLVED_HAND_READ names call sites that no longer exist (the line moved "
      "or the walk went away) -- re-read and update: %s" % stale)

print("%d checks, %d failed  [%d commands executed, %d unresolved]"
      % (checks, len(failures), executed, len(unresolved)))
for f in failures:
    print("FAIL: %s" % f)
sys.exit(1 if failures else 0)

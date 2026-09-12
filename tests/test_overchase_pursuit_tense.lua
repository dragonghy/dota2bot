-- [overchase / GH #760] LEG (a)'s PURSUIT TEST IS PAST TENSE, AND EVERY REPAIR
-- THIS CORPUS CAN EXPRESS IS A NO-OP OR AN ARTEFACT -- the pricing, pinned.
--
-- THE FINDING. GH #760 says J.ShouldPunishOverchase's leg (b) is a pure
-- POSITION test with no velocity term: it asks where the chaser is, not whether
-- he is coming in or going out, and measured 211/524 = 40.3% of entries as
-- collapses onto someone already retreating. That complaint is true of leg (a)
-- too, and on this corpus it is sharper there, because of leg (a)'s three
-- pursuit disjuncts the only one the dump can answer is the past-tense one:
--
--   oc_a_attacktarget 0 | oc_a_ischasing 0 | oc_a_recentdmg 2
--
-- i.e. "the chaser is on my ally" is inferred ENTIRELY from "the chaser damaged
-- my ally, up to 2 s ago" -- which is precisely what a chaser who has already
-- turned around and walked home looks like.
--
-- ⛔ WHY NOTHING LANDED, AND WHY THAT IS A READING RATHER THAN CAUTION. Four
-- narrowings were priced on real frames. All four are a no-op or an artefact:
--
--   (1) leg (b) velocity term (#760's proposal (a)) -- NOT MEASURABLE. A
--       fixture is ONE INSTANT; tests/mock/replay_fixture.lua answers the zero
--       vector for GetVelocity as a DECLARED world assumption, so there is no
--       depth delta to read. Asserted below against the mock, not assumed.
--   (2) J.IsChasingTarget promoted from disjunct to necessary condition
--       (#760's proposal (b)) -- refuses 2 of 2, CONSTRUCTIVELY: it needs
--       GetAnimActivity and IsFacingLocation and the dumper carries neither, so
--       oc_a_ischasing is 0 by construction. An annihilation produced by the
--       instrument is not a reading about the game.
--   (3) the pursuit lookback tightened 2.0 -> 1.0 s -- the ONE present-tense
--       narrowing the dump CAN answer, because recent_damage carries per-event
--       dt. Refuses 0 of 2: oc_a_pass_tight == oc_a_pass, oc_a_dmg_dt_le_1s 2.
--       A NO-OP. This is the reading that closes the question, because it is
--       the only one taken with a working instrument.
--   (4) leg (d) discounting the dying ally from the numbers branch -- the
--       f_071423_luna_chase shape that this tree's own J.ShouldNotChaseWhenLow
--       header records as having cost a batch run. oc_d_numbers_thin 0.
--
-- ⭐ THE SENTENCE FOR THE NEXT ROUND: on this corpus `overchase` has exactly
-- TWO witnesses, both in ONE fixture and both on the SAME 0.18-HP ally. An
-- effect-size ceiling of two frames bounds what ANY narrowing of this guard can
-- be shown to do, which is prior to the question of which narrowing is right
-- (the GH #770 shape). The lever is blocked on the dumper carrying facing /
-- velocity / attack-target, not on choosing a repair.
--
-- ⚠️ NOT gate plumbing (charter rule 2). Every count below comes from driving
-- the SHIPPED helpers on real dumped frames via tests/_overchase_sweep.lua; the
-- mock-blindness claims in (1) and (2) are driven against the real loader on a
-- real frame rather than restated from its comments.
--
-- ======================================================================
-- ⭐⭐ THIS FILE CARRIES NO PRIVATE HARNESS. WHY, AND WHAT REPLACED IT.
-- ======================================================================
-- [GH #790, strategy desk 2026-09-12T22:xxZ] The first version of this file ran
-- itself: its own ok()/FAIL printer, its own summary line, and two `os.exit`
-- calls. tests/test_run_tests_guard.py named it, verbatim, and it stood as a
-- trunk red -- but THE RED IS NOT THE HAZARD. The hazard is the green:
-- tests/run_tests.lua loads every tests/test_*.lua into ONE process, so a file
-- that calls os.exit mid-suite DECAPITATES the run at itself, and the truncated
-- `N tests, 0 failures` that iron rule 6's dynamic half then prints is
-- indistinguishable from a complete pass (GH #200 / #387, measured there at
-- ~229 of 277 files silently unrun). A file that passes standalone is exactly
-- the file that looks fine.
--
-- Two properties of the old harness were load bearing, and neither is lost:
--
--   * REPORTING SURVIVES THE MOCK'S BLANKED `print`. tests/mock/bot_api.lua
--     sets `G.print = function() end` on fixture load, so the old harness's
--     ok/FAIL lines went silent from §6 onward -- on this file's very first run
--     13 ok lines printed, two whole sections vanished, and the exit code said
--     0. The old fix was to capture `print` into a local `say` plus a
--     completion marker. The runner needs neither: it reports through
--     `io.write` / `io.stdout:write`, which the mock does not touch, and it
--     counts and names every case itself. The property is now STRUCTURAL rather
--     than ceremonial -- and it is still asserted, at its source, below.
--   * A DEAD CENSUS MUST NOT READ AS A NO-OP. The old harness bailed with
--     os.exit(1) when the sweep subprocess died. The runner has no such escape
--     hatch and must not be given one, so `census_or_die` below is called first
--     in every count-reading case instead. This matters more than it looks:
--     with the counts nil, `C.oc_a_pass_tight == C.oc_a_pass` evaluates
--     nil == nil = TRUE, i.e. a dead instrument would SATISFY this file's
--     load-bearing conclusion for free (the GH #171 shape).
--
-- The mutation stand tools/agent/mutstand_overchase_tense.sh was rebuilt for
-- the same reason: it drives this file THROUGH the runner (run directly, the
-- file now merely returns its table and exits 0 in silence, which would score
-- every mutant as SURVIVED), and its M5 scores on the runner's own FAIL line
-- naming the contract breach rather than on the absent completion marker.

package.path = 'tests/?.lua;' .. package.path

local JMZ = 'bots/FunLib/jmz_func.lua'
local SWEEP = 'tests/_overchase_sweep.lua'
local MOCKBOT = 'tests/mock/bot_api.lua'

----------------------------------------------------------------------
-- The census, run as a subprocess at load time (the sweep rebuilds jmz_func
-- once per hero-frame and must not share this heap -- backlog 0q). Load time,
-- not per-case: it costs ~30 s and every case below reads the same counts.
----------------------------------------------------------------------

local G, C, F = {}, {}, {}
local done = false
local tail = {}
do
    local p = assert(io.popen('lua5.1 ' .. SWEEP .. ' 2>&1'))
    for line in p:lines() do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k then G[k] = v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck then C[ck] = tonumber(cv) end
        local ff, fh, fw = line:match('^F (%S+) (%S+) (%S+)$')
        if ff then F[#F + 1] = { ff, fh, fw } end
        if line == 'DONE' then done = true end
        -- Keep a short tail so a dead subprocess can say WHY without a re-run.
        tail[#tail + 1] = line
        if #tail > 6 then table.remove(tail, 1) end
    end
    p:close()
end

-- Every case that reads a count calls this FIRST. See the header: a missing
-- DONE makes the counts nil, and nil == nil satisfies the no-op conclusions.
local function census_or_die()
    if not done then
        error(SWEEP .. ' did not print DONE; the counts are NOT MEASURED and '
            .. 'must not be read as zeros. Last lines of its output:\n  '
            .. table.concat(tail, '\n  '))
    end
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local src = fh:read('*a')
    fh:close()
    return src
end

-- §6's frame, loaded once and memoised. Lazy rather than load-time so that a
-- fixture that goes missing fails the three cases that need it and nothing else.
local frame_cache
local function frame()
    if not frame_cache then
        local rf = require('mock.replay_fixture')
        local f = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'
        local J = rf.load(f, 'npc_dota_hero_lina')
        local bot = GetBot()
        frame_cache = {
            path = f,
            J = J,
            bot = bot,
            enemies = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {},
        }
    end
    return frame_cache
end

local tests = {}

----------------------------------------------------------------------
-- §1  The census ran, and it reached the corpus it claims to have read.
----------------------------------------------------------------------

tests['[census] the sweep ran to completion'] = function()
    census_or_die()
end

tests['[census] the sweep reached the corpus'] = function()
    census_or_die()
    assert((C.fixtures or 0) >= 100 and (C.live or 0) >= 900,
        'fixtures=' .. tostring(C.fixtures) .. ' live=' .. tostring(C.live))
end

----------------------------------------------------------------------
-- §2  Leg (a)'s pursuit test is past tense on this corpus.
----------------------------------------------------------------------

tests['[tense] the shipped pursuit lookback is still parseable'] = function()
    census_or_die()
    assert(tonumber(G.CHASE_DMG_LOOKBACK) ~= nil,
        "leg (a)'s WasRecentlyDamagedByHero lookback no longer parses out of "
        .. JMZ .. '; re-point the pattern in ' .. SWEEP
        .. ' rather than hardcoding the number here')
end

tests['[tense] only the PAST-TENSE pursuit disjunct answers'] = function()
    census_or_die()
    assert(C.oc_a_attacktarget == 0 and C.oc_a_ischasing == 0
        and C.oc_a_recentdmg > 0,
        'attacktarget=' .. tostring(C.oc_a_attacktarget)
        .. ' ischasing=' .. tostring(C.oc_a_ischasing)
        .. ' recentdmg=' .. tostring(C.oc_a_recentdmg)
        .. ' -- if a present-tense disjunct now answers, the dumper has grown a '
        .. 'field and GH #760 is newly measurable: re-price it, do not adjust this')
end

tests['[tense] leg (a) never fails for want of pursuit evidence'] = function()
    census_or_die()
    assert(C.oc_a_pursuit_unseen == 0,
        'oc_a_pursuit_unseen=' .. tostring(C.oc_a_pursuit_unseen)
        .. ' -- a low ally is present and the chaser is NOT visibly on them; that '
        .. 'is a new sub-population and the pricing above does not cover it')
end

----------------------------------------------------------------------
-- §3  Narrowing (3): the tightened lookback is a NO-OP. This is the load-
--     bearing number of the whole file -- the only pricing taken with an
--     instrument that works.
----------------------------------------------------------------------

tests['[no-op] the tightened pursuit lookback refuses NOTHING'] = function()
    census_or_die()
    assert(C.oc_a_pass_tight == C.oc_a_pass,
        'oc_a_pass=' .. tostring(C.oc_a_pass)
        .. ' oc_a_pass_tight=' .. tostring(C.oc_a_pass_tight)
        .. ' -- these have diverged, so tightening leg (a)\'s lookback is no longer '
        .. 'a no-op and the lever is worth writing. Re-read GH #760.')
end

tests['[no-op] it refuses nothing because the chaser is hitting them RIGHT NOW'] = function()
    census_or_die()
    assert(C.oc_a_dmg_dt_le_1s == C.oc_a_recentdmg,
        'oc_a_dmg_dt_le_1s=' .. tostring(C.oc_a_dmg_dt_le_1s)
        .. ' oc_a_recentdmg=' .. tostring(C.oc_a_recentdmg)
        .. ' -- some witness now rests on damage OLDER than 1 s, which is exactly '
        .. 'the population a tightened lookback would delete')
end

-- ⭐ THE POSITIVE CONTROL, and the reason §3's no-op is a reading rather than a
-- free pass. Everything §3 concludes is NEGATIVE, so a
-- WasRecentlyDamagedByHero (or a lookback argument) that had degenerated to
-- constant-true would satisfy every assertion above for nothing. 0.2 s sits
-- below the smallest dt in the witness set, so this bucket MUST come back
-- strictly smaller. It is the mutation stand's M1/M2 target.
tests['[control] the lookback argument actually bites (probe below the witness dts)'] = function()
    census_or_die()
    assert(C.oc_a_dmg_dt_le_02s < C.oc_a_recentdmg,
        'oc_a_dmg_dt_le_02s=' .. tostring(C.oc_a_dmg_dt_le_02s)
        .. ' is not below oc_a_recentdmg=' .. tostring(C.oc_a_recentdmg)
        .. ' -- WasRecentlyDamagedByHero is ignoring its lookback, so EVERY '
        .. 'no-op reading in this file is vacuous. Fix the instrument first.')
end

tests['[no-op] no frame passes leg (a) on stale damage alone'] = function()
    census_or_die()
    local loose_only = 0
    for _, r in ipairs(F) do
        if r[3] == 'oc_a_pass_loose_only' then loose_only = loose_only + 1 end
    end
    assert(loose_only == 0,
        loose_only .. ' frame(s) pass the 2.0 s test but not the 1.0 s one; those '
        .. 'are the lever\'s witnesses and it should be written')
end

----------------------------------------------------------------------
-- §4  Narrowing (4): the dying-ally discount, already priced -- still 0.
----------------------------------------------------------------------

tests['[no-op] discounting the dying ally from the numbers branch is a no-op'] = function()
    census_or_die()
    assert(C.oc_d_numbers_thin == 0,
        'oc_d_numbers_thin=' .. tostring(C.oc_d_numbers_thin)
        .. ' -- the f_071423_luna_chase shape now has witnesses here')
end

tests['[no-op] the (a) disc really is inside the (d) disc'] = function()
    census_or_die()
    assert(G.A_DISC_INSIDE_D_DISC == '1',
        'CHASE_ALLY_R=' .. tostring(G.CHASE_ALLY_R)
        .. ' SAFE_ALLY_R=' .. tostring(G.SAFE_ALLY_R)
        .. ' -- the double count is no longer structural, so §4 measures something '
        .. 'else than it claims')
end

----------------------------------------------------------------------
-- §5  The effect-size ceiling: two witnesses, one fixture, one ally.
----------------------------------------------------------------------

tests['[ceiling] the corpus carries exactly the witnesses the pricing assumed'] = function()
    census_or_die()
    assert(C.oc_fires == C.oc_ad_pass and C.oc_fires > 0 and C.oc_fires <= 4,
        'oc_fires=' .. tostring(C.oc_fires) .. ' oc_ad_pass=' .. tostring(C.oc_ad_pass)
        .. ' -- the witness set moved; every no-op reading above is scoped to it '
        .. 'and must be re-taken')
end

tests['[ceiling] every witness comes from ONE fixture'] = function()
    census_or_die()
    local seen, n = {}, 0
    for _, r in ipairs(F) do
        if r[3] == 'oc_a_pass' and not seen[r[1]] then
            seen[r[1]] = true
            n = n + 1
        end
    end
    assert(n == 1,
        'witnesses are spread over ' .. n .. ' fixtures -- the '
        .. 'ceiling argument in this header is about a single-fixture corpus')
end

tests['[ceiling] every firing still comes from the SOFT midline read'] = function()
    census_or_die()
    assert(C.oc_fire_building == 0 and C.oc_fire_midline == C.oc_fires,
        'fire_building=' .. tostring(C.oc_fire_building)
        .. ' fire_midline=' .. tostring(C.oc_fire_midline)
        .. ' fires=' .. tostring(C.oc_fires))
end

----------------------------------------------------------------------
-- §6  Narrowings (1) and (2) are blind, and that is shown on a real frame
--     rather than read off the mock's own comments. This is the half that
--     justifies GH #786 instead of merely asserting it.
----------------------------------------------------------------------

tests['[blind] the witness frame still carries an enemy in collapse range'] = function()
    local fr = frame()
    assert(#fr.enemies >= 1,
        fr.path .. ' no longer has an enemy within the collapse radius')
end

tests['[blind] (1) the frame reports the chaser as standing still'] = function()
    local fr = frame()
    assert(#fr.enemies >= 1, fr.path .. ' carries no enemy to read a velocity off')
    local v = fr.enemies[1]:GetVelocity()
    local moving = type(v) == 'table'
        and ((v.x or 0) ~= 0 or (v.y or 0) ~= 0)
    assert(not moving,
        'GetVelocity now answers a real velocity on this frame -- the '
        .. "dumper has grown the field, GH #760's proposal (a) is newly "
        .. 'measurable, and GH #786 is satisfied. Re-price leg (b).')
end

tests['[blind] (2) no anim activity, so J.IsChasingTarget cannot answer'] = function()
    local fr = frame()
    assert(#fr.enemies >= 1, fr.path .. ' carries no enemy to ask about')
    assert(not fr.J.IsChasingTarget(fr.enemies[1], fr.bot),
        'J.IsChasingTarget now answers true on a frame whose dump carries '
        .. 'no facing or anim activity -- check what it is reading')
end

----------------------------------------------------------------------
-- §7  The source registration must stay attached to the finding.
----------------------------------------------------------------------

tests['[source] leg (a) carries the GH #760 registration'] = function()
    -- ⚠️ The anchor must name #760. `REGISTERED, NOT REPAIRED` alone appears
    -- TWICE in this file (the tpdeftower registration from the same day uses
    -- the same phrase), so a bare search for it would be satisfied by the OTHER
    -- comment and this assertion would pass with leg (a)'s note deleted --
    -- caught by mutation stand M6.
    local src = read_file(JMZ)
    assert(src:find('GH #760] REGISTERED, NOT REPAIRED', 1, true) ~= nil,
        'the registration comment is gone from ' .. JMZ
        .. ' -- if the lever landed, delete this file too')
end

tests['[source] the registration names the blocking issue'] = function()
    local src = read_file(JMZ)
    assert(src:find('GH #786', 1, true) ~= nil,
        'the comment no longer points at the dumper-extension issue, so a '
        .. 'reader cannot find out why this is blocked rather than ignored')
end

-- ⭐ THE REPORTING CHANNEL, ASSERTED AT ITS SOURCE RATHER THAN BY EXPERIMENT.
-- This file's first version reported through the global `print` and lost two
-- whole sections to the mock the moment §6 loaded a fixture (header, GH #790).
-- The runner does not have that problem -- it writes through io.write -- and
-- this case is what keeps the REASON discoverable: if the mock ever stops
-- blanking print, the warning below stops being true and should be deleted
-- along with it.
--   Asserted on the mock's SOURCE, deliberately, and not by probing the live
-- `print`: the runner loads ~100 fixture-using files into one process in
-- alphabetical order, so by the time this file runs in a full suite the global
-- has usually been blanked by somebody else already. A live probe would then
-- read a property of the RUN ORDER, and pass or fail depending on the filter.
tests['[source] the mock still blanks the global print -- so no test file may report through it'] = function()
    local src = read_file(MOCKBOT)
    assert(src:find('G.print = function() end', 1, true) ~= nil,
        MOCKBOT .. ' no longer blanks the global print. The warning in this '
        .. "file's header (and the reason its private harness went silent) is "
        .. 'now historical; re-read GH #790 before relying on print anywhere '
        .. 'in tests/.')
end

return tests

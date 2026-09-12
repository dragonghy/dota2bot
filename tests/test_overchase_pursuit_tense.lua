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

package.path = 'tests/?.lua;' .. package.path

local JMZ = 'bots/FunLib/jmz_func.lua'
local SWEEP = 'tests/_overchase_sweep.lua'

-- ⚠️ REPORTING MUST NOT ROUTE THROUGH THE GLOBAL `print`. tests/mock/bot_api.lua
-- sets `G.print = function() end` ("keep test output clean") the moment a
-- fixture is loaded, so every ok/FAIL line emitted after §6's rf.load would be
-- SWALLOWED -- and a swallowed FAIL plus os.exit(0) is a file that reads green
-- while two sections went unreported. Caught on this file's first run: §6 and §7
-- printed nothing and the summary line vanished with it. Bind the real print
-- BEFORE any mock touches the globals.
local say = print

local pass, fail = 0, 0
local function ok(name, cond, msg)
    if cond then
        pass = pass + 1
        say('ok   ' .. name)
    else
        fail = fail + 1
        say('FAIL ' .. name .. ' -- ' .. tostring(msg))
    end
end

----------------------------------------------------------------------
-- §1  The census, run as a subprocess (the sweep rebuilds jmz_func once per
--     hero-frame and must not share this heap -- backlog 0q).
----------------------------------------------------------------------

local G, C, F = {}, {}, {}
local done = false
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
    end
    p:close()
end

-- A missing DONE means the subprocess died; every count below would then be a
-- zero that means "not measured" (the GH #171 shape), so this gates the file.
ok('census ran to completion', done,
    'tests/_overchase_sweep.lua did not print DONE; the counts below are '
    .. 'NOT MEASURED and must not be read as zeros')
if not done then
    say(string.format("\n%d passed, %d failed", pass, fail))
    os.exit(1)
end

ok('census reached the corpus', (C.fixtures or 0) >= 100 and (C.live or 0) >= 900,
    'fixtures=' .. tostring(C.fixtures) .. ' live=' .. tostring(C.live))

----------------------------------------------------------------------
-- §2  Leg (a)'s pursuit test is past tense on this corpus.
----------------------------------------------------------------------

ok('the shipped pursuit lookback is still parseable',
    tonumber(G.CHASE_DMG_LOOKBACK) ~= nil,
    "leg (a)'s WasRecentlyDamagedByHero lookback no longer parses out of "
    .. JMZ .. '; re-point the pattern in ' .. SWEEP
    .. ' rather than hardcoding the number here')

ok('only the PAST-TENSE pursuit disjunct answers',
    C.oc_a_attacktarget == 0 and C.oc_a_ischasing == 0 and C.oc_a_recentdmg > 0,
    'attacktarget=' .. tostring(C.oc_a_attacktarget)
    .. ' ischasing=' .. tostring(C.oc_a_ischasing)
    .. ' recentdmg=' .. tostring(C.oc_a_recentdmg)
    .. ' -- if a present-tense disjunct now answers, the dumper has grown a '
    .. 'field and GH #760 is newly measurable: re-price it, do not adjust this')

ok('leg (a) never fails for want of pursuit evidence',
    C.oc_a_pursuit_unseen == 0,
    'oc_a_pursuit_unseen=' .. tostring(C.oc_a_pursuit_unseen)
    .. ' -- a low ally is present and the chaser is NOT visibly on them; that '
    .. 'is a new sub-population and the pricing above does not cover it')

----------------------------------------------------------------------
-- §3  Narrowing (3): the tightened lookback is a NO-OP. This is the load-
--     bearing number of the whole file -- the only pricing taken with an
--     instrument that works.
----------------------------------------------------------------------

ok('the tightened pursuit lookback refuses NOTHING',
    C.oc_a_pass_tight == C.oc_a_pass,
    'oc_a_pass=' .. tostring(C.oc_a_pass)
    .. ' oc_a_pass_tight=' .. tostring(C.oc_a_pass_tight)
    .. ' -- these have diverged, so tightening leg (a)\'s lookback is no longer '
    .. 'a no-op and the lever is worth writing. Re-read GH #760.')

ok('and it refuses nothing because the chaser is hitting them RIGHT NOW',
    C.oc_a_dmg_dt_le_1s == C.oc_a_recentdmg,
    'oc_a_dmg_dt_le_1s=' .. tostring(C.oc_a_dmg_dt_le_1s)
    .. ' oc_a_recentdmg=' .. tostring(C.oc_a_recentdmg)
    .. ' -- some witness now rests on damage OLDER than 1 s, which is exactly '
    .. 'the population a tightened lookback would delete')

-- ⭐ THE POSITIVE CONTROL, and the reason §3's no-op is a reading rather than a
-- free pass. Everything §3 concludes is NEGATIVE, so a
-- WasRecentlyDamagedByHero (or a lookback argument) that had degenerated to
-- constant-true would satisfy every assertion above for nothing. 0.2 s sits
-- below the smallest dt in the witness set, so this bucket MUST come back
-- strictly smaller. It is the mutation stand's M1/M2 target.
ok('the lookback argument actually bites (probe below the witness dts)',
    C.oc_a_dmg_dt_le_02s < C.oc_a_recentdmg,
    'oc_a_dmg_dt_le_02s=' .. tostring(C.oc_a_dmg_dt_le_02s)
    .. ' is not below oc_a_recentdmg=' .. tostring(C.oc_a_recentdmg)
    .. ' -- WasRecentlyDamagedByHero is ignoring its lookback, so EVERY '
    .. 'no-op reading in this file is vacuous. Fix the instrument first.')

local loose_only = 0
for _, r in ipairs(F) do
    if r[3] == 'oc_a_pass_loose_only' then loose_only = loose_only + 1 end
end
ok('no frame passes leg (a) on stale damage alone', loose_only == 0,
    loose_only .. ' frame(s) pass the 2.0 s test but not the 1.0 s one; those '
    .. 'are the lever\'s witnesses and it should be written')

----------------------------------------------------------------------
-- §4  Narrowing (4): the dying-ally discount, already priced -- still 0.
----------------------------------------------------------------------

ok('discounting the dying ally from the numbers branch is a no-op',
    C.oc_d_numbers_thin == 0,
    'oc_d_numbers_thin=' .. tostring(C.oc_d_numbers_thin)
    .. ' -- the f_071423_luna_chase shape now has witnesses here')

ok('the (a) disc really is inside the (d) disc', G.A_DISC_INSIDE_D_DISC == '1',
    'CHASE_ALLY_R=' .. tostring(G.CHASE_ALLY_R)
    .. ' SAFE_ALLY_R=' .. tostring(G.SAFE_ALLY_R)
    .. ' -- the double count is no longer structural, so §4 measures something '
    .. 'else than it claims')

----------------------------------------------------------------------
-- §5  The effect-size ceiling: two witnesses, one fixture, one ally.
----------------------------------------------------------------------

ok('the corpus carries exactly the witnesses the pricing assumed',
    C.oc_fires == C.oc_ad_pass and C.oc_fires > 0 and C.oc_fires <= 4,
    'oc_fires=' .. tostring(C.oc_fires) .. ' oc_ad_pass=' .. tostring(C.oc_ad_pass)
    .. ' -- the witness set moved; every no-op reading above is scoped to it '
    .. 'and must be re-taken')

local fire_fixtures = {}
local n_fire_fixtures = 0
for _, r in ipairs(F) do
    if r[3] == 'oc_a_pass' and not fire_fixtures[r[1]] then
        fire_fixtures[r[1]] = true
        n_fire_fixtures = n_fire_fixtures + 1
    end
end
ok('every witness comes from ONE fixture', n_fire_fixtures == 1,
    'witnesses are spread over ' .. n_fire_fixtures .. ' fixtures -- the '
    .. 'ceiling argument in this header is about a single-fixture corpus')

ok('every firing still comes from the SOFT midline read',
    C.oc_fire_building == 0 and C.oc_fire_midline == C.oc_fires,
    'fire_building=' .. tostring(C.oc_fire_building)
    .. ' fire_midline=' .. tostring(C.oc_fire_midline)
    .. ' fires=' .. tostring(C.oc_fires))

----------------------------------------------------------------------
-- §6  Narrowings (1) and (2) are blind, and that is shown on a real frame
--     rather than read off the mock's own comments. This is the half that
--     justifies GH #786 instead of merely asserting it.
----------------------------------------------------------------------

do
    local rf = require('mock.replay_fixture')
    local f = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'
    local J = rf.load(f, 'npc_dota_hero_lina')
    local bot = GetBot()
    local tE = J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) or {}
    ok('the witness frame still carries an enemy in collapse range', #tE >= 1,
        f .. ' no longer has an enemy within the collapse radius')

    if #tE >= 1 then
        local e = tE[1]
        local v = e:GetVelocity()
        local moving = type(v) == 'table'
            and ((v.x or 0) ~= 0 or (v.y or 0) ~= 0)
        ok('(1) is blind: the frame reports the chaser as standing still',
            not moving,
            'GetVelocity now answers a real velocity on this frame -- the '
            .. "dumper has grown the field, GH #760's proposal (a) is newly "
            .. 'measurable, and GH #786 is satisfied. Re-price leg (b).')

        ok('(2) is blind: no anim activity, so J.IsChasingTarget cannot answer',
            not J.IsChasingTarget(e, bot),
            'J.IsChasingTarget now answers true on a frame whose dump carries '
            .. 'no facing or anim activity -- check what it is reading')
    end
end

----------------------------------------------------------------------
-- §7  The source registration must stay attached to the finding.
----------------------------------------------------------------------

do
    local fh = assert(io.open(JMZ, 'r'), JMZ .. ' is not readable')
    local src = fh:read('*a')
    fh:close()
    -- ⚠️ The anchor must name #760. `REGISTERED, NOT REPAIRED` alone appears
    -- TWICE in this file (the tpdeftower registration from the same day uses
    -- the same phrase), so a bare search for it would be satisfied by the OTHER
    -- comment and this assertion would pass with leg (a)'s note deleted --
    -- caught by mutation stand M6.
    ok('leg (a) carries the GH #760 registration',
        src:find('GH #760] REGISTERED, NOT REPAIRED', 1, true) ~= nil,
        'the registration comment is gone from ' .. JMZ
        .. ' -- if the lever landed, delete this file too')
    ok('the registration names the blocking issue', src:find('GH #786', 1, true) ~= nil,
        'the comment no longer points at the dumper-extension issue, so a '
        .. 'reader cannot find out why this is blocked rather than ignored')
end

-- ⭐ THE REPORTING CHANNEL, ASSERTED RATHER THAN ASSUMED. §6 loaded a fixture,
-- so tests/mock/bot_api.lua has by now blanked the GLOBAL print. Two things
-- follow and both are checked, because the failure they guard against cannot
-- raise an exit code -- a FAIL line swallowed by a no-op print is swallowed
-- together with its effect on nothing but the reader's eyes:
--   * the global print really is blanked (so binding `say` was necessary, not
--     superstition -- if this ever stops being true, delete the ceremony), and
--   * `say` is NOT that blanked global.
local blanked = false
do
    -- A blanked print is a function that returns nothing and writes nothing; the
    -- only portable probe is identity against the captured original.
    blanked = (print ~= say)
end
ok('the global print really was blanked by the mock (so `say` is load bearing)',
    blanked,
    'the global print survived the fixture load -- tests/mock/bot_api.lua no '
    .. 'longer blanks it, so the `say` indirection is now dead ceremony and '
    .. 'this file should drop it')

say(string.format("\n%d passed, %d failed", pass, fail))
-- The completion marker. A reporting channel that has gone silent takes the
-- ok/FAIL lines with it and CANNOT change the exit code, so "did this file
-- report at all" has to be answerable from the outside.
-- tools/agent/mutstand_overchase_tense.sh M5 scores on the ABSENCE of this line.
say('OVERCHASE-TENSE-REPORT-COMPLETE')
os.exit(fail == 0 and 0 or 1)

-- [ratchet] [midsupmirror 2026-09-04, 协同组] test_set.md §EF.7 registered four
-- mirror members as "askable and not asked" and handed them to the next round as
-- four equal follow-ups, one lever at a time. This file prices them, and the
-- answer is that the sort key was wrong.
--
-- ⭐ THE FINDING (reusable, larger than this subject). §EF.7 sorted the four on
-- ASKABLE BY THE ENGINE. The axis that decides whether this group may LAND one
-- is a different axis -- CHECKABLE ON THE CORPUS -- because our own change rule
-- is "a behaviour change ships with a real-frame fixture; gate plumbing is not
-- local validation" (AGENTS.md / charter step 2). On the askability axis the
-- four sort 4-and-0. On the checkability axis they sort 0-and-4: not one of them
-- can be witnessed on a single frame of the 109-fixture corpus, so landing any
-- one of them today means shipping a conjunct whose only evidence is that it
-- compiles.
--
-- And they are unwitnessable for TWO different reasons, which is why "four
-- equals" was the wrong shape:
--   * BY ABSENCE (three legs).  J.IsGoingOnSomeone reads bot:GetActiveMode(),
--     which is bot-VM state the dumper does not carry: the mock default answers
--     on 1012/1012 live frames, so the leg is vacuously true everywhere. The 15s
--     fresh-respawn window and the 45s bRepeatFront memory read per-bot session
--     memory (lastDeadFrameTime / lastRespawnTime / lastFrontAnswerT) written by
--     the mode scripts ACROSS frames; a one-frame fixture carries no history, so
--     both fields are nil on 1012/1012.
--   * BY RAISE (one leg).  J.CanEnemyInterruptTpChannel extrapolates each nearby
--     enemy (GetExtrapolatedLocation(0.5)), which the fixture mock does not stub;
--     it answers a number, and J.GetLocationToLocationDistance indexes it. On the
--     257/1012 frames where the guard is inside its own domain -- an enemy hero
--     within its scan radius -- it raises 257/257, one single cause. Its 755
--     `false` answers are all the #enemies==0 early return, i.e. the guard
--     abstaining. On this entire corpus the guard has answered its own question
--     ZERO times.
--
-- ⭐⭐ AND THAT LEG CENSORED THE PREVIOUS ROUND'S PUBLISHED DOMAIN.
-- tests/_midsupfar_sweep.lua reads the trigger through `pcall` and has two
-- buckets for a three-valued read, so a RAISE is counted as "did not fire".
-- 75/1012 live frames raise inside J.ShouldTpSupportTowerFight, every one of
-- them with the same signature. §EF.1's "1012 live frames => the helper fires 8"
-- was therefore taken over 937 frames with 75 excluded BY THE INSTRUMENT, and
-- the exclusion is not random: the excluded frames are exactly the ones with an
-- enemy hero in the bot's face, which is a fight -- the very condition the
-- helper exists to answer. 8 is a floor, not a count.
--
-- ⇒ NOTHING IS REPAIRED HERE, deliberately. The blocker is one missing mock
-- method, and stubbing it is a harness-wide change: it moves readings for every
-- helper that extrapolates, and tests/test_itemdesire_world_assertion.lua
-- already pins `type(other:GetExtrapolatedLocation(0.5)) ~= 'table'` with a
-- count of 178 resting on it. That decision belongs to the director, not to this
-- group. This file is the ratchet that makes the day it changes visible.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_midsupmirror_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- The one frame in the whole corpus where a core reaches the yield and the
-- shipped predicate accepts a support: the decision domain, n=1 after the
-- pairing repair. All four legs are silent about that support.
local DOMAIN = 'f_260819_182855_lion_drain_midchannel'
local DSUBJ = 'npc_dota_hero_death_prophet'
-- A frame the instrument cannot read at all: the trigger raises before it can
-- answer. It is also the frame tests/test_replay_071423_luna_chase.lua is built
-- on, so "the corpus has no such frame" is not available as an explanation.
local CENSORED = 'tests/fixtures/f_071423_luna_chase.lua'
local CSUBJ = 'npc_dota_hero_luna'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, dom = {}, censored = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local xf, xh = line:match('^X (%S+) (%S+)$')
        if xf ~= nil then m.censored[#m.censored + 1] = { fixture = xf, hero = xh } end
        local df, dc, ds, dm, di, dr, dfr =
            line:match('^D (%S+) (%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$')
        if df ~= nil then
            m.dom[#m.dom + 1] = { fixture = df, core = dc, support = ds,
                mode = dm, interrupt = di, respawn = dr, front = dfr }
        end
        if line == 'DONE' then m.done = true end
    end
    return m
end)()

local function C(key)
    local n = M.c[key]
    assert(n ~= nil, 'the sweep did not emit counter ' .. key
        .. ' -- an absent counter is not a zero')
    return n
end

tests['[sweep] the subprocess ran to completion'] = function()
    assert(M.done, 'tests/_midsupmirror_sweep.lua did not print DONE -- every '
        .. 'count below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
end

tests['[instrument] the census agrees with the shipped predicate'] = function()
    -- The sweep re-runs the mirror's member list as a shadow so each accepted
    -- support can be named. A shadow can drift from the tree, and then the
    -- census measures only itself, so every core frame also re-asks the SHIPPED
    -- predicate over the REAL team and the two must agree.
    assert(C('shipped_disagrees') == 0, C('shipped_disagrees')
        .. ' core frame(s) where the shadow and J.HasAvailableSupportResponder '
        .. 'disagree -- this census is not measuring the shipped tree')
    -- ...and the shadow reproduces the other census's headline, independently.
    cs.ratchet(C('fires'), 8, 'frames where the trigger returns a tower')
    cs.ratchet(C('fires_core'), 3, 'core frames among them')
    cs.ratchet(C('sup_accepted'), 1, 'supports the shipped predicate accepts')
end

-- ------------------------------------------- the tree, read as source ------

tests['[source] the loop applies all four legs and the mirror still applies none'] = function()
    -- Restated here as parsed facts rather than prose so that repairing one --
    -- the whole point of §EF.7 -- turns THIS file red too, and whoever does it
    -- has to re-read the pricing below before re-baselining.
    assert(M.g.LOOP == 1 and M.g.MIRROR == 1,
        'the sweep could not slice one of the two functions out of ' .. JMZ)
    local short = 0
    for _, leg in ipairs({ 'IsGoingOnSomeone', 'CanEnemyInterruptTpChannel',
        'lastRespawnTime', 'lastFrontAnswerT' }) do
        assert(M.g['LOOP_' .. leg] == 1,
            'the responder loop no longer applies ' .. leg
            .. ' to itself -- the mirror is no longer short it either, re-read')
        if M.g['MIRROR_' .. leg] == 0 then short = short + 1 end
    end
    assert(short == 4, 'registered 4 support-only mirror members still absent '
        .. 'from J.HasAvailableSupportResponder, found ' .. short
        .. ' -- if one was repaired, say so in the report, lower this number, '
        .. 'and lower the twin in tests/test_midsupfar_yield_target.lua')
end

-- -------------------------------- unwitnessable BY ABSENCE (three legs) ----

tests['[census] the active-mode leg is vacuous on every corpus frame'] = function()
    -- J.IsGoingOnSomeone is bot:GetActiveMode() compared against five modes.
    -- GetActiveMode is bot-VM state, not world state, so the dumper carries none
    -- of it (the standing statement of this is tests/test_activemode_world_assertion.lua).
    assert(C('mode_readable') == C('live'),
        'GetActiveMode stopped answering on some frames -- re-read this pricing')
    assert(C('mode_nondefault') == 0, C('mode_nondefault') .. ' frame(s) now carry '
        .. 'a real active mode. The corpus can now witness the IsGoingOnSomeone '
        .. 'leg: PRICE IT AGAIN, it may have become landable')
    assert(C('mode_default') == C('live'), 'mode_default must cover every live frame')
    assert(C('mode_would_veto') == 0, C('mode_would_veto') .. ' frame(s) where '
        .. 'J.IsGoingOnSomeone answers true -- that is a fixture the repair could '
        .. 'be validated on; this leg is no longer unwitnessable')
end

tests['[census] the two session-memory legs are vacuous on every corpus frame'] = function()
    -- lastDeadFrameTime / lastRespawnTime are written by mode_retreat_generic
    -- across frames; lastFrontAnswerT is written by the trigger itself when it
    -- answers a front. A single-frame fixture is by construction a world with no
    -- history, so neither the 15s respawn window nor the 45s repeat-front memory
    -- has anything to read.
    assert(M.g.FRESH_RESPAWN_S == 15, 'the fresh-respawn window moved to '
        .. tostring(M.g.FRESH_RESPAWN_S) .. 's -- re-read the pricing')
    assert(M.g.REPEAT_FRONT_S == 45, 'the repeat-front memory moved to '
        .. tostring(M.g.REPEAT_FRONT_S) .. 's -- re-read the pricing')
    assert(C('respawn_field') == 0, C('respawn_field') .. ' frame(s) now carry '
        .. 'respawn history -- the 15s leg became witnessable, price it again')
    assert(C('front_field') == 0, C('front_field') .. ' frame(s) now carry a '
        .. 'lastFrontAnswerT -- the 45s leg became witnessable, price it again')
end

-- ------------------------------------ unwitnessable BY RAISE (one leg) -----

tests['[census] the interrupt guard has never answered its own question'] = function()
    -- Its domain is "an enemy hero inside the narrow scan"; outside it the
    -- helper early-returns false, and that false is the guard ABSTAINING, not
    -- the guard answering. Counting those 755 abstentions as answers is how a
    -- guard that never runs reads as a guard that never fires.
    assert(M.g.INT_R == 700, 'the narrow interrupt scan moved to '
        .. tostring(M.g.INT_R) .. ' -- re-read this pricing')
    assert(C('int_true') == 0, C('int_true') .. ' frame(s) where '
        .. 'J.CanEnemyInterruptTpChannel answers TRUE. It has an answer on this '
        .. 'corpus now: the leg became witnessable, price it again')
    assert(C('int_in_domain') > 0, 'no corpus frame puts an enemy inside the '
        .. 'interrupt scan -- then the raise below is untestable, re-read')
    cs.ratchet(C('int_in_domain'), 257, 'frames inside the interrupt guard domain')
    assert(C('int_in_domain_raised') == C('int_in_domain'),
        string.format('%d of %d in-domain frames raise; registered ALL of them. '
            .. 'If some now answer, the mock gained extrapolation: re-price '
            .. 'this leg and re-read the censoring finding below',
            C('int_in_domain_raised'), C('int_in_domain')))
    assert(C('int_raised') == C('int_in_domain'), 'the guard raised on a frame '
        .. 'OUTSIDE its own domain -- a second cause exists, find it')
    assert(C('int_raised_sloc') == C('int_raised'), 'the raises no longer share '
        .. 'one signature -- one mock repair will not unblock them all')
    assert(C('int_false') + C('int_raised') == C('live'),
        'the three buckets must partition the live frames')
end

tests['[premise] the raise is the missing mock method, not a bug in the guard'] = function()
    -- Driven, not argued: the guard is fed a real frame and the cause is read
    -- off the failure. The nil-guard lesson from the last round -- an assertion
    -- that passes for the wrong reason is not an assertion -- applies here, so
    -- this drives the exact call the guard makes rather than asserting a string.
    local J, bot = rf.load(CENSORED, CSUBJ)
    J.IsSoakCandidate = function() return false end
    local near = J.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
    assert(near ~= nil and #near > 0, CSUBJ .. ' on ' .. CENSORED
        .. ' has no enemy inside the scan -- this frame no longer exercises the guard')
    -- The engine call the guard makes, on a real enemy handle from a real frame.
    local extrap = near[1]:GetExtrapolatedLocation(0.5)
    assert(type(extrap) ~= 'table', 'GetExtrapolatedLocation now answers a '
        .. 'location. The whole finding in this file is re-openable: re-run the '
        .. 'sweep, re-price all four legs, and re-take the 8-fires domain in '
        .. 'test_set.md §EF.1')
    -- ...and that is exactly what J.GetLocationToLocationDistance indexes.
    local okd = pcall(J.GetLocationToLocationDistance, bot:GetLocation(), extrap)
    assert(not okd, 'the distance read survived a non-location -- then the raise '
        .. 'has some other cause and this premise is wrong')
    local okg, err = pcall(J.CanEnemyInterruptTpChannel, bot)
    assert(not okg, 'the guard no longer raises on this frame -- re-price')
    assert(tostring(err):find("index local 'sLoc'", 1, true) ~= nil,
        'the guard raises for a different reason now: ' .. tostring(err))
    -- The guard really is reached through extrapolation in the shipped tree.
    local src = read_file(JMZ)
    assert(src:find('GetExtrapolatedLocation( 0.5 )', 1, true) ~= nil,
        'the guard stopped extrapolating -- this whole premise is stale')
end

-- ------------------------------- what that leg did to the published domain --

tests['[census] the previous domain read was censored by that same raise'] = function()
    -- tests/_midsupfar_sweep.lua wraps the trigger in pcall and has two buckets
    -- for a three-valued read, so "raised" lands in "did not fire".
    cs.ratchet(C('trigger_raised'), 75, 'live frames where the trigger RAISES')
    assert(C('trigger_raised_sloc') == C('trigger_raised'),
        'the trigger raises for more than one reason now -- re-read')
    assert(C('trigger_raised') > C('fires'), 'the censored set (' 
        .. C('trigger_raised') .. ') is no longer larger than the measured one ('
        .. C('fires') .. ') -- the finding is weaker than registered, re-read it')
    assert(#M.censored == C('trigger_raised'),
        'every censored frame must be named, got ' .. #M.censored)
    -- The censoring is not random with respect to the question: a frame is
    -- censored because an enemy is in the bot's face, which is what a fight is.
    local J, bot = rf.load(CENSORED, CSUBJ)
    J.IsSoakCandidate = function(id) return id == 'midtp' end
    local ok = pcall(J.ShouldTpSupportTowerFight, bot)
    assert(not ok, 'the trigger no longer raises on the registered censored '
        .. 'frame -- re-take the census')
    -- and the two-bucket reading of that same frame calls it a clean "no".
    local okq, res = pcall(J.ShouldTpSupportTowerFight, bot)
    assert((okq and res ~= nil) == false, 'a pcall-with-two-buckets reader scores '
        .. 'this frame identically to a frame that was measured and said no -- '
        .. 'that is the censoring, stated as the reader sees it')
end

-- --------------------------------------------------- the decision domain ---

tests['[census] all four legs are silent about the one support in the domain'] = function()
    -- After the pairing repair the yield's domain is a single accepted support
    -- on a single frame. Even there, not one of the four registered legs has
    -- anything to say about it -- so even a fixture written by hand on this
    -- exact frame could not distinguish the repaired mirror from the current one.
    assert(#M.dom >= 1, 'no accepted support in the whole corpus -- the decision '
        .. 'domain vanished, re-read before trusting anything above')
    local seen = false
    for _, d in ipairs(M.dom) do
        if d.fixture == DOMAIN and d.core == DSUBJ then
            seen = true
            assert(d.mode == '0', 'the accepted support now carries a real active '
                .. 'mode (' .. d.mode .. ') -- the IsGoingOnSomeone leg is '
                .. 'witnessable ON THE DECISION FRAME; price it again')
            assert(d.interrupt == 'false', 'the interrupt guard now says '
                .. d.interrupt .. ' about the accepted support -- price it again')
            assert(d.respawn == 'nil' and d.front == 'nil',
                'the accepted support now carries session memory -- price again')
        end
    end
    assert(seen, 'the registered decision frame ' .. DOMAIN .. ' no longer '
        .. 'produces an accepted support -- re-read the pricing')
    assert(C('sup_int_true') == 0 and C('sup_int_raised') == 0,
        'the interrupt guard changed its answer about an accepted support')
end

tests['[ratchet] not one of the four is landable under this group rule today'] = function()
    -- The conclusion, as one number. Charter step 2: a behaviour change ships
    -- with a real-frame fixture, and gate plumbing is not local validation. A
    -- leg that no corpus frame can make speak has no such fixture available, so
    -- landing it would be a conjunct validated by the fact that it compiles.
    -- The day ANY of these stops being zero, one of the four became landable and
    -- this test is the thing that says so.
    local witnessable = 0
    if C('mode_would_veto') > 0 then witnessable = witnessable + 1 end
    if C('int_true') > 0 then witnessable = witnessable + 1 end
    if C('respawn_field') > 0 then witnessable = witnessable + 1 end
    if C('front_field') > 0 then witnessable = witnessable + 1 end
    assert(witnessable == 0, witnessable .. ' of the four §EF.7 legs can now be '
        .. 'witnessed on a corpus frame -- that leg is landable, take it')
end

return tests

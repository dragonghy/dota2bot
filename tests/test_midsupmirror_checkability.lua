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

tests['[source] the loop applies all four legs and the mirror now applies one'] = function()
    -- Restated here as parsed facts rather than prose so that repairing one --
    -- the whole point of §EF.7 -- turns THIS file red too, and whoever does it
    -- has to re-read the pricing below before re-baselining.
    --
    -- ⭐ 2026-09-05 (协同组, GH #503): IT DID, AND THAT IS THE HANDOFF WORKING.
    -- This assertion went red the moment the interrupt member landed, which is
    -- the behaviour it was written for: the count is lowered 4 -> 3 deliberately
    -- and with a report (test_set.md §EN,
    -- tests/test_midsupint_mirror_interrupt.lua), not drifted.
    assert(M.g.LOOP == 1 and M.g.MIRROR == 1,
        'the sweep could not slice one of the two functions out of ' .. JMZ)
    local short, repaired = 0, {}
    for _, leg in ipairs({ 'IsGoingOnSomeone', 'CanEnemyInterruptTpChannel',
        'lastRespawnTime', 'lastFrontAnswerT' }) do
        assert(M.g['LOOP_' .. leg] == 1,
            'the responder loop no longer applies ' .. leg
            .. ' to itself -- the mirror is no longer short it either, re-read')
        if M.g['MIRROR_' .. leg] == 0 then short = short + 1
        else repaired[#repaired + 1] = leg end
    end
    assert(short == 3, 'registered 3 support-only mirror members still absent '
        .. 'from J.HasAvailableSupportResponder, found ' .. short
        .. ' -- if one was repaired, say so in the report, lower this number, '
        .. 'and lower the twin in tests/test_midsupfar_yield_target.lua')
    -- ...and it is the one the corpus can witness that got repaired. Landing an
    -- unwitnessable leg instead would satisfy the count above while breaking the
    -- rule the count exists to protect (charter step 2: a behaviour change ships
    -- with a real-frame fixture), so the count alone is not the check.
    assert(#repaired == 1 and repaired[1] == 'CanEnemyInterruptTpChannel',
        'the repaired mirror member is {' .. table.concat(repaired, ',')
        .. '}, expected exactly {CanEnemyInterruptTpChannel} -- the other three '
        .. 'legs are priced UNWITNESSABLE below, so landing one of them means a '
        .. 'conjunct whose only evidence is that it compiles')
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

tests['[census] the interrupt guard now answers on every in-domain frame'] = function()
    -- ⭐ RE-PRICED 2026-09-05 (director, GH #492). This leg used to be titled
    -- "has never answered its own question" and it was true: 257 of 257
    -- in-domain frames RAISED, because the fixture mock did not stub
    -- GetExtrapolatedLocation and the guard indexed the catch-all 0 as a
    -- location. The mock was repaired on this commit. Same corpus, same tree,
    -- the mock the only difference:
    --     int_in_domain         257  ->  257   (unchanged, as it must be)
    --     int_in_domain_raised  257  ->    0
    --     int_true                0  ->   73
    --     int_false             755  ->  939   (755 abstentions + 184 in-domain no)
    -- So a SHIPPED, UNGATED guard -- `tpsafe2` was promoted to a turbo default
    -- on 2026-07-23 -- that had never once executed on a real frame now answers
    -- on all 257, and says "do not start this TP" on 73 of the 1012 live frames.
    --
    -- ⚠️ WHAT THE 73 IS AND IS NOT. It is the `nNow <= nReach` clause only:
    -- "an enemy can strike me where I stand". The repaired mock models every
    -- unit as standing still (a fixture is one instant and carries no
    -- velocity), so nSoon == nNow and the second clause -- "it is closing the
    -- gap on me" -- is unreachable here. 73 is therefore a LOWER BOUND on
    -- interruption. That model is declared in tests/mock/replay_fixture.lua and
    -- measured in tests/test_fixture_extrapolation_mock.lua, so it goes red
    -- rather than quiet on the day a fixture carries motion.
    assert(M.g.INT_R == 700, 'the narrow interrupt scan moved to '
        .. tostring(M.g.INT_R) .. ' -- re-read this pricing')
    assert(C('int_in_domain') > 0, 'no corpus frame puts an enemy inside the '
        .. 'interrupt scan -- then this whole leg is untestable, re-read')
    cs.ratchet(C('int_in_domain'), 257, 'frames inside the interrupt guard domain')
    -- The repair, stated as the assertion that would catch its loss. A raise
    -- reappearing here is the censoring coming back, and the two-bucket readers
    -- downstream would score it as a measured "no" again without saying so.
    assert(C('int_raised') == 0, C('int_raised') .. ' in-domain frame(s) raise '
        .. 'again. The mock lost GetExtrapolatedLocation (or a second unstubbed '
        .. 'name appeared on this road): the censoring GH #492 closed is back, '
        .. 'and every domain count below is being taken on a truncated corpus')
    assert(C('int_in_domain_raised') == 0, 'in-domain raises reappeared')
    -- A guard that is reached must decide, and both answers must occur: an
    -- all-true or all-false column would mean the corpus stopped discriminating
    -- and the number below had become a constant, not a reading.
    assert(C('int_true') > 0 and C('int_true') < C('int_in_domain'),
        'the guard answers the SAME thing on all ' .. C('int_in_domain')
        .. ' in-domain frames (' .. C('int_true') .. ' true) -- it is no longer '
        .. 'discriminating between frames, re-read before trusting it')
    cs.ratchet(C('int_true'), 73, 'frames where the guard says do-not-TP')
    assert(C('int_false') + C('int_raised') + C('int_true') == C('live'),
        'the three buckets must partition the live frames: '
        .. C('int_false') .. ' + ' .. C('int_raised') .. ' + ' .. C('int_true')
        .. ' vs ' .. C('live'))
end

tests['[premise] the raise was the missing mock method, and it is gone'] = function()
    -- Driven, not argued: the guard is fed a real frame and the cause is read
    -- off the failure. The nil-guard lesson from the last round -- an assertion
    -- that passes for the wrong reason is not an assertion -- applies here, so
    -- this drives the exact call the guard makes rather than asserting a string.
    local J, bot = rf.load(CENSORED, CSUBJ)
    J.IsSoakCandidate = function() return false end
    local near = J.GetNearbyHeroes(bot, 700, true, BOT_MODE_NONE)
    assert(near ~= nil and #near > 0, CSUBJ .. ' on ' .. CENSORED
        .. ' has no enemy inside the scan -- this frame no longer exercises the guard')
    -- ⭐ RE-PRICED 2026-09-05 (director, GH #492). The original premise was
    -- proved by DRIVING the failure: the mock answered a scalar, the distance
    -- helper indexed it, and the guard raised with `index local 'sLoc'`. That
    -- diagnosis was correct, and the repair it justified has landed. The
    -- assertions are inverted rather than deleted, because the thing worth
    -- keeping is not "it raises" but "the cause of the raise was THIS name" --
    -- which is now checked by showing the raise disappears when, and only when,
    -- the name answers a location.
    local extrap = near[1]:GetExtrapolatedLocation(0.5)
    assert(type(extrap) == 'table' and type(extrap.x) == 'number',
        'GetExtrapolatedLocation answers a ' .. type(extrap) .. ' again -- the '
        .. 'mock repair was lost, and with it every count in this file')
    -- The consumer that used to be handed the scalar now completes.
    local okd, d = pcall(J.GetLocationToLocationDistance, bot:GetLocation(), extrap)
    assert(okd and type(d) == 'number', 'the distance read still fails on the '
        .. 'repaired answer -- the mock returns a table that is not a location')
    local okg, ans = pcall(J.CanEnemyInterruptTpChannel, bot)
    assert(okg, 'the guard still raises on this frame: ' .. tostring(ans))
    assert(ans == true, 'the guard answers ' .. tostring(ans) .. ' on the frame '
        .. 'where luna is being hit at melee range -- the first clause is not '
        .. 'doing the work the 73 rests on; re-read before trusting it')
    -- ...and the SECOND clause still cannot be witnessed, which is the standing
    -- limit of the repair, not a leftover of the defect. Same frame, driven.
    local nNow  = J.GetLocationToLocationDistance(bot:GetLocation(),
                      near[1]:GetLocation())
    assert(d == nNow, 'the extrapolated distance moved away from the current '
        .. 'one -- the mock started extrapolating for real, so the 73 is no '
        .. 'longer a lower bound taken under standing-still; re-take it')
    -- The guard really is reached through extrapolation in the shipped tree.
    local src = read_file(JMZ)
    assert(src:find('GetExtrapolatedLocation( 0.5 )', 1, true) ~= nil,
        'the guard stopped extrapolating -- this whole premise is stale')
end

-- ------------------------------- what that leg did to the published domain --

tests['[census] the censoring is gone, and here is what it had been hiding'] = function()
    -- ⭐ RE-PRICED 2026-09-05 (director, GH #492). This leg registered the
    -- censoring: tests/_midsupfar_sweep.lua reads the trigger through pcall
    -- with two buckets for a three-valued read, so a RAISE landed in "did not
    -- fire", and 75 of the 1012 live frames raised inside
    -- J.ShouldTpSupportTowerFight -- the enemy-in-my-face frames, which is not
    -- independent of the question that helper answers.
    --
    -- ⭐⭐ THE ANSWER, now that those 75 frames were actually driven (same
    -- corpus, same tree, the mock the only difference):
    --     trigger_raised   75  ->  0
    --     fires             8  ->  9      (published as §EF.1's headline)
    --     fires_core        3  ->  3
    --     yield_domain      2  ->  2      and core_no_support / yield_all_near /
    --                                     yield_some_far / sup_near / sup_far
    --                                     all 1 -> 1, byte-identical
    -- So the censored set bought back exactly ONE firing frame, and it is not a
    -- core frame: every number the 'midsupyield' arbitration rests on is
    -- unmoved. That is worth saying precisely because it is the boring outcome
    -- -- the finding was that the instrument COULD NOT SEE those frames, and
    -- that was true and worth fixing whichever way the count fell. A censored
    -- reading that happens to equal the honest one is still a censored reading;
    -- it just cannot be known to be equal until someone drives it.
    assert(C('trigger_raised') == 0, C('trigger_raised') .. ' live frame(s) '
        .. 'raise inside the trigger again -- the two-bucket reader is scoring '
        .. 'them as measured "no" once more; GH #492 is re-opened')
    assert(#M.censored == 0, #M.censored .. ' frame(s) still named as censored')
    assert(C('trigger_raised_sloc') == C('trigger_raised'),
        'the trigger raises for a reason that is not the extrapolation -- a '
        .. 'second unstubbed name is on this road, find it before re-baselining')
    -- The frame that WAS the standing example, driven: it now reaches an answer
    -- rather than raising, which is the whole content of the repair.
    local J, bot = rf.load(CENSORED, CSUBJ)
    J.IsSoakCandidate = function(id) return id == 'midtp' end
    local ok, res = pcall(J.ShouldTpSupportTowerFight, bot)
    assert(ok, 'the registered censored frame still raises: ' .. tostring(res))
    -- ...and a two-bucket reader can no longer confuse it with anything: it is
    -- a measured answer now, whatever that answer is.
    assert(res == nil or type(res) == 'table' or type(res) == 'boolean',
        'the trigger answered a ' .. type(res) .. ', which no caller expects')
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

tests['[ratchet] ONE of the four is LANDED now; the other three are not landable'] = function()
    -- The conclusion, as one number. Charter step 2: a behaviour change ships
    -- with a real-frame fixture, and gate plumbing is not local validation. A
    -- leg that no corpus frame can make speak has no such fixture available, so
    -- landing it would be a conjunct validated by the fact that it compiles.
    --
    -- ⭐ 2026-09-05 (director, GH #492): THIS TEST FIRED, AS DESIGNED, AND THAT
    -- IS THE DELIVERABLE. Repairing the mock moved the interrupt leg from
    -- unwitnessable to witnessable in one step -- int_true 0 -> 73 -- so
    -- J.HasAvailableSupportResponder's missing CanEnemyInterruptTpChannel
    -- member can now be landed with a real-frame fixture on any of those 73
    -- frames. Handed to the strategy stream (that member is theirs to write,
    -- not the director's); the other three legs are untouched and stay
    -- unlandable for the reasons priced above -- two are session memory a
    -- single-instant fixture cannot carry, one is bot-VM state the dumper does
    -- not dump. Note the asymmetry that makes this ratchet worth keeping: the
    -- repair that unblocked the leg was in the HARNESS, and nothing in the
    -- strategy stream's own backlog would have noticed the day it happened.
    --
    -- ⭐⭐ 2026-09-05 (协同组, GH #503): AND IT WAS LANDED, same day. The member
    -- is now in J.HasAvailableSupportResponder, validated on two real frames in
    -- tests/test_midsupint_mirror_interrupt.lua (test_set.md §EN); the corpus
    -- price of the conjunct is 151 flips over 7,048 (hero, tower) pairs, and it
    -- is not subsumed by the IsInTeamFight leg above it (20 rejected candidates,
    -- only 4 of them already blocked there). This test keeps its job unchanged:
    -- it is still the thing that fires if one of the OTHER three becomes
    -- witnessable, and it now also fails if the landed one is quietly reverted.
    local LANDABLE = { int_true = true }
    local witnessable, landable = {}, {}
    for _, k in ipairs({ 'mode_would_veto', 'int_true', 'respawn_field',
                         'front_field' }) do
        if C(k) > 0 then
            witnessable[#witnessable + 1] = k
            if LANDABLE[k] then landable[#landable + 1] = k end
        end
    end
    assert(#landable == #witnessable, 'a §EF.7 leg became witnessable that is '
        .. 'not yet registered as landable: ' .. table.concat(witnessable, ' ')
        .. ' -- price it and hand it to the strategy stream, do not just widen '
        .. 'this list')
    assert(C('int_true') > 0, 'the interrupt leg stopped being witnessable -- '
        .. 'the mock repair was lost; the registered landability above is stale')
    -- Landability is a claim about the corpus; LANDED is a claim about the tree,
    -- and the two are recorded separately on purpose. A revert that left this
    -- file passing would put the pricing above back to describing a tree that no
    -- longer exists -- which is exactly how §EF.7 came to read "four" for a day
    -- after the world had moved.
    assert(M.g.MIRROR_CanEnemyInterruptTpChannel == 1,
        'the interrupt member left J.HasAvailableSupportResponder again. It was '
        .. 'landed on 2026-09-05 (GH #503) with real-frame validation in '
        .. 'tests/test_midsupint_mirror_interrupt.lua; if the revert is '
        .. 'deliberate, say so in a report and re-raise the counts above')
end

return tests

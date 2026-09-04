-- [ratchet] [midsupfar 2026-09-04, 协同组] The 'midsupyield' arbitration handed
-- the team's single TP-response slot to a support it never asked could accept
-- it -- and its whole safety argument was that it does the opposite.
--
-- THE CLAIM UNDER TEST. J.HasAvailableSupportResponder documented itself as
-- mirroring, "member by member, the exact gates the support would itself have to
-- clear inside J.ShouldTpSupportTowerFight". On that mirror rests "this can only
-- REALLOCATE a response to a support, never DROP one" -- written in the source,
-- repeated in tests/test_midsupyield_core_yields.lua's header, and carried into
-- the director's conditional approval (iterations/state.json,
-- "AX.5_strategy5b_midsupyield": "Direction is bounded by construction (can only
-- REALLOCATE a tower-defense response from core to support, never drop one)").
--
-- ⭐ THE DEFECT (reusable, larger than this subject). Every clause of the mirror
-- is a property of the SUPPORT ALONE. The responder loop has one more that is a
-- property of the PAIRING: the responder must be farther than the far floor from
-- the very tower it answers. A predicate that takes no building argument cannot
-- ask that clause -- so the missing member is not one of five equals, it is the
-- only one that names WHAT IS BEING HANDED OVER, and the arbitration is exactly
-- a claim about the handover. A support standing AT the tower passes every other
-- clause and can take nothing.
--
-- ⭐⭐ AND IT BITES ON THE ID'S OWN POSITIVE CONTROL.
-- f_260820_042612_axe_blink_init_573 is the frame
-- tests/test_midsupyield_core_yields.lua uses to assert that armed YIELDS. Core
-- luna answers a tower 11,876 away; the one support the mirror accepts is a
-- pos-5 vengeful_spirit standing 655 from that tower -- 5.3x inside the 3,500
-- floor, i.e. already at the fight, with no response to make. That yield is a
-- DROP. The corpus sweep says the yield's whole domain is 2 frames, so this is
-- one of two, not a corner.
--
-- THE REPAIR is one conjunct inside the existing 'midsupyield' gate -- NO new
-- soak id, on purpose: `IsSoakCandidate('midsupyield') and
-- IsSoakCandidate('midsupfar')` would freeze FALSE the day either is promoted
-- (the pullcad lesson in AGENTS.md), and 'midsupyield' has never been armed in
-- any wave, so no wave's reading is invalidated by changing its body.
--
-- DIRECTION. A conjunct can only shrink the accepted set, so armed yields on
-- strictly fewer frames than before => strictly closer to shipped. The
-- load-bearing half of this file is therefore the POSITIVE CONTROL: the
-- death_prophet frame must STILL yield, or "fixed" would be satisfied by a
-- predicate that answers false everywhere.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_midsupfar_sweep.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- DROP: the id's own positive control. Armed used to yield here to a support
-- sitting on top of the tower; after the repair the core answers.
local DROP, DSUBJ = 'tests/fixtures/f_260820_042612_axe_blink_init_573.lua',
    'npc_dota_hero_luna'
-- REALLOC: a genuine hand-over -- the support is 15,832 from the tower, well
-- past the floor, so it really could TP in. Armed must STILL yield.
local REAL, RSUBJ = 'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua',
    'npc_dota_hero_death_prophet'
-- NODROP: a core with no support alternative at all; armed must fire.
local NODROP, NSUBJ = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua',
    'npc_dota_hero_storm_spirit'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- One evaluation on a real frame with `ids` armed. ALWAYS a fresh load:
--- J.TryTakeTpResponseSlot is a module-level ledger the trigger CONSUMES on
--- success, so a second call against the same world would answer the quota, not
--- the question under test.
local function run(path, subj, ids)
    local J, bot = rf.load(path, subj)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    return J, bot
end
local function fires(path, subj, ids)
    local J, bot = run(path, subj, ids)
    return J.ShouldTpSupportTowerFight(bot) ~= nil
end

-- ------------------------------------------------------------- the sweep --

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = {}, sup = {}, yield = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then m.g[k] = tonumber(v) or v end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local sf, sh, sa, sd, scls =
            line:match('^S (%S+) (%S+) (%S+) (%d+) (%S+)$')
        if sf ~= nil then
            m.sup[#m.sup + 1] = { fixture = sf, hero = sh, support = sa,
                dist = tonumber(sd), far = (scls == 'far') }
        end
        local yf, yh, yp, yd, yn, ynf, ynn, ysh =
            line:match('^Y (%S+) (%S+) (%d+) (%d+) (%d+) (%d+) (%d+) (%S+)$')
        if yf ~= nil then
            m.yield[#m.yield + 1] = { fixture = yf, hero = yh,
                pos = tonumber(yp), dist = tonumber(yd), n = tonumber(yn),
                far = tonumber(ynf), near = tonumber(ynn),
                shipped = (ysh == 'true') }
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
    assert(M.done, 'tests/_midsupfar_sweep.lua did not print DONE -- '
        .. 'every count below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
end

-- ------------------------------------------- the tree, read as source ------

tests['[source] the far floor is ONE constant, read by both sites'] = function()
    -- The defect this id repairs is a mirror that drifted out of sync with the
    -- responder loop. Two copies of 3500 are two things that can drift again,
    -- so the single-source property is asserted, not assumed.
    assert(M.g.PARSE == nil,
        'the sweep could not find J.ShouldTpSupportTowerFight: ' .. tostring(M.g.PARSE))
    assert(M.g.FAR_FLOOR == 3500,
        'the registered far floor is 3500, sweep read ' .. tostring(M.g.FAR_FLOOR))
    assert(M.g.LOOP_READS_CONST == 1,
        'the responder loop re-inlined a literal instead of reading '
        .. 'J.TP_RESPONSE_FAR_FLOOR -- the two sites can now drift apart again')
    local src = read_file(JMZ)
    assert(src:find('J.HasAvailableSupportResponder( bot, building )', 1, true) ~= nil,
        'the call site must hand the answered tower to the predicate')
    assert(src:find(
        'GetUnitToUnitDistance( hAlly, hBuilding ) > J.TP_RESPONSE_FAR_FLOOR',
        1, true) ~= nil, 'the pairing clause is gone from the predicate')
end

tests['[premise] the repair is inside midsupyield, NOT a second soak id'] = function()
    -- A gate written as `IsSoakCandidate('midsupyield') and
    -- IsSoakCandidate('midsupfar')` is frozen FALSE the day either id is
    -- promoted, because a promoted id is in no armed string (AGENTS.md, caught
    -- on pullcad). This asserts the shape was not introduced.
    local src = read_file(JMZ)
    assert(src:find("IsSoakCandidate( 'midsupfar' )", 1, true) == nil,
        "'midsupfar' must NOT be a soak id: the repair rides inside "
        .. "'midsupyield', which has never been armed in any wave")
end

-- ------------------------------------------------------- the census --------

tests['[census] the yield domain, and how much of it was a drop'] = function()
    -- The helper fires on few frames and the yield touches fewer; the finding is
    -- a RATIO over a small domain, so the domain is stated with it (rule 4 (ii):
    -- a small-valued count is reported with its distribution, not a median).
    assert(C('fires') >= 8, 'the helper fires on ' .. C('fires')
        .. ' corpus frames; registered 8')
    assert(C('fires_core') >= 3, 'core frames (the only ones midsupyield can '
        .. 'touch): ' .. C('fires_core') .. ', registered 3')
    cs.ratchet(C('yield_domain'), 2, 'frames where a core would yield')
    cs.ratchet(C('core_no_support'), 1, 'core frames with no support at all')
    -- THE FINDING: half of the yield domain handed the slot to a support that
    -- could not take it.
    cs.ratchet(C('yield_all_near'), 1, 'yields with NO viable-for-this-tower support')
    -- ...and the other half is a real hand-over, so the fix is not vacuous.
    cs.ratchet(C('yield_some_far'), 1, 'yields with a genuinely viable support')
    cs.ratchet(C('sup_near'), 1, 'accepted supports inside the far floor')
    cs.ratchet(C('sup_far'), 1, 'accepted supports beyond the far floor')
end

tests['[instrument] the census agrees with the shipped predicate on every frame'] = function()
    -- The sweep re-implements the PRE-midsupfar member list so each support can
    -- be named; that shadow could drift from the tree and the census would then
    -- be measuring itself. Every yield record therefore also re-asks the SHIPPED
    -- predicate and the two must agree. This column has already earned its keep:
    -- the first run after the constant refactor left the sweep's regex matching a
    -- literal that no longer existed, every support classified `near`, and this
    -- counter is what said so.
    assert(C('shipped_disagrees') == 0,
        C('shipped_disagrees') .. ' frame(s) where the sweep classifier and '
        .. 'J.HasAvailableSupportResponder disagree -- the census is not '
        .. 'measuring the shipped tree')
    assert(#M.yield >= 2, 'expected at least the two registered yield frames, got '
        .. #M.yield)
    for _, y in ipairs(M.yield) do
        assert(y.shipped == (y.far > 0), 'row disagreement on ' .. y.fixture)
    end
end

tests['[census] the drop frame is the one the id already calls its control'] = function()
    local seen = false
    for _, s in ipairs(M.sup) do
        if s.fixture == 'f_260820_042612_axe_blink_init_573'
            and s.support == 'npc_dota_hero_vengeful_spirit' then
            seen = true
            assert(not s.far, 'the yielded-to support must be INSIDE the floor')
            assert(s.dist < 700, 'registered 655 from the answered tower, got ' .. s.dist)
        end
    end
    assert(seen, 'the drop frame vanished from the sweep -- re-read the finding')
end

-- ---------------------------------------- the decision, on real frames -----

tests['[frame] DROP frame: the tower is far from the core and ON TOP of the support'] = function()
    local J, bot = run(DROP, DSUBJ, { 'midtp' })
    assert(J.IsModeTurbo(), 'the candidate family is turbo-only')
    assert(J.GetPosition(bot) == 1 and J.IsCore(bot),
        'subject luna must be a core, got pos ' .. tostring(J.GetPosition(bot)))
    local building = J.ShouldTpSupportTowerFight(bot)
    assert(building ~= nil, 'midtp alone must still answer this front')
    assert(GetUnitToUnitDistance(bot, building) > J.TP_RESPONSE_FAR_FLOOR,
        'the core is beyond the floor -- only a TP arrives in time')
    -- and the support the old mirror accepted is standing at that tower.
    local vs = nil
    for i = 1, #(GetTeamPlayers(GetTeam()) or {}) do
        local m = GetTeamMember(i)
        if m ~= nil and m:GetUnitName() == 'npc_dota_hero_vengeful_spirit' then vs = m end
    end
    assert(vs ~= nil, 'the pos-5 support must be on the roster')
    assert(J.GetPosition(vs) >= 4 and vs:IsAlive() and vs:GetLevel() >= 6,
        'it clears every clause of the mirror that is about the support alone')
    assert(GetUnitToUnitDistance(vs, building) < J.TP_RESPONSE_FAR_FLOOR,
        'and it is INSIDE the floor for the tower being handed over')
end

tests['[decision] DROP frame: armed no longer yields to a support that cannot take it'] = function()
    -- Before the repair this returned nil (the yield). The response was not
    -- reallocated to anyone -- vengeful_spirit is already standing at the tower.
    assert(fires(DROP, DSUBJ, { 'midtp', 'midsupyield' }) == true,
        'armed must ANSWER here: the only accepted support sits 655 from the '
        .. 'tower, 5.3x inside the floor, so yielding drops the response')
    local J, bot = run(DROP, DSUBJ, { 'midtp' })
    local building = J.ShouldTpSupportTowerFight(bot)
    local J2, bot2 = run(DROP, DSUBJ, { 'midtp' })
    assert(J2.HasAvailableSupportResponder(bot2, building) == false,
        'the repaired predicate must reject the near support')
end

tests['[decision, positive control] REALLOC frame: armed STILL yields'] = function()
    -- LOAD-BEARING. Without this, "no support can take it" would be satisfied by
    -- a predicate that answers false on every frame, and the id would be dead
    -- rather than repaired.
    local J, bot = run(REAL, RSUBJ, { 'midtp' })
    assert(J.IsCore(bot), 'subject must be a core for midsupyield to reach it')
    local building = J.ShouldTpSupportTowerFight(bot)
    assert(building ~= nil, 'midtp alone must answer this front')
    local dk = nil
    for i = 1, #(GetTeamPlayers(GetTeam()) or {}) do
        local m = GetTeamMember(i)
        if m ~= nil and m:GetUnitName() == 'npc_dota_hero_dragon_knight' then dk = m end
    end
    assert(dk ~= nil and GetUnitToUnitDistance(dk, building) > J.TP_RESPONSE_FAR_FLOOR,
        'the alternative responder is genuinely far from the tower')
    assert(fires(REAL, RSUBJ, { 'midtp', 'midsupyield' }) == false,
        'armed must still hand this response over -- the repair narrows the '
        .. 'yield, it does not delete it')
end

tests['[decision] NODROP frame: a core with no support alternative still fires'] = function()
    assert(fires(NODROP, NSUBJ, { 'midtp', 'midsupyield' }) == true,
        'with no support on the team the core is the only responder')
end

tests['[inert] midsupyield alone (midtp/suptp not armed) is a no-op'] = function()
    -- J.ShouldTpSupportTowerFight returns nil on its own gate line unless
    -- midtp/suptp is armed, so midsupyield can only ever remove a response an
    -- armed midtp/suptp made.
    assert(fires(DROP, DSUBJ, { 'midsupyield' }) == false, 'helper gate closed')
    assert(fires(REAL, RSUBJ, { 'midsupyield' }) == false, 'helper gate closed')
    assert(fires(DROP, DSUBJ, {}) == false, 'nothing armed = shipped behaviour')
end

tests['[premise] a caller that cannot name the tower fails TOWARD shipped'] = function()
    -- ⭐ THIS LEG WAS WRITTEN WRONG THE FIRST TIME AND THE MUTATION STAND SAID SO.
    -- The first version asserted only `... (bot, nil) == false`, and that passed
    -- with the guard DELETED (mutstand_midsupfar.sh M6 survived): with no guard
    -- the loop runs, GetUnitToUnitDistance(hAlly, nil) answers a garbage number
    -- under the mock, `garbage > 3500` is false, every support is rejected, and
    -- the predicate returns false. The right answer for the wrong reason -- and
    -- the wrong reason is one the ENGINE does not share, where a nil handle
    -- raises inside an error handler that swallows the text (AGENTS.md: no
    -- bot-side debugging). So the guard is driven, not just its return value:
    -- the distance reader is replaced by one that refuses a nil, and the guard
    -- is what must keep it from ever being called.
    local J, bot = run(DROP, DSUBJ, { 'midtp' })
    local real = GetUnitToUnitDistance
    GetUnitToUnitDistance = function(a, b)
        assert(a ~= nil and b ~= nil,
            'the predicate reached the distance read with a nil handle -- the '
            .. 'nil-building guard is gone; in the engine this raises where '
            .. 'nothing prints')
        return real(a, b)
    end
    local ok, res = pcall(J.HasAvailableSupportResponder, bot, nil)
    GetUnitToUnitDistance = real
    assert(ok, 'the nil-building call must not reach the distance read: ' .. tostring(res))
    assert(res == false,
        'a nil building must answer false -- no yield is the shipped answer, so '
        .. 'the unaskable case must fail toward shipped, not away from it')
    assert(J.HasAvailableSupportResponder(nil, nil) == false, 'nil bot, unchanged')

    -- and the guard is where it is claimed to be.
    local src = read_file(JMZ)
    assert(src:find('if hBuilding == nil then return false end', 1, true) ~= nil,
        'the nil-building guard is not in the tree')
end

-- ----------------------------------- registered, deliberately NOT repaired --

tests['[census] the mirror is still short four SUPPORT-ONLY members'] = function()
    -- One lever at a time (the lanefix lesson). The pairing clause is the one
    -- the predicate structurally COULD NOT ask; these four it could ask and does
    -- not. Each is a gate the responder loop applies to itself and the mirror
    -- omits, so each can still hand the slot to a support that would bail:
    --   J.IsGoingOnSomeone          (already committed to a gank)
    --   J.CanEnemyInterruptTpChannel(the channel would be broken)
    --   the 15s fresh-respawn window
    --   the 45s bRepeatFront memory  (answered this front already, went cold)
    -- Registered as a count so repairing one later is a DELIBERATE act and not
    -- drift. Raising this number without a report is the failure mode.
    local src = read_file(JMZ)
    local at = assert(src:find('function J.HasAvailableSupportResponder(', 1, true))
    local stop = assert(src:find('\nfunction J.', at + 10))
    local body = src:sub(at, stop)
    local missing = 0
    for _, name in ipairs({ 'IsGoingOnSomeone', 'CanEnemyInterruptTpChannel',
        'lastRespawnTime', 'lastFrontAnswerT' }) do
        if body:find(name, 1, true) == nil then missing = missing + 1 end
    end
    assert(missing == 4, 'registered 4 support-only mirror members still absent, '
        .. 'found ' .. missing .. ' -- if one was repaired, say so in the report '
        .. 'and lower this number; if one was ADDED to the loop, raise it')
end

return tests

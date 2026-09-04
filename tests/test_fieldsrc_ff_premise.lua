-- [ratchet] [owner priority P2] The PREMISE under J.HasFieldRegenSource: does
-- an accepted source prove the bot can drink it HERE?
--
-- The helper states its own contract in its header: it counts "only
-- consumables whose presence in the slot already proves they are usable". That
-- sentence is what makes the hold ids (stayfield / stayfield2) and the supply
-- id (fieldbuy) a partition worth having -- the hold keeps a bot in the field
-- BECAUSE there is something to drink, the buy resupplies BECAUSE there is not.
--
-- THE FINDING. For one of the four accepted legs the premise is FALSE, and the
-- shipped tree says so itself. The only code that can eat an item_faerie_fire
-- is X.ConsiderItemDesire["item_faerie_fire"], and its three branches are:
--   * 撤退 -- needs an ABSOLUTE health floor (OriginalGetHealth < 90);
--   * 攻击 -- needs J.IsGoingOnSomeone, HP < 0.3 and a valid botTarget;
--   * 自己吃 -- needs DotaTime() > 10*60 AND backpack slot 6 occupied.
-- On the 7 corpus frames where the field-regen situation holds and the ONLY
-- accepted source is a faerie fire, the 自己吃 branch is closed on 7/7 by BOTH
-- of its extra gates, and the 撤退 branch on 7/7 by the absolute floor. So the
-- presence test answers TRUE with an item this bot cannot eat for another four
-- minutes of a ~20-minute Turbo game -- and that TRUE is spent twice: it buys
-- the hold, and it tells fieldbuy the bot is already supplied.
--
-- ⭐ It bites on owner P2's OWN pinned frame. f_260822_063722_lina_tp_home,
-- t=349.0s: the faerie fire that justifies holding Lina in the field cannot be
-- eaten until t=600.
--
-- ⭐⭐ WHY NOTHING HAS SEEN IT. 'fieldsip' (the MAGNITUDE lever) releases all 7
-- of these frames -- 85 health is under a quarter of every bar in the corpus --
-- so with fieldsip armed the presence defect is invisible. That masking is
-- exact (7/7, asserted below) and it is a COINCIDENCE OF DIRECTION, not a fix:
-- fieldsip asks "is the sip big enough to stay for", this asks "can the sip be
-- taken at all". If fieldsip is rejected at the gate, the presence premise is
-- still broken and nothing else is looking at it.
--
-- WHAT THIS FILE IS NOT. There is no behaviour change here and no new soak id:
-- it is a premise purchase plus a guard, so that a future promote of
-- stayfield/stayfield2 without fieldsip cannot ship the broken premise quietly.
--
-- Honest bounds, stated first rather than buried:
--   * the 攻击 branch is NOT claimed closed. Its botTarget clause is
--     structurally nil on every fixture frame (GH #474), so on the 2 of 7
--     frames below HP 0.3 only two of its four conjuncts are measurable. The
--     conclusion therefore rests on 5 frames where all three branches are
--     provably closed, and the other 2 are registered as UNMEASURABLE.
--   * the two zeros are not blindness: the same two reads are exercised
--     elsewhere in this corpus (203 live frames carry an item in slot 6, 173
--     are past the 10-minute mark), and that is asserted, not assumed.
--   * the bottle leg can never answer TRUE on a fixture (the mock's
--     GetCurrentCharges default is 0), exactly as for J.HasFieldRegenSource.
--   * this says nothing about the tango leg. Its consumer needs a TREE, which
--     a fixture does not carry; that leg is left explicitly unmeasured rather
--     than assumed sound.
--
-- Mutation stand: tools/agent/mutstand_fieldsrc_ff.sh

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SWEEP = 'lua5.1 tests/_fieldsrc_ff_sweep.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

-- Owner P2's pinned frame.
local P2_FIX, P2_HERO = 'tests/fixtures/f_260822_063722_lina_tp_home.lua', 'npc_dota_hero_lina'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

-- ------------------------------------------------------------- the sweep --

local M = (function()
    local p = assert(io.popen(SWEEP, 'r'))
    local raw = p:read('*a')
    p:close()
    local m = { g = {}, c = setmetatable({}, { __index = function() return nil end }),
                rows = {}, done = false }
    for line in raw:gmatch('[^\n]+') do
        local k, v = line:match('^G (%S+) (%S+)$')
        if k ~= nil then
            m.g[k] = tonumber(v) or v
        end
        local ck, cv = line:match('^C (%S+) (%-?%d+)$')
        if ck ~= nil then m.c[ck] = tonumber(cv) end
        local fix, hero, hp, mx, hp4, t10, miss, df, sip =
            line:match('^FF (%S+) (%S+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%S+)$')
        if fix ~= nil then
            m.rows[#m.rows + 1] = { fixture = fix, hero = hero,
                health = tonumber(hp), maxhp = tonumber(mx),
                hp = tonumber(hp4) / 10000, t = tonumber(t10) / 10,
                missing = tonumber(miss), dist = tonumber(df),
                sip_enough = (sip == 'true') }
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
    assert(M.done, 'tests/_fieldsrc_ff_sweep.lua did not print DONE -- '
        .. 'every count below would be a partial sweep read as a finding')
    cs.corpus(C('fixtures'), 'fixture corpus')
    cs.ratchet(C('live'), 1012, 'live hero frames')
end

-- ------------------------------------------- the consumer, read as source --

tests['[source] the faerie-fire consumer still has the three branches this rests on'] = function()
    assert(M.g.PARSE == 'nil' or M.g.PARSE == nil,
        'the faerie-fire consider function could not be located in ' .. AIUG
        .. ' -- the census below measured nothing')
    assert(M.g.FOUNTAIN_FLOOR == 1800,
        'the function-wide fountain floor moved to ' .. tostring(M.g.FOUNTAIN_FLOOR))
    assert(M.g.RETREAT_HEALTH == 90,
        'the 撤退 branch absolute health floor moved to ' .. tostring(M.g.RETREAT_HEALTH))
    assert(M.g.ATTACK_HP == 0.3,
        'the 攻击 branch HP gate moved to ' .. tostring(M.g.ATTACK_HP))
    assert(M.g.SELF_TIME == 600,
        'the 自己吃 branch time gate moved to ' .. tostring(M.g.SELF_TIME) .. 's')
    assert(M.g.SELF_SLOT == 6 and M.g.SELF_SLOT_OP == 'occupied',
        'the 自己吃 branch slot gate is now slot ' .. tostring(M.g.SELF_SLOT)
        .. ' being ' .. tostring(M.g.SELF_SLOT_OP))
    assert(M.g.SELF_MISSING == 200,
        'the 自己吃 branch missing-health gate moved to ' .. tostring(M.g.SELF_MISSING))
end

tests['[source] the presence test still accepts the faerie fire it is being asked about'] = function()
    local src = read_file(JMZ)
    local at = src:find('function J.HasFieldRegenSource( bot )', 1, true)
    assert(at ~= nil, 'J.HasFieldRegenSource is gone -- this file is about its contract')
    local body = src:sub(at, at + 1400)
    assert(body:find("sName == 'item_faerie_fire'", 1, true) ~= nil,
        'the faerie-fire leg left J.HasFieldRegenSource -- if that is the FIX, '
        .. 'this file is the place that records why it was made')
    -- The contract sentence itself, quoted from the header. If it is rewritten,
    -- whoever rewrote it must decide what this census then measures.
    assert(src:find('already proves they are usable', 1, true) ~= nil,
        'the "presence proves usability" contract sentence is gone from '
        .. JMZ .. ' -- re-read this file before re-baselining it')
end

-- ----------------------------------------------------------- the census --

tests['[census] the sole-source population and its two closed gates'] = function()
    cs.ratchet(C('situation'), 57, 'field-regen situation frames')
    cs.ratchet(C('with_source'), 24, 'situation frames carrying an accepted source')
    cs.ratchet(C('ff_sole'), 7, 'situation frames whose ONLY source is a faerie fire')
    assert(C('IMPOSSIBLE_sole_without_source') == 0,
        'a frame classified sole-faerie-fire that the presence test rejects: the '
        .. 'two slot reads have drifted apart')
    -- The finding, as two zeros. Both stay equalities on purpose: a claim whose
    -- whole content is a zero must go red the moment the corpus grows a
    -- counter-example.
    assert(C('ff_sole_selftime_open') == 0,
        'a sole-faerie-fire frame is now past the 自己吃 time gate ('
        .. C('ff_sole_selftime_open') .. ') -- re-read the finding')
    assert(C('ff_sole_selfslot_open') == 0,
        'a sole-faerie-fire frame now satisfies the 自己吃 slot gate ('
        .. C('ff_sole_selfslot_open') .. ') -- re-read the finding')
    assert(C('ff_sole_eatable') == 0,
        C('ff_sole_eatable') .. ' sole-faerie-fire frame(s) can now eat the item '
        .. 'the presence test is holding them for -- this file exists because '
        .. 'that count was zero')
    assert(C('ff_sole_retreat_open') == 0,
        'the 撤退 branch absolute health floor is now satisfiable in this '
        .. 'population (' .. C('ff_sole_retreat_open') .. ')')
end

tests['[census] the zeros are measurements, not corpus blindness'] = function()
    -- If nothing in the corpus ever carried a backpack item, or nothing ever
    -- ran past ten minutes, the two zeros above would be vacuous.
    cs.ratchet(C('any_slot_occupied'), 203, 'live frames with slot 6 occupied')
    cs.ratchet(C('any_after_selftime'), 173, 'live frames past the 自己吃 time gate')
    cs.universal(C('ff_sole_far'), C('ff_sole'),
        'sole-faerie-fire frames past the function-wide fountain floor', 5)
    -- And the structural half of WHY: this family's own situation predicate
    -- lives almost entirely before the eat window opens.
    assert(C('src_after_selftime') <= 1 + (C('with_source') - 24),
        'the share of source-carrying frames past the 10-minute mark grew from '
        .. '1/24 -- the structural claim below needs re-measuring')
end

tests['[honest] the 攻击 branch is registered UNMEASURABLE, not closed'] = function()
    -- GH #474: J.GetProperTarget is nil on every fixture frame, so the branch's
    -- botTarget conjunct cannot be evaluated here. Two frames sit below its HP
    -- gate; the conclusion does not use them.
    local nUnmeasurable = C('ff_sole_attack_hp_open')
    assert(nUnmeasurable >= 2,
        'the count of frames where the 攻击 branch cannot be ruled out fell to '
        .. nUnmeasurable .. ' -- that would strengthen the finding, so re-derive '
        .. 'it deliberately rather than letting it drift')
    local nProven = C('ff_sole') - nUnmeasurable
    assert(nProven >= 5,
        'only ' .. nProven .. ' frames have all three branches provably closed '
        .. '(was 5) -- the conclusion rests on this number')
end

tests['[mask] fieldsip hides every one of these frames, and that is not a fix'] = function()
    cs.universal(C('ff_sole_sip_masked'), C('ff_sole'),
        'sole-faerie-fire frames that armed fieldsip already releases', 5)
    assert(C('ff_sole_sip_enough') == 0,
        C('ff_sole_sip_enough') .. ' sole-faerie-fire frame(s) now pass fieldsip '
        .. '-- on those the magnitude id STOPS masking the presence defect, '
        .. 'which is the case this file was written to make visible')
end

-- ------------------------------------------------------- the subject frame --

tests['[subject] owner P2 own frame is held on an item it cannot eat'] = function()
    local J, bot = rf.load(P2_FIX, P2_HERO)
    J.IsSoakCandidate = function() return false end

    assert(J.IsFieldRegenSituation(bot) == true, 'the situation holds on this frame')
    assert(J.HasFieldRegenSource(bot) == true, 'and the presence test says yes')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'so the core decision is STAY')

    -- What that yes is backed by, on this frame.
    local nFF = 0
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        if type(hItem) == 'table' and hItem:GetName() == 'item_faerie_fire' then
            nFF = nFF + 1
        end
    end
    assert(nFF == 1, 'the faerie fire is the source on this frame, found ' .. nFF)
    assert(type(bot:GetItemInSlot(6)) ~= 'table',
        'slot 6 is empty on this frame -- the 自己吃 branch slot gate is FALSE')
    assert(DotaTime() < 600,
        'this frame is at t=' .. DotaTime() .. ', before the 自己吃 time gate')
    -- The gap, in the unit that makes it legible: a Turbo game is ~20 minutes.
    assert(600 - DotaTime() > 200,
        'the wait to the eat window shrank below 200s -- re-derive the claim')

    -- And the same TRUE on the supply side: fieldbuy is told the bot is stocked.
    J.IsSoakCandidate = function(id) return id == 'fieldbuy' end
    assert(J.ShouldFieldBuyRegen(bot) == false,
        'armed fieldbuy does NOT buy here -- blocked by the same faerie fire')
end

return tests

-- [GH #259] The ability layer's SECOND ancient population: the sites that read
-- `nNeutralCreeps[1]` instead of asking a selector.
--
-- WHERE THE DENOMINATOR CAME FROM. 'abilanc' (GH #196) closed the selector
-- path -- `J.GetMostHpUnit` picks the ancient BY CONSTRUCTION -- and its
-- comment says in as many words that it "deliberately does not cover ... the
-- sites that read `list[1]`, so the next lever has a denominator". W17-R put
-- the first frames in that denominator: 3 below-tier casts at an ancient camp
-- over 18 games, 3 of 3 from this population, two of them the same waste shape
-- (cast twice, camp not taken, walk away).
--
--   (1) zuus L11, `88d937/20260827_151652_slot10` t=620.4: two Arc Lightnings
--       into an ancient camp (mana 1.00 -> 0.81), then turns around at 624.4
--       and walks back to lane. Source: hero_zuus.lua's farm branch, whose
--       SECOND disjunct -- "there is one creep and it is an ANCIENT" -- is
--       written as a reason to FIRE and carries no level clause at all.
--   (2) centaur L11, `88d937/20260827_151632_slot8` t=759.4: one Double Edge
--       (a SELF-damage nuke) into the granite/rock golems at 59% health, down
--       to 48%, camp not taken, walks out. Its shipped guard
--       `J.GetHP(nNeutralCreeps[1]) > 0.33` reads like a tier clause and is
--       the opposite of one: an ancient is exactly the unit that is always
--       above 0.33.
--
-- The positive control is in the same corpus (GH #259): PA L11, 376 u from an
-- ancient camp, attacks a `mud_golem` for 8 seconds and finishes it.
--
-- THE FIX. `J.GetFirstUnit` (jmz_func.lua), soak candidate 'abil1st',
-- turbo-only, threshold read from J.Site.ANCIENT_MIN_LEVEL. Unarmed it IS
-- `unitList[1]`; armed below the tier it is the first NON-ancient unit of the
-- same sweep, or nil. It is a SECOND id and not a conjunct of 'abilanc' for
-- the `pullcad` reason in AGENTS.md (an id written into another gate's
-- conjunction freezes to FALSE the day that other id is promoted, and
-- check_armed_wiring.py still calls it WIRED), and because the two are not the
-- same defect: "most HP" IS the ancient by construction, `[1]` is engine order
-- and only sometimes one.
--
-- WHAT IS REAL HERE AND WHAT IS DECLARED -- read before trusting a number.
--   * REAL: both subjects, their LEVELS (the only bot operand the fix reads),
--     and for zuus the fact that he was standing in an ancient camp on that
--     frame -- the dump carries `modifier_ancient_rock_golem_weakening`.
--   * DECLARED: the camp itself. World fact [W1] below asserts the dumper
--     carries no creeps at all, so the sweep is a stand-in with exactly the
--     fields the code reads. Also declared, and labelled at each use: zuus's
--     mana and active mode (the branch's own preconditions, not the fix's),
--     and for centaur the fact the branch cannot be reached at all under the
--     mock -- [limit centaur] asserts WHY rather than leaving it in prose.

package.path = 'tests/?.lua;' .. package.path
local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')
local ss  = require('mock.soak_side')              -- owns bots/Customize/soak_side.lua

local FIX_Z = 'tests/fixtures/f_212636_tide_ancient.lua'
local FIX_C = 'tests/fixtures/f_260819_181742_ss_chase_stalled.lua'
local JMZ   = 'bots/FunLib/jmz_func.lua'
local SITE  = 'bots/FunLib/aba_site.lua'
local ZUUS  = 'bots/BotLib/hero_zuus.lua'
local CENT  = 'bots/BotLib/hero_centaur.lua'
local CAND  = 'abil1st'

-- Subjects as the dump gave them: name, level. L10/L11 are below
-- J.Site.ANCIENT_MIN_LEVEL, L14 is above it, so the ladder is walked without
-- inventing a level anywhere.
local S_TIDE = { 'npc_dota_hero_tidehunter', 10 }
local S_ZUUS = { 'npc_dota_hero_zuus',       11 }
local S_LUNA = { 'npc_dota_hero_luna',       14 }
local S_CENT = { 'npc_dota_hero_centaur',     5 }

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Write the (gitignored) soak_side file the farm writes per wave. The gate
--- is read through its SHIPPED body -- no J.* function is stubbed in this
--- file. GetSoakSideConf caches on first read, so the file must exist BEFORE
--- the frame is loaded, not merely before the call -- which is why this file
--- arms by hand around a fixture load instead of wrapping a closure.
---
--- [GH #365 §3 / GH #229, hero backlog `-78`] The three lines this used to
--- inline are now in tests/mock/soak_side.lua, the switch's one owner: the
--- write is read back (a short write, a full disk or a read-only tree used to
--- present as "the gate did not fire", which is what the unarmed cases below
--- EXPECT), arming refuses to clobber a switch this process did not write, and
--- `disarm` removes only bytes this process wrote and still owns.
local function arm(sCand)
    ss.arm(sCand)
end

local function disarm()
    ss.disarm()
end

--- Load a frame with the gate already in whatever state the caller wants.
--- `sCand == nil` is the unarmed leg, and it now ASSERTS the switch is absent:
--- "the shipped answer" and "the gate is off" are the same observation only
--- while no soak_side file exists, and that path is one global inode shared
--- with every concurrent lua5.1 process.
local function subject(fix, spec, sCand)
    if sCand then arm(sCand) else ss.assert_clean('unarmed leg') end
    local ok, J, bot = pcall(rf.load, fix, spec[1])
    if not ok then disarm(); error(J, 0) end
    if not (bot ~= nil) then disarm(); error('fixture no longer carries ' .. spec[1], 0) end
    if bot:GetLevel() ~= spec[2] then
        disarm()
        error(string.format('the frame moved: %s used to be level %d here, now %d',
            spec[1], spec[2], bot:GetLevel()), 0)
    end
    return J, bot
end

-- ...and once HERE, at file-load time, the only moment that sees the state this
-- process STARTED in: every armed span ends by removing the switch, and the
-- armed cases can sort before the unarmed ones, so an INHERITED leftover is
-- deleted by a sibling case before any per-case guard looks at it (GH #417:
-- such a leftover survived a per-case guard 19/19 green).
ss.assert_clean('test_abil1st_first_unit_reader')

-- The camp as a declared stand-in -- see [W1]. Coordinates are the ones the
-- timeline sampled for the tide/zuus frame's ancient camp; only the fields the
-- code reads are supplied.
local CAMP = { x = -5024, y = 781 }

local function neutral(sName, bAncient, nHealth)
    return api.MakeUnit({
        GetUnitName    = sName,
        IsAncientCreep = bAncient,
        IsNull         = false,
        IsAlive        = true,
        GetTeam        = 4,
        GetLocation    = api.Vector(CAMP.x, CAMP.y, 0),
        GetHealth      = nHealth,
        GetMaxHealth   = nHealth,
    })
end

--- An ancient camp with a normal creep standing in it, ordered so that "the
--- first non-ancient" and "the most HP" are DIFFERENT answers: the mud golem
--- is last in engine order and smallest. A filter that emptied the list
--- wholesale, or one that quietly delegated to J.GetMostHpUnit, fails here.
local function mixed_camp()
    return {
        neutral('npc_dota_neutral_granite_golem', true,  1400),
        neutral('npc_dota_neutral_rock_golem',    true,  1100),
        neutral('npc_dota_neutral_mud_golem',     false,  550),
    }
end

--- A camp with TWO normal creeps, ordered so that "the first non-ancient" and
--- "the biggest non-ancient" are DIFFERENT units. Without this list the file
--- cannot tell the two rules apart -- a mutation that made the reader answer
--- the healthiest non-ancient survived the whole suite until it was added,
--- because mixed_camp() has exactly one non-ancient and both rules agree on it.
local function order_camp()
    return {
        neutral('npc_dota_neutral_granite_golem',    true,  1400),
        neutral('npc_dota_neutral_mud_golem',        false,  300),
        neutral('npc_dota_neutral_dark_troll_warlord', false, 800),
    }
end

local function ancient_only_camp()
    return {
        neutral('npc_dota_neutral_granite_golem', true, 1400),
        neutral('npc_dota_neutral_rock_golem',    true, 1100),
    }
end

local function name_of(u) return u and u:GetUnitName() or nil end

----------------------------------------------------------------------
-- [W1] world fact: the corpus carries no creeps, stated before it is relied on
----------------------------------------------------------------------

tests['[W1] neither frame carries a creep, so every camp below is declared'] = function()
    for _, pair in ipairs({ { FIX_Z, S_ZUUS }, { FIX_C, S_CENT } }) do
        local _, bot = subject(pair[1], pair[2])
        local tNeutrals = bot:GetNearbyNeutralCreeps(1600)
        assert(type(tNeutrals) == 'table' and #tNeutrals == 0,
            'GetNearbyNeutralCreeps answers {} on every fixture (GH #100 section 3); got '
            .. tostring(#tNeutrals))
    end
end

----------------------------------------------------------------------
-- [frame] the subjects really are what this file claims
----------------------------------------------------------------------

tests['[frame] zuus is L11 IN an ancient camp, in turbo, below a threshold read from source'] = function()
    local nMin = tonumber(read_file(SITE):match('ANCIENT_MIN_LEVEL%s*=%s*(%d+)'))
    assert(nMin == 12, 'threshold read from source, not restated; got ' .. tostring(nMin))
    local J, bot = subject(FIX_Z, S_ZUUS)
    assert(J.IsModeTurbo() == true, 'turbo (analysis.json: mode = turbo)')
    -- Standing in the camp is not inferred from coordinates: the dump carries
    -- the debuff the ancient rock golem applies.
    assert(bot:HasModifier('modifier_ancient_rock_golem_weakening'),
        'zuus carries the ancient rock golem debuff on this frame')
    assert(bot:GetLevel() < nMin, 'and he is below the tier -- the whole domain')
    local _, luna = subject(FIX_Z, S_LUNA)
    assert(luna:GetLevel() >= nMin, 'the same frame carries the far side of the ladder')
    local _, cent = subject(FIX_C, S_CENT)
    assert(cent:GetLevel() < nMin,
        'the centaur frame is L5 -- the SAME side of the threshold as the pinned L11 frame, '
        .. 'which is all the fix reads; the corpus has no centaur above the tier')
end

----------------------------------------------------------------------
-- [lever] the behaviour change, through the shipped helper on real frames
----------------------------------------------------------------------

--- Close a span `subject` opened. The two orderings the owner insists on, in
--- the one place this file can put them: on the armed leg the switch cause
--- OUTRANKS the value the body produced (a switch removed mid-span yields the
--- UNARMED value, which #365 §3 spent a round arguing about as an expectation
--- bug); on the unarmed leg the switch must still be absent afterwards, or the
--- "shipped answer" reading was taken under somebody else's candidate.
local function close_span(sCand, ok, err)
    if sCand ~= nil then return ss.finish(ok, err) end
    if ok then ss.assert_clean('unarmed leg, after the case body') end
    if not ok then error(err, 0) end
end

local function first(fix, spec, sCand, tList)
    local J = subject(fix, spec, sCand)
    local ok, answer = pcall(J.GetFirstUnit, tList)
    close_span(sCand, ok, answer)
    return answer
end

tests['[lever] unarmed it IS unitList[1], for every level and every list'] = function()
    for _, spec in ipairs({ S_TIDE, S_ZUUS, S_LUNA }) do
        local camp = mixed_camp()
        local answer = first(FIX_Z, spec, nil, camp)
        assert(answer == camp[1], spec[1]
            .. ' unarmed answers the identical handle at index 1, not a copy and not a pick')
        assert(name_of(answer) == 'npc_dota_neutral_granite_golem')
    end
    assert(first(FIX_Z, S_ZUUS, nil, {}) == nil, 'unarmed, the empty sweep is already nil')
    assert(first(FIX_Z, S_ZUUS, nil, nil) == nil, 'and so is a nil sweep')
end

tests['[lever] armed below the tier: the first NON-ancient, by ORDER not by health'] = function()
    local camp = mixed_camp()
    local answer = first(FIX_Z, S_ZUUS, CAND, camp)
    assert(answer == camp[3], 'L11 armed walks past both ancients to the mud golem')
    assert(first(FIX_Z, S_TIDE, CAND, mixed_camp()):GetUnitName() == 'npc_dota_neutral_mud_golem',
        'L10 likewise')
    -- ORDER, not health: on a camp with two normal creeps the answer is the
    -- one the engine listed first even though it is the smaller of the two.
    -- This is the case that separates this reader from J.GetMostHpUnit; a
    -- "healthiest non-ancient" mutation is invisible without it.
    local ordered = order_camp()
    assert(first(FIX_Z, S_ZUUS, CAND, ordered) == ordered[2],
        'the first non-ancient in ENGINE ORDER (300 hp), not the healthiest one (800 hp)')
    local J = subject(FIX_Z, S_ZUUS, 'abilanc')
    local okOther, other = pcall(J.GetMostHpUnit, order_camp())
    close_span('abilanc', okOther, other)
    assert(name_of(other) == 'npc_dota_neutral_dark_troll_warlord',
        "'abilanc' on the same list answers by health; this lever answers by order -- "
        .. 'two different measurements, which is why they are two ids')
end

tests['[lever] armed below the tier, all ancients: nil -- not a new outcome class'] = function()
    assert(first(FIX_Z, S_ZUUS, CAND, ancient_only_camp()) == nil,
        'an all-ancient sweep answers nil below the tier')
    assert(first(FIX_Z, S_ZUUS, nil, {}) == nil,
        'and the shipped read already answers nil for the empty sweep, so no call site '
        .. 'learns a failure mode it does not already handle')
end

tests['[lever] armed at or above the tier: unchanged'] = function()
    local camp = mixed_camp()
    assert(first(FIX_Z, S_LUNA, CAND, camp) == camp[1],
        'L14 armed keeps the shipped answer -- the tier is the whole domain')
end

tests['[inert] a DIFFERENT armed id, and non-turbo, both leave the shipped answer'] = function()
    local camp = mixed_camp()
    assert(first(FIX_Z, S_ZUUS, 'abilanc', camp) == camp[1],
        "an armed 'abilanc' leg must not move this reader -- the two ids are independent")
    assert(first(FIX_Z, S_ZUUS, 'pullcamp', mixed_camp()):GetUnitName()
        == 'npc_dota_neutral_granite_golem', 'nor any other wave')
    -- Turbo-only, driven by flipping the engine mode the shipped predicate reads.
    arm(CAND)
    local J, answer
    local okTurbo, errTurbo = pcall(function()
        J = rf.load(FIX_Z, S_ZUUS[1])
        GetGameMode = function() return 1 end   -- luacheck: ignore
        answer = J.GetFirstUnit(camp)
    end)
    close_span(CAND, okTurbo, errTurbo)
    assert(J.IsModeTurbo() == false, 'the mode override took')
    assert(answer == camp[1], 'armed but not turbo is the shipped answer')
end

----------------------------------------------------------------------
-- [site zuus] the real call site, end to end, on the real frame
----------------------------------------------------------------------

--- Drive X.ConsiderQ (Arc Lightning) on the zuus frame with a declared camp.
--- DECLARED, and only these: the sweep (see [W1]), the active mode and the
--- mana -- both preconditions of the shipped farm branch, neither read by the
--- fix. The frame's own mana is 268/932, i.e. the branch's `GetManaAfter > 0.3`
--- clause is false there; the pinned GH #259 frame had mana 1.00, which is the
--- state being reproduced.
local function drive_zuus(sCand, tCamp)
    if sCand then arm(sCand) else ss.assert_clean('unarmed leg') end
    local J, bot = rf.load(FIX_Z, S_ZUUS[1])
    assert(bot:GetLevel() == 11 and bot:GetMana() == 268,
        'the frame moved: zuus was L11 with 268 mana here')
    bot.GetNearbyNeutralCreeps = function() return tCamp end
    bot.GetActiveMode = function() return BOT_MODE_FARM end   -- luacheck: ignore
    bot.GetMana = function() return 900 end
    local X = rf.load_hero('zuus')
    local desire, target
    local ok, err = pcall(function() desire, target = X.ConsiderQ() end)
    close_span(sCand, ok, err)
    assert(J ~= nil)
    return desire, target
end

tests['[site zuus] unarmed the PLAN EXISTS: HIGH desire, and the target is the ancient'] = function()
    -- Asserted FIRST and on its own, per GH #259: a later "it is no longer the
    -- ancient" is worthless if the branch never fired to begin with (the GH
    -- #250 trap -- reading "no plan" as "the fix worked").
    local desire, target = drive_zuus(nil, ancient_only_camp())
    assert(desire == BOT_ACTION_DESIRE_HIGH,   -- luacheck: ignore
        'the shipped farm branch fires on a camp of nothing but ancients; got ' .. tostring(desire))
    assert(name_of(target) == 'npc_dota_neutral_granite_golem',
        'and it hands back the raw first unit -- an ancient. This IS the frame-620.4 decision.')
end

tests['[site zuus] armed, the below-tier bot declines that camp entirely'] = function()
    local desire, target = drive_zuus(CAND, ancient_only_camp())
    assert(target == nil, 'no target')
    assert(desire ~= BOT_ACTION_DESIRE_HIGH,   -- luacheck: ignore
        'and no desire -- the guard at the call site is what stops HIGH-with-no-target, '
        .. 'which is the one new failure mode this edit could have introduced')
end

tests['[site zuus] armed, a normal creep in the same camp is still farmed'] = function()
    local desire, target = drive_zuus(CAND, mixed_camp())
    assert(desire == BOT_ACTION_DESIRE_HIGH,   -- luacheck: ignore
        'the lever removes an ancient from the answer, it does not stop the bot farming')
    assert(name_of(target) == 'npc_dota_neutral_mud_golem', 'and the target is the normal creep')
end

tests['[site zuus] armed on ANOTHER id leaves the whole branch alone'] = function()
    local desire, target = drive_zuus('abilanc', ancient_only_camp())
    assert(desire == BOT_ACTION_DESIRE_HIGH and   -- luacheck: ignore
        name_of(target) == 'npc_dota_neutral_granite_golem',
        'the shipped decision, unchanged, on a wave that armed the sibling lever')
end

----------------------------------------------------------------------
-- [site centaur] source shape, and the reason it is not driven end to end
----------------------------------------------------------------------

tests['[site centaur] the branch consumes the guarded handle, not the raw [1]'] = function()
    local src = read_file(CENT)
    assert(src:find('local hNeutralTarget = J.GetFirstUnit(nNeutralCreeps)', 1, true),
        'the sweep goes through the guarded reader')
    assert(src:find('and J.GetHP(hNeutralTarget) > 0.33', 1, true),
        'the health clause reads the SAME handle that will be returned -- reading the raw '
        .. '[1] here would gate on one unit and cast at another')
    assert(src:find('return BOT_ACTION_DESIRE_HIGH, hNeutralTarget', 1, true),
        'and the target is the guarded handle')
    -- The two guards it replaced are subsumed by the nil answer, not dropped:
    local branch = src:match('local nNeutralCreeps = bot:GetNearbyNeutralCreeps%(nCastRange %* 2%)(.-)end')
    assert(branch and not branch:find('#nNeutralCreeps >= 1', 1, true),
        'the length guard is gone because J.GetFirstUnit answers nil for both an empty '
        .. 'and a nil sweep -- asserted in [lever] above')
end

tests['[limit centaur] the consider is NOT driven here, and the reason is asserted'] = function()
    -- Registering this as an executable fact rather than a sentence in a
    -- report: the farm branch sits behind J.IsAttacking, which reads three
    -- animation values the dumper does not carry, so reaching it would mean
    -- declaring the bot's attack animation -- a declaration with no frame
    -- behind it, on top of the camp that already has none.
    local J, bot = subject(FIX_C, S_CENT)
    assert(J.IsAttacking(bot) == false,
        'the dump leaves the anim state at its defaults, so IsAttacking is false')
    assert(bot:GetAnimActivity() ~= ACTIVITY_ATTACK,  -- luacheck: ignore
        'and that is the first of the three values, not a downstream accident')
    assert(J.IsFarming(bot) == false,
        'the frame is a chase, not a farm -- the branch is two declarations away, '
        .. 'and the zuus site above already witnesses the shared reader end to end')
end

----------------------------------------------------------------------
-- [source] gate shape
----------------------------------------------------------------------

tests['[ratchet][source] turbo-only, exactly one id, resolved in exactly one place'] = function()
    local body = read_file(JMZ)
    local cond = assert(body:match("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%( 'abil1st' %)"),
        "the gate resolves as turbo AND 'abil1st'")
    -- The `pullcad` lesson (AGENTS.md): an id written into ANOTHER gate's
    -- conjunction is frozen false the day that other id is promoted, and
    -- check_armed_wiring.py still calls it WIRED.
    local n = 0
    for _ in cond:gmatch("IsSoakCandidate%s*%(%s*'[%w_]+'") do n = n + 1 end
    assert(n == 1, 'exactly one soak id in the gate; got ' .. n)
    local _, nGates = body:gsub("IsSoakCandidate%( 'abil1st' %)", '')
    assert(nGates == 1, "'abil1st' is resolved in exactly one place; got " .. nGates)
    -- And it is not conjoined with the sibling anywhere in the tree.
    local p = assert(io.popen("grep -rn \"abil1st\" bots/ | grep abilanc | grep -v '^%s*--'"))
    local both = p:read('*a')
    p:close()
    for line in both:gmatch('[^\n]+') do
        local body_ = line:match('^[^:]+:%d+:(.*)$')
        assert(body_ == nil or body_:match('^%s*%-%-'),
            'the two ids may share a threshold but never a conjunction: ' .. line)
    end
    -- Threshold from the shared constant, matched on the CODE line: the
    -- surrounding comment names the constant too, so a whole-file find would
    -- pass a mutation that replaced the real read with a bare 12 (0SRC).
    assert(body:find('\t\tbStrictAncient = hSelf ~= nil\n\t\t\tand hSelf:GetLevel() < J.Site.ANCIENT_MIN_LEVEL', 1, true),
        'the tier comes from J.Site.ANCIENT_MIN_LEVEL, not a copied literal')
    -- Order is the mechanism, so the scan must be ordered.
    local fn = assert(body:match('function J%.GetFirstUnit.-\nend'))
    assert(fn:find('for _, unit in ipairs( unitList )', 1, true),
        '"the first" of an unordered walk is not a reproducible decision')
    assert(not fn:find('pairs( unitList )', 1, true) or fn:find('ipairs( unitList )', 1, true),
        'and the unordered walk is not also present')
end

tests['[source] the zuus site guards the nil answer before the disjunction'] = function()
    local src = read_file(ZUUS)
    assert(src:find('local hNeutralTarget = J.GetFirstUnit( nNeutralCreeps )', 1, true),
        'the sweep goes through the guarded reader')
    assert(src:find('if hNeutralTarget ~= nil', 1, true),
        'the nil guard is the FIRST conjunct')
    assert(src:find('return BOT_ACTION_DESIRE_HIGH, hNeutralTarget', 1, true),
        'and the raw [1] is no longer the target')
    -- The second disjunct still reads the raw [1] on purpose: it is the
    -- shipped REASON TO FIRE ("one creep, and it is an ancient"), left
    -- byte-identical so that unarmed the branch is the branch it was.
    assert(src:find("or ( #nNeutralCreeps >= 1 and J.IsValid( nNeutralCreeps[1] ) and nNeutralCreeps[1]:IsAncientCreep() )", 1, true),
        'the shipped disjunction is unchanged')
end

----------------------------------------------------------------------
-- [limit] what is NOT covered, counted so it cannot drift into a claim
----------------------------------------------------------------------

tests['[ratchet][limit] the rest of the [1] population is the next denominator'] = function()
    local function count(pattern)
        local n = 0
        local p = assert(io.popen("grep -rn '" .. pattern .. "' bots/"))
        for line in p:lines() do
            local body = line:match('^[^:]+:%d+:(.*)$')
            if body and not body:match('^%s*%-%-') then n = n + 1 end
        end
        p:close()
        return n
    end
    -- Sites that still hand the raw first unit of a neutral sweep to an
    -- ability as its target/location. Two came off this list in GH #259; if
    -- the tree moves, this fails rather than the report going quietly stale.
    local nRaw = count('DESIRE_[A-Z]*, *[A-Za-z]*NeutralCreeps\\[1\\]')
    assert(nRaw == 8, 'raw-[1] ability targets left in bots/; got ' .. tostring(nRaw))
    -- 'abilanc' territory is untouched by this lever: the selector's own
    -- census file owns that count, and this one must not restate it.
    assert(count('J\\.GetFirstUnit') == 3,
        'one definition and the two call sites GH #259 pinned; got '
        .. tostring(count('J\\.GetFirstUnit')))
end

return tests

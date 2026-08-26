-- [GH #196] The ability layer picks the ancient BY CONSTRUCTION, and none of
-- the three camp-tier candidates is standing on that path.
--
-- WHAT THE REPLAY DESK MEASURED (GH #196, W11: 125 games wide + 7 frame by
-- frame). A level 10-11 hero's fight with an ANCIENT camp is mostly not opened
-- by the neutral-farm target selection at all. On the armed leg, 10 of the 12
-- "the bot landed the first blow" episodes were opened by an ABILITY, 6 of them
-- cast AT the ancient camp (baseline leg: 7 of 9 / 6). Named frame:
-- `spot_20260825_211022_..._d21f62 / 20260825_212701_slot2`, luna, L11,
-- t=515.5, `ABILITY luna_lucent_beam -> npc_dota_neutral_prowler_shaman`.
--
-- WHY NO EXISTING CANDIDATE REACHES IT. 'campgrade' filters the camp LIST,
-- 'campsel' the camp PICK, 'campfarm' the farm path's target selection -- all
-- three live on the neutral-farm path in mode_farm_generic / aba_site. A hero's
-- own ability code never goes through any of them: it sweeps
-- `bot:GetNearbyNeutralCreeps(...)` itself and hands the raw table to
-- `J.GetMostHpUnit`. An ancient creep carries the most health on the field, so
-- on that path "most HP" and "the ancient" are the same answer.
--
-- THE FIX (one lever, one place): the exclusion goes INSIDE the selector, next
-- to the two exclusions of the same class already written there -- Roshan and
-- the Tormentor. Soak candidate 'abilanc', turbo-only, threshold read from
-- J.Site.ANCIENT_MIN_LEVEL. Placing it at the selector rather than at the 20
-- call sites is what makes a future call site structurally unable to miss the
-- gate; the price is that the opt-out has to be explicit, which is the second
-- entry point J.GetMostHpUnitAnyTier and its single user (see [census] below).
-- It was a `bAllowAncient` PARAMETER first: the GH #188 arity ratchet went red
-- on all 16 files that still pass one argument, because an optional parameter
-- makes "passed 1, declares 2" the shape of every existing call site. Two names
-- keep every call site at 1-of-1 and put the exception at the call site.
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number.
-- The SUBJECT half is real and so is the ladder: every bot driven below comes
-- off ONE real .dem frame (t=627.5) carrying the level the game gave it, and
-- level is the only bot operand the fix reads. Three subjects on that one frame
-- straddle the threshold -- tidehunter L10, zuus L11, luna L14 -- and all three
-- were demonstrably standing in the ancient camp, because the frame carries
-- `modifier_ancient_rock_golem_weakening` on each of them.
-- The CREEP half is NOT in the corpus and is not pretended to be: world fact
-- [W1] below asserts the dumper carries no creeps at all, so an end-to-end
-- drive of a hero's farm branch would be measuring an empty sweep. The camp
-- below is a DECLARED STAND-IN with the coordinates the timeline sampled at
-- t=626.5, carrying exactly the fields the selector reads. No count here is
-- claimed as corpus data except the ones under [census] and [W1], which read
-- the tree and the fixture archive directly.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local FIX  = 'tests/fixtures/f_212636_tide_ancient.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'
local SITE = 'bots/FunLib/aba_site.lua'
local DOOM = 'bots/BotLib/hero_doom_bringer.lua'
local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

-- Three subjects on ONE frame, with the level the dump gave them. L10 and L11
-- are below J.Site.ANCIENT_MIN_LEVEL, L14 is above it, so the ladder is walked
-- without inventing a level anywhere.
local TIDE = { 'npc_dota_hero_tidehunter', 10 }
local ZUUS = { 'npc_dota_hero_zuus',       11 }
local LUNA = { 'npc_dota_hero_luna',       14 }

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Arm the REAL gate by writing the (gitignored) soak_side file the farm writes
--- per wave. No J.* function is stubbed anywhere in this file: IsSoakCandidate
--- and IsModeTurbo both run their shipped bodies on the real frame.
local function with_armed(sCand, fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = '" .. sCand .. "' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

local function subject(spec)
    local J, _, heroes = rf.load(FIX, spec[1])
    local bot = heroes[spec[1]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[1])
    assert(bot:GetLevel() == spec[2], string.format(
        'the frame moved: %s used to be level %d here, now %d',
        spec[1], spec[2], bot:GetLevel()))
    return J, bot
end

-- The camp as the timeline sampled it at t=626.5: team-4 entities within 1200 u
-- of the subject, two of them 197 and 220 u away. DECLARED INPUT, not
-- fixture-carried -- see [W1]. The mud golem is the negative control: a normal
-- creep in the same sweep, so a filter that emptied the list wholesale would
-- fail this file rather than pass it.
local CAMP = { x = -5024, y = 781 }

local function neutral(sName, bAncient, nHealth)
    return api.MakeUnit({
        GetUnitName   = sName,
        IsAncientCreep = bAncient,
        IsNull        = false,
        IsAlive       = true,
        GetTeam       = 4,
        GetLocation   = api.Vector(CAMP.x, CAMP.y, 0),
        GetHealth     = nHealth,
        GetMaxHealth  = nHealth,
    })
end

--- Ancients carry the most health on the field. That ordering IS the mechanism,
--- so it is written here as data rather than assumed in prose.
local function camp_units()
    return {
        neutral('npc_dota_neutral_mud_golem',     false, 550),
        neutral('npc_dota_neutral_rock_golem',    true, 1100),
        neutral('npc_dota_neutral_granite_golem', true, 1400),
    }
end

----------------------------------------------------------------------
-- [W1] world fact: the corpus has no creeps, stated before it is relied on
----------------------------------------------------------------------

tests['[W1] no fixture carries a creep, so the camp above is a declared input'] = function()
    local _, bot = subject(TIDE)
    local tNeutrals = bot:GetNearbyNeutralCreeps(1600)
    assert(type(tNeutrals) == 'table' and #tNeutrals == 0,
        'GetNearbyNeutralCreeps answers {} on every fixture (GH #100 §3); got '
        .. tostring(#tNeutrals))
    assert(#bot:GetNearbyCreeps(1600, true) == 0,
        'and so does the lane sweep')
end

----------------------------------------------------------------------
-- [frame] the three subjects really are the ladder this file claims
----------------------------------------------------------------------

tests['[frame] one real frame carries L10, L11 and L14 in the same ancient camp'] = function()
    local nMin = tonumber(read_file(SITE):match('ANCIENT_MIN_LEVEL%s*=%s*(%d+)'))
    assert(nMin == 12, 'threshold read from source, not restated; got ' .. tostring(nMin))
    for _, spec in ipairs({ TIDE, ZUUS, LUNA }) do
        local J, bot = subject(spec)
        assert(J.IsModeTurbo() == true, 'turbo (analysis.json: mode = turbo)')
        -- Standing in the ancient camp is not inferred from coordinates: the
        -- dump carries the debuff the ancient rock golem applies.
        assert(bot:HasModifier('modifier_ancient_rock_golem_weakening'),
            spec[1] .. ' carries the ancient rock golem debuff on this frame')
    end
    local _, tide = subject(TIDE)
    local _, luna = subject(LUNA)
    assert(tide:GetLevel() < nMin and luna:GetLevel() >= nMin,
        'the two ends of the ladder straddle the tier')
end

----------------------------------------------------------------------
-- [lever] the behaviour change, driven through the shipped selector
----------------------------------------------------------------------

--- The whole lever in one place: what the SHIPPED selector answers on the real
--- frame, with the real gate, for each subject.
local function pick(spec, sArmed, bAnyTier)
    local J, bot = subject(spec)
    local answer
    local function run()
        if bAnyTier then
            answer = J.GetMostHpUnitAnyTier(camp_units())
        else
            answer = J.GetMostHpUnit(camp_units())
        end
    end
    if sArmed then with_armed(sArmed, run) else run() end
    assert(bot ~= nil)
    return answer and answer:GetUnitName() or nil
end

tests['[lever] unarmed, every level picks the ancient -- the shipped default'] = function()
    for _, spec in ipairs({ TIDE, ZUUS, LUNA }) do
        assert(pick(spec, nil) == 'npc_dota_neutral_granite_golem',
            spec[1] .. ' unarmed still picks the biggest unit in the sweep')
    end
end

tests['[lever] armed with a DIFFERENT candidate changes nothing'] = function()
    -- The id is not a global switch: an armed wave that is not this wave leaves
    -- the shipped answer alone.
    assert(pick(TIDE, 'campfarm') == 'npc_dota_neutral_granite_golem',
        "an armed 'campfarm' leg must not move this selector")
end

tests['[lever] armed + below the tier: the normal creep, not the ancient'] = function()
    assert(pick(TIDE, 'abilanc') == 'npc_dota_neutral_mud_golem',
        'L10 armed picks the mud golem that shares the sweep')
    assert(pick(ZUUS, 'abilanc') == 'npc_dota_neutral_mud_golem',
        'L11 armed likewise -- 11 is still below 12')
end

tests['[lever] armed + at or above the tier: unchanged'] = function()
    assert(pick(LUNA, 'abilanc') == 'npc_dota_neutral_granite_golem',
        'L14 armed keeps the shipped answer -- the tier is the whole domain')
end

tests['[lever] armed, ancients only: nil, which every call site already handles'] = function()
    local J, _ = subject(TIDE)
    local answer
    with_armed('abilanc', function()
        answer = J.GetMostHpUnit({
            neutral('npc_dota_neutral_rock_golem',    true, 1100),
            neutral('npc_dota_neutral_granite_golem', true, 1400),
        })
    end)
    assert(answer == nil, 'an all-ancient sweep answers nil below the tier')
    -- nil is NOT a new outcome class: the shipped selector already answers nil
    -- for an empty list, so no call site learns a new failure mode here.
    local shipped = J.GetMostHpUnit({})
    assert(shipped == nil, 'the shipped selector already answers nil for {}')
end

tests['[lever] the AnyTier entry point restores the shipped answer exactly'] = function()
    assert(pick(TIDE, 'abilanc', true) == 'npc_dota_neutral_granite_golem',
        'the opt-out is byte-identical to the shipped pick')
    assert(pick(TIDE, nil, true) == 'npc_dota_neutral_granite_golem',
        'and it carries no gate of its own, so unarmed it is the same answer')
end

tests['[lever] the two shipped exclusions still hold, armed and unarmed'] = function()
    local J, _ = subject(TIDE)
    local list = {
        neutral('npc_dota_neutral_mud_golem', false, 550),
        -- CanBeSeen matters: J.IsRoshan requires it, so a stub without it is
        -- not Roshan as far as the shipped predicate is concerned.
        api.MakeUnit({ GetUnitName = 'npc_dota_roshan', IsNull = false,
            IsAlive = true, CanBeSeen = true, GetHealth = 9000,
            GetMaxHealth = 9000,
            GetLocation = api.Vector(CAMP.x, CAMP.y, 0) }),
    }
    assert(J.GetMostHpUnit(list):GetUnitName() == 'npc_dota_neutral_mud_golem',
        'Roshan is excluded unarmed, as before')
    with_armed('abilanc', function()
        assert(J.GetMostHpUnit(list):GetUnitName() == 'npc_dota_neutral_mud_golem',
            'and armed -- the new conjunct is added to that list, not put in its place')
    end)
end

----------------------------------------------------------------------
-- [census] the call-site facts the comment in jmz_func.lua asserts
----------------------------------------------------------------------

--- Every J.GetMostHpUnit call site outside jmz_func.lua, as file:line plus the
--- expression that produced its list. Read off the tree so it cannot go stale
--- in prose while the tree moves.
local function call_sites()
    local out = {}
    local p = assert(io.popen("grep -rn 'J\\.GetMostHpUnit' bots/ | grep -v '^bots/FunLib/jmz_func.lua:'"))
    for line in p:lines() do
        local file, num, body = line:match('^([^:]+):(%d+):(.*)$')
        -- A CALL census, so a comment that names the selector is not a site.
        -- (The alternative -- never writing the name in a comment -- is the
        -- 0NIL trap in reverse: it would make the tree less readable to keep a
        -- crude matcher happy.)
        if file and not body:match('^%s*%-%-') then
            out[#out + 1] = { file = file, line = tonumber(num), body = body }
        end
    end
    p:close()
    return out
end

tests['[census] 20 call sites, and exactly one of them opts out'] = function()
    local sites = call_sites()
    assert(#sites == 20, '20 call sites outside the selector; got ' .. #sites)
    local optouts = {}
    for _, s in ipairs(sites) do
        if s.body:find('J.GetMostHpUnitAnyTier', 1, true) then
            optouts[#optouts + 1] = s
        end
    end
    assert(#optouts == 1, 'exactly one opt-out; got ' .. #optouts)
    assert(optouts[1].file == DOOM, 'and it is the doom devour path; got ' .. optouts[1].file)
end

tests['[census] the opt-out site is the only consumer that reads the tier BEFORE it commits'] = function()
    -- This is the mechanism the exception is allowed to be as wide as (0EXC):
    -- a consumer that itself branches on IsAncientCreep and can act on an
    -- ancient. Doom's block does; mirana's only DECLINES one after the pick.
    local body = read_file(DOOM)
    assert(body:find('J.GetMostHpUnitAnyTier(nCreeps)', 1, true),
        'the opt-out is written at the devour path')
    assert(body:find('nCreepTarget:IsAncientCreep()', 1, true)
        and body:find('DevourAncientTalent:IsTrained()', 1, true),
        'and that path really does have a use for an ancient')
    local mirana = read_file('bots/BotLib/hero_mirana.lua')
    assert(mirana:find('not targetCreep:IsAncientCreep()', 1, true),
        'mirana reads the tier only to REJECT, so she wants the filter, not the opt-out')
end

tests['[source] the gate is turbo-only, names exactly one id, and lives once'] = function()
    local body = read_file(JMZ)
    local cond = assert(body:match("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%( 'abilanc' %)"),
        "the gate resolves as turbo AND 'abilanc'")
    -- The `pullcad` lesson (AGENTS.md): an id written into ANOTHER gate's
    -- conjunction is frozen false the day that other id is promoted, and
    -- check_armed_wiring.py still calls it WIRED. One id per gate.
    local n = 0
    for _ in cond:gmatch("IsSoakCandidate%s*%(%s*'[%w_]+'") do n = n + 1 end
    assert(n == 1, 'exactly one soak id in the gate; got ' .. n)
    local _, nGates = body:gsub("IsSoakCandidate%( 'abilanc' %)", '')
    assert(nGates == 1, "'abilanc' is resolved in exactly one place; got " .. nGates)
    -- Threshold from the shared constant, not a second literal 12. Matched on
    -- the CODE line, not anywhere in the file: the surrounding comment names
    -- the constant too, and a whole-file `find` therefore passed a mutation
    -- that replaced the real read with a bare 12 (0SRC's own failure mode --
    -- the check that quotes what it tests stops testing it).
    assert(body:find('and hSelf:GetLevel() < J.Site.ANCIENT_MIN_LEVEL', 1, true),
        'the tier comes from J.Site.ANCIENT_MIN_LEVEL (0SRC), not a copied literal')
end

----------------------------------------------------------------------
-- [limit] what is NOT covered, asserted so it cannot drift into a claim
----------------------------------------------------------------------

tests['[limit] the [1] and centre-of-mass readers are untouched, and counted'] = function()
    -- GH #196 §3.2 asks not to touch the "an ancient camp is worth an AoE"
    -- reasons. These counts are the denominator handed to the next lever; if
    -- the tree moves, this fails rather than the report going quietly stale.
    -- Comment lines dropped for the same reason as in [census] above.
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
    -- 143 method-call sweeps. The two remaining textual hits are the engine
    -- override in aba_global_overrides.lua that caps every one of them at
    -- 1600 u, not sweeps of their own.
    local nSweeps = count(':GetNearbyNeutralCreeps(')
    assert(nSweeps == 143, 'neutral sweeps in bots/; got ' .. tostring(nSweeps))
    local nCentre = count('J\\.GetCenterOfUnits')
    assert(nCentre >= 13, 'the AoE centre readers are still there; got ' .. tostring(nCentre))
end

return tests

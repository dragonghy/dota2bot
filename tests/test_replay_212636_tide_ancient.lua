-- [GH #197 §3] The fixture the replay desk was asked to pin: W11 armed leg,
-- `spot_20260825_211022_..._d21f62 / 20260825_212636_slot7`, tidehunter,
-- t=627.5, level 10 -- one of the two frames where a bot inside `campfarm`'s
-- domain (turbo, armed, level < 12) landed an auto-attack on an ANCIENT creep,
-- which the armed filter is supposed to have removed from the farm path's
-- input table.
--
-- #197 offered two explanations and said the offline read could not separate
-- them: (i) the gate did not take effect on that frame, or (ii) the attack
-- order came from somewhere other than the farm path. This file answers (i)
-- with the real filter on the real frame, and hands (ii) the frame evidence
-- that #197's own argument for excluding engine retaliation does not survive.
--
-- WHAT #197's ARGUMENT SAID, AND WHAT THE FRAME SAYS. #197 §1 excluded engine
-- auto-acquire with "此前一帧都没挨过打 ... 首次挨打晚 2.0 秒" -- the subject
-- takes no damage until 2 s AFTER the attack. That reading looked only at
-- damage TO the subject, and only inside an episode window that opened at
-- t=624.5. The full event stream (tl_212636_slot7, cited per row below) shows
-- the camp had been in combat with this bot's group for seconds before 627.5:
--
--   613.0  the subject casts RAVAGE in a teamfight standing on the camp
--   614.7  ravage deals 193 to granite_golem, mud_golem and BOTH rock_golems
--          -- the subject's own first damage to this camp, 12.8 s early, and
--          via an ultimate's AoE, which no farm-target filter can gate
--   613.7/615.0  two kills (slardar, ogre_magi); level 9 -> 10 at t=614.5
--   622.4  modifier_ancient_rock_golem_weakening lands on the SUBJECT
--   623.5  rock_golem DAMAGES an ally (zuus, 21)
--   623.6-626.6  luna (L14) and zuus auto-attack the camp continuously
--   627.1  the subject's auto-attack on rock_golem -- the frame in question
--   629.8  granite_golem's first damage to the subject (#197's "first hit")
--
-- So at the decision instant this is post-teamfight ground with two allies
-- already committed to the camp, not a farm pick. Engine auto-acquire on an
-- aggroed camp is fully live, and the farm path's own anti-steal branch
-- (`bAllyFarming`, mode_farm_generic.lua:764-782) is pointing AWAY from this
-- camp. The three assertions marked [frame] below are the parts of that story
-- the fixture itself carries, so they cannot drift with a re-read.
--
-- WHAT THIS FILE CANNOT DO, stated first (GH #61):
--   * The neutral half of the world is a DECLARED STAND-IN. GH #100/§3: every
--     fixture answers GetNearbyCreeps() with {}, so the creep table handed to
--     the filter below is BUILT HERE from the camp the timeline sampled at
--     t=626.5 (three neutral entities 197-220 u from the subject, of which the
--     granite/rock golems are the ancient camp). That makes test 1 a test of
--     the FILTER, not an end-to-end reproduction of the attack order.
--   * A .dem carries no bot mode, so #197 §3 question 3 ("was the active mode
--     BOT_MODE_FARM?") is not answerable from any fixture. It stays open; the
--     [frame] assertions bound it from the outside instead.
--   * Nothing here measures gold, and no assertion depends on the mock's
--     GetItemCost.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local FIX = 'tests/fixtures/f_212636_tide_ancient.lua'
local SUBJ = 'npc_dota_hero_tidehunter'
local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local SITE = 'bots/FunLib/aba_site.lua'
local FARM = 'bots/mode_farm_generic.lua'

-- The camp, as the timeline sampled it at t=626.5 (team-4 entities within
-- 1200 u of the subject). DECLARED INPUT, not fixture-carried -- see the bound
-- above. Two of the three sit 197 and 220 u from the subject.
local CAMP = { x = -5024, y = 781 }

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Arm the REAL gate by writing the (gitignored) soak_side file the farm
--- writes per wave, exactly as tests/test_aegis_grouping.lua does. No J.*
--- function is stubbed anywhere in this file: `IsSoakCandidate` and
--- `IsModeTurbo` both run their shipped bodies.
--- The wave really did arm this: the game's analysis.json carries
--- `script_version = mirror:...,campfarm:s896:radiant`, and the subject is on
--- team 2 = radiant, i.e. the armed leg.
local function with_campfarm_armed(fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'campfarm' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

--- The camp as three unit handles. `IsAncientCreep` is the only predicate
--- FilterFarmNeutrals reads, and the mud golem is the negative control: a
--- normal creep standing in the same 900 u sweep, so a filter that emptied the
--- list wholesale would fail this file rather than pass it.
local function camp_units()
    local vCamp = api.Vector(CAMP.x, CAMP.y, 0)
    local function neutral(sName, bAncient)
        return api.MakeUnit({
            GetUnitName = sName,
            IsAncientCreep = bAncient,
            IsNull = false,
            IsAlive = true,
            GetLocation = vCamp,
            GetHealth = bAncient and 1400 or 550,
            GetMaxHealth = bAncient and 1400 or 550,
            GetTeam = 4,
        })
    end
    return {
        neutral('npc_dota_neutral_rock_golem', true),
        neutral('npc_dota_neutral_granite_golem', true),
        neutral('npc_dota_neutral_mud_golem', false),
    }
end

--- The gate expression EXACTLY as mode_farm_generic.lua:76-78 writes it. The
--- level comes off the loaded bot, not off a literal, so if the fixture is
--- ever regenerated at a different instant this reads the new level.
local function neutral_farm_list(J, bot, tCreeps)
    return J.Site.FilterFarmNeutrals(tCreeps, bot:GetLevel(),
        J.IsModeTurbo() and J.IsSoakCandidate('campfarm'))
end

local function names_of(tList)
    local out = {}
    for _, u in ipairs(tList) do out[#out + 1] = u:GetUnitName() end
    table.sort(out)
    return table.concat(out, ',')
end

tests['[frame] the subject really is inside campfarm domain at t=627.5'] = function()
    local J, bot, _, fx = rf.load(FIX, SUBJ)
    local nMin = tonumber(read_file(SITE):match('ANCIENT_MIN_LEVEL%s*=%s*(%d+)'))
    assert(nMin == 12, 'ANCIENT_MIN_LEVEL read from source, not restated: ' .. tostring(nMin))
    assert(fx.time == 627.5, 'the fixture is the instant #197 named')
    assert(bot:GetLevel() == 10, 'level 10 on the frame, from the dump')
    assert(bot:GetLevel() < nMin, 'and therefore below the ancient tier')
    assert(J.IsModeTurbo() == true, 'turbo (analysis.json: mode = turbo)')
    with_campfarm_armed(function()
        local J2, bot2 = rf.load(FIX, SUBJ)
        assert(J2.IsSoakCandidate('campfarm') == true,
            'the real gate opens for this bot: radiant leg, campfarm armed')
        assert(bot2:GetTeam() == 2, 'subject is radiant = the armed side of this wave')
    end)
end

tests['[gate] armed, the real filter drops both ancients and keeps the normal creep'] = function()
    with_campfarm_armed(function()
        local J, bot = rf.load(FIX, SUBJ)
        local tIn = camp_units()
        local tOut = neutral_farm_list(J, bot, tIn)
        assert(#tIn == 3, 'declared stand-in camp: 2 ancient + 1 normal')
        assert(names_of(tOut) == 'npc_dota_neutral_mud_golem',
            'armed at level 10 the ancients are gone and ONLY they are gone; got: '
            .. names_of(tOut))
        assert(tOut ~= tIn, 'a filtered list is a new table, not the input')
    end)
end

tests['[gate] the mechanism is level-keyed, not unconditional'] = function()
    with_campfarm_armed(function()
        local J, _ = rf.load(FIX, SUBJ)
        local tIn = camp_units()
        -- Same armed wave, same camp, a bot one level past the tier.
        local tOut = J.Site.FilterFarmNeutrals(tIn, 12,
            J.IsModeTurbo() and J.IsSoakCandidate('campfarm'))
        assert(tOut == tIn, 'at the tier the SAME TABLE comes back, by identity')
    end)
end

tests['[control] armed on the OTHER side, the same frame is untouched'] = function()
    -- Falsification for the test above: if the drop came from the level alone
    -- the list would shrink here too. It must not -- this bot is radiant.
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'dire', cand = 'campfarm' }\n")
    f:close()
    local ok, err = pcall(function()
        local J, bot = rf.load(FIX, SUBJ)
        assert(J.IsSoakCandidate('campfarm') == false, 'wrong leg, gate shut')
        local tIn = camp_units()
        assert(neutral_farm_list(J, bot, tIn) == tIn, 'the ancients stay in the list')
    end)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

tests['[control] with no soak_side file the gate is shut and the list is untouched'] = function()
    assert(io.open(SIDE_PATH, 'r') == nil, 'no soak_side file exists here')
    local J, bot = rf.load(FIX, SUBJ)
    assert(J.IsSoakCandidate('campfarm') == false, 'unarmed off the farm')
    local tIn = camp_units()
    local tOut = neutral_farm_list(J, bot, tIn)
    assert(tOut == tIn, 'shipped path unchanged down to the object the caller holds')
end

tests['[frame] the camp had been on the subject for 5+ seconds before the attack'] = function()
    local _, bot, _, fx = rf.load(FIX, SUBJ)
    assert(bot:HasModifier('modifier_ancient_rock_golem_weakening'),
        "the ancient camp's aura is on the subject at the decision instant")
    local nElapsed
    for _, u in ipairs(fx.units) do
        if u.name == SUBJ then
            for _, m in ipairs(u.modifiers or {}) do
                if m.name == 'modifier_ancient_rock_golem_weakening' then nElapsed = m.elapsed end
            end
        end
    end
    assert(nElapsed and nElapsed >= 5.0,
        'and it had been on for ' .. tostring(nElapsed) .. ' s -- the camp was '
        .. 'already engaged, so "no damage taken yet" does not exclude retaliation')
end

tests['[frame] the same camp had already damaged an ally 4 s before the frame'] = function()
    local _, _, _, fx = rf.load(FIX, SUBJ)
    local nDt
    for _, u in ipairs(fx.units) do
        for _, d in ipairs(u.recent_damage or {}) do
            if d.src == 'npc_dota_neutral_rock_golem' then
                nDt = math.min(nDt or 99, d.dt)
            end
        end
    end
    assert(nDt and nDt <= 4.5,
        'a rock_golem hit a hero ' .. tostring(nDt) .. ' s before t=627.5 -- '
        .. 'the camp is fighting this group, not idling in its box')
end

tests['[frame] two allies are on the camp and the nearest enemies are corpses'] = function()
    local _, bot, heroes, fx = rf.load(FIX, SUBJ)
    local vCamp = api.Vector(CAMP.x, CAMP.y, 0)
    local nAlliesOnCamp, nAliveEnemiesNear = 0, 0
    for _, u in ipairs(fx.units) do
        if u.name ~= SUBJ then
            local h = heroes[u.name]
            local dCamp = GetUnitToLocationDistance(h, vCamp)
            if u.team == bot:GetTeam() and u.alive and dCamp <= 800 then
                nAlliesOnCamp = nAlliesOnCamp + 1
            end
            if u.team ~= bot:GetTeam() and u.alive
                and GetUnitToUnitDistance(bot, h) <= 1600 then
                nAliveEnemiesNear = nAliveEnemiesNear + 1
            end
        end
    end
    assert(nAlliesOnCamp == 2,
        'luna and zuus are inside the anti-steal radius of this camp; got ' .. nAlliesOnCamp)
    assert(nAliveEnemiesNear == 0,
        'and the two enemies within 900 u (slardar 665 u, ogre_magi 877 u) are dead, '
        .. 'so the frame is post-teamfight ground')
    -- The clause those two allies would trip if the farm path were driving.
    local body = read_file(FARM)
    assert(body:find('local nAllyNearCamp = J.GetAlliesNearLoc(targetFarmLoc, 800)', 1, true),
        'the anti-steal branch reads an 800 u ring around the camp')
end

tests['[source] the gate is one wrapper, campfarm alone, no conjunction'] = function()
    local body = read_file(FARM)
    local cond = assert(body:match("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%('campfarm'%)"),
        'the wrapper still resolves the gate as turbo AND campfarm')
    -- The `pullcad` lesson (AGENTS.md): an id written into ANOTHER gate's
    -- conjunction is frozen false the day that other id is promoted. campfarm's
    -- gate must name exactly one candidate.
    local n = 0
    for _ in cond:gmatch("IsSoakCandidate%s*%(%s*'[%w_]+'") do n = n + 1 end
    assert(n == 1, 'exactly one soak id in the gate; got ' .. n)
    local _, nSites = body:gsub('NeutralFarmList%(bot,', '')
    assert(nSites == 3, 'all three neutral sweeps still go through the wrapper; got ' .. nSites)
end

return tests

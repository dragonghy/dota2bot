-- Strategy desk backlog 0NEXT16 (2026-09-14T19:28Z), which asked for ONE
-- reading before any code moved: "is IsAncientCreep() constantly false on the
-- GetFarmLaneTarget path? If so, narrowing utils.IsValidCreep's `> 9` is a
-- closed-form no-op there, and it is a lever UPSTREAM of 'camppick' that also
-- covers the consumers camppick cannot reach."
--
-- THE RULING THIS FILE PINS: the literal does not move, and the lane reading
-- is NOT what decides that. A cheaper, source-level reading does, and it
-- refutes the premise instead of the branch -- narrowing `> 9` is not upstream
-- of camppick and does not cover more; it is INCOMPLETE on the very path it
-- targets, and where it does bite it changes more than ancient-refusal.
--
--   (1) INCOMPLETE. GetMaxHPCreep and GetMinHPCreep open their loop with
--           if not creep:IsNull() and HasArmorReduction(creep) then return creep end
--       which returns BEFORE IsValidCreep is ever called. So at a level the
--       literal refuses, an ancient carrying medallion / solar crest / amplify
--       damage / meld armor is still handed back. A narrowed literal cannot
--       close the ancient hole in the two HP selectors -- it is not a bound on
--       that path at all, it is a bound on one of the two branches of it.
--
--   (2) WIDER, NOT NARROWER. GetNearestCreep tests creepList[1] ONLY; it does
--       not scan for the next valid creep. So in the narrowed world a
--       'nearest' farmer whose closest creep is an ancient does not get "the
--       nearest non-ancient" -- it gets nil, falls through
--       FindFarmNeutralTarget's `targetCreep or GetMinHPCreep(tPick)` tail and
--       silently becomes a minHP farmer for that frame. camppick, which
--       filters the copy the selector walks, keeps the farmer's TYPE.
--       Measured below on a real level-4 sven frame: shipped pick is the
--       300 hp creep 800u away, camppick's list gives the 550 hp creep 400u
--       away. Both refuse the ancient; only one of them is still "nearest".
--
--   (3) camppick closes BOTH, because it filters before any selector walks the
--       list -- the armor-reduction shortcut included.
--
-- WHY THE LANE READING IS STILL UNBOUGHT, AND WHY THAT NO LONGER BLOCKS
-- --------------------------------------------------------------------
-- The two consumer families of the literal are asserted below: the neutral
-- sweep (FindFarmNeutralTarget, which camppick already gates) and the lane
-- sweep (GetFarmLaneTarget over bot:GetNearbyLaneCreeps). Whether an ancient
-- can appear in the second is UNCERTIFIABLE on today's instruments -- the
-- dumper writes creep rows as position and team only, so IsAncientCreep() is
-- discarded at fixture-write time (the same wall tests/test_camppick_target_
-- tier.lua [world] states). It is registered here, not assumed in either
-- direction. It does not block the ruling because (1) and (2) hold whatever
-- that list contains: they are properties of the selectors, not of the sweep.
--
-- TRANSFERABLE: a backlog entry can name the wrong reading. 0NEXT16 named an
-- expensive uncertifiable one and made it the gate; the deciding reading was
-- six lines of shipped Lua above it. Before buying the reading an entry names,
-- check whether a cheaper one refutes the PREMISE rather than picking a branch.
-- (Second instance in two rounds: 0NEXT15's premise had expired in the source.)
--
-- LEVEL IS THE ONLY BOT OPERAND HERE, and it is real: every bot below is a
-- real hero off a real .dem frame carrying the level the game gave it. The
-- creeps are a DECLARED STAND-IN carrying exactly the fields the shipped
-- selectors read, for the reason stated above. No count here is claimed as
-- corpus data.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- The narrowed world is OBSERVABLE without narrowing anything: below level 10
-- the shipped `> 9` already refuses ancients, so a real sub-10 frame IS the
-- world a narrowed literal would create at 10..11. That is why these two
-- frames, and why no source edit is needed to read the consequence.
local VIPER      = 'npc_dota_hero_viper'
local SVEN       = 'npc_dota_hero_sven'
local VIPER_L9   = { 'tests/fixtures/f_260820_102645_cm_es_reach.lua', VIPER, 9 }
local SVEN_L4    = { 'tests/fixtures/f_071903_sven_idle.lua',          SVEN,  4 }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    local bot = heroes[spec[2]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[2] .. ' -- ' .. spec[1])
    assert(bot:GetLevel() == spec[3], string.format(
        'the frame moved: %s used to carry %s at level %d, now %d',
        spec[1], spec[2], spec[3], bot:GetLevel()))
    assert(bot:GetLevel() <= 9, 'this file reads the sub-10 world on purpose')
    return J, bot
end

local function creep(bot, sName, nHealth, bAncient, dist, tMods)
    local loc = bot:GetLocation()
    local d = (dist or 300) / math.sqrt(2)
    return api.MakeUnit({
        GetUnitName = sName,
        GetHealth = nHealth,
        GetMaxHealth = nHealth,
        IsAncientCreep = bAncient,
        IsNull = false,
        CanBeSeen = true,
        IsAlive = true,
        IsInvulnerable = false,
        IsHero = false,
        HasModifier = function(_, m) return tMods ~= nil and tMods[m] == true end,
        GetLocation = api.Vector(loc.x + d, loc.y + d, 0),
    })
end

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

--============================================================================
-- The shape, read from source. If any of this drifts the ruling gets re-read
-- instead of quietly surviving as prose in a backlog entry.
--============================================================================

-- [ratchet], not [source]: 开工自检's fast Lua leg discovers files by that tag,
-- and both blocks below are tree-scanners over shipped source that ANY desk's
-- landing can redden (a new IsValidCreep call site, a new GetFarmLaneTarget
-- caller). Untagged, their red is found hours later by the next desk to start
-- work -- GH #624's立案 shape, and GH #806's UNCOVERED counter reported exactly
-- that about this desk's previous file the round after it landed. Timed before
-- tagging, as that leg's header requires: 0.08s for the whole file.
tests['[ratchet] the literal still reads `> 9` and lives in IsValidCreep only'] = function()
    local utils = strip_comments(read('bots/FunLib/utils.lua'))
    local body = utils:match('function ____exports%.IsValidCreep%b()%s*(.-)\nend')
    assert(body ~= nil, 'IsValidCreep is gone from bots/FunLib/utils.lua')
    assert(body:find('GetBot%(%):GetLevel%(%)%s*>%s*9'),
        "IsValidCreep's `> 9` moved -- re-read 0NEXT16's ruling before trusting this file")
    local _, nElsewhere = utils:gsub('GetBot%(%):GetLevel%(%)%s*>%s*9', '')
    assert(nElsewhere == 1, 'the `> 9` ancient clause now has ' .. nElsewhere
        .. ' copies in utils.lua -- the ruling was written for exactly one')
end

-- The two consumer families. This is the census 0NEXT16 asked for, and it is
-- the reason the lane path is in scope at all: the literal is shared.
tests['[ratchet] the literal has exactly two consumer families, one of them the lane'] = function()
    local site = strip_comments(read('bots/FunLib/aba_site.lua'))

    -- Every selector that evaluates IsValidCreep, and nothing else does.
    local _, nUses = site:gsub('IsValidCreep%s*%(', '')
    assert(nUses == 3, 'expected the 3 shipped IsValidCreep call sites '
        .. '(GetNearestCreep, GetMaxHPCreep, GetMinHPCreep), found ' .. nUses)

    -- Family A: the neutral sweep, already gated at the call layer by camppick.
    local neutral = site:match('____exports%.FindFarmNeutralTarget%s*=%s*function%b()%s*(.-)\nend')
    assert(neutral ~= nil, 'FindFarmNeutralTarget is gone')
    assert(neutral:find('FilterFarmNeutrals%s*%('),
        'FindFarmNeutralTarget no longer routes through camppick\'s filter')

    -- Family B: the lane sweep.
    local lane = site:match('____exports%.GetFarmLaneTarget%s*=%s*function%b()%s*(.-)\nend')
    assert(lane ~= nil, 'GetFarmLaneTarget is gone')
    assert(not lane:find('FilterFarmNeutrals%s*%('),
        'the lane path now routes through camppick -- the ruling assumed it does not')

    -- ...and its one provider, which is what the unbought reading is about.
    local farm = strip_comments(read('bots/mode_farm_generic.lua'))
    local _, nLaneCalls = farm:gsub('J%.Site%.GetFarmLaneTarget%s*%(', '')
    assert(nLaneCalls == 1, 'GetFarmLaneTarget now has ' .. nLaneCalls
        .. ' call sites -- the lane provider census below covers one')
    assert(farm:find('hLaneCreepList%s*=%s*bot:GetNearbyLaneCreeps%s*%('),
        'the lane sweep no longer comes from bot:GetNearbyLaneCreeps')

    local p = assert(io.popen("grep -rl 'GetFarmLaneTarget' bots/ 2>/dev/null"))
    local seen = {}
    for line in p:lines() do seen[#seen + 1] = line end
    p:close()
    table.sort(seen)
    assert(table.concat(seen, ',') == 'bots/FunLib/aba_site.lua,bots/mode_farm_generic.lua',
        'a new file calls GetFarmLaneTarget: ' .. table.concat(seen, ','))
end

-- The lane branch of 0NEXT16 is unbought, and this says why in an assertion
-- rather than in a sentence: if the dumper ever emits creep identity, this
-- goes red and the reading becomes buyable.
tests['[world] creep identity is not in the corpus, so the lane branch stays UNCERTIFIABLE'] = function()
    local gen = read('tools/batch_test/replayscope/make_fixture.py')
    assert(gen:find('POSITION AND TEAM ONLY', 1, true)
        or gen:find('no entity id, no name, no health', 1, true),
        'make_fixture.py now emits creep identity -- IsAncientCreep() on the lane '
        .. 'sweep just became measurable; re-open 0NEXT16\'s lane branch')
end

--============================================================================
-- (1) INCOMPLETE: the armor-reduction shortcut outruns the literal.
--============================================================================

tests['[incomplete] the armor-reduction shortcut precedes IsValidCreep in both HP selectors'] = function()
    local site = strip_comments(read('bots/FunLib/aba_site.lua'))
    for _, name in ipairs({ 'GetMaxHPCreep', 'GetMinHPCreep' }) do
        local body = site:match('____exports%.' .. name .. '%s*=%s*function%b()%s*(.-)\nend')
        assert(body ~= nil, name .. ' is gone')
        local iShort = body:find('HasArmorReduction%s*%(')
        local iValid = body:find('IsValidCreep%s*%(')
        assert(iShort ~= nil and iValid ~= nil, name .. ' lost one of the two branches')
        assert(iShort < iValid, name .. ': the armor-reduction shortcut no longer '
            .. 'precedes IsValidCreep -- the incompleteness this ruling turns on is gone')
    end
end

tests['[incomplete] at a level the literal refuses, an amped ancient still comes back'] = function()
    local J, bot = subject(VIPER_L9)
    local amped = { modifier_slardar_amplify_damage = true }
    local sweep = {
        creep(bot, 'npc_dota_neutral_ogre_mauler',    550,  false, 260),
        creep(bot, 'npc_dota_neutral_prowler_shaman', 1400, true,  620, amped),
    }

    -- Control: without the modifier the literal does refuse the ancient.
    local clean = {
        creep(bot, 'npc_dota_neutral_ogre_mauler',    550,  false, 260),
        creep(bot, 'npc_dota_neutral_prowler_shaman', 1400, true,  620),
    }
    local ctl = J.Site.GetMaxHPCreep(clean)
    assert(ctl ~= nil and not ctl:IsAncientCreep(),
        'level 9 control: the literal no longer refuses a plain ancient')

    for _, sel in ipairs({ 'GetMaxHPCreep', 'GetMinHPCreep' }) do
        local got = J.Site[sel](sweep)
        assert(got ~= nil and got:IsAncientCreep(), string.format(
            '%s: the shortcut no longer returns the amped ancient at level 9 (%s) -- '
            .. 'narrowing `> 9` may now be complete after all, re-read 0NEXT16',
            sel, got and got:GetUnitName() or 'nil'))
    end
end

--============================================================================
-- (2) WIDER: in the narrowed world a 'nearest' farmer stops being one.
--============================================================================

tests['[typeswap] a nearest farmer behind the literal degrades to the minHP pick'] = function()
    local J, bot = subject(SVEN_L4)
    assert(J.Site.ConsiderFarmNeutralType[SVEN]() == 'nearest',
        'sven is no longer a nearest farmer -- pick another one before trusting this')

    local sweep = {
        creep(bot, 'npc_dota_neutral_prowler_shaman', 1400, true,  260),
        creep(bot, 'npc_dota_neutral_ogre_mauler',     550, false, 400),
        creep(bot, 'npc_dota_neutral_kobold_taskmaster', 300, false, 800),
    }

    -- GetNearestCreep tests [1] only: an ancient head yields nil, not a scan.
    assert(J.Site.GetNearestCreep(sweep) == nil,
        'GetNearestCreep now scans past an invalid head -- the whole typeswap '
        .. 'reading below depends on it testing [1] only')

    local shipped = J.Site.FindFarmNeutralTarget(sweep)
    assert(shipped ~= nil, 'the sweep produced no pick at all')
    assert(not shipped:IsAncientCreep(), 'level 4: the literal let an ancient through')
    assert(shipped:GetUnitName() == 'npc_dota_neutral_kobold_taskmaster', string.format(
        'expected the minHP pick (the farmer silently swapped type), got %s',
        shipped:GetUnitName()))

    -- camppick filters the copy the selector walks, so [1] is the nearest
    -- NON-ancient and the farmer stays a nearest farmer. Same ancient refused,
    -- different creep attacked: that is the separation, and it is why the
    -- literal is the worse place to put the bound.
    local tPick = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    local kept = J.Site.GetNearestCreep(tPick)
    assert(kept ~= nil and kept:GetUnitName() == 'npc_dota_neutral_ogre_mauler',
        'camppick\'s list no longer preserves the nearest non-ancient: '
        .. (kept and kept:GetUnitName() or 'nil'))
    assert(not rawequal(kept, shipped),
        'the two levers now pick the same creep -- the separating reading is gone, '
        .. 'which means the ruling (do not move the literal) must be re-derived')
end

--============================================================================
-- (3) camppick closes both holes, including the one the literal cannot reach.
--============================================================================

tests['[camppick] filtering before the walk closes the shortcut hole too'] = function()
    local J, bot = subject(VIPER_L9)
    local amped = { modifier_slardar_amplify_damage = true }
    local sweep = {
        creep(bot, 'npc_dota_neutral_ogre_mauler',    550,  false, 260),
        creep(bot, 'npc_dota_neutral_prowler_shaman', 1400, true,  620, amped),
    }
    local tPick = J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true)
    assert(not rawequal(tPick, sweep), 'armed should hand back a new list')
    for _, u in ipairs(tPick) do
        assert(not u:IsAncientCreep(),
            'the filter left an ancient in the list the selector walks')
    end
    local got = J.Site.GetMaxHPCreep(tPick)
    assert(got ~= nil and not got:IsAncientCreep(),
        'the shortcut still reached an ancient through camppick\'s list')

    -- Presence is preserved by construction, which is camppick's whole reason
    -- for existing; assert it here too so this file cannot be read as an
    -- argument for filtering the caller's table instead.
    assert(#sweep == 2, 'camppick mutated the caller\'s table')
end

return tests

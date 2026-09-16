-- GH #137 section 4, suggestion 3: the camp-tier ladder guards the LARGE tier
-- with an attack-damage clause and the ANCIENT tier with level alone. Gated
-- soak candidate 'campdmg' (turbo-only), resolved at the one RefreshCamp call
-- site in bots/mode_farm_generic.lua and passed in as bAncientDamage.
--
-- THE DEFECT: THE LADDER IS NON-MONOTONIC IN CAMP DIFFICULTY
-- ----------------------------------------------------------
-- bots/FunLib/aba_site.lua, IsCampAllowedForLevel (that function is the OTHER
-- lever, 'campgrade'):
--
--     if IsLargeCamp(camp)   and (botLevel <= 7 or attackDamage <= 80) -> refuse
--     if IsAncientCamp(camp) and botLevel < 12                          -> refuse
--
-- An ancient camp is strictly harder than a large one -- more health, more
-- armor, and the rock-golem camps put modifier_ancient_rock_golem_weakening on
-- whoever walks in (that modifier is on the subject of the bearing frame this
-- file loads). So a bot can be judged too weak for the EASIER camp and handed
-- the HARDER one in the same sweep: at level 12 with 60 attack damage the
-- large tier refuses and the ancient tier admits. That ordering is wrong on its
-- face, and [invariant] below asserts it over the whole (level, damage) grid
-- rather than arguing it in prose.
--
-- WHY 80 AND NOT A NEW NUMBER. The bar is deliberately the same literal the
-- large tier already uses, because "an ancient camp cannot need LESS than a
-- large one" is the entire argument; inventing a second, higher, unmeasured
-- constant would be a threshold guess, and nothing in the corpus can price one
-- (see the limit below). [source] reads the large tier's literal out of
-- bots/FunLib/aba_site.lua and asserts J.Site.ANCIENT_MIN_DAMAGE equals it, so
-- the two cannot drift.
--
-- WHY THIS IS A SECOND ID AND NOT AN EDIT TO 'campgrade'
-- ------------------------------------------------------
-- tests/test_campgrade_tier_ladder.lua carries an assertion named "[the lever
-- is one lever] attack damage stays off the ancient tier", whose failure text
-- says in as many words that reaching the ancient tier with attack damage is
-- "GH #137 suggestion 3, a SECOND lever". So the rule lives in its own pure
-- predicate (IsAncientCampTooTough), behind its own gate id, resolved from its
-- own argument. [independence] drives all four arm combinations: either gate
-- alone does its own job, and neither is written in terms of the other's id
-- (the 'pullcad' trap -- a gate spelled as a conjunction freezes FALSE the day
-- the other id is promoted).
--
-- WHAT THIS FILE CAN AND CANNOT BUY LOCALLY -- read before trusting a number
-- --------------------------------------------------------------------------
-- The LEVEL half is real: every bot driven below is a real hero off a real
-- .dem frame carrying the level the game gave it.
--
-- The DAMAGE half is NOT in the corpus and is not pretended to be. World fact
-- (W2) asserts that GetAttackDamage() reads 0 on every fixture hero -- a .dem
-- slice carries no attack damage, which tests/mock/bot_api.lua states at its
-- own default and test_campgrade_tier_ladder.lua's W2 already pins. Left alone
-- that would make `attackDamage <= 80` vacuously TRUE for every real frame, so
-- the damage operand below is a DECLARED override, stated at each call. The
-- camp table is declared for the same reason (W1: GetNeutralSpawners() is empty
-- on every fixture).
--
-- Both limits are ASSERTED, not described, so the day the dumper starts
-- carrying either one the world facts go red and the stand-ins retire
-- themselves. That is the same handling test_campfarm_ancient_target.lua gives
-- its creeps and test_campgrade_tier_ladder.lua gives its camps.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Real frames. The same heroes test_campgrade_tier_ladder.lua straddles the
-- level tier with, so the two files cannot disagree about what the corpus says.
local WK_L10 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua', 'npc_dota_hero_skeleton_king' }
local WK_L12 = { 'tests/fixtures/f_260820_162859_es_blink_flee_615.lua', 'npc_dota_hero_skeleton_king' }
local AXE_L11 = { 'tests/fixtures/f_050713_es_defend_1v3.lua', 'npc_dota_hero_axe' }
-- GH #137's own bearing-weight frame: skeleton_king, level 11, standing in an
-- ancient camp (modifier_ancient_rock_golem_weakening, 11.0s elapsed at
-- t=634.1), 817/1307 HP on the way from 100% to 13.5%, for 166 gold, with the
-- nearest enemy hero 4573u away. The issue measured that WK hitting for 80-81.
local WK_L11_BEARING = { 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua', 'npc_dota_hero_skeleton_king' }

local ALL_FRAMES = { WK_L10, WK_L12, AXE_L11, WK_L11_BEARING }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    local bot = heroes[spec[2]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[2] .. ' -- ' .. spec[1])
    return J, bot
end

-- The declared damage operand (W2). Stated at every call site so no assertion
-- below can be read as having measured it.
local function declare_damage(bot, n)
    bot.GetAttackDamage = function() return n end
    return bot
end

-- The declared camp stand-in (W1). Fields: exactly the three RefreshCamp reads.
local function camp_table(nOwnTeam)
    local nEnemyTeam = nOwnTeam == 2 and 3 or 2
    local camps, i = {}, 0
    for _, team in ipairs({ nOwnTeam, nEnemyTeam }) do
        for _, sType in ipairs({ 'small', 'medium', 'large', 'ancient' }) do
            i = i + 1
            camps['c' .. i] = { idx = i, type = sType, team = team,
                                location = Vector(100 * i, 100 * i, 0) }
        end
    end
    return camps, i
end

local function with_camps(nOwnTeam, fn)
    local camps, nTotal = camp_table(nOwnTeam)
    local prev = GetNeutralSpawners
    GetNeutralSpawners = function() return camps end
    local ok, err = pcall(fn, nTotal)
    GetNeutralSpawners = prev
    if not ok then error(err, 0) end
end

-- What came back, as a set of "<type>/<own|enemy>" labels.
local function labels(list, nOwnTeam)
    local out = {}
    for _, entry in ipairs(list) do
        local c = entry.cattr
        out[c.type .. '/' .. (c.team == nOwnTeam and 'own' or 'enemy')] = true
    end
    return out
end

local function refresh(J, bot, bStrict, bDamage)
    local nOwnTeam = bot:GetTeam()
    local got
    with_camps(nOwnTeam, function()
        local list, n = J.Site.RefreshCamp(bot, bStrict, bDamage)
        assert(n == #list, 'RefreshCamp second return must be the list length')
        got = labels(list, nOwnTeam)
        got.__n = n
    end)
    return got
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
-- World facts this file rests on. Asserted, not described.
--============================================================================

tests['[world W1] the corpus carries no neutral spawners, so the camps are declared'] = function()
    local J, bot = subject(WK_L10)
    local camps = GetNeutralSpawners()
    assert(type(camps) == 'table' and next(camps) == nil,
        'GetNeutralSpawners() is no longer empty on a fixture -- if the dumper ' ..
        'started carrying the spawner table, this file should drive the real ' ..
        'one instead of the stand-in and every claim below gets stronger')
    local _, n = J.Site.RefreshCamp(bot)
    assert(n == 0, 'with no camps in the world the shipped entry point returns ' ..
        'an empty list -- that is why the camp table here is declared, not loaded')
end

tests['[world W2] every fixture hero reads attack damage 0, so the damage is declared'] = function()
    for _, spec in ipairs(ALL_FRAMES) do
        local _, bot = subject(spec)
        assert(bot:GetAttackDamage() == 0, string.format(
            '%s on %s reads attack damage %s. This is the operand THIS LEVER ' ..
            'reads: if the dump started carrying it, every declare_damage() ' ..
            'call below should be deleted and these assertions re-driven on the ' ..
            'real number -- they all get stronger',
            spec[2], spec[1], tostring(bot:GetAttackDamage())))
    end
end

tests['[world W3] the level tier alone cannot reach the case this lever owns'] = function()
    -- The domain of this lever is level >= 12 (at or above the ancient tier,
    -- where 'campgrade' has already stopped refusing) AND weak attack. If the
    -- level tier covered it there would be nothing here to fix, so the gap is
    -- asserted rather than assumed: at level 12 the ladder admits the ancient
    -- camp at ANY attack damage.
    local J, bot = subject(WK_L12)
    assert(bot:GetLevel() >= 12, 'the frame moved: WK_L12 is now level ' .. bot:GetLevel())
    declare_damage(bot, 1)
    local got = refresh(J, bot, true, false)
    assert(got['ancient/own'], 'the level tier now refuses an ancient camp at ' ..
        'level ' .. bot:GetLevel() .. ' -- this lever has no domain left')
end

--============================================================================
-- Today's defect: the ladder is non-monotonic in camp difficulty.
--============================================================================

tests["[today's defect] the easier camp is refused and the harder one is handed over"] = function()
    -- The whole argument, on a real level with a declared damage.
    local J, bot = subject(WK_L12)
    declare_damage(bot, 60)
    local got = refresh(J, bot, true, false)
    assert(not got['large/own'], 'the large tier stopped refusing 60 attack ' ..
        'damage -- the premise of this lever is gone')
    assert(got['ancient/own'], 'the ancient tier already refuses 60 attack ' ..
        'damage without this lever -- the defect is fixed elsewhere')
end

tests['[invariant] the shipped ladder violates monotonicity over the whole grid'] = function()
    -- Not an example: every (level, damage) pair the ladder can see. "Harder
    -- camp admitted while the easier one is refused" is the defect, stated as a
    -- property.
    local J = subject(WK_L10)
    local large = { type = 'large', team = 2, idx = 1, location = Vector(0, 0, 0) }
    local ancient = { type = 'ancient', team = 2, idx = 2, location = Vector(0, 0, 0) }
    local nViolations = 0
    for level = 1, 30 do
        for dmg = 0, 200, 5 do
            local bLarge = J.Site.IsCampAllowedForLevel(large, level, dmg)
            local bAncient = J.Site.IsCampAllowedForLevel(ancient, level, dmg)
            if bAncient and not bLarge then nViolations = nViolations + 1 end
        end
    end
    -- Measured on the shipped ladder: every level >= 12 crossed with every
    -- declared damage <= 80 (17 of the 41 damage steps), i.e. 19 * 17 = 323.
    assert(nViolations == 323, 'the shipped ladder now has ' .. nViolations ..
        ' non-monotonic (level, damage) cells, not 323 -- a tier moved and this ' ..
        "file's premise needs re-reading, not re-baselining")
end

tests['[the fix] armed, the same grid has no violation left'] = function()
    local J = subject(WK_L10)
    local large = { type = 'large', team = 2, idx = 1, location = Vector(0, 0, 0) }
    local ancient = { type = 'ancient', team = 2, idx = 2, location = Vector(0, 0, 0) }
    for level = 1, 30 do
        for dmg = 0, 200, 5 do
            local bLarge = J.Site.IsCampAllowedForLevel(large, level, dmg)
            local bAncient = J.Site.IsCampAllowedForLevel(ancient, level, dmg)
                and not J.Site.IsAncientCampTooTough(ancient, dmg)
            assert(not (bAncient and not bLarge), string.format(
                'level %d / damage %d: the ancient camp is still admitted while ' ..
                'the easier large camp is refused', level, dmg))
        end
    end
end

--============================================================================
-- The fix, driven end to end on real frames.
--============================================================================

tests['[the fix] armed, the weak level-12 bot loses the ancient camps'] = function()
    local J, bot = subject(WK_L12)
    declare_damage(bot, 60)
    local got = refresh(J, bot, true, true)
    assert(not got['ancient/own'] and not got['ancient/enemy'],
        'armed, an ancient camp survived for a 60-damage bot')
end

tests['[the fix does not starve the farm] small and medium camps survive'] = function()
    -- The declared consequence to check for is an empty list, which would send
    -- the farm block somewhere else entirely. Armed, the bot keeps everything
    -- it could actually clear.
    for _, spec in ipairs(ALL_FRAMES) do
        local J, bot = subject(spec)
        declare_damage(bot, 40)
        local got = refresh(J, bot, true, true)
        assert(got['small/own'] and got['medium/own'], string.format(
            '%s at level %d lost its small/medium camps -- this lever only owns ' ..
            'the ancient tier', spec[2], bot:GetLevel()))
        assert(got.__n > 0, 'armed returned an EMPTY camp list')
    end
end

tests['[the fix does not overshoot] a bot over the bar keeps its ancient camp'] = function()
    local J, bot = subject(WK_L12)
    declare_damage(bot, 120)
    local got = refresh(J, bot, true, true)
    assert(got['ancient/own'], 'armed refused an ancient camp to a level-' ..
        bot:GetLevel() .. ' bot hitting for 120 -- the >= 12 population is the ' ..
        'one GH #137 section 4 says must NOT collapse')
end

tests['[boundary] 80 refuses and 81 admits, on a real level'] = function()
    local J, bot = subject(WK_L12)
    declare_damage(bot, 80)
    assert(not refresh(J, bot, true, true)['ancient/own'],
        'exactly at the bar (80) the ancient camp must be refused -- the clause ' ..
        'is `<=`, transcribed from the large tier it copies')
    declare_damage(bot, 81)
    assert(refresh(J, bot, true, true)['ancient/own'],
        'one point over the bar (81) the ancient camp must come back')
end

tests['[bearing case] GH #137 frame: level 11, and the issue measured it at 80-81'] = function()
    local J, bot = subject(WK_L11_BEARING)
    assert(bot:GetLevel() == 11, 'the bearing frame moved: skeleton_king is now ' ..
        'level ' .. bot:GetLevel() .. ', not 11')
    assert(bot:HasModifier('modifier_ancient_rock_golem_weakening'),
        'the bearing frame no longer has the subject standing in the ancient camp')
    -- Two independent reasons refuse this camp, and that is worth stating: the
    -- level tier ('campgrade') already stops a level-11 bot, so this frame does
    -- NOT discriminate the new lever by itself -- it is the case that motivated
    -- the bar, not the case that tests it. The discriminating cell is level >=
    -- 12 (W3 + the grid above).
    declare_damage(bot, 80)
    assert(not refresh(J, bot, true, false)['ancient/own'],
        'the level tier alone must already refuse the bearing frame')
    assert(not refresh(J, bot, false, true)['ancient/own'],
        'this lever alone must also refuse the bearing frame at the 80 the issue ' ..
        'measured that Wraith King hitting for')
end

--============================================================================
-- Independence: two gates, four arm combinations, no conjunction.
--============================================================================

tests['[independence] campdmg armed ALONE still drops ancient camps'] = function()
    -- The pullcad point, driven rather than described: this lever must not need
    -- 'campgrade' to be armed. If it did, promoting campgrade would freeze it.
    local J, bot = subject(WK_L12)
    declare_damage(bot, 60)
    local got = refresh(J, bot, false, true)
    assert(not got['ancient/own'] and not got['ancient/enemy'],
        'campdmg armed alone did nothing -- it is hanging under campgrade')
    -- and it really is alone: with campgrade off the rest of the ladder is
    -- still the shipped all-camps default.
    assert(got['large/own'] and got['large/enemy'] and got['small/enemy'],
        'campdmg armed alone changed something other than the ancient tier')
end

tests['[independence] campgrade armed ALONE is unchanged by this lever'] = function()
    for _, spec in ipairs(ALL_FRAMES) do
        local J, bot = subject(spec)
        declare_damage(bot, 60)
        local a = refresh(J, bot, true, false)
        local b = refresh(J, bot, true, nil)
        assert(a.__n == b.__n, 'a nil third argument is not the same as false')
        for k in pairs(a) do assert(b[k], 'label ' .. tostring(k) .. ' moved') end
    end
end

tests['[unarmed is identity] every off combination is the shipped default'] = function()
    for _, spec in ipairs(ALL_FRAMES) do
        local J, bot = subject(spec)
        declare_damage(bot, 0)
        local nOwnTeam = bot:GetTeam()
        local nTotal
        with_camps(nOwnTeam, function(n) nTotal = n end)
        for _, combo in ipairs({ { nil, nil }, { false, false }, { false, nil }, { nil, false } }) do
            local got = refresh(J, bot, combo[1], combo[2])
            assert(got.__n == nTotal, string.format(
                '%s at level %d: unarmed returned %d camps, not the shipped %d ' ..
                '-- the default must stay every camp on the map',
                spec[2], bot:GetLevel(), got.__n, nTotal))
        end
    end
end

--============================================================================
-- Structure: the gate cannot be missed, and the two bars cannot drift.
--============================================================================

tests['[source] the ancient bar is the SAME number the large tier uses'] = function()
    local J = subject(WK_L10)
    local code = strip_comments(read('bots/FunLib/aba_site.lua'))
    local body = code:match('IsCampAllowedForLevel%s*=%s*function.-\nend')
    assert(body, 'IsCampAllowedForLevel is gone or reshaped')
    local large = body:match('IsLargeCamp[^\n]*\n')
    assert(large, 'the large tier line is gone')
    local bar = large:match('attackDamage%s*<=%s*(%d+)')
    assert(bar, 'the large tier no longer carries an attack-damage literal: ' .. large)
    assert(tonumber(bar) == J.Site.ANCIENT_MIN_DAMAGE, string.format(
        'the large tier bars at %s and J.Site.ANCIENT_MIN_DAMAGE is %s -- the ' ..
        'whole argument for this lever is that an ancient camp cannot need LESS ' ..
        'than a large one, so a second, different number needs its own evidence',
        bar, tostring(J.Site.ANCIENT_MIN_DAMAGE)))
end

tests['[source] the other lever stays one lever'] = function()
    -- test_campgrade_tier_ladder.lua asserts this too. It is repeated here
    -- because THIS file is the one that would be tempted to break it.
    local code = strip_comments(read('bots/FunLib/aba_site.lua'))
    local body = code:match('IsCampAllowedForLevel%s*=%s*function.-\nend')
    local ancient = body:match('IsAncientCamp[^\n]*\n')
    assert(ancient and not ancient:find('attackDamage'),
        "attack damage reached 'campgrade' own ancient tier -- this lever is " ..
        'supposed to live in IsAncientCampTooTough, behind its own id')
end

tests['[source] the gate is resolved once, turbo-only, and is not a conjunction'] = function()
    local code = strip_comments(read('bots/mode_farm_generic.lua'))
    local call = code:match('J%.Site%.RefreshCamp%s*(%b())')
    assert(call, 'the RefreshCamp call site moved or changed shape')
    assert(call:find("J%.IsSoakCandidate%s*%(%s*'campdmg'%s*%)"),
        "the third argument must be gated on 'campdmg'; got: " .. call)
    assert(call:find('J%.IsModeTurbo%s*%(%s*%)'), 'the lever must be turbo-only')
    local _, nGates = code:gsub("J%.IsSoakCandidate%s*%(%s*'campdmg'%s*%)", '')
    assert(nGates == 1, "'campdmg' is resolved in " .. nGates .. ' places -- a ' ..
        'second resolution point is a second gate to keep in step')
    -- the pullcad trap, as source: the two ids must not appear inside one
    -- boolean expression, or promoting either freezes the other.
    for line in code:gmatch('[^\n]*campdmg[^\n]*') do
        assert(not line:find('campgrade'), 'campdmg and campgrade share a line -- ' ..
            'if that is a conjunction, promoting one freezes the other FALSE: ' .. line)
    end
    -- and nothing else in bots/ resolves it
    local p = assert(io.popen("grep -rl \"IsSoakCandidate('campdmg')\" bots/ | sort"))
    local files = {}
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    assert(#files == 1 and files[1] == 'bots/mode_farm_generic.lua',
        "'campdmg' is resolved outside the one wrapper: " .. table.concat(files, ' '))
end

tests['[ts parity] the TypeScript source carries the same lever'] = function()
    local ts = read('typescript/bots/FunLib/aba_site.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    assert(ts:find('IsAncientCampTooTough'), 'the TS source was not kept in lockstep')
    assert(ts:find('bAncientDamage'), 'the TS RefreshCamp lost the new parameter')
    assert(ts:find('ANCIENT_MIN_DAMAGE%s*=%s*80'), 'the TS bar drifted from the Lua one')
end

--============================================================================
-- Domain: how much of the corpus sits in the cell this lever owns.
--============================================================================

tests['[domain] the level >= 12 population this lever owns is real'] = function()
    -- Floor, not an equality (GH #106): adding a fixture must not turn this
    -- red. The damage half of the cell is NOT counted here and cannot be --
    -- that is W2. This says only that the level half has a population.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local nSlots, nAbove = 0, 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                if u.level then
                    nSlots = nSlots + 1
                    if u.level >= 12 then nAbove = nAbove + 1 end
                end
            end
        end
    end
    p:close()
    assert(nSlots >= 1000, 'corpus shrank: ' .. nSlots .. ' hero-slots')
    assert(nAbove >= 70, 'the >= 12 population collapsed: ' .. nAbove)
end

return tests

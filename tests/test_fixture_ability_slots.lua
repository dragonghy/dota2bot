-- GH #36 contract: a fixture's ability slots must reproduce the ENGINE's view.
--
-- The behavioural dump is flattened (filtered entries are skipped, so the array
-- index is not the engine slot) and carries no ultimate marker (`AbilityType`
-- is KV data that never enters a .dem). Before this contract,
-- `X.GetAbilityList(bot)[6]` was nil for EVERY hero: any test that pinned a
-- real frame and drove `ConsiderR` / an ultimate gate returned
-- BOT_ACTION_DESIRE_NONE at the first `IsFullyCastable()` and PASSED without
-- executing one line of the logic it claimed to validate -- a false green, same
-- family as GH #27 (no `vis` -> every fixture judged in an all-visible world).
--
-- These assertions make that class of false green impossible to reintroduce
-- silently: they run over a real checked-in fixture and name the expected
-- ultimate per hero, from the game's own KV (tests/mock/ability_meta.lua).
--
-- Deliberately NOT asserted by position: the dump order differs per hero
-- (centaur ends stampede[ult], horsepower[innate]; storm ends
-- ball_lightning[ult], galvanized[innate]; lich ends chain_frost[ult]) -- which
-- is exactly why "take the last ability" would be a guess. Two heroes below are
-- included because their ultimate is NOT the last dumped entry, and case 3
-- asserts that fact so the coverage cannot rot into a tautology.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local meta = require('mock.ability_meta')

local FIXTURE = 'tests/fixtures/f_260819_004858_cm_centaur_far.lua'
local tests = {}

-- hero -> its real ultimate; `ult_is_last` = does it happen to be dumped last?
local CASES = {
    { hero = 'npc_dota_hero_crystal_maiden', ult = 'crystal_maiden_freezing_field', ult_is_last = true },
    { hero = 'npc_dota_hero_centaur',        ult = 'centaur_stampede',              ult_is_last = false },
    { hero = 'npc_dota_hero_storm_spirit',   ult = 'storm_spirit_ball_lightning',   ult_is_last = false },
    { hero = 'npc_dota_hero_lich',           ult = 'lich_chain_frost',              ult_is_last = true },
    { hero = 'npc_dota_hero_lina',           ult = 'lina_laguna_blade',             ult_is_last = true },
}

local function dumped_abilities(fx, hero)
    for _, u in ipairs(fx.units) do
        if u.name == hero then return u.abilities or {} end
    end
    return nil
end

tests['the generated KV table names each hero\'s real ultimate'] = function()
    for _, c in ipairs(CASES) do
        local set = meta.ULTIMATES[c.hero]
        assert(set ~= nil, 'ability_meta has no entry for ' .. c.hero
            .. ' -- regenerate with tools/agent/gen_ability_meta.py')
        assert(set[c.ult] == true,
            'ability_meta does not mark ' .. c.ult .. ' as ' .. c.hero .. "'s ultimate")
    end
end

tests['GetAbilityList fills slot 6 with the ultimate on a real frame'] = function()
    local J, _, heroes = rf.load(FIXTURE)
    for _, c in ipairs(CASES) do
        local h = heroes[c.hero]
        assert(h ~= nil, c.hero .. ' missing from ' .. FIXTURE)
        local list = J.Skill.GetAbilityList(h)
        assert(list[6] == c.ult, 'sAbilityList[6] for ' .. c.hero .. ': got '
            .. tostring(list[6]) .. ', want ' .. c.ult)
    end
end

tests['the ultimate no longer leaks into the basic-ability slots'] = function()
    -- Pre-fix shape: IsUltimate() was false, so the ultimate fell through to
    -- `table.insert(sAbilityList, name)` and squatted a basic index -- which is
    -- how CM's sAbilityList[4] came to be freezing_field.
    local J, _, heroes = rf.load(FIXTURE)
    for _, c in ipairs(CASES) do
        local list = J.Skill.GetAbilityList(heroes[c.hero])
        for i = 1, 5 do
            assert(list[i] ~= c.ult, c.ult .. ' must not also sit at sAbilityList['
                .. i .. '] for ' .. c.hero)
        end
    end
end

tests['slot 6 is not merely "the last ability in the dump"'] = function()
    local J, _, heroes, fx = rf.load(FIXTURE)
    local checked = 0
    for _, c in ipairs(CASES) do
        if not c.ult_is_last then
            local dumped = dumped_abilities(fx, c.hero)
            assert(dumped ~= nil and #dumped > 0, 'no dumped abilities for ' .. c.hero)
            local last = dumped[#dumped].name
            assert(last ~= c.ult, 'case is stale: ' .. c.hero .. ' now dumps its '
                .. 'ultimate last, so it no longer discriminates position-guessing')
            assert(J.Skill.GetAbilityList(heroes[c.hero])[6] == c.ult,
                c.hero .. ' resolved slot 6 to something other than its ultimate')
            checked = checked + 1
        end
    end
    assert(checked >= 2, 'need >= 2 heroes whose ultimate is not dumped last')
end

tests['a non-ultimate never lands in slot 6'] = function()
    local J, _, heroes, fx = rf.load(FIXTURE)
    for _, u in ipairs(fx.units) do
        local h = heroes[u.name]
        if h ~= nil then
            local six = J.Skill.GetAbilityList(h)[6]
            if six ~= nil then
                local set = meta.ULTIMATES[u.name] or {}
                assert(set[six] == true, u.name .. ' put non-ultimate ' .. six
                    .. ' into sAbilityList[6]')
            end
        end
    end
end

tests['no NEW fixture may ship without ability data'] = function()
    -- The residual half of GH #36: nine legacy (v1) fixtures were dumped before
    -- the timeline carried abilities at all. On those, slot 6 is nil no matter
    -- how good the resolution is -- there is nothing to resolve -- so driving an
    -- ultimate gate on them is STILL a false green. That is tolerable only as a
    -- closed, shrinking set, so this ratchet pins it: regenerate an old fixture
    -- with make_fixture.py and remove it from the list; add a new one that
    -- forgot abilities and this test names it.
    local LEGACY_NO_ABILITIES = {
        ['f_071423_luna_chase.lua'] = true,
        ['f_071423_sky_rescue.lua'] = true,
        ['f_071859_oracle_screen.lua'] = true,
        ['f_071859_oracle_wandered.lua'] = true,
        ['f_071859_qop_salve.lua'] = true,
        ['f_071903_sven_idle.lua'] = true,
        ['f_073148_zuus_lina.lua'] = true,
        ['f_080225_wk_lane.lua'] = true,
        ['f_080225_wk_revive.lua'] = true,
    }
    local p = io.popen('ls tests/fixtures')
    local offenders, healed = {}, {}
    for file in p:lines() do
        if file:match('^f_.*%.lua$') then
            local fx = dofile('tests/fixtures/' .. file)
            local has = false
            for _, u in ipairs(fx.units or {}) do
                if u.abilities ~= nil and #u.abilities > 0 then has = true end
            end
            if not has and not LEGACY_NO_ABILITIES[file] then
                offenders[#offenders + 1] = file
            elseif has and LEGACY_NO_ABILITIES[file] then
                healed[#healed + 1] = file
            end
        end
    end
    p:close()
    assert(#offenders == 0, 'fixture(s) carry no ability data, so any ultimate '
        .. 'logic driven on them silently no-ops: ' .. table.concat(offenders, ', '))
    assert(#healed == 0, 'these fixtures now carry ability data -- drop them '
        .. 'from LEGACY_NO_ABILITIES: ' .. table.concat(healed, ', '))
end

tests['the ultimate handle carries the frame\'s real level and cooldown'] = function()
    -- Without this, a driven ultimate gate would read mock defaults rather than
    -- the dumped state -- passing for the wrong reason all over again.
    local J, _, heroes, fx = rf.load(FIXTURE)
    local hero = 'npc_dota_hero_crystal_maiden'
    local list = J.Skill.GetAbilityList(heroes[hero])
    local r = heroes[hero]:GetAbilityByName(list[6])

    local want_level, want_cd
    for _, a in ipairs(dumped_abilities(fx, hero)) do
        if a.name == list[6] then want_level, want_cd = a.level, a.cd end
    end
    assert(want_level ~= nil, 'ultimate not found in the dump for ' .. hero)

    assert(r:GetLevel() == want_level, 'ultimate level: got '
        .. tostring(r:GetLevel()) .. ', want ' .. tostring(want_level))
    assert(r:GetCooldownTimeRemaining() == want_cd, 'ultimate cooldown: got '
        .. tostring(r:GetCooldownTimeRemaining()) .. ', want ' .. tostring(want_cd))
    assert(r:IsFullyCastable() == (want_level > 0 and want_cd <= 0),
        'ultimate castability must follow the dumped level/cooldown')
end

return tests

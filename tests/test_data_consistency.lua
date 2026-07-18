-- Data-consistency checks across the tables that patch updates touch most:
-- hero role maps, spell lists, and BotLib file coverage. Pure data, no game
-- needed — this is where hero renames / additions usually go wrong.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function list_hero_files()
    local set = {}
    local p = io.popen('ls bots/BotLib')
    for line in p:lines() do
        local part = line:match('^hero_(.*)%.lua$')
        if part then set[part] = true end
    end
    p:close()
    return set
end

local function load_module(path)
    api.reset_modules()
    api.install({})
    return dofile(path)
end

tests['spell_list heroes have matching BotLib files'] = function()
    local spell_list = load_module('bots/FunLib/spell_list.lua')
    assert(type(spell_list) == 'table' and type(spell_list.spells) == 'table',
        'spell_list.lua did not return the expected table')

    local hero_files = list_hero_files()
    -- BotLib filenames use the internal npc name directly (hero_zuus.lua)
    local missing = {}
    local count = 0
    for npc in pairs(spell_list.spells) do
        count = count + 1
        local part = npc:match('^npc_dota_hero_(.*)$')
        if not part or not hero_files[part] then
            missing[#missing + 1] = npc
        end
    end
    assert(count > 100, 'spell list unexpectedly small: ' .. count .. ' heroes')
    if #missing > 0 then
        table.sort(missing)
        error('spell_list heroes without a BotLib file: ' .. table.concat(missing, ', '))
    end
end

tests['hero role map covers every spell_list hero'] = function()
    local roles = load_module('bots/FunLib/aba_hero_roles_map.lua')
    assert(type(roles) == 'table' and type(roles.HeroRolesMap) == 'table',
        'aba_hero_roles_map.lua did not return the expected table')

    local spell_list = load_module('bots/FunLib/spell_list.lua')
    local missing = {}
    for npc in pairs(spell_list.spells) do
        if roles.HeroRolesMap[npc] == nil then
            missing[#missing + 1] = npc
        end
    end
    if #missing > 0 then
        table.sort(missing)
        error('heroes missing from HeroRolesMap: ' .. table.concat(missing, ', '))
    end
end

tests['role map entries have all role fields'] = function()
    local roles = load_module('bots/FunLib/aba_hero_roles_map.lua')
    local REQUIRED = { 'carry', 'disabler', 'durable', 'escape', 'initiator',
        'jungler', 'nuker', 'support', 'pusher', 'ranged', 'healer' }
    local bad = {}
    for npc, entry in pairs(roles.HeroRolesMap) do
        for _, field in ipairs(REQUIRED) do
            if type(entry[field]) ~= 'number' then
                bad[#bad + 1] = npc .. ' missing ' .. field
            end
        end
    end
    if #bad > 0 then
        table.sort(bad)
        error(table.concat(bad, ', '))
    end
end

return tests

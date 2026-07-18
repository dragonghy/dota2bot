-- Smoke test: every BotLib hero file (and the core libraries they pull in)
-- must load without error under the mock Bot API. Catches load-time crashes
-- (nil indexing, bad requires, syntax slips) that otherwise only surface
-- in-game at hero pick.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- BotLib filenames use the internal npc name (hero_zuus.lua, not hero_zeus.lua),
-- so the mapping is direct. hero_lone_druid_bear is the druid's bear unit, not
-- a hero of its own.
local function npc_name(file_part)
    if file_part == 'lone_druid_bear' then return 'npc_dota_lone_druid_bear' end
    return 'npc_dota_hero_' .. file_part
end

local function list_hero_files()
    local files = {}
    local p = io.popen('ls bots/BotLib')
    for line in p:lines() do
        local part = line:match('^hero_(.*)%.lua$')
        if part then files[#files + 1] = part end
    end
    p:close()
    table.sort(files)
    return files
end

-- Abort any single file load that runs away (infinite loop under mock
-- conditions would otherwise hang CI).
local MAX_INSTRUCTIONS = 200 * 1000 * 1000
local function guarded_dofile(path)
    debug.sethook(function()
        debug.sethook()
        error('instruction budget exceeded loading ' .. path .. ' (likely an infinite loop)', 2)
    end, '', MAX_INSTRUCTIONS)
    local ok, err = pcall(dofile, path)
    debug.sethook()
    return ok, err
end

tests['all BotLib hero files load under mock API'] = function()
    local hero_parts = list_hero_files()
    assert(#hero_parts > 100, 'expected 100+ hero files, found ' .. #hero_parts)

    local errors = {}
    for _, part in ipairs(hero_parts) do
        api.reset_modules()
        local bot = api.MakeHero(npc_name(part))
        api.install({ bot = bot })
        if part == 'lone_druid_bear' then
            -- the bear script expects the druid's shared cache entry to exist
            local Utils = require(GetScriptDirectory() .. '/FunLib/utils')
            local druid = api.MakeHero('npc_dota_hero_lone_druid')
            druid.assignedRole = 2
            Utils.GetLoneDruid(bot).hero = druid
        end
        local ok, err = guarded_dofile('bots/BotLib/hero_' .. part .. '.lua')
        if not ok then
            errors[#errors + 1] = part .. ': ' .. tostring(err)
        end
    end

    if #errors > 0 then
        error(#errors .. ' hero file(s) failed to load:\n' .. table.concat(errors, '\n'))
    end
end

tests['core generic scripts load under mock API'] = function()
    local core = {
        'bots/hero_selection.lua',
        'bots/item_purchase_generic.lua',
        'bots/ability_item_usage_generic.lua',
        'bots/bot_generic.lua',
        'bots/mode_laning_generic.lua',
        'bots/mode_attack_generic.lua',
        'bots/mode_retreat_generic.lua',
        'bots/mode_farm_generic.lua',
        'bots/mode_roam_generic.lua',
        'bots/mode_rune_generic.lua',
        'bots/mode_roshan_generic.lua',
    }
    local errors = {}
    for _, file in ipairs(core) do
        api.reset_modules()
        api.install({})
        local ok, err = guarded_dofile(file)
        if not ok then
            errors[#errors + 1] = file .. ': ' .. tostring(err)
        end
    end
    if #errors > 0 then
        error(#errors .. ' core file(s) failed to load:\n' .. table.concat(errors, '\n'))
    end
end

return tests

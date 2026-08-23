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

-- Files under bots/ that the engine loads by fixed name but that genuinely
-- cannot load under the mock API. Keyed by filename, valued by the reason.
-- EMPTY as of 2026-08-23: all 27 engine-loaded top-level files load clean.
-- An entry here is a *declared* hole rather than a silent one -- and the test
-- below fails if a skipped file no longer exists, or has since started loading
-- (a stale skip is where a regression hides).
local CORE_SKIP = {}

-- The engine finds top-level scripts by fixed name, so prefixing a filename
-- with '--' is how this repo disables one (bots/--mode_item_generic.lua). Such
-- a file never reaches the bot VM, so its loadability is not our problem.
local function is_disabled(name)
    return name:sub(1, 2) == '--'
end

-- Split a raw `ls bots` listing into what this test must load, what the engine
-- never loads, and what we have declared un-loadable. Takes the listing as an
-- argument so the classification itself is testable without touching the tree.
local function classify_core(names, skip)
    local load_me, disabled, skipped = {}, {}, {}
    for _, name in ipairs(names) do
        if name:match('%.lua$') then
            if is_disabled(name) then
                disabled[#disabled + 1] = name
            elseif skip[name] then
                skipped[#skipped + 1] = name
            else
                load_me[#load_me + 1] = name
            end
        end
    end
    table.sort(load_me)
    table.sort(disabled)
    table.sort(skipped)
    return load_me, disabled, skipped
end

local function list_core_files()
    local names = {}
    local p = io.popen('ls bots')
    for line in p:lines() do names[#names + 1] = line end
    p:close()
    return names
end

-- The engine loads every bots/*.lua by fixed name, so this coverage has to grow
-- with the tree. It used to be a hardcoded 11-element array that covered 11 of
-- 27 files (GH #131): the first new mode file this project ever added
-- (mode_item_generic.lua) landed outside it and had load coverage only because
-- its author happened to pcall(dofile) it in an unrelated test. A load-time
-- crash in the bot VM is silent -- 'error in error handling' eats the text and
-- print() never reaches the server console -- so an uncovered file does not
-- announce itself, it just quietly changes a wave's numbers.
tests['core generic scripts load under mock API'] = function()
    local load_me, _, skipped = classify_core(list_core_files(), CORE_SKIP)

    -- Discovery that finds nothing must fail, not pass vacuously: an empty or
    -- near-empty list means `ls` broke, and a green run off it would be exactly
    -- the false assurance this test exists to prevent.
    assert(#load_me + #skipped >= 20,
        'expected 20+ top-level bots/*.lua files, discovered ' .. (#load_me + #skipped)
        .. ' -- discovery is broken, not the tree')

    -- A skip must name a real file, and must still be justified.
    for name, reason in pairs(CORE_SKIP) do
        local fh = io.open('bots/' .. name, 'r')
        assert(fh, 'CORE_SKIP names a file that does not exist: ' .. name .. ' (' .. reason .. ')')
        fh:close()
        api.reset_modules()
        api.install({})
        local ok = guarded_dofile('bots/' .. name)
        assert(not ok, 'CORE_SKIP entry ' .. name .. ' now loads fine -- remove it (' .. reason .. ')')
    end

    local errors = {}
    for _, name in ipairs(load_me) do
        api.reset_modules()
        api.install({})
        local ok, err = guarded_dofile('bots/' .. name)
        if not ok then
            errors[#errors + 1] = name .. ': ' .. tostring(err)
        end
    end

    if #errors > 0 then
        error(#errors .. ' core file(s) failed to load:\n' .. table.concat(errors, '\n'))
    end
end

-- Guards the classification itself. Without this the discovery logic is only
-- ever exercised on one input (the real tree), where CORE_SKIP is empty and the
-- disabled branch has a single member -- so both branches could rot unnoticed.
tests['core file classification is discovery-driven'] = function()
    local names = {
        'BotLib',                       -- a directory, no .lua suffix
        '--mode_item_generic.lua',      -- disabled by filename
        'mode_item_generic.lua',        -- the live one
        'mode_brand_new_generic.lua',   -- the case GH #131 is about
        'bot_generic.lua',
        'README.md',
    }
    local load_me, disabled, skipped = classify_core(names, { ['bot_generic.lua'] = 'pretend' })

    assert(#disabled == 1 and disabled[1] == '--mode_item_generic.lua',
        'disabled files must be routed out of the load set, got ' .. #disabled)
    assert(#skipped == 1 and skipped[1] == 'bot_generic.lua',
        'CORE_SKIP entries must be routed out of the load set, got ' .. #skipped)
    assert(#load_me == 2, 'expected 2 loadable files, got ' .. #load_me)
    -- The whole point: a file nobody listed anywhere still gets loaded.
    assert(load_me[1] == 'mode_brand_new_generic.lua' and load_me[2] == 'mode_item_generic.lua',
        'a newly added mode file must be discovered, got ' .. table.concat(load_me, ','))
end

return tests

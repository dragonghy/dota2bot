-- [GH #48, class-level] Every `J.<name>` referenced under bots/ must be defined
-- under bots/.
--
-- GH #48 was one instance of a defect class this repo cannot see any other way:
-- a J-helper referenced under a name nobody ever defined. Lua resolves it at
-- CALL time, so the file loads, luacheck is happy (`J` is a legit local, its
-- fields are not checked), the smoke test loads it, and the failure only shows
-- up on the frame that reaches the line -- in-game, where `print()` never
-- reaches the console and the engine's error handler masks the Lua error text
-- ("error in error handling"). In other words: unfixed, these are invisible.
--
-- So this is a source-level scan, not a behavioral test. A fixture can only
-- prove the one call site it happens to execute; the invariant has to hold for
-- every call site, including the ones added next month.
--
-- The KNOWN_BROKEN table is a ratchet, matching the fixture-ability whitelist
-- pattern: the two live sites found while fixing GH #48 are recorded (with the
-- issue that tracks them) so they stay visible instead of silently accumulating
-- company. A NEW undefined reference fails immediately; a whitelisted one that
-- gets fixed also fails, so the list cannot rot.

local ROOT = 'bots'

-- symbol -> { file = <path it is referenced from>, issue = <tracking issue> }
-- Both entries are real nil-call crashes with LIVE call sites (unlike #48,
-- which had none). Fixing them means inventing the missing helper's semantics
-- for a non-focus hero, which is hero-group work, not a rename.
local KNOWN_BROKEN = {
    -- hero_largo.lua: `J.IsCore(bot) or not J.IsThereCoreInLocation(loc, 650)`
    -- -- short-circuits away for a core Largo, crashes for a support one.
    IsThereCoreInLocation = { file = 'bots/BotLib/hero_largo.lua', issue = 'GH #50' },
    -- hero_invoker.lua: `J.Unit.IsUnitWithName(...)` -- J.Unit is nil, so this
    -- is "attempt to index field 'Unit'". The function it wants exists as
    -- ____exports.IsUnitWithName in bots/FunLib/utils.lua.
    Unit = { file = 'bots/BotLib/hero_invoker.lua', issue = 'GH #50' },
}

local tests = {}

local function lua_files()
    local files = {}
    local p = assert(io.popen('find ' .. ROOT .. ' -name "*.lua" | sort'))
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    assert(#files > 50, 'expected to find the bot script tree under ' .. ROOT
        .. ', found ' .. #files .. ' files')
    return files
end

-- Every name assigned onto the shared J table anywhere in the tree, e.g.
--   function J.Foo(...)     J.Foo = function(...)     J.Foo = {}
-- (mode files legitimately define helpers onto J too, so the definition set is
-- collected tree-wide, not just from FunLib/jmz_func.lua.)
local function collect_definitions(files)
    local defined = {}
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
        for line in fh:lines() do
            local name = line:match('^%s*function%s+J%.([%w_]+)')
                or line:match('^%s*J%.([%w_]+)%s*=')
            if name then defined[name] = path end
        end
        fh:close()
    end
    return defined
end

-- Every name read off J, with the site that reads it. Whole-line comments are
-- skipped; a trailing comment on a code line is counted, which is the
-- conservative direction (it can only ask for a definition, never hide one).
local function collect_references(files)
    local refs = {}
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
        local lineno = 0
        for line in fh:lines() do
            lineno = lineno + 1
            if not line:match('^%s*%-%-') then
                for name in line:gmatch('J%.([%w_]+)') do
                    refs[name] = refs[name] or {}
                    refs[name][#refs[name] + 1] = { file = path, line = lineno }
                end
            end
        end
        fh:close()
    end
    return refs
end

local function undefined_refs()
    local files = lua_files()
    local defined = collect_definitions(files)
    local refs = collect_references(files)
    local out = {}
    for name, sites in pairs(refs) do
        if not defined[name] then out[name] = sites end
    end
    return out, defined
end

tests['no J.* reference under bots/ resolves to nothing (except the ratchet)'] = function()
    local undefined = undefined_refs()
    local problems = {}
    for name, sites in pairs(undefined) do
        if not KNOWN_BROKEN[name] then
            problems[#problems + 1] = string.format('J.%s -- %s:%d', name,
                sites[1].file, sites[1].line)
        end
    end
    table.sort(problems)
    assert(#problems == 0, 'undefined J.* reference(s) -- these crash at call '
        .. 'time with no visible error in-game:\n  ' .. table.concat(problems, '\n  '))
end

tests['the ratchet cannot rot: every KNOWN_BROKEN entry is still broken'] = function()
    local undefined = undefined_refs()
    local stale = {}
    for name, meta in pairs(KNOWN_BROKEN) do
        if not undefined[name] then
            stale[#stale + 1] = string.format('J.%s (%s, %s)', name, meta.file, meta.issue)
        end
    end
    table.sort(stale)
    assert(#stale == 0, 'KNOWN_BROKEN lists J.* name(s) that now resolve -- '
        .. 'delete them from the whitelist and close the issue:\n  '
        .. table.concat(stale, '\n  '))
end

-- Guards the scan itself: if the definition regexes ever stop matching (a
-- refactor of how helpers are attached to J), both tests above would go quiet
-- and pass for the wrong reason.
tests['the scan actually sees the helper table'] = function()
    local _, defined = undefined_refs()
    local n = 0
    for _ in pairs(defined) do n = n + 1 end
    assert(n > 300, 'expected hundreds of J.* definitions, found ' .. n
        .. ' -- the definition scan is probably broken, not the tree')
    assert(defined['GetCastDelay'] == 'bots/FunLib/jmz_func.lua',
        'GetCastDelay must be found in jmz_func.lua (GH #48 fix depends on it)')
    assert(defined['IsSoakCandidate'] ~= nil, 'the soak-candidate gate must be found')
end

return tests

-- [GH #48, class-level] Every `J.<name>` referenced under bots/ must be defined
-- under bots/ -- where `<name>` is the FIRST component after the dot, and only
-- that one.
--
-- [director 20260826, ruling on GH #198 §2] That scope line is not a caveat
-- bolted on; it is the correction.  The header used to advertise "every
-- `J.<name>`" flat, and this test then walked past a live nil call in a shipped
-- Think() -- `J.Site.IsCampDangerous` (GH #193) -- because its pattern captures
-- one component, so the reference was scored against `J.Site`, which IS defined
-- (`J.Site = require(...)`), and `IsCampDangerous` was never asked about.  The
-- blind spot covers every name under J.Site / J.Skill / J.Item / J.Role /
-- J.Utils / J.Chat; a census counted 78 of them, 77 resolving by luck rather
-- than by anything checking.
--
-- THE RULING WAS NOT "DEEPEN THIS TEST".  The deeper half already exists and is
-- already enforced: tools/agent/call_form_census.py resolves `J.<sub>.<name>`
-- against each sub-table's own module (aba_site.lua and friends are transpiled
-- flat tables of `____exports.x = `, with no metatable and so no dynamic
-- fallback), and tests/test_call_form_census.py fails on any finding that has
-- no verdict in that tool's ALLOWLIST.  Re-deriving that resolution here would
-- mean a second implementation of one rule in a second language, across six
-- modules with their own export conventions -- which is how two checks drift
-- until neither is trusted.  That same python test pins "this file still stops
-- at the first dot" as an assertion, so anyone who deepens the patterns below
-- gets a red pointing at the overlap instead of discovering it afterwards.
--
-- In short: this file owns the first component, the census owns the rest, and
-- neither is allowed to quietly grow into the other.
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
--
-- EMPTY as of 2026-08-20: both GH #50 entries are fixed and deleted rather than
-- left behind, which is the ratchet working as designed.
--   * IsThereCoreInLocation (hero_largo.lua) -- now defined in
--     FunLib/jmz_func.lua as the location-centred sibling of
--     J.IsThereCoreNearby, pinned by tests/test_is_there_core_in_location.lua.
--   * Unit (hero_invoker.lua) -- the reference now reads J.Utils.IsUnitWithName,
--     pinned by tests/test_invoker_cm_target_guard.lua. That one was NOT a live
--     crash, contrary to what #50 recorded here: the branch it sits in is
--     unreachable (J.IsValidTarget and J.IsValidHero are the same delegate, so
--     the `and` short-circuits exactly when the `or` would have needed it), and
--     that test measures it rather than arguing it.
--
-- Note what this scan can and cannot see: it answers "is this name defined
-- anywhere", never "is this call site reachable" and never "does the function
-- return something sane" (that blind spot is GH #51's whole story). A new
-- undefined reference fails immediately; a whitelisted one that gets fixed
-- without its entry being deleted also fails, so the list cannot rot.
local KNOWN_BROKEN = {}

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

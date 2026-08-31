-- Corpus half of the `rotscope` reading: J.GetProperTarget is nil on EVERY
-- live-hero frame of the corpus, and the reason is the corpus, not the game.
--
-- DELIBERATELY UNTAGGED. This file carries no [detector]/[ratchet] marker, so
-- the 铁律-10 selfcheck's fast Lua leg does not pick it up: it spends ~30s
-- driving 993 frames, and GH #358 already has that leg at 133.3s for every
-- stream on every trigger. The cheap half of this finding lives in
-- tests/test_rotscope_shadowed_target.lua, which IS tagged. Same split, same
-- reason, as tests/test_towercreep_stale_{source,domain}.lua.
--
-- WHY THE READING MATTERS BEYOND ONE BLOCK. J.GetProperTarget is read at 351
-- call expressions in 164 files under bots/. If it answers nil on every
-- fixture frame, then every conclusion this repo has ever drawn on a fixture
-- frame about any of those call sites was drawn on a frame where the target
-- was nil. That is UNMEASURABLE, not EMPTY -- the GH #171 / #205 distinction:
-- the zero is attributable to two named engine getters that nothing wires
-- (tests/mock/bot_api.lua's `handle_getters`, and 0 of the fixtures supplying
-- an override), not to a game condition.

package.path = 'tests/?.lua;' .. package.path

local tests = {}

--- Run the sweep in its own process and return its parsed COUNT/SKIP/SRC lines.
--- Its own process because it walks every fixture through the real jmz_func
--- and a shared VM would leak state between fixtures (same reason as
--- tests/_towerstale_sweep.lua).
local sweep_cache
local function sweep()
    if sweep_cache then return sweep_cache end
    local p = assert(io.popen('lua5.1 tests/_propertarget_sweep.lua 2>&1'))
    local out = p:read('*a')
    p:close()
    local r = {}
    for k, v in out:gmatch('(%w+)=(%-?%d+)') do r[k] = tonumber(v) end
    assert(r.frames, 'the sweep produced no COUNT line:\n' .. out:sub(1, 400))
    sweep_cache = r
    return r
end

tests['[recorded] the corpus is 993 live-hero frames'] = function()
    -- Pinned so a corpus that GREW is visible as a red line here rather than
    -- silently changing every percentage in the report that cites this file.
    local r = sweep()
    assert(r.frames == 993, 'the live-hero frame count moved: ' .. r.frames .. ' (was 993)')
end

tests['[recorded] J.GetProperTarget is nil on every frame of the corpus'] = function()
    local r = sweep()
    assert(r['nil'] == r.frames,
        'J.GetProperTarget is no longer nil everywhere: nil=' .. tostring(r['nil'])
        .. ' of ' .. r.frames .. ' -- the far-creep half of GH #368 just became MEASURABLE,'
        .. ' which is the outcome we want: re-read the sweep and price it')
    assert(r.hero == 0 and r.nonhero == 0 and r.other == 0,
        'a non-nil target appeared in the corpus')
end

tests['[attribution] the zero comes from two unwired getters, not from game state'] = function()
    -- Without this case the reading above is a bare zero. With it, the zero
    -- has a named cause that a future frame-supplying fixture will erase.
    local r = sweep()
    assert(r.tgt == 0, 'bot:GetTarget() now answers on ' .. r.tgt .. ' frames')
    assert(r.atk == 0, 'bot:GetAttackTarget() now answers on ' .. r.atk .. ' frames')

    local f = assert(io.open('tests/mock/bot_api.lua', 'r'))
    local api = f:read('*a'); f:close()
    assert(api:find('GetAttackTarget = true', 1, true) and api:find('GetTarget = true', 1, true),
        'both getters are no longer declared in handle_getters -- re-derive the attribution')
end

tests['[recorded] how wide the consequence is'] = function()
    -- The 351/164 numbers are counted from the tree, never copied in: charter
    -- 0SRC. They are what makes this a world assertion rather than a note
    -- about one Pudge block.
    local p = assert(io.popen(
        "grep -rn 'J\\.GetProperTarget *(' bots/ | grep -cv ':[0-9]*:[\t ]*--'"))
    local calls = tonumber(p:read('*a')); p:close()
    local q = assert(io.popen("grep -rl 'J\\.GetProperTarget *(' bots/ | wc -l"))
    local files = tonumber(q:read('*a')); q:close()
    assert(calls >= 300, 'J.GetProperTarget call expressions fell to ' .. calls
        .. ' -- the report cites 351; re-derive before quoting the old number')
    assert(files >= 150, 'J.GetProperTarget consumer files fell to ' .. files
        .. ' -- the report cites 164; re-derive before quoting the old number')
end

return tests

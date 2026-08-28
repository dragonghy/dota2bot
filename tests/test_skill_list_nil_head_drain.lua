-- [GH #286 20260828] The skill list stops draining the moment its nil hole
-- reaches the head, and the handler written for exactly that case is locked out
-- by its own `#` gate.
--
-- Frame evidence (replay-check, W22 seed 975, run af08aa, 6/6 games read):
-- Obsidian Destroyer stalled at 6 spent ability points in 5 of 6 games and then
-- spent nothing for the remaining ~21 minutes, while the other nine heroes in
-- the same games sat at 14-20 points.  This is shipped default behaviour -- no
-- gate, no soak candidate id, both legs identical -- so it happens in every
-- game, not only in an armed wave.
--
-- The chain, all of it verifiable off the source:
--   * aba_skill.lua only writes sAbilityList[6] for an ultimate in slot >= 4.
--     OD's ultimate is in slot 3, so [6] is never written and every build entry
--     of 6 resolves to nil through aba_skill's `sSkillList[i] = sAbilityList[...]`.
--   * In Lua 5.1 a nil hole that has been consumed down to index 1 collapses
--     `#` to 0 while the real entries survive at higher indices.
--   * ability_item_usage_generic.lua gates the whole level-up body on
--     `#sAbilityLevelUpList >= 1`, so it is false for the rest of the game.
--
-- WHY THE OBVIOUS FIX IS NOT THE FIX, and why this file tests a compaction
-- rather than a hoisted handler.  GH #286 proposed lifting the existing nil
-- handler above the `#` gate.  That handler drains with `table.remove(t, 1)`,
-- and at `#t == 0` table.remove shifts nothing -- it is a no-op.  A hoisted
-- handler would therefore meet the same hole on every frame forever, turning a
-- permanent stop into a permanent spin, and its `return` would additionally
-- shadow the `botLevel > 25` rebuild further down, which is today the ONLY path
-- that ever recovers (the one OD game that escaped, at level 26, escaped
-- through it).  Section 1 pins that no-op as a language fact so the next reader
-- does not re-propose the handler; sections 2-3 pin the shape that does work.
--
-- Scope: this repairs the DRAIN only.  The build table's own index convention
-- (OD's `{...,6,...}` naming an entry that does not exist, so objurgation is
-- never learned) is a behaviour change and stays out of this file -- it is
-- handed to the hero desk as a gated id, see the report and #286 item 2.

package.path = 'tests/?.lua;' .. package.path

local tests = {}

local SOURCE = 'bots/ability_item_usage_generic.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local SRC = read_file(SOURCE)

--- Lift the SHIPPED CompactSkillList out of the shipped file and compile it.
--- Extracting rather than restating it is the point: a copy in this file would
--- keep passing after the real one was reworded or deleted (the `pullcad`
--- lesson -- a battery that measured its own copy).  The inner `end`s are
--- indented, the closing one is not, so the non-greedy match stops on the
--- function's own end.
local function shipped_compactor()
    local body = SRC:match('\nlocal function CompactSkillList.-\nend\n')
    assert(body, SOURCE .. ': `local function CompactSkillList` is gone or was ' ..
        'reindented -- GH #286 regression, or the extraction needs updating')
    local chunk = assert(loadstring(body .. '\nreturn CompactSkillList',
        '@' .. SOURCE), 'the extracted CompactSkillList does not compile')
    return assert(chunk(), 'the extracted chunk returned no function')
end

--- The exact shape from GH #286 section 2: a list with one hole, consumed down
--- to the point where the hole sits at the head.
local function stalled_list()
    local t = { 'a', 'b', 'c', 'd', 'e', nil, 'g', 'h' }
    for _ = 1, 5 do table.remove(t, 1) end
    return t
end

-- ---------------------------------------------------------------- section 1
-- The premise, as a language fact, including the half GH #286 got wrong.

tests['[GH #286] a head nil collapses # while entries survive'] = function()
    local t = stalled_list()
    assert(#t == 0, ('expected the collapsed length 0, got %d -- the Lua 5.1 ' ..
        'border behaviour this fix is built on no longer holds'):format(#t))
    assert(next(t) ~= nil, 'expected surviving entries behind the collapsed length')

    local n = 0
    for _ in pairs(t) do n = n + 1 end
    assert(n == 2, ('expected 2 surviving entries, got %d'):format(n))
end

tests['[GH #286] table.remove cannot drain a collapsed list'] = function()
    local t = stalled_list()
    local before = {}
    for k, v in pairs(t) do before[k] = v end

    -- This is what the shipped nil handler does, and what a hoisted version of
    -- it would keep doing every frame.
    table.remove(t, 1)

    local after_n = 0
    for k, v in pairs(t) do
        after_n = after_n + 1
        assert(before[k] == v, ('table.remove moved key %s -- if this ever ' ..
            'starts shifting, the hoisted-handler fix rejected in GH #286 ' ..
            'becomes viable and this file should be revisited'):format(tostring(k)))
    end
    assert(after_n == 2, ('table.remove(t, 1) changed the entry count to %d; ' ..
        'it is supposed to be a no-op at #t == 0'):format(after_n))
    assert(#t == 0, 'the collapsed length changed')
end

-- ---------------------------------------------------------------- section 2
-- The shipped compactor, executed.

tests['[GH #286] the shipped compactor drains a collapsed list'] = function()
    local compact = shipped_compactor()
    local dense = compact(stalled_list())

    assert(#dense == 2, ('expected 2 dense entries, got %d -- the stalled list ' ..
        'is still not drainable'):format(#dense))
    assert(dense[1] == 'g' and dense[2] == 'h',
        ('expected {g, h} in source order, got {%s, %s}')
            :format(tostring(dense[1]), tostring(dense[2])))
end

tests['[GH #286] the compactor preserves order across several holes'] = function()
    local compact = shipped_compactor()
    -- OD's shape: a build that names a missing index more than once.
    local t = { 'q', 'w', nil, 'e', nil, 'r', nil }
    local dense = compact(t)

    assert(#dense == 4, ('expected 4 dense entries, got %d'):format(#dense))
    local want = { 'q', 'w', 'e', 'r' }
    for i = 1, #want do
        assert(dense[i] == want[i], ('entry %d is %s, expected %s -- the ' ..
            'compactor reordered the build'):format(i, tostring(dense[i]), want[i]))
    end
end

tests['[GH #286] the compactor leaves a healthy list alone'] = function()
    local compact = shipped_compactor()
    local t = { 'a', 'b', 'c' }
    local dense = compact(t)

    assert(#dense == 3, ('a hole-free list came back with %d entries'):format(#dense))
    for i = 1, 3 do
        assert(dense[i] == t[i], ('entry %d changed on a healthy list'):format(i))
    end
end

tests['[GH #286] the compactor returns an empty list for an empty one'] = function()
    local compact = shipped_compactor()
    local dense = compact({})
    assert(type(dense) == 'table', 'the compactor did not return a table')
    assert(next(dense) == nil, 'the compactor invented an entry out of nothing')
end

-- ---------------------------------------------------------------- section 3
-- Where the call sits.  Executing the compactor proves it drains; only the
-- source order proves it is REACHED before the gate that the collapse freezes,
-- and that it does not shadow the one recovery path we have.

local function positions()
    -- AbilityLevelUpThink delegates the whole body to this one; that is where
    -- the gate and the rebuild live.
    local fn = SRC:match('\nlocal function AbilityLevelUpComplement.-\nend\n')
    assert(fn, SOURCE .. ': AbilityLevelUpComplement no longer parses')

    local call = fn:find('CompactSkillList%(')
    local gate = fn:find('#sAbilityLevelUpList%s*>=%s*1')
    local rebuild = fn:find('botLevel%s*>%s*25%s*and%s*botLevel%s*<%s*30')
    return fn, call, gate, rebuild
end

tests['[GH #286] the compaction runs before the length gate'] = function()
    local _, call, gate = positions()
    assert(call, 'AbilityLevelUpComplement no longer calls CompactSkillList')
    assert(gate, 'the `#sAbilityLevelUpList >= 1` gate no longer parses')
    assert(call < gate, 'the compaction moved below the `#` gate -- the gate is ' ..
        'exactly what a collapsed length holds shut, so from there it can never run')
end

tests['[GH #286] the compaction block does not return'] = function()
    local fn = positions()
    -- The whole `if ... then <call> end` block that guards the compaction.
    local block = fn:match('(if sAbilityLevelUpList%[1%] == nil.-\n\tend\n)')
    assert(block, SOURCE .. ': the compaction guard block no longer parses')
    assert(not block:find('return'), 'the compaction block returns -- that is ' ..
        'the hazard GH #286 records: an early return here shadows the ' ..
        'botLevel > 25 rebuild, the only path that recovered a stalled hero')
end

tests['[GH #286] the botLevel > 25 rebuild is still downstream'] = function()
    local _, call, _, rebuild = positions()
    assert(rebuild, 'the botLevel > 25 rebuild left AbilityLevelUpComplement')
    assert(call < rebuild, 'the compaction is no longer upstream of the rebuild')
end

return tests

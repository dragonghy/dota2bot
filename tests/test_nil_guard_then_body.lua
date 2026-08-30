-- A nil guard must not route execution INTO the branch that indexes the value
-- it just found nil.  GH #346 (director), taken by hero 2026-08-30.
--
-- THE SHAPE
-- ---------
--     if X == nil
--         or f( X.field ) <= 2      -- short-circuited when X is nil: fine
--     then
--         X.count = 0               -- <== reached EXACTLY when X is nil
--     end
--
-- The `or` short-circuit means the SECOND clause is never evaluated on nil, so
-- the nil never reaches `f`.  The then-body is the whole defect, and it is the
-- one line the guard was written to protect.
--
-- ⚠️ THIS CORRECTS THE ISSUE THAT COMMISSIONED IT, in two places, and both
-- corrections started as this stream's own writing:
--
--   (1) #346 says the site "可以把 nil 传进 J.GetInLocLaneCreepCount".  It cannot
--       -- `or` short-circuits.  That claim came from this stream's
--       state.json:cmqreach_20260830.known_gap (5) and #346 inherited it.  The
--       reachable defect is the then-body index and only that.
--   (2) #346 offers hero_crystal_maiden.lua as the healthy 对照 ("至少还多一句
--       targetloc == nil 检查").  CM had the IDENTICAL defect.  The extra clause
--       guards a DIFFERENT nil (the field) than the one the body indexes (the
--       table), so it never protected the body at all.  Fixed here.
--
-- WHY A SOURCE-SHAPE TEST AND NOT A FIXTURE.  Whether `FindAoELocation` ever
-- returns nil is not decidable from the bot VM (AGENTS.md: `print()` never
-- reaches the console; `error in error handling` eats every Lua error text), so
-- no frame can be captured that shows the crash.  But the defect does not need
-- that datum: BOTH worlds are defects, and #346 says so.  What IS decidable is
-- the shape, from the source, and it is decidable for every hero at once.
--
-- ⚠️ THE FIX IS NOT A NIL-SAFETY CLAIM FOR CM, and the honest bound is a
-- counted one: this repo has **353** `FindAoELocation` call sites and exactly
-- **3** of them test the result for nil (pinned below).  The other 350 index it
-- unguarded -- three of them inside CM's own ConsiderQImpl.  So if the engine
-- ever does return nil, CM still dies, just four lines later.  What the fix buys
-- is narrower and is the whole of what is claimed: the code no longer
-- contradicts itself by using `X == nil` as the trigger for indexing X.
--
-- 350-vs-3 is also the strongest available evidence on WHICH world we are in:
-- if nil were reachable, the repo would be crashing at 350 sites, not 3.  That
-- is evidence, not proof, and the fix is written to be correct either way.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')

-- `depth_delta` / `scan_file` live in tests/lua_source_scan.lua, by the same
-- one-copy rule that put `strip_line_comment` there (GH #346).  Keeping them
-- here would have forced a second copy the moment anything else -- the wide
-- census handed over as its own issue, for one -- needed to run the shape
-- scan.  The module owns the scanner; this file owns the verdicts.
local scan_file = scan.nil_guard_shapes

--- The shape census over every Lua file under `bots/`.
--
-- SCOPE, and why it is the whole tree.  The first draft of this file asserted
-- only over the `FindAoELocation` family, because the first census reported 53
-- hits and this stream will not sign an allowlist it has not read.  Two scanner
-- defects produced 52 of those 53:  the header glue ran one line past `then`
-- (so every body was read late), and the body scan did not stop at an
-- assignment, so the correct `if X == nil then X = {} ; X.f = 1 end` idiom
-- looked exactly like the defect.  With both fixed the whole-tree census is
-- TWO, both true positives, both hand-read -- so the scope restriction was
-- removed and the assertions below cover every hero.
local function census()
    local self_indexing, pre_indexed = {}, {}
    for _, path in ipairs(scan.bots_files()) do
        local a, b = scan_file(path)
        for _, r in ipairs(a) do self_indexing[#self_indexing + 1] = r end
        for _, r in ipairs(b) do pre_indexed[#pre_indexed + 1] = r end
    end
    return self_indexing, pre_indexed
end

local function render(rows)
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = r[1] .. ':' .. r[2] .. ' (' .. r[3] .. ')'
    end
    table.sort(out)
    return table.concat(out, '\n            ')
end

local tests = {}

tests['[ratchet] the scanner itself: inline bodies, `then` at EOL, exact lines'] = function()
    -- WHY THIS NODE EXISTS.  The mutation stand for this change ran a mutant
    -- that reintroduced the header-padding bug (see scan_file) and the three
    -- census nodes below came back GREEN -- because the bug only misreads the
    -- LINE a hit sits on, and the narrow FindAoELocation scope happens to hold
    -- its verdicts either way.  A scanner fix that no assertion can detect is
    -- not pinned, so the fix is pinned HERE, on synthetic input with known line
    -- numbers, where the off-by-one is exactly what goes red.
    local path = os.tmpname()
    local f = assert(io.open(path, 'w'))
    f:write([[
local a = f()
if a == nil then return end
local x = a.field
local b = f()
if b == nil
then
    b.count = 0
end
local c = f()
local y = c.count
if c == nil
    or c.count > 1
then
    c = nil
end
local d = f()
if d == nil then
    d = {}
    d.field = 1
end
]])
    f:close()
    local self_idx, pre_idx = scan_file(path)
    os.remove(path)

    -- `a`: inline `then return end`.  Properly guarded -- the body returns and
    -- never touches `a`.  The later `a.field` is outside the if entirely, and a
    -- scanner that reads past the inline `end` would wrongly flag it.
    -- `b`: `then` alone on its own line, body indexes `b`.  THE defect shape,
    -- and the one whose line number the padding bug moves (5 instead of 7).
    -- `c`: indexed at line 10 before the guard at 11; body assigns, never
    -- indexes -- so it is a pre-index hit and NOT a self-index hit.
    -- `d`: the CORRECT idiom -- the body assigns `{}` and only then indexes.
    -- Not a defect, and it is what 3 of the first whole-tree census's 4 hits
    -- actually were.  A scanner that flags `d` cannot be run over the tree.
    assert(#self_idx == 1,
        'expected exactly 1 self-indexing hit (`b`), got ' .. #self_idx ..
        ' -- 2 means the `d = {}` assignment idiom is being flagged as a defect')
    assert(self_idx[1][3] == 'b', 'expected the hit on `b`, got ' .. self_idx[1][3])
    assert(self_idx[1][2] == 7,
        'expected the `b` hit on line 7 (the body), got line ' .. self_idx[1][2] ..
        ' -- an off-by-one here means the header glue ran past the `then`')

    assert(#pre_idx == 1, 'expected exactly 1 pre-index hit, got ' .. #pre_idx)
    assert(pre_idx[1][3] == 'c', 'expected the pre-index hit on `c`, got ' .. pre_idx[1][3])
    assert(pre_idx[1][2] == 10,
        'expected the `c` pre-index hit on line 10, got line ' .. pre_idx[1][2])
end

tests['[ratchet] no nil guard routes execution into indexing the value it found nil'] = function()
    local self_indexing = census()

    -- The ONE registered exception, and it is registered as a defect, not as
    -- acceptable: hero_silencer.lua is the site #346 was filed about.  It stays
    -- because Silencer is not one of the five focus heroes and the hero stream
    -- moves one lever at a time -- NOT because the shape is tolerable there.
    -- Whoever takes #346 deletes this exception; do not add a second one.
    local expected = { 'bots/BotLib/hero_silencer.lua' }

    local got = {}
    for _, r in ipairs(self_indexing) do got[#got + 1] = r[1] end
    table.sort(got)

    assert(#got == #expected,
        'the set of self-defeating nil guards moved (expected ' .. #expected ..
        ', got ' .. #got .. '):\n            ' .. render(self_indexing) ..
        '\n        A NEW one means someone wrote `if X == nil ... then X.field = ...`.' ..
        '\n        A MISSING one means #346 was fixed -- delete it from `expected` here.')
    for n = 1, #expected do
        assert(got[n] == expected[n],
            'expected the only self-defeating nil guard to be in ' .. expected[n] ..
            ', found ' .. got[n])
    end
end

tests['[ratchet] crystal_maiden: the guard no longer indexes what it found nil'] = function()
    local self_indexing = census()
    for _, r in ipairs(self_indexing) do
        assert(r[1] ~= 'bots/BotLib/hero_crystal_maiden.lua',
            'CM regressed to the #346 shape at line ' .. r[2] .. ' (' .. r[3] .. ')')
    end

    -- Pin the repaired structure itself, so the fix cannot be reverted into a
    -- shape that merely dodges the scanner.  The nil branch must SUBSTITUTE a
    -- zero-count stand-in, because the four downstream `.count >= N` reads (5,
    -- 4, 4, 4) would otherwise index nil themselves -- and each of them guards
    -- a `.targetloc` return, so count 0 makes all four false and `.targetloc`
    -- is never read off the stand-in.
    local src = assert(io.open('bots/BotLib/hero_crystal_maiden.lua')):read('*a')
    assert(src:match('if%s+nCanHurtCreepsLocationAoE%s*==%s*nil%s*then%s*' ..
        'nCanHurtCreepsLocationAoE%s*=%s*{%s*count%s*=%s*0%s*}'),
        'CM nil branch must substitute `{ count = 0 }`, not index the nil value')
    assert(src:match('elseif%s+nCanHurtCreepsLocationAoE%s*%.%s*targetloc%s*==%s*nil'),
        'the targetloc check must survive the repair, on the elseif leg')
end

tests['[ratchet] the guard that cannot fire: indexed before it is tested'] = function()
    local _, pre_indexed = census()

    -- hero_sniper.lua reads `.count` off the value on the line ABOVE the
    -- `== nil` test.  This is the sharpest form of #346's disjunction and it
    -- needs no engine datum to settle: if FindAoELocation can return nil the
    -- crash already happened one line earlier, and if it cannot the guard is
    -- dead.  Either way that guard protects nothing, in both worlds.
    -- Registered, not fixed: Sniper is not a focus hero.
    local expected = { 'bots/BotLib/hero_sniper.lua' }

    local got = {}
    for _, r in ipairs(pre_indexed) do got[#got + 1] = r[1] end
    table.sort(got)

    assert(#got == #expected,
        'the set of nil guards that are indexed before they fire moved (expected ' ..
        #expected .. ', got ' .. #got .. '):\n            ' .. render(pre_indexed))
    for n = 1, #expected do
        assert(got[n] == expected[n], 'expected ' .. expected[n] .. ', found ' .. got[n])
    end
end

tests['[ratchet] the 350-vs-3 bound the fix is NOT allowed to overclaim'] = function()
    -- The honest bound in this file's header, as a number that moves if someone
    -- makes it false.  If a future round makes CM actually nil-safe, this pin
    -- goes red and the header prose must be rewritten with it.
    local total, guarded = 0, 0
    for _, path in ipairs(scan.bots_files()) do
        for _, line in ipairs(scan.stripped_lines(path)) do
            for _ in line:gmatch('FindAoELocation%s*%(') do
                total = total + 1
            end
            if line:match('LocationAoE%s*==%s*nil') then
                guarded = guarded + 1
            end
        end
    end

    assert(total == 353, 'FindAoELocation call sites moved from 353 to ' .. total)
    assert(guarded == 3,
        'the number of FindAoELocation results tested for nil moved from 3 to ' ..
        guarded .. ' -- if it went UP, the header prose (350-vs-3) is now wrong')

    -- CM's own function still indexes three OTHER FindAoELocation results
    -- unguarded, which is why the fix claims no nil-safety for CM.
    local src = assert(io.open('bots/BotLib/hero_crystal_maiden.lua')):read('*a')
    for _, name in ipairs({ 'nCanKillHeroLocationAoE', 'nCanHurtHeroLocationAoE',
                            'nCanKillCreepsLocationAoE' }) do
        assert(src:match(name .. '%s*%.%s*count'),
            name .. ' should still be indexed unguarded -- if it is not, the ' ..
            'honest bound in this file changed and must be rewritten')
    end
end

return tests

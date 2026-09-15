-- [ratchet] [strategy 2026-09-15] The host of soak candidate 'waitclar' has no
-- live call site, and never had one in this repo's history.
--
-- THE FACT
-- ---------------------------------------------------------------------------
-- bots/mode_roam_generic.lua defines ConsiderWaitInBaseToHeal() at ~1571 and
-- the ONLY place that would call it is commented out, twenty lines into the
-- mode's Think:
--
--     -- if ConsiderWaitInBaseToHeal()
--     -- and GetUnitToLocationDistance(bot, J.GetTeamFountain()) > 5500
--     -- then
--     -- 	return BOT_ACTION_DESIRE_ABSOLUTE
--     -- end
--
-- With comments stripped, the token ConsiderWaitInBaseToHeal occurs exactly
-- ONCE in the whole file: on its own `function` line. Nothing calls it.
--
-- The function's only outward effect is the file-local `ShouldWaitInBaseToHeal`
-- it sets true at ~1681, read by the "Heal in Base" branch at ~484. That
-- assignment is the ONLY `= true` for the flag in the file, so the consumer
-- branch is unreachable for the same reason -- one dead call site takes both.
--
-- ⛔ WHY THIS MATTERS RIGHT NOW. 'waitclar' (strategy, 2026-09-06, owner
-- priority P2) is a gated veto appended INSIDE this function at ~1676. It is
-- landed but not yet in the armed set (P4.2 admission freeze). The moment it is
-- admitted, the wave that reads it measures a STRUCTURAL ZERO and reports back
-- "tested, no effect" with nothing raising a hand -- the exact failure shape
-- AGENTS.md records for a gate that can never be true. This file is the hand.
--
-- ⛔ AND THE ZERO IS THE CONSTRUCTIVE KIND, which decides the disposition.
-- 'siegecap' (same stream, same day) is a CORPUS-COVERAGE zero: its branch runs
-- for every drafted hero in every game that lasts, the corpus just stops at
-- 850s. This one is different in kind -- the host is not reached in ANY game,
-- by ANY hero, at ANY time, because the caller is commented out in the shipped
-- source. No wave and no corpus can move that. Landing more levers here, or
-- paying for a wave to read this one, buys nothing.
--
-- ⚠️ IT WAS NEVER LIVE, so this is not a regression anyone introduced. The
-- upstream OHA snapshot this repo started from (74727e4a) already carries the
-- call site commented out, at its line 74. The 2026-09-06 block above the gate
-- calls ConsiderWaitInBaseToHeal "SHIPPED and ungated"; the ungated half is
-- true and the SHIPPED half is not, and that prose is corrected in the same
-- change as this file.
--
-- ⚠️ WHAT THE 2026-09-06 MEASUREMENT ACTUALLY MEASURED. tests/_waitclar_sweep.lua
-- reports the shipped function answering true on 6 of 1012 live frames. Those
-- 6 are real, and they are not reachable play: the sweep CALLS
-- ConsiderWaitInBaseToHeal() directly (its lines ~228 and ~234 do exactly
-- that), which is the only way the function runs anywhere in this repo. The
-- probe was reading itself. Nothing in that file is wrong about the function's
-- internals; the missing term is that the engine never asks.
--
-- WHAT THIS FILE PINS
-- ---------------------------------------------------------------------------
--   §1 zero live call sites, counted on comment-stripped source
--   §2 the call site exists but is commented -- disabled, not absent
--   §3 the flag's only `= true` sits inside the dead function, so the
--      consumer branch at ~484 is dead too
--   §4 the 'waitclar' gate is inside the dead function's body
--   §5 REVERSE CALLS: every zero above is re-counted on a copy of the source
--      with the call site un-commented, and must become non-zero. A counter
--      that cannot see a call site would report §1 whatever the file said.
--
-- §1 IS THE TRIPWIRE, in both directions. The day someone uncomments that
-- call, §1 and §3 go red and say so: 'waitclar' becomes readable, must be
-- re-priced on a live corpus, and can then be put up for admission. Until
-- then a red here means the opposite of a problem.

local ROAMFILE = 'bots/mode_roam_generic.lua'

local function read_source()
    local fh = assert(io.open(ROAMFILE, 'r'),
        'cannot open ' .. ROAMFILE .. ' -- run from the repo root')
    local src = fh:read('*a')
    fh:close()
    assert(src and #src > 0, ROAMFILE .. ' is empty')
    return src
end

-- Strip Lua line comments. This file carries no long-bracket comments (asserted
-- below) and no `--` inside a string literal on any line that mentions either
-- name, so a split on the first `--` is exact for what is counted here.
local function strip_comments(src)
    local out = {}
    local i = 1
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        local code = line:match('^(.-)%-%-') or line
        out[i] = code
        i = i + 1
    end
    return out
end

-- Count live (comment-stripped) lines matching a plain-text needle.
local function live_lines_with(src, needle)
    local hits = {}
    local lines = strip_comments(src)
    for n = 1, #lines do
        if lines[n]:find(needle, 1, true) then
            hits[#hits + 1] = { line = n, text = lines[n] }
        end
    end
    return hits
end

-- The mutated stand for §5: put the commented call site back into code.
local function uncomment_callsite(src)
    local mutated, n = src:gsub('\n%s*%-%- if ConsiderWaitInBaseToHeal%(%)',
        '\n\tif ConsiderWaitInBaseToHeal()')
    return mutated, n
end

local tests = {}

-- §0 -------------------------------------------------------------------------

tests['[§0] the file has no long-bracket comments, so the stripper is exact']
= function()
    local src = read_source()
    assert(src:find('--[[', 1, true) == nil,
        ROAMFILE .. ' grew a long-bracket comment; strip_comments() only '
        .. 'handles line comments, so every count in this file must be '
        .. 're-derived before it is trusted again')
end

-- §1 -------------------------------------------------------------------------

tests['[§1] ConsiderWaitInBaseToHeal has ZERO live call sites'] = function()
    local src = read_source()
    local hits = live_lines_with(src, 'ConsiderWaitInBaseToHeal')
    assert(#hits == 1,
        'expected exactly 1 live mention of ConsiderWaitInBaseToHeal (its own '
        .. 'definition), found ' .. #hits .. '. IF A CALL SITE WAS JUST '
        .. 'RE-ENABLED, THIS RED IS THE GOOD NEWS: the host is live again, so '
        .. "'waitclar' must be re-priced on a live corpus and can then go up "
        .. 'for admission to the armed set. Update this file with the new '
        .. 'reading rather than deleting it.')
    assert(hits[1].text:find('function ConsiderWaitInBaseToHeal()', 1, true),
        'the one live mention is not the definition line but: '
        .. tostring(hits[1].text))
end

-- §2 -------------------------------------------------------------------------

tests['[§2] the call site is present but commented -- disabled, not absent']
= function()
    local src = read_source()
    assert(src:find('-- if ConsiderWaitInBaseToHeal()', 1, true),
        'the commented call site is gone from ' .. ROAMFILE .. '. Either it '
        .. 'was deleted (then this whole function is dead code and should be '
        .. "read as such, taking 'waitclar' with it) or it was re-enabled "
        .. '(then §1 is red and carries the instructions).')
end

-- §3 -------------------------------------------------------------------------

tests['[§3] the flag is only ever set true inside the dead function']
= function()
    local src = read_source()
    local lines = strip_comments(src)

    local def_line, end_line
    for n = 1, #lines do
        if lines[n]:find('function ConsiderWaitInBaseToHeal()', 1, true) then
            def_line = n
        elseif def_line and not end_line and lines[n]:match('^end%s*$') then
            end_line = n
        end
    end
    assert(def_line, 'ConsiderWaitInBaseToHeal definition not found')
    assert(end_line, 'could not find the end of ConsiderWaitInBaseToHeal')

    local sets_true, reads = {}, {}
    for n = 1, #lines do
        local rhs = lines[n]:match('ShouldWaitInBaseToHeal%s*=%s*(%a+)')
        if rhs == 'true' then
            sets_true[#sets_true + 1] = n
        elseif rhs == nil and lines[n]:find('ShouldWaitInBaseToHeal', 1, true)
            and not lines[n]:find('Tinker', 1, true) then
            reads[#reads + 1] = n
        end
    end

    assert(#sets_true == 1,
        'expected exactly one `ShouldWaitInBaseToHeal = true`, found '
        .. #sets_true)
    assert(sets_true[1] > def_line and sets_true[1] < end_line,
        'the only `= true` is at line ' .. sets_true[1] .. ', outside the dead '
        .. 'function [' .. def_line .. ', ' .. end_line .. '] -- the flag now '
        .. 'has a live writer and the "Heal in Base" branch is reachable again')
    assert(#reads > 0,
        'nothing reads ShouldWaitInBaseToHeal any more; the branch this file '
        .. 'calls unreachable has been removed, so re-derive §3 before '
        .. 'quoting it')
end

-- §4 -------------------------------------------------------------------------

tests["[§4] the 'waitclar' gate sits inside the dead function's body"]
= function()
    local src = read_source()
    local lines = strip_comments(src)

    local def_line, end_line
    for n = 1, #lines do
        if lines[n]:find('function ConsiderWaitInBaseToHeal()', 1, true) then
            def_line = n
        elseif def_line and not end_line and lines[n]:match('^end%s*$') then
            end_line = n
        end
    end

    local gate_lines = {}
    for n = 1, #lines do
        if lines[n]:find("IsSoakCandidate('waitclar')", 1, true) then
            gate_lines[#gate_lines + 1] = n
        end
    end

    assert(#gate_lines == 1,
        "expected exactly one live 'waitclar' gate in " .. ROAMFILE
        .. ', found ' .. #gate_lines .. ". More than one gate point is the "
        .. "'pullcad' shape and has to be re-read before any wave arms it")
    assert(gate_lines[1] > def_line and gate_lines[1] < end_line,
        "the 'waitclar' gate is at line " .. gate_lines[1] .. ', outside '
        .. 'ConsiderWaitInBaseToHeal [' .. def_line .. ', ' .. end_line
        .. '] -- it has been moved to another host, so its domain is no '
        .. 'longer zero for the reason this file gives')
end

-- §5 REVERSE CALLS -----------------------------------------------------------
-- Each zero above is re-counted against a source that DOES carry the call, so
-- none of them can be satisfied by a counter that simply never matches.

tests['[§5 reverse] the mutated stand really does re-enable the call site']
= function()
    local src = read_source()
    local mutated, n = uncomment_callsite(src)
    assert(n == 1,
        'the mutation did not land exactly once (landed ' .. n .. ' times) -- '
        .. 'every §5 reading below would be measuring the unmutated file')
    assert(mutated ~= src, 'the mutated source is identical to the original')
end

tests['[§5 reverse] §1 counts a call site when one exists'] = function()
    local mutated = uncomment_callsite(read_source())
    local hits = live_lines_with(mutated, 'ConsiderWaitInBaseToHeal')
    assert(#hits == 2,
        'with the call site un-commented, §1 should see 2 live mentions '
        .. '(definition + call), it saw ' .. #hits .. ' -- so §1 cannot '
        .. 'distinguish a called function from an uncalled one')
end

tests['[§5 reverse] the live-line counter is not blind to this file']
= function()
    local src = read_source()
    -- A token that IS live in the shipped file, as a control on the stripper:
    -- if strip_comments over-stripped, this would read zero too.
    local hits = live_lines_with(src, 'TinkerWaitInBaseAndHeal()')
    assert(#hits >= 2,
        'the stripper reports ' .. #hits .. ' live mentions of the Tinker '
        .. 'twin (definition + its live call at ~126); fewer than 2 means '
        .. 'strip_comments() is eating code, and every zero above is an '
        .. 'artefact of the stripper rather than a fact about the file')
end

tests['[§5 reverse] a needle that is only ever in a comment reads zero']
= function()
    local src = read_source()
    -- This phrase appears in the 2026-09-06 block, in comment text only.
    assert(src:find('owner priority P2', 1, true),
        'the control needle is gone from the file; pick another comment-only '
        .. 'phrase before trusting this case')
    local hits = live_lines_with(src, 'owner priority P2')
    assert(#hits == 0,
        'a phrase that exists only inside comments was counted as live '
        .. #hits .. ' time(s) -- strip_comments() is not stripping, so §1 '
        .. 'proves nothing')
end

return tests

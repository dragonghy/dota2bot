-- The `GetActiveMode()` call-site census, split out of
-- tests/test_activemode_world_assertion.lua so that 开工自检 can DISCOVER it.
--
-- WHY THE SPLIT (GH #267 §4, ruling (c), director 2026-08-28)
-- ----------------------------------------------------------
-- The census pin sat RED on origin/main for ~22 hours and no stream saw it.
-- 开工自检's fast Lua leg discovers files BY TAG (`[detector]` / `[ratchet]`),
-- and the world-assertion file carries no tag -- because it CANNOT afford one:
-- it loads every fixture in the archive twice over, measured 5.7s against a
-- ~20s selfcheck, and that file's own header says to TIME a set before tagging
-- it into 开工.  So the choice was never "tag it or do not": tagging the whole
-- file buys the red at a third of the budget, and the ruling priced that as too
-- much.
--
-- The census does not need the fixtures at all.  It greps `bots/`.  Split out,
-- the tag now buys exactly the assertions that went red, for a fraction of what
-- tagging the whole file would have cost.
--
-- ⚠️ THE PRICE IS NOT THE 0.144s THE RULING QUOTED, and the difference is
-- registered here rather than quietly inherited (iron rule 4(iii): an effect
-- size is logged WITH the cut that produced it).  0.144s is what the census
-- SCAN costs.  What 开工自检 actually pays is the marginal cost of one more
-- member in its discovery set, and every member pays the runner's own startup
-- -- which globs 218 test files and loads the mock Bot API before running
-- anything.  Measured 2026-08-28 on this container, by running the real
-- discovery loop with and without this file:
--
--     fast leg, 16 files : 8.86s
--     fast leg, 17 files : 10.34s   => marginal cost 1.48s
--     the whole world-assertion file, if tagged instead : 4.1s (5.7s cold)
--
-- So the split is still the right call -- roughly a third of tagging the whole
-- file, against a ~20s selfcheck -- but it is 1.5s, not 0.14s, and the next
-- person to add a tag should budget against THIS number.  Per that file's
-- standing instruction: TIME the resulting set, do not quote a prior round's
-- figure.
--
-- ⚠️ THE SCANNER MOVED, IT WAS NOT COPIED.  `strip_line_comment` and
-- `scan_call_sites` live HERE now and nowhere else; the world-assertion file
-- keeps the prose that cites their numbers and points at this file for them.  A
-- second copy would be this repo's most expensive recorded trap ("a test that
-- mirrors the thing it checks is checking the mirror",
-- tests/test_selfcheck_lua_leg.py 2a2) -- and it would be that trap on the very
-- instrument whose over-wide reading opened #267.
--
-- ⚠️ IT MOVED AGAIN, BY THAT SAME RULE (GH #346, hero 2026-08-30).
-- `strip_line_comment` now lives in tests/lua_source_scan.lua, because a second
-- source-shape test (tests/test_nil_guard_then_body.lua) needs the same cut and
-- the paragraph above forbids the copy that would otherwise have been made.
-- `scan_call_sites` did NOT move -- it is about GetActiveMode and belongs here.
-- The direct unit checks on the cut at the bottom of this file stayed, and they
-- got STRONGER by moving: they now exercise the single shared copy.
--
-- LIMIT.  Being in the fast leg means a landing that moves these counts goes red
-- at the NEXT stream's 开工, not at the pusher's own gate: the push gate runs
-- luacheck, not this. That is the shape #267 §4 names, one round shorter.

package.path = 'tests/?.lua;' .. package.path

--- Cut a line at its first `--` that is NOT inside a quoted string.
--
-- GH #267 (director 2026-08-28T06:5xZ).  The census below counts "shipped call
-- sites", and its own prose says "shipped comparison lines" -- but the pattern
-- read PROSE too, so a comment that MENTIONS `bot:GetActiveMode()` moved the
-- number exactly like a new call would.  That is how this file went red on
-- 08-27 without one executable line changing: hero_zuus.lua grew a doc comment
-- quoting the very predicate this file is about.  Two more had been miscounted
-- since the pin was first taken (a commented-out clause in jmz_func.lua and a
-- commented-out local in mode_outpost_generic.lua), so the old 255/210 were
-- never the numbers the prose claimed.
--
-- FAILURE DIRECTION, and why the pin was RE-TAKEN rather than RAISED: raising
-- 255 -> 256 would have folded a comment into a count of executable sites
-- permanently, and the next doc line would demand the same courtesy.  The
-- assertion is unchanged ("every shipped comparison line is constant FALSE");
-- only the instrument now measures the set its name always claimed.
--
-- Deliberately conservative: `--` inside a string literal does NOT start a
-- comment, so a real call sitting after such a string is still counted.  The
-- naive `line:find('--')` would have dropped it -- an over-wide cut is the same
-- class of defect as the over-wide pattern this fixes.
local strip_line_comment = require('lua_source_scan').strip_line_comment

--- Shipped call-site counts for the three things this file is about.
-- Counts EXECUTABLE occurrences only (see strip_line_comment / GH #267).
-- Long comments (`--[[ ... ]]`) are not tracked across lines; there are none
-- around these three patterns today, and the mutation batch would catch it if
-- one appeared, because the count would move without an executable line moving.
local function scan_call_sites()
    local out = { get_active_mode = 0, compare_lines = 0, teamfight_consumers = 0,
                  commented_out = 0 }
    -- Skip the two gitignored, farm-only files under bots/Customize/. The gate
    -- switch is created and deleted by every gate test in this suite, so
    -- listing it and then `io.lines`-ing it is a race -- observed here on
    -- 2026-09-02 as `bad argument #1 to 'lines' (... No such file or
    -- directory)`, which names neither this file's subject nor a real defect.
    -- Same family as GH #365 §2 (three sibling censuses, same window), and it
    -- never needed GH #229: this file is not a gate test and never writes the
    -- switch, it only walks over it. Neither farm-only file calls GetActiveMode.
    -- (The literal path is deliberately not spelled out here: prose alone would
    -- enrol this file in test_soakside_shared_switch.lua's census of files that
    -- reach the switch -- the reason that census excludes itself.)
    local p = assert(io.popen(
        'find bots -name "*.lua" ! -path "bots/Customize/soak_*.lua" | sort'))
    for file in p:lines() do
        for raw in io.lines(file) do
            local line = strip_line_comment(raw)
            for _ in line:gmatch('GetActiveMode%s*%(%s*%)') do
                out.get_active_mode = out.get_active_mode + 1
            end
            if raw:match('GetActiveMode%s*%(%s*%)')
                and not line:match('GetActiveMode%s*%(%s*%)')
            then
                out.commented_out = out.commented_out + 1
            end
            if line:match('GetActiveMode%s*%(%s*%)') and line:match('BOT_MODE_') then
                out.compare_lines = out.compare_lines + 1
            end
            for _ in line:gmatch('J%.GetTeamFightLocation%s*%(') do
                if not line:match('^%s*function') then
                    out.teamfight_consumers = out.teamfight_consumers + 1
                end
            end
        end
    end
    p:close()
    return out
end

local tests = {}

tests['[ratchet] call-site census: how much rides on the missing datum'] = function()
    local c = scan_call_sites()
    -- GH #267: EXECUTABLE sites only.  Re-taken 2026-08-28 (was 255/210 while the
    -- pattern still read comments); the claim did not move, the instrument did.
    assert(c.get_active_mode == 253,
        'GetActiveMode() call sites moved from 253 to ' .. c.get_active_mode)
    assert(c.compare_lines == 209,
        'lines comparing GetActiveMode() to a BOT_MODE_* moved from 209 to ' .. c.compare_lines)
    assert(c.teamfight_consumers == 35,
        'J.GetTeamFightLocation consumers moved from 35 to ' .. c.teamfight_consumers)
end

tests['[ratchet] GH #267: the census separates prose from code, and says so'] = function()
    local c = scan_call_sites()
    -- The census must SEE the commented-out mentions and REFUSE to count them.
    -- Asserting only the executable number would pass just as well on a scanner
    -- that could not read comments at all -- which is what 255 came from.
    assert(c.commented_out == 3,
        'GetActiveMode() mentions inside comments moved from 3 to ' .. c.commented_out ..
        ' -- that is a prose change, NOT a call-site change; re-take THIS number, ' ..
        'never fold it into get_active_mode')
    assert(c.get_active_mode + c.commented_out == 256,
        'executable + commented must equal the raw pattern count (256); if it does ' ..
        'not, strip_line_comment cut somewhere it should not have')

    -- Direct unit checks on the cut, including the one the naive `find("--")`
    -- gets wrong.
    assert(strip_line_comment('local x = bot:GetActiveMode()')
        == 'local x = bot:GetActiveMode()', 'a plain code line must survive whole')
    assert(not strip_line_comment('-- local x = bot:GetActiveMode()')
        :match('GetActiveMode'), 'a leading comment must be cut')
    assert(not strip_line_comment('return true -- bot:GetActiveMode() ~= BOT_MODE_RETREAT')
        :match('GetActiveMode'), 'a trailing comment must be cut')
    assert(strip_line_comment('f("a--b") local x = bot:GetActiveMode()')
        :match('GetActiveMode'), '`--` inside a string does not start a comment')
    assert(strip_line_comment("f('a--b') local x = bot:GetActiveMode()")
        :match('GetActiveMode'), 'single-quoted strings count too')
end

return tests

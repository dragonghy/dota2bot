-- [ratchet] No `GetItem`-family call site may pass the item name where the BOT
-- goes.
--
-- GH #451: `bots/BotLib/hero_tinker.lua` carried eight of them. The declaration
-- in `bots/FunLib/utils.lua` is
--
--     function ____exports.GetItem(bot, itemName)
--         return ____exports.GetItemFromCountedInventory(bot, itemName, 6)
--     end
--
-- and `GetItemFromCountedInventory`'s loop body opens with
-- `bot:GetItemInSlot(i)` under `while i < count` with `count` 6 -- so the first
-- iteration always runs. Called with one argument, `bot` is the STRING
-- `'item_shivas_guard'`. A Lua string has a metatable (`__index = string`), so
-- the INDEX is legal and yields nil; CALLING it is what raises. Measured under
-- the real interpreter rather than recalled:
--
--     $ lua5.1 -e 'local s="item_x" print(pcall(function() return s:GetItemInSlot(0) end))'
--     false   attempt to call method 'GetItemInSlot' (a nil value)
--
-- WHY A STANDING CHECK AND NOT JUST THE EIGHT EDITS. Nothing already in the
-- repo can see this shape. Lua does not check arity; `.luacheckrc` is
-- `only = {"1"}`, the global-access family; and the cross-module arity census
-- resolves declarations written `____exports.GetItem` against call sites
-- written `J.Utils.GetItem` -- two names that are never equal -- so the pair
-- falls out of its scan (GH #452, the strategy half). A defect class that every
-- existing gate is structurally blind to comes back.
--
-- WHAT IT MEASURES. Comment-stripped source for every SHIPPED file under
-- `bots/`, walked through `lua_source_scan.bots_files()` so the gitignored
-- farm-only switches are not read (GH #438). A call is an OFFENDER iff its
-- first argument is a STRING LITERAL: that is decidable from the text and is
-- exactly the observed defect. Any other first argument is left alone --
-- `GetItem(bot, name)`, `GetItem(hUnit, sName)`, `GetItem(t[i], n)` are all
-- legal and this file does not guess at them.
--
-- FAILURE DIRECTION IS NARROW: it can miss (a variable holding an item name,
-- passed first, reads as legal here) and it does not invent. That is the
-- intended side. This is a ratchet against a shape that HAS occurred, not a
-- type checker.

package.path = 'tests/?.lua;' .. package.path

local tests = {}

-- The `utils.lua` wrappers whose FIRST parameter is the unit. Kept here rather
-- than derived, because deriving it from the declarations is precisely the step
-- GH #452 shows is unreliable across the `____exports.` / `J.Utils.` name gap.
local WRAPPERS = { 'GetItem', 'GetItemFromFullInventory', 'GetItemFromCountedInventory' }

-- Returns offenders (list of "path:line  text") and the number of call sites
-- seen, so a scan that has stopped seeing anything can be told apart from a
-- scan that is clean.
local function census()
    local scan = require('lua_source_scan')
    local tOffenders, nCallSites = {}, 0

    for _, sPath in ipairs(scan.bots_files()) do
        local tLines = scan.stripped_lines(sPath)
        for nLine, sLine in ipairs(tLines) do
            for _, sFn in ipairs(WRAPPERS) do
                -- `%s*` after the paren so `GetItem( 'item_x' )` counts too.
                if sLine:find('%.' .. sFn .. '%s*%(') ~= nil then
                    nCallSites = nCallSites + 1
                    if sLine:find('%.' .. sFn .. '%s*%(%s*[\'"]') ~= nil then
                        tOffenders[#tOffenders + 1] = string.format(
                            '%s:%d  %s', sPath, nLine, (sLine:gsub('^%s+', '')))
                    end
                end
            end
        end
    end

    return tOffenders, nCallSites
end

tests['no GetItem-family call passes the item name as the unit'] = function()
    local tOffenders = census()
    assert(#tOffenders == 0,
        'a GetItem-family call passes the item name where the bot goes, so the '
        .. 'wrapper indexes a string and RAISES on every execution (GH #451). '
        .. "Pass the unit first: GetItem(bot, 'item_x'). Offenders: "
        .. table.concat(tOffenders, ' | '))
end

-- Without this the file goes green the day the wrappers are renamed or the walk
-- stops reaching `bots/` -- a pass that proves nothing and says so to nobody,
-- the failure mode GH #200 put the zero-body guard in `run_tests.lua` for.
tests['the scan is actually looking at call sites'] = function()
    local _, nCallSites = census()
    assert(nCallSites > 0,
        'the GetItem-family scan found zero call sites anywhere under bots/ -- '
        .. 'the wrappers were renamed or the walk broke, and this file is now '
        .. 'vacuous rather than clean')
end

return tests

-- [census + ratchet] A `local n<Something> = <number>` inside a shipped
-- function that nothing in that function ever reads.
--
-- WHY THIS EXISTS (hero stream, 2026-09-03).
-- ------------------------------------------
-- The runtime cost of an unread local is zero.  The cost this file is about is
-- the READING cost, and the tree has already paid it more than once: a line of
-- the form
--
--     local nRadius = 600
--
-- is indistinguishable, at a glance, from the constant that actually drives the
-- decision three lines down.  Nothing in the file says which one the code
-- consumes, and `.luacheckrc` cannot say either -- it is configured
-- `only = { "1" }`, i.e. GLOBAL-related warnings only, so luacheck's unused-local
-- family (2xx) is switched off tree-wide by policy.  That policy is not wrong
-- (the 1xx half is the half that catches typos and leaked locals), but it means
-- this class has never had a counter of any kind.
--
-- THE TWO SITES THAT PRICE THE CLASS, both removed in the change that added this
-- file, both in the focus five, and neither of them found by reading:
--
--   * hero_axe.lua X.ConsiderR carried `local nRadius = 600` EIGHT LINES ABOVE
--     the most heavily annotated lever in that file (the registered `hero-2`
--     Culling-damage hardcode, ~20 lines of commentary written across four
--     separate rounds).  Culling Blade is single-target at AbilityCastRange 175
--     and its only *_aoe key is `speed_aoe` 900 -- the ally movespeed-buff
--     radius on a kill.  There is no 600 anywhere in the ability.  Four rounds
--     of maximum attention passed over that line.
--
--   * hero_zuus.lua X.ConsiderR carried `local nCastRange = 1600`.
--     Thundergod's Wrath is GLOBAL: zuus_thundergods_wrath carries no
--     AbilityCastRange key at all.  A reader auditing "does Zeus ult from too
--     far away" was shown a 1600-unit gate that has never existed.  This is the
--     dangerous shape -- not a harmless leftover but a false PREMISE, the class
--     this lab has had to retract readings over before.
--
-- HOW IT MEASURES.  For every `function <name>(` at column 0 through the next
-- `end` at column 0, over comment-stripped source: a line matching
-- `local <ident> = <number literal>` is DEAD iff `<ident>` appears on no other
-- line of that span.  Every ambiguity resolves toward LIVE:
--
--   * a use inside a nested closure is inside the span, so it counts;
--   * a later re-declaration of the same name counts as a use (the site is
--     called live, and this test says nothing about it);
--   * a mention inside a string literal counts as a use (comments do not -- a
--     name that survives only in a comment is dead in exactly the sense that
--     matters here);
--   * `nDamageType` does not count as a use of `nDamage` (word-boundary match).
--
-- So the reading UNDERSTATES the class.  A site this test names is dead; a site
-- it does not name is not thereby proven live.
--
-- LIMITS.  (1) Only column-0 `function ... end` pairs are spans; a function
-- nested inside another is scanned as part of its parent, which merges the two
-- scopes and can only move a site from dead to live.  (2) Only NUMBER literals;
-- `local sFoo = 'bar'` and `local t = {}` are out of the domain by construction,
-- and a future round widening this must re-measure rather than reuse the
-- ceilings below.  (3) Inherited from lua_source_scan.strip_line_comment: long
-- comments (`--[[ ... ]]`) are not tracked across lines.
--
-- WHY THE FOCUS FIVE ARE ENFORCED AT ZERO AND THE TREE IS ONLY RATCHETED.  The
-- focus five are this stream's scope, and all five sites there were removed as
-- one change because removing an unread local is a provable no-op -- it is not
-- the `lanefix` shape, where each edit was defensible and the BUNDLE was
-- rejected twice.  The other 46 live under 128 hero files this stream does not
-- own; they are registered, not touched.  The ceiling is `<=` and MONOTONE:
-- going down is the point, going up names the new site.  It is deliberately not
-- `==` -- that is the shape GH #457 had to repair.

package.path = 'tests/?.lua;' .. package.path

local scan = require('lua_source_scan')

-- The five focus heroes, enforced at zero.
local FOCUS = {
    'bots/BotLib/hero_axe.lua',
    'bots/BotLib/hero_zuus.lua',
    'bots/BotLib/hero_skeleton_king.lua',
    'bots/BotLib/hero_lion.lua',
    'bots/BotLib/hero_crystal_maiden.lua',
}

-- Measured 2026-09-03 on the tree that added this file: 51 before the focus-five
-- removals, 46 after.  RATCHET: lower is fine, higher is a finding.
local TREE_CEILING = 46

-- Supply floors.  These are the aetherlens lesson (hero 2026-09-03) written as
-- code: a ceiling assertion alone cannot tell "nothing is broken" from "the
-- scanner matched nothing".  That round's first parser anchored on `%s*$` and
-- read ZERO sites tree-wide while its `<=` ceiling passed in silence.  Measured
-- the same day: tree-wide 2590 spans / 643 live numeric locals; focus five
-- 65 spans / 22 live.  The floors sit well below so ordinary churn does not trip
-- them, and a parser that stops matching does.
local MIN_SPANS = 2000
local MIN_LIVE  = 500
local MIN_FOCUS_SPANS = 45
local MIN_FOCUS_LIVE  = 12

local function is_number_literal(s)
    return s:match('^%-?%d+$') ~= nil or s:match('^%-?%d+%.%d+$') ~= nil
end

--- Every `local <ident> = <number>` site in `path`, each tagged dead or live.
--- Returns the site list and the number of column-0 function spans seen.
local function sites(path)
    local lines = scan.stripped_lines(path)
    local out, spans = {}, 0
    local i = 1
    while i <= #lines do
        if lines[i]:match('^function%s+[%a_][%w_%.:]*%s*%(') then
            spans = spans + 1
            local j = i + 1
            while j <= #lines and not lines[j]:match('^end%f[%W]') do j = j + 1 end
            local last = math.min(j, #lines)
            for k = i, last do
                local ident, value = lines[k]:match('^%s*local%s+([%a_][%w_]*)%s*=%s*(%S+)%s*$')
                if ident ~= nil and is_number_literal(value) then
                    local used = false
                    for m = i, last do
                        if m ~= k and lines[m]:find('%f[%w_]' .. ident .. '%f[^%w_]') then
                            used = true
                            break
                        end
                    end
                    out[#out + 1] = {
                        path = path, line = k, ident = ident, value = value, dead = not used,
                    }
                end
            end
            i = j
        end
        i = i + 1
    end
    return out, spans
end

local function sweep(paths)
    local dead, live, spans = {}, 0, 0
    for _, p in ipairs(paths) do
        local found, n = sites(p)
        spans = spans + n
        for _, s in ipairs(found) do
            if s.dead then dead[#dead + 1] = s else live = live + 1 end
        end
    end
    return dead, live, spans
end

local function render(dead)
    local parts = {}
    for _, s in ipairs(dead) do
        parts[#parts + 1] = string.format('%s:%d local %s = %s', s.path, s.line, s.ident, s.value)
    end
    return table.concat(parts, '\n  ')
end

local tests = {}

tests['[scope] no focus-five function carries an unread numeric local'] = function()
    local dead, live, spans = sweep(FOCUS)
    assert(spans >= MIN_FOCUS_SPANS,
        'supply: only ' .. spans .. ' function spans across the focus five, floor '
        .. MIN_FOCUS_SPANS .. ' -- the scanner stopped matching, this is not a '
        .. 'clean reading')
    assert(live >= MIN_FOCUS_LIVE,
        'supply: only ' .. live .. ' LIVE numeric locals across the focus five, floor '
        .. MIN_FOCUS_LIVE .. ' -- same failure, and the zero below would have '
        .. 'passed in silence')
    assert(#dead == 0,
        #dead .. ' unread numeric local(s) in a focus-five decision function.\n  '
        .. render(dead)
        .. '\nRemoving one is a no-op (nothing reads it).  If the constant is '
        .. 'knowledge worth keeping, put it in a comment naming the KV key -- a '
        .. 'bare literal cannot say whether it is live.')
end

tests['[ratchet] the tree-wide count does not grow'] = function()
    local dead, live, spans = sweep(scan.bots_files())
    assert(spans >= MIN_SPANS,
        'supply: ' .. spans .. ' function spans tree-wide, floor ' .. MIN_SPANS
        .. ' -- the scanner is not reaching the tree; the ceiling below proves nothing')
    assert(live >= MIN_LIVE,
        'supply: ' .. live .. ' LIVE numeric locals tree-wide, floor ' .. MIN_LIVE
        .. ' -- same failure')
    assert(#dead <= TREE_CEILING,
        'unread numeric locals tree-wide: ' .. #dead .. ' > ceiling ' .. TREE_CEILING
        .. '.  Someone added one.  The list:\n  ' .. render(dead)
        .. '\nLower the ceiling when you remove some; never raise it, and never '
        .. 'make it `==` (GH #457).')
end

tests['[negative control] a constant the code really reads is called live'] = function()
    -- hero_zuus.lua X.ConsiderW2 `local nRadius = 325` is zuus_lightning_bolt's
    -- own spread_aoe, read twice on the following lines.  If the scanner ever
    -- starts calling THIS dead, its use-detection has broken open and every
    -- zero it reports is worthless.
    local found = sites('bots/BotLib/hero_zuus.lua')
    local seen = false
    for _, s in ipairs(found) do
        if s.ident == 'nRadius' and s.value == '325' then
            seen = true
            assert(not s.dead,
                'hero_zuus.lua:' .. s.line .. ' local nRadius = 325 read as DEAD, but '
                .. 'X.ConsiderW2 consumes it -- use-detection is broken')
        end
    end
    assert(seen, 'the control site (hero_zuus.lua X.ConsiderW2 local nRadius = 325) is '
        .. 'gone from the tree; re-anchor this control on another read constant '
        .. 'rather than deleting it')
end

tests['[negative control] the sweep can still see a dead site'] = function()
    -- The focus-five assertion is a ZERO, and a scanner that finds nothing
    -- satisfies a zero perfectly.  The 46 registered tree-wide sites are the
    -- standing proof that the dead branch of the classifier still fires.  If
    -- this ever legitimately reaches 0, replace it with a synthetic fixture --
    -- do not delete it.
    local dead = sweep(scan.bots_files())
    assert(#dead > 0,
        'the tree-wide sweep found ZERO dead sites.  Either 46 sites were fixed '
        .. 'in one round (then lower TREE_CEILING and re-anchor this control) or '
        .. 'the dead branch of the classifier no longer fires -- and in that case '
        .. 'the focus-five zero above is vacuous.')
end

tests['[shape] the classifier does not confuse a prefix for a use'] = function()
    -- `nDamageType` must not count as a use of `nDamage`; that exact pair stood
    -- in hero_axe.lua X.ConsiderQ on adjacent lines, and a substring match would
    -- have called the dead site live and hidden it.
    local lines = { 'function X.T()', '\tlocal nDamage = 0', '\tlocal nDamageType = 1',
                    '\treturn nDamageType', 'end' }
    local tmp = os.tmpname()
    local fh = assert(io.open(tmp, 'w'))
    fh:write(table.concat(lines, '\n') .. '\n')
    fh:close()
    local found = sites(tmp)
    os.remove(tmp)
    local by = {}
    for _, s in ipairs(found) do by[s.ident] = s end
    assert(by['nDamage'] ~= nil and by['nDamage'].dead,
        'nDamage should be DEAD: only nDamageType is read')
    assert(by['nDamageType'] ~= nil and not by['nDamageType'].dead,
        'nDamageType should be LIVE: the return reads it')
end

tests['[shape] a string mention counts as a use, a comment mention does not'] = function()
    local lines = { 'function X.A()', '\tlocal nKeep = 7', "\tprint('nKeep')", 'end',
                    'function X.B()', '\tlocal nGone = 7', '\t-- nGone is nice', 'end' }
    local tmp = os.tmpname()
    local fh = assert(io.open(tmp, 'w'))
    fh:write(table.concat(lines, '\n') .. '\n')
    fh:close()
    local found = sites(tmp)
    os.remove(tmp)
    local by = {}
    for _, s in ipairs(found) do by[s.ident] = s end
    assert(by['nKeep'] ~= nil and not by['nKeep'].dead,
        'a mention inside a string literal must resolve toward LIVE')
    assert(by['nGone'] ~= nil and by['nGone'].dead,
        'a mention that survives only in a comment is not a use')
end

return tests

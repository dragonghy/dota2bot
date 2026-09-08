-- Corpus sweep behind tests/test_blind_a_cmrguard.lua (director 2026-09-08,
-- test_set.md §GD).  Split out of the fast leg the same way
-- tests/_blind_a_sweep.lua is: it loads every fixture in the tree (~3s) and the
-- Lua detector leg is already at its 120s budget (GH #358).  The test file pins
-- this script's numbers as literals; re-take them with
--
--     lua5.1 tests/_blind_a_sweep.lua        (the wandlimbo / tpdead sweep)
--     lua5.1 tests/_blind_a_cmrguard_sweep.lua
--
-- WHAT IT MEASURES.  `cmrguard` (hero_crystal_maiden.lua:1612) withholds
-- Freezing Field when an ENEMY inside 1600 holds a ready curated hard CC that he
-- can deliver:
--
--     GetUnitToUnitDistance(cm, e) <= ( hCc:GetCastRange() or 0 ) + 400
--
-- Every term but the last is real dump data in a fixture.  The last one is the
-- whole content of the GH #34 narrowing (before it, the gate was range-blind and
-- vetoed on capability alone), and it is read off an ENEMY's ability handle --
-- which is the one place this loader does not serve it.  So the sweep counts,
-- across every fixture, how many curated hard-CC handles answer a cast range
-- that came from the KV and how many answer the `^Get -> 0` catch-all in
-- tests/mock/bot_api.lua.
--
-- ⛔ A ZERO HERE IS NOT A NARROW RING, IT IS A MISSING READ, and the two are
-- indistinguishable from the read alone: `axe_berserkers_call` is genuinely
-- cast range 0 in the engine (no-target, the holder must arrive) and it reaches
-- that 0 through the same catch-all as `jakiro_ice_path`, whose real cast range
-- is ~1000.  This script separates them by SOURCE, not by value.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local W = function(s) io.stderr:write(s .. '\n') end

-- Which heroes have a KV block at all, and for which of their abilities does
-- that block declare AbilityCastRange?  `replay_fixture.lua` installs
-- sp.GetCastRange ONLY when both are true (see its `has_kv` / `value_ladder`);
-- anything else falls through to bot_api.lua's `^Get -> 0`.
local function kv_serves_cast_range(sUnit, sAbility)
    local short = sUnit:gsub('^npc_dota_hero_', '')
    local abils = shapes.SHAPES[short]
    if abils == nil then return false, 'no KV block for this hero' end
    local entry = abils[sAbility]
    if entry == nil then return false, 'hero has a block, this ability is not in it' end
    local kv = entry['AbilityCastRange']
    if kv == nil or kv.base == nil then
        return false, 'ability is in the block, AbilityCastRange is not declared'
    end
    return true, kv.base
end

local kv_roster = {}
for k in pairs(shapes.SHAPES) do kv_roster[#kv_roster + 1] = k end
table.sort(kv_roster)

local p = io.popen('ls tests/fixtures/*.lua')
local files = {}
for l in p:lines() do files[#files + 1] = l end
p:close()

local C = {
    fixtures = 0, unloadable = 0,
    handles = 0, cr_zero = 0, cr_nonzero = 0,
    ready = 0, ready_zero = 0,
    served = 0, unserved = 0,
    accidental_zero = 0,          -- unserved AND the engine's real answer is 0
}
local carriers = {}

-- The curated carriers whose real cast range is 0 in the engine (no-target,
-- self-radius): for these the catch-all's 0 is the RIGHT VALUE for the WRONG
-- REASON.  Anchored offline, like every cast range in this lab -- see
-- tools/batch_test/behavioral/cmrguard_counterfactual.py CAST_RANGE.
local TRUE_SELF_RADIUS = {
    axe_berserkers_call = true, centaur_hoof_stomp = true,
    slardar_slithereen_crush = true, tidehunter_ravage = true,
    primal_beast_pulverize = true,
}

for _, f in ipairs(files) do
    local ok, J, _, heroes = pcall(rf.load, f)
    if ok and J ~= nil and heroes ~= nil then
        C.fixtures = C.fixtures + 1
        for sName, h in pairs(heroes) do
            for slot = 0, 5 do
                local a = h.GetAbilityInSlot ~= nil and h:GetAbilityInSlot(slot) or nil
                if a ~= nil and J.tHardCcAbilities[a:GetName()] then
                    local sAb = a:GetName()
                    local cr = a:GetCastRange() or 0
                    local bServed = kv_serves_cast_range(sName, sAb)
                    C.handles = C.handles + 1
                    if cr == 0 then C.cr_zero = C.cr_zero + 1
                    else C.cr_nonzero = C.cr_nonzero + 1 end
                    if bServed then C.served = C.served + 1
                    else
                        C.unserved = C.unserved + 1
                        if TRUE_SELF_RADIUS[sAb] then
                            C.accidental_zero = C.accidental_zero + 1
                        end
                    end
                    local lvl, cd = a:GetLevel() or 0, a:GetCooldownTimeRemaining() or 0
                    if lvl >= 1 and cd <= 0 then
                        C.ready = C.ready + 1
                        if cr == 0 then C.ready_zero = C.ready_zero + 1 end
                    end
                    local key = string.format('%-28s %-32s cr=%-5s served=%s',
                        sName:gsub('^npc_dota_hero_', ''), sAb, tostring(cr), tostring(bServed))
                    carriers[key] = (carriers[key] or 0) + 1
                end
            end
        end
    else
        C.unloadable = C.unloadable + 1
    end
end

W('=== cmrguard blind-(a) sweep -- the enemy-side cast range this lab cannot read')
W(string.format('G KV_ROSTER %d   (%s)', #kv_roster, table.concat(kv_roster, ',')))
W(string.format('C FIXTURES %d   C UNLOADABLE %d', C.fixtures, C.unloadable))
W(string.format('C HARDCC_HANDLES %d   C CR_ZERO %d   C CR_NONZERO %d',
    C.handles, C.cr_zero, C.cr_nonzero))
W(string.format('C READY %d   C READY_ZERO %d', C.ready, C.ready_zero))
W(string.format('C KV_SERVED %d   C CATCHALL %d   C ACCIDENTALLY_RIGHT %d',
    C.served, C.unserved, C.accidental_zero))
W('')
W('per carrier|ability -> handles seen:')
local keys = {}
for k in pairs(carriers) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do W(string.format('   %s  x%d', k, carriers[k])) end
W('')
W('LIMITS, so these numbers are not over-read:')
W('  * a fixture corpus is not a game corpus: these are the frames someone')
W('    already froze, so the carrier mix is whatever past rounds happened to')
W('    pin.  The reading that matters is the SOURCE split, which is a property')
W('    of the loader and not of the sample.')
W('  * TRUE_SELF_RADIUS is an offline anchor like every cast range here.  It')
W('    only ever moves a handle from "wrong" to "accidentally right"; it never')
W('    moves one into KV_SERVED.')
W('  * this says nothing about the REPLAY path.  behav-dump does not carry cast')
W('    range either, but cmrguard_counterfactual.py holds a datafeed-anchored')
W('    per-level table and declares it -- that path reaches the pivot.')

-- [hero] GH #162 -- a GetSpecialValue key the game renamed, and the census that
-- found it.  Behaviour change, so it ships GATED ('lionsplash', turbo-only) and
-- every step of the reasoning is pinned here.
--
-- WHAT WAS FOUND
--
-- `ability:GetSpecialValueInt('foo')` answers **0** when `foo` is not a key in
-- that ability's AbilityValues block.  No error, no warning, and nothing a
-- bot-side print could ever show (AGENTS.md: print() never reaches the server
-- console and the engine's error handler is broken).  A key Valve renamed in
-- some past patch therefore degrades, silently, into a zero.
--
-- hero_lion.lua read `splash_radius_scepter` off lion_finger_of_death.  In this
-- patch's KV that key does not exist; the name today is `splash_radius`:
--
--     AbilityValues/splash_radius/special_bonus_scepter    = 325
--     AbilityValues/splash_radius/affected_by_aoe_increase = 1
--
-- so the shipped read is 0 and BOTH consumers of nRadius in X.ConsiderR are
-- dead code for a scepter Lion:
--
--   * `R团战Aoe` (hero_lion.lua) counts enemies within nRadius of a candidate
--     and requires nAoeCount > 1.  At radius 0 only the candidate itself is
--     ever inside, so the count is 1 and the branch cannot fire.
--   * `R-带线` requires GetNearbyAroundLocationUnitCount(..., nRadius, ...) > 4
--     around an enemy creep.  At radius 0 it cannot clear 4.
--
-- Same family as GH #137 (野点分级是死代码) and GH #115/#104 (7.2x-era relics
-- still being read as if current): a clause that reads true-looking but is
-- structurally unreachable.
--
-- THE CENSUS BEHIND IT (tools/agent/special_value_key_census.py)
--
-- 620 GetSpecialValue reads across bots/, checked against the game's own hero
-- KV (npc_dota_hero_<name>.txt on the d2vpkr mirror -- the same source
-- tools/agent/gen_ability_meta.py already uses).  26 reads name a key that is
-- in NONE of the owning hero's abilities, plus 4 more in generic files.
-- EXACTLY ONE of them is in the focus five, and it is this one.  The other 25
-- hero files are outside this stream's polish mandate and are reported on the
-- issue, not fixed here.
--
-- The check is deliberately ONE-DIRECTIONAL, the same discipline the boots
-- supply census used (hero charter, 2026-08-24):
--
--   * a key absent from the owning hero's WHOLE KV is a PROOF the read is a
--     zero, whichever handle it was taken on;
--   * a key that IS present proves nothing, because neither the census nor
--     this file resolves which ability a Lua handle points at.  `radius` exists
--     somewhere on nearly every hero.  So findings are real; SILENCE IS NOT A
--     CLEAN BILL OF HEALTH, and §1 below is written as "no NEW offender", not
--     as "every read is correct".
--
-- THE SHAPE OF THE CHANGE (why gate-off equivalence is structural)
--
-- X.GetAbilityRSplashRadius runs the SHIPPED key FIRST and returns it whenever
-- it answers anything positive.  Only if that is 0, and only when armed in
-- Turbo, does it consult the current key.  So the gate-off path is the shipped
-- path by construction rather than by measurement -- the lesson GH #154 wrote
-- down ("放宽型的门写成「出货判据先跑一遍」的形状").  M5/M6 below are the
-- mutations that make that claim falsifiable.
--
-- ⚠️ LIMIT -- WHY THERE IS NO REAL-FRAME FIXTURE FOR THE FIRING SIDE, AND WHY A
-- GREEN RUN HERE IS NOT EVIDENCE THE GUARD IS UNNECESSARY
--
-- The offline world cannot tell the two keys apart, and §4 measures that rather
-- than asserting it:
--
--   * tests/mock/bot_api.lua's generic `^Get` default answers 0, so
--     GetSpecialValueInt returns 0 for EVERY key -- the renamed one and the
--     current one alike.  A fixture cannot watch the widening fire.
--   * the `^Has` default answers false, so bot:HasScepter() is false on every
--     real frame in tests/fixtures/ -- the branch that reads nRadius at all is
--     structurally unreachable offline.
--
-- This is the same class as the world assertions on GH #100 / #133 / #145 /
-- #154 (the 22nd: GetActualIncomingDamage reads 0 on 1040/1040 handles).  The
-- behavioural claim is therefore bought by a corpus scan, not by a fixture:
-- queue `hero-14`, pre-registered on the issue.  Until that comes back this is
-- a defensible key correction with a mechanism, NOT a measured win.
--
-- WHAT THIS FILE DOES NOT CLAIM
--
--   * That 325 is what the engine will hand back.  The KV states the value
--     under `special_bonus_scepter` with no base `value` entry, which is read
--     here as "0 without a scepter, 325 with one" -- and the call site is
--     already inside `if bot:HasScepter()`.  §5 asserts the KV shape that
--     reading rests on, so a future patch that gives the key a base value or
--     drops the scepter bonus turns this file red instead of silently
--     re-breaking the branch.
--   * That waking the two branches is GOOD.  Locally-correct is not
--     emergently-good (AGENTS.md, the lanefix lesson).  That is what the gate
--     is for.
--   * Anything about the other 25 hero files.  Not measured, not fixed, not in
--     the focus five.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local SNAPSHOT = 'tests/mock/special_value_keys.lua'
local BOTLIB   = 'bots/BotLib/'

-- AGENTS.md's five polish targets, by hero unit short name.
local FOCUS_FIVE = { 'axe', 'zuus', 'skeleton_king', 'lion', 'crystal_maiden' }

-- talentN:GetSpecialValueInt('value'): talents are special_bonus_* abilities in
-- npc_abilities.txt, not in the hero KV, and every one of them carries `value`.
local TALENT_KEYS = { ['value'] = true }

-- The single stale key this tree still contains, and the gate that handles it.
local KNOWN_STALE = 'splash_radius_scepter'
local CURRENT_KEY = 'splash_radius'
local CAND_ID     = 'lionsplash'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE key names are picked out.  The reasoning
--- block above quotes both key names while explaining them; a parser that reads
--- prose reports the prose (the mistake GH #136's first census made, and the
--- reason this is one shared function used by the census AND its own self-test).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- { key -> count } for every GetSpecialValue* read in one source string.
local function reads_in(src)
    local t = {}
    for sKey in strip_comments(src):gmatch("GetSpecialValue[%a]*%s*%(%s*['\"]([%w_]+)['\"]") do
        t[sKey] = (t[sKey] or 0) + 1
    end
    return t
end

--- THE VERDICT, factored out so it has somewhere to be tested (hero backlog
--- §24).  Unlike the boots census this predicate IS driven by real data -- the
--- tree still contains one true offender -- but the SILENT direction (a
--- mutation that stops reporting) still needs a synthetic caller, so both are
--- fed below.
local function is_stale(sKey, tLegalKeys)
    if TALENT_KEYS[sKey] then return false end
    return not tLegalKeys[sKey]
end

--- THE REPORT, factored out for the same reason.  Returns a list of readable
--- offence strings for one hero file.
local function offences_in(sHero, tReads, tLegalKeys)
    local t = {}
    for sKey in pairs(tReads) do
        if is_stale(sKey, tLegalKeys) then
            t[#t + 1] = sHero .. ' reads ' .. sKey .. ', which is in no ability of its KV'
        end
    end
    table.sort(t)
    return t
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The census, standing.

tests['[hero] focus five: the only stale GetSpecialValue key is the one the gate handles'] = function()
    api.install({})
    local tKeys = dofile(SNAPSHOT).KEYS
    local tAll = {}
    for _, sHero in ipairs(FOCUS_FIVE) do
        local tLegal = assert(tKeys[sHero], 'no KV snapshot for ' .. sHero)
        local tReads = reads_in(read_file(BOTLIB .. 'hero_' .. sHero .. '.lua'))
        assert(next(tReads) ~= nil, sHero .. ' has no GetSpecialValue reads at all; the parser lost them')
        for _, s in ipairs(offences_in(sHero, tReads, tLegal)) do tAll[#tAll + 1] = s end
    end
    assert(#tAll == 1, 'expected exactly the known offender, got ' .. #tAll
        .. ':\n  ' .. table.concat(tAll, '\n  '))
    assert(tAll[1]:find(KNOWN_STALE, 1, true) and tAll[1]:find('lion', 1, true),
        'the one offender must be lion/' .. KNOWN_STALE .. ', got ' .. tAll[1])
end

tests['[hero] the stale key survives exactly once, inside the gated helper'] = function()
    local src = strip_comments(read_file(BOTLIB .. 'hero_lion.lua'))
    local n = select(2, src:gsub(KNOWN_STALE, ''))
    assert(n == 1, 'the shipped key must stay, exactly once (it is the gate-off answer), got ' .. n)
    local m = select(2, src:gsub(CURRENT_KEY .. "'", ''))
    assert(m == 1, 'and the current key must be read exactly once, got ' .. m)

    -- Both reads live in the helper, not scattered back into ConsiderR.
    local sHelper = src:match('function X%.GetAbilityRSplashRadius%(%)(.-)\nend')
    assert(sHelper, 'X.GetAbilityRSplashRadius is gone; the call site would be ungated')
    assert(sHelper:find(KNOWN_STALE, 1, true), 'shipped key read inside the helper')
    assert(sHelper:find(CURRENT_KEY .. "'", 1, true), 'current key read inside the helper')
    assert(sHelper:find("IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the widening must sit behind IsSoakCandidate(' .. CAND_ID .. ')')
    assert(sHelper:find('IsModeTurbo', 1, true), 'and behind IsModeTurbo (turbo-only, AGENTS.md)')

    -- ConsiderR must go through the helper, not read either key itself.
    local sConsider = src:match('function X%.ConsiderR%(%)(.-)\nend\n')
    assert(sConsider and sConsider:find('X.GetAbilityRSplashRadius()', 1, true),
        'ConsiderR must take nRadius from the helper')
end

-- ---------------------------------------------------------------------------
-- 2. The helper's own behaviour, on a synthetic ability handle.
--
-- The mock cannot express "this key exists and that one does not" on its own
-- (§4), so the ability handle is given an explicit key -> value table.  That is
-- a declared fabrication, not a frame reading.

local FOCUSED = 'tests/fixtures/f_260819_182323_lion_drain_calm.lua'

--- Load Lion on a real frame with the ultimate handle's GetSpecialValueInt
--- answering out of `tKV`, then arm/disarm the gate.  The handle is fetched by
--- the SAME expression hero_lion.lua binds abilityR with, so a change to that
--- binding cannot leave this test silently driving a different object.
local function load_lion(tKV, bArmed, bTurbo)
    local J, bot = rf.load(FOCUSED)
    local sUlt = J.Skill.GetAbilityList(bot)[6]
    local hUlt = bot:GetAbilityByName(sUlt)
    rawget(hUlt, '__spec').GetSpecialValueInt = function(_, sKey) return tKV[sKey] or 0 end

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('lion'), J, bot, hUlt
end

tests['gate off: the answer is the shipped key, whatever it says'] = function()
    local X = load_lion({ [KNOWN_STALE] = 275, [CURRENT_KEY] = 325 }, false, true)
    assert(X.GetAbilityRSplashRadius() == 275, 'shipped key wins when the gate is off')

    local Y = load_lion({ [CURRENT_KEY] = 325 }, false, true)
    assert(Y.GetAbilityRSplashRadius() == 0,
        'and a shipped key that reads 0 stays 0 -- that IS the shipped behaviour')
end

tests['gate on: a shipped key that answers 0 falls through to the current key'] = function()
    local X = load_lion({ [CURRENT_KEY] = 325 }, true, true)
    assert(X.GetAbilityRSplashRadius() == 325,
        'armed, the renamed key supplies the radius the branch needs')
end

tests['gate on: the shipped key still wins when it answers anything positive'] = function()
    -- The direction that matters if Valve ever restores the old name: the
    -- widening must not override a live shipped read.
    local X = load_lion({ [KNOWN_STALE] = 275, [CURRENT_KEY] = 325 }, true, true)
    assert(X.GetAbilityRSplashRadius() == 275, 'shipped key runs first and wins')
end

tests['gate on: both keys dead is still 0, not a fabricated default'] = function()
    local X = load_lion({}, true, true)
    assert(X.GetAbilityRSplashRadius() == 0,
        'no key, no radius -- the helper must not invent one')
end

tests['gate on but NOT turbo: unchanged (turbo-only, AGENTS.md)'] = function()
    local X = load_lion({ [CURRENT_KEY] = 325 }, true, false)
    assert(X.GetAbilityRSplashRadius() == 0, 'the widening is turbo-only')
end

-- ---------------------------------------------------------------------------
-- 3. The verdict and the report, on synthetic input (hero backlog §24).
--
-- Both directions are fed.  The LOUD direction is also driven by real data here
-- (the tree still holds one offender, unlike the boots census), but the SILENT
-- direction -- a mutation that counts and then reports nothing -- has no real
-- driver at all once a fix lands, so it gets a caller of its own.

tests['self-test: is_stale answers on a synthetic key set, both ways'] = function()
    local tLegal = { ['splash_radius'] = true, ['damage'] = true }
    assert(is_stale('splash_radius_scepter', tLegal) == true, 'absent key is stale')
    assert(is_stale('splash_radius', tLegal) == false, 'present key is not')
    assert(is_stale('value', tLegal) == false, 'talent `value` is exempt, not stale')
    assert(is_stale('damage', tLegal) == false, 'present key is not, second witness')
end

tests['self-test: offences_in reports what is_stale flags, and nothing else'] = function()
    local tLegal = { ['radius'] = true }
    local t = offences_in('synthetic', { ['radius'] = 1, ['gone_key'] = 2, ['value'] = 1 }, tLegal)
    assert(#t == 1, 'exactly one offence expected, got ' .. #t)
    assert(t[1]:find('gone_key', 1, true), 'and it names the stale key, got ' .. t[1])

    local tClean = offences_in('synthetic', { ['radius'] = 1 }, tLegal)
    assert(#tClean == 0, 'a clean list reports nothing, got ' .. #tClean)
end

tests['self-test: strip_comments is what keeps prose out of the census'] = function()
    local src = "-- reads splash_radius_scepter, explained\nlocal x = a:GetSpecialValueInt( 'radius' )\n"
    local t = reads_in(src)
    assert(t['radius'] == 1, 'the real read is counted')
    assert(t[KNOWN_STALE] == nil, 'the one in the comment is not')
end

-- ---------------------------------------------------------------------------
-- 4. The LIMIT, measured rather than asserted.

tests['LIMIT: offline, every key reads 0 -- the two names are indistinguishable'] = function()
    local _, _, bot = load_lion({ [CURRENT_KEY] = 325 }, true, true)
    -- A handle the test did NOT doctor: the shipped mock default.
    local hOther = bot:GetAbilityByName('lion_impale')
    assert(hOther:GetSpecialValueInt(CURRENT_KEY) == 0, 'current key reads 0 under the mock')
    assert(hOther:GetSpecialValueInt(KNOWN_STALE) == 0, 'renamed key reads 0 too')
    assert(hOther:GetSpecialValueInt('a_key_nobody_ever_wrote') == 0,
        'and so does a key that never existed -- the mock cannot distinguish any of them')
end

tests['LIMIT: offline, HasScepter is false, so the branch that reads nRadius is unreachable'] = function()
    local _, _, bot = load_lion({}, true, true)
    assert(bot:HasScepter() == false,
        'no fixture frame carries a scepter; the scepter branch of ConsiderR cannot be driven')
end

-- ---------------------------------------------------------------------------
-- 5. The KV shape the reading rests on -- so a patch breaks this file loudly.

tests['[hero] the KV snapshot says splash_radius is a Lion key and the old name is not'] = function()
    api.install({})
    local tLion = assert(dofile(SNAPSHOT).KEYS['lion'], 'no snapshot for lion')
    assert(tLion[CURRENT_KEY] == true, CURRENT_KEY .. ' must be a lion ability key')
    assert(tLion[KNOWN_STALE] == nil, KNOWN_STALE .. ' must NOT be one -- that is the whole finding')

    -- Corroboration inside the same snapshot: the neighbouring cleave_* keys
    -- that replaced the old scepter splash wording are all there, so the
    -- absence above is not a fetch that half-failed.
    for _, sKey in ipairs({ 'cleave_damage', 'cleave_distance', 'damage_per_kill' }) do
        assert(tLion[sKey] == true, 'expected sibling key ' .. sKey .. ' in the snapshot')
    end
end

tests['[hero] the snapshot covers all five focus heroes and is not a stub'] = function()
    local tKeys = dofile(SNAPSHOT).KEYS
    for _, sHero in ipairs(FOCUS_FIVE) do
        local n = 0
        for _ in pairs(assert(tKeys[sHero], 'missing ' .. sHero)) do n = n + 1 end
        assert(n >= 25, sHero .. ' snapshot has only ' .. n .. ' keys; a truncated fetch would '
            .. 'make §1 pass by manufacturing offenders, or fail for the wrong reason')
    end
end

return tests

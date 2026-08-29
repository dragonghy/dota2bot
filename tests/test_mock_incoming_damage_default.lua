-- [ratchet] The mock's default for `GetActualIncomingDamage` -- the datum every
-- non-PURE kill-confirm in the tree is judged on.
--
-- WHAT WAS FOUND (hero stream, 2026-08-29).  `tests/mock/bot_api.lua` defined
-- neither `GetActualIncomingDamage` nor `GetMagicResist`, so both fell through to
-- the generic `^Get` default and answered **0**.  For `GetMagicResist` a 0 is the
-- right shape by accident ("no resistance recorded").  For
-- `GetActualIncomingDamage` a 0 is not a small number, it is a different world:
--
--     J.CanKillTarget( t, dmg, type )    -- jmz_func.lua:1066
--       = t:GetActualIncomingDamage( dmg, type ) >= t:GetHealth()   for non-PURE
--
-- so the answer was FALSE for every magical and physical kill-confirm, on every
-- fixture frame, at every damage number, for every hero.  41 call expressions on
-- 40 lines under bots/ route through that engine call (this header first said
-- "42 call sites"; that number is a `grep -c` of lines MENTIONING the identifier,
-- two of which are prose -- see tests/test_incoming_damage_callsite_census.lua,
-- which also names the 2 sites where the zero made a branch fire UNCONDITIONALLY
-- rather than never) -- and the second kill-confirm helper is
-- not a second opinion: `J.WillMagicKillTarget` (:1110) builds a whole
-- resistance/shield/refraction estimate and then ends in the SAME call (:1151),
-- so it was dead in exactly the same way.  Every test that watched such a branch
-- "correctly decline" was reading the mock, not the frame; and every attempt to
-- SIZE such a lever against the corpus read an artefact zero rather than a
-- measurement.  (The measurement that found it: the Wraith King Q kill-confirm
-- band census, 0 frames in band before the fix and 1 after -- see
-- tests/test_replay_260820_wk_blast_overclaim.lua.)
--
-- WHY THE FIX IS "RAW DAMAGE" AND NOT A DAMAGE MODEL.  A fixture carries no
-- resistances and no armor (make_fixture.py extracts none), so the mock cannot
-- compute a reduction without inventing one.  Its SIBLING default in the same
-- file already declared what to do with that missing datum: `GetMagicResist`
-- answers 0 -- "no resistance recorded" -- while a 0 out of
-- `GetActualIncomingDamage` says the opposite thing about the same unknown,
-- "infinite resistance".  Returning the raw damage puts the two defaults on one
-- assumption and makes the branches reachable; a test that needs a real reduction
-- overrides the method per unit through `__spec`, as with every other datum the
-- frame does not carry.
--
-- HONEST BOUNDARY: "no reduction modelled" is an UPPER bound on damage, i.e. it
-- can make a kill-confirm test greener than the game would be. It is not a claim
-- that heroes have no magic resistance -- they have 25% base. A test asserting
-- that a branch DOES fire on real numbers must say which of the two it needs.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

--- Fresh jmz_func under a clean mock world (the helpers under test are pure
--- readers of the unit handles they are given).
local function load_jmz()
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_zuus') })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

local tests = {}

tests['[ratchet] the default is the damage itself, for every damage type'] = function()
    local u = api.MakeHero('npc_dota_hero_lion', { GetHealth = 500 })
    for _, t in ipairs({ 'DAMAGE_TYPE_MAGICAL', 'DAMAGE_TYPE_PHYSICAL', 'DAMAGE_TYPE_PURE' }) do
        assert(u:GetActualIncomingDamage(400, t) == 400,
            'no reduction is modelled for ' .. t .. ', got '
            .. tostring(u:GetActualIncomingDamage(400, t)))
    end
    assert(u:GetActualIncomingDamage(0, 'DAMAGE_TYPE_MAGICAL') == 0, 'zero stays zero')
end

tests['[ratchet] a non-numeric first argument still answers a number'] = function()
    -- The generic default must never hand back a nil the callers would index or
    -- compare: `J.CanKillTarget` puts the result straight into a `>=`.
    local u = api.MakeHero('npc_dota_hero_lion')
    assert(u:GetActualIncomingDamage(nil, 'DAMAGE_TYPE_MAGICAL') == 0,
        'a missing damage argument degrades to 0, not to nil')
    assert(u:GetActualIncomingDamage() == 0, 'no arguments at all still answers 0')
end

tests['[ratchet] a per-unit __spec override still wins'] = function()
    local u = api.MakeHero('npc_dota_hero_lion')
    rawget(u, '__spec').GetActualIncomingDamage = function(_, dmg) return dmg * 0.75 end
    assert(u:GetActualIncomingDamage(400, 'DAMAGE_TYPE_MAGICAL') == 300,
        'a test that models 25% base magic resistance must be able to say so')
end

tests['[ratchet] this is what it buys: J.CanKillTarget can now answer true'] = function()
    local J = load_jmz()
    local t = api.MakeHero('npc_dota_hero_lich', { GetHealth = 149 })
    assert(J.CanKillTarget(t, 200, DAMAGE_TYPE_MAGICAL) == true,
        '200 magical into 149 HP is a kill; before the fix this was false')
    assert(J.CanKillTarget(t, 100, DAMAGE_TYPE_MAGICAL) == false,
        'and 100 into 149 is still not a kill -- the branch is reachable, not open')
end

tests['[ratchet] the OTHER helper bottoms out here too, and was dead the same way'] = function()
    -- J.WillMagicKillTarget is not a second opinion: it builds an estimate and
    -- then asks GetActualIncomingDamage. Pin that both now answer, so a future
    -- reader does not "fix" one and assume the other was fine.
    local J = load_jmz()
    local bot = api.MakeHero('npc_dota_hero_zuus')
    local t = api.MakeHero('npc_dota_hero_lich', { GetHealth = 149, GetMaxHealth = 738 })
    assert(t:GetMagicResist() == 0, 'the sibling default states no resistance recorded')
    assert(J.CanKillTarget(t, 150, DAMAGE_TYPE_MAGICAL) == true, 'CanKillTarget: kill')
    assert(J.WillMagicKillTarget(bot, t, 150, 0) == true,
        'WillMagicKillTarget reaches the same verdict on the same numbers')
    assert(J.WillMagicKillTarget(bot, t, 100, 0) == false,
        'and still refuses 100 into 149 -- reachable, not open')
end

tests['[ratchet][source] the default is declared, not inherited from ^Get'] = function()
    local f = assert(io.open('tests/mock/bot_api.lua'))
    local src = f:read('*a')
    f:close()
    assert(src:find("if key == 'GetActualIncomingDamage' then", 1, true),
        'the default must stay an explicit branch: the whole finding is that the '
        .. 'generic ^Get fallthrough states a world assumption nobody declared')
    -- The branch is only reachable because default_for receives the call's args.
    assert(src:find('local function default_for(key, ...)', 1, true),
        'default_for must keep taking the call arguments')
    assert(src:find('return default_for(key, ...)', 1, true),
        'and the unit metatable must keep forwarding them')
end

return tests

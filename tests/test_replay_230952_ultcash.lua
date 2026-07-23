-- [ultcash / freehunt#1] Dying ult cash-out predicate, pinned by the REAL
-- frame: game 20260722_230952 t=567 (9:27). Zuus at 42% (443/1045) walked
-- FORWARD into Slardar (164u) with Oracle 1047u -- never entered retreat mode,
-- so the existing retreat-gated dying branch in ConsiderR could not fire --
-- and died 1.8s later with Thundergod's Wrath READY (level 1, cd 0, mp 608 of
-- 848) while four enemies sat at 50-54% HP. Observed burst (ground truth):
-- oracle 321 + slardar 241 = 562 >= 443 current hp -- death was predictable.
--
-- J.IsDyingUnderAttack must be TRUE on this frame (armed), and its
-- counterfactuals must hold: no recent damage -> false (a poke, not a kill),
-- healthy -> false, enemies gone -> false, off the candidate -> false.
-- WasRecentlyDamagedByAnyHero is not captured by the dumper; set TRUE
-- justified by the event stream (oracle+slardar were actively hitting him).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_230952_zuus_ult_hoard.lua'
local tests = {}

local function armed(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'ultcash'
    end
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = (opts.noDamage ~= true)
    return J, bot, heroes, fx
end

tests['FIRE: the 9:27 death frame -- 42% hp, 562 incoming, under attack'] = function()
    local J, bot = armed()
    assert(J.IsDyingUnderAttack(bot) == true,
        'zuus died 1.8s after this frame with the ult ready -- the predicate '
        .. 'must read this as dying and let ConsiderR cash the ult out')
end

tests['NO-FIRE: same frame without fresh hero damage -> false'] = function()
    local J, bot = armed({ noDamage = true })
    assert(J.IsDyingUnderAttack(bot) == false,
        'low HP alone is not dying -- without an active attacker keep the ult')
end

tests['NO-FIRE: healthy zuus (80%) -> false even under attack'] = function()
    local J, bot = armed()
    local sp = rawget(bot, '__spec')
    sp.GetHealth = 840
    sp.OriginalGetHealth = 840
    assert(J.IsDyingUnderAttack(bot) == false,
        'a healthy hero being traded on is normal laning, not a cash-out')
end

tests['NO-FIRE: attackers left (out of 1200) -> false'] = function()
    local J, bot, heroes = armed()
    for _, name in ipairs({ 'npc_dota_hero_slardar', 'npc_dota_hero_oracle' }) do
        local sp = rawget(heroes[name], '__spec')
        sp.GetLocation = { x = 90000, y = 90000, z = 0 }
        rawset(heroes[name], 'GetLocation', nil)
    end
    assert(J.IsDyingUnderAttack(bot) == false,
        'nobody in range to finish me -> the ult keeps its normal rules')
end

tests['OFF: inert off the ultcash candidate (shipped default)'] = function()
    local J, bot = armed({ off = true })
    assert(J.IsDyingUnderAttack(bot) == false,
        'off the candidate the predicate must never fire')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local J, bot = armed()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J.IsDyingUnderAttack(bot) == false,
        'normal mode ships unchanged')
end

return tests

-- [hero.md backlog #1] J.IsWkReincarnationArmed gating contract.
--
-- mode_retreat_generic suppresses WK's teamfight retreat desire when
-- Reincarnation "looks armed". The shipped check used a hardcoded 160-mana
-- threshold, but Reincarnation's real trigger cost is level-dependent and
-- decreasing (skill level 1/2/3 approx 220/110/0 per Liquipedia 2026-08) --
-- at skill level 1 (WK levels 6-11, most of the midgame) the real cost is
-- 220, so 160 mana falsely reads as "armed": WK holds a losing fight
-- believing it has a free life, dies for real without reincarnating, and
-- feeds. This pins:
--   * gate OFF (no candidate / non-turbo) => byte-identical to the shipped
--     160 threshold, even when that is objectively wrong vs the real cost,
--   * gate ON (turbo + 'wkreincarnmp') + mana between the old threshold and
--     the real cost => now correctly reports NOT armed,
--   * gate ON + mana >= real cost => still correctly reports armed,
--   * ability on cooldown => never armed, gate state irrelevant.
--
-- NOTE: this is a MOCK-constructed scenario (controlled level/mana/ability
-- state), not a make_fixture.py-mined real replay frame -- no local replay
-- archive was reachable in this session (no AWS bootstrap). Real-frame
-- fixture validation is a follow-up before promoting 'wkreincarnmp'.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function make_bot(J, opts)
    opts = opts or {}
    local abilityR = api.MakeAbility('skeleton_king_reincarnation', {
        GetManaCost = opts.cost or 220,
        GetCooldownTimeRemaining = opts.cd or 0,
    })
    local bot = api.MakeHero('npc_dota_hero_skeleton_king', {
        GetMana = opts.mana or 165,
        GetLevel = opts.level or 6,
        GetAbilityByName = function(_, name)
            if name == 'skeleton_king_reincarnation' then return abilityR end
            return api.MakeAbility(name)
        end,
    })
    api.install({ bot = bot })
    return bot
end

local function fresh_jmz()
    api.reset_modules()
    return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

local function arm(J)
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function(id) return id == 'wkreincarnmp' end
end

tests['gate OFF (normal mode): 165 mana reads armed at the old 160 threshold (shipped default unchanged)'] = function()
    local J = fresh_jmz()
    GetGameMode = function() return 1 end -- not turbo
    local bot = make_bot(J, { mana = 165, cost = 220 })
    assert(J.IsWkReincarnationArmed(bot) == true,
        'off the candidate, behavior must stay byte-identical to the shipped 160 check')
end

tests['gate OFF (turbo but candidate not armed): still the old 160 threshold'] = function()
    local J = fresh_jmz()
    local bot = make_bot(J, { mana = 165, cost = 220 })
    GetGameMode = function() return GAMEMODE_TURBO end -- must set AFTER install()
    J.IsSoakCandidate = function() return false end
    assert(J.IsWkReincarnationArmed(bot) == true,
        'turbo alone must not flip the threshold; needs the wkreincarnmp candidate too')
end

tests['gate ON: 165 mana vs real cost 220 (skill lvl 1) is CORRECTLY not armed'] = function()
    local J = fresh_jmz()
    local bot = make_bot(J, { mana = 165, cost = 220 })
    arm(J) -- must arm AFTER install(): install() resets GetGameMode to non-turbo
    assert(J.IsWkReincarnationArmed(bot) == false,
        'the fix must stop the false-safe-net read: 165 < the real 220 cost')
end

tests['gate ON: 225 mana vs real cost 220 is armed'] = function()
    local J = fresh_jmz()
    local bot = make_bot(J, { mana = 225, cost = 220 })
    arm(J)
    assert(J.IsWkReincarnationArmed(bot) == true,
        'genuinely sufficient mana must still read as armed')
end

tests['gate ON: skill level 3 cost 0 is armed with near-zero mana'] = function()
    local J = fresh_jmz()
    local bot = make_bot(J, { mana = 5, cost = 0 })
    arm(J)
    assert(J.IsWkReincarnationArmed(bot) == true,
        'a free-to-trigger max-level reincarnation must read armed even at low mana')
end

tests['ability on cooldown is never armed, regardless of gate state'] = function()
    local J = fresh_jmz()
    local bot = make_bot(J, { mana = 400, cost = 220, cd = 12.5 })
    arm(J)
    assert(J.IsWkReincarnationArmed(bot) == false,
        'a reincarnation still on cooldown cannot be a safety net')
end

return tests

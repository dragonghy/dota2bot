-- [lf_rescue NARROWED / analyst waveA diff 20260723] The bisect's lf6 subset
-- carried a consistent xpm(-26.5)/lh(-4.6) drag (0/2, 20/20 mirror cells
-- negative) and the frame-level diff pinned the mechanism on lf_rescue: the
-- old trigger ("ally < 60% + 2 enemies within 900") is TRUE in every ordinary
-- 2v2 lane trade, so one exchange vacuumed 2-3 healthy heroes (carries
-- included) off their lanes for 45-90s each.
--
-- Pinned on the two watched frames:
--   * f_013254 t=37.3 -- Viper traded to ~60% vs Lion+VS top (a normal 2v2
--     poke; Viper died only because THREE rescuers left their lanes and the
--     lane stayed 1v2). Lina (mid) and CK (carry) both burned TPs here.
--   * f_011405 t=51.5 -- Axe traded to 68%->55% AT HIS OWN TOWER and walked
--     away fine; Jakiro + CK (the whole bot lane) TP'd for him anyway.
-- The narrowed contract: genuine danger only (< 35% with a diver), laning
-- cores never cross-map rescue, and no rescuing an ally under its own tower.
--
-- HP notes: the 1Hz snapshot at t=37.3 has Viper at 80% (the dip to ~60% is
-- between snapshots, event-ledger verified); tests set the historical trough
-- explicitly where the assertion depends on it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local function setHp(hero, frac)
    local sp = rawget(hero, '__spec')
    local max = hero:GetMaxHealth()
    sp.GetHealth = math.floor(max * frac)
    sp.OriginalGetHealth = math.floor(max * frac)
end

local function armed(fixture, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(fixture)
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'lf_rescue'
    end
    -- Role is not captured by the dumper; each test pins it explicitly.
    J.IsCore = function(u) return u == bot and opts.core == true end
    return J, bot, heroes, fx
end

tests['[013254 lina] trade victim at 60% is NOT a rescue target'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_013254_lina_rescue_trade.lua')
    setHp(heroes['npc_dota_hero_viper'], 0.58) -- the event-ledger trough
    assert(J.GetRescueTpTarget(bot) == nil,
        'a 60% 2v2 trade is normal laning -- the old trigger fired here and '
        .. 'stripped three lanes; the narrowed bar (<35%) must not')
end

tests['[013254 lina] genuine danger (<35%) with the SAME roster still rescues'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_013254_lina_rescue_trade.lua')
    local viper = heroes['npc_dota_hero_viper']
    setHp(viper, 0.30)
    assert(J.GetRescueTpTarget(bot) == viper,
        'the narrowing must not kill the real rescue: Viper at 30% with '
        .. 'Lion+VS on it is exactly the dive case')
end

tests['[013254 ck] laning-phase CORE never cross-map rescues (carry frame)'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_013254_ck_rescue_trade.lua',
        { core = true })
    setHp(heroes['npc_dota_hero_viper'], 0.30) -- even genuine danger
    assert(J.GetRescueTpTarget(bot) == nil,
        'the watched frame pulled the CARRY off the bot lane; laning cores '
        .. 'must hold their lane -- rescue is the supports\' job')
end

tests['[011405 jakiro] Axe at 55% trading at his own tower is not a rescue'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_011405_jak_rescue_axe.lua')
    setHp(heroes['npc_dota_hero_axe'], 0.55) -- historical trough (t=60)
    assert(J.GetRescueTpTarget(bot) == nil,
        'Axe walked away from this trade on his own; two bot-laners burned '
        .. 'TPs for nothing -- the 35% bar must hold')
end

tests['[013254 lina] under-own-tower veto: dived ally at a tower is the tower\'s job'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_013254_lina_rescue_trade.lua')
    local viper = heroes['npc_dota_hero_viper']
    setHp(viper, 0.30)
    local api = require('mock.bot_api')
    local tower = api.MakeUnit({
        GetUnitName = 'npc_dota_goodguys_tower1_top',
        GetLocation = viper:GetLocation(),
        IsAlive = true, CanBeSeen = true, IsBuilding = true,
    })
    local orig = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        if kind == UNIT_LIST_ALLIED_BUILDINGS then return { tower } end
        return orig(kind)
    end
    assert(J.GetRescueTpTarget(bot) == nil,
        'an ally fighting under its own standing tower has the peel already')
end

tests['OFF: inert off the lf_rescue candidate (shipped default)'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_013254_lina_rescue_trade.lua',
        { off = true })
    setHp(heroes['npc_dota_hero_viper'], 0.30)
    assert(J.GetRescueTpTarget(bot) == nil,
        'off the candidate the helper must stay inert')
end

return tests

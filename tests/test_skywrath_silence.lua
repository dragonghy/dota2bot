-- [GH #9] skysilence gating + decision contract for J.ShouldSkywrathHoldSeal.
-- Skywrath Mage's Ancient Seal (E) is a damage-less silence + magic-amp; casting
-- it to OPEN a fight with no follow-up wastes it. This helper decides whether to
-- HOLD such a lone seal. It is a gated (soak-candidate 'skysilence') supplement
-- to the already-promoted turbo skyburst guard, closing the combined-mana gap
-- that guard's per-ability IsFullyCastable check misses. It must be inert unless
-- the game is turbo AND this side carries the 'skysilence' id, and even when
-- armed it must hold ONLY the clearly-wasted case (no interrupt target AND no
-- affordable burst to chain after the seal). Mirrors tests/test_depthnum_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz(nMana)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skywrath_mage', { GetMana = nMana or 200 })
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

-- Build the three ability handles the helper inspects. Defaults describe the
-- BAD (lone-seal) case: seal costs 100 mana; neither follow-up is castable.
local function make_abilities(opts)
    opts = opts or {}
    local hSeal = api.MakeAbility('skywrath_mage_ancient_seal',
        { GetManaCost = opts.sealCost or 100 })
    local hBolt = api.MakeAbility('skywrath_mage_arcane_bolt', {
        GetLevel = opts.boltLevel or 1,
        IsFullyCastable = opts.boltCastable or false,
        GetManaCost = opts.boltCost or 90,
    })
    local hFlare = api.MakeAbility('skywrath_mage_mystic_flare', {
        GetLevel = opts.flareLevel or 1,
        IsFullyCastable = opts.flareCastable or false,
        GetManaCost = opts.flareCost or 200,
    })
    return hSeal, hBolt, hFlare
end

-- Arm turbo + the 'skysilence' candidate (no Customize/soak_side file in CI).
local function arm(J)
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function(id) return id == 'skysilence' end
    -- No interrupt target by default; individual tests override this.
    J.GetNearbyHeroes = function() return {} end
end

-- BAD case: armed, seal ready, no interrupt target, and no follow-up burst is
-- affordable after paying for the seal -> the seal is a lone value-less silence.
tests['armed + no interrupt + no affordable follow-up HOLDS the seal'] = function()
    local J, bot = fresh_jmz()
    arm(J)
    local hSeal, hBolt, hFlare = make_abilities()  -- follow-ups not castable
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == true,
        'a lone, follow-up-less offensive seal must be held')
end

-- BAD case variant: the exact gap the promoted skyburst guard misses. Arcane
-- Bolt IS off cooldown (IsFullyCastable true), but with only 200 mana, paying
-- the 100 seal leaves 100 -- not enough for the 90? It IS enough for 90, so use
-- a seal that leaves too little: seal 130 -> 70 left < 90 bolt.
tests['armed + follow-up off cooldown but UNAFFORDABLE after seal HOLDS'] = function()
    local J, bot = fresh_jmz()  -- 200 mana
    arm(J)
    local hSeal, hBolt, hFlare = make_abilities({
        sealCost = 130, boltCastable = true, boltCost = 90,  -- 200-130=70 < 90
    })
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == true,
        'a bolt that is off cooldown but unaffordable after the seal is no real follow-up')
end

-- GOOD (a): an enemy is visibly channeling -> the seal interrupts it and has
-- value on its own. Never hold.
tests['armed + enemy channeling ALLOWS the seal (interrupt value)'] = function()
    local J, bot = fresh_jmz()
    arm(J)
    local caster = api.MakeHero('npc_dota_hero_enemy',
        { GetTeam = 3, IsChanneling = true })
    J.GetNearbyHeroes = function() return { caster } end
    J.IsValidHero = function() return true end
    J.CanCastOnNonMagicImmune = function() return true end
    local hSeal, hBolt, hFlare = make_abilities()  -- no burst follow-up at all
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == false,
        'sealing to interrupt a channel is worthwhile alone -- must be allowed')
end

-- GOOD (b): mana + an off-cooldown burst affordable after the seal -> the seal
-- amplifies a real follow-up. Never hold.
tests['armed + affordable burst follow-up ALLOWS the seal'] = function()
    local J, bot = fresh_jmz()  -- 200 mana
    arm(J)
    local hSeal, hBolt, hFlare = make_abilities({
        sealCost = 100, boltCastable = true, boltCost = 90,  -- 200-100=100 >= 90
    })
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == false,
        'a bolt off cooldown AND affordable after the seal is a real chain -- must be allowed')
end

-- GOOD (b') Mystic Flare path: bolt down, flare off cooldown and affordable.
tests['armed + affordable Mystic Flare follow-up ALLOWS the seal'] = function()
    local J, bot = fresh_jmz(400)  -- 400 mana
    arm(J)
    local hSeal, hBolt, hFlare = make_abilities({
        sealCost = 100, boltCastable = false,
        flareCastable = true, flareCost = 200,  -- 400-100=300 >= 200
    })
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == false,
        'flare off cooldown and affordable after the seal is a real chain -- must be allowed')
end

-- OFF: not turbo -> inert (never holds), shipped normal-mode behavior untouched.
tests['normal (non-turbo) mode is inert (never holds)'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    J.IsSoakCandidate = function(id) return id == 'skysilence' end
    J.GetNearbyHeroes = function() return {} end
    local hSeal, hBolt, hFlare = make_abilities()  -- would be the BAD case in turbo
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == false,
        'outside turbo the guard must be inert')
end

-- OFF: turbo but the 'skysilence' candidate is not armed -> inert.
tests['turbo but candidate NOT armed is inert (never holds)'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function() return false end  -- shipped default off-farm
    J.GetNearbyHeroes = function() return {} end
    local hSeal, hBolt, hFlare = make_abilities()  -- would be the BAD case if armed
    assert(J.ShouldSkywrathHoldSeal(bot, hSeal, hBolt, hFlare) == false,
        'without the soak candidate the guard must be inert -- shipped behavior unchanged')
end

return tests

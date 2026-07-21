-- [GH #9] Slardar (~8:00) travel-TP interrupt guard: J.ShouldNotStartInterruptibleTp.
--
-- Bug (issue #9): Slardar begins a Town Portal at ~8:00 that is immediately
-- cancelled -- the 3s channel is started with an enemy close enough to hit it,
-- so the first tick of damage breaks it and the scroll + time are wasted.
--
-- Why this is NOT already handled by #3 (J.ShouldWalkNotTp): #3 is wired ONLY
-- into the RETREAT branch of the tpscroll consider, and even there fires only
-- for an on-face (~350) chaser WITH a refuge one step away. Slardar's 8:00 TP
-- is a TRAVEL TP (laning "go develop" / push / defend / support) -- a code path
-- that had NO enemy-interrupt check at all. So this is a genuine gap, closed by
-- the complementary guard J.ShouldNotStartInterruptibleTp (gate 'tpsafe2'),
-- scoped by its caller to non-retreat modes so it never overlaps #3.
--
-- Two contracts, mirroring the #3 tpsafe test:
--   1. Gating: inert unless turbo AND this side is the active 'tpsafe2' soak
--      candidate. Off the candidate side (shipped default) => false (TP allowed).
--   2. Firing: fires ONLY when an enemy hero within ~700 can genuinely break the
--      channel -- inside its attack reach now, or actively closing the gap. A
--      stationary enemy out of reach, or one walking away, => false (TP allowed).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

local tests = {}

-- Fresh jmz with a Slardar bot on TEAM_RADIANT, turbo on. (TEAM_RADIANT pins to
-- 1001 after constants load, so GetTeam is fixed after require -- the soak-side
-- gate matches this team against side='radiant'.)
local function fresh_jmz(botSpec)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_slardar', botSpec)
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    return J, bot
end

-- Activate the 'tpsafe2' soak candidate on radiant by writing the (gitignored)
-- soak_side file, running fn, then cleaning up. reset_modules re-requires
-- jmz_func so its cached GetSoakSideConf re-reads the file.
local function with_candidate(fn)
    local f = assert(io.open(SIDE_PATH, 'w'))
    f:write("return { side = 'radiant', cand = 'tpsafe2' }\n")
    f:close()
    local ok, err = pcall(fn)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

-- An enemy hero handle at `loc`, extrapolating to `futureLoc` in 0.5s, with a
-- given attack range. Visible + alive so J.IsValidHero accepts it.
local function make_enemy(loc, futureLoc, atkRange)
    return api.MakeHero('npc_dota_hero_axe', {
        GetTeam = 3,
        GetLocation = loc,
        GetExtrapolatedLocation = futureLoc or loc,
        GetAttackRange = atkRange or 150,
        GetHealth = 600,
        CanBeSeen = true,
    })
end

tests['ShouldNotStartInterruptibleTp is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldNotStartInterruptibleTp(bot) == false, 'normal mode must never fire')
end

tests['ShouldNotStartInterruptibleTp is inert in turbo without an active tpsafe2 candidate'] = function()
    local J, bot = fresh_jmz()
    -- No soak_side file => IsSoakCandidate('tpsafe2') false => guard off (TP allowed).
    assert(J.ShouldNotStartInterruptibleTp(bot) == false, 'off-candidate must never fire')
end

-- BAD: the 8:00 scenario. A melee enemy is on Slardar and closing; starting a
-- travel TP here gets it interrupted. Guard must SUPPRESS the TP.
tests['ShouldNotStartInterruptibleTp fires: enemy in interrupt range, closing (Slardar 8:00)'] = function()
    with_candidate(function()
        -- Melee enemy at 400, extrapolating to 250 in 0.5s => actively closing.
        local enemy = make_enemy(api.Vector(400, 0, 0), api.Vector(250, 0, 0), 150)
        local J, bot = fresh_jmz({
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 400 then return { enemy } end
                return {}
            end,
        })
        assert(J.ShouldNotStartInterruptibleTp(bot) == true,
            'an enemy in interrupt range and closing should suppress the travel TP')
    end)
end

-- BAD variant: a ranged enemy already within its own attack reach of us, even
-- though it is standing still -- it can auto-attack and break the channel.
tests['ShouldNotStartInterruptibleTp fires: ranged enemy already in attack reach (stationary)'] = function()
    with_candidate(function()
        -- Enemy at 620, attack range 600 (+150 buffer => reach 750 >= 620): can hit us.
        local enemy = make_enemy(api.Vector(620, 0, 0), api.Vector(620, 0, 0), 600)
        local J, bot = fresh_jmz({
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 620 then return { enemy } end
                return {}
            end,
        })
        assert(J.ShouldNotStartInterruptibleTp(bot) == true,
            'a ranged enemy already in attack reach can break the channel')
    end)
end

-- GOOD: no enemy near => the TP can complete, so allow it.
tests['ShouldNotStartInterruptibleTp does NOT fire: no enemy near'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz({
            GetNearbyHeroes = function() return {} end,
        })
        assert(J.ShouldNotStartInterruptibleTp(bot) == false,
            'with no enemy in range the travel TP is safe to start')
    end)
end

-- GOOD: a melee enemy is within 700 but OUT of attack reach and NOT closing
-- (walking away) => it cannot break the channel, so let the TP go.
tests['ShouldNotStartInterruptibleTp does NOT fire: enemy out of reach and receding'] = function()
    with_candidate(function()
        -- Melee (reach 300) at 650, extrapolating to 720 => moving away.
        local enemy = make_enemy(api.Vector(650, 0, 0), api.Vector(720, 0, 0), 150)
        local J, bot = fresh_jmz({
            GetNearbyHeroes = function(_, r, bEnemy)
                if bEnemy and r >= 650 then return { enemy } end
                return {}
            end,
        })
        assert(J.ShouldNotStartInterruptibleTp(bot) == false,
            'an out-of-reach, receding enemy will not break the channel')
    end)
end

-- Guard against a dead handle (defensive): never fire on a non-alive bot.
tests['ShouldNotStartInterruptibleTp does NOT fire: bot not alive'] = function()
    with_candidate(function()
        local enemy = make_enemy(api.Vector(300, 0, 0), api.Vector(150, 0, 0), 150)
        local J, bot = fresh_jmz({
            IsAlive = false,
            GetNearbyHeroes = function() return { enemy } end,
        })
        assert(J.ShouldNotStartInterruptibleTp(bot) == false,
            'a non-alive bot must fall through')
    end)
end

return tests

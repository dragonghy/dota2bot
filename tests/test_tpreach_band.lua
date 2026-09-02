-- [tpreach, GH #159] The scan-radius / reach blind band in
-- J.CanEnemyInterruptTpChannel, and the narrowness of the fix for it.
--
-- THE DEFECT (source-side, no replay needed to see it)
-- ---------------------------------------------------
-- The predicate scanned enemies within 700, then tested each against its own
-- reach, GetAttackRange() + 150. Those two numbers are not ordered. Every
-- ranged hero with attack range > 550 has reach > 700 -- viper 575 -> 725,
-- lina / CM / lion / WD / silencer 600 -> 750, drow 625 -> 775, skywrath
-- 700 -> 850 -- so on the band [700, reach] such an enemy can auto-attack us
-- and break the channel while being structurally invisible: the strike clause
-- `nNow <= nReach` cannot be true there because the enemy was never in the
-- candidate list to be asked. This is not a tuning question, it is an
-- unreachable branch, and it is live in every turbo game (tpsafe2 is
-- PROMOTED, no gate).
--
-- WHY THE FIX IS ASYMMETRIC (the part worth testing)
-- -------------------------------------------------
-- Armed, the scan widens to 1200 -- but only the STRIKE clause is widened with
-- it. The "closing the gap" clause keeps the original 700 domain. Widening
-- that one too would re-create the first cut of GH #3 (any enemy strolling in
-- from a screen away vetoes every travel TP), which measured about -15 GPM
-- with no deaths saved. So the interesting contract here is not "the guard
-- fires more", it is "the guard fires more in EXACTLY one new way".
--
-- MUTATION CHECK (run by hand when editing the predicate)
-- ------------------------------------------------------
--   * revert the scan to a literal 700 => case 2 fails, and ONLY case 2 (run
--     2026-08-24: 7 tests, 1 failure);
--   * widen the chase clause too (drop the `not bWide or nNow <= 700` guard)
--     => case 3 fails, and ONLY case 3 (same run: 7 tests, 1 failure).
-- One mutant, one dead test, each time: neither half of the fix is being
-- carried by the other half's assertions.
--
-- The unarmed cases are here for a second reason: this predicate is the
-- ungated core shared by a PROMOTED default (tpsafe2) and two gated response
-- TPs. A gated edit to it must leave the promoted path byte-identical, and
-- cases 1, 4 and 6 are what say so.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local ss = require('mock.soak_side')               -- owns bots/Customize/soak_side.lua

local tests = {}

-- The scan radius the predicate asks for is the whole subject of this file, so
-- the mock honours it literally: an enemy is returned only when the requested
-- radius actually covers where it stands. A mock that ignored `r` would make
-- every case below pass for the wrong reason.
local function fresh_jmz(enemy, enemyDist)
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_jakiro', {
        GetNearbyHeroes = function(_, r, bEnemy)
            if bEnemy and enemy ~= nil and r >= enemyDist then return { enemy } end
            return {}
        end,
    })
    api.install({ bot = bot })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    GetGameMode = function() return GAMEMODE_TURBO end
    GetTeam = function() return TEAM_RADIANT end
    return J, bot
end

-- [GH #365 §3 / GH #417 / GH #229, hero backlog `-78`] The write goes through
-- tests/mock/soak_side.lua, the switch's one owner: the bytes are read back
-- (an unarmed reading can no longer masquerade as an armed one), a switch this
-- process did not write is reported instead of clobbered, and the switch is
-- re-read after the case body so a concurrent removal is reported as itself.
-- That last part matters most HERE: cases 1 and 4 assert `== false` and
-- `== true` about the SHIPPED behaviour, and a switch deleted under case 2
-- turns its armed reading into exactly the value case 1 expects.
local function with_candidate(fn)
    ss.with_candidate('tpreach', fn)
end

-- The state this process STARTED in, taken at file-load time -- the only
-- moment that sees it. Measured on this file (hero 20260902T225428Z): with a
-- leftover `cand = 'tpreach'` planted before the run, the whole file is 7/7
-- GREEN, while the unarmed cases run ALONE under the same leftover go RED --
-- the `armed:` cases sort ahead of the `unarmed:` ones and their unconditional
-- `os.remove` threw the stranger's switch away first.
ss.assert_clean('test_tpreach_band')

local function make_enemy(loc, futureLoc, atkRange)
    return api.MakeHero('npc_dota_hero_viper', {
        GetTeam = 3,
        GetLocation = loc,
        GetExtrapolatedLocation = futureLoc or loc,
        GetAttackRange = atkRange,
        GetHealth = 600,
        CanBeSeen = true,
    })
end

-- 1. The band as it ships TODAY: a ranged enemy standing 900 away with attack
--    range 800 (reach 950) can hit us right now, and the promoted guard does
--    not see it. This is the bug, pinned. If this case ever starts returning
--    true with the candidate OFF, the fix stopped being gated.
tests['unarmed: an enemy inside its own reach but past 700 is INVISIBLE (the defect)'] = function()
    ss.with_candidate(nil, function()
        local J, bot = fresh_jmz(make_enemy(api.Vector(900, 0, 0), api.Vector(900, 0, 0), 800), 900)
        assert(J.CanEnemyInterruptTpChannel(bot) == false,
            'shipped default scans only 700 -- the [700, reach] band is unreachable')
        assert(J.ShouldNotStartInterruptibleTp(bot) == false,
            'the promoted wrapper inherits the same blind band')
    end)
end

-- 2. Armed, the same frame is seen: 900 <= reach 950 -> do not start the TP.
tests['armed: the same enemy is seen and the TP is suppressed'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz(make_enemy(api.Vector(900, 0, 0), api.Vector(900, 0, 0), 800), 900)
        assert(J.CanEnemyInterruptTpChannel(bot) == true,
            'armed, an enemy that can strike us at 900 must break the channel read')
    end)
end

-- 3. THE NARROWNESS CONTRACT. A melee enemy (reach 300) at 900 walking toward
--    us cannot touch us this frame. Under the old chase clause applied at 1200
--    it would veto the TP -- that is the -15 GPM shape from GH #3. It must
--    stay false.
tests['armed: a distant enemy merely CLOSING does not fire (chase clause not widened)'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz(make_enemy(api.Vector(900, 0, 0), api.Vector(800, 0, 0), 150), 900)
        assert(J.CanEnemyInterruptTpChannel(bot) == false,
            'widening the chase clause would re-create the too-broad first cut of GH #3')
    end)
end

-- 4/5. The original 700 domain is untouched by arming: an out-of-reach chaser
--      inside 700 still fires, armed or not.
tests['unarmed: a chaser inside 700 but out of reach still fires (old domain intact)'] = function()
    ss.with_candidate(nil, function()
        local J, bot = fresh_jmz(make_enemy(api.Vector(650, 0, 0), api.Vector(500, 0, 0), 150), 650)
        assert(J.CanEnemyInterruptTpChannel(bot) == true,
            'the promoted behaviour inside 700 must not change')
    end)
end

tests['armed: a chaser inside 700 but out of reach still fires (old domain intact)'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz(make_enemy(api.Vector(650, 0, 0), api.Vector(500, 0, 0), 150), 650)
        assert(J.CanEnemyInterruptTpChannel(bot) == true,
            'arming may only ADD the strike band, never remove the old domain')
    end)
end

-- 6. Turbo-only, like every gate in this tree: armed but in normal mode the
--    widening is off and the band is blind again.
tests['normal mode: armed makes no difference (turbo-only gate)'] = function()
    with_candidate(function()
        local J, bot = fresh_jmz(make_enemy(api.Vector(900, 0, 0), api.Vector(900, 0, 0), 800), 900)
        GetGameMode = function() return 1 end
        assert(J.CanEnemyInterruptTpChannel(bot) == false,
            'shipped normal-mode behaviour stays unchanged')
    end)
end

-- 7. Nothing nearby stays quiet on both sides of the gate -- a widened scan
--    that started firing on an empty world would be the obvious way to get
--    case 2 green for the wrong reason.
tests['no enemy at all: quiet armed and unarmed'] = function()
    ss.with_candidate(nil, function()
        local J, bot = fresh_jmz(nil, 0)
        assert(J.CanEnemyInterruptTpChannel(bot) == false, 'unarmed, empty world -> quiet')
    end)
    with_candidate(function()
        local J2, bot2 = fresh_jmz(nil, 0)
        assert(J2.CanEnemyInterruptTpChannel(bot2) == false, 'armed, empty world -> quiet')
    end)
end

return tests

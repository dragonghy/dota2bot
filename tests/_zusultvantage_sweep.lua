-- Corpus sweep for section 6 of tests/test_zuus_fight_quorum.lua, run as a
-- SUBPROCESS (backlog rule 0q keeps corpus-wide dofile loops off run_tests.lua's
-- long-lived heap).  The leading underscore keeps run_tests.lua from globbing it.
--
-- WHY THIS FILE EXISTS AS A SECOND SWEEP, 2026-09-12
-- --------------------------------------------------
-- tests/_zusfightquorum_sweep.lua measures one expression -- "how many heroes of
-- the OPPOSING side does this hero see inside R" -- at every alive hero, and its
-- histogram is a legitimate statement about the RANGE of that expression.
--
-- ⛔ WHAT IT COULD NOT SUPPORT, AND WAS ASKED TO: section 6's vantage-bias claim
-- read two of those rows against each other --
--
--     "two of Zeus's own enemies each see FOUR enemies inside 1400 while Zeus,
--      in the same frame, sees two"
--
-- -- and the two numbers COUNT DIFFERENT TEAMS.  `bEnemy = true` is relative to
-- the hero the call is made on, so at a DIRE vantage point the expression counts
-- RADIANT heroes (Zeus's own side) and at Zeus it counts DIRE heroes.  The 4 is
-- how many of ZEUS'S ALLIES were standing near centaur.  Moving the branch's
-- count to centaur's feet would not turn Zeus's 2 into 4; it would ask centaur
-- how many DIRE heroes are near him, which on that frame is also 2.  The
-- comparison is not a vantage bias, it is a quantity swap that happens to be
-- read at two places.
--
-- ⭐ SO THIS SWEEP HOLDS THE QUANTITY FIXED AND MOVES ONLY THE VANTAGE POINT.
-- One quantity throughout: "visible, castable ENEMIES OF ZEUS inside R".
--
--   ship  -- counted from Zeus's feet, the shipped expression:
--            J.GetInvUnitCount( false, J.GetNearbyHeroes( zeus, R, true, ... ) )
--   best  -- the largest such count centred on any one of those same enemies.
--
-- ⚠️ AND IT IS FOG-HONEST, which is the second reason it reads lower than the
-- old §6 did.  `best` is built from GetUnitList( UNIT_LIST_ENEMY_HEROES ) put
-- through J.CanCastOnNonMagicImmune -- the visibility filter the branch's own
-- J.GetInvUnitCount applies, and the same iteration X.ConsiderR's kill-confirm
-- block already ships.  The old §6 read a vantage hero's OWN GetNearbyHeroes,
-- which the loader answers with THAT hero's team vision (replay_fixture.lua
-- `visible_to_team(v, self:GetTeam())`), so it could count heroes Zeus's team
-- cannot see.  No fix Zeus is allowed to make may use those.
--
-- `best >= ship` is not asserted here but holds by construction on every row:
-- every hero counted in `ship` lies inside R of Zeus, and Zeus is not a vantage
-- point, so the two are independent counts -- section 6 asserts the inequality
-- it actually needs rather than assuming this one.
--
-- THE RADIUS IS READ FROM THE HERO SOURCE, NOT RE-TYPED (the M13 lesson: a
-- census that copies the constant it measures reports the old world unmoved
-- after the constant moves).
--
-- Rows written to stdout:
--   RADIUS <r>
--   Z <fixture> <subject?> <ship> <best> <inTeamFight?> <ultCastable?>
--   C <key> <int>
--   DONE
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout

local ZUUS = 'npc_dota_hero_zuus'

local paths = {}
do
    local p = assert(io.popen('ls tests/fixtures'))
    for name in p:lines() do
        if name:match('%.lua$') then paths[#paths + 1] = 'tests/fixtures/' .. name end
    end
    p:close()
end
table.sort(paths)

local RADIUS
do
    rf.load(paths[1])
    local X = rf.load_hero('zuus')
    RADIUS = assert(X.nUltFightRadius,
        'bots/BotLib/hero_zuus.lua no longer exposes X.nUltFightRadius; this sweep '
        .. 'reads that constant rather than re-typing it, so re-anchor it deliberately.')
end
out:write(string.format('RADIUS %d\n', RADIUS))

local nLive, nSubject, nFight, nGain, nMaxShip, nMaxBest = 0, 0, 0, 0, 0, 0

for _, path in ipairs(paths) do
    local ok, res = pcall(function()
        local a, b, c, d = rf.load(path, ZUUS)
        return { a, b, c, d }
    end)
    if ok and res[2] ~= nil and res[2]:GetUnitName() == ZUUS and res[2]:IsAlive() then
        local J, bot, _, fx = res[1], res[2], res[3], res[4]
        nLive = nLive + 1
        local bSubject = (fx.self == ZUUS)
        if bSubject then nSubject = nSubject + 1 end

        local nShip = J.GetInvUnitCount(false,
            J.GetNearbyHeroes(bot, RADIUS, true, BOT_MODE_NONE))

        -- The same population the shipped count draws from, enumerated globally
        -- because Thundergod's Wrath is global: every enemy hero Zeus may
        -- legally cast on, wherever they stand.
        local tVisible = {}
        for _, hEnemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
            if hEnemy ~= nil and J.CanCastOnNonMagicImmune(hEnemy) then
                tVisible[#tVisible + 1] = hEnemy
            end
        end

        local nBest = 0
        for _, hCentre in ipairs(tVisible) do
            local n = 0
            for _, hEnemy in ipairs(tVisible) do
                if GetUnitToUnitDistance(hCentre, hEnemy) <= RADIUS then n = n + 1 end
            end
            if n > nBest then nBest = n end
        end

        local bFight = J.IsInTeamFight(bot, RADIUS)
        if bFight then nFight = nFight + 1 end
        if nBest > nShip then nGain = nGain + 1 end
        if nShip > nMaxShip then nMaxShip = nShip end
        if nBest > nMaxBest then nMaxBest = nBest end

        local hUlt = bot:GetAbilityByName('zuus_thundergods_wrath')
        local bCastable = hUlt ~= nil and hUlt:IsFullyCastable()

        out:write(string.format('Z %s %d %d %d %d %d\n', path, bSubject and 1 or 0,
            nShip, nBest, bFight and 1 or 0, bCastable and 1 or 0))
    end
end

out:write(string.format('C zeus_frames %d\n', nLive))
out:write(string.format('C zeus_subject_frames %d\n', nSubject))
out:write(string.format('C in_team_fight %d\n', nFight))
out:write(string.format('C vantage_gain_frames %d\n', nGain))
out:write(string.format('C max_ship %d\n', nMaxShip))
out:write(string.format('C max_best %d\n', nMaxBest))
out:write('DONE\n')

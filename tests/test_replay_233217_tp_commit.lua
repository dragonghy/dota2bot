-- Replay-fixture regression for TP audit fix C (landing commitment), pinned by
-- the REAL mass-TP frame: game 20260722_233217 t=58.1 (0:58). Three dire
-- responders (veno/jugg/lina) TP'd for the bot-lane trigger where Sniper (71%)
-- and Sven were being pressured by WK (196u off Sniper) + Lich (592u); all
-- three landed 900-1250u out, threw ZERO attacks, and walked off to mid/jungle
-- -- Sniper died at 64.2 anyway (audit waste type 4). Subject = lina (nearest
-- responder, the one lane assignment reclaimed most visibly).
--
-- The fixed decision: with the commitment stamped for the answered trigger,
-- J.GetTpCommitDefendDesire floors the answered lane's defend desire while the
-- trigger is still hot (WK+Lich visibly there), so the laning layer cannot
-- reclaim the responder into the walk-away.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_233217_lina_tp58.lua'
local tests = {}

-- The real trigger: Sniper's position at the frame.
local TRIGGER = { x = 6073.1, y = -4450.3, z = 0 }

local function armed(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id)
        return opts.armed ~= false and id == 'tpcommit'
    end
    -- Engine lane fronts (not captured by the dumper): the answered lane's
    -- front is at the trigger; the other lanes are far.
    GetLaneFrontLocation = function(_, lane) -- luacheck: ignore
        if lane == LANE_BOT then return TRIGGER end
        return { x = -12000, y = 12000, z = 0 }
    end
    -- The commitment stamp the response branch lays down at cast time.
    bot.tpRespondLoc = TRIGGER
    bot.tpRespondUntil = fx.time + 10  -- fresh (cast was ~0.2s ago)
    return J, bot, heroes, fx
end

tests['FIRE: hot trigger (WK 196u, Lich 592u visible) -> 0.85 floor on the answered lane'] = function()
    local J, bot = armed()
    assert(J.GetTpCommitDefendDesire(bot, LANE_BOT) == 0.85,
        'the 0:58 responder must stay committed to the bot-lane fight it answered')
end

tests['LANE-BINDING: the same commitment yields nothing for the other lanes'] = function()
    local J, bot = armed()
    assert(J.GetTpCommitDefendDesire(bot, LANE_MID) == nil,
        'mid front is nowhere near the answered trigger -- no floor there')
end

tests['counterfactual: trigger gone cold (WK+Lich left) -> released'] = function()
    local J, bot, heroes = armed()
    for _, name in ipairs({ 'npc_dota_hero_skeleton_king', 'npc_dota_hero_lich' }) do
        local sp = rawget(heroes[name], '__spec')
        sp.GetLocation = { x = -90000, y = -90000, z = 0 }
        rawset(heroes[name], 'GetLocation', nil)
    end
    assert(J.GetTpCommitDefendDesire(bot, LANE_BOT) == nil,
        'nobody left at the trigger -> the responder is released, no standing around')
end

tests['counterfactual: window expired -> released'] = function()
    local J, bot, _, fx = armed()
    bot.tpRespondUntil = fx.time - 1
    assert(J.GetTpCommitDefendDesire(bot, LANE_BOT) == nil,
        'a stale commitment must not pin the bot forever')
end

tests['OFF: inert off the soak candidate (shipped default)'] = function()
    local J, bot = armed({ armed = false })
    assert(J.GetTpCommitDefendDesire(bot, LANE_BOT) == nil,
        'off tpcommit the floor never fires -- shipped behavior unchanged')
end

return tests

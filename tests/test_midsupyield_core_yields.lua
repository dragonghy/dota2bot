-- [backlog #4 "suptp x midtp 协同仲裁", owner: "suptp needs to COORDINATE with
-- midtp"; state.json keep_optimize/teambrain] midsupyield: a CORE yields the
-- team's single TP-response slot to a viable SUPPORT.
--
-- J.ShouldTpSupportTowerFight is shared by 'midtp' (any position) and 'suptp'
-- (pos 4/5). When a fight breaks out at one of our towers, both a core (via
-- midtp) and a support (via suptp) can reach the response, and the only thing
-- separating them is J.TryTakeTpResponseSlot -- a position-BLIND, module-level,
-- first-come-first-served ledger (one gated TP responder per 6s window). So on a
-- frame where both would go, WHICH one burns the slot is a race. Standard turbo
-- strategy resolves it: supports rotate/TP to defend sibling lanes (a usually-
-- free counter-kill, LANING_PLAYBOOK L5-TPDEF), cores stay on the map farming --
-- a core that TP-defends pays the higher opportunity cost (the same off-farm
-- defensive-gravity pull the residual-fingerprint diagnosis costed at ~half the
-- -25 gpm). midsupyield makes the core defer: when it is about to take the slot
-- and a viable support responder exists, it returns nil instead.
--
-- SAFETY BY CONSTRUCTION: the yield fires only when a support ALTERNATIVE exists
-- (J.HasAvailableSupportResponder, member-by-member the same gates the support
-- itself would clear in this helper). With no such support the core does NOT
-- yield, so armed can only REALLOCATE a response to a support, never DROP one.
-- Gated turbo (inherited from the helper) + 'midsupyield' + core-only; supports
-- never yield. Inert until armed.
--
-- Real-frame validation (NOT gate-plumbing). Two corpus frames where a CORE's
-- helper actually fires (a whole-corpus census over tests/fixtures/ found only
-- three such frames; two carry a viable support responder):
--   YIELD    f_260820_042612_axe_blink_init_573  luna (roles-VERIFIED pos 1)
--            t=573.0, with vengeful_spirit (roles-VERIFIED pos 5) alive/lvl10/TP
--   NODROP   f_260819_183613_storm_collapse_parity  storm_spirit (core) t=378.9,
--            NO support with a ready TP on the team -> the core must still fire.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local YIELD  = 'tests/fixtures/f_260820_042612_axe_blink_init_573.lua'
local YSUBJ  = 'npc_dota_hero_luna'
local NODROP = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua'
local NSUBJ  = 'npc_dota_hero_storm_spirit'

--- One evaluation on a real frame with `ids` armed. ALWAYS a fresh load:
--- J.TryTakeTpResponseSlot is a module-level ledger the trigger CONSUMES on
--- success, so a second call against the same world would answer the quota, not
--- the question under test.
local function run(path, subj, ids)
    local J, bot = rf.load(path, subj)
    local armed = {}
    for _, id in ipairs(ids) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    return J, bot
end
local function fires(path, subj, ids)
    local J, bot = run(path, subj, ids)
    return J.ShouldTpSupportTowerFight(bot) ~= nil
end

local tests = {}

-- ---- frame facts every outcome below rests on -------------------------------

tests['[frame] YIELD frame: a core responder, a pos-5 support alternative'] = function()
    local J, bot = run(YIELD, YSUBJ, { 'midtp' })
    assert(J.IsModeTurbo(), 'the candidate is turbo-only')
    assert(J.GetPosition(bot) == 1 and J.IsCore(bot),
        'subject luna must be a roles-verified core, got pos ' .. tostring(J.GetPosition(bot)))
    assert(bot:IsAlive() and bot:GetLevel() >= 6, 'live level-6+ responder')
    local tp = J.GetItem2(bot, 'item_tpscroll')
    assert(tp ~= nil and tp:IsFullyCastable(), 'the TP must be ready')
    assert(not J.IsInTeamFight(bot, 1600) and not J.IsGoingOnSomeone(bot)
        and not J.IsRetreating(bot), 'idle responder, all midtp preconditions hold')
end

tests['[frame] YIELD frame carries a viable support responder, pos >= 4'] = function()
    local J, bot = run(YIELD, YSUBJ, { 'midtp' })
    assert(J.HasAvailableSupportResponder(bot) == true,
        'a pos-4/5 support with a ready TP must be present, or the yield has no target')
    -- name it: the predicate must be reading a real pos>=4 teammate, not the bot.
    local found = nil
    for i = 1, #(GetTeamPlayers(GetTeam()) or {}) do
        local m = GetTeamMember(i)
        if m ~= nil and m ~= bot and J.IsValidHero(m) and m:IsAlive()
        and J.GetPosition(m) >= 4 and m:GetLevel() >= 6
        and not J.IsInTeamFight(m, 1600) and not J.IsRetreating(m) then
            local it = J.GetItem2(m, 'item_tpscroll')
            local bt = J.GetItem2(m, 'item_travel_boots')
            if (it ~= nil and it:IsFullyCastable())
            or (bt ~= nil and bt:IsFullyCastable()) then found = m:GetUnitName() end
        end
    end
    assert(found ~= nil, 'the viable support the predicate found must be enumerable here')
end

tests['[frame] NODROP frame: a core fires but NO support has a ready TP'] = function()
    local J, bot = run(NODROP, NSUBJ, { 'midtp' })
    assert(J.IsCore(bot), 'subject must reach the core-only yield clause')
    assert(J.HasAvailableSupportResponder(bot) == false,
        'this frame must have no viable support, or it is not a negative control')
end

-- ---- the lever, on real frames ----------------------------------------------

tests['[YIELD] shipped (midtp only) fires -- this is the response we reallocate'] = function()
    assert(fires(YIELD, YSUBJ, { 'midtp' }) == true,
        'the current behavior: the core TP-defends the tower fight')
end

tests['[YIELD] armed (midtp+midsupyield) the core YIELDS the slot to the support'] = function()
    assert(fires(YIELD, YSUBJ, { 'midtp', 'midsupyield' }) == false,
        'with a viable support present, the core must defer (return nil)')
end

tests['[NODROP] armed the core still fires -- a response is never DROPPED'] = function()
    assert(fires(NODROP, NSUBJ, { 'midtp' }) == true, 'baseline: fires')
    assert(fires(NODROP, NSUBJ, { 'midtp', 'midsupyield' }) == true,
        'no support alternative => the core must NOT yield; the fight is answered')
end

tests['[inert] midsupyield alone (midtp not armed) is a no-op'] = function()
    -- The helper returns nil at its first line unless midtp or suptp is armed,
    -- so midsupyield can only ever REMOVE a response an armed midtp/suptp made.
    assert(fires(YIELD, YSUBJ, { 'midsupyield' }) == false,
        'midsupyield without midtp/suptp does nothing')
end

tests['[inert] shipped default (nothing armed) unchanged'] = function()
    assert(fires(YIELD, YSUBJ, {}) == false, 'no gate armed => shipped behavior')
    assert(fires(NODROP, NSUBJ, {}) == false, 'no gate armed => shipped behavior')
end

-- ---- mutation teeth: flip one clause, the outcome must flip ------------------
-- These monkeypatch the predicate/position reader AFTER load, so each proves the
-- call-site gate genuinely depends on that clause (not on luck of the frame).

tests['[mut] no support alternative => the core does NOT yield (M1)'] = function()
    local J, bot = run(YIELD, YSUBJ, { 'midtp', 'midsupyield' })
    J.HasAvailableSupportResponder = function() return false end
    assert(J.ShouldTpSupportTowerFight(bot) ~= nil,
        'strip the support-responder clause and the yield must vanish -- '
        .. 'the yield is not firing on its own')
end

tests['[mut] a support subject is never yielded (core-only, M2)'] = function()
    local J, bot = run(YIELD, YSUBJ, { 'midtp', 'midsupyield' })
    J.IsCore = function() return false end
    assert(J.ShouldTpSupportTowerFight(bot) ~= nil,
        'treat the responder as a support and the yield must not apply')
end

tests['[mut] with a support present, the yield IS driven by the predicate (M3)'] = function()
    -- Inverse of M1 on the NODROP frame: force a support alternative and the
    -- core that otherwise fires must now yield. Proves the negative control is
    -- the absence of a support, not some other frame accident.
    local J, bot = run(NODROP, NSUBJ, { 'midtp', 'midsupyield' })
    J.HasAvailableSupportResponder = function() return true end
    assert(J.ShouldTpSupportTowerFight(bot) == nil,
        'inject a support alternative and the core must yield here too')
end

tests['[mut] the gate is behind its own soak id (M4)'] = function()
    -- Arm midtp but NOT midsupyield: even with a viable support the core fires,
    -- because the yield clause is gated. This is the shipped-safety guarantee.
    assert(fires(YIELD, YSUBJ, { 'midtp' }) == true,
        'midsupyield unarmed => the coordination is inert, the core still goes')
end

return tests

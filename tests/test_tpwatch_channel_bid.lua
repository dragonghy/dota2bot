-- [tpwatch] The eaten-TP-channel guard, run on a real frame for the first time.
--
-- Family: the director's §0b "the helper's reasoning is quietly voided by its
-- consumer" -- the BID-class variant (#29/#31/#32/#35), with a subtype that has
-- not appeared before: **the bid is delivered intact, wins the auction, and
-- changes nothing, because the mode it raises was already winning.**
--
-- `J.ShouldAbandonTpChannel` (jmz_func.lua) is read at exactly one place:
-- `mode_retreat_generic.lua:261`, which answers `BOT_MODE_DESIRE_VERYHIGH`
-- (0.9). Its comment states the theory of change: "the retreat desire wins and
-- the move order cancels the channel". Two things have to hold for that:
--   (a) 0.9 has to beat what the retreat mode would otherwise bid, AND that bid
--       has to lose to some other mode -- only a CHANGE OF ACTIVE MODE makes the
--       engine re-issue orders; and
--   (b) something has to actually issue the move -- `mode_retreat_generic`
--       defines `GetDesire()` and no `Think()`, so the order can only come from
--       the engine's built-in retreat implementation, i.e. from (a) happening.
--
-- On the frame below neither holds: the retreat mode is ALREADY bidding 0.75
-- (the promoted anti-dive guard, six lines further down the same chain) and
-- 0.75 already beats every other script mode on the frame by 0.30. Arming
-- `tpwatch` moves 0.75 -> 0.9 and re-elects the incumbent.
--
-- REAL FRAMES, both from game 20260819_222030_slot1, subject juggernaut, and
-- both from the CANDIDATE side of that mirrored pair (`mirror:...,tpwatch,...
-- :s867:radiant`, juggernaut is team 2 = radiant), so `tpwatch` was armed in
-- the game these frames were taken from:
--   * f_260819_222030_jugg_tp_start  t=437.1 -- 0.1s into the channel, 733/1154
--     hp, cast while diving out of a lost fight under a dire T1;
--   * f_260819_222030_jugg_tp_eaten  t=439.5 -- 2.5s in, 313/1155 hp, viper and
--     lich still on him, 0.5s of channel left.
-- GROUND TRUTH: the channel COMPLETED at t=440.0 and the juggernaut lived
-- another 103.5 seconds (`observed.died_after`). Riding the channel out was the
-- correct decision on this frame; the health was the price of the escape.
--
-- Reaching the body at all needed the recent-damage wiring landed alongside
-- this file: the helper's third line is `WasRecentlyDamagedByAnyHero(1.5)`,
-- which every fixture answered `false` (see tests/test_fixture_recent_damage).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F_START = 'tests/fixtures/f_260819_222030_jugg_tp_start.lua'
local F_EATEN = 'tests/fixtures/f_260819_222030_jugg_tp_eaten.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which makes
-- a cross-mode desire comparison a comparison of garbage (test_set.md §F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local CHANNEL_START_HP = 733   -- what the helper stamps on the cast frame

local function world(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function(id) return opts.armed == true and id == 'tpwatch' end
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    return J, bot, heroes, fx
end

--- Every mode script's bid on this frame. Returns { [file] = desire } plus the
--- list of files that define no script `GetDesire` for this hero at all (the
--- engine's own mode implementation bids there, and a .dem carries no mode).
local function auction(path, opts)
    local bids, engine_owned, non_numeric = {}, {}, {}
    local files = {}
    local p = io.popen('ls bots/mode_*.lua')
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    assert(#files >= 20, 'expected the full mode-file set; got ' .. #files)
    for _, f in ipairs(files) do
        local _, bot = world(path, opts)
        rawset(bot, 'tpChannelStartHealth', CHANNEL_START_HP)
        GetDesire, Think = nil, nil -- luacheck: ignore
        local ok, err = pcall(dofile, f)
        assert(ok, 'mode file failed to load: ' .. f .. ' -- ' .. tostring(err))
        if type(GetDesire) ~= 'function' then
            engine_owned[#engine_owned + 1] = f
        else
            local ok2, d = pcall(GetDesire)
            assert(ok2, 'GetDesire crashed in ' .. f .. ' -- ' .. tostring(d))
            if type(d) == 'number' then
                bids[f] = d
            else
                -- mode_ward_generic returns a bare `false` on the no-ward path.
                -- Recorded rather than coerced: it is not a number and cannot
                -- outbid anything, but pretending it is 0 would hide it.
                non_numeric[f] = d
            end
        end
    end
    GetDesire, Think = nil, nil -- luacheck: ignore
    return bids, engine_owned, non_numeric
end

-- ---------------------------------------------------------------------------
-- The frames themselves: every premise this file rests on is ASSERTED.
-- ---------------------------------------------------------------------------

tests['REAL FRAMES: a 3.0s channel, 733 -> 313 hp, and it LANDED'] = function()
    local J, bot, _, fx = world(F_START)
    assert(J.IsModeTurbo(), 'the dump is turbo -- the gate is turbo-only')
    assert(math.abs(fx.time - 437.1) < 1e-9, 'start frame pinned at t=437.1')
    assert(bot:HasModifier('modifier_teleporting'), 'the channel is running')
    assert(math.abs(J.GetModifierTime(bot, 'modifier_teleporting') - 2.9) < 1e-9,
        '2.9s of channel left, i.e. 0.1s in')
    assert(bot:GetHealth() == CHANNEL_START_HP, 'cast at 733 hp')

    local J2, bot2, _, fx2 = world(F_EATEN)
    assert(math.abs(fx2.time - 439.5) < 1e-9, 'eaten frame pinned at t=439.5')
    assert(math.abs(J2.GetModifierTime(bot2, 'modifier_teleporting') - 0.5) < 1e-9,
        'only 0.5s of channel is left by the time this frame happens')
    assert(bot2:GetHealth() == 313, '313 hp -- 420 gone since the cast')
    assert(bot2:IsAlive(), 'still alive on the frame under test')
    assert(fx2.observed.died_after == 103.5,
        'GROUND TRUTH: he landed and lived another 103.5s -- riding the channel '
        .. 'out was RIGHT here; got ' .. tostring(fx2.observed.died_after))
end

-- ---------------------------------------------------------------------------
-- The helper: its body runs, and it answers TRUE on this frame.
-- ---------------------------------------------------------------------------

tests['the cast frame stamps the channel health and does NOT abandon'] = function()
    local J, bot = world(F_START, { armed = true })
    assert(J.ShouldAbandonTpChannel(bot) == false,
        'nothing has been lost yet 0.1s in')
    assert(rawget(bot, 'tpChannelStartHealth') == CHANNEL_START_HP,
        'and the stamp the later frame is measured against is written here')
end

tests['the eaten frame answers TRUE -- and only with the gate armed'] = function()
    local J, bot = world(F_EATEN, { armed = true })
    rawset(bot, 'tpChannelStartHealth', CHANNEL_START_HP)
    -- The premise the helper's third line rests on, which was unreachable
    -- before the recent-damage wiring.
    assert(bot:WasRecentlyDamagedByAnyHero(1.5) == true,
        'viper and lich hit him 0.5s and 0.7s ago')
    local lost = CHANNEL_START_HP - bot:GetHealth()
    assert(lost >= bot:GetMaxHealth() * 0.30,
        'lost ' .. lost .. ' of a ' .. bot:GetMaxHealth() .. ' pool -- over the 30% bar')
    assert(J.ShouldAbandonTpChannel(bot) == true, 'so tpwatch says abandon')

    local J2, bot2 = world(F_EATEN)
    rawset(bot2, 'tpChannelStartHealth', CHANNEL_START_HP)
    assert(J2.ShouldAbandonTpChannel(bot2) == false,
        'shipped is inert -- the gate is the only difference')
end

tests['the retreat guard chain really reaches the tpwatch line on this frame'] = function()
    -- Everything that returns above line 261 must be silent, or the 0.9 below
    -- would be somebody else's number.
    local J, bot = world(F_EATEN, { armed = true })
    assert(bot:GetUnitName() ~= 'npc_dota_hero_skeleton_king',
        'the WK reincarnation early-out cannot apply')
    assert(DotaTime() > 0, 'the pre-horn early-out cannot apply')
    for _, m in ipairs({ 'modifier_dazzle_nothl_projection_soul_clone',
        'modifier_skeleton_king_reincarnation_scepter_active',
        'modifier_item_helm_of_the_undying_active', 'modifier_item_satanic_unholy' }) do
        assert(bot:HasModifier(m) == false, 'veto modifier ' .. m .. ' is absent')
    end
    assert(J.ShouldStayAndRegen(bot) == false, 'the regen veto is silent')
    assert(J.ShouldAbortDeepSoloPush(bot) == false, 'pushguard is silent')
end

-- ---------------------------------------------------------------------------
-- THE DEFECT: the bid arrives, wins... and re-elects the mode already in place.
-- ---------------------------------------------------------------------------

tests['DEFECT: retreat already bids 0.75 and already wins -- armed only moves it to 0.9'] = function()
    local shipped, engine_owned, non_numeric = auction(F_EATEN)
    local armed = auction(F_EATEN, { armed = true })
    local RETREAT = 'bots/mode_retreat_generic.lua'
    for f, v in pairs(non_numeric) do
        assert(v == false, f .. ' returned a non-desire that is not even false: '
            .. tostring(v))
    end

    assert(math.abs(shipped[RETREAT] - 0.75) < 1e-9,
        'shipped retreat bid on this frame is HIGH (the PROMOTED anti-dive guard, '
        .. 'six lines below tpwatch in the same chain); got ' .. tostring(shipped[RETREAT]))
    assert(math.abs(armed[RETREAT] - 0.9) < 1e-9,
        'armed retreat bid is VERYHIGH; got ' .. tostring(armed[RETREAT]))

    -- Nothing else comes close, in EITHER world.
    local runnerUp, runnerName = -1, nil
    for f, d in pairs(shipped) do
        if f ~= RETREAT and d > runnerUp then runnerUp, runnerName = d, f end
    end
    assert(runnerUp < shipped[RETREAT],
        'the SHIPPED retreat bid already wins the auction -- the highest other '
        .. 'script bid is ' .. tostring(runnerName) .. ' at ' .. tostring(runnerUp))
    for f, d in pairs(armed) do
        if f ~= RETREAT then
            assert(math.abs(d - shipped[f]) < 1e-9,
                'arming tpwatch must not move any other mode: ' .. f)
        end
    end
    -- => same winner, both worlds. The engine sees no mode change, so it has no
    -- reason to re-issue orders, so nothing cancels the channel.
    assert(#engine_owned >= 1,
        'at least one mode file defines no script GetDesire for this hero '
        .. '(mode_attack_generic only overrides the Valve-buggy hero list); '
        .. 'those bids are engine-native and a .dem carries no mode, so this '
        .. 'reconstruction covers the SCRIPT bids only -- stated, not hidden')
end

tests['DEFECT: the mode whose desire is raised has no Think() to issue the order'] = function()
    local src = io.open('bots/mode_retreat_generic.lua'):read('*a')
    assert(src:find('function GetDesire', 1, true), 'sanity: it does define GetDesire')
    assert(not src:find('\nfunction Think', 1, true),
        'REVERSE ASSERTION: mode_retreat_generic has no Think(), which is why a '
        .. 'desire bump alone cannot cancel a channel -- the move can only come '
        .. "from the engine's built-in retreat, and only a CHANGE of active mode "
        .. 'makes the engine re-issue. If a Think() is ever added here, this '
        .. 'analysis is stale and must be redone.')
end

-- ---------------------------------------------------------------------------
-- Timing: even a working seam would arrive too late.
-- ---------------------------------------------------------------------------

tests['the predicate is a LAGGING indicator: true only in the last half second'] = function()
    -- Same subject, same channel, 2.4s earlier: nothing to abandon yet. The
    -- 30%-of-max-HP bar is crossed by a burst, and a burst big enough to cross
    -- it lands late in a 3.0s channel. (Event-level reconstruction of this
    -- channel puts the true crossing at t=438.8, i.e. 1.2s before landing; the
    -- 1Hz snapshot grid can only pin the 0.5s figure below.)
    local J, bot = world(F_START, { armed = true })
    assert(J.ShouldAbandonTpChannel(bot) == false, 'silent at the cast instant')
    local J2, bot2 = world(F_EATEN, { armed = true })
    rawset(bot2, 'tpChannelStartHealth', CHANNEL_START_HP)
    assert(J2.ShouldAbandonTpChannel(bot2) == true, 'true only once 0.5s is left')
    assert(J2.GetModifierTime(bot2, 'modifier_teleporting') <= 0.5,
        'and by then the channel is all but finished -- abandoning here strands '
        .. 'a 27%-hp hero deep in enemy territory instead of landing him home')
end

return tests

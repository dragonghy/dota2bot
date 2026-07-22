-- [L1-TRADE counter-trade / LANING_PLAYBOOK] Kite-through-support, pinned by
-- the REAL frame that motivated it (f_225947_wk_trade_kite, 6:07): WK at ~81%
-- (1044 hp) stood and face-tanked a committed 2v2 trade against Lich+SF with
-- Ogre 225u beside it -- Lich's castable burst was 750 (+SF 232), WK never
-- stepped back through its support and was dead by 6:11 (died_after=4.6 in the
-- fixture ground truth).
--
-- J.ShouldCounterTradeKite must FIRE here (committed on me + backed -> kite),
-- and this frame also PINS THE COMPOSITION with the lanesurv guard:
-- J.ShouldRetreatLaneBurst does NOT fire on this frame (982 incoming < 1044 hp
-- = not lethal-grade through a peel ally), which is exactly the gap the
-- counter-trade rule covers -- lanesurv handles "they can kill me", l1kite
-- handles "they committed and I have a support to kite through".
--
-- WasRecentlyDamagedByAnyHero is not captured in the dump; the test sets it
-- TRUE justified by the timeline (WK 99%->81% across 6:04-6:07, hero damage).

package.path = 'tests/?.lua;' .. package.path
local fixture = require('mock.replay_fixture')

local tests = {}

local function arm(J, bot, opts)
    opts = opts or {}
    J.IsSoakCandidate = function(id) return id == (opts.cand or 'l1kite') end
    J.IsInLaningPhase = function() return true end
    J.IsCore = function(u) return u == bot end
    local sp = rawget(bot, '__spec')
    sp.WasRecentlyDamagedByAnyHero = (opts.noDamage ~= true)
end

tests['FIRE: WK committed-on (Lich 196u, fresh damage) with Ogre 225u backing -> kite'] = function()
    local J, bot = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    arm(J, bot)
    assert(J.ShouldCounterTradeKite(bot) == true,
        'the 6:07 death frame: committed trade + backing support must kite, not face-tank')
end

tests['COMPOSITION: lanesurv does NOT fire on this frame (982 < 1044 through peel)'] = function()
    local J, bot = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    J.IsSoakCandidate = function(id) return id == 'lanesurv' end
    J.IsInLaningPhase = function() return true end
    assert(J.ShouldRetreatLaneBurst(bot) == false,
        'the burst guard correctly stays quiet (not lethal through peel) -- '
        .. 'this frame is exactly the counter-trade gap, not the lethal-flee gap')
end

tests['NO-FIRE: no fresh hero damage (they have not committed) -> false'] = function()
    local J, bot = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    arm(J, bot, { noDamage = true })
    assert(J.ShouldCounterTradeKite(bot) == false,
        'without a committed attack on me there is nothing to counter-trade -- keep farming')
end

tests['NO-FIRE: no backing ally in range -> false (not a counter-trade without support)'] = function()
    local J, bot, heroes = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    arm(J, bot)
    -- Push every ALLY out of backing range (>900 from WK); enemies unchanged.
    local myTeam = bot:GetTeam()
    for _, h in pairs(heroes) do
        if h ~= bot and h:GetTeam() == myTeam then
            rawget(h, '__spec').GetLocation = { x = 90000, y = 90000, z = 0 }
            rawset(h, 'GetLocation', nil)
        end
    end
    assert(J.ShouldCounterTradeKite(bot) == false,
        'alone there is no support to kite through -- that case is XPSOAK/flee territory')
end

tests['OFF: inert off the soak candidate on the death frame'] = function()
    local J, bot = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    arm(J, bot, { cand = 'other' })
    assert(J.ShouldCounterTradeKite(bot) == false,
        'off the l1kite candidate the helper must stay inert (shipped default)')
end

tests['OFF: inert outside the laning phase'] = function()
    local J, bot = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    arm(J, bot)
    J.IsInLaningPhase = function() return false end
    assert(J.ShouldCounterTradeKite(bot) == false,
        'counter-trade kiting is a LANING rule; fight logic is the separate #23 track')
end

tests['ANTI-OSC: no kite inside our own commit window (watched 182007 sven)'] = function()
    local J, bot = fixture.load('tests/fixtures/f_225947_wk_trade_kite.lua')
    arm(J, bot)
    DotaTime = function() return 100 end -- luacheck: ignore
    bot.laneCommitUntil = 102  -- we initiated 2s ago; finish the trade
    assert(J.ShouldCounterTradeKite(bot) == false,
        'commit-lock: once we initiated, the kite must not abort the trade')
    bot.laneCommitUntil = 99   -- window expired -> normal kite behavior returns
    assert(J.ShouldCounterTradeKite(bot) == true,
        'after the commit window the kite works as before')
end

return tests

-- THE FOURTEENTH WORLD ASSERTION: a lazily-initialised clock stamp makes the
-- FIRST call in a fresh VM its own initialiser, so the guard that reads it is
-- true by construction -- and a fixture VM is never older than one call.
--
-- The shape, verbatim from mode_farm_generic.lua:124-126:
--
--     J.Utils['GameStates']['defendPings'] =
--         J.Utils['GameStates']['defendPings'] or { pingedTime = GameTime() }
--     if GameTime() - J.Utils['GameStates']['defendPings'].pingedTime <= 5.0 then
--         return BOT_MODE_DESIRE_NONE
--     end
--
-- In a live game this is benign: the table is filled once, a few seconds into
-- the match, and from then on `GameTime() - pingedTime` grows without bound
-- until somebody actually pings a defence. In a fixture the VM is built,
-- asked one question, and thrown away -- so the line that fills the table and
-- the line that reads it run microseconds apart, off the SAME clock reading.
-- The difference is exactly 0. The guard fires. Every time. On every frame.
--
-- WHY THIS IS WORSE THAN "ONE MODE IS UNDRIVABLE" (the shape of GH #62 §0d).
-- mode_rune_generic and mode_secret_shop_generic THROW on a fixture, so every
-- bid-level test that wraps GetDesire in pcall at least gets a chance to name
-- them. This one does not throw. It returns a number -- the floor -- and every
-- "who won the auction" claim this repository has ever published read that
-- floor as a measurement of the frame.
--
-- AND IT IS HIDING ONE OF THOSE CRASHES BEHIND ITSELF. Open the guard and
-- mode_farm_generic stops returning the floor and starts THROWING, on 5 of 94
-- declared subjects: `GetRoshanDesire` (line 370) is a real engine global that
-- the mock does not stub. So mode_farm_generic is a THIRD undrivable mode
-- file, invisible until now because the guard returns 246 lines above the
-- crash. The §0d rule ("name the modes you could not drive") was written
-- against a list of two that was never complete.
--
-- CORPUS NOTE (2026-08-21T16:xxZ, hero stream): this file was written on a
-- 94-fixture corpus; two GH #86 Lion fixtures landed the same hour and the
-- counts below were re-measured on 96. What moved: 94 -> 96 fixtures,
-- 872 -> 892 alive hero frames, push floor-as-loaded 68 -> 70 (so the
-- stamp's own share 32 -> 34; floor-with-stale unchanged at 36), farm
-- floor-with-stale 88 -> 90, and the section-5 situational domain 3 -> 4
-- frames. Every qualitative claim is unchanged -- the guard is
-- subject-independent, so growing the corpus can only grow the counts.
--
-- HOW BIG IS IT. Measured over the 94 declared subjects, both ways:
--   * farm: 94/94 floor as loaded -> 88 floor, 1 bid, 5 crashes;
--   * all three push-tower bids (one shared guard in aba_push): 68/94 floor
--     as loaded -> 36/94, i.e. the stamp alone zeroes 32 push bids;
--   * side_shop: 94/94 either way -- a guard that fires without mattering;
--   * and across all 21 drivable mode files, the AUCTION WINNER changes on
--     exactly 1 of 94 frames (defend_tower_bot 0.100 -> push_tower_bot 0.920).
-- Bids move a lot, outcomes move rarely. Both halves are asserted below; the
-- second is the one that keeps this from being an alarm.
--
-- TWO INDEPENDENT CAUSES, AND REPAIRING THE OBVIOUS ONE CHANGES NOTHING.
--   (1) the mock's GameTime() is a constant 0 (tests/mock/bot_api.lua:232)
--       while the loader answers DotaTime() with the real frame time
--       (tests/mock/replay_fixture.lua:488) -- the fixture world runs two
--       clocks that disagree by the whole elapsed game;
--   (2) the stamp is initialised FROM the same clock it is later compared to.
-- Cause (2) alone is sufficient. Teaching the loader to answer GameTime()
-- honestly -- the repair anyone would reach for first -- leaves the guard
-- firing on every frame, because the initialiser moves with it. That is
-- asserted below as a mutation probe, not argued.
--
-- FOUR SHIPPED SITES SHARE THE STAMP, THREE OF THEM IN FRONT OF A BID:
--   bots/mode_farm_generic.lua:124      -> returns DESIRE_NONE
--   bots/mode_side_shop_generic.lua:50  -> returns DESIRE_NONE
--   bots/FunLib/aba_push.lua:223        -> returns None  (all three
--                                          mode_push_tower_*_generic bids)
--   bots/FunLib/aba_defend.lua:881      -> suppresses the "come defend" ping
--                                          only; the defend BID is unaffected.
-- The defend site is listed because it is a WRITER of the shared key: whoever
-- runs first stamps it, and after that everybody else reads a zero difference.
--
-- WHAT THIS FILE DOES NOT DO. It does not change bots/. The shipped code is
-- correct for the game it runs in; what is wrong is that a one-frame VM cannot
-- represent "the match has been going for a while and nobody pinged". Whether
-- the loader should declare that assumption for every test, or every test
-- should declare it for itself (the GH #61 lane-front settlement), is a
-- harness call and belongs to the director.
--
-- ---------------------------------------------------------------------------
-- DELIVERY TO GH #84 §5: `mode_farm_generic:536` cannot be given the (b) shape
-- on this corpus either -- but for a reason that CAN be bought.
--
-- The census (tests/test_level_gate_census.lua) read `bot:GetLevel() >= 15` at
-- mode_farm_generic.lua:536 as TEETH: the farm-mode "turn and fight" block
-- (an enemy hero inside my own attack range, two allies within 900) is a live
-- turbo situation hung on a maturity proxy no turbo hero reaches. This round
-- measured the two halves of that block separately:
--
--   * the SITUATIONAL half is live and it is not a guess -- 3 alive hero
--     frames out of 872 satisfy every clause of the inner `if` (levels 4, 11
--     and 11, enemies at 55-167u, two to three allies inside 900). On those
--     three frames `GetLevel() >= 15` is the only thing standing between a
--     farming bot and Action_AttackUnit.
--   * the ENCLOSING half never co-occurs. `runMode` is set only where
--     X.ShouldRun(bot) ~= 0, which on this corpus is 5 hero frames out of 940,
--     and the intersection with the three situational frames is EMPTY.
--
-- So the (b) shape -- gated + real frame + assert the final ACTION -- has no
-- frame to stand on, exactly as `285` had none. The difference from `285` is
-- that this gap is a corpus gap, not a dumper gap: X.ShouldRun is a pure
-- function of the frame, so a replay containing the co-occurrence would settle
-- it. The corpus request is therefore live (see the report), unlike #84's,
-- which was withdrawn.
--
-- AND ONE HONEST LIMIT ON EVEN THAT REQUEST, recorded below: `runMode` is
-- file-local state with a TIME TAIL. GetDesireHelper sets it at the instant
-- ShouldRun fires and holds it for `shouldRunTime` seconds (1.33 to 3.33)
-- without re-asking. A fixture starts every VM with runTime = 0, so it can
-- only ever observe the FIRST frame of a runMode episode -- never the tail,
-- which is most of it. This is a third kind of harness blindness, distinct
-- from the twelfth (a field the dump has but the loader drops) and the
-- thirteenth (a field the dump never had): here the state is reconstructible,
-- but only at its onset.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FARM = 'bots/mode_farm_generic.lua'
local SHOP = 'bots/mode_side_shop_generic.lua'
local PUSH = {
    'bots/mode_push_tower_top_generic.lua',
    'bots/mode_push_tower_mid_generic.lua',
    'bots/mode_push_tower_bot_generic.lua',
}

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which makes
-- a desire comparison a comparison of garbage (test_set.md §F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

local function fixture_files()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

--- Install a fixture world plus the stubs every bid-level test in this repo
--- needs. `opts.stale` declares the assumption this file is about: nobody has
--- pinged a defence recently. `opts.clock` is the mutation probe -- it makes
--- GameTime() answer the frame time instead of 0.
local function world(path, subj, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path, subj)
    for k, v in pairs(DESIRE) do _G[k] = v end
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', {})
    rawset(bot, 'DefendLaneDesire', {})
    -- GH #61: the loader refuses to answer GetLaneFrontLocation; declare the
    -- pre-#61 default explicitly so the drivers below can run at all. Nothing
    -- this file asserts depends on where the lane front is -- the guard under
    -- test returns before any consumer of it.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    -- Always (re)state the clock, never only in the probe branch: `GameTime`
    -- is a plain global, test order inside a file is pairs() order, and a
    -- probe left installed would follow this file into the next one. The
    -- default here is the base mock's own constant, so the non-probe path is a
    -- no-op that cannot leak.
    if opts.clock then
        local t = fx.time
        GameTime = function() return t end -- luacheck: ignore
    else
        GameTime = function() return 0 end -- luacheck: ignore
    end
    if opts.stale then
        J.Utils['GameStates'] = J.Utils['GameStates'] or {}
        J.Utils['GameStates']['defendPings'] = { pingedTime = -1000 }
    end
    return J, bot, heroes, fx
end

--- One mode file's bid on this frame, or nil if it could not be driven.
local function bid(path, subj, file, opts)
    world(path, subj, opts)
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok = pcall(dofile, file)
    local out = nil
    if ok and type(GetDesire) == 'function' then
        local ok2, d = pcall(GetDesire)
        if ok2 and type(d) == 'number' then out = d end
    end
    GetDesire, Think = nil, nil -- luacheck: ignore
    return out
end

-- ---------------------------------------------------------------------------
-- Premises.
-- ---------------------------------------------------------------------------

tests['[premise] the fixture world runs two clocks and they disagree by the whole game'] = function()
    -- rf.load DIRECTLY, not through world(): world() restates the clock itself
    -- (see the leak note there), so asking it this question would be asking
    -- this file about its own stub. Caught by mutation M4, which moved the
    -- mock's GameTime and left the whole suite green.
    local _, _, _, fx = rf.load('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    assert(fx.time > 600, 'this frame is late in the game; got ' .. tostring(fx.time))
    assert(DotaTime() == fx.time, 'the loader answers DotaTime with the frame time')
    assert(GameTime() == 0,
        'the loader leaves GameTime at the base mock constant; got ' .. tostring(GameTime()))
    -- Stated as the size of the disagreement, so a future loader change that
    -- narrows it turns this red rather than passing silently.
    assert(math.abs(DotaTime() - GameTime()) > 600,
        'the two clocks are more than ten minutes apart on this frame')
end

tests['[reverse] four shipped sites lazily stamp the same shared key'] = function()
    local n = 0
    for _, f in ipairs({
        'bots/mode_farm_generic.lua', 'bots/mode_side_shop_generic.lua',
        'bots/FunLib/aba_push.lua', 'bots/FunLib/aba_defend.lua',
    }) do
        local src = read_file(f)
        assert(src:find('defendPings', 1, true), 'no defendPings in ' .. f)
        assert(src:find('pingedTime = GameTime()', 1, true),
            'the lazy stamp moved in ' .. f)
        n = n + 1
    end
    assert(n == 4, 'expected exactly four stamping sites; got ' .. n)

    -- Three of them guard a bid; the defend one guards a chat ping.
    local farm = read_file('bots/mode_farm_generic.lua')
    assert(farm:find("if GameTime() - J.Utils['GameStates']['defendPings'].pingedTime <= 5.0 then", 1, true),
        'the farm guard moved -- re-read the fourteenth world assertion')
    local shop = read_file('bots/mode_side_shop_generic.lua')
    assert(shop:find("if GameTime() - J.Utils['GameStates']['defendPings'].pingedTime <= 5.0 then", 1, true),
        'the side-shop guard moved')
    local push = read_file('bots/FunLib/aba_push.lua')
    assert(push:find('if GameTime() - jmz.Utils.GameStates.defendPings.pingedTime <= 5 then', 1, true),
        'the push guard moved')
    local defend = read_file('bots/FunLib/aba_defend.lua')
    assert(defend:find('if GameTime() - defendPings.pingedTime <= 6 then', 1, true),
        'the defend guard moved')
    -- ... and the defend one is followed by a chat/ping, not by a desire.
    local at = defend:find('if GameTime() - defendPings.pingedTime <= 6 then', 1, true)
    assert(defend:find('ActionImmediate_Ping', at, true),
        'the defend guard no longer fronts the ping -- it may now front a bid')
end

-- ---------------------------------------------------------------------------
-- The mechanism, on a real frame.
-- ---------------------------------------------------------------------------

tests['[MECHANISM] the first call in a fresh VM is its own initialiser'] = function()
    local J, _, _, fx = world('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    assert(J.Utils.GameStates.defendPings == nil,
        'the stamp starts unset in a fresh VM -- that is the whole problem')
    local d = bid('tests/fixtures/f_260820_043637_axe_ring_alone.lua', nil, FARM)
    assert(d == 0, 'farm bids the floor on this frame; got ' .. tostring(d))
    local _ = fx
end

tests['[MECHANISM] the stamp equals the clock, so the difference is exactly 0'] = function()
    local J = world('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    -- Reproduce the shipped two lines here rather than restating their effect.
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] =
        J.Utils['GameStates']['defendPings'] or { pingedTime = GameTime() }
    local diff = GameTime() - J.Utils['GameStates']['defendPings'].pingedTime
    assert(diff == 0, 'the difference is exactly zero, not merely small; got ' .. tostring(diff))
    assert(diff <= 5.0, 'and so every shipped guard on it fires')
end

tests['[MECHANISM] repairing the clock does NOT open the guard'] = function()
    -- The mutation probe: give GameTime() the honest frame time. The guard
    -- still fires, because the initialiser reads the same clock. Anyone who
    -- "fixes" the loader's GameTime and declares the world assertion closed is
    -- wrong, and this assertion is here to say so.
    local path = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
    local J, _, _, fx = world(path, nil, { clock = true })
    assert(GameTime() == fx.time, 'the probe really did move the clock')
    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] =
        J.Utils['GameStates']['defendPings'] or { pingedTime = GameTime() }
    assert(GameTime() - J.Utils['GameStates']['defendPings'].pingedTime == 0,
        'still exactly zero -- the two causes are independent')
    assert(bid(path, nil, FARM, { clock = true }) == 0,
        'and the farm bid is still the floor with an honest clock')
end

-- ---------------------------------------------------------------------------
-- The world assertion, over the corpus.
-- ---------------------------------------------------------------------------

local corpus_cache
local function corpus()
    if corpus_cache then return corpus_cache end
    local s = { fixtures = 0, unset = 0, guard_fires = 0,
                farm_floor_plain = 0, farm_floor_stale = 0, farm_moved = {} }
    for _, path in ipairs(fixture_files()) do
        s.fixtures = s.fixtures + 1
        local J = world(path)
        if J.Utils.GameStates.defendPings == nil then s.unset = s.unset + 1 end
        J.Utils['GameStates']['defendPings'] =
            J.Utils['GameStates']['defendPings'] or { pingedTime = GameTime() }
        if GameTime() - J.Utils['GameStates']['defendPings'].pingedTime <= 5.0 then
            s.guard_fires = s.guard_fires + 1
        end
        local plain = bid(path, nil, FARM)
        local stale = bid(path, nil, FARM, { stale = true })
        if plain == 0 then s.farm_floor_plain = s.farm_floor_plain + 1 end
        if stale == 0 then s.farm_floor_stale = s.farm_floor_stale + 1 end
        if plain ~= stale then
            s.farm_moved[#s.farm_moved + 1] = { path = path, plain = plain, stale = stale }
        end
    end
    corpus_cache = s
    return s
end

tests['[WORLD ASSERTION] the stamp is unset, and the guard fires, on 100/100 fixtures'] = function()
    local s = corpus()
    assert(s.fixtures == 100, 'expected 100 fixtures; got ' .. s.fixtures)
    assert(s.unset == 100,
        'every fixture VM starts with the stamp unset; got ' .. s.unset)
    assert(s.guard_fires == 100,
        'and the guard fires on every one of them; got ' .. s.guard_fires)
    -- The guard reads VM-global state and a global clock -- nothing about the
    -- subject hero enters it. So "94/94 fixtures" is "940/940 hero frames"
    -- by construction, and that is an argument, not a sample.
end

tests['[WORLD ASSERTION] mode_farm_generic bids the floor on every fixture as loaded'] = function()
    local s = corpus()
    assert(s.farm_floor_plain == 100,
        'farm bids DESIRE_NONE on every fixture as loaded; got '
        .. s.farm_floor_plain .. '/100')
end

tests['[MEASURED] declaring "no recent defend ping" moves the farm bid on 6 fixtures'] = function()
    local s = corpus()
    -- The size of what every auction-level claim in this repo has been reading
    -- as a measurement of the frame -- and the shape of it is not what it looks
    -- like from the count alone. Of the 6, exactly ONE is a bid; the other five
    -- are the mode file CRASHING (next test).
    assert(#s.farm_moved == 6,
        'expected 6 of 96 declared subjects to move off the floor; got '
        .. #s.farm_moved)
    local bids, crashes = 0, 0
    for _, m in ipairs(s.farm_moved) do
        assert(m.plain == 0, 'every move starts at the floor: ' .. m.path)
        if m.stale == nil then crashes = crashes + 1 else bids = bids + 1 end
    end
    assert(bids == 1 and crashes == 5,
        'one real bid, five crashes; got ' .. bids .. ' and ' .. crashes)
    assert(s.farm_floor_stale == 94, 'and 94 stay at the floor for other reasons; got '
        .. s.farm_floor_stale)
end

tests['[WORLD ASSERTION] the guard is also HIDING a crash: farm is a third undrivable mode'] = function()
    -- GH #62 §0d named two mode files that cannot be driven on a fixture
    -- (mode_rune_generic, mode_secret_shop_generic) and made it a rule to say
    -- so in any bid-level test. mode_farm_generic is a THIRD, and nobody could
    -- have known: the ping guard returns at line 124, and the unstubbed engine
    -- global sits at line 371. Open the guard and the crash appears.
    local path = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
    assert(bid(path, nil, FARM) == 0, 'shut: the floor, no error')
    world(path, nil, { stale = true })
    GetDesire, Think = nil, nil -- luacheck: ignore
    assert(pcall(dofile, FARM), 'the farm mode file loads')
    local ok, err = pcall(GetDesire)
    GetDesire, Think = nil, nil -- luacheck: ignore
    assert(not ok, 'open: it does not return the floor, it throws')
    assert(tostring(err):find('GetRoshanDesire', 1, true),
        'the missing engine global is GetRoshanDesire; got ' .. tostring(err))
    assert(tostring(err):find(':371:', 1, true),
        'at mode_farm_generic.lua:371; got ' .. tostring(err))
    -- It is a real engine API (.luacheckrc read_globals lists it), so this is
    -- a mock gap, not a typo in bots/. Recorded here rather than patched: what
    -- the mock should answer for "how badly does the team want Roshan" is a
    -- harness call, and stubbing it changes what several other files see.
    local rc = read_file('.luacheckrc')
    assert(rc:find('"GetRoshanDesire"', 1, true),
        'GetRoshanDesire is a declared engine global')
    -- One line above it is `bot:GetLevel() >= 23`, which the level-gate census
    -- (tests/test_level_gate_census.lua) read as REDUNDANT. That reading came
    -- from the source, not from a frame -- and now we know why it could not
    -- have come from a frame.
    local src = read_file('bots/mode_farm_generic.lua')
    assert(src:find('or (bot:GetLevel() >= 23 and nAlliesCount >= 3)', 1, true),
        'the census row one line above the crash moved')
end

tests['[WORLD ASSERTION] the stamp pins all three push bids on 35 of 98 fixtures'] = function()
    -- aba_push.GetPushDesire is the shared source of all three push-tower bids,
    -- so this is one guard, not three -- and unlike farm, plenty of frames
    -- reach it with something real to say.
    local floor_plain, floor_stale = 0, 0
    for _, path in ipairs(fixture_files()) do
        if bid(path, nil, PUSH[2]) == 0 then floor_plain = floor_plain + 1 end
        if bid(path, nil, PUSH[2], { stale = true }) == 0 then
            floor_stale = floor_stale + 1
        end
    end
    assert(floor_plain == 74, 'as loaded, 74 of 100 push bids are the floor; got ' .. floor_plain)
    assert(floor_stale == 38, 'with the ping declared stale, 38; got ' .. floor_stale)
    -- 68/36 -> 70/36 on 2026-08-21T16:xxZ: the hero stream added the two GH #86
    -- Lion frames and BOTH of them bid the floor as loaded and something real
    -- with the ping declared stale, so the stamp's own share went 32 -> 34.
    -- Corpus growth, not a behaviour change: floor_stale did not move.
    -- 70/36 -> 72/37 on 2026-08-22T00:30Z: the two GH #63 cask frames. This
    -- time the growth is NOT symmetric -- both bid the floor as loaded, but
    -- only one of them says something real once the ping is declared stale
    -- (f_260820_042009_cm_cask_far; the close frame is a five-hero scrum where
    -- push stays at the floor for its own reasons). So the stamp's own share
    -- goes 34 -> 35 and the other-reasons share grows by one as well.
    -- 72/37 -> 74/38 on 2026-08-22T09:5xZ: the strategy stream's two owner-P2
    -- TP-home frames. Asymmetric again, and the other way round from the cask
    -- pair: BOTH bid the floor as loaded, and exactly one of them says
    -- something real once the ping is declared stale
    -- (f_260822_063559_slardar_tp_forward, 0 -> 0.1; the lina frame stays at 0
    -- both ways). So the stamp's own share goes 35 -> 36.
    assert(floor_plain - floor_stale == 36,
        'the stamp alone accounts for 36 zeroed push bids')
    local push = read_file('bots/FunLib/aba_push.lua')
    local n = 0
    for _ in push:gmatch('defendPings') do n = n + 1 end
    -- three mentions: two in the `or` assignment, one in the guard.
    assert(n == 3, 'aba_push stamps and reads the key exactly once each; got ' .. n)
end

tests['[negative control] side_shop is pinned by the guard AND by something else'] = function()
    -- The honest counterweight to the push number: side_shop sits behind the
    -- same guard, but opening it changes nothing anywhere in the corpus. A
    -- guard that fires is not automatically a guard that matters.
    local floor_plain, floor_stale = 0, 0
    for _, path in ipairs(fixture_files()) do
        if bid(path, nil, SHOP) == 0 then floor_plain = floor_plain + 1 end
        if bid(path, nil, SHOP, { stale = true }) == 0 then floor_stale = floor_stale + 1 end
    end
    assert(floor_plain == 100 and floor_stale == 100,
        'side_shop bids the floor either way; got ' .. floor_plain .. '/' .. floor_stale)
end

tests['[MEASURED] and on one frame it decides the auction: defend 0.10 -> push 0.92'] = function()
    -- The wider sweep (all 21 drivable mode files x 94 declared subjects, both
    -- ways) found the winner changing on exactly 1 of 94 frames. Bids move a
    -- lot; outcomes move rarely -- both halves of that belong in the record.
    -- That one frame is driven here in full rather than quoted.
    local path = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'
    local files = {}
    do
        local p = assert(io.popen('ls bots/mode_*.lua'))
        for l in p:lines() do files[#files + 1] = l end
        p:close()
    end
    assert(#files >= 20, 'expected the full mode-file set; got ' .. #files)
    local function auction(opts)
        local bn, bv = 'NOBODY', -math.huge
        for _, f in ipairs(files) do
            local d = bid(path, nil, f, opts)
            if d ~= nil and d > bv then bn, bv = f, d end
        end
        return bn, bv
    end
    local wa, va = auction(nil)
    local wb, vb = auction({ stale = true })
    assert(wa == 'bots/mode_defend_tower_bot_generic.lua',
        'as loaded, defend_tower_bot wins; got ' .. wa)
    assert(math.abs(va - 0.1) < 1e-9, 'with 0.100; got ' .. tostring(va))
    assert(wb == 'bots/mode_push_tower_bot_generic.lua',
        'with the ping declared stale, push_tower_bot wins; got ' .. wb)
    assert(math.abs(vb - 0.92) < 1e-9, 'with 0.920 -- the push cap; got ' .. tostring(vb))
end

tests['[self-audit] it does not retract retnear -- all three published winners hold'] = function()
    -- The question this file owes the rest of the team: does the world
    -- assertion RETRACT any auction claim already published? Checked here for
    -- this stream's most explicit one, tests/test_retnear_radius_parity.lua.
    -- NOTE ON WHAT THIS ASSERTION IS WORTH: it pins a NON-change, so it is
    -- weakly mutation-sensitive by construction -- opening or shutting the
    -- guard leaves both sides equal. What it does buy is a tripwire for the
    -- day some other change lifts a farm or push bid past 0.369 on this frame;
    -- the values are asserted, not just the equality.
    local path = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
    local files = {}
    do
        local p = assert(io.popen('ls bots/mode_*.lua'))
        for l in p:lines() do files[#files + 1] = l end
        p:close()
    end
    local function auction(armed, stale)
        local bn, bv = 'NOBODY', -math.huge
        for _, f in ipairs(files) do
            world(path, nil, { stale = stale })
            local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
            J.IsSoakCandidate = function(x) return armed and x == 'retnear' end
            GetDesire, Think = nil, nil -- luacheck: ignore
            pcall(dofile, f)
            if type(GetDesire) == 'function' then
                local ok, d = pcall(GetDesire)
                if ok and type(d) == 'number' and d > bv then bn, bv = f, d end
            end
            GetDesire, Think = nil, nil -- luacheck: ignore
        end
        return bn:gsub('bots/mode_', ''):gsub('_generic.lua', ''), bv
    end
    local sw, sv = auction(false, false)
    local sw2, sv2 = auction(false, true)
    assert(sw == 'retreat' and sw2 == 'retreat',
        'retnear shipped: retreat wins either way; got ' .. sw .. '/' .. sw2)
    assert(math.abs(sv - sv2) < 1e-9 and sv > 0.6903 and sv < 0.6904,
        'at 0.690 either way; got ' .. tostring(sv) .. '/' .. tostring(sv2))
    local aw, av = auction(true, false)
    local aw2, av2 = auction(true, true)
    assert(aw == 'laning' and aw2 == 'laning',
        'retnear armed: laning wins either way; got ' .. aw .. '/' .. aw2)
    assert(math.abs(av - av2) < 1e-9 and av > 0.36 and av < 0.37,
        'at 0.369 either way; got ' .. tostring(av) .. '/' .. tostring(av2))
    -- HONEST LIMIT: eleven other files in tests/ make auction-level claims and
    -- NONE of them was re-run this round. Per the charter's one-at-a-time rule
    -- (backlog 0b/0c) they are re-read when next touched, not batch-refreshed.
end

-- ---------------------------------------------------------------------------
-- GH #84 §5: mode_farm_generic:536.
-- ---------------------------------------------------------------------------

local block_cache
--- Every clause of the runMode fight-back block EXCEPT the level gate, over
--- every alive hero frame. Loaded once per team so that GetTeam()-relative
--- helpers (J.GetDistanceFromEnemyFountain) answer for the right side.
local function block_domain()
    if block_cache then return block_cache end
    local s = { hero_frames = 0, satisfied = {}, corpses_excluded = 0 }
    for _, path in ipairs(fixture_files()) do
        local fx = dofile(path)
        local first_of_team, team_order = {}, {}
        for _, u in ipairs(fx.units) do
            if u.name:match('^npc_dota_hero_') and u.alive and not first_of_team[u.team] then
                first_of_team[u.team] = u.name
                team_order[#team_order + 1] = u.team
            end
        end
        for _, team in ipairs(team_order) do
            local J, _, heroes = rf.load(path, first_of_team[team])
            for _, u in ipairs(fx.units) do
                if u.name:match('^npc_dota_hero_') and u.team == team then
                    local hero = heroes[u.name]
                    if not u.alive then
                        -- GH #78: a corpse is not a subject. Counted, not used.
                        s.corpses_excluded = s.corpses_excluded + 1
                    else
                        s.hero_frames = s.hero_frames + 1
                        local ar = hero:GetAttackRange()
                        if ar > 1400 then ar = 1400 end
                        local allies = hero:GetNearbyHeroes(900, false, BOT_MODE_NONE)
                        local foes = hero:GetNearbyHeroes(ar + 50, true, BOT_MODE_NONE)
                        if J.IsValid(foes[1])
                            and #allies >= 2
                            and not foes[1]:IsAttackImmune()
                            and u.name ~= 'npc_dota_hero_bristleback'
                            and J.GetDistanceFromEnemyFountain(hero) > 2200
                        then
                            s.satisfied[#s.satisfied + 1] = {
                                path = path, name = u.name, level = hero:GetLevel(),
                                allies = #allies,
                                dist = GetUnitToUnitDistance(hero, foes[1]),
                            }
                        end
                    end
                end
            end
        end
    end
    block_cache = s
    return s
end

tests['[#84 §5] the 535 block has teeth: 4 alive frames where only the level gate stands'] = function()
    local s = block_domain()
    -- 911 -> 930 on 2026-08-22T09:5xZ (the two owner-P2 TP-home frames, 19 live
    -- hero-frames between them -- crystal_maiden is dead on the lina one).
    -- The DENOMINATOR moved and the finding did not: still exactly 4 satisfied
    -- frames, the same four.
    assert(s.hero_frames == 930,
        'expected the 930 alive hero frames the corpus carries; got ' .. s.hero_frames)
    -- 3 -> 4 on 2026-08-21T16:xxZ: the hero stream's f_260820_182906_lion_drain_
    -- survived (GH #86's "must not release" frame) is a FOURTH instance of this
    -- situational domain -- a level 8 Lion with luna 177u away and two allies
    -- inside 900. It arrived as a side effect of pinning a Mana Drain decision,
    -- which is worth noting for GH #84 section 5: the shape is not as rare as
    -- three-in-872 suggested, it is just never looked for.
    assert(#s.satisfied == 4,
        'four alive frames satisfy every clause but the level gate; got ' .. #s.satisfied)
    local by = {}
    for _, f in ipairs(s.satisfied) do by[f.name:gsub('npc_dota_hero_', '')] = f end
    assert(by.chaos_knight and by.chaos_knight.level == 4,
        'f_260819_142047: a level 4 chaos knight with two allies')
    assert(by.dragon_knight and by.dragon_knight.level == 11,
        'f_260819_222559: a level 11 dragon knight with three allies')
    assert(by.juggernaut and by.juggernaut.level == 11,
        'f_260819_222559: a level 11 juggernaut with three allies')
    assert(by.lion and by.lion.level == 8,
        'f_260820_182906: a level 8 Lion with luna 177u away and two allies')
    for _, f in ipairs(s.satisfied) do
        assert(f.level < 15,
            'the whole point: not one of them reaches the gate; ' .. f.name)
        assert(f.dist < 200,
            'the enemy is inside melee range on all four; got ' .. math.floor(f.dist))
    end
end

tests['[#84 §5] but runMode never co-occurs, so the (b) shape has no frame'] = function()
    -- runMode is set only where the farm bid is the escape return
    -- (DESIRE_ABSOLUTE * 1.1); it is unreachable on any frame where the bid is
    -- anything else, because runTime starts at 0 in a fresh VM.
    local s = block_domain()
    local escaped = 0
    for _, f in ipairs(s.satisfied) do
        local d = bid(f.path, f.name, FARM, { stale = true })
        if d ~= nil and d > 1.0 then escaped = escaped + 1 end
    end
    assert(escaped == 0,
        'not one of the three situational frames is also a runMode frame; got ' .. escaped)
    -- Reported, and reproducible from the wider sweep in this round's report:
    -- across all 940 hero frames (corpses included) with the ping stamp
    -- declared stale, exactly 5 reach the escape return, and none of those 5
    -- satisfies the block above. The intersection is empty from both sides.
end

tests['[reverse] mode_farm_generic:536 and its block are pinned verbatim'] = function()
    local src = read_file('bots/mode_farm_generic.lua')
    assert(src:find('if not bot:IsInvisible() and bot:GetLevel() >= 15', 1, true),
        'the level gate under #84 §5 moved -- re-read this file before editing')
    assert(src:find('local runModeAllies = bot:GetNearbyHeroes(900,false,BOT_MODE_NONE);', 1, true),
        'the ally radius moved')
    -- The THRESHOLD, separately: block_domain() below restates this clause
    -- rather than reading it, so without this line the number 2 is unpinned.
    -- Caught by mutation M7 (>= 2 -> >= 3), which left the suite green.
    assert(src:find('and #runModeAllies >= 2', 1, true),
        'the ally count moved -- re-measure the three frames in block_domain')
    assert(src:find('local runModeEnemyHeroes = bot:GetNearbyHeroes(botAttackRange +50,true,BOT_MODE_NONE);', 1, true),
        'the enemy radius moved')
    assert(src:find('and not runModeEnemyHeroes[1]:IsAttackImmune()', 1, true),
        'the magic-immunity clause moved')
    assert(src:find('and botName ~= "npc_dota_hero_bristleback"', 1, true),
        'the bristleback exclusion moved')
    assert(src:find('and J.GetDistanceFromEnemyFountain(bot) > 2200', 1, true),
        'the fountain clause moved')
    assert(src:find('bot:Action_AttackUnit(runModeEnemyHeroes[1], true);', 1, true),
        'the action this block exists to reach moved')
end

tests['[recorded] one ShouldRun leg can never reach the block on its trigger frame'] = function()
    -- X.ShouldRun returns 2 when `enemyFountainDistance < 1000`, and the block
    -- it enables requires `J.GetDistanceFromEnemyFountain(bot) > 2200`. Same
    -- helper, same frame, disjoint intervals -- so that leg cannot open the
    -- fight-back block on the frame it fires. It can only do so via the tail
    -- (below), and only if the bot covers 1200 units in the two seconds the
    -- leg buys, which needs ~600 movement speed.
    local src = read_file('bots/mode_farm_generic.lua')
    assert(src:find('if enemyFountainDistance < 1000', 1, true),
        'the deep-in-their-base leg moved')
    assert(src:find('and J.GetDistanceFromEnemyFountain(bot) > 2200', 1, true),
        'the block clause it contradicts moved')
    assert(true)
end

tests['[recorded] a fixture can only see the FIRST frame of a runMode episode'] = function()
    -- GetDesireHelper holds runMode for `shouldRunTime` seconds without
    -- re-asking (`if runTime ~= 0 and DotaTime() < runTime + shouldRunTime`),
    -- and the values ShouldRun returns are used as that duration: 1.33 to 3.33
    -- seconds. A fixture VM starts with runTime = 0, so it observes only the
    -- instant the episode opens -- never the tail, which is most of it.
    -- INFERENCE, stated as one: the block's true in-game domain is therefore
    -- larger than anything this harness can count, by a factor this harness
    -- cannot estimate. Not a reason to arm anything; a reason not to read
    -- "5 frames out of 940" as the in-game frequency.
    local src = read_file('bots/mode_farm_generic.lua')
    assert(src:find('and DotaTime() < runTime + shouldRunTime', 1, true),
        'the runMode hold moved')
    assert(src:find('runTime = DotaTime();', 1, true), 'the runMode onset moved')
    assert(src:find('shouldRunTime = X.ShouldRun(bot);', 1, true),
        'the duration and the trigger are still the same number')
    assert(true)
end

return tests

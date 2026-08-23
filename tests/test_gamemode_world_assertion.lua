-- THE FIFTEENTH WORLD ASSERTION: on every fixture the world is Turbo and not
-- Turbo at the same time, and which one you get depends on how the shipped
-- line spells the constant.
--
--   GetGameMode() == GAMEMODE_TURBO   -> TRUE  on 96/96 fixtures
--   GetGameMode() == 23               -> FALSE on 96/96 fixtures
--
-- Both spellings name the same number in the engine (GAMEMODE_TURBO is 23);
-- bots/hero_selection.lua and bots/ability_item_usage_generic.lua even carry a
-- self-heal for engines that do not define it -- `if GAMEMODE_TURBO == nil
-- then GAMEMODE_TURBO = 23 end`. So the shipped code is coherent and this is
-- not a defect in bots/. It is a defect in the world the fixtures run in, and
-- it is caused by the mock trying to be helpful:
--
--   * tests/mock/bot_api.lua auto-defines every unknown ALL_CAPS global as a
--     distinct sentinel integer starting at 1001, so GAMEMODE_TURBO resolves
--     to 1149 rather than 23 -- AND, because it is therefore never nil, the
--     shipped self-heal that would have set it to 23 never runs;
--   * tests/mock/replay_fixture.lua:487 declares the fixture world Turbo with
--     `GetGameMode = function() return GAMEMODE_TURBO end`, i.e. it returns
--     that same sentinel.
--
-- The two therefore agree with each other and disagree with 23. Every shipped
-- line that spells the constant by NAME reads "turbo"; every shipped line that
-- spells it as the literal 23 reads "not turbo". Nine shipped comparison sites
-- across SEVEN files are on the wrong side of that split, and the split runs
-- through the middle of one expression (FunLib/aba_push.lua:172-172) and
-- through the middle of one table literal (the same file's gameStateCache,
-- whose currentTime field is built the number way while its four isEarlyGame /
-- isMidGame / isLateGame / isLaningPhase siblings are built the name way).
--
-- HOW BIG IS IT, MEASURED (both halves, as always):
--   * the split itself is total: 96/96 by name, 0/96 by number, and
--     J.IsModeTurbo() -- the name-spelled helper with 94 call sites -- reads
--     TRUE on 96/96;
--   * the LANING BID MOVES ON 21 OF 96 FIXTURES, and every one of the 21 moves
--     DOWN when the game mode is made honest (0.446 -> 0.369, 0.369 -> 0.2).
--     The turbo clock dilation at mode_laning_generic.lua:156 (`currentTime *
--     1.65`) is off on every fixture, so every fixture reads the laning desire
--     ladder eighty-six lines below it (242-244) as though the match were
--     younger than it is. Auction-level conclusions in this repository are
--     therefore biased toward laning, by a rung, on 22% of the corpus.
--     (FunLib/override_generic/mode_laning_generic.lua carries a SECOND copy
--     of the same dilation and ladder, but it is dofile'd only for heroes in
--     Utils.BuggyHeroesDueToValveTooLazy, so it is not what the corpus rides;
--     this file named the wrong copy until a mutation said otherwise, and both
--     are pinned below.);
--   * across the whole mode auction (96 frames x 21 mode files, both ways)
--     the LANING BID IS THE ONLY BID THAT MOVES -- 21 moved cells out of
--     2016 -- but that is enough to change the AUCTION WINNER on 18 of 96
--     frames, and on 10 of those the winning MODE ITSELF changes: seven
--     laning -> defend_tower_bot and three laning -> retreat. On more than a
--     tenth of the corpus the fixture says the bot is laning and the honest
--     world says it is defending or running away. (The fourteenth world
--     assertion moved 1 winner in 94; this one moves 18.)
--   * the push-cap clause that the split runs through does NOT move on this
--     corpus (0/96 either way) -- see the honest boundary on it below.
--
-- DELIVERY TO GH #84 §5. The default next pick for the (b) shape was
-- `item_purchase_generic.lua:228` (`bot:GetLevel() >= 18`, classified TEETH by
-- the census in tests/test_level_gate_census.lua). It is retired here, and the
-- census reading is corrected: in Turbo that level gate is not what holds the
-- buyback reserve closed. The gate lives inside `GeneralPurchase()` (lines
-- 192-363), which is called from exactly one place --
--
--     if GetGameMode() == 23 then TurboModeGeneralPurchase() else GeneralPurchase() end
--
-- -- at line 1276. In a real Turbo game that dispatch takes the OTHER leg, so
-- the entire function never runs, and with it the only four writes and two
-- reads of `t3AlreadyDamaged` and the `cost = itemCost + GetBuybackCost() +
-- GetNetWorth()/40 - 300` reserve at line 272. `TurboModeGeneralPurchase()`
-- has no buyback reserve of its own. So Turbo has no buyback-money
-- reservation in item purchase at all, for a reason 1048 lines above the level
-- constant. Lowering or deleting `>= 18` would change nothing in the game we
-- optimise for.
--
-- That makes three TEETH candidates retired for three DISTINCT reasons:
--   285 -- dumper gap (mode is not in the .dem and cannot be bought);
--   535 -- corpus gap (buyable; the request is live, GH #84 §4);
--   228 -- not in Turbo at all (nothing to buy; the branch is the wrong one).
-- The remaining live candidate is `ability_item_usage_generic.lua:5751`.
--
-- AND IT IS ALSO A CORRECTION TO THIS GROUP'S OWN PUBLISHED READING. The
-- previous round (the fourteenth world assertion) re-ran three retnear bids as
-- a self-check and reported "armed -> laning 0.369" on
-- f_260820_043637_axe_ring_alone. That 0.369 is a rung of the ladder above;
-- with an honest game mode the same frame reads a different rung. The number
-- was correctly measured in the world it was measured in -- which is the whole
-- point of writing these down.
--
-- WHAT THIS FILE DOES NOT DO. It does not change bots/ and it does not change
-- the loader. The repair is one line in the mock (define the real GAMEMODE_*
-- numbers instead of letting the metatable invent them), and it would move
-- readings across the whole corpus at once -- the same class of decision as
-- GH #61 (lane front), GH #81 (enemy roles), GH #89 (active mode) and GH #91
-- (the ping stamp). It belongs to the director, and is asked as GH #93.
-- Unlike those four, though, there is nothing to model here: GAMEMODE_TURBO is
-- a documented engine constant with one correct value, and bots/ already says
-- what it is.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local LANING = 'bots/mode_laning_generic.lua'

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
--- needs. `honest` is the probe: it gives the world the game mode the engine
--- would have given it, by rawsetting the constant to its real value AND
--- answering GetGameMode() with it. Both are required -- moving only one of
--- them swaps which spelling is wrong instead of repairing the split.
local function world(path, honest, opts)
    opts = opts or {}
    -- Always clear the rawset first. GAMEMODE_TURBO is a plain global; a probe
    -- left installed would follow this file into the next one, and the next
    -- file would silently be the only one in the suite running an honest
    -- turbo world.
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    -- GH #61: the loader refuses to answer GetLaneFrontLocation; declare the
    -- pre-#61 default explicitly so the drivers below can run at all. Nothing
    -- asserted here depends on where the lane front is.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    -- GH #91 / the fourteenth world assertion: a fixture VM's first call to
    -- GameTime() is its own initialiser, so every bid behind the shared
    -- defendPings stamp reads the floor unless the test declares otherwise.
    -- Declared here, visibly, per this group's recommendation on #91.
    -- `opts.fresh_ping` withholds the declaration so the corpus can measure
    -- whether it is load-bearing for the bid under test rather than assume it.
    if not opts.fresh_ping then
        J.Utils['GameStates'] = J.Utils['GameStates'] or {}
        J.Utils['GameStates']['defendPings'] = { pingedTime = -1000 }
    end
    if honest then
        GAMEMODE_TURBO = 23 -- luacheck: ignore
        GetGameMode = function() return 23 end -- luacheck: ignore
    end
    return J
end

--- Undo the honest probe. GAMEMODE_TURBO is a plain global and the suite is
--- ONE Lua process running every test file in sequence, so a probe left
--- installed makes this file's successors the only ones in the repository
--- running an honest turbo world -- which is exactly the 21-fixture, 18-winner
--- shift measured below, applied silently to somebody else's assertions.
--- Restores the as-loaded state: the constant back to the mock's sentinel and
--- GetGameMode back to the closure the loader installs.
local function unprobe()
    GAMEMODE_TURBO = nil -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- One mode file's bid on this frame, or nil if it could not be driven.
local function bid(path, file, honest, opts)
    world(path, honest, opts)
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok = pcall(dofile, file)
    local out = nil
    if ok and type(GetDesire) == 'function' then
        local ok2, d = pcall(GetDesire)
        if ok2 and type(d) == 'number' then out = d end
    end
    GetDesire, Think = nil, nil -- luacheck: ignore
    unprobe()
    return out
end

-- ---------------------------------------------------------------------------
-- Premises. Asked of rf.load / the base mock DIRECTLY, never through world():
-- world() rawsets the constant itself, so asking it these questions would be
-- asking this file about its own stub (the M4 lesson from the fourteenth).
-- ---------------------------------------------------------------------------

tests['[premise] the mock invents a number for GAMEMODE_TURBO, and it is not 23'] = function()
    GAMEMODE_TURBO = nil -- luacheck: ignore
    rf.load('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    assert(type(GAMEMODE_TURBO) == 'number',
        'the mock answers a number for every unknown ALL_CAPS global')
    assert(GAMEMODE_TURBO > 1000,
        'and it is a sentinel from the auto-constant range; got ' .. tostring(GAMEMODE_TURBO))
    assert(GAMEMODE_TURBO ~= 23,
        'which is the whole problem: the engine constant is 23')
    GAMEMODE_TURBO = nil -- luacheck: ignore
end

tests['[premise] the loader declares the world Turbo BY NAME, so it inherits the sentinel'] = function()
    local src = read_file('tests/mock/replay_fixture.lua')
    assert(src:find('GetGameMode = function() return GAMEMODE_TURBO end', 1, true),
        'the loader no longer answers GetGameMode with the named constant')
    GAMEMODE_TURBO = nil -- luacheck: ignore
    rf.load('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    assert(GetGameMode() == GAMEMODE_TURBO, 'by name the fixture world is Turbo')
    assert(GetGameMode() ~= 23, 'by number it is not')
    GAMEMODE_TURBO = nil -- luacheck: ignore
end

tests['[premise] the base mock without a fixture answers 1, not 23 and not the sentinel'] = function()
    -- Stated so that a future loader change that stops overriding GetGameMode
    -- turns this file red rather than quietly making every unit test a
    -- GAMEMODE_AP game.
    local src = read_file('tests/mock/bot_api.lua')
    assert(src:find('G.GetGameMode = function() return 1 end', 1, true),
        'the base mock default moved')
end

tests['[premise] the shipped self-heal exists, and the mock is what disables it'] = function()
    -- bots/ already knows the right answer. `GAMEMODE_TURBO == nil` is the
    -- condition it uses to decide whether to supply it, and the mock's
    -- auto-constant metatable makes that condition permanently false.
    local n = 0
    for _, f in ipairs({ 'bots/hero_selection.lua', 'bots/ability_item_usage_generic.lua' }) do
        local src = read_file(f)
        assert(src:find('if GAMEMODE_TURBO == nil then GAMEMODE_TURBO = 23 end', 1, true),
            'the self-heal moved in ' .. f)
        n = n + 1
    end
    assert(n == 2, 'expected exactly two self-healing files; got ' .. n)
    -- And it really is unreachable here: the metatable answers before nil can.
    GAMEMODE_TURBO = nil -- luacheck: ignore
    rf.load('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    assert(GAMEMODE_TURBO ~= nil,
        'the constant is never nil under the mock, so the self-heal never fires')
    GAMEMODE_TURBO = nil -- luacheck: ignore
end

-- ---------------------------------------------------------------------------
-- The shipped sites, pinned. Nine comparisons against the literal, in SEVEN
-- files; the named spelling in the places that carry the helper family.
--
-- SEVEN, corrected 2026-08-21T20:2xZ. The first version of this file, and
-- GH #93's body with it, said six in prose while the table below listed nine
-- rows across seven distinct paths -- item_purchase_generic carries three of
-- the nine on its own, which is what makes the list read shorter than it is.
-- The count was never asserted, so nothing could catch it. It is asserted now.
-- ---------------------------------------------------------------------------

local LITERAL_SITES = {
    { 'bots/item_purchase_generic.lua',
      'if ( GetGameMode() ~= 23 and botLevel > 6 and currentTime > bot.fullInvCheck + 1.0' },
    { 'bots/item_purchase_generic.lua',
      'or ( GetGameMode() == 23 and botLevel > 9 and currentTime > bot.fullInvCheck + 1.0' },
    { 'bots/item_purchase_generic.lua', 'if GetGameMode() == 23' },
    { 'bots/mode_laning_generic.lua', 'if GetGameMode() == 23 then currentTime = currentTime * 1.65 end' },
    { 'bots/mode_team_roam_generic.lua', 'if GetGameMode() == 23 then return nil end' },
    { 'bots/FunLib/aba_defend.lua',
      'local adjustedTime = gameMode == 23 and currentTime * 1.65 or currentTime' },
    { 'bots/FunLib/global_cache.lua',
      'local adjustedTime = gameMode == 23 and currentTime * 2 or currentTime' },
    { 'bots/FunLib/override_generic/mode_laning_generic.lua',
      'if GetGameMode() == 23 then currentTime = currentTime * 1.65 end' },
    { 'bots/FunLib/aba_push.lua',
      'local adjustedTime = gameMode == 23 and currentTime * 2 or currentTime' },
}

tests['[reverse] nine shipped comparisons spell the mode as the literal 23'] = function()
    for _, site in ipairs(LITERAL_SITES) do
        local src = read_file(site[1])
        assert(src:find(site[2], 1, true),
            'this literal-23 site moved in ' .. site[1] .. ': ' .. site[2])
    end
    assert(#LITERAL_SITES == 9, 'expected nine literal sites; got ' .. #LITERAL_SITES)
    -- The file count, asserted rather than counted by eye in prose -- see the
    -- correction note above the table.
    local seen, nfiles = {}, 0
    for _, site in ipairs(LITERAL_SITES) do
        if not seen[site[1]] then seen[site[1]] = true nfiles = nfiles + 1 end
    end
    assert(nfiles == 7, 'the nine rows live in seven distinct files; got ' .. nfiles)
end

tests['[reverse] and the helper family spells it by name'] = function()
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    assert(jmz:find('bModeTurboCache = GetGameMode() == GAMEMODE_TURBO', 1, true),
        'J.IsModeTurbo no longer compares against the named constant')
    local aiug = read_file('bots/ability_item_usage_generic.lua')
    assert(aiug:find('local nRate = GetGameMode() == GAMEMODE_TURBO and 2.0 or 1.0', 1, true),
        'the named site at ability_item_usage_generic:398 moved')
    assert(aiug:find('if GetGameMode() == GAMEMODE_TURBO then return false end', 1, true),
        'the named site at ability_item_usage_generic:815 moved')
end

-- ---------------------------------------------------------------------------
-- The world assertion, over the corpus.
-- ---------------------------------------------------------------------------

local corpus_cache
local function corpus()
    if corpus_cache then return corpus_cache end
    local s = { fixtures = 0, by_name = 0, by_number = 0, helper = 0, latest = 0,
                laning_moved = {}, laning_down = 0, laning_up = 0,
                past_plain = 0, past_honest = 0,
                probe_both = 0, probe_helper = 0, ping_changed = 0 }
    for _, path in ipairs(fixture_files()) do
        s.fixtures = s.fixtures + 1
        local J = world(path, false)
        if GetGameMode() == GAMEMODE_TURBO then s.by_name = s.by_name + 1 end
        if GetGameMode() == 23 then s.by_number = s.by_number + 1 end
        if J.IsModeTurbo() then s.helper = s.helper + 1 end
        if DotaTime() > s.latest then s.latest = DotaTime() end
        -- FunLib/aba_push.lua:172-172, reproduced rather than restated: the
        -- threshold comes from the named spelling, the operand from the
        -- literal one. Both readings computed on the same frame.
        local t = DotaTime()
        local nCloseByTime = J.IsModeTurbo() and 25 * 60 or 40 * 60
        if ((GetGameMode() == 23) and t * 2 or t) > nCloseByTime then
            s.past_plain = s.past_plain + 1
        end
        if t * 2 > nCloseByTime then s.past_honest = s.past_honest + 1 end

        -- Probe integrity: the honest world must be honest on BOTH spellings,
        -- and the named helper must still say turbo. Moving only GetGameMode
        -- would not repair the split, it would swap which side of it is wrong.
        local J2 = world(path, true)
        if GetGameMode() == 23 and GetGameMode() == GAMEMODE_TURBO then
            s.probe_both = s.probe_both + 1
        end
        if J2.IsModeTurbo() then s.probe_helper = s.probe_helper + 1 end
        unprobe()

        local a = bid(path, LANING, false)
        local b = bid(path, LANING, true)
        -- Is the declared ping-stamp assumption load-bearing for THIS bid?
        -- Measured, not assumed (GH #91 / the fourteenth world assertion).
        if bid(path, LANING, false, { fresh_ping = true }) ~= a then
            s.ping_changed = s.ping_changed + 1
        end
        if a ~= b then
            s.laning_moved[#s.laning_moved + 1] = { path = path, plain = a, honest = b }
            if a ~= nil and b ~= nil then
                if b < a then s.laning_down = s.laning_down + 1 else s.laning_up = s.laning_up + 1 end
            end
        end
    end
    corpus_cache = s
    return s
end

tests['[WORLD ASSERTION] 100/100 Turbo by name, 0/100 Turbo by number'] = function()
    local s = corpus()
    assert(s.fixtures == 100, 'expected 100 fixtures; got ' .. s.fixtures)
    assert(s.by_name == 100,
        'every fixture is Turbo when the constant is spelled by name; got ' .. s.by_name)
    assert(s.by_number == 0,
        'and none of them is Turbo when it is spelled 23; got ' .. s.by_number)
    -- Not "most" and not "usually": the split is total, and it is total
    -- because it has nothing to do with the frame -- it is a property of the
    -- mock's constant table, which is the same in every VM.
    assert(s.helper == 100,
        'J.IsModeTurbo() -- the named helper, 94 call sites -- reads TRUE on all of them; got '
        .. s.helper)
end

tests['[premise] the probe does not follow this file into the next one'] = function()
    -- The suite is ONE process (tests/run_tests.lua loads every test_*.lua in
    -- sequence) and GAMEMODE_TURBO is a plain global, so a probe left set
    -- would hand every LATER test file the honest world -- silently applying
    -- the 21-fixture / 18-winner shift measured in this file to assertions
    -- written against the other one. That is not a hypothetical: the first
    -- full-suite run of this file did exactly that and turned another file
    -- red. Every honest reading is now undone by unprobe(), and this asserts
    -- the state a successor actually inherits.
    corpus() -- the heaviest user of the probe; run it, then look at the world
    assert(GAMEMODE_TURBO ~= 23,
        'the rawset probe is still installed after the corpus ran; got '
        .. tostring(GAMEMODE_TURBO))
    assert(GetGameMode() == GAMEMODE_TURBO,
        'and GetGameMode is back to the closure the loader installs')
    assert(GetGameMode() ~= 23, 'i.e. the successor inherits the as-loaded world, not the probe')
end

tests['[premise] the honest probe repairs the split rather than swapping sides'] = function()
    local s = corpus()
    assert(s.probe_both == 100,
        'under the probe both spellings agree on all 100 fixtures; got ' .. s.probe_both)
    assert(s.probe_helper == 100,
        'and J.IsModeTurbo() still reads TRUE -- a probe that only moved GetGameMode() '
        .. 'would turn the named helper OFF and measure a different mistake; got '
        .. s.probe_helper)
end

tests['[premise] the declared ping-stamp assumption is inert for the laning bid'] = function()
    local s = corpus()
    -- The assumption is declared in world() because a bid-level test must
    -- declare it (GH #91). Whether it MATTERS for this particular bid is a
    -- separate question and is measured here rather than assumed: laning does
    -- not read the shared defendPings key, so withholding the declaration
    -- changes nothing on any of the 94 frames. Stating it keeps a future
    -- reader from concluding the laning numbers below depend on it.
    assert(s.ping_changed == 0,
        'withholding the declaration must not move the laning bid; got ' .. s.ping_changed)
    -- A null result is only worth reading if the thing that produced it has
    -- teeth. Same corpus, same withholding switch, a bid that DOES sit behind
    -- the shared key: farm. If this stops moving, the switch above has gone
    -- inert and the null result above stops meaning anything.
    local farm_changed = 0
    for _, path in ipairs(fixture_files()) do
        if bid(path, 'bots/mode_farm_generic.lua', false)
            ~= bid(path, 'bots/mode_farm_generic.lua', false, { fresh_ping = true }) then
            farm_changed = farm_changed + 1
        end
    end
    assert(farm_changed > 0,
        'the withholding switch must move the farm bid on at least one frame, or it is not '
        .. 'measuring anything; got ' .. farm_changed)
end

tests['[WORLD ASSERTION] the laning bid moves on 23 of 100 frames, and always downward'] = function()
    local s = corpus()
    assert(#s.laning_moved == 23,
        'expected the laning bid to move on 23 of 100 fixtures; got ' .. #s.laning_moved)
    assert(s.laning_up == 0,
        'no fixture bids laning HIGHER with an honest game mode; got ' .. s.laning_up)
    assert(s.laning_down == 23,
        'all 23 move down; got ' .. s.laning_down)
    -- The direction is not a coincidence and it is worth stating as a
    -- mechanism, not a statistic: the ladder in
    -- FunLib/override_generic/mode_laning_generic.lua is a sequence of
    -- `currentTime <= X` rungs, and the fixture's clock is missing the
    -- turbo * 1.65 dilation, so every fixture lands on an EARLIER rung than
    -- the same frame would in the game. Earlier rungs bid higher.
    local seen = {}
    for _, m in ipairs(s.laning_moved) do
        seen[tostring(m.plain) .. '->' .. tostring(m.honest)] = true
    end
    assert(seen['0.446->0.369'] and seen['0.369->0.2'],
        'the two observed transitions are one rung each; got a different set')
end

tests['[WORLD ASSERTION] every rung the corpus lands on is a rung of the shipped ladder'] = function()
    -- Guards against reading the numbers above as arbitrary: 0.446 and 0.369
    -- are written in the shipped file, one rung apart, and the gate between
    -- them is the dilated clock. THE LIVE COPY IS mode_laning_generic.lua --
    -- dilation at 156, ladder at 242-244, both inside the same GetDesire().
    local ml = read_file('bots/mode_laning_generic.lua')
    assert(ml:find('if GetGameMode() == 23 then currentTime = currentTime * 1.65 end', 1, true),
        'the live dilation moved')
    assert(ml:find('if currentTime <= 9 * 60 and botLV <= 7 then return 0.446 end', 1, true),
        'the 0.446 rung moved')
    assert(ml:find('if currentTime <= 12 * 60 and botLV <= 11 then return 0.369 end', 1, true),
        'the 0.369 rung moved')
    -- The literal 1.65 has to have its own pin: the measurement above merely
    -- flips the mode and reads what comes out, so a changed multiplier would
    -- move the numbers without moving any assertion. (The M7 lesson from the
    -- fourteenth: when the measurement restates a constant, pin the constant.)
    assert(ml:find('* 1.65', 1, true), 'the dilation factor moved')
    -- The second copy, and the one line that says it is not the live one. This
    -- distinction is asserted rather than commented because this file got it
    -- backwards on the first draft: mutating the override changed nothing the
    -- corpus could see, and mutating the live copy moved four assertions.
    local ov = read_file('bots/FunLib/override_generic/mode_laning_generic.lua')
    assert(ov:find('if GetGameMode() == 23 then currentTime = currentTime * 1.65 end', 1, true),
        'the second copy of the dilation moved')
    assert(ov:find('if currentTime <= 9 * 60 and botLV <= 7 then return 0.446 end', 1, true),
        'the second copy of the ladder moved')
    assert(ml:find('if Utils.BuggyHeroesDueToValveTooLazy[botName] then local_mode_laning_generic = dofile(', 1, true),
        'the override is still loaded only for the buggy-hero list -- if that condition '
        .. 'widens, the corpus starts riding the other copy')
end

tests['[WORLD ASSERTION] the split runs through the middle of one expression'] = function()
    -- FunLib/aba_push.lua:172-172. The threshold is chosen by the NAMED
    -- spelling and the operand is built by the LITERAL one, eleven lines and
    -- one function apart in the same file. In the engine they agree; here they
    -- cannot.
    local src = read_file('bots/FunLib/aba_push.lua')
    assert(src:find('local nCloseByTime = jmz.IsModeTurbo() and 25 * 60 or 40 * 60', 1, true),
        'the threshold moved')
    assert(src:find('local bPastCloseByTime = gameState.currentTime > nCloseByTime', 1, true),
        'the comparison moved')
    assert(src:find('local adjustedTime = gameMode == 23 and currentTime * 2 or currentTime', 1, true),
        'the operand moved')
    assert(src:find('currentTime = adjustedTime,', 1, true),
        'the operand is still what lands in the cache field')
    -- The same table literal builds four SIBLING fields the named way.
    for _, sib in ipairs({ 'isEarlyGame = jmz.IsEarlyGame()', 'isMidGame = jmz.IsMidGame()',
                           'isLateGame = jmz.IsLateGame()', 'isLaningPhase = jmz.IsInLaningPhase()' }) do
        assert(src:find(sib, 1, true), 'sibling field moved: ' .. sib)
    end
end

tests['[WORLD ASSERTION] but that clause does not move on this corpus -- honest boundary'] = function()
    local s = corpus()
    -- 0/94 either way, and the reason is the corpus, not the mechanism: the
    -- honest reading needs DotaTime > 750s (25*60 halved by the *2 dilation)
    -- and the latest frame anyone has is 690.5s, because batch games
    -- self-terminate on economy_10min_cap at ~640s. Real Turbo games average
    -- ~20 minutes, so in the game this clause opens for the last third of the
    -- match. This is the SAME honest boundary the level-gate census recorded
    -- for J.IsLateGame(): a property of turbo AND a property of the harness,
    -- and it must be quoted with the reading.
    assert(s.past_plain == 0, 'as loaded the push cap clause never opens; got ' .. s.past_plain)
    assert(s.past_honest == 0, 'and with an honest mode it still does not, on THIS corpus; got '
        .. s.past_honest)
    assert(s.latest > 690 and s.latest < 691,
        'the latest frame in the corpus is 690.5s; got ' .. tostring(s.latest))
    assert(s.latest * 2 < 25 * 60,
        'which is why: even doubled it is short of the 25-minute threshold')
    -- corpus() restates the shipped 25 * 60 rather than reading it, so the
    -- measurement above cannot notice the threshold moving. Pin it here, next
    -- to the claim that depends on it (M7 lesson, fourteenth world assertion).
    local push = read_file('bots/FunLib/aba_push.lua')
    assert(push:find('jmz.IsModeTurbo() and 25 * 60 or 40 * 60', 1, true),
        'the threshold this boundary is computed against moved')
end

-- ---------------------------------------------------------------------------
-- The auction. One moved bid is not a finding; a moved WINNER is.
-- ---------------------------------------------------------------------------

local MODE_FILES
local function mode_files()
    if MODE_FILES then return MODE_FILES end
    local p = assert(io.popen('ls bots/mode_*.lua'))
    local t = {}
    for l in p:lines() do t[#t + 1] = l end
    p:close()
    MODE_FILES = t
    return t
end

--- Re-run the whole mode auction on one frame and return (winner, value).
--- The world is rebuilt per mode file, as every bid-level test in this repo
--- does, because driving a mode mutates globals.
local function auction(path, honest)
    local bn, bv = 'NOBODY', -math.huge
    for _, f in ipairs(mode_files()) do
        local d = bid(path, f, honest)
        if d ~= nil and d > bv then bn, bv = f, d end
    end
    return (bn:gsub('bots/mode_', ''):gsub('_generic%.lua', '')), bv
end

tests['[AUCTION] a laning frame becomes a defending frame'] = function()
    local path = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
    local pw, pv = auction(path, false)
    local hw, hv = auction(path, true)
    assert(pw == 'laning', 'as loaded, laning wins this frame; got ' .. pw)
    assert(pv > 0.3689 and pv < 0.3691, 'at 0.369; got ' .. tostring(pv))
    assert(hw == 'defend_tower_bot',
        'with an honest game mode the winner is a different MODE; got ' .. hw)
    assert(hv > 0.2999 and hv < 0.3001, 'at 0.300; got ' .. tostring(hv))
end

tests['[AUCTION] a laning frame becomes a retreating frame'] = function()
    local path = 'tests/fixtures/f_260820_043524_wd_defend_alone.lua'
    local pw, pv = auction(path, false)
    local hw, hv = auction(path, true)
    assert(pw == 'laning' and pv > 0.3689 and pv < 0.3691,
        'as loaded laning wins at 0.369; got ' .. pw .. '/' .. tostring(pv))
    assert(hw == 'retreat', 'with an honest game mode retreat wins; got ' .. hw)
    assert(hv > 0.319 and hv < 0.321, 'at 0.320; got ' .. tostring(hv))
end

tests['[AUCTION] and a frame where only the number moves, not the mode'] = function()
    -- The control. Eight of the eighteen moved winners are this shape: laning
    -- still wins, one rung lower. Included so the finding above is not read as
    -- "the winner always flips" -- it flips on 10 of 94, and moves without
    -- flipping on 8 more.
    local path = 'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua'
    local pw, pv = auction(path, false)
    local hw, hv = auction(path, true)
    assert(pw == 'laning' and hw == 'laning',
        'laning wins either way on this frame; got ' .. pw .. '/' .. hw)
    assert(pv > 0.4459 and pv < 0.4461, 'as loaded at 0.446; got ' .. tostring(pv))
    assert(hv > 0.3689 and hv < 0.3691, 'honestly at 0.369; got ' .. tostring(hv))
end

tests['[recorded] the corpus-wide auction figures, and how they were taken'] = function()
    -- MEASURED OUT OF BAND, not re-measured on every suite run: the full
    -- auction is 94 frames x 21 mode files x 2 readings x one world rebuild
    -- per cell, which is roughly three quarters of an hour. The three frames
    -- above are the in-suite ratchet; these are the numbers they are drawn
    -- from, recorded here so the report and the test agree and so a future
    -- reader knows the method rather than trusting the figure:
    --
    --   moved bid cells        23 / 2100   (all of them the laning bid)
    --   moved auction winners  19 / 100
    --   of which the MODE changed  11      (8 -> defend_tower_bot, 3 -> retreat)
    --   of which only the value moved 8    (laning 0.446 -> 0.369 or 0.369 -> 0.200)
    --
    -- THE CORPUS GREW WHILE THIS ROUND WAS RUNNING, and the ratchet caught it:
    -- the numerators were taken over 94 fixtures and three assertions here
    -- turned red on rebase when two lion_drain fixtures landed. Rather than
    -- move the denominator and hope, the whole auction was re-run on the two
    -- new frames both ways: f_260820_162821_lion_drain_lethal (retreat 0.750
    -- either way) and f_260820_182906_lion_drain_survived (defend_tower_bot
    -- 0.300 either way), ZERO moved cells each. So every numerator above is
    -- unchanged and only the denominator moved, 94 -> 96. That is a
    -- measurement, not an assumption, and it is exactly what these census
    -- assertions exist to force.
    --
    -- The seven defend flips and three retreat flips include three fixtures
    -- this group pinned itself for the blinkflee family
    -- (axe_blink_init_573, axe_blink_flee_555, es_blink_flee_615). Those tests
    -- assert helper decisions, not auctions, so they are not invalidated --
    -- but the mode context they were described in moves, and whoever next
    -- touches them should re-read this.
    --
    -- AND IT CAUGHT THE NEXT ONE, 2026-08-22T00:30Z, with a different answer:
    -- the hero stream added the two GH #63 cask frames, and this time the
    -- auction was NOT a no-op. Re-run both ways on each:
    --   f_260820_043039_cm_cask_close  retreat 0.750 either way   -> 0 moved cells
    --   f_260820_042009_cm_cask_far    laning 0.369 -> defend_tower_bot 0.300
    -- So one numerator moves with the denominator: moved bid cells 21 -> 22,
    -- moved winners 18 -> 19, MODE changed 10 -> 11 (defend_tower_bot 7 -> 8).
    -- "Only the value moved" stays at 8. The lesson the previous entry drew --
    -- re-run the auction rather than move the denominator and hope -- is the
    -- reason this is a measurement and not a guess in the wrong direction.
    --
    -- AND AGAIN, 2026-08-22T09:5xZ, strategy stream, two owner-P2 TP-home
    -- frames. Auction re-run both ways on each rather than moving the
    -- denominator and hoping, exactly as the two entries above require:
    --   f_260822_063722_lina_tp_home     laning 0.369 either way -> 0 moved cells
    --   f_260822_063559_slardar_tp_forward  retreat 0.860 either way, but ONE
    --       moved cell: its laning bid reads 0.369 as loaded and 0.200 honestly.
    --       The cell moves and the winner does not -- retreat outbids both.
    -- So: moved bid cells 22 -> 23 (denominator 2058 -> 2100), moved winners
    -- unchanged at 19, MODE changed unchanged at 11. This is the first entry
    -- in this record where a numerator and the denominator moved by different
    -- amounts, which is the whole reason the cells are counted separately from
    -- the winners.
    --
    -- Pinned so the claim cannot drift away from the corpus it describes:
    local n = 0
    for _, _ in ipairs(fixture_files()) do n = n + 1 end
    assert(n == 100, 'the figures above are for a 100-fixture corpus; got ' .. n)
    -- 21 -> 22 on 2026-08-23: bots/mode_item_generic.lua landed (itemtrip, GH
    -- #120). The figures recorded above were taken with 21 and STILL STAND,
    -- which is a claim about that file rather than an assumption: unarmed it
    -- defines no GetDesire at all, so it contributes no bid cell and cannot win
    -- an auction. If it ever bids in an unarmed world, its own load-time gate
    -- is broken and these figures need re-taking -- which is exactly what
    -- tests/test_itemtrip_wasteful_trip.lua asserts on a real frame.
    assert(#mode_files() == 22, 'and 22 mode files; got ' .. #mode_files())
    for _, f in ipairs({ 'tests/fixtures/f_260820_042612_axe_blink_init_573.lua',
                         'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua',
                         'tests/fixtures/f_260820_162859_es_blink_flee_615.lua' }) do
        local fh = io.open(f, 'r')
        assert(fh, 'a fixture named in this record is gone: ' .. f)
        fh:close()
    end
    -- The four frames that grew the denominator, pinned by name so that the
    -- "re-measured, not assumed" claim above stays attached to the frames it
    -- was checked on.
    for _, f in ipairs({ 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua',
                         'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
                         'tests/fixtures/f_260820_043039_cm_cask_close.lua',
                         'tests/fixtures/f_260820_042009_cm_cask_far.lua' }) do
        local fh = io.open(f, 'r')
        assert(fh, 'a frame this round re-measured for is gone: ' .. f)
        fh:close()
    end
end

tests['[recorded] the split changes WHICH MODE most often wins on this corpus'] = function()
    -- Added 2026-08-21T20:2xZ, from an independent re-derivation of the whole
    -- census (same chunked driver, same 4032 bids, every numerator above
    -- reproduced row for row). This is the one reading the per-frame figures
    -- above hide, and it is the sharpest way to state the cost:
    --
    --   as loaded   laning 37, retreat 30, defend_tower_bot 17, push 9,
    --               assemble 6, farm 1
    --   honest      retreat 33, laning 26, defend_tower_bot 25, push 9,
    --               assemble 6, farm 1
    --
    -- (35/28/17 and 31/25/24 over the 96-fixture corpus, until the two GH #63
    -- cask frames landed on 2026-08-22: the close one wins retreat either way,
    -- the far one is a laning->defend_tower_bot flip. Both cells re-run, see
    -- the record above.)
    --
    -- The fixture world does not merely over-bid laning by a rung. It reports
    -- LANING AS THE SINGLE MOST COMMON THING our bots are doing, and honestly
    -- it is the second, behind retreat. Every bid-level conclusion this
    -- repository has published is tilted toward "he is laning" by that much --
    -- which is a different and larger claim than "18 winners are wrong",
    -- because it applies to the shape of every aggregate, not to 18 frames.
    --
    -- Taken out of band for the same reason as the figures above (the full
    -- auction is roughly three quarters of an hour). Six modes win at least
    -- one frame under each reading; the three that move are exactly the three
    -- the per-frame assertions drive. push/assemble/farm are unchanged, which
    -- is the control: the shift is not a global re-scaling of every bid.
    --
    -- (37/30/17 and 33/26/25 over the 100-fixture corpus from
    -- 2026-08-22T09:5xZ: the strategy stream's two owner-P2 TP-home frames win
    -- laning (lina) and retreat (slardar) under BOTH readings, so each adds one
    -- to the same mode on both sides and every transition below is untouched.)
    --
    -- Pinned to the corpus it describes, so it cannot drift silently:
    local n = 0
    for _, _ in ipairs(fixture_files()) do n = n + 1 end
    assert(n == 100, 'these distributions are for a 100-fixture corpus; got ' .. n)
    -- Both readings must still account for every frame, whatever the split.
    assert(37 + 30 + 17 + 9 + 6 + 1 == n, 'the as-loaded distribution sums to the corpus')
    assert(33 + 26 + 25 + 9 + 6 + 1 == n, 'and so does the honest one')
    -- And the transitions the distributions are made of are the ones the three
    -- [AUCTION] tests above drive: laning loses 11, defend gains 8, retreat
    -- gains 3, and nothing else moves.
    assert(37 - 26 == 11, 'laning loses eleven frames')
    assert(25 - 17 == 8, 'defend_tower_bot gains eight')
    assert(33 - 30 == 3, 'retreat gains three')
end

-- ---------------------------------------------------------------------------
-- Delivery to GH #84 §5: item_purchase_generic:228 is retired, and the census
-- reading of it is corrected.
-- ---------------------------------------------------------------------------

tests['[GH84] the level-18 gate lives in the function Turbo never calls'] = function()
    local src = read_file('bots/item_purchase_generic.lua')
    -- The dispatch, verbatim -- indentation included, because the whole claim
    -- is that these two calls are the two legs of ONE `if` on the game mode.
    assert(src:find('\t\t\tif GetGameMode() == 23\n\t\t\tthen\n\t\t\t\tTurboModeGeneralPurchase()\n'
        .. '\t\t\telse\n\t\t\t\tGeneralPurchase()\n\t\t\tend', 1, true),
        'the dispatch moved')
    local _, defs = src:gsub('local function GeneralPurchase%(%)', '')
    assert(defs == 1, 'GeneralPurchase is defined exactly once; got ' .. defs)
    local _, calls = src:gsub('\n%s*GeneralPurchase%(%)', '')
    assert(calls == 1, 'and called from exactly one place; got ' .. calls)
    -- The gate under test, and the reserve it is supposed to be holding shut.
    assert(src:find('if bot:GetLevel() >= 18\n\t\tand t3AlreadyDamaged == false', 1, true),
        'the level-18 gate moved -- re-read the census entry for it')
    assert(src:find('cost = itemCost + bot:GetBuybackCost() + bot:GetNetWorth() / 40 - 300', 1, true),
        'the buyback reserve moved')
end

tests['[GH84] every write and read of t3AlreadyDamaged is inside that function'] = function()
    local src = read_file('bots/item_purchase_generic.lua')
    -- Line-addressed rather than offset-addressed so the failure message says
    -- something useful when the file shifts.
    local lines = {}
    for l in (src .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = l end
    local first, last
    for i, l in ipairs(lines) do
        if l == 'local function GeneralPurchase()' then first = i end
        if first and not last and i > first and l == 'end' then last = i end
    end
    assert(first and last, 'could not locate GeneralPurchase')
    local inside, outside = 0, 0
    for i, l in ipairs(lines) do
        if l:find('t3AlreadyDamaged', 1, true) then
            if i > first and i < last then inside = inside + 1
            elseif l:find('local t3AlreadyDamaged', 1, true) then -- the file-scope declaration
            else outside = outside + 1 end
        end
    end
    assert(inside == 6, 'four writes and two reads, all inside; got ' .. inside)
    assert(outside == 0,
        'nothing outside the function touches it -- so Turbo never sets it and never reads it; got '
        .. outside)
end

tests['[GH84] and the Turbo purchase path has no buyback reserve of its own'] = function()
    local src = read_file('bots/item_purchase_generic.lua')
    local lines = {}
    for l in (src .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = l end
    local first, last
    for i, l in ipairs(lines) do
        if l == 'local function TurboModeGeneralPurchase()' then first = i end
        if first and not last and i > first and l == 'end' then last = i end
    end
    assert(first and last, 'could not locate TurboModeGeneralPurchase')
    for i = first, last do
        assert(not lines[i]:find('GetBuybackCost', 1, true),
            'the Turbo path grew a buyback reserve at line ' .. i .. ' -- re-read this delivery')
        assert(not lines[i]:find('t3AlreadyDamaged', 1, true),
            'the Turbo path grew a t3 check at line ' .. i)
    end
    -- Stated as the conclusion, not left as an inference: in the game we tune
    -- for, nothing in item purchase reserves buyback money.
    assert(true)
end

tests['[GH84] on 94/94 frames the fixture takes the leg the game does not'] = function()
    local s = corpus()
    assert(s.by_number == 0,
        'the dispatch condition is false on every fixture, so every fixture runs GeneralPurchase '
        .. '-- the non-Turbo path -- while every real Turbo game runs the other one; got '
        .. s.by_number)
    -- Which means the census could not have caught this from a frame either:
    -- the branch IS reachable here, and only here.
end

-- ---------------------------------------------------------------------------
-- Accounting. Recorded, not acted on.
-- ---------------------------------------------------------------------------

tests['[recorded] two of the three turbo clock dilations are written and never read'] = function()
    -- Three shipped sites compute an `adjustedTime` and store it as a cache
    -- field called `currentTime`. Repo-wide there are exactly TWO readers of
    -- that field and BOTH belong to aba_push (the push cap clause at :172 and
    -- the human-players clause at :240). The dilations in aba_defend (* 1.65)
    -- and global_cache (* 2) therefore cost a multiply and change nothing --
    -- the same three-writes-zero-reads shape as the towerreach calibration
    -- flag (GH #67). No gate, no change: this is a note for whoever next tries
    -- to make a defend or global-cache decision turbo-aware and assumes the
    -- clock in the cache is already dilated.
    local n = 0
    for _, f in ipairs({ 'bots/FunLib/aba_defend.lua', 'bots/FunLib/global_cache.lua',
                         'bots/FunLib/aba_push.lua' }) do
        local src = read_file(f)
        assert(src:find('local adjustedTime = gameMode == 23 and currentTime', 1, true),
            'a dilation site moved in ' .. f)
        assert(src:find('currentTime = adjustedTime,', 1, true),
            'the dilation no longer lands in the cache in ' .. f)
        n = n + 1
    end
    assert(n == 3, 'expected three dilation sites; got ' .. n)
    -- And exactly two readers, both in aba_push.
    local p = assert(io.popen('grep -rn "\\.currentTime" bots/ game/ --include=*.lua'))
    local readers, foreign = 0, 0
    for l in p:lines() do
        readers = readers + 1
        if not l:find('bots/FunLib/aba_push.lua', 1, true) then foreign = foreign + 1 end
    end
    p:close()
    assert(readers == 2,
        'exactly two shipped lines read a .currentTime cache field; got ' .. readers)
    assert(foreign == 0,
        'and both are in aba_push -- neither aba_defend nor global_cache reads its own dilation; got '
        .. foreign)
    local push = read_file('bots/FunLib/aba_push.lua')
    assert(push:find('local bPastCloseByTime = gameState.currentTime > nCloseByTime', 1, true),
        'the push-cap reader moved')
    assert(push:find('if nH > 0 and currentTime <= StartToPushTime then', 1, true),
        'the second reader moved -- it is behind a human-players-on-the-enemy-team clause, '
        .. 'which is 0 in every bot-vs-bot batch game, so it is inert on this corpus')
end

tests['[recorded] what a census reading owes the call chain above it'] = function()
    -- The census (tests/test_level_gate_census.lua) read item_purchase:228 as
    -- TEETH from the SOURCE, correctly, within the block it lives in: the
    -- level gate really is the only writer of t3AlreadyDamaged and the reserve
    -- at :272 really is dead while it stays shut. What it did not do was look
    -- one level UP the call chain, where the whole function is switched off in
    -- the mode we tune for. This is the same shape as the previous round's
    -- re-read of the REDUNDANT call on mode_farm_generic:370 -- a source-only
    -- reading that was fine as far as it went.
    --
    -- THE RULE, so the next census does not repeat it: a claim that some
    -- constant is "the only thing holding this branch closed" has to be
    -- checked on the branch's CALL CHAIN, not only inside the block it sits
    -- in. Pinned here rather than left in a report, with the two facts that
    -- would have caught it: one caller, and a condition on the caller.
    local src = read_file('bots/item_purchase_generic.lua')
    local _, calls = src:gsub('\n%s*GeneralPurchase%(%)', '')
    assert(calls == 1,
        'the "only one caller" half of the rule; got ' .. calls .. ' callers')
    assert(src:find('if GetGameMode() == 23\n\t\t\tthen', 1, true),
        'the "and the caller is conditional" half of the rule')
    -- The census entry this corrects is still on disk and still says TEETH;
    -- the correction lives in GH #84 and in the header above. Pinned on the
    -- ROW, not on the filename, so that re-reading the verdict there turns
    -- this red and the two are forced to meet. (First draft pinned the
    -- filename, which appears twice in that file and could not fail --
    -- mutation M15.)
    local census = read_file('tests/test_level_gate_census.lua')
    assert(census:find("{ file = 'bots/item_purchase_generic.lua', line = 228, op = '>=', n = 18", 1, true),
        'the census row for this site moved')
    local at = census:find("line = 228, op = '>=', n = 18", 1, true)
    -- Bounded to THIS row. An unbounded find from `at` matches a TEETH verdict
    -- in some later row and can never fail -- mutation M15b, the third empty
    -- assertion of the "searched a whole file for a string that is in it
    -- twenty times" shape this group has now catalogued.
    local nxt = census:find('{ file = ', at, true) or #census
    local row = census:sub(at, nxt)
    assert(row:find("verdict = 'TEETH'", 1, true),
        'the census still reads THIS site TEETH -- if that changes, re-read this record')
end

tests['[recorded] the ARDM comparisons are on the right side of the split by luck'] = function()
    -- Seven shipped sites compare against GAMEMODE_ARDM, which the mock also
    -- invents. They happen to read correctly (GetGameMode() answers the TURBO
    -- sentinel, which is a different sentinel), so nothing in the ARDM family
    -- is wrong here. Recorded so that a repair which defines GAMEMODE_TURBO as
    -- 23 but leaves GAMEMODE_ARDM inventing itself is understood to be half a
    -- repair: after it, GetGameMode() would answer 23 and every `==
    -- GAMEMODE_ARDM` would still be comparing 23 against a sentinel.
    GAMEMODE_TURBO = nil -- luacheck: ignore
    rf.load('tests/fixtures/f_260820_043637_axe_ring_alone.lua')
    assert(GAMEMODE_ARDM ~= nil and GAMEMODE_ARDM ~= 20,
        'the mock invents GAMEMODE_ARDM too, and not as 20')
    assert(GetGameMode() ~= GAMEMODE_ARDM,
        'so the ARDM branches read false -- correct, for the wrong reason')
    local aiug = read_file('bots/ability_item_usage_generic.lua')
    assert(aiug:find('if GAMEMODE_ARDM == nil then GAMEMODE_ARDM = 20 end', 1, true),
        'the ARDM self-heal moved')
    GAMEMODE_TURBO = nil -- luacheck: ignore
end

tests['[recorded] this revises a number this group published one round ago'] = function()
    -- The fourteenth world assertion re-ran three retnear bids as a
    -- self-check and reported laning 0.369 on this frame with retnear armed.
    -- That reading stands for the world it was taken in; with an honest game
    -- mode the same frame reads a different rung of the same ladder. Asserted
    -- both ways so the revision is a measurement rather than a caveat.
    local path = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
    local plain = bid(path, LANING, false)
    local honest = bid(path, LANING, true)
    assert(plain ~= nil and honest ~= nil, 'laning is drivable on this frame both ways')
    assert(honest <= plain,
        'the honest reading is never the higher one; got ' .. tostring(plain) ..
        ' -> ' .. tostring(honest))
    -- HONEST LIMIT, stated in the same terms as the previous round's: eleven
    -- other files in tests/ make auction-level claims and none was re-run
    -- here. Per the charter's one-at-a-time rule they are re-read when next
    -- touched, not batch-refreshed.
end

return tests

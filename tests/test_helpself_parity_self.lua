-- [helpself] Three "do we have the numbers to help this ally" sites write the
-- ally half as `#allies + 1`, the `+ 1` standing for the asking bot -- and all
-- three lists can already hold the asking bot.
--
-- READ THE HEADER OF J.GetHelpParityAllyCount FIRST (bots/FunLib/jmz_func.lua):
-- the defect, the two producers it comes from, the direction argument and the
-- domain readings live there. This file is what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE. It is in tests/_helpself_sweep.lua
-- and is run BY HAND: 1039 loads is minutes, and tools/agent/lua_gate.py kills
-- an unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition. Same reason tests/_roamring_sweep.lua sits outside.
-- Numbers quoted below were taken by that sweep on 2026-09-18:
--
--   live 1039
--   A reached 679  self 448  shipped 673  armed 664  down  9  up 0
--   B reached 547  self 367  shipped 541  armed 534  down  7  up 0
--   C reached  69  self  69  shipped  67  armed  40  down 27  up 0
--
-- ⛔ `up 0` is a reading only because `down` is 43 in the SAME tally.
--
-- ⚠️ INSTRUMENT LIMIT, stated rather than left for a wave: sites A and B sit
-- behind mode/desire chains (bot:GetActiveModeDesire, J.IsGoingOnSomeone) built
-- out of bot-VM state a .dem does not carry (GH #27 / STOPPER 4 family), so
-- those numbers are a CEILING on how often the BRANCH changes, not a fire rate.
-- Site C is different and is asserted end to end below: J.EvalTeamfightIdle is
-- reachable on the fixture frame and its whole answer flips.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_helpself_parity_self load time')

local tests = {}

-- THE WITNESS, and it is the frame that writes its own verdict.  Subject frame
-- of f_260820_162821_lion_drain_lethal (t=307.4): necrolyte stands 59.6u from
-- lion, who is being hit by luna and crystal_maiden.  The fixture's own ground
-- truth for lion is `died_after = 1.5` with 546 burst from THREE enemies -- the
-- third, lina, sits 1245.8u away, 45.8u outside the 1200 ring both halves use,
-- so even the enemy count is the understated one.  Shipped, necrolyte reads
-- this as even numbers, and one of the two fighters it counts is itself.
local W_FLIP  = { 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua',
                  'npc_dota_hero_necrolyte', 'dire' }
-- THE CONTROL, chosen so that arming is a no-op for the RIGHT reason: the bot
-- is 1853u from its closest ally, i.e. outside the 1200 ring, so the `+ 1` is
-- the correct arithmetic there.  The parity still sits on the knife edge
-- (1 + 1 >= 2), so "unchanged" is not unchanged-because-nothing-was-close.
local W_OUT   = { 'tests/fixtures/f_080225_wk_lane.lua',
                  'npc_dota_hero_vengeful_spirit', 'dire' }

local ALLY_RING, ENEMY_RING = 1200, 1600
local IDLE_ALLY, IDLE_RING = 1000, 1200

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ONE real load. ⛔ Never reuse a load to read the other game mode:
--- J.IsModeTurbo memoises into a module-level cache on its FIRST call, so a
--- second reading taken after flipping GetGameMode is the FIRST reading.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

--- Site A / B, rebuilt from the two producers the mode file calls -- no stubs.
--- `hAnchor` is J.GetClosestAlly (A) or J.GetClosestCore (B); both sites read
--- the ally half off the anchor's location.
local function help_parity(J, bot, hAnchor)
    local v = hAnchor:GetLocation()
    local tAllies = J.GetAlliesNearLoc(v, ALLY_RING) or {}
    local nEnemies = #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {})
    local nOurs = J.GetHelpParityAllyCount(bot, tAllies)
    return nOurs >= nEnemies, #tAllies, nEnemies, nOurs
end

--- Site C's own focused-ally scan, copied from J.EvalTeamfightIdle so the test
--- prices the same hFocusedAlly the shipped branch picks.
local function focused_ally(J, bot)
    for _, ally in pairs(J.GetNearbyHeroes(bot, IDLE_ALLY, false, BOT_MODE_NONE) or {}) do
        if J.IsValidHero(ally) and ally ~= bot
            and not J.IsSuspiciousIllusion(ally)
        then
            local onAlly = J.GetNearbyHeroes(ally, 900, true, BOT_MODE_NONE) or {}
            if #onAlly > 0
                and (ally:WasRecentlyDamagedByAnyHero(2.0) or J.GetHP(ally) < 0.5)
            then
                return ally
            end
        end
    end
    return nil
end

local function holds(tList, hUnit)
    for _, v in pairs(tList or {}) do if v == hUnit then return true end end
    return false
end

-- ================================================ 1. the source, pinned

local function slurp(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

--- Comments stripped: a claim about what the CODE does must not be satisfiable
--- by the prose describing it (both headers quote every one of these tokens).
local function code_of(path)
    return (slurp(path):gsub('%-%-[^\n]*', ''))
end

local function helper_code()
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function J.GetHelpParityAllyCount', 1, true),
        'J.GetHelpParityAllyCount is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[helpself] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'count'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'helpself'%s*%)"),
        "the 'helpself' gate is gone from J.GetHelpParityAllyCount")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- Three `+ 1` exits: the two refusals and the armed no-match fall-through.
    -- A helper that returns a literal, or that drops one of the refusals, passes
    -- every existence check above and then changes shipped behaviour.
    local _, nPlus = code:gsub('return%s+nCount%s*%+%s*1', '')
    assert(nPlus == 3,
        'expected three `return nCount + 1` exits (two refusals + no-match), '
        .. 'found ' .. nPlus)
    local _, nBare = code:gsub('return%s+nCount%s+end', '')
    assert(nBare == 1,
        'expected exactly one `return nCount end` -- the armed self-match -- '
        .. 'found ' .. nBare)
    -- The subtraction must be an identity test against the ASKER, not a count
    -- of anything: `#tAllies - 1` would answer this frame correctly and be
    -- wrong on every frame the bot is not in the list.
    assert(code:find('hAlly == bot', 1, true),
        'the armed path no longer compares list members against `bot`')
    assert(not code:find('%-%s*1'),
        'J.GetHelpParityAllyCount grew a `- 1`: the repair is not arithmetic')
end

tests['[helpself] all three call sites route through the helper'] = function()
    local roam = code_of('bots/mode_team_roam_generic.lua')
    local func = code_of('bots/FunLib/jmz_func.lua')
    local _, nRoam = roam:gsub('J%.GetHelpParityAllyCount%(bot, nInRangeAlly%)', '')
    assert(nRoam == 2,
        'expected both mode_team_roam parity sites on the helper, found '
        .. nRoam)
    assert(func:find('J.GetHelpParityAllyCount( bot, nAllyNear )', 1, true),
        'J.EvalTeamfightIdle no longer routes through the helper')
    -- ⛔ The lever is worth nothing if the old expression survives anywhere:
    -- this is the census that 0NEXT42 says to run, not the one call site the
    -- defect was found at.
    local _, nOldRoam = roam:gsub('#nInRangeAlly%s*%+%s*1%s*>=', '')
    assert(nOldRoam == 0,
        'a raw `#nInRangeAlly + 1 >=` survived in mode_team_roam_generic.lua: '
        .. nOldRoam)
    local _, nOldFunc = func:gsub('#nAllyNear%s*%+%s*1%s*%)%s*>=', '')
    assert(nOldFunc == 0,
        'a raw `( #nAllyNear + 1 ) >=` survived in jmz_func.lua: ' .. nOldFunc)
end

-- ================================================ 2. the real frame, no stubs

tests['[helpself] site C, end to end: shipped helps, armed flees'] = function()
    local J, bot = load(W_FLIP)
    ss.assert_clean('helpself site C shipped leg')
    assert(J.EvalTeamfightIdle(bot) == 'help',
        'the shipped tree no longer answers "help" on the witness frame -- the '
        .. 'defect this lever exists for is not on this frame any more')
    unprobe()

    local J2, bot2 = load(W_FLIP)
    ss.with_candidate('helpself', function()
        assert(J2.IsModeTurbo() == true, 'the turbo probe did not take')
        assert(J2.EvalTeamfightIdle(bot2) == 'flee',
            'armed, J.EvalTeamfightIdle must stop counting the asker twice and '
            .. 'refuse the help -- it did not')
    end, W_FLIP[3])
    unprobe()
end

tests['[helpself] site C: the list holds the asker, and that is the flip']
= function()
    local J, bot = load(W_FLIP)
    local hAlly = focused_ally(J, bot)
    assert(hAlly ~= nil, 'the witness frame lost its focused ally')
    assert(hAlly:GetUnitName() == 'npc_dota_hero_lion',
        'the focused ally changed identity: ' .. hAlly:GetUnitName())
    -- By construction, not by luck: hFocusedAlly is found inside 1000u and the
    -- ring is 1200, so the asker cannot be outside it.
    local d = GetUnitToUnitDistance(bot, hAlly)
    assert(d <= IDLE_ALLY, 'the focused ally is outside its own scan: ' .. d)
    local tNear = J.GetNearbyHeroes(hAlly, IDLE_RING, false, BOT_MODE_NONE) or {}
    assert(#tNear == 1, 'the ally ring stopped holding exactly one hero: ' .. #tNear)
    assert(holds(tNear, bot),
        'the asker is no longer in the list its call site adds 1 for')
    local nEnemies = #(J.GetNearbyHeroes(hAlly, IDLE_RING, true, BOT_MODE_NONE) or {})
    assert(nEnemies == 2, 'the enemy half stopped reading 2: ' .. nEnemies)
    assert(J.GetHelpParityAllyCount(bot, tNear) == 2,
        'disarmed, the helper must reproduce `#tAllies + 1`')
    unprobe()

    local J2, bot2 = load(W_FLIP)
    ss.with_candidate('helpself', function()
        local hAlly2 = focused_ally(J2, bot2)
        local tNear2 = J2.GetNearbyHeroes(hAlly2, IDLE_RING, false, BOT_MODE_NONE) or {}
        assert(J2.GetHelpParityAllyCount(bot2, tNear2) == 1,
            'armed, the asker must be counted once, not twice')
    end, W_FLIP[3])
    unprobe()
end

tests['[helpself] sites A and B flip on the same frame'] = function()
    local J, bot = load(W_FLIP)
    local hAlly = J.GetClosestAlly(bot, 3500)
    local hCore = J.GetClosestCore(bot, 3500)
    assert(hAlly ~= nil and hCore ~= nil,
        'the witness frame lost its closest ally / core anchor')
    local bA, nAllies, nEnemies, nOurs = help_parity(J, bot, hAlly)
    assert(nAllies == 2 and nEnemies == 3,
        'site A stopped reading 2 allies / 3 enemies: ' .. nAllies .. ' / '
        .. nEnemies)
    assert(nOurs == 3 and bA == true,
        'shipped, site A must call this even numbers (3 >= 3)')
    local bB = help_parity(J, bot, hCore)
    assert(bB == true, 'shipped, site B must call this even numbers too')
    unprobe()

    local J2, bot2 = load(W_FLIP)
    ss.with_candidate('helpself', function()
        local hAlly2 = J2.GetClosestAlly(bot2, 3500)
        local hCore2 = J2.GetClosestCore(bot2, 3500)
        local bA2, _, _, nOurs2 = help_parity(J2, bot2, hAlly2)
        assert(nOurs2 == 2,
            'armed, site A must count 2 of us, not 3: ' .. nOurs2)
        assert(bA2 == false, 'armed, site A must refuse (2 >= 3 is false)')
        assert(help_parity(J2, bot2, hCore2) == false,
            'armed, site B must refuse as well')
    end, W_FLIP[3])
    unprobe()
end

-- ================================================ 3. inertness

tests['[helpself] disarmed, the helper is the shipped expression'] = function()
    local J, bot = load(W_FLIP)
    ss.assert_clean('helpself inertness')
    local t = J.GetAlliesNearLoc(bot:GetLocation(), ALLY_RING) or {}
    assert(holds(t, bot), 'the inertness check needs a list holding the asker')
    assert(J.GetHelpParityAllyCount(bot, t) == #t + 1,
        'disarmed, the helper dropped the asker anyway')
    -- A different id armed must not arm this one.
    ss.with_candidate('roamring', function()
        assert(J.GetHelpParityAllyCount(bot, t) == #t + 1,
            'another armed id switched the self-count repair on')
    end, W_FLIP[3])
    unprobe()
end

tests['[helpself] armed but NOT turbo is the shipped expression'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading, because
    -- J.IsModeTurbo memoises into a module-level cache on its FIRST call -- a
    -- reading taken after flipping a mode that was already read is the OLD one.
    unprobe()
    local J, bot = rf.load(W_FLIP[1], W_FLIP[2])
    GAMEMODE_TURBO = 23                     -- luacheck: ignore
    GetGameMode = function() return 1 end   -- luacheck: ignore
    ss.with_candidate('helpself', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        local t = J.GetAlliesNearLoc(bot:GetLocation(), ALLY_RING) or {}
        assert(holds(t, bot), 'the non-turbo check needs a list holding the asker')
        assert(J.GetHelpParityAllyCount(bot, t) == #t + 1,
            'armed outside turbo dropped the asker -- this must be turbo-only')
    end, W_FLIP[3])
    unprobe()
end

tests['[helpself] armed on the OTHER side is the shipped expression'] = function()
    local J, bot = load(W_FLIP)
    ss.with_candidate('helpself', function()
        local t = J.GetAlliesNearLoc(bot:GetLocation(), ALLY_RING) or {}
        assert(J.GetHelpParityAllyCount(bot, t) == #t + 1,
            'the radiant-armed leg changed a dire bot')
    end, 'radiant')
    unprobe()
end

-- ================================================ 4. direction, on real frames

tests['[helpself] armed can only REMOVE one, never add'] = function()
    -- The direction argument is arithmetic on a set membership, so it is checked
    -- as one: on both witnesses the armed count must be the shipped count or
    -- exactly one less, and which of the two is decided by membership alone.
    for _, w in ipairs({ W_FLIP, W_OUT }) do
        local J, bot = load(w)
        local hAnchor = J.GetClosestAlly(bot, 3500)
        local t = J.GetAlliesNearLoc(hAnchor:GetLocation(), ALLY_RING) or {}
        local bSelf = holds(t, bot)
        local nShipped = J.GetHelpParityAllyCount(bot, t)
        assert(nShipped == #t + 1, w[2] .. ': disarmed reading moved')
        unprobe()

        local J2, bot2 = load(w)
        ss.with_candidate('helpself', function()
            local hAnchor2 = J2.GetClosestAlly(bot2, 3500)
            local t2 = J2.GetAlliesNearLoc(hAnchor2:GetLocation(), ALLY_RING) or {}
            local nArmed = J2.GetHelpParityAllyCount(bot2, t2)
            assert(nArmed <= nShipped,
                w[2] .. ': armed counted MORE of us than shipped ('
                .. nArmed .. ' > ' .. nShipped .. ')')
            assert(nArmed >= nShipped - 1,
                w[2] .. ': armed removed more than the asker')
            assert(nArmed == nShipped - (bSelf and 1 or 0),
                w[2] .. ': the difference is not membership of the asker')
        end, w[3])
        unprobe()
    end
end

-- ================================================ 5. control

tests['[control] a bot outside the ring is unchanged by arming'] = function()
    local J, bot = load(W_OUT)
    local hAnchor = J.GetClosestAlly(bot, 3500)
    assert(hAnchor ~= nil, 'the control frame lost its anchor')
    local d = GetUnitToUnitDistance(bot, hAnchor)
    assert(d > ALLY_RING,
        'the control bot walked INSIDE the 1200 ring (' .. d
        .. ') -- it no longer controls for anything')
    local t = J.GetAlliesNearLoc(hAnchor:GetLocation(), ALLY_RING) or {}
    assert(not holds(t, bot), 'the control list grew the asker')
    local bShipped, nAllies, nEnemies, nOurs = help_parity(J, bot, hAnchor)
    -- ⛔ Knife edge on purpose: `1 + 1 >= 2`. If arming touched this frame at
    -- all the answer would move, so "unchanged" is a real reading here and not
    -- unchanged-because-nothing-was-close.
    assert(nAllies == 1 and nEnemies == 2 and nOurs == 2 and bShipped == true,
        'the control frame left the knife edge: allies=' .. nAllies
        .. ' enemies=' .. nEnemies .. ' ours=' .. nOurs)
    unprobe()

    local J2, bot2 = load(W_OUT)
    ss.with_candidate('helpself', function()
        local hAnchor2 = J2.GetClosestAlly(bot2, 3500)
        local bArmed, _, _, nOurs2 = help_parity(J2, bot2, hAnchor2)
        assert(nOurs2 == 2 and bArmed == bShipped,
            'arming changed a frame whose `+ 1` was the correct arithmetic -- '
            .. 'the flips in section 2 are not the self entry')
    end, W_OUT[3])
    unprobe()
end

tests['[control] the two witnesses are distinct populations'] = function()
    local seen = {}
    for _, w in ipairs({ W_FLIP, W_OUT }) do
        local J, bot = load(w)
        local hAnchor = J.GetClosestAlly(bot, 3500)
        seen[#seen + 1] = holds(J.GetAlliesNearLoc(hAnchor:GetLocation(),
            ALLY_RING) or {}, bot)
        unprobe()
    end
    assert(seen[1] == true and seen[2] == false,
        'the witnesses no longer cover both sides of "is the asker in the '
        .. 'list": ' .. tostring(seen[1]) .. ', ' .. tostring(seen[2]))
end

return tests

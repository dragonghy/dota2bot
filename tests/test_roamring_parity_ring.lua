-- [roamring] mode_team_roam_generic.lua reads the two halves of ONE parity
-- question off two DIFFERENT rings -- allies 2200, enemies 2000 -- and the only
-- consumer of both is `elseif #nearbyAllies >= #nearbyEnemies`.
--
-- READ THE HEADER OF J.GetRoamParityRadius FIRST (bots/FunLib/jmz_func.lua):
-- the defect, the direction argument and the domain readings live there. This
-- file is what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE. It is in tests/_roamring_sweep.lua
-- and is run BY HAND: 1039 loads is minutes, and tools/agent/lua_gate.py kills
-- an unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition. Same reason tests/_soloclaim_sweep.lua sits outside.
-- Numbers quoted below were taken by that sweep on 2026-09-17:
--
--   live 1039 | eshell_nonempty 57 | shipped_true 954 | wide_true 944
--   wide_down 10 | wide_up 0
--
-- ⛔ `wide_up 0` is a reading only because `wide_down` is 10 in the SAME tally.
--
-- ⚠️ INSTRUMENT LIMIT, stated rather than left for a wave: the consumer at
-- :398 sits behind a mode/activity chain built out of bot:GetActiveMode(), which
-- is bot-VM state a .dem does not carry (GH #27 / STOPPER 4 family). So 10 is a
-- CEILING on how often the BRANCH changes, not a fire rate. Every assertion
-- below is about the PREDICATE, which is entirely hero geometry and is ground
-- truth in the dump.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_roamring_parity_ring load time')

local tests = {}

-- The witness. `a2200=1 e2000=1 e2200=2`: jakiro alone (its only living ally is
-- 7499u away, the other is dead at 1114u), dragon_knight at 1309.6u and
-- earthshaker at 2151.8u -- i.e. an enemy standing INSIDE the very ring the file
-- already trusts for our own side, and outside the one it uses for theirs.
local W_FLIP  = { 'tests/fixtures/f_260819_183613_storm_collapse_lost.lua',
                  'npc_dota_hero_jakiro', 'radiant' }
-- The control: a frame with NOTHING in the 2000-2200 enemy shell, so arming
-- must be a no-op there for a reason that is not the gate.
local W_QUIET = { 'tests/fixtures/f_011405_jak_rescue_axe.lua',
                  'npc_dota_hero_axe', 'radiant' }

local ALLY_RING, ENEMY_RING = 2200, 2000

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

--- The shipped comparison, rebuilt from the two producers the mode file calls
--- and the radius the helper hands back -- no stubs anywhere in this file.
local function parity(J, bot)
    local v = bot:GetLocation()
    local nAllies = #(J.GetAlliesNearLoc(v, ALLY_RING) or {})
    local nEnemies = #(J.GetEnemiesNearLoc(v,
        J.GetRoamParityRadius(ALLY_RING, ENEMY_RING)) or {})
    return nAllies >= nEnemies, nAllies, nEnemies
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
    local at = assert(s:find('function J.GetRoamParityRadius', 1, true),
        'J.GetRoamParityRadius is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[roamring] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'radius'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'roamring'%s*%)"),
        "the 'roamring' gate is gone from J.GetRoamParityRadius")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- Both refusals must hand back the ENEMY radius, not a literal: a helper
    -- that returns 2000 by name passes every existence check above and then
    -- silently ignores what its caller asked about.
    local _, nReturns = code:gsub('return%s+nEnemyRadius', '')
    assert(nReturns == 2,
        'expected both disarmed paths to return nEnemyRadius, found '
        .. nReturns)
    assert(not code:find('2000', 1, true) and not code:find('2200', 1, true),
        'J.GetRoamParityRadius grew a literal radius of its own -- the two '
        .. 'numbers belong to the call site')
end

tests['[roamring] the call site: one ring literal, one consumer'] = function()
    local code = code_of('bots/mode_team_roam_generic.lua')
    -- The ally ring is named once and both producers are fed from that name,
    -- so the two halves cannot drift apart again without this failing.
    local _, nDecl = code:gsub('local nRoamParityAllyRing = 2200', '')
    assert(nDecl == 1,
        'expected exactly one nRoamParityAllyRing declaration, found ' .. nDecl)
    assert(code:find('GetAlliesNearLoc(bot:GetLocation(), nRoamParityAllyRing)',
        1, true), 'the ally half no longer reads the named ring')
    assert(code:find('J.GetRoamParityRadius(nRoamParityAllyRing, 2000)', 1, true),
        'the enemy half no longer routes through J.GetRoamParityRadius')
    -- ⛔ The lever is worth nothing if a second consumer appears that reads the
    -- two counts for a different question.
    local _, nUse = code:gsub('#nearbyAllies >= #nearbyEnemies', '')
    assert(nUse == 1,
        'expected exactly one consumer of the parity pair, found ' .. nUse)
end

-- ================================================ 2. the real frame, no stubs

tests['[roamring] the witness frame: shipped says "not outnumbered", armed '
    .. 'does not'] = function()
    local J, bot = load(W_FLIP)
    ss.assert_clean('roamring shipped leg')
    local bShipped, nA, nE = parity(J, bot)
    assert(nA == 1, 'the witness stopped being a lone hero: allies = ' .. nA)
    assert(nE == 1, 'the shipped enemy ring stopped reading 1: ' .. nE)
    assert(bShipped == true,
        'the shipped tree no longer calls this frame even numbers -- the '
        .. 'defect this lever exists for is not on this frame any more')
    unprobe()

    local J2, bot2 = load(W_FLIP)
    ss.with_candidate('roamring', function()
        local bArmed, nA2, nE2 = parity(J2, bot2)
        assert(nA2 == 1, 'ally count moved under arming: ' .. nA2)
        assert(nE2 == 2,
            'armed, the enemy half must see the hero in the 2000-2200 shell; '
            .. 'it read ' .. nE2)
        assert(bArmed == false,
            'armed REFUSES the lone-hero commit -- it did not')
    end, W_FLIP[3])
    unprobe()
end

tests['[roamring] the witness is the shell, not the gate'] = function()
    -- ⛔ A frame where the extra enemy sat at 1900u would make the test above
    -- pass for a reason that has nothing to do with the two rings.
    local J, bot = load(W_FLIP)
    local v = bot:GetLocation()
    local tWide = J.GetEnemiesNearLoc(v, ALLY_RING) or {}
    local tTight = J.GetEnemiesNearLoc(v, ENEMY_RING) or {}
    assert(#tWide == #tTight + 1,
        'expected exactly one enemy in the 2000-2200 shell, found '
        .. (#tWide - #tTight))
    local nFound = 0
    for _, e in pairs(tWide) do
        local d = GetUnitToLocationDistance(e, v)
        if d > ENEMY_RING and d <= ALLY_RING then
            nFound = nFound + 1
            assert(e:GetUnitName() == 'npc_dota_hero_earthshaker',
                'the shell hero changed identity: ' .. e:GetUnitName())
        end
    end
    assert(nFound == 1, 'the shell reading and the count disagree')
    unprobe()
end

-- ================================================ 3. inertness

tests['[roamring] disarmed, the helper is the shipped expression'] = function()
    local J = load(W_FLIP)
    ss.assert_clean('roamring inertness')
    assert(J.GetRoamParityRadius(ALLY_RING, ENEMY_RING) == ENEMY_RING,
        'disarmed, the enemy ring moved')
    -- A different id armed must not arm this one.
    ss.with_candidate('pullcamp', function()
        assert(J.GetRoamParityRadius(ALLY_RING, ENEMY_RING) == ENEMY_RING,
            'another armed id switched the parity ring on')
    end, W_FLIP[3])
    unprobe()
end

tests['[roamring] armed but NOT turbo is the shipped expression'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading, because
    -- J.IsModeTurbo memoises into a module-level cache on its FIRST call -- a
    -- reading taken after flipping a mode that was already read is the OLD one.
    -- `J.IsModeTurbo() == false` is asserted first so a silently-ineffective
    -- override cannot make the real claim pass for free.
    unprobe()
    local J = rf.load(W_FLIP[1], W_FLIP[2])
    GAMEMODE_TURBO = 23                     -- luacheck: ignore
    GetGameMode = function() return 1 end   -- luacheck: ignore
    ss.with_candidate('roamring', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        assert(J.GetRoamParityRadius(ALLY_RING, ENEMY_RING) == ENEMY_RING,
            'armed outside turbo widened the enemy ring -- this must be '
            .. 'turbo-only')
    end, W_FLIP[3])
    unprobe()
end

tests['[roamring] armed on the OTHER side is the shipped expression'] = function()
    local J = load(W_FLIP)
    ss.with_candidate('roamring', function()
        assert(J.GetRoamParityRadius(ALLY_RING, ENEMY_RING) == ENEMY_RING,
            'the dire-armed leg changed a radiant bot')
    end, 'dire')
    unprobe()
end

-- ================================================ 4. direction, on real frames

tests['[roamring] armed can only ADD enemies, never remove one'] = function()
    -- The direction argument is a set inclusion, so it is checked as one: on
    -- both witnesses the wide list must CONTAIN the tight list.
    for _, w in ipairs({ W_FLIP, W_QUIET }) do
        local J, bot = load(w)
        local v = bot:GetLocation()
        local tTight = J.GetEnemiesNearLoc(v, ENEMY_RING) or {}
        local tWide = J.GetEnemiesNearLoc(v, ALLY_RING) or {}
        local seen = {}
        for _, e in pairs(tWide) do seen[e] = true end
        for _, e in pairs(tTight) do
            assert(seen[e], w[2] .. ': the 2200 ring dropped a hero the 2000 '
                .. 'ring had -- the superset argument is false')
        end
        assert(#tWide >= #tTight, w[2] .. ': the wider ring counted fewer')
        unprobe()
    end
end

-- ================================================ 5. control

tests['[control] a frame with an empty shell is unchanged by arming'] =
function()
    local J, bot = load(W_QUIET)
    local v = bot:GetLocation()
    local nTight = #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {})
    local nWide = #(J.GetEnemiesNearLoc(v, ALLY_RING) or {})
    assert(nWide == nTight,
        'the control frame grew a shell hero (' .. nTight .. ' -> ' .. nWide
        .. ') -- it no longer controls for anything')
    local bShipped = parity(J, bot)
    unprobe()

    local J2, bot2 = load(W_QUIET)
    ss.with_candidate('roamring', function()
        local bArmed = parity(J2, bot2)
        assert(bArmed == bShipped,
            'arming changed a frame with nothing in the shell -- the flip in '
            .. 'section 2 is not the shell')
    end, W_QUIET[3])
    unprobe()
end

tests['[control] the two witnesses are distinct populations'] = function()
    local shells = {}
    for _, w in ipairs({ W_FLIP, W_QUIET }) do
        local J, bot = load(w)
        local v = bot:GetLocation()
        shells[#shells + 1] = #(J.GetEnemiesNearLoc(v, ALLY_RING) or {})
            - #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {})
        unprobe()
    end
    assert(shells[1] == 1 and shells[2] == 0,
        'the witnesses no longer cover shell sizes 1 / 0, they read '
        .. table.concat(shells, ', '))
end

return tests

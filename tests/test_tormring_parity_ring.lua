-- [tormring] mode_side_shop_generic.lua reads the two halves of ONE parity
-- question off two DIFFERENT rings -- enemies 1600 (:61), allies 1200 (:220) --
-- and the only consumer of both is the Tormentor bail
-- `if not J.IsRealInvisible(bot) and (#tInRangeEnemy > #tInRangeAlly)`.
--
-- READ THE HEADER OF J.GetTormentorParityRadius FIRST (bots/FunLib/jmz_func.lua):
-- the defect, the direction argument, the domain readings and the reason the
-- OTHER unification is registered-but-not-shipped all live there. This file is
-- what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE. It is in tests/_tormring_sweep.lua
-- and is run BY HAND: 1039 loads is minutes, and tools/agent/lua_gate.py kills
-- an unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition. Same reason tests/_roamring_sweep.lua sits outside.
-- Numbers quoted below were taken by that sweep on 2026-09-18:
--
--   live 1039 | ashell_nonempty 94 | shipped_bail 78 | wide_bail 65
--   wide_down 13 | wide_up 0   (shipped lever: allies read off the enemy ring)
--   tight_bail 59 | tight_down 19 | tight_up 0   (the other unification)
--
-- ⛔ `wide_up 0` is a reading only because `wide_down` is 13 in the SAME tally.
--
-- ⚠️ INSTRUMENT LIMIT, stated rather than left for a wave: the consumer sits
-- behind the Tormentor chain (spawn window, average levels, `bot == ally`, and
-- the `bot.tormentor_state` booleans, which are bot-VM state a .dem does not
-- carry -- GH #27 / STOPPER 4 family). So 13 is a CEILING on how often the BAIL
-- changes, not a fire rate. Every assertion below is about the PREDICATE, which
-- is entirely hero geometry and is ground truth in the dump.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_tormring_parity_ring load time')

local tests = {}

-- The witness. `a1200=1 a1600=3 e1600=3`: sniper (dire) with TWO living
-- teammates at 1426u (viper) and 1570u (crystal_maiden) -- i.e. allies standing
-- INSIDE the very ring the file already trusts for the enemy half, and outside
-- the one it uses for ours. Shipped reads 3 > 1 and bails; counted over one
-- circle it is 3 > 3, which is not being outnumbered.
local W_FLIP  = { 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua',
                  'npc_dota_hero_sniper', 'dire' }
-- The control: a frame with NOTHING in the 1200-1600 ally shell, so arming must
-- be a no-op there for a reason that is not the gate.
local W_QUIET = { 'tests/fixtures/f_011405_jak_rescue_axe.lua',
                  'npc_dota_hero_axe', 'radiant' }

local ALLY_RING, ENEMY_RING = 1200, 1600

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

--- The shipped bail, rebuilt from the two producers the mode file calls and the
--- radius the helper hands back -- no stubs anywhere in this file.
local function bail(J, bot)
    local v = bot:GetLocation()
    local nEnemies = #(J.GetEnemiesNearLoc(v, ENEMY_RING) or {})
    local nAllies = #(J.GetAlliesNearLoc(v,
        J.GetTormentorParityRadius(ENEMY_RING, ALLY_RING)) or {})
    return nEnemies > nAllies, nEnemies, nAllies
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
    local at = assert(s:find('function J.GetTormentorParityRadius', 1, true),
        'J.GetTormentorParityRadius is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[tormring] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'radius'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'tormring'%s*%)"),
        "the 'tormring' gate is gone from J.GetTormentorParityRadius")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- Both refusals must hand back the ALLY radius, not a literal: a helper
    -- that returns 1200 by name passes every existence check above and then
    -- silently ignores what its caller asked about.
    local _, nReturns = code:gsub('return%s+nAllyRadius', '')
    assert(nReturns == 2,
        'expected both disarmed paths to return nAllyRadius, found ' .. nReturns)
    assert(not code:find('1200', 1, true) and not code:find('1600', 1, true),
        'J.GetTormentorParityRadius grew a literal radius of its own -- the two '
        .. 'numbers belong to the call site')
end

tests['[tormring] the call site: one ring literal, one consumer'] = function()
    local code = code_of('bots/mode_side_shop_generic.lua')
    -- The enemy ring is named once and both producers are fed from that name,
    -- so the two halves cannot drift apart again without this failing.
    local _, nDecl = code:gsub('local nTormentorParityEnemyRing = 1600', '')
    assert(nDecl == 1,
        'expected exactly one nTormentorParityEnemyRing declaration, found '
        .. nDecl)
    assert(code:find(
        'GetEnemiesNearLoc(bot:GetLocation(), nTormentorParityEnemyRing)',
        1, true), 'the enemy half no longer reads the named ring')
    assert(code:find(
        'J.GetTormentorParityRadius(nTormentorParityEnemyRing, 1200)', 1, true),
        'the ally half no longer routes through J.GetTormentorParityRadius')
    -- ⛔ The lever is worth nothing if a second consumer appears that reads the
    -- two counts for a different question.
    local _, nUse = code:gsub('#tInRangeEnemy > #tInRangeAlly', '')
    assert(nUse == 1,
        'expected exactly one consumer of the parity pair, found ' .. nUse)
end

-- ================================================ 2. the real frame, no stubs

tests['[tormring] the witness frame: shipped bails on the Tormentor, armed '
    .. 'does not'] = function()
    local J, bot = load(W_FLIP)
    ss.assert_clean('tormring shipped leg')
    local bShipped, nE, nA = bail(J, bot)
    assert(nE == 3, 'the witness stopped reading 3 enemies: ' .. nE)
    assert(nA == 1, 'the shipped ally ring stopped reading 1: ' .. nA)
    assert(bShipped == true,
        'the shipped tree no longer calls this frame outnumbered -- the defect '
        .. 'this lever exists for is not on this frame any more')
    unprobe()

    local J2, bot2 = load(W_FLIP)
    ss.with_candidate('tormring', function()
        local bArmed, nE2, nA2 = bail(J2, bot2)
        assert(nE2 == 3, 'enemy count moved under arming: ' .. nE2)
        assert(nA2 == 3,
            'armed, the ally half must see the two heroes in the 1200-1600 '
            .. 'shell; it read ' .. nA2)
        assert(bArmed == false,
            'armed REFUSES the outnumbered bail -- it did not')
    end, W_FLIP[3])
    unprobe()
end

tests['[tormring] the witness is the shell, not the gate'] = function()
    -- ⛔ A frame whose extra allies sat at 1100u would make the test above pass
    -- for a reason that has nothing to do with the two rings.
    local J, bot = load(W_FLIP)
    local v = bot:GetLocation()
    local tWide = J.GetAlliesNearLoc(v, ENEMY_RING) or {}
    local tTight = J.GetAlliesNearLoc(v, ALLY_RING) or {}
    assert(#tWide == #tTight + 2,
        'expected exactly two allies in the 1200-1600 shell, found '
        .. (#tWide - #tTight))
    local seen = {}
    for _, a in pairs(tWide) do
        local d = GetUnitToLocationDistance(a, v)
        if d > ALLY_RING and d <= ENEMY_RING then
            seen[a:GetUnitName()] = true
        end
    end
    assert(seen['npc_dota_hero_viper'] and seen['npc_dota_hero_crystal_maiden'],
        'the two shell heroes changed identity')
    unprobe()
end

-- ================================================ 3. inertness

tests['[tormring] disarmed, the helper is the shipped expression'] = function()
    local J = load(W_FLIP)
    ss.assert_clean('tormring inertness')
    assert(J.GetTormentorParityRadius(ENEMY_RING, ALLY_RING) == ALLY_RING,
        'disarmed, the ally ring moved')
    -- A different id armed must not arm this one.
    ss.with_candidate('roamring', function()
        assert(J.GetTormentorParityRadius(ENEMY_RING, ALLY_RING) == ALLY_RING,
            'another armed id switched the parity ring on')
    end, W_FLIP[3])
    unprobe()
end

tests['[tormring] armed but NOT turbo is the shipped expression'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading, because
    -- J.IsModeTurbo memoises into a module-level cache on its FIRST call -- a
    -- reading taken after flipping a mode that was already read is the OLD one.
    -- `J.IsModeTurbo() == false` is asserted first so a silently-ineffective
    -- override cannot make the real claim pass for free.
    unprobe()
    local J = rf.load(W_FLIP[1], W_FLIP[2])
    GAMEMODE_TURBO = 23                     -- luacheck: ignore
    GetGameMode = function() return 1 end   -- luacheck: ignore
    ss.with_candidate('tormring', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        assert(J.GetTormentorParityRadius(ENEMY_RING, ALLY_RING) == ALLY_RING,
            'armed outside turbo widened the ally ring -- this must be '
            .. 'turbo-only')
    end, W_FLIP[3])
    unprobe()
end

tests['[tormring] armed on the OTHER side is the shipped expression'] = function()
    local J = load(W_FLIP)
    ss.with_candidate('tormring', function()
        assert(J.GetTormentorParityRadius(ENEMY_RING, ALLY_RING) == ALLY_RING,
            'the radiant-armed leg changed a dire bot')
    end, 'radiant')
    unprobe()
end

-- ================================================ 4. direction, on real frames

tests['[tormring] armed can only ADD allies, never remove one'] = function()
    -- The direction argument is a set inclusion, so it is checked as one: on
    -- both witnesses the wide list must CONTAIN the tight list.
    for _, w in ipairs({ W_FLIP, W_QUIET }) do
        local J, bot = load(w)
        local v = bot:GetLocation()
        local tTight = J.GetAlliesNearLoc(v, ALLY_RING) or {}
        local tWide = J.GetAlliesNearLoc(v, ENEMY_RING) or {}
        local seen = {}
        for _, a in pairs(tWide) do seen[a] = true end
        for _, a in pairs(tTight) do
            assert(seen[a], w[2] .. ': the 1600 ring dropped a hero the 1200 '
                .. 'ring had -- the superset argument is false')
        end
        assert(#tWide >= #tTight, w[2] .. ': the wider ring counted fewer')
        unprobe()
    end
end

-- ================================================ 5. control

tests['[control] a frame with an empty ally shell is unchanged by arming'] =
function()
    local J, bot = load(W_QUIET)
    local v = bot:GetLocation()
    local nTight = #(J.GetAlliesNearLoc(v, ALLY_RING) or {})
    local nWide = #(J.GetAlliesNearLoc(v, ENEMY_RING) or {})
    assert(nWide == nTight,
        'the control frame grew a shell hero (' .. nTight .. ' -> ' .. nWide
        .. ') -- it no longer controls for anything')
    local bShipped = bail(J, bot)
    unprobe()

    local J2, bot2 = load(W_QUIET)
    ss.with_candidate('tormring', function()
        local bArmed = bail(J2, bot2)
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
        shells[#shells + 1] = #(J.GetAlliesNearLoc(v, ENEMY_RING) or {})
            - #(J.GetAlliesNearLoc(v, ALLY_RING) or {})
        unprobe()
    end
    assert(shells[1] == 2 and shells[2] == 0,
        'the witnesses no longer cover shell sizes 2 / 0, they read '
        .. table.concat(shells, ', '))
end

return tests

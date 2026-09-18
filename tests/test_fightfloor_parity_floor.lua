-- [fightfloor] J.SafeToCommitFight's NUMBERS branch counts every ALIVE ally
-- near the engage point as a full fighter, including one that is seconds from
-- dying.
--
-- READ THE HEADER OF J.GetCommitParityFighters FIRST (bots/FunLib/jmz_func.lua):
-- the defect, the "ally side only" argument, the direction argument and the
-- domain readings live there. This file is what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE. It is in tests/_fightfloor_sweep.lua
-- and is run BY HAND: 1039 loads is minutes, and tools/agent/lua_gate.py kills
-- an unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition. Same reason tests/_roamring_sweep.lua sits outside.
-- Numbers quoted below were taken by that sweep on 2026-09-18:
--
--   live 1039 | pairs 4840 | lowally_pairs 365 | shipped_true 1354
--   armed_true 1164 | down 190 | up 0 | down_unique 39 on 21 of 112 fixtures
--
-- ⛔ `up 0` is a reading only because `down` is 190 in the SAME tally.
--
-- ⚠️ INSTRUMENT LIMIT. `lethal_true` is 0 over the whole corpus: a fixture's
-- GetEstimatedDamageToTarget is the damage that unit actually dealt to the
-- SUBJECT (replay_fixture.lua:729), and an ALLY dealt none. So on a fixture
-- J.SafeToCommitFight IS its numbers branch, and the end-to-end assertions
-- below are legitimate readings of branch (b) -- but they say nothing about how
-- often branch (a) pre-empts it in game.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_fightfloor_parity_floor load time')

local tests = {}

-- The witness, and it is the frame the defect was WRITTEN DOWN on: Wraith King
-- at 88/693 = 12.7% HP stands inside the Shadow Shaman + Juggernaut dual lane
-- and dies 6.1s later (ground truth in the fixture). Around Juggernaut the
-- shipped parity reads 2 allies (the dying WK + Earthshaker) vs 2 enemies and
-- answers "safe to commit".
local W_FLIP   = { 'tests/fixtures/f_080225_wk_lane.lua',
                   'npc_dota_hero_skeleton_king', 'dire',
                   'npc_dota_hero_juggernaut' }
-- The control: same shape (2 allies, 2 enemies, parity true), nobody below the
-- floor, so arming must be a no-op there for a reason that is not the gate.
local W_QUIET  = { 'tests/fixtures/f_011405_jak_rescue_axe.lua',
                   'npc_dota_hero_axe', 'radiant',
                   'npc_dota_hero_pudge' }

local RING = 1200

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
    local J, bot, heroes, fx = rf.load(w[1], w[2])
    turbo()
    return J, bot, heroes[w[4]], fx
end

--- The three counts the branch is built out of, taken through the real
--- producers and the real helper -- no stubs anywhere in this file.
local function counts(J, hTarget)
    local v = hTarget:GetLocation()
    local tAllies = J.GetAlliesNearLoc(v, RING) or {}
    local tEnemies = J.GetEnemiesNearLoc(v, RING) or {}
    local tFighters = J.GetCommitParityFighters(tAllies) or {}
    return #tAllies, #tFighters, #tEnemies
end

-- ================================================ 1. the source, pinned

local function slurp(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end

--- Comments stripped: a claim about what the CODE does must not be satisfiable
--- by the prose describing it (the header quotes every one of these tokens).
local function code_of(path)
    return (slurp(path):gsub('%-%-[^\n]*', ''))
end

local function body_of(sName)
    local s = code_of('bots/FunLib/jmz_func.lua')
    local at = assert(s:find('function ' .. sName, 1, true),
        sName .. ' is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[fightfloor] the repair is gated, turbo-scoped, and fails to the '
    .. 'shipped list'] = function()
    local code = body_of('J.GetCommitParityFighters')
    assert(code:find("IsSoakCandidate%(%s*'fightfloor'%s*%)"),
        "the 'fightfloor' gate is gone from J.GetCommitParityFighters")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- Both refusals must hand back the CALLER'S list. A helper that rebuilds
    -- an unfiltered copy passes every existence check above and then quietly
    -- changes identity -- and a caller comparing `==` would never know.
    local _, nReturns = code:gsub('return tAllies', '')
    assert(nReturns == 2,
        'expected both disarmed paths to return tAllies, found ' .. nReturns)
    -- ⛔ The floor belongs to the NAME, not to this function: a literal here is
    -- exactly the drift this lever exists to make impossible.
    assert(not code:find('0.35', 1, true),
        'J.GetCommitParityFighters grew a floor literal of its own')
    assert(code:find('J.COMMIT_PARITY_HP_FLOOR', 1, true),
        'the helper no longer reads the named floor')
end

tests['[fightfloor] one floor, declared once, read by both halves'] = function()
    local code = code_of('bots/FunLib/jmz_func.lua')
    local _, nDecl = code:gsub('J%.COMMIT_PARITY_HP_FLOOR%s*=%s*0%.35', '')
    assert(nDecl == 1,
        'expected exactly one J.COMMIT_PARITY_HP_FLOOR declaration, found '
        .. nDecl)
    -- The caller that repaired this ONE call site in-place now reads the same
    -- name, so "too low to count" cannot mean two different numbers again.
    assert(code:find('J.GetHP( bot ) < J.COMMIT_PARITY_HP_FLOOR', 1, true),
        'the dive guard stopped reading the named floor')
end

tests['[fightfloor] the call site: the numbers branch, and only it'] =
function()
    local code = body_of('J.SafeToCommitFight')
    local _, nUse = code:gsub('J%.GetCommitParityFighters%( tAllies %)', '')
    assert(nUse == 1,
        'expected exactly one GetCommitParityFighters consumer inside '
        .. 'J.SafeToCommitFight, found ' .. nUse)
    -- ⛔ Branch (a) must stay on the UNFILTERED list: a secured burst kill is
    -- still a go, and a critical ally's damage is still damage.
    assert(code:find('J.GetTotalEstimatedDamageToTarget( tAllies, target )',
        1, true),
        'the LETHAL branch no longer scores the unfiltered ally list')
end

-- ================================================ 2. the real frame, no stubs

tests['[fightfloor] the witness frame: shipped commits into the lane that '
    .. 'killed him, armed does not'] = function()
    local J, bot, hT, fx = load(W_FLIP)
    ss.assert_clean('fightfloor shipped leg')
    assert(fx.observed.died_after ~= nil and fx.observed.died_after < 10,
        'ground truth: the subject died within seconds of this frame')
    assert(J.GetHP(bot) < J.COMMIT_PARITY_HP_FLOOR,
        'the witness stopped being a critical-HP frame')
    local nA, nF, nE = counts(J, hT)
    assert(nA == 2 and nE == 2,
        'the witness stopped being a 2v2 around the target: ' .. nA .. 'v' .. nE)
    assert(nF == nA,
        'disarmed, the fighter list must BE the ally list; it read ' .. nF)
    assert(J.SafeToCommitFight(bot, hT) == true,
        'the shipped tree no longer calls this commit safe -- the defect this '
        .. 'lever exists for is not on this frame any more')
    unprobe()

    local J2, bot2, hT2 = load(W_FLIP)
    ss.with_candidate('fightfloor', function()
        local nA2, nF2, nE2 = counts(J2, hT2)
        assert(nA2 == 2 and nE2 == 2, 'the counts moved under arming')
        assert(nF2 == 1,
            'armed, the 12.7%-HP subject must drop out of the fighter count; '
            .. 'it read ' .. nF2)
        assert(J2.SafeToCommitFight(bot2, hT2) == false,
            'armed REFUSES the commit next to a dying ally -- it did not')
    end, W_FLIP[3])
    unprobe()
end

tests['[fightfloor] the witness is the FLOOR, not the gate'] = function()
    -- ⛔ A frame where both allies were healthy would make the case above pass
    -- for a reason that has nothing to do with anybody's health.
    local J, _, hT = load(W_FLIP)
    local tAllies = J.GetAlliesNearLoc(hT:GetLocation(), RING) or {}
    local nBelow, nAbove = 0, 0
    for _, a in pairs(tAllies) do
        if J.GetHP(a) < J.COMMIT_PARITY_HP_FLOOR then
            nBelow = nBelow + 1
            assert(a:GetUnitName() == 'npc_dota_hero_skeleton_king',
                'the sub-floor ally changed identity: ' .. a:GetUnitName())
        else
            nAbove = nAbove + 1
        end
    end
    assert(nBelow == 1 and nAbove == 1,
        'expected exactly one sub-floor ally beside one healthy one, found '
        .. nBelow .. ' / ' .. nAbove)
    unprobe()
end

-- ================================================ 3. inertness

tests['[fightfloor] disarmed, the helper is the identity'] = function()
    local J, _, hT = load(W_FLIP)
    ss.assert_clean('fightfloor inertness')
    local tAllies = J.GetAlliesNearLoc(hT:GetLocation(), RING)
    assert(J.GetCommitParityFighters(tAllies) == tAllies,
        'disarmed, the helper handed back something other than its argument')
    -- A different id armed must not arm this one.
    ss.with_candidate('pullcamp', function()
        assert(J.GetCommitParityFighters(tAllies) == tAllies,
            'another armed id switched the floor on')
    end, W_FLIP[3])
    unprobe()
end

tests['[fightfloor] armed but NOT turbo is the identity'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading,
    -- because J.IsModeTurbo memoises into a module-level cache on its FIRST
    -- call -- a reading taken after flipping a mode that was already read is
    -- the OLD one. `J.IsModeTurbo() == false` is asserted first so a silently
    -- ineffective override cannot make the real claim pass for free.
    unprobe()
    local J, _, heroes = rf.load(W_FLIP[1], W_FLIP[2])
    local hT = heroes[W_FLIP[4]]
    GAMEMODE_TURBO = 23                     -- luacheck: ignore
    GetGameMode = function() return 1 end   -- luacheck: ignore
    ss.with_candidate('fightfloor', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        local tAllies = J.GetAlliesNearLoc(hT:GetLocation(), RING)
        assert(J.GetCommitParityFighters(tAllies) == tAllies,
            'armed outside turbo dropped an ally -- this must be turbo-only')
    end, W_FLIP[3])
    unprobe()
end

tests['[fightfloor] armed on the OTHER side is the identity'] = function()
    local J, _, hT = load(W_FLIP)
    ss.with_candidate('fightfloor', function()
        local tAllies = J.GetAlliesNearLoc(hT:GetLocation(), RING)
        assert(J.GetCommitParityFighters(tAllies) == tAllies,
            'the radiant-armed leg changed a dire bot')
    end, 'radiant')
    unprobe()
end

-- ================================================ 4. direction, on real frames

tests['[fightfloor] armed can only DROP allies, never add one'] = function()
    -- The direction argument is a set inclusion, so it is checked as one: on
    -- both witnesses the armed list must be CONTAINED IN the shipped list.
    for _, w in ipairs({ W_FLIP, W_QUIET }) do
        local J, _, hT = load(w)
        local tAllies = J.GetAlliesNearLoc(hT:GetLocation(), RING) or {}
        ss.with_candidate('fightfloor', function()
            local tFighters = J.GetCommitParityFighters(tAllies) or {}
            local seen = {}
            for _, a in pairs(tAllies) do seen[a] = true end
            for _, f in pairs(tFighters) do
                assert(seen[f], w[2] .. ': the fighter list holds a hero the '
                    .. 'ally list does not -- the subset argument is false')
            end
            assert(#tFighters <= #tAllies,
                w[2] .. ': the filtered list counted more')
        end, w[3])
        unprobe()
    end
end

-- ================================================ 5. control

tests['[control] a frame with nobody below the floor is unchanged by arming'] =
function()
    local J, bot, hT = load(W_QUIET)
    local nA, nF, nE = counts(J, hT)
    assert(nA == 2 and nE == 2,
        'the control frame stopped being a 2v2: ' .. nA .. 'v' .. nE)
    assert(nF == nA, 'the control read a filtered list while disarmed')
    local bShipped = J.SafeToCommitFight(bot, hT)
    assert(bShipped == true, 'the control frame stopped being a shipped commit')
    unprobe()

    local J2, bot2, hT2 = load(W_QUIET)
    ss.with_candidate('fightfloor', function()
        local nA2, nF2 = counts(J2, hT2)
        assert(nF2 == nA2,
            'arming dropped an ally on a frame where everyone is healthy ('
            .. nF2 .. ' of ' .. nA2 .. ') -- the flip in section 2 is not the '
            .. 'floor')
        assert(J2.SafeToCommitFight(bot2, hT2) == bShipped,
            'arming changed a frame with nobody below the floor')
    end, W_QUIET[3])
    unprobe()
end

tests['[control] the two witnesses are distinct populations'] = function()
    local below = {}
    for _, w in ipairs({ W_FLIP, W_QUIET }) do
        local J, _, hT = load(w)
        local n = 0
        for _, a in pairs(J.GetAlliesNearLoc(hT:GetLocation(), RING) or {}) do
            if J.GetHP(a) < J.COMMIT_PARITY_HP_FLOOR then n = n + 1 end
        end
        below[#below + 1] = n
        unprobe()
    end
    assert(below[1] == 1 and below[2] == 0,
        'the witnesses no longer cover sub-floor counts 1 / 0, they read '
        .. table.concat(below, ', '))
end

return tests

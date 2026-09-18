-- [ratchet] [towerpow] [strategy 2026-09-18] J.WeAreStronger
-- (bots/FunLib/jmz_func.lua) ends in
-- `nOurPower > enemyPower`, and between the hero loop and that comparison it
-- adds exactly ONE structure term:
--
--   local nAllyTowers = bot:GetNearbyTowers(600, false)
--   if J.IsValidBuilding(nAllyTowers[1]) then
--       ... ourPower = ourPower + power ; ourPowerRaw = ourPowerRaw + power
--   end
--
-- There is no counterpart on the enemy side anywhere in the function. A bot
-- standing under its OWN tower is credited with the tower that shoots for it;
-- a bot standing under THEIRS is credited with nothing for the tower shooting
-- at it. One column of a two-column comparison carries structures.
--
-- READ THE HEADER OF J.GetFightPowerEnemyTowers (bots/FunLib/jmz_func.lua)
-- FIRST: the defect, why it is not 'helpring', the closed-form direction, what
-- the corpus can and cannot price, and what this lever is NOT all live there.
-- This file drives them on real frames.
--
-- ⛔ WHAT NO ASSERTION BELOW CLAIMS. The magnitude of either tower term is
-- GetAttackDamage() * GetAttackSpeed(), and a .dem slice carries neither
-- (tests/mock/bot_api.lua:136, tests/mock/replay_fixture.lua:1052). On this
-- corpus every term of J.WeAreStronger is sqrt(0), so the shipped predicate is
-- `0 > 0` = false on every frame -- already written down at
-- tests/test_creeppull_zone_clause.lua:40 ("FALSE on 966/966 frames"). So a
-- flipped `WeAreStronger` witness is UNAVAILABLE here, not rare, and is not
-- claimed. What the dump does carry is which structures stand where and on
-- whose team, so §2 drives the SELECTION -- the thing the shipped expression
-- has no way to express -- on real frames, and §4 exhausts the direction as
-- arithmetic rather than sampling it.
--
-- ⛔ THE CORPUS WALK IS NOT IN THIS FILE. It is tests/_towerpow_sweep.lua, run
-- by hand: 1039 loads is minutes and tools/agent/lua_gate.py kills an
-- unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition. Readings taken 2026-09-18 (112 fixtures / 1039 subject
-- frames, ring = the shipped 600):
--
--   own tower in ring 78 | ENEMY tower in ring 13 | both 0
--   fixtures_with_a_change 7
--
-- ⚠️ 78 vs 13 is the shape of the defect, not a fire rate: the structure term
-- fires six times as often for us as it ever could for them, because only one
-- side has one.

-- ⛔ WHY THIS FILE IS [ratchet]-TAGGED AND NOT IN tools/agent/lua_gate_manifest.json.
-- Membership in the push hook is decided by measured seconds against a
-- CUMULATIVE budget, and the binding constraint today is the 2x fallback
-- (GH #901): 2 x 268.942 = 537.884 against budget_seconds 540.0, i.e. 2.116s
-- of headroom for the whole repo.  This file measures 0.226s best-of-three on
-- this container (calibration: test_pipetower_backup_tower reads 0.274s here
-- against its recorded 0.308s, so this box runs ~0.89x and the conservative
-- manifest-equivalent is ~0.263s).  Adding the row would pass -- 538.41 <= 540
-- -- and would hand the NEXT desk 1.59s.  The manifest's own note lists tagging
-- as one of the three legitimate fixes, so this file is read by 开工自检's fast
-- Lua leg instead (138 tagged files, 0 failures, 2026-09-18).
-- ⛔ THAT IS A WEAKER GUARANTEE AND IS NOT DRESSED UP AS THE SAME ONE: the
-- push hook does NOT run this file, so a red here is found by the next desk to
-- start work, not by the person who caused it (GH #624).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_towerpow_enemy_tower_power load time')

local tests = {}

local FX = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua'

-- THE ADD WITNESS. Lich, dire, t=631.5 (10:31): a RADIANT tower 407u away and
-- no tower of its own within 600. Shipped puts nothing in either column; armed
-- puts that tower in THEIRS, which is the whole lever.
local W_ADD   = { FX, 'npc_dota_hero_lich', 'dire' }
-- THE SECOND ADD WITNESS, same frame, different subject and different distance
-- (302u): so the reading below is a property of the ring, not of one hero.
local W_ADD2  = { FX, 'npc_dota_hero_medusa', 'dire' }
-- THE FLAG WITNESS. Dragon Knight, radiant: its OWN tower 221u away and no
-- enemy tower within 600. This is the frame that separates the repair from a
-- mutant that reads `false`: shipped already credits that tower to US, and
-- armed must add NOTHING here.
local W_OWN   = { FX, 'npc_dota_hero_dragon_knight', 'radiant' }
-- THE CONTROL. Juggernaut, radiant: no tower of either team inside 600, so
-- arming is a no-op for a reason that is not the gate.
local W_QUIET = { FX, 'npc_dota_hero_juggernaut', 'radiant' }

local RING = 600

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

local JMZ = 'bots/FunLib/jmz_func.lua'

local function helper_code()
    local s = code_of(JMZ)
    local at = assert(s:find('function J.GetFightPowerEnemyTowers', 1, true),
        'J.GetFightPowerEnemyTowers is gone from jmz_func.lua -- this lever '
        .. 'went with it and so does this file')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

local function stronger_code()
    local s = code_of(JMZ)
    local at = assert(s:find('function J.WeAreStronger(', 1, true),
        'J.WeAreStronger is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[towerpow] the repair is gated, turbo-scoped, and fails to an empty list']
= function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'towerpow'%s*%)"),
        "the 'towerpow' gate is gone from J.GetFightPowerEnemyTowers")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- ⛔ The whole lever is one boolean argument, and this assertion is FIRST
    -- on purpose: a helper that read `false` would satisfy every existence
    -- check above and quietly hand OUR towers to the ENEMY column -- the
    -- mirror of the defect being repaired, and worse than it. The stand's M4
    -- drives exactly this line (tools/agent/mutstand_towerpow.sh).
    assert(not code:find('false', 1, true),
        'J.GetFightPowerEnemyTowers reads the own-team flag somewhere -- the '
        .. 'enemy column may only receive towers that shoot at us')
    local _, nTrue = code:gsub('GetNearbyTowers%(%s*nRadius%s*,%s*true%s*%)', '')
    assert(nTrue == 1, 'expected exactly one enemy-flag tower read, found '
        .. nTrue)
    assert(not code:find('600', 1, true),
        'the helper grew a radius of its own -- that number belongs to the '
        .. 'call site, where both halves of the comparison read it')
end

tests['[towerpow] the call site: ONE ring, both halves, enemy term on the '
    .. 'enemy total'] = function()
    local code = stronger_code()
    -- The anti-drift mechanism: the radius is a name, read by both halves, so
    -- the two circles cannot drift apart the way 'roamring'/'tormring' did.
    assert(code:find('local nFightTowerRing = 600', 1, true),
        'the fight-tower ring is no longer named once in J.WeAreStronger')
    local _, nOwn = code:gsub(
        'GetNearbyTowers%(nFightTowerRing, false%)', '')
    assert(nOwn == 1, 'expected exactly one own-tower read through the named '
        .. 'ring, found ' .. nOwn)
    assert(not code:find('GetNearbyTowers(600', 1, true),
        'a raw 600 tower read is back in J.WeAreStronger -- then the two '
        .. 'halves can drift apart again')
    assert(code:find(
        'J.GetFightPowerEnemyTowers( bot, nFightTowerRing )', 1, true),
        'J.WeAreStronger no longer routes its enemy-tower term through the '
        .. 'helper')
    -- ⛔ The term must land in the ENEMY column. Adding it to ourPower would
    -- pass every structural check above and INVERT the fix.
    local _, nEnemyAdd = code:gsub('enemyPower = enemyPower %+ nTowerPower', '')
    assert(nEnemyAdd == 1,
        'expected exactly one `enemyPower = enemyPower + nTowerPower`, found '
        .. nEnemyAdd)
    assert(not code:find('ourPower = ourPower + nTowerPower', 1, true)
       and not code:find('ourPowerRaw = ourPowerRaw + nTowerPower', 1, true),
        'the enemy tower power is being added to OUR column -- that is the '
        .. 'defect with an extra step')
    -- The shipped ally term must still be there: this lever adds a column, it
    -- does not move one.
    assert(code:find('ourPower = ourPower + power', 1, true)
       and code:find('ourPowerRaw = ourPowerRaw + power', 1, true),
        'the shipped ally-tower term is gone -- this lever adds the missing '
        .. 'half, it does not remove the half that exists')
end

-- ================================================ 2. real frames, no stubs

tests['[towerpow] the add witness: armed, THEIR tower enters the enemy column']
= function()
    local J, bot = load(W_ADD)
    ss.assert_clean('towerpow shipped leg')
    -- The frame is the claim, so the frame is asserted before the verdict is.
    local tEnemy = bot:GetNearbyTowers(RING, true) or {}
    local tOwn   = bot:GetNearbyTowers(RING, false) or {}
    assert(#tEnemy == 1, 'the witness enemy-tower count moved: ' .. #tEnemy)
    assert(#tOwn == 0, 'the witness grew an own tower inside 600: ' .. #tOwn)
    local nDist = GetUnitToUnitDistance(bot, tEnemy[1])
    assert(nDist > 350 and nDist < 500,
        'the enemy tower moved out of its measured 407u: ' .. nDist)
    assert(tEnemy[1]:GetTeam() ~= bot:GetTeam(),
        'the tower this lever prices is on our own team after all -- then '
        .. 'there is nothing missing from the enemy column')
    assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0,
        'disarmed the helper must hand back nothing -- that emptiness IS the '
        .. 'shipped behaviour of this call site')
    unprobe()

    local J2, bot2 = load(W_ADD)
    ss.with_candidate('towerpow', function()
        local t = J2.GetFightPowerEnemyTowers(bot2, RING)
        assert(#t == 1, 'armed, the enemy tower 407u away must reach the '
            .. 'enemy column; the helper handed back ' .. #t)
        assert(t[1]:GetTeam() ~= bot2:GetTeam(),
            'armed, the helper handed back a tower of OUR team')
        assert(J2.IsValidBuilding(t[1]),
            'armed, the helper handed back something the call site would '
            .. 'reject at its IsValidBuilding guard -- then the term is still '
            .. 'never added')
    end, W_ADD[3])
    unprobe()
end

tests['[towerpow] the same reading on a second subject and a second distance']
= function()
    local J, bot = load(W_ADD2)
    local tEnemy = bot:GetNearbyTowers(RING, true) or {}
    assert(#tEnemy == 1 and #(bot:GetNearbyTowers(RING, false) or {}) == 0,
        'the second witness no longer stands alone under their tower')
    local nDist = GetUnitToUnitDistance(bot, tEnemy[1])
    assert(nDist > 250 and nDist < 360,
        'the second witness moved out of its measured 302u: ' .. nDist)
    assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0)
    unprobe()

    local J2, bot2 = load(W_ADD2)
    ss.with_candidate('towerpow', function()
        assert(#J2.GetFightPowerEnemyTowers(bot2, RING) == 1,
            'the reading does not reproduce on a second subject -- then it is '
            .. 'a property of one hero, not of the ring')
    end, W_ADD2[3])
    unprobe()
end

tests['[towerpow] the flag witness: our OWN tower must NOT enter the enemy '
    .. 'column'] = function()
    local J, bot = load(W_OWN)
    local tOwn = bot:GetNearbyTowers(RING, false) or {}
    assert(#tOwn == 1, 'the flag witness lost its own tower: ' .. #tOwn)
    assert(#(bot:GetNearbyTowers(RING, true) or {}) == 0,
        'the flag witness grew an ENEMY tower inside 600 -- then it no longer '
        .. 'separates the two flags')
    local nDist = GetUnitToUnitDistance(bot, tOwn[1])
    assert(nDist > 170 and nDist < 280,
        'the own tower moved out of its measured 221u: ' .. nDist)
    assert(tOwn[1]:GetTeam() == bot:GetTeam(),
        'the tower the shipped ally term counts is not on our team')
    unprobe()

    local J2, bot2 = load(W_OWN)
    ss.with_candidate('towerpow', function()
        assert(#J2.GetFightPowerEnemyTowers(bot2, RING) == 0,
            'armed, OUR OWN tower 221u away was handed to the ENEMY column. '
            .. 'That is not this defect repaired, it is the mirror of it.')
    end, W_OWN[3])
    unprobe()
end

-- ================================================ 3. inertness

tests['[towerpow] disarmed, and under another armed id, the list stays empty']
= function()
    local J, bot = load(W_ADD)
    ss.assert_clean('towerpow inertness')
    assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0,
        'disarmed, the enemy column gained a tower term -- shipped play moved')
    ss.with_candidate('pipetower', function()
        assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0,
            'another armed id switched this lever on')
    end, W_ADD[3])
    unprobe()
end

tests['[towerpow] armed but NOT turbo is the shipped expression'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading because
    -- J.IsModeTurbo memoises on its FIRST call. `J.IsModeTurbo() == false` is
    -- asserted first so a silently-ineffective override cannot make the real
    -- claim pass for free.
    unprobe()
    local J, bot = rf.load(W_ADD[1], W_ADD[2])
    GAMEMODE_TURBO = 23                   -- luacheck: ignore
    GetGameMode = function() return 1 end -- luacheck: ignore
    ss.with_candidate('towerpow', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0,
            'armed outside turbo added the enemy-tower term -- this must be '
            .. 'turbo-only')
    end, W_ADD[3])
    unprobe()
end

tests['[towerpow] armed on the OTHER side is the shipped expression'] =
function()
    local J, bot = load(W_ADD)
    ss.with_candidate('towerpow', function()
        assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0,
            'the radiant-armed leg changed a dire bot')
    end, 'radiant')
    unprobe()
end

-- ================================================ 4. direction, exhausted

tests['[towerpow] direction: a non-negative addend on the RIGHT of `>` can '
    .. 'only withdraw'] = function()
    -- ⛔ Not sampled on frames: the claim is over a domain, so it is exhausted.
    -- `math.sqrt(Max(0, x))` is non-negative for every x, including the nan
    -- guard the shipped ally term already carries, so the armed enemy total is
    -- >= the shipped one and `ours > theirs` can only go TRUE -> FALSE.
    local vals = { 0, 1e-9, 0.5, 1, 2, 17, 1e6 }
    local nFlips, nGrows = 0, 0
    for _, ours in ipairs(vals) do
        for _, theirs in ipairs(vals) do
            for _, add in ipairs(vals) do
                local shipped = ours > theirs
                local armed   = ours > theirs + add
                if armed and not shipped then nGrows = nGrows + 1 end
                if shipped and not armed then nFlips = nFlips + 1 end
            end
        end
    end
    assert(nGrows == 0,
        'a non-negative enemy addend made "we are stronger" TRUE where '
        .. 'shipped said FALSE -- then the direction claim in the helper '
        .. 'header is wrong and every downstream reading of this lever is too')
    -- ⛔ A zero in the other column would satisfy the assert above by never
    -- exercising anything; this says the grid actually moved decisions.
    assert(nFlips > 0, 'the grid never flipped a single decision -- it is '
        .. 'asserting nothing')
end

-- ================================================ 5. control

tests['[control] with no tower of either team inside the ring, arming is a '
    .. 'no-op'] = function()
    local J, bot = load(W_QUIET)
    assert(#(bot:GetNearbyTowers(RING, true) or {}) == 0
           and #(bot:GetNearbyTowers(RING, false) or {}) == 0,
        'the control frame grew a tower inside 600 -- it no longer controls '
        .. 'for anything')
    assert(#J.GetFightPowerEnemyTowers(bot, RING) == 0)
    unprobe()

    local J2, bot2 = load(W_QUIET)
    ss.with_candidate('towerpow', function()
        assert(#J2.GetFightPowerEnemyTowers(bot2, RING) == 0,
            'arming added a tower on a frame with no tower in the ring -- '
            .. 'the readings above are not the tower')
    end, W_QUIET[3])
    unprobe()
end

return tests

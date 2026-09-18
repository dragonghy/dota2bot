-- [pipetower] The "protect the team" branch of the item_pipe desire
-- (bots/ability_item_usage_generic.lua) adds a tower count to OUR side of a
-- strength comparison, and the list it adds was fetched on the ENEMY side.
--
-- Shipped, verbatim (:4068-4071):
--   local nNearbyAllyTowers = bot:GetNearbyTowers( 1200, true )
--   if ( #nNearbyAllyHeroes >= 2 and #nNearbyEnemyHeroes >= 2 )
--     or ( #nNearbyEnemyHeroes >= 2 and #nNearbyAllyHeroes + #nNearbyAllyTowers >= 2 )
--
-- `bEnemies` is relative to the ANCHOR, not to the executing bot
-- (tests/test_ring_subject_census.py §2 asserts that contract against the
-- instrument), and the anchor here is `bot`.  So `true` is the ENEMY's towers:
-- the term that is supposed to say "a tower is fighting for us" says "a tower
-- is shooting at us", and the sum treats it as a second body on our side.
--
-- READ THE HEADER OF J.GetBackupTowerCount (bots/FunLib/jmz_func.lua) FIRST:
-- the defect, the direction, the domain readings and what this lever is NOT
-- all live there.  This file drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE.  It is tests/_pipetower_sweep.lua
-- and is run BY HAND: 1039 loads is minutes and tools/agent/lua_gate.py kills
-- an unmeasured new test at hook_timeout_seconds = 20.0 -- mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition.  Same reason tests/_roamring_sweep.lua sits outside.
-- Readings taken by that sweep on 2026-09-18 (112 fixtures / 1039 subject
-- frames):
--
--   LIVE  (subject actually HOLDS a pipe)  pipes 4 | up 0 | down 1
--   SHAPE (every subject frame)  etower 63 | atower 192 | decides 244
--                                up 18 | down 12 | fixtures_with_a_change 11
--
-- ⚠️ `live down 1` is the number that matters and it is ONE frame -- the
-- witness below.  A pipe is a mid-game item and this corpus is capped at
-- 10-25 game minutes (GH #184 / #291), so 4 pipe-frames is the INSTRUMENT, not
-- the rarity of the branch: the shape columns are what the branch would do on
-- the frames it will actually see.  Neither column is a fire rate.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_pipetower_backup_tower load time')

local tests = {}

local FX = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua'

-- THE LIVE WITNESS.  Lich, dire, t=631.5 (10:31), holding item_pipe in slot 2:
-- one ally (Medusa, 122u), two enemies inside 1600 (OD 396u, CM 902u), and a
-- RADIANT tower 407u away with no own tower anywhere within 4000u.  Shipped
-- reads 1 ally + 1 enemy tower = 2 and casts the pipe "保护团队".
local W_DOWN  = { FX, 'npc_dota_hero_lich', 'dire' }
-- THE OTHER DIRECTION, same frame, other side: Crystal Maiden, radiant, one
-- ally, two enemies, and her OWN tower inside 1200 -- the case the branch was
-- written for and the shipped expression cannot see.
local W_UP    = { FX, 'npc_dota_hero_crystal_maiden', 'radiant' }
-- THE CONTROL: Juggernaut, radiant, no tower of EITHER team inside 1200, so
-- the two readings are the same number and arming is a no-op for a reason that
-- is not the gate.
local W_QUIET = { FX, 'npc_dota_hero_juggernaut', 'radiant' }

local ALLY_RING, ENEMY_RING, TOWER_RING = 1200, 1600, 1200

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ONE real load.  ⛔ Never reuse a load to read the other game mode:
--- J.IsModeTurbo memoises into a module-level cache on its FIRST call, so a
--- second reading taken after flipping GetGameMode is the FIRST reading.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

--- The shipped branch condition, rebuilt from the same three producers the item
--- desire calls and the count the helper hands back -- no stubs anywhere here.
local function wants_pipe(J, bot)
    local nAlly  = #(J.GetNearbyHeroes(bot, ALLY_RING, false, BOT_MODE_NONE) or {})
    local nEnemy = #(J.GetNearbyHeroes(bot, ENEMY_RING, true, BOT_MODE_NONE) or {})
    local nTower = J.GetBackupTowerCount(bot, TOWER_RING)
    local b = (nAlly >= 2 and nEnemy >= 2)
              or (nEnemy >= 2 and nAlly + nTower >= 2)
    return b, nAlly, nEnemy, nTower
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
    local at = assert(s:find('function J.GetBackupTowerCount', 1, true),
        'J.GetBackupTowerCount is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[pipetower] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'flag'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'pipetower'%s*%)"),
        "the 'pipetower' gate is gone from J.GetBackupTowerCount")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- ⛔ The whole lever is one boolean argument, so both flags must appear
    -- exactly once each.  A helper that returned the same flag twice would pass
    -- every existence check above and be a no-op.
    local _, nTrue = code:gsub('GetNearbyTowers%(%s*nRadius%s*,%s*true%s*%)', '')
    local _, nFalse = code:gsub('GetNearbyTowers%(%s*nRadius%s*,%s*false%s*%)', '')
    assert(nTrue == 1, 'expected exactly one enemy-flag read, found ' .. nTrue)
    assert(nFalse == 1, 'expected exactly one own-flag read, found ' .. nFalse)
    assert(not code:find('1200', 1, true),
        'J.GetBackupTowerCount grew a radius of its own -- that number belongs '
        .. 'to the call site')
end

tests['[pipetower] the call site: one consumer, routed through the helper'] =
function()
    local code = code_of('bots/ability_item_usage_generic.lua')
    assert(code:find('J.GetBackupTowerCount( bot, 1200 )', 1, true),
        'the item_pipe branch no longer routes its tower term through '
        .. 'J.GetBackupTowerCount')
    -- ⛔ The defect must be gone from the call site, not merely wrapped: a
    -- leftover `bot:GetNearbyTowers( 1200, true )` next to the helper call is
    -- the shape of a fix that shipped twice and fired once.
    assert(not code:find('GetNearbyTowers( 1200, true )', 1, true),
        'a raw enemy-flag 1200 tower read is still in the file')
    local _, nUse = code:gsub('#nNearbyAllyHeroes %+ nBackupTowerCount >= 2', '')
    assert(nUse == 1,
        'expected exactly one consumer of the backup-tower count, found '
        .. nUse)
end

-- ================================================ 2. the real frame, no stubs

tests['[pipetower] the live witness: shipped casts the pipe next to THEIR '
    .. 'tower, armed does not'] = function()
    local J, bot = load(W_DOWN)
    ss.assert_clean('pipetower shipped leg')
    -- The frame is the claim, so the frame is asserted before the verdict is.
    local bPipe = false
    for i = 0, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == 'item_pipe' then bPipe = true end
    end
    assert(bPipe, 'the witness stopped carrying a pipe -- this branch cannot '
        .. 'run on a frame whose subject does not hold the item')
    local bShipped, nAlly, nEnemy, nTower = wants_pipe(J, bot)
    assert(nAlly == 1, 'the witness stopped reading 1 ally: ' .. nAlly)
    assert(nEnemy == 2, 'the witness stopped reading 2 enemies: ' .. nEnemy)
    assert(nTower == 1,
        'disarmed, the tower term must be the ONE enemy tower; it read '
        .. nTower)
    assert(bShipped == true,
        'the shipped tree no longer wants the pipe here -- the defect this '
        .. 'lever exists for is not on this frame any more')
    unprobe()

    local J2, bot2 = load(W_DOWN)
    ss.with_candidate('pipetower', function()
        local bArmed, nAlly2, nEnemy2, nTower2 = wants_pipe(J2, bot2)
        assert(nAlly2 == 1 and nEnemy2 == 2,
            'the hero counts moved under arming: ' .. nAlly2 .. '/' .. nEnemy2)
        assert(nTower2 == 0,
            'armed, the tower term must count towers that fight FOR us and '
            .. 'there are none here; it read ' .. nTower2)
        assert(bArmed == false, 'armed still wants the pipe -- it must not')
    end, W_DOWN[3])
    unprobe()
end

tests['[pipetower] the witness is the tower, not the distance'] = function()
    -- ⛔ A frame whose own tower merely sat at 1300u would make the case above
    -- pass while saying something much weaker.  Here the nearest own tower is
    -- past 4000u: there is no backup to be had at any plausible radius.
    local J, bot = load(W_DOWN)
    assert(#(bot:GetNearbyTowers(4000, false) or {}) == 0,
        'the witness grew an own tower inside 4000u')
    local tEnemy = bot:GetNearbyTowers(TOWER_RING, true) or {}
    assert(#tEnemy == 1, 'the witness enemy-tower count moved: ' .. #tEnemy)
    local nDist = GetUnitToUnitDistance(bot, tEnemy[1])
    assert(nDist > 350 and nDist < 500,
        'the enemy tower moved out of its measured 407u: ' .. nDist)
    assert(tEnemy[1]:GetTeam() ~= bot:GetTeam(),
        'the tower the shipped term counts is on our own team after all -- '
        .. 'then there is no sign error to fix')
    assert(J ~= nil)
    unprobe()
end

tests['[pipetower] the other direction, same frame: armed SEES our own tower'] =
function()
    local J, bot = load(W_UP)
    local bShipped, nAlly, nEnemy, nTower = wants_pipe(J, bot)
    assert(nAlly == 1 and nEnemy == 2,
        'the up-witness hero counts moved: ' .. nAlly .. '/' .. nEnemy)
    assert(nTower == 0,
        'disarmed the term must be 0 (no ENEMY tower near her): ' .. nTower)
    assert(bShipped == false,
        'the shipped tree already wants the pipe here -- then this frame does '
        .. 'not show the missed case')
    unprobe()

    local J2, bot2 = load(W_UP)
    ss.with_candidate('pipetower', function()
        local bArmed, _, _, nTower2 = wants_pipe(J2, bot2)
        assert(nTower2 == 1,
            'armed, her own tower inside 1200 must be counted; term read '
            .. nTower2)
        assert(bArmed == true,
            'armed does not want the pipe standing under our own tower '
            .. 'outnumbered -- that is the case the branch was written for')
    end, W_UP[3])
    unprobe()
end

-- ================================================ 3. inertness

tests['[pipetower] disarmed, the helper is the shipped expression'] = function()
    local J, bot = load(W_DOWN)
    ss.assert_clean('pipetower inertness')
    assert(J.GetBackupTowerCount(bot, TOWER_RING)
           == #(bot:GetNearbyTowers(TOWER_RING, true) or {}),
        'disarmed, the count is no longer the shipped enemy-flag read')
    -- A different armed id must not arm this one.
    ss.with_candidate('tormring', function()
        assert(J.GetBackupTowerCount(bot, TOWER_RING) == 1,
            'another armed id switched the backup-tower count over')
    end, W_DOWN[3])
    unprobe()
end

tests['[pipetower] armed but NOT turbo is the shipped expression'] = function()
    -- ⛔ The mode is flipped AFTER the load and BEFORE the first reading because
    -- J.IsModeTurbo memoises on its FIRST call.  `J.IsModeTurbo() == false` is
    -- asserted first so a silently-ineffective override cannot make the real
    -- claim pass for free.
    unprobe()
    local J, bot = rf.load(W_DOWN[1], W_DOWN[2])
    GAMEMODE_TURBO = 23                   -- luacheck: ignore
    GetGameMode = function() return 1 end -- luacheck: ignore
    ss.with_candidate('pipetower', function()
        assert(J.IsModeTurbo() == false, 'the mode override did not take')
        assert(J.GetBackupTowerCount(bot, TOWER_RING) == 1,
            'armed outside turbo changed the tower term -- this must be '
            .. 'turbo-only')
    end, W_DOWN[3])
    unprobe()
end

tests['[pipetower] armed on the OTHER side is the shipped expression'] =
function()
    local J, bot = load(W_DOWN)
    ss.with_candidate('pipetower', function()
        assert(J.GetBackupTowerCount(bot, TOWER_RING) == 1,
            'the radiant-armed leg changed a dire bot')
    end, 'radiant')
    unprobe()
end

-- ================================================ 4. control

tests['[control] with no tower of either team inside the ring, arming is a '
    .. 'no-op'] = function()
    local J, bot = load(W_QUIET)
    assert(#(bot:GetNearbyTowers(TOWER_RING, true) or {}) == 0
           and #(bot:GetNearbyTowers(TOWER_RING, false) or {}) == 0,
        'the control frame grew a tower inside 1200 -- it no longer controls '
        .. 'for anything')
    local nShipped = J.GetBackupTowerCount(bot, TOWER_RING)
    unprobe()

    local J2, bot2 = load(W_QUIET)
    ss.with_candidate('pipetower', function()
        assert(J2.GetBackupTowerCount(bot2, TOWER_RING) == nShipped,
            'arming moved the count on a frame with no tower in the ring -- '
            .. 'the flips above are not the tower')
    end, W_QUIET[3])
    unprobe()
end

tests['[control] the three witnesses are distinct populations'] = function()
    local seen = {}
    for _, w in ipairs({ W_DOWN, W_UP, W_QUIET }) do
        local _, bot = load(w)
        seen[#seen + 1] = #(bot:GetNearbyTowers(TOWER_RING, true) or {})
            .. '/' .. #(bot:GetNearbyTowers(TOWER_RING, false) or {})
        unprobe()
    end
    assert(seen[1] == '1/0' and seen[2] == '0/1' and seen[3] == '0/0',
        'the witnesses no longer cover enemy-only / own-only / neither; they '
        .. 'read ' .. table.concat(seen, ', '))
end

return tests

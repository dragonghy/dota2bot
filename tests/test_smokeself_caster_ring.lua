-- [ratchet] [smokeself] [strategy 2026-09-18] THE CASTER IS MISSING FROM ITS
-- OWN CENSUS.
--
-- X.ConsiderItemDesire['item_smoke_of_deceit'] in
-- bots/ability_item_usage_generic.lua asks "is there anyone around who would
-- break this smoke", and the shipped block answers it by walking the caster's
-- ALLIES:
--
--   local isThereEnemyNearby = false
--   local nInRangeAlly   = J.GetAllyList(bot, 1200)
--   local nInRangeEnemy  = J.GetNearbyHeroes(bot, 1200, true, BOT_MODE_NONE)
--   local nInRangeTower  = bot:GetNearbyTowers(1200, true)
--   if (#nInRangeEnemy == 0) or (#nInRangeTower == 0) then
--       for _, allyHero in pairs(nInRangeAlly) do ... isThereEnemyNearby = true
--   end
--   if not isThereEnemyNearby then ... BOT_ACTION_DESIRE_HIGH ... end
--
-- The caster's own two readings are computed with the right `bEnemies` flag and
-- then spent on the GATE of the ally scan; nothing lets them reach the answer.
-- J.GetAllyList never returns self (jmz_func.lua:9997), so the unit the smoke
-- is centred on -- `hEffectTarget = bot` -- is the one unit the predicate
-- cannot see.
--
-- READ THE HEADER OF J.IsSmokeBreakerNearSelf (bots/FunLib/jmz_func.lua) FIRST:
-- the closed-form defect, why it is an omission and not a choice, the direction
-- proof, the game rule it is measured against, and what this lever is NOT all
-- live there. This file drives them on real frames.
--
-- THE THREE WAYS IT FAILS, one real witness each, §2/§3/§4 below:
--   (A) an enemy hero AND an enemy tower inside 1200 makes the gate FALSE, so
--       the only check there is never runs;
--   (B) zero allies inside 1200 means the loop body never executes, so a SOLO
--       caster beside an enemy reads "clear";
--   (C) allies are scanned and are themselves clear, while the enemy 867u from
--       ME is further than 1200 from all of them.
--
-- ⛔ WHAT NO ASSERTION BELOW CLAIMS, AND WHY IT CANNOT. Nothing here drives the
-- item desire end to end, and on this corpus nothing could: the sixteenth world
-- assertion in tests/test_itemdesire_world_assertion.lua measures
-- `slot_castable == 0` over every alive frame and `X.ItemUsageThink` taking
-- ZERO actions on all 928 drivable frames, because the fixture loader wires
-- IsFullyCastable and only IsFullyCastable -- J.CanCastAbility's IsTrained
-- clause is false for every item handle a .dem slice can build. So an
-- end-to-end smoke witness is STRUCTURALLY unavailable here, not rare, and is
-- not claimed. What IS driven is the flag -- the one value every branch of that
-- desire hangs off -- on real frames, plus the direction as arithmetic in §6
-- rather than as a sample.
--
-- ⛔ THE CORPUS WALK IS NOT IN THIS FILE. It is tests/_smokeself_sweep.lua,
-- run by hand (1039 loads is minutes; tools/agent/lua_gate.py kills an
-- unmeasured new test at hook_timeout_seconds = 20.0, mid-`ss.arm`, which
-- leaves the global switch on disk and breaks every OTHER gate test's "gate
-- off" precondition). Readings 2026-09-18, 112 fixtures / 1039 live subject
-- frames, ring = the shipped 1200:
--
--   enemy hero within 1200 of the caster   438
--   enemy tower within 1200 of the caster   63
--   caster has at least one (armed true)   469
--   shipped flag true (the ally scan)      292
--   FLIP (shipped false, armed true)       206   over 84 of 112 fixtures
--     (A) 32 | (B) 153 | (C) 21   -- disjoint, and they sum to 206
--     19 of the 206 are TOWER-ONLY (a tower in the ring, no enemy hero)
--     nearest breaker > 1025: 33 | <= 1025: 173
--
-- ⚠️ Unlike 'towerpow', the PREDICATE is fully measurable here: every input is
-- geometry plus team membership and the dump carries both, so 206 is a count of
-- CHANGED ANSWERS. ⛔ It is not a count of changed games, and it is
-- frames-by-subject, not situations.
-- ⛔ HALF THE VALUE IS UNCERTIFIABLE AND IS REGISTERED AS UNCERTIFIABLE, NOT AS
-- ZERO: the real item cannot be USED within 1025 of an enemy hero or tower, and
-- whether IsFullyCastable() (which J.CanCastAbility calls before the desire
-- function is reached) already models that is not answerable from this
-- container. The 33 flips whose nearest breaker is beyond 1025 are the half
-- that survives the question, and they are what the lever is claimed on.
--
-- ⛔ WHY [ratchet]-TAGGED AND NOT IN tools/agent/lua_gate_manifest.json: same
-- arithmetic as tests/test_towerpow_enemy_tower_power.lua (GH #901 -- the 2x
-- fallback leaves ~2.1s for the whole repo). 开工自检's fast Lua leg reads
-- tagged files. ⛔ That is a weaker guarantee and is not dressed up as the same
-- one: the push hook does not run this file unless it has budget left, so a red
-- here can be found by the next desk rather than by the author (GH #624/#884).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_smokeself_caster_ring load time')

local tests = {}

local R = 1200   -- the shipped radius at the call site, mirrored exactly

-- (A) THE GATE SKIPS THE ONLY CHECK THERE IS. Lina, dire, t=201.3: enemy Ogre
-- Magi 882u AND an enemy tower 860u -- so `#enemy == 0 or #tower == 0` is
-- false and the ally scan never runs. Her ally Necrolyte stands 305u away and
-- reads e=1 tw=1 himself, so the scan the gate refused to run is exactly the
-- scan that would have caught it.
local W_A = { 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
              'npc_dota_hero_lina', 'dire' }
-- (B) SOLO. Luna, dire, t=235.0: Slardar 455u and Jakiro 907u inside her ring,
-- and not one ally within 1200 -- so the loop body never executes.
local W_B = { 'tests/fixtures/f_071423_sky_rescue.lua',
              'npc_dota_hero_luna', 'dire' }
-- (C) SCANNED AND STILL BLIND. Lion, radiant, t=235.0: Drow 867u from HIM,
-- his only ally inside 1200 is Lina at 649u and her own ring is empty.
local W_C = { 'tests/fixtures/f_20260909_212625_lion_235.lua',
              'npc_dota_hero_lion', 'radiant' }
-- (B-tower) THE OTHER HALF OF THE RING. Zeus, radiant, t=278.5: no enemy hero
-- inside 1200, an enemy TOWER 727u away -- well inside the 1025 at which a
-- smoke is dispelled -- and no ally within 1200. 19 of the 206 flips are
-- tower-only like this, and no other witness in this file can tell a dead
-- tower half from a live one.
local W_TOWER = { 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
                  'npc_dota_hero_zuus', 'radiant' }
-- CONTROL 1, same frame as (A): Juggernaut, radiant -- nothing of either kind
-- in his ring and no ally inside 1200, so both readings are false and arming
-- is a no-op for a reason that is not the gate.
local W_QUIET = { 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
                  'npc_dota_hero_juggernaut', 'radiant' }
-- CONTROL 2, same frame as (A): Zeus, radiant -- his OWN ring is empty but the
-- ally scan already answers true, so the flag is true either way. This is the
-- half that a "return true" mutant cannot be distinguished by.
local W_ALREADY = { 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua',
                    'npc_dota_hero_zuus', 'radiant' }

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ⛔ NOT-TURBO IS A MODE, NOT THE ABSENCE OF A PROBE. With GAMEMODE_TURBO nil
--- J.IsModeTurbo (jmz_func.lua:13786) SKIPS the authoritative branch and falls
--- through to the courier-speed heuristic, which on a .dem slice can answer
--- either way. So "outside turbo" has to be an engine that answers a DIFFERENT
--- mode id, not an engine that answers nothing -- otherwise the assertion below
--- is about the fallback, not about the scope.
local function normal_mode()
    GAMEMODE_TURBO = 23                   -- luacheck: ignore
    GetGameMode = function() return 1 end -- luacheck: ignore
end

--- ONE real load. ⛔ Never reuse a load to read the other game mode:
--- J.IsModeTurbo memoises into a module-level cache on its FIRST call.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

--- The caster's own two readings, from the same producers the call site uses.
local function self_rings(J, bot)
    return J.GetNearbyHeroes(bot, R, true, BOT_MODE_NONE) or {},
           bot:GetNearbyTowers(R, true) or {}
end

--- The SHIPPED block, rebuilt line for line -- gate included -- so that "the
--- shipped answer" in every assertion below is produced by the shipped shape
--- and not by a remembered number.
local function shipped_flag(J, bot)
    local tE, tT = self_rings(J, bot)
    local tA = J.GetAllyList(bot, R) or {}
    local bGate = (#tE == 0) or (#tT == 0)
    if bGate then
        for _, hAlly in pairs(tA) do
            if J.IsValidHero(hAlly) then
                local aE = J.GetNearbyHeroes(hAlly, R, true, BOT_MODE_NONE) or {}
                local aT = hAlly:GetNearbyTowers(R, true) or {}
                if #aE >= 1 or #aT >= 1 then return true, bGate, #tA end
            end
        end
    end
    return false, bGate, #tA
end

-- ============================================== 1. the source, pinned

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
    local at = assert(s:find('function J.IsSmokeBreakerNearSelf', 1, true),
        'J.IsSmokeBreakerNearSelf is gone from jmz_func.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

local function smoke_site_code()
    local s = code_of('bots/ability_item_usage_generic.lua')
    local at = assert(s:find("ConsiderItemDesire%['item_smoke_of_deceit'%]"),
        'the smoke-of-deceit desire is gone from ability_item_usage_generic.lua')
    local fin = assert(s:find('\nend\n', at, true))
    return s:sub(at, fin)
end

tests['[smokeself] the caster reading reaches the flag, and the shipped `false` '
    .. 'initializer is gone'] = function()
    local site = smoke_site_code()
    -- ⭐ THE SEMANTIC NAIL, FIRST: the flag is seeded from the caster's own two
    -- lists. Putting it first matters -- a mutant that only breaks the wiring
    -- must not be scored by a counting assertion that happens to fire earlier
    -- (0NEXT47/0NEXT48: a mutant that trips an earlier assertion is not testing
    -- the nail you meant).
    assert(site:find('local isThereEnemyNearby%s*=%s*J%.IsSmokeBreakerNearSelf%s*%('
        .. '%s*nInRangeEnemy%s*,%s*nInRangeTower%s*%)'),
        'the smoke flag is no longer seeded from the CASTER\'s own two lists -- '
        .. 'this lever is exactly that seeding')
    assert(not site:find('local isThereEnemyNearby%s*=%s*false'),
        'the shipped `= false` initializer came back; the caster reading is '
        .. 'dead again')
    -- ONE ring, named once, read by the caster's lists AND the ally scan.
    local _, nLit = site:gsub('1200', '')
    assert(nLit == 1, 'expected the 1200 to appear exactly once (the `local '
        .. 'nRadius = 1200`); found ' .. nLit .. ' -- a second copy is a ring '
        .. 'that can drift, which is what roamring/tormring cost')
    -- The ally scan is untouched: it is still the only OTHER writer.
    local _, nWrite = site:gsub('isThereEnemyNearby%s*=%s*true', '')
    assert(nWrite == 1, 'expected exactly one ally-scan write of '
        .. 'isThereEnemyNearby; found ' .. nWrite)
end

tests['[smokeself] the repair is gated, turbo-scoped, and fails to the shipped '
    .. 'false'] = function()
    local code = helper_code()
    assert(code:find("IsSoakCandidate%(%s*'smokeself'%s*%)"),
        "the 'smokeself' gate is gone from J.IsSmokeBreakerNearSelf")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- ⛔ It must read BOTH lists: a helper that only looked at heroes would
    -- pass every existence check above and silently drop the tower half, which
    -- is 63 of the 469 caster-present frames.
    assert(code:find('tEnemyHeroes', 1, true) and code:find('tEnemyTowers', 1, true),
        'the helper stopped reading one of its two lists')
    -- ⛔ Not a conjunction: no OTHER candidate id may appear inside it
    -- ('pullcad', GH #606/#576).
    local _, nIds = code:gsub("IsSoakCandidate%(%s*'[%w_]+'%s*%)", '')
    assert(nIds == 1, 'J.IsSmokeBreakerNearSelf now names ' .. nIds .. ' soak '
        .. 'ids -- a gate inside a gate is the conjunction of two levers')
end

-- ============================================== 2. (A) the gate skips the check

tests['[smokeself] (A) both breakers present makes the gate skip the only check '
    .. 'there is'] = function()
    local J, bot = load(W_A)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 1 and #tT >= 1,
        'witness A no longer has BOTH an enemy hero and an enemy tower inside '
        .. R .. ' (read e=' .. #tE .. ' tw=' .. #tT .. ')')
    local bShipped, bGate, nAlly = shipped_flag(J, bot)
    assert(bGate == false,
        'the shipped gate no longer skips on this frame -- case (A) is gone')
    assert(bShipped == false,
        'the shipped flag is true here; (A) is no longer a flip')
    assert(J.IsSmokeBreakerNearSelf(tE, tT) == false,
        'the helper answers armed while the gate is OFF')

    -- ⭐ THE POINT OF (A), asserted and not narrated: the scan the gate refused
    -- to run is the scan that would have caught it.
    assert(nAlly >= 1, 'witness A lost its ally; the next assertion is vacuous')
    local bWouldHave = false
    for _, hAlly in pairs(J.GetAllyList(bot, R) or {}) do
        if J.IsValidHero(hAlly) then
            local aE = J.GetNearbyHeroes(hAlly, R, true, BOT_MODE_NONE) or {}
            local aT = hAlly:GetNearbyTowers(R, true) or {}
            if #aE >= 1 or #aT >= 1 then bWouldHave = true end
        end
    end
    assert(bWouldHave,
        'the skipped ally scan would have answered false too -- (A) no longer '
        .. 'shows the gate refusing the check that would have caught it')
    unprobe()

    local J2, bot2 = load(W_A)
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == true,
            'armed, the caster still cannot see an enemy hero 882u away and an '
            .. 'enemy tower 860u away')
    end, W_A[3])
    unprobe()
end

-- ============================================== 3. (B) solo caster

tests['[smokeself] (B) a solo caster is invisible to a census taken from its '
    .. 'allies'] = function()
    local J, bot = load(W_B)
    local tE, tT = self_rings(J, bot)
    local bShipped, bGate, nAlly = shipped_flag(J, bot)
    assert(nAlly == 0, 'witness B grew an ally inside ' .. R .. '; it no longer '
        .. 'isolates the empty-loop case')
    assert(bGate == true, 'witness B no longer passes the gate')
    assert(#tE >= 2, 'witness B lost its enemies (read e=' .. #tE .. ')')
    assert(bShipped == false, 'the shipped flag is true here; (B) is not a flip')
    unprobe()

    local J2, bot2 = load(W_B)
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == true,
            'armed, a solo bot with Slardar at 455u still reads "clear"')
    end, W_B[3])
    unprobe()
end

-- ============================================== 4. (C) scanned and still blind

tests['[smokeself] (C) an ally census cannot see the enemy standing next to '
    .. 'ME'] = function()
    local J, bot = load(W_C)
    local tE, tT = self_rings(J, bot)
    local bShipped, bGate, nAlly = shipped_flag(J, bot)
    assert(nAlly >= 1, 'witness C lost its ally; it is now case (B), not (C)')
    assert(bGate == true, 'witness C no longer passes the gate')
    assert(#tE >= 1 and #tT == 0,
        'witness C changed shape (read e=' .. #tE .. ' tw=' .. #tT .. ')')
    assert(bShipped == false,
        'the ally scan now answers true here; (C) is no longer a flip')
    unprobe()

    local J2, bot2 = load(W_C)
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == true,
            'armed, an enemy 867u from the caster is still invisible because '
            .. 'the only ally in range is clear')
    end, W_C[3])
    unprobe()
end

-- ============================================== 4b. (B-tower) the other half

tests['[smokeself] (B-tower) an enemy tower inside the break radius is a '
    .. 'breaker the ally census never sees'] = function()
    local J, bot = load(W_TOWER)
    local tE, tT = self_rings(J, bot)
    assert(#tE == 0 and #tT >= 1,
        'the tower witness changed shape (read e=' .. #tE .. ' tw=' .. #tT
        .. ') -- it no longer isolates the tower half')
    local bShipped, bGate, nAlly = shipped_flag(J, bot)
    assert(bGate == true and nAlly == 0 and bShipped == false,
        'the tower witness is no longer a flip (gate=' .. tostring(bGate)
        .. ' ally=' .. nAlly .. ' shipped=' .. tostring(bShipped) .. ')')
    unprobe()

    local J2, bot2 = load(W_TOWER)
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == true,
            'armed, an enemy tower 727u away is still not a smoke breaker -- '
            .. 'the tower half of the helper is dead')
    end, W_TOWER[3])
    unprobe()
end

-- ============================================== 5. the two controls

tests['[control] an empty caster ring moves nothing, armed or not'] = function()
    local J, bot = load(W_QUIET)
    local tE, tT = self_rings(J, bot)
    assert(#tE == 0 and #tT == 0,
        'the quiet control grew something inside ' .. R .. ' -- it no longer '
        .. 'controls for anything')
    local bShipped = shipped_flag(J, bot)
    assert(bShipped == false, 'the quiet control is no longer both-false')
    unprobe()

    local J2, bot2 = load(W_QUIET)
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == false,
            'armed, the helper claims a breaker on a frame with nothing in the '
            .. 'ring -- the flips in 2-4 are not the caster reading')
    end, W_QUIET[3])
    unprobe()
end

tests['[control] where the ally scan already answers true, arming changes the '
    .. 'flag by nothing'] = function()
    local J, bot = load(W_ALREADY)
    local tE, tT = self_rings(J, bot)
    assert(#tE == 0 and #tT == 0,
        'control 2 grew something in its own ring; it no longer separates '
        .. '"already true" from "true because of me"')
    local bShipped = shipped_flag(J, bot)
    assert(bShipped == true,
        'control 2 no longer has the ally scan answering true')
    unprobe()

    local J2, bot2 = load(W_ALREADY)
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        -- The final flag is `helper(...) or <ally scan>`; the helper is false
        -- here, so the flag is true either way and the lever is a no-op on a
        -- frame where the shipped answer was already right.
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == false,
            'the helper fires on an empty caster ring')
    end, W_ALREADY[3])
    unprobe()
end

-- ============================================== 6. direction, exhausted

tests['[smokeself] direction: armed can only withhold a smoke, never add '
    .. 'one'] = function()
    local J, bot = load(W_QUIET)
    local nFlip = 0
    ss.with_candidate('smokeself', function()
        for _, nE in ipairs({ 0, 1, 2 }) do
            for _, nT in ipairs({ 0, 1 }) do
                local tE, tT = {}, {}
                for i = 1, nE do tE[i] = true end
                for i = 1, nT do tT[i] = true end
                local bArmed = J.IsSmokeBreakerNearSelf(tE, tT)
                -- the shipped initializer is the literal false, everywhere
                local bShipped = false
                assert(bArmed == (nE > 0 or nT > 0),
                    'armed answer is wrong for e=' .. nE .. ' tw=' .. nT)
                assert(not (bShipped == true and bArmed == false),
                    'armed turned a shipped TRUE into FALSE at e=' .. nE
                    .. ' tw=' .. nT .. ' -- that direction would ADD smokes')
                if bArmed ~= bShipped then nFlip = nFlip + 1 end
            end
        end
    end, W_QUIET[3])
    unprobe()
    -- ⛔ A grid that flips nothing proves nothing -- it would pass against a
    -- helper that returns false always.
    assert(nFlip == 5, 'the grid flipped ' .. nFlip .. ' of 6 cells; expected '
        .. 'the 5 with something in the ring')
    -- nil-tolerance: the call site can only hand over engine lists, but a nil
    -- must not become a crash in a shipped item-desire path.
    local J2, bot2 = load(W_QUIET)
    ss.with_candidate('smokeself', function()
        assert(J2.IsSmokeBreakerNearSelf(nil, nil) == false,
            'nil lists must read as "nothing in the ring", not error')
    end, W_QUIET[3])
    unprobe()
end

-- ============================================== 7. disarmed is the shipped false

tests['[smokeself] disarmed, wrong-sided and outside turbo it is the literal '
    .. 'shipped initializer'] = function()
    -- gate off entirely
    local J, bot = load(W_B)
    local tE, tT = self_rings(J, bot)
    assert(#tE >= 2, 'witness B lost its enemies; this check is vacuous')
    assert(J.IsSmokeBreakerNearSelf(tE, tT) == false,
        'with no candidate armed the helper is not the shipped `false`')
    unprobe()

    -- armed, but on the OTHER side: same frame, same lists, must stay false
    local J2, bot2 = load(W_B)
    local other = (W_B[3] == 'dire') and 'radiant' or 'dire'
    ss.with_candidate('smokeself', function()
        local e2, t2 = self_rings(J2, bot2)
        assert(J2.IsSmokeBreakerNearSelf(e2, t2) == false,
            'the helper fired for a bot on the NON-candidate side')
    end, other)
    unprobe()

    -- armed and right-sided, but NOT turbo: a fresh load whose first
    -- J.IsModeTurbo reading is taken against a non-turbo mode id.
    local J3, bot3 = rf.load(W_B[1], W_B[2])
    normal_mode()
    ss.with_candidate('smokeself', function()
        local e3 = J3.GetNearbyHeroes(bot3, R, true, BOT_MODE_NONE) or {}
        local t3 = bot3:GetNearbyTowers(R, true) or {}
        assert(J3.IsSmokeBreakerNearSelf(e3, t3) == false,
            'the helper fired outside turbo')
    end, W_B[3])
    unprobe()
end

return tests

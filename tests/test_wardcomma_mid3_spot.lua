-- [ratchet] [strategy 2026-09-15] Soak candidate 'wardcomma': the one missing
-- comma in bots/, and it is in a coordinate the ward mode walks to and plants on.
--
-- THE DEFECT (shipped default, bots/FunLib/aba_ward_utility.lua)
-- -------------------------------------------------------------
-- `WardLocationsBeforeAllyTowerFall__Radiant[TOWER_MID_3][3]` is written
--
--     Vector(-2414.402100 -3802.327637)
--
-- with no comma. Lua reads ONE argument -- the subtraction -- so the spot is at
-- (-6216.729737, 0) instead of (-2414.4, -3802.3): 5,377 units away, on the far
-- west edge, at y exactly zero, while the other five members of the same
-- mid-tier-3 group cluster around (-3300, -2500). It is the ONLY such literal in
-- the tree, and this file RE-RUNS that scan instead of quoting it, because
-- "there is exactly one" is the whole reason to call it a typo rather than a
-- convention. Neither automatic reader on the push path can see it: the
-- expression is valid Lua, so luacheck is silent, and the file loads, so the
-- smoke loader is too.
--
-- WHY IT IS A BEHAVIOUR FINDING. X.GetClosestObserverWardSpot is an argmin over
-- distance-to-bot, so a spot dragged 4.7k units across the map competes for the
-- pick from wherever it lands -- and where it lands is near where radiant
-- supports actually stand. The chosen spot is what mode_ward_generic tests its
-- 3200u desire gate against and what it finally passes to
-- Action_UseAbilityOnLocation, so the argmin is not a preference, it is the
-- plant.
--
-- THE LEVER ('wardcomma', turbo-only). ONE COORDINATE MOVES. No spot is added,
-- no spot is removed, no clause is relaxed, no constant is invented -- the armed
-- value is the two numbers already written on that line, read with the comma
-- they were meant to have. Resolved once, on the spot OBJECT, at the head of the
-- only two producers that read these tables.
--
-- WHAT THIS FILE CAN AND CANNOT BUY -- read before trusting a number below
-- ----------------------------------------------------------------------
-- The GEOMETRY half is real, all of it: every hero below is a real hero at its
-- real position off a real .dem frame, every position (J.GetPosition) is the
-- real one, and every distance is the real bot-to-spot distance.
--
-- The TOWER half is declared, and it is the only declared thing here. The MID_3
-- group is read only while our own mid tier-2 is down and tier-3 stands, and
-- over all 126 radiant hero-frames at position >= 4 in the corpus that state
-- occurs ZERO times -- asserted below as the debt, not described. That zero is
-- the CORPUS-COVERAGE kind, not the constructive kind (GH #838): the branch runs
-- in every game that loses a mid tier-2, which in Turbo is most of them.
--
-- ⛔ AND IT IS NOT THE "NO LATE FRAMES" WALL, which is what a reader would
-- reach for. That wall was mis-stated: the claim in circulation is that the
-- corpus tops out at t=850.1s, and 850.1s is only the maximum over
-- `tests/fixtures/f_*.lua`. Recursing into the SUBDIRECTORIES finds 125
-- fixtures and a maximum of t=1514.1s (`skillstall/f_ab6c0d_vs_banked22_1514.lua`,
-- plus two `outchan/` frames past 1349s). The corpus has late frames; what it
-- has none of is a frame whose SUBJECT's own mid tier-2 has fallen. `[limit]`
-- asserts both halves so neither statement can rot quietly, and the request for
-- such a frame is `iterations/queue.json:strategy-48`.
--
-- WHAT IS DRIVEN, not declared: the real X.GetAvailabeObserverWardSpots and the
-- real X.GetClosestObserverWardSpot of the real bots/FunLib/aba_ward_utility.lua,
-- through the real J.IsSoakCandidate reading the real bots/Customize/soak_side.lua.
-- No J.* function is stubbed anywhere in this file.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local SRC = 'bots/FunLib/aba_ward_utility.lua'

-- The two numbers on the broken line, and what Lua actually builds out of them.
local A, B = -2414.402100, -3802.327637
local BOGUS_X = A - B * -1              -- written this way so a copy-paste of
                                        -- the literal cannot be what proves it
local SHIPPED_X, SHIPPED_Y = A + B, 0.0
local FIXED_X, FIXED_Y = A, B

-- The bearing frame. Crystal Maiden, position 5, on a frame where the broken
-- spot is 760u away and the spot it was meant to be is 5,788u away -- inside
-- mode_ward_generic's 3200u desire gate versus far outside it.
local FIX  = 'f_260819_222559_od_eclipse_pair.lua'
local SUBJ = 'npc_dota_hero_crystal_maiden'

-- Every corpus frame on which the broken spot is the ARGMIN once the tower
-- state is declared -- i.e. the frames where the typo decides the plant. Found
-- by the full 126-frame walk in tests/_wardcomma_sweep.lua (124/126 list the
-- broken spot, 8 hand it the plant); re-driven here.
local ARGMIN_FRAMES = {
    { 'f_20260912_094042_sniper_546.lua',        'npc_dota_hero_warlock' },
    { 'f_212636_tide_ancient.lua',               'npc_dota_hero_zuus' },
    { 'f_260819_222559_od_eclipse_pair.lua',     'npc_dota_hero_crystal_maiden' },
    { 'f_260820_043120_viper_defend_poked.lua',  'npc_dota_hero_silencer' },
    { 'f_260820_043124_axe_blink_kill.lua',      'npc_dota_hero_skywrath_mage' },
    { 'f_260820_043140_wd_defend_token.lua',     'npc_dota_hero_lich' },
    { 'f_260902_154755_cm_wandbleed_residue.lua','npc_dota_hero_oracle' },
    { 'f_260903_101254_cm_farm_stealcamp.lua',   'npc_dota_hero_warlock' },
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Structural facts are claims about CODE, and this lever ships with a long head
--- note that names the literal, both coordinates and the gate id. Reading the
--- raw source would let the COMMENT satisfy every assertion below.
local function strip_comments(s)
    s = s:gsub('%-%-%[%[.-%]%]', ' ')
    return (s:gsub('%-%-[^\n]*', ' '))
end

local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.01) end

--- Stand a real frame up and DECLARE the one thing the dump cannot carry: our
--- own mid tier-2 has fallen and mid tier-3 still stands. Nothing else moves --
--- every other tower answers exactly what the frame's own building rows say.
--- `bDeclare == false` runs the same frame on the dump's own tower state, which
--- is what makes the debt below a reading and not an excuse.
local function stand(sFix, sSubj, bDeclare)
    -- Drop any override a previous case installed BEFORE the world is rebuilt,
    -- and refuse to continue if the mock stops supplying its own. A stale
    -- override would make the debt case below read the declared state and go
    -- green for the wrong reason -- the one direction this file must not fail in.
    _G.GetTower = nil                                        -- luacheck: ignore
    local J, bot = rf.load('tests/fixtures/' .. sFix, sSubj)
    assert(type(GetTower) == 'function', 'mock.replay_fixture no longer supplies '
        .. 'GetTower; every tower reading in this file would be a stub')
    local W = dofile(SRC)
    if bDeclare then
        local shipped = GetTower
        local myTeam = bot:GetTeam()
        _G.GetTower = function(team, i)                      -- luacheck: ignore
            if team == myTeam and i == TOWER_MID_2 then return nil end
            if team == myTeam and i == TOWER_MID_3 then
                -- Any standing allied tower object will do: the branch only ever
                -- asks this one for `~= nil`.
                return shipped(team, TOWER_MID_3) or shipped(team, TOWER_MID_1)
                    or shipped(team, TOWER_TOP_1)
            end
            return shipped(team, i)
        end
    end
    return J, bot, W
end

local function spot_list(W, bot)
    local t = W.GetAvailabeObserverWardSpots(bot)
    local n = 0
    local bHasBroken, bHasFixed = false, false
    for _, s in pairs(t) do
        n = n + 1
        if near(s.location[1], SHIPPED_X) and near(s.location[2], SHIPPED_Y) then bHasBroken = true end
        if near(s.location[1], FIXED_X) and near(s.location[2], FIXED_Y) then bHasFixed = true end
    end
    return t, n, bHasBroken, bHasFixed
end

-- ==========================================================================
-- SOURCE. The typo is a fact about the tree, and the tree is re-scanned.
-- ==========================================================================

tests['[source] exactly one missing-comma Vector literal exists in bots/']
= function()
    -- The clause is NOT decoration. bots/Customize/soak_side.lua is gitignored
    -- and exists only on the farm, so a walk without it counts a DIFFERENT
    -- population there than here -- and this case's whole claim is "exactly
    -- one". Read from lua_source_scan so there is one copy of the literal.
    local p = assert(io.popen("find bots -name '*.lua' "
        .. require('lua_source_scan').FARM_ONLY_FIND_CLAUSE .. " -print"))
    local nHits, sWhere = 0, nil
    for path in p:lines() do
        local code = strip_comments(read_file(path))
        for a, b in code:gmatch('Vector%(%s*(%-?[%d%.]+)%s+(%-[%d%.]+)%s*%)') do
            nHits = nHits + 1
            sWhere = path .. '  (' .. a .. ' ' .. b .. ')'
        end
    end
    p:close()
    assert(nHits == 1, 'bots/ now holds ' .. nHits .. ' Vector literals with a '
        .. 'missing comma, not 1. If it grew, the new one needs the same '
        .. 'treatment; if it shrank to 0 the shipped default was changed '
        .. 'UNGATED and this lever is dead. Last seen: ' .. tostring(sWhere))
    assert(sWhere ~= nil and sWhere:find('aba_ward_utility', 1, true),
        'the one missing-comma literal moved out of the ward table: ' .. tostring(sWhere))
end

tests['[source] the shipped constant still evaluates to the corrupted point']
= function()
    assert(near(A - 3802.327637, SHIPPED_X),
        'arithmetic drifted: the literal no longer evaluates to ' .. SHIPPED_X)
    assert(near(BOGUS_X, SHIPPED_X),
        'the guard against proving this by copy-paste is itself broken')
    -- 4,723 units, and y exactly zero -- the two tells that make it a typo.
    local dx, dy = SHIPPED_X - FIXED_X, SHIPPED_Y - FIXED_Y
    local d = math.sqrt(dx * dx + dy * dy)
    assert(math.abs(d - 5377.3) < 1.0, string.format(
        'the displacement is now %.1fu, not 5377.3', d))
    assert(SHIPPED_Y == 0.0, 'the corrupted y is no longer exactly 0')
end

tests['[source] the gate is turbo-only, single-id, and names no other id']
= function()
    local code = strip_comments(read_file(SRC))
    local at = code:find('function X.ApplyWardCommaFix', 1, true)
    assert(at ~= nil, 'X.ApplyWardCommaFix is gone from ' .. SRC)
    local body = code:sub(at, (code:find('\nfunction ', at + 10) or #code))

    local nIds = 0
    for _ in body:gmatch('IsSoakCandidate') do nIds = nIds + 1 end
    assert(nIds == 1, 'the resolver now names ' .. nIds .. ' candidate ids. Two '
        .. "ids in one condition is the 'pullcad' trap: promoting either freezes "
        .. 'this gate FALSE forever (AGENTS.md).')
    assert(body:find("IsSoakCandidate('wardcomma')", 1, true), 'the id changed')

    local atTurbo = body:find('IsModeTurbo()', 1, true)
    local atGate = body:find("IsSoakCandidate('wardcomma')", 1, true)
    assert(atTurbo ~= nil and atTurbo < atGate,
        'J.IsModeTurbo() must stand BEFORE the candidate read, so a non-turbo '
        .. 'game never reaches the switch file at all')
end

tests['[source] the resolver is called by both producers and nobody else']
= function()
    local code = strip_comments(read_file(SRC))
    -- The definition line matches the same needle, so it is excluded by name
    -- rather than by an off-by-one that the next reader has to re-derive.
    local nDefs, nAll = 0, 0
    for _ in code:gmatch('function%s+X%.ApplyWardCommaFix%(%)') do nDefs = nDefs + 1 end
    for _ in code:gmatch('X%.ApplyWardCommaFix%(%)') do nAll = nAll + 1 end
    assert(nDefs == 1, 'X.ApplyWardCommaFix is defined ' .. nDefs .. ' times')
    local nCalls = nAll - nDefs
    assert(nCalls == 2, 'X.ApplyWardCommaFix() is called ' .. nCalls
        .. ' times, not 2. The point of one resolver is that the observer path '
        .. 'and the sentry path cannot drift apart; a third caller means a third '
        .. 'reader exists, and a first means one of the two stopped asking.')
    for _, fn in ipairs({ 'X.GetAvailabeObserverWardSpots', 'X.GetPossibleSentryWardSpots' }) do
        local at = assert(code:find('function ' .. fn, 1, true), fn .. ' is gone')
        local head = code:sub(at, at + 400)
        assert(head:find('X%.ApplyWardCommaFix%(%)'),
            fn .. ' no longer resolves the gate before it reads the tables')
    end
end

-- ==========================================================================
-- WORLD. The bearing frame is asserted, never described.
-- ==========================================================================

tests['[world] the bearing frame is a real radiant support the ward mode admits']
= function()
    local J, bot = stand(FIX, SUBJ, true)
    assert(bot:GetTeam() == TEAM_RADIANT, 'the subject changed sides; this lever '
        .. 'lives in the __Radiant table and has no domain on dire')
    local pos = J.GetPosition(bot)
    assert(pos ~= nil and pos >= 4, 'the subject reads position ' .. tostring(pos)
        .. "; mode_ward_generic's own first line returns false for <= 3, so this "
        .. 'frame would never reach the ward path')
end

tests['[world] on that frame the typo is 760u away and the real spot 5788u']
= function()
    local _, bot = stand(FIX, SUBJ, true)
    local dBroken = GetUnitToLocationDistance(bot, Vector(SHIPPED_X, SHIPPED_Y, 0))
    local dFixed  = GetUnitToLocationDistance(bot, Vector(FIXED_X, FIXED_Y, 0))
    assert(math.abs(dBroken - 760) < 5, string.format(
        'the frame moved: the broken spot used to be 760u away, now %.0f', dBroken))
    assert(math.abs(dFixed - 5788) < 5, string.format(
        'the frame moved: the intended spot used to be 5788u away, now %.0f', dFixed))
    -- The 3200u gate in mode_ward_generic's observer branch. The typo is what
    -- puts the mode in range of anything here at all.
    assert(dBroken <= 3200 and dFixed > 3200, 'the frame no longer straddles the '
        .. "3200u desire gate, which is the whole reason it is the bearing frame")
end

tests['[world] ⭐ unarmed the bot plants on the typo; armed it plants on a real spot']
= function()
    local vUnarmed, nUnarmed
    ss.with_candidate(nil, function()
        local _, bot, W = stand(FIX, SUBJ, true)
        local spots, n, bBroken = spot_list(W, bot)
        nUnarmed = n
        assert(bBroken, 'the broken spot is not even in the unarmed list; the '
            .. 'declared tower state stopped reaching the MID_3 group')
        vUnarmed = W.GetClosestObserverWardSpot(bot, spots).location
        assert(near(vUnarmed[1], SHIPPED_X) and near(vUnarmed[2], SHIPPED_Y),
            string.format('the shipped argmin is now (%.1f, %.1f); this frame no '
                .. 'longer demonstrates the defect', vUnarmed[1], vUnarmed[2]))
    end)

    ss.with_candidate('wardcomma', function()
        local _, bot, W = stand(FIX, SUBJ, true)
        local spots, n, bBroken, bFixed = spot_list(W, bot)
        assert(not bBroken, 'the corrupted point survived arming')
        assert(bFixed, 'the corrected point is not in the armed list')
        assert(n == nUnarmed, 'armed changed the list SIZE (' .. nUnarmed .. ' -> '
            .. n .. '). This lever moves one coordinate; the only way it may '
            .. 'change the count is IsLocationPassable refusing the corrected '
            .. 'point, and that has to be read, not assumed.')
        local v = W.GetClosestObserverWardSpot(bot, spots).location
        assert(not (near(v[1], SHIPPED_X) and near(v[2], SHIPPED_Y)),
            'armed still picks the corrupted point')
        assert(near(v[1], -4334.572266) and near(v[2], -1036.464844), string.format(
            'armed now picks (%.1f, %.1f); it used to pick the mid-tier-3 spot '
            .. 'at (-4334.6, -1036.5)', v[1], v[2]))
    end, 'radiant')
end

tests['[world] the same frame, unarmed, is byte-identical to no gate file at all']
= function()
    ss.with_candidate(nil, function()
        local _, bot, W = stand(FIX, SUBJ, true)
        local _, n, bBroken, bFixed = spot_list(W, bot)
        assert(bBroken and not bFixed, 'the unarmed list moved')
        assert(n == 18, 'the unarmed list is now ' .. n .. ' spots, not 18')
    end)
end

-- ==========================================================================
-- DOMAIN. Every zero below is driven in both directions.
-- ==========================================================================

tests['[domain] ⭐ the typo is the argmin on 8 real frames once the tower falls']
= function()
    local nArgmin, nListed = 0, 0
    for _, row in ipairs(ARGMIN_FRAMES) do
        local _, bot, W = stand(row[1], row[2], true)
        local spots, _, bBroken = spot_list(W, bot)
        if bBroken then nListed = nListed + 1 end
        local best = W.GetClosestObserverWardSpot(bot, spots)
        if best ~= nil and near(best.location[1], SHIPPED_X)
            and near(best.location[2], SHIPPED_Y) then
            nArgmin = nArgmin + 1
        end
    end
    assert(nListed == #ARGMIN_FRAMES, 'the broken spot reaches only ' .. nListed
        .. '/' .. #ARGMIN_FRAMES .. ' of these lists')
    assert(nArgmin == #ARGMIN_FRAMES, 'the broken spot is the argmin on only '
        .. nArgmin .. '/' .. #ARGMIN_FRAMES .. ' of the frames it used to decide. '
        .. 'Re-run tests/_wardcomma_sweep.lua and re-pick the list.')
end

tests['[domain] ⭐ the same eight frames, armed, hand the plant to a real spot']
= function()
    ss.with_candidate('wardcomma', function()
        local nBroken = 0
        for _, row in ipairs(ARGMIN_FRAMES) do
            local _, bot, W = stand(row[1], row[2], true)
            local spots = spot_list(W, bot)
            local best = W.GetClosestObserverWardSpot(bot, spots)
            if best ~= nil and near(best.location[1], SHIPPED_X)
                and near(best.location[2], SHIPPED_Y) then
                nBroken = nBroken + 1
            end
        end
        assert(nBroken == 0, nBroken .. ' of the eight frames still plant on the '
            .. 'corrupted point with the gate armed')
    end, 'radiant')
end

tests['[domain] ⛔ THE DEBT: on the dump\'s own tower state that domain is zero']
= function()
    local nReached = 0
    for _, row in ipairs(ARGMIN_FRAMES) do
        local _, bot, W = stand(row[1], row[2], false)
        local _, _, bBroken = spot_list(W, bot)
        if bBroken then nReached = nReached + 1 end
    end
    assert(nReached == 0, nReached .. ' of these frames NOW reach the MID_3 group '
        .. 'without declaring the tower state. That is good news, not a failure: '
        .. 'the corpus has grown a post-mid-tier-2 frame, so the declaration in '
        .. '`stand()` can retire and this lever can be priced on shipped state. '
        .. 'Re-read the header before quoting any number in it.')
end

tests['[limit] ⛔ late frames DO exist; the missing thing is a fallen mid tier-2']
= function()
    -- Half one: the "no late frames" claim, re-measured, RECURSIVELY. The 850.1s
    -- in circulation is the maximum over the top directory only.
    local function scan(sFind)
        local p = assert(io.popen(sFind))
        local tMax, nFix = -math.huge, 0
        for path in p:lines() do
            local fx = dofile(path)
            if type(fx) == 'table' and type(fx.time) == 'number' then
                nFix = nFix + 1
                if fx.time > tMax then tMax = fx.time end
            end
        end
        p:close()
        return nFix, tMax
    end
    local nFlat, tFlat = scan("find tests/fixtures -maxdepth 1 -name 'f_*.lua' -print")
    local nAll,  tAll  = scan("find tests/fixtures -name 'f_*.lua' -print")

    assert(nAll > nFlat, 'the subdirectory fixtures are gone; the recursion this '
        .. 'case exists to demonstrate no longer finds anything (' .. nFlat
        .. ' flat, ' .. nAll .. ' total)')
    assert(math.abs(tFlat - 850.1) < 1.0, string.format(
        'the TOP-DIRECTORY maximum is now %.1fs, not 850.1s -- the number the '
        .. '"no late frames" claim was built on has moved', tFlat))
    assert(tAll > 1400, string.format('the recursive maximum fell to %.1fs. It '
        .. 'was 1514.1s; the corpus lost its late frames.', tAll))
end

tests['[limit] ⛔ THE DEBT, stated as the thing actually missing'] = function()
    -- Half two: what the corpus really has none of. Driven over the same eight
    -- frames the domain cases use, on the dump's own tower state.
    local nDown = 0
    for _, row in ipairs(ARGMIN_FRAMES) do
        local _, bot = stand(row[1], row[2], false)
        if GetTower(bot:GetTeam(), TOWER_MID_2) == nil then nDown = nDown + 1 end
    end
    assert(nDown == 0, nDown .. ' of these frames NOW carry a fallen own-side mid '
        .. 'tier-2. That is the frame `queue.json:strategy-48` asked for: the '
        .. 'declaration in `stand()` was only ever a stand-in for one and should '
        .. 'now retire, and this lever can be priced on shipped tower state.')
end

return tests

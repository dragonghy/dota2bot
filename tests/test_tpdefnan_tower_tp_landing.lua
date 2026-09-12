-- [tpdefnan 20260912] THE DEFENCE TP WHOSE CAST POINT IS NOT A COORDINATE.
--
-- GH #539. `midtp` and `suptp` share one wiring in
-- bots/ability_item_usage_generic.lua (J.ShouldTpSupportTowerFight -> the TP
-- cast point), and that wiring used to read:
--
--     local vTpLoc = J.GetNearbyLocationToTp( hTowerFight:GetLocation() )
--
-- J.GetNearbyLocationToTp answers "575u from the nearest allied tower, TOWARD
-- nLoc". It has nine call sites in bots/; eight pass an ally / laneFront /
-- Roshan / Tormentor / team-fight point / target, so the tower it picks and nLoc
-- are distinct places and the direction is defined. THIS one passes a tower's
-- own location, and then the nearest allied tower to it is ITSELF: minDist == 0,
-- the watch-tower branch needs `< minDist - 1300` and becomes unsatisfiable, and
-- the return is
--     J.GetLocationTowardDistanceLocation( tower, tower:GetLocation(), 575 )
--   = towerLoc + 575 * ( towerLoc - towerLoc ) / 0
--   = Vector(-nan, -nan, -nan).
-- `vTpLoc ~= nil` is TRUE for that vector, so it reaches
-- Action_UseAbilityOnLocation with no nil / NaN / bounds check anywhere on the
-- path. Neither id could deliver the behaviour it wrote down, whichever end the
-- engine takes: benign (the action is rejected -> both ids are inert while the
-- item-decision loop still returns nSlot + 1 and eats that frame's item
-- decision) or malign (the TP lands somewhere undefined).
--
-- WHAT LANDED, AND WHY IT NEEDS NO NEW GATE ID. A new helper,
-- J.GetTowerDefenseTpLocation( hTower ), answers the same question for a
-- BUILDING: the same shipped 575, taken toward OUR OWN fountain, i.e. behind the
-- tower being defended rather than ahead of it among the heroes diving it
-- (standard defensive-TP play -- verification philosophy condition (c)). The one
-- call site is inside `if hTowerFight ~= nil`, and J.ShouldTpSupportTowerFight
-- returns nil on its second and third lines unless turbo AND 'midtp'/'suptp' is
-- armed. So the repair INHERITS those gates. Section 5 pins that ordering,
-- because a nested J.IsSoakCandidate here would read `(midtp or suptp) AND
-- <new>` and a wave arming <new> alone would measure a structurally impossible 0
-- that check_armed_wiring.py still calls WIRED (GH #606, test_set.md 0OVERCHASE
-- -- the constraint the previous round wrote down for whoever landed next).
--
-- AND WHY THE CUT IS HERE RATHER THAN INSIDE J.GetNearbyLocationToTp. Repairing
-- the shared function would reach all nine call sites at once; exactly one of
-- them can produce the degenerate input, and that one is already dark. Section 6
-- asserts the shared function is untouched, so "the other eight are unaffected"
-- is a read of the tree and not a promise in prose.
--
-- ⚠️ WHAT THIS FILE DOES NOT CLAIM. Not that the TP is a good idea (that is what
-- the two ids are for, and both are OUT of the test set), not a hit rate, and
-- nothing at all about the engine end: there is no bot-side debugging, so
-- "Action_UseAbilityOnLocation with a NaN" is read here only as "the value the
-- shipped bytes hand it", never as an observed engine behaviour.
--
-- ⚠️ ONE MEASUREMENT TRAP, INHERITED FROM THE PREVIOUS ROUND AT THIS SITE AND
-- AVOIDED RATHER THAN RE-PAID: J.ShouldTpSupportTowerFight's last conjunct is
-- J.TryTakeTpResponseSlot(), which CONSUMES the team's TP quota. Two heroes
-- driven off one loaded frame therefore give the second one a 0 that looks like
-- a veto. Section 4 calls the host exactly ONCE per loaded fixture, on that
-- fixture's own subject, so the quota is asked once and never re-read.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'
local AIU = 'bots/ability_item_usage_generic.lua'

-- The shipped constants, quoted rather than re-chosen.
local OFFSET       = 575    -- J.GetNearbyLocationToTp's own offset
local FOUNTAIN_OUT = 2500   -- its `<= 2500 -> return nLoc` early return

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed: this change's own comments quote the
--- expressions the structural sections look for, so an unstripped read would
--- let a COMMENT satisfy them.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local JMZ_SRC = stripped(read_file(JMZ))
local AIU_SRC = stripped(read_file(AIU))

local function finite(v)
    if v == nil or v.x == nil then return false end
    for _, n in ipairs({ v.x, v.y, v.z or 0 }) do
        -- n ~= n is the NaN test; math.huge catches the +-inf side.
        if n ~= n or n == math.huge or n == -math.huge then return false end
    end
    return true
end

local function dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'),
            'could not list ' .. dir)
        for line in p:lines() do
            if line:sub(-4) == '.lua' then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    assert(#out > 100, 'expected the frame corpus, got ' .. #out)
    return out
end

local PATHS = corpus_paths()

local function allied_towers(J)
    local out = {}
    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
        if J.IsValidBuilding(b)
            and string.find(b:GetUnitName(), 'tower') ~= nil
        then
            out[#out + 1] = b
        end
    end
    return out
end

--- Is this tower one of the GetTower(team, 0..10) slots, at distance 0 from
--- itself? That -- not "is it a tower" -- is the exact precondition for
--- J.GetNearbyLocationToTp's minDist to reach 0, and section 2 asserts the
--- equivalence instead of assuming it.
local function in_tower_slots(tower)
    local vT = tower:GetLocation()
    for i = 0, 10 do
        local t = GetTower(GetTeam(), i)
        if t ~= nil and dist2(t:GetLocation(), vT) == 0 then return true end
    end
    return false
end

-- ------------------------------------------------- 1. the meter, first ---

tests['[tpdefnan] 1. the meter can see a NaN at all'] = function()
    -- ⭐ If the mock's Vector arithmetic quietly answered 0 for 0/0, every
    -- reading below would be vacuously green while the shipped defect stood.
    -- So prove the instrument first, on the repo's own Vector, with the exact
    -- shape the shipped call produces.
    local towers, J = nil, nil
    for _, path in ipairs(PATHS) do
        local ok, mod = pcall(rf.load, path)
        if ok and mod ~= nil then
            local t = allied_towers(mod)
            if #t > 0 then
                towers, J = t, mod
                break
            end
        end
    end
    assert(towers ~= nil, 'no fixture in the corpus carries an allied tower; '
        .. 'this file needs real buildings, not hero-only frames')

    local t = towers[1]
    local degenerate = J.GetLocationTowardDistanceLocation(t, t:GetLocation(), OFFSET)
    assert(not finite(degenerate),
        'J.GetLocationTowardDistanceLocation( u, u:GetLocation(), 575 ) came '
        .. 'back FINITE (' .. tostring(degenerate.x) .. '). Either the shared '
        .. 'helper grew a zero-distance branch -- in which case this whole file '
        .. 'is about a defect that no longer exists, re-read GH #539 before '
        .. 'deleting anything -- or the Vector mock stopped dividing by zero, '
        .. 'in which case nothing below measures the shipped tree.')

    -- And the opposite pole: a non-degenerate direction is finite, so `finite`
    -- is not simply answering false to everything.
    local sane = J.GetLocationTowardDistanceLocation(t, J.GetTeamFountain(), OFFSET)
    assert(finite(sane), 'a well-posed direction came back non-finite; the '
        .. 'finiteness test itself is broken')
end

-- ------------------------------- 2. the defect, on the real frame corpus ---

local CENSUS = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end

    for _, path in ipairs(PATHS) do
        local ok, J = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames')
            -- ⚠️ The loader binds UNIT_LIST_ALLIED_BUILDINGS to the LOADED
            -- subject's team at load time, so everything below is read for that
            -- team only and never for a hero driven from the other side.
            for _, tower in ipairs(allied_towers(J)) do
                bump('tower')
                local vT = tower:GetLocation()
                local far = dist2(vT, J.GetTeamFountain()) > FOUNTAIN_OUT
                if far then bump('tower_far') else bump('tower_base') end

                local okShip, shipped = pcall(J.GetNearbyLocationToTp, vT)
                if not okShip then
                    bump('shipped_error')
                else
                    local slotted = in_tower_slots(tower)
                    if slotted then bump('slotted') end
                    if not finite(shipped) then
                        bump('shipped_nan')
                        if not (far and slotted) then bump('NAN_UNEXPLAINED') end
                    elseif far and slotted then
                        bump('NAN_MISSING')
                    end
                end

                local okFix, fixed = pcall(J.GetTowerDefenseTpLocation, tower)
                if not okFix then
                    bump('fixed_error')
                elseif not finite(fixed) then
                    bump('FIXED_NAN')
                else
                    bump('fixed_finite')
                    if math.abs(dist2(fixed, vT) - OFFSET) > 1e-6 then
                        bump('FIXED_OFFSET_WRONG')
                    end
                    if dist2(fixed, J.GetTeamFountain())
                        >= dist2(vT, J.GetTeamFountain())
                    then
                        bump('FIXED_WRONG_SIDE')
                    end
                end
            end
        end
    end
    return c
end)()

-- One line each, to stderr, so the numbers a report quotes come out of the run
-- that made them rather than out of a second script that re-derives them (and
-- can drift from this one). Same convention as the tests/_*_sweep.lua files.
io.stderr:write(string.format(
    '[tpdefnan] census frames=%d towers=%d far=%d base=%d slotted=%d '
    .. 'shipped_nan=%d nan_unexplained=%d nan_missing=%d fixed_finite=%d '
    .. 'offset_wrong=%d wrong_side=%d load_fail=%d\n',
    CENSUS.frames, CENSUS.tower, CENSUS.tower_far, CENSUS.tower_base,
    CENSUS.slotted, CENSUS.shipped_nan, CENSUS.NAN_UNEXPLAINED,
    CENSUS.NAN_MISSING, CENSUS.fixed_finite, CENSUS.FIXED_OFFSET_WRONG,
    CENSUS.FIXED_WRONG_SIDE, CENSUS.load_fail))

tests['[tpdefnan] 2. the defect is real on real frames, and exactly where predicted'] = function()
    assert(CENSUS.frames > 100, 'only ' .. CENSUS.frames .. ' frames loaded')
    assert(CENSUS.tower > 0, 'the corpus carried no allied tower at all')
    assert(CENSUS.shipped_error == 0,
        CENSUS.shipped_error .. ' calls into J.GetNearbyLocationToTp raised')

    -- The headline: the shipped wiring's input really does come back as a
    -- non-coordinate, on ordinary frames, not in a constructed scenario.
    assert(CENSUS.shipped_nan > 0,
        'no tower location in the corpus made J.GetNearbyLocationToTp answer '
        .. 'NaN. That is the premise of GH #539; if it is gone, the repair '
        .. 'landed with this file is unmotivated -- find out why before '
        .. 'deleting it.')

    -- ⭐ AND THE PART THAT IS AN ASSERTION RATHER THAN A HEADLINE NUMBER: the
    -- NaN is not "sometimes". It is exactly `nLoc is farther than 2500 from our
    -- fountain` AND `nLoc coincides with a GetTower slot` -- the two conditions
    -- read off the shipped body. Both directions are checked, so a future
    -- change that moves the boundary shows up here as a mismatch instead of as
    -- a quietly smaller count.
    assert(CENSUS.NAN_UNEXPLAINED == 0,
        CENSUS.NAN_UNEXPLAINED .. ' towers answered NaN without being both far '
        .. 'from the fountain and a GetTower slot; the mechanism in the header '
        .. 'is not the whole mechanism')
    assert(CENSUS.NAN_MISSING == 0,
        CENSUS.NAN_MISSING .. ' towers were far + slotted yet answered a finite '
        .. 'vector; the mechanism in the header over-predicts')
end

tests['[tpdefnan] 3. the repair is a coordinate, at 575, on our side'] = function()
    assert(CENSUS.fixed_error == 0,
        CENSUS.fixed_error .. ' calls into J.GetTowerDefenseTpLocation raised')
    assert(CENSUS.fixed_finite == CENSUS.tower,
        'J.GetTowerDefenseTpLocation answered a coordinate for only '
        .. CENSUS.fixed_finite .. ' of ' .. CENSUS.tower .. ' allied towers ('
        .. CENSUS.FIXED_NAN .. ' non-finite)')
    assert(CENSUS.FIXED_OFFSET_WRONG == 0,
        CENSUS.FIXED_OFFSET_WRONG .. ' landing points were not 575u from their '
        .. 'tower; the shipped constant was not preserved')
    -- "Behind the tower" is the whole design claim, so it is measured on every
    -- tower rather than argued once in a comment.
    assert(CENSUS.FIXED_WRONG_SIDE == 0,
        CENSUS.FIXED_WRONG_SIDE .. ' landing points were no closer to our own '
        .. 'fountain than the tower is, i.e. the defender would arrive in FRONT '
        .. 'of the building he came to defend')
end

-- --------------------------- 4. end to end, through the real armed host ---

local E2E = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end

    for _, path in ipairs(PATHS) do
        local ok, J, subject = pcall(rf.load, path)
        if ok and J ~= nil and subject ~= nil then
            bump('frames')
            local realSoak, realTurbo = J.IsSoakCandidate, J.IsModeTurbo
            J.IsSoakCandidate = function(sId) return sId == 'midtp' end
            J.IsModeTurbo = function() return true end

            -- ⚠️ EXACTLY ONE CALL PER LOADED FRAME (see the header trap): the
            -- host's last conjunct consumes the team's TP response slot.
            local okHost, hTower = pcall(J.ShouldTpSupportTowerFight, subject)
            if not okHost then
                bump('host_error')
            elseif hTower ~= nil then
                bump('witness')
                c.witnesses = (c.witnesses == 0 and '' or c.witnesses .. ' ')
                    .. path .. '/' .. subject:GetUnitName()
                local okA, shipped = pcall(J.GetNearbyLocationToTp, hTower:GetLocation())
                local okB, fixed = pcall(J.GetTowerDefenseTpLocation, hTower)
                if okA and not finite(shipped) then bump('witness_was_nan') end
                if okB and finite(fixed) then bump('witness_now_finite') end
            end

            J.IsSoakCandidate, J.IsModeTurbo = realSoak, realTurbo
        end
    end
    return c
end)()

io.stderr:write(string.format(
    '[tpdefnan] e2e frames=%d host_error=%d witness=%d was_nan=%d now_finite=%d [%s]\n',
    E2E.frames, E2E.host_error, E2E.witness, E2E.witness_was_nan,
    E2E.witness_now_finite, tostring(E2E.witnesses)))

tests['[tpdefnan] 4. the armed host, driven, hands the repair a tower'] = function()
    assert(E2E.host_error == 0,
        E2E.host_error .. ' calls into the armed J.ShouldTpSupportTowerFight raised')

    -- ⛔ THE HONEST BOUND, WRITTEN BEFORE THE NUMBER. This corpus was frozen for
    -- other candidates; the host demands level >= 6, a castable TP, no team
    -- fight, no ongoing commit, a far enough tower with enemies at it and a free
    -- team TP slot. A round where it fires on zero frames is a statement about
    -- the corpus, not about the repair -- and sections 2 and 3 stand on their
    -- own either way, because they read the shipped producer directly.
    if E2E.witness == 0 then
        return  -- nothing to assert; the count is registered in the report
    end

    -- Where it DOES fire, both halves must hold on the same frame: this is the
    -- only place in the file where "the shipped wiring was broken" and "the
    -- landed wiring is not" are read off ONE decision instant.
    assert(E2E.witness_was_nan == E2E.witness,
        'the armed host produced ' .. E2E.witness .. ' towers but only '
        .. E2E.witness_was_nan .. ' of them fed the shipped helper a NaN. The '
        .. 'defect is narrower than the header says -- re-read before trusting '
        .. 'section 2.')
    assert(E2E.witness_now_finite == E2E.witness,
        'only ' .. E2E.witness_now_finite .. ' of ' .. E2E.witness
        .. ' armed decisions got a coordinate from the repair')
end

-- ------------------------------------- 5. shipped play is untouched ---

tests['[tpdefnan] 5. the repair inherits midtp/suptp and adds no gate'] = function()
    local s = JMZ_SRC:find('function J.ShouldTpSupportTowerFight( bot )', 1, true)
    assert(s ~= nil, 'J.ShouldTpSupportTowerFight is gone from ' .. JMZ)
    local host = JMZ_SRC:sub(s, (JMZ_SRC:find('\nend', s, true) or #JMZ_SRC) + 3)

    local iTurbo = host:find('if not J.IsModeTurbo() then return nil end', 1, true)
    local iGate  = host:find("if not ( J.IsSoakCandidate( 'midtp' ) or bSup ) then return nil end", 1, true)
    assert(iTurbo ~= nil and iGate ~= nil and iTurbo < iGate,
        'the host no longer opens with the turbo + midtp/suptp early returns, '
        .. 'so the repair at the call site is no longer inert in shipped play')

    -- The call site, and the fact that it is the ONLY caller: a second caller
    -- reached from ungated code would make this an ungated behaviour change.
    local callers = 0
    for _ in AIU_SRC:gmatch('J%.GetTowerDefenseTpLocation') do callers = callers + 1 end
    assert(callers == 1,
        'expected exactly one call to J.GetTowerDefenseTpLocation in ' .. AIU
        .. ', found ' .. callers)
    assert(AIU_SRC:find('local vTpLoc = J.GetTowerDefenseTpLocation( hTowerFight )', 1, true) ~= nil,
        'the midtp/suptp wiring no longer calls the repaired helper')
    assert(AIU_SRC:find('J.GetNearbyLocationToTp( hTowerFight:GetLocation() )', 1, true) == nil,
        'the NaN-producing call is back in ' .. AIU)

    -- Whole-repo: no other file may pick the helper up without re-reading this.
    local p = assert(io.popen('grep -rl "GetTowerDefenseTpLocation" bots/ 2>/dev/null'))
    local files, seen = {}, {}
    for line in p:lines() do
        files[#files + 1] = line
        seen[line] = true
    end
    p:close()
    table.sort(files)
    assert(#files == 2 and seen[AIU] and seen[JMZ],
        'J.GetTowerDefenseTpLocation is referenced from ' .. table.concat(files, ', ')
        .. '; it is gated only by the midtp/suptp wiring, so a third file means '
        .. 'a shipped behaviour change nobody priced')
end

tests['[tpdefnan] 6. the other eight call sites were not touched'] = function()
    local s = JMZ_SRC:find('function J.GetNearbyLocationToTp( nLoc )', 1, true)
    assert(s ~= nil, 'J.GetNearbyLocationToTp is gone from ' .. JMZ)
    local body = JMZ_SRC:sub(s, (JMZ_SRC:find('\nend', s, true) or #JMZ_SRC) + 3)

    -- The shared function keeps its shipped shape, byte for byte in the two
    -- places that decide its answer. This is what makes "only one call site
    -- moved" a read of the tree rather than a promise.
    assert(body:find('J.GetLocationToLocationDistance( nLoc, nFountain ) <= 2500', 1, true) ~= nil,
        'the <=2500 early return moved; the eight untouched call sites are no '
        .. 'longer untouched')
    assert(body:find('return J.GetLocationTowardDistanceLocation( targetTower, nLoc, 575 )', 1, true) ~= nil,
        'the toward-nLoc return moved; the eight untouched call sites are no '
        .. 'longer untouched')

    -- ⚠️ REGISTERED, NOT REPAIRED: the shared function still answers NaN for a
    -- tower's own location. Section 2 measures that. It is left standing
    -- because no shipped caller passes such a location today -- and because
    -- repairing it would be a change to eight other call sites in one move,
    -- which is the bundle AGENTS.md has already paid for twice (lanefix, gpm
    -- -74.5 then -88.7, 0/4 comps). Whoever adds a TENTH call site that passes
    -- a building must repair the shared function then, with its own pricing.
    assert(CENSUS.shipped_nan > 0, 'see section 2')
end

tests['[tpdefnan] 7. the repair keeps its own zero-distance branch'] = function()
    local s = JMZ_SRC:find('function J.GetTowerDefenseTpLocation( hTower )', 1, true)
    assert(s ~= nil, 'J.GetTowerDefenseTpLocation is gone from ' .. JMZ)
    local body = JMZ_SRC:sub(s, (JMZ_SRC:find('\nend', s, true) or #JMZ_SRC) + 3)

    -- ⭐ A SOURCE PIN, AND IT SAYS SO. No tower in this corpus stands on a
    -- fountain, so a corpus reading CANNOT distinguish `nDist <= 0` from
    -- `nDist < 0` or from no branch at all: sections 2-4 stay green either way.
    -- That is exactly the hole the shipped 0/0 came through -- a direction
    -- nobody could observe being undefined -- so the branch is pinned on the
    -- text instead of pretended to be measured.
    assert(body:find('if nDist <= 0 then return vTower end', 1, true) ~= nil,
        'the zero-distance branch is gone from J.GetTowerDefenseTpLocation. It '
        .. 'is not reachable on this corpus, which is precisely why it cannot '
        .. 'be defended by a count: removing it re-opens a 0/0 that no frame '
        .. 'here would show you.')
    assert(body:find('J.GetLocationTowardDistanceLocation( hTower, vFountain, 575 )', 1, true) ~= nil,
        'the repair no longer offsets by the shipped 575 toward our own '
        .. 'fountain; sections 3 measures that, this pins the expression')
end

return tests

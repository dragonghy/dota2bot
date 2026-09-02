-- Soak candidate 'roshdist' -- bots/mode_retreat_generic.lua:426; gate resolved
-- in exactly one place, J.IsAtRoshanPit in bots/FunLib/jmz_func.lua, over the
-- parameterised worker J.RoshanPitProximity.
--
-- THE DEFECT. The shipped conjunct reads
--
--     if botActiveMode == BOT_MODE_ROSHAN
--         and not J.IsRoshanAlive()
--         and GetUnitToLocationDistance(bot, vRoshanLocation)   <-- here
--         and IsLocationVisible(vRoshanLocation)
--
-- A distance is a NUMBER, and in Lua every number -- 0 included -- is truthy.
-- That conjunct is therefore not a condition; it is a spacer that reads like
-- one. The comparison that would make it a condition was dropped, and nothing
-- in the language, in luacheck, or in the test suite raises a hand: the line
-- is well-formed, the value is used, the file is green.
--
-- Same family as 'hpbool' (GH #397), where six J.GetHP operands had lost their
-- `< X`. The discriminator there was 64:6; here it is sharper. Repo-wide
-- census over bots/ (pinned by [census] below): 1173 call sites of the three
-- distance functions -- 1308 counting the DistanceFrom* family -- and exactly
-- TWO of them spell one as a bare truth operand --
-- both in mode_retreat_generic.lua, both the same expression against the same
-- variable, twelve lines apart. Everything else in the tree carries its
-- comparison. This is a defect, not a house idiom.
--
-- FAILURE DIRECTION IS OPEN (fourth in the archive to point this way, after
-- #393 / #397 / #406). A guard that cannot refuse anybody offers the
-- "roshan is dead, stop lingering in BOT_MODE_ROSHAN" retreat desire to a bot
-- standing anywhere on the map with line of sight to the pit -- and
-- IsLocationVisible is a LOCATION test, not a proximity test: an ally, a ward
-- or a courier holding vision of the pit satisfies it for the whole team.
--
-- THE RADIUS IS DERIVED, NOT BORROWED (the [threshold] case below is the
-- evidence). 1600 is this repo's own "arrived at the pit" radius: three sites
-- walk toward J.GetCurrentRoshanLocation() while the distance is > 1600 and
-- stop below it, and it is the only threshold in bots/ used in the arrival
-- sense against this location.
--
-- ⛔ WHAT THIS FILE CANNOT BUY, STATED UP FRONT (the 0CORP domain price, run
-- BEFORE the lever was picked, not after):
--   * The fixtures do NOT record a bot's active mode, so BOT_MODE_ROSHAN
--     itself is out of reach here. What this file buys on real frames is the
--     conjunct -- the operand that was broken -- and its two answers, over
--     every hero position in the corpus. The surrounding mode/aegis/liveness
--     conjuncts are untouched by this change and are not re-asserted.
--   * Condition (a) -- "it really fires in a real game" -- is the replay
--     group's to buy, and the thing to look for is a retreat desire raised
--     while the subject is nowhere near the pit.
--
-- The domain price came back CHEAP, which is why this lever was picked over
-- the arc-warden one found in the same sweep (J.GetNearbyHeroes filters the
-- whole list on a modifier of the SCANNER instead of the candidate --
-- registered, not fixed, because corpus_hero_census.py answers arc_warden
-- DOMAIN-EMPTY files=0 and a fixture-level acceptance is impossible).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- The one fixture in the corpus with a hero standing inside the pit radius
-- (venomancer, 756u, night frame -> radiant pit). It carries the positive
-- control, so a "always false" repair cannot satisfy this file.
local NEAR_FX = 'tests/fixtures/f_050713_es_defend_1v3.lua'
local NEAR_HERO = 'npc_dota_hero_venomancer'
local FAR_FX = 'tests/fixtures/f_011405_jak_rescue_axe.lua'

local RADIUS = 1600

local tests = {}

local function paths()
    local p = assert(io.popen('ls tests/fixtures/f_*.lua'))
    local out = {}
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    assert(#out > 0, 'the fixture corpus is empty -- nothing below can fail')
    return out
end

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function lua_sources()
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    local out = {}
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    assert(#out > 100, 'the bots/ tree shrank to ' .. #out .. ' files -- census would be vacuous')
    return out
end

-- rf.load hands back the hero table keyed BY UNIT NAME, not as an array. The
-- first draft of this file walked it with ipairs, got nil for every lookup,
-- and every corpus reading below silently scanned zero units -- which is the
-- same "green because nothing ran" shape the archive keeps hitting. The
-- floors in each case are what turned it red instead of quiet.
local function hero_named(heroes, sName)
    return heroes[sName]
end

--============================================================================
-- [premise] The instrument is not blind.
--
-- Four rounds of this archive have been bitten by a getter that answers 0 or
-- nil under the mock and makes a whole domain constructively unreachable
-- (GH #89 world assertion 13; #391 GetCastRange; the ITEM_SLOT_TYPE getter in
-- §DJ). Every reading in this file is a distance, so if
-- GetUnitToLocationDistance were an instrument zero the numbers below would be
-- unanimous garbage that still looks like data. Pin it: the engine call must
-- agree with the frame's own coordinates.
--============================================================================
tests['[premise] GetUnitToLocationDistance measures, it does not answer 0'] = function()
    local J, bot, heroes, fx = rf.load(NEAR_FX)
    local vPit = J.GetCurrentRoshanLocation()
    assert(vPit ~= nil, 'J.GetCurrentRoshanLocation() is nil under the fixture harness')

    local nAgree, nNonZero = 0, 0
    for _, u in ipairs(fx.units) do
        local h = hero_named(heroes, u.name)
        if h ~= nil then
            local nEngine = GetUnitToLocationDistance(h, vPit)
            local dx, dy = u.x - vPit.x, u.y - vPit.y
            local nFrame = math.sqrt(dx * dx + dy * dy)
            assert(math.abs(nEngine - nFrame) < 1.0,
                u.name .. ': engine says ' .. tostring(nEngine) ..
                ', the frame coordinates say ' .. tostring(nFrame))
            nAgree = nAgree + 1
            if nEngine > 0 then nNonZero = nNonZero + 1 end
        end
    end
    assert(nAgree >= 8, 'only ' .. nAgree .. ' units compared -- the premise is vacuous')
    assert(nNonZero == nAgree, 'some distance came back 0 on a hero that is not at the pit')
end

--============================================================================
-- [domain price] Two histograms over the whole corpus, and BOTH have to be
-- non-empty for anything here to be falsifiable: frames outside the radius are
-- where armed disagrees with shipped, frames inside are where it must still
-- agree. Measured 2026-09-02 over the 107 fixtures the loader actually builds
-- heroes for -- 1070 hero-frames, 1046 distinct distances: 10 inside the
-- radius, 1060 outside. Floors, not equalities -- the corpus grows.
--============================================================================
tests['[domain price] the corpus can falsify this fix in both directions'] = function()
    local nInside, nOutside, nFrames = 0, 0, 0
    local inside = {}
    for _, path in ipairs(paths()) do
        local J, bot, heroes, fx = rf.load(path)
        local vPit = J.GetCurrentRoshanLocation()
        for _, u in ipairs(fx.units) do
            local h = hero_named(heroes, u.name)
            if h ~= nil then
                nFrames = nFrames + 1
                local nDist = GetUnitToLocationDistance(h, vPit)
                if nDist <= RADIUS then
                    nInside = nInside + 1
                    inside[#inside + 1] = path .. ' ' .. u.name
                else
                    nOutside = nOutside + 1
                end
            end
        end
    end
    assert(nFrames >= 900, 'hero-frames scanned collapsed to ' .. nFrames)
    assert(nOutside >= 900, 'the disagreeing half collapsed to ' .. nOutside)
    assert(nInside >= 1, 'NO unit-frame is inside the pit radius any more -- the ' ..
        'positive control below is unbuyable and this fix is untestable on real ' ..
        'frames; re-measure before trusting anything in this file')
    -- The one that carries the positive control must still be there by name.
    local bFound = false
    for _, s in ipairs(inside) do
        if s == NEAR_FX .. ' ' .. NEAR_HERO then bFound = true end
    end
    assert(bFound, 'the named near-pit frame moved: inside set is {' ..
        table.concat(inside, ', ') .. '}')
end

--============================================================================
-- Ground truth on real frames: the two legs, and the flip.
--============================================================================
tests['[off-candidate] unarmed IS the shipped expression, value for value'] = function()
    -- Not "same truth value" -- the same NUMBER. The shipped call site used
    -- the distance itself as the operand, so anything that changes the value
    -- changes what a future caller in a non-boolean context would read.
    --
    -- ⚠ This assertion is only worth something if the corpus can make it fail.
    -- §DJ.7 counted a mutation equivalent because "this corpus has no two
    -- carriers at equal distance" and the mutant then sat on trunk. So: the
    -- distances have to actually vary, and that is asserted, not assumed.
    local nChecked, nDistinct = 0, 0
    local seen = {}
    for _, path in ipairs(paths()) do
        local J, bot, heroes, fx = rf.load(path)
        local vPit = J.GetCurrentRoshanLocation()
        for _, u in ipairs(fx.units) do
            local h = hero_named(heroes, u.name)
            if h ~= nil then
                local nShipped = GetUnitToLocationDistance(h, vPit)
                local nUnarmed = J.RoshanPitProximity(h, vPit, false)
                assert(nUnarmed == nShipped, path .. ' ' .. u.name ..
                    ': unarmed returned ' .. tostring(nUnarmed) ..
                    ' where the shipped expression is ' .. tostring(nShipped))
                nChecked = nChecked + 1
                local key = string.format('%.1f', nShipped)
                if not seen[key] then seen[key] = true; nDistinct = nDistinct + 1 end
            end
        end
    end
    assert(nChecked >= 900, 'only ' .. nChecked .. ' hero-frames checked')
    assert(nDistinct >= 400, 'the corpus distances collapsed to ' .. nDistinct ..
        ' distinct values -- a value-equality assertion over a constant is not a test')
end

tests['[flip] armed refuses a bot that is nowhere near the pit'] = function()
    local J, bot, heroes, fx = rf.load(FAR_FX)
    local vPit = J.GetCurrentRoshanLocation()
    local nDist = GetUnitToLocationDistance(bot, vPit)
    assert(nDist > RADIUS + 2000, 'the far frame drifted to ' .. tostring(nDist) .. 'u')

    local shipped = J.RoshanPitProximity(bot, vPit, false)
    assert(shipped, 'shipped must be truthy -- that is the whole defect')
    assert(shipped ~= false and shipped ~= nil and type(shipped) == 'number',
        'shipped must be the raw number, got ' .. type(shipped))
    assert(J.RoshanPitProximity(bot, vPit, true) == false,
        'armed still accepts a bot ' .. tostring(nDist) .. 'u from the pit')
end

tests['[decision, positive control] armed still accepts a bot AT the pit'] = function()
    -- Load-bearing: without it, "armed said false" is also satisfied by a
    -- repair that says false for everybody, which is a different bug in the
    -- other direction (a bot that can never leave BOT_MODE_ROSHAN).
    local J, bot, heroes, fx = rf.load(NEAR_FX)
    local vPit = J.GetCurrentRoshanLocation()
    local h = hero_named(heroes, NEAR_HERO)
    assert(h ~= nil, NEAR_HERO .. ' left this frame')
    local nDist = GetUnitToLocationDistance(h, vPit)
    assert(nDist < RADIUS, NEAR_HERO .. ' is now ' .. tostring(nDist) .. 'u out')
    assert(J.RoshanPitProximity(h, vPit, true) == true,
        'armed refused a hero standing ' .. tostring(nDist) .. 'u from the pit')
end

tests['[boundary] the radius is inclusive, on this frame own geometry'] = function()
    -- Constructed from a real hero's real position rather than asserted in
    -- prose: place the pit exactly RADIUS away along the x axis and let the
    -- engine measure it. `<` instead of `<=` dies here; nothing else does.
    local J, bot, heroes, fx = rf.load(FAR_FX)
    local vHere = bot:GetLocation()
    local vEdge = Vector(vHere.x + RADIUS, vHere.y, vHere.z)
    local nEdge = GetUnitToLocationDistance(bot, vEdge)
    assert(math.abs(nEdge - RADIUS) < 0.001,
        'the constructed edge is ' .. tostring(nEdge) .. 'u, not ' .. RADIUS ..
        ' -- the premise of this case, not its conclusion')
    assert(J.RoshanPitProximity(bot, vEdge, true) == true,
        'a bot exactly at the radius must count as arrived')
    local vJustOut = Vector(vHere.x + RADIUS + 1, vHere.y, vHere.z)
    assert(J.RoshanPitProximity(bot, vJustOut, true) == false,
        'one unit past the radius must not count as arrived')
end

tests['[radius override] the caller can name its own radius'] = function()
    local J, bot, heroes, fx = rf.load(FAR_FX)
    local vPit = J.GetCurrentRoshanLocation()
    local nDist = GetUnitToLocationDistance(bot, vPit)
    assert(J.RoshanPitProximity(bot, vPit, true, nDist + 1) == true,
        'an explicit radius wider than the distance must accept')
    assert(J.RoshanPitProximity(bot, vPit, true, nDist - 1) == false,
        'an explicit radius narrower than the distance must refuse')
end

--============================================================================
-- [census] The discriminator, pinned so that "one bare operand left" is a
-- deliberate state and not drift. This is the only case in the file that does
-- not need a falsifiable input: it reads source and is red on an empty corpus.
--============================================================================
local DIST_FNS = {
    'GetUnitToUnitDistance',
    'GetUnitToLocationDistance',
    'GetLocationToLocationDistance',
}

-- Returns: total call sites, and the list of BARE truth operands (a call in a
-- boolean-lead position whose next token -- on this line or the next non-blank
-- one -- is not a comparison).
local function census()
    local nTotal, bare = 0, {}
    for _, path in ipairs(lua_sources()) do
        local lines = {}
        for line in read(path):gmatch('([^\n]*)\n?') do lines[#lines + 1] = line end
        for i = 1, #lines do
            local code = lines[i]:gsub('%-%-.*$', '')
            for _, fn in ipairs(DIST_FNS) do
                local from = 1
                while true do
                    local s, e = code:find(fn .. '%s*%(', from)
                    if s == nil then break end
                    -- reject a longer identifier that merely ends with fn
                    local prev = s > 1 and code:sub(s - 1, s - 1) or ' '
                    if not prev:match('[%w_]') then
                        nTotal = nTotal + 1
                        -- walk to the matching ')'
                        local depth, k = 0, e
                        while k <= #code do
                            local c = code:sub(k, k)
                            if c == '(' then depth = depth + 1
                            elseif c == ')' then
                                depth = depth - 1
                                if depth == 0 then break end
                            end
                            k = k + 1
                        end
                        local after = code:sub(k + 1):gsub('^%s+', '')
                        local before = code:sub(1, s - 1):gsub('^%s+', ''):gsub('%s+$', '')
                        -- A BARE TRUTH OPERAND is a call that is a WHOLE
                        -- operand of a boolean expression: the token in front
                        -- of it opens a condition and nothing binds tighter
                        -- behind it. Both halves matter. Without the first,
                        -- `dLoc < (best and dist(x) or dLoc)` counts (the `and`
                        -- of a ternary); without the second, `and dist(a) -
                        -- dist(b) > r` counts (the comparison is three tokens
                        -- away). Each of those cost the first draft of this
                        -- census a false positive, and a census that cries
                        -- wolf is worse than none.
                        local bLead = before == 'if' or before == 'elseif'
                            or before == 'and' or before == 'or'
                            or before:match('^i[f]%s*%(+$') ~= nil
                            or before:match('^and%s*%(+$') ~= nil
                            or before:match('^or%s*%(+$') ~= nil
                            or before:match('^elseif%s*%(+$') ~= nil
                        -- Closing parens that merely give the lead's own
                        -- brackets back are not a continuation; anything that
                        -- follows them is. `and ((dist(a, b)) / speed) <= 6.0`
                        -- ends the call with `)` and would otherwise pass.
                        local tail = after:gsub('^%s*%)+%s*', '')
                        local bWholeOperand = tail == '' or tail:match('^and%f[%W]') ~= nil
                            or tail:match('^or%f[%W]') ~= nil
                            or tail:match('^then%f[%W]') ~= nil
                        if bLead and bWholeOperand then
                            if tail ~= '' or after ~= '' then
                                bare[#bare + 1] = path .. ':' .. i .. ': ' ..
                                    (lines[i]:gsub('^%s+', ''))
                            else
                                -- the comparison may sit on the next non-blank line
                                local j = i + 1
                                while lines[j] ~= nil and lines[j]:match('^%s*$') do j = j + 1 end
                                local nxt = (lines[j] or ''):gsub('^%s+', '')
                                if not nxt:match('^[<>=~]') then
                                    bare[#bare + 1] = path .. ':' .. i .. ': ' ..
                                        (lines[i]:gsub('^%s+', ''))
                                end
                            end
                        end
                    end
                    from = e
                end
            end
        end
    end
    return nTotal, bare
end

tests['[census] exactly one bare-truth distance operand is left in bots/'] = function()
    local nTotal, bare = census()
    assert(nTotal >= 1000, 'the census scanned only ' .. nTotal ..
        ' distance call sites -- it stopped seeing the tree, so its zero means nothing')
    -- Before this change: 2, both in mode_retreat_generic.lua. This one takes
    -- the generic (all-heroes, BOT_MODE_ROSHAN) site. The lone_druid site
    -- twelve lines up is REGISTERED AND DELIBERATELY UNTOUCHED -- one lever at
    -- a time -- and its domain price is already measured: corpus_hero_census.py
    -- answers lone_druid DOMAIN-EMPTY, so it cannot buy condition (a) here.
    assert(#bare == 1, 'expected exactly one bare operand left, found ' .. #bare ..
        ':\n  ' .. table.concat(bare, '\n  '))
    assert(bare[1]:find('mode_retreat_generic%.lua:41[0-9]'),
        'the remaining bare operand moved: ' .. bare[1])
    assert(bare[1]:find('GetUnitToLocationDistance%(bot, vRoshanLocation%)'),
        'the remaining bare operand is not the lone_druid twin: ' .. bare[1])
end

--============================================================================
-- [source parity] and [gate]: what the diff is allowed to be.
--============================================================================
tests['[source parity] the call site changed by exactly one name'] = function()
    local src = read('bots/mode_retreat_generic.lua')
    local _, nWrapped = src:gsub('J%.IsAtRoshanPit%s*%(%s*bot%s*,%s*vRoshanLocation%s*%)', '')
    assert(nWrapped == 1, 'the wrapper must be named exactly once in the mode ' ..
        'script, found ' .. nWrapped)
    local block = src:match('(if botActiveMode == BOT_MODE_ROSHAN.-then)')
    assert(block, 'the BOT_MODE_ROSHAN block is gone or reshaped')
    assert(block:find('J%.IsAtRoshanPit'), 'the repaired conjunct left its block')
    assert(not block:find('GetUnitToLocationDistance'),
        'the raw distance call is still inside the repaired block')
    -- and the three neighbours are untouched
    assert(block:find('not J%.IsRoshanAlive%(%)'), 'the liveness conjunct moved')
    assert(block:find('IsLocationVisible%(vRoshanLocation%)'), 'the vision conjunct moved')
    assert(block:find('botActiveMode == BOT_MODE_ROSHAN'), 'the mode conjunct moved')
end

tests['[gate] turbo AND the id, resolved in exactly one place'] = function()
    local src = read('bots/FunLib/jmz_func.lua')
    local fn = src:match('function J%.IsAtRoshanPit.-\nend')
    assert(fn, 'J.IsAtRoshanPit is gone or reshaped')
    assert(fn:find("J%.IsSoakCandidate%s*%(%s*'roshdist'%s*%)"),
        'the wrapper does not read the roshdist gate')
    assert(fn:find('J%.IsModeTurbo%s*%(%s*%)'), 'the gate is not turbo-only')
    local iTurbo = fn:find('J%.IsModeTurbo')
    local iCand = fn:find('J%.IsSoakCandidate')
    assert(iTurbo < iCand, 'turbo must be the first operand of the gate')

    local _, nGates = src:gsub("IsSoakCandidate%s*%(%s*'roshdist'%s*%)", '')
    assert(nGates == 1, "the roshdist id is read in " .. nGates ..
        ' places; it must resolve in exactly one')

    -- and the worker itself must carry no gate at all
    local worker = src:match('function J%.RoshanPitProximity.-\nend')
    assert(worker, 'J.RoshanPitProximity is gone or reshaped')
    assert(not worker:find('IsSoakCandidate'),
        'the worker reads the gate -- then the wrapper is not the one place')
    assert(worker:find('nDistance <= %( nRadius or 1600 %)'),
        'the armed comparison drifted from `<= (nRadius or 1600)`')
end

tests['[threshold] 1600 is the tree own arrival radius, not a guess'] = function()
    -- The [gate] case pins the number; this one pins WHY it is that number, so
    -- that a future reader who wants to move it knows what to re-derive.
    local nSites = 0
    for _, path in ipairs(lua_sources()) do
        local src = read(path)
        if src:find('GetUnitToLocationDistance%(bot, RoshanLocation%) > 1600') then
            nSites = nSites + 1
        end
    end
    assert(nSites >= 2, 'the "walk to the pit while > 1600" idiom this radius is ' ..
        'borrowed from has dropped to ' .. nSites .. ' sites -- re-derive the radius')
end

return tests

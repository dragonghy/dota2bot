-- [strategy backlog 8, the midtp/suptp half] The gated TP-response chain:
-- does a bot ever CONSUME the team-wide response quota without casting a TP?
--
-- The charter has carried two suspicions about this chain for several rounds:
--   (i) the item loop's slot order `{5,4,3,2,1,0,15,16}` puts the TP scroll
--       SEVENTH, so any main-inventory item that wants to fire this frame
--       preempts the whole TP branch; and
--   (ii) `ability_item_usage_generic.lua:5100+` is a first-match-wins guard
--       chain in which `lf_rescue` is ordered BEFORE `midtp` while both share
--       `J.TryTakeTpResponseSlot()` -- a module-level ledger that allows ONE
--       gated TP response per rolling 6s window, team-wide.
--
-- The worry behind (ii) was a leak: `J.GetRescueTpTarget` takes the slot as the
-- last conjunct of its `and` chain, and only THEN does its caller resolve a
-- landing point and decide whether to actually cast. If that resolution could
-- fail, the slot would be spent on nothing -- blocking the whole team for 6s
-- AND, on the very next line of the same function, blocking `midtp`.
--
-- HEADLINE RESULT: NEGATIVE. The leak does not exist, for a reason that is
-- structural rather than lucky -- `J.GetNearbyLocationToTp` is a TOTAL
-- function. It has no `return nil` anywhere in its body and ends in an
-- unconditional `return nFountain`, so both callers' `if v... ~= nil then`
-- guards are dead code and neither branch can fall through after taking the
-- slot. Suspicion (ii) is void.
--
-- NOTHING in bots/ changes here and no gate is proposed. Removing the two dead
-- guards would be a readability edit on a SHIPPED, UNGATED path in the middle
-- of the TP family, and it would delete the only in-code marker of the
-- invariant this file now pins. The invariant is pinned instead.
--
-- Suspicion (i) SURVIVES and is narrowed below (test 9): the TP scroll really
-- is seventh of eight, and the pre-loop regen preemption that would have made
-- it much worse is inert (gated behind `lanefix`, which is not armed).
--
-- SECOND RESULT, found by the mutation pass rather than by reading: the quota
-- ledger stamps its clock in TWO places and each stamp is individually a dead
-- store. Remove either and nothing changes; remove both and the team quota
-- becomes UNLIMITED, silently. Pinned by test 7 -- see the note there.
--
-- Honest bounds:
--   * Totality is proven two ways -- by reading the function's source for
--     `return nil` (test 1, exhaustive over the body) and by measuring the
--     real answer on four real frames (test 2). Neither alone is enough: the
--     source read cannot rule out a runtime error, and four frames cannot rule
--     out an unvisited branch.
--   * `tTpQuota` being ONE ledger shared by all five bots is an assumption of
--     the shipped design (the comment at jmz_func.lua:5683 asserts it), not
--     something this harness can check: the mock loads jmz_func once per test,
--     so a per-bot VM would look identical here. Only an in-game observation
--     can settle it. Tests 5-7 therefore pin the ledger's ARITHMETIC, which is
--     what the code actually controls.
--   * The frames are reused from the GH #37 acceptance triple plus the
--     `lf_rescue` keystone. They were chosen because they are the frames on
--     which a rescue TP is genuinely being decided; no new corpus was bought.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ_PATH = 'bots/FunLib/jmz_func.lua'
local ITEM_PATH = 'bots/ability_item_usage_generic.lua'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

--- The source text of one top-level `function <name>( ... ) ... end`, matched
--- on the column-0 `end` that the repo's style guarantees.
local function function_body(src, name)
    local s = src:find('\nfunction ' .. name .. '%s*%(', 1)
    assert(s, 'could not find function ' .. name)
    local e = src:find('\nend\n', s, true)
    assert(e, 'could not find the terminating end of ' .. name)
    return src:sub(s, e + 4)
end

local function count_occurrences(src, needle)
    local n, pos = 0, 1
    while true do
        local s = src:find(needle, pos, true)
        if not s then return n end
        n, pos = n + 1, s + 1
    end
end

-- Frames on which a rescue TP is genuinely being decided. `expect_landing` is
-- the distance from the resolved landing point to the ally, already reproduced
-- from the .dem by tests/test_lf_rescue_landing_reach.lua (GH #37).
local FRAMES = {
    { name = 'A far',    path = 'tests/fixtures/f_260819_123012_dk_rescue_far.lua' },
    { name = 'B doomed', path = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua' },
    { name = 'C works',  path = 'tests/fixtures/f_260819_123546_axe_rescue_ok.lua' },
    { name = 'keystone', path = 'tests/fixtures/f_071423_sky_rescue.lua' },
}

-- ---------------------------------------------------------------------------
-- 1-2. The landing resolver is TOTAL -- the load-bearing fact of this file.
-- ---------------------------------------------------------------------------

tests['[reverse] J.GetNearbyLocationToTp has no nil-returning path'] = function()
    local body = function_body(read_file(JMZ_PATH), 'J.GetNearbyLocationToTp')

    assert(body:find('return%s+nil') == nil,
        'J.GetNearbyLocationToTp gained a `return nil`. The two callers in '
        .. ITEM_PATH .. ' guard its result with `~= nil` and take the team TP '
        .. 'quota BEFORE resolving the landing point -- those guards were dead '
        .. 'code, and a nil path turns them live into a quota leak. Re-read '
        .. 'this whole file: its headline negative result no longer holds.')

    -- Not merely "no explicit nil": the function must END in an unconditional
    -- return, or control could fall off the bottom and return nil implicitly.
    local tail = body:match('([^\n]*)\n[^\n]*\n?end\n$') or ''
    assert(body:find('\treturn nFountain\n', 1, true) ~= nil,
        'the unconditional `return nFountain` tail is gone; got tail ' .. tail)

    -- Every `return` in the body must be a value, never a bare `return`.
    for ret in body:gmatch('return([^\n]*)') do
        assert(ret:match('^%s*$') == nil,
            'bare `return` (implicit nil) in J.GetNearbyLocationToTp')
    end
end

tests['on four real rescue frames the resolver answers a real location'] = function()
    for _, f in ipairs(FRAMES) do
        local J, ally = rf.load(f.path)
        local vLand = J.GetNearbyLocationToTp(ally:GetLocation())
        assert(vLand ~= nil, f.name .. ': landing point came back nil')
        assert(type(vLand) == 'table' and vLand.x ~= nil and vLand.y ~= nil,
            f.name .. ': landing point is not a location, got ' .. type(vLand))
        -- A location the caller would actually pass to Action_UseAbilityOnLocation.
        local d = J.GetLocationToLocationDistance(vLand, ally:GetLocation())
        assert(d >= 0 and d < 30000, f.name .. ': implausible landing distance ' .. d)
    end
end

-- ---------------------------------------------------------------------------
-- 3-4. Therefore the guards are dead and the chain cannot fall through.
-- ---------------------------------------------------------------------------

tests['[reverse] both TP-response callers still guard the total resolver'] = function()
    local src = read_file(ITEM_PATH)
    -- These two guards are UNREACHABLE-FALSE given test 1. They are pinned so
    -- that the pair (resolver totality, caller shape) stays a checked claim
    -- rather than a comment: if either side moves, this file must be re-read.
    assert(src:find('if vRescueLoc ~= nil then', 1, true),
        'the lf_rescue landing guard moved -- re-derive the leak analysis')
    assert(src:find('if vTpLoc ~= nil then', 1, true),
        'the midtp landing guard moved -- re-derive the leak analysis')
end

tests['[reverse] lf_rescue is ordered before midtp and neither can fall through'] = function()
    local src = read_file(ITEM_PATH)
    local iRescue = src:find('J.GetRescueTpTarget( bot )', 1, true)
    local iMidTp = src:find('J.ShouldTpSupportTowerFight( bot )', 1, true)
    assert(iRescue and iMidTp, 'both TP-response triggers must be in the chain')
    -- The ordering suspicion (ii) is real as an ORDERING: lf_rescue is asked
    -- first. What made it a suspected DEFECT was the fall-through, and there
    -- is none: between taking the quota and returning, the only branch is the
    -- dead nil-guard above.
    assert(iRescue < iMidTp,
        'lf_rescue must still precede midtp, or the precedence analysis in '
        .. 'this file and in the strategy charter is stale')

    -- Between the two triggers there is exactly one `return`: the rescue TP's
    -- own. No other exit, and no code that could consume the frame.
    local between = src:sub(iRescue, iMidTp)
    assert(count_occurrences(between, 'return ') == 1,
        'the span between the two triggers gained an exit path -- a taken '
        .. 'quota could now be spent without a TP being cast')
end

-- ---------------------------------------------------------------------------
-- 5-7. The ledger's arithmetic, driven on the real helper.
-- ---------------------------------------------------------------------------

--- Load jmz_func on a real frame and hand back a settable clock.
local function with_clock(path)
    local J = rf.load(path)
    local now = DotaTime()
    DotaTime = function() return now end
    return J, function(t) now = t end
end

tests['the team TP quota admits one responder per 6s window'] = function()
    local J, setNow = with_clock(FRAMES[1].path)
    setNow(300.0)
    assert(J.TryTakeTpResponseSlot() == true, 'the first responder must get in')
    assert(J.TryTakeTpResponseSlot() == false, 'the second must be refused')
    setNow(305.9)
    assert(J.TryTakeTpResponseSlot() == false,
        'still inside the 6s window at +5.9s')
    setNow(306.5)
    assert(J.TryTakeTpResponseSlot() == true, 'the window must reopen after 6s')
end

tests['the quota window SLIDES from the last successful take, not the first'] = function()
    local J, setNow = with_clock(FRAMES[1].path)
    setNow(100.0)
    assert(J.TryTakeTpResponseSlot() == true)
    setNow(106.5)
    assert(J.TryTakeTpResponseSlot() == true, 'reopens 6.5s after the take')
    -- The third window is measured from 106.5 and not from 100.0. Pinned
    -- because "one per 6s" reads as a fixed grid and it is not one.
    setNow(112.0)
    assert(J.TryTakeTpResponseSlot() == false,
        'at 112.0 we are 12.0s past the FIRST take but only 5.5s past the '
        .. 'second -- the window is measured from the second')
end

tests['[reverse] the quota timestamp is written TWICE and neither write may go'] = function()
    -- Measured, not assumed (mutation pass 20260821): `tTpQuota.t = nNow`
    -- appears in BOTH the window-reset branch and the take path, and each one
    -- is individually a DEAD STORE -- deleting either alone leaves every
    -- assertion in this file green, because the other still stamps the clock.
    -- Deleting BOTH makes `nNow - tTpQuota.t` permanently exceed the window,
    -- so every caller resets and `TryTakeTpResponseSlot` returns true forever:
    -- the team quota silently becomes unlimited and the collective-TP
    -- pathology that fix B was built to stop comes back with no error, no log
    -- and no failing test other than this file's behavioural ones.
    --
    -- That is a live hazard for exactly the reason it is hard to see: a
    -- reviewer who removes "the redundant assignment" is right the first time
    -- and catastrophically wrong the second. Both writes are pinned here so
    -- the second removal cannot be justified by the first one having been safe.
    local body = function_body(read_file(JMZ_PATH), 'J.TryTakeTpResponseSlot')
    assert(body:find('tTpQuota.t, tTpQuota.n = nNow, 0', 1, true),
        'the window-reset stamp is gone -- if the take-path stamp is also '
        .. 'gone the quota is disabled; re-read this test before proceeding')
    assert(body:find('\ttTpQuota.t = nNow\n', 1, true),
        'the take-path stamp is gone -- if the reset stamp is also gone the '
        .. 'quota is disabled; re-read this test before proceeding')
    assert(count_occurrences(body, 'nNow') >= 4,
        'the ledger stopped reading the clock in the shape this test pins')
end

tests['a taken quota slot cannot be given back'] = function()
    local J, setNow = with_clock(FRAMES[1].path)
    -- This is the shape of the leak that turned out not to exist. It is pinned
    -- as an absence: there is no refund API, so IF a caller ever gains a path
    -- that takes the slot and then declines to cast, the slot is simply gone
    -- for 6s and this file's negative result must be reopened.
    assert(J.ReleaseTpResponseSlot == nil,
        'a release/refund API appeared. That only makes sense if some caller '
        .. 'can now take the slot without casting -- re-derive the leak '
        .. 'analysis in this file from scratch.')
    setNow(50.0)
    assert(J.TryTakeTpResponseSlot() == true)
    assert(J.TryTakeTpResponseSlot() == false)
    -- No argument reports the outcome, either: the take is unconditional on
    -- whether a TP is ultimately cast.
    assert(J.TryTakeTpResponseSlot(true) == false,
        'TryTakeTpResponseSlot must remain outcome-blind and argument-free')
end

tests['[reverse] the quota is taken as the LAST conjunct at both call sites'] = function()
    local src = read_file(JMZ_PATH)
    -- Ordering matters: taken earlier, a later conjunct could refuse and the
    -- slot would be spent on nothing. Both sites must keep it last.
    local n = 0
    for line in src:gmatch('[^\n]+') do
        if line:find('J.TryTakeTpResponseSlot()', 1, true)
            and not line:find('function J.TryTakeTpResponseSlot', 1, true) then
            n = n + 1
            local rest = line:match('and J%.TryTakeTpResponseSlot%(%)%s*(.-)%s*$')
            assert(rest ~= nil,
                'the quota take must stay an `and` conjunct, got: ' .. line)
            -- LAST conjunct: nothing may follow the call on its line except
            -- the `then` that closes the condition. Anything else is another
            -- conjunct that could refuse AFTER the slot has been consumed --
            -- which is precisely the leak this file reports as absent.
            assert(rest == '' or rest == 'then',
                'the quota take is no longer the LAST conjunct; `' .. rest
                .. '` now follows it, so the slot can be spent on a condition '
                .. 'that then refuses. Re-derive this file: its headline '
                .. 'negative result depends on this ordering.')
        end
    end
    assert(n == 2, 'expected exactly 2 quota call sites in ' .. JMZ_PATH
        .. ' (lf_rescue and midtp), found ' .. n
        .. ' -- a third consumer changes the whole contention analysis')
end

-- ---------------------------------------------------------------------------
-- 8. Suspicion (i) survives: the TP scroll is seventh of eight.
-- ---------------------------------------------------------------------------

tests['[reverse] the item loop reaches the TP scroll seventh, and regen preempt is inert'] = function()
    local src = read_file(ITEM_PATH)

    local literal = src:match('local nItemSlot = (%b{})')
    assert(literal ~= nil, 'the item slot order literal moved')
    local order = {}
    for tok in literal:gmatch('%d+') do order[#order + 1] = tonumber(tok) end
    assert(#order == 8, 'expected 8 slots, got ' .. #order)
    assert(order[7] == 15, 'the TP scroll slot (15) must still be 7th; the '
        .. 'strategy charter records the consequence -- any of the six main '
        .. 'inventory slots that wants to fire this frame preempts the whole '
        .. 'TP branch, including lf_rescue/midtp/suptp. Got index 7 = '
        .. tostring(order[7]))
    for i = 1, 6 do
        assert(order[i] <= 5, 'slots 1-6 of the order must be main inventory')
    end

    -- The one thing that would make (i) MUCH worse -- an unconditional regen
    -- use ahead of the entire loop -- is gated behind `lanefix`, which is not
    -- armed. Pinned so that arming it is not silently a TP-response change.
    local regen = function_body(read_file(JMZ_PATH), 'J.LaneRegenItemToUse')
    assert(regen:find("J.IsLaneFixOn", 1, true) or regen:find("IsSoakCandidate", 1, true),
        'J.LaneRegenItemToUse lost its gate. It runs BEFORE the item slot loop '
        .. 'and returns early, so ungated it would starve the TP-response '
        .. 'branch on exactly the idle frames lf_rescue/midtp fire on.')
end

return tests

-- [ratchet] [outlatch, GH #373 / GH #424] The REAL-FRAME half of condition (a), owed as
-- `iterations/owed_executions.json:outlatch_condition_a_fixture` since the id
-- was returned out of the test set on 2026-09-12 (§HA.1, disposition
-- INSTRUMENT-BLIND).
--
-- WHAT THE OWED ROW ASKS FOR, verbatim: a real frame on which
-- `GetUnitList(UNIT_LIST_ALL)` carries no `#DOTA_OutpostName_*`, and one
-- assertion -- armed, `DidWeGetOutpost` is NOT set (or `NextOutpostScanTime` is
-- advanced, so the next game second re-scans); shipped, it IS set. The row also
-- says, in the same breath, why `tests/test_outlatch_scan_postcondition.lua`
-- does not discharge it: that file is a STATIC SOURCE RATCHET -- it proves the
-- mechanism by reading the file. This one drives the shipped mode file on a
-- pinned frame and reads the consequence off the running code.
--
-- REAL FRAME: 20260905_010205_slot7, t=1350.5, subject luna, the same instant
-- test_outcommit_channel_hold.lua pins, and the only checked-in slice whose
-- building table carries the two watch towers.
-- Slice: tests/fixtures/tl_260905_010205_luna_outchan.json
-- Fixture: tests/fixtures/outchan/f_260905_010205_luna_channel.lua
--
-- ⭐ WHAT IS BOUGHT HERE, and it is the POSTCONDITION, not the DOMAIN:
--     [F3] shipped: over 61 ticks spanning 6 game seconds the world is swept
--          exactly ONCE, the bid is NONE on every one of them, and it is STILL
--          NONE after the outposts become enumerable -- the latch is permanent
--          and the mode is dead for this bot for the rest of the game.
--     [F4] armed: the sweep repeats once per game second while the result is
--          empty, and the first sweep that DOES see an outpost closes the latch
--          and the mode comes alive with the frame's own geometry.
--     [F5] control: when the very first sweep already sees the outposts, armed
--          and shipped are identical in both readings -- same sweep count, same
--          bid. The fix costs nothing on the path that already worked.
--
-- ⛔ WHAT IS NOT BOUGHT, stated before any number below is read:
-- (B1) SUPPLY, not game fact. The empty sweep on this frame is the loader's
--      declared gap -- tests/mock/replay_fixture.lua says in its own comment
--      that it injects no structures into UNIT_LIST_ALL, and
--      tests/_outpost_gate_sweep.lua measures the consequence (2026-09-17
--      re-run: 0 outposts in 1039 entries over 112 fixtures). So [F2] is a
--      property of the corpus, and this file uses it as the STAND for an empty
--      sweep. Whether a real game ever presents an empty sweep at the instant
--      this code runs is the DOMAIN question; outposts are not in the dump at
--      all, which is exactly why §HA.1 called the zero INSTRUMENT-BLIND rather
--      than DOMAIN-NOT-REACHED. Nothing here retires that.
-- (B2) HARNESS, not game fact: `IsEnemyTier2Down` is true on this frame because
--      the slice carries only the two watch towers, so the loader's GetTower
--      answers nil for every slot. Identical in both arms, asserted in [F1]
--      rather than assumed, never the subject of a claim. Same declaration
--      test_outcommit_channel_hold.lua makes as its bound (3).
-- (B3) STIPULATED: the clock. A fixture is one instant; `DotaTime` is driven
--      forward here to exercise the 1.0s re-scan spacing. Every other frame
--      fact (positions, hp, the building table) stays frozen at t=1350.5, so
--      the bid at the last tick is this frame's geometry, NOT a prediction of
--      where luna would have been six seconds later.
-- (B4) The outpost handles in the "enumerable" arms delegate GetTeam /
--      GetLocation / IsAlive to the real building handles the loader built from
--      the dump -- [F1] asserts that delegation reads the dump's numbers. The
--      EMPTY arms, which are the ones the owed row is about, inject nothing at
--      all: they are the loader's own list.
--
-- ⚠️ INSTRUMENT CONTROL, and it is why the sweep counter can be read as "sweeps
-- by this mode": the counter counts every UNIT_LIST_ALL read by anything in the
-- call path (J.IsTeamPushingHighGround, J.GetEnemiesAroundAncient and
-- J.GetEnemiesNearLoc are all on it). [F3] measures that total as exactly 1
-- over 61 ticks in the shipped arm, which bounds every other consumer's
-- contribution on this frame at 0 -- so the counts in [F4] are this file's
-- sweeps and nothing else's.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local MODE = 'bots/mode_outpost_generic.lua'
local FX   = 'tests/fixtures/outchan/f_260905_010205_luna_channel.lua'
local CODE = io.open(MODE):read('*a')
local CAND = 'outlatch'

--- The file with its comment lines removed. The mode file DISCUSSES the
--- shipped latch in prose (`DidWeGetOutpost = true` appears inside the comment
--- that explains the defect), so a source assertion that counts over the raw
--- text answers a question about the documentation, not about the code.
local BODY = (function()
    local out = {}
    for line in (CODE .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end)()

local DESIRE = {
    BOT_MODE_DESIRE_NONE       = 0.0,
    BOT_ACTION_DESIRE_NONE     = 0.0,
    BOT_ACTION_DESIRE_VERYLOW  = 0.1,
    BOT_ACTION_DESIRE_LOW      = 0.25,
    BOT_ACTION_DESIRE_MODERATE = 0.5,
    BOT_ACTION_DESIRE_HIGH     = 0.75,
    BOT_ACTION_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_HIGH       = 0.75,
    BOT_MODE_DESIRE_VERYHIGH   = 0.9,
}

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if s == nil then return n end
        n, at = n + 1, e + 1
    end
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

--- Load the real frame, then hand back the loaded mode plus three instruments:
--- a sweep counter, a clock, and a switch that decides whether the world sweep
--- can see the outposts at all.
---
--- `dofile(MODE)` per call is deliberate and load-bearing here more than
--- anywhere: `Outposts`, `DidWeGetOutpost` and `NextOutpostScanTime` are file
--- locals, and the whole subject of this file is what those three do over time.
--- A shared copy would make the second arm read the first arm's latch.
local function world(opts)
    opts = opts or {}
    local J, bot, _, fx = rf.load(FX)
    for k, v in pairs(DESIRE) do _G[k] = v end

    local ids = opts.ids or {}
    J.IsSoakCandidate = function(id) return ids[id] == true end
    if opts.turbo == false then J.IsModeTurbo = function() return false end end

    -- The real building handles, from the dump, via the loader.
    local real = {}
    for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
        if u:GetUnitName() == 'watch_tower' then real[#real + 1] = u end
    end
    for _, u in ipairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS)) do
        if u:GetUnitName() == 'watch_tower' then real[#real + 1] = u end
    end

    -- Named copies for the "enumerable" arms (B4). Nothing is invented: every
    -- accessor delegates to the handle above.
    local NAMES = { '#DOTA_OutpostName_North', '#DOTA_OutpostName_South' }
    local outposts = {}
    for i, u in ipairs(real) do
        outposts[i] = api.MakeUnit({
            GetUnitName    = NAMES[i],
            GetTeam        = function() return u:GetTeam() end,
            GetLocation    = function() return u:GetLocation() end,
            HasModifier    = function(_, s) return u:HasModifier(s) end,
            IsAlive        = function() return u:IsAlive() end,
            IsNull         = false,
            IsInvulnerable = false,
            CanBeSeen      = true,
        })
    end

    local w = {
        J = J, bot = bot, fx = fx,
        real = real, outposts = outposts,
        sweeps = 0,
        t = fx.time,
        visible = opts.visible and true or false,
    }

    local prev = GetUnitList
    w.raw_all = prev(UNIT_LIST_ALL)
    GetUnitList = function(kind) -- luacheck: ignore
        local base = prev(kind)
        if kind ~= UNIT_LIST_ALL then return base end
        w.sweeps = w.sweeps + 1
        if not w.visible then return base end
        local out = {}
        for _, u in ipairs(base) do out[#out + 1] = u end
        for _, u in ipairs(w.outposts) do out[#out + 1] = u end
        return out
    end
    DotaTime = function() return w.t end -- luacheck: ignore

    dofile(MODE)
    w.desire = GetDesire
    return w
end

--- Tick the mode at 10Hz for `secs` game seconds, returning the last bid.
local function tick(w, secs)
    local t0, last = w.t, nil
    for i = 1, math.floor(secs * 10) do
        w.t = t0 + i * 0.1
        last = w.desire()
    end
    return last
end

-- ---------------------------------------------------------------------------
-- [source] -- the shape, read off the shipped tree
-- ---------------------------------------------------------------------------

tests['[source] the latch records the postcondition, behind one turbo-only gate']
= function()
    assert(count(BODY, "J.IsSoakCandidate('" .. CAND .. "')") == 1,
        "expected exactly one arming point for '" .. CAND .. "'")
    assert(count(BODY, 'DidWeGetOutpost = not bRescan or #Outposts > 0') == 1,
        'the latch line moved; this file drives it and must be re-derived')
    assert(count(BODY, 'DidWeGetOutpost = true') == 0,
        'an unconditional latch assignment is back in the file')
    assert(count(CODE, 'DidWeGetOutpost = true') == 1,
        'the comment that explains the shipped defect moved; it is the reason '
        .. 'the assertion above reads BODY and not CODE')
    assert(count(BODY, 'table.insert(Outposts, unit)') == 1,
        'Outposts has more than one writer; the permanence argument changes')
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real frame, and what it supplies
-- ---------------------------------------------------------------------------

tests['[frame F1] the frame is real, and its two declarations hold'] = function()
    local w = world()
    assert(w.fx.self == 'npc_dota_hero_luna',
        'subject moved: ' .. tostring(w.fx.self))
    assert(w.fx.time == 1350.5, 'frame moved: t=' .. tostring(w.fx.time))
    assert(#w.real == 2, 'the slice carries ' .. #w.real .. ' watch towers, not 2')

    -- (B4): the named copies read the dump's numbers, not this file's.
    for i, u in ipairs(w.real) do
        local a, b = u:GetLocation(), w.outposts[i]:GetLocation()
        assert(a.x == b.x and a.y == b.y,
            'outpost handle ' .. i .. ' does not delegate its location')
        assert(u:GetTeam() == w.outposts[i]:GetTeam(),
            'outpost handle ' .. i .. ' does not delegate its team')
    end

    -- (B2): tier-2 is "down" because the slice carries no tier-2 tower at all.
    local opp = GetOpposingTeam()
    assert(GetTower(opp, TOWER_TOP_2) == nil
       and GetTower(opp, TOWER_MID_2) == nil
       and GetTower(opp, TOWER_BOT_2) == nil,
        'this slice now carries enemy tier-2 towers, so the mode body is no '
        .. 'longer reachable on it and every arm below is vacuous')

    -- One enemy-owned outpost within the mode's 3000u window: the geometry the
    -- bid is made of, read off the frame.
    local enemy = nil
    for _, u in ipairs(w.outposts) do
        if u:GetTeam() ~= GetTeam() then enemy = u end
    end
    assert(enemy ~= nil, 'no enemy-owned outpost on this frame')
    local d = GetUnitToUnitDistance(w.bot, enemy)
    assert(d < 3000, 'the enemy outpost is ' .. d .. 'u away, outside the window')
end

tests['[frame F2] on this frame UNIT_LIST_ALL carries no outpost at all']
= function()
    -- This is the frame the owed row asks for. It is also (B1): a supply gap
    -- used as a stand, not a measured game fact.
    local w = world()
    local n = 0
    for _, u in ipairs(w.raw_all) do
        local nm = u:GetUnitName()
        if nm == '#DOTA_OutpostName_North' or nm == '#DOTA_OutpostName_South' then
            n = n + 1
        end
    end
    assert(#w.raw_all > 0, 'UNIT_LIST_ALL is empty outright; the stand is vacuous')
    assert(n == 0, 'the loader now supplies ' .. n .. ' outposts through '
        .. 'UNIT_LIST_ALL -- the empty-sweep stand below is gone and this file '
        .. 'must be re-derived (the owed row wants the EMPTY case)')
end

-- ---------------------------------------------------------------------------
-- [frame] -- the two arms on the empty sweep
-- ---------------------------------------------------------------------------

tests['[frame F3] shipped: one sweep, then the mode is dead for the game']
= function()
    local w = world({ ids = {} })

    local first = w.desire()
    assert(first == DESIRE.BOT_ACTION_DESIRE_NONE,
        'shipped bid on an empty sweep is ' .. first .. ', expected NONE')
    assert(w.sweeps == 1, 'the first tick swept ' .. w.sweeps .. ' times')

    -- Six game seconds at 10Hz. Shipped may not sweep again: `DidWeGetOutpost`
    -- was set on the way out of the block regardless of what the sweep found.
    local last = tick(w, 6.0)
    assert(w.sweeps == 1,
        'shipped swept ' .. w.sweeps .. ' times over 61 ticks; the latch is '
        .. 'supposed to make that impossible')
    assert(last == DESIRE.BOT_ACTION_DESIRE_NONE,
        'shipped bid drifted to ' .. last .. ' with no outpost ever found')

    -- Now the outposts become enumerable. Shipped cannot notice: the only code
    -- that would ever look again is behind the latch.
    w.visible = true
    local after = tick(w, 6.0)
    assert(w.sweeps == 1,
        'shipped looked again after the outposts appeared (' .. w.sweeps .. ')')
    assert(after == DESIRE.BOT_ACTION_DESIRE_NONE,
        'shipped bid recovered to ' .. after .. ' without ever re-sweeping')
end

tests['[frame F4] armed: re-scans once per game second, then latches on the find']
= function()
    local w = world({ ids = { [CAND] = true } })

    local first = w.desire()
    assert(first == DESIRE.BOT_ACTION_DESIRE_NONE,
        'armed bid on an empty sweep is ' .. first .. ', expected NONE')
    assert(w.sweeps == 1, 'the first tick swept ' .. w.sweeps .. ' times')

    -- One game second of ticks: exactly one more sweep, i.e. the spacing is the
    -- declared OUTPOST_RESCAN_INTERVAL and not "every tick".
    tick(w, 1.0)
    assert(w.sweeps == 2,
        'armed swept ' .. w.sweeps .. ' times over the first game second; '
        .. 'expected 2 (t0 and t0+1.0)')

    -- Outposts become enumerable. The next scheduled scan finds them, the latch
    -- closes on the postcondition, and the mode comes alive.
    w.visible = true
    local after = tick(w, 5.0)
    assert(w.sweeps == 3,
        'armed swept ' .. w.sweeps .. ' times; expected exactly one more scan '
        .. 'after the outposts became enumerable, then the latch closes')
    assert(after > DESIRE.BOT_ACTION_DESIRE_NONE,
        'armed bid is still ' .. after .. ' after a sweep that saw the outpost')

    -- The number is the frame's own geometry, not a constant typed here.
    local enemy = nil
    for _, u in ipairs(w.outposts) do
        if u:GetTeam() ~= GetTeam() then enemy = u end
    end
    local expect = RemapValClamped(GetUnitToUnitDistance(w.bot, enemy),
        3000, 0, DESIRE.BOT_ACTION_DESIRE_VERYLOW, DESIRE.BOT_ACTION_DESIRE_HIGH)
    assert(math.abs(after - expect) < 1e-9,
        'armed bid ' .. after .. ' is not the frame geometry ' .. expect)
end

-- ---------------------------------------------------------------------------
-- [frame] -- controls
-- ---------------------------------------------------------------------------

tests['[frame F5] control: a first sweep that finds them -> armed == shipped']
= function()
    -- ⚠️ The two arms are run and read ONE AT A TIME. `GetUnitList`, `DotaTime`
    -- and `GetDesire` are globals, so two worlds alive at once share the second
    -- one's clock and count each other's sweeps -- measured, first draft of
    -- this file: the shipped arm read 0 sweeps and the armed arm 1, and the
    -- test failed for a reason that had nothing to do with the mode.
    local s = world({ ids = {}, visible = true })
    local ds = s.desire()
    tick(s, 6.0)
    local ss = s.sweeps

    local a = world({ ids = { [CAND] = true }, visible = true })
    local da = a.desire()
    tick(a, 6.0)
    local sa = a.sweeps

    assert(ds > DESIRE.BOT_ACTION_DESIRE_NONE,
        'the control does not reach the lever (shipped bid is NONE), so '
        .. '"arming changed nothing" here would be vacuous')
    assert(da == ds, 'arming moved the bid ' .. ds .. ' -> ' .. da
        .. ' on a frame whose first sweep already found the outposts')
    assert(ss == 1 and sa == 1,
        'sweep counts diverged on the already-working path: shipped '
        .. ss .. ', armed ' .. sa)
end

tests['[gate] control: armed but not turbo -> shipped'] = function()
    local w = world({ ids = { [CAND] = true }, turbo = false })
    w.desire()
    tick(w, 6.0)
    assert(w.sweeps == 1,
        'outside turbo the gate still re-scanned (' .. w.sweeps .. ' sweeps)')
end

tests['[gate] control: a DIFFERENT id armed -> shipped'] = function()
    -- 'outcommit' is the other id in this file. Arming it must not arm this one.
    local w = world({ ids = { outcommit = true } })
    w.desire()
    tick(w, 6.0)
    assert(w.sweeps == 1,
        "with only 'outcommit' armed this gate still re-scanned ("
        .. w.sweeps .. ' sweeps)')
end

-- ---------------------------------------------------------------------------

return tests

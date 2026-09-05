-- [outcommit 2026-09-05, 协同组] GH #511 handoff (乙). The outpost mode's bid is
-- a pure distance remap that tops out at BOT_ACTION_DESIRE_HIGH (0.75) and
-- returns the SAME number on the frame a capture channel starts as on the frame
-- it is 5.9s deep. Farm's own bid is a remap that reaches
-- BOT_MODE_DESIRE_VERYHIGH (0.9). So the seconds already sunk into a channel
-- buy nothing in arbitration, and W47 measured the consequence: 53 channels,
-- 13 completions, 40 aborts (75.5%), 66.6 hero-seconds burned, with 34 of 36
-- sampled aborts happening on frames where nothing in mode_outpost_generic had
-- changed. 'outcommit' raises the bid to VERYHIGH for exactly as long as THIS
-- bot's own channel is running.
--
-- ⭐ THE REUSABLE JUDGEMENT, and it is why this file exists at all rather than
-- the one-line guard the issue asked for: the issue's proposed fix
-- (`if bot:IsChanneling() then return end` at the top of Think) is a NO-OP --
-- Think's first statement is already `J.CanNotUseAction(bot)`, whose sixth
-- disjunct is `bot:IsChanneling()`. The interruption is therefore NOT this
-- file re-issuing over its own channel; every recorded cast is, by
-- construction, on a frame where IsChanneling() was already false. What is
-- missing is one level up: the mode never bids for the channel it is already
-- paying for. A finding of the form "the guard is missing" and a finding of the
-- form "the bid does not price the sunk cost" land in the same file and read
-- alike; only the second one can move anything here.
--
-- WHAT IS ASSERTED. Not gate plumbing. The shipped mode file is loaded and
-- driven -- twice, on the same REAL frame -- once with every candidate disarmed
-- and once with 'outcommit' armed, and the two numbers are compared. The frame
-- facts the decision rests on (distance to the outpost, the outpost's team, the
-- capture modifier and its remaining duration, hp, where the enemies are) are
-- read off the fixture, never retyped here.
--
-- REAL FRAME: 20260905_010205_slot7 (run spot_20260905_003250_1_...695907, seed
-- 4763, armed=dire, so luna on radiant is the BASELINE leg -- this defect is
-- not any armed id's). t=1350.5. luna stands 138u from the dire-owned outpost
-- at (3392,-448) with `modifier_watch_tower_capturing` on it, 1.3s remaining of
-- the ~6s capture. Slice: tests/fixtures/tl_260905_010205_luna_outchan.json.
--
-- ⚠️ HONEST BOUNDS, all five stated up front:
-- (1) DECLARED, and it is the only declaration: the two outposts are appended
--     to UNIT_LIST_ALL under their engine names. The corpus cannot supply it --
--     tests/mock/replay_fixture.lua says in its own comment that it injects no
--     structures into UNIT_LIST_ALL, and _outpost_gate_sweep.lua measures the
--     consequence (0 outposts in 993 entries). The handles are NOT invented:
--     each one delegates GetTeam/GetLocation/HasModifier/IsAlive to the real
--     building handle the loader built from the dump, and [frame F2] asserts
--     that delegation reads the dump's numbers rather than this file's.
-- (2) `bot:IsChanneling()` is not a dump column. It is DERIVED from the frame's
--     own events -- MODIFIER_ADD by actor luna at 1349.9, MODIFIER_REMOVE at
--     1351.8, and t=1350.5 strictly inside -- the same interval arithmetic that
--     produced the `remaining = 1.3` the fixture carries. It is set as ONE
--     field, and [frame F4] is the control that shows it load-bearing.
-- (3) The mode's own precondition `IsEnemyTier2Down` is true here for a HARNESS
--     reason: the slice carries only the two watch towers, so the loader's
--     GetTower answers nil for every slot. Identical in both arms, asserted
--     rather than assumed, never the subject of a claim. Same declaration
--     test_outlatch_scan_postcondition.lua makes as its S-A.
-- (4) 0.9 clears the shipped 0.75 and MATCHES the top of farm's remap. That the
--     raised bid wins every arbitration is NOT established offline and is not
--     claimed; what is shown is that it no longer sits below a bid the shipped
--     0.75 sat below. Whether the interruptions actually stop is condition (a),
--     and it is bought by re-running outlatch_capture.py on the next wave
--     (pre-fix baseline: armed 72% / base 79%, 53 attempts, 13 completions).
-- (5) The issue reports "5v5 throughout"; this frame's own unit table says
--     bristleback (dire) is dead at t=1350.5, i.e. 5v4 in luna's favour. The
--     fixture is the ground truth used here, and [frame F3] asserts the
--     outnumbered veto is clear FROM THE FRAME rather than from the issue.
-- (6) DOMAIN PRICE, measured over every snapshot instant in both checked-in
--     slices (30 luna frames + 18 axe frames, one fixture per instant, mode
--     driven on each):
--        luna  1344.5 .. 1360.5  -- 17 frames, shipped bid LIVE (0.59 .. 0.72);
--                                   the capture modifier is on the tower for
--                                   11 of them (1350.5 .. 1360.5)
--        luna  1361.5 .. 1373.5  -- 13 frames, shipped bid 0.0
--        axe   1014.4 .. 1031.4  -- 18 frames, shipped bid 0.0, ALL of them
--     ⚠️ and those 31 zeros are a HARNESS artifact, not a game fact, which is
--     why no assertion here counts them: the slices carry no ancient, so the
--     loader's GetAncient hands back a stand-in structure and
--     `J.GetEnemiesAroundAncient(bot, 3200) > 0` -- the mode's second veto --
--     starts answering 2 the moment two enemies wander within 3200 of THAT.
--     Same family as GH #171/#205: a zero attributable to a named supply gap,
--     not to a game condition. It is what made this file's first control
--     vacuous (see [frame F5]) and it is handed off in the round's report.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local MODE    = 'bots/mode_outpost_generic.lua'
local FX_CHAN = 'tests/fixtures/outchan/f_260905_010205_luna_channel.lua'
local FX_PRE  = 'tests/fixtures/outchan/f_260905_010205_luna_precast.lua'
local CAPMOD  = 'modifier_watch_tower_capturing'
local CAND    = 'outcommit'

-- The engine's numeric values, needed because the mock auto-defines ALL_CAPS
-- globals as distinct arbitrary numbers and this file compares MAGNITUDES.
local DESIRE = {
    BOT_MODE_DESIRE_NONE      = 0.0,
    BOT_ACTION_DESIRE_NONE    = 0.0,
    BOT_ACTION_DESIRE_VERYLOW = 0.1,
    BOT_ACTION_DESIRE_LOW     = 0.25,
    BOT_ACTION_DESIRE_HIGH    = 0.75,
    BOT_MODE_DESIRE_HIGH      = 0.75,
    BOT_MODE_DESIRE_VERYHIGH  = 0.9,
}

local SRC = io.open(MODE):read('*a')

--- Blank whole-line comments while preserving line numbers, so "in the code"
--- means in the code -- this file's own explanation quotes the statements it
--- pins, and a scanner that counts its own doc comment agrees with itself.
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local CODE = codeOnly(SRC)

local function count(src, needle)
    return select(2, src:gsub(needle:gsub('%W', '%%%0'), ''))
end

local function lineOf(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return nil end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

--- Load one real frame, wire the declared outpost enumeration, and hand back
--- the loaded mode's GetDesire plus a few instruments.
---
--- `dofile(MODE)` per call is deliberate: the mode file's state (`Outposts`,
--- `DidWeGetOutpost`, `IsEnemyTier2Down`) lives in file locals, so a fresh copy
--- per arm is what makes two arms comparable rather than sequential.
local function world(fixture, opts)
    opts = opts or {}
    local J, bot, _, fx = rf.load(fixture)
    for k, v in pairs(DESIRE) do _G[k] = v end

    local ids = opts.ids or {}
    J.IsSoakCandidate = function(id) return ids[id] == true end
    if opts.turbo == false then J.IsModeTurbo = function() return false end end

    -- Honest bound (2): the single declared field, derived from the frame's own
    -- MODIFIER_ADD/REMOVE interval. Absent here it defaults to the mock's
    -- `^Is -> false`, which is what [frame F4] drives.
    if opts.channeling then
        rawget(bot, '__spec').IsChanneling = true
    end

    -- Honest bound (1): the declared enumeration. Every reading below comes
    -- from the loader's own building handle -- this table adds a name and
    -- nothing else.
    local real = {}
    for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_BUILDINGS)) do
        if u:GetUnitName() == 'watch_tower' then real[#real + 1] = u end
    end
    for _, u in ipairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS)) do
        if u:GetUnitName() == 'watch_tower' then real[#real + 1] = u end
    end
    -- The dump's `#DOTA_OutpostName_North` is the one the frame's combat log
    -- names, and make_fixture.py's position vote already resolved that onto the
    -- (3392,-448) tower -- the enemy-owned one, which is `real[1]`. The mode
    -- filters on the two-name SET and does nothing else with the label, so the
    -- ordering below is a labelling convenience, asserted in [frame F2] rather
    -- than relied upon.
    local NAMES = { '#DOTA_OutpostName_North', '#DOTA_OutpostName_South' }
    local outposts = {}
    for i, u in ipairs(real) do
        outposts[i] = api.MakeUnit({
            GetUnitName    = NAMES[i],
            GetTeam        = function() return u:GetTeam() end,
            GetLocation    = function() return u:GetLocation() end,
            HasModifier    = function(_, s) return u:HasModifier(s) end,
            NumModifiers   = function() return u:NumModifiers() end,
            GetModifierName = function(_, k) return u:GetModifierName(k) end,
            GetModifierRemainingDuration = function(_, k)
                return u:GetModifierRemainingDuration(k)
            end,
            IsAlive        = function() return u:IsAlive() end,
            IsNull         = false,
            IsInvulnerable = false,
            CanBeSeen      = true,
        })
    end

    local prev = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        local base = prev(kind)
        if kind ~= UNIT_LIST_ALL then return base end
        local out = {}
        for _, u in ipairs(base) do out[#out + 1] = u end
        for _, u in ipairs(outposts) do out[#out + 1] = u end
        return out
    end

    dofile(MODE)

    return {
        J = J, bot = bot, fx = fx,
        desire = GetDesire,
        outposts = outposts,
        real = real,
    }
end

--- The shipped number on a frame: every candidate disarmed.
local function shipped(fixture, opts)
    opts = opts or {}
    opts.ids = {}
    return world(fixture, opts).desire()
end

--- The armed number on a frame: 'outcommit' and nothing else.
local function armed(fixture, opts)
    opts = opts or {}
    opts.ids = { [CAND] = true }
    return world(fixture, opts).desire()
end

-- ---------------------------------------------------------------------------
-- [source] -- the shape, read off the shipped tree
-- ---------------------------------------------------------------------------

tests['[source] the gate is one id wide and turbo-only'] = function()
    assert(count(CODE, "J.IsSoakCandidate('" .. CAND .. "')") == 1,
        "expected exactly one arming point for '" .. CAND .. "'")
    assert(count(CODE, 'J.IsSoakCandidate(') == 2,
        'mode_outpost_generic now carries ' .. count(CODE, 'J.IsSoakCandidate(')
        .. " soak ids; expected exactly 2 (the pre-existing 'outlatch' and "
        .. "'" .. CAND .. "') -- a third one means this file's before/after is "
        .. 'no longer isolating one lever')
    assert(CODE:find("J.IsModeTurbo() and J.IsSoakCandidate('" .. CAND .. "')", 1, true),
        'the gate is not turbo-only')
end

tests['[source] the lever sits BELOW every shipped veto'] = function()
    -- The whole conservatism claim is positional: armed behaviour may only
    -- differ on frames where the shipped tree already returned a capture bid.
    -- If the block ever moves above the in-vision abort or the suitability
    -- check, it can pin a bot in a fight and this assertion is the alarm.
    local gate  = lineOf(CODE, "J.IsSoakCandidate('" .. CAND .. "')")
    local remap = lineOf(CODE, 'return RemapValClamped(GetUnitToUnitDistance')
    local abort = lineOf(CODE, 'local nInRangeEnemy = J.GetEnemiesNearLoc(')
    local suit  = lineOf(CODE, 'and IsSuitableToCaptureOutpost()')
    assert(gate and remap and abort and suit, 'anchors moved in ' .. MODE)
    assert(suit < gate, 'the gate no longer sits below IsSuitableToCaptureOutpost')
    assert(abort < gate, 'the gate no longer sits below the in-vision abort')
    assert(gate < remap, 'the gate no longer sits above the shipped remap')
end

tests['[source] the issue\'s own proposed fix would be a no-op'] = function()
    -- Registered as a ratchet, per GH #511 §5: the day someone lands
    -- `if bot:IsChanneling() then return end` at the top of Think, this fails
    -- and says why. Think's first statement already evaluates that predicate.
    local think = CODE:find('function Think()', 1, true)
    assert(think, 'Think() moved')
    local first = CODE:sub(think):match('function Think%(%)%s*\n%s*([^\n]+)')
    assert(first == 'if J.CanNotUseAction(bot) then return end',
        "Think()'s first statement is now `" .. tostring(first) .. "`")
    local jmz = io.open('bots/FunLib/jmz_func.lua'):read('*a')
    local body = jmz:match('function J%.CanNotUseAction%(.-\nend')
    assert(body and body:find('or bot:IsChanneling()', 1, true),
        'J.CanNotUseAction no longer reads IsChanneling -- the reason this '
        .. "file's lever lives in GetDesire rather than in Think is gone")
    assert(not CODE:find('function Think()%s*\n%s*if bot:IsChanneling'),
        'somebody landed the redundant guard in Think(); this is a NO-OP, not '
        .. 'a fix -- the predicate is already evaluated one call down, and the '
        .. 'lever that matters is the bid in GetDesireHelper')
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real instant
-- ---------------------------------------------------------------------------

tests['[frame F1] the frame is the one GH #511 pins'] = function()
    local w = world(FX_CHAN)
    assert(w.fx.time == 1350.5, 't = ' .. tostring(w.fx.time))
    assert(w.fx.self == 'npc_dota_hero_luna', w.fx.self)
    assert(w.J.IsModeTurbo(), 'the fixture frame is not turbo')

    local op = w.outposts[1]
    local d = GetUnitToUnitDistance(w.bot, op)
    assert(d > 130 and d < 145, 'distance to the outpost is ' .. d .. ', not ~138')
    assert(d < 300, 'the frame is not inside the cast branch of Think')
    assert(op:GetTeam() ~= w.bot:GetTeam(), 'the outpost is already ours')
    assert(op:HasModifier(CAPMOD), 'the capture modifier is not on the outpost')
    local rem = op:GetModifierRemainingDuration(0)
    assert(rem > 1.0 and rem < 1.6, 'remaining reads ' .. rem .. ', not ~1.3')
    -- Full hp and nobody near: the interruption cannot be blamed on damage or
    -- on this file's own danger clauses. Read off the frame, not off the issue.
    assert(w.bot:GetHealth() == w.bot:GetMaxHealth(), 'the subject is not at full hp')
    assert(not w.bot:WasRecentlyDamagedByAnyHero(5), 'the subject took hero damage')
end

tests['[frame F2] the injected handles read the DUMP, not this file'] = function()
    -- Honest bound (1). If the proxies ever stop delegating, the numbers below
    -- become this file's opinion and every assertion above becomes circular.
    local w = world(FX_CHAN)
    assert(#w.real == 2, 'the frame carries ' .. #w.real .. ' watch towers, not 2')
    for i, u in ipairs(w.real) do
        local p = w.outposts[i]
        assert(p:GetTeam() == u:GetTeam(), 'proxy ' .. i .. ' invented a team')
        assert(p:GetLocation().x == u:GetLocation().x
            and p:GetLocation().y == u:GetLocation().y,
            'proxy ' .. i .. ' invented a location')
        assert(p:HasModifier(CAPMOD) == u:HasModifier(CAPMOD),
            'proxy ' .. i .. ' invented a modifier')
    end
    -- The labelling convenience, stated as a fact rather than assumed: the
    -- modifier-bearing tower is the enemy-owned one, and it is the one the
    -- mode will pick.
    assert(w.outposts[1]:HasModifier(CAPMOD), 'real[1] is not the captured tower')
    assert(not w.outposts[2]:HasModifier(CAPMOD), 'both towers carry the modifier')
end

tests['[frame F3] the shipped vetoes are all clear on this frame'] = function()
    -- Honest bounds (3) and (5). Everything the mode could refuse on is
    -- asserted CLEAR here, so the only thing separating the two arms below is
    -- the lever.
    local w = world(FX_CHAN)
    local opp = GetOpposingTeam()
    assert(GetTower(opp, TOWER_MID_2) == nil, 'an enemy tier-2 stands -- the '
        .. 'mode returns above the lever and this file measures nothing')
    local near = w.J.GetEnemiesNearLoc(w.bot:GetLocation(), w.bot:GetCurrentVisionRange())
    assert(near ~= nil and #near == 0,
        #near .. ' enemies in vision -- the <600u abort fires, not the lever')
    assert(w.J.GetNumOfAliveHeroes(false) >= w.J.GetNumOfAliveHeroes(true),
        'the outnumbered veto fires on this frame')
    -- And the shipped bid is in fact the distance remap, i.e. the mode wants
    -- this outpost with the gate shut. Without this the "raise" below could be
    -- a raise from NONE, which is a different and much wider change.
    local s = shipped(FX_CHAN, { channeling = true })
    assert(s > DESIRE.BOT_ACTION_DESIRE_NONE, 'the shipped bid is NONE')
    assert(s > 0.70 and s < DESIRE.BOT_ACTION_DESIRE_HIGH,
        'the shipped bid is ' .. s .. ', not the ~0.72 distance remap')
end

tests['[frame] armed, the mode holds the channel; unarmed it does not'] = function()
    local s = shipped(FX_CHAN, { channeling = true })
    local a = armed(FX_CHAN, { channeling = true })
    assert(a == DESIRE.BOT_MODE_DESIRE_VERYHIGH,
        'armed, the bid is ' .. a .. ' -- the lever does not reach this frame')
    assert(a > s, 'armed (' .. a .. ') does not outbid shipped (' .. s .. ')')
    -- The magnitude claim, bound (4): the raise clears farm's ceiling instead
    -- of merely nudging. A raise that still sat under 0.9 would change the
    -- number without changing the arbitration this lever is about.
    assert(s < DESIRE.BOT_MODE_DESIRE_VERYHIGH and a >= DESIRE.BOT_MODE_DESIRE_VERYHIGH,
        'the raise does not cross the bid that outbids it')
end

-- ---------------------------------------------------------------------------
-- [control] -- every zero below has a world that can make it non-zero
-- ---------------------------------------------------------------------------

tests['[frame F4] control: same frame, not channelling -> shipped'] = function()
    -- Honest bound (2) made load-bearing. If this passes only because the frame
    -- is special, arming would change the number here too.
    local s = shipped(FX_CHAN)
    local a = armed(FX_CHAN)
    assert(a == s, 'not channelling, arming still moved the bid ' .. s .. ' -> ' .. a)
    assert(a > 0.70 and a < DESIRE.BOT_ACTION_DESIRE_HIGH,
        'the control bid is ' .. a .. ', not the shipped distance remap')
end

tests['[frame F5] control: a REAL frame with no capture modifier -> shipped'] = function()
    -- The anti-vacuum control is another instant of the SAME approach, not a
    -- synthetic world: t=1349.5, one second before the first cast, luna 280u
    -- from the same outpost, walking in. The capture modifier is not on the
    -- tower yet -- and the lever must not fire yet either.
    --
    -- ⚠️ THE FIRST CONTROL THIS FILE TRIED WAS VACUOUS, and the mutation stand
    -- is what said so (M5 SURVIVED). It used t=1364.5, the 0.5s hole between
    -- the MODIFIER_REMOVE at 1364.3 and the next ADD at 1364.8 -- textbook on
    -- paper, and 138u from the tower. But on that frame the mode returns NONE
    -- five clauses EARLIER, at `J.GetEnemiesAroundAncient(bot, 3200) > 0`, so
    -- both arms answered 0.0 and "arming changed nothing" was true for a reason
    -- that had nothing to do with the modifier. A control frame has to reach
    -- the code it is controlling; the assertion below is what makes that a
    -- fact rather than a hope.
    local w = world(FX_PRE, { channeling = true })
    assert(w.fx.time == 1349.5, 't = ' .. tostring(w.fx.time))
    assert(not w.outposts[1]:HasModifier(CAPMOD),
        'the pre-cast frame carries the capture modifier after all')
    local d = GetUnitToUnitDistance(w.bot, w.outposts[1])
    assert(d > 270 and d < 300, 'the control frame is ' .. d .. 'u away, not ~280')

    local s = shipped(FX_PRE, { channeling = true })
    local a = armed(FX_PRE, { channeling = true })
    assert(s > DESIRE.BOT_ACTION_DESIRE_NONE,
        'the control frame does not reach the lever (shipped bid is NONE), so '
        .. '"arming changed nothing" here would be vacuous')
    assert(a == s, 'with no channel on the outpost, arming still moved the bid '
        .. s .. ' -> ' .. a)
end

tests['[gate] control: armed but not turbo -> shipped'] = function()
    local s = shipped(FX_CHAN, { channeling = true, turbo = false })
    local a = armed(FX_CHAN, { channeling = true, turbo = false })
    assert(a == s, 'outside turbo, arming still moved the bid ' .. s .. ' -> ' .. a)
end

tests['[gate] control: a DIFFERENT id armed -> shipped'] = function()
    -- 'outlatch' is the other id in this file. Arming it must not arm this one:
    -- a gate that answers to any armed string is a bundle, not a lever.
    local s = shipped(FX_CHAN, { channeling = true })
    local a = world(FX_CHAN, { channeling = true, ids = { outlatch = true } }).desire()
    assert(a == s, "with only 'outlatch' armed the bid moved " .. s .. ' -> ' .. a)
end

-- ---------------------------------------------------------------------------

return tests

-- [ratchet] [outlatch, GH #373] mode_outpost_generic latches on the ATTEMPT,
-- not on the RESULT: one sweep that returns no outpost kills the whole mode
-- for that bot for the rest of the game, silently and with no retry.
--
-- Family: backlog `0d`'s "the remaining mode files' continuous / queued
-- `Action_*` -- still unchecked". `mode_outpost_generic.lua:117`'s
-- `Action_AttackUnit(ClosestOutpost, false)` is the LAST continuous order left
-- in any mode file outside the roam pair (measured: grep over every
-- bots/mode_*.lua for `Action_AttackUnit(x, false)` / `Action_MoveToUnit` /
-- `ActionQueue_*` returns exactly that one line once mode_roam_generic and
-- mode_team_roam_generic are excluded). Reading it turned up something one
-- level ABOVE the order: the order's mode can never bid at all.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A latch must record the POSTCONDITION it gates, not the attempt.
--     `DidWeGetOutpost = true` is written unconditionally after a sweep whose
--     whole purpose is to fill `Outposts`. The name says "did we GET"; the
--     code says "did we LOOK". Whenever a do-this-once flag is set on the way
--     out of the block that was supposed to produce something, the empty
--     result is indistinguishable from the full one -- and it is permanent,
--     because the flag is the only thing that would ever run the producer
--     again.
--     Distinguish from the three same-family findings before it: GH #348 is
--     ORDER (a nil guard below the index it guards), GH #368 is SCOPE (a guard
--     naming a different variable than the consumer), GH #370 is an UNREPORTED
--     SIDE EFFECT (a callee that orders while reading like a query). Here the
--     producer, the flag and the consumer are all correct in isolation; what
--     is wrong is that the flag answers a different question than the consumer
--     asks.
--
-- The mechanism, static and provable by reading one file:
--
--   * `Outposts` has exactly ONE writer -- the `table.insert(Outposts, unit)`
--     inside the `if not DidWeGetOutpost` block -- and exactly ONE reader,
--     `GetClosestOutpost`. [source S2]
--   * the block sets `DidWeGetOutpost = true` after the sweep with no test on
--     what the sweep produced, so it never runs a second time. [source S1]
--   * `GetClosestOutpost` walks `Outposts[1..2]`; over an empty table it
--     returns `nil, 10000` forever.
--   * `GetDesireHelper`'s only non-NONE return sits behind
--     `ClosestOutpost ~= nil`, so the mode's desire is NONE for the rest of
--     the game and `Think` (and with it the continuous order at :117) is never
--     reached.
--
-- ⭐⭐ SECOND, INDEPENDENT CONSEQUENCE (registered, NOT fixed this round --
-- one lever at a time). `GetClosestOutpost`'s conjunction is
--     Outposts[i] ~= nil
--     and Outposts[i]:GetTeam() ~= GetTeam()
--     and GetUnitToUnitDistance(bot, Outposts[i]) < dist
--     and not Outposts[i]:IsNull()
--     and not Outposts[i]:IsInvulnerable()
-- Lua's `and` is left-to-right short-circuit, so `IsNull()` -- the guard whose
-- entire job is "this handle may have gone away" -- is evaluated FOURTH, after
-- two method calls on the very handle it guards. That is GH #348's shape in a
-- second file, and it is worth exactly as much as the handles are stale-able,
-- which is a direct consequence of the latch above: the table is populated
-- once and never refreshed. Pinned by [source S6] so the day it moves this
-- file is re-derived. Not fixed here.
--
-- REAL FRAME: tests/fixtures/f_260819_181742_ss_chase_start.lua -- game
-- 20260819_181742_slot1, subject shadow_shaman, t=312.5, real building table.
--
-- ⭐⭐⭐ WHAT THE REAL FRAME SAYS, AND WHAT IT CANNOT SAY. Two corpus readings,
-- both real, pull in opposite directions and both are pinned:
--
--   (A) On all 64 pinned frames that carry a building table, EVERY enemy
--       tier-2 tower is standing, so `IsEnemyTier2Down` is false and this
--       mode's entire body below that line is unreachable. The other 43
--       frames report "tier-2 down" for a harness reason only: they carry no
--       building table at all, so the loader's GetTower answers nil for every
--       slot. The two sets are EQUAL, not merely similar -- 43 = 43, verified
--       by set intersection, not by count. So no frame in this repo reaches
--       the latch on its own, and S-A below declares the mode's own
--       precondition rather than discovering it. [source S5] + the sweep in
--       tests/_outpost_gate_sweep.lua.
--   (B) `GetUnitList(UNIT_LIST_ALL)` carries 993 entries over the 107 pinned
--       frames and ZERO outposts -- but that zero is UNMEASURABLE, not EMPTY.
--       tests/mock/replay_fixture.lua says so in its own comment: the fixture
--       generator writes heroes and (separately) buildings, and the loader
--       deliberately injects neither creeps nor structures into UNIT_LIST_ALL.
--       Same distinction as GH #171/#205 and as GH #368's GetProperTarget
--       reading: the zero is attributable to a named supply gap, not to a game
--       condition. [frame F1]
--
-- ⚠️ LIMITS, declared:
--   * FREQUENCY IS UNKNOWN, and here that is a stronger caveat than usual.
--     This file proves the SHAPE (an empty sweep is permanent) and proves the
--     armed arm recovers where the shipped arm cannot. It does NOT establish
--     how often a real game's first post-tier-2 sweep comes back empty. In the
--     real engine UNIT_LIST_ALL is very likely to carry both outposts most of
--     the time; the value of the fix is bounded by how often it does not, and
--     THAT reading exists only in a replay (GH #373, baton to 录像组).
--   * Consequently the fix is GATED and makes no claim to be promotable on
--     this file alone.
--   * The engine's own semantics for UNIT_LIST_ALL (vision-limited? does it
--     carry outposts at all?) are NOT observable from this repo, so nothing
--     here asserts them.
--
-- LABELLED SYNTHETIC (declared; each one asserted where it matters):
--   S-A  enemy TOWER_MID_2 declared destroyed. Required to reach the latch at
--        all -- see reading (A). It is the mode's precondition, never the
--        subject of a claim: both arms get it, identically.
--   S-B  two outpost handles appended to UNIT_LIST_ALL on the LATER frame.
--        This is the whole point of the difference under test ("the world
--        later contains what the first sweep missed"), and the corpus cannot
--        supply it -- see reading (B). Both arms get the identical injection;
--        the assertion is about which arm can still see it. The PLACEMENT is
--        chosen, and the choice is a real-frame fact worth stating: mirrored
--        to the bot's other side the frame's own IsEnemyCloserToOutpostLoc
--        vetoes it (real GetHeroLastSeenInfo data -- an enemy was seen inside
--        5s nearer to that point than the bot is), so the mode would bid NONE
--        for a reason that has nothing to do with the latch. Both of the
--        frame's vetoes are asserted CLEAR at the placement used, so the only
--        thing separating the two arms below is the latch.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'
local MODE    = 'bots/mode_outpost_generic.lua'

local DESIRE = {
    BOT_MODE_DESIRE_NONE      = 0.0,
    BOT_ACTION_DESIRE_NONE    = 0.0,
    BOT_ACTION_DESIRE_VERYLOW = 0.1,
    BOT_ACTION_DESIRE_LOW     = 0.25,
    BOT_ACTION_DESIRE_HIGH    = 0.75,
}

local SRC_MODE = io.open(MODE):read('*a')

--- Blank every whole-line Lua comment while PRESERVING line numbering, so a
--- count or a line lookup means "in code", not "anywhere in the file". The doc
--- comment above the fix quotes the very statements this file pins; without
--- this the scanner counts its own explanation (GH #370 hit exactly that, and
--- GH #341/#345 are the tool-side family).
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local CODE = codeOnly(SRC_MODE)

--- The body of GetClosestOutpost, extracted by its two NEIGHBOURS rather than
--- by a lazy `.-\nend`.
---
--- ⚠️ METHOD SELF-HARM, recorded because it passed silently for one run: the
--- obvious pattern `function GetClosestOutpost%(%).-\nend` stops at the FIRST
--- `\nend` in the body, which is the nested `if`'s -- so it returned a
--- truncated function and a count over it under-reported the reads by one,
--- while still matching a plausible expected number. A scanner that returns
--- less than it claims to fails by AGREEING with you. Same family as GH
--- #341/#345 (a tool that never evaluates the clause it says it reads) and as
--- the comment-counting self-harm in GH #370.
local GETTER = (function()
    local a = CODE:find('function GetClosestOutpost()', 1, true)
    local b = CODE:find('function IsEnemyCloserToOutpostLoc(', 1, true)
    assert(a and b and a < b, 'GetClosestOutpost must sit above IsEnemyCloserToOutpostLoc')
    return CODE:sub(a, b - 1)
end)()

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

--- Build the world, apply S-A, and load a FRESH copy of the mode (dofile gives
--- the mode file's locals -- `Outposts`, `DidWeGetOutpost`, the rescan clock --
--- a new set every call, which is what makes two arms comparable).
---
--- Returns the J table plus a handful of instruments:
---   sweeps()   how many times the mode has swept UNIT_LIST_ALL
---   reveal()   S-B: from now on UNIT_LIST_ALL also carries the two outposts
---   clock(dt)  advance DotaTime by dt on an otherwise frozen frame
local function world(opts)
    opts = opts or {}
    local ids = opts.ids or {}
    local J, bot = rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function(id) return ids[id] == true end
    if opts.turbo == false then J.IsModeTurbo = function() return false end end

    -- S-A. One slot, declared, identical in both arms.
    local opp = GetOpposingTeam()
    local realTower = GetTower
    GetTower = function(team, slot) -- luacheck: ignore
        if team == opp and slot == TOWER_MID_2 then return nil end
        return realTower(team, slot)
    end

    -- S-B, armed on demand. ~1530u from the subject: inside the mode's 3000u
    -- interest ring, outside its 600u "abort if any enemy is in vision" ring,
    -- and away from where this frame's last-seen enemies are, so none of those
    -- three clauses is what any assertion below is reading. All three are
    -- asserted clear in [frame F3].
    local here = bot:GetLocation()
    local outposts = {}
    for i, nm in ipairs({ '#DOTA_OutpostName_North', '#DOTA_OutpostName_South' }) do
        outposts[i] = api.MakeUnit({
            GetUnitName     = nm,
            GetTeam         = opp,
            GetLocation     = api.Vector(here.x - 1500 * i, here.y - 300 * i, here.z),
            IsNull          = false,
            IsInvulnerable  = false,
            IsAlive         = true,
        })
    end

    local revealed = false
    local sweeps = 0
    local realList = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        local base = realList(kind)
        if kind ~= UNIT_LIST_ALL then return base end
        sweeps = sweeps + 1
        if not revealed then return base end
        local out = {}
        for _, u in ipairs(base) do out[#out + 1] = u end
        for _, u in ipairs(outposts) do out[#out + 1] = u end
        return out
    end

    local t0 = DotaTime()
    local realClock = DotaTime
    local offset = 0
    DotaTime = function() return t0 + offset end -- luacheck: ignore

    dofile(MODE)

    return J, bot, {
        sweeps  = function() return sweeps end,
        reveal  = function() revealed = true end,
        clock   = function(dt) offset = offset + dt end,
        restore = function() DotaTime = realClock end, -- luacheck: ignore
        outposts = outposts,
        t0 = t0,
    }
end

-- ---------------------------------------------------------------------------
-- [source] -- the shape, read off the shipped tree
-- ---------------------------------------------------------------------------

tests['[source S1] the latch is written exactly once, and only the gate makes it conditional'] = function()
    assert(count(CODE, 'local DidWeGetOutpost = false') == 1,
        'expected exactly one declaration of DidWeGetOutpost')
    local n = count(CODE, 'DidWeGetOutpost = ') - 1
    assert(n == 1, 'expected exactly 1 assignment to DidWeGetOutpost (beyond the '
        .. 'declaration) in code; got ' .. n)

    assert(CODE:find('DidWeGetOutpost = not bRescan or #Outposts > 0', 1, true) ~= nil,
        'the latch must read `not bRescan or #Outposts > 0`: shipped (gate shut) is the '
        .. 'unconditional true byte for byte, armed records the postcondition')

    -- Shipped equivalence, proved rather than asserted by inspection: with
    -- bRescan false the expression is `true or ...`, which Lua short-circuits
    -- before ever measuring the table.
    local bRescan, Outposts = false, {}
    assert((not bRescan or #Outposts > 0) == true, 'gate shut must latch unconditionally')
    bRescan = true
    assert((not bRescan or #Outposts > 0) == false, 'gate open on an empty sweep must NOT latch')
    Outposts = { 1, 2 }
    assert((not bRescan or #Outposts > 0) == true, 'gate open on a full sweep must latch')
end

tests['[source S2] Outposts has one writer and one reader, so an empty table is permanent'] = function()
    local writes = count(CODE, 'table.insert(Outposts')
    assert(writes == 1, 'expected exactly 1 writer of Outposts; got ' .. writes)

    -- Readers: the declaration, the writer, the two indexed reads and the two
    -- guarded method calls inside GetClosestOutpost, the length test in the
    -- latch. Any NEW mention means somebody else can now fill or empty the
    -- table and this whole file must be re-derived.
    local mentions = count(CODE, 'Outposts')
    assert(mentions == 10,
        'expected exactly 10 mentions of Outposts IN CODE (1 declaration, 1 insert, '
        .. '1 length test in the latch, 7 inside GetClosestOutpost); got ' .. mentions)

    local getter = GETTER
    assert(count(getter, 'Outposts') == 7,
        'all seven reads of Outposts must live inside GetClosestOutpost; got '
        .. count(getter, 'Outposts'))
    assert(getter:find('for i = 1, 2', 1, true) ~= nil,
        'GetClosestOutpost walks a fixed 1..2 range, so an empty table yields nil')
end

tests['[source S3] the gate is turbo-only, named, and evaluated once'] = function()
    assert(count(CODE, "J.IsSoakCandidate('outlatch')") == 1,
        "expected exactly one J.IsSoakCandidate('outlatch') call site")
    assert(CODE:find('local bRescan = J.IsModeTurbo() and J.IsSoakCandidate(\'outlatch\')', 1, true) ~= nil,
        'the candidate must be conjoined with IsModeTurbo at a single hoisted site')
    assert(count(CODE, 'bRescan') == 3,
        'expected exactly 3 mentions of bRescan (the hoisted assignment, the throttle '
        .. 'test, the latch); got ' .. count(CODE, 'bRescan'))
end

tests['[source S4] the retry is bounded, and the bound lives INSIDE the gate'] = function()
    local lGate     = lineOf(CODE, 'local bRescan =')
    local lThrottle = lineOf(CODE, 'if DotaTime() < NextOutpostScanTime')
    local lSweep    = lineOf(CODE, 'for _, unit in pairs(GetUnitList(UNIT_LIST_ALL))')
    local lLatch    = lineOf(CODE, 'DidWeGetOutpost = not bRescan')
    assert(lGate and lThrottle and lSweep and lLatch, 'all four statements must exist in code')
    assert(lGate < lThrottle and lThrottle < lSweep and lSweep < lLatch,
        string.format('expected gate < throttle < sweep < latch; got %d < %d < %d < %d',
            lGate, lThrottle, lSweep, lLatch))

    -- The throttle sits under `if bRescan then`, so the shipped path never
    -- evaluates it. Pinned by position: the only `if bRescan` block opens
    -- above the throttle and closes above the sweep.
    local head = CODE:sub(1, CODE:find('for _, unit in pairs(GetUnitList(UNIT_LIST_ALL))', 1, true))
    assert(head:find('if bRescan', 1, true) < CODE:find('if DotaTime() < NextOutpostScanTime', 1, true),
        'the throttle must be inside the `if bRescan` block')
end

tests['[source S6] REGISTERED, NOT FIXED: IsNull is the 4th conjunct, after two calls on the handle it guards'] = function()
    local getter = GETTER
    local pTeam  = getter:find('Outposts[i]:GetTeam()', 1, true)
    local pDist  = getter:find('GetUnitToUnitDistance(bot, Outposts[i])', 1, true)
    local pNull  = getter:find('not Outposts[i]:IsNull()', 1, true)
    assert(pTeam and pDist and pNull, 'the three conjuncts must all be present')
    assert(pTeam < pNull and pDist < pNull,
        'this file DOCUMENTS the defect: IsNull() is evaluated after GetTeam() and after '
        .. 'GetUnitToUnitDistance() on the same handle. If this assertion ever flips, the '
        .. 'sibling defect was fixed and GH #373 must be re-read, not silently passed')
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real frame, and the corpus facts it stands on
-- ---------------------------------------------------------------------------

tests['[frame F1] on the real frame the sweep is empty, and the zero is UNMEASURABLE not EMPTY'] = function()
    local _, bot = rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    local all = GetUnitList(UNIT_LIST_ALL)
    assert(#all == 10, 'expected the frame\'s 10 live heroes in UNIT_LIST_ALL; got ' .. #all)
    local outposts = 0
    for _, u in ipairs(all) do
        local nm = u:GetUnitName()
        if nm == '#DOTA_OutpostName_North' or nm == '#DOTA_OutpostName_South' then
            outposts = outposts + 1
        end
    end
    assert(outposts == 0, 'the corpus supplies no outpost; got ' .. outposts)

    -- ATTRIBUTION, which is what makes this UNMEASURABLE rather than EMPTY:
    -- the loader says in its own comment that it injects neither creeps nor
    -- structures into UNIT_LIST_ALL. Pin the sentence, not the number.
    local loader = io.open('tests/mock/replay_fixture.lua'):read('*a')
    assert(loader:find('Buildings are', 1, true) ~= nil
        and loader:find('deliberately NOT injected here', 1, true) ~= nil,
        'the loader must still declare the UNIT_LIST_ALL supply gap; if that comment '
        .. 'moved, re-derive whether the zero above is still a harness fact')

    assert(bot:IsAlive() and bot:IsHero() and not bot:IsIllusion() and not bot:IsInvulnerable(),
        'the subject must clear the mode\'s own liveness test on the real frame')
end

tests['[frame F5] the real frame\'s enemy tier-2 towers all stand, so S-A is a declaration'] = function()
    rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end
    local opp = GetOpposingTeam()
    for _, slot in ipairs({ TOWER_TOP_2, TOWER_MID_2, TOWER_BOT_2 }) do
        assert(GetTower(opp, slot) ~= nil,
            'this frame carries a real building table with every enemy tier-2 standing; '
            .. 'that is why S-A has to declare one down to reach the latch at all')
    end
end

tests['[frame F2] SHIPPED: one empty sweep and the mode is dead, even after the world changes'] = function()
    local _, _, w = world()

    local d1 = GetDesireHelper()
    assert(d1 == BOT_ACTION_DESIRE_NONE, 'empty sweep must yield NONE; got ' .. tostring(d1))
    assert(w.sweeps() == 1, 'the first desire call must sweep once; got ' .. w.sweeps())
    assert(GetClosestOutpost() == nil, 'an empty Outposts table has no closest member')

    -- The world now contains both outposts. Give the shipped arm every chance:
    -- many frames, and a clock well past anything a retry could wait on.
    w.reveal()
    for _ = 1, 20 do
        w.clock(1.0)
        assert(GetDesireHelper() == BOT_ACTION_DESIRE_NONE, 'shipped stays NONE')
    end

    assert(w.sweeps() == 1,
        'shipped must never sweep again -- the latch is the only thing that would '
        .. 'run the producer, and it was closed on the empty result; got ' .. w.sweeps())
    assert(GetClosestOutpost() == nil,
        'shipped can no longer see an outpost that is now plainly in the world')
    w.restore()
end

tests['[frame F3] ARMED: the latch stays open on an empty sweep and closes on the full one'] = function()
    local _, _, w = world({ ids = { outlatch = true } })

    local d1 = GetDesireHelper()
    assert(d1 == BOT_ACTION_DESIRE_NONE, 'an empty sweep still yields NONE this frame')
    assert(w.sweeps() == 1, 'first sweep; got ' .. w.sweeps())
    assert(GetClosestOutpost() == nil, 'nothing found yet')

    w.reveal()
    w.clock(1.0)
    local d2 = GetDesireHelper()

    assert(w.sweeps() == 2, 'armed must sweep again once the throttle expires; got ' .. w.sweeps())
    local closest, dist = GetClosestOutpost()
    assert(closest ~= nil, 'armed finds the outpost the shipped arm can no longer see')
    assert(dist and dist < 3000, 'the declared outpost sits inside the interest ring; got '
        .. tostring(dist))

    -- The three clauses that could ALSO make this bid NONE are the real
    -- frame's, not the latch's. Assert each is clear so the difference between
    -- the arms cannot be blamed on any of them.
    assert(dist > 600, 'outside the "any enemy in vision" abort ring; got ' .. tostring(dist))
    assert(IsSuitableToCaptureOutpost() == true, 'the real frame permits capturing here')
    assert(IsEnemyCloserToOutpostLoc(closest:GetLocation(), dist) == false,
        'no enemy was last seen nearer this point than the bot is -- real '
        .. 'GetHeroLastSeenInfo data; mirrored to the bot\'s other side this same '
        .. 'frame DOES veto, which is why S-B declares a placement')

    assert(d2 > BOT_ACTION_DESIRE_NONE,
        'and the mode can finally bid: got ' .. tostring(d2))

    -- Latched now: no further sweeps, so the single writer cannot run twice
    -- and Outposts cannot accumulate duplicates.
    for _ = 1, 5 do w.clock(1.0); GetDesireHelper() end
    assert(w.sweeps() == 2, 'a successful sweep must close the latch for good; got ' .. w.sweeps())
    w.restore()
end

tests['[frame F4] the retry is throttled: no sweep inside the interval'] = function()
    local _, _, w = world({ ids = { outlatch = true } })

    GetDesireHelper()
    assert(w.sweeps() == 1, 'first sweep')

    for _ = 1, 9 do
        w.clock(0.1)
        assert(GetDesireHelper() == BOT_ACTION_DESIRE_NONE, 'still nothing to find')
    end
    assert(w.sweeps() == 1,
        'nine frames inside the 1.0s interval must not re-sweep; got ' .. w.sweeps())

    w.clock(0.2)
    GetDesireHelper()
    assert(w.sweeps() == 2, 'crossing the interval must re-sweep; got ' .. w.sweeps())
    w.restore()
end

tests['[control] turbo-only: armed outside turbo is the shipped arm exactly'] = function()
    local _, _, w = world({ ids = { outlatch = true }, turbo = false })

    assert(GetDesireHelper() == BOT_ACTION_DESIRE_NONE)
    assert(w.sweeps() == 1)

    w.reveal()
    for _ = 1, 20 do w.clock(1.0); GetDesireHelper() end

    assert(w.sweeps() == 1,
        'outside turbo the gate is shut and the latch is unconditional; got ' .. w.sweeps())
    assert(GetClosestOutpost() == nil, 'and the mode is dead exactly as shipped')
    w.restore()
end

tests['[control] the arms are indistinguishable until the world supplies an outpost'] = function()
    local _, _, wa = world()
    local shipped = {}
    for _ = 1, 10 do wa.clock(1.0); shipped[#shipped + 1] = GetDesireHelper() end
    local shippedSweeps = wa.sweeps()
    wa.restore()

    local _, _, wb = world({ ids = { outlatch = true } })
    local armed = {}
    for _ = 1, 10 do wb.clock(1.0); armed[#armed + 1] = GetDesireHelper() end
    wb.restore()

    for i = 1, 10 do
        assert(shipped[i] == armed[i],
            'desire must match frame ' .. i .. ': ' .. tostring(shipped[i])
            .. ' vs ' .. tostring(armed[i]))
    end
    assert(shippedSweeps == 1, 'shipped sweeps once')
    -- The armed arm keeps looking; that IS the difference, and it costs one
    -- GetUnitList sweep per second per bot until something is found.
    assert(wb.sweeps() > shippedSweeps,
        'armed must keep retrying while the table is empty; got ' .. wb.sweeps())
end

return tests

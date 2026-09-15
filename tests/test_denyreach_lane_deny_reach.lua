-- [denyreach / charter 0NEXT18 / P4.4(i)] THE DENY BRANCH HAS NO DISTANCE TERM.
--
-- THE DEFECT, in one line: eleven lines apart in the same Think, the last-hit
-- branch tests reach twice and the deny branch never tests it once -- and the
-- deny branch is the one reading the WIDER ring.
--
--   last-hit  nEnemyCreeps = bot:GetNearbyLaneCreeps(  800, true  )
--             + `GetUnitToUnitDistance(bot, hitCreep) > botAttackRange`
--             + `... > botAttackRange * 0.8`   -> moves instead of swinging
--   deny      nAllyCreeps  = bot:GetNearbyLaneCreeps( 1200, false )
--             + nothing.  Action_AttackUnit at whatever distance.
--
-- GetBestDenyCreep filters on HEALTH only (`J.GetHP(creep) < 0.49` and
-- `creep:GetHealth() <= attackDamage`); no position is read anywhere on that
-- path.  Section 1 is that whole claim ratcheted term by term against shipped
-- source, because it is a statement about CODE and must not be satisfiable by
-- a comment (every identifier it names is also named in this header).
--
-- ⭐⭐ WHY IT IS WORTH AN ID.  `Action_AttackUnit` on a unit 1100 away is a walk
-- order with an attack on the end, and a deny candidate is by construction a
-- creep already under fire in the middle of the wave -- down the lane, toward
-- the enemy.  Worse, the branch `return`s, and it sits ABOVE the lane-front
-- block whose last act is `J.IsLaneFrontTooDeepToHold` -- the guard the
-- mega-bundle review added precisely so a laner never holds a shoved-deep front
-- alone.  So an out-of-reach deny is the one way into this Think that walks the
-- bot down the lane with the anti-overextend clamp never asked.  Section 1c
-- pins that source order.
--
-- ⭐ THE REPAIR INTRODUCES NO NEW NUMBER: the bound is `bot:GetAttackRange()`
-- and the operator is `>`, both lifted verbatim from the sibling branch.  That
-- is deliberate -- an invented constant is a second thing to defend, and this
-- desk has spent rounds pricing exactly those (GH #788 / #793 / #811).
--
-- ⛔ WHAT THIS FILE CAN AND CANNOT BUY, stated before any number below.
--
--   * The dumper writes `{t, team, x, y}` per creep and NO health and NO name
--     (GH #581).  So the HP half of GetBestDenyCreep -- hence how often the
--     selector returns anything at all -- is NOT readable from a fixture, today
--     or by trying harder.  This file therefore NEVER reports a trigger
--     frequency.  What it reports is GEOMETRY, which is exactly the half the
--     helper turns on, and it is an UPPER bound on the branch's reachable set:
--     the unreadable HP filter can only shrink it.
--   * `GetAttackRange()` is NOT in the dump either.  Under the loader every
--     unit answers the mock's melee default, so the reach used in section 2 is
--     a DECLARED bound, not a corpus reading, and section 2 sweeps it on
--     purpose rather than quoting it: the flip has to be produced by moving the
--     bound, which is what proves the predicate reads both of its terms instead
--     of answering a constant.
--   * The creep POSITIONS in section 2 and section 3 are real: they are read
--     out of the fixture's own `creeps` block, the same rows the loader serves.
--     Only "this creep is a legal deny candidate" is declared.
--
-- ⭐ THE ANTI-VACUUM IS NOT A SWAPPED TALLY.  Section 2 drives the SAME four
-- real rows under two declared bounds and requires 4 drops under one and 0
-- under the other.  A predicate that never ran, or that answered a constant,
-- fails one of the two halves.  (Charter 0NEXT13 丑: swapping the legs of a
-- tally proves nothing when the domain is empty; here the domain is non-empty
-- under both halves by construction.)

package.path = 'tests/?.lua;' .. package.path
local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')
local ss  = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local tests = {}

local LANING = 'bots/mode_laning_generic.lua'
local JMZ    = 'bots/FunLib/jmz_func.lua'

-- The one fixture under tests/fixtures/ that carries BOTH a creep sample and a
-- laning-phase subject.  Its allied creep rows are the real geometry this file
-- reads; `LION_LEVEL` pins the frame so a regenerated fixture cannot silently
-- become a different instant underneath the numbers below.
local LION_FIX   = 'tests/fixtures/f_20260909_212625_lion_235.lua'
local LION       = 'npc_dota_hero_lion'
local LION_LEVEL = 4

-- The second creep-carrying fixture.  Its allied rows are all sampled at
-- dt ~= 0 (the dumper samples creeps on its own 3s cadence), so they are OFF
-- the subject's instant and are reported separately in section 3 rather than
-- pooled into the headline.
local ZUUS_FIX = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'
local ZUUS     = 'npc_dota_hero_zuus'

-- ---------------------------------------------------------- source reading --

local function read(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a'); fh:close()
    return s
end

--- Structural facts are claims about CODE.  This file names every identifier it
--- asserts, and so does the shipped source, so a raw-text match would let a
--- COMMENT satisfy the assertion.
local function mask_comments(s)
    s = s:gsub('%-%-%[%[.-%]%]', ' ')
    return (s:gsub('%-%-[^\n]*', ' '))
end

local function count(s, needle)
    local n, at = 0, 1
    while true do
        local i = s:find(needle, at, true)
        if i == nil then break end
        n, at = n + 1, i + 1
    end
    return n
end

local function at(s, needle)
    return s:find(needle, 1, true) or -1
end

--- The core laning `Think`, comment-free.  EVERY offset in section 1 is taken
--- inside it: `DoSupportLaningThink` holds a second deny branch with the same
--- two lines, and a file-wide anchor would silently measure that one instead
--- while the source-order assertion still passed.
local function think_fn()
    local src = mask_comments(read(LANING))
    local a = assert(src:find('if bCustomLastHit or bSupLastHit', 1, true),
        'the core laning Think guard moved')
    return src:sub(a)
end

--- `DoSupportLaningThink`, comment-free -- the sibling site this round
--- deliberately does NOT wire.
local function support_fn()
    local src = mask_comments(read(LANING))
    local a = assert(src:find('local function DoSupportLaningThink()', 1, true),
        'DoSupportLaningThink moved')
    local b = assert(src:find('\nend\n', a, true), 'DoSupportLaningThink has no end')
    return src:sub(a, b)
end

--- The helper body, comment-free.
local function helper_fn()
    local src = mask_comments(read(JMZ))
    local a = assert(src:find('function J.ShouldDropOutOfReachDeny', 1, true),
        'J.ShouldDropOutOfReachDeny is gone')
    local b = assert(src:find('\nend\n', a, true), 'the helper has no end')
    return src:sub(a, b)
end

-- ------------------------------------------------------------- real frames --

--- Load one fixture in the HONEST turbo world (GH #93: by name the fixture
--- world is Turbo, by the literal 23 it is not, and the gate opens with
--- J.IsModeTurbo).
local function world(path, subject)
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    local J, _, heroes = rf.load(path, subject)
    GAMEMODE_TURBO = 23                                -- luacheck: ignore
    GetGameMode = function() return 23 end             -- luacheck: ignore
    local bot = assert(heroes[subject],
        'fixture no longer carries ' .. subject .. ' -- ' .. path)
    return J, bot
end

local function unturbo()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return 22 end             -- luacheck: ignore
end

--- The subject's own row, straight out of the fixture table (not the loader),
--- so the creep rows below and the bot position come from the same read.
local function frame(path, subject)
    local fx = dofile(path)
    local me
    for _, u in ipairs(fx.units) do
        if u.name == subject then me = u end
    end
    assert(me ~= nil, path .. ' no longer carries ' .. subject)
    assert(fx.creeps ~= nil and #fx.creeps > 0,
        path .. ' no longer carries a creep sample -- this file reads REAL '
        .. 'creep geometry and must not fall back to invented coordinates')
    return fx, me
end

--- Allied creep rows, with their true distance from the subject.  `bSameInstant`
--- keeps only rows sampled AT the subject's instant (dt == 0); the dumper
--- samples creeps on its own cadence, so the others describe a different moment
--- and are never pooled with these.
local function ally_rows(fx, me, bSameInstant)
    local out = {}
    for _, c in ipairs(fx.creeps) do
        if c.team == me.team
            and (not bSameInstant or math.abs(c.dt or 0) < 1e-6) then
            local dx, dy = c.x - me.x, c.y - me.y
            out[#out + 1] = { x = c.x, y = c.y, d = math.sqrt(dx * dx + dy * dy) }
        end
    end
    table.sort(out, function(p, q) return p.d < q.d end)
    return out
end

--- A DECLARED stand-in for a legal deny candidate, standing on a REAL allied
--- creep coordinate.  Health is declared because GH #581 leaves it unreadable;
--- the position is not declared, and the position is the only thing the helper
--- under test looks at.
local function deny_candidate(row)
    return api.MakeUnit({
        GetUnitName = 'npc_dota_creep_goodguys_melee',
        GetHealth   = 120,
        GetMaxHealth = 550,
        IsNull      = false,
        CanBeSeen   = true,
        IsAlive     = true,
        IsBuilding  = false,
        IsHero      = false,
        IsIllusion  = false,
        GetLocation = api.Vector(row.x, row.y, 0),
    })
end

--- Answer the helper on `rows` with the bot's reach DECLARED at `nReach`.
--- Returns how many rows it says to drop.
local function drops(J, bot, rows, nReach)
    bot.GetAttackRange = function() return nReach end
    local n = 0
    for _, r in ipairs(rows) do
        if J.ShouldDropOutOfReachDeny(bot, deny_candidate(r)) then n = n + 1 end
    end
    return n
end

ss.assert_clean('test_denyreach_lane_deny_reach')

--============================================================================
-- 1. THE SHAPE, read from shipped source.
--
-- [ratchet], not [source]: 开工自检's fast Lua leg finds files by that tag, and
-- these blocks scan shipped source that ANY desk's landing can redden (a new
-- deny call site, a moved branch).  Untagged, that red is found hours later by
-- the next desk to start work -- GH #624's立案 shape.  Timed before tagging as
-- that leg's header requires: 0.05s for the whole file.
--============================================================================

tests['[ratchet] the deny branch reads the 1200 ring, the last-hit branch the 800'] = function()
    local src = mask_comments(read(LANING))
    assert(count(src, 'bot:GetNearbyLaneCreeps(1200, false)') == 1,
        'nAllyCreeps is no longer the single 1200 ally-creep read')
    assert(count(src, 'bot:GetNearbyLaneCreeps(800, true)') == 1,
        'nEnemyCreeps is no longer the single 800 enemy-creep read')
    -- The whole point: the wider list feeds the branch with no reach test.
    assert(at(src, 'nAllyCreeps = bot:GetNearbyLaneCreeps(1200, false)') > 0,
        'the deny branch no longer reads the 1200 list')
end

tests['[ratchet] GetBestDenyCreep reads health only -- no position term'] = function()
    local src = mask_comments(read(LANING))
    local a = assert(src:find('function GetBestDenyCreep(hCreepList)', 1, true),
        'GetBestDenyCreep moved')
    local b = assert(src:find('\nend\n', a, true), 'GetBestDenyCreep has no end')
    local body = src:sub(a, b)
    -- Health terms present...
    assert(body:find('J.GetHP(creep) < 0.49', 1, true), 'the HP fraction filter moved')
    assert(body:find('creep:GetHealth() <= attackDamage', 1, true),
        'the lethality filter moved')
    -- ...and not one distance term.  If this ever goes red the SELECTOR grew a
    -- reach bound, which would make the branch-level guard below redundant --
    -- re-read the round, do not delete the assertion.
    assert(not body:find('Distance', 1, true),
        'GetBestDenyCreep now reads a distance -- the defect this id addresses '
        .. 'may have been fixed upstream; re-price before keeping the gate')
    assert(not body:find('AttackRange', 1, true),
        'GetBestDenyCreep now reads an attack range -- re-price this id')
end

tests['[ratchet] the last-hit branch tests reach twice, in the same Think'] = function()
    local fn = think_fn()
    -- TWO tests, and the first literal is a PREFIX of the second -- so the
    -- count of the prefix is 2 and the count of the `* 0.8` form is 1, which is
    -- what "exactly one bare test and exactly one walk-up test" reduces to.
    -- (Asserting `== 1` on the prefix is the mistake this comment exists to
    -- stop: it reads as the stricter claim and is simply false.)
    assert(count(fn, 'GetUnitToUnitDistance(bot, hitCreep) > botAttackRange') == 2,
        "the last-hit branch no longer carries exactly two reach tests")
    assert(count(fn, 'GetUnitToUnitDistance(bot, hitCreep) > botAttackRange * 0.8') == 1,
        "the last-hit branch's walk-up reach test moved")
end

tests['[ratchet] the deny branch returns ABOVE the deep-front clamp'] = function()
    local fn = think_fn()
    local nDeny  = at(fn, 'local denyCreep = GetBestDenyCreep(nAllyCreeps)')
    local nClamp = at(fn, 'J.IsLaneFrontTooDeepToHold(bot, target_loc)')
    assert(nDeny > 0, 'the core-Think deny branch moved')
    assert(nClamp > 0, 'the deep-front clamp moved out of the core Think')
    -- This ordering IS the second half of the defect: every frame the deny
    -- branch takes is a frame IsLaneFrontTooDeepToHold is never asked.
    assert(nDeny < nClamp,
        'the deny branch no longer precedes the deep-front clamp -- the '
        .. 'skipped-guard half of this id no longer holds; re-read the round')
    -- ...and it really does return, rather than falling through to it.
    local tail = fn:sub(nDeny, nClamp)
    assert(tail:find('bot:Action_AttackUnit(denyCreep, true)', 1, true),
        'the deny branch no longer issues the attack order')
    assert(tail:find('return', 1, true), 'the deny branch no longer returns')
end

tests['[ratchet] the guard is wired into the core deny branch as a NARROWING'] = function()
    local fn = think_fn()
    -- `and not` is what makes the direction a fact about the source rather than
    -- a claim about a count: appended to a conjunction that already passed, it
    -- can only turn TRUE into FALSE.
    assert(fn:find('if J.IsValid(denyCreep)\n\t\tand not J.ShouldDropOutOfReachDeny(bot, denyCreep) then',
        1, true),
        'the denyreach conjunct is not wired as `and not` on the core deny branch')
    assert(count(fn, 'J.ShouldDropOutOfReachDeny') == 1,
        'the core Think names J.ShouldDropOutOfReachDeny '
        .. count(fn, 'J.ShouldDropOutOfReachDeny') .. ' times; one call site per id')
end

tests['[ratchet] the SUPPORT deny branch is still unguarded, on purpose'] = function()
    local fn = support_fn()
    -- Registered as a deliberate non-action (GH #767 §6.2's shape).  The two
    -- sites sit behind different armed populations, so one id across both would
    -- make a per-id verdict unattributable (GH #29).  If this goes red someone
    -- wired it -- which is fine, but it needs its OWN id and its own pricing,
    -- not this one's.
    assert(fn:find('local denyCreep = GetBestDenyCreep(nAllyCreeps)', 1, true),
        'the support deny branch moved')
    assert(not fn:find('ShouldDropOutOfReachDeny', 1, true),
        'the support deny branch is now guarded too -- one id must not move two '
        .. 'call sites; give it its own id and re-price')
end

tests['[ratchet] the helper gates FIRST, turbo SECOND, and names one id'] = function()
    local body = helper_fn()
    assert(count(body, 'IsSoakCandidate') == 1,
        'the helper names ' .. count(body, 'IsSoakCandidate')
        .. " candidate ids; it must name exactly one (the 'pullcad' trap, GH #622)")
    assert(count(body, "IsSoakCandidate( 'denyreach' )") == 1,
        "the helper no longer gates on 'denyreach'")
    local nGate  = at(body, "IsSoakCandidate( 'denyreach' )")
    local nTurbo = at(body, 'IsModeTurbo')
    local nWork  = at(body, 'GetUnitToUnitDistance')
    assert(nGate < nTurbo, 'turbo is asked before the gate -- unarmed, this '
        .. 'reaches an engine call it must not reach')
    assert(nTurbo < nWork, 'the helper does work before asking turbo')
    -- No new constant: the bound is the sibling branch's own.
    assert(body:find('bot:GetAttackRange()', 1, true),
        'the bound is no longer the bot\'s own attack range')
    assert(not body:find('1200', 1, true),
        'the helper hard-codes the ring width; the bound must be the reach')
end

--============================================================================
-- 2. THE DECISION, on real creep coordinates from a real laning frame.
--============================================================================

tests['[decision] armed, every real allied creep row in the ring is out of melee reach'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me, true)
    assert(#rows == 4, 'the lion frame used to carry 4 same-instant allied creep '
        .. 'rows, now ' .. #rows .. ' -- the section 3 census is stale')

    local J, bot = world(LION_FIX, LION)
    assert(bot:GetLevel() == LION_LEVEL, string.format(
        'the frame moved: %s used to carry %s at level %d, now %d',
        LION_FIX, LION, LION_LEVEL, bot:GetLevel()))

    local ok, err = pcall(function()
        ss.arm('denyreach')
        -- Melee reach.  All four real rows (275 / 357 / 409 / 761) are beyond it.
        assert(drops(J, bot, rows, 150) == 4,
            'armed at melee reach, the helper does not drop all four out-of-reach rows')
        -- ⭐ ANTI-VACUUM, same rows, bound moved to beyond the farthest of them.
        -- A predicate that never ran, or one answering a constant, fails here.
        assert(drops(J, bot, rows, 800) == 0,
            'armed at reach 800 the helper still drops rows inside reach -- it is '
            .. 'not reading the bound')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

tests['[decision] armed, the flip happens AT the bound and nowhere else'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me, true)
    local J, bot = world(LION_FIX, LION)
    local nNear = rows[1].d          -- 275: the closest real row

    local ok, err = pcall(function()
        ss.arm('denyreach')
        -- Strictly inside -> keep; exactly at the bound -> keep (the sibling
        -- branch's own `>`, not `>=`); strictly beyond -> drop.
        local one = { rows[1] }
        assert(drops(J, bot, one, nNear + 1) == 0, 'a creep inside reach is dropped')
        assert(drops(J, bot, one, nNear) == 0,
            'a creep exactly at the bound is dropped -- the operator drifted off '
            .. "the sibling branch's `>`")
        assert(drops(J, bot, one, nNear - 1) == 1,
            'a creep one unit beyond reach is kept')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

tests['[gate] disarmed the answer is FALSE on every row, at every bound'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me, true)
    local J, bot = world(LION_FIX, LION)
    ss.assert_clean('test_denyreach_lane_deny_reach / disarmed leg')
    -- The rows that section 2 proves the ARMED helper drops.  Unarmed it must
    -- answer false on all of them, or the shipped tree is not byte-identical.
    assert(drops(J, bot, rows, 150) == 0,
        'disarmed, the helper still drops rows -- the gate is not first')
end

tests['[gate] armed but NOT turbo, the answer is FALSE on every row'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me, true)
    local J, bot = world(LION_FIX, LION)
    local ok, err = pcall(function()
        ss.arm('denyreach')
        unturbo()
        assert(drops(J, bot, rows, 150) == 0,
            'armed outside turbo the helper still drops rows -- this id is '
            .. 'turbo-only and nothing on this path asks turbo for us')
        ss.assert_still_armed()
    end)
    GetGameMode = function() return 23 end             -- luacheck: ignore
    ss.finish(ok, err)
end

tests['[gate] armed, a nil or invalid creep is never dropped'] = function()
    local J, bot = world(LION_FIX, LION)
    local ok, err = pcall(function()
        ss.arm('denyreach')
        assert(J.ShouldDropOutOfReachDeny(bot, nil) == false,
            'the helper drops a nil creep -- it would narrow a branch J.IsValid '
            .. 'had already closed, and it must not reach GetUnitToUnitDistance')
        assert(J.ShouldDropOutOfReachDeny(nil, nil) == false,
            'the helper answers on a nil bot')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

--============================================================================
-- 3. THE EXPOSURE, and what it is NOT.
--
-- These are REAL allied-creep rows at REAL distances.  They are an UPPER bound
-- on the deny branch's reachable set and NEVER a trigger frequency: GH #581
-- leaves creep health out of the dump, so whether any given row is a legal deny
-- candidate is unreadable.  The unreadable filter can only SHRINK the set.
--============================================================================

local WORLD = {
    lion_same_instant = 4,   -- allied rows at dt == 0, inside 1200
    lion_beyond_150   = 4,
    lion_beyond_550   = 1,
    zuus_off_instant  = 5,   -- allied rows at dt ~= 0, inside 1200
    zuus_beyond_150   = 5,
    zuus_beyond_550   = 2,
}

tests['[world] every real allied creep row inside the 1200 ring is beyond melee reach'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me, true)
    local nRing, n150, n550 = 0, 0, 0
    for _, r in ipairs(rows) do
        if r.d <= 1200 then
            nRing = nRing + 1
            if r.d > 150 then n150 = n150 + 1 end
            if r.d > 550 then n550 = n550 + 1 end
        end
    end
    assert(nRing == WORLD.lion_same_instant, 'the lion ring population moved: '
        .. nRing .. ' vs recorded ' .. WORLD.lion_same_instant)
    assert(n150 == WORLD.lion_beyond_150, 'beyond-melee count moved: ' .. n150)
    assert(n550 == WORLD.lion_beyond_550, 'beyond-550 count moved: ' .. n550)
    -- ⭐ ANTI-VACUUM: the ring is non-empty AND the two thresholds disagree, so
    -- "everything is beyond reach" cannot be satisfied by an empty walk or by a
    -- classifier that answers a constant.
    assert(nRing > 0, 'the ring is empty -- this exposure reading says nothing')
    assert(n550 < n150, 'the two thresholds agree exactly; the distances are '
        .. 'not being read')
end

tests['[world] the second creep fixture is OFF-INSTANT and is reported apart'] = function()
    local fx, me = frame(ZUUS_FIX, ZUUS)
    local nSame = #ally_rows(fx, me, true)
    local rows  = ally_rows(fx, me, false)
    -- The dumper samples creeps on its own cadence; on this frame NO allied row
    -- shares the subject's instant.  That is exactly why its rows are not
    -- pooled into the headline above -- and asserting the zero is what keeps
    -- that sentence from silently becoming false.
    assert(nSame == 0, 'the zuus frame now carries ' .. nSame .. ' same-instant '
        .. 'allied rows; it may now be poolable -- re-read section 3')
    local nRing, n150, n550 = 0, 0, 0
    for _, r in ipairs(rows) do
        if r.d <= 1200 then
            nRing = nRing + 1
            if r.d > 150 then n150 = n150 + 1 end
            if r.d > 550 then n550 = n550 + 1 end
        end
    end
    assert(nRing == WORLD.zuus_off_instant, 'the zuus ring population moved: ' .. nRing)
    assert(n150 == WORLD.zuus_beyond_150, 'beyond-melee count moved: ' .. n150)
    assert(n550 == WORLD.zuus_beyond_550, 'beyond-550 count moved: ' .. n550)
end

tests['[world] the recorded exposure is internally consistent and is a bound'] = function()
    assert(WORLD.lion_beyond_150 <= WORLD.lion_same_instant,
        'more rows beyond melee reach than rows in the ring')
    assert(WORLD.lion_beyond_550 <= WORLD.lion_beyond_150,
        'the 550 subset is not contained in the 150 subset')
    assert(WORLD.zuus_beyond_550 <= WORLD.zuus_beyond_150
        and WORLD.zuus_beyond_150 <= WORLD.zuus_off_instant,
        'the zuus subsets do not nest')
    -- The headline this file is allowed to state, and its exact shape.
    assert(WORLD.lion_beyond_150 + WORLD.zuus_beyond_150 == 9
        and WORLD.lion_same_instant + WORLD.zuus_off_instant == 9,
        'the 9-of-9 headline no longer matches the recorded rows')
end

return tests

-- [supdenyrange / charter 0NEXT18 / P4.4(i)] THE SUPPORT DENY BRANCH HAS NO
-- DISTANCE TERM EITHER -- and it returns above four guards, not one.
--
-- THE DEFECT, in one line: in DoSupportLaningThink the deny branch reads the
-- 1200 ally ring and never tests reach, while the uncontested-last-hit branch a
-- few lines below tests it twice.  That is the same shape 'denyreach' repaired
-- in the core laning Think, at the OTHER call site.
--
--   deny        nAllyCreeps  = bot:GetNearbyLaneCreeps( 1200, false )
--               + nothing.  Action_AttackUnit at whatever distance.
--   last-hit    + `GetUnitToUnitDistance(bot, hitCreep) > botAttackRange`
--               + `... > botAttackRange * 0.8`   -> moves instead of swinging
--
-- ⭐⭐ WHY IT IS A SECOND ID AND NOT A WIDENING OF THE FIRST.  The two sites sit
-- behind DIFFERENT armed populations, and that is a fact about source, asserted
-- in section 1d rather than asserted in prose: the core Think body runs with
-- every gate off (`bCustomLastHit` is `local_mode_laning_generic`), while this
-- branch is reached only through `if bSupLastHit or bLaneFixSupport then
-- DoSupportLaningThink()`, i.e. only when 'suplh' / 'lanefix' / 'lf_support' is
-- armed.  One id across both would make a per-id verdict unattributable
-- (GH #29) AND would take this id's reading on a population that only exists
-- when another candidate is armed.  Section 2's cross-arm legs are the
-- behavioural half of the same claim: arming either id must move exactly one
-- helper.
--
-- ⭐⭐ WHY IT IS WORTH ITS OWN PRICE.  At the core site the out-of-reach deny
-- returns above ONE guard.  This branch is the FIRST statement of the support
-- Think, so it returns above FOUR later blocks -- the uncontested last-hit (the
-- support's only lane gold), the harass block, the 'lanefix' screen-the-carry
-- block (itself narrowed after a final-gate reject), and the lane-front hold
-- whose last act is `J.IsLaneFrontTooDeepToHold`, the anti-overextend clamp.
-- Section 1c pins that source order term by term.  And the unit being walked
-- down the lane toward the enemy wave is a support.
--
-- ⛔ THE ID IS NOT 'supdenyreach'.  'denyreach' would be a substring of it.  The
-- runtime matcher compares ids exactly (`SoakStrArms`), so the game would be
-- fine -- but every unanchored grep over an armed string, a verdict table,
-- state.json or test_set.md would then read a wave arming this id as arming the
-- core one too, and per-id attributability is the whole reason there are two.
--
-- ⛔ WHAT THIS FILE DOES NOT BUY, stated before any number below.
--
--   * It does NOT re-buy the geometry census.  The corpus is the same two
--     frames the sibling file already read, and reporting them again here would
--     turn ONE reading into two citable ones (charter 计量三条 (iii)).  Section
--     3 instead asserts that the sibling file still holds those numbers, and
--     quotes them as its own domain evidence.
--   * Creep HEALTH is not in the dump (GH #581), so how often
--     `GetBestDenyCreep` returns anything is unreadable.  This file therefore
--     never reports a trigger frequency; the geometry is an UPPER bound on the
--     branch's reachable set, since the unreadable filter can only shrink it.
--   * `GetAttackRange()` is not in the dump either, so the reach in section 2
--     is a DECLARED bound and is SWEPT on purpose rather than quoted: the flip
--     has to be produced by moving the bound, which is what proves the
--     predicate reads both of its terms instead of answering a constant.
--   * The creep POSITIONS are real -- read out of the fixture's own `creeps`
--     block.  Only "this creep is a legal deny candidate" is declared.

package.path = 'tests/?.lua;' .. package.path
local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')
local ss  = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local tests = {}

local LANING  = 'bots/mode_laning_generic.lua'
local JMZ     = 'bots/FunLib/jmz_func.lua'
local SIBLING = 'tests/test_denyreach_lane_deny_reach.lua'

-- The one fixture under tests/fixtures/ carrying BOTH a creep sample and a
-- laning-phase subject -- and the subject is a position-5 lion, which is the
-- hero this call site exists for.  `LION_LEVEL` pins the frame so a regenerated
-- fixture cannot silently become a different instant underneath the numbers.
local LION_FIX   = 'tests/fixtures/f_20260909_212625_lion_235.lua'
local LION       = 'npc_dota_hero_lion'
local LION_LEVEL = 4

-- ---------------------------------------------------------- source reading --

local function read(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a'); fh:close()
    return s
end

--- Structural facts are claims about CODE, and this file names every identifier
--- it asserts -- so does the shipped source.  A raw-text match would let a
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

--- `DoSupportLaningThink`, comment-free.  EVERY offset in section 1 is taken
--- inside it: the core laning Think holds the sibling deny branch with nearly
--- the same two lines, and a file-wide anchor would silently measure THAT one
--- while the source-order assertions still passed.
local function support_fn()
    local src = mask_comments(read(LANING))
    local a = assert(src:find('local function DoSupportLaningThink()', 1, true),
        'DoSupportLaningThink moved')
    local b = assert(src:find('\nend\n', a, true), 'DoSupportLaningThink has no end')
    return src:sub(a, b)
end

--- The core laning `Think`, comment-free -- the sibling site, which this id
--- must NOT move.
local function think_fn()
    local src = mask_comments(read(LANING))
    local a = assert(src:find('if bCustomLastHit or bSupLastHit', 1, true),
        'the core laning Think guard moved')
    return src:sub(a)
end

--- This id's helper body, comment-free.
local function helper_fn()
    local src = mask_comments(read(JMZ))
    local a = assert(src:find('function J.ShouldDropOutOfReachSupportDeny', 1, true),
        'J.ShouldDropOutOfReachSupportDeny is gone')
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

--- Allied creep rows at the subject's own instant (dt == 0), with their true
--- distance.  The dumper samples creeps on its own cadence; rows off the
--- subject's instant describe a different moment and are never used here.
local function ally_rows(fx, me)
    local out = {}
    for _, c in ipairs(fx.creeps) do
        if c.team == me.team and math.abs(c.dt or 0) < 1e-6 then
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

--- Answer `fn` on `rows` with the bot's reach DECLARED at `nReach`.  Returns
--- how many rows it says to drop.  `fn` is a parameter rather than baked in
--- because the cross-arm legs drive BOTH helpers through this one counter.
local function drops(fn, bot, rows, nReach)
    bot.GetAttackRange = function() return nReach end
    local n = 0
    for _, r in ipairs(rows) do
        if fn(bot, deny_candidate(r)) then n = n + 1 end
    end
    return n
end

ss.assert_clean('test_supdenyrange_support_deny_reach')

--============================================================================
-- 1. THE SHAPE, read from shipped source.
--
-- [ratchet], not [source]: 开工自检's fast Lua leg finds files by that tag, and
-- these blocks scan shipped source that ANY desk's landing can redden (a new
-- deny call site, a moved branch).  Untagged, that red is found hours later by
-- the next desk to start work -- GH #624's立案 shape.  Timed before tagging as
-- that leg's header requires ("if you are about to add a tag here, TIME the
-- resulting set first"): 0.19s wall for the whole file, interpreter startup
-- included -- inside the band that leg's members have never left.
--============================================================================

tests['[ratchet] 1a the support deny branch reads the 1200 ring and tests reach never'] = function()
    local fn = support_fn()
    assert(fn:find('local denyCreep = GetBestDenyCreep(nAllyCreeps)', 1, true),
        'the support deny branch moved')
    -- The list it is handed is the WIDE one, built once at the top of the file.
    local src = mask_comments(read(LANING))
    assert(count(src, 'nAllyCreeps = bot:GetNearbyLaneCreeps(1200, false)') == 1,
        'nAllyCreeps is no longer the single 1200 ally-creep read')
    -- And the branch itself reads no position of its own: the ONLY distance
    -- term inside this function is the one the guard adds, which is a call, not
    -- a comparison.  If this goes red the branch grew a reach test of its own
    -- and this id is redundant -- re-price, do not delete the assertion.
    assert(not fn:find('GetUnitToUnitDistance(bot, denyCreep)', 1, true),
        'the support deny branch now measures the deny creep itself -- re-price '
        .. 'this id before keeping the gate')
end

tests['[ratchet] 1b the support last-hit branch, just below, tests reach twice'] = function()
    local fn = support_fn()
    -- TWO tests, and the first literal is a PREFIX of the second -- so the count
    -- of the prefix is 2 and the count of the `* 0.8` form is 1.  (Asserting
    -- `== 1` on the prefix reads as the stricter claim and is simply false; the
    -- sibling file carries the same warning for the same reason.)
    assert(count(fn, 'GetUnitToUnitDistance(bot, hitCreep) > botAttackRange') == 2,
        'the support last-hit branch no longer carries exactly two reach tests')
    assert(count(fn, 'GetUnitToUnitDistance(bot, hitCreep) > botAttackRange * 0.8') == 1,
        "the support last-hit branch's walk-up reach test moved")
    -- The asymmetry is the finding: the branch WITHOUT the reach test is the one
    -- reading the wider ring, and it comes FIRST.
    assert(at(fn, 'local denyCreep = GetBestDenyCreep(nAllyCreeps)')
        < at(fn, 'GetSupportUncontestedLastHitCreep(nEnemyCreeps)'),
        'the deny branch no longer precedes the last-hit branch')
end

tests['[ratchet] 1c the deny branch returns ABOVE four later blocks'] = function()
    local fn = support_fn()
    local nDeny    = at(fn, 'local denyCreep = GetBestDenyCreep(nAllyCreeps)')
    local nLastHit = at(fn, 'GetSupportUncontestedLastHitCreep(nEnemyCreeps)')
    local nHarass  = at(fn, 'J.WeAreStronger(bot, 1200)')
    local nScreen  = at(fn, 'J.GetLaneCoreToProtect( bot )')
    local nClamp   = at(fn, 'J.IsLaneFrontTooDeepToHold(bot, target_loc)')
    for name, off in pairs({ deny = nDeny, lasthit = nLastHit, harass = nHarass,
                             screen = nScreen, clamp = nClamp }) do
        assert(off > 0, 'the support Think no longer contains the ' .. name
            .. ' block -- this id\'s cost half is measured against it')
    end
    -- THIS is the half that makes the support site cost more than the core one:
    -- everything below is skipped on every frame the deny branch takes.
    assert(nDeny < nLastHit and nLastHit < nHarass and nHarass < nScreen
        and nScreen < nClamp,
        'the support Think\'s block order moved; the "returns above four '
        .. 'guards" claim is re-read, not assumed')
    -- ...and it really does return, rather than falling through to them.
    local head = fn:sub(nDeny, nLastHit)
    assert(head:find('bot:Action_AttackUnit(denyCreep, true)', 1, true),
        'the support deny branch no longer issues the attack order')
    assert(head:find('return', 1, true),
        'the support deny branch no longer returns -- if it now falls through, '
        .. 'the skipped-guard half of this id is gone; re-read the round')
end

tests['[ratchet] 1d the two call sites really do sit behind different gates -- and THIS one is BUNDLE-ONLY'] = function()
    local src = mask_comments(read(LANING))
    -- ⛔ THIS LEG IS ALSO THE SINGLE-ARM-ZERO REGISTRATION (GH #606 shape).  The
    -- host function is gated, and this id's helper has exactly one call site
    -- inside it, so a wave arming 'supdenyrange' ALONE measures a structural
    -- zero -- while check_armed_wiring.py answers WIRED, because WIRED means "a
    -- call site exists on this tree" and says so in its own LIMITS block.  The
    -- verdict would read back "tested, no effect" with nothing raising a hand.
    -- The id must be armed as a BUNDLE (`suplh,supdenyrange`, or
    -- `lf_support,supdenyrange`) with the host id alone as the reference leg.
    -- If these assertions go red because the host stopped being gated, that is
    -- GOOD NEWS for this id and the constraint should be lifted deliberately --
    -- in state.json and in the helper header, not by deleting the leg.
    -- The support Think is reached ONLY under the two gated flags...
    assert(count(src, 'if bSupLastHit or bLaneFixSupport then') == 1,
        'the support Think is no longer entered through exactly one guarded '
        .. 'branch -- the "different armed population" claim must be re-read')
    assert(src:find("local bSupLastHit = J.IsModeTurbo() and J.IsSoakCandidate('suplh')",
        1, true), 'bSupLastHit is no longer the suplh gate')
    assert(src:find('local bLaneFixSupport = J.IsModeTurbo()', 1, true),
        'bLaneFixSupport is no longer a turbo-gated flag')
    -- ...while the core Think's own body needs no candidate at all, because
    -- bCustomLastHit is just "the native laning module is present".
    assert(src:find('local bCustomLastHit = local_mode_laning_generic', 1, true),
        'bCustomLastHit is no longer ungated -- if BOTH sites are now gated the '
        .. 'two ids may no longer be independent; re-price before promoting')
    assert(not src:find('local bCustomLastHit = local_mode_laning_generic\n\t\tand J',
        1, true), 'bCustomLastHit grew a conjunct')
end

tests['[ratchet] 1e the guard is wired as a NARROWING, and only here'] = function()
    local fn = support_fn()
    -- `and not` appended to a conjunction that already passed can only turn TRUE
    -- into FALSE: direction is a fact about the source, not a claim about a count.
    assert(fn:find('if J.IsValid(denyCreep)\n\tand not J.ShouldDropOutOfReachSupportDeny(bot, denyCreep) then',
        1, true),
        'the supdenyrange conjunct is not wired as `and not` on the support deny branch')
    assert(count(fn, 'J.ShouldDropOutOfReachSupportDeny') == 1,
        'the support Think names J.ShouldDropOutOfReachSupportDeny '
        .. count(fn, 'J.ShouldDropOutOfReachSupportDeny')
        .. ' times; one call site per id')
    -- The mirror of the sibling file's leg: THIS id must not reach into the core
    -- Think either.  Without both halves, "one id, one call site" only holds in
    -- one direction.
    assert(not think_fn():find('ShouldDropOutOfReachSupportDeny', 1, true),
        "the core laning Think now calls this id's helper -- one id must not "
        .. "move two call sites; the core site has its own id ('denyreach')")
end

tests['[ratchet] 1f the helper gates FIRST, turbo SECOND, and names one id'] = function()
    local body = helper_fn()
    assert(count(body, 'IsSoakCandidate') == 1,
        'the helper names ' .. count(body, 'IsSoakCandidate')
        .. " candidate ids; it must name exactly one (the 'pullcad' trap, GH #622)")
    assert(count(body, "IsSoakCandidate( 'supdenyrange' )") == 1,
        "the helper no longer gates on 'supdenyrange'")
    -- The id must stay one that 'denyreach' is NOT a substring of, or every
    -- unanchored grep over an armed string reports this id's wave as arming the
    -- core one too.
    assert(not body:find('denyreach', 1, true),
        "this id's name now contains 'denyreach' as a substring -- unanchored "
        .. 'greps over armed strings and verdict tables would conflate the two '
        .. 'ids, which is the one thing having two ids is for')
    local nGate  = at(body, "IsSoakCandidate( 'supdenyrange' )")
    local nTurbo = at(body, 'IsModeTurbo')
    local nWork  = at(body, 'GetUnitToUnitDistance')
    assert(nGate < nTurbo, 'turbo is asked before the gate -- unarmed, this '
        .. 'reaches an engine call it must not reach')
    assert(nTurbo < nWork, 'the helper does work before asking turbo')
    -- No new constant: the bound is the sibling branch's own.
    assert(body:find('bot:GetAttackRange()', 1, true),
        "the bound is no longer the bot's own attack range")
    assert(not body:find('1200', 1, true),
        'the helper hard-codes the ring width; the bound must be the reach')
end

--============================================================================
-- 2. THE DECISION, on real creep coordinates from a real laning frame.
--============================================================================

tests['[decision] armed, every real allied creep row in the ring is out of melee reach'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    assert(#rows == 4, 'the lion frame used to carry 4 same-instant allied creep '
        .. 'rows, now ' .. #rows .. ' -- section 3 is stale')

    local J, bot = world(LION_FIX, LION)
    assert(bot:GetLevel() == LION_LEVEL, string.format(
        'the frame moved: %s used to carry %s at level %d, now %d',
        LION_FIX, LION, LION_LEVEL, bot:GetLevel()))

    local ok, err = pcall(function()
        ss.arm('supdenyrange')
        -- Melee reach.  All four real rows (275 / 357 / 409 / 761) are beyond it.
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, rows, 150) == 4,
            'armed at melee reach, the helper does not drop all four out-of-reach rows')
        -- ⭐ ANTI-VACUUM, same rows, bound moved beyond the farthest of them.  A
        -- predicate that never ran, or one answering a constant, fails here.
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, rows, 800) == 0,
            'armed at reach 800 the helper still drops rows inside reach -- it is '
            .. 'not reading the bound')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

tests['[decision] armed, the flip happens AT the bound and nowhere else'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    local J, bot = world(LION_FIX, LION)
    local nNear = rows[1].d          -- 275: the closest real row

    local ok, err = pcall(function()
        ss.arm('supdenyrange')
        local one = { rows[1] }
        -- Strictly inside -> keep; exactly at the bound -> keep (the sibling
        -- branch's own `>`, not `>=`); strictly beyond -> drop.
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, one, nNear + 1) == 0,
            'a creep inside reach is dropped')
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, one, nNear) == 0,
            'a creep exactly at the bound is dropped -- the operator drifted off '
            .. "the sibling branch's `>`")
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, one, nNear - 1) == 1,
            'a creep one unit beyond reach is kept')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

tests['[gate] disarmed the answer is FALSE on every row, at every bound'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    local J, bot = world(LION_FIX, LION)
    ss.assert_clean('test_supdenyrange_support_deny_reach / disarmed leg')
    -- The rows section 2 proves the ARMED helper drops.  Unarmed it must answer
    -- false on all of them, or the shipped tree is not byte-identical.
    assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, rows, 150) == 0,
        'disarmed, the helper still drops rows -- the gate is not first')
end

tests['[gate] armed but NOT turbo, the answer is FALSE on every row'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    local J, bot = world(LION_FIX, LION)
    local ok, err = pcall(function()
        ss.arm('supdenyrange')
        unturbo()
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, rows, 150) == 0,
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
        ss.arm('supdenyrange')
        assert(J.ShouldDropOutOfReachSupportDeny(bot, nil) == false,
            'the helper drops a nil creep -- it would narrow a branch J.IsValid '
            .. 'had already closed, and it must not reach GetUnitToUnitDistance')
        assert(J.ShouldDropOutOfReachSupportDeny(nil, nil) == false,
            'the helper answers on a nil bot')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

--============================================================================
-- 2b. THE TWO IDS ARE INDEPENDENT, measured rather than argued.
--
-- Section 1e pins that each helper has one call site.  These two legs pin the
-- other half: arming one id moves ONE helper.  Without them, "two ids" is a
-- naming convention -- a body that gated on the sibling's id, or a shared
-- helper reached through two names, would satisfy every structural assertion
-- above and every behavioural one in section 2.
--============================================================================

tests['[decision] arming the SIBLING id does not move this helper'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    local J, bot = world(LION_FIX, LION)
    local ok, err = pcall(function()
        ss.arm('denyreach')
        -- The core id is armed, so ITS helper drops all four (non-vacuous: this
        -- half proves the arm landed and the rows are droppable)...
        assert(drops(J.ShouldDropOutOfReachDeny, bot, rows, 150) == 4,
            "arming 'denyreach' no longer moves its own helper -- this leg is "
            .. 'measuring nothing')
        -- ...and THIS one stays silent on the very same rows.
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, rows, 150) == 0,
            "arming 'denyreach' also moves the support helper -- the two ids are "
            .. 'not independent and neither verdict would be attributable')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

tests['[decision] arming THIS id does not move the sibling helper'] = function()
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    local J, bot = world(LION_FIX, LION)
    local ok, err = pcall(function()
        ss.arm('supdenyrange')
        assert(drops(J.ShouldDropOutOfReachSupportDeny, bot, rows, 150) == 4,
            'this id no longer moves its own helper -- this leg is measuring '
            .. 'nothing')
        assert(drops(J.ShouldDropOutOfReachDeny, bot, rows, 150) == 0,
            "arming 'supdenyrange' also moves the core helper -- the ids are not "
            .. 'independent.  Check first whether the id names collide as '
            .. 'substrings; the matcher is exact, but a helper that gates on the '
            .. 'wrong literal looks identical from outside')
        ss.assert_still_armed()
    end)
    ss.finish(ok, err)
end

--============================================================================
-- 3. THE EXPOSURE IS THE SIBLING'S, QUOTED -- NOT A SECOND READING.
--
-- The corpus behind this id is the same two frames 'denyreach' already read, so
-- reporting the census again here would turn one reading into two citable ones
-- (计量三条 (iii): an effect size is registered together with the cut that
-- produced it).  What this file asserts instead is that the sibling still holds
-- those numbers -- so a round that edits them cannot leave this id quoting a
-- figure that no longer exists anywhere.
--============================================================================

tests['[world] the recorded exposure lives in the sibling file, and still does'] = function()
    local sib = read(SIBLING)
    -- The numbers, as the sibling records them.  9 of 9 allied rows inside the
    -- 1200 ring are beyond melee reach; 3 of 9 beyond even 550.  An UPPER bound
    -- on the branch's reachable set, never a trigger frequency (GH #581).
    assert(sib:find('lion_same_instant = 4', 1, true), 'the sibling census moved')
    assert(sib:find('lion_beyond_150   = 4', 1, true), 'the sibling census moved')
    assert(sib:find('zuus_off_instant  = 5', 1, true), 'the sibling census moved')
    assert(sib:find('zuus_beyond_150   = 5', 1, true), 'the sibling census moved')
    assert(sib:find('WORLD.lion_beyond_150 + WORLD.zuus_beyond_150 == 9', 1, true),
        'the sibling no longer asserts the 9-of-9 headline this file quotes')
end

tests['[world] this id\'s own domain on the lion frame is non-empty and graded'] = function()
    -- The one census this file takes for itself, because section 2 needs a
    -- non-empty domain to be non-vacuous and that domain must be REAL rows.
    -- Same four rows as the sibling's lion block by construction (same fixture,
    -- same filter), which is why they are not reported as a separate finding.
    local fx, me = frame(LION_FIX, LION)
    local rows = ally_rows(fx, me)
    local nRing, n150, n550 = 0, 0, 0
    for _, r in ipairs(rows) do
        if r.d <= 1200 then
            nRing = nRing + 1
            if r.d > 150 then n150 = n150 + 1 end
            if r.d > 550 then n550 = n550 + 1 end
        end
    end
    assert(nRing == 4, 'the lion ring population moved: ' .. nRing)
    assert(n150 == 4, 'beyond-melee count moved: ' .. n150)
    assert(n550 == 1, 'beyond-550 count moved: ' .. n550)
    -- ⭐ ANTI-VACUUM: the ring is non-empty AND the two thresholds disagree, so
    -- "everything is beyond reach" cannot be satisfied by an empty walk or by a
    -- classifier answering a constant.
    assert(nRing > 0, 'the ring is empty -- section 2 would be vacuous')
    assert(n550 < n150, 'the two thresholds agree exactly; the distances are '
        .. 'not being read')
end

return tests

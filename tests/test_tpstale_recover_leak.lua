-- [tpstale / OWNER_PRIORITIES P2 / charter 0NEXT13] THE '回复状态' BRANCH FIRES
-- ON A DESTINATION IT DID NOT CHOOSE.
--
-- THE DEFECT, in one line: the branch's firing condition is `if tpLoc ~= nil`,
-- and `tpLoc` is not its own.
--
-- `tpLoc` is ONE function-scoped local declared at the top of
-- X.ConsiderItemDesire["item_tpscroll"] and shared by every branch of it. Two
-- upstream branches assign it and then fall through WITHOUT clearing it:
--
--   * 前往守塔  `tpLoc = X.GetDefendTPLocation( nDefendLane )`, and the branch
--     fires only on `tpLoc ~= nil AND GetUnitToLocationDistance(bot, tpLoc) >
--     nMinTPDistance - 500`;
--   * 前往推塔  `tpLoc = X.GetPushTPLocation( nPushLane )`, fires only on
--     `tpLoc ~= nil AND ... > nMinTPDistance - 600`.
--
-- When the DISTANCE half fails the branch neither fires nor returns, and the
-- assignment stands. The only `tpLoc = nil` reset anywhere in the function is
-- the defend branch's own J.ShouldAllowDefendTp clear, which runs BEFORE that
-- distance test -- so nothing clears a destination that failed on distance.
-- Section 1 below is that whole claim, ratcheted term by term against the
-- shipped source.
--
-- ⭐⭐ WHY THIS IS A P2 FINDING AND NOT A TIDINESS ONE. Two bugs, not one:
--
--   (1) The bot TPs to a TOWER under the motive '回复状态' -- a destination it
--       cannot recover at, chosen by a branch that already declined to go
--       there, and skipping this branch's own `DistanceFromFountain() >
--       nMinTPDistance + 200` floor entirely.
--   (2) EVERY conjunct of this branch is bypassed, including BOTH gated owner-
--       P2 regen vetoes on it: J.ShouldSipNotTpRecover ('tprecov') and
--       J.ShouldDeepSipNotTpRecover ('tpdeep'). Those two guard the ASSIGNMENT
--       of tpLoc. A veto on the assignment cannot be reached when the FIRING
--       condition is satisfied by somebody else's assignment. So on every
--       leaked frame the two ids are dead whatever they answer, an armed wave
--       reads back "tested, no effect", and check_armed_wiring.py still calls
--       them WIRED -- the 'pullcad' shape (GH #622), arrived at from a new
--       direction: not a gate frozen false, but a call site whose result is
--       overwritten by a sibling's leftover state.
--
-- ⭐ THE REPAIR IS THE BRANCH'S OWN DECLARED POLICY. The conjunction exists to
-- decide whether to go to J.GetTeamFountain(), and `sCastMotive = '回复状态'`
-- names that decision. Requiring the destination to be the one this branch
-- chose cannot remove anything it ever meant to allow -- the flag is true on
-- exactly the frames the conjunction already passed. Direction is therefore a
-- NARROWING only: armed can turn this branch's TRUE into FALSE, never the
-- other way. Gated turbo-only on 'tpstale'; disarmed, the flag is written and
-- never read.
--
-- ⭐ WHAT THE CORPUS SAYS, and it is a real-frame number rather than an
-- argument (tests/_stayfield_tpleg_sweep.lua section 2, 1039 alive hero frames
-- on the live 26-id member string). Of 17 frames inside 回复状态's OUTER head,
-- **10** have the branch's own inner conjunction SHUT -- fountain 5, ring 3,
-- allies 2. On those 10 the branch declines to set tpLoc, so whether it fires
-- is decided ENTIRELY by whether an upstream branch leaked one, and 'tpstale'
-- is the only thing in the function that can tell the two apart. The other 7
-- set their own, where the repair is a no-op by construction.
--
-- ⛔ WHAT THE CORPUS CANNOT SAY, said here rather than left for a wave (GH
-- #622's question, asked in advance):
--   * `X` is FILE-LOCAL, so X.CanJuke / X.GetDefendTPLocation /
--     X.GetPushTPLocation are not callable from a test. The inner conjunction
--     is modelled WITHOUT CanJuke, so 10 is a LOWER bound on the exposure (a
--     false CanJuke can only move a frame from open to shut); and whether an
--     upstream branch actually leaked on a given frame is not readable at all.
--     The LEAK itself is therefore a CLOSED-FORM claim about the source
--     (section 1), never a frequency measured here.
--   * `bot:GetActiveMode()` answers 0 on 1039/1039 frames while
--     BOT_MODE_RETREAT is 1005 -- active mode is bot-VM state, absent from the
--     .dem, exactly like lane assignment (the pullcamp census's STOPPER 4). So
--     the corpus cannot say how often the DEFEND/PUSH branches upstream are
--     even entered. Section 3 records that reading because it also qualifies a
--     sibling file's headline; see the note there.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

local AIUG = 'bots/ability_item_usage_generic.lua'

-- ----------------------------------------------------------- source reading --

local function read(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a'); fh:close()
    return s
end

--- Structural facts are claims about CODE. This very file names in prose every
--- identifier asserted below, and so does the shipped source, so a raw-text
--- match would let a COMMENT satisfy the assertion.
local function mask_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The tpscroll Consider function, comment-free. EVERY offset in this file is
--- taken inside it: `if nMode == BOT_MODE_RETREAT` also occurs in an earlier
--- item's Consider function, and a file-wide anchor silently measured that one
--- instead while the source-order assertion still passed (a wrong-but-smaller
--- offset is still smaller).
local function tp_fn()
    local src = mask_comments(read(AIUG))
    local a = assert(src:find('X.ConsiderItemDesire["item_tpscroll"] = function',
        1, true), 'the tpscroll Consider function moved')
    local b = assert(src:find('\nend\n', a, true), 'the tpscroll function has no end')
    return src:sub(a, b)
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

-- ------------------------------------------------------------------ census --

--- Recorded by tests/_stayfield_tpleg_sweep.lua on the live member string.
--- Re-run it by hand after any change to the branch or its constants:
---   ARMED=$(python3 -c "import sys; sys.path.insert(0,'tools/agent'); \
---     from stale_waits import armed_ids; print(','.join(sorted(armed_ids())))")
---   lua5.1 tests/_stayfield_tpleg_sweep.lua "$ARMED"
--- The full 1039-frame walk costs ~54s and deliberately does NOT run here (the
--- charter's timing rule): this file drives only the decisive frames below, so
--- it stays inside the push gate's per-test budget.
local CENSUS = {
    frames = 1039,
    r4_head = 17,
    inner_open = 7,
    inner_shut = 10,
    why_fountain = 5,
    why_ring = 3,
    why_allies = 2,
    mode_is_retreat = 0,
}

--- The decisive frames, one per outcome the classification can produce, taken
--- from the sweep's V rows. Driving one frame per reason is what keeps this
--- file's teeth on the REAL corpus while the counts above stay a quotation.
local FRAMES = {
    { 'f_260819_181742_ss_chase_stalled.lua', 'npc_dota_hero_ember_spirit', 'open' },
    { 'f_181441_zuus_lowhp_limbo.lua', 'npc_dota_hero_zuus', 'fountain' },
    { 'f_20260827_091703_slot12_zuus_473_1.lua', 'npc_dota_hero_zuus', 'allies' },
    { 'f_260819_142047_zuus_ult_denied.lua', 'npc_dota_hero_bristleback', 'ring' },
}

local BRANCH_MODIFIERS = {
    'modifier_flask_healing', 'modifier_clarity_potion', 'modifier_filler_heal',
    'modifier_item_urn_heal', 'modifier_item_spirit_vessel_heal',
    'modifier_juggernaut_healing_ward_heal', 'modifier_bottle_regeneration',
    'modifier_tango_heal',
}

--- Load one fixture frame in the HONEST turbo world (GH #93: by name the
--- fixture world is Turbo, by the literal 23 it is not, and the gate opens with
--- J.IsModeTurbo).
local function world(path, subject)
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J, bot = rf.load('tests/fixtures/' .. path, subject)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J, bot
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

-- =========================== 1. THE LEAK, IN SOURCE =========================

tests['[ratchet][source] two upstream branches assign tpLoc behind a distance test that can fail'] = function()
    local fn = tp_fn()
    assert(count(fn, 'tpLoc = X.GetDefendTPLocation(') == 1,
        'the 前往守塔 assignment to tpLoc moved or multiplied')
    assert(count(fn, 'tpLoc = X.GetPushTPLocation(') == 1,
        'the 前往推塔 assignment to tpLoc moved or multiplied')
    -- The firing guards, each a conjunction whose SECOND half is a distance
    -- test. If either becomes unconditional on tpLoc ~= nil, the fall-through
    -- this file is about stops existing and this assertion says so.
    assert(fn:find('nMinTPDistance %- 500'),
        "the 前往守塔 distance half is no longer nMinTPDistance - 500")
    assert(fn:find('nMinTPDistance %- 600'),
        "the 前往推塔 distance half is no longer nMinTPDistance - 600")
end

tests['[ratchet][source] nothing clears tpLoc between those assignments and 回复状态'] = function()
    local fn = tp_fn()
    -- THREE resets exist in the function today and they are not
    -- interchangeable. The SHIPPED one is the defend branch's
    -- ShouldAllowDefendTp clear, which runs BEFORE that branch's distance test
    -- and so cannot clear a destination that failed ON distance. The second is
    -- this file's own gated 'tpstale' drop. The third (strategy 2026-09-17) is
    -- the gated 'tprupt' drop, which sits DOWNSTREAM of 回复状态 on the rupture
    -- branch and therefore cannot clear anything before this branch reads it --
    -- the slice assertion below, not this count, is what carries the leak
    -- claim: between the defend distance test and 回复状态 there is no OTHER,
    -- ungated reset, i.e. disarming 'tpstale' restores the leak exactly.
    -- `local tpLoc = nil` is the DECLARATION, not a reset; counting it as one
    -- is how this assertion first read 3 and looked like a broken claim.
    local nDecl = count(fn, 'local tpLoc = nil')
    local nResets = count(fn, 'tpLoc = nil') - nDecl
    assert(nDecl == 1, 'tpLoc is no longer declared exactly once in this function')
    assert(nResets == 3,
        'the tpscroll function now has ' .. nResets
        .. ' `tpLoc = nil` resets, expected 3 (the ShouldAllowDefendTp clear, '
        .. 'the gated tpstale drop, the gated tprupt drop) -- re-read the leak '
        .. 'before trusting it')
    local nReset = fn:find('tpLoc = nil', at(fn, 'local tpLoc = nil') + 20, true) or -1
    local nDefendFire = at(fn, 'nMinTPDistance - 500')
    local nGate = at(fn, 'J.ShouldDropUnownedRecoverTp(')
    local nRecover = at(fn, "sCastMotive = '回复状态'")
    assert(nReset > 0 and nDefendFire > 0 and nGate > 0 and nRecover > 0,
        'an anchor moved')
    assert(nReset < nDefendFire,
        'the shipped reset now runs AFTER the defend distance test -- re-read '
        .. 'the leak')
    assert(nDefendFire < nRecover, '前往守塔 is no longer upstream of 回复状态')
    -- The ONLY reset between the leaking branch and the branch it leaks into is
    -- the gated one.
    local middle = fn:sub(nDefendFire, nRecover)
    assert(count(middle, 'tpLoc = nil') == 1,
        'an unexpected `tpLoc = nil` appeared between 前往守塔 and 回复状态')
    assert(nGate > nDefendFire and nGate < nRecover,
        'the tpstale drop is not between the leaking branch and the branch it '
        .. 'protects')
end

tests['[ratchet][source] 回复状态 still fires on the bare `tpLoc ~= nil`'] = function()
    local fn = tp_fn()
    local nGate = at(fn, 'J.ShouldDropUnownedRecoverTp(')
    local nRecover = at(fn, "sCastMotive = '回复状态'")
    assert(nGate > 0, "the 'tpstale' call is gone from the tpscroll function")
    assert(nGate < nRecover, "the 'tpstale' gate moved BELOW the branch it guards")
    -- The firing condition itself is unchanged; the repair works by making the
    -- value it reads honest, not by rewriting the test. If somebody replaces it
    -- with a compound condition, the fix and this file both need re-reading.
    local tail = fn:sub(nGate, nRecover)
    assert(tail:find('if tpLoc ~= nil', 1, true),
        'the 回复状态 firing condition is no longer `if tpLoc ~= nil`')
end

-- ====================== 2. THE REPAIR, AND ITS DIRECTION ====================

tests['[ratchet][source] the flag is set inside the branch own conjunction, and only there'] = function()
    local fn = tp_fn()
    assert(count(fn, 'bRecoverTpIsOurs = true') == 1,
        'the tpstale ownership flag is set in more than one place (or none)')
    assert(count(fn, 'local bRecoverTpIsOurs = false') == 1,
        'the tpstale ownership flag is no longer declared false per call')
    local nDecl = at(fn, 'local bRecoverTpIsOurs = false')
    local nSet = at(fn, 'bRecoverTpIsOurs = true')
    local nOwnTp = at(fn, 'tpLoc = J.GetTeamFountain()\n\t\t\tbRecoverTpIsOurs = true')
    assert(nDecl < nSet, 'the flag is set before it is declared')
    assert(nOwnTp > 0,
        'the flag is no longer set immediately after this branch own '
        .. 'tpLoc = J.GetTeamFountain() -- it must be true on exactly the '
        .. 'frames the conjunction passed, or the direction claim is void')
end

tests['[ratchet][source] the call site only DROPS, and names no candidate id'] = function()
    local fn = tp_fn()
    local nGate = at(fn, 'J.ShouldDropUnownedRecoverTp(')
    assert(nGate > 0, 'the tpstale call site is gone')
    -- ⛔ THE GATE LIVES IN THE HELPER, NOT HERE. The suite already enforces this
    -- for 'tprecov' and 'tpdeep' (test_tprecov_recover_trip.lua's RECOVER_NIDS
    -- == 0): an id named in the branch condition makes the branch's levers
    -- jointly armable instead of separately. Landing the first draft inline is
    -- what turned those two files red on 2026-09-14.
    assert(not fn:find("IsSoakCandidate", 1, true),
        'a candidate id is named in the tpscroll branch body; the gate belongs '
        .. 'in the helper so each lever here stays separately armable')
    -- The body of the gated block may only assign nil: an assignment of a
    -- LOCATION here would make armed able to OPEN the branch, and the whole
    -- "narrowing only" claim of this round rests on it never doing that.
    local body = fn:sub(nGate, nGate + 200)
    local a = body:find('then', 1, true)
    local b = body:find('\n\t\tend', 1, true)
    assert(a and b and b > a, 'the tpstale block could not be sliced')
    local inner = body:sub(a + 4, b)
    assert(inner:find('tpLoc = nil', 1, true),
        'the tpstale block no longer drops tpLoc')
    assert(count(inner, 'tpLoc =') == 1,
        'the tpstale block assigns tpLoc more than once -- it may only drop it')
    assert(not inner:find('GetTeamFountain', 1, true),
        'the tpstale block assigns a destination; armed would be able to OPEN '
        .. 'this branch, which is the one direction it must never do')
end

tests['[ratchet][source] the helper is gate-first, turbo-second, and names one id'] = function()
    local jmz = mask_comments(read('bots/FunLib/jmz_func.lua'))
    local a = jmz:find('function J.ShouldDropUnownedRecoverTp', 1, true)
    assert(a ~= nil, 'J.ShouldDropUnownedRecoverTp is gone')
    local b = jmz:find('\nend', a, true)
    local body = jmz:sub(a, b)
    -- Exactly ONE candidate id. A second makes the gate a conjunction that
    -- freezes FALSE the day the other is promoted -- the pullcad trap, which
    -- this repo has now paid for twice.
    assert(count(body, 'IsSoakCandidate') == 1,
        'the helper names ' .. count(body, 'IsSoakCandidate') .. ' candidate '
        .. 'ids; a second one freezes the gate FALSE the day the other is '
        .. 'promoted (the pullcad trap)')
    assert(count(body, "IsSoakCandidate( 'tpstale' )") == 1,
        "the helper's id is no longer 'tpstale'")
    -- Gate FIRST, turbo second: unarmed it must reach no engine call at all.
    local nGate = body:find("IsSoakCandidate( 'tpstale' )", 1, true)
    local nTurbo = body:find('IsModeTurbo', 1, true)
    assert(nGate and nTurbo and nGate < nTurbo,
        'the helper is no longer gate-first-then-turbo')
    -- It is a PURE predicate over its argument: no engine reads of its own, so
    -- it cannot acquire an opinion the call site did not ask for.
    assert(not body:find('bot', 1, true),
        'the helper now reads the bot; it is meant to answer only "did the '
        .. 'caller choose this destination"')
end

tests['[ratchet][source] disarmed, the flag is written and never read'] = function()
    local fn = tp_fn()
    -- Two reads of the flag would mean a second behaviour hangs off it; one
    -- read, inside the gated block, is what makes the disarmed tree byte-for-
    -- byte the old one.
    assert(count(fn, 'bRecoverTpIsOurs') == 3,
        'bRecoverTpIsOurs appears ' .. count(fn, 'bRecoverTpIsOurs')
        .. ' times, expected 3 (declare, set, one read as the helper argument)')
    local nRead = at(fn, 'J.ShouldDropUnownedRecoverTp( bRecoverTpIsOurs )')
    assert(nRead > 0,
        'the flag is no longer what the tpstale helper is asked about')
end

tests['[ratchet][source] both P2 vetoes still guard the assignment this repair protects'] = function()
    local fn = tp_fn()
    -- If either veto were moved to the FIRING condition this repair would be
    -- redundant; if either were deleted, the reason it exists changes. Either
    -- way the finding above needs re-reading, so pin both.
    assert(count(fn, 'J.ShouldSipNotTpRecover( bot )') == 1,
        "'tprecov' left the 回复状态 conjunction")
    assert(count(fn, 'J.ShouldDeepSipNotTpRecover( bot )') == 1,
        "'tpdeep' left the 回复状态 conjunction")
    local nOwnTp = at(fn, 'bRecoverTpIsOurs = true')
    assert(at(fn, 'J.ShouldSipNotTpRecover( bot )') < nOwnTp,
        "'tprecov' no longer guards the assignment")
    assert(at(fn, 'J.ShouldDeepSipNotTpRecover( bot )') < nOwnTp,
        "'tpdeep' no longer guards the assignment")
end

-- =============== 3. THE SHAPE OF THE FOUR BRANCHES (charter 0NEXT13) ========

tests['[ratchet][structure] three home branches sit inside the retreat wrap and 回复状态 does not'] = function()
    local fn = tp_fn()
    local nWrap = at(fn, 'if nMode == BOT_MODE_RETREAT')
    local nR1 = at(fn, 'if botHP < 0.19')
    local nR2 = at(fn, 'if botHP < ( 0.15 + 0.24 * nEnemyCount )')
    local nR3 = at(fn, 'if ( botHP < 0.34 or botHP + botMP < 0.43 )')
    local nR4 = at(fn, 'if ( botHP + botMP < 0.3 or botHP < 0.2 )')
    assert(nWrap > 0 and nR1 > 0 and nR2 > 0 and nR3 > 0 and nR4 > 0,
        'a home-TP branch head moved')
    assert(nWrap < nR1 and nR1 < nR2 and nR2 < nR3 and nR3 < nR4,
        'the source order of the four home branches changed')
    -- The wrap's close: the first one-tab `end` after 撤退:3. 撤退:1/2/3 land
    -- before it, 回复状态 after -- which is the nesting claim read off the
    -- structure rather than from indentation.
    local nEnd = fn:find('\n\tend\n', nR3, true)
    assert(nEnd ~= nil, 'the retreat wrap has no one-tab close after 撤退:3')
    assert(nR3 < nEnd, '撤退:3 is no longer inside the retreat wrap')
    assert(nR4 > nEnd, '回复状态 moved INSIDE the retreat wrap')
end

tests['[ratchet][arith] the three HP heads nest 撤退:1 in 回复状态 in 撤退:3'] = function()
    local fn = tp_fn()
    -- Parsed, never retyped (the M13 lesson): a test that restates the
    -- constants it measures reports the old world unmoved after they change.
    local r1 = tonumber(fn:match('if botHP < ([%d%.]+)'))
    local r3hp, r3sum = fn:match('if %( botHP < ([%d%.]+) or botHP %+ botMP < ([%d%.]+) %)')
    local r4sum, r4hp = fn:match('if %( botHP %+ botMP < ([%d%.]+) or botHP < ([%d%.]+) %)')
    r3hp, r3sum = tonumber(r3hp), tonumber(r3sum)
    r4sum, r4hp = tonumber(r4sum), tonumber(r4hp)
    assert(r1 and r3hp and r3sum and r4sum and r4hp, 'a head constant is unparseable')
    -- 撤退:1 (hp < r1) implies 回复状态 (hp < r4hp) implies 撤退:3 (hp < r3hp).
    assert(r1 <= r4hp, '撤退:1 is no longer inside 回复状态 on the HP leg')
    assert(r4hp <= r3hp, '回复状态 is no longer inside 撤退:3 on the HP leg')
    assert(r4sum <= r3sum, '回复状态 is no longer inside 撤退:3 on the HP+MP leg')
    -- Measured the same way on real frames: the sweep's viol_* counters are all
    -- absent (0) and its anti-vacuum pair h3_beyond_h1 / h3_beyond_h4 are 46 /
    -- 45, so those zeros come from a tally that demonstrably tallies.
end

tests['[ratchet][limit] the corpus cannot see the retreat wrap, and the sweep says so'] = function()
    -- Loader fact, re-driven here on one real frame rather than quoted: active
    -- mode is bot-VM state and absent from the .dem. THIS QUALIFIES SECTION 1
    -- OF tests/_stayfield_tpleg_sweep.lua -- its `branch_stop` walks 撤退:3's
    -- own conjuncts and never models the wrap, so `trigger`, `branch_open`,
    -- `margin_solo` and `margin_live` are all conditional on "given the bot is
    -- in retreat mode" and the corpus contributes nothing to whether it is.
    local J, bot = world(FRAMES[1][1], FRAMES[1][2])
    assert(J ~= nil and bot ~= nil, 'the pinned frame did not load')
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'the loader now answers a real active mode -- the limit above is stale '
        .. 'and every 撤退:* reading in this family can be re-taken properly')
    assert(CENSUS.mode_is_retreat == 0,
        'the recorded census says some frame WAS in retreat mode')
    unprobe()
end

-- ============= 4. THE EXPOSURE POPULATION, DRIVEN ON REAL FRAMES ===========

--- 回复状态's inner conjunction MINUS X.CanJuke() (file-local, not callable),
--- returning the first conjunct that shuts it. Byte-for-byte the model the
--- sweep uses, so a frame classified here and there cannot disagree.
local function why_shut(J, bot)
    local okFar, far = pcall(function() return bot:DistanceFromFountain() end)
    local nFar = (okFar and type(far) == 'number') and far or -1
    if not (nFar > 5500 + 200) then return 'fountain' end
    if #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) > 1 then return 'ring' end
    if J.GetAllyCount(bot, 1600) > 1 then return 'allies' end
    if J.GetProperTarget(bot) ~= nil then return 'propertarget' end
    if J.IsItemAvailable('item_flask') ~= nil then return 'flask' end
    if bot:GetAttackTarget() ~= nil then return 'target' end
    for _, m in ipairs(BRANCH_MODIFIERS) do
        if bot:HasModifier(m) then return 'modifier' end
    end
    return 'open'
end

tests['[detector] each decisive frame reproduces the exposure class the census recorded'] = function()
    local nDriven, nShut = 0, 0
    for _, f in ipairs(FRAMES) do
        local J, bot = world(f[1], f[2])
        assert(bot ~= nil and bot:IsAlive(), f[1] .. ' / ' .. f[2] .. ' is not a live frame')
        -- The OUTER head must still open on this frame, or the row is not
        -- about 回复状态 at all.
        local nHP, nMP = J.GetHP(bot), J.GetMP(bot)
        assert((nHP + nMP < 0.3) or (nHP < 0.2),
            f[1] .. ' / ' .. f[2] .. ' no longer opens 回复状态 outer head')
        local sWhy = why_shut(J, bot)
        assert(sWhy == f[3], f[1] .. ' / ' .. f[2] .. ' classified ' .. sWhy
            .. ', census recorded ' .. f[3])
        nDriven = nDriven + 1
        if sWhy ~= 'open' then nShut = nShut + 1 end
        unprobe()
    end
    assert(nDriven == #FRAMES, 'drove ' .. nDriven .. ' of ' .. #FRAMES .. ' frames')
    -- ⭐ ANTI-VACUUM. Three of the four are SHUT and one is OPEN: a classifier
    -- that answered a constant would fail one of them, so "they all matched"
    -- cannot be satisfied by a model that never ran.
    assert(nShut == 3, 'expected 3 shut / 1 open among the decisive frames, got '
        .. nShut .. ' shut')
end

tests['[ratchet] the recorded census is internally consistent'] = function()
    assert(CENSUS.inner_open + CENSUS.inner_shut == CENSUS.r4_head,
        'the exposure split does not close on the head population')
    assert(CENSUS.why_fountain + CENSUS.why_ring + CENSUS.why_allies
        == CENSUS.inner_shut, 'the shut reasons do not sum to inner_shut')
    assert(CENSUS.inner_shut > 0,
        "the exposure population is empty -- 'tpstale' would be a lever with no "
        .. 'domain and this round must be re-read, not shipped')
    assert(CENSUS.r4_head <= CENSUS.frames, 'the head population exceeds the corpus')
end

tests['[ratchet] the census population has not shrunk under this file'] = function()
    local p = assert(io.popen('ls tests/fixtures'))
    local n = 0
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then n = n + 1 end
    end
    p:close()
    cs.corpus(n, 'tests/fixtures')
    -- The census is a sum over fixtures. Growth does not falsify the frame
    -- drives above, but it does make the COUNTS stale -- and `inner_shut = 10`
    -- is exactly the kind of claim a 113th fixture can move.
    cs.ratchet(n, 112, 'fixture count at the time of the 0NEXT13 census')
end

return tests

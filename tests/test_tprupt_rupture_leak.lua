-- [tprupt / OWNER_PRIORITIES P2 / strategy 2026-09-17] THE RUPTURE BRANCH
-- FIRES ON A DESTINATION IT DID NOT CHOOSE -- AND IT ASKS FOR NO LOW HP.
--
-- THE DEFECT, in one line: this branch's firing condition is a bare non-nil
-- test on the shared destination local, and that local is not its own.
--
-- It is the SAME leak 'tpstale' closed one branch up, at the only other
-- consumer left in X.ConsiderItemDesire["item_tpscroll"]. The shared local is
-- written by two upstream branches that fall through WITHOUT clearing it:
--
--   * 前往守塔  from X.GetDefendTPLocation, fires only if it is set AND the
--     distance exceeds nMinTPDistance - 500;
--   * 前往推塔  from X.GetPushTPLocation, fires only if it is set AND the
--     distance exceeds nMinTPDistance - 600.
--
-- When the DISTANCE half fails, neither branch fires and neither clears, so a
-- TOWER destination travels down the function still set.
--
-- ⭐⭐ WHY THIS IS A SECOND FINDING AND NOT A RESTATEMENT OF 'tpstale'. The
-- difference is the two OUTER heads, and it is arithmetic rather than taste:
--
--   * 回复状态 (what 'tpstale' guards) sits under
--     `( botHP + botMP < 0.3 or botHP < 0.2 ) and bot:GetLevel() >= 6`. On a
--     healthy bot that head is FALSE, so the branch's own non-nil test is never
--     evaluated -- the leak is NOT consumed there and travels on.
--   * the rupture branch reads the rupture modifier, its remaining time and the
--     enemy count. NO HP TERM ANYWHERE (section 2 asserts this by parsing both
--     heads, never by retyping them).
--
--   ⇒ every frame 'tpstale' cannot reach BECAUSE THE BOT IS HEALTHY is a frame
--   this one can. The two levers are not redundant and are deliberately not one
--   id: each guards a different branch, and arming either must not move the
--   other's reading.
--
-- ⭐ THE CONSEQUENCE, in the branch's own terms. The branch exists to run away
-- from a bloodseeker ult and its own assignment is the team fountain. On a
-- leaked frame it instead spends the scroll to teleport a ruptured hero to a
-- tower a DEFEND or a PUSH branch computed and then declined to travel to,
-- under its own escape motive, at DESIRE_HIGH -- and every conjunct of the
-- branch (the ally count, the juke test) is bypassed there whatever it answers.
--
-- ⭐ THE REPAIR IS THE BRANCH'S OWN DECLARED POLICY. The caller passes TRUE when
-- its own inner conjunction set the destination; J.ShouldDropUnownedRuptureTp
-- answers "drop it" only when it did NOT. Direction is a NARROWING by
-- construction: the flag is true on exactly the frames the conjunction already
-- passed, so armed can turn the branch's TRUE into FALSE and never the other
-- way.
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT SAY, said here rather than left to a wave.
-- The fixture corpus carries NO bloodseeker and no rupture modifier, so this
-- lever's live domain on it is ZERO. Section 4 reads that zero the way the
-- charter's 0NEXT33 §丙 requires -- paired with a NON-zero from the same reader
-- on the same frames -- so it is registered as a CONSTRUCTIVE zero (this corpus
-- drafted no bloodseeker) and never as "the instrument is blind". And as with
-- 'tpstale', the LEAK itself is a closed-form claim about the SOURCE (section
-- 1): X is file-local, so X.CanJuke / X.GetDefendTPLocation /
-- X.GetPushTPLocation are not callable from a test and no fixture can show a
-- leak happening.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

local tests = {}

local AIUG = 'bots/ability_item_usage_generic.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'

-- ----------------------------------------------------------- source reading --

local function read(path)
    local fh = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = fh:read('*a'); fh:close()
    return s
end

--- Structural claims are claims about CODE. This file names every identifier it
--- asserts, and so do the shipped comments, so a raw-text match would let a
--- COMMENT satisfy the assertion.
local function mask_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The tpscroll Consider function, comment-free. Every offset below is taken
--- inside it: several anchors also occur in other items' Consider functions.
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

-- =========================== 1. THE LEAK, IN SOURCE =========================

tests['[ratchet][source] the rupture branch is downstream of both leaking writers']
= function()
    local fn = tp_fn()
    local nDefend = at(fn, 'tpLoc = X.GetDefendTPLocation(')
    local nPush   = at(fn, 'tpLoc = X.GetPushTPLocation(')
    local nRupt   = at(fn, "bot:HasModifier( 'modifier_bloodseeker_rupture' )")
    assert(nDefend > 0, 'the 前往守塔 assignment moved or multiplied')
    assert(nPush > 0, 'the 前往推塔 assignment moved or multiplied')
    assert(nRupt > 0, 'the rupture branch head is gone from this function')
    assert(nDefend < nRupt and nPush < nRupt,
        'a leaking writer moved BELOW the rupture branch -- re-read the leak')
    -- The distance halves that make the fall-through exist. If either firing
    -- guard becomes unconditional, the leak stops existing and this says so.
    assert(fn:find('nMinTPDistance %- 500'),
        'the 前往守塔 distance half is no longer nMinTPDistance - 500')
    assert(fn:find('nMinTPDistance %- 600'),
        'the 前往推塔 distance half is no longer nMinTPDistance - 600')
end

tests['[ratchet][source] the only clears between the writers and this branch are the two gated drops and the defend clear']
= function()
    local fn = tp_fn()
    -- THREE resets exist in the function today and they are not
    -- interchangeable: the SHIPPED one is the defend branch's
    -- ShouldAllowDefendTp clear (which runs BEFORE that branch's distance test,
    -- so it cannot clear a destination that failed ON distance), plus the gated
    -- 'tpstale' drop and this round's gated 'tprupt' drop. `local tpLoc = nil`
    -- is the DECLARATION, not a reset.
    local nDecl = count(fn, 'local tpLoc = nil')
    local nResets = count(fn, 'tpLoc = nil') - nDecl
    assert(nDecl == 1, 'tpLoc is no longer declared exactly once in this function')
    assert(nResets == 3,
        'the tpscroll function now has ' .. nResets .. ' `tpLoc = nil` resets, '
        .. 'expected 3 (the ShouldAllowDefendTp clear, the tpstale drop, the '
        .. 'tprupt drop) -- re-read the leak before trusting it')
    local nDefendFire = at(fn, 'nMinTPDistance - 500')
    local nRuptGate = at(fn, 'J.ShouldDropUnownedRuptureTp(')
    local nRupt = at(fn, "bot:HasModifier( 'modifier_bloodseeker_rupture' )")
    assert(nDefendFire > 0 and nRuptGate > 0, 'an anchor moved')
    assert(nRuptGate > nRupt,
        'the tprupt drop is not inside the branch it protects')
    -- Between the leaking branch's distance test and THIS branch's drop there
    -- is exactly ONE reset, and it is the sibling's gated 'tpstale' drop -- the
    -- defend branch's own clear runs upstream of that distance test and is not
    -- in this slice. A second reset appearing here would be an UNGATED clear,
    -- i.e. the leak would no longer reach this branch and this finding would be
    -- stale rather than merely narrower.
    local middle = fn:sub(nDefendFire, nRuptGate)
    assert(count(middle, 'tpLoc = nil') == 1,
        'expected exactly 1 `tpLoc = nil` (the gated tpstale drop) between the '
        .. '前往守塔 distance test and the tprupt drop, found '
        .. count(middle, 'tpLoc = nil') .. ' -- re-read whether the leak still '
        .. 'reaches the rupture branch')
    assert(count(middle, 'J.ShouldDropUnownedRecoverTp(') == 1,
        'the one reset in that slice is not the gated tpstale drop')
end

tests['[ratchet][source] the branch still fires on the bare non-nil test, and the drop precedes it']
= function()
    local fn = tp_fn()
    local nRuptGate = at(fn, 'J.ShouldDropUnownedRuptureTp(')
    local nRupt = at(fn, "bot:HasModifier( 'modifier_bloodseeker_rupture' )")
    assert(nRupt > 0 and nRuptGate > nRupt, 'the tprupt gate left its branch')
    -- The firing condition itself is unchanged: the repair works by making the
    -- value it reads honest, not by rewriting the test.
    local tail = fn:sub(nRuptGate)
    local nFire = tail:find('if tpLoc ~= nil', 1, true)
    assert(nFire ~= nil,
        'the rupture branch firing condition is no longer a bare non-nil test '
        .. 'on tpLoc -- the repair and this file both need re-reading')
end

-- ====================== 2. WHY IT IS NOT 'tpstale' AGAIN ====================

tests['[ratchet][arith] the sibling branch has a low-HP head and this one has no HP term at all']
= function()
    local fn = tp_fn()
    -- Parsed, never retyped: a test that restates the constants it measures
    -- reports the old world unmoved after they change.
    local r4sum, r4hp = fn:match('if %( botHP %+ botMP < ([%d%.]+) or botHP < ([%d%.]+) %)')
    r4sum, r4hp = tonumber(r4sum), tonumber(r4hp)
    assert(r4sum and r4hp, "the 回复状态 head is unparseable")
    assert(r4hp > 0 and r4hp < 1 and r4sum > 0,
        'the 回复状态 head no longer gates on a health fraction, so the '
        .. 'exposure argument of this round needs re-reading')
    -- The rupture head: from its own `if` to its `then`. It must mention the
    -- modifier, its time and the enemy count -- and NO health quantity. That
    -- absence is the whole reason this branch is exposed where the sibling is
    -- not, so it is asserted rather than described.
    local i = assert(fn:find("if bot:HasModifier( 'modifier_bloodseeker_rupture' )", 1, true),
        'the rupture branch head moved')
    local j = assert(fn:find('\n\tthen', i, true), 'the rupture head has no then')
    local head = fn:sub(i, j)
    assert(head:find('nEnemyCount', 1, true), 'the rupture head lost its enemy count')
    assert(head:find('GetModifierTime', 1, true), 'the rupture head lost its time test')
    assert(not head:find('botHP', 1, true),
        'the rupture head now reads botHP -- it used to read no health at all, '
        .. 'and "healthy bots reach this branch" is the claim that made tprupt '
        .. 'a separate finding from tpstale')
    assert(not head:find('GetHP', 1, true),
        'the rupture head now reads GetHP -- same re-read as above')
end

tests['[ratchet][source] the sibling gate is still on its own branch and names its own id']
= function()
    local fn = tp_fn()
    -- If 'tpstale' had been widened to cover this branch instead, this round
    -- would be a duplicate. Pin that it was not.
    assert(count(fn, 'J.ShouldDropUnownedRecoverTp(') == 1,
        'the tpstale drop moved or multiplied')
    assert(count(fn, 'J.ShouldDropUnownedRuptureTp(') == 1,
        'the tprupt drop moved or multiplied')
    assert(at(fn, 'J.ShouldDropUnownedRecoverTp(') < at(fn, 'J.ShouldDropUnownedRuptureTp('),
        'the two drops swapped order -- the branches did not')
end

-- ====================== 3. THE REPAIR, AND ITS DIRECTION ====================

tests['[ratchet][source] the flag is declared per call and set only inside the branch own conjunction']
= function()
    local fn = tp_fn()
    assert(count(fn, 'local bRuptureTpIsOurs = false') == 1,
        'the tprupt ownership flag is no longer declared false per call')
    assert(count(fn, 'bRuptureTpIsOurs = true') == 1,
        'the tprupt ownership flag is set in more than one place (or none)')
    assert(count(fn, 'bRuptureTpIsOurs') == 3,
        'bRuptureTpIsOurs appears ' .. count(fn, 'bRuptureTpIsOurs')
        .. ' times, expected 3 (declare, set, one read as the helper argument)')
    -- Set IMMEDIATELY after this branch's own destination assignment: the
    -- direction claim is that the flag is true on exactly the frames the inner
    -- conjunction passed, and that is where it can be read off the source.
    assert(fn:find('tpLoc = J.GetTeamFountain()\n\t\t\tbRuptureTpIsOurs = true', 1, true),
        'the flag is no longer set immediately after this branch own '
        .. 'destination assignment -- the direction claim is void without it')
    assert(at(fn, 'local bRuptureTpIsOurs = false') < at(fn, 'bRuptureTpIsOurs = true'),
        'the flag is set before it is declared')
end

tests['[ratchet][source] the call site only DROPS, and names no candidate id']
= function()
    local fn = tp_fn()
    local nGate = at(fn, 'J.ShouldDropUnownedRuptureTp(')
    assert(nGate > 0, 'the tprupt call site is gone')
    -- ⛔ THE GATE LIVES IN THE HELPER, NOT HERE: an id named in a branch body
    -- makes that branch's levers jointly armable instead of separately.
    assert(not fn:find('IsSoakCandidate', 1, true),
        'a candidate id is named in the tpscroll branch body; the gate belongs '
        .. 'in the helper so each lever here stays separately armable')
    local body = fn:sub(nGate, nGate + 200)
    local a = body:find('then', 1, true)
    local b = body:find('\n\t\tend', 1, true)
    assert(a and b and b > a, 'the tprupt block could not be sliced')
    local inner = body:sub(a + 4, b)
    assert(inner:find('tpLoc = nil', 1, true), 'the tprupt block no longer drops tpLoc')
    assert(count(inner, 'tpLoc =') == 1,
        'the tprupt block assigns tpLoc more than once -- it may only drop it')
    assert(not inner:find('GetTeamFountain', 1, true),
        'the tprupt block assigns a destination; armed would be able to OPEN '
        .. 'this branch, which is the one direction it must never do')
end

tests['[ratchet][source] the helper is gate-first, turbo-second, names one id, and reads no unit']
= function()
    local jmz = mask_comments(read(JMZ))
    local a = assert(jmz:find('function J.ShouldDropUnownedRuptureTp', 1, true),
        'J.ShouldDropUnownedRuptureTp is gone')
    local b = jmz:find('\nend', a, true)
    local body = jmz:sub(a, b)
    -- Exactly ONE candidate id: a second makes the gate a conjunction that
    -- freezes FALSE the day the other is promoted (the pullcad trap).
    assert(count(body, 'IsSoakCandidate') == 1,
        'the helper names ' .. count(body, 'IsSoakCandidate') .. ' candidate ids; '
        .. 'a second one freezes the gate FALSE the day the other is promoted')
    assert(count(body, "IsSoakCandidate( 'tprupt' )") == 1,
        "the helper's id is no longer 'tprupt'")
    local nGate = body:find("IsSoakCandidate( 'tprupt' )", 1, true)
    local nTurbo = body:find('IsModeTurbo', 1, true)
    assert(nGate and nTurbo and nGate < nTurbo,
        'the helper is no longer gate-first-then-turbo')
    assert(not body:find('bot', 1, true),
        'the helper now reads the bot; it is meant to answer only "did the '
        .. 'caller choose this destination"')
end

-- ============ 4. THE DOMAIN ON THIS CORPUS: A ZERO, READ PROPERLY ==========

--- 0NEXT33 §丙: a zero is only a zero when the SAME reader produces a non-zero
--- somewhere. These two counts are taken in one pass over the same frames.
local RUPTURE = 'modifier_bloodseeker_rupture'

local function corpus_modifier_census()
    local p = assert(io.popen('ls tests/fixtures'))
    local names = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then names[#names + 1] = f end
    end
    p:close()
    return names
end

tests['[instrument] the rupture domain is a CONSTRUCTIVE zero, and the same reader answers non-zero']
= function()
    local names = corpus_modifier_census()
    assert(#names > 100, 'the fixture corpus shrank to ' .. #names .. ' frames')
    -- Read the fixture SOURCE rather than loading 118 worlds: the question is
    -- whether the corpus CARRIES the modifier at all, and the loader can only
    -- answer for one subject at a time.
    local nRupture, nOtherModifier, nWithBlocks = 0, 0, 0
    for _, f in ipairs(names) do
        local s = read('tests/fixtures/' .. f)
        if s:find('modifier_', 1, true) then nWithBlocks = nWithBlocks + 1 end
        if s:find(RUPTURE, 1, true) then nRupture = nRupture + 1 end
        -- Any OTHER modifier name, from the same text, in the same pass.
        if s:find('modifier_tango_heal', 1, true)
            or s:find('modifier_fountain_aura_buff', 1, true)
            or s:find('modifier_clarity_potion', 1, true)
        then
            nOtherModifier = nOtherModifier + 1
        end
    end
    -- ⭐ THE PAIR. The first number is this lever's domain on this corpus; the
    -- second is what makes it readable as a constructive zero rather than as a
    -- blind instrument.
    assert(nRupture == 0,
        'the corpus now carries ' .. nRupture .. ' rupture frame(s) -- this '
        .. "lever's domain is no longer constructively empty and must be "
        .. 'measured properly instead of argued in closed form')
    assert(nOtherModifier > 0,
        'no fixture carries ANY of the three control modifiers, so the zero '
        .. 'above cannot be distinguished from a reader that sees nothing')
    assert(nWithBlocks > 0, 'no fixture carries a modifier block at all')
end

-- ================== 5. THE GATE, DRIVEN ON A REAL FRAME ====================

local FRAME = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SUBJ  = 'npc_dota_hero_obsidian_destroyer'

local function side_of()
    local _, bot = rf.load(FRAME, SUBJ)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

--- The loader world is Turbo by name but not by the literal 23 (GH #93), and
--- J.IsModeTurbo is what the helper asks second.
local function turbo_world()
    GAMEMODE_TURBO = nil -- luacheck: ignore
    local J = rf.load(FRAME, SUBJ)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

tests['[driven] un-armed the helper drops NOTHING, for every argument'] = function()
    local J = turbo_world()
    assert(J.ShouldDropUnownedRuptureTp(false) == false,
        'un-armed the helper dropped a destination -- the inertness claim is void')
    assert(J.ShouldDropUnownedRuptureTp(nil) == false,
        'un-armed the helper dropped on a nil argument')
    assert(J.ShouldDropUnownedRuptureTp(true) == false,
        'un-armed the helper answered true for an owned destination')
    unprobe()
end

tests['[driven] ⭐ armed in turbo it drops exactly the destinations the branch did not choose']
= function()
    ss.with_candidate('tprupt', function()
        local J = turbo_world()
        assert(J.IsSoakCandidate('tprupt') == true,
            'the gate did not open, so this leg measured the unarmed tree')
        -- The whole argument domain, as equality assertions.
        assert(J.ShouldDropUnownedRuptureTp(false) == true,
            'armed, a destination the branch did NOT choose survived')
        assert(J.ShouldDropUnownedRuptureTp(nil) == true,
            'armed, an unset ownership flag was treated as ownership')
        assert(J.ShouldDropUnownedRuptureTp(true) == false,
            'armed, it dropped a destination the branch DID choose -- that is '
            .. 'the one direction this lever must never take')
        unprobe()
    end, side_of())
end

tests['[driven] armed outside turbo it drops nothing'] = function()
    ss.with_candidate('tprupt', function()
        GAMEMODE_TURBO = nil                    -- luacheck: ignore
        local J = rf.load(FRAME, SUBJ)
        GetGameMode = function() return 22 end  -- luacheck: ignore
        assert(J.IsSoakCandidate('tprupt') == true,
            'the gate did not open, so this leg measured the unarmed tree')
        assert(J.ShouldDropUnownedRuptureTp(false) == false,
            'armed OUTSIDE turbo the helper dropped a destination; this family '
            .. 'is turbo-only')
        unprobe()
    end, side_of())
end

tests['[control] un-armed the gate is shut'] = function()
    local J = rf.load(FRAME, SUBJ)
    assert(J.IsSoakCandidate('tprupt') == false, 'the gate is open with nothing armed')
end

tests['[control] armed on the other side the gate stays shut'] = function()
    local sOther = side_of() == 'radiant' and 'dire' or 'radiant'
    ss.with_candidate('tprupt', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate('tprupt') == false,
            'the gate fired for a bot on the other side')
    end, sOther)
end

tests['[control] armed under another id the gate stays shut'] = function()
    ss.with_candidate('tpstale', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate('tprupt') == false,
            'the gate fired under a different candidate id')
        -- ⭐ AND THE SIBLING IS UNMOVED BY THIS ONE: two ids, two branches.
        assert(J.IsSoakCandidate('tpstale') == true,
            'arming the sibling id did not open the sibling gate')
    end, side_of())
end

return tests

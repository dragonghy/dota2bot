-- [hero, GH #TBD / backlog -162] Wraith King `X.ConsiderW` attack branch: the
-- skeleton bank is priced as a RATIO of its own capacity while every term the
-- release is worth is an ABSOLUTE count -- and the ratio is NON-MONOTONE IN RANK.
--
-- THE DEFECT IN ONE TABLE.  Bone Guard fields one skeleton per charge.  The hero
-- file's own re-anchored KV block (:44 region, live datafeed 2026-08-22) gives
-- max_skeleton_charges 2/4/6/8 and skeleton damage 34/39/43/49, +25 more against
-- heroes.  `nStack / maxStack >= 0.6` therefore demands:
--
--   rank  maxStack  integer bank needed  per-skeleton hero damage
--     1       2              2                     59
--     2       4              3                     64
--     3       6              4                     68
--     4       8              5                     74
--
-- so a bank of 4 is COMMITTED at rank 3 (4/6 = 0.67) and REFUSED at rank 4
-- (4/8 = 0.50) -- same bank, same 100-mana 42s-cooldown release, more damage per
-- skeleton, answer flips to no.  Same inversion at bank 3 (accepted at rank 2,
-- refused at 3 and 4) and bank 2 (accepted at rank 1, refused at 2, 3 and 4).
-- Three inversions, all pointing the same way: the gate tightens in ABSOLUTE
-- terms exactly where each charge is worth most.
--
-- WHY THIS IS WORTH A LEVER RATHER THAN A COMMENT.  The `wkbonefight` domain
-- reading delivered 2026-09-06 (queue.json hero-31, consumed 2026-09-09,
-- state.json:wkbonefight_ring_20260909) records in its own section 6 that CHARGE
-- STACK COUNTS COULD NOT BE BOUGHT -- which is exactly why its first three
-- columns are upper bounds.  The unmeasured filter behind that phrase is this
-- conjunct.  It has been sitting under a published reading as an unknown, and
-- until 2026-09-13 nobody asked whether it was correct.
--
-- ⚠️ WHAT THIS FILE CANNOT SHOW, SAID BEFORE ANY NUMBER IN IT IS QUOTED.
-- `nStack` is a MODIFIER STACK COUNT.  make_fixture.py dumps no modifiers, and
-- `modifier_skeleton_king_bone_guard` appears on 0 frames of the corpus
-- (tests/test_wk_bone_guard_talent_bypass.lua section 2 measures the same zero
-- from the other direction and is the older witness).  So NO frame this repo
-- holds can drive this conjunct end to end, and §5 pins that zero rather than
-- letting a later round rediscover it.  What the corpus CAN carry is the RANK
-- half -- ability levels ARE dumped -- so §6 pins the inversion on REAL FRAMES
-- at real ranks.  Frequency is not priced anywhere here: that is queue.json
-- hero-70 (zero EC2).
--
-- ⭐ DIRECTION IS GUARANTEED BY CONSTRUCTION, NOT BY DATA.  The shipped
-- predicate is bound first and returned alone whenever true, so arming can only
-- move the answer false -> true.  §2 sweeps the whole rank x bank grid rather
-- than asserting single values, because the mutation that "reads like what this
-- round wanted to do" while silently DELETING a shipped release (e.g. replacing
-- the shipped disjunct instead of adding to it) is only caught by a sweep.  That
-- is the `wkbonefight` lesson (state.json:wkbonefight_20260905, section on M4)
-- reused on a second conjunct of the same `if`.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_skeleton_king.lua'
local UNIT = 'npc_dota_hero_skeleton_king'
local HELPER = 'wk_IsBoneGuardBankCommittable'
local CAND = 'wkbonebank'
local BONE_MOD = 'modifier_skeleton_king_bone_guard'
local FIXTURE_DIR = 'tests/fixtures'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Comments stripped, so a census counting CODE shapes cannot be satisfied by
--- prose that merely mentions the expression (backlog -160's second lesson: the
--- census that counted the fix's own comment).  The block comment in this hero
--- file is an npc dump whose lines do NOT start with `--`, so it is stripped as
--- a block first -- the trap test_wk_fact_anchor.lua documents.
local function strip_comments(s)
    return (s:gsub('%-%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', ''))
end

local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if not s then return n end
        n, at = n + 1, e + 1
    end
end

local SRC_TEXT = read_file(SRC)
local SRC_CODE = strip_comments(SRC_TEXT)

--- ⭐ READ OFF THE SOURCE, never re-typed.  A mirror that froze today's 2 would
--- keep passing the day the hero file changed it -- the stale-mirror defect
--- tests/test_cast_ring_mirror_discipline.lua exists to catch.
local FLOOR = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nBoneGuardShippedFloor%s*=%s*([^\n]+)'),
    'X.nBoneGuardShippedFloor is gone from ' .. SRC)))()

--- The ladder, recorded from the live datafeed read of 2026-08-22 that the hero
--- file's own ABILITY INDEX MAP block carries.  Kept as data so a re-anchor
--- edits ONE table; §3 re-derives every threshold in this file from it rather
--- than trusting a typed number.
local LADDER = {
    max_skeleton_charges = { 2, 4, 6, 8 },
    skeleton_damage      = { 34, 39, 43, 49 },
    hero_bonus_damage    = 25,
}

local RATIO = 0.6

--- One loaded world with the helper reachable.  `opt.armed` arms CAND;
--- `opt.nonTurbo` undoes rf.load's forced turbo AFTER load, exactly as
--- tests/test_lion_q_lane_push_clock.lua does.
local function world(path, opt)
    opt = opt or {}
    local J = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return id == CAND and opt.armed == true end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    return rf.load_hero('skeleton_king')
end

--- Any frame will do for the algebra sections: the helper reads only its two
--- arguments and the two gate predicates.  Picking the first WK-subject frame
--- keeps the world a real one anyway.
local function any_frame()
    local p = assert(io.popen('ls ' .. FIXTURE_DIR .. ' 2>/dev/null'))
    local names = {}
    -- UNRESOLVED_HAND_READ: io.popen over a literal directory, non-recursive
    -- `ls`, registered per GH #774's hand-read list.  It cannot reach
    -- bots/Customize/.
    for name in p:lines() do
        if name:match('^f_.*%.lua$') then names[#names + 1] = name end
    end
    p:close()
    table.sort(names)
    assert(#names > 0, 'corpus directory ' .. FIXTURE_DIR .. ' yielded no frame')
    for _, name in ipairs(names) do
        local ok, fx = pcall(dofile, FIXTURE_DIR .. '/' .. name)
        if ok and type(fx) == 'table' and fx.self == UNIT then
            return FIXTURE_DIR .. '/' .. name
        end
    end
    error('no WK-subject frame in ' .. FIXTURE_DIR)
end

local FRAME = any_frame()

-- ===========================================================================
-- §1  THE GATE IS WIRED, AND IT NAMES EXACTLY ONE ID
-- ===========================================================================

tests['1.1 helper exists, is turbo-gated, and names only its own id'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, HELPER))
    assert(body:find('J.IsModeTurbo()', 1, true),
        HELPER .. ' lost its turbo guard -- a soak candidate must be turbo-only')
    assert(count(body, "IsSoakCandidate( '") == 1,
        HELPER .. ' must hold exactly ONE IsSoakCandidate call (it holds '
        .. count(body, "IsSoakCandidate( '") .. ')')
    assert(body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        HELPER .. ' no longer names ' .. CAND)
    -- pullcad trap: a gate that names ANOTHER id freezes FALSE the day that id
    -- is promoted, and check_armed_wiring.py would still call this WIRED.
    for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == CAND,
            HELPER .. ' names a second id ' .. id .. ' -- the pullcad trap')
    end
end

tests['1.2 the call site is wired and the literal ratio is gone from it'] = function()
    assert(count(SRC_CODE, 'X.' .. HELPER) == 2,
        'expected exactly two X.' .. HELPER .. ' occurrences in code (the '
        .. 'definition and the single call site), got '
        .. count(SRC_CODE, 'X.' .. HELPER))
    -- The shipped ratio must survive in exactly ONE place -- inside the helper.
    -- Two copies means the call site was reverted or a second branch grew one.
    assert(count(SRC_CODE, 'nStack / maxStack >= 0.6') == 1,
        'the expression `nStack / maxStack >= 0.6` appears '
        .. count(SRC_CODE, 'nStack / maxStack >= 0.6') .. ' times in code; it '
        .. 'must live in exactly one place, the helper body')
    local body = strip_comments(fn_body(SRC_TEXT, HELPER))
    assert(body:find('nStack / maxStack >= 0.6', 1, true),
        'the one surviving copy of the shipped ratio is NOT inside ' .. HELPER)
end

tests['1.3 the id appears in bots/ exactly once, inside the helper'] = function()
    assert(count(SRC_CODE, CAND) == 1,
        CAND .. ' appears ' .. count(SRC_CODE, CAND) .. ' times in the code of '
        .. SRC .. '; a soak id must be readable at exactly one site')
end

-- ===========================================================================
-- §2  DIRECTION BY CONSTRUCTION -- SWEEP THE WHOLE GRID, NEVER A SINGLE VALUE
-- ===========================================================================

--- The shipped answer, computed from the ladder and NOT from the hero file, so
--- that a mutation inside the helper cannot move both sides of the comparison.
local function shipped_answer(bank, rank)
    local maxStack = LADDER.max_skeleton_charges[rank]
    return bank / maxStack >= RATIO
end

tests['2.1 gate OFF reproduces the shipped ratio on every (rank, bank) cell'] =
function()
    local X = world(FRAME, { armed = false })
    local n = 0
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            local got = X[HELPER](bank, maxStack) and true or false
            assert(got == shipped_answer(bank, rank),
                'gate OFF, rank ' .. rank .. ' bank ' .. bank .. ': helper said '
                .. tostring(got) .. ', shipped ratio says '
                .. tostring(shipped_answer(bank, rank)))
            n = n + 1
        end
    end
    -- 3 + 5 + 7 + 9 = 24: bank runs 0..maxStack INCLUSIVE at each of the four
    -- ranks, so each rank contributes maxStack+1 cells, not maxStack.
    assert(n == 24, 'expected 24 grid cells (banks 0..maxStack at ranks 1-4), '
        .. 'swept ' .. n)
end

tests['2.2 turbo OFF but id armed still reproduces the shipped ratio'] =
function()
    -- A soak candidate is turbo-only.  Without this cell an armed leg that lost
    -- its `J.IsModeTurbo()` conjunct would pass §2.1 and §2.3 both.
    local X = world(FRAME, { armed = true, nonTurbo = true })
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            assert((X[HELPER](bank, maxStack) and true or false)
                == shipped_answer(bank, rank),
                'armed but NON-TURBO, rank ' .. rank .. ' bank ' .. bank
                .. ': the leg fired outside turbo')
        end
    end
end

tests['2.3 gate ON is a strict SUPERSET -- it never deletes a shipped release'] =
function()
    local X = world(FRAME, { armed = true })
    local added = 0
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            local armed = X[HELPER](bank, maxStack) and true or false
            local ship = shipped_answer(bank, rank)
            if ship then
                assert(armed, 'ARMED DELETED A SHIPPED RELEASE at rank ' .. rank
                    .. ' bank ' .. bank .. '.  This lever\'s negative-read '
                    .. 'attribution depends on the armed set being a strict '
                    .. 'superset; a deletion invalidates every verdict quoting it')
            end
            if armed and not ship then added = added + 1 end
        end
    end
    -- M4-shaped mutation trap: a leg that merely REPLACED the ratio with the
    -- floor would still be a superset here, so the count is pinned too.  The
    -- added cells are exactly (rank2,bank2), (rank3,bank2..3), (rank4,bank2..4).
    assert(added == 6, 'armed added ' .. added .. ' cells, expected 6.  A '
        .. 'different count means the floor moved or the grid did; re-derive '
        .. 'via §4 before editing this number')
end

-- ===========================================================================
-- §3  THE INVERSION IS RE-DERIVED FROM THE LADDER, NOT ASSERTED
-- ===========================================================================

tests['3.1 the shipped ratio is non-monotone in rank at a FIXED bank'] = function()
    local inversions = {}
    for bank = 1, 8 do
        local accepted, refused = {}, {}
        for rank = 1, 4 do
            if bank <= LADDER.max_skeleton_charges[rank] then
                if shipped_answer(bank, rank) then accepted[#accepted + 1] = rank
                else refused[#refused + 1] = rank end
            end
        end
        for _, r in ipairs(refused) do
            if #accepted > 0 and r > accepted[1] then
                inversions[#inversions + 1] = { bank = bank, lo = accepted[1], hi = r }
            end
        end
    end
    -- bank 2: accepted@1, refused@2,3,4  (3 pairs)
    -- bank 3: accepted@2, refused@3,4    (2 pairs)
    -- bank 4: accepted@2, refused@4      (1 pair)
    assert(#inversions == 6, 'expected 6 (bank, lower-rank-accepts, '
        .. 'higher-rank-refuses) pairs from the ladder, derived ' .. #inversions
        .. '.  If this is 0 the ladder changed and the whole lever is stale')
    -- ⭐ Each inversion must also be a DOMINANCE inversion: the refused state
    -- must be worth strictly MORE than the accepted one.  Non-monotone alone is
    -- not a defect; non-monotone against a strictly larger payoff is.
    for _, inv in ipairs(inversions) do
        local lo = inv.bank * (LADDER.skeleton_damage[inv.lo] + LADDER.hero_bonus_damage)
        local hi = inv.bank * (LADDER.skeleton_damage[inv.hi] + LADDER.hero_bonus_damage)
        assert(hi > lo, 'bank ' .. inv.bank .. ': rank ' .. inv.hi
            .. ' is refused but worth ' .. hi .. ', rank ' .. inv.lo
            .. ' is accepted and worth ' .. lo
            .. ' -- that is not a dominance inversion, so this file\'s '
            .. 'argument does not cover it')
    end
end

-- ===========================================================================
-- §4  THE FLOOR IS THE MONOTONE CLOSURE -- RE-DERIVED, NOT TYPED
-- ===========================================================================

tests['4.1 X.nBoneGuardShippedFloor equals the smallest bank shipped commits on'] =
function()
    local smallest = nil
    for rank = 1, 4 do
        for bank = 0, LADDER.max_skeleton_charges[rank] do
            if shipped_answer(bank, rank) and (smallest == nil or bank < smallest) then
                smallest = bank
            end
        end
    end
    assert(smallest ~= nil, 'the shipped rule commits on NO cell of the ladder')
    assert(FLOOR == smallest, 'X.nBoneGuardShippedFloor is ' .. tostring(FLOOR)
        .. ' but the smallest bank the shipped rule commits on anywhere is '
        .. tostring(smallest) .. '.  The floor is READ OFF the shipped rule; it '
        .. 'is not a tuning knob, so a mismatch means one of the two moved')
end

tests['4.2 every cell the armed leg adds is one shipped commits on at a LOWER rank'] =
function()
    -- This is the whole value argument, executable: the lever invents no
    -- willingness this file does not already display.
    local X = world(FRAME, { armed = true })
    local checked = 0
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            if X[HELPER](bank, maxStack) and not shipped_answer(bank, rank) then
                local witness = nil
                for lower = 1, rank - 1 do
                    if bank <= LADDER.max_skeleton_charges[lower]
                        and shipped_answer(bank, lower) then
                        witness = lower
                        break
                    end
                end
                assert(witness ~= nil, 'armed adds (rank ' .. rank .. ', bank '
                    .. bank .. ') and NO lower rank commits on that bank -- the '
                    .. 'monotone-closure argument does not cover this cell, so '
                    .. 'the lever is wider than its own justification')
                assert(LADDER.skeleton_damage[rank] > LADDER.skeleton_damage[witness],
                    'armed adds (rank ' .. rank .. ', bank ' .. bank
                    .. ') on the strength of rank ' .. witness
                    .. ', but the skeletons are not stronger there')
                checked = checked + 1
            end
        end
    end
    assert(checked == 6, 'expected to check 6 added cells, checked ' .. checked)
end

-- ===========================================================================
-- §5  THE BANK IS UNREPRESENTABLE IN THIS CORPUS -- PIN THE ZERO
-- ===========================================================================

tests['5.1 no fixture frame carries the bone guard modifier (bank unbuyable)'] =
function()
    local p = assert(io.popen('ls ' .. FIXTURE_DIR .. ' 2>/dev/null'))
    -- UNRESOLVED_HAND_READ: same registered io.popen as above.
    local carriers, total = 0, 0
    for name in p:lines() do
        if name:match('^f_.*%.lua$') then
            total = total + 1
            if read_file(FIXTURE_DIR .. '/' .. name):find(BONE_MOD, 1, true) then
                carriers = carriers + 1
            end
        end
    end
    p:close()
    assert(total > 0, 'corpus is empty')
    assert(carriers == 0, carriers .. ' of ' .. total .. ' frames now carry '
        .. BONE_MOD .. '.  THIS IS GOOD NEWS, not a regression: the bank half '
        .. 'of this lever just became frame-checkable.  Build the fixture '
        .. 'assertion and retire queue.json hero-70\'s first column')
end

-- ===========================================================================
-- §6  THE RANK HALF *IS* REAL-FRAME CHECKABLE -- PIN THE INVERSION ON FRAMES
-- ===========================================================================

tests['6.1 real frames exist at the two ranks the bank-4 inversion needs'] =
function()
    local p = assert(io.popen('ls ' .. FIXTURE_DIR .. ' 2>/dev/null'))
    -- UNRESOLVED_HAND_READ: same registered io.popen as above.
    local seen = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    for name in p:lines() do
        if name:match('^f_.*%.lua$') then
            local src = read_file(FIXTURE_DIR .. '/' .. name)
            for lv in src:gmatch(
                "name = 'skeleton_king_bone_guard', level = (%d+)") do
                lv = tonumber(lv)
                if lv >= 1 and lv <= 4 then seen[lv] = seen[lv] + 1 end
            end
        end
    end
    p:close()
    -- The bank-4 inversion is the headline one: accepted at rank 3, refused at
    -- rank 4.  Both of those ranks must exist in games we actually play, or the
    -- inversion is an arithmetic curiosity rather than a decision the bot makes.
    assert(seen[3] > 0 and seen[4] > 0,
        'the corpus holds ' .. seen[3] .. ' rank-3 and ' .. seen[4]
        .. ' rank-4 Bone Guard frames; the headline inversion needs BOTH ranks '
        .. 'to occur in real games or it is arithmetic only')
    -- Pinned so a corpus that quietly loses its high-rank frames is visible.
    assert(seen[1] + seen[2] + seen[3] + seen[4] >= 33,
        'only ' .. (seen[1] + seen[2] + seen[3] + seen[4]) .. ' Bone Guard rank '
        .. 'sightings in the corpus (was 33 on 2026-09-13); a shrinking corpus '
        .. 'weakens §6 and must be noticed, not absorbed')
end

tests['6.2 on a real frame, the helper answers the inversion the ladder predicts'] =
function()
    -- The bank cannot come off the frame (§5), so it is supplied; the RANK is
    -- the half the frame carries, and the point of this cell is that the two
    -- ranks it compares are ranks real WK bots really reach.
    local X = world(FRAME, { armed = false })
    local r3 = LADDER.max_skeleton_charges[3]
    local r4 = LADDER.max_skeleton_charges[4]
    assert(X[HELPER](4, r3), 'shipped refuses bank 4 at rank 3 -- the ladder '
        .. 'says 4/6 = 0.67 clears 0.6, so either the ladder or the helper moved')
    assert(not X[HELPER](4, r4), 'shipped ACCEPTS bank 4 at rank 4 -- the '
        .. 'inversion this whole file is about is gone; re-price the lever')

    local Y = world(FRAME, { armed = true })
    assert(Y[HELPER](4, r4), 'armed still refuses bank 4 at rank 4 -- the lever '
        .. 'does not do the one thing it was landed to do')
end

-- ===========================================================================
-- §7  GATE-OFF BEHAVIOR INCLUDES THE DEGENERATE maxStack, BYTE FOR BYTE
-- ===========================================================================

tests['7.1 maxStack 0 answers exactly what the shipped expression answered'] =
function()
    -- Adding a `maxStack > 0` guard inside the helper would be a gate-OFF
    -- behavior change -- the one thing a soak candidate may never do.  Lua 5.1:
    -- 2/0 = inf (inf >= 0.6 is true), 0/0 = nan (nan >= 0.6 is false).
    local X = world(FRAME, { armed = false })
    assert(X[HELPER](2, 0) == true,
        'gate OFF with maxStack 0 and a non-empty bank must answer true, as the '
        .. 'shipped `nStack / maxStack >= 0.6` did (inf >= 0.6).  A guard was '
        .. 'added to the helper and it changed shipped behavior')
    assert(X[HELPER](0, 0) == false,
        'gate OFF with maxStack 0 and an empty bank must answer false, as the '
        .. 'shipped expression did (nan >= 0.6)')
end

return tests

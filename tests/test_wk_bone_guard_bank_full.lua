-- [ratchet] [hero] Wraith King `X.ConsiderW` BRANCH 2 (the lane-front / farming
-- release): the skeleton bank is priced as `nStack == maxStack`, which is the
-- neighbouring ratio rule at threshold 1.0 -- and a ratio against an ABSOLUTE
-- payoff is NON-MONOTONE IN RANK.
--
-- WHY THIS FILE EXISTS SEPARATELY FROM tests/test_wk_bone_guard_bank_floor.lua.
-- That file gates branch 1 (`wkbonebank`, `nStack / maxStack >= 0.6`) and its
-- helper is never called from branch 2.  Both the hero file's header and that
-- test's own prose say branch 2's equality was left alone -- "That predates this
-- lever and is unchanged by it".  So the strictest member of the family has been
-- riding ungated since the file was inherited.  `wkbonefull` is that gate.
--
-- THE DEFECT IN ONE TABLE.  One skeleton per charge; the hero file's re-anchored
-- KV block (:44 region, live datafeed 2026-08-22) gives max_skeleton_charges
-- 2/4/6/8 and skeleton damage 34/39/43/49, +25 more against heroes.  At
-- threshold 1.0 the shipped rule commits on exactly ONE bank per rank:
--
--   rank  maxStack  the only committed bank  per-skeleton hero damage
--     1       2                2                       59
--     2       4                4                       64
--     3       6                6                       68
--     4       8                8                       74
--
-- so a bank of 2 is COMMITTED at rank 1 and REFUSED at rank 2, 3 and 4 -- same
-- bank, same 100-mana 42s-cooldown release, strictly more damage per skeleton,
-- answer flips to no.  Same at bank 4 (accepted at 2, refused at 3 and 4) and
-- bank 6 (accepted at 3, refused at 4).  Six pairs; section 3 DERIVES them from
-- the ladder rather than trusting the table above.
--
-- WHY IT BITES HARDER THAN ON BRANCH 1.  A rank-up does not touch the bank, so
-- the instant Bone Guard is levelled this branch goes silent until the bank
-- refills to the NEW capacity.  Branch 1 keeps 60% of the ladder; branch 2 keeps
-- a single point of it.
--
-- ⭐ THE ARMED LEG IS THE NEIGHBOUR'S PREDICATE VERBATIM, and that is derived,
-- not copied: the dominance closure of {(1,2),(2,4),(3,6),(4,8)} under "more
-- skeletons, each at least as strong" is exactly `bank >= 2`, i.e.
-- X.nBoneGuardShippedFloor, which this file already read OFF the shipped rule.
-- Section 4 re-derives it; section 5 asserts the two armed legs agree instead of
-- letting them drift.
--
-- ⚠️ WHAT THIS FILE CANNOT SHOW, said before any number in it is quoted.
-- `nStack` is a MODIFIER STACK COUNT; make_fixture.py dumps no modifiers and
-- `modifier_skeleton_king_bone_guard` appears on 0 frames of the corpus.  So NO
-- frame this repo holds drives this conjunct end to end -- §6 pins that zero
-- rather than letting a later round rediscover it.  The RANK half IS dumped, so
-- §7 pins the inversion on real frames at real ranks.  Frequency is not priced
-- anywhere here: iterations/queue.json hero-84 (zero EC2).
--
-- ⭐ DIRECTION IS GUARANTEED BY CONSTRUCTION, NOT BY DATA.  The shipped equality
-- is bound first and returned alone whenever true, so arming can only move the
-- answer false -> true.  §2 sweeps the whole rank x bank grid rather than
-- asserting single values, because the mutation that "reads like what this round
-- wanted to do" while silently DELETING a shipped release (replacing the shipped
-- disjunct instead of adding to it) is only caught by a sweep.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_skeleton_king.lua'
local UNIT = 'npc_dota_hero_skeleton_king'
local HELPER = 'wk_IsBoneGuardBankFull'
local SIBLING = 'wk_IsBoneGuardBankCommittable'
local CAND = 'wkbonefull'
local SIBLING_CAND = 'wkbonebank'
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
--- prose that merely mentions the expression.  The block comment in this hero
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
--- keep passing the day the hero file changed it.
local FLOOR = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nBoneGuardShippedFloor%s*=%s*([^\n]+)'),
    'X.nBoneGuardShippedFloor is gone from ' .. SRC)))()

--- The ladder, from the live datafeed read of 2026-08-22 that the hero file's
--- own ABILITY INDEX MAP block carries.  Kept as data so a re-anchor edits ONE
--- table; §3 and §4 re-derive every threshold from it.
local LADDER = {
    max_skeleton_charges = { 2, 4, 6, 8 },
    skeleton_damage      = { 34, 39, 43, 49 },
    hero_bonus_damage    = 25,
}

--- One loaded world with the helper reachable.  `opt.armed` arms CAND;
--- `opt.armed_other` arms an unrelated id instead (the wrong-name cell);
--- `opt.nonTurbo` undoes rf.load's forced turbo AFTER load.
local function world(path, opt)
    opt = opt or {}
    local J = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id)
        if opt.armed_other then return id == opt.armed_other end
        return id == CAND and opt.armed == true
    end
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

--- The shipped answer for branch 2, computed from the LADDER and not from the
--- hero file, so a mutation inside the helper cannot move both sides.
local function shipped_answer(bank, rank)
    return bank == LADDER.max_skeleton_charges[rank]
end

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
    -- is promoted, and check_armed_wiring.py would still call this WIRED.  The
    -- sibling gate is the one a future round is most likely to reach for here,
    -- because the two armed legs are deliberately identical.
    for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == CAND,
            HELPER .. ' names a second id ' .. id .. ' -- the pullcad trap')
    end
end

tests['1.2 the call site is wired and the equality lives in exactly one place'] =
function()
    assert(count(SRC_CODE, 'X.' .. HELPER) == 2,
        'expected exactly two X.' .. HELPER .. ' occurrences in code (the '
        .. 'definition and the single call site), got '
        .. count(SRC_CODE, 'X.' .. HELPER))
    assert(count(SRC_CODE, 'nStack == maxStack') == 1,
        'the expression `nStack == maxStack` appears '
        .. count(SRC_CODE, 'nStack == maxStack') .. ' times in code; it must '
        .. 'live in exactly one place, the helper body.  Two copies means the '
        .. 'call site was reverted or a second branch grew one')
    local body = strip_comments(fn_body(SRC_TEXT, HELPER))
    assert(body:find('nStack == maxStack', 1, true),
        'the one surviving copy of the shipped equality is NOT inside ' .. HELPER)
    -- Branch 2's OTHER disjunct is not this lever's subject and must survive
    -- untouched, or a wave read of `wkbonefull` is really a bundle read.
    local considerw = SRC_TEXT:match('function X%.ConsiderW%b()(.-)\nend')
    assert(considerw ~= nil and considerw:find('talent6:IsTrained()', 1, true),
        'the t20 bypass beside this term is gone from X.ConsiderW -- that is '
        .. "`wkbonespawn`'s subject, not this one's, and it must not move here")
end

tests['1.3 the id appears in bots/ exactly once, inside the helper'] = function()
    assert(count(SRC_CODE, CAND) == 1,
        CAND .. ' appears ' .. count(SRC_CODE, CAND) .. ' times in the code of '
        .. SRC .. '; a soak id must be readable at exactly one site')
end

-- ===========================================================================
-- §2  DIRECTION BY CONSTRUCTION -- SWEEP THE WHOLE GRID, NEVER A SINGLE VALUE
-- ===========================================================================

tests['2.1 gate OFF reproduces the shipped equality on every (rank, bank) cell'] =
function()
    local X = world(FRAME, { armed = false })
    local n = 0
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            local got = X[HELPER](bank, maxStack) and true or false
            assert(got == shipped_answer(bank, rank),
                'gate OFF, rank ' .. rank .. ' bank ' .. bank .. ': helper said '
                .. tostring(got) .. ', shipped equality says '
                .. tostring(shipped_answer(bank, rank)))
            n = n + 1
        end
    end
    -- 3 + 5 + 7 + 9 = 24: bank runs 0..maxStack INCLUSIVE at each rank.
    assert(n == 24, 'expected 24 grid cells (banks 0..maxStack at ranks 1-4), '
        .. 'swept ' .. n)
end

tests['2.2 turbo OFF but id armed still reproduces the shipped equality'] =
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

tests['2.3 a DIFFERENT armed id does not open this gate'] = function()
    -- The wrong-name cell: a helper that read `IsSoakCandidate(anything)` -- or
    -- whose gate was edited to the sibling's id -- passes §2.1 and §2.2 and
    -- fails only here.
    local X = world(FRAME, { armed_other = SIBLING_CAND })
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            assert((X[HELPER](bank, maxStack) and true or false)
                == shipped_answer(bank, rank),
                'arming ' .. SIBLING_CAND .. ' opened ' .. CAND
                .. ' at rank ' .. rank .. ' bank ' .. bank
                .. ' -- the gate reads the wrong name')
        end
    end
end

tests['2.4 gate ON is a strict SUPERSET -- it never deletes a shipped release'] =
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
                    .. ' bank ' .. bank .. ".  This lever's negative-read "
                    .. 'attribution depends on the armed set being a strict '
                    .. 'superset; a deletion invalidates every verdict quoting it')
            end
            if armed and not ship then added = added + 1 end
        end
    end
    -- Mutation trap: a leg that merely REPLACED the equality with the floor
    -- would still be a superset here, so the count is pinned too.  Added cells
    -- are (r1: none), (r2: banks 2-3), (r3: banks 2-5), (r4: banks 2-7).
    assert(added == 12, 'armed added ' .. added .. ' cells, expected 12.  A '
        .. 'different count means the floor moved or the grid did; re-derive '
        .. 'via §4 before editing this number')
end

-- ===========================================================================
-- §3  THE INVERSION IS RE-DERIVED FROM THE LADDER, NOT ASSERTED
-- ===========================================================================

tests['3.1 the shipped equality is non-monotone in rank at a FIXED bank'] =
function()
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
                inversions[#inversions + 1] =
                    { bank = bank, lo = accepted[1], hi = r }
            end
        end
    end
    -- bank 2: accepted@1, refused@2,3,4  (3 pairs)
    -- bank 4: accepted@2, refused@3,4    (2 pairs)
    -- bank 6: accepted@3, refused@4      (1 pair)
    assert(#inversions == 6, 'expected 6 (bank, lower-rank-accepts, '
        .. 'higher-rank-refuses) pairs from the ladder, derived ' .. #inversions
        .. '.  If this is 0 the ladder changed and the whole lever is stale')
    -- ⭐ Each inversion must also be a DOMINANCE inversion: the refused state
    -- must be worth strictly MORE than the accepted one.  Non-monotone alone is
    -- not a defect; non-monotone against a strictly larger payoff is.
    for _, inv in ipairs(inversions) do
        local lo = inv.bank
            * (LADDER.skeleton_damage[inv.lo] + LADDER.hero_bonus_damage)
        local hi = inv.bank
            * (LADDER.skeleton_damage[inv.hi] + LADDER.hero_bonus_damage)
        assert(hi > lo, 'bank ' .. inv.bank .. ': rank ' .. inv.hi
            .. ' is refused but worth ' .. hi .. ', rank ' .. inv.lo
            .. ' is accepted and worth ' .. lo
            .. " -- that is not a dominance inversion, so this file's "
            .. 'argument does not cover it')
    end
end

-- ===========================================================================
-- §4  THE FLOOR IS THE DOMINANCE CLOSURE -- RE-DERIVED, NOT TYPED
-- ===========================================================================

tests['4.1 X.nBoneGuardShippedFloor equals the smallest bank branch 2 commits on'] =
function()
    local smallest = nil
    for rank = 1, 4 do
        for bank = 0, LADDER.max_skeleton_charges[rank] do
            if shipped_answer(bank, rank)
                and (smallest == nil or bank < smallest) then
                smallest = bank
            end
        end
    end
    assert(smallest ~= nil, 'branch 2 commits on NO cell of the ladder')
    assert(FLOOR == smallest, 'X.nBoneGuardShippedFloor is ' .. tostring(FLOOR)
        .. ' but the smallest bank branch 2 commits on anywhere is '
        .. tostring(smallest) .. '.  ⭐ The two branches agreeing on this number '
        .. 'is a DERIVED fact (branch 1 bottoms out at 2/2 = 1.0, branch 2 at '
        .. '2 == 2), not a shared constant somebody chose')
end

tests['4.2 every cell the armed leg adds is DOMINATED by one shipped commits on'] =
function()
    -- The whole value argument, executable: the lever invents no willingness
    -- this file does not already display.  Dominance takes BOTH directions --
    -- at least as many skeletons (bank), each at least as strong (rank) --
    -- because branch 2's accept set has one point per rank, so a pure
    -- lower-RANK witness cannot cover an intermediate bank such as (rank 2,
    -- bank 3).  §4.3 shows that the bank direction alone is not enough either.
    local X = world(FRAME, { armed = true })
    local checked = 0
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            if X[HELPER](bank, maxStack) and not shipped_answer(bank, rank) then
                local wr, wb = nil, nil
                for lower = 1, rank do
                    for b = 0, LADDER.max_skeleton_charges[lower] do
                        if b <= bank and shipped_answer(b, lower) then
                            wr, wb = lower, b
                            break
                        end
                    end
                    if wr then break end
                end
                assert(wr ~= nil, 'armed adds (rank ' .. rank .. ', bank '
                    .. bank .. ') and NO dominated shipped cell witnesses it -- '
                    .. 'the closure argument does not cover this cell, so the '
                    .. 'lever is wider than its own justification')
                local hi = bank
                    * (LADDER.skeleton_damage[rank] + LADDER.hero_bonus_damage)
                local lo = wb
                    * (LADDER.skeleton_damage[wr] + LADDER.hero_bonus_damage)
                assert(hi > lo, 'armed adds (rank ' .. rank .. ', bank ' .. bank
                    .. ') worth ' .. hi .. ' on the strength of (rank ' .. wr
                    .. ', bank ' .. wb .. ') worth ' .. lo
                    .. ' -- the witness is not strictly weaker')
                checked = checked + 1
            end
        end
    end
    assert(checked == 12, 'expected to check 12 added cells, checked ' .. checked)
end

tests['4.3 a lower-RANK-only witness would NOT cover the added cells'] =
function()
    -- Registered so nobody "simplifies" §4.2 back to the neighbour's one-
    -- dimensional witness.  Branch 1 accepts a whole interval per rank, so a
    -- lower-rank witness at the SAME bank exists for each of its added cells.
    -- Branch 2 accepts one point per rank, so the same search finds nothing for
    -- the odd banks -- and a §4.2 written that way would red on a correct lever.
    local uncovered = 0
    for rank = 1, 4 do
        for bank = 0, LADDER.max_skeleton_charges[rank] do
            if bank >= FLOOR and not shipped_answer(bank, rank) then
                local witness = nil
                for lower = 1, rank - 1 do
                    if bank <= LADDER.max_skeleton_charges[lower]
                        and shipped_answer(bank, lower) then
                        witness = lower
                        break
                    end
                end
                if witness == nil then uncovered = uncovered + 1 end
            end
        end
    end
    -- Uncovered are the six ODD-bank cells: (r2,b3), (r3,b3), (r3,b5),
    -- (r4,b3), (r4,b5), (r4,b7).  The six even ones are witnessed at (1,2),
    -- (2,4) or (3,6) -- the only banks branch 2 ever commits on.
    assert(uncovered == 6, 'expected 6 of the 12 added cells to have no '
        .. 'same-bank lower-rank witness, counted ' .. uncovered
        .. '.  If this is 0 the ladder became interval-shaped and §4.2 can be '
        .. 'simplified; if it moved, re-read the ladder before touching §4.2')
end

-- ===========================================================================
-- §5  THE TWO ARMED LEGS AGREE -- ASSERTED, NOT LEFT TO DRIFT
-- ===========================================================================

tests['5.1 armed wkbonefull and armed wkbonebank answer the same on every cell'] =
function()
    -- Both armed legs are the dominance closure of their own branch's shipped
    -- rule, and both closures come out at `bank >= FLOOR`.  That is a derived
    -- coincidence, so it is asserted rather than assumed -- if a future round
    -- moves one, this cell names the other.
    -- ⛔ The two GATES still must not mention each other (§1.1); this is a test
    -- reading both helpers, not a predicate depending on both.
    local A = world(FRAME, { armed = true })
    local J = rf.load(FRAME, UNIT)
    J.IsSoakCandidate = function(id) return id == SIBLING_CAND end
    local B = rf.load_hero('skeleton_king')
    for rank = 1, 4 do
        local maxStack = LADDER.max_skeleton_charges[rank]
        for bank = 0, maxStack do
            local a = A[HELPER](bank, maxStack) and true or false
            local b = B[SIBLING](bank, maxStack) and true or false
            assert(a == b, 'rank ' .. rank .. ' bank ' .. bank .. ': armed '
                .. CAND .. ' says ' .. tostring(a) .. ' but armed '
                .. SIBLING_CAND .. ' says ' .. tostring(b)
                .. '.  The two armed legs are the same closure; a divergence '
                .. 'means one branch was re-tuned without the other')
        end
    end
end

-- ===========================================================================
-- §6  THE BANK IS UNREPRESENTABLE IN THIS CORPUS -- PIN THE ZERO
-- ===========================================================================

tests['6.1 no fixture frame carries the bone guard modifier (bank unbuyable)'] =
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
        .. "assertion and retire queue.json hero-84's first column")
end

-- ===========================================================================
-- §7  THE RANK HALF *IS* REAL-FRAME CHECKABLE -- PIN THE INVERSION ON FRAMES
-- ===========================================================================

tests['7.1 real frames exist at the ranks the bank-2 inversion needs'] = function()
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
    -- The headline inversion here is bank 2: committed at rank 1, refused at
    -- every rank above.  Both ends must occur in games we actually play, or the
    -- inversion is arithmetic rather than a decision the bot makes.
    assert(seen[1] > 0 and seen[4] > 0,
        'the corpus holds ' .. seen[1] .. ' rank-1 and ' .. seen[4]
        .. ' rank-4 Bone Guard frames; the headline inversion needs BOTH ranks '
        .. 'to occur in real games or it is arithmetic only')
    assert(seen[1] + seen[2] + seen[3] + seen[4] >= 33,
        'only ' .. (seen[1] + seen[2] + seen[3] + seen[4]) .. ' Bone Guard rank '
        .. 'sightings in the corpus (was 33 on 2026-09-13); a shrinking corpus '
        .. 'weakens §7 and must be noticed, not absorbed')
end

tests['7.2 on a real frame, the helper answers the inversion the ladder predicts'] =
function()
    -- The bank cannot come off the frame (§6), so it is supplied; the RANK is
    -- the half the frame carries, and the point is that both ranks compared are
    -- ranks real WK bots really reach.
    local X = world(FRAME, { armed = false })
    local r1 = LADDER.max_skeleton_charges[1]
    local r4 = LADDER.max_skeleton_charges[4]
    assert(X[HELPER](2, r1), 'shipped refuses bank 2 at rank 1 -- the ladder '
        .. 'says maxStack is 2 there, so either the ladder or the helper moved')
    assert(not X[HELPER](2, r4), 'shipped ACCEPTS bank 2 at rank 4 -- the '
        .. 'inversion this whole file is about is gone; re-price the lever')

    local Y = world(FRAME, { armed = true })
    assert(Y[HELPER](2, r4), 'armed still refuses bank 2 at rank 4 -- the lever '
        .. 'does not do the one thing it was landed to do')
end

-- ===========================================================================
-- §8  GATE-OFF BEHAVIOR INCLUDES THE DEGENERATE maxStack, BYTE FOR BYTE
-- ===========================================================================

tests['8.1 maxStack 0 answers exactly what the shipped equality answered'] =
function()
    -- ⚠️ THIS IS A PRESERVED HAZARD, NOT A REPAIR.  `0 == 0` is true, so the
    -- shipped branch releases on an EMPTY bank whenever max_skeleton_charges
    -- reads 0.  The hero file's header says so in as many words.  A soak
    -- candidate may not move gate-OFF behaviour, so the cell is PINNED here and
    -- left for whoever prices that corner; adding a `maxStack > 0` guard inside
    -- the helper would be exactly the forbidden edit.
    local X = world(FRAME, { armed = false })
    assert(X[HELPER](0, 0) == true,
        'gate OFF with maxStack 0 and an EMPTY bank must answer true, as the '
        .. 'shipped `nStack == maxStack` did (0 == 0).  A guard was added to '
        .. 'the helper and it changed shipped behaviour')
    assert(X[HELPER](2, 0) == false,
        'gate OFF with maxStack 0 and a non-empty bank must answer false, as '
        .. 'the shipped equality did (2 ~= 0)')

    -- And armed: the closure says bank >= FLOOR, so the non-empty cell opens
    -- while the empty one is carried by the shipped leg alone.
    local Y = world(FRAME, { armed = true })
    assert(Y[HELPER](2, 0) == true,
        'armed refuses bank 2 with maxStack 0; the armed leg is `nStack >= '
        .. tostring(FLOOR) .. '` and 2 clears it')
    assert(Y[HELPER](1, 0) == false,
        'armed accepts bank 1 -- that is BELOW the floor this file derived, so '
        .. 'the lever is wider than its justification')
end

return tests

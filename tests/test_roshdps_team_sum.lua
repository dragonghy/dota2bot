-- [ratchet] [strategy 2026-09-16] Soak candidate 'roshdps': the Roshan go/no-go
-- predicate divides a GROUP total by the number of heroes and compares the mean
-- against a bar that was derived for the group.
--
-- THE DEFECT (shipped default, bots/FunLib/jmz_func.lua, J.HasEnoughDPSForRoshan)
-- ---------------------------------------------------------------------------
-- The function walks the candidate heroes and accumulates
--
--     dps = attackDamage * attackSpeed * (1 - roshanArmor / (roshanArmor + 20))
--     DPS = DPS + dps                       <- one accumulator, every hero
--
-- so `DPS` leaves the loop as the GROUP's damage per second. The bar is built
-- from Roshan's own health curve:
--
--     DPSThreshold = roshanHealth / plannedTimeToKill     (plannedTimeToKill = 60)
--
-- i.e. the damage per second a GROUP must sustain to take the pit inside a
-- minute. Both quantities are damage-per-second and both refer to the same
-- party -- the comparison `DPS >= DPSThreshold` is exactly right as written.
--
-- Between the loop and that comparison sits one shipped line:
--
--     DPS = DPS / #heroes
--
-- which converts the group total into a per-hero MEAN and leaves the bar alone.
-- The predicate then asks whether the AVERAGE ally could solo Roshan on
-- schedule. With five alive allies it demands five times the damage the pit
-- actually needs, and the Roshan mode's whole desire hangs off the answer
-- (bots/mode_roshan_generic.lua:132 latches `initDPSFlag` from it, :167 is the
-- gated live re-check, :188 is the outnumbered branch).
--
-- ⭐ WHY THIS IS AN ARITHMETIC DEFECT AND NOT A TUNING OPINION. A conservative
-- author who wanted a margin would raise plannedTimeToKill or the health model;
-- those stay in the same units. Dividing one side of a comparison by the party
-- size makes the two sides answer different questions, and it makes the bar move
-- with the number of heroes brought -- the wrong way round: the more allies show
-- up, the harder this predicate says Roshan is.
--
-- DIRECTION. sum >= sum/n for n >= 1 exactly when sum >= 0, so arming can only
-- turn NOs into YESes. A batch reading that comes back bad therefore CANNOT be
-- read as "the lever stopped the bots taking Roshan"; the only reading available
-- is that the attempts it added were bad ones. §4 exhausts that over a grid
-- instead of asserting it, and prices the one case where it does not hold.
--
-- ⛔ WHAT THIS FILE CAN AND CANNOT BUY -- read before quoting any number below
-- ---------------------------------------------------------------------------
-- ⛔ NEITHER INPUT IS IN THE DUMP. No fixture carries attack damage, attack
-- speed or armor, so the predicate's NUMERIC value is UNASKABLE on this corpus
-- -- not rare, unaskable. §4 therefore feeds the REAL shipped function DECLARED
-- per-hero dps values and proves statements that hold for every value, rather
-- than inventing the engine's numbers for one frame. That absence is pinned as
-- world assertion W1, which goes RED the day the dumper emits any of the three,
-- and it is REVERSE-CALLED (a field that IS in every fixture must be found by
-- the same scanner) so a zero means "absent", not "scanner broken" -- charter
-- 0NEXT27's criterion, and 0NEXT28's refinement that the reverse call has to run
-- on the same command, not merely the same tool.
--
-- ⭐ What the corpus CAN price is the DIVISOR, because `alive` is dumped and
-- the call site's list is "every alive allied hero". §5 measures the real
-- distribution of #heroes on real frames -- that is the factor by which the
-- shipped line overstates the bar, and it is a corpus reading, not a model.
--
-- ⭐ AND THE SECOND DEATH CAUSE WAS CHECKED FIRST (charter 0NEXT28 (酉): "this
-- line is a typo" and "fixing it makes the branch live" are two propositions and
-- the second is false by default). The predicate has three live readers, all in
-- an engine-loaded file; the branch it feeds is not otherwise dead; and §4's
-- grid keeps at least one cell where arming actually moves the answer, so a
-- vacuous proof fails rather than passes.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')          -- owns bots/Customize/soak_side.lua

local JMZ = 'bots/FunLib/jmz_func.lua'
local ROSH = 'bots/mode_roshan_generic.lua'
local HELPER = 'J.ShouldRateRoshanDpsAsTeamSum'
local CAND = 'roshdps'
local FRAME = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SUBJ  = 'npc_dota_hero_obsidian_destroyer'

ss.assert_clean('file load, tests/test_roshdps_team_sum.lua')

local tests = {}

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

local _jmz
local function jmz_src()
    if not _jmz then _jmz = strip_comments(read(JMZ)) end
    return _jmz
end

local function body_of(sPattern, sWhat)
    local src = jmz_src()
    local a = src:find(sPattern)
    assert(a, sWhat .. ' is gone from ' .. JMZ .. '. If it was renamed or '
        .. 'deleted, this lever went with it and so does this file.')
    local b = src:find('\nend', a, true)
    return src:sub(a, b)
end

local function predicate_body()
    return body_of('function J%.HasEnoughDPSForRoshan%(', 'J.HasEnoughDPSForRoshan')
end

local function helper_body()
    return body_of('function ' .. HELPER:gsub('%.', '%%.'), HELPER)
end

-- ==========================================================================
-- §1 THE SITE. Source-level, because it holds on every frame, not some.
-- ==========================================================================

tests['[site] ⭐ the loop still builds ONE group total']
= function()
    local body = predicate_body()
    assert(body:find('DPS = DPS + dps', 1, true),
        'the accumulator line is gone. Everything below rests on `DPS` leaving '
        .. 'the loop as the sum over the party.')
    assert(select(2, body:gsub('DPS = DPS %+ dps', '')) == 1,
        'there is more than one accumulation of DPS now; re-derive what the '
        .. 'name holds before quoting the direction claim.')
end

tests['[site] ⭐ the bar is still the GROUP bar -- the premise of the defect']
= function()
    local body = predicate_body()
    -- Anchored to the end of the statement on purpose: a mutant that appends
    -- `/ #heroes` to the BAR makes the units agree the other way round, and it
    -- still contains this substring. That edit is not this lever -- it changes
    -- the un-armed default in every shipped game -- so the pin has to see it.
    assert(body:find('DPSThreshold = roshanHealth / plannedTimeToKill[ \t]*\n'),
        'the threshold is no longer exactly roshanHealth / plannedTimeToKill. The '
        .. 'claim "the bar was derived for the group" is about THAT expression; '
        .. 'if the bar became per-hero, the shipped division stops being a '
        .. 'defect and this lever must be withdrawn, not re-argued.')
    assert(body:find('plannedTimeToKill = 60', 1, true),
        'plannedTimeToKill is no longer 60s. Not fatal to the lever, but the '
        .. 'numbers quoted in the report and in §4 were computed with 60.')
end

tests['[site] ⭐ un-armed the compared value is still `DPS / #heroes`']
= function()
    local body = predicate_body()
    assert(body:find('DPS = +DPS / #heroes'),
        'the shipped division is gone. Un-armed inertness IS that line: the '
        .. 'gate is supposed to choose between its result and the sum, not to '
        .. 'delete it.')
    assert(body:find('local nDPS = DPS', 1, true),
        'nDPS no longer DEFAULTS to the divided value. The default is the '
        .. 'un-armed behaviour; if it changes, the lever stops being inert in '
        .. 'shipped games and becomes a live edit.')
    assert(body:find('return nDPS >= DPSThreshold', 1, true),
        'the comparison no longer reads nDPS. Every claim in this file is '
        .. 'about which total that name holds.')
end

tests['[site] ⭐ the armed assignment is the ONLY thing behind the gate']
= function()
    local body = predicate_body()
    local armed = body:match('if ' .. HELPER:gsub('%.', '%%.')
        .. '%(%) then%s*(.-)%s*end')
    assert(armed, 'the armed assignment is no longer guarded by ' .. HELPER
        .. '(). Un-armed inertness rests on that guard.')
    assert(armed == 'nDPS = nTeamDPS', 'the guarded body is `' .. armed
        .. '`, not `nDPS = nTeamDPS`. This lever switches which of two values '
        .. 'already in scope is compared, and nothing else.')
    local nCapture = body:find('local nTeamDPS = DPS', 1, true)
    assert(nCapture, 'nTeamDPS is no longer captured, so the armed leg is '
        .. 'reading something other than the group sum.')
    -- ⭐ ORDER, not presence. Captured AFTER the division, nTeamDPS holds the
    -- mean too, the armed leg becomes inert, and a wave reports "tested, no
    -- effect" with nothing raising a hand.
    local nDivide = body:find('DPS = +DPS / #heroes')
    assert(nDivide and nCapture < nDivide,
        'nTeamDPS is captured AFTER the shipped division, so it holds the mean '
        .. 'and the armed leg is the same expression as the un-armed one.')
end

tests['[site] ⭐ the predicate has live readers -- not a constructive zero']
= function()
    local src = strip_comments(read(ROSH))
    local n = select(2, src:gsub('J%.HasEnoughDPSForRoshan%(', ''))
    assert(n >= 2, 'J.HasEnoughDPSForRoshan is read ' .. n .. ' time(s) in '
        .. ROSH .. '. Below 2 the call sites this lever was priced on are '
        .. 'gone: re-check who reads it BEFORE trusting any claim here. A '
        .. 'fixed predicate nobody reads is a provable no-op, which is the '
        .. 'charter 0NEXT28 (酉) trap.')
    assert(src:find('initDPSFlag', 1, true),
        'the latch that carries this predicate into the desire is gone from '
        .. ROSH)
end

-- ==========================================================================
-- §2 THE UNITS PREMISE IS THE REPO'S, NOT THIS FILE'S.
--
-- "damage * attack-speed is one hero's damage per second" is the convention the
-- whole tree computes with. Counted, not asserted -- and the count is part of
-- the conclusion (charter 0NEXT24).
-- ==========================================================================

tests['[premise] ⭐ damage*speed is the tree-wide per-hero dps idiom']
= function()
    local p = assert(io.popen(
        'grep -rl "GetAttackDamage() \\* .*GetAttackSpeed()" bots '
        .. '--include=*.lua | sort'))
    local n = 0
    for _ in p:lines() do n = n + 1 end
    p:close()
    assert(n >= 5, 'only ' .. n .. ' file(s) in bots/ use '
        .. 'GetAttackDamage()*GetAttackSpeed() as a dps. The claim that the '
        .. 'loop accumulates damage-per-second -- and therefore that it shares '
        .. 'units with roshanHealth/seconds -- rests on this being the house '
        .. 'convention rather than one function\'s private scaling.')
end

-- ==========================================================================
-- §3 THE HELPER. Gate-first, turbo-second, one id, no opinions of its own.
-- ==========================================================================

tests['[helper] ⭐ gate-first, turbo-second, exactly one id, reads no unit']
= function()
    local body = helper_body()
    local n = select(2, body:gsub('IsSoakCandidate', ''))
    assert(n == 1, 'the helper names ' .. n .. ' candidate ids; a second one '
        .. 'freezes the gate FALSE the day the other is promoted (the pullcad '
        .. 'trap -- a promoted id is in no armed string).')
    assert(body:find("IsSoakCandidate%( '" .. CAND .. "' %)"),
        "the helper's id is no longer '" .. CAND .. "'")
    local nGate = body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true)
    local nTurbo = body:find('IsModeTurbo', 1, true)
    assert(nGate and nTurbo and nGate < nTurbo,
        'the helper is no longer gate-first-then-turbo; un-armed it must '
        .. 'reach no engine call at all')
    assert(not body:find('bot', 1, true),
        'the helper now reads the bot. It answers one question -- "is this '
        .. 'lever live" -- and the call site owns everything else.')
end

tests['[helper] un-armed it is false, and that is not a corpus fact']
= function()
    local J = rf.load(FRAME, SUBJ)
    assert(J.ShouldRateRoshanDpsAsTeamSum() == false,
        'the helper answers true with nothing armed. Every shipped game would '
        .. 'take the armed branch.')
end

-- ==========================================================================
-- §4 ⭐⭐ THE PROOF. The REAL shipped function, DECLARED inputs, exhaustive
-- over a grid.
--
-- ⛔ The dps numbers below are declared, not measured: the corpus cannot
-- supply them (§5 W1). Every statement proved here is quantified over all
-- values, so a declared grid is the right instrument and a frame would not be
-- a better one.
-- ==========================================================================

--- A hero that answers exactly the methods J.HasEnoughDPSForRoshan reaches:
--- the two dps getters, plus what J.GetArmorReducers touches (item slots,
--- ability lookup, unit name). No armor reducers, so roshanArmor is the plain
--- curve for every case.
local function stub_hero(nDamage, nSpeed)
    return {
        GetAttackDamage  = function() return nDamage end,
        GetAttackSpeed   = function() return nSpeed end,
        GetUnitName      = function() return 'npc_dota_hero_axe' end,
        GetAbilityByName = function() return nil end,
        GetItemInSlot    = function() return nil end,
        FindItemSlot     = function() return -1 end,
    }
end

local function party(nCount, nDamage, nSpeed)
    local t = {}
    for _ = 1, nCount do t[#t + 1] = stub_hero(nDamage, nSpeed) end
    return t
end

--- The shipped arithmetic, recomputed independently of the function under test.
--- §1 pins that the tree still spells it this way.
local function expected(nCount, nDamage, nSpeed, bArmed)
    local nArmor = 30 + 0.375 * math.floor(DotaTime() / 60)
    local nOne = nDamage * nSpeed * (1 - nArmor / (nArmor + 20))
    local nSum = nOne * nCount
    local nHealth = 6000 + 260 * math.floor(DotaTime() / 60)
    local nBar = nHealth / 60
    local nVal = bArmed and nSum or (nSum / nCount)
    return nVal >= nBar
end

-- { heroes, damage, attackSpeed, label }
local GRID = {
    { 5, 120, 1.2, '⭐ five allies, ordinary Turbo right clicks -- the lever\'s domain' },
    { 5, 400, 1.6, 'five allies, late-game carries: both legs say yes' },
    { 5,  20, 0.8, 'five allies, supports only: both legs say no' },
    { 4, 150, 1.3, 'four allies (one dead)' },
    { 3, 200, 1.4, 'three allies -- the gated live re-check\'s minimum party' },
    { 1, 700, 1.9, '⭐ n == 1: the two legs are the SAME expression' },
    { 1,  10, 0.5, 'n == 1, far below the bar' },
    { 2, 300, 1.5, 'two allies, the smallest party where n divides' },
    { 5,   0, 0.0, 'zero damage: sum and mean are both 0' },
}

tests['[proof] ⭐⭐ un-armed, the predicate IS the shipped expression']
= function()
    local J = rf.load(FRAME, SUBJ)
    for _, c in ipairs(GRID) do
        local got = J.HasEnoughDPSForRoshan(party(c[1], c[2], c[3]))
        local want = expected(c[1], c[2], c[3], false)
        assert(got == want, 'un-armed disagreed with the shipped expression on '
            .. 'case "' .. c[4] .. '": got ' .. tostring(got) .. ', `DPS/#heroes '
            .. '>= roshanHealth/60` gives ' .. tostring(want) .. '. Un-armed '
            .. 'inertness is the promise this lever ships on.')
    end
end

tests['[proof] ⭐⭐ armed can only ADD a YES, never withhold one']
= function()
    local sSide
    do
        local _, bot = rf.load(FRAME, SUBJ)
        sSide = bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
    end
    local nMoved, nSame = 0, 0
    ss.with_candidate(CAND, function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.ShouldRateRoshanDpsAsTeamSum() == true,
            'the gate did NOT open under its own id on its own side, so every '
            .. 'armed reading here measured the un-armed tree')
        for _, c in ipairs(GRID) do
            local bArm = J.HasEnoughDPSForRoshan(party(c[1], c[2], c[3]))
            local bUn = expected(c[1], c[2], c[3], false)
            assert(bArm == expected(c[1], c[2], c[3], true),
                'armed disagreed with `sum >= bar` on case "' .. c[4] .. '"')
            assert(not (bUn and not bArm), 'on case "' .. c[4] .. '" arming '
                .. 'turned a YES into a NO. sum >= sum/n for n >= 1 whenever '
                .. 'sum >= 0 -- if that ever fails, the direction claim in the '
                .. 'header is wrong, not the test.')
            if bUn ~= bArm then nMoved = nMoved + 1 else nSame = nSame + 1 end
        end
    end, sSide)
    assert(nMoved > 0, 'no grid case moved at all, so this proof is vacuous -- '
        .. 'exactly the 0NEXT28 (酉) failure. The grid must keep at least one '
        .. 'party that clears the group bar and misses the per-hero one.')
    assert(nSame > 0, 'EVERY grid case moved, which means the grid stopped '
        .. 'containing the cases where the two legs agree (n == 1 is one by '
        .. 'construction). Re-price before quoting it.')
end

tests['[proof] ⭐ at n == 1 the lever is provably a no-op']
= function()
    local sSide
    do
        local _, bot = rf.load(FRAME, SUBJ)
        sSide = bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
    end
    local J0 = rf.load(FRAME, SUBJ)
    local bUn = J0.HasEnoughDPSForRoshan(party(1, 700, 1.9))
    ss.with_candidate(CAND, function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.HasEnoughDPSForRoshan(party(1, 700, 1.9)) == bUn,
            'with one hero, sum and mean are the same number and the two legs '
            .. 'must agree. They did not, so the gate is doing something '
            .. 'besides choosing between them.')
    end, sSide)
end

tests['[proof] ⛔ the empty party: 0/0 is nan and nan >= x is false']
= function()
    local J = rf.load(FRAME, SUBJ)
    assert(J.HasEnoughDPSForRoshan({}) == false,
        'the empty party no longer answers false. Un-armed it is 0/0 = nan and '
        .. 'nan >= bar is false; armed it is 0 >= bar, also false. The two '
        .. 'legs agree here for DIFFERENT reasons, which is worth keeping '
        .. 'pinned: an armed leg that answered true on an empty party would be '
        .. 'a Roshan attempt with nobody in it.')
end

-- ==========================================================================
-- §5 REAL FRAMES. The divisor, measured; the inputs, declared absent.
-- ==========================================================================

local _frames
local function all_frames()
    if _frames then return _frames end
    local p = assert(io.popen('find tests/fixtures -name "f_*.lua" | sort'))
    local out = {}
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units and fx.self then
            out[#out + 1] = { path = path, fx = fx }
        end
    end
    p:close()
    _frames = out
    return out
end

--- ONE walk of the raw fixture tables. Reading them directly (not through
--- rf.load) is deliberate: the question is what the DUMPER emitted, and a mock
--- that synthesises a default would answer a different question.
local _sweep
local function corpus_sweep()
    if _sweep then return _sweep end
    local s = {
        nFrames = 0, nHeroes = 0,
        nDpsFields = 0,        -- attack damage / speed / armor: expected 0
        nHpFields = 0,         -- reverse call: a field that IS there
        nAliveSum = 0, nAliveFrames = 0, nMaxAlive = 0,
        nFramesAliveGe3 = 0,   -- the gated re-check's party floor
    }
    for _, f in ipairs(all_frames()) do
        s.nFrames = s.nFrames + 1
        local sSelfTeam
        for _, u in ipairs(f.fx.units) do
            if type(u) == 'table' and u.name == f.fx.self then
                sSelfTeam = u.team
            end
        end
        local nAlive = 0
        for _, u in ipairs(f.fx.units) do
            if type(u) == 'table' and u.name then
                s.nHeroes = s.nHeroes + 1
                for k in pairs(u) do
                    local sK = tostring(k)
                    if sK:find('attack') or sK:find('armor') or sK == 'dps' then
                        s.nDpsFields = s.nDpsFields + 1
                    end
                    if sK == 'max_hp' then s.nHpFields = s.nHpFields + 1 end
                end
                if u.team == sSelfTeam and u.alive then nAlive = nAlive + 1 end
            end
        end
        if sSelfTeam ~= nil then
            s.nAliveFrames = s.nAliveFrames + 1
            s.nAliveSum = s.nAliveSum + nAlive
            if nAlive > s.nMaxAlive then s.nMaxAlive = nAlive end
            if nAlive >= 3 then s.nFramesAliveGe3 = s.nFramesAliveGe3 + 1 end
        end
    end
    _sweep = s
    return s
end

tests['[world W1] ⛔ neither dps input is in the dump -- REVERSE-CALLED']
= function()
    local s = corpus_sweep()
    assert(s.nHeroes > 500, 'only ' .. s.nHeroes .. ' dumped hero slots; this '
        .. 'scan is too small to call anything absent')
    -- The reverse call FIRST: a scanner that finds nothing may be broken.
    assert(s.nHpFields > 0, 'the same scanner cannot find max_hp either, so '
        .. 'its zero below means "scanner broken", not "field absent". Fix the '
        .. 'scanner before reading anything into W1.')
    assert(s.nHpFields == s.nHeroes, 'max_hp is on ' .. s.nHpFields .. ' of '
        .. s.nHeroes .. ' hero slots, not all of them -- the reverse call no '
        .. 'longer anchors on a universal field.')
    assert(s.nDpsFields == 0, 'the dumper now emits an attack-damage, '
        .. 'attack-speed or armor field (' .. s.nDpsFields .. ' hits). That is '
        .. 'GOOD NEWS and this assertion is how you hear it: the predicate can '
        .. 'now be evaluated on a real frame, so replace §4\'s declared grid '
        .. 'with a frame reading and re-price this lever on the corpus.')
end

tests['[world W2] ⭐ the divisor, priced on real frames']
= function()
    local s = corpus_sweep()
    assert(s.nAliveFrames > 50, 'only ' .. s.nAliveFrames .. ' frames resolved '
        .. 'a subject team')
    -- The call site's list is every ALIVE allied hero, so this IS the factor by
    -- which the shipped line overstates the bar.
    local fMean = s.nAliveSum / s.nAliveFrames
    assert(fMean > 1.0, 'the mean alive-ally count is ' .. fMean .. '. At 1 the '
        .. 'shipped division would be a no-op and this lever a CONSTRUCTIVE '
        .. 'zero -- say so in the report instead of quoting §4.')
    assert(s.nMaxAlive >= 4, 'the corpus never shows 4+ allies alive at once '
        .. '(max ' .. s.nMaxAlive .. '), so the 4-5x overstatement quoted in '
        .. 'the header is not visible here; re-price before repeating it.')
    -- ⛔ The upper pin is what makes this number THE DIVISOR rather than some
    -- other count. A sweep that lost the team or the alive filter reads 10 on
    -- every frame and every assertion above still passes -- measured: that
    -- mutant SURVIVED the first version of this file.
    assert(s.nMaxAlive <= 5, 'the sweep reports ' .. s.nMaxAlive .. ' allies '
        .. 'alive at once. A party has five. This sweep is counting something '
        .. 'that is not "the subject\'s living allies", so it is not the '
        .. 'divisor and the factor quoted in the header is not measured.')
    assert(s.nAliveSum < 5 * s.nAliveFrames, 'every frame reports a FULL party '
        .. 'alive, so the sweep is not varying with the corpus at all -- the '
        .. 'shape a constant (a lost alive filter) produces.')
    assert(s.nFramesAliveGe3 > 0, 'no frame has the 3 alive allies that '
        .. ROSH .. ':167 requires, so the gated re-check\'s own floor is '
        .. 'unmet everywhere in this corpus')
end

-- ==========================================================================
-- §6 THE GATE. Controls.
-- ==========================================================================

local function side_of()
    local _, bot = rf.load(FRAME, SUBJ)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

tests['[control] un-armed the gate is shut'] = function()
    local J = rf.load(FRAME, SUBJ)
    assert(J.IsSoakCandidate(CAND) == false,
        'the gate is open with nothing armed')
end

tests['[control] armed on the other side the gate stays shut'] = function()
    local sOther = side_of() == 'radiant' and 'dire' or 'radiant'
    ss.with_candidate(CAND, function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate(CAND) == false,
            'the gate fired for a bot on the other side')
        assert(J.ShouldRateRoshanDpsAsTeamSum() == false,
            'the helper fired for a bot on the other side')
    end, sOther)
end

tests['[control] armed under another id the gate stays shut'] = function()
    ss.with_candidate('siegecap', function()
        local J = rf.load(FRAME, SUBJ)
        assert(J.IsSoakCandidate(CAND) == false,
            'the gate fired under a different candidate id')
        assert(J.ShouldRateRoshanDpsAsTeamSum() == false,
            'the helper fired under a different candidate id')
    end, side_of())
end

return tests

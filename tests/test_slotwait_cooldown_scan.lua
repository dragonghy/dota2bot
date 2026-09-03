-- Soak candidate 'slotwait' -- bots/FunLib/utils.lua,
-- HasTeamMemberWithCriticalItemInCooldown / HasTeamMemberWithCriticalSpellInCooldown;
-- gate resolved in exactly one place, J.ShouldWaitForTeamCooldowns in
-- bots/FunLib/jmz_func.lua. GH #467.
--
-- Sixth and seventh of the pid-shaped GetTeamMember sites (after 'slotarb'
-- GH #406, 'slotdust' GH #411, 'slotpush' GH #415), and the last two LIVE
-- members of the eight-strong bots/FunLib/utils.lua cluster -- GH #467 censused
-- the other five as having no caller in bots/ at all. Same defect:
--
--   GetTeamPlayers(team)  hands back PLAYER IDS (0-4 radiant, 5-9 dire)
--   GetTeamMember(n)      takes a TEAM SLOT      (1..5)
--
-- TWO THINGS ARE DIFFERENT FROM 'slotpush', AND BOTH MAKE THIS PAIR THE EASIER
-- ONE TO REASON ABOUT.
--
--   1. NO GUARD/SUBJECT SPLIT. slotpush guards on IsHeroAlive(playerdId) and
--      then looks at GetTeamMember(playerdId) -- two different heroes. These
--      two guard on teamMember:IsAlive(), asked about the member the accessor
--      just handed back, so the guard and its subject agree in BOTH worlds.
--      What is left is pure under-scanning.
--   2. THE SIGN IS THE OPPOSITE ONE, and it is monotone. The loop can only turn
--      a member into TRUE, never into FALSE, so the shipped TRUE set is a
--      strict SUBSET of the armed TRUE set -- there is no `over` direction to
--      worry about. The sole consumer is
--      aba_push.ShouldWaitForImportantItemsSpells, where TRUE means "hold the
--      push, a teammate's key spell/item is still on cooldown". Under-scanning
--      can therefore only open a mid/late-game push EARLY, never late, and it
--      does so having never looked at 4 of 5 teammates on dire. slotpush's
--      callers use TRUE to SUPPRESS a distraction, so its under-scan peels bots
--      off a siege; this one commits them to one they are not ready for.
--      "Do not open high ground while your team's BKBs and ultimates are down"
--      is standard play, which is the (c) leg of the validation philosophy.
--
-- ⛔ WHAT THIS FILE CANNOT BUY, STATED UP FRONT (measured before the lever was
-- chosen, not after). On the UNTOUCHED corpus -- 109 loadable fixtures, 49 of
-- them carrying player_id, 223 alive member-frames -- BOTH predicates answer
-- FALSE on all 98 evaluations (49 fixtures x 2 functions), shipped and armed
-- alike: 0 TRUE, 0 flips. The decision is DOMAIN-EMPTY here, and for two
-- INDEPENDENT reasons that were measured separately rather than pooled into one
-- comfortable zero:
--
--   * ITEM leg -- a corpus fact. ImportantItems is two entries long
--     ({item_black_king_bar, item_refresher}) and 0 of the 223 alive
--     member-frames holds either. Nothing is broken; these frames simply have
--     no BKB on them.
--   * SPELL leg -- an INSTRUMENT fact, and the more dangerous of the two,
--     because it looks exactly like the first one from the outside. 181 of the
--     223 members ARE in the 88-hero ImportantSpells map and their real
--     ability levels and cooldowns ARE loaded from the frame (216 of 1050
--     ability handles carry cd > 0). The leg still cannot fire:
--     J.Utils.IsValidAbility ends in `not ability:IsActivated()`, IsActivated
--     is on no spec in tests/mock/bot_api.lua, and the generic `^Is` default
--     there answers FALSE -- so IsValidAbility is structurally false for EVERY
--     ability on EVERY fixture frame. Measured: of the 181, 149 die at
--     IsActivated and 32 at IsTrained; 0 survive. This is a KNOWN loader gap,
--     already named by tests/test_lf_rescue_final_action.lua:57 ("clauses the
--     loader never wires (IsTrained/IsActivated)") and worked around per-unit
--     by test_itemdesire_world_assertion.lua and test_lf_salve_cast_type.lua.
--     Same family as the GetManaCost and GetActualIncomingDamage zeros already
--     documented in mock/replay_fixture.lua: a silent default is not a small
--     number, it is a DIFFERENT PREDICATE.
--
-- So the corpus-wide "0 TRUE" is NOT evidence that the shipped decision is
-- fine. It is one corpus fact and one blind instrument wearing the same face.
-- This file therefore buys the SCAN and the ARGUMENTS on real frames
-- unconditionally, and buys the DECISION under a clearly-labelled
-- counterfactual that restores the two clauses the loader never wires -- the
-- established pattern, not a new liberty. Condition (a) -- "it really fires in
-- a real game" -- remains the replay group's to buy, and GH #467 §验收 already
-- names the detector for it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- Dire: shipped step 1 (player id 5) is the only one in slot range, and it
-- lands on SLOT 5 -- so the scan looks at exactly one member and it is not the
-- one step 1 is nominally about.
local DIRE_FX = 'tests/fixtures/f_260819_182855_lion_drain_jungle.lua'
-- Radiant: player id 0 reads nil, ids 1..4 read slots 1..4, and slot 5 is never
-- asked for at all.
local RAD_FX  = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'

local tests = {}

local function short(u)
    if u == nil then return 'NIL' end
    return (u:GetUnitName():gsub('npc_dota_hero_', ''))
end

local function paths()
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local out = {}
    for path in p:lines() do out[#out + 1] = path end
    p:close()
    return out
end

-- The scan the shipped loop performs (by player id) and the one armed performs
-- (by team slot), read off whatever world is currently loaded. Pure frame data.
local function scans()
    local byId, bySlot = {}, {}
    for i, id in ipairs(GetTeamPlayers(GetTeam())) do
        byId[i] = GetTeamMember(id)
        bySlot[i] = GetTeamMember(i)
    end
    return byId, bySlot
end

local function count(t)
    local n = 0
    for _, v in pairs(t) do if v ~= nil then n = n + 1 end end
    return n
end

-- DECLARED HARNESS INPUT, used only by the tests with "counterfactual" in their
-- name. Restores the two clauses tests/mock/bot_api.lua never wires
-- (IsTrained / IsActivated) on ONE named ability of ONE named member, and puts
-- a cooldown on it that outlasts that member's own walk to the target. Every
-- other ability on the frame is left exactly as the loader built it, so the
-- only member that can answer TRUE is the one this function names.
local function arm_critical_spell(J, member, targetLoc, nCd)
    local sSpell = J.Utils.ImportantSpells[member:GetUnitName()]
    assert(sSpell ~= nil, short(member) .. ' is not in ImportantSpells -- ' ..
        'pick a member the predicate can even ask about')
    local ab = member:GetAbilityByName(sSpell[1])
    local sp = rawget(ab, '__spec')
    sp.IsTrained = true
    sp.IsActivated = true
    sp.IsHidden = false
    sp.IsNull = false
    sp.GetCooldownTimeRemaining = nCd
    local dur = GetUnitToLocationDistance(member, targetLoc) / member:GetCurrentMovementSpeed()
    assert(nCd > dur, string.format(
        'the counterfactual must outlast the walk: cd %.1fs vs %.1fs for %s',
        nCd, dur, short(member)))
    assert(J.Utils.HasCriticalSpellWithCooldown(member, dur) == true,
        'the counterfactual did not take on ' .. short(member) ..
        ' -- IsValidAbility still refuses, so nothing below means what it says')
    return sSpell[1]
end

-- Same idea for the item leg: one member, one BKB, one cooldown. GetItem scans
-- GetItemInSlot 0..5, which the mock answers nil for by default.
local function arm_critical_item(J, member, targetLoc, nCd)
    local api = require('mock.bot_api')
    local item = api.MakeAbility('item_black_king_bar',
        { GetCooldownTimeRemaining = nCd })
    local sp = rawget(member, '__spec')
    sp.GetItemInSlot = function(_, slot)
        if slot == 0 then return item end
        return nil
    end
    assert(J.Utils.GetItem(member, 'item_black_king_bar') ~= nil,
        'the counterfactual BKB is not reachable through GetItem on ' .. short(member))
    local dur = GetUnitToLocationDistance(member, targetLoc) / member:GetCurrentMovementSpeed()
    assert(nCd > dur, 'the counterfactual must outlast the walk')
end

--============================================================================
-- Ground truth on real frames. No counterfactual below this line until the
-- section that says so.
--============================================================================

tests['[frame F1] dire: the shipped scan reaches ONE member of five'] = function()
    local J, bot = rf.load(DIRE_FX)
    assert(GetTeam() == 3, 'F1 must be a dire frame; got team ' .. tostring(GetTeam()))
    local pids = GetTeamPlayers(GetTeam())
    assert(pids[1] == 5 and pids[5] == 9,
        'F1 player ids are not the dire 5..9 block: {' .. table.concat(pids, ',') .. '}')

    local byId, bySlot = scans()
    assert(count(bySlot) == 5, 'armed must reach the whole roster; reached ' .. count(bySlot))
    assert(count(byId) == 1, 'shipped must reach exactly one member on dire; reached ' .. count(byId))
    assert(byId[1] ~= nil and byId[2] == nil and byId[3] == nil
        and byId[4] == nil and byId[5] == nil,
        'the one member the shipped loop reaches must be the FIRST step (id 5 -> slot 5)')
    -- And the member it reaches is the LAST slot, not the first. The step is
    -- nominally about player id 5 (death_prophet, slot 1) and it hands back
    -- lion (slot 5, player id 9).
    assert(short(byId[1]) == 'lion' and short(bySlot[5]) == 'lion',
        'F1 roster drifted: shipped step 1 reads ' .. short(byId[1]) ..
        ', slot 5 holds ' .. short(bySlot[5]))
    assert(short(bySlot[1]) == 'death_prophet',
        'F1 slot 1 drifted: ' .. short(bySlot[1]))
    assert(short(bot) == 'lion', 'F1 subject drifted: ' .. short(bot))
end

tests['[frame F2] radiant: four of five, and slot 5 is never asked for'] = function()
    local J, bot = rf.load(RAD_FX)
    assert(GetTeam() == 2, 'F2 must be a radiant frame; got team ' .. tostring(GetTeam()))
    local pids = GetTeamPlayers(GetTeam())
    assert(pids[1] == 0 and pids[5] == 4,
        'F2 player ids are not the radiant 0..4 block: {' .. table.concat(pids, ',') .. '}')

    local byId, bySlot = scans()
    assert(count(bySlot) == 5, 'armed must reach the whole roster; reached ' .. count(bySlot))
    assert(count(byId) == 4, 'shipped must reach four members on radiant; reached ' .. count(byId))
    assert(byId[1] == nil, 'player id 0 is out of slot range and must read nil')
    assert(bySlot[5] ~= nil and byId[5] ~= bySlot[5],
        'slot 5 must exist and must NOT be what the shipped loop reads at step 5')
    assert(short(bySlot[5]) == 'silencer',
        'F2 slot 5 drifted: ' .. short(bySlot[5]) ..
        ' -- this is the member the shipped scan never looks at')
    assert(short(bot) == 'viper', 'F2 subject drifted: ' .. short(bot))
end

tests['[trace] the arguments the two predicates themselves pass to GetTeamMember'] = function()
    -- Every other reading here re-implements the scan beside the function and
    -- compares outcomes. On a corpus where the outcome never moves (see the
    -- domain block at the top) that would leave the functions' own indexing
    -- untested -- an armed leg that scanned slots 2..6 would pass every other
    -- test in this file. So instrument the accessor and read the arguments off
    -- the real call.
    --
    -- Both predicates answer FALSE on both fixtures (that is the domain price,
    -- and here it is a convenience: an early TRUE return would truncate the
    -- trace and a truncated trace cannot see the tail). There is no liveness
    -- guard on these loops, so the expected traces are the WHOLE id list and
    -- the whole 1..5 slot list -- no member is skipped before the accessor.
    local FNS = {
        'HasTeamMemberWithCriticalItemInCooldown',
        'HasTeamMemberWithCriticalSpellInCooldown',
    }
    for _, path in ipairs({ DIRE_FX, RAD_FX }) do
        for _, sFn in ipairs(FNS) do
            local wantShipped, wantArmed = {}, {}

            local J, bot = rf.load(path)
            local pids = GetTeamPlayers(GetTeam())
            for i, id in ipairs(pids) do
                wantShipped[#wantShipped + 1] = id
                wantArmed[#wantArmed + 1] = i
            end
            assert(#wantArmed == 5, path .. ': expected a five-member roster')

            local real = GetTeamMember
            local seen = {}
            GetTeamMember = function(n) seen[#seen + 1] = n; return real(n) end
            local ok, res = pcall(J.Utils[sFn], bot:GetLocation(), false)
            GetTeamMember = real
            assert(ok, path .. ' ' .. sFn .. ': shipped leg raised: ' .. tostring(res))
            assert(res == false, path .. ' ' .. sFn .. ': this frame must answer FALSE, ' ..
                'or the trace is truncated by the early return')
            assert(table.concat(seen, ',') == table.concat(wantShipped, ','),
                path .. ' ' .. sFn .. ': shipped asked GetTeamMember for {' ..
                table.concat(seen, ',') .. '}, expected the player ids {' ..
                table.concat(wantShipped, ',') .. '}')

            local J2, bot2 = rf.load(path)
            real = GetTeamMember
            seen = {}
            GetTeamMember = function(n) seen[#seen + 1] = n; return real(n) end
            local ok2, res2 = pcall(J2.Utils[sFn], bot2:GetLocation(), true)
            GetTeamMember = real
            assert(ok2, path .. ' ' .. sFn .. ': armed leg raised: ' .. tostring(res2))
            assert(table.concat(seen, ',') == table.concat(wantArmed, ','),
                path .. ' ' .. sFn .. ': armed asked GetTeamMember for {' ..
                table.concat(seen, ',') .. '}, expected the team slots {' ..
                table.concat(wantArmed, ',') .. '}')
        end
    end
end

tests['[corpus] every player_id fixture shows the shrink, by side'] = function()
    local nTotal, nPid, nDire, nRadiant, nScanOne, nScanFour = 0, 0, 0, 0, 0, 0
    for _, path in ipairs(paths()) do
        local ok = pcall(function()
            rf.load(path)
            nTotal = nTotal + 1
            local pids = GetTeamPlayers(GetTeam())
            -- The pre-player_id dumps hand back {1,2,3,4,5}, on which pid and
            -- slot coincide. Those fixtures CANNOT see this defect and must
            -- never be counted as evidence that it is absent.
            if #pids == 0 or pids[1] == 1 then return end
            nPid = nPid + 1
            local byId, bySlot = scans()
            local b, a = count(byId), count(bySlot)
            assert(a == 5, path .. ': armed must always reach five slots; reached ' .. a)
            assert(b < a, path .. ': the shipped scan is never as wide as the armed one')
            if GetTeam() == 3 then
                nDire = nDire + 1
                assert(b == 1, path .. ': dire shipped scan reached ' .. b .. ', expected 1')
                nScanOne = nScanOne + 1
            else
                nRadiant = nRadiant + 1
                assert(b == 4, path .. ': radiant shipped scan reached ' .. b .. ', expected 4')
                nScanFour = nScanFour + 1
            end
        end)
        assert(ok, 'fixture failed to load or violated the shrink: ' .. path)
    end
    -- Measured 2026-09-03: 109 loadable fixtures, 49 with player ids, 25 dire /
    -- 24 radiant, and the split is TOTAL -- every dire frame reaches exactly
    -- one member and every radiant frame exactly four. Floors, not equalities,
    -- so a growing corpus does not turn this red on its own.
    assert(nTotal >= 100, 'corpus shrank: ' .. nTotal .. ' loadable fixtures')
    assert(nPid >= 45, 'the player_id population collapsed: ' .. nPid)
    assert(nDire >= 20, 'the dire population collapsed: ' .. nDire)
    assert(nRadiant >= 20, 'the radiant population collapsed: ' .. nRadiant)
    assert(nScanOne == nDire and nScanFour == nRadiant,
        'the by-side shrink stopped being total: ' .. nScanOne .. '/' .. nDire ..
        ' dire, ' .. nScanFour .. '/' .. nRadiant .. ' radiant')
end

tests['[domain price] on the untouched corpus neither predicate ever fires'] = function()
    -- Pinned as a PREMISE so the next agent re-measures instead of re-deriving,
    -- and so the day it stops being true somebody is told. Both legs, both
    -- directions, every player_id fixture.
    local nEval, nShipped, nArmed, nFlip = 0, 0, 0, 0
    local nMembers, nWithItem, nValidSpell, nInSpellMap = 0, 0, 0, 0
    for _, path in ipairs(paths()) do
        pcall(function()
            local J, bot = rf.load(path)
            local pids = GetTeamPlayers(GetTeam())
            if #pids == 0 or pids[1] == 1 then return end
            local loc = bot:GetLocation()
            for _, sFn in ipairs({ 'HasTeamMemberWithCriticalItemInCooldown',
                                   'HasTeamMemberWithCriticalSpellInCooldown' }) do
                local s, a = J.Utils[sFn](loc, false), J.Utils[sFn](loc, true)
                nEval = nEval + 1
                if s then nShipped = nShipped + 1 end
                if a then nArmed = nArmed + 1 end
                if s ~= a then nFlip = nFlip + 1 end
            end
            for i = 1, #pids do
                local m = GetTeamMember(i)
                if m ~= nil and m:IsAlive() then
                    nMembers = nMembers + 1
                    for _, sItem in ipairs(J.Utils.ImportantItems) do
                        if J.Utils.GetItem(m, sItem) then nWithItem = nWithItem + 1 end
                    end
                    local spells = J.Utils.ImportantSpells[m:GetUnitName()]
                    if spells ~= nil then
                        nInSpellMap = nInSpellMap + 1
                        if J.Utils.IsValidAbility(m:GetAbilityByName(spells[1])) then
                            nValidSpell = nValidSpell + 1
                        end
                    end
                end
            end
        end)
    end
    assert(nEval >= 90, 'the evaluation population collapsed: ' .. nEval)
    assert(nShipped == 0 and nArmed == 0 and nFlip == 0,
        'the corpus stopped being domain-empty (' .. nShipped .. ' shipped TRUE, ' ..
        nArmed .. ' armed TRUE, ' .. nFlip .. ' flips over ' .. nEval ..
        ' evaluations) -- GOOD NEWS: re-read the domain block at the top of ' ..
        'this file, the decision is now buyable on real frames and the ' ..
        'counterfactual below can be replaced by the frames themselves')
    -- The two reasons, separately, so a fix to one is never read as a fix to both.
    assert(nMembers >= 200, 'the member-frame population collapsed: ' .. nMembers)
    assert(nWithItem == 0, 'a member now holds an ImportantItem (' .. nWithItem ..
        ' of ' .. nMembers .. ') -- the ITEM leg is no longer domain-empty')
    assert(nInSpellMap >= 150, 'the ImportantSpells population collapsed: ' .. nInSpellMap)
    assert(nValidSpell == 0, 'IsValidAbility now answers TRUE somewhere (' .. nValidSpell ..
        ' of ' .. nInSpellMap .. ') -- the loader grew IsActivated/IsTrained, so ' ..
        'the SPELL leg blindness documented at the top of this file is closed')
end

--============================================================================
-- COUNTERFACTUAL. Everything below restores clauses the loader never wires;
-- see arm_critical_spell / arm_critical_item.
--============================================================================

tests['[counterfactual C1] dire: the member shipped never looks at is invisible to it'] = function()
    -- lich sits in slot 3. On dire the shipped scan asks GetTeamMember for
    -- {5,6,7,8,9} and gets back exactly one member -- lion, in slot 5. lich is
    -- 3.3s of walking from the target with a chain frost that will not be back
    -- for 99s, and the shipped predicate never asks.
    local J, bot = rf.load(DIRE_FX)
    local loc = bot:GetLocation()
    local lich = GetTeamMember(3)
    assert(short(lich) == 'lich', 'C1 anchor drifted: slot 3 holds ' .. short(lich))
    arm_critical_spell(J, lich, loc, 99)

    assert(J.Utils.HasTeamMemberWithCriticalSpellInCooldown(loc, false) == false,
        'shipped must not see a member it never asks the engine for')
    assert(J.Utils.HasTeamMemberWithCriticalSpellInCooldown(loc, true) == true,
        'armed must see the slot-3 member')
end

tests['[counterfactual C2] the shipped leg is not simply always-false'] = function()
    -- The control for C1, and the reason C1 means anything: put the same
    -- cooldown on lion -- slot 5, the ONE member the dire shipped scan does
    -- reach -- and the shipped leg answers TRUE. So its FALSE in C1 is a
    -- statement about WHO it looked at, not about a dead instrument.
    local J, bot = rf.load(DIRE_FX)
    local loc = bot:GetLocation()
    local lion = GetTeamMember(5)
    assert(short(lion) == 'lion', 'C2 anchor drifted: slot 5 holds ' .. short(lion))
    arm_critical_spell(J, lion, loc, 99)

    assert(J.Utils.HasTeamMemberWithCriticalSpellInCooldown(loc, false) == true,
        'shipped must see slot 5 on dire -- it is the one member it reaches')
    assert(J.Utils.HasTeamMemberWithCriticalSpellInCooldown(loc, true) == true,
        'armed must see it too; the fix only ever ADDS members')
end

tests['[counterfactual C3] radiant: slot 5 is the blind spot, and the item leg has it too'] = function()
    -- Radiant's shipped scan reads slots 1..4, so the missing member is always
    -- slot 5 -- here silencer, 26.1s out with a BKB on a 99s cooldown. Run on
    -- the ITEM leg so both functions are bought, not just the spell one.
    local J, bot = rf.load(RAD_FX)
    local loc = bot:GetLocation()
    local silencer = GetTeamMember(5)
    assert(short(silencer) == 'silencer', 'C3 anchor drifted: slot 5 holds ' .. short(silencer))
    arm_critical_item(J, silencer, loc, 99)

    assert(J.Utils.HasTeamMemberWithCriticalItemInCooldown(loc, false) == false,
        'shipped must not see slot 5 on radiant -- it never asks for it')
    assert(J.Utils.HasTeamMemberWithCriticalItemInCooldown(loc, true) == true,
        'armed must see the slot-5 member')
end

tests['[counterfactual C4] the wrapper carries both legs through the gate'] = function()
    -- C1/C3 drive the utils predicates directly. This one drives the shipped
    -- consumer path -- J.ShouldWaitForTeamCooldowns -- so the wrapper's own
    -- threading is measured, not assumed. The gate is turbo-only, and
    -- IsModeTurbo/IsSoakCandidate are what the soak file answers, so this test
    -- pins the wrapper's TWO delegations rather than the arming (the arming is
    -- pinned by structure below).
    local J, bot = rf.load(DIRE_FX)
    local loc = bot:GetLocation()
    arm_critical_spell(J, GetTeamMember(3), loc, 99)
    assert(J.Utils.HasTeamMemberWithCriticalItemInCooldown(loc, true) == false,
        'C4 wants the SPELL leg to be the only one that can fire')
    assert(J.Utils.HasTeamMemberWithCriticalSpellInCooldown(loc, true) == true,
        'C4 setup failed')
    -- Whatever the soak file and the game mode say, the wrapper must equal the
    -- disjunction of the two legs at the arming those two answers imply. That
    -- is the whole contract, and it holds in every one of the four worlds
    -- (turbo/not x armed/not) without this test having to fake either one.
    local bTurbo = J.IsModeTurbo()
    local bArmed = bTurbo and J.IsSoakCandidate('slotwait')
    local expected = J.Utils.HasTeamMemberWithCriticalItemInCooldown(loc, bArmed)
        or J.Utils.HasTeamMemberWithCriticalSpellInCooldown(loc, bArmed)
    assert(J.ShouldWaitForTeamCooldowns(loc) == expected,
        'the wrapper disagrees with the two legs it is supposed to be')
end

--============================================================================
-- Structure: one id, one place, one shape, in both source trees.
--============================================================================

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

tests['[structure] the wrapper owns the slotwait gate, turbo-first, read ONCE'] = function()
    local code = strip_comments(read('bots/FunLib/jmz_func.lua'))
    local fn = code:match('function J%.ShouldWaitForTeamCooldowns%s*%b()(.-)\nend')
    assert(fn, 'the J.ShouldWaitForTeamCooldowns wrapper is gone or reshaped')
    local iCand = fn:find("J%.IsSoakCandidate%s*%(%s*'slotwait'%s*%)")
    assert(iCand, "the fix must be gated on 'slotwait'; got: " .. fn)
    local iTurbo = fn:find('J%.IsModeTurbo%s*%(%s*%)')
    assert(iTurbo, 'the fix must be turbo-only; got: ' .. fn)
    assert(iTurbo < iCand, 'IsModeTurbo() must be evaluated before the slotwait check')
    -- The whole point of ONE wrapper for TWO functions: the id is read once and
    -- threaded into both legs, so 'slotwait' can never be half-armed.
    local _, nReads = fn:gsub("J%.IsSoakCandidate%s*%(%s*'slotwait'%s*%)", '')
    assert(nReads == 1, 'the gate must be read exactly once and threaded into both ' ..
        'legs; found ' .. nReads .. ' reads')
    assert(fn:find('J%.Utils%.HasTeamMemberWithCriticalItemInCooldown%s*%('),
        'the wrapper must delegate to the utils item predicate')
    assert(fn:find('J%.Utils%.HasTeamMemberWithCriticalSpellInCooldown%s*%('),
        'the wrapper must delegate to the utils spell predicate')
    -- Order matters: the shipped consumer tested item first, then spell, and
    -- both legs can have side-effect-free but not cost-free scans.
    assert(fn:find('Item.-Spell'), 'the wrapper must keep the shipped order: item, then spell')
end

tests['[structure] utils does not name the id; it only takes the flag'] = function()
    local code = strip_comments(read('bots/FunLib/utils.lua'))
    assert(not code:find('slotwait'), "'slotwait' must be resolved in jmz_func.lua, " ..
        'never read inside utils.lua -- utils may not import jmz_func at all')
    for _, sFn in ipairs({ 'HasTeamMemberWithCriticalItemInCooldown',
                           'HasTeamMemberWithCriticalSpellInCooldown' }) do
        local fn = code:match('function ____exports%.' .. sFn .. '.-\nend\n')
        assert(fn, sFn .. ' is gone or reshaped')
        assert(fn:find('bSlotWait'), sFn .. ' lost the gate parameter')
        assert(fn:find('GetTeamMember%s*%(%s*nSlot%s*%)'),
            sFn .. ': the fix must be the ARGUMENT, not a new clause around the call')
        assert(fn:find('nSlot%s*=%s*playerId'), sFn .. ': unarmed must still pass the player id')
        assert(fn:find('nSlot%s*=%s*i%s'), sFn .. ': armed must pass the loop index')
    end
end

tests['[structure] the two predicates are named exactly once outside utils'] = function()
    -- Both halves of the "one place to arm" claim, by census: neither utils
    -- predicate is called anywhere but the wrapper, and the consumer calls the
    -- wrapper. A second call site would be a second, ungated scan.
    local p = assert(io.popen(
        "grep -rn 'HasTeamMemberWithCriticalItemInCooldown\\|" ..
        "HasTeamMemberWithCriticalSpellInCooldown\\|ShouldWaitForTeamCooldowns' " ..
        "bots/ --include='*.lua'"))
    local nDirect, nWrapper, nWrapped, direct = 0, 0, 0, {}
    for line in p:lines() do
        local path, num, text = line:match('^([^:]+):(%d+):(.*)$')
        if path and not text:match('^%s*%-%-') and path ~= 'bots/FunLib/utils.lua' then
            if text:match('^function J%.ShouldWaitForTeamCooldowns') then
                nWrapper = nWrapper + 1
            elseif text:find('J%.Utils%.HasTeamMemberWithCritical') then
                nDirect = nDirect + 1
                direct[#direct + 1] = path .. ':' .. num
            elseif text:find('jmz%.Utils%.HasTeamMemberWithCritical') then
                nDirect = nDirect + 1
                direct[#direct + 1] = path .. ':' .. num
            elseif text:find('ShouldWaitForTeamCooldowns%s*%(') then
                nWrapped = nWrapped + 1
            end
        end
    end
    p:close()
    assert(nWrapper == 1, 'expected exactly one wrapper definition, found ' .. nWrapper)
    -- Two names, both delegated from inside the wrapper body, and nothing else.
    assert(nDirect == 2, 'the utils predicates must be named exactly twice outside ' ..
        'utils.lua (both inside the wrapper); found ' .. nDirect ..
        (#direct > 0 and (':\n  ' .. table.concat(direct, '\n  ')) or ''))
    assert(nWrapped == 1, 'expected exactly one consumer call site on the wrapper ' ..
        '(aba_push.ShouldWaitForImportantItemsSpells), found ' .. nWrapped)
end

tests['[structure] the consumer kept its order and its short circuit'] = function()
    local code = strip_comments(read('bots/FunLib/aba_push.lua'))
    local fn = code:match('function ____exports%.ShouldWaitForImportantItemsSpells.-\nend\n')
    assert(fn, 'ShouldWaitForImportantItemsSpells is gone or reshaped')
    assert(fn:find('jmz%.ShouldWaitForTeamCooldowns%s*%(%s*vLocation%s*%)'),
        'the consumer must go through the wrapper')
    assert(not fn:find('HasTeamMemberWithCritical'),
        'the consumer must not call the ungated predicates directly any more')
    assert(fn:find('isMidGame') and fn:find('isLateGame'),
        'the mid/late-game guard must survive -- the gate must not widen the domain')
end

tests['[ts parity] the TypeScript source carries the same argument fix'] = function()
    local ts = read('typescript/bots/FunLib/utils.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    for _, sFn in ipairs({ 'HasTeamMemberWithCriticalItemInCooldown',
                           'HasTeamMemberWithCriticalSpellInCooldown' }) do
        local fn = ts:match('export function ' .. sFn .. '.-\n}')
        assert(fn, 'the TS predicate ' .. sFn .. ' is gone or reshaped')
        assert(fn:find('bSlotWait%?: boolean'), sFn .. ': the TS predicate lost the gate parameter')
        assert(fn:find('GetTeamMember%(bSlotWait %? i : playerId%)'),
            sFn .. ': the TS argument drifted from the Lua one')
    end
    local push = read('typescript/bots/FunLib/aba_push.ts')
    push = push:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    assert(push:find('jmz%.ShouldWaitForTeamCooldowns%(vLocation%)'),
        'the TS consumer still calls the ungated predicates')
end

tests['[instrument] the two mock blind spots this file leans on'] = function()
    -- Both are declared at the top; assert them so the day the loader closes
    -- either one, this file says so instead of quietly meaning something else.
    local mock = require('mock.bot_api')
    mock.install({ bot = mock.MakeHero('npc_dota_hero_axe'), team = 3 })
    -- The BARE mock answers GetTeamMember for any index, so on that instrument
    -- the shrink is invisible and every frame reading above would be vacuous.
    -- Only the fixture loader lays down a real five-slot roster, which is why
    -- every reading in this file goes through rf.load and never through a bare
    -- install. (This is the same declaration test_slotpush_highground_scan.lua
    -- makes; if it ever fails, the mock grew a roster -- drop the declaration
    -- and say so in the report.)
    assert(GetTeamMember(9) ~= nil,
        'the bot_api mock now refuses an out-of-range slot -- the blind spot is closed')
    local ab = mock.MakeAbility('some_ability')
    assert(ab:IsActivated() == false,
        'the mock now specs IsActivated -- the SPELL-leg blindness is closed and the ' ..
        'domain-price block at the top of this file is out of date')
end

return tests

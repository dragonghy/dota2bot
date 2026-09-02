-- Soak candidate 'slotpush' -- bots/FunLib/utils.lua,
-- IsTeamPushingSecondTierOrHighGround; gate resolved in exactly one place,
-- J.IsTeamPushingHighGround in bots/FunLib/jmz_func.lua.
--
-- Third of the pid-shaped GetTeamMember sites (after 'slotarb' GH #406 and
-- 'slotdust' GH #411) and the first of the eight-strong bots/FunLib/utils.lua
-- cluster. Same defect, one file over:
--
--   GetTeamPlayers(team)  hands back PLAYER IDS (0-4 radiant, 5-9 dire)
--   GetTeamMember(n)      takes a TEAM SLOT      (1..5)
--
-- docs/BOT_API_REFERENCE.md:223 says 1..5 and "nil if the player slot doesn't
-- exist". Feeding one to the other does not raise: it silently shrinks the
-- scanned roster, side-dependently, AND -- new here, because this loop has a
-- guard the other two did not -- it splits the guard from its subject:
-- IsHeroAlive(playerdId) is asked about one hero while GetTeamMember(playerdId)
-- hands back another.
--
-- WHY THIS ONE IS A STRATEGY LEVER: all seven call sites are mode-desire
-- scripts (ward / rune / outpost / side shop / secret shop / roshan / laning)
-- and every one of them uses TRUE to return BOT_MODE_DESIRE_NONE. Seeing fewer
-- teammates can only make "the team is pushing" HARDER to believe, so the
-- shipped failure direction is CLOSED: bots peel off a high-ground siege to go
-- shopping / warding / rune-hunting. That is standard-strategy wrong (you do
-- not split five during a high-ground siege) and it is the (c) leg of the
-- team's validation philosophy.
--
-- ⛔ WHAT THIS FILE CANNOT BUY, STATED UP FRONT (the 0CORP domain price, run
-- BEFORE the lever was chosen rather than after):
--   * 517 member-frames over 107 fixtures. Every conjunct of the predicate
--     fires somewhere -- crowd>=2 on 51, near enemy T2 on 10, near enemy high
--     ground on 5, within 3000 of the enemy ancient on 38 -- so the instrument
--     is NOT blind. But both halves are true together on only FOUR
--     member-frames, and all four are the same fixture
--     (f_260820_163429_es_blink_init_621, dire).
--   * On that one frame the shipped scan sees exactly one of those four
--     pushers -- and that one (jakiro, slot 5) is itself a pusher, so shipped
--     answers TRUE for a reason it did not earn. Over the whole corpus, both
--     sides of every fixture, the two legs NEVER disagree: 0 flips in 94
--     subject-loads. [domain price] pins that as a premise so the next agent
--     re-measures instead of re-deriving.
--   * Therefore this file buys the SCAN and the DIRECTION on real frames, and
--     buys the DECISION only under a clearly-labelled counterfactual. Condition
--     (a) -- "it really fires in a real game" -- is the replay group's to buy.
--
-- The two other live pid-shaped functions in the same cluster were measured the
-- same way before this one was picked, and are worse: aba_push.lua:584/587 call
-- HasTeamMemberWithCriticalItemInCooldown / ...SpellInCooldown, and over the
-- same 107 fixtures neither answers TRUE even once (0 anyTrue, 0 flips). Four
-- more of the eight have NO caller in bots/ at all.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SIEGE_FX = 'tests/fixtures/f_260820_163429_es_blink_init_621.lua'
local DIRE_FX  = 'tests/fixtures/f_260819_182855_lion_drain_jungle.lua'
local RAD_FX   = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'

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

-- DECLARED HARNESS INPUT, and the one this whole file leans on: the bot API
-- mock answers IsHeroAlive(id) with a constant true for every id (see
-- [instrument] at the bottom), so the guard/subject split is invisible on the
-- bare instrument. The dumps DO carry per-hero alive flags keyed by player id,
-- so this is a RESTORATION of frame ground truth, not a model. `sDead` flips
-- exactly one hero's bit, and is used only by the test that says
-- "counterfactual" in its name.
local function frame_liveness(fx, sDead)
    local alive, nKilled = {}, 0
    for _, u in ipairs(fx.units) do
        if u.player_id ~= nil then
            local bDead = sDead ~= nil and u.name:gsub('npc_dota_hero_', '') == sDead
            if bDead then nKilled = nKilled + 1 end
            alive[u.player_id] = (u.alive and not bDead) and true or false
        end
    end
    -- A counterfactual that silently killed nobody would leave every assertion
    -- below reading the untouched frame and passing for the wrong reason. The
    -- first draft of this helper did exactly that: fixture names carry the
    -- npc_dota_hero_ prefix and the short name never matched.
    assert(sDead == nil or nKilled == 1,
        'the counterfactual named a hero that is not on this frame: ' .. tostring(sDead))
    IsHeroAlive = function(id) return alive[id] == true end
    return alive
end

-- The scan the shipped loop performs (by id) and the one armed performs (by
-- slot), read off whatever world is currently loaded. Pure frame data.
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

--============================================================================
-- Ground truth on real frames.
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
    assert(short(bot) == 'lion', 'F1 subject drifted: ' .. short(bot))
end

tests['[frame F2] radiant: four of five, and no step names its own hero'] = function()
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
    assert(short(bot) == 'viper', 'F2 subject drifted: ' .. short(bot))
end

tests['[guard] armed pairs each guard with its own subject; shipped does not'] = function()
    -- The half of this defect that 'slotarb' and 'slotdust' did not have: this
    -- loop asks IsHeroAlive(playerdId) and then looks at GetTeamMember(...).
    -- Armed those are one hero by construction (step i <-> player id list[i]
    -- <-> team slot i); shipped they are two.
    local nChecked, nMisguarded = 0, 0
    for _, path in ipairs(paths()) do
        local J, bot, heroes, fx = rf.load(path)
        local pids = GetTeamPlayers(GetTeam())
        if #pids > 0 and pids[1] ~= 1 then      -- skip the pre-player_id dumps
            for i, id in ipairs(pids) do
                nChecked = nChecked + 1
                local armedSubject = GetTeamMember(i)
                assert(armedSubject ~= nil, path .. ': slot ' .. i .. ' is missing')
                assert(armedSubject:GetPlayerID() == id, path .. ': armed step ' .. i ..
                    ' guards player ' .. id .. ' but looks at player ' ..
                    tostring(armedSubject:GetPlayerID()) ..
                    ' -- the whole fix rests on these being the same hero')
                local shippedSubject = GetTeamMember(id)
                if shippedSubject == nil or shippedSubject:GetPlayerID() ~= id then
                    nMisguarded = nMisguarded + 1
                end
            end
        end
    end
    -- Measured 2026-09-02: 47 player_id fixtures x 5 steps = 235 checked, and
    -- the shipped pairing is wrong on 211 of them (only step 1 on dire, and the
    -- degenerate radiant coincidences, line up). Floors, not equalities.
    assert(nChecked >= 200, 'the battery shrank: ' .. nChecked)
    assert(nMisguarded >= 180, 'the shipped mispairing collapsed: ' .. nMisguarded)
end

tests['[trace] the arguments the predicate itself passes to GetTeamMember'] = function()
    -- Every other reading here re-implements the scan beside the function and
    -- compares outcomes. On a corpus where the outcome barely moves (see
    -- [domain price]) that leaves the function's own indexing untested: a
    -- mutant that armed to `i + 1` -- scanning slots 2..6, one real member
    -- missed and one nil read -- survived the whole file until this test
    -- existed, because on the one siege frame it still found a pusher.
    -- So instrument the accessor and read the arguments off the real call.
    --
    -- Both fixtures are chosen so the predicate answers FALSE: an early TRUE
    -- return truncates the trace and a truncated trace cannot see the tail.
    for _, path in ipairs({ DIRE_FX, RAD_FX }) do
        local J, bot, heroes, fx = rf.load(path)
        frame_liveness(fx)
        local pids = GetTeamPlayers(GetTeam())
        local wantShipped, wantArmed = {}, {}
        for i, id in ipairs(pids) do
            if IsHeroAlive(id) then
                wantShipped[#wantShipped + 1] = id
                wantArmed[#wantArmed + 1] = i
            end
        end
        assert(#wantArmed >= 2, path .. ': too few live members to trace')

        local real = GetTeamMember
        local seen = {}
        GetTeamMember = function(n) seen[#seen + 1] = n; return real(n) end
        local ok, res = pcall(J.Utils.IsTeamPushingSecondTierOrHighGround, bot, false)
        GetTeamMember = real
        assert(ok, path .. ': shipped leg raised: ' .. tostring(res))
        assert(res == false, path .. ': pick a frame the predicate answers FALSE on, ' ..
            'or the trace is truncated by the early return')
        assert(table.concat(seen, ',') == table.concat(wantShipped, ','),
            path .. ': shipped asked GetTeamMember for {' .. table.concat(seen, ',') ..
            '}, expected the live player ids {' .. table.concat(wantShipped, ',') .. '}')

        local J2, bot2, _, fx2 = rf.load(path)
        frame_liveness(fx2)
        real = GetTeamMember
        seen = {}
        GetTeamMember = function(n) seen[#seen + 1] = n; return real(n) end
        local ok2, res2 = pcall(J2.Utils.IsTeamPushingSecondTierOrHighGround, bot2, true)
        GetTeamMember = real
        assert(ok2, path .. ': armed leg raised: ' .. tostring(res2))
        assert(table.concat(seen, ',') == table.concat(wantArmed, ','),
            path .. ': armed asked GetTeamMember for {' .. table.concat(seen, ',') ..
            '}, expected the live team slots {' .. table.concat(wantArmed, ',') .. '}')
    end
end

tests['[corpus] every player_id fixture shows the shrink, by side'] = function()
    local nTotal, nDire, nRadiant, nDegenerate, nScanOne = 0, 0, 0, 0, 0
    for _, path in ipairs(paths()) do
        local ok = pcall(function()
            rf.load(path)
            local pids = GetTeamPlayers(GetTeam())
            if #pids == 0 then return end
            nTotal = nTotal + 1
            local byId, bySlot = scans()
            local b, a = count(byId), count(bySlot)
            if b == a then
                nDegenerate = nDegenerate + 1
            else
                assert(b < a, path .. ': the shipped scan is never WIDER than the armed one')
                if b == 1 then nScanOne = nScanOne + 1 end
                if GetTeam() == 3 then nDire = nDire + 1 else nRadiant = nRadiant + 1 end
            end
        end)
        assert(ok, 'fixture failed to load: ' .. path)
    end
    assert(nTotal >= 100, 'corpus shrank: ' .. nTotal .. ' loadable fixtures')
    assert(nDire >= 20, 'the dire population collapsed: ' .. nDire)
    assert(nRadiant >= 20, 'the radiant population collapsed: ' .. nRadiant)
    assert(nScanOne >= 20, 'the "reaches exactly one member" population collapsed: ' .. nScanOne)
    assert(nDegenerate >= 50, 'the pre-player_id population collapsed: ' .. nDegenerate ..
        ' -- those fixtures CANNOT see this defect and must not be counted as evidence')
end

--============================================================================
-- The one siege frame in the corpus.
--============================================================================

local function siege_bodies(J)
    -- Which team members satisfy the predicate's BODY on the loaded frame:
    -- crowded (>=2 allies within 2000) AND standing on the enemy's second tier,
    -- high ground, or ancient. Every term is frame data.
    local U = J.Utils
    local BotMode = require(GetScriptDirectory() .. '/ts_libs/dota/index').BotMode
    local anc = GetAncient(GetOpposingTeam())
    local sat = {}
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if m ~= nil
            and #m:GetNearbyHeroes(2000, false, BotMode.None) >= 2
            and (U.IsNearEnemySecondTierTower(m, 2000)
                or U.IsNearEnemyHighGroundTower(m, 3000)
                or (anc ~= nil and GetUnitToUnitDistance(m, anc) < 3000))
        then
            sat[i] = m
        end
    end
    return sat
end

tests['[frame siege] shipped can see one of the four heroes doing the pushing'] = function()
    local J, bot, heroes, fx = rf.load(SIEGE_FX)
    frame_liveness(fx)
    assert(GetTeam() == 3, 'the siege frame must load dire; got ' .. tostring(GetTeam()))

    local sat = siege_bodies(J)
    assert(count(sat) == 4, 'the siege frame no longer has four pushers; has ' .. count(sat))
    assert(sat[5] ~= nil and short(sat[5]) == 'jakiro',
        'slot 5 on the siege frame drifted: ' .. short(GetTeamMember(5)))

    -- Shipped reaches only slot 5 on dire, so of the four heroes that satisfy
    -- the body it can see exactly one -- and it is a satisfying one. That is
    -- why the corpus shows no decision flip: not because the scan is adequate,
    -- but because the single member it happens to reach happens to qualify.
    local byId = scans()
    local nSeenSat = 0
    for _, m in pairs(byId) do
        for _, s in pairs(sat) do if m == s then nSeenSat = nSeenSat + 1 end end
    end
    assert(count(byId) == 1, 'shipped reach on the siege frame moved: ' .. count(byId))
    assert(nSeenSat == 1, 'shipped sees ' .. nSeenSat .. ' of the four pushers')

    -- Pure frame data, no counterfactual: shipped's one resolving step guards
    -- on player 5 and looks at slot 5, and on this frame those are two heroes.
    local pids = GetTeamPlayers(GetTeam())
    assert(pids[1] == 5, 'the dire id block moved: ' .. table.concat(pids, ','))
    assert(short(GetTeamMember(5)) == 'jakiro', 'slot 5 drifted')
    local guarded = nil
    for _, m in pairs(heroes) do
        if m.GetPlayerID and m:GetPlayerID() == 5 then guarded = m end
    end
    assert(guarded ~= nil and short(guarded) == 'juggernaut',
        'player 5 on this frame drifted: ' .. short(guarded))
    assert(guarded ~= GetTeamMember(5),
        'the guard and the subject must be two different heroes for this to be a defect')

    assert(J.Utils.IsTeamPushingSecondTierOrHighGround(bot, false) == true,
        'shipped must answer TRUE here -- off jakiro alone')
end

tests['[frame siege, positive control] armed answers TRUE on the same frame'] = function()
    -- Carries the counterfactual below: without it, "armed said TRUE" is also
    -- what a fix that always answered TRUE would produce.
    local J, bot, heroes, fx = rf.load(SIEGE_FX)
    frame_liveness(fx)
    assert(J.Utils.IsTeamPushingSecondTierOrHighGround(bot, true) == true,
        'armed must still recognise a real siege')
end

tests['[decision, COUNTERFACTUAL] one dead hero costs shipped the whole siege'] = function()
    -- ⚠ THIS ONE CONTRADICTS THE DUMP, deliberately and in exactly ONE bit:
    -- juggernaut is alive on the real frame. It is here because the corpus
    -- contains no frame where the two legs differ on their own (see [domain
    -- price]), and an inert lever is worse than a labelled counterfactual.
    -- Everything else -- the roster, where all ten heroes stand, which towers
    -- are up, where the ancient is, who is crowded -- is frame data. The
    -- load-bearing reading is [frame siege] above; this only shows the size of
    -- what the mispairing costs.
    --
    -- The bit is chosen, not arbitrary. On dire the shipped loop's ONLY step
    -- that resolves is step 1, whose guard is player 5 (juggernaut) and whose
    -- subject is slot 5 (jakiro). Kill player 5 and the guard closes the only
    -- door, so shipped answers "nobody is pushing" while three teammates --
    -- jakiro among them, untouched and unasked-about -- are standing on the
    -- enemy high ground. The first version of this test killed jakiro instead
    -- and did NOT flip: shipped happily answered TRUE off the corpse, because
    -- the hero it looks at is never the hero it checks. That is the same
    -- finding from the other side, and it is why the guard is part of this fix.
    local J, bot, heroes, fx = rf.load(SIEGE_FX)
    frame_liveness(fx, 'juggernaut')
    assert(J.Utils.IsTeamPushingSecondTierOrHighGround(bot, false) == false,
        'shipped: its one reachable step is guarded by player 5, so a dead ' ..
        'player 5 must cost it the entire siege')

    local J2, bot2, _, fx2 = rf.load(SIEGE_FX)
    frame_liveness(fx2, 'juggernaut')
    assert(J2.Utils.IsTeamPushingSecondTierOrHighGround(bot2, true) == true,
        'armed: three other heroes are still standing on the enemy high ground')
end

tests['[domain price] the corpus cannot flip this decision, and that is the finding'] = function()
    -- [premise] -- a ratchet, not a floor. Going RED here is GOOD NEWS: it
    -- means a fixture that can actually see this decision entered the archive.
    -- Re-measure, move the load-bearing reading onto that frame, and delete the
    -- counterfactual above. Both sides of every fixture are loaded, because
    -- rf.load only ever makes ONE team the subject's and a siege looks
    -- different from the defending side.
    local nCase, nTrue, nFlip = 0, 0, 0
    for _, path in ipairs(paths()) do
        local subs = {}
        local fx0 = dofile(path)
        for _, u in ipairs(fx0.units) do
            if u.team and subs[u.team] == nil and u.player_id ~= nil then subs[u.team] = u.name end
        end
        for _, name in pairs(subs) do
            local J, bot, heroes, fx = rf.load(path, name)
            if #GetTeamPlayers(GetTeam()) > 0 then
                frame_liveness(fx)
                nCase = nCase + 1
                local shipped = J.Utils.IsTeamPushingSecondTierOrHighGround(bot, false)
                local armed = J.Utils.IsTeamPushingSecondTierOrHighGround(bot, true)
                if shipped or armed then nTrue = nTrue + 1 end
                if shipped ~= armed then nFlip = nFlip + 1 end
            end
        end
    end
    assert(nCase >= 90, 'the battery shrank: ' .. nCase .. ' subject-loads')
    assert(nTrue == 1, 'the number of subject-loads where either leg answers TRUE moved ' ..
        'from 1 to ' .. nTrue .. ' -- re-measure the domain price')
    assert(nFlip == 0, 'a fixture now FLIPS this decision (' .. nFlip .. ') -- good news: ' ..
        'move the load-bearing reading onto it and drop the counterfactual test')
end

--============================================================================
-- Darkness and direction.
--============================================================================

tests['[off-candidate equivalence] unarmed IS the shipped function'] = function()
    -- The pre-fix body, transcribed from the shipped source, run beside the
    -- patched one over every fixture. Called ONCE per load per leg on purpose:
    -- the function memoises on a one-second window, so a second call with the
    -- same arming would read its own cache and assert nothing.
    local function pre_fix(J, bot)
        local U = J.Utils
        local BotMode = require(GetScriptDirectory() .. '/ts_libs/dota/index').BotMode
        local enemyAncient = GetAncient(GetOpposingTeam())
        if enemyAncient ~= nil then
            for _, playerdId in ipairs(GetTeamPlayers(bot:GetTeam())) do
                if IsHeroAlive(playerdId) then
                    local teamMember = GetTeamMember(playerdId)
                    if teamMember ~= nil
                        and #teamMember:GetNearbyHeroes(2000, false, BotMode.None) >= 2
                        and (U.IsNearEnemySecondTierTower(teamMember, 2000)
                            or U.IsNearEnemyHighGroundTower(teamMember, 3000)
                            or GetUnitToUnitDistance(teamMember, enemyAncient) < 3000)
                    then
                        return true
                    end
                end
            end
        end
        return false
    end

    local nCases = 0
    for pass = 1, 2 do
        for _, path in ipairs(paths()) do
            local J, bot, heroes, fx = rf.load(path)
            if #GetTeamPlayers(GetTeam()) > 0 then
                frame_liveness(fx)
                nCases = nCases + 1
                local want = pre_fix(J, bot)
                local got
                if pass == 1 then
                    got = J.Utils.IsTeamPushingSecondTierOrHighGround(bot)
                else
                    got = J.Utils.IsTeamPushingSecondTierOrHighGround(bot, false)
                end
                assert(got == want, 'unarmed (' .. (pass == 1 and 'no second argument' or 'false')
                    .. ') diverged in ' .. path)
            end
        end
    end
    assert(nCases >= 200, 'the battery shrank: ' .. nCases .. ' cases')
end

tests['[direction] armed never reaches FEWER members than shipped'] = function()
    -- The direction claim, measured rather than argued: the scanned set only
    -- ever grows, so "the team is pushing" only ever becomes EASIER to believe,
    -- and the callers only ever suppress MORE distractions. (Not a TRUE-set
    -- superset claim: armed also re-pairs each guard with its own subject, so a
    -- shipped TRUE earned off an unchecked hero can legitimately vanish. That
    -- is the [guard] reading, not this one.)
    local nCases, nWider = 0, 0
    for _, path in ipairs(paths()) do
        rf.load(path)
        if #GetTeamPlayers(GetTeam()) > 0 then
            nCases = nCases + 1
            local byId, bySlot = scans()
            assert(count(bySlot) >= count(byId), path .. ': armed reached FEWER members')
            if count(bySlot) > count(byId) then nWider = nWider + 1 end
        end
    end
    assert(nCases >= 100, 'the battery shrank: ' .. nCases)
    assert(nWider >= 40, 'armed widened almost nothing on the whole corpus: ' .. nWider)
end

--============================================================================
-- Structure: one gate, one place, turbo first.
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

tests['[structure] the wrapper owns the slotpush gate, turbo-first'] = function()
    local code = strip_comments(read('bots/FunLib/jmz_func.lua'))
    local fn = code:match('function J%.IsTeamPushingHighGround%s*%b()(.-)\nend')
    assert(fn, 'the J.IsTeamPushingHighGround wrapper is gone or reshaped')
    local iCand = fn:find("J%.IsSoakCandidate%s*%(%s*'slotpush'%s*%)")
    assert(iCand, "the fix must be gated on 'slotpush'; got: " .. fn)
    local iTurbo = fn:find('J%.IsModeTurbo%s*%(%s*%)')
    assert(iTurbo, 'the fix must be turbo-only; got: ' .. fn)
    assert(iTurbo < iCand, 'IsModeTurbo() must be evaluated before the slotpush check')
    assert(fn:find('J%.Utils%.IsTeamPushingSecondTierOrHighGround%s*%('),
        'the wrapper must delegate to the utils predicate, not reimplement it')
end

tests['[structure] utils does not name the id; it only takes the flag'] = function()
    local code = strip_comments(read('bots/FunLib/utils.lua'))
    assert(not code:find('slotpush'), "'slotpush' must be resolved in jmz_func.lua, " ..
        'never read inside utils.lua -- utils may not import jmz_func at all')
    local fn = code:match('function ____exports%.IsTeamPushingSecondTierOrHighGround.-\nend')
    assert(fn, 'IsTeamPushingSecondTierOrHighGround is gone or reshaped')
    assert(fn:find('bSlotPush'), 'the predicate lost the gate parameter')
    assert(fn:find('GetTeamMember%s*%(%s*nSlot%s*%)'),
        'the fix must be the ARGUMENT, not a new clause around the call')
    assert(fn:find('nSlot%s*=%s*playerdId'), 'unarmed must still pass the player id')
    assert(fn:find('nSlot%s*=%s*i%s'), 'armed must pass the loop index')
    -- The memo key must fork with the arming, or the first leg called in a
    -- given second decides for the other one too.
    assert(fn:find('cacheKey%s*=%s*cacheKey%s*%.%.%s*"byslot"'),
        'the armed leg must not share the shipped leg\'s cache key')
end

tests['[structure] all seven mode scripts go through the wrapper'] = function()
    -- Both halves of the "one place to arm" claim, by census: the utils
    -- predicate is named exactly once outside its own file (in the wrapper),
    -- and the wrapper is what the desire scripts call.
    local p = assert(io.popen(
        "grep -rn 'IsTeamPushingSecondTierOrHighGround\\|IsTeamPushingHighGround' bots/ --include='*.lua'"))
    local nDirect, nWrapped, direct = 0, 0, {}
    for line in p:lines() do
        local path, num, text = line:match('^([^:]+):(%d+):(.*)$')
        if path and not text:match('^%s*%-%-') and path ~= 'bots/FunLib/utils.lua'
            and not text:match('^%s*function%s') then
            if text:find('J%.Utils%.IsTeamPushingSecondTierOrHighGround') then
                nDirect = nDirect + 1
                direct[#direct + 1] = path .. ':' .. num
            elseif text:find('J%.IsTeamPushingHighGround%s*%(%s*bot%s*%)') then
                nWrapped = nWrapped + 1
            end
        end
    end
    p:close()
    assert(nDirect == 1, 'the utils predicate must be named exactly once outside utils.lua ' ..
        '(the wrapper); found ' .. nDirect .. ':\n  ' .. table.concat(direct, '\n  '))
    assert(nWrapped == 7, 'expected seven mode-script call sites on the wrapper, found ' .. nWrapped)
end

tests['[ts parity] the TypeScript source carries the same argument fix'] = function()
    local ts = read('typescript/bots/FunLib/utils.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    local fn = ts:match('export function IsTeamPushingSecondTierOrHighGround.-\n}')
    assert(fn, 'the TS predicate is gone or reshaped')
    assert(fn:find('bSlotPush%?: boolean'), 'the TS predicate lost the gate parameter')
    assert(fn:find('GetTeamMember%(bSlotPush %? i : playerdId%)'),
        'the TS argument drifted from the Lua one')
    assert(fn:find('cacheKey %+ "byslot"'), 'the TS memo key does not fork with the arming')
end

tests['[instrument] the bare mock cannot see the guard/subject split'] = function()
    -- tests/mock/bot_api.lua answers IsHeroAlive(id) with a constant true for
    -- any id, so on that instrument the guard is satisfied for a hero that is
    -- not the one being looked at and nothing shows. Every reading above that
    -- depends on liveness therefore declares frame_liveness() first. If this
    -- assertion ever fails the mock grew a real roster -- drop the declaration
    -- and say so in the report.
    local mock = require('mock.bot_api')
    mock.install({ bot = mock.MakeHero('npc_dota_hero_axe'), team = 3 })
    assert(IsHeroAlive(4242) == true,
        'the bot_api mock now answers IsHeroAlive for real -- the blind spot is closed')
    assert(GetTeamMember(9) ~= nil,
        'the bot_api mock now refuses an out-of-range slot -- the other blind spot is closed')
end

return tests

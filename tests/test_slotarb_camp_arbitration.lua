-- Soak candidate 'slotarb' -- bots/FunLib/aba_site.lua, IsTheClosestOne.
--
-- MAIN CLAIM (reusable, beyond this topic): when a loop's DOMAIN and its
-- ACCESSOR are indexed by two different number spaces, the mismatch does not
-- raise -- it silently shrinks the domain, and the shrink is side-dependent.
--
--   GetTeamPlayers(GetTeam())  hands back PLAYER IDS  (0-4 radiant, 5-9 dire)
--   GetTeamMember(n)           takes a TEAM SLOT       (1..5)
--
-- docs/BOT_API_REFERENCE.md:223 says 1..5 and "nil if the player slot doesn't
-- exist"; tests/mock/replay_fixture.lua and tests/mock/bot_api.lua both
-- implement it that way. The shipped line feeds an id where a slot goes, so
-- out-of-range reads answer nil and the arbitration scans a SUBSET:
--
--   radiant  ids {0,1,2,3,4} -> slots {1,2,3,4}   4 of 5, slot 5 never asked
--   dire     ids {5,6,7,8,9} -> slot  {5}         1 of 5
--
-- [frame F1] and [frame F2] below print that table off two real frames, and
-- [corpus] shows it holds on every fixture in the archive that carries
-- player_id (47 of 107; the other 60 predate the dumper's player_id key and
-- report bare indices, where id == i and the defect is INVISIBLE -- that is a
-- degenerate world, not a clean bill of health).
--
-- WHY IT MATTERS: missing a teammate can only make "nobody is closer than me"
-- EASIER to believe, so this fails toward OPEN -- several bots each conclude
-- they own the same neutral camp. On dire the loop sees exactly one member
-- (the pid-9 player), and for that bot itself it sees only itself, so the whole
-- arbitration is a no-op and the answer is unconditionally TRUE.
--
-- STRICT SUBSET: armed scans a superset of members, and a wider scan can only
-- ever FIND someone closer. So armed's TRUE set is a strict subset of the
-- shipped TRUE set: it can refuse a camp the shipped code took, and can never
-- take one the shipped code refused. [subset] asserts that over the corpus.
--
-- The gate is threaded, not read here: 'slotarb' is resolved in exactly one
-- place, ClosestCamp in bots/mode_farm_generic.lua, the same wrapper 'campsel'
-- already uses. Unarmed, IsTheClosestOne is byte-for-byte the shipped
-- function -- [off-candidate] runs the transcribed pre-fix body beside it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local DIRE_FX = 'tests/fixtures/f_260819_182855_lion_drain_jungle.lua'
local RAD_FX  = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'

local tests = {}

local function short(u)
    if u == nil then return 'NIL' end
    return (u:GetUnitName():gsub('npc_dota_hero_', ''))
end

-- The scan the shipped loop performs (by id) and the one armed performs (by
-- slot), read off whatever world is currently loaded. Pure frame data: no
-- harness-supplied field is touched.
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
-- Ground truth on two real frames.
--============================================================================

tests['[frame F1] dire: the shipped loop looks at ONE member, and it is itself'] = function()
    local J, bot = rf.load(DIRE_FX)
    assert(GetTeam() == 3, 'F1 must be a dire frame; got team ' .. tostring(GetTeam()))
    local pids = GetTeamPlayers(GetTeam())
    assert(#pids == 5, 'F1 roster is not five deep: ' .. #pids)
    assert(pids[1] == 5 and pids[5] == 9,
        'F1 player ids are not the dire 5..9 block: {' .. table.concat(pids, ',') .. '}')

    local byId, bySlot = scans()
    assert(count(bySlot) == 5, 'armed must see the whole roster; saw ' .. count(bySlot))
    assert(count(byId) == 1, 'shipped must see exactly one member on dire; saw ' ..
        count(byId) .. ' -- if this moved, the fixture roster changed')
    assert(byId[1] ~= nil and byId[2] == nil and byId[3] == nil
        and byId[4] == nil and byId[5] == nil,
        'the one member the shipped loop sees must be the FIRST step (id 5 -> slot 5)')

    -- and that one member is the bot itself, so the loop decides nothing
    assert(byId[1] == bot, 'F1: the single visible member should be the subject itself, got '
        .. short(byId[1]) .. ' vs subject ' .. short(bot))
    assert(short(bot) == 'lion', 'F1 subject drifted: ' .. short(bot))
end

tests['[frame F2] radiant: 4 of 5, and every step names the WRONG hero'] = function()
    local J, bot = rf.load(RAD_FX)
    assert(GetTeam() == 2, 'F2 must be a radiant frame; got team ' .. tostring(GetTeam()))
    local pids = GetTeamPlayers(GetTeam())
    assert(pids[1] == 0 and pids[5] == 4,
        'F2 player ids are not the radiant 0..4 block: {' .. table.concat(pids, ',') .. '}')

    local byId, bySlot = scans()
    assert(count(bySlot) == 5, 'armed must see the whole roster; saw ' .. count(bySlot))
    assert(count(byId) == 4, 'shipped must see four members on radiant; saw ' .. count(byId))
    assert(byId[1] == nil, 'player id 0 is out of slot range and must read nil')
    assert(bySlot[5] ~= nil and byId[5] ~= bySlot[5],
        'slot 5 must exist and must NOT be what the shipped loop reads at step 5')

    -- The off-by-one is not only a missing member: at every step from 2 on, the
    -- hero the shipped loop measures is a DIFFERENT hero than the step is on.
    local nMisaligned = 0
    for i = 2, 5 do
        if byId[i] ~= bySlot[i] then nMisaligned = nMisaligned + 1 end
    end
    assert(nMisaligned == 4, 'expected all four remaining steps misaligned, got ' .. nMisaligned)
    assert(short(bot) == 'viper', 'F2 subject drifted: ' .. short(bot))
end

--============================================================================
-- Corpus: the shape is not a property of two hand-picked frames.
--============================================================================

tests['[corpus] every player_id fixture shows the shrink, by side'] = function()
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local paths = {}
    for path in p:lines() do paths[#paths + 1] = path end
    p:close()

    local nTotal, nDire, nRadiant, nDegenerate, nScanOne = 0, 0, 0, 0, 0
    for _, path in ipairs(paths) do
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

    -- Floors, not equalities (GH #106): adding a fixture must not turn this red.
    assert(nTotal >= 100, 'corpus shrank: ' .. nTotal .. ' loadable fixtures')
    -- Measured 2026-09-01 on 107 fixtures: 24 dire + 23 radiant defective,
    -- 60 degenerate (no player_id in the dump, so id == i and nothing differs).
    assert(nDire >= 20, 'the dire population collapsed: ' .. nDire)
    assert(nRadiant >= 20, 'the radiant population collapsed: ' .. nRadiant)
    assert(nScanOne >= 20, 'the "scans exactly one member" population collapsed: ' .. nScanOne)
    assert(nDegenerate >= 50, 'the pre-player_id population collapsed: ' .. nDegenerate ..
        ' -- these fixtures CANNOT see this defect and must not be counted as evidence')
end

--============================================================================
-- The decision itself, on a real frame.
--============================================================================

-- DECLARED HARNESS INPUT: the frame dumps carry no active mode, so
-- GetActiveMode is specified here. Everything else the assertion leans on --
-- who is on the roster, where each of them stands, who is alive -- is frame
-- data. Without the spec every member fails the `== BotMode.Farm` test, the
-- loop body never runs, and both legs answer TRUE for a reason that has
-- nothing to do with this fix.
local function farming_roster()
    local J, bot, heroes, fx = rf.load(DIRE_FX)
    local BotMode = require(GetScriptDirectory() .. '/ts_libs/dota/index').BotMode
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if m ~= nil then
            local spec = rawget(m, '__spec')
            spec.GetActiveMode = BotMode.Farm
            spec.IsAlive = true
        end
    end
    return J, bot
end

tests['[decision] armed refuses a camp a teammate is standing on; shipped takes it'] = function()
    local J, bot = farming_roster()
    -- A real teammate's real position on this frame: dragon_knight, slot 4.
    local mate = GetTeamMember(4)
    assert(mate ~= nil and short(mate) == 'dragon_knight',
        'slot 4 drifted: ' .. short(mate))
    local loc = mate:GetLocation()
    local d = GetUnitToLocationDistance(bot, loc)
    assert(d > 200, 'the teammate must actually be somewhere else; got ' .. d)

    assert(J.Site.IsTheClosestOne(bot, loc) == true,
        'shipped: the dire loop sees only itself, so it must claim the camp')
    assert(J.Site.IsTheClosestOne(bot, loc, true) == false,
        'armed: a farming teammate is standing ON the location and must win it')
end

tests['[decision, positive control] armed still claims a camp nobody else is near'] = function()
    -- The control carries the assertion above: without it, "armed answers
    -- false" is also what a fix that simply always answers false would produce.
    local J, bot = farming_roster()
    local at = bot:GetLocation()
    local loc = Vector(at.x + 40, at.y + 40, at.z)
    assert(J.Site.IsTheClosestOne(bot, loc) == true, 'shipped must claim its own feet')
    assert(J.Site.IsTheClosestOne(bot, loc, true) == true,
        'armed must still claim a location it is genuinely closest to')
end

--============================================================================
-- Darkness and direction.
--============================================================================

tests['[off-candidate equivalence] unarmed IS the shipped function'] = function()
    -- The pre-fix body, transcribed from the shipped source, run beside the
    -- patched one over every fixture and every hero position in it.
    local function pre_fix(bot, loc)
        local minDist = GetUnitToLocationDistance(bot, loc)
        local closestMember = bot
        local BotMode = require(GetScriptDirectory() .. '/ts_libs/dota/index').BotMode
        for _, id in ipairs(GetTeamPlayers(GetTeam())) do
            local member = GetTeamMember(id)
            if member and member:IsAlive() and member:GetActiveMode() == BotMode.Farm then
                local memberDist = GetUnitToLocationDistance(member, loc)
                if memberDist < minDist then
                    minDist = memberDist
                    closestMember = member
                end
            end
        end
        return closestMember == bot
    end

    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local paths = {}
    for path in p:lines() do paths[#paths + 1] = path end
    p:close()

    local nCases = 0
    for _, path in ipairs(paths) do
        local J, bot = rf.load(path)
        if #GetTeamPlayers(GetTeam()) > 0 then
            local locs = {}
            for i = 1, 5 do
                local m = GetTeamMember(i)
                if m ~= nil then locs[#locs + 1] = m:GetLocation() end
            end
            local at = bot:GetLocation()
            locs[#locs + 1] = Vector(at.x + 1500, at.y - 1500, at.z)
            for _, loc in ipairs(locs) do
                nCases = nCases + 1
                local want = pre_fix(bot, loc)
                assert(J.Site.IsTheClosestOne(bot, loc) == want,
                    'unarmed (no third argument) diverged in ' .. path)
                assert(J.Site.IsTheClosestOne(bot, loc, false) == want,
                    'unarmed (false) diverged in ' .. path)
            end
        end
    end
    assert(nCases >= 500, 'the battery shrank: ' .. nCases .. ' cases')
end

tests['[subset] armed TRUE is a strict subset of shipped TRUE'] = function()
    -- The direction claim, measured rather than argued. A fix that merely
    -- disagreed would satisfy neither half of this.
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    local paths = {}
    for path in p:lines() do paths[#paths + 1] = path end
    p:close()

    local nCases, nFlips = 0, 0
    for _, path in ipairs(paths) do
        local J, bot = rf.load(path)
        if #GetTeamPlayers(GetTeam()) > 0 then
            local BotMode = require(GetScriptDirectory() .. '/ts_libs/dota/index').BotMode
            local locs = {}
            for i = 1, 5 do
                local m = GetTeamMember(i)
                if m ~= nil then
                    local spec = rawget(m, '__spec')
                    spec.GetActiveMode = BotMode.Farm
                    spec.IsAlive = true
                    locs[#locs + 1] = m:GetLocation()
                end
            end
            for _, loc in ipairs(locs) do
                nCases = nCases + 1
                local shipped = J.Site.IsTheClosestOne(bot, loc)
                local armed = J.Site.IsTheClosestOne(bot, loc, true)
                assert(not (armed and not shipped),
                    'armed said TRUE where shipped said FALSE in ' .. path ..
                    ' -- that direction is impossible if armed only ever scans MORE')
                if shipped and not armed then nFlips = nFlips + 1 end
            end
        end
    end
    assert(nCases >= 200, 'the battery shrank: ' .. nCases .. ' cases')
    -- The subset must be PROPER somewhere, or the fix is inert on this corpus.
    -- Measured 2026-09-01: 46 flips. Floor, not equality (GH #106).
    assert(nFlips >= 40, 'armed changed almost no decision on the whole corpus: ' .. nFlips)
end

--============================================================================
-- Structure: one gate, one place, turbo first; and the census behind the claim.
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

tests['[structure] the wrapper owns the slotarb gate, turbo-first'] = function()
    local code = strip_comments(read('bots/mode_farm_generic.lua'))
    local call = code:match('J%.Site%.GetClosestNeutralSpwan%s*(%b())')
    assert(call, 'the GetClosestNeutralSpwan call site moved or changed shape')
    local iCand = call:find("J%.IsSoakCandidate%s*%(%s*'slotarb'%s*%)")
    assert(iCand, "the fix must be gated on 'slotarb'; got: " .. call)
    -- The turbo check that governs THIS id is the one immediately before it,
    -- not merely some IsModeTurbo() somewhere in the argument list ('campsel'
    -- has its own). Assert the nearest preceding one.
    local iTurbo = nil
    local pos = 1
    while true do
        local s = call:find('J%.IsModeTurbo%s*%(%s*%)', pos)
        if not s or s > iCand then break end
        iTurbo = s
        pos = s + 1
    end
    assert(iTurbo, 'the fix must be turbo-only; got: ' .. call)
    assert(iTurbo < iCand, 'IsModeTurbo() must be evaluated before the slotarb check')
    local between = call:sub(iTurbo, iCand)
    assert(not between:find('campsel'),
        "the turbo check nearest 'slotarb' is campsel's -- slotarb needs its own")
end

tests['[structure] aba_site does not name the id; it only takes the flag'] = function()
    local code = strip_comments(read('bots/FunLib/aba_site.lua'))
    assert(not code:find('slotarb'), "'slotarb' must be resolved at the ONE call site " ..
        'in mode_farm_generic.lua, never read inside aba_site.lua')
    local fn = code:match('IsTheClosestOne%s*=%s*function.-\nend')
    assert(fn, 'IsTheClosestOne is gone or reshaped')
    assert(fn:find('bSlotArb'), 'IsTheClosestOne lost the gate parameter')
    assert(fn:find('GetTeamMember%s*%(%s*nSlot%s*%)'),
        'the fix must be the ARGUMENT, not a new clause around the call')
    assert(fn:find('nSlot%s*=%s*id'), 'unarmed must still pass the player id')
    assert(fn:find('nSlot%s*=%s*i%s'), 'armed must pass the loop index')

    -- The selector is the only caller inside this file, and it is the link
    -- that carries the flag down from mode_farm_generic. Without this the flag
    -- can be dropped between the wrapper and the predicate and every
    -- behavioural assertion above still passes -- they call IsTheClosestOne
    -- directly, so they would never notice.
    local sel = code:match('GetClosestNeutralSpwan%s*=%s*function.-\nend')
    assert(sel, 'GetClosestNeutralSpwan is gone or reshaped')
    assert(sel:find('bSlotArb%s*%)%s*$') or sel:match('function%s*%b()'):find('bSlotArb'),
        'the selector does not accept the flag')
    assert(sel:find('IsTheClosestOne%s*%(%s*bot%s*,%s*camp%.cattr%.location%s*,%s*bSlotArb%s*%)'),
        'the selector accepts the flag but does not pass it to IsTheClosestOne')
end

tests['[ts parity] the TypeScript source carries the same argument fix'] = function()
    local ts = read('typescript/bots/FunLib/aba_site.ts')
    ts = ts:gsub('/%*.-%*/', ' '):gsub('//[^\n]*', ' ')
    local fn = ts:match('IsTheClosestOne%s*=%s*function.-\n};')
    assert(fn, 'the TS IsTheClosestOne is gone or reshaped')
    assert(fn:find('bSlotArb'), 'the TS function lost the gate parameter')
    assert(fn:find('GetTeamMember%(bSlotArb %? i : id%)'),
        'the TS argument drifted from the Lua one')
    local sel = ts:match('GetClosestNeutralSpwan%s*=%s*function.-\n};')
    assert(sel, 'the TS selector is gone or reshaped')
    -- Not `sel:find('bSlotArb')`: the parameter list alone satisfies that, so a
    -- selector that ACCEPTS the flag and then drops it reads as threaded. (This
    -- exact mutant survived the first pass of the stand -- a right conclusion
    -- reached by a wrong reason.) Assert the hand-off itself.
    assert(sel:match('function%s*%b()'):find('bSlotArb'),
        'the TS selector does not accept the flag')
    assert(sel:find('IsTheClosestOne%(bot, camp%.cattr%.location, bSlotArb%)'),
        'the TS selector accepts the flag but never passes it on')
end

tests['[census] one lever: eight pid-shaped call sites stay untouched'] = function()
    -- The evidence that this is a defect and not a house idiom is the ratio,
    -- and the evidence that this is ONE lever is that the ratio moved by
    -- exactly one. Both are counts, not promises.
    local p = assert(io.popen("grep -rn 'GetTeamMember' bots/ --include='*.lua'"))
    local slotShaped, pidShaped, other = 0, 0, {}
    local pidSites = {}
    for line in p:lines() do
        local path, num, text = line:match('^([^:]+):(%d+):(.*)$')
        if path and not text:match('^%s*%-%-') then
            for arg in text:gmatch('GetTeamMember%s*%(([^)]*)%)') do
                arg = arg:gsub('^%s*', ''):gsub('%s*$', '')
                if arg:match('^%d+$') or arg == 'i' or arg == 'nSlot' or arg == 'i + 1' then
                    slotShaped = slotShaped + 1
                elseif arg == 'id' or arg == 'playerId' or arg == 'playerdId' or arg == 'pid' then
                    pidShaped = pidShaped + 1
                    pidSites[#pidSites + 1] = path .. ':' .. num
                else
                    other[#other + 1] = path .. ':' .. num .. ' (' .. arg .. ')'
                end
            end
        end
    end
    p:close()

    assert(slotShaped >= 75, 'the slot-shaped majority collapsed: ' .. slotShaped ..
        ' -- if this fell, the house idiom changed and the 80:10 claim needs redoing')
    -- 2026-09-02: was nine, then eight. The ninth -- J.IsClosestToDustLocation
    -- in jmz_func.lua, the same "am I the closest" shape this test named as the
    -- next lever -- became soak candidate 'slotdust'
    -- (tests/test_slotdust_dust_arbitration.lua); the eighth --
    -- IsTeamPushingSecondTierOrHighGround, the only one of the utils.lua
    -- cluster with more than one live caller -- became 'slotpush'
    -- (tests/test_slotpush_highground_scan.lua). The seven that remain are all
    -- in one file, so the count and the cluster below say the same thing twice
    -- on purpose: if they ever disagree, a site moved somewhere unexpected.
    -- Read that file's header before picking the next one: four of the seven
    -- have NO caller in bots/ at all, and the two that do (aba_push.lua:584 and
    -- :587) never answer TRUE once on the whole fixture corpus.
    -- 2026-09-03: seven -> FIVE. The fourth lever, 'slotwait' (commit dc63d791,
    -- GH #467), converted the last two LIVE utils.lua sites --
    -- HasTeamMemberWithCriticalItemInCooldown and ...SpellInCooldown. That
    -- commit moved neither this pin nor its deliberate duplicate in
    -- tests/test_slotdust_dust_arbitration.lua, so both went red together --
    -- the duplication doing exactly the job its comment claims. The five that
    -- remain are the DEAD half of the utils.lua cluster: no caller in bots/ at
    -- all, which is why picking a next lever here now needs a caller first.
    -- Re-derived from the scan, not relaxed.
    assert(pidShaped == 5, 'expected exactly five pid-shaped call sites left after ' ..
        'the slotarb, slotdust, slotpush and slotwait levers, found ' .. pidShaped .. ':\n  ' ..
        table.concat(pidSites, '\n  '))
    local nUtils = 0
    for _, s in ipairs(pidSites) do
        if s:match('bots/FunLib/utils%.lua') then nUtils = nUtils + 1 end
    end
    assert(nUtils == 5, 'the utils.lua cluster moved: ' .. nUtils .. ' of 5')
    -- Registered, not fixed: a two-argument call whose first argument is a TEAM
    -- constant, not a slot. It spans two source lines, so the line-oriented
    -- census above cannot see it at all -- read it whole, or the count silently
    -- omits the one site that is neither shape.
    assert(#other == 0, 'a new one-line GetTeamMember argument shape appeared:\n  ' ..
        table.concat(other, '\n  '))
    local ais = strip_comments(read('bots/FunLib/advanced_item_strategy.lua'))
    assert(ais:find('GetTeamMember%s*%(%s*GetOpposingTeam%s*%(%s*%)%s*,'),
        'the GetTeamMember(GetOpposingTeam(), i) site vanished -- if it was ' ..
        'fixed, drop this assertion with it')
end

tests['[instrument] the plain mock cannot see this defect, and that is why nothing did'] = function()
    -- tests/mock/bot_api.lua answers GetTeamMember(n) for any n, so an
    -- out-of-range read there is a hero, not nil. Every unit test written
    -- against that mock is structurally blind to this bug; only the real-frame
    -- roster in replay_fixture.lua reports nil. If this assertion ever fails,
    -- the mock was fixed -- delete this test and say so in the report.
    local mock = require('mock.bot_api')
    mock.install({ bot = mock.MakeHero('npc_dota_hero_axe'), team = 3 })
    assert(GetTeamMember(9) ~= nil,
        'the bot_api mock now refuses an out-of-range slot -- the blind spot is closed')
end

return tests

-- Soak candidate 'slotdust' -- bots/FunLib/jmz_func.lua, J.IsClosestToDustLocation.
--
-- MAIN CLAIM (reusable, beyond this topic): when a loop's DOMAIN and its
-- ACCESSOR are indexed by two different number spaces, the mismatch does not
-- raise -- it silently shrinks the domain, and the shrink is side-dependent.
--
--   GetTeamPlayers(GetTeam())  hands back PLAYER IDS  (0-4 radiant, 5-9 dire)
--   GetTeamMember(n)           takes a TEAM SLOT       (1..5)
--
-- This is the SECOND of the ten pid-shaped call sites GH #406 counted (80 : 10
-- in the shipped tree), and the one it named as the next lever. The first,
-- 'slotarb', is the neutral-camp arbitration in aba_site.lua.
--
-- WHAT IS DIFFERENT HERE, AND WHY IT IS THE WHOLE POINT. IsTheClosestOne seeds
-- its search with `bot` itself, so the caller is always a candidate and armed's
-- TRUE set is a strict SUBSET of shipped's. This function seeds with `nil`:
-- the caller wins only by being FOUND in the scan. So the same shrink cuts
-- BOTH ways here, and the strict-subset argument that carried 'slotarb' is NOT
-- available -- see [not-subset] below, which asserts both directions rather
-- than assuming either. Copying the safety claim across from the sibling fix
-- because the defect looked identical would have been a right-shaped sentence
-- about the wrong function.
--
-- WHAT IT COSTS IN GAME. On dire the loop reaches exactly one member, the pid-9
-- player, so the dust/gungir arbitration is reserved to that one bot and
-- answers nil for the whole team when that bot is not carrying dust. On radiant
-- it reaches slots 1..4 and never asks for slot 5, so the slot-5 hero can never
-- claim its own dust. [decision D3] and [decision D4] read both off real
-- frames: on D3 the shipped code hands the decision to a carrier 3,938 units
-- away while refusing the carrier standing on the spot.
--
-- The gate is threaded, not read in jmz_func: 'slotdust' is resolved in exactly
-- one place, the ClosestDustCarrier wrapper in bots/ability_item_usage_generic.lua,
-- which is where all three call sites in bots/ live. Unarmed, the helper is
-- byte-for-byte the shipped function -- [off-candidate] runs the transcribed
-- pre-fix body beside it over the whole roster and a location sweep.
--
-- INSTRUMENT. Two mock gaps had to be closed before this predicate could be
-- evaluated on a frame at all, and both are registered below as [instrument]
-- rather than quietly enjoyed:
--   (1) GetItemSlotType was unspecced on fixture heroes. It is NOT that the
--       constants were missing -- api.install auto-resolves ALL_CAPS globals to
--       distinct sentinels >= 1001 -- it is that an unspecced `^Get` answers 0,
--       so `GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN` was `0 == 1174`:
--       FALSE on every frame in the corpus, and every branch behind one
--       constructively unreachable. Fails CLOSED, silently. The same trap is
--       documented at a sibling site in tests/test_fieldbuy_backpack_rescuer.lua:50
--       (GH #89's thirteenth world assertion); this is that shape recurring.
--   (2) The fixture's item names are ENTITY CLASS names, not engine item names.
--       See [instrument I2].

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- dire: two main-inventory dust carriers, in slot 4 (ES, pid 8) and slot 5
-- (jakiro, pid 9). The shipped scan reaches only the second.
local DIRE_FX = 'tests/fixtures/f_260820_162859_es_blink_flee_615.lua'
-- radiant: the team's ONLY main-inventory dust carrier is vengeful_spirit,
-- pid 4 -- team slot 5, the one slot the shipped scan never asks for.
local RAD_FX = 'tests/fixtures/f_260820_043140_luna_ring_bid.lua'

local tests = {}

local function short(u)
    if u == nil then return 'NIL' end
    return (u:GetUnitName():gsub('npc_dota_hero_', ''))
end

local function member_named(sFragment)
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if m ~= nil and m:GetUnitName():find(sFragment, 1, true) then return m, i end
    end
    return nil
end

-- The two scans, read off whatever world is loaded. Pure frame data.
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
-- Ground truth on two real frames: what the shipped loop can see.
--============================================================================

tests['[frame D1] dire: the shipped scan reaches ONE of five teammates'] = function()
    local _, bot = rf.load(DIRE_FX)
    assert(GetTeam() == 3, 'D1 must be a dire frame; got team ' .. tostring(GetTeam()))
    assert(short(bot) == 'earthshaker', 'D1 subject moved: ' .. short(bot))
    local pids = GetTeamPlayers(GetTeam())
    assert(#pids == 5, 'D1 roster is not five deep: ' .. #pids)
    assert(pids[1] == 5 and pids[5] == 9,
        'D1 dire ids are not 5..9: ' .. table.concat(pids, ','))

    local byId, bySlot = scans()
    assert(count(bySlot) == 5, 'the slot scan should see the whole roster, saw ' .. count(bySlot))
    assert(count(byId) == 1, 'the shipped id scan should see exactly one member, saw ' ..
        count(byId))
    assert(short(byId[1]) == 'jakiro',
        'the one member the shipped scan reaches is not the pid-9 hero: ' .. short(byId[1]))
    -- ids 6..9 are out of range for a five-slot roster, so four of five reads
    -- are nil rather than wrong -- silence, not an error.
    for i = 2, 5 do
        assert(byId[i] == nil, 'id ' .. pids[i] .. ' answered ' .. short(byId[i]) ..
            ' -- the out-of-range read stopped being nil')
    end
end

tests['[frame D2] radiant: four of five, and every step names another hero'] = function()
    local _, bot = rf.load(RAD_FX)
    assert(GetTeam() == 2, 'D2 must be a radiant frame; got team ' .. tostring(GetTeam()))
    assert(short(bot) == 'luna', 'D2 subject moved: ' .. short(bot))
    local pids = GetTeamPlayers(GetTeam())
    assert(pids[1] == 0 and pids[5] == 4,
        'D2 radiant ids are not 0..4: ' .. table.concat(pids, ','))

    local byId, bySlot = scans()
    assert(count(bySlot) == 5, 'the slot scan should see the whole roster, saw ' .. count(bySlot))
    assert(count(byId) == 4, 'the shipped id scan should see four members, saw ' .. count(byId))
    assert(byId[1] == nil, 'id 0 is out of range and must answer nil, got ' .. short(byId[1]))
    -- Slot 5 is never asked for, and that is where this frame's only dust is.
    local vs, iSlot = member_named('vengeful')
    assert(vs ~= nil and iSlot == 5, 'D2 carrier is no longer the slot-5 hero')
    for i = 1, 5 do
        assert(byId[i] ~= vs, 'the shipped scan reached the slot-5 hero after all')
    end
    -- The misalignment, stated as a count rather than as prose: from step 2 on,
    -- the member the loop is holding is not the member the step is about.
    local nMisaligned = 0
    for i = 2, 5 do
        if byId[i] ~= bySlot[i] then nMisaligned = nMisaligned + 1 end
    end
    assert(nMisaligned == 4, 'expected all four remaining steps misaligned, got ' .. nMisaligned)
end

--============================================================================
-- The decision itself, on real frames. This is the part [frame] cannot buy:
-- the scan set is the mechanism, the return value is the behaviour.
--============================================================================

-- Every cell of the dire 2x2, measured 2026-09-02 and asserted as absolute
-- values -- not as "shipped differs from armed", which a fix that always
-- answered false would also satisfy.
tests['[decision D3] dire: both flip directions and both controls, one frame'] = function()
    local J = rf.load(DIRE_FX)
    local es = assert(member_named('earthshaker'), 'D3 lost earthshaker')
    local ja = assert(member_named('jakiro'), 'D3 lost jakiro')

    -- The constants must be non-nil, mutually distinct AND non-zero before
    -- anything below means what it says. Zero is the load-bearing third
    -- condition and the least obvious: an unspecced `^Get` on this mock
    -- answers 0, so pinning MAIN to 0 would make every unit the loader did not
    -- build as a fixture hero report "main inventory" by default -- the silent
    -- fail-CLOSED that hid this branch would become a silent fail-OPEN. (The
    -- first pass of the mutation stand went the other way and taught the same
    -- lesson from the other side: deleting a constant does NOT make it nil
    -- here, because api.install auto-resolves ALL_CAPS globals to distinct
    -- sentinels -- so "the constant was missing" was never the mechanism.)
    assert(ITEM_SLOT_TYPE_MAIN ~= nil and ITEM_SLOT_TYPE_BACKPACK ~= nil
        and ITEM_SLOT_TYPE_STASH ~= nil, 'a slot-type constant is missing from _G')
    assert(ITEM_SLOT_TYPE_MAIN ~= ITEM_SLOT_TYPE_BACKPACK
        and ITEM_SLOT_TYPE_MAIN ~= ITEM_SLOT_TYPE_STASH
        and ITEM_SLOT_TYPE_BACKPACK ~= ITEM_SLOT_TYPE_STASH,
        'the slot-type constants collide; the reader cannot discriminate')
    assert(ITEM_SLOT_TYPE_MAIN ~= 0, 'ITEM_SLOT_TYPE_MAIN is 0, which is what an ' ..
        'unspecced Get* answers -- every unmodelled unit now reads as main inventory')

    -- Preconditions, read off the frame: both carry a castable dust in the MAIN
    -- inventory. If this ever stops holding the four cells below are vacuous.
    for _, m in ipairs({ es, ja }) do
        local slot = m:FindItemSlot('item_dust')
        assert(slot >= 0, short(m) .. ' no longer carries item_dust on this frame')
        assert(m:GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN,
            short(m) .. "'s dust is not in the main inventory (slot " .. slot .. ')')
        assert(m:GetItemInSlot(slot):IsFullyCastable(), short(m) .. "'s dust is not castable")
    end

    local atES, atJA = es:GetLocation(), ja:GetLocation()
    local gap = GetUnitToLocationDistance(ja, atES)
    assert(gap > 3900 and gap < 3980,
        'the two carriers moved; the "3,938 units away" sentence needs redoing: ' .. gap)

    -- shipped FALSE -> armed TRUE: the carrier standing ON the spot is refused
    -- today, purely because its player id is not a slot number.
    assert(J.IsClosestToDustLocation(es, atES, false) == false, 'D3 a: shipped said true')
    assert(J.IsClosestToDustLocation(es, atES, true) == true, 'D3 a: armed did not claim')
    -- shipped TRUE -> armed FALSE: the carrier 3,938 units away owns the
    -- decision today and yields it once the scan can see the nearer one.
    assert(J.IsClosestToDustLocation(ja, atES, false) == true, 'D3 b: shipped said false')
    assert(J.IsClosestToDustLocation(ja, atES, true) == false, 'D3 b: armed did not yield')
    -- Negative control: armed does not simply hand everything to the subject.
    assert(J.IsClosestToDustLocation(es, atJA, false) == false, 'D3 c: shipped said true')
    assert(J.IsClosestToDustLocation(es, atJA, true) == false, 'D3 c: armed claimed a spot ' ..
        'that a nearer carrier owns')
    -- Positive control (load-bearing): armed still says TRUE for the carrier
    -- that genuinely is closest, so "armed said false" above cannot be
    -- satisfied by a fix that always says false.
    assert(J.IsClosestToDustLocation(ja, atJA, false) == true, 'D3 d: shipped said false')
    assert(J.IsClosestToDustLocation(ja, atJA, true) == true, 'D3 d: armed refused a spot ' ..
        'it is genuinely closest to')

    -- And the shipped answer is decided by identity, not geometry: the same
    -- bot answers the same way at both locations, 3,938 units apart.
    assert(J.IsClosestToDustLocation(ja, atES, false)
        == J.IsClosestToDustLocation(ja, atJA, false),
        'the shipped answer moved with the location -- it is no longer a no-op scan')
end

tests['[decision D4] radiant: the sole carrier cannot claim its own dust'] = function()
    local J = rf.load(RAD_FX)
    local vs = assert(member_named('vengeful'), 'D4 lost vengeful_spirit')
    local other = assert(member_named('death_prophet'), 'D4 lost death_prophet')
    local slot = vs:FindItemSlot('item_dust')
    assert(slot >= 0 and vs:GetItemSlotType(slot) == ITEM_SLOT_TYPE_MAIN,
        'D4 carrier no longer holds dust in the main inventory')
    -- Nobody else on this radiant roster carries one, so the shipped scan finds
    -- no candidate at all and the function falls off its end: nil, not false.
    for i = 1, 5 do
        local m = GetTeamMember(i)
        if m ~= vs then
            assert(m:FindItemSlot('item_dust') < 0,
                'a second radiant carrier appeared (' .. short(m) .. '); D4 is no longer ' ..
                'the "sole carrier" case')
        end
    end

    local at = vs:GetLocation()
    assert(J.IsClosestToDustLocation(vs, at, false) == nil,
        'shipped should find no candidate at all and return nil')
    assert(J.IsClosestToDustLocation(vs, at, true) == true,
        'armed must let the only carrier on the team claim its own dust')
    assert(J.IsClosestToDustLocation(other, at, false) == nil, 'D4: shipped answered a non-nil')
    assert(J.IsClosestToDustLocation(other, at, true) == false,
        'armed handed the decision to a hero carrying no dust')
end

-- Widening the scan must not widen the QUALIFICATION. A dust in the backpack
-- is not castable, and this frame is the corpus's cleanest statement of it:
-- both dire carriers hold one there and nobody may claim it -- armed included.
-- Without this cell, "the main inventory" is asserted only where the answer is
-- MAIN, and a slot-type reader that answered MAIN for every slot would satisfy
-- every other decision in this file (measured: mutant M12 survived the first
-- pass of the stand for exactly that reason).
tests['[decision D5] a backpack dust is nobody\'s, on either leg'] = function()
    local J = rf.load('tests/fixtures/f_260820_043120_viper_defend_paired.lua',
        'npc_dota_hero_lion')
    assert(GetTeam() == 3, 'D5 must load the dire side of this frame')
    local lion = assert(member_named('lion'), 'D5 lost lion')
    local sb = assert(member_named('spirit_breaker'), 'D5 lost spirit_breaker')
    for _, m in ipairs({ lion, sb }) do
        local slot = m:FindItemSlot('item_dust')
        assert(slot >= 6 and slot <= 8, short(m) .. "'s dust left the backpack (slot " ..
            slot .. ') -- D5 is no longer the backpack case')
        assert(m:GetItemSlotType(slot) == ITEM_SLOT_TYPE_BACKPACK,
            short(m) .. "'s backpack slot does not report BACKPACK")
        assert(m:GetItemSlotType(slot) ~= ITEM_SLOT_TYPE_MAIN,
            'BACKPACK and MAIN are the same value -- the slot-type reader cannot ' ..
            'discriminate and every "main inventory" claim here is vacuous')
    end
    for _, who in ipairs({ lion, sb }) do
        for _, loc in ipairs({ lion:GetLocation(), sb:GetLocation() }) do
            assert(J.IsClosestToDustLocation(who, loc, false) == nil,
                'shipped claimed a backpack dust for ' .. short(who))
            assert(J.IsClosestToDustLocation(who, loc, true) == nil,
                'armed claimed a backpack dust for ' .. short(who) ..
                ' -- the wider scan must not relax the qualification')
        end
    end
end

tests['[not-subset] armed is NOT a subset of shipped -- unlike slotarb'] = function()
    -- The sibling fix could claim "armed can only refuse". This one cannot, and
    -- the honest form of that is a measurement, not a caveat: both directions
    -- occur on real frames. If either count ever reaches zero the header
    -- paragraph about seeding with nil has stopped being true.
    local J = rf.load(DIRE_FX)
    local es = assert(member_named('earthshaker'))
    local ja = assert(member_named('jakiro'))
    local nOpened, nClosed, nCases = 0, 0, 0
    local roster = {}
    for i = 1, 5 do roster[i] = GetTeamMember(i) end
    local spots = { es:GetLocation(), ja:GetLocation() }
    for _, m in ipairs(roster) do spots[#spots + 1] = m:GetLocation() end
    for _, m in ipairs(roster) do
        for _, loc in ipairs(spots) do
            local ship = J.IsClosestToDustLocation(m, loc, false) or false
            local arm = J.IsClosestToDustLocation(m, loc, true) or false
            nCases = nCases + 1
            if arm and not ship then nOpened = nOpened + 1 end
            if ship and not arm then nClosed = nClosed + 1 end
        end
    end
    assert(nCases == 35, 'the battery changed size: ' .. nCases)
    assert(nOpened > 0, 'no shipped-FALSE -> armed-TRUE case on this frame: ' .. nOpened)
    assert(nClosed > 0, 'no shipped-TRUE -> armed-FALSE case on this frame: ' .. nClosed)
end

--============================================================================
-- The gate off is the shipped function, byte for byte.
--============================================================================

-- Transcribed from the pre-fix body (jmz_func.lua, before 2026-09-02). Kept
-- here so "unarmed is unchanged" is a comparison against code, not a promise.
local function shipped_body(J, bot, loc)
    local closest = nil
    local closestDist = 100000
    for _, id in pairs(GetTeamPlayers(GetTeam())) do
        local member = GetTeamMember(id)
        if J.IsValidHero(member)
        and member:GetItemSlotType(member:FindItemSlot('item_dust')) == ITEM_SLOT_TYPE_MAIN
        and member:GetItemInSlot(member:FindItemSlot('item_dust')):IsFullyCastable()
        and not J.IsSuspiciousIllusion(member)
        then
            local dist = GetUnitToLocationDistance(member, loc)
            if dist < closestDist then
                closest = member
                closestDist = dist
            end
        end
    end
    if closest ~= nil then
        return closest == bot
    end
end

tests['[off-candidate] gate off == the transcribed pre-fix body, on both frames'] = function()
    local nCases = 0
    for _, fx in ipairs({ DIRE_FX, RAD_FX }) do
        local J = rf.load(fx)
        local roster, spots = {}, {}
        for i = 1, 5 do
            roster[i] = GetTeamMember(i)
            spots[i] = roster[i]:GetLocation()
        end
        spots[#spots + 1] = Vector(0, 0, 0)
        for _, m in ipairs(roster) do
            for _, loc in ipairs(spots) do
                nCases = nCases + 1
                local a = J.IsClosestToDustLocation(m, loc, false)
                local b = shipped_body(J, m, loc)
                assert(a == b, 'gate off diverged from the shipped body for ' ..
                    short(m) .. ': ' .. tostring(a) .. ' vs ' .. tostring(b))
            end
        end
    end
    assert(nCases == 60, 'the parity battery changed size: ' .. nCases)
end

--============================================================================
-- Structure: one gate, one place, turbo first; and the census behind it.
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

tests['[structure] jmz_func takes the flag and spends it on the ARGUMENT'] = function()
    local code = strip_comments(read('bots/FunLib/jmz_func.lua'))
    assert(not code:find('slotdust'), "'slotdust' must be resolved at the ONE wrapper in " ..
        'ability_item_usage_generic.lua, never read inside jmz_func.lua')
    -- Assert on the function's own slice: jmz_func is 11k lines and a
    -- whole-file find is satisfied by any of them.
    local fn = code:match('function J%.IsClosestToDustLocation.-\nend')
    assert(fn, 'J.IsClosestToDustLocation is gone or reshaped')
    assert(fn:match('function%s+J%.IsClosestToDustLocation%s*%b()'):find('bSlotDust'),
        'the helper does not accept the gate parameter')
    assert(fn:find('GetTeamMember%s*%(%s*nSlot%s*%)'),
        'the fix must be the ARGUMENT, not a new clause around the call')
    assert(fn:find('nSlot%s*=%s*id'), 'unarmed must still pass the player id')
    assert(fn:find('nSlot%s*=%s*i%s'), 'armed must pass the loop index')
    assert(fn:find('for%s+i%s*,%s*id%s+in%s+pairs%s*%(%s*AllyPIDs%s*%)'),
        'the loop must still walk AllyPIDs in the shipped order, now also binding the index')
end

tests['[structure] the wrapper owns the slotdust gate, turbo-first'] = function()
    local code = strip_comments(read('bots/ability_item_usage_generic.lua'))
    local fn = code:match('local function ClosestDustCarrier.-\nend')
    assert(fn, 'the ClosestDustCarrier wrapper is gone or reshaped')
    local iCand = fn:find("J%.IsSoakCandidate%s*%(%s*'slotdust'%s*%)")
    assert(iCand, "the fix must be gated on 'slotdust'; got: " .. fn)
    local iTurbo = fn:find('J%.IsModeTurbo%s*%(%s*%)')
    assert(iTurbo and iTurbo < iCand, 'the fix must be turbo-only, checked first; got: ' .. fn)
    -- The wrapper must actually hand the flag down. A wrapper that computes the
    -- gate and then calls the helper with two arguments reads as gated and is
    -- inert -- the same hole that survived the first mutation pass on slotarb.
    local call = fn:match('J%.IsClosestToDustLocation%s*(%b())')
    assert(call, 'the wrapper no longer calls the helper')
    assert(call:find('IsSoakCandidate'),
        'the wrapper computes the gate but does not pass it to the helper')
end

tests['[structure] every call site in bots/ goes through the one wrapper'] = function()
    -- Not "the wrapper exists": the claim is that no branch can reach the
    -- helper around it. Counted, like the campsel wrapper's own census.
    local p = assert(io.popen(
        "grep -rn 'IsClosestToDustLocation' bots/ --include='*.lua'"))
    local outside, defs = {}, 0
    for line in p:lines() do
        local path, num, text = line:match('^([^:]+):(%d+):(.*)$')
        if path and not text:match('^%s*%-%-') then
            if text:find('function J%.IsClosestToDustLocation') then
                defs = defs + 1
            elseif path ~= 'bots/FunLib/jmz_func.lua' then
                outside[#outside + 1] = path .. ':' .. num
            end
        end
    end
    p:close()
    assert(defs == 1, 'expected exactly one definition, found ' .. defs)
    assert(#outside == 1, 'the helper is named ' .. #outside .. ' times outside jmz_func.lua; ' ..
        'exactly one (the wrapper) is the whole point:\n  ' .. table.concat(outside, '\n  '))
    assert(outside[1]:match('^bots/ability_item_usage_generic%.lua:'),
        'the one call site left jmz_func for somewhere unexpected: ' .. outside[1])

    local code = strip_comments(read('bots/ability_item_usage_generic.lua'))
    local nBranch = 0
    for _ in code:gmatch('ClosestDustCarrier%s*%(%s*bot%s*,') do nBranch = nBranch + 1 end
    assert(nBranch == 3, 'expected the three invis-response branches to call the wrapper, ' ..
        'found ' .. nBranch)
end

tests['[census] one lever: eight pid-shaped call sites stay untouched'] = function()
    -- GH #406 counted ten pid-shaped sites and moved one. This moves the
    -- second, so the ratchet reads eight -- and the eight are all in
    -- bots/FunLib/utils.lua. Moving another is then a deliberate act, not drift.
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
    assert(slotShaped >= 75, 'the slot-shaped majority collapsed: ' .. slotShaped)
    assert(pidShaped == 8, 'expected exactly eight pid-shaped call sites left after this ' ..
        'second lever, found ' .. pidShaped .. ':\n  ' .. table.concat(pidSites, '\n  '))
    local nUtils = 0
    for _, s in ipairs(pidSites) do
        if s:match('bots/FunLib/utils%.lua') then nUtils = nUtils + 1 end
    end
    assert(nUtils == 8, 'the remaining eight are no longer the utils.lua cluster: ' .. nUtils)
    assert(#other == 0, 'a new one-line GetTeamMember argument shape appeared:\n  ' ..
        table.concat(other, '\n  '))
end

--============================================================================
-- Instruments. Both of these are why nothing caught this.
--============================================================================

tests['[instrument I1] the plain mock still cannot see this defect'] = function()
    -- tests/mock/bot_api.lua answers GetTeamMember(n) for any n, so an
    -- out-of-range read there is a hero, not nil. Every unit test written
    -- against that mock is structurally blind to this family; only the real
    -- roster in replay_fixture.lua reports nil. Registered by GH #406 as
    -- backlog 0MOCKHOLE, still the director's call. Delete this when it is
    -- fixed, and say so in the report.
    local mock = require('mock.bot_api')
    mock.install({ bot = mock.MakeHero('npc_dota_hero_axe'), team = 3 })
    assert(GetTeamMember(9) ~= nil,
        'the bot_api mock now refuses an out-of-range slot -- the blind spot is closed')
end

tests['[instrument I2] the fixture item namespace is not the engine one'] = function()
    -- The dumper writes snakeFromClass(GetClassName(), "CDOTA_Item_") -- an
    -- ENTITY CLASS name -- and replay_fixture prefixed it with 'item_' as if it
    -- were the name FindItemSlot takes. Where the two spellings differ, every
    -- inventory predicate in bots/ that names the item finds NOTHING on every
    -- fixture and the test reads as a clean pass. Dust is the case this fix
    -- needed and the only entry with in-repo evidence for both spellings.
    assert(rf.CLASS_TO_ITEM.dustof_appearance == 'item_dust',
        'the one verified class->item mapping is gone')
    local n = 0
    for _ in pairs(rf.CLASS_TO_ITEM) do n = n + 1 end
    assert(n == 1, 'the verified map grew to ' .. n .. ' entries -- update this ratchet and ' ..
        'the note in replay_fixture.lua with the evidence for each new one')

    -- The ceiling on the remaining damage: fixture item names that cannot be
    -- resolved against bots/ at all. That set mixes true divergences with items
    -- the bot code simply never mentions, so it is not a bug list -- but it
    -- must not grow silently.
    local names = {}
    local p = assert(io.popen("grep -rho \"items = {[^}]*}\" tests/fixtures/"))
    for line in p:lines() do
        -- `[^']*`, not `[^']+`: an empty slot is written '' and a one-or-more
        -- pattern skips past its opening quote, then matches the SEPARATOR
        -- between two real names as if it were one (', '). That mis-parse read
        -- 115 where there are 114 -- a fake name nobody would look at twice.
        for it in line:gmatch("'([^']*)'") do
            if it ~= '' then names[it] = true end
        end
    end
    p:close()
    local q = assert(io.popen("grep -rho --include='*.lua' 'item_[a-z0-9_]*' bots/"))
    local have = {}
    for w in q:lines() do have[w] = true end
    q:close()
    local nNames, nMissing = 0, 0
    for it in pairs(names) do
        nNames = nNames + 1
        if not have['item_' .. it] and rf.CLASS_TO_ITEM[it] == nil then
            nMissing = nMissing + 1
        end
    end
    assert(nNames == 114, 'the fixture item vocabulary changed size: ' .. nNames)
    assert(nMissing == 23, 'unresolvable fixture item names moved from 23 to ' .. nMissing ..
        ' -- either a fixture arrived with new items, or the namespace hole widened')
end

return tests

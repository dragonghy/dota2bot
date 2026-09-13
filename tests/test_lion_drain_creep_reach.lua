-- [hero] `liondrainreach` -- X.ConsiderE's low-mana creep branch is the one
-- branch in that function with no distance term at all, and the gated reach
-- term that gives it one.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- X.ConsiderE computes its ring on its first working line:
--
--     local nCastRange = abilityE:GetCastRange() + aetherRange     (:1338)
--
-- and every other branch in the function measures against it -- the 团战 loop
-- and the 打架 branch both test `J.IsInRange( ..., nCastRange )`, and the
-- illusion loop deliberately opens to `nCastRange + 300`.  That last one is the
-- reason this is a scope defect rather than an oversight: the author widened a
-- ring ON PURPOSE somewhere else in the same function, so relating a ring to
-- cast range was in hand.
--
-- The low-mana creep branch does not do it.  It reads
-- `bot:GetNearbyCreeps( 1600, true )` and accepts on mana alone
-- (`GetMana() > nManaDrain * 0.8 or GetMana() > 349`), then returns
-- `BOT_ACTION_DESIRE_HIGH, nCreep` with nothing between the list and the return
-- that mentions distance.
--
-- SIZE OF THE GAP, off the KV snapshot, not guessed: lion_mana_drain /
-- AbilityCastRange is a flat 850 at every rank.  1600 against 850 is 750 units;
-- against 1100 (aether lens) it is still 500.  The ability's own
-- `break_distance` is 1100, so the branch can pick a creep from further away
-- than the distance at which the channel it is bidding for would break.
--
-- A cast order on a unit outside cast range is a MOVE order first, and the bid
-- is BOT_ACTION_DESIRE_HIGH, so the walk outranks whatever mode Lion was in.
--
-- ===========================================================================
-- §0.1  WHAT THIS FILE CAN AND CANNOT BUY
-- ===========================================================================
--
-- It CANNOT buy an end-to-end reading, and the reason is structural rather than
-- unlucky: the branch needs enemy creeps with a real mana pool, and this corpus
-- answers an EMPTY table for every creep query on every instant this stream has
-- measured (CORPUS_HAS_NO_NONHERO_UNITS_20260912, first recorded against
-- `cmcreepclock`).  §4 DRIVES that rather than asserting it, and it is a
-- one-way tripwire: the day a creep-bearing frame lands, §4 goes red and says
-- so instead of quietly staying green on a claim that has expired.
--
-- It CAN buy the RING reading -- how far apart 1600 and nCastRange actually
-- are on real Lion instants, measured with the real handles the frames carry
-- (§3).  ⚠️ That is a reading ABOUT THE RING, not about the branch firing.  It
-- says nothing about how often a mana-bearing creep sits in the band.
--
-- ⛔ NO ONE MAY REPORT A NUMBER OF BIDS THIS LEVER REMOVES.  Evidence is
-- requested as iterations/queue.json `hero-79` (zero EC2, archive-only).
--
-- ===========================================================================
-- §0.2  DIRECTION
-- ===========================================================================
--
-- NARROWING, one-way by construction: the shipped answer is computed by the
-- caller and handed in as `bShippedInReach`, and every path returns it
-- unchanged except the armed one, which can only turn a true into a false.
-- §2 asserts that rather than arguing it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CAND   = 'liondrainreach'
local HELPER = 'lion_IsDrainCreepInReach'
local UNIT   = 'npc_dota_hero_lion'
local DRAIN  = 'lion_mana_drain'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local SEARCH_RING  = 1600   -- the branch's GetNearbyCreeps radius
local KV_CAST      = 850    -- lion_mana_drain / AbilityCastRange, flat
local AETHER_BONUS = 250
local BREAK_DIST   = 1100   -- lion_mana_drain / break_distance

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The body of one top-level `function X.<name>(`, cut at the matching
--- top-level `\nend\n`.  Prose anchors inside nested blocks are how two files
--- in this tree stopped reading three lines short of the thing they guarded
--- (hero charter -167); this cuts on the function, not on a needle.
local function fn_body(src, name)
    local i = assert(src:find('\nfunction%s+X%.' .. name .. '%s*%('), name .. ' not found in ' .. SRC)
    local rest = src:sub(i + 1)
    return rest:sub(1, assert(rest:find('\nend\n'), 'no terminating end for ' .. name))
end

local function corpus_paths()
    local out, seen = {}, {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') and not seen[name] then
                seen[name] = true
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

local function lion_alive(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == UNIT and u.alive ~= false then return true end
    end
    return false
end

--- The first frame in the corpus that actually carries a live Lion.  `the first
--- path in the corpus` is not the same thing, and the first draft of §2 used it:
--- rf.load then refuses with "fixture subject not in units", which reads like a
--- broken harness rather than a badly chosen frame.
local function first_lion_frame()
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then return path end
    end
    error('no live-Lion frame in the corpus -- every section of this file is vacuous')
end

--- Load a frame with Lion as the subject and arm exactly the ids named in `tOn`.
local function frame(path, tOn)
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return tOn[id] == true end
    J.IsModeTurbo = function() return true end
    local X = rf.load_hero('lion')
    return J, bot, X
end

--- The ring X.ConsiderE really computes on this frame: GetCastRange() off the
--- live handle plus the aether-lens bonus X.SkillsComplement would have set.
--- The slot bound is the BRANCH's bound -- J.IsItemAvailable hands back a handle
--- only for the six EQUIPPED slots (0-5), so a backpacked lens grants nothing
--- and a meter that asked only `>= 0` would over-state the ring on exactly the
--- frames it was added to measure (same defect as test_lion_q_kill_reach.lua).
local function frame_ring(bot, hE)
    local nRing = (hE ~= nil and hE:GetCastRange() or KV_CAST)
    if bot.FindItemSlot ~= nil then
        local nSlot = bot:FindItemSlot('item_aether_lens')
        if nSlot ~= nil and nSlot >= 0 and nSlot <= 5 then nRing = nRing + AETHER_BONUS end
    end
    return nRing
end

-- ---------------------------------------------------------------- section 1 --
-- The defect is still shaped the way the lever assumes.

tests['§1.1 the creep branch searches 1600 and the function computes nCastRange'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderE')
    assert(body:find('local%s+nCastRange%s*=%s*abilityE:GetCastRange%(%)%s*%+%s*aetherRange'),
        'X.ConsiderE no longer computes nCastRange from the ability -- the lever is '
        .. 'passing a number that is not the branch\'s own ring')
    assert(body:find('bot:GetNearbyCreeps%(%s*1600%s*,%s*true%s*%)'),
        'the creep branch no longer searches 1600 -- re-derive the gap before trusting §3')
end

tests['§1.2 the OTHER branches do relate their ring to nCastRange'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderE')
    -- This is what makes it a scope defect rather than an oversight: the same
    -- function measures against nCastRange elsewhere, and widens on purpose once.
    local n = select(2, body:gsub('nCastRange', ''))
    assert(n >= 5, 'nCastRange appears only ' .. n .. ' times in X.ConsiderE (was >= 5); '
        .. 'the "every other branch already uses it" claim in the helper header is stale')
    assert(body:find('nCastRange%s*%+%s*300'),
        'the illusion branch no longer widens deliberately -- the header cites that as '
        .. 'evidence the author related rings to cast range on purpose')
end

tests['§1.3 the gated conjunct sits on the creep accept test, and nowhere else'] = function()
    local src = read_file(SRC)
    local body = fn_body(src, 'ConsiderE')
    assert(body:find('X%.' .. HELPER .. '%(%s*bot%s*,%s*nCreep%s*,%s*nCastRange%s*,%s*true%s*%)'),
        'the creep accept test no longer calls ' .. HELPER .. ' with (bot, nCreep, nCastRange, true)')
    -- Count CALL sites only.  `function X.<name>(` matches the same needle, and
    -- the first draft of this assertion counted the definition as a call site.
    local nAll = select(2, src:gsub('X%.' .. HELPER .. '%s*%(', ''))
    local nDef = select(2, src:gsub('function%s+X%.' .. HELPER .. '%s*%(', ''))
    assert(nDef == 1, 'expected exactly one definition of ' .. HELPER .. ', got ' .. nDef)
    assert(nAll - nDef == 1, 'the helper is called ' .. (nAll - nDef) .. ' times (want exactly 1); '
        .. 'a second call site would put this id on a branch its header does not describe')
end

tests['§1.4 the gate is read in exactly one place and names only its own id'] = function()
    local body = fn_body(read_file(SRC), HELPER)
    local nGate = select(2, body:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", ''))
    assert(nGate == 1, 'expected exactly one IsSoakCandidate(\'' .. CAND .. '\') in the helper, got ' .. nGate)
    assert(body:find('J%.IsModeTurbo%(%)'), 'the helper is no longer turbo-only')
    -- The pullcad trap (AGENTS.md): a gate whose condition names a SIBLING id is
    -- frozen FALSE the day that sibling is promoted, and every wiring checker
    -- still calls it WIRED.
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        assert(id == CAND, 'the helper\'s gate names a sibling id (' .. id .. ') -- pullcad trap')
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The helper's contract.  Direction is asserted, not argued.

tests['§2.1 gate OFF is byte-for-byte the shipped answer, in both directions'] = function()
    local J, bot, X = frame(first_lion_frame(), {})
    assert(X[HELPER](bot, bot, 850, true) == true,
        'gate off must return the shipped true unchanged')
    assert(X[HELPER](bot, bot, 850, false) == false,
        'gate off must return the shipped false unchanged')
    assert(J ~= nil)
end

tests['§2.2 armed, a shipped FALSE is still false (one-way)'] = function()
    local _, bot, X = frame(first_lion_frame(), { [CAND] = true })
    assert(X[HELPER](bot, bot, 0, false) == false,
        'armed must never turn a shipped false into a true -- that would make this '
        .. 'lever ADD a cast, and every reading of it is written as a subtraction')
end

tests['§2.3 armed with an unreadable argument falls back to shipped'] = function()
    local _, bot, X = frame(first_lion_frame(), { [CAND] = true })
    assert(X[HELPER](nil, bot, 850, true) == true, 'nil bot must fall back to shipped')
    assert(X[HELPER](bot, nil, 850, true) == true, 'nil creep must fall back to shipped')
    assert(X[HELPER](bot, bot, nil, true) == true, 'nil range must fall back to shipped')
    assert(X[HELPER](bot, bot, '850', true) == true, 'a string range must fall back to shipped')
end

tests['§2.4 armed, the answer is the distance test and it cuts at nCastRange'] = function()
    -- Same handle for bot and creep => distance 0 => inside any positive ring;
    -- a zero ring => outside.  Two sides of the same inequality on real J.
    local _, bot, X = frame(first_lion_frame(), { [CAND] = true })
    assert(X[HELPER](bot, bot, KV_CAST, true) == true, 'distance 0 must be inside a ring of 850')
    assert(X[HELPER](bot, bot, -1, true) == false, 'nothing is inside a negative ring')
end

-- ---------------------------------------------------------------- section 3 --
-- The RING reading, on real frames.  A reading about the ring, NOT about the
-- branch firing.

tests['§3.1 every live-Lion frame has a Mana Drain handle whose cast range is the KV 850'] = function()
    local nSeen, nRanked = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then
            local _, bot = rf.load(path, UNIT)
            local hE = bot:GetAbilityByName(DRAIN)
            if hE ~= nil then
                nSeen = nSeen + 1
                if hE:GetLevel() > 0 then nRanked = nRanked + 1 end
                assert(hE:GetCastRange() == KV_CAST,
                    path .. ': lion_mana_drain cast range reads ' .. tostring(hE:GetCastRange())
                        .. ', not the flat ' .. KV_CAST .. ' this file measures against')
            end
        end
    end
    assert(nSeen > 0, 'no live-Lion frame carries a lion_mana_drain handle -- §3 is vacuous')
    -- Registered, not asserted as a rate: how many of those are RANKED is a
    -- property of which instants earlier rounds chose to cut, not of the game.
    assert(nRanked >= 0)
end

tests['§3.2 the search ring exceeds both the cast range and the channel break distance'] = function()
    -- Arithmetic, stated once, so a KV change reddens here instead of silently
    -- shrinking the defect the header describes.
    assert(SEARCH_RING > KV_CAST, 'the 1600 search no longer exceeds the 850 reach')
    assert(SEARCH_RING - KV_CAST == 750, 'the bare gap moved from 750')
    assert(SEARCH_RING - (KV_CAST + AETHER_BONUS) == 500, 'the lens gap moved from 500')
    assert(SEARCH_RING > BREAK_DIST,
        'the search ring no longer exceeds break_distance -- the header\'s sharpest '
        .. 'sentence ("further away than the channel would break") is stale')
end

tests['§3.3 on real frames the band between nCastRange and 1600 is non-empty'] = function()
    -- Measured with the handles the frames actually carry.  There are no creeps
    -- (§4), so this counts the band using the hero handles present: it answers
    -- "is the band a real region of the map on these instants", which is the
    -- only ring question a creepless corpus can answer.
    local nFrames, nInBand = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then
            local _, bot = rf.load(path, UNIT)
            local hE = bot:GetAbilityByName(DRAIN)
            local nRing = frame_ring(bot, hE)
            nFrames = nFrames + 1
            for _, h in ipairs(bot:GetNearbyHeroes(SEARCH_RING, true, BOT_MODE_NONE) or {}) do
                local d = GetUnitToUnitDistance(bot, h)
                if d > nRing and d <= SEARCH_RING then nInBand = nInBand + 1 end
            end
        end
    end
    assert(nFrames > 0, 'no live-Lion frame -- §3.3 is vacuous')
    assert(nInBand > 0, 'not one unit anywhere in the (nCastRange, 1600] band across '
        .. nFrames .. ' live-Lion frames; the band may be unreachable and the lever '
        .. 'would then be inert for a reason this file has not written down')
end

-- ---------------------------------------------------------------- section 4 --
-- The end-to-end zero, DRIVEN, and one-way.

tests['§4 the corpus holds no creeps at all -- a tripwire, not a conclusion'] = function()
    local nFrames, nCreeps = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if lion_alive(path) then
            local _, bot = rf.load(path, UNIT)
            nFrames = nFrames + 1
            nCreeps = nCreeps + #(bot:GetNearbyCreeps(SEARCH_RING, true) or {})
        end
    end
    assert(nFrames > 0, 'no live-Lion frame -- §4 is vacuous')
    assert(nCreeps == 0, 'THIS IS THE TRIPWIRE FIRING, NOT A REGRESSION: the corpus now '
        .. 'holds ' .. nCreeps .. ' enemy creep handle(s) on live-Lion frames, where it held '
        .. '0 when liondrainreach was written (CORPUS_HAS_NO_NONHERO_UNITS_20260912). The '
        .. 'end-to-end domain of this lever can now be MEASURED. Do that, write the number '
        .. 'into the helper header, and replace this assertion with it.')
end

-- ---------------------------------------------------------------- section 5 --
-- Registered, not fixed: the accept test's second disjunct.

tests['§5 the 349 disjunct is subsumed at ranks 1-3 and load-bearing at rank 4'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderE')
    assert(body:find('nCreep:GetMana%(%)%s*>%s*nManaDrain%s*%*%s*0%.8'),
        'the first disjunct moved')
    assert(body:find('nCreep:GetMana%(%)%s*>%s*349'), 'the 349 disjunct moved')

    -- The arithmetic, from the KV snapshot rather than from the claim.  The
    -- first draft of the helper header called this disjunct DEAD; it is dead at
    -- three ranks out of four and the fourth is the one that matters.
    local shapes = dofile('tests/mock/special_value_shapes.lua').SHAPES
    local kv = shapes['lion'] and shapes['lion'][DRAIN]
    assert(kv ~= nil, 'no KV shape for ' .. DRAIN)
    local nDuration = tonumber(kv['duration'].base)
    assert(nDuration ~= nil, 'lion_mana_drain duration is no longer a single flat number')
    local tPer = {}
    for w in tostring(kv['mana_per_second'].base):gmatch('%S+') do tPer[#tPer + 1] = tonumber(w) end
    assert(#tPer == 4, 'mana_per_second is no longer four ranks: ' .. #tPer)

    local nSubsumed, nLive = 0, 0
    for _, per in ipairs(tPer) do
        if per * nDuration * 0.8 > 349 then nLive = nLive + 1 else nSubsumed = nSubsumed + 1 end
    end
    assert(nSubsumed == 3 and nLive == 1,
        'the 349 disjunct changed character: ' .. nSubsumed .. ' subsumed / ' .. nLive
            .. ' load-bearing (was 3/1). The helper header says 3/1 -- fix the header, '
            .. 'do not relax this.')
end

return tests

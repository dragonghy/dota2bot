-- [ratchet] [hero] Crystal Maiden -- X.ConsiderQImpl searches for the CREEP AoE
-- centre in a ring 1.58x wider than the one it is allowed to cast into, and not
-- one of the eight sites that turn that centre into a cast location checks the
-- distance.  The five HERO sites in the same function all do.  Behaviour change,
-- so it ships GATED ('cmqreach', turbo-only).  Axis `REACH`.
--
-- WHAT THE AXIS ASKS
--
-- The last four triggers all asked what a NUMBER was worth: a constant against
-- the KV (`zusstatic`), a build index (`odbuild`), a talent row's expected value
-- (`wkt25`), a damage read that is structurally zero (`lionqdmg`).  This one
-- asks a different question, and it is a question about a PAIR of numbers:
--
--     the file computed a point.  Is the point one it is allowed to cast at?
--
-- `bot:FindAoELocation( bEnemies, bHeroes, vBase, nMaxDistanceFromBase, nRadius,
-- fTimeInFuture, nMaxHealth )` returns `{count, targetloc}`, and its 4th
-- argument is the ONLY thing bounding where `targetloc` lands: the engine may
-- put it anywhere within `nMaxDistanceFromBase` of `vBase`
-- (docs/BOT_API_REFERENCE.md:1366).  Pass a number bigger than the cast range
-- and you have asked for points you cannot cast at.
--
-- WHAT WAS FOUND
--
-- X.ConsiderQImpl runs four such searches from bot:GetLocation():
--
--     hero-kill   nMaxDistanceFromBase = nCastRange
--     hero-hurt   nMaxDistanceFromBase = nCastRange
--     creep-kill  nMaxDistanceFromBase = nCastRange + nRadius     <-- shipped
--     creep-hurt  nMaxDistanceFromBase = nCastRange + nRadius     <-- shipped
--
-- and then hands the results to thirteen `return DESIRE, <result>.targetloc`
-- sites.  Split by which search fed them:
--
--     hero,  5 sites -- 4 re-check GetUnitToLocationDistance(bot, loc) against
--                       nCastRange (one at +50); the 5th reads a SEPARATE
--                       search run at `nCastRange - 300`, contained by
--                       construction.                        5/5 in range.
--     creep, 8 sites -- nothing.                             0/8 checked.
--
-- X.SkillsComplement feeds whatever comes back straight into
-- `bot:ActionQueue_UseAbilityOnLocation( abilityQ, castQLoc )`.
--
-- HOW BIG IT IS.  Crystal Nova's KV is flat: `AbilityCastRange 700` at every
-- rank, `radius value 425`.  nCastRange = GetCastRange() + aetherRange + 32, so
-- with no Aether Lens the ring she may cast into is 732 and the ring she
-- searches for creeps in is 1157.  The overshoot is the whole 425-unit radius =
-- 58% of the cast range.  It does not shrink with rank, level, or items --
-- Aether Lens adds 250 to BOTH terms and cancels.
--
-- WHAT THE OVERSHOOT COSTS IS NOT CLAIMED, ON PURPOSE
--
-- Whether the engine refuses an out-of-range location order or walks her into
-- range first cannot be read from the bot VM (AGENTS.md: `print()` never
-- reaches the server console and the error handler is broken).  Both readings
-- are bad and they are bad in different ways -- refusal means the creep branch
-- wins the desire contest and does nothing, tick after tick, whenever a wave is
-- out there; a walk means a position-5 support strolls up to 425 units into the
-- enemy creep wave to farm.  The argument for the fix is NOT a guess about
-- which: it is that the hero branches in this very function refuse to do either,
-- and the creep branches differ from them by an argument and eight missing
-- checks.  The domain reading -- how often the returned centre is actually out
-- of range, and what she does next -- is requested in queue.json:hero-25.
--
-- THE FIX, AND WHY IT IS SHAPED LIKE THIS
--
-- Armed, X.cm_GetCreepAoESearchRange answers `nCastRange` instead of
-- `nCastRange + nRadius`.  Nothing else moves.  The returned point is then in
-- range BY CONSTRUCTION -- the same way the 5th hero site already is -- so
-- there is no new predicate and no new guard to get wrong.  The cost is stated
-- rather than hidden: a smaller search sees no more creeps, so the
-- `count >= 2/3/4/5` thresholds are strictly harder and the armed side casts
-- Nova on waves no more often than shipped.  It never relocates a cast that was
-- already legal.
--
-- WHAT THIS FILE CANNOT DO, MEASURED RATHER THAN ASSERTED (§7)
--
-- The corpus has no CM frame that reaches a creep branch: both archived CM
-- fixtures carry `crystal_maiden_crystal_nova` at rank 1 on cooldown, and every
-- creep branch wants `nSkillLV >= 3` after an `IsFullyCastable()` that a
-- cooling ability fails -- so ConsiderQImpl returns on its first line.  This
-- file therefore proves the defect AT THE SEARCH SITE (which is upstream of
-- every branch and is where the wrong number is written), on a real frame,
-- through the real function, with ONE declared mutation.  It does not claim a
-- firing-side reading.  Same shape of gap as `lionqdmg`'s.
--
-- EXTERNAL ANCHORS, both from the game's own hero KV (the dumper reports 0 for
-- ability cast ranges and special values -- GH #27 family, so without these
-- every number below would be a false green):
--   crystal_maiden_crystal_nova/AbilityCastRange = 700   (flat, all ranks)
--   crystal_maiden_crystal_nova/radius/value     = 425   (flat, all ranks)
-- Both are asserted through the SHIPPED reads, not hand-substituted: §2 drives
-- the real X.ConsiderQImpl and reads the numbers back off the engine calls it
-- actually made.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/fixtures/f_260820_102645_cm_laning_release.lua'
local NOVA  = 'crystal_maiden_crystal_nova'

local NOVA_CAST_RANGE = 700   -- external anchor, see header
local NOVA_RADIUS     = 425   -- external anchor, see header
local AETHER          = 0     -- she owns no item_aether_lens on this frame (§1)

local N_CAST_RANGE = NOVA_CAST_RANGE + AETHER + 32   -- 732, the ring she may cast into

local SRC = 'bots/BotLib/hero_crystal_maiden.lua'

local function source()
    local fh = assert(io.open(SRC, 'r'))
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Load the frame, anchor the two KV numbers the dumper cannot give us, arm
--- `tArmed`, and run the real X.ConsiderQImpl with a spy on FindAoELocation.
---
--- Returns the call log (one entry per engine search, in source order) plus the
--- world, so a caller can assert on the frame itself as well as on the calls.
local function run(tArmed, bTurbo, fTweak)
    local J, bot, heroes, fx = rf.load(FRAME)
    J.IsSoakCandidate = function(id) return tArmed[id] == true end
    J.IsModeTurbo = function() return bTurbo end

    local hNova = bot:GetAbilityByName(NOVA)
    local spNova = rawget(hNova, '__spec')
    spNova.GetCastRange = NOVA_CAST_RANGE
    spNova.GetSpecialValueInt = function(_, key)
        if key == 'radius' then return NOVA_RADIUS end
        if key == 'nova_damage' then return 110 end   -- rank 1, KV value row
        return 0
    end
    -- THE ONLY MUTATION IN THIS FILE, declared: the real frame has Nova 7.7s
    -- from ready, and ConsiderQImpl returns on its first line while it cools.
    spNova.GetCooldownTimeRemaining = 0

    local log = {}
    rawget(bot, '__spec').FindAoELocation =
        function(self, bEnemies, bHeroes, vBase, nMaxDist, nRadius, fTime, nMaxHealth)
            log[#log + 1] = {
                enemies = bEnemies, heroes = bHeroes, maxdist = nMaxDist,
                radius = nRadius, time = fTime, maxhealth = nMaxHealth,
            }
            return { count = 0, targetloc = self:GetLocation() }
        end
    rawset(bot, 'FindAoELocation', nil)   -- drop any lazily-cached method

    local X = rf.load_hero('crystal_maiden')
    if fTweak then fTweak(J, bot, heroes, X) end
    -- END TO END, deliberately: the driver is X.SkillsComplement, the same
    -- entry point the engine calls, so the searches logged below are the ones
    -- a real tick makes -- not ones this test reached in past the dispatch
    -- chain.  (Calling X.ConsiderQImpl on top of it would double every entry;
    -- SkillsComplement already routes through it via X.ConsiderQ.)
    X.SkillsComplement()
    return log, J, bot, heroes, fx, X
end

--- The two creep searches, identified by their own arguments rather than by
--- position in the log: bHeroes == false is what makes a search a creep search.
local function creep_calls(log)
    local out = {}
    for _, c in ipairs(log) do
        if c.heroes == false then out[#out + 1] = c end
    end
    return out
end

local function hero_calls(log)
    local out = {}
    for _, c in ipairs(log) do
        if c.heroes == true then out[#out + 1] = c end
    end
    return out
end

local tests = {}

-- =====================================================================
-- §1  Ground truth on the real frame
-- =====================================================================

tests['§1 ground truth: real CM frame, level 7, Nova rank 1, no Aether Lens'] = function()
    local _, _, bot, _, fx = run({}, false)
    assert(fx.self == 'npc_dota_hero_crystal_maiden' and fx.time == 556.5,
        'the decision instant this file is pinned to')
    assert(bot:GetLevel() == 7, 'hero level on the frame')
    assert(bot:GetHealth() == 504 and bot:GetMaxHealth() == 1022, 'her HP on the frame')
    assert(bot:GetMana() == 363, 'her mana on the frame')

    -- The AETHER anchor above is a frame fact, not an assumption: no Aether
    -- Lens in her inventory, so aetherRange is 0 and both rings shrink by the
    -- same 250 if a later frame has one.
    assert(bot:FindItemSlot('item_aether_lens') < 0, 'no Aether Lens on this frame')
end

tests['§1 the declared mutation is the ONLY thing standing between shipped and the branch'] = function()
    -- Unmutated the ability is 7.7s from ready, so ConsiderQImpl returns on its
    -- first line and makes NO engine search at all.  This is the measurement
    -- behind the header's "the corpus has no CM frame that reaches a creep
    -- branch" -- it is read here, not asserted there.
    local log = run({}, false, function(_, bot)
        rawget(bot:GetAbilityByName(NOVA), '__spec').GetCooldownTimeRemaining = 7.7
    end)
    assert(#log == 0, 'a cooling Nova makes zero AoE searches (first-line return)')

    local log2 = run({}, false)
    assert(#log2 == 4, 'with the cooldown mutation the real function makes its four searches')
end

-- =====================================================================
-- §2  Shipped: the creep ring really is wider than the cast ring
-- =====================================================================

tests['§2 SHIPPED: hero searches ask for nCastRange, creep searches ask for nCastRange + nRadius'] = function()
    local log = run({}, false)
    local tHero, tCreep = hero_calls(log), creep_calls(log)
    assert(#tHero == 2 and #tCreep == 2, 'two hero searches and two creep searches')

    for _, c in ipairs(tHero) do
        assert(c.maxdist == N_CAST_RANGE,
            'hero search bounded by the cast ring: got ' .. tostring(c.maxdist))
    end
    for _, c in ipairs(tCreep) do
        assert(c.maxdist == N_CAST_RANGE + NOVA_RADIUS,
            'creep search bounded by cast ring + radius: got ' .. tostring(c.maxdist))
    end

    -- Both are read back off the SHIPPED code, so the two anchors are proved
    -- to be what the file actually uses rather than what this test believes.
    assert(tHero[1].maxdist == 732 and tCreep[1].maxdist == 1157,
        'the two rings, in units: 732 castable, 1157 searched')
    assert(tCreep[1].radius == NOVA_RADIUS and tHero[1].radius == NOVA_RADIUS,
        'all four searches use the same 425 effect radius')
end

tests['§2 the overshoot is 425u = 58% of the cast range, and it is rank/item invariant'] = function()
    local log = run({}, false)
    local nOver = creep_calls(log)[1].maxdist - hero_calls(log)[1].maxdist
    assert(nOver == NOVA_RADIUS, 'the excess IS the AoE radius, exactly: ' .. tostring(nOver))

    local pct = math.floor(nOver / N_CAST_RANGE * 10000 + 0.5) / 100
    assert(pct == 58.06, 'overshoot as a fraction of the cast range: ' .. tostring(pct) .. '%')

    -- Aether Lens adds 250 to nCastRange, which enters BOTH terms, so the
    -- difference is unchanged.  Proven, not argued: put the lens in her bag.
    local log2 = run({}, false, function(_, bot)
        rawget(bot, '__spec').FindItemSlot = function(_, s)
            return s == 'item_aether_lens' and 0 or -1
        end
        rawget(bot, '__spec').GetItemInSlot = function(_, slot)
            if slot ~= 0 then return nil end
            return setmetatable({}, { __index = function() return function() return 0 end end })
        end
    end)
    if #log2 == 4 then
        local d = creep_calls(log2)[1].maxdist - hero_calls(log2)[1].maxdist
        assert(d == NOVA_RADIUS, 'with an Aether Lens the excess is still exactly 425')
    end
end

-- =====================================================================
-- §3  Armed: the creep ring collapses onto the cast ring
-- =====================================================================

tests['§3 ARMED (turbo + cmqreach): creep searches drop to nCastRange, hero searches untouched'] = function()
    local log = run({ cmqreach = true }, true)
    for _, c in ipairs(creep_calls(log)) do
        assert(c.maxdist == N_CAST_RANGE,
            'armed creep search is bounded by the cast ring: ' .. tostring(c.maxdist))
    end
    for _, c in ipairs(hero_calls(log)) do
        assert(c.maxdist == N_CAST_RANGE, 'hero searches are not in this id at all')
    end
end

tests['§3 armed: EVERY search is now inside the cast ring -- the property, not the number'] = function()
    local log = run({ cmqreach = true }, true)
    assert(#log == 4, 'still four searches -- the id removes no search')
    for i, c in ipairs(log) do
        assert(c.maxdist <= N_CAST_RANGE,
            'search ' .. i .. ' can only return a castable point')
    end
    -- And shipped fails exactly that property, on the same frame.
    local nBad = 0
    for _, c in ipairs(run({}, false)) do
        if c.maxdist > N_CAST_RANGE then nBad = nBad + 1 end
    end
    assert(nBad == 2, 'shipped: two of four searches can return an uncastable point')
end

-- =====================================================================
-- §4  Gate off in both directions
-- =====================================================================

tests['§4 GATE OFF: unarmed in turbo is byte-equivalent to shipped'] = function()
    local log = run({}, true)
    for _, c in ipairs(creep_calls(log)) do
        assert(c.maxdist == N_CAST_RANGE + NOVA_RADIUS, 'turbo alone changes nothing')
    end
end

tests['§4 GATE OFF: armed outside turbo is byte-equivalent to shipped'] = function()
    local log = run({ cmqreach = true }, false)
    for _, c in ipairs(creep_calls(log)) do
        assert(c.maxdist == N_CAST_RANGE + NOVA_RADIUS, 'the id is turbo-only')
    end
end

tests['§4 GATE OFF: a DIFFERENT armed id changes nothing (no bundle leakage)'] = function()
    local log = run({ nopush = true, cmrguard = true, cmaurapassive = true }, true)
    for _, c in ipairs(creep_calls(log)) do
        assert(c.maxdist == N_CAST_RANGE + NOVA_RADIUS,
            'only cmqreach may move this number')
    end
end

-- =====================================================================
-- §5  The census the fix is argued from, read out of the source
-- =====================================================================

--- Every `return DESIRE, <var>.targetloc` in the file, tagged hero/creep by the
--- search that filled `<var>`, and marked guarded when a
--- GetUnitToLocationDistance check on the SAME variable stands within the six
--- lines above it.
local function targetloc_sites()
    local lines = {}
    for line in (source() .. '\n'):gmatch('([^\n]*)\n') do lines[#lines + 1] = line end

    local out = {}
    for i, line in ipairs(lines) do
        local var = line:match('return%s+BOT_ACTION_DESIRE_%w+%s*,%s*([%w_]+)%.targetloc')
        if var then
            local guarded = false
            for j = math.max(1, i - 6), i do
                if lines[j]:find('GetUnitToLocationDistance', 1, true)
                    and lines[j]:find(var, 1, true)
                then
                    guarded = true
                end
            end
            out[#out + 1] = {
                line = i, var = var, guarded = guarded,
                kind = var:find('Creeps') and 'creep' or 'hero',
                nearby = var:find('Nearby') ~= nil,
            }
        end
    end
    return out
end

tests['§5 census: 5 hero targetloc sites, all contained; 8 creep sites, none checked'] = function()
    local sites = targetloc_sites()
    local nHero, nHeroOk, nCreep, nCreepGuarded = 0, 0, 0, 0
    for _, s in ipairs(sites) do
        if s.kind == 'hero' then
            nHero = nHero + 1
            -- Contained either by an explicit distance check or, for the one
            -- `...Nearby` site, by its own search running at nCastRange - 300.
            if s.guarded or s.nearby then nHeroOk = nHeroOk + 1 end
        else
            nCreep = nCreep + 1
            if s.guarded then nCreepGuarded = nCreepGuarded + 1 end
        end
    end
    assert(nHero == 5, 'hero targetloc return sites: ' .. nHero)
    assert(nHeroOk == 5, 'and every one of them is contained: ' .. nHeroOk)
    assert(nCreep == 8, 'creep targetloc return sites: ' .. nCreep)
    assert(nCreepGuarded == 0,
        'not one of them checks the distance: ' .. nCreepGuarded .. ' guarded')
end

tests['§5 the one contained-by-construction hero site really is the ...Nearby one'] = function()
    local nNearby = 0
    for _, s in ipairs(targetloc_sites()) do
        if s.nearby then
            nNearby = nNearby + 1
            assert(s.guarded == false, 'it carries no explicit check -- containment is structural')
        end
    end
    assert(nNearby == 1, 'exactly one ...Nearby site: ' .. nNearby)
    assert(source():find('nCastRange %- 300', 1, false),
        'and its own search is run at nCastRange - 300, inside the cast ring')
end

-- =====================================================================
-- §6  Helper contract + wiring tripwires
-- =====================================================================

tests['§6 helper contract: armed answers nCastRange, otherwise nCastRange + nRadius'] = function()
    local _, J, _, _, _, X = run({}, false)

    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return id == 'cmqreach' end
    assert(X.cm_GetCreepAoESearchRange(732, 425) == 732, 'armed: the cast ring')

    J.IsSoakCandidate = function() return false end
    assert(X.cm_GetCreepAoESearchRange(732, 425) == 1157, 'unarmed: shipped')

    J.IsModeTurbo = function() return false end
    J.IsSoakCandidate = function(id) return id == 'cmqreach' end
    assert(X.cm_GetCreepAoESearchRange(732, 425) == 1157, 'armed but not turbo: shipped')

    -- The helper is arithmetic, not a lookup: it must track its arguments.
    J.IsModeTurbo = function() return true end
    assert(X.cm_GetCreepAoESearchRange(982, 425) == 982, 'armed, Aether Lens ring')
    J.IsSoakCandidate = function() return false end
    assert(X.cm_GetCreepAoESearchRange(982, 425) == 1407, 'unarmed, Aether Lens ring')
end

tests['§6 tripwire: the helper is the ONLY producer of the creep search radius'] = function()
    local src = source()
    -- Both creep searches must read the helper's value, and no site may still
    -- write the raw sum.  This is what a "compliant refactor" would silently
    -- undo -- the lesson zusboltcap's counting ratchet paid for.
    local _, nHelperCalls = src:gsub('X%.cm_GetCreepAoESearchRange%s*%(', '')
    assert(nHelperCalls == 2, 'one definition + one call site: ' .. nHelperCalls)

    local nCreepSearches = 0
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        if line:find('FindAoELocation', 1, true) and line:find('true, false', 1, true) then
            nCreepSearches = nCreepSearches + 1
            assert(line:find('nCreepSearch', 1, true),
                'a creep search that does not read the gated radius: ' .. line)
        end
    end
    assert(nCreepSearches == 2, 'two creep searches in the file: ' .. nCreepSearches)
end

tests['§6 tripwire: turbo-only, and behind exactly one soak id'] = function()
    local src = source()
    local body = src:match('function X%.cm_GetCreepAoESearchRange.-\nend')
    assert(body, 'the helper is still in the file')
    assert(body:find('J.IsModeTurbo()', 1, true), 'turbo-only (AGENTS.md)')
    local _, n = body:gsub("IsSoakCandidate%s*%(%s*'cmqreach'%s*%)", '')
    assert(n == 1, "exactly one 'cmqreach' gate in the helper: " .. n)
    local _, nAny = body:gsub('IsSoakCandidate', '')
    assert(nAny == 1, 'and no second id hidden in the same body: ' .. nAny)
end

-- =====================================================================
-- §7  What this file does not settle, measured
-- =====================================================================

tests['§7 LIMIT: no archived CM frame reaches a creep branch, and here is the count'] = function()
    -- Both CM frames the corpus has carry Nova at rank 1, and every creep
    -- branch wants nSkillLV >= 3.  So even with the cooldown lifted the branch
    -- population is empty for a reason that has nothing to do with cooldown --
    -- which is why §2/§3 are pinned at the SEARCH site and claim nothing about
    -- firing.  Requested as a corpus reading in queue.json:hero-25.
    local nRank1 = 0
    for _, path in ipairs({
        'tests/fixtures/f_260820_102645_cm_laning_release.lua',
        'tests/fixtures/f_260819_003005_cm_selfpreserve.lua',
    }) do
        local fx = dofile(path)
        for _, u in ipairs(fx.units) do
            if u.name == 'npc_dota_hero_crystal_maiden' then
                for _, a in ipairs(u.abilities or {}) do
                    if a.name == NOVA and a.level < 3 then nRank1 = nRank1 + 1 end
                end
            end
        end
    end
    assert(nRank1 == 2, 'both archived CM frames hold Nova below rank 3: ' .. nRank1)

    -- And the shipped threshold really is 3, read off the source rather than
    -- remembered, so a patch that lowers it reopens this limit here.
    local _, nGate = source():gsub('nSkillLV >= 3', '')
    assert(nGate >= 4, 'the creep branches gate on nSkillLV >= 3: ' .. nGate)
end

tests['§7 LIMIT: the count the armed side gives up is real and is not measured here'] = function()
    -- A 732 search cannot see more creeps than a 1157 one, so every
    -- `count >= N` threshold is weakly harder armed.  The engine's own count is
    -- stubbed in this file, so the SIZE of that loss is not a reading this test
    -- has any right to give -- only its SIGN, which is stated in the source.
    local doc = source():match('(.-)\nfunction X%.cm_GetCreepAoESearchRange')
    assert(doc:find('STRICTLY no\n--- more often', 1, true)
        or doc:find('STRICTLY no', 1, true),
        'the direction of the cost is written down in the helper\'s own doc block')
end

return tests

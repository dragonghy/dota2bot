-- [hero] The `hero-2` lever (Axe's Culling Blade kill-check) has been blocked
-- since 2026-08-22 by ONE published number, and this file re-derives that number
-- from the corpus instead of quoting it.
--
-- THE BATON THIS FILE TAKES
--
-- tests/test_axe_culling_threshold_preflight.lua wrote the lever up and refused
-- it, and the refusal was NOT "empty domain" -- it named itself
-- NARROW-BAND-UNMEASURABLE and rested on a power calculation:
--
--     "The band is 25 points wide. ... on 3 of those 20 an enemy hero is inside
--      the effective 375u ring.  The band is occupied in the ring ZERO times.
--      That zero decides nothing.  Three in-ring enemy-frames against a
--      25-point window on a health pool of order 1000 gives an expected count
--      near 0.08 ... you would need roughly 40 in-ring frames to expect a single
--      hit, and several hundred for an estimate worth quoting."
--
-- and then generalised it into a rule for the stream's Y.2 list:
--
--     "A lever whose domain is a narrow BAND on a continuous quantity ... cannot
--      be sized from a frame corpus at all ... Size it on the EVENT side (casts
--      that did/didn't happen), or not at all."
--
-- WHAT THIS FILE FINDS
--
-- The arithmetic is right and the conclusion drawn from it is too strong, in a
-- way that matters because it is what routes the lever at GH #310 (cast-instant
-- target HP, a dumper change nobody has scheduled) instead of at the archived
-- 1 Hz timelines this project already owns.
--
-- The "40 in-ring frames" figure is the POOL model: it prices the band as
-- band / health_pool, i.e. it asks how often a UNIFORMLY DRAWN enemy-frame lands
-- in a 25-point window of a ~1000-point pool.  §7 reproduces it from the corpus
-- (median in-ring pool 1131 -> 45 frames) so the reconstruction is not a guess.
--
-- But an enemy never occupies the band uniformly.  It ENTERS the band from above,
-- on its way down, and the only question is whether a sample lands during the
-- traverse.  At sampling period dt and health velocity v, time-in-band is
-- band/v, so a crossing is caught with probability min(1, band / (v*dt)) -- a
-- quantity that does not contain the health pool at all.  The corpus can price v
-- because `observed.burst` is exactly that: hero damage actually dealt over the
-- 5 s following each frame, ground truth from the replays.  Median 58.3 HP/s
-- over the 58 fixtures that carry a live burst; max 360.
--
--     pool model     25/1131          = 0.022   -> ~45 in-ring frames per hit
--     crossing model 25/(58.3 * 1.0)  = 0.429   -> ~2.3 crossings per hit
--     crossing model 25/(360  * 1.0)  = 0.069   -> ~15 crossings per hit
--
-- So the crossing population is ~19x more efficient than the random-frame
-- population at the median observed burst, and still ~3x more efficient at the
-- fastest burst the corpus has ever recorded.  The sizing this lever needs is
-- therefore NOT out of reach of 1 Hz data -- it is out of reach of a FIXTURE
-- LIBRARY, which holds isolated instants and by construction contains no
-- crossings at all.  Both statements were compressed into "cannot be sized from
-- a frame corpus", and only the second one is true.
--
-- CONSEQUENCE, STATED AS A ROUTE AND NOT AS A RESULT
--
-- GH #310 ("1 Hz snapshots cannot resolve the kill-confirmation band") stays
-- correct for PER-CAST verification -- confirming that one particular cast was
-- decided by the band does need the HP at the cast instant.  It is not a blocker
-- for DOMAIN SIZING, which needs crossings and not instants.  Nothing here
-- promotes, arms, or widens anything: `hero-2` is still unwritten, the shipped
-- kill-check is untouched, and no gate id is created.
--
-- WHAT IS PINNED, AND WHY EACH THING IS PINNED THE WAY IT IS
--
--   * The shipped ladder is PARSED out of hero_axe.lua and the KV ladder out of
--     tests/mock/special_value_shapes.lua.  Neither is retyped, so a rebalance
--     moves this file's arithmetic instead of leaving it confidently stale --
--     which is the very failure the lever exists to remove.
--   * §4 asserts the drift DIRECTION, not just its size.  Today the constant is
--     25 LOW at every rank and the cost is a declined kill.  The rebalance that
--     moves damage the other way makes it sit HIGH, and then Axe spends an
--     80-second ultimate on a target that lives -- strictly worse and silent.
--     That flip turns this file red.
--   * §6 asserts the band is occupied ZERO times with an EXPIRY text: a corpus
--     that ever lands a frame in the band has GIVEN the lever its frame, and the
--     failure says so rather than reading as a regression.
--
-- LIMITS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
--   * The crossing model assumes a monotone descent through the band at roughly
--     constant velocity and a sampling phase independent of the crossing.  Heal,
--     regen, or a burst that overshoots the whole band in one engine tick all
--     break it in the SAME direction -- fewer catches -- so the numbers above are
--     an UPPER bound on capture, i.e. the honest reading is "at least this many
--     crossings", never "this many suffice".
--   * `observed.burst` is damage dealt TO the fixture's subject BY enemy heroes.
--     Using it as the velocity of a TARGET being killed assumes hero-on-hero
--     damage rates are symmetric in distribution.  It is the corpus's own
--     measurement of the right physical quantity on the wrong end of the fight.
--   * Fixtures with an all-zero burst are excluded (49 of 107): a hero taking no
--     damage is not crossing anything.  The median is therefore conditioned on
--     "a fight is happening", which is the population the lever lives in.
--   * The rings ignore vision, exactly as the preflight's did, so they are UPPER
--     bounds on what the engine's list would show.  The approximation runs in the
--     safe direction for a "the corpus cannot settle this" claim.
--   * All 22 ready frames are rank 1 or 2 (20 and 2).  Rank 3 -- where the band
--     is (450, 475] and the talent question of hero_axe.lua's t25 note lives -- is
--     untested by this corpus at every level.
--   * Nothing here is a frequency estimate.  The fixture library is curated for
--     other investigations and holds near-duplicate instants from single games.

package.path = 'tests/?.lua;' .. package.path

local rf = require('mock.replay_fixture')

local SHAPES = 'tests/mock/special_value_shapes.lua'
local AXE    = 'bots/BotLib/hero_axe.lua'
local FRAME  = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'

local CULL    = 'axe_culling_blade'
local TALENT8 = 'special_bonus_unique_axe_5'
local SUBJECT = 'npc_dota_hero_axe'
local TARGET  = 'npc_dota_hero_skywrath_mage'

local RING     = 375       -- cast range + 200, the list ConsiderR's execute reads
local SAMPLE_S = 1.0       -- the archived timelines' snapshot period

-- ---------------------------------------------------------------------------
-- KV + source anchors.  Parsed, never retyped.

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Every per-level entry of a KV "a b c" base string.
local function ladder(sBase)
    local t = {}
    for w in tostring(sBase):gmatch('%S+') do t[#t + 1] = tonumber(w) end
    assert(#t > 0, 'no numeric entries in KV base string ' .. tostring(sBase))
    return t
end

local AXE_SHAPES = assert(dofile(SHAPES).SHAPES['axe'], 'no axe block in the KV snapshot')

local function kv(sAbility, sKey)
    local ab = assert(AXE_SHAPES[sAbility], 'no KV block for ' .. sAbility)
    return assert(ab[sKey], sAbility .. ' has no key ' .. sKey)
end

local KV_DAMAGE = ladder(kv(CULL, 'damage').base)
local KV_MANA   = ladder(kv(CULL, 'AbilityManaCost').base)
local KV_RANGE  = ladder(kv(CULL, 'AbilityCastRange').base)[1]
local KV_POINT  = ladder(kv(CULL, 'AbilityCastPoint').base)[1]
-- NOTE the doubled parentheses: gsub returns TWO values and as the last argument
-- both would expand, handing tonumber a base.  (The sibling Zeus band file was
-- bitten by the same two-value expansion through string.find.)
local TALENT_ADD = tonumber(((kv(CULL, 'damage').bonus[TALENT8] or ''):gsub('%+', '')))

--- The shipped kill-check's ladder, lifted out of the Lua rather than retyped.
local function shipped_ladder()
    local src = read_file(AXE)
    local a, b = src:match('local nKillDamage = (%d+) %+ (%d+) %* nSkillLV')
    assert(a and b, 'the shipped Culling kill-check no longer reads '
        .. '`local nKillDamage = <a> + <b> * nSkillLV` in ' .. AXE
        .. ' -- if hero-2 landed, retire this file; if it was reshaped, re-read §1')
    local t = {}
    for i = 1, #KV_DAMAGE do t[i] = tonumber(a) + tonumber(b) * i end
    return t, tonumber(a), tonumber(b)
end

local SHIPPED = shipped_ladder()

-- ---------------------------------------------------------------------------
-- Corpus readers.

local function each_fixture(fn)
    local fh = assert(io.popen('ls tests/fixtures/f_*.lua 2>/dev/null'))
    for sPath in fh:lines() do
        local ok, fx = pcall(dofile, sPath)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then fn(sPath, fx) end
    end
    fh:close()
end

--- Axe's row in a fixture, plus his Culling rank / cooldown, or nil.
local function axe_row(fx)
    local a
    for _, u in ipairs(fx.units) do if u.name == SUBJECT then a = u end end
    if a == nil then return nil end
    local nRank, nCd = 0, 0
    for _, ab in ipairs(a.abilities or {}) do
        if ab.name == CULL then nRank, nCd = ab.level, ab.cd end
    end
    return a, nRank, nCd
end

--- The whole census in one pass, so every §6 number comes from one reading.
local function census()
    local c = {
        axe = 0, alive = 0, ready = 0, ring = 0, inCastRange = 0,
        band = 0, bandTalent = 0, pairs_ = 0, ranks = {}, pools = {},
        blockedRank = 0, blockedCd = 0, blockedMana = 0, where = nil,
    }
    each_fixture(function(sPath, fx)
        local a, nRank, nCd = axe_row(fx)
        if a == nil then return end
        c.axe = c.axe + 1
        if not a.alive then return end
        c.alive = c.alive + 1
        if nRank == 0 then c.blockedRank = c.blockedRank + 1 return end
        if nCd > 0 then c.blockedCd = c.blockedCd + 1 return end
        if (a.mp or 0) < KV_MANA[math.min(nRank, #KV_MANA)] then
            c.blockedMana = c.blockedMana + 1 return
        end
        c.ready = c.ready + 1
        c.ranks[nRank] = (c.ranks[nRank] or 0) + 1
        local bRing, bClose = false, false
        for _, u in ipairs(fx.units) do
            if u.team ~= a.team and u.alive and u.name:find('^npc_dota_hero_') then
                c.pools[#c.pools + 1] = u.max_hp
                local nDist = math.sqrt((u.x - a.x) ^ 2 + (u.y - a.y) ^ 2)
                if nDist <= KV_RANGE then bClose = true end
                if nDist <= RING then
                    bRing = true
                    c.pairs_ = c.pairs_ + 1
                    local nShip, nTrue = SHIPPED[nRank], KV_DAMAGE[nRank]
                    if u.hp >= nShip and u.hp < nTrue then
                        c.band = c.band + 1
                        c.where = sPath .. ' / ' .. u.name .. ' hp=' .. u.hp
                    end
                    if u.hp >= nShip and u.hp < nTrue + TALENT_ADD then
                        c.bandTalent = c.bandTalent + 1
                    end
                end
            end
        end
        if bRing then c.ring = c.ring + 1 end
        if bClose then c.inCastRange = c.inCastRange + 1 end
    end)
    return c
end

--- Hero damage per second actually dealt, one reading per fixture that has one.
local function burst_velocities()
    local v = {}
    each_fixture(function(_, fx)
        local o = fx.observed
        if type(o) ~= 'table' or type(o.burst) ~= 'table' then return end
        local nSum, nSeen = 0, 0
        for _, d in pairs(o.burst) do
            if type(d) == 'number' then nSum = nSum + d; nSeen = nSeen + 1 end
        end
        if nSeen > 0 and nSum > 0 then v[#v + 1] = nSum / (fx.window or 5.0) end
    end)
    table.sort(v)
    return v
end

--- Sorts a COPY: the caller's order is meaningful elsewhere, and reading a
--- median off an unsorted array silently answers "some element", not the median.
local function median(t)
    assert(#t > 0, 'median of an empty sample')
    local c = {}
    for i = 1, #t do c[i] = t[i] end
    table.sort(c)
    return c[math.ceil(#c / 2)]
end

local CENSUS = census()
local BURST  = burst_velocities()

-- ---------------------------------------------------------------------------

local tests = {}

-- 1. The two ladders, and that neither of them was retyped into this file.

tests['[hero] the shipped Culling kill-check is still the hardcoded ladder'] = function()
    local t, a, b = shipped_ladder()
    assert(a == 150 and b == 100,
        'the shipped constants moved to ' .. a .. ' + ' .. b .. ' * lv; §7 prices the OLD pair')
    assert(#t == #KV_DAMAGE, 'ladder length must match the KV ranks')
    for i = 1, #t do
        assert(t[i] == 150 + 100 * i, 'shipped ladder entry ' .. i .. ' is ' .. t[i])
    end
end

tests['[hero] the KV ladder and the talent fold come out of the frozen snapshot'] = function()
    assert(#KV_DAMAGE == 3, 'Culling Blade should have three ranks, snapshot has ' .. #KV_DAMAGE)
    assert(TALENT_ADD ~= nil and TALENT_ADD > 0,
        TALENT8 .. ' must still be folded into ' .. CULL .. '/damage by the engine')
    assert(KV_RANGE == 175, 'cast range moved to ' .. KV_RANGE .. '; RING above is range + 200')
    assert(KV_POINT > 0, 'cast point must be a real number for §5')
end

-- 2. The drift: size, and -- the part that matters more -- direction.

tests['[hero] the constant is short by the same amount at every rank'] = function()
    local nFirst = KV_DAMAGE[1] - SHIPPED[1]
    for i = 1, #KV_DAMAGE do
        assert(KV_DAMAGE[i] - SHIPPED[i] == nFirst,
            'rank ' .. i .. ' drifts by ' .. (KV_DAMAGE[i] - SHIPPED[i])
            .. ', rank 1 by ' .. nFirst .. ' -- §7 prices ONE band width for all ranks')
    end
    assert(nFirst == 25, 'the band this file prices is ' .. nFirst .. ' wide, not 25')
end

tests['[hero] DIRECTION GUARD: the constant must be LOW, never high'] = function()
    for i = 1, #KV_DAMAGE do
        assert(SHIPPED[i] < KV_DAMAGE[i],
            'rank ' .. i .. ': the hardcoded kill-check (' .. SHIPPED[i] .. ') is no longer BELOW '
            .. 'Culling\'s real damage (' .. KV_DAMAGE[i] .. ').  THE FAILURE MODE HAS FLIPPED: '
            .. 'today the bot declines a kill it could make; above the real damage it spends an '
            .. '80-second ultimate on a target that LIVES.  That is strictly worse and silent.  '
            .. 'Land hero-2 (read abilityR:GetSpecialValueInt(\'damage\')) rather than re-hardcode.')
    end
end

tests['[hero] the talent term is dead for a structural reason, not a typo'] = function()
    assert(AXE_SHAPES[TALENT8] == nil,
        TALENT8 .. ' owns a KV block in the snapshot; GH #228\'s reason for the dead '
        .. 'talent8:GetSpecialValueInt(\'value\') read no longer holds -- re-read hero_axe.lua:916')
    local nBand = KV_DAMAGE[#KV_DAMAGE] - SHIPPED[#KV_DAMAGE]
    local nWithTalent = (KV_DAMAGE[#KV_DAMAGE] + TALENT_ADD) - SHIPPED[#KV_DAMAGE]
    assert(nWithTalent == nBand + TALENT_ADD, 'talent band arithmetic')
    assert(nWithTalent == 7 * nBand,
        'hero_axe.lua\'s t25 note says taking [8] multiplies the blind band by seven; '
        .. 'it is now ' .. nWithTalent .. ' against ' .. nBand)
end

-- 3. The one real frame the corpus has, driven through the real function.

tests['[hero] ConsiderR fires on the real frame -- and the repair would not change it'] = function()
    local J, bot, heroes = rf.load(FRAME, SUBJECT)
    local abilityR = bot:GetAbilityByName(CULL)
    local sR = rawget(abilityR, '__spec')
    -- DECLARED ANCHORING: .dem carries no ability specs, so range/point/mana come
    -- from the frozen KV snapshot at the frame's own real rank.
    local nRank = abilityR:GetLevel()
    sR.GetCastRange = KV_RANGE
    sR.GetCastPoint = KV_POINT
    sR.GetManaCost  = KV_MANA[math.min(nRank, #KV_MANA)]

    local X = rf.load_hero('axe')
    local nDesire, hTarget = X.ConsiderR()
    assert(nDesire == BOT_ACTION_DESIRE_HIGH,
        'the shipped execute must still fire on this frame; got desire ' .. tostring(nDesire))
    assert(hTarget ~= nil and hTarget:GetUnitName() == TARGET,
        'and must still pick ' .. TARGET)

    -- WHY THIS FRAME DOES NOT MOTIVATE THE LEVER: the target is BELOW the shipped
    -- threshold, so it is not in the band at all.  Both thresholds fire, the repair
    -- is a no-op here, and that is the point -- the corpus proves the mechanism and
    -- says nothing about the defect.
    local nHp = heroes[TARGET]:GetHealth()
    assert(nHp < SHIPPED[nRank],
        'this frame is supposed to sit BELOW the shipped threshold; hp=' .. nHp)
    assert(nHp < KV_DAMAGE[nRank], 'and therefore below the repaired one too')
    assert(J.IsValidHero(heroes[TARGET]), 'target must be a live hero on the frame')
end

-- 4. The census, driven.  Lower bounds where the corpus may grow (GH #273 shape).

tests['[hero] the corpus reaches the branch, and the band is empty in it'] = function()
    assert(CENSUS.axe >= 28, 'fixtures carrying an Axe: ' .. CENSUS.axe .. ', expected >= 28')
    assert(CENSUS.alive == CENSUS.axe, 'every Axe frame in the corpus is a live Axe')
    assert(CENSUS.ready >= 22, 'frames with Culling ready: ' .. CENSUS.ready .. ', expected >= 22')
    assert(CENSUS.ring >= 3, 'ready frames with an enemy inside ' .. RING .. 'u: ' .. CENSUS.ring)
    assert(CENSUS.inCastRange >= 1,
        'ready frames with an enemy inside the ' .. KV_RANGE .. 'u cast range: ' .. CENSUS.inCastRange)
    assert(CENSUS.band == 0,
        'EXPECTED EXPIRY, NOT A REGRESSION: the fixture corpus now holds a frame INSIDE the '
        .. 'Culling band (' .. tostring(CENSUS.where) .. ').  That is the real frame the `hero-2` '
        .. 'lever has been waiting for since 2026-08-22 -- take the lever, then retire this case.')
    assert(CENSUS.bandTalent == 0,
        'EXPECTED EXPIRY: a frame now sits in the WIDER talent-[8] band ('
        .. tostring(CENSUS.where) .. ') -- see hero_axe.lua\'s t25 note')
end

-- 5. The power correction.  Every input is read off the corpus above.

tests['[hero] the pool model reproduces the published "roughly 40 frames"'] = function()
    local nPool = median(CENSUS.pools)
    local nBand = KV_DAMAGE[1] - SHIPPED[1]
    local nPerFrame = nBand / nPool
    local nFrames = 1 / nPerFrame
    assert(nPool > 900 and nPool < 1400,
        'median in-ring health pool moved to ' .. nPool .. '; the published figure assumed ~1000')
    assert(nFrames > 35 and nFrames < 60,
        'the pool model now needs ' .. string.format('%.1f', nFrames)
        .. ' in-ring frames per expected hit; the preflight published "roughly 40"')
end

tests['[hero] the crossing model prices the same band without the health pool'] = function()
    local nBand = KV_DAMAGE[1] - SHIPPED[1]
    assert(#BURST >= 50, 'fixtures carrying a live burst: ' .. #BURST .. ', expected >= 50')

    local nMed = median(BURST)
    local nMax = BURST[#BURST]
    local pMed = math.min(1, nBand / (nMed * SAMPLE_S))
    local pMax = math.min(1, nBand / (nMax * SAMPLE_S))
    local pPool = nBand / median(CENSUS.pools)

    -- The whole point: the crossing probability contains no health pool term, so
    -- it does not shrink as heroes get tankier.
    assert(pMed > pPool,
        'at the corpus median burst (' .. string.format('%.1f', nMed) .. ' HP/s) a crossing is '
        .. 'caught with p=' .. string.format('%.3f', pMed) .. ', which must beat the pool model\'s '
        .. string.format('%.3f', pPool))
    assert(pMax > pPool,
        'even at the fastest burst the corpus has recorded (' .. string.format('%.0f', nMax)
        .. ' HP/s) the crossing population must still beat the random-frame population')
    assert(pMed / pPool > 10,
        'the median-burst advantage is ' .. string.format('%.1f', pMed / pPool)
        .. 'x; §7 of the header quotes ~19x')
    assert(1 / pMax < 1 / pPool,
        'crossings needed at worst-case velocity must stay below frames needed under the pool model')
end

-- 6. Source tripwires: everything above reads the shipped code as it is TODAY.

tests['[hero] ConsiderR still decides the execute with that one constant'] = function()
    local src = read_file(AXE)
    local nAt = (src:find('function X.ConsiderR', 1, true))
    assert(nAt, 'X.ConsiderR must still exist in ' .. AXE)
    local body = src:sub(nAt)
    body = body:sub(1, (body:find('\nend', 1, true)))
    assert(body:find('local nKillDamage = 150 + 100 * nSkillLV', 1, true),
        'the hardcoded ladder must still live inside ConsiderR')
    assert(body:find('GetHealth() + npcEnemy:GetHealthRegen() * 0.8 < nKillDamage', 1, true),
        'and the execute must still be the comparison this file prices')
    assert(not body:find('IsSoakCandidate', 1, true),
        'the execute is UNGATED shipped behaviour; if a gate appeared, hero-2 landed -- '
        .. 'retire this file rather than editing the numbers')
end

return tests

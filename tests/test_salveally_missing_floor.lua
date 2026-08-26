-- GH #231 -- the salve's ALLY branch, the other half of the function GH #227
-- fixed, and this half is not merely pool-blind: on a pool the archive actually
-- carries it is ARITHMETICALLY UNSATISFIABLE.
--
-- ability_item_usage_generic's salve consider picks a teammate to stick the
-- salve on with
--     npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > <a fixed amount>
-- Missing health can never exceed the pool, so for any ally whose pool is at or
-- below that amount the test is false at EVERY health, one included. That is a
-- STRUCTURAL ZERO by arithmetic -- the `bbfight` shape -- not a "domain too
-- small to measure" statistical verdict. And the archive carries such a pool on
-- a plausible frame (a level-1 Crystal Maiden at 538): read as the fraction of
-- health she must be missing, the shipped floor asks for 102.2% of her.
--
-- Above that pool the SECOND defect takes over, and it is the same
-- pool-blindness the self branch was just fixed for, only harsher: at 669 the
-- ally must be under 17.8% health, at 2566 under 78.6%.
--
-- The two loops being compared here are not analogous, they are the SAME loop:
-- the healing-lotus helper forty lines below runs GetAlliesNearLoc( ..., 700 )
-- with the same IsValid / ~= bot / IsIllusion / heal-modifier /
-- WasRecentlyDamagedByAnyHero guards, and asks its question as a REMAINING
-- RATIO. The single structural difference between the two ally loops in this
-- file is the form of this one predicate.
--
-- ⚠ THE CRITERION THIS ROUND EXISTS TO WRITE DOWN. An arithmetic structural
-- zero and a corpus reading are answers to two different questions, and the
-- force of the first must not be spent covering for the second. The zero above
-- is proved -- but on the axis this branch is actually measured on
-- (salve-holder x ally-within-700 PAIRS) the archive's ally pools run
-- [582, 1872] and NOT ONE PAIR carries a sub-550 ally. So:
--   * the arithmetic says the shipped line is unsatisfiable for such an ally;
--   * the corpus says this archive has never put such an ally in front of a
--     salve holder, and therefore buys this lever ZERO end-to-end frames.
-- Both are asserted below, separately, and neither is quoted as the other.
-- `bbfight`'s zero sat on the axis its lever was reachable on; this one does
-- not, and that difference is the whole finding of the round.
--
-- WHAT IS PINNED RATHER THAN ASSUMED:
--   [W1] the branch's other conjuncts (four heal modifiers,
--        WasRecentlyDamagedByAnyHero, IsIllusion, IsChanneling) are NOT in any
--        dump. Every count here counts frames REACHING the missing-health test,
--        never a salve stuck on anybody.
--   [W2] the fountain guard (DistanceFromFountain < 3000 returns early) is not
--        modelled either -- fixtures carry no fountain -- so every pair count
--        below is an UPPER bound on the branch's real reachability.
--   [W3] the self branch returns first, so a pair is only reachable if the self
--        branch does NOT fire. Only two of its conjuncts are corpus-answerable,
--        so what is excluded below is a NECESSARY condition for pre-emption,
--        which makes the deepest count a lower bound. It is measured under both
--        the shipped and the `salvepool`-armed self floor and it is the same
--        number either way; that agreement is asserted rather than assumed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIX  = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local SIDE_PATH = 'bots/Customize/soak_side.lua'   -- gitignored, farm-only

-- The anchor: a Chaos Knight holding a salve, and a Lich 491u away at a third
-- of her health that the shipped floor will not let him touch.
local HOLDER  = 'npc_dota_hero_chaos_knight'
local ALLY    = 'npc_dota_hero_lich'
local FRAME_T = 201.3
local HOLDER_LEVEL = 4
local ALLY_HP, ALLY_MAXHP = 225, 692

-- The shipped constants, written out so the model below is comparable against
-- the source rather than against a memory of it. [source] pins each one.
local FLOOR = 550       -- the shipped absolute ally floor, unarmed
local RATIO = 0.55      -- the armed pool ratio
local SELF_FLOOR = 500  -- the sibling branch GH #227 moved; not this lever
local CALIB_POOL = 1000 -- the mid-laning pool both floors are read against

-- Pools, from the archive. [corpus] pins them.
local POOL_MIN_REAL = 538    -- level-1 Crystal Maiden, the smallest plausible pool
local POOL_MAX      = 2566

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- The three radii the model needs are READ OUT OF THE SOURCE rather than typed
-- here a second time. A model constant that is typed twice can drift from the
-- branch it claims to model without anything noticing -- and it did: a first
-- draft of this file hard-coded the quiet radius, and mutating that copy from
-- 1000 to 1600 left all 23 assertions green, because on this archive the two
-- radii happen to select the same pairs. Deriving them makes such a mutation a
-- disagreement with the tree instead of a silent one with nothing.
local function salve_consider()
    local body = read_file(AIUG)
    local fn = body:match('X%.ConsiderItemDesire%["item_flask"%].-\n\nend')
    assert(fn ~= nil, 'the salve consider is no longer findable in ' .. AIUG)
    return body, fn
end

local PAIR_DIST_MAX, QUIET_RADIUS, SELF_QUIET_RADIUS
do
    local body, fn = salve_consider()
    -- the ally branch's own GetAlliesNearLoc radius
    PAIR_DIST_MAX = tonumber(fn:match('J%.GetAlliesNearLoc%(%s*bot:GetLocation%(%),%s*(%d+)%s*%)'))
    -- the self branch's enemy-list radius, used only to model pre-emption [W3]
    SELF_QUIET_RADIUS = tonumber(fn:match('local nCastRange = (%d+)'))
    -- the ally branch is guarded by the file-level list, built once per frame
    QUIET_RADIUS = tonumber(body:match('hNearbyEnemyHeroList = J%.GetNearbyHeroes%(bot,%s*(%d+),'))
    assert(PAIR_DIST_MAX and SELF_QUIET_RADIUS and QUIET_RADIUS, string.format(
        'could not read the radii out of the source (ally %s, self %s, quiet %s)',
        tostring(PAIR_DIST_MAX), tostring(SELF_QUIET_RADIUS), tostring(QUIET_RADIUS)))
end

local function load_with(sCand, sSide)
    if sCand == nil then
        os.remove(SIDE_PATH)
    else
        local f = assert(io.open(SIDE_PATH, 'w'))
        f:write("return { side = '" .. (sSide or 'dire') .. "', cand = '" .. sCand .. "' }\n")
        f:close()
    end
    local J, bot, heroes = rf.load(FIX, HOLDER)
    assert(bot ~= nil, 'fixture no longer carries ' .. HOLDER)
    assert(heroes[ALLY] ~= nil, 'fixture no longer carries ' .. ALLY)
    return J, bot, heroes[ALLY]
end

local function armed(sCand, fn, sSide)
    local J, bot, ally = load_with(sCand, sSide)
    local ok, err = pcall(fn, J, bot, ally)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------
-- The model: two floors, and the branch's corpus-answerable conjuncts.
----------------------------------------------------------------------

local function shipped_floor() return FLOOR end
local function armed_floor(nMaxHealth, nRatio)
    return math.min(FLOOR, nMaxHealth * (nRatio or RATIO))
end
local function self_floor(nMaxHealth, bSelfArmed)
    if bSelfArmed then return math.min(SELF_FLOOR, nMaxHealth * 0.5) end
    return SELF_FLOOR
end

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function holds_salve(u)
    for _, sItem in ipairs(u.items or {}) do
        if sItem == 'flask' then return true end
    end
    return false
end

-- The whole archive, read as plain Lua tables (a fixture IS `return { ... }`),
-- so the census costs one dofile per file and never a mock world.
local corpus_cache = nil
local function corpus()
    if corpus_cache ~= nil then return corpus_cache end
    local alive, pairs_, nFiles = {}, {}, 0
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                if u.alive and u.max_hp and u.max_hp > 0 then
                    alive[#alive + 1] = { file = path, name = u.name, max_hp = u.max_hp }
                end
            end
            -- The pair axis: a salve holder and a living teammate inside the
            -- branch's own 700 radius. This, not the alive-frame list, is the
            -- axis this lever is reachable on.
            for _, h in ipairs(fx.units) do
                if h.alive and h.max_hp and h.max_hp > 0 and holds_salve(h) then
                    -- The outer conjunct of the ally branch: the consider's own
                    -- 1000-radius enemy list must be empty.
                    local bQuiet1000, bQuiet900 = true, true
                    for _, v in ipairs(fx.units) do
                        if v ~= h and v.alive and v.team ~= h.team then
                            local d = dist(v, h)
                            if d <= QUIET_RADIUS then bQuiet1000 = false end
                            if d <= SELF_QUIET_RADIUS then bQuiet900 = false end
                        end
                    end
                    for _, a in ipairs(fx.units) do
                        if a ~= h and a.alive and a.team == h.team
                            and a.max_hp and a.max_hp > 0
                            and dist(a, h) <= PAIR_DIST_MAX
                        then
                            pairs_[#pairs_ + 1] = {
                                file = path,
                                holder = h.name, ally = a.name,
                                ally_max_hp = a.max_hp,
                                ally_missing = a.max_hp - a.hp,
                                quiet = bQuiet1000,
                                -- [W3]: necessary condition for the self branch
                                -- to pre-empt, under either self floor.
                                self_pre_shipped = (h.max_hp - h.hp > self_floor(h.max_hp, false)) and bQuiet900,
                                self_pre_armed   = (h.max_hp - h.hp > self_floor(h.max_hp, true)) and bQuiet900,
                            }
                        end
                    end
                end
            end
        end
    end
    p:close()
    assert(nFiles > 0, 'no fixtures readable; the census below would be a vacuous pass')
    corpus_cache = { alive = alive, pairs = pairs_, files = nFiles }
    return corpus_cache
end

local function count_pairs(fPred, nRatio)
    local n = 0
    for _, r in ipairs(corpus().pairs) do
        if fPred(r, nRatio) then n = n + 1 end
    end
    return n
end

local function fires_shipped(r) return r.ally_missing > shipped_floor() end
local function fires_armed(r, nRatio) return r.ally_missing > armed_floor(r.ally_max_hp, nRatio) end
local function opened(r, nRatio) return fires_armed(r, nRatio) and not fires_shipped(r) end
local function closed(r, nRatio) return fires_shipped(r) and not fires_armed(r, nRatio) end

----------------------------------------------------------------------
-- [structural] the arithmetic, which needs no corpus at all
----------------------------------------------------------------------

tests['[structural] shipped, a pool at or below the floor can never satisfy it'] = function()
    -- Exhaustive over every pool the floor claims to serve and every health in
    -- it, one included. Not a sample: the point is that there is nothing to
    -- sample, the predicate is false everywhere in that region.
    local nWidest, nChecked = 0, 0
    for nMax = 1, FLOOR do
        for nHp = 1, nMax do
            assert(not ((nMax - nHp) > shipped_floor()), string.format(
                'pool %d at hp %d now satisfies the shipped ally floor; the '
                .. 'structural-zero claim is wrong', nMax, nHp))
            nChecked = nChecked + 1
        end
        nWidest = nMax
    end
    -- What the loop actually covered, asserted -- otherwise the range could be
    -- shrunk and the remaining subset would still pass, which is the difference
    -- between "exhaustive" and "true on the part I looked at".
    assert(nWidest == FLOOR, string.format(
        'the sweep stopped at pool %d, not the floor %d', nWidest, FLOOR))
    assert(nChecked == FLOOR * (FLOOR + 1) / 2, string.format(
        'the sweep covered %d (pool, health) states, not the %d the region has',
        nChecked, FLOOR * (FLOOR + 1) / 2))
    -- The boundary, stated exactly, so the grid above cannot be quietly shrunk
    -- and still pass. A living hero has at least 1 health, so the first pool at
    -- which the shipped line is satisfiable at all is FLOOR + 2, and there only
    -- at exactly 1 health.
    for nHp = 1, FLOOR + 1 do
        assert(not ((FLOOR + 1 - nHp) > shipped_floor()),
            'a pool one above the floor became satisfiable at hp ' .. nHp)
    end
    assert((FLOOR + 2 - 1) > shipped_floor(),
        'a pool two above the floor is no longer satisfiable at 1 health; the '
        .. 'boundary of the structural zero has moved')
    assert(not ((FLOOR + 2 - 2) > shipped_floor()),
        'and at 2 health it must still be refused')
end

tests['[structural] armed, the same pools become reachable'] = function()
    -- The zero is removed rather than narrowed: for every pool below the floor
    -- there is a health at which the armed predicate is true.
    for nMax = 100, FLOOR, 1 do
        local nFloor = armed_floor(nMax)
        assert(nFloor < nMax, string.format(
            'pool %d armed floor %g is still at or above the whole pool', nMax, nFloor))
        local nHp = math.floor(nMax - nFloor)
        assert((nMax - nHp) > nFloor or (nMax - (nHp - 1)) > nFloor, string.format(
            'pool %d has no health at which the armed floor fires', nMax))
    end
end

tests['[structural] the archive carries such a pool, on a plausible frame'] = function()
    -- Existence comes from the corpus; the verdict came from the arithmetic
    -- above. 17 alive hero-frames sit at or below the ally floor -- 16 of them
    -- are the SAME hero at pool values no hero has (the GH #176 dump-artefact
    -- family GH #227's [W3] already refused to build on), and the seventeenth
    -- is a level-1 Crystal Maiden at 538, which is plausible.
    local c = corpus()
    assert(c.files >= 100, 'only ' .. c.files .. ' fixtures read; the census is thin')
    assert(#c.alive > 900, 'only ' .. #c.alive .. ' alive hero-frames; the census is thin')
    local nSub, nPlausible, names = 0, 0, {}
    for _, r in ipairs(c.alive) do
        if r.max_hp <= FLOOR then
            nSub = nSub + 1
            if r.max_hp >= SELF_FLOOR then
                nPlausible = nPlausible + 1
                names[r.name] = (names[r.name] or 0) + 1
            end
        end
    end
    assert(nSub == 17, 'alive frames at or below the ally floor moved to ' .. nSub)
    -- The other end of the roster, so the pool band this file sweeps over is the
    -- band the archive actually has rather than a number carried over by hand.
    local nLargest = 0
    for _, r in ipairs(c.alive) do
        if r.max_hp > nLargest then nLargest = r.max_hp end
    end
    assert(nLargest == POOL_MAX, 'largest archived pool moved to ' .. nLargest)
    assert(nPlausible == 1, string.format(
        'plausible sub-floor alive frames moved to %d; the existence half of '
        .. 'this finding rests on exactly one frame and the assertion says so',
        nPlausible))
    assert(names['npc_dota_hero_crystal_maiden'] == 1,
        'the one plausible sub-floor frame is no longer the level-1 Crystal Maiden')
    -- And what the shipped floor asks of her, stated as the fraction it is.
    local fDemanded = FLOOR / POOL_MIN_REAL
    assert(fDemanded > 1.0, string.format(
        'the shipped ally floor now asks only %.1f%% of the smallest real pool; '
        .. 'that is no longer unsatisfiable', 100 * fDemanded))
end

----------------------------------------------------------------------
-- [criterion] the zero is proved, and it buys nothing here. Say both.
----------------------------------------------------------------------

tests['[criterion] no archived pair puts such an ally in front of a salve'] = function()
    -- THE POINT OF THE ROUND. The structural zero above is real arithmetic, but
    -- on the axis the branch is actually reachable on it is unpopulated: the
    -- ally pools among salve-holder/ally pairs never come near the floor. The
    -- proof does not get to stand in for evidence it did not buy.
    local c = corpus()
    assert(#c.pairs == 73, 'holder-ally pairs moved to ' .. #c.pairs)
    local nMin, nMax = math.huge, 0
    for _, r in ipairs(c.pairs) do
        if r.ally_max_hp < nMin then nMin = r.ally_max_hp end
        if r.ally_max_hp > nMax then nMax = r.ally_max_hp end
    end
    assert(nMin == 582 and nMax == 1872, string.format(
        'archived ally pool band moved to [%g, %g]', nMin, nMax))
    local nSubFloorAlly = count_pairs(function(r) return r.ally_max_hp <= FLOOR end)
    assert(nSubFloorAlly == 0, string.format(
        'the archive now HAS %d pair(s) with a sub-floor ally -- that is the '
        .. 'end-to-end evidence this round says it could not buy, so go read it',
        nSubFloorAlly))
end

----------------------------------------------------------------------
-- [lever] the domain, nested, each question answered with its own number
----------------------------------------------------------------------

tests['[lever] the lever\'s own conjunct opens two archived pairs'] = function()
    local nShipped, nArmed, nOpened = count_pairs(fires_shipped), count_pairs(fires_armed), count_pairs(opened)
    assert(nShipped == 6 and nArmed == 8, string.format(
        'ally missing-health conjunct fires shipped/armed %d/%d (expected 6/8)',
        nShipped, nArmed))
    assert(nOpened == 2, 'pairs opened: ' .. nOpened .. ' (expected 2)')
end

tests['[lever] with the branch\'s own quiet conjunct it is zero, not two'] = function()
    -- The ally branch is guarded by the consider's 1000-radius enemy list being
    -- empty, and both opened pairs are on frames where it is not. The looser 2
    -- must never be quoted alone.
    local nOpenedQuiet = count_pairs(function(r) return opened(r) and r.quiet end)
    local nShippedQuiet = count_pairs(function(r) return fires_shipped(r) and r.quiet end)
    assert(nShippedQuiet == 2, 'quiet pairs firing the shipped floor: ' .. nShippedQuiet)
    assert(nOpenedQuiet == 0, string.format(
        'quiet pairs opened %d (expected 0) -- if this is no longer zero it is '
        .. 'the (a)-evidence this round said it could not buy', nOpenedQuiet))
end

tests['[W3] with the self branch unable to pre-empt it is one shipped, zero opened'] = function()
    -- The deepest readable nesting, and the control that stops the zero above
    -- from reading as "the ally branch is dead": the SHIPPED floor does fire
    -- here, so the conjunction is reachable and only this lever's band is empty.
    for _, sKey in ipairs({ 'self_pre_shipped', 'self_pre_armed' }) do
        local nShipped = count_pairs(function(r) return fires_shipped(r) and r.quiet and not r[sKey] end)
        local nOpened  = count_pairs(function(r) return opened(r) and r.quiet and not r[sKey] end)
        assert(nShipped == 1, string.format(
            'under %s the shipped floor reaches %d pair(s) (expected 1); at zero '
            .. 'the finding would be about the branch, not about this lever',
            sKey, nShipped))
        assert(nOpened == 0, string.format('under %s opened moved to %d', sKey, nOpened))
    end
end

tests['[lever] armed is strictly one-directional: it never closes a pair'] = function()
    assert(count_pairs(closed) == 0, 'the armed floor closed pairs the shipped floor opened')
    -- Exhaustively over a pool/health grid too, so a growing corpus cannot
    -- quietly break the direction.
    for nMax = 400, 2600, 50 do
        for nHp = 1, nMax, 37 do
            local nMissing = nMax - nHp
            if nMissing > shipped_floor() then
                assert(nMissing > armed_floor(nMax), string.format(
                    'pool %d hp %d fired shipped and no longer fires armed', nMax, nHp))
            end
        end
    end
end

tests['[lever] at and above the calibration pool the armed floor IS the shipped one'] = function()
    -- The other half of one-directional: not a blanket loosening. Min pins the
    -- armed floor to the shipped number for every pool at or above 1000, so the
    -- whole change lives below that -- which is where the defect is.
    for nMax = CALIB_POOL, POOL_MAX, 100 do
        assert(armed_floor(nMax) == FLOOR, string.format(
            'pool %d armed floor is %g, not the shipped %d', nMax, armed_floor(nMax), FLOOR))
    end
    assert(armed_floor(CALIB_POOL - 2) < FLOOR, 'a pool just under the calibration pool should drop below the floor')
    local nBig = count_pairs(function(r) return opened(r) and r.ally_max_hp >= CALIB_POOL end)
    assert(nBig == 0, string.format(
        '%d opened pairs have an ally pool at or above %d; Min is not holding',
        nBig, CALIB_POOL))
end

----------------------------------------------------------------------
-- [derivation] the ratio is read off the shipped constant, not fitted
----------------------------------------------------------------------

tests['[derivation] the ratio is the shipped floor read against the same pool'] = function()
    assert(FLOOR / CALIB_POOL == RATIO, string.format(
        'the ratio %g is no longer the shipped ally floor read as a fraction of '
        .. 'the %d pool (%g)', RATIO, CALIB_POOL, FLOOR / CALIB_POOL))
    -- The same rule GH #227 used on the self floor, applied to this branch's own
    -- constant -- so the two floors keep their shipped relationship (550 > 500)
    -- at every pool rather than crossing at some pool the fix invented.
    assert(RATIO > SELF_FLOOR / CALIB_POOL,
        'the ally ratio no longer sits above the self ratio; the shipped '
        .. 'ordering of the two floors has been inverted by the fix')
    for nMax = 100, POOL_MAX, 50 do
        assert(armed_floor(nMax) >= math.min(SELF_FLOOR, nMax * (SELF_FLOOR / CALIB_POOL)), string.format(
            'at pool %d the armed ally floor dropped below the armed self floor', nMax))
    end
end

tests['[derivation] the armed floor stays stricter than every sibling ally tier'] = function()
    -- Second, independent reason to prefer this ratio: the healing-lotus family
    -- in the same file fires on an ally at 0.6 / 0.5 / 0.5 REMAINING, i.e. 0.4 /
    -- 0.5 / 0.5 missing. 0.55 missing is stricter than all three, so this moves
    -- the salve TOWARD that family without passing its most conservative member.
    local body = read_file(AIUG)
    local nStrictest = 0
    for _, sTier in ipairs({ '0.7, 0.5, 0.6, 3000', '0.6, 0.4, 0.5, 3000', '0.5, 0.3, 0.5, 1200' }) do
        assert(body:find(sTier, 1, true),
            'lotus tier "' .. sTier .. '" moved; this derivation cites it')
        local nAllyRemaining = tonumber(sTier:match('^[%d.]+,%s*[%d.]+,%s*([%d.]+)'))
        local nAllyMissing = 1 - nAllyRemaining
        if nAllyMissing > nStrictest then nStrictest = nAllyMissing end
    end
    assert(nStrictest == 0.5, 'the strictest sibling ally tier moved to ' .. nStrictest)
    assert(RATIO > nStrictest, string.format(
        'the armed ally ratio %g is no longer stricter than the strictest '
        .. 'sibling tier %g -- this fix would now be a loosening past the family',
        RATIO, nStrictest))
end

----------------------------------------------------------------------
-- [frame] a real turbo frame, and one that is in the band
----------------------------------------------------------------------

tests['[frame] a salve holder and a teammate at a third of her health'] = function()
    local _, bot, ally = load_with(nil)
    assert(bot:IsAlive(), HOLDER .. ' is dead on this frame now; the fixture moved')
    assert(ally:IsAlive(), ALLY .. ' is dead on this frame now; the fixture moved')
    assert(bot:GetLevel() == HOLDER_LEVEL, string.format(
        'the frame moved: %s used to be level %d here, now %d',
        HOLDER, HOLDER_LEVEL, bot:GetLevel()))
    assert(DotaTime() == FRAME_T, string.format(
        'fixture clock moved: expected %.1f, got %s', FRAME_T, tostring(DotaTime())))
    assert(GetGameMode() == GAMEMODE_TURBO,
        'the gate is turbo-only, so the anchor has to be a turbo frame')
    assert(bot:GetTeam() == ally:GetTeam(), 'the anchor pair is no longer same-team')
    local nDist = GetUnitToUnitDistance(bot, ally)
    assert(nDist <= PAIR_DIST_MAX, string.format(
        'the pair is %.0fu apart, outside the branch\'s own %du radius', nDist, PAIR_DIST_MAX))
    -- Without the item the dispatcher never reaches this consider at all.
    local bFlask = false
    for i = 0, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == 'item_flask' then bFlask = true end
    end
    assert(bFlask, 'the anchor holder lost their salve; pick another frame')
end

tests['[frame] shipped refuses her at 33% health; armed does not'] = function()
    local _, _, ally = load_with(nil)
    local nMax, nHp = ally:OriginalGetMaxHealth(), ally:OriginalGetHealth()
    assert(nMax == ALLY_MAXHP and nHp == ALLY_HP, string.format(
        'the anchor frame moved: ally hp %g/%g, expected %d/%d', nHp, nMax, ALLY_HP, ALLY_MAXHP))
    local nMissing = nMax - nHp
    assert(nMissing > armed_floor(nMax) and not (nMissing > FLOOR), string.format(
        'the anchor is no longer IN the band this lever opens (missing %g, '
        .. 'shipped floor %d, armed floor %g)', nMissing, FLOOR, armed_floor(nMax)))
    -- What the shipped floor means for this pool, as the fraction it is: she is
    -- at 32.5% health and the file's own lotus comment calls 30% critical.
    local fNow = nHp / nMax
    local fRequired = (nMax - FLOOR) / nMax
    assert(fNow > 0.30 and fNow < 0.35, string.format('the ally is now at %.1f%% health', 100 * fNow))
    assert(fRequired < 0.21, string.format(
        'the shipped floor now lets this pool be healed at %.1f%% health; the '
        .. 'finding was that it does not', 100 * fRequired))
end

tests['[frame] the real helper says the same thing on the real frame'] = function()
    local J, _, ally = load_with(nil)
    assert(not J.SalveAllyMissingEnough(ally),
        'unarmed, the helper must refuse this ally exactly as the shipped line did')
    armed('salveally', function(J2, _, ally2)
        assert(J2.SalveAllyMissingEnough(ally2),
            'armed and turbo, the helper must accept this ally')
    end)
end

----------------------------------------------------------------------
-- [gate] unarmed is the shipped literal, to the number
----------------------------------------------------------------------

tests['[gate] unarmed the floor is exactly the shipped amount, for every pool'] = function()
    local J = load_with(nil)
    assert(J.SALVE_ALLY_MISSING_FLOOR == FLOOR,
        'the shipped ally floor moved to ' .. tostring(J.SALVE_ALLY_MISSING_FLOOR))
    for _, nMax in ipairs({ 230, 538, 582, 692, 1000, 1872, 2566 }) do
        assert(J.SalveAllyMissingFloor(nMax) == FLOOR, string.format(
            'unarmed floor for pool %d: got %s', nMax, tostring(J.SalveAllyMissingFloor(nMax))))
    end
end

tests['[gate] armed and turbo the floor is the pool-relative one'] = function()
    armed('salveally', function(J)
        assert(J.IsModeTurbo(), 'the anchor frame is turbo')
        assert(J.SALVE_ALLY_POOL_RATIO == RATIO,
            'the ratio moved to ' .. tostring(J.SALVE_ALLY_POOL_RATIO))
        assert(J.SalveAllyMissingFloor(ALLY_MAXHP) == ALLY_MAXHP * RATIO, string.format(
            'armed floor for the anchor pool: got %s, expected %g',
            tostring(J.SalveAllyMissingFloor(ALLY_MAXHP)), ALLY_MAXHP * RATIO))
        assert(J.SalveAllyMissingFloor(POOL_MAX) == FLOOR,
            'armed, a large pool must still get the shipped floor')
    end)
end

tests['[gate] no other id in the tree arms this one'] = function()
    for _, sOther in ipairs({ 'salvepool', 'bbshort', 'bbfight', 'basesiege', 'stayfield' }) do
        armed(sOther, function(J)
            assert(J.SalveAllyMissingFloor(ALLY_MAXHP) == FLOOR, string.format(
                "arming '%s' must leave this floor at the shipped %d", sOther, FLOOR))
        end)
    end
end

tests['[gate] the wrong side does not arm it either'] = function()
    local ok, err = pcall(function()
        local J, bot = load_with('salveally', 'radiant')
        assert(bot:GetTeam() == 3, 'the anchor holder used to be dire here')
        assert(not J.IsSoakCandidate('salveally'), 'radiant side must not arm a dire subject')
        assert(J.SalveAllyMissingFloor(ALLY_MAXHP) == FLOOR, 'and the floor stays shipped')
    end)
    os.remove(SIDE_PATH)
    if not ok then error(err, 0) end
end

----------------------------------------------------------------------
-- [source] the tree still says what the model above assumes
----------------------------------------------------------------------

tests['[source] the gate is one conjunct against a mode predicate'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.SalveAllyMissingFloor.-\nend')
    assert(fn ~= nil, 'J.SalveAllyMissingFloor lost its body')
    local gate = fn:match('\n\tif ([^\n]-IsSoakCandidate[^\n]-) then')
    assert(gate ~= nil, 'J.SalveAllyMissingFloor lost its gate line')
    assert(gate == "J.IsModeTurbo() and J.IsSoakCandidate( 'salveally' )",
        'the gate line changed shape: ' .. tostring(gate))
    local _, n = body:gsub("IsSoakCandidate%(%s*'salveally'%s*%)", '')
    assert(n == 1, 'exactly one resolution site for this id; got ' .. tostring(n))
end

tests['[source] the armed value is Min of named constants, not a retyped number'] = function()
    local body = read_file(JMZ)
    assert(body:find('J.SALVE_ALLY_MISSING_FLOOR = 550', 1, true),
        'the shipped ally floor is no longer pinned at 550')
    assert(body:find('J.SALVE_ALLY_POOL_RATIO    = 0.55', 1, true),
        'the ally pool ratio is no longer pinned at 0.55')
    local fn = body:match('function J%.SalveAllyMissingFloor.-\nend')
    assert(fn:find('Min( J.SALVE_ALLY_MISSING_FLOOR, nMaxHealth * J.SALVE_ALLY_POOL_RATIO )', 1, true),
        'the armed value must be Min of the two named constants')
    -- Stronger than "no literal 302.5": the body must carry NO digit at all, so
    -- no pool-relative value can ever be typed in beside the derivation.
    assert(fn:find('%d') == nil,
        'a numeric literal appeared in the floor body; the armed value is derived, '
        .. 'never written down')
end

tests['[source] the three radii the model uses are the ones the branch uses'] = function()
    -- The derivation above is only worth anything if it landed on the numbers
    -- the branch is documented against, so state them here as well: if the tree
    -- moves a radius this fails and the counts get re-read, rather than silently
    -- being counts of a different question.
    assert(PAIR_DIST_MAX == 700, 'the ally search radius moved to ' .. PAIR_DIST_MAX)
    assert(QUIET_RADIUS == 1000, 'the ally branch\'s enemy-list radius moved to ' .. QUIET_RADIUS)
    assert(SELF_QUIET_RADIUS == 900, 'the self branch\'s enemy-list radius moved to ' .. SELF_QUIET_RADIUS)
    local _, fn = salve_consider()
    assert(fn:find('if hNeedHealAlly ~= nil and #hNearbyEnemyHeroList == 0', 1, true),
        'the ally branch no longer gates on the file-level enemy list being empty')
end

tests['[source] the pool is read once, inside the predicate helper'] = function()
    -- Otherwise the subtraction and the floor could read two different numbers,
    -- and the read would sit ahead of the caller's IsValid short-circuit.
    local body = read_file(JMZ)
    local fn = body:match('function J%.SalveAllyMissingEnough.-\nend')
    assert(fn ~= nil, 'J.SalveAllyMissingEnough lost its body')
    local _, nReads = fn:gsub('OriginalGetMaxHealth%(%)', '')
    assert(nReads == 1, 'the pool must be read exactly once here; got ' .. nReads)
    assert(fn:find('J.SalveAllyMissingFloor( nMaxHealth )', 1, true),
        'the predicate no longer passes the local it just read')
end

tests['[source] the call site delegates and the shipped literal is gone'] = function()
    local body = read_file(AIUG)
    assert(body:find('and J.SalveAllyMissingEnough( npcAlly )', 1, true),
        'the ally branch no longer delegates to the helper')
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then
            assert(not line:find('npcAlly:OriginalGetHealth() > 550', 1, true),
                'the shipped literal is still live somewhere in this file')
        end
    end
end

----------------------------------------------------------------------
-- [limit] what this lever does NOT move
----------------------------------------------------------------------

tests['[limit] the self branch and the fountain guard are untouched'] = function()
    local body = read_file(AIUG)
    assert(body:find('if nSelfMaxHealth - bot:OriginalGetHealth() > J.SalveSelfMissingFloor( nSelfMaxHealth )', 1, true),
        'the self branch moved; it is GH #227\'s lever, not this one')
    assert(body:find('if bot:DistanceFromFountain() < 3000 then return BOT_ACTION_DESIRE_NONE end', 1, true),
        'the salve consider lost its fountain guard; the branch domain changed '
        .. 'for a reason that has nothing to do with this lever')
    assert(body:find('a hero at 30%% HP is critical regardless of their max HP pool'),
        'the lotus helper lost the comment this round\'s reasoning cites')
end

return tests

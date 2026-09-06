-- GH #227 -- the salve's self-use gate is the one healing consumable in its own
-- file still asking an ABSOLUTE amount of missing health, and the pool it asks
-- it of varies by a factor of nearly five across the archived turbo frames.
--
-- ability_item_usage_generic's salve consider opens the self-use branch on
--     bot:OriginalGetMaxHealth() - bot:OriginalGetHealth() > <a fixed amount>
-- Forty lines below, the healing-lotus helper -- SAME file, SAME shape (try
-- yourself first, then a nearby ally), SAME DistanceFromFountain( 3000 ) guard,
-- three tiers of the same kind of item -- takes its thresholds as REMAINING
-- ratios, above a comment saying in so many words that ratios are the right
-- form because "a hero at 30% HP is critical regardless of their max HP pool".
-- Both halves of that argument are already in the tree. Only the salve is on
-- the wrong side of it.
--
-- WHAT THIS FILE MEASURES, AND WHAT IT REFUSES TO. Three nested questions, and
-- they get three different numbers rather than one flattering one:
--   1. the LEVER'S OWN CONJUNCT -- how many archived alive hero-frames sit in
--      the band the armed floor opens and the shipped floor refuses;
--   2. + the branch's other corpus-answerable conjunct (no living enemy hero
--      within the 900 the consider itself uses);
--   3. + actually holding a salve, which is what the dispatcher requires before
--      this consider is ever called. THAT NUMBER IS ZERO IN THIS ARCHIVE, it is
--      asserted as zero below, and it is the reason this round asks for no wave
--      and no admission. See [W2].
--
-- WHAT IS PINNED RATHER THAN ASSUMED:
--   [W1] the branch's remaining conjuncts (WasRecentlyDamagedByAnyHero and four
--        heal modifiers) are NOT in any dump. Every count here is a count of
--        frames REACHING the missing-health test, never of a salve drunk.
--   [W2] no archived frame satisfies conjuncts 1-3 at once, so this file cannot
--        buy condition (a) and does not pretend to. The denominator that would
--        is a corpus question, handed on rather than guessed at.
--   [W3] health pools below the shipped floor DO occur in the archive (16 alive
--        frames), which would make the branch a structural zero for those
--        heroes -- but every one of them is the same hero at implausible pool
--        values, i.e. a dump artefact of the GH #176 family, so the structural
--        zero is NOT claimed. The lowest pool this file will call real is the
--        level-1 Crystal Maiden at 538, and 538 is plausible.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
-- [director 2026-08-29, GH #221] Every absolute count below is a SUM OVER
-- FIXTURES, so an equality on it re-states the corpus size and goes red on
-- growth that has nothing to do with this lever.  That is what happened: the
-- 121/64 pin below stood red on trunk while the assertion the whole file exists
-- to make -- `nEndToEnd == 0`, three lines under it -- was never reached at all,
-- because assert() short-circuits the test body.  A scale pin sitting ABOVE a
-- structural claim does not merely cost a re-pin round; it silently stops the
-- claim from being checked.  See tests/corpus_scale.lua for the argument that
-- makes ratchet safe, and for why the zeros here deliberately stay equalities.
local cs = require('corpus_scale')

local FIX  = 'tests/fixtures/f_260819_004858_cm_centaur_far.lua'
local JMZ  = 'bots/FunLib/jmz_func.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'
local ss = require('mock.soak_side')
local SIDE_PATH = ss.PATH                          -- gitignored, farm-only

local SUBJECT  = 'npc_dota_hero_crystal_maiden'
local FRAME_T  = 423.4
local SUBJ_HP, SUBJ_MAXHP, SUBJ_LEVEL = 427, 890, 7

-- The shipped constants, written out so the model below is comparable against
-- the source rather than against a memory of it. [source] pins each one.
local FLOOR = 500     -- the shipped absolute floor, unarmed
local RATIO = 0.5     -- the armed pool ratio
local ALLY_FLOOR = 550  -- the sibling branch this round deliberately does NOT move

-- The band the corpus says the roster actually occupies. [corpus] pins both.
local POOL_MIN_REAL = 538    -- level-1 Crystal Maiden, the smallest plausible pool
-- 2026-09-06 (hero, GH #566): 2646 -> 3666, the chaos_knight of the corpus's
-- first late-game frame (f_260905_004847_lion_drain_bkb.lua).  The RATIO/FLOOR
-- arithmetic below is re-derived from these two constants by the file itself,
-- so it follows the corpus; any prose elsewhere quoting "nearly five to one"
-- was written against the 2646 ceiling.
local POOL_MAX      = 3666

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

-- [GH #365 §3 / GH #229] Arming goes through tests/mock/soak_side.lua, the
-- switch's one owner: the write is read back, the unarmed leg ASSERTS the
-- switch is absent instead of deleting whatever it finds (that unconditional
-- `os.remove` was itself a deleter of other processes' switches), and the
-- switch is re-read after each case body so a concurrent removal is reported
-- as itself rather than as the unarmed floor this file publishes elsewhere.
local function load_with(sCand, sSide)
    if sCand == nil then
        ss.assert_clean('test_salvepool_missing_floor unarmed leg')
    else
        ss.arm(sCand, sSide or 'dire')
    end
    local J, bot = rf.load(FIX, SUBJECT)
    assert(bot ~= nil, 'fixture no longer carries ' .. SUBJECT)
    return J, bot
end

local function armed(sCand, fn, sSide)
    local J, bot = load_with(sCand, sSide)
    local ok, err = pcall(fn, J, bot)
    ss.finish(ok, err)
end

----------------------------------------------------------------------
-- The model. Two floors, and the three nested predicates above.
----------------------------------------------------------------------

local function shipped_floor() return FLOOR end
local function armed_floor(nMaxHealth, nRatio)
    return math.min(FLOOR, nMaxHealth * (nRatio or RATIO))
end

-- The whole archive, read as plain Lua tables (a fixture IS `return { ... }`),
-- so the census costs one dofile per file and never a mock world.
local corpus_cache = nil
local function corpus()
    if corpus_cache ~= nil then return corpus_cache end
    local rows = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    local nFiles = 0
    for path in p:lines() do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                if u.alive and u.max_hp and u.max_hp > 0 then
                    local bFlask = false
                    for _, sItem in ipairs(u.items or {}) do
                        if sItem == 'flask' then bFlask = true end
                    end
                    -- The consider's own radius, asked of living enemy heroes.
                    local bQuiet = true
                    for _, v in ipairs(fx.units) do
                        if v ~= u and v.alive and v.team ~= u.team then
                            local dx, dy = v.x - u.x, v.y - u.y
                            if math.sqrt(dx * dx + dy * dy) <= 900 then bQuiet = false end
                        end
                    end
                    rows[#rows + 1] = {
                        file = path, name = u.name, level = u.level,
                        hp = u.hp, max_hp = u.max_hp, missing = u.max_hp - u.hp,
                        flask = bFlask, quiet = bQuiet,
                    }
                end
            end
        end
    end
    p:close()
    assert(nFiles > 0, 'no fixtures readable; the census below would be a vacuous pass')
    corpus_cache = { rows = rows, files = nFiles }
    return corpus_cache
end

local function count(fPred, nRatio)
    local n = 0
    for _, r in ipairs(corpus().rows) do
        if fPred(r, nRatio) then n = n + 1 end
    end
    return n
end

local function fires_shipped(r) return r.missing > shipped_floor() end
local function fires_armed(r, nRatio) return r.missing > armed_floor(r.max_hp, nRatio) end
local function opened(r, nRatio) return fires_armed(r, nRatio) and not fires_shipped(r) end
local function closed(r, nRatio) return fires_shipped(r) and not fires_armed(r, nRatio) end

----------------------------------------------------------------------
-- [frame] a real turbo frame, and one that is on the point
----------------------------------------------------------------------

tests['[frame] the subject is a focus hero holding a salve on a real turbo frame'] = function()
    local _, bot = load_with(nil)
    assert(bot:IsAlive(), SUBJECT .. ' is dead on this frame now; the fixture moved')
    assert(bot:GetLevel() == SUBJ_LEVEL, string.format(
        'the frame moved: %s used to be level %d here, now %d',
        SUBJECT, SUBJ_LEVEL, bot:GetLevel()))
    assert(DotaTime() == FRAME_T, string.format(
        'fixture clock moved: expected %.1f, got %s', FRAME_T, tostring(DotaTime())))
    assert(GetGameMode() == GAMEMODE_TURBO,
        'the gate is turbo-only, so the anchor has to be a turbo frame')
    -- The frame is only worth anchoring on because the hero owns the item the
    -- consider is registered for -- without that the dispatcher never calls it.
    local bFlask = false
    for i = 0, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == 'item_flask' then bFlask = true end
    end
    assert(bFlask, 'the anchor frame lost its salve; pick another frame or drop the anchor')
end

tests['[frame] shipped, this hero must fall under half health before she may drink'] = function()
    local _, bot = load_with(nil)
    local nMax, nHp = bot:OriginalGetMaxHealth(), bot:OriginalGetHealth()
    assert(nMax == SUBJ_MAXHP and nHp == SUBJ_HP, string.format(
        'the anchor frame moved: hp %g/%g, expected %d/%d', nHp, nMax, SUBJ_HP, SUBJ_MAXHP))
    local nMissing = nMax - nHp
    assert(nMissing > armed_floor(nMax) and not (nMissing > FLOOR), string.format(
        'the anchor is no longer IN the band this lever opens (missing %g, shipped '
        .. 'floor %d, armed floor %g)', nMissing, FLOOR, armed_floor(nMax)))
    -- What the shipped floor means for THIS pool, stated as the fraction it is.
    local fSurvive = (nMax - FLOOR) / nMax
    assert(fSurvive < 0.45, string.format(
        'the shipped floor now lets this pool drink at %.1f%% health; the finding '
        .. 'was that it does not', 100 * fSurvive))
end

----------------------------------------------------------------------
-- [corpus] the pool range, which is the whole defect
----------------------------------------------------------------------

tests['[corpus] the archive is readable and the pools span nearly five to one'] = function()
    local c = corpus()
    assert(c.files >= 100, 'only ' .. c.files .. ' fixtures read; the census is thin')
    assert(#c.rows > 900, 'only ' .. #c.rows .. ' alive hero-frames; the census is thin')
    local nMax = 0
    for _, r in ipairs(c.rows) do
        if r.max_hp > nMax then nMax = r.max_hp end
    end
    assert(nMax == POOL_MAX, 'largest archived pool moved to ' .. nMax)
    -- The smallest pool this file is willing to call real. See [W3].
    local nMinReal = math.huge
    for _, r in ipairs(c.rows) do
        if r.max_hp >= FLOOR and r.max_hp < nMinReal then nMinReal = r.max_hp end
    end
    assert(nMinReal == POOL_MIN_REAL, 'smallest plausible archived pool moved to ' .. nMinReal)
    -- The defect, as a ratio of what the same line asks of the two ends.
    local fSmall = (POOL_MIN_REAL - FLOOR) / POOL_MIN_REAL
    local fLarge = (POOL_MAX - FLOOR) / POOL_MAX
    assert(fSmall < 0.08, string.format('small-pool meaning drifted to %.3f', fSmall))
    assert(fLarge > 0.80, string.format('large-pool meaning drifted to %.3f', fLarge))
end

tests['[W3] the sub-floor pools in the archive are NOT claimed as a structural zero'] = function()
    -- 16 alive frames carry a pool at or below the shipped floor, which would
    -- make the branch unreachable at ANY health for those heroes. Every one of
    -- them is the same hero at pool values no hero has at those levels, so this
    -- is a dump artefact and the zero is refused. If a SECOND hero ever shows
    -- up down there, that refusal is what needs revisiting -- hence the assert.
    local names, n = {}, 0
    for _, r in ipairs(corpus().rows) do
        if r.max_hp <= FLOOR then
            n = n + 1
            names[r.name] = true
        end
    end
    cs.ratchet(n, 16, 'sub-floor alive frames')
    local nDistinct = 0
    for _ in pairs(names) do nDistinct = nDistinct + 1 end
    assert(nDistinct == 1, string.format(
        'sub-floor pools now span %d heroes, not one -- that stops looking like a '
        .. 'dump artefact and starts looking like a structural zero worth claiming',
        nDistinct))
end

----------------------------------------------------------------------
-- [lever] the domain, measured three times and never rounded up
----------------------------------------------------------------------

tests['[lever] the lever\'s own conjunct opens twenty archived frames'] = function()
    local nShipped = count(fires_shipped)
    local nArmed   = count(fires_armed)
    local nOpened  = count(opened)
    -- Not red yet on 2026-08-29, and converted anyway: these are the same
    -- sum-over-fixtures shape as the 121/64 that WAS red, so leaving them as
    -- equalities just schedules the next re-pin round.  The direction that
    -- matters -- a count FALLING, i.e. the lever's domain shrinking -- is what
    -- ratchet keeps.
    cs.ratchet(nShipped, 169, 'missing-health conjunct fires (shipped floor)')
    cs.ratchet(nArmed, 189, 'missing-health conjunct fires (armed floor)')
    assert(nArmed >= nShipped, 'the armed floor fires on fewer frames than the '
        .. 'shipped one, which contradicts the one-directional claim below')
    cs.ratchet(nOpened, 20, 'frames the armed floor opens and the shipped floor refuses')
end

tests['[lever] with the branch\'s other readable conjunct it is ten, not twenty'] = function()
    local nOpened = count(function(r) return opened(r) and r.quiet end)
    cs.ratchet(nOpened, 10, 'frames opened with no enemy hero within 900')
    -- The point of this test is the RELATION, not the literal: the qualified
    -- number must stay strictly below the unqualified one, or "the unqualified
    -- 20 is the looser number and must not be quoted alone" stops being true.
    assert(nOpened < count(opened), string.format(
        'the enemy-proximity conjunct no longer narrows anything: %d of %d',
        nOpened, count(opened)))
end

-- [ratchet] ⭐ THE TAG IS THE POINT OF THIS NAME, not decoration.
-- routine_selfcheck.sh's fast Lua leg discovers files by grepping tests/ for
-- `[detector]`/`[ratchet]`; this file carried neither, so it was invisible to
-- 开工 and its red stood on trunk for a day being read as green every round
-- (the same family as GH #216/#171: an instrument that cannot see a thing
-- reports its absence as health).  Timed before tagging, as the script's own
-- header demands: this file is **sub-second** (measured 2026-08-29, <1s wall
-- for all 19 tests), so the fast set stays a 开工 check.
-- ⚠️ Its sibling red, test_itemdesire_world_assertion.lua, is deliberately NOT
-- tagged: **383s measured the same day**.  That is the GH #124 sweep family the
-- header excludes by name, and tagging it would turn a ~20s selfcheck into a
-- ~7min one -- which is how a check stops being run at all.  The coverage gap
-- that leaves is real and is a scheduling question, not a tagging one; it is
-- written up in DECISIONS_NEEDED.md §14.
tests['[ratchet] [W2] and with the salve actually in the bag it is ZERO'] = function()
    -- The number that decides this round asks for no wave. The dispatcher only
    -- reaches this consider for an item the bot holds, so a frame that opens
    -- the branch end to end must satisfy all three. None does.
    local nHeld = count(function(r) return r.flask end)
    local nHeldQuiet = count(function(r) return r.flask and r.quiet end)
    local nEndToEnd = count(function(r) return opened(r) and r.quiet and r.flask end)
    -- 121/64 -> 124/67 on 2026-08-29: corpus growth, ratcheted.  These two are
    -- CONTEXT for the zero below; they must never again be the reason the zero
    -- goes unchecked.
    cs.ratchet(nHeld, 121, 'salve-holding alive frames')
    cs.ratchet(nHeldQuiet, 64, 'salve-holding alive frames with no enemy within 900')
    -- STAYS an equality: this zero is the [W2] refusal the whole round rests on.
    assert(nEndToEnd == 0, string.format(
        'the archive now HAS %d end-to-end frame(s) -- that is the (a)-evidence '
        .. 'this round said it could not buy, so go buy it', nEndToEnd))
    -- And the control that stops the zero above reading as "the branch is dead":
    -- the SHIPPED floor does fire on salve-holding quiet frames, so the
    -- conjunction is reachable and only this lever's band is unpopulated.
    local nShippedEndToEnd = count(function(r) return fires_shipped(r) and r.quiet and r.flask end)
    assert(nShippedEndToEnd > 0, string.format(
        'shipped end-to-end frames %d; if this is 0 the zero above is about the '
        .. 'branch, not about this lever', nShippedEndToEnd))
    cs.ratchet(nShippedEndToEnd, 7, 'shipped end-to-end frames')
end

tests['[lever] armed is strictly one-directional: it never closes a frame'] = function()
    assert(count(closed) == 0, 'the armed floor closed frames the shipped floor opened')
    -- And exhaustively over a pool/health grid rather than only over the archive,
    -- so a corpus that grows cannot quietly break the direction.
    for nMax = 400, 2600, 50 do
        for nHp = 1, nMax, 37 do
            local nMissing = nMax - nHp
            local bBefore = nMissing > shipped_floor()
            local bAfter  = nMissing > armed_floor(nMax)
            if bBefore then
                assert(bAfter, string.format(
                    'pool %d hp %d fired shipped and no longer fires armed', nMax, nHp))
            end
        end
    end
end

tests['[lever] above a 1000 pool the armed floor IS the shipped floor'] = function()
    -- The other half of one-directional: this lever is not a blanket loosening.
    -- Min pins it to the shipped number for every pool at or above 1000, so the
    -- whole change lives on small pools -- which is what the defect was about.
    for nMax = 1000, 2600, 100 do
        assert(armed_floor(nMax) == FLOOR, string.format(
            'pool %d armed floor is %g, not the shipped %d', nMax, armed_floor(nMax), FLOOR))
    end
    assert(armed_floor(998) < FLOOR, 'pool 998 should be below the shipped floor')
    local nBig = count(function(r) return opened(r) and r.max_hp >= 1000 end)
    assert(nBig == 0, string.format(
        '%d opened frames have a pool at or above 1000; Min is not holding', nBig))
end

----------------------------------------------------------------------
-- [refusal] the looser sibling tier buys more frames and is still refused
----------------------------------------------------------------------

tests['[refusal] the ratio is derived, not fitted to the corpus'] = function()
    -- The sibling lotus family runs three tiers of remaining-HP ratio. Its
    -- LOOSEST tier would buy this lever six end-to-end frames -- the very
    -- evidence [W2] says the archive does not have -- and it is refused anyway,
    -- because a floor that low means drinking with a large fraction of the heal
    -- overflowing, and because picking the constant that maximises the corpus
    -- yield is fitting, not deriving.
    local nLooseEndToEnd = count(function(r) return opened(r, 0.3) and r.quiet and r.flask end)
    assert(nLooseEndToEnd == 6, string.format(
        'the loose tier now buys %d end-to-end frames (was 6); the refusal below '
        .. 'is about the principle, but the size of what is refused should be '
        .. 'stated correctly', nLooseEndToEnd))
    local nLooseOpened = count(function(r) return opened(r, 0.3) end)
    assert(nLooseOpened > 100, 'the loose tier used to open more than a hundred frames')
    -- The derivation actually taken: the shipped floor is itself half of a 1000
    -- pool, so the ratio is the shipped constant's own implied one.
    assert(FLOOR / 1000 == RATIO, string.format(
        'the ratio %g is no longer the shipped floor read as a fraction of a 1000 '
        .. 'pool (%g); the derivation in jmz_func has gone stale', RATIO, FLOOR / 1000))
end

----------------------------------------------------------------------
-- [gate] unarmed is the shipped literal, to the number
----------------------------------------------------------------------

tests['[gate] unarmed the floor is exactly the shipped amount, for every pool'] = function()
    local J = load_with(nil)
    assert(J.SALVE_SELF_MISSING_FLOOR == FLOOR,
        'the shipped floor moved to ' .. tostring(J.SALVE_SELF_MISSING_FLOOR))
    for _, nMax in ipairs({ 230, 538, 669, 890, 1000, 1750, 2566 }) do
        assert(J.SalveSelfMissingFloor(nMax) == FLOOR, string.format(
            'unarmed floor for pool %d: got %s', nMax, tostring(J.SalveSelfMissingFloor(nMax))))
    end
end

tests['[gate] armed and turbo the floor is the pool-relative one'] = function()
    armed('salvepool', function(J)
        assert(J.IsModeTurbo(), 'the fixture frame is turbo')
        assert(J.SALVE_SELF_POOL_RATIO == RATIO,
            'the ratio moved to ' .. tostring(J.SALVE_SELF_POOL_RATIO))
        assert(J.SalveSelfMissingFloor(SUBJ_MAXHP) == SUBJ_MAXHP * RATIO, string.format(
            'armed floor for the anchor pool: got %s, expected %g',
            tostring(J.SalveSelfMissingFloor(SUBJ_MAXHP)), SUBJ_MAXHP * RATIO))
        assert(J.SalveSelfMissingFloor(2566) == FLOOR,
            'armed, a large pool must still get the shipped floor')
    end)
end

tests['[gate] no other id in the tree arms this one'] = function()
    for _, sOther in ipairs({ 'bbshort', 'bbfight', 'bbrespawn', 'basesiege', 'stayfield' }) do
        armed(sOther, function(J)
            assert(J.SalveSelfMissingFloor(SUBJ_MAXHP) == FLOOR, string.format(
                "arming '%s' must leave this floor at the shipped %d", sOther, FLOOR))
        end)
    end
end

tests['[gate] the wrong side does not arm it either'] = function()
    local ok, err = pcall(function()
        local J, bot = load_with('salvepool', 'radiant')
        assert(bot:GetTeam() == 3, 'the subject used to be dire here')
        assert(not J.IsSoakCandidate('salvepool'), 'radiant side must not arm a dire subject')
        assert(J.SalveSelfMissingFloor(SUBJ_MAXHP) == FLOOR, 'and the floor stays shipped')
    end)
    ss.finish(ok, err)
end

----------------------------------------------------------------------
-- [source] the tree still says what the model above assumes
----------------------------------------------------------------------

tests['[source] the gate is one conjunct against a mode predicate'] = function()
    local body = read_file(JMZ)
    local fn = body:match('function J%.SalveSelfMissingFloor.-\nend')
    assert(fn ~= nil, 'J.SalveSelfMissingFloor lost its body')
    local gate = fn:match('\n\tif ([^\n]-IsSoakCandidate[^\n]-) then')
    assert(gate ~= nil, 'J.SalveSelfMissingFloor lost its gate line')
    assert(gate == "J.IsModeTurbo() and J.IsSoakCandidate( 'salvepool' )",
        'the gate line changed shape: ' .. tostring(gate))
    local _, n = body:gsub("IsSoakCandidate%(%s*'salvepool'%s*%)", '')
    assert(n == 1, 'exactly one resolution site for this id; got ' .. tostring(n))
end

tests['[source] the armed value is Min of named constants, not a retyped number'] = function()
    local body = read_file(JMZ)
    assert(body:find('J.SALVE_SELF_MISSING_FLOOR = 500', 1, true),
        'the shipped floor is no longer pinned at 500')
    assert(body:find('J.SALVE_SELF_POOL_RATIO    = 0.5', 1, true),
        'the pool ratio is no longer pinned at 0.5')
    local fn = body:match('function J%.SalveSelfMissingFloor.-\nend')
    assert(fn:find('Min( J.SALVE_SELF_MISSING_FLOOR, nMaxHealth * J.SALVE_SELF_POOL_RATIO )', 1, true),
        'the armed value must be Min of the two named constants')
    assert(not fn:find('250', 1, true),
        'the pool-relative value is derived, never written down')
end

tests['[source] the call site delegates and the shipped literal is gone'] = function()
    local body = read_file(AIUG)
    assert(body:find('if nSelfMaxHealth - bot:OriginalGetHealth() > J.SalveSelfMissingFloor( nSelfMaxHealth )', 1, true),
        'the self-use branch no longer delegates to the helper')
    assert(body:find('local nSelfMaxHealth = bot:OriginalGetMaxHealth()', 1, true),
        'the pool is no longer read once into a local; the helper and the '
        .. 'subtraction could now be reading two different numbers')
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then
            assert(not line:find('OriginalGetHealth() > 500', 1, true),
                'the shipped literal is still live somewhere in this file')
        end
    end
end

----------------------------------------------------------------------
-- [limit] what this lever does NOT move
----------------------------------------------------------------------

tests['[limit] the ally branch of the same function is a separate lever'] = function()
    -- PIN MOVED, NOT LOOSENED (2026-08-26, GH #231). This round's lever was the
    -- SELF branch; the ally branch was left alone and registered in the charter
    -- backlog as the next one, and the next round took it: it is now gated
    -- 'salveally' behind J.SalveAllyMissingEnough, with its own file
    -- (tests/test_salveally_missing_floor.lua). What this assertion exists to
    -- protect is unchanged -- the two branches are separate levers with separate
    -- ids -- so it now pins the delegation instead of the literal it replaced.
    local body = read_file(AIUG)
    assert(body:find('and J.SalveAllyMissingEnough( npcAlly )', 1, true),
        'the ally branch no longer delegates to its own helper')
    local jmz = read_file(JMZ)
    assert(jmz:find('J.SALVE_ALLY_MISSING_FLOOR = ' .. ALLY_FLOOR, 1, true),
        'the ally floor moved off ' .. ALLY_FLOOR .. '; the reasoning below cites it')
    assert(ALLY_FLOOR > POOL_MIN_REAL - 1 and ALLY_FLOOR > FLOOR,
        'the ally floor is no longer above the smallest real pool; the structural '
        .. 'zero GH #231 is built on needs redoing')
    -- And this file's lever must still be the self one only: exactly one live
    -- call site (the comment above it mentions the name too, so count code).
    local n = 0
    for line in body:gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') and line:find('SalveSelfMissingFloor', 1, true) then n = n + 1 end
    end
    assert(n == 1, 'the self helper is called from ' .. n .. ' live sites in this file, not one')
end

tests['[limit] the sibling lotus family and the fountain guard are untouched'] = function()
    local body = read_file(AIUG)
    -- The grounding for the ratio form. If this comment or these tiers go, the
    -- derivation in jmz_func is citing something that is no longer there.
    assert(body:find('a hero at 30%% HP is critical regardless of their max HP pool'),
        'the lotus helper lost the comment this round\'s reasoning cites')
    assert(body:find('ConsiderHealingLotus(h, "lotus",         0.7, 0.5, 0.6, 3000', 1, true),
        'the loosest lotus tier moved; [refusal] cites its ratio')
    assert(body:find('if bot:DistanceFromFountain() < 3000 then return BOT_ACTION_DESIRE_NONE end', 1, true),
        'the salve consider lost its fountain guard; the branch domain changed '
        .. 'for a reason that has nothing to do with this lever')
end

return tests

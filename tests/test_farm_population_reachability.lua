-- [ratchet] [strategy 0NEXT19 / GH #606 family] THE CUSTOM LANING THINK HAS AN
-- UNGATED DOORWAY, AND THAT DOORWAY IS EMPTY ON THE FARM.
--
-- ⭐⭐ THE DISTINCTION THIS FILE EXISTS TO MAKE, because four places in the tree
-- have been using ONE answer for TWO questions:
--
--   (Q1) LIVENESS -- "does this code run in a shipped game with every gate off?"
--        It decides whether a change here needs its own soak gate.
--        ANSWER: YES, and this file does not touch that.  `bCustomLastHit` is
--        true for any hero carrying an override laning module
--        (Utils.BuggyHeroesDueToValveTooLazy, nine heroes) and for a pos-1
--        paired with a HUMAN pos-5.  Both are real in shipped games.
--
--   (Q2) MEASURABILITY -- "can a single-arm A/B wave READ an id that lives
--        behind that doorway?"  It decides how a wave must be launched and how
--        its verdict may be read.
--        ANSWER: NO.  Measured below: on the batch farm both of Q1's
--        populations are EMPTY BY CONSTRUCTION, so the doorway that makes the
--        code live in shipped games passes NOBODY on the farm.
--
-- Answering Q2 with Q1's YES is how an id gets launched single-arm, measures a
-- structural zero, and comes back as "tested, no effect" with nothing raising a
-- hand -- the GH #606 shape.  `check_armed_wiring.py` cannot catch it: WIRED
-- means "a call site exists in this tree", which is a statement about SOURCE,
-- and Q2 is a statement about the POPULATION the wave drafts.
--
-- 📌 THE TRANSFERABLE RULE, sharpened from the 2026-09-15T04:46Z round (which
-- had it as "whether an id is single-arm testable is a property of its helper's
-- call sites, not of the id"):
--     UNGATED IS A PROPERTY OF THE SOURCE.  REACHABLE IS A PROPERTY OF THE
--     POPULATION THE WAVE DRAFTS.  An ungated disjunct that no drafted hero can
--     satisfy is not a doorway, it is a wall with a door painted on it.
--
-- ⛔ WHAT THIS FILE DOES NOT CLAIM.  It does NOT say the three ids behind that
-- doorway ('denyreach', 'deepnum', and by the same door 'hrparity'/'hrreach'/
-- 'hrflee') are wrong, inert in shipped games, or that they should lose their
-- own gates -- Q1 says the opposite and their gates are exactly right.  It says
-- their WAVES must be bundled with a host id, and their single-arm zeros must
-- never be read as "no effect".
--
-- THE THREE MEASUREMENTS, all taken here rather than asserted from prose:
--   1. structure  -- the five flags that stand up the Think, and the exact
--                    disjuncts of the one that is not a soak gate;
--   2. the pool   -- tools/batch_test/soak/hero_pool.txt is the closed list the
--                    soak drafter fills all ten slots from; none of the nine
--                    override heroes is in it;
--   3. the corpus -- the 1039 live hero frames in tests/fixtures carry zero
--                    frames of those nine, and the corpus's hero set is EXACTLY
--                    the drafter's pool, which is why (2) and (3) are one fact
--                    seen twice rather than two independent hopes.
-- plus the launch fact that removes the human pos-5 half: both launchers pass
-- `-fill_with_bots` with `dota_start_ai_game 1`, i.e. ten bots and no human.
--
-- ⚠️ DIRECTION GOES THROUGH COUNTERS PROVED TO COUNT (GH #171).  Every zero
-- below is reported by a function that is called a SECOND time with the legs
-- swapped, where it must report the WHOLE domain (41 heroes / 1039 frames).  A
-- counter whose content is all zeros cannot tell "the domain is empty" from
-- "the walk never ran", and this file's entire content is an empty domain.

local tests = {}

-- ==========================================================================
-- helpers
-- ==========================================================================

--- Engine unit names and the drafter's short names disagree on underscores
--- (`npc_dota_hero_queen_of_pain` vs `queenofpain`, `vengeful_spirit` vs
--- `vengefulspirit`).  Canonicalising by DROPPING the prefix and every
--- underscore is what makes the pool/corpus comparison exact instead of
--- approximately right in two places.
local function canon(sName)
    return (sName:gsub('^npc_dota_hero_', ''):gsub('_', ''))
end

local function slurp(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot read ' .. sPath)
    local s = fh:read('*a')
    fh:close()
    return s
end

local memo = {}
local function facts()
    if memo.done then return memo end

    -- HeroName.X -> "npc_dota_hero_x"
    local map = {}
    for line in io.lines('bots/ts_libs/dota/heroes.lua') do
        local k, v = line:match('^____exports%.HeroName%.(%w+)%s*=%s*"([^"]+)"')
        if k then map[k] = v end
    end
    memo.name_map_size = 0
    for _ in pairs(map) do memo.name_map_size = memo.name_map_size + 1 end

    -- the nine override heroes, resolved through that map (never typed here)
    local utils = slurp('bots/FunLib/utils.lua')
    local blk = assert(utils:match('BuggyHeroesDueToValveTooLazy = {(.-)}'),
        'the override-hero table is gone from bots/FunLib/utils.lua -- '
        .. 're-derive this whole file before trusting any zero in it')
    memo.buggy = {}
    for k in blk:gmatch('%[HeroName%.(%w+)%]') do
        memo.buggy[#memo.buggy + 1] = assert(map[k],
            'HeroName.' .. k .. ' is in the override table but not in '
            .. 'bots/ts_libs/dota/heroes.lua -- an unresolved name would drop '
            .. 'silently out of every count below')
    end

    -- the drafter's closed pool
    memo.pool, memo.pool_n = {}, 0
    for line in io.lines('tools/batch_test/soak/hero_pool.txt') do
        line = line:gsub('%s+$', '')
        if line ~= '' and line:sub(1, 1) ~= '#' then
            memo.pool[canon(line:match('^([^,]+)'))] = true
            memo.pool_n = memo.pool_n + 1
        end
    end

    -- the fixture corpus, walked once
    memo.corpus, memo.live, memo.fixtures = {}, 0, 0
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    for _, path in ipairs(files) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then
            memo.fixtures = memo.fixtures + 1
            for _, u in ipairs(fx.units) do
                if u.alive and u.name and u.name:match('^npc_dota_hero_') then
                    memo.live = memo.live + 1
                    local k = canon(u.name)
                    memo.corpus[k] = (memo.corpus[k] or 0) + 1
                end
            end
        end
    end

    memo.done = true
    return memo
end

--- ONE counter for both directions, called twice with the legs swapped.
--- `tNames` is a list of engine/pool names; returns how many of them the pool
--- admits and how many live corpus frames they hold.
local function census(tNames)
    local F = facts()
    local nInPool, nFrames = 0, 0
    for _, sName in ipairs(tNames) do
        local k = canon(sName)
        if F.pool[k] then nInPool = nInPool + 1 end
        nFrames = nFrames + (F.corpus[k] or 0)
    end
    return nInPool, nFrames
end

-- ==========================================================================
-- 1. Structure: what stands the Think up, and which doorway is not a gate
-- ==========================================================================

tests['[structure] the Think guard is still those five flags'] = function()
    local src = slurp('bots/mode_laning_generic.lua')
    assert(src:find('if bCustomLastHit or bSupLastHit or bLaneFixSupport or '
        .. 'bLaneFixCoreLH or bBodyBlock then', 1, true),
        'the custom laning Think guard changed -- every reachability claim '
        .. 'below is about THAT disjunction and must be re-derived')
end

tests['[structure] four of the five flags are soak gates'] = function()
    local src = slurp('bots/mode_laning_generic.lua')
    for _, sFlag in ipairs({ 'bSupLastHit', 'bLaneFixSupport', 'bLaneFixCoreLH',
        'bBodyBlock' }) do
        local at = assert(src:find('local ' .. sFlag .. ' = ', 1, true),
            sFlag .. ' is gone from the file')
        local decl = src:sub(at, (src:find('\n\n', at, true) or #src))
        assert(decl:find('J.IsSoakCandidate', 1, true),
            sFlag .. ' no longer names J.IsSoakCandidate -- it just became an '
            .. 'ungated doorway into this Think, and the farm-population '
            .. 'measurement below does not cover it')
    end
end

tests['[structure] bCustomLastHit has exactly three disjuncts, one gated']
= function()
    local src = slurp('bots/mode_laning_generic.lua')
    local at = assert(src:find('local bCustomLastHit = ', 1, true),
        'bCustomLastHit is gone; re-derive why the ids behind it carry gates')
    local decl = src:sub(at, (src:find('\n\n', at, true) or #src))
    -- Q1's two ungated disjuncts, named exactly as the code names them.
    assert(decl:find('local_mode_laning_generic', 1, true),
        'bCustomLastHit no longer keys on the override module -- that is the '
        .. 'disjunct sections 2 and 3 price')
    assert(decl:find('J.IsPosxHuman(5)', 1, true),
        'bCustomLastHit no longer keys on a human pos-5 -- that is the '
        .. 'disjunct the launch fact prices')
    assert(decl:find("J.IsSoakCandidate('c3')", 1, true),
        "bCustomLastHit's third disjunct is no longer the 'c3' gate")
    -- A FOURTH ungated disjunct would be a new population, unmeasured here.
    local _, nOr = decl:gsub('\n%s*or ', '')
    assert(nOr == 2, 'bCustomLastHit now has ' .. (nOr + 1) .. ' disjuncts, not '
        .. '3 -- a new one is a new population and this file has not priced it')
end

tests['[structure] the override module loads only for the nine'] = function()
    local src = slurp('bots/mode_laning_generic.lua')
    assert(src:find('if Utils.BuggyHeroesDueToValveTooLazy[botName] then '
        .. 'local_mode_laning_generic = dofile(', 1, true),
        'the override module is no longer loaded off BuggyHeroesDueToValveTooLazy '
        .. '-- the nine-hero domain measured below is no longer this doorway\'s')
end

tests['[structure] a human pos-5 means a non-bot ally'] = function()
    local src = slurp('bots/FunLib/jmz_func.lua')
    local at = assert(src:find('function J.IsPosxHuman(x)', 1, true))
    local body = src:sub(at, at + 600)
    assert(body:find('not ally:IsBot()', 1, true),
        'J.IsPosxHuman no longer tests IsBot -- the launch fact below prices '
        .. 'the human half through exactly that test')
end

-- ==========================================================================
-- 2. The pool: the drafter cannot draft any of the nine
-- ==========================================================================

tests['[pool] the nine and the forty-one both parsed'] = function()
    local F = facts()
    assert(#F.buggy == 9, 'the override table now lists ' .. #F.buggy
        .. ' heroes, not 9 -- re-price the doorway')
    assert(F.pool_n == 41, 'the soak pool now lists ' .. F.pool_n
        .. ' heroes, not 41 -- re-run this census against the new pool')
    assert(F.name_map_size > 100, 'the HeroName map parsed only '
        .. F.name_map_size .. ' names; a short map would resolve the nine into '
        .. 'nothing and every zero below would be an artefact')
end

tests['[pool] ⭐ none of the nine is draftable on the farm'] = function()
    local F = facts()
    local nInPool = census(F.buggy)
    assert(nInPool == 0, nInPool .. ' of the nine override heroes are now in '
        .. 'the soak pool -- the ungated doorway is no longer empty on the '
        .. 'farm, and the ids behind it may be single-arm testable again')
end

tests['[pool] the same counter, legs swapped, reports the whole pool']
= function()
    local F = facts()
    local tPool = {}
    for k in pairs(F.pool) do tPool[#tPool + 1] = k end
    local nInPool = census(tPool)
    assert(nInPool == 41, 'the pool census answered ' .. nInPool
        .. ' for the pool itself -- the comparator that reported 0 above '
        .. 'cannot be trusted to have run')
end

-- ==========================================================================
-- 3. The corpus: the same emptiness, seen a second way
-- ==========================================================================

tests['[corpus] the walk covered the corpus it thinks it did'] = function()
    local F = facts()
    assert(F.fixtures >= 100, 'the fixture walk loaded only ' .. F.fixtures
        .. ' files')
    assert(F.live >= 1000, 'the fixture walk found only ' .. F.live
        .. ' live hero frames -- a short walk makes every zero below cheap')
end

tests['[corpus] ⭐ the nine hold zero live frames'] = function()
    local F = facts()
    local _, nFrames = census(F.buggy)
    assert(nFrames == 0, 'the corpus now carries ' .. nFrames .. ' live frames '
        .. 'of the nine override heroes -- a fixture for the override laning '
        .. 'module is possible again, and so is pricing its deny branch')
end

tests['[corpus] the same counter, legs swapped, reports every frame']
= function()
    local F = facts()
    local tPool = {}
    for k in pairs(F.pool) do tPool[#tPool + 1] = k end
    local _, nFrames = census(tPool)
    assert(nFrames == F.live, 'the pool heroes account for ' .. nFrames
        .. ' of ' .. F.live .. ' live frames; the counter that reported 0 for '
        .. 'the nine is not reading the same corpus')
end

tests['[corpus] ⭐ the corpus hero set IS the drafter pool'] = function()
    local F = facts()
    local nBoth, tCorpusOnly, tPoolOnly = 0, {}, {}
    for k in pairs(F.corpus) do
        if F.pool[k] then nBoth = nBoth + 1 else tCorpusOnly[#tCorpusOnly + 1] = k end
    end
    for k in pairs(F.pool) do
        if not F.corpus[k] then tPoolOnly[#tPoolOnly + 1] = k end
    end
    table.sort(tCorpusOnly); table.sort(tPoolOnly)
    assert(#tCorpusOnly == 0, 'the corpus carries heroes the drafter cannot '
        .. 'draft (' .. table.concat(tCorpusOnly, ' ') .. ') -- it is no longer '
        .. 'an image of the pool, so the pool census no longer transfers to it')
    assert(#tPoolOnly == 0, 'the pool carries heroes the corpus has never seen ('
        .. table.concat(tPoolOnly, ' ') .. ') -- the two measurements have '
        .. 'drifted apart and the nine\'s zero now rests on only one of them')
    assert(nBoth == F.pool_n, 'corpus/pool overlap is ' .. nBoth .. ', pool is '
        .. F.pool_n)
end

-- ==========================================================================
-- 4. The launch fact: no human pos-5 exists on a farm instance
-- ==========================================================================

tests['[launch] both launchers fill every slot with bots'] = function()
    for _, sPath in ipairs({ 'tools/batch_test/run_batch.sh',
        'tools/batch_test/soak/soak_loop.sh' }) do
        local s = slurp(sPath)
        assert(s:find('-fill_with_bots', 1, true),
            sPath .. ' no longer passes -fill_with_bots -- a human slot would '
            .. 'reopen J.IsPosxHuman(5) and with it the second ungated '
            .. 'disjunct this file prices at zero')
    end
    local s = slurp('tools/batch_test/run_batch.sh')
    assert(s:find('dota_start_ai_game 1', 1, true),
        'run_batch.sh no longer auto-starts an AI game')
end

-- ==========================================================================
-- 5. The consequence, derived from 1-4 rather than asserted from prose
-- ==========================================================================

tests['[consequence] ⭐⭐ every doorway into this Think is gated on the farm']
= function()
    local F = facts()
    -- The five flags, as sections 1 and 2-4 price them on a FARM instance.
    local nInPool = census(F.buggy)
    local tDoorways = {
        { flag = 'bCustomLastHit/override-module', gated = false,
          farm_population = nInPool },                     -- section 2
        { flag = 'bCustomLastHit/human-pos5',      gated = false,
          farm_population = 0 },                           -- section 4
        { flag = 'bCustomLastHit/c3',              gated = true },
        { flag = 'bSupLastHit',                    gated = true },
        { flag = 'bLaneFixSupport',                gated = true },
        { flag = 'bLaneFixCoreLH',                 gated = true },
        { flag = 'bBodyBlock',                     gated = true },
    }
    local nOpen = 0
    for _, d in ipairs(tDoorways) do
        if not d.gated and (d.farm_population or 0) > 0 then nOpen = nOpen + 1 end
    end
    assert(nOpen == 0, nOpen .. ' ungated doorway(s) into the custom laning '
        .. 'Think now admit farm-drafted heroes -- the BUNDLE-ONLY constraint '
        .. 'on the ids behind it can be lifted, DELIBERATELY, after re-reading '
        .. 'state.json and the wave request in iterations/queue.json')
end

return tests

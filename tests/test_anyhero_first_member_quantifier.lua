-- [anyhero 20260910] A SET WAS COMPUTED, AND THEN HANDED TO A RULER THAT
-- MEASURES ONLY ITS FIRST MEMBER.
--
-- THE DEFECT (charter criterion (5); the variant the previous round named on its
-- way out was "IsValidHero fed a non-hero list" -- that scan came back EMPTY in
-- this group's scope, see section 6 -- and the shape that was actually sitting
-- there is its neighbour: the ruler is fed the right KIND of thing, just one of
-- them). bots/FunLib/aba_special_units.lua:
--     function X.IsHeroWithinRadius(tUnits, nRadius)
--         if J.IsValidHero(tUnits[1]) and J.IsInRange(bot, tUnits[1], nRadius) then
-- Its one caller (:203) asks an existential question --
--     if not X.IsHeroWithinRadius(tEnemyHeroes, botAttackRange - 130)
--     then return 0.96 end
-- -- and the list it hands over is J.GetEnemiesNearLoc(bot:GetLocation(), 1600),
-- which table.inserts in GetUnitList(UNIT_LIST_ENEMY_HEROES) iteration order and
-- contains no sort of any kind (section 1b reads that off the shipped source).
-- So `[1]` is an ARBITRARY member of the set, not the nearest one. Section 1a
-- measures it on the frame corpus: on 142 of the 262 rows carrying two or more
-- heroes, `[1]` is not the nearest -- 141 of those strictly farther.
--
-- WHAT THAT COSTS. When the close hero is not the one at `[1]`, the helper
-- answers false, the caller reads that as "nobody is on me", and the bot returns
-- desire 0.96 -- near-max -- to walk up and hit a SUMMON (grimstroke ink
-- creature / weaver swarm / tidehunter anchor) with an enemy hero standing
-- inside its attack range. The branch above it (`if #tEnemyHeroes == 0 then
-- return 0.9 end`) already spends a line distinguishing "no heroes at all" from
-- "no hero CLOSE", so the helper is unambiguously meant to answer the second.
--
-- WHY THE LOOP IS THE INTENDED READING -- condition (c) is inside this file, not
-- on a wiki. Section 5 counts it rather than asserting it in prose: every other
-- existential helper in aba_special_units.lua quantifies over the whole set
-- (X.IsBeingAttackedByHero, directly above it; X.IsThereSentry;
-- X.GetTotalAttackDamage; X.GetTotalUnitHealth). X.IsHeroWithinRadius is the
-- only one that reads `[1]` and stops.
--
-- ⭐ THE WHOLE CHANGE IS GATED, and that is a DIFFERENCE from 'tombhp', not a
-- copy of it. There, the shipped ruler RAISED, so un-raising it had to be
-- unconditional and the unarmed leg was deliberately not byte-identical to
-- shipped. Here the shipped ruler merely ANSWERS FALSE. Nothing has to be
-- repaired outside the gate, the unarmed leg IS the shipped bytes, and section
-- 3b measures that equality on every driven row rather than asserting it from
-- the diff. The loop starts at 2 because element 1 is already decided above.
--
-- ⛔ WHAT THIS CORPUS CANNOT BUY, said before any number below is read.
--   * THE MOCK'S ENEMY LIST CONTAINS THE QUERYING HERO ITSELF. On these frames
--     GetUnitList(UNIT_LIST_ENEMY_HEROES) answers with the asking hero's own
--     side, self included -- an `axe@0` row. Section 4a measures it (121 self
--     entries over the frames/ half alone). Every count in sections 1-3
--     therefore runs on the list with self REMOVED, and what it measures is the
--     GEOMETRY of a set of heroes with real dump positions -- NOT enemy
--     semantics. No fire rate in a real game is claimed from any of it.
--   * GetAttackRange() is the mock default 150 on all 1270 live rows (section
--     4b), not the dump's value, so the caller's true radius
--     (botAttackRange - 130) is not in this corpus either. Section 2 reports a
--     radius SWEEP for that reason, and no single rate anywhere is "the" rate.
--   * The outer guard -- an enemy summon of one of three names within 1600 --
--     is not in the corpus at all (section 4c). ⇒ 'anyhero' is FROZEN-HOLD per
--     P4.2: registered in state.json:anyhero_20260910, NOT requested into the
--     armed set.
--
-- HOW SECTION 3 DRIVES IT. The helper is not replicated here: its body is lifted
-- VERBATIM out of bots/FunLib/aba_special_units.lua, compiled with loadstring
-- and run under setfenv. Everything it reads is listed one by one, and only the
-- last is injected:
--     J                  real jmz_func from the fixture loader
--     bot                a real dump hero (the helper's module-local `bot`)
--     tUnits             that hero's real J.GetEnemiesNearLoc(loc, 1600),
--                        self removed
--     J.IsModeTurbo      real
--     J.IsSoakCandidate  INJECTED: the arm under test
-- Section 3d then MUTATES the lifted text back to a `[1]`-only body and re-runs
-- it through the same machinery: the armed leg must stop firing. The defect and
-- its repair are read off ONE apparatus, not two.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local SU = 'bots/FunLib/aba_special_units.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'
local CAND = 'anyhero'

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block names the
--- id, the caller and the loop, so an unstripped read would let a COMMENT
--- satisfy the structural assertions in sections 5 and 6.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local function corpus_paths()
    local out = {}
    for _, glob in ipairs({ 'tests/fixtures/*.lua', 'tests/frames/*.lua' }) do
        local p = assert(io.popen('ls ' .. glob .. ' 2>/dev/null'),
            'could not list ' .. glob)
        for line in p:lines() do out[#out + 1] = line end
        p:close()
    end
    assert(#out > 100, 'expected the frame corpus, got ' .. #out)
    return out
end

--- The helper's body, lifted verbatim from the shipped file. The function's own
--- terminating `end` is the only one at column 0; every `end` inside it is
--- indented, which is what makes the '\nend' anchor safe here.
local function helper_src()
    local src = stripped(read_file(SU))
    local s = src:find('function X.IsHeroWithinRadius(tUnits, nRadius)', 1, true)
    assert(s ~= nil, 'X.IsHeroWithinRadius is gone from ' .. SU)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.IsHeroWithinRadius in ' .. SU)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

--- Compile a lifted body into a callable under a controlled environment.
local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.IsHeroWithinRadius', name))
    setfenv(fn, env)
    return fn()
end

-- ------------------------------------------------------------- the sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 150, 300, 470, 600, 800, 1000, 1200 }

    for _, path in ipairs(corpus_paths()) do
        local ok, J, _, heroes, fx = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames_loaded')
            for _, u in ipairs(fx.units) do
                local h = heroes[u.name]
                if h ~= nil and u.alive then
                    bump('live')
                    if h:GetAttackRange() == 150 then bump('range_mockdefault') end

                    -- The caller's own read, byte for byte.
                    local raw = J.GetEnemiesNearLoc(h:GetLocation(), 1600)
                    local list = {}
                    -- The two reads are deliberately separate statements: 4a
                    -- must keep counting self even when a mutant stops the
                    -- exclusion, or the stand cannot tell "the bound moved"
                    -- apart from "the measurement collapsed" (M7).
                    for i = 1, #raw do
                        if raw[i] == h then bump('self_in_list') end
                        if raw[i] ~= h then list[#list + 1] = raw[i] end
                    end

                    -- The outer guard: is any of the three summon names here?
                    for _, e in pairs(GetUnitList(UNIT_LIST_ENEMIES)) do
                        local n = e.GetUnitName and e:GetUnitName() or ''
                        if n:find('grimstroke_ink_creature', 1, true)
                            or n:find('weaver_swarm', 1, true)
                            or n:find('tidehunter_anchor', 1, true) then
                            bump('summon_present')
                        end
                    end

                    if #list >= 1 then
                        bump('ge1')
                        local d1 = GetUnitToUnitDistance(h, list[1])
                        local best, bi = d1, 1
                        for i = 2, #list do
                            local d = GetUnitToUnitDistance(h, list[i])
                            if d < best then best, bi = d, i end
                        end
                        -- Anti-contamination. Two hero handles at distance 0 is
                        -- not geometry, it is the same unit twice -- which is
                        -- exactly what this corpus hands over if the self
                        -- exclusion above ever stops working. It has to be a
                        -- ZERO claim: every count below is a ratchet, i.e. a
                        -- FLOOR, so self-contamination RAISES all of them and
                        -- not one would go red (measured -- M7 survived the
                        -- stand until this counter existed).
                        if best < 1 then bump('best_zero') end
                        if #list >= 2 then
                            bump('ge2')
                            if bi ~= 1 then bump('e1_not_nearest') end
                            if d1 > best + 1 then bump('e1_strictly_farther') end
                        end

                        -- 2. the radius sweep. `miss_rN` is the population this
                        --    lever changes: [1] is outside, somebody else is in.
                        for _, r in ipairs(RADII) do
                            if best <= r then bump('any_r' .. r) end
                            if d1 > r and best <= r then bump('miss_r' .. r) end
                        end

                        -- 3. the helper itself, driven on its own shipped bytes,
                        --    over the rows the lever is actually about.
                        local R = 470
                        if d1 > R and best <= R and J.IsModeTurbo() then
                            bump('drives')

                            local armed = false
                            local realSoak = J.IsSoakCandidate
                            J.IsSoakCandidate = function(sId)
                                if sId ~= CAND then return realSoak(sId) end
                                return armed
                            end
                            local env = setmetatable({ J = J, bot = h },
                                { __index = _G })

                            local fn = compile(BODY, env, 'anyhero_body')
                            local okOff, rOff = pcall(fn, list, R)
                            if okOff then bump('off_no_error') end
                            if okOff and rOff == false then bump('off_false') end

                            armed = true
                            local okOn, rOn = pcall(fn, list, R)
                            if okOn then bump('on_no_error') end
                            if okOn and rOn == true then bump('on_true') end

                            -- 3d. a `[1]`-only body -- the shipped quantifier --
                            --     back through the same apparatus. Counted, not
                            --     asserted, so a no-op mutation cannot kill the
                            --     file at load time (the tombhp M4/M5 lesson).
                            local mut = BODY:gsub('for i = 2, #tUnits do',
                                'for i = 2, 1 do')
                            if mut == BODY then bump('mut_noop') end
                            local gn = compile(mut, env, 'anyhero_mut')
                            local okMut, rMut = pcall(gn, list, R)
                            if okMut and rMut == false then bump('mut_false') end

                            J.IsSoakCandidate = realSoak
                        end
                    end
                end
            end
        end
    end
    return c
end)()

local function C(k) return SWEEP[k] end

-- Every counter is a SUM OVER FRAMES, so appending a fixture can only raise it:
-- cs.ratchet still catches the FALL that would mean behaviour moved, and stops
-- charging this file for corpus growth (GH #106/#127). The zero claims stay
-- equalities on purpose -- zero is already growth-immune, and the bounds in the
-- header are argued from them.
tests['[anyhero] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' frames failed to load')
    cs.corpus(C('frames_loaded'), 'anyhero sweep')
    cs.ratchet(C('live'), 1270, 'live hero frames')
end

-- ------------------------------ 1. the list is not in the order [1] implies --

tests['[anyhero] 1a. MEASURED: the first member is not the nearest one'] = function()
    cs.ratchet(C('ge1'), 693, 'rows with at least one other hero within 1600')
    cs.ratchet(C('ge2'), 262, 'rows carrying two or more')

    -- 142/262 registered. Both directions matter: if [1] were always nearest the
    -- helper would be right by accident, and if it were never nearest the sweep
    -- would be measuring something other than a list order.
    cs.ratchet(C('e1_not_nearest'), 142, 'rows where [1] is not the nearest')
    cs.ratchet(C('e1_strictly_farther'), 141, 'rows where [1] is strictly farther')
    assert(C('best_zero') == 0,
        C('best_zero') .. ' row(s) put a "different" hero at distance 0 from the '
        .. 'asking one. That is the asking hero back in its own list (4a), not '
        .. 'geometry: every count in this file is a ratchet, so the '
        .. 'contamination would only ever raise them and nothing else here can '
        .. 'go red. Fix the self exclusion in the sweep before reading on.')
    assert(C('e1_not_nearest') < C('ge2'),
        '[1] is never the nearest on any of the ' .. C('ge2') .. ' multi-hero rows '
        .. '-- that is not an unsorted list, it is a reversed one; re-read the '
        .. 'producer before quoting anything below')
end

tests['[anyhero] 1b. the producer contains no sort, read off the shipped source']
= function()
    local src = stripped(read_file(JMZ))
    local s = src:find('function J.GetEnemiesNearLoc', 1, true)
    assert(s ~= nil, 'J.GetEnemiesNearLoc is gone from ' .. JMZ)
    local e = src:find('\nend', s, true)
    local body = src:sub(s, e)
    assert(body:find('table.insert(enemies, enemyHero)', 1, true) ~= nil,
        'J.GetEnemiesNearLoc no longer builds its list by table.insert')
    assert(body:find('sort', 1, true) == nil,
        'J.GetEnemiesNearLoc now sorts its result -- if it sorts by distance the '
        .. 'whole premise of anyhero is gone and the gate must be re-argued, not '
        .. 're-baselined')
end

-- ------------------------------------- 2. the population the lever changes --

tests['[anyhero] 2. MEASURED: a radius sweep, because the true radius is not in '
    .. 'this corpus'] = function()
    -- Registered: 21 / 49 / 61 / 60 / 51 / 43 / 35 at r = 150 / 300 / 470 / 600
    -- / 800 / 1000 / 1200. Reported as a sweep, never as "the" rate: the caller
    -- computes botAttackRange - 130 and GetAttackRange() is mock here (4b).
    local reg = { r150 = 21, r300 = 49, r470 = 61, r600 = 60, r800 = 51,
                  r1000 = 43, r1200 = 35 }
    for k, v in pairs(reg) do
        cs.ratchet(C('miss_' .. k), v,
            'rows where [1] is outside ' .. k .. ' but another hero is inside')
    end
    -- Anti-vacuum in the other direction: the misses must be a SUBSET of the
    -- rows that have anybody in range at all, or the sweep is miscounting.
    for k in pairs(reg) do
        assert(C('miss_' .. k) <= C('any_' .. k),
            'miss_' .. k .. ' (' .. C('miss_' .. k) .. ') exceeds any_' .. k
            .. ' (' .. C('any_' .. k) .. ') -- the sweep is double counting')
    end
end

-- ------------------------- 3. the helper, driven on its own shipped bytes ---

tests['[anyhero] 3a. the drive ran on real geometry, all of it Turbo'] = function()
    cs.ratchet(C('drives'), 61, 'rows driven at r=470')
    assert(C('drives') == C('miss_r470'),
        'the drive population (' .. C('drives') .. ') no longer equals the r=470 '
        .. 'miss population (' .. C('miss_r470') .. ') -- one of them stopped '
        .. 'being the thing this lever is about')
end

tests['[anyhero] 3b. UNARMED: the shipped answer, false, on every driven row']
= function()
    cs.universal(C('off_no_error'), C('drives'),
        'the unarmed leg completes without raising', 20)
    -- This is the byte-identity claim, MEASURED rather than read off the diff:
    -- every one of these rows is a row where the shipped `[1]` test fails, so a
    -- true here would mean the gate leaks.
    cs.universal(C('off_false'), C('drives'),
        'and it answers false -- exactly what shipped answers', 20)
end

tests['[anyhero] 3c. ARMED: the helper finds the hero that is actually close']
= function()
    cs.universal(C('on_no_error'), C('drives'),
        'the armed leg completes without raising', 20)
    cs.universal(C('on_true'), C('drives'),
        'and it answers true on every row where a hero IS inside the radius', 20)
end

tests['[anyhero] 3d. the SHIPPED quantifier, restored into the same apparatus, '
    .. 'stops firing again'] = function()
    assert(C('mut_noop') == 0,
        'the 3d mutation was a NO-OP on ' .. C('mut_noop') .. ' rows: the lifted '
        .. 'body no longer contains the `for i = 2, #tUnits` loop, which means '
        .. 'the gate is no longer what makes the difference')
    cs.universal(C('mut_false'), C('drives'),
        'collapsing the loop back to [1] returns false on every driven row', 20)
end

-- ---------------------- 4. the bounds, measured rather than cited as prose ---

tests['[anyhero] 4a. BOUND: the corpus enemy list contains the asking hero itself']
= function()
    -- Not a defect in bots/ -- a property of the loader. It is asserted here so
    -- that the day the loader starts answering with the opposing side, this goes
    -- red and the sections above get re-taken against real enemy semantics
    -- instead of quietly meaning something else. A baton pinned as an assertion,
    -- not as an issue that can be closed (the GH #13 shape).
    assert(C('self_in_list') > 0,
        'the corpus enemy list no longer contains the querying hero. If the '
        .. 'loader now answers with the OPPOSING side, sections 1-3 are measuring '
        .. 'enemy semantics for the first time: re-take them and re-price anyhero '
        .. 'for admission rather than re-baselining these counters.')
end

tests['[anyhero] 4b. BOUND: GetAttackRange is the mock default on every row']
= function()
    cs.universal(C('range_mockdefault'), C('live'),
        'every live row reports attack range 150', 100)
end

tests['[anyhero] 4c. BOUND: the outer guard has no rows in this corpus'] = function()
    -- Stated as an equality on purpose: it is the reason no fire-rate claim is
    -- made anywhere above and the reason this id is FROZEN-HOLD. If a frame
    -- carrying one of the three summons ever lands, this goes red and the
    -- question -- "can the branch now be seen end to end?" -- comes back with it.
    assert(C('summon_present') == 0,
        C('summon_present') .. ' frame(s) now carry a grimstroke/weaver/tidehunter '
        .. "summon. The bound in this file's header no longer holds: re-take the "
        .. "caller's reachability end to end on those frames, and re-price "
        .. 'anyhero for admission.')
end

-- ------------- 5. condition (c), counted in the file rather than argued in prose --

tests['[anyhero] 5. every OTHER existential helper in the file quantifies over '
    .. 'the whole set'] = function()
    local src = stripped(read_file(SU))
    -- The four siblings named in the header. Each must still contain a loop over
    -- its own set; if one of them ever collapses to `[1]` too, the "only one"
    -- sentence in the header is wrong and the argument for the loop weakens.
    for _, name in ipairs({ 'X.IsBeingAttackedByHero', 'X.IsThereSentry',
                            'X.GetTotalAttackDamage', 'X.GetTotalUnitHealth' }) do
        local s = src:find('function ' .. name, 1, true)
        assert(s ~= nil, name .. ' is gone from ' .. SU)
        local e = src:find('\nend', s, true)
        local body = src:sub(s, e)
        assert(body:find('for ', 1, true) ~= nil,
            name .. ' no longer loops over its set -- the header claims it as '
            .. 'evidence that the loop is this file\'s own idiom')
    end
end

tests['[anyhero] 5b. the caller still asks the existential question this lever '
    .. 'is about'] = function()
    local src = stripped(read_file(SU))
    -- A lever whose caller has been rewritten around it is inert while every
    -- behavioural assertion above stays green -- the cheapest way for this work
    -- to LOOK landed. Pin the call site itself, not a count of call sites.
    local at = src:find(
        'X.IsHeroWithinRadius(tEnemyHeroes, botAttackRange - 130)', 1, true)
    assert(at ~= nil,
        'the :203 call site no longer reads '
        .. 'X.IsHeroWithinRadius(tEnemyHeroes, botAttackRange - 130). If the '
        .. 'caller was rewritten, anyhero may now be gating nothing: re-read what '
        .. 'asks this question before re-baselining anything above.')
    assert(src:find('local tEnemyHeroes = J.GetEnemiesNearLoc(bot:GetLocation(), 1600)',
        1, true) ~= nil,
        'tEnemyHeroes is no longer J.GetEnemiesNearLoc(loc, 1600) -- section 1b '
        .. 'argues the unsortedness off THAT producer')
    -- Count CALLS, not mentions: the definition line matches the same name and
    -- was scored as a second caller on the first run of this file.
    local _, nAll = src:gsub('X%.IsHeroWithinRadius%(', '')
    local _, nDef = src:gsub('function X%.IsHeroWithinRadius%(', '')
    assert(nDef == 1, SU .. ' defines X.IsHeroWithinRadius ' .. nDef .. ' times')
    assert(nAll - nDef == 1,
        'X.IsHeroWithinRadius now has ' .. (nAll - nDef) .. ' callers, not 1 -- the '
        .. 'blast radius of this gate changed and the header no longer describes it')
end

-- --------------------------------------------- 6. the gate, structurally ---

tests['[anyhero] 6. the gate is turbo-only, single, and sits after the shipped '
    .. 'test'] = function()
    local atTurbo = BODY:find('J.IsModeTurbo()', 1, true)
    local atGate = BODY:find("J.IsSoakCandidate('" .. CAND .. "')", 1, true)
    local atShipped = BODY:find('J.IsValidHero(tUnits[1])', 1, true)
    assert(atGate ~= nil, 'the ' .. CAND .. ' gate is gone from the helper')
    assert(atTurbo ~= nil and atTurbo < atGate,
        'the gate is not turbo-only, or turbo is not read first')
    assert(atShipped ~= nil and atShipped < atGate,
        'the shipped [1] test no longer runs before the gate -- the unarmed leg '
        .. 'must reach `return false` by exactly the path it does today')
    local atLoop = BODY:find('for i = 2, #tUnits do', 1, true)
    assert(atLoop ~= nil,
        'the `for i = 2, #tUnits` loop is gone from the helper -- section 3d '
        .. 'mutates exactly that text, so without it the stand is scoring a no-op')
    assert(atLoop > atGate, 'the loop is no longer inside the gate')

    -- The gate must not be nested inside another id's gate: an id reachable only
    -- while a second id is armed is frozen FALSE the day that second id is
    -- promoted (the 'pullcad' lesson, AGENTS.md).
    local _, nGates = BODY:gsub('J%.IsSoakCandidate%(', '')
    assert(nGates == 1, 'the helper reads ' .. nGates .. ' soak gates, expected 1')
end

return tests

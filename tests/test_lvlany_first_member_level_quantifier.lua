-- [lvlany 20260910] AN EXISTENTIAL QUESTION ABOUT *LEVEL* ANSWERED BY THE
-- NEAREST HERO -- AND THE LIST IS CORRECTLY SORTED, WHICH IS WHAT MAKES THIS
-- ONE DIFFERENT.
--
-- THE DEFECT (charter criterion (5), the variant named on the previous round's
-- way out: "the ruler is fed the right KIND of thing, just one member of the
-- set"). bots/mode_team_roam_generic.lua, X.SupportFindTarget's laning
-- last-hit/deny guard:
--     local nNearbyEnemyHeroes = J.GetNearbyHeroes(bot, 750, true, BOT_MODE_NONE)
--     if IsModeSuitHit and bot:GetLevel() <= 8
--     ...
--     and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10)
-- The empty-list leg written right beside it (`[1] == nil`) is what proves the
-- question is existential: the author already spent a term separating "nobody
-- here" from "somebody here who is weak". What the expression actually answers
-- is "is the NEAREST one weak".
--
-- ⭐ WHY THIS IS NOT A SECOND COPY OF 'anyhero'. That lever rested on a measured
-- fact about ORDER: J.GetEnemiesNearLoc table.inserts in GetUnitList order and
-- never sorts, so `[1]` was an arbitrary member. Here the list is ordered and
-- correctly so -- the engine promises it (docs/BOT_API_REFERENCE.md:1229) and
-- J.GetNearbyHeroes only filters (jmz_func.lua:2856). Section 1b pins BOTH of
-- those rather than assuming them. `[1]` is genuinely the nearest visible enemy
-- hero, and the guard is still wrong, because the predicate being quantified is
-- LEVEL: section 1a measures that the nearest is not the highest-level one on 43
-- of the 135 rows carrying two or more. An engine change that started sorting
-- these lists would repair 'anyhero' and would not touch this.
--
-- WHAT IT COSTS. The guard is the safety half of a branch returning
-- BOT_MODE_DESIRE_ABSOLUTE * 0.97 -- walk up and last-hit/deny in lane. When the
-- nearest enemy is the level-5 support and the level-12 offlaner is the other
-- name inside the same 750, the guard reads "clear" and a bot capped at level 8
-- by the term above it commits to the creep wave with a hero four levels up
-- inside kill range. Section 2 counts that population at the shipped radius and
-- threshold: 7 rows, and it is a SWEEP because 7 is one cell of it.
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT BUY, said before any number below is read.
--   * IT CAN BUY ENEMY SEMANTICS, and that is a real difference from the
--     previous two rounds. This producer is bot:GetNearbyHeroes, which the
--     loader restores from dump ground truth with a team comparison, a vision
--     check, self excluded, and a distance sort (mock/replay_fixture.lua:1372).
--     Section 4a asserts the self-exclusion as an EQUALITY so that the day it
--     stops holding, every count here goes red instead of quietly drifting.
--   * IT CAN BUY REAL LEVELS: `GetLevel` is dump ground truth
--     (mock/replay_fixture.lua:666) and section 4b measures the spread rather
--     than trusting it -- 66 of the 135 multi-hero rows carry two different
--     levels. A corpus of uniform levels would make sections 1-3 vacuous while
--     leaving them green.
--   * IT CANNOT BUY A FIRE RATE. The branch's other terms -- IsModeSuitHit,
--     GetNetWorth, WasRecentlyDamagedByAnyHero, the two fountain distances --
--     are not driven here, and section 4c reports the one of them that IS
--     readable (bot:GetLevel() <= 8) as a bound and nothing more. No claim about
--     how often this fires in a real game appears anywhere in this file.
--   ⇒ 'lvlany' is FROZEN-HOLD per OWNER_PRIORITIES P4.2: registered in
--     state.json:lvlany_20260910, NOT requested into the armed set. The armed
--     string, queue.json and test_set.md are untouched.
--
-- HOW SECTION 3 DRIVES IT. The helper is not replicated here: its body is lifted
-- VERBATIM out of bots/mode_team_roam_generic.lua, compiled with loadstring and
-- run under setfenv. It reads exactly two names, and only the second is
-- injected:
--     J                  real jmz_func from the fixture loader
--     J.IsSoakCandidate  INJECTED: the arm under test
-- Section 3d then MUTATES the lifted text back to a `[1]`-only body and re-runs
-- it through the same machinery: the armed leg must go back to answering what
-- shipped answers. The defect and its repair are read off ONE apparatus.
--
-- ⛔ SECTION 7 IS THE BATON, AND IT IS AN ASSERTION, NOT AN ISSUE. The identical
-- expression sat at three more sites in the same file. They are deliberately
-- NOT changed by THIS lever (one lever at a time -- the lanefix bundle is why),
-- and section 7 pins them as still `[1]`-shaped so that "there are more" cannot
-- decay into a sentence nobody re-reads. This is the GH #13 shape the charter
-- names: a baton handed over as a closeable issue is a baton on the floor.
-- 2026-09-11: the baton was picked up -- 'lvlcarry' took the first of the three
-- and section 7 moved 3 -> 2 by having the repaired site leave the table, which
-- is what a moved baton is supposed to look like from in here.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/mode_team_roam_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'
local REF = 'docs/BOT_API_REFERENCE.md'
local CAND = 'lvlany'

-- The shipped call site's own two constants. Every count in sections 2 and 3 is
-- taken at these; the sweep in section 2 exists because they are one cell of it.
local SITE_RADIUS = 750
local SITE_LEVEL = 10

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block quotes the
--- shipped expression and names the three untouched siblings, so an unstripped
--- read would let a COMMENT satisfy the structural assertions in 5, 6 and 7.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'),
            'could not list ' .. dir)
        for line in p:lines() do
            if line:sub(-4) == '.lua' then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    assert(#out > 100, 'expected the frame corpus, got ' .. #out)
    return out
end

--- The helper's body, lifted verbatim from the shipped file. The function's own
--- terminating `end` is the only one at column 0; every `end` inside it is
--- indented, which is what makes the '\nend' anchor safe here.
local function helper_src()
    local src = stripped(read_file(TRG))
    local s = src:find('function X.NoNearbyEnemyAtLevel(tHeroes, nLevel)', 1, true)
    assert(s ~= nil, 'X.NoNearbyEnemyAtLevel is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.NoNearbyEnemyAtLevel in ' .. TRG)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.NoNearbyEnemyAtLevel', name))
    setfenv(fn, env)
    return fn()
end

-- ------------------------------------------------------------- the sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 600, 650, 750, 1600 }

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
                    if J.IsModeTurbo() then bump('turbo') end
                    -- 4c: the one other term of the shipped conjunction that is
                    -- readable on these frames. A bound, not a rate.
                    if h:GetLevel() <= 8 then bump('lv8') end

                    -- The call site's own read, byte for byte.
                    local list = J.GetNearbyHeroes(h, SITE_RADIUS, true,
                        BOT_MODE_NONE)

                    -- 4a. Kept as its own pass so a mutant that breaks the
                    -- producer's self-exclusion shows up HERE rather than by
                    -- silently inflating the ratchets below (all of which are
                    -- floors, so contamination could only satisfy them).
                    for i = 1, #list do
                        if list[i] == h then bump('self_in_list') end
                        if list[i]:GetTeam() == h:GetTeam() then bump('sameteam') end
                    end

                    if #list >= 1 then
                        bump('ge1')
                        local first = list[1]:GetLevel()
                        local hi, lo = first, first
                        local dprev, sorted = -1, true
                        for i = 1, #list do
                            local l = list[i]:GetLevel()
                            if l > hi then hi = l end
                            if l < lo then lo = l end
                            local d = GetUnitToUnitDistance(h, list[i])
                            if d < dprev - 1 then sorted = false end
                            dprev = d
                        end
                        if not sorted then bump('unsorted') end
                        if #list >= 2 then
                            bump('ge2')
                            if hi > lo then bump('level_spread') end
                            if first ~= hi then bump('e1_not_highest') end
                            if first < hi then bump('e1_strictly_lower') end
                        end
                    end

                    -- 2. the sweep. `miss_*` is the population this lever
                    --    changes: the nearest is under the bar, somebody else in
                    --    the same radius is over it.
                    for _, r in ipairs(RADII) do
                        local lr = J.GetNearbyHeroes(h, r, true, BOT_MODE_NONE)
                        if #lr >= 1 then
                            local f = lr[1]:GetLevel()
                            local hi = 0
                            for i = 1, #lr do
                                local l = lr[i]:GetLevel()
                                if l > hi then hi = l end
                            end
                            for _, th in ipairs({ 10, 12 }) do
                                local k = 'r' .. r .. '_th' .. th
                                if hi >= th then bump('any_' .. k) end
                                if f < th and hi >= th then bump('miss_' .. k) end
                            end
                        end
                    end

                    -- 3. the helper, driven on its own shipped bytes, over the
                    --    rows the lever is actually about.
                    local hi = 0
                    for i = 1, #list do
                        local l = list[i]:GetLevel()
                        if l > hi then hi = l end
                    end
                    if #list >= 1 and list[1]:GetLevel() < SITE_LEVEL
                        and hi >= SITE_LEVEL and J.IsModeTurbo() then
                        bump('drives')

                        local armed = false
                        local realSoak = J.IsSoakCandidate
                        J.IsSoakCandidate = function(sId)
                            if sId ~= CAND then return realSoak(sId) end
                            return armed
                        end
                        local env = setmetatable({ J = J }, { __index = _G })

                        local fn = compile(BODY, env, 'lvlany_body')
                        local okOff, rOff = pcall(fn, list, SITE_LEVEL)
                        if okOff then bump('off_no_error') end
                        -- The byte-identity claim, MEASURED: every driven row is
                        -- a row where the shipped expression answers TRUE ("all
                        -- clear"), so a false here would mean the gate leaks.
                        if okOff and rOff == true then bump('off_true') end

                        armed = true
                        local okOn, rOn = pcall(fn, list, SITE_LEVEL)
                        if okOn then bump('on_no_error') end
                        if okOn and rOn == false then bump('on_false') end

                        -- 3d. the shipped quantifier restored into the same
                        --     apparatus. Counted, not asserted, so a no-op
                        --     mutation cannot kill the file at load time.
                        local mut = BODY:gsub('for i = 1, #tHeroes do',
                            'for i = 1, 1 do')
                        if mut == BODY then bump('mut_noop') end
                        local gn = compile(mut, env, 'lvlany_mut')
                        local okMut, rMut = pcall(gn, list, SITE_LEVEL)
                        if okMut and rMut == true then bump('mut_true') end

                        J.IsSoakCandidate = realSoak
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
-- equalities on purpose -- zero is already growth-immune.

tests['[lvlany] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' frames failed to load')
    cs.corpus(C('frames_loaded'), 'lvlany sweep')
    cs.ratchet(C('live'), 1306, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every driven row is Turbo', 100)
end

-- ---------------- 1. the list is ordered; the question is not about order ---

tests['[lvlany] 1a. MEASURED: the nearest enemy is not the highest-level one']
= function()
    cs.ratchet(C('ge1'), 396, 'rows with at least one enemy hero within 750')
    cs.ratchet(C('ge2'), 135, 'rows carrying two or more')
    -- 43/135 registered. Both directions matter: if [1] were always the highest
    -- the guard would be right by accident, and if it were never the highest the
    -- sweep would be measuring something other than a level spread.
    cs.ratchet(C('e1_not_highest'), 43, 'rows where the nearest is not the highest')
    cs.ratchet(C('e1_strictly_lower'), 43, 'rows where the nearest is strictly lower')
    assert(C('e1_not_highest') < C('ge2'),
        'the nearest is never the highest on any of the ' .. C('ge2')
        .. ' multi-hero rows -- that is not a level spread, it is an inverted '
        .. 'corpus; re-read the loader before quoting anything below')
end

tests['[lvlany] 1b. the list IS distance-sorted -- pinned, not assumed']
= function()
    -- This is the assertion that keeps this lever from quietly turning into
    -- 'anyhero'. If the order ever stops holding, the argument in the header
    -- ("[1] really is the nearest, and it is still the wrong answer") is no
    -- longer the argument being made, and the id must be re-argued rather than
    -- re-baselined.
    assert(C('unsorted') == 0,
        C('unsorted') .. ' row(s) came back out of distance order. The premise '
        .. 'of this lever is that `[1]` is CORRECTLY the nearest and the guard is '
        .. 'wrong anyway; an unsorted list makes it the weaker anyhero argument '
        .. 'instead. Re-argue, do not re-baseline.')
    -- Both halves of the order claim, read off the shipped tree rather than
    -- remembered: the engine's promise, and the fact that J only filters.
    local doc = read_file(REF)
    assert(doc:find('sorted by distance', 1, true) ~= nil,
        REF .. ' no longer records the engine\'s distance-order promise for the '
        .. 'GetNearby* family -- section 1b cites it')
    local src = stripped(read_file(JMZ))
    local s = src:find('function J.GetNearbyHeroes', 1, true)
    assert(s ~= nil, 'J.GetNearbyHeroes is gone from ' .. JMZ)
    local e = src:find('\nend', s, true)
    local body = src:sub(s, e)
    assert(body:find('table.insert(heroes, hero)', 1, true) ~= nil,
        'J.GetNearbyHeroes no longer refilters into a fresh table')
    assert(body:find('sort', 1, true) == nil,
        'J.GetNearbyHeroes now sorts on its own -- the header says it only '
        .. 'filters and inherits the engine\'s order; re-read it')
end

-- ------------------------------------- 2. the population the lever changes --

tests['[lvlany] 2. MEASURED: a sweep, because the shipped cell is one cell of it']
= function()
    -- Registered at r = 600 / 650 / 750 / 1600 x threshold 10 / 12. The shipped
    -- call site is r750_th10 = 7; it is reported inside the sweep and never on
    -- its own, so that "7" cannot be read as "the" rate (charter rule (iii)).
    local reg = {
        r600_th10 = 4, r650_th10 = 5, r750_th10 = 7, r1600_th10 = 15,
        r600_th12 = 2, r650_th12 = 2, r750_th12 = 2, r1600_th12 = 3,
    }
    for k, v in pairs(reg) do
        cs.ratchet(C('miss_' .. k), v,
            'rows where the nearest is under the bar but another enemy is over it '
            .. '(' .. k .. ')')
    end
    -- Anti-vacuum in the other direction: the misses must be a SUBSET of the rows
    -- that have anybody over the bar at all, or the sweep is miscounting.
    for k in pairs(reg) do
        assert(C('miss_' .. k) <= C('any_' .. k),
            'miss_' .. k .. ' (' .. C('miss_' .. k) .. ') exceeds any_' .. k
            .. ' (' .. C('any_' .. k) .. ') -- the sweep is double counting')
    end
    -- Monotone in radius: a wider radius can only add heroes, so it can only add
    -- misses. A violation means the two reads are not the same measurement.
    assert(C('miss_r600_th10') <= C('miss_r650_th10')
        and C('miss_r650_th10') <= C('miss_r750_th10')
        and C('miss_r750_th10') <= C('miss_r1600_th10'),
        'the r=600/650/750/1600 miss counts are not monotone -- widening the '
        .. 'radius cannot remove a hero, so these are not one measurement')
end

-- ------------------------- 3. the helper, driven on its own shipped bytes ---

tests['[lvlany] 3a. the drive ran on the rows the lever is about'] = function()
    cs.ratchet(C('drives'), 7, 'rows driven at the shipped radius and threshold')
    assert(C('drives') == C('miss_r750_th10'),
        'the drive population (' .. C('drives') .. ') no longer equals the '
        .. 'r750_th10 miss population (' .. C('miss_r750_th10') .. ') -- one of '
        .. 'them stopped being the thing this lever is about')
end

tests['[lvlany] 3b. UNARMED: the shipped answer, "all clear", on every driven row']
= function()
    cs.universal(C('off_no_error'), C('drives'),
        'the unarmed leg completes without raising', 5)
    cs.universal(C('off_true'), C('drives'),
        'and it answers true -- exactly what the shipped expression answers', 5)
end

tests['[lvlany] 3c. ARMED: the helper sees the hero that is actually dangerous']
= function()
    cs.universal(C('on_no_error'), C('drives'),
        'the armed leg completes without raising', 5)
    cs.universal(C('on_false'), C('drives'),
        'and it answers false on every row where somebody IS over the bar', 5)
end

tests['[lvlany] 3d. the SHIPPED quantifier, restored into the same apparatus, '
    .. 'goes back to answering "all clear"'] = function()
    assert(C('mut_noop') == 0,
        'the 3d mutation was a NO-OP on ' .. C('mut_noop') .. ' rows: the lifted '
        .. 'body no longer contains the `for i = 1, #tHeroes` loop, which means '
        .. 'the loop is no longer what makes the difference')
    cs.universal(C('mut_true'), C('drives'),
        'collapsing the loop back to [1] returns true on every driven row', 5)
end

-- ---------------------- 4. the bounds, measured rather than cited as prose ---

tests['[lvlany] 4a. BOUND: this producer has real enemy semantics'] = function()
    -- An equality on purpose. Unlike the two rounds before it, this corpus DOES
    -- answer with the opposing side and does exclude the asking hero -- which is
    -- what lets sections 1-3 be about enemies rather than about geometry. The
    -- day that stops holding, this goes red instead of every ratchet above
    -- quietly meaning something else (all of them are floors, so contamination
    -- would only satisfy them).
    assert(C('self_in_list') == 0,
        C('self_in_list') .. ' row(s) put the asking hero in its own enemy list. '
        .. 'Sections 1-3 are then measuring geometry, not enemy semantics: fix '
        .. 'the producer or re-take them, do not re-baseline.')
    assert(C('sameteam') == 0,
        C('sameteam') .. ' row(s) put a same-team hero in the enemy list. Same '
        .. 'consequence as the line above.')
end

tests['[lvlany] 4b. BOUND: the levels in this corpus actually differ'] = function()
    -- Without this the whole file could be green and vacuous: a corpus where
    -- every hero is the same level makes "the nearest is not the highest"
    -- unmeasurable and every count above an artifact.
    cs.ratchet(C('level_spread'), 66,
        'multi-hero rows carrying two different levels')
    assert(C('level_spread') > 0,
        'no row in the corpus carries two enemy heroes at different levels -- '
        .. 'sections 1-3 are vacuous and nothing in this file may be quoted')
end

tests['[lvlany] 4c. BOUND: the rest of the conjunction is not driven here']
= function()
    -- Reported so that no reader turns section 2's 7 into a fire rate. Only one
    -- of the shipped branch's other terms is readable on these frames; the
    -- others (IsModeSuitHit, GetNetWorth, WasRecentlyDamagedByAnyHero, the two
    -- fountain distances) are not driven at all.
    cs.ratchet(C('lv8'), 806, 'live rows where bot:GetLevel() <= 8')
    assert(C('lv8') < C('live'),
        'every live row is level <= 8; that is a corpus property this bound is '
        .. 'supposed to distinguish, so re-read it before quoting section 2')
end

-- ------------- 5. condition (c), counted in the file rather than argued in prose --

tests['[lvlany] 5. the file\'s own idiom for a set question is a loop'] = function()
    local src = stripped(read_file(TRG))
    -- Siblings in the SAME file that ask a question of a whole set. If one of
    -- them ever collapses to `[1]` too, the argument that the loop is this
    -- file's own idiom weakens and must be re-made, not re-baselined.
    for _, name in ipairs({ 'X.GetCanTogetherCount', 'X.GetMostDamageUnit' }) do
        local s = src:find('function ' .. name, 1, true)
        assert(s ~= nil, name .. ' is gone from ' .. TRG)
        local e = src:find('\nend', s, true)
        local body = src:sub(s, e)
        assert(body:find('for ', 1, true) ~= nil,
            name .. ' no longer loops over its set -- the header claims the loop '
            .. 'as this file\'s own idiom')
    end
end

tests['[lvlany] 5b. the call site still asks the question this lever is about']
= function()
    local src = stripped(read_file(TRG))
    -- A lever whose caller has been rewritten around it is inert while every
    -- behavioural assertion above stays green -- the cheapest way for this work
    -- to LOOK landed. Pin the call site itself.
    assert(src:find('X.NoNearbyEnemyAtLevel(nNearbyEnemyHeroes, 10)', 1, true) ~= nil,
        'the guard no longer reads X.NoNearbyEnemyAtLevel(nNearbyEnemyHeroes, 10) '
        .. '-- lvlany may now be gating nothing')
    assert(src:find(
        'local nNearbyEnemyHeroes = J.GetNearbyHeroes(bot, 750, true, BOT_MODE_NONE)',
        1, true) ~= nil,
        'the guard\'s list is no longer J.GetNearbyHeroes(bot, 750, ...) -- '
        .. 'sections 2 and 3 are taken at THAT radius')
    -- Count CALLS, not mentions: the definition line matches the same name.
    local _, nAll = src:gsub('X%.NoNearbyEnemyAtLevel%(', '')
    local _, nDef = src:gsub('function X%.NoNearbyEnemyAtLevel%(', '')
    assert(nDef == 1, TRG .. ' defines X.NoNearbyEnemyAtLevel ' .. nDef .. ' times')
    assert(nAll - nDef == 1,
        'X.NoNearbyEnemyAtLevel now has ' .. (nAll - nDef) .. ' callers, not 1 -- '
        .. 'the blast radius of this gate changed and the header, section 7 and '
        .. 'the report all describe a one-site lever')
end

-- --------------------------------------------- 6. the gate, structurally ---

tests['[lvlany] 6. the gate is turbo-only, single, and the unarmed path is the '
    .. 'shipped expression'] = function()
    local atTurbo = BODY:find('J.IsModeTurbo()', 1, true)
    local atGate = BODY:find("J.IsSoakCandidate('" .. CAND .. "')", 1, true)
    assert(atGate ~= nil, 'the ' .. CAND .. ' gate is gone from the helper')
    assert(atTurbo ~= nil and atTurbo < atGate,
        'the gate is not turbo-only, or turbo is not read first')
    local _, nGates = BODY:gsub('J%.IsSoakCandidate%(', '')
    assert(nGates == 1,
        'the helper now reads ' .. nGates .. ' soak candidates. A gate written as '
        .. 'a conjunction of two ids freezes FALSE the day either is promoted '
        .. '(the pullcad trap) -- keep it one id.')
    -- The unarmed return, verbatim. This is what makes "unarmed IS the shipped
    -- expression" a structural claim as well as the measured one in 3b.
    assert(BODY:find('return tHeroes[1]:GetLevel() < nLevel', 1, true) ~= nil,
        'the unarmed leg no longer returns the shipped `[1]` comparison')
    assert(BODY:find('if tHeroes == nil or tHeroes[1] == nil then return true end',
        1, true) ~= nil,
        'the empty-list leg no longer matches the shipped `[1] == nil` term')
end

-- ----------------------------------------------------- 7. THE BATON ---------

tests['[lvlany] 7. the untouched siblings are still there, still `[1]`']
= function()
    -- Deliberately not fixed in this work unit: one lever at a time. Pinned here
    -- rather than left to the report, because a baton written only in prose (or
    -- only in a closeable issue) is the GH #13 failure the charter names -- that
    -- one went missing for 37 rounds. When one of these is repaired, THIS
    -- assertion is what tells the next round the count moved.
    --
    -- ⭐ 2026-09-11: IT MOVED, AND THIS IS WHAT THAT LOOKS LIKE. The strategy
    -- desk took the first of the three -- X.CarryFindTarget's deny guard, the
    -- level-12 site -- as 'lvlcarry', with its OWN id and its OWN helper
    -- (X.NoNearbyEnemyAtLevelCarry) so that arming one does not arm the other.
    -- The repaired site is moved OUT of the table below rather than the count
    -- being quietly lowered: the level-12 entry drops 2 -> 1 because one of the
    -- two is gone from the source, and the total drops 3 -> 2. The remaining two
    -- are the second level-12 site in X.CarryFindTarget (the group-push branch)
    -- and the level-10 site inside X.CanAttackTogether -- and section 7b of
    -- tests/test_lvlcarry_carry_deny_level_quantifier.lua now carries the
    -- measured reason the CanAttackTogether one is not takeable on this corpus
    -- yet (its full predicate never flips here).
    local src = stripped(read_file(TRG))
    local siblings = {
        ['nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12'] = 1,
        ['nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10'] = 1,
    }
    local total = 0
    for text, want in pairs(siblings) do
        local n = 0
        local at = 1
        while true do
            local s = src:find(text, at, true)
            if s == nil then break end
            n = n + 1
            at = s + 1
        end
        assert(n == want,
            'expected ' .. want .. ' un-repaired `' .. text .. '` site(s) in '
            .. TRG .. ', found ' .. n .. '. If one was repaired, move it out of '
            .. 'this table and say so in the report -- do not just lower the '
            .. 'number.')
        total = total + n
    end
    assert(total == 2,
        'the baton is ' .. total .. ' sites, not 2 -- one of the original three '
        .. 'was taken by \'lvlcarry\' on 2026-09-11 and the report says two '
        .. 'remain')
end

return tests

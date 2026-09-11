-- [lvlgroup 20260911] THE SECOND SIBLING OFF 'lvlany'S BATON: THE GROUP-PUSH
-- BRANCH ASKS AN EXISTENTIAL QUESTION ABOUT *LEVEL* AND ANSWERS IT WITH THE
-- NEAREST HERO.
--
-- THE DEFECT. bots/mode_team_roam_generic.lua, X.CarryFindTarget's group-push
-- branch -- the one that gangs up on a creep our own tower is about to kill:
--     local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650,true,BOT_MODE_NONE)
--     ...
--     if IsModeSuitHit and bot:GetLevel() <= 8
--        and X.CanAttackTogether(bot)
--        and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12)
-- The empty-list leg beside it is again what proves the question is existential:
-- the author already spent a term separating "nobody here" from "somebody here
-- who is weak". What the expression answers is "is the NEAREST one weak".
--
-- ⛔⛔ READ THIS BEFORE ANY NUMBER BELOW. THIS LEVER IS WEAKER THAN 'lvlcarry',
-- AND THE WEAKNESS IS MEASURED RATHER THAN SUSPECTED.
--   * Its own predicate change IS driven: 2 real rows, the same r650/th12 miss
--     population 'lvlcarry' reports, on real dumped levels (sections 2 and 3).
--   * But THE BRANCH THOSE ROWS SIT IN NEVER OPENS ON THIS CORPUS. Both miss
--     rows carry ZERO allies within 1200, so `X.CanAttackTogether(bot)` -- a
--     conjunct standing right beside this guard -- is false on both, and arming
--     changes the branch's OUTCOME on 0 rows. Section 5 asserts that 0 as an
--     EQUALITY.
--   * ⭐ THE ZERO IS NOT STRUCTURAL, WHICH IS WHY IT IS WORTH ASSERTING RATHER
--     THAN CONCEDING: 13 rows DO carry >=2 allies within 1200 and >=2 enemies
--     within 650 -- the exact shape a miss needs -- and none of the 13 happens
--     to be a miss. So section 5 is a small-sample zero over a live 13-row
--     candidate population, and the day a fixture lands in that shape this file
--     goes red and the lever can be driven end to end. ⭐ THAT RED IS GOOD NEWS.
--     Take it as the drive; do not re-baseline it.
--
-- ⭐ WHAT CARRIES THE LEVER WHILE THAT ZERO STANDS IS THE DIRECTION, AND SECTION
-- 3e MEASURES IT OVER ALL 1306 LIVE ROWS RATHER THAN ARGUING IT FROM THE DIFF.
-- Armed answers `not any(level >= nLevel)`; shipped answers `[1] < nLevel`; the
-- first implies the second whenever `[1]` exists. So armed is a pure NARROWING
-- of the "clear" answer this branch needs: it can only ever WITHDRAW a group
-- push baseline would have made, never add one. That is the safety shape
-- 'glyphany' and 'wkqdmg' ship on, and it is what makes a gated lever with an
-- unreachable branch a safe thing to have sitting in the tree. ⛔ It is a bound
-- on the DIRECTION of the change, not a fire rate. No fire rate is claimed here.
--
-- ⛔ THE BAR, STATED ONCE SO THIS FAMILY STOPS DRIFTING. The bar this lever is
-- taken on is "the lever's OWN predicate change is driven on real rows", with
-- branch reachability registered separately as the weaker bound (section 5).
-- 'lvlcarry' section 7b had judged the OTHER remaining sibling (the level-10
-- site inside X.CanAttackTogether) unbuyable on a stricter bar -- "the full
-- predicate flips". Those two bars disagree, and applying a different one to
-- each sibling of one family is how a standard erodes without anyone deciding
-- to change it. So 7b's comment is amended in THIS commit to record which bar
-- is in force and that its sibling is buyable under it (4 miss rows at its own
-- r=600/level 10). ⛔ It is NOT taken here: one lever at a time is what the
-- lanefix bundle cost us (gpm -74.5, then -88.7, 0/4 comps).
--
-- ⛔ WHY A THIRD HELPER RATHER THAN A SECOND CALLER OF 'lvlcarry'S. Sharing would
-- put both call sites behind ONE id, which is that same bundling by hand; giving
-- a shared helper two ids is the pullcad trap (a gate written as a conjunction
-- of ids freezes FALSE the day either is promoted). 'lvlcarry' section 5b pins
-- its caller count at exactly 1, so sharing would also turn that file red --
-- which is the pin doing its job, not an obstacle to route around.
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT BUY, said before any number is read.
--   * IT CAN BUY ENEMY SEMANTICS AND REAL LEVELS. The producer is the raw
--     bot:GetNearbyHeroes, which the loader restores from dump ground truth with
--     a team comparison, a vision check, self excluded and a distance sort;
--     GetLevel is dump ground truth. Section 4a asserts the self-exclusion and
--     the team split as EQUALITIES (every ratchet here is a FLOOR, so
--     contamination could only SATISFY one -- the lesson 'anyhero's M7 paid for)
--     and 4b measures the level SPREAD rather than trusting it.
--   * IT CANNOT BUY A FIRE RATE, and it cannot buy the branch either -- that is
--     section 5, stated above.
--   ⇒ 'lvlgroup' is FROZEN-HOLD per OWNER_PRIORITIES P4.2: registered in
--     state.json:lvlgroup_20260911, NOT requested into the armed set. The armed
--     string, queue.json and test_set.md are untouched.
--
-- ⭐ SECTION 1 IS THIS FILE'S OWN FINDING AND HAS NO COUNTERPART IN 'lvlcarry'.
-- This branch asks the dangerous-enemy question TWICE at two different cells:
-- once here at r=650/level 12, and once inside X.CanAttackTogether at
-- r=600/level 10 -- a stricter threshold over a smaller radius. So repairing
-- only this site leaves the composite guard still answered-by-the-nearest at the
-- other cell. Section 1 measures what that costs on the two miss rows: the
-- >=12 hero is inside 600 on BOTH (the 600-650 annulus story is empty here), and
-- the inner guard already reads "not clear" on ONE of the two. That is the
-- honest statement of how much of the defect this lever removes, and it is the
-- reason the remaining sibling stays on the baton instead of being folded in.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/mode_team_roam_generic.lua'
local REF = 'docs/BOT_API_REFERENCE.md'
local CAND = 'lvlgroup'

-- The shipped call site's own two constants. Every count in sections 2 and 3 is
-- taken at these; the sweep in section 2 exists because they are one cell of it.
local SITE_RADIUS = 650
local SITE_LEVEL = 12
-- The OTHER cell the same branch asks at, via X.CanAttackTogether. Section 1.
local INNER_RADIUS = 600
local INNER_LEVEL = 10
-- X.CanAttackTogether's ally term.
local ALLY_RADIUS = 1200

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block quotes the
--- shipped expression and the remaining sibling, so an unstripped read would let
--- a COMMENT satisfy the structural assertions in 5b, 6 and 7.
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
    local s = src:find(
        'function X.NoNearbyEnemyAtLevelGroup(tHeroes, nLevel)', 1, true)
    assert(s ~= nil, 'X.NoNearbyEnemyAtLevelGroup is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.NoNearbyEnemyAtLevelGroup in ' .. TRG)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.NoNearbyEnemyAtLevelGroup', name))
    setfenv(fn, env)
    return fn()
end

--- The shipped expression, spelled out here so section 3 compares the helper
--- against the TEXT of what shipped rather than against another call of itself.
local function shipped_answer(list, nLevel)
    return (list[1] == nil) or (list[1]:GetLevel() < nLevel)
end

--- X.CanAttackTogether, replicated term for term. Section 5b pins the shipped
--- text against this replication, so the day the function is edited this file
--- goes red instead of section 5's zero quietly becoming a statement about a
--- predicate that no longer exists.
local function can_attack_together(J, h)
    local allies = h:GetNearbyHeroes(ALLY_RADIUS, false, BOT_MODE_NONE)
    local en = h:GetNearbyHeroes(INNER_RADIUS, true, BOT_MODE_NONE)
    return h ~= nil and h:IsAlive()
        and not h:IsIllusion()
        and J.GetProperTarget(h) == nil
        and #allies >= 2
        and (en[1] == nil or en[1]:GetLevel() < INNER_LEVEL)
end

-- ------------------------------------------------------------- the sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 450, 600, 650, 1600 }

    for _, path in ipairs(corpus_paths()) do
        local ok, J, _, heroes, fx = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames_loaded')

            -- The arm under test, injected once per fixture rather than once per
            -- row: 1306 rows would otherwise mean 1306 compiles of the same
            -- bytes, and the compile is not what is being measured.
            local armed = false
            local realSoak = J.IsSoakCandidate
            J.IsSoakCandidate = function(sId)
                if sId ~= CAND then return realSoak(sId) end
                return armed
            end
            local env = setmetatable({ J = J }, { __index = _G })
            local fn = compile(BODY, env, 'lvlgroup_body')
            -- 3d. the shipped quantifier restored into the same apparatus.
            -- Counted, not asserted, so a no-op mutation cannot kill the file at
            -- load time.
            local mut = BODY:gsub('for i = 1, #tHeroes do', 'for i = 1, 1 do')
            if mut == BODY then bump('mut_noop') end
            local gn = compile(mut, env, 'lvlgroup_mut')

            for _, u in ipairs(fx.units) do
                local h = heroes[u.name]
                if h ~= nil and u.alive then
                    bump('live')
                    if J.IsModeTurbo() then bump('turbo') end
                    -- 4c: the one other term of the shipped branch that is
                    -- readable on these frames. A bound, not a rate.
                    if h:GetLevel() <= 8 then bump('lv8') end

                    -- The call site's own read, byte for byte: the RAW engine
                    -- method, not J.GetNearbyHeroes.
                    local list = h:GetNearbyHeroes(SITE_RADIUS, true,
                        BOT_MODE_NONE)
                    local allies = h:GetNearbyHeroes(ALLY_RADIUS, false,
                        BOT_MODE_NONE)
                    local en600 = h:GetNearbyHeroes(INNER_RADIUS, true,
                        BOT_MODE_NONE)

                    -- 4a. Its own pass, so a mutant that breaks the producer's
                    -- self-exclusion shows up HERE rather than by silently
                    -- inflating the ratchets below (all of which are floors).
                    -- The ALLY half is not redundant: breaking self-exclusion
                    -- does NOT put the asking hero in its own ENEMY list (the
                    -- team comparison rejects it a second time), so it lands in
                    -- the ally list -- where it inflates `#allies >= 2` and so
                    -- moves what section 5's zero is a statement about.
                    for i = 1, #list do
                        if list[i] == h then bump('self_in_list') end
                        if list[i]:GetTeam() == h:GetTeam() then bump('sameteam') end
                    end
                    for i = 1, #allies do
                        if allies[i] == h then bump('self_in_allies') end
                    end

                    -- 4d. raw engine list vs the J-filtered one at the same
                    -- radius. This lever's producer is the raw one; the count
                    -- says whether this corpus can tell them apart at all.
                    local jl = J.GetNearbyHeroes(h, SITE_RADIUS, true,
                        BOT_MODE_NONE)
                    if #jl ~= #list then bump('jfilter_differs') end

                    -- 5. the branch's OTHER conjunct, and the candidate shape.
                    local cat = can_attack_together(J, h)
                    if cat then bump('cat_true') end
                    if #allies >= 2 and #list >= 2 then bump('cand_shape') end

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
                        local lr = h:GetNearbyHeroes(r, true, BOT_MODE_NONE)
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

                    -- 3. the helper, driven on its own shipped bytes, over EVERY
                    --    live row -- the population it changes is 2, which is far
                    --    too thin to carry "all 2 of 2" on its own.
                    local hi = 0
                    for i = 1, #list do
                        local l = list[i]:GetLevel()
                        if l > hi then hi = l end
                    end
                    local isMiss = (#list >= 1)
                        and (list[1]:GetLevel() < SITE_LEVEL) and (hi >= SITE_LEVEL)
                    if isMiss then
                        bump('site_miss')
                        if h:GetLevel() <= 8 then bump('site_miss_lv8') end
                        -- 5. THE ZERO: does the branch this guard sits in ever
                        --    open on a row the lever changes?
                        if cat then bump('miss_cat') end
                        if #allies >= 2 then bump('miss_ally2') end
                        -- 1. the other cell of the same branch.
                        local hi600 = 0
                        for i = 1, #en600 do
                            local l = en600[i]:GetLevel()
                            if l > hi600 then hi600 = l end
                        end
                        if hi600 >= SITE_LEVEL then
                            bump('miss_high_inside_inner')
                        else
                            bump('miss_high_in_annulus')
                        end
                        if not (en600[1] == nil
                                or en600[1]:GetLevel() < INNER_LEVEL) then
                            bump('miss_inner_already_blocks')
                        end
                    end

                    local want = shipped_answer(list, SITE_LEVEL)
                    if want then bump('shipped_true') end

                    bump('drives')
                    armed = false
                    local okOff, rOff = pcall(fn, list, SITE_LEVEL)
                    if okOff then bump('off_no_error') end
                    if okOff and rOff == want then bump('off_matches_shipped') end

                    armed = true
                    local okOn, rOn = pcall(fn, list, SITE_LEVEL)
                    if okOn then bump('on_no_error') end
                    if isMiss then
                        if okOn and rOn == false then bump('on_false_on_miss') end
                    else
                        if okOn and rOn == want then bump('on_matches_off') end
                    end

                    -- 3e. THE DIRECTION, measured on every row rather than
                    -- argued from the diff: armed true must imply unarmed true.
                    -- A row that breaks it is a row where arming GRANTS the
                    -- "clear" answer -- the one direction a narrowing may never
                    -- take.
                    if okOn and okOff then
                        bump('dir_rows')
                        if rOn == true then
                            bump('armed_true')
                            if rOff ~= true then bump('dir_violation') end
                        end
                        if rOff == true then bump('off_true') end
                        if rOn == false and rOff == true then bump('dir_narrows') end
                    end

                    local okMut, rMut = pcall(gn, list, SITE_LEVEL)
                    if okMut and rMut == want then bump('mut_matches_shipped') end
                    armed = false
                end
            end

            J.IsSoakCandidate = realSoak
        end
    end
    return c
end)()

local function C(k) return SWEEP[k] end

-- Every counter is a SUM OVER FRAMES, so appending a fixture can only raise it:
-- cs.ratchet still catches the FALL that would mean behaviour moved, and stops
-- charging this file for corpus growth (GH #106/#127). The zero claims stay
-- equalities on purpose -- zero is already growth-immune, and section 5's zero
-- is the one this lever's honesty rests on.

tests['[lvlgroup] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' frames failed to load')
    cs.corpus(C('frames_loaded'), 'lvlgroup sweep')
    cs.ratchet(C('live'), 1306, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every driven row is Turbo', 100)
end

-- ------------- 1. the branch asks the same question at TWO cells ------------

tests['[lvlgroup] 1a. MEASURED: how much of the defect this one site removes']
= function()
    -- This file's own finding. The branch reads the dangerous-enemy question
    -- here at r=650/level 12 AND again inside X.CanAttackTogether at
    -- r=600/level 10, so a repair at one cell leaves the other cell still
    -- answered by `[1]`. These two counts say what that costs on the rows the
    -- lever actually changes -- they are the reason the remaining sibling stays
    -- on the baton (section 7) instead of being folded in here.
    assert(C('miss_high_in_annulus') == 0,
        C('miss_high_in_annulus') .. ' miss row(s) put the >= ' .. SITE_LEVEL
        .. ' hero in the ' .. INNER_RADIUS .. '-' .. SITE_RADIUS .. ' annulus, '
        .. 'where the inner cell cannot see it at all. That is a NEW shape for '
        .. 'this family -- read it before quoting section 1, do not re-baseline.')
    cs.ratchet(C('miss_high_inside_inner'), 2,
        'miss rows whose dangerous hero is also inside the inner radius')
    cs.ratchet(C('miss_inner_already_blocks'), 1,
        'miss rows where the inner r=600/level 10 guard ALREADY reads "not clear"')
    assert(C('miss_inner_already_blocks') < C('site_miss'),
        'the inner guard already blocks every miss row (' .. C('site_miss')
        .. '), so this lever removes no part of the defect the composite guard '
        .. 'still has -- re-argue the id, do not re-baseline this line')
end

tests['[lvlgroup] 1b. the list IS distance-sorted -- pinned, not assumed']
= function()
    -- Same argument 'lvlany' and 'lvlcarry' rest on and the same reason to pin
    -- it: if the order ever stops holding, the claim being made here ("`[1]`
    -- really IS the nearest and the guard is wrong anyway") turns into the
    -- weaker 'anyhero' claim, and the id must be re-argued rather than
    -- re-baselined.
    assert(C('unsorted') == 0,
        C('unsorted') .. ' row(s) came back out of distance order. Re-argue, do '
        .. 'not re-baseline.')
    local doc = read_file(REF)
    assert(doc:find('sorted by distance', 1, true) ~= nil,
        REF .. ' no longer records the engine\'s distance-order promise for the '
        .. 'GetNearby* family -- section 1b cites it')
end

tests['[lvlgroup] 1c. MEASURED: the nearest enemy is not the highest-level one']
= function()
    cs.ratchet(C('ge1'), 357, 'rows with at least one enemy hero within 650')
    cs.ratchet(C('ge2'), 104, 'rows carrying two or more')
    cs.ratchet(C('e1_not_highest'), 32, 'rows where the nearest is not the highest')
    cs.ratchet(C('e1_strictly_lower'), 32, 'rows where the nearest is strictly lower')
    assert(C('e1_not_highest') < C('ge2'),
        'the nearest is never the highest on any of the ' .. C('ge2')
        .. ' multi-enemy rows -- that is not a level spread, it is an inverted '
        .. 'corpus; re-read the loader before quoting anything below')
end

-- ------------------------------------- 2. the population the lever changes --

tests['[lvlgroup] 2. MEASURED: a sweep, because the shipped cell is one cell of it']
= function()
    -- Registered at r = 450 / 600 / 650 / 1600 x threshold 10 / 12. The shipped
    -- call site is r650_th12 = 2; it is reported inside the sweep and never on
    -- its own, so that "2" cannot be read as "the" rate (charter rule (iii)).
    -- It is the SAME cell 'lvlcarry' drives, because it is the same list local
    -- read at the same threshold -- section 7 says so out loud rather than
    -- letting a reader mistake this for an independent measurement.
    local reg = {
        r450_th10 = 1, r600_th10 = 4, r650_th10 = 5, r1600_th10 = 15,
        r450_th12 = 0, r600_th12 = 2, r650_th12 = 2, r1600_th12 = 3,
    }
    for k, v in pairs(reg) do
        cs.ratchet(C('miss_' .. k), v,
            'rows where the nearest is under the bar but another enemy is over it '
            .. '(' .. k .. ')')
    end
    -- Anti-vacuum in the other direction: the misses must be a SUBSET of the
    -- rows that have anybody over the bar at all, or the sweep is miscounting.
    for k in pairs(reg) do
        assert(C('miss_' .. k) <= C('any_' .. k),
            'miss_' .. k .. ' (' .. C('miss_' .. k) .. ') exceeds any_' .. k
            .. ' (' .. C('any_' .. k) .. ') -- the sweep is double counting')
    end
    -- Monotone in radius: a wider radius can only add heroes, so it can only add
    -- misses. A violation means the two reads are not the same measurement.
    for _, th in ipairs({ 10, 12 }) do
        assert(C('miss_r450_th' .. th) <= C('miss_r600_th' .. th)
            and C('miss_r600_th' .. th) <= C('miss_r650_th' .. th)
            and C('miss_r650_th' .. th) <= C('miss_r1600_th' .. th),
            'the r=450/600/650/1600 miss counts at threshold ' .. th .. ' are '
            .. 'not monotone -- widening the radius cannot remove a hero, so '
            .. 'these are not one measurement')
    end
    cs.ratchet(C('site_miss'), 2, 'miss rows at the shipped radius and threshold')
    assert(C('site_miss') == C('miss_r650_th12'),
        'the lever population (' .. C('site_miss') .. ') no longer equals the '
        .. 'r650_th12 sweep cell (' .. C('miss_r650_th12') .. ') -- one of them '
        .. 'stopped being the thing this lever is about')
    assert(C('site_miss') > 0,
        'nothing in this corpus is a miss row any more -- sections 3c and 3d are '
        .. 'vacuous and nothing in this file may be quoted')
end

-- ------------------------- 3. the helper, driven on its own shipped bytes ---

tests['[lvlgroup] 3a. the drive ran on every live row, not only on the 2']
= function()
    cs.universal(C('drives'), C('live'),
        'the drive visited every live row', 100)
    cs.universal(C('off_no_error'), C('drives'),
        'the unarmed leg completes without raising', 100)
    cs.universal(C('on_no_error'), C('drives'),
        'the armed leg completes without raising', 100)
end

tests['[lvlgroup] 3b. UNARMED: the shipped expression, term for term, on all of them']
= function()
    -- ⛔ THE ANTI-VACUUM GOES FIRST, ON PURPOSE. It is a statement about the
    -- ORACLE and it is logically prior to the comparison below: if the shipped
    -- expression answered TRUE on every row, "matches shipped" would be
    -- satisfiable by a helper that always returns true and this whole section
    -- would be green and empty.
    assert(C('shipped_true') < C('drives'),
        'the shipped expression answers true on all ' .. C('drives') .. ' rows, '
        .. 'so 3b is satisfiable by a constant -- re-read the corpus')
    cs.ratchet(C('shipped_true'), 1242, 'rows where the shipped guard reads "clear"')
    cs.universal(C('off_matches_shipped'), C('drives'),
        'the unarmed helper answers exactly what the shipped expression answers',
        100)
end

tests['[lvlgroup] 3c. ARMED: differs on exactly the miss rows, agrees everywhere else']
= function()
    cs.universal(C('on_false_on_miss'), C('site_miss'),
        'the armed helper sees the dangerous hero on every miss row', 1)
    cs.universal(C('on_matches_off'), C('drives') - C('site_miss'),
        'and it answers exactly what shipped answers on every other row', 100)
    assert(C('on_matches_off') + C('on_false_on_miss') == C('drives'),
        'armed rows accounted for: ' .. C('on_matches_off') .. ' + '
        .. C('on_false_on_miss') .. ' /= ' .. C('drives'))
end

tests['[lvlgroup] 3d. the SHIPPED quantifier, restored into the same apparatus, '
    .. 'goes back to answering what shipped answers'] = function()
    assert(C('mut_noop') == 0,
        'the 3d mutation was a NO-OP on ' .. C('mut_noop') .. ' fixture(s): the '
        .. 'lifted body no longer contains the `for i = 1, #tHeroes` loop, which '
        .. 'means the loop is no longer what makes the difference')
    cs.universal(C('mut_matches_shipped'), C('drives'),
        'collapsing the loop back to [1] restores the shipped answer on every row',
        100)
end

tests['[lvlgroup] 3e. THE DIRECTION: armed is a pure NARROWING, on every row']
= function()
    -- ⭐ THE SECTION THAT CARRIES THIS LEVER while section 5's zero stands. With
    -- the branch unreachable on this corpus, "the repair is correct on the rows
    -- it changes" is true but thin; what makes a gated lever with an unreachable
    -- branch SAFE to have sitting in the tree is that arming can only ever
    -- subtract the permission, never add it.
    cs.universal(C('dir_rows'), C('drives'),
        'both legs answered on every row, so the implication is measured on all '
        .. 'of them', 100)
    assert(C('dir_violation') == 0,
        C('dir_violation') .. ' row(s) have the ARMED helper answering "clear" '
        .. 'where the shipped expression does not. That is arming GRANTING a '
        .. 'group push baseline withheld -- the one direction this lever may '
        .. 'never take. Re-read the helper; do not re-baseline.')
    -- Anti-vacuum, both ways: the implication is only content if armed answers
    -- true somewhere AND narrows somewhere.
    assert(C('armed_true') > 0,
        'the armed helper never answers "clear" on any of the ' .. C('drives')
        .. ' rows, so the implication above is vacuously satisfied')
    cs.ratchet(C('dir_narrows'), 2,
        'rows where arming strictly withdraws the "clear" answer')
    assert(C('dir_narrows') == C('site_miss'),
        'the rows where arming narrows (' .. C('dir_narrows') .. ') are no '
        .. 'longer exactly the miss rows (' .. C('site_miss') .. ')')
end

-- ---------------------- 4. the bounds, measured rather than cited as prose ---

tests['[lvlgroup] 4a. BOUND: this producer has real enemy semantics'] = function()
    assert(C('self_in_list') == 0,
        C('self_in_list') .. ' row(s) put the asking hero in its own enemy list. '
        .. 'Sections 1-3 are then measuring geometry, not enemy semantics: fix '
        .. 'the producer or re-take them, do not re-baseline.')
    assert(C('sameteam') == 0,
        C('sameteam') .. ' row(s) put a same-team hero in the enemy list. Same '
        .. 'consequence as the line above.')
    assert(C('self_in_allies') == 0,
        C('self_in_allies') .. ' row(s) put the asking hero in its own ALLY '
        .. 'list. Section 5 reads `#allies >= 2` off that list, so its zero '
        .. 'stops meaning what it says: fix the producer or re-take it, do not '
        .. 're-baseline.')
end

tests['[lvlgroup] 4b. BOUND: the levels in this corpus actually differ'] = function()
    cs.ratchet(C('level_spread'), 50,
        'multi-enemy rows within 650 carrying two different levels')
    assert(C('level_spread') > 0,
        'no row in the corpus carries two enemy heroes at different levels -- '
        .. 'sections 1-3 are vacuous and nothing in this file may be quoted')
end

tests['[lvlgroup] 4c. BOUND: the rest of the branch is not driven here']
= function()
    -- Reported so that no reader turns section 2's 2 into a fire rate. Only one
    -- of the branch's other terms besides X.CanAttackTogether is readable on
    -- these frames -- bot:GetLevel() <= 8 -- and the honest cell is its
    -- INTERSECTION with the miss population.
    cs.ratchet(C('lv8'), 806, 'live rows where bot:GetLevel() <= 8')
    assert(C('lv8') < C('live'),
        'every live row is level <= 8; that is a corpus property this bound is '
        .. 'supposed to distinguish, so re-read it before quoting section 2')
    cs.ratchet(C('site_miss_lv8'), 1,
        'miss rows that ALSO satisfy the one other readable term (level <= 8)')
    assert(C('site_miss_lv8') <= C('site_miss'),
        'the intersection is larger than the miss population it is drawn from')
end

tests['[lvlgroup] 4d. BOUND: this site reads the RAW list, and the corpus cannot '
    .. 'tell the two producers apart'] = function()
    -- The call site is bot:GetNearbyHeroes, not J.GetNearbyHeroes, so the list
    -- is not put through J.IsValidHero / the meepo-clone filter. That is a
    -- separate pre-existing question, untouched here. The equality says this
    -- corpus contains no frame where the two differ, so nothing above rests on
    -- it either way -- and the day a fixture does contain one, this goes red and
    -- that question gets asked on purpose instead of by accident.
    assert(C('jfilter_differs') == 0,
        C('jfilter_differs') .. ' row(s) have bot:GetNearbyHeroes and '
        .. 'J.GetNearbyHeroes returning different-sized lists at r = '
        .. SITE_RADIUS .. '. Section 4d was taken on the claim that they never '
        .. 'differ here -- go ask the filtering question on purpose.')
end

-- --------------- 5. THE ZERO: the branch never opens on a lever row ---------

tests['[lvlgroup] 5. MEASURED: arming changes this BRANCH on 0 rows, over a '
    .. '13-row candidate population'] = function()
    -- ⛔ THE WEAKNESS OF THIS LEVER, ASSERTED RATHER THAN FOOTNOTED. The guard
    -- stands beside `X.CanAttackTogether(bot)`, whose `#allies >= 2` term is
    -- false on BOTH miss rows (they carry zero allies within 1200). So the
    -- branch's outcome is false armed and unarmed alike on every row this lever
    -- touches.
    assert(C('miss_cat') == 0,
        C('miss_cat') .. ' miss row(s) now ALSO satisfy X.CanAttackTogether. '
        .. '⭐ THAT IS GOOD NEWS: the branch can finally be driven end to end on '
        .. 'this corpus. Replace this assertion with that drive -- do NOT '
        .. 're-baseline the number.')
    assert(C('miss_ally2') == 0,
        C('miss_ally2') .. ' miss row(s) carry >= 2 allies within ' .. ALLY_RADIUS
        .. '. Same consequence as the line above, one term earlier.')
    -- ⭐ AND THE ZERO IS NOT STRUCTURAL -- this is what makes it worth asserting
    -- rather than conceding. The candidate shape exists in this corpus; none of
    -- its members happens to be a miss. A fixture author reading this knows
    -- exactly what to freeze: a hero with >= 2 allies within 1200, >= 2 enemies
    -- within 650, and the nearest of those enemies BELOW level 12 while another
    -- is at or above it.
    cs.ratchet(C('cand_shape'), 13,
        'rows in the candidate shape (>= 2 allies within 1200 AND >= 2 enemies '
        .. 'within 650)')
    assert(C('cand_shape') > 0,
        'the candidate shape is empty, so the zero above is structural rather '
        .. 'than small-sample and the fixture request in the report is wrong')
    cs.ratchet(C('cat_true'), 124,
        'rows where X.CanAttackTogether reads true (the branch is live here)')
end

tests['[lvlgroup] 5b. the replication of X.CanAttackTogether still matches the '
    .. 'shipped predicate'] = function()
    -- Section 5's zero is taken with can_attack_together() above, a hand copy.
    -- Pin the shipped text against it, so an edit to the real function turns
    -- this red instead of leaving the zero as a statement about a predicate that
    -- no longer exists.
    local src = stripped(read_file(TRG))
    local s = src:find('function X.CanAttackTogether(bot)', 1, true)
    assert(s ~= nil, 'X.CanAttackTogether is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    local body = src:sub(s, e + 3)
    -- ⭐ THE TERMS ARE BUILT FROM THIS FILE'S OWN CONSTANTS, NOT TYPED OUT. A
    -- literal list would pin the shipped function while leaving ALLY_RADIUS /
    -- INNER_RADIUS / INNER_LEVEL free to drift in the replication above -- and
    -- a drift there silently moves what section 5's zero is a statement about
    -- while every ratchet (all floors) stays satisfied. Constructing the strings
    -- makes the two sides one claim. Mutants M16 and M17 are exactly this.
    for _, term in ipairs({
        'bot:GetNearbyHeroes(' .. ALLY_RADIUS .. ',false,BOT_MODE_NONE)',
        'bot:GetNearbyHeroes(' .. INNER_RADIUS .. ',true,BOT_MODE_NONE)',
        'bot:IsAlive()',
        'not bot:IsIllusion()',
        'J.GetProperTarget(bot) == nil',
        '#allies >= 2',
        -- ⭐ 2026-09-11: this term used to be the raw `[1]` comparison. The site
        -- was taken as 'lvltogether', so the shipped text is now a call to that
        -- lever's helper -- and the replication above still reads `[1]` on
        -- purpose, because 'lvltogether' ships GATED and FROZEN-HOLD: the
        -- UNARMED answer, which is what section 5's zero is taken against, is
        -- still exactly `[1] < INNER_LEVEL`. If that gate is ever promoted, this
        -- replication stops matching shipped behaviour and section 5 must be
        -- re-taken rather than re-baselined.
        'X.NoNearbyEnemyAtLevelTogether(nNearbyEnemyHeroes, ' .. INNER_LEVEL .. ')',
    }) do
        assert(body:find(term, 1, true) ~= nil,
            'X.CanAttackTogether no longer contains `' .. term .. '` -- the '
            .. 'replication section 5 measures its zero with is now a copy of '
            .. 'something else. Re-take section 5, do not re-baseline it.')
    end
end

-- --------------------------------------- 5c. the call site, structurally ---

tests['[lvlgroup] 5c. the call site still asks the question this lever is about']
= function()
    local src = stripped(read_file(TRG))
    -- A lever whose caller has been rewritten around it is inert while every
    -- behavioural assertion above stays green -- the cheapest way for this work
    -- to LOOK landed.
    local call = 'X.NoNearbyEnemyAtLevelGroup(nNearbyEnemyHeroes, 12)'
    assert(src:find(call, 1, true) ~= nil,
        'the guard no longer reads ' .. call .. ' -- lvlgroup may now be gating '
        .. 'nothing')
    assert(src:find(
        'local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650,true,BOT_MODE_NONE)',
        1, true) ~= nil,
        'the guard\'s list is no longer the raw bot:GetNearbyHeroes(650, ...) -- '
        .. 'sections 2, 3 and 4d are taken on THAT producer at THAT radius')
    local fs = src:find('function X.CarryFindTarget', 1, true)
    assert(fs ~= nil, 'X.CarryFindTarget is gone from ' .. TRG)
    local fe = src:find('\nfunction ', fs + 1, true) or #src
    local at = src:find(call, fs, true)
    assert(at ~= nil and at < fe,
        'the call site left X.CarryFindTarget -- the header, the domain and '
        .. 'section 1 are all about that function')
    -- ⛔ It must stay in the GROUP-PUSH branch, i.e. after X.CanAttackTogether.
    -- Section 5's whole content is about that conjunct standing beside it; a
    -- call site that drifted into the deny branch above would be 'lvlcarry's
    -- site with a second id on it.
    local cat = src:find('X.CanAttackTogether(bot)', fs, true)
    assert(cat ~= nil and cat < at and at < fe,
        'the call site is no longer inside the branch guarded by '
        .. 'X.CanAttackTogether -- section 5 is then about a different branch')
    -- Count CALLS, not mentions: the definition line matches the same name.
    local _, nAll = src:gsub('X%.NoNearbyEnemyAtLevelGroup%(', '')
    local _, nDef = src:gsub('function X%.NoNearbyEnemyAtLevelGroup%(', '')
    assert(nDef == 1,
        TRG .. ' defines X.NoNearbyEnemyAtLevelGroup ' .. nDef .. ' times')
    assert(nAll - nDef == 1,
        'X.NoNearbyEnemyAtLevelGroup now has ' .. (nAll - nDef) .. ' callers, '
        .. 'not 1 -- the blast radius of this gate changed and the header, '
        .. 'section 7 and the report all describe a one-site lever')
end

-- --------------------------------------------- 6. the gate, structurally ---

tests['[lvlgroup] 6. the gate is turbo-only, single, and the unarmed path is the '
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
    assert(BODY:find('return tHeroes[1]:GetLevel() < nLevel', 1, true) ~= nil,
        'the unarmed leg no longer returns the shipped `[1]` comparison')
    assert(BODY:find('if tHeroes == nil or tHeroes[1] == nil then return true end',
        1, true) ~= nil,
        'the empty-list leg no longer matches the shipped `[1] == nil` term')
    -- The three helpers must stay separate ids: sharing one would arm two or
    -- three call sites together, which is the bundling this lever exists to
    -- avoid.
    for _, other in ipairs({ 'lvlany', 'lvlcarry' }) do
        assert(BODY:find("J.IsSoakCandidate('" .. other .. "')", 1, true) == nil,
            'this helper now reads ' .. other .. '\'s id -- the sites would arm '
            .. 'together, which is the bundling this lever exists to avoid')
    end
end

-- ----------------------------------------------------- 7. THE BATON ---------

tests['[lvlgroup] 7. the baton is empty, and it emptied by ids not deletions']
= function()
    -- 'lvlany' handed over three. 'lvlcarry' took the first, this lever the
    -- second -- the GH #13 shape (a baton that decays into a sentence nobody
    -- re-reads) written as an assertion.
    --
    -- ⭐ 2026-09-11, LATER THE SAME DAY: THE THIRD WAS TAKEN, as 'lvltogether'
    -- (its own id, its own helper X.NoNearbyEnemyAtLevelTogether) -- on exactly
    -- the bar THIS file put in force and at exactly the number the amended
    -- 'lvlcarry' section 7b registered for it. ⛔ The level-10 line is MOVED OUT
    -- of this assertion rather than lowered from 1 to 0, which is literally what
    -- its own failure text asked for; the loop below now spans BOTH thresholds
    -- and requires the shape to be extinct.
    --   ⛔ Extinct is also what a DELETED guard looks like, so extinction is only
    -- half the claim. The pin after it is the other half: all four repaired sites
    -- must still be there as calls to identified helpers.
    local src = stripped(read_file(TRG))
    local function count(text)
        local n, at = 0, 1
        while true do
            local s = src:find(text, at, true)
            if s == nil then break end
            n = n + 1
            at = s + 1
        end
        return n
    end
    for _, th in ipairs({ 10, 12 }) do
        local shape = 'nNearbyEnemyHeroes[1] == nil or '
            .. 'nNearbyEnemyHeroes[1]:GetLevel() < ' .. th
        assert(count(shape) == 0,
            'found ' .. count(shape) .. ' un-repaired level-' .. th .. ' `[1]` '
            .. 'site(s) in ' .. TRG .. '. All four originals are behind ids '
            .. '(lvlany, lvlcarry, lvlgroup, lvltogether); another one appearing '
            .. 'means a NEW site was written in the old shape -- go read it, do '
            .. 'not raise this number.')
    end
    for _, call in ipairs({
        'X.NoNearbyEnemyAtLevel(nNearbyEnemyHeroes, 10)',
        'X.NoNearbyEnemyAtLevelCarry(nNearbyEnemyHeroes, 12)',
        'X.NoNearbyEnemyAtLevelGroup(nNearbyEnemyHeroes, 12)',
        'X.NoNearbyEnemyAtLevelTogether(nNearbyEnemyHeroes, 10)',
    }) do
        assert(src:find(call, 1, true) ~= nil,
            'the site repaired as `' .. call .. '` is gone from ' .. TRG
            .. ' -- the baton emptied because a guard was DELETED, not because '
            .. 'it was taken behind an id. Re-read it.')
    end
end

tests['[lvlgroup] 7b. REGISTERED: this lever shares its miss cell with lvlcarry']
= function()
    -- ⛔ Said out loud so nobody reads section 2 as an independent confirmation
    -- of 'lvlcarry's number. Same list local, same radius, same threshold ⇒ the
    -- SAME two rows. What is independent here is section 1 (the two-cell
    -- finding), section 3e (the direction) and section 5 (the branch zero).
    local src = stripped(read_file(TRG))
    local decl = 'local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650,true,BOT_MODE_NONE)'
    local _, n = src:gsub(decl:gsub('([^%w])', '%%%1'), '')
    assert(n == 1,
        'X.CarryFindTarget declares the 650 enemy list ' .. n .. ' times; this '
        .. 'section rests on both call sites reading ONE local, which is why '
        .. 'their miss populations are the same rows rather than merely equal '
        .. 'numbers')
    assert(src:find('X.NoNearbyEnemyAtLevelCarry(nNearbyEnemyHeroes, 12)',
        1, true) ~= nil,
        'lvlcarry\'s call site is gone -- this section describes the pair')
end

return tests

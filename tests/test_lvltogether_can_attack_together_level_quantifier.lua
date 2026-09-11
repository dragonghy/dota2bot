-- [lvltogether 20260911] THE LAST SIBLING OFF 'lvlany'S BATON, AND THE ONE THAT
-- IS SHAPED DIFFERENTLY FROM THE OTHER THREE.
--
-- THE DEFECT. bots/mode_team_roam_generic.lua, X.CanAttackTogether:
--     local allies             = bot:GetNearbyHeroes(1200,false,BOT_MODE_NONE)
--     local nNearbyEnemyHeroes = bot:GetNearbyHeroes(600,true,BOT_MODE_NONE)
--     return ... and #allies >= 2
--            and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 10)
-- The same existential-question-answered-by-the-nearest defect 'lvlany',
-- 'lvlcarry' and 'lvlgroup' each took one site of, and the empty-list leg beside
-- it is again the author's own proof that the question is existential: a term was
-- already spent separating "nobody here" from "somebody here who is weak". What
-- the expression answers is "is the NEAREST one weak".
--
-- ⭐⭐ TWO THINGS ARE NEW HERE. Both are measured below, not argued.
--   (1) ⛔ THE SUBJECT IS NOT THE ASKING BOT. X.CanAttackTogether takes a HERO
--       PARAMETER, and three of its four call sites pass an ALLY: two branches
--       call it on a chosen ally and X.GetCanTogetherCount walks the whole ally
--       list. So this guard also answers "does MY ALLY have a dangerous enemy
--       next to them", and that answer is COUNTED into "how many of us can go
--       in". No other sibling is ever evaluated about anyone but the asker.
--       SECTION 1 measures that population on its own: 868 ally evaluations over
--       the corpus, 1 of them a miss, and 0 rows where the co-attacker count
--       moves. ⭐ THIS IS THIS FILE'S OWN FINDING; the other three have no
--       counterpart to it.
--   (2) ⛔ ONE PREDICATE, ONE SOURCE SITE, FOUR BRANCHES. Each sibling gates one
--       call site; this gates a predicate four branches read. That is NOT the
--       lanefix bundling -- bundling is several DIFFERENT levers behind one id,
--       and this is one lever whose defect lives in a shared helper, where
--       "repair it at the call site" would mean writing the same repair four
--       times. It does mean this id moves more behaviour than its siblings,
--       which is a reason to keep it alone and gated, not to widen it. SECTION
--       5c pins the caller count so that "four" cannot drift unnoticed.
--
-- ⛔ THE ZERO, AND IT IS SHARPER THAN 'lvlgroup'S. Arming changes this helper's
-- answer on 4 real rows (its own cell, r = 600 / level 10 -- the population
-- 'lvlcarry' section 7b registered and called buyable). It changes
-- X.CanAttackTogether's RETURN on 0, because all 4 carry fewer than 2 allies
-- within 1200. What this corpus can say that 'lvlgroup's could not is WHAT IS
-- MISSING: all 4 miss rows satisfy EVERY OTHER conjunct (alive, not illusion,
-- GetProperTarget == nil) -- section 5 asserts that as an EQUALITY against the
-- miss count, not a floor -- so `#allies >= 2` is the single term standing
-- between those rows and a flip. The candidate shape (>= 2 allies within 1200
-- AND >= 2 enemies within 600) exists on 11 live rows, so the zero is
-- small-sample, not structural. ⭐ WHEN SECTION 5 GOES RED THAT IS GOOD NEWS: a
-- fixture has arrived that drives the lever end to end. Take it as the drive; do
-- NOT re-baseline it.
--
-- ⭐ WHAT CARRIES THE LEVER WHILE THAT ZERO STANDS IS THE DIRECTION, MEASURED
-- OVER ALL 1306 LIVE ROWS (sections 3e and 5d). Armed answers
-- `not any(level >= nLevel)`; shipped answers `[1] < nLevel`; the first implies
-- the second whenever `[1]` exists, so armed is a pure NARROWING. Here that
-- bound reaches further than it did for the siblings: because three call sites
-- COUNT the answer, "never grants a true baseline withheld" means the co-attacker
-- count can only go DOWN armed -- more cautious about grouping, never more
-- reckless. ⛔ It is a bound on the DIRECTION, not a fire rate. No fire rate is
-- claimed anywhere in this file.
--
-- ⛔ THE BAR IS THE ONE ALREADY IN FORCE, and this is the round that executes a
-- judgement two earlier files wrote down rather than re-opening it. 'lvlgroup'
-- put the bar at "the lever's OWN predicate change is driven on real rows", with
-- reachability registered separately as the weaker bound, and amended 'lvlcarry'
-- section 7b in the same commit to say this sibling is buyable under it (4 miss
-- rows at its own cell). Both statements are in the tree; this file takes the
-- sibling on exactly that bar and at exactly that number.
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT BUY, said before any number is read.
--   * IT CAN BUY ENEMY SEMANTICS AND REAL LEVELS. The producer is the raw
--     bot:GetNearbyHeroes, restored by the loader from dump ground truth with a
--     team comparison, a vision check, self excluded and a distance sort;
--     GetLevel is dump ground truth. Section 4a asserts self-exclusion and the
--     team split as EQUALITIES (every ratchet here is a FLOOR, so contamination
--     could only SATISFY one -- the lesson 'anyhero's M7 paid for) and 4b
--     measures the level SPREAD rather than trusting it.
--   * IT CANNOT BUY A FIRE RATE, and it cannot buy the four BRANCHES that read
--     this predicate: none of their other terms is driven here. Section 4c says
--     so as a bound.
--   ⇒ 'lvltogether' is FROZEN-HOLD per OWNER_PRIORITIES P4.2: registered in
--     state.json:lvltogether_20260911, NOT requested into the armed set. The
--     armed string, queue.json and test_set.md are untouched.
--
-- ⛔ THE BATON IS NOW EMPTY, AND SECTION 7 IS WHERE THAT IS RECORDED. 'lvlany'
-- named three siblings; 'lvlcarry', 'lvlgroup' and this lever took one each. The
-- three older files each carried a "N remain" assertion, and all three are
-- amended in THIS commit -- the level-10 key moved OUT of their tables rather
-- than being lowered to 0, which is literally what their own failure text asks
-- for ("move it out of this table and say so in the report -- do not just lower
-- the number"). Section 7 here pins the empty baton from the other side: zero
-- un-repaired `[1]` level sites of this family remain in the file, and all four
-- repaired ones are gone BECAUSE THEY ARE BEHIND IDS, not because a guard was
-- deleted.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/mode_team_roam_generic.lua'
local REF = 'docs/BOT_API_REFERENCE.md'
local CAND = 'lvltogether'

-- X.CanAttackTogether's own constants. Every count in sections 1-5 is taken at
-- these; the sweep in section 2 exists because they are one cell of it.
local SITE_RADIUS = 600
local SITE_LEVEL = 10
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
--- shipped expression and its three siblings, so an unstripped read would let a
--- COMMENT satisfy the structural assertions in 5c, 6 and 7.
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
        'function X.NoNearbyEnemyAtLevelTogether(tHeroes, nLevel)', 1, true)
    assert(s ~= nil, 'X.NoNearbyEnemyAtLevelTogether is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.NoNearbyEnemyAtLevelTogether in ' .. TRG)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.NoNearbyEnemyAtLevelTogether', name))
    setfenv(fn, env)
    return fn()
end

--- The shipped expression, spelled out here so section 3 compares the helper
--- against the TEXT of what shipped rather than against another call of itself.
local function shipped_answer(list, nLevel)
    return (list[1] == nil) or (list[1]:GetLevel() < nLevel)
end

--- X.CanAttackTogether with its level term made a parameter, so the SAME
--- replication can be evaluated with the shipped quantifier and with the armed
--- one. Section 5b pins the shipped text against it, so the day the function is
--- edited this file goes red instead of section 5's zero quietly becoming a
--- statement about a predicate that no longer exists.
local function can_attack_together(J, h, level_fn)
    local allies = h:GetNearbyHeroes(ALLY_RADIUS, false, BOT_MODE_NONE)
    local en = h:GetNearbyHeroes(SITE_RADIUS, true, BOT_MODE_NONE)
    return h ~= nil and h:IsAlive()
        and not h:IsIllusion()
        and J.GetProperTarget(h) == nil
        and #allies >= 2
        and level_fn(en, SITE_LEVEL)
end

--- The armed quantifier, written out once for the replication above. The
--- HELPER itself is never re-implemented here -- sections 3a-3e drive the real
--- shipped bytes; this exists only so section 5 can ask what the FUNCTION
--- returns under each answer.
local function armed_answer(list, nLevel)
    if list[1] == nil then return true end
    for i = 1, #list do
        if list[i]:GetLevel() >= nLevel then return false end
    end
    return true
end

-- ------------------------------------------------------------- the sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 450, 600, 650, 1200, 1600 }

    local function highest(list)
        local hi = 0
        for i = 1, #list do
            local l = list[i]:GetLevel()
            if l > hi then hi = l end
        end
        return hi
    end

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
            local fn = compile(BODY, env, 'lvltogether_body')
            -- 3d. the shipped quantifier restored into the same apparatus.
            -- Counted, not asserted, so a no-op mutation cannot kill the file at
            -- load time.
            local mut = BODY:gsub('for i = 1, #tHeroes do', 'for i = 1, 1 do')
            if mut == BODY then bump('mut_noop') end
            local gn = compile(mut, env, 'lvltogether_mut')

            for _, u in ipairs(fx.units) do
                local h = heroes[u.name]
                if h ~= nil and u.alive then
                    bump('live')
                    if J.IsModeTurbo() then bump('turbo') end

                    -- The call site's own reads, byte for byte: the RAW engine
                    -- method, not J.GetNearbyHeroes.
                    local list = h:GetNearbyHeroes(SITE_RADIUS, true,
                        BOT_MODE_NONE)
                    local allies = h:GetNearbyHeroes(ALLY_RADIUS, false,
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
                        end
                    end

                    -- 2. the sweep. `miss_*` is the population this lever
                    --    changes: the nearest is under the bar, somebody else in
                    --    the same radius is over it.
                    for _, r in ipairs(RADII) do
                        local lr = h:GetNearbyHeroes(r, true, BOT_MODE_NONE)
                        if #lr >= 1 then
                            local f = lr[1]:GetLevel()
                            local hi = highest(lr)
                            for _, th in ipairs({ 10, 12 }) do
                                local k = 'r' .. r .. '_th' .. th
                                if hi >= th then bump('any_' .. k) end
                                if f < th and hi >= th then bump('miss_' .. k) end
                            end
                        end
                    end

                    local isMiss = (#list >= 1)
                        and (list[1]:GetLevel() < SITE_LEVEL)
                        and (highest(list) >= SITE_LEVEL)

                    -- 5. THE ZERO, and -- new here -- WHICH conjunct holds it.
                    local preterms = h:IsAlive() and not h:IsIllusion()
                        and J.GetProperTarget(h) == nil
                    if preterms then bump('preterms') end
                    if preterms and #allies >= 2 then bump('pre_true') end
                    if #allies >= 2 and #list >= 2 then bump('cand_shape') end
                    if isMiss then
                        bump('site_miss')
                        if preterms then bump('miss_preterms') end
                        if #allies >= 2 then bump('miss_ally2') end
                    end

                    -- 5d. the FUNCTION's return under each quantifier.
                    local catOff = can_attack_together(J, h, shipped_answer)
                    local catOn = can_attack_together(J, h, armed_answer)
                    if catOff then bump('cat_true') end
                    if catOn then bump('cat_armed_true') end
                    if catOn ~= catOff then bump('cat_flip') end
                    if catOn == true and catOff ~= true then
                        bump('cat_dir_violation')
                    end

                    -- 1. ⭐ THE ALLY PERSPECTIVE -- this file's own finding.
                    --    Three of the four call sites evaluate this predicate
                    --    about an ALLY, and X.GetCanTogetherCount turns the
                    --    answers into a COUNT. Measure that population on its
                    --    own rather than assuming it mirrors the asker's.
                    local nOff, nOn = 0, 0
                    for i = 1, #allies do
                        bump('ally_evals')
                        if can_attack_together(J, allies[i], shipped_answer) then
                            nOff = nOff + 1
                        end
                        if can_attack_together(J, allies[i], armed_answer) then
                            nOn = nOn + 1
                        end
                        local aen = allies[i]:GetNearbyHeroes(SITE_RADIUS, true,
                            BOT_MODE_NONE)
                        if #aen >= 1 and aen[1]:GetLevel() < SITE_LEVEL
                            and highest(aen) >= SITE_LEVEL then
                            bump('ally_miss')
                        end
                    end
                    bump('ally_rows')
                    if nOn ~= nOff then bump('together_count_differs') end
                    if nOn > nOff then bump('together_count_rose') end
                    if nOff > 0 then bump('together_count_pos') end

                    -- 3. the helper, driven on its own shipped bytes, over EVERY
                    --    live row -- the population it changes is 4, far too
                    --    thin to carry "all 4 of 4" on its own.
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

tests['[lvltogether] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' frames failed to load')
    cs.corpus(C('frames_loaded'), 'lvltogether sweep')
    cs.ratchet(C('live'), 1306, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every driven row is Turbo', 100)
end

-- -------- 1. THIS FILE'S OWN FINDING: the predicate is asked about ALLIES -----

tests['[lvltogether] 1a. MEASURED: the subject is not always the asking bot']
= function()
    -- ⭐ The structural difference from all three siblings. X.CanAttackTogether
    -- takes a hero parameter, and three of its four call sites pass an ALLY --
    -- X.GetCanTogetherCount walks the whole ally list and turns the answers into
    -- a COUNT of co-attackers. So the repair does not only change what THIS bot
    -- thinks about its own surroundings; it changes who gets counted as able to
    -- come along. That population is measured here on its own rather than
    -- assumed to mirror the asker's.
    cs.ratchet(C('ally_evals'), 868,
        'evaluations of the predicate about a hero other than the asker')
    assert(C('ally_evals') > 0,
        'the predicate is never evaluated about an ally on this corpus, so '
        .. 'section 1 is vacuous and the finding above may not be quoted')
    cs.ratchet(C('ally_miss'), 1,
        'ally evaluations where the ALLY\'s own nearest enemy is under the bar '
        .. 'while another within ' .. SITE_RADIUS .. ' is at or above it')
    cs.ratchet(C('together_count_pos'), 144,
        'rows where at least one ally already counts as a co-attacker')
end

tests['[lvltogether] 1b. MEASURED: the co-attacker COUNT moves on 0 rows, and '
    .. 'could only ever fall'] = function()
    -- The consequence of 1a for the thing three call sites actually read. On
    -- this corpus the count is unchanged everywhere -- same small-sample zero
    -- section 5 reports, seen from the ally side.
    --
    -- ⛔ THE DIRECTION CHECK GOES FIRST, AND THE MUTATION STAND IS WHY (M18).
    -- Both assertions below are zeroes, and the second one's failure text reads
    -- "⭐ GOOD NEWS -- a fixture arrived". That message is RIGHT for a corpus
    -- that grew a driving frame and WRONG for an oracle that started widening:
    -- with the direction check second, M18 (armed answers true where shipped
    -- answers false) handed the reader a congratulation for a bug. Ordered this
    -- way, a widening is named as the forbidden direction and only a genuine new
    -- frame reaches the good-news line.
    assert(C('together_count_rose') == 0,
        C('together_count_rose') .. ' row(s) have MORE co-attackers armed than '
        .. 'unarmed. Arming may only ever withdraw a "can attack together", '
        .. 'never grant one -- re-read the helper; do not re-baseline. ⛔ This is '
        .. 'NOT the good-news case below.')
    assert(C('together_count_differs') == 0,
        C('together_count_differs') .. ' row(s) now have a DIFFERENT co-attacker '
        .. 'count armed, all of them narrowings (the line above ruled out the '
        .. 'other direction). ⭐ THAT IS GOOD NEWS: the ally-side path can '
        .. 'finally be driven on this corpus. Read it and replace this assertion '
        .. 'with that drive -- do NOT re-baseline the number.')
end

tests['[lvltogether] 1c. the list IS distance-sorted -- pinned, not assumed']
= function()
    -- Same argument the three siblings rest on and the same reason to pin it a
    -- fourth time: if the order ever stops holding, the claim being made here
    -- ("`[1]` really IS the nearest and the guard is wrong anyway") turns into
    -- the weaker 'anyhero' claim, and the id must be re-argued rather than
    -- re-baselined.
    assert(C('unsorted') == 0,
        C('unsorted') .. ' row(s) came back out of distance order. Re-argue, do '
        .. 'not re-baseline.')
    local doc = read_file(REF)
    assert(doc:find('sorted by distance', 1, true) ~= nil,
        REF .. ' no longer records the engine\'s distance-order promise for the '
        .. 'GetNearby* family -- section 1c cites it')
end

tests['[lvltogether] 1d. MEASURED: the nearest enemy is not the highest-level one']
= function()
    cs.ratchet(C('ge1'), 319, 'rows with at least one enemy hero within 600')
    cs.ratchet(C('ge2'), 87, 'rows carrying two or more')
    cs.ratchet(C('e1_not_highest'), 27, 'rows where the nearest is not the highest')
    assert(C('e1_not_highest') < C('ge2'),
        'the nearest is never the highest on any of the ' .. C('ge2')
        .. ' multi-enemy rows -- that is not a level spread, it is an inverted '
        .. 'corpus; re-read the loader before quoting anything below')
end

-- ------------------------------------- 2. the population the lever changes --

tests['[lvltogether] 2. MEASURED: a sweep, because the shipped cell is one cell of it']
= function()
    -- Registered at r = 450 / 600 / 650 / 1200 / 1600 x threshold 10 / 12. The
    -- shipped call site is r600_th10 = 4; it is reported inside the sweep and
    -- never on its own, so that "4" cannot be read as "the" rate (charter rule
    -- (iii)). ⛔ It is the SAME cell 'lvlcarry' section 7b registered for this
    -- sibling -- said out loud in section 7b here rather than letting a reader
    -- mistake this for an independent confirmation of that number.
    local reg = {
        r450_th10 = 1, r600_th10 = 4, r650_th10 = 5, r1200_th10 = 12,
        r1600_th10 = 15,
        r450_th12 = 0, r600_th12 = 2, r650_th12 = 2, r1200_th12 = 3,
        r1600_th12 = 3,
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
            and C('miss_r650_th' .. th) <= C('miss_r1200_th' .. th)
            and C('miss_r1200_th' .. th) <= C('miss_r1600_th' .. th),
            'the r=450/600/650/1200/1600 miss counts at threshold ' .. th
            .. ' are not monotone -- widening the radius cannot remove a hero, '
            .. 'so these are not one measurement')
    end
    cs.ratchet(C('site_miss'), 4, 'miss rows at the shipped radius and threshold')
    assert(C('site_miss') == C('miss_r600_th10'),
        'the lever population (' .. C('site_miss') .. ') no longer equals the '
        .. 'r600_th10 sweep cell (' .. C('miss_r600_th10') .. ') -- one of them '
        .. 'stopped being the thing this lever is about')
    assert(C('site_miss') > 0,
        'nothing in this corpus is a miss row any more -- sections 3c and 3d are '
        .. 'vacuous and nothing in this file may be quoted')
end

-- ------------------------- 3. the helper, driven on its own shipped bytes ---

tests['[lvltogether] 3a. the drive ran on every live row, not only on the 4']
= function()
    cs.universal(C('drives'), C('live'),
        'the drive visited every live row', 100)
    cs.universal(C('off_no_error'), C('drives'),
        'the unarmed leg completes without raising', 100)
    cs.universal(C('on_no_error'), C('drives'),
        'the armed leg completes without raising', 100)
end

tests['[lvltogether] 3b. UNARMED: the shipped expression, term for term, on all of them']
= function()
    -- ⛔ THE ANTI-VACUUM GOES FIRST, ON PURPOSE. It is a statement about the
    -- ORACLE and it is logically prior to the comparison below: if the shipped
    -- expression answered TRUE on every row, "matches shipped" would be
    -- satisfiable by a helper that always returns true and this whole section
    -- would be green and empty.
    assert(C('shipped_true') < C('drives'),
        'the shipped expression answers true on all ' .. C('drives') .. ' rows, '
        .. 'so 3b is satisfiable by a constant -- re-read the corpus')
    cs.ratchet(C('shipped_true'), 1232, 'rows where the shipped guard reads "clear"')
    cs.universal(C('off_matches_shipped'), C('drives'),
        'the unarmed helper answers exactly what the shipped expression answers',
        100)
end

tests['[lvltogether] 3c. ARMED: differs on exactly the miss rows, agrees everywhere else']
= function()
    cs.universal(C('on_false_on_miss'), C('site_miss'),
        'the armed helper sees the dangerous hero on every miss row', 1)
    cs.universal(C('on_matches_off'), C('drives') - C('site_miss'),
        'and it answers exactly what shipped answers on every other row', 100)
    assert(C('on_matches_off') + C('on_false_on_miss') == C('drives'),
        'armed rows accounted for: ' .. C('on_matches_off') .. ' + '
        .. C('on_false_on_miss') .. ' /= ' .. C('drives'))
end

tests['[lvltogether] 3d. the SHIPPED quantifier, restored into the same apparatus, '
    .. 'goes back to answering what shipped answers'] = function()
    assert(C('mut_noop') == 0,
        'the 3d mutation was a NO-OP on ' .. C('mut_noop') .. ' fixture(s): the '
        .. 'lifted body no longer contains the `for i = 1, #tHeroes` loop, which '
        .. 'means the loop is no longer what makes the difference')
    cs.universal(C('mut_matches_shipped'), C('drives'),
        'collapsing the loop back to [1] restores the shipped answer on every row',
        100)
end

tests['[lvltogether] 3e. THE DIRECTION: armed is a pure NARROWING, on every row']
= function()
    -- ⭐ THE SECTION THAT CARRIES THIS LEVER while section 5's zero stands. With
    -- the function's return unmoved on this corpus, "the repair is correct on the
    -- rows it changes" is true but thin; what makes a gated lever with an
    -- unexercised consumer SAFE to have sitting in the tree is that arming can
    -- only ever subtract the permission, never add it -- and here that reaches
    -- the co-attacker COUNT as well (section 1b).
    cs.universal(C('dir_rows'), C('drives'),
        'both legs answered on every row, so the implication is measured on all '
        .. 'of them', 100)
    assert(C('dir_violation') == 0,
        C('dir_violation') .. ' row(s) have the ARMED helper answering "clear" '
        .. 'where the shipped expression does not. That is arming GRANTING a '
        .. 'group-up baseline withheld -- the one direction this lever may never '
        .. 'take. Re-read the helper; do not re-baseline.')
    -- Anti-vacuum, both ways: the implication is only content if armed answers
    -- true somewhere AND narrows somewhere.
    assert(C('armed_true') > 0,
        'the armed helper never answers "clear" on any of the ' .. C('drives')
        .. ' rows, so the implication above is vacuously satisfied')
    cs.ratchet(C('armed_true'), 1228, 'rows where the ARMED helper reads "clear"')
    cs.ratchet(C('dir_narrows'), 4,
        'rows where arming strictly withdraws the "clear" answer')
    assert(C('dir_narrows') == C('site_miss'),
        'the rows where arming narrows (' .. C('dir_narrows') .. ') are no '
        .. 'longer exactly the miss rows (' .. C('site_miss') .. ')')
end

-- ---------------------- 4. the bounds, measured rather than cited as prose ---

tests['[lvltogether] 4a. BOUND: this producer has real enemy semantics'] = function()
    assert(C('self_in_list') == 0,
        C('self_in_list') .. ' row(s) put the asking hero in its own enemy list. '
        .. 'Sections 1-3 are then measuring geometry, not enemy semantics: fix '
        .. 'the producer or re-take them, do not re-baseline.')
    assert(C('sameteam') == 0,
        C('sameteam') .. ' row(s) put a same-team hero in the enemy list. Same '
        .. 'consequence as the line above.')
    assert(C('self_in_allies') == 0,
        C('self_in_allies') .. ' row(s) put the asking hero in its own ALLY '
        .. 'list. Sections 1 and 5 both read `#allies >= 2` off that list, so '
        .. 'their zeroes stop meaning what they say: fix the producer or re-take '
        .. 'them, do not re-baseline.')
end

tests['[lvltogether] 4b. BOUND: the levels in this corpus actually differ'] = function()
    cs.ratchet(C('level_spread'), 43,
        'multi-enemy rows within 600 carrying two different levels')
    assert(C('level_spread') > 0,
        'no row in the corpus carries two enemy heroes at different levels -- '
        .. 'sections 1-3 are vacuous and nothing in this file may be quoted')
end

tests['[lvltogether] 4c. BOUND: the four branches that READ this predicate are '
    .. 'not driven here'] = function()
    -- Reported so that no reader turns section 2's 4 into a fire rate. Unlike
    -- the siblings, the terms of X.CanAttackTogether ITSELF are all readable on
    -- these frames (section 5 uses that), but the four BRANCHES that consume its
    -- answer carry their own conditions -- mode suitability, tower state, target
    -- selection -- and none of those is exercised by a single dumped frame.
    cs.ratchet(C('preterms'), 1306,
        'rows where the function\'s non-ally, non-level terms all hold')
    cs.ratchet(C('pre_true'), 164,
        'rows where everything but the level guard holds (the function is one '
        .. 'term from true)')
    assert(C('pre_true') < C('live'),
        'every live row already satisfies everything but the level guard; that '
        .. 'is a corpus property this bound is supposed to distinguish, so '
        .. 're-read it before quoting section 2')
end

tests['[lvltogether] 4d. BOUND: this site reads the RAW list, and the corpus cannot '
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

-- ----- 5. THE ZERO: the function's return never moves, and WHY it does not ---

tests['[lvltogether] 5. MEASURED: arming moves X.CanAttackTogether on 0 rows, '
    .. 'and `#allies >= 2` is the single term holding that zero'] = function()
    -- ⛔ THE WEAKNESS OF THIS LEVER, ASSERTED RATHER THAN FOOTNOTED -- and said
    -- one step more precisely than 'lvlgroup' could say it. All 4 miss rows fail
    -- `#allies >= 2` (they carry fewer than 2 allies within 1200), so the
    -- function answers false armed and unarmed alike on every row this lever
    -- touches.
    -- ⛔ THE DIRECTION CHECK GOES FIRST HERE FOR THE SAME REASON IT DOES IN 1b
    -- (mutation stand M18): the flip zero's failure text is a congratulation,
    -- and a congratulation is the wrong thing to hand a reader whose oracle has
    -- started answering "clear" where shipped does not.
    assert(C('cat_dir_violation') == 0,
        C('cat_dir_violation') .. ' row(s) have X.CanAttackTogether reading TRUE '
        .. 'armed where the shipped predicate does not. Arming may only ever '
        .. 'withdraw a group-up, never grant one -- re-read the helper; do not '
        .. 're-baseline. ⛔ This is NOT the good-news case below.')
    assert(C('cat_armed_true') <= C('cat_true'),
        'the function reads true on MORE rows armed (' .. C('cat_armed_true')
        .. ') than unarmed (' .. C('cat_true') .. ') -- that is the forbidden '
        .. 'direction stated as a count')
    assert(C('cat_flip') == 0,
        C('cat_flip') .. ' row(s) now flip X.CanAttackTogether\'s full predicate, '
        .. 'all of them narrowings (the lines above ruled out the other '
        .. 'direction). ⭐ THAT IS GOOD NEWS: the lever can finally be driven end '
        .. 'to end on this corpus. Replace this assertion with that drive -- do '
        .. 'NOT re-baseline the number.')
    assert(C('miss_ally2') == 0,
        C('miss_ally2') .. ' miss row(s) carry >= 2 allies within ' .. ALLY_RADIUS
        .. '. Same consequence as the line above, one term earlier.')
    -- ⭐ AND THIS IS THE PART 'lvlgroup' COULD NOT SAY: an EQUALITY naming the
    -- one term that is missing. Every miss row satisfies alive, not-illusion and
    -- GetProperTarget == nil, so the ONLY thing between these rows and a flip is
    -- two allies. A fixture author reading this knows exactly what to freeze --
    -- and if this equality ever breaks, the zero above has a SECOND cause and
    -- the sentence "one term away" must be re-taken, not re-baselined.
    assert(C('miss_preterms') == C('site_miss'),
        'only ' .. C('miss_preterms') .. ' of the ' .. C('site_miss') .. ' miss '
        .. 'rows satisfy the function\'s other terms. The zero above then has a '
        .. 'second cause besides `#allies >= 2`, so re-take the finding; do not '
        .. 're-baseline this line.')
    -- ⭐ AND THE ZERO IS NOT STRUCTURAL -- this is what makes it worth asserting
    -- rather than conceding. The candidate shape exists in this corpus; none of
    -- its members happens to be a miss.
    cs.ratchet(C('cand_shape'), 11,
        'rows in the candidate shape (>= 2 allies within ' .. ALLY_RADIUS
        .. ' AND >= 2 enemies within ' .. SITE_RADIUS .. ')')
    assert(C('cand_shape') > 0,
        'the candidate shape is empty, so the zero above is structural rather '
        .. 'than small-sample and the fixture request in the report is wrong')
    cs.ratchet(C('cat_true'), 124,
        'rows where X.CanAttackTogether reads true (its consumers are live here)')
end

tests['[lvltogether] 5b. the replication of X.CanAttackTogether still matches the '
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
    -- SITE_RADIUS / SITE_LEVEL free to drift in the replication above -- and a
    -- drift there silently moves what section 5's zero is a statement about
    -- while every ratchet (all floors) stays satisfied. Constructing the strings
    -- makes the two sides one claim.
    for _, term in ipairs({
        'bot:GetNearbyHeroes(' .. ALLY_RADIUS .. ',false,BOT_MODE_NONE)',
        'bot:GetNearbyHeroes(' .. SITE_RADIUS .. ',true,BOT_MODE_NONE)',
        'bot:IsAlive()',
        'not bot:IsIllusion()',
        'J.GetProperTarget(bot) == nil',
        '#allies >= 2',
        'X.NoNearbyEnemyAtLevelTogether(nNearbyEnemyHeroes, ' .. SITE_LEVEL .. ')',
    }) do
        assert(body:find(term, 1, true) ~= nil,
            'X.CanAttackTogether no longer contains `' .. term .. '` -- the '
            .. 'replication section 5 measures its zero with is now a copy of '
            .. 'something else. Re-take section 5, do not re-baseline it.')
    end
    -- ⛔ AND THE ORDER MATTERS TO THE ZERO ITSELF. `#allies >= 2` stands BEFORE
    -- the level guard, so on every miss row Lua short-circuits before the guard
    -- is ever reached. If the level guard were hoisted above it, section 5's
    -- zero would still be 0 but would mean something else entirely.
    local atAllies = body:find('#allies >= 2', 1, true)
    local atLevel = body:find('X.NoNearbyEnemyAtLevelTogether', 1, true)
    assert(atAllies < atLevel,
        'the level guard now stands BEFORE `#allies >= 2`. Section 5\'s zero is '
        .. 'about a short-circuit that no longer happens -- re-take it.')
end

tests['[lvltogether] 5c. the call site, and the four consumers, structurally']
= function()
    local src = stripped(read_file(TRG))
    -- A lever whose caller has been rewritten around it is inert while every
    -- behavioural assertion above stays green -- the cheapest way for this work
    -- to LOOK landed.
    local call = 'X.NoNearbyEnemyAtLevelTogether(nNearbyEnemyHeroes, 10)'
    assert(src:find(call, 1, true) ~= nil,
        'the guard no longer reads ' .. call .. ' -- lvltogether may now be '
        .. 'gating nothing')
    assert(src:find(
        'local nNearbyEnemyHeroes = bot:GetNearbyHeroes(600,true,BOT_MODE_NONE)',
        1, true) ~= nil,
        'the guard\'s list is no longer the raw bot:GetNearbyHeroes(600, ...) -- '
        .. 'sections 1, 2, 3 and 4d are taken on THAT producer at THAT radius')
    local fs = src:find('function X.CanAttackTogether', 1, true)
    assert(fs ~= nil, 'X.CanAttackTogether is gone from ' .. TRG)
    local fe = src:find('\nfunction ', fs + 1, true) or #src
    local at = src:find(call, fs, true)
    assert(at ~= nil and at < fe,
        'the call site left X.CanAttackTogether -- the header, section 1 and '
        .. 'section 5 are all about that function')
    -- Count CALLS, not mentions: the definition line matches the same name.
    local _, nAll = src:gsub('X%.NoNearbyEnemyAtLevelTogether%(', '')
    local _, nDef = src:gsub('function X%.NoNearbyEnemyAtLevelTogether%(', '')
    assert(nDef == 1,
        TRG .. ' defines X.NoNearbyEnemyAtLevelTogether ' .. nDef .. ' times')
    assert(nAll - nDef == 1,
        'X.NoNearbyEnemyAtLevelTogether now has ' .. (nAll - nDef) .. ' callers, '
        .. 'not 1 -- one lever, one id, one definition site')
    -- ⭐ AND THE THING THAT MAKES THIS LEVER DIFFERENT FROM ITS SIBLINGS: the
    -- predicate has ONE definition site but FOUR consumers. The header, section
    -- 1 and the report all say "four"; pin it so that number cannot drift while
    -- every behavioural assertion stays green.
    local _, nCat = src:gsub('X%.CanAttackTogether%(', '')
    local _, nCatDef = src:gsub('function X%.CanAttackTogether%(', '')
    assert(nCatDef == 1,
        TRG .. ' defines X.CanAttackTogether ' .. nCatDef .. ' times')
    assert(nCat - nCatDef == 4,
        'X.CanAttackTogether now has ' .. (nCat - nCatDef) .. ' call sites, not '
        .. '4. The blast radius of this ONE id changed: re-read them and say so '
        .. 'in the report -- do not just change this number.')
    -- ⭐ THREE of the four pass a hero that is NOT the querying bot. That split
    -- IS section 1's finding, so pin the split itself rather than merely that
    -- one such site survives: a call site quietly changed from (ally) to (bot)
    -- would leave section 1 measuring a path the tree no longer has, while every
    -- counter in it -- all floors -- stayed satisfied.
    local _, nAlly = src:gsub('X%.CanAttackTogether%(ally%)', '')
    assert(nAlly == 3,
        'X.CanAttackTogether is now called with an ally at ' .. nAlly
        .. ' sites, not 3. Section 1\'s whole finding is that the subject is '
        .. 'usually NOT the asking bot -- re-read the call sites and say so in '
        .. 'the report; do not just change this number.')
    assert(src:find('function X.GetCanTogetherCount', 1, true) ~= nil,
        'X.GetCanTogetherCount is gone -- section 1b measures the COUNT it '
        .. 'produces')
end

-- --------------------------------------------- 6. the gate, structurally ---

tests['[lvltogether] 6. the gate is turbo-only, single, and the unarmed path is '
    .. 'the shipped expression'] = function()
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
    -- The four helpers must stay separate ids: sharing one would arm two or more
    -- call sites together, which is the bundling this lever exists to avoid.
    for _, other in ipairs({ 'lvlany', 'lvlcarry', 'lvlgroup' }) do
        assert(BODY:find("J.IsSoakCandidate('" .. other .. "')", 1, true) == nil,
            'this helper now reads ' .. other .. '\'s id -- the sites would arm '
            .. 'together, which is the bundling this lever exists to avoid')
    end
end

-- ----------------------------------------------------- 7. THE BATON ---------

tests['[lvltogether] 7. the baton is EMPTY, and it emptied by ids not deletions']
= function()
    -- 'lvlany' named three siblings. 'lvlcarry' took the first, 'lvlgroup' the
    -- second, this lever the third -- so the count is 0 and this is where that
    -- is recorded from the far side. ⛔ The three older files each carried a
    -- "N remain" assertion; all three are amended in THIS commit, with the
    -- level-10 key MOVED OUT of their tables rather than lowered to 0, which is
    -- what their own failure text asks for.
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
            .. 'site(s) in ' .. TRG .. '. All four originals are behind ids now, '
            .. 'so a new one means a NEW site was written in the old shape -- go '
            .. 'read it, do not raise this number.')
    end
    -- ⛔ Zero is also what a DELETED guard looks like, which is why the emptiness
    -- is only half the claim. Pin that each of the four left the shape because
    -- an id was hung on it.
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

tests['[lvltogether] 7b. REGISTERED: this lever shares its miss cell with '
    .. 'lvlcarry section 7b'] = function()
    -- ⛔ Said out loud so nobody reads section 2's 4 as an independent
    -- confirmation of the number 'lvlcarry' registered for this sibling. Same
    -- radius, same threshold, same corpus ⇒ the SAME four rows. What IS
    -- independent here is section 1 (the ally perspective), section 3e (the
    -- direction) and section 5's equality naming `#allies >= 2`.
    local other = 'tests/test_lvlcarry_carry_deny_level_quantifier.lua'
    local s = read_file(other)
    assert(s:find('miss_r600_th10', 1, true) ~= nil,
        other .. ' no longer registers the r600/th10 cell -- this section '
        .. 'describes the pair')
    assert(s:find('lvltogether', 1, true) ~= nil,
        other .. ' section 7b was not amended to record that this sibling was '
        .. 'taken. A file still saying "go take it" after it was taken is how '
        .. 'this family\'s standard erodes -- amend it, do not delete this line.')
end

return tests

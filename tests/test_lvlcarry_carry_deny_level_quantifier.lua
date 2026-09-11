-- [lvlcarry 20260911] THE FIRST SIBLING OFF 'lvlany'S BATON: THE CARRY'S DENY
-- GUARD ASKS AN EXISTENTIAL QUESTION ABOUT *LEVEL* AND ANSWERS IT WITH THE
-- NEAREST HERO.
--
-- THE DEFECT. bots/mode_team_roam_generic.lua, X.CarryFindTarget's
-- last-hit/deny/tower branch:
--     local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650,true,BOT_MODE_NONE)
--     if IsModeSuitHit
--        and (botHP > 0.38 or not bot:WasRecentlyDamagedByAnyHero(3.0))
--        and (nNearbyEnemyHeroes[1] == nil or nNearbyEnemyHeroes[1]:GetLevel() < 12)
-- The empty-list leg written beside it (`[1] == nil`) is what proves the
-- question is existential -- the author already spent a term separating "nobody
-- here" from "somebody here who is weak". What the expression answers is "is the
-- NEAREST one weak".
--
-- ⭐ WHY THIS IS A SECOND LEVER AND NOT 'lvlany' WIDENED. Three differences, all
-- of them load-bearing: a different function and branch (the carry's deny branch,
-- not the support's laning guard); different constants (r = 650 / level 12, not
-- 750 / 10, and the corpus reads DIFFERENTLY at them -- the miss population is 2
-- here against 7 there, section 2); and a different producer -- this site reads
-- bot:GetNearbyHeroes DIRECTLY rather than through J.GetNearbyHeroes, so it is
-- not J.IsValidHero-filtered. Section 4d measures that the two lists never
-- differ on this corpus, so nothing here rests on that difference in either
-- direction, and the filtering question is left untouched.
--
-- ⛔ AND WHY IT IS A SECOND HELPER RATHER THAN A SECOND CALLER OF 'lvlany'S.
-- Sharing the helper would put both sites behind ONE id, which is the bundling
-- the lanefix rejections paid for (gpm -74.5, then -88.7, 0/4 comps); giving the
-- shared helper two ids would be the pullcad trap (a gate written as a
-- conjunction of ids freezes FALSE the day either is promoted). 'lvlany's
-- section 5b pins it at exactly one caller precisely so this cannot happen by
-- accident. Nine duplicated lines is the cheap side of that trade.
--
-- WHAT IT COSTS. The branch returns BOT_MODE_DESIRE_ABSOLUTE * 0.97 to walk up
-- and last-hit/deny, and the term above the sub-branch caps the bot at level 8.
-- The anchor row is real, not hypothetical:
-- tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua -- slardar at level 7,
-- three enemies inside 650, the NEAREST is tidehunter at level 8 and 191 units,
-- and lina at level 12 is one of the other two. The shipped guard reads "clear".
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT BUY, said before any number below is read.
--   * IT CAN BUY ENEMY SEMANTICS. The producer is bot:GetNearbyHeroes, which the
--     loader restores from dump ground truth with a team comparison, a vision
--     check, self excluded and a distance sort (mock/replay_fixture.lua:1372).
--     Section 4a asserts the self-exclusion and the team split as EQUALITIES, so
--     the day either stops holding this file goes red instead of every ratchet
--     quietly meaning something else (they are all floors, so contamination
--     could only satisfy them -- that is the lesson M7 taught 'anyhero').
--   * IT CAN BUY REAL LEVELS: GetLevel is dump ground truth
--     (mock/replay_fixture.lua:666), and section 4b measures the SPREAD rather
--     than trusting it -- 50 of the 104 multi-enemy rows carry two different
--     levels. A corpus of uniform levels would leave sections 1-3 green and
--     vacuous.
--   * IT CANNOT BUY A FIRE RATE. The branch's other terms -- IsModeSuitHit,
--     botHP/WasRecentlyDamagedByAnyHero, the two fountain distances -- are not
--     driven here. Section 4c reports the ONE other term that is readable
--     (bot:GetLevel() <= 8, which gates the deny sub-branch) intersected with
--     the miss population, as a BOUND: 1 row. No claim about how often this
--     fires in a real game appears anywhere in this file.
--   ⇒ 'lvlcarry' is FROZEN-HOLD per OWNER_PRIORITIES P4.2: registered in
--     state.json:lvlcarry_20260911, NOT requested into the armed set. The armed
--     string, queue.json and test_set.md are untouched.
--
-- HOW SECTION 3 DRIVES IT, AND WHY THE DENOMINATOR IS 1306 AND NOT 2. 'lvlany'
-- drove only the rows its lever changes (7 of them). Here that population is 2,
-- which is thin enough that "all 2 of 2" would be close to vacuous. So the drive
-- runs over EVERY live row instead, and the claim is split in two:
--   3b  the UNARMED helper equals the shipped expression on all 1306 rows
--       -- byte-identity measured over the whole corpus, not read off the diff;
--   3c  the ARMED helper differs from it on EXACTLY the miss rows, and agrees
--       with it everywhere else (1304 rows).
-- A thin effect population is then a measured fact about the corpus rather than
-- a thin apparatus: the anti-vacuum guard sits on 1306, and the 2 carries its
-- own `> 0` assertion. The helper's body is not replicated here -- it is lifted
-- VERBATIM out of the shipped file, compiled with loadstring and run under
-- setfenv, reading exactly two names (J from the fixture loader, and
-- J.IsSoakCandidate INJECTED as the arm under test). Section 3d mutates that
-- same lifted text back to a `[1]`-only body and re-runs it through the same
-- machinery: the armed leg must go back to answering what shipped answers.
--
-- ⛔ SECTION 7 IS THE BATON, AND IT IS AN ASSERTION, NOT AN ISSUE. 'lvlany' left
-- three siblings; this lever takes one, so TWO remain and section 7 counts them.
-- It also registers the one thing this round measured about the next one: the
-- X.CanAttackTogether sibling's FULL predicate never flips on this corpus (its 4
-- miss rows all fail `#allies >= 2`), so a round that takes it on these fixtures
-- would be driving nothing. That zero is an assertion too -- when it goes red,
-- the corpus can finally buy that sibling, and that is good news, not a break.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/mode_team_roam_generic.lua'
local REF = 'docs/BOT_API_REFERENCE.md'
local CAND = 'lvlcarry'

-- The shipped call site's own two constants. Every count in sections 2 and 3 is
-- taken at these; the sweep in section 2 exists because they are one cell of it.
local SITE_RADIUS = 650
local SITE_LEVEL = 12

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block quotes the
--- shipped expression and the two remaining siblings, so an unstripped read
--- would let a COMMENT satisfy the structural assertions in 5, 6 and 7.
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
        'function X.NoNearbyEnemyAtLevelCarry(tHeroes, nLevel)', 1, true)
    assert(s ~= nil, 'X.NoNearbyEnemyAtLevelCarry is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.NoNearbyEnemyAtLevelCarry in ' .. TRG)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.NoNearbyEnemyAtLevelCarry', name))
    setfenv(fn, env)
    return fn()
end

--- The shipped expression, spelled out here so section 3 compares the helper
--- against the TEXT of what shipped rather than against another call of itself.
local function shipped_answer(list, nLevel)
    return (list[1] == nil) or (list[1]:GetLevel() < nLevel)
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
            local fn = compile(BODY, env, 'lvlcarry_body')
            -- 3d. the shipped quantifier restored into the same apparatus.
            -- Counted, not asserted, so a no-op mutation cannot kill the file at
            -- load time.
            local mut = BODY:gsub('for i = 1, #tHeroes do', 'for i = 1, 1 do')
            if mut == BODY then bump('mut_noop') end
            local gn = compile(mut, env, 'lvlcarry_mut')

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

                    -- 4a. Its own pass, so a mutant that breaks the producer's
                    -- self-exclusion shows up HERE rather than by silently
                    -- inflating the ratchets below (all of which are floors).
                    for i = 1, #list do
                        if list[i] == h then bump('self_in_list') end
                        if list[i]:GetTeam() == h:GetTeam() then bump('sameteam') end
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

                    -- 7. the NEXT sibling, measured rather than guessed: the
                    --    X.CanAttackTogether copy at r = 600 / level 10. Its
                    --    full predicate is readable here, so the question "could
                    --    a round take it on these fixtures" has an answer.
                    local allies = h:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
                    -- 4a, the ALLY half. Found by M13 of the mutation stand:
                    -- breaking the producer's self-exclusion does NOT put the
                    -- asking hero in its own ENEMY list (the team comparison
                    -- rejects it a second time), so the enemy-side equality
                    -- alone cannot see that mutation -- it surfaces here, in
                    -- `#allies >= 2`, which is what 7b's zero rests on.
                    for i = 1, #allies do
                        if allies[i] == h then bump('self_in_allies') end
                    end
                    local catPre = h:IsAlive() and not h:IsIllusion()
                        and J.GetProperTarget(h) == nil and #allies >= 2
                    local en600 = h:GetNearbyHeroes(600, true, BOT_MODE_NONE)
                    if #en600 >= 1 then
                        local hi = 0
                        for i = 1, #en600 do
                            local l = en600[i]:GetLevel()
                            if l > hi then hi = l end
                        end
                        if en600[1]:GetLevel() < 10 and hi >= 10 and catPre then
                            bump('cat_flip')
                        end
                    end

                    -- 3. the helper, driven on its own shipped bytes, over EVERY
                    --    live row -- see the header for why the denominator is
                    --    1306 and not the 2 rows the lever changes.
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
-- equalities on purpose -- zero is already growth-immune.

tests['[lvlcarry] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' frames failed to load')
    cs.corpus(C('frames_loaded'), 'lvlcarry sweep')
    cs.ratchet(C('live'), 1306, 'live hero frames')
    cs.universal(C('turbo'), C('live'), 'every driven row is Turbo', 100)
end

-- ---------------- 1. the list is ordered; the question is not about order ---

tests['[lvlcarry] 1a. MEASURED: the nearest enemy is not the highest-level one']
= function()
    cs.ratchet(C('ge1'), 357, 'rows with at least one enemy hero within 650')
    cs.ratchet(C('ge2'), 104, 'rows carrying two or more')
    -- 32/104 registered. Both directions matter: if `[1]` were always the
    -- highest the guard would be right by accident, and if it were never the
    -- highest the sweep would be measuring something other than a level spread.
    cs.ratchet(C('e1_not_highest'), 32, 'rows where the nearest is not the highest')
    cs.ratchet(C('e1_strictly_lower'), 32, 'rows where the nearest is strictly lower')
    assert(C('e1_not_highest') < C('ge2'),
        'the nearest is never the highest on any of the ' .. C('ge2')
        .. ' multi-enemy rows -- that is not a level spread, it is an inverted '
        .. 'corpus; re-read the loader before quoting anything below')
end

tests['[lvlcarry] 1b. the list IS distance-sorted -- pinned, not assumed']
= function()
    -- Same argument 'lvlany' rests on and the same reason to pin it: if the
    -- order ever stops holding, the claim being made here ("`[1]` really IS the
    -- nearest and the guard is wrong anyway") turns into the weaker 'anyhero'
    -- claim, and the id must be re-argued rather than re-baselined.
    assert(C('unsorted') == 0,
        C('unsorted') .. ' row(s) came back out of distance order. Re-argue, do '
        .. 'not re-baseline.')
    local doc = read_file(REF)
    assert(doc:find('sorted by distance', 1, true) ~= nil,
        REF .. ' no longer records the engine\'s distance-order promise for the '
        .. 'GetNearby* family -- section 1b cites it')
end

-- ------------------------------------- 2. the population the lever changes --

tests['[lvlcarry] 2. MEASURED: a sweep, because the shipped cell is one cell of it']
= function()
    -- Registered at r = 450 / 600 / 650 / 1600 x threshold 10 / 12. The shipped
    -- call site is r650_th12 = 2; it is reported inside the sweep and never on
    -- its own, so that "2" cannot be read as "the" rate (charter rule (iii)).
    -- It is also where this lever differs from 'lvlany' numerically: that site's
    -- cell (r750_th10) is 7.
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
    -- The lever's own population, with its own anti-vacuum guard: it is small,
    -- and small is a fact about the corpus, not a licence for it to be zero.
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

tests['[lvlcarry] 3a. the drive ran on every live row, not only on the 2']
= function()
    cs.universal(C('drives'), C('live'),
        'the drive visited every live row', 100)
    cs.universal(C('off_no_error'), C('drives'),
        'the unarmed leg completes without raising', 100)
    cs.universal(C('on_no_error'), C('drives'),
        'the armed leg completes without raising', 100)
end

tests['[lvlcarry] 3b. UNARMED: the shipped expression, term for term, on all of them']
= function()
    -- ⛔ THE ANTI-VACUUM GOES FIRST, ON PURPOSE. It is a statement about the
    -- ORACLE, and it is logically prior to the comparison below: if the shipped
    -- expression answered TRUE on every row, "matches shipped" would be
    -- satisfiable by a helper that always returns true, and this whole section
    -- would be green and empty. Asserting it second would mean the degenerate
    -- oracle gets reported as "the helper disagrees with shipped", which sends
    -- the next reader to the wrong file.
    assert(C('shipped_true') < C('drives'),
        'the shipped expression answers true on all ' .. C('drives') .. ' rows, '
        .. 'so 3b is satisfiable by a constant -- re-read the corpus')
    cs.ratchet(C('shipped_true'), 1242, 'rows where the shipped guard reads "clear"')
    -- The byte-identity claim, MEASURED against the TEXT of the shipped
    -- expression (shipped_answer above) rather than read off the diff. This is
    -- the assertion that says the gate does not leak.
    cs.universal(C('off_matches_shipped'), C('drives'),
        'the unarmed helper answers exactly what the shipped expression answers',
        100)
end

tests['[lvlcarry] 3c. ARMED: differs on exactly the miss rows, agrees everywhere else']
= function()
    cs.universal(C('on_false_on_miss'), C('site_miss'),
        'the armed helper sees the dangerous hero on every miss row', 1)
    cs.universal(C('on_matches_off'), C('drives') - C('site_miss'),
        'and it answers exactly what shipped answers on every other row', 100)
    -- Stated as its own line because it is the whole behavioural claim: armed
    -- changes the answer on site_miss rows and on nothing else.
    assert(C('on_matches_off') + C('on_false_on_miss') == C('drives'),
        'armed rows accounted for: ' .. C('on_matches_off') .. ' + '
        .. C('on_false_on_miss') .. ' /= ' .. C('drives'))
end

tests['[lvlcarry] 3d. the SHIPPED quantifier, restored into the same apparatus, '
    .. 'goes back to answering what shipped answers'] = function()
    assert(C('mut_noop') == 0,
        'the 3d mutation was a NO-OP on ' .. C('mut_noop') .. ' fixture(s): the '
        .. 'lifted body no longer contains the `for i = 1, #tHeroes` loop, which '
        .. 'means the loop is no longer what makes the difference')
    cs.universal(C('mut_matches_shipped'), C('drives'),
        'collapsing the loop back to [1] restores the shipped answer on every row',
        100)
end

-- ---------------------- 4. the bounds, measured rather than cited as prose ---

tests['[lvlcarry] 4a. BOUND: this producer has real enemy semantics'] = function()
    assert(C('self_in_list') == 0,
        C('self_in_list') .. ' row(s) put the asking hero in its own enemy list. '
        .. 'Sections 1-3 are then measuring geometry, not enemy semantics: fix '
        .. 'the producer or re-take them, do not re-baseline.')
    assert(C('sameteam') == 0,
        C('sameteam') .. ' row(s) put a same-team hero in the enemy list. Same '
        .. 'consequence as the line above.')
    -- ⭐ The ally half, and it is NOT redundant -- the mutation stand is what
    -- proved that. Delete the producer's `other ~= self` guard and the enemy
    -- list is UNCHANGED, because the team comparison rejects the asking hero a
    -- second time on the way in. The two equalities above therefore cannot see
    -- that mutation at all; it lands in the ALLY list, where it inflates
    -- `#allies >= 2` and so silently moves what 7b's zero is a statement about.
    assert(C('self_in_allies') == 0,
        C('self_in_allies') .. ' row(s) put the asking hero in its own ALLY '
        .. 'list. Section 7b reads `#allies >= 2` off that list, so its zero '
        .. 'stops meaning what it says: fix the producer or re-take it, do not '
        .. 're-baseline.')
end

tests['[lvlcarry] 4b. BOUND: the levels in this corpus actually differ'] = function()
    cs.ratchet(C('level_spread'), 50,
        'multi-enemy rows within 650 carrying two different levels')
    assert(C('level_spread') > 0,
        'no row in the corpus carries two enemy heroes at different levels -- '
        .. 'sections 1-3 are vacuous and nothing in this file may be quoted')
end

tests['[lvlcarry] 4c. BOUND: the rest of the branch is not driven here']
= function()
    -- Reported so that no reader turns section 2's 2 into a fire rate. Only one
    -- of the branch's other terms is readable on these frames -- the
    -- bot:GetLevel() <= 8 that gates the deny sub-branch -- and the honest cell
    -- is its INTERSECTION with the miss population, which is 1 row.
    cs.ratchet(C('lv8'), 806, 'live rows where bot:GetLevel() <= 8')
    assert(C('lv8') < C('live'),
        'every live row is level <= 8; that is a corpus property this bound is '
        .. 'supposed to distinguish, so re-read it before quoting section 2')
    cs.ratchet(C('site_miss_lv8'), 1,
        'miss rows that ALSO satisfy the one other readable term (level <= 8)')
    assert(C('site_miss_lv8') <= C('site_miss'),
        'the intersection is larger than the miss population it is drawn from')
end

tests['[lvlcarry] 4d. BOUND: this site reads the RAW list, and the corpus cannot '
    .. 'tell the two producers apart'] = function()
    -- The call site is bot:GetNearbyHeroes, not J.GetNearbyHeroes, so the list
    -- is not put through J.IsValidHero / the meepo-clone filter. That is a
    -- separate pre-existing question. The equality says this corpus contains no
    -- frame where the two differ, so nothing above rests on it either way -- and
    -- the day a fixture does contain one, this goes red and that question gets
    -- asked on purpose instead of by accident.
    assert(C('jfilter_differs') == 0,
        C('jfilter_differs') .. ' row(s) have bot:GetNearbyHeroes and '
        .. 'J.GetNearbyHeroes returning different-sized lists at r=' .. SITE_RADIUS
        .. '. This lever drives the RAW one because that is what the call site '
        .. 'reads; a corpus that can tell them apart is a new question, not a '
        .. 'baseline to move.')
end

-- ------------- 5. condition (c), counted in the file rather than argued in prose --

tests['[lvlcarry] 5. the file\'s own idiom for a set question is a loop'] = function()
    local src = stripped(read_file(TRG))
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

tests['[lvlcarry] 5b. the call site still asks the question this lever is about']
= function()
    local src = stripped(read_file(TRG))
    -- A lever whose caller has been rewritten around it is inert while every
    -- behavioural assertion above stays green -- the cheapest way for this work
    -- to LOOK landed. Pin the call site itself, and pin that it is still inside
    -- X.CarryFindTarget rather than merely somewhere in the file.
    local call = 'X.NoNearbyEnemyAtLevelCarry(nNearbyEnemyHeroes, 12)'
    assert(src:find(call, 1, true) ~= nil,
        'the guard no longer reads ' .. call .. ' -- lvlcarry may now be gating '
        .. 'nothing')
    assert(src:find(
        'local nNearbyEnemyHeroes = bot:GetNearbyHeroes(650,true,BOT_MODE_NONE)',
        1, true) ~= nil,
        'the guard\'s list is no longer the raw bot:GetNearbyHeroes(650, ...) -- '
        .. 'sections 2, 3 and 4d are taken on THAT producer at THAT radius')
    local fs = src:find('function X.CarryFindTarget', 1, true)
    assert(fs ~= nil, 'X.CarryFindTarget is gone from ' .. TRG)
    local fe = src:find('\nfunction ', fs + 1, true) or #src
    assert(src:find(call, fs, true) ~= nil and src:find(call, fs, true) < fe,
        'the call site left X.CarryFindTarget -- the header, the domain and the '
        .. 'anchor frame are all about that function')
    -- Count CALLS, not mentions: the definition line matches the same name.
    local _, nAll = src:gsub('X%.NoNearbyEnemyAtLevelCarry%(', '')
    local _, nDef = src:gsub('function X%.NoNearbyEnemyAtLevelCarry%(', '')
    assert(nDef == 1,
        TRG .. ' defines X.NoNearbyEnemyAtLevelCarry ' .. nDef .. ' times')
    assert(nAll - nDef == 1,
        'X.NoNearbyEnemyAtLevelCarry now has ' .. (nAll - nDef) .. ' callers, not '
        .. '1 -- the blast radius of this gate changed and the header, section 7 '
        .. 'and the report all describe a one-site lever')
end

-- --------------------------------------------- 6. the gate, structurally ---

tests['[lvlcarry] 6. the gate is turbo-only, single, and the unarmed path is the '
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
    -- The two helpers must stay separate ids: see the header for why sharing one
    -- would be either the lanefix bundle or the pullcad trap.
    assert(BODY:find("J.IsSoakCandidate('lvlany')", 1, true) == nil,
        'this helper now reads lvlany\'s id -- the two sites would arm together, '
        .. 'which is the bundling this lever exists to avoid')
end

-- ----------------------------------------------------- 7. THE BATON ---------

tests['[lvlcarry] 7. one sibling left']
= function()
    -- 'lvlany' handed over three. This lever takes the first. Counted here so
    -- that "two remain" cannot decay into a sentence nobody re-reads -- the GH
    -- #13 shape, which went missing for 37 rounds as a closeable issue.
    --
    -- 2026-09-11: the second was taken by 'lvlgroup' (the group-push branch's
    -- level-12 site, its own id and its own helper -- see the block above
    -- X.NoNearbyEnemyAtLevelGroup). It is MOVED OUT of the table below rather
    -- than having its number lowered, which is what the assertion text asked
    -- for. ONE remains: the level-10 site inside X.CanAttackTogether.
    --
    -- ⭐ 2026-09-11, LATER: THE LAST ONE WAS TAKEN TOO, as 'lvltogether' (its own
    -- id, its own helper X.NoNearbyEnemyAtLevelTogether), on the bar 'lvlgroup'
    -- put in force and at exactly the number section 7b below registered for it.
    -- Its key is MOVED OUT of the table rather than lowered to 0 -- what the
    -- failure text of this assertion asks for -- and `total` drops 1 -> 0.
    --   ⛔ An empty table is also what a DELETED guard looks like, so the loop no
    -- longer carries the claim alone: the pin after it requires all four repaired
    -- sites to still be there as calls to identified helpers.
    local src = stripped(read_file(TRG))
    local siblings = {}
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
    assert(total == 0,
        'the baton is ' .. total .. ' sites, not 0 -- the report says none remains')
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

tests['[lvlcarry] 7b. MEASURED: the CanAttackTogether sibling\'s BRANCH never '
    .. 'flips on this corpus'] = function()
    -- Cheap to measure while the sweep was already loaded, and it is the thing
    -- the next round most needs to know: that sibling's full predicate
    -- (alive, not illusion, GetProperTarget == nil, #allies >= 2, the level
    -- guard) never flips here. Its 4 miss rows at r=600/level 10 all fail
    -- `#allies >= 2`.
    --
    -- ⛔ AMENDED 2026-09-11 BY 'lvlgroup', AND THE AMENDMENT IS THE POINT. As
    -- first written this comment concluded "a round that took it on these
    -- fixtures would be asserting over an empty drive -- green and vacuous", and
    -- that conclusion rested on a STRICTER BAR than the family actually uses:
    -- "the full predicate flips". 'lvlgroup' measured the identical zero at its
    -- own site (both its miss rows fail the same `#allies >= 2` conjunct, so
    -- arming changes its BRANCH on 0 rows) and was taken anyway, on the bar
    -- "the lever's own predicate change is driven on real rows" with branch
    -- reachability registered separately as the weaker bound. Under that bar
    -- this sibling is buyable too -- 4 miss rows at its own cell. Two bars
    -- applied to two siblings of one family is how a standard erodes without
    -- anyone deciding to change it, so the bar in force is written here rather
    -- than left implied.
    --   ⇒ WHAT THE ZERO BELOW STILL MEANS: not "do not take this sibling", but
    --     "taking it buys a correct predicate whose branch this corpus cannot
    --     exercise". Say that in the lever's own file, as
    --     tests/test_lvlgroup_group_push_level_quantifier.lua section 5 does.
    --
    -- ⭐ 2026-09-11, AND THIS IS THE LINE THAT CHANGED WHAT THIS SECTION IS FOR:
    -- THE SIBLING WAS TAKEN, as 'lvltogether'. So the sentence "go take it" below
    -- is spent, and what this section now IS is a second, independent read of
    -- that lever's cell from outside its own file -- 'lvltogether' section 7b
    -- points back here and asserts this file says so, precisely so that a file
    -- still telling the next round to take an already-taken sibling cannot sit in
    -- the tree. The zero itself is UNCHANGED in meaning: the shipped (unarmed)
    -- predicate still never flips here, because 'lvltogether' ships gated and
    -- FROZEN-HOLD, and the reading is a hand replication in this file rather than
    -- a call into the source.
    --   ⇒ 'lvltogether' section 5 carries the same zero measured against the real
    --     helper, plus the equality this section could not state: all 4 miss rows
    --     satisfy every OTHER conjunct, so `#allies >= 2` is the single term
    --     between them and a flip.
    --
    -- ⭐ WHEN THIS GOES RED IT IS STILL GOOD NEWS: a fixture has arrived that can
    -- drive that lever end to end. Go drive it there -- do not lower the number.
    assert(C('cat_flip') == 0,
        C('cat_flip') .. ' row(s) now flip X.CanAttackTogether\'s full predicate. '
        .. 'The corpus can finally drive \'lvltogether\' end to end -- go do that '
        .. 'in tests/test_lvltogether_can_attack_together_level_quantifier.lua '
        .. 'section 5, and replace this assertion with that drive rather than '
        .. 're-baselining it.')
    cs.ratchet(C('miss_r600_th10'), 4,
        'miss rows at the CanAttackTogether sibling\'s own constants')
end

return tests

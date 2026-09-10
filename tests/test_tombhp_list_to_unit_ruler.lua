-- [tombhp 20260910] A LIST WAS HANDED TO A RULER THAT MEASURES A UNIT, and the
-- ruler does not answer false -- it RAISES.
--
-- THE DEFECT (charter criterion (5), the variant the previous round named on its
-- way out: "a set is computed, and then handed to a ruler that measures the
-- wrong thing"). bots/mode_roam_generic.lua, the tombstone branch of
-- ConsiderGeneralRoamingInConditions:
--     nInRangeEnemy = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)   -- :67, :468
--     ...
--     and J.IsValidHero(nInRangeEnemy[1]) and J.GetHP(nInRangeEnemy) > 0.35 then
-- The first conjunct indexes the list. The second passes it WHOLE. J.GetHP's
-- first statement is `unit:GetHealth()` (jmz_func.lua:4141), so on a plain array
-- that indexes nil and raises. Section 1 executes it on the real corpus:
-- 573 of 573 frames that reach the conjunct RAISE, every message naming
-- GetHealth. So the shipped conjunct never returns false and never returns true:
-- it aborts ConsiderGeneralRoamingInConditions, taking every branch below it
-- with it, and the engine's error handler is broken (AGENTS.md, "no bot-side
-- debugging"), so nothing anywhere says so.
--
-- WHY IT IS `[1]` AND NOT SOMETHING ELSE -- condition (c) is inside this file,
-- not on a wiki. The sibling branch at :1789 already reads
-- `J.IsValidHero(nInRangeEnemy[1]) and J.IsInRange(bot, nInRangeEnemy[1], ...)`,
-- and the six neighbouring debuff branches in the same `J.IsInLaningPhase()`
-- block (nevermore / monkey king / viper / huskar / batrider / slark) all read
-- ONE enemy's HP against the bot's. The intent -- "the nearest enemy hero is not
-- nearly dead, so leaving is right" -- is unambiguous; only the index was lost.
--
-- ⭐ THE FIX SPLITS IN TWO, AND ONLY THE SECOND HALF IS GATED.
--   * Removing the CRASH is unconditional -- it is the INDEX, not the gate.
--     Section 3 executes that (299/299 driven frames: unarmed, no error, result
--     false). This is deliberately NOT byte-identical to the shipped path. A
--     runtime error is not a behaviour any wave could ever have attributed
--     anything to.
--     ⚠️ The gate's POSITION before the J.GetHP term is a second layer, not the
--     mechanism, and this file said the opposite until its own mutation stand
--     disproved it: moving the gate below the term (M3) does NOT bring the raise
--     back, because the term is repaired. It takes BOTH (M10) -- and M10 is why
--     the ordering is pinned in section 5 anyway: with the gate first, a future
--     half-revert of the index still cannot raise on the unarmed leg.
--   * Letting the branch FIRE is a behaviour change and is gated turbo-only
--     behind 'tombhp', like every other new lever.
--
-- ⛔ WHAT THIS CORPUS CANNOT BUY, said before any number below is read.
--   * The OUTER guard has no rows: modifier_undying_tombstone_zombie_deathstrike_slow
--     appears on 0 of 1270 live hero frames (section 4 measures it rather than
--     asserting it), and botTarget is J.GetProperTarget, structurally nil on
--     every fixture (GH #474). ⇒ NO fire-rate claim is made about real games and
--     not one number below may be quoted as one.
--   * What the corpus DOES carry is the CONJUNCT THIS ID CHANGES. Its own domain
--     is real dump geometry -- 573 rows where the enemy-hero list is non-empty --
--     and that is the whole reason this lever was allowed to land a gate at all
--     where the previous round's barracks candidate was not (its predicate had
--     0 rows, not merely its ambient guard).
--
-- HOW SECTION 3 DRIVES IT. The condition is not replicated here: the `if` text
-- is lifted VERBATIM out of bots/mode_roam_generic.lua, compiled with loadstring
-- and run under setfenv. Everything it reads is listed one by one, and only the
-- last two are injected:
--     J                             real jmz_func from the fixture loader
--     bot                           a real dump hero with J.GetHP(bot) < 0.8
--     nInRangeEnemy                 that hero's real bot:GetNearbyHeroes(1200, true)
--     GetUnitToUnitDistance, DotaTime, J.IsModeTurbo   real
--     enemy                         INJECTED: a real enemy hero within 1200
--                                   standing in for the tombstone unit, so the
--                                   first disjunct is carried by real geometry
--     cachedTombstoneZombieSlowState  INJECTED: -1000, so the SECOND disjunct is
--                                   dead and the OR is not satisfied for free
--     J.IsSoakCandidate             INJECTED: the arm under test
-- Section 3d then MUTATES the lifted text back to the shipped `J.GetHP(nInRangeEnemy)`
-- and re-runs it through the same machinery: 299/299 raise. The defect and its
-- repair are therefore read off one apparatus, not two.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local ROAM = 'bots/mode_roam_generic.lua'
local CAND = 'tombhp'

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block names the
--- id, both rulers and the index, so an unstripped read would let a COMMENT
--- satisfy every structural assertion below (the 'fieldsip' lesson).
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

--- The tombstone branch's condition, lifted verbatim from the shipped file.
--- Anchored on the modifier name so it cannot drift onto a neighbour, and the
--- `then` it stops at is the branch's own (the condition contains no `then`).
local function condition_src()
    local src = stripped(read_file(ROAM))
    local at = src:find('modifier_undying_tombstone_zombie_deathstrike_slow', 1, true)
    assert(at ~= nil, 'the tombstone branch is gone from ' .. ROAM)
    local s = src:find('if J.GetHP(bot) < 0.8', at, true)
    assert(s ~= nil, 'the tombstone branch no longer opens on J.GetHP(bot) < 0.8')
    local e = src:find(' then', s, true)
    assert(e ~= nil, 'unterminated `if` in the tombstone branch')
    local cond = src:sub(s + 3, e - 1)
    assert(cond:find('then', 1, true) == nil, 'the lift swallowed a nested `then`')
    return cond
end

local COND = condition_src()

-- ------------------------------------------------------------- the sweep ---

--- One pass over the corpus. Sections 1, 2 and 4 read the two rulers on the real
--- frame; section 3 drives the lifted condition on the subset that satisfies the
--- branch's real-geometry preconditions.
local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local seen_msg = nil

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
                    if h:HasModifier('modifier_undying_tombstone_zombie_deathstrike_slow') then
                        bump('tomb_mod')
                    end

                    -- The shipped file's own read, byte for byte.
                    local eList = h:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
                    if type(eList) == 'table' and #eList > 0 then
                        bump('e1')
                        if J.IsValidHero(eList[1]) then bump('e1_valid') end

                        -- 1. the ruler that measures the wrong thing
                        local okList, errList = pcall(J.GetHP, eList)
                        if okList then
                            bump('list_answered')
                        else
                            bump('list_raised')
                            if tostring(errList):find('GetHealth', 1, true) then
                                bump('list_raised_gethealth')
                            end
                            seen_msg = seen_msg or tostring(errList)
                        end

                        -- 2. the ruler that measures the right thing
                        local okElem, vElem = pcall(J.GetHP, eList[1])
                        if okElem and type(vElem) == 'number' then
                            bump('elem_number')
                            if vElem > 0 and vElem <= 1 then bump('elem_fraction') end
                            if vElem > 0.35 then bump('elem_gt035') end
                        else
                            bump('elem_raised')
                        end

                        -- 3. the branch itself, on the rows whose real geometry
                        --    satisfies its non-injected preconditions.
                        if J.GetHP(h) < 0.8
                            and J.IsValid(eList[1])
                            and GetUnitToUnitDistance(eList[1], h) < 1200 then
                            bump('drives')
                            if J.IsModeTurbo() then bump('drive_turbo') end

                            local armed = false
                            local realSoak = J.IsSoakCandidate
                            J.IsSoakCandidate = function(sId)
                                if sId ~= CAND then return realSoak(sId) end
                                return armed
                            end
                            local env = setmetatable({
                                J = J, bot = h, enemy = eList[1], nInRangeEnemy = eList,
                                cachedTombstoneZombieSlowState = -1000,
                            }, { __index = _G })

                            local fn = assert(loadstring('return ' .. COND, 'tombhp_cond'))
                            setfenv(fn, env)

                            local okOff, rOff = pcall(fn)
                            if okOff then bump('off_no_error') end
                            if okOff and rOff == false then bump('off_false') end

                            armed = true
                            local okOn, rOn = pcall(fn)
                            if okOn then bump('on_no_error') end
                            if okOn and rOn == (J.GetHP(eList[1]) > 0.35) then
                                bump('on_matches_intent')
                            end
                            if okOn and rOn == true then bump('on_true') end

                            -- 3d. the shipped bytes, restored, through the same
                            --     apparatus: the defect must come back. The
                            --     no-op case is COUNTED, not asserted: an assert
                            --     here kills the whole file at load time and
                            --     every message below it with it (found on the
                            --     mutation stand, M4/M5).
                            local mut = COND:gsub('J%.GetHP%(nInRangeEnemy%[%d+%]%)',
                                'J.GetHP(nInRangeEnemy)')
                            if mut == COND then bump('mut_noop') end
                            local gn = assert(loadstring('return ' .. mut, 'tombhp_mut'))
                            setfenv(gn, env)
                            local okMut, rMut = pcall(gn)
                            if not okMut and tostring(rMut):find('GetHealth', 1, true) then
                                bump('mut_raised')
                            end

                            J.IsSoakCandidate = realSoak
                        end
                    end
                end
            end
        end
    end
    c.msg = seen_msg
    return c
end)()

local function C(k) return SWEEP[k] end

-- The counters are all SUMS OVER FRAMES, so appending a fixture can only raise
-- them: cs.ratchet still catches the FALL that would mean behaviour moved, and
-- stops charging this file for corpus growth (GH #106/#127). The zero claims
-- stay equalities on purpose -- zero is already growth-immune, and the bound
-- sentences in the header are argued from them.
tests['[tombhp] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' frames failed to load')
    cs.corpus(C('frames_loaded'), 'tombhp sweep')
    cs.ratchet(C('live'), 1270, 'live hero frames')
end

-- ------------------------------- 1. the shipped ruler does not answer false --

tests['[tombhp] 1. MEASURED: J.GetHP(list) RAISES on every frame that reaches it']
= function()
    cs.ratchet(C('e1'), 573, 'frames with a non-empty enemy-hero list in 1200')
    cs.universal(C('e1_valid'), C('e1'),
        'J.IsValidHero accepts the first element of every non-empty list', 100)

    -- The whole finding: not "sometimes wrong", not "returns a bad number".
    assert(C('list_answered') == 0,
        C('list_answered') .. ' frames got an ANSWER out of J.GetHP(list); the '
        .. 'defect is that it raises, so an answer means the ruler or the list '
        .. 'shape moved and this reading must be retaken')
    cs.universal(C('list_raised'), C('e1'), 'J.GetHP(list) raises', 100)
    cs.universal(C('list_raised_gethealth'), C('e1'),
        'the raise is the GetHealth index, not some other error', 100)
    assert(tostring(C('msg')):find('jmz_func.lua', 1, true) ~= nil,
        'expected the raise to come from jmz_func, got: ' .. tostring(C('msg')))
end

-- ------------------------------------ 2. the repaired ruler has real rows ---

tests['[tombhp] 2. MEASURED: J.GetHP(list[1]) answers a real fraction, and the '
    .. 'conjunct is not a tautology'] = function()
    cs.universal(C('elem_number'), C('e1'), 'the element read answers a number', 100)
    cs.universal(C('elem_fraction'), C('e1'),
        'and it is a fraction in (0,1], i.e. a real health read', 100)
    assert(C('elem_raised') == 0, C('elem_raised') .. ' element reads raised')

    -- 487/573 on the corpus this was registered on. Both directions matter: a
    -- conjunct that is true everywhere would not be a lever, and one that is
    -- true nowhere would not be reachable.
    cs.ratchet(C('elem_gt035'), 487, 'frames where the nearest enemy is above 35% hp')
    assert(C('elem_gt035') < C('e1'),
        'the > 0.35 conjunct is true on ALL ' .. C('e1') .. ' frames -- it has '
        .. 'stopped discriminating, so re-read what it is for')
end

-- -------------------------- 3. the branch, driven on its own shipped bytes ---

tests['[tombhp] 3a. the drive ran on real geometry, all of it Turbo'] = function()
    cs.ratchet(C('drives'), 299, 'frames satisfying the branch preconditions')
    cs.universal(C('drive_turbo'), C('drives'), 'the drive corpus is all Turbo', 100)
end

tests['[tombhp] 3b. UNARMED: no error and no fire -- the gate short-circuits '
    .. 'before J.GetHP is ever called'] = function()
    cs.universal(C('off_no_error'), C('drives'),
        'the unarmed leg completes without raising', 100)
    cs.universal(C('off_false'), C('drives'), 'and it answers false', 100)
end

tests['[tombhp] 3c. ARMED: the branch evaluates the intended term'] = function()
    cs.universal(C('on_no_error'), C('drives'),
        'the armed leg completes without raising', 100)
    cs.universal(C('on_matches_intent'), C('drives'),
        'the armed result is exactly "the nearest enemy is above 35% hp"', 100)
    -- 261/299 registered. Anti-vacuum: an armed leg that never answers true
    -- would make 3c pass while measuring nothing.
    cs.ratchet(C('on_true'), 261, 'armed frames where the branch fires')
end

tests['[tombhp] 3d. the SHIPPED text, restored into the same apparatus, brings '
    .. 'the raise back'] = function()
    assert(C('mut_noop') == 0,
        'the 3d mutation was a NO-OP on ' .. C('mut_noop') .. ' frames: the lifted '
        .. 'condition no longer contains an indexed J.GetHP(nInRangeEnemy[N]) to '
        .. 'un-index, which means the shipped text already hands the list over')
    cs.universal(C('mut_raised'), C('drives'),
        'putting J.GetHP(nInRangeEnemy) back raises GetHealth on every driven frame', 100)
end

-- ------------------------------------------- 4. the bound, measured not cited --

tests['[tombhp] 4. BOUND: the outer guard has no rows in this corpus'] = function()
    -- Stated as an equality on purpose: it is the reason no fire-rate claim is
    -- made anywhere above, and the reason this id is FROZEN-HOLD. If a frame
    -- carrying the modifier ever lands, this goes red and the question -- "can
    -- the branch now be seen end to end?" -- comes back with it. That red IS the
    -- baton (GH #13 lost one by living in an issue that got closed).
    assert(C('tomb_mod') == 0,
        C('tomb_mod') .. ' frame(s) now carry '
        .. 'modifier_undying_tombstone_zombie_deathstrike_slow. The bound in this '
        .. "file's header no longer holds: re-take the branch's reachability end "
        .. 'to end on those frames, and re-price tombhp for admission.')
end

-- --------------------------------------------- 5. the call site, structurally --

tests['[tombhp] 5. the shipped call site reads the element, and the gate is '
    .. 'turbo-only and ordered before it'] = function()
    local src = stripped(read_file(ROAM))

    assert(src:find('J.GetHP(nInRangeEnemy)', 1, true) == nil,
        ROAM .. ' still hands the whole list to J.GetHP somewhere')
    assert(COND:find('J.GetHP(nInRangeEnemy[1])', 1, true) ~= nil,
        'the tombstone branch no longer reads the first element')

    local atGate = COND:find("J.IsSoakCandidate('" .. CAND .. "')", 1, true)
    local atTurbo = COND:find('J.IsModeTurbo()', 1, true)
    local atHp = COND:find('J.GetHP(nInRangeEnemy[1])', 1, true)
    assert(atGate ~= nil, 'the ' .. CAND .. ' gate is gone from the branch')
    assert(atTurbo ~= nil and atTurbo < atGate,
        'the gate is not turbo-only, or turbo is not read first')
    -- Source order IS evaluation order for `and`, and that ordering is the whole
    -- mechanism behind 3b: move the gate after the J.GetHP term and the unarmed
    -- leg starts raising again.
    assert(atGate < atHp,
        'the gate no longer sits BEFORE the J.GetHP term -- the unarmed leg will '
        .. 'call it and raise again')

    -- The gate must not be nested inside another id's gate: an id that is only
    -- reachable while a second id is armed is frozen FALSE the day that second
    -- id is promoted (the 'pullcad' lesson, AGENTS.md).
    local _, nGates = COND:gsub('J%.IsSoakCandidate%(', '')
    assert(nGates == 1, 'the branch reads ' .. nGates .. ' soak gates, expected 1')
end

return tests

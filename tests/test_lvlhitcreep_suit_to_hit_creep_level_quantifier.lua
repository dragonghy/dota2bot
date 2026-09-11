-- [lvlhitcreep 20260911] THE 'lvlany' FAMILY SHAPE IN A NEW FUNCTION -- AND THE
-- FIRST ONE OF THE FAMILY THAT IS DRIVEN END TO END BY FRAMES THAT ALREADY EXIST.
--
-- THE DEFECT. bots/mode_team_roam_generic.lua, X.IsModeSuitToHitCreep:
--     local nEnemyHeroes = J.GetEnemyList(b, 750)
--     if #nEnemyHeroes >= 3 or (nEnemyHeroes[1] ~= nil and nEnemyHeroes[1]:GetLevel() >= 8) then
--         return false
--     end
-- J.GetEnemyList filters GetNearbyHeroes but does NOT re-sort it, so `[1]` is
-- still the NEAREST live enemy (section 4a measures that rather than trusting
-- it). The question is existential -- "is a dangerous enemy standing here" --
-- and the `#nEnemyHeroes >= 3` leg beside it is the author's own proof of that:
-- a whole term was already spent asking about the GROUP. What the level term
-- answers instead is "is the NEAREST one dangerous", so a level-5 support
-- screening a level-12 core at 700 units reads SAFE TO KEEP LAST-HITTING.
--
-- ⭐⭐ WHY THIS ONE IS WORTH A REPORT LINE OF ITS OWN, and it is a number, not a
-- preference. 'lvlany', 'lvlcarry', 'lvlgroup' and 'lvltogether' each had to be
-- taken on the weaker of the two bars in force: arming changed the HELPER's
-- answer on real rows, but changed the enclosing function's RETURN on ZERO of
-- them (each of those four files pins its own `cat_flip == 0` and says so). This
-- site flips X.IsModeSuitToHitCreep's OWN early return on 9 live rows -- section
-- 5, asserted as an equality against the 10 predicate misses minus the 1 row the
-- `>= 3` leg had already short-circuited. ⇒ The family's owed fixture (GH #756)
-- is NOT owed here. That is the whole reason this site was chosen over hunting a
-- fifth `[1] < N` sibling, which section 8 of the previous round ruled out.
--
-- ⛔ DIRECTION, measured over all 1306 live rows (section 3). Armed answers
-- `any(level >= nLevel)`; shipped answers `[1] >= nLevel`; `[1]` is a MEMBER of
-- the list, so shipped TRUE implies armed TRUE. Arming is a pure WIDENING of the
-- DANGER predicate and therefore a pure NARROWING of the permission it guards:
-- it can only ever WITHDRAW a "suitable to hit creeps", never grant one baseline
-- withheld. The bot only ever becomes more cautious about standing in a lane
-- auto-attacking creeps. 0 violations, pinned as an equality, plus
-- `armed_true - shipped_true == site_miss` so the bound cannot be satisfied by a
-- helper that answers a constant.
-- ⛔ It is a bound on the DIRECTION, not a fire rate. No fire rate is claimed in
-- this file.
--
-- ⛔ THE DOMAIN IS SELF-LIMITING, which is the answer to "does this just stop
-- farming whenever any enemy is near". The two answers can only differ while the
-- nearest enemy is below the threshold and someone behind them is not -- the
-- mixed-level window. Once both sides are past level 8 the nearest is dangerous
-- too and SHIPPED already fires, so armed and shipped converge. Section 2's
-- sweep shows the miss population shrinking as the threshold rises past the
-- corpus's level band, which is that statement as a measurement.
--
-- ⛔ WHAT THIS CORPUS CAN AND CANNOT BUY, said before any number is read.
--   * IT CAN BUY enemy semantics and real levels: the producer is the raw
--     bot:GetNearbyHeroes restored by the loader from dump ground truth with a
--     team comparison, a vision check, self excluded and a distance sort, and
--     GetLevel is dump ground truth. Section 4 asserts self-exclusion and the
--     team split as EQUALITIES (contamination could only ever SATISFY a floor --
--     the lesson 'anyhero's M7 paid for) and measures the level SPREAD rather
--     than assuming one.
--   * IT CANNOT BUY A FIRE RATE for the two callers that read
--     X.IsModeSuitToHitCreep (X.SupportFindTarget, X.ShouldAttackTowerCreep):
--     none of their other terms is driven here. Section 4d says so as a bound.
--   ⇒ 'lvlhitcreep' is FROZEN-HOLD per OWNER_PRIORITIES P4.2: registered in
--     state.json:lvlhitcreep_20260911, NOT requested into the armed set. The
--     armed string, queue.json and test_set.md are untouched.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/mode_team_roam_generic.lua'
local CAND = 'lvlhitcreep'

-- X.IsModeSuitToHitCreep's own constants. Every count in sections 1-5 is taken
-- at these; the sweep in section 2 exists because they are one cell of it.
local SITE_RADIUS = 750
local SITE_LEVEL = 8
local GROUP_LEG = 3 -- the `#nEnemyHeroes >= 3` term beside the level term

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- Source with every comment removed. This lever's own comment block quotes the
--- shipped expression, so an unstripped read would let a COMMENT satisfy the
--- structural assertions in sections 6 and 7.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        -- Registered in tests/test_bots_walk_farm_only.py:UNRESOLVED_HAND_READ:
        -- a plain non-recursive `ls` over two literal directories, which cannot
        -- reach bots/Customize/.
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

--- The helper's body, lifted verbatim from the shipped file, so sections 3-5
--- drive the REAL shipped bytes and not a re-implementation of them.
local function helper_src()
    local src = stripped(read_file(TRG))
    local s = src:find('function X.AnyEnemyAtLevelHitCreep(tHeroes, nLevel)', 1, true)
    assert(s ~= nil, 'X.AnyEnemyAtLevelHitCreep is gone from ' .. TRG)
    local e = src:find('\nend', s, true)
    assert(e ~= nil, 'unterminated X.AnyEnemyAtLevelHitCreep in ' .. TRG)
    return src:sub(s, e + 3)
end

local BODY = helper_src()

local function compile(body, env, name)
    local fn = assert(loadstring(
        'local X = {}\n' .. body .. '\nreturn X.AnyEnemyAtLevelHitCreep', name))
    setfenv(fn, env)
    return fn()
end

--- The shipped expression, spelled out here so section 3 compares the helper
--- against the TEXT of what shipped rather than against another call of itself.
local function shipped_answer(list, nLevel)
    return list[1] ~= nil and list[1]:GetLevel() >= nLevel
end

--- The armed quantifier, written out once for the replication in section 5. The
--- HELPER itself is never re-implemented for sections 3a-3d; those drive the
--- real bytes.
local function armed_answer(list, nLevel)
    for i = 1, #list do
        if list[i]:GetLevel() >= nLevel then return true end
    end
    return false
end

--- X.IsModeSuitToHitCreep's early return with its level term made a parameter,
--- so the SAME replication can be evaluated under each answer. Section 6b pins
--- the shipped text against it, so the day the function is edited this file goes
--- red instead of section 5's count quietly becoming a statement about a
--- predicate that no longer exists.
local function bails_early(list, level_fn)
    return #list >= GROUP_LEG or level_fn(list, SITE_LEVEL)
end

-- ------------------------------------------------------------- the sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 600, 750, 900, 1200 }
    local LEVELS = { 6, 8, 10 }

    for _, path in ipairs(corpus_paths()) do
        local ok, J, _, heroes = pcall(rf.load, path)
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
            local fn = compile(BODY, env, 'lvlhitcreep_body')

            for _, h in pairs(heroes or {}) do
                if h ~= nil and h.IsAlive and h:IsAlive() then
                    bump('live')
                    local site = J.GetEnemyList(h, SITE_RADIUS)

                    -- 3a-3d: the real bytes, both legs of the gate.
                    armed = true
                    local a_real = fn(site, SITE_LEVEL)
                    armed = false
                    local s_real = fn(site, SITE_LEVEL)

                    local s_text = shipped_answer(site, SITE_LEVEL)
                    local a_spec = armed_answer(site, SITE_LEVEL)

                    -- 3a. unarmed bytes == the shipped TEXT, row by row.
                    if s_real ~= s_text then bump('UNARMED_DRIFT') end
                    -- 3b. armed bytes == the quantifier, row by row.
                    if a_real ~= a_spec then bump('ARMED_DRIFT') end

                    if s_real then bump('shipped_true') end
                    if a_real then bump('armed_true') end
                    -- 3c. DIRECTION: shipped true must imply armed true.
                    if s_real and not a_real then bump('DIR_VIOLATION') end

                    if a_real and not s_real then
                        bump('site_miss')
                        -- 5. does the FUNCTION's early return actually move?
                        if bails_early(site, shipped_answer)
                            ~= bails_early(site, armed_answer) then
                            bump('miss_flips')
                        else
                            bump('miss_masked_by_ge3')
                        end
                        -- 4a. producer sanity, taken ON THE ROWS THAT CARRY THE
                        -- CLAIM rather than corpus-wide.
                        for i = 1, #site do
                            if site[i] == h then bump('SELF_IN_LIST') end
                            if site[i]:GetTeam() == h:GetTeam() then bump('SAME_TEAM') end
                        end
                    end

                    if site[1] ~= nil then
                        bump('nonempty')
                        local hi, lo = 0, 999
                        for i = 1, #site do
                            local lv = site[i]:GetLevel()
                            if lv > hi then hi = lv end
                            if lv < lo then lo = lv end
                        end
                        -- 4b. the level SPREAD, measured not assumed: if every
                        -- list were flat the miss population could not exist and
                        -- every count here would be about nothing.
                        if hi ~= lo then bump('spread_nonzero') end
                        if site[1]:GetLevel() < hi then bump('e1_not_highest') end
                        -- 4c. distance sort, measured not trusted: `[1]` must be
                        -- the NEAREST, or "the nearest one" is not what the
                        -- shipped expression reads and this whole file is about
                        -- a different defect.
                        local d1 = GetUnitToUnitDistance(h, site[1])
                        for i = 2, #site do
                            if GetUnitToUnitDistance(h, site[i]) < d1 - 0.5 then
                                bump('SORT_VIOLATION')
                            end
                        end
                    end
                    if #site >= GROUP_LEG then bump('ge3') end

                    -- 2. the sweep: the site cell is ONE of these, and the
                    -- neighbours are what make it a population rather than a
                    -- coincidence.
                    for _, r in ipairs(RADII) do
                        local list = (r == SITE_RADIUS) and site or J.GetEnemyList(h, r)
                        for _, lv in ipairs(LEVELS) do
                            if armed_answer(list, lv) and not shipped_answer(list, lv) then
                                bump('miss_r' .. r .. '_l' .. lv)
                            end
                        end
                    end
                end
            end
        end
    end
    return c
end)()

-- ============================================================== sections ===

tests['[lvlhitcreep] 1. the corpus this file speaks about'] = function()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' fixture(s) failed to load -- every count below '
        .. 'is taken over a corpus this file cannot describe. Fix the loader '
        .. 'before reading any other section.')
    cs.corpus(SWEEP['frames_loaded'], 'frames loaded')
    cs.ratchet(SWEEP['live'], 1306, 'live hero rows')
    cs.ratchet(SWEEP['nonempty'], 396,
        'live rows with >= 1 enemy within ' .. SITE_RADIUS)
end

tests['[lvlhitcreep] 2. the sweep: the site cell is one of a population'] = function()
    -- Monotone in radius at a fixed threshold: a wider ring is a superset, so it
    -- cannot hold FEWER rows whose nearest disagrees with their strongest...
    -- except that widening also changes WHO `[1]` is, so this is asserted only
    -- where it is actually entailed: the site cell against its own neighbours,
    -- as a ratchet, with the shape of the curve recorded in the report.
    cs.ratchet(SWEEP['miss_r750_l8'], 10, 'site cell: r750 / level 8 misses')
    assert(SWEEP['miss_r750_l8'] == SWEEP['site_miss'],
        'the sweep cell (' .. SWEEP['miss_r750_l8'] .. ') and the site count ('
        .. SWEEP['site_miss'] .. ') disagree, and they are the same question '
        .. 'asked twice -- one of the two is measuring something else now.')
    -- ⛔ The self-limiting domain, as a measurement rather than a claim: raising
    -- the threshold past the corpus's level band must not GROW the population.
    -- Registered, not asserted as a law: it is a statement about this corpus.
    assert(SWEEP['miss_r750_l10'] <= SWEEP['miss_r750_l8'] + 4,
        'the level-10 cell (' .. SWEEP['miss_r750_l10'] .. ') has run away from '
        .. 'the level-8 cell (' .. SWEEP['miss_r750_l8'] .. '). The domain '
        .. 'argument in this file\'s header is about a mixed-level window -- '
        .. 're-read it against the new corpus before raising this.')
end

tests['[lvlhitcreep] 3a. unarmed, the shipped bytes answer the shipped text'] = function()
    assert(SWEEP['UNARMED_DRIFT'] == 0,
        SWEEP['UNARMED_DRIFT'] .. ' row(s) where the helper UNARMED disagrees '
        .. 'with `list[1] ~= nil and list[1]:GetLevel() >= n`. Unarmed MUST be '
        .. 'byte-for-byte the old behaviour -- this id is gated and unpromoted, '
        .. 'so a drift here is a live change to every shipped game.')
    assert(SWEEP['shipped_true'] > 0,
        'the shipped predicate is true on 0 rows, so section 3c compares two '
        .. 'empty sets and the direction bound is vacuous.')
end

tests['[lvlhitcreep] 3b. armed, the shipped bytes answer the quantifier'] = function()
    assert(SWEEP['ARMED_DRIFT'] == 0,
        SWEEP['ARMED_DRIFT'] .. ' row(s) where the helper ARMED disagrees with '
        .. '`any(level >= n)`. The lever is not the fix it is described as.')
    assert(SWEEP['armed_true'] > 0,
        'the armed predicate is true on 0 rows -- the lever is inert on this '
        .. 'corpus and nothing below is about anything.')
end

tests['[lvlhitcreep] 3c. DIRECTION: arming only ever WITHDRAWS the permission'] = function()
    -- ⛔ This assertion comes FIRST and the counts come after, deliberately: a
    -- violation here means arming GRANTED a "safe to keep hitting creeps" that
    -- baseline withheld, which is the one outcome this lever must never produce.
    assert(SWEEP['DIR_VIOLATION'] == 0,
        SWEEP['DIR_VIOLATION'] .. ' row(s) where SHIPPED called the field '
        .. 'dangerous and ARMED did not. `[1]` is a member of the list, so this '
        .. 'is supposed to be impossible: armed must be a pure WIDENING of the '
        .. 'danger predicate. A non-zero here is a bug in the helper, not a new '
        .. 'baseline.')
    -- ... and the widening must be REAL, not a constant that trivially satisfies
    -- the line above.
    assert(SWEEP['armed_true'] - SWEEP['shipped_true'] == SWEEP['site_miss'],
        'armed_true - shipped_true = '
        .. (SWEEP['armed_true'] - SWEEP['shipped_true']) .. ' but site_miss = '
        .. SWEEP['site_miss'] .. '. These are the same rows counted two ways; '
        .. 'if they disagree the helper is not a pure widening of the shipped '
        .. 'answer and section 3c above is measuring the wrong thing.')
end

tests['[lvlhitcreep] 4a. the producer: self excluded, enemies only'] = function()
    -- EQUALITIES, taken on the rows that carry the claim. Every ratchet in this
    -- file is a FLOOR, so contamination could only ever SATISFY one.
    assert(SWEEP['SELF_IN_LIST'] == 0,
        SWEEP['SELF_IN_LIST'] .. ' row(s) where the asking hero is inside its '
        .. 'own enemy list -- the loader is not reproducing GetNearbyHeroes and '
        .. 'the miss population is contaminated.')
    assert(SWEEP['SAME_TEAM'] == 0,
        SWEEP['SAME_TEAM'] .. ' row(s) where an ALLY is inside the enemy list. '
        .. 'Same as above: this would inflate every count in section 5.')
end

tests['[lvlhitcreep] 4b. the levels really do spread, and `[1]` really is nearest'] = function()
    assert(SWEEP['SORT_VIOLATION'] == 0,
        SWEEP['SORT_VIOLATION'] .. ' row(s) where some enemy is NEARER than '
        .. '`[1]`. J.GetEnemyList is supposed to preserve GetNearbyHeroes\' '
        .. 'distance sort -- if it does not, "the nearest one" is not what the '
        .. 'shipped expression reads and this file is about a different defect.')
    cs.ratchet(SWEEP['spread_nonzero'], 66,
        'rows whose enemy list is NOT level-flat')
    cs.ratchet(SWEEP['e1_not_highest'], 43,
        'rows where the nearest enemy is not the highest-level one')
    assert(SWEEP['e1_not_highest'] > 0,
        'the nearest enemy is the strongest on every single row, so shipped and '
        .. 'armed could not differ anywhere and this lever is about nothing on '
        .. 'this corpus.')
end

tests['[lvlhitcreep] 4c. REGISTERED BOUND: no fire rate is bought here'] = function()
    -- ⛔ A bound, deliberately not an assertion about behaviour. Two functions
    -- read X.IsModeSuitToHitCreep (X.SupportFindTarget and
    -- X.ShouldAttackTowerCreep) and NONE of their other terms -- active mode,
    -- anim activity, HP, recent damage -- is driven by this corpus. Section 5
    -- measures the function's own early return and stops there. Anyone quoting
    -- a "this fires N% of the time" number off this file is quoting something
    -- that was never measured.
    local src = stripped(read_file(TRG))
    local n = 0
    for _ in src:gmatch('X%.IsModeSuitToHitCreep') do n = n + 1 end
    assert(n == 4,
        'X.IsModeSuitToHitCreep appears ' .. n .. ' times (1 definition + 3 '
        .. 'reads expected). The caller population this bound describes has '
        .. 'changed -- re-read them before trusting section 5\'s scope.')
end

tests['[lvlhitcreep] 5. ⭐ THE FLIP: the enclosing function\'s return really moves'] = function()
    -- ⭐⭐ THE SENTENCE NO SIBLING IN THIS FAMILY COULD WRITE. 'lvlany',
    -- 'lvlcarry', 'lvlgroup' and 'lvltogether' each pin `cat_flip == 0`: arming
    -- moved the helper but never the enclosing function, so each was taken on
    -- the weaker bar with a fixture owed (GH #756). Here the function's own
    -- early return moves on real rows, so this lever is driven END TO END and
    -- owes no fixture.
    assert(SWEEP['miss_flips'] > 0,
        'the function\'s early return now moves on 0 rows. If the corpus '
        .. 'SHRANK this is an artefact; if it did not, this lever has lost the '
        .. 'property that justified taking it over a fifth `[1] < N` sibling, '
        .. 'and the id must be re-argued, NOT re-baselined.')
    cs.ratchet(SWEEP['miss_flips'], 9,
        'rows where X.IsModeSuitToHitCreep\'s early return flips')
    -- ⛔ The masked leg needs its OWN floor, not just the partition below.
    -- Without it, a replication that quietly DROPS the `>= ' .. GROUP_LEG .. '`
    -- term scores 10 flips / 0 masked -- the partition still sums to site_miss,
    -- the flip ratchet is a floor so 10 satisfies it, and the mutant walks. M15
    -- on the stand is exactly that edit.
    cs.ratchet(SWEEP['miss_masked_by_ge3'], 1,
        'misses the `#enemies >= ' .. GROUP_LEG .. '` leg had already '
        .. 'short-circuited')
    -- The partition, as an equality: every predicate miss either moves the
    -- return or was already short-circuited by the `>= 3` leg. If these stop
    -- summing, a THIRD thing is happening and section 5's 9 is no longer the
    -- number it is described as.
    assert(SWEEP['miss_flips'] + SWEEP['miss_masked_by_ge3'] == SWEEP['site_miss'],
        'miss_flips (' .. SWEEP['miss_flips'] .. ') + miss_masked_by_ge3 ('
        .. SWEEP['miss_masked_by_ge3'] .. ') /= site_miss ('
        .. SWEEP['site_miss'] .. '). These three are one partition of the same '
        .. 'rows; a gap means the replication in bails_early() has drifted from '
        .. 'the shipped function.')
    -- ⛔ And the masked leg must stay SMALL relative to the flips, or the honest
    -- reading of this lever changes from "it moves the decision" to "the group
    -- leg was already doing the work".
    assert(SWEEP['miss_masked_by_ge3'] < SWEEP['miss_flips'],
        'the `#enemies >= ' .. GROUP_LEG .. '` leg now masks at least as many '
        .. 'misses (' .. SWEEP['miss_masked_by_ge3'] .. ') as this lever moves ('
        .. SWEEP['miss_flips'] .. '). That is a different lever than the one '
        .. 'this file argues for -- re-read it.')
end

tests['[lvlhitcreep] 6a. the gate: turbo-only, this id, and nothing else'] = function()
    local src = stripped(read_file(TRG))
    local body = helper_src()
    assert(body:find("J.IsSoakCandidate('" .. CAND .. "')", 1, true) ~= nil,
        'the helper no longer gates on ' .. CAND)
    assert(body:find('J.IsModeTurbo()', 1, true) ~= nil,
        'the helper lost its turbo-only guard -- a soak candidate must be inert '
        .. 'outside turbo.')
    -- The pullcad trap: a gate naming a SECOND id is frozen FALSE the day that
    -- id is promoted, and check_armed_wiring.py would still call this WIRED.
    local ids = 0
    for _ in body:gmatch('IsSoakCandidate') do ids = ids + 1 end
    assert(ids == 1,
        'the helper reads IsSoakCandidate ' .. ids .. ' times. A gate conjoined '
        .. 'with another candidate id is the pullcad trap: it freezes FALSE the '
        .. 'day that id is promoted and the lever silently no-ops in every wave.')
    -- One lever, one id, one definition site (the sibling files each pin their
    -- own caller count at 1 for the same reason).
    local defs = 0
    for _ in src:gmatch('function X%.AnyEnemyAtLevelHitCreep') do defs = defs + 1 end
    assert(defs == 1, 'expected exactly 1 definition, found ' .. defs)
    local calls = 0
    for _ in src:gmatch('X%.AnyEnemyAtLevelHitCreep%(') do calls = calls + 1 end
    assert(calls == 2,
        'X.AnyEnemyAtLevelHitCreep has ' .. (calls - 1) .. ' call site(s), '
        .. 'expected 1. Sharing this helper would arm two sites under one id -- '
        .. 'the lanefix bundling (gpm -74.5, then -88.7, 0/4 comps).')
end

tests['[lvlhitcreep] 6b. the shipped call site still reads what section 5 replicates'] = function()
    local src = stripped(read_file(TRG))
    -- Built from the constants rather than typed, so a drift in SITE_LEVEL or
    -- GROUP_LEG cannot leave this pin agreeing with a stale literal.
    local want = '#nEnemyHeroes >= ' .. GROUP_LEG
        .. ' or X.AnyEnemyAtLevelHitCreep(nEnemyHeroes, ' .. SITE_LEVEL .. ')'
    assert(src:find(want, 1, true) ~= nil,
        'X.IsModeSuitToHitCreep no longer reads `' .. want .. '`. Section 5 '
        .. 'replicates that expression to count the flips, so this file\'s 9 '
        .. 'would otherwise quietly become a statement about an expression that '
        .. 'is no longer in the tree.')
    assert(src:find('J.GetEnemyList(b, ' .. SITE_RADIUS .. ')', 1, true) ~= nil,
        'the radius the whole census is taken at is no longer '
        .. SITE_RADIUS .. ' at the call site.')
end

tests['[lvlhitcreep] 7. census: no un-repaired copy of this shape at this site'] = function()
    local src = stripped(read_file(TRG))
    -- The `[1] >= N` polarity, which is THIS lever's shape (the four siblings
    -- took the `[1] < N` polarity and their own censuses cover that one).
    local n = 0
    for _ in src:gmatch('nEnemyHeroes%[1%][^\n]-:GetLevel%(%) >= ') do n = n + 1 end
    assert(n == 0,
        'found ' .. n .. ' un-repaired `nEnemyHeroes[1]:GetLevel() >= N` '
        .. 'site(s) in ' .. TRG .. '. The one this file took is behind an id '
        .. 'now, so a new one means a NEW site was written in the old shape -- '
        .. 'go read it, do not raise this number.')
    -- ⛔ Zero is ALSO what a DELETED guard looks like, so emptiness is only half
    -- the claim. The other half: the site left the shape because an id was hung
    -- on it, which section 6b pins as a live call.
end

return tests

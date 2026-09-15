-- [ratchet] [hero] Wraith King's Reincarnation reserve tells the hero to wait
-- for a mana total his pool CANNOT HOLD -- and "wait" with no reachable exit is
-- a permanent refusal, not a delay.  New soak candidate `wksavecap`.
--
-- GH #407.  X.ShouldSaveMana refuses a cast while
--
--     GetMana() - ability:GetManaCost() < R:GetManaCost()
--
-- i.e. it asks the hero to accumulate `cost + reserve`.  Nothing in the rule
-- compares that target against GetMaxMana().  On f_232320_wk_od_burst the
-- target is 95 + 220 = 315 and the pool tops out at 272, so Wraithfire Blast is
-- refused at a FULL POOL and at every mana below it.  The issue's own archive
-- scan (W34, 78 games with a Wraith King,
-- iterations/reports/batch-desk/hero27_savemana_archive_scan.md) then showed
-- the lock is a CANCELLATION rather than a delay -- only 11.04% of lock events
-- are followed by a Q within 2s of release -- which is what moved this from
-- "priced" to "may touch bots/".
--
-- THE LEVER, in one line: the reserve becomes
-- `min( R:GetManaCost(), GetMaxMana() - cost )`.  Where the pool can hold both
-- prices that is the shipped number unchanged; where it cannot, the threshold
-- collapses to "cast at a full pool only".
--
-- ⭐ WHAT THIS FILE IS FOR, and it is not the gate plumbing.  Section 2 drives
-- the whole priced corpus and separates two counts that look like one number:
-- the CONSTRUCTIVE set (pool below the target) is 5 frames, and the DECISION
-- domain (an answer that actually moves) is 1.  The 4 that separate them are
-- below hero level 6, where the shipped rule never fires.  A round that quoted
-- "5" as this lever's domain would be quoting a set it cannot touch.
--
-- ⚠️ WHAT IS NOT CLAIMED, said before any number below is quoted:
--   * No in-game frequency.  A fixture corpus is a set of instants chosen for
--     other investigations; 1/33 is a domain, not a rate.  The W34 scan's
--     constructive cell (1.74% of firing events) came entirely from ONE seed of
--     three and its own report says so -- do not quote it as a cross-seed rate.
--   * No claim that a released reserve is a cast.  Section 5 pins the opposite:
--     the shipped X.ConsiderQ still answers 0 on the released frame, and the
--     control that tells "the body ran and declined" apart from "the body never
--     ran" is measured rather than assumed.
--   * Nothing about the rank blindness in the same function (`nLV >= 6` standing
--     in for "R is learned").  That is GH #407's other open cell, registered by
--     tests/test_wk_save_mana_lock_census.lua section 6.  One lever at a time.
--
-- SECTIONS
--   1  the gate is wired, turbo-only, and names exactly one id
--   2  the corpus: 5 constructive frames, 1 decision, and the 4 that differ
--   3  the arithmetic, driven over a grid rather than on one triple
--   4  direction is guaranteed by shape: the reserve never grows
--   5  a released reserve is not a cast -- with the control that proves the body ran
--   6  `wksavecap` and `wksaveidle` release DISJOINT frames

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_skeleton_king.lua'
local UNIT = 'npc_dota_hero_skeleton_king'
local HELPER = 'GetReincarnationReserve'
local CAND = 'wksavecap'
local SIBLING_CAND = 'wksaveidle'
local Q = 'skeleton_king_hellfire_blast'
local R = 'skeleton_king_reincarnation'
-- Q's cast range from the KV snapshot (tests/mock/special_value_shapes.lua).
-- GetCastRange is on no spec and falls through to the generic `^Get` default of
-- 0 (GH #391), so section 5 feeds it back before reading anything into a silent
-- ConsiderQ.
local Q_CAST_RANGE = 525
local FIXTURE_DIR = 'tests/fixtures'
-- The headline frame of GH #407.  Named as a constant because three sections
-- below assert something different about the same frame.
local HEADLINE = 'f_232320_wk_od_burst.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Comments stripped, so a census counting CODE shapes cannot be satisfied by
--- prose that merely mentions the expression.  The hero file opens with an npc
--- dump inside a block comment whose lines do NOT start with `--`, so the block
--- form is stripped first (the trap tests/test_wk_fact_anchor.lua documents).
local function strip_comments(s)
    return (s:gsub('%-%-%[%[.-%]%]', ''):gsub('%-%-[^\n]*', ''))
end

local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if not s then return n end
        n, at = n + 1, e + 1
    end
end

local SRC_TEXT = read_file(SRC)
local SRC_CODE = strip_comments(SRC_TEXT)

local function short(path) return (path:gsub('^' .. FIXTURE_DIR .. '/', '')) end
local function joined(t) return table.concat(t, ', ') end

local function fixture_files()
    local files = {}
    -- UNRESOLVED_HAND_READ (GH #774 / GH #803): io.popen over a literal
    -- directory, non-recursive `ls`, no interpolated value.  It cannot reach
    -- bots/Customize/.  Same call and same registration as
    -- tests/test_wk_save_mana_lock_census.lua, whose corpus split this file
    -- reuses on purpose.
    local p = assert(io.popen('ls ' .. FIXTURE_DIR))
    for line in p:lines() do
        if line:match('%.lua$') then files[#files + 1] = FIXTURE_DIR .. '/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

--- The PRICED Wraith King frames, split exactly as
--- tests/test_wk_save_mana_lock_census.lua section 1 splits them and for the
--- same two reasons: a fixture with no abilities list hands back blank handles
--- whose rank 0 / cooldown 0 / cost 0 are an ABSENCE indistinguishable from
--- "unlearned, ready, free", and a DEAD row is not a frame on which a mana
--- decision was taken (the GH #794 ruling -- the shipped file assigns nLV only
--- past X.SkillsComplement's `J.CanNotUseAbility( bot )` return, so a corpse
--- raises rather than answering).
local function priced_corpus()
    local priced = {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == UNIT and u.alive ~= false then
                    if type(u.abilities) == 'table' then
                        priced[#priced + 1] = path
                    end
                    break
                end
            end
        end
    end
    return priced
end

--- One frame, loaded through the real loader, with `cand` armed (nil = nothing
--- armed).  Returns the operands plus the two answers the sections need.
local function read_frame(path, cand, nonturbo)
    local J = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return cand ~= nil and id == cand end
    -- ⚠️ BEFORE load_hero, not after.  J.IsModeTurbo memoises into a module
    -- upvalue on its first call, and X.SkillsComplement calls it -- an override
    -- installed afterwards is read by nobody and the section passes vacuously.
    if nonturbo then GetGameMode = function() return 1 end end
    local bot = GetBot()
    local X = rf.load_hero('skeleton_king')
    pcall(function() X.SkillsComplement() end)   -- primes the file-level nLV/nMP/nHP
    local hQ, hR = bot:GetAbilityByName(Q), bot:GetAbilityByName(R)
    return {
        X = X, J = J, bot = bot, hQ = hQ, hR = hR,
        level = bot:GetLevel(),
        mana = bot:GetMana(),
        max_mana = bot:GetMaxMana(),
        q_cost = hQ:GetManaCost(),
        q_castable = hQ:IsFullyCastable(),
        r_cost = hR:GetManaCost(),
        r_cd = hR:GetCooldownTimeRemaining(),
        save = X.ShouldSaveMana(hQ),
        reserve = X.GetReincarnationReserve(hQ),
    }
end

-- ===========================================================================
-- 1  THE GATE IS WIRED, TURBO-ONLY, AND NAMES EXACTLY ONE ID
-- ===========================================================================

tests['1.1 the helper is turbo-gated and names only its own id'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, HELPER))
    assert(body:find('J.IsModeTurbo()', 1, true),
        HELPER .. ' lost its turbo guard -- a soak candidate must be turbo-only')
    assert(count(body, "IsSoakCandidate( '") == 1,
        HELPER .. ' must hold exactly ONE IsSoakCandidate call, it holds '
        .. count(body, "IsSoakCandidate( '"))
    assert(body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        HELPER .. ' no longer names ' .. CAND)
    -- The pullcad trap: a gate that also names ANOTHER id freezes FALSE the day
    -- that id is promoted, and check_armed_wiring.py would still call this
    -- WIRED (it checks that a call site exists, not that the predicate can be
    -- true).  `wksaveidle` is the id a future round is likeliest to reach for
    -- here, because it lives in the same function and guards the same reserve.
    for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == CAND, HELPER .. ' names a second id ' .. id
            .. ' -- the pullcad trap.  The two reserve levers must stay '
            .. 'independently armable')
    end
end

tests['1.2 the call site replaced the shipped term -- it did not grow a second copy'] =
function()
    assert(count(SRC_CODE, 'X.' .. HELPER) == 2,
        'expected exactly two X.' .. HELPER .. ' occurrences in code (the '
        .. 'definition and the single call site in X.ShouldSaveMana), got '
        .. count(SRC_CODE, 'X.' .. HELPER))
    local body = strip_comments(fn_body(SRC_TEXT, 'ShouldSaveMana'))
    assert(body:find('X.' .. HELPER .. '( nAbility )', 1, true),
        'X.ShouldSaveMana no longer calls X.' .. HELPER .. ' -- the lever is '
        .. 'defined but unwired, the shape check_armed_wiring.py exists for')
    -- The shipped comparison must read the HELPER, not R's price directly.  A
    -- revert that leaves the helper in the file but restores the old right-hand
    -- side is the failure this asserts against, and it is invisible to 1.1.
    assert(not body:find('< abilityR:GetManaCost()', 1, true),
        'X.ShouldSaveMana compares against abilityR:GetManaCost() again -- the '
        .. 'call site was reverted and the helper is now dead code')
    -- Reached only past the two non-nil guards, which is WHY the helper may
    -- dereference both handles without repeating the checks.  If that ordering
    -- is ever broken the helper raises instead of answering.
    local guards = body:find('abilityR ~= nil', 1, true)
    local callsite = body:find('X.' .. HELPER, 1, true)
    assert(guards and callsite and guards < callsite,
        'the `abilityR ~= nil` guard no longer precedes the X.' .. HELPER
        .. ' call site.  The helper dereferences abilityR and nAbility on its '
        .. 'first lines precisely because that ordering holds')
end

-- ===========================================================================
-- 2  THE CORPUS.  Two counts that look like one number.
-- ===========================================================================

--- Everything sections 2 and 6 need, driven once over the whole priced corpus.
local function census()
    local c = { n = 0, constructive = {}, constructive_below6 = {},
                fires = {}, released_cap = {}, released_idle = {} }
    for _, path in ipairs(priced_corpus()) do
        c.n = c.n + 1
        local base = read_frame(path, nil)
        local capped = read_frame(path, CAND)
        local idle = read_frame(path, SIBLING_CAND)
        local name = short(path)
        if base.max_mana < base.q_cost + base.r_cost then
            c.constructive[#c.constructive + 1] = name
            if base.level < 6 then
                c.constructive_below6[#c.constructive_below6 + 1] = name
            end
        end
        if base.save then
            c.fires[#c.fires + 1] = name
            if not capped.save then c.released_cap[#c.released_cap + 1] = name end
            if not idle.save then c.released_idle[#c.released_idle + 1] = name end
        end
    end
    for _, t in pairs(c) do if type(t) == 'table' then table.sort(t) end end
    return c
end

tests['2.1 the priced corpus is 33 frames -- the split this file inherits'] =
function()
    local c = census()
    if c.n ~= 33 then
        error('the priced Wraith King corpus is now ' .. c.n .. ' frames, '
            .. 'recorded 33.  Fixtures were added or removed; re-read every '
            .. 'count in this file before quoting one.  The split itself is '
            .. 'defined in tests/test_wk_save_mana_lock_census.lua section 1')
    end
end

tests['2.2 the CONSTRUCTIVE set is 5, and 4 of them are below level 6'] =
function()
    local c = census()
    if #c.constructive ~= 5 then
        error('`max mana < Q cost + R cost` now holds on ' .. #c.constructive
            .. ' priced frames, recorded 5: ' .. joined(c.constructive))
    end
    -- ⭐ The whole point of this section.  4 of the 5 sit below hero level 6,
    -- where the shipped rule's own first conjunct refuses, so this lever cannot
    -- move them however unreachable their target is.  Quoting 5 as the lever's
    -- domain would be quoting a set it does not touch.
    local expect_below = 'f_013254_ck_rescue_trade.lua, '
        .. 'f_013254_lina_rescue_trade.lua, f_072738_zuus_mana.lua, '
        .. 'f_231411_ck_zoned.lua'
    if joined(c.constructive_below6) ~= expect_below then
        error('the constructive frames below level 6 are now {'
            .. joined(c.constructive_below6) .. '}, recorded {' .. expect_below
            .. '}.  These are the frames that separate the constructive count '
            .. 'from the decision domain')
    end
end

tests['2.3 the DECISION domain is exactly 1 frame, and it is the issue headline'] =
function()
    local c = census()
    if #c.fires ~= 6 then
        error('the shipped reserve now fires on ' .. #c.fires
            .. ' of the priced frames, recorded 6: ' .. joined(c.fires))
    end
    if joined(c.released_cap) ~= HEADLINE then
        error('arming ' .. CAND .. ' now releases {' .. joined(c.released_cap)
            .. '}, recorded exactly {' .. HEADLINE .. '}.  If the set GREW, '
            .. 'the cap is reaching frames whose target the pool can hold and '
            .. 'the arithmetic in section 3 is wrong; if it SHRANK to empty, '
            .. 'the lever is inert and every claim in its note is unsupported')
    end
end

tests['2.4 the headline frame reads what GH #407 says it reads'] = function()
    local f = read_frame(FIXTURE_DIR .. '/' .. HEADLINE, nil)
    -- Read off the frame, never retyped from the issue: the issue is prose and
    -- prose cannot fail when a fixture is regenerated.
    local got = string.format('lv=%d mana=%d max=%d q=%d r=%d rcd=%.1f',
        f.level, f.mana, f.max_mana, f.q_cost, f.r_cost, f.r_cd)
    local want = 'lv=6 mana=272 max=272 q=95 r=220 rcd=0.0'
    if got ~= want then
        error(HEADLINE .. ' now reads `' .. got .. '`, recorded `' .. want
            .. '`.  Every arithmetic claim in this file and in the hero file '
            .. "note is anchored to those numbers")
    end
    assert(f.q_castable,
        HEADLINE .. ': Q is no longer fully castable, so `not '
        .. 'abilityQ:IsFullyCastable()` -- which sits BEFORE the reserve in '
        .. 'X.ConsiderQ -- would refuse this frame anyway and the reserve '
        .. 'would no longer be the only thing in the way')
    -- The lock is CONSTRUCTIVE here, not merely tight: the target exceeds the
    -- pool, so the hero is at his own ceiling and still refused.
    assert(f.mana == f.max_mana, HEADLINE .. ' is no longer at a full pool')
    assert(f.q_cost + f.r_cost > f.max_mana,
        HEADLINE .. ': the target ' .. (f.q_cost + f.r_cost)
        .. ' now fits inside the pool ' .. f.max_mana
        .. ' -- this frame is no longer a constructive lock')
    assert(f.save, HEADLINE .. ': the shipped reserve no longer fires here')
end

-- ===========================================================================
-- 3  THE ARITHMETIC, over a grid rather than on one triple.
-- ===========================================================================

--- What the lever is specified to return, written independently of the hero
--- file so a mutation inside the helper cannot move both sides of the check.
local function spec_reserve(max_mana, cost, r_cost)
    local reachable = max_mana - cost
    if reachable < 0 or reachable >= r_cost then return r_cost end
    return reachable
end

local GRID_MAX  = { 0, 95, 200, 272, 315, 316, 500 }
local GRID_COST = { 0, 95, 140, 400 }
local GRID_R    = { 0, 110, 220 }

--- A frame whose three prices are writable.  ⚠️ `rawset`, not a plain field
--- write: tests/mock/bot_api.lua's unit metatable synthesises a method on first
--- `__index` and CACHES it on the table, so assigning to `__spec` after the hero
--- file has already read GetMaxMana once is silently ignored.  The first draft
--- of this file did exactly that and the grid below "passed" the same three
--- frame values 84 times.
local function writable_frame(cand)
    local f = read_frame(FIXTURE_DIR .. '/' .. HEADLINE, cand)
    local v = { max_mana = f.max_mana, cost = f.q_cost, r_cost = f.r_cost }
    rawset(f.bot, 'GetMaxMana', function() return v.max_mana end)
    rawset(f.hQ, 'GetManaCost', function() return v.cost end)
    rawset(f.hR, 'GetManaCost', function() return v.r_cost end)
    -- The helper reads the hero file's own file-scope `abilityR`, which is the
    -- handle SkillsComplement pulled with the same name -- the mock caches by
    -- name, so it is this very object.  Asserted rather than assumed, because
    -- if it ever stops being true the grid silently measures the untouched
    -- shipped price on every cell.
    v.r_cost = -12345
    assert(f.X.GetReincarnationReserve(f.hQ) == -12345,
        'the write to R\'s price does not reach X.GetReincarnationReserve -- '
        .. 'the file-scope abilityR is a different handle and this grid would '
        .. 'measure nothing')
    v.r_cost = f.r_cost
    return f, v
end

tests['3.1 armed, the reserve is min(R cost, max mana - cost) across a grid'] =
function()
    local f, v = writable_frame(CAND)
    local checked, moved = 0, 0
    for _, max_mana in ipairs(GRID_MAX) do
        for _, cost in ipairs(GRID_COST) do
            for _, r_cost in ipairs(GRID_R) do
                v.max_mana, v.cost, v.r_cost = max_mana, cost, r_cost
                local got = f.X.GetReincarnationReserve(f.hQ)
                local want = spec_reserve(max_mana, cost, r_cost)
                assert(got == want, string.format(
                    'armed reserve at max=%d cost=%d R=%d is %s, specified %s',
                    max_mana, cost, r_cost, tostring(got), tostring(want)))
                if want ~= r_cost then moved = moved + 1 end
                checked = checked + 1
            end
        end
    end
    assert(checked == 84, 'the grid covered ' .. checked .. ' cells, recorded 84')
    -- A grid on which the cap never bites is a grid that agrees with the
    -- shipped rule everywhere, i.e. proves nothing about the cap.
    assert(moved == 17, 'the cap bites on ' .. moved .. ' of the 84 cells, '
        .. 'recorded 17.  If this is 0 the grid no longer exercises the lever')
end

tests['3.2 unarmed, the reserve is R cost verbatim on every cell of that grid'] =
function()
    -- INERTNESS is the claim a soak candidate lives or dies by, and it is the
    -- one a reader is most likely to take on trust.  Same grid, nothing armed:
    -- every cell must answer R's price, including the cells where the armed leg
    -- answers something else.
    local f, v = writable_frame(nil)
    local differed = 0
    for _, max_mana in ipairs(GRID_MAX) do
        for _, cost in ipairs(GRID_COST) do
            for _, r_cost in ipairs(GRID_R) do
                v.max_mana, v.cost, v.r_cost = max_mana, cost, r_cost
                local got = f.X.GetReincarnationReserve(f.hQ)
                assert(got == r_cost, string.format(
                    'UNARMED reserve at max=%d cost=%d R=%d is %s, must be the '
                    .. 'shipped %s -- the gate leaks', max_mana, cost, r_cost,
                    tostring(got), tostring(r_cost)))
                if spec_reserve(max_mana, cost, r_cost) ~= r_cost then
                    differed = differed + 1
                end
            end
        end
    end
    -- Without this the section passes vacuously on a grid where armed and
    -- unarmed agree everywhere, which is exactly how an inertness test stops
    -- being a test.
    assert(differed > 0, 'the grid holds no cell where the armed leg differs, '
        .. 'so this section proved nothing about the gate')
end

tests['3.3 non-turbo is inert even with the id armed'] = function()
    local f = read_frame(FIXTURE_DIR .. '/' .. HEADLINE, CAND, true)
    assert(f.X.GetReincarnationReserve(f.hQ) == f.r_cost,
        'outside turbo the armed id still moved the reserve -- a soak candidate '
        .. 'must be turbo-only')
    assert(f.X.ShouldSaveMana(f.hQ),
        'outside turbo the armed id still released ' .. HEADLINE)
end

-- ===========================================================================
-- 4  DIRECTION IS GUARANTEED BY SHAPE, NOT BY TODAY'S NUMBERS.
-- ===========================================================================

tests['4.1 the returned reserve is never larger than the shipped one'] =
function()
    -- A WIDENING lever: the comparison it feeds can only move true -> false, so
    -- armed the bot casts MORE and never less.  That is what makes a negative
    -- wave readable as "the extra casts were bad" -- the reading the hero file
    -- note insists on, against "N reincarnations were lost", which no offline
    -- stand can price.  Driven over the same grid so a sign error anywhere in
    -- the helper is caught here even if section 3's spec mirrored it.
    local f, v = writable_frame(CAND)
    for _, max_mana in ipairs(GRID_MAX) do
        for _, cost in ipairs(GRID_COST) do
            for _, r_cost in ipairs(GRID_R) do
                v.max_mana, v.cost, v.r_cost = max_mana, cost, r_cost
                local got = f.X.GetReincarnationReserve(f.hQ)
                assert(got <= r_cost, string.format(
                    'armed reserve at max=%d cost=%d R=%d is %s, LARGER than '
                    .. 'the shipped %s -- this lever would narrow rather than '
                    .. 'widen and the attribution rule in its note is void',
                    max_mana, cost, r_cost, tostring(got), tostring(r_cost)))
                assert(got >= 0, 'a negative reserve at max=' .. max_mana
                    .. ' cost=' .. cost .. ': it would release the guard on '
                    .. 'every frame, which is not this lever')
            end
        end
    end
end

tests['4.2 armed never ADDS a refusal anywhere on the priced corpus'] = function()
    -- Section 4.1 is about the helper; this is about the decision it feeds,
    -- driven on real frames.  The one-way property must survive the call site.
    for _, path in ipairs(priced_corpus()) do
        local base = read_frame(path, nil)
        local armed = read_frame(path, CAND)
        if armed.save and not base.save then
            error(short(path) .. ': arming ' .. CAND .. ' turned a release into '
                .. 'a refusal.  This lever is specified one-way')
        end
    end
end

-- ===========================================================================
-- 5  A RELEASED RESERVE IS NOT A CAST.
-- ===========================================================================

tests['5.1 X.ConsiderQ still answers 0 on the released frame -- with the control'] =
function()
    -- ⚠️ The sentence this section exists to stop: "wksavecap unlocks a blast on
    -- f_232320_wk_od_burst".  It does not.  It unlocks the GUARD; the census
    -- (tests/test_wk_save_mana_lock_census.lua section 5) already measured that
    -- the shipped X.ConsiderQ answers 0 on all 33 priced frames either way, and
    -- the reason is downstream of this lever.
    local armed = read_frame(FIXTURE_DIR .. '/' .. HEADLINE, CAND)
    assert(not armed.save, HEADLINE .. ': the reserve did not release')
    local desire = armed.X.ConsiderQ()
    assert(desire == 0, 'X.ConsiderQ now answers ' .. tostring(desire)
        .. ' on ' .. HEADLINE .. ', recorded 0.  That is not a failure of this '
        .. 'lever -- it is a recorded reading moving, and every "the reserve is '
        .. 'released, not a cast" sentence in this file and in the hero file '
        .. 'note must be re-read before it is quoted again')
end

tests['5.2 the control: the body really ran past the reserve when armed'] =
function()
    -- ⭐ Without this, "ConsiderQ answers 0 either way" and "the function never
    -- got past its first statement" look identical.  Counting the cast-range
    -- read separates them, because X.ConsiderQ reads it only AFTER the reserve
    -- has let it through.  The KV range is fed back first (GetCastRange is on no
    -- spec and would otherwise answer 0, GH #391) so the body is not refused for
    -- a reason that is an instrument artefact.
    local function range_reads(cand)
        local f = read_frame(FIXTURE_DIR .. '/' .. HEADLINE, cand)
        local n = 0
        rawset(f.hQ, 'GetCastRange', function()
            n = n + 1
            return Q_CAST_RANGE
        end)
        pcall(function() f.X.ConsiderQ() end)
        return n
    end
    local shipped, armed = range_reads(nil), range_reads(CAND)
    assert(shipped == 0, 'the SHIPPED leg read Q\'s cast range ' .. shipped
        .. ' times on ' .. HEADLINE .. ', recorded 0.  The reserve is supposed '
        .. 'to short-circuit before the body reads a range; if it does not, '
        .. 'this control no longer separates the two legs')
    assert(armed >= 1, 'the ARMED leg read Q\'s cast range ' .. armed
        .. ' times, recorded >= 1.  A 0 here means the body never ran, and '
        .. 'section 5.1\'s "still answers 0" would be measuring nothing')
end

-- ===========================================================================
-- 6  THE TWO RESERVE LEVERS RELEASE DISJOINT FRAMES.
-- ===========================================================================

tests['6.1 wksavecap releases 1, wksaveidle releases 2, and they do not overlap'] =
function()
    -- Two soak candidates now sit on the same shipped predicate.  If their
    -- release sets overlapped, an A/B wave arming both could not attribute a
    -- behaviour change to either -- the GH #798 shape (`ownhalf` / `overchase`
    -- on one leg), and the reason this is measured rather than asserted in
    -- prose.
    local c = census()
    if #c.released_idle ~= 2 then
        error(SIBLING_CAND .. ' now releases ' .. #c.released_idle
            .. ' of the 6 firing frames, recorded 2: ' .. joined(c.released_idle))
    end
    local seen = {}
    for _, name in ipairs(c.released_cap) do seen[name] = true end
    local checked = 0
    for _, name in ipairs(c.released_idle) do
        checked = checked + 1
        assert(not seen[name], name .. ' is released by BOTH ' .. CAND .. ' and '
            .. SIBLING_CAND .. '.  The two levers can no longer be armed on the '
            .. 'same leg without losing attribution (GH #798)')
    end
    -- ⭐ THE LIVENESS GUARD, added because the mutation stand said so rather
    -- than because it looked tidy.  M10 of tools/agent/mutstand_wksavecap.sh
    -- emptied the loop above and the suite stayed GREEN: a loop that iterates
    -- nothing asserts nothing, and the disjointness claim would have been prose
    -- with a `for` in front of it.  Same family as the empty mutant recorded in
    -- tools/agent/mutstand_wkbonefull.sh M7.
    assert(checked == #c.released_idle,
        'the disjointness loop compared ' .. checked .. ' of the '
        .. #c.released_idle .. ' sibling releases -- it is not iterating the '
        .. 'set it claims to iterate')
    assert(checked > 0, 'the disjointness loop compared nothing at all')
end

tests['6.2 the sibling refuses the headline frame on BOTH of its terms'] =
function()
    -- The hero file's note says exactly this, so it is driven here rather than
    -- left as prose.  It matters because "wksaveidle already covers this" is the
    -- first objection to the new lever, and the answer is that the sibling's
    -- release conditions are not merely unmet but doubly unmet.
    local f = read_frame(FIXTURE_DIR .. '/' .. HEADLINE, SIBLING_CAND)
    local J = f.J
    local hp = J.GetHP(f.bot)
    assert(hp < 0.95, HEADLINE .. ': health is now ' .. tostring(hp)
        .. ', at or above the 0.95 floor -- the sibling\'s HP term no longer '
        .. 'refuses here and the note in the hero file must be corrected')
    local near = #J.GetNearbyHeroes(f.bot, 1600, true, BOT_MODE_NONE)
    assert(near > 0, HEADLINE .. ': the 1600u ring is now empty -- the '
        .. 'sibling\'s enemy-count term no longer refuses here either')
    assert(f.save, HEADLINE .. ': arming ' .. SIBLING_CAND
        .. ' alone now releases this frame, so the two levers are no longer '
        .. 'disjoint and section 6.1 is measuring a coincidence')
end

return tests

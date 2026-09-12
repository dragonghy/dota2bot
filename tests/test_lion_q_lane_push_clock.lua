-- [hero] `lionpushclock` -- the 推线 (lane-push) firing point of Lion's
-- X.ConsiderQ is the only place in bots/BotLib/hero_lion.lua that carries a
-- wall-clock COMPARISON, and the clock is a NORMAL-MODE constant standing in
-- front of a branch whose own enabling condition this file's ability build
-- satisfies at hero level 8.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_lion.lua X.ConsiderQ, as shipped:
--
--     if ( J.IsPushing( bot ) or J.IsDefending( bot ) or J.IsFarming( bot ) )
--         and J.IsAllowedToSpam( bot, nManaCost )   <- the mana rationer
--         and nSkillLV >= 4 and DotaTime() > 9 * 60 <- a PROXY
--         and #hAllyList <= 2 and #hEnemyList == 0  <- the safety measurements
--         and not bot:HasScepter()
--     then ... Impale a >= 5 creep lane wave
--
-- The branch's payoff channel is Impale itself, and the branch says so: it
-- refuses until `nSkillLV >= 4`, i.e. until Impale is MAXED.  This file's own
-- build row ({1,3,1,2,3,6,1,1,3,3,6,2,2,2,6}) puts the fourth point in Impale
-- at hero level 8 -- in Turbo, with XP doubled, that arrives well inside the
-- window the clock closes.  So the branch's own precondition is satisfied for
-- several hero levels while the branch itself is refused by a clock.
--
-- ⚠️ AND THE CLOCK IS NOT DOING EITHER JOB A CLOCK COULD BE DOING HERE, which
-- §5 counts rather than asserts in prose:
--   * not a mana policy -- `J.IsAllowedToSpam( bot, nManaCost )` is already a
--     conjunct of the same `if` (jmz_func.lua :2119 keeps fKeepManaPercent of
--     max mana AFTER the cast), so a second, time-shaped rationer on the same
--     `if` would be rationing twice;
--   * not a safety term -- `#hEnemyList == 0` and `#hAllyList <= 2` are already
--     conjuncts of the same `if`, and they are the DIRECT measurement of "is it
--     safe to stand here and clear a wave".  As in `cmtfclock` (GH #758) and
--     `axecallclock` (GH #788), the proxy sits beside the measurement and
--     overrides it.
--
-- ===========================================================================
-- §0.1  DIRECTION -- THIS IS A WIDENING, and that is the first thing to know
-- ===========================================================================
--
-- Every t past 9:00 is also past 4:30, so armed is a strict SUPERSET of
-- shipped: arming can only ADD 推线 Impales, inside (4:30, 9:00], and can never
-- remove one or move one onto a different location.  §4 drives that over the
-- whole corpus rather than arguing it.  A negative wave reading is attributable
-- to "those early lane-push Impales were not worth casting" and NEVER to a cast
-- this lever refused.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua                          # whole suite
--     lua5.1 tests/run_tests.lua lion_q_lane_push_clock    # this file
--
-- ⚠️ `lua5.1 -e "dofile(...)"` on this file exits SILENTLY (exit 0, no output)
-- in a Routine container -- it is not this file's bug (the pre-existing
-- tests/test_cm_w_teamfight_clock.lua behaves identically), and it is why the
-- run_tests.lua entry above is the only reading taken here.
--
-- ===========================================================================
-- §0.3  LIMITS (each one has an assertion below)
-- ===========================================================================
--
--   1. ⛔ TWO DOMAINS, and they are different numbers.  GATE-LAYER domain = 5
--      corpus instants (§3): the clock is the only thing that answers
--      differently there.  END-TO-END domain = 0 and cannot be anything else
--      today -- the branch also needs `#laneCreepList >= 5` and the dumped
--      corpus carries NO non-hero units at all (GH #772).  §3.4 asserts that
--      zero in that direction, so the two can never be quoted as one number.
--   2. 5 of 14 is a DOMAIN, not a frequency.  A fixture corpus is a set of
--      instants chosen for OTHER investigations; how often a real Turbo game
--      puts Lion beside a 5-creep wave with no enemy hero in the ring inside
--      (4:30, 9:00] is a wave question (iterations/queue.json hero-69).
--   3. NOT in this id: whether the branch should carry a clock AT ALL, and none
--      of the branch's other conjuncts.  §5.3 pins them unchanged.
--   4. Every corpus count below that is not itself a conclusion is a FLOOR, so
--      a corpus that GROWS may only make these larger and cannot turn this file
--      red for being right (the `-145`/`-149`/`-152` family of same-cause reds
--      was every time a `== N` pin on corpus size).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local skillmap = require('skill_level_map')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CAND   = 'lionpushclock'
local UNIT   = 'npc_dota_hero_lion'
local HELPER = 'lion_IsLanePushClockOpen'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting CODE shapes cannot be satisfied by
--- prose that merely mentions the expression (backlog -149, and -160's second
--- lesson: the census that counted a fix's own comment).
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
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

--- ⭐ THE THRESHOLDS ARE READ OFF THE SOURCE, never re-typed.  A mirror that
--- froze today's 9*60 / 4.5*60 would keep passing the day the hero file changed
--- them -- the stale-mirror defect tests/test_cast_ring_mirror_discipline.lua
--- exists to catch.
local SHIPPED = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nQLanePushClockShipped%s*=%s*([^\n]+)'),
    'X.nQLanePushClockShipped is gone from ' .. SRC)))()
local TURBO = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nQLanePushClockTurbo%s*=%s*([^\n]+)'),
    'X.nQLanePushClockTurbo is gone from ' .. SRC)))()

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen over a literal directory, non-recursive
        -- `ls`, registered per GH #596's habit and GH #774's list.  It cannot
        -- reach bots/Customize/.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

local function frame(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return nil end
    return chunk
end

--- Every instant in the corpus whose SUBJECT is Lion.  The clock reads
--- DotaTime(), a property of the frame; restricting to Lion-subject frames is
--- not required by the predicate but it is what makes the count in §3 a
--- statement about THIS hero rather than about the corpus's clock histogram.
local function lion_subject_frames()
    local out = {}
    for _, p in ipairs(corpus_paths()) do
        local fx = frame(p)
        if fx ~= nil and fx.self == UNIT and type(fx.time) == 'number' then
            out[#out + 1] = { path = p, t = fx.time }
        end
    end
    return out
end

--- One loaded world.  `opt.armed` arms CAND; `opt.nonTurbo` undoes rf.load's
--- forced turbo AFTER load, exactly as tests/test_cm_w_teamfight_clock.lua and
--- tests/test_axe_q_lane_push_clock.lua do.
local function world(path, opt)
    opt = opt or {}
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return id == CAND and opt.armed == true end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    local X = rf.load_hero('lion')
    return J, bot, X
end

-- ===========================================================================
-- §1  THE GATE IS WIRED, AND IT NAMES EXACTLY ONE ID
-- ===========================================================================

tests['1.1 helper exists, is turbo-gated, and names only its own id'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, HELPER))
    assert(body:find('J.IsModeTurbo()', 1, true),
        HELPER .. ' lost its turbo guard -- a soak candidate must be turbo-only')
    assert(count(body, "IsSoakCandidate( '") == 1,
        HELPER .. ' must hold exactly ONE IsSoakCandidate call (it holds '
        .. count(body, "IsSoakCandidate( '") .. ')')
    assert(body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true),
        HELPER .. ' no longer names ' .. CAND)
    -- pullcad trap: a gate that names ANOTHER id freezes FALSE the day that id
    -- is promoted, and check_armed_wiring.py would still call this WIRED.
    for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == CAND,
            HELPER .. ' names a second id ' .. id .. ' -- the pullcad trap')
    end
end

tests['1.2 the call site is wired and the literal clock is gone from it'] = function()
    local n = count(SRC_CODE, 'X.lion_IsLanePushClockOpen()')
    assert(n == 2,
        'expected exactly two X.lion_IsLanePushClockOpen() occurrences in code '
        .. '(the definition and the single call site), got ' .. n)
    assert(not SRC_CODE:find('DotaTime() > 9 * 60', 1, true),
        'the literal `DotaTime() > 9 * 60` is back in the code -- either the '
        .. 'call site was reverted or a second copy was added; the threshold '
        .. 'lives in X.nQLanePushClockShipped now')
end

tests['1.3 the id appears in bots/ exactly once, inside the helper'] = function()
    assert(count(SRC_CODE, CAND) == 1,
        CAND .. ' appears ' .. count(SRC_CODE, CAND)
        .. ' times in ' .. SRC .. ' code; it must appear exactly once')
end

-- ===========================================================================
-- §2  THE TWO NUMBERS, READ OFF THE SOURCE
-- ===========================================================================

tests['2.1 armed threshold is the shipped one halved'] = function()
    assert(SHIPPED == 9 * 60, 'shipped clock moved to ' .. tostring(SHIPPED)
        .. ' -- if that is intended, the header argument (a NORMAL-MODE 9:00) '
        .. 'has to move with it')
    assert(TURBO * 2 == SHIPPED,
        'armed threshold ' .. tostring(TURBO) .. ' is no longer SHIPPED/2 ('
        .. tostring(SHIPPED) .. ') -- the 2x is this repo\'s stated Turbo pace '
        .. 'ratio, not a free parameter')
    assert(TURBO < SHIPPED, 'the armed clock must be EARLIER than shipped, or '
        .. 'this lever is a narrowing and every direction claim above is wrong')
end

-- ===========================================================================
-- §3  REAL FRAMES -- THE GATE-LAYER DOMAIN, AND WHAT IT IS NOT
-- ===========================================================================

tests['3.1 the in-window Lion instants: shipped refuses, armed does not'] = function()
    local hit = {}
    for _, fr in ipairs(lion_subject_frames()) do
        if fr.t > TURBO and fr.t <= SHIPPED then hit[#hit + 1] = fr end
    end
    assert(#hit >= 5, 'expected at least 5 Lion-subject instants inside ('
        .. TURBO .. ', ' .. SHIPPED .. '], found ' .. #hit
        .. ' -- this is a FLOOR (LIMIT 4); a shrinking corpus is the only way '
        .. 'to get here')
    for _, fr in ipairs(hit) do
        local _, _, Xs = world(fr.path, { armed = false })
        assert(Xs.lion_IsLanePushClockOpen() == false,
            fr.path .. ' (t=' .. fr.t .. '): shipped leg should REFUSE inside '
            .. 'the window')
        local _, _, Xa = world(fr.path, { armed = true })
        assert(Xa.lion_IsLanePushClockOpen() == true,
            fr.path .. ' (t=' .. fr.t .. '): armed leg should ADMIT inside the '
            .. 'window -- this is the whole lever')
    end
end

tests['3.2 the pin, named: lion_meatgrinder at t=419.0 (6:59)'] = function()
    local PIN = FIXTURE_DIR .. '/f_045650_lion_meatgrinder.lua'
    local fx = frame(PIN)
    assert(fx ~= nil, 'the pin frame ' .. PIN .. ' is gone')
    assert(fx.self == UNIT, 'the pin frame is no longer a Lion-subject frame')
    assert(fx.time > TURBO and fx.time <= SHIPPED,
        'the pin frame moved out of (' .. TURBO .. ', ' .. SHIPPED .. ']: t='
        .. tostring(fx.time))
    local _, _, Xs = world(PIN, { armed = false })
    assert(Xs.lion_IsLanePushClockOpen() == false)
    local _, _, Xa = world(PIN, { armed = true })
    assert(Xa.lion_IsLanePushClockOpen() == true)
end

tests['3.3 non-turbo armed is byte-for-byte the shipped answer'] = function()
    local PIN = FIXTURE_DIR .. '/f_045650_lion_meatgrinder.lua'
    local _, _, X = world(PIN, { armed = true, nonTurbo = true })
    assert(X.lion_IsLanePushClockOpen() == false,
        'armed but NOT turbo must answer exactly what shipped answers -- a soak '
        .. 'candidate may not change a normal-mode game')
end

tests['3.4 END-TO-END domain is 0, and the corpus cannot make it anything else'] = function()
    -- The branch also needs `#laneCreepList >= 5`.  GH #772: the dumped corpus
    -- carries no non-hero units at all, so no archived frame can drive the
    -- branch to its return.  Asserting the zero in THIS direction is what stops
    -- §3.1's "5" from being quoted as an execution verification.
    local nonHero = 0
    for _, p in ipairs(corpus_paths()) do
        local fx = frame(p)
        for _, u in ipairs((fx or {}).units or {}) do
            if not tostring(u.name):match('^npc_dota_hero_') then
                nonHero = nonHero + 1
            end
        end
    end
    assert(nonHero == 0,
        'the corpus now carries ' .. nonHero .. ' non-hero unit(s) (GH #772 '
        .. 'moved).  That is GOOD NEWS and this assertion is the flag: the '
        .. 'END-TO-END domain of `' .. CAND .. '` is now measurable and this '
        .. 'file owes a frame-level reading of `#laneCreepList >= 5`.')
end

-- ===========================================================================
-- §4  DIRECTION, DRIVEN OVER THE WHOLE CORPUS RATHER THAN ARGUED
-- ===========================================================================

tests['4.1 shipped => armed on every corpus instant (strict superset)'] = function()
    local seen, flipped = 0, 0
    for _, p in ipairs(corpus_paths()) do
        local fx = frame(p)
        if fx ~= nil and type(fx.time) == 'number' then
            seen = seen + 1
            local bShipped = fx.time > SHIPPED
            local bArmed   = fx.time > TURBO
            assert(not (bShipped and not bArmed),
                p .. ': shipped admits and armed refuses -- the lever is NOT a '
                .. 'widening and every direction claim in this file is wrong')
            if bArmed and not bShipped then flipped = flipped + 1 end
        end
    end
    assert(seen >= 100, 'corpus shrank to ' .. seen .. ' timed instants')
    assert(flipped >= 1, 'no corpus instant sits in the window at all -- the '
        .. 'lever would be untestable offline')
end

tests['4.2 the flip set is exactly the window, on the loaded predicate'] = function()
    -- Same claim as 4.1 but through the real helper on real loads, so a mutant
    -- that changes the PREDICATE (rather than the constants) is caught too.
    for _, fr in ipairs(lion_subject_frames()) do
        local _, _, Xs = world(fr.path, { armed = false })
        local _, _, Xa = world(fr.path, { armed = true })
        local s, a = Xs.lion_IsLanePushClockOpen(), Xa.lion_IsLanePushClockOpen()
        assert(s == (fr.t > SHIPPED), fr.path .. ': shipped leg disagrees with '
            .. 'DotaTime() > ' .. SHIPPED)
        assert(a == (fr.t > TURBO), fr.path .. ': armed leg disagrees with '
            .. 'DotaTime() > ' .. TURBO)
        assert(not (s and not a), fr.path .. ': superset violated on a load')
    end
end

-- ===========================================================================
-- §5  CENSUS -- THE CLAIMS IN THE HEADER, COUNTED
-- ===========================================================================

tests['5.1 this is the only wall-clock COMPARISON in the file'] = function()
    -- Three DotaTime() reads survive in code: the helper's two legs, plus the
    -- cast-timestamp bookkeeping pair (lastCastQTime = DotaTime() and the
    -- `lastCastQTime > DotaTime() - 0.8` recency test).  The header's claim is
    -- about CURFEWS, so count both groups and separate them here rather than
    -- asserting the distinction in prose.
    local n = count(SRC_CODE, 'DotaTime()')
    assert(n == 4, 'expected exactly 4 DotaTime() reads in ' .. SRC
        .. ' code (2 helper legs + 2 lastCastQTime bookkeeping), found ' .. n
        .. ' -- if a new wall clock landed, the header\'s "the ONLY wall-clock '
        .. 'comparison in this file" is stale and must be re-read, not re-typed')
    assert(count(SRC_CODE, 'lastCastQTime') == 3,
        'the lastCastQTime bookkeeping changed shape; §5.1\'s arithmetic (4 = 2'
        .. ' + 2) no longer separates curfews from recency tests')
end

tests['5.2 the branch already carries its own mana rationer and safety terms'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, 'ConsiderQ'))
    local at = body:find('X.lion_IsLanePushClockOpen()', 1, true)
    assert(at, 'the 推线 call site left X.ConsiderQ')
    -- the conjunction the call site sits in, read as the enclosing `if`
    local from = body:sub(1, at):match('.*()if ')
    local chunk = body:sub(from, at + 200)
    assert(chunk:find('J.IsAllowedToSpam( bot, nManaCost )', 1, true),
        'the 推线 branch lost J.IsAllowedToSpam -- the header argues the clock '
        .. 'is not a mana policy BECAUSE this conjunct is already there')
    assert(chunk:find('#hEnemyList == 0', 1, true),
        'the 推线 branch lost `#hEnemyList == 0` -- the header argues the clock '
        .. 'is not a safety term BECAUSE this conjunct is already there')
    assert(chunk:find('#hAllyList <= 2', 1, true),
        'the 推线 branch lost `#hAllyList <= 2` -- same reason')
end

tests['5.3 nothing else on the branch moved'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, 'ConsiderQ'))
    for _, term in ipairs({
        'J.IsPushing( bot )', 'J.IsDefending( bot )', 'J.IsFarming( bot )',
        'nSkillLV >= 4', 'not bot:HasScepter()',
        '#laneCreepList >= 5', 'J.IsGlyphVetoClear( laneCreepList )',
    }) do
        assert(body:find(term, 1, true),
            'the 推线 branch lost `' .. term .. '` -- this lever moves ONE '
            .. 'conjunct and LIMIT 3 says so')
    end
end

tests['5.4 the build row the (c) argument rests on still maxes Impale at lv8'] = function()
    local src = skillmap.read_file(SRC)
    local row = skillmap.build_row(src)
    local slot = skillmap.ability_slots(src)
    assert(slot.abilityQ == 1,
        'abilityQ is no longer sAbilityList[' .. tostring(slot.abilityQ)
        .. '] -- the build-row reading below counts slot 1')
    -- Drive the REAL J.Skill.GetSkillList rather than counting row entries:
    -- the row index is not the hero level once talents interleave (GH #134).
    -- Impale's fourth point lands at index 8, inside the pre-talent prefix, so
    -- the two readings must agree -- assert that they do rather than assume it.
    local ranks = select(1, skillmap.ranks_at(UNIT, row,
        skillmap.talent_rows(src), 8))
    assert((ranks[slot.abilityQ] or 0) >= 4,
        'Impale reaches only rank ' .. tostring(ranks[slot.abilityQ] or 0)
        .. ' by hero level 8 under the current build row -- the (c) argument '
        .. 'for `' .. CAND .. '` rested on rank 4 (the branch\'s own '
        .. '`nSkillLV >= 4`) by level 8 and is now stale')
    local byIndex = 0
    for i = 1, 8 do if row[i] == slot.abilityQ then byIndex = byIndex + 1 end end
    assert(byIndex == (ranks[slot.abilityQ] or 0),
        'row-index count (' .. byIndex .. ') and the driven skill list ('
        .. tostring(ranks[slot.abilityQ]) .. ') disagree at level 8 -- a talent '
        .. 'now interleaves before level 10 and the header footnote is stale')
end

return tests

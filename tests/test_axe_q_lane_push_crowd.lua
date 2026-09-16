-- [hero] `axecallcrowd` -- the 带线 (lane-push) firing point of Axe's
-- X.ConsiderQ refuses to taunt a lane wave whenever two or more allies stand
-- near Axe, and the state it is refusing is a GROUPED PUSH: the same `if`
-- already carries `#hEnemyList == 0`.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_axe.lua X.ConsiderQ, as shipped:
--
--     if ( J.IsPushing( bot ) or J.IsDefending( bot ) or J.IsFarming( bot ) )
--         and J.IsAllowedToSpam( bot, nManaCost )   <- the mana rationer
--         and bot:GetAttackTarget() ~= nil
--         and DotaTime() > 6 * 60                   <- `axecallclock`, NOT this
--         and #hAllyList <= 2                       <- THIS ID
--         and #hEnemyList == 0                      <- the safety measurement
--     then ... taunt a >= 4 creep lane wave onto Axe
--
-- `#hEnemyList == 0` is a conjunct of the same `if`, so the state the cap
-- refuses is "several of my team, standing in a lane wave, with no enemy hero
-- in view".  That is not a danger; it is the grouped push docs/PROJECT.md names
-- as paying off MORE in Turbo than in normal mode ("weaker towers, shorter
-- games, grouped pushing pays off more").  The cap is at its most restrictive
-- exactly where the mode's own doctrine wants the wave deleted fastest.
--
-- ⚠️ BOTH LEGS COUNT AXE HIMSELF.  J.GetAlliesNearLoc walks every living team
-- member and keeps the ones inside the radius, and the caster is at distance 0
-- from his own location.  So shipped `<= 2` is "Axe plus at most ONE other"
-- and armed `<= 4` is "Axe plus at most THREE" -- armed still refuses exactly
-- one state, the full five-man stack.  §2.4 drives that off the loader rather
-- than trusting the reading.
--
-- ===========================================================================
-- §0.1  DIRECTION -- THIS IS A WIDENING, and that is the first thing to know
-- ===========================================================================
--
-- Every count satisfying `<= 2` also satisfies `<= 4`, so armed is a strict
-- SUPERSET of shipped: arming can only ADD 带线 taunts and can never remove one
-- or move one onto a different target.  §4 drives that over the whole corpus
-- rather than arguing it.  A negative wave reading is attributable to "those
-- grouped lane-push taunts were not worth casting" and NEVER to a cast this
-- lever refused.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua                 # whole suite
--     lua5.1 -e "for n,f in pairs(dofile('tests/test_axe_q_lane_push_crowd.lua')) do f() end"
--
-- ===========================================================================
-- §0.3  LIMITS (each one has an assertion below)
-- ===========================================================================
--
--   1. ⛔ THE LEVER IS THE CAP, NOT THE RADIUS, and that is a MEASUREMENT and
--      not a preference.  The first draft moved the 1600u `hAllyList` is built
--      with (hero_axe.lua:426) on the grounds that 1600 is ~5x Berserker's
--      Call's own 315u radius.  Over the 16 Axe-subject instants, shrinking
--      1600 -> 1200 / 900 / 800 / 600 moves the answer to `<= 2` on ZERO of
--      them.  The radius claim is TRUE and NOT LOAD-BEARING; §2.3 keeps the
--      measurement executable so nobody re-derives the dead lever from the
--      prose.
--   2. ⛔ THREE DOMAINS, and they are different numbers.  CONJUNCT-LAYER = 4
--      corpus instants (§3.1), the half this lever changes.  BRANCH-LEVEL = 0
--      (§6), and the reason is SELECTION not rarity: these frames were
--      harvested to study Call/Culling-Blade decisions, i.e. moments with
--      enemies present, and `#hEnemyList == 0` holds on 1 of 16.  END-TO-END =
--      0 and cannot be anything else today (§3.4): the branch needs
--      `#laneCreepList >= 4` and the dumped corpus carries no non-hero units
--      at all (GH #772).  Quoting any two of these as one number would be an
--      execution verification out of thin air.
--   3. 4 of 16 is a DOMAIN, not a frequency.  How often a real Turbo game puts
--      3-5 grouped allies in a 4-creep wave with no enemy hero in view is a
--      wave question (iterations/queue.json hero-93).
--   4. ⛔ NOT a bundle with `axecallclock`.  Both levers sit on conjuncts of
--      the same `if`, so arming both in one wave is attributable to neither,
--      and neither gate names the other's id (the `pullcad` trap).  §7 asserts
--      the independence in both directions.
--   5. NOT in this id: whether the branch should carry a crowd cap AT ALL (the
--      armed cap is 4, not 5, precisely so a refusal survives), and none of
--      the branch's other conjuncts.  §5.3 pins them unchanged.
--   6. Every corpus count below that is not itself a conclusion is a FLOOR, so
--      a corpus that GROWS may only make these larger and cannot turn this
--      file red for being right.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_axe.lua'
local CAND   = 'axecallcrowd'
local SIB    = 'axecallclock'
local UNIT   = 'npc_dota_hero_axe'
local HELPER = 'axe_IsLanePushCrowdOpen'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

--- The ally-count radius `hAllyList` is built with at hero_axe.lua:426.  Read
--- off the source in §2.3 rather than trusted here.
local ALLY_RADIUS = 1600

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting CODE shapes cannot be satisfied by
--- prose that merely mentions the expression (backlog -149).
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

--- ⭐ THE CAPS ARE READ OFF THE SOURCE, never re-typed.  A mirror that froze
--- today's 2 / 4 would keep passing the day the hero file changed them -- the
--- stale-mirror defect tests/test_cast_ring_mirror_discipline.lua exists to
--- catch.
local SHIPPED = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nQLanePushAllyCapShipped%s*=%s*([^\n]+)'),
    'X.nQLanePushAllyCapShipped is gone from ' .. SRC)))()
local TURBO = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nQLanePushAllyCapTurbo%s*=%s*([^\n]+)'),
    'X.nQLanePushAllyCapTurbo is gone from ' .. SRC)))()

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

--- Every instant in the corpus whose SUBJECT is Axe.  The cap reads a list
--- built around the SUBJECT's own location, so restricting to Axe-subject
--- frames is what makes the counts below statements about THIS hero.
local function axe_subject_paths()
    local out = {}
    for _, p in ipairs(corpus_paths()) do
        local fx = frame(p)
        if fx ~= nil and fx.self == UNIT and type(fx.time) == 'number' then
            out[#out + 1] = { path = p, t = fx.time }
        end
    end
    return out
end

--- One loaded world.  `opt.arm` is the SET of ids that answer true, so §7 can
--- arm a sibling without arming this id.  `opt.nonTurbo` undoes rf.load's
--- forced turbo AFTER load, exactly as tests/test_cm_w_teamfight_clock.lua does.
local function world(path, opt)
    opt = opt or {}
    local armed = opt.arm or {}
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return armed[id] == true end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    local X = rf.load_hero('axe')
    return J, bot, X
end

--- ⭐ THE ALLY COUNT COMES FROM THE REAL HELPER ON THE REAL FRAME, not from a
--- re-implementation of the distance loop in this file.  That is the whole
--- point of the fixture tier: the number the branch would see is the number
--- J.GetAlliesNearLoc produces, self-inclusion and liveness included.
local function ally_count(J, bot, nRadius)
    return #J.GetAlliesNearLoc(bot:GetLocation(), nRadius or ALLY_RADIUS)
end

--- Loaded once, reused by every section that needs real frames.
local LOADED = nil
local function loaded_axe_frames()
    if LOADED then return LOADED end
    LOADED = {}
    for _, fr in ipairs(axe_subject_paths()) do
        local J, bot = world(fr.path, {})
        local row = { path = fr.path, t = fr.t, band = {} }
        for _, r in ipairs({ 1600, 1200, 900, 800, 600, 400 }) do
            row.band[r] = ally_count(J, bot, r)
        end
        row.ally  = row.band[ALLY_RADIUS]
        row.enemy = #J.GetNearbyHeroes(bot, ALLY_RADIUS, true, BOT_MODE_NONE)
        LOADED[#LOADED + 1] = row
    end
    return LOADED
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

tests['1.2 the call site is wired and the literal cap is gone from it'] = function()
    local n = count(SRC_CODE, 'X.axe_IsLanePushCrowdOpen(')
    assert(n == 2, 'expected exactly two X.axe_IsLanePushCrowdOpen( occurrences '
        .. 'in code (the definition and the single call site), got ' .. n)
    assert(not SRC_CODE:find('#hAllyList <= 2', 1, true),
        'the literal `#hAllyList <= 2` is back in the code -- either the call '
        .. 'site was reverted or a second copy was added; the threshold lives '
        .. 'in X.nQLanePushAllyCapShipped now')
    assert(SRC_CODE:find('X.axe_IsLanePushCrowdOpen( #hAllyList )', 1, true),
        'the call site no longer passes #hAllyList -- the helper is pure and '
        .. 'the list it must be fed is the one built at hero_axe.lua:426')
end

tests['1.3 the id appears in bots/ exactly once, inside the helper'] = function()
    assert(count(SRC_CODE, CAND) == 1,
        CAND .. ' appears ' .. count(SRC_CODE, CAND)
        .. ' times in ' .. SRC .. ' code; it must appear exactly once')
end

-- ===========================================================================
-- §2  THE TWO NUMBERS, AND THE LEVER THAT MEASUREMENT KILLED
-- ===========================================================================

tests['2.1 the caps are what the header argues about'] = function()
    assert(SHIPPED == 2, 'shipped cap moved to ' .. tostring(SHIPPED)
        .. ' -- if that is intended, the header argument has to move with it')
    assert(TURBO > SHIPPED, 'the armed cap must be LARGER than shipped, or this '
        .. 'lever is a narrowing and every direction claim above is wrong')
end

tests['2.2 the armed cap leaves a refusal -- it does not delete the conjunct'] = function()
    -- A five-man team is five living members, and the count includes Axe.  A
    -- cap of 5 would make the conjunct unfalsifiable, which is the second
    -- question LIMIT 5 refuses to conjoin with this one.
    assert(TURBO < 5, 'the armed cap is ' .. tostring(TURBO) .. ', which no '
        .. 'five-man team can exceed -- that DELETES the conjunct rather than '
        .. 'raising it, and this file\'s whole "one lever at a time" argument '
        .. 'is gone with it')
end

tests['2.3 ⛔ the RADIUS is not the lever, and this is the measurement'] = function()
    -- LIMIT 1, kept executable.  If this ever fails, the dead lever came back
    -- to life and is worth its own id -- do not silently widen this one.
    local rows = loaded_axe_frames()
    assert(#rows >= 16, 'Axe-subject corpus shrank to ' .. #rows
        .. ' instants (FLOOR, LIMIT 6)')
    local moved = {}
    for _, r in ipairs({ 1200, 900, 800, 600 }) do
        moved[r] = 0
        for _, row in ipairs(rows) do
            local base = (row.band[ALLY_RADIUS] <= SHIPPED)
            local narrow = (row.band[r] <= SHIPPED)
            if base ~= narrow then moved[r] = moved[r] + 1 end
        end
        assert(moved[r] == 0, 'shrinking the ally radius ' .. ALLY_RADIUS
            .. ' -> ' .. r .. ' now moves `<= ' .. SHIPPED .. '` on '
            .. moved[r] .. ' Axe instant(s).  That is NEWS: the radius was '
            .. 'measured dead when `' .. CAND .. '` landed, and the header '
            .. 'says so.  Re-read the corpus, do not re-type the conclusion.')
    end
end

tests['2.4 the ally count includes the caster -- both legs are off by one'] = function()
    -- The header's "armed still refuses exactly the five-man stack" rests on
    -- this.  Driven off the loader, not read off jmz_func's source.
    local rows = loaded_axe_frames()
    local solo = 0
    for _, row in ipairs(rows) do
        assert(row.ally >= 1, row.path .. ': J.GetAlliesNearLoc answered '
            .. row.ally .. ' at the subject\'s OWN location -- the caster is at '
            .. 'distance 0 from himself, so 0 is impossible unless the helper '
            .. 'stopped counting self, which shifts the meaning of BOTH caps')
        if row.ally == 1 then solo = solo + 1 end
    end
    assert(solo >= 1, 'no Axe instant has the subject alone in the list, so '
        .. 'this file cannot show that 1 means "just me"')
end

-- ===========================================================================
-- §3  REAL FRAMES -- THE CONJUNCT-LAYER DOMAIN, AND WHAT IT IS NOT
-- ===========================================================================

tests['3.1 the domain, as the number it is: shipped refuses, armed admits'] = function()
    local rows = loaded_axe_frames()
    local shipPass, armPass, moved, both_refuse = 0, 0, 0, 0
    for _, row in ipairs(rows) do
        local _, _, Xs = world(row.path, { arm = {} })
        local _, _, Xa = world(row.path, { arm = { [CAND] = true } })
        local s = Xs.axe_IsLanePushCrowdOpen(row.ally)
        local a = Xa.axe_IsLanePushCrowdOpen(row.ally)
        assert(s == (row.ally <= SHIPPED), row.path .. ': shipped leg disagrees '
            .. 'with `<= ' .. SHIPPED .. '` on an ally count of ' .. row.ally)
        assert(a == (row.ally <= TURBO), row.path .. ': armed leg disagrees '
            .. 'with `<= ' .. TURBO .. '` on an ally count of ' .. row.ally)
        if s then shipPass = shipPass + 1 end
        if a then armPass = armPass + 1 end
        if a and not s then moved = moved + 1 end
        if not a and not s then both_refuse = both_refuse + 1 end
    end
    assert(moved >= 4, 'the lever moves ' .. moved .. ' Axe instant(s); it moved '
        .. '4 when it landed (FLOOR, LIMIT 6)')
    assert(both_refuse >= 1, 'no Axe instant is refused by BOTH legs any more, '
        .. 'so the residual §2.2 argues for is no longer OCCUPIED -- the cap '
        .. 'of ' .. TURBO .. ' has become unfalsifiable ON THIS CORPUS and the '
        .. 'header claim about the five-man stack is stale')
    assert(armPass > shipPass, 'armed admits ' .. armPass .. ' and shipped '
        .. shipPass .. ' -- a widening must admit strictly more')
end

tests['3.2 the pin, named: axe_cull_promise at t=1452.8 is the residual'] = function()
    local PIN = STAGED_DIR .. '/f_260828_124358_axe_cull_promise.lua'
    local fx = frame(PIN)
    assert(fx ~= nil, 'the pin frame ' .. PIN .. ' is gone')
    assert(fx.self == UNIT, 'the pin frame is no longer an Axe-subject frame')
    local J, bot, Xa = world(PIN, { arm = { [CAND] = true } })
    local n = ally_count(J, bot)
    assert(n == 5, 'the pin frame now counts ' .. n .. ' allies, not 5 -- it '
        .. 'was chosen BECAUSE all five are alive inside ' .. ALLY_RADIUS
        .. 'u, which is what makes it the one state armed still refuses')
    assert(Xa.axe_IsLanePushCrowdOpen(n) == false,
        'the armed leg admits the full five-man stack -- that is the state '
        .. '§2.2 says the armed cap deliberately keeps refusing')
    local _, _, Xs = world(PIN, { arm = {} })
    assert(Xs.axe_IsLanePushCrowdOpen(n) == false,
        'the shipped leg should refuse it too')
end

tests['3.3 non-turbo armed is byte-for-byte the shipped answer'] = function()
    local PIN = STAGED_DIR .. '/f_260909_215412_axe_cull_cm_838.lua'
    local J, bot = world(PIN, { arm = {} })
    local n = ally_count(J, bot)
    assert(n > SHIPPED and n <= TURBO, 'the pin frame counts ' .. n
        .. ' allies, which is no longer inside (' .. SHIPPED .. ', ' .. TURBO
        .. '] -- it cannot separate the legs any more')
    local _, _, X = world(PIN, { arm = { [CAND] = true }, nonTurbo = true })
    assert(X.axe_IsLanePushCrowdOpen(n) == false,
        'armed but NOT turbo must answer exactly what shipped answers -- a soak '
        .. 'candidate may not change a normal-mode game')
end

tests['3.4 END-TO-END domain is 0, and the corpus cannot make it anything else'] = function()
    -- The branch also needs `#laneCreepList >= 4`.  GH #772: the dumped corpus
    -- carries no non-hero units at all, so no archived frame can drive the
    -- branch to its return.  Asserting the zero in THIS direction is what stops
    -- §3.1's "4" from being quoted as an execution verification.
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
        .. 'file owes a frame-level reading of `#laneCreepList >= 4`.')
end

-- ===========================================================================
-- §4  DIRECTION, DRIVEN OVER THE CORPUS RATHER THAN ARGUED
-- ===========================================================================

tests['4.1 shipped => armed on every Axe instant (strict superset)'] = function()
    for _, row in ipairs(loaded_axe_frames()) do
        local _, _, Xs = world(row.path, { arm = {} })
        local _, _, Xa = world(row.path, { arm = { [CAND] = true } })
        local s = Xs.axe_IsLanePushCrowdOpen(row.ally)
        local a = Xa.axe_IsLanePushCrowdOpen(row.ally)
        assert(not (s and not a), row.path .. ': shipped admits and armed '
            .. 'refuses -- the lever is NOT a widening and every direction '
            .. 'claim in this file is wrong')
    end
end

tests['4.2 superset holds for every count, not just the ones the corpus has'] = function()
    -- The corpus can only ever show the counts it happens to contain; the
    -- predicate is total over 0..5 and is cheap to drive exhaustively.
    local _, _, Xs = world(STAGED_DIR .. '/f_260909_215412_axe_cull_drow_475.lua',
        { arm = {} })
    local _, _, Xa = world(STAGED_DIR .. '/f_260909_215412_axe_cull_drow_475.lua',
        { arm = { [CAND] = true } })
    for n = 0, 6 do
        local s, a = Xs.axe_IsLanePushCrowdOpen(n), Xa.axe_IsLanePushCrowdOpen(n)
        assert(not (s and not a),
            'ally count ' .. n .. ': shipped admits and armed refuses')
    end
end

-- ===========================================================================
-- §5  CENSUS -- THE CLAIMS IN THE HEADER, COUNTED
-- ===========================================================================

tests['5.1 the branch already carries its own mana rationer and safety term'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, 'ConsiderQ'))
    local at = body:find('X.axe_IsLanePushCrowdOpen(', 1, true)
    assert(at, 'the 带线 call site left X.ConsiderQ')
    local from = body:sub(1, at):match('.*()if ')
    local chunk = body:sub(from, at + 400)
    assert(chunk:find('J.IsAllowedToSpam( bot, nManaCost )', 1, true),
        'the 带线 branch lost J.IsAllowedToSpam -- the header argues the cap '
        .. 'is not a mana policy BECAUSE this conjunct is already there')
    assert(chunk:find('#hEnemyList == 0', 1, true),
        'the 带线 branch lost `#hEnemyList == 0` -- the header argues the cap '
        .. 'refuses a GROUPED PUSH rather than a fight BECAUSE this conjunct '
        .. 'is already there.  Without it the whole (c) argument is void.')
end

tests['5.2 the list the cap is fed is still the 1600u one'] = function()
    assert(SRC_CODE:find('hAllyList = J.GetAlliesNearLoc( bot:GetLocation(), '
        .. ALLY_RADIUS .. ' )', 1, true),
        'hAllyList is no longer J.GetAlliesNearLoc( bot:GetLocation(), '
        .. ALLY_RADIUS .. ' ) -- §2.3 measured the RADIUS dead at '
        .. ALLY_RADIUS .. '; if it moved, that measurement is stale')
end

tests['5.3 nothing else on the branch moved'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, 'ConsiderQ'))
    for _, term in ipairs({
        'J.IsPushing( bot )', 'J.IsDefending( bot )', 'J.IsFarming( bot )',
        'bot:GetAttackTarget() ~= nil', 'X.axe_IsLanePushClockOpen()',
        '#hEnemyList == 0', '#laneCreepList >= 4',
        'J.IsGlyphVetoClear( laneCreepList )',
    }) do
        assert(body:find(term, 1, true),
            'the 带线 branch lost `' .. term .. '` -- this lever moves ONE '
            .. 'conjunct and LIMIT 5 says so')
    end
end

-- ===========================================================================
-- §6  THE BRANCH-LEVEL ZERO, AND WHY IT IS SELECTION AND NOT RARITY
-- ===========================================================================

tests['6.1 `#hEnemyList == 0` is absent from this corpus by construction'] = function()
    -- LIMIT 2.  These frames were harvested to study Call and Culling Blade
    -- DECISIONS -- moments with enemies present.  A corpus of fight instants
    -- cannot size a no-enemy lane-push branch, and "rare" would be the wrong
    -- word for "absent from this sample".
    local rows = loaded_axe_frames()
    local quiet, quiet_moved = 0, 0
    for _, row in ipairs(rows) do
        if row.enemy == 0 then
            quiet = quiet + 1
            if row.ally > SHIPPED and row.ally <= TURBO then
                quiet_moved = quiet_moved + 1
            end
        end
    end
    assert(quiet <= 2, 'the corpus now carries ' .. quiet .. ' Axe instants '
        .. 'with no enemy hero inside ' .. ALLY_RADIUS .. 'u.  That is GOOD '
        .. 'NEWS and this assertion is the flag: re-read §6, the selection '
        .. 'argument may no longer be the right description.')
    assert(quiet_moved == 0, 'a no-enemy Axe instant now sits inside ('
        .. SHIPPED .. ', ' .. TURBO .. '] allies -- the BRANCH-LEVEL domain of `'
        .. CAND .. '` is no longer 0 and this file owes a branch-level reading '
        .. 'instead of a conjunct-level one.')
end

-- ===========================================================================
-- §7  INDEPENDENCE FROM `axecallclock` -- BOTH DIRECTIONS
-- ===========================================================================

tests['7.1 arming the sibling alone does not fire this conjunct'] = function()
    local PIN = STAGED_DIR .. '/f_260909_215412_axe_cull_cm_838.lua'
    local J, bot = world(PIN, { arm = {} })
    local n = ally_count(J, bot)
    local _, _, X = world(PIN, { arm = { [SIB] = true } })
    assert(X.axe_IsLanePushCrowdOpen(n) == false,
        'arming ' .. SIB .. ' alone moved THIS conjunct -- the two ids are '
        .. 'entangled and neither wave reading would be attributable')
end

tests['7.2 arming this id alone does not move the sibling clock'] = function()
    local PIN = STAGED_DIR .. '/f_260909_215412_axe_cull_viper_348.lua'
    local _, _, Xs = world(PIN, { arm = {} })
    local _, _, Xa = world(PIN, { arm = { [CAND] = true } })
    assert(Xs.axe_IsLanePushClockOpen() == Xa.axe_IsLanePushClockOpen(),
        'arming ' .. CAND .. ' moved X.axe_IsLanePushClockOpen -- the pullcad '
        .. 'trap, from the other side')
    assert(Xa.axe_IsLanePushClockOpen() == false,
        'this pin was chosen because the SHIPPED clock refuses it (t=348.0, '
        .. 'inside the 6:00 curfew): it is the one instant this lever moves '
        .. 'that the branch would still refuse on the clock, and LIMIT 4 says '
        .. 'so rather than counting it twice')
end

tests['7.3 the sibling helper does not name this id either'] = function()
    local body = strip_comments(fn_body(SRC_TEXT, 'axe_IsLanePushClockOpen'))
    assert(not body:find(CAND, 1, true),
        'X.axe_IsLanePushClockOpen names ' .. CAND .. ' -- the pullcad trap: '
        .. 'the day one id is promoted the other gate freezes FALSE and '
        .. 'check_armed_wiring.py would still call it WIRED')
end

return tests

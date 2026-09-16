-- tests/test_axe_q_lane_push_nocap.lua
--
-- Soak candidate `axecallnocap` (Axe, turbo-only, INERT until armed) -- whether
-- X.ConsiderQ's 带线 (lane-push) firing point should carry an ally-crowd cap
-- AT ALL.  Real frames via tests/mock/replay_fixture.lua; the real jmz_func
-- helpers run on the real frame.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
-- The 带线 branch taunts a >= 4 creep lane wave onto Axe so Counter Helix spins
-- it down.  Shipped refuses whenever `#hAllyList > 2`; `axecallcrowd` raises
-- that cap to 4, which is the largest cap that still leaves the conjunct a
-- refusal to make.  The state it keeps refusing is the FULL FIVE-MAN STACK
-- standing in a lane wave with no enemy hero inside 1600u -- the single most
-- unambiguous grouped push the game can present, and the one docs/PROJECT.md
-- names as paying off MORE in Turbo ("weaker towers, shorter games, grouped
-- pushing pays off more").  `axecallcrowd`'s own header wrote this down as the
-- second question and deliberately did not answer it.  This id answers it by
-- removing the conjunct instead of moving it.
--
-- §0.1  THE COOLDOWN RATIONALE, AND WHY IT POINTS THE OTHER WAY
-- Berserker's Call costs a real cooldown (AbilityCooldown 18/16/14/12 --
-- §5.2 reads it off tests/mock/special_value_shapes.lua rather than re-typing
-- it), so spending it on a creep wave seconds before a fight is a genuine
-- cost, and "five allies grouped, no enemy in view" is a plausible pre-contact
-- state.  That is the one rationale `axecallcrowd` did not have to rule out.
-- But the shipped cap does not ration the cooldown, it rations it BACKWARDS:
-- shipped fires at `<= 2` -- Axe alone or with one ally, the state most likely
-- to be jumped and therefore most likely to need Call for a fight -- and
-- refuses at four allies, the safest state on the board.  A cooldown argument
-- that holds against five allies holds STRICTLY HARDER against one.
--
-- §0.2  DIRECTION -- THIS IS A WIDENING, and it is the first thing to know
-- Armed, the conjunct is the constant true, so this id is a strict SUPERSET of
-- BOTH legs it sits above: of shipped `<= 2` and of `axecallcrowd`'s `<= 4`.
-- Arming can only ADD 带线 taunts; it can never remove one or move one onto a
-- different target.  §4.1 drives that over every Axe instant in the corpus and
-- §4.2 drives it again over the whole value range 0..6, which the corpus
-- cannot supply on its own.  A negative wave reading is attributable to "those
-- grouped lane-push taunts were not worth the cooldown" and NEVER to a cast
-- this lever refused.
--
-- §0.3  REPRODUCE
--   lua5.1 tests/run_tests.lua axe_q_lane_push_nocap
--   bash tools/agent/mutstand_axecallnocap.sh
--
-- §0.4  LIMITS (each one has an assertion below)
--   1. CONJUNCT-LAYER DOMAIN, as the number it is (§3.1): over the 16
--      Axe-subject instants, shipped admits 11, `axecallcrowd` armed admits 15,
--      this id armed admits 16.  So it moves 5 against shipped and exactly ONE
--      against `axecallcrowd` -- f_260828_124358_axe_cull_promise (t=1452.8,
--      all five allies alive inside 1600u).
--   2. ⛔ THAT SEPARATING FRAME SEPARATES THE TWO IDS AT THE CONJUNCT LAYER
--      ONLY (§3.2): at that instant there is 1 enemy hero inside 1600u, so
--      `#hEnemyList == 0` on the same `if` refuses the branch whatever this
--      conjunct answers.  The corpus contains ZERO frames where this id
--      changes what Axe does; quoting the "1" as a behaviour difference would
--      be an execution verification out of thin air.
--   3. ⛔ BRANCH-LEVEL DOMAIN = 0, and the reason is SELECTION not rarity
--      (§6.1).  Identical to `axecallcrowd`'s bound 3 and it does not get to be
--      counted as new evidence here: `#hEnemyList == 0` holds on exactly 1 of
--      the 16 instants, because these frames were harvested to study Call and
--      Culling Blade DECISIONS, i.e. moments with enemies present.  The wave
--      question is iterations/queue.json hero-94.
--   4. ⛔ END-TO-END DOMAIN = 0 and cannot be anything else today (§3.4): the
--      branch also needs `#laneCreepList >= 4` and the dumped corpus carries
--      no non-hero units at all (GH #772).
--   5. ⛔ NOT a bundle with `axecallcrowd`, and the reason is stronger than
--      one-lever-at-a-time: this id DOMINATES it (§7.4).  Armed, the
--      disjunction short-circuits true before the cap is consulted, so a wave
--      arming both measures THIS id alone under two names.  Also not a bundle
--      with `axecallclock` (§7.1-§7.3).
--   6. CORPUS FLOOR: the counts above are over 16 Axe-subject instants.  §2.1
--      asserts the floor so a shrinking corpus reds instead of quietly
--      re-basing every number in this file.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_axe.lua'
local KV     = 'tests/mock/special_value_shapes.lua'
local CAND   = 'axecallnocap'
local CAP    = 'axecallcrowd'
local CLOCK  = 'axecallclock'
local UNIT   = 'npc_dota_hero_axe'
local HELPER = 'axe_IsLanePushCrowdCapOff'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

--- The radius `hAllyList` / `hEnemyList` are built with at hero_axe.lua:425-426.
--- §5.3 reads it off the source rather than trusting it here.
local ALLY_RADIUS = 1600

--- The one instant that separates this id from `axecallcrowd`.
local SEPARATOR = STAGED_DIR .. '/f_260828_124358_axe_cull_promise.lua'

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

--- ⭐ THE CAPS ARE READ OFF THE SOURCE, never re-typed (the stale-mirror
--- family, tests/test_cast_ring_mirror_discipline.lua).
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

--- Every instant whose SUBJECT is Axe.  The cap reads a list built around the
--- SUBJECT's own location, so restricting to Axe-subject frames is what makes
--- the counts below statements about THIS hero.
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

--- ⭐ THE CALL SITE'S OWN EXPRESSION.  This is not a free-floating mirror:
--- §1.2 asserts that the source really is this two-term disjunction, in this
--- order, with nothing else in the parentheses.  If the source shape moves,
--- §1.2 reds before any number in this file can be read off a stale copy.
local function call_site(X, nAllyCount)
    return X.axe_IsLanePushCrowdOpen(nAllyCount) or X.axe_IsLanePushCrowdCapOff()
end

--- ⭐ THE ALLY COUNT COMES FROM THE REAL HELPER ON THE REAL FRAME, not from a
--- re-implementation of the distance loop in this file.
local function ally_count(J, bot, nRadius)
    return #J.GetAlliesNearLoc(bot:GetLocation(), nRadius or ALLY_RADIUS)
end

local LOADED = nil
local function loaded_axe_frames()
    if LOADED then return LOADED end
    LOADED = {}
    for _, fr in ipairs(axe_subject_paths()) do
        local J, bot = world(fr.path, {})
        LOADED[#LOADED + 1] = {
            path  = fr.path,
            t     = fr.t,
            ally  = ally_count(J, bot),
            enemy = #J.GetNearbyHeroes(bot, ALLY_RADIUS, true, BOT_MODE_NONE),
        }
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
    -- is promoted, and check_armed_wiring.py would still call it WIRED.
    for id in body:gmatch("IsSoakCandidate%( '([%w_]+)' %)") do
        assert(id == CAND,
            HELPER .. ' names a second id ' .. id .. ' -- the pullcad trap')
    end
end

tests['1.2 the call site is the two-term disjunction, cap first'] = function()
    -- The shape `call_site()` above depends on, and the shape that makes the
    -- gate-off collapse literal rather than argued.
    local want = 'and ( X.axe_IsLanePushCrowdOpen( #hAllyList )\n'
              .. '\t\t\t\tor X.axe_IsLanePushCrowdCapOff() )'
    assert(SRC_CODE:find(want, 1, true),
        'the 带线 call site is no longer `X.axe_IsLanePushCrowdOpen( #hAllyList )'
        .. ' or X.axe_IsLanePushCrowdCapOff()`.  Every domain number in this '
        .. 'file is a statement about THAT expression; if the source shape '
        .. 'moved, re-derive them instead of re-reading this file.')
    assert(count(SRC_CODE, 'X.axe_IsLanePushCrowdCapOff(') == 2,
        'expected exactly two X.axe_IsLanePushCrowdCapOff( occurrences in code '
        .. '(the definition and the single call site), got '
        .. count(SRC_CODE, 'X.axe_IsLanePushCrowdCapOff('))
    assert(not SRC_CODE:find('#hAllyList <= 2', 1, true),
        'the literal `#hAllyList <= 2` is back in the code -- a second copy of '
        .. 'the cap defeats both this id and ' .. CAP)
end

tests['1.3 the id appears in bots/ exactly once, inside the helper'] = function()
    assert(count(SRC_CODE, CAND) == 1,
        CAND .. ' appears ' .. count(SRC_CODE, CAND) .. ' times in ' .. SRC
        .. ' code; it must appear exactly once')
end

-- ===========================================================================
-- §2  THE SHAPE OF "NO CAP", AND WHAT GATE-OFF COLLAPSES TO
-- ===========================================================================

tests['2.1 corpus floor -- every count in this file rests on it'] = function()
    local rows = loaded_axe_frames()
    assert(#rows >= 16, 'Axe-subject corpus shrank to ' .. #rows
        .. ' instants (FLOOR, LIMIT 6).  The 11 / 15 / 16 in §3.1 are '
        .. 'statements about 16 frames; re-measure, do not re-base.')
end

tests['2.2 armed this conjunct is the constant true -- no cap survives'] = function()
    -- Driven, not argued: there must be NO ally count the armed leg refuses.
    local _, _, Xa = world(SEPARATOR, { arm = { [CAND] = true } })
    for n = 0, 12 do
        assert(Xa.axe_IsLanePushCrowdCapOff() == true,
            'the armed leg answered false -- this id is supposed to DELETE the '
            .. 'conjunct, so any false makes it a third cap and every '
            .. 'superset claim in §0.2 wrong')
        assert(call_site(Xa, n) == true,
            'armed, the call site refused ally count ' .. n .. ' -- a cap '
            .. 'survived the deletion')
    end
end

tests['2.3 gate off the helper is `false`, so the cap alone decides'] = function()
    local _, _, Xs = world(SEPARATOR, { arm = {} })
    assert(Xs.axe_IsLanePushCrowdCapOff() == false,
        'gate off ' .. HELPER .. ' answered true -- it is not inert, and the '
        .. 'shipped 带线 behaviour has changed in every real game')
    for n = 0, 12 do
        assert(call_site(Xs, n) == (n <= SHIPPED),
            'gate off, the call site answered ' .. tostring(call_site(Xs, n))
            .. ' at ally count ' .. n .. ' -- it must be exactly `#hAllyList <= '
            .. SHIPPED .. '`, byte-for-byte shipped behaviour')
    end
end

tests['2.4 non-turbo is inert even with the id armed'] = function()
    local _, _, Xn = world(SEPARATOR, { arm = { [CAND] = true }, nonTurbo = true })
    assert(Xn.axe_IsLanePushCrowdCapOff() == false,
        'armed but NOT turbo, ' .. HELPER .. ' answered true -- a soak '
        .. 'candidate must be turbo-only, and this one would be live in every '
        .. 'all-pick game the moment the id is armed anywhere')
end

-- ===========================================================================
-- §3  REAL FRAMES -- THE CONJUNCT-LAYER DOMAIN, AND WHAT IT IS NOT
-- ===========================================================================

tests['3.1 the three domains, as the numbers they are'] = function()
    local rows = loaded_axe_frames()
    local ship, cap, nocap = 0, 0, 0
    for _, row in ipairs(rows) do
        local _, _, Xs = world(row.path, { arm = {} })
        local _, _, Xc = world(row.path, { arm = { [CAP] = true } })
        local _, _, Xn = world(row.path, { arm = { [CAND] = true } })
        if call_site(Xs, row.ally) then ship  = ship  + 1 end
        if call_site(Xc, row.ally) then cap   = cap   + 1 end
        if call_site(Xn, row.ally) then nocap = nocap + 1 end
    end
    assert(nocap == #rows, 'the armed leg admits ' .. nocap .. ' of ' .. #rows
        .. ' instants; deleting the conjunct must admit ALL of them')
    assert(ship == 11, 'shipped admits ' .. ship .. ' Axe instants, not the 11 '
        .. 'this file and state.json:axecallnocap_20260916 report')
    assert(cap == 15, CAP .. ' armed admits ' .. cap .. ' Axe instants, not the '
        .. '15 reported.  If the cap moved, LIMIT 1 moved with it.')
    assert(nocap - cap == 1, 'this id now moves ' .. (nocap - cap)
        .. ' instants against ' .. CAP .. ', not the 1 LIMIT 1 reports.  That '
        .. 'is NEWS about the corpus, not a number to overwrite.')
end

tests['3.2 ⛔ the separating frame, and why it is not a behaviour difference'] = function()
    -- LIMIT 2, kept executable.  This is the assertion that stops the "1" in
    -- §3.1 from being quoted as an execution verification.
    local rows = loaded_axe_frames()
    local sep = nil
    for _, row in ipairs(rows) do
        if row.path == SEPARATOR then sep = row end
    end
    assert(sep ~= nil, 'the separating frame ' .. SEPARATOR .. ' left the '
        .. 'corpus -- §3.1\'s "1" then has no carrier and LIMIT 1 is unsourced')
    assert(sep.ally == 5, SEPARATOR .. ': ' .. sep.ally .. ' allies inside '
        .. ALLY_RADIUS .. 'u, not the five-man stack this id is about.  It is '
        .. 'the ONLY instant that separates this id from ' .. CAP .. ', and it '
        .. 'separates them because 5 > ' .. TURBO .. '.')
    assert(sep.ally > TURBO, 'the separating frame no longer exceeds the armed '
        .. 'cap ' .. TURBO .. ' -- the two ids are then indistinguishable on '
        .. 'this corpus and LIMIT 1 must say so')
    assert(sep.enemy == 1, SEPARATOR .. ': ' .. sep.enemy .. ' enemy heroes '
        .. 'inside ' .. ALLY_RADIUS .. 'u.  LIMIT 2 rests on this being NON-ZERO: '
        .. '`#hEnemyList == 0` on the same `if` refuses the branch here whatever '
        .. 'this conjunct answers, so the corpus has ZERO frames where this id '
        .. 'changes what Axe DOES.  If this reads 0, that is NEWS -- the corpus '
        .. 'finally carries a branch-layer carrier and LIMIT 2 must be rewritten '
        .. '(not relaxed).')
end

tests['3.3 the five instants this lever moves against shipped'] = function()
    -- One world per arm set, for the reason §4.1 gives.
    local rows = loaded_axe_frames()
    local _, _, Xs = world(SEPARATOR, { arm = {} })
    local _, _, Xn = world(SEPARATOR, { arm = { [CAND] = true } })
    local moved = {}
    for _, row in ipairs(rows) do
        if call_site(Xn, row.ally) and not call_site(Xs, row.ally) then
            moved[#moved + 1] = row.path
        end
    end
    assert(#moved == 5, 'this lever moves ' .. #moved .. ' instants against '
        .. 'shipped, not the 5 LIMIT 1 reports')
    local named = {
        [STAGED_DIR .. '/f_260909_215412_axe_cull_viper_348.lua'] = true,
        [STAGED_DIR .. '/f_260909_215412_axe_cull_cm_415.lua']    = true,
        [STAGED_DIR .. '/f_260909_215412_axe_cull_cm_838.lua']    = true,
        [STAGED_DIR .. '/f_260831_061811_axe_call_tp_channel.lua'] = true,
        [SEPARATOR] = true,
    }
    for _, p in ipairs(moved) do
        assert(named[p], p .. ' is a mover this file does not name.  Four of '
            .. 'the five are ' .. CAP .. '\'s movers and the fifth is the '
            .. 'separating frame; a sixth name means the corpus changed.')
    end
end

tests['3.4 ⛔ the end-to-end domain is 0 and cannot be anything else'] = function()
    -- LIMIT 4.  The branch needs `#laneCreepList >= 4` and the corpus carries
    -- no non-hero units (GH #772).  Asserted here so nobody quotes §3.1's
    -- conjunct-layer numbers as taunts that would actually happen.
    local nonHero = 0
    for _, fr in ipairs(axe_subject_paths()) do
        local fx = frame(fr.path)
        for _, u in ipairs((fx and fx.units) or {}) do
            if u.unit_name ~= nil and not tostring(u.unit_name):find('^npc_dota_hero_') then
                nonHero = nonHero + 1
            end
        end
    end
    assert(nonHero == 0, 'the corpus now carries ' .. nonHero .. ' non-hero '
        .. 'unit row(s) on Axe-subject frames.  That is NEWS (GH #772): the '
        .. 'end-to-end domain becomes measurable and LIMIT 4 must be replaced '
        .. 'by a measurement rather than relaxed.')
end

-- ===========================================================================
-- §4  DIRECTION, DRIVEN RATHER THAN ARGUED
-- ===========================================================================

tests['4.1 strict superset of shipped over the whole corpus'] = function()
    -- ⚠️ ONE world per arm set, not one per frame: both helpers are PURE in
    -- nAllyCount, and the frame's only contribution is that count -- which
    -- loaded_axe_frames() already took off the real loader.  §3.1 is the
    -- section that pays for a per-frame load of every leg; repeating it here
    -- buys nothing and costs this file its place in the push gate (GH #624).
    local rows = loaded_axe_frames()
    local _, _, Xs = world(SEPARATOR, { arm = {} })
    local _, _, Xn = world(SEPARATOR, { arm = { [CAND] = true } })
    for _, row in ipairs(rows) do
        if call_site(Xs, row.ally) then
            assert(call_site(Xn, row.ally), row.path .. ': shipped admits and '
                .. 'armed refuses -- that is a NARROWING, and every direction '
                .. 'claim in this file and in the header is wrong')
        end
    end
end

tests['4.2 strict superset of BOTH legs over the whole value range'] = function()
    -- The corpus can only supply the counts it happens to contain, so the
    -- direction claim is driven again over 0..6 (a five-man team plus slack).
    local _, _, Xs = world(SEPARATOR, { arm = {} })
    local _, _, Xc = world(SEPARATOR, { arm = { [CAP] = true } })
    local _, _, Xn = world(SEPARATOR, { arm = { [CAND] = true } })
    for n = 0, 6 do
        if call_site(Xs, n) then
            assert(call_site(Xn, n), 'ally count ' .. n
                .. ': shipped admits, this id refuses -- not a superset')
        end
        if call_site(Xc, n) then
            assert(call_site(Xn, n), 'ally count ' .. n .. ': ' .. CAP
                .. ' armed admits, this id refuses -- not a superset of the '
                .. 'sibling either, and LIMIT 5\'s domination argument is void')
        end
    end
end

-- ===========================================================================
-- §5  CENSUS -- THE CLAIMS IN THE HEADER, COUNTED
-- ===========================================================================

tests['5.1 mana and safety are already conjuncts of the same `if`'] = function()
    -- §0's "the cap is not a mana policy and not a safety term" is a claim
    -- about the source, so it is counted here rather than asserted in prose.
    local from = SRC_CODE:find('X.axe_IsLanePushCrowdCapOff() )', 1, true)
    assert(from, 'the call site moved -- see §1.2')
    local window = SRC_CODE:sub(math.max(1, from - 700), from + 200)
    assert(window:find('J.IsAllowedToSpam( bot, nManaCost )', 1, true),
        'J.IsAllowedToSpam left the 带线 `if` -- the header argues the cap is '
        .. 'not a mana rationer BECAUSE a mana rationer is already there.  '
        .. 'With it gone, that argument has to be rewritten.')
    assert(window:find('#hEnemyList == 0', 1, true),
        '`#hEnemyList == 0` left the 带线 `if` -- it is what makes this branch '
        .. 'a PUSH rather than a fight, and both the safety argument (§0) and '
        .. 'LIMIT 2 rest on it being a conjunct here')
end

tests['5.2 the cooldown numbers in §0.1 are read off the KV, not typed'] = function()
    local kv = read_file(KV)
    local blk = kv:match("%['axe_berserkers_call'%](.-)\n%s*},\n")
    assert(blk, "the axe_berserkers_call KV block is gone from " .. KV
        .. ' -- §0.1 quotes its cooldown and now has no source')
    local cd = blk:match("%['AbilityCooldown'%]%s*=%s*{%s*base%s*=%s*'([^']+)'")
    assert(cd == '18 16 14 12', "Berserker's Call AbilityCooldown reads '"
        .. tostring(cd) .. "' in " .. KV .. ", not the '18 16 14 12' §0.1 "
        .. 'quotes.  The cooldown-rationing argument is about real seconds; '
        .. 'move the prose with the number.')
end

tests['5.3 the 1600u ring is the same ring for allies and enemies'] = function()
    -- LIMIT 2 and §0's safety argument both need `#hEnemyList == 0` to be
    -- measured over the SAME radius the cap counts allies over.  Read off the
    -- source, because a divergence would make the two conjuncts talk past
    -- each other without either line changing.
    local a = SRC_CODE:match('hAllyList%s*=%s*J%.GetAlliesNearLoc%([^\n]-,%s*(%d+)%s*%)')
    local e = SRC_CODE:match('hEnemyList%s*=%s*J%.GetNearbyHeroes%(bot,%s*(%d+),')
    assert(tonumber(a) == ALLY_RADIUS, 'hAllyList is now built with radius '
        .. tostring(a) .. ', not ' .. ALLY_RADIUS .. ' -- every count in this '
        .. 'file is over the old ring')
    assert(tonumber(e) == ALLY_RADIUS, 'hEnemyList is now built with radius '
        .. tostring(e) .. ' while allies use ' .. ALLY_RADIUS .. '.  The two '
        .. 'conjuncts then describe different rings, and "no enemy in view" '
        .. 'stops being the safety term the cap was supposed to be redundant with.')
end

-- ===========================================================================
-- §6  THE BRANCH-LEVEL ZERO, AND WHY IT IS SELECTION AND NOT RARITY
-- ===========================================================================

tests['6.1 ⛔ `#hEnemyList == 0` holds on 1 of 16 -- selection, not rarity'] = function()
    local rows = loaded_axe_frames()
    local quiet = 0
    for _, row in ipairs(rows) do
        if row.enemy == 0 then quiet = quiet + 1 end
    end
    assert(quiet == 1, 'the no-enemy count is now ' .. quiet .. ' of ' .. #rows
        .. ', not 1.  LIMIT 3 says this corpus CANNOT size a no-enemy '
        .. 'lane-push branch because these frames were harvested for Call / '
        .. 'Culling Blade decisions, i.e. moments with enemies present.  A '
        .. 'change here is NEWS: re-read LIMIT 3, and do not turn "absent from '
        .. 'this sample" into "rare" (that is the step the bound exists to block).')
end

tests['6.2 the one quiet instant is already admitted by shipped'] = function()
    local rows = loaded_axe_frames()
    for _, row in ipairs(rows) do
        if row.enemy == 0 then
            local _, _, Xs = world(row.path, { arm = {} })
            assert(call_site(Xs, row.ally), row.path .. ' is the only instant '
                .. 'where the branch premise holds, and shipped now REFUSES '
                .. 'it.  That would make it a branch-layer carrier for this '
                .. 'lever -- LIMIT 3 would have to be rewritten around it.')
        end
    end
end

-- ===========================================================================
-- §7  INDEPENDENCE FROM THE TWO SIBLINGS ON THE SAME `if`, AND DOMINATION
-- ===========================================================================

tests['7.1 arming a sibling alone does not fire this conjunct'] = function()
    local _, _, Xc = world(SEPARATOR, { arm = { [CAP] = true } })
    local _, _, Xk = world(SEPARATOR, { arm = { [CLOCK] = true } })
    assert(Xc.axe_IsLanePushCrowdCapOff() == false,
        'arming ' .. CAP .. ' alone moved THIS conjunct -- the two ids are '
        .. 'entangled and neither wave reading would be attributable')
    assert(Xk.axe_IsLanePushCrowdCapOff() == false,
        'arming ' .. CLOCK .. ' alone moved THIS conjunct -- same defect, '
        .. 'other sibling')
end

tests['7.2 arming this id alone does not move either sibling'] = function()
    local _, _, Xs = world(SEPARATOR, { arm = {} })
    local _, _, Xa = world(SEPARATOR, { arm = { [CAND] = true } })
    assert(Xs.axe_IsLanePushClockOpen() == Xa.axe_IsLanePushClockOpen(),
        'arming ' .. CAND .. ' moved X.axe_IsLanePushClockOpen -- the pullcad '
        .. 'trap, from the other side')
    assert(Xs.axe_IsLanePushCrowdOpen(5) == Xa.axe_IsLanePushCrowdOpen(5),
        'arming ' .. CAND .. ' moved X.axe_IsLanePushCrowdOpen -- this id is '
        .. 'supposed to sit BESIDE the cap in a disjunction, not inside it')
end

tests['7.3 neither sibling helper names this id'] = function()
    for _, name in ipairs({ 'axe_IsLanePushCrowdOpen', 'axe_IsLanePushClockOpen' }) do
        local body = strip_comments(fn_body(SRC_TEXT, name))
        assert(not body:find(CAND, 1, true),
            'X.' .. name .. ' names ' .. CAND .. ' -- the pullcad trap: the '
            .. 'day one id is promoted the other gate freezes FALSE and '
            .. 'check_armed_wiring.py would still call it WIRED')
    end
end

tests['7.4 ⛔ this id DOMINATES the cap -- arming both measures this one'] = function()
    -- LIMIT 5, kept executable.  If the disjunction ever stops dominating,
    -- the "never arm both" instruction is over-strict and should be reread --
    -- but until then a wave arming both carries two names for one measurement.
    -- One world per arm set, for the reason §4.1 gives.
    local rows = loaded_axe_frames()
    local _, _, Xn = world(SEPARATOR, { arm = { [CAND] = true } })
    local _, _, Xb = world(SEPARATOR, { arm = { [CAND] = true, [CAP] = true } })
    for _, row in ipairs(rows) do
        assert(call_site(Xn, row.ally) == call_site(Xb, row.ally),
            row.path .. ': arming ' .. CAP .. ' on top of ' .. CAND
            .. ' changed the answer.  LIMIT 5 claims it cannot -- re-read it '
            .. 'before changing this assertion.')
        assert(call_site(Xb, row.ally) == true,
            row.path .. ': both armed and the call site refused -- the '
            .. 'domination claim rests on the armed leg being constant true')
    end
end

return tests

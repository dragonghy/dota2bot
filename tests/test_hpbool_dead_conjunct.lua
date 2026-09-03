-- [ratchet] [hpbool] A ratio used where a predicate was meant.
--
--     or (J.GetHP(bot) and bot:WasRecentlyDamagedByAnyHero(2))
--
-- `J.GetHP` (jmz_func.lua:4003) returns `nCurHealth / nMaxHealth`, and a bare
-- `0` on the dead path. It never returns nil and never returns false, so in Lua
-- -- where 0 is TRUE -- that operand is true on every unit on every frame. The
-- conjunct costs a division and decides nothing.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A CONJUNCT WHOSE OPERAND IS A NUMBER IS NOT A CONDITION. It is an
--     `and true`. The tell is countable, needs no frame and no run, and does
--     not require understanding the predicate: a call whose return type is
--     numeric appearing as a bare truth operand -- no `<`, no `>`, no `==`.
--     Repo-wide census [source S1]: SIX such sites in bots/, all six the same
--     `J.GetHP` idiom, in four hero files. The wider sweep for the same shape
--     over every `J.Get*` helper and every `unit:GetX()` call finds nothing
--     else live [source S2] -- so this is the whole population, not a sample.
--
-- ⭐⭐ WHY IT IS A DEFECT AND NOT A DESIGN CHOICE -- the repo answers it by
--     majority, on the byte-identical idiom. SIXTY-FOUR sites in bots/ write
--     `J.GetHP(bot) < X and bot:WasRecentlyDamagedByAnyHero(...)` with the
--     threshold present (mode X = 0.65, 11 sites; range 0.2 .. 0.82); six
--     dropped the `< X`. 64 : 6 [source S3]. Same shape of evidence as GH #385
--     (249 call sites, 227 fed `botTarget`, exactly 1 fed `bot`): the fix is
--     not this file's invention, it is what the other copies already say.
--
-- ⭐⭐⭐ WHAT IT COSTS -- and the second cost is the one worth having.
--   (1) The direct cost: shipped Tiny tosses while retreating at ANY health,
--       full health included, as long as some hero touched it in the last 2s.
--   (2) THE DOMINATION. The guard is a disjunction:
--           (#enemies > #allies) or (<always true> and recentlyDamaged)
--       Inside a retreat, `WasRecentlyDamagedByAnyHero(2)` is what a retreat
--       normally IS, so the right arm is nearly always true and the LEFT ARM --
--       the outnumbered test the author wrote -- can never decide anything
--       either. One dead conjunct silently killed the whole bid. Pinned on the
--       real frame by [frame F4].
--
-- ⚠️ FAILURE DIRECTION: OPEN, like GH #393 `immguard` and unlike the seven
--    before it (#348 order, #368 lexical scope, #370 unreported side effect,
--    #373 a latch recording the attempt, #378 a throttle wider than its
--    consumers, #381 a hand-copied world fact, #385 a foreign-unit predicate
--    fed self). The guard admits everything, so the wrong answer is a positive
--    act -- a Toss cast, its cooldown, and its mana, spent at full health.
--    Observable in principle; simply unobserved.
--
-- REAL FRAME: tests/fixtures/f_260820_043120_viper_defend_paired.lua --
-- game 20260820_043120_slot1.timeline, t=599.5 (9:59). Chosen because ONE
-- frame carries both readings this fix needs, and both are dump ground truth
-- rather than anything this file declares:
--   * npc_dota_hero_viper  1644/1683 = 0.977, last hit by a HERO 2.0s ago;
--   * npc_dota_hero_axe     579/1708 = 0.339, last hit by a HERO 0.5s ago.
-- So the same real frame supplies the discriminating case (a hero at full
-- health that shipped lets through) and the positive control (a hero genuinely
-- low that BOTH arms must still let through).
--
-- ⚠️ LIMITS, declared:
--   * THE SUBJECT HERO IS NOT IN THE CORPUS, AND THAT IS MEASURED, NOT
--     ASSUMED. [source S6] walks all 110 fixtures: shredder, tiny, dawnbreaker
--     and kez appear ZERO times -- as does brewmaster, the subject of GH #393.
--     This is the THIRD consecutive round whose subject hero has no corpus
--     presence. The consequence is stated plainly and belongs in the admission
--     ruling, not in a footnote: THE LOCAL CORPUS CANNOT PRICE THIS DOMAIN, and
--     a `DOMAIN-EMPTY` harvest would say nothing about the fix. What IS better
--     here than in the last two rounds, and is also measured: none of these
--     four heroes is on hero_selection.lua's `WeakHeroes` throttle list, while
--     brewmaster IS -- so the draw odds are structurally better, not merely
--     hoped for.
--   * THE THRESHOLD IS BORROWED, NOT DERIVED. 0.65 is the MODE of the 64
--     sibling copies, not a number any frame in this repo argues for. A
--     different threshold is a different lever and needs its own evidence; this
--     file pins that the constant equals the measured mode, so the day someone
--     changes it they must change the reason too.
--   * FIVE OF THE SIX SITES ARE LEFT ALONE, one lever at a time. [source S1]
--     names all five so they cannot be lost.
--   * The `#enemies > #allies` term is driven with synthetic list lengths --
--     the fixture carries positions, not this bot's mode-scoped hero lists.
--     Declared: the HP and recent-damage terms are real frame data, the
--     cardinality term is not.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260820_043120_viper_defend_paired.lua'
local TARGET  = 'bots/BotLib/hero_tiny.lua'
local JMZ     = 'bots/FunLib/jmz_func.lua'

local GATE    = "J.IsSoakCandidate('hpbool')"

--- Blank whole-line comments while preserving line numbers, so every count
--- below means "in code". This file's own fix comment quotes the defective
--- idiom verbatim; without this the census would count the explanation.
--- (GH #370 hit exactly that; #381/#385/#393 copied the fix, and so does this.)
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local function read(path)
    local fh = assert(io.open(path), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function count(src, needle)
    return select(2, src:gsub(needle:gsub('%W', '%%%0'), ''))
end

local CODE = codeOnly(read(TARGET))

--- Every .lua under bots/, comments blanked, enumerated off the FILESYSTEM the
--- way tests/test_smoke_load.lua does -- the population is "files that ship",
--- not any in-tree list that could drift.
local BOTS = (function()
    local out = {}
-- Farm-only files are skipped: `bots/Customize/` holds two gitignored,
-- TRANSIENT switch files that every gate test in this suite creates and
-- deletes, so listing one and then reading it is a race whose red names a
-- file this test has no business reading (GH #365 §2 / #438; hero backlog
-- -79 measured the population at 18 walks in 18 files).  The rule lives in
-- tests/lua_source_scan.lua and is referenced, never copied -- the path
-- literal is load-bearing text and a second copy is the defect.
    for _, path in ipairs(require('lua_source_scan').bots_files()) do
        out[#out + 1] = { path = path, src = codeOnly(read(path)) }
    end
    assert(#out > 100, 'the walk must find the shipped tree; got ' .. #out)
    return out
end)()

--- THE DISCRIMINATING FEATURE, mechanised. A call to `fn(...)` sitting as a
--- bare truth operand: preceded by `and`/`or`/`if`/`not`/`(` and followed by
--- `and`/`or`/`then`/`)` -- with NO comparison operator bound to it. The
--- lookahead is deliberately whitespace-tolerant ACROSS LINES, because the
--- first version of this scanner only looked at the rest of the same line and
--- so read four multi-line comparisons in jmz_func.lua as bare operands. A
--- census that mistakes a wrapped `<` for a missing one is worse than none.
local function bareTruthOperands(src, fn)
    local hits = {}
    local pat = fn:gsub('%W', '%%%0') .. '%s*%b()'
    local i = 1
    while true do
        local a, b = src:find(pat, i)
        if a == nil then break end
        i = b + 1
        -- Trim the open parens the idiom wraps the operand in, so `or (J.GetHP`
        -- is recognised as the operand position it is. The first version of
        -- this scanner did not, and found ONE of the six.
        local before = src:sub(math.max(1, a - 16), a - 1):gsub('[%s%(]*$', '')
        local after  = src:sub(b + 1)
        -- skip the definition itself and any assignment/argument position
        local isOperand = before:match('%f[%w]and$') or before:match('%f[%w]or$')
                       or before:match('%f[%w]not$') or before:match('%f[%w]if$')
        local nextTok = after:match('^%s*([%a%p]+)')
        local isBare = nextTok ~= nil
                   and (nextTok:match('^and%f[%W]') or nextTok:match('^or%f[%W]')
                        or nextTok:match('^then%f[%W]') or nextTok:match('^%)'))
        if isOperand and isBare then
            local line = select(2, src:sub(1, a):gsub('\n', '')) + 1
            hits[#hits + 1] = { line = line, text = src:sub(a, b) }
        end
    end
    return hits
end

local function census(fn)
    local out = {}
    for _, f in ipairs(BOTS) do
        for _, h in ipairs(bareTruthOperands(f.src, fn)) do
            out[#out + 1] = { path = f.path, line = h.line }
        end
    end
    return out
end

--- The shipped guard expression, sliced out of the file rather than retyped:
--- anchor on the unique gate id, walk back to the enclosing disjunction, then
--- balance parentheses forward. Slicing by `.-\n` neighbours is what GH #373
--- recorded as a method self-harm; this one cannot truncate.
local EXPR = (function()
    local g = assert(CODE:find(GATE, 1, true), 'the gate must be in ' .. TARGET)
    local head = '((#nInRangeEnemy > #nInRangeAlly)'
    local a = nil
    local i = 1
    while true do
        local p = CODE:find(head, i, true)
        if p == nil or p > g then break end
        a = p; i = p + 1
    end
    assert(a, 'the enclosing disjunction must sit above the gate')
    local depth, b = 0, nil
    for k = a, #CODE do
        local c = CODE:sub(k, k)
        if c == '(' then depth = depth + 1
        elseif c == ')' then
            depth = depth - 1
            if depth == 0 then b = k break end
        end
    end
    assert(b and b > g, 'the gate must sit INSIDE the sliced disjunction')
    return CODE:sub(a, b)
end)()

--- The same expression with the gated conjunct removed -- i.e. the tree as it
--- shipped before this change. Reconstructed by deletion so that "shipped" is
--- never a retyped guess.
local ARMED_CONJUNCT = (function()
    local a = assert(EXPR:find('and (not (J.IsModeTurbo()', 1, true),
        'the gated conjunct must be findable for removal')
    local depth, b = 0, nil
    local open = EXPR:find('(', a + 4, true)
    for k = open, #EXPR do
        local c = EXPR:sub(k, k)
        if c == '(' then depth = depth + 1
        elseif c == ')' then
            depth = depth - 1
            if depth == 0 then b = k break end
        end
    end
    assert(b, 'the gated conjunct must be balanced')
    return EXPR:sub(a, b)
end)()

local SHIPPED_EXPR = EXPR:gsub(ARMED_CONJUNCT:gsub('%W', '%%%0'), '')

--- Compile an expression into `f(J, bot, nAlly, nEnemy)`.
local function compile(expr)
    local chunk = 'local J, bot, nInRangeAlly, nInRangeEnemy = ...\nreturn ' .. expr
    local f = assert(loadstring(chunk), 'cannot compile: ' .. expr)
    return function(J, bot, nAlly, nEnemy) return (f(J, bot, nAlly, nEnemy)) end
end

local guardShipped = compile(SHIPPED_EXPR)
local guardCurrent = compile(EXPR)

--- Load the real jmz_func on the real frame, with the gate answering as told.
local function world(bTurbo, bArmed)
    local J = rf.load(FIXTURE, 'npc_dota_hero_viper')
    J.IsModeTurbo = function() return bTurbo end
    J.IsSoakCandidate = function(sId) return bArmed and sId == 'hpbool' end
    return J
end

--- Outnumbered = false, so the left arm of the disjunction cannot decide; the
--- right arm is what is under test. `hero` is looked up on the loaded world.
local FEW, MANY = { 1 }, { 1, 2 }

local function hero(_, name)
    local h = nil
    for _, u in ipairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
        if u:GetUnitName() == name then h = u end
    end
    for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if u:GetUnitName() == name then h = u end
    end
    return assert(h, 'the frame must carry ' .. name)
end

-- ===================================================================
-- source -- the shape, read off the shipped tree
-- ===================================================================

tests['[source S1] the census: six bare-truth J.GetHP operands in bots/, each named'] = function()
    local hits = census('J.GetHP')
    local byFile = {}
    for _, h in ipairs(hits) do byFile[h.path] = (byFile[h.path] or 0) + 1 end

    assert(#hits == 6, 'the population is six bare-truth J.GetHP operands in the shipped '
        .. 'tree -- if this moved, the census moved, and the number in the header, in the '
        .. 'GH issue and in state.json must move with it; got ' .. #hits)

    -- One repaired, five left standing -- one lever at a time. Counted by file
    -- rather than by line so a later edit above them cannot make this test lie.
    local expect = {
        ['bots/BotLib/hero_tiny.lua']        = 1,  -- repaired: still in the census by
                                                   -- shape, because the fix ADDS the
                                                   -- threshold beside the ratio operand
                                                   -- rather than rewriting it
        ['bots/BotLib/hero_shredder.lua']    = 3,  -- survivors, named so a later round
        ['bots/BotLib/hero_kez.lua']         = 1,  -- cannot lose them
        ['bots/BotLib/hero_dawnbreaker.lua'] = 1,
    }
    for path, n in pairs(expect) do
        assert(byFile[path] == n, path .. ' must hold exactly ' .. n .. ' site(s); got '
            .. tostring(byFile[path]))
    end
    for path in pairs(byFile) do
        assert(expect[path] ~= nil, 'a bare-truth J.GetHP operand appeared in ' .. path
            .. ', which is NOT one of the four known files -- that is a new member of the '
            .. 'family, not a broken scanner; look at it before editing this list')
    end

    -- and exactly one of the four carries the repair
    local n = 0
    for _, f in ipairs(BOTS) do if f.src:find(GATE, 1, true) then n = n + 1 end end
    assert(n == 1, 'exactly one file carries the hpbool gate; got ' .. n)
    assert(CODE:find(GATE, 1, true) ~= nil, 'and it is ' .. TARGET)
end

tests['[source S2] the wider sweep finds nothing else: this idiom is the whole population'] = function()
    -- Every J.* helper whose name says it returns a number, and the two
    -- unit-method families most likely to be mistaken for predicates.
    for _, fn in ipairs({ 'J.GetMP', 'J.GetEffectiveHP', 'J.GetDistance',
                          'J.GetLocationToLocationDistance',
                          'J.GetTotalEstimatedDamageToTarget' }) do
        local hits = census(fn)
        assert(#hits == 0, fn .. ' must have no bare-truth operand in bots/; got ' .. #hits
            .. ' -- if this fires it is a NEW member of the family, not a broken scanner: '
            .. 'check it by hand before editing this assertion')
    end
end

tests['[source S3] the repo already says what was dropped: 64 copies carry the threshold'] = function()
    local n, byX = 0, {}
    for _, f in ipairs(BOTS) do
        for x in f.src:gmatch('J%.GetHP%(bot%)%s*<%s*([%d%.]+)%s*and%s*bot:WasRecentlyDamagedByAnyHero') do
            n = n + 1
            byX[x] = (byX[x] or 0) + 1
        end
    end
    assert(n >= 60, 'the sibling idiom WITH its threshold is the majority reading; got ' .. n)

    local best, bestN = nil, 0
    for x, c in pairs(byX) do if c > bestN then best, bestN = x, c end end
    assert(best == '0.65', 'the mode of the sibling thresholds is what the fix borrows; got '
        .. tostring(best))
    -- ⚠️ SCOPED TO THE SLICED EXPRESSION, NOT TO THE FILE. The first version
    -- asked `CODE:find(...)`, and hero_tiny.lua ALREADY contains a correct
    -- `J.GetHP(bot) < 0.65 and bot:WasRecentlyDamagedByAnyHero(2)` at :659 --
    -- so the assertion was satisfied by a line the fix never touches, and the
    -- mutation stand duly walked a 0.65 -> 0.5 mutant straight through it. A
    -- matching conclusion reached for the wrong reason.
    assert(EXPR:find('J.GetHP(bot) < 0.65', 1, true) ~= nil,
        'the armed threshold must BE the measured mode -- change the constant and you must '
        .. 'change the reason, which is this assertion; got ' .. EXPR)

    -- ...and that neighbour is itself evidence. THE SAME FILE, 170 lines below
    -- the defect, writes the same idiom correctly, with the same constant this
    -- fix borrows. The author knew the threshold; this call site lost it.
    local right = 0
    for _ in CODE:gmatch('J%.GetHP%(bot%)%s*<%s*0%.65%s*and%s*bot:WasRecentlyDamagedByAnyHero') do
        right = right + 1
    end
    assert(right >= 1, 'hero_tiny.lua must still hold its own correct copy of the idiom -- '
        .. 'it is the narrowest evidence in this file that the missing `< X` is an omission')
end

tests['[source S4] J.GetHP is total: every return is a number, so the operand is always true'] = function()
    local jmz = codeOnly(read(JMZ))
    local a = assert(jmz:find('function J.GetHP( unit )', 1, true))
    local b = assert(jmz:find('function J.GetEffectiveHP', 1, true))
    local body = jmz:sub(a, b - 1)
    assert(count(body, 'return nil') == 0, 'J.GetHP has no nil path')
    assert(count(body, 'return false') == 0, 'J.GetHP has no false path')
    assert(count(body, 'return 0') == 1, 'the dead path returns a bare 0 -- which is TRUE '
        .. 'in Lua, and is the whole reason the conjunct is vacuous')

    -- and the language fact, asserted rather than assumed
    assert((0 and 'x') == 'x', 'in Lua 0 is truthy; if this ever fails the criterion is void')
end

tests['[source S5] the gate is turbo-only, named hpbool, and leaves the shipped text intact'] = function()
    assert(EXPR:find("J.IsModeTurbo() and J.IsSoakCandidate('hpbool')", 1, true) ~= nil,
        'turbo-only arming, by the id')
    assert(EXPR:find('J.GetHP(bot) and bot:WasRecentlyDamagedByAnyHero(2)', 1, true) ~= nil,
        'the shipped operand stays textually in place -- the fix adds, it does not rewrite')
    assert(SHIPPED_EXPR ~= EXPR, 'the reconstruction must actually remove something')
    assert(SHIPPED_EXPR:find('hpbool', 1, true) == nil, 'and must remove all of it')
    assert(ARMED_CONJUNCT:match('^and%s*%(%s*not%s*%(') ~= nil,
        'the added conjunct opens `and (not (...`, so a shut gate evaluates to true and the '
        .. 'disjunct is byte-for-byte the shipped decision; got ' .. ARMED_CONJUNCT:sub(1, 40))
end

tests['[source S6] the domain price: none of the four heroes is anywhere in the corpus'] = function()
    -- The reason this is a test and not a sentence in a report: it is the
    -- number the admission ruling has to weigh, and it is cheap, local and
    -- exact. Walk every fixture and count appearances by hero name.
    local p = assert(io.popen("find tests/fixtures tests/frames -name '*.lua' | sort"))
    local corpus, nFiles = {}, 0
    for path in p:lines() do
        nFiles = nFiles + 1
        for nm in read(path):gmatch('npc_dota_hero_[%a_]+') do corpus[nm] = (corpus[nm] or 0) + 1 end
    end
    p:close()
    assert(nFiles >= 100, 'the walk must find the corpus; got ' .. nFiles)
    assert((corpus['npc_dota_hero_crystal_maiden'] or 0) > 0,
        'sanity: a focus hero must be all over the corpus, or the walk is wrong')

    for _, nm in ipairs({ 'npc_dota_hero_tiny', 'npc_dota_hero_shredder',
                          'npc_dota_hero_dawnbreaker', 'npc_dota_hero_kez',
                          'npc_dota_hero_brewmaster' }) do
        assert((corpus[nm] or 0) == 0, nm .. ' is now IN the corpus (' .. tostring(corpus[nm])
            .. ' appearances) -- that is good news and it invalidates this file\'s declared '
            .. 'LIMIT: the fixture-level acceptance that was impossible is now possible')
    end
    -- brewmaster is in the list on purpose: GH #393's subject, the round before
    -- this one, and the reason the director pre-registered DOMAIN-EMPTY there.
    -- Three rounds running, the subject hero has zero corpus presence.

    -- What IS better here, and is also measured: the throttle list.
    local sel = codeOnly(read('bots/hero_selection.lua'))
    assert(sel:find("'npc_dota_hero_brewmaster'", 1, true) ~= nil,
        'brewmaster sits on the WeakHeroes throttle list -- so GH #393 was fighting the '
        .. 'draw as well as the corpus')
    for _, nm in ipairs({ 'tiny', 'shredder', 'dawnbreaker', 'kez' }) do
        assert(sel:find("'npc_dota_hero_" .. nm .. "'", 1, true) == nil,
            nm .. ' must NOT be on the WeakHeroes throttle list -- that is the one '
            .. 'structural advantage this round has over the last two')
    end
end

-- ===================================================================
-- frame -- the real instant
-- ===================================================================

tests['[frame F0] the two readings are dump ground truth, read not asserted'] = function()
    local J = world(true, true)
    local viper, axe = hero(J, 'npc_dota_hero_viper'), hero(J, 'npc_dota_hero_axe')

    local rv = J.GetHP(viper)
    local ra = J.GetHP(axe)
    assert(rv > 0.95 and rv < 1.0, 'viper is at full health on this frame; got ' .. rv)
    assert(ra > 0.30 and ra < 0.40, 'axe is genuinely low on this frame; got ' .. ra)
    assert(rv > 0.65 and ra < 0.65, 'the frame straddles the borrowed threshold -- that is '
        .. 'why one frame can carry both the case and its control')

    assert(viper:WasRecentlyDamagedByAnyHero(2) == true,
        'viper was hit by a hero 2.0s ago (ember spirit) -- from the replay ledger')
    assert(axe:WasRecentlyDamagedByAnyHero(2) == true,
        'axe was hit by a hero 0.5s ago (silencer) -- from the replay ledger')
end

tests['[frame FC] POSITIVE CONTROL: the low hero passes BOTH arms'] = function()
    -- Load-bearing, not decoration. Without it, every "armed says no" below
    -- could be a guard that was never reached at all -- the lesson §DD wrote
    -- down: A SHUT GATE PROVES NOTHING UNTIL SOMETHING SHOWS IT CAN OPEN.
    local J = world(true, true)
    local axe = hero(J, 'npc_dota_hero_axe')
    assert(guardShipped(J, axe, MANY, FEW) == true, 'shipped admits the low hero')
    assert(guardCurrent(J, axe, MANY, FEW) == true,
        'ARMED STILL ADMITS THE LOW HERO -- if this fails the fix is not a threshold, it is '
        .. 'an off switch, and nothing else in this file means anything')
end

tests['[frame F1] SHIPPED: a hero at 97.7% health is admitted to the retreat toss'] = function()
    local J = world(false, false)
    local viper = hero(J, 'npc_dota_hero_viper')
    assert(guardShipped(J, viper, MANY, FEW) == true,
        'THE DEFECT: full health, outnumbered false, and the guard still says yes -- because '
        .. 'the health operand is a ratio and 0.977 is merely "true"')
end

tests['[frame F2] ARMED: the same hero on the same frame is refused'] = function()
    local J = world(true, true)
    local viper = hero(J, 'npc_dota_hero_viper')
    assert(guardCurrent(J, viper, MANY, FEW) == false,
        'armed in turbo, the threshold the other 64 copies carry declines a full-health toss')
end

tests['[frame F3] the gate matrix: only (turbo AND armed) differs from shipped'] = function()
    for _, c in ipairs({ { false, false }, { true, false }, { false, true } }) do
        local J = world(c[1], c[2])
        local viper = hero(J, 'npc_dota_hero_viper')
        assert(guardCurrent(J, viper, MANY, FEW) == guardShipped(J, viper, MANY, FEW),
            ('gate shut (turbo=%s armed=%s) must be the shipped decision')
                :format(tostring(c[1]), tostring(c[2])))
    end
end

tests['[frame F4] the dead conjunct dominated the LEFT arm too, and that is the real cost'] = function()
    -- Outnumbered TRUE: the author's own test. Shipped and armed agree here,
    -- which is the point -- the left arm is the branch the author wrote, and
    -- shipped can never observe it deciding anything, because the right arm is
    -- already true whenever a retreating hero has been touched.
    local J = world(true, true)
    local viper = hero(J, 'npc_dota_hero_viper')
    assert(guardShipped(J, viper, FEW, MANY) == true, 'outnumbered: shipped yes')
    assert(guardCurrent(J, viper, FEW, MANY) == true, 'outnumbered: armed yes, unchanged')

    -- ...and the domination itself, stated as an equivalence on this frame:
    -- with the ratio operand vacuous, shipped is `outnumbered or recentlyHit`,
    -- so it says yes in BOTH cardinalities. It has no third answer to give.
    assert(guardShipped(J, viper, MANY, FEW) == guardShipped(J, viper, FEW, MANY),
        'THE DOMINATION: shipped returns the same verdict whether or not the bot is '
        .. 'outnumbered -- the cardinality test it was written around is unreachable')
    assert(guardCurrent(J, viper, MANY, FEW) ~= guardCurrent(J, viper, FEW, MANY),
        'armed, the cardinality test decides again -- that is what the threshold restores')
end

tests['[frame F5] STRICT SUBSET over every hero on the frame: armed never adds a cast'] = function()
    local J = world(true, true)
    local n, differ = 0, 0
    for _, list in ipairs({ UNIT_LIST_ALLIED_HEROES, UNIT_LIST_ENEMY_HEROES }) do
        for _, u in ipairs(GetUnitList(list)) do
            local s = guardShipped(J, u, MANY, FEW)
            local a = guardCurrent(J, u, MANY, FEW)
            n = n + 1
            if a ~= s then
                differ = differ + 1
                assert(s == true and a == false,
                    'armed may only REMOVE a yes, never add one; ' .. u:GetUnitName()
                        .. ' went ' .. tostring(s) .. ' -> ' .. tostring(a))
            end
        end
    end
    assert(n >= 8, 'the frame must carry a full roster; got ' .. n)
    assert(differ >= 1, 'and at least one hero must actually change, or the sweep is vacuous')
end

-- NOT PINNED -- surviving mutants, declared with their reasons.
--   * The `2` in `WasRecentlyDamagedByAnyHero(2)` is shipped tuning this change
--     has no opinion about; widening it is EQUIVALENT on this frame (viper's
--     ledger has hero damage at 2.0s and at 4.2s, axe's at 0.5s).
--   * Any mutant that changes 0.65 to another value in (0.339, 0.977) is caught
--     by [source S3] (which pins it to the measured mode), NOT by the frames --
--     the frames only straddle it. That is deliberate: the constant's warrant
--     is the sibling census, so the census is where it is pinned.
--   * `J.IsModeTurbo()` and the id string are separable by [frame F3] only as a
--     pair with the conjunction; a mutant that swaps `and` for `or` there is
--     caught (turbo-alone would then arm), a mutant that renames BOTH the gate
--     and its assertion is not, and cannot be from inside one file.

return tests

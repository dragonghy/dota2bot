-- GH #794, ruled: the Wraith King censuses crash on a DEAD row, and the nil is
-- NOT a mana cost.  This file is the hero desk's answer to the fork that issue
-- put to it, landed as a driven reading rather than as a comment.
--
-- WHAT #794 REPORTED.  A new replay-check fixture added one dead Wraith King
-- row (`alive = false`, `hp = 0`, `max_hp = 0`, and no `abilities` field at
-- all).  That row moved six recorded counts in three WK census files and, in
-- tests/test_wk_reserve_idle_release.lua section 3, crashed shipped code:
--
--     bots/BotLib/hero_skeleton_king.lua:<N>: attempt to compare number with nil
--
-- The issue's section 2 attributed the nil to one of the two `GetManaCost()`
-- calls on the line it quoted -- "前面的 and 链已短路保证 nAbility / abilityR
-- 非 nil ⇒ nil 来自某个 GetManaCost()" -- and asked the hero desk to choose
-- between guarding the CALL SITE and keeping the dead row out of the DRIVER.
--
-- ⭐ THE ATTRIBUTION IS WRONG, AND THAT CHANGES THE ANSWER.  Lua reports a
-- multi-line expression at the line the offending OPERATOR sits on, and the
-- whole `local bShipped = ... and ... and ...` chain is one expression; the
-- line the issue quoted is its last line, not the line the error names.  The
-- nil is the file-scope `nLV`, on the chain's FIRST comparison (`nLV >= 6`).
-- Section 4 reproduces that and pins the line number by parsing the source, so
-- the claim is not a reading of a line number that drifts.
--
-- Two independent facts make the mana-cost reading impossible on this tree,
-- and section 3 drives both rather than arguing them:
--   * an abilities-less row answers `GetManaCost()` = 0, never nil -- the
--     loader installs every ability reader inside `for i, a in ipairs(u.abilities
--     or {})`, so a row with no list runs that loop zero times and every read
--     falls through to tests/mock/bot_api.lua's generic `^Get` default of 0.
--     That is already established in tests/test_wk_rank0_absence_join.lua; this
--     file re-drives it because #794 rests on its negation;
--   * all three abilities-less WK rows in the corpus today are ALIVE, and none
--     of them crashes.  Liveness is the variable that moved, not the abilities
--     list.
--
-- ⭐⭐ THE RULING: THE DRIVER, and not as a matter of taste.  The shipped file
-- declares its own precondition twice, in two places neither of which this desk
-- wrote for the occasion:
--   1. bots/ability_item_usage_generic.lua's AbilityUsageThink refuses to call
--      BotBuild.SkillsComplement() at all unless `bot:IsAlive()` (section 1);
--   2. X.SkillsComplement's first statement is
--      `if J.CanNotUseAbility( bot ) or bot:IsInvisible() then return end`, and
--      J.CanNotUseAbility's first disjunct is `not bot:IsAlive()`.  Every
--      per-frame value this file's decision functions read -- nLV, nMP, nHP,
--      hEnemyHeroList -- is assigned BELOW that return (section 2).
-- So on a dead hero the engine never enters the file, and the file never
-- assigns the state.  A driver that calls X.ShouldSaveMana on a dead row is
-- calling a function outside a precondition the shipped code states twice, and
-- a nil-guard at the call site would be defending shipped code against a state
-- it structurally refuses to enter -- while also converting a loud crash into a
-- quiet answer, which is how the six moved counts would have gone unnoticed.
--
-- ⚠️ WHAT THE RULING DOES NOT SAY.  It does not say the three censuses are
-- fine.  It says their population predicate needs LIVENESS, and section 5
-- shows that liveness and "carries an abilities list" are DIFFERENT predicates
-- on this corpus -- disjoint, in fact: 3 abilities-less rows, all alive; 0 dead
-- rows.  #794's acceptance item 1 asks for one declaration; it needs both, and
-- either one alone would have missed the other's rows.
--
-- ⚠️ AND IT IS ABOUT THE DRIVER, NOT ABOUT THE FIXTURE.  Nothing here asks
-- replay-check to withhold a dead row from a fixture; a dead hero is real frame
-- data and the corpus is better with it.  What must not happen is a census
-- walking that row into a decision function.
--
-- bots/ carries no behavior change from this work unit, on purpose: the answer
-- to "guard the call site or not" is NOT.
--
-- SECTIONS
--   1  the engine-side precondition, read off the generic Think
--   2  the file-side precondition, read off X.SkillsComplement
--   3  #794 section 2 falsified: abilities-less answers 0, and does not crash
--   4  the reproduction: the nil is nLV, and it takes a DEAD row
--   5  liveness and abilities are different predicates on this corpus

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local WK = 'npc_dota_hero_skeleton_king'
local Q = 'skeleton_king_hellfire_blast'
local R = 'skeleton_king_reincarnation'
local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local GENERIC_SRC = 'bots/ability_item_usage_generic.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Every line of a file, blank lines included, in order.  `gmatch('[^\n]*')`
--- is NOT this: it also yields an empty match after every line, so it counts
--- each line twice and every line number it produces is roughly doubled.
local function lines_of(path)
    local out = {}
    local s = read_file(path)
    local pos = 1
    while true do
        local nl = s:find('\n', pos, true)
        if nl == nil then
            if pos <= #s then out[#out + 1] = s:sub(pos) end
            break
        end
        out[#out + 1] = s:sub(pos, nl - 1)
        pos = nl + 1
    end
    return out
end

--- The 1-based line number of the first line matching `pat`, and an error that
--- names the file when there is none.  Used instead of literal line numbers so
--- that this file's claims survive edits above them.
local function line_of(path, pat, what)
    local n = 0
    for _, line in ipairs(lines_of(path)) do
        n = n + 1
        if line:find(pat) then return n end
    end
    error('cannot find ' .. what .. ' in ' .. path
        .. ' (pattern ' .. pat .. ').  This file reads that line rather than '
        .. 'quoting it, so a rename breaks the reading, not just the match')
end

local function fixture_files()
    local files = {}
    -- Hand-read call site, registered in tests/test_bots_walk_farm_only.py
    -- (GH #774): a literal `ls` of the fixture directory, no interpolation.
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

--- Every Wraith King ROW in the corpus, with the two flags this file is about.
--- Rows, not fixtures: a fixture may hold more than one, and #794's row was not
--- its fixture's subject.
local function wk_rows()
    local rows = {}
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            for _, u in ipairs(fx.units) do
                if u.name == WK then
                    rows[#rows + 1] = {
                        path = path,
                        alive = (u.alive ~= false),
                        has_abilities = (type(u.abilities) == 'table'),
                        level = u.level,
                    }
                end
            end
        end
    end
    return rows
end

local function short(path) return (path:gsub('^tests/fixtures/', '')) end

local function select_rows(rows, pred)
    local out = {}
    for _, r in ipairs(rows) do if pred(r) then out[#out + 1] = r end end
    return out
end

local function joined(rows)
    local names = {}
    for _, r in ipairs(rows) do names[#names + 1] = short(r.path) end
    table.sort(names)
    return table.concat(names, ', ')
end

-- ---------------------------------------------------------------------------
-- 1. The engine-side precondition.

tests['[section 1] the generic Think refuses a dead hero before the hero file is entered'] =
function()
    local src = read_file(GENERIC_SRC)
    local body = src:match('function AbilityUsageThink%(%)(.-)\nend')
    assert(body ~= nil, 'cannot find AbilityUsageThink in ' .. GENERIC_SRC
        .. '; this section reads its body, so a rename breaks the reading')
    local guard = body:find('not bot:IsAlive()', 1, true)
    local call = body:find('BotBuild.SkillsComplement()', 1, true)
    assert(call ~= nil, 'AbilityUsageThink no longer calls BotBuild.SkillsComplement(); '
        .. 'the entry point moved and the ruling in this file must be re-taken '
        .. 'against the new one')
    assert(guard ~= nil, 'AbilityUsageThink no longer tests `not bot:IsAlive()`.  '
        .. 'That guard is half of the GH #794 ruling -- if it was removed '
        .. 'deliberately, a dead hero can now reach X.SkillsComplement in a real '
        .. 'game and the call-site question reopens')
    assert(guard < call, 'AbilityUsageThink tests `not bot:IsAlive()` AFTER it '
        .. 'calls SkillsComplement; the guard no longer protects the call')
end

-- ---------------------------------------------------------------------------
-- 2. The file-side precondition.

tests['[section 2] the per-frame state is assigned only past the file own liveness gate'] =
function()
    local src = read_file(WK_SRC)
    local body = src:match('function X%.SkillsComplement%(%)(.-)\nend')
    assert(body ~= nil, 'cannot find X.SkillsComplement in ' .. WK_SRC)
    local gate = body:find('J.CanNotUseAbility( bot )', 1, true)
    local assign = body:find('nLV = bot:GetLevel()', 1, true)
    assert(gate ~= nil, 'X.SkillsComplement no longer opens with J.CanNotUseAbility; '
        .. 'the file-side half of the GH #794 ruling is gone')
    assert(assign ~= nil, 'X.SkillsComplement no longer assigns nLV; sections 2 '
        .. 'and 4 of this file are readings of a different function')
    assert(gate < assign, 'nLV is now assigned BEFORE the liveness gate.  That '
        .. 'is a real change to the ruling: the state would then be defined on a '
        .. 'dead hero and the driver question in GH #794 changes shape')

    -- The gate is a liveness gate, not merely a "busy" gate.  Read off
    -- jmz_func rather than assumed, because the whole ruling turns on it.
    local jmz = read_file('bots/FunLib/jmz_func.lua')
    local can_not = jmz:match('function J%.CanNotUseAbility%( bot %)(.-)\nend')
    assert(can_not ~= nil, 'cannot find J.CanNotUseAbility in bots/FunLib/jmz_func.lua')
    assert(can_not:find('not bot:IsAlive()', 1, true) ~= nil,
        'J.CanNotUseAbility no longer tests IsAlive, so X.SkillsComplement no '
        .. 'longer refuses a dead hero and the GH #794 ruling must be re-taken')

    -- nLV is a file-scope local with exactly one assignment.  Without this a
    -- second assignment elsewhere could make section 4 unreproducible while
    -- every assertion above still passed.
    local n_assign = 0
    for _ in src:gmatch('\n%s*nLV = ') do n_assign = n_assign + 1 end
    assert(n_assign == 1, 'nLV is assigned ' .. n_assign .. ' times in ' .. WK_SRC
        .. ', recorded 1.  The reproduction in section 4 assumes the only '
        .. 'assignment is the one behind the liveness gate')
end

-- ---------------------------------------------------------------------------
-- 3. GH #794 section 2, falsified on the frames it names.

tests['[section 3] a LIVE abilities-less row answers 0 rather than nil, and the reserve runs'] =
function()
    local rows = wk_rows()
    -- LIVE and abilities-less: that pair is the whole falsification.  #794
    -- blamed the abilities list, so the control that separates the two
    -- candidate causes is a row that has the blamed property and NOT the other
    -- one.  (Driving a dead abilities-less row here would prove nothing about
    -- which of the two raised -- it is section 4's job to say which.)
    local absent = select_rows(rows, function(r)
        return (not r.has_abilities) and r.alive
    end)
    assert(#absent > 0, 'no LIVE abilities-less Wraith King row left in the '
        .. 'corpus; this section drives the shape GH #794 blamed, so it cannot run')
    for _, r in ipairs(absent) do
        local _, bot = rf.load(r.path, WK)
        local hQ, hR = bot:GetAbilityByName(Q), bot:GetAbilityByName(R)
        assert(hQ ~= nil and hR ~= nil, short(r.path)
            .. ': the loader handed back no handle at all, so the readings below '
            .. 'are about a different failure than the one GH #794 describes')
        assert(hQ:GetManaCost() == 0 and hR:GetManaCost() == 0, short(r.path)
            .. ': an abilities-less row answers a mana cost of '
            .. tostring(hQ:GetManaCost()) .. '/' .. tostring(hR:GetManaCost())
            .. ', recorded 0/0.  The loader default changed and GH #794 section '
            .. '2 may be right after all -- re-take the ruling')
        local X = rf.load_hero('skeleton_king')
        pcall(function() X.SkillsComplement() end)
        local ok, err = pcall(X.ShouldSaveMana, hQ)
        assert(ok, short(r.path) .. ': X.ShouldSaveMana raised on an abilities-less '
            .. 'but LIVE row (' .. tostring(err) .. ').  GH #794 blamed the '
            .. 'abilities list; if this fires, that blame is back on the table')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The reproduction.

tests['[section 4] on a DEAD row the nil is nLV, on the first comparison of the chain'] =
function()
    local rows = wk_rows()
    local live = select_rows(rows, function(r) return r.alive and r.has_abilities end)
    assert(#live > 0, 'no live, priced Wraith King row to build the dead one from')
    local path = live[1].path

    local _, bot = rf.load(path, WK)
    -- The ONE substitution, declared: the corpus holds no dead Wraith King row
    -- today (section 5), so liveness is injected rather than read.  Everything
    -- else on the frame is the fixture's.  This is the same shape #794's row
    -- had -- J.CanNotUseAbility's first disjunct is what both trip.
    local sp = rawget(bot, '__spec')
    assert(sp ~= nil, 'the loader no longer exposes a __spec table; the '
        .. 'substitution this section declares cannot be made honestly')
    sp.IsAlive = function() return false end
    assert(bot:IsAlive() == false, 'the injected liveness did not take')

    local X = rf.load_hero('skeleton_king')
    local ok_think = pcall(function() X.SkillsComplement() end)
    assert(ok_think, 'X.SkillsComplement itself raised on the dead row; it is '
        .. 'supposed to early-return, and the ruling rests on that return')

    local hQ = bot:GetAbilityByName(Q)
    local ok, err = pcall(X.ShouldSaveMana, hQ)
    assert(not ok, 'X.ShouldSaveMana returned ' .. tostring(err) .. ' on a dead '
        .. 'row instead of raising.  Either the state is now defined on a dead '
        .. 'hero or a guard was added at the call site -- both are changes to '
        .. 'the GH #794 ruling and must be argued, not absorbed')
    assert(tostring(err):find('attempt to compare number with nil', 1, true) ~= nil,
        'the dead row now raises "' .. tostring(err) .. '", not the '
        .. '"attempt to compare number with nil" GH #794 reported')

    -- ⭐ The attribution, pinned against the source rather than against a
    -- remembered line number: the line Lua names must be the `nLV >= 6` line,
    -- NOT the `GetManaCost()` line GH #794 blamed.
    local reported = tonumber(tostring(err):match(':(%d+):'))
    assert(reported ~= nil, 'the error carries no line number: ' .. tostring(err))
    local nlv_line = line_of(WK_SRC, 'local bShipped = nLV >= 6',
        'the first comparison of the reserve chain')
    local cost_line = line_of(WK_SRC, 'nAbility:GetManaCost%(%) < abilityR:GetManaCost',
        'the mana-cost comparison GH #794 blamed')
    assert(reported == nlv_line, 'the dead row now raises at line ' .. reported
        .. ', while `local bShipped = nLV >= 6` is at line ' .. nlv_line
        .. '.  The nil moved operand; re-read the ruling before quoting it')
    assert(reported ~= cost_line, 'the dead row raises at the mana-cost line ('
        .. cost_line .. '), which is what GH #794 claimed.  If this ever fires, '
        .. 'that issue was right and this file is the thing that is wrong')
end

-- ---------------------------------------------------------------------------
-- 5. The two predicates.

--- ⛔ THIS SECTION MUST NOT BE A TRIPWIRE ON THE FIXTURE ITSELF.  The first
--- draft of it asserted `dead rows == 0`, which would have gone red the moment
--- replay-check lands the fixture GH #794 withdrew -- i.e. it would have handed
--- the same push back to the same desk with a different file's name on it.
--- What the ruling actually requires is not that the corpus stay free of
--- corpses; it is that every WK population which DRIVES shipped code carries a
--- liveness predicate.  So this section reads the four census files and asserts
--- the predicate is there, and reports the counts as ratchets that may rise.
local LIVENESS_SITES = {
    'tests/test_wk_save_mana_lock_census.lua',
    'tests/test_wk_reserve_idle_release.lua',
    'tests/test_wk_roshan_mana_floor.lua',
    'tests/test_wk_roshan_mana_ceiling.lua',
}

tests['[section 5] every WK census that walks the corpus carries a liveness predicate'] =
function()
    local rows = wk_rows()
    cs.corpus(#fixture_files(), 'fixture corpus')
    cs.ratchet(#rows, 36, 'Wraith King rows in the corpus')

    local dead = select_rows(rows, function(r) return not r.alive end)
    local absent = select_rows(rows, function(r) return not r.has_abilities end)
    cs.ratchet(#absent, 3, 'abilities-less Wraith King rows')

    for _, path in ipairs(LIVENESS_SITES) do
        local src = read_file(path)
        assert(src:find('alive ~= false', 1, true) ~= nil, path
            .. ' walks the fixture corpus for Wraith King rows and no longer '
            .. 'tests `alive ~= false`.  That predicate is the GH #794 ruling: '
            .. 'without it a dead row reaches a decision function, and the '
            .. 'shipped file raises rather than answering (section 4).  Three '
            .. 'of these four files had six recorded counts moved by exactly '
            .. 'one such row; the fourth was found by staging one')
    end

    -- Informational, and deliberately NOT an assertion on the count: the two
    -- predicates were disjoint on the 2026-09-13 corpus (3 abilities-less rows,
    -- all alive; 0 dead rows), and #794's own row is in BOTH buckets, so the
    -- day it lands neither bucket's size can be read off the other.  What must
    -- keep holding is the loop above, not these numbers.
    assert(#dead >= 0 and #absent >= 0)
end

return tests

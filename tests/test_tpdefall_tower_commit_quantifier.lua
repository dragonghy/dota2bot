-- [tpdefall 20260912] THE ARBITRARY-MEMBER FAMILY IN THE DEFEND-TP WINNABILITY
-- READ -- the first site where the SHIPPED COMMENT STATED the false claim, and
-- the first one this desk PRICED AND DID NOT LAND.
--
-- ⛔ READ THIS FIRST: THERE IS NO BEHAVIOUR CHANGE BEHIND THIS FILE. The lever
-- it prices was written, measured, and REVERTED inside the same work unit (the
-- reason is section 4e, and it is a measurement, not a nerve). What is landed is
-- (i) a comment repair -- the shipped prose said something false about the
-- shipped code -- and (ii) this census, so the next attempt starts from priced
-- numbers instead of re-deriving them. Every count below is therefore a
-- COUNTERFACTUAL about a reading of the site, not a test of shipped behaviour,
-- and both readings are written out in this file.
--
-- THE DEFECT. bots/FunLib/jmz_func.lua, J.ShouldTpSupportTowerFight:
--     local tEnemies = J.GetEnemiesNearLoc( vTower, 1200 )
--     ...
--     -- reuse the lethal-or-numbers commit gate against the nearest tower enemy
--     ... J.SafeToCommitFight( bot, tEnemies[1] )
-- "Is this collapse winnable" is an existential question about the enemies
-- standing at that tower, and it is asked of ONE list member.
--
-- ⭐⭐ WHY THIS SITE IS WORTH ITS OWN LINE. Every earlier member of the family
-- (lvlany / lvlcarry / lvlgroup / lvltogether / lvlhitcreep) read a list that
-- INHERITS A DISTANCE SORT, so `[1]` at least meant "the nearest" and the defect
-- was "the nearest is not the most dangerous". 'cutoff' was the first site where
-- `[1]` was arbitrary -- but there the "nearest" reading was a READER's
-- assumption. Here the shipped comment SAID "the nearest tower enemy", and
-- section 4a pins that the producer cannot deliver it: J.GetEnemiesNearLoc fills
-- from `GetUnitList(UNIT_LIST_ENEMY_HEROES)` -- one world list, the same object
-- order for every observer -- and filters by distance, illusion, Meepo clone and
-- the tempest-double modifier, with no `table.sort` anywhere on the path.
-- Section 4b measures the claim failing on 22 of 113 real sites. That sentence
-- is now gone from the source, and section 4a keeps it from coming back.
--
-- ⛔ WHY THE OBVIOUS REPAIR WAS NOT LANDED EITHER, and the reason is MEASURED,
-- not preferred. Section 4d prices four readings of the same site over the 42
-- responder-shaped sites this corpus carries: `[1]` = 19, "some member" = 19,
-- "nearest to the tower" = 19, "every member" = 16. The first three are the SAME
-- SET (each implies the next and the counts are equal), so repairing the
-- comment's literal word would move ZERO rows -- a no-op dressed as a fix, and
-- the kind that reads in a report as if something happened.
--
-- ⛔ AND WHY THE ONE READING THAT DOES MOVE WAS REVERTED. `J.SafeToCommitFight`
-- is NOT a per-enemy question that a quantifier merely asks correctly. Its two
-- branches are (a) can the allies within 1200 OF e burst e down, and (b) is
-- `#allies near e >= #enemies near e`; both are anchored at the TARGET's
-- location, and `bot` is not read by either. So "every member" is a STRICTER,
-- DIFFERENT question, and section 4e records what it cost: landed for one round,
-- it withdrew the host's response on tparrive's `parity` control frame and on
-- midsupyield's NODROP frame -- two OTHER unpromoted candidates silently
-- re-scoped by a change advertised as one lever. That is a bundle, and AGENTS.md
-- already paid for that lesson twice (lanefix, gpm -74.5 then -88.7, 0/4 comps).
-- The direction bound was clean (section 3b, 0 violations, 3 withdrawals of 31)
-- and the end-to-end drive was real (midtp 4 -> 3 on the corpus, witness
-- f_260819_183613_storm_collapse_parity.lua / storm_spirit). Clean direction was
-- not enough, and that is the finding.
--
-- ⚠️ TWO TRAPS THIS CENSUS WALKED INTO BEFORE IT MEASURED ANYTHING. Both were
-- caught, both changed the numbers, and both are recorded because the shapes
-- recur -- a reader who re-takes this census without them gets confident wrong
-- answers, not obvious errors.
--
-- (1) A MUTATING CONJUNCT MAKES LEG ORDER LOAD-BEARING. The host's conjunction
-- ENDS in `J.TryTakeTpResponseSlot()`, which mutates the team's response quota.
-- Driving both legs on the SAME loaded fixture lets the first leg eat the slot,
-- so the second reads 0 for a reason that has nothing to do with the lever: the
-- first function-layer measurement reported the universal withdrawing EVERY
-- response the corpus could witness -- the lanefix shape, and it would have been
-- the right reason to abandon the change, had it been real. It was an artifact
-- of leg order. Any re-attempt must run ONE FULL PASS PER LEG with a fresh
-- rf.load per fixture and assert `shipped - withdraw == armed`.
--
-- (2) ⭐ THE LOADER'S TEAM BINDING DOES NOT FOLLOW AN OVERRIDDEN `GetTeam()`.
-- tests/mock/replay_fixture.lua closes over `enemies` / `allies` (and the
-- structure lists) AT LOAD TIME, from the loaded SUBJECT's team. The sibling
-- census for 'cutoff' overrides the global GetTeam() per row and rebuilds its
-- site list BY HAND from UNIT_LIST_ALL, so it is unaffected; this file calls the
-- SHIPPED producer (J.GetEnemiesNearLoc) and therefore is. Driving an
-- opposite-team hero as the bot hands that producer the hero's own TEAMMATES as
-- "enemies". ⛔ The tell was not a crash and not an implausible headline number:
-- it was section 4c, whose whole job is producer sanity, reporting SAME_TEAM = 6
-- on the withdrawal rows -- an assertion written for a different reason paying
-- for itself. Every count here is now taken with the subject's own team as the
-- bot, which halves the row base (1306 -> 653) and moved every number reported.
--
-- ⛔ THE HOST IS RETIRED, WHICH IS WHY NOTHING IS URGENT HERE. Both host ids are
-- OUT of the armed set: `midtp` 退集 (test_set.md:108, VERIFY verdict=BUGGY, the
-- TP landing point is not an arithmetically valid coordinate, GH #539) and
-- `suptp` 退集 (test_set.md:109, the same NaN plus being dominated by midtp,
-- GH #545). No wave is disturbed by the comment repair, and no wave would have
-- measured the reverted lever either. Registered: state.json:tpdefall_20260912,
-- GH #767. armed string / queue.json / test_set.md untouched.
--
-- ⛔ REGISTERED, NOT REPAIRED: the other leg of the same disjunct reads
-- `tEnemies[1]` too --
--     or ( J.IsSoakCandidate('tparrive') and J.SafeToCommitFightOnArrival(bot, tEnemies[1]) )
-- Section 6 asserts it is still there, so this note cannot go stale silently.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local TRG = 'bots/FunLib/jmz_func.lua'

-- The host's own constants, not new ones.
local TOWER_RING = 1200   -- J.GetEnemiesNearLoc( vTower, 1200 )
local FAR_FLOOR  = 3500   -- J.TP_RESPONSE_FAR_FLOOR

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
--- structural assertions in sections 4a, 5 and 6.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local SRC = stripped(read_file(TRG))

local function block(header)
    local s = SRC:find(header, 1, true)
    assert(s ~= nil, header .. ' is gone from ' .. TRG)
    local e = SRC:find('\nend', s, true)
    assert(e ~= nil, 'unterminated ' .. header .. ' in ' .. TRG)
    return SRC:sub(s, e + 3)
end

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ 'tests/fixtures', 'tests/frames' }) do
        -- Registered in tests/test_bots_walk_farm_only.py:UNRESOLVED_HAND_READ:
        -- a plain non-recursive `ls` over two literal directories.
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

local PATHS = corpus_paths()

--- The shipped expression, spelled out here so section 3b compares the helper
--- against the TEXT of what shipped rather than against another call of itself.
local function shipped_answer(J, bot, t)
    if t == nil or t[1] == nil then return false end
    return J.SafeToCommitFight(bot, t[1]) and true or false
end

--- The armed quantifier, written out once for the drift check in section 3a.
--- Sections 3b-4 drive the REAL shipped bytes, never this.
local function all_answer(J, bot, t)
    if t == nil or t[1] == nil then return false end
    for i = 1, #t do
        if J.IsValidHero(t[i]) and not J.SafeToCommitFight(bot, t[i]) then
            return false
        end
    end
    return true
end

--- "some member" and "nearest to the tower": the two obvious alternative
--- readings, priced in section 4d so the choice of quantifier is measured.
local function exists_answer(J, bot, t)
    if t == nil or t[1] == nil then return false end
    for i = 1, #t do
        if J.SafeToCommitFight(bot, t[i]) then return true end
    end
    return false
end

local function nearest_answer(J, bot, t, vTower)
    if t == nil or t[1] == nil then return false end
    local best, bd = t[1], GetUnitToLocationDistance(t[1], vTower)
    for i = 2, #t do
        local d = GetUnitToLocationDistance(t[i], vTower)
        if d < bd then best, bd = t[i], d end
    end
    return J.SafeToCommitFight(bot, best) and true or false
end

--- `bAllyThere`, lifted term for term from the host so section 4d speaks about
--- the sites the host would actually score rather than about every tower.
local function ally_there(J, bot, vTower)
    for _, ally in pairs(J.GetAlliesNearLoc(vTower, TOWER_RING)) do
        if ally ~= bot and J.IsValidHero(ally)
            and J.WillAllySurviveTpWindow(ally)
            and (ally:WasRecentlyDamagedByAnyHero(3.0) or J.GetHP(ally) < 0.75)
        then
            return true
        end
    end
    return false
end

-- --------------------------------------------- the predicate-layer sweep ---

local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    local RADII = { 800, 1200, 1600 }

    for _, path in ipairs(PATHS) do
        local ok, J, subject, heroes = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('frames_loaded')
            -- ⚠️ SUBJECT'S TEAM ONLY, and this is not a convenience -- see the
            -- second trap in the header. The loader binds UNIT_LIST_ENEMY_HEROES
            -- and UNIT_LIST_ALLIED_BUILDINGS to the LOADED SUBJECT's team at
            -- load time; they do not follow an override of the global GetTeam().
            -- Driving an opposite-team hero as the bot therefore hands the
            -- shipped producer that hero's own TEAMMATES as "enemies".
            local subj_team = subject:GetTeam()
            for _, h in pairs(heroes or {}) do
                if h ~= nil and h.IsAlive and h:IsAlive()
                    and h:GetTeam() == subj_team
                then
                    bump('live')
                    for _, b in pairs(GetUnitList(UNIT_LIST_ALLIED_BUILDINGS) or {}) do
                        if J.IsValidBuilding(b)
                            and string.find(b:GetUnitName(), 'tower') ~= nil
                        then
                            bump('tower_seen')
                            if GetUnitToUnitDistance(h, b) > FAR_FLOOR then
                                bump('tower_far')
                                local vT = b:GetLocation()
                                local tE = J.GetEnemiesNearLoc(vT, TOWER_RING)
                                if tE[1] ~= nil then
                                    bump('site')
                                    if #tE >= 2 then bump('site_ge2') end

                                    -- ⛔ Both readings are written out IN THIS
                                    -- FILE. Nothing here drives a shipped
                                    -- helper, because there is no shipped
                                    -- helper: the change this census priced was
                                    -- reverted the same round (header §REVERTED).
                                    -- These are a COUNTERFACTUAL, and the file
                                    -- says so rather than reading like a test of
                                    -- landed behaviour.
                                    local a_real = all_answer(J, h, tE)
                                    local s_text = shipped_answer(J, h, tE)
                                    if s_text then bump('shipped_true') end
                                    if a_real then bump('all_true') end
                                    if a_real and not s_text then bump('DIR_VIOLATION') end
                                    if s_text and not a_real then
                                        bump('site_miss')
                                        -- A withdrawal needs a SECOND member:
                                        -- with one member the two answers are
                                        -- the same expression.
                                        if #tE >= 2 then bump('miss_ge2') end
                                        -- 4c, taken ON THE ROWS THAT CARRY THE
                                        -- CLAIM rather than corpus-wide.
                                        for i = 1, #tE do
                                            if tE[i] == h then bump('SELF_IN_LIST') end
                                            if tE[i]:GetTeam() == h:GetTeam() then
                                                bump('SAME_TEAM')
                                            end
                                            if not J.IsValidHero(tE[i]) then
                                                bump('INVALID_MEMBER')
                                            end
                                        end
                                    end

                                    -- 4b. `[1]` is NOT the nearest -- to the
                                    -- tower (the word the comment used) and to
                                    -- the bot (the other reading a reader might
                                    -- supply). Both measured, neither assumed.
                                    local d1 = GetUnitToLocationDistance(tE[1], vT)
                                    for i = 2, #tE do
                                        if GetUnitToLocationDistance(tE[i], vT) < d1 - 0.5 then
                                            bump('not_nearest_tower')
                                            break
                                        end
                                    end
                                    local e1 = GetUnitToUnitDistance(h, tE[1])
                                    for i = 2, #tE do
                                        if GetUnitToUnitDistance(h, tE[i]) < e1 - 0.5 then
                                            bump('not_nearest_bot')
                                            break
                                        end
                                    end

                                    -- 4d. the responder-shaped sites, and the
                                    -- four readings priced on them.
                                    if ally_there(J, h, vT) then
                                        bump('rsite')
                                        if shipped_answer(J, h, tE) then bump('r_first') end
                                        if exists_answer(J, h, tE) then bump('r_exists') end
                                        if nearest_answer(J, h, tE, vT) then bump('r_nearest') end
                                        if all_answer(J, h, tE) then bump('r_all') end
                                    end

                                    -- 2. the sweep: the site cell is ONE of
                                    -- these, and the neighbours are what make
                                    -- it a population rather than a coincidence.
                                    for _, r in ipairs(RADII) do
                                        local L = J.GetEnemiesNearLoc(vT, r)
                                        if shipped_answer(J, h, L)
                                            and not all_answer(J, h, L)
                                        then
                                            bump('miss_r' .. r)
                                        end
                                    end
                                end
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

tests['[tpdefall] 1. the corpus this file speaks about'] = function()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' fixture(s) failed to load -- every count below '
        .. 'is taken over a corpus this file cannot describe. Fix the loader '
        .. 'before reading any other section.')
    cs.corpus(SWEEP['frames_loaded'], 'frames loaded')
    cs.ratchet(SWEEP['live'], 653, 'live hero rows on the subject\'s team')
    cs.ratchet(SWEEP['tower_seen'], 5135, '(row, live allied tower) pairs')
    cs.ratchet(SWEEP['tower_far'], 4352,
        'those pairs beyond J.TP_RESPONSE_FAR_FLOOR (' .. FAR_FLOOR .. ')')
    cs.ratchet(SWEEP['site'], 113,
        'sites with >= 1 enemy hero within ' .. TOWER_RING .. ' of the tower')
    cs.ratchet(SWEEP['site_ge2'], 30, 'sites with >= 2 such enemies')
end

tests['[tpdefall] 2. the sweep: the site cell is one of a population'] = function()
    cs.ratchet(SWEEP['miss_r1200'], 3, 'site cell: r1200 withdrawals')
    assert(SWEEP['miss_r800'] == 0,
        'r800 withdrawals rose to ' .. SWEEP['miss_r800'] .. ' (registered 0). '
        .. 'A zero is kept as an EQUALITY on purpose: it is the end of this '
        .. "corpus's curve, and a counter-example is a finding about the "
        .. 'producer worth reading, not a number to re-baseline past.')
    cs.ratchet(SWEEP['miss_r1600'], 3, 'r1600 withdrawals')
    assert(SWEEP['miss_r1200'] == SWEEP['site_miss'],
        'the sweep cell (' .. SWEEP['miss_r1200'] .. ') and the site count ('
        .. SWEEP['site_miss'] .. ') disagree, and they are the same question '
        .. 'asked twice -- one of the two is measuring something else now.')
    -- ⛔ Registered, NOT asserted as a law. Widening the ring adds members,
    -- which can only add ways for the universal to fail -- but it also changes
    -- WHO `[1]` is, so monotonicity is not entailed here the way it would be
    -- for a distance-sorted producer. 0 / 3 / 3 is this corpus's curve; if a
    -- future corpus breaks the ordering that is a finding about the producer,
    -- not a failure of this file.
end

tests['[tpdefall] 3a. both readings are non-degenerate on this corpus'] = function()
    assert(SWEEP['shipped_true'] > 0,
        'the shipped expression is true on 0 rows, so section 3b compares two '
        .. 'empty sets and the direction bound is vacuous.')
    assert(SWEEP['all_true'] > 0,
        'the universal is true on 0 rows -- it would be a constant `false` here '
        .. 'and section 4d would be comparing a lever against nothing.')
    cs.ratchet(SWEEP['shipped_true'], 31, 'sites where `[1]` says commit')
    cs.ratchet(SWEEP['all_true'], 28, 'sites where EVERY member says commit')
end

tests['[tpdefall] 3b. direction: the predicate layer only ever withdraws'] = function()
    assert(SWEEP['DIR_VIOLATION'] == 0,
        SWEEP['DIR_VIOLATION'] .. ' row(s) where the universal says commit and '
        .. '`[1]` does not. The loop starts at i = 1 on a list the producer has '
        .. 'already filtered to valid heroes, so `[1]` is always evaluated and '
        .. 'this count is 0 by construction -- a non-zero here means the loop '
        .. 'bound or the producer changed.')
    assert(SWEEP['shipped_true'] - SWEEP['all_true'] == SWEEP['site_miss'],
        'shipped_true (' .. SWEEP['shipped_true'] .. ') - all_true ('
        .. SWEEP['all_true'] .. ') should equal site_miss ('
        .. SWEEP['site_miss'] .. '). It does not, so the two counts are not '
        .. 'about the same rows and the direction bound above could be '
        .. 'satisfied by a helper that answers a constant.')
    assert(SWEEP['miss_ge2'] == SWEEP['site_miss'],
        SWEEP['site_miss'] - SWEEP['miss_ge2'] .. ' withdrawal(s) happened on a '
        .. 'ONE-member list, where the two readings are literally the same '
        .. 'expression. That is arithmetically impossible, so the sweep is '
        .. 'measuring two different lists.')
    cs.ratchet(SWEEP['site_miss'], 3, 'predicate-layer withdrawals')
end

tests['[tpdefall] 4a. the producer cannot deliver the word "nearest"'] = function()
    local prod = block('function J.GetEnemiesNearLoc(vLoc, nRadius)')
    local n = 0
    for _ in prod:gmatch('table%.sort') do n = n + 1 end
    assert(n == 0,
        'J.GetEnemiesNearLoc now sorts (' .. n .. ' call(s)). If it sorts by '
        .. 'distance the whole premise of this file is gone and `[1]` really is '
        .. 'the nearest -- re-read section 4b before deleting anything.')
    assert(prod:find('GetUnitList(UNIT_LIST_ENEMY_HEROES)', 1, true) ~= nil,
        'J.GetEnemiesNearLoc no longer reads the world list; the '
        .. 'observer-independence argument in the header is about that list.')
    -- The site still reads the producer this file measured.
    local host = block('function J.ShouldTpSupportTowerFight( bot )')
    assert(host:find('J.GetEnemiesNearLoc( vTower, 1200 )', 1, true) ~= nil,
        'the host no longer builds tEnemies from J.GetEnemiesNearLoc at 1200')
    assert(host:find('J.SafeToCommitFight( bot, tEnemies[1] )', 1, true) ~= nil,
        'the host no longer reads tEnemies[1]. If someone repaired the site, '
        .. 'this whole census is about a defect that is gone -- read section 4d '
        .. 'first: on this corpus the OBVIOUS repair moves nothing, so a repair '
        .. 'that claims to fix this needs its own numbers.')
    -- And the false word is gone from the prose. Read off the UNSTRIPPED file,
    -- because a comment is exactly what this pin is about.
    local raw = read_file(TRG)
    assert(raw:find('the nearest tower enemy', 1, true) == nil,
        'the comment above the site calls tEnemies[1] "the nearest tower enemy" '
        .. 'again. Section 4a just measured that the producer cannot deliver '
        .. 'that, and section 4b measured it failing on real rows.')
end

tests['[tpdefall] 4b. `[1]` is not the nearest, measured'] = function()
    cs.ratchet(SWEEP['not_nearest_tower'], 22,
        'sites where `[1]` is NOT the enemy nearest the tower (the word the '
        .. 'shipped comment used)')
    cs.ratchet(SWEEP['not_nearest_bot'], 15,
        'sites where `[1]` is NOT the enemy nearest the bot')
    assert(SWEEP['not_nearest_tower'] > 0,
        'on this corpus `[1]` is always the nearest to the tower, so the '
        .. 'comment happens to be right here and section 4a is the only thing '
        .. 'carrying the claim. Say so in the report rather than deleting this.')
    -- ⛔ These counts are this corpus's INSTANCE of the argument, not its proof:
    -- the loader restores UNIT_LIST_ENEMY_HEROES in fixture roster order, which
    -- is A world order, not necessarily the engine's. The argument that survives
    -- either order is the observer-independence pinned in 4a.
end

tests['[tpdefall] 4c. producer sanity on the rows that carry the claim'] = function()
    assert(SWEEP['SELF_IN_LIST'] == 0,
        SWEEP['SELF_IN_LIST'] .. ' withdrawal row(s) list the bot itself as an '
        .. 'enemy')
    assert(SWEEP['SAME_TEAM'] == 0,
        SWEEP['SAME_TEAM'] .. ' withdrawal row(s) list an ally as an enemy')
    assert(SWEEP['INVALID_MEMBER'] == 0,
        SWEEP['INVALID_MEMBER'] .. ' withdrawal row(s) carry an invalid hero. '
        .. 'The helper skips those, so a non-zero here means the skip is live '
        .. 'and the direction argument needs the skip to be re-argued.')
    -- ⚠️ These are the producer's guarantees, and they are what makes the
    -- direction claim in section 3b hold BY CONSTRUCTION rather than by count:
    -- every member is a valid enemy hero, so a universal that loops from i = 1
    -- always evaluates `[1]` and can only ever withdraw.
end

tests['[tpdefall] 4d. the alternative readings this corpus retires'] = function()
    cs.ratchet(SWEEP['rsite'], 42,
        'responder-shaped sites (tower far + enemies there + an ally in trouble)')
    -- `first` implies `exists`, and `nearest` implies `exists`. Equal counts on
    -- top of those implications make them the SAME SET, which is the whole
    -- content of this section: on this corpus, repairing the comment's literal
    -- word is a no-op.
    assert(SWEEP['r_first'] == SWEEP['r_exists'],
        'r_first ' .. SWEEP['r_first'] .. ' vs r_exists ' .. SWEEP['r_exists'])
    assert(SWEEP['r_first'] == SWEEP['r_nearest'],
        'r_first ' .. SWEEP['r_first'] .. ' vs r_nearest ' .. SWEEP['r_nearest']
        .. '. These differing is GOOD NEWS for the cheaper fix -- it would mean '
        .. '"ask the nearest one" is distinguishable from what ships after all. '
        .. 'Re-read the header before re-baselining: the choice of the universal '
        .. 'rests on this equality.')
    assert(SWEEP['r_all'] < SWEEP['r_first'],
        'the universal no longer differs from `[1]` on the responder sites, so '
        .. 'this lever moves nothing that matters')
    cs.ratchet(SWEEP['r_first'], 19, 'responder sites `[1]` admits')
    cs.ratchet(SWEEP['r_all'], 16, 'responder sites the universal admits')
end

tests['[tpdefall] 4e. the collision that reverted the change'] = function()
    -- ⛔ THE WEAKEST PIN IN THIS FILE, and it is labelled so rather than dressed
    -- up. The collision was MEASURED (the universal, landed for one round, made
    -- tests/test_tparrive_collapse_gate.lua and
    -- tests/test_midsupyield_core_yields.lua red -- see the header). It cannot
    -- be RE-measured here, because the code that caused it is gone. So what
    -- this section pins is the PRECONDITION: both sibling files still exist and
    -- still lean on the host firing on their frames. If either is rewritten,
    -- this goes red and the next attempt learns that its cost estimate is
    -- stale -- which is the only job a pin over absent code can honestly do.
    local sib = {
        { 'tests/test_tparrive_collapse_gate.lua',
          'parity: both arms respond',
          "tparrive's `parity` control frame" },
        { 'tests/test_midsupyield_core_yields.lua',
          'midtp alone must answer a front here',
          "midsupyield's NODROP frame" },
    }
    for _, e in ipairs(sib) do
        local f = io.open(e[1], 'r')
        assert(f ~= nil, e[1] .. ' is gone; ' .. e[3] .. ' was one of the two '
            .. 'reasons this round reverted rather than landed')
        local text = f:read('*a')
        f:close()
        assert(text:find(e[2], 1, true) ~= nil,
            e[1] .. ' no longer asserts "' .. e[2] .. '". ' .. e[3] .. ' is one '
            .. 'of the two frames a universal at this site withdraws, so the '
            .. 'revert recorded in this file was priced against a version of '
            .. 'that file which no longer exists -- re-price before re-landing.')
    end
end

tests['[tpdefall] 5. shipped play is untouched'] = function()
    local host = block('function J.ShouldTpSupportTowerFight( bot )')
    -- Turbo first, then the candidate disjunction, both as EARLY RETURNS ahead
    -- of anything this change can reach.
    local iTurbo = host:find('if not J.IsModeTurbo() then return nil end', 1, true)
    local iGate  = host:find("if not ( J.IsSoakCandidate( 'midtp' ) or bSup ) then return nil end", 1, true)
    local iSite  = host:find('J.SafeToCommitFight( bot, tEnemies[1] )', 1, true)
    assert(iTurbo ~= nil, 'the host no longer opens with the turbo guard')
    assert(iGate ~= nil, 'the host no longer opens with the midtp/suptp guard')
    assert(iTurbo < iGate and iGate < iSite,
        'the turbo/candidate early returns no longer precede the narrowed site, '
        .. 'so this change is no longer inert in shipped play')
    -- ⛔ AND THE STANDING CONSTRAINT ON WHOEVER LANDS THE NEXT ATTEMPT: any
    -- narrowing of this site must edit the HOST's body and inherit the host's
    -- ids. The host is itself gated on the unpromoted 'midtp' (or 'suptp'), so
    -- a nested J.IsSoakCandidate would be `(midtp or suptp) AND <new>` and a
    -- wave arming <new> alone would read a STRUCTURALLY IMPOSSIBLE 0 that
    -- check_armed_wiring.py still calls WIRED (GH #606; the #576/#600/#607
    -- family). That is the 0OVERCHASE rule, test_set.md §FY.
end

tests['[tpdefall] 6. the tparrive leg is still un-repaired, on purpose'] = function()
    local host = block('function J.ShouldTpSupportTowerFight( bot )')
    assert(host:find('J.SafeToCommitFightOnArrival( bot, tEnemies[1] )', 1, true) ~= nil,
        'the tparrive leg no longer reads tEnemies[1]. If someone repaired it, '
        .. 'delete this section and the REGISTERED CONSEQUENCE note in the '
        .. 'header -- but do not delete it silently: it was left arbitrary on '
        .. 'purpose so that only one lever moved in this change.')
end

return tests

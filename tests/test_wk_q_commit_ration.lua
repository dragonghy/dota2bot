-- [hero] `wkqcommit` -- X.ConsiderQ's 打架时先手 firing point rations Wraithfire
-- Blast a SECOND time, after the function's own reserve rule has already cleared
-- the frame, and the first term of that rationing layer cannot be true before
-- hero level 14 under this file's own build row.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_skeleton_king.lua X.ConsiderQ, 打架时先手.  The outer `if`
-- has already established that the bot is going on someone, that the target is
-- a valid hero inside `nCastRange + 80`, castable, not disabled and not
-- disarmed.  What it asks next is a branch-local permission set:
--
--     nSkillLV >= 3  or  nMP > 0.68  or  GetHP(target) < 0.38  or  nHP < 0.25
--
--   1. `nSkillLV >= 3` is UNREACHABLE before hero level 14.  §1 derives that
--      through the real J.Skill.GetSkillList rather than re-typing it: Q's
--      points land at hero levels 2 / 13 / 14 / 16, so the term is constant
--      FALSE for hero 1-13, which in turbo is essentially the whole game.
--
--   2. `nMP > 0.68` re-asks a question the FIRST line of the same function has
--      already answered.  X.ShouldSaveMana refuses outright when the pool would
--      drop under Reincarnation's price, so every frame that reaches this
--      branch has been cleared by this file's OWN declared reserve rule.  §2
--      asserts that ordering out of the source so the argument cannot go stale.
--
-- ARMED (`wkqcommit`, turbo only) adds a fifth disjunct that drops the
-- branch-local layer and leaves the reserve rule as the mana authority for a
-- cast the bot is already committed to.  Nothing is edited: the four shipped
-- disjuncts stay exactly as they are, so gate off the site is byte-for-byte
-- the shipped one (§4) and armed is a strict SUPERSET (§3.3).
--
-- ===========================================================================
-- §0.1  THE READING (three real frames, the real hero file, no injection)
-- ===========================================================================
--
--     51 live Wraith King instants over tests/fixtures/ + tests/frames/
--  -> 48 priced (3 carry no abilities list; their rank 0 is an ABSENCE and
--     would manufacture a reading -- same corpus split
--     tests/test_wk_save_mana_lock_census.lua §1 defines, for the same reason)
--  -> 27 reach the function body (Blast castable AND X.ShouldSaveMana false)
--  ->  3 have ALL THREE own-state disjuncts false:
--
--       f_260909_215040_wk_blast_lane_121  hero 3, Q rank 1, R RANK 0,
--                                          mana 194/327 = 0.59
--       f_260909_215040_wk_blast_mid_269   hero 5, Q rank 1, R RANK 0,
--                                          mana 124/363 = 0.34, hp 0.67
--       f_260820_102645_cm_laning_release  hero 9, Q rank 1, R rank 1 on a
--                                          94.9s cooldown, mana 179/411 = 0.44
--
-- On the first two Reincarnation is UNLEARNED; on the third it is 95 seconds
-- away.  On all three the mana the 0.68 floor protects is not spoken for by
-- anything on the frame.  The other 24 are identical under both legs.
--
-- ===========================================================================
-- §0.2  WHAT THIS FILE CANNOT SHOW, stated rather than papered
-- ===========================================================================
--
--   1. The fourth shipped disjunct is about the TARGET (`J.GetHP( npcTarget )
--      < 0.38`) and the target comes from J.GetProperTarget, a mode-dependent
--      read that is not on an archived frame.  The 3 above are frames where the
--      three OWN-STATE disjuncts are false; 3 is therefore an UPPER BOUND on
--      the domain, not a count of cast changes.
--   2. `J.IsGoingOnSomeone` is a mode predicate and reads false on every
--      archived frame, so this corpus cannot show the BRANCH firing.  What §3
--      measures is the PERMISSION SET -- the half this lever changes.  §5
--      asserts that limit so it cannot quietly go stale.
--   3. 3 frames is a DOMAIN, not a frequency.  Sizing needs a wave
--      (iterations/queue.json hero-64).
--
-- Run:  lua5.1 tests/run_tests.lua wk_q_commit_ration

package.path = 'tests/?.lua;' .. package.path
local skillmap = require('skill_level_map')
local rf = require('mock.replay_fixture')

local HERO_SRC    = 'bots/BotLib/hero_skeleton_king.lua'
local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'
local UNIT        = 'npc_dota_hero_skeleton_king'
local CAND        = 'wkqcommit'
local HELPER      = 'wk_IsCommitBlastPermitted'
local Q_SLOT      = 1
local Q_NAME      = 'skeleton_king_hellfire_blast'
local R_NAME      = 'skeleton_king_reincarnation'

--- The three frames §0.1 names.  Written down so §3 fails loudly if a future
--- corpus edit removes one, rather than silently measuring a smaller domain.
local DOMAIN_FRAMES = {
    'tests/frames/f_260909_215040_wk_blast_lane_121.lua',
    'tests/frames/f_260909_215040_wk_blast_mid_269.lua',
    'tests/fixtures/f_260820_102645_cm_laning_release.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Both corpus directories, enumerated -- never a hardcoded list.  An empty
--- enumerator and an empty corpus are the same integer; the assert is the only
--- thing that tells them apart.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
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

--- Does this frame carry a Wraith King, and does it price him?  Reads the raw
--- fixture table, because "the abilities list is absent" is exactly the thing a
--- loaded handle cannot tell you apart from "rank 0".
local function wk_row(path)
    local ok, fx = pcall(dofile, path)
    if not ok or type(fx) ~= 'table' or type(fx.units) ~= 'table' then return nil end
    for _, u in ipairs(fx.units) do
        if u.name == UNIT and u.alive then return u, fx end
    end
    return nil
end

local function ability_of(u, sName)
    for _, a in ipairs(u.abilities or {}) do
        if a.name == sName then return a end
    end
    return nil
end

--- Load one frame with Wraith King as subject and arm (or not) the candidate.
local function frame(path, bArmed)
    local J, bot, heroes = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    local X = rf.load_hero('skeleton_king')
    return J, bot, X, heroes
end

local function function_body(src, sName)
    local from = src:find('\nfunction%s+' .. sName .. '%s*%(')
    assert(from, sName .. ' is gone from the source this test reads')
    local rest = src:sub(from + 1)
    local to = rest:find('\nend\n')
    assert(to, sName .. ' has no closing end')
    return rest:sub(1, to)
end

-- ---------------------------------------------------------------- section 1 --
-- The rank term, driven through the shipped level-up list.

tests['§1.1 Q reaches rank 3 only at hero level 14 under the shipped build row'] = function()
    local src = read_file(HERO_SRC)
    local row = skillmap.build_row(src, 1)
    local ladder = skillmap.rank_ladder('skeleton_king', row, skillmap.talent_rows(src))
    local q = ladder[Q_SLOT]

    assert(q[1] ~= nil, 'the driven ladder never learns Q at all')
    assert(q[3] ~= nil,
        'Q never reaches rank 3 on the driven ladder -- the shipped `nSkillLV '
        .. '>= 3` term is not merely late, it is unreachable.  Re-read §0 '
        .. 'before keeping this file.')
    assert(q[3] == 14, string.format(
        'Q reaches rank 3 at hero level %d, not 14.  The build row moved; '
        .. 'the `wkqcommit` block in ' .. HERO_SRC .. ' quotes 14 and must be '
        .. 're-read, not patched here.', q[3]))
    assert(q[1] == 2, string.format('Q is learned at hero level %d, not 2', q[1]))
    assert(q[2] == 13, string.format('Q reaches rank 2 at hero level %d, not 13', q[2]))
end

tests['§1.2 so the rank term is constant FALSE for hero levels 1-13'] = function()
    local src = read_file(HERO_SRC)
    local row = skillmap.build_row(src, 1)
    local talents = skillmap.talent_rows(src)
    for lv = 1, 13 do
        local ranks = skillmap.ranks_at('skeleton_king', row, talents, lv)
        local rank = ranks[Q_SLOT] or 0
        assert(rank < 3, string.format(
            'Q is rank %d at hero level %d -- the "unreachable before 14" half '
            .. 'of §0 is gone', rank, lv))
    end
end

-- ---------------------------------------------------------------- section 2 --
-- The mana term re-asks a question line one of the same function answered.

tests['§2.1 X.ShouldSaveMana is consulted before the branch, not after'] = function()
    local src = read_file(HERO_SRC)
    local body = function_body(src, 'X%.ConsiderQ')

    local iReserve = body:find('ShouldSaveMana', 1, true)
    local iBranch  = body:find('nMP > 0.68', 1, true)
    assert(iReserve, 'X.ConsiderQ no longer consults X.ShouldSaveMana at all')
    assert(iBranch, 'the 0.68 permission term is gone from X.ConsiderQ -- if a '
        .. 'round repaired it, retire `' .. CAND .. '` rather than keeping two answers')
    assert(iReserve < iBranch,
        'X.ShouldSaveMana is no longer asked BEFORE the branch-local mana '
        .. 'floor.  The whole "already cleared by the file\'s own reserve rule" '
        .. 'argument in §0 rests on this ordering.')
end

tests['§2.2 the reserve rule really is a mana refusal, not a name that moved'] = function()
    local src = read_file(HERO_SRC)
    local body = function_body(src, 'X%.ShouldSaveMana')
    assert(body:find('GetManaCost', 1, true),
        'X.ShouldSaveMana no longer reads a mana cost')
    assert(body:find('abilityR', 1, true),
        'X.ShouldSaveMana no longer reserves against Reincarnation')
end

-- ---------------------------------------------------------------- section 3 --
-- The domain, over the whole corpus, through the real loader and hero file.

--- Walk the corpus once and bucket every live Wraith King instant.  Returns the
--- four counts §0.1 quotes plus the domain paths it found.
local function census()
    local n_live, n_priced, n_body = 0, 0, 0
    local domain = {}
    for _, path in ipairs(corpus_paths()) do
        local u = wk_row(path)
        if u ~= nil then
            n_live = n_live + 1
            local q = ability_of(u, Q_NAME)
            if q ~= nil then
                n_priced = n_priced + 1
                local J, bot, X = frame(path, false)
                -- primes the file-level nLV/nMP/nHP that X.ShouldSaveMana reads
                -- (the same call tests/test_wk_save_mana_lock_census.lua makes,
                -- and for the same reason: those locals are assigned in the
                -- think entry point, not at load).
                pcall(function() X.SkillsComplement() end)
                local abilityQ = bot:GetAbilityByName(Q_NAME)
                local abilityR = bot:GetAbilityByName(R_NAME)
                if abilityQ ~= nil and abilityQ:IsFullyCastable()
                    and not X.ShouldSaveMana(abilityQ)
                then
                    n_body = n_body + 1
                    -- the three OWN-STATE disjuncts, read off the loaded frame
                    local nSkillLV = abilityQ:GetLevel()
                    local nMP = bot:GetMana() / math.max(1, bot:GetMaxMana())
                    local nHP = bot:GetHealth() / math.max(1, bot:GetMaxHealth())
                    if not (nSkillLV >= 3 or nMP > 0.68 or nHP < 0.25) then
                        domain[#domain + 1] = {
                            path = path, lv = bot:GetLevel(), q = nSkillLV,
                            r = abilityR ~= nil and abilityR:GetLevel() or -1,
                            mp = nMP, hp = nHP,
                        }
                    end
                end
            end
        end
    end
    return n_live, n_priced, n_body, domain
end

tests['§3.1 the corpus split is the one §0.1 quotes'] = function()
    local n_live, n_priced, n_body, domain = census()
    assert(n_live == 51, string.format('live Wraith King instants: %d, not 51', n_live))
    assert(n_priced == 48, string.format('priced instants: %d, not 48', n_priced))
    assert(n_body == 27, string.format('instants reaching the body: %d, not 27', n_body))
    assert(#domain == 3, string.format(
        'domain frames: %d, not 3.  A corpus edit moved the reading; re-read '
        .. 'it into the `wkqcommit` block rather than relaxing this number.',
        #domain))
end

tests['§3.2 the domain frames are the three named ones, at the stated state'] = function()
    local _, _, _, domain = census()
    local byPath = {}
    for _, d in ipairs(domain) do byPath[d.path] = d end
    for _, want in ipairs(DOMAIN_FRAMES) do
        assert(byPath[want] ~= nil, 'expected domain frame missing: ' .. want)
    end
    local lane = byPath['tests/frames/f_260909_215040_wk_blast_lane_121.lua']
    local mid  = byPath['tests/frames/f_260909_215040_wk_blast_mid_269.lua']
    assert(lane.lv == 3 and lane.q == 1 and lane.r == 0, string.format(
        'lane_121: hero %d, Q rank %d, R rank %d -- §0.1 says 3 / 1 / 0',
        lane.lv, lane.q, lane.r))
    assert(mid.lv == 5 and mid.q == 1 and mid.r == 0, string.format(
        'mid_269: hero %d, Q rank %d, R rank %d -- §0.1 says 5 / 1 / 0',
        mid.lv, mid.q, mid.r))
    -- The load-bearing half of condition (c): on both, Reincarnation is
    -- UNLEARNED, so the mana the 0.68 floor protects has nothing to protect.
    assert(lane.r == 0 and mid.r == 0,
        'Reincarnation is trained on a frame §0 calls unlearned -- the '
        .. '"holding mana for an ultimate the hero has not learned" argument '
        .. 'no longer describes these frames')
end

tests['§3.3 the two legs: gate off FALSE, armed TRUE, on every domain frame'] = function()
    local _, _, _, domain = census()
    assert(#domain > 0, 'no domain frames -- §3.1 should have caught this first')
    for _, d in ipairs(domain) do
        local _, _, Xoff = frame(d.path, false)
        assert(Xoff[HELPER]() == false, string.format(
            '%s: gate off, X.%s answered true -- the shipped disjunction is no '
            .. 'longer reproduced byte for byte', d.path, HELPER))
        local _, _, Xon = frame(d.path, true)
        assert(Xon[HELPER]() == true, string.format(
            '%s: armed, X.%s answered false -- the lever is inert on the very '
            .. 'frames it was cut for', d.path, HELPER))
    end
end

tests['§3.4 armed never WITHHOLDS: the release set is a strict superset'] = function()
    -- Direction is a property of the shape, not of today\'s arithmetic: the
    -- helper joins the disjunction with `or`, so for every input the armed
    -- answer is `shipped or <helper>`.  Assert the shape, in the source.
    local src = read_file(HERO_SRC)
    local body = function_body(src, 'X%.ConsiderQ')
    local site = body:match('nSkillLV >= 3[^\n]*\n[^\n]*' .. HELPER .. '[^\n]*')
    assert(site ~= nil,
        'the ' .. HELPER .. ' call is no longer on the line after the shipped '
        .. 'disjunction -- if it moved into a conjunct the direction argument '
        .. 'in §0 reverses and must be rewritten')
    assert(site:find('\n%s*or%s+X%.' .. HELPER),
        'the ' .. HELPER .. ' call is joined by something other than `or`; a '
        .. 'widening lever that can WITHHOLD a cast is a different lever')
end

-- ---------------------------------------------------------------- section 4 --
-- Wiring and gate hygiene.

tests['§4.1 the helper names exactly one candidate, and it is this one'] = function()
    local src = read_file(HERO_SRC)
    local body = function_body(src, 'X%.' .. HELPER)
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'") do ids[#ids + 1] = id end
    assert(#ids == 1, string.format(
        'X.%s names %d candidate ids.  A gate that names a SECOND id freezes '
        .. 'FALSE the day that id is promoted -- the `pullcad` trap.',
        HELPER, #ids))
    assert(ids[1] == CAND, 'X.' .. HELPER .. ' names ' .. ids[1] .. ', not ' .. CAND)
    assert(body:find('IsModeTurbo', 1, true),
        'X.' .. HELPER .. ' is no longer turbo-only')
end

tests['§4.2 the call site exists and is the only one'] = function()
    local src = read_file(HERO_SRC)
    local n = 0
    for _ in src:gmatch('X%.' .. HELPER .. '%s*%(') do n = n + 1 end
    -- the `X.<name>(` spelling occurs twice: the definition and the one call.
    -- A third occurrence is a second caller, and the §3 domain reading is about
    -- ONE branch -- a second caller measures something else.
    assert(n == 2, string.format(
        '%d occurrences of `X.%s(` (expected exactly 2: the definition and one '
        .. 'call site).', n, HELPER))
end

tests['§4.3 the id is registered in iterations/state.json'] = function()
    local body = read_file('iterations/state.json')
    assert(body:find(CAND, 1, true),
        CAND .. ' is not registered in iterations/state.json.  An unregistered '
        .. 'id cannot be armed by a wave and cannot be judged.')
end

-- ---------------------------------------------------------------- section 5 --
-- The limits, asserted so they cannot quietly go stale.

tests['§5.1 the branch itself cannot fire offline: IsGoingOnSomeone is dead'] = function()
    local J, bot = frame(DOMAIN_FRAMES[1], false)
    assert(J.IsGoingOnSomeone(bot) == false,
        'J.IsGoingOnSomeone now answers true on an archived frame.  Limit 2 of '
        .. '§0.2 is gone: this file could measure the BRANCH, not only the '
        .. 'permission set -- rewrite §3 rather than deleting this assert.')
end

tests['§5.2 the target-side disjunct is genuinely unreadable here'] = function()
    local J, bot = frame(DOMAIN_FRAMES[1], false)
    local t = J.GetProperTarget(bot)
    assert(t == nil or not t.GetHealth,
        'J.GetProperTarget now returns a usable handle on an archived frame.  '
        .. 'Limit 1 of §0.2 is gone: the 4th disjunct can be read and the '
        .. 'domain is no longer an upper bound -- re-measure it.')
end

return tests

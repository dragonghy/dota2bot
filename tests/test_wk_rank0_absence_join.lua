-- Two files read the SAME two Wraith King frames and disagree about what
-- "Reincarnation at ability level 0" means. This file joins them and says which
-- reading is right.
--
-- THE CONTRADICTION, verbatim from the tree
-- -----------------------------------------
--   * tests/test_wk_save_mana_lock_census.lua section 1 EXCLUDES 3 of the 36
--     Wraith King frames because their fixture carries no abilities list, and
--     writes that "two of the three are level >= 6, which is what makes them
--     dangerous rather than merely useless" -- i.e. rank 0 there is an ABSENCE.
--   * tests/test_wkreinctr_untrained.lua's header reads the same shape as DATA:
--     "24 of the 36 live Wraith King frames answer TRUE, and 14 of those 24 --
--     58% of every TRUE this function produces -- sit on a Reincarnation at
--     ability level 0. Two of the 14 are at HERO level 7."
--
-- Both "2"s are asserted numbers in the suite (`at_six == 2` there,
-- `C.ship_true_untrained_lv6 == 2` here). A count cannot tell you it is the
-- same count. Section 2 joins them BY FIXTURE NAME, as a set equality, and they
-- are the same two files.
--
-- ⭐ THE ANSWER: the census reading is right, and it is right for a reason that
-- is in the loader, not in the numbers. tests/mock/replay_fixture.lua installs
-- every ability reader inside `for i, a in ipairs(u.abilities or {})`. A unit
-- with NO abilities list runs that loop zero times, so the handle
-- GetAbilityByName hands back carries no installed reader at all and every read
-- falls through to tests/mock/bot_api.lua's generic defaults -- `^Get` answers
-- 0, `^Is` answers false. GetLevel() 0, IsTrained() false,
-- GetCooldownTimeRemaining() 0, GetManaCost() 0: the four answers a genuinely
-- unlearned ultimate gives, produced by a unit that recorded nothing. Section 1
-- drives that instead of arguing it.
--
-- ⭐⭐ AND THE JOIN CHANGES A DOMAIN READING, which is why this is worth a file
-- rather than a comment fix. 'wkreinctr' flips 14 frames at the helper; its
-- call site (mode_retreat_generic.lua ~:198, SHIPPED) carries its own
-- `bot:GetLevel() >= 6`. Section 3 measures how those 14 split:
--     12 are PRICED -- their rank 0 is real recorded data -- and every one of
--        them is at hero level <= 5, where Reincarnation CANNOT be learned yet.
--        The call site's own guard rejects all 12.
--      2 clear `GetLevel() >= 6`, and both of them are the absence frames.
-- So this corpus holds ZERO frames of the shape the lever exists for (a hero at
-- level >= 6 with a genuinely unspent ultimate point). The sibling file
-- attributes its call-site zero entirely to `J.IsInTeamFight(bot, 1200)` being
-- false on all 36 -- true, and not the only barrier: forcing that conjunct TRUE
-- would leave a domain of 2, and both of those 2 are absences.
--
-- WHAT IS NOT CLAIMED HERE, stated up front:
--   * NOTHING about whether 'wkreinctr' is a good lever. Adding
--     `abilityR:IsTrained()` next to a GetAbilityByName handle is the pattern
--     the same function already uses twice (huskar, axeblink); this file does
--     not touch that argument. What moves is the EVIDENCE for its domain.
--   * No edit to 'wkreinctr' or to its files. It is another stream's landed id
--     (GH #582); this file delivers the reading, not the repair. bots/ is
--     untouched by this work unit on purpose, and section 6 asserts that.
--   * Nothing about how often the shape occurs in a GAME. A fixture corpus is a
--     set of instants cut for other reasons.
--
-- SECTIONS
--   1  the mechanism: an absent abilities list is read as rank 0, driven
--   2  the join: the census's 2 and the sweep's 2 are the same two files
--   3  the split of the 14, and the hero-level 6 line that cuts it
--   4  the call site's own guard is really there, and it is what does the cut
--   5  the discriminator: the format CAN carry a real rank 0, and does
--   6  what this work unit did not do

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local WK = 'npc_dota_hero_skeleton_king'
local R = 'skeleton_king_reincarnation'
-- The call site's own hero-level conjunct. Named once; section 4 asserts it is
-- still the number in the shipped tree before section 3 cuts anything by it.
local SITE_LEVEL = 6

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

-- Structural facts are claims about CODE, and both files joined here ship long
-- headers that quote the very lines being asserted. Reading the raw text would
-- let a COMMENT satisfy the assertion.
local function strip_comments(s) return (s:gsub('%-%-[^\n]*', '')) end

local function fixture_files()
    local files = {}
    local p = assert(io.popen('ls tests/fixtures'))
    for line in p:lines() do
        if line:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. line end
    end
    p:close()
    table.sort(files)
    return files
end

local function short(path) return (path:match('([^/]+)%.lua$')) end

local function sorted_names(t)
    local out = {}
    for _, r in ipairs(t) do out[#out + 1] = short(r.path) end
    table.sort(out)
    return out
end

local function joined(t) return table.concat(t, ', ') end

--- The whole corpus, read TWICE per Wraith King frame and both readings kept.
---
--- The `raw` half comes straight out of the fixture table: what make_fixture.py
--- actually wrote down. The `driven` half comes through the loader and the
--- SHIPPED helper. Keeping both is the point of the file -- the disagreement
--- under investigation is exactly a case where the driven read answers a number
--- the raw read never recorded, and a census that only ever drives cannot see
--- the difference.
local corpus_cache = nil
local function corpus()
    if corpus_cache ~= nil then return corpus_cache end
    local rows, nFixtures = {}, 0
    for _, path in ipairs(fixture_files()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            nFixtures = nFixtures + 1
            for _, u in ipairs(fx.units) do
                if u.name == WK and u.alive then
                    -- RAW: the recorded ability row, or nil if the unit carries
                    -- no abilities list at all. `raw_rank == nil` is the ABSENCE
                    -- and it is a different value from `raw_rank == 0`; every
                    -- claim below that turns on the distinction reads this field
                    -- and never the driven one.
                    local raw_rank = nil
                    if type(u.abilities) == 'table' then
                        for _, a in ipairs(u.abilities) do
                            if a.name == R then raw_rank = a.level end
                        end
                    end
                    local okL, J, bot = pcall(rf.load, path, WK)
                    if okL and bot ~= nil then
                        local hR = bot:GetAbilityByName(R)
                        J.IsSoakCandidate = function() return false end
                        local okS, shipped = pcall(J.IsWkReincarnationArmed, bot)
                        rows[#rows + 1] = {
                            path = path,
                            priced = (type(u.abilities) == 'table'),
                            raw_rank = raw_rank,
                            raw_level = u.level,
                            level = bot:GetLevel(),
                            spec = rawget(hR, '__spec'),
                            rank = hR:GetLevel(),
                            trained = hR:IsTrained() and true or false,
                            cd = hR:GetCooldownTimeRemaining(),
                            mana = bot:GetMana(),
                            ship = (okS and shipped) and true or false,
                        }
                    end
                    break
                end
            end
        end
    end
    corpus_cache = { rows = rows, fixtures = nFixtures }
    return corpus_cache
end

local function select_rows(fPred)
    local out = {}
    for _, r in ipairs(corpus().rows) do
        if fPred(r) then out[#out + 1] = r end
    end
    return out
end

-- ==========================================================================
-- 1. The mechanism: an absent abilities list reads as rank 0
-- ==========================================================================

tests['[mech] the loader installs ability readers in exactly one place, inside the abilities loop'] =
function()
    local src = strip_comments(read_file('tests/mock/replay_fixture.lua'))
    local at = assert(src:find('ipairs(u.abilities or {})', 1, true),
        'tests/mock/replay_fixture.lua no longer walks `u.abilities or {}` -- '
        .. 'the whole absence mechanism this file settles hangs off that `or {}`')
    -- ONE install site, and it is downstream of the loop header. A second one
    -- somewhere else could give an abilities-less unit real readers, and then
    -- "rank 0 is an absence" would stop being a property of the loader.
    for _, sKey in ipairs({ 'sp.GetLevel', 'sp.IsTrained' }) do
        local n, first = 0, nil
        for pos in src:gmatch('()' .. sKey:gsub('%.', '%%.') .. '%s*=') do
            n = n + 1
            first = first or pos
        end
        assert(n == 1, sKey .. ' is now assigned at ' .. n .. ' sites in the '
            .. 'loader, not 1 -- a second install path means an abilities-less '
            .. 'unit may get real readers, and section 2 must be re-derived')
        assert(first > at, sKey .. ' is now assigned BEFORE the abilities loop, '
            .. 'so it no longer depends on the unit carrying an abilities list')
    end
end

tests['[mech] on an absence frame the handle carries no reader, yet answers like an unlearned ult'] =
function()
    local absent = select_rows(function(r) return not r.priced end)
    assert(#absent > 0, 'no Wraith King frame lacks an abilities list any more. '
        .. 'If the three v1 fixtures were re-cut with abilities, this whole '
        .. 'file is settled and every count in the census and the wkreinctr '
        .. 'sweep moves -- re-read them, do not delete this')
    for _, r in ipairs(absent) do
        local sp = r.spec
        assert(sp ~= nil, short(r.path) .. ': the ability handle has no __spec '
            .. 'table at all, which is not the shape this mechanism assumes')
        -- The load-bearing half: NOTHING was installed.
        for _, sKey in ipairs({ 'GetLevel', 'IsTrained', 'GetManaCost',
            'GetCooldownTimeRemaining' }) do
            assert(rawget(sp, sKey) == nil, short(r.path) .. ': the loader now '
                .. 'installs ' .. sKey .. ' on a unit with no abilities list, '
                .. 'so its reads are recorded data and this frame belongs in '
                .. 'the priced set')
        end
        -- ...and yet all four reads answer, from bot_api's generic defaults.
        assert(r.rank == 0 and r.trained == false and r.cd == 0,
            short(r.path) .. ' now answers rank=' .. tostring(r.rank)
            .. ' trained=' .. tostring(r.trained) .. ' cd=' .. tostring(r.cd)
            .. '; it used to answer 0/false/0 with nothing installed, which is '
            .. 'what makes an absence indistinguishable from an unlearned ult')
        assert(r.raw_rank == nil, short(r.path) .. ' now records a '
            .. 'Reincarnation rank in the fixture (' .. tostring(r.raw_rank)
            .. '), so its 0 is data and not an absence')
    end
end

tests['[mech] the same four answers come from a name that is in no fixture at all'] =
function()
    -- The control that separates "these are R's answers" from "these are the
    -- generic default's answers". Same reads, on a PRICED frame, against an
    -- ability name nothing in the tree owns: identical. That is the proof the
    -- absence frames are reading the default and not something Reincarnation
    -- specific (the GH #386 / #391 shape -- an unspecced getter answering 0).
    local priced = select_rows(function(r) return r.priced end)
    assert(#priced > 0, 'no priced Wraith King frame left to run the control on')
    local _, bot = rf.load(priced[1].path, WK)
    local hNone = bot:GetAbilityByName('skeleton_king_no_such_ability')
    assert(hNone ~= nil, 'the mock no longer hands back a handle for an unknown '
        .. 'ability name; if it answers nil now, an absent ability is '
        .. 'distinguishable from an unlearned one and the shipped `abilityR == '
        .. 'nil` guard already covers this case')
    assert(hNone:GetLevel() == 0 and hNone:IsTrained() == false
        and hNone:GetCooldownTimeRemaining() == 0 and hNone:GetManaCost() == 0,
        'the generic default no longer answers 0/false/0/0 for an unknown '
        .. 'ability -- re-derive section 1 before quoting it')
end

-- ==========================================================================
-- 2. The join: the census's "2" and the sweep's "2" are the same two files
-- ==========================================================================

tests['[join] the two 2s name the same two fixtures, as a set'] = function()
    -- Set A -- the census's phrasing: frames with no abilities list, at hero
    -- level >= 6. ("two of the three are level >= 6")
    local A = select_rows(function(r)
        return (not r.priced) and r.level >= SITE_LEVEL
    end)
    -- Set B -- the wkreinctr sweep's phrasing, computed the way its own loop
    -- computes `ship_true_untrained_lv6`: shipped TRUE, untrained, hero level
    -- >= 6. ("Two of the 14 are at HERO level 7")
    local B = select_rows(function(r)
        return r.ship and (not r.trained) and r.level >= SITE_LEVEL
    end)
    -- ⭐ SET EQUALITY, NOT COUNT EQUALITY. Two counts that agree agree for one
    -- round and then drift; and a count is exactly the instrument that cannot
    -- answer the question this file was opened for. Both sides are named.
    assert(joined(sorted_names(A)) == joined(sorted_names(B)),
        'the two readings no longer name the same frames.  census-side {'
        .. joined(sorted_names(A)) .. '} vs wkreinctr-side {'
        .. joined(sorted_names(B)) .. '}.  If a frame is in B and not in A it '
        .. 'is a REAL untrained level-6 Wraith King and the lever finally has '
        .. 'a domain on this corpus -- measure it, do not re-baseline this line')
    assert(#A > 0, 'both sets are empty now; the contradiction this file '
        .. 'settles is gone and its finding must be re-read, not deleted')
end

tests['[join] every frame in that set is an absence, one at a time'] = function()
    local B = select_rows(function(r)
        return r.ship and (not r.trained) and r.level >= SITE_LEVEL
    end)
    for _, r in ipairs(B) do
        assert(not r.priced, short(r.path) .. ' is a PRICED frame that is '
            .. 'shipped-TRUE, untrained and at hero level >= ' .. SITE_LEVEL
            .. ' -- the first real member of this lever\'s domain in the '
            .. 'corpus.  That is a finding, not a broken assertion')
        assert(r.raw_rank == nil, short(r.path) .. ' now records a rank ('
            .. tostring(r.raw_rank) .. '); its 0 stopped being an absence')
    end
end

-- ==========================================================================
-- 3. The split of the 14, and the level-6 line that cuts it
-- ==========================================================================

tests['[split] the untrained frames split into real data and absence, and the counts reconcile'] =
function()
    local untrained = select_rows(function(r) return not r.trained end)
    local real = select_rows(function(r) return (not r.trained) and r.priced end)
    local absent = select_rows(function(r) return (not r.trained) and not r.priced end)
    assert(#real + #absent == #untrained, 'the two buckets sum to '
        .. (#real + #absent) .. ' but there are ' .. #untrained
        .. ' untrained frames')
    -- Sums over fixtures: they may rise with the corpus, never fall (GH #106 /
    -- #127, tests/corpus_scale.lua). Registered 2026-09-07 at 15 / 12 / 3.
    cs.corpus(corpus().fixtures, 'fixture corpus')
    cs.ratchet(#untrained, 15, 'untrained WK frames')
    cs.ratchet(#real, 12, 'untrained WK frames with a RECORDED rank 0')
    -- The absence bucket is the one that must NOT grow quietly: a new v1-shaped
    -- fixture would put another unreadable frame into every WK census in the
    -- suite. Registered as an equality on purpose.
    assert(#absent == 3, #absent .. ' Wraith King frames read untrained from an '
        .. 'ABSENT abilities list, recorded 3: {' .. joined(sorted_names(absent))
        .. '}.  A new one means a fixture was cut without abilities')
end

tests['[split] every RECORDED rank 0 sits below the level at which R can be learned'] =
function()
    -- Stated as a universal, not as `== 12`: it keeps holding over fixtures
    -- nobody has written yet, and the day it fails is the day the corpus
    -- acquires the frame this lever is actually about.
    local real = select_rows(function(r) return (not r.trained) and r.priced end)
    assert(#real > 0, 'no frame records a real rank-0 Reincarnation any more')
    for _, r in ipairs(real) do
        assert(r.level < SITE_LEVEL, short(r.path) .. ' records a real rank-0 '
            .. 'Reincarnation at hero level ' .. r.level .. ', i.e. at or above '
            .. SITE_LEVEL .. ' where the ultimate CAN be learned.  This is the '
            .. 'first genuine "level 6+ with an unspent ultimate point" frame '
            .. 'in the corpus -- GH #366 / #374 made the shape real, and the '
            .. 'wkreinctr domain reading must be re-taken from it')
    end
    -- The same zero the census already registered in its section 6, reproduced
    -- here from the RAW rank rather than the driven one, so the two files
    -- cannot both be reading the same artefact.
    local shape = select_rows(function(r)
        return r.priced and r.raw_rank == 0 and r.raw_level >= SITE_LEVEL
    end)
    assert(#shape == 0, #shape .. ' fixture(s) now RECORD a level >= '
        .. SITE_LEVEL .. ' Wraith King next to a rank-0 Reincarnation: {'
        .. joined(sorted_names(shape)) .. '}')
end

tests['[split] raw and driven agree wherever the fixture recorded anything'] = function()
    -- Without this the raw half of section 3 would be an unvalidated parallel
    -- reading of the corpus. Where a rank IS recorded, the loader must serve
    -- exactly it -- otherwise `raw_rank == nil` stops meaning "the loader had
    -- nothing to serve".
    local priced = select_rows(function(r) return r.priced and r.raw_rank ~= nil end)
    assert(#priced > 0, 'no priced frame records a Reincarnation row at all')
    for _, r in ipairs(priced) do
        assert(r.rank == r.raw_rank, short(r.path) .. ': the loader serves rank '
            .. tostring(r.rank) .. ' where the fixture recorded '
            .. tostring(r.raw_rank))
        assert(r.trained == (r.raw_rank > 0), short(r.path)
            .. ': IsTrained() and the recorded rank disagree')
        assert(r.level == r.raw_level, short(r.path) .. ': the loader serves '
            .. 'hero level ' .. tostring(r.level) .. ' where the fixture '
            .. 'recorded ' .. tostring(r.raw_level))
    end
end

-- ==========================================================================
-- 4. The call site's own guard is really there
-- ==========================================================================

tests['[site] the shipped call site still cuts by hero level 6, and by a team fight'] =
function()
    -- Section 3 cuts the 14 by SITE_LEVEL. That is only a statement about this
    -- lever if the shipped tree really cuts by it too -- read structurally,
    -- comment-stripped, because the helper's own header quotes the call site
    -- verbatim (the §EN mistake, and the M4 survivor of the 'lionearlyreturn'
    -- round: an offset assertion that ended up racing a COMMENT).
    local ret = strip_comments(read_file('bots/mode_retreat_generic.lua'))
    local at = assert(ret:find('J.IsWkReincarnationArmed(bot)', 1, true),
        'mode_retreat_generic no longer calls J.IsWkReincarnationArmed; with no '
        .. 'caller the level cut below describes nothing')
    local blk = ret:sub(math.max(1, at - 400), at + 200)
    assert(blk:find('bot:GetLevel() >= ' .. SITE_LEVEL, 1, true),
        'the call site no longer guards on `bot:GetLevel() >= ' .. SITE_LEVEL
        .. '` next to this helper.  Section 3 cuts the untrained frames by that '
        .. 'number; if it moved, the split moved with it')
    assert(blk:find('J.IsInTeamFight(bot, 1200)', 1, true),
        'the call site\'s team-fight conjunct moved.  It is the barrier the '
        .. 'sibling file names; this file\'s point is that it is not the only one')
end

tests['[site] the corpus reaches the level guard and still holds no real domain'] =
function()
    -- The anti-vacuum half: "no frame survives the cut" must be distinguishable
    -- from "no frame reached the cut". Plenty reach it.
    local at_level = select_rows(function(r) return r.level >= SITE_LEVEL end)
    cs.ratchet(#at_level, 23, 'WK frames at hero level >= 6')
    local survivors = select_rows(function(r)
        return r.level >= SITE_LEVEL and (not r.trained) and r.priced
    end)
    assert(#survivors == 0, #survivors .. ' frame(s) now clear the call site\'s '
        .. 'level guard with a RECORDED unspent ultimate: {'
        .. joined(sorted_names(survivors)) .. '}.  Until this is non-zero the '
        .. 'corpus cannot supply condition (a) for this lever, and a wave that '
        .. 'reads zero on it is reading "domain not reached" (GH #576)')
end

-- ==========================================================================
-- 5. The discriminator: the format CAN carry a real rank 0
-- ==========================================================================

tests['[format] a priced frame really does record a rank-0 Reincarnation'] = function()
    -- Without this, "those three frames are absences" could just as well be
    -- "make_fixture.py cannot record an unlearned ability", and the repair
    -- would be a dumper change rather than three re-cut fixtures. It can, and
    -- it did: section 3's `real` bucket is non-empty and section 3's
    -- raw/driven check proves those zeros survive the loader.
    local real = select_rows(function(r) return r.priced and r.raw_rank == 0 end)
    assert(#real > 0, 'no fixture records `{ name = \'' .. R
        .. '\', level = 0 }` any more.  The claim that the three v1 frames are '
        .. 'ABSENCES rests on the format being able to record a real 0; without '
        .. 'an instance, absence and inability read the same and section 2 must '
        .. 'be re-argued')
    -- Named, so the repair is a fixture re-cut and not a guess: these three
    -- files re-generated with make_fixture.py would move every WK census in
    -- the suite, including the two joined here.
    local absent = select_rows(function(r) return not r.priced end)
    assert(joined(sorted_names(absent))
        == 'f_073148_zuus_lina, f_080225_wk_lane, f_080225_wk_revive',
        'the frames without an abilities list are now {'
        .. joined(sorted_names(absent)) .. '}, recorded {f_073148_zuus_lina, '
        .. 'f_080225_wk_lane, f_080225_wk_revive} -- the same three the census '
        .. 'section 1 names')
end

-- ==========================================================================
-- 6. What this work unit did not do
-- ==========================================================================

tests['[absent] no gate was added, and the shipped helper still names its two ids'] =
function()
    local src = strip_comments(read_file('bots/FunLib/jmz_func.lua'))
    local at = assert(src:find('function J.IsWkReincarnationArmed( bot )', 1, true),
        'J.IsWkReincarnationArmed was renamed or removed')
    local blk = src:sub(at, (src:find('\nfunction ', at + 40)) or #src)
    local n = 0
    for _ in blk:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 2, 'J.IsWkReincarnationArmed now names ' .. n .. ' candidate '
        .. 'ids, not the 2 it carried when this file was written.  This work '
        .. 'unit delivered a READING of another stream\'s landed id and changed '
        .. 'no behaviour; a third id there is somebody else\'s change and the '
        .. 'reading above must be re-taken against it')
    -- This file drives the SHIPPED helper with the gate hard OFF. If it ever
    -- needs an armed leg it has stopped being an evidence file.
    --
    -- ⚠️ AND IT IS READ AS A PATTERN, NOT AS A LITERAL, FOR A REASON THAT COST
    -- THIS ASSERTION ITS FIRST RUN. The first version searched its own source
    -- for the plain string it was forbidding -- which the search argument then
    -- PUT into that source, so it fired on itself and reported an armed leg
    -- that does not exist. A file that greps itself must use a needle it cannot
    -- contain; the `%s*` classes below are literal characters in the source and
    -- match no whitespace, so the pattern cannot match its own text.
    local own = strip_comments(read_file('tests/test_wk_rank0_absence_join.lua'))
    local nAssign, sBody = 0, nil
    for body in own:gmatch('IsSoakCandidate%s*=%s*function%s*%(%s*%)%s*return%s+(%a+)') do
        nAssign = nAssign + 1
        sBody = body
    end
    assert(nAssign == 1, 'this file assigns J.IsSoakCandidate at ' .. nAssign
        .. ' sites, not the single one in corpus(); a second driver could arm '
        .. 'a leg the readings above are not taken under')
    assert(sBody == 'false', 'this file now drives the helper with a gate that '
        .. 'returns ' .. tostring(sBody) .. '; it measures the shipped tree only')
end

return tests

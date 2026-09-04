-- OWNER_PRIORITIES P1 / GH #241 -- the `.type` half of the GetNeutralSpawners
-- premise, and why the method that settled the `.team` half CANNOT settle it.
--
-- WHY THIS FILE EXISTS
-- -------------------
-- The charter's next slot said: before writing a guard against `camp.type`,
-- buy the premise the way §BN.4 bought `.team` -- "ask whether some already
-- measured behaviour has that predicate on its path". This file is that
-- attempt, carried out mechanically, and it answers NO, with a reason that is
-- structural rather than an accident of which waves we happen to have run.
--
-- §BN.4 infers a premise from an OBSERVED BEHAVIOUR: `.team` sits on an
-- ADMISSION DOOR -- J.ShouldPullNeutralCamp returns nil unless some camp
-- satisfies `camp.team == GetTeam()`, and the pull behaviour downstream is
-- reachable only through a non-nil return. So the refuting hypothesis
-- ("`.team` is not a team id") predicts that the behaviour is IMPOSSIBLE, and
-- 283 games of it happening refuted the hypothesis for free.
--
-- Every `.type` read in this repo has the OPPOSITE polarity. Each one is a
-- FILTER CLAUSE written as an exclusion (`... and lvl < 12 then return false`,
-- `or not IsAncientCamp(rec)`, `camp.type ~= "small"`), so the refuting
-- hypothesis ("`.type` is not one of those strings") makes every one of them
-- VACUOUSLY PERMISSIVE -- the camp passes. A permissive filter and an absent
-- filter emit the same games. "The behaviour happened" is exactly what the
-- refuter predicts too, so no amount of it separates the two.
--
--   ⇒ §BN.4 has a POLARITY PRECONDITION. It settles a premise only when the
--     refuting hypothesis makes the predicate FAIL CLOSED (nothing happens).
--     Where the predicate FAILS OPEN (everything passes) the method is
--     structurally silent, and reaching for it looks like diligence while
--     buying nothing. Ask which way the predicate fails BEFORE deciding
--     whether an online probe can be skipped.
--
-- That sentence is a claim about this repo's source, so this file asserts it
-- by RUNNING the shipped predicates twice -- once on a camp record whose
-- `.type` is the string the code compares against, once on the same record
-- with the INT the retired doc row claimed (`type (int)`, small/medium/large/
-- ancient) -- and comparing the ADMITTED SETS. Permissive is the machine-
-- checkable statement `admitted(string) is a subset of admitted(int)`, and it
-- is checked on every path, not argued in prose. The conclusion the charter
-- and docs/BOT_API_REFERENCE.md will carry ("no site fails closed") is itself
-- a COUNT computed here, so a future edit that makes one site fail closed
-- turns this file red instead of silently invalidating the prose.
--
-- WHAT THIS FILE DOES NOT CLAIM
-- -----------------------------
--   * It does NOT settle `.type`. It proves the free method cannot, and it
--     leaves the row `unverified`. The paid route is pre-registered in
--     test_set.md §EA-type / queue.json (strategy-43): campgrade's exclusive
--     wave already has to read own-side ancient engagements in the 10..11
--     band, and under the refuter that reading CANNOT move, because campgrade's
--     ancient tier is dead and its only surviving tier is the `.team` one.
--     So the settle rides a wave that is already owed -- zero extra AWS.
--   * It changes NO behaviour. bots/ and game/ are untouched by the commit
--     that adds it; the only non-test edit is the doc row.
--   * The camp records are a DECLARED STAND-IN, exactly as
--     tests/test_campsel_wrapper_fields.lua declares them, because
--     GetNeutralSpawners() answers `{}` on every corpus frame (world W1
--     below, re-asserted here rather than cited). The BOT half is real: every
--     level below comes off a real .dem frame.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

-- Real frames straddling every literal the shipped ladder states (7, 10, 12).
local L1  = { 'tests/fixtures/f_011405_jak_rescue_axe.lua',            'npc_dota_hero_axe',           1  }
local L9  = { 'tests/fixtures/f_045650_lion_meatgrinder.lua',          'npc_dota_hero_earthshaker',   9  }
local L10 = { 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua', 'npc_dota_hero_skeleton_king', 10 }
local L12 = { 'tests/fixtures/f_260820_162859_es_blink_flee_615.lua',  'npc_dota_hero_skeleton_king', 12 }

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    local bot = heroes[spec[2]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[2] .. ' -- ' .. spec[1])
    assert(bot:GetLevel() == spec[3], string.format(
        'fixture %s no longer puts %s at level %d (got %d) -- the level bands ' ..
        'below stop straddling the literals they were chosen for',
        spec[1], spec[2], spec[3], bot:GetLevel()))
    return J, bot
end

-- The two columns. STRING is what shipped code compares against; INT is the
-- refuter -- the annotation docs/BOT_API_REFERENCE.md carried until 2026-08-27
-- and was cited with ("type (int)" next to small/medium/large/ancient).
local TYPES  = { 'small', 'medium', 'large', 'ancient' }
local AS_INT = { small = 1, medium = 2, large = 3, ancient = 4 }

-- The 4x2 (tier, side) stand-in. `hyp` is 'string' or 'int'; nothing else
-- differs between the two tables, so every difference measured below is
-- attributable to `.type` and to nothing else.
local function camps_for(nOwnTeam, hyp)
    local out, i = {}, 0
    for _, team in ipairs({ nOwnTeam, nOwnTeam == 2 and 3 or 2 }) do
        for _, sType in ipairs(TYPES) do
            i = i + 1
            out['c' .. i] = {
                idx  = i,
                type = (hyp == 'int') and AS_INT[sType] or sType,
                team = team,
                location = Vector(100 * i, 100 * i, 0),
            }
        end
    end
    return out, i
end

local function with_camps(camps, fn)
    local prev = GetNeutralSpawners
    GetNeutralSpawners = function() return camps end -- luacheck: ignore
    local ok, err = pcall(fn)
    GetNeutralSpawners = prev -- luacheck: ignore
    if not ok then error(err, 0) end
end

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

-- The machine-checkable form of "fails open": the set admitted when `.type` is
-- the string is contained in the set admitted when `.type` is the refuting
-- int. Returns true/false plus the first idx that breaks it, so a failure
-- names the camp instead of only the verdict.
local function is_subset(a, b)
    for idx in pairs(a) do
        if not b[idx] then return false, idx end
    end
    return true, nil
end

--============================================================================
-- World facts. Both are re-measured here, not cited.
--============================================================================

tests['[world W1] the corpus carries no neutral spawners, so the camps are declared'] = function()
    local J, bot = subject(L10)
    local live = GetNeutralSpawners()
    assert(type(live) == 'table' and next(live) == nil,
        'GetNeutralSpawners() is no longer empty on a fixture -- if the dumper ' ..
        'started carrying the spawner table, this file should drive the real one, ' ..
        'and `.type` may then be settleable from the corpus alone')
    local _, n = J.Site.RefreshCamp(bot)
    assert(n == 0, 'with no camps in the world the shipped entry point returns an ' ..
        'empty list -- that is why the tables here are a declared stand-in')
end

tests['[world W2] Lua semantics: a non-string .type makes every shipped comparison permissive'] = function()
    -- The one-line reason the polarity argument holds for the source-only
    -- sites (hero_templar_assassin.lua), asserted rather than assumed. An
    -- equality against a string literal is FALSE for a number, and an
    -- inequality is TRUE -- so an exclusion clause written either way admits.
    assert((4 == 'ancient') == false, 'Lua stopped answering false for number == string')
    assert((1 ~= 'small') == true,    'Lua stopped answering true for number ~= string')
    assert((2 ~= 'medium') == true,   'Lua stopped answering true for number ~= string')
end

--============================================================================
-- The census. This is the ratchet: a NEW `.type` reader anywhere under bots/
-- turns this red, because the polarity claim below is a claim about a CLOSED
-- set of sites, and an unclassified site silently voids it.
--============================================================================

local function read(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local function strip_comments(src)
    src = src:gsub('%-%-%[%[.-%]%]', ' ')
    return (src:gsub('%-%-[^\n]*', ' '))
end

tests['[census] every `.type` read under bots/ is enumerated and classified'] = function()
    -- Measured 2026-09-04 over the whole shipped tree. The CAMP-RECORD rows
    -- are the subject of this file; the other three are `.type` on unrelated
    -- tables and are listed so that the census is over ALL of bots/ and not
    -- over a hand-picked subset (a subset census cannot notice a new reader
    -- that was named something else).
    local expect = {
        -- camp records off GetNeutralSpawners()
        ['bots/FunLib/aba_site.lua|camp']              = { 4, 'camp-record' },
        ['bots/BotLib/hero_templar_assassin.lua|camp'] = { 2, 'camp-record' },
        ['bots/BotLib/hero_templar_assassin.lua|loc']  = { 1, 'camp-record' },
        -- unrelated tables, listed to keep the census total
        ['bots/hero_selection.lua|cfg']                = { 3, 'unrelated' },
        ['bots/FretBots/HeroSounds.lua|sound']         = { 4, 'unrelated' },
        ['bots/mode_rune_generic.lua|rune']            = { 2, 'unrelated' },
    }
    local seen = {}
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for path in p:lines() do
        local src = strip_comments(read(path))
        for id in src:gmatch('([%w_]+)%.type') do
            local k = path .. '|' .. id
            seen[k] = (seen[k] or 0) + 1
        end
    end
    p:close()

    local nCampRecordSites = 0
    for k, v in pairs(seen) do
        assert(expect[k] ~= nil, 'a NEW `.type` reader appeared: ' .. k .. ' x' .. v ..
            ' -- classify it (camp-record or unrelated) and, if it reads a camp ' ..
            'record, add it to the polarity check below before editing this line')
        assert(expect[k][1] == v, string.format(
            '`.type` read count changed for %s: expected %d, found %d', k, expect[k][1], v))
    end
    for k, e in pairs(expect) do
        assert(seen[k] ~= nil, '`.type` reader disappeared: ' .. k ..
            ' -- if it was deleted, drop the row; the polarity claim is about a ' ..
            'closed set and must not quietly shrink')
        if e[2] == 'camp-record' then nCampRecordSites = nCampRecordSites + seen[k] end
    end
    assert(nCampRecordSites == 7, 'expected 7 camp-record `.type` reads, found ' ..
        nCampRecordSites)
end

tests['[census] the doc row undercounts hero_templar_assassin by one clause'] = function()
    -- docs/BOT_API_REFERENCE.md's `.type` row says "two clauses in
    -- hero_templar_assassin.lua". There are THREE, and the third is the one
    -- that matters most: :618/:619 filter a camp LIST, but the third gates a
    -- CAST (Psionic Trap placement) on `loc.type ~= 'ancient'`. A row that
    -- undercounts its own reader set is how a site escapes classification.
    local src = strip_comments(read('bots/BotLib/hero_templar_assassin.lua'))
    local n = 0
    for _ in src:gmatch('[%w_]+%.type') do n = n + 1 end
    assert(n == 3, 'hero_templar_assassin.lua `.type` reads changed: ' .. n)
    assert(src:find("camp%.type%s*~=%s*[\"']small[\"']"),   'the small clause moved')
    assert(src:find("camp%.type%s*~=%s*[\"']medium[\"']"),  'the medium clause moved')
    assert(src:find("loc%.type%s*~=%s*[\"']ancient[\"']"),  'the ancient cast clause moved')
end

tests['[census] all four Is*Camp helpers compare .type to a string literal'] = function()
    local src = strip_comments(read('bots/FunLib/aba_site.lua'))
    for _, sType in ipairs(TYPES) do
        assert(src:find('camp%.type%s*==%s*"' .. sType .. '"'),
            'the ' .. sType .. ' helper no longer compares `.type` to that string')
    end
    -- and two of the four are DEFINED AND NEVER CALLED, which is why the
    -- polarity check below drives only the ancient/large pair. The definition
    -- is `____exports.IsSmallCamp = function(camp)`, so a call-shaped match
    -- (`IsSmallCamp(`) counts callers and nothing else -- both halves are
    -- asserted so a rename cannot read as "no callers".
    for _, sName in ipairs({ 'IsSmallCamp', 'IsMediumCamp' }) do
        assert(src:find('____exports%.' .. sName .. '%s*=%s*function'),
            sName .. ' is gone or reshaped -- the dead-helper row below is then stale')
    end
    local nSmall, nMedium = 0, 0
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for path in p:lines() do
        local s = strip_comments(read(path))
        local _, a = s:gsub('IsSmallCamp%s*%(', '')
        local _, b = s:gsub('IsMediumCamp%s*%(', '')
        nSmall, nMedium = nSmall + a, nMedium + b
    end
    p:close()
    assert(nSmall == 0 and nMedium == 0, string.format(
        'IsSmallCamp/IsMediumCamp gained a caller (%d/%d call sites, 0 each today) ' ..
        '-- a new caller is a new `.type` decision and needs its own polarity row',
        nSmall, nMedium))
end

tests['[census] .speed is a premise with no price: one reader, and that reader has no caller'] = function()
    -- The sibling half of GH #241 that campteam_SETTLED_20260827's boundary
    -- leaves OPEN alongside `.type`. It does not need a settling round: the
    -- whole tree reads `.speed` in exactly one place, and that place is never
    -- called, so the premise carries no decision today. (Its chain is
    -- "fast"->56 / "slow"->55 / fallback 56, so under the refuter every camp
    -- answers 56 -- a one-second difference on slow camps that has nowhere to
    -- happen.) Pinned so that the day someone calls it, the premise regains a
    -- price and this raises its hand.
    local nReads, nCallers = 0, 0
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for path in p:lines() do
        local s = strip_comments(read(path))
        local _, a = s:gsub('[%w_]+%.speed', '')
        local _, b = s:gsub('GetCampStackTime%s*%(', '')
        nReads, nCallers = nReads + a, nCallers + b
    end
    p:close()
    assert(nReads == 2, '`.speed` read count changed (' .. nReads .. ') -- today both ' ..
        'reads are the two branches of aba_site.GetCampStackTime')
    assert(nCallers == 0, 'GetCampStackTime gained a caller (' .. nCallers ..
        ') -- `.speed` now carries a decision and needs its own polarity row')
    local src = strip_comments(read('bots/FunLib/aba_site.lua'))
    assert(src:find('____exports%.GetCampStackTime%s*=%s*function'),
        'GetCampStackTime is gone or reshaped -- drop this row if it was deleted')
end

--============================================================================
-- The polarity check, run rather than argued. Every path is driven twice on
-- otherwise-identical records.
--============================================================================

tests['[polarity 1] the two live helpers answer FALSE for every camp under the refuter'] = function()
    local J = subject(L10)
    local sCamps = camps_for(GetTeam(), 'string')
    local iCamps = camps_for(GetTeam(), 'int')
    local nStringTrue, nIntTrue = 0, 0
    for k, c in pairs(sCamps) do
        if J.Site.IsAncientCamp(c) then nStringTrue = nStringTrue + 1 end
        if J.Site.IsLargeCamp(c)   then nStringTrue = nStringTrue + 1 end
        local d = iCamps[k]
        if J.Site.IsAncientCamp(d) then nIntTrue = nIntTrue + 1 end
        if J.Site.IsLargeCamp(d)   then nIntTrue = nIntTrue + 1 end
    end
    assert(nStringTrue == 4, 'stand-in changed shape: 2 sides x (1 ancient + 1 large) ' ..
        '= 4 true answers expected, got ' .. nStringTrue)
    assert(nIntTrue == 0, 'under the refuter every tier predicate must be false, got ' ..
        nIntTrue .. ' true -- if this ever becomes non-zero the whole polarity ' ..
        'argument changes shape')
end

tests['[polarity 2] the campgrade ladder FAILS OPEN: string-admitted is a subset of int-admitted'] = function()
    local J = subject(L10)
    local sCamps = camps_for(GetTeam(), 'string')
    local iCamps = camps_for(GetTeam(), 'int')
    local nStrictlyWider = 0
    for _, dmg in ipairs({ 60, 120 }) do
        for lvl = 1, 20 do
            local sSet, iSet = {}, {}
            for k, c in pairs(sCamps) do
                if J.Site.IsCampAllowedForLevel(c, lvl, dmg) then sSet[c.idx] = true end
                if J.Site.IsCampAllowedForLevel(iCamps[k], lvl, dmg) then iSet[c.idx] = true end
            end
            local ok, bad = is_subset(sSet, iSet)
            assert(ok, string.format(
                'FAILS CLOSED at level %d / dmg %d: camp %s is admitted with a string ' ..
                '`.type` and refused with the refuting int. That inverts the whole ' ..
                'argument of this file -- §BN.4 would then be able to settle `.type` ' ..
                'and the docs row must be revisited, not this assertion.',
                lvl, dmg, tostring(bad)))
            if count(iSet) > count(sSet) then nStrictlyWider = nStrictlyWider + 1 end
        end
    end
    -- Teeth: the subset relation must not be vacuous (equal sets everywhere
    -- would mean this path never reads `.type` at all).
    assert(nStrictlyWider >= 8, 'the refuter never widened the admitted set (' ..
        nStrictlyWider .. ' of 40 level/damage cells) -- the ladder would then not ' ..
        'be reading `.type` and this row belongs in the census, not here')

    -- And the SHAPE of the ladder, pinned as three cells rather than as a
    -- direction. A direction survives losing a whole tier (drop the ancient
    -- tier and the large tier alone still widens on 27 of the 40 cells); these
    -- numbers do not. Read off the source ladder: enemy needs 15, ancient 12,
    -- large needs level > 7 AND damage > 80.
    local function cell(lvl, dmg, hyp)
        local n = 0
        local src = (hyp == 'int') and iCamps or sCamps
        for _, c in pairs(src) do
            if J.Site.IsCampAllowedForLevel(c, lvl, dmg) then n = n + 1 end
        end
        return n
    end
    assert(cell(9, 60, 'string')  == 2, 'lvl 9 / dmg 60: own small+medium only, got ' .. cell(9, 60, 'string'))
    assert(cell(9, 60, 'int')     == 4, 'lvl 9 / dmg 60 under the refuter: all four own camps, got ' .. cell(9, 60, 'int'))
    assert(cell(9, 120, 'string') == 3, 'lvl 9 / dmg 120: the large tier releases, got ' .. cell(9, 120, 'string'))
    assert(cell(9, 120, 'int')    == 4, 'lvl 9 / dmg 120 under the refuter, got ' .. cell(9, 120, 'int'))
    assert(cell(15, 120, 'string') == 8 and cell(15, 120, 'int') == 8,
        'at level 15 every tier has released, so the two columns must agree -- that ' ..
        'is the population the ladder is not allowed to speak about')
end

tests['[polarity 3] the campsel selector FAILS OPEN at level 9, and is invariant unarmed'] = function()
    -- The single decision GH #137 §2 measured 6 times in 40 games: a bot below
    -- level 10 standing in an ancient camp. Armed ('campsel') the selector
    -- reads the record, so the string column refuses it and the refuting int
    -- admits it -- fail open. Unarmed the selector reads the WRAPPER, which
    -- carries no `.type` at all, so both columns answer identically: the
    -- shipped default cannot press this premise in either direction.
    local J, bot = subject(L9)
    local function pick(camps, bArmed)
        local got
        with_camps(camps, function()
            local list = J.Site.RefreshCamp(bot, false)
            got = J.Site.GetClosestNeutralSpwan(bot, list, bArmed)
        end)
        return got and got.idx or nil
    end
    -- Only the own-side ancient camp, so the pick is about `.type` alone.
    local function only_own_ancient(hyp)
        local all = camps_for(GetTeam(), hyp)
        local one = {}
        for k, c in pairs(all) do
            if c.team == GetTeam() and (c.type == 'ancient' or c.type == AS_INT.ancient) then
                c.location = Vector(bot:GetLocation().x + 500, bot:GetLocation().y + 500, 0)
                one[k] = c
            end
        end
        assert(count(one) == 1, 'expected exactly one own-side ancient camp, got ' .. count(one))
        return one
    end
    assert(pick(only_own_ancient('string'), true) == nil,
        'armed, a level-9 bot must be refused the ancient camp when `.type` is the string')
    assert(pick(only_own_ancient('int'), true) ~= nil,
        'armed, the refuting int must let the same camp through -- that is the ' ..
        'fail-open this file is about')
    -- unarmed: the wrapper has neither field, so both columns are the same pick
    local sUn = pick(only_own_ancient('string'), false)
    local iUn = pick(only_own_ancient('int'), false)
    assert(sUn ~= nil and sUn == iUn,
        'the SHIPPED selector must be invariant under the hypothesis (it reads the ' ..
        'wrapper): got ' .. tostring(sUn) .. ' vs ' .. tostring(iUn))
end

tests['[polarity 4] RefreshCamp unarmed is INVARIANT, so no wave can press `.type` through it'] = function()
    -- The fall-through chain reads `.type` four times and then appends the
    -- same value in every branch, including an unconditional `else`. So the
    -- OUTPUT does not depend on `.type` at all: this reader is not merely
    -- permissive under the refuter, it is structurally silent under BOTH
    -- columns, and no behavioural measurement of the shipped list can ever
    -- speak about `.type`. Asserted on all four real levels.
    for _, spec in ipairs({ L1, L9, L10, L12 }) do
        local J, bot = subject(spec)
        local sIdx, iIdx = {}, {}
        with_camps(camps_for(GetTeam(), 'string'), function()
            for _, e in ipairs(J.Site.RefreshCamp(bot, false)) do sIdx[e.idx] = true end
        end)
        with_camps(camps_for(GetTeam(), 'int'), function()
            for _, e in ipairs(J.Site.RefreshCamp(bot, false)) do iIdx[e.idx] = true end
        end)
        assert(count(sIdx) == 8 and count(iIdx) == 8, string.format(
            'the unarmed ladder no longer admits every camp at level %d (%d vs %d)',
            spec[3], count(sIdx), count(iIdx)))
        local ok = select(1, is_subset(sIdx, iIdx)) and select(1, is_subset(iIdx, sIdx))
        assert(ok, 'the unarmed list became sensitive to `.type` at level ' .. spec[3])
    end
end

tests['[polarity 5] RefreshCamp ARMED is where the sensitivity lives, and it too fails open'] = function()
    -- The mirror of polarity 4: the same function, with campgrade's flag, is
    -- `.type`-sensitive. Keeping both rows in one file is the point -- the
    -- invariance above is a property of the CHAIN, not of the function, and a
    -- reader who took it for the function would conclude the ladder is dead.
    local J, bot = subject(L9)
    local sIdx, iIdx = {}, {}
    with_camps(camps_for(GetTeam(), 'string'), function()
        for _, e in ipairs(J.Site.RefreshCamp(bot, true)) do sIdx[e.idx] = true end
    end)
    with_camps(camps_for(GetTeam(), 'int'), function()
        for _, e in ipairs(J.Site.RefreshCamp(bot, true)) do iIdx[e.idx] = true end
    end)
    local ok, bad = is_subset(sIdx, iIdx)
    assert(ok, 'armed RefreshCamp FAILS CLOSED on camp ' .. tostring(bad))
    assert(count(iIdx) > count(sIdx), string.format(
        'armed RefreshCamp must be strictly wider under the refuter (%d vs %d) -- ' ..
        'equal sets would mean campgrade is not reading `.type`',
        count(iIdx), count(sIdx)))
end

tests['[argmin] a selector WINNER is not a monotone quantity, so admissibility is asked one camp at a time'] = function()
    -- Bought by this file failing on its own first run, and worth keeping as a
    -- row rather than as a fixed bug: "the refuter is more permissive" is a
    -- statement about the ADMITTED SET, and GetClosestNeutralSpwan returns an
    -- ARGMIN over that set. Widening a candidate set can move an argmin to a
    -- newly admitted candidate, so the winner under the string column can
    -- vanish from the winner under the int column -- which reads exactly like
    -- "fails closed" while nothing failed closed at all. The first draft of
    -- the conclusion below classified the selector by its winner and reported
    -- 1 FAIL-CLOSED site group, i.e. the one finding that would have inverted
    -- this whole file. The fix is not a looser assertion, it is the right
    -- quantity: ask each camp whether it is admissible ALONE.
    local J, bot = subject(L9)
    local function winner(hyp)
        local got
        with_camps(camps_for(GetTeam(), hyp), function()
            local list = J.Site.RefreshCamp(bot, false)
            got = J.Site.GetClosestNeutralSpwan(bot, list, true)
        end)
        return got and got.idx or nil
    end
    local function admissible(hyp)
        local set = {}
        for k, c in pairs(camps_for(GetTeam(), hyp)) do
            with_camps({ [k] = c }, function()
                local list = J.Site.RefreshCamp(bot, false)
                if J.Site.GetClosestNeutralSpwan(bot, list, true) ~= nil then
                    set[c.idx] = true
                end
            end)
        end
        return set
    end
    local sWin, iWin = winner('string'), winner('int')
    assert(sWin ~= nil and iWin ~= nil, 'both columns must still pick something')
    assert(sWin ~= iWin, 'the winners no longer differ between the columns -- the ' ..
        'non-monotonicity this row exists to document has stopped reproducing, so ' ..
        'the per-camp form below is no longer justified by a live case')
    local sSet, iSet = admissible('string'), admissible('int')
    local ok, bad = is_subset(sSet, iSet)
    assert(ok, 'per-camp admissibility must still be a subset; camp ' .. tostring(bad))
    assert(count(iSet) > count(sSet), string.format(
        'and strictly wider (%d vs %d) -- otherwise the selector is not reading `.type`',
        count(iSet), count(sSet)))
end

--============================================================================
-- The conclusion, as a COUNT rather than as prose. This is the assertion the
-- charter, test_set.md and docs/BOT_API_REFERENCE.md will cite.
--============================================================================

tests['[conclusion] zero camp-record `.type` sites fail closed => §BN.4 is silent here'] = function()
    local J, bot = subject(L9)
    local nOpen, nClosed, nInvariant = 0, 0, 0

    local function classify(fn)
        local sSet, iSet = fn('string'), fn('int')
        local a = select(1, is_subset(sSet, iSet))
        local b = select(1, is_subset(iSet, sSet))
        if a and b then
            nInvariant = nInvariant + 1
        elseif a then
            nOpen = nOpen + 1
        else
            nClosed = nClosed + 1
        end
    end

    -- site group 1: the campgrade ladder (aba_site.lua:432 + :435)
    classify(function(hyp)
        local set = {}
        for _, c in pairs(camps_for(GetTeam(), hyp)) do
            if J.Site.IsCampAllowedForLevel(c, 9, 60) then set[c.idx] = true end
        end
        return set
    end)
    -- site group 2: the RefreshCamp fall-through chain (:453 + :455), unarmed
    classify(function(hyp)
        local set = {}
        with_camps(camps_for(GetTeam(), hyp), function()
            for _, e in ipairs(J.Site.RefreshCamp(bot, false)) do set[e.idx] = true end
        end)
        return set
    end)
    -- site group 3: the campsel selector (:528), armed. ADMISSIBILITY, one
    -- camp at a time -- see the [argmin] test below for why the winner of a
    -- full list is the wrong quantity here.
    classify(function(hyp)
        local set = {}
        for k, c in pairs(camps_for(GetTeam(), hyp)) do
            with_camps({ [k] = c }, function()
                local list = J.Site.RefreshCamp(bot, false)
                if J.Site.GetClosestNeutralSpwan(bot, list, true) ~= nil then
                    set[c.idx] = true
                end
            end)
        end
        return set
    end)

    assert(nClosed == 0, string.format(
        '%d camp-record `.type` site group(s) now FAIL CLOSED. That is the one ' ..
        'finding that would let §BN.4 settle `.type` from behaviour we already ' ..
        'own -- do not relax this assertion, go settle the premise and update ' ..
        'docs/BOT_API_REFERENCE.md and test_set.md instead.', nClosed))
    assert(nOpen >= 2, 'expected at least the ladder and the selector to fail open, got ' ..
        nOpen)
    assert(nInvariant >= 1, 'expected the unarmed fall-through chain to be invariant, got ' ..
        nInvariant)
    assert(nOpen + nClosed + nInvariant == 3, 'the three driven site groups must close on 3')
end

return tests

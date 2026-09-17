-- [hero] `lionwseed` -- X.ConsiderW's teamfight argmax spells its "no candidate
-- yet" sentinel as a DAMAGE VALUE, sitting ON the floor of that quantity's own
-- range instead of below it, so a legal candidate projecting exactly 0 can
-- never win and an all-zero candidate set vetoes the whole branch.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
--     local npcMostDangerousEnemy = nil
--     local nMostDangerousDamage = 0
--     ...
--         if ( npcEnemyDamage > nMostDangerousDamage ) then ... end
--
-- GetEstimatedDamageToTarget never returns a negative, so `0` is not below the
-- domain -- it is the domain's first legal value.  A candidate reading exactly
-- 0 fails a strict `>` against the seed.  With every legal candidate reading 0,
-- npcMostDangerousEnemy stays nil and the branch returns nothing: Lion holds a
-- hard disable in a teamfight with a castable enemy standing in range.
--
-- Armed, the seed moves to -1 (strictly below the floor) and nothing else
-- changes.  ⛔ THE BEHAVIOUR DELTA IS EXACTLY THE ALL-ZERO CASE: a 0 can never
-- beat a positive under `>`, so as soon as one candidate projects anything the
-- winner is byte-identical to shipped.  §6 drives both halves of that.
--
-- ===========================================================================
-- §0.1  WHY THE 0 READING IS THE ORDINARY CASE, NOT AN EXOTIC ONE
-- ===========================================================================
--
-- The meter is RETROSPECTIVE: it answers ground truth for damage the enemy
-- actually dealt to THIS bot inside the window (the accurate statement has been
-- in the tree at tests/test_chasering_target_in_ring.lua:48 all along; the
-- "answers 0 on every fixture frame" prose in four other places is false, GH
-- #873).  So it reads 0 for an enemy who has not yet connected on this bot --
-- which in a teamfight is the ordinary state of every enemy currently hitting
-- somebody else.  The seed therefore bites hardest on exactly the enemies a
-- support most wants to Hex.
--
-- ===========================================================================
-- §0.2  WHAT THIS FILE BUYS, AND THE ONE COUNTERFACTUAL IT PAYS
-- ===========================================================================
--
-- ⭐⭐ THE HEADLINE IS THAT §4 DRIVES THE REAL X.ConsiderW, NOT A TRANSCRIPTION.
-- The predecessor lever's file (tests/test_lion_w_fight_reach.lua §3.2b) had to
-- argue the masking through a LOCAL RE-IMPLEMENTATION of the branch, because a
-- premise repeated in four places said the corpus could not reach the decision
-- end to end.  That premise was corrected by GH #873 and the charter's next-round
-- note said to re-ask the question.  Re-asked: the end-to-end domain IS
-- purchasable.  §4 calls the shipped X.SkillsComplement dispatch and then the
-- shipped X.ConsiderW on the real frame and reads the real returned target.
--
-- ⛔ ONE COUNTERFACTUAL IS PAID AND IT IS LABELLED: on the recording Hex has
-- 22.7s of cooldown left, so X.ConsiderW returns at its first line.  §4 sets
-- that ability's cooldown to 0.  ⛔ NOTHING ELSE IS MOVED -- both candidates,
-- their distances (177.8u / 625.2u), their projections (0 / 144), the teamfight
-- predicate, the branch guards, the cast ring and both helper calls are the
-- recording's own.  §4.0 asserts the counterfactual is the only injection by
-- pinning each of those reads.
--
-- ===========================================================================
-- §0.3  ⛔ THE DOMAIN, INCLUDING THE PART THAT IS EMPTY
-- ===========================================================================
--
-- This lever's OWN domain is empty on this corpus and that is registered here
-- rather than left for a later round to discover:
--
--   search ring, all-zero legal set (what this id alone would rescue):  0
--   acceptance ring, all-zero legal set (i.e. AFTER `lionwfight` filters): 1
--
-- ⇒ arming `lionwseed` alone changes no decision anywhere in the corpus (§5.3
-- asserts it), and the one frame it does change requires `lionwfight` armed too.
-- The two ids MASK EACH OTHER; iterations/queue.json hero-102 requests them as
-- ONE atom, and neither may be waved alone on a corpus-like frame and then
-- written up as "tested, no effect" (the lionqkill / lionqdmg precedent).
--
-- ⚠️ 0 and 1 are counts over 112 RECORDED frames whose meter is retrospective.
-- They are NOT frequencies in play, where the meter is live.  Nobody may quote
-- either number as one.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CM_SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local CAND   = 'lionwseed'
local OTHER  = 'lionwfight'
local HELPER = 'lion_FightArgmaxSeed'
local UNIT   = 'npc_dota_hero_lion'
local HEX    = 'lion_voodoo'

local FIXTURE_DIR = 'tests/fixtures'
local PIN = FIXTURE_DIR .. '/f_260820_182906_lion_drain_survived.lua'

-- The branch's two rings, as OFFSETS from nCastRange, and the shipped seed.
local SEARCH_OFFSET = 300
local ACCEPT_OFFSET = 50
local SHIPPED_SEED  = 0
local ARMED_SEED    = -1

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- The body of one top-level `function X.<name>(`, cut at the matching
--- top-level `\nend\n` -- cut on the function, not on a prose needle.
local function fn_body(src, name, where)
    local i = assert(src:find('\nfunction%s+X%.' .. name .. '%s*%('),
        name .. ' not found in ' .. (where or SRC))
    local rest = src:sub(i + 1)
    return rest:sub(1, assert(rest:find('\nend\n'), 'no terminating end for ' .. name))
end

--- Source with `--` comments stripped, so a census counts CODE.  Every count in
--- §1 and §2 runs through this; the headers in this tree quote their own
--- literals constantly and a raw gsub would score the prose.
local function code_only(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

local function fixture_paths()
    local out = {}
    -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
    local p = assert(io.popen('ls ' .. FIXTURE_DIR .. ' 2>/dev/null'))
    for name in p:lines() do
        if name:match('^f_.*%.lua$') then out[#out + 1] = FIXTURE_DIR .. '/' .. name end
    end
    p:close()
    assert(#out > 0, 'corpus directory ' .. FIXTURE_DIR .. ' yielded no f_*.lua frame')
    table.sort(out)
    return out
end

--- Does this fixture carry `unit` alive?  Read off the chunk, without paying
--- for rf.load -- loading is the expensive part of every census below.
---
--- ⭐ MEMOISED, and the reason is the push gate's cumulative budget, not taste.
--- §3 asks this for three heroes over 112 fixtures; unmemoised that is 336
--- dofiles for 112 files' worth of answers. The alive-set of a fixture cannot
--- change inside one process.
local mALIVE = {}
local function alive_set(path)
    local set = mALIVE[path]
    if set == nil then
        set = {}
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            for _, u in ipairs(chunk.units or {}) do
                if u.alive == true then set[u.name] = true end
            end
        end
        mALIVE[path] = set
    end
    return set
end

local function frame_has_alive(path, unit)
    return alive_set(path)[unit] == true
end

--- A hero's own cast ring, computed the way the branches compute it:
---     local nCastRange = ability:GetCastRange() + aetherRange
--- ⚠️ THE AETHER TERM IS NOT OPTIONAL and this file does not get to relearn
--- that: tests/test_cast_ring_mirror_discipline.lua [2] fails a census that
--- spells the ring as GetCastRange() alone, because dropping the term
--- under-states the ring by 225-250u and reads legal casts as out of range (GH
--- #725 read an 861.99u cast as "outside 670").  Read OFF THE FRAME, so a
--- corpus that ever puts a lens on one of these heroes moves the numbers
--- instead of silently misclassifying them.
local function branch_cast_range(J, bot, sAbility)
    local ab = bot:GetAbilityByName(sAbility)
    if ab == nil then return 0 end
    local base = ab:GetCastRange() or 0
    if base <= 0 then return 0 end
    local aether = J.IsItemAvailable('item_aether_lens')
    local bonus = 0
    if aether ~= nil then bonus = J.GetAetherLensRangeBonus(aether, 250) or 0 end
    return base + bonus
end

--- The branch's own candidate filter, transcribed from X.ConsiderW's 团战 loop.
--- X.IsHexAoe is a file-local and unreachable from here; it is the SECOND
--- disjunct of one conjunct, so treating it as false reproduces the shipped
--- filter on the default (no AoE talent) build.  §1.6 pins that this is still
--- what the loop tests, so the transcription cannot drift silently.
local function is_legal_candidate(J, e)
    return J.IsValid(e)
        and J.CanCastOnNonMagicImmune(e)
        and J.CanCastOnTargetAdvanced(e)
        and not J.IsDisabled(e)
        and not J.IsTaunted(e)
        and not e:IsDisarmed()
end

local function projection(bot, e)
    return e:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
end

-- ---------------------------------------------------------------- section 1 --
-- The lever is wired where its header says it is, and nowhere else.

tests['§1.1 the shipped seed literal survives in exactly one place'] = function()
    local src = code_only(read_file(SRC))

    local _, nConst = src:gsub('X%.nWFightArgmaxSeedShipped = ' .. SHIPPED_SEED, '')
    assert(nConst == 1, 'X.nWFightArgmaxSeedShipped = ' .. SHIPPED_SEED .. ' appears '
        .. nConst .. ' times, expected once')

    -- ⛔ And the bare literal must be GONE from the branch. If a later edit
    -- re-inlines `nMostDangerousDamage = 0` the lever is only half wired: the
    -- helper still exists, still passes its own unit tests, and no longer
    -- reaches the decision. That is the exact failure mode `lionwfight`'s file
    -- had to learn from a mutation stand.
    local body = code_only(fn_body(read_file(SRC), 'ConsiderW'))
    local _, nBare = body:gsub('nMostDangerousDamage%s*=%s*0', '')
    assert(nBare == 0, 'X.ConsiderW still seeds nMostDangerousDamage with a bare 0 ('
        .. nBare .. 'x) -- the helper is then wired to nothing')
end

tests['§1.2 exactly one call site, and it is the seed assignment'] = function()
    local src = code_only(read_file(SRC))
    -- ⚠️ The definition line matches the same needle as a call, so count both
    -- and subtract the one definition. Spelling this as "expected 1" was this
    -- file's own first-draft bug: it read 2 and blamed the source.
    local _, nDef = src:gsub('function%s+X%.' .. HELPER .. '%(%s*%)', '')
    assert(nDef == 1, HELPER .. ' is defined ' .. nDef .. ' times in ' .. SRC .. ', expected 1')
    local _, nTotal = src:gsub('X%.' .. HELPER .. '%(%s*%)', '')
    local nCall = nTotal - nDef
    assert(nCall == 1, 'expected exactly one `X.' .. HELPER .. '()` call site in '
        .. SRC .. ', found ' .. nCall)

    local body = code_only(fn_body(read_file(SRC), 'ConsiderW'))
    local _, nSeed = body:gsub('nMostDangerousDamage%s*=%s*X%.' .. HELPER .. '%(%s*%)', '')
    assert(nSeed == 1, 'the call site is not the nMostDangerousDamage seed inside '
        .. 'X.ConsiderW (found ' .. nSeed .. ') -- §0 is about that seed')
end

tests['§1.3 the argmax still compares with a strict `>`'] = function()
    -- The lever is only meaningful against a STRICT comparison. If someone
    -- "fixes" this by relaxing to `>=`, the seed becomes harmless and this
    -- lever must be RETIRED rather than left armed: a `>=` argmax over an
    -- all-zero set already selects the LAST member. Either way it is a
    -- different change and it must not happen silently.
    local body = code_only(fn_body(read_file(SRC), 'ConsiderW'))
    local _, nStrict = body:gsub('npcEnemyDamage%s*>%s*nMostDangerousDamage', '')
    local _, nLoose  = body:gsub('npcEnemyDamage%s*>=%s*nMostDangerousDamage', '')
    assert(nStrict == 1, 'the strict `npcEnemyDamage > nMostDangerousDamage` is gone from '
        .. 'X.ConsiderW (' .. nStrict .. ' occurrences) -- re-read §0 before touching this lever')
    assert(nLoose == 0, 'the argmax now compares with `>=` (' .. nLoose .. 'x). The seed is no '
        .. 'longer what vetoes an all-zero set, so `' .. CAND .. '` should be RETIRED, not kept')
end

tests['§1.4 nothing after the loop reads the seed value'] = function()
    -- The whole safety argument for moving 0 to -1 is that the seed is a
    -- sentinel and never escapes the loop. Assert it rather than assume it: a
    -- later edit that reports nMostDangerousDamage (a chat motive, a desire
    -- scale) would make -1 leak into play the day this id is armed.
    local body = code_only(fn_body(read_file(SRC), 'ConsiderW'))
    local _, nUses = body:gsub('nMostDangerousDamage', '')
    assert(nUses == 3, 'nMostDangerousDamage is mentioned ' .. nUses .. ' times in X.ConsiderW '
        .. '(seed, comparison, re-assignment = 3). A fourth use means the sentinel ESCAPES the '
        .. 'loop and the -1 is no longer confined to the argmax -- re-price this lever')
end

tests['§1.5 ⛔ the gate does not name the other id (the pullcad trap)'] = function()
    -- A gate written as `IsSoakCandidate('lionwseed') and IsSoakCandidate
    -- ('lionwfight')` would be the good-looking way to encode the dependency
    -- and it is exactly the trap: it freezes FALSE the day the other id is
    -- promoted, because a promoted id appears in no armed string. The
    -- dependency belongs in the wave request, and it is in hero-102.
    local body = fn_body(read_file(SRC), HELPER)
    assert(body:find("IsSoakCandidate%( *'" .. CAND .. "' *%)"),
        HELPER .. ' does not gate on ' .. CAND)
    assert(body:find("IsSoakCandidate%( *'" .. OTHER .. "' *%)") == nil,
        HELPER .. " names '" .. OTHER .. "' inside its own predicate. That gate is frozen "
        .. 'FALSE the day ' .. OTHER .. ' is promoted. Encode the pairing in the wave request.')
    assert(body:find('IsModeTurbo'), HELPER .. ' is not turbo-only')
end

tests['§1.6 the transcribed candidate filter is still the 团战 LOOP\'s filter'] = function()
    -- §3 and §5.3 re-implement the loop's filter. Every simplification in a
    -- re-implementation is an unsigned assumption, so pin the conjuncts.
    --
    -- ⚠️⚠️ AND PIN THEM AT THE SITE, NOT SOMEWHERE IN THE FUNCTION. This file's
    -- first draft asked `fn_body(ConsiderW):find(needle)` and the mutation
    -- stand's M14 -- delete the conjunct from THIS loop -- SURVIVED it:
    -- X.ConsiderW carries the identical five-conjunct chain THREE times (the
    -- 团战 argmax, and two more branches below it), so deleting one still
    -- leaves two for a `find` to land on. The assertion was true of the
    -- function and said nothing about the loop. Same shape as charter -195's
    -- lesson: assert by LOCATION, not by existence.
    local fn = code_only(fn_body(read_file(SRC), 'ConsiderW'))

    -- Cut the argmax loop: seed call site .. the winner test that ends it.
    local i = assert(fn:find('local npcMostDangerousEnemy = nil', 1, true),
        'the 团战 argmax is gone from X.ConsiderW')
    local j = assert(fn:find('if npcMostDangerousEnemy ~= nil', i, true),
        'the argmax no longer ends in a winner test -- re-read the cut below')
    local loop = fn:sub(i, j)

    for _, needle in ipairs({
        'J%.IsValid%( npcEnemy %)',
        'J%.CanCastOnNonMagicImmune%( npcEnemy %)',
        'J%.IsDisabled%( npcEnemy %)',
        'J%.IsTaunted%( npcEnemy %)',
        'npcEnemy:IsDisarmed%(%)',
    }) do
        assert(loop:find(needle), 'the 团战 argmax loop no longer carries ' .. needle
            .. ' -- is_legal_candidate() is measuring a different set than the branch does')
    end
    -- The AoE disjunct, which the transcription treats as false.
    assert(loop:find('X%.IsHexAoe%(%)'), 'X.IsHexAoe is gone from the argmax filter; the '
        .. 'transcription\'s "treat as false" simplification no longer describes it')
    -- And the sibling lever's term, which is what makes the pair reach a cast.
    -- ⚠️ plain=true, so this needle is a LITERAL and must not carry `%.`
    -- escapes. The first draft passed an escaped pattern with plain=true and
    -- searched for the characters `X%.lion_...`, which no source line has.
    assert(loop:find('X.lion_IsHexFightTargetInReach', 1, true),
        'the ' .. OTHER .. ' call site left the argmax loop -- §4.2/§4.3 are then driving a '
        .. 'branch that no longer has a partner to be masked by')

    -- ⛔ The COUNT as well, so a deletion anywhere in the function shows up
    -- rather than being absorbed by one of the two sibling branches.
    local _, nChain = fn:gsub('npcEnemy:IsDisarmed%(%)', '')
    assert(nChain == 3, 'X.ConsiderW carries ' .. nChain .. ' copies of the candidate chain, '
        .. 'was 3. If a branch was added or removed, re-read which one this lever sits in.')
end

-- ---------------------------------------------------------------- section 2 --
-- The copy lineage, read out of source.

tests['§2.1 all three focus copies share this seed polarity, byte for byte'] = function()
    -- ⭐ Unlike the REACH postures (which differ across the three copies and
    -- were `lionwfight`'s headline), the seed is identical in all three. That
    -- is why this is a family and not a one-off, and why the other two are
    -- named as next candidates rather than folded into this id.
    -- ⚠️ Lion's copy is the one this lever GATED, so its 0 now lives in
    -- X.nWFightArgmaxSeedShipped rather than inline. Asserting the inline
    -- literal for all three was this file's own first-draft bug -- it would
    -- have gone red on the very change it exists to protect.
    local lion = code_only(read_file(SRC))
    assert(lion:find('X%.nWFightArgmaxSeedShipped = ' .. SHIPPED_SEED),
        'lion no longer carries the shipped 0 seed as a named constant -- §1.1 covers where '
        .. 'it lives; if the seed itself changed, this whole family census is stale')
    assert(lion:find('npcEnemyDamage > nMostDangerousDamage'),
        'lion no longer carries the strict `>`')

    -- The two UNGATED copies still carry it inline, and that is the point: the
    -- shape travelled and only one copy has been fixed.
    for _, pair in ipairs({ { CM_SRC, 'crystal_maiden' }, { WK_SRC, 'skeleton_king' } }) do
        local src = code_only(read_file(pair[1]))
        assert(src:find('local nMostDangerousDamage = 0'),
            pair[2] .. ' no longer carries the `= 0` seed. If it was FIXED, register the id in '
            .. 'iterations/state.json and drop it from this census; if it merely MOVED, every '
            .. 'count in §3.3 is stale.')
        assert(src:find('npcEnemyDamage > nMostDangerousDamage'),
            pair[2] .. ' no longer carries the strict `>` -- the "same polarity in all three" '
            .. 'claim in ' .. HELPER .. "'s header is now wrong")
    end
end

tests['§2.2 only Lion\'s copy is gated -- the other two are untouched by this id'] = function()
    -- The blast radius, asserted. Arming this id must not reach crystal_maiden
    -- or skeleton_king; they need their own ids and their own frames.
    for _, pair in ipairs({ { CM_SRC, 'crystal_maiden' }, { WK_SRC, 'skeleton_king' } }) do
        local src = read_file(pair[1])
        assert(src:find(CAND, 1, true) == nil,
            pair[2] .. ' now mentions ' .. CAND .. '. This id is one lever in one file; a '
            .. 'second file makes it a BUNDLE that no wave can take apart (GH #606).')
    end
    local _, nGate = code_only(read_file(SRC)):gsub("IsSoakCandidate%( *'" .. CAND .. "' *%)", '')
    assert(nGate == 1, CAND .. ' is gated in ' .. nGate .. ' places in ' .. SRC .. ', expected 1')
end

-- ---------------------------------------------------------------- section 3 --
-- The corpus domain, including the empty parts.

--- One pass over the corpus for one hero.  Returns the funnel plus the two
--- all-zero counts §0.3 quotes.  `nAccept` nil means that copy has no winner
--- test, so there is no acceptance ring to measure.
---
--- ⭐ It also carries §5.3's question -- does the ARMED seed ever pick a
--- different winner than the shipped one -- so that walk happens on the SAME
--- pass rather than as a second one. Same budget reason as alive_set above:
--- this file went into the push gate's cumulative total and a walk it did not
--- need is a walk every pusher pays for.
local function argmax_winner(J, bot, set, seed)
    local win, best = nil, seed
    for _, e in pairs(set) do
        if is_legal_candidate(J, e) then
            local d = projection(bot, e)
            if d > best then best, win = d, e end
        end
    end
    return win
end

local mCENSUS = {}
local function census(unit, ability, nSearch, nAccept)
    local key = unit .. '|' .. ability .. '|' .. nSearch .. '|' .. tostring(nAccept)
    if mCENSUS[key] ~= nil then return mCENSUS[key][1], mCENSUS[key][2], mCENSUS[key][3] end
    local c = { alive = 0, fight = 0, guard = 0, measured = 0, zero = 0,
                search_allzero = 0, accept_nonempty = 0, accept_allzero = 0,
                multi = 0, ascending = 0, argmax_frames = 0, argmax_nonnil = 0 }
    local drivable, divergent = {}, {}
    for _, path in ipairs(fixture_paths()) do
        if frame_has_alive(path, unit) then
            c.alive = c.alive + 1
            local ok, J, bot = pcall(rf.load, path, unit)
            if ok and J.IsInTeamFight(bot, 1200) then
                c.fight = c.fight + 1
                local cr = branch_cast_range(J, bot, ability)
                if cr > 0 then
                    local set = J.GetNearbyHeroes(bot, cr + nSearch, true, BOT_MODE_NONE)

                    -- §5.3's question, asked on this same pass.
                    c.argmax_frames = c.argmax_frames + 1
                    local wShip = argmax_winner(J, bot, set, SHIPPED_SEED)
                    local wArm  = argmax_winner(J, bot, set, ARMED_SEED)
                    if wShip ~= nil or wArm ~= nil then c.argmax_nonnil = c.argmax_nonnil + 1 end
                    if wShip ~= wArm then
                        divergent[#divergent + 1] = path .. ' (shipped='
                            .. tostring(wShip and wShip:GetUnitName()) .. ', armed='
                            .. tostring(wArm and wArm:GetUnitName()) .. ')'
                    end

                    if #set >= 2 then
                        c.guard = c.guard + 1
                        c.multi = c.multi + 1
                        local mono = true
                        for i = 2, #set do
                            if GetUnitToUnitDistance(bot, set[i]) < GetUnitToUnitDistance(bot, set[i - 1])
                            then mono = false end
                        end
                        if mono then c.ascending = c.ascending + 1 end
                    end
                    local nS, nSz, nA, nAz = 0, 0, 0, 0
                    for _, e in pairs(set) do
                        if is_legal_candidate(J, e) then
                            local d = projection(bot, e)
                            nS = nS + 1
                            if d == 0 then nSz = nSz + 1 end
                            if nAccept ~= nil and J.IsInRange(bot, e, cr + nAccept) then
                                nA = nA + 1
                                if d == 0 then nAz = nAz + 1 end
                            end
                        end
                    end
                    c.measured = c.measured + nS
                    c.zero = c.zero + nSz
                    if nS > 0 and nSz == nS then c.search_allzero = c.search_allzero + 1 end
                    if nAccept ~= nil and nA > 0 then
                        c.accept_nonempty = c.accept_nonempty + 1
                        if nAz == nA then
                            c.accept_allzero = c.accept_allzero + 1
                            drivable[#drivable + 1] = path
                        end
                    end
                end
            end
        end
    end
    mCENSUS[key] = { c, drivable, divergent }
    return c, drivable, divergent
end

tests['§3.1 ⛔ this id\'s OWN domain is EMPTY on this corpus; the paired one is 1 frame'] = function()
    local c, drivable = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET)
    assert(c.alive == 25, 'live-Lion instants ' .. c.alive .. ', was 25. The corpus moved; '
        .. 're-read every count in this section AND in the helper header before quoting one.')
    assert(c.fight == 5, 'J.IsInTeamFight true on ' .. c.fight .. ' of them, was 5')
    assert(c.guard == 1, c.guard .. ' frames clear the branch\'s `#nInBonusEnemyList >= 2` '
        .. 'guard, was 1')

    -- ⛔ THE EMPTY READING, asserted as a number so it cannot quietly become a
    -- claim of coverage. On the SEARCH ring nothing is all-zero: this id alone
    -- rescues nothing here.
    assert(c.search_allzero == 0, 'the search ring now carries ' .. c.search_allzero
        .. ' all-zero frame(s), was 0. ' .. CAND .. ' has acquired a domain of its OWN and '
        .. 'the "changes no decision alone" claim in §0.3 and §5.3 must be re-read')

    -- And the paired one, which is the only thing this lever is bought for.
    assert(c.accept_allzero == 1, 'the acceptance ring carries ' .. c.accept_allzero
        .. ' all-zero frame(s), was 1. That is the frame §4 drives; if it went to 0 this '
        .. 'lever lost its only witnessed domain and must be re-priced before any wave.')
    assert(#drivable == 1 and drivable[1]:find('lion_drain_survived', 1, true) ~= nil,
        'the drivable frame is no longer f_260820_182906_lion_drain_survived: '
        .. tostring(drivable[1]))
    -- ⛔ A RATE OVER ONE FRAME. Not a frequency. See §0.3.
    assert(c.measured == 2 and c.zero == 1,
        'the branch-reaching census measures ' .. c.measured .. ' legal candidates of which '
        .. c.zero .. ' read 0 (was 2 and 1)')
end

tests['§3.2 the armed tie-break is the NEAREST member, measured not assumed'] = function()
    -- With the seed below the floor and a strict `>`, an all-zero set selects
    -- the FIRST member of the list. Whether that is a good target depends on an
    -- ordering nobody in this tree has written down, so measure it instead of
    -- asserting the engine sorts by distance.
    local c = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET)
    assert(c.multi >= 1, 'no frame carries 2+ candidates, so the ordering is unmeasured here '
        .. 'and the "nearest member" line in ' .. HELPER .. "'s header is unsupported")
    assert(c.ascending == c.multi, 'J.GetNearbyHeroes returned a NON-ascending list on '
        .. (c.multi - c.ascending) .. ' of ' .. c.multi .. ' multi-candidate frames. The armed '
        .. 'tie-break is then "an arbitrary legal member", not "the nearest" -- fix the header '
        .. 'rather than the assertion. (Still strictly better than no cast: every member has '
        .. 'cleared the full legality chain.)')
end

tests['§3.3 ⛔ the other two copies: measured, and BOTH empty'] = function()
    -- The draft of this lever's header called the ungated copies "strictly
    -- easier to buy" because they carry no winner test. That is a statement
    -- about SHAPE. The corpus refutes it as a statement about DOMAIN, and the
    -- refutation is pinned here so the next round starts from the number.
    local cm = census('npc_dota_hero_crystal_maiden', 'crystal_maiden_frostbite', 0, nil)
    local wk = census('npc_dota_hero_skeleton_king', 'skeleton_king_hellfire_blast', 43, nil)
    assert(cm.alive == 51, 'live-CM instants ' .. cm.alive .. ', was 51')
    assert(wk.alive == 36, 'live-WK instants ' .. wk.alive .. ', was 36')
    assert(cm.fight == 2, 'CM clears IsInTeamFight on ' .. cm.fight .. ', was 2')
    assert(wk.fight == 0, 'WK clears IsInTeamFight on ' .. wk.fight .. ', was 0 -- if this is '
        .. 'now positive, the WK copy just became measurable and GH #873 can be advanced')
    assert(cm.search_allzero == 0 and wk.search_allzero == 0,
        'an all-zero set appeared in an ungated copy (cm=' .. cm.search_allzero .. ', wk='
        .. wk.search_allzero .. '). That copy is now buyable on a real frame and is the next '
        .. 'id to land -- it does NOT become part of ' .. CAND .. '.')
end

-- ---------------------------------------------------------------- section 4 --
-- ⭐⭐ THE END-TO-END TRUTH TABLE, through the real X.ConsiderW.

--- Drive the shipped dispatch and then the shipped X.ConsiderW on the pin with
--- an arbitrary set of ids armed.  `tArmed` is a set of id strings.
---
--- ⛔ THE ONE COUNTERFACTUAL, labelled: Hex carries 22.7s of cooldown on the
--- recording, so X.ConsiderW returns at its first line.  It is set ready here
--- and NOTHING else is moved.  §4.0 pins every other read as the frame's own.
local function drive(tArmed)
    local J, bot = rf.load(PIN, UNIT)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return tArmed ~= nil and tArmed[id] == true end

    local X = rf.load_hero('lion')
    local hW = bot:GetAbilityByName(HEX)
    local spec = rawget(hW, '__spec')
    spec.GetCooldownTimeRemaining = function() return 0 end
    spec.IsFullyCastable = function() return true end

    X.SkillsComplement()
    local nDesire, hTarget, sMotive = X.ConsiderW()
    return nDesire, hTarget, sMotive, J, bot
end

tests['§4.0 the counterfactual is the ONLY injection -- pin everything else'] = function()
    local J, bot = rf.load(PIN, UNIT)
    local hW = bot:GetAbilityByName(HEX)
    assert(hW:GetLevel() == 1, 'Hex rank on the pin is ' .. hW:GetLevel() .. ', was 1')
    assert(hW:GetCooldownTimeRemaining() > 20,
        'Hex is no longer on cooldown on the recording (' .. hW:GetCooldownTimeRemaining()
        .. 's). The §4 counterfactual has stopped being one -- say so, do not keep paying for it.')
    assert(J.IsItemAvailable('item_aether_lens') == nil,
        'Lion now carries an aether lens on the pin -- every ring number in this file moves '
        .. 'by J.GetAetherLensRangeBonus and must be re-read, not re-fitted')
    local cr = branch_cast_range(J, bot, HEX)
    assert(cr == 575, 'Hex cast range on the pin is ' .. cr .. ', was 575 (rank 1, no lens)')
    assert(J.IsInTeamFight(bot, 1200), 'the pin no longer clears the branch\'s entry predicate')

    local set = J.GetNearbyHeroes(bot, cr + SEARCH_OFFSET, true, BOT_MODE_NONE)
    assert(#set == 2, 'the pin now carries ' .. #set .. ' enemies in the search ring, was 2 '
        .. '(and the branch guard reads exactly this count)')
    local inner, outer
    for _, e in pairs(set) do
        if is_legal_candidate(J, e) then
            if J.IsInRange(bot, e, cr + ACCEPT_OFFSET) then inner = e else outer = e end
        end
    end
    assert(inner ~= nil and outer ~= nil, 'the pin lost one side of the acceptance ring')
    assert(inner:GetUnitName() == 'npc_dota_hero_luna', 'inner is ' .. inner:GetUnitName())
    assert(outer:GetUnitName() == 'npc_dota_hero_crystal_maiden', 'outer is ' .. outer:GetUnitName())

    -- The two projections, and they are the whole mechanism: 0 is what the seed
    -- eats, 144 is what wins the argmax from outside the acceptance ring.
    assert(projection(bot, inner) == 0, 'the in-range candidate now projects '
        .. projection(bot, inner) .. ', was 0 -- the masking §4.2 drives is gone')
    assert(projection(bot, outer) == 144, 'the annulus member projects '
        .. projection(bot, outer) .. ', was 144')

    local dOuter = GetUnitToUnitDistance(bot, outer)
    assert(dOuter > cr + ACCEPT_OFFSET and dOuter < cr + ACCEPT_OFFSET + 1,
        'the annulus member is at ' .. string.format('%.1f', dOuter) .. 'u against an '
        .. 'acceptance ring of ' .. (cr + ACCEPT_OFFSET) .. '; it was 625.2 (0.2u outside)')
    assert(GetUnitToUnitDistance(bot, inner) < cr + ACCEPT_OFFSET,
        'the in-range candidate left the acceptance ring')
end

tests['§4.1 ⭐ shipped VETOES: real dispatch, real ConsiderW, real frame'] = function()
    local nDesire, hTarget = drive(nil)
    assert(nDesire == 0, 'shipped X.ConsiderW now bids ' .. tostring(nDesire) .. ' on the pin. '
        .. 'The defect this pair exists for is GONE -- retire the ids, do not relax them.')
    assert(hTarget == nil, 'shipped returned a target: ' .. tostring(hTarget))
end

tests['§4.2 ⛔ NEITHER id alone rescues the frame -- they mask each other'] = function()
    -- This is the WAVE-ORDER fact, driven end to end so nobody re-measures
    -- either id alone and writes it up as "tested, no effect".
    local dFight = drive({ [OTHER] = true })
    assert(dFight == 0, OTHER .. ' alone now casts (' .. tostring(dFight) .. '). The masking '
        .. 'claim in hero-102 and in both helper headers is stale -- re-read before waving.')

    local dSeed = drive({ [CAND] = true })
    assert(dSeed == 0, CAND .. ' alone now casts (' .. tostring(dSeed) .. '). The annulus '
        .. 'member is supposed to still win the argmax and still fail the winner test.')
end

tests['§4.3 ⭐⭐ the PAIR casts, on the real branch, at the enemy in range'] = function()
    local nDesire, hTarget, sMotive = drive({ [OTHER] = true, [CAND] = true })
    assert(nDesire == BOT_ACTION_DESIRE_HIGH, 'the armed pair bids ' .. tostring(nDesire)
        .. ', expected BOT_ACTION_DESIRE_HIGH (' .. tostring(BOT_ACTION_DESIRE_HIGH) .. ')')
    assert(type(hTarget) == 'table' and hTarget.GetUnitName ~= nil,
        'the armed pair returned ' .. type(hTarget) .. ', expected a unit handle. (A LOCATION '
        .. 'would mean X.IsHexAoe went true, which changes what this branch returns and what '
        .. 'is_legal_candidate transcribes.)')
    assert(hTarget:GetUnitName() == 'npc_dota_hero_luna',
        'the armed pair casts on ' .. hTarget:GetUnitName() .. ', expected npc_dota_hero_luna '
        .. '-- the legal enemy at 177.8u that shipped play holds a hard disable against')
    assert(type(sMotive) == 'string' and sMotive:find('W%-团战'),
        'the motive is ' .. tostring(sMotive) .. ', expected the 团战 branch\'s own')
end

-- ---------------------------------------------------------------- section 5 --
-- The armed leg of the helper itself, driven; and the UNARMED control.

--- Run `fn` with the J the helper closes over reporting `tArmed` armed, then
--- restore.  The hero module caches J at load, so patch the loaded table.
local function with_gates(tArmed, bTurbo, fn)
    local J, bot = rf.load(PIN, UNIT)
    local oldC, oldT = J.IsSoakCandidate, J.IsModeTurbo
    J.IsSoakCandidate = function(id) return tArmed ~= nil and tArmed[id] == true end
    J.IsModeTurbo = function() return bTurbo end
    local X = rf.load_hero('lion')
    local ok, res = pcall(fn, X, J, bot)
    J.IsSoakCandidate, J.IsModeTurbo = oldC, oldT
    assert(ok, res)
    return res
end

tests['§5.1 armed, the helper returns a seed BELOW the projection floor'] = function()
    local seed = with_gates({ [CAND] = true }, true, function(X) return X[HELPER]() end)
    assert(seed == ARMED_SEED, 'armed seed is ' .. tostring(seed) .. ', expected ' .. ARMED_SEED)
    -- The property that actually matters, stated as the property rather than
    -- as the constant: a 0 projection must beat it under the branch's own
    -- strict `>`. A seed of 0 (or any value >= 0) fails this.
    assert(0 > seed, 'the armed seed ' .. tostring(seed) .. ' is not below the floor of '
        .. 'GetEstimatedDamageToTarget, so a 0 projection still loses the strict `>` and this '
        .. 'lever does nothing')
end

tests['§5.2 UNARMED the helper returns the shipped literal -- the gate is the difference'] = function()
    -- The control for §5.1. Without this, a helper that returned -1
    -- unconditionally would pass every other test in this file while being
    -- LIVE in shipped play.
    local off = with_gates(nil, true, function(X) return X[HELPER]() end)
    assert(off == SHIPPED_SEED, 'gate off, the seed is ' .. tostring(off) .. ', expected the '
        .. 'shipped ' .. SHIPPED_SEED .. '. This lever is LIVE IN EVERY GAME as written.')

    -- Turbo-only: armed but not Turbo must also be the shipped literal.
    local nonTurbo = with_gates({ [CAND] = true }, false, function(X) return X[HELPER]() end)
    assert(nonTurbo == SHIPPED_SEED, 'armed outside Turbo the seed is ' .. tostring(nonTurbo)
        .. ', expected ' .. SHIPPED_SEED .. ' -- the lever is not turbo-only')

    -- And the OTHER id must not arm this one.
    local otherOnly = with_gates({ [OTHER] = true }, true, function(X) return X[HELPER]() end)
    assert(otherOnly == SHIPPED_SEED, 'arming ' .. OTHER .. ' alone moved this seed to '
        .. tostring(otherOnly) .. '. The two ids are then a BUNDLE no wave can separate.')
end

tests['§5.3 ⛔ armed alone, NO decision in the corpus changes'] = function()
    -- §3.1 says the search-ring all-zero set is empty, so this must hold. It is
    -- driven rather than inferred, over every branch-reaching Lion frame, with
    -- the shipped and armed argmax computed side by side on the SAME loaded
    -- frame. A divergence means this lever has grown a solo domain nobody
    -- priced, which is how a "one lever" wave silently becomes two.
    local c, _, divergent = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET)
    assert(#divergent == 0, 'arming ' .. CAND .. ' alone changes the argmax winner on '
        .. #divergent .. ' frame(s): ' .. table.concat(divergent, '; ') .. '. §0.3 and §3.1 '
        .. 'claim this cannot happen; one of them is now wrong, and this lever has grown a '
        .. 'solo domain nobody priced.')

    -- ⛔ THE ANTI-VACUITY PAIR. An assertion that "nothing diverged" is free if
    -- nothing ran, and free again if every frame produced nil under BOTH seeds.
    assert(c.argmax_frames >= 5, 'only ' .. c.argmax_frames .. ' frames reached the argmax, '
        .. 'was 5+ -- the comparison above is going vacuous')
    assert(c.argmax_nonnil >= 1, 'no frame produced a winner under EITHER seed, so the '
        .. 'comparison above is vacuously true on every frame it ran')
end

tests['§5.4 armed, a positive projection still wins -- the delta is all-zero ONLY'] = function()
    -- The safety half of §0, driven on the pin. Give the in-range candidate a
    -- positive projection and shipped and armed must agree, because no 0 can
    -- beat a positive under `>`.
    local J, bot = rf.load(PIN, UNIT)
    local cr = branch_cast_range(J, bot, HEX)
    local set = {}
    for _, e in pairs(J.GetNearbyHeroes(bot, cr + SEARCH_OFFSET, true, BOT_MODE_NONE)) do
        if is_legal_candidate(J, e) then set[#set + 1] = e end
    end
    assert(#set == 2, 'the pin carries ' .. #set .. ' legal candidates, was 2')

    local function winner(seed)
        local win, best = nil, seed
        for _, e in ipairs(set) do
            local d = projection(bot, e)
            if d > best then best, win = d, e end
        end
        return win
    end
    -- ONE DECLARED NUMBER, and what it is for: the meter is retrospective, so
    -- Luna's 0 says she did not connect in that window, not that a carry at
    -- 177.8u projects nothing. Nothing else on the frame is touched.
    assert(winner(SHIPPED_SEED) == winner(ARMED_SEED),
        'with a 144 in the set, the two seeds already disagree -- the "delta is the all-zero '
        .. 'case only" claim in §0 is false')
    rawget(set[1], '__spec').GetEstimatedDamageToTarget = function() return 7 end
    assert(winner(SHIPPED_SEED) == winner(ARMED_SEED),
        'with every candidate projecting a positive number the two seeds must pick the SAME '
        .. 'winner; they did not')
end

return tests

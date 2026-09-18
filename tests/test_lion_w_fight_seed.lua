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
-- §0.3  ⭐⭐ THE DOMAIN -- AND THE 2026-09-18 CORRECTION OF IT
-- ===========================================================================
--
-- ⛔⛔ THE READING THIS SECTION CARRIED UNTIL 2026-09-18 WAS WRONG, IN THE
-- DIRECTION THAT MADE THE LEVER LOOK INERT.  It said:
--
--     search ring, all-zero legal set (what this id alone would rescue):  0
--     acceptance ring, all-zero legal set (after `lionwfight` filters):   1
--     ⇒ arming `lionwseed` alone changes NO decision anywhere in the corpus
--
-- Re-measured, the same census over the same tree reads:
--
--     live-Lion instants                      25 -> 42
--     J.IsInTeamFight true                     5 -> 13
--     frames clearing the branch guard          1 -> 13   (11 via the ALLY disjunct)
--     search ring, all-zero legal set           0 ->  6
--     acceptance ring, all-zero legal set       1 ->  5
--
-- ⭐⭐ AND IT IS NOT A MATTER OF DEGREE: §6 drives the shipped X.ConsiderW on
-- tests/frames/f_260909_215040_wk_blast_lion_480.lua WITH NO INJECTION AT ALL
-- (Hex is rank 1, off cooldown, fully castable on the recording) and reads
--
--     shipped:                 desire 0, no target
--     `lionwseed` armed ALONE: BOT_ACTION_DESIRE_HIGH on npc_dota_hero_skeleton_king
--
-- ⇒ this id HAS a solo witnessed domain.  Every sentence anywhere claiming it
-- "changes no decision alone" is false, including the one this file used to
-- assert and the one hero_lion.lua's helper header used to print.
--
-- ⭐ TWO INDEPENDENT SCOPE DEFECTS, BOTH SIGNED THE SAME WAY, WHICH IS WHY THEY
-- COMPOUNDED INSTEAD OF CANCELLING:
--
--   (a) the corpus walk enumerated `tests/fixtures` ALONE, and `tests/frames`
--       holds 32 more frames -- the charter's `-199` bought exactly this
--       correction on the WK row of this same family
--       (「团战谓词的域要在两个语料目录上数」) and it was never applied here;
--   (b) the branch guard `( #nInBonusEnemyList >= 2 or #hAllyList >= 3 )` was
--       transcribed as its FIRST DISJUNCT ONLY.  11 of the 13 guard-clearing
--       frames clear it through the ally count, and the §6 witness is one of
--       them -- so under (b) alone that frame was not merely uncounted, it was
--       unreachable by construction.
--
-- ⛔ WHAT SURVIVES THE CORRECTION, SAID PLAINLY SO THE REPAIR IS NOT OVERSOLD.
-- The MASKING on the original pin (f_260820_182906_lion_drain_survived) is
-- real and §4 still drives it: there, and there specifically, neither id alone
-- casts and the pair does.  What is dead is the general claim built on top of
-- it -- that masking is the ONLY thing this corpus witnesses, and hence that
-- the pair is inseparable.  iterations/queue.json hero-102 requested the two as
-- ONE atom on that ground; the ground is now measured false, and a wave that
-- arms the pair and reads back a delta will be attributing to the pair a change
-- the seed makes by itself on at least one real frame.
--
-- ⚠️ 6 / 5 / 1 are counts over 144 RECORDED frames whose meter is
-- RETROSPECTIVE.  They are NOT frequencies in play, where the meter is live.
-- Nobody may quote any of them as one.  (That caveat was right in the old text
-- and is the one line of it worth keeping.)

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local scale = require('corpus_scale')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CM_SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local CAND   = 'lionwseed'
local OTHER  = 'lionwfight'
local HELPER = 'lion_FightArgmaxSeed'
local UNIT   = 'npc_dota_hero_lion'
local HEX    = 'lion_voodoo'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'
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

--- ⭐⭐ BOTH corpus directories, and the widening is the 2026-09-18 repair.
--- This walk enumerated `tests/fixtures` ALONE until then, and §3.3 below is
--- the row that paid for it: its own assertion message says the CM copy
--- becomes "the next id to land" the moment an all-zero set appears there --
--- and one HAS been on the tree, in `tests/frames`, which this walk could not
--- see.  A ratchet whose message tells the next round what to do, out of a
--- scope that can never produce that message, is not a thin reading; it is a
--- reading that cannot move.  Same cause as the charter's `-199` correction
--- (「团战谓词的域要在两个语料目录上数」), which was bought on the WK row of
--- this same family and is applied here to the CM row.
---
--- ⚠️ Enumerated, never a hardcoded list, so a corpus that GROWS cannot turn
--- this file red on size alone (the `-145`/`-149` family).  Each directory
--- must yield at least one frame: a silently-empty second directory would
--- re-create exactly the defect this widening repairs.
local function fixture_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
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

--- ⭐⭐ THE BRANCH GUARD IS A DISJUNCTION, AND THE SECOND DISJUNCT IS THE
--- 2026-09-18 REPAIR.  hero_lion.lua:1541 reads
---
---     ( #nInBonusEnemyList >= 2 or #hAllyList >= 3 )
---
--- and this census transcribed the FIRST disjunct only.  The frame §6 now
--- drives end to end carries ONE enemy in the search ring and clears the guard
--- through the ALLY count -- so under the old transcription it was not merely
--- uncounted, it was unreachable by construction.  `hAllyList` is the file-level
--- upvalue X.SkillsComplement fills at hero_lion.lua:413; mirrored here off the
--- same call rather than re-typed as a radius.
---
--- ⚠️ Only the Lion copy has this shape.  CM's and WK's teamfight branches have
--- no ally disjunct, so `bAllyDisjunct` is nil for them and the guard stays the
--- enemy count alone -- a shared `>= 3` would have invented a guard neither
--- file has.
local ALLY_RADIUS = tonumber(
    read_file(SRC):match('hAllyList = J%.GetAlliesNearLoc%( bot:GetLocation%(%), (%d+) %)'))
assert(ALLY_RADIUS ~= nil,
    'X.SkillsComplement no longer fills hAllyList as '
    .. 'J.GetAlliesNearLoc( bot:GetLocation(), <n> ) -- this file\'s guard mirror is stale')

local mCENSUS = {}
local function census(unit, ability, nSearch, nAccept, bAllyDisjunct)
    local key = unit .. '|' .. ability .. '|' .. nSearch .. '|' .. tostring(nAccept)
        .. '|' .. tostring(bAllyDisjunct)
    if mCENSUS[key] ~= nil then return mCENSUS[key][1], mCENSUS[key][2], mCENSUS[key][3] end
    local c = { alive = 0, fight = 0, guard = 0, measured = 0, zero = 0,
                search_allzero = 0, accept_nonempty = 0, accept_allzero = 0,
                multi = 0, ascending = 0, argmax_frames = 0, argmax_nonnil = 0,
                guard_by_ally = 0 }
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

                    local nAllies = 0
                    if bAllyDisjunct then
                        nAllies = #J.GetAlliesNearLoc(bot:GetLocation(), ALLY_RADIUS)
                    end
                    local bGuard = (#set >= 2)
                        or (bAllyDisjunct == true and nAllies >= 3)
                    if bGuard then
                        c.guard = c.guard + 1
                        if #set < 2 then c.guard_by_ally = c.guard_by_ally + 1 end
                    end
                    if #set >= 2 then
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

tests['§3.1 ⭐⭐ this id HAS a solo domain -- 6 search-ring frames, not 0'] = function()
    local c, drivable = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET, true)

    -- Corpus-coupled sizes: FLOORS, so growth cannot turn this file red on size
    -- alone. (The pre-2026-09-18 text pinned these as equalities and then read
    -- the domain off the same walk; when the walk was too narrow BOTH were
    -- wrong and only the domain number mattered.)
    scale.ratchet(c.alive, 42, 'live-Lion instants (both corpus directories)')
    scale.ratchet(c.fight, 13, 'Lion instants clearing J.IsInTeamFight( bot, 1200 )')
    scale.ratchet(c.guard, 13, 'Lion instants clearing the branch guard '
        .. '( #nInBonusEnemyList >= 2 or #hAllyList >= 3 )')

    -- ⭐⭐ THE CORRECTED DOMAIN. This number was asserted as `== 0` until
    -- 2026-09-18 and the 0 was an artefact of the walk, not of the tree: one
    -- corpus directory out of two, and the branch guard transcribed as its
    -- first disjunct only. See §0.3.
    scale.ratchet(c.search_allzero, 6, 'search-ring all-zero frames -- what '
        .. CAND .. ' alone rescues')
    assert(c.search_allzero >= 1, CAND .. ' has no search-ring all-zero frame left. Its solo '
        .. 'domain has gone back to empty -- re-read §0.3, §5.3 and §6 before quoting either, '
        .. 'and do NOT restore the old "changes no decision alone" wording without re-driving '
        .. '§6 first.')

    -- The acceptance-ring (i.e. post-`lionwfight`) count, which is what the
    -- PAIR rescues. Still the larger claim; no longer the only one.
    scale.ratchet(c.accept_allzero, 5, 'acceptance-ring all-zero frames -- what the PAIR '
        .. 'rescues')
    local bPin = false
    for _, path in ipairs(drivable) do
        if path:find('lion_drain_survived', 1, true) ~= nil then bPin = true end
    end
    assert(bPin, 'f_260820_182906_lion_drain_survived left the drivable set (' ..
        table.concat(drivable, ', ') .. '). That is the frame §4 drives; if it is gone the '
        .. 'masking reading must be re-taken, not re-fitted.')

    -- ⛔ COUNTS OVER 144 RECORDED FRAMES WITH A RETROSPECTIVE METER. Not a
    -- frequency in play. See §0.3.
    scale.ratchet(c.measured, 10, 'legal candidates measured across branch-reaching frames')
    scale.ratchet(c.zero, 7, 'of those, candidates projecting exactly 0')
end

tests['§3.1b ⭐ 11 of the 13 guard-clearing frames clear it through the ALLY disjunct'] = function()
    -- The half of the guard this census used to drop, as its own number. It is
    -- not a detail: it is the reason the §6 witness was invisible rather than
    -- merely uncounted -- that frame carries ONE enemy in the search ring, so
    -- `#nInBonusEnemyList >= 2` is false on it and the old transcription could
    -- never have reached the decision it is about.
    local c = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET, true)
    assert(c.guard_by_ally >= 1, 'no frame clears the branch guard through `#hAllyList >= 3` '
        .. 'alone any more, so this file can no longer demonstrate WHY the first-disjunct-only '
        .. 'transcription hid a real frame. Re-read §0.3(b) before trusting it.')
    scale.ratchet(c.guard_by_ally, 11, 'guard-clearing frames that clear it via the ally count')
    -- The control: dropping the disjunct must actually lose frames, or this
    -- section is asserting something the census would satisfy either way.
    local cNoAlly = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET, false)
    assert(cNoAlly.guard < c.guard, 'the ally disjunct now adds no frames (' .. cNoAlly.guard
        .. ' vs ' .. c.guard .. '); the repair in §0.3(b) has become a no-op and this file '
        .. 'is paying for a census parameter that measures nothing')
end

tests['§3.2 the armed tie-break is the NEAREST member, measured not assumed'] = function()
    -- With the seed below the floor and a strict `>`, an all-zero set selects
    -- the FIRST member of the list. Whether that is a good target depends on an
    -- ordering nobody in this tree has written down, so measure it instead of
    -- asserting the engine sorts by distance.
    local c = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET, true)
    assert(c.multi >= 1, 'no frame carries 2+ candidates, so the ordering is unmeasured here '
        .. 'and the "nearest member" line in ' .. HELPER .. "'s header is unsupported")
    assert(c.ascending == c.multi, 'J.GetNearbyHeroes returned a NON-ascending list on '
        .. (c.multi - c.ascending) .. ' of ' .. c.multi .. ' multi-candidate frames. The armed '
        .. 'tie-break is then "an arbitrary legal member", not "the nearest" -- fix the header '
        .. 'rather than the assertion. (Still strictly better than no cast: every member has '
        .. 'cleared the full legality chain.)')
end

tests['§3.3 ⭐ the other two copies: all-zero sets DO appear -- and neither is buyable'] = function()
    -- ⛔⛔ THE ASSERTION THIS SECTION USED TO CARRY IS THE EXHIBIT.  It read
    -- `cm.search_allzero == 0 and wk.search_allzero == 0`, and its own failure
    -- message told the next round what to do the moment either went positive:
    -- "that copy is now buyable on a real frame and is the next id to land."
    -- Both HAD gone positive on the tree (cm 1, wk 2) and the message could
    -- never print, because the walk under it saw one of the two corpus
    -- directories and both frames live in the other.  ⭐ A ratchet whose
    -- message hands the next round its work, out of a scope that cannot
    -- produce that message, is not a thin reading -- it is a reading that
    -- cannot move.  That is the defect §0.3(a) repairs, priced here.
    local cm = census('npc_dota_hero_crystal_maiden', 'crystal_maiden_frostbite', 0, nil)
    local wk = census('npc_dota_hero_skeleton_king', 'skeleton_king_hellfire_blast', 43, nil)
    scale.ratchet(cm.alive, 70, 'live-CM instants (both corpus directories)')
    scale.ratchet(wk.alive, 51, 'live-WK instants (both corpus directories)')
    scale.ratchet(cm.fight, 5, 'CM instants clearing J.IsInTeamFight( bot, 1200 )')
    scale.ratchet(wk.fight, 2, 'WK instants clearing J.IsInTeamFight( bot, 1200 )')
    assert(cm.search_allzero >= 1 and wk.search_allzero >= 1,
        'an ungated copy lost its all-zero frames (cm=' .. cm.search_allzero .. ', wk='
        .. wk.search_allzero .. '). The 2026-09-18 reading in §0.3 and in the charter rests '
        .. 'on both being positive; re-take it rather than re-fitting the number.')

    -- ⛔ AND THE PART THAT MATTERS MORE THAN THE COUNT: a branch-local all-zero
    -- set is NOT a domain.  The CM copy's single all-zero frame
    -- (tests/frames/f_260909_215040_wk_blast_sb_661.lua) is blocked END TO END
    -- by two independent things, either of which alone empties it:
    --
    --   (1) Frostbite carries 3.2s of cooldown on the recording, so
    --       X.ConsiderW returns at its first line;
    --   (2) with that lifted, the 击杀敌人 branch -- which sits ABOVE the
    --       teamfight branch -- owns the frame: spirit_breaker is at 172 HP
    --       against a rank-4 Frostbite's 300 magic damage, so shipped
    --       X.ConsiderW already returns HIGH on that same enemy and the
    --       teamfight loop is never entered.
    --
    -- ⇒ the CM `= 0` seed has NO end-to-end witness on this corpus and a
    -- `cmwseed` id may NOT be landed off this count.  §6.2 drives (2) rather
    -- than asserting it, so this paragraph cannot go stale silently.
    -- (charter hero.md `-201`; the frame-supply request is queue.json hero-103.)
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

tests['§5.3 ⭐⭐ armed alone, the argmax winner MOVES on 6 frames'] = function()
    -- ⛔⛔ THIS SECTION ASSERTED THE OPPOSITE UNTIL 2026-09-18 (`#divergent == 0`,
    -- "arming this id alone changes NO decision in the corpus"), and that
    -- assertion is what hero_lion.lua's helper header quoted as settled.  It
    -- held only because the census under it walked one corpus directory and
    -- transcribed half the branch guard (§0.3).  Corrected, the same walk finds
    -- the winner moving on 6 frames -- all 6 in tests/frames, which is exactly
    -- the half it could not see.
    local c, _, divergent = census(UNIT, HEX, SEARCH_OFFSET, ACCEPT_OFFSET, true)
    scale.ratchet(#divergent, 6, 'frames where arming ' .. CAND
        .. ' alone moves the argmax winner')
    assert(#divergent >= 1, 'arming ' .. CAND .. ' alone no longer moves the argmax winner '
        .. 'anywhere. The solo domain this file, §0.3, hero_lion.lua\'s helper header and '
        .. 'queue.json hero-103 all now rest on has vanished -- re-take the reading.')

    -- ⛔ A MOVED ARGMAX WINNER IS NOT YET A MOVED DECISION, and conflating the
    -- two is how this file got its previous reading backwards in the first
    -- place. The argmax runs inside a branch that may not be entered, behind an
    -- ability that may be on cooldown, below three earlier exits. §6 settles
    -- the end-to-end question on the one frame where nothing is injected; this
    -- number is the SUPPLY for that question, not the answer to it.
    assert(c.argmax_frames >= 13, 'only ' .. c.argmax_frames .. ' frames reached the argmax, '
        .. 'was 13+ -- the comparison above is going vacuous')
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

-- ---------------------------------------------------------------- section 6 --
-- ⭐⭐ THE SOLO WITNESS, END TO END, WITH NOTHING INJECTED.
--
-- §4 pays one labelled counterfactual (Hex on cooldown) to reach its frame.
-- This one pays NONE: on tests/frames/f_260909_215040_wk_blast_lion_480.lua Hex
-- is rank 1, off cooldown and fully castable on the recording, Lion clears
-- J.IsInTeamFight, and the branch guard is cleared through `#hAllyList >= 3`.
-- ⇒ what this section reads is what shipped Lion does, and what armed Lion
-- would do, on a frame as recorded.

local SOLO_PIN = STAGED_DIR .. '/f_260909_215040_wk_blast_lion_480.lua'

--- Drive the shipped dispatch + the shipped X.ConsiderW on SOLO_PIN.  ⛔ No
--- cooldown injection, no ability-spec patching, nothing but the gate table.
local function drive_solo(tArmed)
    local J, bot = rf.load(SOLO_PIN, UNIT)
    J.IsModeTurbo = function() return true end
    J.IsSoakCandidate = function(id) return tArmed ~= nil and tArmed[id] == true end
    local X = rf.load_hero('lion')
    X.SkillsComplement()
    local nDesire, hTarget, sMotive = X.ConsiderW()
    return nDesire, hTarget, sMotive, J, bot
end

tests['§6.0 ⛔ NOTHING is injected on this frame -- pin the reads that make that true'] = function()
    local J, bot = rf.load(SOLO_PIN, UNIT)
    local hW = bot:GetAbilityByName(HEX)
    assert(hW:GetLevel() >= 1, 'Hex is unlearned on the solo pin (' .. hW:GetLevel()
        .. '); X.ConsiderW cannot reach the branch and §6 is measuring nothing')
    assert(hW:GetCooldownTimeRemaining() == 0, 'Hex now carries '
        .. hW:GetCooldownTimeRemaining() .. 's of cooldown on the solo pin. The whole point '
        .. 'of this section is that it pays NO counterfactual -- if that stopped being true, '
        .. 'say so, do not start injecting.')
    assert(hW:IsFullyCastable(), 'Hex is not fully castable on the solo pin as recorded')
    assert(J.IsInTeamFight(bot, 1200), 'the solo pin no longer clears the branch\'s entry '
        .. 'predicate')

    -- ⭐ The guard is cleared by the ALLY disjunct, not the enemy count: this is
    -- the frame §0.3(b) is about, and the reason the old census could not see
    -- it is asserted here rather than described.
    local cr = branch_cast_range(J, bot, HEX)
    local set = J.GetNearbyHeroes(bot, cr + SEARCH_OFFSET, true, BOT_MODE_NONE)
    assert(#set == 1, 'the solo pin now carries ' .. #set .. ' enemies in the search ring, '
        .. 'was 1 -- if it reached 2 this frame stopped demonstrating the dropped disjunct')
    local nAllies = #J.GetAlliesNearLoc(bot:GetLocation(), ALLY_RADIUS)
    assert(nAllies >= 3, 'the solo pin carries ' .. nAllies .. ' allies within '
        .. ALLY_RADIUS .. 'u; with fewer than 3 the branch guard fails on BOTH disjuncts and '
        .. 'this frame is no longer reachable at all')

    -- And the mechanism: the sole legal candidate projects exactly 0, which is
    -- what the shipped seed eats.
    local legal = {}
    for _, e in pairs(set) do
        if is_legal_candidate(J, e) then legal[#legal + 1] = e end
    end
    assert(#legal == 1, 'the solo pin carries ' .. #legal .. ' legal candidates, was 1')
    assert(projection(bot, legal[1]) == 0, 'the sole candidate now projects '
        .. projection(bot, legal[1]) .. ', was 0 -- the seed no longer bites here')
    assert(J.IsInRange(bot, legal[1], cr + ACCEPT_OFFSET),
        'the sole candidate left the acceptance ring, so the winner test would veto the cast '
        .. 'and this frame stops separating the two seeds')
end

tests['§6.1 ⭐⭐ shipped VETOES and the id ALONE casts -- no pairing, no injection'] = function()
    local dShip, tShip = drive_solo(nil)
    assert(dShip == 0, 'shipped X.ConsiderW now bids ' .. tostring(dShip) .. ' on the solo '
        .. 'pin. The veto this id exists for is gone HERE -- re-read §0.3 before quoting it.')
    assert(tShip == nil, 'shipped returned a target: ' .. tostring(tShip))

    local dSolo, tSolo, mSolo = drive_solo({ [CAND] = true })
    assert(dSolo == BOT_ACTION_DESIRE_HIGH, CAND .. ' armed ALONE bids ' .. tostring(dSolo)
        .. ' on the solo pin, expected BOT_ACTION_DESIRE_HIGH. This is the whole claim of '
        .. '§0.3: the id has a domain of its own.')
    assert(type(tSolo) == 'table' and tSolo.GetUnitName ~= nil,
        'the armed leg returned ' .. type(tSolo) .. ', expected a unit handle')
    assert(tSolo:GetUnitName() == 'npc_dota_hero_skeleton_king',
        'the armed leg casts on ' .. tSolo:GetUnitName() .. ', expected '
        .. 'npc_dota_hero_skeleton_king')
    assert(type(mSolo) == 'string' and mSolo:find('W%-团战'),
        'the motive is ' .. tostring(mSolo) .. ', expected the 团战 branch\'s own -- a '
        .. 'different motive means a DIFFERENT branch fired and this section proves nothing')

    -- ⛔ THE CONTROL that makes the above about the GATE and not about the
    -- frame: the other id alone must leave the veto standing here.
    local dOther = drive_solo({ [OTHER] = true })
    assert(dOther == 0, OTHER .. ' alone now casts on the solo pin (' .. tostring(dOther)
        .. '), so this frame no longer separates the two ids and cannot support the '
        .. '"' .. CAND .. ' has its OWN domain" reading')
end

tests['§6.2 ⛔ the CM copy has NO end-to-end witness -- the blocker, driven'] = function()
    -- §3.3(2), driven rather than described. On CM's one all-zero frame the
    -- 击杀敌人 branch sits above the teamfight branch and already returns HIGH,
    -- so no seed id could change that decision. This is why `-201` did NOT land
    -- a `cmwseed`, and it is asserted here so a later round cannot quietly
    -- promote the branch-local count in §3.3 into a domain.
    local CM_PIN = STAGED_DIR .. '/f_260909_215040_wk_blast_sb_661.lua'
    local CM_UNIT = 'npc_dota_hero_crystal_maiden'

    local J, bot = rf.load(CM_PIN, CM_UNIT)
    local hW = bot:GetAbilityByName('crystal_maiden_frostbite')
    assert(hW:GetCooldownTimeRemaining() > 0, 'Frostbite is off cooldown on the CM frame now '
        .. '-- blocker (1) in §3.3 is gone; re-price the CM copy, do not assume it is still '
        .. 'unbuyable')

    -- Blocker (2), with (1) lifted so it can be reached at all. ⚠️ THIS IS AN
    -- INJECTION AND IT IS LABELLED: it exists to show the SECOND blocker is
    -- independent of the first, i.e. that lifting the cooldown would not buy
    -- the domain either.
    local J2, bot2 = rf.load(CM_PIN, CM_UNIT)
    J2.IsModeTurbo = function() return true end
    J2.IsSoakCandidate = function() return false end
    local XCM = rf.load_hero('crystal_maiden')
    local hW2 = bot2:GetAbilityByName('crystal_maiden_frostbite')
    local spec = rawget(hW2, '__spec')
    spec.GetCooldownTimeRemaining = function() return 0 end
    spec.IsFullyCastable = function() return true end
    XCM.SkillsComplement()
    local d, t = XCM.ConsiderW()
    assert(d == BOT_ACTION_DESIRE_HIGH, 'with the cooldown lifted, shipped CM X.ConsiderW '
        .. 'bids ' .. tostring(d) .. ' on this frame, expected BOT_ACTION_DESIRE_HIGH from '
        .. 'the 击杀敌人 branch. If it now bids 0 the teamfight branch IS reachable and the '
        .. 'CM copy has just become buyable -- that is a `cmwseed` round, not a re-baseline.')
    assert(type(t) == 'table' and t:GetUnitName() == 'npc_dota_hero_spirit_breaker',
        'the pre-empting branch now targets ' .. tostring(type(t) == 'table' and t:GetUnitName())
        .. ', expected npc_dota_hero_spirit_breaker')
end

return tests

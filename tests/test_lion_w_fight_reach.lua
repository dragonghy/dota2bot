-- [hero] `lionwfight` -- X.ConsiderW's teamfight argmax searches a ring 300
-- units wider than the ring it will accept a winner from, so a candidate that
-- cannot be cast at can win the search and veto the whole branch.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- X.ConsiderW builds its candidate list once, at the top:
--
--     local nCastRange       = abilityW:GetCastRange() + aetherRange
--     local nInBonusEnemyList = J.GetNearbyHeroes( bot, nCastRange + 300, ... )
--
-- and the 团战 branch runs a "most dangerous enemy" argmax over that list.  The
-- reach test is applied to the WINNER, after the loop:
--
--     if npcMostDangerousEnemy ~= nil
--         and J.IsInRange( bot, npcMostDangerousEnemy, nCastRange + 50 )
--
-- Search ring nCastRange + 300, acceptance ring nCastRange + 50.  The 250 units
-- between them are an annulus whose members cannot be cast at but CAN win the
-- argmax -- and a winner drawn from there does not fall through to the best
-- in-range enemy, it ends the branch.  Lion holds Hex with a legal castable
-- enemy in range because someone slightly further out projects more damage.
--
-- The veto is SILENT.  No desire is bid, so from outside the function this is
-- indistinguishable from "no candidate existed".
--
-- ===========================================================================
-- §0.1  THE COPY LINEAGE, which is the headline
-- ===========================================================================
--
-- The same argmax body -- `local npcMostDangerousEnemy = nil`, a 0 seed, a
-- strict `>` on GetEstimatedDamageToTarget(false, bot, 3.0, PHYSICAL) -- exists
-- three times in the focus five.  The BODIES are identical.  The reach postures
-- are not, and that is the whole finding: the shape travelled between files and
-- the term that makes the shape safe did not.
--
--   crystal_maiden  ring nCastRange       , no winner test  -> correct
--   skeleton_king   ring nCastRange + 43  , no winner test  -> over-reaches 43u
--   lion            ring nCastRange + 300 , winner at +50   -> this defect
--
-- §2 parses all three rings out of source, so the day one of them moves this
-- file says so rather than the header quietly going stale.  ⛔ The WK over-reach
-- is the OPPOSITE sign (it casts out of range where Lion refuses to cast in
-- range); it is NOT this id and is not fixed here -- GH #873.
--
-- ===========================================================================
-- §0.2  WHAT THIS FILE CAN AND CANNOT BUY
-- ===========================================================================
--
-- It buys THE SHIPPED VETO OUTRIGHT, on a real frame, with nothing injected.
-- §3.2 drives it: on f_260820_182906_lion_drain_survived, Hex rank 1 (rings 625
-- and 875), Luna stands at 177.8u projecting 0 and Crystal Maiden at 625.2u
-- projecting 144 -- both fully legal candidates.  The argmax picks Crystal
-- Maiden, the winner test asks for 625, and Lion holds a hard disable over
-- 0.2 UNITS.
--
-- ⚠️ THE DRAFT OF THIS FILE ASSUMED THAT WAS UNREACHABLE, on a premise this
-- tree repeats in four places: that the loader's GetEstimatedDamageToTarget
-- "answers 0 on every fixture frame".  The 144 is a counterexample and §3.3
-- pins it.  The accurate description was already in the tree, at
-- tests/test_chasering_target_in_ring.lua:48 -- the meter answers GROUND TRUTH
-- FOR DAMAGE DEALT TO THE FIXTURE SUBJECT.  It reads 0 for an attacker who did
-- not connect in that window, which is why subject-facing pins measured 0 and
-- the coarse sentence survived.  ⛔ It is NOT "the meter is broken", and it is
-- NOT "the meter works": it is retrospective.  GH #873 carries the correction.
--
-- What still costs a declared number is only the ARMED half (§3.2b), and for
-- that same retrospective reason: Luna's 0 says she did not connect, not that a
-- carry at 177u projects nothing.
--
-- ⛔ §3.1's reading is 1-of-1 frames.  It is a RATE OVER ONE FRAME and nobody
-- may quote it as evidence about how often this fires in play.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_lion.lua'
local CM_SRC = 'bots/BotLib/hero_crystal_maiden.lua'
local WK_SRC = 'bots/BotLib/hero_skeleton_king.lua'
local CAND   = 'lionwfight'
local HELPER = 'lion_IsHexFightTargetInReach'
local UNIT   = 'npc_dota_hero_lion'
local HEX    = 'lion_voodoo'

local FIXTURE_DIR = 'tests/fixtures'

-- The branch's two rings, as OFFSETS from nCastRange.  Both are parsed out of
-- source in §1.4; these are what the header claims they are, and a mismatch is
-- a failure rather than a silent re-read.
local SEARCH_OFFSET = 300
local ACCEPT_OFFSET = 50

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

--- Every live-Lion instant in the corpus, as loaded (J, bot) pairs.  Loading is
--- the expensive part, so each caller gets the path back too and decides.
local function live_lion_frames()
    local out = {}
    for _, path in ipairs(fixture_paths()) do
        local ok, chunk = pcall(dofile, path)
        if ok and type(chunk) == 'table' then
            for _, u in ipairs(chunk.units or {}) do
                if u.name == UNIT and u.alive == true then
                    out[#out + 1] = path
                    break
                end
            end
        end
    end
    return out
end

--- X.ConsiderW's OWN ring, recomputed the way the branch computes it:
---     local nCastRange = abilityW:GetCastRange() + aetherRange
--- ⚠️ THE AETHER TERM IS NOT OPTIONAL, and this file learned that from a ratchet
--- rather than from care: tests/test_cast_ring_mirror_discipline.lua [2] failed
--- both census sites below for spelling the ring as GetCastRange() alone.  A
--- mirror that drops the term under-states its own ring by 225-250 units and
--- reads legal casts as out of range (GH #725 read an 861.99u cast as "outside
--- 670").  It is read OFF THE FRAME here, exactly as X.SkillsComplement :415
--- does, so a corpus that ever puts a lens on Lion moves this file's numbers
--- instead of silently misclassifying them.
local function branch_cast_range(J, bot)
    local aw = bot:GetAbilityByName(HEX)
    if aw == nil then return 0 end
    local base = aw:GetCastRange() or 0
    if base <= 0 then return 0 end
    local aether = J.IsItemAvailable('item_aether_lens')
    local bonus = 0
    if aether ~= nil then bonus = J.GetAetherLensRangeBonus(aether, 250) or 0 end
    return base + bonus
end

--- The branch's own candidate filter, transcribed from X.ConsiderW's 团战 loop.
--- X.IsHexAoe is a file-local and unreachable from here; it is the SECOND
--- disjunct of one conjunct, so treating it as false reproduces the shipped
--- filter on the default (no AoE talent) build.  §1.5 pins that this is still
--- what the loop tests, so the transcription cannot drift silently.
local function is_legal_candidate(J, e)
    return J.IsValid(e)
        and J.CanCastOnNonMagicImmune(e)
        and J.CanCastOnTargetAdvanced(e)
        and not J.IsDisabled(e)
        and not J.IsTaunted(e)
        and not e:IsDisarmed()
end

-- ---------------------------------------------------------------- section 1 --
-- The lever is wired where its header says it is, and nowhere else.

tests['§1.1 the teamfight argmax lives in X.ConsiderW and seeds at 0'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderW')
    assert(body:find('local%s+npcMostDangerousEnemy%s*=%s*nil'),
        'X.ConsiderW no longer runs a most-dangerous-enemy argmax -- the whole header is stale')
    -- ⚠️ THE SEED MOVED BEHIND A HELPER, and the shipped VALUE is unchanged.
    -- `lionwseed` (2026-09-17) gates this seed; gate off it still answers the
    -- literal 0 this assertion was written for, now named
    -- X.nWFightArgmaxSeedShipped. Both spellings are accepted here so this file
    -- keeps pricing what it was written to price -- the SEED POLARITY, which
    -- §0.1's lineage claim rests on -- rather than the line's typography.
    -- ⛔ The 0 itself is NOT optional: if it is ever a different number the case
    -- split in §3.2b is wrong. tests/test_lion_w_fight_seed.lua owns the gated
    -- half; this file must not also assert it, or the two ratchet each other.
    assert(body:find('local%s+nMostDangerousDamage%s*=%s*0')
        or body:find('local%s+nMostDangerousDamage%s*=%s*X%.lion_FightArgmaxSeed%(%s*%)'),
        'the argmax seed is neither the literal 0 nor X.lion_FightArgmaxSeed() -- re-read '
        .. 'both this file and tests/test_lion_w_fight_seed.lua before trusting either')
    if body:find('X%.lion_FightArgmaxSeed') then
        assert(read_file(SRC):find('X%.nWFightArgmaxSeedShipped%s*=%s*0'),
            'the gated seed helper no longer answers 0 when its gate is off. Shipped play has '
            .. 'changed underneath this file and every case split below is stale.')
    end
    assert(body:find('npcEnemyDamage%s*>%s*nMostDangerousDamage'),
        'the argmax no longer uses a strict `>` -- re-read §0 before trusting the case split')
end

tests['§1.2 the search ring is 300 over cast range and the loop walks it'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderW')
    assert(body:find('nInBonusEnemyList%s*=%s*J%.GetNearbyHeroes%(bot,%s*nCastRange%s*%+%s*'
        .. SEARCH_OFFSET .. '%s*,'),
        'X.ConsiderW no longer builds nInBonusEnemyList at nCastRange + ' .. SEARCH_OFFSET
        .. ' -- the annulus width in the helper header is wrong')
    -- The argmax must walk THAT list.  If it ever walks a narrower one the
    -- defect is gone and this lever should be retired, not relaxed.
    local at = assert(body:find('local%s+npcMostDangerousEnemy%s*=%s*nil'))
    local loop = body:sub(at, at + 400)
    assert(loop:find('for%s+_,%s*npcEnemy%s+in%s+pairs%(%s*nInBonusEnemyList%s*%)'),
        'the teamfight argmax no longer iterates nInBonusEnemyList')
end

tests['§1.3 the winner test is 50 over cast range, i.e. narrower than the search'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderW')
    assert(body:find('J%.IsInRange%(%s*bot%s*,%s*npcMostDangerousEnemy%s*,%s*nCastRange%s*%+%s*'
        .. ACCEPT_OFFSET .. '%s*%)'),
        'the winner acceptance test is no longer nCastRange + ' .. ACCEPT_OFFSET)
    assert(SEARCH_OFFSET > ACCEPT_OFFSET,
        'search offset is no longer wider than the acceptance offset -- there is no annulus '
        .. 'left and this lever has nothing to do')
end

tests['§1.4 ⭐ the reach handed to the helper IS the acceptance ring, not a copy'] = function()
    -- The one number that must not drift.  If the call site and the winner test
    -- ever disagree, armed play can refuse a candidate the shipped branch would
    -- have accepted -- which breaks the "widening only" claim the whole
    -- direction argument rests on.  Both are parsed; neither is typed twice.
    local body = fn_body(read_file(SRC), 'ConsiderW')
    local nCall = body:match('X%.' .. HELPER .. '%(%s*bot%s*,%s*npcEnemy%s*,%s*nCastRange%s*%+%s*(%d+)%s*,%s*true%s*%)')
    local nWin  = body:match('J%.IsInRange%(%s*bot%s*,%s*npcMostDangerousEnemy%s*,%s*nCastRange%s*%+%s*(%d+)%s*%)')
    assert(nCall ~= nil, 'the gated conjunct is not on the argmax filter with (bot, npcEnemy, nCastRange + N, true)')
    assert(nWin ~= nil, 'the winner acceptance test no longer reads nCastRange + N')
    assert(tonumber(nCall) == tonumber(nWin),
        'DRIFT: the lever filters at nCastRange + ' .. nCall .. ' but the branch accepts at '
        .. 'nCastRange + ' .. nWin .. '. Armed play can now REMOVE a shipped cast, and the '
        .. '"no-cast becomes cast, never the reverse" direction in the helper header is false.')
    assert(tonumber(nCall) == ACCEPT_OFFSET,
        'both moved together to ' .. nCall .. ' -- update ACCEPT_OFFSET and re-read §3')
end

tests['§1.5 the transcribed candidate filter still matches the shipped loop'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderW')
    local at = assert(body:find('local%s+npcMostDangerousEnemy%s*=%s*nil'))
    local loop = body:sub(at, at + 900)
    for _, needle in ipairs({
        'J%.IsValid%(%s*npcEnemy%s*%)',
        'J%.CanCastOnNonMagicImmune%(%s*npcEnemy%s*%)',
        'J%.CanCastOnTargetAdvanced%(%s*npcEnemy%s*%)',
        'not%s+J%.IsDisabled%(%s*npcEnemy%s*%)',
        'not%s+J%.IsTaunted%(%s*npcEnemy%s*%)',
        'not%s+npcEnemy:IsDisarmed%(%)',
    }) do
        assert(loop:find(needle),
            'the argmax filter lost/changed a conjunct (' .. needle .. '); the local '
            .. 'is_legal_candidate transcription in this file no longer reproduces it, so '
            .. 'every §3 count is measuring a different set than the branch does')
    end
    assert(loop:find('X%.IsHexAoe%(%)'),
        'the AoE disjunct left the filter -- is_legal_candidate treats it as false and says so')
end

tests['§1.6 one definition, one call site, and the gate names only its own id'] = function()
    local src = read_file(SRC)
    local nAll = select(2, src:gsub('X%.' .. HELPER .. '%s*%(', ''))
    local nDef = select(2, src:gsub('function%s+X%.' .. HELPER .. '%s*%(', ''))
    assert(nDef == 1, 'expected exactly one definition of ' .. HELPER .. ', got ' .. nDef)
    assert(nAll - nDef == 1, 'the helper is called ' .. (nAll - nDef) .. ' times (want exactly 1); '
        .. 'a second call site would put this id on a branch its header does not describe')

    local body = fn_body(src, HELPER)
    local nGate = select(2, body:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", ''))
    assert(nGate == 1, "expected exactly one IsSoakCandidate('" .. CAND .. "') in the helper, got " .. nGate)
    assert(body:find('J%.IsModeTurbo%(%)'), 'the helper is no longer turbo-only')
    -- The pullcad trap (AGENTS.md): a gate whose condition names a SIBLING id is
    -- frozen FALSE the day that sibling is promoted, and every wiring checker
    -- still calls it WIRED.
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do
        assert(id == CAND, "the helper's gate names a sibling id (" .. id .. ') -- pullcad trap')
    end
end

tests['§1.6b ⛔ this id is NOT the sibling `lionwreach` that already owns this function'] = function()
    -- The first draft of this lever reused `lionwreach`. It is the obvious name
    -- for "the W reach term", and it was already taken (:1008, 2026-09-12) by
    -- the INTERRUPT legs of this same function. Arming one string would then
    -- arm two levers on two branches -- a bundle wearing one id's clothes
    -- (GH #606), with no wave able to separate them.
    --
    -- ⭐ It was caught by the mutation stand, not by reading: M4 rewrites
    -- `IsSoakCandidate( '<CAND>' )` and perl replaced the FIRST occurrence in
    -- the file, which was the sibling's -- so the mutant applied, this file
    -- stayed green, and the "survivor" was a fact about the TREE.
    local src = read_file(SRC)
    assert(CAND ~= 'lionwreach', 'this lever took the sibling id back')
    local nSelf = select(2, src:gsub("IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)", ''))
    assert(nSelf == 1, 'this id is read in ' .. nSelf .. ' places in ' .. SRC .. ' (want exactly 1)')
    -- The sibling must still exist and still be its own id. If it were renamed
    -- or removed, the collision note in the helper header is stale.
    assert(src:find("IsSoakCandidate%(%s*'lionwreach'%s*%)"),
        'the sibling `lionwreach` left this file -- the collision note in ' .. HELPER
        .. "'s header and in state.json:lionwfight_20260917 needs re-reading")
    assert(src:find('X%.lion_IsInterruptTargetInReach'),
        'the sibling helper X.lion_IsInterruptTargetInReach is gone')
    -- ⭐ And the substantive half: the sibling reads the SAME wide ring this
    -- branch does. That is what makes this leg a THIRD consumer rather than an
    -- unrelated find, and it is the claim the helper header leads with.
    local body = fn_body(src, 'ConsiderW')
    local nRing = select(2, body:gsub('nInBonusEnemyList', ''))
    assert(nRing >= 4, 'nInBonusEnemyList is read only ' .. nRing .. ' times in X.ConsiderW '
        .. '(was >= 4). The "one ring, several consumers" claim in the helper header rests on '
        .. 'the interrupt legs and this argmax sharing it.')
end

tests['§1.7 unarmed the helper returns the shipped answer it was handed'] = function()
    -- Driven, not read.  soak_side.lua is absent or disarmed in this container,
    -- so J.IsSoakCandidate is false and every path must return bShippedInReach.
    local J = rf.load(live_lion_frames()[1], UNIT)
    local X = dofile(SRC)
    assert(type(X) == 'table' and type(X[HELPER]) == 'function',
        SRC .. ' did not return a table carrying ' .. HELPER)
    assert(X[HELPER](nil, nil, 650, true) == true, 'unarmed helper did not pass `true` through')
    assert(X[HELPER](nil, nil, 650, false) == false, 'unarmed helper did not pass `false` through')
    assert(J ~= nil)
end

-- ---------------------------------------------------------------- section 2 --
-- ⭐ The copy lineage.  Three files, one argmax body, three reach postures.

tests['§2.1 all three copies carry the byte-identical argmax body'] = function()
    for _, pair in ipairs({ { SRC, 'ConsiderW' }, { CM_SRC, 'ConsiderW' }, { WK_SRC, 'ConsiderQ' } }) do
        local body = fn_body(read_file(pair[1]), pair[2], pair[1])
        assert(body:find('local%s+npcMostDangerousEnemy%s*=%s*nil'),
            pair[1] .. ' X.' .. pair[2] .. ' lost the most-dangerous argmax; the lineage claim '
            .. 'in ' .. SRC .. "'s " .. HELPER .. ' header is stale')
        -- ⚠️ Lion's seed is gated by `lionwseed` since 2026-09-17 and reads
        -- X.lion_FightArgmaxSeed(), which answers the same literal 0 with its
        -- gate off (§1.1 asserts that). The lineage claim is about the SEED
        -- POLARITY being identical in all three copies, and it still is.
        assert(body:find('local%s+nMostDangerousDamage%s*=%s*0')
            or body:find('local%s+nMostDangerousDamage%s*=%s*X%.lion_FightArgmaxSeed%(%s*%)'),
            pair[1] .. ' no longer seeds the argmax at 0 (nor via the gated seed helper)')
        assert(body:find('GetEstimatedDamageToTarget%(%s*false%s*,%s*bot%s*,%s*3%.0%s*,%s*DAMAGE_TYPE_PHYSICAL%s*%)'),
            pair[1] .. ' no longer measures with GetEstimatedDamageToTarget(false, bot, 3.0, PHYSICAL)')
    end
end

tests['§2.2 ⭐ and the three rings differ -- the shape travelled, the reach term did not'] = function()
    -- CM: the list the argmax walks is built at nCastRange exactly.
    local cm = fn_body(read_file(CM_SRC), 'ConsiderW', CM_SRC)
    local cmOff = cm:match('nEnemysHeroesInRange%s*=%s*J%.GetNearbyHeroes%(bot,%s*nCastRange%s*%+%s*(%d+)')
    assert(cmOff == nil,
        'crystal_maiden grew a +' .. tostring(cmOff) .. ' offset on its argmax list. It was the '
        .. 'CORRECT copy (search ring == castable ring) and the lineage table in ' .. HELPER
        .. "'s header cites it as such -- re-read that table, and price the new offset.")
    assert(cm:find('nEnemysHeroesInRange%s*=%s*J%.GetNearbyHeroes%(bot,%s*nCastRange%s*,'),
        'crystal_maiden no longer builds its argmax list at a bare nCastRange')

    -- WK: built 43 over cast range, and the winner is NEVER distance tested.
    local wk = fn_body(read_file(WK_SRC), 'ConsiderQ', WK_SRC)
    local wkOff = tonumber(wk:match('nEnemysHerosInRange%s*=%s*J%.GetNearbyHeroes%(bot,%s*nCastRange%s*%+%s*(%d+)'))
    assert(wkOff == 43, 'skeleton_king argmax ring offset is ' .. tostring(wkOff) .. ', was 43')
    local wkAt = assert(wk:find('local%s+npcMostDangerousEnemy%s*=%s*nil'))
    local wkTail = wk:sub(wkAt)
    assert(not wkTail:find('J%.IsInRange%(%s*bot%s*,%s*npcMostDangerousEnemy'),
        'skeleton_king grew a winner reach test -- GH #873 may be fixed; if so say so there '
        .. 'and drop this assertion, do not relax it')

    -- Lion: built 300 over, accepted at 50 over.  The outlier.
    local li = fn_body(read_file(SRC), 'ConsiderW')
    local liOff = tonumber(li:match('nInBonusEnemyList%s*=%s*J%.GetNearbyHeroes%(bot,%s*nCastRange%s*%+%s*(%d+)'))
    assert(liOff == SEARCH_OFFSET, 'lion argmax ring offset is ' .. tostring(liOff))
    assert(liOff > wkOff, 'lion is no longer the widest search ring of the three')
end

-- ---------------------------------------------------------------- section 3 --
-- The domain, on real frames.

--- One pass over the corpus, shared by §3.1 and §3.3 so the frames are loaded
--- once.  Returns the counts and the paths that carry the drivable shape.
local function census()
    local c = { alive = 0, fight = 0, guard = 0, drivable = 0, annulus_only = 0, zero_meter = 0, measured = 0 }
    local drivable = {}
    for _, path in ipairs(live_lion_frames()) do
        c.alive = c.alive + 1
        local ok = pcall(function()
            local J, bot = rf.load(path, UNIT)
            local cr = branch_cast_range(J, bot)
            if cr <= 0 then return end
            if not J.IsInTeamFight(bot, 1200) then return end
            c.fight = c.fight + 1
            local bonus = J.GetNearbyHeroes(bot, cr + SEARCH_OFFSET, true, BOT_MODE_NONE)
            local allies = J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
            if not (#bonus >= 2 or #allies >= 3) then return end
            c.guard = c.guard + 1
            local nIn, nAnn = 0, 0
            for _, e in pairs(bonus) do
                if is_legal_candidate(J, e) then
                    c.measured = c.measured + 1
                    if e:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL) == 0 then
                        c.zero_meter = c.zero_meter + 1
                    end
                    if J.IsInRange(bot, e, cr + ACCEPT_OFFSET) then nIn = nIn + 1 else nAnn = nAnn + 1 end
                end
            end
            if nAnn > 0 and nIn > 0 then
                c.drivable = c.drivable + 1
                drivable[#drivable + 1] = path
            elseif nAnn > 0 then
                c.annulus_only = c.annulus_only + 1
            end
        end)
        assert(ok, 'census failed on ' .. path)
    end
    return c, drivable
end

tests['§3.1 the annulus is a real region at a real instant (1 of 1 branch frames)'] = function()
    local c, drivable = census()
    assert(c.alive == 25, 'live-Lion instants ' .. c.alive .. ', was 25. The corpus moved; '
        .. 're-read every count in this section and in the helper header before quoting one.')
    assert(c.fight == 5, 'J.IsInTeamFight true on ' .. c.fight .. ' of them, was 5')
    assert(c.guard == 1, c.guard .. ' frames clear the branch\'s second guard, was 1')
    -- ⛔ THE READING, and its size: one frame reaches the branch, and it has the
    -- drivable shape.  1-of-1 is a rate over ONE frame.
    assert(c.drivable == 1,
        c.drivable .. ' frames carry a legal candidate on BOTH sides of the acceptance ring '
        .. '(was 1). If this went to 0 the lever lost its only witnessed domain and must be '
        .. 're-priced before anyone asks for a wave.')
    assert(#drivable == 1 and drivable[1]:find('lion_drain_survived', 1, true) ~= nil,
        'the drivable frame is no longer f_260820_182906_lion_drain_survived: '
        .. tostring(drivable[1]))
end

local PIN = FIXTURE_DIR .. '/f_260820_182906_lion_drain_survived.lua'

--- The branch's decision, recomputed from the shipped source's own shape: seed
--- at 0, strict `>` argmax over `set`, then the winner acceptance test.  §1.1
--- and §1.3 pin that this is still what X.ConsiderW does.
local function decide(J, bot, cr, set)
    local win, best = nil, 0
    for _, e in ipairs(set) do
        local d = e:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
        if d > best then best, win = d, e end
    end
    if win ~= nil and J.IsInRange(bot, win, cr + ACCEPT_OFFSET) then return win end
    return nil
end

--- The pin's two candidates, sorted by which side of the acceptance ring they
--- are on.  Nothing here is injected.
local function pin_sides()
    local J, bot = rf.load(PIN, UNIT)
    local cr = branch_cast_range(J, bot)
    local inner, outer
    for _, e in pairs(J.GetNearbyHeroes(bot, cr + SEARCH_OFFSET, true, BOT_MODE_NONE)) do
        if is_legal_candidate(J, e) then
            if J.IsInRange(bot, e, cr + ACCEPT_OFFSET) then inner = e else outer = e end
        end
    end
    return J, bot, cr, inner, outer
end

tests['§3.2 ⭐ the shipped veto, witnessed on the pin with NOTHING injected'] = function()
    local J, bot, cr, inner, outer = pin_sides()
    assert(inner ~= nil and outer ~= nil, 'the pin lost one side of the ring')
    -- 575 is lion_voodoo rank 1 with NO lens on the frame. Both halves are
    -- asserted, so "the ring moved" and "a lens appeared" cannot be confused.
    assert(J.IsItemAvailable('item_aether_lens') == nil,
        'Lion now carries an aether lens on the pin -- every ring number in this file '
        .. 'moves by J.GetAetherLensRangeBonus and must be re-read, not re-fitted')
    assert(cr == 575, 'Hex cast range on the pin is ' .. cr .. ', was 575 (rank 1, no lens)')
    assert(inner:GetUnitName() == 'npc_dota_hero_luna', 'inner candidate is ' .. inner:GetUnitName())
    assert(outer:GetUnitName() == 'npc_dota_hero_crystal_maiden', 'outer is ' .. outer:GetUnitName())

    -- ⭐ THE MARGIN. The winner fails the acceptance test by two tenths of a unit.
    local dOuter = GetUnitToUnitDistance(bot, outer)
    assert(dOuter > cr + ACCEPT_OFFSET and dOuter < cr + ACCEPT_OFFSET + 1,
        'the annulus member is at ' .. string.format('%.1f', dOuter) .. 'u against an acceptance '
        .. 'ring of ' .. (cr + ACCEPT_OFFSET) .. '. It was 625.2 -- 0.2u outside. If it moved, '
        .. 'the "held over 0.2 units" line in the helper header is stale.')

    -- Real numbers, read off the frame.  This is what makes §3.2 injection-free.
    assert(outer:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL) == 144,
        'the annulus member projects '
        .. outer:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL) .. ', was 144')
    assert(decide(J, bot, cr, { outer, inner }) == nil,
        'shipped play is supposed to VETO here: the annulus member wins the argmax on real '
        .. 'numbers and then fails the winner test. If it now casts, the defect this lever '
        .. 'exists for is gone and the lever should be RETIRED, not relaxed.')
end

tests['§3.2b ⛔ and arming this id ALONE does not rescue that frame -- the 0 seed eats it'] = function()
    -- The two defects in these six lines mask each other. This is a fact about
    -- WAVE ORDER, and it is driven here so nobody re-measures it as a fact about
    -- this lever ("tested, no effect").
    local J, bot, cr, inner, outer = pin_sides()
    assert(inner:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL) == 0,
        'the in-range candidate now projects a number, so the masking below is gone -- '
        .. 're-read the wave-order note in ' .. HELPER .. "'s header")
    assert(decide(J, bot, cr, { inner }) == nil,
        'armed play must ALSO return nothing on this frame: Luna projects 0, the argmax seeds '
        .. 'at 0 and tests with a strict `>`, so the seed drops the only candidate left')

    -- ONE DECLARED NUMBER, and what it is for: the meter is RETROSPECTIVE (§3.3),
    -- so Luna's 0 means she did not connect in that window, not that a carry at
    -- 177.8u projects nothing. Give her any positive projection and the lever's
    -- own half of the frame appears. Nothing else is touched.
    rawget(inner, '__spec').GetEstimatedDamageToTarget = function() return 1 end
    assert(decide(J, bot, cr, { outer, inner }) == nil, 'shipped still vetoes, as in §3.2')
    assert(decide(J, bot, cr, { inner }) == inner,
        'armed must cast on the in-range enemy once it projects anything at all')

    -- The direction claim, same frame: when the shipped winner is already in
    -- range, filtering the annulus changes NOTHING. Second declared number.
    rawget(outer, '__spec').GetEstimatedDamageToTarget = function() return 0 end
    assert(decide(J, bot, cr, { outer, inner }) == inner and decide(J, bot, cr, { inner }) == inner,
        'with the in-range enemy most dangerous, armed and shipped must agree on the target -- '
        .. 'this is the "never retargets a shipped cast" half of the direction claim')
end

tests['§3.3 ⚠️ the meter is RETROSPECTIVE, not always-zero -- pin both readings'] = function()
    -- This assertion exists because the coarse sentence ("answers 0 on every
    -- fixture frame", jmz_func.lua:9905 / _overchase_sweep.lua:38 /
    -- test_focus_decision_reachability.lua §4.3b prose) is FALSE, and being
    -- false in the conservative direction is what kept this family unmeasured.
    -- One frame carrying BOTH readings is the whole guard: an always-0 loader
    -- and a fully-live loader each turn one of these two red.
    local J, bot = rf.load(PIN, UNIT)
    local zero, live = 0, 0
    for _, e in pairs(J.GetNearbyHeroes(bot, 875, true, BOT_MODE_NONE)) do
        local d = e:GetEstimatedDamageToTarget(false, bot, 3.0, DAMAGE_TYPE_PHYSICAL)
        if d == 0 then zero = zero + 1 elseif d > 0 then live = live + 1 end
    end
    assert(zero >= 1, 'no candidate reads 0 any more -- the meter stopped being retrospective; '
        .. 'every "the corpus cannot answer this" note keyed to it is now re-buyable')
    assert(live >= 1, 'every candidate reads 0 again. If this is a loader change the tree\'s '
        .. '"answers 0 on every fixture frame" prose became true by accident; if it is a corpus '
        .. 'change, §3.1 and §3.2 are measuring a different frame.')
    local c = census()
    assert(c.measured > 0, 'no legal candidate was measured at all -- §3.1 is measuring nothing')
    assert(c.zero_meter == 1 and c.measured == 2,
        'the branch-reaching census now measures ' .. c.measured .. ' candidates of which '
        .. c.zero_meter .. ' read 0 (was 2 and 1)')
end

-- ---------------------------------------------------------------- section 4 --
-- ⭐ THE ARMED LEG, DRIVEN.  This section exists because the mutation stand said
-- so: M6 (armed leg answers `true`), M7 (nil guard dropped) and M8 (type guard
-- dropped) all SURVIVED the first draft.  §1 parses the helper and §3 drives a
-- local re-implementation of the branch, so between them nothing ever EXECUTED
-- the armed return -- the file proved the defect and the shape of the fix, and
-- said nothing about whether the helper implements it.
--
-- soak_side.lua is absent or disarmed in this container, so the gate is driven
-- by stubbing J.IsSoakCandidate / J.IsModeTurbo on the same J table the hero
-- module holds (the tree's idiom -- tests/_blinkproj_sweep.lua:128 and others).
-- Every stub is restored in the same test, pcall-protected, so a failure here
-- cannot leave a live gate behind for another section.

--- Run `fn` with the lever armed, then put J back however `fn` ends.
local function with_armed(J, fn)
    local oldCand, oldTurbo = J.IsSoakCandidate, J.IsModeTurbo
    J.IsSoakCandidate = function(id) return id == CAND end
    J.IsModeTurbo = function() return true end
    local ok, err = pcall(fn)
    J.IsSoakCandidate, J.IsModeTurbo = oldCand, oldTurbo
    if not ok then error(err, 0) end
end

tests['§4.1 armed, the helper actually measures the reach it was handed'] = function()
    local J, bot, cr, inner, outer = pin_sides()
    local X = dofile(SRC)
    assert(type(X) == 'table' and type(X[HELPER]) == 'function', SRC .. ' lost ' .. HELPER)
    with_armed(J, function()
        -- The in-range candidate survives the filter; the annulus member does not.
        -- This is the whole armed behaviour, on the real frame, real positions.
        assert(X[HELPER](bot, inner, cr + ACCEPT_OFFSET, true) == true,
            'armed, the helper rejected the candidate at '
            .. string.format('%.1f', GetUnitToUnitDistance(bot, inner))
            .. 'u against a reach of ' .. (cr + ACCEPT_OFFSET))
        assert(X[HELPER](bot, outer, cr + ACCEPT_OFFSET, true) == false,
            'armed, the helper ACCEPTED the annulus member at '
            .. string.format('%.1f', GetUnitToUnitDistance(bot, outer))
            .. 'u against a reach of ' .. (cr + ACCEPT_OFFSET) .. '. The lever is a no-op.')
        -- The reach is the argument, not a number baked into the helper.
        assert(X[HELPER](bot, outer, cr + SEARCH_OFFSET, true) == true,
            'the helper ignores the reach it is handed -- it is measuring against something '
            .. 'of its own, so §1.4\'s drift guard is guarding nothing')
    end)
end

tests['§4.2 armed, the shipped `false` is STILL passed through (one-way, driven)'] = function()
    local J, bot, cr, inner = pin_sides()
    local X = dofile(SRC)
    with_armed(J, function()
        -- The direction claim's floor: armed may turn a shipped true into false,
        -- never a shipped false into true. Driven on the candidate that WOULD
        -- pass the reach test, so only the passthrough can produce the false.
        assert(X[HELPER](bot, inner, cr + ACCEPT_OFFSET, false) == false,
            'armed, a shipped `false` came back true -- the helper can now ADD a candidate '
            .. 'the shipped filter rejected, and the whole direction argument is void')
    end)
end

tests['§4.3 armed, the guards return the shipped answer instead of erroring'] = function()
    local J, bot, cr = pin_sides()
    local X = dofile(SRC)
    with_armed(J, function()
        -- M7: a nil handle must not reach J.IsInRange.
        assert(X[HELPER](nil, nil, cr + ACCEPT_OFFSET, true) == true,
            'armed with nil handles, the helper did not fall back to the shipped answer')
        assert(X[HELPER](bot, nil, cr + ACCEPT_OFFSET, true) == true,
            'armed with a nil target, the helper did not fall back to the shipped answer')
        -- M8: a non-number reach must not be compared.
        assert(X[HELPER](bot, bot, 'not a number', true) == true,
            'armed with a string reach, the helper did not fall back to the shipped answer')
    end)
end

tests['§4.4 UNARMED the same calls are inert -- the gate, not the guards, is the difference'] = function()
    -- The control for §4.1: without arming, the annulus member passes. If this
    -- ever returns false the lever is live in shipped play, which is the one
    -- thing a soak candidate must never be.
    local _, bot, cr, inner, outer = pin_sides()
    local X = dofile(SRC)
    assert(X[HELPER](bot, outer, cr + ACCEPT_OFFSET, true) == true,
        'UNARMED, the helper filtered the annulus member. This lever is LIVE in shipped play.')
    assert(X[HELPER](bot, inner, cr + ACCEPT_OFFSET, true) == true,
        'UNARMED, the helper filtered an in-range candidate')
end

return tests

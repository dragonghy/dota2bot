-- [hero] PRICING, NOT A LEVER.  GH #873 §四 handed the hero stream one open
-- question: X.ConsiderQ's teamfight firing point runs its argmax over
-- `nEnemysHerosInRange` (nCastRange + 43) and returns the winner with no
-- distance test, so it can commit Wraithfire Blast to a target up to 43 units
-- outside cast range -- is that worth a soak-candidate id?
--
-- THE ANSWER THIS FILE MACHINE-CHECKS IS **DO-NOT-ARM**, on three independent
-- legs.  Nothing is gated here and bots/ is not edited; the candidate is
-- retired, and this file is the ratchet that makes the retirement re-checkable
-- instead of a sentence in a report.
--
-- ===========================================================================
-- §0.1  LEG 1 -- MAGNITUDE, BY THIS FUNCTION'S OWN STANDARD
-- ===========================================================================
--
-- 43 is not compared against zero here, it is compared against the slack THIS
-- FUNCTION already ships.  X.ConsiderQ's own admission constant is +80, and it
-- appears at BOTH of the firing points that do bound distance:
--
--     kill-confirm   :1341   GetUnitToUnitDistance(...) <= nCastRange + 80
--     打架先手       :1407   J.IsInRange( npcTarget, bot, nCastRange + 80 )
--
-- and again at :993, as the reach term the hero stream's own landed candidate
-- `wkqlane` uses -- whose note names it in those words, "the GATE, not the
-- search ring".  So the whole band this candidate would refuse,
-- (nCastRange, nCastRange + 43], sits INSIDE what this function calls in range
-- at three other places.  Arming it would make the teamfight leg strictly
-- stricter than every branch in the same function that tests distance at all.
-- §2 asserts 43 < 80 with both numbers PARSED from the source, so the day
-- either constant moves this leg is re-taken rather than quoted.
--
-- The realised cost is smaller than 43 anyway.  §3 measures the band
-- occupancy: the worst real overextension in the whole corpus is lion at
-- 547.5u, 22.5 units past a 525 cast range -- 0.075s of walking at 300 move
-- speed, on a MELEE hero with 150 attack range, TOWARD the enemy he is in a
-- teamfight with.  Compare the walk that did earn an id in this function:
-- `wkqlane`'s real frame is a 56.6u approach out of one's own creep wave in the
-- laning phase, and its 330u ring allows 7.7x this one.
--
-- ===========================================================================
-- §0.2  LEG 2 -- THE OVEREXTENSION IS A PROPERTY OF THE LIST, NOT OF THE LEG
-- ===========================================================================
--
-- `nEnemysHerosInRange` is built once at :1326 and iterated by FOUR of the ten
-- firing points, and not one of the four tests the distance of the candidate it
-- returns:
--
--     3  teamfight          argmax winner, no distance term   <- GH #873 §四
--     6  retreat            first admissible, no distance term
--     9  recently-damaged   first admissible, no distance term
--     10 generic catch-all  first admissible, no distance term
--
-- So a lever scoped to firing point 3 does not remove an out-of-range cast, it
-- RELOCATES one -- the `lionrreach` trap (GH #617).  `wkqlane` checked that trap
-- and passed it, because its band lies OUTSIDE every other point's ring.  This
-- candidate's band lies INSIDE the very list three later points iterate, so it
-- fails the same check, and §4 DRIVES that rather than arguing it: on both
-- corpus frames where the band decides anything, the real dispatch blasts the
-- out-of-range target and the cast is the CATCH-ALL's, not the teamfight leg's.
--
-- The list-scoped alternative (edit :1326 from +43 to +0) is not the same fix
-- wearing a wider scope -- it moves four firing points in one change, which is
-- the `lanefix` bundle lesson in AGENTS.md ("locally-correct != emergently-
-- good", REJECTED twice).  It is not proposed here either.
--
-- ===========================================================================
-- §0.3  LEG 3 -- THE DOMAIN IS EMPTY, AND EMPTY FOR A CHECKABLE REASON
-- ===========================================================================
--
-- Measured over both corpus directories, 144 frames, Wraith King present and
-- alive on 51 (§3 asserts every number in this paragraph):
--
--     enemy hero in the band (nCastRange, nCastRange + 43]   6 frames
--     ...of which the band holds an enemy the CAST RING does not
--                                    ("band-only", the only frames on which a
--                                     narrowing could turn a cast into a
--                                     no-cast at all)          2 frames
--     J.IsInTeamFight( bot, 1200 ) true                        2 frames
--     INTERSECTION OF THE LAST TWO                             0 frames
--
-- A teamfight-scoped id would therefore have ZERO witness frames in the archive
-- -- it could not be fixture-validated at all, which is the mandatory cheap
-- stage of the iteration loop.  ⚠️ This corrects a number the hero stream's own
-- backlog entry `-197` carries: it read the teamfight predicate as true on 0 WK
-- frames.  It is 2, and both are in tests/frames/ (the staged directory), which
-- a tests/fixtures-only enumerator does not see.  The correction does not move
-- the verdict -- the intersection is what matters and it is 0 either way -- but
-- a later round that quotes "0 teamfight frames" would be quoting a stale
-- reading of a smaller corpus.
--
-- ===========================================================================
-- §0.4  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua wk_q_teamfight_reach_pricing
--     bash tools/agent/mutstand_wkqreach.sh
--     bash tools/agent/luacheck_gate.sh
--
-- ===========================================================================
-- §0.5  LIMITS -- load-bearing, quote these with any number above
-- ===========================================================================
--
-- 1. THREE INJECTIONS in §4, all three structural rather than convenient, all
--    three asserted to have been read before any reading is taken (§4.3):
--      (a) GetCastRange -> 525.  GetCastRange is on no spec in tests/mock, so
--          the generic `^Get` default answers 0 on every archive frame (the
--          meter-zero family X.ConsiderQ's kill-confirm note records).  At 0
--          both rings collapse and NO frame reaches any firing point, for a
--          reason about the harness rather than about the game.  525 is this
--          ability's own AbilityCastRange, already in the tree at
--          tests/mock/special_value_shapes.lua.
--      (b) GetCooldownTimeRemaining -> 0 and IsFullyCastable -> true.  The
--          catch-all's own note records the corpus fact these work around:
--          every WK frame with enemies in this ring has the Blast unlearned or
--          on cooldown.  Without them X.ConsiderQ returns on its first line and
--          §4 would prove nothing about any firing point.
--    Geometry, roster, health, hero level, ability ranks and the teamfight
--    predicate are REAL and untouched on every frame read here.
-- 2. §3's counts are a CORPUS reading, not a frequency.  The fixtures were each
--    frozen for some other hero's decision, so WK's 51 frames are an incidental
--    sample; the corpus is also early-game (levels 1..9 on the band frames).
--    A zero here shows EMPTY, never RARE -- the same bound the catch-all's own
--    note attaches to its census.
-- 3. THIS FILE DOES NOT TOUCH THE CHANNEL INTERRUPT (firing point 1), the other
--    unbounded point, nor the +330 ring.  §5 asserts the teamfight leg is still
--    unbounded and that no gate was landed on it, so that a future round cannot
--    read this file as having fixed anything.
-- 4. WHETHER THE 22.5u APPROACH WAS WORTH TAKING IS NOT SETTLED HERE, and does
--    not need to be: leg 2 says a branch-scoped lever cannot stop it anyway.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC   = 'bots/BotLib/hero_skeleton_king.lua'
local UNIT  = 'npc_dota_hero_skeleton_king'
local BLAST = 'skeleton_king_hellfire_blast'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local CAST_RANGE = 525          -- AbilityCastRange, tests/mock/special_value_shapes.lua

-- The two band-only frames, named so §4 cannot quietly drift onto some other
-- frame if the corpus grows.  §3 asserts the census still returns exactly these.
local BAND_ONLY = {
    { path = 'tests/fixtures/f_073148_zuus_lina.lua',
      enemy = 'npc_dota_hero_sven',  dist = 536.4 },
    { path = 'tests/frames/f_260909_215040_wk_blast_lion_480.lua',
      enemy = 'npc_dota_hero_lion',  dist = 547.5 },
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

local function consider_q_body(src)
    local from = src:find('\nfunction%s+X%.ConsiderQ%s*%(')
    assert(from, 'X.ConsiderQ is gone from ' .. SRC)
    local rest = src:sub(from + 1)
    local to = rest:find('\nend\n')
    assert(to, 'X.ConsiderQ has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

--- Install `v` as the answer to `h:k()`.
---
--- ⚠️ THE SECOND LINE IS DEFENSIVE, NOT LOAD-BEARING, and this note corrects the
--- one it was copied from.  tests/test_wk_q_lane_reach.lua says here that
--- "setting only the spec entry leaves an already-materialised method in place
--- and the injection silently does not take"; tests/mock/replay_fixture.lua:1534
--- states the same mechanism.  MEASURED 2026-09-17 (this file's mutation stand,
--- M10), it is false for this mock: tests/mock/bot_api.lua:188-203 materialises
--- the method once and rawsets it, but that closure reads `spec[key]` AT CALL
--- TIME, so a spec-only write takes effect on an already-cached method.  Driven
--- on a real handle: GetCastRange reads 0, then 525 after a spec-only write with
--- NO cache drop.  The line is kept (it is free, and it is what the sibling
--- files do) but nothing here rests on it, and M10 is scored as a proven
--- equivalent rather than as coverage.
local function inject(h, k, v)
    rawget(h, '__spec')[k] = v
    rawset(h, k, nil)
end

--- Is WK present and alive on this frame?  Read off the chunk rather than off a
--- loaded handle, so a frame that cannot be loaded at all is not silently
--- counted as "WK absent".
local function wk_alive(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == UNIT and u.alive ~= false then return true end
    end
    return false
end

--- Drive the REAL dispatch on a real frame with the §0.5 limit 1 injections in
--- place.  `fCatchAll`, when given, replaces the catch-all branch's own gated
--- conjunct X.wk_IsCatchAllOddsOk -- a member consulted at THAT branch and
--- nowhere else, which is how §4 attributes a cast to a firing point by
--- IDENTITY rather than by counting returns.
local function drive(path, fCatchAll)
    local J, bot = rf.load(path, UNIT)
    local X = rf.load_hero('skeleton_king')
    local hQ = bot:GetAbilityByName(BLAST)
    inject(hQ, 'GetCastRange', CAST_RANGE)
    inject(hQ, 'GetCooldownTimeRemaining', 0)
    inject(hQ, 'IsFullyCastable', true)
    if fCatchAll ~= nil then X.wk_IsCatchAllOddsOk = fCatchAll end
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, J, bot, X, hQ
end

--- The blast target the dispatch actually ordered, or nil if it ordered none.
local function blasted(log)
    for _, a in ipairs(log) do
        if a.fn:find('UseAbilityOnEntity') then
            local h = a.args[2]
            if h ~= nil and h.GetUnitName ~= nil then return h:GetUnitName() end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- The shape, parsed out of the shipped source.  §0.2's table is not narrated
-- here; it is read off the file, so the day a firing point changes which list
-- it walks, this goes red instead of the table going stale.

tests['§1.1 the two search rings are +43 and +330, off one cast range'] = function()
    local body = consider_q_body(read_file(SRC))
    local eps = body:match('nEnemysHerosInRange%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*nCastRange%s*%+%s*(%d+)')
    local bonus = body:match('nEnemysHerosInBonus%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*nCastRange%s*%+%s*(%d+)')
    assert(eps == '43', 'the teamfight leg\'s search ring is no longer nCastRange + 43 (got '
        .. tostring(eps) .. ') -- GH #873 §四 is about that constant, so every '
        .. 'number in §0 is re-taken rather than quoted')
    assert(bonus == '330', 'the bonus ring is no longer nCastRange + 330 (got '
        .. tostring(bonus) .. ')')
end

tests['§1.2 four firing points walk nEnemysHerosInRange, none of them bounds its winner'] = function()
    local body = consider_q_body(read_file(SRC))
    local nRange = 0
    for _ in body:gmatch('for%s+_%s*,%s*npcEnemy%s+in%s+pairs%(%s*nEnemysHerosInRange%s*%)') do
        nRange = nRange + 1
    end
    assert(nRange == 4, 'nEnemysHerosInRange is walked by ' .. nRange
        .. ' firing points, was 4 (teamfight / retreat / recently-damaged / '
        .. 'catch-all).  §0.2 leg 2 -- the relocation argument -- is counted off '
        .. 'this number, so re-take it rather than quoting it.')

    -- The teamfight leg specifically: from its argmax loop to its return, there
    -- must be no distance term.  That absence IS the GH #873 §四 finding, and
    -- the day somebody adds one this assertion says so.
    local from = body:find('if%s+J%.IsInTeamFight%(%s*bot%s*,%s*1200%s*%)')
    assert(from, 'the teamfight firing point no longer gates on '
        .. 'J.IsInTeamFight( bot, 1200 )')
    local to = body:find('return%s+BOT_ACTION_DESIRE_HIGH%s*,%s*npcMostDangerousEnemy', from)
    assert(to, 'the teamfight firing point no longer returns npcMostDangerousEnemy')
    local leg = body:sub(from, to)
    assert(not leg:find('IsInRange') and not leg:find('GetUnitToUnitDistance'),
        'the teamfight firing point now HAS a distance term.  That is the fix '
        .. 'GH #873 §四 asked to be priced; this file argues DO-NOT-ARM and its '
        .. 'whole §0.2 is about the absence, so it must be re-read, not amended.')
end

-- ---------------------------------------------------------------- section 2 --
-- Leg 1.  Both constants parsed; neither typed.

tests['§2 the 43u band sits inside this function\'s own +80 admission slack'] = function()
    local body = consider_q_body(read_file(SRC))
    local eps = tonumber(body:match('nEnemysHerosInRange%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*nCastRange%s*%+%s*(%d+)'))
    local kill = tonumber(body:match('GetUnitToUnitDistance%(%s*bot%s*,%s*npcEnemy%s*%)%s*<=%s*nCastRange%s*%+%s*(%d+)'))
    local commit = tonumber(body:match('J%.IsInRange%(%s*npcTarget%s*,%s*bot%s*,%s*nCastRange%s*%+%s*(%d+)%s*%)'))
    assert(eps and kill and commit, 'one of the three constants no longer parses ('
        .. tostring(eps) .. ' / ' .. tostring(kill) .. ' / ' .. tostring(commit)
        .. ') -- §0.1 is arithmetic on these three and cannot be quoted without them')
    assert(kill == commit, 'the two bounded firing points no longer share one '
        .. 'admission constant (' .. kill .. ' vs ' .. commit .. ').  §0.1 leg 1 '
        .. 'rests on there BEING a single "this function\'s own slack".')
    assert(eps < kill, 'the teamfight leg\'s search ring (+' .. eps .. ') is no '
        .. 'longer inside this function\'s own admission slack (+' .. kill
        .. ').  Leg 1 of the DO-NOT-ARM is exactly that containment; it is now '
        .. 'false and the verdict must be re-taken.')
end

-- ---------------------------------------------------------------- section 3 --
-- Leg 3.  The domain, counted -- a census that cannot go red is a sentence.

tests['§3 the band is thin, the teamfight predicate is rare, and they do not meet'] = function()
    local body = consider_q_body(read_file(SRC))
    local eps = tonumber(body:match('nEnemysHerosInRange%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*nCastRange%s*%+%s*(%d+)'))
    local bonus = tonumber(body:match('nEnemysHerosInBonus%s*=%s*J%.GetNearbyHeroes%(%s*bot%s*,%s*nCastRange%s*%+%s*(%d+)'))

    local nFiles, nLive = 0, 0
    local nBandFrames, nBandEnemies, nBandOnly, nTeamFight, nBoth = 0, 0, 0, 0, 0
    local tBandOnly = {}
    local fWorst, sWorst, nWorst = nil, nil, 0
    for _, path in ipairs(corpus_paths()) do
        nFiles = nFiles + 1
        if wk_alive(path) then
            nLive = nLive + 1
            local J, bot = rf.load(path, UNIT)
            local nIn, nBand = 0, 0
            local sBand = nil
            for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + bonus, true, BOT_MODE_NONE)) do
                local d = GetUnitToUnitDistance(bot, e)
                if d <= CAST_RANGE then
                    nIn = nIn + 1
                elseif d <= CAST_RANGE + eps then
                    nBand = nBand + 1
                    sBand = e:GetUnitName()
                    if d - CAST_RANGE > nWorst then
                        nWorst, fWorst, sWorst = d - CAST_RANGE, path, e:GetUnitName()
                    end
                end
            end
            local bTF = J.IsInTeamFight(bot, 1200) and true or false
            if bTF then nTeamFight = nTeamFight + 1 end
            if nBand > 0 then
                nBandFrames = nBandFrames + 1
                nBandEnemies = nBandEnemies + nBand
                if nIn == 0 then
                    nBandOnly = nBandOnly + 1
                    tBandOnly[#tBandOnly + 1] = { path = path, enemy = sBand }
                    if bTF then nBoth = nBoth + 1 end
                end
            end
        end
    end

    assert(nFiles >= 140, 'the corpus enumerator returned ' .. nFiles
        .. ' frames, expected >= 140 -- an empty ls and an empty corpus are the '
        .. 'same integer')
    assert(nLive == 51, 'Wraith King is alive on ' .. nLive
        .. ' corpus frames, was 51 -- re-take §0.3 rather than quoting it')
    assert(nBandFrames == 6 and nBandEnemies == 6, 'the band domain moved: '
        .. nBandFrames .. ' frames / ' .. nBandEnemies .. ' enemies, was 6 / 6')
    assert(nBandOnly == 2, 'the band-ONLY domain moved: ' .. nBandOnly
        .. ' frames, was 2.  Those are the only frames on which any narrowing of '
        .. 'this list could turn a cast into a no-cast, so §4 is driven on them.')
    assert(nTeamFight == 2, 'J.IsInTeamFight( bot, 1200 ) is now true on '
        .. nTeamFight .. ' live-WK frames, was 2.  ⚠️ NOT 0 -- backlog -197 read '
        .. 'it as 0 off a tests/fixtures-only enumerator; both live frames are '
        .. 'staged in ' .. STAGED_DIR .. '.')
    assert(nBoth == 0, 'a frame now has BOTH a band-only enemy and a true '
        .. 'teamfight predicate (' .. nBoth .. ').  That is the witness frame '
        .. 'leg 3 says the archive does not hold -- the DO-NOT-ARM loses a leg '
        .. 'and the candidate is re-priceable.')

    -- The realised overextension, which is what leg 1 quotes -- not the 43 the
    -- constant permits.
    assert(nWorst > 20 and nWorst < 25, 'the worst realised overextension is now '
        .. string.format('%.1f', nWorst) .. 'u (' .. tostring(sWorst) .. ' on '
        .. tostring(fWorst) .. '), was 22.5u.  §0.1 quotes that number.')

    -- And the two band-only frames are still the two §4 drives.
    assert(#tBandOnly == #BAND_ONLY, 'band-only frame count disagrees with the '
        .. 'named list in BAND_ONLY')
    for i, got in ipairs(tBandOnly) do
        assert(got.path == BAND_ONLY[i].path and got.enemy == BAND_ONLY[i].enemy,
            'band-only frame ' .. i .. ' is now ' .. got.path .. ' / ' .. got.enemy
            .. ', was ' .. BAND_ONLY[i].path .. ' / ' .. BAND_ONLY[i].enemy
            .. ' -- §4 drives the named frames, so it would be driving something else')
    end
end

-- ---------------------------------------------------------------- section 4 --
-- Leg 2, driven end to end through the real dispatch.  This is the section the
-- verdict actually rests on: the out-of-range cast is REAL, and it is NOT the
-- teamfight leg's.

tests['§4.1 both band-only frames really do blast the out-of-range enemy'] = function()
    for _, f in ipairs(BAND_ONLY) do
        local log, J, bot = drive(f.path)
        local got = blasted(log)
        assert(got == f.enemy, f.path .. ': the shipped dispatch blasted '
            .. tostring(got) .. ', expected ' .. f.enemy .. '.  §0 reads this '
            .. 'frame as a live out-of-range cast; if it is not one any more, '
            .. 'the whole pricing is stale.')
        local d
        for _, e in ipairs(bot:GetNearbyHeroes(CAST_RANGE + 330, true, BOT_MODE_NONE)) do
            if e:GetUnitName() == f.enemy then d = GetUnitToUnitDistance(bot, e) end
        end
        assert(d and d > CAST_RANGE, f.path .. ': ' .. f.enemy .. ' is at '
            .. tostring(d) .. 'u, which is not outside the ' .. CAST_RANGE
            .. 'u cast range -- the cast would not be an overextension at all')
        assert(math.abs(d - f.dist) < 0.2, f.path .. ': ' .. f.enemy .. ' moved to '
            .. string.format('%.1f', d) .. 'u, was ' .. f.dist)
    end
end

tests['§4.2 the cast is the CATCH-ALL\'s, and the teamfight leg is dark on both'] = function()
    for _, f in ipairs(BAND_ONLY) do
        local _, J, bot = drive(f.path)
        assert(J.IsInTeamFight(bot, 1200) == false, f.path
            .. ': the teamfight predicate is now TRUE here, so the cast in §4.1 '
            .. 'may be the teamfight leg\'s after all and leg 2 must be re-driven')

        -- X.wk_IsCatchAllOddsOk is consulted at the catch-all branch and nowhere
        -- else, so shutting it attributes the cast by IDENTITY, not by counting.
        local shut = blasted((drive(f.path, function() return false end)))
        assert(shut == nil, f.path .. ': with the catch-all\'s own conjunct shut '
            .. 'the dispatch still blasted ' .. tostring(shut) .. '.  Then the '
            .. 'cast is NOT the catch-all\'s and §0.2\'s attribution is wrong.')
    end
end

tests['§4.3 the three injections were really read'] = function()
    -- A reading taken through an injection that did not take is a reading about
    -- the harness.  Drive once and assert the function saw the injected values.
    local f = BAND_ONLY[1]
    local _, _, bot, _, hQ = drive(f.path)
    assert(hQ:GetCastRange() == CAST_RANGE, 'the GetCastRange injection did not '
        .. 'take (got ' .. tostring(hQ:GetCastRange()) .. ') -- at 0 both rings '
        .. 'collapse and every reading in this file is about tests/mock')
    assert(hQ:GetCooldownTimeRemaining() == 0 and hQ:IsFullyCastable() == true,
        'the castability injections did not take -- X.ConsiderQ returns on its '
        .. 'first line and §4 proves nothing about any firing point')
    -- ...and the hero level, which the catch-all's own `nLV >= 7` conjunct needs,
    -- is REAL on this frame.  If it ever needed injecting too, limit 1 is wrong.
    assert(bot:GetLevel() >= 7, 'the band-only frame now carries a WK below hero '
        .. 'level 7 (' .. tostring(bot:GetLevel()) .. '), so the catch-all\'s own '
        .. 'nLV conjunct is false and §4.2 is attributing to a branch that cannot '
        .. 'have fired')
end

-- ---------------------------------------------------------------- section 5 --
-- The retirement guard.  Nothing was landed; a later round must not be able to
-- read this file as having fixed the thing it priced.

tests['§5 no gate was landed on the teamfight leg, and none is claimed'] = function()
    local body = consider_q_body(read_file(SRC))
    -- Guarded, because an UNguarded body:sub(nil, ...) raises "bad argument #1
    -- to 'sub'" -- red, but with a message the reader cannot act on, which the
    -- mutation stand scores the same as survived.  Measured: this is what §5
    -- did under the stand's M7 before this guard.
    local from = body:find('if%s+J%.IsInTeamFight%(%s*bot%s*,%s*1200%s*%)')
    assert(from, 'the teamfight firing point no longer gates on '
        .. 'J.IsInTeamFight( bot, 1200 ), so §5 cannot locate the leg it guards')
    local to = body:find('return%s+BOT_ACTION_DESIRE_HIGH%s*,%s*npcMostDangerousEnemy', from)
    assert(to, 'the teamfight firing point no longer returns npcMostDangerousEnemy, '
        .. 'so §5 cannot locate the leg it guards')
    local leg = body:sub(from, to)
    assert(not leg:find('IsSoakCandidate'), 'a soak candidate now sits on the '
        .. 'teamfight firing point.  This file says DO-NOT-ARM and is the '
        .. 'record of that verdict; landing one means overturning it in the '
        .. 'same change, not alongside it.')

    -- And the other unbounded point this file deliberately does not touch is
    -- still unbounded, so §0.5 limit 3 stays true.
    local iInterrupt = body:find('if%s+npcEnemy:IsChanneling%(%s*%)')
    assert(iInterrupt, 'the channel-interrupt firing point is gone')
    local sInterrupt = body:sub(iInterrupt, body:find('return%s+BOT_ACTION_DESIRE_HIGH', iInterrupt))
    assert(not sInterrupt:find('IsInRange') and not sInterrupt:find('GetUnitToUnitDistance'),
        'the channel interrupt now bounds distance -- §0.5 limit 3 says this '
        .. 'file left it alone, and that sentence has gone false')
end

return tests

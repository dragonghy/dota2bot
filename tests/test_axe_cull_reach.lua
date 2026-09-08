-- [hero] `axecullreach` on THREE REAL FRAMES.  Written 2026-09-08 under
-- OWNER_PRIORITIES P4.4 (i), from the hero charter's backlog item `-123`
-- ("continue finding a focus hero's bots/ behaviour change").
--
-- WHAT THE LEVER IS
-- -----------------
-- bots/BotLib/hero_axe.lua X.ConsiderR builds two enemy lists and reads the
-- WIDER one in its only firing loop, with no distance term in the loop body:
--
--     local nInRangeEnemyList = J.GetAroundEnemyHeroList( nCastRange )        -- 175
--     local nInBonusEnemyList = J.GetAroundEnemyHeroList( nCastRange + 200 )  -- 375
--
-- The first was DEAD -- computed every frame, never read -- until this lever,
-- which is the tell.  `axecullreach` swaps the pool to the in-range list, so
-- Culling Blade is only ordered at a target the ability can actually reach.
--
-- THE THREE FRAMES, AND WHY THESE THREE
-- -------------------------------------
--   * FRAME_RING -- tests/frames/f_260828_002127_axe_call_bkb_ring.lua, t=982.1.
--     The value column.  Shadow Shaman at 276.9u with 228 hp against a rank-2
--     threshold of 350, i.e. 101.9u OUT of Culling's reach; and ALL THREE living
--     enemies (75.1 / 165.3 / 276.9) stand inside Berserker's Call's 315 radius
--     with Call rank 3, cooldown 0 and 319 mana against a 110 cost.  The shipped
--     tree spends this frame ordering a Culling Blade it cannot reach, and
--     because the R arm of X.SkillsComplement returns unconditionally, never
--     asks about the Call.
--   * FRAME_CLOSE -- tests/fixtures/f_260820_043637_axe_ring_close.lua, t=393.4.
--     The thin edge: Skywrath Mage at 188.0u with 221 hp against a rank-1
--     threshold of 250 -- 13.0u out of reach.  Same flip, one order of magnitude
--     less margin, so a rounding-shaped mistake in the lever shows up here.
--   * FRAME_PROMISE -- tests/frames/f_260828_124358_axe_cull_promise.lua,
--     t=1452.8.  The NEGATIVE control: Oracle at 153.7u, INSIDE the 175 reach.
--     Arming must not move this frame, and section 4 asserts it does not.
--
-- Every distance, health, level, cooldown and mana figure above is READ OFF THE
-- FRAME by section 1 rather than retyped from a report.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANYTHING FROM HERE
-- -------------------------------------------------------
--   * TWO OF THE THREE FRAMES ARE STAGED, NOT ADMITTED.  FRAME_RING and
--     FRAME_PROMISE live in tests/frames/ and are loaded BY NAME; their
--     admission price to tests/fixtures/ is not measured here and no number is
--     claimed for it.  See tests/frames/README.md.  FRAME_CLOSE is a corpus
--     fixture.
--   * THE "CALL WOULD FIRE INSTEAD" HALF IS NOT DRIVEN BY THESE FRAMES, and
--     section 9 asserts that rather than hiding it.  X.ConsiderQ's branches are
--     all behind mode predicates (J.IsGoingOnSomeone / J.IsPushing /
--     J.IsFarming) that the fixture world answers false for, so X.ConsiderQ
--     answers 0 on all three frames whatever this gate does.  What IS machine
--     checked is the DOMINANCE that makes the question matter: section 7 reads
--     X.SkillsComplement and asserts the R arm returns before the Q arm is
--     reached.  That is a source-level fact, and it is labelled as one.
--   * HEALTH REGEN IS STRUCTURALLY 0 IN THIS CORPUS (section 9), so the loop's
--     `GetHealthRegen() * 0.8` term is dead offline.  Nothing here reads that
--     term as evidence, and nobody should price the 0.8s budget off this file.
--   * THE HERO-LEVEL EFFECT IS NOT A PURE NARROWING.  Inside X.ConsiderR the
--     armed pool is a strict subset (section 5) so the lever can only delete a
--     Culling order.  But a declined frame then falls through to X.ConsiderQ and
--     X.ConsiderW, which may fire.  "Armed Axe casts fewer spells" is therefore
--     NOT a prediction of this lever, and a wave reading it that way is reading
--     the wrong quantity.
--
-- HOW THE TWO STAGED FRAMES WERE CUT (reproduction, not run by this file)
-- ----------------------------------------------------------------------
--   bash tools/batch_test/aws/session_setup.sh
--   BIN=$(bash tools/batch_test/behavioral/get_dumper.sh)
--   # both already exist; these are the commands that produced them, quoted from
--   # tests/test_axe_call_staged_frames.lua and tests/test_axe_cull_promise_premise.lua
--   python3 tools/batch_test/replayscope/make_fixture.py t.json \
--       --t 982.1  --hero axe -o tests/frames/f_260828_002127_axe_call_bkb_ring.lua
--   python3 tools/batch_test/replayscope/make_fixture.py t.json \
--       --t 1452.8 --hero axe -o tests/frames/f_260828_124358_axe_cull_promise.lua
--
-- Run: lua5.1 tests/run_tests.lua axe_cull_reach

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local SRC = 'bots/BotLib/hero_axe.lua'
local CAND = 'axecullreach'
local HELPER = 'CullTargetPool'
local GATE = 'IsCullReachOn'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR = 'tests/frames'

local FRAME_RING = STAGED_DIR .. '/f_260828_002127_axe_call_bkb_ring.lua'
local FRAME_CLOSE = FIXTURE_DIR .. '/f_260820_043637_axe_ring_close.lua'
local FRAME_PROMISE = STAGED_DIR .. '/f_260828_124358_axe_cull_promise.lua'

local AXE = 'npc_dota_hero_axe'
local CULLING = 'axe_culling_blade'
local CALL = 'axe_berserkers_call'
local BONUS = 200

local SHAMAN = 'npc_dota_hero_shadow_shaman'
local SKYWRATH = 'npc_dota_hero_skywrath_mage'
local ORACLE = 'npc_dota_hero_oracle'

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Every .lua frame in the two corpus directories.  Both directory names are
--- literals in this file; nothing here enumerates bots/.
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for line in p:lines() do
            if line:match('%.lua$') then out[#out + 1] = dir .. '/' .. line end
        end
        p:close()
    end
    table.sort(out)
    return out
end

local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

--- Load a frame, arm or disarm THIS lever's id only, and drive the real
--- X.ConsiderR.  `armed` is a boolean because this lever has exactly one id;
--- the moment it grows a second, this helper has to become a list (the shape
--- tests/test_axe_call_staged_frames.lua uses) rather than a flag.
local function drive(path, armed)
    local J, bot, heroes, fx = rf.load(path)
    -- `== true`, not a bare lookup: an absent key answers nil, and a helper
    -- asserted `== false` would then pass on a nil that behaves identically.
    J.IsSoakCandidate = function(id) return (armed == true) and id == CAND end
    local X = rf.load_hero('axe')
    local d, hTarget, sMotive = X.ConsiderR()
    return d, hTarget, sMotive, J, bot, heroes, fx, X
end

--- The body of X.ConsiderR, so the source ratchets cannot be satisfied by a
--- matching string elsewhere in a 1400-line file.
local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

local function unit_named(fx, sName)
    for _, u in ipairs(fx.units) do
        if u.name == sName then return u end
    end
    return nil
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth, all of it read off the frames.  If a frame is ever recut these
-- go red and name the number that moved, instead of the sections below quietly
-- measuring a different world.

tests['\194\1671 FRAME_RING: reach is 175, and the target the shipped loop takes is 101.9u outside it'] = function()
    local _, _, _, _, bot, _, fx = drive(FRAME_RING, false)
    local abilityR = bot:GetAbilityByName(CULLING)
    local abilityQ = bot:GetAbilityByName(CALL)
    assert(abilityR:GetCastRange() == 175,
        'Culling Blade cast range reads ' .. tostring(abilityR:GetCastRange())
        .. ' on this frame, not 175 -- every distance claim in this file is '
        .. 'relative to that number')
    assert(abilityR:GetLevel() == 2, 'Culling rank moved, got ' .. tostring(abilityR:GetLevel()))
    assert(abilityR:IsFullyCastable(), 'Culling is no longer castable on FRAME_RING')

    local me, shaman = unit_named(fx, AXE), unit_named(fx, SHAMAN)
    assert(me and shaman, 'FRAME_RING no longer carries both Axe and Shadow Shaman')
    local d = dist2d(shaman, me)
    assert(math.abs(d - 276.9) < 0.5, 'Shadow Shaman is at ' .. string.format('%.1f', d)
        .. 'u, was 276.9u')
    assert(d > 175 and d <= 175 + BONUS, 'Shadow Shaman is no longer in the (175, 375] band')
    -- 150 + 100*lv is the shipped threshold; `cullthresh` may widen it, and this
    -- file never arms that id, so the shipped ladder is the one in force here.
    assert(shaman.hp == 228 and shaman.hp < 150 + 100 * 2,
        'Shadow Shaman hp is ' .. tostring(shaman.hp) .. ', was 228 and below the rank-2 threshold 350')

    -- The suppressed question.  Call's radius covers the whole band on this frame.
    assert(abilityQ:GetSpecialValueInt('radius') == 315,
        'Berserker Call radius reads ' .. tostring(abilityQ:GetSpecialValueInt('radius')) .. ', was 315')
    assert(abilityQ:IsFullyCastable(),
        'Berserker Call is not castable on FRAME_RING -- the "the bot never even asks" '
        .. 'argument in this lever\'s header is priced off it being ready')
    local nInCall = 0
    for _, u in ipairs(fx.units) do
        if u.name:match('^npc_dota_hero_') and u.team ~= me.team and u.alive
            and dist2d(u, me) <= 315 then
            nInCall = nInCall + 1
        end
    end
    assert(nInCall == 3, 'FRAME_RING now has ' .. nInCall
        .. ' living enemies inside the Call radius, was 3')
end

tests['\194\1671 FRAME_CLOSE / FRAME_PROMISE: the thin edge (13.0u out) and the in-reach control'] = function()
    local _, _, _, _, botC, _, fxC = drive(FRAME_CLOSE, false)
    assert(botC:GetAbilityByName(CULLING):GetCastRange() == 175, 'FRAME_CLOSE reach moved')
    local dC = dist2d(unit_named(fxC, SKYWRATH), unit_named(fxC, AXE))
    assert(math.abs(dC - 188.0) < 0.5, 'Skywrath is at ' .. string.format('%.1f', dC) .. 'u, was 188.0u')
    assert(dC > 175, 'Skywrath is no longer OUTSIDE the 175 reach -- FRAME_CLOSE was the thin edge')
    assert(unit_named(fxC, SKYWRATH).hp == 221, 'Skywrath hp moved')

    local _, _, _, _, botP, _, fxP = drive(FRAME_PROMISE, false)
    assert(botP:GetAbilityByName(CULLING):GetCastRange() == 175, 'FRAME_PROMISE reach moved')
    local dP = dist2d(unit_named(fxP, ORACLE), unit_named(fxP, AXE))
    assert(math.abs(dP - 153.7) < 0.5, 'Oracle is at ' .. string.format('%.1f', dP) .. 'u, was 153.7u')
    assert(dP <= 175, 'Oracle is no longer INSIDE the reach -- the negative control in '
        .. 'section 4 has stopped being a control')
end

-- ---------------------------------------------------------------- section 2 --
-- The shipped tree, driven.  This is the defect, not a description of it.

tests['\194\1672 SHIPPED: the unarmed loop orders Culling at a target it cannot reach (both frames)'] = function()
    local dR, hR = drive(FRAME_RING, false)
    assert(dR > 0, 'unarmed FRAME_RING no longer fires Culling, got desire ' .. tostring(dR))
    assert(hR ~= nil and hR:GetUnitName() == SHAMAN,
        'unarmed FRAME_RING targets ' .. tostring(hR and hR:GetUnitName())
        .. ', was ' .. SHAMAN)

    local dC, hC = drive(FRAME_CLOSE, false)
    assert(dC > 0, 'unarmed FRAME_CLOSE no longer fires Culling, got desire ' .. tostring(dC))
    assert(hC ~= nil and hC:GetUnitName() == SKYWRATH,
        'unarmed FRAME_CLOSE targets ' .. tostring(hC and hC:GetUnitName()) .. ', was ' .. SKYWRATH)
end

-- ---------------------------------------------------------------- section 3 --
-- The fix, driven on the same two frames.

tests['\194\1673 ARMED: both out-of-reach orders are gone'] = function()
    local dR, hR = drive(FRAME_RING, true)
    assert(dR == BOT_ACTION_DESIRE_NONE, 'armed FRAME_RING still bids ' .. tostring(dR))
    assert(hR == nil, 'armed FRAME_RING still names a target: ' .. tostring(hR and hR:GetUnitName()))

    local dC, hC = drive(FRAME_CLOSE, true)
    assert(dC == BOT_ACTION_DESIRE_NONE, 'armed FRAME_CLOSE still bids ' .. tostring(dC))
    assert(hC == nil, 'armed FRAME_CLOSE still names a target: ' .. tostring(hC and hC:GetUnitName()))
end

tests['\194\1673 ARMED: the two in-reach enemies on FRAME_RING are not what stops the cast'] = function()
    -- Lina (75.1u) and Necrolyte (165.3u) ARE in the armed pool.  The armed leg
    -- returns NONE because neither is below the threshold, not because the pool
    -- came back empty -- an empty pool would make section 3 pass for the wrong
    -- reason, and the day a frame is recut that difference is the whole story.
    local _, _, _, J, bot, _, fx = drive(FRAME_RING, true)
    local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange())
    assert(#pool == 2, 'the armed pool holds ' .. #pool .. ' enemies on FRAME_RING, was 2')
    local me = unit_named(fx, AXE)
    for _, u in ipairs(pool) do
        local row = unit_named(fx, u:GetUnitName())
        assert(row.hp >= 150 + 100 * 2, u:GetUnitName() .. ' is in the armed pool at '
            .. tostring(row.hp) .. ' hp, BELOW the rank-2 threshold 350 -- armed FRAME_RING '
            .. 'should then have fired, so section 3 is measuring something else')
        assert(dist2d(row, me) <= 175, u:GetUnitName() .. ' is in the in-range pool but '
            .. 'further than the cast range')
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The negative control.  A lever that moved this frame would be narrowing the
-- wrong thing.

tests['\194\1674 CONTROL: FRAME_PROMISE (Oracle at 153.7u, in reach) is byte-identical armed and not'] = function()
    local dOff, hOff, mOff = drive(FRAME_PROMISE, false)
    local dOn, hOn, mOn = drive(FRAME_PROMISE, true)
    assert(dOff > 0, 'the unarmed control no longer fires; it is not a control any more')
    assert(dOn == dOff, 'arming moved the in-reach control: ' .. tostring(dOff)
        .. ' -> ' .. tostring(dOn))
    assert(hOn ~= nil and hOff ~= nil and hOn:GetUnitName() == hOff:GetUnitName(),
        'arming changed the control\'s target')
    assert(hOn:GetUnitName() == ORACLE, 'the control targets ' .. hOn:GetUnitName() .. ', was ' .. ORACLE)
    assert(mOn == mOff, 'arming changed the control\'s motive string')
end

-- ---------------------------------------------------------------- section 5 --
-- DIRECTION, as a property of the code rather than of these three frames: the
-- armed pool is built by the SAME helper with a SMALLER radius, so it is a
-- subset on every frame the corpus holds.  Inside X.ConsiderR the lever can
-- therefore only ever delete a Culling order.

tests['\194\1675 DIRECTION: armed pool is a subset of the shipped pool on every Axe frame in the corpus'] = function()
    local nAxeFrames, nStrict = 0, 0
    for _, path in ipairs(corpus_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' and unit_named(fx, AXE) then
            nAxeFrames = nAxeFrames + 1
            local _, _, _, J, bot = drive(path, false)
            local abilityR = bot:GetAbilityByName(CULLING)
            local cr = abilityR:GetCastRange()
            local tight = J.GetAroundEnemyHeroList(cr)
            local wide = J.GetAroundEnemyHeroList(cr + BONUS)
            local seen = {}
            for _, u in ipairs(wide) do seen[u:GetUnitName()] = true end
            for _, u in ipairs(tight) do
                assert(seen[u:GetUnitName()], path .. ': ' .. u:GetUnitName()
                    .. ' is in the armed pool but NOT in the shipped one -- the lever '
                    .. 'is not a narrowing on this frame')
            end
            if #tight < #wide then nStrict = nStrict + 1 end
        end
    end
    assert(nAxeFrames >= 30, 'only ' .. nAxeFrames .. ' corpus frames carry an Axe; '
        .. 'this round scanned 33 (28 fixtures + 5 staged).  Fixtures were removed, '
        .. 'or the loader changed')
    assert(nStrict >= 4, 'the armed pool is strictly smaller on only ' .. nStrict
        .. ' Axe frames; this round measured 4 (blink_flee_529, ring_close, '
        .. 'call_bkb_ring, call_tp_channel).  Below this the corpus distinguishes the '
        .. 'two pools on fewer frames than the reading was taken on')
end

-- ---------------------------------------------------------------- section 6 --
-- THE RELOCATION CHECK (the `lionrreach` lesson, GH #617): a target the armed
-- pool rejects must not be caught by some later branch of the same function
-- carrying a now-true kill claim.  X.ConsiderR has exactly ONE firing branch.

tests['\194\1676 NO DOWNSTREAM CATCHER: X.ConsiderR still has exactly one firing branch'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderR')
    local nFire = 0
    for _ in body:gmatch('return%s+BOT_ACTION_DESIRE_HIGH') do nFire = nFire + 1 end
    assert(nFire == 1, 'X.ConsiderR now has ' .. nFire .. ' firing branches, was 1.  '
        .. 'A second one can CATCH the targets this lever rejects -- that is the '
        .. '`lionrreach` relocation trap, and this reading has to be redone before '
        .. 'the lever can still be called a narrowing')
    assert(body:find('return%s+BOT_ACTION_DESIRE_NONE'),
        'X.ConsiderR no longer falls through to NONE')
end

-- ---------------------------------------------------------------- section 7 --
-- WHY THE BAND COSTS SOMETHING: dominance.  Source-level, and labelled as such
-- -- the fixture world cannot drive it (section 9).

tests['\194\1677 DOMINANCE: the R arm of X.SkillsComplement returns before Q and W are asked'] = function()
    local body = fn_body(read_file(SRC), 'SkillsComplement')
    local atR = body:find('X%.ConsiderR%s*%(')
    local atQ = body:find('X%.ConsiderQ%s*%(')
    local atW = body:find('X%.ConsiderW%s*%(')
    assert(atR and atQ and atW, 'X.SkillsComplement no longer calls all three Considers')
    assert(atR < atQ and atQ < atW, 'the arms are no longer ordered R, Q, W -- the '
        .. 'dominance argument in this lever\'s header is priced off R being first')
    -- The `return` between the R arm and the Q arm is the whole mechanism.
    local seg = body:sub(atR, atQ)
    assert(seg:find('\n%s*return%s*\n') or seg:find('\n%s*return%s*$'),
        'the R arm no longer returns unconditionally before the Q arm.  If that is '
        .. 'deliberate, this lever\'s "Berserker\'s Call is never even asked" claim '
        .. 'is retired -- do not weaken this assert to keep the sentence')
end

-- ---------------------------------------------------------------- section 8 --
-- The `pullcad` guard, and the wiring.

tests['\194\1678 ONE ID: the gate helper names exactly this id and no sibling'] = function()
    local src = read_file(SRC)
    local body = fn_body(src, GATE)
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'%s*%)") do ids[#ids + 1] = id end
    assert(#ids == 1, 'X.' .. GATE .. ' now names ' .. #ids .. ' soak ids, was 1.  A gate '
        .. 'naming a sibling freezes FALSE the day that sibling is promoted (the '
        .. '`pullcad` trap) and check_armed_wiring.py still calls it WIRED')
    assert(ids[1] == CAND, 'X.' .. GATE .. ' names ' .. ids[1] .. ', not ' .. CAND)
    assert(body:find('J%.IsModeTurbo%(%s*%)'), 'X.' .. GATE .. ' is no longer turbo-only')
end

tests['\194\1678 WIRED: X.ConsiderR routes its pool through the helper, exactly once'] = function()
    local body = fn_body(read_file(SRC), 'ConsiderR')
    local n = 0
    for _ in body:gmatch('X%.' .. HELPER .. '%s*%(') do n = n + 1 end
    assert(n == 1, 'X.' .. HELPER .. ' has ' .. n .. ' call sites in X.ConsiderR, was 1.  '
        .. 'Zero means the lever is wired to nothing and every reading above is '
        .. 'vacuous; two means a second pool with a different domain, which is a '
        .. 'different id')
    -- The dead local this lever consumed.  If a later edit re-orphans it, the
    -- lever has silently stopped being reachable and this says so.
    assert(body:find('nInRangeEnemyList'), 'nInRangeEnemyList is gone from X.ConsiderR')
    local at = body:find('X%.' .. HELPER .. '%s*%(%s*nInRangeEnemyList%s*,%s*nInBonusEnemyList%s*%)')
    assert(at, 'the pool call no longer passes (nInRangeEnemyList, nInBonusEnemyList) in '
        .. 'that order -- swapped arguments would INVERT this lever and every section '
        .. 'above would still pass on the frames that happen to be symmetric')

    -- The two radii, pinned where they are BUILT.  Section 5 recomputes the pools
    -- from GetCastRange() itself, so it is blind to a change in these two lines --
    -- widening the armed list here left section 5 green (the stand's M9), and the
    -- only red was section 3 saying the flip stopped happening, which does not
    -- name the cause.  This is the assertion that names it.
    assert(body:find('nInRangeEnemyList = J%.GetAroundEnemyHeroList%( nCastRange %)'),
        'the armed pool is no longer built on the bare nCastRange.  Any term added '
        .. 'here can make this lever WIDEN instead of narrow, which is the one '
        .. 'direction its header promises is impossible')
    assert(body:find('nInBonusEnemyList = J%.GetAroundEnemyHeroList%( nCastRange %+ 200 %)'),
        'the shipped pool is no longer nCastRange + 200 -- the gate-off tree just '
        .. 'moved, and every "byte for byte" claim about it has to be re-read')
end

-- ---------------------------------------------------------------- section 9 --
-- The two limits this file refuses to hide.  Both are asserted, so the day the
-- corpus grows the ability to answer them, this section goes red and says so.

tests['\194\1679 LIMIT: X.ConsiderQ answers 0 on all three frames, armed or not'] = function()
    for _, path in ipairs({ FRAME_RING, FRAME_CLOSE, FRAME_PROMISE }) do
        for _, armed in ipairs({ false, true }) do
            local J, bot, _, _ = rf.load(path)
            J.IsSoakCandidate = function(id) return (armed == true) and id == CAND end
            local X = rf.load_hero('axe')
            local dq = X.ConsiderQ()
            assert(dq == 0, path .. ' (armed=' .. tostring(armed) .. '): X.ConsiderQ now '
                .. 'answers ' .. tostring(dq) .. '.  GOOD -- the fixture world has grown '
                .. 'the mode state this file says it lacks.  Retire this limit and drive '
                .. 'the "Call fires instead" half for real; do not delete the assert to '
                .. 'keep the file green')
            assert(bot ~= nil)
        end
    end
end

tests['\194\1679 LIMIT: health regen is 0 across the corpus, so the 0.8s budget is dead offline'] = function()
    local nRows, nNonZero = 0, 0
    for _, path in ipairs(corpus_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' and unit_named(fx, AXE) then
            local _, _, _, J = drive(path, false)
            for _, u in ipairs(J.GetAroundEnemyHeroList(375)) do
                nRows = nRows + 1
                if (u:GetHealthRegen() or 0) ~= 0 then nNonZero = nNonZero + 1 end
            end
        end
    end
    assert(nRows > 0, 'no enemy rows at all in the Axe corpus ring -- section 5 would be '
        .. 'vacuous too')
    assert(nNonZero == 0, nNonZero .. ' of ' .. nRows .. ' enemy rows now carry a non-zero '
        .. 'GetHealthRegen.  GOOD -- the corpus can price the loop\'s `* 0.8` term now. '
        .. 'Retire this limit rather than the assert')
end

-- --------------------------------------------------------------- section 10 --
-- The domain, on real frames.  A tripwire on a LOWER bound, so adding fixtures
-- can only strengthen it.

tests['\194\16710 DOMAIN: the corpus holds at least 2 band frames and 1 in-reach control'] = function()
    local nBand, nInReach = 0, 0
    for _, path in ipairs(corpus_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            local me = unit_named(fx, AXE)
            if me and me.alive then
                local _, _, _, _, bot = drive(path, false)
                local abilityR = bot:GetAbilityByName(CULLING)
                if abilityR:IsFullyCastable() then
                    local thr = 150 + 100 * abilityR:GetLevel()
                    local cr = abilityR:GetCastRange()
                    local band, inreach = false, false
                    for _, u in ipairs(fx.units) do
                        if u.name:match('^npc_dota_hero_') and u.team ~= me.team and u.alive
                            and u.hp < thr then
                            local d = dist2d(u, me)
                            if d <= cr then inreach = true
                            elseif d <= cr + BONUS then band = true end
                        end
                    end
                    if band then nBand = nBand + 1 end
                    if inreach then nInReach = nInReach + 1 end
                end
            end
        end
    end
    assert(nBand >= 2, 'only ' .. nBand .. ' corpus frames put a sub-threshold enemy in '
        .. 'the (cast range, cast range + 200] band; this round found 2 and both are '
        .. 'driven above.  Below 2 the flip is a single anecdote')
    assert(nInReach >= 1, 'only ' .. nInReach .. ' corpus frames put a sub-threshold enemy '
        .. 'INSIDE the cast range; without one there is no negative control and section 4 '
        .. 'is measuring nothing')
end

return tests

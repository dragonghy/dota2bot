-- [chasering 20260913] THE ANTI-SUICIDE-CHASE GUARD'S ESCAPE HATCH NOW HAS TO
-- BE ABOUT THE FIGHT THE BOT IS STANDING IN.
--
-- ⭐ WHAT LANDED, IN ONE LINE: inside J.ShouldNotChaseWhenLow, the "the kill is
-- secured WITHOUT me tanking" exemption is evaluated only when the caller's
-- target is one of the enemies already punishing the bot (identity membership in
-- the `tEnemies` ring the function ALREADY computed for its burst test).
-- Off-ring, the exemption is skipped. One conjunct, one indent level, NO NEW
-- SOAK ID.
--
-- ⭐ THE DEFECT, IN THE FUNCTION'S OWN ANCHORING. Every other line of the guard
-- is anchored on the BOT: `bot:GetHealth() / bot:GetMaxHealth() >= 0.40`, and
-- `tEnemies = J.GetEnemiesNearLoc( bot:GetLocation(), 1200 )` whose combined
-- burst must reach 45% of the bot's CURRENT health. The exemption alone is
-- anchored on `target` -- `J.GetAlliesNearLoc( target:GetLocation(), 1200 )` --
-- and `target`'s only filter anywhere in the function is the
-- `J.IsValidHero( target )` on the first line. Nothing ties it to the ring the
-- burst was summed over.
--
-- ⭐ AND THE CALLER CAN SUPPLY ONE. The shipped call site is
-- bots/mode_retreat_generic.lua's retreat desire, which passes
-- `botTarget = J.GetProperTarget( bot )`: `bot:GetTarget()` (the current ORDER
-- target) falling back to `bot:GetAttackTarget()`, filtered only by "not one of
-- our own heroes/buildings", with no distance call of any kind. §1 asserts that
-- absence against the source rather than describing it, so the day somebody
-- leashes that helper this file goes red instead of quietly overstating the
-- domain. Same third argument, same shape, as the 'divepocket' repair earlier
-- today -- these two guards sit eight lines apart in mode_retreat_generic and
-- take the SAME unbounded handle.
--
-- ⭐ (乙) SITE CENSUS BY THE TREE, NOT BY THE HOST. Three call sites:
--   * bots/mode_retreat_generic.lua  -- J.GetProperTarget( bot ), UNBOUNDED;
--   * bots/BotLib/hero_phantom_assassin.lua -- the blink-strike target, already
--     inside `J.IsInRange( npcTarget, bot, nCastRange + 50 )`, so in-ring by
--     construction unless it is an illusion/clone (which `tEnemies` filters and
--     `J.IsValidHero` does not -- there the narrowing FIRES, correctly);
--   * bots/BotLib/hero_spirit_breaker.lua -- the charge target, and Charge of
--     Darkness is global, so unbounded again.
-- One of three sites is bounded. §1 pins all three.
--
-- ⭐ ONE-DIRECTIONAL BY CONSTRUCTION (this is NOT the 'divepocket' shape). The
-- exemption is the only `return false` left at that point, so gating it can only
-- ADD `true` answers: the narrowed FALSE set is a subset of the shipped one.
-- §3 asserts the sign (`shrink_ba == 0`) instead of leaning on the prose.
--
-- ⭐⭐ THE ANSWER-LEVEL EFFECT IS ZERO ON THIS CORPUS BY CONSTRUCTION, NOT BY
-- SAMPLING -- and that is why this file counts the BRANCH. The mock's
-- GetEstimatedDamageToTarget answers ground truth only for damage dealt TO the
-- fixture subject (replay_fixture.lua:8), so an ALLY's burst on an enemy reads 0
-- and the shipped exemption never fires naturally anywhere in the corpus
-- (§5 pins that zero as the instrument limit it is). An answer-count assertion
-- here would therefore be true of a mutant that deletes the exemption outright:
-- that is this desk's (癸) lesson from 'divepocket' this morning, applied BEFORE
-- the mutation stand rather than after it. §3's load-bearing readings are
-- `exempt_off` (how many times the exemption was computed around a hero the bot
-- is not fighting) and `exempt_in`, taken by wrapping the one function the
-- exemption spends -- J.GetAlliesNearLoc.
--
-- ⭐⭐ WHAT THE CORPUS DOES BUY, and it is geometry, not damage:
--   * 23 (row, off-ring target) pairs reach the exemption. The nearest sits at
--     1,372.0u -- an ordinary order-target distance, not a map-width artefact --
--     and 3 of the 23 are inside 3,000u (§5's near-band control).
--   * 10 of those 23 have a NON-EMPTY ally set within 1200 of the far target,
--     i.e. the shipped exemption is not merely reachable off-ring, it has real
--     allies to score, around heroes up to 14,582u away from the bot.
-- ⚠️ NO SINGLE FRAME HAS BOTH the near band and a non-empty ally set: the three
-- near-band pairs all score 0 allies at the target. The counterfactual in §4 is
-- therefore taken at 6,486.8u and says so. Registering that seam is the point --
-- the cheap half of a corpus must not be allowed to stand in for the dear half
-- ((壬), earned this morning).
--
-- ⭐ NO NEW SOAK ID, ON PURPOSE -- criterion (甲′)'s THIRD state, the same call
-- as 'rescpost' and 'roshpost'. The host's FIRST line is a bare
-- `J.IsLaneFixOn( 'chase' )` early return, so the whole helper is already inert
-- in shipped play; a second candidate nested under an unarmed one is the pullcad
-- trap's cousin (no wave can isolate it, while check_armed_wiring.py still calls
-- it WIRED). §1 asserts the host gate is still there, because the day 'lf_chase'
-- is promoted this narrowing becomes a SHIPPED behaviour change and must be
-- re-priced rather than inherited.
--
-- ⚠️ CORPUS LIMITS, registered rather than worked around:
--   (i) the ally-burst instrument above. It makes flip_ab structurally 0; §3
--       records that reading and labels it NON-DISCRIMINATING.
--  (ii) subject rows only. The exemption is driven off ground-truth burst on the
--       fixture's own subject, so a row driven through rf.load(path, other)
--       reads 0 damage and never reaches the exemption at all. This file drives
--       the natural subject and §2 pins the resulting domain sizes.
-- (iii) the dumper carries no attack-target field (GH #786), so this corpus
--       cannot say how OFTEN a real bot:GetTarget() sits outside the ring --
--       only what happens when it does. No rate is claimed anywhere below.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'
local PA = 'bots/BotLib/hero_phantom_assassin.lua'
local SB = 'bots/BotLib/hero_spirit_breaker.lua'

-- The counterfactual frame (§4) and the nearest off-ring pair (§5).
local CF_FIX = 'tests/fixtures/f_231411_ck_zoned.lua'
local CF_TARGET = 'npc_dota_hero_obsidian_destroyer'
local NEAR_FIX = 'f_260909_215040_wk_blast_sb_1052.lua'
local NEAR_HERO = 'npc_dota_hero_lion'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction J.', at + 10) or #src
    return src:sub(at, stop)
end

local SRC = read_file(JMZ)
local HOST = block(SRC, 'function J.ShouldNotChaseWhenLow( bot, target )')
local PROPER = block(SRC, 'function J.GetProperTarget( bot )')

-- Parsed out of the shipped source, never typed here (the M13 lesson): move the
-- radius in jmz_func and this file moves with it. A failed parse reads as nil,
-- never as a zero (the GH #171 shape).
local RING_R = HOST
    and tonumber(HOST:match('GetEnemiesNearLoc%( bot:GetLocation%(%), (%d+) %)'))

-- ------------------------------------------------------------- §1 source ---

tests['[chasering] 1. the prose, the conjunct, the host gate and all three callers'] = function()
    assert(HOST ~= nil, 'J.ShouldNotChaseWhenLow is gone from ' .. JMZ)
    assert(PROPER ~= nil, 'J.GetProperTarget is gone from ' .. JMZ)

    -- (a) The sentence this repair is named after.
    assert(HOST:find('the kill is secured WITHOUT me tanking', 1, true) ~= nil,
        'the exemption comment no longer says "the kill is secured WITHOUT me '
        .. 'tanking". This file is built on that being the shipped intent -- '
        .. 're-read it before trusting any count below.')

    -- (b) The bot-anchored legs the exemption was the odd one out against. If
    --     these move, "every other line is anchored on the bot" stops being true
    --     and the defect statement has to be re-argued.
    assert(HOST:find('local tEnemies = J.GetEnemiesNearLoc( bot:GetLocation(), 1200 )',
        1, true) ~= nil,
        'the punish ring is no longer J.GetEnemiesNearLoc( bot:GetLocation(), '
        .. '1200 ). The narrowing tests membership in THAT list.')
    assert(HOST:find('local nBurst = J.GetTotalEstimatedDamageToTarget( tEnemies, bot )',
        1, true) ~= nil,
        'the burst leg no longer sums tEnemies onto the bot.')

    -- (c) The conjunct itself, and that it wraps the exemption rather than
    --     sitting beside it.
    assert(HOST:find('if J.IsExistInTable( target, tEnemies ) then', 1, true) ~= nil,
        'the ring-membership conjunct is gone from J.ShouldNotChaseWhenLow. '
        .. 'Without it the exemption is scored around any valid hero on the map '
        .. 'again.')
    assert(HOST:find('local tAllies = J.GetAlliesNearLoc( target:GetLocation(), 1200 )',
        1, true) ~= nil,
        'the exemption no longer reads allies around the target; §3 wraps that '
        .. 'call to count the branch, so the probe would be measuring nothing.')

    -- (d) ⭐ THE THIRD-STATE JUSTIFICATION, AS A RED-ABLE ASSERTION. The host is
    --     gated as a whole, which is WHY no new id was minted. The day
    --     'lf_chase' is promoted this line goes red and the placement must be
    --     re-priced instead of inherited.
    assert(HOST:find("if not J.IsLaneFixOn( 'chase' ) then return false end",
        1, true) ~= nil,
        'J.ShouldNotChaseWhenLow no longer opens with the bare '
        .. "J.IsLaneFixOn( 'chase' ) early return. The narrowing inside it was "
        .. 'landed WITHOUT its own soak id on exactly that basis (criterion '
        .. "甲′'s third state); if the host now ships, this is a live behaviour "
        .. 'change with no wave behind it.')
    assert(HOST:find('J.IsSoakCandidate(', 1, true) == nil,
        'J.ShouldNotChaseWhenLow now calls J.IsSoakCandidate directly. A second '
        .. 'candidate nested under an unarmed host is the pullcad trap\'s '
        .. 'cousin: no wave can isolate it while check_armed_wiring.py still '
        .. 'calls it WIRED.')

    -- (e) The three call sites, quoted rather than described ((乙)).
    local RETREAT_SRC = read_file(RETREAT)
    assert(RETREAT_SRC:find('J.ShouldNotChaseWhenLow(bot, botTarget)', 1, true) ~= nil,
        RETREAT .. ' no longer passes botTarget to J.ShouldNotChaseWhenLow. The '
        .. 'whole domain argument is about what that second argument can be.')
    assert(RETREAT_SRC:find('botTarget      = J.GetProperTarget(bot)', 1, true) ~= nil,
        RETREAT .. ' no longer sources botTarget from J.GetProperTarget.')
    assert(read_file(PA):find('J.ShouldNotChaseWhenLow( bot, npcTarget )', 1, true) ~= nil,
        PA .. ' no longer consults the chase guard; the site census in the '
        .. 'header is then stale.')
    assert(read_file(SB):find('J.ShouldNotChaseWhenLow(bot, target)', 1, true) ~= nil,
        SB .. ' no longer consults the chase guard; the site census in the '
        .. 'header is then stale.')

    -- (f) ⭐ THE CLAIM THAT MAKES THE DOMAIN REAL: J.GetProperTarget applies no
    --     distance bound. Not "we read it and it looked unbounded" -- the three
    --     distance calls the tree has are absent from its body.
    for _, fn in ipairs({ 'GetUnitToUnitDistance', 'GetUnitToLocationDistance',
        'GetLocationToLocationDistance' }) do
        assert(PROPER:find(fn, 1, true) == nil,
            'J.GetProperTarget now calls ' .. fn .. '. It may be leashed, and if '
            .. 'it is, the "the caller can hand us a target anywhere on the map" '
            .. 'premise of this file must be re-measured, not restated.')
    end

    assert(RING_R == 1200, 'could not parse the punish-ring radius out of the '
        .. 'host (got ' .. tostring(RING_R) .. '); refusing to hardcode it (the '
        .. 'M13 lesson).')
end

-- -------------------------------------------------------------- the sweep ---

--- ONE pass over the corpus: census + two arms per (row, enemy) pair.
---
--- ⚠️ BUDGET IS NOT MEMBERSHIP. This file is not registered in
--- tools/agent/lua_gate_manifest.json; the only sanctioned way in is a full
--- re-measure of every file, which rewrites the whole manifest and is not a
--- small work unit's business (GH #783). A red here does not block anybody's
--- push -- the GH #624 shape, registered rather than papered over.
local SWEEP, SWEEP_ERR = nil, nil
local MIN_OFF_D, MAX_IN_D, NEAR_SEEN = nil, nil, false

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

local function run_sweep()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) rawset(c, k, c[k] + 1) end
    -- Zero-initialised, so "never reached" and "measured zero" are never the
    -- same thing to a reader (the GH #171 shape).
    for _, k in ipairs({ 'frames', 'load_fail', 'raised', 'low_hp', 'reach_rows',
        'in_p', 'off_p', 'near_off', 'off_with_allies', 'in_with_allies',
        'fire_a', 'fire_b', 'flip_ab', 'shrink_ba',
        'exempt_in_a', 'exempt_off_a', 'exempt_in_b', 'exempt_off_b',
        'exempt_fires_natural' }) do
        rawset(c, k, 0)
    end

    for _, path in ipairs(corpus_paths()) do
        local ok, J, bot = pcall(rf.load, path)
        if not ok or J == nil or bot == nil then
            bump('load_fail')
        else
            bump('frames')
            J.IsSoakCandidate = function(id) return id == 'lf_chase' end

            -- ⭐⭐ THE BRANCH PROBE. J.GetAlliesNearLoc is the one function the
            --    exemption spends, and the guard calls it nowhere else, so a
            --    wrapper here separates "the exemption was computed" from "the
            --    exemption changed the answer" -- which on this corpus it never
            --    can (limit (i)). Counting answers instead would be true of a
            --    mutant that deletes the exemption outright.
            local EXEMPT = 0
            local real_allies = J.GetAlliesNearLoc
            J.GetAlliesNearLoc = function(v, r)
                EXEMPT = EXEMPT + 1
                return real_allies(v, r)
            end

            -- Arm A is the SHIPPED tree, recovered by making the new conjunct
            -- vacuous: with membership always true the exemption is entered for
            -- every target, which is byte-for-byte the pre-narrowing control
            -- flow. Arm B is the real predicate.
            local real_exist = J.IsExistInTable
            local function drive(armed, tgt)
                J.IsExistInTable = armed and real_exist
                    or function() return true end
                EXEMPT = 0
                local okr, r = pcall(J.ShouldNotChaseWhenLow, bot, tgt)
                J.IsExistInTable = real_exist
                if not okr then
                    bump('raised')
                    return 'ERR', 0
                end
                return (r and 'T' or 'F'), EXEMPT
            end

            local hp = bot:GetHealth() / bot:GetMaxHealth()
            if hp < 0.40 then
                bump('low_hp')
                local tE = J.GetEnemiesNearLoc(bot:GetLocation(), RING_R) or {}
                local nBurst = J.GetTotalEstimatedDamageToTarget(tE, bot)
                if nBurst >= bot:GetHealth() * 0.45 then
                    bump('reach_rows')
                    for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
                        if J.IsValidHero(e) then
                            -- ⛔ THE CLASSIFIER IS NOT THE SUBJECT. This split
                            -- is computed with an inline identity loop, NOT
                            -- with J.IsExistInTable -- the helper the narrowing
                            -- calls and the mutation stand mutates. Routing it
                            -- through that helper made §2's own pair counts
                            -- collapse together with the mutant (M2 came back
                            -- CAUGHT by §2 instead of by §3's branch counters),
                            -- which reads like sensitivity and is actually the
                            -- axis and the subject moving as one.
                            local bIn = false
                            for _, x in pairs(tE) do
                                if x == e then bIn = true end
                            end
                            local d = GetUnitToUnitDistance(bot, e)
                            -- Real allies around the target, excluding self:
                            -- the exemption's own inputs, measured.
                            local nOthers = 0
                            for _, a in pairs(real_allies(e:GetLocation(), 1200) or {}) do
                                if a ~= bot then nOthers = nOthers + 1 end
                            end
                            local rA, xA = drive(false, e) -- shipped
                            local rB, xB = drive(true, e)  -- narrowed
                            if bIn then
                                bump('in_p')
                                if MAX_IN_D == nil or d > MAX_IN_D then MAX_IN_D = d end
                                if nOthers > 0 then bump('in_with_allies') end
                                if xA > 0 then bump('exempt_in_a') end
                                if xB > 0 then bump('exempt_in_b') end
                            else
                                bump('off_p')
                                if MIN_OFF_D == nil or d < MIN_OFF_D then
                                    MIN_OFF_D = d
                                    NEAR_SEEN = path:sub(-#NEAR_FIX) == NEAR_FIX
                                        and e:GetUnitName() == NEAR_HERO
                                end
                                if d < 3000 then bump('near_off') end
                                if nOthers > 0 then bump('off_with_allies') end
                                if xA > 0 then bump('exempt_off_a') end
                                if xB > 0 then bump('exempt_off_b') end
                            end
                            if rA == 'T' then bump('fire_a') end
                            if rB == 'T' then bump('fire_b') end
                            if rA ~= rB then
                                bump('flip_ab')
                                -- The forbidden direction: the narrowing may
                                -- only ADD true answers.
                                if rA == 'T' then bump('shrink_ba') end
                            end
                            -- Did the SHIPPED exemption ever actually exempt?
                            if rA == 'F' then bump('exempt_fires_natural') end
                        end
                    end
                end
            end
            J.GetAlliesNearLoc = real_allies
        end
    end
    return c
end

local function census_or_die()
    if SWEEP == nil and SWEEP_ERR == nil then
        local ok, res = pcall(run_sweep)
        if ok then SWEEP = res else SWEEP_ERR = tostring(res) end
    end
    assert(SWEEP ~= nil, 'the corpus sweep did not run: ' .. tostring(SWEEP_ERR))
end

-- ------------------------------------------------------------- §2 census ---

tests['[chasering] 2. the corpus drove, and the domain is not empty'] = function()
    census_or_die()
    assert(SWEEP['load_fail'] == 0,
        SWEEP['load_fail'] .. ' corpus file(s) failed to load. Every count in '
        .. 'this file is then taken over a smaller corpus than it claims.')
    -- 2026-09-17 (replay-check): 142 -> 144, the two staged `campbind`
    -- condition-(a) frames (tests/frames/README.md carries the row).
    -- RE-MEASURED, not edited: every count below was re-run over the grown
    -- corpus and is asserted unchanged, so this is a denominator move.
    assert(SWEEP['frames'] == 144,
        'corpus size moved: ' .. SWEEP['frames'] .. ' frames, was 144. Re-read '
        .. 'every count below before quoting it.')
    assert(SWEEP['raised'] == 0,
        SWEEP['raised'] .. ' drive(s) raised. An arm that errored is not an arm '
        .. 'that answered.')
    -- The guard's own three anchored legs, as a funnel: 142 subjects -> 23 under
    -- 40% HP -> 8 of those with a punishing ring that can take 45% of what is
    -- left. Nothing below is comparable across a change in these.
    assert(SWEEP['low_hp'] == 23,
        'subjects under the 0.40 HP leg moved: ' .. SWEEP['low_hp'] .. ', was 23.')
    assert(SWEEP['reach_rows'] == 8,
        'rows reaching the exemption moved: ' .. SWEEP['reach_rows'] .. ', was 8. '
        .. 'This is the guard\'s live domain on this corpus.')
    assert(SWEEP['off_p'] == 23 and SWEEP['in_p'] == 17,
        'the (row, enemy) pair split moved: off=' .. SWEEP['off_p'] .. ' in='
        .. SWEEP['in_p'] .. ', was 23/17.')
    -- ⭐ THE INSTRUMENT CONTROL. A broken distance call would hand back the same
    --   split for free. The two sides must straddle the parsed ring radius.
    assert(MIN_OFF_D ~= nil and MIN_OFF_D > RING_R,
        'an "off-ring" pair sits at ' .. tostring(MIN_OFF_D) .. ' <= the parsed '
        .. 'ring radius ' .. tostring(RING_R) .. '. The membership split and the '
        .. 'distance instrument disagree.')
    assert(MAX_IN_D ~= nil and MAX_IN_D <= RING_R,
        'an "in-ring" pair sits at ' .. tostring(MAX_IN_D) .. ' > the parsed ring '
        .. 'radius ' .. tostring(RING_R) .. '.')
end

-- --------------------------------------------------------------- §3 arms ---

tests['[chasering] 3. two arms: the BRANCH moves, the answers do not, and the sign holds'] = function()
    census_or_die()
    -- ⭐⭐ THE DISCRIMINATING READING. Shipped: the exemption is computed for
    --    every pair that reaches it, 23 of them around a hero the bot is not
    --    fighting. Narrowed: off-ring pairs never enter it, in-ring pairs are
    --    untouched. A mutant that deletes the exemption outright, or one that
    --    skips it unconditionally, moves these numbers -- which is exactly what
    --    an answer count on this corpus could not do.
    assert(SWEEP['exempt_off_a'] == 23,
        'shipped entered the exemption on ' .. SWEEP['exempt_off_a']
        .. ' off-ring pair(s), was 23. A ZERO here means arm A is no longer the '
        .. 'shipped tree -- check that the J.IsExistInTable stub still recovers '
        .. 'it before reading anything else.')
    assert(SWEEP['exempt_off_b'] == 0,
        SWEEP['exempt_off_b'] .. ' off-ring pair(s) still reached the exemption '
        .. 'with the narrowing live. That is the defect itself, not a narrowing '
        .. 'of it.')
    -- ...and the INTENDED domain is left alone, on the branch as well as the
    -- answer. Both numbers, or the zero above is free.
    assert(SWEEP['exempt_in_a'] == 17 and SWEEP['exempt_in_b'] == 17,
        'in-ring exemption entries moved: shipped=' .. SWEEP['exempt_in_a']
        .. ' narrowed=' .. SWEEP['exempt_in_b'] .. ', was 17/17. An in-ring '
        .. 'target is the one case the narrowing must not touch.')
    -- ⭐ THE SIGN, ASSERTED. The exemption is the only `return false` left at
    --   that point, so the narrowed FALSE set is a subset of the shipped one.
    assert(SWEEP['shrink_ba'] == 0,
        SWEEP['shrink_ba'] .. ' pair(s) went TRUE -> FALSE when the narrowing '
        .. 'was applied. That direction is impossible by construction; if it '
        .. 'happened, the conjunct is not wrapping only the exemption.')
    -- ⚠️ A REAL READING THAT IS NOT A DISCRIMINATING ONE, kept and labelled
    --   rather than deleted (the (癸) rule). flip_ab is 0 because the mock's
    --   ally burst is 0, so the shipped exemption never fires -- see §5.
    assert(SWEEP['flip_ab'] == 0,
        SWEEP['flip_ab'] .. ' answer(s) changed. On this corpus that is supposed '
        .. 'to be impossible (limit (i)): if it is no longer 0 the instrument '
        .. 'has changed and §4\'s counterfactual should become a real frame.')
    assert(SWEEP['fire_a'] == 40 and SWEEP['fire_b'] == 40,
        'the guard fires ' .. SWEEP['fire_a'] .. '/' .. SWEEP['fire_b']
        .. ' (shipped/narrowed), was 40/40.')
end

-- ----------------------------------------------------- §4 counterfactual ---

tests['[chasering] 4. the answer flip, on a real frame with ONE declared number'] = function()
    -- ⚠️ THIS SECTION IS A COUNTERFACTUAL AND SAYS SO. Everything below is real
    --    frame state -- the bot's HP, the two enemies on top of it, the target
    --    6,486.8u away, the ally standing next to that target -- EXCEPT the
    --    ally's burst on the target, which the mock cannot answer (limit (i))
    --    and which is declared here. That single number is what the shipped
    --    exemption reads, so declaring it is the smallest possible way to show
    --    the branch changing an answer.
    local J, bot = rf.load(CF_FIX)
    J.IsSoakCandidate = function(id) return id == 'lf_chase' end

    local tgt = nil
    for _, e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES) or {}) do
        if e:GetUnitName() == CF_TARGET then tgt = e end
    end
    assert(tgt ~= nil, CF_TARGET .. ' is no longer on ' .. CF_FIX
        .. '; the counterfactual has lost its frame.')

    -- The real geometry, asserted before anything is declared.
    local hp = bot:GetHealth() / bot:GetMaxHealth()
    assert(hp < 0.40, 'the counterfactual subject is at ' .. hp
        .. ' HP and no longer passes the guard\'s own low-HP leg.')
    local tE = J.GetEnemiesNearLoc(bot:GetLocation(), 1200) or {}
    assert(#tE >= 2, 'the punishing ring is down to ' .. #tE .. ' enemies.')
    assert(not J.IsExistInTable(tgt, tE),
        CF_TARGET .. ' is now INSIDE the punish ring; it was the off-ring target '
        .. 'this section is built on.')
    local d = GetUnitToUnitDistance(bot, tgt)
    assert(d > 6000, 'the counterfactual target is now ' .. d .. 'u away; the '
        .. 'claim being illustrated is that the exemption reads a fight the bot '
        .. 'is nowhere near.')
    local nOthers = 0
    for _, a in pairs(J.GetAlliesNearLoc(tgt:GetLocation(), 1200) or {}) do
        if a ~= bot then nOthers = nOthers + 1 end
    end
    assert(nOthers >= 1,
        'no ally of ours stands within 1200 of ' .. CF_TARGET .. ' any more, so '
        .. 'the declared burst below would be attributed to nobody.')

    -- THE ONE DECLARED NUMBER: those allies can finish that hero.
    local real_total = J.GetTotalEstimatedDamageToTarget
    J.GetTotalEstimatedDamageToTarget = function(tUnits, t)
        if t == tgt then return t:GetHealth() + t:GetHealthRegen() * 3 end
        return real_total(tUnits, t)
    end

    local real_exist = J.IsExistInTable
    J.IsExistInTable = function() return true end
    local shipped = J.ShouldNotChaseWhenLow(bot, tgt)
    J.IsExistInTable = real_exist
    local narrowed = J.ShouldNotChaseWhenLow(bot, tgt)

    assert(shipped == false,
        'SHIPPED no longer exempts this bot. The defect being illustrated is '
        .. 'that a securable kill ' .. math.floor(d) .. 'u away cancels the '
        .. 'retreat bid of a hero at ' .. string.format('%.1f%%', hp * 100)
        .. ' HP with ' .. #tE .. ' enemies on it.')
    assert(narrowed == true,
        'NARROWED no longer refuses the chase. With the target off-ring the '
        .. 'exemption must be skipped and the guard must answer from its own '
        .. 'three bot-anchored facts.')
end

-- ------------------------------------------------------------ §5 controls ---

tests['[chasering] 5. positive controls, the near band, and the instrument limit'] = function()
    census_or_die()
    -- ⭐ (庚): the leg being trimmed is a POLLUTED one, not one that never fires.
    --   The exemption really is computed off-ring, and 10 of those 23 times it
    --   has real allies to score -- so this is not a narrowing of an empty set.
    assert(SWEEP['off_with_allies'] == 10,
        'off-ring pairs with a non-empty ally set moved: '
        .. SWEEP['off_with_allies'] .. ', was 10. A ZERO would mean the shipped '
        .. 'exemption could never compute anything off-ring on this corpus, and '
        .. 'the whole reading would be about an unreachable branch.')
    assert(SWEEP['in_with_allies'] > 0,
        'no in-ring pair has allies near the target either, so the ally probe is '
        .. 'measuring the corpus\'s emptiness rather than the split.')
    -- ⭐ (壬): the near band is where the repair is realistic. Pinned by name so
    --   a corpus change cannot turn this green on an empty band.
    assert(SWEEP['near_off'] == 3,
        'the near band (off-ring, < 3000u) moved: ' .. SWEEP['near_off']
        .. ' pairs, was 3.')
    assert(NEAR_SEEN,
        'the nearest off-ring pair is no longer ' .. NEAR_FIX .. ' / '
        .. NEAR_HERO .. ' (now ' .. tostring(MIN_OFF_D) .. 'u). The claim that '
        .. 'this defect lives at ordinary order-target distances rests on it.')
    assert(MIN_OFF_D ~= nil and MIN_OFF_D < 1500,
        'the nearest off-ring pair is now at ' .. tostring(MIN_OFF_D)
        .. ' units. Far enough out, "the target is not in my fight" stops being '
        .. 'a subtle claim and this file would be pricing only the easy half.')
    -- ⚠️ THE INSTRUMENT LIMIT, PINNED AS A NUMBER. The shipped exemption never
    --   fires naturally anywhere in this corpus, and that is WHY §3 counts
    --   branches and §4 is a counterfactual. If this ever becomes non-zero the
    --   mock has gained an ally-damage model and this file should be re-read.
    assert(SWEEP['exempt_fires_natural'] == 0,
        'the shipped exemption fired naturally on '
        .. SWEEP['exempt_fires_natural'] .. ' pair(s). The corpus has gained an '
        .. 'ally-burst model -- §3\'s flip_ab == 0 and §4\'s counterfactual both '
        .. 'need re-reading, and the answer-level effect can now be measured for '
        .. 'real.')
end

return tests

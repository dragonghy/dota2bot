-- [hero] `axecullbm` -- Culling Blade into an active Blade Mail.  Written
-- 2026-09-15 under OWNER_PRIORITIES P4.4 (i), closing the ruling GH #833 asked
-- for and landing the lever that ruling authorised.
--
-- WHAT GH #833 ASKED, AND WHY IT DISSOLVED
-- ----------------------------------------
-- The issue measured that X.ConsiderR's execute loop asks seven vetoes and
-- none of them is Blade Mail, while hero_windrunner.lua and
-- hero_primal_beast.lua both ask it -- and then REFUSED to call that a defect,
-- because the answer hangs on whether "the kill below the threshold" is a
-- reflectable damage instance, and it judged that unanswerable offline.
--
-- ⭐ There is no kill-threshold branch to ask about.  `axe_culling_blade`
-- carries no kill_threshold key in the live KV (d2vpkr
-- dota/scripts/npc/heroes/npc_dota_hero_axe.txt, read 2026-09-15: grep for
-- `kill` and for `threshold` over the whole hero file returns nothing) and none
-- in this tree's own snapshot either -- section 6 drives that half against
-- tests/mock/special_value_shapes.lua rather than quoting the network read.
-- What the ability has is `damage` 275/375/475 at DAMAGE_TYPE_PURE.  So the
-- loop's health test is a LETHALITY PREDICATE OVER A PURE DAMAGE INSTANCE, and
-- an ordinary pure damage instance is reflected.  Condition (c) holds, on two
-- sources that agree.
--
-- ⭐⭐ AND THE SIBLING PATTERN IS THE WRONG FIX (section 7).  The three
-- block/reflect vetoes already in X.HasSpecialModifier stop the cast from
-- killing anything, so refusing is free.  Blade Mail is not that family: the
-- cull still lands and the target still dies; Axe pays health.  A blanket veto
-- would throw away a certain hero kill.  The lever therefore vetoes ONLY where
-- the return kills Axe, at the bound that is true under both readings of the
-- one thing the KV cannot settle:
--     bot:GetHealth() <= 0.85 * npcEnemy:GetHealth()
-- Read X.IsCullReflectLethal's header in bots/BotLib/hero_axe.lua for the
-- interval argument and the four honest bounds.
--
-- THE FRAME
-- ---------
-- FRAME_BM -- tests/frames/f_260831_061811_axe_call_tp_channel.lua, t=1209.9,
-- game 20260831_061811_slot1.  Axe level 19 at 2548/2597 with a rank-2 Culling
-- off cooldown; a Bristleback at 190.2u holding blade_mail with an ACTIVE
-- modifier_item_blade_mail_reflect, 1299/2460.  190.2u is inside the shipped
-- 375 pool and outside the 175 reach, so this frame is one conjunct short of
-- the guard -- the supply and the instrument are real, the decision is not.
--
-- ⭐ GH #833's own scan reported ONE reflect row in the whole corpus because it
-- looked only in tests/fixtures/.  Section 2 re-measures across both corpus
-- directories and finds three, in two files, one of which is this frame -- the
-- only one that carries BOTH operands of the guard.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANYTHING FROM HERE
-- -------------------------------------------------------
--   * THE DECISION DOMAIN IS ZERO AND SECTION 2 SAYS SO AS A NUMBER.  No frame
--     in either corpus directory carries a reflect-active enemy below a cull
--     threshold.  Section 4 therefore drives the PREDICATE on the real frame
--     (where it correctly answers false for a healthy Axe) and section 5 drives
--     the end-to-end flip as an explicitly LABELLED COUNTERFACTUAL.  Neither is
--     presented as a case sighting.
--   * FRAME_BM IS STAGED, NOT ADMITTED.  It lives in tests/frames/ and is
--     loaded by name; its admission price to tests/fixtures/ is not measured
--     here and no number is claimed for it.  See tests/frames/README.md.
--   * THE 0.85 IS A RECORDED KV READ (d2vpkr items.txt, "item_blade_mail",
--     "active_reflection_pct" "85") with NO in-repo cross-check -- items are not
--     in special_value_shapes.lua at all.  Section 6 pins the literal against
--     the quoted line; that is a drift guard, not a verification.
--   * IN-GAME FREQUENCY IS NOT MEASURED HERE.  queue.json hero-89 asks for it
--     off archived .dem (zero EC2).
--
-- Run: lua5.1 tests/run_tests.lua axe_cull_blade_mail

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local SRC = 'bots/BotLib/hero_axe.lua'
local CAND = 'axecullbm'
local GATE = 'IsCullReflectOn'
local HELPER = 'IsCullReflectLethal'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR = 'tests/frames'

local FRAME_BM = STAGED_DIR .. '/f_260831_061811_axe_call_tp_channel.lua'

local AXE = 'npc_dota_hero_axe'
local BRISTLE = 'npc_dota_hero_bristleback'
local CULLING = 'axe_culling_blade'
local REFLECT = 'modifier_item_blade_mail_reflect'
local BONUS = 200
local SHARE = 0.85

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

local function unit_named(fx, sName)
    for _, u in ipairs(fx.units) do
        if u.name == sName then return u end
    end
    return nil
end

local function modifier_names(u)
    local out = {}
    for _, m in ipairs(u.modifiers or {}) do
        out[#out + 1] = (type(m) == 'table') and m.name or m
    end
    return out
end

local function has_reflect(u)
    for _, name in ipairs(modifier_names(u)) do
        if name == REFLECT then return true end
    end
    return false
end

--- Load a frame, arm or disarm THIS lever's id only, and drive the real
--- X.ConsiderR.  `armed` is a boolean because this lever has exactly one id;
--- the moment it grows a second, this helper has to become a list.
local function drive(path, armed, tPatch)
    local J, bot, heroes, fx = rf.load(path)
    -- `== true`, not a bare lookup: an absent key answers nil, and a helper
    -- asserted `== false` would then pass on a nil that behaves identically.
    J.IsSoakCandidate = function(id) return (armed == true) and id == CAND end
    local X = rf.load_hero('axe')
    if tPatch ~= nil then tPatch(J, bot, X) end
    local d, hTarget, sMotive = X.ConsiderR()
    return d, hTarget, sMotive, J, bot, heroes, fx, X
end

--- The CODE of one function in hero_axe.lua -- `function X.name(` through its
--- own closing `end` at column 0 -- so the source ratchets below cannot be
--- satisfied by a matching string elsewhere in a 1700-line file.
---
--- ⚠️ THE OBVIOUS SPELLING OF THIS IS WRONG AND IT COST A RED.  The sibling
--- files cut at the next `function X.`, which swallows the HEADER COMMENT of
--- whatever comes next.  That is harmless when the assertion is "this string is
--- present" and wrong when it is "this string is absent": the first draft of
--- section 6's single-id check read `cullthresh` out of X.IsCullReflectLethal's
--- header and failed, naming a sibling the gate does not mention.  Same shape
--- as the `mutstand_zusultd` M3 lesson -- an assertion about a function that is
--- really about the prose under it.
local function fn_code(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nend')
    assert(to, 'X.' .. name .. ' has no closing `end` at column 0 in ' .. SRC)
    return rest:sub(1, to + 4)
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth, all of it read off the frame.  If FRAME_BM is ever recut these
-- go red and name the number that moved, instead of the sections below quietly
-- measuring a different world.

tests['\194\1671 FRAME_BM carries both operands: a rank-2 Culling and a reflect-active enemy at 190.2u'] = function()
    local _, _, _, _, bot, _, fx = drive(FRAME_BM, false)

    local me, bristle = unit_named(fx, AXE), unit_named(fx, BRISTLE)
    assert(me and bristle, 'FRAME_BM no longer carries both Axe and Bristleback')
    assert(me.hp == 2548 and me.max_hp == 2597,
        'Axe is at ' .. tostring(me.hp) .. '/' .. tostring(me.max_hp) .. ', was 2548/2597')
    assert(bristle.hp == 1299 and bristle.max_hp == 2460,
        'Bristleback is at ' .. tostring(bristle.hp) .. '/' .. tostring(bristle.max_hp)
        .. ', was 1299/2460')
    assert(bristle.team ~= me.team, 'the Bristleback is no longer on the other side')

    local abilityR = bot:GetAbilityByName(CULLING)
    assert(abilityR:GetCastRange() == 175,
        'Culling Blade cast range reads ' .. tostring(abilityR:GetCastRange()) .. ', not 175')
    assert(abilityR:GetLevel() == 2, 'Culling rank moved, got ' .. tostring(abilityR:GetLevel()))
    assert(abilityR:IsFullyCastable(), 'Culling is no longer castable on FRAME_BM')

    local d = dist2d(bristle, me)
    assert(math.abs(d - 190.2) < 0.5,
        'Bristleback is at ' .. string.format('%.1f', d) .. 'u, was 190.2u')
    assert(d <= 175 + BONUS,
        'the Bristleback has left the shipped (nCastRange + 200) pool -- this frame stops '
        .. 'being the one where both operands of the guard are present')
end

tests['\194\1671 the instrument reads the ACTIVE reflect modifier, and the item behind it'] = function()
    local _, _, _, J, bot, _, fx = drive(FRAME_BM, false)
    local bristle = unit_named(fx, BRISTLE)

    assert(has_reflect(bristle),
        'the Bristleback row no longer carries ' .. REFLECT
        .. ' -- with it goes the only real-frame supply this lever has')
    local bHoldsItem = false
    for _, it in ipairs(bristle.items or {}) do
        if it == 'blade_mail' or it == 'item_blade_mail' then bHoldsItem = true end
    end
    assert(bHoldsItem, 'the Bristleback no longer holds blade_mail -- the modifier and the '
        .. 'item are two readings and this file quotes both')

    -- Read through the loop's own pool rather than off the fixture table: what
    -- matters is that the guard's operand is visible to the code, not that a
    -- row in a lua file has a string in it.
    local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
    assert(#pool == 1, 'the shipped pool holds ' .. #pool .. ' enemies on FRAME_BM, was 1')
    assert(pool[1]:GetUnitName() == BRISTLE,
        'the shipped pool now holds ' .. tostring(pool[1]:GetUnitName()) .. ', was ' .. BRISTLE)
    assert(pool[1]:HasModifier(REFLECT) == true,
        'HasModifier(' .. REFLECT .. ') answers ' .. tostring(pool[1]:HasModifier(REFLECT))
        .. ' through the pool handle -- the instrument, not the data, has stopped working')
end

-- ---------------------------------------------------------------- section 2 --
-- The census.  GH #833 reported ONE reflect row because it scanned only
-- tests/fixtures/; this re-measures both corpus directories, and -- the number
-- that actually governs this lever -- counts the DECISION domain.

tests['\194\1672 supply census over both corpus directories: 3 active-reflect rows in 2 files'] = function()
    local nFiles, nRows, nHolding, nReflect = 0, 0, 0, 0
    local tReflectFiles = {}
    for _, path in ipairs(corpus_paths()) do
        local chunk = loadfile(path)
        local ok, fx = pcall(chunk)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            nFiles = nFiles + 1
            for _, u in ipairs(fx.units) do
                if type(u.name) == 'string' and u.name:match('^npc_dota_hero_') then
                    nRows = nRows + 1
                    for _, it in ipairs(u.items or {}) do
                        if it == 'blade_mail' or it == 'item_blade_mail' then
                            nHolding = nHolding + 1
                            break
                        end
                    end
                    if has_reflect(u) then
                        nReflect = nReflect + 1
                        tReflectFiles[path] = true
                    end
                end
            end
        end
    end

    -- Ratchets, not equalities: the corpus grows, and a growing corpus must not
    -- be able to turn this census red for a reason that has nothing to do with
    -- the lever.  The reading as measured 2026-09-15 was
    -- 142 / 1420 / 23 / 3, in 2 files.
    assert(nFiles >= 142, 'the corpus shrank to ' .. nFiles .. ' frames, was 142 -- re-read '
        .. 'every count in this file before quoting one')
    assert(nRows >= 1420, 'the corpus shrank to ' .. nRows .. ' hero rows, was 1420')
    assert(nHolding >= 23, 'rows holding blade_mail fell to ' .. nHolding .. ', was 23 -- the '
        .. 'supply argument in this lever\'s header is priced off that number')
    assert(nReflect >= 3, 'rows with an ACTIVE ' .. REFLECT .. ' fell to ' .. nReflect
        .. ', was 3 -- GH #833 measured 1 by looking only in ' .. FIXTURE_DIR)

    local nReflectFiles = 0
    for _ in pairs(tReflectFiles) do nReflectFiles = nReflectFiles + 1 end
    assert(nReflectFiles >= 2, 'active reflect now appears in ' .. nReflectFiles
        .. ' file(s), was 2')
    assert(tReflectFiles[FRAME_BM], FRAME_BM .. ' no longer carries an active reflect row')
end

tests['\194\1672 DECISION domain is ZERO: no reflect-active enemy anywhere sits below a cull line'] = function()
    -- The set this lever can actually move: an enemy of an Axe, carrying an
    -- active reflect, inside the shipped pool, and below the shipped threshold.
    -- The threshold ladder is read as the shipped 150 + 100*rank; `cullthresh`
    -- may widen it and this file never arms that id.  Rank is taken as 3 -- the
    -- WIDEST shipped threshold, 450 -- so the count cannot be zero merely
    -- because the Axe on a frame had a low rank.
    local nDomain, nCandidateFrames = 0, 0
    local tNear = {}
    for _, path in ipairs(corpus_paths()) do
        local chunk = loadfile(path)
        local ok, fx = pcall(chunk)
        if ok and type(fx) == 'table' and type(fx.units) == 'table' then
            local me = unit_named(fx, AXE)
            if me ~= nil then
                for _, u in ipairs(fx.units) do
                    if type(u.name) == 'string' and u.name:match('^npc_dota_hero_')
                        and u.team ~= me.team and has_reflect(u) then
                        nCandidateFrames = nCandidateFrames + 1
                        local d = dist2d(u, me)
                        tNear[#tNear + 1] = string.format('%s %s hp=%d dist=%.1f',
                            path, u.name, u.hp, d)
                        if d <= 175 + BONUS and u.hp < 150 + 100 * 3 then
                            nDomain = nDomain + 1
                        end
                    end
                end
            end
        end
    end

    assert(nCandidateFrames == 1, 'the corpus now holds ' .. nCandidateFrames
        .. ' (Axe, reflect-active enemy) pairs, was 1: ' .. table.concat(tNear, ' | '))
    assert(nDomain == 0, 'the decision domain is no longer 0 but ' .. nDomain
        .. ' -- a real case has appeared, and sections 4 and 5 should be rewritten to '
        .. 'drive it instead of driving a counterfactual: ' .. table.concat(tNear, ' | '))
end

-- ---------------------------------------------------------------- section 3 --
-- Inertness.  Unarmed, the loop must answer exactly what the shipped tree
-- answered -- on every Axe-bearing frame in the corpus, not just on FRAME_BM.

tests['\194\1673 unarmed == armed on every Axe-bearing frame (the domain-zero reading, driven)'] = function()
    local nDriven, nMoved = 0, 0
    local tMoved = {}
    for _, path in ipairs(corpus_paths()) do
        local chunk = loadfile(path)
        local ok, fx = pcall(chunk)
        if ok and type(fx) == 'table' and type(fx.units) == 'table'
            and unit_named(fx, AXE) ~= nil and fx.self == AXE then
            local okOff, dOff, hOff = pcall(drive, path, false)
            local okOn, dOn, hOn = pcall(drive, path, true)
            if okOff and okOn then
                nDriven = nDriven + 1
                local sOff = tostring(dOff) .. '/' .. tostring(hOff and hOff:GetUnitName())
                local sOn = tostring(dOn) .. '/' .. tostring(hOn and hOn:GetUnitName())
                if sOff ~= sOn then
                    nMoved = nMoved + 1
                    tMoved[#tMoved + 1] = path .. ' ' .. sOff .. ' -> ' .. sOn
                end
            end
        end
    end
    assert(nDriven >= 16, 'only ' .. nDriven .. ' Axe-subject frames drove -- this section is '
        .. 'close to passing vacuously; it drove 16 when it was written (40 corpus frames '
        .. 'hold an Axe row, 16 of them have Axe as the fixture SUBJECT, which is what '
        .. 'X.ConsiderR needs)')
    assert(nMoved == 0, nMoved .. ' frame(s) changed answer when the id was armed, and the '
        .. 'decision domain measured in section 2 is 0 -- one of the two is wrong: '
        .. table.concat(tMoved, ' | '))
end

tests['\194\1673 FRAME_BM: unarmed and armed both decline, and NOT because the pool is empty'] = function()
    local dOff, hOff = drive(FRAME_BM, false)
    local dOn, hOn = drive(FRAME_BM, true)
    assert(dOff == BOT_ACTION_DESIRE_NONE and hOff == nil,
        'unarmed FRAME_BM now bids ' .. tostring(dOff))
    assert(dOn == BOT_ACTION_DESIRE_NONE and hOn == nil,
        'armed FRAME_BM now bids ' .. tostring(dOn))

    -- Why it declines matters: the Bristleback IS in the pool and IS reflecting;
    -- what stops the cast is the health test, three conjuncts ABOVE this guard.
    -- Without this control, "both legs answer NONE" and "the loop body never ran"
    -- look identical.
    local _, _, _, J, bot, _, _ = drive(FRAME_BM, true)
    local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
    assert(#pool == 1 and pool[1]:HasModifier(REFLECT),
        'the reflecting enemy has left the pool -- section 5 is no longer a counterfactual '
        .. 'over a real frame')
    assert(pool[1]:GetHealth() >= 150 + 100 * 3,
        'the Bristleback is at ' .. tostring(pool[1]:GetHealth())
        .. ', now BELOW the widest shipped threshold 450 -- this is a real case and '
        .. 'section 2 should have caught it first')
end

-- ---------------------------------------------------------------- section 4 --
-- The predicate itself, on the real frame.  This is the NEGATIVE control that
-- separates this lever from the blanket veto section 7 rejects: a healthy Axe
-- facing an active Blade Mail must still be allowed to cull.

tests['\194\1674 armed, the guard answers FALSE for the real Axe against the real reflecting enemy'] = function()
    local _, _, _, J, bot, _, _, X = drive(FRAME_BM, true)
    local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
    local hEnemy = pool[1]

    assert(X[GATE]() == true, 'X.' .. GATE .. '() answers ' .. tostring(X[GATE]())
        .. ' with the id armed in a turbo fixture -- the gate itself is not live')
    assert(X[HELPER](hEnemy) == false,
        'the guard vetoes a cull by a 2548 hp Axe against a 1299 hp reflecting enemy -- '
        .. '0.85 * 1299 = ' .. (SHARE * 1299) .. ' and Axe is far above it')

    -- The arithmetic, stated so a future edit cannot quietly change the bound.
    assert(bot:GetHealth() > SHARE * hEnemy:GetHealth(),
        'the frame no longer satisfies the inequality this section is a control for')
end

tests['\194\1674 unarmed, the guard answers FALSE for every input -- including a lethal one'] = function()
    local _, _, _, J, bot, _, _, X = drive(FRAME_BM, false)
    local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
    assert(X[GATE]() == false, 'X.' .. GATE .. '() answers true with the id UNARMED')
    assert(X[HELPER](pool[1]) == false, 'unarmed guard answered true on the real frame')

    -- Force the inequality true and confirm the unarmed leg still refuses: the
    -- gate has to be the thing holding it shut, not the arithmetic.
    bot.GetHealth = function() return 1 end
    assert(X[HELPER](pool[1]) == false,
        'with Axe on 1 hp against a 1299 hp reflecting enemy the UNARMED guard answered '
        .. 'true -- the gate is not what keeps this lever dark')
end

-- ---------------------------------------------------------------- section 5 --
-- Liveness and the knife edge.  ⚠️ EXPLICITLY COUNTERFACTUAL: the corpus holds
-- no frame in this lever's decision domain (section 2), so these drive the real
-- frame with one or two readings overridden.  Nothing here is a case sighting.

tests['\194\1675 COUNTERFACTUAL: the health crossing is exactly 0.85 * target health'] = function()
    local nTarget = 1299
    local nEdge = SHARE * nTarget  -- 1104.15
    for _, probe in ipairs({
        { hp = math.floor(nEdge) - 1, want = true },
        { hp = math.floor(nEdge), want = true },
        { hp = math.ceil(nEdge), want = false },
        { hp = math.ceil(nEdge) + 1, want = false },
        { hp = 1, want = true },
        { hp = 2548, want = false },
    }) do
        local _, _, _, J, bot, _, _, X = drive(FRAME_BM, true)
        local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
        assert(pool[1]:GetHealth() == nTarget,
            'the target is at ' .. tostring(pool[1]:GetHealth()) .. ', this ladder is priced '
            .. 'off ' .. nTarget)
        bot.GetHealth = function() return probe.hp end
        assert(X[HELPER](pool[1]) == probe.want,
            'Axe on ' .. probe.hp .. ' hp against ' .. nTarget .. ': guard answered '
            .. tostring(X[HELPER](pool[1])) .. ', expected ' .. tostring(probe.want)
            .. ' (crossing is ' .. nEdge .. ')')
    end
end

tests['\194\1675 COUNTERFACTUAL: the equality case, on a target health that makes the crossing an integer'] = function()
    -- ⚠️ THIS PROBE EXISTS BECAUSE THE LADDER ABOVE COULD NOT SEE `<=` vs `<`.
    -- 0.85 * 1299 = 1104.15, so no INTEGER health lands on the crossing and a
    -- mutant that drops the equality case survives the whole ladder (mutation
    -- stand M7, first run).  Health is an integer in Dota, so the fix is not to
    -- probe a fractional hp -- it is to pick a target health whose 85% IS an
    -- integer.  1300 * 0.85 = 1105 exactly, and 1300 is one hit point off the
    -- real Bristleback, so the probe is a realistic state rather than a
    -- contrived one.
    local nTarget = 1300
    local nEdge = SHARE * nTarget
    assert(nEdge == math.floor(nEdge), 'the crossing is no longer an integer -- this probe '
        .. 'has stopped being able to see the equality case, which is the only thing it is for')

    for _, probe in ipairs({
        { hp = nEdge - 1, want = true },
        { hp = nEdge, want = true },   -- <= keeps this true; < does not
        { hp = nEdge + 1, want = false },
    }) do
        local _, _, _, J, bot, _, _, X = drive(FRAME_BM, true)
        local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
        pool[1].GetHealth = function() return nTarget end
        bot.GetHealth = function() return probe.hp end
        assert(X[HELPER](pool[1]) == probe.want,
            'Axe on ' .. probe.hp .. ' hp against ' .. nTarget .. ': guard answered '
            .. tostring(X[HELPER](pool[1])) .. ', expected ' .. tostring(probe.want)
            .. '.  A hero on exactly the return\'s worth of health DIES to it, so the '
            .. 'comparison must keep its equality case (crossing is ' .. nEdge .. ')')
    end
end

tests['\194\1675 COUNTERFACTUAL: end to end, the armed loop deletes a Culling order the shipped loop issues'] = function()
    -- Both overrides are named: the target dropped to 300 (inside the rank-2
    -- threshold of 350) and Axe dropped to 200 (below 0.85 * 300 = 255).  This
    -- is the shape a real case would have; it is not one.
    local function patch(J, bot, _)
        local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
        assert(#pool == 1, 'counterfactual pool is not the single Bristleback')
        pool[1].GetHealth = function() return 300 end
        bot.GetHealth = function() return 200 end
    end

    local dOff, hOff = drive(FRAME_BM, false, patch)
    assert(dOff > 0 and hOff ~= nil and hOff:GetUnitName() == BRISTLE,
        'the SHIPPED loop no longer orders a Culling at a 300 hp reflecting Bristleback '
        .. '(desire ' .. tostring(dOff) .. ') -- without that, the armed leg below is not a '
        .. 'deletion of anything')

    local dOn, hOn = drive(FRAME_BM, true, patch)
    assert(dOn == BOT_ACTION_DESIRE_NONE and hOn == nil,
        'the ARMED loop still orders the Culling (desire ' .. tostring(dOn) .. ', target '
        .. tostring(hOn and hOn:GetUnitName()) .. ')')
end

tests['\194\1675 COUNTERFACTUAL: with the reflect gone the armed loop casts again'] = function()
    -- The veto must be keyed on the modifier and not on the health numbers:
    -- same two health overrides, reflect removed, armed leg fires.
    local function patch(J, bot, _)
        local pool = J.GetAroundEnemyHeroList(bot:GetAbilityByName(CULLING):GetCastRange() + BONUS)
        pool[1].GetHealth = function() return 300 end
        pool[1].HasModifier = function(_, s) return s ~= REFLECT and false or false end
        bot.GetHealth = function() return 200 end
    end
    local dOn, hOn = drive(FRAME_BM, true, patch)
    assert(dOn > 0 and hOn ~= nil and hOn:GetUnitName() == BRISTLE,
        'with the reflect removed the armed loop still declines (desire ' .. tostring(dOn)
        .. ') -- the veto is keyed on something other than ' .. REFLECT)
end

-- ---------------------------------------------------------------- section 6 --
-- Source pins.  The gate names one id; the conjunct is where the header says it
-- is; the RECORDED constant is watched; and the no-kill-threshold half of the
-- ruling is driven against this tree's own KV snapshot rather than quoted from
-- a network read.

tests['\194\1676 the gate is turbo-only and names exactly one id (the pullcad trap)'] = function()
    local src = read_file(SRC)
    local body = fn_code(src, GATE)
    assert(body:find('J%.IsModeTurbo%(%)'), 'X.' .. GATE .. ' no longer requires turbo')
    assert(body:find("J%.IsSoakCandidate%( '" .. CAND .. "' %)"),
        'X.' .. GATE .. ' no longer names ' .. CAND)
    local n = 0
    for _ in body:gmatch('IsSoakCandidate') do n = n + 1 end
    assert(n == 1, 'X.' .. GATE .. ' now names ' .. n .. ' soak ids.  A gate naming a sibling '
        .. 'is frozen FALSE the day that sibling is promoted, and check_armed_wiring.py '
        .. 'still calls it WIRED')
    -- ⚠️ QUOTED, not bare: `axecull` is a substring of this lever's own id
    -- `axecullbm`, so a bare find reports the gate naming a sibling it does not
    -- name.  The first draft did exactly that.  A soak id only ever appears
    -- inside single quotes at a call site, so quoting is also the tighter test.
    for _, sibling in ipairs({ 'cullthresh', 'axecullreach', 'axecull' }) do
        assert(not body:find("'" .. sibling .. "'", 1, true),
            'X.' .. GATE .. ' mentions the sibling id ' .. sibling)
    end
    assert(body:find("'" .. CAND .. "'", 1, true),
        'the quoting convention the loop above relies on has changed: ' .. CAND
        .. ' is no longer a single-quoted literal in X.' .. GATE)
end

tests['\194\1676 the conjunct is the LAST one in X.ConsiderR and is negated'] = function()
    local src = read_file(SRC)
    local body = fn_code(src, 'ConsiderR')
    assert(body:find('and not X%.' .. HELPER .. '%( npcEnemy %)'),
        'X.ConsiderR no longer carries `and not X.' .. HELPER .. '( npcEnemy )`')
    local iMine = body:find('X%.' .. HELPER)
    local iShipped = body:find('X%.IsKillBotAntiMage')
    assert(iShipped and iMine and iMine > iShipped,
        'the new conjunct no longer sits after the shipped ones -- the header claims the '
        .. 'shipped conjuncts keep their order and their short-circuit cost')
end

tests['\194\1676 the RECORDED 0.85 is in the source and is the number the helper uses'] = function()
    local src = read_file(SRC)
    assert(src:find('local nCullReflectShare = 0%.85'),
        'nCullReflectShare is no longer 0.85 in ' .. SRC .. ' -- it is a RECORDED KV read '
        .. '("active_reflection_pct" "85") with no in-repo cross-check, so this pin is the '
        .. 'only thing watching it')
    assert(src:find('"active_reflection_pct" "85"', 1, true),
        'the KV line the constant is quoted from has left the header -- a RECORDED anchor '
        .. 'without its provenance is just a number')
    assert(fn_code(src, HELPER):find('nCullReflectShare %* nTargetHealth'),
        'the helper no longer multiplies the target health by the recorded share')
end

tests['\194\1676 the ruling half that can be driven: this tree KNOWS OF NO kill threshold'] = function()
    local kv = read_file('tests/mock/special_value_shapes.lua')
    local from = kv:find("%['axe_culling_blade'%]")
    assert(from, 'axe_culling_blade has left tests/mock/special_value_shapes.lua')
    local block = kv:sub(from, from + 1200)
    local stop = block:find("%['axe_one_man_army'%]")
    block = stop and block:sub(1, stop) or block

    assert(block:find("%['damage'%]"), 'the culling KV snapshot no longer carries `damage`')
    assert(block:find('275 375 475', 1, true),
        'the culling damage ladder is no longer 275 375 475 in this tree\'s KV snapshot -- '
        .. 'the ruling in this file\'s header is priced off it being a damage instance')
    assert(not block:lower():find('threshold'),
        'a `threshold` key has appeared in the culling KV snapshot.  The whole ruling GH #833 '
        .. 'asked for rests on there being no separate kill branch -- re-read it before '
        .. 'quoting this file')
end

-- ---------------------------------------------------------------- section 7 --
-- Why this is NOT the sibling pattern.  Two source-level facts: the tree does
-- write this line elsewhere (so "nobody writes it" is false), and this loop
-- deliberately does not write it in the blanket place.

tests['\194\1677 the blanket veto is NOT in X.HasSpecialModifier, and that is the ruling'] = function()
    local src = read_file(SRC)
    local body = fn_code(src, 'HasSpecialModifier')
    assert(not body:find(REFLECT, 1, true),
        REFLECT .. ' has been added to X.HasSpecialModifier.  That is the blanket veto this '
        .. 'round rejected: the three vetoes already there stop the cast from killing '
        .. 'anything, while a reflected cull still kills the target -- so a blanket refusal '
        .. 'throws away a certain hero kill.  If the desk has changed its mind, the argument '
        .. 'belongs in the header before the code changes')
    -- and the three it DOES carry, so this assertion cannot pass because the
    -- function was emptied.
    for _, m in ipairs({ 'modifier_antimage_spell_shield', 'modifier_item_lotus_orb_active',
                         'modifier_item_sphere_target' }) do
        assert(body:find(m, 1, true), 'X.HasSpecialModifier no longer vetoes ' .. m
            .. ' -- the contrast this section draws has lost one of its terms')
    end
end

tests['\194\1677 two other hero files DO write the blanket line, at call sites of a different kind'] = function()
    local nSites = 0
    for _, path in ipairs({ 'bots/BotLib/hero_windrunner.lua', 'bots/BotLib/hero_primal_beast.lua' }) do
        local src = read_file(path)
        for _ in src:gmatch(REFLECT) do nSites = nSites + 1 end
    end
    assert(nSites >= 5, 'only ' .. nSites .. ' blanket ' .. REFLECT .. ' checks left in '
        .. 'windrunner/primal_beast, was 5.  GH #833\'s "this line is not unwritten in this '
        .. 'repo" reading is priced off them, and so is section 7\'s contrast')
end

return tests

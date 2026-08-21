-- GH #84 (甲): the conjunct/disjunct classification of every published
-- `GetLevel() >= N` gate with N >= 15, pinned so it cannot drift silently.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- The director's 2026-08-21T11:0xZ census (tools/agent/fixture_level_census.py,
-- GH #84 §1) measured the turbo level curve on our own already-paid-for fixture
-- archive.  In the bias-controlled late window (t >= 540s, 21 games / 210
-- hero-slots) it read:
--
--     level >= 10 : 65.7% of slots, 21/21 games   <- alive
--     level >= 15 :  3.3% of slots,  7/21 games   <- near-dead
--     level >= 18 :  0.5% of slots,  1/21 games
--     level >= 20 :  0.0% of slots,  0/21 games   <- dead
--
-- and asked (§5) for the desk-only first step: classify the 22 gates at
-- N >= 15, the 12 in generic files line by line, BEFORE anyone proposes a
-- change.  Constraint (甲) of that issue is the whole point of the exercise:
-- "unreachable" is not "defective" until you say what the unreachability costs.
--
-- WHAT THE CLASSIFICATION FOUND (and where it departs from the issue)
-- -------------------------------------------------------------------
-- The AND/OR shape does NOT predict where the teeth are.  Of the six generic
-- rows whose unreachability actually removes live turbo behaviour, three are
-- conjuncts and three are disjuncts (asserted below).  The discriminator is a
-- different question:
--
--   * Is the level test the SUBJECT of the branch -- i.e. the branch exists to
--     describe what a level-20 hero should do?  Then unreachability costs
--     nothing a turbo game could observe.  Verdict INERT.  It is dead weight,
--     the same kind of dead weight as the t20/t25 half of `tTalentTreeList`
--     (GH #84 §4.2), not a defect.
--   * Or is the level test a MATURITY PROXY bolted onto a purpose that is
--     live at level 10 (guard the ancient, reserve buyback gold, stop farming
--     when the fight is 2500 away)?  Then the constant is the only thing
--     holding that purpose shut.  Verdict TEETH.
--   * Or does a sibling disjunct carry the same purpose with a live predicate?
--     Verdict REDUNDANT.
--
-- Two consequences for the acceptance criterion in GH #84 §5:
--
--   1. "只有分类为合取且 N >= 20 的行才值得继续" selects exactly four rows
--      (aiug:149, aiug:582, aba_site:760, aba_site:824) and ALL FOUR are INERT.
--      Every row with teeth sits at N = 15 or N = 18 -- including the issue's
--      own headline candidate, mode_farm_generic:285 (N = 18).  The filter as
--      written would have discarded the thing it was written to find.
--   2. The issue's sample labels invert on two of the five rows it spot-checked:
--      aba_site:760 / :824 are named 合取(有牙齿) and read INERT here (their
--      subject is a level-20 hero and that hero does not exist in turbo), while
--      mode_farm:392 / :506 are named 无害析取 and read TEETH here.  The load-
--      bearing fact for 392/506 is one line: `J.IsLateGame()` (jmz_func:4337)
--      is `DotaTime() > 18*60` in turbo, and the LATEST frame in the whole
--      94-fixture archive is t = 690.5s.  The "harmless fallback" is itself
--      false everywhere we can see.  Asserted below, both halves.
--
-- LIMITS (do not launder these away)
-- ----------------------------------
-- * The corpus assertions below say what is true in the frames we HOLD.  Our
--   batch games self-terminate on `economy_10min_cap` at ~640s, so "no frame is
--   past 18 minutes" is a property of the harness as much as of turbo.  Real
--   turbo games average ~20 min (CLAUDE.md), so `J.IsLateGame()` is reachable
--   in a tail we have never sampled.  What is NOT a sampling artefact is the
--   level column: level >= 20 is 0/940 hero-slots, and a hero cannot reach 20
--   in the last minute of a game whose median hero is level 10.
-- * The verdict column is a reading of intent, not a measurement.  It is pinned
--   here so that a future reader disagrees with it EXPLICITLY (by editing this
--   table) rather than by accident.  Nothing in bots/ is changed by this file
--   and no soak candidate is proposed: per GH #84 §5 a change needs a gate, a
--   real frame, and an assertion on the FINAL desire -- none of which is this
--   work unit.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- ---------------------------------------------------------------------------
-- The pinned census.  `op`/`n` are what the source literally says; `eff` is the
-- level a hero must actually reach (`> 24` needs 25).  `shape` is mechanical:
-- CONJ = the level test is an operand of an AND chain (or a standalone `if`
-- whose body is the branch), DISJ = it is one rung of an OR.
local GATES = {
    -- ---- generic files: these reach every hero, focus five included --------
    { file = 'bots/item_purchase_generic.lua', line = 228, op = '>=', n = 18, eff = 18,
      shape = 'CONJ', verdict = 'TEETH',
      text = 'if bot:GetLevel() >= 18',
      why = 'sole writer of the file-local `t3AlreadyDamaged`; with it shut the '
         .. 'buyback-gold reserve at :272 (cost = itemCost + GetBuybackCost() + nw/40 - 300) '
         .. 'is dead code for the whole game, and reserving for buyback when your own t3s '
         .. 'are falling is live turbo behaviour at level 12.' },

    { file = 'bots/mode_farm_generic.lua', line = 285, op = '>=', n = 18, eff = 18,
      shape = 'DISJ', verdict = 'TEETH',
      text = 'if bot:GetLevel() >= 18 or not J.IsCore(bot) then',
      why = 'GH #84 (乙). Supports keep the exit through `not J.IsCore(bot)`; a core\'s '
         .. 'ONLY door out of farm desire with a teamfight inside 2500 is the level term. '
         .. 'Note the standing warning: dropping farm desire is not the same as fighting -- '
         .. 'this row is a candidate, and it needs a final-desire assertion, not a reachability one.' },

    { file = 'bots/mode_farm_generic.lua', line = 369, op = '>=', n = 23, eff = 23,
      shape = 'DISJ', verdict = 'REDUNDANT',
      text = 'or (bot:GetLevel() >= 23 and nAlliesCount >= 3)',
      why = 'rung 2 of 3. It only loosens the grouped-allies count from 4 to 3; rung 1 '
         .. '(nAlliesCount >= 4) and rung 3 (GetRoshanDesire()) carry the same purpose live.' },

    { file = 'bots/mode_farm_generic.lua', line = 392, op = '>=', n = 15, eff = 15,
      shape = 'DISJ', verdict = 'TEETH',
      text = 'if #nNeutrals == 0 and #nDefendAllies >= 2 and (not beVeryHighFarmer or bot:GetLevel() >= 15 or J.IsLateGame()) then',
      why = 'for a `beVeryHighFarmer` the first rung is false by construction, so the '
         .. 'clause rests on level>=15 (3.3% of slots) OR J.IsLateGame() -- and IsLateGame '
         .. 'is DotaTime() > 18*60 in turbo, false in every frame of the archive. Both '
         .. 'fallbacks dead => the very-high farmer never joins a defence this way.' },

    { file = 'bots/mode_farm_generic.lua', line = 506, op = '>=', n = 18, eff = 18,
      shape = 'DISJ', verdict = 'TEETH',
      text = 'if not J.IsInLaningPhase() and (bCore or J.IsLateGame() or bot:GetLevel() >= 18) then',
      why = 'cores are covered by `bCore`; for a SUPPORT the remaining two rungs are the '
         .. 'dead pair (IsLateGame + level 18), so a support structurally never receives '
         .. 'the post-laning BOT_MODE_DESIRE_LOW farm floor. Whether that is wrong is a '
         .. 'design question -- what is pinned here is that no level-18 support decides it.' },

    { file = 'bots/mode_farm_generic.lua', line = 535, op = '>=', n = 15, eff = 15,
      shape = 'CONJ', verdict = 'TEETH',
      text = 'if not bot:IsInvisible() and bot:GetLevel() >= 15',
      why = 'the farm-mode runMode response block (enemy inside attack range, 2+ allies) '
         .. 'is a live turbo situation gated behind a 3.3% maturity proxy.' },

    { file = 'bots/ability_item_usage_generic.lua', line = 149, op = '>=', n = 30, eff = 30,
      shape = 'CONJ', verdict = 'INERT',
      text = 'if bot:GetLevel() >= 30',
      why = 'a bloodseeker-only opt-out at the level cap. The subject of the branch is a '
         .. 'level-30 hero; that hero does not exist in turbo, so nothing is lost.' },

    { file = 'bots/ability_item_usage_generic.lua', line = 582, op = '>', n = 24, eff = 25,
      shape = 'CONJ', verdict = 'INERT',
      text = 'if bot:GetLevel() > 24',
      why = 'buyback path 2 of 3. Inert on its own terms (a level-25 hero). See the '
         .. '[recorded] buyback test below: this path is unreachable for a SECOND, '
         .. 'independent reason, which is the part worth following up.' },

    { file = 'bots/ability_item_usage_generic.lua', line = 5749, op = '>=', n = 15, eff = 15,
      shape = 'CONJ', verdict = 'TEETH',
      text = 'if bot:GetLevel() >= 15',
      why = '"guard the ancient" TP: 5-way AND whose other four operands (no enemies near '
         .. 'me, ShouldTpToFarm, far from fountain, no ally already at the ancient) are all '
         .. 'live turbo states. The level term is the maturity proxy that shuts it.' },

    { file = 'bots/ability_item_usage_generic.lua', line = 5789, op = '>=', n = 15, eff = 15,
      shape = 'DISJ', verdict = 'REDUNDANT',
      text = 'and ( creep:GetAttackTarget() == nAncient or bot:GetLevel() >= 15 )',
      why = 'the sibling rung is the more specific and live predicate (a creep actually '
         .. 'attacking the ancient); the level rung only widens it.' },

    { file = 'bots/FunLib/aba_site.lua', line = 760, op = '>=', n = 20, eff = 20,
      shape = 'CONJ', verdict = 'INERT',
      text = 'if bot:GetLevel() >= 20 and allyCount <= 1 and botNetWorth < 21000 then',
      why = 'named 合取(有牙齿) in GH #84 §3(甲); reads INERT here. The row\'s subject is a '
         .. 'level-20 bristleback, which does not exist in turbo. The live row above it '
         .. '(:757, level >= 10) and the caller\'s pos<=3 fallback ladder (:617-625, whose '
         .. 'rungs are level < 10 / < 15 / < 20) already answer the sub-20 world. '
         .. 'It does reach a FOCUS hero -- skeleton_king delegates here (:1001) -- which is '
         .. 'why the row was worth reading rather than waving through.' },

    { file = 'bots/FunLib/aba_site.lua', line = 824, op = '>', n = 20, eff = 21,
      shape = 'CONJ', verdict = 'INERT',
      text = 'if bot:GetLevel() > 20 and botNetWorth < 23333 then',
      why = 'same shape, huskar\'s entry (luna delegates here at :853). Subject is a '
         .. 'level-21 hero; the three rows above it are net-worth-only and live.' },

    -- ---- hero files: not focus heroes, classified for completeness ---------
    { file = 'bots/BotLib/hero_medusa.lua', line = 495, op = '>=', n = 20, eff = 20,
      shape = 'DISJ', verdict = 'REDUNDANT',
      text = 'if bot:GetLevel() >= 20 or J.GetMP( bot ) > 0.88 then nShouldAoeCount = 3 end',
      why = 'the mana sibling is live and carries the same relaxation.' },

    { file = 'bots/BotLib/hero_morphling.lua', line = 985, op = '>=', n = 26, eff = 26,
      shape = 'DISJ', verdict = 'INERT', text = 'if bot:GetLevel() >= 26 then count = 7',
      why = 'rung of the innate stat ladder (:984 seeds count = 0). All seven rungs are '
         .. 'above the turbo ceiling, so `count` stays 0 -- which is the correct estimate '
         .. 'for a sub-17 morphling. The consumer at :998-1004 is live.' },
    { file = 'bots/BotLib/hero_morphling.lua', line = 986, op = '>=', n = 24, eff = 24,
      shape = 'DISJ', verdict = 'INERT', text = 'elseif bot:GetLevel() >= 24 then count = 6',
      why = 'same ladder.' },
    { file = 'bots/BotLib/hero_morphling.lua', line = 987, op = '>=', n = 23, eff = 23,
      shape = 'DISJ', verdict = 'INERT', text = 'elseif bot:GetLevel() >= 23 then count = 5',
      why = 'same ladder.' },
    { file = 'bots/BotLib/hero_morphling.lua', line = 988, op = '>=', n = 22, eff = 22,
      shape = 'DISJ', verdict = 'INERT', text = 'elseif bot:GetLevel() >= 22 then count = 4',
      why = 'same ladder.' },
    { file = 'bots/BotLib/hero_morphling.lua', line = 989, op = '>=', n = 21, eff = 21,
      shape = 'DISJ', verdict = 'INERT', text = 'elseif bot:GetLevel() >= 21 then count = 3',
      why = 'same ladder.' },
    { file = 'bots/BotLib/hero_morphling.lua', line = 990, op = '>=', n = 19, eff = 19,
      shape = 'DISJ', verdict = 'INERT', text = 'elseif bot:GetLevel() >= 19 then count = 2',
      why = 'same ladder. This is the only rung the archive comes within reach of '
         .. '(one hero-slot at level 19 in 940).' },
    { file = 'bots/BotLib/hero_morphling.lua', line = 991, op = '>=', n = 17, eff = 17,
      shape = 'DISJ', verdict = 'INERT', text = 'elseif bot:GetLevel() >= 17 then count = 1',
      why = 'same ladder.' },

    { file = 'bots/BotLib/hero_necrolyte.lua', line = 382, op = '>', n = 24, eff = 25,
      shape = 'DISJ', verdict = 'REDUNDANT',
      text = 'or ( nCanHurtCount >= 2 and nCanKillCount >= 1 and bot:GetLevel() > 24 and #tableNearbyEnemyCreeps == 2 )',
      why = 'rung 6 of 6; the five rungs above it are live and strictly easier to satisfy.' },

    { file = 'bots/BotLib/hero_necrolyte.lua', line = 587, op = '>=', n = 18, eff = 18,
      shape = 'CONJ', verdict = 'INERT',
      text = 'if bot:GetLevel() >= 18 then EstDamage = EstDamage + targetMaxHealth * 0.016 end',
      why = 'an additive term modelling the level-3 ultimate. Below 18 the term should NOT '
         .. 'be added, so its absence is the correct answer, not a lost behaviour.' },
}

local GENERIC_PREFIXES = { 'bots/mode_', 'bots/ability_item_usage_', 'bots/item_purchase_',
                           'bots/FunLib/' }

local function is_generic(file)
    if file:match('^bots/BotLib/') then return false end
    for _, p in ipairs(GENERIC_PREFIXES) do
        if file:sub(1, #p) == p then return true end
    end
    return false
end

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end

--- Every `GetLevel() >=|> N` site in bots/ with an effective threshold >= 15,
--- read straight off the shipped source.  Keyed 'file:line'.
local function scan_source()
    local found = {}
    local p = assert(io.popen('find bots -name "*.lua" | sort'))
    for file in p:lines() do
        local n = 0
        for line in io.lines(file) do
            n = n + 1
            for op, num in line:gmatch('GetLevel%(%)%s*(>=?)%s*(%d+)') do
                local eff = tonumber(num)
                if op == '>' then eff = eff + 1 end
                if eff >= 15 then
                    found[file .. ':' .. n] = { op = op, n = tonumber(num), eff = eff,
                                                text = trim(line) }
                end
            end
        end
    end
    p:close()
    return found
end

--- Levels of every hero-slot in every fixture, plus the frame clock.
local function scan_corpus()
    local out = { fixtures = 0, slots = 0, max_level = 0, ge15 = 0, ge18 = 0, ge20 = 0,
                  max_t = 0, frames_past_18min = 0, games = {} }
    local p = assert(io.popen('ls tests/fixtures'))
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then
            local fx = dofile('tests/fixtures/' .. f)
            out.fixtures = out.fixtures + 1
            out.games[tostring(fx.game)] = true
            if fx.time > out.max_t then out.max_t = fx.time end
            if fx.time > 18 * 60 then out.frames_past_18min = out.frames_past_18min + 1 end
            for _, u in ipairs(fx.units) do
                if u.name:match('^npc_dota_hero_') then
                    out.slots = out.slots + 1
                    local lv = u.level or 0
                    if lv > out.max_level then out.max_level = lv end
                    if lv >= 15 then out.ge15 = out.ge15 + 1 end
                    if lv >= 18 then out.ge18 = out.ge18 + 1 end
                    if lv >= 20 then out.ge20 = out.ge20 + 1 end
                end
            end
        end
    end
    p:close()
    return out
end

local function read_file(path)
    local fh = assert(io.open(path, 'r'))
    local s = fh:read('*a')
    fh:close()
    return s
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The census itself: the pinned table and the shipped source must agree in
--    BOTH directions.  A new gate, a deleted gate or a moved line trips this.

tests['[census] the pinned set is exactly the set bots/ ships'] = function()
    local found = scan_source()
    local pinned = {}
    for _, g in ipairs(GATES) do pinned[g.file .. ':' .. g.line] = g end

    for key, src in pairs(found) do
        local g = pinned[key]
        assert(g ~= nil, 'unpinned GetLevel gate at ' .. key .. ' (' .. src.text .. ') -- '
            .. 'classify it in GATES (GH #84 甲) before shipping it')
        assert(g.op == src.op and g.n == src.n,
            key .. ': pinned ' .. g.op .. ' ' .. g.n .. ' but source reads '
            .. src.op .. ' ' .. src.n)
    end
    for key in pairs(pinned) do
        assert(found[key] ~= nil, 'pinned gate ' .. key .. ' is gone from bots/ -- '
            .. 'delete its GATES row and re-read the verdict it carried')
    end
end

tests['[census] 22 gates at N >= 15, 12 of them in generic files'] = function()
    assert(#GATES == 22, 'expected 22 pinned gates, got ' .. #GATES)
    local generic = 0
    for _, g in ipairs(GATES) do if is_generic(g.file) then generic = generic + 1 end end
    assert(generic == 12, 'expected 12 generic-file gates, got ' .. generic)
end

tests['[census] 12 of the 22 sit at an effective threshold >= 20'] = function()
    local ge20 = 0
    for _, g in ipairs(GATES) do if g.eff >= 20 then ge20 = ge20 + 1 end end
    assert(ge20 == 12, 'expected 12 gates at N >= 20, got ' .. ge20)
end

tests['[census] each pinned row still reads the text it was classified from'] = function()
    local found = scan_source()
    for _, g in ipairs(GATES) do
        local src = found[g.file .. ':' .. g.line]
        assert(src ~= nil, 'missing source for ' .. g.file .. ':' .. g.line)
        assert(src.text == g.text, g.file .. ':' .. g.line
            .. '\n  pinned: ' .. g.text .. '\n  source: ' .. src.text
            .. '\n  the line changed -- re-read the verdict, do not just update the string')
    end
end

-- ---------------------------------------------------------------------------
-- 2. The headline of the classification (GH #84 甲).

tests['[classification] the teeth do not line up with the AND/OR split'] = function()
    local teeth, conj_teeth, disj_teeth = 0, 0, 0
    for _, g in ipairs(GATES) do
        if g.verdict == 'TEETH' then
            teeth = teeth + 1
            if g.shape == 'CONJ' then conj_teeth = conj_teeth + 1 else disj_teeth = disj_teeth + 1 end
        end
    end
    assert(teeth == 6, 'expected 6 rows with teeth, got ' .. teeth)
    assert(conj_teeth == 3 and disj_teeth == 3,
        'the point of this row: teeth split 3 CONJ / 3 DISJ, got '
        .. conj_teeth .. ' / ' .. disj_teeth
        .. ' -- if this ever becomes lopsided the shape may after all be predictive, say so')
    -- every one of them is in a generic file, i.e. reaches the focus five
    for _, g in ipairs(GATES) do
        if g.verdict == 'TEETH' then
            assert(is_generic(g.file), g.file .. ' has teeth but is not a generic file')
        end
    end
end

tests['[classification] "CONJ and N >= 20" selects 4 rows and all 4 are INERT'] = function()
    local sel, inert = 0, 0
    for _, g in ipairs(GATES) do
        if g.shape == 'CONJ' and g.eff >= 20 then
            sel = sel + 1
            if g.verdict == 'INERT' then inert = inert + 1 end
        end
    end
    assert(sel == 4, 'expected 4 rows matching the GH #84 §5 filter, got ' .. sel)
    assert(inert == 4, 'the filter proposed in GH #84 §5 selects only inert rows; '
        .. 'got ' .. inert .. '/4 inert -- if that changes, the filter is worth re-reading')
end

tests['[classification] every row with teeth sits at N = 15 or N = 18'] = function()
    for _, g in ipairs(GATES) do
        if g.verdict == 'TEETH' then
            assert(g.eff == 15 or g.eff == 18, g.file .. ':' .. g.line
                .. ' has teeth at N = ' .. g.eff .. ' -- the "look at N >= 20" heuristic '
                .. 'would now find something; re-read the §5 acceptance criterion')
        end
    end
end

tests['[classification] the 22 verdicts total 6 TEETH / 12 INERT / 4 REDUNDANT'] = function()
    local tally = { TEETH = 0, INERT = 0, REDUNDANT = 0 }
    for _, g in ipairs(GATES) do
        assert(tally[g.verdict] ~= nil, 'unknown verdict ' .. tostring(g.verdict))
        tally[g.verdict] = tally[g.verdict] + 1
    end
    assert(tally.TEETH == 6 and tally.INERT == 12 and tally.REDUNDANT == 4,
        string.format('verdict tally moved: %d TEETH / %d INERT / %d REDUNDANT',
            tally.TEETH, tally.INERT, tally.REDUNDANT))
end

-- ---------------------------------------------------------------------------
-- 3. The real-frame side.  These are the measurements the verdicts rest on.

tests['[corpus] 94 fixtures / 67 games / 940 hero-slots: level >= 20 is 0'] = function()
    local c = scan_corpus()
    local games = 0
    for _ in pairs(c.games) do games = games + 1 end
    assert(c.fixtures == 94, 'fixture count moved to ' .. c.fixtures
        .. ' -- re-run tools/agent/fixture_level_census.py and re-read GH #84 §1')
    assert(games == 67, 'distinct games moved to ' .. games)
    assert(c.slots == 940, 'hero-slots moved to ' .. c.slots)
    assert(c.ge20 == 0, c.ge20 .. ' hero-slot(s) now reach level 20 -- the four INERT '
        .. 'verdicts above were argued from "that hero does not exist"; re-read them')
    assert(c.max_level == 19, 'archive high-water level moved to ' .. c.max_level)
    assert(c.ge18 == 1, 'slots at level >= 18 moved to ' .. c.ge18)
    assert(c.ge15 == 8, 'slots at level >= 15 moved to ' .. c.ge15)
end

tests['[corpus] the archive never reaches turbo late game (the 392/506 fallback)'] = function()
    local c = scan_corpus()
    assert(c.max_t == 690.5, 'latest frame moved to t = ' .. c.max_t)
    assert(c.frames_past_18min == 0, c.frames_past_18min .. ' frame(s) are now past '
        .. '18:00 -- J.IsLateGame() is no longer vacuous, so the TEETH verdicts on '
        .. 'mode_farm_generic:392 and :506 must be re-read')
    -- and the same thing said by running the real helper on the latest frame we own
    local J = rf.load('tests/fixtures/f_260820_043140_luna_ring_bid.lua')
    assert(J.IsModeTurbo() == true, 'fixture loader must report turbo')
    assert(J.IsLateGame() == false,
        'the latest frame in the archive (t=690.5) reports late game -- re-read 392/506')
end

-- ---------------------------------------------------------------------------
-- 4. [reverse] source nails: the specific facts each contested verdict rests
--    on.  If one of these moves, the verdict is wrong, not merely stale.

tests['[reverse] J.IsLateGame is the 18-minute turbo constant'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    assert(src:find('function J.IsLateGame()', 1, true),
        'J.IsLateGame is gone -- 392/506 were classified through it')
    assert(src:find('DotaTime() > (J.IsModeTurbo() and 18 * 60 or 30 * 60)', 1, true),
        'the turbo late-game constant moved; re-read mode_farm_generic:392 and :506')
end

tests['[reverse] 392 and 506 really do name IsLateGame as their fallback'] = function()
    local src = read_file('bots/mode_farm_generic.lua')
    assert(src:find('not beVeryHighFarmer or bot:GetLevel() >= 15 or J.IsLateGame()', 1, true),
        ':392 no longer reads as classified')
    assert(src:find('if not J.IsInLaningPhase() and (bCore or J.IsLateGame() or bot:GetLevel() >= 18) then', 1, true),
        ':506 no longer reads as classified')
end

tests['[reverse] aba_site 760 is dead code a FOCUS hero routes into'] = function()
    local src = read_file('bots/FunLib/aba_site.lua')
    -- Wraith King delegates into the bristleback body that owns the level-20 row.
    assert(src:find('____exports.ConsiderIsTimeToFarm.npc_dota_hero_skeleton_king = function()', 1, true),
        'skeleton_king lost its ConsiderIsTimeToFarm entry')
    local wk = src:match('ConsiderIsTimeToFarm%.npc_dota_hero_skeleton_king = function%(%)(.-)\nend')
    assert(wk ~= nil and wk:find('ConsiderIsTimeToFarm.npc_dota_hero_bristleback()', 1, true),
        'skeleton_king no longer delegates to bristleback -- the "generic file reaches the '
        .. 'focus five" claim for aba_site:760 went through this one edge')
    -- luna (candidate pool) reaches :824 the same way, through huskar.
    local luna = src:match('ConsiderIsTimeToFarm%.npc_dota_hero_luna = function%(%)(.-)\nend')
    assert(luna ~= nil and luna:find('ConsiderIsTimeToFarm.npc_dota_hero_huskar()', 1, true),
        'luna no longer delegates to huskar')
    -- and the live sub-20 answer the INERT verdict leans on
    assert(src:find('if bot:GetLevel() >= 10 and allyCount <= 2 and botNetWorth < 15000 then', 1, true),
        'the live level-10 row above :760 is gone; :760 may no longer be inert')
    assert(src:find('if botLvl < 20 and botNetWorth < 16000 then', 1, true),
        'the caller\'s pos<=3 sub-20 fallback ladder moved; re-read :760 and :824')
end

tests['[reverse] item_purchase: the level-18 block is the only writer of t3AlreadyDamaged'] = function()
    local writers = 0
    local n, in_block = 0, false
    for line in io.lines('bots/item_purchase_generic.lua') do
        n = n + 1
        if n == 228 then in_block = true end
        if n > 228 and line:find('elseif t3AlreadyDamaged == true', 1, true) then in_block = false end
        if line:find('t3AlreadyDamaged = ', 1, true) and n ~= 62 then
            writers = writers + 1
            assert(in_block, 'a t3AlreadyDamaged write escaped the level-18 block at line '
                .. n .. ' -- the TEETH verdict on :228 assumed it could not')
        end
    end
    assert(writers == 4, 'expected 4 writes inside the block, found ' .. writers)
end

-- ---------------------------------------------------------------------------
-- 5. [recorded] a by-product, kept as a ledger entry, NOT acted on here.
--    The gate at aiug:582 is inert on its own terms, but it turned out to be
--    the second of three buyback paths and none of the three can fire in a
--    turbo game of the length we play.  This is a separate lever and needs its
--    own frame evidence before anyone touches it (one lever at a time).

tests['[recorded] all three automatic buyback paths are shut in turbo'] = function()
    local src = read_file('bots/ability_item_usage_generic.lua')
    local n = 0
    for _ in src:gmatch('ActionImmediate_Buyback') do n = n + 1 end
    assert(n == 3, 'buyback call sites moved from 3 to ' .. n)
    -- path 1: guarded by a units mismatch -- the ancient's HP is thousands, and
    -- this compares it to 0.8 as if it were a fraction (J.GetHP would be the
    -- fractional read). Recorded, not fixed: it is not this work unit's lever.
    assert(src:find('if ancient ~= nil and ancient:GetHealth() < 0.8 then', 1, true),
        'buyback path 1 changed -- re-read the units observation in GH #84 follow-up')
    -- paths 2 and 3 both sit below this early return.
    assert(src:find('if nFullRespawnTime < 60 then', 1, true),
        'the respawn-time floor above buyback paths 2/3 moved')
    assert(src:find('if bot:GetLevel() > 24', 1, true), 'buyback path 2 gate moved')
    -- INFERENCE, stated as one: turbo halves respawn time and our games end with
    -- a median hero at level 10, so `bot:GetRespawnTime() >= 60` is not a state
    -- we believe occurs. The harness cannot decide this -- GetRespawnTime is not
    -- in the dump -- so it is recorded as a claim to be checked in-game or by a
    -- dumper field, never asserted as measured.
    assert(true)
end

return tests

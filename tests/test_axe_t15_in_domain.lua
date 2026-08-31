-- [ratchet] [hero] Axe t15, taken IN DOMAIN for the first time.
--
-- Pays row 6 of GH #357's reopen list -- "Axe t15 finally measurable IN
-- domain", the first of that issue's three real re-decisions to be paid.
-- Sister file: tests/test_axe_t15_payoff.lua, which adjudicated the pair
-- (VERDICT: [3] +8 Battle Hunger dps, re-taken 2026-08-23 and 2026-08-28) and
-- whose single load-bearing HONEST BOUND was:
--
--     NO FRAME IN THIS CORPUS IS IN DOMAIN.  The highest level any Axe reaches
--     in a fixture is 14; a t15 talent exists at 15.  Everything above is a
--     PROXY measured one level below the talent, and it is pinned as such.
--
-- That bound is now RETIRABLE, and this file is where it is retired -- on a
-- real frame with a real Axe at level 21, not by relaxing the ratchet that
-- states it.  The corpus statement itself stays TRUE and its ratchet stays
-- byte-identical: tests/fixtures/ still tops out at Axe level 14.  What changed
-- is that a frame OUTSIDE the corpus can now answer the question.
--
--     tests/frames/f_20260831_004433_cm_creepreach.lua
--     69e067 / 20260831_004433_slot1, t = 1190.4 (19:50)
--     npc_dota_hero_axe, team 2, level 21, ALIVE
--
-- WHY BY NAME AND NOT THROUGH THE GLOB.  tests/fixtures/ is also the CENSUS
-- CORPUS (see tests/frames/README.md and GH #357): about two dozen tests glob
-- it and take readings over everything they find.  Admitting this frame turns
-- nine of those readings red, three of them real re-decisions belonging to
-- three different levers.  This file loads the frame BY NAME, so it pays
-- exactly one of those three and moves NONE of the nine.  The other two (the
-- Black King Bar zero behind test_axe_cull_immune_veto, and the Alchemist
-- objective-clock band) are still open and still owed.
--
-- ===========================================================================
-- THE READING, AND THE VERDICT IT DOES NOT MOVE
-- ===========================================================================
--
-- (1) IN DOMAIN.  Axe at level 21 >= 15.  The t15 choice exists on this hero at
--     this instant; nothing below is a proxy.
--
-- (2) THE OBSERVED RANK PAIR IS Call 3 / Battle Hunger 4 -- which is exactly the
--     pair test_axe_t15_payoff.lua computed its structural ceilings on, and the
--     ratio those ceilings carry (Hunger can be live ~5x as much of the game as
--     Call) is therefore corroborated ON A REAL FRAME rather than only derived.
--     It even holds LONGER than that file assumed: the shipped build row puts
--     Call's fourth point at level 16, so the file's own arithmetic expected
--     Call rank 4 -- and hence the smaller 4x ratio -- from level 16 onward.
--     The observed level-21 Axe is still at rank 3.
--
-- (3) ⚠️ AND THAT IS NOT A WIN, BECAUSE THE REASON IS NOT THE ONE IT LOOKS LIKE.
--     The pair did not hold because the build row held.  The observed Axe has
--     THIRTEEN ability points down at level 21, where the engine offers 18 and
--     the shipped row would have spent 15 by level 17.  Thirteen is precisely
--     the level-15 build state -- the same 13 that file's CORRECTED note names
--     ("only THIRTEEN ability points are down when the t15 choice is made").
--     And it is not Axe's alone: of the nine heroes on this frame at level >= 18,
--     NINE have their ultimate still at rank 2 where the 6/12/18 ladder allows 3
--     -- ten different hero scripts, both teams.  (Crystal Maiden, level 17 and
--     correctly at rank 2, is the control that shows the reader separates the
--     two cases.)  So the in-domain corroboration in (2) is real, and its cause
--     is a SEPARATE defect that this file pins and hands off rather than absorbs.
--     Reading it as "the build row is working" would be a matching conclusion
--     standing in for a correct reason.  The row is not being DISOBEYED either:
--     it puts Battle Hunger's 4th point at ability point 10 and Berserker's
--     Call's at 14, so 13 points spent predicts the observed 3/4 exactly.  The
--     row is being followed by a hero who stopped spending.
--     LIMIT, load-bearing: ten units, ONE game, one instant.  That is a
--     POINTER, not a frequency -- ten hero-slots of a single match are as
--     correlated as samples get, and no second in-domain game exists yet.
--
--     ⚠️ NEAR-MISS WORTH KEEPING, because the reader nearly measured itself.
--     The first version of the ten-hero case summed every dumped ability rank
--     and subtracted a HAND-WRITTEN LIST of six facet names.  Run over the 855
--     hero-units of the 108 generated fixtures, that reader called 359 of them
--     (42%) impossible -- more points spent than their level allows -- because
--     the archive carries many more facets than the list named
--     (earthshaker_slugger, phantom_assassin_immaterial, centaur_horsepower,
--     slardar_slardar_seaborn_sentinel, ...).  A name list over an open set is
--     not a classifier.  The 42% is what caught it: the reading it produced for
--     Axe was RIGHT (Axe has no facet), so the conclusion would have survived
--     review while resting on a reader that was wrong for two units in five.
--     Same family as the k=4 / 829.4 hand-arithmetic misses of the last week.
--
--     ⚠️ SECOND NEAR-MISS, and this one was a settled question.  The first draft
--     also asserted a SOURCE half: "the build row is 15 entries long, the driven
--     skill list ends at hero level 17, so a bot reaches 25 with 6 points and 2
--     talents unspent."  That is GH #238 section 5, which drove the same
--     function and ruled it 看着错,其实是对的 -- the list is indexed by the Nth
--     POINT SPENT, not by hero level, so positions 18/19 are levels 20/25 and
--     nothing is stranded.  The draft's "list ends at 17" was reading the MOCK's
--     talent list (which resolves talent names to nil) as if it were the shipped
--     one.  It would have re-opened a closed ruling, in the wrong direction,
--     from a test that was green.  The node is deleted rather than weakened, and
--     section 3 now asks its question in ability points -- the indexing #238
--     established -- so the same confusion cannot come back through it.
--
-- (4) THE FRAME IS DRY, so it could not have moved the verdict even if it were
--     admitted.  Neither modifier is live on it: no enemy carries
--     modifier_axe_battle_hunger, and Axe does not carry
--     modifier_axe_berserkers_call_armor.  (Axe does carry
--     modifier_axe_battle_hunger_self_movespeed, which is his OWN buff, not the
--     debuff the uptime reading counts.)  It adds ceiling and no observation --
--     the same shape as the two venomancer frames of GH #274.
--
-- (5) SO ROW 6 OF #357, PAID: **VERDICT UNCHANGED.**  Admitting this frame to
--     the corpus would move the counters to axe_frames 28 -> 29, call_ceiling
--     2.33 -> 2.52, hunger_ceiling 16 -> 17, with call_live and hunger_live
--     unmoved at 1 and 5.  The direction test that file pins its health reading
--     on -- call_live * hunger_ceiling > hunger_live * call_ceiling -- then
--     reads 17.00 > 12.61 and still holds.  This is computed below rather than
--     asserted from prose, so it moves when the corpus does.
--
-- ===========================================================================
-- THE BOUND THAT REPLACES "OUT OF DOMAIN" -- strictly narrower, still real
-- ===========================================================================
--
-- Being in domain upgrades the RANK and UPTIME readings.  It does NOT let the
-- corpus confirm WHICH TALENT WAS TAKEN, and that limit is now the binding one:
--
--   * The dump carries AT MOST ONE special_bonus_* entry per hero -- max = 1
--     over all 1,080 hero-units in the archive, including level-22 heroes who
--     must have three talents down.  So a hero's talent list is never complete
--     and a missing talent is never evidence of a talent not taken.
--   * Axe carries ZERO on all 29 of its frames, the in-domain one included.
--
-- Which means: the t15 VERDICT of the sister file rests, as it always did, on
-- reachability arithmetic plus the build row -- and this file establishes that
-- no frame in this archive has ever observed an Axe's t15 pick, rather than
-- leaving that as "we did not look".  Retiring "no frame is in domain" without
-- putting this in its place would read as a strengthening of the evidence when
-- the evidence for the CHOICE did not move at all.
--
-- ===========================================================================
-- WHAT THIS FILE DOES NOT DO
-- ===========================================================================
-- Zero lines of bots/ or game/.  No gate id, no arm, no promote, no AWS, no
-- wave request.  The ability-point gap of (3) is written up and handed off; it
-- is a different lever from t15 and answering it here, in the same work unit,
-- is the shape AGENTS.md's lanefix lesson warns about.

package.path = 'tests/?.lua;' .. package.path
local skillmap = require('skill_level_map')

local FRAME = 'tests/frames/f_20260831_004433_cm_creepreach.lua'
local HERO_SRC = 'bots/BotLib/hero_axe.lua'
local TALENT_LEVEL = 15

-- datafeed hero_id=2, 2026-08-23 -- the same anchors the sister file reads, so
-- the two ceilings below are computed with one set of numbers, not two.
local CALL = {
    cooldown = { 18, 16, 14, 12 },
    duration = { 2.1, 2.4, 2.7, 3.0 },
}
local HUNGER = {
    cooldown = { 20, 15, 10, 5 },
    duration = { 12, 12, 12, 12 },
}

-- What the corpus counters stood at before this frame, from
-- tests/test_axe_t15_payoff.lua's own pinned reading (GH #274 re-take).
local BEFORE = {
    axe_frames = 28,
    call_ceiling = 2.33,
    hunger_ceiling = 16.00,
    call_live = 1,
    hunger_live = 5,
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function ceiling(spec, rank)
    if rank == 0 then return 0 end
    local up = spec.duration[rank] / spec.cooldown[rank]
    return (up > 1) and 1 or up
end

local function has_modifier(unit, sName)
    for _, m in ipairs(unit.modifiers or {}) do
        if m.name == sName then return m end
    end
    return nil
end

local function ability_rank(unit, sName)
    for _, a in ipairs(unit.abilities or {}) do
        if a.name == sName then return a.level or 0 end
    end
    return 0
end

--- Ability points a unit has spent, summed over its dumped ability ranks.
---
--- ⚠️ ONLY SOUND FOR A HERO WITH NO INNATE/FACET ABILITY IN THE DUMP, which is
--- why every caller below asserts that first.  Innates and facets are granted at
--- rank 1 without costing a point, so summing all entries over-counts by one per
--- facet -- and the first version of this file did exactly that with a
--- hand-written list of facet names.  Measured: on the 855 hero-units of the 108
--- GENERATED fixtures, that reader called 359 of them (42%) IMPOSSIBLE -- more
--- points spent than their level allows -- because the list named six facets and
--- the archive has many more (earthshaker_slugger, phantom_assassin_immaterial,
--- slardar_slardar_seaborn_sentinel, centaur_horsepower, ...).  A name list over
--- an open set is not a classifier.  Axe happens to be safe because the dump
--- gives him exactly four entries and no facet; the ten-hero reading below
--- therefore does NOT use this function at all, it reads one ultimate rank per
--- hero, which no facet can perturb.
local function points_spent(unit)
    for _, a in ipairs(unit.abilities or {}) do
        assert(not a.name:match('innate'),
            unit.name .. ' now carries the innate/facet entry ' .. a.name
            .. ', so summing its ability ranks over-counts the points it spent. '
            .. 'Use the ultimate-rank reader instead, as the ten-hero case does.')
    end
    local n = 0
    for _, a in ipairs(unit.abilities or {}) do
        if not a.name:match('^special_bonus') then n = n + (a.level or 0) end
    end
    return n
end

--- The ultimate of each hero on this frame, and the rank the engine allows at a
--- level.  Ultimates rank at 6 / 12 / 18, so this reads ONE field per hero and
--- is immune to the facet-counting problem above.  Crystal Maiden is the control:
--- she is level 17 and correctly at rank 2, so a reader that simply answered
--- "everyone is at 2" would not separate her from the nine that are short.
local ULTIMATE = {
    axe = 'axe_culling_blade',
    crystal_maiden = 'crystal_maiden_freezing_field',
    lina = 'lina_laguna_blade',
    lion = 'lion_finger_of_death',
    necrolyte = 'necrolyte_reapers_scythe',
    shadow_shaman = 'shadow_shaman_mass_serpent_ward',
    skeleton_king = 'skeleton_king_reincarnation',
    skywrath_mage = 'skywrath_mage_mystic_flare',
    sven = 'sven_gods_strength',
    zuus = 'zuus_thundergods_wrath',
}

local function ult_rank_allowed(nLevel)
    if nLevel >= 18 then return 3 elseif nLevel >= 12 then return 2
    elseif nLevel >= 6 then return 1 else return 0 end
end

--- Ability points the ENGINE offers at a hero level: one per level, minus the
--- levels spent on talents (10, 15, 20, 25).
local function points_available(nLevel)
    local n = nLevel
    for _, t in ipairs({ 10, 15, 20, 25 }) do
        if nLevel >= t then n = n - 1 end
    end
    return n
end

local function corpus_paths()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files['tests/fixtures/' .. f] = true end
    end
    p:close()
    -- The staged frame counts once whether or not it has been admitted, so the
    -- talent-surface reading below does not shift the day somebody moves it.
    files[FRAME] = true
    local out = {}
    for k in pairs(files) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local FX = dofile(FRAME)
local AXE
for _, u in ipairs(FX.units or {}) do
    if u.name == 'npc_dota_hero_axe' then AXE = u end
end

-- ---------------------------------------------------------------------------
-- 1. The frame is where this file thinks it is, and is NOT in the corpus glob.

tests['[hero] axe t15 in-domain: the frame is staged, not admitted'] = function()
    assert(AXE ~= nil, FRAME .. ' no longer carries an npc_dota_hero_axe unit, so '
        .. 'every reading in this file is about a hero that is not there.')
    local fh = io.open('tests/fixtures/f_20260831_004433_cm_creepreach.lua', 'r')
    if fh ~= nil then
        fh:close()
        error('the staged frame has been ADMITTED to tests/fixtures/.  That is a '
            .. 'legitimate decision, but it is the one GH #357 says costs the '
            .. 'whole reopen list -- and only row 6 (this file) has been paid. '
            .. 'Pay the Black King Bar zero (test_axe_cull_immune_veto) and the '
            .. 'Alchemist objective-clock band before leaving it there.')
    end
end

-- ---------------------------------------------------------------------------
-- 2. In domain at last.

tests['[hero] axe t15 in-domain: a real Axe is finally at level >= 15'] = function()
    assert(AXE.alive == true,
        'the in-domain Axe is dead on this frame.  A dead unit carries no live '
        .. 'modifiers, so the uptime half of this reading would be vacuous rather '
        .. 'than observed-zero, and section 4 must not be read as DRY.')
    assert((AXE.level or 0) >= TALENT_LEVEL,
        'the staged frame Axe is level ' .. tostring(AXE.level) .. ', below '
        .. TALENT_LEVEL .. '.  This whole file exists because it was 21; if the '
        .. 'frame was regenerated and lost that, the sister file\'s OUT OF DOMAIN '
        .. 'bound is NOT retired and has to go back to being load-bearing.')
    assert(AXE.level == 21,
        'the in-domain Axe is now level ' .. tostring(AXE.level) .. ', not 21. '
        .. 'Every arithmetic statement below names 21 explicitly; re-take them.')
end

-- ---------------------------------------------------------------------------
-- 3. The observed rank pair, against what the shipped build row predicts.

tests['[hero] axe t15 in-domain: observed Call 3 / Hunger 4 at level 21'] = function()
    local nCall = ability_rank(AXE, 'axe_berserkers_call')
    local nHunger = ability_rank(AXE, 'axe_battle_hunger')
    assert(nCall == 3, 'in-domain Berserker\'s Call rank is ' .. nCall .. ', not 3.')
    assert(nHunger == 4, 'in-domain Battle Hunger rank is ' .. nHunger .. ', not 4.')

    -- WHY THAT PAIR, read off the shipped row in ABILITY POINTS SPENT rather
    -- than in hero levels.  This is the axis GH #238 section 5 settled: the
    -- skill list is indexed by the Nth point spent, and its consumer reads it
    -- that way (`nPointsSpent = botLevel - bot:GetAbilityPoints()`).  Asking
    -- "what rank at hero level 21" instead would put the question past the end
    -- of the list, where the two indexings stop agreeing and the answer would be
    -- an artifact of which one this file happened to assume.
    local src = read_file(HERO_SRC)
    local slot = skillmap.ability_slots(src)
    local ladder = skillmap.rank_ladder('npc_dota_hero_axe',
        skillmap.build_row(src), skillmap.talent_rows(src))
    local function point_of(nPos)
        local n = 0
        for i = 1, nPos do if i ~= 10 and i ~= 15 then n = n + 1 end end
        return n
    end
    local nCallR4 = point_of((ladder[slot.abilityQ] or {})[4] or 0)
    local nHungerR4 = point_of((ladder[slot.abilityW] or {})[4] or 0)

    assert(nCallR4 == 14,
        'the shipped row now puts Berserker\'s Call rank 4 at ability point '
        .. nCallR4 .. ', not the 14th.  The row moved; re-take the comparison.')
    assert(nHungerR4 == 10,
        'the shipped row now puts Battle Hunger rank 4 at ability point '
        .. nHungerR4 .. ', not the 10th.')

    -- The observed pair is EXACTLY what 13 points spent predicts: past Hunger's
    -- 10th, one short of Call's 14th.  So the row is not being disobeyed -- it is
    -- being followed by a hero who stopped spending, which is section 4.
    local nSpent = points_spent(AXE)
    assert(nSpent >= nHungerR4 and nSpent < nCallR4,
        'the in-domain Axe has ' .. nSpent .. ' ability points, which no longer '
        .. 'falls between Battle Hunger\'s 4th point (' .. nHungerR4 .. ') and '
        .. 'Berserker\'s Call\'s (' .. nCallR4 .. ').  The observed 3/4 pair is '
        .. 'then NOT explained by the point count, and section 4\'s causal story '
        .. 'has to be re-derived rather than restated.')
end

-- ---------------------------------------------------------------------------
-- 4. Why it held: the whole game is stalled at the level-15 build.  ⚠️ POINTER.

tests['[hero] axe t15 in-domain: 13 ability points at level 21'] = function()
    local nSpent = points_spent(AXE)
    local nAvail = points_available(AXE.level)
    assert(nSpent == 13,
        'the in-domain Axe now reports ' .. nSpent .. ' ability points, not 13. '
        .. 'Thirteen is the level-15 build state, and "he is still standing on '
        .. 'it at level 21" is the reason his rank pair matched the t15 pair. '
        .. 'A different number means the corroboration in section 3 has a '
        .. 'different cause and has to be re-read.')
    assert(nAvail == 18, 'level 21 offers ' .. nAvail .. ' ability points, not 18.')
    assert(nSpent < nAvail,
        'the in-domain Axe has now spent every point available to him.  Good -- '
        .. 'but then section 3\'s rank pair is NOT explained by a stalled build, '
        .. 'and the sister file\'s ceiling arithmetic needs re-deriving at the '
        .. 'ranks he actually holds.')
end

tests['[hero] axe t15 in-domain: every ultimate on the frame is a rank short'] = function()
    -- The gap above is NOT Axe's and not this repo's five focus heroes': every
    -- script in the game shows it.  That uniformity is what makes it a hand-off
    -- rather than an Axe fix.
    --
    -- Read through ONE field per hero -- the ultimate's rank against the 6/12/18
    -- ladder -- because that is immune to the facet over-count documented on
    -- points_spent above.  Crystal Maiden is the in-frame CONTROL: she is level
    -- 17 and correctly at rank 2, so this reader demonstrably separates "short"
    -- from "at its allowed rank" instead of answering 2 for everybody.
    --
    -- ⚠️ ONE GAME, ONE INSTANT.  Ten hero-slots of a single match are as
    -- correlated as samples get; this is a POINTER at a lever, not a measured
    -- frequency.  A second in-domain game is what would turn it into one, and
    -- none exists yet -- which is exactly why it is handed off rather than acted
    -- on here.
    local nAtCeiling, nShort, nControl, tShort = 0, 0, 0, {}
    for _, u in ipairs(FX.units or {}) do
        local sShort = (u.name or ''):gsub('^npc_dota_hero_', '')
        local sUlt = ULTIMATE[sShort]
        if sUlt ~= nil then
            local nRank = ability_rank(u, sUlt)
            local nAllowed = ult_rank_allowed(u.level or 0)
            if (u.level or 0) >= 18 then
                nAtCeiling = nAtCeiling + 1
                if nRank < nAllowed then
                    nShort = nShort + 1
                    tShort[#tShort + 1] = sShort .. ' lvl' .. u.level
                        .. ' ult ' .. nRank .. '/' .. nAllowed
                end
            elseif nRank == nAllowed then
                nControl = nControl + 1
            end
        end
    end
    assert(nControl >= 1,
        'no hero below level 18 on this frame is at its allowed ultimate rank, so '
        .. 'this reader has no control and "9 of 9 are short" could equally be a '
        .. 'reader that always says short.')
    assert(nAtCeiling == 9,
        'the frame now has ' .. nAtCeiling .. ' heroes at level >= 18, not 9.')
    assert(nShort == 9,
        'only ' .. nShort .. ' of ' .. nAtCeiling .. ' level-18+ heroes are a '
        .. 'rank short on their ultimate, not all 9.  The uniformity across ten '
        .. 'different hero scripts and both teams is the whole evidence that this '
        .. 'is a shared mechanism rather than one bad build row.  Still short: '
        .. table.concat(tShort, ', '))
end

-- ---------------------------------------------------------------------------
-- 5. The frame is DRY, and admitting it would not move the verdict.

tests['[hero] axe t15 in-domain: the frame observes neither modifier'] = function()
    assert(has_modifier(AXE, 'modifier_axe_berserkers_call_armor') == nil,
        'the in-domain Axe now carries Berserker\'s Call armor.  That is the '
        .. 'first in-domain OBSERVATION on the Call side and it belongs in the '
        .. 'sister file\'s health reading, not merely here.')
    assert(has_modifier(AXE, 'modifier_axe_battle_hunger_self_movespeed') ~= nil,
        'the in-domain Axe no longer carries his own Battle Hunger movespeed '
        .. 'buff.  That buff is what makes "the debuff is not live" a reading '
        .. 'about the DEBUFF rather than about Battle Hunger being unused.')
    local nOnEnemy = 0
    for _, u in ipairs(FX.units or {}) do
        if u.team ~= AXE.team and has_modifier(u, 'modifier_axe_battle_hunger') ~= nil then
            nOnEnemy = nOnEnemy + 1
        end
    end
    assert(nOnEnemy == 0,
        nOnEnemy .. ' enemies carry modifier_axe_battle_hunger on the in-domain '
        .. 'frame.  That is a first in-domain observation on the Hunger side; '
        .. 'carry it into the sister file rather than leaving it here.')
end

tests['[hero] axe t15 in-domain: admitting the frame leaves the verdict standing'] = function()
    -- Prices rows 4, 5 and 6 of GH #357 by arithmetic rather than by prose.
    local nCall = ability_rank(AXE, 'axe_berserkers_call')
    local nHunger = ability_rank(AXE, 'axe_battle_hunger')
    local call_ceiling = BEFORE.call_ceiling + ceiling(CALL, nCall)
    local hunger_ceiling = BEFORE.hunger_ceiling + ceiling(HUNGER, nHunger)

    assert(math.abs(call_ceiling - 2.52) < 0.005,
        'admitting the frame would put call_ceiling at ' .. string.format('%.4f', call_ceiling)
        .. ', not the 2.52 GH #357 row 4 priced.')
    assert(math.abs(hunger_ceiling - 17.00) < 0.005,
        'admitting the frame would put hunger_ceiling at '
        .. string.format('%.4f', hunger_ceiling) .. ', not 17.00.')

    -- The sister file's direction test, evaluated on the post-admission numbers.
    -- live counts are UNMOVED because section 5 established the frame is dry.
    local lhs = BEFORE.call_live * hunger_ceiling
    local rhs = BEFORE.hunger_live * call_ceiling
    assert(lhs > rhs,
        'ADMITTING THE STAGED FRAME WOULD FLIP THE t15 HEALTH READING: '
        .. string.format('call_live * hunger_ceiling = %.2f, hunger_live * call_ceiling = %.2f', lhs, rhs)
        .. '.  Then row 6 of GH #357 is a real re-decision with a real answer '
        .. 'and this file must say so instead of "verdict unchanged".')
    assert(math.abs(lhs - 17.00) < 0.01 and math.abs(rhs - 12.61) < 0.01,
        'the post-admission direction reads ' .. string.format('%.2f > %.2f', lhs, rhs)
        .. ', not the 17.00 > 12.61 this file reports.  The conclusion may well '
        .. 'be the same; the number in the report is not.')
end

-- ---------------------------------------------------------------------------
-- 6. The bound that replaces "out of domain": the CHOICE is still unobservable.

tests['[hero] axe t15: the talent PICK is unobservable, in domain or out'] = function()
    local nUnits, nWithTalent, nMaxTalent = 0, 0, 0
    local nAxe, nAxeWithTalent, nAxeInDomain = 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        local fx = dofile(path)
        for _, u in ipairs((type(fx) == 'table' and fx.units) or {}) do
            if u.name and u.name:match('^npc_dota_hero_') then
                local nTal = 0
                for _, a in ipairs(u.abilities or {}) do
                    if a.name:match('^special_bonus') then nTal = nTal + 1 end
                end
                nUnits = nUnits + 1
                if nTal > 0 then nWithTalent = nWithTalent + 1 end
                if nTal > nMaxTalent then nMaxTalent = nTal end
                if u.name == 'npc_dota_hero_axe' then
                    nAxe = nAxe + 1
                    if nTal > 0 then nAxeWithTalent = nAxeWithTalent + 1 end
                    if (u.level or 0) >= TALENT_LEVEL then nAxeInDomain = nAxeInDomain + 1 end
                end
            end
        end
    end

    assert(nMaxTalent == 1,
        'some hero unit now carries ' .. nMaxTalent .. ' special_bonus entries. '
        .. 'The cap of ONE is the reason a missing talent is not evidence of a '
        .. 'talent not taken -- a level-22 hero has three down and the dump shows '
        .. 'at most one.  If the surface widened, the t15 PICK may finally be '
        .. 'observable and this bound should be re-taken, not restated.')
    assert(nAxeWithTalent == 0,
        nAxeWithTalent .. ' of ' .. nAxe .. ' Axe frames now name a talent. '
        .. 'That is the first observation of an Axe t-pick in this archive; if it '
        .. 'is a t15 entry it is direct evidence about the sister file\'s verdict '
        .. 'and belongs there.')
    assert(nAxeInDomain >= 1,
        'no Axe in the archive is at level >= ' .. TALENT_LEVEL .. ' any more, so '
        .. 'this file has nothing to read.')
    assert(nWithTalent < nUnits,
        'every hero unit in the archive now carries a talent entry, so the '
        .. '"at most one, usually none" surface this bound rests on is gone.')
end

return tests

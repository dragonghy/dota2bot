-- [hero] The level-15 talent pairs of the two focus casters, decided on PAYOFF
-- CONDITIONS rather than on which single payout is bigger.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- Backlog section 18 left four t15/t10 pairs marked "no obvious winner -- do not
-- flip on taste; if you flip one, bring its payoff-condition analysis".  This is
-- that analysis for two of them, pinned so the next reader can attack the reasoning
-- instead of re-deriving it:
--
--   * ZEUS t15 was CHANGED, [3] +75 Thundergod's Wrath damage -> [4] -20% Arc
--     Lightning mana cost / cooldown.  A damage bonus can only pay on a cast that
--     happens; on this repo's fixture corpus Thundergod's Wrath is ready-and-
--     unaffordable on a large fraction of the frames where it is ready at all.
--   * CRYSTAL MAIDEN t15 was DELIBERATELY LEFT ALONE at [3] +100 Frostbite cast
--     range.  The rival ([4] -4.5s Crystal Nova cooldown) attacks a constraint that
--     is not binding: at 175 mana a rank-4 Nova every 3.5s needs mana this hero does
--     not have, and her file has no reserve mechanism that would arbitrate.  Section
--     4 records the three code facts that decide it, so the next round starts there.
--
-- ANCHORS
--   Ability and talent numbers are RECORDED from
--   https://www.dota2.com/datafeed/herodata?language=english&hero_id={5,22}, read
--   2026-08-22.  This test cannot reach the network; what it enforces is the
--   repo-local half -- which index each row selects, which handles the hero files
--   consume, and the arithmetic that those recorded numbers make true or false.
--
-- HONEST BOUNDS
--   * The fixture census in sections 3 and 6 is over 100 frames cut for OTHER
--     investigations.  It is an EXISTENCE read, not a density (charter section Y.2),
--     and four of the Zeus frames were cut by this desk specifically to study Zeus
--     mana -- so both counts are asserted as LOWER BOUNDS, never as equations
--     (GH #106: a corpus equality is a landmine for whoever adds the next fixture).
--   * Nothing here claims a win rate.  The claims are about which payoff condition
--     the shipped code can reach, and how often the corpus shows it reached.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local BOTLIB = 'bots/BotLib/'

-- Recorded from the datafeed, 2026-08-22.
local ZEUS = {
    talents = {
        'special_bonus_unique_zeus',            -- [1] +1 Heavenly Jump target
        'special_bonus_hp_200',                 -- [2] +200 health
        'special_bonus_unique_zeus_4',          -- [3] +75 Thundergod's Wrath damage
        'special_bonus_unique_zeus_6',          -- [4] -20% Arc Lightning mana/cooldown
        'special_bonus_unique_zeus_2',          -- [5] +60 Arc Lightning damage   (t20)
        'special_bonus_unique_zeus_3',          -- [6] +0.5s Bolt ministun        (t20)
        'special_bonus_unique_zeus_5',          -- [7] AoE Lightning Bolt         (t25)
        'special_bonus_unique_zeus_jump_charges', -- [8] +3 Jump charges          (t25)
    },
    ult_cost = { 250, 375, 500 },
    arc_cost = { 85, 90, 95, 100 },
    arc_cooldown = 1.6,
}

local CM = {
    frostbite_cast_range = 600,
    frostbite_range_talent = 100,   -- special_bonus_unique_crystal_maiden_frostbite_castrange
    nova_cast_range = 700,
    nova_cooldown = { 11, 10, 9, 8 },
    nova_cd_talent = 4.5,           -- special_bonus_unique_crystal_maiden_5
    nova_cost = { 115, 135, 155, 175 },
    ult_cost = { 200, 400, 600 },
    attack_range = 600,
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function talent_rows(hero)
    local src = read_file(BOTLIB .. 'hero_' .. hero .. '.lua')
    local body = src:match('local tTalentTreeList = {(.-)\n}')
    assert(body, 'hero_' .. hero .. '.lua has no tTalentTreeList literal')
    local rows = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    return rows
end

local function with_skill_lib(hero, fn)
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_' .. hero) })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    return fn(J)
end

--- Every fixture in the corpus, loaded the way the tests load them.
--- Deliberately dofile and not a regex: the 2026-08-22 Axe round read 10 Axe frames
--- with a regex where dofile reads 26, which is exactly how a reachable domain gets
--- written up as an empty one.
local function each_fixture(fn)
    local paths = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua'))
    for line in p:lines() do paths[#paths + 1] = line end
    p:close()
    assert(#paths >= 90, 'fixture corpus shrank to ' .. #paths .. ' files; the census '
        .. 'below is a lower bound over the corpus, so a shrinking corpus makes it '
        .. 'weaker without failing -- check what was deleted.')
    for _, path in ipairs(paths) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and fx.units then fn(path, fx) end
    end
end

--- Ult-ready frames of one hero: { mana, max_mana, ult_level, spell_level } rows.
local function ready_frames(hero_unit, ult_name, spell_name)
    local rows = {}
    each_fixture(function(path, fx)
        for _, u in ipairs(fx.units) do
            if u.name == hero_unit and u.alive then
                local ult, spell
                for _, a in ipairs(u.abilities or {}) do
                    if a.name == ult_name then ult = a end
                    if a.name == spell_name then spell = a end
                end
                if ult and (ult.level or 0) > 0 and (ult.cd or 0) <= 0 then
                    rows[#rows + 1] = {
                        path = path, time = fx.time, mana = u.mp,
                        ult_level = ult.level,
                        spell_level = (spell and (spell.level or 0) > 0) and spell.level or 1,
                    }
                end
            end
        end
    end)
    return rows
end

-- ---------------------------------------------------------------------------
-- 1. The Zeus change itself, driven through the real GetTalentBuild.

tests['[hero] zeus t15 takes the Arc Lightning mana talent, not the ult damage one'] = function()
    local rows = talent_rows('zuus')
    assert(rows.t15, 'hero_zuus.lua lost its t15 row')
    assert(rows.t15[1] ~= 0,
        "hero_zuus.lua's t15 row is back to the odd index = special_bonus_unique_zeus_4 "
        .. '(+75 Thundergod\'s Wrath damage). It was changed on 2026-08-22 to '
        .. 'special_bonus_unique_zeus_6 (-20% Arc Lightning mana cost / cooldown) '
        .. 'because the ult is ready-and-unaffordable on a large share of the frames '
        .. 'where it is ready at all, and a damage bonus cannot buy back a cast that '
        .. 'never happened. Reverting is allowed -- but say why in the file.')
    with_skill_lib('zuus', function(J)
        local picks = J.Skill.GetTalentBuild(rows)
        assert(picks[2] == 4,
            'zeus t15 must resolve to sTalentList[4] = ' .. ZEUS.talents[4]
            .. '; got [' .. tostring(picks[2]) .. '] = '
            .. tostring(ZEUS.talents[picks[2]]))
    end)
end

tests['[hero] the zeus t15 rationale is still in the hero file'] = function()
    local src = read_file(BOTLIB .. 'hero_zuus.lua')
    for _, needle in ipairs({
        'special_bonus_unique_zeus_6',   -- what is taken
        'binding constraint is mana',    -- the shape of the argument
        'HONEST BOUNDS',                 -- what it gives up and what was not measured
        'datafeed',                      -- where the numbers came from
    }) do
        assert(src:find(needle, 1, true),
            'the t15 rationale block in hero_zuus.lua no longer mentions "' .. needle
            .. '". The charter allows an ungated talent change only with its reasoning '
            .. 'written into the hero file; if the reasoning is gone, so is the licence '
            .. 'for the change.')
    end
end

-- ---------------------------------------------------------------------------
-- 2. Why the change is a PURE TABLE change: no code path reads a t10/t15 handle.
--
-- This is the load-bearing claim behind "ungated numeric change".  If some branch
-- consumed talent3 or talent4, flipping the row would move behaviour through code as
-- well as through the hero's skill points, and the charter would want a gate.

tests['[hero] hero_zuus.lua consumes no turbo-reachable talent handle'] = function()
    local src = read_file(BOTLIB .. 'hero_zuus.lua')
    local live = src:gsub('%-%-%[%[.-%]%]', ''):gsub('\n%s*%-%-[^\n]*', '\n')
    for idx = 1, 4 do
        assert(not live:find('sTalentList%[' .. idx .. '%]'),
            'hero_zuus.lua now binds sTalentList[' .. idx .. '] (a t10/t15 talent, '
            .. 'reachable in turbo). The 2026-08-22 t15 flip was justified as a pure '
            .. 'table change on the grounds that nothing in the file reads those '
            .. 'handles -- re-argue it before shipping this.')
    end
    assert(live:find('sTalentList%[5%]'), 'the talent5 handle vanished; section 5 is '
        .. 'written against it -- re-read the report before deleting the finding.')
end

tests['[hero] the write-only talentDamage local stayed deleted'] = function()
    local src = read_file(BOTLIB .. 'hero_zuus.lua')
    local live = src:gsub('%-%-%[%[.-%]%]', ''):gsub('\n%s*%-%-[^\n]*', '\n')
    assert(not live:find('talentDamage'),
        'talentDamage is back in hero_zuus.lua. It was assigned twice and read '
        .. 'nowhere (the shape GH #104 removed from Wraith King, GH #73 from Lion), '
        .. 'and its only input was the t25 Heavenly Jump CHARGES talent read through a '
        .. "special value name ('value') that talent does not have. If it is back, it "
        .. 'needs a reader and a correct handle, not a re-assignment.')
    assert(not live:find('talent8'),
        'the talent8 handle is back in hero_zuus.lua with nothing to feed; it was '
        .. 'removed together with talentDamage.')
end

-- ---------------------------------------------------------------------------
-- 3. The census the Zeus argument rests on -- as LOWER BOUNDS, recomputed here.
--
-- Recorded reading on 2026-08-22: 16 ult-ready Zeus frames, 7 of them unaffordable
-- (4 of 12 once the four fixtures cut to study Zeus mana are excluded), shortfalls
-- 26 / 60 / 98 / 106 / 123 / 151 / 239 mana.  Adding fixtures can only add frames,
-- so the assertions below are >=, and a failure here means the corpus LOST frames or
-- the fixture schema changed -- not that the argument got weaker.

tests['[hero] zeus ult is ready-and-unaffordable on multiple corpus frames'] = function()
    local rows = ready_frames('npc_dota_hero_zuus', 'zuus_thundergods_wrath', 'zuus_arc_lightning')
    assert(#rows >= 16, 'only ' .. #rows .. ' ult-ready Zeus frames in the corpus; '
        .. '16 were read on 2026-08-22')
    local short, worst_arcs = {}, 0
    for _, r in ipairs(rows) do
        local cost = ZEUS.ult_cost[r.ult_level]
        if r.mana < cost then
            local arcs = (cost - r.mana) / ZEUS.arc_cost[r.spell_level]
            short[#short + 1] = arcs
            if arcs > worst_arcs then worst_arcs = arcs end
        end
    end
    assert(#short >= 7, 'only ' .. #short .. ' unaffordable ult-ready Zeus frames; 7 '
        .. 'were read on 2026-08-22, and the t15 flip is argued from them')
    table.sort(short)
    local median = short[math.ceil(#short / 2)]
    assert(median <= 2.0, string.format(
        'the median shortfall is now %.1f Arc Lightning casts (was ~1.1). The talent '
        .. 'buys 20%% of one Arc per cast, so a large shortfall is NOT something it '
        .. 'closes -- if this trips, the t15 argument needs re-reading, not a bigger '
        .. 'number here.', median))
end

-- ---------------------------------------------------------------------------
-- 4. Crystal Maiden t15: three code facts, and why they say DO NOT FLIP.
--
-- FACT 1 (containment).  X.ConsiderQ builds its ring as GetCastRange() + aether + 32
-- and X.ConsiderW as GetCastRange() + 30 + aether.  With the datafeed ranges that is
-- 732 for Nova and 630 for Frostbite; the +100 talent takes Frostbite's ring to 730,
-- i.e. it stays INSIDE Nova's ring -- by two units, and the aether term cancels.  So
-- every frame the talent could newly address is a frame Nova already addressed.
--
-- FACT 2 (order).  X.SkillsComplement consults ConsiderQ BEFORE ConsiderW and returns
-- on any desire > 0.  Combined with fact 1: the range talent only ever pays on frames
-- where Nova declined -- while the rival talent (-4.5s Nova cooldown) pays into the
-- consumer that has first refusal.  That asymmetry argues FOR the flip.
--
-- FACT 3 (the constraint that is actually binding) is what stops it: a rank-4 Nova
-- costs 175 with a 3.5s post-talent cooldown, i.e. 50 mana/second sustained, which no
-- support has.  Cooldown was not the limit; mana was.  Section 6 measures the same
-- hero's ult already going unaffordable, and section 5 shows her file has no reserve
-- mechanism to arbitrate between Nova and the ult.

tests['[hero] the CM frostbite range talent stays inside the Nova ring'] = function()
    local src = read_file(BOTLIB .. 'hero_crystal_maiden.lua')
    local q_off = tonumber(src:match('abilityQ:GetCastRange%(%)%s*%+%s*aetherRange%s*%+%s*(%d+)'))
    local w_off = tonumber(src:match('abilityW:GetCastRange%(%)%s*%+%s*(%d+)%s*%+%s*aetherRange'))
    assert(q_off and w_off, 'the ConsiderQ/ConsiderW cast-range expressions in '
        .. 'hero_crystal_maiden.lua no longer have the shape this analysis parsed '
        .. '(GetCastRange() + <n> terms) -- re-read section 4 before trusting it.')
    local nova_ring = CM.nova_cast_range + q_off
    local frostbite_ring_with_talent = CM.frostbite_cast_range + CM.frostbite_range_talent + w_off
    assert(nova_ring >= frostbite_ring_with_talent, string.format(
        'Nova ring %d is no longer >= the talent-boosted Frostbite ring %d. The CM '
        .. 't15 "do not flip" note rests on the containment: whatever the range talent '
        .. 'newly reaches, Nova reached first and got first refusal.',
        nova_ring, frostbite_ring_with_talent))
end

tests['[hero] CM considers Nova before Frostbite, and returns in between'] = function()
    local src = read_file(BOTLIB .. 'hero_crystal_maiden.lua')
    local body = src:match('function X%.SkillsComplement%(%)(.-)\nend')
    assert(body, 'hero_crystal_maiden.lua has no X.SkillsComplement body')
    local q_at = body:find('X%.ConsiderQ%(%)')
    local w_at = body:find('X%.ConsiderW%(%)')
    assert(q_at and w_at, 'SkillsComplement no longer calls both ConsiderQ and ConsiderW')
    assert(q_at < w_at, 'ConsiderW is now consulted before ConsiderQ; fact 2 of the CM '
        .. 't15 analysis (Nova has first refusal on every frame the Frostbite range '
        .. 'talent could address) is inverted -- redo the comparison.')
    assert(body:sub(q_at, w_at):find('return'),
        'the early return between the Nova bid and the Frostbite bid is gone, so a '
        .. 'Nova bid no longer preempts Frostbite on the same tick.')
end

-- ---------------------------------------------------------------------------
-- 5. The attack-range floor in X.ConsiderW is unreachable today -- and it is a
-- fossil, not a safeguard.
--
-- `if #nEnemysHeroesInView <= 1 and nCastRange < bot:GetAttackRange() then ... end`
-- can only fire while Frostbite's cast range plus 30 is UNDER Crystal Maiden's 600
-- attack range, i.e. while that cast range is at most 569.  The datafeed says 600.
-- It is left in place rather than deleted: unreachability here depends on a runtime
-- value (GetAttackRange()), not on a zero-read local, so deleting it would be a
-- behaviour change in any world where this hero gains attack range.

tests['[hero] the CM frostbite attack-range floor cannot fire at the shipped numbers'] = function()
    local src = read_file(BOTLIB .. 'hero_crystal_maiden.lua')
    local w_off = tonumber(src:match('abilityW:GetCastRange%(%)%s*%+%s*(%d+)%s*%+%s*aetherRange'))
    assert(w_off, 'ConsiderW no longer builds its range as GetCastRange() + <n> + aether')
    assert(src:find('nCastRange < bot:GetAttackRange()', 1, true),
        'the attack-range floor in X.ConsiderW is gone. If it was deleted, note that '
        .. 'this test called it unreachable at the SHIPPED numbers only -- the deletion '
        .. 'is still a behaviour change if this hero ever gains attack range.')
    assert(CM.frostbite_cast_range + w_off >= CM.attack_range, string.format(
        'Frostbite ring %d is now under the %d attack range, so the floor branch is '
        .. 'LIVE again and the ConsiderW ring is really %d. Every range claim in the '
        .. 'CM t15 analysis was computed without it.',
        CM.frostbite_cast_range + w_off, CM.attack_range, CM.attack_range + 60))
end

-- ---------------------------------------------------------------------------
-- 6. Crystal Maiden has no mana reserve for Freezing Field either -- the third
-- member of the family (Zeus: GH #47/#59; Lion: GH #73).
--
-- The highest mana bar anywhere in her file is nKeepMana * 2 = 440, and it guards
-- only the LANE HARASS branches; the kill/hurt-AoE branches that fire in fights carry
-- no mana predicate at all.  Recorded census, 2026-08-22: 24 ult-ready CM frames, 5
-- of them below the ult cost -- including 399 mana against a 400 cost, one mana short.

tests['[hero] no mana bar in hero_crystal_maiden.lua reserves the ultimate'] = function()
    local src = read_file(BOTLIB .. 'hero_crystal_maiden.lua')
    local keep = tonumber(src:match('nKeepMana%s*=%s*(%d+)'))
    assert(keep, 'hero_crystal_maiden.lua no longer sets nKeepMana')
    local highest = keep
    for mult in src:gmatch('nKeepMana%s*%*%s*([%d%.]+)') do
        highest = math.max(highest, keep * tonumber(mult))
    end
    for lit in src:gmatch('bot:GetMana%(%)%s*>=?%s*(%d+)') do
        highest = math.max(highest, tonumber(lit))
    end
    assert(highest < CM.ult_cost[3], string.format(
        'the highest mana bar in the file is now %d, at or above the rank-3 Freezing '
        .. 'Field cost of %d. That would be an actual reserve -- re-open the CM t15 '
        .. 'question, because fact 3 (mana is the binding constraint, and nothing '
        .. 'arbitrates it) is what stopped the flip.', highest, CM.ult_cost[3]))
end

tests['[hero] CM ult goes unaffordable on corpus frames where it is ready'] = function()
    local rows = ready_frames('npc_dota_hero_crystal_maiden', 'crystal_maiden_freezing_field',
        'crystal_maiden_crystal_nova')
    assert(#rows >= 24, 'only ' .. #rows .. ' ult-ready CM frames in the corpus; 24 '
        .. 'were read on 2026-08-22')
    local below, in_band = 0, 0
    for _, r in ipairs(rows) do
        local cost = CM.ult_cost[r.ult_level]
        if r.mana < cost then
            below = below + 1
        elseif r.mana < cost + CM.nova_cost[r.spell_level] then
            in_band = in_band + 1
        end
    end
    assert(below >= 5, 'only ' .. below .. ' unaffordable ult-ready CM frames; 5 were '
        .. 'read on 2026-08-22')
    -- The band is the ENTIRE domain a reserve gate could ever act on: mana high
    -- enough for the ult, low enough that one Nova would break it.  Two frames, both
    -- at ult rank 1.  Recorded so a future 'cmkeep' proposal starts from a measured
    -- domain rather than from the idea -- the lesson of the six pre-flight rejections.
    assert(in_band >= 2, 'only ' .. in_band .. ' CM frames in the [ult cost, ult cost + '
        .. 'nova cost) band; 2 were read on 2026-08-22. That band is the whole domain '
        .. 'of any future CM mana-reserve gate.')
end

return tests

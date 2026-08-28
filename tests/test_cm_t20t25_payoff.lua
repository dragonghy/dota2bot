-- [hero] Crystal Maiden's t20 and t25 pairs, priced 2026-08-27 -- and BOTH
-- FLIPPED.  This file exists so neither decision is re-litigated on taste, and
-- so the facts they rest on are assertions rather than prose.
--
--   t20  [5] special_bonus_unique_crystal_maiden_glacial_guard_mana_multiplier
--            +20 on Glacial Guard's mana-to-barrier percentage   <- NOW SHIPPED
--        [6] special_bonus_unique_crystal_maiden_3
--            +50 Freezing Field damage                           <- was shipped
--
--   t25  [8] special_bonus_unique_crystal_maiden_2
--            +300 Crystal Nova damage                            <- NOW SHIPPED
--        [7] special_bonus_unique_crystal_maiden_1
--            +1.0s Frostbite duration                            <- was shipped
--
-- The two rows moved for DIFFERENT reasons, and only one of them is a payoff
-- argument:
--
--   * t20 is REACHABILITY, decided the way t10 and t15 were.  [6] pays +50 per
--     Freezing Field explosion, i.e. it is denominated in channel-seconds held;
--     the two channels this repo has read frame by frame were cut at 6% and
--     ~10% of maximum, and the three candidates that would guard the opening
--     ('cmrguard', 'cmrcap', 'cmrself') are all still soak candidates, so the
--     shipped default has no guard at all.  [5] is denominated in mana spent on
--     abilities -- no cast to land, no channel to hold -- and section 4 pins
--     that NEITHER side is visible to this file's decision layer, which is what
--     makes the flip affordable: it can only move combat power.
--
--   * t25 is a STALE READING, and the shipped row was the one carrying it.
--     Section 2 is an iff ratchet on that: X.ConsiderW reconstructs Frostbite's
--     damage by hand, the reconstruction is exactly right at all four ranks, and
--     it is right ONLY while no talent touches the duration.  Section 3 pins the
--     contrast -- Nova's damage is read live from the engine, so [8]'s +300
--     reaches the kill-check by itself (GH #228's fold).
--
-- HONEST BOUNDS, carried here because they travel with the decision:
--   * the channel evidence is n=2, both frames below level 20 and both from the
--     10-minute-capped corpus.  It bounds the SHAPE of [6]'s payoff, not its
--     rate at 20+.  Nothing in this file asserts a rate.
--   * Glacial Guard's barrier is PHYSICAL only.  This file cannot measure what
--     share of the damage that kills her is physical; no assertion here claims
--     to.
--   * the KV facts (what each talent modifies, Frostbite's dps and duration)
--     come from tests/mock/*.lua, which are snapshots of the game's own KV taken
--     by tools/agent/*_census.py --snapshot.  A patch that reworks the hero
--     moves them, and this file is meant to go red when it does.

package.path = 'tests/?.lua;' .. package.path

local SLOTS = require('mock.talent_slots').SLOTS
local SHAPES = require('mock.special_value_shapes').SHAPES

local HERO = 'bots/BotLib/hero_crystal_maiden.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

--- The source with every comment removed.  MANDATORY here: this round wrote the
--- whole argument -- the `100 + nSkillLV * 50` formula included -- into the hero
--- file's own header, so a scan of the raw text would happily read its own
--- documentation back and call the code present.  Same reason
--- tests/test_focus_talent_anchor.lua grew live_lines.
local function live_source(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return table.concat(out, '\n')
end

--- { t10 = {a,b}, ... } read out of the shipped literal.
local function talent_rows(src)
    local body = src:match('local tTalentTreeList = {(.-)\n}')
    assert(body, HERO .. ' has no tTalentTreeList literal')
    local rows = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    return rows
end

--- '1.5 2 2.5 3' -> { 1.5, 2, 2.5, 3 }.  The per-level strings are the only form
--- the KV snapshot carries, so every arithmetic assertion below starts here.
local function levels(sValue)
    local out = {}
    for token in tostring(sValue):gmatch('%S+') do out[#out + 1] = tonumber(token) end
    return out
end

local CM_SLOTS = SLOTS['crystal_maiden']
local CM_SHAPES = SHAPES['crystal_maiden']
local FROSTBITE = CM_SHAPES and CM_SHAPES['crystal_maiden_frostbite']
local NOVA = CM_SHAPES and CM_SHAPES['crystal_maiden_crystal_nova']

-- ---------------------------------------------------------------------------
-- 0. Anti-vacuum.  Every section below is a scan or a table lookup, and each of
--    them passes trivially if what it reads is empty.

tests['[hero] the sources this file prices from are non-empty'] = function()
    local live = live_source(read_file(HERO))
    assert(#live > 4000, 'only ' .. #live .. ' bytes of live (comment-stripped) '
        .. HERO .. ' -- every source scan below would pass by finding nothing')
    assert(CM_SLOTS and #CM_SLOTS == 8,
        'tests/mock/talent_slots.lua no longer carries eight crystal_maiden slots')
    assert(FROSTBITE and NOVA,
        'tests/mock/special_value_shapes.lua no longer carries CM Frostbite / Crystal Nova')
    assert(#levels(FROSTBITE['duration'].base) == 4 and #levels(NOVA['nova_damage'].base) == 4,
        'Frostbite duration / Nova damage are no longer four-rank strings')
end

-- ---------------------------------------------------------------------------
-- 1. The two rows, in the shipped source.

tests['[hero] CM t20 takes the Glacial Guard barrier talent, not Freezing Field damage'] = function()
    local rows = talent_rows(read_file(HERO))
    assert(rows.t20, HERO .. ' has no t20 row')
    assert(rows.t20[1] == 0 and rows.t20[2] == 10,
        'CM t20 is {' .. rows.t20[1] .. ',' .. rows.t20[2] .. '}, i.e. back on the '
        .. 'EVEN index -- special_bonus_unique_crystal_maiden_3, +50 Freezing Field '
        .. 'damage. That row was priced on 2026-08-27 and moved to [5] because its '
        .. 'payoff is denominated in channel-seconds held, and the two channels this '
        .. 'repo has read frame by frame were cut at 6% and ~10% of maximum while the '
        .. 'guards that would protect them are still soak candidates. Flipping back is '
        .. 'allowed -- but bring a measurement of how long the SHIPPED bot actually '
        .. 'holds the channel at level 20+, which is the number nobody has.')
end

tests['[hero] CM t25 takes the Crystal Nova damage talent, not the Frostbite duration one'] = function()
    local rows = talent_rows(read_file(HERO))
    assert(rows.t25, HERO .. ' has no t25 row')
    assert(rows.t25[1] == 10 and rows.t25[2] == 0,
        'CM t25 is {' .. rows.t25[1] .. ',' .. rows.t25[2] .. '}, i.e. back on the '
        .. 'ODD index -- special_bonus_unique_crystal_maiden_1, +1.0s Frostbite '
        .. 'duration. Read section 2 before doing that: X.ConsiderW reconstructs '
        .. "Frostbite's damage as a hardcoded 100 + rank*50, and that reconstruction "
        .. 'is exact ONLY while no talent touches the duration.')
end

-- ---------------------------------------------------------------------------
-- 2. The iff ratchet: the Frostbite kill-check hardcode, and the talent that
--    invalidates it.  Either the row stays off [7], or the hardcode stops being
--    a hardcode -- one of the two, forever.

--- The `nDamage = ( 100 + nSkillLV * 50 )` reconstruction, as {base, per_rank},
--- or nil once someone replaces it with a real read.
local function frostbite_hardcode(live)
    local base, per = live:match('nDamage%s*=%s*%(%s*(%d+)%s*%+%s*nSkillLV%s*%*%s*(%d+)%s*%)')
    if base == nil then return nil end
    return { tonumber(base), tonumber(per) }
end

tests["[hero] X.ConsiderW's hardcoded Frostbite damage equals the KV at all four ranks"] = function()
    local hc = frostbite_hardcode(live_source(read_file(HERO)))
    if hc == nil then return end -- repaired; section 2b is the assertion that matters then
    local dps = tonumber(FROSTBITE['damage_per_second'].base)
    local dur = levels(FROSTBITE['duration'].base)
    for rank = 1, 4 do
        local kv = dps * dur[rank]
        local coded = hc[1] + hc[2] * rank
        assert(math.abs(kv - coded) < 0.001,
            'rank ' .. rank .. ': the KV says Frostbite deals ' .. dps .. ' dps for '
            .. dur[rank] .. 's = ' .. kv .. ', while X.ConsiderW computes ' .. coded
            .. '. The hardcode was EXACT when this pair was priced (150/200/250/300); '
            .. 'if the patch moved the dps or the duration ladder, the kill-check is '
            .. 'now wrong at every rank and the t25 pricing has to be re-read.')
    end
end

tests['[hero] the +1.0s Frostbite talent is exactly what the hardcode cannot see'] = function()
    local bonus = FROSTBITE['duration'].bonus['special_bonus_unique_crystal_maiden_1']
    assert(bonus, 'special_bonus_unique_crystal_maiden_1 no longer modifies '
        .. 'crystal_maiden_frostbite/duration in the KV snapshot -- the whole t25 '
        .. 'ruling rests on it doing so')
    assert(CM_SLOTS[7].name == 'special_bonus_unique_crystal_maiden_1',
        'slot 7 is now ' .. CM_SLOTS[7].name .. ', not the Frostbite duration talent. '
        .. 'The t25 pair was priced against the [7]/[8] pairing; re-read it.')
    local hc = frostbite_hardcode(live_source(read_file(HERO)))
    if hc == nil then return end
    local dps = tonumber(FROSTBITE['damage_per_second'].base)
    local dur = levels(FROSTBITE['duration'].base)
    local extra = tonumber((tostring(bonus):gsub('%+', '')))
    local blind = dps * (dur[4] + extra) - (hc[1] + hc[2] * 4)
    assert(math.abs(blind - 100) < 0.001,
        'taking [7] would leave the kill-check short by ' .. blind .. ', not the 100 '
        .. 'this pair was priced on. The direction still matters more than the size: '
        .. 'the bot underestimates its own damage, i.e. it declines kills it can make.')
end

tests['[hero] CM t25 is on [7] only if the Frostbite hardcode has been repaired'] = function()
    local src = read_file(HERO)
    local rows = talent_rows(src)
    local on_seven = (rows.t25[1] == 0)
    local hardcoded = frostbite_hardcode(live_source(src)) ~= nil
    assert(not (on_seven and hardcoded),
        'CM t25 is back on [7] (+1.0s Frostbite duration) WHILE X.ConsiderW still '
        .. 'reconstructs Frostbite damage as a hardcoded 100 + rank*50. That pairing '
        .. 'is the defect this round removed: from level 25 the real damage is 400 '
        .. 'and the kill-check says 300. Take [8], or make X.ConsiderW read '
        .. "duration/damage_per_second off the ability handle the way X.ConsiderQImpl "
        .. 'reads nova_damage -- either fixes it, and this assertion accepts both.')
end

-- ---------------------------------------------------------------------------
-- 3. The other half of the t25 argument: Nova's damage is read LIVE, so the
--    engine's fold of the +300 reaches the decision layer with no code change.

tests['[hero] X.ConsiderQImpl reads nova_damage off the ability and spends it on the kill search'] = function()
    local live = live_source(read_file(HERO))
    assert(live:match("abilityQ:GetSpecialValueInt%(%s*'nova_damage'%s*%)"),
        "hero_crystal_maiden.lua no longer reads abilityQ:GetSpecialValueInt('nova_damage'). "
        .. 'That read is the entire reason [8] was preferred at t25: the engine folds a '
        .. 'trained talent into the base value (GH #228), so the kill-check tracks the '
        .. '+300 by itself. If the read is gone, the talent is invisible and the pair '
        .. 'must be re-priced.')
    local var = live:match('local%s+(%w+)%s*=%s*abilityQ:GetSpecialValueInt%(%s*\'nova_damage\'%s*%)')
    assert(var, 'the nova_damage read is no longer bound to a local')
    local spent = false
    for args in live:gmatch('FindAoELocation(%b())') do
        if args:find('[^%w_]' .. var .. '[^%w_]') then spent = true end
    end
    assert(spent,
        'the nova_damage read no longer reaches bot:FindAoELocation. The talent then '
        .. 'raises damage without raising the threshold the bot searches with, which is '
        .. 'the half of the t25 argument that is about DECISIONS rather than damage.')
    assert(NOVA['nova_damage'].bonus['special_bonus_unique_crystal_maiden_2'],
        'special_bonus_unique_crystal_maiden_2 no longer modifies nova_damage in the KV '
        .. 'snapshot; the t25 ruling rests on that fold')
    assert(CM_SLOTS[8].name == 'special_bonus_unique_crystal_maiden_2',
        'slot 8 is now ' .. CM_SLOTS[8].name .. ', not the Crystal Nova damage talent')
end

-- ---------------------------------------------------------------------------
-- 4. The t20 premises: what the talent modifies, that NEITHER side is visible
--    to this file, and that the guards on opening the channel are still dark.

tests['[hero] slot 5 is the Glacial Guard mana-to-barrier talent'] = function()
    assert(CM_SLOTS[5].name == 'special_bonus_unique_crystal_maiden_glacial_guard_mana_multiplier',
        'slot 5 is now ' .. CM_SLOTS[5].name .. '. The t20 flip was argued about the '
        .. 'Glacial Guard barrier; a different talent there is a different decision.')
    local mm = CM_SHAPES['crystal_maiden_glacial_guard']['mana_multiplier']
    assert(tonumber(mm.base) == 30 and mm.bonus['hero_levelup'] == '+2'
        and mm.bonus['special_bonus_unique_crystal_maiden_glacial_guard_mana_multiplier'] == '+20',
        'Glacial Guard now reads base ' .. tostring(mm.base) .. ' with levelup '
        .. tostring(mm.bonus['hero_levelup']) .. ' and talent '
        .. tostring(mm.bonus['special_bonus_unique_crystal_maiden_glacial_guard_mana_multiplier'])
        .. '. The pricing said ~70% at level 20 going to ~90%, i.e. +20 barrier per 100 '
        .. 'mana spent; re-do that arithmetic before leaving the row where it is.')
    assert(CM_SLOTS[6].name == 'special_bonus_unique_crystal_maiden_3'
        and CM_SHAPES['crystal_maiden_freezing_field']['damage']
            .bonus['special_bonus_unique_crystal_maiden_3'] == '+50',
        'the rejected side of t20 is no longer +50 Freezing Field damage')
end

tests['[hero] neither t20 side is visible to this file, which is what made the flip affordable'] = function()
    local live = live_source(read_file(HERO))
    assert(not live:find('glacial_guard', 1, true),
        'hero_crystal_maiden.lua now names crystal_maiden_glacial_guard in live code. '
        .. 'The t20 flip was affordable BECAUSE no handle existed (the innate is hidden '
        .. 'on 53/53 corpus frames and dropped from sAbilityList before this file sees '
        .. 'it, GH #206). A handle means the row can now create a stale read, so the '
        .. 'pricing has to be redone with that read in it.')
    assert(not live:match("GetSpecialValue%w*%(%s*'damage'%s*%)"),
        "hero_crystal_maiden.lua now reads a 'damage' special value. If that is Freezing "
        .. "Field's, the rejected t20 side stopped being invisible and the pair is no "
        .. 'longer a pure combat-power call.')
end

tests['[hero] the Freezing Field opening guards are still soak candidates'] = function()
    local live = live_source(read_file(HERO))
    for _, id in ipairs({ 'cmrguard', 'cmrcap', 'cmrself' }) do
        assert(live:find("IsSoakCandidate( '" .. id .. "' )", 1, true),
            "the '" .. id .. "' gate is gone from hero_crystal_maiden.lua. If it was "
            .. 'PROMOTED, the shipped bot now guards its own Freezing Field opening -- '
            .. 'which is exactly the premise the t20 flip rests on (that it does not). '
            .. 'Re-price t20: a channel that is held longer is a channel whose per-'
            .. 'explosion damage talent is worth more.')
    end
end

return tests

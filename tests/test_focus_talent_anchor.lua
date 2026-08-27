-- [hero] Focus-five talent ladder re-anchor: which talent each focus hero's
-- tTalentTreeList actually selects today, and the arithmetic that decides it.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- GH #104 re-anchored Wraith King against the live datafeed and found the talent
-- block in his file was still the 7.2x set.  The other four focus heroes had never
-- been checked, and the rows are written as {0,10}/{10,0} pairs whose meaning is an
-- arithmetic detail of J.Skill.GetTalentBuild -- which is exactly the kind of thing
-- that rots silently across patches.  It had already rotted twice in hero_axe.lua:
--
--   * the npc dump quotes the 7.2x ladder (special_bonus_strength_8 /
--     ..._movement_speed_20 / ..._mp_regen_2 / ..._attack_speed_35 /
--     ..._hp_regen_20); five of those names are gone from the hero;
--   * the t15 row carried the comment "+35 attack speed over +2 mana regen" -- and
--     {0,10} takes the ODD index of the pair, which in that same 7.2x ladder was
--     special_bonus_mp_regen_2.  The row picked the talent its own comment says it
--     rejects.  That comment is deleted, not corrected: both names are gone.
--
-- WHAT IS PINNED HERE
--   1. the pair-to-tier wiring and the {0,10}/{10,0} parity, READ OUT of this
--      repo's own J.Skill.GetTalentBuild by flipping one row at a time -- never
--      asserted from convention (the same method GH #104 had to switch to after a
--      mutation walked through an asserted version);
--   2. the resolved t10/t15/t20/t25 index of all five focus heroes, parsed from
--      their own source.  t20/t25 WERE recorded but not pinned, on this reason:
--      "GH #84's level census read level >= 20 on 0 of 210 hero-slots
--      (high-water 19), so in turbo they are dead rows and pinning them would
--      only create noise".  THAT REASON IS GONE (GH #235, and the axis this
--      round opened).  The zero was an artefact of the batch harness, not a
--      property of turbo: every game self-terminated at the 10-minute
--      economy cap, so no hero-slot could reach 20.  Owner priority P3
--      (GH #108) raised the cap to 25 minutes, and the first frame taken past
--      it -- iterations/pending/tpgap_159_fixture/, t=1382.2 (23:02) of a
--      24.9-minute naturally-ended game -- reads TEN heroes at level 22-27,
--      three of them focus heroes (crystal_maiden 22, zuus 23,
--      skeleton_king 26).  t20 and t25 are live rows, they are reached in the
--      order section 6 pins, and the ten picks they resolve to have never been
--      examined by this project: they are the OpenHyperAI snapshot's defaults;
--   3. Axe's t10 change of 2026-08-22 (index [1] -> [2]) together with the
--      rationale block that has to travel with it;
--   4. a ratchet that the dead 7.2x talent names never come back as live data.
--
--   5. that this record and tests/mock/talent_slots.lua cannot drift apart
--      again -- see section 5 and GH #214, which is what let them disagree
--      about Wraith King's slot 4 for two days.
--
-- HONEST BOUNDS
--   * The talent NAMES below are RECORDED from
--     https://www.dota2.com/datafeed/herodata?language=english&hero_id=<id>, read
--     2026-08-22 and re-read 2026-08-26.  This test cannot reach the network;
--     what it can enforce is the repo-local half (which index each row selects,
--     that the source still says what the record says, and that the generated
--     snapshot says the same thing).
--   * Name-to-index NO LONGER rests on a display list (GH #214).  It is measured
--     against the game's own npc_heroes.txt, where a hero's talents are a
--     contiguous run of "AbilityN" "special_bonus_*" entries and N is the slot
--     bot:GetAbilityInSlot indexes -- the same argument GH #209 made for
--     abilities.  Corroboration on 2026-08-26: Valve's datafeed order equalled
--     that KV run on 22 of 22 heroes read (176 rows), while odota's display list
--     disagreed with both on 18 of them.  Section 1 never depended on this at
--     all -- it is arithmetic on the index.  For Axe there are two further
--     corroborations in the shipped file itself: talent7 is consumed as a
--     Berserker's Call radius bonus and [7] is the Call AoE talent; talent8 is
--     consumed as Culling Blade kill damage and [8] is the Culling damage talent.
--   * Nothing here is a claim about how often a talent pays out in a real game.
--     The Axe change is argued from cast conditions and this file's own build
--     order; no replay corpus was read for it.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local BOTLIB = 'bots/BotLib/'

-- The five focus heroes, and what the datafeed said their eight talents were on
-- 2026-08-22 (indices 1-4) and 2026-08-27 (indices 5-8, added when the "only 1-4
-- matter in turbo" premise fell -- see the header).
--
-- Indices 5-8 are read from Valve's datafeed BY HAND, the same way 1-4 were, and
-- NOT copied out of tests/mock/talent_slots.lua.  Section 5 exists to catch the
-- two sources disagreeing, and it can only do that while they are two sources;
-- copying one into the other is precisely how GH #214 happened.  Read
-- 2026-08-27 from https://www.dota2.com/datafeed/herodata?hero_id=<id> for all
-- five heroes: 40 of 40 rows agreed with the KV-derived snapshot, indices 5-8
-- included.
local FOCUS = {
    axe = {
        id = 2,
        talents = {
            'special_bonus_unique_axe_culling_blade_speed_duration',
            'special_bonus_unique_axe_8',
            'special_bonus_unique_axe',
            'special_bonus_unique_axe_7',
            'special_bonus_strength_15',
            'special_bonus_unique_axe_4',
            'special_bonus_unique_axe_2',
            'special_bonus_unique_axe_5',
        },
        -- t20/t25 RECORDED 2026-08-27, first pricing, NOT changed. The row takes
        -- [5] +15 Strength over [6] +40 Counter Helix damage, and [7] +85
        -- Berserker's Call AoE over [8] +150 Culling Blade damage. Both are the
        -- upstream OpenHyperAI defaults; neither has ever been argued in this
        -- repo. Two things this file's own reads say about the pair, recorded
        -- here because they are consequences, not opinions:
        --   * hero_axe.lua reads BOTH talent7 and talent8, but a hero takes one
        --     talent per tier -- so with the row on [7], `talent8:IsTrained()`
        --     is structurally false for the whole game and the nKillDamage term
        --     it guards is dead code, not merely a zero read (GH #232 priced the
        --     read; this prices the guard). Whoever takes `hero-2` inherits both
        --     halves of that.
        --   * `talent7:IsTrained()` becomes TRUE for the first time at level 25.
        --     GH #228 ruled that read harmless because the engine folds the +85
        --     into the base `radius` the site already reads -- and until this
        --     round that ruling was also protected by the branch being
        --     unreachable. It is not any more: the fold argument is now the only
        --     thing holding it. It still holds; it is now load-bearing.
        expect = { t10 = 2, t15 = 3, t20 = 5, t25 = 7 },
    },
    crystal_maiden = {
        id = 5,
        talents = {
            'special_bonus_hp_200',
            'special_bonus_intelligence_12',
            'special_bonus_unique_crystal_maiden_frostbite_castrange',
            'special_bonus_unique_crystal_maiden_5',
            'special_bonus_unique_crystal_maiden_glacial_guard_mana_multiplier',
            'special_bonus_unique_crystal_maiden_3',
            'special_bonus_unique_crystal_maiden_1',
            'special_bonus_unique_crystal_maiden_2',
        },
        -- t20/t25 RECORDED 2026-08-27, first pricing, NOT changed. The row takes
        -- [6] +50 Freezing Field damage over [5] +20% Glacial Guard mana-to-
        -- barrier, and [7] +1.0s Frostbite duration over [8] +300 Crystal Nova
        -- damage. Upstream defaults, never argued here. Crystal Maiden is the
        -- focus hero the counter-example frame actually carries at level 22
        -- (pending fixture, 23:02), so this is not a hypothetical tier for her.
        -- t10 EXAMINED 2026-08-23 and deliberately NOT changed, so it is not
        -- re-litigated on taste: the +12 INT side has a real, measurable payoff
        -- (9 of 26 ready ability slots on in-domain frames are mana-blocked
        -- inside the +144 it buys), but the +200 HP side's payoff channel --
        -- surviving damage -- has ZERO in-domain samples in this corpus, so its
        -- zero is UNDERPOWERED, not EMPTY (GH #115), and standard play prefers
        -- the health on the squishiest hero on the map. Full analysis, the
        -- evidence that would reopen it, and the honest bounds:
        -- tests/test_cm_t10_payoff.lua. t15 was decided in the same series
        -- (GH #122) and also holds.
        expect = { t10 = 1, t15 = 3, t20 = 6, t25 = 7 },
    },
    zuus = {
        id = 22,
        talents = {
            'special_bonus_unique_zeus',
            'special_bonus_hp_200',
            'special_bonus_unique_zeus_4',
            'special_bonus_unique_zeus_6',
            'special_bonus_unique_zeus_2',
            'special_bonus_unique_zeus_3',
            'special_bonus_unique_zeus_5',
            'special_bonus_unique_zeus_jump_charges',
        },
        -- t20/t25 RECORDED 2026-08-27, first pricing, NOT changed. The row takes
        -- [5] +60 Arc Lightning damage over [6] +0.5s Lightning Bolt ministun,
        -- and [7] AoE Lightning Bolt (325 radius) over [8] +3 Heavenly Jump
        -- charges. Upstream defaults, never argued here.
        -- t15 CHANGED 2026-08-22, [3] -> [4]: the +75 Thundergod's Wrath damage row
        -- can only pay on a cast that happens, and on this corpus the ult is
        -- ready-and-unaffordable on 7 of 16 ready frames.  [4] takes 20% off the mana
        -- cost of Arc Lightning, the ability that empties the pool.  Full analysis and
        -- its honest bounds: tests/test_focus_t15_payoff.lua and the rationale block
        -- in hero_zuus.lua.
        expect = { t10 = 2, t15 = 4, t20 = 5, t25 = 7 },
    },
    lion = {
        id = 26,
        talents = {
            'special_bonus_unique_lion_6',
            'special_bonus_movement_speed_20',
            'special_bonus_unique_lion_5',
            'special_bonus_unique_lion_11',
            'special_bonus_unique_lion_8',
            'special_bonus_unique_lion_10',
            'special_bonus_unique_lion_4',
            'special_bonus_unique_lion_2',
        },
        -- t20/t25 RECORDED 2026-08-27, first pricing, NOT changed -- and THIS is
        -- the row the axis was worth opening for. The t25 row takes [8]
        -- special_bonus_unique_lion_2 (+600 Earth Spike cast range), i.e. exactly
        -- the half that makes every `talent8` read in hero_lion.lua answer TRUE
        -- while believing it means "Hex is an AoE spell now". The talent that
        -- actually gives Hex a radius is [7]. GH #166 landed the narrowing
        -- (soak candidate 'lionhexaoe') and closed with "domain is empty" --
        -- BECAUSE NO HERO IN THE CORPUS REACHED LEVEL 25. That premise is the
        -- one this round retired. From level 25 on, a shipped turbo Lion trains
        -- [8], X.IsHexAoe answers true, and the W dispatch swaps
        -- ActionQueue_UseAbilityOnEntity for ActionQueue_UseAbilityOnLocation on
        -- a UNIT_TARGET ability. 'lionhexaoe' is not an empty-domain candidate
        -- any more; re-open GH #166 before pricing this pair on taste.
        -- t10 CHANGED 2026-08-22, [1] -> [2]: the +10pp Mana Drain slow is only
        -- collectible while channelling on an enemy hero, and X.ConsiderE reaches
        -- those two branches only when Earth Spike, Hex and Finger are ALL
        -- unavailable; +20 move speed has no predicate.  Full analysis and its
        -- honest bounds: tests/test_lion_t10_payoff.lua and the rationale block in
        -- hero_lion.lua.  t15 was examined in the same pass and deliberately left
        -- alone -- see the same block.
        expect = { t10 = 2, t15 = 4, t20 = 6, t25 = 8 },
    },
    skeleton_king = {
        id = 42,
        talents = {
            'special_bonus_unique_wraith_king_2',
            'special_bonus_unique_wraith_king_facet_1',
            'special_bonus_unique_wraith_king_11',
            -- RE-CORRECTED 2026-08-26 (GH #214) back to what it was before
            -- 2026-08-24.  The 08-24 edit put hp_350 here and recorded its
            -- reason as "odota + the hero KV read hp_350" -- two agreeing
            -- sources.  It cannot have been two: npc_dota_hero_skeleton_king.txt
            -- carries AbilityValues override keys and no talent NAMES at all, so
            -- a generic row like this one can never appear in it.  The one real
            -- source was odota's display list, and it is a patch behind.  Valve's
            -- own datafeed (hero_id 42, read 2026-08-26) says
            -- special_bonus_hp_300 with special_values value = 300, and the
            -- game's npc_heroes.txt agrees: "Ability13" "special_bonus_hp_300".
            -- Used only in assertion messages, so nothing shipped moved either
            -- time -- what moved is whether the record can be trusted.
            'special_bonus_hp_300',
            'special_bonus_attack_speed_50',
            'special_bonus_unique_wraith_king_facet_3',
            'special_bonus_unique_wraith_king_10',
            'special_bonus_unique_wraith_king_4',
        },
        -- t20/t25 RECORDED 2026-08-27, first pricing, NOT changed. The row takes
        -- [6] +5 Bone Guard skeletons over [5] +50 attack speed, and [7] -2s
        -- Mortal Strike cooldown over [8] Reincarnation casts Wraithfire Blast.
        -- Upstream defaults, never argued here. Two of them are FACET rows
        -- (facet_1, facet_3) -- whether they are even offered depends on the
        -- facet the game rolled, which nothing in this repo reads; do not price
        -- this pair without settling that first.
        expect = { t10 = 2, t15 = 4, t20 = 6, t25 = 7 },
    },
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Lines with comments stripped, so a ratchet on live code never trips on the prose
--- that documents the defect.  Block comments go first: the npc dumps are `--[[ ]]`
--- blocks whose inner lines do not start with `--`, and this file's Axe ratchet
--- exists precisely because that block still quotes the stale names.
local function live_lines(src)
    local out = {}
    for line in src:gsub('%-%-%[%[.-%]%]', ''):gmatch('[^\n]+') do
        if not line:match('^%s*%-%-') then out[#out + 1] = line end
    end
    return out
end

--- The tTalentTreeList literal of a hero file, as { t10 = {a,b}, ... }.
local function talent_rows(hero)
    local src = read_file(BOTLIB .. 'hero_' .. hero .. '.lua')
    local body = src:match('local tTalentTreeList = {(.-)\n}')
    assert(body, 'hero_' .. hero .. '.lua has no tTalentTreeList literal')
    local rows = {}
    for tier, a, b in body:gmatch("%['(t%d+)'%]%s*=%s*{%s*(%d+)%s*,%s*(%d+)%s*}") do
        rows[tier] = { tonumber(a), tonumber(b) }
    end
    for _, tier in ipairs({ 't10', 't15', 't20', 't25' }) do
        assert(rows[tier], 'hero_' .. hero .. '.lua is missing the ' .. tier .. ' row')
    end
    return rows
end

local function with_skill_lib(hero, fn)
    api.reset_modules()
    api.install({ bot = api.MakeHero('npc_dota_hero_' .. hero) })
    local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
    return fn(J)
end

-- ---------------------------------------------------------------------------
-- 1. The wiring, read out of the code.
--
-- KNOWN BLIND SPOT, recorded because a mutation found it rather than reasoning:
-- this section pins which index PAIR a tier row drives, not which pick SLOT
-- receives it.  Re-pointing pick[1] at the t20 row (mutation M3) leaves the moved
-- set at {1,2} -- because pick[5] still moves with t10 -- and walks straight
-- through here.  Section 2 catches it on four of five heroes, which is the reason
-- the per-hero resolution is driven through the real function instead of being a
-- table of expected indices.

tests['[hero] GetTalentBuild drives indices 1,2 from t10 and 3,4 from t15'] = function()
    with_skill_lib('axe', function(J)
        local function baseline()
            return { t10 = { 10, 0 }, t15 = { 10, 0 }, t20 = { 10, 0 }, t25 = { 10, 0 } }
        end
        local base = J.Skill.GetTalentBuild(baseline())

        -- Flip ONE row and see which returned picks move.  Asserting "pick 1 is the
        -- t10 one" instead would let a mutation that re-points a row at another
        -- tier walk straight through -- that is how GH #104 lost its first draft.
        local function indices_driven_by(key)
            local cfg = baseline()
            cfg[key] = { 0, 10 }
            local flipped = J.Skill.GetTalentBuild(cfg)
            local seen, out = {}, {}
            for pick = 1, 8 do
                if flipped[pick] ~= base[pick] then
                    for _, idx in ipairs({ base[pick], flipped[pick] }) do
                        if not seen[idx] then seen[idx] = true; out[#out + 1] = idx end
                    end
                end
            end
            table.sort(out)
            return table.concat(out, ',')
        end

        assert(indices_driven_by('t10') == '1,2',
            'the t10 row drives sTalentList indices {' .. indices_driven_by('t10')
            .. '}, not {1,2}. Every talent claim in the focus hero files is written '
            .. 'against that pairing -- re-read them all before changing it.')
        assert(indices_driven_by('t15') == '3,4',
            'the t15 row drives sTalentList indices {' .. indices_driven_by('t15')
            .. '}, not {3,4}.')
    end)
end

tests['[hero] {0,10} takes the odd index of a pair and {10,0} the even one'] = function()
    with_skill_lib('axe', function(J)
        local odd = J.Skill.GetTalentBuild({ t10 = { 0, 10 }, t15 = { 0, 10 }, t20 = { 0, 10 }, t25 = { 0, 10 } })
        local even = J.Skill.GetTalentBuild({ t10 = { 10, 0 }, t15 = { 10, 0 }, t20 = { 10, 0 }, t25 = { 10, 0 } })
        assert(odd[1] == 1 and odd[2] == 3, 'expected {0,10} to select indices 1 and 3 at t10/t15, got ' .. odd[1] .. ' and ' .. odd[2])
        assert(even[1] == 2 and even[2] == 4, 'expected {10,0} to select indices 2 and 4 at t10/t15, got ' .. even[1] .. ' and ' .. even[2])
    end)
end

-- ---------------------------------------------------------------------------
-- 2. What each focus hero actually picks, driven through the same function.

for hero, spec in pairs(FOCUS) do
    tests['[hero] ' .. hero .. ' resolves all four talent tiers to the recorded pick'] = function()
        local rows = talent_rows(hero)
        with_skill_lib(hero, function(J)
            local picks = J.Skill.GetTalentBuild(rows)
            local named = function(idx) return '[' .. idx .. '] ' .. spec.talents[idx] end
            assert(picks[1] == spec.expect.t10,
                hero .. ' now takes ' .. named(picks[1]) .. ' at level 10; the record '
                .. '(datafeed hero_id ' .. spec.id .. ', read 2026-08-22) says '
                .. named(spec.expect.t10) .. '. A talent change is a shippable, '
                .. 'ungated change -- but the stream charter wants the reasoning '
                .. 'written into the hero file, so put it there and update this row.')
            assert(picks[2] == spec.expect.t15,
                hero .. ' now takes ' .. named(picks[2]) .. ' at level 15; the record '
                .. 'says ' .. named(spec.expect.t15) .. '.')
            assert(picks[3] == spec.expect.t20,
                hero .. ' now takes ' .. named(picks[3]) .. ' at level 20; the record '
                .. '(datafeed hero_id ' .. spec.id .. ', read 2026-08-27) says '
                .. named(spec.expect.t20) .. '. This tier was pinned on 2026-08-27, '
                .. 'when the reason not to pin it -- "turbo never reaches level 20" -- '
                .. 'turned out to be an artefact of the 10-minute batch cap that '
                .. 'owner priority P3 removed.')
            assert(picks[4] == spec.expect.t25,
                hero .. ' now takes ' .. named(picks[4]) .. ' at level 25; the record '
                .. 'says ' .. named(spec.expect.t25) .. '.')
        end)
    end
end

-- The pins above are only worth having if the record they compare against is a
-- record of TODAY's ladder.  Slots 5-8 were added to FOCUS on 2026-08-27 and
-- nothing else in this file would notice if a hero were left with four.
tests['[hero] every focus hero has all eight talent slots recorded'] = function()
    for hero, spec in pairs(FOCUS) do
        assert(#spec.talents == 8,
            hero .. ' records ' .. #spec.talents .. ' talents, not 8. t20/t25 resolve '
            .. 'to indices 5-8, so a four-entry record makes the assertion messages '
            .. 'above print nil for exactly the two tiers this section was extended '
            .. 'to cover.')
        for _, tier in ipairs({ 't10', 't15', 't20', 't25' }) do
            assert(spec.expect[tier], hero .. ' has no recorded ' .. tier .. ' pick.')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 3. The Axe t10 change, and the rationale that has to travel with it.

tests['[hero] axe t10 takes the Battle Hunger move speed talent, not the Culling kill buff'] = function()
    local rows = talent_rows('axe')
    assert(rows.t10[1] ~= 0,
        "hero_axe.lua's t10 row is back to the odd index, i.e. "
        .. 'special_bonus_unique_axe_culling_blade_speed_duration (+3s on a buff that '
        .. 'only exists AFTER a Culling Blade hero kill). It was changed on '
        .. '2026-08-22 to special_bonus_unique_axe_8 (+8% move speed per ACTIVE '
        .. 'Battle Hunger) because Battle Hunger is the first point the build buys, '
        .. 'is maxed by level 11 (the row\'s 10th entry -- level 10 goes on a '
        .. 'talent, GH #134), and is fired from four branches of X.ConsiderW, '
        .. 'while this Axe never holds a Blink Dagger in turbo (GH #56) and so walks '
        .. 'to every fight. Reverting is allowed -- but say why in the file.')
    with_skill_lib('axe', function(J)
        assert(J.Skill.GetTalentBuild(rows)[1] == 2,
            'axe t10 must resolve to sTalentList[2]; got ' .. J.Skill.GetTalentBuild(rows)[1])
    end)
end

tests['[hero] the axe t10 rationale is still in the hero file'] = function()
    local src = read_file(BOTLIB .. 'hero_axe.lua')
    for _, needle in ipairs({
        'special_bonus_unique_axe_8',              -- what is taken
        'per ACTIVE Battle Hunger',                -- why it pays often
        'HONEST BOUND',                            -- what it gives up
        'datafeed',                                -- where the numbers came from
    }) do
        assert(src:find(needle, 1, true),
            'the t10 rationale block in hero_axe.lua no longer mentions "' .. needle
            .. '". A talent pick that ships without a gate IS its rationale -- the '
            .. 'file is the only place the reasoning lives.')
    end
end

tests['[hero] the inverted 7.2x t15 comment is gone from hero_axe.lua'] = function()
    local src = read_file(BOTLIB .. 'hero_axe.lua')
    assert(not src:find('+35 attack speed over +2 mana regen', 1, true),
        'the old t15 comment is back. It named two talents the hero no longer has, '
        .. 'and it was backwards even for them: {0,10} takes the odd index, which in '
        .. 'that ladder was special_bonus_mp_regen_2 -- the row picked the talent the '
        .. 'comment says it rejects.')
end

-- ---------------------------------------------------------------------------
-- 4. The stale ladder may be quoted, never used.

tests['[hero] no focus hero uses a 7.2x axe talent name as live data'] = function()
    local stale = {
        'special_bonus_strength_8',
        'special_bonus_movement_speed_20_axe',   -- guard against a copy of the old row
        'special_bonus_mp_regen_2',
        'special_bonus_attack_speed_35',
        'special_bonus_hp_regen_20',
        'special_bonus_unique_axe_3',
    }
    for _, line in ipairs(live_lines(read_file(BOTLIB .. 'hero_axe.lua'))) do
        for _, name in ipairs(stale) do
            assert(not line:find(name, 1, true),
                name .. ' is live data in hero_axe.lua again. It is a 7.2x talent the '
                .. 'hero no longer has -- re-read the datafeed before trusting it: ' .. line)
        end
    end
end

tests['[hero] hero_axe.lua still reads exactly the two t25 talent handles'] = function()
    local reads = {}
    for _, line in ipairs(live_lines(read_file(BOTLIB .. 'hero_axe.lua'))) do
        -- Both halves matter and they are NOT the same claim: the identifier says
        -- which tier the reader believes it is on, the subscript says which one it
        -- is actually on.  A first draft read only the identifier, and renaming
        -- nothing while re-pointing sTalentList[7] at [5] walked through it.
        for idx in line:gmatch('talent(%d)') do reads[tonumber(idx)] = true end
        for idx in line:gmatch('sTalentList%[(%d)%]') do reads[tonumber(idx)] = true end
    end
    local seen = {}
    for idx in pairs(reads) do seen[#seen + 1] = idx end
    table.sort(seen)
    assert(table.concat(seen, ',') == '7,8',
        'hero_axe.lua now reads talent handles {' .. table.concat(seen, ',')
        .. '}, not {7,8}. Indices 7,8 are the two halves of the t25 pair. This used '
        .. 'to be filed as harmless on the grounds that GH #84 measured level >= 20 '
        .. 'on 0 of 210 hero-slots -- that zero was the 10-minute batch cap, not '
        .. 'turbo (GH #235), and both reads are reachable now. A hero takes ONE '
        .. 'talent per tier, and this file\'s t25 row takes [7]: talent7 is live '
        .. 'from level 25 and talent8 is structurally untrained, so the two reads '
        .. 'are NOT the same kind of thing any more. A read of index 1-4 is a LIVE '
        .. 'read and needs its own accounting (GH #104 section 4 splits these into '
        .. 'ADDITIVE and STRUCTURAL).')
end

-- ---------------------------------------------------------------------------
-- 5. The record above and the generated snapshot must name the same talents.
--
-- WHY (GH #214).  Both files answer "what is sTalentList[N] for this hero", and
-- from 2026-08-24 to 2026-08-26 they answered differently for Wraith King's
-- slot 4 -- the record said special_bonus_hp_350, the snapshot said the same,
-- and hero_skeleton_king.lua's own comment said hp_300, which was the right
-- one.  Nothing was watching the pair, so the disagreement was invisible until
-- somebody read all three by hand.  This closes that: regenerating the snapshot
-- after a patch now fails HERE until the record is re-read from the datafeed,
-- which is the moment a human is supposed to look at it anyway.
--
-- Direction matters.  This is a CONSISTENCY test, not a correctness one: both
-- files being wrong in the same way still passes.  The thing that makes them
-- right is the source, and the source is asserted in the census tool
-- (tools/agent/talent_slot_census.py --cross-check exits 3 when Valve's
-- datafeed disagrees with the KV run it snapshots).

tests['[hero] the recorded talent names match tests/mock/talent_slots.lua'] = function()
    local snapshot = dofile('tests/mock/talent_slots.lua').SLOTS
    for hero, spec in pairs(FOCUS) do
        local rows = snapshot[hero]
        assert(rows, 'tests/mock/talent_slots.lua has no rows for ' .. hero
            .. '. Regenerate it: python3 tools/agent/talent_slot_census.py --snapshot')
        for idx, name in ipairs(spec.talents) do
            assert(rows[idx] and rows[idx].name == name,
                hero .. ' slot [' .. idx .. ']: this file records "' .. name
                .. '", tests/mock/talent_slots.lua says "'
                .. ((rows[idx] and rows[idx].name) or '<missing>')
                .. '". These are the same claim read from two places, so one of '
                .. 'them is stale. The snapshot is generated from the game\'s '
                .. 'npc_heroes.txt; this record is read by hand from Valve\'s '
                .. 'datafeed (hero_id ' .. spec.id .. '). Re-read the datafeed '
                .. 'and fix whichever one disagrees with it -- do NOT just copy '
                .. 'one into the other, which is how GH #214 happened.')
        end
    end
end

tests['[hero] the snapshot still carries all eight talent rows per focus hero'] = function()
    local snapshot = dofile('tests/mock/talent_slots.lua').SLOTS
    for hero in pairs(FOCUS) do
        local rows = snapshot[hero]
        for idx = 1, 8 do
            assert(rows[idx] and rows[idx].name ~= '',
                hero .. ' is missing snapshot slot [' .. idx .. ']. sTalentList '
                .. 'is a COMPACTED list (aba_skill.X.GetTalentList table.inserts '
                .. 'every IsTalent() handle it walks past), so a hero with fewer '
                .. 'than eight talent rows renumbers every index after the gap '
                .. 'and every talentN binding in that hero file starts naming a '
                .. 'different talent, silently.')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 6. WHERE in the level-up queue the four tiers actually sit.
--
-- WHY THIS SECTION EXISTS.  The moment t20/t25 stopped being dead rows, the
-- first thing a reader worries about is whether the queue asks for them too
-- early -- because ability_item_usage_generic.lua consumes sSkillList strictly
-- from the head and does NOT skip an entry it cannot level: the branch that
-- removes an unlevelable head is guarded by `botLevel > 25`, so a premature
-- talent at the head would stall every later entry behind it.  That worry is
-- answerable without the engine, and the answer is that the queue is right.
--
-- Positions, driven out of the real function below: talents land at list
-- positions 10, 15, 18, 19, 20, 21, 22, 23 -- NOT at 10/15/20/25.  That reads
-- wrong and is right, because a list position is not a hero level: it is the
-- Nth ability point SPENT, which is how the consumer itself reads it
-- (ability_item_usage_generic.lua computes `nPointsSpent = botLevel -
-- bot:GetAbilityPoints()` and trims that many entries off the front).  A hero
-- spends 15 points on abilities and one at each of levels 10/15/20/25, so
-- positions 1-17 are the 15 abilities plus the t10 and t15 talents, position 18
-- is the 18th point -- level 20 -- and position 19 is the 19th -- level 25.
-- The tiers land exactly where they belong.
--
-- WORLD ASSERTION, registered not asserted: that a hero receives ability points
-- at levels 1-15 and at 10/15/20/25 and at no other level.  Nothing offline can
-- evaluate it -- the mock answers a constant for GetAbilityPoints() -- and the
-- arithmetic above is the only thing that makes positions 18/19 mean levels
-- 20/25.  If it is wrong, this section's positions are still right and their
-- INTERPRETATION is wrong, which is the failure worth being able to find later.
--
-- WHAT IS NOT REACHED.  Positions 20-23 are nTalentBuildList[5..8] -- the OTHER
-- half of each already-taken tier, permanently unlevelable.  Under the same
-- arithmetic there is no 20th ability point, so they are never dequeued and the
-- `botLevel > 25` escape never has to fire.  Recorded because "the tail is dead
-- weight" and "the tail jams the queue" are different claims and only the first
-- one is true.

tests['[hero] the t20 and t25 picks are queued as the 18th and 19th ability points'] = function()
    with_skill_lib('axe', function(J)
        local abilities = { 'A1', 'A2', 'A3', 'A4', 'A5', 'A6' }
        local build = { 2, 3, 1, 3, 3, 6, 3, 2, 2, 2, 6, 1, 1, 1, 6 }  -- hero_axe.lua's own row
        local talents = { 'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8' }
        local picks = J.Skill.GetTalentBuild(talent_rows('axe'))
        local list = J.Skill.GetSkillList(abilities, build, talents, picks)

        local at = {}
        for pos, name in ipairs(list) do
            if name:match('^T%d$') then at[#at + 1] = pos end
        end
        assert(table.concat(at, ',') == '10,15,18,19,20,21,22,23',
            'talents are queued at list positions {' .. table.concat(at, ',')
            .. '}, not {10,15,18,19,20,21,22,23}. A list position is the Nth '
            .. 'ability point spent, and the whole reason the t20/t25 picks are '
            .. 'safe at 18 and 19 is that a hero has spent exactly 17 points by '
            .. 'the time it can take a t20 talent. Re-read section 6 before '
            .. 'accepting a new layout: the consumer takes the head of this queue '
            .. 'and will not skip an entry it cannot level below level 26.')

        -- Which PICK sits at 18/19, not merely that something does. Asserting the
        -- positions alone would survive a GetTalentBuild that returned its four
        -- tier picks in any order.
        assert(list[18] == talents[picks[3]] and list[19] == talents[picks[4]],
            'the entries at positions 18 and 19 are ' .. tostring(list[18]) .. '/'
            .. tostring(list[19]) .. ', not the t20 and t25 picks ('
            .. tostring(talents[picks[3]]) .. '/' .. tostring(talents[picks[4]])
            .. '). The tier order in the queue is what makes "position 18 = level 20" '
            .. 'a statement about t20 at all.')
    end)
end

tests['[hero] the level-up consumer still cannot skip a head it fails to level'] = function()
    local src = read_file('bots/ability_item_usage_generic.lua')
    assert(src:find('if botLevel > 25 then', 1, true),
        'ability_item_usage_generic.lua no longer guards its only unlevelable-head '
        .. 'escape on `botLevel > 25`. Section 6 argues that the t20/t25 picks are '
        .. 'safe at queue positions 18/19 GIVEN that a stalled head is expensive; '
        .. 'if the consumer learned to skip, that argument is about a cost that no '
        .. 'longer exists and section 6 should be re-read, not deleted.')
end

return tests

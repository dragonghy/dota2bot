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
--   2. the resolved t10/t15 index of all five focus heroes, parsed from their own
--      source.  t20/t25 are recorded but not pinned: GH #84's level census read
--      level >= 20 on 0 of 210 hero-slots (high-water 19), so in turbo they are
--      dead rows and pinning them would only create noise;
--   3. Axe's t10 change of 2026-08-22 (index [1] -> [2]) together with the
--      rationale block that has to travel with it;
--   4. a ratchet that the dead 7.2x talent names never come back as live data.
--
-- HONEST BOUNDS
--   * The talent NAMES below are RECORDED from
--     https://www.dota2.com/datafeed/herodata?language=english&hero_id=<id>, read
--     2026-08-22.  This test cannot reach the network; what it can enforce is the
--     repo-local half (which index each row selects, and that the source still says
--     what the record says).
--   * Name-to-index rests on the feed listing talents in ability-slot order, which
--     is the order J.Skill.GetTalentList returns.  Section 1 does not depend on it
--     at all -- it is arithmetic on the index.  For Axe there are two independent
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
-- 2026-08-22.  Only indices 1-4 (t10, t15) matter in turbo; 5-8 are recorded for
-- the next reader and deliberately not pinned.
local FOCUS = {
    axe = {
        id = 2,
        talents = {
            'special_bonus_unique_axe_culling_blade_speed_duration',
            'special_bonus_unique_axe_8',
            'special_bonus_unique_axe',
            'special_bonus_unique_axe_7',
        },
        expect = { t10 = 2, t15 = 3 },
    },
    crystal_maiden = {
        id = 5,
        talents = {
            'special_bonus_hp_200',
            'special_bonus_intelligence_12',
            'special_bonus_unique_crystal_maiden_frostbite_castrange',
            'special_bonus_unique_crystal_maiden_5',
        },
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
        expect = { t10 = 1, t15 = 3 },
    },
    zuus = {
        id = 22,
        talents = {
            'special_bonus_unique_zeus',
            'special_bonus_hp_200',
            'special_bonus_unique_zeus_4',
            'special_bonus_unique_zeus_6',
        },
        -- t15 CHANGED 2026-08-22, [3] -> [4]: the +75 Thundergod's Wrath damage row
        -- can only pay on a cast that happens, and on this corpus the ult is
        -- ready-and-unaffordable on 7 of 16 ready frames.  [4] takes 20% off the mana
        -- cost of Arc Lightning, the ability that empties the pool.  Full analysis and
        -- its honest bounds: tests/test_focus_t15_payoff.lua and the rationale block
        -- in hero_zuus.lua.
        expect = { t10 = 2, t15 = 4 },
    },
    lion = {
        id = 26,
        talents = {
            'special_bonus_unique_lion_6',
            'special_bonus_movement_speed_20',
            'special_bonus_unique_lion_5',
            'special_bonus_unique_lion_11',
        },
        -- t10 CHANGED 2026-08-22, [1] -> [2]: the +10pp Mana Drain slow is only
        -- collectible while channelling on an enemy hero, and X.ConsiderE reaches
        -- those two branches only when Earth Spike, Hex and Finger are ALL
        -- unavailable; +20 move speed has no predicate.  Full analysis and its
        -- honest bounds: tests/test_lion_t10_payoff.lua and the rationale block in
        -- hero_lion.lua.  t15 was examined in the same pass and deliberately left
        -- alone -- see the same block.
        expect = { t10 = 2, t15 = 4 },
    },
    skeleton_king = {
        id = 42,
        talents = {
            'special_bonus_unique_wraith_king_2',
            'special_bonus_unique_wraith_king_facet_1',
            'special_bonus_unique_wraith_king_11',
            'special_bonus_hp_300',
        },
        expect = { t10 = 2, t15 = 4 },
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
    tests['[hero] ' .. hero .. ' resolves its turbo-reachable talents to the recorded pair'] = function()
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
        end)
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

tests['[hero] both axe talent handles are still t25, so turbo reads nothing from them'] = function()
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
        .. '}, not {7,8}. Indices 7,8 are the t25 pair and GH #84 measured level >= '
        .. '20 on 0 of 210 hero-slots, so both were dead weight in turbo. A read of '
        .. 'index 1-4 is a LIVE read and needs its own accounting (GH #104 section 4 '
        .. 'splits these into ADDITIVE and STRUCTURAL).')
end

return tests

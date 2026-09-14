-- [hero] [ratchet] GH #817's "talent uptake is a per-hero CONSTANT" is three
-- different things wearing one sentence, and the biggest of the three is the
-- instrument.
--
-- ⚠️ THE TAG IS LOAD-BEARING, 2026-09-14.  It landed a round late: this file
-- went in untagged and with no lua_gate_manifest.json row, so 开工自检's next
-- run reported it as NEW UNCOVERED (GH #806) -- nothing automatic would have
-- run it, and its red would have been found by whichever desk started work
-- next.  Do not drop [ratchet] to "tidy" the header.
-- 2026-09-14.  Zero behaviour change, zero gate: this file registers what a
-- wave-level talent read CAN and CANNOT see, not a decision about the bots.
--
-- WHAT #817 MEASURED (8 games, W40 = dem21/spot_20260902_214528_1_..._ab6c0d,
-- the `2146xx` batch, slot1-8; that tree is OFF-TRUNK -- it is the tree the
-- batch instance cloned, not a ref you can resolve on origin/main):
--
--   nevermore / obsidian_destroyer / vengefulspirit   0 talents in 8/8 games
--   skeleton_king                                     1 talent, first at hero
--                                                     level 18-20, 0/8 at 10
--   shadow_shaman / crystal_maiden / witch_doctor /
--   skywrath_mage / bristleback / death_prophet       1-2 talents, 7-8/8 spend
--                                                     at hero level 10
--
-- and it read "34/80 bodies spent nothing at hero level 10" off the same meter.
--
-- THE JOIN NOBODY HAD MADE.  #817 says the split is a constant per hero and
-- does not say what the hero-valued input is.  It is one property of the row
-- the hero's OWN build selects at t10: whether that row is a hero-unique
-- `special_bonus_unique_*` row or a generic one.  The dumper drops hero-unique
-- talents by construction -- isRealAbility() in the dumper discards any entity
-- whose class name carries Special_Bonus_Base / Special_Bonus_Attributes
-- BEFORE the branch that keeps leveled talents, and hero-unique rows share
-- that base class while generic rows have their own (H1, settled 2026-08-27,
-- tests/test_fixture_talent_blindness.lua).  A talent the dumper dropped raises
-- no ability-ledger count, so a point spent on it is a point #817's meter
-- cannot see -- and "no spend at hero level 10" is exactly what it prints.
--
-- Section 2 is the whole finding: the t10 row's kind partitions #817's own ten
-- heroes with EXACTLY ONE exception, and the exception misses in the direction
-- a SECOND, already-documented defect predicts.
--
-- THE THREE ACCOUNTS, kept apart on purpose (this is the point of the file):
--   * nevermore, vengefulspirit -- all four of their selected rows are unique,
--     so their VISIBLE talent ceiling is 0 and the observed 0 is the ceiling,
--     not a reading about the bots.  Nothing here says they take their talents;
--     it says this corpus cannot tell.
--   * obsidian_destroyer -- its t10 pick is GENERIC (`special_bonus_mp_200`),
--     i.e. visible, and it still reads 0/8.  Blindness does not cover it.  The
--     repo already carries the other account: the nil-hole collapse of
--     sAbilityLevelUpList (GH #286, quoted in bots/ability_item_usage_generic.lua:
--     "OD stalled at 6 spent points in 5/6 games"), and #817's own numbers
--     corroborate it (5-6 ability points at the end, median idle 1279.5 s, and
--     every one of the eight >=900 s idle bodies is OD).
--   * skeleton_king -- t10 unique (invisible), t15 generic (visible), t20/t25
--     unique.  Its VISIBLE ceiling is exactly 1 and the wave read exactly 1, in
--     8 of 8 games.  Section 4 pins that coincidence.
--
-- ⛔ WHAT THIS FILE DOES NOT ESTABLISH, and no offline read can
--   * That any bot actually trains any unique talent.  An entity the dumper
--     dropped is not in the file to be counted; H1 says the corpus is silent,
--     not that the answer is yes.  #817's acceptance 3 ("re-run the same ruler
--     and watch 34/80 come down") is therefore UNMEASURABLE for the three
--     unique-t10 heroes no matter what is fixed -- the meter is blind on those
--     rows by construction, so the number cannot move for them.  That is the
--     operational consequence of this file and the reason it was written before
--     anyone spends a wave on it.
--   * Skeleton King's RESIDUAL.  Blindness predicts his first VISIBLE talent at
--     hero level 15 (the t15 pick is generic); #817 read 18-20.  That 3-5 level
--     lag is NOT explained here and stays open -- section 4 asserts the ceiling,
--     never the timing.  A live candidate nobody can settle offline: whether
--     `special_bonus_hp_300` has its own C++ class at all, or falls back to the
--     dropped base like the unique rows do (only `special_bonus_hp_200` has
--     actually been SEEN in a dump; hp_300 has not).
--   * Anything about the other 117 heroes.  Ten heroes, one wave, one tree.
--
-- SLOT ORDER is read out of the two generated snapshots this repo already
-- keeps (tests/mock/hero_slots.lua, tests/mock/talent_slots.lua), and the
-- left/right SELECTION rule is read out of aba_skill.lua rather than re-typed,
-- so a patch that moves a row or a refactor that flips the rule reddens this
-- file instead of silently re-pointing its conclusion.

package.path = 'tests/?.lua;' .. package.path

local SLOTS = dofile('tests/mock/hero_slots.lua')
local TALENTS = dofile('tests/mock/talent_slots.lua')

local ABA = 'bots/FunLib/aba_skill.lua'
local DUMPER = 'tools/batch_test/behavioral/dumper/main.go'
local GENERIC = 'bots/ability_item_usage_generic.lua'

-- Ability10 / Ability11 upstream are the t10 pair, and hero_slots.lua re-keys
-- "AbilityN" to the 0-based slot bot:GetAbilityInSlot uses, so they land here.
local T10_SLOT = { [1] = 9, [2] = 10 }

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Which of the t10 pair this hero's own build selects, 1 = left / 2 = right.
--- The rule is aba_skill.X.GetTalentBuild's; section 1 asserts it still reads
--- the way this function assumes before any row is looked up.
local function t10_pick(hero)
    local src = read_file('bots/BotLib/hero_' .. hero .. '.lua')
    local tree = src:match('tTalentTreeList%s*=%s*(%b{})')
    assert(tree, hero .. ': no tTalentTreeList in its BotLib file')
    local first = tree:match("%['t10'%]%s*=%s*{%s*(%d+)%s*,")
    assert(first, hero .. ": no ['t10'] = { n, m } row in tTalentTreeList")
    return (tonumber(first) == 0) and 1 or 2
end

local function is_unique(name)
    return name:sub(1, #'special_bonus_unique_') == 'special_bonus_unique_'
end

--- The row this hero's build actually takes at t10, and whether the dumper can
--- see it.  Fails loudly rather than guessing if the slot is not a talent at
--- all: slots 9/10 hold the t10 pair only for heroes whose ability run ends
--- before them (invoker's slot 9 is invoker_emp), and every hero here is one.
local function t10_row(hero)
    local map = SLOTS[hero]
    assert(map, hero .. ': absent from tests/mock/hero_slots.lua')
    local pick = t10_pick(hero)
    local name = map[T10_SLOT[pick]]
    assert(type(name) == 'string' and name:sub(1, #'special_bonus_') == 'special_bonus_',
        hero .. ": slot " .. T10_SLOT[pick] .. " holds '" .. tostring(name)
        .. "', not a talent -- this hero's ability run reaches into the talent "
        .. "slots and the t10 pair is not at 9/10 for it")
    return name, pick
end

-- GH #817's wave table, transcribed.  `lv10` is "games in which this hero spent
-- a point at hero level 10", out of 8; `talents` is the end-of-game talent count
-- the same meter read.  Cut (iron rule 4(iii)): body = (hero name, first idx
-- that name appears), spend = the frame the ability ledger rises, talents
-- baselined at 0.  Not an armed/baseline comparison -- one tree, whole roster,
-- both teams every game, so there is no leg to stratify and no ab/ba reading
-- exists for it.
local WAVE = {
    { hero = 'obsidian_destroyer', talents = 0, lv10 = 0 },
    { hero = 'vengefulspirit',     talents = 0, lv10 = 0 },
    { hero = 'nevermore',          talents = 0, lv10 = 0 },
    { hero = 'skeleton_king',      talents = 1, lv10 = 0 },
    { hero = 'shadow_shaman',      talents = 1, lv10 = 7 },
    { hero = 'crystal_maiden',     talents = 1, lv10 = 7 },
    { hero = 'witch_doctor',       talents = 1, lv10 = 8 },
    { hero = 'skywrath_mage',      talents = 1, lv10 = 8 },
    { hero = 'bristleback',        talents = 1, lv10 = 8 },
    { hero = 'death_prophet',      talents = 2, lv10 = 8 },
}

-- ---------------------------------------------------------------------------
-- 1. The selection rule this file's arithmetic rests on, read out of the
--    source.  Without this the whole partition below could be pointing at the
--    wrong half of every pair and still look tidy.

tests['[hero] GetTalentBuild still takes the LEFT row on {0,n} and the RIGHT row on {n,0}'] =
function()
    local src = read_file(ABA)
    local on_zero, on_nonzero = src:match(
        "%[1%]%s*=%s*%(%s*tTalentTreeList%['t10'%]%[1%]%s*==%s*0%s*and%s*(%d)%s*or%s*(%d)%s*%)")
    assert(on_zero, ABA .. ': GetTalentBuild no longer spells its t10 rule as '
        .. "`tTalentTreeList['t10'][1] == 0 and <n> or <m>`. Every row in this "
        .. 'file is a lookup through that rule -- re-read it before re-pointing them')
    assert(tonumber(on_zero) == 1 and tonumber(on_nonzero) == 2,
        'GetTalentBuild maps {0,n}->' .. on_zero .. ' and {n,0}->' .. on_nonzero
        .. ', this file assumes 1 and 2')
end

-- ---------------------------------------------------------------------------
-- 2. THE FINDING.  One property of the selected t10 row partitions #817's ten
--    heroes, and the single miss is the hero a second documented defect names.

tests['[hero] the selected t10 row being hero-unique predicts #817\'s "no spend at level 10", 9 of 10'] =
function()
    local misses, seen = {}, 0
    for _, row in ipairs(WAVE) do
        local name = t10_row(row.hero)
        local invisible = is_unique(name)
        -- The prediction: invisible row <=> the meter reads no spend at 10.
        local predicted_zero = invisible
        local observed_zero = (row.lv10 == 0)
        seen = seen + 1
        if predicted_zero ~= observed_zero then
            misses[#misses + 1] = row.hero .. " (t10='" .. name .. "' "
                .. (invisible and 'UNIQUE' or 'generic') .. ', lv10=' .. row.lv10 .. '/8)'
        end
    end
    assert(seen == 10, 'expected #817\'s ten heroes, walked ' .. seen)
    table.sort(misses)
    assert(#misses == 1 and misses[1]:sub(1, #'obsidian_destroyer') == 'obsidian_destroyer',
        'the t10-kind partition is supposed to miss on obsidian_destroyer and '
        .. 'nothing else -- OD is the hero GH #286 already measured stalling at '
        .. '6 spent points in 5/6 games, so it misses where a SECOND defect '
        .. 'predicts. Actual misses: ' .. (next(misses) and table.concat(misses, '; ') or 'none'))
end

tests['[hero] every hero #817 read as "0 talents in 8/8" has an invisible t10 row -- except OD'] =
function()
    for _, row in ipairs(WAVE) do
        if row.talents == 0 then
            local name = t10_row(row.hero)
            if row.hero == 'obsidian_destroyer' then
                assert(not is_unique(name), "OD's t10 pick is recorded GENERIC ("
                    .. "'special_bonus_mp_200'), which is what makes its zero a "
                    .. 'reading about the bots and not about the dumper. It now '
                    .. "reads '" .. name .. "'")
            else
                assert(is_unique(name), row.hero .. " reads 0 talents in 8/8 games "
                    .. "and its t10 pick '" .. name .. "' is GENERIC, i.e. the dumper "
                    .. 'CAN see it. That breaks the blindness account for this hero '
                    .. 'and makes its zero a live defect again -- do not quote this '
                    .. 'file as covering it')
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- 3. The mechanism, read out of the dumper's source rather than re-typed.  A
--    dropped entity leaves no trace in the dump by construction, so no fixture
--    can ever witness the drop; what this pins is that the code still says what
--    the account needs it to say.

tests['[hero] the dumper still drops base-class talents before the leveled-talent branch'] =
function()
    local src = read_file(DUMPER)
    local body = src:match('func isRealAbility%b()%s*bool%s*(%b{})')
    assert(body, DUMPER .. ': isRealAbility no longer parses -- the whole '
        .. 'instrument-blindness account is read off this function')
    local drop = body:find('Special_Bonus_Base', 1, true)
    local keep = body:find('level > 0', 1, true)
    assert(drop, 'isRealAbility no longer names Special_Bonus_Base')
    assert(keep, 'isRealAbility no longer keeps leveled talents with `level > 0`')
    assert(drop < keep, 'the Special_Bonus_Base drop used to run BEFORE the '
        .. '`level > 0` keep, which is why a TRAINED unique talent never reaches '
        .. 'the dump. They are now the other way round, so unique rows may be '
        .. 'visible and #817\'s zeros may be real -- re-read this whole file')
end

-- ---------------------------------------------------------------------------
-- 4. Skeleton King: the ceiling, and only the ceiling.
--
--    Of his four selected rows exactly one -- the t15 pick -- is generic, so
--    the most talents this meter can EVER show him is 1.  #817 read exactly 1,
--    in 8 of 8 games, zero variance.  That is his ceiling, so the reading
--    carries no information about how many he took.
--    ⛔ The timing residual (first visible talent at 18-20, ceiling says 15) is
--    deliberately NOT asserted here: it is unexplained, and pinning it would
--    dress an open question as a settled one.

local function visible_ceiling(hero)
    local rows = TALENTS.SLOTS[hero]
    assert(rows, hero .. ': absent from tests/mock/talent_slots.lua')
    local src = read_file('bots/BotLib/hero_' .. hero .. '.lua')
    local tree = src:match('tTalentTreeList%s*=%s*(%b{})')
    local n, picks = 0, {}
    for i, tier in ipairs({ 't10', 't15', 't20', 't25' }) do
        local first = tree:match("%['" .. tier .. "'%]%s*=%s*{%s*(%d+)%s*,")
        assert(first, hero .. ': no ' .. tier .. ' row')
        local slot = (i - 1) * 2 + ((tonumber(first) == 0) and 1 or 2)
        local name = rows[slot].name
        picks[#picks + 1] = tier .. "='" .. name .. "'"
        if not is_unique(name) then n = n + 1 end
    end
    return n, table.concat(picks, ' ')
end

tests['[hero] Wraith King\'s visible talent ceiling is exactly 1, and #817 read exactly 1'] =
function()
    local n, picks = visible_ceiling('skeleton_king')
    assert(n == 1, 'exactly one of WK\'s four selected talent rows is generic '
        .. '(the t15 pick, special_bonus_hp_300); a corpus can show him at most '
        .. 'that one. Now ' .. n .. ': ' .. picks)
    for _, row in ipairs(WAVE) do
        if row.hero == 'skeleton_king' then
            assert(row.talents == n, "#817 read WK at " .. row.talents
                .. ' end-of-game talents and his visible ceiling is ' .. n
                .. ' -- when those stop being equal the reading has started '
                .. 'carrying information about uptake, and this file must say so')
        end
    end
end

tests['[hero] Axe is invisible at ALL FOUR tiers -- no corpus talent read on him means anything'] =
function()
    local n, picks = visible_ceiling('axe')
    assert(n == 0, 'all four of Axe\'s selected talent rows used to be hero-unique, '
        .. 'so his visible ceiling is 0 and "Axe took no talents" is unsayable '
        .. 'from any dump this repo holds. Now ' .. n .. ' generic: ' .. picks)
end

tests['[hero] the other three focus heroes are visible at t10 and blind above it'] =
function()
    for _, hero in ipairs({ 'zuus', 'lion', 'crystal_maiden' }) do
        local n, picks = visible_ceiling(hero)
        assert(n == 1, hero .. ": exactly the t10 pick is generic, so a corpus "
            .. 'can show at most one of its four talents. Now ' .. n .. ': ' .. picks)
    end
end

-- ---------------------------------------------------------------------------
-- 5. Why the queue-freeze account does NOT cover the unique-t10 heroes, pinned
--    at the one half of the argument that is assertable.
--
--    The competing story for "no spend at hero level 10" is that the queue head
--    (slot 10 is the first talent, aba_skill.lua's slot rule) could not be
--    upgraded and the point was banked -- the `skillstall` shape, GH #799.  It
--    does not fit #817's own frame: nevermore idx=1352 spends at t=376.1 (hero
--    level 9) and again at t=504.1 (hero level 11) on `nevermore_frenzy1`, an
--    ability, i.e. an entry BEHIND the head was consumed one level later.  The
--    terminal `else` removes nothing below hero level 26, so a head that fell
--    into it cannot let the next entry through at level 11.  Whatever happened
--    at slot 10, the head was consumed -- which is what training the talent
--    looks like from outside.
--
--    ⛔ Assertable half only: that the terminal `else` still removes nothing.
--    The frame reading itself is #817's, quoted, not re-derived here.

tests['[hero] the level-up dispatcher\'s terminal else still removes nothing from the queue'] =
function()
    local src = read_file(GENERIC)
    local tail = src:match('elseif%s+not%s+abilityToLevelup:IsHidden%(%).-\n(%s*else\n.-\n%s*end)')
    assert(tail, GENERIC .. ': the level-up dispatcher no longer parses')
    assert(not tail:find('table.remove( sAbilityLevelUpList, 1 )', 1, true),
        'the terminal `else` now removes the head. That was the branch whose '
        .. 'NOT removing anything is why a stuck head freezes the queue -- and '
        .. 'section 5\'s argument (an entry behind the head was consumed at '
        .. 'level 11, so the head was not stuck) rests on it')
end

return tests

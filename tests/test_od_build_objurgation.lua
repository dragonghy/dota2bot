-- [ratchet] [hero] GH #287 §2 -- soak candidate 'odbuild': the one mis-resolved
-- index in Obsidian Destroyer's skill build, aimed at the ability the row's own
-- arithmetic says it meant.
--
-- Tagged `[ratchet]` so routine_selfcheck.sh's fast Lua leg reads it every round
-- (~0.11s): §5 and §6 go red the moment someone edits the shipped row, renames
-- the gate id, or promotes it -- events that must be noticed the same round,
-- not whenever the ~100-minute full suite next completes (GH #124/#267).
--
-- WHAT THE DEFECT IS.  J.Skill.GetAbilityList walks the engine's slots; OD's
-- real slot row (the game's npc_heroes.txt, mirrored into tests/mock/hero_slots.lua)
-- puts `generic_hidden` at slot 3, so the list the hero levels from reads
--   [1] arcane_orb  [2] astral_imprisonment  [3] objurgation
--   [4] generic_hidden  [5] equilibrium (innate)  [6] sanity_eclipse
-- and the shipped row `{2,1,4,2,2,6,2,1,1,1,6,4,4,4,6}` spends FOUR points on
-- [4] while never naming [3].  tests/test_build_index_resolution.lua §4 measured
-- that placeholder reference in 2 of 2 drop-worlds -- the only unconditional one
-- in the repo.
--
-- ⭐ WHY THE REPLAY FRAME IS THE POINT OF THIS FILE, not the arithmetic.
-- tests/fixtures/f_260819_222559_od_eclipse_solo.lua is a real instant
-- (20260819_222559_slot1 @ t=661.5, 11:01) whose subject is a real bot-played
-- Obsidian Destroyer at HERO LEVEL 11 holding `obsidian_destroyer_objurgation`
-- at RANK 0, with 1448 of 1658 mana in the pool.  The shipped row predicts
-- exactly that -- rank 0 at every level, forever -- and no row that names index
-- 3 can produce it.  The barrier this hero never buys is the one that scales
-- with the mana pool he is standing there holding.
--
-- ⚠️ LIMITS -- READ BEFORE CITING
--   * WHICH INDEX NAMES WHAT comes from the KV slot row, NOT from the frame.
--     The dumper writes a FLATTENED ability list (filtered entries dropped), so
--     the fixture's own OD carries four abilities and no placeholder at all --
--     §6 pins that difference rather than hiding it.  The frame is authority on
--     the RANK objurgation actually held; the KV is authority on the index.
--   * The frame is from 2026-08-19, before GH #286's compaction landed, so its
--     OD is ALSO inside the six-point stall #290 measured.  Nothing here reads
--     the other ranks as a clean execution of the shipped row -- only
--     objurgation's zero, which both defects predict and neither explains away.
--   * Static + one frame.  Whether the armed row wins games is condition (a)
--     and (b), and is asked of a wave, not of this file.
--   * The fix is GATED ('odbuild', turbo-only).  Nothing below claims shipped
--     behaviour changed; §5 asserts the opposite.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')
local meta = require('mock.ability_meta')

local FRAME       = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua'
local SOURCE      = 'bots/BotLib/hero_obsidian_destroyer.lua'
local SLOTS_LUA   = 'tests/mock/hero_slots.lua'
local HERO        = 'obsidian_destroyer'
local UNIT        = 'npc_dota_hero_' .. HERO
local PLACEHOLDER = 'generic_hidden'
local OBJURGATION = 'obsidian_destroyer_objurgation'
local SHIPPED_TABLE = 'tAllAbilityBuildList'
local GATED_TABLE   = 'tObjurgationBuildList'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

local SRC   = read_file(SOURCE)
local SLOTS = dofile(SLOTS_LUA)
local ULTS  = meta.ULTIMATES[UNIT] or {}

--- The first numeric row of one named build-list literal in the hero source.
local function build_row(sTable)
    local sBlock = SRC:match('\nlocal ' .. sTable .. '%s*=%s*(%b{})')
    assert(sBlock, SOURCE .. ' has no `local ' .. sTable .. '` literal. Either the '
        .. 'gated row was removed (odbuild promoted or reverted -- say which) or the '
        .. 'file changed shape; this test reads the SHIPPED source, not a copy.')
    for sLine in sBlock:gmatch('[^\n]+') do
        local sInner = sLine:gsub('%-%-.*$', ''):match('{%s*([%d%s,]+)%s*}')
        if sInner then
            local tRow = {}
            for sN in sInner:gmatch('%d+') do tRow[#tRow + 1] = tonumber(sN) end
            if #tRow > 0 then return tRow end
        end
    end
    error(sTable .. ' carries no numeric row')
end

--- A bot serving OD's real KV slot order to the shipped walk.  `bDropInnate`
--- is the one thing offline code cannot decide (IsHidden() is engine-only), so
--- both worlds are driven wherever it could matter.
local function slot_bot(bDropInnate)
    return api.MakeUnit{
        GetUnitName = UNIT,
        GetAbilityInSlot = function(_, nSlot)
            local sName = SLOTS[HERO][nSlot]
            if sName == nil or sName == '' then sName = PLACEHOLDER end
            local bDropped = bDropInnate and sName == 'obsidian_destroyer_equilibrium'
            return api.MakeUnit{
                GetName     = sName,
                IsUltimate  = ULTS[sName] == true,
                IsTalent    = sName:match('^special_bonus') ~= nil,
                IsHidden    = bDropped,
                GetBehavior = bDropped and DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE or 0,
            }
        end,
    }
end

--- name -> rank held once `tRow` has been spent, driving the SHIPPED
--- J.Skill.GetSkillList so the talent interleave is the real one (GH #134: the
--- row index is not the hero level).  Entries naming nothing learnable are
--- returned separately -- they are the cost being measured.
local function ranks_from(J, tRow, bDropInnate, nUpToLevel)
    local hBot = slot_bot(bDropInnate)
    local tAbil = J.Skill.GetAbilityList(hBot)
    local tTalent = { 'special_bonus_a', 'special_bonus_b', 'special_bonus_c',
                      'special_bonus_d', 'special_bonus_e', 'special_bonus_f',
                      'special_bonus_g', 'special_bonus_h' }
    local tTalentBuild = { 1, 3, 5, 7 }
    local tList = J.Skill.GetSkillList(tAbil, tRow, tTalent, tTalentBuild)

    local tRanks, tWasted = {}, 0
    for i = 1, (nUpToLevel or 30) do
        local sName = tList[i]
        if sName == PLACEHOLDER then
            tWasted = tWasted + 1
        elseif sName ~= nil and sName:match('^special_bonus') == nil then
            tRanks[sName] = (tRanks[sName] or 0) + 1
        end
    end
    return tRanks, tWasted, tAbil, tList
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The frame: a real bot-played OD holding objurgation at rank 0.

tests['[1] the replay frame shows objurgation at rank 0 on a level-11 OD'] = function()
    local J, bot, heroes, fx = rf.load(FRAME)
    assert(J ~= nil and bot ~= nil, 'the fixture did not load')
    assert(fx.self == UNIT,
        'fixture subject is ' .. tostring(fx.self) .. ', expected ' .. UNIT
            .. ' -- this file is anchored to an OD frame and nothing else')

    local hOD = heroes[UNIT]
    assert(hOD ~= nil, UNIT .. ' is not in the frame roster')
    assert(hOD:GetLevel() == 11,
        'the frame OD is level ' .. tostring(hOD:GetLevel()) .. ', recorded 11')

    local tSeen = {}
    for _, u in ipairs(fx.units) do
        if u.name == UNIT then
            for _, a in ipairs(u.abilities or {}) do tSeen[a.name] = a.level end
        end
    end
    assert(tSeen[OBJURGATION] ~= nil,
        OBJURGATION .. ' is absent from the frame dump entirely -- the fixture was '
            .. 'regenerated or the ability was renamed; re-read GH #287 before '
            .. 'trusting anything below')
    assert(tSeen[OBJURGATION] == 0,
        'the frame OD holds ' .. OBJURGATION .. ' at rank ' .. tostring(tSeen[OBJURGATION])
            .. ', recorded 0. A non-zero rank here would mean the shipped build DOES '
            .. 'reach index 3 in a real game, and the whole premise of odbuild is wrong.')

    -- The mana pool is why the barrier is worth four points on this hero.
    assert(hOD:GetMana() >= 1400 and hOD:GetMaxMana() >= 1600,
        'the frame OD holds ' .. tostring(hOD:GetMana()) .. '/'
            .. tostring(hOD:GetMaxMana()) .. ' mana, recorded 1448/1658 -- the barrier '
            .. 'X.ConsiderObjurgation prices scales with exactly this pool')
end

-- ---------------------------------------------------------------------------
-- 2. Index resolution, driven through the shipped walk on OD's real slot row.

tests['[2] the shipped walk puts objurgation at index 3 and the placeholder at 4'] = function()
    local J = rf.load(FRAME)
    for _, bDrop in ipairs({ false, true }) do
        local _, _, tAbil = ranks_from(J, build_row(SHIPPED_TABLE), bDrop)
        assert(tAbil[3] == OBJURGATION,
            'sAbilityList[3] is ' .. tostring(tAbil[3]) .. ' (innate dropped='
                .. tostring(bDrop) .. '), expected ' .. OBJURGATION
                .. '. odbuild aims four points at index 3 -- if that index moved, the '
                .. 'gated row now aims at something else and must be re-derived.')
        assert(tAbil[4] == PLACEHOLDER,
            'sAbilityList[4] is ' .. tostring(tAbil[4]) .. ', expected ' .. PLACEHOLDER
                .. ' -- that is the defect GH #287 §2 exists for')
        assert(tAbil[6] == 'obsidian_destroyer_sanity_eclipse',
            'sAbilityList[6] is ' .. tostring(tAbil[6]) .. '; the ultimate must still '
                .. 'land on the fixed index 6, which is why #287 §2 candidate (a) was '
                .. 'a no-op for this hero')
    end
end

-- ---------------------------------------------------------------------------
-- 3. The shipped row, unarmed: four points buy nothing and objurgation stays 0.

tests['[3] unarmed, the shipped row wastes 4 points and never trains objurgation'] = function()
    local J = rf.load(FRAME)
    local tRow = build_row(SHIPPED_TABLE)
    local nRefs4 = 0
    for _, n in ipairs(tRow) do if n == 4 then nRefs4 = nRefs4 + 1 end end
    assert(nRefs4 == 4,
        'the shipped row references index 4 ' .. nRefs4 .. ' times, recorded 4. That '
            .. 'count IS the cost; if it changed, the shipped row was edited and this '
            .. 'gate is no longer measuring what it was written for.')

    for _, bDrop in ipairs({ false, true }) do
        local tRanks, nWasted = ranks_from(J, tRow, bDrop)
        assert(nWasted == 4,
            'the shipped row queues ' .. nWasted .. ' placeholder entries (innate '
                .. 'dropped=' .. tostring(bDrop) .. '), recorded 4')
        assert(tRanks[OBJURGATION] == nil,
            'the shipped row now trains ' .. OBJURGATION .. ' to rank '
                .. tostring(tRanks[OBJURGATION]) .. '. It reached rank 0 in the frame '
                .. '(§1); the two readings must agree.')
        assert(tRanks['obsidian_destroyer_arcane_orb'] == 4
            and tRanks['obsidian_destroyer_astral_imprisonment'] == 4
            and tRanks['obsidian_destroyer_sanity_eclipse'] == 3,
            'the shipped row no longer maxes orb/astral and takes three ultimate '
                .. 'points; the odbuild row was written to keep those identical')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The armed row: same 15 points, all fifteen of them landing on an ability.

tests['[4] armed, odbuild trains objurgation to 4 and wastes nothing'] = function()
    local J = rf.load(FRAME)
    local tRow = build_row(GATED_TABLE)
    for _, bDrop in ipairs({ false, true }) do
        local tRanks, nWasted = ranks_from(J, tRow, bDrop)
        assert(nWasted == 0,
            'the odbuild row still queues ' .. nWasted .. ' placeholder entries '
                .. '(innate dropped=' .. tostring(bDrop) .. ') -- the whole change is '
                .. 'that it queues none')
        assert(tRanks[OBJURGATION] == 4,
            OBJURGATION .. ' reaches rank ' .. tostring(tRanks[OBJURGATION])
                .. ' under the odbuild row, expected 4 (OD\'s three basics take four '
                .. 'ranks each; that is the arithmetic the shipped row\'s 4+4+4+3 = 15 '
                .. 'already assumes)')
        assert(tRanks['obsidian_destroyer_arcane_orb'] == 4
            and tRanks['obsidian_destroyer_astral_imprisonment'] == 4
            and tRanks['obsidian_destroyer_sanity_eclipse'] == 3,
            'odbuild moved a point that was not the placeholder\'s. It is an index '
                .. 'repair, not a rethink of the build -- see §5.')
    end
end

-- ---------------------------------------------------------------------------
-- 5. The two rows differ in exactly the four placeholder positions, and the
--    default branch is untouched.

tests['[5] odbuild differs from the shipped row only where the placeholder was'] = function()
    local tShipped, tGated = build_row(SHIPPED_TABLE), build_row(GATED_TABLE)
    assert(#tShipped == #tGated and #tShipped == 15,
        'rows are ' .. #tShipped .. ' and ' .. #tGated .. ' entries, both recorded 15')
    local tDiff = {}
    for i = 1, #tShipped do
        if tShipped[i] ~= tGated[i] then
            tDiff[#tDiff + 1] = i
            assert(tShipped[i] == 4 and tGated[i] == 3,
                ('position %d changed %d -> %d; odbuild is defined as 4 -> 3 and '):format(
                    i, tShipped[i], tGated[i])
                    .. 'nothing else. Any other edit belongs in its own candidate id '
                    .. 'so a wave can tell the two apart.')
        end
    end
    assert(#tDiff == 4,
        'the rows differ in ' .. #tDiff .. ' positions, recorded 4')
end

tests['[6] the gate is turbo-only, named odbuild, and leaves the default row live'] = function()
    assert(SRC:find("J%.IsModeTurbo%(%) and J%.IsSoakCandidate%(%s*'odbuild'%s*%)"),
        SOURCE .. ' no longer gates on `J.IsModeTurbo() and J.IsSoakCandidate(\'odbuild\')`. '
            .. 'A behaviour change in this repo ships dark and turbo-only until it is '
            .. 'promoted; if odbuild WAS promoted, this assertion is the one to rewrite, '
            .. 'together with iterations/state.json.')
    local sElse = SRC:match("IsSoakCandidate%(%s*'odbuild'%s*%).-else(.-)\nend")
    assert(sElse and sElse:find(SHIPPED_TABLE, 1, true),
        'the unarmed branch no longer selects ' .. SHIPPED_TABLE
            .. '. Unarmed behaviour must stay byte-equivalent to what shipped.')
    local sThen = SRC:match("IsSoakCandidate%(%s*'odbuild'%s*%) then(.-)else")
    assert(sThen and sThen:find(GATED_TABLE, 1, true),
        'the armed branch no longer selects ' .. GATED_TABLE)
end

-- ---------------------------------------------------------------------------
-- 6. Two things this file would otherwise let a reader assume.

tests['[7] ConsiderObjurgation is gated on castability, so rank 0 silences it'] = function()
    local sBody = SRC:match('function X%.ConsiderObjurgation%(%)(.-)\nend\n')
    assert(sBody, SOURCE .. ' has no X.ConsiderObjurgation. The claim "the fix wakes a '
        .. 'handler that has never run" depends on that handler existing.')
    local sFirst = sBody:match('^%s*(.-)\n')
    assert(sFirst and sFirst:find('Objurgation:IsFullyCastable()', 1, true),
        'X.ConsiderObjurgation no longer opens on Objurgation:IsFullyCastable() (first '
            .. 'line is: ' .. tostring(sFirst) .. '). That condition is the entire '
            .. 'reason rank 0 makes the handler unreachable -- if the guard moved, '
            .. 'recheck the claim instead of relaxing this.')
    assert(sBody:find('mana_pool_to_barrier_pct', 1, true),
        'the handler no longer reads mana_pool_to_barrier_pct -- the "barrier scales '
            .. 'with OD\'s pool" argument in §1 is read off this line')
end

tests['[8] the fixture\'s own slot list is NOT the authority on index 4'] = function()
    -- The dumper flattens: filtered entries never reach the .dem-derived fixture,
    -- so replay_fixture reconstructs slots 0,1,2 + ult at 5 and index 4 comes back
    -- nil, not `generic_hidden`.  Recorded on purpose: a future reader who drives
    -- the walk off the FRAME instead of the KV would measure the wrong mechanism
    -- (a nil hole, GH #286) and conclude odbuild targets something it does not.
    local J, bot = rf.load(FRAME)
    local tFromFrame = J.Skill.GetAbilityList(bot)
    assert(tFromFrame[3] == OBJURGATION,
        'even flattened, the frame keeps objurgation at index 3; got '
            .. tostring(tFromFrame[3]))
    assert(tFromFrame[4] ~= PLACEHOLDER,
        'the frame now carries the placeholder at index 4. If the dumper started '
            .. 'emitting filtered slots, this test can stop overlaying the KV row -- '
            .. 'and tests/test_build_index_resolution.lua can too.')
end

return tests

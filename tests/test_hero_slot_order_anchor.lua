-- [hero] `GRANTSLOT`, the other half: the SLOT ORDER itself, read out of the
-- game's KV instead of assumed.  GH #209.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- `sAbilityList[N]` means "the Nth ability `J.Skill.GetAbilityList` accepted
-- while walking `bot:GetAbilityInSlot(0..10)`" (bots/FunLib/aba_skill.lua).
-- Every argument about what index N names therefore starts from one input: the
-- hero's slot order.  Two landed soak candidates already rest on one --
-- `zusbind` (GH #203) and `cmclone` (GH #206) -- and both took it from the Dota
-- 2 datafeed's `abilities` array while saying, in as many words, that "that
-- GetAbilityInSlot enumerates the datafeed's order is an ASSUMPTION".
--
-- It is not an assumption any more.  `npc_heroes.txt` carries a literal
-- `"AbilityN"` map per hero; `tools/agent/hero_slot_map.py` reads it into
-- tests/mock/hero_slots.lua (one HTTPS GET, no per-hero fan-out, no AWS), and
-- section 2 below checks the two candidates' quoted tables against it row by
-- row.  Both match, so nothing lands here -- what changes is that they stop
-- being assumptions.
--
-- ⭐ WHAT THE KV SAYS THAT NOTHING IN THIS REPO COULD SAY BEFORE
--   Empty ability slots are not absent, they hold the literal name
--   `generic_hidden`, and the walk KEEPS those (`if slot ~= 0`).  That single
--   fact is the whole reason `X.GetAbilityList` can hardcode `slot >= 4` and
--   index 6: the KV convention is Ability1..3 = the basics, Ability4/5 = extras
--   or placeholders, Ability6 = the ultimate.  Axe is the clean case --
--
--       slot 0  axe_berserkers_call
--       slot 1  axe_battle_hunger
--       slot 2  axe_counter_helix
--       slot 3  generic_hidden
--       slot 4  generic_hidden
--       slot 5  axe_culling_blade      ultimate -> index 6
--       slot 6  axe_one_man_army       innate
--
--   -- and it settles by direct read a question the corpus could only answer
--   with an n=1 leg.  test_focus_innate_index_anchor.lua section 5 had to argue
--   that the dumped ability array is not slot order, because Axe dumps four
--   entries with the ultimate last, which under slot order would put the
--   ultimate at slot 3, fail `slot >= 4`, and leave `abilityR` bound to nil.
--   Its refutation was "Axe's ultimate is on cooldown on 1 of 26 frames".  The
--   KV refutes it outright: the ultimate is at slot 5 and the two slots ahead
--   of it are placeholders the dumper filters out.  That section stands; its
--   thinnest leg no longer has to carry anything.
--
-- WHAT IS MEASURED, AND WHY AXE AND LION NEED NO CANDIDATE
-- -------------------------------------------------------
-- Zeus and Crystal Maiden bind indices 4 and 5, which sit AFTER the optional
-- region (slots 3/4, where innates and shard/scepter grants live), so a drop
-- decision this repo cannot evaluate moves them -- that is what #203 and #206
-- had to gate.  Axe and Lion read only indices 1, 2, 3 and 6:
--
--   * nothing precedes slots 0/1/2, so NO drop decision anywhere can shift
--     indices 1..3.  This is structural, not a lucky world;
--   * their ultimates are at slot 5 >= 4, so index 6 is written directly and
--     does not depend on how many abilities came before it.
--
-- Section 3 does not take that on the argument's word: it drives the SHIPPED
-- walk over each hero's real slots in EVERY drop-world over its optional
-- occupants and asserts the four bindings are invariant -- and asserts, in the
-- same loop, that Crystal Maiden's index 4 is NOT invariant, so the
-- discriminator is measured rather than asserted.  Result: hero_axe.lua and
-- hero_lion.lua are correct on this axis in every world, and the focus five is
-- closed with no fifth candidate and no `bots/` change.
--
-- ⚠️ LIMITS -- READ BEFORE CITING
--   * The table says which ability sits in which SLOT.  It says nothing about
--     which ones the walk keeps: that turns on `NOT_LEARNABLE and IsHidden()`,
--     and `IsHidden()` is unreadable outside the game VM
--     (test_focus_innate_index_anchor.lua section 2; GH #206 added a one-way
--     corpus read of it, which is a read of PRESENCE only).
--   * It is a snapshot of the dotabuff/d2vpkr mirror taken when the generator
--     last ran, not a live read.  A patch that moves a slot makes every index
--     argument in this repo stale -- regenerate, then re-read #203 and #206.
--   * Slots 9/10 hold talent rows.  The walk filters them via `IsTalent()`,
--     which the mock answers `false` for (that is a harness fact, GH #151), so
--     nothing here asserts anything about indices produced past slot 6.
--   * Nothing here is a behaviour claim and nothing gates.  It is a
--     measurement that says two existing candidates modelled the world
--     correctly and that two other focus heroes need no candidate at all.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local SLOTS_LUA = 'tests/mock/hero_slots.lua'
local FRAME     = 'tests/fixtures/f_113638_cm_chain_rescue.lua'

local SLOTS = dofile(SLOTS_LUA)

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

-- The focus five, recorded from the generated table on 2026-08-26.  Written out
-- longhand rather than read back from SLOTS: a pin that reads its own source is
-- not a pin.
local FOCUS_SLOTS = {
    axe = {
        [0] = 'axe_berserkers_call',
        [1] = 'axe_battle_hunger',
        [2] = 'axe_counter_helix',
        [3] = 'generic_hidden',
        [4] = 'generic_hidden',
        [5] = 'axe_culling_blade',
        [6] = 'axe_one_man_army',
    },
    lion = {
        [0] = 'lion_impale',
        [1] = 'lion_voodoo',
        [2] = 'lion_mana_drain',
        [3] = 'lion_to_hell_and_back',
        [4] = 'generic_hidden',
        [5] = 'lion_finger_of_death',
        [6] = '',
    },
    crystal_maiden = {
        [0] = 'crystal_maiden_crystal_nova',
        [1] = 'crystal_maiden_frostbite',
        [2] = 'crystal_maiden_brilliance_aura',
        [3] = 'crystal_maiden_crystal_clone',
        [4] = 'crystal_maiden_glacial_guard',
        [5] = 'crystal_maiden_freezing_field',
        [6] = 'crystal_maiden_freezing_field_stop',
    },
    skeleton_king = {
        [0] = 'skeleton_king_hellfire_blast',
        [1] = 'skeleton_king_bone_guard',
        [2] = 'skeleton_king_mortal_strike',
        [3] = 'skeleton_king_vampiric_spirit',
        [4] = 'generic_hidden',
        [5] = 'skeleton_king_reincarnation',
        [6] = '',
    },
    zuus = {
        [0] = 'zuus_arc_lightning',
        [1] = 'zuus_lightning_bolt',
        [2] = 'zuus_heavenly_jump',
        [3] = 'zuus_cloud',
        [4] = 'zuus_lightning_hands',
        [5] = 'zuus_thundergods_wrath',
        [6] = 'zuus_static_field',
    },
}

local FOCUS = { 'axe', 'crystal_maiden', 'lion', 'skeleton_king', 'zuus' }

-- Each focus hero's ultimate and its slot, per the table above.  The walk only
-- writes index 6 from `slot >= 4`, so this pair is what makes `abilityR` work.
local ULT_SLOT = {
    axe = 5, crystal_maiden = 5, lion = 5, skeleton_king = 5, zuus = 5,
}

-- ---------------------------------------------------------------------------
-- A synthetic bot that serves one hero's real slot order to the shipped walk.
--
-- Fabricated handles, declared as such: no .dem carries slot order (the dumped
-- ability array is flattened, test_focus_innate_index_anchor.lua section 5), so
-- this is the only way to drive the shipped walk on a real layout.  Same shape
-- as the harness in test_cm_ability_index_binding.lua, generalised over heroes.

--- @param sHero string
--- @param tDrop table  set of slot indices whose occupant the walk drops
local function make_bot(sHero, tDrop)
    local nNotLearnable = DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE
    assert(type(nNotLearnable) == 'number' and nNotLearnable > 0,
        'the NOT_LEARNABLE constant must be a real number for this enumeration to mean '
            .. 'anything -- if it is nil the drop branch can never be taken and every '
            .. 'world below collapses into the same one')

    local tSlots = FOCUS_SLOTS[sHero]
    local nUlt = ULT_SLOT[sHero]

    return api.MakeUnit{
        GetUnitName = 'npc_dota_hero_' .. sHero,
        GetAbilityInSlot = function(_, nSlot)
            local sName = tSlots[nSlot]
            -- Past the recorded rows the engine hands back placeholders (and,
            -- at slots 9/10, talent rows).  Serving generic_hidden keeps the
            -- tail of the produced list the same length the engine's would be;
            -- leaving it out would silently shorten every world.
            if sName == nil or sName == '' then sName = 'generic_hidden' end
            local bDropped = tDrop[nSlot] == true
            return api.MakeUnit{
                GetName     = sName,
                IsUltimate  = nSlot == nUlt,
                IsTalent    = false,
                IsHidden    = bDropped,
                GetBehavior = bDropped and nNotLearnable or 0,
            }
        end,
    }
end

--- Which slots hold an ability whose keep/drop the walk actually decides.
--- `generic_hidden` is name-checked BEFORE the drop rule, so a placeholder is
--- never dropped however hidden it is; the basics and the ultimate are what the
--- file means to bind.  What is left is the optional region -- innates and
--- shard/scepter grants -- and that is what gets enumerated.
local function optional_slots(sHero)
    local out = {}
    local tSlots = FOCUS_SLOTS[sHero]
    for nSlot = 0, 6 do
        local sName = tSlots[nSlot]
        if sName ~= nil and sName ~= '' and sName ~= 'generic_hidden'
            and nSlot ~= ULT_SLOT[sHero] and nSlot > 2
        then
            out[#out + 1] = nSlot
        end
    end
    return out
end

--- Every subset of `tSlots`, as a set of dropped slot indices.
local function worlds(tSlots)
    local out = { {} }
    for _, nSlot in ipairs(tSlots) do
        local grown = {}
        for _, w in ipairs(out) do
            local copy = {}
            for k, v in pairs(w) do copy[k] = v end
            copy[nSlot] = true
            grown[#grown + 1] = w
            grown[#grown + 1] = copy
        end
        out = grown
    end
    return out
end

local function world_label(w)
    local parts = {}
    for nSlot in pairs(w) do parts[#parts + 1] = tostring(nSlot) end
    table.sort(parts)
    return #parts == 0 and 'dropped{}' or ('dropped{' .. table.concat(parts, ',') .. '}')
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The generated table is a KV read, and it covers what ships.

tests['[1] the slot table covers every shipped hero and has no empty rows'] = function()
    local nHeroes = 0
    for sHero, tRow in pairs(SLOTS) do
        nHeroes = nHeroes + 1
        assert(type(tRow) == 'table' and tRow[0] ~= nil,
            sHero .. ' has no slot 0 in ' .. SLOTS_LUA .. '. An empty row is a PARSE '
                .. 'HOLE, not a hero without abilities -- the upstream file dedents a '
                .. 'few hero headers and a depth-relative parser drops exactly those. '
                .. 'Re-run tools/agent/hero_slot_map.py and read its header note.')
    end
    assert(nHeroes == 127,
        SLOTS_LUA .. ' holds ' .. nHeroes .. ' heroes, recorded 127. If a hero was '
            .. 'added or removed, regenerate; if the count fell without a removal, the '
            .. 'parser lost blocks.')

    local p = assert(io.popen('ls bots/BotLib/hero_*.lua'))
    local nShipped, tMissing = 0, {}
    for sPath in p:lines() do
        local sHero = sPath:match('hero_(.+)%.lua$')
        -- lone_druid_bear is a summoned unit, not a hero: it has no KV block,
        -- and that is data rather than a hole (same carve-out as
        -- tools/agent/gen_ability_meta.py).
        if sHero ~= 'lone_druid_bear' then
            nShipped = nShipped + 1
            if SLOTS[sHero] == nil then tMissing[#tMissing + 1] = sHero end
        end
    end
    p:close()
    assert(#tMissing == 0,
        'shipped hero file(s) with no slot row: ' .. table.concat(tMissing, ', '))
    assert(nShipped == 127,
        'bots/BotLib ships ' .. nShipped .. ' hero files (excluding lone_druid_bear), '
            .. 'recorded 127.')
end

tests['[1] the focus five slot rows are what was recorded'] = function()
    for _, sHero in ipairs(FOCUS) do
        local tRow = SLOTS[sHero]
        assert(tRow ~= nil, 'no slot row for ' .. sHero)
        for nSlot = 0, 6 do
            assert(tRow[nSlot] == FOCUS_SLOTS[sHero][nSlot],
                sHero .. ' slot ' .. nSlot .. ' is ' .. tostring(tRow[nSlot])
                    .. ', recorded ' .. tostring(FOCUS_SLOTS[sHero][nSlot])
                    .. '. A patch that moves a slot invalidates EVERY sAbilityList '
                    .. 'index argument in this repo -- re-read GH #203 and #206 before '
                    .. 'updating this table.')
        end
    end
end

tests['[1] every focus ultimate is at slot >= 4, which is what writes index 6'] = function()
    for _, sHero in ipairs(FOCUS) do
        local nSlot = ULT_SLOT[sHero]
        assert(nSlot >= 4,
            sHero .. "'s ultimate is recorded at slot " .. nSlot .. '. Below 4 the walk '
                .. 'fails `IsUltimate() and slot >= 4`, appends the ultimate like an '
                .. 'ordinary ability, and leaves sAbilityList[6] -- i.e. abilityR -- '
                .. 'bound to nil.')
        assert(FOCUS_SLOTS[sHero][nSlot] ~= 'generic_hidden'
            and FOCUS_SLOTS[sHero][nSlot] ~= '',
            sHero .. ' has a placeholder at its recorded ultimate slot')
    end
end

-- ---------------------------------------------------------------------------
-- 2. The two landed candidates quoted a slot order as an assumption.  It holds.

--- Pull `--     slot N  name` rows out of a test file's header block.
local function quoted_slots(sPath)
    local out = {}
    for sLine in read_file(sPath):gmatch('[^\n]+') do
        local nSlot, sName = sLine:match('^%-%-+%s+slot%s+(%d+)%s+([%w_]+)')
        if nSlot then out[tonumber(nSlot)] = sName end
    end
    return out
end

tests['[2] GH #203 and #206 quoted the right slot order -- now measured, not assumed'] = function()
    local tCases = {
        { 'tests/test_zuus_ability_index_binding.lua', 'zuus', 7 },
        { 'tests/test_cm_ability_index_binding.lua',   'crystal_maiden', 6 },
    }
    for _, tCase in ipairs(tCases) do
        local sPath, sHero, nRows = tCase[1], tCase[2], tCase[3]
        local tQuoted = quoted_slots(sPath)
        local nSeen = 0
        for nSlot, sName in pairs(tQuoted) do
            nSeen = nSeen + 1
            assert(SLOTS[sHero][nSlot] == sName,
                sPath .. ' quotes slot ' .. nSlot .. ' as ' .. sName .. ', but the '
                    .. "game's KV says " .. tostring(SLOTS[sHero][nSlot]) .. '. That '
                    .. 'file gates a soak candidate on its slot order -- if the KV '
                    .. 'moved, the candidate is measuring the wrong thing and must be '
                    .. 're-derived, not merely re-commented.')
        end
        assert(nSeen == nRows,
            sPath .. ' now quotes ' .. nSeen .. ' slot rows in its header, recorded '
                .. nRows .. '. This cross-check is only worth what it covers, so say '
                .. 'what changed.')
    end
end

-- ---------------------------------------------------------------------------
-- 3. Drive the SHIPPED walk on real slot orders, in every drop-world.

tests['[3] Axe and Lion: indices 1/2/3 and 6 are invariant across every drop-world'] = function()
    local J = rf.load(FRAME)
    assert(J ~= nil and J.Skill ~= nil, 'the fixture loader no longer hands back J.Skill')

    -- What each file means by those indices, read off its own bindings:
    -- abilityQ/W/E are sAbilityList[1]/[2]/[3] and abilityR is [6].
    local tWant = {
        axe  = { [1] = 'axe_berserkers_call', [2] = 'axe_battle_hunger',
                 [3] = 'axe_counter_helix',   [6] = 'axe_culling_blade' },
        lion = { [1] = 'lion_impale', [2] = 'lion_voodoo',
                 [3] = 'lion_mana_drain', [6] = 'lion_finger_of_death' },
    }

    for _, sHero in ipairs({ 'axe', 'lion' }) do
        local tOptional = optional_slots(sHero)
        local tWorlds = worlds(tOptional)
        assert(#tWorlds == 2 ^ #tOptional and #tWorlds >= 2,
            sHero .. ' enumerated ' .. #tWorlds .. ' worlds over ' .. #tOptional
                .. ' optional slots; the enumeration is broken')
        for _, w in ipairs(tWorlds) do
            local tList = J.Skill.GetAbilityList(make_bot(sHero, w))
            for nIndex, sName in pairs(tWant[sHero]) do
                assert(tList[nIndex] == sName,
                    'hero_' .. sHero .. '.lua binds sAbilityList[' .. nIndex .. '] and '
                        .. 'in ' .. world_label(w) .. ' the shipped walk puts '
                        .. tostring(tList[nIndex]) .. ' there, not ' .. sName .. '. '
                        .. 'That file has no nil guard and no candidate on this axis '
                        .. 'because this assertion said it did not need one.')
            end
        end
    end
end

tests['[3] the discriminator is measured: Crystal Maiden index 4 is NOT invariant'] = function()
    -- Axe and Lion survive every world because nothing optional sits ahead of
    -- what they bind.  If that were true of Crystal Maiden too, section 3 would
    -- be proving nothing about the axis -- so the contrast is asserted, not
    -- assumed.  (What her index 4 holds in each world is #206's subject, and
    -- tests/test_cm_ability_index_binding.lua is where it is enumerated; here
    -- only the fact that it MOVES is pinned.)
    local J = rf.load(FRAME)
    local tSeen = {}
    for _, w in ipairs(worlds(optional_slots('crystal_maiden'))) do
        tSeen[tostring(J.Skill.GetAbilityList(make_bot('crystal_maiden', w))[4])] = true
    end
    local nDistinct = 0
    for _ in pairs(tSeen) do nDistinct = nDistinct + 1 end
    assert(nDistinct > 1,
        'Crystal Maiden index 4 is now the same in every drop-world (' .. nDistinct
            .. ' distinct occupant). If that is real, GH #206 gated a no-op and the '
            .. 'Axe/Lion result above stops being a discriminator -- re-derive both.')
end

tests['[3] the invariance is structural: nothing optional sits ahead of slot 3'] = function()
    -- The loop above measures; this says WHY, so a future reader does not read
    -- the green as luck.  Indices 1..3 come from slots 0/1/2, and no drop
    -- decision anywhere can move them because there is nothing in front.
    for _, sHero in ipairs({ 'axe', 'lion' }) do
        for _, nSlot in ipairs(optional_slots(sHero)) do
            assert(nSlot > 2,
                'hero_' .. sHero .. ' now has an optional ability at slot ' .. nSlot
                    .. ', i.e. ahead of or among the three basics. Indices 1..3 can '
                    .. 'shift now; hero_' .. sHero .. '.lua binds all three.')
        end
    end
    -- and the placeholder rule that makes an empty slot occupy an index anyway
    local sWalk = read_file('bots/FunLib/aba_skill.lua')
    assert(sWalk:find('if name == generic_hidden then', 1, true)
        and sWalk:find('if slot ~= 0 then', 1, true),
        'the walk no longer inserts generic_hidden for non-zero empty slots. Every '
            .. 'index past the first placeholder in the table above moves; re-derive '
            .. 'section 3.')
end

-- ---------------------------------------------------------------------------
-- 4. Roster-wide: who else reads an index, and which of them read past 3.
--    A ratchet, not a verdict -- the leads are for whoever claims the survey.

-- Shipped hero files that read sAbilityList[4] or [5], measured 2026-08-26.
-- Of the focus five only Crystal Maiden and Zeus are here, and both are already
-- routed behind a candidate (`cmclone`, `zusbind`).  The rest are leads: their
-- slot 3/4 occupants are innates or shard grants, so what index 4 names there
-- depends on the same unreadable drop rule -- see the report for the per-hero
-- layout.  Nothing about them is claimed here beyond membership.
local BINDS_PAST_3 = {
    'crystal_maiden', 'dazzle', 'juggernaut', 'kunkka', 'lich', 'muerta',
    'necrolyte', 'nevermore', 'ogre_magi', 'omniknight', 'oracle',
    'phantom_assassin', 'riki', 'slark', 'sniper', 'witch_doctor', 'zuus',
}

tests['[4] the set of hero files reading sAbilityList[4]/[5] has not grown'] = function()
    local tExpect = {}
    for _, sHero in ipairs(BINDS_PAST_3) do tExpect[sHero] = true end

    local p = assert(io.popen('ls bots/BotLib/hero_*.lua'))
    local tGot, nFiles = {}, 0
    for sPath in p:lines() do
        nFiles = nFiles + 1
        local sHero = sPath:match('hero_(.+)%.lua$')
        local sSrc = read_file(sPath)
        for sIndex in sSrc:gmatch('sAbilityList%[(%d+)%]') do
            local n = tonumber(sIndex)
            if n == 4 or n == 5 then tGot[sHero] = true end
        end
    end
    p:close()
    assert(nFiles == 128, 'scanned ' .. nFiles .. ' hero files, recorded 128')

    for sHero in pairs(tGot) do
        assert(tExpect[sHero],
            'hero_' .. sHero .. '.lua now reads sAbilityList[4] or [5]. Those indices '
                .. 'sit after the optional region (innates, shard/scepter grants), so '
                .. 'what they name turns on a drop rule this repo cannot evaluate. '
                .. 'Check tests/mock/hero_slots.lua for this hero before trusting the '
                .. 'binding, and nil-guard it.')
    end
    for sHero in pairs(tExpect) do
        assert(tGot[sHero],
            'hero_' .. sHero .. '.lua no longer reads sAbilityList[4] or [5]. That is '
                .. 'progress, not a failure -- delete it from BINDS_PAST_3 and say so.')
    end
end

tests['[4] of the focus five only Crystal Maiden and Zeus read past index 3'] = function()
    local tPast = {}
    for _, sHero in ipairs(BINDS_PAST_3) do tPast[sHero] = true end
    assert(tPast.crystal_maiden and tPast.zuus,
        'the two focus heroes recorded as reading past index 3 are Crystal Maiden and '
            .. 'Zeus; one of them stopped')
    for _, sHero in ipairs({ 'axe', 'lion', 'skeleton_king' }) do
        assert(not tPast[sHero],
            'hero_' .. sHero .. '.lua now reads past index 3, which section 3 above '
                .. 'proves nothing about -- it only covers indices 1/2/3 and 6.')
    end
    -- Wraith King is the third of those three for a different reason, and it is
    -- the reason the other two should copy: hero_skeleton_king.lua binds by
    -- literal ability name and never indexes sAbilityList at all.
    local sWK = read_file('bots/BotLib/hero_skeleton_king.lua')
    assert(not sWK:find('sAbilityList[', 1, true),
        'hero_skeleton_king.lua now indexes sAbilityList. It was the focus five\'s only '
            .. 'name-binding file, i.e. the shape #203 and #206 both moved toward.')
end

return tests

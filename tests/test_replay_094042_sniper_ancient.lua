-- Replay desk 2026-09-13 -- the fixture layer the 09-12T21:2xZ round handed
-- forward for 'campfarm', built on the frame that round photographed:
--
--     W69 run spot_20260912_092624_1_main_0128b9, game 20260912_094042_slot1,
--     sniper, level 10, ARMED leg (script_version ends `:s13027:radiant`,
--     subject is team 2), t=546.0 -- the first of 12 right-clicks on an
--     ANCIENT creep (npc_dota_neutral_prowler_acolyte) inside campfarm's
--     domain, i.e. the shape the armed filter is supposed to make impossible.
--
-- ⛔ WHAT THE HANDOFF ASKED FOR, AND WHY THIS FILE DOES NOT DO IT.
-- The handoff asked to "assert that the table the armed world hands
-- J.Site.FindFarmNeutralTarget contains no ancient creep". That assertion is
-- NOT BUYABLE AT THIS LAYER, and the reason is in the generator's own source:
--
--     tools/batch_test/replayscope/make_fixture.py:474-478 -- "each sample
--     carries POSITION AND TEAM ONLY -- no entity id, no name, no health
--     (dumper/main.go: creepSnaps). So the block below is the whole truth
--     available about creeps, and everything a test wants beyond position+team
--     it has to declare for itself."
--
-- `IsAncientCreep()` is the ONLY predicate FilterFarmNeutrals reads, and it is
-- not in that stream -- verified first-hand on THIS timeline: every one of the
-- 135,137 creep samples in tl_094042_slot1 carries exactly {t, team, x, y}.
-- So "which of the creeps in the sweep were ancient" was dropped at
-- fixture-write time, exactly as GH #354 section 5's "pin a fixture on the gap
-- frame" was (same comment block names that precedent), and exactly as
-- campvoid_escape.py's header says of its own two conjuncts. Test [limit]
-- below pins this as an assertion so that a dumper which later DOES emit
-- identity retires the refusal instead of leaving it as prose.
--
-- WHAT THIS FILE BUYS INSTEAD, and it is the more useful half. The subject
-- half of a fixture IS real, and on this frame the subject half decides the
-- question GH #137 built 'campfarm' on. #137's motivating mechanism is:
--
--     "For a maxHP farmer -- viper, naga_siren, huskar, or anyone holding
--      bfury/maelstrom/mjollnir/radiance -- that is not a corner case but the
--      ROUTINE outcome: an ancient creep has the most health on the field, so
--      it is exactly the one GetMaxHPCreep returns."
--
-- This subject is NEITHER. `npc_dota_hero_sniper` has no entry in
-- ConsiderFarmNeutralType, and its real inventory at t=546.0 is
-- blade_of_alacrity / belt_of_strength / magic_wand / power_treads /
-- wraith_band / flask / faerie_fire -- none of the four items. So
-- FindFarmNeutralTarget falls all the way through to GetMinHPCreep, a pure
-- LOWEST-health pick, and its early return (HasArmorReduction) is structurally
-- dead on this frame: the four modifiers it reads come from Templar Assassin's
-- meld, Slardar's amplify damage, medallion and solar crest, and this game's
-- draft contains no TA and no Slardar, never sees a medallion, and its first
-- solar crest appears at t=1191.5 on ogre_magi -- 645 s after the frame.
--
-- ⇒ An ancient creep is the LAST thing this subject's target selection would
-- return, not the first. The target-selection story therefore does not explain
-- the t=546.0 attack, and the in-wrapper consumers that remain are the two
-- `nNeutrals[1]` clauses and the raw Action_AttackUnit(nNeutrals[1], true)
-- fallback at bots/mode_farm_generic.lua:992 -- all three of which read ENGINE
-- ORDER, not health, and all three of which are fed by the same filtered list.
--
-- WHAT THE EVENT STREAM SAYS ABOUT THE INSTANT (cited; the fixture carries the
-- subject half of it, and only the [frame] cases below assert what it carries):
--
--   541.2  sniper KILLS npc_dota_neutral_centaur_outrunner (gold+xp to sniper)
--   545.1  npc_dota_neutral_centaur_khan dies -- the normal camp is now cleared
--   546.0  sniper -> npc_dota_neutral_prowler_acolyte, inflictor dota_unknown,
--          115 damage  <-- THE FRAME
--   546.9  the first shrapnel tick to land on a prowler (sniper's own AoE,
--          cast at 540.9 on the OTHER camp)
--   547.0  bristleback's quill spray splashes both prowlers
--   548.3  the first prowler -> hero damage of the whole game
--
--   ⭐ Damage rows with a prowler as TARGET before t=546.0: ZERO.
--   ⭐ Damage rows with a prowler as ACTOR before t=546.0: ZERO.
--   So the right-click at 546.0 is strictly pre-aggro under the discriminator
--   the desk registered on 09-12 (and the two contaminating shapes that
--   discriminator warns about -- one's own AoE, an ally's quill spray -- both
--   land AFTER it, not before).
--
-- WHAT THIS FILE CANNOT DO, stated first (GH #61):
--   * The neutral half of the world is a DECLARED STAND-IN, for the reason at
--     the top. camp_units() below is written HERE, not read from the frame.
--     That makes every case below a test of the SELECTOR and the FILTER, not
--     an end-to-end reproduction of the attack order.
--   * A .dem carries no command stream, so "which consumer issued this
--     right-click" is not answerable from any fixture (GH #521, same family).
--     This file NARROWS the consumer set; it does not name the consumer.
--   * A .dem carries no bot mode, so "was the active mode BOT_MODE_FARM?"
--     stays open, as it did for tests/test_replay_212636_tide_ancient.lua.
--   * Nothing here measures gold.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')
local ss = require('mock.soak_side')               -- owns bots/Customize/soak_side.lua

local FIX = 'tests/fixtures/f_20260912_094042_sniper_546.lua'
local SUBJ = 'npc_dota_hero_sniper'
local CTRL = 'npc_dota_hero_viper'                 -- #137's named maxHP farmer,
                                                   -- a REAL hero on this frame

local SITE = 'bots/FunLib/aba_site.lua'
local FARM = 'bots/mode_farm_generic.lua'

-- The four items FindFarmNeutralTarget forces maxHP on, in BOTH spellings the
-- tree uses: the bot code names them `item_bfury` etc., while a fixture's raw
-- `items` entry is the dumper's entity-class snake (replay_fixture.lua's
-- NAMESPACE note -- 24 of 114 fixture item names never appear as `item_<name>`
-- in bots/, and bfury is exactly that shape). The raw check below is run over
-- the DUMP strings so a namespace divergence cannot make the negative pass for
-- free; [frame] positive-controls the predicate separately.
local MAXHP_ITEM_CLASSES = {
    bfury = true, battle_fury = true, battlefury = true,
    maelstrom = true, mjollnir = true, radiance = true,
}

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Arm the REAL gate by writing the (gitignored) soak_side file the farm writes
--- per wave. No J.* function is stubbed anywhere in this file: IsSoakCandidate
--- and IsModeTurbo both run their shipped bodies. This wave really did arm it --
--- the game's analysis.json carries
---   script_version = mirror:...,campfarm,...:s13027:radiant
--- and the subject is team 2 = radiant, i.e. the armed leg.
local function with_campfarm_armed(fn, sSide)
    ss.with_candidate('campfarm', fn, sSide)
end

ss.assert_clean('test_replay_094042_sniper_ancient')

--- A mixed sweep as two unit handles: one ancient at full health, one normal
--- creep already wounded. DECLARED INPUT (see the bound at the top).
--- `IsAncientCreep` is the only predicate the filter reads; GetHealth is the
--- only one the selector reads. The normal creep is deliberately the LOWER-hp
--- and the ancient the HIGHER-hp one, because that is the configuration in
--- which minHP and maxHP disagree -- a list where they agreed could not tell
--- the two branches apart at all.
local function camp_units()
    local function neutral(sName, bAncient, nHP)
        return api.MakeUnit({
            GetUnitName = sName,
            IsAncientCreep = bAncient,
            IsNull = false,
            IsAlive = true,
            -- IsValidUnit reads all four of these; the mock defaults every
            -- Is/Has/Can to false, so a unit that omitted CanBeSeen would be
            -- silently invalid and the selector would return nil for BOTH
            -- branches -- i.e. the contrast this file rests on would vanish
            -- into a uniform pass-by-nothing.
            CanBeSeen = true,
            IsInvulnerable = false,
            IsHero = false,
            GetLocation = api.Vector(-4180, 815, 0),
            GetHealth = nHP,
            GetMaxHealth = nHP,
            GetTeam = 4,
        })
    end
    return {
        neutral('npc_dota_neutral_prowler_acolyte', true, 1400),
        neutral('npc_dota_neutral_centaur_khan', false, 550),
    }
end

--- The gate expression EXACTLY as mode_farm_generic.lua's NeutralFarmList
--- writes it. The level comes off the loaded bot, not off a literal.
local function neutral_farm_list(J, bot, tCreeps)
    return J.Site.FilterFarmNeutrals(tCreeps, bot:GetLevel(),
        J.IsModeTurbo() and J.IsSoakCandidate('campfarm'))
end

local function names_of(tList)
    local out = {}
    for _, u in ipairs(tList) do out[#out + 1] = u:GetUnitName() end
    table.sort(out)
    return table.concat(out, ',')
end

local function unit_of(fx, sName)
    for _, u in ipairs(fx.units) do
        if u.name == sName then return u end
    end
end

tests['[frame] the subject really is inside campfarm domain at t=546.0'] = function()
    local J, bot, _, fx = rf.load(FIX, SUBJ)
    local nMin = tonumber(read_file(SITE):match('ANCIENT_MIN_LEVEL%s*=%s*(%d+)'))
    assert(nMin == 12, 'ANCIENT_MIN_LEVEL read from source, not restated: ' .. tostring(nMin))
    assert(fx.time == 546.0, 'the fixture is the instant the 09-12 round named')
    assert(bot:GetLevel() == 10, 'level 10 on the frame, from the dump')
    assert(bot:GetLevel() < nMin, 'and therefore below the ancient tier')
    assert(J.IsModeTurbo() == true, 'turbo (analysis.json: mode = turbo)')
    with_campfarm_armed(function()
        local J2, bot2 = rf.load(FIX, SUBJ)
        assert(J2.IsSoakCandidate('campfarm') == true,
            'the real gate opens for this bot: radiant leg, campfarm armed')
        assert(bot2:GetTeam() == 2, 'subject is radiant = the armed side of this wave')
    end)
end

tests['[frame] the subject holds NONE of the four maxHP-forcing items'] = function()
    -- Checked over the DUMP strings, so a fixture-loader namespace divergence
    -- (bfury is one of the known ones) cannot make this pass for free.
    local _, _, _, fx = rf.load(FIX, SUBJ)
    local u = unit_of(fx, SUBJ)
    assert(u, 'subject present in the fixture units')
    local nSlots = 0
    for _, itname in ipairs(u.items or {}) do
        if itname ~= '' then
            nSlots = nSlots + 1
            assert(not MAXHP_ITEM_CLASSES[itname],
                'the frame carries a maxHP-forcing item, which would change the '
                .. 'whole reading of this file: ' .. itname)
        end
    end
    assert(nSlots == 7, 'and the inventory is not empty -- 7 filled slots on the '
        .. 'frame, so the negative above is a reading of a real inventory; got '
        .. tostring(nSlots))
end

tests['[frame] the loader really can see this inventory (positive control)'] = function()
    -- Falsification for the case above: if the mock answered "no item" to
    -- everything, that test would pass on an empty world. power_treads is one
    -- of the spellings that do coincide, and the frame carries it.
    local _, bot = rf.load(FIX, SUBJ)
    local bFound = false
    for i = 0, 8 do
        local h = bot:GetItemInSlot(i)
        if h and h.GetName and h:GetName() == 'item_power_treads' then bFound = true end
    end
    assert(bFound, 'the real inventory reaches the bot handle; without this the '
        .. 'no-maxHP-item reading would be vacuous')
end

tests['[source] sniper has no entry in ConsiderFarmNeutralType'] = function()
    local J = rf.load(FIX, SUBJ)
    assert(J.Site.ConsiderFarmNeutralType[SUBJ] == nil,
        'no per-hero farm type, so the selector falls through to the item check')
    assert(type(J.Site.ConsiderFarmNeutralType[CTRL]) == 'function',
        'and the control hero DOES have one -- otherwise the contrast below is '
        .. 'not a contrast')
end

tests['[frame+source] this subject\'s target selection is a pure minHP pick'] = function()
    -- THE LOAD-BEARING CASE. Real bot, real level, real inventory; the camp is
    -- the declared stand-in. Unfiltered -- i.e. the SHIPPED world, gate shut --
    -- the ancient is still in the list, and this subject still does not pick it.
    ss.with_candidate(nil, function()
        local J, bot = rf.load(FIX, SUBJ)
        local tIn = camp_units()
        assert(neutral_farm_list(J, bot, tIn) == tIn, 'gate shut: same table back')
        local hTarget = J.Site.FindFarmNeutralTarget(tIn)
        assert(hTarget, 'the selector returns something')
        assert(hTarget:GetUnitName() == 'npc_dota_neutral_centaur_khan',
            'GH #137\'s maxHP mechanism does NOT apply to this subject: it takes '
            .. 'the GetMinHPCreep fall-through and returns the WOUNDED NORMAL '
            .. 'creep, not the full-health ancient; got '
            .. tostring(hTarget:GetUnitName()))
    end)
end

tests['[control] the real viper off the SAME frame does NOT pick the ancient either'] = function()
    -- ⭐ THIS CASE DID NOT DO WHAT IT WAS WRITTEN TO DO, AND THAT IS THE RESULT.
    -- It was written as #137's mechanism reproduced: viper is the maxHP farmer
    -- #137 names first, it is in this game's draft, and neither hero holds a
    -- maxHP item here, so the only difference from the case above should have
    -- been the per-hero name table. Viper DOES take the maxHP branch -- and
    -- still returns the normal creep, because this viper is LEVEL 9 and
    -- IsValidCreep's own ancient clause (keyed at 9, see the case below) makes
    -- the ancient invalid for it outright.
    --
    -- So on this frame BOTH real heroes refuse the ancient, for two DIFFERENT
    -- reasons one level apart, and #137's mechanism turns out to need a maxHP
    -- farmer at level 10 or 11 exactly -- a two-level window, which is the same
    -- 10..11 band the desk's campfarm tables have been reading all along. This
    -- game's only maxHP farmer is a level below it.
    ss.with_candidate(nil, function()
        local J, bot, _, fx = rf.load(FIX, CTRL)
        local u = unit_of(fx, CTRL)
        for _, itname in ipairs(u.items or {}) do
            assert(itname == '' or not MAXHP_ITEM_CLASSES[itname],
                'the control must reach maxHP through the NAME table, not an item: '
                .. itname)
        end
        assert(J.Site.ConsiderFarmNeutralType[CTRL]() == 'maxHP',
            'viper really is on the maxHP branch -- the refusal below is not a '
            .. 'wrong-branch artefact')
        assert(bot:GetLevel() == 9, 'and it is level 9 on this frame, from the dump')
        local hTarget = J.Site.FindFarmNeutralTarget(camp_units())
        assert(hTarget and hTarget:GetUnitName() == 'npc_dota_neutral_centaur_khan',
            'the maxHP farmer still returns the NORMAL creep; got '
            .. tostring(hTarget and hTarget:GetUnitName()))
        assert(J.Site.FindFarmNeutralTarget({ camp_units()[1] }) == nil,
            'and handed nothing but the ancient it returns NOTHING -- at level 9 '
            .. 'the ancient is not a candidate at all, which is the clause, not '
            .. 'the preference')
    end)
end

tests['[gate] armed at L10 the filter empties an ALL-ancient sweep'] = function()
    -- The event stream says the normal camp was already cleared at t=545.1
    -- (centaur_outrunner 541.2, centaur_khan 545.1), so 0.9 s later the only
    -- neutrals the sweep could return were the prowlers. This is the
    -- consequence FilterFarmNeutrals' own header DECLARES for that case, and
    -- it is what makes the t=546.0 right-click un-explainable from inside the
    -- wrapper: with an empty list there is no [1] to attack either.
    with_campfarm_armed(function()
        local J, bot = rf.load(FIX, SUBJ)
        local tAllAncient = { camp_units()[1] }
        local tOut = neutral_farm_list(J, bot, tAllAncient)
        assert(#tOut == 0, 'armed, an all-ancient sweep comes back EMPTY; got '
            .. #tOut)
        assert(tOut[1] == nil, 'so the raw Action_AttackUnit(nNeutrals[1]) '
            .. 'fallback has no unit to attack')
        assert(J.Site.FindFarmNeutralTarget(tOut) == nil,
            'and the selector has nothing to return')
    end)
end

tests['[gate] armed, the filter drops the ancient and keeps the normal creep'] = function()
    with_campfarm_armed(function()
        local J, bot = rf.load(FIX, SUBJ)
        local tIn = camp_units()
        local tOut = neutral_farm_list(J, bot, tIn)
        assert(#tIn == 2, 'declared stand-in camp: 1 ancient + 1 normal')
        assert(names_of(tOut) == 'npc_dota_neutral_centaur_khan',
            'armed at level 10 the ancient is gone and ONLY it is gone; got: '
            .. names_of(tOut))
        assert(tOut ~= tIn, 'a filtered list is a new table, not the input')
    end)
end

tests['[control] armed on the OTHER side, the same frame is untouched'] = function()
    -- Falsification: if the drop came from the level alone the list would
    -- shrink here too. It must not -- this bot is radiant.
    with_campfarm_armed(function()
        local J, bot = rf.load(FIX, SUBJ)
        assert(J.IsSoakCandidate('campfarm') == false, 'wrong leg, gate shut')
        local tIn = camp_units()
        assert(neutral_farm_list(J, bot, tIn) == tIn, 'the ancient stays in the list')
    end, 'dire')
end

tests['[limit] the fixture carries NO creep identity -- the refusal, as an assertion'] = function()
    -- This is the machine-checked form of the ⛔ note at the top. It is written
    -- to FAIL the day the dumper starts emitting creep names or an ancient
    -- flag, because on that day the handoff's original assertion becomes
    -- buyable and this file's bound should be retired rather than quoted.
    local _, _, _, fx = rf.load(FIX, SUBJ)
    assert(fx.creeps and #fx.creeps > 0,
        'the frame does carry creep samples -- so this is a bound on their '
        .. 'CONTENT, not on their absence')
    local nNeutral = 0
    for _, c in ipairs(fx.creeps) do
        for k in pairs(c) do
            assert(k == 'team' or k == 'x' or k == 'y' or k == 'dt',
                'the creep stream grew a field: ' .. tostring(k) .. ' -- if it '
                .. 'carries identity now, retire this bound and assert the '
                .. 'ancient-free list directly')
        end
        if c.team == 4 then nNeutral = nNeutral + 1 end
    end
    assert(nNeutral >= 2, 'and neutrals really are among them (' .. nNeutral
        .. ' team-4 samples), so the missing datum is identity, not presence')
end

tests['[source] a FOURTH ancient threshold lives inside IsValidCreep, and it is 9'] = function()
    -- Found while building this file, and it is not in any campfarm header.
    -- bots/FunLib/utils.lua's IsValidCreep ends with
    --     (GetBot():GetLevel() > 9 or not target:IsAncientCreep())
    -- so EVERY reader of that predicate -- GetMinHPCreep and GetMaxHPCreep
    -- included -- carries its own ancient clause, keyed at 9. The tree now has
    -- four different ancient thresholds on this path: 9 here, 10 in the two
    -- `nNeutrals[1]` clauses, 12 in ANCIENT_MIN_LEVEL/the camp ladder, and
    -- none at all in the 1000u branch and the raw [1] fallback.
    --
    -- Consequence for THIS frame, and the reason it is asserted rather than
    -- noted: the subject is level 10, i.e. 10 > 9, so the ancient passes
    -- validity here and is a live candidate for selection. The reading in this
    -- file ("minHP simply prefers the wounded normal creep") therefore does NOT
    -- lean on the ancient being filtered out upstream -- which it would, one
    -- level lower.
    local u = read_file('bots/FunLib/utils.lua')
    local nLvl = tonumber(u:match('GetBot%(%):GetLevel%(%)%s*>%s*(%d+)%s*or not target:IsAncientCreep'))
    assert(nLvl == 9, 'the IsValidCreep ancient clause is keyed at 9, read from '
        .. 'source; got ' .. tostring(nLvl))
    local J, bot = rf.load(FIX, SUBJ)
    assert(bot:GetLevel() > nLvl,
        'and this subject is above it, so the ancient is a LIVE candidate on '
        .. 'this frame -- the minHP reading is not an artefact of it being dropped')
    local hAncient = camp_units()[1]
    assert(J.Site.FindFarmNeutralTarget({ hAncient }) == hAncient,
        'handed nothing but the ancient, the selector does return it -- so the '
        .. 'normal-creep answer above is a PREFERENCE, not an inability')
end

tests['[wiring] the farm path resolves campfarm in exactly one place'] = function()
    -- Not a restatement of test_campfarm_ancient_target.lua's call-site census;
    -- this file's whole argument assumes the three [1]-order readers are fed by
    -- the same wrapper, so it checks that assumption where it stands.
    local src = read_file(FARM)
    local _, nGate = src:gsub("IsSoakCandidate%('campfarm'%)", '')
    assert(nGate == 1, "'campfarm' is resolved once on the farm path; got "
        .. nGate)
    assert(src:find('Action_AttackUnit%(nNeutrals%[1%]', 1, false),
        'the raw [1] fallback this file reasons about is still there')
end

return tests

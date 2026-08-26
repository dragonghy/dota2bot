-- [hero] What the engine actually calls the focus five's abilities, and why the
-- datafeed cannot answer that question.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- GH #104 re-anchored Wraith King's ability index map against the live Dota 2
-- datafeed, and the sentence it left in hero_skeleton_king.lua reads:
--
--     "skeleton_king_vampiric_spirit (the lifesteal) is flagged INNATE by the
--      datafeed, so GetAbilityList drops it and it costs no skill point at all."
--
-- Both halves of that are wrong, and the same shape of sentence is doing work
-- for four other files.  This file measures the two halves apart:
--
--   (1) THE NAME.  The engine does not call it skeleton_king_vampiric_spirit.
--       Every Wraith King frame in this repo's fixture corpus carries
--       skeleton_king_INNATE_vampiric_spirit -- on all 31 WK frames that dump
--       an ability array at all (of 34 WK frames) -- and the datafeed's name
--       appears on 0.  Lion has the identical shape:
--       lion_innate_to_hell_and_back on 22 of 22, the feed's
--       lion_to_hell_and_back on 0.  So a name read off the datafeed is not a
--       name you may compare an engine ability against.
--
--   (2) THE MECHANISM.  J.Skill.GetAbilityList does not read an innate flag; no
--       such flag exists in the bot API.  It drops an ability only when
--       DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE **and** ability:IsHidden() are both
--       true, and nothing offline in this repo can evaluate IsHidden.  So "the
--       feed says innate, therefore it is dropped, therefore my index map holds"
--       is an assumption, not a derivation.
--
-- WHY IT IS NOT MERELY PEDANTIC
--   Of the focus five, three innates (axe_one_man_army, crystal_maiden_
--   glacial_guard, zuus_static_field) are absent from the engine's ability array
--   entirely, so for those three the drop is trivially satisfied.  The two that
--   ARE present -- WK's and Lion's -- are present with level = 1 on every single
--   frame.  Whether GetAbilityList drops them rests entirely on IsHidden.  If it
--   does not drop them they land at index 4 by table.insert, and index 4 is
--   exactly where hero_crystal_maiden.lua binds CrystalClone and
--   hero_zuus.lua binds abilityD (with abilityAS at 5).  Section 4 records who
--   binds what, so the blast radius of that unknown is bounded rather than
--   guessed at: it is Zeus and Crystal Maiden.  UPDATE 2026-08-26 (GH #203):
--   the Zeus half stopped being an unknown -- enumerating the drop decision over
--   the three optional abilities and driving the shipped walk in each world
--   showed index 5 is Static Field in none of them and nil in four
--   (tests/test_zuus_ability_index_binding.lua), and both Zeus consumers are now
--   routed and nil-guarded.  The Crystal Maiden binding still is not, the way
--   hero_skeleton_king.lua's abilityW is.
--
-- WHAT IS PINNED HERE
--   1. corpus ground truth: the engine ability-name set per focus hero, with
--      frame denominators, read out of tests/fixtures/ rather than asserted;
--   2. the name divergence, in both directions, with its denominators;
--   3. the drop rule, read out of bots/FunLib/aba_skill.lua as source text;
--   4. the sAbilityList index consumers of the five focus files, read out of
--      their source;
--   5. a LIMIT assertion: the fixture ability array is NOT GetAbilityInSlot
--      order, so no index map may ever be derived from this corpus.  The proof
--      is inside the corpus (see section 5) and it is the reason section 1 stops
--      at names and refuses to speak about indices.
--
-- HONEST BOUNDS
--   * The datafeed rows quoted below are RECORDED (hero_id 2/5/22/26/42, read
--     2026-08-23); this test cannot reach the network.  What ratchets is the
--     repo-local half plus the corpus half.
--   * "0 of N" for a granted ability is a real zero on THIS corpus, not proof
--     the pipeline cannot show one: zuus_lightning_hands (an Aghanim's Shard
--     grant) is present on 1 of the 47 Zeus frames that dump an ability array
--     (of 50), which is the denominator that
--     makes the other zeros readable.  It is still an existence read on fixtures
--     curated for other investigations, never a density.
--   * Nothing here is a behaviour claim.  No bots/ decision changes, no gate.

package.path = 'tests/?.lua;' .. package.path

local FOCUS = { 'axe', 'crystal_maiden', 'lion', 'skeleton_king', 'zuus' }

-- Recorded from https://www.dota2.com/datafeed/herodata?language=english&hero_id=N
-- on 2026-08-23.  Each focus hero has exactly one ability with
-- ability_is_innate = true; this is the name the FEED gives it.
local FEED_INNATE = {
    axe             = 'axe_one_man_army',
    crystal_maiden  = 'crystal_maiden_glacial_guard',
    lion            = 'lion_to_hell_and_back',
    skeleton_king   = 'skeleton_king_vampiric_spirit',
    zuus            = 'zuus_static_field',
}

-- The name the ENGINE uses, where the corpus shows one at all.
local ENGINE_INNATE = {
    lion            = 'lion_innate_to_hell_and_back',
    skeleton_king   = 'skeleton_king_innate_vampiric_spirit',
}

-- Corpus ground truth, measured 2026-08-23; re-measured 2026-08-26 when
-- f_212636_tide_ancient (GH #197) added one frame carrying crystal_maiden,
-- lion and zuus (+1 each; zuus's `with` went 47 -> 48 because that frame does
-- dump his ability array). axe and skeleton_king are not on that frame and did
-- not move -- a denominator change, not a name-set change.
-- hero -> { frames, {name = count} }.
-- Talent rows (special_bonus_*) leak into the dumped ability array on some
-- frames; they are excluded here because J.Skill.GetAbilityList filters
-- ability:IsTalent() anyway.
local CORPUS = {
    axe = { frames = 26, with = 26, names = {
        axe_berserkers_call = 26, axe_battle_hunger = 26,
        axe_counter_helix = 26, axe_culling_blade = 26 } },
    crystal_maiden = { frames = 51, with = 51, names = {
        crystal_maiden_crystal_nova = 51, crystal_maiden_frostbite = 51,
        crystal_maiden_brilliance_aura = 51, crystal_maiden_freezing_field = 51 } },
    lion = { frames = 23, with = 23, names = {
        lion_impale = 23, lion_voodoo = 23, lion_mana_drain = 23,
        lion_innate_to_hell_and_back = 23, lion_finger_of_death = 23 } },
    skeleton_king = { frames = 34, with = 31, names = {
        skeleton_king_hellfire_blast = 31, skeleton_king_bone_guard = 31,
        skeleton_king_mortal_strike = 31,
        skeleton_king_innate_vampiric_spirit = 31,
        skeleton_king_reincarnation = 31 } },
    zuus = { frames = 51, with = 48, names = {
        zuus_arc_lightning = 48, zuus_lightning_bolt = 48,
        zuus_heavenly_jump = 48, zuus_thundergods_wrath = 48,
        zuus_lightning_hands = 1 } },
}

-- Each focus hero's ultimate, and where it sits in the DUMPED array.  Used by
-- section 5 only.
local ULT = {
    axe            = 'axe_culling_blade',
    crystal_maiden = 'crystal_maiden_freezing_field',
    lion           = 'lion_finger_of_death',
    skeleton_king  = 'skeleton_king_reincarnation',
    zuus           = 'zuus_thundergods_wrath',
}

-- ---------------------------------------------------------------------------
-- Corpus scan.
--
-- NOTE ON THE PARSE, and it cost this file a wrong reading before it was caught:
-- the ability array must be walked entry by entry, NOT captured with a lazy
-- "everything up to `} }`" pattern.  That pattern swallows the closing brace of
-- the LAST entry, and the last entry is the ultimate on every focus hero -- so
-- the first cut of section 5 read "Axe never has his ult on cooldown" (really
-- 1 of 26) and only saw an ult at all on the frames that happened to carry a
-- trailing talent row.  Entries are matched individually below.

local function fixture_paths()
    local p = assert(io.popen('ls tests/fixtures'))
    local files = {}
    for f in p:lines() do
        if f:match('^f_.*%.lua$') then files[#files + 1] = 'tests/fixtures/' .. f end
    end
    p:close()
    table.sort(files)
    return files
end

local scanned = nil

--- One pass over the corpus.  Every hero entry counts, alive or dead: the
--- dumped ability array is present either way, and this file is about names.
local function scan()
    if scanned then return scanned end
    local r = {}
    for _, h in ipairs(FOCUS) do
        r[h] = { frames = 0, with = 0, names = {}, ult_learned = 0, ult_on_cd = 0,
                 ult_last = 0, entries_max = 0 }
    end
    for _, path in ipairs(fixture_paths()) do
        local fx = dofile(path)
        if type(fx) == 'table' and fx.units then
            for _, u in ipairs(fx.units) do
                local h = tostring(u.name):match('^npc_dota_hero_(.+)$')
                local acc = h and r[h]
                if acc then
                    acc.frames = acc.frames + 1
                    if u.abilities ~= nil then acc.with = acc.with + 1 end
                    local real = {}
                    for _, a in ipairs(u.abilities or {}) do
                        if not tostring(a.name):match('^special_bonus') then
                            real[#real + 1] = a
                            acc.names[a.name] = (acc.names[a.name] or 0) + 1
                        end
                    end
                    if #real > acc.entries_max then acc.entries_max = #real end
                    if #real > 0 and real[#real].name == ULT[h] then
                        acc.ult_last = acc.ult_last + 1
                    end
                    for _, a in ipairs(real) do
                        if a.name == ULT[h] then
                            if (a.level or 0) > 0 then acc.ult_learned = acc.ult_learned + 1 end
                            if (a.cd or 0) > 0 then acc.ult_on_cd = acc.ult_on_cd + 1 end
                        end
                    end
                end
            end
        end
    end
    scanned = r
    return r
end

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. Corpus ground truth: names and denominators.

tests['[1] the engine ability-name set of each focus hero is what was recorded'] = function()
    local r = scan()
    for _, h in ipairs(FOCUS) do
        local rec, got = CORPUS[h], r[h]
        assert(got.frames == rec.frames,
            'hero ' .. h .. ' now has ' .. got.frames .. ' entries in tests/fixtures/, '
            .. 'recorded ' .. rec.frames .. '.')
        -- The name counts below are out of `with`, not `frames`: some hero
        -- entries carry no ability array at all (WK 34 entries / 31 with, Zeus
        -- 50 / 47). Dividing a name count by the wrong one of those two is the
        -- same mistake in miniature that this whole file is about.
        assert(got.with == rec.with,
            'hero ' .. h .. ' dumps an ability array on ' .. got.with .. ' entries, '
            .. 'recorded ' .. rec.with .. ' of ' .. rec.frames .. '. Every name '
            .. 'count in this file is a fraction of THAT denominator -- re-measure '
            .. 'before quoting any of them.')
        for name, n in pairs(rec.names) do
            assert(got.names[name] == n,
                h .. "'s ability '" .. name .. "' is on " .. tostring(got.names[name])
                .. ' frames, recorded ' .. n .. ' of ' .. rec.with .. '.')
        end
        for name, n in pairs(got.names) do
            assert(rec.names[name],
                h .. ' grew an unrecorded engine ability name: ' .. name .. ' ('
                .. n .. ' of ' .. got.with .. ' frames). If a patch renamed '
                .. 'something, every literal in bots/ that spells the old name is '
                .. 'now dead -- check them before updating this table.')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 2. The name divergence, measured in both directions.

tests['[2] no focus hero carries its DATAFEED innate name on any frame'] = function()
    local r = scan()
    for _, h in ipairs(FOCUS) do
        local feed = FEED_INNATE[h]
        assert(r[h].names[feed] == nil,
            h .. ' now carries the datafeed name ' .. feed .. ' on '
            .. tostring(r[h].names[feed]) .. ' frames. That would mean the engine '
            .. 'and the feed agree for this hero -- which is the opposite of what '
            .. 'this file records, so re-read the whole divergence before relying '
            .. 'on either source.')
    end
end

tests['[2] the two innates the engine DOES expose carry an _innate_ infix the feed lacks'] = function()
    local r = scan()
    local found = {}
    for _, h in ipairs(FOCUS) do
        for name, n in pairs(r[h].names) do
            if name:find('_innate_', 1, true) then
                found[h] = name
                assert(n == CORPUS[h].with,
                    h .. "'s innate " .. name .. ' is on ' .. n .. ' of '
                    .. CORPUS[h].with .. ' frames, not all of them. A partial '
                    .. 'count would mean the entry comes and goes, which changes '
                    .. 'what index 4 can be.')
                -- the feed's name is this one with the infix removed
                local stripped = name:gsub('_innate_', '_', 1)
                assert(stripped == FEED_INNATE[h],
                    'stripping _innate_ from ' .. name .. ' gives ' .. stripped
                    .. ', not the recorded feed name ' .. FEED_INNATE[h]
                    .. '. The divergence is no longer a pure infix -- say what it '
                    .. 'is now.')
            end
        end
    end
    for h, name in pairs(ENGINE_INNATE) do
        assert(found[h] == name,
            'expected ' .. h .. ' to expose ' .. name .. ' in the engine ability '
            .. 'array; found ' .. tostring(found[h]) .. '.')
    end
    for h in pairs(found) do
        assert(ENGINE_INNATE[h],
            h .. ' grew an _innate_ ability entry and was recorded as NOT having '
            .. 'one. Its innate can now land at sAbilityList[4] -- check section 4 '
            .. 'for whether this file binds that index.')
    end
end

tests['[2] the other three focus innates are absent from the array entirely'] = function()
    local r = scan()
    for _, h in ipairs({ 'axe', 'crystal_maiden', 'zuus' }) do
        assert(ENGINE_INNATE[h] == nil, h .. ' is recorded as exposing no innate entry')
        for name in pairs(r[h].names) do
            assert(not name:find('_innate_', 1, true),
                h .. ' now exposes ' .. name .. ' in its ability array.')
        end
        assert(r[h].names[FEED_INNATE[h]] == nil,
            h .. ' now exposes ' .. FEED_INNATE[h] .. '.')
    end
end

tests['[2] a granted ability CAN appear here -- so the zeros above are real zeros'] = function()
    local r = scan()
    -- zuus_lightning_hands is an Aghanim's Shard grant.  It is in the corpus on
    -- exactly one frame.  Without this denominator, "the innate is absent" and
    -- "the pipeline cannot show optional abilities" look identical -- which is
    -- the axeblink trap, and the reason this control exists.
    assert(r.zuus.names.zuus_lightning_hands == 1,
        'zuus_lightning_hands is on ' .. tostring(r.zuus.names.zuus_lightning_hands)
        .. ' frames, recorded 1 of 47. This single frame is the only proof this '
        .. 'corpus can show a granted ability at all; if it goes, every "absent" '
        .. 'reading in section 2 loses its denominator and must be re-stated as '
        .. 'UNMEASURABLE rather than zero.')
end

-- ---------------------------------------------------------------------------
-- 3. The drop rule, read out of the source.

tests['[3] GetAbilityList drops on NOT_LEARNABLE *and* IsHidden, and reads no innate flag'] = function()
    local src = read_file('bots/FunLib/aba_skill.lua')
    local a = src:find('function X.GetAbilityList(', 1, true)
    assert(a, 'X.GetAbilityList is gone from bots/FunLib/aba_skill.lua')
    local b = src:find('function X.GetSkillList(', a, true)
    assert(b, 'X.GetSkillList no longer follows X.GetAbilityList; re-pick the '
        .. 'end marker for this slice')
    local fn = src:sub(a, b - 1)

    assert(fn:find('DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE', 1, true),
        'GetAbilityList no longer tests DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE')
    assert(fn:find('ability:IsHidden()', 1, true),
        'GetAbilityList no longer tests ability:IsHidden()')
    assert(fn:find('NOT_LEARNABLE) and ability:IsHidden()', 1, true),
        'the drop condition is no longer NOT_LEARNABLE *and* IsHidden. It is a '
        .. 'conjunction on purpose: an ability that is unlearnable but VISIBLE is '
        .. 'kept, and that is the only reason an innate can reach index 4.')

    -- The word "innate" DOES appear in this function -- but only inside a
    -- commented-out warning, `(e.g. innate like)`.  That parenthetical is the
    -- whole provenance of the "the feed says innate, so it is dropped" story:
    -- an aside in a dead print, not a rule the code applies.  So the assertion
    -- is on CODE, with line comments stripped.
    local code = fn:gsub('%-%-[^\n]*', '')
    assert(not code:lower():find('innate', 1, true),
        'GetAbilityList now mentions "innate" in code, not just in the commented-'
        .. 'out warning. There is no innate flag in the bot API -- if one '
        .. 'appeared, this whole file\'s premise changes and the comments in '
        .. 'hero_skeleton_king.lua can finally say "innate" truthfully.')
    assert(fn:find('e.g. innate like', 1, true),
        'the `(e.g. innate like)` aside is gone from the commented-out warning in '
        .. 'GetAbilityList. It is recorded because it is where the innate framing '
        .. 'in five hero files came from -- if you removed it, say so.')

    -- the ultimate is forced to 6 only from slot 4 up; section 5 depends on this
    assert(fn:find('ability:IsUltimate() and slot >= 4', 1, true),
        'the ultimate is no longer forced to index 6 by an `IsUltimate() and '
        .. 'slot >= 4` test; section 5 reasons from that exact literal.')
    assert(fn:find('sAbilityList[6] = name', 1, true),
        'the ultimate is no longer written to index 6')
end

-- ---------------------------------------------------------------------------
-- 4. Who binds which index.  Read out of the five files, not asserted.

-- hero -> sorted list of sAbilityList indices the file reads.
local INDEX_CENSUS = {
    axe            = { 1, 2, 3, 6 },
    crystal_maiden = { 1, 2, 4, 6 },
    lion           = { 1, 2, 3, 6 },
    skeleton_king  = {},           -- binds by hardcoded name instead
    zuus           = { 1, 2, 3, 4, 5, 6 },
}

local function index_reads(hero)
    local src = read_file('bots/BotLib/hero_' .. hero .. '.lua')
    local seen, out = {}, {}
    for n in src:gmatch('sAbilityList%[(%d+)%]') do
        n = tonumber(n)
        if not seen[n] then seen[n] = true; out[#out + 1] = n end
    end
    table.sort(out)
    return out, src
end

tests['[4] the focus five bind exactly the recorded sAbilityList indices'] = function()
    for _, h in ipairs(FOCUS) do
        local got = index_reads(h)
        local rec = INDEX_CENSUS[h]
        assert(#got == #rec,
            'hero_' .. h .. '.lua reads ' .. #got .. ' distinct sAbilityList '
            .. 'indices, recorded ' .. #rec .. '.')
        for i = 1, #rec do
            assert(got[i] == rec[i],
                'hero_' .. h .. '.lua index ' .. i .. ' is ' .. tostring(got[i])
                .. ', recorded ' .. rec[i] .. '.')
        end
    end
end

tests['[4] only Zeus and Crystal Maiden bind above index 3 -- that is the blast radius'] = function()
    local exposed = {}
    for _, h in ipairs(FOCUS) do
        for _, n in ipairs(index_reads(h)) do
            if n == 4 or n == 5 then exposed[h] = true end
        end
    end
    assert(exposed.zuus and exposed.crystal_maiden,
        'Zeus and Crystal Maiden are recorded as the two files that bind '
        .. 'sAbilityList[4]/[5]; one of them stopped.')
    for _, h in ipairs({ 'axe', 'lion', 'skeleton_king' }) do
        assert(not exposed[h],
            'hero_' .. h .. '.lua now binds sAbilityList[4] or [5]. That is the '
            .. 'slot an undropped innate would occupy, and whether it is dropped '
            .. 'turns on ability:IsHidden(), which nothing offline in this repo '
            .. 'can evaluate. Say what the binding is for and nil-guard it.')
    end
end

tests['[4] Crystal Maiden\'s index-4 binding is still unguarded, unlike WK\'s abilityW'] = function()
    -- Recorded, not argued: hero_skeleton_king.lua re-fetches abilityW behind
    -- `if not abilityW or abilityW:IsHidden()`, and gates X.ConsiderW on
    -- `abilityW:GetName() ~= "skeleton_king_bone_guard"`.  The Zeus and CM
    -- bindings do neither, so if their index-4 handle is ever the wrong ability
    -- (or nil) the failure is a silent Think-time crash -- and print() does not
    -- reach the server console, so nobody would see it.
    local wk = read_file('bots/BotLib/hero_skeleton_king.lua')
    assert(wk:find('if not abilityW or abilityW:IsHidden()', 1, true),
        'hero_skeleton_king.lua lost its abilityW guard; it is the contrast case '
        .. 'this assertion is written against.')
    assert(wk:find('abilityW:GetName() ~= "skeleton_king_bone_guard"', 1, true),
        'hero_skeleton_king.lua lost its abilityW name check')

    local cm = read_file('bots/BotLib/hero_crystal_maiden.lua')
    assert(cm:find('local CrystalClone = bot:GetAbilityByName( sAbilityList[4] )', 1, true),
        'hero_crystal_maiden.lua no longer binds CrystalClone from sAbilityList[4]')
    assert(cm:find('if not CrystalClone:IsTrained()', 1, true),
        'X.ConsiderCrystalClone no longer opens on CrystalClone:IsTrained(). If a '
        .. 'nil guard was added, delete this assertion and say so -- it exists to '
        .. 'record that the first thing done with the handle is an unguarded '
        .. 'method call.')

    local zs = read_file('bots/BotLib/hero_zuus.lua')
    assert(zs:find('local abilityD = bot:GetAbilityByName( sAbilityList[4] )', 1, true),
        'hero_zuus.lua no longer binds abilityD from sAbilityList[4]')
    assert(zs:find('local abilityAS = bot:GetAbilityByName( sAbilityList[5] )', 1, true),
        'hero_zuus.lua no longer binds abilityAS from sAbilityList[5]')
    -- ANSWERED 2026-08-26 for Zeus (GH #203, gated 'zusbind'), and this half is
    -- re-pointed exactly as the CM half above still instructs: the open question
    -- this assertion recorded -- "the first thing done with the index-4/5 handle
    -- is an unguarded method call" -- is no longer true of hero_zuus.lua, so the
    -- assertion now records what replaced it rather than demanding the old
    -- shape.  Enumerating the drop worlds (tests/test_zuus_ability_index_binding.lua)
    -- turned the unknown into a measurement: index 5 is Static Field in NONE of
    -- the eight, and four of them hand back nil.  Both consumers now route
    -- through X.GetBoundAbility and both nil-check ungated.
    assert(zs:find("X.GetStaticFieldBonus( X.GetBoundAbility( abilityAS, 'zuus_static_field' ) )", 1, true),
        'hero_zuus.lua no longer routes abilityAS through X.GetBoundAbility')
    assert(zs:find("X.GetBoundAbility( abilityD, 'zuus_cloud' )", 1, true),
        'hero_zuus.lua no longer routes abilityD through X.GetBoundAbility')
    local sBonus = zs:gsub('%-%-[^\n]*', ''):match('function X%.GetStaticFieldBonus%b()(.-)\nend')
    assert(sBonus, 'X.GetStaticFieldBonus is gone; where does the index-5 handle go now?')
    assert(sBonus:match('^%s*if hAbility == nil then return 0 end'),
        'X.GetStaticFieldBonus no longer OPENS on the ungated nil check. That check is '
        .. 'the whole ungated half of GH #203 -- four of the eight drop-worlds hand '
        .. 'back nil, and indexing nil inside X.SkillsComplement is a silent whole-tick '
        .. 'abort.')
end

-- ---------------------------------------------------------------------------
-- 5. LIMIT: the dumped array is not slot order.  Nobody may derive an index map
--    from this corpus.

tests['[5] the fixture ability array is NOT GetAbilityInSlot order (two-hero proof)'] = function()
    local r = scan()
    -- Axe and Crystal Maiden each dump exactly four abilities with the ultimate
    -- LAST.  If that array were GetAbilityInSlot order, their ultimate would sit
    -- at slot 3; GetAbilityList forces index 6 only from `slot >= 4`, so it would
    -- fall through to table.insert at index 4 and sAbilityList[6] would be nil --
    -- i.e. abilityR nil and the entire ult path dead for both heroes.
    -- The corpus refutes that directly: both have the ultimate ON COOLDOWN on
    -- real frames, which only happens after a cast.
    for _, h in ipairs({ 'axe', 'crystal_maiden' }) do
        assert(r[h].entries_max == 4,
            h .. ' now dumps up to ' .. r[h].entries_max .. ' abilities, recorded 4. '
            .. 'The argument below counts on four.')
        assert(r[h].ult_last == r[h].with,
            h .. "'s ultimate is last in the array on " .. r[h].ult_last .. ' of '
            .. r[h].with .. ' frames, not all of them.')
        assert(r[h].ult_on_cd > 0,
            h .. "'s ultimate is never on cooldown in this corpus, so the "
            .. '"it was actually cast" leg of the proof is gone. Re-establish it '
            .. 'before trusting any index reasoning.')
    end
    assert(r.axe.ult_on_cd == 1 and r.crystal_maiden.ult_on_cd == 10,
        'recorded ult-on-cooldown counts were axe 1 of 26 and crystal_maiden 10 '
        .. 'of 50; got ' .. r.axe.ult_on_cd .. ' and ' .. r.crystal_maiden.ult_on_cd
        .. '. Axe\'s leg is n=1 -- say so whenever this proof is quoted.')

    -- Lion and Wraith King dump five, ultimate last, so THEY are consistent with
    -- slot order.  Recorded so nobody "confirms" slot order off those two.
    for _, h in ipairs({ 'lion', 'skeleton_king' }) do
        assert(r[h].entries_max == 5,
            h .. ' now dumps up to ' .. r[h].entries_max .. ' abilities, recorded 5.')
        assert(r[h].ult_last == r[h].with,
            h .. "'s ultimate is last on " .. r[h].ult_last .. ' of ' .. r[h].with
            .. ' frames, not all of them.')
    end
end

-- ---------------------------------------------------------------------------
-- 6. What sAbilityList ACTUALLY holds in the fixture world.
--
-- Sections 3 and 4 argue on paper that an undropped innate lands at index 4 and
-- that only Zeus and Crystal Maiden read that far.  This section stops arguing
-- and drives J.Skill.GetAbilityList on real frames through the loader, which
-- reconstructs engine slots (tests/mock/replay_fixture.lua, GH #36).  Two things
-- come back, and both are FACTS ABOUT THE HARNESS, not about the engine:
--
--   * the prediction is realised -- WK's and Lion's innates ARE at index 4,
--     because the mock's IsHidden() is false and the drop needs it true;
--   * and a second occupant nobody predicted: the mock's ability:IsTalent()
--     returns false for everything, including special_bonus_* rows.  The dumper
--     puts those rows in the ability array on some frames (CM 14 of 50, Zeus 9
--     of 47), so GetAbilityList's `elseif not ability:IsTalent()` does not
--     filter them and they get table.insert-ed like a real ability.  On those
--     frames CM's CrystalClone and Zeus's abilityAS are bound to a TALENT.
--
-- This is the GH #36 / #27 / #133 / #145 family: a fixture test that drives
-- X.ConsiderCrystalClone is not exercising the shipped handle.  It is filed for
-- the harness owner in GH #151 section 3; nothing in bots/ is changed for it.

local RF = require('mock.replay_fixture')

-- (fixture, subject, expected sAbilityList[4], expected [5])
local INDEX_PROBES = {
    { 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua', 'npc_dota_hero_skeleton_king',
      'skeleton_king_innate_vampiric_spirit', nil,
      'the innate is NOT dropped -- IsHidden() is false in the mock' },
    { 'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua', 'npc_dota_hero_lion',
      'lion_innate_to_hell_and_back', nil,
      'same shape as WK; harmless only because hero_lion.lua never reads [4]' },
    { 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua', 'npc_dota_hero_crystal_maiden',
      'special_bonus_h_p200', nil,
      'CM binds CrystalClone from [4] -- here that is a TALENT' },
    { 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua', 'npc_dota_hero_zuus',
      'zuus_lightning_hands', 'special_bonus_h_p200',
      'Zeus binds abilityAS from [5] -- here that is a TALENT' },
    { 'tests/fixtures/f_113638_cm_chain_rescue.lua', 'npc_dota_hero_crystal_maiden',
      nil, nil,
      'on a frame with no talent row, CM index 4 is nil outright' },
}

tests['[6] sAbilityList[4]/[5] on real frames: the innate lands there, and so do talents'] = function()
    for _, probe in ipairs(INDEX_PROBES) do
        local path, subject, want4, want5, why = probe[1], probe[2], probe[3], probe[4], probe[5]
        local J, bot = RF.load(path, subject)
        local list = J.Skill.GetAbilityList(bot)
        assert(list[4] == want4,
            subject .. ' on ' .. path .. ': sAbilityList[4] is '
            .. tostring(list[4]) .. ', recorded ' .. tostring(want4)
            .. ' (' .. why .. ').')
        assert(list[5] == want5,
            subject .. ' on ' .. path .. ': sAbilityList[5] is '
            .. tostring(list[5]) .. ', recorded ' .. tostring(want5) .. '.')
        -- index 6 must stay the ultimate whatever else moved
        assert(list[6] == ULT[subject:match('^npc_dota_hero_(.+)$')],
            subject .. ': sAbilityList[6] is ' .. tostring(list[6])
            .. ', expected the ultimate. If this breaks, every ConsiderR test on '
            .. 'real frames silently stops reaching ultimate logic (GH #36).')
    end
end

tests['[6] the mock IsTalent() is a constant false -- that is why talents leak in'] = function()
    local J, bot = RF.load('tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua',
                           'npc_dota_hero_crystal_maiden')
    assert(J ~= nil)
    local talent = bot:GetAbilityByName('special_bonus_h_p200')
    assert(talent ~= nil, 'the mock no longer hands back a handle for a talent row')
    assert(talent:IsTalent() == false,
        'the mock now answers IsTalent() truthfully for special_bonus_h_p200. If '
        .. 'that is a real fix, GetAbilityList will start filtering these rows and '
        .. 'the section-6 table above must be re-measured -- CM index 4 becomes '
        .. 'nil, not the talent.')
    assert(talent:IsHidden() == false,
        'the mock now answers IsHidden() for a talent row; re-measure section 6.')
end

tests['[6] the fixture world cannot exhibit the nil handle the engine could'] = function()
    -- On the frame where CM's index 4 is nil, bot:GetAbilityByName(nil) still
    -- hands back a table.  So "X.ConsiderCrystalClone crashes on a nil handle" is
    -- UNTESTABLE here by construction -- the harness papers over exactly the
    -- failure the missing guard would produce.  Recorded so nobody reads a green
    -- fixture run as evidence that the guard is unnecessary.
    local _, bot = RF.load('tests/fixtures/f_113638_cm_chain_rescue.lua',
                           'npc_dota_hero_crystal_maiden')
    assert(bot:GetAbilityByName(nil) ~= nil,
        'the mock now returns nil for GetAbilityByName(nil). That is closer to the '
        .. 'engine -- and it means the unguarded CrystalClone:IsTrained() in '
        .. 'X.ConsiderCrystalClone can now be reproduced. Go get the frame.')
end

return tests

-- [hero] GH #287 §3: the enumeration -- which shipped build tables reference an
-- `sAbilityList` index that does not resolve to a learnable ability.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- GH #286/#287 found Obsidian Destroyer's skill build spending points on
-- nothing, and #287 §3 asked for the same question over every hero rather than
-- only OD, on the grounds that "只有 OD 受影响" was an assumption.  It also said
-- the trigger "**离线读不出来**(要引擎的 `GetAbilityInSlot`)".
--
-- ⭐ THAT PREMISE IS FALSE, AND THAT IS WHY THIS FILE IS CHEAP.  The engine's
-- slot order is in the game's own `npc_heroes.txt` ("AbilityN"), already
-- mirrored into `tests/mock/hero_slots.lua` by tools/agent/hero_slot_map.py for
-- GH #209, and which name is an ultimate is in tests/mock/ability_meta.lua
-- (GH #36).  With those two, the SHIPPED walk `J.Skill.GetAbilityList`
-- (bots/FunLib/aba_skill.lua) runs offline on every hero's real layout.  No
-- .dem, no batch, no AWS.
--
-- WHAT IS UNREADABLE, AND HOW IT IS HANDLED
--   The walk drops an ability only when `NOT_LEARNABLE` **and** `IsHidden()`,
--   and `IsHidden()` cannot be evaluated outside the game VM
--   (test_focus_innate_index_anchor.lua §2).  So this census does not guess it:
--   for each hero it enumerates every drop-world over the optional slots
--   (innates, shard/scepter grants) exactly as
--   test_hero_slot_order_anchor.lua §3 does, and reports a hit as
--   "in k of the N worlds".  k == N is a fact about the hero; k < N is a fact
--   about a predicate this repo cannot read.
--
-- ⭐⭐ WHAT THE CENSUS MEASURED (126 heroes, 2026-08-29)
--   1. **ZERO build indices resolve to nil in every world.**  The predicate
--      #287 §3 named -- "引用了一个在 sAbilityList 里为 nil 的下标" -- has no
--      unconditional instance in the repo, **OD included**.  Four heroes hit it
--      in SOME worlds only (§3 below).
--   2. **OD's defect is a different one: index 4 is `generic_hidden`, in 2 of 2
--      worlds**, and its build spends 4 points on it.  The placeholder is a
--      string, not nil, so every nil-shaped detector is silent on it.
--   3. **OD is the only hero whose build hits a placeholder unconditionally**;
--      six more do so in some worlds (§4).
--   4. **No hero's ultimate sits below slot 4** (§5), so `sAbilityList[6]` is
--      written for all 126.  This matters for #287 §2, which proposed either
--      "let GetAbilityList write [6] for a `slot < 4` ultimate" or "change OD's
--      build from 6 to 4": the first is a no-op for OD (its ultimate is at slot
--      5 and index 6 is already written) and the second would aim the build at
--      the placeholder measured in point 2.  Both candidate fixes address a
--      mechanism the KV says is not OD's.
--
-- ⚠️ LIMITS -- READ BEFORE CITING
--   * This is a STATIC read: KV slot order + the shipped walk.  It says which
--     index names what.  It does NOT say what the level-up consumer then does
--     with that name -- `ability_item_usage_generic.lua` has a `generic_hidden`
--     escape hatch (it drops the entry and levels the NEXT one), so a
--     placeholder reference is a wasted build slot here, not a proven stall.
--     The stall itself is GH #290's, measured from replays.
--   * `tests/mock/hero_slots.lua` is a snapshot of the d2vpkr mirror.  A patch
--     that moves a slot invalidates every reading below -- regenerate first.
--   * Build rows are parsed out of the hero file's `t<Name>BuildList` literals
--     (commented-out rows skipped) -- ALL of them since 2026-08-29, not only
--     `tAllAbilityBuildList`, because a gated row ships too; see parse_builds
--     and section 8.  A hero that computes its build some other way is counted
--     as uncensused and named, not silently dropped.
--   * "Which name is an ultimate" comes from tests/mock/ability_meta.lua, and it
--     has NO row for invoker (`invoker_invoke` is not ABILITY_TYPE_ULTIMATE in
--     the KV).  So for invoker the walk writes no index 6 from the ultimate
--     branch at all -- index 6 is simply the sixth ability it appended, which
--     happens to be `invoker_invoke` (slots 0..5 are quas/wex/exort/empty1/
--     empty2/invoke).  Section 6 therefore says nothing about invoker, and the
--     hero is clean below only because that coincidence holds.
--   * Nothing here gates and nothing in bots/ changes.  It is a measurement
--     plus a ratchet, so the next hero to acquire this defect fails loudly.

package.path = 'tests/?.lua;' .. package.path

local api  = require('mock.bot_api')
local rf   = require('mock.replay_fixture')
local meta = require('mock.ability_meta')

local SLOTS_LUA = 'tests/mock/hero_slots.lua'
local FRAME     = 'tests/fixtures/f_113638_cm_chain_rescue.lua'
local PLACEHOLDER = 'generic_hidden'

local SLOTS = dofile(SLOTS_LUA)

-- Heroes that carry no `tAllAbilityBuildList` literal, or no KV slot row.
-- Named rather than counted: "the census covered N" is only honest next to
-- "and these are the ones it could not".
local NO_BUILD_LITERAL = { wisp = true }          -- Io's build is not a literal
local NO_SLOT_ROW      = { lone_druid_bear = true } -- a summoned unit, not a hero

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Rows of EVERY top-level `t<Name>BuildList` literal, commented-out rows
--- excluded.  Also returns the table names it read, in source order.
---
--- ⭐ WHY NOT JUST `tAllAbilityBuildList` (changed 2026-08-29, GH #287 §2).
--- Reading only the default table makes this census blind to the one shape it
--- exists to catch.  A GATED build row is a build this repo can ship -- arm the
--- id and every bot on that side levels from it -- and four points spent on a
--- placeholder cost the same there as in the default row.  Three such tables
--- exist today (section 8 pins the set): hero_skeleton_king's tKillBuildList
--- behind 'wkbuild', hero_warlock's tLaningAbilityBuildList, and
--- hero_obsidian_destroyer's tObjurgationBuildList behind 'odbuild'.  Before
--- this change the last of those -- written BECAUSE of section 4 -- would have
--- been invisible to section 4.
---
--- The name pattern requires an upper-case letter after the `t` so that
--- hero_wisp's `talentBuildList` (a call, not a literal) cannot be read as one.
local function parse_builds(sSrc)
    local tRows, tNames = {}, {}
    for sName, sBlock in sSrc:gmatch('\nlocal (t%u[%w_]*BuildList)%s*=%s*(%b{})') do
        tNames[#tNames + 1] = sName
        for sLine in sBlock:gmatch('[^\n]+') do
            local sCode = sLine:gsub('%-%-.*$', '')
            local sInner = sCode:match('{%s*([%d%s,]+)%s*}')
            if sInner then
                local tRow = {}
                for sN in sInner:gmatch('%d+') do tRow[#tRow + 1] = tonumber(sN) end
                if #tRow > 0 then tRows[#tRows + 1] = tRow end
            end
        end
    end
    if #tNames == 0 then return nil end
    return tRows, tNames
end

local function is_talent_name(sName)
    return sName:match('^special_bonus') ~= nil
end

--- A synthetic bot serving one hero's real slot order to the shipped walk.
--- Same shape as test_hero_slot_order_anchor.lua's, generalised over all heroes:
--- fabricated handles, declared as such -- no .dem carries slot order.
local function make_bot(sHero, tSlots, tUlts, tDrop)
    return api.MakeUnit{
        GetUnitName = 'npc_dota_hero_' .. sHero,
        GetAbilityInSlot = function(_, nSlot)
            local sName = tSlots[nSlot]
            -- Past the recorded rows the engine hands back placeholders; serving
            -- them keeps the produced list the length the engine's would be.
            if sName == nil or sName == '' then sName = PLACEHOLDER end
            local bDropped = tDrop[nSlot] == true
            return api.MakeUnit{
                GetName     = sName,
                IsUltimate  = tUlts[sName] == true,
                IsTalent    = is_talent_name(sName),
                IsHidden    = bDropped,
                GetBehavior = bDropped and DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE or 0,
            }
        end,
    }
end

--- Slots whose keep/drop the walk actually decides: `generic_hidden` is
--- name-checked ahead of the drop rule, the basics (slots 0..2) have nothing in
--- front of them, and an ultimate at slot >= 4 goes to the fixed index 6.
local function optional_slots(tSlots, tUlts)
    local out = {}
    for nSlot = 3, 10 do
        local sName = tSlots[nSlot]
        if sName ~= nil and sName ~= '' and sName ~= PLACEHOLDER
            and not is_talent_name(sName) and tUlts[sName] ~= true
        then
            out[#out + 1] = nSlot
        end
    end
    return out
end

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

local function shipped_heroes()
    local p = assert(io.popen('ls bots/BotLib/hero_*.lua'))
    local out = {}
    for sPath in p:lines() do out[#out + 1] = sPath:match('hero_(.+)%.lua$') end
    p:close()
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------------
-- The census itself, run once and shared by the sections below.

local function census()
    local J = rf.load(FRAME)
    local tOut = {
        heroes = {},        -- hero -> { nWorlds, refs, nilw, ghw }
        censused = 0,
        skipped_no_build = {},
        skipped_no_slots = {},
    }
    for _, sHero in ipairs(shipped_heroes()) do
        local tSlots = SLOTS[sHero]
        local tRows, tNames = parse_builds(read_file('bots/BotLib/hero_' .. sHero .. '.lua'))
        if tSlots == nil then
            tOut.skipped_no_slots[#tOut.skipped_no_slots + 1] = sHero
        elseif tRows == nil or #tRows == 0 then
            tOut.skipped_no_build[#tOut.skipped_no_build + 1] = sHero
        else
            local tUlts = meta.ULTIMATES['npc_dota_hero_' .. sHero] or {}
            local tWorlds = worlds(optional_slots(tSlots, tUlts))
            local tRefs = {}
            for _, tRow in ipairs(tRows) do
                for _, nIdx in ipairs(tRow) do
                    tRefs[nIdx] = (tRefs[nIdx] or 0) + 1
                end
            end
            local tNil, tGh = {}, {}
            for _, w in ipairs(tWorlds) do
                local tList = J.Skill.GetAbilityList(make_bot(sHero, tSlots, tUlts, w))
                for nIdx in pairs(tRefs) do
                    if tList[nIdx] == nil then
                        tNil[nIdx] = (tNil[nIdx] or 0) + 1
                    elseif tList[nIdx] == PLACEHOLDER then
                        tGh[nIdx] = (tGh[nIdx] or 0) + 1
                    end
                end
            end
            tOut.heroes[sHero] = {
                nWorlds = #tWorlds, refs = tRefs, nilw = tNil, ghw = tGh,
                tables = tNames, nRows = #tRows,
            }
            tOut.censused = tOut.censused + 1
        end
    end
    return tOut
end

local CENSUS = census()

--- hero -> { [index] = worlds-hit } for whichever axis, flattened for compare.
local function hits(sAxis, bOnlyUnconditional)
    local out = {}
    for sHero, tRec in pairs(CENSUS.heroes) do
        for nIdx, nHit in pairs(tRec[sAxis]) do
            if (not bOnlyUnconditional) or nHit == tRec.nWorlds then
                out[sHero] = out[sHero] or {}
                out[sHero][nIdx] = nHit
            end
        end
    end
    return out
end

local function describe(tHits)
    local parts = {}
    for sHero, tIdx in pairs(tHits) do
        for nIdx, nHit in pairs(tIdx) do
            parts[#parts + 1] = ('%s[%d] in %d/%d worlds')
                :format(sHero, nIdx, nHit, CENSUS.heroes[sHero].nWorlds)
        end
    end
    table.sort(parts)
    return table.concat(parts, ', ')
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The census covers what ships, and names what it could not cover.

tests['[1] every shipped hero is censused or named as an exception'] = function()
    for _, sHero in ipairs(CENSUS.skipped_no_slots) do
        assert(NO_SLOT_ROW[sHero],
            'hero_' .. sHero .. '.lua has no row in ' .. SLOTS_LUA .. '. That is a '
                .. 'PARSE HOLE or a hero added without regenerating -- run '
                .. 'tools/agent/hero_slot_map.py. Until then this hero is UNCENSUSED, '
                .. 'and "OD is the only one" would be a claim about 125 heroes.')
    end
    for _, sHero in ipairs(CENSUS.skipped_no_build) do
        assert(NO_BUILD_LITERAL[sHero],
            'hero_' .. sHero .. '.lua carries no tAllAbilityBuildList literal, so this '
                .. 'census cannot see its build. Either the file changed shape or the '
                .. 'parser broke; do not read the sections below as covering it.')
    end
    assert(CENSUS.censused == 126,
        'censused ' .. CENSUS.censused .. ' heroes, recorded 126 on 2026-08-29. A hero '
            .. 'added or removed changes this -- update the number together with a '
            .. 'fresh reading of sections 2-5, not on its own.')
end

-- ---------------------------------------------------------------------------
-- 2. The predicate GH #287 §3 named has no unconditional instance.

tests['[2] no build index is nil in every drop-world -- OD included'] = function()
    local tAlways = hits('nilw', true)
    assert(next(tAlways) == nil,
        'a build index now resolves to nil in EVERY world: ' .. describe(tAlways)
            .. '. That is the GH #287 §3 predicate finally firing for real, and it is '
            .. 'a permanent skill-point stall unless the consumer\'s nil handler catches '
            .. 'it -- fix the build table or the walk, do not relax this assertion.')

    local tOD = CENSUS.heroes.obsidian_destroyer
    assert(tOD ~= nil, 'obsidian_destroyer fell out of the census')
    assert(next(tOD.nilw) == nil,
        'obsidian_destroyer now has a nil-resolving index. Section 2 recorded NONE: '
            .. 'OD\'s defect was the placeholder at index 4 (section 4), not a nil. '
            .. 'If this fires, re-read GH #287 §2 -- its two candidate fixes were '
            .. 'written for the nil mechanism.')
end

-- ---------------------------------------------------------------------------
-- 3. The conditional half: hits that turn on the unreadable IsHidden().

tests['[3] four heroes reference an index that is nil in SOME worlds'] = function()
    local tSome = {}
    for sHero, tIdx in pairs(hits('nilw', false)) do
        tSome[sHero] = tIdx
    end
    local tExpect = {
        monkey_king      = { [4] = 1 },
        nevermore        = { [5] = 4 },
        phantom_assassin = { [5] = 2 },
        troll_warlord    = { [5] = 2 },
    }
    for sHero, tIdx in pairs(tExpect) do
        assert(tSome[sHero] ~= nil,
            sHero .. ' no longer references a sometimes-nil index. That is progress, '
                .. 'not a failure -- drop it from the table and say what changed.')
        for nIdx, nHit in pairs(tIdx) do
            assert(tSome[sHero][nIdx] == nHit,
                ('%s[%d] is nil in %s worlds, recorded %d/%d')
                    :format(sHero, nIdx, tostring(tSome[sHero][nIdx]), nHit,
                            CENSUS.heroes[sHero].nWorlds))
        end
    end
    for sHero in pairs(tSome) do
        assert(tExpect[sHero] ~= nil,
            sHero .. ' newly references a sometimes-nil index (' .. describe(tSome)
                .. '). Whether it bites turns on IsHidden(), which this repo cannot '
                .. 'read -- treat it as a real risk, not a rounding error.')
    end
end

-- ---------------------------------------------------------------------------
-- 4. The axis OD actually sits on: the placeholder, which is a string.

tests['[4] obsidian_destroyer is the only unconditional placeholder reference'] = function()
    local tAlways = hits('ghw', true)
    local tOD = tAlways.obsidian_destroyer
    assert(tOD ~= nil and tOD[4] ~= nil,
        'obsidian_destroyer[4] no longer resolves to ' .. PLACEHOLDER .. ' in every '
            .. 'world. If hero_obsidian_destroyer.lua was fixed, this is the assertion '
            .. 'that should be rewritten to describe the new build -- see GH #287.')
    assert(tOD[4] == CENSUS.heroes.obsidian_destroyer.nWorlds,
        'obsidian_destroyer[4] hits the placeholder in only part of its worlds now')
    assert(CENSUS.heroes.obsidian_destroyer.refs[4] == 4,
        'OD\'s build spends ' .. tostring(CENSUS.heroes.obsidian_destroyer.refs[4])
            .. ' points on index 4, recorded 4. That count IS the cost of the defect.')

    for sHero in pairs(tAlways) do
        assert(sHero == 'obsidian_destroyer',
            sHero .. ' now spends build points on ' .. PLACEHOLDER .. ' in every world '
                .. '(' .. describe(tAlways) .. '). Until 2026-08-29 OD was alone in '
                .. 'this, which is what made "only OD is affected" checkable.')
    end
end

tests['[5] six more heroes hit the placeholder in some worlds'] = function()
    local tExpect = {
        beastmaster        = { [4] = 1 },
        morphling          = { [4] = 2 },
        nevermore          = { [4] = 1, [5] = 2 },
        obsidian_destroyer = { [4] = 2 },
        phantom_assassin   = { [5] = 1 },
        troll_warlord      = { [4] = 1, [5] = 1 },
    }
    local tGot = hits('ghw', false)
    for sHero, tIdx in pairs(tExpect) do
        assert(tGot[sHero] ~= nil, sHero .. ' no longer hits ' .. PLACEHOLDER
            .. ' in any world -- progress; drop the row and say what changed.')
        for nIdx, nHit in pairs(tIdx) do
            assert(tGot[sHero][nIdx] == nHit,
                ('%s[%d] hits %s in %s worlds, recorded %d')
                    :format(sHero, nIdx, PLACEHOLDER, tostring(tGot[sHero][nIdx]), nHit))
        end
    end
    for sHero in pairs(tGot) do
        assert(tExpect[sHero] ~= nil,
            sHero .. ' newly spends build points on ' .. PLACEHOLDER
                .. '. Full census: ' .. describe(tGot))
    end
end

-- ---------------------------------------------------------------------------
-- 5. The mechanism GH #287 §3 hypothesised, measured directly.

tests['[6] no hero has to reach index 6 through a slot < 4 ultimate'] = function()
    local tBelow = {}
    for sHero, tRow in pairs(SLOTS) do
        local tUlts = meta.ULTIMATES['npc_dota_hero_' .. sHero] or {}
        local bHasHigh, tLow = false, {}
        for nSlot = 0, 10 do
            local sName = tRow[nSlot]
            if sName ~= nil and tUlts[sName] then
                if nSlot >= 4 then bHasHigh = true else tLow[#tLow + 1] = nSlot end
            end
        end
        if not bHasHigh and #tLow > 0 then
            tBelow[#tBelow + 1] = sHero .. '@' .. tLow[1]
        end
    end
    table.sort(tBelow)
    assert(#tBelow == 0,
        'hero(es) whose ONLY ultimate sits below slot 4: ' .. table.concat(tBelow, ', ')
            .. '. For those, X.GetAbilityList never writes sAbilityList[6], so a build '
            .. 'row referencing 6 gets whatever the walk appended into that position '
            .. 'instead -- the placeholder under this harness (which serves one for '
            .. 'every empty slot row), nil in an engine that hands back no ability at '
            .. 'all. That is the mechanism GH #287 §3 asked to be enumerated, and on '
            .. '2026-08-29 it had zero members.')
end

tests['[6] dark_willow is the one hero with an ult-flagged ability below slot 4'] = function()
    -- Not a defect: `dark_willow_bedlam` at slot 3 fails the walk's `slot >= 4`
    -- test and is appended like a normal ability, while `dark_willow_terrorize`
    -- at slot 5 still writes index 6.  It is recorded because it is the single
    -- case where "the ultimate" is not one ability, and any future reading of
    -- section 6 that forgets it will misattribute the exception.
    local tLow = {}
    for sHero, tRow in pairs(SLOTS) do
        local tUlts = meta.ULTIMATES['npc_dota_hero_' .. sHero] or {}
        for nSlot = 0, 3 do
            local sName = tRow[nSlot]
            if sName ~= nil and tUlts[sName] then
                tLow[#tLow + 1] = sHero .. '@' .. nSlot
            end
        end
    end
    table.sort(tLow)
    assert(#tLow == 1 and tLow[1] == 'dark_willow@3',
        'ult-flagged abilities below slot 4: ' .. table.concat(tLow, ', ')
            .. ', recorded exactly dark_willow@3')
end

-- ---------------------------------------------------------------------------
-- 6. The focus five, stated separately because that is this stream's mandate.

tests['[7] the focus five reference no nil and no placeholder in any world'] = function()
    for _, sHero in ipairs({ 'axe', 'crystal_maiden', 'lion', 'skeleton_king', 'zuus' }) do
        local tRec = CENSUS.heroes[sHero]
        assert(tRec ~= nil, sHero .. ' is not in the census')
        assert(next(tRec.nilw) == nil,
            sHero .. ' now references a nil index in some world -- the focus five were '
                .. 'clean on 2026-08-29')
        assert(next(tRec.ghw) == nil,
            sHero .. ' now spends a build point on ' .. PLACEHOLDER .. '. Axe and '
                .. 'Earthshaker carry TWO placeholders (slots 3 and 4) and stay clean '
                .. 'only because their builds never index past 3 except at 6.')
    end
end

-- ---------------------------------------------------------------------------
-- 7. The set of NON-default build tables, pinned so a new one is read on
--    purpose rather than silently.

tests['[8] exactly three heroes carry a second build table'] = function()
    local tExtra = {}
    for sHero, tRec in pairs(CENSUS.heroes) do
        for _, sName in ipairs(tRec.tables or {}) do
            if sName ~= 'tAllAbilityBuildList' then
                tExtra[#tExtra + 1] = sHero .. ':' .. sName
            end
        end
    end
    table.sort(tExtra)
    local tExpect = {
        'obsidian_destroyer:tObjurgationBuildList',  -- gated 'odbuild', GH #287 §2
        'skeleton_king:tKillBuildList',              -- gated 'wkbuild'
        'warlock:tLaningAbilityBuildList',           -- selected by lane role
    }
    assert(#tExtra == #tExpect,
        'non-default build tables: ' .. table.concat(tExtra, ', ') .. '; recorded '
            .. table.concat(tExpect, ', ') .. ' on 2026-08-29. A new one is not a '
            .. 'failure -- add it here AFTER checking sections 2-5 still read the '
            .. 'same, because its rows now enter the census too.')
    for i, s in ipairs(tExpect) do
        assert(tExtra[i] == s,
            'expected ' .. s .. ' at position ' .. i .. ', got ' .. tostring(tExtra[i]))
    end

    -- The reason the parser was widened: OD's gated row must be visible to the
    -- same census that found the defect it repairs.
    local tOD = CENSUS.heroes.obsidian_destroyer
    assert(tOD.nRows == 2,
        'obsidian_destroyer contributes ' .. tostring(tOD.nRows) .. ' build rows to '
            .. 'the census, recorded 2 (the shipped row and the gated odbuild row)')
    assert(tOD.refs[3] == 4,
        'the gated odbuild row no longer spends 4 points on index 3 (objurgation); '
            .. 'refs[3] = ' .. tostring(tOD.refs[3]) .. '. Section 4 still measures the '
            .. 'shipped row spending 4 on the placeholder at index 4 -- if THAT one '
            .. 'went away, odbuild was promoted and both assertions move together.')
    assert(tOD.ghw[3] == nil and tOD.nilw[3] == nil,
        'obsidian_destroyer[3] no longer resolves to a real ability in every world. '
            .. 'That index is the whole point of the odbuild row -- if it stopped '
            .. 'naming objurgation, the fix is aimed at nothing.')
end

return tests

-- [hero] `GRANTSLOT`: what an index into `sAbilityList` can and cannot name.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- `sAbilityList` is NOT the hero's slot array.  It is the array
-- `J.Skill.GetAbilityList` COMPACTS out of slots 0..10
-- (bots/FunLib/aba_skill.lua): every accepted ability is appended with
-- `table.insert`, and the only fixed index is 6, written directly for the
-- ultimate.  So index N means "the Nth ability the walk accepted", and ANY
-- ability the walk accepts ahead of the one you meant shifts it by one.
--
-- Zeus reaches for two abilities by index, and both have optional abilities in
-- front of them (slot order read off the Dota 2 datafeed, hero_id=22, on
-- 2026-08-26; the grant flags are `IsGrantedByScepter` / `IsGrantedByShard` in
-- the game's own KV via the dotabuff/d2vpkr mirror this repo already reads):
--
--     slot 0  zuus_arc_lightning
--     slot 1  zuus_lightning_bolt
--     slot 2  zuus_heavenly_jump
--     slot 3  zuus_cloud             IsGrantedByScepter 1   (Nimbus)
--     slot 4  zuus_lightning_hands   IsGrantedByShard   1
--     slot 5  zuus_thundergods_wrath ultimate -> index 6
--     slot 6  zuus_static_field      innate
--
--   * `abilityD  = sAbilityList[4]` -- every consumer sits behind
--     `bot:HasScepter()`, so the file means Nimbus.
--   * `abilityAS = sAbilityList[5]` -- its only consumer is
--     X.GetStaticFieldBonus, so the file means Static Field.
--
-- WHAT IS PROVED HERE, AND HOW IT SURVIVES AN UNREADABLE PREDICATE
-- ----------------------------------------------------------------
-- The walk drops an ability only when `NOT_LEARNABLE` **and** `IsHidden()` are
-- both true, and `IsHidden()` cannot be evaluated outside the game VM
-- (tests/test_focus_innate_index_anchor.lua section 2 established that; nothing
-- since has made it readable).  So this file does not GUESS the drop decision:
-- it enumerates it for the three optional abilities -- 2^3 = 8 worlds -- and
-- drives the SHIPPED GetAbilityList on Zeus's real slot order in each.
-- Measured, section 1:
--
--     index 5 is Static Field in ZERO of the eight worlds
--        (zuus_lightning_hands in 2, nil in 4, generic_hidden in 2)
--     index 4 is Nimbus in exactly the four worlds that KEEP grant abilities
--
-- So `abilityAS` never names what its only consumer thinks it names, whatever
-- the engine decides about hidden flags; and `abilityD` is right in half the
-- worlds -- right, that is, only under a predicate this repo cannot read.
-- Four of the eight worlds hand back nil, which is what the ungated nil checks
-- are for.
--
-- ⚠️ One dependency inside that measurement is declared rather than buried:
-- GetAbilityList writes the ultimate to the fixed index 6 and keeps appending
-- afterwards, so every later `table.insert` asks `#` about a table WITH A HOLE
-- -- unspecified in Lua 5.1.  On this VM it answers 6, so the appends land past
-- both bindings; a VM answering 4 would put a kept Static Field at index 5.
-- Section 1's world assertion pins that, and it is itself an argument for the
-- fix: correct index arithmetic here is not something the file should be
-- relying on at all.
--
-- WHAT IT COSTS (why the two consumers make this worth a candidate)
--   * X.GetStaticFieldBonus feeds `target:GetHealth() * bonus` into the kill
--     estimate that decides whether the ~130s global execute is cashed in.  Off
--     a wrong handle the shipped 0.09 becomes a term gated on an unrelated
--     ability's IsTrained(), and the armed `zusstatic` leg (GH #173) reads
--     `damage_health_pct` off an ability that has no such key -- a silent 0
--     under the GH #162 house rule, which is the one answer that makes #173's
--     fix indistinguishable from doing nothing.
--   * X.ConsiderD issues a LOCATION order.  Lightning Hands is TOGGLE|ATTACK
--     and the ultimate is NO_TARGET, so a wrong handle there is an order the
--     engine cannot execute (axis `CASTSHAPE`, GH #177) plus the `return` that
--     eats the rest of the dispatch tick.
--
-- THE SHAPE OF THE CHANGE
--   `X.GetBoundAbility( hShipped, sName )` -- gate-off returns the caller's own
--   file-local as the function's LAST statement, so gate-off equivalence is
--   structural, not measured.  Armed (`zusbind`, turbo-only) it fetches by name
--   and still falls back when the engine answers nil.  Binding by name is this
--   repo's majority pattern, not an invention: 40 file-scope sites under
--   bots/BotLib already fetch a shard/scepter ability by literal name, and
--   hero_skeleton_king.lua re-fetches `abilityW` by name after checking it.
--
--   Two nil checks ship UNGATED (X.GetStaticFieldBonus, X.ConsiderD): indexing
--   a nil handle raises inside X.SkillsComplement and the broken engine error
--   handler turns that into a silent whole-tick abort (AGENTS.md).  Structurally
--   a no-op wherever the shipped code does not already raise.  Same split as
--   GH #188 / #192: forced repairs ungated, policy gated.
--
-- ⚠️ LIMITS -- READ BEFORE CITING
--   * This settles which name each index CANNOT carry, never which one it does.
--     The datafeed is an anchor for slot ORDER; that GetAbilityInSlot
--     enumerates the same order is an assumption, and section 5 says so.
--     ⭐ RESOLVED 2026-08-26 (GH #209): that assumption is now a measurement.
--     The game's own npc_heroes.txt carries a literal ability-index map per
--     hero; tools/agent/hero_slot_map.py reads it into
--     tests/mock/hero_slots.lua, and tests/test_hero_slot_order_anchor.lua
--     checks the seven rows quoted above against it, one by one, so a patch
--     that moves any of them turns THIS candidate red rather than silently
--     making it measure the wrong ability.  Nothing else in this file changes:
--     which abilities the walk KEEPS is still the unreadable half.
--   * The corpus cannot arbitrate either: the .dem ability array is flattened
--     and is not slot order (test_focus_innate_index_anchor.lua section 5).
--   * In the worlds where both grant abilities are dropped, the walk appends
--     after `sAbilityList[6]` has been written, so `#` runs over a table with a
--     hole and Lua 5.1 leaves that length UNSPECIFIED.  Section 1 therefore
--     asserts the property over whatever the shipped code returns; it never
--     asserts a particular index for those worlds.
--   * Nothing here says the corrected handles WIN games.  Locally-correct is
--     not emergently-good (AGENTS.md, the lanefix lesson).  That is the gate's
--     job.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local ZUUS    = 'bots/BotLib/hero_zuus.lua'
local FRAME   = 'tests/fixtures/f_230952_zuus_ult_hoard.lua'
local CAND_ID = 'zusbind'

local NIMBUS = 'zuus_cloud'
local STATIC = 'zuus_static_field'

local function read_file(sPath)
    local fh = assert(io.open(sPath, 'r'), 'cannot open ' .. sPath)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Strip Lua line comments BEFORE counting anything: the reasoning block in the
--- hero file quotes every name and every id it explains, and a parser that
--- reads prose reports the prose (GH #136's first census).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

local function load_zuus(bArmed, bTurbo)
    local J, bot = rf.load(FRAME)

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(sId) return sId == CAND_ID end
        or function() return false end

    return rf.load_hero('zuus'), J, bot
end

-- ---------------------------------------------------------------------------
-- Zeus's real slot order, and a synthetic bot that serves it to the shipped
-- walk.  Fabricated handles are declared as such: no .dem carries slot order.

local SLOTS = {
    [0] = { name = 'zuus_arc_lightning' },
    [1] = { name = 'zuus_lightning_bolt' },
    [2] = { name = 'zuus_heavenly_jump' },
    [3] = { name = NIMBUS,                 optional = 'cloud' },
    [4] = { name = 'zuus_lightning_hands', optional = 'hands' },
    [5] = { name = 'zuus_thundergods_wrath', ult = true },
    [6] = { name = STATIC,                 optional = 'static' },
}

--- @param tDrop table  which optional abilities the walk drops in this world
local function make_zuus(tDrop)
    local nNotLearnable = DOTA_ABILITY_BEHAVIOR_NOT_LEARNABLE
    assert(type(nNotLearnable) == 'number' and nNotLearnable > 0,
        'the NOT_LEARNABLE constant must be a real number for this enumeration to mean anything')

    local function ability(sName, bDropped, bUlt)
        return api.MakeUnit{
            GetName     = sName,
            IsUltimate  = bUlt == true,
            IsTalent    = false,
            IsHidden    = bDropped == true,
            GetBehavior = bDropped and nNotLearnable or 0,
        }
    end

    return api.MakeUnit{
        GetUnitName = 'npc_dota_hero_zuus',
        GetAbilityInSlot = function(_, nSlot)
            local t = SLOTS[nSlot]
            if t ~= nil then
                return ability(t.name, t.optional ~= nil and tDrop[t.optional] == true, t.ult)
            end
            -- Empty engine slots hold generic_hidden, and the walk keeps those
            -- (slot ~= 0), so leaving them out would make the tail of the list
            -- shorter than the engine's.
            return ability('generic_hidden', false, false)
        end,
    }
end

local WORLDS = {}
for _, bCloud in ipairs({ false, true }) do
    for _, bHands in ipairs({ false, true }) do
        for _, bStatic in ipairs({ false, true }) do
            table.insert(WORLDS, { cloud = bCloud, hands = bHands, static = bStatic })
        end
    end
end

local function world_label(w)
    return 'dropped{cloud=' .. tostring(w.cloud) .. ',hands=' .. tostring(w.hands)
        .. ',static=' .. tostring(w.static) .. '}'
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1. The disjunction, computed by the shipped walk in all 8 worlds.

tests['[hero] index 5 is Static Field in NONE of the eight drop-worlds'] = function()
    local J = rf.load(FRAME)
    assert(#WORLDS == 8, 'the enumeration must be complete, got ' .. #WORLDS)

    local tSeen = {}
    for _, w in ipairs(WORLDS) do
        local list = J.Skill.GetAbilityList(make_zuus(w))
        assert(list[5] ~= STATIC, STATIC .. ' reached index 5 in ' .. world_label(w)
            .. ' -- `abilityAS` would be right there and the candidate needs re-deriving')
        local sGot = tostring(list[5])
        tSeen[sGot] = (tSeen[sGot] or 0) + 1
    end

    -- Guard against the assertion above passing for a boring reason (an empty
    -- list in every world would also never equal STATIC).  What index 5 DOES
    -- carry is recorded here rather than in prose: two worlds hand back the
    -- shard ability, four hand back nil, two hand back the empty-slot
    -- placeholder.
    assert(tSeen['zuus_lightning_hands'] == 2,
        'expected the shard ability at index 5 in the two worlds that keep both grants, got '
            .. tostring(tSeen['zuus_lightning_hands']))
    assert(tSeen['nil'] == 4, 'expected a nil index 5 in four worlds, got ' .. tostring(tSeen['nil']))
    assert(tSeen['generic_hidden'] == 2,
        'expected the empty-slot placeholder twice, got ' .. tostring(tSeen['generic_hidden']))
end

tests['[hero] index 4 is Nimbus exactly where the walk keeps hidden grant abilities'] = function()
    local J = rf.load(FRAME)
    local nRight = 0
    for _, w in ipairs(WORLDS) do
        local list = J.Skill.GetAbilityList(make_zuus(w))
        if w.cloud then
            assert(list[4] ~= NIMBUS, 'a dropped Nimbus cannot be at index 4 in ' .. world_label(w))
        else
            assert(list[4] == NIMBUS, 'a kept Nimbus must land at index 4 in ' .. world_label(w)
                .. ', got ' .. tostring(list[4]))
            nRight = nRight + 1
        end
    end
    assert(nRight == 4, 'four of the eight worlds keep Nimbus, got ' .. nRight)
    -- So `abilityD` is right in half the worlds and `abilityAS` in none: the two
    -- bindings are never both right, and the ONE binding that can be right is
    -- right only under a predicate this repo cannot read.
end

tests['[hero] the four nil worlds are the ungated nil check\'s whole reason'] = function()
    local J = rf.load(FRAME)
    local nNil = 0
    for _, w in ipairs(WORLDS) do
        if J.Skill.GetAbilityList(make_zuus(w))[5] == nil then nNil = nNil + 1 end
    end
    assert(nNil == 4, 'expected four worlds where sAbilityList[5] is nil, got ' .. nNil)
    -- In those worlds the file calls bot:GetAbilityByName(nil).  The mock hands
    -- back a shared untrained stub (documented in tests/mock/bot_api.lua); the
    -- engine's answer is NOT documented, and if it is nil the shipped code
    -- indexes nil inside X.SkillsComplement -- a silent whole-tick abort.
end

tests['WORLD ASSERTION: the index arithmetic rests on `#` over a table with a hole'] = function()
    -- GetAbilityList writes the ultimate to the fixed index 6 and keeps
    -- appending with table.insert afterwards, so every later insert asks `#`
    -- about a table with a hole -- unspecified in Lua 5.1.  On THIS VM the
    -- answer is 6 (the append goes to 7, past both bindings).  A VM that
    -- answered 4 here would put a kept Static Field at index 5 and change the
    -- world table above, which is precisely why the fix is to stop counting.
    local t = { 'a', 'b', 'c', 'd' }
    t[6] = 'ult'
    assert(#t == 6, 'this VM used to answer 6 for #{1,2,3,4,[6]}; it now answers ' .. #t
        .. ' -- re-run the world enumeration before citing any index in this file')

    local src = read_file('bots/FunLib/aba_skill.lua')
    local sWalk = src:match('function X%.GetAbilityList%b()(.-)\nend\n')
    assert(sWalk, 'X.GetAbilityList not found')
    assert(sWalk:find('sAbilityList%[6%] = name'), 'the fixed-index write must still be there')
    assert(sWalk:find('table.insert(sAbilityList, name)', 1, true),
        'and the appends that run after it')
end

tests['[hero] the walk really is index-shifting, not name-addressed'] = function()
    -- If the walk kept every ability at its slot index this whole axis would be
    -- empty, so the shifting itself is pinned rather than assumed.
    local J = rf.load(FRAME)
    local kept = J.Skill.GetAbilityList(make_zuus({}))
    assert(kept[4] == NIMBUS, 'with nothing dropped, slot 3 lands at index 4, got '
        .. tostring(kept[4]))
    assert(kept[5] == 'zuus_lightning_hands', 'and slot 4 lands at index 5, got '
        .. tostring(kept[5]))
    assert(kept[6] == 'zuus_thundergods_wrath', 'the ultimate takes the fixed index 6, got '
        .. tostring(kept[6]))
    for i = 1, 5 do
        assert(kept[i] ~= STATIC, STATIC .. ' must not be reachable at index ' .. i
            .. ' when the two grant abilities are kept')
    end
end

-- ---------------------------------------------------------------------------
-- 2. Source ratchets: where the correction may live, and that nothing bypasses it.

tests['[hero] the helper is gated, turbo-only, and ends on the shipped handle'] = function()
    local src = strip_comments(read_file(ZUUS))

    local sHelper = src:match('function X%.GetBoundAbility%b()(.-)\nend')
    assert(sHelper, 'X.GetBoundAbility is gone; every call site would be ungated')
    assert(sHelper:find("IsSoakCandidate( '" .. CAND_ID .. "' )", 1, true),
        'the correction must sit behind IsSoakCandidate(' .. CAND_ID .. ')')
    assert(sHelper:find('IsModeTurbo', 1, true),
        'and behind IsModeTurbo (turbo-only, AGENTS.md)')
    assert(sHelper:find('GetAbilityByName( sName )', 1, true),
        'armed, it must resolve the handle BY NAME')

    local sTail = sHelper:match('(return[^\n]*)%s*$')
    assert(sTail and sTail:find('hShipped', 1, true),
        'the helper must END on the caller\'s shipped handle -- that is what makes '
            .. 'gate-off equivalence structural; got ' .. tostring(sTail))

    -- Armed, a name the engine cannot resolve must fall back, not propagate a
    -- nil into a consumer that indexes it (the GH #162 house rule).
    assert(sHelper:find('hNamed ~= nil', 1, true),
        'the armed branch must check the resolved handle before returning it')
end

tests['[hero] every consumer of the two index-bound handles goes through the helper'] = function()
    local src = strip_comments(read_file(ZUUS))

    -- The declarations themselves are the only bare uses that may remain.
    local nBareD  = select(2, src:gsub('abilityD', '')) - select(2, src:gsub('X%.GetBoundAbility%( abilityD', ''))
    local nBareAS = select(2, src:gsub('abilityAS[^B]', '')) - select(2, src:gsub('X%.GetBoundAbility%( abilityAS', ''))
    assert(nBareD == 1, 'abilityD may appear outside the helper exactly once (its own '
        .. 'declaration), got ' .. nBareD)
    assert(nBareAS == 1, 'abilityAS may appear outside the helper exactly once (its own '
        .. 'declaration), got ' .. nBareAS)

    assert(src:find("X.GetBoundAbility( abilityD, 'zuus_cloud' )", 1, true),
        'X.ConsiderD and the dispatch line must both name zuus_cloud')
    assert(select(2, src:gsub("X%.GetBoundAbility%( abilityD, 'zuus_cloud' %)", '')) == 2,
        'both abilityD call sites (the consider and the queued order) must be routed; '
            .. 'routing only one would let the desire and the order disagree about which '
            .. 'ability they are talking about')
    assert(src:find("X.GetStaticFieldBonus( X.GetBoundAbility( abilityAS, 'zuus_static_field' ) )", 1, true),
        'the Static Field bonus must be taken off the routed handle')
end

tests['[hero] the ungated nil checks are present in both consumers'] = function()
    local src = strip_comments(read_file(ZUUS))

    local sBonus = src:match('function X%.GetStaticFieldBonus%b()(.-)\nend')
    assert(sBonus and sBonus:find('hAbility == nil', 1, true),
        'X.GetStaticFieldBonus must answer 0 for a nil handle before indexing it')
    assert(not sBonus:find('IsSoakCandidate', 1, true)
        or sBonus:find('hAbility == nil') < sBonus:find('IsSoakCandidate'),
        'the nil check must run BEFORE the gate -- it is the ungated half')

    local sD = src:match('function X%.ConsiderD%(%)(.-)\nend')
    assert(sD and sD:find('hCloud == nil', 1, true),
        'X.ConsiderD must bail on a nil handle before calling IsFullyCastable on it')
end

-- ---------------------------------------------------------------------------
-- 3. The helper's behaviour, on both legs.

tests['gate off: the shipped handle comes back untouched'] = function()
    local X = load_zuus(false, true)
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, STATIC) == hShipped,
        'gate off must be the shipped handle, by identity')
    assert(X.GetBoundAbility(hShipped, NIMBUS) == hShipped)
end

tests['gate on: the handle is resolved by name'] = function()
    local X = load_zuus(true, true)
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, STATIC):GetName() == STATIC,
        'armed, the Static Field handle must be the one named zuus_static_field')
    assert(X.GetBoundAbility(hShipped, NIMBUS):GetName() == NIMBUS,
        'armed, the Nimbus handle must be the one named zuus_cloud')
end

tests['gate on but NOT turbo: unchanged (turbo-only, AGENTS.md)'] = function()
    local X = load_zuus(true, false)
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, STATIC) == hShipped,
        'the correction is turbo-only')
end

tests['gate on, engine cannot resolve the name: falls back, never returns nil'] = function()
    local X, _, bot = load_zuus(true, true)
    bot.GetAbilityByName = function() return nil end
    local hShipped = api.MakeUnit{ GetName = 'shipped_handle' }
    assert(X.GetBoundAbility(hShipped, STATIC) == hShipped,
        'an unresolvable name must fall back to the shipped handle')
end

tests['the ungated nil check answers 0 rather than raising'] = function()
    local X = load_zuus(false, true)
    assert(X.GetStaticFieldBonus(nil) == 0,
        'a nil handle must cost the term, not the tick')
    local X2 = load_zuus(true, true)
    assert(X2.GetStaticFieldBonus(nil) == 0, 'armed too')
end

-- ---------------------------------------------------------------------------
-- 4. The interaction this candidate must not be cited without.

tests['[hero] zusstatic still reads its percentage off the handle it is HANDED'] = function()
    local src = strip_comments(read_file(ZUUS))
    local sBonus = src:match('function X%.GetStaticFieldBonus%b()(.-)\nend')
    assert(sBonus:find('hAbility:GetSpecialValueFloat', 1, true),
        'the armed zusstatic leg must still read the key off its parameter -- which is '
            .. 'why arming zusstatic WITHOUT zusbind measures the wrong ability\'s missing '
            .. 'key, i.e. 0 (registered in iterations/state.json:zusbind_20260826)')

    -- The dependency is deliberately NOT coded as a conjunction of two ids:
    -- AGENTS.md records that `IsSoakCandidate('X') and IsSoakCandidate('Y')`
    -- freezes FALSE the day Y is promoted.  Pin that it stayed out.
    assert(not sBonus:find("IsSoakCandidate( 'zusbind' )", 1, true),
        'zusbind must not appear inside the zusstatic gate -- see the promote trap in '
            .. 'AGENTS.md; the dependency is registered for the director, not coded')
end

-- ---------------------------------------------------------------------------
-- 5. The limit that bounds every claim above.

tests['LIMIT: the fixture corpus cannot supply slot order'] = function()
    local J, bot, _, fx = rf.load(FRAME)
    local tZuus
    for _, u in ipairs(fx.units) do
        if u.name == 'npc_dota_hero_zuus' then tZuus = u.abilities end
    end
    assert(tZuus ~= nil and #tZuus > 0, 'the frame must carry a Zeus ability array at all')

    local bHasStatic = false
    for _, a in ipairs(tZuus) do
        if a.name == STATIC then bHasStatic = true end
    end
    assert(not bHasStatic, 'the innate is absent from the dumped array (GH #151 family) -- '
        .. 'if a future dumper starts carrying it, this file\'s worlds can be narrowed '
        .. 'with corpus evidence instead of enumerated')

    -- And the live consequence of that absence, which is why the fixture world
    -- cannot be used to decide the binding: the shipped walk over the REAL
    -- frame does not produce a Static Field entry anywhere.
    local list = J.Skill.GetAbilityList(bot)
    for i = 1, 6 do
        assert(list[i] ~= STATIC, 'no fixture-world index may carry ' .. STATIC)
    end
end

return tests

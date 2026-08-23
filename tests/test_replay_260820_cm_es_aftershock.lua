-- Replay-fixture regression for GH #66: the RECALL side of `cmrguard`.
--
-- The gate withholds Freezing Field while a visible enemy holds a READY hard CC
-- he can deliver -- "ready hard CC" being the curated name table
-- J.tHardCcAbilities. GH #66 measured what that table misses: over 12 mirror
-- games, 4 of CM's 11 channels were cut short inside 3 seconds and the gate
-- caught 1 of them; TWO of the three misses were ended by the same hero through
-- the same hole -- Earthshaker with AFTERSHOCK leveled, whose every cast stuns
-- everything in a 300 self-radius. The table carries earthshaker_fissure and
-- nothing else, so an ES whose fissure is on cooldown but who still holds
-- enchant_totem reads as harmless while being, in fact, a stun on legs.
--
-- Both real frames from GH #66 section 2 are pinned here, deliberately together,
-- because they say DIFFERENT things and only one of them is a fix:
--
--   A. tests/fixtures/f_260820_103216_cm_es_aftershock.lua -- t=473.5 of
--      spot_20260820_101145.../20260820_103216_slot1 (BASELINE side of the wave).
--      CM at 292/1110 (26%), already carrying a modifier_stunned with 0.2s to
--      run, ES at 195.9u with fissure on a 14.7s cooldown but enchant_totem
--      ready and aftershock at level 4, Zeus at 268u. She opened the channel at
--      474.3, was stunned again at 474.4 and was dead at 474.5: the fixture's
--      own ground truth is died_after = 1.0. THIS frame is what the entry fixes.
--
--   B. tests/fixtures/f_260820_102645_cm_es_reach.lua -- t=391.5 of
--      .../20260820_102645_slot1 (ARMED side). Same hole, same hero, same two
--      ready abilities -- but ES stands at 536.1u, and enchant_totem is
--      no-target, so the veto ring is 0 + X.nRGuardCloseBuffer = 400. THIS frame
--      is NOT fixed by the table entry and the tests below assert that it still
--      releases. GH #66 section 2 calls both misses "the same root cause"; on
--      the real geometry only one of them is. The other belongs to the RING
--      SHAPE, which is GH #63's open redesign (a flat `cast_range + const` both
--      overshoots ranged CC and undershoots self-radius CC against a 10s
--      channel) -- explicitly out of scope here: one lever per change.
--
-- EXTERNAL ANCHORS (numbers that are not in the dump -- make_fixture.py extracts
-- no ability specs, the same caveat every gate test in this directory carries):
--   * earthshaker_enchant_totem cast range: 0. It is a no-target ability; the
--     only thing in the game that gives it a cast range is an Aghanim's Scepter,
--     and the tests ASSERT that neither ES carries one rather than assuming it.
--     The mock's own Get* default is 0, so this anchor is also what the fixture
--     world produces on its own; a case below pins the alternative (300, the
--     aftershock radius as a generous upper bound) so the reader can see exactly
--     which conclusion depends on the anchor and how.
--   * crystal_maiden_freezing_field: mana cost 200 at level 1, AoE radius 835.
--     Both are load bearing for the end-to-end cases -- at the mock default of 0
--     the radius makes J.GetNearbyHeroes return nobody and every bid would be an
--     empty green.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local CLOSE = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua' -- must BLOCK armed
local REACH = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'      -- must RELEASE (known miss)

local ES = 'npc_dota_hero_earthshaker'
local TOTEM_CAST_RANGE   = 0      -- external anchor, see header
local AFTERSHOCK_RADIUS  = 300    -- external anchor, used only as an upper bound
local FIELD_RADIUS       = 835    -- external anchor
local FIELD_MANA_COST    = 200    -- external anchor (level 1)

--- Load a frame with an explicit set of armed candidate ids.
local function load_armed(path, tIds)
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id)
        for _, s in ipairs(tIds) do if s == id then return true end end
        return false
    end
    return J, bot, heroes, fx
end

local function totem(heroes)
    return heroes[ES]:GetAbilityByName('earthshaker_enchant_totem')
end

--- Place `unit` at `dist` units from `bot`, keeping the frame's real bearing.
local function move_to(bot, unit, dist)
    local b, u = bot:GetLocation(), unit:GetLocation()
    local dx, dy = u.x - b.x, u.y - b.y
    local d = math.sqrt(dx * dx + dy * dy)
    rawget(unit, '__spec').GetLocation = Vector(b.x + dx / d * dist, b.y + dy / d * dist, 0)
end

--- Drive the REAL X.ConsiderR() on a frame, with the ultimate's two specs
--- anchored. Returns the desire it bids plus the loaded world.
local function bid_considerR(path, tIds, fTweak)
    local J, bot, heroes, fx = load_armed(path, tIds)
    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == 'crystal_maiden_freezing_field',
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    local spec = rawget(abilityR, '__spec')
    spec.GetAOERadius = FIELD_RADIUS
    spec.GetManaCost = FIELD_MANA_COST
    assert(abilityR:IsFullyCastable(),
        'R is trained, off cooldown and affordable on this real frame')
    if fTweak then fTweak(J, bot, heroes) end
    local X = rf.load_hero('crystal_maiden')
    return X.ConsiderR(), J, bot, heroes, fx
end

local tests = {}

-- ------------------------------------------------------------- ground truth

tests['frame A ground truth: 26%-hp CM, ES at 195.9u with fissure DOWN but totem up'] = function()
    local J, bot, heroes, fx = load_armed(CLOSE, {})
    assert(fx.self == 'npc_dota_hero_crystal_maiden')
    assert(fx.time == 473.5, 'the last snapshot strictly before the 474.3 cast')
    assert(bot:GetHealth() == 292 and bot:GetMaxHealth() == 1110, 'CM hp on the real frame')

    local es = heroes[ES]
    assert(math.floor(GetUnitToUnitDistance(bot, es)) == 195, 'ES distance')
    -- The hole itself: the ONE ES ability in the curated table is unavailable,
    -- and the two that make him a stun on legs are both up.
    local fissure = es:GetAbilityByName('earthshaker_fissure')
    assert(fissure:GetLevel() == 2 and fissure:GetCooldownTimeRemaining() == 14.7,
        'the curated entry is on a 14.7s cooldown -- the shipped scan finds nothing')
    assert(totem(heroes):GetLevel() == 1 and totem(heroes):IsFullyCastable(),
        'enchant_totem is trained, off cooldown and affordable')
    assert(es:GetAbilityByName('earthshaker_aftershock'):GetLevel() == 4,
        'aftershock is what turns that cast into a stun')

    -- She had ALREADY been stunned by him 1.1s earlier and was still in it.
    assert(bot:HasModifier('modifier_stunned'), 'CM is mid-stun on the decision frame')
    -- ...and the channel she opened next lasted 0.2s.
    assert(fx.observed.died_after == 1.0, 'CM died 1.0s after this frame (ground truth)')
end

tests['frame A ground truth: the veto can only be attributed to Earthshaker'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'esaftershock' })
    -- Zeus is CLOSER to the ring than most, and he holds a ready ultimate --
    -- but nothing of his is in either table, so he can never be the vetoer.
    local zuus = heroes['npc_dota_hero_zuus']
    assert(math.floor(GetUnitToUnitDistance(bot, zuus)) == 268, 'Zeus distance')
    assert(J.GetReadyHardCc(zuus) == nil, 'no Zeus ability is curated hard CC')
    -- The gate only scans 1600 units, so "attributable" means: inside that ring
    -- ES is the only ready-hard-CC holder. (Jakiro IS one on this frame -- his
    -- ice_path is up -- and he is ~9200 units away, which is precisely why the
    -- census has to be taken over the ring rather than over the roster.)
    local nScanned = 0
    for _, h in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)) do
        nScanned = nScanned + 1
        if h:GetUnitName() ~= ES then
            assert(J.GetReadyHardCc(h) == nil,
                h:GetUnitName() .. ' must hold no ready hard CC, or the veto is not attributable')
        end
    end
    assert(nScanned == 2, 'ES and Zeus are the two enemies inside the scan')
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_jakiro']) > 1600
        and J.GetReadyHardCc(heroes['npc_dota_hero_jakiro']) ~= nil,
        'Jakiro holds a ready curated CC but is outside the scan -- stated so the '
        .. 'census above cannot silently become vacuous')
end

tests['frame B ground truth: same hole, same hero, 536.1u away -- and she lived'] = function()
    local J, bot, heroes, fx = load_armed(REACH, {})
    assert(fx.time == 391.5, 'the last snapshot strictly before the 391.6 cast')
    local es = heroes[ES]
    assert(math.floor(GetUnitToUnitDistance(bot, es) * 10) == 5361, 'ES distance 536.1')
    assert(es:GetAbilityByName('earthshaker_fissure'):GetCooldownTimeRemaining() == 1.6,
        'fissure is 1.6s from ready -- again NOT what stunned her')
    assert(totem(heroes):IsFullyCastable() and
        es:GetAbilityByName('earthshaker_aftershock'):GetLevel() == 4,
        'the same enchant_totem + aftershock pair is up')
    -- The cost of this miss was the ULTIMATE, not the life: the channel was cut
    -- at 1.2s and she went on living for another 106.9 seconds. Stating it here
    -- keeps the "known miss" case below from reading as a near-death.
    assert(fx.observed.died_after == 106.9, 'CM survived this one (ground truth)')
end

-- ----------------------------------------------------- the defect, then the fix

tests['frame A, gate OFF: shipped allows the channel -- the defect, stated positively'] = function()
    local _, bot = load_armed(CLOSE, {})
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'off every candidate nothing may change')
end

tests['frame A, `cmrguard` armed ALONE: still allows -- GH #66 reproduced'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard' })
    assert(J.GetReadyHardCc(heroes[ES]) == nil,
        'the shipped scan cannot see him: his only curated ability is on cooldown')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'this is the miss GH #66 measured -- the gate was live and let the channel through')
end

tests['frame A, `cmrguard` + `esaftershock`: withheld'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    local hCc = J.GetReadyHardCc(heroes[ES])
    assert(hCc ~= nil and hCc:GetName() == 'earthshaker_enchant_totem',
        'the extension returns the HANDLE, so the caller can still range-check it')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'an ES 195.9u away who stuns on every cast must withhold the 10s channel')
end

tests['frame A, `esaftershock` armed ALONE: the table grows, the decision does not'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'esaftershock' })
    assert(J.GetReadyHardCc(heroes[ES]) ~= nil, 'the extension is live at the helper')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'every consumer keeps its own gate: widening the table cannot act on its own')
end

tests['frame A, both armed but NOT turbo: unchanged'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    GetGameMode = function() return 1 end -- set after rf.load(): install() forces turbo
    assert(J.GetReadyHardCc(heroes[ES]) == nil, 'the extension is turbo-only at the helper too')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'normal mode is untouched')
end

-- ------------------------------------------- each clause of the entry, isolated

tests['frame A [MUTATED]: an ES who never leveled aftershock is not a vetoer'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    rawget(heroes[ES]:GetAbilityByName('earthshaker_aftershock'), '__spec').GetLevel = 0
    assert(J.GetReadyHardCc(heroes[ES]) == nil,
        'without the passive, enchant_totem is a self-buff and stuns nobody')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'the entry is a PAIR -- the spell is only hard CC because of the passive')
end

tests['frame A [MUTATED]: enchant_totem on cooldown releases the frame'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    rawget(totem(heroes), '__spec').GetCooldownTimeRemaining = 4.0
    assert(J.GetReadyHardCc(heroes[ES]) == nil, 'readiness is still required')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'a CC he cannot cast is not a threat')
end

tests['frame A [MUTATED]: an ES who cannot afford the cast is not a vetoer'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    assert(heroes[ES]:GetMana() == 534, 'his real mana on the frame')
    rawget(totem(heroes), '__spec').GetManaCost = 600 -- MUTATION: unaffordable
    assert(J.GetReadyHardCc(heroes[ES]) == nil,
        'affordability rides on IsFullyCastable, the clause GH #63 section 4 had to add to its own tool')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'and so the frame releases')
end

tests['cross-layer tripwire: the level clause is redundant TODAY, and only via IsFullyCastable'] = function()
    -- Honest accounting: seeding "drop `GetLevel() >= 1` from the candidate
    -- pass" is the one mutation this file does NOT catch, because
    -- IsFullyCastable already implies trained -- in the engine and in the mock
    -- (tests/mock/replay_fixture.lua derives it from level, cooldown and mana).
    -- The clause is kept anyway, to mirror the shipped scan one line above; this
    -- case asserts the property that makes it redundant, so if either layer ever
    -- stops providing it the redundancy is reported instead of assumed.
    local _, _, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    local spec = rawget(totem(heroes), '__spec')
    spec.GetLevel = 0
    assert(totem(heroes):IsFullyCastable() == false,
        'an untrained ability must not read as fully castable')
end

tests['the extension never overrides the shipped scan: fissure still wins when ready'] = function()
    local J, _, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    rawget(heroes[ES]:GetAbilityByName('earthshaker_fissure'), '__spec')
        .GetCooldownTimeRemaining = 0 -- MUTATION: give him the curated ability back
    local hCc = J.GetReadyHardCc(heroes[ES])
    assert(hCc ~= nil and hCc:GetName() == 'earthshaker_fissure',
        'the shipped table keeps priority -- arming this id can only ADD a handle '
        .. 'where the shipped scan found none, never swap one it already found')
end

-- ------------------------------------------ frame B: the miss this does NOT fix

tests['frame B, both armed: STILL released -- 536.1u is outside a self-radius ring'] = function()
    local J, bot, heroes = load_armed(REACH, { 'cmrguard', 'esaftershock' })
    assert(J.GetReadyHardCc(heroes[ES]) ~= nil, 'the extension DOES see him here')
    local X = rf.load_hero('crystal_maiden')
    assert(totem(heroes):GetCastRange() == TOTEM_CAST_RANGE,
        'no-target ability -> cast range 0 (anchor, and the fixture world agrees)')
    assert(GetUnitToUnitDistance(bot, heroes[ES]) > TOTEM_CAST_RANGE + X.nRGuardCloseBuffer,
        'so the veto ring is 400 units and he stands at 536.1')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'the curated-table entry does NOT close this miss: the binding constraint '
        .. 'is the ring SHAPE, which is GH #63 open work, not the table')
end

tests['frame B: the ring is what binds -- pinned one unit either side of 400'] = function()
    local X = rf.load_hero('crystal_maiden')
    assert(X.nRGuardCloseBuffer == 400, 'the buffer this conclusion is measured against')

    local J, bot, heroes = load_armed(REACH, { 'cmrguard', 'esaftershock' })
    move_to(bot, heroes[ES], 400) -- MUTATION of the real frame: same bearing, on the ring
    assert(rf.load_hero('crystal_maiden').cm_IsRSafeToOpen(bot) == false,
        'ON the ring the entry withholds')
    assert(J.GetReadyHardCc(heroes[ES]) ~= nil, 'and he is still the same vetoer')

    local _, bot2, heroes2 = load_armed(REACH, { 'cmrguard', 'esaftershock' })
    move_to(bot2, heroes2[ES], 401) -- MUTATION: one unit outside
    assert(rf.load_hero('crystal_maiden').cm_IsRSafeToOpen(bot2) == true,
        'one unit outside it releases -- the release is caused by DISTANCE, not '
        .. 'by the ability dropping out of the extended table')
end

tests['the 0-cast-range anchor is safe on both frames: neither ES owns a Scepter'] = function()
    -- An Aghanim's Scepter is the only thing in the game that gives
    -- enchant_totem a cast range, so this is the assumption the anchor rests on.
    for _, sPath in ipairs({ CLOSE, REACH }) do
        local _, _, h = load_armed(sPath, {})
        for _, sItem in ipairs({ 'item_ultimate_scepter', 'item_aghanims_shard' }) do
            assert(h[ES]:FindItemSlot(sItem) == -1, sPath .. ': ES carries no ' .. sItem)
        end
    end
end

tests['frame B [ANCHOR sensitivity]: at a 300 cast range the same frame would veto'] = function()
    -- This case exists so the dependency is visible rather than implicit: were
    -- the engine to report the aftershock radius instead of 0, frame B would
    -- flip from a known miss into a catch.
    local _, bot, heroes = load_armed(REACH, { 'cmrguard', 'esaftershock' })
    rawget(totem(heroes), '__spec').GetCastRange = AFTERSHOCK_RADIUS -- MUTATION
    assert(rf.load_hero('crystal_maiden').cm_IsRSafeToOpen(bot) == false,
        '536.1 <= 300 + 400 -- the frame-B conclusion is anchor-dependent, by exactly this much')
end

-- ------------------------------------------------------------------ end to end
-- Rule 0b (test_set.md): assert the decision the world actually gets, not a
-- helper's return value. Frame A needs NO mutation to reach the guard's effect:
-- two enemies (ES 195.9u, Zeus 268.0u) stand inside the field on the real frame,
-- which is exactly why the shipped bid is HIGH there.

tests['end-to-end: `cmrguard` alone still bids the channel she died in'] = function()
    local nBid, J, bot, heroes = bid_considerR(CLOSE, { 'cmrguard' })
    assert(J.GetReadyHardCc(heroes[ES]) == nil, 'the gate sees no threat')
    assert(nBid == BOT_ACTION_DESIRE_HIGH,
        'the miss reaches CM\'s real bid: armed, she still commits the 10s channel '
        .. 'at 26% hp with two enemies on top of her, and the ground truth is that '
        .. 'she was dead 1.0s later')
end

tests['end-to-end: with `esaftershock` the bid becomes NONE'] = function()
    local nBid = bid_considerR(CLOSE, { 'cmrguard', 'esaftershock' })
    assert(nBid == BOT_ACTION_DESIRE_NONE,
        'the guard must reach the final decision -- if this still bids, the entry is decorative')
end

tests['end-to-end: outside turbo the bid is unchanged'] = function()
    local nBid = bid_considerR(CLOSE, { 'cmrguard', 'esaftershock' },
        function() GetGameMode = function() return 1 end end)
    assert(nBid == BOT_ACTION_DESIRE_HIGH, 'normal mode keeps the shipped decision')
end

tests['end-to-end: frame B is ability-for-ability identical armed vs shipped'] = function()
    local nArmed, J, bot, heroes = bid_considerR(REACH, { 'cmrguard', 'esaftershock' })
    local nShipped = bid_considerR(REACH, {})
    -- Both are NONE, and NOT because the guard held: it released (case above).
    -- Asserting the actual reason keeps this from being an empty green.
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'the guard released this frame')
    local tInField = J.GetNearbyHeroes(bot, FIELD_RADIUS * 0.88, true, BOT_MODE_NONE)
    assert(#tInField == 2, 'only two enemies stand inside the field (ES and Bristleback)')
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_bristleback']) > 500,
        'and both are far enough out that the aoeCanHurt clause counts neither')
    assert(nShipped == BOT_ACTION_DESIRE_NONE and nArmed == nShipped,
        'so ConsiderR bids NONE here for its own reasons, armed or not')
end

-- ----------------------------------------------------------- source tripwires

local function jmz_source()
    local f = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

tests['tripwire: the entry stays OUT of the shipped table'] = function()
    local src = jmz_source()
    local shipped = src:match('J%.tHardCcAbilities = {(.-)}')
    assert(shipped ~= nil, 'the shipped curated table must still be a literal')
    assert(shipped:find('earthshaker_enchant_totem', 1, true) == nil,
        'moving the entry into the SHIPPED table would ungate it -- it has not '
        .. 'cleared condition (b); it belongs in J.tHardCcAbilitiesCandidate')
    assert(shipped:find('earthshaker_fissure', 1, true) ~= nil,
        'the shipped entry this one sits next to must still be there')
end

tests['tripwire: the candidate table is the pair (spell -> required passive)'] = function()
    local J = load_armed(CLOSE, {})
    local tCand = J.tHardCcAbilitiesCandidate
    assert(type(tCand) == 'table', 'the extension table must exist')
    local nEntries = 0
    for _ in pairs(tCand) do nEntries = nEntries + 1 end
    assert(nEntries == 1, 'one entry today; adding a second is a new lever, not a tweak')
    assert(tCand['earthshaker_enchant_totem'] == 'earthshaker_aftershock',
        'the VALUE is the passive that makes the spell a stun -- a boolean here '
        .. 'would fire for an ES who never leveled aftershock')
end

tests['tripwire: one gate call, one id, and the ccburst consumer keeps its own'] = function()
    local src = jmz_source()
    local nIds = select(2, src:gsub("IsSoakCandidate%( 'esaftershock' %)", ''))
    assert(nIds == 1, "exactly one 'esaftershock' gate call in jmz_func; found " .. nIds)
    assert(src:find("if not J.IsModeTurbo() or not J.IsSoakCandidate( 'esaftershock' ) then", 1, true),
        'the extension pass must be turbo-only and behind its own id')
    -- Blast radius: J.GetReadyHardCc has a SECOND consumer (ShouldRetreatLaneBurst).
    -- It must stay behind its own `bCcAware` candidate, so arming this id cannot
    -- move the lane-retreat rule while `ccburst` is unarmed.
    assert(src:find('if bCcAware then\n\t\t\t\tlocal hCc = J.GetReadyHardCc( hEnemy )', 1, true),
        'the ccburst consumption point must stay inside its own gate')
end

-- ---------------------------------------------------------------------------
-- RE-READ of frame B under the real drafted roles (strategy backlog 0c, GH #57).
--
-- Every case above that touches REACH was written while the fixture carried no
-- `roles` table, so Role.GetPosition fell through to RoleAssignment[team][slot]
-- -- the draft SLOT, which GH #57 measured against the real draft at 47.3%.
-- The game is attributable (script_version = mirror:...:s906:radiant), so the
-- fixture has been regenerated with `--roles`. The regeneration is byte-for-byte
-- identical apart from the added table: same positions, HP, mana, items,
-- abilities, modifiers, recent_damage and the whole `observed` block (burst 99
-- from Earthshaker, died_after = 106.9), and the generator raised no
-- ground_truth_ambiguous / recent_damage_ambiguous flag (GH #69).
--
-- What moved: three of the five allies read a different position, and unlike
-- the axe frame (seed 885, where all five moved and the core/support partition
-- held) THIS frame's partition FLIPS TWICE -- sniper from core to support and
-- viper from support to core. Nothing above forks on either, because neither
-- the guard nor the bid asks for a position at all; the cases below measure
-- that rather than assuming it, because "24 cases still pass" says nothing
-- without a reason why they could not have moved.
--
-- The one role read on the whole path is the same call site the axe re-read
-- found -- Item.GetRoleItemsBuyList, at hero-file load -- and here it does NOT
-- move, because Crystal Maiden is a fixed point of this frame's permutation
-- (slot 5 = drafted 5). That makes this frame the control for that finding, and
-- the last case shows the mechanism is live anyway by moving her.
-- ---------------------------------------------------------------------------

--- Count every position read, through BOTH entry points: J.GetPosition (the
--- jmz wrapper) and Role.GetPosition (the module, which aba_item reaches
--- directly). They are NOT the same function object, so hooking one undercounts.
local function counting_roles(J, fBody)
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')
    assert(J.GetPosition ~= Role.GetPosition,
        'the two role entry points must be distinct functions -- hooking only '
        .. 'one of them undercounts, which is how the aba_item call site hides')
    local tLog = {}
    local realJ, realR = J.GetPosition, Role.GetPosition
    J.GetPosition = function(u) tLog[#tLog + 1] = 'J:' .. u:GetUnitName() return realJ(u) end
    Role.GetPosition = function(u) tLog[#tLog + 1] = 'R:' .. u:GetUnitName() return realR(u) end
    local ok, err = pcall(fBody)
    J.GetPosition, Role.GetPosition = realJ, realR
    assert(ok, err)
    return tLog
end

tests['RE-READ: frame B carries the drafted roles, and the partition FLIPS TWICE'] = function()
    local J, bot, _, fx = load_armed(REACH, {})
    assert(fx.roles ~= nil, 'the fixture must carry the drafted roles -- without '
        .. 'them every position on this frame is the draft slot (GH #57)')

    -- slot (what the fixture answered before the heal) -> drafted (now).
    local WAS_AND_IS = {
        [1] = { 'npc_dota_hero_phantom_assassin', 1 },
        [2] = { 'npc_dota_hero_skeleton_king',    3 },
        [3] = { 'npc_dota_hero_sniper',           4 },
        [4] = { 'npc_dota_hero_viper',            2 },
        [5] = { 'npc_dota_hero_crystal_maiden',   5 },
    }
    local nMoved, nFlipped = 0, 0
    for nSlot, tWant in ipairs(WAS_AND_IS) do
        local h = GetTeamMember(nSlot)
        assert(h:GetUnitName() == tWant[1], 'roster slot ' .. nSlot .. ' is '
            .. h:GetUnitName() .. ', this frame was recorded with ' .. tWant[1])
        assert(J.GetPosition(h) == tWant[2], tWant[1] .. ' reads position '
            .. tostring(J.GetPosition(h)) .. ', drafted ' .. tWant[2]
            .. ' -- a slot-order answer here means the fixture lost its roles')
        if tWant[2] ~= nSlot then nMoved = nMoved + 1 end
        if (nSlot <= 3) ~= J.IsCore(h) then nFlipped = nFlipped + 1 end
    end
    assert(nMoved == 3, 'three of five allies must move; got ' .. nMoved)
    assert(nFlipped == 2, 'the core/support partition must flip for exactly two '
        .. 'allies (sniper core->support, viper support->core); got ' .. nFlipped
        .. ' -- the axe frame flipped NONE, which is why "the partition is '
        .. 'usually stable" is never a reason to skip a frame')

    assert(J.GetPosition(bot) == 5 and J.IsCore(bot) == false,
        'the subject is a fixed point of the permutation: slot 5, drafted 5')
end

tests['RE-READ: neither the guard nor the bid asks for a role -- WHY the pins held'] = function()
    -- Load the hero file BEFORE hooking, so this counts the decision only.
    local J, bot, heroes = load_armed(REACH, { 'cmrguard', 'esaftershock' })
    local X = rf.load_hero('crystal_maiden')

    local tGuard = counting_roles(J, function()
        assert(X.cm_IsRSafeToOpen(bot) == true, 'the decision under test is still "release"')
    end)
    assert(#tGuard == 0, 'cm_IsRSafeToOpen asked for a position '
        .. table.concat(tGuard, ', ') .. ' -- it must ask ZERO times. If this '
        .. 'ever becomes non-zero, every case on this frame has to be re-read, '
        .. 'because two of the five allied core/support answers flipped')

    local spec = rawget(bot:GetAbilityByName(J.Skill.GetAbilityList(bot)[6]), '__spec')
    spec.GetAOERadius, spec.GetManaCost = FIELD_RADIUS, FIELD_MANA_COST
    local tBid = counting_roles(J, function()
        assert(X.ConsiderR() == BOT_ACTION_DESIRE_NONE, 'and the bid is unchanged')
    end)
    assert(#tBid == 0, 'ConsiderR asked for a position ' .. table.concat(tBid, ', ')
        .. ' -- the end-to-end cases are only role-independent if this is zero')

    assert(J.GetReadyHardCc(heroes[ES]) ~= nil,
        'stated so the two zeroes above cannot be a vacuous "nothing ran": the '
        .. 'extension really is seeing Earthshaker on this frame')
end

tests['RE-READ: the one role read is the build-list key, and CM sits on a fixed point'] = function()
    local J, bot = load_armed(REACH, {})
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')

    -- The read happens at hero-file LOAD, not in any decision: hero_crystal_
    -- maiden.lua asks Item.GetRoleItemsBuyList for its build the moment it is
    -- dofile'd, and that call site (aba_item.lua) is the only one in the repo
    -- that bypasses the J wrapper.
    local tLoad = counting_roles(J, function() rf.load_hero('crystal_maiden') end)
    assert(#tLoad == 1 and tLoad[1] == 'R:npc_dota_hero_crystal_maiden',
        'expected exactly one role read at hero load, on the subject, through '
        .. 'the MODULE; got { ' .. table.concat(tLoad, ', ') .. ' }')

    -- It does not move here, and the reason is arithmetic, not luck.
    assert(Role.GetPosition(bot) == 5, 'drafted pos 5')
    assert(GetTeamMember(5) == bot, 'and roster slot 5, so the pre-heal world '
        .. 'keyed the same list -- this frame is the CONTROL for the axe '
        .. 'finding, where slot 2 vs drafted 3 changed the whole build')

    -- The mechanism is live all the same: move her the way the permutation
    -- moved three of her team-mates and the build changes outright.
    local function buy_list_at(nPos)
        local J2, bot2 = load_armed(REACH, {})
        local Role2 = require(GetScriptDirectory() .. '/FunLib/aba_role')
        local real = Role2.GetPosition
        Role2.GetPosition = function(u) if u == bot2 then return nPos end return real(u) end
        local ok, X = pcall(dofile, GetScriptDirectory() .. '/BotLib/hero_crystal_maiden.lua')
        Role2.GetPosition = real
        assert(ok and type(X) == 'table' and X.sBuyList ~= nil,
            'hero_crystal_maiden must publish an sBuyList for pos ' .. nPos)
        return J2, X.sBuyList
    end

    local _, tPos5 = buy_list_at(5)
    local _, tPos1 = buy_list_at(1)
    local _, tPos4 = buy_list_at(4)
    -- These read the SHIPPED pos_5 list.  2026-08-23's arcane-boots swap is a
    -- soak candidate again ('cmboots', GH #144) and gate-off restores this list
    -- byte-for-byte, so entry 5 is Boots of Bearing here.  If 'cmboots' is ever
    -- promoted, entry 5 becomes item_pipe and the pin below moves to tPos5[2].
    assert(tPos5[1] == 'item_blood_grenade' and tPos5[5] == 'item_boots_of_bearing',
        'the pos_5 list this frame really runs')
    assert(tPos1[1] == 'item_mage_outfit' and tPos1[3] == 'item_veil_of_discord',
        'a pos_1 CM buys a different opener entirely')
    assert(#tPos4 == 11 and tPos4[1] == 'item_priest_outfit',
        'and pos_4 is a third list, of a different length -- so a one-step slip '
        .. 'in the position is a whole build, not a reordering')
end

-- ---------------------------------------------------------------------------
-- RE-READ of frame A under the real drafted roles (strategy backlog 0c, GH #57).
--
-- Frame B was healed on 2026-08-21T07:40Z; frame A -- the one this file exists
-- for -- was still slot-derived until now, which is why the two halves of the
-- same pair were deliberately done in separate rounds (one fixture per round,
-- re-read each time; healing a frame may FLIP what it pins).
--
-- The regeneration is byte-for-byte identical apart from the added `roles`
-- table: same positions, HP, mana, items, abilities, modifiers, recent_damage
-- and the whole `observed` block (burst zuus 152 / earthshaker 98, died_after
-- = 1.0), and the generator raised no ground_truth_ambiguous /
-- recent_damage_ambiguous flag (GH #69). The game is attributable --
-- script_version = mirror:...:s906:dire -- i.e. the SAME seed as frame B from
-- the other side of the mirror, so the draft is the same ten heroes and only
-- the slot assignment differs.
--
-- What moved: ALL FIVE allies read a different position (frame B moved three),
-- and the core/support partition flips TWICE again -- but not for the same two
-- heroes: here it is sniper core->support and skeleton_king support->core,
-- where frame B flipped sniper and viper. Same seed, same draft, different
-- slots, different flips: "the partition is usually stable" remains a
-- per-frame measurement and never a reason to skip a frame.
--
-- What did NOT move: any of the 51 cases across this file and
-- test_replay_260820_cm_r_selfstate.lua, because neither cm_IsRSafeToOpen nor
-- ConsiderR asks for a position at all. That is measured below, not assumed.
--
-- The margin, and the point of this round: on frame B Crystal Maiden was a
-- FIXED POINT of the permutation (slot 5 = drafted 5), so the one role read on
-- the whole path -- Item.GetRoleItemsBuyList, at hero-file load -- happened not
-- to move, and that frame was recorded as the CONTROL. Frame A is the
-- EXPERIMENT: slot 4, drafted 5, so the pre-heal world keyed her onto the
-- pos_4 build. The frame's own inventory falsifies that world outright (she is
-- carrying every basic of the pos_5 opener and neither discriminator of the
-- pos_4 one), which is the same finding the axe re-read reached by item
-- ORDERING -- here the corpus states it directly.
-- ---------------------------------------------------------------------------

tests['RE-READ: frame A moves all five allies and flips a DIFFERENT two'] = function()
    local J, bot, _, fx = load_armed(CLOSE, {})
    assert(fx.roles ~= nil, 'the fixture must carry the drafted roles -- without '
        .. 'them every position on this frame is the draft slot (GH #57)')

    -- slot (what the fixture answered before the heal) -> drafted (now).
    local WAS_AND_IS = {
        [1] = { 'npc_dota_hero_viper',            2 },
        [2] = { 'npc_dota_hero_phantom_assassin', 1 },
        [3] = { 'npc_dota_hero_sniper',           4 },
        [4] = { 'npc_dota_hero_crystal_maiden',   5 },
        [5] = { 'npc_dota_hero_skeleton_king',    3 },
    }
    local nMoved, tFlipped = 0, {}
    for nSlot, tWant in ipairs(WAS_AND_IS) do
        local h = GetTeamMember(nSlot)
        assert(h:GetUnitName() == tWant[1], 'roster slot ' .. nSlot .. ' is '
            .. h:GetUnitName() .. ', this frame was recorded with ' .. tWant[1])
        assert(J.GetPosition(h) == tWant[2], tWant[1] .. ' reads position '
            .. tostring(J.GetPosition(h)) .. ', drafted ' .. tWant[2]
            .. ' -- a slot-order answer here means the fixture lost its roles')
        if tWant[2] ~= nSlot then nMoved = nMoved + 1 end
        if (nSlot <= 3) ~= J.IsCore(h) then tFlipped[#tFlipped + 1] = tWant[1] end
    end
    assert(nMoved == 5, 'all five allies must move on this frame; got ' .. nMoved)
    assert(#tFlipped == 2, 'exactly two core/support answers must flip; got '
        .. #tFlipped .. ' { ' .. table.concat(tFlipped, ', ') .. ' }')
    assert(tFlipped[1] == 'npc_dota_hero_sniper'
        and tFlipped[2] == 'npc_dota_hero_skeleton_king',
        'the flips are sniper core->support and skeleton_king support->core; '
        .. 'got { ' .. table.concat(tFlipped, ', ') .. ' }. Frame B is the SAME '
        .. 'seed and flipped sniper and VIPER -- if these two ever agree, one '
        .. 'of the fixtures is answering slots again')

    -- The subject is NOT a fixed point here, which is the whole difference
    -- from frame B and is what the build-list case below turns on.
    assert(J.GetPosition(bot) == 5 and GetTeamMember(4) == bot,
        'CM is roster slot 4 and drafted pos 5 on frame A')
    assert(J.IsCore(bot) == false, 'she is a support in both worlds -- only the '
        .. 'number moves for her, and the number is enough')
end

tests['RE-READ: the enemy half of the heal is inert, by construction'] = function()
    -- World assertion 12 (GH #81): --roles structurally cannot reach the enemy
    -- team. aba_role.GetPosition's enemy branch throws the drafted value away
    -- and returns 3 unless enemy_role_estimation has been warmed, which the
    -- loader never does. Stated as a case so nobody reads the new `roles`
    -- table and concludes that enemy-position forks became readable here.
    local J, _, heroes, fx = load_armed(CLOSE, {})
    local DRAFTED = {
        ['npc_dota_hero_juggernaut']  = 1,
        ['npc_dota_hero_zuus']        = 2,
        ['npc_dota_hero_bristleback'] = 3,
        ['npc_dota_hero_earthshaker'] = 4,
        ['npc_dota_hero_jakiro']      = 5,
    }
    local nDisagree = 0
    for sName, nPos in pairs(DRAFTED) do
        assert(fx.roles[sName] == nPos, sName .. ' is drafted pos ' .. nPos
            .. ' in the fixture, got ' .. tostring(fx.roles[sName]))
        assert(J.GetPosition(heroes[sName]) == 3, sName .. ' must read 3 through '
            .. 'the role chain (GH #81), got ' .. tostring(J.GetPosition(heroes[sName])))
        assert(J.IsCore(heroes[sName]) == true, 'and therefore IsCore')
        if nPos ~= 3 then nDisagree = nDisagree + 1 end
    end
    assert(nDisagree == 4, 'four of the five enemies are drafted to something '
        .. 'other than 3, so the constant answer really is discarding data; got '
        .. nDisagree .. ' -- if this reaches 0 the case has gone vacuous')
end

tests['RE-READ: frame A\'s guard and bid ask for no role either -- WHY the pins held'] = function()
    -- Load the hero file BEFORE hooking, so this counts the decision only.
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard', 'esaftershock' })
    local X = rf.load_hero('crystal_maiden')

    local tGuard = counting_roles(J, function()
        assert(X.cm_IsRSafeToOpen(bot) == false,
            'the decision under test is still "block" on frame A')
    end)
    assert(#tGuard == 0, 'cm_IsRSafeToOpen asked for a position '
        .. table.concat(tGuard, ', ') .. ' -- it must ask ZERO times. If this '
        .. 'ever becomes non-zero, every case on this frame has to be re-read, '
        .. 'because two of the five allied core/support answers flipped')

    local spec = rawget(bot:GetAbilityByName(J.Skill.GetAbilityList(bot)[6]), '__spec')
    spec.GetAOERadius, spec.GetManaCost = FIELD_RADIUS, FIELD_MANA_COST
    local tBid = counting_roles(J, function()
        assert(X.ConsiderR() == BOT_ACTION_DESIRE_NONE, 'and the bid is unchanged')
    end)
    assert(#tBid == 0, 'ConsiderR asked for a position ' .. table.concat(tBid, ', ')
        .. ' -- the end-to-end cases are only role-independent if this is zero')

    assert(J.GetReadyHardCc(heroes[ES]) ~= nil,
        'stated so the two zeroes above cannot be a vacuous "nothing ran": the '
        .. 'extension really is seeing Earthshaker on this frame')
end

tests['RE-READ: the one role read is the build-list key, and on frame A it MOVES'] = function()
    local J, bot, _, fx = load_armed(CLOSE, {})
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')

    -- Same single call site the frame-B and axe re-reads found: the read
    -- happens at hero-file LOAD, through the MODULE, bypassing the J wrapper.
    local tLoad = counting_roles(J, function() rf.load_hero('crystal_maiden') end)
    assert(#tLoad == 1 and tLoad[1] == 'R:npc_dota_hero_crystal_maiden',
        'expected exactly one role read at hero load, on the subject, through '
        .. 'the MODULE; got { ' .. table.concat(tLoad, ', ') .. ' }')

    -- ...and unlike frame B, it lands somewhere else than it used to.
    assert(Role.GetPosition(bot) == 5 and J.Item.GetRoleItemsBuyList(bot) == 'pos_5',
        'the drafted role keys this CM onto pos_5; got '
        .. tostring(J.Item.GetRoleItemsBuyList(bot)))

    local function buy_list_at(nPos)
        local _, bot2 = load_armed(CLOSE, {})
        local Role2 = require(GetScriptDirectory() .. '/FunLib/aba_role')
        local real = Role2.GetPosition
        Role2.GetPosition = function(u) if u == bot2 then return nPos end return real(u) end
        local ok, X = pcall(dofile, GetScriptDirectory() .. '/BotLib/hero_crystal_maiden.lua')
        Role2.GetPosition = real
        assert(ok and type(X) == 'table' and X.sBuyList ~= nil,
            'hero_crystal_maiden must publish an sBuyList for pos ' .. nPos)
        return X.sBuyList
    end

    local tDrafted, tSlot = buy_list_at(5), buy_list_at(4)
    assert(#tDrafted == 13 and tDrafted[1] == 'item_blood_grenade',
        'pos_5 is a 13-entry list opening on a blood grenade; got ' .. #tDrafted
        .. ' / ' .. tostring(tDrafted[1]))
    assert(#tSlot == 11 and tSlot[1] == 'item_priest_outfit',
        'pos_4 is an 11-entry list opening on the priest outfit; got ' .. #tSlot
        .. ' / ' .. tostring(tSlot[1]))
    assert(tDrafted[2] == 'item_mage_outfit',
        'and the two openers are different outfits, not the same one renamed')
end

tests['RE-READ: the frame\'s own inventory falsifies the pre-heal build key'] = function()
    -- The strongest form of the axe finding. There the wrong build list was
    -- inferred from where item_blink sat in each list; here the corpus states
    -- it: the outfit bundles of pos_4 and pos_5 have no basic in common, and
    -- the real Crystal Maiden of this frame is carrying one of them.
    local _, bot, _, fx = load_armed(CLOSE, {})

    local tHeld = {}
    for _, u in ipairs(fx.units) do
        if u.name == fx.self then
            for _, s in ipairs(u.items or {}) do
                if s ~= '' then tHeld['item_' .. s] = true end
            end
        end
    end
    assert(tHeld['item_tranquil_boots'], 'sanity: the frame\'s own item list is '
        .. 'being read (she has tranquil boots at t=473.5)')

    -- item_mage_outfit   (pos_5, entry 2) = ... tranquil_boots, null_talisman,
    --                                       magic_wand, flask ...
    -- item_priest_outfit (pos_4, entry 1) = ... arcane_boots, urn_of_shadows,
    --                                       magic_wand, flask ...
    -- The shared basics (magic_wand, flask) decide nothing; the boots and the
    -- fourth slot decide everything.
    for _, s in ipairs({ 'item_tranquil_boots', 'item_null_talisman',
                         'item_magic_wand', 'item_flask' }) do
        assert(tHeld[s], 'she must be holding ' .. s .. ', a basic of the '
            .. 'pos_5 opener -- without it this case proves nothing')
    end
    for _, s in ipairs({ 'item_arcane_boots', 'item_urn_of_shadows' }) do
        assert(tHeld[s] == nil, 'she must NOT be holding ' .. s .. ': it is a '
            .. 'pos_4-only basic, and its absence is half the discriminator')
    end
    -- ...and the pos_5 list's very first entry, which pos_4 does not contain
    -- at any index, is in her backpack.
    assert(tHeld['item_blood_grenade'],
        'the pos_5 opener itself is in her inventory')
    local tSlotList = (function()
        local _, bot2 = load_armed(CLOSE, {})
        local Role2 = require(GetScriptDirectory() .. '/FunLib/aba_role')
        local real = Role2.GetPosition
        Role2.GetPosition = function(u) if u == bot2 then return 4 end return real(u) end
        local ok, X = pcall(dofile, GetScriptDirectory() .. '/BotLib/hero_crystal_maiden.lua')
        Role2.GetPosition = real
        assert(ok)
        return X.sBuyList
    end)()
    for _, s in ipairs(tSlotList) do
        assert(s ~= 'item_blood_grenade', 'the pos_4 list must not contain a '
            .. 'blood grenade anywhere, else the discriminator is not one')
    end

    assert(bot:GetHealth() == 292, 'and this is still the 26%-hp decision frame')
end

return tests

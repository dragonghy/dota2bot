-- Replay-fixture regression for GH #34: `cmrguard` (CM's Freezing Field
-- self-preservation gate) was RANGE-BLIND -- it asked the boolean wrapper
-- J.HasReadyHardCc and threw away the handle J.GetReadyHardCc deliberately
-- returns, so any enemy inside the 1600 scan holding a ready hard CC vetoed
-- the ultimate no matter whether he could deliver it.
--
-- The counterfactual replay of 14 mirror games (issue #34) reconstructed all 5
-- vetoes on real frames; this is the clean false positive:
--
--   game spot_20260819_001007_1_main/20260819_004858_slot1, t=423.4 (7:03).
--   CM 427/890 hp. The ONLY nearby enemy holding a ready curated hard CC is a
--   31%-hp Centaur at 1326 units whose hoof_stomp is a SELF-CENTERED 325-radius
--   AoE with no cast range -- and over the next 10s he walks monotonically away
--   (1326 -> 1459 -> 2043 -> 3077) and never casts it. Ogre Magi is closer
--   (346u) but his fireblast is 4s from ready, so he is not a vetoer.
--   Ground truth: CM opened Freezing Field here for real and lived another
--   44.1 seconds. The old gate would have eaten that ultimate for nothing.
--
-- The narrowed gate must release THIS frame while still catching the frame the
-- gate was opened for (Jakiro ice_path at 1139u, the other fixture below).
-- Both are pinned here together, deliberately: this is the `lanefix` lesson --
-- a narrowing that is locally right must not silently undo the original catch.
--
-- EXTERNAL ANCHORS -- ⭐ RE-READ 2026-09-04 (`-76`), AND THE ONE-SENTENCE
-- REASON BELOW IS NOW THREE DIFFERENT REASONS.
--
-- It used to read: "numbers that do NOT come from the dump -- make_fixture.py
-- extracts no ability specs, same caveat as wkreincarnmp's GetManaCost".  The
-- fixtures DO carry ability KV, and tests/mock/replay_fixture.lua has served it
-- since 2026-09-04.  The three anchors below are still anchors, but each for a
-- reason the others do not share, and the file must not be quoted as if one
-- sentence covered them:
--
--   * hoof_stomp / ice_path cast range -- centaur and jakiro are NON-FOCUS
--     heroes, and the loader refuses them BY DESIGN (a declared bound, not a
--     gap).  Both handles answer GetCastRange() == 0 with no spec installed.
--     These two anchors are load-bearing and will stay so until the loader's
--     focus-five restriction is lifted.
--   * Freezing Field AoE radius -- CM is a focus hero and her KV block IS
--     served, but GetAOERadius is not one of the seven getters the loader
--     specs (GetManaCost / GetSpecialValueInt / GetSpecialValueFloat /
--     GetCastRange / GetCastPoint / GetCooldown / GetAbilityDamage).  It
--     answers 0 through the generic bot_api `^Get` default.  Different reason,
--     same conclusion: still load-bearing.
--
-- ⚠️ AND ONE DISAGREEMENT, REGISTERED NOT RESOLVED.  On both fixtures the
-- served KV answers `GetSpecialValueInt('radius') == 810` for
-- crystal_maiden_freezing_field, while this file anchors 835 from Liquipedia.
-- Whether the AbilityValues key named `radius` is the same quantity the engine
-- returns from GetAOERadius is NOT established here, so 835 is left in place
-- and nothing is re-derived off 810; the section below pins both numbers so the
-- gap cannot close silently.  Filed for the key-to-getter mapping owner.
--
-- ⭐ RULED 2026-09-05 (hero, GH #502's last cell).  THE MAPPING QUESTION IS
-- ANSWERED, AND THE ANSWER IS NO -- SO THE NUMBER STAYS 835.  Measured by
-- `tools/agent/aoe_radius_source_census.py`, frozen by
-- `tests/test_aoe_radius_source_census.py`:
--
--   * NO NAME IDENTITY.  Every other served getter is served because the KV
--     carries a top-level field of its own name (`AbilityCastRange` ->
--     GetCastRange, and so on).  Across 127 shipped-hero KV files there are 31
--     distinct top-level `Ability*` fields and NOT ONE contains "aoe" or
--     "radius".  GetAOERadius has no KV field anywhere in the tree, so the rule
--     that serves the other six cannot be extended to it -- it is a C++-side
--     quantity, not a declared one.
--   * SO ANY MAPPING IS A HAND-WRITTEN GUESS, AND ON THE CALL SITES IT IS NOT A
--     FUNCTION.  Of the 7 shipped `GetAOERadius()` reads, exactly ONE
--     (sniper_shrapnel) has the two candidate rules -- "the key named `radius`",
--     "the key flagged affected_by_aoe_increase" -- agree on one key.  On
--     Freezing Field the name rule offers `radius` (810) while the flag rule
--     offers THREE (`radius` 810, `explosion_max_dist` 785, `explosion_radius`
--     320).  Picking 810 there is a choice, not a read.  And on two other call
--     sites (drow_ranger_wave_of_silence, muerta_the_calling) no key named
--     `radius` exists at all.
--   * ⛔ THEREFORE 810 MUST NOT SOURCE FIELD_RADIUS, and the loader must not
--     spec GetAOERadius off the KV: doing either replaces a number that has a
--     provenance (Liquipedia) with one that has none, and it would read as a
--     repair.  This is GH #502's path (b), taken with a reason, not its path
--     (a) -- and NOT the third thing #502 forbade, loosening the section into a
--     tolerance.
--   * ⭐ WHAT WOULD CLOSE IT is an ENGINE reading, and the engine is reachable:
--     `bots/FunLib/rubick_utility.lua:185` already calls `GetAOERadius()` in
--     shipped code, so the behavioural dumper can record it per ability handle
--     and the question becomes a measurement instead of a mapping argument.
--     Handed off as the next baton (see the round's report).
--   * ⚠️ AND THE TWO NUMBERS AGREEING WOULD STILL NOT CLOSE IT.  The section
--     below used to say that a KV `radius` of 835 would close the gap; that is
--     false and has been corrected.  Equal values are not the same quantity --
--     a coincidence would license exactly the substitution this ruling refuses.
--
-- The anchors themselves:
--   * hoof_stomp cast range: 0 (no-target self-radius ability). Tested at 0 AND
--     at 325 (its stomp radius, a generous upper bound) so the conclusion holds
--     whichever the engine reports.
--   * ice_path cast range: 1000, a deliberate UNDER-estimate (Liquipedia puts
--     the path at 1200 long, reaching ~1362). The predicate is monotone in cast
--     range, so blocking at 1000 blocks at the real value too.
--   * Freezing Field AoE radius: 835 (Liquipedia), used by the end-to-end cases.
-- CM's distance from fountain is NOT an anchor -- the loader wires the real
-- engine method off the map-constant fountains, and she is 9481 units out.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FAR   = 'tests/fixtures/f_260819_004858_cm_centaur_far.lua'   -- must ALLOW
local CLOSE = 'tests/fixtures/f_260819_003005_cm_selfpreserve.lua'  -- must BLOCK

local function hoof(heroes)
    return heroes['npc_dota_hero_centaur']:GetAbilityByName('centaur_hoof_stomp')
end

-- Place `unit` at `dist` units from `bot`, keeping the frame's real bearing.
local function move_to(bot, unit, dist)
    local b, u = bot:GetLocation(), unit:GetLocation()
    local dx, dy = u.x - b.x, u.y - b.y
    local d = math.sqrt(dx * dx + dy * dy)
    rawget(unit, '__spec').GetLocation = Vector(b.x + dx / d * dist, b.y + dy / d * dist, 0)
end

-- ConsiderR's opening bid needs three enemies inside the Freezing Field, and on
-- both real frames only ONE enemy stands that close -- so the shipped bid is
-- BOT_ACTION_DESIRE_NONE there whatever the guard says, and the guard's effect
-- on the FINAL decision is invisible. The end-to-end cases therefore mutate the
-- frame: two enemies who are alive on it are walked into the field. Which two is
-- not a free choice -- they must not change what the guard sees, and the tests
-- ASSERT that (`J.GetReadyHardCc(mover) == nil`) rather than assume it, so the
-- mutation moves the branch precondition and nothing else.
local FIELD_RADIUS = 835                    -- external anchor, see header
local IN_FIELD     = 500                    -- inside 835 * 0.88 = 735
local FAR_FILLERS   = { 'npc_dota_hero_lich', 'npc_dota_hero_luna' }
local CLOSE_FILLERS = { 'npc_dota_hero_chaos_knight', 'npc_dota_hero_pudge' }

--- Arm/disarm the candidate, anchor the ultimate's AoE radius, walk the fillers
--- into the field, then drive the real X.ConsiderR(). Returns the desire it bids.
local function bid_considerR(path, bArmed, tFillers, fTweak)
    local J, bot, heroes = rf.load(path)
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'cmrguard' end
        or function() return false end

    local sAbilityList = J.Skill.GetAbilityList(bot)
    -- GH #36 (fixed 2026-08-19): before ability_meta.lua taught the loader which
    -- name is the ultimate, this slot was nil in every fixture and ConsiderR
    -- short-circuited at IsFullyCastable() without running a line of its logic.
    assert(sAbilityList[6] == 'crystal_maiden_freezing_field',
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    assert(abilityR:IsFullyCastable(), 'R is off cooldown and affordable on this real frame')
    rawget(abilityR, '__spec').GetAOERadius = FIELD_RADIUS

    for _, sName in ipairs(tFillers) do
        assert(J.GetReadyHardCc(heroes[sName]) == nil,
            sName .. ' must hold no ready hard CC, or moving him would change the guard input')
        move_to(bot, heroes[sName], IN_FIELD)          -- MUTATION of the real frame
    end
    if fTweak then fTweak(J, bot, heroes) end

    local X = rf.load_hero('crystal_maiden')
    return X.ConsiderR(), J, bot, heroes
end

local function ranged_cc(sHero, sAbility, nRange)
    return function(_, _, heroes)
        rawget(heroes[sHero]:GetAbilityByName(sAbility), '__spec').GetCastRange = nRange
    end
end

local tests = {}

tests['ground truth: the retreating Centaur at 1326u is the sole ready hard-CC holder in range'] = function()
    local J, bot, heroes, fx = rf.load(FAR)
    assert(fx.self == 'npc_dota_hero_crystal_maiden')
    assert(fx.time == 423.4, 'decision instant')
    assert(bot:GetHealth() == 427 and bot:GetMaxHealth() == 890, 'CM hp on the real frame')

    local centaur = heroes['npc_dota_hero_centaur']
    assert(math.floor(GetUnitToUnitDistance(bot, centaur)) == 1326, 'centaur distance')
    assert(J.GetReadyHardCc(centaur) ~= nil, 'his hoof_stomp is leveled and off cooldown')

    -- The closer enemy is NOT a vetoer: fireblast is 4s from ready.
    local ogre = heroes['npc_dota_hero_ogre_magi']
    assert(math.floor(GetUnitToUnitDistance(bot, ogre)) == 345, 'ogre distance')
    assert(J.GetReadyHardCc(ogre) == nil, 'ogre fireblast is on cooldown at this instant')

    -- Ground truth that makes this a false positive rather than a lucky escape.
    assert(fx.observed.died_after == 44.1, 'CM opened R for real and lived 44.1s')
end

tests['gate OFF: unchanged (always allows), byte-identical to the shipped path'] = function()
    local J, bot = rf.load(FAR)
    GetGameMode = function() return 1 end -- set after rf.load(): install() forces turbo
    J.IsSoakCandidate = function() return false end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'off the candidate nothing may change')
end

tests['gate ON: the 1326u retreating Centaur no longer vetoes (the GH #34 false positive)'] = function()
    local J, bot = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'a self-radius stomp 1326 units away cannot interrupt the channel -- must allow')
end

tests['gate ON: still allows if the engine reports hoof_stomp cast range as its 325 radius'] = function()
    local J, bot, heroes = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    rawget(hoof(heroes), '__spec').GetCastRange = 325 -- generous upper bound
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'the release must not hinge on which of the two plausible values the engine reports')
end

tests['gate ON [MUTATED frame]: same Centaur walked in to 350u -> vetoes again'] = function()
    local J, bot, heroes = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    move_to(bot, heroes['npc_dota_hero_centaur'], 350) -- MUTATION of the real frame
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'the narrowing must not disarm the gate -- a stomp that can actually land still withholds R')
end

tests['gate ON [MUTATED ability]: the same enemy at his real 1326u with a 1000-range CC vetoes'] = function()
    local J, bot, heroes = rf.load(FAR)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    rawget(hoof(heroes), '__spec').GetCastRange = 1000 -- MUTATION: pretend it is ranged
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'the release is caused by DELIVERY RANGE, not by the ability dropping out of the curated table')
end

tests['gate ON: the frame the gate was opened for (Jakiro ice_path, 1139u) is still caught'] = function()
    local J, bot, heroes = rf.load(CLOSE)
    J.IsSoakCandidate = function(id) return id == 'cmrguard' end
    local icePath = heroes['npc_dota_hero_jakiro']:GetAbilityByName('jakiro_ice_path')
    rawget(icePath, '__spec').GetCastRange = 1000 -- under-estimate; see header
    local X = rf.load_hero('crystal_maiden')
    assert(math.floor(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_jakiro'])) == 1138,
        'the original motivating frame, unchanged')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'narrowing must not undo the original catch (lanefix lesson: pin both frames together)')
end

tests['the closing buffer stays inside the window the two real frames bound'] = function()
    rf.load(FAR)
    local X = rf.load_hero('crystal_maiden')
    -- Lower bound: ice_path (>=1000 range) must still cover the 1139u frame.
    assert(X.nRGuardCloseBuffer >= 139,
        'below 139 the Jakiro frame that motivated the whole gate stops being caught')
    -- Upper bound: hoof_stomp (0..325 range) must not cover the 1326u frame.
    assert(X.nRGuardCloseBuffer < 1326 - 325,
        'at or above 1001 the GH #34 false positive comes back')
end

-- END-TO-END, per the director's rule 0b (test_set.md 2026-08-19): assert the
-- decision the world actually gets, not a helper's return value. This was
-- source-level-only when the gate was narrowed (2026-08-19T11:53Z) because
-- sAbilityList[6] was nil in every fixture and ConsiderR short-circuited before
-- reaching the guard -- GH #36, fixed by the director the same day. These four
-- cases are the first time cmrguard's effect on CM's real bid is pinned.

tests['end-to-end [MUTATED frame]: the GH #34 false positive no longer eats the bid'] = function()
    local nBid, J, bot, heroes = bid_considerR(FAR, true, FAR_FILLERS)
    -- The vetoer is untouched: still the real Centaur, at his real distance,
    -- still holding a ready hoof_stomp. Only the enemy COUNT was mutated.
    local centaur = heroes['npc_dota_hero_centaur']
    assert(math.floor(GetUnitToUnitDistance(bot, centaur)) == 1326, 'centaur unmoved')
    assert(J.GetReadyHardCc(centaur) ~= nil, 'and still a ready-hard-CC holder')
    assert(nBid == BOT_ACTION_DESIRE_HIGH,
        'armed, CM must still bid her ultimate -- ground truth is that she cast it and lived 44.1s')
end

tests['end-to-end [MUTATED frame]: armed equals shipped on that frame'] = function()
    local nArmed = bid_considerR(FAR, true, FAR_FILLERS)
    local nShipped = bid_considerR(FAR, false, FAR_FILLERS)
    assert(nShipped == BOT_ACTION_DESIRE_HIGH, 'shipped bids the ultimate here')
    assert(nArmed == nShipped,
        'the narrowed gate must be a no-op on the frame it was narrowed for')
end

tests['end-to-end [MUTATED frame+ability]: a deliverable CC on that Centaur kills the bid'] = function()
    local nBid = bid_considerR(FAR, true, FAR_FILLERS,
        ranged_cc('npc_dota_hero_centaur', 'centaur_hoof_stomp', 1000))
    assert(nBid == BOT_ACTION_DESIRE_NONE,
        'the guard must reach the final decision -- if this still bids, cmrguard is decorative')
end

tests['end-to-end [MUTATED frame]: the motivating Jakiro frame loses the ultimate'] = function()
    local nBid = bid_considerR(CLOSE, true, CLOSE_FILLERS,
        ranged_cc('npc_dota_hero_jakiro', 'jakiro_ice_path', 1000)) -- under-estimate, see header
    assert(nBid == BOT_ACTION_DESIRE_NONE,
        'armed, the channel that got her stunned 0.6s in must not be bid')
end

tests['end-to-end [MUTATED frame]: and shipped bids it there -- the gate is what withholds'] = function()
    local nBid = bid_considerR(CLOSE, false, CLOSE_FILLERS,
        ranged_cc('npc_dota_hero_jakiro', 'jakiro_ice_path', 1000))
    assert(nBid == BOT_ACTION_DESIRE_HIGH,
        'without the candidate CM commits to the channel on the frame that killed her')
end

-- Source-level wiring, kept as the cheap tripwire: the end-to-end cases above
-- would also fail if the guard were unhooked, but these say WHY in one line.
tests['wiring: the guard gates the ConsiderR entry, ahead of every bid branch'] = function()
    local f = assert(io.open('bots/BotLib/hero_crystal_maiden.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function X%.ConsiderR%(%)(.-)\nend')
    assert(body, 'could not locate X.ConsiderR')
    assert(body:match('or not X%.cm_IsRSafeToOpen%( bot %)%s*\n%s*then%s*\n%s*return BOT_ACTION_DESIRE_NONE'),
        'the guard must sit on the early return that yields BOT_ACTION_DESIRE_NONE')
    assert(body:find('cm_IsRSafeToOpen', 1, true) < body:find('BOT_ACTION_DESIRE_HIGH', 1, true),
        'and it must be evaluated before any branch that bids for the ultimate')
end

tests['wiring: nothing calls the range-blind boolean wrapper any more'] = function()
    local f = assert(io.open('bots/BotLib/hero_crystal_maiden.lua', 'r'))
    local src = f:read('*a')
    f:close()
    assert(src:find('J.GetReadyHardCc', 1, true), 'the gate must take the handle')
    assert(src:match('J%.HasReadyHardCc%s*%(') == nil,
        'the boolean wrapper discards the handle -- that IS the GH #34 defect')
end

-- ANCHORS -- why each of the three is still load-bearing after the 2026-09-04
-- loader repair, pinned so the reason cannot rot again (`-76`).
--
-- Every assertion here is written to go RED when an anchor stops being needed.
-- That is the good outcome, and each message says what to do: replace the
-- anchor with the served value and re-derive, never loosen the assertion.
tests['anchors: the non-focus cast ranges are still unserved (by design)'] = function()
    local cases = {
        { FAR,   'npc_dota_hero_centaur', 'centaur_hoof_stomp' },
        { CLOSE, 'npc_dota_hero_jakiro',  'jakiro_ice_path' },
    }
    for _, c in ipairs(cases) do
        local _, _, heroes = rf.load(c[1])
        local u = heroes[c[2]]
        assert(u ~= nil, c[2] .. ' is no longer on ' .. c[1])
        local a = u:GetAbilityByName(c[3])
        assert(a ~= nil, c[3] .. ': no handle')
        assert(rawget(a, '__spec').GetCastRange == nil,
            c[3] .. ': the loader now specs GetCastRange on a NON-FOCUS hero -- the '
            .. 'focus-five bound moved. Drop the hand anchor for this ability and '
            .. 're-derive the two end-to-end cases off the served value.')
        assert(a:GetCastRange() == 0,
            c[3] .. ': unserved handles used to answer 0, this one answers '
            .. tostring(a:GetCastRange()))
    end
end

tests['anchors: GetAOERadius is still not one of the served getters'] = function()
    for _, fx in ipairs({ FAR, CLOSE }) do
        local _, bot = rf.load(fx)
        local r = bot:GetAbilityByName('crystal_maiden_freezing_field')
        assert(r ~= nil, fx .. ': no freezing_field handle')
        local sp = rawget(r, '__spec')
        assert(sp ~= nil and sp.GetSpecialValueFloat ~= nil,
            fx .. ': CM is a focus hero but got no KV spec -- this section is vacuous')
        assert(sp.GetAOERadius == nil,
            fx .. ': the loader now serves GetAOERadius. WHERE FROM decides what to do '
            .. '(2026-09-05 ruling, header): served off an ENGINE reading -- delete '
            .. 'FIELD_RADIUS, take the served value, re-derive. Served off the KV -- '
            .. 'that is the substitution this ruling refuses, revert it.')
    end
end

-- The registered disagreement.  810 is what the fixture's own KV answers under
-- the key named `radius`; 835 is the Liquipedia number this file runs on.  The
-- section name is kept verbatim across the 2026-09-05 ruling (citations point
-- at it): the VALUE gap is still open -- what closed is the mapping question
-- that would have let 810 replace 835.  See the header's ⭐ RULED block.
tests['anchors: the 810 (KV `radius`) vs 835 (anchor) gap is still open'] = function()
    for _, fx in ipairs({ FAR, CLOSE }) do
        local _, bot = rf.load(fx)
        local r = bot:GetAbilityByName('crystal_maiden_freezing_field')
        assert(r:GetLevel() == 1, fx .. ': freezing_field is no longer rank 1; the KV '
            .. 'ladder is rank-indexed, so re-read before comparing')
        assert(r:GetSpecialValueInt('radius') == 810,
            ('%s: KV `radius` now answers %s, registered 810. NOTE the corrected '
            .. 'reading: a move to %d would NOT close the gap and would NOT license '
            .. 'sourcing FIELD_RADIUS from the KV -- equal values are not the same '
            .. 'quantity, and GetAOERadius has no KV field on any of 127 heroes '
            .. '(tools/agent/aoe_radius_source_census.py). Only an ENGINE reading '
            .. 'closes it.')
            :format(fx, tostring(r:GetSpecialValueInt('radius')), FIELD_RADIUS))
    end
    assert(FIELD_RADIUS == 835, 'FIELD_RADIUS moved off the Liquipedia anchor. The '
        .. '2026-09-05 ruling (header) refuses the KV as a source for it, so a move '
        .. 'here needs an engine reading behind it -- say which one in the header.')
end

return tests

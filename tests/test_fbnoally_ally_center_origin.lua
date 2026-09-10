-- [fbnoally 20260910] The Force Boots "push the target INTO my group" branch
-- has no group: J.GetCenterOfUnits({}) answers Vector(0,0) and the branch
-- force-shoves its chase target towards the map ORIGIN.
--
-- THE DEFECT (charter criterion (5), the SENTINEL-VALUE variant the previous
-- round opened: "no data" written as a value that looks like an answer, and a
-- consumer that cannot tell the two apart).
-- bots/ability_item_usage_generic.lua, X.ConsiderItemDesire["item_force_boots"]:
--     local nInRangeAlly = J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE)
--     ...
--     local allyCenterLocation = J.GetCenterOfUnits(nInRangeAlly)
--     if botTarget:IsFacingLocation(allyCenterLocation, 15)
--     and GetUnitToLocationDistance(bot, allyCenterLocation) >= 750
-- With no ally in 1200 the "centroid of my group" is the middle of the Dota
-- map, and BOTH consumers accept it: a facing test is satisfied by any target
-- pointed at mid, and "at least 750 from mid" is true nearly everywhere. The
-- outcome is a tier-5 neutral spent to shove the target 600 units in whatever
-- direction it is already fleeing.
--
-- ⭐ CONDITION (c) IS IN THIS REPO, NOT ON A WIKI. The same decision is written
-- twice. The sibling entry -- item_force_staff, "推敌人靠近自己" -- opens with
--     if J.IsGoingOnSomeone(bot) and #hAllyList >= 2
-- The tier-5 copy dropped the guard. Section 1 measures why the constant is not
-- copied literally: the two ally lists COUNT DIFFERENTLY. J.GetAlliesNearLoc
-- walks GetTeamMember and includes the bot itself (515 of 515 own-team frames);
-- J.GetNearbyHeroes excludes the caller (0 of 1031 frames). So the sibling's
-- ">= 2 including me" is ">= 1" here. docs/BOT_API_REFERENCE.md states neither,
-- which is exactly why this is measured instead of assumed.
--
-- ⛔ WHAT THIS CORPUS CANNOT BUY, said before any number below is read. The
-- branch has three conjuncts no fixture carries, and section 3 MEASURES each
-- one rather than citing it:
--   * the MODE -- J.IsGoingOnSomeone reads GetActiveMode(), which the loader
--     leaves at the generic 0 (BOT_MODE_ATTACK is 1003). Same wall the previous
--     round hit on `tfnull`.
--   * the TARGET -- botTarget is J.GetProperTarget(bot), i.e. GetTarget() /
--     GetAttackTarget(), neither of which the loader wires at all.
--   * the ITEM -- force_boots appears in 0 of the 111 loadable fixtures.
-- ⇒ NO frequency claim is made here about real games, and not one number below
-- may be quoted as one. What the corpus DOES carry is the whole geometry:
-- positions, teams, alive flags and vision are dump ground truth, so sections
-- 1-2 read the CAUSE set and the surviving consumer exactly.
--
-- Section 4 drives the real shipped ItemUsageThink with all three conjuncts
-- supplied by DECLARATION on a real frame. That is a synthetic ENTRY on real
-- geometry: it prices the fix's behaviour at the branch and its no-op upper
-- bound, and it buys nothing at all about how often a game gets there.
--
-- Mutation stand: tools/agent/mutstand_fbnoally.sh

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local AIUG = 'bots/ability_item_usage_generic.lua'
local PIN = 'tests/fixtures/f_071423_sky_rescue.lua'
local PIN_HERO = 'npc_dota_hero_sven'
local PIN_TARGET = 'npc_dota_hero_medusa'

local tests = {}

-- --------------------------------------------------------------- helpers ---

local function read_file(path)
    local f = assert(io.open(path, 'r'), 'could not open ' .. path)
    local s = f:read('*a')
    f:close()
    return s
end

--- The source with every comment removed. This lever's own comment names the
--- id, the sibling entry and both constants, so an unstripped read would let
--- the COMMENT satisfy every structural assertion below.
local function stripped(src)
    src = src:gsub('%-%-%[(=*)%[.-%]%1%]', ' ')
    return (src:gsub('%-%-[^\n]*', ''))
end

local function entry_body(src, sItem)
    local at = src:find('X.ConsiderItemDesire["' .. sItem .. '"] = function', 1, true)
    assert(at ~= nil, 'could not locate the ' .. sItem .. ' consider entry in ' .. AIUG)
    local stop = src:find('\nX.ConsiderItemDesire[', at + 10, true) or #src
    return src:sub(at, stop)
end

local function all_fixtures()
    local out = {}
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'),
        'could not list tests/fixtures')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    assert(#out > 100, 'expected the full fixture corpus, got ' .. #out)
    return out
end

-- ------------------------------------------------------------ the sweep ----

--- One pass over the corpus. Every hero of every fixture is asked the two ally
--- questions the branch asks, on the real frame, through the shipped helpers.
local SWEEP = (function()
    local c = setmetatable({}, { __index = function() return 0 end })
    local function bump(k) c[k] = c[k] + 1 end
    for _, path in ipairs(all_fixtures()) do
        local ok, J, _, heroes, fx = pcall(rf.load, path)
        if not ok or J == nil then
            bump('load_fail')
        else
            bump('fixtures')
            local ORIGIN = Vector(0, 0)
            if J.IsModeTurbo() then bump('turbo_fx') end
            for _, u in ipairs(fx.units) do
                local h = heroes[u.name]
                if h ~= nil and u.alive then
                    bump('live')
                    -- The item conjunct, measured rather than asserted.
                    for _, it in ipairs(u.items or {}) do
                        if it == 'force_boots' then bump('has_force_boots') end
                    end
                    -- The mode and target conjuncts, likewise.
                    if h:GetActiveMode() == BOT_MODE_ATTACK then bump('mode_attack') end
                    if h:GetAttackTarget() ~= nil then bump('has_attack_target') end

                    local a = J.GetNearbyHeroes(h, 1200, false, BOT_MODE_NONE)
                    for _, m in pairs(a) do
                        if m == h then bump('nearby_has_self') end
                    end
                    if h:GetTeam() == GetTeam() then
                        bump('own_team')
                        for _, m in pairs(J.GetAlliesNearLoc(h:GetLocation(), 600)) do
                            if m == h then bump('alloc_has_self') end
                        end
                    end

                    if #a == 0 then
                        bump('ally0')
                        local e = J.GetNearbyHeroes(h, 900, true, BOT_MODE_NONE)
                        if #e > 0 then
                            bump('ally0_chaseable')
                            local nT = #J.GetNearbyHeroes(e[1], 1200, false, BOT_MODE_NONE)
                            local d = GetUnitToLocationDistance(h, ORIGIN)
                            if #a >= nT then bump('ally0_parity') end
                            if #a >= nT + 1 then bump('ally0_sub1') end
                            if d >= 750 then bump('ally0_origin_far') end
                            if #a >= nT and d >= 750 then bump('ally0_joint') end
                        end
                    end
                end
            end
        end
    end
    return c
end)()

local function C(k) return SWEEP[k] end

-- [strategy 20260910, second unit] THE PINS BELOW WERE EQUALITIES AND THAT WAS
-- THE GH #106 / #127 DEFECT, LANDED BY THIS STREAM'S OWN PREVIOUS ROUND.
-- `C('fixtures') == 111` re-stated the corpus size inside a test about the
-- force-boots centroid, so the next fixture anybody appends turns this file red
-- without one thing it measures having moved -- and it did not wait for that
-- fixture: tests/test_corpus_scale.lua is the detector for exactly this shape
-- and it went red on trunk the moment the pin landed. The counters here are all
-- SUMS OVER FIXTURES (the sweep visits each fixture once and adds), so append
-- can only raise them: `ratchet` still catches the fall that would mean
-- behaviour moved, and stops charging for growth. The ZERO claims below
-- (nearby_has_self, ally0_sub1, and all of section 3) stay equalities on
-- purpose -- they are already growth-immune, and several of this file's
-- INERT/bounds sentences are argued from them.
tests['[fbnoally] 0. the sweep covered the corpus'] = function()
    assert(C('load_fail') == 0, C('load_fail') .. ' fixtures failed to load')
    cs.corpus(C('fixtures'), 'fbnoally sweep')
    cs.ratchet(C('live'), 1031, 'live hero frames')
    cs.universal(C('turbo_fx'), C('fixtures'), 'the corpus is all-Turbo', cs.FLOOR)
end

-- ------------------------------- 1. the two ally lists count differently ----

tests['[fbnoally] 1. MEASURED: GetAlliesNearLoc includes self, GetNearbyHeroes does not']
= function()
    -- This is the whole reason the sibling's `>= 2` becomes `>= 1` here, and it
    -- is a fact about the shipped helpers, not about the docs -- which state
    -- neither. If a future engine/loader change flips either reading, the
    -- constant in bots/ is wrong and this goes red first.
    cs.ratchet(C('own_team'), 515, 'own-team frames')
    cs.universal(C('alloc_has_self'), C('own_team'),
        'J.GetAlliesNearLoc includes the bot itself (the sibling entry\'s '
        .. '`#hAllyList >= 2` means "me plus one")', 500)
    assert(C('nearby_has_self') == 0,
        'J.GetNearbyHeroes handed the caller back to itself on '
        .. C('nearby_has_self') .. ' frames -- then `#nInRangeAlly == 0` is not '
        .. 'reachable and this whole lever is a no-op')
end

-- ------------------------------------- 2. the cause set and what survives ---

tests['[fbnoally] 2. MEASURED: the empty ally list is the common case'] = function()
    -- The set that makes the sentinel: a live hero with no VISIBLE ally inside
    -- the branch's own 1200. Real geometry, no mode/target/item needed.
    cs.ratchet(C('ally0'), 556, 'zero-ally frames')
    assert(C('ally0') * 2 > C('live'), 'the zero-ally case is now a minority of '
        .. 'frames (' .. C('ally0') .. ' of ' .. C('live') .. ') -- the "it never '
        .. 'happens" reading this lever rejects would need re-examining')
end

tests['[fbnoally] 2b. MEASURED: the sentinel clears the branch\'s own gates'] = function()
    -- Of the zero-ally frames, those that also have a visible enemy hero inside
    -- the branch's 900. Then: does the branch's OWN parity gate pass (it does
    -- exactly when the target is also alone), and does the surviving consumer
    -- -- ">= 750 from the ally centroid" -- accept the origin?
    cs.ratchet(C('ally0_chaseable'), 107, 'zero-ally frames with a chaseable enemy')
    cs.ratchet(C('ally0_parity'), 58, 'zero-ally frames clearing the parity gate')
    cs.ratchet(C('ally0_origin_far'), 95, 'zero-ally frames >= 750 from the origin')
    cs.ratchet(C('ally0_joint'), 48, 'zero-ally frames clearing both')
    assert(C('ally0_joint') > 0, 'no frame in the corpus clears both the parity '
        .. 'gate and the distance consumer on the sentinel -- the consequence '
        .. 'this lever prices would be unwitnessed')
    -- ⛔ The facing consumer is NOT in this reading: the fixtures carry no
    -- facing, so bot:IsFacingLocation falls to the mock's ^Is -> false default.
    -- 48 is therefore an UPPER bound on the geometry, not a count of casts.
end

tests['[fbnoally] 2c. the earlier sub-branch cannot be credited to this fix'] = function()
    -- The same `if` block has a first arm that returns HIGH on the BOT:
    --     #nInRangeAlly >= #nTargetInRangeAlly + 1
    -- At zero allies that is `0 >= n+1`, false for every n >= 0. So the refusal
    -- below it can never be the reason that arm stops firing. Asserted on the
    -- frames rather than argued, so a later round cannot slip that lever in
    -- under this id.
    assert(C('ally0_sub1') == 0, C('ally0_sub1') .. ' zero-ally frames satisfy '
        .. 'the self-push arm -- the arithmetic this fix leans on is wrong')
end

-- ------------------------------------------------- 3. the loader bounds -----

tests['[fbnoally] 3. MEASURED: the three conjuncts this corpus cannot supply']
= function()
    -- Each of these is the reason a number above is a geometry reading and not
    -- a frequency. Asserting them means a loader that later buys one of them
    -- turns this red, and the honest-bounds header has to be rewritten.
    assert(C('has_force_boots') == 0, C('has_force_boots') .. ' fixture heroes now '
        .. 'carry force_boots -- the item conjunct is buyable, drive it for real')
    assert(C('mode_attack') == 0, C('mode_attack') .. ' fixture heroes now report '
        .. 'BOT_MODE_ATTACK -- the mode conjunct is buyable, drive it for real')
    assert(C('has_attack_target') == 0, C('has_attack_target') .. ' fixture heroes '
        .. 'now report an attack target -- the target conjunct is buyable')
    assert(BOT_MODE_ATTACK ~= 0, 'the default the mode reading leans on must '
        .. 'differ from BOT_MODE_ATTACK')
end

-- ------------------------------------------------------- 4. the source ------

tests['[fbnoally] 4. the sibling entry still carries the guard this one lacked']
= function()
    local src = stripped(read_file(AIUG))
    local sib = entry_body(src, 'item_force_staff')
    assert(sib:find('#hAllyList >= 2', 1, true) ~= nil,
        'the item_force_staff entry no longer guards its ally centroid with '
        .. '`#hAllyList >= 2` -- the in-repo condition-(c) argument for this '
        .. 'lever is gone and has to be re-derived')
    assert(sib:find('J.GetCenterOfUnits( hAllyList )', 1, true) ~= nil,
        'the sibling no longer takes a centroid of that list -- it is not the '
        .. 'same decision any more')
end

tests['[fbnoally] 4b. the fix is gated, turbo-only, and conditioned on the empty list']
= function()
    local src = stripped(read_file(AIUG))
    local body = entry_body(src, 'item_force_boots')
    assert(body:find('#nInRangeAlly == 0', 1, true) ~= nil,
        'the refusal is no longer conditioned on the empty ally list -- it has '
        .. 'stopped being a sentinel guard and become a policy')
    assert(body:match("J%.IsSoakCandidate%('fbnoally'%)") ~= nil,
        'the force_boots entry is not gated on fbnoally -- either the gate was '
        .. 'removed (promotion) or a new lever landed ungated here')
    assert(body:find('J.IsModeTurbo()', 1, true) ~= nil,
        'the fix is no longer turbo-only')
    -- One id wide. A second id in this entry would mean two levers share a
    -- verdict, which is what "one small lever at a time" forbids.
    local n = 0
    for _ in body:gmatch('J%.IsSoakCandidate%(') do n = n + 1 end
    assert(n == 1, 'expected exactly one soak gate in the force_boots entry, got ' .. n)
end

-- ----------------------------- 5. the drive: real code, declared entry -------

--- Supply, by declaration, exactly the three conjuncts section 3 measured as
--- absent -- and the facing bit the dump does not carry either. Nothing else
--- about the frame is touched: positions, teams, vision and the ally lists stay
--- dump ground truth, and they are what the branch actually decides on.
local function stage(path, sHero, sTarget, nAllyOverride)
    local J, bot, heroes = rf.load(path, sHero)
    assert(bot ~= nil, path .. ': the pinned hero no longer loads')
    local tgt = heroes[sTarget]
    assert(tgt ~= nil, path .. ': the pinned target no longer loads')

    local bs, ts = rawget(bot, '__spec'), rawget(tgt, '__spec')
    bs.GetActiveMode = function() return BOT_MODE_ATTACK end
    bs.GetTarget = function() return tgt end
    ts.IsFacingLocation = function() return true end

    -- The item under test, alone in the bag, so no sibling entry can claim the
    -- action this section reads.
    local hItem = require('mock.bot_api').MakeAbility('item_force_boots', {
        IsFullyCastable = true, IsTrained = true, IsActivated = true,
        IsPassive = false, IsHidden = false, IsNull = false,
        GetCooldownTimeRemaining = 0,
    })
    bs.GetItemInSlot = function(_, i) if i == 16 then return hItem end return nil end

    if nAllyOverride ~= nil then
        local real = J.GetNearbyHeroes
        J.GetNearbyHeroes = function(u, r, bEnemy, m)
            local out = real(u, r, bEnemy, m)
            if u == bot and not bEnemy and r == 1200 then return nAllyOverride end
            return out
        end
    end
    return J, bot, tgt, hItem
end

local function drive(path, sHero, sTarget, bArmed, nAllyOverride)
    local J, bot, tgt = stage(path, sHero, sTarget, nAllyOverride)
    J.IsSoakCandidate = function(sId) return bArmed and sId == 'fbnoally' end
    local aiug = assert(loadfile(AIUG))
    assert(pcall(aiug), path .. ': ' .. AIUG .. ' failed to load on this frame')
    local log = rf.record_actions(bot)
    bot.lastItemFrameProcessTime = DotaTime() - 100
    assert(pcall(_G.ItemUsageThink), path .. ': ItemUsageThink crashed')
    for _, e in ipairs(log) do
        for _, a in ipairs(e.args) do
            if a == tgt then return true end
        end
    end
    return false
end

tests['[fbnoally] 5. the shipped code shoves the target towards the origin; armed it does not']
= function()
    -- The pin is one of the 48 frames section 2b counted: Sven, no ally inside
    -- 1200, Medusa inside 900 and also alone, and the fabricated "ally centroid"
    -- sits 8047 units away from Sven -- eight thousand units of empty map,
    -- handed to two consumers that only ask "is it far, is it faced".
    local J, bot, tgt = stage(PIN, PIN_HERO, PIN_TARGET)
    assert(#J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) == 0,
        'the pin has an ally inside 1200 now -- it is no longer the sentinel case')
    assert(GetUnitToUnitDistance(bot, tgt) <= 900,
        'the pin\'s target left the branch\'s 900')
    local nOff = GetUnitToLocationDistance(bot, Vector(0, 0))
    assert(math.abs(nOff - 8047) <= 1.0,
        ('the fabricated centroid sits %.0f from the bot, recorded 8047'):format(nOff))

    assert(drive(PIN, PIN_HERO, PIN_TARGET, false) == true,
        'the shipped code no longer casts on the sentinel here -- the defect '
        .. 'this lever removes is not reachable on the pin any more')
    assert(drive(PIN, PIN_HERO, PIN_TARGET, true) == false,
        'armed, the refusal did not stop the cast')
end

tests['[fbnoally] 5b. with one ally present the fix is a no-op'] = function()
    -- The risk upper bound, driven rather than argued: give the same frame a
    -- real ally in the list and armed must be byte-identical to shipped. The
    -- refusal is a conjunction containing `#nInRangeAlly == 0`, so this holds
    -- for every non-empty list; the drive proves the gate does not leak past it.
    local ALLY = 'npc_dota_hero_dragon_knight'
    local _, _, heroes0 = rf.load(PIN, PIN_HERO)
    assert(heroes0[ALLY] ~= nil, 'the pin no longer carries the stand-in ally')

    local function with_ally(bArmed)
        local _, _, heroes = rf.load(PIN, PIN_HERO)
        return drive(PIN, PIN_HERO, PIN_TARGET, bArmed, { heroes[ALLY] })
    end
    local bOff, bOn = with_ally(false), with_ally(true)
    -- The equality below is worthless unless the branch is still REACHED with a
    -- non-empty list. Two equal `false`s would read as "no-op" while proving
    -- only that the drive stopped working.
    assert(bOff == true, 'the shipped code no longer casts when the ally list is '
        .. 'non-empty -- the no-op reading below would be vacuous')
    assert(bOff == bOn,
        'armed changed the decision on a frame whose ally list is NOT empty -- '
        .. 'the guard leaked out of its own domain')
end

tests['[fbnoally] 5c. gate off and non-turbo both keep the shipped answer'] = function()
    assert(drive(PIN, PIN_HERO, PIN_TARGET, false) == true,
        'unarmed must keep the shipped cast')
    -- armed but not Turbo, driven through the predicate the call site reads.
    local J, bot, tgt = stage(PIN, PIN_HERO, PIN_TARGET)
    J.IsSoakCandidate = function(sId) return sId == 'fbnoally' end
    J.IsModeTurbo = function() return false end
    local aiug = assert(loadfile(AIUG))
    assert(pcall(aiug))
    local log = rf.record_actions(bot)
    bot.lastItemFrameProcessTime = DotaTime() - 100
    assert(pcall(_G.ItemUsageThink))
    local bCast = false
    for _, e in ipairs(log) do
        for _, a in ipairs(e.args) do if a == tgt then bCast = true end end
    end
    assert(bCast, 'the fix fired outside Turbo')
end

return tests

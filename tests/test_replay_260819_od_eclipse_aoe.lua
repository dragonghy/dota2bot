-- Replay-fixture regression for GH #54: Sanity's Eclipse is an AREA nuke whose
-- only firing condition was "can this ONE enemy be executed by it".
--
-- OBSERVATION (GH #54, 8 mirror games from the 22:11Z (a) evidence wave):
--   51 opportunity frames (ult trained, cd 0, mana >= 400, an enemy hero inside
--   600u, 6s-deduped) produced 8 real casts; OD died 17 times, 10 of those
--   holding a ready ultimate. Both pinned frames below come from
--   20260819_222559_slot1, a game in which OD cast the ultimate ZERO times.
--
-- ENTITY NOTE (why the frames were re-derived rather than trusted by name):
--   that replay carries THREE entities named npc_dota_hero_obsidian_destroyer
--   -- the hero (idx 1279) and two illusions (idx 216, 1896, spawned at t=412,
--   max_mp 1123, dead from then on). Selecting "the OD snapshot" by hero name
--   picks an illusion corpse and every distance in the frame is wrong by
--   thousands of units. All numbers in this header were measured with the
--   entity locked to (name, idx) as GH #54 §7 prescribes; make_fixture.py
--   drops illusions at generation, so the fixtures themselves carry the hero.
--
-- FRAME A -- must CAST (f_260819_222559_od_eclipse_pair.lua, t=631.5):
--   OD at full health 1374/1374 with 1415/1415 mana, ultimate level 1, cd 0.
--   lich   396.4u away, 708/1153 HP, 456 mana
--   medusa 496.4u away, 227/230  HP, 569 mana
--   The two of them stand 121.5u apart, so a single 500-radius circle holds
--   both with room to spare, and the circle's centre is well inside the 700
--   cast range. Estimated pre-mitigation damage at OD's mana: 584 on the lich
--   (82% of its current health) and 538 on the medusa. He cast nothing.
--   Ground truth from the following 5s (fixture observed.burst): the medusa
--   dealt him 364 damage -- this is a real fight, not two enemies walking past.
--   The shipped loop refuses because neither enemy can be single-killed by it.
--
-- FRAME B -- must NOT cast (f_260819_222559_od_eclipse_solo.lua, t=661.5):
--   Same game, 30s later, same OD, ultimate still ready, 1448 mana. Exactly ONE
--   enemy inside cast range: the lich, 583.1u away, 712/1153 HP, 175 mana.
--   This is the sharpest possible control: that lone lich is individually
--   WORTH MORE than either target in frame A (estimated damage 709 against 712
--   current health), so anything that fired on "is this juicy" would fire here.
--   The area branch must still refuse it, because one enemy is not an area.
--
-- FIX: X.od_GetEclipseAoeLocation + X.od_IsEclipseWorthHitting in
-- bots/BotLib/hero_obsidian_destroyer.lua, gated turbo + soak candidate
-- 'odaoe', consumed in X.ConsiderSanitysEclipse BELOW the shipped
-- single-target loop. Placement is the safety property: armed, the branch can
-- only turn a NONE into a cast, never redirect a cast the shipped code already
-- decided on. Unarmed it returns nil on its first line.
--
-- WHAT THE ISSUE ASKED FOR AND THIS DOES NOT DO: GH #54 §5.3 flags the
-- surrounding `if J.IsGoingOnSomeone(bot)` as a second, separate defect (it
-- shuts the ultimate off entirely in RETREAT/PUSH rather than lowering its
-- priority). The new branch sits INSIDE that block deliberately -- one lever
-- per change. The mode domain stays exactly as shipped.
--
-- EXTERNAL ANCHORS -- five numbers do not come from the replay. All five are
-- read from the game's own KV (dotabuff/d2vpkr,
-- dota/scripts/npc/heroes/npc_dota_hero_obsidian_destroyer.txt, the same
-- authoritative source tools/agent/gen_ability_meta.py uses), not from a wiki
-- summary, because make_fixture.py extracts no ability specs and the mock's
-- generic Get* default is 0:
--   AbilityCastRange 700, radius 500/525/550 (level 1 -> 500),
--   base_damage 200/300/400 (level 1 -> 200), damage_multiplier 0.4,
--   AbilityManaCost 200/300/400 (level 1 -> 200).
--   Cast range is not optional decoration: at the default 0 the shipped
--   J.GetNearbyHeroes(bot, nCastRange, ...) returns nobody and every case here
--   would be an empty green.
-- Everything else -- both frames' positions, health, mana, levels, ability
-- levels and cooldowns, alive/dead, inventories, and the 5s damage ground
-- truth -- is real frame data.
--
-- HONEST BOUNDARIES:
--   1. J.IsGoingOnSomeone reads GetActiveMode, which is not in the .dem (the
--      J.IsRetreating family, GH #27). The end-to-end cases set it as an
--      EXPLICITLY LABELLED mutation; the helper cases do not need it.
--   2. The damage figures quoted above are pre-mitigation estimates using the
--      ability's own formula. Real mitigation on frame A includes the lich's
--      pipe barrier and the medusa's mana shield; no case here asserts that
--      either enemy would have DIED, only that one circle covers two of them.
--   3. One game, one OD. Whether spending the ultimate on pairs is better on
--      aggregate is a batch question, not a fixture question (lanefix lesson).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local PAIR = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua' -- must CAST
local SOLO = 'tests/fixtures/f_260819_222559_od_eclipse_solo.lua' -- must REFUSE

local ULT_NAME       = 'obsidian_destroyer_sanity_eclipse'
local ULT_CAST_RANGE = 700   -- external anchors, see header
local ULT_RADIUS     = 500
local ULT_BASE_DMG   = 200
local ULT_MULTIPLIER = 0.4
local ULT_MANA_COST  = 200

--- Load a frame, arm/disarm the candidate, return the real hero module.
local function load_od(path, bArmed, bTurbo)
    local J, bot, heroes, fx = rf.load(path)

    local sp = rawget(bot:GetAbilityByName(ULT_NAME), '__spec')
    sp.GetCastRange = ULT_CAST_RANGE
    sp.GetManaCost = ULT_MANA_COST
    sp.GetSpecialValueInt = function(_, key)
        if key == 'radius' then return ULT_RADIUS end
        return 0
    end
    sp.GetSpecialValueFloat = function(_, key)
        if key == 'base_damage' then return ULT_BASE_DMG end
        if key == 'damage_multiplier' then return ULT_MULTIPLIER end
        return 0
    end

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'odaoe' end
        or function() return false end

    local X = rf.load_hero('obsidian_destroyer')
    return X, J, bot, heroes, fx
end

--- The helper as X.ConsiderSanitysEclipse itself calls it.
local function aoe_location(X, bot)
    return X.od_GetEclipseAoeLocation(bot, ULT_CAST_RANGE, ULT_RADIUS,
        ULT_BASE_DMG, ULT_MULTIPLIER)
end

--- Drive the real X.SkillsComplement() and return what reached the action queue.
--- MUTATION, labelled: GetActiveMode is not in the dump, and J.IsGoingOnSomeone
--- (the shipped domain this branch lives inside) reads nothing else.
local function run_skills(path, bArmed)
    local X, J, bot, heroes, fx = load_od(path, bArmed)
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, X, J, bot, heroes, fx
end

local function ability_names(log)
    local t = {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local a = e.args[1]
            t[#t + 1] = (type(a) == 'table' and a.GetName) and a:GetName() or tostring(a)
        end
    end
    return t
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

local function eclipse_location(log)
    for _, e in ipairs(log) do
        local a = e.args[1]
        if e.fn:find('UseAbilityOnLocation')
            and type(a) == 'table' and a.GetName and a:GetName() == ULT_NAME
        then
            return e.args[2]
        end
    end
    return nil
end

local tests = {}

-- ---------------------------------------------------------------- ground truth

tests['ground truth A: one 500 circle holds two enemies, and he cast nothing'] = function()
    local X, _, bot, heroes, fx = load_od(PAIR, true)
    assert(fx.time == 631.5, 'frame A is the pair frame, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_obsidian_destroyer', 'subject is OD')
    assert(bot:GetHealth() == 1374 and bot:GetMaxHealth() == 1374,
        'real health on the frame, got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:GetMana() == 1415, 'real mana on the frame, got ' .. bot:GetMana())

    local ult = bot:GetAbilityByName(ULT_NAME)
    assert(ult:GetLevel() == 1, 'ultimate is level 1')
    assert(ult:IsFullyCastable(), 'ready and affordable -- 1415 mana against a 200 cost')

    local lich   = heroes['npc_dota_hero_lich']
    local medusa = heroes['npc_dota_hero_medusa']
    assert(lich:IsAlive() and medusa:IsAlive(), 'both enemies are alive')

    local dLich   = GetUnitToUnitDistance(bot, lich)
    local dMedusa = GetUnitToUnitDistance(bot, medusa)
    assert(dLich > 390 and dLich < 400, 'lich is ~396 away, got ' .. math.floor(dLich))
    assert(dMedusa > 490 and dMedusa < 500, 'medusa is ~496 away, got ' .. math.floor(dMedusa))
    assert(dLich < ULT_CAST_RANGE and dMedusa < ULT_CAST_RANGE, 'both inside cast range')

    local sep = GetUnitToUnitDistance(lich, medusa)
    assert(sep > 115 and sep < 130, 'they stand ~121 apart, got ' .. math.floor(sep))
    assert(sep <= 2 * ULT_RADIUS,
        'which is what makes a single circle able to hold both')

    -- The shipped exit's own question, answered on the real frame.
    assert(lich:GetHealth() == 708, 'lich health, got ' .. lich:GetHealth())
    assert(medusa:GetHealth() == 227, 'medusa health, got ' .. medusa:GetHealth())
    assert(lich:GetMana() == 456 and medusa:GetMana() == 569, 'real enemy mana')

    -- Ground truth from the 5s after the frame: this really was a fight.
    assert((fx.observed.burst['npc_dota_hero_medusa'] or 0) > 300,
        'the medusa dealt him 364 over the next 5s, got '
        .. tostring(fx.observed.burst['npc_dota_hero_medusa']))
    assert(X ~= nil, 'the hero module loaded')
end

tests['ground truth B: a lone lich, individually juicier than either A target'] = function()
    local X, _, bot, heroes, fx = load_od(SOLO, true)
    assert(fx.time == 661.5, 'frame B is the solo frame, got ' .. tostring(fx.time))
    assert(bot:GetMana() == 1448, 'real mana on the frame, got ' .. bot:GetMana())
    assert(bot:GetAbilityByName(ULT_NAME):IsFullyCastable(), 'the ultimate is ready here too')

    local lich = heroes['npc_dota_hero_lich']
    local d = GetUnitToUnitDistance(bot, lich)
    assert(d > 578 and d < 590, 'lich is ~583 away, got ' .. math.floor(d))
    assert(d < ULT_CAST_RANGE, 'and inside cast range')

    -- Nobody else is: the frame's discriminator is the COUNT, so census it.
    local nInRange = 0
    for _, u in ipairs(fx.units) do
        if u.alive and u.team ~= 2 then
            local h = heroes[u.name]
            if GetUnitToUnitDistance(bot, h) <= ULT_CAST_RANGE then nInRange = nInRange + 1 end
        end
    end
    assert(nInRange == 1, 'exactly one enemy inside cast range, got ' .. nInRange)

    -- And that one enemy passes the per-target value test with room to spare,
    -- so the refusal below cannot be blamed on the damage clause.
    assert(X.od_IsEclipseWorthHitting(bot, lich, ULT_BASE_DMG, ULT_MULTIPLIER) == true,
        'the lone lich IS worth hitting -- 709 estimated against 712 health')
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: unarmed, the helper is inert on the frame that motivated it'] = function()
    local X, _, bot = load_od(PAIR, false)
    assert(aoe_location(X, bot) == nil,
        'unarmed the branch must not exist -- shipped behaviour byte for byte')
end

tests['gate OFF: armed but NOT turbo is still inert'] = function()
    local X, _, bot = load_od(PAIR, true, false)
    assert(aoe_location(X, bot) == nil, 'the gate is turbo-only')
end

-- ------------------------------------------------------------------ gate armed

tests['armed: casts on the real frame, and the point covers BOTH enemies'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    local vLoc, nCovered = aoe_location(X, bot)
    assert(vLoc ~= nil, 'the pair frame must produce an area cast')
    assert(nCovered == 2, 'and it must report two covered enemies, got ' .. tostring(nCovered))

    assert(GetUnitToLocationDistance(bot, vLoc) <= ULT_CAST_RANGE,
        'the chosen point must be castable at all, got '
        .. math.floor(GetUnitToLocationDistance(bot, vLoc)))
    for _, name in ipairs({ 'npc_dota_hero_lich', 'npc_dota_hero_medusa' }) do
        local d = GetUnitToLocationDistance(heroes[name], vLoc)
        assert(d <= ULT_RADIUS,
            name .. ' must actually be inside the circle, got ' .. math.floor(d))
    end
end

tests['armed: refuses the solo frame -- one enemy is not an area'] = function()
    local X, _, bot = load_od(SOLO, true)
    assert(aoe_location(X, bot) == nil,
        'a single covered enemy must not fire the area branch')
end

tests['armed: the solo frame fires once the minimum is lowered to one'] = function()
    -- MUTATION of the threshold, not of the frame: proves the count clause is
    -- the ONLY thing refusing frame B (everything else about that lich passes).
    local X, _, bot = load_od(SOLO, true)
    X.nRAoeMinTargets = 1
    assert(aoe_location(X, bot) ~= nil,
        'with the minimum at one, the lone lich is a legal target')
end

tests['armed: the minimum-targets constant is 2 and is read, not hardcoded'] = function()
    local X, _, bot = load_od(PAIR, true)
    assert(X.nRAoeMinTargets == 2, 'shipped minimum, got ' .. tostring(X.nRAoeMinTargets))
    X.nRAoeMinTargets = 3
    assert(aoe_location(X, bot) == nil,
        'raising it above the two covered enemies must refuse frame A')
end

tests['armed: an enemy walked out of cast range drops the pair to a single'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    -- MUTATION of the real frame: push the medusa past the 700 cast range.
    local v = bot:GetLocation()
    rawget(heroes['npc_dota_hero_medusa'], '__spec').GetLocation =
        Vector(v.x + 1500, v.y, v.z)
    assert(aoe_location(X, bot) == nil,
        'only the lich is left in range -- back to a single target')
end

tests['armed: two enemies too far APART for one circle do not count'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    -- MUTATION of the real frame: keep the medusa inside cast range but move
    -- her more than 2*radius from the lich, so no single point holds both.
    -- The lich sits 396 from OD, so the far side of the 700 ring is the only
    -- place both constraints hold at once -- push her straight down that axis.
    local vBot  = bot:GetLocation()
    local vLich = heroes['npc_dota_hero_lich']:GetLocation()
    local dx, dy = vBot.x - vLich.x, vBot.y - vLich.y
    local len = math.sqrt(dx * dx + dy * dy)
    local medusa = heroes['npc_dota_hero_medusa']
    rawget(medusa, '__spec').GetLocation =
        Vector(vBot.x + dx / len * 690, vBot.y + dy / len * 690, vBot.z)
    assert(GetUnitToUnitDistance(bot, medusa) <= ULT_CAST_RANGE,
        'sanity: she is still inside cast range, got '
        .. math.floor(GetUnitToUnitDistance(bot, medusa)))
    assert(GetUnitToUnitDistance(heroes['npc_dota_hero_lich'], medusa) > 2 * ULT_RADIUS,
        'sanity: and now further from the lich than one circle can span, got '
        .. math.floor(GetUnitToUnitDistance(heroes['npc_dota_hero_lich'], medusa)))
    assert(aoe_location(X, bot) == nil,
        'coverage is geometric -- two in range is not two in one circle')
end

tests['armed: a pair only a MIDPOINT can cover is still found'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    -- LABELLED SYNTHETIC GEOMETRY on the real frame. The pinned pair stands
    -- 121.5 apart, so on that frame every candidate centre works and the
    -- midpoint candidates are not load bearing. This case builds the geometry
    -- that needs them -- two enemies further apart than the radius but closer
    -- than twice it -- by swinging the medusa 90 degrees off the OD->lich axis
    -- at 650 units, which keeps her inside cast range.
    local vBot  = bot:GetLocation()
    local vLich = heroes['npc_dota_hero_lich']:GetLocation()
    local dx, dy = vLich.x - vBot.x, vLich.y - vBot.y
    local len = math.sqrt(dx * dx + dy * dy)
    local medusa = heroes['npc_dota_hero_medusa']
    rawget(medusa, '__spec').GetLocation =
        Vector(vBot.x - dy / len * 650, vBot.y + dx / len * 650, vBot.z)

    local lich = heroes['npc_dota_hero_lich']
    local sep = GetUnitToUnitDistance(lich, medusa)
    assert(sep > ULT_RADIUS and sep < 2 * ULT_RADIUS,
        'the point of the case: neither enemy is a usable centre, got ' .. math.floor(sep))
    assert(GetUnitToUnitDistance(bot, medusa) <= ULT_CAST_RANGE, 'sanity: still castable')

    local vLoc, nCovered = aoe_location(X, bot)
    assert(vLoc ~= nil and nCovered == 2,
        'one circle still holds both, so the branch must find it, got '
        .. tostring(nCovered))
    assert(GetUnitToLocationDistance(lich, vLoc) <= ULT_RADIUS
        and GetUnitToLocationDistance(medusa, vLoc) <= ULT_RADIUS,
        'and the point it returns must really cover both')
end

tests['armed: a shrunken radius stops covering the real pair'] = function()
    local X, _, bot = load_od(PAIR, true)
    -- The two enemies are 121.5 apart, so a 50 radius cannot hold both.
    assert(X.od_GetEclipseAoeLocation(bot, ULT_CAST_RANGE, 50,
        ULT_BASE_DMG, ULT_MULTIPLIER) == nil,
        'the radius is load bearing, not decoration')
end

tests['armed: a missing or zero radius refuses rather than guesses'] = function()
    local X, _, bot = load_od(PAIR, true)
    assert(X.od_GetEclipseAoeLocation(bot, ULT_CAST_RANGE, 0,
        ULT_BASE_DMG, ULT_MULTIPLIER) == nil, 'zero radius must refuse')
    assert(X.od_GetEclipseAoeLocation(bot, ULT_CAST_RANGE, nil,
        ULT_BASE_DMG, ULT_MULTIPLIER) == nil, 'nil radius must refuse')
    assert(X.od_GetEclipseAoeLocation(bot, 0, ULT_RADIUS,
        ULT_BASE_DMG, ULT_MULTIPLIER) == nil, 'zero cast range must refuse')
end

-- --------------------------------------------------------- the value clause

tests['armed: an enemy with MORE mana than OD takes nothing and does not count'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    local medusa = heroes['npc_dota_hero_medusa']
    -- MUTATION of the real frame: the damage is a mana DIFFERENCE, so an enemy
    -- at or above OD's own pool is a free body in the circle, not a target.
    rawget(medusa, '__spec').GetMana = bot:GetMana()
    assert(X.od_IsEclipseWorthHitting(bot, medusa, ULT_BASE_DMG, ULT_MULTIPLIER) == false,
        'no mana gap, no damage')
    assert(aoe_location(X, bot) == nil, 'and so the pair is no longer a pair')
end

tests['armed: a target the cast barely scratches does not count'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    local lich = heroes['npc_dota_hero_lich']
    -- MUTATION of the real frame: 584 estimated damage against 25% of health
    -- passes at 708 health; give the lich enough health that it does not.
    rawget(lich, '__spec').GetHealth = 20000
    assert(X.od_IsEclipseWorthHitting(bot, lich, ULT_BASE_DMG, ULT_MULTIPLIER) == false,
        'a rounding error on a health bar is not a reason to spend an ultimate')
    assert(aoe_location(X, bot) == nil, 'and the frame falls back to a single target')
end

tests['armed: the damage floor is 0.25 and both sides of it are pinned'] = function()
    local X, _, bot, heroes = load_od(PAIR, true)
    assert(X.nRAoeMinDamagePct == 0.25,
        'shipped floor, got ' .. tostring(X.nRAoeMinDamagePct))
    local lich = heroes['npc_dota_hero_lich']
    local nDamage = ULT_BASE_DMG + (bot:GetMana() - lich:GetMana()) * ULT_MULTIPLIER
    -- Just under: the target's health makes the cast worth exactly below the floor.
    rawget(lich, '__spec').GetHealth = math.floor(nDamage / X.nRAoeMinDamagePct) + 10
    assert(X.od_IsEclipseWorthHitting(bot, lich, ULT_BASE_DMG, ULT_MULTIPLIER) == false,
        'below the floor')
    rawget(lich, '__spec').GetHealth = math.floor(nDamage / X.nRAoeMinDamagePct) - 10
    assert(X.od_IsEclipseWorthHitting(bot, lich, ULT_BASE_DMG, ULT_MULTIPLIER) == true,
        'above the floor')
end

tests['cross-layer: an illusion in the circle does not make it a pair'] = function()
    local X, J, bot, heroes = load_od(PAIR, true)
    -- MUTATION of the real frame: this replay genuinely contained two OD
    -- illusions (see header), so a counter that trusts hero entities is a real
    -- risk here, not a hypothetical one.
    -- NOTE ON WHAT THIS TESTS: X.od_IsEclipseWorthHitting has no illusion
    -- branch of its own -- J.CanCastOnNonMagicImmune ends in exactly that call,
    -- so a second one would be unreachable. This case therefore pins the
    -- CROSS-LAYER fact (the helper inherits illusion filtering from that
    -- helper) and fails if either layer stops providing it.
    local medusa = heroes['npc_dota_hero_medusa']
    medusa.is_suspicious_illusion = true
    assert(J.CanCastOnNonMagicImmune(medusa) == false,
        'the layer this helper relies on must reject illusions')
    assert(X.od_IsEclipseWorthHitting(bot, medusa,
        ULT_BASE_DMG, ULT_MULTIPLIER) == false, 'illusions are not targets')
    assert(aoe_location(X, bot) == nil, 'and cannot pad the coverage count')
end

-- ------------------------------------------------------------------ end to end

tests['end to end: shipped reaches the loop, sees both enemies, and casts nothing'] = function()
    local log, X, J, bot = run_skills(PAIR, false)
    local names = ability_names(log)
    assert(not contains(names, ULT_NAME),
        'the shipped single-target exit refuses this frame, got {'
        .. table.concat(names, ',') .. '}')
    -- This IS the bug, so "nothing was queued" is the correct shipped outcome
    -- and cannot itself be the positive assertion. Instead pin that the frame
    -- really drives the shipped code all the way into the loop that refuses:
    assert(J.IsGoingOnSomeone(bot),
        'the labelled mode mutation must put him in the shipped domain')
    local tEnemies = J.GetNearbyHeroes(bot, ULT_CAST_RANGE, true, BOT_MODE_NONE)
    assert(tEnemies ~= nil and #tEnemies == 2,
        'the shipped loop really had two enemies to look at, got '
        .. tostring(tEnemies and #tEnemies))
    local nDesire = X.ConsiderSanitysEclipse()
    assert(nDesire == BOT_ACTION_DESIRE_NONE,
        'and it still bids NONE on both of them, got ' .. tostring(nDesire))
    assert(#names == 0,
        'nothing else picked the frame up either -- the whole ability layer '
        .. 'went quiet, which is exactly what GH #54 measured; got {'
        .. table.concat(names, ',') .. '}')
end

tests['end to end: armed queues Sanity Eclipse at the point covering both'] = function()
    local log, _, _, _, heroes = run_skills(PAIR, true)
    local names = ability_names(log)
    assert(contains(names, ULT_NAME),
        'armed, the area branch must reach the action queue, got {'
        .. table.concat(names, ',') .. '}')
    local vLoc = eclipse_location(log)
    assert(vLoc ~= nil, 'and it must be a LOCATION cast')
    for _, name in ipairs({ 'npc_dota_hero_lich', 'npc_dota_hero_medusa' }) do
        assert(GetUnitToLocationDistance(heroes[name], vLoc) <= ULT_RADIUS,
            name .. ' must be inside the queued circle')
    end
end

tests['end to end: armed leaves the solo frame exactly as shipped'] = function()
    local shipped = ability_names(run_skills(SOLO, false))
    local armed   = ability_names(run_skills(SOLO, true))
    assert(not contains(armed, ULT_NAME), 'armed must not cast on a single enemy')
    assert(#shipped == #armed, 'the whole skill layer is unchanged on this frame')
    for i = 1, #shipped do
        assert(shipped[i] == armed[i],
            'ability ' .. i .. ': shipped ' .. shipped[i] .. ' vs armed ' .. armed[i])
    end
end

-- ------------------------------------------------------- source-level wiring

tests['wiring: the area branch sits BELOW the shipped single-target exit'] = function()
    local f = assert(io.open('bots/BotLib/hero_obsidian_destroyer.lua'))
    local src = f:read('*a')
    f:close()

    local iShippedExit = src:find('return BOT_ACTION_DESIRE_HIGH, enemyHero:GetLocation()', 1, true)
    local iAoeCall     = src:find('local vAoeLoc = X.od_GetEclipseAoeLocation(bot,', 1, true)
    local iConsider    = src:find('function X.ConsiderSanitysEclipse()', 1, true)
    -- the mode check INSIDE ConsiderSanitysEclipse -- other abilities in this
    -- file open with the same line, so the search has to start at the function.
    local iMode        = iConsider and src:find('if J.IsGoingOnSomeone(bot)', iConsider, true)
    assert(iShippedExit and iAoeCall and iConsider and iMode, 'all four landmarks exist')
    assert(iAoeCall > iShippedExit,
        'the area branch must never pre-empt a decision the shipped loop makes')
    assert(iMode > iConsider and iAoeCall > iMode,
        'and it must stay INSIDE the shipped J.IsGoingOnSomeone domain (one lever)')
end

tests['wiring: exactly one gate call, behind the odaoe id, turbo-only'] = function()
    local f = assert(io.open('bots/BotLib/hero_obsidian_destroyer.lua'))
    local src = f:read('*a')
    f:close()
    assert(src:find("if not (J.IsModeTurbo() and J.IsSoakCandidate('odaoe')) then return nil end", 1, true),
        'the helper must open with the turbo + candidate gate')
    local _, nIds = src:gsub("J%.IsSoakCandidate%('odaoe'%)", '')
    assert(nIds == 1, 'exactly ONE gate call behind ONE id, found ' .. nIds)
    assert(src:find("SanitysEclipse:GetSpecialValueInt('radius')", 1, true),
        'the radius must come from the ability, not from a literal in the branch')
    -- Deliberately untestable: candidate centres are convex combinations of
    -- points the engine reported inside nCastRange, so no frame can make this
    -- guard's false side happen. Mutating it away therefore breaks no case --
    -- hence this tripwire rather than a silent unreachable branch.
    assert(src:find('if GetUnitToLocationDistance(hBot, vLoc) <= nCastRange', 1, true),
        'the chosen point must still be bounded by the cast range')
end

return tests

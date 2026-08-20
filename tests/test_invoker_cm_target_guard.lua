-- [GH #50 §2] hero_invoker.lua's `J.Unit.IsUnitWithName(...)` -- the second of
-- the two undefined-J references the director's #48 sweep found, and the one it
-- recorded as a real crash with a live call site.
--
-- It is not one. This file measures that instead of arguing it.
--
--   X.ConsiderCmToTarget(target, ...):
--       if (J.IsValidHero(target)
--           or (J.IsValidTarget(target) and (J.Unit.IsUnitWithName(target, "roshan")
--                                         or J.Unit.IsUnitWithName(target, "boss"))))
--
-- `J.Unit` is assigned nowhere in the tree, so reaching it is
-- "attempt to index field 'Unit' (a nil value)" -- and nothing pcalls
-- X.SkillsComplement (ability_item_usage_generic.lua:8520 calls it bare from
-- AbilityUsageThink), so it would take out Invoker's whole ability layer for
-- that frame, invisibly. The question is only whether anything reaches it.
--
-- Nothing does, for a reason that is structural rather than statistical:
--
--   jmz_func.lua:2992  function J.IsValidTarget(nTarget) return J.Utils.IsValidHero(nTarget) end
--   jmz_func.lua:2997  function J.IsValidHero(nTarget)   return J.Utils.IsValidHero(nTarget) end
--
-- They are the SAME delegate. So the guard is `A or (A and X)`, which is `A`:
-- Lua evaluates the right side of the `or` only when A is false, and then the
-- `and` short-circuits on that same false A before ever indexing `J.Unit`. No
-- target of any kind can reach it -- a hero takes the left disjunct, a
-- non-hero fails both conjuncts. The two call sites say the same thing from
-- the other end: one iterates UNIT_LIST_ENEMY_HEROES, the other guards on
-- J.IsValidTarget(botTarget). Roshan and the tormentor never arrive.
--
-- Two consequences worth keeping apart:
--
--   1. THE FIX IS INERT, and is worth making anyway. jmz_func.lua:2992 carries
--      its author's own NOTE -- "ideally it should be IsValidUnit, but a lot of
--      legacy usage causing some problems" -- i.e. a one-line edit somebody is
--      already contemplating arms this branch, and it would go live as a raised
--      error. The rename disarms that. Post-#51 the renamed call is also
--      forward-CORRECT (substring test, not the constant `true` it used to be),
--      which is pinned below in the world that edit would create.
--   2. THE INTENT IS UNIMPLEMENTED. "can be roshan or others" describes a
--      meteor on Roshan/the tormentor that has never once been cast, and giving
--      it to Invoker needs a call site, not a rename. Deliberately NOT done
--      here: Invoker is not a focus hero and that is a behavior change, which
--      under the charter ships gated with its own frames. Recorded in the
--      report instead.
--
-- REAL FRAME. 20260720_080225_slot1 @ t=47.0 -- the fixture already in the
-- library (no new replay pulled). Every hero, position, HP and mana below is
-- dump data, and X.ConsiderCmToTarget is driven for real, not reconstructed:
-- on this frame it returns a genuine HIGH bid for two of the ten heroes, which
-- is what stops "IsUnitWithName was called 0 times" from being the vacuous
-- kind of zero.
--
-- WHAT IS SYNTHETIC, and why it has to be: the behavioral dumper emits HEROES
-- ONLY (tools/batch_test/behavioral/dumper/main.go), so no archived frame
-- contains a Roshan, a tormentor or a creep -- the same structural gap as
-- GH #27 / #43 / #53. GH #50's suggested acceptance ("assert both ways on a
-- target-is-Roshan frame and a target-is-a-creep frame") is therefore not
-- constructible today. The non-hero units here are mock units, labelled as
-- such at every use; they carry exactly the four fields IsValidHero reads
-- (IsNull / CanBeSeen / IsAlive / IsInvulnerable) plus IsHero and a name.
-- Nothing about the unreachability claim rests on them: it is proved on the
-- ten real heroes, and they only extend it to the class that cannot be dumped.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local FRAME = 'tests/fixtures/f_080225_wk_lane.lua'
local INVOKER_SRC = 'bots/BotLib/hero_invoker.lua'
local JMZ_SRC = 'bots/FunLib/jmz_func.lua'

-- ConsiderCmToTarget's real arguments, as X.ConsiderChaosMeteor passes them:
-- (target, nDelay, nTravelDistance, nRadius).
local N_DELAY, N_TRAVEL, N_RADIUS = 0.0, 1200, 275

--- The guard expression exactly as it read BEFORE the fix, J.Unit left nil.
--- Kept honest by the source tripwires at the bottom, which pin that the real
--- line still has this shape (same operands, same order, same short-circuits).
local function guard_before(J, target)
    return (J.IsValidHero(target)
        or (J.IsValidTarget(target) and (J.Unit.IsUnitWithName(target, "roshan")
            or J.Unit.IsUnitWithName(target, "boss"))))
end

--- The same expression AFTER the fix.
local function guard_after(J, target)
    return (J.IsValidHero(target)
        or (J.IsValidTarget(target) and (J.Utils.IsUnitWithName(target, "roshan")
            or J.Utils.IsUnitWithName(target, "boss"))))
end

--- A non-hero unit. Mock, necessarily -- see the header. Only the fields
--- Utils.IsValidHero actually reads, so a change in what it reads shows up as
--- a nil default rather than as a quietly wrong answer.
local function make_non_hero(sName)
    return api.MakeUnit{
        GetUnitName = sName,
        IsNull = false, CanBeSeen = true, IsAlive = true, IsInvulnerable = false,
        IsHero = false,
        GetTeam = 3, -- TEAM_DIRE, opposite the subject
    }
end

local function read(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function load_frame()
    local J, bot, heroes, fx = rf.load(FRAME)
    local X = rf.load_hero('invoker')
    return J, bot, heroes, fx, X
end

--- Count every call that reaches Utils.IsUnitWithName, from anywhere. Returns
--- the counter and a restore function. Instruments the shared utils table, so
--- both `J.Utils.X` and hero_invoker's own `local Utils = require(...)` alias
--- land in the same counter.
local function count_name_tests(J)
    local n = 0
    local original = J.Utils.IsUnitWithName
    J.Utils.IsUnitWithName = function(...)
        n = n + 1
        return original(...)
    end
    return function() return n end, function() J.Utils.IsUnitWithName = original end
end

local tests = {}

tests['[GH #50] ground truth: the real frame and its ten heroes'] = function()
    local _, _, heroes, fx = load_frame()
    assert(fx.self == 'npc_dota_hero_skeleton_king', 'subject is the dumped slot')
    assert(fx.time == 47.0, 'decision instant, 0:47')

    local n = 0
    for _ in pairs(heroes) do n = n + 1 end
    assert(n == 10, 'the frame carries all ten heroes, found ' .. n)
    assert(heroes['npc_dota_hero_pudge'] ~= nil)
    assert(heroes['npc_dota_hero_shadow_shaman'] ~= nil)
end

-- The claim the whole file rests on, asserted on real units rather than read
-- off the source.
tests['[GH #50] J.IsValidTarget and J.IsValidHero agree on every unit on the frame'] = function()
    local J, _, heroes = load_frame()
    for sName, hUnit in pairs(heroes) do
        assert(J.IsValidTarget(hUnit) == J.IsValidHero(hUnit),
            'the two predicates must be the same answer for ' .. sName
            .. ' -- if they can differ, the unreachability proof is void')
    end
    -- ...and on the classes the dumper cannot produce.
    for _, sName in ipairs({ 'npc_dota_roshan', 'npc_dota_miniboss',
                             'npc_dota_creep_badguys_melee' }) do
        local hUnit = make_non_hero(sName)
        assert(J.IsValidHero(hUnit) == false, sName .. ' is not a valid hero')
        assert(J.IsValidTarget(hUnit) == false,
            sName .. ' is not a valid TARGET either -- that identity is the '
            .. 'reason the roshan/boss branch is dead')
    end
end

tests['[GH #50] source: both predicates still delegate to the same function'] = function()
    local src = read(JMZ_SRC)
    local sTarget = src:match('function J%.IsValidTarget%b()%s*(.-)\nend')
    local sHero = src:match('function J%.IsValidHero%b()%s*(.-)\nend')
    assert(sTarget and sHero, 'both helpers must still be defined in ' .. JMZ_SRC)
    assert(sTarget:find('J%.Utils%.IsValidHero'),
        'J.IsValidTarget must still delegate to J.Utils.IsValidHero. If this '
        .. 'changed -- the NOTE on that function contemplates IsValidUnit -- '
        .. 'then hero_invoker.lua ConsiderCmToTarget\'s roshan/boss branch has '
        .. 'just gone LIVE, and it needs a real behavior decision, not a rename.')
    assert(sHero:find('J%.Utils%.IsValidHero'),
        'J.IsValidHero must still delegate to J.Utils.IsValidHero')
end

-- The behavioral half: drive the real function, count what it asks.
tests['[GH #50] the real ConsiderCmToTarget never reaches the name test'] = function()
    local J, _, heroes, _, X = load_frame()
    local count, restore = count_name_tests(J)

    for sName, hUnit in pairs(heroes) do
        local ok, err = pcall(X.ConsiderCmToTarget, hUnit, N_DELAY, N_TRAVEL, N_RADIUS)
        assert(ok, 'ConsiderCmToTarget raised on real hero ' .. sName
            .. ': ' .. tostring(err))
    end
    for _, sName in ipairs({ 'npc_dota_roshan', 'npc_dota_miniboss',
                             'npc_dota_creep_badguys_melee' }) do
        local ok, err = pcall(X.ConsiderCmToTarget, make_non_hero(sName),
            N_DELAY, N_TRAVEL, N_RADIUS)
        assert(ok, 'ConsiderCmToTarget raised on ' .. sName .. ': ' .. tostring(err))
    end

    local n = count()
    restore()
    assert(n == 0, 'the roshan/boss name test must be unreachable, it ran '
        .. n .. ' time(s) -- if this fires, the branch is live and the fix is '
        .. 'no longer inert')
end

-- Without this the zero above would also be what a function that returns on
-- line 1 produces.
tests['[GH #50] non-vacuity: the same drive produces real HIGH bids'] = function()
    local _, _, heroes, _, X = load_frame()
    local tDesire = {}
    for sName, hUnit in pairs(heroes) do
        tDesire[sName] = X.ConsiderCmToTarget(hUnit, N_DELAY, N_TRAVEL, N_RADIUS)
    end
    -- Two of the ten clear the whole guard chain and bid on this frame.
    assert(tDesire['npc_dota_hero_pudge'] == BOT_ACTION_DESIRE_HIGH,
        'pudge must draw a HIGH meteor bid on this frame, got '
        .. tostring(tDesire['npc_dota_hero_pudge']))
    assert(tDesire['npc_dota_hero_shadow_shaman'] == BOT_ACTION_DESIRE_HIGH,
        'shadow_shaman must draw a HIGH meteor bid on this frame, got '
        .. tostring(tDesire['npc_dota_hero_shadow_shaman']))
    -- ...and the guard is a guard, not a rubber stamp.
    assert(tDesire['npc_dota_hero_juggernaut'] == BOT_ACTION_DESIRE_NONE,
        'juggernaut must not bid on this frame')
end

tests['[GH #50] a non-hero target draws no bid at all (the intent is unimplemented)'] = function()
    local _, _, _, _, X = load_frame()
    for _, sName in ipairs({ 'npc_dota_roshan', 'npc_dota_miniboss' }) do
        assert(X.ConsiderCmToTarget(make_non_hero(sName), N_DELAY, N_TRAVEL, N_RADIUS)
            == BOT_ACTION_DESIRE_NONE,
            sName .. ' must draw no meteor bid -- the "can be roshan or others" '
            .. 'comment describes an intent that has never been implemented')
    end
end

-- What #50 recorded: a live crash. Reconstructed on the real frame, both ways.
tests['[GH #50] the reported crash was unreachable: the pre-fix line never raises'] = function()
    local J, _, heroes = load_frame()
    assert(rawget(J, 'Unit') == nil, 'J.Unit must still be nil -- that is the defect')

    for sName, hUnit in pairs(heroes) do
        local ok, err = pcall(guard_before, J, hUnit)
        assert(ok, 'the PRE-fix expression raised on real hero ' .. sName
            .. ' -- it was supposed to be unreachable: ' .. tostring(err))
    end
    for _, sName in ipairs({ 'npc_dota_roshan', 'npc_dota_miniboss',
                             'npc_dota_creep_badguys_melee' }) do
        local ok = pcall(guard_before, J, make_non_hero(sName))
        assert(ok, 'the PRE-fix expression raised on ' .. sName)
    end
end

-- The positive control for the test above: in the one world where the two
-- predicates disagree, the pre-fix line does exactly what #50 said it would.
-- Without this, "it never raised" would also be what a broken reconstruction
-- prints. This is also, precisely, the world jmz_func.lua:2992's NOTE creates.
tests['[GH #50] positive control: make the predicates disagree and the old line DOES raise'] = function()
    local J, _, _ = load_frame()
    local hRoshan = make_non_hero('npc_dota_roshan')
    local original = J.IsValidTarget
    J.IsValidTarget = function() return true end -- i.e. IsValidUnit, per the NOTE

    local okBefore, errBefore = pcall(guard_before, J, hRoshan)
    local okAfter, valAfter = pcall(guard_after, J, hRoshan)
    J.IsValidTarget = original

    assert(J.IsValidHero(hRoshan) == false,
        'the control must only move IsValidTarget; IsValidHero stays honest')
    assert(okBefore == false, 'the PRE-fix expression must raise once the branch '
        .. 'is reachable -- otherwise this file proves nothing about the fix')
    assert(tostring(errBefore):find("Unit"),
        'the raise must be the reported one (index field \'Unit\'), got: '
        .. tostring(errBefore))
    assert(okAfter == true, 'the POST-fix expression must not raise: '
        .. tostring(valAfter))
    assert(valAfter == true, 'and it must answer true for a unit named roshan')
end

-- Forward-correctness in that same world, which is also a cross-layer tripwire
-- on GH #51: while IsUnitWithName was the constant `true`, the creep case below
-- would pass the guard too.
tests['[GH #50/#51] once reachable, the renamed call answers by name, not always-yes'] = function()
    local J, _, _ = load_frame()
    local original = J.IsValidTarget
    J.IsValidTarget = function() return true end

    local tCase = {
        ['npc_dota_roshan'] = true,
        ['npc_dota_miniboss'] = true, -- contains "boss"
        ['npc_dota_creep_badguys_melee'] = false,
        ['npc_dota_neutral_kobold'] = false,
    }
    local tGot = {}
    for sName in pairs(tCase) do
        tGot[sName] = guard_after(J, make_non_hero(sName))
    end
    J.IsValidTarget = original

    for sName, bWant in pairs(tCase) do
        assert(tGot[sName] == bWant, sName .. ': expected ' .. tostring(bWant)
            .. ', got ' .. tostring(tGot[sName])
            .. ' -- a name test that answers yes for everything is GH #51 back')
    end
end

tests['[GH #50] source: the fixed call site reads J.Utils and keeps its shape'] = function()
    local src = read(INVOKER_SRC)
    assert(not src:find('J%.Unit%.'),
        'no J.Unit reference may survive in ' .. INVOKER_SRC
        .. ' -- J.Unit is nil and the ratchet whitelist entry is deleted')

    local sLine
    for line in src:gmatch('[^\n]+') do
        if line:find('IsUnitWithName') and line:find('roshan') then sLine = line end
    end
    assert(sLine, 'the roshan/boss guard line must still exist')
    assert(sLine:find('J%.Utils%.IsUnitWithName%(target, "roshan"%)')
        and sLine:find('J%.Utils%.IsUnitWithName%(target, "boss"%)'),
        'both name tests must read J.Utils.IsUnitWithName, got:\n  ' .. sLine)
    -- The shape guard_before/guard_after reconstruct: the left disjunct is
    -- IsValidHero and the right conjunct opens with IsValidTarget. If somebody
    -- loosens that first conjunct, this branch is live and the reconstructions
    -- above stop describing the real line.
    assert(sLine:find('J%.IsValidTarget%(target%)'),
        'the right branch must still open with J.IsValidTarget(target):\n  ' .. sLine)
    assert(src:find('if %(J%.IsValidHero%(target%)%s*\n%s*or %(J%.IsValidTarget%(target%)'),
        'the guard must still be `IsValidHero(target) or (IsValidTarget(target) and ...)`')
end

tests['[GH #50] source: both call sites can only hand it a hero'] = function()
    local src = read(INVOKER_SRC)
    -- Call site 1: the enemy-hero sweep.
    assert(src:find('for _, enemyHero in pairs%(GetUnitList%(UNIT_LIST_ENEMY_HEROES%)%)'
        .. '.-X%.ConsiderCmToTarget%(enemyHero'),
        'call site 1 must still iterate UNIT_LIST_ENEMY_HEROES')
    -- Call site 2: the attack target, admitted by the same hero predicate.
    assert(src:find('J%.IsValidTarget%(botTarget%).-X%.ConsiderCmToTarget%(botTarget'),
        'call site 2 must still guard on J.IsValidTarget(botTarget)')
    local n = 0
    for _ in src:gmatch('X%.ConsiderCmToTarget%(') do n = n + 1 end
    assert(n == 3, 'expected one definition and two call sites, found ' .. n
        .. ' occurrences -- a new call site may hand it a non-hero, which makes '
        .. 'the branch live')
end

return tests

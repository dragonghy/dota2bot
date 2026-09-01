-- [ratchet] [immguard] minion_lib/primal_split.lua asks the right question about
-- its attack target -- "is it attack-immune, is it invulnerable?" -- and then
-- throws the answer away, because BOTH arms of that `if` return the same
-- expression:
--
--     if target ~= nil and not target:IsAttackImmune() and not target:IsInvulnerable() then
--         return target
--     end
--
--     return target
--
-- Family: the minion drivers -- the population backlog `0d` never named because
-- it is not reached through mode bidding (GH #378 `illumove`, GH #381
-- `illureal`). Those two rounds fixed branches inside illusions.lua; the
-- leftover both of them wrote down verbatim was "the 4 Action_AttackUnit(x,
-- false) sites in aba_hero_sub_units.lua / primal_split.lua are surveyed, not
-- audited". GH #385 then proved aba_hero_sub_units.lua has ZERO requirers, so
-- primal_split.lua is the whole live remainder. This is that audit.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A two-armed branch whose arms return the SAME EXPRESSION is not a filter.
--     It is a comment that costs a function call.
--     The tell is countable and needs no frame, no run and no reasoning about
--     the predicate: `if C then return E end` immediately followed by
--     `return E`. Repo-wide before this change there were THREE; this fix takes
--     one out of the census by inserting the gate BETWEEN the two arms, and
--     [source S1] pins the remaining two by name and reconstructs the third.
--     ⚠️ AND THE FAILURE DIRECTION IS THE OTHER ONE. Every same-family finding
--     before this fails toward OFF -- #348 order, #368 lexical scope, #370 an
--     unreported side effect, #373 a latch recording the attempt, #378 a
--     throttle wider than what it throttles, #381 a hand-maintained copy of a
--     world fact, #385 a foreign-unit predicate fed `self`. All seven make a
--     branch that should happen not happen, and all seven are invisible because
--     "did not fire" and "was correctly declined" look identical.
--     This one fails OPEN: the guard admits everything, so the wrong answer is
--     a positive act -- an attack order on a unit that cannot be attacked. It
--     is not unobservable. It is merely unobserved, because the only hero that
--     reaches this file is Brewmaster in Primal Split ([source S6], and the
--     honest bound in LIMITS).
--
-- ⭐⭐ WHY IT IS A DEFECT AND NOT A DESIGN CHOICE -- the repo answers this
-- itself, twice, and the second answer is the one that matters:
--   (1) THE SHARED HELPER ALREADY APPLIES EXACTLY THESE TWO CLAUSES. AttackUnits'
--       hero arm calls J.GetWeakestUnit, which is J.GetAttackableWeakestUnitFromList
--       (jmz_func.lua:3748), whose selection condition contains
--       `not unit:IsAttackImmune()` and `not unit:IsInvulnerable()` verbatim
--       (:3764-3765). So `return nil` on an unattackable unit is not this
--       change's invention -- it is what the repo's own picker does, on the
--       very call this function makes. Pinned by [source S5].
--   (2) ...AND THREE LINES LATER THE FUNCTION PUTS BACK WHAT THE HELPER JUST
--       REFUSED. The helper answers nil for "every candidate is unattackable",
--       and line 105 reads that nil as "the helper had no opinion" and assigns
--       `target = enemies[1]` -- the same handle. So the hand-written guard is
--       not a redundant second opinion sitting behind a filtered picker: after
--       the `enemies[1]` fallback it is the ONLY thing between an unattackable
--       unit and the attack order, on EVERY arm, heroes included. Driven on the
--       real frame by [frame F6], where J.GetWeakestUnit answers nil and the
--       shipped tree attacks that exact hero anyway.
--
-- ⭐⭐⭐ WHAT IT COSTS AT THE CALL SITE -- twice, not once. X.MinionThink issues
-- `Action_AttackUnit(target, false)` and RETURNS on whatever AttackUnits hands
-- back (primal_split.lua:65-69). So an unattackable handle buys (a) an order the
-- engine resolves into no damage, and (b) the loss of ConsiderMove, which sits
-- below that return -- and for the FIRE panda ConsiderMove is the entire rest of
-- its behaviour, its own ability branch being an empty `if ... then end`
-- ([source S4]). Twenty seconds of Primal Split spent swinging at a building
-- that cannot be damaged.
--
-- REAL FRAME: tests/fixtures/f_260819_142047_zuus_ult_denied.lua -- game
-- 20260819_142047_slot1, subject zuus (a focus hero), t=278.5 (4:38). Chosen
-- for the geometry, which is dump ground truth and is exactly the geometry that
-- reaches the guard: the subject stands at (63, 89) in mid lane with an ALIVE
-- enemy tower 727u away and NOT ONE enemy hero inside 1600 -- the nearest is
-- 7479u. That is what walks AttackUnits past its hero arm, past its creep arm,
-- past its barracks arm and into the tower arm, which is the unfiltered
-- `enemies[1]` path. Read, not asserted, by [frame F0].
--
-- ⚠️ LIMITS, declared:
--   * THE INSTRUMENT READS ZERO HERE, AND THAT IS MEASURED, NOT ASSUMED
--     ([frame F1]). `IsInvulnerable` and `IsAttackImmune` are on no mock spec,
--     so they fall through tests/mock/bot_api.lua's generic `^Is` default and
--     answer false for every hero and every building on every fixture in the
--     corpus. A .dem slice carries no invulnerability flag, so this is
--     UNMEASURABLE, not EMPTY -- the same distinction as GH #171/#205, #373,
--     #378, and the GetAOERadius zero of GH #386. Consequence, stated plainly:
--     THE CORPUS CANNOT PRICE THIS DOMAIN. How often a Brewmaster panda is in
--     range of an invulnerable structure or a ghosted hero in a real Turbo game
--     is not bought by this file, and that number is the upper bound on the
--     fix's worth.
--   * WHICH MAKES THE POSITIVE CONTROL LOAD-BEARING, not decoration. [frame FC]
--     runs the frame exactly as dumped -- tower vulnerable, nothing declared --
--     and requires BOTH arms to attack it. Without it, every case below could
--     pass because the guard was never reached at all: that is precisely the
--     self-inflicted wound of GH #385's first [frame F1], where a shut gate
--     four conditions upstream made a NONE reading look like a verdict.
--   * SO INVULNERABILITY IS A DECLARED WORLD SLOT (S-A), set on a REAL building
--     handle carried by the fixture with its real team, position and alive
--     flag. The frame supplies the world that reaches the guard; the flag the
--     guard reads is stated.
--   * bot:GetNearbyLaneCreeps IS ALSO AN INSTRUMENT ZERO (world slot S-C). The
--     dumper emits no creeps, so the creep arm is empty on every fixture. In a
--     real lane it usually would not be, which makes the tower arm EASIER to
--     reach here than in game. Declared because it moves the domain reading in
--     the flattering direction.
--   * WHAT THIS FIX DOES NOT DO: RE-PICK. Armed, an unattackable candidate
--     yields nil and the tick falls through to ConsiderMove; it does not walk
--     on to the next-weakest attackable unit. That is a strictly larger lever
--     (it would change WHO gets attacked, not just whether a null order is
--     issued) and is left for its own unit. Pinned as a boundary by [frame F3].
--   * NOT FIXED, REGISTERED: the second live instance the same census found,
--     J.GetBestRetreatTree (jmz_func.lua:12109), where `maxDist >
--     bot:GetAttackRange()` is discarded the same way. One lever at a time.
--     Named and counted by [source S1] so it cannot be lost.
--
-- DECLARED WORLD SLOTS:
--   S-A  the target's IsInvulnerable/IsAttackImmune flag (see LIMITS). Set on
--        the fixture's own building handle; identical in both arms.
--   S-B  the attack-immune enemy hero of [frame F6]. Injected, because on this
--        frame every enemy hero is 7479u+ away and a minion is leashed to 1600
--        of its owner (primal_split.lua:84). Identical in both arms.
--   S-C  bot:GetNearbyLaneCreeps() = {} (see LIMITS).

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local TARGET  = 'bots/FunLib/minion_lib/primal_split.lua'
local DRIVER  = 'bots/FunLib/aba_minion.lua'
local UTILS   = 'bots/FunLib/minion_lib/utils.lua'
local JMZ     = 'bots/FunLib/jmz_func.lua'

local GLOBALS = {
    BOT_MODE_NONE          = 0,
    BOT_MODE_DESIRE_NONE   = 0.0,
    BOT_ACTION_DESIRE_NONE = 0.0,
    BOT_ACTION_DESIRE_HIGH = 0.75,
}

--- Blank whole-line comments while PRESERVING line numbers, so every count
--- below means "in code". This file's own fix comment names IsAttackImmune and
--- IsInvulnerable repeatedly; without this the scanners would be counting the
--- explanation instead of the program. GH #370 hit exactly that; GH #381 and
--- #385 copied the fix rather than re-derive it, and so does this.
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local function read(path)
    local fh = assert(io.open(path), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local function count(src, needle)
    return select(2, src:gsub(needle:gsub('%W', '%%%0'), ''))
end

--- Slice a function body by its two NEIGHBOURS rather than by `.-\nend`, which
--- stops at the first NESTED end and silently returns a truncated body -- the
--- method self-harm recorded in GH #373.
local function slice(src, from, to)
    local a = src:find(from, 1, true)
    local b = src:find(to, 1, true)
    assert(a and b and a < b, ('%q must sit above %q'):format(from, to))
    return src:sub(a, b - 1)
end

local function lines(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do out[#out + 1] = line end
    return out
end

local CODE  = codeOnly(read(TARGET))
local DRIVE = codeOnly(read(DRIVER))
local UCODE = codeOnly(read(UTILS))

--- Every .lua under bots/, read once, comments blanked. Enumerated off the
--- FILESYSTEM (the same way tests/test_smoke_load.lua does it) rather than off
--- any in-tree list, because the population being counted is "files that ship".
local BOTS = (function()
    local out = {}
    local p = assert(io.popen("find bots -name '*.lua' | sort"), 'cannot walk bots/')
    for path in p:lines() do
        out[#out + 1] = { path = path, src = codeOnly(read(path)) }
    end
    p:close()
    assert(#out > 100, 'the walk must find the shipped tree; got ' .. #out)
    return out
end)()

--- THE DISCRIMINATING FEATURE, mechanised: a single-line `if ... then` whose
--- body is one `return E`, closed by `end`, followed (blank lines skipped) by
--- `return E` with a byte-identical E. Deliberately narrow -- it is meant to be
--- a tell anyone can grep for, not a dataflow analysis.
local function sameExpressionGuards(src)
    local L = lines(src)
    local hits = {}
    for i = 1, #L do
        if L[i]:match('^%s*if%s') then
            -- The condition may span lines (it does in two of the three hits),
            -- so walk forward to the `then` that closes it rather than
            -- demanding a one-liner.
            local t = nil
            for k = i, math.min(i + 6, #L) do
                if L[k]:match('then%s*$') then t = k break end
            end
            if t then
                local j = t + 1
                while L[j] and L[j]:match('^%s*$') do j = j + 1 end
                local e1 = L[j] and L[j]:match('^%s*return%s+(.-)%s*$')
                if e1 then
                    local k = j + 1
                    while L[k] and L[k]:match('^%s*$') do k = k + 1 end
                    if L[k] and L[k]:match('^%s*end%s*$') then
                        local m = k + 1
                        while L[m] and L[m]:match('^%s*$') do m = m + 1 end
                        local e2 = L[m] and L[m]:match('^%s*return%s+(.-)%s*$')
                        if e2 and e1 == e2 then hits[#hits + 1] = { line = i, expr = e1 } end
                    end
                end
            end
        end
    end
    return hits
end

-- ---------------------------------------------------------------------------
-- [source] -- the shape, read off the shipped tree
-- ---------------------------------------------------------------------------

tests['[source S1] the census: three same-expression guards in bots/, and what each one is'] = function()
    local found = {}
    for _, f in ipairs(BOTS) do
        for _, h in ipairs(sameExpressionGuards(f.src)) do
            found[#found + 1] = { path = f.path, line = h.line, expr = h.expr }
        end
    end
    table.sort(found, function(a, b)
        if a.path ~= b.path then return a.path < b.path end
        return a.line < b.line
    end)

    local names = {}
    for _, h in ipairs(found) do names[#names + 1] = h.path .. ':' .. h.line end

    -- (1) THIS ONE IS GONE FROM THE CENSUS, and that is the ratchet. The guard
    -- itself is untouched -- the gate is inserted BETWEEN its two arms -- so the
    -- shape "if C then return E end / return E" no longer reads off the file
    -- even though gate-shut behaviour is byte-for-byte the shipped behaviour
    -- ([source S3] proves that half by evaluation). Two survivors remain, and
    -- both are named below so "one lever at a time" cannot become "one lever and
    -- a forgotten one".
    assert(#found == 2, 'after the fix exactly 2 same-expression guards must remain in '
        .. 'bots/ (this file was the third); got ' .. #found .. ' -- '
        .. table.concat(names, ', '))

    local byPath = {}
    for _, h in ipairs(found) do byPath[h.path] = h end
    assert(byPath[TARGET] == nil,
        'primal_split.lua must NO LONGER match the shape -- if it does, the gate is not '
        .. 'sitting between the two arms')

    -- ...and it WAS the third: strip the two gate lines back out and the shape
    -- returns, at the guard, returning `target` from both arms. This is the
    -- before-picture, reconstructed rather than remembered.
    local before = CODE
        :gsub("\tif J%.IsModeTurbo%(%) and J%.IsSoakCandidate%('immguard'%) then\n\t\treturn nil\n\tend\n", '')
    assert(before ~= CODE, 'the reconstruction must actually remove the gate')
    local was = sameExpressionGuards(before)
    assert(#was == 1 and was[1].expr == 'target',
        'without the gate, primal_split.lua must show exactly one same-expression guard '
        .. 'returning `target` -- the defect this file fixes; got ' .. #was)

    -- (2) A WHOLE-FUNCTION STUB, not this defect. X.ConsiderEchantRemnant is
    -- NONE either way: its guard is vacuous because the FUNCTION is, so there
    -- is no discarded answer and nothing to restore.
    local es = byPath['bots/BotLib/hero_earth_spirit.lua']
    assert(es ~= nil, 'the earth spirit stub must still be in the census -- if it vanished '
        .. 'the scanner changed, not the tree')
    assert(es.expr == 'BOT_ACTION_DESIRE_NONE, nil',
        'the stub returns NONE from both arms; got ' .. es.expr)

    -- (3) THE SIBLING, REGISTERED AND NOT FIXED. Same shape, live code, one
    -- caller (hero_shredder.lua). Named here so one lever at a time cannot turn
    -- into one lever and a forgotten one.
    local sib = byPath[JMZ]
    assert(sib ~= nil, 'J.GetBestRetreatTree must still be in the census -- it is the '
        .. 'registered-but-unfixed second instance')
    assert(sib.expr == 'bestRetreatTree', 'the sibling returns the tree from both arms; got '
        .. sib.expr)
end

tests['[source S2] the shipped guard cannot filter -- proved by evaluation, not by reading'] = function()
    -- Both arms of the shipped shape, modelled exactly, over the four input
    -- classes the guard distinguishes. Identical for all four is the defect.
    local function shipped(target)
        if target ~= nil and not target:IsAttackImmune() and not target:IsInvulnerable() then
            return target
        end
        return target
    end

    local plain  = { IsAttackImmune = function() return false end, IsInvulnerable = function() return false end }
    local immune = { IsAttackImmune = function() return true  end, IsInvulnerable = function() return false end }
    local invuln = { IsAttackImmune = function() return false end, IsInvulnerable = function() return true  end }

    assert(shipped(nil) == nil, 'nil in, nil out')
    assert(shipped(plain) == plain, 'an attackable target comes back')
    assert(shipped(immune) == immune, 'THE DEFECT: so does an attack-immune one')
    assert(shipped(invuln) == invuln, 'THE DEFECT: so does an invulnerable one')

    -- The whole condition is dead weight: deleting it changes no output.
    local function withoutTheGuard(target) return target end
    for _, t in ipairs({ plain, immune, invuln }) do
        assert(shipped(t) == withoutTheGuard(t),
            'the guard must be provably equivalent to not being there at all')
    end
end

tests['[source S3] the gate sits between the two arms, is turbo-only, and is named immguard'] = function()
    local body = slice(CODE, 'function AttackUnits(', 'function UseDispelMagic(')

    assert(count(body, 'return target') == 3,
        'all three shipped `return target` statements must survive -- the leash early-out '
        .. 'at :86 and the guard pair; got ' .. count(body, 'return target'))
    assert(count(body, 'return nil') == 1, 'exactly one armed early-out')

    local a = body:find('not target:IsInvulnerable()', 1, true)
    local g = body:find('IsSoakCandidate', 1, true)
    local z = body:find('return target', g or 1, true)
    assert(a and g and z and a < g and g < z,
        'the gate must sit BELOW the shipped guard and ABOVE the shipped fallthrough -- '
        .. 'anywhere else and gate-shut is no longer the shipped path')

    assert(body:find("J.IsModeTurbo() and J.IsSoakCandidate('immguard')", 1, true) ~= nil,
        'the gate must be turbo-only and carry the id immguard')

    -- ...and gate shut really is a fallthrough, by evaluation.
    local function gated(target, turbo, armed)
        if target ~= nil and not target:IsAttackImmune() and not target:IsInvulnerable() then
            return target
        end
        if turbo and armed then return nil end
        return target
    end
    local invuln = { IsAttackImmune = function() return false end, IsInvulnerable = function() return true end }
    assert(gated(invuln, false, false) == invuln, 'gate shut = shipped')
    assert(gated(invuln, true,  false) == invuln, 'turbo alone is not arming')
    assert(gated(invuln, false, true)  == invuln, 'the id alone is not arming -- turbo-only')
    assert(gated(invuln, true,  true)  == nil,    'armed in turbo is the only arm that filters')
end

tests['[source S4] the call site pays twice: a null order, and ConsiderMove never runs'] = function()
    local think = slice(CODE, 'function X.MinionThink(', 'function AttackUnits(')

    assert(count(think, 'AttackUnits(hMinionUnit)') == 1, 'exactly one call into AttackUnits')
    assert(think:find('hMinionUnit:Action_AttackUnit(target, false)', 1, true) ~= nil,
        'the order is issued directly on whatever AttackUnits returns -- no second filter')

    -- The attack block returns, and ConsiderMove is BELOW it. That ordering is
    -- the second half of the cost.
    local atk = think:find('Action_AttackUnit(target, false)', 1, true)
    local mov = think:find('ConsiderMove(hMinionUnit)', 1, true)
    assert(atk and mov and atk < mov,
        'ConsiderMove must sit below the attack return, or the "loses the tick" claim is false')

    -- The fire panda's own ability branch is an EMPTY if -- so AttackUnits plus
    -- ConsiderMove is the whole of its behaviour.
    local fire = think:find('npc_dota_brewmaster_fire', 1, true)
    assert(fire ~= nil, 'the fire panda branch must exist')
    local tail = think:sub(fire)
    local nextIf = tail:find('\n%s*if%s') or #tail
    assert(tail:sub(1, nextIf):find('Action_', 1, true) == nil,
        'the fire panda branch must remain empty of orders -- that is why the generic '
        .. 'attack/move tail is its entire Think')
end

tests['[source S5] the repo already filters exactly this, on the very call AttackUnits makes'] = function()
    local jmz = codeOnly(read(JMZ))

    local picker = slice(jmz, 'function J.GetAttackableWeakestUnitFromList(', 'function J.CannotBeKilled(')
    assert(picker:find('not unit:IsAttackImmune()', 1, true) ~= nil,
        'the shared picker must reject attack-immune units')
    assert(picker:find('not unit:IsInvulnerable()', 1, true) ~= nil,
        'the shared picker must reject invulnerable units')

    local weakest = slice(jmz, 'function J.GetWeakestUnit(', 'function J.HasInvisibilityOrItem(')
    assert(weakest:find('J.GetAttackableWeakestUnitFromList(', 1, true) ~= nil,
        'J.GetWeakestUnit must delegate to that picker -- otherwise the precedent is not '
        .. 'on the call AttackUnits actually makes')

    local body = slice(CODE, 'function AttackUnits(', 'function UseDispelMagic(')
    assert(count(body, 'J.GetWeakestUnit(enemies)') == 1,
        'the hero arm must go through the filtered picker')

    -- ...AND the fallback puts back what the picker refused. This is the line
    -- that makes the hand-written guard load-bearing on every arm, not just on
    -- the structure ones.
    assert(body:find('target == nil and enemies ~= nil and #enemies >= 1', 1, true) ~= nil,
        'the enemies[1] fallback must still read the picker nil as "no opinion"')
    assert(count(body, 'target = enemies[1]') == 1, 'and hand back the raw first element')
end

tests['[source S6] the routing is real: four brewmaster units, one dispatcher, one hero'] = function()
    local isSplit = UCODE:sub((UCODE:find('function U.IsPrimalSplit(', 1, true)))
    for _, unit in ipairs({ 'npc_dota_brewmaster_earth', 'npc_dota_brewmaster_storm',
                            'npc_dota_brewmaster_fire',  'npc_dota_brewmaster_void' }) do
        assert(isSplit:find(unit, 1, true) ~= nil, 'U.IsPrimalSplit must name ' .. unit)
    end

    assert(count(DRIVE, 'PrimalSplit.MinionThink(bot, hMinionUnit)') == 1,
        'exactly one call expression into this module')
    assert(DRIVE:find('U.IsPrimalSplit(hMinionUnit)', 1, true) ~= nil,
        'and it is guarded by the unit-name predicate above')

    -- The population, stated: this file is reached by Brewmaster's ultimate and
    -- by nothing else. That is the honest bound on the fix's frequency.
    local brew = codeOnly(read('bots/BotLib/hero_brewmaster.lua'))
    assert(brew:find('brewmaster_primal_split', 1, true) ~= nil,
        'hero_brewmaster.lua must ship the ability that creates this population')
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

local function world(armed, opts)
    opts = opts or {}
    local J, bot = rf.load(FIXTURE)
    for k, v in pairs(GLOBALS) do _G[k] = v end

    J.IsSoakCandidate = function(id) return armed and id == 'immguard' end
    J.IsModeTurbo     = function() return opts.turbo ~= false end

    local here = bot:GetLocation()
    local botspec = rawget(bot, '__spec')

    -- The real tower this frame carries: real team, real position, real alive
    -- flag, real distance. S-A only states its invulnerability.
    local tower = bot:GetNearbyTowers(1600, true)[1]
    assert(tower ~= nil, 'the frame must put an enemy tower inside 1600')
    if opts.invulnerable then rawget(tower, '__spec').IsInvulnerable = true end

    -- S-B: the ghosted enemy hero of [frame F6]. Only built when asked for.
    local ghost = api.MakeUnit({
        GetUnitName             = 'npc_dota_hero_lina',
        GetTeam                 = 3,
        GetPlayerID             = 7,
        IsHero                  = true,
        IsAlive                 = true,
        IsNull                  = false,
        CanBeSeen               = true,
        IsAttackImmune          = true,
        GetHealth               = 120,
        GetMaxHealth            = 670,
        GetCurrentMovementSpeed = 300,
        GetLocation             = api.Vector(here.x + 400, here.y, here.z),
    })

    local log = {}
    local minion = api.MakeUnit({
        GetUnitName             = 'npc_dota_brewmaster_fire',
        GetTeam                 = bot:GetTeam(),
        GetPlayerID             = -1,
        IsAlive                 = true,
        IsNull                  = false,
        CanBeSeen               = true,
        GetHealth               = 900,
        GetMaxHealth            = 900,
        OriginalGetHealth       = 900,
        OriginalGetMaxHealth    = 900,
        GetCurrentMovementSpeed = 300,
        GetAttackRange          = 150,
        GetAttackDamage         = 50,
        GetLocation             = api.Vector(here.x, here.y, here.z),
        GetNearbyTowers         = botspec.GetNearbyTowers,
        GetNearbyBarracks       = botspec.GetNearbyBarracks,
        GetNearbyHeroes         = opts.ghost and function() return { ghost } end
                                              or botspec.GetNearbyHeroes,
        Action_AttackUnit       = function(_, u) log[#log + 1] = 'attack:' .. u:GetUnitName() end,
        Action_MoveToLocation   = function() log[#log + 1] = 'move' end,
        Action_AttackMove       = function() log[#log + 1] = 'attackmove' end,
    })

    local PrimalSplit = dofile(TARGET)
    return {
        J = J, bot = bot, tower = tower, ghost = ghost, minion = minion, log = log,
        think = function() PrimalSplit.MinionThink(bot, minion) return table.concat(log, ',') end,
    }
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real frame
-- ---------------------------------------------------------------------------

tests['[frame F0] the geometry that reaches the guard is dump ground truth, read not asserted'] = function()
    local w = world(false)
    assert(w.bot:GetUnitName() == 'npc_dota_hero_zuus',
        'subject must be zuus; got ' .. tostring(w.bot:GetUnitName()))

    -- The tower arm is reached because the two arms above it are genuinely
    -- empty on this frame, and the tower is genuinely there.
    assert(#w.bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE) == 0,
        'the hero arm must be empty FOR REAL on this frame')
    local nearest = math.huge
    for _, h in ipairs(w.J.GetEnemiesNearLoc(w.bot:GetLocation(), 12000)) do
        nearest = math.min(nearest, GetUnitToUnitDistance(w.bot, h))
    end
    assert(nearest > 7000, 'and empty because the enemy team is genuinely far -- nearest '
        .. 'enemy hero should be 7479u; got ' .. tostring(math.floor(nearest)))

    assert(#w.bot:GetNearbyBarracks(1600, true) == 0, 'no barracks inside 1600')
    assert(w.tower:IsAlive() == true, 'the tower must be alive')
    assert(w.tower:GetTeam() ~= w.bot:GetTeam(), 'and hostile')
    local d = GetUnitToUnitDistance(w.bot, w.tower)
    assert(d > 700 and d < 760, 'sanity: 727u on this frame; got ' .. tostring(math.floor(d)))
end

tests['[frame F1] the instrument reads zero here -- measured, and it is why S-A is declared'] = function()
    local w = world(false)
    local seen, positive = 0, 0
    for _, h in ipairs(GetUnitList(UNIT_LIST_ALL)) do
        seen = seen + 1
        if h:IsInvulnerable() or h:IsAttackImmune() then positive = positive + 1 end
    end
    for _, side in ipairs({ UNIT_LIST_ALLIED_BUILDINGS, UNIT_LIST_ENEMY_BUILDINGS }) do
        for _, h in ipairs(GetUnitList(side)) do
            seen = seen + 1
            if h:IsInvulnerable() or h:IsAttackImmune() then positive = positive + 1 end
        end
    end
    assert(seen > 20, 'the sweep must actually see the frame; got ' .. seen .. ' handles')
    assert(positive == 0, 'THE POINT: ' .. seen .. ' handles on this frame, ' .. positive
        .. ' unattackable. A .dem carries no invulnerability flag, so this is UNMEASURABLE, '
        .. 'not EMPTY -- the corpus cannot price this domain and S-A must be stated.')

    -- ...which also means the shipped guard's negative arm is unreachable on an
    -- undeclared fixture. Anything below that "passed" without S-A would be
    -- passing because the guard was never reached.
    assert(w.tower:IsInvulnerable() == false, 'and the tower is one of those zeros')
end

tests['[frame FC] POSITIVE CONTROL: the frame as dumped -- both arms attack the tower'] = function()
    -- No world slot set. If this case ever goes quiet, every case below is
    -- worthless: it would mean the harness stopped reaching the guard at all.
    local shipped = world(false).think()
    local armed   = world(true).think()
    assert(shipped == 'attack:tower',
        'shipped must order the attack on the real tower; got ' .. shipped)
    assert(armed == 'attack:tower',
        'and ARMING MUST NOT FIRE SPURIOUSLY: a vulnerable target is still attacked; got '
        .. armed)
end

tests['[frame F2] SHIPPED: an unattackable tower is attacked, and ConsiderMove never runs'] = function()
    local w = world(false, { invulnerable = true })
    assert(w.tower:IsInvulnerable() == true, 'precondition: world slot S-A is set')
    local out = w.think()
    assert(out == 'attack:tower', 'THE DEFECT: the guard asked the right question and the '
        .. 'answer was discarded, so the order goes out anyway; got ' .. out)
    assert(out:find('move', 1, true) == nil,
        'and the tick is lost twice -- MinionThink returns above ConsiderMove')
end

tests['[frame F3] ARMED: the same frame yields a real order instead of a null one'] = function()
    local w = world(true, { invulnerable = true })
    local out = w.think()
    assert(out == 'move', 'armed, the negative arm finally filters and the panda reaches '
        .. 'ConsiderMove; got ' .. out)
    -- The declared boundary: armed does NOT re-pick a different attack target.
    assert(out:find('attack', 1, true) == nil,
        'this fix removes a null order; it does not choose a new victim (see LIMITS)')
end

tests['[frame F4] gate shut is the shipped behaviour on this frame, in both worlds'] = function()
    local dumped   = world(false).think()
    local declared = world(false, { invulnerable = true }).think()
    assert(dumped == 'attack:tower' and declared == 'attack:tower',
        'with the gate shut the two worlds are indistinguishable -- exactly the shipped '
        .. 'defect; got ' .. dumped .. ' / ' .. declared)
end

tests['[frame F5] turbo-only: arming immguard outside Turbo changes nothing'] = function()
    local out = world(true, { invulnerable = true, turbo = false }).think()
    assert(out == 'attack:tower',
        'the id alone must not arm -- the gate is J.IsModeTurbo() AND the candidate; got '
        .. out)
end

tests['[frame F6] the hero arm is broken too: the picker refuses, enemies[1] puts it back'] = function()
    local w = world(false, { ghost = true })
    assert(w.J.GetWeakestUnit({ w.ghost }) == nil,
        'precondition and the whole point of [source S5]: the shared picker REFUSES an '
        .. 'attack-immune hero')
    local shipped = w.think()
    assert(shipped == 'attack:npc_dota_hero_lina',
        'THE DEFECT, second face: AttackUnits attacks the exact unit the picker just '
        .. 'refused, because the enemies[1] fallback reads nil as "no opinion"; got ' .. shipped)

    local armed = world(true, { ghost = true }).think()
    assert(armed == 'move',
        'armed, the hand-written guard agrees with the shared picker again; got ' .. armed)
end

-- NOT PINNED -- surviving mutants, declared with their reasons.
--   * `not target:IsAttackImmune()` and `not target:IsInvulnerable()` are not
--     separable by [frame F2]/[frame F3] alone (the tower sets only the second).
--     [frame F6] sets only the first, so between them each clause has a witness;
--     a mutant that deletes BOTH is caught by either. A mutant that swaps one
--     for the other is NOT caught, and cannot be without a frame carrying a
--     handle that is one and not the other for real -- which [frame F1] shows
--     the corpus does not have.
--   * The 1600 radii in AttackUnits are untouched by this change and unpinned;
--     pinning them would assert shipped tuning values this fix has no opinion
--     about.
--   * `GetUnitToUnitDistance(hMinionUnit, bot) > 1600` (the leash at :84) reads
--     false here because the minion is placed at the owner's own position, so a
--     mutant that widens it is EQUIVALENT on this frame. Declared before the
--     stand was run.

return tests

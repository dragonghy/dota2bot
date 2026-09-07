-- [hero] `liondrainmi` -- the WIDENING half of the question GH #566 left open.
--
-- WHAT THIS ROUND TOOK, AND WHAT IT DELIBERATELY DID NOT
-- ------------------------------------------------------
-- bots/BotLib/hero_lion.lua X.ConsiderE picks a Mana Drain target at three
-- places.  GH #566 retired the reading that the PERMISSIVE one was wrong.  The
-- opposite reading -- that the STRICT ones are -- is a separate, WIDENING lever,
-- and the three sites are not three instances of one question:
--
--   mana-refill loop   `J.CanCastOnNonMagicImmune( nCreep )`     <- a CREEP
--   团战吸蓝 branch     `J.CanCastOnMagicImmune( npcEnemy )`      <- an enemy hero
--   打架抽蓝 branch     `J.CanCastOnNonMagicImmune( botTarget )`  <- an enemy hero
--
-- The two hero sites pick the SAME KIND of target under the same conditions (an
-- enemy hero, in combat, inside cast range, >200 mana, no Finger on them) and
-- answer differently.  That is this round's lever, and only that one.  The
-- creep loop is a different domain with a different base rate; it is untouched,
-- and section 4 asserts it is still untouched so "not taken" cannot decay into
-- "taken quietly".
--
-- WHY THE PERMISSIVE SIDE IS THE ONE WITH EVIDENCE.  GH #566's three legs
-- (order accepted 7.1s into the immunity; channel nested inside the immunity
-- for its full 5.1s; mana measurably moving, +157 against a +8/s baseline) are
-- readings about `lion_mana_drain` AS AN ABILITY.  None of them is about which
-- `if` block issued the order.  So they carry to this branch -- which is what
-- makes this a lever rather than a guess -- and they carry no further than
-- that: they say the engine accepts the cast, NOT that casting it is good here.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANYTHING FROM HERE
-- --------------------------------------------------------
--   * THE BRANCH IS NOT REACHABLE ON ANY FRAME IN THIS TREE, and section 3
--     MEASURES that rather than asserting around it.  `botTarget` comes from
--     J.GetProperTarget -> GetTarget()/GetAttackTarget(), and the dumper's
--     snapshot schema has no target channel at all, so this generator cannot
--     produce a reachable frame (the same schema gap GH #577's branch (ii) hit;
--     re-measured here rather than quoted).  What the real frame therefore pins
--     is THE DECISION -- the target test, on the real spell-immune unit -- not
--     the branch.  Those are two different claims and this file keeps them
--     apart.
--   * THE MOCK DOES NOT INSTALL THE SHIPPED IsMagicImmune OVERRIDE, so a
--     comparison taken without the injection is vacuous.  Section 2 asserts the
--     vacuity FIRST, then injects once, labelled, then asserts the injection
--     changed something -- the same discipline as
--     tests/test_lion_drain_immune_target.lua section 3, and the immunity
--     modifier names are read OUT OF bots/FunLib/aba_global_overrides.lua so a
--     drift in the shipped reader turns this file red instead of stale.
--   * THE DOMAIN IS NOT MEASURED and is NOT GH #566's 16 landings -- those are
--     the 团战吸蓝 branch's.  This branch's EXCLUSIVE domain is "going on
--     someone but NOT in a teamfight", because J.IsInTeamFight makes the
--     sibling branch return first.  Request: queue.json hero-40.
--   * NOTHING HERE IS A PROMOTE ARGUMENT.  `liondrainmi` is unarmed and P4.2
--     freezes new admissions; the lever ships dark.
--
-- Round: hero desk 2026-09-07, backlog -109, owner priority P4.4(i).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_lion.lua'
local OVERRIDES = 'bots/FunLib/aba_global_overrides.lua'
local FIXTURE = 'tests/frames/f_260905_004847_lion_drain_bkb.lua'
local BB = 'npc_dota_hero_bristleback'
local BKB_MOD = 'modifier_black_king_bar_immune'
local CAND = 'liondrainmi'
local HELPER = 'lion_IsDrainCombatTargetCastable'

-- The frames this file drives.  Listed, not globbed: the corpus glob is 109
-- files and rf.load is not free, and a new entry here should be a deliberate
-- edit whose effect on section 5's counts is visible in the diff.  The eight
-- corpus Lion frames (the same list tests/test_lion_drain_immune_target.lua
-- keeps) plus every staged frame, because the staged three are where the tree's
-- only Black-King-Bar immunity lives.
local DRIVEN_FRAMES = {
    'tests/fixtures/f_045650_lion_meatgrinder.lua',
    'tests/fixtures/f_222428_lion_lich_burst.lua',
    'tests/fixtures/f_260819_182323_lion_drain_calm.lua',
    'tests/fixtures/f_260819_182855_lion_drain_jungle.lua',
    'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua',
    'tests/fixtures/f_260819_183409_lion_drain_focused.lua',
    'tests/fixtures/f_260820_162821_lion_drain_lethal.lua',
    'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
    'tests/frames/f_20260831_004433_cm_creepreach.lua',
    'tests/frames/f_260828_002127_axe_call_bkb_ring.lua',
    'tests/frames/f_260828_124358_axe_cull_promise.lua',
    'tests/frames/f_260831_061811_axe_call_tp_channel.lua',
    'tests/frames/f_260905_004847_lion_drain_bkb.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Load a frame with the candidate armed or not.  rf.load's install() forces
--- turbo; `bNonTurbo` undoes it afterwards, exactly as the sibling gate tests
--- do.  `IsSoakCandidate` answers for this id ONLY, so an armed farm string can
--- never leak a second lever into a reading here.
local function world(sPath, bArmed, bNonTurbo)
    local J, bot, heroes, fx = rf.load(sPath)
    J.IsSoakCandidate = function(id) return bArmed and id == CAND end
    if bNonTurbo then GetGameMode = function() return 1 end end
    return J, bot, heroes, fx
end

--- The modifier names the SHIPPED IsMagicImmune override consults, read out of
--- that file rather than retyped, so this test cannot drift away from the
--- reader whose answer it is standing in for.
local function immunity_modifiers()
    local src = read_file(OVERRIDES)
    local from = src:find('function CDOTA_Bot_Script:IsMagicImmune%(%)')
    assert(from, 'the IsMagicImmune override is gone from ' .. OVERRIDES
        .. '; this file was reading its modifier list out of it')
    local rest = src:sub(from)
    local body = rest:sub(1, rest:find('\nend') or #rest)
    local set, n = {}, 0
    for name in body:gmatch("HasModifier%('([%w_]+)'%)") do
        if not set[name] then set[name], n = true, n + 1 end
    end
    assert(n >= 11, 'the shipped override now consults ' .. n
        .. ' modifier names, was 11 -- re-read it before quoting any supply number here')
    return set
end

local function helper_body(src)
    local from = src:find('function%s+X%.' .. HELPER .. '%s*%(')
    assert(from, 'X.' .. HELPER .. ' is not defined in ' .. SRC
        .. ' -- this whole file is about that function')
    local rest = src:sub(from)
    local to = rest:find('\nend')
    assert(to, 'X.' .. HELPER .. ' has no closing end in ' .. SRC)
    return rest:sub(1, to)
end

local function consider_e_body(src)
    local from = src:find('function X%.ConsiderE%s*%(%s*%)')
    assert(from, 'X.ConsiderE not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth: the real frame really carries the situation the lever is about.

tests['ground truth: the frame carries a live, spell-immune enemy hero'] = function()
    local J, bot, heroes, fx = world(FIXTURE, false)
    assert(fx.self == 'npc_dota_hero_lion' and fx.time == 1266.5,
        'the decision instant, got ' .. tostring(fx.self) .. ' @ ' .. tostring(fx.time))
    local bb = assert(heroes[BB], BB .. ' is not on this frame; the fixture is stale')
    assert(bb:GetTeam() ~= bot:GetTeam() and bb:IsAlive(), 'a live ENEMY hero')
    assert(bb:HasModifier(BKB_MOD) == true,
        'the frame really carries the Black King Bar immunity that makes the two '
        .. 'helpers answer differently')
    assert(immunity_modifiers()[BKB_MOD],
        BKB_MOD .. ' is no longer a name the shipped IsMagicImmune reader consults; '
        .. 'this file rests on that mapping')
    -- The other clauses of the branch, so a red here says "the frame stopped
    -- being this branch's situation" rather than "the target test moved".
    assert(bb:GetMana() == 1246, 'clears the >200 mana clause, got ' .. bb:GetMana())
    assert(bb:HasModifier('modifier_lion_finger_of_death') == false, 'not fingered')
    assert(J.IsDisabled(bb) == false, 'not disabled')
    assert(J.CanCastOnTargetAdvanced(bb) == true, 'passes the advanced check')
    assert(GetUnitToUnitDistance(bot, bb) < 850,
        'inside the base 850u cast range, got ' .. math.floor(GetUnitToUnitDistance(bot, bb)))
end

-- ---------------------------------------------------------------- section 2 --
-- THE DECISION, on the real frame's real unit.  One labelled injection.

tests['decision: gate off refuses this target, gate armed accepts it'] = function()
    local J, _, heroes = world(FIXTURE, false)
    local bb = heroes[BB]
    local X = rf.load_hero('lion')

    -- Vacuity, asserted before it could be leaned on: without the injection the
    -- mock answers IsMagicImmune=false from its own spec, so the two helpers are
    -- indistinguishable on this frame and any comparison here proves nothing.
    assert(bb:IsMagicImmune() == false,
        'HARNESS GAP, NOT A CORPUS FACT: if this went red the loader now installs '
        .. 'the shipped reader -- good news; drop the injection below.')
    assert(J.CanCastOnMagicImmune(bb) == J.CanCastOnNonMagicImmune(bb),
        'without the injection the two helpers cannot be told apart on this frame')

    rawget(bb, '__spec').IsMagicImmune = true  -- INJECTION, see HONEST BOUNDS
    assert(bb:IsMagicImmune() == true, 'the injection took')
    assert(J.CanCastOnNonMagicImmune(bb) == false and J.CanCastOnMagicImmune(bb) == true,
        'and it separated the two helpers, which is the only reason it is here')

    assert(X[HELPER](bb) == false,
        'GATE OFF the branch must still refuse this target -- shipped behaviour is '
        .. 'undrifted, which is the whole promise of a dark lever')
end

tests['decision: armed, the same frame and the same unit are accepted'] = function()
    local _, _, heroes = world(FIXTURE, true)
    local bb = heroes[BB]
    local X = rf.load_hero('lion')
    rawget(bb, '__spec').IsMagicImmune = true  -- INJECTION, see HONEST BOUNDS
    assert(X[HELPER](bb) == true,
        'ARMED + turbo the branch must accept the spell-immune enemy its sibling '
        .. 'branch two blocks up already accepts, and that GH #566 measured the '
        .. 'engine accepting for 5.1s on this very frame')
end

tests['decision: armed but NOT turbo is still the shipped answer'] = function()
    local _, _, heroes = world(FIXTURE, true, true)
    local bb = heroes[BB]
    local X = rf.load_hero('lion')
    rawget(bb, '__spec').IsMagicImmune = true  -- INJECTION, see HONEST BOUNDS
    assert(X[HELPER](bb) == false,
        'the turbo-only clause is load-bearing: an armed farm string must not '
        .. 'change a normal-mode game')
end

tests['decision: a NON-immune enemy is accepted either way (arming is a no-op there)'] = function()
    -- The other half of "widening": everywhere the immunity is absent, arming
    -- must change nothing at all.  Without this, an accept could be coming from
    -- the gate rather than from the shipped predicate.
    local _, _, heroesOff = world(FIXTURE, false)
    local X = rf.load_hero('lion')
    assert(X[HELPER](heroesOff[BB]) == true,
        'un-injected (so not immune as far as the mock is concerned) the target is '
        .. 'accepted with the gate OFF')
    local _, _, heroesOn = world(FIXTURE, true)
    rf.load_hero('lion')
    assert(X[HELPER](heroesOn[BB]) == true, 'and with the gate ON -- same answer')
end

-- ---------------------------------------------------------------- section 3 --
-- REACHABILITY, measured.  This is the bound the header states; it is a
-- reading taken here, not a sentence quoted from GH #577.

tests['reachability: the dumper gives this branch no target channel at all'] = function()
    local J, bot, _, _ = world(FIXTURE, false)
    assert(bot:GetTarget() == nil, 'GetTarget has a value on this frame -- if the '
        .. 'dumper grew a target channel, this branch became reachable and the '
        .. 'header\'s bound is stale (good news)')
    assert(bot:GetAttackTarget() == nil, 'GetAttackTarget likewise')
    assert(J.GetProperTarget(bot) == nil,
        'botTarget is nil, so X.ConsiderE\'s 打架抽蓝 branch cannot be entered from '
        .. 'a frame this generator produced.  THIS is why section 2 pins the '
        .. 'decision and not the branch.')
    assert(J.IsGoingOnSomeone(bot) == false, 'and the branch guard is false too')
end

tests['reachability: the sibling branch returns first on this very frame'] = function()
    -- Why the domain reading has to be its own: even with a target channel this
    -- frame would never reach the branch, because J.IsInTeamFight is true and
    -- 团战吸蓝 sits above it and accepts bristleback.  The exclusive domain is
    -- "going on someone but NOT in a teamfight".
    local J, bot, heroes = world(FIXTURE, false)
    assert(J.IsInTeamFight(bot, 1000) == true,
        'the sibling branch\'s premise is the replay\'s, not a stub')
    assert(J.CanCastOnMagicImmune(heroes[BB]) == true,
        'and the sibling branch accepts this target, so it returns before the '
        .. 'branch this file is about is ever consulted')
end

tests['reachability: the mana-refill loop has no supply here either'] = function()
    -- Stated so "the third site is untouched" is a measurement too: there are no
    -- creeps in this generator's output, so the creep loop could not have been
    -- validated in this round even if it had been taken.
    local _, bot = world(FIXTURE, false)
    assert(#bot:GetNearbyCreeps(1600, true) == 0,
        'creeps appeared in the fixture world; the mana-refill site is a separate '
        .. 'domain and would now be measurable -- it is still not this round\'s lever')
end

-- ---------------------------------------------------------------- section 4 --
-- The shape, pinned on the source.  These are what stop the lever from turning
-- into something else without a round noticing.

tests['shape: WIDENING by construction -- shipped first, bound, short-circuits true'] = function()
    local body = helper_body(read_file(SRC))
    local iShipped = body:find('local%s+bShipped%s*=%s*J%.CanCastOnNonMagicImmune%(')
    assert(iShipped, 'the shipped predicate is no longer computed FIRST and bound. '
        .. 'Direction-by-construction rests on that: armed is only ever reached '
        .. 'when shipped already said false.')
    local iGate = body:find('J%.IsSoakCandidate%(')
    assert(iGate and iShipped < iGate, 'the gate is consulted before the shipped '
        .. 'predicate is bound; the armed path could then answer for a target '
        .. 'shipped would have accepted, and the superset argument dies')
    assert(body:find('if%s+bShipped%s+then%s+return%s+true%s+end'),
        'the true short-circuit is gone -- without it the armed detour is reachable '
        .. 'for targets shipped ACCEPTS, which is how a widening lever silently '
        .. 'becomes a narrowing one')
    assert(body:find('return%s+bShipped%s*\n?%s*$') or body:find('\n%s*return%s+bShipped%s*\n'),
        'the last statement no longer returns bShipped; gate-off equivalence is '
        .. 'then a claim rather than a structure')
    assert(body:find('return%s+false') == nil,
        'a bare `return false` appeared in the body.  For a WIDENING lever that is '
        .. 'the forbidden direction: the armed path must never be able to refuse '
        .. 'something the shipped predicate accepted')
end

tests['shape: turbo-only and STANDALONE (the pullcad trap)'] = function()
    local body = helper_body(read_file(SRC))
    assert(body:find("J%.IsModeTurbo%(%)%s*and%s*J%.IsSoakCandidate%(%s*'" .. CAND .. "'%s*%)"),
        'the gate is no longer `IsModeTurbo() and IsSoakCandidate(\'' .. CAND
        .. '\')`. If it was PROMOTED, this file has to be re-read, not edited green.')
    -- STANDALONE: exactly one gate call in the body, and it names this id.  A
    -- gate written as `IsSoakCandidate('X') and IsSoakCandidate('Y')` freezes
    -- FALSE the day Y is promoted, and check_armed_wiring.py still says WIRED.
    local n = 0
    for _ in body:gmatch('IsSoakCandidate%(') do n = n + 1 end
    assert(n == 1, 'the body makes ' .. n .. ' IsSoakCandidate calls, was 1 -- a '
        .. 'second candidate id conjoined here is the pullcad trap')
    -- And the id exists exactly once across bots/, so nothing else rides it.
    local nTree = 0
    local p = assert(io.popen('grep -rl "' .. CAND .. '" bots 2>/dev/null'))
    for _ in p:lines() do nTree = nTree + 1 end
    p:close()
    assert(nTree == 1, CAND .. ' appears in ' .. nTree .. ' files under bots/, was 1')
end

tests['shape: the call site moved, and the other two sites did NOT'] = function()
    local body = consider_e_body(read_file(SRC))
    assert(body:find('and%s+X%.' .. HELPER .. '%(%s*botTarget%s*%)'),
        'the 打架抽蓝 branch no longer calls X.' .. HELPER .. '( botTarget ) -- the '
        .. 'lever is defined but not wired, which reads as "tested, no effect"')
    assert(body:find('and%s+J%.CanCastOnMagicImmune%(%s*npcEnemy%s*%)'),
        'the 团战吸蓝 branch stopped calling J.CanCastOnMagicImmune( npcEnemy ) '
        .. 'directly.  GH #566 says that branch is CORRECT as shipped; this round '
        .. 'was not allowed to touch it.')
    assert(body:find('and%s+J%.CanCastOnNonMagicImmune%(%s*nCreep%s*%)'),
        'the mana-refill loop stopped calling J.CanCastOnNonMagicImmune( nCreep ). '
        .. 'That site is a DIFFERENT domain (a creep, not an enemy hero) and this '
        .. 'round deliberately did not take it -- "not taken" must not decay into '
        .. '"taken quietly".')
end

tests['shape: the falsified-premise note still resolves to a file that exists'] = function()
    -- The note is the only thing standing between the next reader and re-deriving
    -- the withdrawn veto.  It named tests/fixtures/ for the staged frame from the
    -- day the rollback staged it, and nothing checked the path.
    local src = read_file(SRC)
    assert(src:find('PREMISE%-FALSIFIED'), SRC .. ' no longer carries the note')
    for path in src:gmatch('tests/[%w_/%.]+%.lua') do
        assert(io.open(path, 'r'), SRC .. ' cites ' .. path .. ', which does not exist')
    end
end

-- ---------------------------------------------------------------- section 5 --
-- The superset, DRIVEN rather than argued -- over every hero unit in the frames
-- this file loads, with the shipped reader's answer restored wherever the unit's
-- own modifier list says it is immune.

tests['superset: armed accepts everything shipped accepts, and only immunity differs'] = function()
    local set = immunity_modifiers()
    local nUnits, nInjected, nDiff, tDiff = 0, 0, 0, {}
    for _, path in ipairs(DRIVEN_FRAMES) do
        for _, bArmed in ipairs({ false, true }) do
            local J, bot, heroes = world(path, bArmed)
            local X = rf.load_hero('lion')
            for name, h in pairs(heroes) do
                if h ~= bot then
                    local bImmune = false
                    for m in pairs(set) do
                        if h:HasModifier(m) then bImmune = true break end
                    end
                    if bImmune then rawget(h, '__spec').IsMagicImmune = true end
                    local bAns = X[HELPER](h)
                    local bShipped = J.CanCastOnNonMagicImmune(h)
                    if not bArmed then
                        assert(bAns == bShipped, 'GATE OFF, ' .. path .. ' / ' .. name
                            .. ': the helper answered ' .. tostring(bAns)
                            .. ' where the shipped predicate says ' .. tostring(bShipped)
                            .. ' -- shipped behaviour has drifted')
                        nUnits = nUnits + 1
                        if bImmune then nInjected = nInjected + 1 end
                    else
                        assert(bShipped == false or bAns == true,
                            'SUPERSET VIOLATED, ' .. path .. ' / ' .. name
                            .. ': shipped accepts this target and armed refuses it. '
                            .. 'A widening lever may not remove a cast.')
                        if bAns ~= bShipped then
                            nDiff = nDiff + 1
                            tDiff[#tDiff + 1] = path .. ' / ' .. name
                            assert(bImmune, 'armed changed the answer for ' .. path
                                .. ' / ' .. name .. ', which carries NO immunity '
                                .. 'modifier.  The lever is supposed to be about '
                                .. 'immunity and nothing else.')
                        end
                    end
                end
            end
        end
    end
    -- Exact, as a ratchet: DRIVEN_FRAMES is a fixed list, so this number can
    -- only move if a frame file itself moves -- and a frame file moving is
    -- exactly when every reading taken over it has to be re-taken.
    assert(nUnits == 117, nUnits .. ' non-self hero instances were driven, was 117 '
        .. 'as of 2026-09-07.  A frame in DRIVEN_FRAMES changed; re-read this case '
        .. 'rather than re-baselining it.')
    -- NON-VACUITY.  Without at least one injected unit the superset above holds
    -- trivially and would stay green if the gate were wired to nothing at all.
    -- FOUR, and all four are in tests/frames/: the three Black-King-Bar instants
    -- (this file's own frame plus the two 2026-09-07 Axe frames) and one
    -- blade_fury.  The CORPUS contributes ZERO, which is backlog -109's premise
    -- and the reason this lever's real domain has to be bought off the archive.
    assert(nInjected == 4, nInjected .. ' spell-immune hero instances across the '
        .. 'driven frames, was 4 as of 2026-09-07.  MORE is good news for this '
        .. 'lever -- re-read it, do not relax it.')
    assert(nDiff > 0, 'arming changed NOTHING anywhere in the driven frames.  Either '
        .. 'the gate is not wired to the helper, or the injection stopped taking -- '
        .. 'in both cases the superset above proves nothing.')
    assert(#tDiff == nDiff and nDiff == nInjected, 'arming changed ' .. nDiff
        .. ' answers against ' .. nInjected .. ' immune instances: '
        .. table.concat(tDiff, '; ') .. '.  It was 4 of 4 -- the widened set is '
        .. 'exactly the immune set here, so anything else means the gate is either '
        .. 'missing immune targets or reaching non-immune ones.')
end

return tests

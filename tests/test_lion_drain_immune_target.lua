-- [hero] `liondrainbkb` -- X.ConsiderE's 团战吸蓝 branch aims Mana Drain at a
-- spell-immune enemy, and Mana Drain is stopped by spell immunity.  Written
-- 2026-09-06 under OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_lion.lua X.ConsiderE picks a Mana Drain target at THREE
-- places, and they do not agree about spell immunity:
--
--   mana-refill loop   `J.CanCastOnNonMagicImmune( nCreep )`      <- agrees with KV
--   团战吸蓝 branch     `J.CanCastOnMagicImmune( npcEnemy )`       <- the defect
--   打架抽蓝 branch     `J.CanCastOnNonMagicImmune( botTarget )`   <- agrees with KV
--
-- The two helpers differ by exactly one term: J.CanCastOnNonMagicImmune is
-- J.CanCastOnMagicImmune plus `not npcTarget:IsMagicImmune()`
-- (bots/FunLib/jmz_func.lua :961 and :988).  The second is the helper for an
-- ability that PIERCES spell immunity.  `lion_mana_drain` does not: its own
-- hero KV carries `SpellImmunityType SPELL_IMMUNITY_ENEMIES_NO`, and so do all
-- four of Lion's actives -- this hero has no piercing ability at all.  So one
-- branch out of three claims a permission the game does not grant.
--
-- WHY IT COSTS MORE THAN A NO-OP.  X.ConsiderE is the FIRST arm of the
-- X.SkillsComplement dispatch chain, and its consumer runs
-- `bot:Action_ClearActions( false )` before queueing the cast and then RETURNS,
-- skipping the R / Q / W arms below.  The branch is also below
-- `if X.IsOtherAbilityFullyCastable() ... then return 0 end`, i.e. it only runs
-- when Impale, Hex and Finger are ALL uncastable -- exactly when the cleared
-- action was the only thing Lion had.  Section 3's last pair measures this:
-- gate off, the frame issues ClearActions + a cast the engine cannot accept;
-- gate on, it issues nothing at all.
--
-- THE FIX is X.lion_IsDrainTargetCastable, gated turbo + 'liondrainbkb', wired
-- at that ONE call site.  The other two branches are not touched: they are
-- already right, and one lever at a time.
--
-- HONEST BOUNDS -- READ BEFORE QUOTING ANY NUMBER FROM HERE
-- ---------------------------------------------------------
--   * NO ENEMY IS SPELL-IMMUNE ON ANY LION FRAME IN THE CORPUS.  Section 2
--     measures that (0 of 8 subject frames, 0 of every enemy hero-instant in
--     them), which is why section 3 is a COUNTERFACTUAL and not a firing frame.
--     It is a one-sided tripwire: the day a fixture arrives with a BKB up it
--     goes RED and names it, and that frame is the (a)-evidence this lever
--     actually wants.
--   * BUT THE BRANCH ITSELF FIRES ON A REAL FRAME, with ONE flip.  That is the
--     part `axecallbkb` could not buy and this one can: on
--     f_260820_182906_lion_drain_survived at t=606.5 every other clause of the
--     团战吸蓝 branch is already satisfied by the replay -- J.IsInTeamFight is
--     true, drain is rank 2, Impale/Hex/Finger are all on cooldown, and TWO
--     enemies sit inside the 850u cast range with >200 mana and no veto.  The
--     single flip is drain's own remaining cooldown, 11.6 -> 0.  Everything
--     else on the frame -- positions, health, mana, levels, cooldowns,
--     modifiers, the other nine heroes -- is the replay's.
--   * THE IMMUNITY FLIPS ARE MUTATIONS AND ARE LABELLED AS SUCH.  Sections 3c
--     and 3d set IsMagicImmune on named enemies.  They are the ONLY inputs to
--     the changed predicate that the corpus cannot supply, and they are applied
--     one at a time so each one's role is visible.
--   * DIRECTION IS STRUCTURAL, NOT MEASURED.  The shipped predicate runs first
--     and the armed path may only turn its `true` into `false`, so armed is a
--     strict SUBSET of shipped.  Section 5 asserts that shape on the source.  A
--     negative wave reading can therefore only ever mean "those drains should
--     have been cast"; it can never mean the lever aimed a drain somewhere new.
--   * Corpus counts come from `dofile` via the loader, never from a regex over
--     the fixture files (the Axe pre-flight's first pass under-counted exactly
--     that way).
--   * `print` is captured before the loader runs anywhere a reading is echoed:
--     rf.install() replaces it with a no-op (GH #546).  This file asserts
--     instead of printing, so it is immune, but the probes behind sections 2-3
--     were not until they were fixed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_lion.lua'
local FUN = 'bots/FunLib/jmz_func.lua'
local FIXTURE = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua'
local LION = 'npc_dota_hero_lion'
local LUNA = 'npc_dota_hero_luna'
local CM = 'npc_dota_hero_crystal_maiden'
local DRAIN = 'lion_mana_drain'
local CAND = 'liondrainbkb'

-- Recalled 2026-09-06 from the game's own npc_dota_hero_lion.txt via the
-- dotabuff/d2vpkr mirror -- the same file and the same top-level-field walk
-- tools/agent/cast_shape_census.py uses for AbilityBehavior.
local DRAIN_SPELL_IMMUNITY = 'SPELL_IMMUNITY_ENEMIES_NO'
-- These four DO have KV counterparts in the repo snapshot, so section KV can
-- cross-check them and a silent drift between the recalled ability shape and
-- the shipped data becomes impossible.  `SpellImmunityType` itself has no
-- counterpart -- exactly the GH #516 disposition, RECORDED not verified.
local DRAIN_CAST_RANGE = 850
local DRAIN_COOLDOWN = { 15, 12, 9, 6 }
local DRAIN_MPS = { 20, 40, 60, 120 }
local DRAIN_DURATION = 5.0

-- Every Lion-SUBJECT fixture in the corpus, listed rather than globbed so a new
-- one is a deliberate edit and section 2's counts move with a named cause.
local LION_FRAMES = {
    'tests/fixtures/f_045650_lion_meatgrinder.lua',
    'tests/fixtures/f_222428_lion_lich_burst.lua',
    'tests/fixtures/f_260819_182323_lion_drain_calm.lua',
    'tests/fixtures/f_260819_182855_lion_drain_jungle.lua',
    'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua',
    'tests/fixtures/f_260819_183409_lion_drain_focused.lua',
    'tests/fixtures/f_260820_162821_lion_drain_lethal.lua',
    'tests/fixtures/f_260820_182906_lion_drain_survived.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function consider_e_body(src)
    local from = src:find('function X%.ConsiderE%s*%(%s*%)')
    assert(from, 'X.ConsiderE not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Load the real frame, optionally arm `liondrainbkb`, optionally apply the
--- declared flips, then drive the REAL X.SkillsComplement and report the orders
--- it issued.  Driving the DISPATCH rather than X.ConsiderE directly is
--- deliberate: Action_ClearActions is issued by the consumer, not the branch,
--- and it is half of what this defect costs.
local function run(opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    -- `opt.armed == true`, not `opt.armed`: an absent key would make this return
    -- nil, and a helper asserted `== false` then fails on a nil that is
    -- behaviourally identical.  The distinction is the test's, not the gate's.
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load, exactly as
        -- tests/test_axe_call_immune_veto.lua does.
        GetGameMode = function() return 1 end
    end
    if opt.ready then
        rawget(bot:GetAbilityByName(DRAIN), '__spec').GetCooldownTimeRemaining = 0
    end
    for _, name in ipairs(opt.immune or {}) do
        local h = assert(heroes[name], name .. ' is not on this frame; the flip list is stale')
        rawget(h, '__spec').IsMagicImmune = true
    end
    local X = rf.load_hero('lion')
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    -- Flatten to "fn(ability -> target)" so a case can assert the TARGET, which
    -- is the whole of what this lever changes.
    local orders = {}
    for _, a in ipairs(log) do
        local abil, tgt = a.args[1], a.args[2]
        local an = (type(abil) == 'table' and abil.GetName) and abil:GetName() or nil
        local tn = (type(tgt) == 'table' and tgt.GetUnitName) and tgt:GetUnitName() or nil
        orders[#orders + 1] = a.fn .. (an and ('(' .. an .. (tn and (' -> ' .. tn) or '') .. ')') or '')
    end
    return orders, X, J, bot, heroes, fx
end

local function joined(orders)
    return (#orders == 0) and '(no action)' or table.concat(orders, ' | ')
end

-- ---------------------------------------------------------------- section 1 --
-- Ground truth on the untouched frame.

tests['ground truth: 10:06, Lion in a teamfight with only Mana Drain to spend'] = function()
    local _, X, J, bot, _, fx = run()
    assert(fx.self == LION and fx.time == 606.5, 'the decision instant')
    assert(bot:GetLevel() == 8 and bot:GetHealth() == 603 and bot:GetMana() == 501,
        'real Lion state, got lvl ' .. bot:GetLevel() .. ' hp ' .. bot:GetHealth()
        .. ' mp ' .. bot:GetMana())
    assert(J.IsInTeamFight(bot, 1000) == true,
        'the branch premise is the replay\'s, not a stub')
    assert(X.IsOtherAbilityFullyCastable() == false,
        'Impale, Hex and Finger are all uncastable -- the shipped guard above the '
        .. 'branch lets this frame through')
    local e = bot:GetAbilityByName(DRAIN)
    assert(e:GetLevel() == 2, 'drain is rank 2 -- past the nSkillLV <= 1 early-out')
end

tests['ground truth: the ONE flip is drain\'s own 11.6s of remaining cooldown'] = function()
    -- Not colour.  It is the fact that makes section 3 a one-flip
    -- counterfactual rather than a three-flip one.
    local _, _, _, bot = run()
    local e = bot:GetAbilityByName(DRAIN)
    assert(e:GetCooldownTimeRemaining() == 11.6,
        'remaining cooldown, got ' .. tostring(e:GetCooldownTimeRemaining()))
    assert(e:IsFullyCastable() == false, 'so the shipped first line of X.ConsiderE bails')
    assert(bot:GetMana() >= 0, 'and it is the COOLDOWN that bails it: drain costs no mana')
end

tests['ground truth: two enemies satisfy every OTHER clause of the branch'] = function()
    local _, _, J, bot, heroes = run()
    local n = 0
    for _, name in ipairs({ LUNA, CM }) do
        local h = assert(heroes[name], name .. ' is not on this frame')
        assert(h:GetTeam() ~= bot:GetTeam(), name .. ' must be the enemy here')
        assert(h:IsAlive(), name .. ' must be alive')
        assert(GetUnitToUnitDistance(bot, h) <= DRAIN_CAST_RANGE,
            name .. ' must be inside the 850u cast range, got '
            .. math.floor(GetUnitToUnitDistance(bot, h)))
        assert(h:GetMana() > 200, name .. ' must clear the >200 mana clause, got ' .. h:GetMana())
        assert(h:HasModifier('modifier_lion_finger_of_death') == false, name .. ' is not fingered')
        assert(J.IsDisabled(h) == false, name .. ' is not disabled')
        assert(J.CanCastOnTargetAdvanced(h) == true, name .. ' passes the advanced check')
        n = n + 1
    end
    assert(n == 2, 'both named enemies must be real branch candidates')
end

tests['shipped path: the untouched frame issues no order at all'] = function()
    local orders = run()
    assert(#orders == 0, 'shipped orders on the untouched frame: ' .. joined(orders))
end

-- ---------------------------------------------------------------- section 2 --
-- The supply, measured.  One-sided tripwires: more fixtures can only strengthen
-- them, and the day one reaches the domain it goes RED and names the frame --
-- which is the real frame this lever needs before anyone promotes it.

tests['supply: no enemy hero-instant is spell-immune in ANY Lion-subject frame'] = function()
    local nFrames, nEnemies, nImmune, sWhere = 0, 0, 0, nil
    for _, path in ipairs(LION_FRAMES) do
        local J, bot, heroes, fx = rf.load(path)
        J.IsSoakCandidate = function() return false end
        assert(fx.self == LION, path .. ' is not a Lion-subject frame; LION_FRAMES is stale')
        nFrames = nFrames + 1
        for name, h in pairs(heroes) do
            if h:GetTeam() ~= bot:GetTeam() then
                nEnemies = nEnemies + 1
                if h:IsMagicImmune() then
                    nImmune = nImmune + 1
                    sWhere = path .. ' / ' .. name
                end
            end
        end
    end
    assert(nFrames == 8, 'LION_FRAMES grew to ' .. nFrames
        .. '; re-read the counts below before trusting them')
    assert(nEnemies >= 40, 'enemy hero-instants dropped below the measured 40, got ' .. nEnemies)
    assert(nImmune == 0,
        'GOOD NEWS, NOT A REGRESSION: ' .. tostring(sWhere) .. ' now carries a spell-immune '
        .. 'enemy on a Lion frame.  This lever no longer needs the flips in section 3c/3d '
        .. '-- rewrite them against that frame and re-read the HONEST BOUNDS header.  Do '
        .. 'NOT relax this assertion.')
end

tests['supply: this is the ONLY subject frame whose branch premise already holds'] = function()
    -- Why the counterfactual is built on this fixture and not another: it is
    -- the only frame that is one flip away.  If a second one appears, that is
    -- worth knowing before anyone claims "the corpus offers nothing".
    local nTF, nReady, sTF = 0, 0, {}
    for _, path in ipairs(LION_FRAMES) do
        local J, bot, _, _ = rf.load(path)
        J.IsSoakCandidate = function() return false end
        local X = rf.load_hero('lion')
        local e = bot:GetAbilityByName(DRAIN)
        local bPremise = J.IsInTeamFight(bot, 1000)
            and e ~= nil and e:GetLevel() >= 2
            and X.IsOtherAbilityFullyCastable() == false
        if bPremise then nTF = nTF + 1; sTF[#sTF + 1] = path end
        if bPremise and e:IsFullyCastable() then nReady = nReady + 1 end
    end
    assert(nTF == 1, 'branch-premise frames moved from the measured 1 to ' .. nTF
        .. ' (' .. table.concat(sTF, ', ') .. '); re-read section 3 before quoting it')
    assert(sTF[1] == FIXTURE, 'the one premise frame is no longer ' .. FIXTURE)
    assert(nReady == 0,
        'GOOD NEWS: a subject frame now has the branch premise AND drain off cooldown, so '
        .. 'flip (a) is no longer needed.  Rewrite section 3 rather than relaxing this.')
end

-- ---------------------------------------------------------------- section 3 --
-- The counterfactual, applied one flip at a time so each one's role is visible.

tests['3a (a) alone, both legs: the branch fires on luna and arming changes nothing'] = function()
    -- The anti-regression half.  Nobody is immune on this frame -- which is
    -- every frame in this corpus and the overwhelming majority of a real game
    -- -- so the gate must be a no-op here.
    local off = run({ ready = true })
    local on = run({ ready = true, armed = true })
    assert(joined(off) == 'Action_ClearActions | ActionQueue_UseAbilityOnEntity('
        .. DRAIN .. ' -> ' .. LUNA .. ')', 'shipped orders, got ' .. joined(off))
    assert(joined(on) == joined(off),
        'armed orders drifted on a frame with nobody immune:\n  off ' .. joined(off)
        .. '\n  on  ' .. joined(on))
end

tests['3b (a) alone: this is a REAL branch firing, not a stubbed one'] = function()
    -- Guards against the whole section becoming gate plumbing: the order that
    -- comes out must be Mana Drain, aimed at a hero the replay put there.
    local orders, _, _, bot, heroes = run({ ready = true })
    assert(#orders == 2, 'expected ClearActions + one queued cast, got ' .. joined(orders))
    assert(GetUnitToUnitDistance(bot, heroes[LUNA]) < 180,
        'luna really is ~178u away on this frame, got '
        .. math.floor(GetUnitToUnitDistance(bot, heroes[LUNA])))
    assert(heroes[LUNA]:GetMana() == 533, 'luna\'s real mana, got ' .. heroes[LUNA]:GetMana())
end

tests['3c (a)+(b) luna spell-immune: gate OFF still aims at her -- the defect'] = function()
    -- MUTATION, labelled: IsMagicImmune false -> true on luna only.
    local orders = run({ ready = true, immune = { LUNA } })
    assert(joined(orders) == 'Action_ClearActions | ActionQueue_UseAbilityOnEntity('
        .. DRAIN .. ' -> ' .. LUNA .. ')',
        'shipped code aims a non-piercing channel at a spell-immune enemy; got '
        .. joined(orders))
end

tests['3c (a)+(b) luna spell-immune: gate ON retargets to the reachable enemy'] = function()
    local orders = run({ ready = true, immune = { LUNA }, armed = true })
    assert(joined(orders) == 'Action_ClearActions | ActionQueue_UseAbilityOnEntity('
        .. DRAIN .. ' -> ' .. CM .. ')',
        'armed, the same branch must pick crystal_maiden (625u, 543 mana, not immune); got '
        .. joined(orders))
end

tests['3d (a)+(b2) both in-range enemies immune, gate OFF: a wasted ClearActions'] = function()
    -- The case that measures the COST.  Nothing the engine can accept comes out
    -- of this tick, but the bot's queued actions are wiped and the R/Q/W arms
    -- below X.ConsiderE never run.
    local orders = run({ ready = true, immune = { LUNA, CM } })
    assert(joined(orders) == 'Action_ClearActions | ActionQueue_UseAbilityOnEntity('
        .. DRAIN .. ' -> ' .. LUNA .. ')',
        'shipped orders when NO reachable target exists; got ' .. joined(orders))
end

tests['3d (a)+(b2) both in-range enemies immune, gate ON: no order is issued'] = function()
    local orders = run({ ready = true, immune = { LUNA, CM }, armed = true })
    assert(#orders == 0,
        'armed, X.ConsiderE must fall through to DESIRE_NONE so the dispatch chain is '
        .. 'free -- and in particular Action_ClearActions must NOT be issued; got '
        .. joined(orders))
end

tests['3e gate ON but NOT turbo: the defect is back, unchanged'] = function()
    -- The turbo half of the gate carries the whole "shipped normal-mode
    -- behaviour is unchanged" promise; without this case the gate could be
    -- turbo-less and every other case here would still pass.
    local orders = run({ ready = true, immune = { LUNA, CM }, armed = true, nonTurbo = true })
    assert(joined(orders) == 'Action_ClearActions | ActionQueue_UseAbilityOnEntity('
        .. DRAIN .. ' -> ' .. LUNA .. ')',
        'outside turbo the candidate must be inert; got ' .. joined(orders))
end

-- ---------------------------------------------------------------- section 4 --
-- The gate helper itself.

tests['the helper is turbo AND candidate, not either'] = function()
    -- Each leg gets a FRESH world: J.IsModeTurbo memoises into bModeTurboCache
    -- on its first call, so flipping GetGameMode after the helper has run once
    -- changes nothing.
    local mk = function(opt)
        local _, X, _, _, heroes = run(opt)
        return X, heroes
    end
    local Xturbo, hTurbo = mk({ armed = true, immune = { LUNA } })
    assert(type(Xturbo.lion_IsDrainTargetCastable) == 'function',
        'X.lion_IsDrainTargetCastable is gone or renamed')
    assert(Xturbo.lion_IsDrainTargetCastable(hTurbo[LUNA]) == false,
        'armed + turbo must veto the immune enemy')

    local Xnormal, hNormal = mk({ armed = true, immune = { LUNA }, nonTurbo = true })
    assert(Xnormal.lion_IsDrainTargetCastable(hNormal[LUNA]) == true,
        'armed but not turbo must be inert')

    local Xdisarmed, hDisarmed = mk({ immune = { LUNA } })
    assert(Xdisarmed.lion_IsDrainTargetCastable(hDisarmed[LUNA]) == true,
        'turbo but not armed must be inert')
end

tests['the helper is a strict subset of the shipped predicate, on this frame'] = function()
    -- Direction, driven rather than only read off the source: for every enemy
    -- hero-instant, armed => shipped.  The reverse is allowed to fail; that is
    -- what NARROWING means.
    local _, Xoff, _, botOff, hOff = run({ immune = { LUNA, CM } })
    local _, Xon, Jon, _, hOn = run({ immune = { LUNA, CM }, armed = true })
    local nStrict = 0
    for name, h in pairs(hOff) do
        if h:GetTeam() ~= botOff:GetTeam() then
            local bOff = Xoff.lion_IsDrainTargetCastable(h)
            local bOn = Xon.lion_IsDrainTargetCastable(hOn[name])
            assert(not bOn or bOff,
                name .. ': armed answered true where shipped answered false -- that is a '
                .. 'WIDENING, and this lever is only allowed to narrow')
            assert(bOff == Jon.CanCastOnMagicImmune(hOff[name]),
                name .. ': gate OFF must be the shipped predicate verbatim')
            if bOff and not bOn then nStrict = nStrict + 1 end
        end
    end
    assert(nStrict == 2, 'exactly the two flipped enemies must differ, got ' .. nStrict)
end

tests['the helper names exactly this candidate id and nothing else'] = function()
    -- The `pullcad` trap: a gate whose condition names a SIBLING id freezes
    -- FALSE the day that sibling is promoted, and no wiring check notices.
    -- This helper must be STANDALONE -- and Lion already carries three other
    -- ids (liondrain, liondrainstop, lionhexaoe) it could have leaned on.
    local src = read_file(SRC)
    local from = src:find('function X%.lion_IsDrainTargetCastable%s*%(')
    assert(from, 'X.lion_IsDrainTargetCastable not found in ' .. SRC)
    local to = src:find('\nend', from)
    local body = src:sub(from, to)
    local ids = {}
    for id in body:gmatch("IsSoakCandidate%s*%(%s*'([%w_]+)'") do ids[#ids + 1] = id end
    assert(#ids == 1 and ids[1] == CAND,
        'the helper must name exactly one candidate id (' .. CAND .. '), found '
        .. table.concat(ids, ','))
    assert(body:find('IsModeTurbo'), 'the helper lost its turbo half')
    local _, nWhole = src:gsub("IsSoakCandidate%s*%(%s*'" .. CAND .. "'", '')
    assert(nWhole == 1,
        CAND .. ' appears at ' .. nWhole .. ' gate sites in ' .. SRC
        .. '; it must be resolved in exactly one place')
end

-- ---------------------------------------------------------------- section 5 --
-- The shape, on the source.  These are what make "gate-off is the shipped
-- expression" and "armed can only narrow" structural rather than measured.

tests['the shipped predicate runs FIRST and is the only thing that can return true'] = function()
    local src = read_file(SRC)
    local from = src:find('function X%.lion_IsDrainTargetCastable%s*%(')
    local body = src:sub(from, src:find('\nend', from))
    assert(body:find('local bShipped = J%.CanCastOnMagicImmune%( hTarget %)'),
        'the shipped predicate must be evaluated first and bound, so gate-off equivalence '
        .. 'is structural')
    assert(body:find('if not bShipped then return false end'),
        'a shipped false must short-circuit before the gate is consulted')
    assert(body:find('return false') and body:find('return bShipped'),
        'the armed branch may only return false; the last statement must return the '
        .. 'shipped value')
    assert(body:find('return true') == nil,
        'a bare `return true` would let the armed path invent a permission the shipped '
        .. 'predicate did not grant')
end

tests['the call site is wired, and it is the 团战吸蓝 branch alone'] = function()
    local body = consider_e_body(read_file(SRC))
    local _, nWired = body:gsub('X%.lion_IsDrainTargetCastable%(', '')
    assert(nWired == 1, 'expected exactly one call site in X.ConsiderE, found ' .. nWired)
    -- The other two target selections must keep the NON-piercing helper, which
    -- is what makes this a one-lever change.
    local _, nNonPierce = body:gsub('J%.CanCastOnNonMagicImmune%(', '')
    assert(nNonPierce == 2,
        'the mana-refill and 打架抽蓝 branches must both keep J.CanCastOnNonMagicImmune; '
        .. 'found ' .. nNonPierce .. ' such calls in X.ConsiderE')
    local _, nPierce = body:gsub('J%.CanCastOnMagicImmune%(', '')
    assert(nPierce == 0,
        'X.ConsiderE must no longer call the piercing helper directly; found ' .. nPierce)
end

tests['the two jmz helpers still differ by exactly the IsMagicImmune term'] = function()
    -- If J.CanCastOnMagicImmune ever loses one of the OTHER vetoes, the armed
    -- path would be narrowing for a second reason and the direction argument
    -- would still hold -- but the DEFECT statement above (they differ by one
    -- term) would be stale, and a reader would be quoting a dead sentence.
    local fun = read_file(FUN)
    local function body_of(name)
        local from = fun:find('function J%.' .. name .. '%s*%(')
        assert(from, 'J.' .. name .. ' not found in ' .. FUN)
        return fun:sub(from, fun:find('\nend', from))
    end
    local pierce, nonPierce = body_of('CanCastOnMagicImmune'), body_of('CanCastOnNonMagicImmune')
    for _, term in ipairs({ 'CanBeSeen', 'IsInvulnerable', 'IsSuspiciousIllusion',
                            'HasForbiddenModifier' }) do
        assert(pierce:find(term), 'J.CanCastOnMagicImmune no longer checks ' .. term)
        assert(nonPierce:find(term), 'J.CanCastOnNonMagicImmune no longer checks ' .. term)
    end
    assert(pierce:find('IsMagicImmune') == nil,
        'J.CanCastOnMagicImmune grew an IsMagicImmune term -- the shipped call site was '
        .. 'never the defect this file describes; re-read everything above')
    assert(nonPierce:find('IsMagicImmune'),
        'J.CanCastOnNonMagicImmune lost its IsMagicImmune term')
end

-- --------------------------------------------------------------- section KV --
-- The recalled ability shape against the fixture's own KV block.  If this goes
-- red, do NOT edit the anchor to match: either a patch moved Mana Drain (update
-- the anchor AND the helper header, and re-read every claim quoting the
-- numbers) or the loader/snapshot drifted (fix that, the anchor is fine).

tests['KV: the recalled Mana Drain anchor matches the fixture KV on all four ranks'] = function()
    local _, _, _, bot = run()
    local h = bot:GetAbilityByName(DRAIN)
    assert(h ~= nil, 'no ' .. DRAIN .. ' handle on the frame')
    local sp = rawget(h, '__spec')
    assert(sp ~= nil and sp.GetSpecialValueFloat ~= nil,
        'the loader installed no KV spec on ' .. DRAIN .. ' -- this cross-check is '
        .. 'vacuous, not passing; find out why before quoting this section')
    local lv0 = sp.GetLevel
    for rank = 1, 4 do
        sp.GetLevel = rank
        assert(h:GetCastRange() == DRAIN_CAST_RANGE,
            ('rank %d cast range: anchor %d, fixture KV %s'):format(
                rank, DRAIN_CAST_RANGE, tostring(h:GetCastRange())))
        assert(h:GetCooldown() == DRAIN_COOLDOWN[rank],
            ('rank %d cooldown: anchor %d, fixture KV %s'):format(
                rank, DRAIN_COOLDOWN[rank], tostring(h:GetCooldown())))
        assert(h:GetSpecialValueInt('mana_per_second') == DRAIN_MPS[rank],
            ('rank %d mana_per_second: anchor %d, fixture KV %s'):format(
                rank, DRAIN_MPS[rank], tostring(h:GetSpecialValueInt('mana_per_second'))))
    end
    sp.GetLevel = lv0
    assert(h:GetSpecialValueFloat('duration') == DRAIN_DURATION,
        'duration anchor ' .. DRAIN_DURATION .. ', fixture KV '
        .. tostring(h:GetSpecialValueFloat('duration')))
    assert(DRAIN_COOLDOWN[2] == 12,
        'the "11.6 of its rank-2 12s cooldown" reading in section 1 is built from this anchor')
end

tests['KV: SpellImmunityType is RECORDED, not verified -- and says so'] = function()
    -- GH #516's disposition, made explicit rather than left to the header.  The
    -- repo's KV snapshot (tests/mock/special_value_shapes.lua) carries
    -- AbilitySpecial/AbilityValues entries and a handful of top-level ones; it
    -- does NOT carry SpellImmunityType, so no in-repo cross-check of the field
    -- this lever rests on is possible.  This case pins the ABSENCE, so the day
    -- the snapshot grows the field a reader is told to upgrade the claim.
    local shapes = read_file('tests/mock/special_value_shapes.lua')
    local from = shapes:find("%['lion_mana_drain'%]")
    assert(from, 'lion_mana_drain is gone from the KV snapshot')
    local block = shapes:sub(from, shapes:find('\n        },', from))
    assert(block:find('SpellImmunityType') == nil,
        'GOOD NEWS: the KV snapshot now carries SpellImmunityType.  Assert '
        .. DRAIN_SPELL_IMMUNITY .. ' against it here and upgrade the header from '
        .. 'RECORDED to verified.')
    assert(DRAIN_SPELL_IMMUNITY == 'SPELL_IMMUNITY_ENEMIES_NO',
        'the recalled value is what the whole lever rests on')
    -- What the snapshot DOES carry is enough to prove the ability is a
    -- multi-second stationary channel, which is the other half of the cost.
    assert(block:find("%['AbilityChannelTime'%] = { base = '5.1'"),
        'Mana Drain is no longer a 5.1s channel; re-read the cost argument in the header')
end

return tests

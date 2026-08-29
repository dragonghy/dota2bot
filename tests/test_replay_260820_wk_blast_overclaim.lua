-- [hero] Replay-fixture regression for soak candidate `wkqdmg` (turbo-only):
-- Wraith King's Hellfire Blast kill-confirm claims damage the blast does not do.
--
-- THE LEVER WAS REGISTERED, NOT TAKEN (hero_skeleton_king.lua, 2026-08-22 and
-- widened 2026-08-27).  The kill check reads a hardcode times 1.68 --
-- 168/235/302/370 CLAIMED magical damage -- against a blast whose impact is
-- 80/100/120/140 and whose impact-plus-whole-dot is 120/180/240/300 (the game's
-- own KV, `skeleton_king_hellfire_blast`: damage 80/100/120/140,
-- blast_dot_damage 20/40/60/80 PER SECOND, blast_dot_duration 2.0).  Both notes
-- say the same thing: this needs its own gate AND ITS OWN REAL FRAME.
--
-- WHY THE FRAME WAS NOT FOUND FOR SEVEN DAYS, and it is not because it was not
-- there.  `J.CanKillTarget` reads `GetActualIncomingDamage` for every non-PURE
-- damage type, and the mock had no default for it, so the generic `^Get` default
-- answered 0 -- "no damage of any type ever reaches this unit".  Every magical
-- kill-confirm in the tree was structurally false on every frame in the corpus,
-- so a band census run against the corpus returned an artefact zero.  With the
-- mock default corrected (tests/mock/bot_api.lua, and pinned by
-- tests/test_mock_incoming_damage_default.lua) the same census over all 107
-- f_*.lua frames returns exactly ONE frame in the band -- this one.
--
-- THE FRAME (real data, 20260820_181711 slot .. , t=333.5 = 5:33):
--   Wraith King, level 5, 702/934 HP, 158 mana. Hellfire Blast rank 1.
--   juggernaut, level 5, **160/1067 HP**, 539 units away, alive, not magic
--   immune (Blade Fury is on a 7.1s cooldown), already carrying
--   `modifier_skeleton_king_hellfire_blast` with 2.4s left -- i.e. WK blasted
--   him 0.6s earlier and this is what that blast left standing.
--   Shipped claims 100 * 1.68 = 168 >= 160 and calls it a kill.
--   The blast alone does 80 + 20*2 = 120. It is not a kill.
--
-- ⚠️ THE ONE LABELLED MUTATION, and it is unavoidable: on this frame the blast is
-- on a 13.3s cooldown (it was just cast), so `abilityQ:IsFullyCastable()` is false
-- and X.ConsiderQ returns on its first line. The end-to-end cases below set the
-- cooldown to 0. Everything the lever reads -- the 160 HP, the ranks, the
-- distance, WK's mana -- is real frame data, and the ground-truth cases assert
-- those directly.
--
-- EXTERNAL ANCHORS -- what make_fixture.py does not extract (it dumps no ability
-- specs): the blast's cast range 525, mana cost 95, and the three AbilityValues
-- above. All four come from the game's own KV via
-- tools/agent/special_value_key_census.py's mirror, fetched 2026-08-29 -- the
-- same source tests/mock/special_value_keys.lua is generated from, which already
-- lists `damage`, `blast_dot_damage` and `blast_dot_duration` as legal keys on
-- this hero.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/fixtures/f_260820_181711_wk_l1trade_333.lua'

local Q_NAME       = 'skeleton_king_hellfire_blast'
local Q_CAST_RANGE = 525                      -- KV AbilityCastRange
local Q_MANA_COST  = 95                       -- KV AbilityManaCost, rank 1
local Q_IMPACT     = { 80, 100, 120, 140 }    -- KV damage
local Q_DOT_DPS    = { 20, 40, 60, 80 }       -- KV blast_dot_damage (per second)
local Q_DOT_DUR    = 2.0                      -- KV blast_dot_duration

--- Load the frame, anchor the KV the dumper cannot carry, arm/disarm the gate.
local function load_wk(bArmed, bTurbo, nRank, nDotDur)
    local J, bot, heroes, fx = rf.load(FRAME)
    local abilityQ = bot:GetAbilityByName(Q_NAME)
    local spec = rawget(abilityQ, '__spec')
    nRank = nRank or abilityQ:GetLevel()
    spec.GetLevel = nRank
    spec.GetCastRange = Q_CAST_RANGE
    spec.GetManaCost = Q_MANA_COST
    spec.GetSpecialValueInt = function(_, sKey)
        if sKey == 'damage' then return Q_IMPACT[nRank] end
        if sKey == 'blast_dot_damage' then return Q_DOT_DPS[nRank] end
        return 0
    end
    spec.GetSpecialValueFloat = function(_, sKey)
        if sKey == 'blast_dot_duration' then return nDotDur or Q_DOT_DUR end
        return 0
    end

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end  -- luacheck: ignore
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'wkqdmg' end
        or function() return false end

    local X = rf.load_hero('skeleton_king')
    return X, J, bot, heroes, abilityQ, fx
end

local tests = {}

-- ---------------------------------------------------------------- ground truth

tests['ground truth: a 160-HP juggernaut 539 away, and a blast that cannot kill him'] = function()
    local _, _, bot, heroes, abilityQ, fx = load_wk(false)
    assert(fx.time == 333.5, 'the frame is t=333.5, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_skeleton_king', 'subject is Wraith King')
    assert(bot:GetLevel() == 5, 'WK is level 5, got ' .. bot:GetLevel())
    assert(abilityQ:GetLevel() == 1, 'the blast is rank 1 on this frame')

    local jug = heroes['npc_dota_hero_juggernaut']
    assert(jug:IsAlive(), 'the target is alive')
    assert(jug:GetHealth() == 160, 'real frame HP, got ' .. jug:GetHealth())
    local d = GetUnitToUnitDistance(bot, jug)
    assert(d > 500 and d < 560, 'juggernaut is ~539 away, got ' .. math.floor(d))
    assert(d <= Q_CAST_RANGE + 80, 'and inside the branch reach of cast range + 80')
    assert(not jug:IsMagicImmune(), 'Blade Fury is on cooldown on this frame')
    assert(jug:HasModifier('modifier_skeleton_king_hellfire_blast'),
        'he is already carrying the blast WK cast 0.6s earlier')

    -- The two numbers the lever is about, on this frame.
    assert(100 * 1.68 >= jug:GetHealth(), 'shipped claims a kill: 168 >= 160')
    assert(Q_IMPACT[1] + Q_DOT_DPS[1] * Q_DOT_DUR < jug:GetHealth(),
        'the blast alone does 120, which does not kill 160')
end

tests['ground truth: the blast is on cooldown here -- the mutation is real and named'] = function()
    local _, _, _, _, abilityQ = load_wk(false)
    assert(not abilityQ:IsFullyCastable(),
        'cd 13.3 on the real frame: every end-to-end case below mutates this')
end

-- ------------------------------------------------------------------ the helper

tests['gate OFF: the helper is the shipped expression, byte for byte'] = function()
    local X, _, _, _, abilityQ = load_wk(false)
    assert(X.wk_GetBlastKillDamage(abilityQ) == 100 * 1.68,
        'unarmed must reproduce nDamage * 1.68, got ' .. X.wk_GetBlastKillDamage(abilityQ))
end

tests['gate OFF: armed but NOT turbo is still the shipped expression'] = function()
    local X, _, _, _, abilityQ = load_wk(true, false)
    assert(X.wk_GetBlastKillDamage(abilityQ) == 100 * 1.68, 'the gate is turbo-only')
end

tests['armed: the claim drops to the blast\'s own damage, impact plus whole dot'] = function()
    local X, _, _, _, abilityQ = load_wk(true)
    assert(X.wk_GetBlastKillDamage(abilityQ) == 120,
        'armed rank 1 = 80 + 20*2, got ' .. X.wk_GetBlastKillDamage(abilityQ))
end

tests['armed: it is a NARROWING -- it may never claim more than shipped'] = function()
    -- Rank 2 with the t10 facet talent trained (blast_dot_duration 2 -> 4) is the
    -- case where the honest read OVERTAKES the hardcode: 100 + 40*4 = 260 against
    -- 140*1.68 = 235.2. A lever that shipped the honest number would ADD casts
    -- there. min() is what keeps this one one-directional (GH #165 discipline).
    local X, _, _, _, abilityQ = load_wk(true, true, 2, 4.0)
    local nShipped = (40 * (2 - 1) + 100) * 1.68
    assert(Q_IMPACT[2] + Q_DOT_DPS[2] * 4.0 > nShipped, 'the honest read really is larger here')
    assert(X.wk_GetBlastKillDamage(abilityQ) == nShipped,
        'armed must fall back to the smaller shipped claim, got '
        .. X.wk_GetBlastKillDamage(abilityQ))
end

tests['armed: rank 4 without the talent still narrows (300 < 369.6)'] = function()
    local X, _, _, _, abilityQ = load_wk(true, true, 4)
    assert(X.wk_GetBlastKillDamage(abilityQ) == 300,
        'armed rank 4 = 140 + 80*2, got ' .. X.wk_GetBlastKillDamage(abilityQ))
end

tests['armed: an unresolved key falls back to shipped, not to a 0-damage world'] = function()
    -- A renamed KV key answers 0 silently (the reason
    -- tools/agent/special_value_key_census.py exists). The armed side must not
    -- turn that into "the blast does nothing", which would mute the branch.
    local X, _, _, _, abilityQ = load_wk(true)
    rawget(abilityQ, '__spec').GetSpecialValueInt = function() return 0 end  -- MUTATION
    assert(X.wk_GetBlastKillDamage(abilityQ) == 100 * 1.68,
        'a zero read is a broken read, not a measurement')
end

-- ------------------------------------------------------------------ end to end
-- Assert the FINAL decision (test_set.md §0b), not the helper's return value:
-- X.SkillsComplement is the only caller of X.ConsiderQ and it queues the cast.

--- Drive the real X.SkillsComplement on the frame; returns the ability names cast.
local function run_skills(bArmed)
    local X, _, bot, heroes, abilityQ = load_wk(bArmed)
    rawget(abilityQ, '__spec').IsFullyCastable = true            -- MUTATION (cd 13.3 -> ready)
    rawget(abilityQ, '__spec').GetCooldownTimeRemaining = 0      -- MUTATION
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local names, targets = {}, {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local a = e.args[1]
            names[#names + 1] = (type(a) == 'table' and a.GetName) and a:GetName() or tostring(a)
            local t = e.args[2]
            targets[#targets + 1] = (type(t) == 'table' and t.GetUnitName)
                and t:GetUnitName() or tostring(t)
        end
    end
    return names, targets, heroes
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

tests['end to end: shipped blasts the juggernaut it cannot kill'] = function()
    local names, targets = run_skills(false)
    assert(contains(names, Q_NAME),
        'shipped fires Hellfire Blast on this frame, got {' .. table.concat(names, ',') .. '}')
    assert(contains(targets, 'npc_dota_hero_juggernaut'),
        'and the target is the 160-HP juggernaut, got {' .. table.concat(targets, ',') .. '}')
end

tests['end to end: armed withholds it -- the final decision changes'] = function()
    local names, targets = run_skills(true)
    assert(not (contains(names, Q_NAME) and contains(targets, 'npc_dota_hero_juggernaut')),
        'the withdrawn kill claim must not reach the action queue, got {'
        .. table.concat(names, ',') .. '} on {' .. table.concat(targets, ',') .. '}')
end

tests['end to end: the gate only withdraws -- a target it really kills still gets blasted'] = function()
    -- MUTATION of the real frame: the same juggernaut at 100 HP, which BOTH
    -- readings kill (120 >= 100 and 168 >= 100). Armed must still fire.
    local X, _, bot, heroes, abilityQ = load_wk(true)
    rawget(abilityQ, '__spec').IsFullyCastable = true                        -- MUTATION
    rawget(heroes['npc_dota_hero_juggernaut'], '__spec').GetHealth = 100     -- MUTATION
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local fired = false
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') and type(e.args[1]) == 'table'
            and e.args[1]:GetName() == Q_NAME then fired = true end
    end
    assert(fired, 'armed must keep the kills the blast really does make')
end

-- ------------------------------------------------------- source-level wiring

tests['[ratchet][source] the gate stays on the hero kill-confirm, and only there'] = function()
    local f = assert(io.open('bots/BotLib/hero_skeleton_king.lua'))
    local src = f:read('*a')
    f:close()
    assert(src:find('J.CanKillTarget( npcEnemy, X.wk_GetBlastKillDamage( abilityQ ), nDamageType )', 1, true),
        'the hero kill-confirm must consume the gated claim')
    assert(src:find("J.IsSoakCandidate( 'wkqdmg' )", 1, true),
        'the helper must stay gated behind the wkqdmg candidate id')
    assert(src:find('J.IsModeTurbo() and J.IsSoakCandidate( \'wkqdmg\' )', 1, true),
        'and turbo-only')
    -- The creep branch reads the RAW nDamage and is deliberately out of scope:
    -- narrowing it would flip a `not J.CanKillTarget(...)` and change the branch
    -- in the opposite direction.
    assert(src:find('not J.CanKillTarget( targetCreep, nDamage, nDamageType )', 1, true),
        'the creep branch must keep reading the ungated nDamage')
end

return tests

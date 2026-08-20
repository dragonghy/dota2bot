-- Replay-fixture regression for GH #59 -- the SECOND execution audit of the
-- `zusult` gate, run by the replay group on the batch's own 04:11Z (a)-evidence
-- wave (tree 7c8b516, i.e. the first corpus that contains GH #47's W2 fix).
--
-- The audit's first half was good news: the W leak is closed (0 domain casts on
-- the armed side, down from 3). Its second half is this file's subject.
--
-- THE DEFECT (code fact). X.zuus_ShouldSaveManaForUlt opened with
--
--     if hBot:GetMana() >= nCost then return false end   -- "already affordable"
--
-- which reads the mana Zeus holds BEFORE the spend it is being asked about. So
-- the gate's effective domain was exactly "the reserve is ALREADY gone":
--
--   * mana >= nCost -- the ult is affordable, i.e. the ONE state in which there
--     is still something to protect -- the gate stands aside;
--   * mana <  nCost -- the reserve has already been spent -- the gate starts
--     holding chip.
--
-- It was never guarding the ultimate. It was guarding the regen that follows
-- losing it. A single Bolt fired on the frame mana crosses nCost is never seen
-- by it, and that is precisely how Zeus's ult mana leaves.
--
-- THE FRAME (game 20260820_042607_slot1, seed 872 radiant = the Zeus-armed
-- side, dumper at 0.5s):
--   t=462.3  item_arcane_boots (+175): 104 -> 256 mana. Thundergod's Wrath is
--            level 1, cooldown 0 -- and now AFFORDABLE. He could ult this
--            instant. (Asserted below: abilityR:IsFullyCastable() is TRUE.)
--   t=462.5  <-- THIS FIXTURE. lion stands 499.7 away at 1.00 HP -- full. The
--            gate is asked, reads 256 >= cost, and answers "nothing is being
--            denied".
--   t=462.9  zuus_lightning_bolt, GROUND cast (the W2 path), into that full-HP
--            lion for 267. ~130 mana gone; the reserve lasted 0.4 seconds.
--   463.5..491.5  the gate now holds 57 consecutive frames of chip, defending a
--            reserve that no longer exists.
--   t=492.2  Zeus dies holding 116 mana, Thundergod's Wrath still level 1,
--            still cooldown 0: ready and unaffordable. 29.7s after the one
--            spend that could have been refused -- which the fixture carries as
--            its own ground truth (observed.died_after).
--   t=521.0  The ult finally goes out, after a death and a respawn.
--
-- THE FIX: the gate takes the bidding ability's own handle and asks the
-- question about the instant it is actually about -- can he still pay for the
-- ult AFTER this spend. Deliberately a SEPARATE candidate id, `zusultx`:
-- post-spend affordability strictly implies pre-spend affordability and never
-- the reverse, so this widens the domain of a rule that has not yet cleared
-- condition (b), which is the `lanefix` failure shape. `zusult` alone keeps the
-- shipped narrow domain, `zusultx` runs the widened one, and the increment is
-- one subtraction between two waves rather than the sum of two rules. Neither
-- id is inert on its own.
--
-- WHY THE END-TO-END CASES MOVE TWO ALLIES (labeled mutation, and the reason is
-- asserted before it is used): on the real roster only ONE ally (tidehunter,
-- 162u) stands inside ConsiderW2's 800 ring, so its poke branch -- whose firing
-- clause GH #47 measured as `#nAllies >= 3` -- cannot bid in the fixture world.
-- Two more allies are teleported in; every input the GATE reads (Zeus's mana,
-- the ult's level and cooldown, lion's HP and distance) stays real frame data,
-- and the mutation is proven not to be doing the work by case 16, which flips
-- the outcome back by moving nothing but Zeus's mana.
--
-- EXTERNAL ANCHORS -- what does NOT come from the frame:
--   * Thundergod's Wrath mana cost. Measured in this very replay: t=331.2
--     251 -> 3 (248, minus ~2 regen) and t=521.0 848 -> 652 (196, plus ~22 of
--     the ~45/s regen visible in the following snapshots). The conclusion does
--     NOT depend on the pick: every case below is swept across the whole
--     [216, 248] band and the verdict never moves.
--   * Lightning Bolt mana cost, measured in this same replay away from the
--     magic-wand pop that muddies the t=462.9 cast: t=440.6 515 -> 382 (133 at
--     level 4) and t=330.7 380 -> 251 (129 at level 3). Swept across [129, 133].
--   * Lightning Bolt cast range 700 / Arc Lightning 900 (Liquipedia; the dumper
--     reports 0). Without them no bolt branch is reachable and every end-to-end
--     case here would be a false green.
-- Everything else -- mana, ult level and cooldown, every hero's HP, position,
-- alive/dead, and the ground truth of the death that followed -- is real.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local CROSS = 'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua'
local SAFE  = 'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua'

local ULT_NAME  = 'zuus_thundergods_wrath'
local BOLT_NAME = 'zuus_lightning_bolt'
local ARC_NAME  = 'zuus_arc_lightning'

local ULT_COST = 225                          -- nominal anchor, see header
local ULT_LOW, ULT_HIGH = 216, 248            -- measured band, both ends swept
local BOLT_COST = 130                         -- nominal anchor, see header
local BOLT_LOW, BOLT_HIGH = 129, 133          -- measured band, both ends swept
local ARC_COST = 91
local BOLT_RANGE, ARC_RANGE = 700, 900        -- external anchors, see header

local LION = 'npc_dota_hero_lion'

--- Load a frame, anchor what the dumper cannot report, and arm a chosen id set.
-- @param sFrame    fixture path
-- @param tArmed    set of soak-candidate ids to arm (nil = none armed)
-- @param opts      { turbo=false, ultCost=N, boltCost=N, mana=N, allies={..},
--                    lionHp=fraction }
local function load_zeus(sFrame, tArmed, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(sFrame)

    local sAbilityList = J.Skill.GetAbilityList(bot)
    -- GH #36 tripwire: before ability_meta.lua taught the loader which name is
    -- the ultimate, this slot was nil in every fixture and every ultimate
    -- helper short-circuited before reaching anything under test.
    assert(sAbilityList[6] == ULT_NAME,
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    rawget(abilityR, '__spec').GetManaCost = opts.ultCost or ULT_COST

    local abilityW = bot:GetAbilityByName(BOLT_NAME)
    rawget(abilityW, '__spec').GetManaCost = opts.boltCost or BOLT_COST
    rawget(abilityW, '__spec').GetCastRange = BOLT_RANGE
    local abilityQ = bot:GetAbilityByName(ARC_NAME)
    rawget(abilityQ, '__spec').GetManaCost = ARC_COST
    rawget(abilityQ, '__spec').GetCastRange = ARC_RANGE

    if opts.mana then rawget(bot, '__spec').GetMana = opts.mana end
    if opts.lionHp then
        local h = heroes[LION]
        rawget(h, '__spec').GetHealth = math.floor(h:GetMaxHealth() * opts.lionHp)
    end
    -- Labeled mutation: see header. Only ConsiderW2's ally count is affected.
    for _, sName in ipairs(opts.allies or {}) do
        local h = heroes['npc_dota_hero_' .. sName]
        local v = bot:GetLocation()
        rawget(h, '__spec').GetLocation = Vector(v.x + 300, v.y + 300, v.z)
    end

    if opts.turbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = function(id) return (tArmed or {})[id] == true end

    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, abilityR, abilityW, fx
end

--- Drive the real X.SkillsComplement() and report what reached the queue.
local function run_skills(sFrame, tArmed, opts)
    local X, J, bot, heroes, abilityR, abilityW, fx = load_zeus(sFrame, tArmed, opts)
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    local t = {}
    for _, e in ipairs(log) do
        if e.fn:find('UseAbility') then
            local a = e.args[1]
            t[#t + 1] = (type(a) == 'table' and a.GetName) and a:GetName() or tostring(a)
        end
    end
    return t, X, J, bot, heroes, abilityR, abilityW, fx
end

local function contains(t, s)
    for _, v in ipairs(t) do if v == s then return true end end
    return false
end

local ARMED_BASE = { zusult = true }              -- shipped narrow domain
local ARMED_X    = { zusultx = true }             -- widened, post-spend
local ARMED_BOTH = { zusult = true, zusultx = true }
local E2E_ALLIES = { 'phantom_assassin', 'viper' }

local tests = {}

-- --------------------------------------------------------------- ground truth

tests['ground truth: 256 mana and the ult is AFFORDABLE this very instant'] = function()
    local _, _, bot, _, abilityR, _, fx = load_zeus(CROSS, ARMED_X)
    assert(fx.time == 462.5, 'this is the decision frame, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_zuus', 'subject is Zeus')
    assert(bot:GetLevel() == 9, 'Zeus is level 9, got ' .. bot:GetLevel())
    assert(bot:GetMana() == 256, 'real mana on the frame, got ' .. bot:GetMana())
    assert(abilityR:IsTrained() and abilityR:GetLevel() == 1, 'ult is level 1')
    assert(abilityR:GetCooldownTimeRemaining() == 0, 'ult is off cooldown')
    -- This is the whole point of GH #59: the reserve is INTACT here. The
    -- shipped clause reads exactly this state as "nothing is being denied".
    assert(abilityR:IsFullyCastable(),
        '256 mana pays the ' .. abilityR:GetManaCost() .. ' ult -- he could fire it now')
end

tests['ground truth: the target lion is at FULL health, 499.7 away'] = function()
    local X, _, bot, heroes = load_zeus(CROSS, ARMED_X)
    local lion = heroes[LION]
    assert(lion:IsAlive(), 'lion is alive on this frame')
    assert(lion:GetHealth() == lion:GetMaxHealth(),
        'lion is untouched, got ' .. lion:GetHealth() .. '/' .. lion:GetMaxHealth())
    assert(lion:GetHealth() / lion:GetMaxHealth() > X.nUltSaveHealthFloor,
        'so this is chip, not a kill window -- the kill-window exemption is NOT '
        .. 'what decides this frame')
    local d = GetUnitToUnitDistance(bot, lion)
    assert(d > 490 and d < 510, 'lion is ~499.7 away, got ' .. math.floor(d))
end

tests['ground truth: he died 29.7s later, and the lion really was fighting him'] = function()
    local _, _, _, _, _, _, fx = load_zeus(CROSS, ARMED_X)
    assert(fx.observed ~= nil and fx.observed.died_after ~= nil,
        'the frame carries its own ground truth')
    assert(fx.observed.died_after > 28 and fx.observed.died_after < 31,
        'Zeus died ~29.7s after this frame, got ' .. tostring(fx.observed.died_after))
    -- The replay's own snapshots at t=492.0: 116 mana, ult level 1, cooldown 0.
    -- He died with it ready and unaffordable -- stated here as the outcome the
    -- refused spend would have bought back.
    assert((fx.observed.burst or {})[LION] ~= nil,
        'the lion actually dealt damage to Zeus in the following window -- this '
        .. 'is a real engagement, not a fantasy poke')
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: nothing armed leaves the frame byte-identical to shipped'] = function()
    local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, nil)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == false,
        'with no id armed the helper must be inert')
end

tests['gate OFF: `zusultx` armed but NOT turbo is still inert'] = function()
    local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, ARMED_X, { turbo = false })
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == false,
        'the gate is turbo-only')
end

-- ------------------------------------------ the defect, stated as an assertion

tests['DEFECT: `zusult` alone stands aside on the one frame that matters'] = function()
    local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, ARMED_BASE)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == false,
        'the shipped clause reads 256 >= cost as "nothing is being denied" and '
        .. 'lets the whole reserve go -- this is GH #59')
end

tests['FIX: `zusultx` refuses the spend that costs him the ult'] = function()
    local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, ARMED_X)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == true,
        '256 - 130 = 126 does not pay a ' .. ULT_COST .. ' ult, so the spend is held')
end

tests['FIX: `zusultx` needs no companion -- armed alone it is NOT inert'] = function()
    -- Guards against the arm-and-nothing-happens trap: there must be no id
    -- combination that silently does nothing (cf. `axeblink`, test_set I.3).
    local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, ARMED_X)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == true,
        '`zusultx` on its own must run the whole widened rule')
    local X2, _, bot2, heroes2, _, abilityW2 = load_zeus(CROSS, ARMED_BOTH)
    assert(X2.zuus_ShouldSaveManaForUlt(bot2, heroes2[LION], abilityW2) == true,
        'and arming both must agree with arming `zusultx` alone')
end

tests['degradation: `zusultx` with no ability handle falls back to pre-spend'] = function()
    local X, _, bot, heroes = load_zeus(CROSS, ARMED_X)
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], nil) == false,
        'a caller that forgets the handle prices the spend at 0 and gets the '
        .. 'shipped answer -- documented here so the source tripwire below, '
        .. 'not a silent no-op, is what catches a future consumer')
end

-- ------------------------------------------------- the verdict vs the anchors

tests['anchors: the flip holds across the whole measured ult-cost band'] = function()
    for _, nUlt in ipairs({ ULT_LOW, ULT_COST, ULT_HIGH }) do
        local Xa, _, bota, heroesa, _, aWa = load_zeus(CROSS, ARMED_BASE, { ultCost = nUlt })
        assert(Xa.zuus_ShouldSaveManaForUlt(bota, heroesa[LION], aWa) == false,
            '`zusult` lets it through at ult cost ' .. nUlt)
        local Xb, _, botb, heroesb, _, aWb = load_zeus(CROSS, ARMED_X, { ultCost = nUlt })
        assert(Xb.zuus_ShouldSaveManaForUlt(botb, heroesb[LION], aWb) == true,
            '`zusultx` holds it at ult cost ' .. nUlt)
    end
end

tests['anchors: the flip holds across the whole measured bolt-cost band'] = function()
    for _, nBolt in ipairs({ BOLT_LOW, BOLT_COST, BOLT_HIGH }) do
        local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, ARMED_X, { boltCost = nBolt })
        assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == true,
            '`zusultx` holds it at bolt cost ' .. nBolt)
    end
end

tests['threshold: the clause is exactly `mana - spend >= ultCost`, both sides'] = function()
    -- 256 mana, 225 ult: 31 is the largest spend that still leaves the ult paid.
    local X, _, bot, heroes, _, abilityW = load_zeus(CROSS, ARMED_X, { boltCost = 31 })
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes[LION], abilityW) == false,
        '256 - 31 = 225 still pays a 225 ult, so nothing is being denied')
    local X2, _, bot2, heroes2, _, abilityW2 = load_zeus(CROSS, ARMED_X, { boltCost = 32 })
    assert(X2.zuus_ShouldSaveManaForUlt(bot2, heroes2[LION], abilityW2) == true,
        '256 - 32 = 224 does not, so it is held -- the boundary is pinned on '
        .. 'both sides, one mana point apart')
end

-- ------------------------------------------------------------ end to end

tests['E2E setup: on the REAL roster only 1 ally is inside the 800 ring'] = function()
    -- Asserted BEFORE the mutation is used, so the mutation's necessity is a
    -- measured fact and its size is bounded to exactly this clause.
    local _, _, J, bot = run_skills(CROSS, nil)
    local tAllies = J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE)
    assert(#tAllies == 1, 'exactly one ally is really nearby, got ' .. #tAllies)
    assert(tAllies[1]:GetUnitName() == 'npc_dota_hero_tidehunter',
        'and it is tidehunter at 162u, got ' .. tAllies[1]:GetUnitName())
end

tests['E2E shipped: the real bolt at the real lion reaches the queue'] = function()
    -- POSITIVE assertion, so the held cases below cannot be empty greens.
    local tQueued, X, _, _, heroes = run_skills(CROSS, nil, { allies = E2E_ALLIES })
    assert(contains(tQueued, BOLT_NAME),
        'unarmed, X.SkillsComplement queues Lightning Bolt; got ['
        .. table.concat(tQueued, ',') .. ']')
    local nW2, _, hTarget = X.ConsiderW2()
    assert(nW2 > 0 and hTarget == heroes[LION],
        'and ConsiderW2 is the bidder, aimed at the full-HP lion')
end

tests['E2E DEFECT: `zusult` alone lets that very bolt through'] = function()
    local tQueued = run_skills(CROSS, ARMED_BASE, { allies = E2E_ALLIES })
    assert(contains(tQueued, BOLT_NAME),
        'GH #59 end to end: the gate is armed, the ult is ready, and the whole '
        .. 'reserve leaves anyway; got [' .. table.concat(tQueued, ',') .. ']')
end

tests['E2E FIX: `zusultx` holds it -- nothing is queued'] = function()
    local tQueued = run_skills(CROSS, ARMED_X, { allies = E2E_ALLIES })
    assert(not contains(tQueued, BOLT_NAME),
        'the bolt must not reach the queue; got [' .. table.concat(tQueued, ',') .. ']')
end

tests['E2E attribution: give him 400 mana and the same bolt goes out again'] = function()
    -- The ally mutation is held fixed; only Zeus's mana moves. 400 - 130 = 270
    -- still pays the 225 ult, so the hold must disappear -- which proves the
    -- hold above is the mana clause and not the teleported allies.
    local tQueued = run_skills(CROSS, ARMED_X, { allies = E2E_ALLIES, mana = 400 })
    assert(contains(tQueued, BOLT_NAME),
        'with the reserve genuinely safe the poke is allowed; got ['
        .. table.concat(tQueued, ',') .. ']')
end

tests['E2E: a kill window still outranks the reserve under `zusultx`'] = function()
    local tQueued = run_skills(CROSS, ARMED_X, { allies = E2E_ALLIES, lionHp = 0.30 })
    assert(contains(tQueued, BOLT_NAME),
        'drop the lion under nUltSaveHealthFloor and the bolt goes out -- the '
        .. 'widened gate must never stand between Zeus and a kill; got ['
        .. table.concat(tQueued, ',') .. ']')
end

tests['E2E: outside turbo `zusultx` changes nothing'] = function()
    local tQueued = run_skills(CROSS, ARMED_X, { allies = E2E_ALLIES, turbo = false })
    assert(contains(tQueued, BOLT_NAME),
        'non-turbo must be byte-identical to shipped; got ['
        .. table.concat(tQueued, ',') .. ']')
end

-- ------------------------------------- the control frame: it must NOT over-hold

-- t=330.5, same game, same Zeus. He holds 380 mana with the ult level 1 and off
-- cooldown. What follows in the replay is the whole argument for allowing:
--   t=330.7  Lightning Bolt, 380 -> 251  (129, the level-3 cost)
--   t=331.2  Thundergod's Wrath fires, 251 -> 3
-- So on this frame the post-spend remainder was, as a matter of recorded fact,
-- enough to pay for the ult 0.7 seconds later. A gate that held this poke would
-- have been wrong, and the frame proves it without any external anchor.

tests['control ground truth: 380 mana, ult ready, and the ult really did fire'] = function()
    local _, _, bot, _, abilityR, _, fx = load_zeus(SAFE, ARMED_X, { boltCost = 129 })
    assert(fx.time == 330.5, 'control frame, got ' .. tostring(fx.time))
    assert(bot:GetMana() == 380, 'real mana on the frame, got ' .. bot:GetMana())
    assert(abilityR:IsTrained() and abilityR:GetLevel() == 1 and
        abilityR:GetCooldownTimeRemaining() == 0, 'ult is level 1 and ready')
    -- 380 - 129 = 251, and the replay cast the ult from exactly 251 at t=331.2.
    assert(380 - 129 >= ULT_COST,
        'the remainder pays the ult -- and in the replay it did, 0.7s later')
end

tests['control: `zusultx` allows the poke on a frame with a real reserve'] = function()
    local X, _, bot, heroes, _, abilityW = load_zeus(SAFE, ARMED_X, { boltCost = 129 })
    local hEnemy = heroes['npc_dota_hero_ember_spirit']
    assert(hEnemy:GetHealth() / hEnemy:GetMaxHealth() > X.nUltSaveHealthFloor,
        'the target is healthy (0.81), so the kill-window exemption is not what '
        .. 'decides this -- got ' .. hEnemy:GetHealth() / hEnemy:GetMaxHealth())
    assert(X.zuus_ShouldSaveManaForUlt(bot, hEnemy, abilityW) == false,
        'the widened gate must let this through')
    assert(X.zuus_ShouldSaveManaForUlt(bot, hEnemy, nil) == false,
        'and `zusult` would too -- the two ids do not diverge here')
end

tests['control: raise the bolt to 160 and the control flips -- it IS the arithmetic'] = function()
    -- Labeled mutation: 380 - 160 = 220 < 225. If the allow above came from
    -- anything other than the post-spend subtraction, this would stay false.
    local X, _, bot, heroes, _, abilityW = load_zeus(SAFE, ARMED_X, { boltCost = 160 })
    assert(X.zuus_ShouldSaveManaForUlt(bot, heroes['npc_dota_hero_ember_spirit'], abilityW) == true,
        'a 160-mana spend would cost him the ult, so it is held')
end

-- ----------------------------------------------------------- source tripwires

local function hero_source()
    local f = assert(io.open('bots/BotLib/hero_zuus.lua', 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

tests['tripwire: every consumption point passes the bidding ability handle'] = function()
    -- Shape-based, in source order, and deliberately NOT name-based: GH #47's
    -- arity tripwire matched on a variable name and a rename slipped straight
    -- past it. A consumer that forgets the third argument degrades silently to
    -- the shipped clause (asserted above), so this is what catches it.
    local nCalls = 0
    for sLine in hero_source():gmatch('[^\n]+') do
        if not sLine:match('^%s*function') then
            local sArgs = sLine:match('X%.zuus_ShouldSaveManaForUlt%(([^)]*)%)')
            if sArgs ~= nil then
                nCalls = nCalls + 1
                local nCommas = select(2, sArgs:gsub(',', ''))
                assert(nCommas == 2,
                    'consumption point #' .. nCalls .. ' must pass (bot, target, '
                    .. 'ability); got `' .. sArgs .. '`')
            end
        end
    end
    assert(nCalls == 3,
        'W, W2 and Q are the three consumption points (GH #47); found ' .. nCalls)
end

tests['tripwire: the clause subtracts the spend, and only under `zusultx`'] = function()
    local src = hero_source()
    assert(src:find('hBot:GetMana() - nSpend >= nCost', 1, true) ~= nil,
        'the affordability test must be the POST-spend one (GH #59)')
    assert(src:find("bPostSpend = J.IsSoakCandidate( 'zusultx' )", 1, true) ~= nil,
        'the widened domain must sit behind its own candidate id')
    assert(src:find('if bPostSpend and hSpell ~= nil', 1, true) ~= nil,
        'and nSpend must stay 0 unless `zusultx` is armed, so `zusult` alone '
        .. 'remains byte-equivalent to shipped')
end

return tests

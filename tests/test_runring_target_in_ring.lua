-- [runring 20260913] "I CANNOT RUN, BUT I CAN KILL SOMEONE" NOW HAS TO BE
-- ABOUT SOMEONE IN THE FIGHT THE BOT IS STANDING IN.
--
-- ⭐ WHAT LANDED, IN ONE LINE: inside mode_retreat_generic's
-- X.LowChanceToRun, the first leg -- "the caller's target is killable" -- is
-- evaluated only when that target is one of the enemies in the 900 ring the
-- function ALREADY computed for its own outnumbered test. Off-ring, the leg is
-- skipped and the sibling loop eleven lines below decides. One conjunct, one
-- new soak id ('runring'), turbo-only.
--
-- ⭐ THE DEFECT, AND THE FILE'S OWN COUNTER-EXAMPLE ELEVEN LINES AWAY. The
-- function's outer gate is entirely local: `#nEnemysHeroes >= 3` where
-- `nEnemysHeroes = J.GetNearbyHeroes(bot, 900, true, ...)`, the bot below 40%,
-- damaged within the last second, moving slower than 330. Having established
-- "three or more people are on top of me and I am slow", it then asks whether
-- ONE hero is killable -- and for the first leg that hero is `botTarget`, while
-- for the loop directly below it is each member of `nEnemysHeroes`. The same
-- question, in the same `if` body, asked of two different domains: one bounded
-- at 900, one bounded by nothing at all.
--
-- ⭐ AND THE CALLER SUPPLIES THE UNBOUNDED ONE. `botTarget` is set once per
-- GetDesireHelper to `J.GetProperTarget(bot)`: `bot:GetTarget()` (the current
-- ORDER target) falling back to `bot:GetAttackTarget()`, filtered only by "not
-- one of our own heroes/buildings". No distance call of any kind appears in it.
-- §1 asserts that absence against the source rather than describing it, so the
-- day somebody leashes that helper this file goes red instead of quietly
-- overstating the domain. This is the THIRD consumer of that same unbounded
-- handle this desk has priced ('divepocket' and 'chasering' were the first
-- two, and all three live inside 380 lines of one another).
--
-- ⭐ (乙) SITE CENSUS BY THE TREE, NOT BY THE HOST. `X.LowChanceToRun` has
-- exactly ONE reader in the whole repository -- mode_retreat_generic.lua's own
-- retreat-desire ladder, where a true short-circuits the bid to
-- BOT_MODE_DESIRE_MODERATE and skips everything below it. §1 pins the census at
-- one definition + one call so a second consumer cannot appear unpriced.
--
-- ⭐ ONE-DIRECTIONAL AT THE PREDICATE, AND NOTHING IS CLAIMED ABOUT THE BID.
-- The added conjunct sits on an admission whose only outcome is `return true`,
-- so the armed TRUE set is a subset of the shipped one (§3 asserts the sign
-- rather than leaning on this paragraph). What happens to the retreat BID when
-- the answer flips is NOT closed-form -- the shipped `true` returns a flat 0.5
-- and the flipped `false` falls through to the rest of the ladder, which can
-- land above or below it. (子): no direction is claimed where none is proved.
--
-- ⭐⭐ THE ANSWER-LEVEL EFFECT IS ZERO ON THIS CORPUS **BY CONSTRUCTION**, NOT
-- BY SAMPLING, AND §2 PROVES THAT RATHER THAN ASSERTING IT. Both legs spend
-- `J.CanKillTarget(u, bot:GetAttackDamage() * 2.5, DAMAGE_TYPE_PHYSICAL)`, and
-- the replay dump carries no attack damage: the mock answers `GetAttackDamage()
-- == 0` for every hero on every frame, so the product is 0 and CanKillTarget is
-- false against any living unit. There is no frame in this corpus on which the
-- shipped leg can return true. Asked the (卯) question -- "is there a frame that
-- could make it non-zero?" -- the answer is no, so the zero is constructional
-- and this file therefore counts BRANCHES (§3) and buys its answer-level
-- reading from a counterfactual that declares exactly one fact (§4).
--
-- ⭐⭐ THE CORPUS IS ONE ROW, AND THAT IS THE HEADLINE READING, NOT A FOOTNOTE.
-- Driven over every live hero of every fixture -- 1,039 rows -- exactly ONE
-- reaches the outer gate. The leg census is `#enemies>=900-ring>=3` on 10 rows,
-- `hp<0.4` on 109, `recently damaged` on 70, and the conjunction on 1. This
-- desk has spent three rounds learning to say what a thin corpus is
-- ((壬)); here the honest form is: the SOURCE argument is what carries this
-- repair, and the frame corpus can price exactly one instant of it. A wave, not
-- another fixture round, is what would price the rest -- and the two dump
-- fields that would widen this domain are named in §2 and in the report.
--
-- ⚠️ AND ONE OF THE FIVE LEGS IS NOT MEASURED AT ALL, IT IS A MOCK CONSTANT.
-- `bot:GetCurrentMovementSpeed()` is not in the dump either; the mock answers a
-- flat 300 for every hero on every frame, so `< 330` is TRUE on 1,039 of 1,039
-- rows. §2 pins that 1039/1039 as the constant it is. Read the other way: the
-- one qualifying row qualifies partly because of an instrument default, so even
-- the single row is softer than its count suggests. Registering this is the
-- whole point -- an unregistered constant leg reads exactly like a satisfied
-- one.
--
-- ⭐ THE ONE ROW, IN FULL (f_260820_043039_cm_cask_close, t=515.5, turbo).
-- Crystal Maiden (a focus hero), Dire, 267/890 = 30.0%, damaged inside the last
-- second. Four enemies stand inside the 900 ring: witch_doctor 546.0,
-- slardar 571.0, shadow_shaman 609.5, lina 806.4. The FIFTH enemy, axe, is
-- 13,979.6 units away -- across the entire map. She is the only allied hero
-- within 1600 of herself; her three living team-mates are 10,677 to 14,313
-- units away. This is precisely the shape the repair is named for: whatever
-- `bot:GetTarget()` happens to hold for that CM, the question "can I kill him"
-- is a statement about her chances only if he is one of the four.
--
-- ⭐ THE AXIS IS INLINE, NEVER `J.IsExistInTable` -- (丑), earned this morning.
-- The shipped repair splits the domain with `J.IsExistInTable`; if this file
-- split it the same way, a mutant that breaks that helper would collapse the
-- measurement and the subject together and score as CAUGHT by the wrong
-- section. Every in-ring/off-ring decision below is an inline identity loop
-- over a distance-filtered list built here.
--
-- ⚠️ CORPUS LIMITS, registered rather than worked around:
--   (i)  no attack damage in the dump (above) -- makes the answer flip
--        structurally 0, which is why §3 counts branches.
--  (ii)  no movement speed in the dump (above) -- one of the five gate legs is
--        a constant.
-- (iii)  no attack-target field in the dump (GH #786), so this corpus cannot
--        say how OFTEN a real bot:GetTarget() sits outside the ring -- only
--        what happens when it does. No rate is claimed anywhere below.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local RETREAT = 'bots/mode_retreat_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local PIN = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'
local PIN_HERO = 'npc_dota_hero_crystal_maiden'
local FAR_ENEMY = 'npc_dota_hero_axe'
local NEAR_ENEMY = 'npc_dota_hero_witch_doctor'
local RING_R = 900

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function fn_block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction ', at + 10) or #src
    return src:sub(at, stop)
end

local RETREAT_SRC = read_file(RETREAT)
local JMZ_SRC = read_file(JMZ)
local HOST = fn_block(RETREAT_SRC, 'function X.LowChanceToRun()')
local PROPER = fn_block(JMZ_SRC, 'function J.GetProperTarget( bot )')

-- ---------------------------------------------------------------------------
-- The world. `opts.target` names the hero bot:GetTarget() hands back, which is
-- the ONLY way this corpus can supply a botTarget at all (limit (iii)).
-- ---------------------------------------------------------------------------
local function world(path, hero, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path, hero)
    for k, v in pairs(DESIRE) do _G[k] = v end
    GetPushLaneDesire = function() return 0 end     -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end   -- luacheck: ignore
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', {})
    rawset(bot, 'DefendLaneDesire', {})

    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == 'runring'
    end

    if opts.target ~= nil then
        local h = assert(heroes[opts.target], opts.target .. ' is not on this frame')
        rawset(bot, 'GetTarget', function() return h end)
    end

    -- The recorder. Every unit J.CanKillTarget is asked about, in order. The
    -- unbounded leg is always the FIRST call inside X.LowChanceToRun (nothing
    -- else in the function spends CanKillTarget before it), so the sequence
    -- separates the leg from the sibling loop without depending on a line
    -- number that any edit to the host would move.
    local seen = {}
    local real_cankill = J.CanKillTarget
    J.CanKillTarget = function(u, dmg, dt)
        seen[#seen + 1] = u
        -- `opts.killable` is the ONE declared fact of the §4 counterfactual: a
        -- set of hero names this bot can finish with 2.5 attacks. It stands in
        -- for GetAttackDamage, which the dump does not carry. Declared, never
        -- measured; absent everywhere except §4 and §5.
        if opts.killable ~= nil then
            return opts.killable[u:GetUnitName()] == true
        end
        return real_cankill(u, dmg, dt)
    end

    GetDesire, Think = nil, nil -- luacheck: ignore
    local X = assert(dofile(RETREAT), RETREAT .. ' did not return its X table')
    assert(type(X.LowChanceToRun) == 'function', 'X.LowChanceToRun is gone')
    -- Populates the file-locals (botTarget, botHP, nAllyHeroes). Its own return
    -- value is not used: this file measures one helper, not the auction.
    pcall(GetDesire)
    GetDesire, Think = nil, nil -- luacheck: ignore

    local function run()
        for i = #seen, 1, -1 do seen[i] = nil end
        local answer = X.LowChanceToRun()
        return answer, seen
    end
    return J, bot, heroes, fx, run
end

--- The classification axis: inline identity, never the helper under test (丑).
local function ring_of(bot, heroes)
    local ring = {}
    for _, u in pairs(heroes) do
        if u ~= bot and u:IsAlive() and u:GetTeam() ~= bot:GetTeam()
            and GetUnitToUnitDistance(bot, u) <= RING_R
        then
            ring[#ring + 1] = u
        end
    end
    return ring
end

local function in_ring(u, ring)
    for _, r in ipairs(ring) do if r == u then return true end end
    return false
end

-- ------------------------------------------------------------- §1 source ---

tests['[runring] 1. the two domains, the gate, the unbounded handle, one caller'] = function()
    assert(HOST ~= nil, 'X.LowChanceToRun is gone from ' .. RETREAT)
    assert(PROPER ~= nil, 'J.GetProperTarget is gone from ' .. JMZ)

    -- (a) The two domains inside one `if` body -- the defect, quoted.
    assert(HOST:find('J.GetNearbyHeroes(bot, ' .. RING_R .. ', true', 1, true) ~= nil,
        'the 900 ring the outer gate counts is gone or moved; this file\'s axis '
        .. 'and the repair both name that radius.')
    assert(HOST:find('for _, enemy in pairs(nEnemysHeroes) do', 1, true) ~= nil,
        'the sibling loop over the ring is gone -- it is the in-file evidence '
        .. 'that the bounded form of this question is the intended one.')
    assert(HOST:find('J.CanKillTarget(botTarget,', 1, true) ~= nil,
        'the unbounded leg no longer asks CanKillTarget of botTarget; this '
        .. 'repair is about that call and nothing else.')

    -- (b) The repair, and its gate. Turbo-only, single id, still soak-gated.
    assert(HOST:find("J.IsSoakCandidate('runring')", 1, true) ~= nil,
        'the runring gate is gone from the host. If it was PROMOTED, this file '
        .. 'must be re-read as a shipped-behaviour test, not a soak test.')
    assert(HOST:find('J.IsModeTurbo()', 1, true) ~= nil,
        'the repair is no longer turbo-only.')
    assert(HOST:find('J.IsExistInTable(botTarget, nEnemysHeroes)', 1, true) ~= nil,
        'the repair no longer splits the domain by identity in the ring.')

    -- (c) THE UNBOUNDED HANDLE, ASSERTED AS AN ABSENCE. The moment somebody
    --     leashes GetProperTarget, the premise of this whole file is wrong and
    --     it should go red rather than keep claiming an unbounded domain.
    for _, probe in ipairs({ 'GetUnitToUnitDistance', 'IsInRange', 'GetLocation',
                             'DistanceFrom', 'NearLoc', 'Nearby' }) do
        assert(PROPER:find(probe, 1, true) == nil,
            'J.GetProperTarget now contains "' .. probe .. '" -- it may no '
            .. 'longer be the unbounded handle this repair is priced against.')
    end

    -- (d) (乙) census: one definition, one caller, in the whole tree.
    local defs, calls = 0, 0
    local p = io.popen('grep -rn "LowChanceToRun" bots/ 2>/dev/null')
    for line in p:lines() do
        if line:find('function X.LowChanceToRun', 1, true) then defs = defs + 1
        elseif line:find('X.LowChanceToRun()', 1, true) then calls = calls + 1 end
    end
    p:close()
    assert(defs == 1 and calls == 1,
        'the LowChanceToRun census moved: ' .. defs .. ' definition(s), ' .. calls
        .. ' call site(s), was 1 and 1. A second consumer is a second domain '
        .. 'and has not been priced.')
end

-- --------------------------------------------------- §2 domain + instrument --

local SWEEP = { rows = 0, gate = 0, leg_ring3 = 0, leg_lowhp = 0, leg_dmg = 0,
                leg_slow = 0, atk0 = 0 }
local GATE_ROWS = {}

do
    local files = {}
    local p = io.popen('ls tests/fixtures/*.lua')
    for line in p:lines() do files[#files + 1] = line end
    p:close()

    for _, path in ipairs(files) do
        local _, subj0, heroes0 = rf.load(path)
        local names = {}
        for nm, u in pairs(heroes0) do
            if u:IsAlive() then names[#names + 1] = nm end
        end
        table.sort(names)
        for _, nm in ipairs(names) do
            local _, bot, heroes = rf.load(path, nm)
            SWEEP.rows = SWEEP.rows + 1
            local ring = ring_of(bot, heroes)
            local allies = 0
            for _, u in pairs(heroes) do
                if u:IsAlive() and u:GetTeam() == bot:GetTeam()
                    and GetUnitToUnitDistance(bot, u) <= 1600 then allies = allies + 1 end
            end
            local hp = bot:GetHealth() / bot:GetMaxHealth()
            local l_ring = #ring >= 3 and #ring >= allies
            local l_hp = hp < 0.4
            local l_dmg = bot:WasRecentlyDamagedByAnyHero(1) == true
            local l_slow = bot:GetCurrentMovementSpeed() < 330
            if l_ring then SWEEP.leg_ring3 = SWEEP.leg_ring3 + 1 end
            if l_hp then SWEEP.leg_lowhp = SWEEP.leg_lowhp + 1 end
            if l_dmg then SWEEP.leg_dmg = SWEEP.leg_dmg + 1 end
            if l_slow then SWEEP.leg_slow = SWEEP.leg_slow + 1 end
            if bot:GetAttackDamage() == 0 then SWEEP.atk0 = SWEEP.atk0 + 1 end
            if l_ring and l_hp and l_dmg and l_slow then
                SWEEP.gate = SWEEP.gate + 1
                GATE_ROWS[#GATE_ROWS + 1] = { path = path, hero = nm,
                                              hp = hp, ring = #ring }
            end
            subj0 = nil -- luacheck: ignore
        end
    end
end

tests['[runring] 2. one row in 1,039 -- and two of the five legs are constants'] = function()
    assert(SWEEP.rows == 1039,
        'the corpus changed size: ' .. SWEEP.rows .. ' live hero rows, was 1039. '
        .. 'Every count below is quoted against that denominator.')

    -- (a) THE HEADLINE. One row. Said as a number so it cannot soften into
    --     "the corpus supports the repair".
    assert(SWEEP.gate == 1,
        'the number of rows reaching X.LowChanceToRun\'s outer gate is now '
        .. SWEEP.gate .. ', was 1. More rows is GOOD news and this file should '
        .. 'be re-read to use them; fewer means the one pin frame is gone.')
    assert(#GATE_ROWS == 1 and GATE_ROWS[1].hero == PIN_HERO
        and GATE_ROWS[1].path == PIN,
        'the single qualifying row is no longer ' .. PIN_HERO .. ' on ' .. PIN)

    -- (b) The funnel, so a future reader can see WHICH leg is scarce. The ring
    --     leg is the binding one: 10 rows in 1039 have three enemies inside 900
    --     and no more allies than that.
    assert(SWEEP.leg_ring3 == 10, 'ring leg moved: ' .. SWEEP.leg_ring3 .. ', was 10')
    assert(SWEEP.leg_lowhp == 109, 'hp leg moved: ' .. SWEEP.leg_lowhp .. ', was 109')
    assert(SWEEP.leg_dmg == 70, 'damage leg moved: ' .. SWEEP.leg_dmg .. ', was 70')

    -- (c) ⚠️ THE TWO INSTRUMENT CONSTANTS, PINNED AS COUNTS. Neither is a
    --     measurement; both read exactly like one if nobody writes them down.
    assert(SWEEP.leg_slow == SWEEP.rows,
        'the movement-speed leg is no longer constant across the corpus ('
        .. SWEEP.leg_slow .. '/' .. SWEEP.rows .. '). The dump has grown a '
        .. 'speed field -- the gate row count above is now a real measurement '
        .. 'and this file should be re-read.')
    assert(SWEEP.atk0 == SWEEP.rows,
        'GetAttackDamage is no longer 0 on every row (' .. SWEEP.atk0 .. '/'
        .. SWEEP.rows .. '). The answer-level flip stops being structurally '
        .. 'zero: §3 can be upgraded from a branch count to an answer count, '
        .. 'and §4\'s declared fact should be replaced by the measured one.')
end

-- ----------------------------------------------------- §3 branch counting ---

-- Four arms on the one row: shipped/armed x each candidate botTarget. The
-- load-bearing reading is `leg_reached`, taken by watching WHICH unit
-- J.CanKillTarget is asked about first -- not by watching the answer, which
-- §2(c) proves is structurally false here. (癸): count branches, not answers.
local ARMS = { a = {}, b = {} }
local PAIRS = { off = 0, inr = 0 }
local FLIP = { ab = 0, ba = 0 }

do
    local _, bot0, heroes0 = rf.load(PIN, PIN_HERO)
    local ring0 = ring_of(bot0, heroes0)
    local names = {}
    for nm, u in pairs(heroes0) do
        if u:IsAlive() and u:GetTeam() ~= bot0:GetTeam() then names[#names + 1] = nm end
    end
    table.sort(names)

    for _, nm in ipairs(names) do
        local off = true
        for _, r in ipairs(ring0) do if r:GetUnitName() == nm then off = false end end
        if off then PAIRS.off = PAIRS.off + 1 else PAIRS.inr = PAIRS.inr + 1 end

        for _, arm in ipairs({ 'a', 'b' }) do
            local _, bot, heroes, _, run = world(PIN, PIN_HERO,
                { armed = (arm == 'b'), target = nm })
            local ring = ring_of(bot, heroes)
            local answer, seen = run()
            local tgt = heroes[nm]
            ARMS[arm][nm] = {
                answer = answer,
                leg_reached = (seen[1] == tgt) and not in_ring(tgt, ring),
                leg_reached_any = (seen[1] == tgt),
                ncalls = #seen,
            }
        end
        if ARMS.a[nm].answer and not ARMS.b[nm].answer then FLIP.ab = FLIP.ab + 1 end
        if ARMS.b[nm].answer and not ARMS.a[nm].answer then FLIP.ba = FLIP.ba + 1 end
    end
end

tests['[runring] 3. the branch closes off-ring, stays open in-ring, sign is one-way'] = function()
    assert(PAIRS.off == 1 and PAIRS.inr == 4,
        'the pin frame\'s split moved: ' .. PAIRS.off .. ' off-ring / '
        .. PAIRS.inr .. ' in-ring enemies, was 1 and 4.')

    -- (a) THE LOAD-BEARING READING. Shipped consults the off-ring target;
    --     armed does not. One pair, and the file says so out loud rather than
    --     dressing 1 up as a population.
    local a_off, b_off = 0, 0
    for _, r in pairs(ARMS.a) do if r.leg_reached then a_off = a_off + 1 end end
    for _, r in pairs(ARMS.b) do if r.leg_reached then b_off = b_off + 1 end end
    assert(a_off == 1, 'shipped reached the unbounded leg on ' .. a_off
        .. ' off-ring pair(s), expected exactly 1 (' .. FAR_ENEMY .. ').')
    assert(b_off == 0, 'armed still reached the unbounded leg on ' .. b_off
        .. ' off-ring pair(s). The conjunct is not doing its job.')

    -- (b) (庚) THE POSITIVE CONTROL: the leg is still ALIVE after the repair.
    --     A narrowing that closes the branch everywhere is indistinguishable
    --     from deleting it, and this arm is what tells them apart.
    local b_in = 0
    for nm, r in pairs(ARMS.b) do
        local off = (nm == FAR_ENEMY)
        if r.leg_reached_any and not off then b_in = b_in + 1 end
    end
    assert(b_in == PAIRS.inr, 'armed reached the leg on only ' .. b_in .. ' of '
        .. PAIRS.inr .. ' in-ring pairs -- the repair has narrowed past its '
        .. 'stated domain and is now suppressing the fight it is supposed to '
        .. 'be about.')

    -- (c) THE SIGN. Predicate-level, closed form (the conjunct sits on an
    --     admission whose only outcome is `return true`).
    assert(FLIP.ba == 0, 'armed answered true where shipped answered false on '
        .. FLIP.ba .. ' pair(s). The repair is supposed to be strictly '
        .. 'narrowing at the predicate; it is not.')

    -- (d) ⚠️ A REAL READING, EXPLICITLY NON-DISCRIMINATING. flip_ab is 0
    --     because §2(c)'s GetAttackDamage == 0 makes CanKillTarget false for
    --     everyone -- not because the repair does nothing. Kept because
    --     deleting it loses information; labelled because leaving it unlabelled
    --     would mislead the next reader. (癸)
    assert(FLIP.ab == 0, 'flip_ab is ' .. FLIP.ab .. ', was 0. The corpus has '
        .. 'gained a damage model -- this reading is now discriminating and '
        .. 'should be promoted out of this note.')
end

-- ------------------------------------------------- §4 the counterfactual ---

tests['[runring] 4. counterfactual: one declared fact, one real frame'] = function()
    -- ⭐ THE DECLARED FACT, WORD FOR WORD, AND IT IS THE ONLY ONE: on this
    --   frame, the set of heroes this Crystal Maiden can finish with 2.5
    --   attacks is { axe }. Nothing else is declared. Everything else below --
    --   her health, the four bodies inside 900, axe's 13,979.6 units -- is read
    --   off the frame. The declaration stands in for GetAttackDamage, which the
    --   dump does not carry (§2(c)); when it does, this becomes a measurement.
    local declared = { [FAR_ENEMY] = true }

    local Ja, bota, heroesa, fx, runa = world(PIN, PIN_HERO,
        { armed = false, target = FAR_ENEMY, killable = declared })
    assert(Ja.IsModeTurbo(), 'the pin frame is turbo -- the gate is turbo-only')
    assert(math.abs(fx.time - 515.5) < 1e-9, 'pinned at t=515.5')
    assert(bota:GetUnitName() == PIN_HERO and bota:GetTeam() == 3,
        'the subject is the Dire crystal maiden')
    assert(bota:GetHealth() == 267 and bota:GetMaxHealth() == 890, '267/890 = 30.0%')
    local ring = ring_of(bota, heroesa)
    assert(#ring == 4, 'four enemies inside ' .. RING_R .. '; got ' .. #ring)
    local d_far = GetUnitToUnitDistance(bota, heroesa[FAR_ENEMY])
    assert(d_far > 13000, FAR_ENEMY .. ' is ' .. string.format('%.1f', d_far)
        .. ' units away; the argument is that this is the other side of the map.')

    local ans_a = runa()
    assert(ans_a == true,
        'shipped did not answer "low chance to run" from a hero '
        .. string.format('%.1f', d_far) .. ' units away. The counterfactual has '
        .. 'stopped reproducing the defect.')

    local _, _, _, _, runb = world(PIN, PIN_HERO,
        { armed = true, target = FAR_ENEMY, killable = declared })
    local ans_b = runb()
    assert(ans_b == false,
        'armed still answered true. With axe out of the ring and nobody in it '
        .. 'declared killable, the only true left would have to come from the '
        .. 'sibling loop -- which is exactly what the repair leaves alone.')
end

tests['[runring] 5. the same declared fact, moved into the ring, changes nothing'] = function()
    -- ⭐ The mirror of §4 and the file's "assertion is not vacuously true" leg:
    --   move the ONE declared killable hero from 13,979.6u to 546.0u and the
    --   repair must become a no-op, answer AND branch. If this arm ever
    --   disagrees with shipped, the conjunct is rejecting members of the very
    --   ring it was written to protect.
    local declared = { [NEAR_ENEMY] = true }
    local outs = {}
    for _, armed in ipairs({ false, true }) do
        local _, bot, heroes, _, run = world(PIN, PIN_HERO,
            { armed = armed, target = NEAR_ENEMY, killable = declared })
        local d = GetUnitToUnitDistance(bot, heroes[NEAR_ENEMY])
        assert(d < RING_R, NEAR_ENEMY .. ' left the ring (' .. string.format('%.1f', d)
            .. 'u); this control no longer controls anything.')
        local answer, seen = run()
        outs[#outs + 1] = { answer = answer, ncalls = #seen,
                            first = seen[1] and seen[1]:GetUnitName() or nil }
    end
    assert(outs[1].answer == true and outs[2].answer == true,
        'in-ring, the two worlds disagree on the answer: shipped '
        .. tostring(outs[1].answer) .. ', armed ' .. tostring(outs[2].answer))
    assert(outs[1].ncalls == outs[2].ncalls and outs[1].ncalls == 1,
        'in-ring, the two worlds spent a different number of CanKillTarget '
        .. 'calls (' .. outs[1].ncalls .. ' vs ' .. outs[2].ncalls .. '); the '
        .. 'leg should fire first and return, in both.')
    assert(outs[1].first == NEAR_ENEMY and outs[2].first == NEAR_ENEMY,
        'the first unit consulted is no longer the caller\'s target.')
end

return tests

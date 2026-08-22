-- Replay-fixture regression for hero.md backlog #7 SECOND LEVER.
--
-- FIRST LEVER (already shipped): X.lion_IsDrainSafeToStart, gate `liondrain`,
-- refuses to START a channel when a hero is currently killing Lion AND inside
-- X.nEDrainDangerRadius. Test: tests/test_replay_260819_lion_drain.lua.
--
-- WHAT THIS LEVER ADDS: even a channel that starts CLEAN (no hero pressure at
-- t0) can turn unsafe -- an enemy walks in or begins hitting Lion during it,
-- and the start-guard has already passed judgement. The shipped release,
-- X.ConsiderStopDrain, then only breaks off on J.IsRetreating(bot); but by
-- construction a rooted hero is not walking home, so retreat mode does not
-- kick in and Lion stands his 5-second channel to the end.
--
-- OBSERVATION (the 5-game census the first lever built -- same replays, same
-- dumper, same event-stream ground truth for channel windows):
--   game 20260819_182855, MODIFIER_ADD t=297.2 -> MODIFIER_REMOVE t=302.2
--   (5.0s channel, target viper). Under the pre-#liondrainstop shipped code
--   Lion held the channel for its whole 5s: position (-5084, 5284) does not
--   move a single unit from t=297.2 to t=302.2. Damage to Lion in that window
--   (from the same replay's DAMAGE event stream, real not inferred):
--     t=297.6 +10 (viper poison), t=297.7 +12 (corrosive), t=297.8 +7 predator
--             +59 (attack), t=298.6 +20 poison, t=298.7 +13 corrosive
--             +11 predator +50 attack, t=299.6 +20 poison, t=300.6 +20 poison,
--             t=301.6 +20 poison, t=302.2 +71 earthshaker echo slam.
--   257 damage over 5s, all from heroes; ES caught him with echo at 302.2
--   because he was stationary. The channel started before the guard could see
--   the pressure and there was nothing to break it off with.
--
-- THE PINNED FRAME (A), FOCUSED mid-channel, t=299.2 (2.0s into the channel):
--   Lion 510/824 (62%), 171/584 mana; lion_mana_drain cd=10.3 (mid-channel
--   cooldown; the ability's cd starts on cast even while the channel runs).
--   Viper is at (-5474, 4997), 484u away -- inside X.nEDrainDangerRadius (500).
--   Recent damage from the same DAMAGE event stream in the previous 2s:
--   t=298.6-299.2 was another viper attack chain (13+11+50 magical/physical
--   + 20 poison), so WasRecentlyDamagedByAnyHero(2) is TRUE. Ground truth
--   died_after = 15.9s (past the fixture window; he survived this channel by
--   ~2s of HP, but the guard's job is to release the root before echo slam
--   lands, not to save every death).
--
-- THE CONTROL FRAME (B), JUNGLE mid-channel, t=247.0 (2.7s into the channel
-- on a neutral dark_troll_warlord, which lasted t=244.3 -> t=248.6 per the
-- MODIFIER_ADD/REMOVE pair):
--   Lion in the Radiant jungle at (3871, -3728), 184 HP / 274 mana. Nearest
--   ALIVE enemy hero is necrolyte at 6033u; every other alive enemy hero is
--   7754u+ across the map (drow_ranger is a corpse on this frame). Recent
--   damage in the previous
--   2s is CREEP only (troll pack hitting him -- three troll_warlord hits +
--   one troll hit inside the window), so WasRecentlyDamagedByAnyHero(2) is
--   FALSE. Ground truth died_after = 68.1s. Same channeling world state as
--   frame A but neither clause of the AND holds, so the release must NOT
--   fire even when armed -- the discriminator is not "is he channeling" but
--   "is a hero currently killing him inside the danger radius".
--
-- FRAME B WAS HEALED 2026-08-22 (strategy backlog 0c) AND THE HEAL MOVED THE
-- INSTANT. The numbers above are the healed ones; the pre-heal file said 188 HP
-- / 284 mana and necrolyte at 5995u. Regenerating this frame at the SAME
-- `--t 247.0` did not just add the missing fields -- it landed on a DIFFERENT
-- sample, ~0.33s earlier in state time. Everything derived from the event
-- stream (recent_damage, observed.burst, observed.died_after = 68.1) came back
-- byte-identical, so it is the hero-snapshot stream alone that moved. The
-- measurement, the four heroes that agree on it, and what it costs are in the
-- RE-READ section at the bottom of this file; the discriminator survives it
-- (a 38u move against a 5500u margin), but two assertions in the ground-truth
-- case were written to 10u / 4hp bands and had to be rewritten.
--
-- EXTERNAL ANCHORS -- what is NOT read off the frame (declared, not hidden):
--   1. Mana Drain cast range = 600 (Liquipedia, 2026-08). Same as the start-
--      lever test. The stop-lever's own predicate does not read cast range;
--      it reads the 500u danger radius. Kept for symmetry with the start test.
--   2. IsChanneling() is a native engine call; the .dem records no per-frame
--      channel flag, only the MODIFIER_ADD/REMOVE events on the drain target.
--      This test declares IsChanneling() = true on the subject as a labelled
--      MUTATION whose ground truth is the pair (297.2, 302.2) or (244.3,
--      248.6) from the same replay's event stream.
--   3. The drain target's modifier_lion_mana_drain: same source (event stream),
--      set as a labelled mutation on the target hero for frame A. Frame B
--      targets a neutral creep the fixture generator does not carry, so the
--      predicate the STOP-guard evaluates is IsAbilityEChanneling's OUTER
--      branch (bot:IsChanneling()) plus the two AND clauses that ARE readable
--      from the frame (recent damage, nearby heroes) -- for frame B those two
--      are the only load-bearing bits.
--   4. GetActiveMode / GetAttackTarget are not in the dump; declared as
--      labelled mutations in the end-to-end helper below.
-- Everything else -- every hero's position, HP, mana, level, ability levels
-- and cooldowns, inventory, alive/dead, WasRecentlyDamagedBy* history, and
-- the death ground truth -- is real frame data.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FOCUSED = 'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua' -- must RELEASE
local JUNGLE  = 'tests/fixtures/f_260819_182855_lion_drain_jungle.lua'     -- must HOLD

local DRAIN_CAST_RANGE = 600        -- external anchor, see header

--- Load a frame and mark Lion as mid-channel. `bChanneling` writes
--- bot:IsChanneling() (the native engine flag the .dem does not carry; ground
--- truth is the MODIFIER_ADD/REMOVE pair in the same replay's event stream --
--- 297.2..302.2 for frame A, 244.3..248.6 for frame B). `bTargetHasMod` adds
--- modifier_lion_mana_drain to the drain target so X.IsAbilityEChanneling's
--- inner loop can confirm the channel. For frame B the drain target is a
--- neutral creep the fixture does not carry, so the inner loop finds nothing
--- there and IsAbilityEChanneling returns false -- documented below.
local function load_lion(path, bArmed, bChanneling, bTargetHasMod, bTurbo)
    local J, bot, heroes, fx = rf.load(path)

    rawget(bot:GetAbilityByName('lion_mana_drain'), '__spec').GetCastRange = DRAIN_CAST_RANGE

    if bChanneling then
        rawget(bot, '__spec').IsChanneling = true
    end

    if bTargetHasMod and path == FOCUSED then
        -- Real drain target on the pinned window is viper (MODIFIER_ADD's
        -- target field at t=297.2). Add the modifier via HasModifier only --
        -- the shipped scan reads only HasModifier, not NumModifiers.
        local v = heroes['npc_dota_hero_viper']
        rawget(v, '__spec').HasModifier = function(_, sName)
            return sName == 'modifier_lion_mana_drain'
        end
    end

    if bTurbo == false then
        GetGameMode = function() return GAMEMODE_ALLPICK end
    end
    J.IsSoakCandidate = bArmed
        and function(id) return id == 'liondrainstop' end
        or function() return false end

    local X = rf.load_hero('lion')
    return X, J, bot, heroes, fx
end

local tests = {}

-- ---------------------------------------------------------------- ground truth

tests['ground truth A: mid-channel, viper 484u, hero pressure, would die if held to end of window'] = function()
    local X, _, bot, heroes, fx = load_lion(FOCUSED, true, true, true)
    assert(fx.time == 299.2, 'fixture A is the mid-channel frame, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_lion', 'subject is Lion')
    assert(bot:GetHealth() == 510 and bot:GetMaxHealth() == 824,
        'real HP on the frame, got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:GetMana() == 171, 'real mana on the frame, got ' .. bot:GetMana())

    -- Channel precondition: IsAbilityEChanneling must be true, otherwise the
    -- STOP guard has no reason to run at all on this frame.
    assert(bot:IsChanneling() == true, 'IsChanneling is the declared mutation')
    assert(X.IsAbilityEChanneling() == true,
        'the enemy target carries modifier_lion_mana_drain in the 1200u scan')

    local viper = heroes['npc_dota_hero_viper']
    assert(viper:IsAlive(), 'the threat is alive')
    local d = GetUnitToUnitDistance(bot, viper)
    assert(d > 480 and d < 490, 'viper is ~484 away, got ' .. math.floor(d))
    assert(d < X.nEDrainDangerRadius, 'and inside the danger radius')

    -- Hero pressure in the last 2s -- straight from the recent_damage rows the
    -- fixture generator wrote (dt<=2, kind='hero'). Read via the same public
    -- reader the helper uses so any refactor of that predicate breaks here too.
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'four hero damage rows inside the last 2s, all from viper')

    -- Ground truth from the following 15.9s: Lion barely survived this channel
    -- (echo slam at t=302.2 dropped him to 249), then walked to safety.
    assert(fx.observed.died_after ~= nil and fx.observed.died_after > 15.0,
        'Lion survived this specific channel by ~2s of HP, got ' .. tostring(fx.observed.died_after))
end

tests['ground truth B: mid-channel on a jungle creep, no hero in radius, no hero damage'] = function()
    local X, _, bot, heroes, fx = load_lion(JUNGLE, true, true, false)
    assert(fx.time == 247.0, 'fixture B is the mid-channel jungle frame, got ' .. tostring(fx.time))
    -- Healed values (see the header): the pre-heal file said 188 / 284, which
    -- is the same nominal instant sampled ~0.33s later in state time.
    assert(bot:GetHealth() == 184, 'real HP on the frame, got ' .. bot:GetHealth())
    assert(bot:GetMana() == 274, 'real mana on the frame, got ' .. bot:GetMana())

    -- IsChanneling is declared, but the drain target is a NEUTRAL CREEP the
    -- fixture does not carry; X.IsAbilityEChanneling's inner loop finds
    -- nothing near, so it returns false. The STOP guard rides on the same
    -- IsAbilityEChanneling early-out as the shipped release, so failing here
    -- is the correct discriminator for a jungle channel with no threats.
    assert(bot:IsChanneling() == true, 'IsChanneling is the declared mutation')
    assert(X.IsAbilityEChanneling() == false,
        'no enemy carries the drain modifier within the 1200u scan (creep target absent from the fixture)')

    -- The two predicate clauses independently: viper is ~13k away, drow (nearest
    -- enemy hero) is at ~1795u, and no hero damage exists inside the 2s window
    -- (the four DAMAGE rows in the fixture are all `kind = 'creep'`).
    local d = GetUnitToUnitDistance(bot, heroes['npc_dota_hero_necrolyte'])
    -- Band widened on purpose after the heal moved the instant: necrolyte moved
    -- 38u (5995 -> 6033) while the clause this case exists for has 5500u of
    -- margin. The old 10u band would have failed on a frame whose conclusion
    -- never budged -- see the RE-READ section.
    assert(d > 5900 and d < 6100, 'nearest ALIVE enemy hero (necrolyte) is ~6033 away, got ' .. math.floor(d))
    assert(d > X.nEDrainDangerRadius,
        'and far outside the danger radius -- distance alone rules this out')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'the four DAMAGE rows in the previous 2s are all creep (dark_troll_warlord)')

    assert(fx.observed.died_after ~= nil and fx.observed.died_after > 60.0,
        'Lion survives the jungle channel comfortably, got ' .. tostring(fx.observed.died_after))
end

-- ------------------------------------------------------------------- gate off

tests['gate OFF: nothing armed leaves ConsiderStopDrain byte-identical to shipped'] = function()
    local X, _, bot = load_lion(FOCUSED, false, true, true)
    -- Not retreating (no mutation), unarmed -> shipped path returns NONE and
    -- new path is inert.
    assert(X.lion_ShouldStopDrain(bot) == false,
        'unarmed, the helper must be inert (false = do not release)')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE,
        'unarmed + not retreating: shipped code returns NONE, our path adds nothing')
end

tests['gate OFF: armed but NOT turbo is still inert'] = function()
    local X, _, bot = load_lion(FOCUSED, true, true, true, false)
    assert(X.lion_ShouldStopDrain(bot) == false, 'the gate is turbo-only')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE, 'non-turbo, still NONE')
end

-- ---------------------------------------------------------------- gate armed

tests['armed: releases the channel on the real mid-channel frame under fire'] = function()
    local X, _, bot = load_lion(FOCUSED, true, true, true)
    assert(X.lion_ShouldStopDrain(bot) == true,
        'being hit by viper with viper 484 units away => release the root')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'the new branch must feed HIGH into ConsiderStopDrain')
end

tests['armed: does not release the jungle channel (no hero in radius, no hero damage)'] = function()
    local X, _, bot = load_lion(JUNGLE, true, true, false)
    assert(X.lion_ShouldStopDrain(bot) == false,
        'creep damage in a quiet camp is not a release condition')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE, 'jungle mid-channel: NONE')
end

tests['armed: frame A without the hero damage would NOT release'] = function()
    -- MUTATION of the real frame: keep viper at 484u, drop the recent-damage
    -- clause via the same override the start-lever test uses. Proves the
    -- release is not proximity alone.
    local X, _, bot = load_lion(FOCUSED, true, true, true)
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return false end
    assert(X.lion_ShouldStopDrain(bot) == false,
        'without incoming hero damage the geometry alone must not release')
end

tests['armed: jungle frame with hero damage added would still NOT release (nobody in radius)'] = function()
    -- MUTATION: pretend viper started poking. The nearest enemy hero is still
    -- 1795u away -- outside the 500u danger radius -- so the release must
    -- still refuse. This isolates the proximity clause.
    local X, _, bot = load_lion(JUNGLE, true, true, false)
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return true end
    assert(X.lion_ShouldStopDrain(bot) == false,
        'hero damage from 1795u away is not the releasable state')
end

tests['armed: jungle frame with a hero moved into the radius AND hero damage WOULD release'] = function()
    -- MUTATION: move drow next to Lion and stamp recent hero damage. Both
    -- clauses of the AND now hold; guard must fire. Mirror of the above --
    -- proves both halves of the AND are load-bearing in both directions.
    local X, _, bot, heroes = load_lion(JUNGLE, true, true, false)
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return true end
    local vBot = bot:GetLocation()
    -- drow_ranger is dead in this jungle fixture (hp = 0, alive = false), so
    -- move an ALIVE enemy (necrolyte, alive at 5995u in the real snapshot)
    -- into the radius. J.GetNearbyHeroes / bot:GetNearbyHeroes both filter on
    -- alive.
    rawget(heroes['npc_dota_hero_necrolyte'], '__spec').GetLocation =
        Vector(vBot.x + 300, vBot.y, vBot.z)
    -- The IsAbilityEChanneling scan needs SOMETHING near carrying the drain
    -- modifier to enter its inner branch. Give the nearby necrolyte the
    -- modifier (this is the mid-channel world we are asserting the guard against).
    rawget(heroes['npc_dota_hero_necrolyte'], '__spec').HasModifier = function(_, sName)
        return sName == 'modifier_lion_mana_drain'
    end
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_necrolyte'])
        < X.nEDrainDangerRadius, 'the mutation really moved necrolyte inside the radius')
    assert(X.lion_ShouldStopDrain(bot) == true,
        'both AND clauses now hold: hero damage + hero in danger radius => release')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'ConsiderStopDrain surfaces the release via HIGH')
end

tests['armed: pushing viper past the radius on frame A stops the release'] = function()
    local X, _, bot, heroes = load_lion(FOCUSED, true, true, true)
    -- MUTATION: move viper (the only enemy inside the radius on this frame)
    -- out past 500. Hero damage stays as real -- proves the proximity clause
    -- is load-bearing when damage is unchanged.
    local vBot = bot:GetLocation()
    rawget(heroes['npc_dota_hero_viper'], '__spec').GetLocation =
        Vector(vBot.x + 900, vBot.y, vBot.z)
    assert(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_viper'])
        > X.nEDrainDangerRadius, 'the mutation really moved viper out')
    assert(X.lion_ShouldStopDrain(bot) == false,
        'damage from far away does not root-lock him; the channel may continue')
end

tests['armed: dropping IsChanneling stops ConsiderStopDrain even when the predicate holds'] = function()
    -- The precondition is IsAbilityEChanneling, which reads IsChanneling first.
    -- With that off the STOP guard's whole ConsiderStopDrain path returns NONE
    -- (nothing to release), even though lion_ShouldStopDrain's own predicate
    -- would answer true in isolation.
    local X, _, bot = load_lion(FOCUSED, true, false, true)
    assert(bot:IsChanneling() == false, 'the mutation really cleared IsChanneling')
    assert(X.IsAbilityEChanneling() == false, 'no channel => nothing to release')
    -- Sanity: the helper still says true (its own predicate holds), which is
    -- WHY the outer IsAbilityEChanneling guard is not redundant.
    assert(X.lion_ShouldStopDrain(bot) == true,
        'the helper only tests the pressure predicate; IsAbilityEChanneling is the outer gate')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE,
        'ConsiderStopDrain must NOT fire without an active channel to break')
end

tests['armed: retreat mode already fires the shipped release; the new branch does not double-count'] = function()
    -- ConsiderStopDrain returns a scalar desire; there is nothing to
    -- double-count numerically, but stapling the two branches in the wrong
    -- order (e.g. as an OR that hides which branch fired) would obscure the
    -- attribution. Assert the shipped branch still fires on its own.
    local X, J, bot = load_lion(FOCUSED, true, true, true)
    -- Force retreat mode; the shipped `and J.IsRetreating(bot)` branch fires.
    J.IsRetreating = function() return true end
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'shipped retreat release still HIGH')
    -- Now disarm the new gate and drop the pressure predicate; only the
    -- shipped branch is left, still HIGH.
    J.IsSoakCandidate = function() return false end
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return false end
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'shipped retreat release stands alone when the new gate is off')
end

tests['armed: a dead enemy inside the radius does not count'] = function()
    -- Same cross-layer tripwire as the start-lever test: J.GetNearbyHeroes
    -- filters every element through J.IsValidHero, so a corpse cannot keep
    -- the release latched after a kill. Not a test of this helper's own
    -- branch (the check is upstream, in the shared reader).
    local X, _, bot, heroes = load_lion(FOCUSED, true, true, true)
    rawget(heroes['npc_dota_hero_viper'], '__spec').IsAlive = false
    assert(X.lion_ShouldStopDrain(bot) == false,
        'a corpse must not keep the release latched after a kill')
end

-- ------------------------------------------------------------ radius interval
-- Same interval assertion as the start-lever test, so a retune of one radius
-- self-reports on both sides. The stop lever cannot LOOSEN the interval without
-- the start lever loosening too (they share the constant).

tests['radius: the danger radius stays inside the interval the frames support'] = function()
    local X = load_lion(FOCUSED, true, true, true)
    assert(X.nEDrainDangerRadius >= 484 and X.nEDrainDangerRadius < 781,
        'observed channels bound this to [484, 781), got ' .. X.nEDrainDangerRadius)
end

-- ---------------------------------------------------- end to end (SkillsComplement)
-- Drive the real X.SkillsComplement and assert what reaches the action log.
-- Shipped code on the mid-channel FOCUSED frame does NOT clear actions -- the
-- shipped ConsiderStopDrain returns NONE (not retreating), so
-- SkillsComplement falls through to its second early-out (CanNotUseAbility is
-- true because IsChanneling). That is the bug repro. Armed code MUST clear.

local function run_skills(path, bArmed, bChanneling, bTargetHasMod)
    local X, J, bot, heroes, fx = load_lion(path, bArmed, bChanneling, bTargetHasMod)
    -- MUTATIONS: dump carries neither active mode nor attack target; without
    -- them J.IsGoingOnSomeone / J.GetProperTarget cannot resolve. The STOP
    -- guard fires BEFORE the combat branches, so these mutations don't affect
    -- its verdict -- they only ensure other Consider* functions can be reached
    -- if the STOP guard declines to fire.
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK
    rawget(bot, '__spec').GetActiveModeDesire = 0.8
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    return log, X, J, bot, heroes, fx
end

local function has_call(log, fn)
    for _, e in ipairs(log) do if e.fn == fn then return true end end
    return false
end

tests['end to end: shipped SkillsComplement on the mid-channel frame does NOT clear actions'] = function()
    local log = run_skills(FOCUSED, false, true, true)
    -- The bug repro: shipped path's ConsiderStopDrain returns NONE (Lion not
    -- retreating), so the ClearActions call inside SkillsComplement is NOT
    -- issued. Lion continues to channel, taking damage each tick.
    assert(not has_call(log, 'Action_ClearActions'),
        'shipped Lion does not break the channel on this frame -- that is the bug')
end

tests['end to end: armed SkillsComplement clears the channel on the same frame'] = function()
    local log = run_skills(FOCUSED, true, true, true)
    assert(has_call(log, 'Action_ClearActions'),
        'the new branch drives ClearActions(true) via ConsiderStopDrain -> HIGH')
end

tests['end to end: armed SkillsComplement on the JUNGLE frame does not clear actions'] = function()
    local log = run_skills(JUNGLE, true, true, false)
    -- No hero in radius / no hero damage -> STOP guard NONE -> no clear.
    assert(not has_call(log, 'Action_ClearActions'),
        'the jungle channel must not be broken by the STOP guard')
end

tests['end to end: only-damage-changed mutation on FOCUSED flips ClearActions off'] = function()
    -- Prove the end-to-end assertion is caused by the DAMAGE clause of the
    -- STOP predicate, not by some other unnoticed side effect: keep everything
    -- else in the armed FOCUSED end-to-end setup identical and drop only the
    -- damage clause -> the ClearActions must disappear.
    local X, J, bot, heroes, fx = load_lion(FOCUSED, true, true, true)
    rawget(bot, '__spec').GetActiveMode = BOT_MODE_ATTACK
    rawget(bot, '__spec').GetActiveModeDesire = 0.8
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function() return false end
    local log = rf.record_actions(bot)
    X.SkillsComplement()
    assert(not has_call(log, 'Action_ClearActions'),
        'flipping only the damage clause of the STOP predicate flips ClearActions off')
end

-- ------------------------------------------------------- source-level wiring
-- The two AND clauses, the gate id, and the outer IsAbilityEChanneling
-- precondition are load-bearing at the source level; a rename or a re-order
-- fails loudly here.

tests['wiring: the STOP helper is gated, consumed in ConsiderStopDrain, and rides IsAbilityEChanneling'] = function()
    local f = assert(io.open('bots/BotLib/hero_lion.lua'))
    local src = f:read('*a')
    f:close()
    assert(src:find("J.IsSoakCandidate( 'liondrainstop' )", 1, true),
        'the helper must stay gated behind the liondrainstop candidate id')
    assert(src:find('X.lion_ShouldStopDrain( bot )', 1, true),
        'ConsiderStopDrain must consume the helper')
    -- The new branch sits BELOW the shipped IsRetreating branch (so the shipped
    -- retreat release keeps its shape) and INSIDE its own IsAbilityEChanneling
    -- clause (so it never fires without a live channel to break).
    local iRetreat = src:find('if X.IsAbilityEChanneling()\n\t\tand J.IsRetreating', 1, true)
    local iStop    = src:find('if X.IsAbilityEChanneling()\n\t\tand X.lion_ShouldStopDrain', 1, true)
    assert(iRetreat and iStop and iStop > iRetreat,
        'the new branch sits BELOW the shipped J.IsRetreating branch')
    -- The helper's own two-clause AND, so an accidental collapse to a single
    -- clause self-reports:
    assert(src:find('WasRecentlyDamagedByAnyHero%( 2%.0 %)', 1, false),
        'helper must retain the 2s recent-hero-damage clause')
    assert(src:find('J.GetNearbyHeroes( hBot, X.nEDrainDangerRadius, true, BOT_MODE_NONE )',
        1, true), 'helper must retain the danger-radius nearby-heroes clause')
end

-- ---------------------------------------------------------------------------
-- RE-READ of frame B under the real drafted roles (strategy backlog 0c, GH #57)
-- -- and the first heal in that queue where the regeneration was NOT a pure
-- addition.
--
-- Every case above was written while the JUNGLE fixture carried no `roles`
-- table, so Role.GetPosition fell through to RoleAssignment[team][slot] -- the
-- draft SLOT, which GH #57 measured against the real draft at 47.3%. The game
-- is attributable (soak seed in the run's analysis.json), so the fixture was
-- regenerated with `--roles`.
--
-- WHAT THE HEAL FOUND, in the order it matters:
--
-- 1. THE INSTANT MOVED. The four previous heals in this queue all reported the
--    regeneration as byte-identical apart from the added table, and used that
--    as the provenance proof. Here it is not: at the same `--t 247.0` the
--    generator picked a sample ~0.33s EARLIER in state time than the file it
--    replaced. Measured, not assumed -- projecting each pre-heal hero position
--    onto the segment between today's two neighbouring samples (246.4 and
--    247.4) puts the old file at t = 246.733 / 246.737 / 246.741 / 246.733 for
--    the four heroes moving fast enough to resolve it (dragon_knight,
--    earthshaker, lich, pudge; 387-427u of travel, <23u off-path). The slow
--    movers land anywhere, which is exactly why only the fast ones were used.
--
-- 2. IT IS THE SNAPSHOT STREAM ALONE. Everything the generator derives from the
--    event stream came back byte-identical: all twelve recent_damage rows, the
--    empty observed.burst, observed.died_after = 68.1, and all 38 buildings.
--    Those are computed off the nominal --t, so a moved game clock would have
--    moved them too. The hero-snapshot sampling phase moved; the event clock
--    did not.
--
-- 3. NO DUMPER WE STILL HAVE REPRODUCES THE OLD FILE. All three binaries cached
--    in S3 (the 2026-08-19 one that was current when this fixture was pinned,
--    and both 2026-08-20 ones) put this game's snapshot grid on the same
--    ...246.4, 247.4... phase and report the same horn (start_time 138.6). The
--    binary that produced the pre-heal file is not among them.
--
-- 4. AND THE CURRENT LABELS ARE THE LATE ONES. Independent of provenance: on
--    this dump a snapshot labelled t carries state from ~0.2-0.33s BEFORE t.
--    Estimated two ways -- (a) 1884 (cast event, later snapshot) pairs where the
--    ability's own cd_len and remaining cd date the state: weighted mean 0.22s,
--    biased low by the 0.1s quantisation of both inputs; (b) reconstructing
--    Lion's HP series across 240-250s against the real damage rows, which only
--    balances if the labels run ~0.33s ahead (the 244.2 creep hit shows up in
--    the sample labelled 245.4, not 244.4). ~0.33s is 10 engine ticks at 1/30s.
--    That the sampling loop drives off m.GetTick() while another site in the
--    same dumper reads p.NetTick is the SHAPE that would produce it -- stated
--    as the hypothesis it is, not as a finding. Reported to the director as a
--    harness issue; nothing in bots/ is involved.
--
-- WHAT IT COST HERE: two assertions in the ground-truth case, both written to
-- bands far tighter than the move (HP to the unit, necrolyte to 10u) on a frame
-- whose conclusion has 5500u of margin. Nothing about the discriminator moved.
--
-- WHAT MOVED ON THE ROLES: four of the five allies read a different position and
-- the core/support partition FLIPS TWICE -- lich core->support, dragon_knight
-- support->core. The subject is a fixed point (slot 5 = drafted 5), so this
-- frame is another CONTROL for the build-list finding of the axe and CM
-- re-reads. No case above forks on any of it, and the cases below measure that
-- rather than assume it.
-- ---------------------------------------------------------------------------

--- Count every position read through BOTH entry points: J.GetPosition (the jmz
--- wrapper) and Role.GetPosition (the module, which aba_item reaches directly).
--- They are not the same function object, so hooking one undercounts.
local function counting_roles(J, fBody)
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')
    assert(J.GetPosition ~= Role.GetPosition,
        'the two role entry points must be distinct functions -- hooking only '
        .. 'one of them undercounts, which is how the aba_item call site hides')
    local tLog = {}
    local realJ, realR = J.GetPosition, Role.GetPosition
    J.GetPosition = function(u) tLog[#tLog + 1] = 'J:' .. u:GetUnitName() return realJ(u) end
    Role.GetPosition = function(u) tLog[#tLog + 1] = 'R:' .. u:GetUnitName() return realR(u) end
    local ok, err = pcall(fBody)
    J.GetPosition, Role.GetPosition = realJ, realR
    assert(ok, err)
    return tLog
end

tests['RE-READ: frame B carries the drafted roles, and the partition FLIPS TWICE'] = function()
    local _, J, bot, _, fx = load_lion(JUNGLE, true, true, false)
    assert(fx.roles ~= nil, 'the fixture must carry the drafted roles -- without '
        .. 'them every position on this frame is the draft slot (GH #57)')

    -- slot (what the fixture answered before the heal) -> drafted (now).
    local WAS_AND_IS = {
        [1] = { 'npc_dota_hero_death_prophet',    2 },
        [2] = { 'npc_dota_hero_phantom_assassin', 1 },
        [3] = { 'npc_dota_hero_lich',             4 },
        [4] = { 'npc_dota_hero_dragon_knight',    3 },
        [5] = { 'npc_dota_hero_lion',             5 },
    }
    local nMoved, nFlipped = 0, 0
    for nSlot, tWant in ipairs(WAS_AND_IS) do
        local h = GetTeamMember(nSlot)
        assert(h:GetUnitName() == tWant[1], 'roster slot ' .. nSlot .. ' is '
            .. h:GetUnitName() .. ', this frame was recorded with ' .. tWant[1])
        assert(J.GetPosition(h) == tWant[2], tWant[1] .. ' reads position '
            .. tostring(J.GetPosition(h)) .. ', drafted ' .. tWant[2]
            .. ' -- a slot-order answer here means the fixture lost its roles')
        if tWant[2] ~= nSlot then nMoved = nMoved + 1 end
        if (nSlot <= 3) ~= J.IsCore(h) then nFlipped = nFlipped + 1 end
    end
    assert(nMoved == 4, 'four of five allies must move; got ' .. nMoved)
    assert(nFlipped == 2, 'the core/support partition must flip for exactly two '
        .. 'allies (lich core->support, dragon_knight support->core); got '
        .. nFlipped .. ' -- the axe frame (seed 885) flipped NONE with all five '
        .. 'moving, so "the partition is usually stable" is never a reason to '
        .. 'skip a frame')

    assert(J.GetPosition(bot) == 5 and J.IsCore(bot) == false,
        'the subject is a fixed point of the permutation: slot 5, drafted 5')
end

tests['RE-READ: the STOP guard asks for ZERO roles -- WHY every case above held'] = function()
    -- Load the hero file BEFORE hooking, so this counts the decision only.
    local X, J, bot = load_lion(JUNGLE, true, true, false)

    local tGuard = counting_roles(J, function()
        assert(X.lion_ShouldStopDrain(bot) == false,
            'the decision under test is still "hold the channel"')
    end)
    assert(#tGuard == 0, 'lion_ShouldStopDrain asked for a position '
        .. table.concat(tGuard, ', ') .. ' -- it must ask ZERO times. If this '
        .. 'ever becomes non-zero, every case on this frame has to be re-read, '
        .. 'because two of the five allied core/support answers flipped')

    local tBid = counting_roles(J, function()
        assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE,
            'the bid under test is still NONE')
    end)
    assert(#tBid == 0, 'ConsiderStopDrain asked for a position '
        .. table.concat(tBid, ', ') .. ' -- it must ask ZERO times')

    -- Both zeroes above are worthless without a witness that something ran:
    -- the guard really did evaluate its proximity clause on this frame.
    assert(#J.GetNearbyHeroes(bot, X.nEDrainDangerRadius, true, BOT_MODE_NONE) == 0,
        'stated so the two zeroes cannot be a vacuous "nothing ran": the '
        .. 'danger-radius scan really is running and really is empty here')
end

tests['RE-READ: the one role read is the build-list key, and on this frame it does NOT move'] = function()
    local _, J, bot = load_lion(JUNGLE, true, true, false)
    local Role = require(GetScriptDirectory() .. '/FunLib/aba_role')

    -- Same single call site the axe and CM re-reads found: the read happens at
    -- hero-file LOAD, through the MODULE, bypassing the J wrapper.
    local tLoad = counting_roles(J, function() rf.load_hero('lion') end)
    assert(#tLoad == 1 and tLoad[1] == 'R:npc_dota_hero_lion',
        'expected exactly one role read at hero load, on the subject, through '
        .. 'the MODULE; got { ' .. table.concat(tLoad, ', ') .. ' }')

    -- ...and here it lands where it already did: Lion is the fixed point.
    assert(Role.GetPosition(bot) == 5 and J.Item.GetRoleItemsBuyList(bot) == 'pos_5',
        'drafted pos 5 keys this Lion onto pos_5, the same list the slot claimed; '
        .. 'got ' .. tostring(J.Item.GetRoleItemsBuyList(bot)))

    -- "It does not move" is only worth stating if the mechanism could have
    -- moved it, so drive the key somewhere else and show a different list.
    local function buy_list_at(nPos)
        local _, _, bot2 = load_lion(JUNGLE, true, true, false)
        local Role2 = require(GetScriptDirectory() .. '/FunLib/aba_role')
        local real = Role2.GetPosition
        Role2.GetPosition = function(u) if u == bot2 then return nPos end return real(u) end
        local ok, X = pcall(dofile, GetScriptDirectory() .. '/BotLib/hero_lion.lua')
        Role2.GetPosition = real
        assert(ok and type(X) == 'table' and X.sBuyList ~= nil,
            'hero_lion must publish an sBuyList for pos ' .. nPos)
        return X.sBuyList
    end
    local tFive, tFour = buy_list_at(5), buy_list_at(4)
    assert(#tFive > 0 and #tFour > 0, 'both lists must be non-empty')
    local bDiffer = #tFive ~= #tFour
    for i = 1, math.min(#tFive, #tFour) do
        if tFive[i] ~= tFour[i] then bDiffer = true end
    end
    assert(bDiffer, 'pos_5 and pos_4 must be different build lists, otherwise '
        .. '"the key did not move" says nothing at all')
end

tests['RE-READ: [recorded] healing frame A will move its instant too -- what it does and does not cost'] = function()
    -- Frame A (FOCUSED) is still slot-derived and still on the pre-heal
    -- sampling phase. Measured on the same regenerated timeline, healing it
    -- lands on the sample labelled 298.4, where Lion is at 601 HP (not 510 --
    -- the 298.6/298.7 viper chain has not landed yet at that state) and viper
    -- sits 484.5u away rather than 484. So the RELEASE pin survives on its
    -- load-bearing clause -- viper stays inside the 500u danger radius, and
    -- WasRecentlyDamagedByAnyHero reads the event stream, which does not move
    -- -- while the HP/mana ground-truth numbers below have to be rewritten.
    -- This case asserts the CURRENT (pre-heal) numbers, so whoever heals frame
    -- A is sent here instead of discovering it in a band that happens to be
    -- wide enough to hide it.
    local _, _, bot, heroes, fx = load_lion(FOCUSED, true, true, true)
    assert(fx.roles == nil, 'frame A is still the slot-derived file; if it now '
        .. 'carries roles it has been healed -- re-read this case and the two '
        .. 'ground-truth numbers it protects')
    assert(bot:GetHealth() == 510 and bot:GetMana() == 171,
        'pre-heal frame A is 510 HP / 171 mana; healing it moves these to '
        .. '601 / (re-measure), got ' .. bot:GetHealth() .. ' / ' .. bot:GetMana())
    local d = GetUnitToUnitDistance(bot, heroes['npc_dota_hero_viper'])
    assert(d > 483 and d < 486, 'viper is 484u pre-heal and 484.5u after; the '
        .. 'clause survives either way, got ' .. math.floor(d))
end

return tests

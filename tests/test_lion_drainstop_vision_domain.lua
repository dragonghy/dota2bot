-- [detector] GH #314 candidate root cause 1, driven -- and why the acceptance
-- the issue proposes cannot decide it.
--
-- THE BATON.  replay-check bought `liondrainstop` its condition (a) = WORKING on
-- W25 (armed 2/30 channels held the predicate for >=2 consecutive 1 Hz frames,
-- baseline 33/67), and opened GH #314 on the 2 that held.  The issue lists three
-- candidate root causes and says offline data cannot decide between them, then
-- proposes pinning frame (A) t=200.4 as a fixture and asserting
-- `X.lion_ShouldStopDrain( bot )` is true there.
--
-- This file answers two of the three WITHOUT that frame, because both answers
-- are arithmetic on code that is already in the tree:
--
--   * CANDIDATE 1 (`J.GetNearbyHeroes` drops the enemy) is REAL and has three
--     named filters, not one -- and the proposed acceptance is structurally
--     unable to see any of them.  Every fixture in the corpus is a fully-visible
--     world (0 of 107 carry `seen_by`, because the dumper emits no `vis` key),
--     so `CanBeSeen()` answers true BY CONSTRUCTION and the asserted green would
--     be mock-given, not earned.  Same shape as the ZERO_TRUE lesson
--     (`tests/test_zero_true_sites_driven.lua`, hero 2026-08-29T13:50Z): the
--     mock datum that decides the assertion is upstream of the frame.
--
--   * CANDIDATE 2 (`X.SkillsComplement` not called on those ticks) is BOUNDED
--     OUT: the only throttle on the path is `AbilityUsageThink`'s
--     `bot.frameProcessTime * (1 + Customize.ThinkLess)`, and both factors are
--     constants in this tree (0.06..0.078 and 2) => at most ~0.16 s of delay,
--     against residuals of 2.2 s and 3.9 s.  Section 6 pins the constants so the
--     bound self-reports if either moves.
--
--   * CANDIDATE 3 (`Action_ClearActions(true)` ineffective) is untouched here:
--     it needs the engine (AGENTS.md, no bot-side debugging).
--
-- WHAT IS DRIVEN vs WHAT IS DECLARED.  Sections 1-4 run the REAL
-- `X.lion_ShouldStopDrain` / `X.IsAbilityEChanneling` / `J.GetNearbyHeroes` on a
-- REAL frame (`f_260819_182855_lion_drain_midchannel.lua`, t=299.2) -- no J.*
-- stub.  `IsChanneling()` and the drain target's modifier are labelled
-- mutations with the same ground truth the sibling test declares (the
-- MODIFIER_ADD/REMOVE pair 297.2..302.2 in that replay's event stream); the
-- fog / invulnerability flips in sections 2-4 are labelled mutations of ONE
-- field on ONE unit, and each section re-reads the snapshot distance to show
-- the census-side predicate did NOT move with it.
--
-- Sibling: tests/test_replay_260819_lion_drain_stop.lua (the lever's own
-- regression).  This file does not restate it; it measures the gap between the
-- lever's predicate and the DETECTOR's predicate.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FOCUSED = 'tests/fixtures/f_260819_182855_lion_drain_midchannel.lua'
local VIPER   = 'npc_dota_hero_viper'

-- The census constant, read off the detector it belongs to
-- (tools/batch_test/behavioral/lion_drain_census.py: DANGER_RADIUS = 500.0,
-- itself a copy of hero_lion.lua:1351 X.nEDrainDangerRadius).
local DANGER_RADIUS = 500

local function read_file(path)
    local fh = io.open(path, 'r')
    assert(fh ~= nil, 'cannot read ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

--- Load the pinned frame with `liondrainstop` armed and Lion mid-channel.
--- `mutate(bot, heroes)` runs BEFORE the hero file is loaded, so a flipped
--- field is in place for every read the hero script makes.
local function load_lion(mutate)
    local J, bot, heroes, fx = rf.load(FOCUSED)
    -- Labelled mutation 1: the .dem carries no per-frame channel flag, only the
    -- MODIFIER_ADD/REMOVE pair (297.2, 302.2) on the drain target.
    rawget(bot, '__spec').IsChanneling = true
    J.IsSoakCandidate = function(id) return id == 'liondrainstop' end
    if mutate then mutate(bot, heroes) end
    local X = rf.load_hero('lion')
    return X, J, bot, heroes, fx
end

--- Labelled mutation 2: the real drain target on this window is viper; the
--- shipped scan reads HasModifier only.
local function give_viper_the_drain_modifier(_, heroes)
    rawget(heroes[VIPER], '__spec').HasModifier = function(_, sName)
        return sName == 'modifier_lion_mana_drain'
    end
end

local tests = {}

-- ------------------------------------------------------------------ section 1
-- Ground truth: on the real frame the lever's predicate and the detector's
-- predicate agree, and BOTH are true. Everything after this measures where
-- they come apart.

tests['1. real frame: viper is inside the danger radius and the armed lever releases'] = function()
    local X, J, bot, heroes, fx = load_lion()
    assert(fx.time == 299.2, 'pinned frame is t=299.2, got ' .. tostring(fx.time))
    assert(bot:GetUnitName() == 'npc_dota_hero_lion', 'subject is Lion')

    -- The detector-side predicate, evaluated the way lion_drain_census.py
    -- evaluates it: snapshot distance, and Lion took hero damage recently.
    local d = GetUnitToUnitDistance(bot, heroes[VIPER])
    assert(d < DANGER_RADIUS, 'viper is inside 500u on this frame, got ' .. tostring(d))
    assert(heroes[VIPER]:IsAlive(), 'and he is alive')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'real recent-damage rows on this frame carry a hero hit')

    -- The lever-side predicate, driven.
    local near = J.GetNearbyHeroes(bot, DANGER_RADIUS, true, BOT_MODE_NONE)
    assert(#near == 1 and near[1]:GetUnitName() == VIPER,
        'the gate sees exactly the same enemy the census counted')
    assert(X.lion_ShouldStopDrain(bot) == true, 'armed: the lever releases here')
end

-- ------------------------------------------------------------------ section 2
-- CANDIDATE 1, first filter: CanBeSeen(). This is the whole of GH #314's
-- candidate 1 -- `J.GetNearbyHeroes` -> `J.IsValidHero` -> `Utils.IsValidUnit`
-- (bots/FunLib/utils.lua:541) = `not IsNull() and CanBeSeen() and IsAlive()
-- and not IsInvulnerable()`. On top of that the ENGINE's own
-- bot:GetNearbyHeroes is vision-limited for enemies. The census reads neither.

tests['2. fog one enemy and the lever goes silent while the census predicate does not move'] = function()
    local X, J, bot, heroes = load_lion(function(_, hs)
        rawget(hs[VIPER], '__spec').CanBeSeen = false
    end)

    -- The census-side predicate is byte-identical to section 1 ...
    local d = GetUnitToUnitDistance(bot, heroes[VIPER])
    assert(d < DANGER_RADIUS, 'the snapshot distance did not move: ' .. tostring(d))
    assert(heroes[VIPER]:IsAlive(), 'still alive in the snapshot')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true, 'still taking hero damage')

    -- ... and the lever-side predicate is now empty.
    assert(#J.GetNearbyHeroes(bot, DANGER_RADIUS, true, BOT_MODE_NONE) == 0,
        'J.IsValidHero drops a hero the bot cannot see')
    assert(X.lion_ShouldStopDrain(bot) == false,
        'so the armed lever holds the channel -- indistinguishable, in the ' ..
        'census, from a gate that failed to fire (GH #314)')
end

-- ------------------------------------------------------------------ section 3
-- CANDIDATE 1, third filter: IsInvulnerable(). GH #314 names only the
-- visibility one. This is the same `IsValidUnit` conjunction, and the census
-- does not read it either (it reads hp > 0, which is the SECOND filter).

tests['3. an invulnerable enemy is dropped by the same conjunction'] = function()
    local X, J, bot, heroes = load_lion(function(_, hs)
        rawget(hs[VIPER], '__spec').IsInvulnerable = true
    end)
    assert(GetUnitToUnitDistance(bot, heroes[VIPER]) < DANGER_RADIUS,
        'the snapshot distance did not move')
    assert(#J.GetNearbyHeroes(bot, DANGER_RADIUS, true, BOT_MODE_NONE) == 0,
        'IsValidUnit also requires not IsInvulnerable()')
    assert(X.lion_ShouldStopDrain(bot) == false, 'and the lever holds')
end

-- ------------------------------------------------------------------ section 4
-- The SECOND landing of the same mechanism, one layer earlier. Fogging the
-- DRAIN TARGET does not merely blank the danger list: X.IsAbilityEChanneling
-- confirms a hero-target channel through the same J.GetNearbyHeroes (at 1200u,
-- hero_lion.lua:495), so `X.ConsiderStopDrain` never reaches either release
-- branch -- the shipped J.IsRetreating one included. GH #314's frames both
-- drain a hero (necrolyte), so this layer is in the domain of the report.

tests['4. fogging the drain target kills the release at IsAbilityEChanneling, not at the lever'] = function()
    local X = load_lion(give_viper_the_drain_modifier)
    assert(X.IsAbilityEChanneling() == true,
        'baseline: the hero-target branch confirms the channel')
    assert(X.ConsiderStopDrain() == BOT_ACTION_DESIRE_HIGH,
        'and the armed lever surfaces the release')

    local X2 = load_lion(function(bot, hs)
        give_viper_the_drain_modifier(bot, hs)
        rawget(hs[VIPER], '__spec').CanBeSeen = false
    end)
    assert(X2.IsAbilityEChanneling() == false,
        'the confirmation loop reads the same vision-filtered helper')
    assert(X2.ConsiderStopDrain() == BOT_ACTION_DESIRE_NONE,
        'so BOTH release branches are unreachable -- shipped and armed alike')
end

-- ------------------------------------------------------------------ section 5
-- Why the acceptance GH #314 proposes cannot decide candidate 1.
--
-- tests/mock/replay_fixture.lua:89 models fog properly: `visible_to_team(u, t)`
-- returns true when `u.seen_by == nil` ("v1 fixtures stay fully visible") and
-- otherwise consults the list. make_fixture.py:307 fills `seen_by` from the
-- snapshot's `vis` key. NO FIXTURE HAS EVER CARRIED ONE -- section 6 shows why.
-- So `CanBeSeen()` is unconditionally true in every fixture, and any fixture
-- pinned at GH #314's t=200.4 will assert `lion_ShouldStopDrain == true` no
-- matter what the bot could actually see at that instant.
--
-- AUTO-EXPIRY. When the dumper starts emitting `vis` and a fixture carries
-- `seen_by`, this section goes RED. That is the DEVICE, not a regression: the
-- reader is being sent back to GH #314 to re-read the two channels with the
-- filter finally modelled.

tests['5. every fixture in the corpus is a fully-visible world (expiry device)'] = function()
    local pipe = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    local total, with_fog, first = 0, 0, nil
    for path in pipe:lines() do
        total = total + 1
        if read_file(path):find('seen_by', 1, true) then
            with_fog = with_fog + 1
            first = first or path
        end
    end
    pipe:close()

    -- Lower bound, not an equality: a compliant new fixture must not redden
    -- trunk (GH #273's shape).
    assert(total >= 107, 'corpus shrank unexpectedly: ' .. total .. ' fixtures')
    assert(with_fog == 0,
        'EXPECTED EXPIRY, NOT A REGRESSION: ' .. tostring(first) .. ' is the ' ..
        'first fixture carrying seen_by, so fog is finally modelled. Go re-read ' ..
        'GH #314 -- its two held channels can now be decided, and this section ' ..
        'plus sections 2-4 should be rewritten to pin the real frames.')
end

-- ------------------------------------------------------------------ section 6
-- The producer/consumer gap behind section 5, and the arithmetic that bounds
-- candidate 2 out. Both are read off source, so both self-report when the
-- source moves.

tests['6a. `vis` has two consumers and no producer'] = function()
    local dumper = read_file('tools/batch_test/behavioral/dumper/main.go')
    -- The dumper says so itself, in the note it ships inside every dump.
    assert(dumper:find('no m_iTaggedAsVisibleByTeam', 1, true),
        "the dumper's vision_note is the source of this claim")
    assert(not dumper:find('"vis"', 1, true),
        'and it writes no "vis" key -- if this fails, section 5 is about to expire')

    assert(read_file('tools/batch_test/replayscope/make_fixture.py')
        :find('s.get("vis")', 1, true), 'consumer 1: make_fixture.py fills seen_by from it')
    assert(read_file('tools/batch_test/replayscope/build.py')
        :find('s.get("vis")', 1, true), 'consumer 2: build.py fills the ReplayScope fog panel')
end

tests['6b. the census in-domain loop reads distance and hp, and nothing about vision'] = function()
    local census = read_file('tools/batch_test/behavioral/lion_drain_census.py')
    assert(census:find('DANGER_RADIUS = 500', 1, true), 'the radius it copies from the hero file')
    -- The qualification loop: from `def classify` to the `break` that instruments
    -- the domain. Whatever else it grows, a visibility filter is not in it today.
    local body = census:match('def classify%(.-\n    ch%["resolvable"%]')
    assert(body ~= nil, 'could not locate the in-domain qualification loop')
    assert(not body:find('vis', 1, true) and not body:find('seen', 1, true),
        'the detector predicate is OMNISCIENT: it counts enemies the bot may ' ..
        'never have seen, on BOTH legs. GH #314 2/30 vs 33/67 are both upper bounds.')
end

tests['6c. candidate 2 is bounded to ~0.16s -- it cannot explain a 2.2s residual'] = function()
    local utils = read_file('bots/FunLib/utils.lua')
    local base = tonumber(utils:match('____exports%.FrameProcessTime = ([%d%.]+)'))
    assert(base == 0.06, 'FrameProcessTime moved: ' .. tostring(base))
    -- SetFrameProcessTime adds fmod(playerID/1000, base/10) * 3, i.e. < base/10*3.
    local worst_frame = base + (base / 10) * 3
    local think_less = tonumber(read_file('bots/Customize/general.lua')
        :match('Customize%.ThinkLess = (%d+)'))
    assert(think_less == 1, 'ThinkLess moved: ' .. tostring(think_less))
    -- The mode files re-derive it as `Customize.Enable and Customize.ThinkLess
    -- or 1`, so 1 either way -- the multiplier is (1 + 1) = 2.
    local worst_gap = worst_frame * (1 + think_less)
    assert(worst_gap < 0.2, 'worst AbilityUsageThink gap = ' .. worst_gap)

    -- GH #314's two held channels, from the issue's own frame listing.
    local residual_a, residual_b = 203.1 - 199.4, 464.2 - 462.4
    assert(residual_a > 20 * worst_gap and residual_b > 10 * worst_gap,
        'the throttle is more than an order of magnitude too small to explain ' ..
        'either held channel, so "SkillsComplement was not called" is not the story')
end

return tests

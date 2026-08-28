-- [strategy 2026-08-28T22:xxZ, GH #288] THE COUNTER-FRAMES OF 'campexit'.
--
-- 'campexit' (J.IsOverTierCampOnly, one call site at mode_farm_generic.lua:892,
-- admitted into the armed set 2026-08-28T06:5xZ) names five factory-leg frames
-- in its own source header as THE DEFECT it was written for:
--
--     venomancer L10 t=786.3 · dragon_knight L11 t=703.5 · necrolyte L10 t=738.8
--     lion L10 t=618.5 · storm_spirit L11 t=694.4
--
-- Those five frames come from one report -- replay desk 2026-08-28T03:52Z,
-- iterations/reports/replay-check/20260828T035500Z.md, table at §3.3. The SAME
-- report, in the table twenty lines further down at §4, says what each of those
-- episodes BOUGHT:
--
--     dragon_knight L11   3025 out /  480 in   6.3x   camp taken, clean
--     death_prophet L10   2906 out /  313 in   9.3x   camp taken
--     necrolyte     L10   2786 out /  760 in   3.7x   camp taken
--     storm_spirit  L11   1256 out /  243 in   5.2x   camp taken
--     lion          L10   1193 out /  327 in   3.6x   took half, TP'd out at 621.9
--     venomancer    L10   1007 out /  898 in   1.1x   burned 45pp, camp still alive
--
-- ⭐ THREE of the five frames the lever's header calls the defect are recorded,
-- in the source it cites, as CLEAN TAKES. One more (lion) is a half-take that
-- left cheaply. Exactly ONE (venomancer) is the waste the header describes. The
-- quantity that pooled them -- "mean 10.4pp of the bot's own health burned" --
-- is the PRICE OF A TAKE on five of six and the price of nothing on one.
--
-- ⭐ THE REUSABLE CRITERION, and it is this group's own, one day old. On
-- 2026-08-27T22:25Z the strategy desk withdrew 'abil1st' on the grounds that
-- "the armed branch is reversed on at least one frame inside its own domain --
-- that alone is enough to withdraw, without waiting for the denominator." Here
-- the armed branch is reversed on FOUR frames of six, and they sit on the
-- FACTORY leg, i.e. they are gold the shipped bot earns today. The axis is the
-- same one #263 named: level cannot separate these six (they are 10/10/10/11/
-- 11/10 -- a constant), and "could it finish the camp" can.
--
-- WHAT THIS FILE ASSERTS, and in which of the two worlds
-- -----------------------------------------------------
-- [domain]  the six-episode reading above, as arithmetic: level does not
--           separate takes from non-takes, the damage ratio does (and by how
--           thin a margin -- lion sits one tenth away from necrolyte).
-- [axis]    on REAL frames: vary only the two quantities that separate 6.3x
--           from 1.1x -- how much of the camp is left, and how much health the
--           bot has spent -- and the predicate does not move. That is what
--           "wrong axis" means, stated as a test rather than as prose.
-- [reach]   on REAL frames at both band levels: armed releases the camp at L11
--           (dragon_knight's bracket) exactly as it does at L10.
-- [limit]   the escape that would exonerate the four takes -- one farmable
--           normal creep inside the sweep -- is asserted to exist, so the
--           honest limit is executable and not a footnote.
--
-- WHAT THIS FILE DOES NOT DO. It changes no behaviour, adds no gate id, and
-- does not retire 'campexit' -- admission and retirement are the director's
-- (AGENTS.md; the strategy desk does not un-arm what it did not arm). It says
-- what the armed branch does on the frames the lever was written for.
--
-- THE CREEP HALF IS DECLARED, NOT CORPUS -- same as its two sibling files, and
-- [world W1] asserts it rather than footnoting it: no fixture in this tree
-- carries neutral creeps, so the camps below are stand-ins holding exactly the
-- fields the shipped code reads. The BOT half (level, health, mana, position,
-- every hero on the map) is real.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

-- The one deep-dived band episode whose own bot is in this tree: the venomancer
-- of GH #265's load-bearing photograph, and the ONLY pure loss of the six.
local VENO_L10 = { 'tests/fixtures/f_20260828_004757_venomancer_785.lua',
                   'npc_dota_hero_venomancer', 10 }
-- dragon_knight's frame is not in the tree (its .dem is in S3 and this desk
-- spends no AWS). L11 is the operand that matters -- level is the only bot
-- input the predicate reads besides the sweep -- so a real L11 bot stands in
-- for it, the substitution the replay-fixture skill allows and the sibling file
-- test_campexit_tier_release.lua already makes for the same reason.
local BB_L11   = { 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
                   'npc_dota_hero_bristleback', 11 }

local BAND = { VENO_L10, BB_L11 }

-- replay-check 2026-08-28T03:55Z §4, verbatim. This is a REGISTERED READING,
-- not a measurement this file makes: if the corpus is re-read and these move,
-- this table is one of the places that has to be edited.
local EPISODES = {
    { hero = 'dragon_knight', level = 11, out = 3025, into = 480, took = true  },
    { hero = 'death_prophet', level = 10, out = 2906, into = 313, took = true  },
    { hero = 'necrolyte',     level = 10, out = 2786, into = 760, took = true  },
    { hero = 'storm_spirit',  level = 11, out = 1256, into = 243, took = true  },
    { hero = 'lion',          level = 10, out = 1193, into = 327, took = false },
    { hero = 'venomancer',    level = 10, out = 1007, into = 898, took = false },
}

local function ratio(e) return e.out / e.into end

local function subject(spec)
    local J, _, heroes = rf.load(spec[1], spec[2])
    -- Same declaration both sibling files make and for the same reason: this
    -- lever is about a bot already committed to a camp, not a lane under attack.
    rf.declare_defend_ping(J, 'stale')
    local bot = heroes[spec[2]]
    assert(bot ~= nil, 'fixture no longer carries ' .. spec[2] .. ' -- ' .. spec[1])
    assert(bot:GetLevel() == spec[3], string.format(
        '%s: the frame moved -- expected level %d, fixture carries %d',
        spec[2], spec[3], bot:GetLevel()))
    return J, bot
end

local function creep(bot, sName, nHealth, nMaxHealth, bAncient, dist)
    local loc = bot:GetLocation()
    local d = (dist or 300) / math.sqrt(2)
    return api.MakeUnit({
        GetUnitName = sName,
        GetHealth = nHealth,
        GetMaxHealth = nMaxHealth or nHealth,
        IsAncientCreep = bAncient,
        IsNull = false,
        CanBeSeen = true,
        IsAlive = true,
        IsInvulnerable = false,
        IsHero = false,
        GetLocation = api.Vector(loc.x + d, loc.y + d, 0),
    })
end

-- An all-ancient camp, at a stated fraction of its own health. `frac` is the
-- FIRST of the two quantities that separated the six episodes: at 6.3x the camp
-- is about to die, at 1.1x it is barely scratched.
local function ancient_camp(bot, frac)
    frac = frac or 1.0
    return {
        creep(bot, 'npc_dota_neutral_black_dragon',    math.floor(2200 * frac), 2200, true, 250),
        creep(bot, 'npc_dota_neutral_black_drake',     math.floor(1100 * frac), 1100, true, 300),
        creep(bot, 'npc_dota_neutral_prowler_acolyte', math.floor( 850 * frac),  850, true, 340),
    }
end

tests['[ratchet][domain] no level cut separates the six -- one level holds both outcomes'] = function()
    -- ⚠ The first version of this test asserted the stronger and FALSE thing --
    -- that the take levels and the non-take levels are the same set -- and the
    -- test caught it on the first run: both non-takes are L10, so L11 is 2/2
    -- takes in this sample. The true statement is the weaker one, and it is the
    -- one the argument actually needs.
    local take, not_take = {}, {}
    for _, e in ipairs(EPISODES) do
        assert(e.level == 10 or e.level == 11, e.hero ..
            ': left the 10..11 band the lever is about')
        if e.took then take[e.level] = (take[e.level] or 0) + 1
        else not_take[e.level] = (not_take[e.level] or 0) + 1 end
    end
    -- Level 10 carries two takes (death_prophet, necrolyte) AND both non-takes
    -- (lion, venomancer). So no threshold on level -- inside the band or at
    -- either edge of it -- can exclude the loss without also excluding takes.
    local mixed = nil
    for lvl in pairs(take) do if not_take[lvl] then mixed = lvl end end
    assert(mixed ~= nil, 'no level value carries both a take and a non-take any ' ..
        'more -- level started separating the six, which is the premise this ' ..
        'whole file argues against')
    assert(take[mixed] >= 2 and not_take[mixed] >= 2, string.format(
        'level %d used to carry 2 takes and 2 non-takes, now %d and %d',
        mixed, take[mixed] or 0, not_take[mixed] or 0))
    -- And the direction of the asymmetry, recorded rather than glossed: the
    -- UPPER half of the band is 2/2 takes here. If level says anything at all in
    -- this sample it says the opposite of what the lever assumes.
    assert(take[11] == 2 and not_take[11] == nil, string.format(
        'L11 stopped being 2/2 takes (now %d takes, %d non-takes) -- the ' ..
        'asymmetry noted above moved', take[11] or 0, not_take[11] or 0))
end

tests['[ratchet][domain] ⭐ four of six took the camp, and the ratio -- not level -- orders them'] = function()
    local takes = 0
    for _, e in ipairs(EPISODES) do if e.took then takes = takes + 1 end end
    assert(takes == 4, string.format(
        'the registered reading moved: %d of %d episodes took the camp, the ' ..
        'published table says 4', takes, #EPISODES))

    -- venomancer is the one pure loss and it is the strict minimum of the ratio
    -- column -- by a factor of three against every take.
    local worst, worst_hero = 1e9, nil
    for _, e in ipairs(EPISODES) do
        if ratio(e) < worst then worst, worst_hero = ratio(e), e.hero end
    end
    assert(worst_hero == 'venomancer', 'the minimum-ratio episode is no longer ' ..
        'the venomancer of GH #265, it is ' .. tostring(worst_hero))
    for _, e in ipairs(EPISODES) do
        if e.took then
            assert(ratio(e) > 3 * worst, string.format(
                '%s took its camp at %.2fx, no longer 3x clear of the one loss ' ..
                'at %.2fx', e.hero, ratio(e), worst))
        end
    end
end

tests['[domain] the margin is THIN -- lion sits one tenth from necrolyte, say so'] = function()
    -- Guard against this file being read as "the ratio cleanly separates". It
    -- separates, but the nearest pair is 3.6 (lion, left) against 3.7
    -- (necrolyte, took) -- a tenth. Any completion clause built on a ratio
    -- threshold is choosing a number inside that gap, and lion is the cheap
    -- intermediate the replay desk flagged: took half, TP'd out, burned 28pp.
    local best_not, worst_take = 0, 1e9
    for _, e in ipairs(EPISODES) do
        if e.took then worst_take = math.min(worst_take, ratio(e))
        else best_not = math.max(best_not, ratio(e)) end
    end
    assert(worst_take > best_not, string.format(
        'the ratio stopped separating: worst take %.2fx <= best non-take %.2fx',
        worst_take, best_not))
    assert(worst_take - best_not < 0.5, string.format(
        'the gap grew to %.2f -- if a re-read really widened it, this assertion ' ..
        'is the place to record that, not to delete', worst_take - best_not))
end

tests['[world W1] the neutral sweep is DECLARED on these frames, not corpus'] = function()
    for _, spec in ipairs(BAND) do
        local _, bot = subject(spec)
        local a = bot:GetNearbyCreeps(1000, true) or {}
        local b = bot.GetNearbyNeutralCreeps and (bot:GetNearbyNeutralCreeps(1000) or {}) or {}
        assert(#a == 0 and #b == 0, spec[2] ..
            ': a neutral sweep answered non-empty -- the declared camps below ' ..
            'are now shadowing real corpus data, rewrite this file end to end')
    end
end

tests['[ratchet][axis] ⭐ the predicate cannot see how much of the camp is left'] = function()
    -- The first of the two separating quantities. A camp at 5% health is one
    -- right-click from being the dragon_knight episode; a camp at 100% is the
    -- venomancer one. The lever answers identically.
    for _, spec in ipairs(BAND) do
        local J, bot = subject(spec)
        local answers = {}
        for _, frac in ipairs({ 1.00, 0.50, 0.05 }) do
            answers[#answers + 1] = J.IsOverTierCampOnly(bot, ancient_camp(bot, frac), true)
        end
        for _, a in ipairs(answers) do
            assert(a == true, spec[2] ..
                ': armed did not release an all-ancient camp inside the band')
        end
        assert(answers[1] == answers[3], spec[2] ..
            ': the predicate started reading camp health -- if a completion ' ..
            'clause landed, this file records the old behaviour and must be updated')
    end
end

tests['[ratchet][axis] ⭐ nor how much health the bot has already spent'] = function()
    -- The second separating quantity. dragon_knight paid 10.7pp and bought a
    -- camp; venomancer paid 45pp and bought nothing. Same answer either way.
    for _, spec in ipairs(BAND) do
        local J, bot = subject(spec)
        local max = bot:GetMaxHealth()
        local sweep = ancient_camp(bot, 1.0)
        local fresh = J.IsOverTierCampOnly(bot, sweep, true)
        bot.GetHealth = function() return math.floor(max * 0.55) end
        local burned = J.IsOverTierCampOnly(bot, sweep, true)
        assert(fresh == true and burned == true, spec[2] ..
            ': armed stopped releasing across the health range')
        assert(fresh == burned, spec[2] ..
            ': the predicate started reading the bot\'s own health')
    end
    -- and the counterfactual did not leak into the loader.
    local _, bot = subject(VENO_L10)
    assert(bot:GetHealth() == bot:GetMaxHealth(),
        'the health override leaked into the fixture loader -- t=785.4 is the ' ..
        'pre-contact frame and carries full health')
end

tests['[reach] ⭐ armed releases at L11 too -- dragon_knight\'s bracket, not just L10'] = function()
    -- The four takes sit at 10 and 11. Both are inside the refused band, so the
    -- release reaches all four, not only the loss the header describes.
    for _, spec in ipairs(BAND) do
        local J, bot = subject(spec)
        local sweep = ancient_camp(bot, 1.0)
        assert(J.IsOverTierCampOnly(bot, sweep, true) == true, string.format(
            'level %d escaped the armed domain -- the six-episode reading ' ..
            'assumes every one of them is inside it', spec[3]))
        -- for the stated reason, not incidentally
        assert(#J.Site.FilterFarmNeutrals(sweep, bot:GetLevel(), true) == 0,
            spec[2] .. ': the ladder kept an ancient inside the band')
        -- unarmed keeps every byte
        assert(J.IsOverTierCampOnly(bot, sweep, false) == false,
            spec[2] .. ': unarmed fired')
        assert(J.IsOverTierCampOnly(bot, sweep, nil) == false,
            spec[2] .. ': a nil gate stopped behaving like false')
    end
end

tests['[control] at the tier the lever is inert -- it is a tier guard, not an anti-ancient one'] = function()
    local J, bot = subject(VENO_L10)
    bot.GetLevel = function() return 12 end
    local sweep = ancient_camp(bot, 1.0)
    assert(#J.Site.FilterFarmNeutrals(sweep, 12, true) > 0,
        'the ladder refused an ancient at level 12 -- the control is vacuous')
    assert(J.IsOverTierCampOnly(bot, sweep, true) == false,
        'armed released a camp the bot is entitled to take')
    local _, again = subject(VENO_L10)
    assert(again:GetLevel() == 10, 'the level override leaked into the loader')
end

tests['[limit] ⭐ the escape that would exonerate the four takes, made executable'] = function()
    -- HONEST LIMIT: no fixture carries the sweep those four bots actually stood
    -- in. If any of them held one farmable normal creep inside 1000u, 'campexit'
    -- would NOT have fired there and the reversal above would shrink by that
    -- episode. That escape is not a footnote here -- it is asserted, so a change
    -- that removes it (e.g. a version that reads only the ancients in the sweep)
    -- turns this red instead of quietly widening the domain.
    for _, spec in ipairs(BAND) do
        local J, bot = subject(spec)
        local sweep = ancient_camp(bot, 1.0)
        sweep[#sweep + 1] = creep(bot, 'npc_dota_neutral_kobold', 300, 300, false, 400)
        assert(J.IsOverTierCampOnly(bot, sweep, true) == false, spec[2] ..
            ': one farmable normal creep no longer spares the camp -- the domain ' ..
            'widened and the honest limit above is gone')
    end
end

tests['[limit reach] what is NOT measured here: how often the branch is entered'] = function()
    -- Carried from both sibling files. The lever needs the bot already latched
    -- into Think()'s third neutral branch; a fixture cannot read FARM_STATE or
    -- GetActiveMode, so "the four takes went through :892" stays an inference
    -- from the position traces (15-16s stationary on a camp), not a read. It is
    -- the same inference the lever's own case rests on, used in both directions.
    local _, bot = subject(VENO_L10)
    assert(bot.GetActiveMode == nil or bot:GetActiveMode() == nil
        or type(bot:GetActiveMode()) == 'number',
        'GetActiveMode became readable -- if it now carries the real mode, both ' ..
        'this file and test_campexit_tier_release.lua can upgrade that inference')
end

return tests

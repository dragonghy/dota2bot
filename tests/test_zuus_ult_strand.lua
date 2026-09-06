-- [hero] `zusultstrand` -- the RETREAT branch of Zeus's X.ConsiderR is guarded by
-- a conjunct that cannot be true, so the "cash the ult before you die" path has
-- never run.  Written 2026-09-06 under OWNER_PRIORITIES P4.4 (bots/ 主体配额).
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_zuus.lua, X.ConsiderR:
--
--     if J.IsRetreating( bot ) and bot:WasRecentlyDamagedByAnyHero( 2.0 )
--     then
--         if bot:GetRespawnTime() > abilityR:GetCooldown()
--             and nHealthPercentage <= 0.28
--
-- The right-hand side of that comparison is a CONSTANT 130: zuus_thundergods_wrath
-- declares `AbilityCooldown 130` with no rank ladder.  The left-hand side is
-- bounded above by the hero respawn table, whose ceiling this repo already pinned
-- for the buyback ladder in bots/FunLib/jmz_func.lua (GH #215): 100s at level 25
-- and above, times turbo's 0.75 = 75s.  75 < 130 at every hero level and every
-- ult rank ⇒ the conjunct is an OFF-SWITCH, not a filter.
--
-- ⭐ THE FACT IS READING-INDEPENDENT, WHICH IS WHY IT IS STATED AS ARITHMETIC ON
-- TWO CEILINGS.  `Unit:GetRespawnTime()` is documented as "seconds until this
-- hero respawns" (docs/BOT_API_REFERENCE.md); what it answers for a LIVING hero
-- is an engine question no offline reading here can settle (AGENTS.md: no
-- bot-side debugging).  It does not need to be settled.  Under "0 while alive"
-- the term is 0 > 130; under the most generous reading available -- the full
-- duration the death WOULD have -- it is at most 75 > 130 in turbo.  False
-- either way.  Section 2 asserts the two ceilings from their SOURCES (the KV
-- snapshot and jmz_func's own GH #215 block) rather than re-typing them, so a
-- patch that moves either one turns this file red instead of leaving a stale
-- "by construction" behind.  Section 4 shows the comparison is nevertheless
-- LIVE -- an impossible 131 flips it -- so section 3's falses are a reading and
-- not a vacuity.
--
-- WHAT THIS FILE COVERS AND WHAT IT DOES NOT -- READ BEFORE QUOTING IT
-- -------------------------------------------------------------------
--   * ⚠️ DIRECTION IS A WIDENING, NOT A NARROWING.  The shipped conjunct is
--     structurally false, so arming can only ADD ult casts on this branch and
--     can never remove one.  A negative wave reading on this id may NOT be read
--     as "fewer ultimates"; the only thing it can mean is that the added casts
--     were bad ones.  Section 5 pins the direction as an assertion.
--   * WHAT IS READ OFF REAL FRAMES: the right-hand 130, on all 7 Zeus-subject
--     fixtures that carry the ult handle (section 3 -- GetCooldown has been
--     served off the KV snapshot since 2026-09-04, so it is a read), and the
--     armed radius term, which is enemy-hero POSITIONS and is frame data
--     (section 5: 6 of 8 frames have a chaser inside 1600).
--   * ⚠️ THE LEFT-HAND 0 THOSE FRAMES REPORT IS A LOADER GAP, NOT FRAME DATA,
--     AND THE TWO SENTENCES MAY NOT BE MERGED.  Nothing under tests/mock/
--     installs GetRespawnTime, so the generic `^Get` default answers 0
--     (tests/mock/bot_api.lua:182).  Section 6 pins that as a ONE-WAY TRIPWIRE:
--     the day a dumper or loader wires the getter, this file goes red and says
--     so rather than staying quietly green on a number it never earned.
--   * ⚠️ NO CREATION FRAME EXISTS FOR THE BRANCH AS A WHOLE, so "the armed
--     branch fires" is NOT a reading this round bought.  The only Zeus frame
--     under 28% HP (f_181441_zuus_lowhp_limbo, 15.8%) misses on two other
--     conjuncts at once: the ult sits on a 2.2s cooldown, and its nearest enemy
--     is 2017u away -- outside the armed radius.  Section 6 states both as the
--     limits they are.  Sizing the branch's real frequency is a corpus question
--     for iterations/queue.json, never this scan.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local shapes = require('mock.special_value_shapes')

local SRC = 'bots/BotLib/hero_zuus.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'
local ULT = 'zuus_thundergods_wrath'
local CAND = 'zusultstrand'

-- Every Zeus-SUBJECT fixture, listed rather than globbed so a new one is a
-- deliberate edit and the counts below move with a named cause.
local ZUUS_FRAMES = {
    'tests/fixtures/f_072738_zuus_mana.lua',
    'tests/fixtures/f_073148_zuus_lina.lua',
    'tests/fixtures/f_163714_zuus_commit_pin.lua',
    'tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
    'tests/fixtures/f_230952_zuus_ult_hoard.lua',
    'tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
    'tests/fixtures/f_260819_142047_zuus_ult_manalock.lua',
    'tests/fixtures/f_260819_222052_zuus_w2_leak.lua',
}

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

--- Comments stripped, so a ratchet counting code shapes cannot be satisfied by
--- prose that merely quotes the expression -- and this file's headers quote it
--- several times on purpose.
local function strip_comments(body)
    return (body:gsub('%-%-[^\n]*', ''))
end

--- Load one real frame and arm (or do not arm) `zusultstrand`.
---
--- `opt.armed == true` rather than a truthiness test: an absent key would arm
--- nothing, and an assertion expecting the shipped answer would then pass for
--- the wrong reason.
local function on_frame(path, opt)
    opt = opt or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return opt.armed == true and id == CAND end
    if opt.nonTurbo then
        -- rf.load's install() forces turbo; undo it AFTER load.
        GetGameMode = function() return 1 end
    end
    local X = rf.load_hero('zuus')
    return X, J, bot, heroes, fx
end

--- The subject's own ult handle on a loaded frame, or nil when the FRAME does
--- not name the ability at all (f_073148_zuus_lina is the corpus's one such
--- frame -- its subject's ability array stops before the ultimate).
---
--- The frame's own array is what decides, NOT the handle: bot:GetAbilityByName
--- answers a live table for any name whatsoever, and an uninstalled one reports
--- the generic `^Get` zero.  Asking the handle would have folded "the loader
--- served no spec" into "the KV says 0" -- the exact indistinguishability
--- tests/mock/replay_fixture.lua names as the reason the third KV batch installs
--- a getter for every ability rather than only the declaring ones.
local function ult_handle(bot, fx)
    local named = false
    for _, u in ipairs(fx.units or {}) do
        if u.name == fx.self then
            for _, a in ipairs(u.abilities or {}) do
                if a.name == ULT then named = true end
            end
        end
    end
    if not named then return nil end
    return bot:GetAbilityByName(ULT)
end

--- Replace GetRespawnTime on the loaded subject with a LABELLED constant.  Every
--- call site of this helper in this file is a declared injection: no fixture
--- carries a respawn reading, and pretending otherwise is exactly the merge the
--- header forbids.
local function inject_respawn(bot, nSeconds)
    bot.GetRespawnTime = function() return nSeconds end
end

-- ---------------------------------------------------------------- section 1 --
-- The call site is wired.  These going red mean "re-read the file", never "the
-- test is stale": an unwired gate measures nothing, and check_armed_wiring.py
-- would still call it WIRED because a call site exists somewhere.

tests['section 1: ConsiderR no longer compares respawn to cooldown inline'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('GetRespawnTime%s*%(%s*%)%s*>%s*abilityR:GetCooldown') == nil,
        'X.ConsiderR still holds the bare `bot:GetRespawnTime() > abilityR:GetCooldown()` '
        .. 'comparison -- the call site was not wired, so the gate is dead and every '
        .. 'reading taken through it measures nothing.')
    assert(body:find('X%.zuus_ShouldCashUltBeforeDeath%s*%(%s*bot%s*%)') ~= nil,
        'X.ConsiderR no longer calls X.zuus_ShouldCashUltBeforeDeath( bot ).')
end

tests['section 1: the helper still contains the shipped expression verbatim'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'zuus_ShouldCashUltBeforeDeath'))
    assert(body:find('hBot:GetRespawnTime%s*%(%s*%)%s*>%s*abilityR:GetCooldown%s*%(%s*%)') ~= nil,
        'the shipped comparison is gone from the helper. Gate-off equivalence is '
        .. 'structural only while the shipped expression is evaluated FIRST and '
        .. 'returned unchanged.')
    assert(body:find("J%.IsModeTurbo%s*%(%s*%)%s*and%s*J%.IsSoakCandidate%s*%(%s*'" .. CAND .. "'%s*%)") ~= nil,
        'the helper no longer gates on turbo AND the ' .. CAND .. ' soak id.')
end

-- ---------------------------------------------------------------- section 2 --
-- The arithmetic premise, read from its two sources rather than re-typed.  This
-- is the load-bearing assertion of the whole round: everything else follows from
-- "the ult's cooldown strictly exceeds the respawn ceiling".

--- The ult's declared cooldown ladder, off the KV snapshot.
local function ult_cooldown_steps()
    local kv = (shapes.SHAPES or shapes)['zuus'][ULT]['AbilityCooldown']
    assert(kv ~= nil and kv.base ~= nil, 'no AbilityCooldown base for ' .. ULT)
    local steps = {}
    for tok in kv.base:gmatch('%S+') do steps[#steps + 1] = assert(tonumber(tok)) end
    return steps
end

--- The turbo respawn ceiling, READ OUT OF jmz_func's own GH #215 block.  If that
--- block is rewritten or the numbers move, this test moves with it instead of
--- certifying a premise the tree no longer states.
local function turbo_respawn_ceiling()
    local body = read_file(JMZ)
    local base, factor, ceiling = body:match('(%d+)%s*%*%s*(0%.%d+)%s*=%s*(%d+)%s+seconds')
    assert(ceiling ~= nil,
        'jmz_func.lua no longer states the turbo respawn ceiling as `<table max> * '
        .. '<turbo factor> = <ceiling> seconds`. This file quotes that block rather '
        .. 'than re-typing 75; re-anchor it deliberately.')
    assert(tonumber(base) * tonumber(factor) == tonumber(ceiling),
        'the respawn ceiling arithmetic in jmz_func.lua does not multiply out.')
    return tonumber(ceiling), tonumber(base)
end

tests['section 2: the ult cooldown is flat and exceeds every respawn ceiling'] = function()
    local steps = ult_cooldown_steps()
    local turboCeiling, normalCeiling = turbo_respawn_ceiling()
    assert(#steps == 1, string.format(
        '%s now declares a %d-step AbilityCooldown ladder. The header argues from a '
        .. 'CONSTANT right-hand side; re-argue it per rank.', ULT, #steps))
    for i, cd in ipairs(steps) do
        assert(cd > turboCeiling, string.format(
            'rank %d cooldown %s is not above the turbo respawn ceiling %d -- the '
            .. 'conjunct is no longer structurally false and the lever needs re-arguing.',
            i, tostring(cd), turboCeiling))
        assert(cd > normalCeiling, string.format(
            'rank %d cooldown %s is not above the NORMAL-mode respawn ceiling %d. The '
            .. 'header concedes normal mode only via Octarine; without that concession '
            .. 'holding, re-argue the mode split.', i, tostring(cd), normalCeiling))
    end
end

-- ---------------------------------------------------------------- section 3 --
-- Real frames.  What is bought here is the RIGHT-hand side; the left-hand 0 is
-- section 6's tripwire and is not evidence.

tests['section 3: GetCooldown reads the KV cooldown on every real Zeus frame'] = function()
    local expected = ult_cooldown_steps()[1]
    local nSeen = 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local _, _, bot, _, fx = on_frame(path)
        local h = ult_handle(bot, fx)
        if h ~= nil then
            local cd = h:GetCooldown()
            assert(cd == expected, string.format(
                '%s: abilityR:GetCooldown() read %s, not the KV %s. Either the loader '
                .. 'stopped serving AbilityCooldown or the KV moved; both retire the '
                .. "header's arithmetic.", path, tostring(cd), tostring(expected)))
            nSeen = nSeen + 1
        end
    end
    assert(nSeen >= 7, string.format(
        'only %d of %d Zeus frames answered a cooldown. The 130 is the load-bearing '
        .. 'half of the argument and it must be READ, not assumed.', nSeen, #ZUUS_FRAMES))
end

tests['section 3: the shipped conjunct is false on every real Zeus frame'] = function()
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, _, bot, _, fx = on_frame(path)
        local h = ult_handle(bot, fx)
        if h ~= nil then
            assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false, string.format(
                '%s: the UNARMED helper answered true. The header claims the shipped '
                .. 'conjunct cannot be true; a frame that makes it true retires the claim.',
                path))
        end
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The comparison is LIVE.  Without this, section 3's falses could equally be
-- produced by a helper that ignores its inputs -- exactly the "an assertion that
-- cannot fail is not evidence" trap GH #560 wrote down.

tests['section 4: an impossible respawn flips the shipped conjunct'] = function()
    local path = 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua'
    local expected = ult_cooldown_steps()[1]
    local X, _, bot = on_frame(path)

    -- LABELLED INJECTION. No fixture carries a respawn reading; these are values
    -- this test installs, and they are not frame data.
    inject_respawn(bot, turbo_respawn_ceiling())
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false,
        'at the turbo respawn CEILING the shipped conjunct answered true -- then the '
        .. 'branch is reachable in turbo and the whole lever is misdiagnosed.')

    inject_respawn(bot, expected + 1)
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == true, string.format(
        'a respawn of %d against a cooldown of %d did NOT flip the conjunct. The '
        .. 'comparison is not live, so every false this file records is a vacuity.',
        expected + 1, expected))
end

-- ---------------------------------------------------------------- section 5 --
-- Gate-off equivalence, direction, and the armed radius term.

tests['section 5: gate-off returns the shipped boolean, value for value'] = function()
    local expected = ult_cooldown_steps()[1]
    local path = 'tests/fixtures/f_230952_zuus_ult_hoard.lua'   -- chaser at 164u
    for _, nRespawn in ipairs({ 0, 12, 75, expected - 1, expected, expected + 1, 999 }) do
        for _, nonTurbo in ipairs({ false, true }) do
            local X, _, bot = on_frame(path, { armed = false, nonTurbo = nonTurbo })
            inject_respawn(bot, nRespawn)
            local got = X.zuus_ShouldCashUltBeforeDeath(bot)
            local want = nRespawn > expected
            assert(got == want, string.format(
                'gate-off answered %s at respawn %d (nonTurbo=%s); the shipped '
                .. 'expression says %s. Gate-off must be the shipped tree value for '
                .. 'value.', tostring(got), nRespawn, tostring(nonTurbo), tostring(want)))
        end
    end
end

tests['section 5: armed is a WIDENING -- it never withdraws a shipped true'] = function()
    local expected = ult_cooldown_steps()[1]
    local path = 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua' -- nearest enemy 2017u
    for _, nRespawn in ipairs({ 0, 75, expected, expected + 1, 999 }) do
        local Xoff, _, botOff = on_frame(path, { armed = false })
        inject_respawn(botOff, nRespawn)
        local off = Xoff.zuus_ShouldCashUltBeforeDeath(botOff)

        local Xon, _, botOn = on_frame(path, { armed = true })
        inject_respawn(botOn, nRespawn)
        local on = Xon.zuus_ShouldCashUltBeforeDeath(botOn)

        assert(not (off and not on), string.format(
            'arming WITHDREW a shipped true at respawn %d. This lever is a widening '
            .. 'by construction -- the shipped expression runs first and short-circuits '
            .. '-- so a withdrawal means the helper was restructured.', nRespawn))
    end
end

tests['section 5: the armed radius term is not vacuous on real frames'] = function()
    local nInside, nOutside = 0, 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, _, bot, _, fx = on_frame(path, { armed = true })
        local h = ult_handle(bot, fx)
        if h ~= nil then
            if X.zuus_ShouldCashUltBeforeDeath(bot) then
                nInside = nInside + 1
            else
                nOutside = nOutside + 1
            end
        end
    end
    -- Both counts positive is the whole point: a term that admitted every frame
    -- would be a widening with no narrowing in it, and a term that admitted none
    -- would be a second off-switch.  These are POSITIONS, which is frame data.
    assert(nInside > 0, 'the armed radius term admitted 0 of the real Zeus frames -- '
        .. 'that is a second off-switch, not a narrowing.')
    assert(nOutside > 0, 'the armed radius term admitted EVERY real Zeus frame -- then '
        .. 'it narrows nothing and the widening is a blank cheque.')
end

tests['section 5: armed refuses when no chaser is inside the radius'] = function()
    -- The assertion a "return true unconditionally" mutant does not survive.
    -- f_260819_142047_zuus_ult_denied has its nearest enemy 7479u away.
    local X, _, bot = on_frame('tests/fixtures/f_260819_142047_zuus_ult_denied.lua',
        { armed = true })
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false,
        'the armed leg fired with the nearest enemy hero 7479u away. The radius term '
        .. 'is the only thing keeping this widening narrow; without it the branch '
        .. 'cashes a 250-500 mana ultimate at every low-HP retreat.')
end

tests['section 5: non-turbo never reaches the armed leg'] = function()
    local X, _, bot = on_frame('tests/fixtures/f_230952_zuus_ult_hoard.lua',
        { armed = true, nonTurbo = true })
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false,
        'the armed leg fired outside turbo. The header concedes a real normal-mode '
        .. 'window (level-25 Octarine, 97.5s < 100s) and explicitly does NOT touch it.')
end

-- ---------------------------------------------------------------- section 6 --
-- The limits, as one-way tripwires rather than prose.  Each of these going red
-- is GOOD NEWS -- it means the corpus grew a reading this round could not buy.

tests['section 6: TRIPWIRE -- no fixture reports a respawn time'] = function()
    for _, path in ipairs(ZUUS_FRAMES) do
        local _, _, bot = on_frame(path)
        assert(bot:GetRespawnTime() == 0, string.format(
            '%s answered a non-zero GetRespawnTime. GOOD NEWS: something now wires the '
            .. 'getter, so the left-hand side of the shipped comparison is finally '
            .. 'frame data. Re-read section 3 -- its falses were bought on the RIGHT '
            .. 'hand side only, and this file said so.', path))
    end
end

tests['section 6: TRIPWIRE -- the corpus holds no creation frame'] = function()
    local nCandidate = 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, _, bot, _, fx = on_frame(path, { armed = true })
        local h = ult_handle(bot, fx)
        if h ~= nil
            and h:IsFullyCastable()
            and bot:GetHealth() / bot:GetMaxHealth() <= 0.28
            and X.zuus_ShouldCashUltBeforeDeath(bot)
        then
            nCandidate = nCandidate + 1
        end
    end
    assert(nCandidate == 0, string.format(
        'GOOD NEWS: %d frame(s) now satisfy the armed branch end to end. This round '
        .. 'bought no such frame and said so; take the reading and retire the limit '
        .. 'in the header of bots/BotLib/hero_zuus.lua.', nCandidate))
end

tests['section 6: the one sub-28%% frame misses on two other conjuncts'] = function()
    -- Stated as an assertion so "no creation frame" carries its REASON and not
    -- just its count -- the difference between a limit and an excuse.
    local X, _, bot, _, fx = on_frame('tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
        { armed = true })
    assert(bot:GetHealth() / bot:GetMaxHealth() <= 0.28,
        'f_181441_zuus_lowhp_limbo is no longer under the 28% bar; the header quotes '
        .. 'it as the corpus\'s only sub-28% Zeus frame.')
    local h = ult_handle(bot, fx)
    assert(h ~= nil and not h:IsFullyCastable(),
        'the ult is now castable on f_181441_zuus_lowhp_limbo -- one of the two '
        .. 'misses the header names is gone. Re-read whether this is now a creation '
        .. 'frame.')
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == false,
        'the armed radius term now admits f_181441_zuus_lowhp_limbo -- the OTHER of '
        .. 'the two misses is gone (its nearest enemy was 2017u).')
end

return tests

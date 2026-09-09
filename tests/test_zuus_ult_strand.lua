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
--     (section 5: 6 of 8 handle-carrying frames have a chaser inside the radius).
--   * ⭐ THE RADIUS WAS NARROWED 1600 -> 700 ON 2026-09-09 and section 7 is where
--     that lives.  The archive scan this lever asked for came back
--     (queue.json:hero-37) and priced 1600 on the branch's own domain at 98.1% of
--     EPISODES -- so the helper's "narrowed, not a blank cheque" paragraph was
--     false at the value it was written with.  Section 7 names the one real frame
--     the new value moves (f_073148_zuus_lina, nearest enemy 979.8u) and asserts
--     the creation frame is not moved.  ⚠️ It does NOT price 700 on the domain:
--     that reading is cut by the 1600 predicate and prices only the 1600 leg.
--     Requested as queue.json:hero-55.
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
    -- Added 2026-09-08 (hero stream) paying GH #593: the CREATION frame the
    -- corpus lacked when this file was written. Listing it here is what retires
    -- section 6's second tripwire -- the tripwire fires on the list, so the
    -- retirement is a reading and not an edit to a sentence.
    'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
}

-- The creation frame, named once so section 6 can say WHICH frame carries the
-- reading rather than only how many do.
local CREATION_FRAME = 'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua'

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

-- RETIRED 2026-09-08 (hero stream, GH #593). What stood here was a one-way
-- tripwire asserting `nCandidate == 0` and calling its own red GOOD NEWS. It is
-- red now, and this is the reading it asked for -- so the limit is replaced by
-- the count it was waiting for, in the same place, rather than deleted.
--
-- ⚠️ WHAT THIS SECTION DOES AND DOES NOT SAY, and the two may not be merged.
-- It says the HELPER's three conjuncts are satisfied together by real frame
-- data on one archived instant. It does NOT say the BRANCH cast an ultimate:
-- X.ConsiderR's outer `J.IsRetreating` is bot-VM mode, no .dem carries it, and
-- the 0 -> 0.75 end-to-end flip is bought with that ONE named substitution in
-- tests/test_replay_260827_zuus_ultstrand_creation.lua section 3, whose own
-- section 5 states the un-injected answer (still 0) as an assertion.
tests['section 6: the corpus holds the creation frame, and this is which one'] = function()
    local tCandidate = {}
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, _, bot, _, fx = on_frame(path, { armed = true })
        local h = ult_handle(bot, fx)
        if h ~= nil
            and h:IsFullyCastable()
            and bot:GetHealth() / bot:GetMaxHealth() <= 0.28
            and X.zuus_ShouldCashUltBeforeDeath(bot)
        then
            tCandidate[#tCandidate + 1] = path
        end
    end
    assert(#tCandidate >= 1,
        'the corpus no longer satisfies the armed helper end to end on ANY frame. '
        .. 'This is a REGRESSION of the reading GH #593 delivered, not a return to '
        .. 'the old limit: either the fixture stopped loading, the helper stopped '
        .. 'reading it, or ' .. CREATION_FRAME .. ' left the list above.')
    -- Counted exactly, not `>= 1`. A loosened conjunct here (the 28% bar, the
    -- castability read, the armed flag on on_frame) admits frames that are not
    -- creation frames, and a `>= 1` written next to a named frame would stay
    -- green through exactly that -- the assertion would then be measuring the
    -- list rather than the helper.
    assert(#tCandidate == 1, string.format(
        '%d frames now satisfy the armed helper end to end, not 1. If a second '
        .. 'creation frame really entered tests/fixtures/, that is GOOD NEWS and it '
        .. 'needs its own price (which game, which instant, what happened next) '
        .. 'before this count moves. If nothing was added to ZUUS_FRAMES, one of '
        .. "this test's own conjuncts has been loosened.", #tCandidate))
    local bNamed = false
    for _, path in ipairs(tCandidate) do
        if path == CREATION_FRAME then bNamed = true end
    end
    assert(bNamed, string.format(
        'the creation frame is no longer %s (the %d frame(s) that qualify are other '
        .. 'ones). GH #593 priced THAT instant -- 17.6%% hp, rank-1 ult off cooldown, '
        .. '405 mana, a chaser at 304.9u, dead 8.3s later with the ult unspent -- so '
        .. 'a different frame carrying the reading needs its own price, not this '
        .. "one's.", CREATION_FRAME, #tCandidate))
end

-- ---------------------------------------------------------------- section 7 --
-- The RADIUS, narrowed 1600 -> 700 on 2026-09-09 because the archive scan the
-- lever asked for came back and priced the old value at 98.1% of episodes
-- (queue.json:hero-37, replay-check domain_scan_hero_2_30_31.md section 10).
--
-- ⚠️ THE TWO INSTRUMENTS IN THIS SECTION MAY NOT BE MERGED WITH THAT ONE.  The
-- 98.1% is an ARCHIVE reading over 1,843 domain frames / 257 episodes / 152
-- games; what this section reads is 9 fixtures, which is not the branch's domain
-- (most of them are neither retreating nor under 28%).  This section can say
-- WHICH real frames the new value moves and that the motivating instant survives.
-- It cannot say what fraction of the domain 700 admits -- no column cuts the
-- corpus by 700, and a reading cut by predicate X prices only the leg written
-- with X.  That column is requested as queue.json:hero-55.

--- Override the shipped radius with a LABELLED constant.  Every call site is a
--- declared substitution: 1600 is no longer a value this tree holds, and a test
--- that read it back without saying so would be quoting a retired number as if
--- the source still stated it.
local function inject_radius(X, nUnits)
    X.nUltCashChaseRadius = nUnits
end

local RADIUS_OLD = 1600
local MOVED_FRAME = 'tests/fixtures/f_073148_zuus_lina.lua'  -- nearest enemy 979.8u

tests['section 7: the shipped radius is 700 and the source says why'] = function()
    local X = rf.load_hero('zuus')
    assert(X.nUltCashChaseRadius == 700, string.format(
        'X.nUltCashChaseRadius is %s, not 700. The value is not free: 700 is this '
        .. 'repo\'s own "an enemy can strike me this instant" ring '
        .. '(J.CanEnemyInterruptTpChannel searches R=700 unarmed, and '
        .. 'tools/batch_test/behavioral/tpreach_domain.py derives the same bound '
        .. 'from the corpus -- reach > 700 needs GetAttackRange() > 550). Moving it '
        .. 'is a re-argument, not an edit.', tostring(X.nUltCashChaseRadius)))

    -- The narrowing rests on a claim about the branch ABOVE the helper, so that
    -- claim is asserted rather than left in prose: if the enclosing conjunct
    -- stops being "was damaged by a hero in the last 2 seconds", the
    -- collinearity argument for why 1600 measured as a tautology is gone.
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('WasRecentlyDamagedByAnyHero%s*%(%s*2%.0%s*%)') ~= nil,
        'X.ConsiderR no longer guards this branch with '
        .. 'bot:WasRecentlyDamagedByAnyHero( 2.0 ). The radius is argued down to '
        .. '700 BECAUSE that conjunct already implies "an enemy was within its own '
        .. 'attack range moments ago"; without it, re-argue the ring.')
end

tests['section 7: the narrowing MOVES a real frame, and this is which one'] = function()
    -- Not `>= 1 frame moved`: a count without a name would stay green if some
    -- unrelated frame started moving and this one stopped.
    local Xold, _, botOld = on_frame(MOVED_FRAME, { armed = true })
    inject_radius(Xold, RADIUS_OLD)                       -- LABELLED injection
    assert(Xold.zuus_ShouldCashUltBeforeDeath(botOld) == true, string.format(
        '%s no longer passes the armed leg at the RETIRED radius %d. This frame is '
        .. 'the whole real-frame evidence that 1600 -> 700 changed an answer; if it '
        .. 'stopped passing at 1600, the narrowing is now a no-op on this corpus '
        .. 'and the mutation stand below is anchored on nothing.',
        MOVED_FRAME, RADIUS_OLD))

    local Xnew, _, botNew = on_frame(MOVED_FRAME, { armed = true })
    assert(Xnew.zuus_ShouldCashUltBeforeDeath(botNew) == false, string.format(
        '%s still passes the armed leg at the SHIPPED radius. Its nearest enemy '
        .. 'hero is Lina at 979.8u -- outside every attack range in the pool, so '
        .. 'she is not a reason the death being priced would happen. That refusal '
        .. 'is the narrowing.', MOVED_FRAME))
end

tests['section 7: the creation frame is NOT moved by the narrowing'] = function()
    -- The narrowing is only defensible if it keeps the instant that motivated the
    -- lever. GH #593 priced that instant; a narrowing that killed it would be a
    -- second off-switch wearing the first one's argument.
    local X, _, bot = on_frame(CREATION_FRAME, { armed = true })
    assert(X.zuus_ShouldCashUltBeforeDeath(bot) == true, string.format(
        '%s no longer passes the armed leg at the shipped radius. Its chaser is a '
        .. 'living Slardar at 304.9u -- well inside 700 -- so a refusal here means '
        .. 'the radius term stopped reading positions, not that the frame changed.',
        CREATION_FRAME))
end

tests['section 7: the corpus census at both radii, counted exactly'] = function()
    -- ⚠️ NO HANDLE FILTER HERE, deliberately, and this is the difference from
    -- section 5. X.zuus_ShouldCashUltBeforeDeath never touches the subject's
    -- ability array -- it reads the file-level abilityR upvalue and enemy
    -- POSITIONS -- so filtering by ult_handle would silently drop the one frame
    -- the narrowing moves (f_073148_zuus_lina is the corpus's only frame whose
    -- ability array stops before the ultimate). Section 5's filter is right for
    -- section 5, which is reading GetCooldown; it would have hidden this.
    local nOld, nNew = 0, 0
    for _, path in ipairs(ZUUS_FRAMES) do
        local Xo, _, bo = on_frame(path, { armed = true })
        inject_radius(Xo, RADIUS_OLD)                     -- LABELLED injection
        if Xo.zuus_ShouldCashUltBeforeDeath(bo) then nOld = nOld + 1 end

        local Xn, _, bn = on_frame(path, { armed = true })
        if Xn.zuus_ShouldCashUltBeforeDeath(bn) then nNew = nNew + 1 end
    end
    assert(#ZUUS_FRAMES == 9, string.format(
        'the Zeus frame list holds %d frames, not the 9 these counts were read on. '
        .. 'A frame was added or removed; re-read the census rather than moving the '
        .. 'numbers.', #ZUUS_FRAMES))
    assert(nOld == 7, string.format(
        'the retired radius %d admits %d of %d frames, not 7.', RADIUS_OLD, nOld,
        #ZUUS_FRAMES))
    assert(nNew == 6, string.format(
        'the shipped radius admits %d of %d frames, not 6.', nNew, #ZUUS_FRAMES))
    assert(nNew < nOld,
        'the narrowing admits at least as many frames as the value it replaced -- '
        .. 'on this corpus it is then a no-op, and no real frame backs it.')
    -- Still a reading and not a second off-switch: both outcomes occur.
    assert(nNew > 0,
        'the shipped radius admits 0 of the real Zeus frames -- that is an '
        .. 'off-switch, which is exactly the defect this lever was written against.')
end

tests['section 6: the OTHER sub-28%% frame misses on two other conjuncts'] = function()
    -- Kept after the retirement above, and it is not redundant with it: this is
    -- the frame that shows the helper's conjuncts are what SELECT the creation
    -- frame. A second sub-28% Zeus that the armed helper still refuses is the
    -- difference between "the bar admits the corpus" and "the bar admits this
    -- instant". (It used to be the corpus's ONLY sub-28% frame; since GH #593 it
    -- is one of two, and that is the whole change to this test.)
    local X, _, bot, _, fx = on_frame('tests/fixtures/f_181441_zuus_lowhp_limbo.lua',
        { armed = true })
    assert(bot:GetHealth() / bot:GetMaxHealth() <= 0.28,
        'f_181441_zuus_lowhp_limbo is no longer under the 28% bar; this test exists '
        .. 'to price a sub-28% frame the armed helper still refuses.')
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

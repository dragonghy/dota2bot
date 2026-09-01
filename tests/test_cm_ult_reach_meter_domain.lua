-- [ratchet] [hero] Crystal Maiden, frame by frame over the whole archive: what
-- the repaired mana meter revoked, and the SECOND meter zero sitting on top of
-- her ultimate that the repair did not touch.
--
-- WHY THIS FILE EXISTS (hero 2026-09-01, backlog -43a's Crystal Maiden
-- direction -- the last of the three the charter owed).  The entry point the
-- previous round handed over was "CM's 16 revoked castable readings + the three
-- readings that miss by one point of mana".  Both halves turned out to be worth
-- less than they looked, and what they were sitting on top of is worth more.
--
-- ===========================================================================
-- 1.  THE 16 REVOCATIONS, REPRODUCED INDEPENDENTLY
-- ===========================================================================
--
-- Every live-CM instant in the archive (tests/fixtures/ + tests/frames/),
-- driven through the real loader.  Buckets are exhaustive and re-sum:
--
--     live-CM instants ....................................  48
--     ability handles on them ............................. 209
--     ... trained (rank >= 1) ............................. 195
--     ... and off cooldown  = "castable" BEFORE the repair . 157
--     ... and mp >= the KV price = castable AFTER it ....... 141
--     revoked by charging the price ........................  16
--         crystal_nova 7 | frostbite 4 | freezing_field 5
--
-- ===========================================================================
-- 2.  THE THREE "ONE POINT OF MANA" READINGS ARE THE SAFE ONES.  The reading
--     nobody flagged is the undecidable one, and it fails toward CASTABLE.
-- ===========================================================================
--
-- The handover called out three revocations that miss by exactly 1 mana (399
-- vs 400, 154 vs 155 twice) as knife edges.  They are not, and the dumper says
-- why.  tools/batch_test/behavioral/dumper/main.go writes mana as
-- `int32(h.mp + 0.5)` -- round-half-up -- so a recorded value v means the true
-- mana was in [v - 0.5, v + 0.5).  For a revocation at margin -1 the whole
-- interval [cost - 1.5, cost - 0.5) lies below cost: she could not cast, and no
-- rounding rule changes that.  All three are DETERMINATE.
--
-- The one reading whose truth the dump cannot settle is the one at margin
-- ZERO: f_260819_004858_cm_centaur_far.lua holds a recorded 200 mana against
-- Freezing Field's 200, so the true value is in [199.5, 200.5) and HALF that
-- interval is below the price.  It is the corpus's only margin-0 reading, it is
-- currently counted as castable, and the direction of its uncertainty is toward
-- castable -- the same dangerous direction the vacuous clause had.  Charging
-- the price shrank that exposure from 157 readings to one; it did not remove it.
--
-- ===========================================================================
-- 3.  WHERE THE MANA TERM CANNOT DECIDE ANYTHING -- CLOSED FORM
-- ===========================================================================
--
-- The loader's own header states the failure direction of a vacuous castable
-- clause tree-wide: it OVERSTATES reachability.  That is a property of the call
-- site's polarity, not of the clause, and Crystal Maiden holds the counter-
-- example: X.ConsiderR reads `not abilityQ:IsFullyCastable() and not
-- abilityW:IsFullyCastable()` (hero_crystal_maiden.lua, retreat branch), where
-- free mana SUPPRESSED the branch instead of opening it.
--
-- On this hero it is inert anyway, and by arithmetic rather than by corpus.
-- Reaching those two lines requires Freezing Field to be castable, so
-- mp >= cost(R) >= 200 (ladder 200/400/600).  Crystal Nova tops out at 175 and
-- Frostbite at 155, so mp is necessarily above BOTH of their prices there:
-- whatever makes Q or W uncastable on that branch, it is never mana.  The two
-- negated call sites are decided by cooldown and rank only, at every rank
-- combination the game can produce.
--
-- ===========================================================================
-- 4.  THE DECISION SIDE ANSWERS ZERO ON 48/48 -- AND THAT ZERO IS NOT EVIDENCE
-- ===========================================================================
--
-- Driving all five shipped entry points (ConsiderQ / W / R / ArcaneAura /
-- CrystalClone) on all 48 instants, in the free-mana world and the priced one,
-- gives desire 0 for 240 readings out of 240 on BOTH sides.  Read carelessly
-- that says "charging mana changes no CM decision".  It says nothing of the
-- kind, because the corpus cannot reach a single return site for reasons that
-- have nothing to do with mana:
--
--     GetActiveMode()          answers 0 on 48/48 (mock default; BOT_MODE_NONE)
--     J.IsGoingOnSomeone       false   on 48/48
--     J.IsRetreating           false   on 48/48
--     FindAoELocation().count  0       on 48/48 (documented loader stand-in)
--     GetAOERadius()           0       on 48/48 (section 5)
--
-- Section 4 asserts those five constants so that the 240 zeros can never be
-- quoted as a null result.  "The 0 of an empty predicate and the 0 of an empty
-- corpus are the same integer" -- this file's own version of the trap.
--
-- ===========================================================================
-- 5.  THE SECOND METER ZERO: GetAOERadius, and it hides TWO real decisions
-- ===========================================================================
--
-- `GetAOERadius` is on no ability spec in tests/mock/replay_fixture.lua, so it
-- falls through mock/bot_api.lua's generic `^Get` default and answers 0 -- the
-- fourth member of the family that already holds GetActualIncomingDamage
-- (hero 2026-08-29), GetAbilityDamage (GH #175) and GetManaCost (2026-09-01).
-- Seven call expressions under bots/ read it; X.ConsiderR's `local nRadius =
-- abilityR:GetAOERadius() * 0.88` is one, and it multiplies into every clause
-- of the ultimate's two health-blind branches.  Zero radius therefore makes
-- both branches UNREACHABLE BY CONSTRUCTION on every fixture frame ever
-- generated, and its direction is the opposite of the mana clause's: it
-- UNDERSTATES reachability, so it converts "CM never wants to ult" from a
-- finding into an artifact.
--
-- Supplying the KV radius and re-driving the real X.ConsiderR over all 48
-- instants moves exactly TWO of them from 0 to BOT_ACTION_DESIRE_HIGH:
--
--   f_260820_043039_cm_cask_close.lua    t=515.5  hp 267/890 = 30.0%
--       fires on `#nEnemysHeroesInRange >= 3` (3 enemies inside 0.88*radius);
--       0 allies within 1200; observed.died_after = 0.2s.
--   f_260820_103216_cm_es_aftershock.lua t=473.5  hp 292/1110 = 26.3%
--       fires on `aoeCanHurtCount >= 2`; 0 allies within 1200;
--       observed.died_after = 1.0s.
--
-- Both are a support alone in a gank, one second from death, being handed a
-- ten-second channel.  The meter zero is currently suppressing them for a
-- reason that has nothing to do with why they should be suppressed.
--
-- ===========================================================================
-- 6.  WHAT THAT SAYS ABOUT `cmrself`, WHICH IS PARKED
-- ===========================================================================
--
-- The soak candidate `cmrself` (hero_crystal_maiden.lua, X.cm_IsRSafeToOpen)
-- vetoes the channel when CM is below 38% health and under hero fire.  Armed,
-- it turns BOTH of the frames above back to NONE: on this archive it covers
-- 2 of the 2 frames where the ultimate's fire branches are reachable at all.
--
-- CLOSED FORM, and it is why the id's fate is tied to section 5: the veto sits
-- at the top of X.ConsiderR, but branch 3 (retreat) carries its own
-- `nHP > 0.38` and the veto only fires BELOW 0.38, so the two are disjoint.
-- `cmrself` can therefore only ever change a decision that came from branch 1
-- or branch 2 -- the two branches that multiply through GetAOERadius.  If the
-- engine's GetAOERadius answers 0 for Freezing Field the way this tree's mock
-- does, the id is a no-op by construction in real games; if it answers the KV
-- radius, the id's domain is exactly the fire set.  Nothing in this repository
-- can read that getter (AGENTS.md: no bot-side debugging), so this file states
-- the fork instead of picking a side.
--
-- The 2026-08-21 pre-flight in hero_crystal_maiden.lua's header measured the
-- domain at 1 frame / 1 episode / 1 of 17 games and parked the id, adding that
-- the single frame "rests on aoeCanHurtCount, whose ring is nRadius * 0.82 -
-- GetCurrentMovementSpeed() and movespeed is not in the .dem: at ms >= 330 the
-- domain is 0".  The frame it names is the es_aftershock one.  The cask_close
-- frame is new, comes from a game outside that pre-flight's corpus
-- (20260820_043039 vs its replays/20260820_10*), and fires on
-- `#nEnemysHeroesInRange >= 3`, which reads NO movespeed -- so the fragility
-- caveat no longer covers the whole domain.  That is an addition to the
-- pre-flight's evidence, not a contradiction of its rate.
--
-- ===========================================================================
-- HONEST BOUNDS -- quote these with any number above
-- ===========================================================================
--
-- (A) THE ARCHIVE IS NOT A SAMPLE OF GAMEPLAY.  Fixtures are generated at
--     decision instants somebody went looking for, and several CM fixtures
--     exist precisely because she was dying.  "2 of 48 instants" is a statement
--     about this shelf, never a rate per game.  The unbiased reading of
--     `cmrself`'s frequency remains the 17-game timeline pre-flight.
-- (B) n = 2 ON THE FIRE SET, and both frames come from the same day's games.
-- (C) THE ENGINE-SIDE VALUE OF GetAOERadius IS UNKNOWN HERE.  Freezing Field's
--     KV carries `radius` = 810 and no AbilityAOERadius key; whether the engine
--     derives the getter from it cannot be read offline.  Section 7 registers
--     that the sister file tests/test_replay_260820_cm_r_selfstate.lua asserts
--     a different external anchor (835) for the same quantity, and pins that
--     the two answers give the SAME fire set rather than silently preferring
--     one.  Both numbers are outside the dump either way.
-- (D) THE FIRE SET IS CONDITIONAL ON A METER THIS FILE SUPPLIES ITSELF.  No
--     claim here says the shipped bot fires on those frames in game; it says
--     the shipped CODE bids HIGH when the radius is not zero.
-- (E) ZERO BEHAVIOUR CHANGE.  No gate, no new candidate id, no bots/ edit
--     beyond a comment that records section 6 next to the id it is about.
--
-- The archive holds exactly one CM instant that is a Freezing Field CAST
-- instant (ultimate at its full 100s cooldown): f_260819_123012_dp_landed_dead
-- t=574.4.  Only branch 3 can explain it -- one enemy inside the radius, not
-- three -- and on that frame Q and W are unavailable because of COOLDOWN
-- (10.4s and 5.8s), exactly as section 3 says they must be.  Section 8 pins it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local UNIT      = 'npc_dota_hero_crystal_maiden'
local NOVA      = 'crystal_maiden_crystal_nova'
local FROSTBITE = 'crystal_maiden_frostbite'
local FIELD     = 'crystal_maiden_freezing_field'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

-- KV snapshot (tests/mock/special_value_shapes.lua) radius for Freezing Field,
-- and the anchor the sister gate test uses.  Section 7 holds them against each
-- other; nothing here prefers one.
local KV_RADIUS     = 810
local SISTER_ANCHOR = 835

local MARGIN0_FRAME = 'tests/fixtures/f_260819_004858_cm_centaur_far.lua'
local FIRE_A        = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'
local FIRE_B        = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua'
local CAST_FRAME    = 'tests/fixtures/f_260819_123012_dp_landed_dead.lua'

-- ---------------------------------------------------------------- enumeration

--- Every corpus file from BOTH directories, never a hardcoded list: a third
--- directory has to cost an edit here rather than a silent undercount (the
--- failure a sister sweep shipped on 2026-08-31 and stayed green through).
local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame. '
            .. 'An empty enumerator and an empty corpus are the same integer; '
            .. 'this assertion is what tells them apart.')
    end
    table.sort(out)
    return out
end

--- Is Crystal Maiden alive on this frame?  Returns her raw dump record.
local function cm_record(path)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return nil end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == UNIT and u.alive ~= false then return u, chunk end
    end
    return nil
end

--- Load one frame with CM as the bot, optionally supplying the ultimate's AoE
--- radius the mock does not carry, and optionally arming soak candidate ids.
local function load_cm(path, nRadius, tIds)
    local J, bot = rf.load(path, UNIT)
    if tIds ~= nil then
        J.IsSoakCandidate = function(id)
            for _, s in ipairs(tIds) do if s == id then return true end end
            return false
        end
    end
    if nRadius ~= nil then
        local h = bot:GetAbilityByName(FIELD)
        assert(h ~= nil, 'the ultimate handle exists on ' .. path)
        rawget(h, '__spec').GetAOERadius = nRadius
    end
    return J, bot
end

--- The shipped bid, driven the way the game drives it: SkillsComplement fills
--- this file's upvalues (hEnemyList, nHP, ...) BEFORE any Consider runs, and
--- calling a Consider without it is what crashed the Lion sweep on 2026-09-01.
local function bid_R(path, nRadius, tIds)
    local J, bot = load_cm(path, nRadius, tIds)
    local X = rf.load_hero('crystal_maiden')
    pcall(function() X.SkillsComplement() end)
    local ok, nDesire = pcall(function() return (X.ConsiderR()) end)
    assert(ok, 'X.ConsiderR raised on ' .. path .. ': ' .. tostring(nDesire))
    return nDesire, J, bot, X
end

-- ------------------------------------------------------------------ the sweep

--- The castable funnel of section 1, per ability and in total.
local function funnel()
    local t = {
        files = 0, instants = 0, handles = 0, trained = 0, pre = 0, post = 0,
        revoked_by_name = {}, margins = {}, nonzero_price = 0, priced = {},
    }
    for _, path in ipairs(corpus_paths()) do
        t.files = t.files + 1
        local u = cm_record(path)
        if u ~= nil then
            t.instants = t.instants + 1
            local _, bot = rf.load(path, UNIT)
            local mp = bot:GetMana() or 0
            for _, a in ipairs(u.abilities or {}) do
                local h = bot:GetAbilityByName(a.name)
                if h ~= nil then
                    t.handles = t.handles + 1
                    local rank = h:GetLevel() or 0
                    local cd   = h:GetCooldownTimeRemaining() or 0
                    local cost = h:GetManaCost() or 0
                    if cost > 0 then t.nonzero_price = t.nonzero_price + 1 end
                    if rank > 0 then t.trained = t.trained + 1 end
                    local pre = rank > 0 and cd <= 0
                    if pre then
                        t.pre = t.pre + 1
                        t.priced[#t.priced + 1] = { path = path, name = a.name,
                            rank = rank, cost = cost, mp = mp, margin = mp - cost }
                        if mp >= cost then
                            t.post = t.post + 1
                        else
                            t.revoked_by_name[a.name] = (t.revoked_by_name[a.name] or 0) + 1
                            t.margins[#t.margins + 1] = mp - cost
                        end
                    end
                end
            end
        end
    end
    return t
end

local tests = {}

-- ===========================================================================
tests['1. the castable funnel over the whole archive, buckets exhaustive'] = function()
    local t = funnel()

    -- GUARD FIRST.  Every count below is derived from GetManaCost, and the
    -- world where that getter fell back to 0 produces a perfectly green
    -- "nothing was revoked".  Refuse to report the funnel until the meter is
    -- demonstrably charging somebody.
    assert(t.nonzero_price > 0,
        'not one ability handle answered a non-zero mana price -- the meter has '
        .. 'regressed to the pre-2026-09-01 world and every number in this file '
        .. 'would be an artifact of that, not a reading')

    assert(t.instants == 48, 'live-CM instants: expected 48, got ' .. t.instants)
    assert(t.handles == 209, 'CM ability handles: expected 209, got ' .. t.handles)
    assert(t.trained == 195, 'trained handles: expected 195, got ' .. t.trained)
    assert(t.pre  == 157, 'castable before the price: expected 157, got ' .. t.pre)
    assert(t.post == 141, 'castable after the price: expected 141, got ' .. t.post)

    local revoked = t.pre - t.post
    assert(revoked == 16, 'revocations: expected 16, got ' .. revoked)
    assert(t.revoked_by_name[NOVA] == 7, 'Crystal Nova revocations: expected 7')
    assert(t.revoked_by_name[FROSTBITE] == 4, 'Frostbite revocations: expected 4')
    assert(t.revoked_by_name[FIELD] == 5, 'Freezing Field revocations: expected 5')
    local sum = 0
    for _, n in pairs(t.revoked_by_name) do sum = sum + n end
    assert(sum == revoked,
        'the per-ability buckets must re-sum to the total, or a dropped record '
        .. 'reads as a smaller domain: ' .. sum .. ' vs ' .. revoked)
end

-- ===========================================================================
tests['2. the -1 readings are determinate; the only undecidable one is at 0'] = function()
    local t = funnel()

    local nAtMinusOne, nWorseThanMinusOne = 0, 0
    for _, m in ipairs(t.margins) do
        if m == -1 then nAtMinusOne = nAtMinusOne + 1
        else
            nWorseThanMinusOne = nWorseThanMinusOne + 1
            assert(m < -1, 'a revocation must have a negative margin, got ' .. m)
        end
    end
    assert(nAtMinusOne == 3, 'three revocations miss by exactly 1 mana, got ' .. nAtMinusOne)
    assert(nWorseThanMinusOne == 13, 'the other 13 miss by more')

    -- The dumper writes int32(mana + 0.5), so a recorded v means the true value
    -- was in [v - 0.5, v + 0.5).  At margin -1 the whole interval is below the
    -- price: no rounding rule makes those three castable.
    for _, m in ipairs(t.margins) do
        assert(m + 0.5 < 0, 'margin ' .. m .. ' would be decidable only if the '
            .. "dump's half-unit rounding could not reach the price")
    end

    -- The undecidable reading is on the other side of the boundary: exactly one
    -- KEEP sits at margin 0, where half the rounding interval is below cost.
    local nZero, sZeroFrame, sZeroAbility = 0, nil, nil
    for _, r in ipairs(t.priced) do
        if r.margin == 0 then
            nZero = nZero + 1
            sZeroFrame, sZeroAbility = r.path, r.name
        end
    end
    assert(nZero == 1, 'expected exactly one margin-0 reading, got ' .. nZero)
    assert(sZeroFrame == MARGIN0_FRAME, 'margin-0 frame moved: ' .. tostring(sZeroFrame))
    assert(sZeroAbility == FIELD, 'margin-0 ability moved: ' .. tostring(sZeroAbility))
end

-- ===========================================================================
tests['3. mana can never decide the two NEGATED castable sites -- closed form'] = function()
    local src = assert(io.open('bots/BotLib/hero_crystal_maiden.lua')):read('*a')
    assert(src:find('and not abilityQ:IsFullyCastable()\n'
        .. '\t\t\tand not abilityW:IsFullyCastable()', 1, true),
        'the negated pair in X.ConsiderR is what this section is about; if it '
        .. 'moved, re-derive the arithmetic instead of deleting this case')

    -- Ladders from the KV snapshot, read rather than transcribed.
    local shapes = require('mock.special_value_shapes')
    local function ladder(name)
        local entry = shapes.SHAPES['crystal_maiden'][name]
        assert(entry ~= nil, 'no snapshot entry for ' .. name)
        local base = entry['AbilityManaCost'] and entry['AbilityManaCost'].base
        assert(base ~= nil, name .. ' carries no AbilityManaCost ladder')
        local out = {}
        for s in base:gmatch('%S+') do out[#out + 1] = tonumber(s) end
        return out
    end
    local function minmax(t)
        local lo, hi = t[1], t[1]
        for _, v in ipairs(t) do
            if v < lo then lo = v end
            if v > hi then hi = v end
        end
        return lo, hi
    end
    local rLo = (minmax(ladder(FIELD)))
    local _, qHi = minmax(ladder(NOVA))
    local _, wHi = minmax(ladder(FROSTBITE))

    assert(rLo > qHi and rLo > wHi,
        'the closed form is exactly this separation: reaching the negated pair '
        .. 'requires mp >= cost(R) >= ' .. rLo .. ', which already exceeds the '
        .. 'dearest Crystal Nova (' .. qHi .. ') and Frostbite (' .. wHi .. '). '
        .. 'If a patch narrows it, the mana term becomes live there and the '
        .. 'suppression direction has to be re-measured')
end

-- ===========================================================================
tests['4. the 240 zero desires come with the five constants that cause them'] = function()
    local nInstants, nZeroBids = 0, 0
    local nMode, nGoing, nRetreat, nAoE, nRadius0 = 0, 0, 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if cm_record(path) ~= nil then
            nInstants = nInstants + 1
            local J, bot = load_cm(path)
            local X = rf.load_hero('crystal_maiden')
            pcall(function() X.SkillsComplement() end)
            for _, fn in ipairs({ 'ConsiderQ', 'ConsiderW', 'ConsiderR',
                                  'ConsiderArcaneAura', 'ConsiderCrystalClone' }) do
                local ok, d = pcall(function() return (X[fn]()) end)
                assert(ok, fn .. ' raised on ' .. path .. ': ' .. tostring(d))
                if d == 0 then nZeroBids = nZeroBids + 1 end
            end
            if (bot:GetActiveMode() or 0) == 0 then nMode = nMode + 1 end
            if not J.IsGoingOnSomeone(bot) then nGoing = nGoing + 1 end
            if not J.IsRetreating(bot) then nRetreat = nRetreat + 1 end
            local aoe = bot:FindAoELocation(true, true, bot:GetLocation(), 700, 400, 0.8, 0)
            if aoe == nil or (aoe.count or 0) == 0 then nAoE = nAoE + 1 end
            local h = bot:GetAbilityByName(FIELD)
            if h ~= nil and (h:GetAOERadius() or 0) == 0 then nRadius0 = nRadius0 + 1 end
        end
    end
    assert(nInstants == 48, 'instants moved: ' .. nInstants)
    assert(nZeroBids == 240, 'expected all 5 x 48 bids to be zero, got ' .. nZeroBids)
    -- ... and here is why that is not a null result.
    assert(nMode == 48, 'GetActiveMode is the mock default on every instant')
    assert(nGoing == 48, 'J.IsGoingOnSomeone is false on every instant')
    assert(nRetreat == 48, 'J.IsRetreating is false on every instant')
    assert(nAoE == 48, 'FindAoELocation is the count=0 loader stand-in everywhere')
    assert(nRadius0 == 48, 'GetAOERadius answers 0 on every instant (section 5)')
end

-- ===========================================================================
tests['5. GetAOERadius is unspecced tree-wide, and supplying it fires 2 frames'] = function()
    -- The zero is a property of the loader, not of this hero: the spec builder
    -- never mentions the getter, so it lands on bot_api's generic `^Get`.
    local loader = assert(io.open('tests/mock/replay_fixture.lua')):read('*a')
    assert(loader:find('GetAOERadius') == nil,
        'tests/mock/replay_fixture.lua now specs GetAOERadius. That is a repair, '
        .. 'not a failure -- but every count in sections 4 and 5 was taken with '
        .. 'the getter answering 0, so re-measure them before editing this case')

    -- Seven CALL sites under bots/ read it; one of them is the ultimate radius
    -- this section is about.  Comment lines are excluded on purpose: a bare
    -- `grep -c` counts prose, and this very file's addendum in
    -- hero_crystal_maiden.lua moved that count from 7 to 9 by writing SENTENCES
    -- about the getter (the same trap that inflated the
    -- GetActualIncomingDamage census from 40 lines to "43").
    local p = assert(io.popen("grep -rn 'GetAOERadius' bots/ 2>/dev/null"))
    local nCalls, nProse = 0, 0
    for line in p:lines() do
        local code = line:gsub('^[^:]*:%d+:', '')
        if code:match('^%s*%-%-') then nProse = nProse + 1 else nCalls = nCalls + 1 end
    end
    p:close()
    assert(nCalls == 7, 'GetAOERadius call sites under bots/: expected 7, got '
        .. nCalls .. ' -- the blast radius of the zero moved')
    assert(nProse > 0, 'the prose/code split must stay exercised: with no comment '
        .. 'line mentioning the getter, this filter is untested and the next '
        .. 'sentence somebody writes silently becomes a call site again')

    -- Supplying the radius, the real ConsiderR bids HIGH on exactly two frames.
    local fired = {}
    for _, path in ipairs(corpus_paths()) do
        if cm_record(path) ~= nil then
            local shipped = bid_R(path, nil, {})
            local supplied = bid_R(path, KV_RADIUS, {})
            assert(shipped == BOT_ACTION_DESIRE_NONE,
                'with the meter zero every bid is NONE, including ' .. path)
            if supplied ~= BOT_ACTION_DESIRE_NONE then
                fired[#fired + 1] = path
                assert(supplied == BOT_ACTION_DESIRE_HIGH,
                    'the fire branches bid HIGH or nothing; got ' .. tostring(supplied))
            end
        end
    end
    table.sort(fired)
    assert(#fired == 2, 'expected 2 frames to fire, got ' .. #fired)
    assert(fired[1] == FIRE_A and fired[2] == FIRE_B,
        'the fire set moved: ' .. table.concat(fired, ', '))

    -- Both are a lone support about to die, which is the whole point.
    for _, path in ipairs(fired) do
        local u, chunk = cm_record(path)
        assert(u.hp / u.max_hp < 0.38,
            path .. ': the subject is below the cmrself floor (' ..
            string.format('%.3f', u.hp / u.max_hp) .. ')')
        assert(chunk.observed ~= nil and chunk.observed.died_after ~= nil
            and chunk.observed.died_after <= 1.0,
            path .. ': ground truth says she dies within a second of the frame')
    end
end

-- ===========================================================================
tests['6. `cmrself` armed vetoes both, and its domain is disjoint from branch 3'] = function()
    for _, path in ipairs({ FIRE_A, FIRE_B }) do
        assert(bid_R(path, KV_RADIUS, {}) == BOT_ACTION_DESIRE_HIGH,
            path .. ': shipped bids HIGH once the radius is supplied')
        assert(bid_R(path, KV_RADIUS, { 'cmrself' }) == BOT_ACTION_DESIRE_NONE,
            path .. ": arming 'cmrself' withholds the channel")
    end

    -- The closed form: the veto fires strictly below the floor, branch 3 needs
    -- strictly above the same constant, so no branch-3 bid can ever be the one
    -- the id changes.  Read both constants out of the source rather than
    -- restating them here.
    local src = assert(io.open('bots/BotLib/hero_crystal_maiden.lua')):read('*a')
    local sFloor = src:match('X%.nRSelfHpFloor%s*=%s*([%d%.]+)')
    assert(sFloor ~= nil, 'X.nRSelfHpFloor is still declared')
    assert(src:find('and J.GetHP( hBot ) < X.nRSelfHpFloor', 1, true),
        'the veto compares BELOW the floor')
    assert(src:find('if J.IsRetreating( bot ) and nHP > ' .. sFloor, 1, true),
        "branch 3 must keep guarding on the SAME constant (" .. sFloor .. "); if "
        .. 'the two ever differ, cmrself stops being disjoint from branch 3 and '
        .. 'section 6 has to be re-derived')
end

-- ===========================================================================
tests['7. the two external radius anchors disagree, and give the same fire set'] = function()
    local shapes = require('mock.special_value_shapes')
    local entry = shapes.SHAPES['crystal_maiden'][FIELD]
    assert(entry['AbilityAOERadius'] == nil,
        "Freezing Field's KV carries no AbilityAOERadius key -- that absence is "
        .. 'why the engine-side value of the getter is an open question here')
    assert(tonumber(entry['radius'].base) == KV_RADIUS,
        'the KV snapshot radius moved from ' .. KV_RADIUS)

    local sister = assert(io.open('tests/test_replay_260820_cm_r_selfstate.lua')):read('*a')
    local nAnchor = tonumber(sister:match('local FIELD_RADIUS%s*=%s*(%d+)'))
    assert(nAnchor == SISTER_ANCHOR,
        'the sister file external anchor moved from ' .. SISTER_ANCHOR
        .. ' to ' .. tostring(nAnchor))
    assert(nAnchor ~= KV_RADIUS,
        'the two sources still disagree; the day they agree, delete this case '
        .. 'rather than leaving a reconciliation nobody needs')

    -- Neither number is in the dump, so the honest thing is to show the reading
    -- does not depend on which one is right.
    for _, path in ipairs({ FIRE_A, FIRE_B }) do
        assert(bid_R(path, KV_RADIUS, {}) == bid_R(path, SISTER_ANCHOR, {}),
            path .. ': the fire verdict differs between the two anchors, so the '
            .. 'reconciliation is load bearing after all')
    end
end

-- ===========================================================================
tests['8. the archive holds one CAST instant, and only branch 3 explains it'] = function()
    local u = cm_record(CAST_FRAME)
    assert(u ~= nil, CAST_FRAME .. ' still holds a live CM')

    local function ability(name)
        for _, a in ipairs(u.abilities or {}) do
            if a.name == name then return a end
        end
        return nil
    end
    local r = ability(FIELD)
    assert(r ~= nil and r.level == 1, 'Freezing Field is rank 1 on this frame')
    -- Rank-1 cooldown is 100 in the KV snapshot; the reading is at the top of it,
    -- so the cast is within one dump sample of this instant.
    local shapes = require('mock.special_value_shapes')
    local nCd = tonumber(shapes.SHAPES['crystal_maiden'][FIELD]['AbilityCooldown']
        .base:match('^(%S+)'))
    assert(r.cd == nCd,
        'the ultimate is at its full rank-1 cooldown (' .. nCd .. '), which is '
        .. 'what makes this a cast instant rather than a frame after one')

    -- Only one enemy is inside the field, so branches 1 and 2 cannot be the
    -- explanation whichever radius anchor is used.
    local nInside = 0
    for _, e in ipairs(select(2, cm_record(CAST_FRAME)).units or {}) do
        if e.team ~= u.team and e.alive ~= false then
            local d = math.sqrt((e.x - u.x) ^ 2 + (e.y - u.y) ^ 2)
            if d <= SISTER_ANCHOR * 0.88 then nInside = nInside + 1 end
        end
    end
    assert(nInside == 1,
        'exactly one enemy inside 0.88*radius on the cast frame, got ' .. nInside)

    -- And the two abilities branch 3 requires to be unavailable are unavailable
    -- for the reason section 3 proves they always are: cooldown.
    local q, w = ability(NOVA), ability(FROSTBITE)
    assert(q.cd > 0 and w.cd > 0,
        'both basics are on cooldown on the cast frame (' .. q.cd .. 's, ' .. w.cd .. 's)')
    -- And her remaining mana corroborates the cooldown reading rather than
    -- repeating it: 192 is BELOW the 200 she had to hold a moment earlier, so
    -- the price has already been taken off the pool on this frame.
    local nCost = tonumber(shapes.SHAPES['crystal_maiden'][FIELD]['AbilityManaCost']
        .base:match('^(%S+)'))
    assert(u.mp < nCost,
        'the ultimate price (' .. nCost .. ') has already left her pool on the '
        .. 'cast frame; she holds ' .. u.mp)
end

-- ---------------------------------------------------------------------------
-- [director 2026-09-01, GH #387] This file used to end with a PRIVATE copy of
-- the runner (its own loop, its own `ok`/`FAIL` lines, its own `os.exit(1)`)
-- and never returned `tests`.  It was the only one of 277 test files that did.
--
-- It passed standalone -- `8 run, 0 failed` -- and that is exactly why it was
-- expensive: under the supported entry point the chunk returns nil, and
-- run_tests.lua reached `pairs(nil)` OUTSIDE any pcall, so the file did not
-- fail, the RUNNER died.  It sorts 48th of 277, so from `afd8fbf8` (this
-- morning, already on origin/main) iron rule 6's dynamic half stopped after 48
-- files and ~229 files (83%) went unrun on every stream, every trigger.
-- Reported by the batch desk 12:18Z.
--
-- The private harness was also the more dangerous half of the deviation: its
-- `os.exit(1)` would have killed the runner mid-suite on a RED file, taking the
-- summary and every later file with it.  The contract is one line; the runner
-- prints, counts, sorts and reports for all 277.
return tests

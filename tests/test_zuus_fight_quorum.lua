-- [hero] `zusfightquorum` -- the TEAM-FIGHT branch of Zeus's X.ConsiderR asks for
-- a quorum of enemy heroes that is the CEILING of the quantity it thresholds,
-- not a point inside its range.  Written 2026-09-06 under OWNER_PRIORITIES P4.4
-- (bots/ 主体配额).  It is the candidate the previous round
-- (tests/test_zuus_ult_strand.lua, GH #564) registered-without-claiming: that
-- round said in as many words that it had NOT checked whether this conjunct was
-- reachable.  This round checked.
--
-- THE DEFECT
-- ----------
-- bots/BotLib/hero_zuus.lua, X.ConsiderR:
--
--     if J.IsInTeamFight( bot, 1400 ) then
--         local tableNearbyEnemyHeroes = J.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE )
--         local nInvUnit = J.GetInvUnitCount( false, tableNearbyEnemyHeroes )
--         if nInvUnit >= 5 then
--
-- A Dota side holds five heroes, so `>= 5` is not a threshold inside the range
-- of that count -- it IS the range's upper end, and it demands the WHOLE enemy
-- team at once.  Both filters in front of it can only subtract: J.GetNearbyHeroes
-- drops everything dead or unseen, and J.GetInvUnitCount keeps only what passes
-- J.CanCastOnNonMagicImmune (visible, not magic immune, not invulnerable, no
-- suspicious-illusion or forbidden modifier).  One enemy dead, one in fog, one
-- holding a BKB, or one standing 1401u away is enough.
--
-- ⭐ THE PREMISE IS A MEASUREMENT AND IT CAN FAIL.  Section 2 does not argue from
-- how Dota is usually played.  It re-runs the shipped expression at EVERY alive
-- hero of EVERY fixture -- 1012 vantage points, tests/_zusfightquorum_sweep.lua
-- -- and asserts the maximum observed count is strictly below the shipped
-- quorum.  It reads 4.  A corpus that ever produced a genuine five-stack inside
-- one 1400 circle would turn this file red, and that is the point: "5 is an
-- off-switch, 3 is a filter" is a reading, not a conviction.  The same rows
-- price the narrowness of the armed side (16 of 1012 = 1.6%), which is the only
-- thing standing between this widening and a blank cheque.
--
-- ⭐⭐ THE VANTAGE POINT IS THE OTHER HALF OF THE DEFECT AND THIS ROUND DOES NOT
-- FIX IT.  Thundergod's Wrath is GLOBAL -- the ability declares no
-- AbilityCastRange key at all -- so measuring the fight from the CASTER's
-- position measures it from the one position a backline mage should never be
-- in.  Section 6 pins the bias off the corpus instead of asserting it in prose:
-- in f_260819_222052_zuus_w2_leak two of Zeus's own enemies each count FOUR
-- enemies inside 1400 while Zeus, in the very same frame, counts two.
-- Repointing the count at the fight rather than at Zeus is a second lever with
-- its own id; one lever at a time, and this one is the quorum.
--
-- WHAT THIS FILE COVERS AND WHAT IT DOES NOT -- READ BEFORE QUOTING IT
-- -------------------------------------------------------------------
--   * ⚠️ DIRECTION IS A WIDENING, NOT A NARROWING.  Armed lowers a quorum, so it
--     can only ADD casts on this branch and can never remove one.  A negative
--     wave reading on this id may NOT be read as "fewer ultimates"; the only
--     thing it can mean is that the added casts were bad ones.  Section 5 pins
--     the direction as an assertion.
--   * WHAT IS READ OFF REAL FRAMES: the count itself, at 1012 vantage points,
--     which is hero POSITIONS, TEAMS, ALIVE flags and per-team VISIBILITY -- all
--     of it dumped frame data (tests/mock/replay_fixture.lua restores
--     GetNearbyHeroes from the roster and is vision-limited like the engine).
--   * ⚠️ MOST OF THOSE VANTAGE POINTS ARE NOT ZEUS, AND THE TWO SENTENCES MAY
--     NOT BE MERGED.  A non-subject vantage point is real geometry read from
--     another hero's feet; it is NOT a creation frame for this branch.  It
--     licenses the claim about the RANGE of the count and nothing else.
--   * ⚠️ NO ZEUS-SUBJECT FRAME REACHES EVEN THE ARMED QUORUM (the ten of them
--     top out at 2), so "the armed branch fires in a real Zeus game" is NOT a
--     reading this round bought.  Section 6 states it as the one-way tripwire it
--     is -- red there is GOOD NEWS.  Sizing the branch's real frequency is a
--     corpus question for iterations/queue.json, never this scan.
--   * ⚠️ J.IsInTeamFight IS NOT UNDER TEST HERE.  It is the other half of the
--     shipped condition and it reads ALLY BOT MODES, which a .dem slice does not
--     carry.  Section 1 asserts only that the call site hands it the same radius
--     the count uses, so the two halves cannot drift apart.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC = 'bots/BotLib/hero_zuus.lua'
local CAND = 'zusfightquorum'

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
    'tests/fixtures/f_260820_042607_zuus_reserve_cross.lua',
    'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua',
}

-- A frame whose whole enemy side is alive and passes J.CanCastOnNonMagicImmune,
-- so an injected list of k of them counts exactly k.  Verified by section 4's
-- own roster assertion rather than trusted.
local FIVE_ENEMY_FRAME = 'tests/fixtures/f_230952_zuus_ult_hoard.lua'

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

--- Load one real frame and arm (or do not arm) `zusfightquorum`.
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

--- LABELLED INJECTION.  Replace the subject's GetNearbyHeroes with one that
--- hands back the first k of its own roster enemies whatever the radius.  The
--- HANDLES are real and so are every predicate J.GetInvUnitCount runs on them;
--- what is injected is GEOMETRY ONLY -- who counts as "nearby" -- which is
--- exactly the term under test.  No fixture places five enemies in one circle
--- (that is section 2's reading), so this is the only way to exercise the
--- shipped quorum at all, and calling it anything other than an injection would
--- be the merge this file's header forbids.
local function inject_nearby_enemies(bot, heroes, fx, k)
    local roster = {}
    for _, u in ipairs(fx.units) do
        local h = heroes[u.name]
        if u.alive and h ~= nil and h:GetTeam() ~= bot:GetTeam() then
            roster[#roster + 1] = h
        end
    end
    assert(#roster >= k, string.format(
        'the frame carries only %d alive enemy heroes; %d were asked for.', #roster, k))
    local list = {}
    for i = 1, k do list[i] = roster[i] end
    bot.GetNearbyHeroes = function(_, _, bEnemies, _)
        if bEnemies then return list end
        return {}
    end
    return list
end

-- ------------------------------------------------------------- corpus sweep --
-- Run once, as a subprocess (backlog rule 0q: corpus-wide dofile loops stay off
-- run_tests.lua's long-lived heap).

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_zusfightquorum_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line). Nothing below '
        .. 'is a reading until it does.')
    local c, hist, vp, zsubj, radius = {}, {}, {}, {}, nil
    for line in text:gmatch('[^\n]+') do
        local r = line:match('^RADIUS (%d+)$')
        if r then radius = tonumber(r) end
        local hk, hv = line:match('^HIST (%d+) (%d+)$')
        if hk then hist[tonumber(hk)] = tonumber(hv) end
        local vf, vu, vn, vs = line:match('^VP (%S+) (%S+) (%d+) (%d)$')
        if vf then
            vp[#vp + 1] = { fix = vf, unit = vu, n = tonumber(vn), subject = vs == '1' }
        end
        local zf, zn = line:match('^ZSUBJ (%S+) (%d+)$')
        if zf then zsubj[#zsubj + 1] = { fix = zf, n = tonumber(zn) } end
        local ck, cv = line:match('^C ([%w_]+) (%-?%d+)$')
        if ck then c[ck] = tonumber(cv) end
    end
    return c, hist, vp, zsubj, radius
end

local C, HIST, VP, ZSUBJ, SWEEP_RADIUS = sweep()

--- How many of the swept vantage points a quorum of `n` would admit.
local function admitted(n)
    local total = 0
    for k, v in pairs(HIST) do
        if k >= n then total = total + v end
    end
    return total
end

-- ---------------------------------------------------------------- section 1 --
-- The call site is wired.  These going red mean "re-read the file", never "the
-- test is stale": an unwired gate measures nothing, and check_armed_wiring.py
-- would still call it WIRED because a call site exists somewhere.

tests['section 1: ConsiderR no longer holds the inline quorum comparison'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('GetInvUnitCount') == nil,
        'X.ConsiderR still holds the bare J.GetInvUnitCount quorum inline -- the call '
        .. 'site was not wired, so the gate is dead and every reading taken through it '
        .. 'measures nothing.')
    assert(body:find('X%.zuus_ShouldUltForTeamFight%s*%(%s*bot%s*%)') ~= nil,
        'X.ConsiderR no longer calls X.zuus_ShouldUltForTeamFight( bot ).')
end

tests['section 1: both halves of the condition share one radius constant'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'ConsiderR'))
    assert(body:find('J%.IsInTeamFight%s*%(%s*bot%s*,%s*X%.nUltFightRadius%s*%)') ~= nil,
        'X.ConsiderR no longer hands X.nUltFightRadius to J.IsInTeamFight. The fight '
        .. 'test and the head count must measure the same circle; a literal in one of '
        .. 'them lets the two halves drift apart silently.')
end

tests['section 1: the helper still contains the shipped quorum verbatim'] = function()
    local body = strip_comments(fn_body(read_file(SRC), 'zuus_ShouldUltForTeamFight'))
    assert(body:find('nInvUnit%s*>=%s*X%.nUltFightQuorumShipped') ~= nil,
        'the shipped quorum comparison is gone from the helper. Gate-off equivalence '
        .. 'is structural only while the shipped expression is evaluated FIRST and '
        .. 'returned unchanged.')
    assert(body:find("J%.IsModeTurbo%s*%(%s*%)%s*and%s*J%.IsSoakCandidate%s*%(%s*'" .. CAND .. "'%s*%)") ~= nil,
        'the helper no longer gates on turbo AND the ' .. CAND .. ' soak id.')
end

-- ---------------------------------------------------------------- section 2 --
-- THE PREMISE, measured.  Everything else in the round follows from "5 is the
-- ceiling of this count, not a point inside its range".

tests['section 2: the sweep measured the radius the hero file actually ships'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    assert(SWEEP_RADIUS == X.nUltFightRadius, string.format(
        'the corpus sweep counted inside %s units while the hero file ships %s. The '
        .. 'sweep reads the constant instead of re-typing it precisely so this cannot '
        .. 'happen; a mismatch means the census measured a world the bot is not in.',
        tostring(SWEEP_RADIUS), tostring(X.nUltFightRadius)))
end

tests['section 2: the shipped quorum is the ceiling of its own quantity'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    assert(C.teamcap ~= nil and C.teamcap > 0, 'the sweep reported no team size at all')
    assert(X.nUltFightQuorumShipped == C.teamcap, string.format(
        'the shipped quorum is %s but the largest side in the corpus holds %s heroes. '
        .. 'This lever is diagnosed as "the threshold IS the ceiling of the count"; if '
        .. 'the two numbers differ, that diagnosis is not the ceiling of its own '
        .. 'quantity any more and the whole round needs re-arguing.',
        tostring(X.nUltFightQuorumShipped), tostring(C.teamcap)))
end

tests['section 2: no real-frame vantage point reaches the shipped quorum'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    assert(C.vantage_points ~= nil and C.vantage_points >= 900, string.format(
        'the sweep only reached %s vantage points; the range claim is worth as many '
        .. 'vantage points as it is paid for.', tostring(C.vantage_points)))
    assert(C.max < X.nUltFightQuorumShipped, string.format(
        'a vantage point counted %d enemy heroes inside the fight radius and the '
        .. 'shipped quorum is %d, so the shipped quorum is no longer out of range. '
        .. 'GOOD NEWS if the corpus grew a real five-stack -- take the reading and '
        .. 'retire the "off-switch" sentence in bots/BotLib/hero_zuus.lua.',
        C.max, X.nUltFightQuorumShipped))
    assert(admitted(X.nUltFightQuorumShipped) == 0, string.format(
        'the shipped quorum admits %d vantage points; the header calls it an '
        .. 'off-switch.', admitted(X.nUltFightQuorumShipped)))
end

tests['section 2: the armed quorum is a filter -- it admits some, and few'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    local nAdmit = admitted(X.nUltFightQuorumArmed)
    assert(nAdmit > 0, string.format(
        'the armed quorum %d admits 0 vantage points out of %d. That is a second '
        .. 'off-switch, not a narrowing, and the lever would be inert in every wave '
        .. 'while still reading as WIRED.', X.nUltFightQuorumArmed, C.vantage_points))
    local share = nAdmit / C.vantage_points
    assert(share < 0.05, string.format(
        'the armed quorum %d admits %d of %d vantage points (%.1f%%). This lever is a '
        .. 'WIDENING and the quorum is the only thing keeping it narrow; above a few '
        .. 'percent it is a blank cheque that fires a 130s-cooldown global nuke in '
        .. 'every skirmish.', X.nUltFightQuorumArmed, nAdmit, C.vantage_points,
        share * 100))
    assert(X.nUltFightQuorumArmed < X.nUltFightQuorumShipped, string.format(
        'the armed quorum %d is not below the shipped quorum %d, so arming changes '
        .. 'nothing.', X.nUltFightQuorumArmed, X.nUltFightQuorumShipped))
end

-- ---------------------------------------------------------------- section 3 --
-- Real frames, gate off.

tests['section 3: the shipped quorum is false on every real Zeus frame'] = function()
    for _, path in ipairs(ZUUS_FRAMES) do
        local X, _, bot = on_frame(path)
        assert(X.zuus_ShouldUltForTeamFight(bot) == false, string.format(
            '%s: the UNARMED helper answered true. The header claims no Zeus frame in '
            .. 'the corpus reaches the shipped quorum; a frame that does retires the '
            .. 'claim.', path))
    end
end

-- ---------------------------------------------------------------- section 4 --
-- The comparison is LIVE.  Without this, section 3's falses could equally be
-- produced by a helper that ignores its inputs -- exactly the "an assertion that
-- cannot fail is not evidence" trap GH #560 wrote down, and the shape a quorum
-- that can never be met shares with a quorum that is never read.

tests['section 4: an injected full enemy team flips the shipped quorum'] = function()
    local X, J, bot, heroes, fx = on_frame(FIVE_ENEMY_FRAME)
    local list = inject_nearby_enemies(bot, heroes, fx, X.nUltFightQuorumShipped)
    assert(J.GetInvUnitCount(false, list) == X.nUltFightQuorumShipped, string.format(
        '%s: the injected roster does not survive J.CanCastOnNonMagicImmune intact, so '
        .. 'this injection controls fewer heads than it names and the assertion below '
        .. 'would pass or fail for the wrong reason.', FIVE_ENEMY_FRAME))
    assert(X.zuus_ShouldUltForTeamFight(bot) == true, string.format(
        'a fight of %d injected enemy heroes did NOT reach the shipped quorum. The '
        .. 'comparison is not live, so every false this file records is a vacuity.',
        X.nUltFightQuorumShipped))
end

tests['section 4: one head short of the quorum is still false, gate off'] = function()
    local X, _, bot, heroes, fx = on_frame(FIVE_ENEMY_FRAME)
    inject_nearby_enemies(bot, heroes, fx, X.nUltFightQuorumShipped - 1)
    assert(X.zuus_ShouldUltForTeamFight(bot) == false, string.format(
        'gate off, a fight of %d enemy heroes cleared a quorum of %d. The comparison '
        .. 'is not the one the header describes.',
        X.nUltFightQuorumShipped - 1, X.nUltFightQuorumShipped))
end

-- ---------------------------------------------------------------- section 5 --
-- Gate-off equivalence, direction, and what the armed quorum actually admits.

tests['section 5: gate-off returns the shipped answer, head count for head count'] = function()
    local Xc = on_frame(FIVE_ENEMY_FRAME)
    local nCeil = Xc.nUltFightQuorumShipped
    for k = 0, nCeil do
        for _, nonTurbo in ipairs({ false, true }) do
            local X, _, bot, heroes, fx = on_frame(FIVE_ENEMY_FRAME,
                { armed = false, nonTurbo = nonTurbo })
            inject_nearby_enemies(bot, heroes, fx, k)
            local got = X.zuus_ShouldUltForTeamFight(bot)
            local want = k >= X.nUltFightQuorumShipped
            assert(got == want, string.format(
                'gate-off answered %s at %d enemy heroes (nonTurbo=%s); the shipped '
                .. 'quorum says %s. Gate-off must be the shipped tree head count for '
                .. 'head count.', tostring(got), k, tostring(nonTurbo), tostring(want)))
        end
    end
end

tests['section 5: armed answers the ARMED quorum, not the shipped one'] = function()
    local Xc = on_frame(FIVE_ENEMY_FRAME)
    local nCeil = Xc.nUltFightQuorumShipped
    for k = 0, nCeil do
        local X, _, bot, heroes, fx = on_frame(FIVE_ENEMY_FRAME, { armed = true })
        inject_nearby_enemies(bot, heroes, fx, k)
        local got = X.zuus_ShouldUltForTeamFight(bot)
        local want = k >= X.nUltFightQuorumArmed
        assert(got == want, string.format(
            'armed answered %s at %d enemy heroes; the armed quorum %d says %s. An '
            .. 'armed leg that did not admit a fight of %d is the dead-wiring twin: '
            .. 'helper, id, gate and call site all survive review while the armed '
            .. 'answer is byte-for-byte the shipped one, and the verdict then reads '
            .. 'back "tested, no effect" with nothing raising a hand.',
            tostring(got), k, X.nUltFightQuorumArmed, tostring(want),
            X.nUltFightQuorumArmed))
    end
end

tests['section 5: armed is a WIDENING -- it never withdraws a shipped true'] = function()
    local Xc = on_frame(FIVE_ENEMY_FRAME)
    for k = 0, Xc.nUltFightQuorumShipped do
        local Xoff, _, botOff, heroesOff, fxOff = on_frame(FIVE_ENEMY_FRAME, { armed = false })
        inject_nearby_enemies(botOff, heroesOff, fxOff, k)
        local off = Xoff.zuus_ShouldUltForTeamFight(botOff)

        local Xon, _, botOn, heroesOn, fxOn = on_frame(FIVE_ENEMY_FRAME, { armed = true })
        inject_nearby_enemies(botOn, heroesOn, fxOn, k)
        local on = Xon.zuus_ShouldUltForTeamFight(botOn)

        assert(not (off and not on), string.format(
            'arming WITHDREW a shipped true at %d enemy heroes. This lever is a '
            .. 'widening by construction -- the shipped comparison runs first and '
            .. 'short-circuits -- so a withdrawal means the helper was restructured.',
            k))
    end
end

tests['section 5: non-turbo never reaches the armed leg'] = function()
    local X, _, bot, heroes, fx = on_frame(FIVE_ENEMY_FRAME,
        { armed = true, nonTurbo = true })
    inject_nearby_enemies(bot, heroes, fx, X.nUltFightQuorumArmed)
    assert(X.zuus_ShouldUltForTeamFight(bot) == false,
        'the armed leg fired outside turbo. This lever is scoped to turbo, where the '
        .. 'game is short enough that a banked 130s ultimate is a large share of the '
        .. 'ultimates the hero will ever cast.')
end

-- ---------------------------------------------------------------- section 6 --
-- The limits, as one-way tripwires rather than prose.  Each of these going red
-- is GOOD NEWS -- it means the corpus grew a reading this round could not buy.

tests['section 6: TRIPWIRE -- no Zeus-subject frame reaches even the armed quorum'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    assert(#ZSUBJ == #ZUUS_FRAMES, string.format(
        'the sweep reported %d Zeus-subject frames and this file lists %d. The list is '
        .. 'deliberate; re-anchor it rather than letting the counts drift.',
        #ZSUBJ, #ZUUS_FRAMES))
    for _, row in ipairs(ZSUBJ) do
        assert(row.n < X.nUltFightQuorumArmed, string.format(
            'GOOD NEWS: %s now counts %d enemy heroes inside the fight radius, which '
            .. 'reaches the armed quorum %d. This round bought no such frame and said '
            .. 'so; take the reading and retire the limit in the header of %s.',
            row.fix, row.n, X.nUltFightQuorumArmed, SRC))
    end
end

tests['section 6: the vantage bias is real, and it is NOT this round\'s lever'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    -- The registered second lever's premise, read off the corpus: a frame where
    -- somebody standing in the fight counts a quorum while Zeus, in the same
    -- frame, does not.  Global ult, caster-centred measurement.
    local byFix = {}
    for _, row in ipairs(ZSUBJ) do byFix[row.fix] = row.n end
    local nBiased = 0
    for _, v in ipairs(VP) do
        if byFix[v.fix] ~= nil
            and not v.subject
            and v.n >= X.nUltFightQuorumArmed
            and byFix[v.fix] < X.nUltFightQuorumArmed
        then
            nBiased = nBiased + 1
        end
    end
    assert(nBiased > 0,
        'the corpus no longer shows a frame in which a non-Zeus vantage point reaches '
        .. 'the armed quorum while the Zeus subject in the SAME frame does not. That '
        .. 'asymmetry is the evidence for the registered-but-unclaimed second lever '
        .. '(a global ult whose fight size is measured from the caster). If it is '
        .. 'gone, re-read the registration in bots/BotLib/hero_zuus.lua before '
        .. 'quoting it.')
end

return tests

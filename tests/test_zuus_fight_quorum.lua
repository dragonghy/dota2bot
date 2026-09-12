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
-- in.  Repointing the count at the fight rather than at Zeus is a second lever
-- with its own id; one lever at a time, and this one is the quorum.
--
-- ⛔ CORRECTED 2026-09-12, AND THE CORRECTION IS IN SECTION 7.  This paragraph
-- used to cite "two of Zeus's own enemies each count FOUR enemies inside 1400
-- while Zeus, in the very same frame, counts two", pinned by a section-6 test.
-- Those two numbers count DIFFERENT TEAMS -- `bEnemy` is relative to the hero
-- the call is made on -- so the 4 was Zeus's own ALLIES near centaur.  Section 7
-- re-measures the bias with the quantity held fixed and fog-honest, and reports
-- a headline that changes how this file's own lever must be read: at the
-- SHIPPED vantage the count never exceeds 2 over 45 live Zeus frames, so the
-- armed quorum 3 is still an off-switch there.  Read section 7 before quoting
-- section 2's "a filter -- it admits some, and few": that reading is taken at
-- every hero in the corpus, not at the one vantage point the branch uses.
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
    -- [replay-check 2026-09-07] Added with a named cause, which is what this
    -- list asks for: the `zusultstrand` creation frame (17.6% HP, ult ready,
    -- Slardar at 305u, dead 8.3s later) --
    -- tests/test_replay_260827_zuus_ultstrand_creation.lua.  It is listed HERE
    -- because section 6's census globs Zeus-subject fixtures and went red on the
    -- count the moment the file landed.  It changes nothing about the QUORUM
    -- lever: its fight radius holds one living enemy (Ogre Magi lies dead on the
    -- same spot and does not count), so it stays far under the armed quorum 3
    -- and section 6's tripwire keeps saying what it said.
    'tests/fixtures/f_20260827_091703_slot12_zuus_473_1.lua',
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

-- ---------------------------------------------------------------- section 7 --
-- ⭐ THE VANTAGE BIAS, RE-MEASURED 2026-09-12 AFTER THE OLD READING WAS
-- FALSIFIED.  Section 6 used to close with a test called "the vantage bias is
-- real, and it is NOT this round's lever".  It compared two rows of
-- _zusfightquorum_sweep.lua against each other, and THE TWO ROWS COUNT
-- DIFFERENT TEAMS: `bEnemy = true` is relative to the hero the call is made on,
-- so at a dire vantage point that expression counts RADIANT heroes and at Zeus
-- it counts DIRE heroes.  The sentence it licensed --
--
--     "two of Zeus's own enemies each see FOUR enemies inside 1400 while Zeus,
--      in the same frame, sees two"
--
-- -- reads as one quantity measured from two places, and is two quantities.
-- The 4 in f_260819_222052_zuus_w2_leak is how many of ZEUS'S OWN ALLIES stood
-- near centaur.  Asked the question the branch actually asks -- how many DIRE
-- heroes are inside 1400 of centaur -- that frame answers 2, the same 2 Zeus
-- reads from his own feet.  So the old test could be satisfied by Zeus's team
-- clumping up, which is not the defect and is not evidence for any lever.
--
-- ⚠️ THE BIAS ITSELF SURVIVES THE CORRECTION -- it is the SIZE that moves, and
-- the direction of the error was toward over-stating it.  tests/
-- _zusultvantage_sweep.lua holds the quantity fixed (visible castable enemies
-- of Zeus) and moves only the vantage point, fog-honestly.  Readings below.

local function vantage_sweep()
    local p = assert(io.popen('lua5.1 tests/_zusultvantage_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'tests/_zusultvantage_sweep.lua did not finish (no DONE line). Nothing in '
        .. 'section 7 is a reading until it does.')
    local c, rows, radius = {}, {}, nil
    for line in text:gmatch('[^\n]+') do
        local r = line:match('^RADIUS (%d+)$')
        if r then radius = tonumber(r) end
        local f, s, sh, be, fi, ca =
            line:match('^Z (%S+) (%d) (%d+) (%d+) (%d) (%d)$')
        if f then
            rows[#rows + 1] = { fix = f, subject = s == '1', ship = tonumber(sh),
                best = tonumber(be), fight = fi == '1', castable = ca == '1' }
        end
        local ck, cv = line:match('^C ([%w_]+) (%-?%d+)$')
        if ck then c[ck] = tonumber(cv) end
    end
    return c, rows, radius
end

local VC, VROWS, VRADIUS = vantage_sweep()

tests['section 7: the vantage sweep measured the radius the hero file ships'] = function()
    local X = on_frame(ZUUS_FRAMES[1])
    assert(VRADIUS == X.nUltFightRadius, string.format(
        'the vantage sweep counted inside %s units while the hero file ships %s.',
        tostring(VRADIUS), tostring(X.nUltFightRadius)))
    assert(VC.zeus_frames ~= nil and VC.zeus_frames > 0,
        'the vantage sweep found no live Zeus frame at all; every reading below '
        .. 'would then be vacuously true.')
end

tests['section 7: the bias is real with the quantity held fixed'] = function()
    -- The corrected premise: on frames where the count centred on some enemy
    -- exceeds the count centred on Zeus, the SAME set of heroes is being
    -- counted -- only the centre of the circle moved.
    assert(VC.vantage_gain_frames > 0, string.format(
        'no live Zeus frame now shows a larger enemy clump measured from an enemy '
        .. 'than from Zeus (%d of %d). That asymmetry is the whole premise of the '
        .. 'registered-but-unlanded vantage lever; if it is gone, re-read the '
        .. 'registration in %s before quoting it.',
        VC.vantage_gain_frames, VC.zeus_frames, SRC))
end

tests['section 7: TRIPWIRE -- the ARMED quorum is still an off-switch at the SHIPPED vantage'] = function()
    -- ⭐ THE HEADLINE, and the reason this section is worth its runtime.  Section
    -- 2 priced the armed quorum as "a filter -- it admits some, and few" off a
    -- histogram taken at EVERY hero.  Measured where the branch actually reads
    -- it -- at Zeus, counting Zeus's enemies -- the count never exceeds this
    -- number over the whole corpus.  While that holds, lowering the quorum from
    -- 5 to 3 cannot change a single decision, and a wave that reports "no
    -- effect" for `zusfightquorum` will be reporting the gate's zero, not the
    -- game's.
    local X = on_frame(ZUUS_FRAMES[1])
    assert(VC.max_ship < X.nUltFightQuorumArmed, string.format(
        'GOOD NEWS: the caster-centred count now reaches %d over %d live Zeus '
        .. 'frames, which meets the armed quorum %d. `zusfightquorum` has a domain '
        .. 'at its own vantage point for the first time; take the reading and '
        .. 're-anchor this tripwire.',
        VC.max_ship, VC.zeus_frames, X.nUltFightQuorumArmed))
end

tests['section 7: and repointing the count is what would make that quorum reachable'] = function()
    -- The other half of the same sentence: the ceiling is a property of WHERE
    -- the circle is centred, not of how many heroes exist.  Same corpus, same
    -- heroes, same radius -- centre it on the fight and the count clears the
    -- armed quorum.
    local X = on_frame(ZUUS_FRAMES[1])
    assert(VC.max_best >= X.nUltFightQuorumArmed, string.format(
        'the fight-centred count now tops out at %d, below the armed quorum %d. '
        .. 'The claim that repointing the vantage makes the quorum reachable is '
        .. 'read off this number and no longer holds -- do not quote it.',
        VC.max_best, X.nUltFightQuorumArmed))
    assert(VC.max_best > VC.max_ship, string.format(
        'fight-centred and caster-centred counts now top out at the same value '
        .. '(%d). The two are then not distinguishable on this corpus and the '
        .. 'vantage registration has no evidence behind it.',
        VC.max_best))
end

tests['section 7: TRIPWIRE -- the shipped conjunction is false on every live Zeus frame'] = function()
    -- ⚠️ BOTH conjuncts are caster-centred, and this is the assertion that keeps
    -- the two halves from being read separately.  J.IsInTeamFight( bot, R ) is
    -- true on some frames and the count clears a quorum on others; the branch
    -- needs BOTH at once, and over the corpus that never happens at either
    -- quorum.  A fix to one half alone therefore cannot be shown to move this
    -- branch -- which is why no vantage lever was landed this round.
    local X = on_frame(ZUUS_FRAMES[1])
    local nFireArmed, nFireShipped = 0, 0
    for _, r in ipairs(VROWS) do
        if r.fight and r.ship >= X.nUltFightQuorumArmed then nFireArmed = nFireArmed + 1 end
        if r.fight and r.ship >= X.nUltFightQuorumShipped then nFireShipped = nFireShipped + 1 end
    end
    assert(nFireShipped == 0 and nFireArmed == 0, string.format(
        'GOOD NEWS: the branch condition is now satisfiable on real frames '
        .. '(%d at the shipped quorum, %d at the armed one, over %d live Zeus '
        .. 'frames, %d of which are in a team fight at all). This branch has been '
        .. 'dark for the whole life of this file; a creation frame exists now, so '
        .. 'pin it and re-anchor this tripwire.',
        nFireShipped, nFireArmed, VC.zeus_frames, VC.in_team_fight))
end

return tests

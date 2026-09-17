-- [fightfoe / strategy 2026-09-17] "AM I IN A TEAM FIGHT" IS ANSWERED WITHOUT
-- LOOKING AT A SINGLE ENEMY.
--
-- THE DEFECT, in one line: J.IsInTeamFight reads ONE list and it is the ALLY
-- list -- `J.GetNearbyHeroes(bot, nRadius, false, BOT_MODE_ATTACK)`, with
-- `bEnemy = false`. There is no enemy term anywhere in the function, so
-- "two allies are in attack mode and the ring is empty" and "two allies are
-- fighting the other team beside me" are the SAME answer.
--
-- ⭐ WHY THAT IS A DEFECT AND NOT A CHEAP PROXY. The predicate's 313 call
-- sites (133 files, 16 negated; masked-comment tally 314 minus this
-- function's own `function` line -- a raw grep answers 330 and that surplus
-- is prose, not call sites)
-- ask it whether a fight is happening AROUND THEM, at a radius they
-- chose. An ally in attack mode says a fight is happening somewhere near THAT
-- ALLY -- which, at 1600, can be another 1600 further on. The one reading that
-- makes the two agree is an enemy inside the caller's own ring, and that is
-- the term the function never takes.
--
-- ⛔ WHAT THIS FILE DOES **NOT** CLAIM, said first because the corpus is split
-- in two here and the halves must never be merged into one sentence:
--   * §3 (i) is GROUND TRUTH: the enemy half of the loader's GetNearbyHeroes
--     is the dump's own roster, vision-limited. "No enemy hero within 1600"
--     is a measurement.
--   * §3 (ii) is an UPPER BOUND: the loader's GetNearbyHeroes IGNORES its
--     third argument, so the ALLY half reads as "allies nearby", never
--     "allies in attack mode". Every shipped-TRUE count in this corpus is
--     therefore an over-count, and the flip count that follows from it is an
--     upper bound -- ⛔ not a claim that 46 frames flip. Closing that needs a
--     per-hero mode in the dump (the GH #27 supply gap); it is owed, not
--     worked around here.
-- The DIRECTION claim (§4) rests on neither of them: it is read off the
-- source, where the veto is guarded by the shipped answer itself.
--
-- ⛔ ONE LEVER. The trailing commented-out `bot:GetActiveMode() ~=
-- BOT_MODE_RETREAT` -- the author's own second missing conjunct -- is asserted
-- STILL COMMENTED OUT by §1, so this round cannot smuggle it in.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

local tests = {}

local JMZ = 'bots/FunLib/jmz_func.lua'

local function read(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

--- Structural claims are claims about CODE. This lever ships with a long
--- comment that names every symbol below, so the prose must not be able to
--- satisfy an assertion about the body.
local function mask_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

--- The body of one named function, from its `function J.<name>` to the
--- matching `\nend`. Anchored on code, never on a comment.
local function fn_body(src, sName)
    local a = src:find('\nfunction ' .. sName .. '%s*%(')
    if a == nil then return nil end
    local b = src:find('\nend', a, true)
    if b == nil then return nil end
    return src:sub(a, b + 3)
end

local function count(s, needle)
    if s == nil then return 0 end
    local n, at = 0, 1
    while true do
        local i = s:find(needle, at, true)
        if i == nil then break end
        n = n + 1
        at = i + 1
    end
    return n
end

-- =====================================================================
-- §1  THE DEFECT AND THE REPAIR, AS STATEMENTS ABOUT THE SOURCE.
-- =====================================================================

tests['§1 the shipped predicate takes no enemy argument anywhere'] = function()
    local src = read(JMZ)
    local body = assert(fn_body(src, 'J.IsInTeamFight'), 'J.IsInTeamFight not found')
    local code = mask_comments(body)

    -- The ally list: `bEnemy = false`. Exactly one, exactly as shipped.
    assert(count(code, 'J.GetNearbyHeroes(bot, nRadius, false, BOT_MODE_ATTACK )') == 1,
        'the shipped ally list is no longer read verbatim -- this lever may not '
        .. 'move it')

    -- ⭐ The finding itself, as a count the tree has to keep honest: before
    -- this round the function held ZERO reads with `true` in the enemy slot.
    -- After it, exactly ONE -- the gated one. A second would mean somebody
    -- widened the repair without saying so.
    assert(count(code, 'J.GetNearbyHeroes( bot, nRadius, true, BOT_MODE_NONE )') == 1,
        'the enemy ring is not read exactly once in J.IsInTeamFight')

    -- The clamp and the threshold are shipped constants and stay untouched.
    assert(count(code, 'nRadius > 1600') == 1, 'the 1600 clamp moved')
    assert(count(code, '#attackModeAllyList >= 2') == 2,
        'expected the shipped threshold twice: once guarding the veto, once as '
        .. 'the returned expression')

    -- ⛔ ONE LEVER: the author's own second conjunct stays commented out.
    assert(body:find('-- and bot:GetActiveMode() ~= BOT_MODE_RETREAT', 1, true) ~= nil,
        'the trailing mode clause is no longer present as a comment')
    assert(count(code, 'GetActiveMode') == 0,
        'the commented-out mode conjunct was smuggled into the body -- that is '
        .. 'a SECOND lever and it is not this one')
end

tests['§1 the gate is one id, gate before turbo, and outside the call site'] = function()
    local src = read(JMZ)
    local gate = assert(fn_body(src, 'J.ShouldTeamFightNeedAnEnemy'),
        'J.ShouldTeamFightNeedAnEnemy not found')
    local gcode = mask_comments(gate)

    -- ⛔ The 'pullcad' trap: two ids in one predicate freeze FALSE the day one
    -- of them is promoted. Exactly one id, and it is this one.
    assert(count(gcode, 'J.IsSoakCandidate') == 1,
        'the gate names more than one candidate id')
    assert(count(gcode, "J.IsSoakCandidate( 'fightfoe' )") == 1,
        "the gate does not name 'fightfoe'")

    -- Gate FIRST, then turbo: un-armed the helper must reach no engine call.
    local iGate = assert(gcode:find('IsSoakCandidate', 1, true))
    local iTurbo = assert(gcode:find('IsModeTurbo', 1, true))
    assert(iGate < iTurbo, 'turbo is asked before the gate -- un-armed this '
        .. 'helper would reach an engine call')

    -- The call site names no candidate id of its own (the gate lives in the
    -- helper, so there is exactly one place to read it).
    local body = assert(fn_body(src, 'J.IsInTeamFight'))
    assert(count(mask_comments(body), 'IsSoakCandidate') == 0,
        'the call site names a candidate id directly')
end

-- =====================================================================
-- §2  DRIVEN ON REAL FRAMES -- three contrasting subjects, no construction.
-- =====================================================================

-- Two allies in the ring, ZERO enemies within 1600: the frame the lever is for.
local FLIP_FX   = 'tests/fixtures/f_212636_tide_ancient.lua'
local FLIP_SUBJ = 'npc_dota_hero_luna'
-- Two allies in the ring AND two enemies: a real fight, which must not move.
local HOLD_FX   = 'tests/fixtures/f_071859_oracle_screen.lua'
local HOLD_SUBJ = 'npc_dota_hero_oracle'
-- Nobody at all: below the shipped threshold, so the veto is never reached.
local BELOW_FX   = 'tests/fixtures/f_045650_lion_meatgrinder.lua'
local BELOW_SUBJ = 'npc_dota_hero_axe'

local function side_of(sFx, sSubj)
    local _, bot = rf.load(sFx, sSubj)
    return bot:GetTeam() == TEAM_RADIANT and 'radiant' or 'dire'
end

--- The loader world is Turbo by name but not by the literal 23 (GH #93), and
--- J.IsModeTurbo is what the gate asks second.
local function turbo_world(sFx, sSubj)
    GAMEMODE_TURBO = nil                   -- luacheck: ignore
    local J, bot = rf.load(sFx, sSubj)
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
    return J, bot
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- The frame's OWN census, read by the same reader the helper uses, so a case
--- that silently stopped describing its frame fails instead of passing.
local function ring(J, bot)
    return #J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_ATTACK),
           #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)
end

tests['§2 the three frames are the frames this file says they are'] = function()
    for _, row in ipairs({
        { FLIP_FX,  FLIP_SUBJ,  2, 0 },
        { HOLD_FX,  HOLD_SUBJ,  2, 2 },
        { BELOW_FX, BELOW_SUBJ, 0, 0 },
    }) do
        local J, bot = rf.load(row[1], row[2])
        local nAlly, nEnemy = ring(J, bot)
        assert(nAlly == row[3], row[1] .. ' ally ring moved: expected '
            .. row[3] .. ', read ' .. nAlly)
        assert(nEnemy == row[4], row[1] .. ' enemy ring moved: expected '
            .. row[4] .. ', read ' .. nEnemy)
    end
end

tests['§2 ⭐ armed in turbo, the enemy-less "team fight" stops being one'] = function()
    ss.with_candidate('fightfoe', function()
        local J, bot = turbo_world(FLIP_FX, FLIP_SUBJ)
        assert(J.IsSoakCandidate('fightfoe') == true,
            'the gate did not open, so this leg measured the unarmed tree')
        assert(J.IsInTeamFight(bot, 1600) == false,
            'armed, a frame with two allies in the ring and ZERO enemies within '
            .. '1600 is still called a team fight')
        unprobe()
    end, side_of(FLIP_FX, FLIP_SUBJ))
end

tests['§2 un-armed the same frame answers exactly what it shipped'] = function()
    local J, bot = turbo_world(FLIP_FX, FLIP_SUBJ)
    assert(J.IsSoakCandidate('fightfoe') == false, 'something armed the gate')
    assert(J.IsInTeamFight(bot, 1600) == true,
        'the shipped answer on the pinned frame is not TRUE -- either the frame '
        .. 'moved or the un-armed path is no longer the shipped expression')
    unprobe()
end

tests['§2 ⭐ armed, a REAL fight is untouched'] = function()
    ss.with_candidate('fightfoe', function()
        local J, bot = turbo_world(HOLD_FX, HOLD_SUBJ)
        assert(J.IsSoakCandidate('fightfoe') == true, 'the gate did not open')
        assert(J.IsInTeamFight(bot, 1600) == true,
            'armed, a frame with two allies AND two enemies inside 1600 stopped '
            .. 'being a team fight -- the lever is eating its own domain')
        unprobe()
    end, side_of(HOLD_FX, HOLD_SUBJ))
end

tests['§2 armed, a frame below the shipped threshold is false either way'] = function()
    local J0, bot0 = turbo_world(BELOW_FX, BELOW_SUBJ)
    assert(J0.IsInTeamFight(bot0, 1600) == false, 'the shipped answer moved')
    unprobe()
    ss.with_candidate('fightfoe', function()
        local J, bot = turbo_world(BELOW_FX, BELOW_SUBJ)
        assert(J.IsSoakCandidate('fightfoe') == true, 'the gate did not open')
        assert(J.IsInTeamFight(bot, 1600) == false,
            'armed, a frame with nobody in the ring answered TRUE')
        unprobe()
    end, side_of(BELOW_FX, BELOW_SUBJ))
end

tests['§2 armed OUTSIDE turbo the frame is untouched'] = function()
    ss.with_candidate('fightfoe', function()
        GAMEMODE_TURBO = nil                   -- luacheck: ignore
        local J, bot = rf.load(FLIP_FX, FLIP_SUBJ)
        GetGameMode = function() return 22 end -- luacheck: ignore
        assert(J.IsSoakCandidate('fightfoe') == true, 'the gate did not open')
        assert(J.IsInTeamFight(bot, 1600) == true,
            'armed OUTSIDE turbo the predicate moved; this lever is turbo-only')
        unprobe()
    end, side_of(FLIP_FX, FLIP_SUBJ))
end

tests['§2 the radius the conjunct uses is THE CALLER\'S, not a new constant']
= function()
    -- On the pinned frame the enemy ring is empty at 1600, so it is empty at
    -- every smaller radius too: the armed answer must be FALSE for each one
    -- the callers actually pass, and the SHIPPED answer must be whatever the
    -- ally count at that radius says -- read here, never retyped.
    ss.with_candidate('fightfoe', function()
        local J, bot = turbo_world(FLIP_FX, FLIP_SUBJ)
        for _, r in ipairs({ 900, 1200, 1600 }) do
            local nEnemy = #J.GetNearbyHeroes(bot, r, true, BOT_MODE_NONE)
            assert(nEnemy == 0, 'the frame has an enemy inside ' .. r
                .. ', so this row is not about an empty ring')
            assert(J.IsInTeamFight(bot, r) == false,
                'armed, the predicate answered TRUE at radius ' .. r
                .. ' with an empty enemy ring')
        end
        unprobe()
    end, side_of(FLIP_FX, FLIP_SUBJ))
end

-- =====================================================================
-- §3  THE CORPUS, AS TWO READINGS THAT ARE NEVER MERGED.
-- =====================================================================

-- =====================================================================
-- §3/§4 LIVE IN tests/_fightfoe_sweep.lua, NOT HERE -- and that is a repair,
-- not a convenience.
--
-- ⛔ THE INCIDENT THAT MOVED THEM (recorded so nobody moves them back).  The
-- two corpus walks made this file ~120s.  tools/agent/lua_gate.py runs an
-- unmeasured new test with `hook_timeout_seconds` = 20.0 and KILLS it at the
-- timeout; the kill landed between `ss.arm` and `ss.disarm`, leaving the
-- global switch `bots/Customize/soak_side.lua` on disk holding
-- `{ side = 'radiant', cand = 'fightfoe' }`.  Every OTHER gate test then
-- failed its "gate off" precondition against that leftover and the push was
-- refused with 11 findings, NONE about the code under test.
-- ⇒ A test that can be killed mid-arm is a hazard to the whole suite (the
-- GH #229 / GH #365 §3 family).  The per-test cap is what enforces that, and
-- the remedy the manifest's own `hand_added_note` records for 'tpstash' and
-- 'WEAKHPSEED' is the one taken here: MAKE THE FILE CHEAP.  ⛔ Never shave the
-- recorded seconds instead -- the budget is derived, not chosen.
--
-- THE READINGS, from `lua5.1 tests/_fightfoe_sweep.lua` on this corpus:
--   live 1039 / shipped_live 1039   the two passes saw the same corpus
--   enemyless 521                   §3 (i), GROUND TRUTH (50.1%)
--   ally2 106 / ally2_enemyless 46  §3 (ii), the UPPER BOUND (see the header)
--   flippable 25                    shipped-TRUE ∩ empty ring ∩ gate open here
--   down 25 / up 0                  §4, the direction tally -- `down` equals
--                                   `flippable` exactly, and `up` is zero
-- ⛔ `flippable` (25) is strictly less than `ally2_enemyless` (46) because
-- `with_candidate` arms ONE side; that inequality is what says the walk did
-- not silently arm both.
-- =====================================================================

-- =====================================================================
-- §5  CONTROLS.  ⛔ A stand with no control leg cannot tell "everything was
-- caught" from "nothing ran at all" (charter 0NEXT36).
-- =====================================================================

tests['[control] un-armed the gate is shut'] = function()
    local J = rf.load(FLIP_FX, FLIP_SUBJ)
    assert(J.IsSoakCandidate('fightfoe') == false,
        'the gate is open with nothing armed')
    assert(J.ShouldTeamFightNeedAnEnemy() == false,
        'un-armed the helper answered true')
end

tests['[control] armed on the other side the gate stays shut'] = function()
    local sOther = side_of(FLIP_FX, FLIP_SUBJ) == 'radiant' and 'dire' or 'radiant'
    ss.with_candidate('fightfoe', function()
        local J, bot = turbo_world(FLIP_FX, FLIP_SUBJ)
        assert(J.IsSoakCandidate('fightfoe') == false,
            'the gate fired for a bot on the other side')
        assert(J.IsInTeamFight(bot, 1600) == true,
            'the shipped answer moved for a bot the gate does not cover')
        unprobe()
    end, sOther)
end

tests['[control] armed under another id the gate stays shut'] = function()
    ss.with_candidate('fightstate', function()
        local J = turbo_world(FLIP_FX, FLIP_SUBJ)
        assert(J.IsSoakCandidate('fightfoe') == false,
            'the gate fired under a different candidate id')
        -- ⭐ AND THE SIBLING IS UNMOVED BY THIS ONE: two ids, two levers.
        assert(J.IsSoakCandidate('fightstate') == true,
            'arming the sibling id did not open the sibling gate')
        unprobe()
    end, side_of(FLIP_FX, FLIP_SUBJ))
end

return tests

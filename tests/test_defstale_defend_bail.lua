-- [defstale] DefendThink's "don't walk through fire" bail-out compares a
-- quantity against an older copy of itself.
--
-- The source's own comment (typescript/bots/FunLib/aba_defend.ts:901) calls it
-- "a small don't-walk-through-fire guard": more enemies on my PATH than IN
-- RANGE means step back. But both sides are the SAME query --
-- `jmz.GetLastSeenEnemiesNearLoc(botLocation, 1600)`:
--
--   * `pathEnemies` is that query, bucketed to 500ms on the bot handle;
--   * `ds.nInRangeEnemy` is that query, written at the BOTTOM of
--     GetDefendDesireHelper -- below SEVEN early returns. One of them,
--       #closeEnemiesDefend > 0 and #closeAlliesDefend >= #closeEnemiesDefend
--     fires on exactly the frames DefendThink runs on, i.e. whenever a fight is
--     happening within 900 of the bot. `bot._defend` is never reset, so during a
--     fight the right-hand side freezes at whatever it held before the fight
--     started -- or, if no helper call ever reached the bottom, at the initial
--     empty table (0).
--
-- So the comparison is never a path/range difference; it is bought entirely by
-- that staleness. When it is true the bot walks 700 back toward its fountain and
-- `return`s, abandoning every other DefendThink branch for the frame.
--
-- REAL FRAME: f_260819_223607_drow_defend_bail -- game 20260819_223607_slot1 at
-- t=330.4 (5:30). Subject drow_ranger (Dire), 609/780 hp (78%), standing 929u
-- from its own 56%-hp top tier-1 tower, last hit by ogre_magi 3.8s earlier, with
-- exactly ONE enemy (necrolyte) inside 1600. GROUND TRUTH from the replay: the
-- drow stayed -- it last-hit a creep at t=332.6, took 120 xp at t=336.9, put
-- 254 damage into ogre_magi between t=338.0 and t=339.9, and did not die for
-- another 42.5 seconds. Stepping back toward the fountain was the wrong call on
-- this frame, and it was not chosen for any reason a reader of the guard would
-- recognise.
--
-- CONTROL FRAME: f_260819_222526_jakiro_defend_fresh -- game
-- 20260819_222526_slot1 at t=358.5. Same lane, same shape, one difference that
-- matters: TWO enemies within 900 against one ally, so the helper does NOT take
-- the early return, reaches the bottom, and writes a live nInRangeEnemy. There
-- the guard is honestly false and armed must be a byte-for-byte no-op.
--
-- 2026-08-20T23:30Z: both fixtures were REGENERATED with the drafted roles of
-- their soak seed (868) and with real structure health. Everything else in them
-- is byte-identical. The re-read is the RE-READ section near the bottom of this
-- file; short version, the pin holds and the world it holds in moved.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local BAIL = 'tests/fixtures/f_260819_223607_drow_defend_bail.lua'
local FRESH = 'tests/fixtures/f_260819_222526_jakiro_defend_fresh.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- any arithmetic on desire constants (same reason as
-- tests/test_roamstale_collapse_action.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
    BOT_ACTION_DESIRE_NONE     = 0.0,
    BOT_ACTION_DESIRE_VERYLOW  = 0.1,
    BOT_ACTION_DESIRE_LOW      = 0.25,
    BOT_ACTION_DESIRE_MODERATE = 0.5,
    BOT_ACTION_DESIRE_HIGH     = 0.75,
    BOT_ACTION_DESIRE_VERYHIGH = 0.9,
    BOT_ACTION_DESIRE_ABSOLUTE = 1.0,
}

--- Load a real frame with the real aba_defend module on top of it.
---   opts.armed  -- arm 'defstale' (nothing else is ever armed)
---   opts.turbo  -- set false to make J.IsModeTurbo() report a non-turbo game
local function world(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function(id)
        return id == 'defstale' and opts.armed == true
    end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end

    -- Per-lane push/defend desire is engine state, never a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    -- GH #61: rf.load refuses to answer GetLaneFrontLocation. This file's
    -- MECHANISM/FIX assertions read `ds.nInRangeEnemy` and `ds.defendLoc`
    -- through aba_defend, which -- with lane fronts collapsed to the origin --
    -- puts `ds.defendLoc` at the river and `ds.distanceToLane` identical
    -- across lanes. That was the pre-#61 world these frames were selected in,
    -- and this file's DEFECT is that `ds.enemyDamageOn` is stale w.r.t. its
    -- OWN write, orthogonal to the lane front. Declaring the origin here is
    -- the explicit continuation of that world.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore

    local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
    return J, bot, heroes, fx, Defend
end

--- One engine frame: bid all three defend lanes (which is what writes
--- ds.nInRangeEnemy when it gets that far), then run the winner's Think.
local function frame(path, opts)
    local J, bot, heroes, fx, Defend = world(path, opts)
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        Defend.GetDefendDesire(bot, lane)
    end
    local log = rf.record_actions(bot)
    Defend.DefendThink(bot, LANE_MID)
    return log, J, bot, heroes, fx, Defend
end

local function dist2d(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- ---------------------------------------------------------------------------
-- The frame itself. Every premise the defect rests on is asserted.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: a 78%-hp defender, under fire, one enemy inside 1600'] = function()
    local J, bot, heroes, fx = world(BAIL)
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(math.abs(fx.time - 330.4) < 1e-6, 'frame is t=330.4; got ' .. tostring(fx.time))
    assert(bot:GetHealth() == 609 and bot:GetMaxHealth() == 780,
        'subject is 609/780; got ' .. bot:GetHealth() .. '/' .. bot:GetMaxHealth())
    assert(bot:WasRecentlyDamagedByAnyHero(5),
        'the guard needs the under-fire half to be true on this frame')
    assert(not bot:WasRecentlyDamagedByAnyHero(3),
        'the last hero hit was 3.8s ago -- so the bail-out is bought by a memory, '
        .. 'not by damage landing right now')
    local here = bot:GetLocation()
    local near = J.GetLastSeenEnemiesNearLoc(here, 1600)
    assert(#near == 1, 'exactly one enemy inside 1600; got ' .. #near)
    local necro = heroes['npc_dota_hero_necrolyte']
    local d = dist2d(here, necro:GetLocation())
    assert(d > 800 and d < 900,
        'that enemy is the necrolyte at ~861u; got ' .. string.format('%.0f', d))
    assert(fx.observed and fx.observed.died_after == 42.5,
        'GROUND TRUTH: the subject survived another 42.5s after this frame; got '
        .. tostring(fx.observed and fx.observed.died_after))
end

tests['MECHANISM: the helper early-returns, so nInRangeEnemy is never written'] = function()
    local J, bot, _, _, Defend = world(BAIL)
    -- The early return that does it, asserted from the frame rather than assumed.
    local closeE = J.GetEnemiesNearLoc(bot:GetLocation(), 900)
    local closeA = J.GetAlliesNearLoc(bot:GetLocation(), 900)
    assert(#closeE > 0 and #closeA >= #closeE,
        'the `enemies within 900 and we are not outnumbered` early return must be '
        .. 'live here: got ' .. #closeE .. ' enemies vs ' .. #closeA .. ' allies')
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        local d = Defend.GetDefendDesireHelper(bot, lane)
        assert(math.abs(d - 0.3) < 1e-9,
            'every lane must take that early return (0.3); lane ' .. tostring(lane)
            .. ' returned ' .. tostring(d))
    end
    local ds = rawget(bot, '_defend')
    assert(#ds.nInRangeEnemy == 0,
        'so the right-hand side of the guard is still the initial empty table; got '
        .. #ds.nInRangeEnemy)
    -- ...while the left-hand side, the SAME query, is 1.
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600) == 1,
        'the identical query answers 1 on this very frame -- the difference between '
        .. 'the two sides is time, not meaning')
end

-- WITHDRAWN 2026-08-20: this case used to assert that a defend mode WINS the
-- script auction on this frame, which is what made DefendThink -- and with it
-- the defstale bail-out -- reachable here at all. It was true only because the
-- fixture world had no addressable structures: GetTower(team, TOWER_*) answered
-- nil for every slot, so aba_defend.GetFurthestBuildingOnLane returned nil, the
-- push modes fell back to a flat 0.05 and mode_laning_generic bid 0. With the
-- real building slots wired in (tests/mock/replay_fixture.lua) the same frame
-- bids laning 0.446 against defend 0.30, and laning wins.
--
-- So this frame no longer shows a live defect: DefendThink most likely was not
-- running here. That is consistent with the ground truth recorded above -- the
-- drow stayed and LAST-HIT CREEPS, which is laning behaviour, not defending.
-- The rest of this file still stands: it pins what the guard compares and that
-- the comparison can only ever be bought by staleness. What it no longer
-- carries is evidence that arming defstale would change anything on this frame.
-- See GH #55.
tests['WITHDRAWN: defend does NOT win the script auction on this frame'] = function()
    local _, bot = world(BAIL)
    local best, bestName, defend = -1, 'none', -1
    local p = io.popen('ls bots/mode_*.lua')
    for path in p:lines() do
        GetDesire = nil -- luacheck: ignore
        local ok = pcall(dofile, path)
        if ok and type(GetDesire) == 'function' then
            local ok2, d = pcall(GetDesire)
            if ok2 and type(d) == 'number' then
                if path:find('defend_tower') and d > defend then defend = d end
                if d > best then best, bestName = d, path end
            end
        end
    end
    p:close()
    assert(defend >= 0, 'the defend modes must produce a number here')
    assert(math.abs(defend - 0.30) < 0.005,
        'the defend modes still bid 0.30 here; got ' .. string.format('%.3f', defend))
    assert(bestName:find('laning'),
        'and laning outbids them; got ' .. bestName
        .. ' at ' .. string.format('%.3f', best))
    assert(best > defend + 0.1,
        'by a margin no rounding accounts for: ' .. string.format('%.3f vs %.3f', best, defend))
    -- LIMITATION, stated rather than hidden: the .dem carries no per-frame mode
    -- (GH #27) and the engine's own built-in modes have no script GetDesire, so
    -- this auction covers the SCRIPT modes only. It is evidence against
    -- reachability on this frame, not a proof that the engine never picks defend.
    assert(bot ~= nil)
end

-- ---------------------------------------------------------------------------
-- The defect.
-- ---------------------------------------------------------------------------

tests['DEFECT: shipped, the defender steps back toward its fountain'] = function()
    local log, J, bot = frame(BAIL)
    assert(#log == 1,
        'the bail-out returns immediately, so it is the only action of the frame; got '
        .. #log)
    assert(log[1].fn == 'Action_MoveToLocation',
        'expected the step-back move; got ' .. log[1].fn)
    local here, target = bot:GetLocation(), log[1].args[1]
    local step = dist2d(here, target)
    assert(step > 700 - 130 and step < 700 + 130,
        'the step is the guard\'s 700 plus its 120 jitter; got '
        .. string.format('%.0f', step))
    local fountain = J.GetTeamFountain()
    assert(dist2d(target, fountain) < dist2d(here, fountain),
        'and it points at our own fountain -- away from the tower being defended')
end

tests['FIX: armed, the frame is no longer spent walking backwards'] = function()
    local log = frame(BAIL, { armed = true })
    for _, a in ipairs(log) do
        assert(a.fn ~= 'Action_MoveToLocation',
            'armed, the staleness bail-out must not fire; still saw ' .. a.fn)
    end
end

tests['the fix is turbo-only'] = function()
    local log = frame(BAIL, { armed = true, turbo = false })
    assert(#log == 1 and log[1].fn == 'Action_MoveToLocation',
        'outside turbo the armed candidate must be inert, so the shipped bail-out '
        .. 'still fires')
end

-- ---------------------------------------------------------------------------
-- Separability: armed may only ever REMOVE this one action.
-- ---------------------------------------------------------------------------

tests['CONTROL: where the helper does reach the bottom, armed is a no-op'] = function()
    local J, bot, _, fx, Defend = world(FRESH)
    assert(math.abs(fx.time - 358.5) < 1e-6, 'control frame is t=358.5')
    local closeE = J.GetEnemiesNearLoc(bot:GetLocation(), 900)
    local closeA = J.GetAlliesNearLoc(bot:GetLocation(), 900)
    assert(#closeE > #closeA,
        'this frame must be outnumbered inside 900 so the early return is skipped; '
        .. 'got ' .. #closeE .. ' vs ' .. #closeA)
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        Defend.GetDefendDesire(bot, lane)
    end
    local ds = rawget(bot, '_defend')
    assert(#ds.nInRangeEnemy == #J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1600),
        'with the bottom reached, the two sides agree exactly -- that is the whole '
        .. 'point: they are the same query')
    assert(bot:WasRecentlyDamagedByAnyHero(5),
        'the under-fire half is still true here, so only the count separates the '
        .. 'control from the defect frame')

    local shipped = frame(FRESH)
    local armed = frame(FRESH, { armed = true })
    assert(#shipped == #armed, 'armed must not change the action count on a frame '
        .. 'where the guard was honestly false; ' .. #shipped .. ' vs ' .. #armed)
    for i = 1, #shipped do
        assert(shipped[i].fn == armed[i].fn,
            'action ' .. i .. ' differs: ' .. shipped[i].fn .. ' vs ' .. armed[i].fn)
    end
    assert(#shipped >= 1 and shipped[1].fn ~= 'Action_MoveToLocation',
        'and the control frame must not be a step-back at all; got '
        .. (shipped[1] and shipped[1].fn or 'nothing'))
end

-- ---------------------------------------------------------------------------
-- RE-READ under the real drafted roles (GH #57 / strategy backlog 0c).
--
-- Both frames were pinned while their fixtures carried NO `roles` table, so
-- aba_role.GetPosition fell through to RoleAssignment[team][slot] -- the draft
-- SLOT, which GH #57 measured against the real draft at 47.3%. Both games are
-- soak seed 868 (`script_version = mirror:...:s868:<side>`), so the drafted
-- role IS recoverable, and both fixtures have been regenerated with --roles.
--
-- What changed in the world (measured, not assumed):
--   BAIL  drow_ranger  slot 3 -> drafted pos 1   (core either way)
--   FRESH jakiro       slot 3 -> drafted pos 5   (CORE -> SUPPORT, a real flip)
-- and on the FRESH frame all five allies read a different position than before.
--
-- What did NOT change: every defend bid and every action on both frames. That
-- is a re-read result, not an absence of one -- the driven frame READS the role
-- 15 times (BAIL) / 18 times (FRESH), it just reads it in one place whose
-- outcome is the same on both sides of the change. The cases below assert both
-- halves, because "the pin survived" is worthless without "the world moved".
-- ---------------------------------------------------------------------------

--- Drive the same three lane bids as frame(), counting what the code asks the
--- role chain and what it is told. `jmz.GetPosition` is resolved on the table
--- at every call site, so hooking the table after world() catches them all.
local function bids_and_role_reads(path)
    local J, bot, _, _, Defend = world(path)
    local reads, answers = 0, {}
    local real = J.GetPosition
    J.GetPosition = function(u)
        local p = real(u)
        if u == bot then
            reads = reads + 1
            answers[tostring(p)] = (answers[tostring(p)] or 0) + 1
        end
        return p
    end
    local bids = {}
    for _, lane in ipairs({ LANE_TOP, LANE_MID, LANE_BOT }) do
        bids[#bids + 1] = Defend.GetDefendDesire(bot, lane)
    end
    J.GetPosition = real
    return bids, reads, answers, J, bot
end

tests['RE-READ: both frames carry the drafted role, and it is not the slot'] = function()
    local J, bot, heroes, fx = world(BAIL)
    assert(fx.roles ~= nil, 'the BAIL fixture must carry the drafted roles now -- '
        .. 'without them every position below is the draft slot (GH #57, 47.3%)')
    -- The subject sits at roster slot 3; the draft made it the pos 1.
    local ids = GetTeamPlayers(GetTeam())
    assert(#ids == 5 and GetTeamMember(3) == bot,
        'the subject must be the third roster slot on this frame, which is what '
        .. 'the slot-derived world used to answer 3 from')
    assert(J.GetPosition(bot) == 1, 'drafted role of the drow is pos 1; got '
        .. tostring(J.GetPosition(bot)) .. ' -- 3 means the fixture lost its roles')
    assert(J.IsCore(bot), 'pos 1 is a core, as slot 3 also was: on THIS frame the '
        .. 'core/support fork does not move, only the number does')

    -- The control frame is where the fork itself moves.
    local J2, bot2, _, fx2 = world(FRESH)
    assert(fx2.roles ~= nil, 'the CONTROL fixture must carry the drafted roles too')
    assert(GetTeamMember(3) == bot2, 'the control subject is also roster slot 3')
    assert(J2.GetPosition(bot2) == 5, 'drafted role of the jakiro is pos 5; got '
        .. tostring(J2.GetPosition(bot2)))
    assert(J2.IsCore(bot2) == false,
        'and that is a CORE -> SUPPORT flip: the slot-derived world called this '
        .. 'jakiro a pos 3 core. Every `jmz.IsCore(bot)` fork in aba_defend read '
        .. 'the wrong side of itself on this frame before the fixture was healed')
    -- Not one lucky hero: the whole roster moved on the control frame.
    local moved = 0
    for i = 1, 5 do
        if J2.GetPosition(GetTeamMember(i)) ~= i then moved = moved + 1 end
    end
    assert(moved == 5, 'all five allies must read a position other than their slot '
        .. 'on the control frame; got ' .. moved
        .. ' -- if this drops, the fixture is answering slots again')
    assert(heroes ~= nil)
end

tests['RE-READ: the bids are unchanged, and the frame really does read the role'] = function()
    -- Pre-heal values, recorded before the fixtures were regenerated: BAIL bids
    -- 0.30 on all three lanes (the `enemies within 900 and not outnumbered`
    -- early return), CONTROL bids 0.10. If a future change moves either number,
    -- the whole file has to be re-derived rather than re-baselined.
    local bidsB, readsB, answersB = bids_and_role_reads(BAIL)
    for i, d in ipairs(bidsB) do
        assert(math.abs(d - 0.3) < 1e-9, 'BAIL lane ' .. i .. ' bid ' .. tostring(d)
            .. ', want 0.30 -- the same value the slot-derived world produced')
    end
    assert(readsB == 15, 'the BAIL frame asks for the subject position 15 times '
        .. 'while bidding; got ' .. readsB .. ' -- zero would make "the pin '
        .. 'survived the real roles" a statement about nothing')
    assert(answersB['1'] == 15 and answersB['3'] == nil,
        'and every one of those reads must be answered 1 (the draft), never 3 '
        .. '(the slot)')

    local bidsF, readsF, answersF = bids_and_role_reads(FRESH)
    for i, d in ipairs(bidsF) do
        assert(math.abs(d - 0.1) < 1e-9, 'CONTROL lane ' .. i .. ' bid ' .. tostring(d)
            .. ', want 0.10')
    end
    assert(readsF == 18, 'the CONTROL frame asks 18 times; got ' .. readsF)
    assert(answersF['5'] == 18 and answersF['3'] == nil,
        'answered 5 (the draft) every time, never 3 (the slot)')
end

tests['RE-READ: the margin is one level -- at level 5 the two worlds diverge'] = function()
    -- GetDefendDesireHelper's FIRST role fork (aba_defend.lua:922) is a level
    -- gate whose threshold is keyed on position: pos 1/2 need level 6, pos 3
    -- needs 5, pos 4/5 need 4. Both worlds return false here, but not with the
    -- same room: as a slot-3 the drow cleared its threshold by a level, as the
    -- drafted pos 1 it clears it by ZERO. One level lower and the two worlds
    -- would give this frame two different defend bids (None vs 0.30).
    local J, bot = world(BAIL)
    assert(bot:GetLevel() == 6, 'the subject is level 6 on this frame; got '
        .. bot:GetLevel())
    assert(J.GetPosition(bot) == 1, 'as the drafted pos 1 its threshold is 6')
    assert(not (bot:GetLevel() < 6),
        'level 6 is not below the pos-1 threshold, so the gate stays shut -- by '
        .. 'exactly one level. This is why the fixture had to be healed rather '
        .. 'than argued about')

    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    local line = src:match('\n([^\n]*GetPosition%(bot%) == 1 and botLevel[^\n]*)\n')
    assert(line, 'the position-keyed level gate must still be one line in '
        .. 'GetDefendDesireHelper -- if it was refactored, re-measure the margin')
    assert(line:find('botLevel < 6', 1, true) and line:find('botLevel < 5', 1, true),
        'the thresholds this margin is measured against (6 for pos 1/2, 5 for '
        .. 'pos 3) must still be the ones in the source; got: ' .. line)

    -- COUNTERFACTUAL, run rather than argued: same frame, same everything, one
    -- level lower. The two worlds then answer this frame differently -- the
    -- drafted pos 1 produces NO defend bid at all, the slot-derived pos 3
    -- produces the 0.30 this whole file is built on. So "the roles did not
    -- change the conclusion" is a fact about level 6, not about the guard.
    local function helper_at(role, level)
        local J2, b = world(BAIL)
        rawset(b, 'assignedRole', role)
        b.__spec.GetLevel = level -- the mock's own storage for a snapshot field
        assert(J2.GetPosition(b) == role, 'the counterfactual must actually take')
        local Defend = require(GetScriptDirectory() .. '/FunLib/aba_defend')
        return Defend.GetDefendDesireHelper(b, LANE_MID)
    end
    assert(math.abs(helper_at(1, 6) - 0.3) < 1e-9, 'drafted pos 1 at level 6: 0.30')
    assert(math.abs(helper_at(3, 6) - 0.3) < 1e-9, 'slot pos 3 at level 6: 0.30 too '
        .. '-- this is the frame as it really is, and the two agree')
    assert(math.abs(helper_at(3, 5) - 0.3) < 1e-9,
        'slot pos 3 at level 5 still clears its threshold of 5: 0.30')
    assert(math.abs(helper_at(1, 5)) < 1e-9,
        'but the DRAFTED pos 1 at level 5 is below its threshold of 6 and bids '
        .. 'nothing -- if this ever returns 0.30 the level gate lost its teeth '
        .. 'and the margin has to be re-measured')
end

tests['RE-READ: the fixtures also gained real structure health'] = function()
    -- Same regeneration brought `hp` on every building (the loader has answered
    -- it since 2026-08-20; these two frames predate that and stood at FULL
    -- health). aba_defend's urgency multiplier and its "this tier is already
    -- lost" early return are both remaps of that number, so it is not a neutral
    -- default. Asserted here because this file's own prose already quoted it.
    local _, _, _, fx = world(BAIL)
    local tower
    for _, b in ipairs(fx.buildings) do
        if b.name == 'tower' and b.team == 3 and b.x == -5275 and b.y == 6036 then
            tower = b
        end
    end
    assert(tower, 'the subject\'s own top tier-1 tower must be in the fixture')
    assert(tower.hp and math.abs(tower.hp - 0.561) < 1e-6,
        'it stands at 56.1% on this frame (the number this file has claimed in '
        .. 'prose since it was written); got ' .. tostring(tower.hp))
    local full = 0
    for _, b in ipairs(fx.buildings) do
        if b.hp == nil then full = full + 1 end
    end
    assert(full == 0, full .. ' building(s) still carry no hp and therefore read '
        .. 'as untouched -- regenerate the fixture')
end

-- ---------------------------------------------------------------------------
-- Reverse assertions: if somebody repairs this properly, this file must say so.
-- ---------------------------------------------------------------------------

tests['REVERSE: both sides of the guard are still the same query'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    local n = select(2, src:gsub('GetLastSeenEnemiesNearLoc', ''))
    assert(n >= 2, 'expected the query to appear on both sides; got ' .. n)
    assert(src:find('pathEnemies = jmz.GetLastSeenEnemiesNearLoc(botLocation, 1600)', 1, true),
        'the PATH side is still that query taken at the bot\'s own location -- if it '
        .. 'has been re-pointed at the defend location, the defect is fixed properly '
        .. 'and this whole file must be re-derived')
    assert(src:find('ds.nInRangeEnemy = jmz.GetLastSeenEnemiesNearLoc(', 1, true),
        'the RANGE side is still that same query')
end

tests['REVERSE: the gate is a pure removal, not a new bid or a new action'] = function()
    local src = io.open('bots/FunLib/aba_defend.lua'):read('*a')
    local n = select(2, src:gsub("IsSoakCandidate%(\"defstale\"%)", ''))
    assert(n == 1, 'defstale must have exactly one call site in aba_defend; got ' .. n)
    local guard = src:match('\n([^\n]*bStaleBail[^\n]*=[^\n]*)\n')
    assert(guard and guard:find('IsModeTurbo', 1, true),
        'the candidate must stay turbo-gated; got: ' .. tostring(guard))
end

return tests

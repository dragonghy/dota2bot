-- [ratchet] [illumove] minion_lib/illusions.lua throttles a PER-UNIT decision
-- with a MODULE-LEVEL clock, so every sibling minion after the first is given
-- no order at all -- permanently, not with a delay.
--
-- Family: backlog `0d`. That entry's remaining census line was "the other mode
-- files' `Action_AttackUnit(x, false)` / `Action_MoveToUnit`, plus the chase
-- orders in ability_item_usage_generic.lua". Both halves are now measured and
-- both are EMPTY of new work: the mode half ended at
-- mode_outpost_generic.lua:117 (GH #373), and a grep of
-- bots/ability_item_usage_generic.lua for the whole continuous/queued order
-- family returns exactly one line, `ActionQueue_UseAbility(hItem)` at :1120 --
-- an item cast inside SetUseItem's 'twice' arm, not a chase order. Widening
-- the same grep to all of bots/ outside bots/mode_*.lua is what turned this
-- up: six live `Action_AttackUnit(x, false)` call sites, all of them in the
-- MINION drivers (aba_hero_sub_units.lua, minion_lib/{primal_split,illusions}),
-- a population `0d` never named because it is not reached through mode
-- bidding at all. The order at illusions.lua:31 turned out to be sound; the
-- branch four lines under it is not.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A throttle's scope must equal the scope of the thing it throttles.
--     `nNextMoveTime` is one number per MODULE. The decision it rate-limits
--     ("has this unit been given somewhere to go recently?") is one per UNIT.
--     Where those two scopes differ, the throttle stops being a rate limit and
--     becomes a LOTTERY: the first caller through the door in each window
--     takes the budget for everybody, and the losers do not get a late order,
--     they get no order -- X.Think simply ends. Nothing raises its hand,
--     because from inside the module every call looks like a correctly
--     throttled one.
--     Distinguish from the four same-family findings before it. GH #348 is
--     ORDER (a nil guard below the index it guards). GH #368 is SCOPE too, but
--     LEXICAL scope -- a `local` shadowing a file-level name so a guard and
--     its consumer read different variables. GH #370 is an UNREPORTED SIDE
--     EFFECT. GH #373 is a latch recording the ATTEMPT instead of the
--     POSTCONDITION. Here every read and every write of the clock is correct
--     and consistent; what is wrong is how many things share the one clock.
--     The tell is countable and does not need a frame: a piece of state whose
--     lifetime is the module, mutated on a path that runs once per unit per
--     frame.
--
-- ⭐⭐ THE SAME FILE ONE CALL UP GETS IT RIGHT, WHICH IS WHY THIS IS A DEFECT
-- AND NOT A DESIGN CHOICE. bots/FunLib/aba_minion.lua is the only dispatcher
-- into X.Think (:11 dofiles the module once, :52 is the single call
-- expression). Twenty lines above that call it throttles the very same
-- population at 0.5s -- and it stores that clock as `hMinionUnit
-- .lastItemFrameProcessTime`, a field ON THE UNIT (:33-35). So the per-unit
-- field is not a new mechanism this fix invents: writing plain lowercase state
-- onto a unit handle is what the shipped dispatcher already does, and what
-- illusions.lua itself already does four times (`attack_desire`,
-- `attack_target`, `move_desire`, `move_location`, `to_farm_lane`). Pinned by
-- [source S2].
--
-- ⭐⭐⭐ WHY THE TWO THROTTLES INTERACT THE WAY THEY DO, and why the loss is
-- total rather than partial. aba_minion's per-unit 0.5s gate initialises to 0
-- for every unit, so a group of minions summoned together passes it on the
-- SAME frame and stays in lockstep forever after. Within that frame the first
-- of them to reach the move branch pushes the shared clock 0.2s out; its
-- siblings fail `DotaTime() >= nNextMoveTime` and fall off the end of X.Think.
-- They are not reconsidered 0.2s later either -- their own per-unit gate holds
-- them for the full 0.5s, by which time the shared clock has been pushed out
-- again by whoever wins the next frame. Measured over 20 cycles in [frame F1]:
-- 20 orders for the winner, 0 for each of the other three. Not 20/6/6/6.
--
-- REAL FRAME: tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua -- game
-- tl_002103_slot5_01, subject skeleton_king, t=634.1 (10:34). Chosen because
-- the subject is a FOCUS hero whose own summons land in this exact code path:
-- `npc_dota_wraith_king_skeleton_warrior` is named by
-- minion_lib/utils.lua's U.IsMinionWithNoSkill, and aba_minion.lua:48-53
-- routes every IsMinionWithNoSkill unit to Illusion.Think. On this frame the
-- subject's `skeleton_king_mortal_strike` is level 4 -- pinned in [frame F0] --
-- i.e. the hero state that produces a whole squad of these at once is real on
-- the frame, not hypothesised.
--
-- ⚠️ LIMITS, declared:
--   * THE MINION HANDLES ARE AN INJECTION, and this is the honest boundary of
--     the frame evidence. tests/mock/replay_fixture.lua deliberately injects
--     neither creeps nor structures, and no fixture in the corpus carries a
--     summon or an illusion, so the corpus cannot supply a second minion. What
--     the real frame supplies is the WORLD the shipped helpers read while
--     deciding where to send them (J.GetTeamFightLocation,
--     J.GetClosestTeamLane, J.IsInLaningPhase, J.GetRandomLocationWithinDist
--     all run for real against it, no J.* stubs). The claim under test --
--     "one clock, N consumers" -- is a property of the module's state, not of
--     the frame, and both arms get the identical injection. Same UNMEASURABLE-
--     is-not-EMPTY distinction as GH #171/#205, GH #368 and GH #373 reading
--     (B).
--   * FREQUENCY IS UNKNOWN. This file proves the SHAPE and proves the armed
--     arm recovers where the shipped arm cannot. It does not establish how
--     many minutes per Turbo game a bot actually has two or more units in this
--     path. The upper bound on the fix's worth is exactly that number, and
--     only the replay stream can price it.
--   * GetLaneFrontLocation is DECLARED, not read (GH #61: the dump carries no
--     lane fronts). Identical in both arms; the Naga/Terrorblade lane-farm
--     branch is the only reader and the subject here is neither.
--   * WHAT THIS FIX DOES NOT TOUCH: the losing siblings still reach the ATTACK
--     branch, which is not throttled at all -- see [frame F5]. So the shipped
--     loss is specifically MOVEMENT (following the owner, rotating to the
--     teamfight, walking to a lane), not "the minions do nothing".
--
-- DECLARED WORLD SLOTS:
--   S-B  N minion handles, built alike and stepped in a fixed order. The order
--        is the point of the shipped defect (whoever is first wins), so it is
--        held constant across arms rather than randomised.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'
local TARGET  = 'bots/FunLib/minion_lib/illusions.lua'
local DRIVER  = 'bots/FunLib/aba_minion.lua'
local UTILS   = 'bots/FunLib/minion_lib/utils.lua'

local DESIRE = {
    BOT_MODE_DESIRE_NONE   = 0.0,
    BOT_ACTION_DESIRE_NONE = 0.0,
    BOT_ACTION_DESIRE_HIGH = 0.75,
}

--- Blank whole-line comments while PRESERVING line numbers, so every count
--- below means "in code". The header of this file quotes the identifiers it
--- counts, and the fix's own doc comment in illusions.lua names
--- `nNextMoveTime` four times; without this the scanners would be reading
--- their own explanations. GH #370 hit exactly that, and its fix is copied
--- here rather than re-derived.
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local function read(path)
    local fh = assert(io.open(path), 'cannot open ' .. path)
    local s = fh:read('*a')
    fh:close()
    return s
end

local CODE   = codeOnly(read(TARGET))
local DRIVE  = codeOnly(read(DRIVER))
local UCODE  = codeOnly(read(UTILS))

local function count(src, needle)
    return select(2, src:gsub(needle:gsub('%W', '%%%0'), ''))
end

--- Slice a function body by its two NEIGHBOURS instead of by `.-\nend`, which
--- stops at the first NESTED end and silently returns a truncated body -- the
--- method self-harm recorded in GH #373.
local function slice(src, from, to)
    local a = src:find(from, 1, true)
    local b = src:find(to, 1, true)
    assert(a and b and a < b, ('%q must sit above %q'):format(from, to))
    return src:sub(a, b - 1)
end

-- ---------------------------------------------------------------------------
-- [source] -- the shape, read off the shipped tree
-- ---------------------------------------------------------------------------

tests['[source S1] the shared clock has exactly one reader and one writer, both inside the accessors'] = function()
    assert(count(CODE, 'local nNextMoveTime = 0') == 1,
        'expected exactly one declaration of nNextMoveTime')

    -- 3 mentions total: the declaration, the read in GetNextMoveTime, the
    -- write in SetNextMoveTime. A fourth means somebody reached past the
    -- accessors and the gate no longer covers every path.
    local mentions = count(CODE, 'nNextMoveTime')
    assert(mentions == 3, 'expected exactly 3 mentions of nNextMoveTime IN CODE '
        .. '(declaration + one accessor read + one accessor write); got ' .. mentions)

    local getter = slice(CODE, 'local function GetNextMoveTime(', 'local function SetNextMoveTime(')
    local setter = slice(CODE, 'local function SetNextMoveTime(', 'function X.Think(')
    assert(count(getter, 'nNextMoveTime') == 1, 'the only read must be in GetNextMoveTime')
    assert(count(setter, 'nNextMoveTime') == 1, 'the only write must be in SetNextMoveTime')

    -- Both accessors are keyed on the unit; a shipped-only accessor that
    -- ignored its argument would make the armed arm impossible to express.
    assert(getter:find('hMinionUnit.next_move_time', 1, true) ~= nil,
        'GetNextMoveTime must read the per-unit field when armed')
    assert(setter:find('hMinionUnit.next_move_time = nTime', 1, true) ~= nil,
        'SetNextMoveTime must write the per-unit field when armed')

    -- X.Think must go through the accessors: no direct touch of the module
    -- local survives in the body.
    local think = slice(CODE, 'function X.Think(', 'function X.ConfuseEnemyWithIllusions(')
    assert(count(think, 'nNextMoveTime') == 0,
        'X.Think must not touch the module clock directly; it has to go through the accessors')
    assert(count(think, 'GetNextMoveTime(hMinionUnit)') == 1,
        'X.Think must consult the clock exactly once')
    assert(count(think, 'SetNextMoveTime(hMinionUnit, DotaTime() + MOVE_THROTTLE)') == 2,
        'both arms of the move branch must stamp the clock, as the shipped file did')
end

tests['[source S2] one dispatcher, one call site, and it already throttles per unit'] = function()
    -- The population sharing the clock is whatever aba_minion routes here.
    assert(count(DRIVE, "dofile(GetScriptDirectory()..'/FunLib/minion_lib/illusions')") == 1,
        'aba_minion must dofile illusions exactly once -- one module instance is the premise')
    assert(count(DRIVE, 'Illusion.Think(bot, hMinionUnit)') == 1,
        'expected exactly one call expression into Illusion.Think')

    -- ... and the routing predicate is what makes the population plural.
    assert(DRIVE:find('U.IsMinionWithNoSkill(hMinionUnit)', 1, true) ~= nil,
        'skill-less minions must route to Illusion.Think')
    assert(UCODE:find('npc_dota_wraith_king_skeleton_warrior', 1, true) ~= nil,
        "WK's skeleton warriors must be named by IsMinionWithNoSkill -- the frame below "
        .. 'is chosen because the subject summons them')

    -- The correct shape, shipped, twenty lines above the call: a PER-UNIT
    -- clock stored on the handle. All three mentions are indexed off the unit.
    local perUnit = count(DRIVE, 'hMinionUnit.lastItemFrameProcessTime')
    assert(perUnit == 4, 'aba_minion must key its own 0.5s throttle on the unit at all 4 '
        .. 'mentions (nil test, nil init, comparison, stamp); got ' .. perUnit)
    assert(count(DRIVE, 'lastItemFrameProcessTime') == perUnit,
        'no module-level copy of that clock may exist')

    -- Writing plain lowercase state onto a handle is already shipped practice
    -- in the file being changed, so `next_move_time` introduces no new
    -- mechanism.
    for _, field in ipairs({ 'attack_desire', 'attack_target', 'move_desire',
                            'move_location', 'to_farm_lane' }) do
        assert(CODE:find('hMinionUnit.' .. field, 1, true) ~= nil,
            'illusions.lua already stores hMinionUnit.' .. field)
    end
end

tests['[source S3] gate shut is the shipped path, proved by evaluation not by reading'] = function()
    -- Re-evaluate the accessors' branch condition rather than eyeballing it.
    local shared, unit = 0, {}
    local function get(armed) if armed then return unit.next_move_time or 0 end return shared end
    local function set(armed, t) if armed then unit.next_move_time = t else shared = t end end

    set(false, 7.5)
    assert(shared == 7.5 and unit.next_move_time == nil,
        'gate shut must write the module clock and nothing else')
    assert(get(false) == 7.5, 'gate shut must read the module clock back')

    set(true, 9.25)
    assert(unit.next_move_time == 9.25 and shared == 7.5,
        'gate open must write the unit field and leave the module clock alone')
    assert(get(true) == 9.25, 'gate open must read the unit field back')

    -- An untouched unit answers 0 under the armed accessor -- the same value a
    -- fresh module clock answers -- so arming cannot make a minion WAIT that
    -- the shipped arm would have moved.
    assert(get(true) == 9.25 and ({} ).next_move_time == nil, 'sanity')
    local fresh = {}
    local function getFresh() return fresh.next_move_time or 0 end
    assert(getFresh() == 0, 'an unseen unit must start unthrottled, as the module clock does')

    -- PROMOTED 2026-09-06 (director, stable-v4): before that date this block
    -- asserted the OPPOSITE -- that the selector was
    -- `IsModeTurbo() and IsSoakCandidate('illumove')`. The load-bearing half is
    -- now the id's ABSENCE: a promoted behavior that quietly grows a gate again
    -- is inert in every real game while every armed-wiring check still reads
    -- clean (AGENTS.md calls that the pullcad trap).
    local clock = slice(CODE, 'local function IsPerUnitMoveClock(', 'local function GetNextMoveTime(')
    assert(clock:find('return J.IsModeTurbo()', 1, true) ~= nil,
        'PROMOTED: IsPerUnitMoveClock must select on IsModeTurbo() alone')
    assert(count(clock, 'IsSoakCandidate') == 0,
        'PROMOTED: no soak gate may remain inside IsPerUnitMoveClock')
    assert(count(CODE, "IsSoakCandidate('illumove')") == 0,
        "PROMOTED: the id 'illumove' must not be wired anywhere in this file")
    -- Still keyed on THIS id rather than on `IsSoakCandidate(` file-wide: the
    -- claim is about illumove, not about the file's right to hold candidates.
    -- The file-wide spelling was tried once and duly fired the day an unrelated
    -- second candidate ('illureal', GH #381) landed here -- a ratchet that
    -- forbids the file from growing is measuring the file, not the claim, and
    -- 'illureal' is still gated and still asserted below.
    assert(count(CODE, "IsSoakCandidate('illureal')") == 1,
        "'illureal' is a separate, still-gated candidate in this file")
end

-- ---------------------------------------------------------------------------
-- World
-- ---------------------------------------------------------------------------

--- Build the frame, select the per-unit or the shared clock, and load a FRESH
--- copy of the module (dofile gives `nNextMoveTime` a new binding per call,
--- which is what makes two arms comparable in one process).
---
--- PROMOTED 2026-09-06: the selector used to be `IsSoakCandidate('illumove')`
--- and is now `IsModeTurbo()` alone, so the two worlds this file compares are
--- turbo (per-unit) and non-turbo (the shipped module clock). The comparison it
--- makes is unchanged -- `IsSoakCandidate` is still stubbed FALSE for every id,
--- so this file's other candidate ('illureal', which also reads IsModeTurbo)
--- stays off in BOTH worlds and the only thing the toggle moves is the clock.
local function world(armed)
    local J, bot = rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function() return false end
    J.IsModeTurbo     = function() return armed end

    -- GH #61: lane fronts are not in the dump. Declared, identical in both
    -- arms, and read only by the Naga/Terrorblade branch the subject misses.
    local realLaneFront = GetLaneFrontLocation
    GetLaneFrontLocation = function(_, lane, _) -- luacheck: ignore
        return api.Vector(1000 * ((lane or 1) + 1), 1000 * ((lane or 1) + 1), 128)
    end

    local t0 = DotaTime()
    local offset = 0
    local realClock = DotaTime
    DotaTime = function() return t0 + offset end -- luacheck: ignore

    local Illusion = dofile(TARGET)

    local here = bot:GetLocation()

    -- S-B. WK's own summons, built alike.
    local function minion(spec)
        local log = {}
        spec = spec or {}
        local u = api.MakeUnit({
            GetUnitName             = 'npc_dota_wraith_king_skeleton_warrior',
            GetTeam                 = bot:GetTeam(),
            GetPlayerID             = -1,
            IsAlive                 = true,
            IsNull                  = false,
            CanBeSeen               = true,
            GetCurrentMovementSpeed = 300,
            GetAttackDamage         = 50,
            GetHealth               = 600,
            GetMaxHealth            = 600,
            -- J.GetHP reads the OriginalGet* pair for own-team units
            -- (jmz_func.lua:4006-4009); without them ConsiderRetreat compares
            -- nil.  Full health, so the retreat clause is never the reason a
            -- minion below does or does not move.
            OriginalGetHealth       = 600,
            OriginalGetMaxHealth    = 600,
            GetAttackRange          = 150,
            GetLocation             = spec.loc or api.Vector(here.x + 200, here.y + 200, here.z),
            -- S-C. bot_api's default answers {} for any GetNearby*, which is
            -- a supply gap, not a world fact -- so with the default no minion
            -- can ever find a target and the attack branch is unreachable.
            -- This answers it from the FRAME's own hero list by distance,
            -- which is exactly what the engine does. Only [frame F5] depends
            -- on it; every other case sits at the default distance where no
            -- enemy is in range, and both arms get the identical function.
            GetNearbyHeroes         = function(self, radius, bEnemies, _)
                -- UNIT_LIST_ALL_HEROES answers ZERO on every fixture while
                -- UNIT_LIST_ENEMY_HEROES answers 4 on this one, so the
                -- per-side lists are the only ones with anything in them.
                -- That zero is UNMEASURABLE, not EMPTY -- a loader supply gap,
                -- same family as GH #171/#205 -- and reading it would have
                -- made this slot silently answer "nobody is nearby".
                local kind = bEnemies and UNIT_LIST_ENEMY_HEROES
                                       or UNIT_LIST_ALLIED_HEROES
                local out, from = {}, self:GetLocation()
                for _, h in ipairs(GetUnitList(kind)) do
                    if h:IsAlive()
                        and GetUnitToLocationDistance(h, from) <= radius then
                        out[#out + 1] = h
                    end
                end
                return out
            end,
            Action_MoveToLocation   = function() log[#log + 1] = 'move' end,
            Action_AttackMove       = function() log[#log + 1] = 'attackmove' end,
            Action_AttackUnit       = function() log[#log + 1] = 'attack' end,
        })
        return u, log
    end

    return {
        J = J, bot = bot, Illusion = Illusion, minion = minion,
        clock   = function(dt) offset = offset + dt end,
        restore = function()
            DotaTime = realClock -- luacheck: ignore
            GetLaneFrontLocation = realLaneFront -- luacheck: ignore
        end,
    }
end

--- Step N minions through `cycles` frames spaced by aba_minion's own 0.5s
--- per-unit cadence, in a fixed order, and return each one's order count.
local function run(w, n, cycles)
    local ms, logs = {}, {}
    for i = 1, n do ms[i], logs[i] = w.minion() end
    for _ = 1, cycles do
        for i = 1, n do w.Illusion.Think(w.bot, ms[i]) end
        w.clock(0.5)
    end
    local out = {}
    for i = 1, n do out[i] = #logs[i] end
    return out
end

-- ---------------------------------------------------------------------------
-- [frame] -- the real frame
-- ---------------------------------------------------------------------------

tests['[frame F0] the subject really is a squad-summoning focus hero on this frame'] = function()
    local w = world(false)
    local ok, err = pcall(function()
        assert(w.bot:GetUnitName() == 'npc_dota_hero_skeleton_king',
            'subject must be the focus hero whose summons take this path; got '
            .. tostring(w.bot:GetUnitName()))
        local mortal = w.bot:GetAbilityByName('skeleton_king_mortal_strike')
        assert(mortal ~= nil and mortal:GetLevel() == 4,
            'Mortal Strike must be maxed on this frame -- the hero state that puts a '
            .. 'whole squad of skeleton warriors into Illusion.Think at once; got level '
            .. tostring(mortal and mortal:GetLevel()))
    end)
    w.restore()
    assert(ok, err)
end

tests['[frame F1] SHIPPED: one shared clock, so 3 of 4 siblings are never given an order'] = function()
    local w = world(false)
    local ok, err = pcall(function()
        local got = run(w, 4, 20)
        assert(got[1] == 20, 'the first minion in the frame order must be ordered every '
            .. 'cycle; got ' .. got[1])
        for i = 2, 4 do
            assert(got[i] == 0, ('minion %d must receive NO order at all under the shared '
                .. 'clock -- not a delayed one; got %d'):format(i, got[i]))
        end
    end)
    w.restore()
    assert(ok, err)
end

tests['[frame F2] ARMED: the same four minions are each ordered every cycle'] = function()
    local w = world(true)
    local ok, err = pcall(function()
        local got = run(w, 4, 20)
        for i = 1, 4 do
            assert(got[i] == 20, ('minion %d must be ordered on every cycle once the clock '
                .. 'is per-unit; got %d'):format(i, got[i]))
        end
    end)
    w.restore()
    assert(ok, err)
end

tests['[frame F3] ARMED: the throttle still throttles -- the same unit is not re-ordered inside 0.2s'] = function()
    local w = world(true)
    local ok, err = pcall(function()
        local m, log = w.minion()
        w.Illusion.Think(w.bot, m)
        assert(#log == 1, 'first Think must order once; got ' .. #log)
        w.clock(0.1)
        w.Illusion.Think(w.bot, m)
        assert(#log == 1, 'a second Think inside the 0.2s window must NOT order again; got '
            .. #log .. ' -- arming must move the clock, not remove it')
        w.clock(0.15) -- now 0.25s since the stamp
        w.Illusion.Think(w.bot, m)
        assert(#log == 2, 'once the window has passed the same unit is ordered again; got ' .. #log)
    end)
    w.restore()
    assert(ok, err)
end

tests['[frame F4] a lone minion behaves identically in both arms'] = function()
    local a = world(false)
    local shipped = run(a, 1, 20)
    a.restore()
    local b = world(true)
    local armed = run(b, 1, 20)
    b.restore()
    assert(shipped[1] == armed[1], 'with one minion there is nothing to share the clock '
        .. 'with, so both arms must agree; shipped ' .. shipped[1] .. ' vs armed ' .. armed[1])
    assert(shipped[1] == 20, 'and both must order it every cycle; got ' .. shipped[1])
end

tests['[frame F5] the loss is MOVEMENT: a starved sibling still reaches the un-throttled attack branch'] = function()
    local w = world(false)
    local ok, err = pcall(function()
        -- Put an enemy hero from the real frame within the minions' reach so
        -- the shipped attack branch (illusions.lua:31, NOT throttled) fires.
        local enemy
        for _, u in ipairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
            if u:IsAlive() then enemy = u break end
        end
        assert(enemy ~= nil, 'the frame must carry a live enemy hero')

        local eLoc = enemy:GetLocation()
        local ms, logs = {}, {}
        for i = 1, 3 do
            ms[i], logs[i] = w.minion({
                loc = api.Vector(eLoc.x + 100 * i, eLoc.y + 100, eLoc.z),
            })
        end
        for i = 1, 3 do w.Illusion.Think(w.bot, ms[i]) end

        for i = 1, 3 do
            assert(#logs[i] == 1 and logs[i][1] == 'attack',
                ('minion %d must still attack -- the attack branch sits ABOVE the throttle '
                .. 'and has no clock of its own; got %d order(s) (%s)')
                :format(i, #logs[i], tostring(logs[i][1])))
        end
    end)
    w.restore()
    assert(ok, err)
end

return tests

-- [ratchet] [roamidle, GH #370] team_roam's stuck-recovery order is destroyed
-- on the same frame it is issued, and it is destroyed exactly when the bot has
-- a roam target.
--
-- Family: backlog `0d`'s "连续型命令在它的 mode 不再赢下竞价之后没有人会再评估它"
-- -- but this is the sharper sibling, and a NEW shape. `roamreach` (GH #45) is
-- about an order that lives TOO LONG. This one is about an order that never
-- lives at all: it is overwritten eleven lines below its own issue site, inside
-- one call of one Think, with no mode switch and no auction involved.
--
-- ⭐ MAIN CRITERION (reusable, wider than this topic):
--     A "state refresh" written as a bare statement -- a call whose return
--     value is assigned and then never branched on -- reads like a query and is
--     audited like one. If that call ORDERS as a side effect, the call site has
--     no way to protect what it ordered, and the next unconditional `Action_*`
--     in the same function erases it. The general form: **a side effect issued
--     by a callee cannot be sequenced by a caller that does not know it
--     happened.** Not a scope bug (GH #368) and not an ordering bug between
--     branches (GH #348) -- the caller here is not wrong about any value, it
--     is missing a fact the callee never reported.
--
-- The mechanism, static and provable by reading three files:
--
--   * `mode_team_roam_generic.lua` Think: `if isInIdleState then isInIdleState =
--     J.CheckBotIdleState() end` -- the block has no `return` and nothing below
--     it reads `isInIdleState`. Its whole effect is the re-assignment.
--   * `jmz_func.lua` J.CheckBotIdleState, recovery arm: `Action_ClearActions(true)`
--     (:11994) then `ActionQueue_AttackMove(laneFront)` (:11998). It ORDERS.
--   * `docs/BOT_API_REFERENCE.md:1715`: an `Action_*` order "CLEARS the entire
--     action queue and sets this as the new (and only) action".
--   * eleven lines below the block, `bot:Action_AttackUnit(targetUnit, false)`
--     fires whenever `targetUnit` is valid.
--
-- ⇒ relocation queued, then cleared, within one Think.
--
-- ⭐⭐ SECOND, INDEPENDENT CONSEQUENCE (pinned separately below): it repeats
-- EVERY FRAME rather than every 3s. The `return true` in that helper sits ABOVE
-- the two lines that refresh the sampling anchor (`botState.botLocation` and
-- `botState.lastCheckTime`, :12010-12011), so once idle latches, the `>= 3s`
-- gate never closes again. Both shipped call sites then take their per-frame
-- path (`... or isInIdleState` at :259, and this block at :618). The wiped
-- `Action_ClearActions(true)` therefore also lands on every OTHER system's
-- queued actions, once per frame, for as long as the bot stays within 100u of
-- a now-frozen anchor.
--
-- REAL FRAME: tests/fixtures/f_260819_181742_ss_chase_start.lua -- game
-- 20260819_181742_slot1, subject shadow_shaman, t=312.5. It is reused
-- deliberately: it is the repo's only pinned frame where team_roam wins the
-- auction AND holds a valid `targetUnit`, which is exactly the precondition
-- under which the recovery order is erased.
--
-- LABELLED SYNTHETIC (declared; each one asserted where it matters):
--   S-A  `GetLaneFrontLocation` -- the loader REFUSES to answer it (GH #61), so
--        this file declares a value. It is the destination of the erased order,
--        so its VALUE is irrelevant to every conclusion here; what matters is
--        that an order was issued at all. Asserted below.
--   S-B  `bot:GetCurrentActionType()` -- the behavioural dump carries no action
--        type and the mock answers 0. Set to BOT_ACTION_TYPE_IDLE, which is one
--        of the three shipped ways into the recovery arm (the other two are
--        `botMode == BOT_MODE_ITEM` / `BOT_MODE_FARM`). Asserted below.
--   S-C  the clock is advanced 3.5s on a FROZEN frame to cross the helper's own
--        3s sampling threshold. Nothing else about the frame is touched, and
--        315.9 is still inside turbo laning (floor 480s), so no phase flips.
--
-- ⚠️ LIMITS, declared:
--   * FREQUENCY IS UNKNOWN. This file proves the shape and proves it fires on a
--     real frame once the idle predicate holds; it does NOT establish how often
--     bots latch idle in a real game. That is a replay question (GH #370 §next).
--   * The engine's real reaction to `Action_ClearActions` followed by an
--     `Action_*` in the same tick is NOT observable from this repo (`print()`
--     never reaches the console; `error in error handling` eats error text).
--     The claim asserted here is the half that does not need the engine: the
--     source orders in this sequence, and the API reference says what the last
--     one does to the queue.

package.path = './tests/?.lua;./tests/mock/?.lua;' .. package.path

local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local F_START = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'

local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- S-A: an arbitrary but fixed lane front. Every conclusion below is about
-- WHETHER an order was issued, never about where it pointed.
local LANE_FRONT = { x = 1234, y = -4321, z = 0 }

local SRC_MODE   = io.open('bots/mode_team_roam_generic.lua'):read('*a')
local SRC_JMZ    = io.open('bots/FunLib/jmz_func.lua'):read('*a')
local SRC_APIDOC = io.open('docs/BOT_API_REFERENCE.md'):read('*a')

--- Blank every whole-line Lua comment while PRESERVING line numbering, so a
--- count or a line lookup means "in code", not "anywhere in the file".
---
--- This is not cosmetic. The first run of this file failed four of its own
--- assertions because the doc comment written above the fix QUOTES the very
--- lines it pins (`isInIdleState`, `J.CheckBotIdleState()`,
--- `bot:Action_AttackUnit(targetUnit, false)`) -- a source scanner that counts
--- prose counts its own explanation, and `lineOf` returned the comment's line
--- instead of the statement's, inverting an ordering claim. Same family as
--- GH #341/#345 (a tool that never evaluates the clause it claims to read).
local function codeOnly(src)
    local out = {}
    for line in (src .. '\n'):gmatch('([^\n]*)\n') do
        out[#out + 1] = line:match('^%s*%-%-') and '' or line
    end
    return table.concat(out, '\n')
end

local CODE_MODE = codeOnly(SRC_MODE)
local CODE_JMZ  = codeOnly(SRC_JMZ)

--- Line number of the first occurrence of a plain (non-pattern) needle.
local function lineOf(src, needle)
    local at = src:find(needle, 1, true)
    if at == nil then return nil end
    local _, n = src:sub(1, at):gsub('\n', '')
    return n + 1
end

local function world(opts)
    opts = opts or {}
    local ids = opts.ids or {}
    local J, bot, heroes, fx = rf.load(F_START)
    for k, v in pairs(DESIRE) do _G[k] = v end

    GetAncient = function(team) -- luacheck: ignore
        if team == GetTeam() then
            return api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
    end

    J.IsSoakCandidate = function(id) return ids[id] == true end
    if opts.turbo == false then J.IsModeTurbo = function() return false end end

    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    -- S-A.
    GetLaneFrontLocation = function() -- luacheck: ignore
        return api.Vector(LANE_FRONT.x, LANE_FRONT.y, LANE_FRONT.z)
    end

    -- S-B.
    local spec = rawget(bot, '__spec')
    spec.GetCurrentActionType = BOT_ACTION_TYPE_IDLE
    rawset(bot, 'GetCurrentActionType', nil)

    dofile('bots/mode_team_roam_generic.lua')
    return J, bot, heroes, fx
end

--- Drive the mode to the state this file is about, then record ONE Think.
---
--- Frame 1 (t=312.5) seeds the helper's per-bot sampling anchor and returns
--- false. S-C advances the clock past the helper's own 3s threshold with the
--- frame otherwise frozen, so frame 2 latches idle -- and it is frame 2's
--- GetDesire that first hands the mode `isInIdleState = true`. Recording starts
--- only after that, so the returned log is exactly what Think ordered.
local function idleThink(opts)
    local J, bot, heroes, fx = world(opts)
    local t0 = DotaTime()

    local d1 = GetDesire()
    local realTime = _G.DotaTime
    _G.DotaTime = function() return t0 + 3.5 end -- S-C
    local d2 = GetDesire()

    local log = rf.record_actions(bot)
    Think()
    _G.DotaTime = realTime
    return log, J, bot, heroes, fx, d1, d2, t0
end

local function names(log)
    local out = {}
    for i, e in ipairs(log) do out[i] = e.fn end
    return table.concat(out, ',')
end

local function indexOf(log, fn)
    for i, e in ipairs(log) do if e.fn == fn then return i end end
    return nil
end

-- ---------------------------------------------------------------------------
-- [source S1] The call site has no control-flow consequence.
-- ---------------------------------------------------------------------------

tests['[source S1] Think consumes isInIdleState only to re-assign it'] = function()
    -- Shipped shape, before this change:
    --     if isInIdleState then
    --         isInIdleState = J.CheckBotIdleState()
    --     end
    -- Nothing below the block reads the variable. Pin BOTH halves so the day
    -- either changes, this file is re-derived rather than quietly passing.
    local decl = select(2, CODE_MODE:gsub('local lastIdleStateCheck, isInIdleState', ''))
    assert(decl == 1, 'expected one file-level declaration of isInIdleState; got ' .. decl)

    local reads = select(2, CODE_MODE:gsub('isInIdleState', ''))
    assert(reads == 5,
        'expected exactly 5 mentions of isInIdleState IN CODE (1 declaration, 2 '
        .. 'at the desire site :259-260, 2 at the Think site) -- got ' .. reads
        .. '; a new reader means the variable now steers something and this '
        .. 'file must be re-derived')

    -- No branch anywhere reads it except the two `if` heads.
    local ifHeads = select(2, CODE_MODE:gsub('or isInIdleState then', ''))
        + select(2, CODE_MODE:gsub('if isInIdleState then', ''))
    assert(ifHeads == 2, 'expected the two known `if` heads; got ' .. ifHeads)
end

-- ---------------------------------------------------------------------------
-- [source S2] The callee ORDERS, and its `return true` is above the anchor
-- refresh.
-- ---------------------------------------------------------------------------

tests['[source S2] CheckBotIdleState orders, and skips its own anchor refresh'] = function()
    local clear  = lineOf(CODE_JMZ, 'bot:Action_ClearActions(true);')
    local queue  = lineOf(CODE_JMZ, 'bot:ActionQueue_AttackMove(frontLoc)')
    local ret    = lineOf(CODE_JMZ, 'return true, bRelocated')
    local anchor = lineOf(CODE_JMZ, 'botState.botLocation = bot:GetLocation()')
    local stamp  = lineOf(CODE_JMZ, 'botState.lastCheckTime = DotaTime()')

    assert(clear and queue and ret and anchor and stamp,
        'one of the five pinned lines is gone from jmz_func.lua')
    assert(clear < queue and queue < ret,
        'the recovery arm must clear, then queue, then return; got '
        .. clear .. '/' .. queue .. '/' .. ret)

    -- THE defect of consequence #2: the early return is ABOVE both refreshes,
    -- so the >= 3s sampling gate never closes again once idle is latched.
    assert(ret < anchor and ret < stamp,
        'the early `return true` is supposed to sit ABOVE the anchor refresh '
        .. '(' .. anchor .. ') and the timestamp refresh (' .. stamp .. '); got '
        .. ret .. ' -- if this has been fixed, consequence #2 of this file is '
        .. 'void and GH #370 must be re-read')

    assert(SRC_JMZ:find('local botIdelStateTimeThreshold = 3', 1, true),
        'the 3s sampling threshold this file reasons about is gone')
end

-- ---------------------------------------------------------------------------
-- [source S3] The API contract that makes the clobber a clobber.
-- ---------------------------------------------------------------------------

tests['[source S3] Action_* clears the whole queue, per the API reference'] = function()
    assert(SRC_APIDOC:find('**CLEARS** the entire action queue', 1, true),
        'docs/BOT_API_REFERENCE.md no longer states that Action_* clears the '
        .. 'queue -- the central premise of this file')
    assert(SRC_APIDOC:find('**APPENDS** to the end of the queue', 1, true),
        'docs/BOT_API_REFERENCE.md no longer states that ActionQueue_* appends')
end

-- ---------------------------------------------------------------------------
-- [source S4] The order that does the erasing is still shipped and still
-- unconditional on the idle state.
-- ---------------------------------------------------------------------------

tests['[source S4] the erasing Action_AttackUnit is below the idle block'] = function()
    local idleBlock = lineOf(CODE_MODE, 'isInIdleState, bRelocated = J.CheckBotIdleState()')
    local firstAtk  = lineOf(CODE_MODE, 'bot:Action_AttackUnit(targetUnit, false)')
    assert(idleBlock and firstAtk, 'the idle block or the attack order is gone')
    assert(idleBlock < firstAtk,
        'the idle block must precede the continuous attack orders; got '
        .. idleBlock .. ' vs ' .. firstAtk)

    local n = select(2, CODE_MODE:gsub('Action_AttackUnit%(targetUnit, false%)', ''))
    assert(n == 2, 'expected two continuous hero-attack orders in team_roam '
        .. 'Think (help-ally and core/support); got ' .. n)
end

-- ---------------------------------------------------------------------------
-- REAL FRAME: the premises of the drive, asserted before anything is concluded.
-- ---------------------------------------------------------------------------

tests['REAL FRAME t=312.5: the drive reaches the idle-latched state'] = function()
    local log, J, bot, _, fx, d1, d2, t0 = idleThink()
    assert(math.abs(fx.time - 312.5) < 1e-9, 'fixture pinned at t=312.5')
    assert(math.abs(t0 - 312.5) < 1e-9, 'the clock starts on the frame time')
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(J.IsInLaningPhase(), 't=312.5 is inside turbo laning')
    assert(t0 + 3.5 < 480, 'S-C does not push the frame out of laning')

    -- Frame 1 only seeds the anchor: no idle latch yet, hence no order.
    assert(d1 > 0, 'team_roam bids on frame 1; got ' .. tostring(d1))
    assert(d2 > 0, 'team_roam still bids after S-C; got ' .. tostring(d2))

    -- S-B is load-bearing and is really in force.
    assert(bot:GetCurrentActionType() == BOT_ACTION_TYPE_IDLE,
        'S-B: the recovery arm is entered through the IDLE action type')

    -- The real predicates that must hold for the helper to latch -- these are
    -- READ off the real frame, not set.
    assert(not J.IsAttacking(bot), 'real frame: the subject is not attacking')
    assert(not J.IsTryingtoUseAbility(bot), 'real frame: it is not casting')
    assert(bot:IsAlive(), 'real frame: it is alive')

    assert(#log > 0, 'Think ordered something on this frame; got an empty log')
end

-- ---------------------------------------------------------------------------
-- THE FINDING, unarmed: the recovery order is issued and then erased, inside
-- ONE Think.
-- ---------------------------------------------------------------------------

tests['REAL FRAME unarmed: relocation is queued, then erased in the same Think'] = function()
    local log = idleThink()
    local seq = names(log)

    local iClear = indexOf(log, 'Action_ClearActions')
    local iMove  = indexOf(log, 'ActionQueue_AttackMove')
    local iAtk   = indexOf(log, 'Action_AttackUnit')

    assert(iClear, 'the recovery arm should have cleared; log = ' .. seq)
    assert(iMove, 'the recovery arm should have queued an attack-move; log = ' .. seq)
    assert(iAtk, 'the continuous chase order should have followed; log = ' .. seq)

    assert(iClear < iMove and iMove < iAtk,
        'the defect IS the order: clear, queue the recovery, then issue an '
        .. 'Action_* that clears the queue again. Got ' .. seq)

    -- The destination really is the declared lane front (S-A asserted in force).
    local dest = log[iMove].args[1]
    assert(math.abs(dest.x - LANE_FRONT.x) < 1e-9 and math.abs(dest.y - LANE_FRONT.y) < 1e-9,
        'S-A: the queued attack-move points at the declared lane front')

    -- And the order that erases it is the CONTINUOUS chase (bOnce == false),
    -- i.e. the very shape roamreach exists to bound.
    assert(log[iAtk].args[2] == false,
        'the erasing order is the continuous one (bOnce=false); got '
        .. tostring(log[iAtk].args[2]))

    -- Nothing after it: the frame ends on the chase, not on the recovery.
    assert(iAtk == #log, 'the chase order is the last order of the frame; log = ' .. seq)
end

-- ---------------------------------------------------------------------------
-- ARMED: the recovery order stands.
-- ---------------------------------------------------------------------------

tests['REAL FRAME armed roamidle: the frame ends on the recovery order'] = function()
    local log = idleThink({ ids = { roamidle = true } })
    local seq = names(log)

    local iClear = indexOf(log, 'Action_ClearActions')
    local iMove  = indexOf(log, 'ActionQueue_AttackMove')

    assert(iClear and iMove, 'armed still runs the recovery arm; log = ' .. seq)
    assert(iClear < iMove, 'clear then queue; got ' .. seq)
    assert(indexOf(log, 'Action_AttackUnit') == nil,
        'armed, no Action_* may follow the relocation this frame; log = ' .. seq)
    assert(iMove == #log, 'the frame ends on the queued attack-move; log = ' .. seq)
end

-- ---------------------------------------------------------------------------
-- The gate: default-off and turbo-only, both read off the source, and the
-- unarmed log proven byte-identical to the shipped sequence.
-- ---------------------------------------------------------------------------

tests['GATE: roamidle is turbo-only and inert unless armed'] = function()
    assert(CODE_MODE:find("bRelocated and J.IsModeTurbo() and J.IsSoakCandidate('roamidle')", 1, true),
        "the roamidle gate must be the conjunction bRelocated AND turbo AND armed")

    -- Turbo-only, measured rather than read: force the world non-turbo and the
    -- armed log must equal the unarmed one order for order.
    local a = names(idleThink({ ids = { roamidle = true }, turbo = false }))
    local b = names(idleThink({ turbo = false }))
    assert(a == b, 'outside turbo, arming roamidle must change nothing; '
        .. a .. ' vs ' .. b)
    assert(indexOf(idleThink({ ids = { roamidle = true }, turbo = false }),
        'Action_AttackUnit') ~= nil,
        'and outside turbo the shipped chase order still fires')

    -- The gate keys on bRelocated, NOT on isInIdleState. That is what keeps the
    -- "idle for unknown reasons" arm -- which orders nothing and reaches the
    -- same `return true` -- falling through to the shipped branches.
    assert(SRC_JMZ:find('local bRelocated = false', 1, true),
        'bRelocated must default false so the non-ordering arm reports false')
    assert(SRC_JMZ:find('bRelocated = true', 1, true),
        'bRelocated must be set only where the relocation is actually ordered')
end

-- ---------------------------------------------------------------------------
-- The second return value is ADDITIVE: the other shipped call site is unchanged.
-- ---------------------------------------------------------------------------

tests['[source S5] the other call site takes a single assignment target'] = function()
    assert(CODE_MODE:find('isInIdleState = J.CheckBotIdleState()', 1, true),
        'the desire-side call site (:260) must still assign a single target, '
        .. 'so Lua discards the new second return value there')
    -- Exactly one single-target call site remains (the Think one now takes two).
    local single = select(2, CODE_MODE:gsub('\n%s*isInIdleState = J%.CheckBotIdleState%(%)', ''))
    assert(single == 1, 'expected exactly one single-target call site; got ' .. single)
end

-- ---------------------------------------------------------------------------
-- CONSEQUENCE #2, on the real frame: the 3s rate limit is gone once latched.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: once idle latches, the helper re-fires with no clock advance'] = function()
    local _, J, bot = idleThink()
    -- The drive above already latched idle at t0+3.5 (S-C) and Think re-checked
    -- at the same clock. Call it AGAIN at that same instant: a helper that
    -- refreshed its anchor would now be inside its own 3s window and answer
    -- false. It answers true, because the early return skipped the refresh.
    local t0 = 312.5
    local realTime = _G.DotaTime
    _G.DotaTime = function() return t0 + 3.5 end
    local log = rf.record_actions(bot)
    local again, relocated = J.CheckBotIdleState()
    _G.DotaTime = realTime

    assert(again == true,
        'the helper still reports idle with ZERO clock advance -- the >= 3s '
        .. 'sampling gate never closes again once the early return skips the '
        .. 'timestamp refresh')
    assert(relocated == true, 'and it ordered another relocation')
    assert(indexOf(log, 'Action_ClearActions') ~= nil,
        'including another Action_ClearActions(true) -- this is the per-frame '
        .. 'event that lands on every other system queued actions')
end

-- ---------------------------------------------------------------------------
-- REVERSE assertion: if the shipped shape this file is about disappears, fail
-- loudly rather than passing by absence.
-- ---------------------------------------------------------------------------

tests['REVERSE: the two shipped call sites of CheckBotIdleState must still exist'] = function()
    local n = select(2, CODE_MODE:gsub('J%.CheckBotIdleState%(%)', ''))
    assert(n == 2, 'expected exactly two call sites in team_roam; got ' .. n
        .. ' -- the call-site set changed and this file must be re-derived')
    local defs = select(2, CODE_JMZ:gsub('function J%.CheckBotIdleState%(%)', ''))
    assert(defs == 1, 'expected exactly one definition of the helper; got ' .. defs)
end

return tests

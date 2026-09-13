-- ===========================================================================
-- `cmcreepclock` -- the wall clock on X.ConsiderW's two CREEP firing points.
--
-- §0  WHAT THIS LEVER IS
--
--     X.ConsiderW's 先远 / 再近 branches each open with a DISJUNCT:
--
--         <clock> or <this creep is not a basic lane creep>
--
--     so before the clock opens, only NON-basic-lane creeps are eligible.  The
--     shipped clock is `DotaTime() > 10 * 60`; armed (turbo only) it is
--     `DotaTime() > 5 * 60`.  One term moves.
--
-- §0.1  WHY IT IS NOT `cmtfclock`'s LEFTOVERS
--
--     X.cm_IsTeamfightClockOpen's header scopes these two reads out on SHAPE
--     grounds -- disjunct that relaxes a target-class rule, not a conjunct that
--     gates a cast.  That scoping is correct and this file does not touch it.
--     The axis here is different: 10*60 is a NORMAL-MODE constant (GH #157), and
--     a normal-mode constant is wrong in Turbo in either shape.  Two questions
--     about one literal, deliberately not conjoined.
--
-- §0.2  DIRECTION
--
--     WIDENING, by construction: TURBO < SHIPPED, so every t the shipped leg
--     accepts the armed leg accepts too.  Arming can only ADD creep casts, in
--     (5:00, 10:00].  §4 asserts this over the whole corpus instead of arguing it.
--
-- §0.3  LIMITS (each one has an assertion below)
--
--   1. TWO DOMAINS, and the second is ZERO.  GATE-LAYER domain = 15 corpus
--      instants (§1).  END-TO-END domain = 0, STRUCTURALLY: the branch needs a
--      creep UNIT and this corpus has none -- bot:GetNearbyCreeps answers empty
--      on every CM instant (state.json:CORPUS_HAS_NO_NONHERO_UNITS_20260912, the
--      same blocker `cmfarcreep` / `cmrangedhp` / `cmcreepcap` record).  So no
--      corpus frame can show a cast this lever adds and nobody may report one.
--      §3.3 / §3.4 assert the two separately and in that direction.
--   2. ⛔ THE MODE CONJUNCT IS NOT MEASURED HERE AND MUST NOT BE READ AS
--      MEASURED.  The enclosing block's first conjunct is
--      `GetActiveMode() ~= BOT_MODE_LANING` (with RETREAT / ATTACK), and that is
--      the direct measurement the clock is a weaker proxy for -- but
--      GetActiveMode() answers 0 on every corpus hero handle while the BOT_MODE_*
--      constants are 1001-1005, so the conjunct is VACUOUSLY TRUE offline.  That
--      is WORLD ASSERTION 13, already registered
--      (state.json:activemode_WORLD_ASSERTION_13_20260821), NOT rediscovered
--      here; §5.2 pins it so this file's domain wording cannot quietly start
--      claiming the mode term held.
--   3. NOT A FREQUENCY.  A fixture corpus is a set of instants chosen for OTHER
--      investigations.  How often a real Turbo game puts this block's
--      preconditions and a legal creep together in (5:00, 10:00] is a wave
--      question: iterations/queue.json hero-77.
--   4. NOT in this id: whether the branch should carry a clock AT ALL, and
--      whether freezing basic lane creeps is worth the mana.  Halving is the
--      narrow change.
--   5. Every corpus count that is not itself a conclusion is a FLOOR, so a corpus
--      that GROWS may only make these larger and cannot turn this file red for
--      being right (the `-145`/`-149`/`-152` family of same-cause reds was every
--      time a `== N` pin on corpus size).
--
--     lua5.1 tests/run_tests.lua                 # whole suite
--     lua5.1 -e "for n,f in pairs(dofile('tests/test_cm_w_creep_clock.lua')) do f() end"
-- ===========================================================================

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND   = 'cmcreepclock'
local UNIT   = 'npc_dota_hero_crystal_maiden'
local HELPER = 'cm_IsCreepClockOpen'

local FIXTURE_DIR = 'tests/fixtures'
local STAGED_DIR  = 'tests/frames'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
    local body = fh:read('*a')
    fh:close()
    return body
end

--- Comments stripped, so a ratchet counting CODE shapes cannot be satisfied by
--- prose that merely mentions the expression (backlog -149).
local function strip_comments(s)
    return (s:gsub('%-%-[^\n]*', ''))
end

local function fn_body(src, name)
    local from = src:find('function X%.' .. name .. '%s*%(')
    assert(from, 'X.' .. name .. ' not found in ' .. SRC)
    local rest = src:sub(from)
    local to = rest:find('\nfunction X%.')
    return to and rest:sub(1, to) or rest
end

local function count(hay, needle)
    local n, at = 0, 1
    while true do
        local s, e = hay:find(needle, at, true)
        if not s then return n end
        n, at = n + 1, e + 1
    end
end

--- ⭐ THE THRESHOLDS ARE READ OFF THE SOURCE, never re-typed.  A mirror that
--- froze today's 10*60 / 5*60 would keep passing the day the hero file changed
--- them -- the stale-mirror defect tests/test_cast_ring_mirror_discipline.lua
--- exists to catch.
local SRC_TEXT = read_file(SRC)
local SHIPPED = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nWCreepClockShipped%s*=%s*([^\n]+)'),
    'X.nWCreepClockShipped is gone from ' .. SRC)))()
local TURBO = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nWCreepClockTurbo%s*=%s*([^\n]+)'),
    'X.nWCreepClockTurbo is gone from ' .. SRC)))()

local function corpus_paths()
    local out = {}
    for _, dir in ipairs({ FIXTURE_DIR, STAGED_DIR }) do
        local n = 0
        -- UNRESOLVED_HAND_READ: io.popen, registered per GH #596's habit.
        local p = assert(io.popen('ls ' .. dir .. ' 2>/dev/null'))
        for name in p:lines() do
            if name:match('^f_.*%.lua$') then
                out[#out + 1] = dir .. '/' .. name
                n = n + 1
            end
        end
        p:close()
        assert(n > 0, 'corpus directory ' .. dir .. ' yielded no f_*.lua frame')
    end
    table.sort(out)
    return out
end

local function frame_has(path, sUnit)
    local ok, chunk = pcall(dofile, path)
    if not ok or type(chunk) ~= 'table' then return false end
    for _, u in ipairs(chunk.units or {}) do
        if u.name == sUnit and u.alive ~= false then return true end
    end
    return false
end

--- One loaded world.  `opt.armed` arms CAND; `opt.nonTurbo` undoes rf.load's
--- forced turbo AFTER load, exactly as tests/test_cm_w_teamfight_clock.lua does.
local function world(path, opt)
    opt = opt or {}
    local J, bot = rf.load(path, UNIT)
    J.IsSoakCandidate = function(id) return id == CAND and opt.armed == true end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    local X = rf.load_hero('crystal_maiden')
    return J, bot, X
end

--- The enclosing block's non-clock conjuncts, in the shipped order, MINUS the
--- mode test -- see LIMIT 2: offline that test is vacuous, so including it would
--- inflate every count below by pretending a term was checked.
local function block_operands_hold(J, bot)
    return #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0
       and #J.GetNearbyHeroes(bot, 1200, false, BOT_MODE_NONE) < 3
       and bot:GetLevel() >= 5
end

-- ---------------------------------------------------------------- section 1 --
-- THE SUPPLY, counted over the corpus.  Floors only (LIMIT 5).

tests['§1 the corpus supply: 70 CM instants, 32 clear the measurable conjuncts, 15 in the window'] = function()
    local nLive, nOperands, nWindow, nPast = 0, 0, 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            nLive = nLive + 1
            local J, bot = rf.load(path, UNIT)
            local t = DotaTime()
            if block_operands_hold(J, bot) then
                nOperands = nOperands + 1
                if t > TURBO and t <= SHIPPED then
                    nWindow = nWindow + 1
                elseif t > SHIPPED then
                    nPast = nPast + 1
                end
            end
        end
    end
    assert(nLive >= 70, 'live-CM instants fell to ' .. nLive .. ' (floor 70)')
    assert(nOperands >= 32, 'CM instants clearing the block\'s measurable non-clock '
        .. 'conjuncts fell to ' .. nOperands .. ' (floor 32)')
    assert(nPast >= 17, 'CM instants past the shipped clock fell to ' .. nPast
        .. ' (floor 17) -- the comparison that makes the window meaningful')
    -- This one IS the conclusion: the lever's whole locally-checkable domain.
    assert(nWindow >= 15, 'the gate-layer domain fell to ' .. nWindow
        .. ' (floor 15): corpus instants where every conjunct the corpus can '
        .. 'evaluate holds and the clock is the only term refusing')
end

-- ---------------------------------------------------------------- section 2 --
-- The instrument, checked before it is read.

tests['§2 the two thresholds are the source\'s own, and the armed one is the smaller'] = function()
    assert(type(SHIPPED) == 'number' and type(TURBO) == 'number')
    assert(TURBO < SHIPPED, 'the turbo threshold (' .. TURBO .. ') is no longer below '
        .. 'the shipped one (' .. SHIPPED .. ') -- this lever is not a widening any '
        .. 'more and every direction claim in this file is stale')
    assert(SHIPPED == 10 * 60, 'the shipped clock is now ' .. SHIPPED
        .. ', not 10*60 -- §0 and the hero-file header both describe 10*60')
    assert(TURBO == SHIPPED / 2, 'the armed clock is no longer the shipped one '
        .. 'halved -- the header derives 5*60 from this repo\'s stated ~2x Turbo '
        .. 'pace ratio, and that derivation is now stale')
end

-- ---------------------------------------------------------------- section 3 --
-- THE PIN, both legs, on real frames with real clocks.

--- Chosen from §1's window rather than typed in: the pin must be a frame where
--- the shipped leg refuses and the armed leg opens, and it must still be one
--- after a corpus edit.
local function window_frames()
    local out = {}
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local J, bot = rf.load(path, UNIT)
            local t = DotaTime()
            if block_operands_hold(J, bot) and t > TURBO and t <= SHIPPED then
                out[#out + 1] = path
            end
        end
    end
    return out
end

tests['§3.1 on every window frame: shipped refuses on the clock alone, armed opens'] = function()
    local frames = window_frames()
    assert(#frames >= 15, 'the window collapsed to ' .. #frames .. ' frames')
    for _, path in ipairs(frames) do
        local _, _, X = world(path, { armed = false })
        assert(X[HELPER]() == false,
            'the shipped leg does not refuse on ' .. path
            .. ' at t=' .. string.format('%.1f', DotaTime()))
        local _, _, Xa = world(path, { armed = true })
        assert(Xa[HELPER]() == true,
            'the armed leg does not open on ' .. path
            .. ' at t=' .. string.format('%.1f', DotaTime())
            .. ' -- the lever does nothing on a frame inside its own window')
    end
end

tests['§3.2 the gate is turbo-only: armed but non-turbo answers exactly what shipped answers'] = function()
    for _, path in ipairs(window_frames()) do
        local _, _, Xn = world(path, { armed = true, nonTurbo = true })
        local bNonTurbo = Xn[HELPER]()
        local _, _, Xs = world(path, { armed = false, nonTurbo = true })
        assert(bNonTurbo == Xs[HELPER](),
            'non-turbo armed answered ' .. tostring(bNonTurbo) .. ' but the shipped '
            .. 'leg answers ' .. tostring(Xs[HELPER]()) .. ' on ' .. path)
    end
end

tests['§3.3 GATE-LAYER domain is real: the flip is on the clock the branch would have read'] = function()
    local nFlip = 0
    for _, path in ipairs(window_frames()) do
        local _, _, X = world(path, { armed = false })
        local _, _, Xa = world(path, { armed = true })
        if X[HELPER]() == false and Xa[HELPER]() == true then nFlip = nFlip + 1 end
    end
    assert(nFlip >= 15, 'the gate-layer flip count fell to ' .. nFlip .. ' (floor 15)')
end

tests['§3.4 END-TO-END domain is ZERO, structurally: no corpus frame carries a creep unit'] = function()
    local nLive, nWithCreep = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            nLive = nLive + 1
            local _, bot = rf.load(path, UNIT)
            if #bot:GetNearbyCreeps(1400, true) > 0 then nWithCreep = nWithCreep + 1 end
        end
    end
    assert(nLive >= 70)
    -- ⛔ One-way tripwire.  If this ever fires, the END-TO-END domain stopped
    -- being structurally zero and every "0 corpus frames" line in this file and
    -- in the hero-file header has to be re-derived BEFORE it is repeated.
    assert(nWithCreep == 0, nWithCreep .. ' CM instant(s) now carry a creep unit '
        .. 'within 1400.  This file, X.cm_IsCreepClockOpen\'s header and '
        .. 'state.json:CORPUS_HAS_NO_NONHERO_UNITS_20260912 all say the end-to-end '
        .. 'domain is zero BECAUSE the corpus has no creeps -- re-derive it')
end

-- ---------------------------------------------------------------- section 4 --
-- DIRECTION, asserted over the corpus rather than argued.

tests['§4 armed accepts a strict superset of shipped, on every live CM instant'] = function()
    local nShipped, nArmed = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local _, _, X = world(path, { armed = false })
            local bS = X[HELPER]()
            local _, _, Xa = world(path, { armed = true })
            local bA = Xa[HELPER]()
            assert(not (bS and not bA),
                'on ' .. path .. ' the shipped leg opens and the armed leg does '
                .. 'NOT -- arming REMOVED a cast.  This lever is documented '
                .. 'everywhere as a pure widening; that claim is now false')
            if bS then nShipped = nShipped + 1 end
            if bA then nArmed = nArmed + 1 end
        end
    end
    assert(nArmed > nShipped, 'the armed leg opens on ' .. nArmed .. ' instants and '
        .. 'the shipped leg on ' .. nShipped .. ' -- the superset is not STRICT, so '
        .. 'the lever is a no-op on this corpus and §1\'s domain is wrong')
end

-- ---------------------------------------------------------------- section 5 --
-- Gate discipline, and the one premise this file borrows instead of measuring.

tests['§5.1 the helper is standalone: exactly one soak call, naming only its own id'] = function()
    local body = fn_body(strip_comments(SRC_TEXT), HELPER)
    assert(count(body, 'J.IsSoakCandidate') == 1,
        'X.' .. HELPER .. ' now holds ' .. count(body, 'J.IsSoakCandidate')
        .. ' soak calls, not 1 -- a gate-inside-a-gate makes single-arm readings '
        .. 'unattributable (the `pullcad` lesson)')
    assert(count(body, "'" .. CAND .. "'") == 1,
        'X.' .. HELPER .. ' no longer names exactly its own id ' .. CAND)
    assert(count(body, 'J.IsModeTurbo') == 1,
        'X.' .. HELPER .. ' lost its turbo conjunct -- the lever would fire in '
        .. 'normal mode, which no argument here covers')
end

tests['§5.2 gate off, the helper IS the shipped expression -- byte for byte'] = function()
    local body = fn_body(strip_comments(SRC_TEXT), HELPER)
    assert(count(body, 'return DotaTime() > X.nWCreepClockShipped') == 1,
        'the unarmed return is no longer `DotaTime() > X.nWCreepClockShipped`.  '
        .. 'Both call sites carry a comment claiming gate-off equivalence byte for '
        .. 'byte; that claim is now unbacked')
    local w = fn_body(strip_comments(SRC_TEXT), 'ConsiderW')
    assert(count(w, 'X.' .. HELPER .. '()') == 2,
        'X.ConsiderW calls X.' .. HELPER .. ' ' .. count(w, 'X.' .. HELPER .. '()')
        .. ' time(s), not 2 -- this lever is defined as moving exactly the two '
        .. 'creep-branch disjuncts')
    assert(count(w, 'DotaTime()') == 0,
        'X.ConsiderW grew a bare DotaTime() read back.  Every clock question in '
        .. 'that function goes through a named helper; a bare one is outside every '
        .. 'lever and outside every census')
end

--- ⛔ LIMIT 2, pinned rather than trusted.  The header's "the block already
--- measures laning directly" paragraph is read off the SOURCE.  Offline it is
--- unmeasurable, and this assertion is what stops a later reader from promoting
--- that paragraph into a frame-backed claim.  It restates WORLD ASSERTION 13
--- (state.json:activemode_WORLD_ASSERTION_13_20260821) at this lever's own call
--- site; it does not re-discover it.
tests['§5.3 the mode conjunct is vacuous offline, so no count here may claim it held'] = function()
    local nSeen, nZero = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local _, bot = rf.load(path, UNIT)
            local m = bot:GetActiveMode()
            nSeen = nSeen + 1
            if m == 0 then nZero = nZero + 1 end
        end
    end
    assert(nSeen >= 70)
    assert(nZero == nSeen, 'GetActiveMode() now answers something other than 0 on '
        .. (nSeen - nZero) .. ' of ' .. nSeen .. ' CM instants.  World assertion 13 '
        .. 'has been lifted -- the mode conjunct may now be MEASURED, and §1 should '
        .. 'be re-derived WITH it instead of documenting it as unmeasurable')
    assert(BOT_MODE_LANING ~= 0 and BOT_MODE_RETREAT ~= 0 and BOT_MODE_ATTACK ~= 0,
        'one of the three refused modes is now 0, which is what GetActiveMode() '
        .. 'answers everywhere -- the mode conjunct just stopped being vacuously '
        .. 'TRUE and became vacuously FALSE.  Every domain count here is stale')
end

return tests

-- [hero] `cmtfclock` -- X.ConsiderW's TEAMFIGHT firing point is the only one of
-- its eight HERO-target firing points that carries a wall clock, and it is the
-- one whose own precondition is the strongest evidence that a cast is warranted.
--
-- ===========================================================================
-- §0  WHAT IS WRONG
-- ===========================================================================
--
-- bots/BotLib/hero_crystal_maiden.lua X.ConsiderW, as shipped:
--
--     if J.IsInTeamFight( bot, 1200 )        <- the DIRECT measurement
--         and DotaTime() > 6 * 60            <- a PROXY for the same thing
--     then ... pick the most dangerous enemy in the ring and Frostbite him
--
-- Seven sibling HERO-target firing points in the same function carry no clock
-- at all -- including the 对线期消耗 lane harass, which is the smallest payoff
-- in the function and the one `cmlaneband` had to put a reach term on.  So a
-- harass may fire at 0:30 while a real five-hero fight is refused until 6:00.
-- The curfew is INVERTED with respect to the evidence.
--
-- ⚠️ "HERO-target" is load-bearing, and §5.1 is why it is there: it caught this
-- header's first draft claiming the teamfight branch was the function's ONLY
-- wall clock.  The two CREEP branches read DotaTime() too, as DISJUNCTS
-- (`> 10 * 60 or <not a basic lane creep>`) that RELAX a target-class rule with
-- time instead of gating a cast.  Opposite shape; not in this lever.
--
-- ⛔ AND IT IS NOT A MANA POLICY.  X.ConsiderW's only entry guard is
-- `abilityW:IsFullyCastable()` and no firing point in it carries a mana reserve
-- (§5 counts that rather than asserting it here).  A mana policy would live on
-- the function, not on one branch of it.
--
-- 6 minutes is a NORMAL-MODE constant.  This project optimizes Turbo
-- (docs/PROJECT.md), where games run ~20 minutes against ~35-40, so the curfew
-- costs roughly 30% of the game and it costs the first 30% -- which in Turbo is
-- not a farming phase: doubled XP/gold and halved respawns mean five-hero
-- fights genuinely happen before 6:00.  Armed the threshold is halved to 3:00,
-- which is the shipped number scaled by this repo's own stated pace ratio.
--
-- ===========================================================================
-- §0.1  DIRECTION -- THIS IS A WIDENING, and that is the first thing to know
-- ===========================================================================
--
-- Every t past 6:00 is also past 3:00, so armed is a strict SUPERSET of
-- shipped: arming can only ADD teamfight casts, inside (3:00, 6:00], and can
-- never remove or move one.  §4 drives that over the whole corpus rather than
-- arguing it.  A negative wave reading is attributable to "those early-fight
-- Frostbites were not worth casting" and NEVER to a cast this lever refused.
--
-- ===========================================================================
-- §0.2  REPRODUCE
-- ===========================================================================
--
--     lua5.1 tests/run_tests.lua                 # whole suite
--     lua5.1 -e "for n,f in pairs(dofile('tests/test_cm_w_teamfight_clock.lua')) do f() end"
--
-- ===========================================================================
-- §0.3  LIMITS (each one has an assertion below)
-- ===========================================================================
--
--   1. TWO DOMAINS, and they are different numbers.  GATE-LAYER domain = 1
--      corpus frame (the clock is the only thing refusing).  END-TO-END domain
--      = 0 corpus frames -- on that same frame Frostbite is on cooldown, so
--      X.ConsiderW returns NONE at its first line and the branch is never
--      evaluated there.  Conflating the two is an execution verification out of
--      thin air.  §3.3 and §3.4 assert them separately and in that direction.
--   2. NOT A FREQUENCY.  5 of 70 CM instants have a teamfight running, 15 sit
--      in the window, exactly 1 is both.  A fixture corpus is a set of instants
--      chosen for OTHER investigations; how often a real Turbo game puts a fight
--      in (3:00, 6:00] is a wave question (iterations/queue.json hero-61).
--   3. NOT in this id: whether the branch should carry a clock AT ALL.  Halving
--      is the narrow change; removing it is a second question and conjoining
--      the two would make one wave reading unattributable to either.
--   4. Every corpus count below that is not itself a conclusion is a FLOOR, so a
--      corpus that GROWS may only make these larger and cannot turn this file
--      red for being right (the `-145`/`-149`/`-152` family of same-cause reds
--      was every time a `== N` pin on corpus size).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local SRC    = 'bots/BotLib/hero_crystal_maiden.lua'
local CAND   = 'cmtfclock'
local UNIT   = 'npc_dota_hero_crystal_maiden'
local HELPER = 'cm_IsTeamfightClockOpen'
local PIN    = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'

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
--- froze today's 6*60 / 3*60 would keep passing the day the hero file changed
--- them, which is the stale-mirror defect tests/test_cast_ring_mirror_discipline
--- .lua exists to catch.
local SRC_TEXT = read_file(SRC)
local SHIPPED = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nWTeamfightClockShipped%s*=%s*([^\n]+)'),
    'X.nWTeamfightClockShipped is gone from ' .. SRC)))()
local TURBO = assert(loadstring('return ' .. assert(
    SRC_TEXT:match('X%.nWTeamfightClockTurbo%s*=%s*([^\n]+)'),
    'X.nWTeamfightClockTurbo is gone from ' .. SRC)))()

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
--- forced turbo AFTER load, exactly as tests/test_cm_w_selfdefense_facing.lua does.
local function world(path, opt)
    opt = opt or {}
    local J, bot = rf.load(path or PIN, UNIT)
    J.IsSoakCandidate = function(id) return id == CAND and opt.armed == true end
    if opt.nonTurbo then GetGameMode = function() return 1 end end
    local X = rf.load_hero('crystal_maiden')
    return J, bot, X
end

--- The aether term is NOT optional in a cast-ring mirror: dropping it
--- under-states Frostbite's ring by 225-250 units and reads legal casts as out
--- of range (GH #725; the census is tests/test_cast_ring_mirror_discipline.lua).
local AETHER_BONUS = tonumber(
    SRC_TEXT:match('aetherRange = J%.GetAetherLensRangeBonus%( aether, (%d+) %)'))
assert(AETHER_BONUS ~= nil,
    'X.SkillsComplement no longer computes aetherRange as '
    .. 'J.GetAetherLensRangeBonus( aether, <n> ) -- this file\'s ring mirror is stale')

local function aether_range(bot)
    if bot.FindItemSlot == nil then return 0 end
    local nSlot = bot:FindItemSlot('item_aether_lens')
    if nSlot ~= nil and nSlot >= 0 then return AETHER_BONUS end
    return 0
end

local function ring(J, bot)
    local hAb = bot:GetAbilityByName('crystal_maiden_frostbite')
    local nAetherRange = aether_range(bot)
    local nCastRange = (hAb and hAb:GetCastRange() or 0) + 30 + nAetherRange
    return J.GetNearbyHeroes(bot, nCastRange, true, BOT_MODE_NONE)
end

--- The teamfight branch's own per-candidate chain, in the shipped order.  Used
--- only to say "the branch had something to cast on", never to pick a target.
local function legal_in_ring(J, bot)
    local n = 0
    for _, e in ipairs(ring(J, bot)) do
        if J.IsValid(e)
            and J.CanCastOnNonMagicImmune(e)
            and J.CanCastOnTargetAdvanced(e)
            and not J.IsDisabled(e)
            and not e:IsDisarmed()
        then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------- section 1 --
-- THE SUPPLY, counted over the corpus.  Floors only (limit 4).

tests['§1 the corpus supply: 70 CM instants, 5 with a teamfight, 15 in the window, 1 both'] = function()
    local nLive, nTF, nWindow, nBoth = 0, 0, 0, 0
    local sBoth = nil
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            nLive = nLive + 1
            local J, bot = rf.load(path, UNIT)
            local t = DotaTime()
            local bTF = J.IsInTeamFight(bot, 1200)
            local bWin = (t > TURBO and t <= SHIPPED)
            if bTF then nTF = nTF + 1 end
            if bWin then nWindow = nWindow + 1 end
            if bTF and bWin then
                nBoth = nBoth + 1
                sBoth = path
            end
        end
    end
    assert(nLive >= 70, 'live-CM instants fell to ' .. nLive .. ' (floor 70)')
    assert(nTF >= 5, 'CM instants with a teamfight running fell to ' .. nTF .. ' (floor 5)')
    assert(nWindow >= 15, 'CM instants inside (' .. TURBO .. ', ' .. SHIPPED
        .. '] fell to ' .. nWindow .. ' (floor 15)')
    -- This one IS the conclusion: the lever's whole locally-checkable domain.
    assert(nBoth >= 1, 'no corpus frame has a teamfight running inside the window '
        .. 'this lever opens -- the lever has no local domain left')
    assert(sBoth == PIN or nBoth > 1,
        'the single qualifying frame moved: ' .. tostring(sBoth)
        .. ' (this file reads ' .. PIN .. ')')
end

-- ---------------------------------------------------------------- section 2 --
-- The instrument, checked before it is read.

tests['§2 the pin frame really carries the clock and the teamfight, with nothing injected'] = function()
    local J, bot = rf.load(PIN, UNIT)
    local t = DotaTime()
    assert(t > TURBO and t <= SHIPPED,
        PIN .. ' is at t=' .. string.format('%.1f', t) .. ', which is no longer inside ('
        .. TURBO .. ', ' .. SHIPPED .. '] -- the pin is stale')
    assert(J.IsInTeamFight(bot, 1200),
        'J.IsInTeamFight( bot, 1200 ) is false on ' .. PIN
        .. ' -- the branch\'s first conjunct no longer holds and §3 reads nothing')
    assert(legal_in_ring(J, bot) >= 1,
        'no enemy in Frostbite\'s real ring clears the branch chain on ' .. PIN
        .. ' -- the branch would find no target even with the clock open')
end

tests['§2.1 the two thresholds are the source\'s own, and the armed one is the smaller'] = function()
    assert(type(SHIPPED) == 'number' and type(TURBO) == 'number')
    assert(TURBO < SHIPPED, 'the turbo threshold (' .. TURBO .. ') is no longer below '
        .. 'the shipped one (' .. SHIPPED .. ') -- this lever is not a widening any more '
        .. 'and every direction claim in this file is stale')
    assert(SHIPPED == 6 * 60, 'the shipped clock is now ' .. SHIPPED
        .. ', not 6*60 -- §0 and the hero-file header both describe 6*60')
end

-- ---------------------------------------------------------------- section 3 --
-- THE PIN, both legs, on the real frame.

tests['§3.1 shipped refuses on the clock alone; armed opens'] = function()
    local _, _, X = world(PIN, { armed = false })
    assert(X[HELPER]() == false,
        'the shipped leg no longer refuses at t=' .. string.format('%.1f', DotaTime()))
    local _, _, Xa = world(PIN, { armed = true })
    assert(Xa[HELPER]() == true,
        'the armed leg does not open at t=' .. string.format('%.1f', DotaTime())
        .. ' -- the lever does nothing on its own pin frame')
end

tests['§3.2 the gate is turbo-only: armed but non-turbo answers exactly what shipped answers'] = function()
    local _, _, Xn = world(PIN, { armed = true, nonTurbo = true })
    local bNonTurbo = Xn[HELPER]()
    local _, _, Xs = world(PIN, { armed = false, nonTurbo = true })
    assert(bNonTurbo == Xs[HELPER](),
        'non-turbo armed answered ' .. tostring(bNonTurbo)
        .. ' but the shipped leg answers ' .. tostring(Xs[HELPER]()))
end

tests['§3.3 limit 1, gate layer: the clock is the ONLY thing refusing on the pin frame'] = function()
    local J, bot, X = world(PIN, { armed = false })
    assert(J.IsInTeamFight(bot, 1200), 'first conjunct gone -- see §2')
    assert(legal_in_ring(J, bot) >= 1, 'no legal target -- see §2')
    assert(X[HELPER]() == false, 'the clock no longer refuses -- see §3.1')
    -- i.e. with the clock open the branch is entered and finds a target; the
    -- refusal is attributable to the clock and to nothing else on this frame.
end

tests['§3.4 limit 1, end to end: the branch is NOT reachable on the pin frame, and that is registered'] = function()
    local _, bot = rf.load(PIN, UNIT)
    local hAb = bot:GetAbilityByName('crystal_maiden_frostbite')
    assert(hAb ~= nil, 'Frostbite is not on the pin frame at all')
    assert(hAb:IsFullyCastable() == false,
        'Frostbite is castable on ' .. PIN .. ' now -- the END-TO-END domain has '
        .. 'become non-zero.  That is good news, not a defect: re-read §0.3 limit 1 '
        .. 'and re-anchor it, because this file currently claims 0.')
end

-- ---------------------------------------------------------------- section 4 --
-- DIRECTION, driven over the whole corpus rather than argued.

tests['§4 armed is a strict superset of shipped on every corpus frame -- never the reverse'] = function()
    local nChecked, nWider = 0, 0
    for _, path in ipairs(corpus_paths()) do
        if frame_has(path, UNIT) then
            local _, _, Xs = world(path, { armed = false })
            local _, _, Xa = world(path, { armed = true })
            local bShipped, bArmed = Xs[HELPER](), Xa[HELPER]()
            assert(not (bShipped and not bArmed),
                path .. ': shipped opens the clock and armed closes it -- this lever '
                .. 'is supposed to be a WIDENING and it just removed a cast')
            if bArmed and not bShipped then nWider = nWider + 1 end
            nChecked = nChecked + 1
        end
    end
    assert(nChecked >= 70, 'only ' .. nChecked .. ' CM frames drove §4 (floor 70)')
    assert(nWider >= 1, 'armed and shipped agree on every corpus frame -- §4 proved '
        .. 'the direction vacuously and the lever has no domain')
end

-- ---------------------------------------------------------------- section 5 --
-- The two claims the header makes about the SHIPPED function, asserted rather
-- than restated.

--- ⭐ WRITTEN AFTER THIS ASSERTION CAUGHT THE FIRST DRAFT OF THIS FILE'S OWN
--- HEADER.  The draft said "exactly one firing point carries a wall clock".
--- X.ConsiderW reads DotaTime() twice MORE than the teamfight branch did, and
--- the honest claim is narrower: the teamfight branch was the only HERO-target
--- firing point with a clock.  The other two readings are on the CREEP branches
--- (先远 / 再近) and they are not curfews at all -- each is a DISJUNCT,
--- `DotaTime() > 10 * 60 or <this creep is not a basic lane creep>`, so time
--- RELAXES a target-class rule there instead of gating a cast.  Opposite shape,
--- different target class, not in this lever.
tests['§5.1 the teamfight branch was the only HERO-target firing point with a wall clock'] = function()
    local w = fn_body(strip_comments(SRC_TEXT), 'ConsiderW')
    local n = count(w, 'DotaTime()')
    assert(n == 2, 'X.ConsiderW now reads DotaTime() directly ' .. n
        .. ' time(s), not 2.  The two that belong there are the creep branches\' '
        .. '`DotaTime() > 10 * 60 or <not a basic lane creep>` disjuncts; the '
        .. 'teamfight clock moved into X.' .. HELPER .. '.  Any other reading means '
        .. 'a firing point grew its own curfew and this file\'s census is stale')
    local nRelax = count(w, 'DotaTime() > 10 * 60')
    assert(nRelax == 2, 'the two creep-branch time DISJUNCTS are no longer '
        .. '`DotaTime() > 10 * 60` (' .. nRelax .. ' found).  They are the reason '
        .. 'the count above is 2 rather than 0; if they changed shape, re-derive '
        .. 'the census before trusting the header')
end

tests['§5.2 X.ConsiderW still carries no mana reserve -- so the clock was never a mana policy'] = function()
    local w = fn_body(strip_comments(SRC_TEXT), 'ConsiderW')
    assert(count(w, 'J.GetManaAfter') == 0 and count(w, 'ShouldConserveMana') == 0,
        'X.ConsiderW now carries a mana reserve.  The header argues the 6-minute '
        .. 'clock cannot be read as a mana policy BECAUSE the function has none; '
        .. 're-read that paragraph before trusting it')
end

-- ---------------------------------------------------------------- section 6 --
-- Gate discipline.

tests['§6.1 the helper is standalone: exactly one soak call, naming only its own id'] = function()
    local body = fn_body(strip_comments(SRC_TEXT), HELPER)
    assert(count(body, 'J.IsSoakCandidate') == 1,
        'X.' .. HELPER .. ' must hold exactly one J.IsSoakCandidate call')
    assert(count(body, "'" .. CAND .. "'") == 1,
        'X.' .. HELPER .. ' must name ' .. CAND .. ' exactly once')
    -- The `pullcad` trap: a gate whose own condition names a SECOND soak id is
    -- frozen FALSE the day either id is promoted.
    for id in body:gmatch("IsSoakCandidate%(%s*'([%w_]+)'") do
        assert(id == CAND, 'X.' .. HELPER .. ' names a second soak id (' .. id
            .. ') inside its own gate')
    end
    assert(count(body, 'J.IsModeTurbo()') == 1,
        'X.' .. HELPER .. ' must be turbo-only')
end

tests['§6.2 the call site consumes the helper exactly once, and the inline clock is gone'] = function()
    local w = fn_body(strip_comments(SRC_TEXT), 'ConsiderW')
    assert(count(w, 'X.' .. HELPER .. '()') == 1,
        'X.ConsiderW must consume X.' .. HELPER .. ' exactly once')
    assert(count(w, '6 * 60') == 0,
        'X.ConsiderW still carries an inline copy of the shipped clock -- the two '
        .. 'can drift apart again')
end

return tests

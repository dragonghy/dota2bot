-- [blinkflee / GH #71] Blink Dagger burned as a retreat "leg".
--
-- The retreat branch of X.ConsiderItemDesire['item_blink']
-- (bots/ability_item_usage_generic.lua) is documented in the issue: it fires
-- HIGH toward the ancient on the sole signals of IsRetreating + at least one
-- enemy in 1200, regardless of how much HP the bot has left or whether any
-- enemy is actually pressing. On 20260820_043124_slot1 (Axe, ARMED side)
-- two of the five real blink casts landed +0.99 aligned with the ancient
-- direction at 84% / 81% HP with the offensive branch structurally blocked
-- (SK inside 500) -- the two real frames pinned in the fixtures below.
--
-- What is under test here is the guard `J.ShouldHoldBlinkFlee`, wired into
-- the retreat branch. Deliberately narrow: it holds the blink only when
-- turbo + 'blinkflee' armed AND HP >= 70% AND no hero has damaged the bot
-- in the last 2.0s. Both frames pass that AND -- the retreat mode's own
-- movement still carries the bot toward ancient at ~355 ms with the 15s CD
-- kept in reserve for the next real initiation.
--
-- Test surface (mirrors the axeblink guard, GH #56):
--   * unit test J.ShouldHoldBlinkFlee on both real frames, gate off/on,
--     and each individual clause mutated to prove it is the guard;
--   * source tripwire that the guard is wired inside the retreat branch,
--     on the path that returns BOT_ACTION_DESIRE_HIGH (director's #0b:
--     a helper that is right but unreachable is worth nothing).

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FLEE_529 = 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua'
local FLEE_555 = 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua'

local tests = {}

--- Load a fixture with (turbo, gate) freely armed via the returned J.
local function load_fx(path, opts)
    opts = opts or {}
    local J, bot = rf.load(path)
    J.IsModeTurbo = function() return opts.turbo == true end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == 'blinkflee'
    end
    return J, bot
end

-- ---------------------------------------------------------------------------
-- Real frame 1: t=529.6, Axe HP 1384/1644 (84.2%), SK@339, ES@173 (ally),
-- recent hero damage 3.2/4.2/5.2s ago (all SK, all 15) -- 0 in the 2.0s
-- window the guard reads.

tests['t=529.6, gate OFF: the guard is inert (never holds)'] = function()
    local J, bot = load_fx(FLEE_529, { turbo = true, armed = false })
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'gate not armed -> shipped behaviour, guard must be a no-op')
end

tests['t=529.6, non-turbo: the guard is inert'] = function()
    local J, bot = load_fx(FLEE_529, { turbo = false, armed = true })
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'turbo-only gate, so a normal-mode game must see shipped behaviour')
end

tests['t=529.6, gate ON: healthy + not under active fire -> HOLD'] = function()
    local J, bot = load_fx(FLEE_529, { turbo = true, armed = true })
    -- Baseline sanity: this frame really is the one described in GH #71.
    assert(math.abs(bot:GetHealth() / bot:GetMaxHealth() - 0.842) < 0.01,
        'Axe HP is 84.2% on this frame')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'and no hero has touched him in the last 2.0s (last SK tick was 3.2s ago)')
    assert(J.ShouldHoldBlinkFlee(bot) == true,
        'healthy + not being pressed: hold the dagger for a real initiation')
end

tests['t=529.6, gate ON, mutate HP under 70%: guard releases'] = function()
    local J, bot = load_fx(FLEE_529, { turbo = true, armed = true })
    -- A genuinely wounded bot keeps its retreat option -- the guard is not a
    -- "never blink to retreat", it is a "do not spend a 15s CD when you are
    -- fine". Mutation reads the shipped Get* so it survives the null-check.
    rawget(bot, '__spec').GetHealth = math.floor(bot:GetMaxHealth() * 0.60 + 0.5)
    rawset(bot, 'GetHealth', nil)
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.70, 'sanity: 60% < 70%')
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'below the HP floor the guard must let the retreat blink through')
end

tests['t=529.6, gate ON, mutate: recent hero damage releases the guard'] = function()
    local J, bot = load_fx(FLEE_529, { turbo = true, armed = true })
    -- Rebase the SK ticks from 3.2/4.2/5.2s ago into the 2.0s window: they
    -- are the same hits, they just landed a moment later, and now the guard
    -- sees the retreat as pressure it should not veto.
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function(_, f)
        return (tonumber(f) or 0) >= 1.5
    end
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'sanity: the mutation put a hero hit inside the 2.0s window')
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'a hero is actively pressing him -- the blink is a legitimate escape')
end

-- Same guard clauses on the second real frame -- the ones the mutations in
-- frame 1 rely on ("bring HP down / bring a fresh hero hit in") both hold
-- naturally here too, so the base decision has to match.

tests['t=555.2, gate ON: healthy + creep-only chip -> HOLD'] = function()
    local J, bot = load_fx(FLEE_555, { turbo = true, armed = true })
    assert(math.abs(bot:GetHealth() / bot:GetMaxHealth() - 0.813) < 0.01,
        'Axe HP is 81.3% on this frame')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'and only a creep chipped him 2.5s ago -- no hero pressure at all')
    assert(J.ShouldHoldBlinkFlee(bot) == true,
        '81% HP with a creep tick is not what a 15s CD blink is for')
end

tests['t=555.2, gate OFF: shipped behaviour'] = function()
    local J, bot = load_fx(FLEE_555, { turbo = true, armed = false })
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'gate not armed -> the shipped retreat blink still fires here')
end

-- ---------------------------------------------------------------------------
-- Wiring tripwire: the guard has to sit ON the retreat branch's HIGH return.
-- Copied from tests/test_replay_222428_axe_blink_call.lua (director's #0b
-- lesson: an unreachable helper is worth nothing).

tests['wiring: ShouldHoldBlinkFlee gates the retreat HIGH return'] = function()
    local f = assert(io.open('bots/ability_item_usage_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local branch = src:match('X%.ConsiderItemDesire%["item_blink"%].-\n end')
        or src:match('X%.ConsiderItemDesire%["item_blink"%].-\nend')
    assert(branch, 'could not locate the item_blink consider function')
    local guarded = branch:match(
        'and not J%.ShouldHoldBlinkFlee%(bot%)%s*\n%s*then%s*\n%s*return BOT_ACTION_DESIRE_HIGH')
    assert(guarded, 'the blinkflee guard must gate the retreat blink HIGH return')
    -- And it must be the RETREAT branch, not the offensive one -- the offensive
    -- branch is what the 'axeblink' guard already covers.
    local retreat_at = branch:find('J.IsRetreating(bot)', 1, true)
    local guard_at   = branch:find('ShouldHoldBlinkFlee', 1, true)
    assert(retreat_at ~= nil and guard_at ~= nil and retreat_at < guard_at,
        'the guard must sit inside the IsRetreating branch, not the offensive one')
end

return tests

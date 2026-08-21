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
-- GH #74 §5, replay-check 2026-08-21T09:00Z: the missing half of the pin set.
local INIT_573 = 'tests/fixtures/f_260820_042612_axe_blink_init_573.lua'

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
-- Real frame 3 (GH #74 §5): 20260820_042612_slot1 t=573.0, seed 887,
-- armed=radiant, Axe on the armed side. The two frames above are both HOLDs,
-- and so is every other HOLD-qualified frame the archive has: replay-check's
-- 09:00Z sweep of the 0411xx wave found 5 real retreat legs and `HOLD` on 5/5.
-- The FALSE direction was therefore only ever exercised by MUTATING a real
-- frame (t=529.6's "mutate HP under 70%") -- a synthetic number standing in for
-- a state no fixture had.
--
-- This frame is that state, for real, and it is the interesting kind:
--
--   * Axe at 518/1556 = 33.3% HP -- far under the 70% floor;
--   * NO hero has touched him for at least 6.0s (the fixture carries no
--     recent_damage row for the subject at all), so the second clause is NOT
--     what releases the guard. The HP floor is the sole deciding clause -- the
--     first time that is true on a real frame rather than under a mutation;
--   * juggernaut is 648 away, i.e. the retreat branch's own prerequisite
--     (`#nInRangeEnemy >= 1` inside 1200) is SATISFIED. That is what separates
--     this frame from the earthshaker PASS frame in
--     tests/test_replay_260820_es_blink_flee.lua, where 1200 was empty and the
--     prerequisite -- not the guard -- did the work.
--
-- Ground truth (replay, not inference): this blink was an OFFENSIVE leg,
-- cos(toward own ancient) = -0.999, 569u, landing 183u from a 46%-HP
-- juggernaut -- and Axe KILLED him 2.9s later (DEATH axe -> juggernaut at
-- t=576.1) while never dropping below 28% HP. Releasing was right. The guard
-- must not be the thing that stops a wounded Axe from taking a kill blink.

tests['t=573.0, gate ON: 33% HP -> the guard RELEASES'] = function()
    local J, bot = load_fx(INIT_573, { turbo = true, armed = true })
    assert(math.abs(bot:GetHealth() / bot:GetMaxHealth() - 0.333) < 0.01,
        'Axe HP is 33.3% on this frame (518/1556)')
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'a genuinely wounded bot keeps its escape option -- the guard may not veto here')
end

tests['t=573.0: the HP floor is the SOLE deciding clause'] = function()
    local J, bot = load_fx(INIT_573, { turbo = true, armed = true })
    -- Both of the other clauses are satisfied, so neither can be credited with
    -- the release. Without this the test above would pass even if the guard
    -- were released by the damage clause instead.
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'no hero damage in the 2.0s window the guard reads')
    assert(bot:WasRecentlyDamagedByAnyHero(6.0) == false,
        'and none in the whole 6.0s the fixture records -- the damage clause is quiet')
    -- Turn the one remaining clause off and the guard flips: proof by
    -- construction that HP is what decided this frame.
    rawget(bot, '__spec').GetHealth = math.floor(bot:GetMaxHealth() * 0.75 + 0.5)
    rawset(bot, 'GetHealth', nil)
    assert(bot:GetHealth() / bot:GetMaxHealth() >= 0.70, 'sanity: 75% >= 70%')
    assert(J.ShouldHoldBlinkFlee(bot) == true,
        'lift this same frame over the HP floor and the guard holds -- so on the '
        .. 'real frame the floor, and nothing else, released it')
end

tests['t=573.0: the frame is INSIDE the retreat branch domain'] = function()
    local J, bot = load_fx(INIT_573, { turbo = true, armed = true })
    -- The branch only ever asks the guard when it already has an enemy inside
    -- 1200. If that were empty here the release would be uninformative (the
    -- earthshaker PASS frame's failure mode, GH #74 §3).
    local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)
    assert(nInRangeEnemy ~= nil and #nInRangeEnemy >= 1,
        'juggernaut sits 648 away: the branch really does reach the guard here')
end

tests['t=573.0, gate OFF: armed and shipped are bit-identical'] = function()
    local J, bot = load_fx(INIT_573, { turbo = true, armed = false })
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'the guard is inert unarmed -- and armed it also releases, so this frame '
        .. 'costs the candidate side nothing')
end

tests['t=573.0 ground truth: releasing was the right call'] = function()
    local _, bot, heroes, fx = rf.load(INIT_573)
    local jugg = heroes['npc_dota_hero_juggernaut']
    assert(jugg ~= nil, 'juggernaut is on the frame')
    assert(jugg:GetHealth() / jugg:GetMaxHealth() < 0.50,
        'and he is under half HP (450/978) -- a kill target, not a threat to flee')
    assert(fx.observed.died_after == nil or fx.observed.died_after > 15.0,
        'the subject did not die inside any window this guard reasons about '
        .. '(ground truth: 36.9s later, long after the fight he won)')
    -- [limitation] observed.burst counts only combat-log DAMAGE rows.
    -- make_fixture.py filters `type == "DAMAGE"` and drops CRITICAL_DAMAGE;
    -- this frame carries two of the latter (120 @ +1.3s, 121 @ +2.0s), each
    -- paired with a DAMAGE row from the same actor at the same instant. The
    -- pairing is why the BOOLEAN readers (WasRecentlyDamagedBy*) are unaffected
    -- -- 6/6 crits in this game have a same-instant DAMAGE twin -- but the
    -- MAGNITUDE here is the applied-damage convention, not a crit-inclusive sum.
    assert(fx.observed.burst['npc_dota_hero_juggernaut'] == 134,
        'burst is the DAMAGE-row sum 50+50+34, not 375')
end

-- ---------------------------------------------------------------------------
-- The HOLD ledger. GH #71's shipped-comment claim -- "cost of holding a wasted
-- blink here is zero" -- was written on n=2 and has been contradicted once
-- since (GH #74 §2: the earthshaker HOLD frame died +6.0s). This case turns
-- that claim into a number the repo maintains, over every frame this family
-- has pinned, so nobody has to re-derive it from three reports.
--
-- The one death is NOT evidence that holding costs a life: on that frame the
-- blink that ACTUALLY happened did not prevent the death either -- viper closed
-- 1175 -> 779 -> 594 -> 515 across the cast and killed the earthshaker anyway
-- (GH #74 §1.3(B), read off the same replay). A hold-cost only exists on a
-- frame where the real blink achieved separation AND the bot lived; the corpus
-- has no such frame yet. So the measured hold-cost is 0 of 3, not 1 of 3 --
-- and that distinction is what this case exists to keep visible.

tests['[recorded] the HOLD ledger: 3 held frames, 1 death, 0 preventable'] = function()
    local LEDGER = {
        -- fixture, expected gate reading, ground-truth died_after
        { FLEE_529, true,  nil },
        { FLEE_555, true,  nil },
        { 'tests/fixtures/f_260820_162859_es_blink_flee_615.lua', true, 6.0 },
        -- The two PASS frames, for contrast: on neither does the guard decide.
        -- es_621 is released by the branch prerequisite (1200 empty), axe_573
        -- by the HP floor -- and es_621 still died, after a blink the guard
        -- never had an opinion about.
        { 'tests/fixtures/f_260820_163429_es_blink_init_621.lua', true,  15.0 },
        { INIT_573, false, 36.9 },
    }

    local nHeld, nHeldDeaths = 0, 0
    for _, row in ipairs(LEDGER) do
        local path, bHold, nDied = row[1], row[2], row[3]
        local J, bot, _, fx = rf.load(path)
        J.IsModeTurbo = function() return true end
        J.IsSoakCandidate = function(id) return id == 'blinkflee' end
        assert(J.ShouldHoldBlinkFlee(bot) == bHold,
            path .. ': the guard reading moved -- re-read the ledger')
        assert(fx.observed.died_after == nDied,
            path .. ': ground truth died_after moved (' .. tostring(nDied)
            .. ' -> ' .. tostring(fx.observed.died_after) .. ')')
        -- Only the retreat-leg frames count toward hold cost; the guard reading
        -- true on an offensive frame (es_621) is not a hold the branch acts on.
        if bHold and path ~= 'tests/fixtures/f_260820_163429_es_blink_init_621.lua' then
            nHeld = nHeld + 1
            if nDied ~= nil and nDied <= 8.0 then nHeldDeaths = nHeldDeaths + 1 end
        end
    end

    assert(nHeld == 3, 'three retreat-leg frames are pinned as HOLD, saw ' .. nHeld)
    assert(nHeldDeaths == 1, 'exactly one of them died inside 8s, saw ' .. nHeldDeaths
        .. ' -- if this moves, GH #71/#74 arming argument has to be re-read')
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

-- GH #193: mode_farm_generic's Think() carried a live call to a nil field, and
-- the repair is split into a forced half (ungated) and a policy half (gated
-- soak candidate 'campdanger', turbo-only).
--
-- THE DEFECT (bots/mode_farm_generic.lua, shipped default, UNGATED)
-- ----------------------------------------------------------------
-- The camp-switch conjunct inside Think() negated a call to a J.Site field
-- named `IsCampDangerous`, handing it the bot and the candidate camp. That
-- name is declared in NO file under bots/ under any of the six declaration
-- forms, and J.Site is `require(FunLib/aba_site)` -- a transpiled module of
-- plain `____exports.name = function` assignments with no setmetatable and no
-- __index, so there is no dynamic fall-back either. The field was nil and the
-- line raised `attempt to call a nil value` INSIDE Think().
--
-- The engine's error handler is broken (`error in error handling` masks the
-- text) and print() never reaches the console, so this never read as a crash.
-- It read as a SILENT Think abort, in every game, on every frame where a
-- farming bot's nearest available camp was more than 200 units closer than its
-- current pick -- and everything below that line in Think(), the whole block
-- that walks to the camp and attacks the neutrals, was eaten on those frames.
--
-- Four layers were structurally unable to see it, which is why it survived from
-- the upstream snapshot: tests/test_no_undefined_jmz_refs.lua (GH #48) exists
-- for exactly this class but its pattern stops at the first dot, so
-- `J.Site.<name>` reads as a reference to `J.Site`, which IS defined, and the
-- second component is never asked about; luacheck is `only = {"1"}` (1xx global
-- access) and this is a field access on a legitimate local; the arity census
-- skips names with no declaration before stats; and the runtime masks it.
--
-- THE SPLIT (why one half is gated and the other is not)
-- -----------------------------------------------------
-- UNGATED, forced: the nil call is gone. J.IsCampSwitchSafe returns false
-- unarmed, and false is byte-for-byte the camp decision the abort produced --
-- an abort updates nothing, so "do not switch" IS the shipped verdict. The one
-- unarmed change is that Think() runs on; restoring that tail invents no camp
-- policy, and there is exactly one way to stop calling a nil field.
--
-- GATED 'campdanger', turbo-only: which semantics the switch should have (write
-- a danger predicate, or drop the term and always switch) is a real farm-policy
-- fork with no shipped verdict to preserve, because the predicate never
-- returned. Policy ships dark.
--
-- WHAT THIS FILE BUYS, AND WHAT IT CANNOT -- read before trusting a number
-- -----------------------------------------------------------------------
-- The DANGER half is real. The fixture loader implements GetHeroLastSeenInfo
-- with genuine fog memory -- real coordinates off the .dem, time_since_seen 0
-- for a hero the subject's team can see -- so J.GetLastSeenEnemiesNearLoc is
-- live here, not stubbed, and [boundary] below drives the answer off the real
-- distance between two real heroes on the frame.
--
-- The END-TO-END switch is NOT reachable and is not pretended to be. World
-- fact (W1) asserts it: GetNeutralSpawners() answers `{}` on every corpus frame
-- (already noted at jmz_func.lua:8191), so J.Site.RefreshCamp returns an empty
-- table, ClosestCamp returns nil, and Think() can never reach the conjunct in a
-- fixture. The location operand below is therefore a REAL MAP POINT taken off
-- the frame, not a real neutral camp: the geometry and the fog are corpus data,
-- the claim "this point is a camp" is not. Nothing here is a measurement of how
-- often the switch fires in a game -- GH #193 section 5 hands that question to
-- an offline frame count, and it is not answered in this file.
--
-- THE FRAME. tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua, the GH
-- #137 case: Wraith King, level 11, at (-5028.8, -76.3) with 817/1307 HP, being
-- eaten by an ancient camp -- his recent_damage is granite_golem and rock_golem
-- and he carries modifier_ancient_rock_golem_weakening. A real farming bot
-- really at a camp, which is the decision this conjunct governs. Measured on
-- the frame, not assumed: his nearest living enemy (earthshaker) is 7644.8
-- units away, and the four living enemies are at 7644.8 / 7790.3 / 10641.3 /
-- 11167.6.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FRAME = 'tests/fixtures/f_260823_002103_wk_ancient_camp_634.lua'
local WK = 'npc_dota_hero_skeleton_king'

-- Measured on the frame by the survey that chose it; re-asserted in [frame] so
-- that a corpus edit fails loudly here instead of quietly moving the boundary.
local NEAREST_ENEMY = 'npc_dota_hero_earthshaker'
local NEAREST_DIST = 7644.8
local ES_LOC = { x = 2284.8, y = 2149.4 }

local tests = {}

--- Load the frame with `ids` armed. Returns J, bot, fx.
local function frame(ids)
    local J, bot, _, fx = rf.load(FRAME, WK)
    local armed = {}
    for _, id in ipairs(ids or {}) do armed[id] = true end
    J.IsSoakCandidate = function(id) return armed[id] == true end
    return J, bot, fx
end

--- The shape RefreshCamp emits: `{ idx = camp.idx, cattr = camp }`, and every
--- camp reader in aba_site goes through `.cattr`. Only `.cattr.location` is
--- read by the predicate under test, so that is all this carries -- a stand-in
--- for the wrapper, at a REAL map point (see the limits block above).
local function camp_at(vLoc)
    return { idx = 1, cattr = { location = vLoc } }
end

-- ---- world facts this file's reach depends on --------------------------------

tests['[W1] the corpus carries no neutral camps, so the switch is unreachable end to end'] = function()
    local J = frame({})
    assert(#GetNeutralSpawners() == 0,
        'GetNeutralSpawners() now answers a non-empty table. That is good news '
        .. 'and it obsoletes this file\'s stand-in camp: RefreshCamp can build '
        .. 'a real table, ClosestCamp can return a real camp, and the switch '
        .. 'should be driven end to end through the real Think() instead')
    assert(#J.Site.RefreshCamp({ GetLevel = function() return 11 end,
                                 GetAttackDamage = function() return 100 end },
                               false) == 0,
        'RefreshCamp reads GetNeutralSpawners(), so an empty spawner list must '
        .. 'produce an empty camp table -- if it does not, the reason this file '
        .. 'uses a stand-in no longer holds')
end

tests['[W2] this frame is Turbo, which the gate structurally requires'] = function()
    local J = frame({})
    assert(J.IsModeTurbo() == true,
        'the batch corpus is Turbo and the gate is turbo-only; if this frame '
        .. 'ever reads non-turbo, every [armed] case below is vacuously false '
        .. 'for the WRONG reason and proves nothing')
end

tests['[frame] the geometry the boundary case rests on has not moved'] = function()
    local _, bot, fx = frame({})
    local me = bot:GetLocation()
    local best, bestName = 1e9, nil
    local nAlive = 0
    for _, u in ipairs(fx.units) do
        if u.team ~= 2 and u.alive then
            nAlive = nAlive + 1
            local d = math.sqrt((u.x - me.x) ^ 2 + (u.y - me.y) ^ 2)
            if d < best then best, bestName = d, u.name end
        end
    end
    assert(nAlive == 4, 'the frame used to carry 4 living enemies, now ' .. nAlive)
    assert(bestName == NEAREST_ENEMY, string.format(
        'nearest living enemy used to be %s, now %s', NEAREST_ENEMY, tostring(bestName)))
    assert(math.abs(best - NEAREST_DIST) < 0.5, string.format(
        'nearest enemy used to be %.1f units away, now %.1f -- the [boundary] '
        .. 'radii below are derived from that number', NEAREST_DIST, best))
end

-- ---- the defect itself, asserted on the real frame ---------------------------

tests['[premise] the field the old conjunct called is still nil'] = function()
    local J = frame({})
    assert(J.Site ~= nil, 'J.Site is the aba_site module and must exist')
    assert(J.Site['IsCampDangerous'] == nil,
        'aba_site now declares IsCampDangerous. The premise of GH #193 was '
        .. 'that the field does not exist; if someone wrote the predicate '
        .. 'there, this file and the gated one in jmz_func are duplicates and '
        .. 'one of them has to go')
    assert(getmetatable(J.Site) == nil,
        'aba_site grew a metatable -- a missing field could now resolve '
        .. 'through __index and the "the field is nil" argument no longer holds')
end

tests['[premise] calling it raises on this frame -- the defect, not a description of it'] = function()
    local J, bot = frame({})
    local camp = camp_at(bot:GetLocation())
    local ok, err = pcall(function()
        -- The shipped conjunct, verbatim except for the field being reached
        -- through a subscript so this file does not itself contain the literal
        -- call text (tests/test_call_form_census.py section 4 presence-checks
        -- the source for it, and a quoted copy re-arms that ratchet).
        return not J.Site['IsCampDangerous'](bot, camp)
    end)
    assert(ok == false,
        'the old conjunct no longer raises. Either aba_site declares the '
        .. 'predicate now, or J.Site resolves missing fields -- either way '
        .. 'GH #193 is stale and this file should be revisited')
    assert(tostring(err):find('nil value', 1, true) ~= nil, string.format(
        'it raised, but not the nil-call this issue is about: %s', tostring(err)))
end

-- ---- the ungated half: same camp decision, no raise ---------------------------

tests['[unarmed] the predicate answers false -- the camp decision the abort produced'] = function()
    local J, bot = frame({})
    assert(J.IsCampSwitchSafe(camp_at(bot:GetLocation())) == false,
        'unarmed this must be false, so the conjunct is false and preferedCamp '
        .. 'is NOT switched. That is byte-for-byte what the abort did, because '
        .. 'an abort updates nothing. If this ever returns true unarmed, the '
        .. 'ungated half stopped being conservative and became live policy')
end

tests['[unarmed] and it does not raise -- which is the whole of the ungated half'] = function()
    local J, bot = frame({})
    local ok = pcall(J.IsCampSwitchSafe, camp_at(bot:GetLocation()))
    assert(ok == true,
        'the point of the ungated half is that Think() runs on past this line. '
        .. 'If the predicate itself can raise, nothing was fixed')
end

tests['[unarmed] a malformed or absent camp is false, not a raise'] = function()
    local J = frame({ 'campdanger' })
    for _, bad in ipairs({ 'nil', 'empty', 'no-location' }) do
        local camp = (bad == 'nil' and nil)
            or (bad == 'empty' and {})
            or { idx = 1, cattr = {} }
        local ok, res = pcall(J.IsCampSwitchSafe, camp)
        assert(ok == true, 'a ' .. bad .. ' camp raised: ' .. tostring(res))
        assert(res == false, 'a ' .. bad .. ' camp must read unsafe, got ' .. tostring(res))
    end
end

-- ---- the gated half: the question the conjunct asks, answered ------------------

tests['[armed] a camp with no enemy inside the radius is safe to switch to'] = function()
    local J, bot = frame({ 'campdanger' })
    -- The point the bot is actually standing on: the ancient camp eating him.
    -- Nearest living enemy 7644.8 away, so nothing is within 800.
    assert(#J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), J.CAMP_DANGER_RADIUS) == 0,
        'the premise of this case is that the radius is empty on this frame')
    assert(J.IsCampSwitchSafe(camp_at(bot:GetLocation())) == true,
        'armed, an empty radius must read safe -- otherwise the gated half '
        .. 'never switches and is indistinguishable from the unarmed leg')
end

tests['[armed] a camp with an enemy inside the radius is not'] = function()
    local J = frame({ 'campdanger' })
    local hot = Vector(ES_LOC.x, ES_LOC.y, 0)
    local n = #J.GetLastSeenEnemiesNearLoc(hot, J.CAMP_DANGER_RADIUS)
    assert(n == 1, string.format(
        'the premise of this case is that exactly one enemy (%s, standing on '
        .. 'this very point) is inside the radius; got %d', NEAREST_ENEMY, n))
    assert(J.IsCampSwitchSafe(camp_at(hot)) == false,
        'armed, an occupied camp must read unsafe. This is the ONLY behaviour '
        .. 'the gated half adds over "always switch to the nearer camp"; if it '
        .. 'is false the id is not worth arming')
end

tests['[armed] outside Turbo the gate is shut, so the answer is the unarmed one'] = function()
    local J, bot = frame({ 'campdanger' })
    J.IsModeTurbo = function() return false end
    assert(J.IsCampSwitchSafe(camp_at(bot:GetLocation())) == false,
        'the whole predicate is turbo-only; outside turbo it must fall back to '
        .. 'the conservative false, exactly as if nothing were armed')
end

tests['[boundary] the verdict is driven by the real distance, not by a stub'] = function()
    local J, bot = frame({ 'campdanger' })
    local camp = camp_at(bot:GetLocation())
    -- Sweep the radius across the real distance to the real nearest enemy. If
    -- the fog query were stubbed to "nobody anywhere", both sides would read
    -- safe and this case would fail.
    J.CAMP_DANGER_RADIUS = math.floor(NEAREST_DIST) - 1
    assert(J.IsCampSwitchSafe(camp) == true, string.format(
        'at r=%d the nearest enemy (%.1f away) is outside and the camp must '
        .. 'read safe', math.floor(NEAREST_DIST) - 1, NEAREST_DIST))
    J.CAMP_DANGER_RADIUS = math.ceil(NEAREST_DIST) + 1
    assert(J.IsCampSwitchSafe(camp) == false, string.format(
        'at r=%d that same enemy is inside and the camp must read unsafe -- '
        .. 'the verdict has to follow the real geometry across the real '
        .. 'distance, or the fog query is not live here', math.ceil(NEAREST_DIST) + 1))
end

-- ---- the call site, pinned ----------------------------------------------------

local function farm_source()
    local fh = assert(io.open('bots/mode_farm_generic.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    -- Strip line comments: the block above the call site describes the old
    -- shape in prose, and a whole-file match would find the description.
    return (s:gsub('%-%-[^\n]*', ''))
end

tests['[source] the conjunct routes through the repaired predicate'] = function()
    local src = farm_source()
    local _, nCall = src:gsub('J%.IsCampSwitchSafe%(nearest%)', '')
    assert(nCall == 1, string.format(
        'expected exactly one J.IsCampSwitchSafe(nearest) call site in '
        .. 'mode_farm_generic, found %d', nCall))
    assert(src:find('IsCampDangerous', 1, true) == nil,
        'the nil call is back in live code (comments are stripped before this '
        .. 'match, so this is not the explanatory block)')
end

tests['[source] the distance test still short-circuits ahead of the predicate'] = function()
    local src = farm_source()
    assert(src:find('newDist + 200 < oldDist and J.IsCampSwitchSafe(nearest)', 1, true) ~= nil,
        'the conjunct order changed. The distance test must stay on the left: '
        .. 'unarmed it is what keeps the predicate from being consulted at all '
        .. 'on the overwhelming majority of frames, and reversing it would put '
        .. 'a fog sweep on every farm tick')
end

return tests

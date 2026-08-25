-- [hero] GH #165 -- Alchemist's two turbo clock scalings never ran, and the
-- reason is Lua operator precedence, not a badly chosen constant.  The fix
-- ships GATED ('alchrage', turbo-only, not armed).
--
-- WHAT WAS FOUND
--
-- bots/BotLib/hero_alchemist.lua and its verbatim rubick_hero copy each carried
-- two clauses inside X.ConsiderChemicalRage, guarding whether the ultimate may
-- be burned on Roshan / the Tormentor:
--
--     and (J.IsModeTurbo() and DotaTime() < 15 * 60 or DotaTime() < 30 * 60)
--     and (J.IsModeTurbo() and DotaTime() < 16 * 60 or DotaTime() < 32 * 60)
--
-- Lua has no ternary operator.  `cond and x or y` is only equivalent to one
-- while `x` can never be false or nil, and here `x` is a COMPARISON.  `and`
-- binds tighter than `or`, so the first line parses as
--
--     (J.IsModeTurbo() and DotaTime() < 15*60)  or  (DotaTime() < 30*60)
--
-- and because 15*60 < 30*60 the left disjunct IMPLIES the right one: true, and
-- the right is true anyway; false, and the right decides alone.  The whole
-- expression was literally `DotaTime() < 30 * 60`, in every mode, forever.  The
-- turbo constant decided nothing and nothing anywhere reported that -- it reads
-- exactly like a turbo scaling somebody already did.
--
-- Note the NUMERIC form of the same idiom is fine and is all over jmz_func
-- (`J.IsModeTurbo() and 5 * 60 or 10 * 60`): a number in the `x` slot is never
-- false.  The discriminator is the type in the `x` slot, not the idiom.
--
-- WHY THIS ONE IS WORTH THE CHANGE.  The strategy desk found the class (GH
-- #165, repo-wide ratchet in tests/test_turbo_ternary_dominance.lua) and fixed
-- its own instance in mode_farm_generic, whose dead band is 18:00-25:00 -- past
-- the end of a ~20-minute turbo game, so close to zero domain.  Alchemist's
-- dead band is 15:00/16:00 to 20:00, which is a real slice of one.
--
-- THE THEORY BEHIND THE ARMED VALUE (validation condition (c)).  The shipped
-- 30:00 / 32:00 is a "stop spending the ultimate on neutral objectives once the
-- game is decided by fights" clock for a ~40-minute normal game.  Turbo runs
-- about half that, so the author's own 15:00 / 16:00 is the same rule at turbo
-- pace.  This change restores the intent that was already written down; it does
-- not invent a new bound, and it is NOT a claim that 15:00 is optimal (that is
-- the clock-constant axis, GH #157 -- and the reason it ships gated).
--
-- THE SHAPE (why both gate-off equivalence and the subset property are
-- STRUCTURAL rather than measured -- hero backlog, the lesson GH #154 wrote
-- down as "放宽型的门写成「出货判据先跑一遍」的形状"):
--
--     local nClock = nShippedMin * 60
--     if J.IsModeTurbo() and J.IsSoakCandidate('alchrage') then
--         nClock = math.min(nClock, nTurboMin * 60)
--     end
--
--   * gate off returns the shipped bound by construction, and the shipped bound
--     is what the old expression collapsed to -- so "gate-closed == factory" is
--     assertable arithmetic, not a promise (§2);
--   * the armed branch can only take a MINIMUM, so the armed predicate is a
--     subset of the shipped one whatever constants a caller passes.  A future
--     caller handing it a turbo bound ABOVE the shipped bound still cannot
--     widen anything (§4).  One lever, and it can only fire less.
--
-- ⚠️ LIMIT -- THE DOMAIN WAS EMPTY ON THE FARM UNTIL 2026-08-25, AND THAT WAS
-- MEASURED BELOW, NOT ASSERTED.  tools/batch_test/soak/soak_loop.sh used to cap
-- games at SOAK_CAP_MIN=10 game-minutes against an armed bound of 15:00; inside
-- a capped game `DotaTime() < 15*60` was true at every instant, so armed and
-- factory were POINTWISE IDENTICAL there and no number of games could buy
-- condition (a).  Consequences, stated so nobody over-reads a green run: a
-- green run here was NOT evidence the change fires and NOT evidence it is
-- unnecessary; it was evidence about arithmetic and about the gate's shape.
--
-- UPDATE 2026-08-25 (GH #108): the director executed the owner's cap decision,
-- SOAK_CAP_MIN is now 25, and the [domain] test below turned over exactly as it
-- was wired to -- it is kept with the sign flipped rather than deleted.  The
-- band 15:00-25:00 now sits inside a capped game, so BOTH a wave and a
-- real-frame fixture are possible and this id is worth proposing for the test
-- set (baton in GH #108 / #165, hero desk).  §7 still measures the frame
-- corpus, which lags the farm: every fixture in tests/fixtures is still below
-- the armed bound, and §7 goes red the day one lands in the band and says so.
--
-- WHAT THIS FILE DOES NOT CLAIM.  That waking these two clauses is GOOD.
-- Locally-correct is not emergently-good (AGENTS.md, the lanefix lesson) --
-- that is what the gate is for.

package.path = 'tests/?.lua;' .. package.path

local api = require('mock.bot_api')

local CAND = 'alchrage'

-- The two files, and the hero each one is loaded on.  The rubick copy is a
-- verbatim twin and BOTH must move together, so everything below runs over this
-- list rather than over the hero file alone.
local SOURCES = {
    { path = 'bots/BotLib/hero_alchemist.lua',        unit = 'npc_dota_hero_alchemist' },
    { path = 'bots/FunLib/rubick_hero/alchemist.lua', unit = 'npc_dota_hero_rubick' },
}

-- The two call sites, as (turbo bound, shipped bound) in minutes.  Roshan and
-- the Tormentor.
local CALL_SITES = {
    { turbo = 15, shipped = 30 },
    { turbo = 16, shipped = 32 },
}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local s = fh:read('*a'); fh:close()
    return s
end

--- Source with Lua line comments removed.  The reasoning block above quotes the
--- broken idiom verbatim; a scanner that reads prose would report the prose
--- (GH #136's first census made exactly that mistake).
local function strip_comments(src)
    return (src:gsub('%-%-[^\n]*', ''))
end

--- Load one source under the mock API and hand back its X table plus the
--- jmz_func instance IT loaded -- patching a second copy would arm a gate
--- nobody reads.
local function load_source(spec, opts)
    opts = opts or {}
    api.reset_modules()
    local bot = api.MakeHero(spec.unit)
    api.install({ bot = bot })
    local X = dofile(spec.path)
    assert(type(X) == 'table', spec.path .. ' did not return its X table')
    local J = package.loaded[GetScriptDirectory() .. '/FunLib/jmz_func']
    assert(J, 'jmz_func must already be loaded by ' .. spec.path)
    J.IsModeTurbo = function() return opts.turbo ~= false end
    J.IsSoakCandidate = function(id) return opts.armed == true and id == CAND end
    assert(X.GetRageObjectiveClock, spec.path .. ' has no X.GetRageObjectiveClock')
    return X
end

--- The factory expression, evaluated exactly as Lua parses it.
local function factory_idiom(bTurbo, t, nTurboSec, nShippedSec)
    return bTurbo and t < nTurboSec or t < nShippedSec
end

--- A dense grid over the interesting range, with both bounds and their
--- immediate neighbours pinned so an off-by-one in the comparison shows up.
local function grid(a, b)
    local ts = {}
    for t = -120, 40 * 60, 5 do ts[#ts + 1] = t end
    for _, edge in ipairs({ a, b }) do
        for _, d in ipairs({ -0.001, 0, 0.001, -1, 1 }) do ts[#ts + 1] = edge + d end
    end
    return ts
end

local tests = {}

-- ---------------------------------------------------------------------------
-- 1.  The defect, as arithmetic.  A frame cannot show this: the two legs agree
--     on every frame, which is the whole point.  It takes the RELATION between
--     the two constants to see it at all.
-- ---------------------------------------------------------------------------

tests['[arithmetic] each call site\'s factory idiom was literally `t < shipped`'] = function()
    for _, cs in ipairs(CALL_SITES) do
        local a, b = cs.turbo * 60, cs.shipped * 60
        for _, t in ipairs(grid(a, b)) do
            for _, bTurbo in ipairs({ true, false }) do
                assert(factory_idiom(bTurbo, t, a, b) == (t < b),
                    ('%d/%d: idiom(turbo=%s, t=%.3f) is not `t < %d` -- the dominance '
                    .. 'this whole file rests on has broken')
                    :format(cs.turbo, cs.shipped, tostring(bTurbo), t, b))
            end
        end
    end
end

-- Without this the test above would pass on a grid where NOTHING is dominated:
-- it would be asserting `x == x`.
tests['[reverse] swap the two constants and the equivalence must BREAK'] = function()
    for _, cs in ipairs(CALL_SITES) do
        local a, b = cs.shipped * 60, cs.turbo * 60   -- turbo bound now ABOVE shipped
        local bDiffers = false
        for _, t in ipairs(grid(a, b)) do
            if factory_idiom(true, t, a, b) ~= factory_idiom(false, t, a, b) then
                bDiffers = true
                assert(t >= b and t < a, ('%d/%d: the legs differ at t=%.3f, outside '
                    .. '[%d, %d) -- the model of the idiom is wrong')
                    :format(cs.shipped, cs.turbo, t, b, a))
            end
        end
        assert(bDiffers, ('%d/%d: with the constants swapped the two legs STILL agree '
            .. 'everywhere. The grid is proving a tautology, not a relation.')
            :format(cs.shipped, cs.turbo))
    end
end

-- ---------------------------------------------------------------------------
-- 2.  Gate closed == factory, pointwise, in both files and both modes.
-- ---------------------------------------------------------------------------

tests['[gate off] the helper reproduces the factory predicate at every t'] = function()
    for _, spec in ipairs(SOURCES) do
        for _, bTurbo in ipairs({ true, false }) do
            local X = load_source(spec, { armed = false, turbo = bTurbo })
            for _, cs in ipairs(CALL_SITES) do
                local a, b = cs.turbo * 60, cs.shipped * 60
                local nClock = X.GetRageObjectiveClock(cs.turbo, cs.shipped)
                assert(nClock == b, ('%s: gate off, turbo=%s, %d/%d gives clock %s, '
                    .. 'the factory expression collapsed to %d')
                    :format(spec.path, tostring(bTurbo), cs.turbo, cs.shipped,
                            tostring(nClock), b))
                for _, t in ipairs(grid(a, b)) do
                    assert((t < nClock) == factory_idiom(bTurbo, t, a, b),
                        ('%s: gate off, turbo=%s, %d/%d disagrees with the factory '
                        .. 'expression at t=%.3f'):format(spec.path, tostring(bTurbo),
                        cs.turbo, cs.shipped, t))
                end
            end
        end
    end
end

-- Armed but NOT turbo is the same claim from the other side: shipped normal-mode
-- behaviour must be untouchable by arming anything (AGENTS.md, turbo-only).
tests['[gate on, normal mode] arming changes nothing outside turbo'] = function()
    for _, spec in ipairs(SOURCES) do
        local X = load_source(spec, { armed = true, turbo = false })
        for _, cs in ipairs(CALL_SITES) do
            assert(X.GetRageObjectiveClock(cs.turbo, cs.shipped) == cs.shipped * 60,
                spec.path .. ': armed in normal mode moved the clock; the gate is not turbo-only')
        end
    end
end

-- ---------------------------------------------------------------------------
-- 3.  Armed, in turbo: the band moves, and only in one direction.
-- ---------------------------------------------------------------------------

tests['[gate on, turbo] armed is a strict SUBSET, and only inside [turbo, shipped)'] = function()
    for _, spec in ipairs(SOURCES) do
        local X = load_source(spec, { armed = true, turbo = true })
        for _, cs in ipairs(CALL_SITES) do
            local a, b = cs.turbo * 60, cs.shipped * 60
            assert(X.GetRageObjectiveClock(cs.turbo, cs.shipped) == a,
                ('%s: armed in turbo, %d/%d did not take the turbo bound')
                :format(spec.path, cs.turbo, cs.shipped))
            local nMoved = 0
            for _, t in ipairs(grid(a, b)) do
                local factory, armed = t < b, t < a
                if factory ~= armed then
                    nMoved = nMoved + 1
                    assert(factory == true and armed == false,
                        ('%s: at t=%.3f armed says TRUE where factory says FALSE -- '
                        .. 'this lever may only fire LESS'):format(spec.path, t))
                    assert(t >= a and t < b, ('%s: a difference at t=%.3f sits outside '
                        .. '[%d, %d)'):format(spec.path, t, a, b))
                end
            end
            assert(nMoved > 0, ('%s: %d/%d armed moves nothing on the grid -- the lever '
                .. 'is a no-op'):format(spec.path, cs.turbo, cs.shipped))
        end
    end
end

-- ---------------------------------------------------------------------------
-- 4.  The subset property is STRUCTURAL, not a property of the two constants
--     these call sites happen to pass.  This is the math.min, and it is the
--     difference between "the fix is safe" and "the fix is safe today".
-- ---------------------------------------------------------------------------

tests['[structural] armed can never RAISE the clock, whatever a caller passes'] = function()
    for _, spec in ipairs(SOURCES) do
        local X = load_source(spec, { armed = true, turbo = true })
        -- a turbo bound ABOVE the shipped bound: the dangerous direction
        assert(X.GetRageObjectiveClock(45, 30) == 30 * 60,
            spec.path .. ': a turbo bound above the shipped bound WIDENED the clock. '
            .. 'The armed branch must take a minimum, not an assignment.')
        assert(X.GetRageObjectiveClock(30, 30) == 30 * 60,
            spec.path .. ': equal bounds must be a no-op')
        assert(X.GetRageObjectiveClock(1, 30) == 60,
            spec.path .. ': a lower turbo bound must be taken')
    end
end

-- ---------------------------------------------------------------------------
-- 5.  Source shape: the four call sites route through the helper, the idiom is
--     gone from both files, and the gate is wired the way the comments say.
-- ---------------------------------------------------------------------------

tests['[source] both files carry the gated helper and no surviving idiom'] = function()
    for _, spec in ipairs(SOURCES) do
        local src = strip_comments(read_file(spec.path))

        local body = src:match('function X%.GetRageObjectiveClock%b()(.-)\nend')
        assert(body, spec.path .. ': X.GetRageObjectiveClock is gone; the call sites '
            .. 'would be back to deciding nothing')
        assert(body:find("IsSoakCandidate( '" .. CAND .. "' )", 1, true),
            spec.path .. ': the narrowing must sit behind IsSoakCandidate(' .. CAND .. ')')
        assert(body:find('IsModeTurbo', 1, true),
            spec.path .. ': and behind IsModeTurbo (turbo-only, AGENTS.md)')
        assert(body:find('math.min', 1, true),
            spec.path .. ': the armed branch must take a minimum -- see §4')

        -- Exactly the two call sites, with the constants this file reasons about
        -- AND the comparison they are consumed by.  Pinning only the helper
        -- would leave `DotaTime() <= clock` (or a negation) free to change the
        -- predicate without a single assertion above noticing: §§2-4 test what
        -- the helper RETURNS, not what the call site does with it.
        for _, cs in ipairs(CALL_SITES) do
            local pat = 'DotaTime%(%)%s*<%s*X%.GetRageObjectiveClock%('
                .. cs.turbo .. ',%s*' .. cs.shipped .. '%)'
            local n = select(2, src:gsub(pat, ''))
            assert(n == 1, ('%s: expected exactly one `DotaTime() < '
                .. 'X.GetRageObjectiveClock(%d, %d)` call site, found %d')
                :format(spec.path, cs.turbo, cs.shipped, n))
        end

        -- and nothing left that reads the old way
        for _, line in ipairs((function()
            local t = {}
            for line in (strip_comments(read_file(spec.path))):gmatch('[^\n]+') do t[#t + 1] = line end
            return t
        end)()) do
            assert(not (line:find('IsModeTurbo', 1, true) and line:find(' or ', 1, true)
                        and line:find('DotaTime', 1, true)),
                spec.path .. ' still carries the boolean-ternary idiom:\n  ' .. line)
        end
    end
end

-- ---------------------------------------------------------------------------
-- 6.  The rubick copy must not drift.  It is a verbatim copy of the hero file's
--     spell logic; a fix applied to one and not the other is how the two ended
--     up carrying the same defect twice.
-- ---------------------------------------------------------------------------

tests['[twin] the two helpers are the same function'] = function()
    local function body_of(path)
        local b = assert(strip_comments(read_file(path))
            :match('function X%.GetRageObjectiveClock%b()(.-)\nend'), path .. ': no helper')
        return (b:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', ''))
    end
    local a, b = body_of(SOURCES[1].path), body_of(SOURCES[2].path)
    assert(a == b, 'the rubick copy has drifted from the hero file:\n  hero:   '
        .. a .. '\n  rubick: ' .. b)
end

-- ---------------------------------------------------------------------------
-- 7.  The LIMIT, measured rather than asserted: nothing offline, and nothing a
--     capped wave can produce, sits inside the band this change moves.
-- ---------------------------------------------------------------------------

tests['[corpus] no fixture in tests/fixtures can tell armed from factory'] = function()
    local ARMED = CALL_SITES[1].turbo * 60
    local tMax, sMax, n = -math.huge, nil, 0
    local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
    for path in p:lines() do
        local t = tonumber(read_file(path):match('time%s*=%s*([%-%d%.]+)'))
        assert(t ~= nil, path .. ' has no `time =` field -- the corpus scan is blind to it')
        n = n + 1
        if t > tMax then tMax, sMax = t, path end
    end
    p:close()
    assert(n > 0, 'no fixtures found -- this assertion is vacuous, do not read it as a pass')
    assert(tMax < ARMED, ('%s sits at t=%.1f, inside the band [%d, %d) this change '
        .. 'moves. The corpus can finally distinguish armed from factory: pin the '
        .. 'decision on that frame instead of resting on the arithmetic alone.')
        :format(sMax, tMax, ARMED, CALL_SITES[1].shipped * 60))
end

tests['[domain] the wave cap is above the armed bound, so a wave can buy (a)'] = function()
    local sh = read_file('tools/batch_test/soak/soak_loop.sh')
    local nCap = tonumber(sh:match('SOAK_CAP_MIN=%${SOAK_CAP_MIN:%-(%d+)}'))
    assert(nCap, 'cannot read SOAK_CAP_MIN out of soak_loop.sh; the domain claim in the '
        .. 'header is unverifiable, go re-read it before quoting it')
    local ARMED = CALL_SITES[1].turbo * 60
    -- 2026-08-25, GH #108: the director raised the cap 10 -> 25 and this
    -- assertion turned over, exactly as the hero desk wired it to. It is kept
    -- (not deleted) with the sign flipped, because the claim it now pins is the
    -- one somebody would otherwise re-derive by hand: while the cap sits ABOVE
    -- the armed bound the band 15:00-25:00 is inside a capped game, so a wave
    -- can distinguish armed from factory and condition (a) is buyable. Lower
    -- the cap back under 15:00 and this goes red -- which is the signal that
    -- any wave reading for `alchrage` has gone void, not merely uninformative.
    assert(nCap * 60 > ARMED, ('SOAK_CAP_MIN is %d minutes, at or below the armed bound '
        .. 'of %d: every instant of a capped game satisfies both predicates again, so '
        .. 'no wave can buy condition (a) for `%s`. Whoever lowered the cap owes the '
        .. 'test set a re-read (GH #108 checklist 7).')
        :format(nCap, CALL_SITES[1].turbo, CAND))
end

return tests

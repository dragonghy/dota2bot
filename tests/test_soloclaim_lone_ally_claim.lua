-- [soloclaim] The target-arbitration veto in J.IsOtherAllysTarget is written as
-- if the ally ring contained the asker, and it never has.
--
-- READ THE HEADER OF J.IsOtherAllysTarget FIRST (bots/FunLib/jmz_func.lua): the
-- defect, the direction argument and the two domain readings live there.  This
-- file is what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE.  It is in tests/_soloclaim_sweep.lua
-- and is run BY HAND.  A walk inside the test made the fightfoe round's file
-- ~120s, and tools/agent/lua_gate.py kills an unmeasured new test at
-- `hook_timeout_seconds` = 20.0 -- mid-`ss.arm`, leaving the global switch on
-- disk and breaking every OTHER gate test's "gate off" precondition.  The
-- numbers quoted below were taken by that sweep on 2026-09-17:
--
--   live 1039 | shipped_live 1039 | self_in_list 0 | ally0 627 | ally1 357
--   ally2plus 55 | proper_target_nonnil 0 | armable 184 | up 184 | down 0
--
-- `up` == `armable` exactly: every frame in the armed-side domain flips and
-- ONLY those.  ⛔ `down 0` is a reading only because `up` is 184 in the SAME
-- tally -- a direction column of zeros cannot tell "the direction holds" from
-- "the tally never ran".  And `armable` 184 < `ally1` 357 is the proof that
-- with_candidate armed ONE side, so the other side's armed and shipped answers
-- are identically equal by construction rather than by the code under test.
--
-- ⛔ `proper_target_nonnil` 0 / 1039 is an INSTRUMENT WALL, not a finding: an
-- attack target is bot-VM state the .dem does not carry (GH #27 / STOPPER 4
-- family).  So 357 is the CEILING of the in-engine flip set, NOT a fire rate,
-- and section 3 below supplies that one missing read with a stub and says so.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_soloclaim_lone_ally_claim load time')

local tests = {}

-- Witness frames, each picked for its ring size by the sweep's own column.
local W_ONE  = { 'tests/fixtures/f_011405_jak_rescue_axe.lua', 'npc_dota_hero_axe' }
local W_ZERO = { 'tests/fixtures/f_011405_jak_rescue_axe.lua', 'npc_dota_hero_lina' }
local W_TWO  = { 'tests/fixtures/f_050713_es_defend_1v3.lua',  'npc_dota_hero_lina' }

local function turbo()
    GAMEMODE_TURBO = 23                    -- luacheck: ignore
    GetGameMode = function() return 23 end -- luacheck: ignore
end

local function unprobe()
    GAMEMODE_TURBO = nil                               -- luacheck: ignore
    GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
end

--- ONE real load, turbo on.  ⛔ Never reuse a load to read the other answer:
--- J.IsModeTurbo memoises into a module-level cache on its FIRST call, so a
--- second reading taken after flipping GetGameMode is the FIRST reading.
local function load(w)
    unprobe()
    local J, bot = rf.load(w[1], w[2])
    turbo()
    return J, bot
end

local function ring(J, bot)
    return J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE) or {}
end

--- Ask the SHIPPED function about a unit the lone ally is holding.  The ONLY
--- constructed input is `J.GetProperTarget` for that one ally -- exactly the
--- read the .dem does not carry -- and it stands on the side that SUPPORTS the
--- conclusion, so it is named here rather than left for the reader to find.
local function ask_with_ally_holding(J, bot, hAlly)
    local unit = { GetLocation = function() return bot:GetLocation() end }
    local prior = J.GetProperTarget
    J.GetProperTarget = function(h)
        if h == hAlly then return unit end
        return prior(h)
    end
    local ok, v = pcall(J.IsOtherAllysTarget, unit)
    J.GetProperTarget = prior
    assert(ok, 'J.IsOtherAllysTarget raised: ' .. tostring(v))
    return v
end

-- ================================================ 1. the source, pinned

local function jmz_code()
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    local at = assert(s:find('function J.IsOtherAllysTarget', 1, true))
    local fin = assert(s:find('\nend\n', at, true))
    -- Comments stripped: a claim about what the CODE does must not be
    -- satisfiable by the prose describing it (the header quotes every one of
    -- these tokens several times).
    return (s:sub(at, fin):gsub('%-%-[^\n]*', ''))
end

tests['[soloclaim] the repair is gated, turbo-scoped, and ON the guard'] =
function()
    local code = jmz_code()
    assert(code:find("IsSoakCandidate%(%s*'soloclaim'%s*%)"),
        "the 'soloclaim' gate is gone from J.IsOtherAllysTarget")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- Order matters and counting cannot see it: a gate that names its id but
    -- sits BELOW the guard it exists to suspend passes every existence check
    -- above while doing nothing.
    local at_guard = assert(code:find('#hAllyList', 1, true))
    local at_gate = assert(code:find('soloclaim', 1, true))
    local at_loop = assert(code:find('for _, ally in pairs', 1, true))
    assert(at_guard < at_gate and at_gate < at_loop,
        "the 'soloclaim' gate no longer sits between the ally-count guard and "
        .. 'the loop it lets run')
end

tests['[soloclaim] the ONE lever: the ring and the dead self-test are untouched']
= function()
    local code = jmz_code()
    assert(code:find('J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )', 1, true),
        'the ally ring moved -- the ring is centred on the ASKER and that is a '
        .. 'SECOND, bigger defect this lever deliberately does not touch')
    assert(code:find('ally ~= bot', 1, true),
        'the `ally ~= bot` term was deleted.  It is dead code (self_in_list is '
        .. '0 / 1039) but it is the OTHER half of the same false belief, and '
        .. 'deleting it silently removes the evidence that the belief was held')
    assert(code:find('#hAllyList <= 1', 1, true),
        'the shipped guard itself is gone -- this lever SUSPENDS it behind a '
        .. 'gate, it does not remove it')
end

tests['[soloclaim] the sibling on the same list carries NEITHER line'] =
function()
    -- The discriminator the whole argument rests on.  If J.IsAllysTarget ever
    -- grows a `<= 1` guard or an `ally ~= bot` term, the two functions agree
    -- again and "the sibling reads the list the other way" stops being true.
    local fh = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local s = fh:read('*a'); fh:close()
    local at = assert(s:find('function J.IsAllysTarget', 1, true))
    local fin = assert(s:find('\nend\n', at, true))
    local sib = (s:sub(at, fin):gsub('%-%-[^\n]*', ''))
    assert(sib:find('J.GetNearbyHeroes(bot, 800, false, BOT_MODE_NONE )', 1, true),
        'J.IsAllysTarget no longer builds the SAME ring -- the comparison that '
        .. 'makes it a discriminator is gone')
    assert(not sib:find('<= 1', 1, true),
        'J.IsAllysTarget grew an ally-count guard; it was the function that '
        .. 'reads the list correctly')
    assert(not sib:find('ally ~= bot', 1, true),
        'J.IsAllysTarget grew a self-test; it was the function that does not '
        .. 'believe the list contains the asker')
end

-- ============================= 2. the premise, on real frames, unstubbed

tests['[soloclaim] real frame: the asker is NOT a member of its own ring'] =
function()
    -- The guard `#hAllyList <= 1` only means "nobody but me is here" if I am an
    -- entry.  Taken with no stub at all, on a frame that has a ring.
    local J, bot = load(W_ONE)
    local r = ring(J, bot)
    assert(#r == 1, 'the witness frame no longer has exactly one ally in 800, '
        .. 'it has ' .. #r .. ' -- re-pick it from the sweep')
    for _, a in pairs(r) do
        assert(a ~= bot, 'the ally ring now contains the asker, so the shipped '
            .. 'guard means what it says and this lever must be re-priced')
    end
    assert(J.GetProperTarget(r[1]) == nil,
        'J.GetProperTarget now answers on a corpus frame -- the "357 is a '
        .. 'ceiling, not a fire rate" reading must be re-taken')
    unprobe()
end

-- ==================== 3. the differential, both directions, two real loads

tests['[soloclaim] one ally holding the unit: armed sees the claim, shipped does not']
= function()
    -- ARMED leg.
    local armed
    ss.with_candidate('soloclaim', function()
        local J, bot = load(W_ONE)
        local r = ring(J, bot)
        assert(J.IsSoakCandidate('soloclaim') == true,
            'the gate is shut for this bot on the armed leg')
        armed = ask_with_ally_holding(J, bot, r[1])
    end, 'radiant')
    unprobe()

    -- SHIPPED leg -- a SECOND real load on a provably clean switch.
    ss.assert_clean('soloclaim shipped leg')
    local J2, bot2 = load(W_ONE)
    local r2 = ring(J2, bot2)
    assert(J2.IsSoakCandidate('soloclaim') == false,
        'the gate is open on the un-armed leg')
    local shipped = ask_with_ally_holding(J2, bot2, r2[1])
    unprobe()

    assert(shipped == false,
        'shipped already answers true with a single ally -- the `<= 1` guard '
        .. 'is not doing what this lever says it does')
    assert(armed == true,
        'armed did not see the lone ally\'s claim.  If this reads false while '
        .. 'shipped also reads false, suspect the two legs came from ONE load: '
        .. 'J.IsModeTurbo memoises, so a re-read after flipping GetGameMode is '
        .. 'the FIRST answer, and both legs then agree for a reason that has '
        .. 'nothing to do with the code under test')
end

tests['[soloclaim] an empty ring is untouched in BOTH directions'] = function()
    local function answer(armed_leg)
        local v
        local body = function()
            local J, bot = load(W_ZERO)
            local r = ring(J, bot)
            assert(#r == 0, 'the zero-ally witness now has ' .. #r .. ' allies')
            -- No ally to hold it, so the stub has nothing to attach to: this is
            -- the shipped question, asked of a real empty ring.
            local unit = { GetLocation = function() return bot:GetLocation() end }
            local ok, got = pcall(J.IsOtherAllysTarget, unit)
            assert(ok, tostring(got))
            v = got
        end
        if armed_leg then ss.with_candidate('soloclaim', body, 'radiant')
        else ss.assert_clean('soloclaim empty ring'); body() end
        unprobe()
        return v
    end
    assert(answer(true) == false, 'armed answered true on an EMPTY ring -- the '
        .. 'loop cannot have found anything, so this is the guard being '
        .. 'replaced by something that decides on its own')
    assert(answer(false) == false, 'shipped answered true on an empty ring')
end

tests['[soloclaim] with two allies the guard never fired, so nothing may move']
= function()
    local function answer(armed_leg)
        local v
        local body = function()
            local J, bot = load(W_TWO)
            local r = ring(J, bot)
            assert(#r >= 2, 'the two-ally witness now has ' .. #r .. ' allies')
            v = ask_with_ally_holding(J, bot, r[1])
        end
        if armed_leg then ss.with_candidate('soloclaim', body, 'radiant')
        else ss.assert_clean('soloclaim two allies'); body() end
        unprobe()
        return v
    end
    local armed, shipped = answer(true), answer(false)
    assert(armed == shipped,
        'armed and shipped disagree on a frame where the `<= 1` guard never '
        .. 'fired (armed ' .. tostring(armed) .. ', shipped ' .. tostring(shipped)
        .. ') -- arming must be byte-identical above the guard')
    assert(shipped == true,
        'the two-ally frame no longer reaches the loop at all; it cannot '
        .. 'witness "the guard never fired"')
end

-- ======================================== 4. inert where it must be inert

tests['[soloclaim] outside turbo the gate cannot open, even fully armed'] =
function()
    ss.with_candidate('soloclaim', function()
        unprobe()
        local J, bot = rf.load(W_ONE[1], W_ONE[2])
        -- ⛔ GAMEMODE_TURBO is the CONSTANT (23), not the current mode.  Moving
        -- it to 22 alongside GetGameMode makes the two agree and reads TURBO --
        -- the first draft of this case did exactly that and failed.  Leave the
        -- constant where it is and move only the reading.
        GAMEMODE_TURBO = 23                    -- luacheck: ignore
        GetGameMode = function() return 22 end -- luacheck: ignore
        local r = ring(J, bot)
        assert(J.IsModeTurbo() == false, 'the witness load is reading turbo')
        assert(ask_with_ally_holding(J, bot, r[1]) == false,
            'the lever fired outside turbo -- it is turbo-only by charter')
    end, 'radiant')
    unprobe()
end

tests['[soloclaim] with a DIFFERENT id armed, nothing changes'] = function()
    -- The switch is one global path shared by every gate test; an id-blind
    -- read of it would make this lever fire under any other candidate's wave.
    ss.with_candidate('pullcamp', function()
        local J, bot = load(W_ONE)
        local r = ring(J, bot)
        assert(J.IsSoakCandidate('soloclaim') == false,
            "'soloclaim' reads armed while 'pullcamp' is the armed id")
        assert(ask_with_ally_holding(J, bot, r[1]) == false,
            "the lever fired under another candidate's switch")
    end, 'radiant')
    unprobe()
end

-- ========================================================= 5. [control]

tests['[control] the stub is what supplies the claim, not the lever'] =
function()
    -- The control leg for section 3: with NO stub, the armed answer must be
    -- false, because the corpus carries no attack target.  If this reads true,
    -- the flip in section 3 is coming from somewhere other than the ally's
    -- claim and every number above is measuring the wrong thing.
    ss.with_candidate('soloclaim', function()
        local J, bot = load(W_ONE)
        local unit = { GetLocation = function() return bot:GetLocation() end }
        local ok, v = pcall(J.IsOtherAllysTarget, unit)
        assert(ok, tostring(v))
        assert(v == false,
            'armed answers true with NO stubbed target -- the flip measured in '
            .. 'section 3 is not the ally\'s claim')
    end, 'radiant')
    unprobe()
end

tests['[control] the witness frames are distinct populations'] = function()
    -- Guards against the whole file quietly collapsing onto one frame (every
    -- case then agrees for free and the direction argument covers nothing).
    local sizes = {}
    for _, w in ipairs({ W_ZERO, W_ONE, W_TWO }) do
        local J, bot = load(w)
        sizes[#sizes + 1] = #ring(J, bot)
        unprobe()
    end
    assert(sizes[1] == 0 and sizes[2] == 1 and sizes[3] >= 2,
        'the three witnesses no longer cover ring sizes 0 / 1 / >=2, they read '
        .. table.concat(sizes, ', '))
end

return tests

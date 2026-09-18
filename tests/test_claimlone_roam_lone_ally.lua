-- [claimlone] THE THIRD COPY OF THE BELIEF "the ally list contains me".
--
-- 'soloclaim' (2026-09-17, same group) repaired that belief in
-- J.IsOtherAllysTarget.  The roam mode file carried its OWN third copy --
-- X.IsAllysTarget, ring 1000 instead of 800, `ally:GetTarget() /
-- ally:GetAttackTarget()` instead of J.GetProperTarget -- with BOTH lines
-- (`#allies < 2 then return false` and `ally ~= bot`) intact.
-- ⛔ AND IT WAS NOT OVERLOOKED: the same round's ring-subject census
-- (tests/test_ring_subject_census.py) carries a row for it BY NAME.  That row
-- prices the asker-anchored RING -- a different defect, the one the soloclaim
-- header parks on purpose -- and prices it to unpriceable.  The guard is not in
-- it.  A triaged row reads as a handled function, which is the hard form of the
-- 0NEXT42 sentence bought one day earlier.
--
-- READ THE HEADER OF J.IsRoamAllysTarget FIRST (bots/FunLib/jmz_func.lua): the
-- defect, the direction argument and the two domain readings live there.  This
-- file is what drives them on real frames.
--
-- ⛔ WHY THE CORPUS WALK IS NOT IN THIS FILE.  It is in tests/_claimlone_sweep.lua
-- and is run BY HAND.  A walk inside the test made the fightfoe round's file
-- ~120s, and tools/agent/lua_gate.py kills an unmeasured new test at
-- `hook_timeout_seconds` = 20.0 -- mid-`ss.arm`, leaving the global switch on
-- disk and breaking every OTHER gate test's "gate off" precondition.  The
-- numbers quoted below were taken by that sweep on 2026-09-18:
--
--   live 1039 | shipped_live 1039 | self_in_list 0 | ally0 588 | ally1 378
--   ally2plus 73 | target_nonnil 0 | armable 199 | up 199 | down 0
--
-- `up` == `armable` exactly: every frame in the armed-side domain flips and
-- ONLY those.  ⛔ `down 0` is a reading only because `up` is 199 in the SAME
-- tally -- a direction column of zeros cannot tell "the direction holds" from
-- "the tally never ran".  And `armable` 199 < `ally1` 378 is the proof that
-- with_candidate armed ONE side, so the other side's armed and shipped answers
-- are identically equal by construction rather than by the code under test.
--
-- ⛔ `target_nonnil` 0 / 1039 is an INSTRUMENT WALL, not a finding: an attack
-- target is bot-VM state the .dem does not carry (GH #27 / STOPPER 4 family).
-- So 378 is the CEILING of the in-engine flip set, NOT a fire rate, and
-- section 3 below supplies that one missing read with a stub and says so.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local ss = require('mock.soak_side')

ss.assert_clean('test_claimlone_roam_lone_ally load time')

local tests = {}

-- Witness frames, each picked for its ring size at r=1000 by the sweep's own
-- column.  A and B are different fixtures on purpose: one lone-ally frame
-- cannot tell "the guard throws the claim away" from "this fixture is odd".
local W_ONE_A = { 'tests/fixtures/f_011405_jak_rescue_axe.lua', 'npc_dota_hero_axe' }
local W_ONE_B = { 'tests/fixtures/f_260903_101254_cm_farm_stealcamp.lua',
                  'npc_dota_hero_silencer' }
local W_ZERO  = { 'tests/fixtures/f_013254_ck_rescue_trade.lua',
                  'npc_dota_hero_ember_spirit' }
local W_TWO   = { 'tests/fixtures/f_050713_es_defend_1v3.lua', 'npc_dota_hero_lion' }

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

--- ⛔ The RAW engine ring, not J.GetNearbyHeroes: X.IsAllysTarget calls
--- `bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE)` directly, and asking the J
--- wrapper here would measure a different (filtered) list than the one the
--- function under test reads.
local function ring(bot)
    return bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE) or {}
end

--- Ask the function about a unit the lone ally is holding.  The ONLY
--- constructed input is `GetTarget` for that one ally -- exactly the read the
--- .dem does not carry -- and it stands on the side that SUPPORTS the
--- conclusion, so it is named here rather than left for the reader to find.
local function ask_with_ally_holding(J, bot, hAlly)
    local unit = { GetLocation = function() return bot:GetLocation() end }
    local spec = rawget(hAlly, '__spec')
    assert(spec ~= nil, 'the ally is not a mock unit; the stub has nothing to '
        .. 'attach to')
    local prior = spec.GetTarget
    spec.GetTarget = function() return unit end
    local ok, v = pcall(J.IsRoamAllysTarget, unit)
    spec.GetTarget = prior
    assert(ok, 'J.IsRoamAllysTarget raised: ' .. tostring(v))
    return v
end

-- ================================================ 1. the source, pinned

local function fn_code(sPath, sName)
    local fh = assert(io.open(sPath, 'r'))
    local s = fh:read('*a'); fh:close()
    local at = assert(s:find('function ' .. sName, 1, true),
        sName .. ' is gone from ' .. sPath)
    local fin = assert(s:find('\nend\n', at, true))
    -- Comments stripped: a claim about what the CODE does must not be
    -- satisfiable by the prose describing it (the header quotes every one of
    -- these tokens several times).
    return (s:sub(at, fin):gsub('%-%-[^\n]*', ''))
end

local function jmz_code() return fn_code('bots/FunLib/jmz_func.lua',
    'J.IsRoamAllysTarget') end

tests['[claimlone] the repair is gated, turbo-scoped, and ON the guard'] =
function()
    local code = jmz_code()
    assert(code:find("IsSoakCandidate%(%s*'claimlone'%s*%)"),
        "the 'claimlone' gate is gone from J.IsRoamAllysTarget")
    assert(code:find('IsModeTurbo', 1, true),
        'the turbo scope disappeared -- this must be inert outside turbo')
    -- Order matters and counting cannot see it: a gate that names its id but
    -- sits BELOW the guard it exists to suspend passes every existence check
    -- above while doing nothing.
    local at_guard = assert(code:find('#hAllyList', 1, true))
    local at_gate = assert(code:find('claimlone', 1, true))
    local at_loop = assert(code:find('for _, ally in pairs', 1, true))
    assert(at_guard < at_gate and at_gate < at_loop,
        "the 'claimlone' gate no longer sits between the ally-count guard and "
        .. 'the loop it lets run')
end

tests['[claimlone] the ONE lever: ring, radius and the dead self-test are untouched']
= function()
    local code = jmz_code()
    assert(code:find('bot:GetNearbyHeroes(1000, false, BOT_MODE_NONE)', 1, true),
        'the ally ring moved.  The ring is centred on the ASKER while the '
        .. 'question is about the UNIT -- that is a SECOND, bigger defect this '
        .. 'lever deliberately does not touch, and the radius 1000 is what '
        .. 'makes this a different function from the 800 one soloclaim repaired')
    assert(code:find('ally ~= bot', 1, true),
        'the `ally ~= bot` term was deleted.  It is dead code (self_in_list is '
        .. '0 / 1039) but it is the OTHER half of the same false belief, and '
        .. 'deleting it silently removes the evidence that the belief was held')
    assert(code:find('#hAllyList < 2', 1, true),
        'the shipped guard itself is gone -- this lever SUSPENDS it behind a '
        .. 'gate, it does not remove it')
    assert(code:find('IsIllusion', 1, true),
        'the illusion test vanished.  The corpus cannot see it (the fixture '
        .. 'loader drops illusions at dump time) so no frame here would go red '
        .. '-- which is exactly why it is pinned in the source instead')
    assert(code:find('GetAttackTarget', 1, true) and code:find('GetTarget', 1, true),
        'the claim test changed.  X.IsAllysTarget reads the two engine getters '
        .. 'directly, NOT J.GetProperTarget -- swapping them in is a second '
        .. 'lever riding this one')
end

tests['[claimlone] the mode file still routes through the repaired function'] =
function()
    local src = assert(io.open('bots/mode_team_roam_generic.lua', 'r')):read('*a')
    local at = assert(src:find('function X.IsAllysTarget', 1, true))
    local fin = assert(src:find('\nend\n', at, true))
    local body = (src:sub(at, fin):gsub('%-%-[^\n]*', ''))
    assert(body:find('J.IsRoamAllysTarget', 1, true),
        'X.IsAllysTarget stopped delegating; the gate is then unreachable from '
        .. 'every one of its five call sites while this file still passes')
    assert(not body:find('#allies < 2', 1, true),
        'the guard grew back inside the mode file, ABOVE the delegate -- the '
        .. 'gate would then be dead code and nothing else here would say so')
end

-- ============================= 2. the premise, on real frames, unstubbed

tests['[claimlone] real frame: the asker is NOT a member of its own 1000u ring']
= function()
    -- The guard `#allies < 2` only means "nobody but me is here" if I am an
    -- entry.  Taken with no stub at all, on a frame that has a ring.
    for _, w in ipairs({ W_ONE_A, W_ONE_B }) do
        local J, bot = load(w)
        local r = ring(bot)
        assert(#r == 1, w[2] .. ' no longer has exactly one ally in 1000, it '
            .. 'has ' .. #r .. ' -- re-pick it from the sweep')
        for _, a in pairs(r) do
            assert(a ~= bot, 'the ally ring now contains the asker, so the '
                .. 'shipped guard means what it says and this lever must be '
                .. 're-priced')
        end
        assert(r[1]:GetTarget() == nil and r[1]:GetAttackTarget() == nil,
            'the engine target getters now answer on a corpus frame -- the '
            .. '"378 is a ceiling, not a fire rate" reading must be re-taken')
        assert(J.IsModeTurbo(), 'the dump is turbo')
        unprobe()
    end
end

-- ==================== 3. the differential, both directions, two real loads

local function differential(w)
    -- ARMED leg.
    local armed
    ss.with_candidate('claimlone', function()
        local J, bot = load(w)
        local r = ring(bot)
        assert(J.IsSoakCandidate('claimlone') == true,
            'the gate is shut for this bot on the armed leg')
        armed = ask_with_ally_holding(J, bot, r[1])
    end, 'radiant')
    unprobe()

    -- SHIPPED leg -- a SECOND real load on a provably clean switch.
    ss.assert_clean('claimlone shipped leg')
    local J2, bot2 = load(w)
    local r2 = ring(bot2)
    assert(J2.IsSoakCandidate('claimlone') == false,
        'the gate is open on the un-armed leg')
    local shipped = ask_with_ally_holding(J2, bot2, r2[1])
    unprobe()
    return armed, shipped
end

for _, w in ipairs({ { 'A', W_ONE_A }, { 'B', W_ONE_B } }) do
    tests['[claimlone] witness ' .. w[1] .. ': armed sees the lone ally\'s claim, '
        .. 'shipped does not'] = function()
        local armed, shipped = differential(w[2])
        assert(shipped == false,
            'shipped already answers true with a single ally -- the `< 2` guard '
            .. 'is not doing what this lever says it does')
        assert(armed == true,
            'armed did not see the lone ally\'s claim.  If this reads false '
            .. 'while shipped also reads false, suspect the two legs came from '
            .. 'ONE load: J.IsModeTurbo memoises, so a re-read after flipping '
            .. 'GetGameMode is the FIRST answer, and both legs then agree for a '
            .. 'reason that has nothing to do with the code under test')
    end
end

tests['[claimlone] an empty ring is untouched in BOTH directions'] = function()
    local function answer(armed_leg)
        local v
        local body = function()
            local J, bot = load(W_ZERO)
            local r = ring(bot)
            assert(#r == 0, 'the zero-ally witness now has ' .. #r .. ' allies')
            -- No ally to hold it, so the stub has nothing to attach to: this is
            -- the shipped question, asked of a real empty ring.
            local unit = { GetLocation = function() return bot:GetLocation() end }
            local ok, got = pcall(J.IsRoamAllysTarget, unit)
            assert(ok, tostring(got))
            v = got
        end
        if armed_leg then ss.with_candidate('claimlone', body, 'radiant')
        else ss.assert_clean('claimlone empty ring'); body() end
        unprobe()
        return v
    end
    assert(answer(true) == false, 'armed answered true on an EMPTY ring -- the '
        .. 'loop cannot have found anything, so this is the guard being '
        .. 'replaced by something that decides on its own')
    assert(answer(false) == false, 'shipped answered true on an empty ring')
end

tests['[claimlone] with two allies the guard never fired, so nothing may move']
= function()
    local function answer(armed_leg)
        local v
        local body = function()
            local J, bot = load(W_TWO)
            local r = ring(bot)
            assert(#r >= 2, 'the two-ally witness now has ' .. #r .. ' allies')
            v = ask_with_ally_holding(J, bot, r[1])
        end
        if armed_leg then ss.with_candidate('claimlone', body, 'radiant')
        else ss.assert_clean('claimlone two allies'); body() end
        unprobe()
        return v
    end
    local armed, shipped = answer(true), answer(false)
    assert(armed == shipped,
        'armed and shipped disagree on a frame where the `< 2` guard never '
        .. 'fired (armed ' .. tostring(armed) .. ', shipped ' .. tostring(shipped)
        .. ') -- arming must be byte-identical above the guard')
    assert(shipped == true,
        'the two-ally frame no longer reaches the loop at all; it cannot '
        .. 'witness "the guard never fired"')
end

-- ======================================== 4. inert where it must be inert

tests['[claimlone] outside turbo the gate cannot open, even fully armed'] =
function()
    ss.with_candidate('claimlone', function()
        unprobe()
        local J, bot = rf.load(W_ONE_A[1], W_ONE_A[2])
        -- ⛔ GAMEMODE_TURBO is the CONSTANT (23), not the current mode.  Moving
        -- it to 22 alongside GetGameMode makes the two agree and reads TURBO --
        -- the first draft of this case did exactly that and failed.  Leave the
        -- constant where it is and move only the reading.
        GAMEMODE_TURBO = 23                    -- luacheck: ignore
        GetGameMode = function() return 22 end -- luacheck: ignore
        assert(J.IsModeTurbo() == false, 'the witness load is reading turbo')
        local r = ring(bot)
        assert(#r == 1, 'the witness lost its lone ally')
        assert(ask_with_ally_holding(J, bot, r[1]) == false,
            'the lever fired in a NON-turbo game.  Every id in this family is '
            .. 'turbo-only; a leak here changes real non-turbo matches')
    end, 'radiant')
    unprobe()
end

tests['[claimlone] the OTHER side of an armed wave is byte-identical'] =
function()
    -- with_candidate arms ONE physical side.  A bot on the other side must see
    -- the shipped answer, or a mirrored wave measures the lever twice.
    local v
    ss.with_candidate('claimlone', function()
        local J, bot = load(W_ONE_A)
        assert(J.IsSoakCandidate('claimlone') == false,
            'the gate is open on the UNARMED side -- side scoping is broken')
        local r = ring(bot)
        v = ask_with_ally_holding(J, bot, r[1])
    end, 'dire')
    unprobe()
    assert(v == false, 'the unarmed side saw the lone ally\'s claim')
end

tests['[claimlone] with a DIFFERENT id armed, nothing changes'] = function()
    -- The switch is one global path shared by every gate test; an id-blind read
    -- of it would make this lever fire under any other candidate's wave.
    ss.with_candidate('pullcamp', function()
        local J, bot = load(W_ONE_A)
        local r = ring(bot)
        assert(J.IsSoakCandidate('claimlone') == false,
            "'claimlone' reads armed while 'pullcamp' is the armed id")
        assert(ask_with_ally_holding(J, bot, r[1]) == false,
            "the lever fired under another candidate's switch")
    end, 'radiant')
    unprobe()
end

-- ========================================================= 5. [control]

tests['[control] the stub is what supplies the claim, not the lever'] =
function()
    -- The control leg for section 3: with NO stub, the armed answer must be
    -- false, because the corpus carries no attack target (target_nonnil 0 /
    -- 1039).  If this reads true, the flip in section 3 is coming from
    -- somewhere other than the ally's claim and every number above is
    -- measuring the wrong thing.
    ss.with_candidate('claimlone', function()
        local J, bot = load(W_ONE_A)
        local r = ring(bot)
        assert(J.IsSoakCandidate('claimlone') == true, 'the gate is shut')
        assert(#r == 1, 'the witness lost its lone ally')
        local unit = { GetLocation = function() return bot:GetLocation() end }
        local ok, got = pcall(J.IsRoamAllysTarget, unit)
        assert(ok, tostring(got))
        assert(got == false,
            'armed answered TRUE with NO stub at all -- the flip in section 3 '
            .. 'is then not the lone ally\'s claim being read, and the "378 is '
            .. 'a ceiling" reading is measuring something else')
    end, 'radiant')
    unprobe()
end

return tests
